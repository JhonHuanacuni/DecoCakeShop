import { useEffect, useState } from "react";
import { parseJsonResponse } from "../../utils/api";
import { phIngrese, phSeleccione } from "../../utils/placeholder";
import { useCrud } from "../../hooks/useCrud";
import PageHeader from "../../components/mantenedor/PageHeader";
import Toolbar from "../../components/mantenedor/Toolbar";
import DataTable from "../../components/mantenedor/DataTable";
import Pagination from "../../components/mantenedor/Pagination";
import ConfirmDialog from "../../components/mantenedor/ConfirmDialog";
import Toast from "../../components/mantenedor/feedback/Toast";
import PagosModal from "../../components/mantenedor/PagosModal";
import { abrirVistaDocumento } from "../../utils/exportarCotizacionPdf";
import "../../styles/mantenedor.css";

const ESTADOS = ["Pendiente", "Empaquetado", "Enviado"];

const columnas = [
  { campo: "IDVENTA", etiqueta: "Código", ordenable: true },
  { campo: "CLIENTE_NOMBRE", etiqueta: "Cliente", ordenable: true },
  { campo: "FORMAPAGO_NOMBRE", etiqueta: "Pago", ordenable: false },
  { campo: "TIPOENTREGA_NOMBRE", etiqueta: "Entrega", ordenable: false },
  { campo: "TOTAL", etiqueta: "Total", tipo: "decimal", ordenable: true },
  { campo: "ESTADO", etiqueta: "Estado", tipo: "estado", ordenable: true },
  { campo: "FECHA", etiqueta: "Fecha", tipo: "fecha", ordenable: true },
  { campo: "HORA", etiqueta: "Hora", ordenable: false },
  { campo: "CREADOPOR_NOMBRE", etiqueta: "Envió", ordenable: false },
];

function emptyLinea() {
  return { IDPRODUCTO: "", CANTIDAD: 1, PRECIOUNITARIO: 0 };
}

export default function VentaPage({ navNonce }) {
  const crud = useCrud({ entidad: "ventas", pk: "IDVENTA", ordenInicial: { campo: "FECHA", direccion: "DESC" } });
  const [vista, setVista] = useState("lista");
  const [modo, setModo] = useState("crear");
  const [form, setForm] = useState({});
  const [detalle, setDetalle] = useState([emptyLinea()]);
  const [catalogos, setCatalogos] = useState({ clientes: [], tiposEntrega: [], productos: [], formasPago: [] });
  const [toast, setToast] = useState(null);
  const [confirm, setConfirm] = useState(null);
  const [enviando, setEnviando] = useState(false);
  const [pagosData, setPagosData] = useState(null);
  const [abono, setAbono] = useState("");
  const [abonoForma, setAbonoForma] = useState("");
  const [focusAbono, setFocusAbono] = useState(false);

  const irListado = () => setVista("lista");
  useEffect(() => { irListado(); }, [navNonce]);

  useEffect(() => {
    (async () => {
      try {
        const res = await fetch("/api/ventas/catalogos/");
        const data = await parseJsonResponse(res);
        if (res.ok) setCatalogos(data);
      } catch { /* opcional */ }
    })();
  }, []);

  const tipo = catalogos.tiposEntrega?.find((t) => t.value === form.IDTIPOENTREGA);
  const requiereDir = Number(tipo?.REQUIEREDIRECCION) === 1;

  const abrirCrear = () => {
    setForm({
      IDCLIENTE: "", IDFORMAPAGO: "", IDTIPOENTREGA: "", DIRECCIONENTREGA: "",
      COSTODELIVERY: 0, OBSERVACIONES: "", ESTADO: "Pendiente",
    });
    setDetalle([emptyLinea()]);
    setModo("crear");
    setVista("form");
  };

  const abrirEditar = async (row, ver = false) => {
    try {
      const data = await crud.obtener(row.IDVENTA);
      setForm(data);
      setDetalle(data.DETALLE?.length ? data.DETALLE : [emptyLinea()]);
      setModo(ver ? "ver" : "editar");
      setVista("form");
    } catch (err) { setToast({ mensaje: err.message, tipo: "error" }); }
  };

  const abrirPagos = async (row, completar = false) => {
    if (!row.IDCOTIZACION) {
      setToast({ mensaje: "Este pedido no tiene una cotización asociada.", tipo: "error" });
      return;
    }
    try {
      setFocusAbono(completar);
      const res = await fetch(`/api/cotizaciones/${encodeURIComponent(row.IDCOTIZACION)}/pagos/`);
      const data = await parseJsonResponse(res);
      if (!res.ok) throw new Error(data.error || "No se pudieron cargar los pagos");
      const info = data.data;
      setPagosData(info);
      const saldo = Number(info.SALDO || 0);
      setAbono(saldo > 0 ? saldo.toFixed(2) : "");
      setAbonoForma("");
    } catch (err) { setToast({ mensaje: err.message, tipo: "error" }); }
  };

  const registrarAbono = async () => {
    if (!pagosData) return;
    const monto = Number(abono);
    if (!monto || monto <= 0) {
      setToast({ mensaje: "Ingresa el monto del abono.", tipo: "error" });
      return;
    }
    if (monto > Number(pagosData.SALDO || 0) + 0.009) {
      setToast({ mensaje: "El abono no puede ser mayor al saldo pendiente.", tipo: "error" });
      return;
    }
    if (!abonoForma) {
      setToast({ mensaje: "Selecciona el método de pago.", tipo: "error" });
      return;
    }
    try {
      setEnviando(true);
      const res = await fetch(`/api/cotizaciones/${encodeURIComponent(pagosData.IDCOTIZACION)}/pagos/`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-IdUsuario": localStorage.getItem("idusuario") || "" },
        body: JSON.stringify({ MONTO: monto, TIPO: "Abono", IDFORMAPAGO: abonoForma }),
      });
      const data = await parseJsonResponse(res);
      if (!res.ok || !data.ok) throw new Error(data.mensaje || data.error || "No se pudo registrar el abono");
      setToast({ mensaje: data.mensaje, tipo: "success" });
      await abrirPagos({ IDCOTIZACION: pagosData.IDCOTIZACION }, false);
      await crud.listar();
    } catch (err) { setToast({ mensaje: err.message, tipo: "error" }); }
    finally { setEnviando(false); }
  };

  const verPedido = async (row) => {
    try {
      const data = await crud.obtener(row.IDVENTA);
      await abrirVistaDocumento({ ...row, ...data }, { tipo: "pedido" });
    } catch (err) {
      setToast({ mensaje: err.message, tipo: "error" });
    }
  };

  const setLinea = (idx, patch) => {
    setDetalle((prev) => prev.map((l, i) => {
      if (i !== idx) return l;
      const next = { ...l, ...patch };
      if (patch.IDPRODUCTO) {
        const p = catalogos.productos.find((x) => x.value === patch.IDPRODUCTO);
        if (p) next.PRECIOUNITARIO = Number(p.PRECIO || 0);
      }
      return next;
    }));
  };

  const subtotal = detalle.reduce((s, l) => s + Number(l.CANTIDAD || 0) * Number(l.PRECIOUNITARIO || 0), 0);
  const total = subtotal + Number(form.COSTODELIVERY || 0);

  const guardar = async () => {
    const payload = { ...form, DETALLE: detalle.filter((l) => l.IDPRODUCTO) };
    setEnviando(true);
    try {
      const mensaje = modo === "crear" ? await crud.insertar(payload) : await crud.actualizar(form.IDVENTA, payload);
      setToast({ mensaje, tipo: "success" });
      setVista("lista");
      await crud.listar();
    } catch (err) { setToast({ mensaje: err.message, tipo: "error" }); }
    finally { setEnviando(false); }
  };

  if (vista === "form") {
    const ro = modo === "ver";
    return (
      <div className="mantenedor-page">
        <PageHeader modulo="Pedidos" vista={modo === "crear" ? "Nuevo pedido" : "Pedido"} mostrarNuevo={false} onIrListado={irListado} />
        <div className="mantenedor-card" style={{ padding: "1.2rem" }}>
          <div className="form-grid">
            <div className="form-field">
              <label>Cliente</label>
              <select disabled={ro} value={form.IDCLIENTE || ""} onChange={(e) => setForm({ ...form, IDCLIENTE: e.target.value })}>
                <option value="">{phSeleccione("cliente")}</option>
                {catalogos.clientes.map((c) => <option key={c.value} value={c.value}>{c.label}</option>)}
              </select>
            </div>
            <div className="form-field">
              <label>Forma de pago</label>
              <select disabled={ro} value={form.IDFORMAPAGO || ""} onChange={(e) => setForm({ ...form, IDFORMAPAGO: e.target.value })}>
                <option value="">{phSeleccione("forma de pago")}</option>
                {catalogos.formasPago.map((c) => <option key={c.value} value={c.value}>{c.label}</option>)}
              </select>
            </div>
            <div className="form-field">
              <label>Tipo de entrega</label>
              <select disabled={ro} value={form.IDTIPOENTREGA || ""} onChange={(e) => setForm({ ...form, IDTIPOENTREGA: e.target.value })}>
                <option value="">{phSeleccione("tipo de entrega")}</option>
                {catalogos.tiposEntrega.map((c) => <option key={c.value} value={c.value}>{c.label}</option>)}
              </select>
            </div>
            {requiereDir && (
              <div className="form-field full">
                <label>Dirección de delivery</label>
                <input disabled={ro} value={form.DIRECCIONENTREGA || ""} placeholder={phIngrese("dirección de delivery")} onChange={(e) => setForm({ ...form, DIRECCIONENTREGA: e.target.value })} />
              </div>
            )}
            <div className="form-field">
              <label>Costo delivery</label>
              <input type="number" disabled={ro} min="0" value={form.COSTODELIVERY || 0} placeholder={phIngrese("costo delivery")} onChange={(e) => setForm({ ...form, COSTODELIVERY: e.target.value })} />
            </div>
            <div className="form-field">
              <label>Estado</label>
              <select disabled={ro} value={form.ESTADO || "Pendiente"} onChange={(e) => setForm({ ...form, ESTADO: e.target.value })}>
                <option value="">{phSeleccione("estado")}</option>
                {(ESTADOS.includes(form.ESTADO) || !form.ESTADO ? ESTADOS : [form.ESTADO, ...ESTADOS]).map((e) => <option key={e}>{e}</option>)}
              </select>
            </div>
            <div className="form-field full">
              <label>Observaciones</label>
              <textarea disabled={ro} value={form.OBSERVACIONES || ""} placeholder={phIngrese("observaciones")} onChange={(e) => setForm({ ...form, OBSERVACIONES: e.target.value })} />
            </div>
            {form.COMPROBANTEPAGO && (
              <div className="form-field full">
                <label>Captura de pago</label>
                <img src={form.COMPROBANTEPAGO} alt="Comprobante de pago" style={{ maxWidth: "100%", maxHeight: 280, borderRadius: 12, border: "1px solid #ead5dc" }} />
              </div>
            )}
          </div>
          <h3 className="form-section-title" style={{ marginTop: "1.2rem" }}>Productos</h3>
          <table className="data-table">
            <thead><tr><th>Producto</th><th>Cant.</th><th>P. unit.</th><th>Subtotal</th><th /></tr></thead>
            <tbody>
              {detalle.map((l, i) => (
                <tr key={i}>
                  <td>
                    <select disabled={ro} value={l.IDPRODUCTO} onChange={(e) => setLinea(i, { IDPRODUCTO: e.target.value })}>
                      <option value="">{phSeleccione("producto")}</option>
                      {catalogos.productos.map((p) => <option key={p.value} value={p.value}>{p.label}</option>)}
                    </select>
                  </td>
                  <td><input type="number" disabled={ro} min="0" value={l.CANTIDAD} placeholder={phIngrese("cant.")} onChange={(e) => setLinea(i, { CANTIDAD: e.target.value })} /></td>
                  <td><input type="number" disabled={ro} min="0" value={l.PRECIOUNITARIO} placeholder={phIngrese("p. unit.")} onChange={(e) => setLinea(i, { PRECIOUNITARIO: e.target.value })} /></td>
                  <td>S/ {(Number(l.CANTIDAD || 0) * Number(l.PRECIOUNITARIO || 0)).toFixed(2)}</td>
                  <td>{!ro && <button type="button" className="btn-icon danger" onClick={() => setDetalle((d) => d.filter((_, x) => x !== i))}>✕</button>}</td>
                </tr>
              ))}
            </tbody>
          </table>
          {!ro && <button type="button" className="btn-secondary" style={{ marginTop: 8 }} onClick={() => setDetalle((d) => [...d, emptyLinea()])}>+ Producto</button>}
          <p style={{ textAlign: "right", fontWeight: 700 }}>Subtotal: S/ {subtotal.toFixed(2)} · Total: S/ {total.toFixed(2)}</p>
          <div className="form-page-footer">
            <button type="button" className="btn-secondary" onClick={() => setVista("lista")}>{ro ? "Cerrar" : "Cancelar"}</button>
            {!ro && <button type="button" className="btn-primary" disabled={enviando} onClick={guardar}>Guardar</button>}
          </div>
        </div>
        {toast && <Toast mensaje={toast.mensaje} tipo={toast.tipo} onClose={() => setToast(null)} />}
      </div>
    );
  }

  return (
    <div className="mantenedor-page">
      <PageHeader modulo="Pedidos" vista="Listado" mostrarNuevo={false} onIrListado={irListado} />
      <div className="mantenedor-card">
        <Toolbar
          buscar={crud.buscar} onBuscarChange={crud.onBuscarChange}
          filtros={[{
            key: "estado", etiqueta: "Estado", value: crud.filtros.estado || "",
            opciones: [...ESTADOS, "Anulado"],
            onChange: (v) => crud.setFiltro("estado", v),
          }]}
        />
        <DataTable
          columnas={columnas} items={crud.items} pk="IDVENTA" orden={crud.orden}
          loading={crud.loading} error={crud.error} onOrden={crud.toggleOrden}
          onVer={verPedido} onEditar={(r) => abrirEditar(r, false)}
          onPagos={(r) => abrirPagos(r, Number(r.SALDO) > 0)}
          onAnular={(r) => setConfirm({ tipo: "anular", id: r.IDVENTA, mensaje: `¿Anular ${r.IDVENTA}? El stock volverá al almacén.` })}
          onEliminar={(r) => setConfirm({ tipo: "eliminar", id: r.IDVENTA, mensaje: `¿Eliminar ${r.IDVENTA}?` })}
          onReintentar={crud.listar} pagina={crud.pagina} tamanio={crud.tamanio}
        />
        <Pagination pagina={crud.pagina} tamanio={crud.tamanio} total={crud.total} onChange={crud.setPagina} />
      </div>
      <ConfirmDialog abierto={Boolean(confirm)} titulo={confirm?.tipo === "anular" ? "Anular" : "Eliminar"} mensaje={confirm?.mensaje}
        onCancel={() => setConfirm(null)}
        onConfirm={async () => {
          try {
            if (confirm.tipo === "anular") {
              const res = await fetch(`/api/ventas/${encodeURIComponent(confirm.id)}/anular/`, {
                method: "POST",
                headers: { "Content-Type": "application/json", "X-IdUsuario": localStorage.getItem("idusuario") || "" },
                body: "{}",
              });
              const data = await parseJsonResponse(res);
              if (!res.ok || !data.ok) throw new Error(data.mensaje || data.error || "No se pudo anular");
              setToast({ mensaje: data.mensaje, tipo: "success" });
            } else {
              setToast({ mensaje: await crud.eliminar(confirm.id), tipo: "success" });
            }
            setConfirm(null);
            await crud.listar();
          }
          catch (err) { setToast({ mensaje: err.message, tipo: "error" }); }
        }}
      />
      <PagosModal
        data={pagosData} abono={abono} setAbono={setAbono} abonoForma={abonoForma} setAbonoForma={setAbonoForma}
        formasPago={catalogos.formasPago} enviando={enviando} focusAbono={focusAbono}
        onCancel={() => setPagosData(null)} onRegistrar={registrarAbono}
      />
      {toast && <Toast mensaje={toast.mensaje} tipo={toast.tipo} onClose={() => setToast(null)} />}
    </div>
  );
}

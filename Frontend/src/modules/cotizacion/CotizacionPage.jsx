import { useEffect, useMemo, useState } from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faSearch, faPlus, faMinus, faTrash } from "@fortawesome/free-solid-svg-icons";
import { parseJsonResponse } from "../../utils/api";
import { phIngrese, phSeleccione } from "../../utils/placeholder";
import { useCrud } from "../../hooks/useCrud";
import ClienteSuggest from "../../components/mantenedor/ClienteSuggest";
import PageHeader from "../../components/mantenedor/PageHeader";
import Toolbar from "../../components/mantenedor/Toolbar";
import DataTable from "../../components/mantenedor/DataTable";
import Pagination from "../../components/mantenedor/Pagination";
import ConfirmDialog from "../../components/mantenedor/ConfirmDialog";
import Toast from "../../components/mantenedor/feedback/Toast";
import PagosModal from "../../components/mantenedor/PagosModal";
import { abrirVistaDocumento } from "../../utils/exportarCotizacionPdf";
import "../../styles/mantenedor.css";
import "./cotizacion.css";

const ESTADOS = ["Deuda", "Pagado"];
const columnas = [
  { campo: "IDCOTIZACION", etiqueta: "Código", ordenable: true },
  { campo: "CLIENTE_NOMBRE", etiqueta: "Cliente", ordenable: true },
  { campo: "TOTAL", etiqueta: "Total", tipo: "decimal", ordenable: true },
  { campo: "ABONADO", etiqueta: "Abonado", tipo: "decimal", ordenable: false },
  { campo: "SALDO", etiqueta: "Saldo", tipo: "decimal", ordenable: false },
  { campo: "ESTADO", etiqueta: "Estado", tipo: "estado", ordenable: true },
  { campo: "FECHA", etiqueta: "Fecha", tipo: "fecha", ordenable: true },
  { campo: "HORA", etiqueta: "Hora", ordenable: false },
];

function actorHeaders() {
  return { "Content-Type": "application/json", "X-IdUsuario": localStorage.getItem("idusuario") || "" };
}

function normalizarEstado(estado) {
  if (estado === "Pagado" || estado === "Convertida") return "Pagado";
  return "Deuda";
}

function envioVacio() {
  return { IDFORMAPAGO: "", IDTIPOENTREGA: "", DIRECCIONENTREGA: "", COSTODELIVERY: 0 };
}

function money(n) {
  return `S/ ${Number(n || 0).toFixed(2)}`;
}

function EnvioModal({ pedido, envio, setEnvio, catalogos, requiereDirEnvio, enviando, modoEnvio = "pedido", onCancel, onConfirm }) {
  if (!pedido) return null;
  const esGuardar = modoEnvio === "guardar";
  return (
    <div className="modal-overlay">
      <div className="modal-panel" style={{ width: "min(460px, 100%)" }}>
        <div className="modal-header"><h2>Datos de envío</h2></div>
        <div className="modal-body">
          <div className="form-field">
            <label>Tipo de entrega</label>
            <select value={envio.IDTIPOENTREGA} onChange={(e) => setEnvio({ ...envio, IDTIPOENTREGA: e.target.value })}>
              <option value="">{phSeleccione("tipo de entrega")}</option>
              {catalogos.tiposEntrega.map((c) => <option key={c.value} value={c.value}>{c.label}</option>)}
            </select>
          </div>
          {requiereDirEnvio && (
            <div className="form-field">
              <label>Dirección de delivery</label>
              <input
                value={envio.DIRECCIONENTREGA}
                placeholder={phIngrese("dirección de delivery")}
                onChange={(e) => setEnvio({ ...envio, DIRECCIONENTREGA: e.target.value })}
              />
            </div>
          )}
          <div className="form-field">
            <label>Costo delivery</label>
            <input
              type="number"
              min="0"
              step="0.01"
              value={envio.COSTODELIVERY}
              placeholder={phIngrese("costo delivery")}
              onChange={(e) => setEnvio({ ...envio, COSTODELIVERY: e.target.value })}
            />
          </div>
          <div className="form-field">
            <label>Forma de pago</label>
            <select value={envio.IDFORMAPAGO} onChange={(e) => setEnvio({ ...envio, IDFORMAPAGO: e.target.value })}>
              <option value="">{phSeleccione("forma de pago")}</option>
              {catalogos.formasPago.map((f) => <option key={f.value} value={f.value}>{f.label}</option>)}
            </select>
          </div>
        </div>
        <div className="modal-footer">
          <button type="button" className="btn-secondary" disabled={enviando} onClick={onCancel}>
            {esGuardar ? "Todavía no" : "Cancelar"}
          </button>
          <button type="button" className="btn-primary" disabled={enviando} onClick={onConfirm}>
            {esGuardar ? "Guardar" : "Confirmar pedido"}
          </button>
        </div>
      </div>
    </div>
  );
}

export default function CotizacionPage({ navNonce, onChangePage }) {
  const crud = useCrud({ entidad: "cotizaciones", pk: "IDCOTIZACION", ordenInicial: { campo: "FECHA", direccion: "DESC" } });
  const [vista, setVista] = useState("lista");
  const [modo, setModo] = useState("crear");
  const [form, setForm] = useState({});
  const [detalle, setDetalle] = useState([]);
  const [catalogos, setCatalogos] = useState({ clientes: [], tiposEntrega: [], productos: [], formasPago: [], categorias: [] });
  const [toast, setToast] = useState(null);
  const [confirm, setConfirm] = useState(null);
  const [pedido, setPedido] = useState(null);
  const [envio, setEnvio] = useState(envioVacio());
  const [modoEnvio, setModoEnvio] = useState("pedido");
  const [enviando, setEnviando] = useState(false);
  const [buscaProd, setBuscaProd] = useState("");
  const [catFiltro, setCatFiltro] = useState("");
  const [pagosData, setPagosData] = useState(null);
  const [abono, setAbono] = useState("");
  const [abonoForma, setAbonoForma] = useState("");
  const [focusAbono, setFocusAbono] = useState(false);

  useEffect(() => {
    (async () => {
      try {
        const res = await fetch("/api/cotizaciones/catalogos/");
        const data = await parseJsonResponse(res);
        if (res.ok) setCatalogos({
          clientes: data.clientes || [],
          tiposEntrega: data.tiposEntrega || [],
          productos: data.productos || [],
          formasPago: data.formasPago || [],
          categorias: data.categorias || [],
        });
      } catch { /* opcional */ }
    })();
  }, []);

  const tipoEnvio = catalogos.tiposEntrega?.find((t) => String(t.value) === String(envio.IDTIPOENTREGA));
  const requiereDirEnvio = Number(tipoEnvio?.REQUIEREDIRECCION) === 1;

  const productosFiltrados = useMemo(() => {
    const q = buscaProd.trim().toLowerCase();
    return (catalogos.productos || []).filter((p) => {
      if (catFiltro && String(p.IDCATEGORIA) !== String(catFiltro)) return false;
      if (!q) return true;
      return String(p.label || "").toLowerCase().includes(q)
        || String(p.CATEGORIA_NOMBRE || "").toLowerCase().includes(q)
        || String(p.DESCRIPCION || "").toLowerCase().includes(q);
    });
  }, [catalogos.productos, buscaProd, catFiltro]);

  const irListado = () => {
    setVista("lista");
    setPedido(null);
  };

  useEffect(() => {
    irListado();
  }, [navNonce]);

  const abrirCrear = () => {
    setForm({
      IDCLIENTE: "", NOMBRECLIENTE: "", OBSERVACIONES: "", ESTADO: "Deuda", MONTOINICIAL: "", IDFORMAPAGOINICIAL: "",
    });
    setDetalle([]);
    setBuscaProd("");
    setCatFiltro("");
    setModo("crear");
    setVista("form");
  };

  const abrirEditar = async (row, ver = false) => {
    try {
      const data = await crud.obtener(row.IDCOTIZACION);
      setForm({
        ...data,
        NOMBRECLIENTE: data.NOMBRECLIENTE || data.CLIENTE_NOMBRE || "",
        ESTADO: normalizarEstado(data.ESTADO),
      });
      setDetalle(data.DETALLE?.length ? data.DETALLE : []);
      setModo(ver ? "ver" : "editar");
      setVista("form");
    } catch (err) { setToast({ mensaje: err.message, tipo: "error" }); }
  };

  const agregarProducto = (prod) => {
    if (modo === "ver") return;
    setDetalle((prev) => {
      const i = prev.findIndex((l) => String(l.IDPRODUCTO) === String(prod.value));
      if (i >= 0) {
        return prev.map((l, idx) => idx === i ? { ...l, CANTIDAD: Number(l.CANTIDAD || 0) + 1 } : l);
      }
      return [...prev, {
        IDPRODUCTO: prod.value,
        PRODUCTO_NOMBRE: prod.label,
        CANTIDAD: 1,
        PRECIOUNITARIO: Number(prod.PRECIO || 0),
        FOTO: prod.FOTO,
      }];
    });
  };

  const setCantidad = (id, cant) => {
    const n = Number(cant);
    setDetalle((prev) => prev.map((l) => String(l.IDPRODUCTO) === String(id) ? { ...l, CANTIDAD: n < 1 ? 1 : n } : l));
  };

  const setPrecio = (id, precio) => {
    const n = Number(precio);
    setDetalle((prev) => prev.map((l) => String(l.IDPRODUCTO) === String(id) ? { ...l, PRECIOUNITARIO: Number.isNaN(n) || n < 0 ? 0 : n } : l));
  };

  const subtotal = detalle.reduce((s, l) => s + Number(l.CANTIDAD || 0) * Number(l.PRECIOUNITARIO || 0), 0);
  const total = subtotal;

  const resolverCliente = () => {
    const nombre = String(form.NOMBRECLIENTE || "").trim();
    const match = catalogos.clientes.find((c) => String(c.label).toLowerCase() === nombre.toLowerCase());
    return {
      IDCLIENTE: match?.value || null,
      NOMBRECLIENTE: nombre,
    };
  };

  const guardar = async () => {
    const cliente = resolverCliente();
    if (!cliente.NOMBRECLIENTE) {
      setToast({ mensaje: "Ingresa el cliente.", tipo: "error" });
      return;
    }
    if (!detalle.length) {
      setToast({ mensaje: "Agrega al menos un producto.", tipo: "error" });
      return;
    }
    const inicial = Number(form.MONTOINICIAL || 0);
    if (modo === "crear" && (Number.isNaN(inicial) || inicial < 0)) {
      setToast({ mensaje: "El monto inicial no es válido.", tipo: "error" });
      return;
    }
    if (modo === "crear" && inicial > total + 0.009) {
      setToast({ mensaje: "El monto inicial no puede ser mayor al total.", tipo: "error" });
      return;
    }
    if (modo === "crear" && inicial > 0 && !form.IDFORMAPAGOINICIAL) {
      setToast({ mensaje: "Selecciona el método de pago del abono inicial.", tipo: "error" });
      return;
    }
    const payload = {
      ...form,
      ...cliente,
      DETALLE: detalle.filter((l) => l.IDPRODUCTO),
      MONTOINICIAL: modo === "crear" ? inicial : undefined,
      IDFORMAPAGOINICIAL: modo === "crear" && inicial > 0 ? form.IDFORMAPAGOINICIAL : undefined,
    };
    setEnviando(true);
    try {
      if (modo === "crear") {
        const res = await fetch("/api/cotizaciones/", {
          method: "POST",
          headers: actorHeaders(),
          body: JSON.stringify(payload),
        });
        const data = await parseJsonResponse(res);
        if (!res.ok || !data.ok) throw new Error(data.mensaje || data.error || "No se pudo guardar");
        setToast({ mensaje: data.mensaje, tipo: "success" });
        setVista("lista");
        await crud.listar();
        if (data.id) {
          setModoEnvio("guardar");
          setPedido({ IDCOTIZACION: data.id });
          setEnvio(envioVacio());
        }
      } else {
        const mensaje = await crud.actualizar(form.IDCOTIZACION, payload);
        setToast({ mensaje, tipo: "success" });
        setVista("lista");
        await crud.listar();
      }
    } catch (err) { setToast({ mensaje: err.message, tipo: "error" }); }
    finally { setEnviando(false); }
  };

  const abrirEnvio = async (row, modo = "pedido") => {
    setModoEnvio(modo);
    let data = row;
    try {
      data = await crud.obtener(row.IDCOTIZACION);
    } catch { data = row; }
    setPedido(data);
    setEnvio({
      IDFORMAPAGO: data.IDFORMAPAGO || "",
      IDTIPOENTREGA: data.IDTIPOENTREGA || "",
      DIRECCIONENTREGA: data.DIRECCIONENTREGA || "",
      COSTODELIVERY: data.COSTODELIVERY ?? 0,
    });
  };

  const validarEnvio = () => {
    if (!envio.IDTIPOENTREGA) {
      setToast({ mensaje: "Selecciona el tipo de entrega.", tipo: "error" });
      return false;
    }
    if (requiereDirEnvio && !String(envio.DIRECCIONENTREGA || "").trim()) {
      setToast({ mensaje: "Ingresa la dirección de delivery.", tipo: "error" });
      return false;
    }
    return true;
  };

  const guardarEnvio = async () => {
    if (!pedido || !validarEnvio()) return;
    try {
      setEnviando(true);
      const res = await fetch(`/api/cotizaciones/${encodeURIComponent(pedido.IDCOTIZACION)}/envio/`, {
        method: "POST",
        headers: actorHeaders(),
        body: JSON.stringify({
          IDFORMAPAGO: envio.IDFORMAPAGO || null,
          IDTIPOENTREGA: envio.IDTIPOENTREGA,
          DIRECCIONENTREGA: envio.DIRECCIONENTREGA || null,
          COSTODELIVERY: envio.COSTODELIVERY || 0,
        }),
      });
      const data = await parseJsonResponse(res);
      if (!res.ok || !data.ok) throw new Error(data.mensaje || data.error || "No se pudieron guardar los datos de envío");
      setToast({ mensaje: data.mensaje, tipo: "success" });
      setPedido(null);
      await crud.listar();
    } catch (err) { setToast({ mensaje: err.message, tipo: "error" }); }
    finally { setEnviando(false); }
  };

  const hacerPedido = async () => {
    if (!validarEnvio()) return;
    try {
      setEnviando(true);
      const res = await fetch(`/api/cotizaciones/${encodeURIComponent(pedido.IDCOTIZACION)}/hacer-pedido/`, {
        method: "POST",
        headers: actorHeaders(),
        body: JSON.stringify({
          IDFORMAPAGO: envio.IDFORMAPAGO || null,
          IDTIPOENTREGA: envio.IDTIPOENTREGA,
          DIRECCIONENTREGA: envio.DIRECCIONENTREGA || null,
          COSTODELIVERY: envio.COSTODELIVERY || 0,
        }),
      });
      const data = await parseJsonResponse(res);
      if (!res.ok || !data.ok) throw new Error(data.mensaje || data.error || "No se pudo convertir");
      setToast({ mensaje: data.mensaje, tipo: "success" });
      setPedido(null);
      setVista("lista");
      await crud.listar();
      if (onChangePage) onChangePage("ventas");
    } catch (err) { setToast({ mensaje: err.message, tipo: "error" }); }
    finally { setEnviando(false); }
  };

  const verDocumento = async (row) => {
    try {
      const cab = await crud.obtener(row.IDCOTIZACION);
      await abrirVistaDocumento(cab, { tipo: "cotizacion", mostrarAbonos: false });
    } catch (err) {
      setToast({ mensaje: err.message, tipo: "error" });
    }
  };

  const abrirPagos = async (row, completar = false) => {
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
        headers: actorHeaders(),
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

  if (vista === "form") {
    const ro = modo === "ver";
    return (
      <div className="mantenedor-page">
        <PageHeader modulo="Cotizaciones" vista={modo === "crear" ? "Nueva cotización" : "Cotización"} mostrarNuevo={false} onIrListado={irListado} />
        <div className="cotiz-layout">
          <section className="cotiz-carta">
            <div className="cotiz-search">
              <FontAwesomeIcon icon={faSearch} />
              <input
                disabled={ro}
                value={buscaProd}
                onChange={(e) => setBuscaProd(e.target.value)}
                placeholder={phIngrese("producto")}
              />
            </div>
            <div className="cotiz-cats">
              <button type="button" className={!catFiltro ? "on" : ""} onClick={() => setCatFiltro("")}>Todos</button>
              {catalogos.categorias.map((c) => (
                <button key={c.value} type="button" className={String(catFiltro) === String(c.value) ? "on" : ""} onClick={() => setCatFiltro(c.value)}>
                  {c.label}
                </button>
              ))}
            </div>
            <div className="cotiz-grid">
              {productosFiltrados.map((p) => (
                <button
                  key={p.value}
                  type="button"
                  className="cotiz-card"
                  disabled={ro}
                  onClick={() => agregarProducto(p)}
                >
                  {p.FOTO
                    ? <img src={p.FOTO} alt="" className="cotiz-card-img" />
                    : <div className="cotiz-card-img cotiz-card-img--empty">Sin foto</div>}
                  <div className="cotiz-card-body">
                    <strong>{p.label}</strong>
                    {p.DESCRIPCION ? <span className="cotiz-card-desc">{p.DESCRIPCION}</span> : null}
                    <span className="cotiz-card-precio">{money(p.PRECIO)}</span>
                  </div>
                </button>
              ))}
              {!productosFiltrados.length && <p className="cotiz-empty">No hay productos para mostrar.</p>}
            </div>
          </section>

          <aside className="cotiz-pedido">
            <h3>Cotización actual</h3>
            <label className="cotiz-label">Cliente
              <ClienteSuggest
                disabled={ro}
                value={form.NOMBRECLIENTE || ""}
                placeholder={phIngrese("cliente")}
                onChange={(nombre, id) => setForm({ ...form, NOMBRECLIENTE: nombre, IDCLIENTE: id || "" })}
              />
            </label>
            <label className="cotiz-label">Estado
              <select disabled={ro} value={form.ESTADO || "Deuda"} onChange={(e) => setForm({ ...form, ESTADO: e.target.value })}>
                <option value="">{phSeleccione("estado")}</option>
                {(ESTADOS.includes(form.ESTADO) || !form.ESTADO ? ESTADOS : [form.ESTADO, ...ESTADOS]).map((e) => <option key={e}>{e}</option>)}
              </select>
            </label>
            {modo === "crear" && (
              <>
                <label className="cotiz-label">Monto inicial
                  <input
                    type="number"
                    min="0"
                    step="0.01"
                    value={form.MONTOINICIAL ?? ""}
                    placeholder={phIngrese("monto inicial")}
                    onChange={(e) => setForm({ ...form, MONTOINICIAL: e.target.value, IDFORMAPAGOINICIAL: Number(e.target.value) > 0 ? form.IDFORMAPAGOINICIAL : "" })}
                  />
                  <small className="cotiz-hint">Abono para separar la cotización. Si cubre el total queda Pagado; si no, Deuda.</small>
                </label>
                {Number(form.MONTOINICIAL || 0) > 0 && (
                  <label className="cotiz-label">Método de pago
                    <select value={form.IDFORMAPAGOINICIAL || ""} onChange={(e) => setForm({ ...form, IDFORMAPAGOINICIAL: e.target.value })}>
                      <option value="">{phSeleccione("método de pago")}</option>
                      {catalogos.formasPago.map((f) => <option key={f.value} value={f.value}>{f.label}</option>)}
                    </select>
                  </label>
                )}
              </>
            )}

            <div className="cotiz-lineas">
              {detalle.length === 0 && <p className="cotiz-empty">Toca un producto para agregarlo.</p>}
              {detalle.map((l) => (
                <div key={l.IDPRODUCTO} className="cotiz-linea">
                  <div className="cotiz-linea-info">
                    <strong>{l.PRODUCTO_NOMBRE || catalogos.productos.find((p) => String(p.value) === String(l.IDPRODUCTO))?.label}</strong>
                    {!ro && (
                      <div className="cotiz-qty">
                        <button type="button" onClick={() => setCantidad(l.IDPRODUCTO, Number(l.CANTIDAD) - 1)}><FontAwesomeIcon icon={faMinus} /></button>
                        <input type="number" min="1" value={l.CANTIDAD} onChange={(e) => setCantidad(l.IDPRODUCTO, e.target.value)} />
                        <button type="button" onClick={() => setCantidad(l.IDPRODUCTO, Number(l.CANTIDAD) + 1)}><FontAwesomeIcon icon={faPlus} /></button>
                        <button type="button" className="danger" onClick={() => setDetalle((d) => d.filter((x) => String(x.IDPRODUCTO) !== String(l.IDPRODUCTO)))}>
                          <FontAwesomeIcon icon={faTrash} />
                        </button>
                      </div>
                    )}
                    {ro && <span>x {l.CANTIDAD}</span>}
                  </div>
                  <div className="cotiz-linea-precio">
                    {ro ? (
                      <span>{money(l.PRECIOUNITARIO)}</span>
                    ) : (
                      <input
                        type="number"
                        min="0"
                        step="0.01"
                        value={l.PRECIOUNITARIO}
                        placeholder={phIngrese("precio")}
                        onChange={(e) => setPrecio(l.IDPRODUCTO, e.target.value)}
                      />
                    )}
                    <strong>{money(Number(l.CANTIDAD || 0) * Number(l.PRECIOUNITARIO || 0))}</strong>
                  </div>
                </div>
              ))}
            </div>

            <label className="cotiz-label">Notas
              <textarea disabled={ro} rows={3} value={form.OBSERVACIONES || ""} placeholder={phIngrese("notas")} onChange={(e) => setForm({ ...form, OBSERVACIONES: e.target.value })} />
            </label>

            <div className="cotiz-totales">
              {modo !== "crear" && form.ABONADO != null && (
                <>
                  <div><span>Abonado</span><strong>{money(form.ABONADO)}</strong></div>
                  <div><span>Saldo</span><strong>{money(form.SALDO)}</strong></div>
                </>
              )}
              {modo === "crear" && Number(form.MONTOINICIAL || 0) > 0 && (
                <>
                  <div><span>Monto inicial</span><strong>{money(form.MONTOINICIAL)}</strong></div>
                  <div><span>Saldo</span><strong>{money(Math.max(0, total - Number(form.MONTOINICIAL || 0)))}</strong></div>
                </>
              )}
              <div className="cotiz-total"><span>Total</span><strong>{money(total)}</strong></div>
            </div>
            <div className="cotiz-acciones">
              <button type="button" className="btn-secondary" onClick={() => setVista("lista")}>{ro ? "Cerrar" : "Cancelar"}</button>
              {!ro && <button type="button" className="btn-primary" disabled={enviando} onClick={guardar}>Guardar cotización</button>}
              {modo === "ver" && form.ESTADO !== "Anulada" && (
                <button type="button" className="btn-primary" disabled={enviando} onClick={() => abrirEnvio(form, "pedido")}>Pasar a pedido</button>
              )}
            </div>
          </aside>
        </div>
        {toast && <Toast mensaje={toast.mensaje} tipo={toast.tipo} onClose={() => setToast(null)} />}
        <EnvioModal
          pedido={pedido} envio={envio} setEnvio={setEnvio} catalogos={catalogos}
          requiereDirEnvio={requiereDirEnvio} enviando={enviando} modoEnvio={modoEnvio}
          onCancel={() => setPedido(null)}
          onConfirm={modoEnvio === "guardar" ? guardarEnvio : hacerPedido}
        />
        <PagosModal
          data={pagosData} abono={abono} setAbono={setAbono} abonoForma={abonoForma} setAbonoForma={setAbonoForma}
          formasPago={catalogos.formasPago} enviando={enviando} focusAbono={focusAbono}
          onCancel={() => setPagosData(null)} onRegistrar={registrarAbono}
        />
      </div>
    );
  }

  return (
    <div className="mantenedor-page">
      <PageHeader modulo="Cotizaciones" vista="Listado" onNuevo={abrirCrear} onIrListado={irListado} />
      <div className="mantenedor-card">
        <Toolbar
          buscar={crud.buscar} onBuscarChange={crud.onBuscarChange}
          filtros={[{
            key: "estado", etiqueta: "Estado", value: crud.filtros.estado || "",
            opciones: ESTADOS,
            onChange: (v) => crud.setFiltro("estado", v),
          }]}
        />
        <DataTable
          columnas={columnas} items={crud.items} pk="IDCOTIZACION" orden={crud.orden}
          loading={crud.loading} error={crud.error} onOrden={crud.toggleOrden}
          onVer={verDocumento} onEditar={(r) => abrirEditar(r, false)}
          onPagos={(r) => abrirPagos(r, Number(r.SALDO) > 0)}
          onHacerPedido={(r) => abrirEnvio(r, "pedido")}
          onAnular={(r) => setConfirm({ tipo: "anular", id: r.IDCOTIZACION, mensaje: `¿Anular ${r.IDCOTIZACION}? El stock volverá al almacén.` })}
          onEliminar={(r) => setConfirm({ tipo: "eliminar", id: r.IDCOTIZACION, mensaje: `¿Eliminar ${r.IDCOTIZACION}?` })}
          onReintentar={crud.listar} pagina={crud.pagina} tamanio={crud.tamanio}
        />
        <Pagination pagina={crud.pagina} tamanio={crud.tamanio} total={crud.total} onChange={crud.setPagina} />
      </div>
      <ConfirmDialog abierto={Boolean(confirm)} titulo={confirm?.tipo === "anular" ? "Anular" : "Eliminar"} mensaje={confirm?.mensaje}
        onCancel={() => setConfirm(null)}
        onConfirm={async () => {
          try {
            if (confirm.tipo === "anular") {
              const res = await fetch(`/api/cotizaciones/${encodeURIComponent(confirm.id)}/anular/`, {
                method: "POST",
                headers: actorHeaders(),
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
      <EnvioModal
        pedido={pedido} envio={envio} setEnvio={setEnvio} catalogos={catalogos}
        requiereDirEnvio={requiereDirEnvio} enviando={enviando} modoEnvio={modoEnvio}
        onCancel={() => setPedido(null)}
        onConfirm={modoEnvio === "guardar" ? guardarEnvio : hacerPedido}
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

import { useState } from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faSpinner, faTimes } from "@fortawesome/free-solid-svg-icons";
import { useCrud } from "../../hooks/useCrud";
import { dbToView } from "../../utils/fecha";
import PageHeader from "../../components/mantenedor/PageHeader";
import Toolbar from "../../components/mantenedor/Toolbar";
import DataTable from "../../components/mantenedor/DataTable";
import Pagination from "../../components/mantenedor/Pagination";
import "../../styles/mantenedor.css";
import "./pago.css";

const columnas = [
  { campo: "IDPAGO", etiqueta: "Código", ordenable: true },
  { campo: "IDCOTIZACION", etiqueta: "Cotización", ordenable: true },
  { campo: "CLIENTE_NOMBRE", etiqueta: "Cliente", ordenable: true },
  { campo: "MONTO", etiqueta: "Monto", tipo: "decimal", ordenable: true },
  { campo: "TIPO", etiqueta: "Tipo", ordenable: true },
  { campo: "FORMAPAGO_NOMBRE", etiqueta: "Método", ordenable: true },
  { campo: "FECHA", etiqueta: "Fecha", tipo: "fecha", ordenable: true },
  { campo: "HORA", etiqueta: "Hora", ordenable: true },
  { campo: "CREADOPOR_NOMBRE", etiqueta: "Registró", ordenable: false },
];

function money(n) {
  return `S/ ${Number(n || 0).toLocaleString("es-PE", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function claseEstado(estado) {
  const v = String(estado || "").toLowerCase();
  if (["activo", "pagado", "convertida"].includes(v)) return "activo";
  if (["anulada", "anulado", "inactivo"].includes(v)) return "inactivo";
  return "vencido";
}

function PagoDetalleModal({ abierto, registro, loading, onClose }) {
  if (!abierto) return null;
  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-panel pago-detalle-modal" onClick={(e) => e.stopPropagation()} role="dialog" aria-modal="true">
        <div className="modal-header">
          <h2>Detalle del pago</h2>
          <button type="button" className="btn-icon" onClick={onClose} aria-label="Cerrar">
            <FontAwesomeIcon icon={faTimes} />
          </button>
        </div>
        <div className="modal-body">
          {loading ? (
            <div className="mantenedor-state">
              <FontAwesomeIcon icon={faSpinner} spin /> Cargando detalle...
            </div>
          ) : !registro ? (
            <div className="mantenedor-state">No se encontró el pago.</div>
          ) : (
            <>
              <dl className="pago-meta">
                <div className="pago-meta-item">
                  <dt>Código</dt>
                  <dd>{registro.IDPAGO || "—"}</dd>
                </div>
                <div className="pago-meta-item">
                  <dt>Tipo</dt>
                  <dd>{registro.TIPO || "Abono"}</dd>
                </div>
                <div className="pago-meta-item">
                  <dt>Método de pago</dt>
                  <dd>{registro.FORMAPAGO_NOMBRE || "—"}</dd>
                </div>
                <div className="pago-meta-item">
                  <dt>Monto</dt>
                  <dd className="pago-meta-monto">{money(registro.MONTO)}</dd>
                </div>
                <div className="pago-meta-item">
                  <dt>Cotización</dt>
                  <dd>{registro.IDCOTIZACION || "—"}</dd>
                </div>
                <div className="pago-meta-item">
                  <dt>Cliente</dt>
                  <dd>{registro.CLIENTE_NOMBRE || "—"}</dd>
                </div>
                <div className="pago-meta-item">
                  <dt>Estado cotización</dt>
                  <dd>
                    <span className={`badge-estado ${claseEstado(registro.COTIZACION_ESTADO)}`}>
                      {registro.COTIZACION_ESTADO || "—"}
                    </span>
                  </dd>
                </div>
                <div className="pago-meta-item">
                  <dt>Pedido asociado</dt>
                  <dd>{registro.IDVENTA || "—"}</dd>
                </div>
                <div className="pago-meta-item">
                  <dt>Registró</dt>
                  <dd>{registro.CREADOPOR_NOMBRE || registro.CREADOPOR || "—"}</dd>
                </div>
                <div className="pago-meta-item">
                  <dt>Fecha / Hora</dt>
                  <dd>{dbToView(String(registro.FECHA || "")) || "—"} {registro.HORA || ""}</dd>
                </div>
                <div className="pago-meta-item">
                  <dt>Modificó</dt>
                  <dd>{registro.MODIFICADOPOR_NOMBRE || registro.MODIFICADOPOR || "—"}</dd>
                </div>
                <div className="pago-meta-item">
                  <dt>Última modificación</dt>
                  <dd>
                    {dbToView(String(registro.FECHAMODIFICACION || "")) || "—"} {registro.HORAMODIFICACION || ""}
                  </dd>
                </div>
              </dl>
              <div className="pago-resumen">
                <div><span>Total cotización</span><strong>{money(registro.COTIZACION_TOTAL)}</strong></div>
                <div><span>Abonado</span><strong>{money(registro.ABONADO)}</strong></div>
                <div><span>Saldo</span><strong>{money(registro.SALDO)}</strong></div>
              </div>
            </>
          )}
        </div>
        <div className="modal-footer">
          <button type="button" className="btn-secondary" onClick={onClose}>Cerrar</button>
        </div>
      </div>
    </div>
  );
}

export default function PagoPage() {
  const crud = useCrud({
    entidad: "pagos",
    pk: "IDPAGO",
    ordenInicial: { campo: "FECHA", direccion: "DESC" },
    filtrosIniciales: { tipo: "" },
  });
  const [detalleAbierto, setDetalleAbierto] = useState(false);
  const [detalleLoading, setDetalleLoading] = useState(false);
  const [detalle, setDetalle] = useState(null);

  const abrirDetalle = async (row) => {
    setDetalleAbierto(true);
    setDetalleLoading(true);
    setDetalle(null);
    try {
      setDetalle(await crud.obtener(row.IDPAGO));
    } catch {
      setDetalle(null);
    } finally {
      setDetalleLoading(false);
    }
  };

  return (
    <div className="mantenedor-page">
      <PageHeader modulo="Pagos" vista="Listado" mostrarNuevo={false} />
      <div className="mantenedor-card">
        <Toolbar
          buscar={crud.buscar}
          onBuscarChange={crud.onBuscarChange}
          placeholder="INGRESE BUSCAR"
          filtros={[{
            key: "tipo",
            etiqueta: "tipo",
            value: crud.filtros.tipo || "",
            opciones: ["Inicial", "Abono"],
            onChange: (v) => crud.setFiltro("tipo", v),
          }]}
        />
        <DataTable
          columnas={columnas} items={crud.items} pk="IDPAGO" orden={crud.orden}
          loading={crud.loading} error={crud.error} onOrden={crud.toggleOrden}
          onVer={abrirDetalle} onReintentar={crud.listar}
          pagina={crud.pagina} tamanio={crud.tamanio}
          emptyMessage="No hay pagos registrados."
        />
        <Pagination pagina={crud.pagina} tamanio={crud.tamanio} total={crud.total} onChange={crud.setPagina} />
      </div>
      <PagoDetalleModal
        abierto={detalleAbierto} registro={detalle} loading={detalleLoading}
        onClose={() => setDetalleAbierto(false)}
      />
    </div>
  );
}

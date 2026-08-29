import { useEffect, useState } from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faSpinner, faTimes } from "@fortawesome/free-solid-svg-icons";
import { useCrud } from "../../hooks/useCrud";
import { parseJsonResponse } from "../../utils/api";
import { dbToView, dbToInput, inputToDb } from "../../utils/fecha";
import PageHeader from "../../components/mantenedor/PageHeader";
import Toolbar from "../../components/mantenedor/Toolbar";
import DataTable from "../../components/mantenedor/DataTable";
import Pagination from "../../components/mantenedor/Pagination";
import {
  auditoriaConfig,
  auditoriaColumnas,
  ACCIONES_AUDITORIA,
} from "./auditoria.config";
import "../../styles/mantenedor.css";
import "./auditoria.css";

function formatJson(value) {
  if (!value) return "—";
  try {
    const parsed = typeof value === "string" ? JSON.parse(value) : value;
    return JSON.stringify(parsed, null, 2);
  } catch {
    return String(value);
  }
}

function labelAccion(accion) {
  const a = String(accion || "").toUpperCase();
  if (a === "INSERT") return "Alta";
  if (a === "UPDATE") return "Modificación";
  if (a === "DELETE") return "Eliminación";
  return accion || "—";
}

function claseAccion(accion) {
  const a = String(accion || "").toUpperCase();
  if (a === "INSERT") return "insert";
  if (a === "UPDATE") return "update";
  if (a === "DELETE") return "delete";
  return "";
}

function AuditoriaDetalleModal({ abierto, registro, loading, onClose }) {
  if (!abierto) return null;
  const accion = String(registro?.ACCION || "").toUpperCase();
  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-panel auditoria-detalle-modal" onClick={(e) => e.stopPropagation()} role="dialog" aria-modal="true">
        <div className="modal-header">
          <h2>Detalle de auditoría</h2>
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
            <div className="mantenedor-state">No se encontró el registro.</div>
          ) : (
            <>
              <dl className="auditoria-meta">
                <div className="auditoria-meta-item">
                  <dt>Fecha / Hora</dt>
                  <dd>{dbToView(String(registro.FECHA || "")) || "—"} {registro.HORA || ""}</dd>
                </div>
                <div className="auditoria-meta-item">
                  <dt>Tabla</dt>
                  <dd>{registro.TABLA || "—"}</dd>
                </div>
                <div className="auditoria-meta-item">
                  <dt>Acción</dt>
                  <dd>
                    <span className={`auditoria-accion auditoria-accion--${claseAccion(registro.ACCION)}`}>
                      {labelAccion(registro.ACCION)}
                    </span>
                  </dd>
                </div>
                <div className="auditoria-meta-item">
                  <dt>Usuario</dt>
                  <dd>{[registro.USUARIO_NOMBRE, registro.IDUSUARIO].filter(Boolean).join(" · ") || "—"}</dd>
                </div>
                <div className="auditoria-meta-item auditoria-meta-item--full">
                  <dt>ID registro</dt>
                  <dd className="auditoria-meta-id" title={registro.IDREGISTRO || ""}>{registro.IDREGISTRO || "—"}</dd>
                </div>
              </dl>
              <div className="auditoria-json-grid">
                {accion !== "INSERT" && (
                  <div className="auditoria-json-panel">
                    <h4>Datos anteriores</h4>
                    <pre>{formatJson(registro.DATOS_ANTES)}</pre>
                  </div>
                )}
                {accion !== "DELETE" && (
                  <div className="auditoria-json-panel">
                    <h4>Datos posteriores</h4>
                    <pre>{formatJson(registro.DATOS_DESPUES)}</pre>
                  </div>
                )}
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

export default function AuditoriaPage() {
  const cfg = auditoriaConfig;
  const crud = useCrud({
    entidad: cfg.entidad,
    pk: cfg.pk,
    ordenInicial: { campo: "FECHA", direccion: "DESC" },
    filtrosIniciales: { tabla: "", accion: "", fechaDesde: "", fechaHasta: "" },
  });
  const [tablas, setTablas] = useState([]);
  const [detalleAbierto, setDetalleAbierto] = useState(false);
  const [detalleLoading, setDetalleLoading] = useState(false);
  const [detalle, setDetalle] = useState(null);

  useEffect(() => {
    (async () => {
      try {
        const res = await fetch("/api/auditoria/catalogos/");
        const data = await parseJsonResponse(res);
        if (res.ok) setTablas(data.tablas || []);
      } catch {
        setTablas([]);
      }
    })();
  }, []);

  const abrirDetalle = async (row) => {
    setDetalleAbierto(true);
    setDetalleLoading(true);
    setDetalle(null);
    try {
      setDetalle(await crud.obtener(row[cfg.pk]));
    } catch {
      setDetalle(null);
    } finally {
      setDetalleLoading(false);
    }
  };

  return (
    <div className="mantenedor-page">
      <PageHeader modulo="Auditoría" vista="Listado" mostrarNuevo={false} />
      <div className="mantenedor-card">
        <Toolbar buscar={crud.buscar} onBuscarChange={crud.onBuscarChange} placeholder="Buscar tabla, registro, usuario..." />
        <div className="auditoria-filtros">
          <label>
            Tabla
            <select value={crud.filtros.tabla || ""} onChange={(e) => crud.setFiltro("tabla", e.target.value)}>
              <option value="">Todas las tablas</option>
              {tablas.map((t) => <option key={t} value={t}>{t}</option>)}
            </select>
          </label>
          <label>
            Acción
            <select value={crud.filtros.accion || ""} onChange={(e) => crud.setFiltro("accion", e.target.value)}>
              {ACCIONES_AUDITORIA.map((a) => (
                <option key={a.value || "all"} value={a.value}>{a.label}</option>
              ))}
            </select>
          </label>
          <label>
            Desde
            <input type="date" value={dbToInput(crud.filtros.fechaDesde || "")} onChange={(e) => crud.setFiltro("fechaDesde", inputToDb(e.target.value) || "")} />
          </label>
          <label>
            Hasta
            <input type="date" value={dbToInput(crud.filtros.fechaHasta || "")} onChange={(e) => crud.setFiltro("fechaHasta", inputToDb(e.target.value) || "")} />
          </label>
        </div>
        <DataTable
          columnas={auditoriaColumnas} items={crud.items} pk={cfg.pk} orden={crud.orden}
          loading={crud.loading} error={crud.error} onOrden={crud.toggleOrden}
          onVer={abrirDetalle} onReintentar={crud.listar} pagina={crud.pagina} tamanio={crud.tamanio}
        />
        <Pagination pagina={crud.pagina} tamanio={crud.tamanio} total={crud.total} onChange={crud.setPagina} />
      </div>
      <AuditoriaDetalleModal abierto={detalleAbierto} registro={detalle} loading={detalleLoading} onClose={() => setDetalleAbierto(false)} />
    </div>
  );
}

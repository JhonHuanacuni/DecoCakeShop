import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faEye, faPencil, faTrash, faSort, faSortUp, faSortDown, faCartShopping, faBan, faReceipt, faFilePdf } from "@fortawesome/free-solid-svg-icons";
import { dbToView } from "../../utils/fecha";

function renderCell(col, row, index = 0, offset = 0, pk = "") {
  if (col.tipo === "numero") return offset + index + 1;
  const value = row[col.campo];
  if (value == null || value === "") return "—";
  if (col.tipo === "estado") {
    const conDeuda = pk === "IDVENTA" && Number(row.SALDO) > 0.009 && !["Anulado", "Anulada"].includes(row.ESTADO);
    const etiqueta = conDeuda ? `${value} (con deuda)` : value;
    const v = String(value).toLowerCase();
    const clase = conDeuda ? "vencido"
      : ["activo", "pagado", "convertida", "aceptado", "empaquetado", "enviado"].includes(v) ? "activo"
        : ["anulada", "anulado", "inactivo", "borrador"].includes(v) ? "inactivo"
          : "vencido";
    return <span className={`badge-estado ${clase}`}>{etiqueta}</span>;
  }
  if (col.tipo === "fecha") return dbToView(String(value));
  if (col.tipo === "decimal") {
    const n = Number(value);
    if (Number.isNaN(n)) return String(value);
    if (col.porcentajeSi && String(row[col.porcentajeSi] || "") === "Porcentaje") {
      return `${n.toLocaleString("es-PE", { maximumFractionDigits: 2 })}%`;
    }
    return `S/ ${n.toLocaleString("es-PE", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
  }
  if (col.tipo === "accionAuditoria") {
    const accion = String(value || "").toUpperCase();
    const clase = accion === "INSERT" ? "insert" : accion === "UPDATE" ? "update" : accion === "DELETE" ? "delete" : "";
    const label = accion === "INSERT" ? "Alta" : accion === "UPDATE" ? "Modificación" : accion === "DELETE" ? "Eliminación" : accion;
    return <span className={`auditoria-accion auditoria-accion--${clase}`}>{label}</span>;
  }
  return String(value);
}

function SortIcon({ col, orden }) {
  if (!col.ordenable) return null;
  if (orden.campo !== col.campo) return <FontAwesomeIcon icon={faSort} />;
  return <FontAwesomeIcon icon={orden.direccion === "ASC" ? faSortUp : faSortDown} />;
}

export default function DataTable({
  columnas, items, pk, orden, loading, error, onOrden, onVer, onEditar, onEliminar,
  onHacerPedido, onAnular, onPagos, onExportarPdf, onReintentar, pagina = 1, tamanio = 10,
  emptyMessage = "No hay registros. Crea el primero.",
}) {
  const mostrarAcciones = Boolean(onVer || onEditar || onEliminar || onHacerPedido || onAnular || onPagos || onExportarPdf);
  const offset = Math.max(0, (pagina - 1) * tamanio);
  if (loading) {
    return (
      <div className="data-table-wrap">
        <table className="data-table">
          <thead><tr>{columnas.map((c) => <th key={c.campo}>{c.etiqueta}</th>)}{mostrarAcciones && <th className="col-actions">Acciones</th>}</tr></thead>
          <tbody>
            {Array.from({ length: 5 }).map((_, i) => (
              <tr key={i} className="skeleton-row">
                {columnas.map((c) => <td key={c.campo}><div className="skeleton-bar" /></td>)}
                {mostrarAcciones && <td><div className="skeleton-bar" /></td>}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    );
  }
  if (error) {
    return (
      <div className="mantenedor-state error">
        <p>{error}</p>
        <button type="button" className="btn-secondary" onClick={onReintentar}>Reintentar</button>
      </div>
    );
  }
  if (!items.length) {
    return <div className="mantenedor-state"><p>{emptyMessage}</p></div>;
  }
  return (
    <div className="data-table-wrap">
      <table className="data-table">
        <thead>
          <tr>
            {columnas.map((col) => (
              <th key={col.campo} className={col.ordenable ? "sortable" : ""} onClick={() => col.ordenable && onOrden(col.campo)}>
                {col.etiqueta} <SortIcon col={col} orden={orden} />
              </th>
            ))}
            {mostrarAcciones && <th className="col-actions">Acciones</th>}
          </tr>
        </thead>
        <tbody>
          {items.map((row, index) => (
            <tr key={row[pk]}>
              {columnas.map((col) => <td key={col.campo}>{renderCell(col, row, index, offset, pk)}</td>)}
              {mostrarAcciones && (
                <td className="col-actions">
                  {onVer && <button type="button" className="btn-icon" title="Ver" onClick={() => onVer(row)}><FontAwesomeIcon icon={faEye} /></button>}
                  {onExportarPdf && (
                    <button type="button" className="btn-icon" title="Exportar PDF" onClick={() => onExportarPdf(row)}>
                      <FontAwesomeIcon icon={faFilePdf} />
                    </button>
                  )}
                  {onPagos && (pk !== "IDVENTA" || Number(row.SALDO) > 0.009) && (
                    <button type="button" className="btn-icon" title="Ver pagos" onClick={() => onPagos(row)}>
                      <FontAwesomeIcon icon={faReceipt} />
                    </button>
                  )}
                  {onEditar && (!onAnular || !["Anulada", "Anulado"].includes(row.ESTADO)) && (
                    <button type="button" className="btn-icon" title="Editar" onClick={() => onEditar(row)}><FontAwesomeIcon icon={faPencil} /></button>
                  )}
                  {onHacerPedido && !["Anulada", "Anulado"].includes(row.ESTADO) && (
                    <button type="button" className="btn-icon" title="Hacer pedido" onClick={() => onHacerPedido(row)}>
                      <FontAwesomeIcon icon={faCartShopping} />
                    </button>
                  )}
                  {onAnular && !["Anulada", "Anulado"].includes(row.ESTADO) && (
                    <button type="button" className="btn-icon danger" title="Anular" onClick={() => onAnular(row)}>
                      <FontAwesomeIcon icon={faBan} />
                    </button>
                  )}
                  {onEliminar && (!onAnular || ["Anulada", "Anulado"].includes(row.ESTADO)) && (
                    <button type="button" className="btn-icon danger" title="Eliminar" onClick={() => onEliminar(row)}>
                      <FontAwesomeIcon icon={faTrash} />
                    </button>
                  )}
                </td>
              )}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

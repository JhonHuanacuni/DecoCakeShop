import { phIngrese, phSeleccione } from "../../utils/placeholder";
import { dbToView } from "../../utils/fecha";
import "./PagosModal.css";

function money(n) {
  return `S/ ${Number(n || 0).toFixed(2)}`;
}

export default function PagosModal({
  data, abono, setAbono, abonoForma, setAbonoForma, formasPago, enviando, focusAbono, onCancel, onRegistrar,
}) {
  if (!data) return null;
  const saldo = Number(data.SALDO || 0);
  const cerrado = data.ESTADO === "Anulada";
  const puedeAbonar = !cerrado && saldo > 0.009;
  return (
    <div className="modal-overlay">
      <div className="modal-panel">
        <div className="modal-header">
          <h2>Pagos de {data.IDCOTIZACION}</h2>
        </div>
        <div className="modal-body">
          <p className="pagos-cliente">{data.CLIENTE_NOMBRE || "—"} · {data.ESTADO}</p>
          <div className="pagos-resumen">
            <div><span>Total</span><strong>{money(data.TOTAL)}</strong></div>
            <div><span>Abonado</span><strong>{money(data.ABONADO)}</strong></div>
            <div><span>Saldo</span><strong>{money(data.SALDO)}</strong></div>
          </div>
          <div className="pagos-table-wrap">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Monto</th>
                  <th>Tipo</th>
                  <th>Pago</th>
                  <th>Registró</th>
                  <th>Modificó</th>
                  <th>Fecha</th>
                  <th>Hora</th>
                </tr>
              </thead>
              <tbody>
                {(data.PAGOS || []).length === 0 && (
                  <tr><td colSpan={7}>Aún no hay pagos registrados.</td></tr>
                )}
                {(data.PAGOS || []).map((p) => (
                  <tr key={p.IDPAGO}>
                    <td>{money(p.MONTO)}</td>
                    <td>{p.TIPO || "Abono"}</td>
                    <td>{p.FORMAPAGO_NOMBRE || "—"}</td>
                    <td>{p.CREADOPOR_NOMBRE || p.CREADOPOR || "—"}</td>
                    <td>{p.MODIFICADOPOR_NOMBRE || p.MODIFICADOPOR || "—"}</td>
                    <td>{dbToView(String(p.FECHAMODIFICACION || "")) || "—"}</td>
                    <td>{p.HORAMODIFICACION || "—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {puedeAbonar && (
            <div className="pagos-abono">
              <h3>Completar pago</h3>
              <div className="pagos-abono-row">
                <label className="cotiz-label">Monto del abono
                  <input
                    autoFocus={focusAbono}
                    type="number"
                    min="0.01"
                    step="0.01"
                    max={saldo}
                    value={abono}
                    placeholder={phIngrese("monto del abono")}
                    onChange={(e) => setAbono(e.target.value)}
                  />
                </label>
                <label className="cotiz-label">Método de pago
                  <select value={abonoForma} onChange={(e) => setAbonoForma(e.target.value)}>
                    <option value="">{phSeleccione("método de pago")}</option>
                    {(formasPago || []).map((f) => <option key={f.value} value={f.value}>{f.label}</option>)}
                  </select>
                </label>
                <button type="button" className="btn-primary" disabled={enviando} onClick={onRegistrar}>
                  Registrar abono
                </button>
              </div>
            </div>
          )}
          {cerrado && <p className="cotiz-empty">No se pueden registrar abonos en una cotización {String(data.ESTADO).toLowerCase()}.</p>}
          {!cerrado && saldo <= 0.009 && (data.PAGOS || []).length > 0 && (
            <p className="cotiz-empty">Esta cotización ya está pagada por completo.</p>
          )}
        </div>
        <div className="modal-footer">
          <button type="button" className="btn-secondary" onClick={onCancel}>Cerrar</button>
        </div>
      </div>
    </div>
  );
}

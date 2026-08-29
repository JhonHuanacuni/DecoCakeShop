import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import {
  faBox, faBoxesStacked, faFileInvoice, faCashRegister, faUsers, faWallet,
} from "@fortawesome/free-solid-svg-icons";

const ICONS = {
  productos: faBox,
  stock: faBoxesStacked,
  cotizaciones: faFileInvoice,
  ventas: faCashRegister,
  clientes: faUsers,
  cobrado: faWallet,
};

export default function DashboardKpi({ items }) {
  if (!items?.length) return null;
  return (
    <div className="dash-kpis">
      {items.map((item) => (
        <article key={item.key} className={`dash-kpi dash-kpi--${item.tono || "primary"}`}>
          <div className="dash-kpi-icon">
            <FontAwesomeIcon icon={ICONS[item.icon] || faBox} />
          </div>
          <div className="dash-kpi-body">
            <span className="dash-kpi-valor">{item.valor}</span>
            <span className="dash-kpi-label">{item.etiqueta}</span>
          </div>
        </article>
      ))}
    </div>
  );
}

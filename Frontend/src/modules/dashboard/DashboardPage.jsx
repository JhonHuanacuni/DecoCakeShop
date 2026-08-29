import { useEffect, useState } from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faSpinner } from "@fortawesome/free-solid-svg-icons";
import { parseJsonResponse } from "../../utils/api";
import DashboardKpi from "./DashboardKpi";
import "../../styles/mantenedor.css";
import "./dashboard.css";

function formatMoney(value) {
  return new Intl.NumberFormat("es-PE", {
    style: "currency",
    currency: "PEN",
    minimumFractionDigits: 2,
  }).format(Number(value || 0));
}

export default function DashboardPage() {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    (async () => {
      try {
        const res = await fetch("/api/dashboard/");
        const json = await parseJsonResponse(res);
        if (!res.ok) throw new Error(json.error || "No se pudo cargar el dashboard");
        setData(json.data || {});
      } catch (err) {
        setError(err.message || "Error al cargar");
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const kpis = data ? [
    { key: "prod", valor: data.PRODUCTOS_ACTIVOS ?? 0, etiqueta: "Productos activos", icon: "productos", tono: "primary" },
    { key: "stock", valor: data.STOCK_TOTAL ?? 0, etiqueta: "Stock total", icon: "stock", tono: "asist" },
    { key: "cot", valor: data.COTIZACIONES_ABIERTAS ?? 0, etiqueta: "Cotizaciones abiertas", icon: "cotizaciones", tono: "warn" },
    { key: "ventas", valor: data.VENTAS_HOY ?? 0, etiqueta: "Pedidos de hoy", icon: "ventas", tono: "primary" },
    { key: "monto", valor: formatMoney(data.MONTO_HOY), etiqueta: "Monto cobrado hoy", icon: "cobrado", tono: "money" },
    { key: "cli", valor: data.CLIENTES_ACTIVOS ?? 0, etiqueta: "Clientes activos", icon: "clientes", tono: "asist" },
  ] : [];

  return (
    <div className="dashboard-page">
      <div className="page-header">
        <h1>Dashboard</h1>
        <p>Resumen operativo de la importadora.</p>
      </div>
      {loading ? (
        <div className="dash-panel"><FontAwesomeIcon icon={faSpinner} spin /> Cargando...</div>
      ) : error ? (
        <div className="dash-panel"><p className="dash-error">{error}</p></div>
      ) : (
        <DashboardKpi items={kpis} />
      )}
    </div>
  );
}

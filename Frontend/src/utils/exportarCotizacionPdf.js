import logoImg from "../images/LogoDecoCakeShop.png";
import { dbToView } from "./fecha";

function esc(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function money(n) {
  return `S/ ${Number(n || 0).toLocaleString("es-PE", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function toDataUrl(src) {
  return fetch(src)
    .then((res) => res.blob())
    .then((blob) => new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result);
      reader.onerror = reject;
      reader.readAsDataURL(blob);
    }))
    .catch(() => "");
}

function nowView() {
  const d = new Date();
  const pad = (n) => String(n).padStart(2, "0");
  return `${pad(d.getDate())}/${pad(d.getMonth() + 1)}/${d.getFullYear()} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
}

function filasProductos(detalle) {
  const rows = (detalle || []).filter((l) => l.IDPRODUCTO);
  if (!rows.length) {
    return `<tr><td colspan="5" class="vacio">Sin productos</td></tr>`;
  }
  return rows.map((l, i) => {
    const cant = Number(l.CANTIDAD || 0);
    const precio = Number(l.PRECIOUNITARIO || 0);
    const sub = Number(l.SUBTOTAL != null ? l.SUBTOTAL : cant * precio);
    return `<tr>
      <td class="num">${i + 1}</td>
      <td>${esc(l.PRODUCTO_NOMBRE || l.IDPRODUCTO)}</td>
      <td class="der">${cant.toLocaleString("es-PE", { maximumFractionDigits: 2 })}</td>
      <td class="der">${esc(money(precio))}</td>
      <td class="der"><strong>${esc(money(sub))}</strong></td>
    </tr>`;
  }).join("");
}

function filasPagos(pagos) {
  return (pagos || []).map((p) => `<tr>
    <td>${esc(dbToView(String(p.FECHAMODIFICACION || p.FECHACREACION || "")) || "—")} ${esc(p.HORAMODIFICACION || p.HORACREACION || "")}</td>
    <td class="der"><strong>${esc(money(p.MONTO))}</strong></td>
  </tr>`).join("");
}

function estilos() {
  return `
    :root {
      --pink: #e1147a;
      --pink-soft: #fde8f2;
      --pink-head: #fce4ec;
      --teal: #2ec4d4;
      --brown: #4a2418;
      --text: #1c2333;
      --muted: #6b7280;
      --line: #ead5dc;
    }
    * { box-sizing: border-box; }
    html, body { margin: 0; padding: 0; }
    body {
      font-family: "Segoe UI", Arial, sans-serif;
      color: var(--text);
      background: #f6f7fb;
    }
    .toolbar {
      position: sticky;
      top: 0;
      z-index: 10;
      display: flex;
      justify-content: flex-end;
      padding: 10px 18px;
      background: #fff;
      border-bottom: 1px solid var(--line);
      box-shadow: 0 1px 6px rgba(20, 30, 60, 0.06);
    }
    .toolbar button {
      background: var(--pink);
      color: #fff;
      border: 0;
      border-radius: 8px;
      padding: 8px 16px;
      font-weight: 700;
      cursor: pointer;
      font-family: inherit;
    }
    .page {
      width: 210mm;
      min-height: 297mm;
      margin: 16px auto;
      padding: 14mm 14mm 22mm;
      background: #fff;
      box-shadow: 0 4px 24px rgba(20, 30, 60, 0.08);
    }
    .header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
      border-bottom: 3px solid var(--pink);
      padding-bottom: 12px;
    }
    .brand { display: flex; align-items: center; gap: 12px; min-width: 0; }
    .brand img { height: 64px; width: auto; }
    .brand h1 {
      margin: 0;
      font-size: 22px;
      color: var(--brown);
      letter-spacing: -0.02em;
    }
    .brand p { margin: 2px 0 0; color: var(--muted); font-size: 12px; }
    .doc-box {
      background: var(--pink);
      color: #fff;
      border-radius: 10px;
      padding: 10px 16px;
      text-align: right;
      min-width: 170px;
    }
    .doc-box span { display: block; font-size: 11px; letter-spacing: 0.12em; opacity: 0.9; }
    .doc-box strong { font-size: 18px; }
    .meta {
      width: 100%;
      border-collapse: collapse;
      margin: 14px 0 16px;
    }
    .meta th, .meta td {
      border: 1px solid var(--line);
      padding: 8px 10px;
      font-size: 12px;
      text-align: left;
    }
    .meta th {
      width: 22%;
      background: var(--pink-head);
      color: var(--brown);
      font-weight: 700;
    }
    h2 {
      margin: 18px 0 8px;
      font-size: 13px;
      color: var(--pink);
      letter-spacing: 0.06em;
      text-transform: uppercase;
    }
    table.grid {
      width: 100%;
      border-collapse: collapse;
      font-size: 12px;
    }
    table.grid thead th {
      background: var(--pink);
      color: #fff;
      padding: 8px 10px;
      text-align: left;
      font-weight: 600;
    }
    table.grid thead th.der { text-align: right; }
    table.grid tbody td {
      border-bottom: 1px solid var(--line);
      padding: 7px 10px;
      vertical-align: top;
    }
    table.grid tbody tr:nth-child(even) { background: var(--pink-soft); }
    .num { width: 36px; color: var(--muted); }
    .der { text-align: right; white-space: nowrap; }
    .vacio { text-align: center; color: var(--muted); padding: 12px !important; }
    .totales {
      width: 280px;
      margin: 14px 0 0 auto;
      border-collapse: collapse;
      font-size: 12px;
    }
    .totales td { padding: 6px 8px; }
    .totales td:last-child { text-align: right; font-weight: 600; }
    .totales tr.total td {
      background: var(--pink);
      color: #fff;
      font-size: 14px;
    }
    .notas {
      margin-top: 16px;
      border: 1px dashed var(--line);
      border-radius: 8px;
      padding: 10px 12px;
      font-size: 12px;
      color: var(--brown);
      background: #fffafc;
    }
    .notas strong { display: block; margin-bottom: 4px; color: var(--pink); }
    .footer {
      margin-top: 28px;
      border-top: 2px solid var(--teal);
      padding-top: 8px;
      display: flex;
      justify-content: space-between;
      gap: 12px;
      font-size: 10px;
      color: var(--muted);
    }
    @page { size: A4; margin: 12mm 12mm 16mm; }
    @media print {
      body { background: #fff; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
      .no-print { display: none !important; }
      .page { width: auto; min-height: auto; margin: 0; padding: 0; box-shadow: none; }
      thead { display: table-header-group; }
    }
  `;
}

function metaPedido(data, cliente, fecha) {
  const tipo = data.TIPOENTREGA_NOMBRE || "—";
  const pago = data.FORMAPAGO_NOMBRE || "—";
  const registro = (data.CREADOPOR_NOMBRE || data.CREADOPOR || "—").toString().trim() || "—";
  return `<table class="meta">
    <tr>
      <th>Cliente</th><td>${esc(cliente)}</td>
      <th>Fecha</th><td>${esc(fecha)}</td>
    </tr>
    <tr>
      <th>Tipo</th><td>${esc(tipo)}</td>
      <th>Método de pago</th><td>${esc(pago)}</td>
    </tr>
    <tr>
      <th>Registro</th><td colspan="3">${esc(registro)}</td>
    </tr>
  </table>`;
}

function metaCotizacion(cliente, fecha) {
  return `<table class="meta">
    <tr>
      <th>Cliente</th><td>${esc(cliente)}</td>
      <th>Fecha</th><td>${esc(fecha)}</td>
    </tr>
  </table>`;
}

export async function abrirVistaDocumento(data, opciones = {}) {
  const esPedido = opciones.tipo === "pedido";
  const autoPrint = Boolean(opciones.autoPrint);
  const mostrarAbonos = Boolean(opciones.mostrarAbonos);
  const logo = await toDataUrl(logoImg);
  const codigo = esPedido
    ? (data.IDVENTA || "—")
    : (data.IDCOTIZACION || "—");
  const tituloDoc = esPedido ? "PEDIDO" : "COTIZACIÓN";
  const cliente = data.NOMBRECLIENTE || data.CLIENTE_NOMBRE || "—";
  const fecha = dbToView(String(data.FECHA || data.FECHACREACION || "")) || "—";
  const subtotal = Number(data.SUBTOTAL || 0);
  const delivery = Number(data.COSTODELIVERY || 0);
  const total = Number(data.TOTAL || subtotal + delivery);
  const abonado = Number(data.ABONADO || 0);
  const saldo = Number(data.SALDO != null ? data.SALDO : total - abonado);
  const notas = String(data.OBSERVACIONES || "").trim();
  const mostrarNotas = Boolean(opciones.mostrarNotas) && notas;
  const tieneDelivery = delivery > 0.009;
  const pagos = data.PAGOS || [];
  const tienePagos = mostrarAbonos && pagos.length > 0;
  const generado = nowView();

  const html = `<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8" />
  <title>${esc(tituloDoc)} ${esc(codigo)}</title>
  <style>${estilos()}</style>
</head>
<body>
  ${autoPrint ? "" : `<div class="toolbar no-print"><button type="button" onclick="window.print()">Guardar como PDF</button></div>`}
  <div class="page">
    <header class="header">
      <div class="brand">
        ${logo ? `<img src="${logo}" alt="DecoCake Shop" />` : ""}
        <div>
          <h1>DecoCake Shop</h1>
          <p>Importadora de insumos de repostería</p>
        </div>
      </div>
      <div class="doc-box">
        <span>${esc(tituloDoc)}</span>
        <strong>${esc(codigo)}</strong>
      </div>
    </header>

    ${esPedido ? metaPedido(data, cliente, fecha) : metaCotizacion(cliente, fecha)}

    <h2>Detalle de productos</h2>
    <table class="grid">
      <thead>
        <tr>
          <th>#</th>
          <th>Producto</th>
          <th class="der">Cant.</th>
          <th class="der">P. unitario</th>
          <th class="der">Subtotal</th>
        </tr>
      </thead>
      <tbody>${filasProductos(data.DETALLE)}</tbody>
    </table>

    ${tienePagos ? `<h2>Abonos</h2>
    <table class="grid">
      <thead>
        <tr>
          <th>Fecha</th>
          <th class="der">Monto</th>
        </tr>
      </thead>
      <tbody>${filasPagos(pagos)}</tbody>
    </table>` : ""}

    <table class="totales">
      <tr><td>Subtotal</td><td>${esc(money(subtotal))}</td></tr>
      ${tieneDelivery ? `<tr><td>Delivery</td><td>${esc(money(delivery))}</td></tr>` : ""}
      ${tienePagos ? `<tr><td>Abonado</td><td>${esc(money(abonado))}</td></tr>
      <tr><td>Saldo</td><td>${esc(money(saldo))}</td></tr>` : ""}
      <tr class="total"><td>Total</td><td>${esc(money(total))}</td></tr>
    </table>

    ${mostrarNotas ? `<div class="notas"><strong>Notas</strong>${esc(notas)}</div>` : ""}

    <footer class="footer">
      <span>Documento generado el ${esc(generado)}</span>
      <span>DecoCake Shop · ${esc(tituloDoc)} ${esc(codigo)}</span>
    </footer>
  </div>
  ${autoPrint ? `<script>window.addEventListener("load", function () { setTimeout(function () { window.focus(); window.print(); }, 250); });</script>` : ""}
</body>
</html>`;

  const win = window.open("", "_blank");
  if (!win) {
    throw new Error("El navegador bloqueó la ventana. Permite ventanas emergentes e inténtalo de nuevo.");
  }
  win.document.open();
  win.document.write(html);
  win.document.close();
}

export async function imprimirCotizacionPdf(data) {
  return abrirVistaDocumento(data, { tipo: "cotizacion", mostrarAbonos: true, mostrarNotas: true, autoPrint: true });
}

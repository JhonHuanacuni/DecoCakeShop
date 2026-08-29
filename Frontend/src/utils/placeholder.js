export function phIngrese(etiqueta) {
  return `INGRESE ${String(etiqueta || "").toUpperCase()}`;
}

export function phSeleccione(etiqueta) {
  return `SELECCIONE ${String(etiqueta || "").toUpperCase()}`;
}

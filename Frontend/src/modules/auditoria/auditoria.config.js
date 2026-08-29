export const auditoriaConfig = {
  entidad: "auditoria",
  pk: "IDAUDITORIA",
  titulo: "Auditoría del sistema",
  descripcion: "Historial de altas, modificaciones y eliminaciones",
};

export const auditoriaColumnas = [
  { campo: "_NUMERO", etiqueta: "N°", tipo: "numero", ordenable: false },
  { campo: "FECHA", etiqueta: "Fecha", tipo: "fecha", ordenable: true },
  { campo: "HORA", etiqueta: "Hora", ordenable: true },
  { campo: "TABLA", etiqueta: "Tabla", ordenable: true },
  { campo: "ACCION", etiqueta: "Acción", tipo: "accionAuditoria", ordenable: true },
  { campo: "IDREGISTRO", etiqueta: "Registro", ordenable: true },
  { campo: "USUARIO_NOMBRE", etiqueta: "Usuario", ordenable: true },
];

export const ACCIONES_AUDITORIA = [
  { value: "", label: "Todas las acciones" },
  { value: "INSERT", label: "Alta (INSERT)" },
  { value: "UPDATE", label: "Modificación (UPDATE)" },
  { value: "DELETE", label: "Eliminación (DELETE)" },
];

export const usuarioConfig = {
  modulo: "Usuarios",
  titulo: "Listado de Usuarios",
  entidad: "usuarios",
  pk: "IDUSUARIO",
  columnas: [
    { campo: "NOMBRE", etiqueta: "Nombre", ordenable: true },
    { campo: "APELLIDO", etiqueta: "Apellido", ordenable: true },
    { campo: "DNI", etiqueta: "DNI", ordenable: true },
    { campo: "EMAIL", etiqueta: "Email", ordenable: true },
    { campo: "TIPOUSUARIO_DESCRIPCION", etiqueta: "Rol", ordenable: true },
    { campo: "ESTADO", etiqueta: "Estado", tipo: "estado", ordenable: true },
  ],
  secciones: [
    {
      titulo: "Datos personales",
      campos: [
        { campo: "NOMBRE", etiqueta: "Nombre", control: "text", obligatorio: true },
        { campo: "APELLIDO", etiqueta: "Apellido", control: "text", obligatorio: true },
        { campo: "DNI", etiqueta: "DNI", control: "text", obligatorio: true },
        { campo: "EMAIL", etiqueta: "Email", control: "text", obligatorio: true, validacion: "email" },
        { campo: "TELEFONO", etiqueta: "Teléfono", control: "text" },
        { campo: "DIRECCION", etiqueta: "Dirección", control: "text", full: true },
      ],
    },
    {
      titulo: "Acceso al sistema",
      campos: [
        { campo: "IDUSUARIO", etiqueta: "Usuario", control: "text", obligatorio: true, soloCrear: true },
        { campo: "CONTRA", etiqueta: "Contraseña", control: "password" },
        { campo: "IDTIPOUSUARIO", etiqueta: "Rol", control: "select", catalogo: "tiposUsuario", obligatorio: true },
        { campo: "ESTADO", etiqueta: "Estado", control: "select", opciones: ["Activo", "Inactivo"], obligatorio: true, defaultValue: "Activo" },
      ],
    },
  ],
};
usuarioConfig.campos = usuarioConfig.secciones.flatMap((s) => s.campos);

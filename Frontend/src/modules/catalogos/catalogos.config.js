export const categoriaConfig = {
  modulo: "Mantenedores", titulo: "Categorías", entidad: "categorias", pk: "IDCATEGORIA",
  columnas: [
    { campo: "IDCATEGORIA", etiqueta: "Código", ordenable: true },
    { campo: "NOMBRE", etiqueta: "Nombre", ordenable: true },
    { campo: "ORDEN", etiqueta: "Orden", ordenable: true },
    { campo: "ESTADO", etiqueta: "Estado", tipo: "estado", ordenable: true },
  ],
  secciones: [{ titulo: "Datos", campos: [
    { campo: "NOMBRE", etiqueta: "Nombre", control: "text", obligatorio: true },
    { campo: "DESCRIPCION", etiqueta: "Descripción", control: "textarea", full: true },
    { campo: "ORDEN", etiqueta: "Orden", control: "number", defaultValue: "0" },
    { campo: "ESTADO", etiqueta: "Estado", control: "select", opciones: ["Activo", "Inactivo"], defaultValue: "Activo", obligatorio: true },
  ]}],
};
categoriaConfig.campos = categoriaConfig.secciones.flatMap((s) => s.campos);

export const unidadConfig = {
  modulo: "Mantenedores", titulo: "Unidades", entidad: "unidades", pk: "IDUNIDAD",
  columnas: [
    { campo: "NOMBRE", etiqueta: "Nombre", ordenable: true },
    { campo: "ABREVIATURA", etiqueta: "Abreviatura", ordenable: true },
    { campo: "ESTADO", etiqueta: "Estado", tipo: "estado", ordenable: true },
  ],
  secciones: [{ titulo: "Datos", campos: [
    { campo: "NOMBRE", etiqueta: "Nombre", control: "text", obligatorio: true },
    { campo: "ABREVIATURA", etiqueta: "Abreviatura", control: "text" },
    { campo: "ESTADO", etiqueta: "Estado", control: "select", opciones: ["Activo", "Inactivo"], defaultValue: "Activo", obligatorio: true },
  ]}],
};
unidadConfig.campos = unidadConfig.secciones.flatMap((s) => s.campos);

export const clienteConfig = {
  modulo: "Mantenedores", titulo: "Clientes", entidad: "clientes", pk: "IDCLIENTE",
  columnas: [
    { campo: "NOMBRE", etiqueta: "Nombre", ordenable: true },
    { campo: "DOCUMENTO", etiqueta: "RUC / DNI", ordenable: true },
    { campo: "TELEFONO", etiqueta: "Teléfono", ordenable: true },
    { campo: "ESTADO", etiqueta: "Estado", tipo: "estado", ordenable: true },
  ],
  secciones: [{ titulo: "Datos", campos: [
    { campo: "NOMBRE", etiqueta: "Nombre", control: "text", obligatorio: true, full: true },
    { campo: "DOCUMENTO", etiqueta: "RUC / DNI", control: "text" },
    { campo: "TELEFONO", etiqueta: "Teléfono", control: "text" },
    { campo: "EMAIL", etiqueta: "Email", control: "text" },
    { campo: "DIRECCION", etiqueta: "Dirección", control: "text", full: true },
    { campo: "ESTADO", etiqueta: "Estado", control: "select", opciones: ["Activo", "Inactivo"], defaultValue: "Activo", obligatorio: true },
  ]}],
};
clienteConfig.campos = clienteConfig.secciones.flatMap((s) => s.campos);

export const formaPagoConfig = {
  modulo: "Mantenedores", titulo: "Formas de pago", entidad: "formas-pago", pk: "IDFORMAPAGO",
  columnas: [
    { campo: "NOMBRE", etiqueta: "Nombre", ordenable: true },
    { campo: "ESTADO", etiqueta: "Estado", tipo: "estado", ordenable: true },
  ],
  secciones: [{ titulo: "Datos", campos: [
    { campo: "NOMBRE", etiqueta: "Nombre", control: "text", obligatorio: true },
    { campo: "ESTADO", etiqueta: "Estado", control: "select", opciones: ["Activo", "Inactivo"], defaultValue: "Activo", obligatorio: true },
  ]}],
};
formaPagoConfig.campos = formaPagoConfig.secciones.flatMap((s) => s.campos);

export const tipoEntregaConfig = {
  modulo: "Mantenedores", titulo: "Tipos de entrega", entidad: "tipos-entrega", pk: "IDTIPOENTREGA",
  columnas: [
    { campo: "NOMBRE", etiqueta: "Nombre", ordenable: true },
    { campo: "REQUIEREDIRECCION_TXT", etiqueta: "Requiere dirección", ordenable: false },
    { campo: "ESTADO", etiqueta: "Estado", tipo: "estado", ordenable: true },
  ],
  secciones: [{ titulo: "Datos", campos: [
    { campo: "NOMBRE", etiqueta: "Nombre", control: "text", obligatorio: true },
    { campo: "REQUIEREDIRECCION", etiqueta: "Requiere dirección", control: "select", opciones: [{ value: "0", label: "No" }, { value: "1", label: "Sí" }], defaultValue: "0" },
    { campo: "ESTADO", etiqueta: "Estado", control: "select", opciones: ["Activo", "Inactivo"], defaultValue: "Activo", obligatorio: true },
  ]}],
};
tipoEntregaConfig.campos = tipoEntregaConfig.secciones.flatMap((s) => s.campos);

export const cuponConfig = {
  modulo: "Cupones", titulo: "Cupones", entidad: "cupones", pk: "IDCUPON",
  columnas: [
    { campo: "CODIGO", etiqueta: "Código", ordenable: true },
    { campo: "DESCRIPCION", etiqueta: "Descripción", ordenable: false },
    { campo: "TIPO", etiqueta: "Tipo", ordenable: true },
    { campo: "VALOR", etiqueta: "Valor", tipo: "decimal", porcentajeSi: "TIPO", ordenable: true },
    { campo: "MINIMO", etiqueta: "Mínimo", tipo: "decimal", ordenable: false },
    { campo: "VIGENCIA", etiqueta: "Vigencia", ordenable: false },
    { campo: "USOS", etiqueta: "Usos", ordenable: false },
    { campo: "ESTADO", etiqueta: "Estado", tipo: "estado", ordenable: true },
  ],
  secciones: [{ titulo: "Datos del cupón", campos: [
    { campo: "CODIGO", etiqueta: "Código", control: "text", ayuda: "Si lo dejas vacío, se genera solo." },
    { campo: "TIPO", etiqueta: "Tipo de descuento", control: "select", opciones: ["Porcentaje", "Monto"], defaultValue: "Porcentaje", obligatorio: true },
    { campo: "VALOR", etiqueta: "Valor", control: "number", obligatorio: true, defaultValue: "10" },
    { campo: "MINIMO", etiqueta: "Compra mínima", control: "number", defaultValue: "0" },
    { campo: "VIGENCIA", etiqueta: "Vigencia", control: "select", opciones: ["Permanente", "Limitado"], defaultValue: "Permanente", obligatorio: true },
    { campo: "USOSMAX", etiqueta: "Cantidad de usos", control: "number", obligatorio: true, visibleSi: { campo: "VIGENCIA", valor: "Limitado" } },
    { campo: "FECHAINICIO", etiqueta: "Fecha de inicio", control: "date" },
    { campo: "FECHAFIN", etiqueta: "Fecha de fin", control: "date" },
    { campo: "DESCRIPCION", etiqueta: "Descripción", control: "textarea", full: true },
    { campo: "ESTADO", etiqueta: "Estado", control: "select", opciones: ["Activo", "Inactivo"], defaultValue: "Activo", obligatorio: true },
  ]}],
};
cuponConfig.campos = cuponConfig.secciones.flatMap((s) => s.campos);

export const productoConfig = {
  modulo: "Productos", titulo: "Inventario", entidad: "productos", pk: "IDPRODUCTO",
  columnas: [
    { campo: "NOMBRE", etiqueta: "Nombre", ordenable: true },
    { campo: "CATEGORIA_NOMBRE", etiqueta: "Categoría", ordenable: true },
    { campo: "PRECIO", etiqueta: "Precio", tipo: "decimal", ordenable: true },
    { campo: "STOCK", etiqueta: "Stock", ordenable: true },
    { campo: "ESTADO", etiqueta: "Estado", tipo: "estado", ordenable: true },
  ],
  secciones: [{ titulo: "Datos del producto", campos: [
    { campo: "NOMBRE", etiqueta: "Nombre", control: "text", obligatorio: true, full: true },
    { campo: "IDCATEGORIA", etiqueta: "Categoría", control: "select", catalogo: "categorias", obligatorio: true },
    { campo: "IDUNIDAD", etiqueta: "Unidad", control: "select", catalogo: "unidades", defaultCatalogoLabel: "Unidad" },
    { campo: "PRECIO", etiqueta: "Precio", control: "number", obligatorio: true, defaultValue: "0" },
    { campo: "STOCK", etiqueta: "Cantidad (stock)", control: "number", obligatorio: true, defaultValue: "0" },
    { campo: "DESCRIPCION", etiqueta: "Descripción", control: "textarea" },
    { campo: "ESTADO", etiqueta: "Estado", control: "select", opciones: ["Activo", "Inactivo"], defaultValue: "Activo", obligatorio: true },
    { campo: "FOTO", etiqueta: "Foto", control: "foto", full: true },
  ]}],
};
productoConfig.campos = productoConfig.secciones.flatMap((s) => s.campos);

function _promoConfig(tipo, titulo) {
  const esCard = tipo === "card";
  return {
    modulo: "Catálogo",
    titulo,
    entidad: "promociones",
    pk: "IDPROMOCION",
    valoresFijos: { TIPO: tipo },
    filtrosIniciales: { tipo },
    columnas: [
      { campo: "IMAGEN", etiqueta: "Imagen", tipo: "imagen", ordenable: false },
      { campo: "TITULO", etiqueta: "Título", ordenable: true },
      ...(esCard ? [
        { campo: "SUBTITULO", etiqueta: "Etiqueta", ordenable: false },
        { campo: "PRECIO", etiqueta: "Precio", tipo: "decimal", ordenable: false },
      ] : []),
      { campo: "ORDEN", etiqueta: "Orden", ordenable: true },
      { campo: "ESTADO", etiqueta: "Estado", tipo: "estado", ordenable: true },
    ],
    secciones: [{ titulo: esCard ? "Datos de la promoción" : "Imagen del carrusel", campos: [
      { campo: "TITULO", etiqueta: esCard ? "Título" : "Título / texto alternativo", control: "text", obligatorio: true, full: true },
      ...(esCard ? [
        { campo: "SUBTITULO", etiqueta: "Etiqueta", control: "text", ayuda: "Ej. Combo del mes" },
        { campo: "DESCRIPCION", etiqueta: "Descripción", control: "textarea", full: true },
        { campo: "PRECIO", etiqueta: "Precio", control: "number", defaultValue: "0" },
        { campo: "PRECIOTEXTO", etiqueta: "Texto junto al precio", control: "text", ayuda: "Ej. Desde. Déjalo vacío para mostrar solo S/." },
        { campo: "ENLACE", etiqueta: "Categoría al hacer clic", control: "text", ayuda: "Id de categoría, ej. CAT003. Vacío = catálogo." },
        { campo: "ESTILO", etiqueta: "Color", control: "select", opciones: [{ value: "rosa", label: "Rosa" }, { value: "teal", label: "Turquesa" }], defaultValue: "rosa" },
      ] : []),
      { campo: "ORDEN", etiqueta: "Orden", control: "number", defaultValue: "1" },
      { campo: "ESTADO", etiqueta: "Estado", control: "select", opciones: ["Activo", "Inactivo"], defaultValue: "Activo", obligatorio: true },
      { campo: "IMAGEN", etiqueta: "Imagen", control: "foto", full: true, obligatorio: true },
    ]}],
  };
}

export const carruselConfig = _promoConfig("slider", "Carrusel");
carruselConfig.campos = carruselConfig.secciones.flatMap((s) => s.campos);

export const promocionConfig = _promoConfig("card", "Promociones");
promocionConfig.campos = promocionConfig.secciones.flatMap((s) => s.campos);

from django.db import connection
from .crud_exec import listar_std, listar_paginado, escribir
from .db_context import prepare_write_cursor
from . import sp_runner as sp


def _std(entidad):
    return {
        'listar': f'usp_{entidad}_listar',
        'obtener': f'usp_{entidad}_obtener',
        'insertar': f'usp_{entidad}_insertar',
        'actualizar': f'usp_{entidad}_actualizar',
        'eliminar': f'usp_{entidad}_eliminar',
    }


def listar_catalogo(entidad, buscar=None, estado=None, ordenar_por='NOMBRE', direccion='ASC', pagina=1, tamanio=10):
    return listar_std(_std(entidad)['listar'], buscar, estado, ordenar_por, direccion, pagina, tamanio)


def obtener_catalogo(entidad, id_val):
    if entidad == 'promocion' and sp.is_mysql():
        return obtener_promocion(id_val)
    return sp.call_obtain(_std(entidad)['obtener'], id_val)


def insertar_categoria(payload, actor=None):
    return escribir(
        'usp_categoria_insertar',
        '@Nombre=%s, @Descripcion=%s, @Orden=%s, @Estado=%s',
        [payload['NOMBRE'], payload.get('DESCRIPCION'), int(payload.get('ORDEN') or 0), payload.get('ESTADO', 'Activo')],
        actor, payload,
    )


def actualizar_categoria(id_val, payload, actor=None):
    return escribir(
        'usp_categoria_actualizar',
        '@Id=%s, @Nombre=%s, @Descripcion=%s, @Orden=%s, @Estado=%s',
        [id_val, payload['NOMBRE'], payload.get('DESCRIPCION'), int(payload.get('ORDEN') or 0), payload.get('ESTADO', 'Activo')],
        actor, payload,
    )


def insertar_unidad(payload, actor=None):
    return escribir(
        'usp_unidad_insertar',
        '@Nombre=%s, @Abreviatura=%s, @Estado=%s',
        [payload['NOMBRE'], payload.get('ABREVIATURA'), payload.get('ESTADO', 'Activo')],
        actor, payload,
    )


def actualizar_unidad(id_val, payload, actor=None):
    return escribir(
        'usp_unidad_actualizar',
        '@Id=%s, @Nombre=%s, @Abreviatura=%s, @Estado=%s',
        [id_val, payload['NOMBRE'], payload.get('ABREVIATURA'), payload.get('ESTADO', 'Activo')],
        actor, payload,
    )


def insertar_cliente(payload, actor=None):
    return escribir(
        'usp_cliente_insertar',
        '@Nombre=%s, @Documento=%s, @Telefono=%s, @Email=%s, @Direccion=%s, @Estado=%s',
        [
            payload['NOMBRE'], payload.get('DOCUMENTO'), payload.get('TELEFONO'),
            payload.get('EMAIL'), payload.get('DIRECCION'), payload.get('ESTADO', 'Activo'),
        ],
        actor, payload,
    )


def actualizar_cliente(id_val, payload, actor=None):
    return escribir(
        'usp_cliente_actualizar',
        '@Id=%s, @Nombre=%s, @Documento=%s, @Telefono=%s, @Email=%s, @Direccion=%s, @Estado=%s',
        [
            id_val, payload['NOMBRE'], payload.get('DOCUMENTO'), payload.get('TELEFONO'),
            payload.get('EMAIL'), payload.get('DIRECCION'), payload.get('ESTADO', 'Activo'),
        ],
        actor, payload,
    )


def insertar_forma_pago(payload, actor=None):
    return escribir(
        'usp_formapago_insertar',
        '@Nombre=%s, @Estado=%s',
        [payload['NOMBRE'], payload.get('ESTADO', 'Activo')],
        actor, payload,
    )


def actualizar_forma_pago(id_val, payload, actor=None):
    return escribir(
        'usp_formapago_actualizar',
        '@Id=%s, @Nombre=%s, @Estado=%s',
        [id_val, payload['NOMBRE'], payload.get('ESTADO', 'Activo')],
        actor, payload,
    )


def insertar_tipo_entrega(payload, actor=None):
    req = payload.get('REQUIEREDIRECCION')
    req_bit = 1 if str(req) in ('1', 'true', 'True', 'Sí', 'Si') else 0
    return escribir(
        'usp_tipoentrega_insertar',
        '@Nombre=%s, @RequiereDireccion=%s, @Estado=%s',
        [payload['NOMBRE'], req_bit, payload.get('ESTADO', 'Activo')],
        actor, payload,
    )


def actualizar_tipo_entrega(id_val, payload, actor=None):
    req = payload.get('REQUIEREDIRECCION')
    req_bit = 1 if str(req) in ('1', 'true', 'True', 'Sí', 'Si') else 0
    return escribir(
        'usp_tipoentrega_actualizar',
        '@Id=%s, @Nombre=%s, @RequiereDireccion=%s, @Estado=%s',
        [id_val, payload['NOMBRE'], req_bit, payload.get('ESTADO', 'Activo')],
        actor, payload,
    )


def _num(val, default=0):
    try:
        if val in (None, ''):
            return default
        return float(val)
    except (TypeError, ValueError):
        return default


def _int_or_none(val):
    try:
        if val in (None, ''):
            return None
        return int(val)
    except (TypeError, ValueError):
        return None


def _codigo_cupon(payload):
    codigo = str(payload.get('CODIGO') or '').strip().upper()
    if codigo:
        return codigo
    from random import randint
    return f'DULCE{randint(100, 999)}'


def _usos_max_cupon(payload):
    if str(payload.get('VIGENCIA') or '') == 'Permanente':
        return None
    return _int_or_none(payload.get('USOSMAX'))


def insertar_cupon(payload, actor=None):
    return escribir(
        'usp_cupon_insertar',
        '@Codigo=%s, @Descripcion=%s, @Tipo=%s, @Valor=%s, @Minimo=%s, @FechaInicio=%s, @FechaFin=%s, @UsosMax=%s, @Estado=%s',
        [
            _codigo_cupon(payload), payload.get('DESCRIPCION'), payload.get('TIPO', 'Porcentaje'),
            _num(payload.get('VALOR')), _num(payload.get('MINIMO'), None),
            payload.get('FECHAINICIO') or None, payload.get('FECHAFIN') or None,
            _usos_max_cupon(payload), payload.get('ESTADO', 'Activo'),
        ],
        actor, payload,
    )


def actualizar_cupon(id_val, payload, actor=None):
    return escribir(
        'usp_cupon_actualizar',
        '@Id=%s, @Codigo=%s, @Descripcion=%s, @Tipo=%s, @Valor=%s, @Minimo=%s, @FechaInicio=%s, @FechaFin=%s, @UsosMax=%s, @Estado=%s',
        [
            id_val, _codigo_cupon(payload), payload.get('DESCRIPCION'), payload.get('TIPO', 'Porcentaje'),
            _num(payload.get('VALOR')), _num(payload.get('MINIMO'), None),
            payload.get('FECHAINICIO') or None, payload.get('FECHAFIN') or None,
            _usos_max_cupon(payload), payload.get('ESTADO', 'Activo'),
        ],
        actor, payload,
    )


def eliminar_catalogo(entidad, id_val, actor=None):
    if entidad == 'promocion' and sp.is_mysql():
        return eliminar_promocion(id_val, actor)
    return escribir(_std(entidad)['eliminar'], '@Id=%s', [id_val], actor)


def _promocion_params(payload, tipo_fijo=None):
    tipo = (tipo_fijo or payload.get('TIPO') or 'slider').strip().lower()
    if tipo not in ('slider', 'card'):
        tipo = 'slider'
    return [
        tipo,
        (payload.get('TITULO') or '').strip(),
        payload.get('SUBTITULO') or None,
        payload.get('DESCRIPCION') or None,
        _num(payload.get('PRECIO'), None),
        payload.get('PRECIOTEXTO') or None,
        payload.get('ENLACE') or None,
        payload.get('ESTILO') or None,
        payload.get('IMAGEN') or payload.get('FOTO') or None,
        int(payload.get('ORDEN') or 0),
        payload.get('ESTADO', 'Activo') or 'Activo',
    ]


_PROMO_ORDEN = {'TITULO': 'TITULO', 'ORDEN': 'ORDEN', 'ESTADO': 'ESTADO', 'IDPROMOCION': 'IDPROMOCION'}
_schema_ok = False


def ensure_promocion_schema():
    """Crea tabla, menú y datos iniciales si aún no existen (MySQL)."""
    global _schema_ok
    if _schema_ok or not sp.is_mysql():
        return
    with connection.cursor() as cursor:
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS PROMOCION (
                IDPROMOCION         VARCHAR(50)    NOT NULL PRIMARY KEY,
                TIPO                VARCHAR(20)    NOT NULL,
                TITULO              VARCHAR(200)   NOT NULL,
                SUBTITULO           VARCHAR(120)   NULL,
                DESCRIPCION         VARCHAR(500)   NULL,
                PRECIO              DECIMAL(12,2)  NULL,
                PRECIOTEXTO         VARCHAR(80)    NULL,
                ENLACE              VARCHAR(80)    NULL,
                ESTILO              VARCHAR(20)    NULL,
                IMAGEN              LONGTEXT       NULL,
                ORDEN               INT            NOT NULL DEFAULT 0,
                ESTADO              VARCHAR(50)    NOT NULL,
                CREADOPOR           VARCHAR(50)    NULL,
                FECHACREACION       CHAR(8)        NULL,
                HORACREACION        CHAR(8)        NULL,
                MODIFICADOPOR       VARCHAR(50)    NULL,
                FECHAMODIFICACION   CHAR(8)        NULL,
                HORAMODIFICACION    CHAR(8)        NULL
            )
            """
        )
        cursor.execute(
            "INSERT INTO MODULO (IDMODULO, NOMBRE, DESCRIPCION, ICONO, ORDEN, ACTIVO) "
            "SELECT 'MOD011', 'Catálogo', 'Carrusel y promociones de la tienda', 'faStore', 8, 1 "
            "FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM MODULO WHERE IDMODULO='MOD011')"
        )
        cursor.execute(
            "INSERT INTO SUBMODULO (IDSUBMODULO, IDMODULO, NOMBRE, ICONO, ORDEN, ACTIVO) "
            "SELECT 'SUB006', 'MOD011', 'Carrusel', 'faImages', 1, 1 "
            "FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM SUBMODULO WHERE IDSUBMODULO='SUB006')"
        )
        cursor.execute(
            "INSERT INTO SUBMODULO (IDSUBMODULO, IDMODULO, NOMBRE, ICONO, ORDEN, ACTIVO) "
            "SELECT 'SUB007', 'MOD011', 'Promociones', 'faBullhorn', 2, 1 "
            "FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM SUBMODULO WHERE IDSUBMODULO='SUB007')"
        )
        cursor.execute(
            """
            INSERT INTO GRUPO_MODULO (IDGRUPOMODULO, IDTIPOUSUARIO, IDMODULO, IDTIPOPERMISO)
            SELECT CONCAT('GRM3MOD011', p.IDTIPOPERMISO), '3', 'MOD011', p.IDTIPOPERMISO
            FROM TIPO_PERMISO p
            WHERE NOT EXISTS (
                SELECT 1 FROM GRUPO_MODULO g
                WHERE g.IDTIPOUSUARIO = '3' AND g.IDMODULO = 'MOD011' AND g.IDTIPOPERMISO = p.IDTIPOPERMISO
            )
            """
        )
        cursor.execute(
            """
            INSERT INTO GRUPO_MODULO (IDGRUPOMODULO, IDTIPOUSUARIO, IDMODULO, IDTIPOPERMISO)
            SELECT CONCAT('GRM1MOD011', p.IDTIPOPERMISO), '1', 'MOD011', p.IDTIPOPERMISO
            FROM TIPO_PERMISO p
            WHERE NOT EXISTS (
                SELECT 1 FROM GRUPO_MODULO g
                WHERE g.IDTIPOUSUARIO = '1' AND g.IDMODULO = 'MOD011' AND g.IDTIPOPERMISO = p.IDTIPOPERMISO
            )
            """
        )
        cursor.execute("SELECT COUNT(*) FROM PROMOCION")
        if cursor.fetchone()[0] == 0:
            seeds = [
                ('PRM000001', 'slider', 'Set de bowls metálicos anidables', None, None, None, None, None, None,
                 '/shop-products/05-bols-de-acero-x7und.png', 1),
                ('PRM000002', 'slider', 'Fondant y pastas de modelar', None, None, None, None, None, None,
                 '/shop-products/04-taper-bombonera.png', 2),
                ('PRM000003', 'slider', 'Colorantes y cortadores', None, None, None, None, None, None,
                 '/shop-products/03-sorbetones.png', 3),
                ('PRM000004', 'card', 'Set de bowls metálicos', 'Combo del mes',
                 '7 piezas anidables, de 18 a 30 cm, para batir y guardar con orden.',
                 58, None, 'CAT004', 'rosa', '/shop-products/05-bols-de-acero-x7und.png', 1),
                ('PRM000005', 'card', 'Kekeras y moldes', 'Hornea más',
                 'Sets listos para tortas, kekes y celebraciones de todo tamaño.',
                 14, 'Desde', 'CAT003', 'teal', '/shop-products/12-kekera-rectangular-x5-und.jpeg', 2),
            ]
            for row in seeds:
                cursor.execute(
                    """
                    INSERT INTO PROMOCION (
                        IDPROMOCION, TIPO, TITULO, SUBTITULO, DESCRIPCION, PRECIO, PRECIOTEXTO,
                        ENLACE, ESTILO, IMAGEN, ORDEN, ESTADO,
                        CREADOPOR, FECHACREACION, HORACREACION, MODIFICADOPOR, FECHAMODIFICACION, HORAMODIFICACION
                    ) VALUES (
                        %s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,'Activo',
                        'sistema', fn_fecha_ddmmyyyy(), TIME_FORMAT(NOW(), '%%H:%%i:%%s'),
                        'sistema', fn_fecha_ddmmyyyy(), TIME_FORMAT(NOW(), '%%H:%%i:%%s')
                    )
                    """,
                    list(row),
                )
    _schema_ok = True


def _mysql_next_promo_id(cursor):
    cursor.execute(
        "SELECT IFNULL(MAX(CAST(SUBSTRING(IDPROMOCION, 4, 12) AS UNSIGNED)), 0) + 1 "
        "FROM PROMOCION WHERE IDPROMOCION LIKE %s",
        ['PRM%'],
    )
    num = int(cursor.fetchone()[0] or 1)
    return f'PRM{num:06d}'


def listar_promociones(buscar=None, estado=None, tipo=None, ordenar_por='ORDEN', direccion='ASC', pagina=1, tamanio=10):
    if not sp.is_mysql():
        return listar_paginado(
            'usp_promocion_listar',
            '@Buscar=%s, @Estado=%s, @Tipo=%s, @OrdenarPor=%s, @Direccion=%s, @Pagina=%s, @TamanioPagina=%s',
            [buscar or None, estado or None, tipo or None, ordenar_por, direccion, pagina, tamanio],
        )
    ensure_promocion_schema()
    pagina = max(1, int(pagina or 1))
    tamanio = max(1, int(tamanio or 10))
    col = _PROMO_ORDEN.get(ordenar_por, 'ORDEN')
    dir_sql = 'DESC' if str(direccion).upper() == 'DESC' else 'ASC'
    where = ['1=1']
    params = []
    if buscar:
        where.append('(IDPROMOCION LIKE %s OR TITULO LIKE %s OR IFNULL(DESCRIPCION,\'\') LIKE %s)')
        like = f'%{buscar}%'
        params.extend([like, like, like])
    if estado:
        where.append('ESTADO = %s')
        params.append(estado)
    if tipo:
        where.append('TIPO = %s')
        params.append(tipo)
    clause = ' AND '.join(where)
    with connection.cursor() as cursor:
        cursor.execute(f'SELECT COUNT(*) FROM PROMOCION WHERE {clause}', params)
        total = int(cursor.fetchone()[0] or 0)
        cursor.execute(
            f'SELECT * FROM PROMOCION WHERE {clause} ORDER BY {col} {dir_sql}, TITULO '
            f'LIMIT %s OFFSET %s',
            params + [tamanio, (pagina - 1) * tamanio],
        )
        return sp.cursor_rows(cursor), total


def obtener_promocion(id_val):
    ensure_promocion_schema()
    with connection.cursor() as cursor:
        cursor.execute('SELECT * FROM PROMOCION WHERE IDPROMOCION = %s', [id_val])
        rows = sp.cursor_rows(cursor)
    return rows[0] if rows else None


def insertar_promocion(payload, actor=None):
    if not sp.is_mysql():
        return escribir(
            'usp_promocion_insertar',
            '@Tipo=%s, @Titulo=%s, @Subtitulo=%s, @Descripcion=%s, @Precio=%s, @PrecioTexto=%s, '
            '@Enlace=%s, @Estilo=%s, @Imagen=%s, @Orden=%s, @Estado=%s',
            _promocion_params(payload),
            actor, payload,
        )
    ensure_promocion_schema()
    tipo, titulo, sub, desc, precio, ptxt, enlace, estilo, imagen, orden, estado = _promocion_params(payload)
    if not titulo:
        return 0, 'Ingresa el título.'
    if not imagen:
        return 0, 'Agrega una imagen.'
    with connection.cursor() as cursor:
        prepare_write_cursor(cursor, actor, payload)
        new_id = _mysql_next_promo_id(cursor)
        cursor.execute(
            """
            INSERT INTO PROMOCION (
                IDPROMOCION, TIPO, TITULO, SUBTITULO, DESCRIPCION, PRECIO, PRECIOTEXTO,
                ENLACE, ESTILO, IMAGEN, ORDEN, ESTADO,
                CREADOPOR, FECHACREACION, HORACREACION, MODIFICADOPOR, FECHAMODIFICACION, HORAMODIFICACION
            ) VALUES (
                %s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,
                IFNULL(@audit_id_usuario, 'sistema'), fn_fecha_ddmmyyyy(), TIME_FORMAT(NOW(), '%%H:%%i:%%s'),
                IFNULL(@audit_id_usuario, 'sistema'), fn_fecha_ddmmyyyy(), TIME_FORMAT(NOW(), '%%H:%%i:%%s')
            )
            """,
            [new_id, tipo, titulo, sub, desc, precio, ptxt, enlace, estilo, imagen, orden, estado],
        )
    return 1, 'Promoción registrada.'


def actualizar_promocion(id_val, payload, actor=None):
    if not sp.is_mysql():
        return escribir(
            'usp_promocion_actualizar',
            '@Id=%s, @Tipo=%s, @Titulo=%s, @Subtitulo=%s, @Descripcion=%s, @Precio=%s, @PrecioTexto=%s, '
            '@Enlace=%s, @Estilo=%s, @Imagen=%s, @Orden=%s, @Estado=%s',
            [id_val, *_promocion_params(payload)],
            actor, payload,
        )
    ensure_promocion_schema()
    tipo, titulo, sub, desc, precio, ptxt, enlace, estilo, imagen, orden, estado = _promocion_params(payload)
    if not titulo:
        return 0, 'Ingresa el título.'
    if not imagen:
        return 0, 'Agrega una imagen.'
    with connection.cursor() as cursor:
        prepare_write_cursor(cursor, actor, payload)
        cursor.execute('SELECT 1 FROM PROMOCION WHERE IDPROMOCION = %s', [id_val])
        if not cursor.fetchone():
            return 0, 'La promoción no existe.'
        cursor.execute(
            """
            UPDATE PROMOCION SET
                TIPO=%s, TITULO=%s, SUBTITULO=%s, DESCRIPCION=%s, PRECIO=%s, PRECIOTEXTO=%s,
                ENLACE=%s, ESTILO=%s, IMAGEN=%s, ORDEN=%s, ESTADO=%s,
                MODIFICADOPOR=IFNULL(@audit_id_usuario, 'sistema'),
                FECHAMODIFICACION=fn_fecha_ddmmyyyy(),
                HORAMODIFICACION=TIME_FORMAT(NOW(), '%%H:%%i:%%s')
            WHERE IDPROMOCION=%s
            """,
            [tipo, titulo, sub, desc, precio, ptxt, enlace, estilo, imagen, orden, estado, id_val],
        )
    return 1, 'Promoción actualizada.'


def eliminar_promocion(id_val, actor=None):
    ensure_promocion_schema()
    with connection.cursor() as cursor:
        prepare_write_cursor(cursor, actor)
        cursor.execute('SELECT 1 FROM PROMOCION WHERE IDPROMOCION = %s', [id_val])
        if not cursor.fetchone():
            return 0, 'La promoción no existe.'
        cursor.execute('DELETE FROM PROMOCION WHERE IDPROMOCION = %s', [id_val])
    return 1, 'Promoción eliminada.'


def listar_promociones_publicas():
    ensure_promocion_schema()
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT IDPROMOCION, TIPO, TITULO, SUBTITULO, DESCRIPCION, PRECIO, PRECIOTEXTO,
                   ENLACE, ESTILO, IMAGEN, ORDEN
            FROM PROMOCION WHERE ESTADO='Activo' ORDER BY TIPO, ORDEN, TITULO
            """
        )
        return sp.cursor_rows(cursor)


def buscar_clientes(buscar):
    q = (buscar or '').strip()
    if len(q) < 3:
        return []
    with connection.cursor() as cursor:
        return sp.call_proc_rows(cursor, 'usp_cliente_buscar', [q], '@Buscar=%s')

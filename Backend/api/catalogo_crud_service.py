from django.db import connection
from .crud_exec import listar_std, escribir
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
    return escribir(_std(entidad)['eliminar'], '@Id=%s', [id_val], actor)


def buscar_clientes(buscar):
    q = (buscar or '').strip()
    if len(q) < 3:
        return []
    with connection.cursor() as cursor:
        cursor.execute('EXEC dbo.usp_cliente_buscar @Buscar=%s', [q])
        if not cursor.description:
            return []
        return sp.cursor_rows(cursor)

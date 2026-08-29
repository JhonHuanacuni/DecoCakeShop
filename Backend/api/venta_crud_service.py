import json
from django.db import connection
from .crud_exec import listar_paginado, escribir
from . import sp_runner as sp


def listar_ventas(buscar=None, estado=None, ordenar_por='FECHA', direccion='DESC', pagina=1, tamanio=10):
    return listar_paginado(
        'usp_venta_listar',
        '@Buscar=%s, @Estado=%s, @OrdenarPor=%s, @Direccion=%s, @Pagina=%s, @TamanioPagina=%s',
        [buscar or None, estado or None, ordenar_por, direccion, pagina, tamanio],
    )


def obtener_venta(id_val):
    cab = sp.call_obtain('usp_venta_obtener', id_val)
    if not cab:
        return None
    foto = cab.get('COMPROBANTEPAGO')
    if isinstance(foto, (bytes, bytearray, memoryview)):
        cab['COMPROBANTEPAGO'] = bytes(foto).decode('utf-8', errors='ignore')
    with connection.cursor() as cursor:
        if sp.is_mysql():
            det = sp.call_simple(cursor, 'usp_venta_detalle_listar', [id_val])
        else:
            cursor.execute('EXEC dbo.usp_venta_detalle_listar @Id=%s', [id_val])
            det = sp.cursor_rows(cursor)
    cab['DETALLE'] = det
    return cab


def _detalle_json(payload):
    detalle = payload.get('DETALLE') or payload.get('detalle') or []
    return json.dumps(detalle, ensure_ascii=False)


def insertar_venta(payload, actor=None):
    return escribir(
        'usp_venta_insertar',
        '@IdCliente=%s, @IdFormaPago=%s, @IdTipoEntrega=%s, @DireccionEntrega=%s, '
        '@CostoDelivery=%s, @Observaciones=%s, @Estado=%s, @DetalleJson=%s, '
        '@ComprobantePago=%s, @NombreCliente=%s',
        [
            payload.get('IDCLIENTE'), payload.get('IDFORMAPAGO'), payload.get('IDTIPOENTREGA'),
            payload.get('DIRECCIONENTREGA'), payload.get('COSTODELIVERY') or 0,
            payload.get('OBSERVACIONES'), payload.get('ESTADO', 'Pendiente'),
            _detalle_json(payload), payload.get('COMPROBANTEPAGO'), payload.get('NOMBRECLIENTE'),
        ],
        actor, payload,
    )


def actualizar_venta(id_val, payload, actor=None):
    return escribir(
        'usp_venta_actualizar',
        '@Id=%s, @IdCliente=%s, @IdFormaPago=%s, @IdTipoEntrega=%s, @DireccionEntrega=%s, '
        '@CostoDelivery=%s, @Observaciones=%s, @Estado=%s, @DetalleJson=%s, '
        '@ComprobantePago=%s, @NombreCliente=%s',
        [
            id_val, payload.get('IDCLIENTE'), payload.get('IDFORMAPAGO'), payload.get('IDTIPOENTREGA'),
            payload.get('DIRECCIONENTREGA'), payload.get('COSTODELIVERY') or 0,
            payload.get('OBSERVACIONES'), payload.get('ESTADO', 'Pendiente'),
            _detalle_json(payload), payload.get('COMPROBANTEPAGO'), payload.get('NOMBRECLIENTE'),
        ],
        actor, payload,
    )


def eliminar_venta(id_val, actor=None):
    return escribir('usp_venta_eliminar', '@Id=%s', [id_val], actor)


def anular_venta(id_val, actor=None):
    return escribir('usp_venta_anular', '@Id=%s', [id_val], actor)

import json
from django.db import connection
from .db_context import prepare_write_cursor
from .crud_exec import listar_paginado, escribir
from . import sp_runner as sp


def listar_cotizaciones(buscar=None, estado=None, ordenar_por='FECHA', direccion='DESC', pagina=1, tamanio=10):
    return listar_paginado(
        'usp_cotizacion_listar',
        '@Buscar=%s, @Estado=%s, @OrdenarPor=%s, @Direccion=%s, @Pagina=%s, @TamanioPagina=%s',
        [buscar or None, estado or None, ordenar_por, direccion, pagina, tamanio],
    )


def obtener_cotizacion(id_val):
    cab = sp.call_obtain('usp_cotizacion_obtener', id_val)
    if not cab:
        return None
    with connection.cursor() as cursor:
        if sp.is_mysql():
            det = sp.call_simple(cursor, 'usp_cotizacion_detalle_listar', [id_val])
        else:
            cursor.execute('EXEC dbo.usp_cotizacion_detalle_listar @Id=%s', [id_val])
            det = sp.cursor_rows(cursor)
    cab['DETALLE'] = det
    return cab


def _detalle_json(payload):
    detalle = payload.get('DETALLE') or payload.get('detalle') or []
    return json.dumps(detalle, ensure_ascii=False)


def _monto(value):
    try:
        return float(value or 0)
    except (TypeError, ValueError):
        return 0.0


def insertar_cotizacion(payload, actor=None):
    params = [
        payload.get('IDCLIENTE') or None, payload.get('NOMBRECLIENTE') or payload.get('CLIENTE_NOMBRE'),
        payload.get('IDTIPOENTREGA'),
        payload.get('DIRECCIONENTREGA'), payload.get('COSTODELIVERY') or 0,
        payload.get('OBSERVACIONES'), payload.get('ESTADO', 'Deuda'),
        _detalle_json(payload),
        _monto(payload.get('MONTOINICIAL')),
        payload.get('IDFORMAPAGOINICIAL') or payload.get('IDFORMAPAGO') or None,
    ]
    with connection.cursor() as cursor:
        prepare_write_cursor(cursor, actor, payload)
        cursor.execute(
            """
            DECLARE @R INT, @M NVARCHAR(200), @Id NVARCHAR(50);
            EXEC dbo.usp_cotizacion_insertar
                @IdCliente=%s, @NombreCliente=%s, @IdTipoEntrega=%s, @DireccionEntrega=%s, @CostoDelivery=%s,
                @Observaciones=%s, @Estado=%s, @DetalleJson=%s, @MontoInicial=%s, @IdFormaPago=%s,
                @Resultado=@R OUTPUT, @Mensaje=@M OUTPUT, @IdOut=@Id OUTPUT;
            SELECT @R AS Resultado, @M AS Mensaje, @Id AS IDCOTIZACION;
            """,
            params,
        )
        resultado, mensaje, id_val = 0, 'Error desconocido', None
        while True:
            if cursor.description:
                row = cursor.fetchone()
                if row:
                    cols = [c[0].lower() for c in cursor.description]
                    data = dict(zip(cols, row))
                    resultado = data.get('resultado', resultado)
                    mensaje = data.get('mensaje', mensaje)
                    id_val = data.get('idcotizacion') or id_val
            if not cursor.nextset():
                break
    return int(resultado or 0), str(mensaje or ''), id_val


def actualizar_cotizacion(id_val, payload, actor=None):
    return escribir(
        'usp_cotizacion_actualizar',
        '@Id=%s, @IdCliente=%s, @NombreCliente=%s, @IdTipoEntrega=%s, @DireccionEntrega=%s, @CostoDelivery=%s, '
        '@Observaciones=%s, @Estado=%s, @DetalleJson=%s',
        [
            id_val, payload.get('IDCLIENTE') or None,
            payload.get('NOMBRECLIENTE') or payload.get('CLIENTE_NOMBRE'),
            payload.get('IDTIPOENTREGA'),
            payload.get('DIRECCIONENTREGA'), payload.get('COSTODELIVERY') or 0,
            payload.get('OBSERVACIONES'), payload.get('ESTADO', 'Deuda'),
            _detalle_json(payload),
        ],
        actor, payload,
    )


def eliminar_cotizacion(id_val, actor=None):
    return escribir('usp_cotizacion_eliminar', '@Id=%s', [id_val], actor)


def anular_cotizacion(id_val, actor=None):
    return escribir('usp_cotizacion_anular', '@Id=%s', [id_val], actor)


def guardar_envio_cotizacion(id_val, payload=None, actor=None):
    payload = payload or {}
    return escribir(
        'usp_cotizacion_guardar_envio',
        '@Id=%s, @IdFormaPago=%s, @IdTipoEntrega=%s, @DireccionEntrega=%s, @CostoDelivery=%s',
        [
            id_val,
            payload.get('IDFORMAPAGO') or None,
            payload.get('IDTIPOENTREGA') or None,
            payload.get('DIRECCIONENTREGA') or None,
            payload.get('COSTODELIVERY') or 0,
        ],
        actor, payload,
    )


def convertir_cotizacion(id_val, payload=None, actor=None):
    payload = payload or {}
    return escribir(
        'usp_cotizacion_hacer_pedido',
        '@Id=%s, @IdFormaPago=%s, @IdTipoEntrega=%s, @DireccionEntrega=%s, @CostoDelivery=%s',
        [
            id_val,
            payload.get('IDFORMAPAGO') or None,
            payload.get('IDTIPOENTREGA') or None,
            payload.get('DIRECCIONENTREGA') or None,
            payload.get('COSTODELIVERY') or 0,
        ],
        actor, payload,
    )


def listar_pagos_cotizacion(id_val):
    cab = obtener_cotizacion(id_val)
    if not cab:
        return None
    with connection.cursor() as cursor:
        if sp.is_mysql():
            pagos = sp.call_simple(cursor, 'usp_cotizacion_pago_listar', [id_val])
        else:
            cursor.execute('EXEC dbo.usp_cotizacion_pago_listar @Id=%s', [id_val])
            pagos = sp.cursor_rows(cursor)
    for p in pagos:
        if p.get('MONTO') is not None:
            p['MONTO'] = float(p['MONTO'])
    abonado = _monto(cab.get('ABONADO'))
    total = _monto(cab.get('TOTAL'))
    return {
        'IDCOTIZACION': cab.get('IDCOTIZACION'),
        'CLIENTE_NOMBRE': cab.get('CLIENTE_NOMBRE') or cab.get('NOMBRECLIENTE'),
        'ESTADO': cab.get('ESTADO'),
        'TOTAL': total,
        'ABONADO': abonado,
        'SALDO': round(total - abonado, 2),
        'PAGOS': pagos,
    }


def insertar_pago_cotizacion(id_val, payload, actor=None):
    return escribir(
        'usp_cotizacion_pago_insertar',
        '@Id=%s, @Monto=%s, @Tipo=%s, @IdFormaPago=%s',
        [id_val, _monto(payload.get('MONTO')), payload.get('TIPO') or 'Abono', payload.get('IDFORMAPAGO') or None],
        actor, payload,
    )


def catalogos_cotizacion():
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT IDCLIENTE AS value, NOMBRE AS label FROM CLIENTE WHERE ESTADO = 'Activo' ORDER BY NOMBRE"
        )
        clientes = sp.cursor_rows(cursor)
        cursor.execute(
            "SELECT IDTIPOENTREGA AS value, NOMBRE AS label, REQUIEREDIRECCION "
            "FROM TIPO_ENTREGA WHERE ESTADO = 'Activo' ORDER BY NOMBRE"
        )
        tipos = sp.cursor_rows(cursor)
        cursor.execute(
            """
            SELECT p.IDPRODUCTO AS value, p.NOMBRE AS label, p.PRECIO, p.STOCK, p.DESCRIPCION, p.FOTO,
                   p.IDCATEGORIA, c.NOMBRE AS CATEGORIA_NOMBRE
            FROM PRODUCTO p INNER JOIN CATEGORIA c ON c.IDCATEGORIA=p.IDCATEGORIA
            WHERE p.ESTADO = 'Activo' ORDER BY c.ORDEN, p.NOMBRE
            """
        )
        productos = sp.cursor_rows(cursor)
        cursor.execute(
            "SELECT IDFORMAPAGO AS value, NOMBRE AS label FROM FORMA_PAGO WHERE ESTADO = 'Activo' ORDER BY NOMBRE"
        )
        formas = sp.cursor_rows(cursor)
        cursor.execute(
            "SELECT IDCATEGORIA AS value, NOMBRE AS label FROM CATEGORIA WHERE ESTADO = 'Activo' ORDER BY ORDEN, NOMBRE"
        )
        categorias = sp.cursor_rows(cursor)
    for p in productos:
        if p.get('PRECIO') is not None:
            p['PRECIO'] = float(p['PRECIO'])
        if p.get('STOCK') is not None:
            p['STOCK'] = float(p['STOCK'])
        foto = p.get('FOTO')
        if isinstance(foto, (bytes, bytearray, memoryview)):
            p['FOTO'] = bytes(foto).decode('utf-8', errors='ignore')
    return {
        'clientes': clientes,
        'tiposEntrega': tipos,
        'productos': productos,
        'formasPago': formas,
        'categorias': categorias,
    }

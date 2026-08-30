from django.db import connection
from .crud_exec import listar_std, escribir
from . import sp_runner as sp


def listar_productos(buscar=None, estado=None, id_categoria=None, ordenar_por='NOMBRE', direccion='ASC', pagina=1, tamanio=10):
    from .crud_exec import listar_paginado
    return listar_paginado(
        'usp_producto_listar',
        '@Buscar=%s, @Estado=%s, @IdCategoria=%s, @OrdenarPor=%s, @Direccion=%s, @Pagina=%s, @TamanioPagina=%s',
        [buscar or None, estado or None, id_categoria or None, ordenar_por, direccion, pagina, tamanio],
    )


def obtener_producto(id_val):
    return sp.call_obtain('usp_producto_obtener', id_val)


def insertar_producto(payload, actor=None):
    return escribir(
        'usp_producto_insertar',
        '@Nombre=%s, @Descripcion=%s, @Precio=%s, @Stock=%s, @IdCategoria=%s, @IdUnidad=%s, @Estado=%s, @Foto=%s',
        [
            payload['NOMBRE'], payload.get('DESCRIPCION'),
            payload.get('PRECIO') or 0, payload.get('STOCK') or 0,
            payload.get('IDCATEGORIA'), payload.get('IDUNIDAD'),
            payload.get('ESTADO', 'Activo'), payload.get('FOTO'),
        ],
        actor, payload,
    )


def actualizar_producto(id_val, payload, actor=None):
    return escribir(
        'usp_producto_actualizar',
        '@Id=%s, @Nombre=%s, @Descripcion=%s, @Precio=%s, @Stock=%s, @IdCategoria=%s, @IdUnidad=%s, @Estado=%s, @Foto=%s',
        [
            id_val, payload['NOMBRE'], payload.get('DESCRIPCION'),
            payload.get('PRECIO') or 0, payload.get('STOCK') or 0,
            payload.get('IDCATEGORIA'), payload.get('IDUNIDAD'),
            payload.get('ESTADO', 'Activo'), payload.get('FOTO'),
        ],
        actor, payload,
    )


def eliminar_producto(id_val, actor=None):
    return escribir('usp_producto_eliminar', '@Id=%s', [id_val], actor)


def catalogos_producto():
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT IDCATEGORIA AS value, NOMBRE AS label FROM CATEGORIA WHERE ESTADO = 'Activo' ORDER BY ORDEN, NOMBRE"
        )
        categorias = sp.cursor_rows(cursor)
        cursor.execute(
            "SELECT IDUNIDAD AS value, NOMBRE AS label FROM UNIDAD WHERE ESTADO = 'Activo' ORDER BY NOMBRE"
        )
        unidades = sp.cursor_rows(cursor)
    return {'categorias': categorias, 'unidades': unidades}

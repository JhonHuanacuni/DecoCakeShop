from django.db import connection
from . import sp_runner as sp
from .crud_exec import listar_paginado


def listar_auditoria(
    buscar=None, tabla=None, accion=None, id_usuario=None,
    fecha_desde=None, fecha_hasta=None,
    ordenar_por='FECHA', direccion='DESC', pagina=1, tamanio=10,
):
    return listar_paginado(
        'usp_auditoria_listar',
        '@Buscar=%s, @Tabla=%s, @Accion=%s, @IdUsuario=%s, @FechaDesde=%s, @FechaHasta=%s, '
        '@OrdenarPor=%s, @Direccion=%s, @Pagina=%s, @TamanioPagina=%s',
        [
            buscar or None, tabla or None, accion or None, id_usuario or None,
            fecha_desde or None, fecha_hasta or None,
            ordenar_por, direccion, pagina, tamanio,
        ],
    )


def obtener_auditoria(id_auditoria: str):
    return sp.call_obtain('usp_auditoria_obtener', id_auditoria)


def listar_tablas_auditoria():
    with connection.cursor() as cursor:
        if sp.is_mysql():
            return sp.call_simple(cursor, 'usp_auditoria_tablas_catalogo', [])
        cursor.execute('EXEC dbo.usp_auditoria_tablas_catalogo')
        return sp.cursor_rows(cursor)

from . import sp_runner as sp
from .crud_exec import listar_paginado


def listar_pagos(buscar=None, tipo=None, ordenar_por='FECHA', direccion='DESC', pagina=1, tamanio=10):
    return listar_paginado(
        'usp_pago_listar',
        '@Buscar=%s, @Tipo=%s, @OrdenarPor=%s, @Direccion=%s, @Pagina=%s, @TamanioPagina=%s',
        [buscar or None, tipo or None, ordenar_por, direccion, pagina, tamanio],
    )


def obtener_pago(id_val):
    return sp.call_obtain('usp_pago_obtener', id_val)

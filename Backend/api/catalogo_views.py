import json
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from .db_context import actor_from_request
from .catalogo_crud_service import (
    listar_catalogo, obtener_catalogo, eliminar_catalogo,
    insertar_categoria, actualizar_categoria,
    insertar_unidad, actualizar_unidad,
    insertar_cliente, actualizar_cliente,
    insertar_forma_pago, actualizar_forma_pago,
    insertar_tipo_entrega, actualizar_tipo_entrega,
    insertar_cupon, actualizar_cupon,
    listar_promociones, insertar_promocion, actualizar_promocion,
    buscar_clientes,
)

INSERTAR = {
    'categoria': insertar_categoria,
    'unidad': insertar_unidad,
    'cliente': insertar_cliente,
    'formapago': insertar_forma_pago,
    'tipoentrega': insertar_tipo_entrega,
    'cupon': insertar_cupon,
    'promocion': insertar_promocion,
}
ACTUALIZAR = {
    'categoria': actualizar_categoria,
    'unidad': actualizar_unidad,
    'cliente': actualizar_cliente,
    'formapago': actualizar_forma_pago,
    'tipoentrega': actualizar_tipo_entrega,
    'cupon': actualizar_cupon,
    'promocion': actualizar_promocion,
}
ORDEN_DEFAULT = {
    'categoria': 'ORDEN',
    'unidad': 'NOMBRE',
    'cliente': 'NOMBRE',
    'formapago': 'NOMBRE',
    'tipoentrega': 'NOMBRE',
    'cupon': 'CODIGO',
    'promocion': 'ORDEN',
}


def _floats(row, campos=('VALOR', 'MINIMO')):
    if not row:
        return row
    for campo in campos:
        if row.get(campo) is not None:
            row[campo] = float(row[campo])
    if 'USOSMAX' in row:
        row['VIGENCIA'] = 'Limitado' if row.get('USOSMAX') else 'Permanente'
    return row


def _parse_body(request):
    try:
        return json.loads(request.body.decode('utf-8'))
    except Exception:
        return None


def catalogo_mantenedor(entidad, not_found='Registro no encontrado'):
    @csrf_exempt
    def _view(request, id_val=None):
        if request.method == 'GET' and not id_val:
            try:
                if entidad == 'promocion':
                    data, total = listar_promociones(
                        request.GET.get('buscar') or None,
                        request.GET.get('estado') or None,
                        request.GET.get('tipo') or None,
                        request.GET.get('ordenarPor', ORDEN_DEFAULT[entidad]),
                        request.GET.get('direccion', 'ASC'),
                        int(request.GET.get('pagina', 1)),
                        int(request.GET.get('tamanio', 10)),
                    )
                else:
                    data, total = listar_catalogo(
                        entidad,
                        request.GET.get('buscar') or None,
                        request.GET.get('estado') or None,
                        request.GET.get('ordenarPor', ORDEN_DEFAULT[entidad]),
                        request.GET.get('direccion', 'ASC'),
                        int(request.GET.get('pagina', 1)),
                        int(request.GET.get('tamanio', 10)),
                    )
                if entidad == 'cupon':
                    data = [_floats(row) for row in data]
                if entidad == 'promocion':
                    data = [_floats(row, ('PRECIO',)) for row in data]
                return JsonResponse({
                    'data': data, 'total': total,
                    'pagina': int(request.GET.get('pagina', 1)),
                    'tamanioPagina': int(request.GET.get('tamanio', 10)),
                })
            except Exception as exc:
                return JsonResponse({'error': str(exc)}, status=500)

        if request.method == 'GET' and id_val:
            try:
                row = obtener_catalogo(entidad, id_val)
                if not row:
                    return JsonResponse({'error': not_found}, status=404)
                if entidad == 'cupon':
                    row = _floats(row)
                if entidad == 'promocion':
                    row = _floats(row, ('PRECIO',))
                return JsonResponse({'data': row})
            except Exception as exc:
                return JsonResponse({'error': str(exc)}, status=500)

        if request.method == 'POST' and not id_val:
            payload = _parse_body(request)
            if not payload:
                return JsonResponse({'error': 'JSON inválido'}, status=400)
            try:
                ok, mensaje = INSERTAR[entidad](payload, actor_from_request(request, payload))
                return JsonResponse({'ok': bool(ok), 'mensaje': mensaje}, status=200 if ok else 400)
            except Exception as exc:
                return JsonResponse({'error': str(exc)}, status=500)

        if request.method == 'PUT' and id_val:
            payload = _parse_body(request)
            if not payload:
                return JsonResponse({'error': 'JSON inválido'}, status=400)
            try:
                ok, mensaje = ACTUALIZAR[entidad](id_val, payload, actor_from_request(request, payload))
                return JsonResponse({'ok': bool(ok), 'mensaje': mensaje}, status=200 if ok else 400)
            except Exception as exc:
                return JsonResponse({'error': str(exc)}, status=500)

        if request.method == 'DELETE' and id_val:
            try:
                ok, mensaje = eliminar_catalogo(entidad, id_val, actor_from_request(request))
                return JsonResponse({'ok': bool(ok), 'mensaje': mensaje}, status=200 if ok else 400)
            except Exception as exc:
                return JsonResponse({'error': str(exc)}, status=500)

        return JsonResponse({'error': 'Método no permitido'}, status=405)

    return _view


@csrf_exempt
def clientes_buscar(request):
    if request.method != 'GET':
        return JsonResponse({'error': 'Método no permitido'}, status=405)
    try:
        return JsonResponse({'data': buscar_clientes(request.GET.get('q') or '')})
    except Exception as exc:
        return JsonResponse({'error': str(exc)}, status=500)


categorias_mantenedor = catalogo_mantenedor('categoria', 'Categoría no encontrada')
unidades_mantenedor = catalogo_mantenedor('unidad', 'Unidad no encontrada')
clientes_mantenedor = catalogo_mantenedor('cliente', 'Cliente no encontrado')
formas_pago_mantenedor = catalogo_mantenedor('formapago', 'Forma de pago no encontrada')
tipos_entrega_mantenedor = catalogo_mantenedor('tipoentrega', 'Tipo de entrega no encontrado')
cupones_mantenedor = catalogo_mantenedor('cupon', 'Cupón no encontrado')
promociones_mantenedor = catalogo_mantenedor('promocion', 'Promoción no encontrada')

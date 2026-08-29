import json
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from .db_context import actor_from_request
from .producto_crud_service import (
    listar_productos, obtener_producto, insertar_producto,
    actualizar_producto, eliminar_producto, catalogos_producto,
)


def _parse_body(request):
    try:
        return json.loads(request.body.decode('utf-8'))
    except Exception:
        return None


@csrf_exempt
def productos_catalogos(request):
    if request.method != 'GET':
        return JsonResponse({'error': 'Método no permitido'}, status=405)
    try:
        return JsonResponse(catalogos_producto())
    except Exception as exc:
        return JsonResponse({'error': str(exc)}, status=500)


@csrf_exempt
def productos_mantenedor(request, id_producto=None):
    if request.method == 'GET' and not id_producto:
        try:
            data, total = listar_productos(
                request.GET.get('buscar') or None,
                request.GET.get('estado') or None,
                request.GET.get('idCategoria') or None,
                request.GET.get('ordenarPor', 'NOMBRE'),
                request.GET.get('direccion', 'ASC'),
                int(request.GET.get('pagina', 1)),
                int(request.GET.get('tamanio', 10)),
            )
            return JsonResponse({
                'data': data, 'total': total,
                'pagina': int(request.GET.get('pagina', 1)),
                'tamanioPagina': int(request.GET.get('tamanio', 10)),
            })
        except Exception as exc:
            return JsonResponse({'error': str(exc)}, status=500)

    if request.method == 'GET' and id_producto:
        try:
            row = obtener_producto(id_producto)
            if not row:
                return JsonResponse({'error': 'Producto no encontrado'}, status=404)
            return JsonResponse({'data': row})
        except Exception as exc:
            return JsonResponse({'error': str(exc)}, status=500)

    if request.method == 'POST' and not id_producto:
        payload = _parse_body(request)
        if not payload:
            return JsonResponse({'error': 'JSON inválido'}, status=400)
        try:
            ok, mensaje = insertar_producto(payload, actor_from_request(request, payload))
            return JsonResponse({'ok': bool(ok), 'mensaje': mensaje}, status=200 if ok else 400)
        except Exception as exc:
            return JsonResponse({'error': str(exc)}, status=500)

    if request.method == 'PUT' and id_producto:
        payload = _parse_body(request)
        if not payload:
            return JsonResponse({'error': 'JSON inválido'}, status=400)
        try:
            ok, mensaje = actualizar_producto(id_producto, payload, actor_from_request(request, payload))
            return JsonResponse({'ok': bool(ok), 'mensaje': mensaje}, status=200 if ok else 400)
        except Exception as exc:
            return JsonResponse({'error': str(exc)}, status=500)

    if request.method == 'DELETE' and id_producto:
        try:
            ok, mensaje = eliminar_producto(id_producto, actor_from_request(request))
            return JsonResponse({'ok': bool(ok), 'mensaje': mensaje}, status=200 if ok else 400)
        except Exception as exc:
            return JsonResponse({'error': str(exc)}, status=500)

    return JsonResponse({'error': 'Método no permitido'}, status=405)

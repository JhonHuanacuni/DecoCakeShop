import json
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from .db_context import actor_from_request
from .venta_crud_service import (
    listar_ventas, obtener_venta, insertar_venta, actualizar_venta, eliminar_venta,
    anular_venta,
)
from .cotizacion_crud_service import catalogos_cotizacion


def _parse_body(request):
    try:
        return json.loads(request.body.decode('utf-8'))
    except Exception:
        return None


@csrf_exempt
def ventas_catalogos(request):
    if request.method != 'GET':
        return JsonResponse({'error': 'Método no permitido'}, status=405)
    try:
        return JsonResponse(catalogos_cotizacion())
    except Exception as exc:
        return JsonResponse({'error': str(exc)}, status=500)


@csrf_exempt
def venta_anular(request, id_venta):
    if request.method != 'POST':
        return JsonResponse({'error': 'Método no permitido'}, status=405)
    try:
        ok, mensaje = anular_venta(id_venta, actor_from_request(request))
        return JsonResponse({'ok': bool(ok), 'mensaje': mensaje}, status=200 if ok else 400)
    except Exception as exc:
        return JsonResponse({'error': str(exc)}, status=500)


@csrf_exempt
def ventas_mantenedor(request, id_venta=None):
    if request.method == 'GET' and not id_venta:
        try:
            data, total = listar_ventas(
                request.GET.get('buscar') or None,
                request.GET.get('estado') or None,
                request.GET.get('ordenarPor', 'FECHA'),
                request.GET.get('direccion', 'DESC'),
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

    if request.method == 'GET' and id_venta:
        try:
            row = obtener_venta(id_venta)
            if not row:
                return JsonResponse({'error': 'Venta no encontrada'}, status=404)
            return JsonResponse({'data': row})
        except Exception as exc:
            return JsonResponse({'error': str(exc)}, status=500)

    if request.method == 'POST' and not id_venta:
        payload = _parse_body(request)
        if not payload:
            return JsonResponse({'error': 'JSON inválido'}, status=400)
        try:
            ok, mensaje = insertar_venta(payload, actor_from_request(request, payload))
            return JsonResponse({'ok': bool(ok), 'mensaje': mensaje}, status=200 if ok else 400)
        except Exception as exc:
            return JsonResponse({'error': str(exc)}, status=500)

    if request.method == 'PUT' and id_venta:
        payload = _parse_body(request)
        if not payload:
            return JsonResponse({'error': 'JSON inválido'}, status=400)
        try:
            ok, mensaje = actualizar_venta(id_venta, payload, actor_from_request(request, payload))
            return JsonResponse({'ok': bool(ok), 'mensaje': mensaje}, status=200 if ok else 400)
        except Exception as exc:
            return JsonResponse({'error': str(exc)}, status=500)

    if request.method == 'DELETE' and id_venta:
        try:
            ok, mensaje = eliminar_venta(id_venta, actor_from_request(request))
            return JsonResponse({'ok': bool(ok), 'mensaje': mensaje}, status=200 if ok else 400)
        except Exception as exc:
            return JsonResponse({'error': str(exc)}, status=500)

    return JsonResponse({'error': 'Método no permitido'}, status=405)

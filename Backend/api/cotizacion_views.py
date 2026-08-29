import json
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from .db_context import actor_from_request
from .cotizacion_crud_service import (
    listar_cotizaciones, obtener_cotizacion, insertar_cotizacion,
    actualizar_cotizacion, eliminar_cotizacion, convertir_cotizacion,
    catalogos_cotizacion, anular_cotizacion,
    listar_pagos_cotizacion, insertar_pago_cotizacion,
    guardar_envio_cotizacion,
)


def _parse_body(request):
    try:
        return json.loads(request.body.decode('utf-8'))
    except Exception:
        return None


@csrf_exempt
def cotizaciones_catalogos(request):
    if request.method != 'GET':
        return JsonResponse({'error': 'Método no permitido'}, status=405)
    try:
        return JsonResponse(catalogos_cotizacion())
    except Exception as exc:
        return JsonResponse({'error': str(exc)}, status=500)


@csrf_exempt
def cotizacion_hacer_pedido(request, id_cotizacion):
    if request.method != 'POST':
        return JsonResponse({'error': 'Método no permitido'}, status=405)
    payload = _parse_body(request) or {}
    try:
        ok, mensaje = convertir_cotizacion(id_cotizacion, payload, actor_from_request(request, payload))
        return JsonResponse({'ok': bool(ok), 'mensaje': mensaje}, status=200 if ok else 400)
    except Exception as exc:
        return JsonResponse({'error': str(exc)}, status=500)


@csrf_exempt
def cotizacion_envio(request, id_cotizacion):
    if request.method != 'POST':
        return JsonResponse({'error': 'Método no permitido'}, status=405)
    payload = _parse_body(request) or {}
    try:
        ok, mensaje = guardar_envio_cotizacion(id_cotizacion, payload, actor_from_request(request, payload))
        return JsonResponse({'ok': bool(ok), 'mensaje': mensaje}, status=200 if ok else 400)
    except Exception as exc:
        return JsonResponse({'error': str(exc)}, status=500)


@csrf_exempt
def cotizacion_anular(request, id_cotizacion):
    if request.method != 'POST':
        return JsonResponse({'error': 'Método no permitido'}, status=405)
    try:
        ok, mensaje = anular_cotizacion(id_cotizacion, actor_from_request(request))
        return JsonResponse({'ok': bool(ok), 'mensaje': mensaje}, status=200 if ok else 400)
    except Exception as exc:
        return JsonResponse({'error': str(exc)}, status=500)


@csrf_exempt
def cotizacion_pagos(request, id_cotizacion):
    if request.method == 'GET':
        try:
            data = listar_pagos_cotizacion(id_cotizacion)
            if not data:
                return JsonResponse({'error': 'Cotización no encontrada'}, status=404)
            return JsonResponse({'data': data})
        except Exception as exc:
            return JsonResponse({'error': str(exc)}, status=500)
    if request.method == 'POST':
        payload = _parse_body(request) or {}
        try:
            ok, mensaje = insertar_pago_cotizacion(id_cotizacion, payload, actor_from_request(request, payload))
            return JsonResponse({'ok': bool(ok), 'mensaje': mensaje}, status=200 if ok else 400)
        except Exception as exc:
            return JsonResponse({'error': str(exc)}, status=500)
    return JsonResponse({'error': 'Método no permitido'}, status=405)


@csrf_exempt
def cotizaciones_mantenedor(request, id_cotizacion=None):
    if request.method == 'GET' and not id_cotizacion:
        try:
            data, total = listar_cotizaciones(
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

    if request.method == 'GET' and id_cotizacion:
        try:
            row = obtener_cotizacion(id_cotizacion)
            if not row:
                return JsonResponse({'error': 'Cotización no encontrada'}, status=404)
            return JsonResponse({'data': row})
        except Exception as exc:
            return JsonResponse({'error': str(exc)}, status=500)

    if request.method == 'POST' and not id_cotizacion:
        payload = _parse_body(request)
        if not payload:
            return JsonResponse({'error': 'JSON inválido'}, status=400)
        try:
            ok, mensaje, id_val = insertar_cotizacion(payload, actor_from_request(request, payload))
            return JsonResponse({'ok': bool(ok), 'mensaje': mensaje, 'id': id_val}, status=200 if ok else 400)
        except Exception as exc:
            return JsonResponse({'error': str(exc)}, status=500)

    if request.method == 'PUT' and id_cotizacion:
        payload = _parse_body(request)
        if not payload:
            return JsonResponse({'error': 'JSON inválido'}, status=400)
        try:
            ok, mensaje = actualizar_cotizacion(id_cotizacion, payload, actor_from_request(request, payload))
            return JsonResponse({'ok': bool(ok), 'mensaje': mensaje}, status=200 if ok else 400)
        except Exception as exc:
            return JsonResponse({'error': str(exc)}, status=500)

    if request.method == 'DELETE' and id_cotizacion:
        try:
            ok, mensaje = eliminar_cotizacion(id_cotizacion, actor_from_request(request))
            return JsonResponse({'ok': bool(ok), 'mensaje': mensaje}, status=200 if ok else 400)
        except Exception as exc:
            return JsonResponse({'error': str(exc)}, status=500)

    return JsonResponse({'error': 'Método no permitido'}, status=405)

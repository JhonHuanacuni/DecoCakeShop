from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from .pago_crud_service import listar_pagos, obtener_pago


@csrf_exempt
def pagos_mantenedor(request, id_pago=None):
    if request.method == 'GET' and not id_pago:
        try:
            data, total = listar_pagos(
                request.GET.get('buscar') or None,
                request.GET.get('tipo') or None,
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

    if request.method == 'GET' and id_pago:
        try:
            row = obtener_pago(id_pago)
            if not row:
                return JsonResponse({'error': 'Pago no encontrado'}, status=404)
            return JsonResponse({'data': row})
        except Exception as exc:
            return JsonResponse({'error': str(exc)}, status=500)

    return JsonResponse({'error': 'Método no permitido'}, status=405)

import json
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from .db_context import actor_from_request
from .usuario_crud_service import (
    listar_usuarios, obtener_usuario, insertar_usuario,
    actualizar_usuario, eliminar_usuario, resetear_contra_usuario,
    listar_tipos_usuario,
)


def _parse_body(request):
    try:
        return json.loads(request.body.decode('utf-8'))
    except Exception:
        return None


@csrf_exempt
def tipos_usuario(request):
    if request.method != 'GET':
        return JsonResponse({'error': 'Método no permitido'}, status=405)
    try:
        return JsonResponse({'data': listar_tipos_usuario()})
    except Exception as exc:
        return JsonResponse({'error': str(exc)}, status=500)


@csrf_exempt
def usuarios_mantenedor(request, id_usuario=None):
    if request.method == 'GET' and not id_usuario:
        try:
            data, total = listar_usuarios(
                request.GET.get('buscar') or None,
                request.GET.get('estado') or None,
                request.GET.get('ordenarPor', 'IDUSUARIO'),
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

    if request.method == 'GET' and id_usuario:
        try:
            row = obtener_usuario(id_usuario)
            if not row:
                return JsonResponse({'error': 'Usuario no encontrado'}, status=404)
            return JsonResponse({'data': row})
        except Exception as exc:
            return JsonResponse({'error': str(exc)}, status=500)

    if request.method == 'POST' and not id_usuario:
        payload = _parse_body(request)
        if not payload:
            return JsonResponse({'error': 'JSON inválido'}, status=400)
        try:
            ok, mensaje = insertar_usuario(payload, actor_from_request(request))
            return JsonResponse({'ok': bool(ok), 'mensaje': mensaje}, status=200 if ok else 400)
        except Exception as exc:
            return JsonResponse({'error': str(exc)}, status=500)

    if request.method == 'PUT' and id_usuario:
        payload = _parse_body(request)
        if not payload:
            return JsonResponse({'error': 'JSON inválido'}, status=400)
        try:
            ok, mensaje = actualizar_usuario(id_usuario, payload, actor_from_request(request))
            return JsonResponse({'ok': bool(ok), 'mensaje': mensaje}, status=200 if ok else 400)
        except Exception as exc:
            return JsonResponse({'error': str(exc)}, status=500)

    if request.method == 'DELETE' and id_usuario:
        try:
            ok, mensaje = eliminar_usuario(id_usuario, actor_from_request(request))
            return JsonResponse({'ok': bool(ok), 'mensaje': mensaje}, status=200 if ok else 400)
        except Exception as exc:
            return JsonResponse({'error': str(exc)}, status=500)

    return JsonResponse({'error': 'Método no permitido'}, status=405)


@csrf_exempt
def usuario_resetear_contra(request, id_usuario):
    if request.method != 'POST':
        return JsonResponse({'error': 'Método no permitido'}, status=405)
    try:
        ok, mensaje = resetear_contra_usuario(id_usuario, actor_from_request(request))
        return JsonResponse({'ok': bool(ok), 'mensaje': mensaje}, status=200 if ok else 400)
    except Exception as exc:
        return JsonResponse({'error': str(exc)}, status=500)

import json
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from rest_framework import viewsets
from rest_framework.permissions import AllowAny
from .services import validate_user
from .modulos_services import (
    get_usuarios_activos,
    listar_modulos_con_submodulos,
    listar_modulos_efectivos_usuario,
    listar_modulos_disponibles_rol,
    listar_modulos_efectivos_rol,
    get_effective_modulos,
    get_menu_for_user,
    asignar_modulo_usuario,
    desasignar_modulo_usuario,
    asignar_modulo_usuario_orm,
    desasignar_modulo_usuario_orm,
    listar_submodulos_modulo_usuario,
    asignar_submodulo_usuario,
    desasignar_submodulo_usuario,
    asignar_submodulo_usuario_orm,
    desasignar_submodulo_usuario_orm,
    asignar_modulo_rol,
    desasignar_modulo_rol,
    asignar_modulo_rol_orm,
    desasignar_modulo_rol_orm,
    listar_submodulos_modulo_rol,
    asignar_submodulo_rol,
    desasignar_submodulo_rol,
    asignar_submodulo_rol_orm,
    desasignar_submodulo_rol_orm,
)
from .models import Modulo, Submodulo, UsuarioModulo, GrupoModulo
from .serializers import (
    ModuloSerializer, SubmoduloSerializer, UsuarioModuloSerializer,
    GrupoModuloSerializer,
)


def status_api(request):
    return JsonResponse({'message': 'Django backend conectado', 'status': 'ok'})


@csrf_exempt
def login(request):
    if request.method != 'POST':
        return JsonResponse({'error': 'Method not allowed'}, status=405)

    try:
        payload = json.loads(request.body.decode('utf-8'))
    except Exception:
        return JsonResponse({'error': 'JSON inválido'}, status=400)

    username = payload.get('username')
    password = payload.get('password')

    if not username or not password:
        return JsonResponse({'error': 'username y password son requeridos'}, status=400)

    try:
        valid, role = validate_user(username, password)
        idtipousuario = None
        if valid:
            from .modulos_services import get_usuario_tipo
            idtipousuario = get_usuario_tipo(username)
    except Exception as exc:
        return JsonResponse({'error': str(exc)}, status=500)

    return JsonResponse({
        'valid': valid,
        'role': role,
        'idusuario': username if valid else None,
        'idtipousuario': idtipousuario,
    })


@csrf_exempt
def menu_usuario(request):
    if request.method != 'GET':
        return JsonResponse({'error': 'Método no permitido'}, status=405)

    idusuario = request.GET.get('idusuario')
    if not idusuario:
        return JsonResponse({'error': 'idusuario es requerido'}, status=400)

    try:
        menu = get_menu_for_user(idusuario)
        return JsonResponse({'success': True, 'menu': menu})
    except Exception as exc:
        return JsonResponse({'error': str(exc)}, status=500)


@csrf_exempt
def usuarios_activos(request):
    if request.method != 'GET':
        return JsonResponse({'error': 'Método no permitido'}, status=405)
    try:
        return JsonResponse({'success': True, 'usuarios': get_usuarios_activos()})
    except Exception as exc:
        return JsonResponse({'error': str(exc)}, status=500)


class ModuloViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Modulo.objects.filter(ACTIVO=True).order_by('ORDEN')
    serializer_class = ModuloSerializer
    permission_classes = [AllowAny]


class SubmoduloViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Submodulo.objects.filter(ACTIVO=True).order_by('ORDEN')
    serializer_class = SubmoduloSerializer
    permission_classes = [AllowAny]


class UsuarioModuloViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = UsuarioModulo.objects.all()
    serializer_class = UsuarioModuloSerializer
    permission_classes = [AllowAny]


class GrupoModuloViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = GrupoModulo.objects.all()
    serializer_class = GrupoModuloSerializer
    permission_classes = [AllowAny]


@csrf_exempt
def modulos_disponibles(request):
    if request.method != 'GET':
        return JsonResponse({'error': 'Método no permitido'}, status=405)

    try:
        idusuario = request.GET.get('idusuario')
        idtipousuario = request.GET.get('idtipousuario')
        todos = listar_modulos_con_submodulos()

        if idtipousuario:
            modulos_list = listar_modulos_disponibles_rol(idtipousuario)
        elif idusuario:
            efectivos = set(get_effective_modulos(idusuario).keys())
            modulos_list = [m for m in todos if m['IDMODULO'] not in efectivos]
        else:
            modulos_list = todos

        return JsonResponse({'success': True, 'modulos': modulos_list})
    except Exception as exc:
        return JsonResponse({'error': str(exc)}, status=500)


@csrf_exempt
def modulos_asignados_usuario(request):
    if request.method == 'GET':
        idusuario = request.GET.get('idusuario')
        if not idusuario:
            return JsonResponse({'error': 'idusuario es requerido'}, status=400)

        try:
            asignados = listar_modulos_efectivos_usuario(idusuario)
            return JsonResponse({'success': True, 'asignados': asignados})
        except Exception as exc:
            try:
                permisos_map = get_effective_modulos(idusuario)
                modulos = Modulo.objects.filter(
                    IDMODULO__in=permisos_map.keys(), ACTIVO=True,
                ).order_by('ORDEN')
                asignados = [
                    {
                        'IDMODULO': m.IDMODULO,
                        'NOMBRE': m.NOMBRE,
                        'DESCRIPCION': m.DESCRIPCION,
                        'ICONO': m.ICONO,
                        'ORDEN': m.ORDEN,
                        'PERMISOS': permisos_map.get(m.IDMODULO, []),
                    }
                    for m in modulos
                ]
                return JsonResponse({'success': True, 'asignados': asignados})
            except Exception as inner:
                return JsonResponse({'error': str(inner)}, status=500)

    if request.method == 'POST':
        try:
            payload = json.loads(request.body.decode('utf-8'))
        except Exception:
            return JsonResponse({'error': 'JSON inválido'}, status=400)

        idusuario = payload.get('idusuario')
        idmodulo = payload.get('idmodulo')
        accion = payload.get('accion')

        if not idusuario or not idmodulo or not accion:
            return JsonResponse({'error': 'Faltan parámetros requeridos'}, status=400)

        try:
            if accion == 'asignar':
                try:
                    asignar_modulo_usuario(idusuario, idmodulo)
                except Exception:
                    asignar_modulo_usuario_orm(idusuario, idmodulo)
                return JsonResponse({'success': True, 'message': 'Módulo asignado'})

            if accion == 'desasignar':
                try:
                    desasignar_modulo_usuario(idusuario, idmodulo)
                except ValueError as exc:
                    return JsonResponse({'error': str(exc)}, status=400)
                except Exception:
                    try:
                        desasignar_modulo_usuario_orm(idusuario, idmodulo)
                    except ValueError as exc:
                        return JsonResponse({'error': str(exc)}, status=400)
                return JsonResponse({'success': True, 'message': 'Módulo desasignado'})

            return JsonResponse({'error': 'accion inválida'}, status=400)
        except Exception as exc:
            return JsonResponse({'error': str(exc)}, status=500)

    return JsonResponse({'error': 'Método no permitido'}, status=405)


@csrf_exempt
def submodulos_modulo_usuario(request):
    if request.method == 'GET':
        idusuario = request.GET.get('idusuario')
        idmodulo = request.GET.get('idmodulo')
        if not idusuario or not idmodulo:
            return JsonResponse({'error': 'idusuario e idmodulo son requeridos'}, status=400)
        try:
            submodulos = listar_submodulos_modulo_usuario(idusuario, idmodulo)
            asignados = [s for s in submodulos if s.get('asignado')]
            disponibles = [s for s in submodulos if not s.get('asignado')]
            return JsonResponse({
                'success': True,
                'submodulos': submodulos,
                'asignados': asignados,
                'disponibles': disponibles,
            })
        except Exception as exc:
            return JsonResponse({'error': str(exc)}, status=500)

    if request.method == 'POST':
        try:
            payload = json.loads(request.body.decode('utf-8'))
        except Exception:
            return JsonResponse({'error': 'JSON inválido'}, status=400)

        idusuario = payload.get('idusuario')
        idsubmodulo = payload.get('idsubmodulo')
        accion = payload.get('accion')

        if not idusuario or not idsubmodulo or not accion:
            return JsonResponse({'error': 'Faltan parámetros requeridos'}, status=400)

        try:
            if accion == 'asignar':
                try:
                    asignar_submodulo_usuario(idusuario, idsubmodulo)
                except Exception:
                    asignar_submodulo_usuario_orm(idusuario, idsubmodulo)
                return JsonResponse({'success': True, 'message': 'Submódulo asignado'})

            if accion == 'desasignar':
                try:
                    desasignar_submodulo_usuario(idusuario, idsubmodulo)
                except Exception:
                    desasignar_submodulo_usuario_orm(idusuario, idsubmodulo)
                return JsonResponse({'success': True, 'message': 'Submódulo desasignado'})

            return JsonResponse({'error': 'accion inválida'}, status=400)
        except ValueError as exc:
            return JsonResponse({'error': str(exc)}, status=400)
        except Exception as exc:
            return JsonResponse({'error': str(exc)}, status=500)

    return JsonResponse({'error': 'Método no permitido'}, status=405)


@csrf_exempt
def modulos_asignados_rol(request):
    if request.method == 'GET':
        idtipousuario = request.GET.get('idtipousuario')
        if not idtipousuario:
            return JsonResponse({'error': 'idtipousuario es requerido'}, status=400)

        try:
            asignados = listar_modulos_efectivos_rol(idtipousuario)
            return JsonResponse({'success': True, 'asignados': asignados})
        except Exception as exc:
            return JsonResponse({'error': str(exc)}, status=500)

    if request.method == 'POST':
        try:
            payload = json.loads(request.body.decode('utf-8'))
        except Exception:
            return JsonResponse({'error': 'JSON inválido'}, status=400)

        idtipousuario = payload.get('idtipousuario')
        idmodulo = payload.get('idmodulo')
        accion = payload.get('accion')

        if not idtipousuario or not idmodulo or not accion:
            return JsonResponse({'error': 'Faltan parámetros requeridos'}, status=400)

        try:
            if accion == 'asignar':
                try:
                    asignar_modulo_rol(idtipousuario, idmodulo)
                except Exception:
                    asignar_modulo_rol_orm(idtipousuario, idmodulo)
                return JsonResponse({'success': True, 'message': 'Módulo asignado al rol'})

            if accion == 'desasignar':
                try:
                    desasignar_modulo_rol(idtipousuario, idmodulo)
                except ValueError as exc:
                    return JsonResponse({'error': str(exc)}, status=400)
                except Exception:
                    try:
                        desasignar_modulo_rol_orm(idtipousuario, idmodulo)
                    except ValueError as exc:
                        return JsonResponse({'error': str(exc)}, status=400)
                return JsonResponse({'success': True, 'message': 'Módulo desasignado del rol'})

            return JsonResponse({'error': 'accion inválida'}, status=400)
        except Exception as exc:
            return JsonResponse({'error': str(exc)}, status=500)

    return JsonResponse({'error': 'Método no permitido'}, status=405)


@csrf_exempt
def submodulos_modulo_rol(request):
    if request.method == 'GET':
        idtipousuario = request.GET.get('idtipousuario')
        idmodulo = request.GET.get('idmodulo')
        if not idtipousuario or not idmodulo:
            return JsonResponse({'error': 'idtipousuario e idmodulo son requeridos'}, status=400)
        try:
            submodulos = listar_submodulos_modulo_rol(idtipousuario, idmodulo)
            asignados = [s for s in submodulos if s.get('asignado')]
            disponibles = [s for s in submodulos if not s.get('asignado')]
            return JsonResponse({
                'success': True,
                'submodulos': submodulos,
                'asignados': asignados,
                'disponibles': disponibles,
            })
        except Exception as exc:
            return JsonResponse({'error': str(exc)}, status=500)

    if request.method == 'POST':
        try:
            payload = json.loads(request.body.decode('utf-8'))
        except Exception:
            return JsonResponse({'error': 'JSON inválido'}, status=400)

        idtipousuario = payload.get('idtipousuario')
        idsubmodulo = payload.get('idsubmodulo')
        accion = payload.get('accion')

        if not idtipousuario or not idsubmodulo or not accion:
            return JsonResponse({'error': 'Faltan parámetros requeridos'}, status=400)

        try:
            if accion == 'asignar':
                try:
                    asignar_submodulo_rol(idtipousuario, idsubmodulo)
                except Exception:
                    asignar_submodulo_rol_orm(idtipousuario, idsubmodulo)
                return JsonResponse({'success': True, 'message': 'Submódulo asignado al rol'})

            if accion == 'desasignar':
                try:
                    desasignar_submodulo_rol(idtipousuario, idsubmodulo)
                except Exception:
                    desasignar_submodulo_rol_orm(idtipousuario, idsubmodulo)
                return JsonResponse({'success': True, 'message': 'Submódulo desasignado del rol'})

            return JsonResponse({'error': 'accion inválida'}, status=400)
        except ValueError as exc:
            return JsonResponse({'error': str(exc)}, status=400)
        except Exception as exc:
            return JsonResponse({'error': str(exc)}, status=500)

    return JsonResponse({'error': 'Método no permitido'}, status=405)

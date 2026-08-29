import uuid
from django.db import connection
from django.utils import timezone
from . import sp_runner as sp
from .models import (
    Modulo, Submodulo, UsuarioModulo, GrupoModulo,
    UsuarioModuloExcluido, UsuarioSubmoduloExcluido, GrupoSubmoduloExcluido,
    Usuario, TipoUsuario,
)
from .menu_config import (
    MODULO_PAGE_MAP, SUBMODULO_PAGE_MAP, MODULOS_MENU_DIRECTO,
    MODULOS_PROTEGIDOS_ADMIN,
)


def _fecha_hoy():
    return timezone.localtime().strftime('%d%m%Y')


def get_usuarios_activos():
    rows = list(
        Usuario.objects.filter(ESTADO='Activo')
        .select_related('IDTIPOUSUARIO')
        .values(
            'IDUSUARIO', 'NOMBRE', 'APELLIDO', 'EMAIL',
            'IDTIPOUSUARIO_id', 'IDTIPOUSUARIO__DESCRIPCION',
        )
        .order_by('NOMBRE', 'APELLIDO')
    )
    return [
        {
            'id': r['IDUSUARIO'],
            'nombre': f"{r.get('NOMBRE', '').strip()} {r.get('APELLIDO', '').strip()}".strip(),
            'email': r.get('EMAIL'),
            'idTipoUsuario': r.get('IDTIPOUSUARIO_id'),
            'tipoUsuario': r.get('IDTIPOUSUARIO__DESCRIPCION'),
        }
        for r in rows
    ]


def get_usuario_tipo(idusuario: str):
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT IDTIPOUSUARIO FROM USUARIO WHERE IDUSUARIO = %s AND ESTADO = 'Activo'",
            [idusuario],
        )
        row = cursor.fetchone()
        if row:
            return str(row[0])
        # Compatibilidad: si el cliente envió el ID de rol en vez del usuario
        cursor.execute(
            "SELECT IDTIPOUSUARIO FROM TIPOUSUARIO WHERE IDTIPOUSUARIO = %s",
            [idusuario],
        )
        row = cursor.fetchone()
    return str(row[0]) if row else None


def _permisos_agregados_por_modulo(idusuario, id_tipo):
    permisos = {}

    grupo_rows = GrupoModulo.objects.filter(
        IDTIPOUSUARIO=id_tipo,
    ).select_related('IDTIPOPERMISO').values(
        'IDMODULO_id', 'IDTIPOPERMISO__DESCRIPCION',
    )
    for row in grupo_rows:
        mid = row['IDMODULO_id']
        perm = row['IDTIPOPERMISO__DESCRIPCION']
        if perm:
            permisos.setdefault(mid, [])
            if perm not in permisos[mid]:
                permisos[mid].append(perm)

    usuario_rows = UsuarioModulo.objects.filter(
        IDUSUARIO=idusuario,
    ).select_related('IDTIPOPERMISO').values(
        'IDMODULO_id', 'IDTIPOPERMISO__DESCRIPCION',
    )
    for row in usuario_rows:
        mid = row['IDMODULO_id']
        perm = row['IDTIPOPERMISO__DESCRIPCION']
        if perm:
            permisos.setdefault(mid, [])
            if perm not in permisos[mid]:
                permisos[mid].append(perm)

    excluidos = set(
        UsuarioModuloExcluido.objects.filter(
            IDUSUARIO=idusuario,
        ).values_list('IDMODULO_id', flat=True)
    )
    for mid in excluidos:
        if id_tipo == '3' and mid in MODULOS_PROTEGIDOS_ADMIN:
            continue
        permisos.pop(mid, None)

    if id_tipo == '3':
        for mid in MODULOS_PROTEGIDOS_ADMIN:
            if mid not in permisos:
                permisos[mid] = ['VER', 'CREAR', 'EDITAR', 'ELIMINAR']

    return permisos


def get_effective_modulos(idusuario: str):
    id_tipo = get_usuario_tipo(idusuario)
    if not id_tipo:
        return {}
    return _permisos_agregados_por_modulo(idusuario, id_tipo)


def _submodulos_excluidos_usuario(idusuario: str):
    try:
        return set(
            UsuarioSubmoduloExcluido.objects.filter(
                IDUSUARIO=idusuario,
            ).values_list('IDSUBMODULO_id', flat=True)
        )
    except Exception:
        return set()


def _submodulos_excluidos_rol(idtipousuario: str):
    try:
        return set(
            GrupoSubmoduloExcluido.objects.filter(
                IDTIPOUSUARIO=idtipousuario,
            ).values_list('IDSUBMODULO_id', flat=True)
        )
    except Exception:
        return set()


def _submodulos_excluidos_efectivos(idusuario: str):
    excluidos = _submodulos_excluidos_usuario(idusuario)
    id_tipo = get_usuario_tipo(idusuario)
    if id_tipo:
        excluidos |= _submodulos_excluidos_rol(id_tipo)
    return excluidos


def _limpiar_exclusiones_submodulos_modulo(idusuario: str, idmodulo: str):
    try:
        UsuarioSubmoduloExcluido.objects.filter(
            IDUSUARIO=idusuario,
            IDSUBMODULO__IDMODULO_id=idmodulo,
        ).delete()
    except Exception:
        pass


def listar_submodulos_modulo_usuario(idusuario: str, idmodulo: str):
    if idmodulo not in get_effective_modulos(idusuario):
        return []

    try:
        with connection.cursor() as cursor:
            if sp.is_mysql():
                rows = sp.call_simple(cursor, 'usp_submodulos_modulo_usuario', [idusuario, idmodulo])
            else:
                cursor.execute(
                    'EXEC usp_submodulos_modulo_usuario @idusuario=%s, @idmodulo=%s',
                    [idusuario, idmodulo],
                )
                rows = sp.cursor_rows(cursor)
        return [
            {
                'IDSUBMODULO': row['IDSUBMODULO'],
                'NOMBRE': row['NOMBRE'],
                'DESCRIPCION': row.get('DESCRIPCION'),
                'ICONO': row.get('ICONO'),
                'ORDEN': row.get('ORDEN'),
                'asignado': bool(row.get('asignado')),
            }
            for row in rows
        ]
    except Exception:
        excluidos = _submodulos_excluidos_efectivos(idusuario)
        subs = Submodulo.objects.filter(
            IDMODULO_id=idmodulo, ACTIVO=True,
        ).order_by('ORDEN', 'NOMBRE')
        return [
            {
                'IDSUBMODULO': sub.IDSUBMODULO,
                'NOMBRE': sub.NOMBRE,
                'DESCRIPCION': sub.DESCRIPCION,
                'ICONO': sub.ICONO,
                'ORDEN': sub.ORDEN,
                'asignado': sub.IDSUBMODULO not in excluidos,
            }
            for sub in subs
        ]


def _enriquecer_modulos_con_submodulos(idusuario: str, modulos):
    for mod in modulos:
        idmodulo = mod.get('IDMODULO')
        subs = listar_submodulos_modulo_usuario(idusuario, idmodulo)
        mod['submodulos'] = subs
        mod['totalSubmodulos'] = len(subs)
        mod['submodulosAsignados'] = sum(1 for s in subs if s.get('asignado'))
    return modulos


def get_menu_for_user(idusuario: str):
    permisos_por_modulo = get_effective_modulos(idusuario)
    if not permisos_por_modulo:
        return []

    modulos = Modulo.objects.filter(
        IDMODULO__in=permisos_por_modulo.keys(),
        ACTIVO=True,
    ).order_by('ORDEN')

    menu = []
    excluidos_sub = _submodulos_excluidos_efectivos(idusuario)

    for modulo in modulos:
        page = MODULO_PAGE_MAP.get(modulo.IDMODULO, modulo.IDMODULO.lower())
        permisos = permisos_por_modulo.get(modulo.IDMODULO, [])

        subs_qs = Submodulo.objects.filter(
            IDMODULO=modulo, ACTIVO=True,
        ).order_by('ORDEN')

        if modulo.IDMODULO in MODULOS_MENU_DIRECTO or not subs_qs.exists():
            menu.append({
                'idmodulo': modulo.IDMODULO,
                'nombre': modulo.NOMBRE,
                'icono': modulo.ICONO or 'faCircle',
                'page': page,
                'permisos': permisos,
                'type': 'link',
            })
            continue

        submodulos = [
            {
                'idsubmodulo': sub.IDSUBMODULO,
                'nombre': sub.NOMBRE,
                'icono': sub.ICONO or 'faCircle',
                'page': SUBMODULO_PAGE_MAP.get(sub.IDSUBMODULO, page),
            }
            for sub in subs_qs
            if sub.IDSUBMODULO not in excluidos_sub
        ]

        if not submodulos:
            continue

        menu.append({
            'idmodulo': modulo.IDMODULO,
            'nombre': modulo.NOMBRE,
            'icono': modulo.ICONO or 'faCircle',
            'page': page,
            'permisos': permisos,
            'type': 'section',
            'section': page,
            'submodulos': submodulos,
        })

    return menu


def listar_modulos_efectivos_usuario(idusuario: str):
    try:
        with connection.cursor() as cursor:
            if sp.is_mysql():
                rows = sp.call_simple(cursor, 'usp_modulos_efectivos_usuario', [idusuario])
            else:
                cursor.execute(
                    'EXEC usp_modulos_efectivos_usuario @idusuario=%s',
                    [idusuario],
                )
                rows = sp.cursor_rows(cursor)

        resultado = []
        for row in rows:
            permisos_raw = row.get('PERMISOS') or ''
            permisos = [p.strip() for p in permisos_raw.split(',') if p.strip()]
            resultado.append({
                'IDMODULO': row['IDMODULO'],
                'NOMBRE': row['NOMBRE'],
                'DESCRIPCION': row.get('DESCRIPCION'),
                'ICONO': row.get('ICONO'),
                'ORDEN': row.get('ORDEN'),
                'PERMISOS': permisos,
            })
        return _enriquecer_modulos_con_submodulos(idusuario, resultado)
    except Exception:
        permisos_map = _permisos_agregados_por_modulo(
            idusuario, get_usuario_tipo(idusuario) or '',
        )
        modulos = Modulo.objects.filter(
            IDMODULO__in=permisos_map.keys(), ACTIVO=True,
        ).order_by('ORDEN')
        resultado = [
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
        return _enriquecer_modulos_con_submodulos(idusuario, resultado)


def listar_modulos_con_submodulos():
    modulos = list(
        Modulo.objects.filter(ACTIVO=True).values(
            'IDMODULO', 'NOMBRE', 'DESCRIPCION', 'ICONO', 'ORDEN',
        ).order_by('ORDEN', 'NOMBRE')
    )
    for mod in modulos:
        submodulos = Submodulo.objects.filter(
            IDMODULO_id=mod['IDMODULO'], ACTIVO=True,
        ).values('IDSUBMODULO', 'NOMBRE', 'ICONO', 'ORDEN').order_by('ORDEN')
        mod['submodulos'] = list(submodulos)
    return modulos


def asignar_modulo_usuario(idusuario: str, idmodulo: str):
    with connection.cursor() as cursor:
        if sp.is_mysql():
            sp.call_simple(cursor, 'usp_modulo_asignar_usuario', [idusuario, idmodulo])
        else:
            cursor.execute(
                'EXEC usp_modulo_asignar_usuario @idusuario=%s, @idmodulo=%s',
                [idusuario, idmodulo],
            )


def desasignar_modulo_usuario(idusuario: str, idmodulo: str):
    validar_desasignacion_modulo(idusuario, idmodulo)
    with connection.cursor() as cursor:
        if sp.is_mysql():
            sp.call_simple(cursor, 'usp_modulo_desasignar_usuario', [idusuario, idmodulo])
        else:
            cursor.execute(
                'EXEC usp_modulo_desasignar_usuario @idusuario=%s, @idmodulo=%s',
                [idusuario, idmodulo],
            )


def asignar_modulo_usuario_orm(idusuario: str, idmodulo: str):
    UsuarioModuloExcluido.objects.filter(
        IDUSUARIO=idusuario, IDMODULO_id=idmodulo,
    ).delete()

    for idperm in ('TP001', 'TP002'):
        if not UsuarioModulo.objects.filter(
            IDUSUARIO=idusuario,
            IDMODULO_id=idmodulo,
            IDTIPOPERMISO_id=idperm,
        ).exists():
            UsuarioModulo.objects.create(
                IDUSUARIOMODULO=f"UM_{uuid.uuid4().hex[:12].upper()}",
                IDUSUARIO=idusuario,
                IDMODULO_id=idmodulo,
                IDTIPOPERMISO_id=idperm,
            )


def validar_desasignacion_modulo(idusuario: str, idmodulo: str):
    id_tipo = get_usuario_tipo(idusuario)
    if id_tipo == '3' and idmodulo in MODULOS_PROTEGIDOS_ADMIN:
        raise ValueError(
            'No se puede quitar este módulo a un administrador '
            '(Dashboard y Administración de Módulos son obligatorios).'
        )


def desasignar_modulo_usuario_orm(idusuario: str, idmodulo: str):
    validar_desasignacion_modulo(idusuario, idmodulo)
    id_tipo = get_usuario_tipo(idusuario)
    UsuarioModulo.objects.filter(
        IDUSUARIO=idusuario, IDMODULO_id=idmodulo,
    ).delete()

    if id_tipo and GrupoModulo.objects.filter(
        IDTIPOUSUARIO=id_tipo, IDMODULO_id=idmodulo,
    ).exists():
        if not UsuarioModuloExcluido.objects.filter(
            IDUSUARIO=idusuario, IDMODULO_id=idmodulo,
        ).exists():
            UsuarioModuloExcluido.objects.create(
                IDUSUARIOEXCLUIDO=f"EX_{uuid.uuid4().hex[:12].upper()}",
                IDUSUARIO=idusuario,
                IDMODULO_id=idmodulo,
                FECHAREGISTRO=_fecha_hoy(),
            )

    _limpiar_exclusiones_submodulos_modulo(idusuario, idmodulo)


def asignar_submodulo_usuario(idusuario: str, idsubmodulo: str):
    with connection.cursor() as cursor:
        if sp.is_mysql():
            sp.call_simple(cursor, 'usp_submodulo_asignar_usuario', [idusuario, idsubmodulo])
        else:
            cursor.execute(
                'EXEC usp_submodulo_asignar_usuario @idusuario=%s, @idsubmodulo=%s',
                [idusuario, idsubmodulo],
            )


def desasignar_submodulo_usuario(idusuario: str, idsubmodulo: str):
    with connection.cursor() as cursor:
        if sp.is_mysql():
            sp.call_simple(cursor, 'usp_submodulo_desasignar_usuario', [idusuario, idsubmodulo])
        else:
            cursor.execute(
                'EXEC usp_submodulo_desasignar_usuario @idusuario=%s, @idsubmodulo=%s',
                [idusuario, idsubmodulo],
            )


def asignar_submodulo_usuario_orm(idusuario: str, idsubmodulo: str):
    sub = Submodulo.objects.filter(IDSUBMODULO=idsubmodulo, ACTIVO=True).first()
    if not sub:
        raise ValueError('Submódulo no encontrado o inactivo')
    if sub.IDMODULO_id not in get_effective_modulos(idusuario):
        raise ValueError('El usuario no tiene acceso al módulo padre de este submódulo')
    UsuarioSubmoduloExcluido.objects.filter(
        IDUSUARIO=idusuario, IDSUBMODULO_id=idsubmodulo,
    ).delete()


def desasignar_submodulo_usuario_orm(idusuario: str, idsubmodulo: str):
    sub = Submodulo.objects.filter(IDSUBMODULO=idsubmodulo, ACTIVO=True).first()
    if not sub:
        raise ValueError('Submódulo no encontrado o inactivo')
    if sub.IDMODULO_id not in get_effective_modulos(idusuario):
        raise ValueError('El usuario no tiene acceso al módulo padre de este submódulo')
    if not UsuarioSubmoduloExcluido.objects.filter(
        IDUSUARIO=idusuario, IDSUBMODULO_id=idsubmodulo,
    ).exists():
        UsuarioSubmoduloExcluido.objects.create(
            IDUSUARIOEXCLSUB=f"EXS_{uuid.uuid4().hex[:12].upper()}",
            IDUSUARIO=idusuario,
            IDSUBMODULO_id=idsubmodulo,
            FECHAREGISTRO=_fecha_hoy(),
        )


def get_tipos_usuario_activos():
    return list(
        TipoUsuario.objects.values('IDTIPOUSUARIO', 'DESCRIPCION').order_by('IDTIPOUSUARIO')
    )


def _permisos_por_modulo_rol(idtipousuario: str):
    permisos = {}
    for row in GrupoModulo.objects.filter(
        IDTIPOUSUARIO=idtipousuario,
    ).select_related('IDTIPOPERMISO').values(
        'IDMODULO_id', 'IDTIPOPERMISO__DESCRIPCION',
    ):
        mid = row['IDMODULO_id']
        perm = row['IDTIPOPERMISO__DESCRIPCION']
        if perm:
            permisos.setdefault(mid, [])
            if perm not in permisos[mid]:
                permisos[mid].append(perm)

    if idtipousuario == '3':
        for mid in MODULOS_PROTEGIDOS_ADMIN:
            if mid not in permisos:
                permisos[mid] = ['VER', 'CREAR', 'EDITAR', 'ELIMINAR']

    return permisos


def listar_modulos_efectivos_rol(idtipousuario: str):
    try:
        with connection.cursor() as cursor:
            if sp.is_mysql():
                rows = sp.call_simple(cursor, 'usp_modulos_efectivos_rol', [idtipousuario])
            else:
                cursor.execute(
                    'EXEC usp_modulos_efectivos_rol @idtipousuario=%s',
                    [idtipousuario],
                )
                rows = sp.cursor_rows(cursor)

        resultado = []
        for row in rows:
            permisos_raw = row.get('PERMISOS') or ''
            permisos = [p.strip() for p in permisos_raw.split(',') if p.strip()]
            resultado.append({
                'IDMODULO': row['IDMODULO'],
                'NOMBRE': row['NOMBRE'],
                'DESCRIPCION': row.get('DESCRIPCION'),
                'ICONO': row.get('ICONO'),
                'ORDEN': row.get('ORDEN'),
                'PERMISOS': permisos,
            })
        return _enriquecer_modulos_con_submodulos_rol(idtipousuario, resultado)
    except Exception:
        permisos_map = _permisos_por_modulo_rol(idtipousuario)
        modulos = Modulo.objects.filter(
            IDMODULO__in=permisos_map.keys(), ACTIVO=True,
        ).order_by('ORDEN')
        resultado = [
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
        return _enriquecer_modulos_con_submodulos_rol(idtipousuario, resultado)


def listar_modulos_disponibles_rol(idtipousuario: str):
    todos = listar_modulos_con_submodulos()
    asignados = set(_permisos_por_modulo_rol(idtipousuario).keys())
    return [m for m in todos if m['IDMODULO'] not in asignados]


def _enriquecer_modulos_con_submodulos_rol(idtipousuario: str, modulos):
    for mod in modulos:
        idmodulo = mod.get('IDMODULO')
        subs = listar_submodulos_modulo_rol(idtipousuario, idmodulo)
        mod['submodulos'] = subs
        mod['totalSubmodulos'] = len(subs)
        mod['submodulosAsignados'] = sum(1 for s in subs if s.get('asignado'))
    return modulos


def listar_submodulos_modulo_rol(idtipousuario: str, idmodulo: str):
    if idmodulo not in _permisos_por_modulo_rol(idtipousuario):
        return []

    try:
        with connection.cursor() as cursor:
            if sp.is_mysql():
                rows = sp.call_simple(cursor, 'usp_submodulos_modulo_rol', [idtipousuario, idmodulo])
            else:
                cursor.execute(
                    'EXEC usp_submodulos_modulo_rol @idtipousuario=%s, @idmodulo=%s',
                    [idtipousuario, idmodulo],
                )
                rows = sp.cursor_rows(cursor)
        return [
            {
                'IDSUBMODULO': row['IDSUBMODULO'],
                'NOMBRE': row['NOMBRE'],
                'DESCRIPCION': row.get('DESCRIPCION'),
                'ICONO': row.get('ICONO'),
                'ORDEN': row.get('ORDEN'),
                'asignado': bool(row.get('asignado')),
            }
            for row in rows
        ]
    except Exception:
        excluidos = _submodulos_excluidos_rol(idtipousuario)
        subs = Submodulo.objects.filter(
            IDMODULO_id=idmodulo, ACTIVO=True,
        ).order_by('ORDEN', 'NOMBRE')
        return [
            {
                'IDSUBMODULO': sub.IDSUBMODULO,
                'NOMBRE': sub.NOMBRE,
                'DESCRIPCION': sub.DESCRIPCION,
                'ICONO': sub.ICONO,
                'ORDEN': sub.ORDEN,
                'asignado': sub.IDSUBMODULO not in excluidos,
            }
            for sub in subs
        ]


def validar_desasignacion_modulo_rol(idtipousuario: str, idmodulo: str):
    if idtipousuario == '3' and idmodulo in MODULOS_PROTEGIDOS_ADMIN:
        raise ValueError(
            'No se puede quitar este módulo al rol Administrador '
            '(Dashboard y Administración de Módulos son obligatorios).'
        )


def asignar_modulo_rol(idtipousuario: str, idmodulo: str):
    with connection.cursor() as cursor:
        if sp.is_mysql():
            sp.call_simple(cursor, 'usp_modulo_asignar_rol', [idtipousuario, idmodulo])
        else:
            cursor.execute(
                'EXEC usp_modulo_asignar_rol @idtipousuario=%s, @idmodulo=%s',
                [idtipousuario, idmodulo],
            )


def desasignar_modulo_rol(idtipousuario: str, idmodulo: str):
    validar_desasignacion_modulo_rol(idtipousuario, idmodulo)
    with connection.cursor() as cursor:
        if sp.is_mysql():
            sp.call_simple(cursor, 'usp_modulo_desasignar_rol', [idtipousuario, idmodulo])
        else:
            cursor.execute(
                'EXEC usp_modulo_desasignar_rol @idtipousuario=%s, @idmodulo=%s',
                [idtipousuario, idmodulo],
            )


def asignar_modulo_rol_orm(idtipousuario: str, idmodulo: str):
    for idperm in ('TP001', 'TP002', 'TP003', 'TP004'):
        if not GrupoModulo.objects.filter(
            IDTIPOUSUARIO=idtipousuario,
            IDMODULO_id=idmodulo,
            IDTIPOPERMISO_id=idperm,
        ).exists():
            GrupoModulo.objects.create(
                IDGRUPOMODULO=f"GRM_{uuid.uuid4().hex[:12].upper()}",
                IDTIPOUSUARIO=idtipousuario,
                IDMODULO_id=idmodulo,
                IDTIPOPERMISO_id=idperm,
            )


def desasignar_modulo_rol_orm(idtipousuario: str, idmodulo: str):
    validar_desasignacion_modulo_rol(idtipousuario, idmodulo)
    GrupoModulo.objects.filter(
        IDTIPOUSUARIO=idtipousuario, IDMODULO_id=idmodulo,
    ).delete()
    try:
        GrupoSubmoduloExcluido.objects.filter(
            IDTIPOUSUARIO=idtipousuario,
            IDSUBMODULO__IDMODULO_id=idmodulo,
        ).delete()
    except Exception:
        pass


def asignar_submodulo_rol(idtipousuario: str, idsubmodulo: str):
    with connection.cursor() as cursor:
        if sp.is_mysql():
            sp.call_simple(cursor, 'usp_submodulo_asignar_rol', [idtipousuario, idsubmodulo])
        else:
            cursor.execute(
                'EXEC usp_submodulo_asignar_rol @idtipousuario=%s, @idsubmodulo=%s',
                [idtipousuario, idsubmodulo],
            )


def desasignar_submodulo_rol(idtipousuario: str, idsubmodulo: str):
    with connection.cursor() as cursor:
        if sp.is_mysql():
            sp.call_simple(cursor, 'usp_submodulo_desasignar_rol', [idtipousuario, idsubmodulo])
        else:
            cursor.execute(
                'EXEC usp_submodulo_desasignar_rol @idtipousuario=%s, @idsubmodulo=%s',
                [idtipousuario, idsubmodulo],
            )


def asignar_submodulo_rol_orm(idtipousuario: str, idsubmodulo: str):
    sub = Submodulo.objects.filter(IDSUBMODULO=idsubmodulo, ACTIVO=True).first()
    if not sub:
        raise ValueError('Submódulo no encontrado o inactivo')
    if sub.IDMODULO_id not in _permisos_por_modulo_rol(idtipousuario):
        raise ValueError('El rol no tiene acceso al módulo padre de este submódulo')
    GrupoSubmoduloExcluido.objects.filter(
        IDTIPOUSUARIO=idtipousuario, IDSUBMODULO_id=idsubmodulo,
    ).delete()


def desasignar_submodulo_rol_orm(idtipousuario: str, idsubmodulo: str):
    sub = Submodulo.objects.filter(IDSUBMODULO=idsubmodulo, ACTIVO=True).first()
    if not sub:
        raise ValueError('Submódulo no encontrado o inactivo')
    if sub.IDMODULO_id not in _permisos_por_modulo_rol(idtipousuario):
        raise ValueError('El rol no tiene acceso al módulo padre de este submódulo')
    if not GrupoSubmoduloExcluido.objects.filter(
        IDTIPOUSUARIO=idtipousuario, IDSUBMODULO_id=idsubmodulo,
    ).exists():
        GrupoSubmoduloExcluido.objects.create(
            IDGRUPOEXCLSUB=f"GEXS_{uuid.uuid4().hex[:12].upper()}",
            IDTIPOUSUARIO=idtipousuario,
            IDSUBMODULO_id=idsubmodulo,
            FECHAREGISTRO=_fecha_hoy(),
        )

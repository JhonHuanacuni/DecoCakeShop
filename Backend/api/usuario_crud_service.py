from django.db import connection
from .db_context import prepare_write_cursor
from .models import TipoUsuario
from . import sp_runner as sp
from .crud_exec import listar_std, escribir


def listar_usuarios(buscar=None, estado=None, ordenar_por='IDUSUARIO', direccion='ASC', pagina=1, tamanio=10):
    return listar_std('usp_usuario_listar', buscar, estado, ordenar_por, direccion, pagina, tamanio)


def obtener_usuario(id_usuario: str):
    return sp.call_obtain('usp_usuario_obtener', id_usuario)


def insertar_usuario(payload: dict, id_usuario=None):
    id_val = payload.get('IDUSUARIO') or payload.get('DNI')
    contra_val = payload.get('CONTRA') or payload.get('DNI') or payload.get('IDUSUARIO')
    params = [
        id_val, contra_val,
        payload['NOMBRE'], payload['APELLIDO'], payload['DNI'],
        payload['EMAIL'], payload.get('TELEFONO'), payload.get('DIRECCION'),
        payload['IDTIPOUSUARIO'], payload.get('ESTADO', 'Activo'),
        payload.get('FOTO'),
    ]
    with connection.cursor() as cursor:
        prepare_write_cursor(cursor, id_usuario, payload)
        if sp.is_mysql():
            return sp.call_write_inout(
                cursor, 'usp_usuario_insertar', id_val, contra_val, params[2:],
            )
        cursor.execute(
            """
            DECLARE @R INT, @M NVARCHAR(200);
            EXEC dbo.usp_usuario_insertar
                @Id=%s, @Contra=%s, @Nombre=%s, @Apellido=%s, @Dni=%s, @Email=%s,
                @Telefono=%s, @Direccion=%s, @IdTipoUsuario=%s, @Estado=%s, @Foto=%s,
                @Resultado=@R OUTPUT, @Mensaje=@M OUTPUT;
            SELECT @R AS Resultado, @M AS Mensaje;
            """,
            params,
        )
        return sp.read_write_result(cursor)


def actualizar_usuario(id_usuario: str, payload: dict, id_actor=None):
    params = [
        id_usuario,
        payload.get('CONTRA') or None,
        payload['NOMBRE'], payload['APELLIDO'], payload['DNI'],
        payload['EMAIL'], payload.get('TELEFONO'), payload.get('DIRECCION'),
        payload['IDTIPOUSUARIO'], payload['ESTADO'],
        payload.get('FOTO'),
        1 if 'FOTO' in payload else 0,
    ]
    return escribir(
        'usp_usuario_actualizar',
        '@Id=%s, @Contra=%s, @Nombre=%s, @Apellido=%s, @Dni=%s, @Email=%s, '
        '@Telefono=%s, @Direccion=%s, @IdTipoUsuario=%s, @Estado=%s, @Foto=%s, @ActualizarFoto=%s',
        params, id_actor, payload,
    )


def eliminar_usuario(id_usuario: str, id_actor=None):
    return escribir('usp_usuario_eliminar', '@Id=%s', [id_usuario], id_actor)


def resetear_contra_usuario(id_usuario: str, id_actor=None):
    return escribir('usp_usuario_resetear_contra', '@Id=%s', [id_usuario], id_actor)


def listar_tipos_usuario():
    return list(
        TipoUsuario.objects.values('IDTIPOUSUARIO', 'DESCRIPCION').order_by('IDTIPOUSUARIO')
    )

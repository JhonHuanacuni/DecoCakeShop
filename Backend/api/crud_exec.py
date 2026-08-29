from django.db import connection
from .db_context import prepare_write_cursor
from . import sp_runner as sp


def listar_paginado(proc, named_sql, params):
    with connection.cursor() as cursor:
        if sp.is_mysql():
            return sp.call_list(cursor, proc, params)
        cursor.execute(
            f"""
            DECLARE @Total INT;
            EXEC dbo.{proc}
                {named_sql}, @TotalRegistros=@Total OUTPUT;
            SELECT @Total AS TotalRegistros;
            """,
            params,
        )
        data = sp.cursor_rows(cursor)
        total = 0
        if cursor.nextset() and cursor.description:
            row = cursor.fetchone()
            if row:
                total = int(row[0])
    return data, total


def escribir(proc, named_sql, params, id_usuario=None, payload=None):
    with connection.cursor() as cursor:
        prepare_write_cursor(cursor, id_usuario, payload)
        if sp.is_mysql():
            return sp.call_write(cursor, proc, params)
        cursor.execute(
            f"""
            DECLARE @R INT, @M NVARCHAR(200);
            EXEC dbo.{proc}
                {named_sql},
                @Resultado=@R OUTPUT, @Mensaje=@M OUTPUT;
            SELECT @R AS Resultado, @M AS Mensaje;
            """,
            params,
        )
        return sp.read_write_result(cursor)


def listar_std(proc, buscar, estado, ordenar_por, direccion, pagina, tamanio):
    return listar_paginado(
        proc,
        '@Buscar=%s, @Estado=%s, @OrdenarPor=%s, @Direccion=%s, @Pagina=%s, @TamanioPagina=%s',
        [buscar or None, estado or None, ordenar_por, direccion, pagina, tamanio],
    )

"""Ejecución de stored procedures: SQL Server (EXEC) y MySQL (CALL)."""

from django.db import connection


def is_mysql():
    return connection.vendor == 'mysql'


def cursor_rows(cursor):
    columns = [col[0] for col in cursor.description] if cursor.description else []
    return [dict(zip(columns, row)) for row in cursor.fetchall()]


def drain_sets(cursor):
    while cursor.nextset():
        pass


def read_write_result(cursor):
    """Lee Resultado/Mensaje del último result set (SQL Server) o tras CALL (MySQL)."""
    resultado, mensaje = 0, 'Error desconocido'
    while True:
        if cursor.description:
            row = cursor.fetchone()
            if row:
                cols = [c[0].lower() for c in cursor.description]
                data = dict(zip(cols, row))
                resultado = data.get('resultado', resultado)
                mensaje = data.get('mensaje', mensaje)
        if not cursor.nextset():
            break
    return int(resultado or 0), str(mensaje or '')


def _placeholders(n):
    return ', '.join(['%s'] * n)


def call_simple(cursor, proc, params):
    if is_mysql():
        cursor.execute(f'CALL {proc}({_placeholders(len(params))})', list(params))
        while True:
            if cursor.description:
                rows = cursor_rows(cursor)
                if rows:
                    return rows
            if not cursor.nextset():
                break
        return []
    raise RuntimeError('call_simple: use rama SQL Server en el servicio')


def call_proc_rows(cursor, proc, params=None, mssql_args=''):
    """SP de solo lectura. params posicionales; mssql_args es '@Foo=%s, @Bar=%s'."""
    params = list(params or [])
    if is_mysql():
        return call_simple(cursor, proc, params)
    sql = f'EXEC dbo.{proc}'
    if mssql_args:
        sql = f'{sql} {mssql_args}'
    cursor.execute(sql, params)
    return cursor_rows(cursor)


def call_obtain(proc, param):
    with connection.cursor() as cursor:
        if is_mysql():
            rows = call_simple(cursor, proc, [param])
            return rows[0] if rows else None
        cursor.execute(f'EXEC dbo.{proc} @Id=%s', [param])
        rows = cursor_rows(cursor)
    return rows[0] if rows else None


def call_list(cursor, proc, params, total_var='@_sp_total'):
    if is_mysql():
        cursor.execute(f'SET {total_var} = 0')
        cursor.execute(
            f'CALL {proc}({_placeholders(len(params))}, {total_var})',
            list(params),
        )
        data = cursor_rows(cursor)
        drain_sets(cursor)
        cursor.execute(f'SELECT {total_var}')
        row = cursor.fetchone()
        total = int(row[0] or 0) if row else 0
        return data, total
    raise RuntimeError('call_list: use rama SQL Server en el servicio')


def call_write(cursor, proc, params, r_var='@_sp_r', m_var='@_sp_m'):
    if is_mysql():
        cursor.execute(f'SET {r_var} = 0, {m_var} = NULL')
        cursor.execute(
            f'CALL {proc}({_placeholders(len(params))}, {r_var}, {m_var})',
            list(params),
        )
        drain_sets(cursor)
        cursor.execute(f'SELECT {r_var} AS Resultado, {m_var} AS Mensaje')
        row = cursor.fetchone()
        if not row:
            return 0, 'Error desconocido'
        return int(row[0] or 0), str(row[1] or '')
    raise RuntimeError('call_write: use rama SQL Server en el servicio')


def call_write_inout(cursor, proc, id_val, contra_val, params):
    if is_mysql():
        cursor.execute('SET @_in_id = %s, @_in_contra = %s', [id_val, contra_val])
        cursor.execute('SET @_sp_r = 0, @_sp_m = NULL')
        ph = _placeholders(len(params))
        cursor.execute(
            f'CALL {proc}(@_in_id, @_in_contra, {ph}, @_sp_r, @_sp_m)',
            list(params),
        )
        drain_sets(cursor)
        cursor.execute('SELECT @_sp_r AS Resultado, @_sp_m AS Mensaje')
        row = cursor.fetchone()
        if not row:
            return 0, 'Error desconocido'
        return int(row[0] or 0), str(row[1] or '')
    raise RuntimeError('call_write_inout: use rama SQL Server en el servicio')

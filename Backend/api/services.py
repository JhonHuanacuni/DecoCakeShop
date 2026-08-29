from django.db import connection


def validate_user(username: str, password: str):
    with connection.cursor() as cursor:
        if connection.vendor == 'mysql':
            cursor.execute(
                'CALL usp_validate_user(%s, %s)',
                [username, password],
            )
            row = cursor.fetchone()
            while cursor.nextset():
                pass
        else:
            cursor.execute(
                'EXEC usp_validate_user @username=%s, @password=%s',
                [username, password],
            )
            row = cursor.fetchone()

    if not row:
        return False, None

    is_valid = bool(row[0])
    role = row[1] if len(row) > 1 else None
    return is_valid, role

"""
Importa todos los scripts de db_scripts_mysql/ en orden.
Uso (desde Backend/ con venv activo):
  python scripts/setup_mysql_db.py
  python scripts/setup_mysql_db.py --skip-import
  python scripts/setup_mysql_db.py --force

Lee DB_* del .env; si DB_PASSWORD está vacío, usa MYSQL_ROOT_PASSWORD del entorno.
"""
import argparse
import os
import re
import sys
from pathlib import Path

import pymysql
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent
SCRIPTS_DIR = BASE_DIR / 'db_scripts_mysql'
ORDER_FILE = SCRIPTS_DIR / '16_08_2026' / 'ORDEN_EJECUCION.txt'

SKIP_ERROR_CODES = {
    1060,  # Duplicate column
    1061,  # Duplicate key name
    1062,  # Duplicate key (reimport seed)
    1826,  # Duplicate foreign key
    3780,  # Referencing column and referenced column in a foreign key differ
}


def _order():
    names = [
        ln.strip()
        for ln in ORDER_FILE.read_text(encoding='utf-8').splitlines()
        if ln.strip() and not ln.strip().startswith('#')
    ]
    return ['00_create_database.sql'] + [f'16_08_2026/{n}' for n in names]


def _split_on_semicolon(sql: str) -> list[str]:
    parts: list[str] = []
    buf: list[str] = []
    in_str = False
    in_line_comment = False
    i = 0
    while i < len(sql):
        ch = sql[i]
        if in_line_comment:
            buf.append(ch)
            if ch == '\n':
                in_line_comment = False
            i += 1
            continue
        if ch == "'" and not in_str:
            in_str = True
            buf.append(ch)
        elif ch == "'" and in_str:
            buf.append(ch)
            if i + 1 < len(sql) and sql[i + 1] == "'":
                buf.append("'")
                i += 1
            else:
                in_str = False
        elif not in_str and ch == '-' and i + 1 < len(sql) and sql[i + 1] == '-':
            in_line_comment = True
            buf.append(ch)
            buf.append(sql[i + 1])
            i += 2
            continue
        elif ch == ';' and not in_str:
            stmt = ''.join(buf).strip()
            if stmt:
                parts.append(stmt)
            buf = []
        else:
            buf.append(ch)
        i += 1
    tail = ''.join(buf).strip()
    if tail:
        parts.append(tail)
    return parts


def split_sql(content: str):
    content = content.replace('\r\n', '\n').replace('\r', '\n')
    content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
    lines = content.splitlines()
    chunks: list[str] = []
    buf: list[str] = []
    delimiter = ';'

    for line in lines:
        stripped = line.strip()
        if stripped.upper().startswith('DELIMITER '):
            if buf:
                block = '\n'.join(buf)
                if delimiter == ';':
                    chunks.extend(_split_on_semicolon(block))
                else:
                    chunks.append(block)
                buf = []
            delimiter = stripped.split(None, 1)[1]
            continue
        buf.append(line)
        if stripped.endswith(delimiter):
            block = '\n'.join(buf).rstrip()
            if delimiter != ';':
                block = block[: -len(delimiter)].rstrip()
            buf = []
            if block.strip():
                if delimiter == ';':
                    chunks.extend(_split_on_semicolon(block))
                else:
                    chunks.append(block)
    if buf:
        tail = '\n'.join(buf).strip()
        if tail:
            if delimiter == ';':
                chunks.extend(_split_on_semicolon(tail))
            else:
                chunks.append(tail)
    return chunks


def _strip_leading_comments(sql: str) -> str:
    lines = sql.splitlines()
    while lines:
        stripped = lines[0].strip()
        if not stripped or stripped.startswith('--'):
            lines.pop(0)
            continue
        break
    return '\n'.join(lines).strip()


def run_file(cursor, path: Path, rel: str | None = None):
    if rel and rel.endswith('3.auditoria.sql'):
        sql = path.read_text(encoding='utf-8')
        for n, stmt in enumerate(split_sql(sql), start=1):
            s = _strip_leading_comments(stmt.strip())
            if not s:
                continue
            if re.match(r'USE\s+', s, re.I):
                continue
            if 'usp_auditoria_instalar_trigger' in s.lower() and 'CREATE PROCEDURE' in s.upper():
                continue
            try:
                cursor.execute(s)
            except pymysql.err.ProgrammingError as exc:
                preview = s.splitlines()[0][:80] if s else ''
                print(f'ERROR en {path.name} stmt #{n} ({preview}): {exc.args[1][:200]}', file=sys.stderr)
                raise
            except pymysql.err.OperationalError as exc:
                if exc.args[0] in SKIP_ERROR_CODES:
                    continue
                preview = s.splitlines()[0][:80] if s else ''
                print(f'ERROR en {path.name} stmt #{n} ({preview}): {exc.args[1][:200]}', file=sys.stderr)
                raise
        from install_auditoria_triggers import install_auditoria_triggers
        install_auditoria_triggers(cursor)
        return

    if rel and rel.endswith(('17.modulo_cupones.sql', '21.modulo_promociones.sql')):
        sql = path.read_text(encoding='utf-8')
        for n, stmt in enumerate(split_sql(sql), start=1):
            s = _strip_leading_comments(stmt.strip())
            if not s:
                continue
            if re.match(r'USE\s+', s, re.I):
                continue
            try:
                cursor.execute(s)
            except pymysql.err.ProgrammingError as exc:
                preview = s.splitlines()[0][:80] if s else ''
                print(f'ERROR en {path.name} stmt #{n} ({preview}): {exc.args[1][:200]}', file=sys.stderr)
                raise
            except pymysql.err.OperationalError as exc:
                if exc.args[0] in SKIP_ERROR_CODES:
                    continue
                preview = s.splitlines()[0][:80] if s else ''
                print(f'ERROR en {path.name} stmt #{n} ({preview}): {exc.args[1][:200]}', file=sys.stderr)
                raise
        from install_auditoria_triggers import install_auditoria_triggers
        install_auditoria_triggers(cursor)
        return

    sql = path.read_text(encoding='utf-8')
    for n, stmt in enumerate(split_sql(sql), start=1):
        s = _strip_leading_comments(stmt.strip())
        if not s:
            continue
        if re.match(r'USE\s+', s, re.I):
            continue
        if re.match(r'CREATE\s+DATABASE\b', s, re.I):
            continue
        try:
            cursor.execute(s)
        except pymysql.err.ProgrammingError as exc:
            preview = s.splitlines()[0][:80] if s else ''
            print(f'ERROR en {path.name} stmt #{n} ({preview}): {exc.args[1][:200]}', file=sys.stderr)
            raise
        except pymysql.err.OperationalError as exc:
            if exc.args[0] in SKIP_ERROR_CODES:
                continue
            preview = s.splitlines()[0][:80] if s else ''
            print(f'ERROR en {path.name} stmt #{n} ({preview}): {exc.args[1][:200]}', file=sys.stderr)
            raise


def _connect(host, port, user, password, database=None):
    return pymysql.connect(
        host=host, port=port, user=user, password=password,
        database=database, charset='utf8mb4', autocommit=True,
    )


def _db_ready(cursor, db_name):
    cursor.execute(
        'SELECT COUNT(*) FROM information_schema.TABLES '
        'WHERE TABLE_SCHEMA = %s AND TABLE_NAME = %s',
        [db_name, 'USUARIO'],
    )
    return cursor.fetchone()[0] > 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--skip-import', action='store_true', help='Solo verificar conexión')
    parser.add_argument('--force', action='store_true', help='Importar aunque ya existan tablas')
    parser.add_argument('--file', help='Ejecutar un solo script, ej. 16_08_2026/21.modulo_promociones.sql')
    args = parser.parse_args()

    load_dotenv(BASE_DIR / '.env')
    host = os.getenv('DB_HOST', '127.0.0.1')
    port = int(os.getenv('DB_PORT', '3306'))
    user = os.getenv('DB_USER', 'root')
    password = os.getenv('DB_PASSWORD', '') or os.getenv('MYSQL_ROOT_PASSWORD', '')
    db_name = os.getenv('DB_NAME', 'DecoCakeShop')

    if not password and user != 'root':
        # En Linode usercodex siempre tiene clave; en local a veces root sin clave.
        pass
    if not ORDER_FILE.exists():
        print(f'ERROR: Falta {ORDER_FILE}. Ejecuta convert_sqlserver_to_mysql.py', file=sys.stderr)
        sys.exit(1)

    print(f'Conectando a MySQL {user}@{host}:{port} ...')
    conn = _connect(host, port, user, password or '')
    try:
        with conn.cursor() as cur:
            try:
                cur.execute('SET GLOBAL log_bin_trust_function_creators = 1')
            except pymysql.err.OperationalError:
                pass
            cur.execute(
                f'CREATE DATABASE IF NOT EXISTS `{db_name}` '
                f'CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci'
            )
            conn.select_db(db_name)
            try:
                cur.execute('SET FOREIGN_KEY_CHECKS = 0')
            except pymysql.err.OperationalError:
                pass

            if args.skip_import:
                if _db_ready(cur, db_name):
                    print(f'OK: {db_name} ya tiene tablas (USUARIO).')
                else:
                    print(f'AVISO: {db_name} sin tablas; ejecuta sin --skip-import.', file=sys.stderr)
                    sys.exit(1)
                return

            if args.file:
                rel = args.file.replace('\\', '/').lstrip('/')
                path = SCRIPTS_DIR / rel.replace('/', os.sep)
                if not path.exists():
                    print(f'FALTA: {path}', file=sys.stderr)
                    sys.exit(1)
                print(f'>>> {rel}')
                run_file(cur, path, rel)
                print(f'OK: aplicado {rel}')
                return

            if _db_ready(cur, db_name) and not args.force:
                print(f'AVISO: {db_name} ya tiene datos; omitiendo importación.')
                print('Usa --force para reimportar (destructivo).')
                print(f'OK: {db_name} lista.')
                return

            for rel in _order():
                path = SCRIPTS_DIR / rel.replace('/', os.sep)
                if not path.exists():
                    print(f'FALTA: {path}', file=sys.stderr)
                    sys.exit(1)
                print(f'>>> {rel}')
                run_file(cur, path, rel)
        print(f'OK: {db_name} lista.')
    finally:
        conn.close()


if __name__ == '__main__':
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    main()

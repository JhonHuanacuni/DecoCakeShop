"""Crea la BD DecoCakeShop en SQL Server local y ejecuta los scripts."""
import os
import shutil
import subprocess
import sys
from pathlib import Path

try:
    import pyodbc
except ImportError:
    print('Instala pyodbc: pip install pyodbc')
    sys.exit(1)

from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / '.env')

DB_NAME = os.getenv('DB_NAME', 'DecoCakeShop')
HOST = os.getenv('DB_HOST', 'localhost')
PORT = os.getenv('DB_PORT', '1433')
DRIVER = os.getenv('DB_DRIVER', 'ODBC Driver 17 for SQL Server')
TRUSTED = os.getenv('DB_TRUSTED_CONNECTION', 'true').lower() in ('1', 'true', 'yes')
USER = os.getenv('DB_USER', 'sa')
PASSWORD = os.getenv('DB_PASSWORD', '')

SCRIPTS_DIR = ROOT / 'db_scripts' / '16_08_2026'
ORDER = (SCRIPTS_DIR / 'ORDEN_EJECUCION.txt').read_text(encoding='utf-8').splitlines()
ORDER = [ln.strip() for ln in ORDER if ln.strip() and not ln.strip().startswith('#')]


def drivers():
    return [d for d in pyodbc.drivers() if 'SQL Server' in d]


def server_name():
    if PORT and PORT != '1433':
        return f'{HOST},{PORT}'
    return HOST


def conn_str(database='master'):
    found = drivers()
    drv = DRIVER if DRIVER in found else (found[-1] if found else DRIVER)
    parts = [
        f'DRIVER={{{drv}}}',
        f'SERVER={server_name()}',
        f'DATABASE={database}',
        'TrustServerCertificate=yes',
    ]
    if TRUSTED:
        parts.append('Trusted_Connection=yes')
    else:
        parts.append(f'UID={USER}')
        parts.append(f'PWD={PASSWORD}')
    return ';'.join(parts)


def sqlcmd_base():
    exe = shutil.which('sqlcmd')
    if not exe:
        raise RuntimeError('No se encontró sqlcmd. Instala SQL Server Command Line Tools.')
    cmd = [exe, '-S', server_name(), '-d', DB_NAME, '-b', '-I', '-C', '-f', '65001']
    if TRUSTED:
        cmd.append('-E')
    else:
        cmd.extend(['-U', USER, '-P', PASSWORD])
    return cmd


def main():
    print('Conectando a SQL Server...', conn_str())
    cn = pyodbc.connect(conn_str('master'), autocommit=True)
    cur = cn.cursor()
    cur.execute(
        f"IF DB_ID(N'{DB_NAME}') IS NULL CREATE DATABASE [{DB_NAME}];"
    )
    print(f'Base {DB_NAME} lista.')
    cn.close()

    for name in ORDER:
        path = SCRIPTS_DIR / name
        print(f'Ejecutando {name}...')
        result = subprocess.run(
            sqlcmd_base() + ['-i', str(path)],
            capture_output=True,
            text=True,
            encoding='utf-8',
            errors='replace',
        )
        out = (result.stdout or '').encode('ascii', 'replace').decode('ascii').strip()
        err = (result.stderr or '').encode('ascii', 'replace').decode('ascii').strip()
        if out:
            print(out)
        if result.returncode != 0:
            if err:
                print(err)
            raise RuntimeError(f'Error en {name} (código {result.returncode})')
        print(f'  OK {name}')
    print('Scripts aplicados. Usuarios: admin / vendedor / almacen  — contraseña 1234')


if __name__ == '__main__':
    main()

#!/usr/bin/env bash
# Bootstrap DecoCake en Linode. Uso:
#   cd ~/decocakeshop_src/Backend
#   chmod +x scripts/bootstrap_server.sh
#   ./scripts/bootstrap_server.sh

set -euo pipefail

BACKEND="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BACKEND"

if [[ ! -f .env ]]; then
  echo "ERROR: Crea Backend/.env (copia deploy/env.production.example)" >&2
  exit 1
fi

if [[ ! -d db_scripts_mysql ]]; then
  echo "ERROR: Falta db_scripts_mysql/. Primero hay que convertir los scripts a MySQL en tu PC." >&2
  exit 1
fi

if ! dpkg -s python3.12-venv >/dev/null 2>&1; then
  echo "Instalando python3.12-venv ..."
  sudo apt-get update -qq
  sudo apt-get install -y python3.12-venv
fi

if [[ ! -x venv/bin/python ]]; then
  echo "Creando venv ..."
  python3 -m venv venv
fi

echo "Instalando dependencias ..."
venv/bin/pip install -r requirements.txt -q

echo "Permiso para funciones MySQL ..."
sudo mysql -e "SET GLOBAL log_bin_trust_function_creators = 1;" 2>/dev/null || true

echo "Importando BD MySQL ..."
venv/bin/python scripts/setup_mysql_db.py "$@"

echo "Estáticos Django ..."
venv/bin/python manage.py collectstatic --noinput

echo ""
echo "OK. Siguiente: sudo systemctl restart gunicorn-decocakeshop"

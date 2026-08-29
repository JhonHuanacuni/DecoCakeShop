# DecoCake Shop

Sistema de gestión para importadora: productos, usuarios por rol, cotizaciones (con delivery), ventas, mantenedores, auditoría y acceso por usuario/rol.

El diseño y la arquitectura siguen el patrón de Academia 3.0: React + Vite (sin react-router), Django + DRF, tablas en SQL Server con `managed = False` y stored procedures. Más adelante se podrá cambiar `DB_ENGINE=mysql`.

## Requisitos

- Python 3.11+
- Node.js 20+
- SQL Server local (Express, Developer o instancia default) con **ODBC Driver 17** (o 18)
- Windows Authentication (Trusted Connection) o usuario `sa`

## Base de datos (SQL Server)

1. Copia `Backend/.env.example` a `Backend/.env` y ajusta host/driver si hace falta.
2. Crea el entorno e instala dependencias:

```bash
cd Backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
python scripts/setup_sqlserver.py
python manage.py migrate
```

Usuarios de prueba (contraseña `1234`):

| Usuario   | Rol            |
|-----------|----------------|
| admin     | Administrador  |
| vendedor  | Vendedor       |
| almacen   | Almacén        |

## Backend

```bash
cd Backend
.venv\Scripts\activate
python manage.py runserver
```

API en `http://127.0.0.1:8000/api/`.

## Frontend

```bash
cd Frontend
npm install
npm run dev
```

Vite en `http://127.0.0.1:5173` (proxy `/api` → Django `:8000`).

## Módulos

- **Dashboard:** KPIs de stock, cotizaciones abiertas y ventas del día.
- **Usuarios:** CRUD por roles (vendedor, almacén, administrador).
- **Productos:** nombre, precio, stock, descripción, categoría, unidad, quién creó/modificó y cuándo.
- **Cotizaciones:** líneas de producto, recojo o delivery, CRUD y **Hacer pedido** (pasa a Ventas, descuenta stock).
- **Ventas:** listado y CRUD de pedidos ya pagados.
- **Mantenedores:** categorías, clientes, unidades, formas de pago, tipos de entrega.
- **Auditoría:** altas, cambios y bajas de las tablas principales.
- **Administración de módulos:** acceso por rol y por usuario.

Todas las tablas principales tienen `CREADOPOR`, `FECHACREACION`, `HORACREACION`, `MODIFICADOPOR`, `FECHAMODIFICACION`, `HORAMODIFICACION`.

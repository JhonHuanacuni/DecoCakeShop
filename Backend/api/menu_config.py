# Módulos que se muestran como un solo enlace (sin desplegar submódulos)
MODULOS_MENU_DIRECTO = frozenset({
    'MOD001',  # Dashboard
    'MOD002',  # Usuarios
    'MOD003',  # Productos
    'MOD004',  # Cotizaciones
    'MOD005',  # Ventas
    'MOD007',  # Auditoría
    'MOD008',  # Administración de módulos
    'MOD009',  # Pagos
    'MOD010',  # Cupones
})

# Módulos que un administrador (tipo 3) no puede perder nunca
MODULOS_PROTEGIDOS_ADMIN = frozenset({
    'MOD001',
    'MOD008',
})

MODULO_PAGE_MAP = {
    'MOD001': 'dashboard',
    'MOD002': 'usuarios',
    'MOD003': 'productos',
    'MOD004': 'cotizaciones',
    'MOD005': 'ventas',
    'MOD006': 'mantenedores',
    'MOD007': 'auditoria',
    'MOD008': 'admin-modulos',
    'MOD009': 'pagos',
    'MOD010': 'cupones',
}

SUBMODULO_PAGE_MAP = {
    'SUB001': 'mantenedores-categorias',
    'SUB002': 'mantenedores-clientes',
    'SUB003': 'mantenedores-unidades',
    'SUB004': 'mantenedores-formas-pago',
    'SUB005': 'mantenedores-tipos-entrega',
}

ROLE_TO_TIPOUSUARIO = {
    'vendedor': '1',
    'almacen': '2',
    'administrador': '3',
    'admin': '3',
}

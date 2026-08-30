from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views
from . import usuario_views
from . import catalogo_views
from . import producto_views
from . import cotizacion_views
from . import venta_views
from . import auditoria_views
from . import dashboard_views
from . import pago_views
from . import tienda_views

router = DefaultRouter()
router.register(r'modulos', views.ModuloViewSet, basename='modulo')
router.register(r'submodulos', views.SubmoduloViewSet, basename='submodulo')
router.register(r'usuario-modulos', views.UsuarioModuloViewSet, basename='usuario-modulo')
router.register(r'grupo-modulos', views.GrupoModuloViewSet, basename='grupo-modulo')

urlpatterns = [
    path('status/', views.status_api, name='status'),
    path('tienda/catalogo/', tienda_views.tienda_catalogo, name='tienda_catalogo'),
    path('tienda/cupon/', tienda_views.tienda_cupon, name='tienda_cupon'),
    path('tienda/cupones/', tienda_views.tienda_cupones, name='tienda_cupones'),
    path('tienda/promociones/', tienda_views.tienda_promociones, name='tienda_promociones'),
    path('tienda/checkout/', tienda_views.tienda_checkout, name='tienda_checkout'),
    path('tienda/pedido/', tienda_views.tienda_pedido, name='tienda_pedido'),
    path('promociones/', catalogo_views.promociones_mantenedor, name='promociones_mantenedor'),
    path('promociones/<str:id_val>/', catalogo_views.promociones_mantenedor, name='promociones_mantenedor_detail'),
    path('login/', views.login, name='login'),
    path('usuarios-activos/', views.usuarios_activos, name='usuarios_activos'),
    path('tipos-usuario/', usuario_views.tipos_usuario, name='tipos_usuario'),
    path('usuarios/', usuario_views.usuarios_mantenedor, name='usuarios_mantenedor'),
    path('usuarios/<str:id_usuario>/reset-contra/', usuario_views.usuario_resetear_contra, name='usuario_resetear_contra'),
    path('usuarios/<str:id_usuario>/', usuario_views.usuarios_mantenedor, name='usuarios_mantenedor_detail'),
    path('dashboard/', dashboard_views.dashboard_api, name='dashboard_api'),
    path('productos/catalogos/', producto_views.productos_catalogos, name='productos_catalogos'),
    path('productos/', producto_views.productos_mantenedor, name='productos_mantenedor'),
    path('productos/<str:id_producto>/', producto_views.productos_mantenedor, name='productos_mantenedor_detail'),
    path('cotizaciones/catalogos/', cotizacion_views.cotizaciones_catalogos, name='cotizaciones_catalogos'),
    path('cotizaciones/', cotizacion_views.cotizaciones_mantenedor, name='cotizaciones_mantenedor'),
    path('cotizaciones/<str:id_cotizacion>/hacer-pedido/', cotizacion_views.cotizacion_hacer_pedido, name='cotizacion_hacer_pedido'),
    path('cotizaciones/<str:id_cotizacion>/envio/', cotizacion_views.cotizacion_envio, name='cotizacion_envio'),
    path('cotizaciones/<str:id_cotizacion>/anular/', cotizacion_views.cotizacion_anular, name='cotizacion_anular'),
    path('cotizaciones/<str:id_cotizacion>/pagos/', cotizacion_views.cotizacion_pagos, name='cotizacion_pagos'),
    path('cotizaciones/<str:id_cotizacion>/', cotizacion_views.cotizaciones_mantenedor, name='cotizaciones_mantenedor_detail'),
    path('ventas/catalogos/', venta_views.ventas_catalogos, name='ventas_catalogos'),
    path('ventas/', venta_views.ventas_mantenedor, name='ventas_mantenedor'),
    path('ventas/<str:id_venta>/anular/', venta_views.venta_anular, name='venta_anular'),
    path('ventas/<str:id_venta>/', venta_views.ventas_mantenedor, name='ventas_mantenedor_detail'),
    path('categorias/', catalogo_views.categorias_mantenedor, name='categorias_mantenedor'),
    path('categorias/<str:id_val>/', catalogo_views.categorias_mantenedor, name='categorias_mantenedor_detail'),
    path('unidades/', catalogo_views.unidades_mantenedor, name='unidades_mantenedor'),
    path('unidades/<str:id_val>/', catalogo_views.unidades_mantenedor, name='unidades_mantenedor_detail'),
    path('clientes/buscar/', catalogo_views.clientes_buscar, name='clientes_buscar'),
    path('clientes/', catalogo_views.clientes_mantenedor, name='clientes_mantenedor'),
    path('clientes/<str:id_val>/', catalogo_views.clientes_mantenedor, name='clientes_mantenedor_detail'),
    path('formas-pago/', catalogo_views.formas_pago_mantenedor, name='formas_pago_mantenedor'),
    path('formas-pago/<str:id_val>/', catalogo_views.formas_pago_mantenedor, name='formas_pago_mantenedor_detail'),
    path('tipos-entrega/', catalogo_views.tipos_entrega_mantenedor, name='tipos_entrega_mantenedor'),
    path('tipos-entrega/<str:id_val>/', catalogo_views.tipos_entrega_mantenedor, name='tipos_entrega_mantenedor_detail'),
    path('pagos/', pago_views.pagos_mantenedor, name='pagos_mantenedor'),
    path('pagos/<str:id_pago>/', pago_views.pagos_mantenedor, name='pagos_mantenedor_detail'),
    path('auditoria/catalogos/', auditoria_views.auditoria_mantenedor, {'id_auditoria': 'catalogos'}),
    path('auditoria/', auditoria_views.auditoria_mantenedor, name='auditoria_mantenedor'),
    path('auditoria/<str:id_auditoria>/', auditoria_views.auditoria_mantenedor, name='auditoria_mantenedor_detail'),
    path('menu-usuario/', views.menu_usuario, name='menu_usuario'),
    path('modulos-disponibles/', views.modulos_disponibles, name='modulos_disponibles'),
    path('modulos-asignados-usuario/', views.modulos_asignados_usuario, name='modulos_asignados_usuario'),
    path('modulos-asignados-rol/', views.modulos_asignados_rol, name='modulos_asignados_rol'),
    path('submodulos-modulo-usuario/', views.submodulos_modulo_usuario, name='submodulos_modulo_usuario'),
    path('submodulos-modulo-rol/', views.submodulos_modulo_rol, name='submodulos_modulo_rol'),
    path('', include(router.urls)),
]

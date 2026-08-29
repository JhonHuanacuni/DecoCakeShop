from django.db import connection
from . import sp_runner as sp


def resumen_dashboard():
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT
                (SELECT COUNT(*) FROM PRODUCTO WHERE ESTADO = 'Activo') AS PRODUCTOS_ACTIVOS,
                (SELECT ISNULL(SUM(STOCK), 0) FROM PRODUCTO WHERE ESTADO = 'Activo') AS STOCK_TOTAL,
                (SELECT COUNT(*) FROM COTIZACION WHERE ESTADO <> 'Anulada' AND NULLIF(IDVENTA, '') IS NULL) AS COTIZACIONES_ABIERTAS,
                (SELECT COUNT(*) FROM VENTA WHERE ESTADO = 'Pagado'
                    AND FECHACREACION = dbo.fn_fecha_ddmmyyyy()) AS VENTAS_HOY,
                (SELECT ISNULL(SUM(TOTAL), 0) FROM VENTA WHERE ESTADO = 'Pagado'
                    AND FECHACREACION = dbo.fn_fecha_ddmmyyyy()) AS MONTO_HOY,
                (SELECT COUNT(*) FROM CLIENTE WHERE ESTADO = 'Activo') AS CLIENTES_ACTIVOS
            """
        )
        rows = sp.cursor_rows(cursor)
    return rows[0] if rows else {}

"""
Instala triggers de auditoría (MySQL no permite PREPARE sobre CREATE TRIGGER).

Usado por setup_mysql_db.py.
"""
from __future__ import annotations

AUDITORIA_TARGETS: list[tuple[str, str]] = [
    ('USUARIO', 'IDUSUARIO'),
    ('CATEGORIA', 'IDCATEGORIA'),
    ('UNIDAD', 'IDUNIDAD'),
    ('CLIENTE', 'IDCLIENTE'),
    ('FORMA_PAGO', 'IDFORMAPAGO'),
    ('TIPO_ENTREGA', 'IDTIPOENTREGA'),
    ('PRODUCTO', 'IDPRODUCTO'),
    ('COTIZACION', 'IDCOTIZACION'),
    ('COTIZACION_PAGO', 'IDPAGO'),
    ('VENTA', 'IDVENTA'),
    ('CUPON', 'IDCUPON'),
]


def _json_object_pairs(row_prefix: str, columns: list[str]) -> str:
    return ', '.join(f"'{col}', {row_prefix}.{col}" for col in columns)


def install_auditoria_triggers(cursor) -> None:
    cursor.execute('DROP PROCEDURE IF EXISTS usp_auditoria_instalar_trigger')

    for tabla, pk in AUDITORIA_TARGETS:
        cursor.execute(
            'SELECT COUNT(*) FROM information_schema.TABLES '
            'WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = %s',
            [tabla],
        )
        if cursor.fetchone()[0] == 0:
            print(f'  auditoría omitida (tabla no existe): {tabla}')
            continue

        cursor.execute(
            'SELECT COLUMN_NAME FROM information_schema.COLUMNS '
            'WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = %s '
            'ORDER BY ORDINAL_POSITION',
            [tabla],
        )
        columns = [row[0] for row in cursor.fetchall()]
        json_new = _json_object_pairs('NEW', columns)
        json_old = _json_object_pairs('OLD', columns)

        trigger_base = f'tr_{tabla}_auditoria'
        for suffix in ('_ins', '_upd', '_del'):
            cursor.execute(f'DROP TRIGGER IF EXISTS `{trigger_base}{suffix}`')

        tbl = f'`{tabla}`'
        body_common = """
    DECLARE v_aud_id VARCHAR(50);
    CALL usp_auditoria_siguiente_id(v_aud_id);
    INSERT INTO AUDITORIA (
        IDAUDITORIA, TABLA, IDREGISTRO, ACCION, IDUSUARIO, FECHA, HORA, DATOS_ANTES, DATOS_DESPUES
    )"""

        cursor.execute(
            f"""
CREATE TRIGGER `{trigger_base}_ins` AFTER INSERT ON {tbl}
FOR EACH ROW
BEGIN
{body_common}
    VALUES (
        v_aud_id, '{tabla}', NEW.{pk}, 'INSERT', @audit_id_usuario,
        fn_fecha_ddmmyyyy(), TIME_FORMAT(NOW(), '%H:%i:%s'), NULL, JSON_OBJECT({json_new})
    );
END
"""
        )

        cursor.execute(
            f"""
CREATE TRIGGER `{trigger_base}_upd` AFTER UPDATE ON {tbl}
FOR EACH ROW
BEGIN
{body_common}
    VALUES (
        v_aud_id, '{tabla}', NEW.{pk}, 'UPDATE', @audit_id_usuario,
        fn_fecha_ddmmyyyy(), TIME_FORMAT(NOW(), '%H:%i:%s'),
        JSON_OBJECT({json_old}), JSON_OBJECT({json_new})
    );
END
"""
        )

        cursor.execute(
            f"""
CREATE TRIGGER `{trigger_base}_del` AFTER DELETE ON {tbl}
FOR EACH ROW
BEGIN
{body_common}
    VALUES (
        v_aud_id, '{tabla}', OLD.{pk}, 'DELETE', @audit_id_usuario,
        fn_fecha_ddmmyyyy(), TIME_FORMAT(NOW(), '%H:%i:%s'), JSON_OBJECT({json_old}), NULL
    );
END
"""
        )
        print(f'  triggers auditoría: {trigger_base}')

-- Convertido desde db_scripts/16_08_2026/3.auditoria.sql
-- MySQL 8 — DecoCake Shop

USE `DecoCakeShop`;

DROP PROCEDURE IF EXISTS usp_auditoria_siguiente_id;

DROP PROCEDURE IF EXISTS usp_auditoria_siguiente_id;

DELIMITER $$

CREATE PROCEDURE usp_auditoria_siguiente_id(
    OUT p_Id VARCHAR(50)
)
main: BEGIN
DECLARE v_Num INT;
    SET v_Num = 1; 
    SELECT IFNULL(MAX(CAST(SUBSTRING(IDAUDITORIA, 4, 10) AS UNSIGNED)), 0) + 1 INTO v_Num
    FROM AUDITORIA WHERE IDAUDITORIA LIKE 'AUD%';
    SET p_Id = CONCAT('AUD', RIGHT(CONCAT('000000', CAST(v_Num AS CHAR)), 6));
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_auditoria_listar;

DROP PROCEDURE IF EXISTS usp_auditoria_listar;

DELIMITER $$

CREATE PROCEDURE usp_auditoria_listar(
    IN p_Buscar VARCHAR(200),
    IN p_Tabla VARCHAR(100),
    IN p_Accion VARCHAR(20),
    IN p_IdUsuario VARCHAR(50),
    IN p_FechaDesde CHAR(8),
    IN p_FechaHasta CHAR(8),
    IN p_OrdenarPor VARCHAR(50),
    IN p_Direccion VARCHAR(4),
    IN p_Pagina INT,
    IN p_TamanioPagina INT,
    OUT p_TotalRegistros INT
)
main: BEGIN
SELECT COUNT(*) INTO p_TotalRegistros
    FROM AUDITORIA a LEFT JOIN USUARIO u ON u.IDUSUARIO=a.IDUSUARIO
    WHERE (p_Buscar IS NULL OR p_Buscar='' OR a.TABLA LIKE CONCAT('%', p_Buscar, '%') OR a.IDREGISTRO LIKE CONCAT('%', p_Buscar, '%')
           OR CONCAT(IFNULL(u.NOMBRE,''), ' ', IFNULL(u.APELLIDO,'')) LIKE CONCAT('%', p_Buscar, '%'))
      AND (p_Tabla IS NULL OR p_Tabla='' OR a.TABLA=p_Tabla)
      AND (p_Accion IS NULL OR p_Accion='' OR a.ACCION=p_Accion)
      AND (p_IdUsuario IS NULL OR p_IdUsuario='' OR a.IDUSUARIO=p_IdUsuario)
      AND (p_FechaDesde IS NULL OR p_FechaDesde='' OR a.FECHA>=p_FechaDesde)
      AND (p_FechaHasta IS NULL OR p_FechaHasta='' OR a.FECHA<=p_FechaHasta);

    SELECT a.IDAUDITORIA, a.TABLA, a.IDREGISTRO, a.ACCION, a.IDUSUARIO,
           TRIM(CONCAT(IFNULL(u.NOMBRE,''), ' ', IFNULL(u.APELLIDO,''))) AS USUARIO_NOMBRE,
           a.FECHA, a.HORA, a.DATOS_ANTES, a.DATOS_DESPUES
    FROM AUDITORIA a LEFT JOIN USUARIO u ON u.IDUSUARIO=a.IDUSUARIO
    WHERE (p_Buscar IS NULL OR p_Buscar='' OR a.TABLA LIKE CONCAT('%', p_Buscar, '%') OR a.IDREGISTRO LIKE CONCAT('%', p_Buscar, '%')
           OR CONCAT(IFNULL(u.NOMBRE,''), ' ', IFNULL(u.APELLIDO,'')) LIKE CONCAT('%', p_Buscar, '%'))
      AND (p_Tabla IS NULL OR p_Tabla='' OR a.TABLA=p_Tabla)
      AND (p_Accion IS NULL OR p_Accion='' OR a.ACCION=p_Accion)
      AND (p_IdUsuario IS NULL OR p_IdUsuario='' OR a.IDUSUARIO=p_IdUsuario)
      AND (p_FechaDesde IS NULL OR p_FechaDesde='' OR a.FECHA>=p_FechaDesde)
      AND (p_FechaHasta IS NULL OR p_FechaHasta='' OR a.FECHA<=p_FechaHasta)
    ORDER BY a.FECHA DESC, a.HORA DESC, a.IDAUDITORIA DESC
    LIMIT p_TamanioPagina OFFSET ((p_Pagina - 1) * p_TamanioPagina);
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_auditoria_obtener;

DROP PROCEDURE IF EXISTS usp_auditoria_obtener;

DELIMITER $$

CREATE PROCEDURE usp_auditoria_obtener(
    IN p_Id VARCHAR(50)
)
main: BEGIN
SELECT a.*, TRIM(CONCAT(IFNULL(u.NOMBRE,''), ' ', IFNULL(u.APELLIDO,''))) AS USUARIO_NOMBRE
    FROM AUDITORIA a LEFT JOIN USUARIO u ON u.IDUSUARIO=a.IDUSUARIO
    WHERE a.IDAUDITORIA=p_Id;
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_auditoria_tablas_catalogo;

DROP PROCEDURE IF EXISTS usp_auditoria_tablas_catalogo;

DELIMITER $$

CREATE PROCEDURE usp_auditoria_tablas_catalogo()
main: BEGIN
SET NOCOUNT ON; SELECT DISTINCT TABLA FROM AUDITORIA ORDER BY TABLA;
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_auditoria_instalar_trigger;

-- usp_auditoria_instalar_trigger: MySQL no permite PREPARE de CREATE TRIGGER.
-- Los triggers se instalan con scripts/install_auditoria_triggers.py
DROP PROCEDURE IF EXISTS usp_auditoria_instalar_trigger;

-- triggers USUARIO.IDUSUARIO: python scripts/install_auditoria_triggers.py
-- triggers CATEGORIA.IDCATEGORIA: python scripts/install_auditoria_triggers.py
-- triggers UNIDAD.IDUNIDAD: python scripts/install_auditoria_triggers.py
-- triggers CLIENTE.IDCLIENTE: python scripts/install_auditoria_triggers.py
-- triggers FORMA_PAGO.IDFORMAPAGO: python scripts/install_auditoria_triggers.py
-- triggers TIPO_ENTREGA.IDTIPOENTREGA: python scripts/install_auditoria_triggers.py
-- triggers PRODUCTO.IDPRODUCTO: python scripts/install_auditoria_triggers.py
-- triggers COTIZACION.IDCOTIZACION: python scripts/install_auditoria_triggers.py
-- triggers COTIZACION_PAGO.IDPAGO: python scripts/install_auditoria_triggers.py
-- triggers VENTA.IDVENTA: python scripts/install_auditoria_triggers.py

SELECT 'Auditoría instalada.';

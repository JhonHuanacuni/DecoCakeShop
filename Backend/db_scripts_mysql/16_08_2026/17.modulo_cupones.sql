-- Convertido desde db_scripts/16_08_2026/17.modulo_cupones.sql
-- MySQL 8 — DecoCake Shop

USE `DecoCakeShop`;

/* Incremental: módulo Cupones */

-- create if missing CUPON
CREATE TABLE IF NOT EXISTS CUPON (
    IDCUPON             VARCHAR(50)    NOT NULL PRIMARY KEY,
    CODIGO              VARCHAR(40)    NOT NULL,
    DESCRIPCION         VARCHAR(255)   NULL,
    TIPO                VARCHAR(20)    NOT NULL,
    VALOR               DECIMAL(12,2)   NOT NULL,
    MINIMO              DECIMAL(12,2)   NULL,
    FECHAINICIO         CHAR(8)         NULL,
    FECHAFIN            CHAR(8)         NULL,
    USOSMAX             INT             NULL,
    USOS                INT             NOT NULL DEFAULT 0,
    ESTADO              VARCHAR(50)    NOT NULL,
    CREADOPOR           VARCHAR(50)    NULL,
    FECHACREACION       CHAR(8)         NULL,
    HORACREACION        CHAR(8)         NULL,
    MODIFICADOPOR       VARCHAR(50)    NULL,
    FECHAMODIFICACION   CHAR(8)         NULL,
    HORAMODIFICACION    CHAR(8)         NULL,
    CONSTRAINT UQ_CUPON_CODIGO UNIQUE (CODIGO)
);

UPDATE MODULO SET ORDEN = ORDEN + 1 WHERE ORDEN >= 7 AND NOT EXISTS (SELECT 1 FROM (SELECT IDMODULO FROM MODULO WHERE IDMODULO='MOD010') t);
INSERT INTO MODULO (IDMODULO, NOMBRE, DESCRIPCION, ICONO, ORDEN, ACTIVO)
SELECT 'MOD010', 'Cupones', 'Cupones de descuento de la tienda', 'faTicket', 7, 1 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM MODULO WHERE IDMODULO='MOD010');
UPDATE MODULO
    SET NOMBRE = 'Cupones', DESCRIPCION = 'Cupones de descuento de la tienda', ICONO = 'faTicket', ACTIVO = 1
    WHERE IDMODULO = 'MOD010';

INSERT INTO GRUPO_MODULO (IDGRUPOMODULO, IDTIPOUSUARIO, IDMODULO, IDTIPOPERMISO)
SELECT CONCAT('GRM3MOD010', p.IDTIPOPERMISO), '3', 'MOD010', p.IDTIPOPERMISO
FROM TIPO_PERMISO p
WHERE NOT EXISTS (
    SELECT 1 FROM GRUPO_MODULO g
    WHERE g.IDTIPOUSUARIO = '3' AND g.IDMODULO = 'MOD010' AND g.IDTIPOPERMISO = p.IDTIPOPERMISO
);

INSERT INTO GRUPO_MODULO (IDGRUPOMODULO, IDTIPOUSUARIO, IDMODULO, IDTIPOPERMISO)
SELECT CONCAT('GRM1MOD010', p.IDTIPOPERMISO), '1', 'MOD010', p.IDTIPOPERMISO
FROM TIPO_PERMISO p
WHERE NOT EXISTS (
    SELECT 1 FROM GRUPO_MODULO g
    WHERE g.IDTIPOUSUARIO = '1' AND g.IDMODULO = 'MOD010' AND g.IDTIPOPERMISO = p.IDTIPOPERMISO
);

DROP PROCEDURE IF EXISTS usp_cupon_listar;

DROP PROCEDURE IF EXISTS usp_cupon_listar;

DELIMITER $$

CREATE PROCEDURE usp_cupon_listar(
    IN p_Buscar VARCHAR(200),
    IN p_Estado VARCHAR(50),
    IN p_OrdenarPor VARCHAR(50),
    IN p_Direccion VARCHAR(4),
    IN p_Pagina INT,
    IN p_TamanioPagina INT,
    OUT p_TotalRegistros INT
)
main: BEGIN
DECLARE v_offset INT DEFAULT 0;
    IF p_Pagina<1 THEN SET p_Pagina=1; END IF; IF p_TamanioPagina<1 THEN SET p_TamanioPagina=10; END IF;
    SELECT COUNT(*) INTO p_TotalRegistros FROM CUPON c
    WHERE (p_Buscar IS NULL OR p_Buscar='' OR c.IDCUPON LIKE CONCAT('%', p_Buscar, '%') OR c.CODIGO LIKE CONCAT('%', p_Buscar, '%') OR IFNULL(c.DESCRIPCION,'') LIKE CONCAT('%', p_Buscar, '%'))
      AND (p_Estado IS NULL OR p_Estado='' OR c.ESTADO=p_Estado);
    SET v_offset = (p_Pagina - 1) * p_TamanioPagina;
    SELECT c.*, CONCAT(cu.NOMBRE, ' ', cu.APELLIDO) AS CREADOPOR_NOMBRE, CONCAT(mu.NOMBRE, ' ', mu.APELLIDO) AS MODIFICADOPOR_NOMBRE
    FROM CUPON c
    LEFT JOIN USUARIO cu ON cu.IDUSUARIO=c.CREADOPOR
    LEFT JOIN USUARIO mu ON mu.IDUSUARIO=c.MODIFICADOPOR
    WHERE (p_Buscar IS NULL OR p_Buscar='' OR c.IDCUPON LIKE CONCAT('%', p_Buscar, '%') OR c.CODIGO LIKE CONCAT('%', p_Buscar, '%') OR IFNULL(c.DESCRIPCION,'') LIKE CONCAT('%', p_Buscar, '%'))
      AND (p_Estado IS NULL OR p_Estado='' OR c.ESTADO=p_Estado)
    ORDER BY
        CASE WHEN p_OrdenarPor='CODIGO' AND p_Direccion='ASC' THEN c.CODIGO END ASC,
        CASE WHEN p_OrdenarPor='CODIGO' AND p_Direccion='DESC' THEN c.CODIGO END DESC,
        CASE WHEN p_OrdenarPor='TIPO' AND p_Direccion='ASC' THEN c.TIPO END ASC,
        CASE WHEN p_OrdenarPor='TIPO' AND p_Direccion='DESC' THEN c.TIPO END DESC,
        CASE WHEN p_OrdenarPor='VALOR' AND p_Direccion='ASC' THEN c.VALOR END ASC,
        CASE WHEN p_OrdenarPor='VALOR' AND p_Direccion='DESC' THEN c.VALOR END DESC,
        CASE WHEN p_OrdenarPor='ESTADO' AND p_Direccion='ASC' THEN c.ESTADO END ASC,
        CASE WHEN p_OrdenarPor='ESTADO' AND p_Direccion='DESC' THEN c.ESTADO END DESC,
        c.CODIGO
    LIMIT p_TamanioPagina OFFSET v_offset;
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_cupon_obtener;

DROP PROCEDURE IF EXISTS usp_cupon_obtener;

DELIMITER $$

CREATE PROCEDURE usp_cupon_obtener(
    IN p_Id VARCHAR(50)
)
main: BEGIN
SET NOCOUNT ON; SELECT * FROM CUPON WHERE IDCUPON=p_Id;
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_cupon_insertar;

DROP PROCEDURE IF EXISTS usp_cupon_insertar;

DELIMITER $$

CREATE PROCEDURE usp_cupon_insertar(
    IN p_Codigo VARCHAR(40),
    IN p_Descripcion VARCHAR(255),
    IN p_Tipo VARCHAR(20),
    IN p_Valor DECIMAL(12,2),
    IN p_Minimo DECIMAL(12,2),
    IN p_FechaInicio CHAR(8),
    IN p_FechaFin CHAR(8),
    IN p_UsosMax INT,
    IN p_Estado VARCHAR(50),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
DECLARE v_Id VARCHAR(50);
    SET p_Codigo = UPPER(TRIM(IFNULL(p_Codigo,'')));
    IF p_Codigo='' THEN SET p_Resultado=0; SET p_Mensaje='Ingresa el código del cupón.'; LEAVE main; END IF;
    IF EXISTS (SELECT 1 FROM CUPON WHERE CODIGO=p_Codigo) THEN SET p_Resultado=0; SET p_Mensaje='Ya existe un cupón con ese código.'; LEAVE main; END IF;
    IF IFNULL(p_Valor,0) <= 0 THEN SET p_Resultado=0; SET p_Mensaje='Ingresa un valor mayor a cero.'; LEAVE main; END IF;
    IF p_Tipo NOT IN ('Porcentaje','Monto') THEN SET p_Tipo='Porcentaje'; END IF; THEN
      CALL usp_siguiente_id('CUP', 'CUPON', 'IDCUPON', v_Id);
    INSERT INTO CUPON (IDCUPON,CODIGO,DESCRIPCION,TIPO,VALOR,MINIMO,FECHAINICIO,FECHAFIN,USOSMAX,USOS,ESTADO,CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
    VALUES (v_Id,p_Codigo,p_Descripcion,p_Tipo,IFNULL(p_Valor,0),p_Minimo,NULLIF(p_FechaInicio,''),NULLIF(p_FechaFin,''),p_UsosMax,0,IFNULL(p_Estado,'Activo'),fn_actor(),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'),fn_actor(),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'));
    SET p_Resultado=1; SET p_Mensaje='Cupón registrado.';
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_cupon_actualizar;

DROP PROCEDURE IF EXISTS usp_cupon_actualizar;

DELIMITER $$

CREATE PROCEDURE usp_cupon_actualizar(
    IN p_Id VARCHAR(50),
    IN p_Codigo VARCHAR(40),
    IN p_Descripcion VARCHAR(255),
    IN p_Tipo VARCHAR(20),
    IN p_Valor DECIMAL(12,2),
    IN p_Minimo DECIMAL(12,2),
    IN p_FechaInicio CHAR(8),
    IN p_FechaFin CHAR(8),
    IN p_UsosMax INT,
    IN p_Estado VARCHAR(50),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
IF NOT EXISTS (SELECT 1 FROM CUPON WHERE IDCUPON=p_Id) THEN SET p_Resultado=0; SET p_Mensaje='El cupón no existe.'; LEAVE main; END IF;
    SET p_Codigo = UPPER(TRIM(IFNULL(p_Codigo,'')));
    IF p_Codigo='' THEN SET p_Resultado=0; SET p_Mensaje='Ingresa el código del cupón.'; LEAVE main; END IF;
    IF EXISTS (SELECT 1 FROM CUPON WHERE CODIGO=p_Codigo AND IDCUPON<>p_Id) THEN SET p_Resultado=0; SET p_Mensaje='Ya existe un cupón con ese código.'; LEAVE main; END IF;
    IF p_Tipo NOT IN ('Porcentaje','Monto') THEN SET p_Tipo='Porcentaje'; END IF;
    UPDATE CUPON SET CODIGO=p_Codigo, DESCRIPCION=p_Descripcion, TIPO=p_Tipo, VALOR=IFNULL(p_Valor,0), MINIMO=p_Minimo,
        FECHAINICIO=NULLIF(p_FechaInicio,''), FECHAFIN=NULLIF(p_FechaFin,''), USOSMAX=p_UsosMax, ESTADO=IFNULL(p_Estado,'Activo'),
        MODIFICADOPOR=fn_actor(), FECHAMODIFICACION=fn_fecha_ddmmyyyy(), HORAMODIFICACION=TIME_FORMAT(NOW(), '%H:%i:%s')
    WHERE IDCUPON=p_Id;
    SET p_Resultado=1; SET p_Mensaje='Cupón actualizado.';
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_cupon_eliminar;

DROP PROCEDURE IF EXISTS usp_cupon_eliminar;

DELIMITER $$

CREATE PROCEDURE usp_cupon_eliminar(
    IN p_Id VARCHAR(50),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
IF NOT EXISTS (SELECT 1 FROM CUPON WHERE IDCUPON=p_Id) THEN SET p_Resultado=0; SET p_Mensaje='El cupón no existe.'; LEAVE main; END IF;
    DELETE FROM CUPON WHERE IDCUPON=p_Id;
    SET p_Resultado=1; SET p_Mensaje='Cupón eliminado.';
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_cupon_validar;

DROP PROCEDURE IF EXISTS usp_cupon_validar;

DELIMITER $$

CREATE PROCEDURE usp_cupon_validar(
    IN p_Codigo VARCHAR(40),
    IN p_Subtotal DECIMAL(12,2)
)
main: BEGIN
DECLARE v_Hoy DATE;
    SET v_Hoy = CURDATE(); 
    SELECT c.IDCUPON, c.CODIGO, c.DESCRIPCION, c.TIPO, c.VALOR, c.MINIMO, c.ESTADO
    FROM CUPON c
    WHERE c.CODIGO = UPPER(TRIM(IFNULL(p_Codigo,'')))
      AND c.ESTADO='Activo'
      AND (c.USOSMAX IS NULL OR c.USOS < c.USOSMAX)
      AND (c.MINIMO IS NULL OR c.MINIMO=0 OR p_Subtotal >= c.MINIMO)
      AND (c.FECHAINICIO IS NULL OR c.FECHAINICIO='' OR STR_TO_DATE(c.FECHAINICIO, '%d%m%Y') <= v_Hoy)
      AND (c.FECHAFIN IS NULL OR c.FECHAFIN='' OR STR_TO_DATE(c.FECHAFIN, '%d%m%Y') >= v_Hoy) LIMIT 1;
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_cupon_usar;

DROP PROCEDURE IF EXISTS usp_cupon_usar;

DELIMITER $$

CREATE PROCEDURE usp_cupon_usar(
    IN p_Codigo VARCHAR(40),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
UPDATE CUPON SET USOS = USOS + 1,
        MODIFICADOPOR=fn_actor(), FECHAMODIFICACION=fn_fecha_ddmmyyyy(), HORAMODIFICACION=TIME_FORMAT(NOW(), '%H:%i:%s')
    WHERE CODIGO = UPPER(TRIM(IFNULL(p_Codigo,''))) AND ESTADO='Activo';
    IF @@ROWCOUNT=0 THEN SET p_Resultado=0; SET p_Mensaje='No se pudo registrar el uso del cupón.'; LEAVE main; END IF;
    SET p_Resultado=1; SET p_Mensaje='Cupón aplicado.';
END$$

DELIMITER ;

INSERT INTO CUPON (IDCUPON,CODIGO,DESCRIPCION,TIPO,VALOR,MINIMO,USOSMAX,USOS,ESTADO,CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
SELECT 'CUP001','DULCE10','10% de descuento en el catálogo','Porcentaje',10,0,200,0,'Activo','sistema',fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'),'sistema',fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s') FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM CUPON WHERE CODIGO='DULCE10');

INSERT INTO CUPON (IDCUPON,CODIGO,DESCRIPCION,TIPO,VALOR,MINIMO,USOSMAX,USOS,ESTADO,CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
SELECT 'CUP002','BIENVENIDA','S/ 5.00 de descuento de bienvenida','Monto',5,20,100,0,'Activo','sistema',fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'),'sistema',fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s') FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM CUPON WHERE CODIGO='BIENVENIDA');

INSERT INTO CUPON (IDCUPON,CODIGO,DESCRIPCION,TIPO,VALOR,MINIMO,USOSMAX,USOS,ESTADO,CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
SELECT 'CUP003','REPOSTERA','15% desde S/ 80.00','Porcentaje',15,80,80,0,'Activo','sistema',fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'),'sistema',fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s') FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM CUPON WHERE CODIGO='REPOSTERA');

-- skip usp_auditoria_instalar_trigger (Python)

SELECT 'Módulo Cupones listo.';

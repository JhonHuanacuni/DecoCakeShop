-- Convertido desde db_scripts/16_08_2026/2b.usp_catalogos.sql
-- MySQL 8 — DecoCake Shop

USE `DecoCakeShop`;

/* Catálogos: categoria, unidad, cliente, formapago, tipoentrega */

/* CATEGORIA */
DROP PROCEDURE IF EXISTS usp_categoria_listar;

DROP PROCEDURE IF EXISTS usp_categoria_listar;

DELIMITER $$

CREATE PROCEDURE usp_categoria_listar(
    IN p_Buscar VARCHAR(200),
    IN p_Estado VARCHAR(50),
    IN p_OrdenarPor VARCHAR(50),
    IN p_Direccion VARCHAR(4),
    IN p_Pagina INT,
    IN p_TamanioPagina INT,
    OUT p_TotalRegistros INT
)
main: BEGIN
IF p_Pagina<1 THEN SET p_Pagina=1; END IF; IF p_TamanioPagina<1 THEN SET p_TamanioPagina=10; END IF;
    SELECT COUNT(*) FROM CATEGORIA c INTO p_TotalRegistros
    WHERE (p_Buscar IS NULL OR p_Buscar='' OR c.IDCATEGORIA LIKE CONCAT('%', p_Buscar, '%') OR c.NOMBRE LIKE CONCAT('%', p_Buscar, '%'))
      AND (p_Estado IS NULL OR p_Estado='' OR c.ESTADO=p_Estado);
    SELECT c.*, CONCAT(cu.NOMBRE, ' ', cu.APELLIDO) AS CREADOPOR_NOMBRE, CONCAT(mu.NOMBRE, ' ', mu.APELLIDO) AS MODIFICADOPOR_NOMBRE
    FROM CATEGORIA c
    LEFT JOIN USUARIO cu ON cu.IDUSUARIO=c.CREADOPOR
    LEFT JOIN USUARIO mu ON mu.IDUSUARIO=c.MODIFICADOPOR
    WHERE (p_Buscar IS NULL OR p_Buscar='' OR c.IDCATEGORIA LIKE CONCAT('%', p_Buscar, '%') OR c.NOMBRE LIKE CONCAT('%', p_Buscar, '%'))
      AND (p_Estado IS NULL OR p_Estado='' OR c.ESTADO=p_Estado)
    ORDER BY
        CASE WHEN p_OrdenarPor='ORDEN' AND p_Direccion='ASC' THEN c.ORDEN END ASC,
        CASE WHEN p_OrdenarPor='ORDEN' AND p_Direccion='DESC' THEN c.ORDEN END DESC,
        CASE WHEN p_OrdenarPor='NOMBRE' AND p_Direccion='ASC' THEN c.NOMBRE END ASC,
        CASE WHEN p_OrdenarPor='NOMBRE' AND p_Direccion='DESC' THEN c.NOMBRE END DESC,
        c.ORDEN, c.NOMBRE
    LIMIT p_TamanioPagina OFFSET ((p_Pagina - 1) * p_TamanioPagina);
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_categoria_obtener;

DROP PROCEDURE IF EXISTS usp_categoria_obtener;

DELIMITER $$

CREATE PROCEDURE usp_categoria_obtener(
    IN p_Id VARCHAR(50)
)
main: BEGIN
SET NOCOUNT ON; SELECT * FROM CATEGORIA WHERE IDCATEGORIA=p_Id;
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_categoria_insertar;

DROP PROCEDURE IF EXISTS usp_categoria_insertar;

DELIMITER $$

CREATE PROCEDURE usp_categoria_insertar(
    IN p_Nombre VARCHAR(150),
    IN p_Descripcion VARCHAR(255),
    IN p_Orden INT,
    IN p_Estado VARCHAR(50),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
DECLARE v_Id VARCHAR(50);
    IF p_Nombre IS NULL OR TRIM(p_Nombre)='' THEN SET p_Resultado=0; SET p_Mensaje='Ingresa el nombre.'; LEAVE main; END IF;
    IF EXISTS (SELECT 1 FROM CATEGORIA WHERE NOMBRE=p_Nombre) THEN SET p_Resultado=0; SET p_Mensaje='Ya existe una categoría con ese nombre.'; LEAVE main; END IF; THEN
      CALL usp_siguiente_id('CAT', 'CATEGORIA', 'IDCATEGORIA', v_Id);
    INSERT INTO CATEGORIA (IDCATEGORIA,NOMBRE,DESCRIPCION,ORDEN,ESTADO,CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
    VALUES (v_Id,p_Nombre,p_Descripcion,IFNULL(p_Orden,0),IFNULL(p_Estado,'Activo'),fn_actor(),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'),fn_actor(),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'));
    SET p_Resultado=1; SET p_Mensaje='Categoría registrada.';
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_categoria_actualizar;

DROP PROCEDURE IF EXISTS usp_categoria_actualizar;

DELIMITER $$

CREATE PROCEDURE usp_categoria_actualizar(
    IN p_Id VARCHAR(50),
    IN p_Nombre VARCHAR(150),
    IN p_Descripcion VARCHAR(255),
    IN p_Orden INT,
    IN p_Estado VARCHAR(50),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
IF NOT EXISTS (SELECT 1 FROM CATEGORIA WHERE IDCATEGORIA=p_Id) THEN SET p_Resultado=0; SET p_Mensaje='La categoría no existe.'; LEAVE main; END IF;
    UPDATE CATEGORIA SET NOMBRE=p_Nombre, DESCRIPCION=p_Descripcion, ORDEN=IFNULL(p_Orden,0), ESTADO=p_Estado,
        MODIFICADOPOR=fn_actor(), FECHAMODIFICACION=fn_fecha_ddmmyyyy(), HORAMODIFICACION=TIME_FORMAT(NOW(), '%H:%i:%s')
    WHERE IDCATEGORIA=p_Id;
    SET p_Resultado=1; SET p_Mensaje='Categoría actualizada.';
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_categoria_eliminar;

DROP PROCEDURE IF EXISTS usp_categoria_eliminar;

DELIMITER $$

CREATE PROCEDURE usp_categoria_eliminar(
    IN p_Id VARCHAR(50),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
IF EXISTS (SELECT 1 FROM PRODUCTO WHERE IDCATEGORIA=p_Id) THEN SET p_Resultado=0; SET p_Mensaje='No se puede eliminar: hay productos asociados.'; LEAVE main; END IF;
    DELETE FROM CATEGORIA WHERE IDCATEGORIA=p_Id;
    SET p_Resultado=1; SET p_Mensaje='Categoría eliminada.';
END$$

DELIMITER ;

/* UNIDAD */
DROP PROCEDURE IF EXISTS usp_unidad_listar;

DROP PROCEDURE IF EXISTS usp_unidad_listar;

DELIMITER $$

CREATE PROCEDURE usp_unidad_listar(
    IN p_Buscar VARCHAR(200),
    IN p_Estado VARCHAR(50),
    IN p_OrdenarPor VARCHAR(50),
    IN p_Direccion VARCHAR(4),
    IN p_Pagina INT,
    IN p_TamanioPagina INT,
    OUT p_TotalRegistros INT
)
main: BEGIN
SELECT COUNT(*) FROM UNIDAD INTO p_TotalRegistros
    WHERE (p_Buscar IS NULL OR p_Buscar='' OR IDUNIDAD LIKE CONCAT('%', p_Buscar, '%') OR NOMBRE LIKE CONCAT('%', p_Buscar, '%'))
      AND (p_Estado IS NULL OR p_Estado='' OR ESTADO=p_Estado);
    SELECT * FROM UNIDAD
    WHERE (p_Buscar IS NULL OR p_Buscar='' OR IDUNIDAD LIKE CONCAT('%', p_Buscar, '%') OR NOMBRE LIKE CONCAT('%', p_Buscar, '%'))
      AND (p_Estado IS NULL OR p_Estado='' OR ESTADO=p_Estado)
    ORDER BY NOMBRE
    LIMIT p_TamanioPagina OFFSET ((p_Pagina - 1) * p_TamanioPagina);
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_unidad_obtener;

DROP PROCEDURE IF EXISTS usp_unidad_obtener;

DELIMITER $$

CREATE PROCEDURE usp_unidad_obtener(
    IN p_Id VARCHAR(50)
)
main: BEGIN
SET NOCOUNT ON; SELECT * FROM UNIDAD WHERE IDUNIDAD=p_Id;
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_unidad_insertar;

DROP PROCEDURE IF EXISTS usp_unidad_insertar;

DELIMITER $$

CREATE PROCEDURE usp_unidad_insertar(
    IN p_Nombre VARCHAR(100),
    IN p_Abreviatura VARCHAR(20),
    IN p_Estado VARCHAR(50),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
DECLARE v_Id VARCHAR(50);
    IF p_Nombre IS NULL OR TRIM(p_Nombre)='' THEN SET p_Resultado=0; SET p_Mensaje='Ingresa el nombre.'; LEAVE main; END IF; THEN
      CALL usp_siguiente_id('UNI', 'UNIDAD', 'IDUNIDAD', v_Id);
    INSERT INTO UNIDAD (IDUNIDAD,NOMBRE,ABREVIATURA,ESTADO,CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
    VALUES (v_Id,p_Nombre,p_Abreviatura,IFNULL(p_Estado,'Activo'),fn_actor(),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'),fn_actor(),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'));
    SET p_Resultado=1; SET p_Mensaje='Unidad registrada.';
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_unidad_actualizar;

DROP PROCEDURE IF EXISTS usp_unidad_actualizar;

DELIMITER $$

CREATE PROCEDURE usp_unidad_actualizar(
    IN p_Id VARCHAR(50),
    IN p_Nombre VARCHAR(100),
    IN p_Abreviatura VARCHAR(20),
    IN p_Estado VARCHAR(50),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
UPDATE UNIDAD SET NOMBRE=p_Nombre, ABREVIATURA=p_Abreviatura, ESTADO=p_Estado,
        MODIFICADOPOR=fn_actor(), FECHAMODIFICACION=fn_fecha_ddmmyyyy(), HORAMODIFICACION=TIME_FORMAT(NOW(), '%H:%i:%s')
    WHERE IDUNIDAD=p_Id;
    SET p_Resultado=1; SET p_Mensaje='Unidad actualizada.';
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_unidad_eliminar;

DROP PROCEDURE IF EXISTS usp_unidad_eliminar;

DELIMITER $$

CREATE PROCEDURE usp_unidad_eliminar(
    IN p_Id VARCHAR(50),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
IF EXISTS (SELECT 1 FROM PRODUCTO WHERE IDUNIDAD=p_Id) THEN SET p_Resultado=0; SET p_Mensaje='No se puede eliminar: hay productos asociados.'; LEAVE main; END IF;
    DELETE FROM UNIDAD WHERE IDUNIDAD=p_Id; SET p_Resultado=1; SET p_Mensaje='Unidad eliminada.';
END$$

DELIMITER ;

/* CLIENTE */
DROP PROCEDURE IF EXISTS usp_cliente_listar;

DROP PROCEDURE IF EXISTS usp_cliente_listar;

DELIMITER $$

CREATE PROCEDURE usp_cliente_listar(
    IN p_Buscar VARCHAR(200),
    IN p_Estado VARCHAR(50),
    IN p_OrdenarPor VARCHAR(50),
    IN p_Direccion VARCHAR(4),
    IN p_Pagina INT,
    IN p_TamanioPagina INT,
    OUT p_TotalRegistros INT
)
main: BEGIN
SELECT COUNT(*) FROM CLIENTE INTO p_TotalRegistros
    WHERE (p_Buscar IS NULL OR p_Buscar='' OR NOMBRE LIKE CONCAT('%', p_Buscar, '%') OR IFNULL(DOCUMENTO,'') LIKE CONCAT('%', p_Buscar, '%') OR IFNULL(TELEFONO,'') LIKE CONCAT('%', p_Buscar, '%'))
      AND (p_Estado IS NULL OR p_Estado='' OR ESTADO=p_Estado);
    SELECT * FROM CLIENTE
    WHERE (p_Buscar IS NULL OR p_Buscar='' OR NOMBRE LIKE CONCAT('%', p_Buscar, '%') OR IFNULL(DOCUMENTO,'') LIKE CONCAT('%', p_Buscar, '%') OR IFNULL(TELEFONO,'') LIKE CONCAT('%', p_Buscar, '%'))
      AND (p_Estado IS NULL OR p_Estado='' OR ESTADO=p_Estado)
    ORDER BY NOMBRE
    LIMIT p_TamanioPagina OFFSET ((p_Pagina - 1) * p_TamanioPagina);
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_cliente_obtener;

DROP PROCEDURE IF EXISTS usp_cliente_obtener;

DELIMITER $$

CREATE PROCEDURE usp_cliente_obtener(
    IN p_Id VARCHAR(50)
)
main: BEGIN
SET NOCOUNT ON; SELECT * FROM CLIENTE WHERE IDCLIENTE=p_Id;
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_cliente_insertar;

DROP PROCEDURE IF EXISTS usp_cliente_insertar;

DELIMITER $$

CREATE PROCEDURE usp_cliente_insertar(
    IN p_Nombre VARCHAR(200),
    IN p_Documento VARCHAR(20),
    IN p_Telefono VARCHAR(20),
    IN p_Email VARCHAR(150),
    IN p_Direccion VARCHAR(255),
    IN p_Estado VARCHAR(50),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
DECLARE v_Id VARCHAR(50);
    IF p_Nombre IS NULL OR TRIM(p_Nombre)='' THEN SET p_Resultado=0; SET p_Mensaje='Ingresa el nombre.'; LEAVE main; END IF; THEN
      CALL usp_siguiente_id('CLI', 'CLIENTE', 'IDCLIENTE', v_Id);
    INSERT INTO CLIENTE (IDCLIENTE,NOMBRE,DOCUMENTO,TELEFONO,EMAIL,DIRECCION,ESTADO,CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
    VALUES (v_Id,p_Nombre,p_Documento,p_Telefono,p_Email,p_Direccion,IFNULL(p_Estado,'Activo'),fn_actor(),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'),fn_actor(),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'));
    SET p_Resultado=1; SET p_Mensaje='Cliente registrado.';
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_cliente_actualizar;

DROP PROCEDURE IF EXISTS usp_cliente_actualizar;

DELIMITER $$

CREATE PROCEDURE usp_cliente_actualizar(
    IN p_Id VARCHAR(50),
    IN p_Nombre VARCHAR(200),
    IN p_Documento VARCHAR(20),
    IN p_Telefono VARCHAR(20),
    IN p_Email VARCHAR(150),
    IN p_Direccion VARCHAR(255),
    IN p_Estado VARCHAR(50),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
UPDATE CLIENTE SET NOMBRE=p_Nombre, DOCUMENTO=p_Documento, TELEFONO=p_Telefono, EMAIL=p_Email, DIRECCION=p_Direccion, ESTADO=p_Estado,
        MODIFICADOPOR=fn_actor(), FECHAMODIFICACION=fn_fecha_ddmmyyyy(), HORAMODIFICACION=TIME_FORMAT(NOW(), '%H:%i:%s')
    WHERE IDCLIENTE=p_Id;
    SET p_Resultado=1; SET p_Mensaje='Cliente actualizado.';
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_cliente_eliminar;

DROP PROCEDURE IF EXISTS usp_cliente_eliminar;

DELIMITER $$

CREATE PROCEDURE usp_cliente_eliminar(
    IN p_Id VARCHAR(50),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCLIENTE=p_Id) OR EXISTS (SELECT 1 FROM VENTA WHERE IDCLIENTE=p_Id) THEN SET p_Resultado=0; SET p_Mensaje='No se puede eliminar: el cliente tiene documentos asociados.'; LEAVE main; END IF;
    DELETE FROM CLIENTE WHERE IDCLIENTE=p_Id; SET p_Resultado=1; SET p_Mensaje='Cliente eliminado.';
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_cliente_buscar;

DROP PROCEDURE IF EXISTS usp_cliente_buscar;

DELIMITER $$

CREATE PROCEDURE usp_cliente_buscar(
    IN p_Buscar VARCHAR(200)
)
main: BEGIN
DECLARE v_q VARCHAR(200);
    SET v_q = TRIM(IFNULL(p_Buscar,'')); 
    IF CHAR_LENGTH(v_q) < 3 THEN LEAVE main; END IF;
    SELECT IDCLIENTE AS value, NOMBRE AS label
    FROM CLIENTE
    WHERE ESTADO = 'Activo' AND NOMBRE LIKE CONCAT('%', v_q, '%')
    ORDER BY NOMBRE LIMIT 10;
END$$

DELIMITER ;

/* FORMA_PAGO */
DROP PROCEDURE IF EXISTS usp_formapago_listar;

DROP PROCEDURE IF EXISTS usp_formapago_listar;

DELIMITER $$

CREATE PROCEDURE usp_formapago_listar(
    IN p_Buscar VARCHAR(200),
    IN p_Estado VARCHAR(50),
    IN p_OrdenarPor VARCHAR(50),
    IN p_Direccion VARCHAR(4),
    IN p_Pagina INT,
    IN p_TamanioPagina INT,
    OUT p_TotalRegistros INT
)
main: BEGIN
SELECT COUNT(*) FROM FORMA_PAGO INTO p_TotalRegistros
    WHERE (p_Buscar IS NULL OR p_Buscar='' OR NOMBRE LIKE CONCAT('%', p_Buscar, '%')) AND (p_Estado IS NULL OR p_Estado='' OR ESTADO=p_Estado);
    SELECT * FROM FORMA_PAGO
    WHERE (p_Buscar IS NULL OR p_Buscar='' OR NOMBRE LIKE CONCAT('%', p_Buscar, '%')) AND (p_Estado IS NULL OR p_Estado='' OR ESTADO=p_Estado)
    ORDER BY NOMBRE LIMIT p_TamanioPagina OFFSET ((p_Pagina - 1) * p_TamanioPagina);
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_formapago_obtener;

DROP PROCEDURE IF EXISTS usp_formapago_obtener;

DELIMITER $$

CREATE PROCEDURE usp_formapago_obtener(
    IN p_Id VARCHAR(50)
)
main: BEGIN
SET NOCOUNT ON; SELECT * FROM FORMA_PAGO WHERE IDFORMAPAGO=p_Id;
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_formapago_insertar;

DROP PROCEDURE IF EXISTS usp_formapago_insertar;

DELIMITER $$

CREATE PROCEDURE usp_formapago_insertar(
    IN p_Nombre VARCHAR(100),
    IN p_Estado VARCHAR(50),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
DECLARE v_Id VARCHAR(50);
    CALL usp_siguiente_id('FPA', 'FORMA_PAGO', 'IDFORMAPAGO', v_Id);
    INSERT INTO FORMA_PAGO (IDFORMAPAGO,NOMBRE,ESTADO,CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
    VALUES (v_Id,p_Nombre,IFNULL(p_Estado,'Activo'),fn_actor(),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'),fn_actor(),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'));
    SET p_Resultado=1; SET p_Mensaje='Forma de pago registrada.';
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_formapago_actualizar;

DROP PROCEDURE IF EXISTS usp_formapago_actualizar;

DELIMITER $$

CREATE PROCEDURE usp_formapago_actualizar(
    IN p_Id VARCHAR(50),
    IN p_Nombre VARCHAR(100),
    IN p_Estado VARCHAR(50),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
UPDATE FORMA_PAGO SET NOMBRE=p_Nombre, ESTADO=p_Estado, MODIFICADOPOR=fn_actor(),
        FECHAMODIFICACION=fn_fecha_ddmmyyyy(), HORAMODIFICACION=TIME_FORMAT(NOW(), '%H:%i:%s')
    WHERE IDFORMAPAGO=p_Id;
    SET p_Resultado=1; SET p_Mensaje='Forma de pago actualizada.';
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_formapago_eliminar;

DROP PROCEDURE IF EXISTS usp_formapago_eliminar;

DELIMITER $$

CREATE PROCEDURE usp_formapago_eliminar(
    IN p_Id VARCHAR(50),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
IF EXISTS (SELECT 1 FROM VENTA WHERE IDFORMAPAGO=p_Id) THEN SET p_Resultado=0; SET p_Mensaje='No se puede eliminar: hay ventas asociadas.'; LEAVE main; END IF;
    DELETE FROM FORMA_PAGO WHERE IDFORMAPAGO=p_Id; SET p_Resultado=1; SET p_Mensaje='Forma de pago eliminada.';
END$$

DELIMITER ;

/* TIPO_ENTREGA */
DROP PROCEDURE IF EXISTS usp_tipoentrega_listar;

DROP PROCEDURE IF EXISTS usp_tipoentrega_listar;

DELIMITER $$

CREATE PROCEDURE usp_tipoentrega_listar(
    IN p_Buscar VARCHAR(200),
    IN p_Estado VARCHAR(50),
    IN p_OrdenarPor VARCHAR(50),
    IN p_Direccion VARCHAR(4),
    IN p_Pagina INT,
    IN p_TamanioPagina INT,
    OUT p_TotalRegistros INT
)
main: BEGIN
SELECT COUNT(*) FROM TIPO_ENTREGA INTO p_TotalRegistros
    WHERE (p_Buscar IS NULL OR p_Buscar='' OR NOMBRE LIKE CONCAT('%', p_Buscar, '%')) AND (p_Estado IS NULL OR p_Estado='' OR ESTADO=p_Estado);
    SELECT IDTIPOENTREGA, NOMBRE, REQUIEREDIRECCION,
           CASE WHEN REQUIEREDIRECCION=1 THEN 'Sí' ELSE 'No' END AS REQUIEREDIRECCION_TXT,
           ESTADO, CREADOPOR, FECHACREACION, HORACREACION, MODIFICADOPOR, FECHAMODIFICACION, HORAMODIFICACION
    FROM TIPO_ENTREGA
    WHERE (p_Buscar IS NULL OR p_Buscar='' OR NOMBRE LIKE CONCAT('%', p_Buscar, '%')) AND (p_Estado IS NULL OR p_Estado='' OR ESTADO=p_Estado)
    ORDER BY NOMBRE LIMIT p_TamanioPagina OFFSET ((p_Pagina - 1) * p_TamanioPagina);
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_tipoentrega_obtener;

DROP PROCEDURE IF EXISTS usp_tipoentrega_obtener;

DELIMITER $$

CREATE PROCEDURE usp_tipoentrega_obtener(
    IN p_Id VARCHAR(50)
)
main: BEGIN
SET NOCOUNT ON;
    SELECT IDTIPOENTREGA, NOMBRE, REQUIEREDIRECCION,
           CASE WHEN REQUIEREDIRECCION=1 THEN 'Sí' ELSE 'No' END AS REQUIEREDIRECCION_TXT, ESTADO
    FROM TIPO_ENTREGA WHERE IDTIPOENTREGA=p_Id;
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_tipoentrega_insertar;

DROP PROCEDURE IF EXISTS usp_tipoentrega_insertar;

DELIMITER $$

CREATE PROCEDURE usp_tipoentrega_insertar(
    IN p_Nombre VARCHAR(100),
    IN p_RequiereDireccion TINYINT(1),
    IN p_Estado VARCHAR(50),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
DECLARE v_Id VARCHAR(50);
    CALL usp_siguiente_id('TEN', 'TIPO_ENTREGA', 'IDTIPOENTREGA', v_Id);
    INSERT INTO TIPO_ENTREGA (IDTIPOENTREGA,NOMBRE,REQUIEREDIRECCION,ESTADO,CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
    VALUES (v_Id,p_Nombre,IFNULL(p_RequiereDireccion,0),IFNULL(p_Estado,'Activo'),fn_actor(),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'),fn_actor(),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'));
    SET p_Resultado=1; SET p_Mensaje='Tipo de entrega registrado.';
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_tipoentrega_actualizar;

DROP PROCEDURE IF EXISTS usp_tipoentrega_actualizar;

DELIMITER $$

CREATE PROCEDURE usp_tipoentrega_actualizar(
    IN p_Id VARCHAR(50),
    IN p_Nombre VARCHAR(100),
    IN p_RequiereDireccion TINYINT(1),
    IN p_Estado VARCHAR(50),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
UPDATE TIPO_ENTREGA SET NOMBRE=p_Nombre, REQUIEREDIRECCION=IFNULL(p_RequiereDireccion,0), ESTADO=p_Estado,
        MODIFICADOPOR=fn_actor(), FECHAMODIFICACION=fn_fecha_ddmmyyyy(), HORAMODIFICACION=TIME_FORMAT(NOW(), '%H:%i:%s')
    WHERE IDTIPOENTREGA=p_Id;
    SET p_Resultado=1; SET p_Mensaje='Tipo de entrega actualizado.';
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_tipoentrega_eliminar;

DROP PROCEDURE IF EXISTS usp_tipoentrega_eliminar;

DELIMITER $$

CREATE PROCEDURE usp_tipoentrega_eliminar(
    IN p_Id VARCHAR(50),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
DELETE FROM TIPO_ENTREGA WHERE IDTIPOENTREGA=p_Id; SET p_Resultado=1; SET p_Mensaje='Tipo de entrega eliminado.';
END$$

DELIMITER ;

SELECT 'SPs catálogos listos.';

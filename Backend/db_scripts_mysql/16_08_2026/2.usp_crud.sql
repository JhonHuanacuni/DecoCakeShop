-- Convertido desde db_scripts/16_08_2026/2.usp_crud.sql
-- MySQL 8 — DecoCake Shop

USE `DecoCakeShop`;

/* ============================================================================
   DECOCAKE SHOP — Stored procedures CRUD
   Ejecutar después de 1.esquema_completo.sql
   ============================================================================ */

DROP PROCEDURE IF EXISTS usp_siguiente_id;

DROP PROCEDURE IF EXISTS usp_siguiente_id;

DELIMITER $$

CREATE PROCEDURE usp_siguiente_id(
    IN p_Prefijo VARCHAR(10),
    IN p_Tabla VARCHAR(128),
    IN p_Columna VARCHAR(128),
    OUT p_Id VARCHAR(50)
)
main: BEGIN
    DECLARE v_Num INT DEFAULT 1;
    DECLARE v_Like VARCHAR(20);
    SET v_Like = CONCAT(p_Prefijo, '%');
    IF p_Tabla = 'VENTA' THEN
        SELECT IFNULL(MAX(CAST(SUBSTRING(IDVENTA, CHAR_LENGTH(p_Prefijo) + 1, 12) AS UNSIGNED)), 0) + 1
          INTO v_Num FROM VENTA WHERE IDVENTA LIKE v_Like;
    ELSEIF p_Tabla = 'CLIENTE' THEN
        SELECT IFNULL(MAX(CAST(SUBSTRING(IDCLIENTE, CHAR_LENGTH(p_Prefijo) + 1, 12) AS UNSIGNED)), 0) + 1
          INTO v_Num FROM CLIENTE WHERE IDCLIENTE LIKE v_Like;
    ELSEIF p_Tabla = 'COTIZACION' THEN
        SELECT IFNULL(MAX(CAST(SUBSTRING(IDCOTIZACION, CHAR_LENGTH(p_Prefijo) + 1, 12) AS UNSIGNED)), 0) + 1
          INTO v_Num FROM COTIZACION WHERE IDCOTIZACION LIKE v_Like;
    ELSEIF p_Tabla = 'COTIZACION_PAGO' THEN
        SELECT IFNULL(MAX(CAST(SUBSTRING(IDPAGO, CHAR_LENGTH(p_Prefijo) + 1, 12) AS UNSIGNED)), 0) + 1
          INTO v_Num FROM COTIZACION_PAGO WHERE IDPAGO LIKE v_Like;
    ELSEIF p_Tabla = 'PRODUCTO' THEN
        SELECT IFNULL(MAX(CAST(SUBSTRING(IDPRODUCTO, CHAR_LENGTH(p_Prefijo) + 1, 12) AS UNSIGNED)), 0) + 1
          INTO v_Num FROM PRODUCTO WHERE IDPRODUCTO LIKE v_Like;
    ELSEIF p_Tabla = 'CATEGORIA' THEN
        SELECT IFNULL(MAX(CAST(SUBSTRING(IDCATEGORIA, CHAR_LENGTH(p_Prefijo) + 1, 12) AS UNSIGNED)), 0) + 1
          INTO v_Num FROM CATEGORIA WHERE IDCATEGORIA LIKE v_Like;
    ELSEIF p_Tabla = 'UNIDAD' THEN
        SELECT IFNULL(MAX(CAST(SUBSTRING(IDUNIDAD, CHAR_LENGTH(p_Prefijo) + 1, 12) AS UNSIGNED)), 0) + 1
          INTO v_Num FROM UNIDAD WHERE IDUNIDAD LIKE v_Like;
    ELSEIF p_Tabla = 'FORMA_PAGO' THEN
        SELECT IFNULL(MAX(CAST(SUBSTRING(IDFORMAPAGO, CHAR_LENGTH(p_Prefijo) + 1, 12) AS UNSIGNED)), 0) + 1
          INTO v_Num FROM FORMA_PAGO WHERE IDFORMAPAGO LIKE v_Like;
    ELSEIF p_Tabla = 'TIPO_ENTREGA' THEN
        SELECT IFNULL(MAX(CAST(SUBSTRING(IDTIPOENTREGA, CHAR_LENGTH(p_Prefijo) + 1, 12) AS UNSIGNED)), 0) + 1
          INTO v_Num FROM TIPO_ENTREGA WHERE IDTIPOENTREGA LIKE v_Like;
    ELSEIF p_Tabla = 'CUPON' THEN
        SELECT IFNULL(MAX(CAST(SUBSTRING(IDCUPON, CHAR_LENGTH(p_Prefijo) + 1, 12) AS UNSIGNED)), 0) + 1
          INTO v_Num FROM CUPON WHERE IDCUPON LIKE v_Like;
    ELSEIF p_Tabla = 'USUARIO' THEN
        SELECT IFNULL(MAX(CAST(SUBSTRING(IDUSUARIO, CHAR_LENGTH(p_Prefijo) + 1, 12) AS UNSIGNED)), 0) + 1
          INTO v_Num FROM USUARIO WHERE IDUSUARIO LIKE v_Like;
    END IF;
    SET p_Id = CONCAT(p_Prefijo, RIGHT(CONCAT('000000', CAST(v_Num AS CHAR)), 6));
END$$

DELIMITER ;

/* ---------- USUARIO ---------- */
DROP PROCEDURE IF EXISTS usp_usuario_listar;

DROP PROCEDURE IF EXISTS usp_usuario_listar;

DELIMITER $$

CREATE PROCEDURE usp_usuario_listar(
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
    IF p_Pagina < 1 THEN SET p_Pagina = 1; END IF;
    IF p_TamanioPagina < 1 THEN SET p_TamanioPagina = 10; END IF;
    SELECT COUNT(*) INTO p_TotalRegistros FROM USUARIO u
    INNER JOIN TIPOUSUARIO t ON t.IDTIPOUSUARIO = u.IDTIPOUSUARIO
    WHERE (p_Buscar IS NULL OR p_Buscar = '' OR u.IDUSUARIO LIKE CONCAT('%', p_Buscar, '%') OR u.NOMBRE LIKE CONCAT('%', p_Buscar, '%')
           OR u.APELLIDO LIKE CONCAT('%', p_Buscar, '%') OR u.DNI LIKE CONCAT('%', p_Buscar, '%') OR u.EMAIL LIKE CONCAT('%', p_Buscar, '%'))
      AND (p_Estado IS NULL OR p_Estado = '' OR u.ESTADO = p_Estado);
    SET v_offset = (p_Pagina - 1) * p_TamanioPagina;
    SELECT u.IDUSUARIO, u.NOMBRE, u.APELLIDO, u.DNI, u.EMAIL, u.TELEFONO, u.DIRECCION, u.ESTADO,
           u.IDTIPOUSUARIO, t.DESCRIPCION AS TIPOUSUARIO_DESCRIPCION,
           u.CREADOPOR, u.FECHACREACION, u.HORACREACION, u.MODIFICADOPOR, u.FECHAMODIFICACION, u.HORAMODIFICACION
    FROM USUARIO u
    INNER JOIN TIPOUSUARIO t ON t.IDTIPOUSUARIO = u.IDTIPOUSUARIO
    WHERE (p_Buscar IS NULL OR p_Buscar = '' OR u.IDUSUARIO LIKE CONCAT('%', p_Buscar, '%') OR u.NOMBRE LIKE CONCAT('%', p_Buscar, '%')
           OR u.APELLIDO LIKE CONCAT('%', p_Buscar, '%') OR u.DNI LIKE CONCAT('%', p_Buscar, '%') OR u.EMAIL LIKE CONCAT('%', p_Buscar, '%'))
      AND (p_Estado IS NULL OR p_Estado = '' OR u.ESTADO = p_Estado)
    ORDER BY
        CASE WHEN p_OrdenarPor='NOMBRE' AND p_Direccion='ASC' THEN u.NOMBRE END ASC,
        CASE WHEN p_OrdenarPor='NOMBRE' AND p_Direccion='DESC' THEN u.NOMBRE END DESC,
        CASE WHEN p_OrdenarPor='APELLIDO' AND p_Direccion='ASC' THEN u.APELLIDO END ASC,
        CASE WHEN p_OrdenarPor='APELLIDO' AND p_Direccion='DESC' THEN u.APELLIDO END DESC,
        CASE WHEN p_OrdenarPor='DNI' AND p_Direccion='ASC' THEN u.DNI END ASC,
        CASE WHEN p_OrdenarPor='DNI' AND p_Direccion='DESC' THEN u.DNI END DESC,
        CASE WHEN p_OrdenarPor='ESTADO' AND p_Direccion='ASC' THEN u.ESTADO END ASC,
        CASE WHEN p_OrdenarPor='ESTADO' AND p_Direccion='DESC' THEN u.ESTADO END DESC,
        u.IDUSUARIO
    LIMIT p_TamanioPagina OFFSET v_offset;
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_usuario_obtener;

DROP PROCEDURE IF EXISTS usp_usuario_obtener;

DELIMITER $$

CREATE PROCEDURE usp_usuario_obtener(
    IN p_Id VARCHAR(50)
)
main: BEGIN
SELECT u.*, t.DESCRIPCION AS TIPOUSUARIO_DESCRIPCION
    FROM USUARIO u INNER JOIN TIPOUSUARIO t ON t.IDTIPOUSUARIO = u.IDTIPOUSUARIO
    WHERE u.IDUSUARIO = p_Id;
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_usuario_insertar;

DROP PROCEDURE IF EXISTS usp_usuario_insertar;

DELIMITER $$

CREATE PROCEDURE usp_usuario_insertar(
    IN p_Id VARCHAR(50),
    IN p_Contra VARCHAR(255),
    IN p_Nombre VARCHAR(100),
    IN p_Apellido VARCHAR(100),
    IN p_Dni VARCHAR(20),
    IN p_Email VARCHAR(150),
    IN p_Telefono VARCHAR(20),
    IN p_Direccion VARCHAR(255),
    IN p_IdTipoUsuario VARCHAR(50),
    IN p_Estado VARCHAR(50),
    IN p_Foto LONGTEXT,
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
IF EXISTS (SELECT 1 FROM USUARIO WHERE IDUSUARIO=p_Id) THEN SET p_Resultado=0; SET p_Mensaje='El usuario ya existe.'; LEAVE main; END IF;
    IF EXISTS (SELECT 1 FROM USUARIO WHERE DNI=p_Dni) THEN SET p_Resultado=0; SET p_Mensaje='El DNI ya está registrado.'; LEAVE main; END IF;
    IF EXISTS (SELECT 1 FROM USUARIO WHERE EMAIL=p_Email) THEN SET p_Resultado=0; SET p_Mensaje='El email ya está registrado.'; LEAVE main; END IF;
    INSERT INTO USUARIO (IDUSUARIO, CONTRA, NOMBRE, APELLIDO, DNI, EMAIL, TELEFONO, DIRECCION, ESTADO, FOTO, IDTIPOUSUARIO,
        CREADOPOR, FECHACREACION, HORACREACION, MODIFICADOPOR, FECHAMODIFICACION, HORAMODIFICACION)
    VALUES (p_Id, IFNULL(NULLIF(p_Contra,''), p_Dni), p_Nombre, p_Apellido, p_Dni, p_Email, p_Telefono, p_Direccion,
        IFNULL(p_Estado,'Activo'), p_Foto, p_IdTipoUsuario,
        fn_actor(), fn_fecha_ddmmyyyy(), TIME_FORMAT(NOW(), '%H:%i:%s'),
        fn_actor(), fn_fecha_ddmmyyyy(), TIME_FORMAT(NOW(), '%H:%i:%s'));
    SET p_Resultado=1; SET p_Mensaje='Usuario registrado.';
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_usuario_actualizar;

DROP PROCEDURE IF EXISTS usp_usuario_actualizar;

DELIMITER $$

CREATE PROCEDURE usp_usuario_actualizar(
    IN p_Id VARCHAR(50),
    IN p_Contra VARCHAR(255),
    IN p_Nombre VARCHAR(100),
    IN p_Apellido VARCHAR(100),
    IN p_Dni VARCHAR(20),
    IN p_Email VARCHAR(150),
    IN p_Telefono VARCHAR(20),
    IN p_Direccion VARCHAR(255),
    IN p_IdTipoUsuario VARCHAR(50),
    IN p_Estado VARCHAR(50),
    IN p_Foto LONGTEXT,
    IN p_ActualizarFoto INT,
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
IF NOT EXISTS (SELECT 1 FROM USUARIO WHERE IDUSUARIO=p_Id) THEN SET p_Resultado=0; SET p_Mensaje='El usuario no existe.'; LEAVE main; END IF;
    UPDATE USUARIO SET
        CONTRA = CASE WHEN p_Contra IS NULL OR TRIM(p_Contra)='' THEN CONTRA ELSE p_Contra END,
        NOMBRE=p_Nombre, APELLIDO=p_Apellido, DNI=p_Dni, EMAIL=p_Email, TELEFONO=p_Telefono, DIRECCION=p_Direccion,
        IDTIPOUSUARIO=p_IdTipoUsuario, ESTADO=p_Estado,
        FOTO = CASE WHEN p_ActualizarFoto=1 THEN p_Foto ELSE FOTO END,
        MODIFICADOPOR=fn_actor(), FECHAMODIFICACION=fn_fecha_ddmmyyyy(), HORAMODIFICACION=TIME_FORMAT(NOW(), '%H:%i:%s')
    WHERE IDUSUARIO=p_Id;
    SET p_Resultado=1; SET p_Mensaje='Usuario actualizado.';
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_usuario_eliminar;

DROP PROCEDURE IF EXISTS usp_usuario_eliminar;

DELIMITER $$

CREATE PROCEDURE usp_usuario_eliminar(
    IN p_Id VARCHAR(50),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
IF NOT EXISTS (SELECT 1 FROM USUARIO WHERE IDUSUARIO=p_Id) THEN SET p_Resultado=0; SET p_Mensaje='El usuario no existe.'; LEAVE main; END IF;
    IF p_Id IN ('admin','vendedor','almacen') THEN SET p_Resultado=0; SET p_Mensaje='No se puede eliminar un usuario de sistema.'; LEAVE main; END IF;
    DELETE FROM USUARIO_MODULO WHERE IDUSUARIO=p_Id;
    DELETE FROM USUARIO_MODULO_EXCLUIDO WHERE IDUSUARIO=p_Id;
    DELETE FROM USUARIO_SUBMODULO_EXCLUIDO WHERE IDUSUARIO=p_Id;
    DELETE FROM USUARIO WHERE IDUSUARIO=p_Id;
    SET p_Resultado=1; SET p_Mensaje='Usuario eliminado.';
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_usuario_resetear_contra;

DROP PROCEDURE IF EXISTS usp_usuario_resetear_contra;

DELIMITER $$

CREATE PROCEDURE usp_usuario_resetear_contra(
    IN p_Id VARCHAR(50),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
IF NOT EXISTS (SELECT 1 FROM USUARIO WHERE IDUSUARIO=p_Id) THEN SET p_Resultado=0; SET p_Mensaje='El usuario no existe.'; LEAVE main; END IF;
    UPDATE USUARIO SET CONTRA=DNI, MODIFICADOPOR=fn_actor(),
        FECHAMODIFICACION=fn_fecha_ddmmyyyy(), HORAMODIFICACION=TIME_FORMAT(NOW(), '%H:%i:%s')
    WHERE IDUSUARIO=p_Id;
    SET p_Resultado=1; SET p_Mensaje='Contraseña restablecida al DNI.';
END$$

DELIMITER ;

SELECT 'SPs usuario listos.';

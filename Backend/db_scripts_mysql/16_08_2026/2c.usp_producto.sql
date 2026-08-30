-- Convertido desde db_scripts/16_08_2026/2c.usp_producto.sql
-- MySQL 8 — DecoCake Shop

USE `DecoCakeShop`;

DROP PROCEDURE IF EXISTS usp_producto_listar;

DROP PROCEDURE IF EXISTS usp_producto_listar;

DELIMITER $$

CREATE PROCEDURE usp_producto_listar(
    IN p_Buscar VARCHAR(200),
    IN p_Estado VARCHAR(50),
    IN p_IdCategoria VARCHAR(50),
    IN p_OrdenarPor VARCHAR(50),
    IN p_Direccion VARCHAR(4),
    IN p_Pagina INT,
    IN p_TamanioPagina INT,
    OUT p_TotalRegistros INT
)
main: BEGIN
DECLARE v_offset INT DEFAULT 0;
    SELECT COUNT(*) INTO p_TotalRegistros
    FROM PRODUCTO p
    WHERE (p_Buscar IS NULL OR p_Buscar='' OR p.NOMBRE LIKE CONCAT('%', p_Buscar, '%') OR p.IDPRODUCTO LIKE CONCAT('%', p_Buscar, '%'))
      AND (p_Estado IS NULL OR p_Estado='' OR p.ESTADO=p_Estado)
      AND (p_IdCategoria IS NULL OR p_IdCategoria='' OR p.IDCATEGORIA=p_IdCategoria);
    SET v_offset = (p_Pagina - 1) * p_TamanioPagina;
    SELECT p.IDPRODUCTO, p.NOMBRE, p.DESCRIPCION, p.PRECIO, p.STOCK, p.IDCATEGORIA, c.NOMBRE AS CATEGORIA_NOMBRE,
           p.IDUNIDAD, u.NOMBRE AS UNIDAD_NOMBRE, p.ESTADO,
           CASE WHEN p.FOTO IS NULL OR CHAR_LENGTH(p.FOTO)=0 THEN 0 ELSE 1 END AS TIENE_FOTO,
           p.CREADOPOR, TRIM(CONCAT(IFNULL(cu.NOMBRE,''), ' ', IFNULL(cu.APELLIDO,''))) AS CREADOPOR_NOMBRE,
           p.FECHACREACION, p.HORACREACION,
           p.MODIFICADOPOR, TRIM(CONCAT(IFNULL(mu.NOMBRE,''), ' ', IFNULL(mu.APELLIDO,''))) AS MODIFICADOPOR_NOMBRE,
           p.FECHAMODIFICACION, p.HORAMODIFICACION
    FROM PRODUCTO p
    INNER JOIN CATEGORIA c ON c.IDCATEGORIA=p.IDCATEGORIA
    LEFT JOIN UNIDAD u ON u.IDUNIDAD=p.IDUNIDAD
    LEFT JOIN USUARIO cu ON cu.IDUSUARIO=p.CREADOPOR
    LEFT JOIN USUARIO mu ON mu.IDUSUARIO=p.MODIFICADOPOR
    WHERE (p_Buscar IS NULL OR p_Buscar='' OR p.NOMBRE LIKE CONCAT('%', p_Buscar, '%') OR p.IDPRODUCTO LIKE CONCAT('%', p_Buscar, '%'))
      AND (p_Estado IS NULL OR p_Estado='' OR p.ESTADO=p_Estado)
      AND (p_IdCategoria IS NULL OR p_IdCategoria='' OR p.IDCATEGORIA=p_IdCategoria)
    ORDER BY
        CASE WHEN p_OrdenarPor='NOMBRE' AND p_Direccion='ASC' THEN p.NOMBRE END ASC,
        CASE WHEN p_OrdenarPor='NOMBRE' AND p_Direccion='DESC' THEN p.NOMBRE END DESC,
        CASE WHEN p_OrdenarPor='PRECIO' AND p_Direccion='ASC' THEN p.PRECIO END ASC,
        CASE WHEN p_OrdenarPor='PRECIO' AND p_Direccion='DESC' THEN p.PRECIO END DESC,
        CASE WHEN p_OrdenarPor='STOCK' AND p_Direccion='ASC' THEN p.STOCK END ASC,
        CASE WHEN p_OrdenarPor='STOCK' AND p_Direccion='DESC' THEN p.STOCK END DESC,
        p.NOMBRE
    LIMIT p_TamanioPagina OFFSET v_offset;
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_producto_obtener;

DROP PROCEDURE IF EXISTS usp_producto_obtener;

DELIMITER $$

CREATE PROCEDURE usp_producto_obtener(
    IN p_Id VARCHAR(50)
)
main: BEGIN
SELECT p.*, c.NOMBRE AS CATEGORIA_NOMBRE, u.NOMBRE AS UNIDAD_NOMBRE,
           TRIM(CONCAT(IFNULL(cu.NOMBRE,''), ' ', IFNULL(cu.APELLIDO,''))) AS CREADOPOR_NOMBRE,
           TRIM(CONCAT(IFNULL(mu.NOMBRE,''), ' ', IFNULL(mu.APELLIDO,''))) AS MODIFICADOPOR_NOMBRE
    FROM PRODUCTO p
    INNER JOIN CATEGORIA c ON c.IDCATEGORIA=p.IDCATEGORIA
    LEFT JOIN UNIDAD u ON u.IDUNIDAD=p.IDUNIDAD
    LEFT JOIN USUARIO cu ON cu.IDUSUARIO=p.CREADOPOR
    LEFT JOIN USUARIO mu ON mu.IDUSUARIO=p.MODIFICADOPOR
    WHERE p.IDPRODUCTO=p_Id;
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_producto_insertar;

DROP PROCEDURE IF EXISTS usp_producto_insertar;

DELIMITER $$

CREATE PROCEDURE usp_producto_insertar(
    IN p_Nombre VARCHAR(200),
    IN p_Descripcion LONGTEXT,
    IN p_Precio DECIMAL(12,2),
    IN p_Stock DECIMAL(12,2),
    IN p_IdCategoria VARCHAR(50),
    IN p_IdUnidad VARCHAR(50),
    IN p_Estado VARCHAR(50),
    IN p_Foto LONGTEXT,
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
DECLARE v_Id VARCHAR(50);
    IF p_Nombre IS NULL OR TRIM(p_Nombre)='' THEN SET p_Resultado=0; SET p_Mensaje='Ingresa el nombre.'; LEAVE main; END IF;
    IF p_IdCategoria IS NULL OR NOT EXISTS (SELECT 1 FROM CATEGORIA WHERE IDCATEGORIA=p_IdCategoria) THEN SET p_Resultado=0; SET p_Mensaje='Selecciona una categoría.'; LEAVE main; END IF;
      CALL usp_siguiente_id('PRD', 'PRODUCTO', 'IDPRODUCTO', v_Id);
    INSERT INTO PRODUCTO (IDPRODUCTO,NOMBRE,DESCRIPCION,PRECIO,STOCK,IDCATEGORIA,IDUNIDAD,ESTADO,FOTO,
        CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
    VALUES (v_Id,p_Nombre,p_Descripcion,IFNULL(p_Precio,0),IFNULL(p_Stock,0),p_IdCategoria,NULLIF(p_IdUnidad,''),IFNULL(p_Estado,'Activo'),p_Foto,
        fn_actor(),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'),fn_actor(),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'));
    SET p_Resultado=1; SET p_Mensaje='Producto registrado.';
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_producto_actualizar;

DROP PROCEDURE IF EXISTS usp_producto_actualizar;

DELIMITER $$

CREATE PROCEDURE usp_producto_actualizar(
    IN p_Id VARCHAR(50),
    IN p_Nombre VARCHAR(200),
    IN p_Descripcion LONGTEXT,
    IN p_Precio DECIMAL(12,2),
    IN p_Stock DECIMAL(12,2),
    IN p_IdCategoria VARCHAR(50),
    IN p_IdUnidad VARCHAR(50),
    IN p_Estado VARCHAR(50),
    IN p_Foto LONGTEXT,
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
IF NOT EXISTS (SELECT 1 FROM PRODUCTO WHERE IDPRODUCTO=p_Id) THEN SET p_Resultado=0; SET p_Mensaje='El producto no existe.'; LEAVE main; END IF;
    UPDATE PRODUCTO SET NOMBRE=p_Nombre, DESCRIPCION=p_Descripcion, PRECIO=IFNULL(p_Precio,0), STOCK=IFNULL(p_Stock,0),
        IDCATEGORIA=p_IdCategoria, IDUNIDAD=NULLIF(p_IdUnidad,''), ESTADO=p_Estado, FOTO=p_Foto,
        MODIFICADOPOR=fn_actor(), FECHAMODIFICACION=fn_fecha_ddmmyyyy(), HORAMODIFICACION=TIME_FORMAT(NOW(), '%H:%i:%s')
    WHERE IDPRODUCTO=p_Id;
    SET p_Resultado=1; SET p_Mensaje='Producto actualizado.';
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_producto_eliminar;

DROP PROCEDURE IF EXISTS usp_producto_eliminar;

DELIMITER $$

CREATE PROCEDURE usp_producto_eliminar(
    IN p_Id VARCHAR(50),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
IF EXISTS (SELECT 1 FROM COTIZACION_DETALLE WHERE IDPRODUCTO=p_Id) OR EXISTS (SELECT 1 FROM VENTA_DETALLE WHERE IDPRODUCTO=p_Id) THEN SET p_Resultado=0; SET p_Mensaje='No se puede eliminar: el producto está en cotizaciones o ventas.'; LEAVE main; END IF;
    DELETE FROM PRODUCTO WHERE IDPRODUCTO=p_Id; SET p_Resultado=1; SET p_Mensaje='Producto eliminado.';
END$$

DELIMITER ;

SELECT 'SPs producto listos.';

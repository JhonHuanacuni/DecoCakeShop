-- Convertido desde db_scripts/16_08_2026/20.tienda_catalogo_paginado.sql
-- MySQL 8 — DecoCake Shop

USE `DecoCakeShop`;

/* Catálogo público paginado: el peso queda en SQL, no en la vista */

DROP PROCEDURE IF EXISTS usp_tienda_categorias;

DROP PROCEDURE IF EXISTS usp_tienda_categorias;

DELIMITER $$

CREATE PROCEDURE usp_tienda_categorias()
main: BEGIN
SELECT IDCATEGORIA AS value, NOMBRE AS label, DESCRIPCION
    FROM CATEGORIA
    WHERE ESTADO = 'Activo'
    ORDER BY ORDEN, NOMBRE;
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_tienda_productos;

DROP PROCEDURE IF EXISTS usp_tienda_productos;

DELIMITER $$

CREATE PROCEDURE usp_tienda_productos(
    IN p_Buscar VARCHAR(200),
    IN p_IdCategoria VARCHAR(50),
    IN p_Pagina INT,
    IN p_TamanioPagina INT,
    OUT p_TotalRegistros INT
)
main: BEGIN
DECLARE v_offset INT DEFAULT 0;
    DECLARE v_Q VARCHAR(200);
    DECLARE v_Cat VARCHAR(50);
    SET v_Q = TRIM(IFNULL(p_Buscar,'')); 
    SET v_Cat = NULLIF(TRIM(IFNULL(p_IdCategoria,'')),''); 
    IF p_Pagina IS NULL OR p_Pagina < 1 THEN SET p_Pagina = 1; END IF;
    IF p_TamanioPagina IS NULL OR p_TamanioPagina < 1 OR p_TamanioPagina > 24 THEN SET p_TamanioPagina = 12; END IF;
    SELECT COUNT(*) INTO p_TotalRegistros FROM PRODUCTO p
    INNER JOIN CATEGORIA c ON c.IDCATEGORIA = p.IDCATEGORIA
    WHERE p.ESTADO = 'Activo'
      AND (v_Cat IS NULL OR p.IDCATEGORIA = v_Cat)
      AND (v_Q = '' OR p.NOMBRE LIKE CONCAT('%', v_Q, '%') OR IFNULL(p.DESCRIPCION,'') LIKE CONCAT('%', v_Q, '%') OR c.NOMBRE LIKE CONCAT('%', v_Q, '%'));
    SET v_offset = (p_Pagina - 1) * p_TamanioPagina;
    SELECT p.IDPRODUCTO, p.NOMBRE, p.DESCRIPCION, p.PRECIO, p.STOCK, p.FOTO,
           p.IDCATEGORIA, c.NOMBRE AS CATEGORIA_NOMBRE
    FROM PRODUCTO p
    INNER JOIN CATEGORIA c ON c.IDCATEGORIA = p.IDCATEGORIA
    WHERE p.ESTADO = 'Activo'
      AND (v_Cat IS NULL OR p.IDCATEGORIA = v_Cat)
      AND (v_Q = '' OR p.NOMBRE LIKE CONCAT('%', v_Q, '%') OR IFNULL(p.DESCRIPCION,'') LIKE CONCAT('%', v_Q, '%') OR c.NOMBRE LIKE CONCAT('%', v_Q, '%'))
    ORDER BY c.ORDEN, p.NOMBRE
    LIMIT p_TamanioPagina OFFSET v_offset;
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_tienda_destacados;

DROP PROCEDURE IF EXISTS usp_tienda_destacados;

DELIMITER $$

CREATE PROCEDURE usp_tienda_destacados()
main: BEGIN
SELECT p.IDPRODUCTO, p.NOMBRE, p.DESCRIPCION, p.PRECIO, p.STOCK, p.FOTO,
           p.IDCATEGORIA, c.NOMBRE AS CATEGORIA_NOMBRE
    FROM PRODUCTO p
    INNER JOIN CATEGORIA c ON c.IDCATEGORIA = p.IDCATEGORIA
    WHERE p.ESTADO = 'Activo' AND p.FOTO IS NOT NULL AND CHAR_LENGTH(p.FOTO) > 0
    ORDER BY c.ORDEN, p.NOMBRE LIMIT 8;
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_tienda_favoritos;

DROP PROCEDURE IF EXISTS usp_tienda_favoritos;

DELIMITER $$

CREATE PROCEDURE usp_tienda_favoritos(
    IN p_Ids LONGTEXT
)
main: BEGIN
SELECT p.IDPRODUCTO, p.NOMBRE, p.DESCRIPCION, p.PRECIO, p.STOCK, p.FOTO,
           p.IDCATEGORIA, c.NOMBRE AS CATEGORIA_NOMBRE
    FROM PRODUCTO p
    INNER JOIN CATEGORIA c ON c.IDCATEGORIA = p.IDCATEGORIA
    AND FIND_IN_SET(p.IDPRODUCTO, p_Ids)
    WHERE p.ESTADO = 'Activo' AND TRIM(IFNULL(p_Ids,'')) <> ''
    ORDER BY p.NOMBRE;
END$$

DELIMITER ;

SELECT 'Catálogo de tienda paginado listo.';

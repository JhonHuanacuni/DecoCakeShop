-- Catálogo de la tienda: carrusel de inicio y tarjetas de promoción
-- MySQL 8 — DecoCake Shop

USE `DecoCakeShop`;

CREATE TABLE IF NOT EXISTS PROMOCION (
    IDPROMOCION         VARCHAR(50)    NOT NULL PRIMARY KEY,
    TIPO                VARCHAR(20)    NOT NULL,
    TITULO              VARCHAR(200)   NOT NULL,
    SUBTITULO           VARCHAR(120)   NULL,
    DESCRIPCION         VARCHAR(500)   NULL,
    PRECIO              DECIMAL(12,2)  NULL,
    PRECIOTEXTO         VARCHAR(80)    NULL,
    ENLACE              VARCHAR(80)    NULL,
    ESTILO              VARCHAR(20)    NULL,
    IMAGEN              LONGTEXT       NULL,
    ORDEN               INT            NOT NULL DEFAULT 0,
    ESTADO              VARCHAR(50)    NOT NULL,
    CREADOPOR           VARCHAR(50)    NULL,
    FECHACREACION       CHAR(8)        NULL,
    HORACREACION        CHAR(8)        NULL,
    MODIFICADOPOR       VARCHAR(50)    NULL,
    FECHAMODIFICACION   CHAR(8)        NULL,
    HORAMODIFICACION    CHAR(8)        NULL
);

UPDATE MODULO SET ORDEN = ORDEN + 1 WHERE ORDEN >= 8 AND NOT EXISTS (SELECT 1 FROM (SELECT IDMODULO FROM MODULO WHERE IDMODULO='MOD011') t);
INSERT INTO MODULO (IDMODULO, NOMBRE, DESCRIPCION, ICONO, ORDEN, ACTIVO)
SELECT 'MOD011', 'Catálogo', 'Carrusel y promociones de la tienda', 'faStore', 8, 1 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM MODULO WHERE IDMODULO='MOD011');
UPDATE MODULO
    SET NOMBRE = 'Catálogo', DESCRIPCION = 'Carrusel y promociones de la tienda', ICONO = 'faStore', ACTIVO = 1
    WHERE IDMODULO = 'MOD011';

INSERT INTO SUBMODULO (IDSUBMODULO, IDMODULO, NOMBRE, ICONO, ORDEN, ACTIVO)
SELECT 'SUB006', 'MOD011', 'Carrusel', 'faImages', 1, 1 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM SUBMODULO WHERE IDSUBMODULO='SUB006');
INSERT INTO SUBMODULO (IDSUBMODULO, IDMODULO, NOMBRE, ICONO, ORDEN, ACTIVO)
SELECT 'SUB007', 'MOD011', 'Promociones', 'faBullhorn', 2, 1 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM SUBMODULO WHERE IDSUBMODULO='SUB007');
UPDATE SUBMODULO SET NOMBRE = 'Carrusel', ICONO = 'faImages', IDMODULO = 'MOD011', ORDEN = 1, ACTIVO = 1 WHERE IDSUBMODULO = 'SUB006';
UPDATE SUBMODULO SET NOMBRE = 'Promociones', ICONO = 'faBullhorn', IDMODULO = 'MOD011', ORDEN = 2, ACTIVO = 1 WHERE IDSUBMODULO = 'SUB007';

INSERT INTO GRUPO_MODULO (IDGRUPOMODULO, IDTIPOUSUARIO, IDMODULO, IDTIPOPERMISO)
SELECT CONCAT('GRM3MOD011', p.IDTIPOPERMISO), '3', 'MOD011', p.IDTIPOPERMISO
FROM TIPO_PERMISO p
WHERE NOT EXISTS (
    SELECT 1 FROM GRUPO_MODULO g
    WHERE g.IDTIPOUSUARIO = '3' AND g.IDMODULO = 'MOD011' AND g.IDTIPOPERMISO = p.IDTIPOPERMISO
);
INSERT INTO GRUPO_MODULO (IDGRUPOMODULO, IDTIPOUSUARIO, IDMODULO, IDTIPOPERMISO)
SELECT CONCAT('GRM1MOD011', p.IDTIPOPERMISO), '1', 'MOD011', p.IDTIPOPERMISO
FROM TIPO_PERMISO p
WHERE NOT EXISTS (
    SELECT 1 FROM GRUPO_MODULO g
    WHERE g.IDTIPOUSUARIO = '1' AND g.IDMODULO = 'MOD011' AND g.IDTIPOPERMISO = p.IDTIPOPERMISO
);

DROP PROCEDURE IF EXISTS usp_promocion_listar;

DROP PROCEDURE IF EXISTS usp_promocion_listar;

DELIMITER $$

CREATE PROCEDURE usp_promocion_listar(
    IN p_Buscar VARCHAR(200),
    IN p_Estado VARCHAR(50),
    IN p_Tipo VARCHAR(20),
    IN p_OrdenarPor VARCHAR(50),
    IN p_Direccion VARCHAR(4),
    IN p_Pagina INT,
    IN p_TamanioPagina INT,
    OUT p_TotalRegistros INT
)
main: BEGIN
DECLARE v_offset INT DEFAULT 0;
    IF p_Pagina<1 THEN SET p_Pagina=1; END IF; IF p_TamanioPagina<1 THEN SET p_TamanioPagina=10; END IF;
    SELECT COUNT(*) INTO p_TotalRegistros FROM PROMOCION p
    WHERE (p_Buscar IS NULL OR p_Buscar='' OR p.IDPROMOCION LIKE CONCAT('%', p_Buscar, '%') OR p.TITULO LIKE CONCAT('%', p_Buscar, '%') OR IFNULL(p.DESCRIPCION,'') LIKE CONCAT('%', p_Buscar, '%'))
      AND (p_Estado IS NULL OR p_Estado='' OR p.ESTADO=p_Estado)
      AND (p_Tipo IS NULL OR p_Tipo='' OR p.TIPO=p_Tipo);
    SET v_offset = (p_Pagina - 1) * p_TamanioPagina;
    SELECT p.*
    FROM PROMOCION p
    WHERE (p_Buscar IS NULL OR p_Buscar='' OR p.IDPROMOCION LIKE CONCAT('%', p_Buscar, '%') OR p.TITULO LIKE CONCAT('%', p_Buscar, '%') OR IFNULL(p.DESCRIPCION,'') LIKE CONCAT('%', p_Buscar, '%'))
      AND (p_Estado IS NULL OR p_Estado='' OR p.ESTADO=p_Estado)
      AND (p_Tipo IS NULL OR p_Tipo='' OR p.TIPO=p_Tipo)
    ORDER BY
        CASE WHEN p_OrdenarPor='TITULO' AND p_Direccion='ASC' THEN p.TITULO END ASC,
        CASE WHEN p_OrdenarPor='TITULO' AND p_Direccion='DESC' THEN p.TITULO END DESC,
        CASE WHEN p_OrdenarPor='ORDEN' AND p_Direccion='ASC' THEN p.ORDEN END ASC,
        CASE WHEN p_OrdenarPor='ORDEN' AND p_Direccion='DESC' THEN p.ORDEN END DESC,
        CASE WHEN p_OrdenarPor='ESTADO' AND p_Direccion='ASC' THEN p.ESTADO END ASC,
        CASE WHEN p_OrdenarPor='ESTADO' AND p_Direccion='DESC' THEN p.ESTADO END DESC,
        p.ORDEN, p.TITULO
    LIMIT p_TamanioPagina OFFSET v_offset;
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_promocion_obtener;

DROP PROCEDURE IF EXISTS usp_promocion_obtener;

DELIMITER $$

CREATE PROCEDURE usp_promocion_obtener(
    IN p_Id VARCHAR(50)
)
main: BEGIN
SELECT * FROM PROMOCION WHERE IDPROMOCION=p_Id;
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_promocion_publicas;

DROP PROCEDURE IF EXISTS usp_promocion_publicas;

DELIMITER $$

CREATE PROCEDURE usp_promocion_publicas()
main: BEGIN
SELECT IDPROMOCION, TIPO, TITULO, SUBTITULO, DESCRIPCION, PRECIO, PRECIOTEXTO, ENLACE, ESTILO, IMAGEN, ORDEN
    FROM PROMOCION
    WHERE ESTADO='Activo'
    ORDER BY TIPO, ORDEN, TITULO;
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_promocion_insertar;

DROP PROCEDURE IF EXISTS usp_promocion_insertar;

DELIMITER $$

CREATE PROCEDURE usp_promocion_insertar(
    IN p_Tipo VARCHAR(20),
    IN p_Titulo VARCHAR(200),
    IN p_Subtitulo VARCHAR(120),
    IN p_Descripcion VARCHAR(500),
    IN p_Precio DECIMAL(12,2),
    IN p_PrecioTexto VARCHAR(80),
    IN p_Enlace VARCHAR(80),
    IN p_Estilo VARCHAR(20),
    IN p_Imagen LONGTEXT,
    IN p_Orden INT,
    IN p_Estado VARCHAR(50),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
DECLARE v_Id VARCHAR(50);
    DECLARE v_Num INT DEFAULT 1;
    SET p_Titulo = TRIM(IFNULL(p_Titulo,''));
    IF p_Titulo='' THEN SET p_Resultado=0; SET p_Mensaje='Ingresa el título.'; LEAVE main; END IF;
    IF IFNULL(p_Imagen,'')='' THEN SET p_Resultado=0; SET p_Mensaje='Agrega una imagen.'; LEAVE main; END IF;
    IF p_Tipo NOT IN ('slider','card') THEN SET p_Tipo='slider'; END IF;
    SELECT IFNULL(MAX(CAST(SUBSTRING(IDPROMOCION, 4, 12) AS UNSIGNED)), 0) + 1 INTO v_Num FROM PROMOCION WHERE IDPROMOCION LIKE 'PRM%';
    SET v_Id = CONCAT('PRM', LPAD(v_Num, 6, '0'));
    INSERT INTO PROMOCION (IDPROMOCION,TIPO,TITULO,SUBTITULO,DESCRIPCION,PRECIO,PRECIOTEXTO,ENLACE,ESTILO,IMAGEN,ORDEN,ESTADO,CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
    VALUES (v_Id,p_Tipo,p_Titulo,NULLIF(p_Subtitulo,''),NULLIF(p_Descripcion,''),p_Precio,NULLIF(p_PrecioTexto,''),NULLIF(p_Enlace,''),NULLIF(p_Estilo,''),p_Imagen,IFNULL(p_Orden,0),IFNULL(p_Estado,'Activo'),fn_actor(),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'),fn_actor(),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'));
    SET p_Resultado=1; SET p_Mensaje='Promoción registrada.';
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_promocion_actualizar;

DROP PROCEDURE IF EXISTS usp_promocion_actualizar;

DELIMITER $$

CREATE PROCEDURE usp_promocion_actualizar(
    IN p_Id VARCHAR(50),
    IN p_Tipo VARCHAR(20),
    IN p_Titulo VARCHAR(200),
    IN p_Subtitulo VARCHAR(120),
    IN p_Descripcion VARCHAR(500),
    IN p_Precio DECIMAL(12,2),
    IN p_PrecioTexto VARCHAR(80),
    IN p_Enlace VARCHAR(80),
    IN p_Estilo VARCHAR(20),
    IN p_Imagen LONGTEXT,
    IN p_Orden INT,
    IN p_Estado VARCHAR(50),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
IF NOT EXISTS (SELECT 1 FROM PROMOCION WHERE IDPROMOCION=p_Id) THEN SET p_Resultado=0; SET p_Mensaje='La promoción no existe.'; LEAVE main; END IF;
    SET p_Titulo = TRIM(IFNULL(p_Titulo,''));
    IF p_Titulo='' THEN SET p_Resultado=0; SET p_Mensaje='Ingresa el título.'; LEAVE main; END IF;
    IF IFNULL(p_Imagen,'')='' THEN SET p_Resultado=0; SET p_Mensaje='Agrega una imagen.'; LEAVE main; END IF;
    IF p_Tipo NOT IN ('slider','card') THEN SET p_Tipo='slider'; END IF;
    UPDATE PROMOCION SET TIPO=p_Tipo, TITULO=p_Titulo, SUBTITULO=NULLIF(p_Subtitulo,''), DESCRIPCION=NULLIF(p_Descripcion,''),
        PRECIO=p_Precio, PRECIOTEXTO=NULLIF(p_PrecioTexto,''), ENLACE=NULLIF(p_Enlace,''), ESTILO=NULLIF(p_Estilo,''),
        IMAGEN=p_Imagen, ORDEN=IFNULL(p_Orden,0), ESTADO=IFNULL(p_Estado,'Activo'),
        MODIFICADOPOR=fn_actor(), FECHAMODIFICACION=fn_fecha_ddmmyyyy(), HORAMODIFICACION=TIME_FORMAT(NOW(), '%H:%i:%s')
    WHERE IDPROMOCION=p_Id;
    SET p_Resultado=1; SET p_Mensaje='Promoción actualizada.';
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_promocion_eliminar;

DROP PROCEDURE IF EXISTS usp_promocion_eliminar;

DELIMITER $$

CREATE PROCEDURE usp_promocion_eliminar(
    IN p_Id VARCHAR(50),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
IF NOT EXISTS (SELECT 1 FROM PROMOCION WHERE IDPROMOCION=p_Id) THEN SET p_Resultado=0; SET p_Mensaje='La promoción no existe.'; LEAVE main; END IF;
    DELETE FROM PROMOCION WHERE IDPROMOCION=p_Id;
    SET p_Resultado=1; SET p_Mensaje='Promoción eliminada.';
END$$

DELIMITER ;

INSERT INTO PROMOCION (IDPROMOCION,TIPO,TITULO,SUBTITULO,DESCRIPCION,PRECIO,PRECIOTEXTO,ENLACE,ESTILO,IMAGEN,ORDEN,ESTADO,CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
SELECT 'PRM000001','slider','Set de bowls metálicos anidables',NULL,NULL,NULL,NULL,NULL,NULL,'/shop-products/05-bols-de-acero-x7und.png',1,'Activo','sistema',fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'),'sistema',fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s') FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM PROMOCION WHERE IDPROMOCION='PRM000001');
INSERT INTO PROMOCION (IDPROMOCION,TIPO,TITULO,SUBTITULO,DESCRIPCION,PRECIO,PRECIOTEXTO,ENLACE,ESTILO,IMAGEN,ORDEN,ESTADO,CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
SELECT 'PRM000002','slider','Fondant y pastas de modelar',NULL,NULL,NULL,NULL,NULL,NULL,'/shop-products/04-taper-bombonera.png',2,'Activo','sistema',fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'),'sistema',fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s') FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM PROMOCION WHERE IDPROMOCION='PRM000002');
INSERT INTO PROMOCION (IDPROMOCION,TIPO,TITULO,SUBTITULO,DESCRIPCION,PRECIO,PRECIOTEXTO,ENLACE,ESTILO,IMAGEN,ORDEN,ESTADO,CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
SELECT 'PRM000003','slider','Colorantes y cortadores',NULL,NULL,NULL,NULL,NULL,NULL,'/shop-products/03-sorbetones.png',3,'Activo','sistema',fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'),'sistema',fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s') FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM PROMOCION WHERE IDPROMOCION='PRM000003');
INSERT INTO PROMOCION (IDPROMOCION,TIPO,TITULO,SUBTITULO,DESCRIPCION,PRECIO,PRECIOTEXTO,ENLACE,ESTILO,IMAGEN,ORDEN,ESTADO,CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
SELECT 'PRM000004','card','Set de bowls metálicos','Combo del mes','7 piezas anidables, de 18 a 30 cm, para batir y guardar con orden.',58.00,NULL,'CAT004','rosa','/shop-products/05-bols-de-acero-x7und.png',1,'Activo','sistema',fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'),'sistema',fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s') FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM PROMOCION WHERE IDPROMOCION='PRM000004');
INSERT INTO PROMOCION (IDPROMOCION,TIPO,TITULO,SUBTITULO,DESCRIPCION,PRECIO,PRECIOTEXTO,ENLACE,ESTILO,IMAGEN,ORDEN,ESTADO,CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
SELECT 'PRM000005','card','Kekeras y moldes','Hornea más','Sets listos para tortas, kekes y celebraciones de todo tamaño.',14.00,'Desde','CAT003','teal','/shop-products/12-kekera-rectangular-x5-und.jpeg',2,'Activo','sistema',fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'),'sistema',fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s') FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM PROMOCION WHERE IDPROMOCION='PRM000005');

SELECT 'Módulo Catálogo / Promociones listo.';

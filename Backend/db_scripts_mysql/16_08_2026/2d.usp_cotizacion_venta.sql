-- Convertido desde db_scripts/16_08_2026/2d.usp_cotizacion_venta.sql
-- MySQL 8 — DecoCake Shop

USE `DecoCakeShop`;

DROP PROCEDURE IF EXISTS usp_cotizacion_listar;

DROP PROCEDURE IF EXISTS usp_cotizacion_listar;

DELIMITER $$

CREATE PROCEDURE usp_cotizacion_listar(
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
    SELECT COUNT(*) INTO p_TotalRegistros FROM COTIZACION q
    LEFT JOIN CLIENTE c ON c.IDCLIENTE=q.IDCLIENTE
    WHERE (p_Buscar IS NULL OR p_Buscar='' OR q.IDCOTIZACION LIKE CONCAT('%', p_Buscar, '%')
           OR IFNULL(c.NOMBRE,q.NOMBRECLIENTE) LIKE CONCAT('%', p_Buscar, '%'))
      AND (p_Estado IS NULL OR p_Estado='' OR q.ESTADO=p_Estado);
    SET v_offset = (p_Pagina - 1) * p_TamanioPagina;
    SELECT q.IDCOTIZACION, q.IDCLIENTE, IFNULL(c.NOMBRE, q.NOMBRECLIENTE) AS CLIENTE_NOMBRE, q.NOMBRECLIENTE,
           q.IDTIPOENTREGA, t.NOMBRE AS TIPOENTREGA_NOMBRE,
           q.DIRECCIONENTREGA, q.COSTODELIVERY, q.SUBTOTAL, q.TOTAL, q.ESTADO, q.IDVENTA,
           q.FECHACREACION AS FECHA, q.HORACREACION AS HORA,
           q.CREADOPOR, TRIM(CONCAT(IFNULL(cu.NOMBRE,''), ' ', IFNULL(cu.APELLIDO,''))) AS CREADOPOR_NOMBRE,
           q.MODIFICADOPOR, q.FECHAMODIFICACION, q.HORAMODIFICACION
    FROM COTIZACION q
    LEFT JOIN CLIENTE c ON c.IDCLIENTE=q.IDCLIENTE
    LEFT JOIN TIPO_ENTREGA t ON t.IDTIPOENTREGA=q.IDTIPOENTREGA
    LEFT JOIN USUARIO cu ON cu.IDUSUARIO=q.CREADOPOR
    WHERE (p_Buscar IS NULL OR p_Buscar='' OR q.IDCOTIZACION LIKE CONCAT('%', p_Buscar, '%')
           OR IFNULL(c.NOMBRE,q.NOMBRECLIENTE) LIKE CONCAT('%', p_Buscar, '%'))
      AND (p_Estado IS NULL OR p_Estado='' OR q.ESTADO=p_Estado)
    ORDER BY q.FECHACREACION DESC, q.HORACREACION DESC, q.IDCOTIZACION DESC
    LIMIT p_TamanioPagina OFFSET v_offset;
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_cotizacion_obtener;

DROP PROCEDURE IF EXISTS usp_cotizacion_obtener;

DELIMITER $$

CREATE PROCEDURE usp_cotizacion_obtener(
    IN p_Id VARCHAR(50)
)
main: BEGIN
SELECT q.*, IFNULL(c.NOMBRE, q.NOMBRECLIENTE) AS CLIENTE_NOMBRE, t.NOMBRE AS TIPOENTREGA_NOMBRE, t.REQUIEREDIRECCION,
           q.FECHACREACION AS FECHA, q.HORACREACION AS HORA
    FROM COTIZACION q
    LEFT JOIN CLIENTE c ON c.IDCLIENTE=q.IDCLIENTE
    LEFT JOIN TIPO_ENTREGA t ON t.IDTIPOENTREGA=q.IDTIPOENTREGA
    WHERE q.IDCOTIZACION=p_Id;
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_cotizacion_detalle_listar;

DROP PROCEDURE IF EXISTS usp_cotizacion_detalle_listar;

DELIMITER $$

CREATE PROCEDURE usp_cotizacion_detalle_listar(
    IN p_Id VARCHAR(50)
)
main: BEGIN
SELECT d.IDDETALLE, d.IDPRODUCTO, p.NOMBRE AS PRODUCTO_NOMBRE, d.CANTIDAD, d.PRECIOUNITARIO, d.SUBTOTAL, p.STOCK
    FROM COTIZACION_DETALLE d INNER JOIN PRODUCTO p ON p.IDPRODUCTO=d.IDPRODUCTO
    WHERE d.IDCOTIZACION=p_Id;
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_cotizacion_guardar_detalle;

DROP PROCEDURE IF EXISTS usp_cotizacion_guardar_detalle;

DELIMITER $$

CREATE PROCEDURE usp_cotizacion_guardar_detalle(
    IN p_Id VARCHAR(50),
    IN p_DetalleJson LONGTEXT
)
main: BEGIN
DECLARE v_n INT;
    DECLARE v_Sub DECIMAL(12,2);
    DELETE FROM COTIZACION_DETALLE WHERE IDCOTIZACION=p_Id;
    SET v_n = 0; 
    INSERT INTO COTIZACION_DETALLE (IDDETALLE, IDCOTIZACION, IDPRODUCTO, CANTIDAD, PRECIOUNITARIO, SUBTOTAL)
    SELECT CONCAT(p_Id, RIGHT(CONCAT('000', CAST(ROW_NUMBER() OVER (ORDER BY j.IDPRODUCTO) AS CHAR)), 3)),
           p_Id, j.IDPRODUCTO, j.CANTIDAD, j.PRECIOUNITARIO, j.CANTIDAD * j.PRECIOUNITARIO
    FROM JSON_TABLE(IFNULL(p_DetalleJson, '[]'), '$[*]' COLUMNS (
            IDPRODUCTO VARCHAR(50) PATH '$.IDPRODUCTO',
            CANTIDAD DECIMAL(12,2) PATH '$.CANTIDAD',
            PRECIOUNITARIO DECIMAL(12,2) PATH '$.PRECIOUNITARIO'
        )) AS j
    WHERE j.IDPRODUCTO IS NOT NULL AND j.CANTIDAD > 0;
    SET v_Sub = IFNULL((SELECT SUM(SUBTOTAL) FROM COTIZACION_DETALLE WHERE IDCOTIZACION=p_Id),0); 
    UPDATE COTIZACION SET SUBTOTAL=v_Sub, TOTAL=v_Sub + IFNULL(COSTODELIVERY,0) WHERE IDCOTIZACION=p_Id;
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_cotizacion_insertar;

DROP PROCEDURE IF EXISTS usp_cotizacion_insertar;

DELIMITER $$

CREATE PROCEDURE usp_cotizacion_insertar(
    IN p_IdCliente VARCHAR(50),
    IN p_NombreCliente VARCHAR(200),
    IN p_IdTipoEntrega VARCHAR(50),
    IN p_DireccionEntrega VARCHAR(255),
    IN p_CostoDelivery DECIMAL(12,2),
    IN p_Observaciones LONGTEXT,
    IN p_Estado VARCHAR(50),
    IN p_DetalleJson LONGTEXT,
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
DECLARE v_IdCli VARCHAR(50);
    DECLARE v_Nom VARCHAR(200);
    DECLARE v_Id VARCHAR(50);
    SET v_IdCli = NULLIF(TRIM(IFNULL(p_IdCliente,'')), ''); 
    SET v_Nom = NULLIF(TRIM(IFNULL(p_NombreCliente,'')), ''); 
    IF v_IdCli IS NOT NULL AND EXISTS (SELECT 1 FROM CLIENTE WHERE IDCLIENTE=v_IdCli) THEN
        SELECT IFNULL(v_Nom, NOMBRE) INTO v_Nom FROM CLIENTE WHERE IDCLIENTE=v_IdCli;
    ELSE
        SET v_IdCli = NULL;
    END IF;
    IF v_Nom IS NULL THEN SET p_Resultado=0; SET p_Mensaje='Ingresa el cliente.'; LEAVE main; END IF;
      CALL usp_siguiente_id('COT', 'COTIZACION', 'IDCOTIZACION', v_Id);
    INSERT INTO COTIZACION (IDCOTIZACION,IDCLIENTE,NOMBRECLIENTE,IDTIPOENTREGA,DIRECCIONENTREGA,COSTODELIVERY,SUBTOTAL,TOTAL,OBSERVACIONES,ESTADO,
        CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
    VALUES (v_Id,v_IdCli,v_Nom,p_IdTipoEntrega,p_DireccionEntrega,IFNULL(p_CostoDelivery,0),0,0,p_Observaciones,IFNULL(p_Estado,'Cotizado'),
        fn_actor(),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'),fn_actor(),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'));
    IF p_DetalleJson IS NOT NULL AND CHAR_LENGTH(p_DetalleJson)>2 THEN
        CALL usp_cotizacion_guardar_detalle(v_Id, p_DetalleJson); END IF;
    SET p_Resultado=1; SET p_Mensaje='Cotización registrada.';
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_cotizacion_actualizar;

DROP PROCEDURE IF EXISTS usp_cotizacion_actualizar;

DELIMITER $$

CREATE PROCEDURE usp_cotizacion_actualizar(
    IN p_Id VARCHAR(50),
    IN p_IdCliente VARCHAR(50),
    IN p_NombreCliente VARCHAR(200),
    IN p_IdTipoEntrega VARCHAR(50),
    IN p_DireccionEntrega VARCHAR(255),
    IN p_CostoDelivery DECIMAL(12,2),
    IN p_Observaciones LONGTEXT,
    IN p_Estado VARCHAR(50),
    IN p_DetalleJson LONGTEXT,
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
DECLARE v_IdCli VARCHAR(50);
    DECLARE v_Nom VARCHAR(200);
    IF NOT EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=p_Id) THEN SET p_Resultado=0; SET p_Mensaje='La cotización no existe.'; LEAVE main; END IF;
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=p_Id AND ESTADO IN ('Convertida','Anulada')) THEN SET p_Resultado=0; SET p_Mensaje='No se puede editar una cotización convertida o anulada.'; LEAVE main; END IF;
    SET v_IdCli = NULLIF(TRIM(IFNULL(p_IdCliente,'')), ''); 
    SET v_Nom = NULLIF(TRIM(IFNULL(p_NombreCliente,'')), ''); 
    IF v_IdCli IS NOT NULL AND EXISTS (SELECT 1 FROM CLIENTE WHERE IDCLIENTE=v_IdCli) THEN
        SELECT IFNULL(v_Nom, NOMBRE) INTO v_Nom FROM CLIENTE WHERE IDCLIENTE=v_IdCli;
    ELSE
        SET v_IdCli = NULL;
    END IF;
    IF v_Nom IS NULL THEN SET p_Resultado=0; SET p_Mensaje='Ingresa el cliente.'; LEAVE main; END IF;
    UPDATE COTIZACION SET IDCLIENTE=v_IdCli, NOMBRECLIENTE=v_Nom, IDTIPOENTREGA=p_IdTipoEntrega, DIRECCIONENTREGA=p_DireccionEntrega,
        COSTODELIVERY=IFNULL(p_CostoDelivery,0), OBSERVACIONES=p_Observaciones, ESTADO=p_Estado,
        MODIFICADOPOR=fn_actor(), FECHAMODIFICACION=fn_fecha_ddmmyyyy(), HORAMODIFICACION=TIME_FORMAT(NOW(), '%H:%i:%s')
    WHERE IDCOTIZACION=p_Id;
    IF p_DetalleJson IS NOT NULL THEN
        CALL usp_cotizacion_guardar_detalle(p_Id, p_DetalleJson); END IF;
    SET p_Resultado=1; SET p_Mensaje='Cotización actualizada.';
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_cotizacion_eliminar;

DROP PROCEDURE IF EXISTS usp_cotizacion_eliminar;

DELIMITER $$

CREATE PROCEDURE usp_cotizacion_eliminar(
    IN p_Id VARCHAR(50),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=p_Id AND ESTADO='Convertida') THEN SET p_Resultado=0; SET p_Mensaje='No se puede eliminar: ya fue convertida a venta.'; LEAVE main; END IF;
    DELETE FROM COTIZACION_DETALLE WHERE IDCOTIZACION=p_Id;
    DELETE FROM COTIZACION WHERE IDCOTIZACION=p_Id;
    SET p_Resultado=1; SET p_Mensaje='Cotización eliminada.';
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_cotizacion_hacer_pedido;

DROP PROCEDURE IF EXISTS usp_cotizacion_hacer_pedido;

DELIMITER $$

CREATE PROCEDURE usp_cotizacion_hacer_pedido(
    IN p_Id VARCHAR(50),
    IN p_IdFormaPago VARCHAR(50),
    IN p_IdTipoEntrega VARCHAR(50),
    IN p_DireccionEntrega VARCHAR(255),
    IN p_CostoDelivery DECIMAL(12,2),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
DECLARE v_Tipo VARCHAR(50);
    DECLARE v_IdVenta VARCHAR(50);
    DECLARE v_Sub DECIMAL(12,2);
    DECLARE v_Cli VARCHAR(50);
    DECLARE v_Nom VARCHAR(200);
    DECLARE v_Obs LONGTEXT;
    IF NOT EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=p_Id) THEN SET p_Resultado=0; SET p_Mensaje='La cotización no existe.'; LEAVE main; END IF;
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=p_Id AND ESTADO IN ('Convertida','Anulada')) THEN SET p_Resultado=0; SET p_Mensaje='La cotización ya fue convertida o está anulada.'; LEAVE main; END IF;
    IF NOT EXISTS (SELECT 1 FROM COTIZACION_DETALLE WHERE IDCOTIZACION=p_Id) THEN SET p_Resultado=0; SET p_Mensaje='La cotización no tiene productos.'; LEAVE main; END IF;
    SET v_Tipo = NULLIF(TRIM(IFNULL(p_IdTipoEntrega,'')), ''); 
    IF v_Tipo IS NULL OR NOT EXISTS (SELECT 1 FROM TIPO_ENTREGA WHERE IDTIPOENTREGA=v_Tipo AND ESTADO='Activo') THEN SET p_Resultado=0; SET p_Mensaje='Selecciona el tipo de entrega.'; LEAVE main; END IF;
    IF EXISTS (SELECT 1 FROM TIPO_ENTREGA WHERE IDTIPOENTREGA=v_Tipo AND REQUIEREDIRECCION=1)
       AND NULLIF(TRIM(IFNULL(p_DireccionEntrega,'')),'') IS NULL
    THEN SET p_Resultado=0; SET p_Mensaje='Ingresa la dirección de delivery.'; LEAVE main; END IF;
    IF EXISTS (
        SELECT 1 FROM COTIZACION_DETALLE d INNER JOIN PRODUCTO p ON p.IDPRODUCTO=d.IDPRODUCTO
        WHERE d.IDCOTIZACION=p_Id AND p.STOCK < d.CANTIDAD
    )
    THEN SET p_Resultado=0; SET p_Mensaje='Stock insuficiente para uno o más productos.'; LEAVE main; END IF;
      CALL usp_siguiente_id('VEN', 'VENTA', 'IDVENTA', v_IdVenta);
        
    SELECT SUBTOTAL, IDCLIENTE, NOMBRECLIENTE, OBSERVACIONES INTO v_Sub, v_Cli, v_Nom, v_Obs FROM COTIZACION WHERE IDCOTIZACION=p_Id;
    INSERT INTO VENTA (IDVENTA,IDCOTIZACION,IDCLIENTE,NOMBRECLIENTE,IDFORMAPAGO,IDTIPOENTREGA,DIRECCIONENTREGA,COSTODELIVERY,SUBTOTAL,TOTAL,OBSERVACIONES,ESTADO,
        CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
    VALUES (
        v_IdVenta, p_Id, v_Cli, v_Nom, NULLIF(TRIM(IFNULL(p_IdFormaPago,'')), ''), v_Tipo, p_DireccionEntrega,
        IFNULL(p_CostoDelivery,0), v_Sub, v_Sub + IFNULL(p_CostoDelivery,0), v_Obs, 'Pagado',
        fn_actor(), fn_fecha_ddmmyyyy(), TIME_FORMAT(NOW(), '%H:%i:%s'),
        fn_actor(), fn_fecha_ddmmyyyy(), TIME_FORMAT(NOW(), '%H:%i:%s')
    );
    INSERT INTO VENTA_DETALLE (IDDETALLE, IDVENTA, IDPRODUCTO, CANTIDAD, PRECIOUNITARIO, SUBTOTAL)
    SELECT CONCAT(v_IdVenta, RIGHT(CONCAT('000', CAST(ROW_NUMBER() OVER (ORDER BY IDDETALLE) AS CHAR)), 3)),
           v_IdVenta, IDPRODUCTO, CANTIDAD, PRECIOUNITARIO, SUBTOTAL
    FROM COTIZACION_DETALLE WHERE IDCOTIZACION=p_Id;
    UPDATE PRODUCTO p INNER JOIN COTIZACION_DETALLE d ON d.IDPRODUCTO=p.IDPRODUCTO SET p.STOCK = p.STOCK - d.CANTIDAD,
        p.MODIFICADOPOR=fn_actor(), p.FECHAMODIFICACION=fn_fecha_ddmmyyyy(), p.HORAMODIFICACION=TIME_FORMAT(NOW(), '%H:%i:%s') WHERE d.IDCOTIZACION=p_Id;
    UPDATE COTIZACION SET ESTADO='Convertida', IDVENTA=v_IdVenta,
        IDTIPOENTREGA=v_Tipo, DIRECCIONENTREGA=p_DireccionEntrega, COSTODELIVERY=IFNULL(p_CostoDelivery,0),
        TOTAL=v_Sub + IFNULL(p_CostoDelivery,0),
        MODIFICADOPOR=fn_actor(), FECHAMODIFICACION=fn_fecha_ddmmyyyy(), HORAMODIFICACION=TIME_FORMAT(NOW(), '%H:%i:%s')
    WHERE IDCOTIZACION=p_Id;
    SET p_Resultado=1; SET p_Mensaje=CONCAT('Pedido generado. ', v_IdVenta, '.');
END$$

DELIMITER ;

/* VENTAS */
DROP PROCEDURE IF EXISTS usp_venta_listar;

DROP PROCEDURE IF EXISTS usp_venta_listar;

DELIMITER $$

CREATE PROCEDURE usp_venta_listar(
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
    SELECT COUNT(*) INTO p_TotalRegistros FROM VENTA v LEFT JOIN CLIENTE c ON c.IDCLIENTE=v.IDCLIENTE
    WHERE (p_Buscar IS NULL OR p_Buscar='' OR v.IDVENTA LIKE CONCAT('%', p_Buscar, '%') OR IFNULL(c.NOMBRE,v.NOMBRECLIENTE) LIKE CONCAT('%', p_Buscar, '%') OR IFNULL(v.IDCOTIZACION,'') LIKE CONCAT('%', p_Buscar, '%'))
      AND (p_Estado IS NULL OR p_Estado='' OR v.ESTADO=p_Estado);
    SET v_offset = (p_Pagina - 1) * p_TamanioPagina;
    SELECT v.IDVENTA, v.IDCOTIZACION, v.IDCLIENTE, IFNULL(c.NOMBRE, v.NOMBRECLIENTE) AS CLIENTE_NOMBRE, v.NOMBRECLIENTE, v.IDFORMAPAGO, f.NOMBRE AS FORMAPAGO_NOMBRE,
           v.IDTIPOENTREGA, t.NOMBRE AS TIPOENTREGA_NOMBRE, v.DIRECCIONENTREGA, v.COSTODELIVERY, v.SUBTOTAL, v.TOTAL, v.ESTADO,
           v.FECHACREACION AS FECHA, v.HORACREACION AS HORA,
           v.CREADOPOR, TRIM(CONCAT(IFNULL(cu.NOMBRE,''), ' ', IFNULL(cu.APELLIDO,''))) AS CREADOPOR_NOMBRE
    FROM VENTA v
    LEFT JOIN CLIENTE c ON c.IDCLIENTE=v.IDCLIENTE
    LEFT JOIN FORMA_PAGO f ON f.IDFORMAPAGO=v.IDFORMAPAGO
    LEFT JOIN TIPO_ENTREGA t ON t.IDTIPOENTREGA=v.IDTIPOENTREGA
    LEFT JOIN USUARIO cu ON cu.IDUSUARIO=v.CREADOPOR
    WHERE (p_Buscar IS NULL OR p_Buscar='' OR v.IDVENTA LIKE CONCAT('%', p_Buscar, '%') OR IFNULL(c.NOMBRE,v.NOMBRECLIENTE) LIKE CONCAT('%', p_Buscar, '%') OR IFNULL(v.IDCOTIZACION,'') LIKE CONCAT('%', p_Buscar, '%'))
      AND (p_Estado IS NULL OR p_Estado='' OR v.ESTADO=p_Estado)
    ORDER BY v.FECHACREACION DESC, v.HORACREACION DESC
    LIMIT p_TamanioPagina OFFSET v_offset;
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_venta_obtener;

DROP PROCEDURE IF EXISTS usp_venta_obtener;

DELIMITER $$

CREATE PROCEDURE usp_venta_obtener(
    IN p_Id VARCHAR(50)
)
main: BEGIN
SELECT v.*, IFNULL(c.NOMBRE, v.NOMBRECLIENTE) AS CLIENTE_NOMBRE, f.NOMBRE AS FORMAPAGO_NOMBRE, t.NOMBRE AS TIPOENTREGA_NOMBRE,
           v.FECHACREACION AS FECHA, v.HORACREACION AS HORA
    FROM VENTA v
    LEFT JOIN CLIENTE c ON c.IDCLIENTE=v.IDCLIENTE
    LEFT JOIN FORMA_PAGO f ON f.IDFORMAPAGO=v.IDFORMAPAGO
    LEFT JOIN TIPO_ENTREGA t ON t.IDTIPOENTREGA=v.IDTIPOENTREGA
    WHERE v.IDVENTA=p_Id;
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_venta_detalle_listar;

DROP PROCEDURE IF EXISTS usp_venta_detalle_listar;

DELIMITER $$

CREATE PROCEDURE usp_venta_detalle_listar(
    IN p_Id VARCHAR(50)
)
main: BEGIN
SELECT d.IDDETALLE, d.IDPRODUCTO, p.NOMBRE AS PRODUCTO_NOMBRE, d.CANTIDAD, d.PRECIOUNITARIO, d.SUBTOTAL
    FROM VENTA_DETALLE d INNER JOIN PRODUCTO p ON p.IDPRODUCTO=d.IDPRODUCTO
    WHERE d.IDVENTA=p_Id;
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_venta_guardar_detalle;

DROP PROCEDURE IF EXISTS usp_venta_guardar_detalle;

DELIMITER $$

CREATE PROCEDURE usp_venta_guardar_detalle(
    IN p_Id VARCHAR(50),
    IN p_DetalleJson LONGTEXT
)
main: BEGIN
DECLARE v_Sub DECIMAL(12,2);
    DELETE FROM VENTA_DETALLE WHERE IDVENTA=p_Id;
    INSERT INTO VENTA_DETALLE (IDDETALLE, IDVENTA, IDPRODUCTO, CANTIDAD, PRECIOUNITARIO, SUBTOTAL)
    SELECT CONCAT(p_Id, RIGHT(CONCAT('000', CAST(ROW_NUMBER() OVER (ORDER BY j.IDPRODUCTO) AS CHAR)), 3)),
           p_Id, j.IDPRODUCTO, j.CANTIDAD, j.PRECIOUNITARIO, j.CANTIDAD * j.PRECIOUNITARIO
    FROM JSON_TABLE(IFNULL(p_DetalleJson, '[]'), '$[*]' COLUMNS (
            IDPRODUCTO VARCHAR(50) PATH '$.IDPRODUCTO',
            CANTIDAD DECIMAL(12,2) PATH '$.CANTIDAD',
            PRECIOUNITARIO DECIMAL(12,2) PATH '$.PRECIOUNITARIO'
        )) AS j WHERE j.IDPRODUCTO IS NOT NULL AND j.CANTIDAD > 0;
    SET v_Sub = IFNULL((SELECT SUM(SUBTOTAL) FROM VENTA_DETALLE WHERE IDVENTA=p_Id),0); 
    UPDATE VENTA SET SUBTOTAL=v_Sub, TOTAL=v_Sub + IFNULL(COSTODELIVERY,0) WHERE IDVENTA=p_Id;
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_venta_insertar;

DROP PROCEDURE IF EXISTS usp_venta_insertar;

DELIMITER $$

CREATE PROCEDURE usp_venta_insertar(
    IN p_IdCliente VARCHAR(50),
    IN p_IdFormaPago VARCHAR(50),
    IN p_IdTipoEntrega VARCHAR(50),
    IN p_DireccionEntrega VARCHAR(255),
    IN p_CostoDelivery DECIMAL(12,2),
    IN p_Observaciones LONGTEXT,
    IN p_Estado VARCHAR(50),
    IN p_DetalleJson LONGTEXT,
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
DECLARE v_Id VARCHAR(50);
    IF p_IdCliente IS NULL THEN SET p_Resultado=0; SET p_Mensaje='Selecciona un cliente.'; LEAVE main; END IF;
      CALL usp_siguiente_id('VEN', 'VENTA', 'IDVENTA', v_Id);
    INSERT INTO VENTA (IDVENTA,IDCLIENTE,IDFORMAPAGO,IDTIPOENTREGA,DIRECCIONENTREGA,COSTODELIVERY,SUBTOTAL,TOTAL,OBSERVACIONES,ESTADO,
        CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
    VALUES (v_Id,p_IdCliente,p_IdFormaPago,p_IdTipoEntrega,p_DireccionEntrega,IFNULL(p_CostoDelivery,0),0,0,p_Observaciones,IFNULL(p_Estado,'Pagado'),
        fn_actor(),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'),fn_actor(),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'));
    IF p_DetalleJson IS NOT NULL AND CHAR_LENGTH(p_DetalleJson)>2 THEN
        CALL usp_venta_guardar_detalle(v_Id, p_DetalleJson); END IF;
    SET p_Resultado=1; SET p_Mensaje='Venta registrada.';
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_venta_actualizar;

DROP PROCEDURE IF EXISTS usp_venta_actualizar;

DELIMITER $$

CREATE PROCEDURE usp_venta_actualizar(
    IN p_Id VARCHAR(50),
    IN p_IdCliente VARCHAR(50),
    IN p_IdFormaPago VARCHAR(50),
    IN p_IdTipoEntrega VARCHAR(50),
    IN p_DireccionEntrega VARCHAR(255),
    IN p_CostoDelivery DECIMAL(12,2),
    IN p_Observaciones LONGTEXT,
    IN p_Estado VARCHAR(50),
    IN p_DetalleJson LONGTEXT,
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
IF NOT EXISTS (SELECT 1 FROM VENTA WHERE IDVENTA=p_Id) THEN SET p_Resultado=0; SET p_Mensaje='La venta no existe.'; LEAVE main; END IF;
    UPDATE VENTA SET IDCLIENTE=p_IdCliente, IDFORMAPAGO=p_IdFormaPago, IDTIPOENTREGA=p_IdTipoEntrega,
        DIRECCIONENTREGA=p_DireccionEntrega, COSTODELIVERY=IFNULL(p_CostoDelivery,0), OBSERVACIONES=p_Observaciones, ESTADO=p_Estado,
        MODIFICADOPOR=fn_actor(), FECHAMODIFICACION=fn_fecha_ddmmyyyy(), HORAMODIFICACION=TIME_FORMAT(NOW(), '%H:%i:%s')
    WHERE IDVENTA=p_Id;
    IF p_DetalleJson IS NOT NULL THEN
        CALL usp_venta_guardar_detalle(p_Id, p_DetalleJson); END IF;
    SET p_Resultado=1; SET p_Mensaje='Venta actualizada.';
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_venta_eliminar;

DROP PROCEDURE IF EXISTS usp_venta_eliminar;

DELIMITER $$

CREATE PROCEDURE usp_venta_eliminar(
    IN p_Id VARCHAR(50),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
UPDATE COTIZACION SET IDVENTA=NULL, ESTADO='Cotizado' WHERE IDVENTA=p_Id;
    DELETE FROM VENTA_DETALLE WHERE IDVENTA=p_Id;
    DELETE FROM VENTA WHERE IDVENTA=p_Id;
    SET p_Resultado=1; SET p_Mensaje='Venta eliminada.';
END$$

DELIMITER ;

SELECT 'SPs cotización y venta listos.';

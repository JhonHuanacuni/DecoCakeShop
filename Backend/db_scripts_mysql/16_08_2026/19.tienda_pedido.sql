-- Convertido desde db_scripts/16_08_2026/19.tienda_pedido.sql
-- MySQL 8 — DecoCake Shop

USE `DecoCakeShop`;

/* Pedido web: captura de pago en base64 y alta desde la tienda */

ALTER TABLE VENTA ADD COLUMN COMPROBANTEPAGO LONGTEXT NULL;

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
    IN p_ComprobantePago LONGTEXT,
    IN p_NombreCliente VARCHAR(200),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
DECLARE v_Est VARCHAR(50);
    DECLARE v_Id VARCHAR(50);
    IF p_IdCliente IS NULL THEN SET p_Resultado=0; SET p_Mensaje='Selecciona un cliente.'; LEAVE main; END IF;
    SET v_Est = IFNULL(NULLIF(TRIM(p_Estado),''),'Pendiente'); 
    IF v_Est NOT IN ('Pendiente','Empaquetado','Enviado') THEN SET v_Est='Pendiente'; END IF;
      CALL usp_siguiente_id('VEN', 'VENTA', 'IDVENTA', v_Id);
    INSERT INTO VENTA (IDVENTA,IDCLIENTE,NOMBRECLIENTE,IDFORMAPAGO,IDTIPOENTREGA,DIRECCIONENTREGA,COSTODELIVERY,SUBTOTAL,TOTAL,OBSERVACIONES,ESTADO,COMPROBANTEPAGO,
        CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
    VALUES (v_Id,p_IdCliente,p_NombreCliente,p_IdFormaPago,p_IdTipoEntrega,p_DireccionEntrega,IFNULL(p_CostoDelivery,0),0,0,p_Observaciones,v_Est,p_ComprobantePago,
        fn_actor(),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'),fn_actor(),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'));
    IF p_DetalleJson IS NOT NULL AND CHAR_LENGTH(p_DetalleJson)>2 THEN
        CALL usp_venta_guardar_detalle(v_Id, p_DetalleJson); END IF;
    SET p_Resultado=1; SET p_Mensaje='Pedido registrado.';
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
    IN p_ComprobantePago LONGTEXT,
    IN p_NombreCliente VARCHAR(200),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
DECLARE v_Est VARCHAR(50);
    IF NOT EXISTS (SELECT 1 FROM VENTA WHERE IDVENTA=p_Id) THEN SET p_Resultado=0; SET p_Mensaje='El pedido no existe.'; LEAVE main; END IF;
    IF EXISTS (SELECT 1 FROM VENTA WHERE IDVENTA=p_Id AND ESTADO='Anulado') THEN SET p_Resultado=0; SET p_Mensaje='No se puede editar un pedido anulado.'; LEAVE main; END IF;
    SET v_Est = IFNULL(NULLIF(TRIM(p_Estado),''),'Pendiente'); 
    IF v_Est NOT IN ('Pendiente','Empaquetado','Enviado') THEN SET v_Est='Pendiente'; END IF;
    UPDATE VENTA SET IDCLIENTE=p_IdCliente, NOMBRECLIENTE=IFNULL(p_NombreCliente,NOMBRECLIENTE),
        IDFORMAPAGO=p_IdFormaPago, IDTIPOENTREGA=p_IdTipoEntrega,
        DIRECCIONENTREGA=p_DireccionEntrega, COSTODELIVERY=IFNULL(p_CostoDelivery,0), OBSERVACIONES=p_Observaciones, ESTADO=v_Est,
        COMPROBANTEPAGO=CASE WHEN p_ComprobantePago IS NULL THEN COMPROBANTEPAGO ELSE p_ComprobantePago END,
        MODIFICADOPOR=fn_actor(), FECHAMODIFICACION=fn_fecha_ddmmyyyy(), HORAMODIFICACION=TIME_FORMAT(NOW(), '%H:%i:%s')
    WHERE IDVENTA=p_Id;
    IF p_DetalleJson IS NOT NULL THEN
        CALL usp_venta_guardar_detalle(p_Id, p_DetalleJson); END IF;
    SET p_Resultado=1; SET p_Mensaje='Pedido actualizado.';
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_tienda_pedido;

DROP PROCEDURE IF EXISTS usp_tienda_pedido;

DELIMITER $$

CREATE PROCEDURE usp_tienda_pedido(
    IN p_Nombre VARCHAR(200),
    IN p_Telefono VARCHAR(20),
    IN p_Email VARCHAR(150),
    IN p_Direccion VARCHAR(255),
    IN p_IdFormaPago VARCHAR(50),
    IN p_IdTipoEntrega VARCHAR(50),
    IN p_ComprobantePago LONGTEXT,
    IN p_Observaciones LONGTEXT,
    IN p_DetalleJson LONGTEXT,
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
DECLARE v_Nom VARCHAR(200);
    DECLARE v_Tel VARCHAR(20);
    DECLARE v_IdCliente VARCHAR(50);
    DECLARE v_Id VARCHAR(50);
    SET v_Nom = TRIM(IFNULL(p_Nombre,'')); 
    SET v_Tel = TRIM(IFNULL(p_Telefono,'')); 
    IF v_Nom='' THEN SET p_Resultado=0; SET p_Mensaje='Ingresa tu nombre.'; LEAVE main; END IF;
    IF v_Tel='' THEN SET p_Resultado=0; SET p_Mensaje='Ingresa tu teléfono.'; LEAVE main; END IF;
    IF p_IdFormaPago IS NULL OR NOT EXISTS (SELECT 1 FROM FORMA_PAGO WHERE IDFORMAPAGO=p_IdFormaPago AND ESTADO='Activo') THEN SET p_Resultado=0; SET p_Mensaje='Selecciona un método de pago.'; LEAVE main; END IF;
    IF p_ComprobantePago IS NULL OR CHAR_LENGTH(p_ComprobantePago) < 40 THEN SET p_Resultado=0; SET p_Mensaje='Adjunta la captura del pago.'; LEAVE main; END IF;
    IF p_DetalleJson IS NULL OR CHAR_LENGTH(p_DetalleJson) < 8 THEN SET p_Resultado=0; SET p_Mensaje='El carrito está vacío.'; LEAVE main; END IF;
    IF p_IdTipoEntrega IS NOT NULL AND EXISTS (SELECT 1 FROM TIPO_ENTREGA WHERE IDTIPOENTREGA=p_IdTipoEntrega AND REQUIEREDIRECCION=1)
       AND (TRIM(IFNULL(p_Direccion,''))='')
    THEN SET p_Resultado=0; SET p_Mensaje='Ingresa la dirección de entrega.'; LEAVE main; END IF;
     
    SELECT IDCLIENTE INTO v_IdCliente FROM CLIENTE WHERE TELEFONO=v_Tel ORDER BY FECHACREACION DESC LIMIT 1;
    IF v_IdCliente IS NULL THEN
            CALL usp_siguiente_id('CLI', 'CLIENTE', 'IDCLIENTE', v_IdCliente);
        INSERT INTO CLIENTE (IDCLIENTE,NOMBRE,TELEFONO,EMAIL,DIRECCION,ESTADO,CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
        VALUES (v_IdCliente,v_Nom,v_Tel,p_Email,p_Direccion,'Activo',IFNULL(fn_actor(),'tienda'),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'),IFNULL(fn_actor(),'tienda'),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'));
    ELSE
        UPDATE CLIENTE SET NOMBRE=v_Nom, EMAIL=IFNULL(p_Email,EMAIL), DIRECCION=IFNULL(NULLIF(TRIM(p_Direccion),''),DIRECCION),
            MODIFICADOPOR=IFNULL(fn_actor(),'tienda'), FECHAMODIFICACION=fn_fecha_ddmmyyyy(), HORAMODIFICACION=TIME_FORMAT(NOW(), '%H:%i:%s')
        WHERE IDCLIENTE=v_IdCliente;
    END IF;
      CALL usp_siguiente_id('VEN', 'VENTA', 'IDVENTA', v_Id);
    INSERT INTO VENTA (IDVENTA,IDCLIENTE,NOMBRECLIENTE,IDFORMAPAGO,IDTIPOENTREGA,DIRECCIONENTREGA,COSTODELIVERY,SUBTOTAL,TOTAL,OBSERVACIONES,ESTADO,COMPROBANTEPAGO,
        CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
    VALUES (v_Id,v_IdCliente,v_Nom,p_IdFormaPago,p_IdTipoEntrega,p_Direccion,0,0,0,p_Observaciones,'Pendiente',p_ComprobantePago,
        IFNULL(fn_actor(),'tienda'),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'),IFNULL(fn_actor(),'tienda'),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'));
    CALL usp_venta_guardar_detalle(v_Id, p_DetalleJson);
    IF NOT EXISTS (SELECT 1 FROM VENTA_DETALLE WHERE IDVENTA=v_Id) THEN
            DELETE FROM VENTA WHERE IDVENTA=v_Id;
        SET p_Resultado=0; SET p_Mensaje='No se pudieron guardar los productos.'; LEAVE main;
    END IF;
    SET p_Resultado=1; SET p_Mensaje=CONCAT('Pedido registrado. ', v_Id, '.');
END$$

DELIMITER ;

SELECT 'Pedido de tienda con captura de pago listo.';

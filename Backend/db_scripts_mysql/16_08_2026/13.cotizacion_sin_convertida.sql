-- Convertido desde db_scripts/16_08_2026/13.cotizacion_sin_convertida.sql
-- MySQL 8 — DecoCake Shop

USE `DecoCakeShop`;

/* Incremental: cotización solo Deuda/Pagado (sin estado Convertida) */

UPDATE COTIZACION c
LEFT JOIN (
    SELECT IDCOTIZACION, SUM(MONTO) AS ABONADO FROM COTIZACION_PAGO GROUP BY IDCOTIZACION
) pay ON pay.IDCOTIZACION = c.IDCOTIZACION
SET c.ESTADO = CASE
    WHEN IFNULL(pay.ABONADO, 0) >= IFNULL(c.TOTAL, 0) AND IFNULL(c.TOTAL, 0) > 0 THEN 'Pagado'
    ELSE 'Deuda'
END
WHERE c.ESTADO = 'Convertida';

DROP PROCEDURE IF EXISTS usp_cotizacion_pago_recalcular;

DROP PROCEDURE IF EXISTS usp_cotizacion_pago_recalcular;

DELIMITER $$

CREATE PROCEDURE usp_cotizacion_pago_recalcular(
    IN p_Id VARCHAR(50)
)
main: BEGIN
DECLARE v_Total DECIMAL(12,2);
    DECLARE v_Pagado DECIMAL(12,2);
    DECLARE v_Estado VARCHAR(50);
    SELECT IFNULL(TOTAL,0), v_Estado=ESTADO INTO v_Total FROM COTIZACION WHERE IDCOTIZACION=p_Id;
    IF v_Estado IS NULL THEN LEAVE main; END IF;
    IF v_Estado = 'Anulada' THEN LEAVE main; END IF;
    SELECT IFNULL(SUM(MONTO),0) INTO v_Pagado FROM COTIZACION_PAGO WHERE IDCOTIZACION=p_Id;
    IF v_Pagado >= v_Total AND v_Total > 0 THEN SET v_Estado='Pagado'; END IF;
    ELSE SET v_Estado='Deuda';
    UPDATE COTIZACION SET ESTADO=v_Estado,
        MODIFICADOPOR=fn_actor(), FECHAMODIFICACION=fn_fecha_ddmmyyyy(), HORAMODIFICACION=TIME_FORMAT(NOW(), '%H:%i:%s')
    WHERE IDCOTIZACION=p_Id;
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_cotizacion_pago_insertar;

DROP PROCEDURE IF EXISTS usp_cotizacion_pago_insertar;

DELIMITER $$

CREATE PROCEDURE usp_cotizacion_pago_insertar(
    IN p_Id VARCHAR(50),
    IN p_Monto DECIMAL(12,2),
    IN p_Tipo VARCHAR(50),
    IN p_IdFormaPago VARCHAR(50),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
DECLARE v_Forma VARCHAR(50);
    DECLARE v_Total DECIMAL(12,2);
    DECLARE v_Pagado DECIMAL(12,2);
    DECLARE v_Saldo DECIMAL(12,2);
    DECLARE v_IdPago VARCHAR(50);
    IF NOT EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=p_Id) THEN SET p_Resultado=0; SET p_Mensaje='La cotización no existe.'; LEAVE main; END IF;
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=p_Id AND ESTADO='Anulada') THEN SET p_Resultado=0; SET p_Mensaje='No se puede registrar un abono en una cotización anulada.'; LEAVE main; END IF;
    IF IFNULL(p_Monto,0) <= 0 THEN SET p_Resultado=0; SET p_Mensaje='El monto del abono debe ser mayor a cero.'; LEAVE main; END IF;
    SET v_Forma = NULLIF(TRIM(IFNULL(p_IdFormaPago,'')), ''); 
    IF v_Forma IS NULL OR NOT EXISTS (SELECT 1 FROM FORMA_PAGO WHERE IDFORMAPAGO=v_Forma AND ESTADO='Activo') THEN SET p_Resultado=0; SET p_Mensaje='Selecciona el método de pago.'; LEAVE main; END IF;
       
    SELECT IFNULL(TOTAL,0) INTO v_Total FROM COTIZACION WHERE IDCOTIZACION=p_Id;
    SELECT IFNULL(SUM(MONTO),0) INTO v_Pagado FROM COTIZACION_PAGO WHERE IDCOTIZACION=p_Id;
    SET v_Saldo = v_Total - v_Pagado;
    IF p_Monto > v_Saldo + 0.009 THEN SET p_Resultado=0; SET p_Mensaje='El abono no puede ser mayor al saldo pendiente.'; LEAVE main; END IF;
     
    CALL usp_siguiente_id('PAG', 'COTIZACION_PAGO', 'IDPAGO', v_IdPago);
    INSERT INTO COTIZACION_PAGO (IDPAGO,IDCOTIZACION,MONTO,TIPO,IDFORMAPAGO,
        CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
    VALUES (v_IdPago,p_Id,p_Monto,IFNULL(NULLIF(TRIM(p_Tipo),''),'Abono'),v_Forma,
        fn_actor(),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'),
        fn_actor(),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'));
    CALL usp_cotizacion_pago_recalcular(p_Id);
    SET p_Resultado=1; SET p_Mensaje='Abono registrado.';
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
    DECLARE v_Est VARCHAR(50);
    DECLARE v_Ok TINYINT(1);
    DECLARE v_Msg VARCHAR(200);
    IF NOT EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=p_Id) THEN SET p_Resultado=0; SET p_Mensaje='La cotización no existe.'; LEAVE main; END IF;
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=p_Id AND ESTADO='Anulada') THEN SET p_Resultado=0; SET p_Mensaje='No se puede editar una cotización anulada.'; LEAVE main; END IF;
    SET v_IdCli = NULLIF(TRIM(IFNULL(p_IdCliente,'')), ''); 
    SET v_Nom = NULLIF(TRIM(IFNULL(p_NombreCliente,'')), ''); 
    IF v_IdCli IS NOT NULL AND EXISTS (SELECT 1 FROM CLIENTE WHERE IDCLIENTE=v_IdCli)
        SELECT IFNULL(v_Nom, NOMBRE) INTO v_Nom FROM CLIENTE WHERE IDCLIENTE=v_IdCli;
    ELSE
        SET v_IdCli = NULL;
    IF v_Nom IS NULL THEN SET p_Resultado=0; SET p_Mensaje='Ingresa el cliente.'; LEAVE main; END IF;
    SET v_Est = IFNULL(NULLIF(TRIM(p_Estado),''),'Deuda'); 
    IF v_Est NOT IN ('Pagado','Deuda') THEN SET v_Est='Deuda'; END IF;
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=p_Id AND STOCKRESERVADO=1) THEN
        CALL usp_stock_desde_detalle(p_Id, 1);
    IF p_DetalleJson IS NOT NULL THEN
              
        CALL usp_stock_check_json(p_DetalleJson, v_Ok, v_Msg);
        IF v_Ok=0 THEN
                    IF EXISTS (SELECT 1 FROM COTIZACION_DETALLE WHERE IDCOTIZACION=p_Id) THEN
                CALL usp_stock_desde_detalle(p_Id, -1); END IF;
            SET p_Resultado=0; SET p_Mensaje=v_Msg; LEAVE main;
        END IF;
    END
    UPDATE COTIZACION SET IDCLIENTE=v_IdCli, NOMBRECLIENTE=v_Nom, IDTIPOENTREGA=p_IdTipoEntrega, DIRECCIONENTREGA=p_DireccionEntrega,
        COSTODELIVERY=IFNULL(p_CostoDelivery,0), OBSERVACIONES=p_Observaciones, ESTADO=v_Est, STOCKRESERVADO=0,
        MODIFICADOPOR=fn_actor(), FECHAMODIFICACION=fn_fecha_ddmmyyyy(), HORAMODIFICACION=TIME_FORMAT(NOW(), '%H:%i:%s')
    WHERE IDCOTIZACION=p_Id;
    IF p_DetalleJson IS NOT NULL THEN
        CALL usp_cotizacion_guardar_detalle(p_Id, p_DetalleJson);
    CALL usp_stock_desde_detalle(p_Id, -1);
    UPDATE COTIZACION SET STOCKRESERVADO=1 WHERE IDCOTIZACION=p_Id;
    CALL usp_cotizacion_pago_recalcular(p_Id);
    SET p_Resultado=1; SET p_Mensaje='Cotización actualizada.';
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_cotizacion_guardar_envio;

DROP PROCEDURE IF EXISTS usp_cotizacion_guardar_envio;

DELIMITER $$

CREATE PROCEDURE usp_cotizacion_guardar_envio(
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
    DECLARE v_Sub DECIMAL(12,2);
    IF NOT EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=p_Id) THEN SET p_Resultado=0; SET p_Mensaje='La cotización no existe.'; LEAVE main; END IF;
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=p_Id AND ESTADO='Anulada') THEN SET p_Resultado=0; SET p_Mensaje='No se puede guardar el envío de una cotización anulada.'; LEAVE main; END IF;
    SET v_Tipo = NULLIF(TRIM(IFNULL(p_IdTipoEntrega,'')), ''); 
    IF v_Tipo IS NULL OR NOT EXISTS (SELECT 1 FROM TIPO_ENTREGA WHERE IDTIPOENTREGA=v_Tipo AND ESTADO='Activo') THEN SET p_Resultado=0; SET p_Mensaje='Selecciona el tipo de entrega.'; LEAVE main; END IF;
    IF EXISTS (SELECT 1 FROM TIPO_ENTREGA WHERE IDTIPOENTREGA=v_Tipo AND REQUIEREDIRECCION=1)
       AND NULLIF(TRIM(IFNULL(p_DireccionEntrega,'')),'') IS NULL
    THEN SET p_Resultado=0; SET p_Mensaje='Ingresa la dirección de delivery.'; LEAVE main; END IF;
     
    SELECT IFNULL(SUBTOTAL,0) INTO v_Sub FROM COTIZACION WHERE IDCOTIZACION=p_Id;
    UPDATE COTIZACION SET
        IDFORMAPAGO=NULLIF(TRIM(IFNULL(p_IdFormaPago,'')), ''),
        IDTIPOENTREGA=v_Tipo,
        DIRECCIONENTREGA=p_DireccionEntrega,
        COSTODELIVERY=IFNULL(p_CostoDelivery,0),
        TOTAL=v_Sub + IFNULL(p_CostoDelivery,0),
        MODIFICADOPOR=fn_actor(), FECHAMODIFICACION=fn_fecha_ddmmyyyy(), HORAMODIFICACION=TIME_FORMAT(NOW(), '%H:%i:%s')
    WHERE IDCOTIZACION=p_Id;
    CALL usp_cotizacion_pago_recalcular(p_Id);
    SET p_Resultado=1; SET p_Mensaje='Datos de envío guardados.';
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_cotizacion_anular;

DROP PROCEDURE IF EXISTS usp_cotizacion_anular;

DELIMITER $$

CREATE PROCEDURE usp_cotizacion_anular(
    IN p_Id VARCHAR(50),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
IF NOT EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=p_Id) THEN SET p_Resultado=0; SET p_Mensaje='La cotización no existe.'; LEAVE main; END IF;
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=p_Id AND NULLIF(TRIM(IFNULL(IDVENTA,'')),'') IS NOT NULL) THEN SET p_Resultado=0; SET p_Mensaje='Anula el pedido asociado, no la cotización.'; LEAVE main; END IF;
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=p_Id AND ESTADO='Anulada') THEN SET p_Resultado=0; SET p_Mensaje='La cotización ya está anulada.'; LEAVE main; END IF;
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=p_Id AND STOCKRESERVADO=1) THEN
        CALL usp_stock_desde_detalle(p_Id, 1);
    UPDATE COTIZACION SET ESTADO='Anulada', STOCKRESERVADO=0,
        MODIFICADOPOR=fn_actor(), FECHAMODIFICACION=fn_fecha_ddmmyyyy(), HORAMODIFICACION=TIME_FORMAT(NOW(), '%H:%i:%s')
    WHERE IDCOTIZACION=p_Id;
    SET p_Resultado=1; SET p_Mensaje='Cotización anulada. El stock volvió al almacén.';
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
    DECLARE v_Forma VARCHAR(50);
    DECLARE v_Dir VARCHAR(255);
    DECLARE v_Costo DECIMAL(12,2);
    DECLARE v_IdVenta VARCHAR(50);
    DECLARE v_Sub DECIMAL(12,2);
    DECLARE v_Cli VARCHAR(50);
    DECLARE v_Nom VARCHAR(200);
    DECLARE v_Obs LONGTEXT;
    IF NOT EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=p_Id) THEN SET p_Resultado=0; SET p_Mensaje='La cotización no existe.'; LEAVE main; END IF;
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=p_Id AND ESTADO='Anulada') THEN SET p_Resultado=0; SET p_Mensaje='La cotización está anulada.'; LEAVE main; END IF;
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=p_Id AND NULLIF(TRIM(IFNULL(IDVENTA,'')),'') IS NOT NULL) THEN SET p_Resultado=0; SET p_Mensaje='Esta cotización ya tiene un pedido.'; LEAVE main; END IF;
    IF NOT EXISTS (SELECT 1 FROM COTIZACION_DETALLE WHERE IDCOTIZACION=p_Id) THEN SET p_Resultado=0; SET p_Mensaje='La cotización no tiene productos.'; LEAVE main; END IF;
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=p_Id AND IFNULL(STOCKRESERVADO,0)=0) THEN
            IF EXISTS (
            SELECT 1 FROM COTIZACION_DETALLE d INNER JOIN PRODUCTO p ON p.IDPRODUCTO=d.IDPRODUCTO
            WHERE d.IDCOTIZACION=p_Id AND p.STOCK < d.CANTIDAD
        )
        THEN SET p_Resultado=0; SET p_Mensaje='Stock insuficiente para uno o más productos.'; LEAVE main; END IF;
        CALL usp_stock_desde_detalle(p_Id, -1);
        UPDATE COTIZACION SET STOCKRESERVADO=1 WHERE IDCOTIZACION=p_Id;
    END
    SET v_Tipo = NULLIF(TRIM(IFNULL(p_IdTipoEntrega,'')), ''); 
    SET v_Forma = NULLIF(TRIM(IFNULL(p_IdFormaPago,'')), ''); 
    SET v_Dir = NULLIF(TRIM(IFNULL(p_DireccionEntrega,'')), ''); 
    SET v_Costo = IFNULL(p_CostoDelivery,0); 
    SELECT IFNULL(v_Tipo, IDTIPOENTREGA), INTO v_Tipo
        v_Forma = IFNULL(v_Forma, IDFORMAPAGO),
        v_Dir = IFNULL(v_Dir, NULLIF(TRIM(IFNULL(DIRECCIONENTREGA,'')), '')),
        v_Costo = CASE WHEN p_IdTipoEntrega IS NULL AND p_CostoDelivery=0 THEN IFNULL(COSTODELIVERY,0) ELSE v_Costo END
    FROM COTIZACION WHERE IDCOTIZACION=p_Id;
    IF v_Tipo IS NULL OR NOT EXISTS (SELECT 1 FROM TIPO_ENTREGA WHERE IDTIPOENTREGA=v_Tipo AND ESTADO='Activo') THEN SET p_Resultado=0; SET p_Mensaje='Selecciona el tipo de entrega.'; LEAVE main; END IF;
    IF EXISTS (SELECT 1 FROM TIPO_ENTREGA WHERE IDTIPOENTREGA=v_Tipo AND REQUIEREDIRECCION=1)
       AND v_Dir IS NULL
    THEN SET p_Resultado=0; SET p_Mensaje='Ingresa la dirección de delivery.'; LEAVE main; END IF;
      CALL usp_siguiente_id('VEN', 'VENTA', 'IDVENTA', v_IdVenta);
        
    SELECT SUBTOTAL, IDCLIENTE, NOMBRECLIENTE, OBSERVACIONES INTO v_Sub, v_Cli, v_Nom, v_Obs FROM COTIZACION WHERE IDCOTIZACION=p_Id;
    INSERT INTO VENTA (IDVENTA,IDCOTIZACION,IDCLIENTE,NOMBRECLIENTE,IDFORMAPAGO,IDTIPOENTREGA,DIRECCIONENTREGA,COSTODELIVERY,SUBTOTAL,TOTAL,OBSERVACIONES,ESTADO,
        CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
    VALUES (
        v_IdVenta, p_Id, v_Cli, v_Nom, v_Forma, v_Tipo, v_Dir,
        v_Costo, v_Sub, v_Sub + v_Costo, v_Obs, 'Pendiente',
        fn_actor(), fn_fecha_ddmmyyyy(), TIME_FORMAT(NOW(), '%H:%i:%s'),
        fn_actor(), fn_fecha_ddmmyyyy(), TIME_FORMAT(NOW(), '%H:%i:%s')
    );
    INSERT INTO VENTA_DETALLE (IDDETALLE, IDVENTA, IDPRODUCTO, CANTIDAD, PRECIOUNITARIO, SUBTOTAL)
    SELECT CONCAT(v_IdVenta, RIGHT(CONCAT('000', CAST(ROW_NUMBER() OVER (ORDER BY IDDETALLE) AS CHAR)), 3)),
           v_IdVenta, IDPRODUCTO, CANTIDAD, PRECIOUNITARIO, SUBTOTAL
    FROM COTIZACION_DETALLE WHERE IDCOTIZACION=p_Id;
    UPDATE COTIZACION SET IDVENTA=v_IdVenta,
        IDFORMAPAGO=v_Forma, IDTIPOENTREGA=v_Tipo, DIRECCIONENTREGA=v_Dir, COSTODELIVERY=v_Costo,
        TOTAL=v_Sub + v_Costo,
        ENVIADOPOR=fn_actor(), FECHAENVIO=fn_fecha_ddmmyyyy(), HORAENVIO=TIME_FORMAT(NOW(), '%H:%i:%s'),
        MODIFICADOPOR=fn_actor(), FECHAMODIFICACION=fn_fecha_ddmmyyyy(), HORAMODIFICACION=TIME_FORMAT(NOW(), '%H:%i:%s')
    WHERE IDCOTIZACION=p_Id;
    CALL usp_cotizacion_pago_recalcular(p_Id);
    SET p_Resultado=1; SET p_Mensaje=CONCAT('Pedido generado. ', v_IdVenta, '.');
END$$

DELIMITER ;

SELECT 'Cotizaciones: solo estados Deuda y Pagado.';

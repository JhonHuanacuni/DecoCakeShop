-- Convertido desde db_scripts/16_08_2026/15.cotizacion_pedido_anular.sql
-- MySQL 8 — DecoCake Shop

USE `DecoCakeShop`;

/* Incremental: permitir hacer pedido y anular aunque ya exista un pedido */

DROP PROCEDURE IF EXISTS usp_cotizacion_anular;

DROP PROCEDURE IF EXISTS usp_cotizacion_anular;

DELIMITER $$

CREATE PROCEDURE usp_cotizacion_anular(
    IN p_Id VARCHAR(50),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
DECLARE v_IdVenta VARCHAR(50);
    IF NOT EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=p_Id) THEN SET p_Resultado=0; SET p_Mensaje='La cotización no existe.'; LEAVE main; END IF;
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=p_Id AND ESTADO='Anulada') THEN SET p_Resultado=0; SET p_Mensaje='La cotización ya está anulada.'; LEAVE main; END IF;
     
    SELECT NULLIF(TRIM(IFNULL(IDVENTA,'')), '') INTO v_IdVenta FROM COTIZACION WHERE IDCOTIZACION=p_Id;
    IF v_IdVenta IS NOT NULL AND EXISTS (SELECT 1 FROM VENTA WHERE IDVENTA=v_IdVenta AND ESTADO<>'Anulado') THEN
            CALL usp_venta_anular(v_IdVenta, p_Resultado, p_Mensaje);
        IF IFNULL(p_Resultado,0)=0 THEN LEAVE main; END IF;
        UPDATE COTIZACION SET ESTADO='Anulada', STOCKRESERVADO=0,
            MODIFICADOPOR=fn_actor(), FECHAMODIFICACION=fn_fecha_ddmmyyyy(), HORAMODIFICACION=TIME_FORMAT(NOW(), '%H:%i:%s')
        WHERE IDCOTIZACION=p_Id;
        SET p_Resultado=1; SET p_Mensaje='Cotización y pedido asociado anulados. El stock volvió al almacén.';
        LEAVE main;
    END IF;
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=p_Id AND STOCKRESERVADO=1) THEN
        CALL usp_stock_desde_detalle(p_Id, 1);
    END IF;
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
DECLARE v_YaPedido TINYINT(1);
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
    IF NOT EXISTS (SELECT 1 FROM COTIZACION_DETALLE WHERE IDCOTIZACION=p_Id) THEN SET p_Resultado=0; SET p_Mensaje='La cotización no tiene productos.'; LEAVE main; END IF;
    SET v_YaPedido = CASE WHEN EXISTS (
        SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=p_Id AND NULLIF(TRIM(IFNULL(IDVENTA,'')),'') IS NOT NULL
    ) THEN 1 ELSE 0 END; 
    IF v_YaPedido = 1 OR EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=p_Id AND IFNULL(STOCKRESERVADO,0)=0) THEN
            IF EXISTS (
            SELECT 1 FROM COTIZACION_DETALLE d INNER JOIN PRODUCTO p ON p.IDPRODUCTO=d.IDPRODUCTO
            WHERE d.IDCOTIZACION=p_Id AND p.STOCK < d.CANTIDAD
        )
        THEN SET p_Resultado=0; SET p_Mensaje='Stock insuficiente para uno o más productos.'; LEAVE main; END IF;
        CALL usp_stock_desde_detalle(p_Id, -1);
        UPDATE COTIZACION SET STOCKRESERVADO=1 WHERE IDCOTIZACION=p_Id;
    END IF;
    SET v_Tipo = NULLIF(TRIM(IFNULL(p_IdTipoEntrega,'')), ''); 
    SET v_Forma = NULLIF(TRIM(IFNULL(p_IdFormaPago,'')), ''); 
    SET v_Dir = NULLIF(TRIM(IFNULL(p_DireccionEntrega,'')), ''); 
    SET v_Costo = IFNULL(p_CostoDelivery,0); 
    SELECT IFNULL(v_Tipo, IDTIPOENTREGA), IFNULL(v_Forma, IDFORMAPAGO), IFNULL(v_Dir, NULLIF(TRIM(IFNULL(DIRECCIONENTREGA,'')), '')), CASE WHEN p_IdTipoEntrega IS NULL AND p_CostoDelivery=0 THEN IFNULL(COSTODELIVERY,0) ELSE v_Costo END INTO v_Tipo, v_Forma, v_Dir, v_Costo FROM COTIZACION WHERE IDCOTIZACION=p_Id;
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

SELECT 'Hacer pedido y anular habilitados.';

-- Convertido desde db_scripts/16_08_2026/5.pedidos.sql
-- MySQL 8 — DecoCake Shop

USE `DecoCakeShop`;

/* Incremental: módulo Pedidos + datos de envío al convertir cotización */

UPDATE MODULO
SET NOMBRE = 'Pedidos', DESCRIPCION = 'Pedidos confirmados con datos de envío'
WHERE IDMODULO = 'MOD005';

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

SELECT 'Pedidos y envío al convertir listos.';

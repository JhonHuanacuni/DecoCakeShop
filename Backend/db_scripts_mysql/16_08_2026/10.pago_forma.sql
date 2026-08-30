-- Convertido desde db_scripts/16_08_2026/10.pago_forma.sql
-- MySQL 8 — DecoCake Shop

USE `DecoCakeShop`;

/* Incremental: método de pago en abonos de cotización */

ALTER TABLE COTIZACION_PAGO ADD COLUMN IDFORMAPAGO VARCHAR(50) NULL;

-- FK ya existe o se ignora (1826)

DROP PROCEDURE IF EXISTS usp_cotizacion_pago_listar;

DROP PROCEDURE IF EXISTS usp_cotizacion_pago_listar;

DELIMITER $$

CREATE PROCEDURE usp_cotizacion_pago_listar(
    IN p_Id VARCHAR(50)
)
main: BEGIN
SELECT p.IDPAGO, p.IDCOTIZACION, p.MONTO, p.TIPO, p.IDFORMAPAGO, f.NOMBRE AS FORMAPAGO_NOMBRE,
           p.CREADOPOR,
           CONCAT(IFNULL(NULLIF(TRIM(IFNULL(cu.NOMBRE,''), ' ', IFNULL(cu.APELLIDO,''))), ''), p.CREADOPOR) AS CREADOPOR_NOMBRE,
           p.FECHACREACION, p.HORACREACION,
           p.MODIFICADOPOR,
           CONCAT(IFNULL(NULLIF(TRIM(IFNULL(mu.NOMBRE,''), ' ', IFNULL(mu.APELLIDO,''))), ''), p.MODIFICADOPOR) AS MODIFICADOPOR_NOMBRE,
           p.FECHAMODIFICACION, p.HORAMODIFICACION
    FROM COTIZACION_PAGO p
    LEFT JOIN FORMA_PAGO f ON f.IDFORMAPAGO=p.IDFORMAPAGO
    LEFT JOIN USUARIO cu ON cu.IDUSUARIO=p.CREADOPOR
    LEFT JOIN USUARIO mu ON mu.IDUSUARIO=p.MODIFICADOPOR
    WHERE p.IDCOTIZACION=p_Id
    ORDER BY p.FECHACREACION, p.HORACREACION, p.IDPAGO;
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
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=p_Id AND ESTADO IN ('Anulada','Convertida')) THEN SET p_Resultado=0; SET p_Mensaje='No se puede registrar un abono en una cotización anulada o convertida.'; LEAVE main; END IF;
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
    IN p_MontoInicial DECIMAL(12,2),
    IN p_IdFormaPago VARCHAR(50),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200),
    OUT p_IdOut VARCHAR(50)
)
main: BEGIN
DECLARE v_IdCli VARCHAR(50);
    DECLARE v_Nom VARCHAR(200);
    DECLARE v_Ok TINYINT(1);
    DECLARE v_Msg VARCHAR(200);
    DECLARE v_TotalEst DECIMAL(12,2) = IFNULL((
        SELECT SUM(j.CANTIDAD * j.PRECIOUNITARIO)
        FROM JSON_TABLE(IFNULL(p_DetalleJson, '[]'), '$[*]' COLUMNS (
            IDPRODUCTO VARCHAR(50) PATH '$.IDPRODUCTO',
            CANTIDAD DECIMAL(12,2) PATH '$.CANTIDAD',
            PRECIOUNITARIO DECIMAL(12,2) PATH '$.PRECIOUNITARIO'
        )) AS j
        WHERE j.IDPRODUCTO IS NOT NULL AND j.CANTIDAD > 0
    ), 0) + IFNULL(p_CostoDelivery, 0);
    DECLARE v_Est VARCHAR(50);
    DECLARE v_Id VARCHAR(50);
    DECLARE v_RPago INT;
    DECLARE v_MPago VARCHAR(200);
    SET p_IdOut = NULL;
    SET v_IdCli = NULLIF(TRIM(IFNULL(p_IdCliente,'')), ''); 
    SET v_Nom = NULLIF(TRIM(IFNULL(p_NombreCliente,'')), ''); 
    IF v_IdCli IS NOT NULL AND EXISTS (SELECT 1 FROM CLIENTE WHERE IDCLIENTE=v_IdCli)
        SELECT IFNULL(v_Nom, NOMBRE) INTO v_Nom FROM CLIENTE WHERE IDCLIENTE=v_IdCli;
    ELSE
        SET v_IdCli = NULL;
    IF v_Nom IS NULL THEN SET p_Resultado=0; SET p_Mensaje='Ingresa el cliente.'; LEAVE main; END IF;
    IF p_DetalleJson IS NULL OR CHAR_LENGTH(p_DetalleJson)<3 THEN SET p_Resultado=0; SET p_Mensaje='Agrega al menos un producto.'; LEAVE main; END IF;
      
    CALL usp_stock_check_json(p_DetalleJson, v_Ok, v_Msg);
    IF v_Ok=0 THEN SET p_Resultado=0; SET p_Mensaje=v_Msg; LEAVE main; END IF;
     
    IF IFNULL(p_MontoInicial,0) < 0 THEN SET p_Resultado=0; SET p_Mensaje='El monto inicial no puede ser negativo.'; LEAVE main; END IF;
    IF IFNULL(p_MontoInicial,0) > v_TotalEst + 0.009 THEN SET p_Resultado=0; SET p_Mensaje='El monto inicial no puede ser mayor al total.'; LEAVE main; END IF;
    IF IFNULL(p_MontoInicial,0) > 0
       AND (NULLIF(TRIM(IFNULL(p_IdFormaPago,'')),'') IS NULL
            OR NOT EXISTS (SELECT 1 FROM FORMA_PAGO WHERE IDFORMAPAGO=p_IdFormaPago AND ESTADO='Activo'))
    THEN SET p_Resultado=0; SET p_Mensaje='Selecciona el método de pago del abono inicial.'; LEAVE main; END IF;
    SET v_Est = IFNULL(NULLIF(TRIM(p_Estado),''),'Deuda'); 
    IF v_Est NOT IN ('Pagado','Deuda') THEN SET v_Est='Deuda'; END IF;
      CALL usp_siguiente_id('COT', 'COTIZACION', 'IDCOTIZACION', v_Id);
    
        START TRANSACTION;
        INSERT INTO COTIZACION (IDCOTIZACION,IDCLIENTE,NOMBRECLIENTE,IDTIPOENTREGA,DIRECCIONENTREGA,COSTODELIVERY,SUBTOTAL,TOTAL,OBSERVACIONES,ESTADO,STOCKRESERVADO,
            CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
        VALUES (v_Id,v_IdCli,v_Nom,p_IdTipoEntrega,p_DireccionEntrega,IFNULL(p_CostoDelivery,0),0,0,p_Observaciones,v_Est,0,
            fn_actor(),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'),fn_actor(),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'));
        CALL usp_cotizacion_guardar_detalle(v_Id, p_DetalleJson);
        CALL usp_stock_desde_detalle(v_Id, -1);
        UPDATE COTIZACION SET STOCKRESERVADO=1 WHERE IDCOTIZACION=v_Id;
        IF IFNULL(p_MontoInicial,0) > 0 THEN
                      
            CALL usp_cotizacion_pago_insertar(v_Id, p_MontoInicial, 'Inicial', p_IdFormaPago, v_RPago, v_MPago);
            IF IFNULL(v_RPago,0)=0 THEN
                            ROLLBACK;
                SET p_Resultado=0; SET p_Mensaje=v_MPago; LEAVE main;
            END IF;
        ELSE
            CALL usp_cotizacion_pago_recalcular(v_Id);
    END IF;
        COMMIT;
        SET p_IdOut=v_Id;
        SET p_Resultado=1; SET p_Mensaje='Cotización registrada.';
END$$

DELIMITER ;

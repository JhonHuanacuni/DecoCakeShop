-- Convertido desde db_scripts/16_08_2026/8.cotizacion_pagos.sql
-- MySQL 8 — DecoCake Shop

USE `DecoCakeShop`;

/* Incremental: estados de cotización + pagos/abonos */

-- create if missing COTIZACION_PAGO
BEGIN
    CREATE TABLE IF NOT EXISTS COTIZACION_PAGO (
        IDPAGO              VARCHAR(50)    NOT NULL PRIMARY KEY,
        IDCOTIZACION VARCHAR(50) NOT NULL,
    FOREIGN KEY (IDCOTIZACION) REFERENCES COTIZACION(IDCOTIZACION),
        MONTO               DECIMAL(12,2)   NOT NULL,
        TIPO                VARCHAR(50)    NOT NULL DEFAULT 'Abono',
        CREADOPOR           VARCHAR(50)    NULL,
        FECHACREACION       CHAR(8)         NULL,
        HORACREACION        CHAR(8)         NULL,
        MODIFICADOPOR       VARCHAR(50)    NULL,
        FECHAMODIFICACION   CHAR(8)         NULL,
        HORAMODIFICACION    CHAR(8)         NULL
    );
END

UPDATE COTIZACION SET ESTADO='Cotizado' WHERE ESTADO IN ('Aceptado','Aceptada','Borrador');
UPDATE COTIZACION SET ESTADO='Enviado' WHERE ESTADO IN ('Enviada');

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
    IF v_Estado IN ('Empaquetado','Enviado','Anulada','Convertida') THEN LEAVE main; END IF;
    SELECT IFNULL(SUM(MONTO),0) INTO v_Pagado FROM COTIZACION_PAGO WHERE IDCOTIZACION=p_Id;
    IF v_Pagado >= v_Total AND v_Total > 0 THEN SET v_Estado='Pagado'; END IF;
    ELSE IF v_Pagado > 0 THEN SET v_Estado='Deuda'; END IF;
    ELSE LEAVE main;
    UPDATE COTIZACION SET ESTADO=v_Estado,
        MODIFICADOPOR=fn_actor(), FECHAMODIFICACION=fn_fecha_ddmmyyyy(), HORAMODIFICACION=TIME_FORMAT(NOW(), '%H:%i:%s')
    WHERE IDCOTIZACION=p_Id;
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS usp_cotizacion_pago_listar;

DROP PROCEDURE IF EXISTS usp_cotizacion_pago_listar;

DELIMITER $$

CREATE PROCEDURE usp_cotizacion_pago_listar(
    IN p_Id VARCHAR(50)
)
main: BEGIN
SELECT p.IDPAGO, p.IDCOTIZACION, p.MONTO, p.TIPO,
           p.CREADOPOR,
           CONCAT(IFNULL(NULLIF(TRIM(IFNULL(cu.NOMBRE,''), ' ', IFNULL(cu.APELLIDO,''))), ''), p.CREADOPOR) AS CREADOPOR_NOMBRE,
           p.FECHACREACION, p.HORACREACION,
           p.MODIFICADOPOR,
           CONCAT(IFNULL(NULLIF(TRIM(IFNULL(mu.NOMBRE,''), ' ', IFNULL(mu.APELLIDO,''))), ''), p.MODIFICADOPOR) AS MODIFICADOPOR_NOMBRE,
           p.FECHAMODIFICACION, p.HORAMODIFICACION
    FROM COTIZACION_PAGO p
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
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
DECLARE v_Total DECIMAL(12,2);
    DECLARE v_Pagado DECIMAL(12,2);
    DECLARE v_Saldo DECIMAL(12,2);
    DECLARE v_IdPago VARCHAR(50);
    IF NOT EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=p_Id) THEN SET p_Resultado=0; SET p_Mensaje='La cotización no existe.'; LEAVE main; END IF;
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=p_Id AND ESTADO IN ('Anulada','Convertida')) THEN SET p_Resultado=0; SET p_Mensaje='No se puede registrar un abono en una cotización anulada o convertida.'; LEAVE main; END IF;
    IF IFNULL(p_Monto,0) <= 0 THEN SET p_Resultado=0; SET p_Mensaje='El monto del abono debe ser mayor a cero.'; LEAVE main; END IF;
       
    SELECT IFNULL(TOTAL,0) INTO v_Total FROM COTIZACION WHERE IDCOTIZACION=p_Id;
    SELECT IFNULL(SUM(MONTO),0) INTO v_Pagado FROM COTIZACION_PAGO WHERE IDCOTIZACION=p_Id;
    SET v_Saldo = v_Total - v_Pagado;
    IF p_Monto > v_Saldo + 0.009 THEN SET p_Resultado=0; SET p_Mensaje='El abono no puede ser mayor al saldo pendiente.'; LEAVE main; END IF; THEN
     
    CALL usp_siguiente_id('PAG', 'COTIZACION_PAGO', 'IDPAGO', v_IdPago);
    INSERT INTO COTIZACION_PAGO (IDPAGO,IDCOTIZACION,MONTO,TIPO,
        CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
    VALUES (v_IdPago,p_Id,p_Monto,IFNULL(NULLIF(TRIM(p_Tipo),''),'Abono'),
        fn_actor(),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'),
        fn_actor(),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'));
    CALL usp_cotizacion_pago_recalcular(p_Id);
    SET p_Resultado=1; SET p_Mensaje='Abono registrado.';
END$$

DELIMITER ;

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
SELECT COUNT(*) INTO p_TotalRegistros
    FROM COTIZACION q
    LEFT JOIN CLIENTE c ON c.IDCLIENTE=q.IDCLIENTE
    WHERE (p_Buscar IS NULL OR p_Buscar='' OR q.IDCOTIZACION LIKE CONCAT('%', p_Buscar, '%')
           OR IFNULL(c.NOMBRE,q.NOMBRECLIENTE) LIKE CONCAT('%', p_Buscar, '%'))
      AND (p_Estado IS NULL OR p_Estado='' OR q.ESTADO=p_Estado);

    SELECT q.IDCOTIZACION, q.IDCLIENTE, IFNULL(c.NOMBRE, q.NOMBRECLIENTE) AS CLIENTE_NOMBRE, q.NOMBRECLIENTE,
           q.IDTIPOENTREGA, t.NOMBRE AS TIPOENTREGA_NOMBRE,
           q.DIRECCIONENTREGA, q.COSTODELIVERY, q.SUBTOTAL, q.TOTAL, q.ESTADO, q.IDVENTA,
           IFNULL(pay.ABONADO,0) AS ABONADO, q.TOTAL - IFNULL(pay.ABONADO,0) AS SALDO,
           q.FECHACREACION AS FECHA, q.HORACREACION AS HORA,
           q.CREADOPOR, TRIM(CONCAT(IFNULL(cu.NOMBRE,''), ' ', IFNULL(cu.APELLIDO,''))) AS CREADOPOR_NOMBRE,
           q.ENVIADOPOR, TRIM(CONCAT(IFNULL(eu.NOMBRE,''), ' ', IFNULL(eu.APELLIDO,''))) AS ENVIADOPOR_NOMBRE,
           q.FECHAENVIO, q.HORAENVIO,
           q.MODIFICADOPOR, q.FECHAMODIFICACION, q.HORAMODIFICACION
    FROM COTIZACION q
    LEFT JOIN CLIENTE c ON c.IDCLIENTE=q.IDCLIENTE
    LEFT JOIN TIPO_ENTREGA t ON t.IDTIPOENTREGA=q.IDTIPOENTREGA
    LEFT JOIN USUARIO cu ON cu.IDUSUARIO=q.CREADOPOR
    LEFT JOIN USUARIO eu ON eu.IDUSUARIO=q.ENVIADOPOR
    LEFT JOIN (SELECT IDCOTIZACION, SUM(MONTO) AS ABONADO FROM COTIZACION_PAGO GROUP BY IDCOTIZACION) pay ON pay.IDCOTIZACION = q.IDCOTIZACION
    WHERE (p_Buscar IS NULL OR p_Buscar='' OR q.IDCOTIZACION LIKE CONCAT('%', p_Buscar, '%')
           OR IFNULL(c.NOMBRE,q.NOMBRECLIENTE) LIKE CONCAT('%', p_Buscar, '%'))
      AND (p_Estado IS NULL OR p_Estado='' OR q.ESTADO=p_Estado)
    ORDER BY q.FECHACREACION DESC, q.HORACREACION DESC, q.IDCOTIZACION DESC
    LIMIT p_TamanioPagina OFFSET ((p_Pagina - 1) * p_TamanioPagina);
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
           q.FECHACREACION AS FECHA, q.HORACREACION AS HORA,
           IFNULL(pay.ABONADO,0) AS ABONADO, q.TOTAL - IFNULL(pay.ABONADO,0) AS SALDO
    FROM COTIZACION q
    LEFT JOIN CLIENTE c ON c.IDCLIENTE=q.IDCLIENTE
    LEFT JOIN TIPO_ENTREGA t ON t.IDTIPOENTREGA=q.IDTIPOENTREGA
    LEFT JOIN (SELECT IDCOTIZACION, SUM(MONTO) AS ABONADO FROM COTIZACION_PAGO GROUP BY IDCOTIZACION) pay ON pay.IDCOTIZACION = q.IDCOTIZACION
    WHERE q.IDCOTIZACION=p_Id;
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
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
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
    SET v_IdCli = NULLIF(TRIM(IFNULL(p_IdCliente,'')), ''); 
    SET v_Nom = NULLIF(TRIM(IFNULL(p_NombreCliente,'')), ''); 
    IF v_IdCli IS NOT NULL AND EXISTS (SELECT 1 FROM CLIENTE WHERE IDCLIENTE=v_IdCli)
        SELECT IFNULL(v_Nom, NOMBRE) INTO v_Nom FROM CLIENTE WHERE IDCLIENTE=v_IdCli;
    ELSE
        SET v_IdCli = NULL;
    IF v_Nom IS NULL THEN SET p_Resultado=0; SET p_Mensaje='Ingresa el cliente.'; LEAVE main; END IF;
    IF p_DetalleJson IS NULL OR CHAR_LENGTH(p_DetalleJson)<3 THEN SET p_Resultado=0; SET p_Mensaje='Agrega al menos un producto.'; LEAVE main; END IF; THEN
      
    CALL usp_stock_check_json(p_DetalleJson, v_Ok, v_Msg);
    IF v_Ok=0 THEN SET p_Resultado=0; SET p_Mensaje=v_Msg; LEAVE main; END IF;
     
    IF IFNULL(p_MontoInicial,0) < 0 THEN SET p_Resultado=0; SET p_Mensaje='El monto inicial no puede ser negativo.'; LEAVE main; END IF;
    IF IFNULL(p_MontoInicial,0) > v_TotalEst + 0.009 THEN SET p_Resultado=0; SET p_Mensaje='El monto inicial no puede ser mayor al total.'; LEAVE main; END IF;
    SET v_Est = IFNULL(NULLIF(TRIM(p_Estado),''),'Cotizado'); 
    IF v_Est IN ('Aceptado','Aceptada','Borrador') THEN SET v_Est='Cotizado'; END IF;
    IF v_Est='Enviada' THEN SET v_Est='Enviado'; END IF;
    IF v_Est NOT IN ('Cotizado','Pagado','Deuda','Empaquetado','Enviado') THEN SET v_Est='Cotizado'; END IF; THEN
      CALL usp_siguiente_id('COT', 'COTIZACION', 'IDCOTIZACION', v_Id);
    BEGIN TRY
        BEGIN TRAN;
        INSERT INTO COTIZACION (IDCOTIZACION,IDCLIENTE,NOMBRECLIENTE,IDTIPOENTREGA,DIRECCIONENTREGA,COSTODELIVERY,SUBTOTAL,TOTAL,OBSERVACIONES,ESTADO,STOCKRESERVADO,
            CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
        VALUES (v_Id,v_IdCli,v_Nom,p_IdTipoEntrega,p_DireccionEntrega,IFNULL(p_CostoDelivery,0),0,0,p_Observaciones,v_Est,0,
            fn_actor(),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'),fn_actor(),fn_fecha_ddmmyyyy(),TIME_FORMAT(NOW(), '%H:%i:%s'));
        CALL usp_cotizacion_guardar_detalle(v_Id, p_DetalleJson);
        CALL usp_stock_desde_detalle(v_Id, -1);
        UPDATE COTIZACION SET STOCKRESERVADO=1 WHERE IDCOTIZACION=v_Id;
        IF IFNULL(p_MontoInicial,0) > 0 THEN
                      
            CALL usp_cotizacion_pago_insertar(v_Id, p_MontoInicial, 'Inicial', NULL, v_RPago, v_MPago);
            IF IFNULL(v_RPago,0)=0 THEN
                            ROLLBACK TRAN;
                SET p_Resultado=0; SET p_Mensaje=v_MPago; LEAVE main;
            END IF;
        END
        COMMIT TRAN;
        SET p_Resultado=1; SET p_Mensaje='Cotización registrada.';
    END TRY
    BEGIN CATCH
        ROLLBACK;
        SET p_Resultado=0; SET p_Mensaje=LEFT(ERROR_MESSAGE(),200);
    END CATCH
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
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=p_Id AND ESTADO IN ('Convertida','Anulada')) THEN SET p_Resultado=0; SET p_Mensaje='No se puede editar una cotización convertida o anulada.'; LEAVE main; END IF;
    SET v_IdCli = NULLIF(TRIM(IFNULL(p_IdCliente,'')), ''); 
    SET v_Nom = NULLIF(TRIM(IFNULL(p_NombreCliente,'')), ''); 
    IF v_IdCli IS NOT NULL AND EXISTS (SELECT 1 FROM CLIENTE WHERE IDCLIENTE=v_IdCli)
        SELECT IFNULL(v_Nom, NOMBRE) INTO v_Nom FROM CLIENTE WHERE IDCLIENTE=v_IdCli;
    ELSE
        SET v_IdCli = NULL;
    IF v_Nom IS NULL THEN SET p_Resultado=0; SET p_Mensaje='Ingresa el cliente.'; LEAVE main; END IF;
    SET v_Est = IFNULL(NULLIF(TRIM(p_Estado),''),'Cotizado'); 
    IF v_Est IN ('Aceptado','Aceptada','Borrador') THEN SET v_Est='Cotizado'; END IF;
    IF v_Est='Enviada' THEN SET v_Est='Enviado'; END IF;
    IF v_Est NOT IN ('Cotizado','Pagado','Deuda','Empaquetado','Enviado') THEN SET v_Est='Cotizado'; END IF;
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

DROP PROCEDURE IF EXISTS usp_cotizacion_eliminar;

DROP PROCEDURE IF EXISTS usp_cotizacion_eliminar;

DELIMITER $$

CREATE PROCEDURE usp_cotizacion_eliminar(
    IN p_Id VARCHAR(50),
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
IF NOT EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=p_Id AND ESTADO='Anulada') THEN SET p_Resultado=0; SET p_Mensaje='Solo se puede eliminar una cotización anulada.'; LEAVE main; END IF;
    DELETE FROM COTIZACION_PAGO WHERE IDCOTIZACION=p_Id;
    DELETE FROM COTIZACION_DETALLE WHERE IDCOTIZACION=p_Id;
    DELETE FROM COTIZACION WHERE IDCOTIZACION=p_Id;
    SET p_Resultado=1; SET p_Mensaje='Cotización eliminada.';
END$$

DELIMITER ;

-- triggers COTIZACION_PAGO.IDPAGO: python scripts/install_auditoria_triggers.py

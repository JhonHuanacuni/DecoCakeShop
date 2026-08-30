-- Convertido desde db_scripts/16_08_2026/9.envio_y_pedidos.sql
-- MySQL 8 — DecoCake Shop

USE `DecoCakeShop`;

/* Incremental: envío en cotización + estados Deuda/Pagado + pedido Pendiente */

ALTER TABLE COTIZACION ADD COLUMN IDFORMAPAGO VARCHAR(50) NULL;

-- FK ya existe o se ignora (1826)

UPDATE COTIZACION
SET ESTADO = 'Deuda'
WHERE ESTADO IN ('Cotizado','Aceptado','Aceptada','Borrador','Empaquetado','Enviado','Enviada');

UPDATE VENTA
SET ESTADO = 'Pendiente'
WHERE ESTADO IN ('Pagado','Pago');

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
    IF v_Estado IN ('Anulada','Convertida') THEN LEAVE main; END IF;
    SELECT IFNULL(SUM(MONTO),0) INTO v_Pagado FROM COTIZACION_PAGO WHERE IDCOTIZACION=p_Id;
    IF v_Pagado >= v_Total AND v_Total > 0 THEN SET v_Estado='Pagado'; END IF;
    ELSE SET v_Estado='Deuda';
    UPDATE COTIZACION SET ESTADO=v_Estado,
        MODIFICADOPOR=fn_actor(), FECHAMODIFICACION=fn_fecha_ddmmyyyy(), HORAMODIFICACION=TIME_FORMAT(NOW(), '%H:%i:%s')
    WHERE IDCOTIZACION=p_Id;
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
DECLARE v_offset INT DEFAULT 0;
    SELECT COUNT(*) INTO p_TotalRegistros
    FROM COTIZACION q
    LEFT JOIN CLIENTE c ON c.IDCLIENTE=q.IDCLIENTE
    WHERE (p_Buscar IS NULL OR p_Buscar='' OR q.IDCOTIZACION LIKE CONCAT('%', p_Buscar, '%')
           OR IFNULL(c.NOMBRE,q.NOMBRECLIENTE) LIKE CONCAT('%', p_Buscar, '%'))
      AND (p_Estado IS NULL OR p_Estado='' OR q.ESTADO=p_Estado);

    SET v_offset = (p_Pagina - 1) * p_TamanioPagina;
    SELECT q.IDCOTIZACION, q.IDCLIENTE, IFNULL(c.NOMBRE, q.NOMBRECLIENTE) AS CLIENTE_NOMBRE, q.NOMBRECLIENTE,
           q.IDFORMAPAGO, q.IDTIPOENTREGA, t.NOMBRE AS TIPOENTREGA_NOMBRE,
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
    LIMIT p_TamanioPagina OFFSET v_offset;
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
    IF p_DetalleJson IS NULL OR CHAR_LENGTH(p_DetalleJson)<3 THEN SET p_Resultado=0; SET p_Mensaje='Agrega al menos un producto.'; LEAVE main; END IF; THEN
      
    CALL usp_stock_check_json(p_DetalleJson, v_Ok, v_Msg);
    IF v_Ok=0 THEN SET p_Resultado=0; SET p_Mensaje=v_Msg; LEAVE main; END IF;
     
    IF IFNULL(p_MontoInicial,0) < 0 THEN SET p_Resultado=0; SET p_Mensaje='El monto inicial no puede ser negativo.'; LEAVE main; END IF;
    IF IFNULL(p_MontoInicial,0) > v_TotalEst + 0.009 THEN SET p_Resultado=0; SET p_Mensaje='El monto inicial no puede ser mayor al total.'; LEAVE main; END IF;
    SET v_Est = IFNULL(NULLIF(TRIM(p_Estado),''),'Deuda'); 
    IF v_Est NOT IN ('Pagado','Deuda') THEN SET v_Est='Deuda'; END IF; THEN
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
        ELSE
            CALL usp_cotizacion_pago_recalcular(v_Id);
        COMMIT TRAN;
        SET p_IdOut=v_Id;
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
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=p_Id AND ESTADO IN ('Convertida','Anulada')) THEN SET p_Resultado=0; SET p_Mensaje='No se puede guardar el envío de una cotización convertida o anulada.'; LEAVE main; END IF;
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
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=p_Id AND ESTADO IN ('Convertida','Anulada')) THEN SET p_Resultado=0; SET p_Mensaje='La cotización ya fue convertida o está anulada.'; LEAVE main; END IF;
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

    UPDATE COTIZACION SET ESTADO='Convertida', IDVENTA=v_IdVenta,
        IDFORMAPAGO=v_Forma, IDTIPOENTREGA=v_Tipo, DIRECCIONENTREGA=v_Dir, COSTODELIVERY=v_Costo,
        TOTAL=v_Sub + v_Costo,
        ENVIADOPOR=fn_actor(), FECHAENVIO=fn_fecha_ddmmyyyy(), HORAENVIO=TIME_FORMAT(NOW(), '%H:%i:%s'),
        MODIFICADOPOR=fn_actor(), FECHAMODIFICACION=fn_fecha_ddmmyyyy(), HORAMODIFICACION=TIME_FORMAT(NOW(), '%H:%i:%s')
    WHERE IDCOTIZACION=p_Id;

    SET p_Resultado=1; SET p_Mensaje=CONCAT('Pedido generado. ', v_IdVenta, '.');
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
DECLARE v_Est VARCHAR(50);
    DECLARE v_Id VARCHAR(50);
    IF p_IdCliente IS NULL THEN SET p_Resultado=0; SET p_Mensaje='Selecciona un cliente.'; LEAVE main; END IF;
    SET v_Est = IFNULL(NULLIF(TRIM(p_Estado),''),'Pendiente'); 
    IF v_Est NOT IN ('Pendiente','Empaquetado','Enviado') THEN SET v_Est='Pendiente'; END IF; THEN
      CALL usp_siguiente_id('VEN', 'VENTA', 'IDVENTA', v_Id);
    INSERT INTO VENTA (IDVENTA,IDCLIENTE,IDFORMAPAGO,IDTIPOENTREGA,DIRECCIONENTREGA,COSTODELIVERY,SUBTOTAL,TOTAL,OBSERVACIONES,ESTADO,
        CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
    VALUES (v_Id,p_IdCliente,p_IdFormaPago,p_IdTipoEntrega,p_DireccionEntrega,IFNULL(p_CostoDelivery,0),0,0,p_Observaciones,v_Est,
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
    OUT p_Resultado INT,
    OUT p_Mensaje VARCHAR(200)
)
main: BEGIN
DECLARE v_Est VARCHAR(50);
    IF NOT EXISTS (SELECT 1 FROM VENTA WHERE IDVENTA=p_Id) THEN SET p_Resultado=0; SET p_Mensaje='El pedido no existe.'; LEAVE main; END IF;
    IF EXISTS (SELECT 1 FROM VENTA WHERE IDVENTA=p_Id AND ESTADO='Anulado') THEN SET p_Resultado=0; SET p_Mensaje='No se puede editar un pedido anulado.'; LEAVE main; END IF;
    SET v_Est = IFNULL(NULLIF(TRIM(p_Estado),''),'Pendiente'); 
    IF v_Est NOT IN ('Pendiente','Empaquetado','Enviado') THEN SET v_Est='Pendiente'; END IF;
    UPDATE VENTA SET IDCLIENTE=p_IdCliente, IDFORMAPAGO=p_IdFormaPago, IDTIPOENTREGA=p_IdTipoEntrega,
        DIRECCIONENTREGA=p_DireccionEntrega, COSTODELIVERY=IFNULL(p_CostoDelivery,0), OBSERVACIONES=p_Observaciones, ESTADO=v_Est,
        MODIFICADOPOR=fn_actor(), FECHAMODIFICACION=fn_fecha_ddmmyyyy(), HORAMODIFICACION=TIME_FORMAT(NOW(), '%H:%i:%s')
    WHERE IDVENTA=p_Id;
    IF p_DetalleJson IS NOT NULL THEN
        CALL usp_venta_guardar_detalle(p_Id, p_DetalleJson); END IF;
    SET p_Resultado=1; SET p_Mensaje='Pedido actualizado.';
END$$

DELIMITER ;

/* Incremental: cotización solo Deuda/Pagado (sin estado Convertida) */
SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON;
GO

UPDATE c
SET c.ESTADO = CASE
    WHEN ISNULL(pay.ABONADO, 0) >= ISNULL(c.TOTAL, 0) AND ISNULL(c.TOTAL, 0) > 0 THEN N'Pagado'
    ELSE N'Deuda'
END
FROM dbo.COTIZACION c
OUTER APPLY (SELECT SUM(MONTO) AS ABONADO FROM dbo.COTIZACION_PAGO WHERE IDCOTIZACION = c.IDCOTIZACION) pay
WHERE c.ESTADO = N'Convertida';
GO

IF OBJECT_ID('dbo.usp_cotizacion_pago_recalcular','P') IS NOT NULL DROP PROCEDURE dbo.usp_cotizacion_pago_recalcular;
GO
CREATE PROCEDURE dbo.usp_cotizacion_pago_recalcular @Id NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Total DECIMAL(12,2), @Pagado DECIMAL(12,2), @Estado NVARCHAR(50);
    SELECT @Total=ISNULL(TOTAL,0), @Estado=ESTADO FROM COTIZACION WHERE IDCOTIZACION=@Id;
    IF @Estado IS NULL RETURN;
    IF @Estado = 'Anulada' RETURN;
    SELECT @Pagado=ISNULL(SUM(MONTO),0) FROM COTIZACION_PAGO WHERE IDCOTIZACION=@Id;
    IF @Pagado >= @Total AND @Total > 0 SET @Estado='Pagado';
    ELSE SET @Estado='Deuda';
    UPDATE COTIZACION SET ESTADO=@Estado,
        MODIFICADOPOR=dbo.fn_actor(), FECHAMODIFICACION=dbo.fn_fecha_ddmmyyyy(), HORAMODIFICACION=CONVERT(CHAR(8),GETDATE(),108)
    WHERE IDCOTIZACION=@Id;
END;
GO

IF OBJECT_ID('dbo.usp_cotizacion_pago_insertar','P') IS NOT NULL DROP PROCEDURE dbo.usp_cotizacion_pago_insertar;
GO
CREATE PROCEDURE dbo.usp_cotizacion_pago_insertar
    @Id NVARCHAR(50), @Monto DECIMAL(12,2), @Tipo NVARCHAR(50)='Abono', @IdFormaPago NVARCHAR(50)=NULL,
    @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=@Id)
    BEGIN SET @Resultado=0; SET @Mensaje='La cotización no existe.'; RETURN; END
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=@Id AND ESTADO='Anulada')
    BEGIN SET @Resultado=0; SET @Mensaje='No se puede registrar un abono en una cotización anulada.'; RETURN; END
    IF ISNULL(@Monto,0) <= 0
    BEGIN SET @Resultado=0; SET @Mensaje='El monto del abono debe ser mayor a cero.'; RETURN; END
    DECLARE @Forma NVARCHAR(50) = NULLIF(LTRIM(RTRIM(ISNULL(@IdFormaPago,''))), '');
    IF @Forma IS NULL OR NOT EXISTS (SELECT 1 FROM FORMA_PAGO WHERE IDFORMAPAGO=@Forma AND ESTADO='Activo')
    BEGIN SET @Resultado=0; SET @Mensaje='Selecciona el método de pago.'; RETURN; END
    DECLARE @Total DECIMAL(12,2), @Pagado DECIMAL(12,2), @Saldo DECIMAL(12,2);
    SELECT @Total=ISNULL(TOTAL,0) FROM COTIZACION WHERE IDCOTIZACION=@Id;
    SELECT @Pagado=ISNULL(SUM(MONTO),0) FROM COTIZACION_PAGO WHERE IDCOTIZACION=@Id;
    SET @Saldo = @Total - @Pagado;
    IF @Monto > @Saldo + 0.009
    BEGIN SET @Resultado=0; SET @Mensaje='El abono no puede ser mayor al saldo pendiente.'; RETURN; END
    DECLARE @IdPago NVARCHAR(50);
    EXEC dbo.usp_siguiente_id 'PAG','COTIZACION_PAGO','IDPAGO',@IdPago OUTPUT;
    INSERT INTO COTIZACION_PAGO (IDPAGO,IDCOTIZACION,MONTO,TIPO,IDFORMAPAGO,
        CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
    VALUES (@IdPago,@Id,@Monto,ISNULL(NULLIF(LTRIM(RTRIM(@Tipo)),''),'Abono'),@Forma,
        dbo.fn_actor(),dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108),
        dbo.fn_actor(),dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108));
    EXEC dbo.usp_cotizacion_pago_recalcular @Id;
    SET @Resultado=1; SET @Mensaje='Abono registrado.';
END;
GO

IF OBJECT_ID('dbo.usp_cotizacion_actualizar','P') IS NOT NULL DROP PROCEDURE dbo.usp_cotizacion_actualizar;
GO
CREATE PROCEDURE dbo.usp_cotizacion_actualizar
    @Id NVARCHAR(50), @IdCliente NVARCHAR(50)=NULL, @NombreCliente NVARCHAR(200)=NULL, @IdTipoEntrega NVARCHAR(50)=NULL,
    @DireccionEntrega NVARCHAR(255)=NULL, @CostoDelivery DECIMAL(12,2)=0, @Observaciones NVARCHAR(MAX)=NULL,
    @Estado NVARCHAR(50)='Deuda', @DetalleJson NVARCHAR(MAX)=NULL,
    @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=@Id) BEGIN SET @Resultado=0; SET @Mensaje='La cotización no existe.'; RETURN; END
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=@Id AND ESTADO='Anulada')
    BEGIN SET @Resultado=0; SET @Mensaje='No se puede editar una cotización anulada.'; RETURN; END
    DECLARE @IdCli NVARCHAR(50) = NULLIF(LTRIM(RTRIM(ISNULL(@IdCliente,''))), '');
    DECLARE @Nom NVARCHAR(200) = NULLIF(LTRIM(RTRIM(ISNULL(@NombreCliente,''))), '');
    IF @IdCli IS NOT NULL AND EXISTS (SELECT 1 FROM CLIENTE WHERE IDCLIENTE=@IdCli)
        SELECT @Nom = ISNULL(@Nom, NOMBRE) FROM CLIENTE WHERE IDCLIENTE=@IdCli;
    ELSE
        SET @IdCli = NULL;
    IF @Nom IS NULL BEGIN SET @Resultado=0; SET @Mensaje='Ingresa el cliente.'; RETURN; END
    DECLARE @Est NVARCHAR(50) = ISNULL(NULLIF(LTRIM(RTRIM(@Estado)),''),'Deuda');
    IF @Est NOT IN ('Pagado','Deuda') SET @Est='Deuda';
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=@Id AND STOCKRESERVADO=1)
        EXEC dbo.usp_stock_desde_detalle @Id, 1;
    IF @DetalleJson IS NOT NULL
    BEGIN
        DECLARE @Ok BIT, @Msg NVARCHAR(200);
        EXEC dbo.usp_stock_check_json @DetalleJson, @Ok OUTPUT, @Msg OUTPUT;
        IF @Ok=0
        BEGIN
            IF EXISTS (SELECT 1 FROM COTIZACION_DETALLE WHERE IDCOTIZACION=@Id)
                EXEC dbo.usp_stock_desde_detalle @Id, -1;
            SET @Resultado=0; SET @Mensaje=@Msg; RETURN;
        END
    END
    UPDATE COTIZACION SET IDCLIENTE=@IdCli, NOMBRECLIENTE=@Nom, IDTIPOENTREGA=@IdTipoEntrega, DIRECCIONENTREGA=@DireccionEntrega,
        COSTODELIVERY=ISNULL(@CostoDelivery,0), OBSERVACIONES=@Observaciones, ESTADO=@Est, STOCKRESERVADO=0,
        MODIFICADOPOR=dbo.fn_actor(), FECHAMODIFICACION=dbo.fn_fecha_ddmmyyyy(), HORAMODIFICACION=CONVERT(CHAR(8),GETDATE(),108)
    WHERE IDCOTIZACION=@Id;
    IF @DetalleJson IS NOT NULL
        EXEC dbo.usp_cotizacion_guardar_detalle @Id, @DetalleJson;
    EXEC dbo.usp_stock_desde_detalle @Id, -1;
    UPDATE COTIZACION SET STOCKRESERVADO=1 WHERE IDCOTIZACION=@Id;
    EXEC dbo.usp_cotizacion_pago_recalcular @Id;
    SET @Resultado=1; SET @Mensaje='Cotización actualizada.';
END;
GO

IF OBJECT_ID('dbo.usp_cotizacion_guardar_envio','P') IS NOT NULL DROP PROCEDURE dbo.usp_cotizacion_guardar_envio;
GO
CREATE PROCEDURE dbo.usp_cotizacion_guardar_envio
    @Id NVARCHAR(50),
    @IdFormaPago NVARCHAR(50)=NULL,
    @IdTipoEntrega NVARCHAR(50)=NULL,
    @DireccionEntrega NVARCHAR(255)=NULL,
    @CostoDelivery DECIMAL(12,2)=0,
    @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=@Id)
    BEGIN SET @Resultado=0; SET @Mensaje='La cotización no existe.'; RETURN; END
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=@Id AND ESTADO='Anulada')
    BEGIN SET @Resultado=0; SET @Mensaje='No se puede guardar el envío de una cotización anulada.'; RETURN; END
    DECLARE @Tipo NVARCHAR(50) = NULLIF(LTRIM(RTRIM(ISNULL(@IdTipoEntrega,''))), '');
    IF @Tipo IS NULL OR NOT EXISTS (SELECT 1 FROM TIPO_ENTREGA WHERE IDTIPOENTREGA=@Tipo AND ESTADO='Activo')
    BEGIN SET @Resultado=0; SET @Mensaje='Selecciona el tipo de entrega.'; RETURN; END
    IF EXISTS (SELECT 1 FROM TIPO_ENTREGA WHERE IDTIPOENTREGA=@Tipo AND REQUIEREDIRECCION=1)
       AND NULLIF(LTRIM(RTRIM(ISNULL(@DireccionEntrega,''))),'') IS NULL
    BEGIN SET @Resultado=0; SET @Mensaje='Ingresa la dirección de delivery.'; RETURN; END
    DECLARE @Sub DECIMAL(12,2);
    SELECT @Sub = ISNULL(SUBTOTAL,0) FROM COTIZACION WHERE IDCOTIZACION=@Id;
    UPDATE COTIZACION SET
        IDFORMAPAGO=NULLIF(LTRIM(RTRIM(ISNULL(@IdFormaPago,''))), ''),
        IDTIPOENTREGA=@Tipo,
        DIRECCIONENTREGA=@DireccionEntrega,
        COSTODELIVERY=ISNULL(@CostoDelivery,0),
        TOTAL=@Sub + ISNULL(@CostoDelivery,0),
        MODIFICADOPOR=dbo.fn_actor(), FECHAMODIFICACION=dbo.fn_fecha_ddmmyyyy(), HORAMODIFICACION=CONVERT(CHAR(8),GETDATE(),108)
    WHERE IDCOTIZACION=@Id;
    EXEC dbo.usp_cotizacion_pago_recalcular @Id;
    SET @Resultado=1; SET @Mensaje='Datos de envío guardados.';
END;
GO

IF OBJECT_ID('dbo.usp_cotizacion_anular','P') IS NOT NULL DROP PROCEDURE dbo.usp_cotizacion_anular;
GO
CREATE PROCEDURE dbo.usp_cotizacion_anular @Id NVARCHAR(50), @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=@Id)
    BEGIN SET @Resultado=0; SET @Mensaje='La cotización no existe.'; RETURN; END
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=@Id AND NULLIF(LTRIM(RTRIM(ISNULL(IDVENTA,''))),'') IS NOT NULL)
    BEGIN SET @Resultado=0; SET @Mensaje='Anula el pedido asociado, no la cotización.'; RETURN; END
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=@Id AND ESTADO='Anulada')
    BEGIN SET @Resultado=0; SET @Mensaje='La cotización ya está anulada.'; RETURN; END
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=@Id AND STOCKRESERVADO=1)
        EXEC dbo.usp_stock_desde_detalle @Id, 1;
    UPDATE COTIZACION SET ESTADO='Anulada', STOCKRESERVADO=0,
        MODIFICADOPOR=dbo.fn_actor(), FECHAMODIFICACION=dbo.fn_fecha_ddmmyyyy(), HORAMODIFICACION=CONVERT(CHAR(8),GETDATE(),108)
    WHERE IDCOTIZACION=@Id;
    SET @Resultado=1; SET @Mensaje='Cotización anulada. El stock volvió al almacén.';
END;
GO

IF OBJECT_ID('dbo.usp_cotizacion_hacer_pedido','P') IS NOT NULL DROP PROCEDURE dbo.usp_cotizacion_hacer_pedido;
GO
CREATE PROCEDURE dbo.usp_cotizacion_hacer_pedido
    @Id NVARCHAR(50),
    @IdFormaPago NVARCHAR(50)=NULL,
    @IdTipoEntrega NVARCHAR(50)=NULL,
    @DireccionEntrega NVARCHAR(255)=NULL,
    @CostoDelivery DECIMAL(12,2)=0,
    @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=@Id)
    BEGIN SET @Resultado=0; SET @Mensaje='La cotización no existe.'; RETURN; END
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=@Id AND ESTADO='Anulada')
    BEGIN SET @Resultado=0; SET @Mensaje='La cotización está anulada.'; RETURN; END
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=@Id AND NULLIF(LTRIM(RTRIM(ISNULL(IDVENTA,''))),'') IS NOT NULL)
    BEGIN SET @Resultado=0; SET @Mensaje='Esta cotización ya tiene un pedido.'; RETURN; END
    IF NOT EXISTS (SELECT 1 FROM COTIZACION_DETALLE WHERE IDCOTIZACION=@Id)
    BEGIN SET @Resultado=0; SET @Mensaje='La cotización no tiene productos.'; RETURN; END

    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=@Id AND ISNULL(STOCKRESERVADO,0)=0)
    BEGIN
        IF EXISTS (
            SELECT 1 FROM COTIZACION_DETALLE d INNER JOIN PRODUCTO p ON p.IDPRODUCTO=d.IDPRODUCTO
            WHERE d.IDCOTIZACION=@Id AND p.STOCK < d.CANTIDAD
        )
        BEGIN SET @Resultado=0; SET @Mensaje='Stock insuficiente para uno o más productos.'; RETURN; END
        EXEC dbo.usp_stock_desde_detalle @Id, -1;
        UPDATE COTIZACION SET STOCKRESERVADO=1 WHERE IDCOTIZACION=@Id;
    END

    DECLARE @Tipo NVARCHAR(50) = NULLIF(LTRIM(RTRIM(ISNULL(@IdTipoEntrega,''))), '');
    DECLARE @Forma NVARCHAR(50) = NULLIF(LTRIM(RTRIM(ISNULL(@IdFormaPago,''))), '');
    DECLARE @Dir NVARCHAR(255) = NULLIF(LTRIM(RTRIM(ISNULL(@DireccionEntrega,''))), '');
    DECLARE @Costo DECIMAL(12,2) = ISNULL(@CostoDelivery,0);
    SELECT
        @Tipo = ISNULL(@Tipo, IDTIPOENTREGA),
        @Forma = ISNULL(@Forma, IDFORMAPAGO),
        @Dir = ISNULL(@Dir, NULLIF(LTRIM(RTRIM(ISNULL(DIRECCIONENTREGA,''))), '')),
        @Costo = CASE WHEN @IdTipoEntrega IS NULL AND @CostoDelivery=0 THEN ISNULL(COSTODELIVERY,0) ELSE @Costo END
    FROM COTIZACION WHERE IDCOTIZACION=@Id;

    IF @Tipo IS NULL OR NOT EXISTS (SELECT 1 FROM TIPO_ENTREGA WHERE IDTIPOENTREGA=@Tipo AND ESTADO='Activo')
    BEGIN SET @Resultado=0; SET @Mensaje='Selecciona el tipo de entrega.'; RETURN; END
    IF EXISTS (SELECT 1 FROM TIPO_ENTREGA WHERE IDTIPOENTREGA=@Tipo AND REQUIEREDIRECCION=1)
       AND @Dir IS NULL
    BEGIN SET @Resultado=0; SET @Mensaje='Ingresa la dirección de delivery.'; RETURN; END

    DECLARE @IdVenta NVARCHAR(50); EXEC dbo.usp_siguiente_id 'VEN','VENTA','IDVENTA',@IdVenta OUTPUT;
    DECLARE @Sub DECIMAL(12,2), @Cli NVARCHAR(50), @Nom NVARCHAR(200), @Obs NVARCHAR(MAX);
    SELECT @Sub = SUBTOTAL, @Cli = IDCLIENTE, @Nom = NOMBRECLIENTE, @Obs = OBSERVACIONES
    FROM COTIZACION WHERE IDCOTIZACION=@Id;

    INSERT INTO VENTA (IDVENTA,IDCOTIZACION,IDCLIENTE,NOMBRECLIENTE,IDFORMAPAGO,IDTIPOENTREGA,DIRECCIONENTREGA,COSTODELIVERY,SUBTOTAL,TOTAL,OBSERVACIONES,ESTADO,
        CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
    VALUES (
        @IdVenta, @Id, @Cli, @Nom, @Forma, @Tipo, @Dir,
        @Costo, @Sub, @Sub + @Costo, @Obs, 'Pendiente',
        dbo.fn_actor(), dbo.fn_fecha_ddmmyyyy(), CONVERT(CHAR(8),GETDATE(),108),
        dbo.fn_actor(), dbo.fn_fecha_ddmmyyyy(), CONVERT(CHAR(8),GETDATE(),108)
    );

    INSERT INTO VENTA_DETALLE (IDDETALLE, IDVENTA, IDPRODUCTO, CANTIDAD, PRECIOUNITARIO, SUBTOTAL)
    SELECT @IdVenta + RIGHT('000'+CAST(ROW_NUMBER() OVER (ORDER BY IDDETALLE) AS VARCHAR(4)), 3),
           @IdVenta, IDPRODUCTO, CANTIDAD, PRECIOUNITARIO, SUBTOTAL
    FROM COTIZACION_DETALLE WHERE IDCOTIZACION=@Id;

    UPDATE COTIZACION SET IDVENTA=@IdVenta,
        IDFORMAPAGO=@Forma, IDTIPOENTREGA=@Tipo, DIRECCIONENTREGA=@Dir, COSTODELIVERY=@Costo,
        TOTAL=@Sub + @Costo,
        ENVIADOPOR=dbo.fn_actor(), FECHAENVIO=dbo.fn_fecha_ddmmyyyy(), HORAENVIO=CONVERT(CHAR(8),GETDATE(),108),
        MODIFICADOPOR=dbo.fn_actor(), FECHAMODIFICACION=dbo.fn_fecha_ddmmyyyy(), HORAMODIFICACION=CONVERT(CHAR(8),GETDATE(),108)
    WHERE IDCOTIZACION=@Id;
    EXEC dbo.usp_cotizacion_pago_recalcular @Id;

    SET @Resultado=1; SET @Mensaje='Pedido generado. '+@IdVenta+'.';
END;
GO

PRINT 'Cotizaciones: solo estados Deuda y Pagado.';
GO

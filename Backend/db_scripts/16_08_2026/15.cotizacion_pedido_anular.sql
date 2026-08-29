/* Incremental: permitir hacer pedido y anular aunque ya exista un pedido */
SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON;
GO

IF OBJECT_ID('dbo.usp_cotizacion_anular','P') IS NOT NULL DROP PROCEDURE dbo.usp_cotizacion_anular;
GO
CREATE PROCEDURE dbo.usp_cotizacion_anular @Id NVARCHAR(50), @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=@Id)
    BEGIN SET @Resultado=0; SET @Mensaje='La cotización no existe.'; RETURN; END
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=@Id AND ESTADO='Anulada')
    BEGIN SET @Resultado=0; SET @Mensaje='La cotización ya está anulada.'; RETURN; END

    DECLARE @IdVenta NVARCHAR(50);
    SELECT @IdVenta = NULLIF(LTRIM(RTRIM(ISNULL(IDVENTA,''))), '') FROM COTIZACION WHERE IDCOTIZACION=@Id;
    IF @IdVenta IS NOT NULL AND EXISTS (SELECT 1 FROM VENTA WHERE IDVENTA=@IdVenta AND ESTADO<>'Anulado')
    BEGIN
        EXEC dbo.usp_venta_anular @Id=@IdVenta, @Resultado=@Resultado OUTPUT, @Mensaje=@Mensaje OUTPUT;
        IF ISNULL(@Resultado,0)=0 RETURN;
        UPDATE COTIZACION SET ESTADO='Anulada', STOCKRESERVADO=0,
            MODIFICADOPOR=dbo.fn_actor(), FECHAMODIFICACION=dbo.fn_fecha_ddmmyyyy(), HORAMODIFICACION=CONVERT(CHAR(8),GETDATE(),108)
        WHERE IDCOTIZACION=@Id;
        SET @Resultado=1; SET @Mensaje='Cotización y pedido asociado anulados. El stock volvió al almacén.';
        RETURN;
    END

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
    IF NOT EXISTS (SELECT 1 FROM COTIZACION_DETALLE WHERE IDCOTIZACION=@Id)
    BEGIN SET @Resultado=0; SET @Mensaje='La cotización no tiene productos.'; RETURN; END

    DECLARE @YaPedido BIT = CASE WHEN EXISTS (
        SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=@Id AND NULLIF(LTRIM(RTRIM(ISNULL(IDVENTA,''))),'') IS NOT NULL
    ) THEN 1 ELSE 0 END;

    IF @YaPedido = 1 OR EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=@Id AND ISNULL(STOCKRESERVADO,0)=0)
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

PRINT 'Hacer pedido y anular habilitados.';
GO

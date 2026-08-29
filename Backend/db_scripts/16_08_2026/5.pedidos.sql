/* Incremental: módulo Pedidos + datos de envío al convertir cotización */
SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON;
GO

UPDATE dbo.MODULO
SET NOMBRE = N'Pedidos', DESCRIPCION = N'Pedidos confirmados con datos de envío'
WHERE IDMODULO = N'MOD005';
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
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=@Id AND ESTADO IN ('Convertida','Anulada'))
    BEGIN SET @Resultado=0; SET @Mensaje='La cotización ya fue convertida o está anulada.'; RETURN; END
    IF NOT EXISTS (SELECT 1 FROM COTIZACION_DETALLE WHERE IDCOTIZACION=@Id)
    BEGIN SET @Resultado=0; SET @Mensaje='La cotización no tiene productos.'; RETURN; END

    DECLARE @Tipo NVARCHAR(50) = NULLIF(LTRIM(RTRIM(ISNULL(@IdTipoEntrega,''))), '');
    IF @Tipo IS NULL OR NOT EXISTS (SELECT 1 FROM TIPO_ENTREGA WHERE IDTIPOENTREGA=@Tipo AND ESTADO='Activo')
    BEGIN SET @Resultado=0; SET @Mensaje='Selecciona el tipo de entrega.'; RETURN; END
    IF EXISTS (SELECT 1 FROM TIPO_ENTREGA WHERE IDTIPOENTREGA=@Tipo AND REQUIEREDIRECCION=1)
       AND NULLIF(LTRIM(RTRIM(ISNULL(@DireccionEntrega,''))),'') IS NULL
    BEGIN SET @Resultado=0; SET @Mensaje='Ingresa la dirección de delivery.'; RETURN; END

    IF EXISTS (
        SELECT 1 FROM COTIZACION_DETALLE d INNER JOIN PRODUCTO p ON p.IDPRODUCTO=d.IDPRODUCTO
        WHERE d.IDCOTIZACION=@Id AND p.STOCK < d.CANTIDAD
    )
    BEGIN SET @Resultado=0; SET @Mensaje='Stock insuficiente para uno o más productos.'; RETURN; END

    DECLARE @IdVenta NVARCHAR(50); EXEC dbo.usp_siguiente_id 'VEN','VENTA','IDVENTA',@IdVenta OUTPUT;
    DECLARE @Sub DECIMAL(12,2), @Cli NVARCHAR(50), @Nom NVARCHAR(200), @Obs NVARCHAR(MAX);
    SELECT @Sub = SUBTOTAL, @Cli = IDCLIENTE, @Nom = NOMBRECLIENTE, @Obs = OBSERVACIONES
    FROM COTIZACION WHERE IDCOTIZACION=@Id;

    INSERT INTO VENTA (IDVENTA,IDCOTIZACION,IDCLIENTE,NOMBRECLIENTE,IDFORMAPAGO,IDTIPOENTREGA,DIRECCIONENTREGA,COSTODELIVERY,SUBTOTAL,TOTAL,OBSERVACIONES,ESTADO,
        CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
    VALUES (
        @IdVenta, @Id, @Cli, @Nom, NULLIF(LTRIM(RTRIM(ISNULL(@IdFormaPago,''))), ''), @Tipo, @DireccionEntrega,
        ISNULL(@CostoDelivery,0), @Sub, @Sub + ISNULL(@CostoDelivery,0), @Obs, 'Pagado',
        dbo.fn_actor(), dbo.fn_fecha_ddmmyyyy(), CONVERT(CHAR(8),GETDATE(),108),
        dbo.fn_actor(), dbo.fn_fecha_ddmmyyyy(), CONVERT(CHAR(8),GETDATE(),108)
    );

    INSERT INTO VENTA_DETALLE (IDDETALLE, IDVENTA, IDPRODUCTO, CANTIDAD, PRECIOUNITARIO, SUBTOTAL)
    SELECT @IdVenta + RIGHT('000'+CAST(ROW_NUMBER() OVER (ORDER BY IDDETALLE) AS VARCHAR(4)), 3),
           @IdVenta, IDPRODUCTO, CANTIDAD, PRECIOUNITARIO, SUBTOTAL
    FROM COTIZACION_DETALLE WHERE IDCOTIZACION=@Id;

    UPDATE p SET p.STOCK = p.STOCK - d.CANTIDAD,
        p.MODIFICADOPOR=dbo.fn_actor(), p.FECHAMODIFICACION=dbo.fn_fecha_ddmmyyyy(), p.HORAMODIFICACION=CONVERT(CHAR(8),GETDATE(),108)
    FROM PRODUCTO p INNER JOIN COTIZACION_DETALLE d ON d.IDPRODUCTO=p.IDPRODUCTO
    WHERE d.IDCOTIZACION=@Id;

    UPDATE COTIZACION SET ESTADO='Convertida', IDVENTA=@IdVenta,
        IDTIPOENTREGA=@Tipo, DIRECCIONENTREGA=@DireccionEntrega, COSTODELIVERY=ISNULL(@CostoDelivery,0),
        TOTAL=@Sub + ISNULL(@CostoDelivery,0),
        MODIFICADOPOR=dbo.fn_actor(), FECHAMODIFICACION=dbo.fn_fecha_ddmmyyyy(), HORAMODIFICACION=CONVERT(CHAR(8),GETDATE(),108)
    WHERE IDCOTIZACION=@Id;

    SET @Resultado=1; SET @Mensaje='Pedido generado. '+@IdVenta+'.';
END;
GO

PRINT 'Pedidos y envío al convertir listos.';
GO

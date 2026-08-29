/* Pedido web: captura de pago en base64 y alta desde la tienda */
SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON;
GO

IF COL_LENGTH('dbo.VENTA', 'COMPROBANTEPAGO') IS NULL
    ALTER TABLE dbo.VENTA ADD COMPROBANTEPAGO NVARCHAR(MAX) NULL;
GO

IF OBJECT_ID('dbo.usp_venta_insertar','P') IS NOT NULL DROP PROCEDURE dbo.usp_venta_insertar;
GO
CREATE PROCEDURE dbo.usp_venta_insertar
    @IdCliente NVARCHAR(50), @IdFormaPago NVARCHAR(50)=NULL, @IdTipoEntrega NVARCHAR(50)=NULL,
    @DireccionEntrega NVARCHAR(255)=NULL, @CostoDelivery DECIMAL(12,2)=0, @Observaciones NVARCHAR(MAX)=NULL,
    @Estado NVARCHAR(50)='Pendiente', @DetalleJson NVARCHAR(MAX)=NULL,
    @ComprobantePago NVARCHAR(MAX)=NULL, @NombreCliente NVARCHAR(200)=NULL,
    @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF @IdCliente IS NULL BEGIN SET @Resultado=0; SET @Mensaje='Selecciona un cliente.'; RETURN; END
    DECLARE @Est NVARCHAR(50) = ISNULL(NULLIF(LTRIM(RTRIM(@Estado)),''),'Pendiente');
    IF @Est NOT IN ('Pendiente','Empaquetado','Enviado') SET @Est='Pendiente';
    DECLARE @Id NVARCHAR(50); EXEC dbo.usp_siguiente_id 'VEN','VENTA','IDVENTA',@Id OUTPUT;
    INSERT INTO VENTA (IDVENTA,IDCLIENTE,NOMBRECLIENTE,IDFORMAPAGO,IDTIPOENTREGA,DIRECCIONENTREGA,COSTODELIVERY,SUBTOTAL,TOTAL,OBSERVACIONES,ESTADO,COMPROBANTEPAGO,
        CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
    VALUES (@Id,@IdCliente,@NombreCliente,@IdFormaPago,@IdTipoEntrega,@DireccionEntrega,ISNULL(@CostoDelivery,0),0,0,@Observaciones,@Est,@ComprobantePago,
        dbo.fn_actor(),dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108),dbo.fn_actor(),dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108));
    IF @DetalleJson IS NOT NULL AND LEN(@DetalleJson)>2
        EXEC dbo.usp_venta_guardar_detalle @Id, @DetalleJson;
    SET @Resultado=1; SET @Mensaje='Pedido registrado.';
END;
GO

IF OBJECT_ID('dbo.usp_venta_actualizar','P') IS NOT NULL DROP PROCEDURE dbo.usp_venta_actualizar;
GO
CREATE PROCEDURE dbo.usp_venta_actualizar
    @Id NVARCHAR(50), @IdCliente NVARCHAR(50), @IdFormaPago NVARCHAR(50)=NULL, @IdTipoEntrega NVARCHAR(50)=NULL,
    @DireccionEntrega NVARCHAR(255)=NULL, @CostoDelivery DECIMAL(12,2)=0, @Observaciones NVARCHAR(MAX)=NULL,
    @Estado NVARCHAR(50)='Pendiente', @DetalleJson NVARCHAR(MAX)=NULL,
    @ComprobantePago NVARCHAR(MAX)=NULL, @NombreCliente NVARCHAR(200)=NULL,
    @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM VENTA WHERE IDVENTA=@Id) BEGIN SET @Resultado=0; SET @Mensaje='El pedido no existe.'; RETURN; END
    IF EXISTS (SELECT 1 FROM VENTA WHERE IDVENTA=@Id AND ESTADO='Anulado')
    BEGIN SET @Resultado=0; SET @Mensaje='No se puede editar un pedido anulado.'; RETURN; END
    DECLARE @Est NVARCHAR(50) = ISNULL(NULLIF(LTRIM(RTRIM(@Estado)),''),'Pendiente');
    IF @Est NOT IN ('Pendiente','Empaquetado','Enviado') SET @Est='Pendiente';
    UPDATE VENTA SET IDCLIENTE=@IdCliente, NOMBRECLIENTE=ISNULL(@NombreCliente,NOMBRECLIENTE),
        IDFORMAPAGO=@IdFormaPago, IDTIPOENTREGA=@IdTipoEntrega,
        DIRECCIONENTREGA=@DireccionEntrega, COSTODELIVERY=ISNULL(@CostoDelivery,0), OBSERVACIONES=@Observaciones, ESTADO=@Est,
        COMPROBANTEPAGO=CASE WHEN @ComprobantePago IS NULL THEN COMPROBANTEPAGO ELSE @ComprobantePago END,
        MODIFICADOPOR=dbo.fn_actor(), FECHAMODIFICACION=dbo.fn_fecha_ddmmyyyy(), HORAMODIFICACION=CONVERT(CHAR(8),GETDATE(),108)
    WHERE IDVENTA=@Id;
    IF @DetalleJson IS NOT NULL
        EXEC dbo.usp_venta_guardar_detalle @Id, @DetalleJson;
    SET @Resultado=1; SET @Mensaje='Pedido actualizado.';
END;
GO

IF OBJECT_ID('dbo.usp_tienda_pedido','P') IS NOT NULL DROP PROCEDURE dbo.usp_tienda_pedido;
GO
CREATE PROCEDURE dbo.usp_tienda_pedido
    @Nombre NVARCHAR(200),
    @Telefono NVARCHAR(20),
    @Email NVARCHAR(150)=NULL,
    @Direccion NVARCHAR(255)=NULL,
    @IdFormaPago NVARCHAR(50),
    @IdTipoEntrega NVARCHAR(50)=NULL,
    @ComprobantePago NVARCHAR(MAX),
    @Observaciones NVARCHAR(MAX)=NULL,
    @DetalleJson NVARCHAR(MAX),
    @Resultado INT OUTPUT,
    @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Nom NVARCHAR(200) = LTRIM(RTRIM(ISNULL(@Nombre,'')));
    DECLARE @Tel NVARCHAR(20) = LTRIM(RTRIM(ISNULL(@Telefono,'')));
    IF @Nom='' BEGIN SET @Resultado=0; SET @Mensaje='Ingresa tu nombre.'; RETURN; END
    IF @Tel='' BEGIN SET @Resultado=0; SET @Mensaje='Ingresa tu teléfono.'; RETURN; END
    IF @IdFormaPago IS NULL OR NOT EXISTS (SELECT 1 FROM FORMA_PAGO WHERE IDFORMAPAGO=@IdFormaPago AND ESTADO='Activo')
    BEGIN SET @Resultado=0; SET @Mensaje='Selecciona un método de pago.'; RETURN; END
    IF @ComprobantePago IS NULL OR LEN(@ComprobantePago) < 40
    BEGIN SET @Resultado=0; SET @Mensaje='Adjunta la captura del pago.'; RETURN; END
    IF @DetalleJson IS NULL OR LEN(@DetalleJson) < 8
    BEGIN SET @Resultado=0; SET @Mensaje='El carrito está vacío.'; RETURN; END
    IF @IdTipoEntrega IS NOT NULL AND EXISTS (SELECT 1 FROM TIPO_ENTREGA WHERE IDTIPOENTREGA=@IdTipoEntrega AND REQUIEREDIRECCION=1)
       AND (LTRIM(RTRIM(ISNULL(@Direccion,'')))='')
    BEGIN SET @Resultado=0; SET @Mensaje='Ingresa la dirección de entrega.'; RETURN; END

    DECLARE @IdCliente NVARCHAR(50);
    SELECT TOP 1 @IdCliente = IDCLIENTE FROM CLIENTE WHERE TELEFONO=@Tel ORDER BY FECHACREACION DESC;
    IF @IdCliente IS NULL
    BEGIN
        EXEC dbo.usp_siguiente_id 'CLI','CLIENTE','IDCLIENTE',@IdCliente OUTPUT;
        INSERT INTO CLIENTE (IDCLIENTE,NOMBRE,TELEFONO,EMAIL,DIRECCION,ESTADO,CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
        VALUES (@IdCliente,@Nom,@Tel,@Email,@Direccion,'Activo',ISNULL(dbo.fn_actor(),'tienda'),dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108),ISNULL(dbo.fn_actor(),'tienda'),dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108));
    END
    ELSE
        UPDATE CLIENTE SET NOMBRE=@Nom, EMAIL=ISNULL(@Email,EMAIL), DIRECCION=ISNULL(NULLIF(LTRIM(RTRIM(@Direccion)),''),DIRECCION),
            MODIFICADOPOR=ISNULL(dbo.fn_actor(),'tienda'), FECHAMODIFICACION=dbo.fn_fecha_ddmmyyyy(), HORAMODIFICACION=CONVERT(CHAR(8),GETDATE(),108)
        WHERE IDCLIENTE=@IdCliente;

    DECLARE @Id NVARCHAR(50); EXEC dbo.usp_siguiente_id 'VEN','VENTA','IDVENTA',@Id OUTPUT;
    INSERT INTO VENTA (IDVENTA,IDCLIENTE,NOMBRECLIENTE,IDFORMAPAGO,IDTIPOENTREGA,DIRECCIONENTREGA,COSTODELIVERY,SUBTOTAL,TOTAL,OBSERVACIONES,ESTADO,COMPROBANTEPAGO,
        CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
    VALUES (@Id,@IdCliente,@Nom,@IdFormaPago,@IdTipoEntrega,@Direccion,0,0,0,@Observaciones,'Pendiente',@ComprobantePago,
        ISNULL(dbo.fn_actor(),'tienda'),dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108),ISNULL(dbo.fn_actor(),'tienda'),dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108));

    EXEC dbo.usp_venta_guardar_detalle @Id, @DetalleJson;
    IF NOT EXISTS (SELECT 1 FROM VENTA_DETALLE WHERE IDVENTA=@Id)
    BEGIN
        DELETE FROM VENTA WHERE IDVENTA=@Id;
        SET @Resultado=0; SET @Mensaje='No se pudieron guardar los productos.'; RETURN;
    END

    SET @Resultado=1; SET @Mensaje='Pedido registrado. '+@Id+'.';
END;
GO

PRINT 'Pedido de tienda con captura de pago listo.';
GO

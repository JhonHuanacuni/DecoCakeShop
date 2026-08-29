/* Incremental: envío en cotización + estados Deuda/Pagado + pedido Pendiente */
SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON;
GO

IF COL_LENGTH('dbo.COTIZACION', 'IDFORMAPAGO') IS NULL
    ALTER TABLE dbo.COTIZACION ADD IDFORMAPAGO NVARCHAR(50) NULL;
GO
IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_COTIZACION_FORMA_PAGO'
)
AND COL_LENGTH('dbo.COTIZACION', 'IDFORMAPAGO') IS NOT NULL
    ALTER TABLE dbo.COTIZACION ADD CONSTRAINT FK_COTIZACION_FORMA_PAGO
        FOREIGN KEY (IDFORMAPAGO) REFERENCES dbo.FORMA_PAGO(IDFORMAPAGO);
GO

UPDATE dbo.COTIZACION
SET ESTADO = 'Deuda'
WHERE ESTADO IN ('Cotizado','Aceptado','Aceptada','Borrador','Empaquetado','Enviado','Enviada');
GO

UPDATE dbo.VENTA
SET ESTADO = 'Pendiente'
WHERE ESTADO IN ('Pagado','Pago');
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
    IF @Estado IN ('Anulada','Convertida') RETURN;
    SELECT @Pagado=ISNULL(SUM(MONTO),0) FROM COTIZACION_PAGO WHERE IDCOTIZACION=@Id;
    IF @Pagado >= @Total AND @Total > 0 SET @Estado='Pagado';
    ELSE SET @Estado='Deuda';
    UPDATE COTIZACION SET ESTADO=@Estado,
        MODIFICADOPOR=dbo.fn_actor(), FECHAMODIFICACION=dbo.fn_fecha_ddmmyyyy(), HORAMODIFICACION=CONVERT(CHAR(8),GETDATE(),108)
    WHERE IDCOTIZACION=@Id;
END;
GO

IF OBJECT_ID('dbo.usp_cotizacion_listar','P') IS NOT NULL DROP PROCEDURE dbo.usp_cotizacion_listar;
GO
CREATE PROCEDURE dbo.usp_cotizacion_listar
    @Buscar NVARCHAR(200)=NULL, @Estado NVARCHAR(50)=NULL, @OrdenarPor NVARCHAR(50)='FECHA',
    @Direccion NVARCHAR(4)='DESC', @Pagina INT=1, @TamanioPagina INT=10, @TotalRegistros INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRegistros = COUNT(*)
    FROM COTIZACION q
    LEFT JOIN CLIENTE c ON c.IDCLIENTE=q.IDCLIENTE
    WHERE (@Buscar IS NULL OR @Buscar='' OR q.IDCOTIZACION LIKE '%'+@Buscar+'%'
           OR ISNULL(c.NOMBRE,q.NOMBRECLIENTE) LIKE '%'+@Buscar+'%')
      AND (@Estado IS NULL OR @Estado='' OR q.ESTADO=@Estado);

    SELECT q.IDCOTIZACION, q.IDCLIENTE, ISNULL(c.NOMBRE, q.NOMBRECLIENTE) AS CLIENTE_NOMBRE, q.NOMBRECLIENTE,
           q.IDFORMAPAGO, q.IDTIPOENTREGA, t.NOMBRE AS TIPOENTREGA_NOMBRE,
           q.DIRECCIONENTREGA, q.COSTODELIVERY, q.SUBTOTAL, q.TOTAL, q.ESTADO, q.IDVENTA,
           ISNULL(pay.ABONADO,0) AS ABONADO, q.TOTAL - ISNULL(pay.ABONADO,0) AS SALDO,
           q.FECHACREACION AS FECHA, q.HORACREACION AS HORA,
           q.CREADOPOR, LTRIM(RTRIM(ISNULL(cu.NOMBRE,'')+' '+ISNULL(cu.APELLIDO,''))) AS CREADOPOR_NOMBRE,
           q.ENVIADOPOR, LTRIM(RTRIM(ISNULL(eu.NOMBRE,'')+' '+ISNULL(eu.APELLIDO,''))) AS ENVIADOPOR_NOMBRE,
           q.FECHAENVIO, q.HORAENVIO,
           q.MODIFICADOPOR, q.FECHAMODIFICACION, q.HORAMODIFICACION
    FROM COTIZACION q
    LEFT JOIN CLIENTE c ON c.IDCLIENTE=q.IDCLIENTE
    LEFT JOIN TIPO_ENTREGA t ON t.IDTIPOENTREGA=q.IDTIPOENTREGA
    LEFT JOIN USUARIO cu ON cu.IDUSUARIO=q.CREADOPOR
    LEFT JOIN USUARIO eu ON eu.IDUSUARIO=q.ENVIADOPOR
    OUTER APPLY (SELECT SUM(MONTO) AS ABONADO FROM COTIZACION_PAGO WHERE IDCOTIZACION=q.IDCOTIZACION) pay
    WHERE (@Buscar IS NULL OR @Buscar='' OR q.IDCOTIZACION LIKE '%'+@Buscar+'%'
           OR ISNULL(c.NOMBRE,q.NOMBRECLIENTE) LIKE '%'+@Buscar+'%')
      AND (@Estado IS NULL OR @Estado='' OR q.ESTADO=@Estado)
    ORDER BY q.FECHACREACION DESC, q.HORACREACION DESC, q.IDCOTIZACION DESC
    OFFSET (@Pagina-1)*@TamanioPagina ROWS FETCH NEXT @TamanioPagina ROWS ONLY;
END;
GO

IF OBJECT_ID('dbo.usp_cotizacion_insertar','P') IS NOT NULL DROP PROCEDURE dbo.usp_cotizacion_insertar;
GO
CREATE PROCEDURE dbo.usp_cotizacion_insertar
    @IdCliente NVARCHAR(50)=NULL, @NombreCliente NVARCHAR(200)=NULL, @IdTipoEntrega NVARCHAR(50)=NULL,
    @DireccionEntrega NVARCHAR(255)=NULL, @CostoDelivery DECIMAL(12,2)=0, @Observaciones NVARCHAR(MAX)=NULL,
    @Estado NVARCHAR(50)='Deuda', @DetalleJson NVARCHAR(MAX)=NULL, @MontoInicial DECIMAL(12,2)=0,
    @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT, @IdOut NVARCHAR(50)=NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @IdOut = NULL;
    DECLARE @IdCli NVARCHAR(50) = NULLIF(LTRIM(RTRIM(ISNULL(@IdCliente,''))), '');
    DECLARE @Nom NVARCHAR(200) = NULLIF(LTRIM(RTRIM(ISNULL(@NombreCliente,''))), '');
    IF @IdCli IS NOT NULL AND EXISTS (SELECT 1 FROM CLIENTE WHERE IDCLIENTE=@IdCli)
        SELECT @Nom = ISNULL(@Nom, NOMBRE) FROM CLIENTE WHERE IDCLIENTE=@IdCli;
    ELSE
        SET @IdCli = NULL;
    IF @Nom IS NULL BEGIN SET @Resultado=0; SET @Mensaje='Ingresa el cliente.'; RETURN; END
    IF @DetalleJson IS NULL OR LEN(@DetalleJson)<3 BEGIN SET @Resultado=0; SET @Mensaje='Agrega al menos un producto.'; RETURN; END
    DECLARE @Ok BIT, @Msg NVARCHAR(200);
    EXEC dbo.usp_stock_check_json @DetalleJson, @Ok OUTPUT, @Msg OUTPUT;
    IF @Ok=0 BEGIN SET @Resultado=0; SET @Mensaje=@Msg; RETURN; END
    DECLARE @TotalEst DECIMAL(12,2) = ISNULL((
        SELECT SUM(j.CANTIDAD * j.PRECIOUNITARIO)
        FROM OPENJSON(@DetalleJson) WITH (
            IDPRODUCTO NVARCHAR(50) '$.IDPRODUCTO',
            CANTIDAD DECIMAL(12,2) '$.CANTIDAD',
            PRECIOUNITARIO DECIMAL(12,2) '$.PRECIOUNITARIO'
        ) j
        WHERE j.IDPRODUCTO IS NOT NULL AND j.CANTIDAD > 0
    ), 0) + ISNULL(@CostoDelivery, 0);
    IF ISNULL(@MontoInicial,0) < 0 BEGIN SET @Resultado=0; SET @Mensaje='El monto inicial no puede ser negativo.'; RETURN; END
    IF ISNULL(@MontoInicial,0) > @TotalEst + 0.009
    BEGIN SET @Resultado=0; SET @Mensaje='El monto inicial no puede ser mayor al total.'; RETURN; END
    DECLARE @Est NVARCHAR(50) = ISNULL(NULLIF(LTRIM(RTRIM(@Estado)),''),'Deuda');
    IF @Est NOT IN ('Pagado','Deuda') SET @Est='Deuda';
    DECLARE @Id NVARCHAR(50); EXEC dbo.usp_siguiente_id 'COT','COTIZACION','IDCOTIZACION',@Id OUTPUT;
    BEGIN TRY
        BEGIN TRAN;
        INSERT INTO COTIZACION (IDCOTIZACION,IDCLIENTE,NOMBRECLIENTE,IDTIPOENTREGA,DIRECCIONENTREGA,COSTODELIVERY,SUBTOTAL,TOTAL,OBSERVACIONES,ESTADO,STOCKRESERVADO,
            CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
        VALUES (@Id,@IdCli,@Nom,@IdTipoEntrega,@DireccionEntrega,ISNULL(@CostoDelivery,0),0,0,@Observaciones,@Est,0,
            dbo.fn_actor(),dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108),dbo.fn_actor(),dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108));
        EXEC dbo.usp_cotizacion_guardar_detalle @Id, @DetalleJson;
        EXEC dbo.usp_stock_desde_detalle @Id, -1;
        UPDATE COTIZACION SET STOCKRESERVADO=1 WHERE IDCOTIZACION=@Id;
        IF ISNULL(@MontoInicial,0) > 0
        BEGIN
            DECLARE @RPago INT, @MPago NVARCHAR(200);
            EXEC dbo.usp_cotizacion_pago_insertar @Id=@Id, @Monto=@MontoInicial, @Tipo='Inicial', @Resultado=@RPago OUTPUT, @Mensaje=@MPago OUTPUT;
            IF ISNULL(@RPago,0)=0
            BEGIN
                ROLLBACK TRAN;
                SET @Resultado=0; SET @Mensaje=@MPago; RETURN;
            END
        END
        ELSE
            EXEC dbo.usp_cotizacion_pago_recalcular @Id;
        COMMIT TRAN;
        SET @IdOut=@Id;
        SET @Resultado=1; SET @Mensaje='Cotización registrada.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        SET @Resultado=0; SET @Mensaje=LEFT(ERROR_MESSAGE(),200);
    END CATCH
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
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=@Id AND ESTADO IN ('Convertida','Anulada'))
    BEGIN SET @Resultado=0; SET @Mensaje='No se puede editar una cotización convertida o anulada.'; RETURN; END
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
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=@Id AND ESTADO IN ('Convertida','Anulada'))
    BEGIN SET @Resultado=0; SET @Mensaje='No se puede guardar el envío de una cotización convertida o anulada.'; RETURN; END
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

    UPDATE COTIZACION SET ESTADO='Convertida', IDVENTA=@IdVenta,
        IDFORMAPAGO=@Forma, IDTIPOENTREGA=@Tipo, DIRECCIONENTREGA=@Dir, COSTODELIVERY=@Costo,
        TOTAL=@Sub + @Costo,
        ENVIADOPOR=dbo.fn_actor(), FECHAENVIO=dbo.fn_fecha_ddmmyyyy(), HORAENVIO=CONVERT(CHAR(8),GETDATE(),108),
        MODIFICADOPOR=dbo.fn_actor(), FECHAMODIFICACION=dbo.fn_fecha_ddmmyyyy(), HORAMODIFICACION=CONVERT(CHAR(8),GETDATE(),108)
    WHERE IDCOTIZACION=@Id;

    SET @Resultado=1; SET @Mensaje='Pedido generado. '+@IdVenta+'.';
END;
GO

IF OBJECT_ID('dbo.usp_venta_insertar','P') IS NOT NULL DROP PROCEDURE dbo.usp_venta_insertar;
GO
CREATE PROCEDURE dbo.usp_venta_insertar
    @IdCliente NVARCHAR(50), @IdFormaPago NVARCHAR(50)=NULL, @IdTipoEntrega NVARCHAR(50)=NULL,
    @DireccionEntrega NVARCHAR(255)=NULL, @CostoDelivery DECIMAL(12,2)=0, @Observaciones NVARCHAR(MAX)=NULL,
    @Estado NVARCHAR(50)='Pendiente', @DetalleJson NVARCHAR(MAX)=NULL,
    @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF @IdCliente IS NULL BEGIN SET @Resultado=0; SET @Mensaje='Selecciona un cliente.'; RETURN; END
    DECLARE @Est NVARCHAR(50) = ISNULL(NULLIF(LTRIM(RTRIM(@Estado)),''),'Pendiente');
    IF @Est NOT IN ('Pendiente','Empaquetado','Enviado') SET @Est='Pendiente';
    DECLARE @Id NVARCHAR(50); EXEC dbo.usp_siguiente_id 'VEN','VENTA','IDVENTA',@Id OUTPUT;
    INSERT INTO VENTA (IDVENTA,IDCLIENTE,IDFORMAPAGO,IDTIPOENTREGA,DIRECCIONENTREGA,COSTODELIVERY,SUBTOTAL,TOTAL,OBSERVACIONES,ESTADO,
        CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
    VALUES (@Id,@IdCliente,@IdFormaPago,@IdTipoEntrega,@DireccionEntrega,ISNULL(@CostoDelivery,0),0,0,@Observaciones,@Est,
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
    @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM VENTA WHERE IDVENTA=@Id) BEGIN SET @Resultado=0; SET @Mensaje='El pedido no existe.'; RETURN; END
    IF EXISTS (SELECT 1 FROM VENTA WHERE IDVENTA=@Id AND ESTADO='Anulado')
    BEGIN SET @Resultado=0; SET @Mensaje='No se puede editar un pedido anulado.'; RETURN; END
    DECLARE @Est NVARCHAR(50) = ISNULL(NULLIF(LTRIM(RTRIM(@Estado)),''),'Pendiente');
    IF @Est NOT IN ('Pendiente','Empaquetado','Enviado') SET @Est='Pendiente';
    UPDATE VENTA SET IDCLIENTE=@IdCliente, IDFORMAPAGO=@IdFormaPago, IDTIPOENTREGA=@IdTipoEntrega,
        DIRECCIONENTREGA=@DireccionEntrega, COSTODELIVERY=ISNULL(@CostoDelivery,0), OBSERVACIONES=@Observaciones, ESTADO=@Est,
        MODIFICADOPOR=dbo.fn_actor(), FECHAMODIFICACION=dbo.fn_fecha_ddmmyyyy(), HORAMODIFICACION=CONVERT(CHAR(8),GETDATE(),108)
    WHERE IDVENTA=@Id;
    IF @DetalleJson IS NOT NULL
        EXEC dbo.usp_venta_guardar_detalle @Id, @DetalleJson;
    SET @Resultado=1; SET @Mensaje='Pedido actualizado.';
END;
GO

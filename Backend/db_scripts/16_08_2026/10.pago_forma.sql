/* Incremental: método de pago en abonos de cotización */
SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON;
GO

IF COL_LENGTH('dbo.COTIZACION_PAGO', 'IDFORMAPAGO') IS NULL
    ALTER TABLE dbo.COTIZACION_PAGO ADD IDFORMAPAGO NVARCHAR(50) NULL;
GO
IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_COTIZACION_PAGO_FORMA_PAGO'
)
AND COL_LENGTH('dbo.COTIZACION_PAGO', 'IDFORMAPAGO') IS NOT NULL
    ALTER TABLE dbo.COTIZACION_PAGO ADD CONSTRAINT FK_COTIZACION_PAGO_FORMA_PAGO
        FOREIGN KEY (IDFORMAPAGO) REFERENCES dbo.FORMA_PAGO(IDFORMAPAGO);
GO

IF OBJECT_ID('dbo.usp_cotizacion_pago_listar','P') IS NOT NULL DROP PROCEDURE dbo.usp_cotizacion_pago_listar;
GO
CREATE PROCEDURE dbo.usp_cotizacion_pago_listar @Id NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.IDPAGO, p.IDCOTIZACION, p.MONTO, p.TIPO, p.IDFORMAPAGO, f.NOMBRE AS FORMAPAGO_NOMBRE,
           p.CREADOPOR,
           ISNULL(NULLIF(LTRIM(RTRIM(ISNULL(cu.NOMBRE,'')+' '+ISNULL(cu.APELLIDO,''))), ''), p.CREADOPOR) AS CREADOPOR_NOMBRE,
           p.FECHACREACION, p.HORACREACION,
           p.MODIFICADOPOR,
           ISNULL(NULLIF(LTRIM(RTRIM(ISNULL(mu.NOMBRE,'')+' '+ISNULL(mu.APELLIDO,''))), ''), p.MODIFICADOPOR) AS MODIFICADOPOR_NOMBRE,
           p.FECHAMODIFICACION, p.HORAMODIFICACION
    FROM COTIZACION_PAGO p
    LEFT JOIN FORMA_PAGO f ON f.IDFORMAPAGO=p.IDFORMAPAGO
    LEFT JOIN USUARIO cu ON cu.IDUSUARIO=p.CREADOPOR
    LEFT JOIN USUARIO mu ON mu.IDUSUARIO=p.MODIFICADOPOR
    WHERE p.IDCOTIZACION=@Id
    ORDER BY p.FECHACREACION, p.HORACREACION, p.IDPAGO;
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
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=@Id AND ESTADO IN ('Anulada','Convertida'))
    BEGIN SET @Resultado=0; SET @Mensaje='No se puede registrar un abono en una cotización anulada o convertida.'; RETURN; END
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

IF OBJECT_ID('dbo.usp_cotizacion_insertar','P') IS NOT NULL DROP PROCEDURE dbo.usp_cotizacion_insertar;
GO
CREATE PROCEDURE dbo.usp_cotizacion_insertar
    @IdCliente NVARCHAR(50)=NULL, @NombreCliente NVARCHAR(200)=NULL, @IdTipoEntrega NVARCHAR(50)=NULL,
    @DireccionEntrega NVARCHAR(255)=NULL, @CostoDelivery DECIMAL(12,2)=0, @Observaciones NVARCHAR(MAX)=NULL,
    @Estado NVARCHAR(50)='Deuda', @DetalleJson NVARCHAR(MAX)=NULL, @MontoInicial DECIMAL(12,2)=0,
    @IdFormaPago NVARCHAR(50)=NULL,
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
    IF ISNULL(@MontoInicial,0) > 0
       AND (NULLIF(LTRIM(RTRIM(ISNULL(@IdFormaPago,''))),'') IS NULL
            OR NOT EXISTS (SELECT 1 FROM FORMA_PAGO WHERE IDFORMAPAGO=@IdFormaPago AND ESTADO='Activo'))
    BEGIN SET @Resultado=0; SET @Mensaje='Selecciona el método de pago del abono inicial.'; RETURN; END
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
            EXEC dbo.usp_cotizacion_pago_insertar @Id=@Id, @Monto=@MontoInicial, @Tipo='Inicial', @IdFormaPago=@IdFormaPago, @Resultado=@RPago OUTPUT, @Mensaje=@MPago OUTPUT;
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

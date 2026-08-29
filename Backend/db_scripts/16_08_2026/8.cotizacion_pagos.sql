/* Incremental: estados de cotización + pagos/abonos */
SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON;
GO

IF OBJECT_ID('dbo.COTIZACION_PAGO','U') IS NULL
BEGIN
    CREATE TABLE dbo.COTIZACION_PAGO (
        IDPAGO              NVARCHAR(50)    NOT NULL PRIMARY KEY,
        IDCOTIZACION        NVARCHAR(50)    NOT NULL FOREIGN KEY REFERENCES dbo.COTIZACION(IDCOTIZACION),
        MONTO               DECIMAL(12,2)   NOT NULL,
        TIPO                NVARCHAR(50)    NOT NULL DEFAULT 'Abono',
        CREADOPOR           NVARCHAR(50)    NULL,
        FECHACREACION       CHAR(8)         NULL,
        HORACREACION        CHAR(8)         NULL,
        MODIFICADOPOR       NVARCHAR(50)    NULL,
        FECHAMODIFICACION   CHAR(8)         NULL,
        HORAMODIFICACION    CHAR(8)         NULL
    );
END
GO

UPDATE dbo.COTIZACION SET ESTADO='Cotizado' WHERE ESTADO IN ('Aceptado','Aceptada','Borrador');
UPDATE dbo.COTIZACION SET ESTADO='Enviado' WHERE ESTADO IN ('Enviada');
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
    IF @Estado IN ('Empaquetado','Enviado','Anulada','Convertida') RETURN;
    SELECT @Pagado=ISNULL(SUM(MONTO),0) FROM COTIZACION_PAGO WHERE IDCOTIZACION=@Id;
    IF @Pagado >= @Total AND @Total > 0 SET @Estado='Pagado';
    ELSE IF @Pagado > 0 SET @Estado='Deuda';
    ELSE RETURN;
    UPDATE COTIZACION SET ESTADO=@Estado,
        MODIFICADOPOR=dbo.fn_actor(), FECHAMODIFICACION=dbo.fn_fecha_ddmmyyyy(), HORAMODIFICACION=CONVERT(CHAR(8),GETDATE(),108)
    WHERE IDCOTIZACION=@Id;
END;
GO

IF OBJECT_ID('dbo.usp_cotizacion_pago_listar','P') IS NOT NULL DROP PROCEDURE dbo.usp_cotizacion_pago_listar;
GO
CREATE PROCEDURE dbo.usp_cotizacion_pago_listar @Id NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.IDPAGO, p.IDCOTIZACION, p.MONTO, p.TIPO,
           p.CREADOPOR,
           ISNULL(NULLIF(LTRIM(RTRIM(ISNULL(cu.NOMBRE,'')+' '+ISNULL(cu.APELLIDO,''))), ''), p.CREADOPOR) AS CREADOPOR_NOMBRE,
           p.FECHACREACION, p.HORACREACION,
           p.MODIFICADOPOR,
           ISNULL(NULLIF(LTRIM(RTRIM(ISNULL(mu.NOMBRE,'')+' '+ISNULL(mu.APELLIDO,''))), ''), p.MODIFICADOPOR) AS MODIFICADOPOR_NOMBRE,
           p.FECHAMODIFICACION, p.HORAMODIFICACION
    FROM COTIZACION_PAGO p
    LEFT JOIN USUARIO cu ON cu.IDUSUARIO=p.CREADOPOR
    LEFT JOIN USUARIO mu ON mu.IDUSUARIO=p.MODIFICADOPOR
    WHERE p.IDCOTIZACION=@Id
    ORDER BY p.FECHACREACION, p.HORACREACION, p.IDPAGO;
END;
GO

IF OBJECT_ID('dbo.usp_cotizacion_pago_insertar','P') IS NOT NULL DROP PROCEDURE dbo.usp_cotizacion_pago_insertar;
GO
CREATE PROCEDURE dbo.usp_cotizacion_pago_insertar
    @Id NVARCHAR(50), @Monto DECIMAL(12,2), @Tipo NVARCHAR(50)='Abono',
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
    DECLARE @Total DECIMAL(12,2), @Pagado DECIMAL(12,2), @Saldo DECIMAL(12,2);
    SELECT @Total=ISNULL(TOTAL,0) FROM COTIZACION WHERE IDCOTIZACION=@Id;
    SELECT @Pagado=ISNULL(SUM(MONTO),0) FROM COTIZACION_PAGO WHERE IDCOTIZACION=@Id;
    SET @Saldo = @Total - @Pagado;
    IF @Monto > @Saldo + 0.009
    BEGIN SET @Resultado=0; SET @Mensaje='El abono no puede ser mayor al saldo pendiente.'; RETURN; END
    DECLARE @IdPago NVARCHAR(50);
    EXEC dbo.usp_siguiente_id 'PAG','COTIZACION_PAGO','IDPAGO',@IdPago OUTPUT;
    INSERT INTO COTIZACION_PAGO (IDPAGO,IDCOTIZACION,MONTO,TIPO,
        CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
    VALUES (@IdPago,@Id,@Monto,ISNULL(NULLIF(LTRIM(RTRIM(@Tipo)),''),'Abono'),
        dbo.fn_actor(),dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108),
        dbo.fn_actor(),dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108));
    EXEC dbo.usp_cotizacion_pago_recalcular @Id;
    SET @Resultado=1; SET @Mensaje='Abono registrado.';
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
           q.IDTIPOENTREGA, t.NOMBRE AS TIPOENTREGA_NOMBRE,
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

IF OBJECT_ID('dbo.usp_cotizacion_obtener','P') IS NOT NULL DROP PROCEDURE dbo.usp_cotizacion_obtener;
GO
CREATE PROCEDURE dbo.usp_cotizacion_obtener @Id NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT q.*, ISNULL(c.NOMBRE, q.NOMBRECLIENTE) AS CLIENTE_NOMBRE, t.NOMBRE AS TIPOENTREGA_NOMBRE, t.REQUIEREDIRECCION,
           q.FECHACREACION AS FECHA, q.HORACREACION AS HORA,
           ISNULL(pay.ABONADO,0) AS ABONADO, q.TOTAL - ISNULL(pay.ABONADO,0) AS SALDO
    FROM COTIZACION q
    LEFT JOIN CLIENTE c ON c.IDCLIENTE=q.IDCLIENTE
    LEFT JOIN TIPO_ENTREGA t ON t.IDTIPOENTREGA=q.IDTIPOENTREGA
    OUTER APPLY (SELECT SUM(MONTO) AS ABONADO FROM COTIZACION_PAGO WHERE IDCOTIZACION=q.IDCOTIZACION) pay
    WHERE q.IDCOTIZACION=@Id;
END;
GO

IF OBJECT_ID('dbo.usp_cotizacion_insertar','P') IS NOT NULL DROP PROCEDURE dbo.usp_cotizacion_insertar;
GO
CREATE PROCEDURE dbo.usp_cotizacion_insertar
    @IdCliente NVARCHAR(50)=NULL, @NombreCliente NVARCHAR(200)=NULL, @IdTipoEntrega NVARCHAR(50)=NULL,
    @DireccionEntrega NVARCHAR(255)=NULL, @CostoDelivery DECIMAL(12,2)=0, @Observaciones NVARCHAR(MAX)=NULL,
    @Estado NVARCHAR(50)='Cotizado', @DetalleJson NVARCHAR(MAX)=NULL, @MontoInicial DECIMAL(12,2)=0,
    @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
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
    DECLARE @Est NVARCHAR(50) = ISNULL(NULLIF(LTRIM(RTRIM(@Estado)),''),'Cotizado');
    IF @Est IN ('Aceptado','Aceptada','Borrador') SET @Est='Cotizado';
    IF @Est='Enviada' SET @Est='Enviado';
    IF @Est NOT IN ('Cotizado','Pagado','Deuda','Empaquetado','Enviado') SET @Est='Cotizado';
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
        COMMIT TRAN;
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
    @Estado NVARCHAR(50)='Cotizado', @DetalleJson NVARCHAR(MAX)=NULL,
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
    DECLARE @Est NVARCHAR(50) = ISNULL(NULLIF(LTRIM(RTRIM(@Estado)),''),'Cotizado');
    IF @Est IN ('Aceptado','Aceptada','Borrador') SET @Est='Cotizado';
    IF @Est='Enviada' SET @Est='Enviado';
    IF @Est NOT IN ('Cotizado','Pagado','Deuda','Empaquetado','Enviado') SET @Est='Cotizado';
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

IF OBJECT_ID('dbo.usp_cotizacion_eliminar','P') IS NOT NULL DROP PROCEDURE dbo.usp_cotizacion_eliminar;
GO
CREATE PROCEDURE dbo.usp_cotizacion_eliminar @Id NVARCHAR(50), @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=@Id AND ESTADO='Anulada')
    BEGIN SET @Resultado=0; SET @Mensaje='Solo se puede eliminar una cotización anulada.'; RETURN; END
    DELETE FROM COTIZACION_PAGO WHERE IDCOTIZACION=@Id;
    DELETE FROM COTIZACION_DETALLE WHERE IDCOTIZACION=@Id;
    DELETE FROM COTIZACION WHERE IDCOTIZACION=@Id;
    SET @Resultado=1; SET @Mensaje='Cotización eliminada.';
END;
GO

IF OBJECT_ID('dbo.usp_auditoria_instalar_trigger','P') IS NOT NULL
    EXEC dbo.usp_auditoria_instalar_trigger 'COTIZACION_PAGO','IDPAGO';
GO

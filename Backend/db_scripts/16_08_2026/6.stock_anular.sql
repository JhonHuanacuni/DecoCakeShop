/* Incremental: stock al cotizar, anular, envío auditado */
SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON;
GO

IF COL_LENGTH('dbo.COTIZACION', 'STOCKRESERVADO') IS NULL
    ALTER TABLE dbo.COTIZACION ADD STOCKRESERVADO BIT NOT NULL CONSTRAINT DF_COTIZACION_STOCKRESERVADO DEFAULT 0;
GO
IF COL_LENGTH('dbo.COTIZACION', 'ENVIADOPOR') IS NULL
    ALTER TABLE dbo.COTIZACION ADD ENVIADOPOR NVARCHAR(50) NULL;
GO
IF COL_LENGTH('dbo.COTIZACION', 'FECHAENVIO') IS NULL
    ALTER TABLE dbo.COTIZACION ADD FECHAENVIO CHAR(8) NULL;
GO
IF COL_LENGTH('dbo.COTIZACION', 'HORAENVIO') IS NULL
    ALTER TABLE dbo.COTIZACION ADD HORAENVIO CHAR(8) NULL;
GO

IF OBJECT_ID('dbo.usp_stock_desde_detalle','P') IS NOT NULL DROP PROCEDURE dbo.usp_stock_desde_detalle;
GO
CREATE PROCEDURE dbo.usp_stock_desde_detalle @Id NVARCHAR(50), @Signo INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE p SET p.STOCK = p.STOCK + (@Signo * d.CANTIDAD),
        p.MODIFICADOPOR=dbo.fn_actor(), p.FECHAMODIFICACION=dbo.fn_fecha_ddmmyyyy(), p.HORAMODIFICACION=CONVERT(CHAR(8),GETDATE(),108)
    FROM PRODUCTO p INNER JOIN COTIZACION_DETALLE d ON d.IDPRODUCTO=p.IDPRODUCTO
    WHERE d.IDCOTIZACION=@Id;
END;
GO

IF OBJECT_ID('dbo.usp_stock_check_json','P') IS NOT NULL DROP PROCEDURE dbo.usp_stock_check_json;
GO
CREATE PROCEDURE dbo.usp_stock_check_json @DetalleJson NVARCHAR(MAX), @Ok BIT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @Ok = 1; SET @Mensaje = NULL;
    IF EXISTS (
        SELECT 1
        FROM OPENJSON(@DetalleJson) WITH (
            IDPRODUCTO NVARCHAR(50) '$.IDPRODUCTO',
            CANTIDAD DECIMAL(12,2) '$.CANTIDAD'
        ) j
        INNER JOIN PRODUCTO p ON p.IDPRODUCTO=j.IDPRODUCTO
        WHERE j.IDPRODUCTO IS NOT NULL AND j.CANTIDAD > 0 AND p.STOCK < j.CANTIDAD
    )
    BEGIN
        SET @Ok = 0;
        SET @Mensaje = 'Stock insuficiente para uno o más productos.';
    END
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
    @Estado NVARCHAR(50)='Cotizado', @DetalleJson NVARCHAR(MAX)=NULL,
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
    DECLARE @Id NVARCHAR(50); EXEC dbo.usp_siguiente_id 'COT','COTIZACION','IDCOTIZACION',@Id OUTPUT;
    INSERT INTO COTIZACION (IDCOTIZACION,IDCLIENTE,NOMBRECLIENTE,IDTIPOENTREGA,DIRECCIONENTREGA,COSTODELIVERY,SUBTOTAL,TOTAL,OBSERVACIONES,ESTADO,STOCKRESERVADO,
        CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
    VALUES (@Id,@IdCli,@Nom,@IdTipoEntrega,@DireccionEntrega,ISNULL(@CostoDelivery,0),0,0,@Observaciones,ISNULL(@Estado,'Cotizado'),0,
        dbo.fn_actor(),dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108),dbo.fn_actor(),dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108));
    EXEC dbo.usp_cotizacion_guardar_detalle @Id, @DetalleJson;
    EXEC dbo.usp_stock_desde_detalle @Id, -1;
    UPDATE COTIZACION SET STOCKRESERVADO=1 WHERE IDCOTIZACION=@Id;
    SET @Resultado=1; SET @Mensaje='Cotización registrada.';
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
        COSTODELIVERY=ISNULL(@CostoDelivery,0), OBSERVACIONES=@Observaciones, ESTADO=@Estado, STOCKRESERVADO=0,
        MODIFICADOPOR=dbo.fn_actor(), FECHAMODIFICACION=dbo.fn_fecha_ddmmyyyy(), HORAMODIFICACION=CONVERT(CHAR(8),GETDATE(),108)
    WHERE IDCOTIZACION=@Id;
    IF @DetalleJson IS NOT NULL
        EXEC dbo.usp_cotizacion_guardar_detalle @Id, @DetalleJson;
    EXEC dbo.usp_stock_desde_detalle @Id, -1;
    UPDATE COTIZACION SET STOCKRESERVADO=1 WHERE IDCOTIZACION=@Id;
    SET @Resultado=1; SET @Mensaje='Cotización actualizada.';
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
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=@Id AND ESTADO='Convertida')
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

IF OBJECT_ID('dbo.usp_cotizacion_eliminar','P') IS NOT NULL DROP PROCEDURE dbo.usp_cotizacion_eliminar;
GO
CREATE PROCEDURE dbo.usp_cotizacion_eliminar @Id NVARCHAR(50), @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM COTIZACION WHERE IDCOTIZACION=@Id AND ESTADO='Anulada')
    BEGIN SET @Resultado=0; SET @Mensaje='Solo se puede eliminar una cotización anulada.'; RETURN; END
    DELETE FROM COTIZACION_DETALLE WHERE IDCOTIZACION=@Id;
    DELETE FROM COTIZACION WHERE IDCOTIZACION=@Id;
    SET @Resultado=1; SET @Mensaje='Cotización eliminada.';
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
    IF @Tipo IS NULL OR NOT EXISTS (SELECT 1 FROM TIPO_ENTREGA WHERE IDTIPOENTREGA=@Tipo AND ESTADO='Activo')
    BEGIN SET @Resultado=0; SET @Mensaje='Selecciona el tipo de entrega.'; RETURN; END
    IF EXISTS (SELECT 1 FROM TIPO_ENTREGA WHERE IDTIPOENTREGA=@Tipo AND REQUIEREDIRECCION=1)
       AND NULLIF(LTRIM(RTRIM(ISNULL(@DireccionEntrega,''))),'') IS NULL
    BEGIN SET @Resultado=0; SET @Mensaje='Ingresa la dirección de delivery.'; RETURN; END

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

    UPDATE COTIZACION SET ESTADO='Convertida', IDVENTA=@IdVenta,
        IDTIPOENTREGA=@Tipo, DIRECCIONENTREGA=@DireccionEntrega, COSTODELIVERY=ISNULL(@CostoDelivery,0),
        TOTAL=@Sub + ISNULL(@CostoDelivery,0),
        ENVIADOPOR=dbo.fn_actor(), FECHAENVIO=dbo.fn_fecha_ddmmyyyy(), HORAENVIO=CONVERT(CHAR(8),GETDATE(),108),
        MODIFICADOPOR=dbo.fn_actor(), FECHAMODIFICACION=dbo.fn_fecha_ddmmyyyy(), HORAMODIFICACION=CONVERT(CHAR(8),GETDATE(),108)
    WHERE IDCOTIZACION=@Id;

    SET @Resultado=1; SET @Mensaje='Pedido generado. '+@IdVenta+'.';
END;
GO

IF OBJECT_ID('dbo.usp_venta_anular','P') IS NOT NULL DROP PROCEDURE dbo.usp_venta_anular;
GO
CREATE PROCEDURE dbo.usp_venta_anular @Id NVARCHAR(50), @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM VENTA WHERE IDVENTA=@Id)
    BEGIN SET @Resultado=0; SET @Mensaje='El pedido no existe.'; RETURN; END
    IF EXISTS (SELECT 1 FROM VENTA WHERE IDVENTA=@Id AND ESTADO='Anulado')
    BEGIN SET @Resultado=0; SET @Mensaje='El pedido ya está anulado.'; RETURN; END

    UPDATE p SET p.STOCK = p.STOCK + d.CANTIDAD,
        p.MODIFICADOPOR=dbo.fn_actor(), p.FECHAMODIFICACION=dbo.fn_fecha_ddmmyyyy(), p.HORAMODIFICACION=CONVERT(CHAR(8),GETDATE(),108)
    FROM PRODUCTO p INNER JOIN VENTA_DETALLE d ON d.IDPRODUCTO=p.IDPRODUCTO
    WHERE d.IDVENTA=@Id;

    UPDATE VENTA SET ESTADO='Anulado',
        MODIFICADOPOR=dbo.fn_actor(), FECHAMODIFICACION=dbo.fn_fecha_ddmmyyyy(), HORAMODIFICACION=CONVERT(CHAR(8),GETDATE(),108)
    WHERE IDVENTA=@Id;

    UPDATE COTIZACION SET ESTADO='Anulada', STOCKRESERVADO=0, IDVENTA=@Id,
        MODIFICADOPOR=dbo.fn_actor(), FECHAMODIFICACION=dbo.fn_fecha_ddmmyyyy(), HORAMODIFICACION=CONVERT(CHAR(8),GETDATE(),108)
    WHERE IDVENTA=@Id;

    SET @Resultado=1; SET @Mensaje='Pedido anulado. El stock volvió al almacén.';
END;
GO

IF OBJECT_ID('dbo.usp_venta_eliminar','P') IS NOT NULL DROP PROCEDURE dbo.usp_venta_eliminar;
GO
CREATE PROCEDURE dbo.usp_venta_eliminar @Id NVARCHAR(50), @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM VENTA WHERE IDVENTA=@Id AND ESTADO='Anulado')
    BEGIN SET @Resultado=0; SET @Mensaje='Solo se puede eliminar un pedido anulado.'; RETURN; END
    UPDATE COTIZACION SET IDVENTA=NULL WHERE IDVENTA=@Id;
    DELETE FROM VENTA_DETALLE WHERE IDVENTA=@Id;
    DELETE FROM VENTA WHERE IDVENTA=@Id;
    SET @Resultado=1; SET @Mensaje='Pedido eliminado.';
END;
GO

PRINT 'Stock al cotizar, anular y envío listos.';
GO

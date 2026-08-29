/* Demo: limpia cotizaciones/pedidos y carga datos de prueba.
   No está en ORDEN_EJECUCION: se ejecuta a demanda. */
SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON; SET NOCOUNT ON;
GO

EXEC sp_set_session_context @key=N'IDUSUARIO', @value=N'vendedor', @read_only=0;

/* Devolver stock reservado por cotizaciones activas */
UPDATE p SET p.STOCK = p.STOCK + d.CANTIDAD
FROM PRODUCTO p
INNER JOIN COTIZACION_DETALLE d ON d.IDPRODUCTO = p.IDPRODUCTO
INNER JOIN COTIZACION q ON q.IDCOTIZACION = d.IDCOTIZACION
WHERE ISNULL(q.STOCKRESERVADO, 0) = 1;

DELETE FROM COTIZACION_PAGO;
DELETE FROM VENTA_DETALLE;
DELETE FROM VENTA;
DELETE FROM COTIZACION_DETALLE;
DELETE FROM COTIZACION;

UPDATE PRODUCTO SET STOCK = 50 WHERE IDPRODUCTO = N'PRD001';
UPDATE PRODUCTO SET STOCK = 100 WHERE IDPRODUCTO = N'PRD002';

DECLARE @R INT, @M NVARCHAR(200), @Id NVARCHAR(50);
DECLARE @IdDeuda NVARCHAR(50), @IdPagado NVARCHAR(50), @IdPablo NVARCHAR(50);
DECLARE @IdPend NVARCHAR(50), @IdEmp NVARCHAR(50), @IdEnv NVARCHAR(50);
DECLARE @CliEncanto NVARCHAR(50), @CliSugar NVARCHAR(50);

IF NOT EXISTS (SELECT 1 FROM CLIENTE WHERE NOMBRE = N'Repostería Encanto')
BEGIN
    EXEC dbo.usp_cliente_insertar
        @Nombre=N'Repostería Encanto', @Documento=N'20654321098', @Telefono=N'987654321',
        @Email=N'encanto@correo.com', @Direccion=N'Jr. Las Flores 450', @Estado=N'Activo',
        @Resultado=@R OUTPUT, @Mensaje=@M OUTPUT;
END
IF NOT EXISTS (SELECT 1 FROM CLIENTE WHERE NOMBRE = N'Sugar Art Studio')
BEGIN
    EXEC dbo.usp_cliente_insertar
        @Nombre=N'Sugar Art Studio', @Documento=N'20444555666', @Telefono=N'912345678',
        @Email=N'sugar@correo.com', @Direccion=N'Av. El Sol 890', @Estado=N'Activo',
        @Resultado=@R OUTPUT, @Mensaje=@M OUTPUT;
END

SET @CliEncanto = (SELECT TOP 1 IDCLIENTE FROM CLIENTE WHERE NOMBRE = N'Repostería Encanto');
SET @CliSugar = (SELECT TOP 1 IDCLIENTE FROM CLIENTE WHERE NOMBRE = N'Sugar Art Studio');

/* 1) Deuda con abono inicial — Dulce Luna, delivery */
EXEC dbo.usp_cotizacion_insertar
    @IdCliente=N'CLI001', @NombreCliente=NULL, @IdTipoEntrega=N'TEN002',
    @DireccionEntrega=N'Av. Primavera 123, Surco', @CostoDelivery=8,
    @Observaciones=N'Para vitrina de la semana.', @Estado=N'Deuda',
    @DetalleJson=N'[{"IDPRODUCTO":"PRD001","CANTIDAD":2,"PRECIOUNITARIO":28.50},{"IDPRODUCTO":"PRD002","CANTIDAD":3,"PRECIOUNITARIO":12.00}]',
    @MontoInicial=30, @IdFormaPago=N'FPA001',
    @Resultado=@R OUTPUT, @Mensaje=@M OUTPUT, @IdOut=@Id OUTPUT;
IF ISNULL(@R,0)=0 RAISERROR(@M, 16, 1);
SET @IdDeuda = @Id;

/* 2) Pagada, aún no convertida — Carlos, recojo */
EXEC dbo.usp_cotizacion_insertar
    @IdCliente=NULL, @NombreCliente=N'CARLOS', @IdTipoEntrega=N'TEN001',
    @DireccionEntrega=NULL, @CostoDelivery=0,
    @Observaciones=N'Recoge el sábado por la mañana.', @Estado=N'Pagado',
    @DetalleJson=N'[{"IDPRODUCTO":"PRD001","CANTIDAD":1,"PRECIOUNITARIO":28.50}]',
    @MontoInicial=28.50, @IdFormaPago=N'FPA003',
    @Resultado=@R OUTPUT, @Mensaje=@M OUTPUT, @IdOut=@Id OUTPUT;
IF ISNULL(@R,0)=0 RAISERROR(@M, 16, 1);
SET @IdPagado = @Id;

/* 3) Deuda sin abonos — Pablo */
EXEC dbo.usp_cotizacion_insertar
    @IdCliente=NULL, @NombreCliente=N'PABLO', @IdTipoEntrega=N'TEN001',
    @DireccionEntrega=NULL, @CostoDelivery=0,
    @Observaciones=N'Pendiente de confirmar colores.', @Estado=N'Deuda',
    @DetalleJson=N'[{"IDPRODUCTO":"PRD002","CANTIDAD":5,"PRECIOUNITARIO":12.00}]',
    @MontoInicial=0, @IdFormaPago=NULL,
    @Resultado=@R OUTPUT, @Mensaje=@M OUTPUT, @IdOut=@Id OUTPUT;
IF ISNULL(@R,0)=0 RAISERROR(@M, 16, 1);
SET @IdPablo = @Id;

/* 4) Pagada + convertida a pedido Pendiente — Encanto, recojo */
EXEC dbo.usp_cotizacion_insertar
    @IdCliente=@CliEncanto, @NombreCliente=NULL, @IdTipoEntrega=N'TEN001',
    @DireccionEntrega=NULL, @CostoDelivery=0,
    @Observaciones=N'Pedido de reposición.', @Estado=N'Pagado',
    @DetalleJson=N'[{"IDPRODUCTO":"PRD001","CANTIDAD":3,"PRECIOUNITARIO":28.50},{"IDPRODUCTO":"PRD002","CANTIDAD":2,"PRECIOUNITARIO":12.00}]',
    @MontoInicial=109.50, @IdFormaPago=N'FPA002',
    @Resultado=@R OUTPUT, @Mensaje=@M OUTPUT, @IdOut=@Id OUTPUT;
IF ISNULL(@R,0)=0 RAISERROR(@M, 16, 1);
SET @IdPend = @Id;
EXEC dbo.usp_cotizacion_hacer_pedido
    @Id=@IdPend, @IdFormaPago=N'FPA002', @IdTipoEntrega=N'TEN001',
    @DireccionEntrega=NULL, @CostoDelivery=0,
    @Resultado=@R OUTPUT, @Mensaje=@M OUTPUT;
IF ISNULL(@R,0)=0 RAISERROR(@M, 16, 1);

/* 5) Pagada + convertida a Empaquetado — Sugar Art, delivery */
EXEC dbo.usp_cotizacion_insertar
    @IdCliente=@CliSugar, @NombreCliente=NULL, @IdTipoEntrega=N'TEN002',
    @DireccionEntrega=N'Av. El Sol 890, Miraflores', @CostoDelivery=12,
    @Observaciones=N'Entregar en recepción.', @Estado=N'Deuda',
    @DetalleJson=N'[{"IDPRODUCTO":"PRD001","CANTIDAD":1,"PRECIOUNITARIO":28.50},{"IDPRODUCTO":"PRD002","CANTIDAD":4,"PRECIOUNITARIO":12.00}]',
    @MontoInicial=40, @IdFormaPago=N'FPA003',
    @Resultado=@R OUTPUT, @Mensaje=@M OUTPUT, @IdOut=@Id OUTPUT;
IF ISNULL(@R,0)=0 RAISERROR(@M, 16, 1);
SET @IdEmp = @Id;
EXEC dbo.usp_cotizacion_pago_insertar
    @Id=@IdEmp, @Monto=48.50, @Tipo=N'Abono', @IdFormaPago=N'FPA001',
    @Resultado=@R OUTPUT, @Mensaje=@M OUTPUT;
IF ISNULL(@R,0)=0 RAISERROR(@M, 16, 1);
EXEC dbo.usp_cotizacion_hacer_pedido
    @Id=@IdEmp, @IdFormaPago=N'FPA001', @IdTipoEntrega=N'TEN002',
    @DireccionEntrega=N'Av. El Sol 890, Miraflores', @CostoDelivery=12,
    @Resultado=@R OUTPUT, @Mensaje=@M OUTPUT;
IF ISNULL(@R,0)=0 RAISERROR(@M, 16, 1);

/* 6) Pagada + convertida a Enviado — Dulce Luna */
EXEC dbo.usp_cotizacion_insertar
    @IdCliente=N'CLI001', @NombreCliente=NULL, @IdTipoEntrega=N'TEN002',
    @DireccionEntrega=N'Av. Primavera 123, Surco', @CostoDelivery=10,
    @Observaciones=N'Ya salió a ruta.', @Estado=N'Pagado',
    @DetalleJson=N'[{"IDPRODUCTO":"PRD001","CANTIDAD":2,"PRECIOUNITARIO":28.50}]',
    @MontoInicial=67, @IdFormaPago=N'FPA002',
    @Resultado=@R OUTPUT, @Mensaje=@M OUTPUT, @IdOut=@Id OUTPUT;
IF ISNULL(@R,0)=0 RAISERROR(@M, 16, 1);
SET @IdEnv = @Id;
EXEC dbo.usp_cotizacion_hacer_pedido
    @Id=@IdEnv, @IdFormaPago=N'FPA002', @IdTipoEntrega=N'TEN002',
    @DireccionEntrega=N'Av. Primavera 123, Surco', @CostoDelivery=10,
    @Resultado=@R OUTPUT, @Mensaje=@M OUTPUT;
IF ISNULL(@R,0)=0 RAISERROR(@M, 16, 1);

UPDATE VENTA SET ESTADO=N'Pendiente'
WHERE IDCOTIZACION = @IdPend;
UPDATE VENTA SET ESTADO=N'Empaquetado'
WHERE IDCOTIZACION = @IdEmp;
UPDATE VENTA SET ESTADO=N'Enviado'
WHERE IDCOTIZACION = @IdEnv;

UPDATE COTIZACION SET FECHACREACION=N'15082026', HORACREACION=N'10:15:22',
    FECHAMODIFICACION=N'15082026', HORAMODIFICACION=N'10:15:22'
WHERE IDCOTIZACION = @IdDeuda;
UPDATE COTIZACION_PAGO SET FECHACREACION=N'15082026', HORACREACION=N'10:15:22',
    FECHAMODIFICACION=N'15082026', HORAMODIFICACION=N'10:15:22'
WHERE IDCOTIZACION = @IdDeuda;

UPDATE COTIZACION SET FECHACREACION=N'18082026', HORACREACION=N'16:40:08',
    FECHAMODIFICACION=N'18082026', HORAMODIFICACION=N'16:40:08'
WHERE IDCOTIZACION = @IdPagado;
UPDATE COTIZACION_PAGO SET FECHACREACION=N'18082026', HORACREACION=N'16:40:08',
    FECHAMODIFICACION=N'18082026', HORAMODIFICACION=N'16:40:08'
WHERE IDCOTIZACION = @IdPagado;

UPDATE COTIZACION SET FECHACREACION=N'19082026', HORACREACION=N'11:05:41',
    FECHAMODIFICACION=N'19082026', HORAMODIFICACION=N'11:05:41'
WHERE IDCOTIZACION = @IdPablo;

UPDATE COTIZACION SET FECHACREACION=N'20082026', HORACREACION=N'09:20:11',
    FECHAMODIFICACION=N'20082026', HORAMODIFICACION=N'09:32:00',
    FECHAENVIO=N'20082026', HORAENVIO=N'09:32:00'
WHERE IDCOTIZACION = @IdPend;
UPDATE COTIZACION_PAGO SET FECHACREACION=N'20082026', HORACREACION=N'09:20:11',
    FECHAMODIFICACION=N'20082026', HORAMODIFICACION=N'09:20:11'
WHERE IDCOTIZACION = @IdPend;
UPDATE VENTA SET FECHACREACION=N'20082026', HORACREACION=N'09:32:00',
    FECHAMODIFICACION=N'20082026', HORAMODIFICACION=N'09:32:00'
WHERE IDCOTIZACION = @IdPend;

UPDATE COTIZACION SET FECHACREACION=N'20082026', HORACREACION=N'14:08:55',
    FECHAMODIFICACION=N'20082026', HORAMODIFICACION=N'15:10:00',
    FECHAENVIO=N'20082026', HORAENVIO=N'15:10:00'
WHERE IDCOTIZACION = @IdEmp;
UPDATE VENTA SET FECHACREACION=N'20082026', HORACREACION=N'15:10:00',
    FECHAMODIFICACION=N'20082026', HORAMODIFICACION=N'18:45:00'
WHERE IDCOTIZACION = @IdEmp;

UPDATE COTIZACION SET FECHACREACION=N'21082026', HORACREACION=N'08:12:30',
    FECHAMODIFICACION=N'21082026', HORAMODIFICACION=N'08:40:00',
    FECHAENVIO=N'21082026', HORAENVIO=N'08:40:00'
WHERE IDCOTIZACION = @IdEnv;
UPDATE COTIZACION_PAGO SET FECHACREACION=N'21082026', HORACREACION=N'08:12:30',
    FECHAMODIFICACION=N'21082026', HORAMODIFICACION=N'08:12:30'
WHERE IDCOTIZACION = @IdEnv;
UPDATE VENTA SET FECHACREACION=N'21082026', HORACREACION=N'08:40:00',
    FECHAMODIFICACION=N'21082026', HORAMODIFICACION=N'11:20:00'
WHERE IDCOTIZACION = @IdEnv;

PRINT 'Datos de prueba de cotizaciones y pedidos cargados.';
GO

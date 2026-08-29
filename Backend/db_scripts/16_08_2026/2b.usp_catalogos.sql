/* Catálogos: categoria, unidad, cliente, formapago, tipoentrega */
SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON;
GO

/* CATEGORIA */
IF OBJECT_ID('dbo.usp_categoria_listar','P') IS NOT NULL DROP PROCEDURE dbo.usp_categoria_listar;
GO
CREATE PROCEDURE dbo.usp_categoria_listar
    @Buscar NVARCHAR(200)=NULL, @Estado NVARCHAR(50)=NULL, @OrdenarPor NVARCHAR(50)='ORDEN',
    @Direccion NVARCHAR(4)='ASC', @Pagina INT=1, @TamanioPagina INT=10, @TotalRegistros INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF @Pagina<1 SET @Pagina=1; IF @TamanioPagina<1 SET @TamanioPagina=10;
    SELECT @TotalRegistros = COUNT(*) FROM CATEGORIA c
    WHERE (@Buscar IS NULL OR @Buscar='' OR c.IDCATEGORIA LIKE '%'+@Buscar+'%' OR c.NOMBRE LIKE '%'+@Buscar+'%')
      AND (@Estado IS NULL OR @Estado='' OR c.ESTADO=@Estado);
    SELECT c.*, cu.NOMBRE+' '+cu.APELLIDO AS CREADOPOR_NOMBRE, mu.NOMBRE+' '+mu.APELLIDO AS MODIFICADOPOR_NOMBRE
    FROM CATEGORIA c
    LEFT JOIN USUARIO cu ON cu.IDUSUARIO=c.CREADOPOR
    LEFT JOIN USUARIO mu ON mu.IDUSUARIO=c.MODIFICADOPOR
    WHERE (@Buscar IS NULL OR @Buscar='' OR c.IDCATEGORIA LIKE '%'+@Buscar+'%' OR c.NOMBRE LIKE '%'+@Buscar+'%')
      AND (@Estado IS NULL OR @Estado='' OR c.ESTADO=@Estado)
    ORDER BY
        CASE WHEN @OrdenarPor='ORDEN' AND @Direccion='ASC' THEN c.ORDEN END ASC,
        CASE WHEN @OrdenarPor='ORDEN' AND @Direccion='DESC' THEN c.ORDEN END DESC,
        CASE WHEN @OrdenarPor='NOMBRE' AND @Direccion='ASC' THEN c.NOMBRE END ASC,
        CASE WHEN @OrdenarPor='NOMBRE' AND @Direccion='DESC' THEN c.NOMBRE END DESC,
        c.ORDEN, c.NOMBRE
    OFFSET (@Pagina-1)*@TamanioPagina ROWS FETCH NEXT @TamanioPagina ROWS ONLY;
END;
GO
IF OBJECT_ID('dbo.usp_categoria_obtener','P') IS NOT NULL DROP PROCEDURE dbo.usp_categoria_obtener;
GO
CREATE PROCEDURE dbo.usp_categoria_obtener @Id NVARCHAR(50)
AS BEGIN SET NOCOUNT ON; SELECT * FROM CATEGORIA WHERE IDCATEGORIA=@Id; END;
GO
IF OBJECT_ID('dbo.usp_categoria_insertar','P') IS NOT NULL DROP PROCEDURE dbo.usp_categoria_insertar;
GO
CREATE PROCEDURE dbo.usp_categoria_insertar
    @Nombre NVARCHAR(150), @Descripcion NVARCHAR(255)=NULL, @Orden INT=0, @Estado NVARCHAR(50)='Activo',
    @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre))='' BEGIN SET @Resultado=0; SET @Mensaje='Ingresa el nombre.'; RETURN; END
    IF EXISTS (SELECT 1 FROM CATEGORIA WHERE NOMBRE=@Nombre) BEGIN SET @Resultado=0; SET @Mensaje='Ya existe una categoría con ese nombre.'; RETURN; END
    DECLARE @Id NVARCHAR(50); EXEC dbo.usp_siguiente_id 'CAT','CATEGORIA','IDCATEGORIA',@Id OUTPUT;
    INSERT INTO CATEGORIA (IDCATEGORIA,NOMBRE,DESCRIPCION,ORDEN,ESTADO,CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
    VALUES (@Id,@Nombre,@Descripcion,ISNULL(@Orden,0),ISNULL(@Estado,'Activo'),dbo.fn_actor(),dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108),dbo.fn_actor(),dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108));
    SET @Resultado=1; SET @Mensaje='Categoría registrada.';
END;
GO
IF OBJECT_ID('dbo.usp_categoria_actualizar','P') IS NOT NULL DROP PROCEDURE dbo.usp_categoria_actualizar;
GO
CREATE PROCEDURE dbo.usp_categoria_actualizar
    @Id NVARCHAR(50), @Nombre NVARCHAR(150), @Descripcion NVARCHAR(255)=NULL, @Orden INT=0, @Estado NVARCHAR(50)='Activo',
    @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM CATEGORIA WHERE IDCATEGORIA=@Id) BEGIN SET @Resultado=0; SET @Mensaje='La categoría no existe.'; RETURN; END
    UPDATE CATEGORIA SET NOMBRE=@Nombre, DESCRIPCION=@Descripcion, ORDEN=ISNULL(@Orden,0), ESTADO=@Estado,
        MODIFICADOPOR=dbo.fn_actor(), FECHAMODIFICACION=dbo.fn_fecha_ddmmyyyy(), HORAMODIFICACION=CONVERT(CHAR(8),GETDATE(),108)
    WHERE IDCATEGORIA=@Id;
    SET @Resultado=1; SET @Mensaje='Categoría actualizada.';
END;
GO
IF OBJECT_ID('dbo.usp_categoria_eliminar','P') IS NOT NULL DROP PROCEDURE dbo.usp_categoria_eliminar;
GO
CREATE PROCEDURE dbo.usp_categoria_eliminar @Id NVARCHAR(50), @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM PRODUCTO WHERE IDCATEGORIA=@Id) BEGIN SET @Resultado=0; SET @Mensaje='No se puede eliminar: hay productos asociados.'; RETURN; END
    DELETE FROM CATEGORIA WHERE IDCATEGORIA=@Id;
    SET @Resultado=1; SET @Mensaje='Categoría eliminada.';
END;
GO

/* UNIDAD */
IF OBJECT_ID('dbo.usp_unidad_listar','P') IS NOT NULL DROP PROCEDURE dbo.usp_unidad_listar;
GO
CREATE PROCEDURE dbo.usp_unidad_listar
    @Buscar NVARCHAR(200)=NULL, @Estado NVARCHAR(50)=NULL, @OrdenarPor NVARCHAR(50)='NOMBRE',
    @Direccion NVARCHAR(4)='ASC', @Pagina INT=1, @TamanioPagina INT=10, @TotalRegistros INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRegistros = COUNT(*) FROM UNIDAD
    WHERE (@Buscar IS NULL OR @Buscar='' OR IDUNIDAD LIKE '%'+@Buscar+'%' OR NOMBRE LIKE '%'+@Buscar+'%')
      AND (@Estado IS NULL OR @Estado='' OR ESTADO=@Estado);
    SELECT * FROM UNIDAD
    WHERE (@Buscar IS NULL OR @Buscar='' OR IDUNIDAD LIKE '%'+@Buscar+'%' OR NOMBRE LIKE '%'+@Buscar+'%')
      AND (@Estado IS NULL OR @Estado='' OR ESTADO=@Estado)
    ORDER BY NOMBRE
    OFFSET (@Pagina-1)*@TamanioPagina ROWS FETCH NEXT @TamanioPagina ROWS ONLY;
END;
GO
IF OBJECT_ID('dbo.usp_unidad_obtener','P') IS NOT NULL DROP PROCEDURE dbo.usp_unidad_obtener;
GO
CREATE PROCEDURE dbo.usp_unidad_obtener @Id NVARCHAR(50) AS BEGIN SET NOCOUNT ON; SELECT * FROM UNIDAD WHERE IDUNIDAD=@Id; END;
GO
IF OBJECT_ID('dbo.usp_unidad_insertar','P') IS NOT NULL DROP PROCEDURE dbo.usp_unidad_insertar;
GO
CREATE PROCEDURE dbo.usp_unidad_insertar
    @Nombre NVARCHAR(100), @Abreviatura NVARCHAR(20)=NULL, @Estado NVARCHAR(50)='Activo',
    @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre))='' BEGIN SET @Resultado=0; SET @Mensaje='Ingresa el nombre.'; RETURN; END
    DECLARE @Id NVARCHAR(50); EXEC dbo.usp_siguiente_id 'UNI','UNIDAD','IDUNIDAD',@Id OUTPUT;
    INSERT INTO UNIDAD (IDUNIDAD,NOMBRE,ABREVIATURA,ESTADO,CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
    VALUES (@Id,@Nombre,@Abreviatura,ISNULL(@Estado,'Activo'),dbo.fn_actor(),dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108),dbo.fn_actor(),dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108));
    SET @Resultado=1; SET @Mensaje='Unidad registrada.';
END;
GO
IF OBJECT_ID('dbo.usp_unidad_actualizar','P') IS NOT NULL DROP PROCEDURE dbo.usp_unidad_actualizar;
GO
CREATE PROCEDURE dbo.usp_unidad_actualizar
    @Id NVARCHAR(50), @Nombre NVARCHAR(100), @Abreviatura NVARCHAR(20)=NULL, @Estado NVARCHAR(50)='Activo',
    @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE UNIDAD SET NOMBRE=@Nombre, ABREVIATURA=@Abreviatura, ESTADO=@Estado,
        MODIFICADOPOR=dbo.fn_actor(), FECHAMODIFICACION=dbo.fn_fecha_ddmmyyyy(), HORAMODIFICACION=CONVERT(CHAR(8),GETDATE(),108)
    WHERE IDUNIDAD=@Id;
    SET @Resultado=1; SET @Mensaje='Unidad actualizada.';
END;
GO
IF OBJECT_ID('dbo.usp_unidad_eliminar','P') IS NOT NULL DROP PROCEDURE dbo.usp_unidad_eliminar;
GO
CREATE PROCEDURE dbo.usp_unidad_eliminar @Id NVARCHAR(50), @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM PRODUCTO WHERE IDUNIDAD=@Id) BEGIN SET @Resultado=0; SET @Mensaje='No se puede eliminar: hay productos asociados.'; RETURN; END
    DELETE FROM UNIDAD WHERE IDUNIDAD=@Id; SET @Resultado=1; SET @Mensaje='Unidad eliminada.';
END;
GO

/* CLIENTE */
IF OBJECT_ID('dbo.usp_cliente_listar','P') IS NOT NULL DROP PROCEDURE dbo.usp_cliente_listar;
GO
CREATE PROCEDURE dbo.usp_cliente_listar
    @Buscar NVARCHAR(200)=NULL, @Estado NVARCHAR(50)=NULL, @OrdenarPor NVARCHAR(50)='NOMBRE',
    @Direccion NVARCHAR(4)='ASC', @Pagina INT=1, @TamanioPagina INT=10, @TotalRegistros INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRegistros = COUNT(*) FROM CLIENTE
    WHERE (@Buscar IS NULL OR @Buscar='' OR NOMBRE LIKE '%'+@Buscar+'%' OR ISNULL(DOCUMENTO,'') LIKE '%'+@Buscar+'%' OR ISNULL(TELEFONO,'') LIKE '%'+@Buscar+'%')
      AND (@Estado IS NULL OR @Estado='' OR ESTADO=@Estado);
    SELECT * FROM CLIENTE
    WHERE (@Buscar IS NULL OR @Buscar='' OR NOMBRE LIKE '%'+@Buscar+'%' OR ISNULL(DOCUMENTO,'') LIKE '%'+@Buscar+'%' OR ISNULL(TELEFONO,'') LIKE '%'+@Buscar+'%')
      AND (@Estado IS NULL OR @Estado='' OR ESTADO=@Estado)
    ORDER BY NOMBRE
    OFFSET (@Pagina-1)*@TamanioPagina ROWS FETCH NEXT @TamanioPagina ROWS ONLY;
END;
GO
IF OBJECT_ID('dbo.usp_cliente_obtener','P') IS NOT NULL DROP PROCEDURE dbo.usp_cliente_obtener;
GO
CREATE PROCEDURE dbo.usp_cliente_obtener @Id NVARCHAR(50) AS BEGIN SET NOCOUNT ON; SELECT * FROM CLIENTE WHERE IDCLIENTE=@Id; END;
GO
IF OBJECT_ID('dbo.usp_cliente_insertar','P') IS NOT NULL DROP PROCEDURE dbo.usp_cliente_insertar;
GO
CREATE PROCEDURE dbo.usp_cliente_insertar
    @Nombre NVARCHAR(200), @Documento NVARCHAR(20)=NULL, @Telefono NVARCHAR(20)=NULL,
    @Email NVARCHAR(150)=NULL, @Direccion NVARCHAR(255)=NULL, @Estado NVARCHAR(50)='Activo',
    @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre))='' BEGIN SET @Resultado=0; SET @Mensaje='Ingresa el nombre.'; RETURN; END
    DECLARE @Id NVARCHAR(50); EXEC dbo.usp_siguiente_id 'CLI','CLIENTE','IDCLIENTE',@Id OUTPUT;
    INSERT INTO CLIENTE (IDCLIENTE,NOMBRE,DOCUMENTO,TELEFONO,EMAIL,DIRECCION,ESTADO,CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
    VALUES (@Id,@Nombre,@Documento,@Telefono,@Email,@Direccion,ISNULL(@Estado,'Activo'),dbo.fn_actor(),dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108),dbo.fn_actor(),dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108));
    SET @Resultado=1; SET @Mensaje='Cliente registrado.';
END;
GO
IF OBJECT_ID('dbo.usp_cliente_actualizar','P') IS NOT NULL DROP PROCEDURE dbo.usp_cliente_actualizar;
GO
CREATE PROCEDURE dbo.usp_cliente_actualizar
    @Id NVARCHAR(50), @Nombre NVARCHAR(200), @Documento NVARCHAR(20)=NULL, @Telefono NVARCHAR(20)=NULL,
    @Email NVARCHAR(150)=NULL, @Direccion NVARCHAR(255)=NULL, @Estado NVARCHAR(50)='Activo',
    @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE CLIENTE SET NOMBRE=@Nombre, DOCUMENTO=@Documento, TELEFONO=@Telefono, EMAIL=@Email, DIRECCION=@Direccion, ESTADO=@Estado,
        MODIFICADOPOR=dbo.fn_actor(), FECHAMODIFICACION=dbo.fn_fecha_ddmmyyyy(), HORAMODIFICACION=CONVERT(CHAR(8),GETDATE(),108)
    WHERE IDCLIENTE=@Id;
    SET @Resultado=1; SET @Mensaje='Cliente actualizado.';
END;
GO
IF OBJECT_ID('dbo.usp_cliente_eliminar','P') IS NOT NULL DROP PROCEDURE dbo.usp_cliente_eliminar;
GO
CREATE PROCEDURE dbo.usp_cliente_eliminar @Id NVARCHAR(50), @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM COTIZACION WHERE IDCLIENTE=@Id) OR EXISTS (SELECT 1 FROM VENTA WHERE IDCLIENTE=@Id)
    BEGIN SET @Resultado=0; SET @Mensaje='No se puede eliminar: el cliente tiene documentos asociados.'; RETURN; END
    DELETE FROM CLIENTE WHERE IDCLIENTE=@Id; SET @Resultado=1; SET @Mensaje='Cliente eliminado.';
END;
GO

IF OBJECT_ID('dbo.usp_cliente_buscar','P') IS NOT NULL DROP PROCEDURE dbo.usp_cliente_buscar;
GO
CREATE PROCEDURE dbo.usp_cliente_buscar
    @Buscar NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @q NVARCHAR(200) = LTRIM(RTRIM(ISNULL(@Buscar,'')));
    IF LEN(@q) < 3 RETURN;
    SELECT TOP 10 IDCLIENTE AS value, NOMBRE AS label
    FROM CLIENTE
    WHERE ESTADO = 'Activo' AND NOMBRE LIKE '%'+@q+'%'
    ORDER BY NOMBRE;
END;
GO

/* FORMA_PAGO */
IF OBJECT_ID('dbo.usp_formapago_listar','P') IS NOT NULL DROP PROCEDURE dbo.usp_formapago_listar;
GO
CREATE PROCEDURE dbo.usp_formapago_listar
    @Buscar NVARCHAR(200)=NULL, @Estado NVARCHAR(50)=NULL, @OrdenarPor NVARCHAR(50)='NOMBRE',
    @Direccion NVARCHAR(4)='ASC', @Pagina INT=1, @TamanioPagina INT=10, @TotalRegistros INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRegistros = COUNT(*) FROM FORMA_PAGO
    WHERE (@Buscar IS NULL OR @Buscar='' OR NOMBRE LIKE '%'+@Buscar+'%') AND (@Estado IS NULL OR @Estado='' OR ESTADO=@Estado);
    SELECT * FROM FORMA_PAGO
    WHERE (@Buscar IS NULL OR @Buscar='' OR NOMBRE LIKE '%'+@Buscar+'%') AND (@Estado IS NULL OR @Estado='' OR ESTADO=@Estado)
    ORDER BY NOMBRE OFFSET (@Pagina-1)*@TamanioPagina ROWS FETCH NEXT @TamanioPagina ROWS ONLY;
END;
GO
IF OBJECT_ID('dbo.usp_formapago_obtener','P') IS NOT NULL DROP PROCEDURE dbo.usp_formapago_obtener;
GO
CREATE PROCEDURE dbo.usp_formapago_obtener @Id NVARCHAR(50) AS BEGIN SET NOCOUNT ON; SELECT * FROM FORMA_PAGO WHERE IDFORMAPAGO=@Id; END;
GO
IF OBJECT_ID('dbo.usp_formapago_insertar','P') IS NOT NULL DROP PROCEDURE dbo.usp_formapago_insertar;
GO
CREATE PROCEDURE dbo.usp_formapago_insertar @Nombre NVARCHAR(100), @Estado NVARCHAR(50)='Activo', @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Id NVARCHAR(50); EXEC dbo.usp_siguiente_id 'FPA','FORMA_PAGO','IDFORMAPAGO',@Id OUTPUT;
    INSERT INTO FORMA_PAGO (IDFORMAPAGO,NOMBRE,ESTADO,CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
    VALUES (@Id,@Nombre,ISNULL(@Estado,'Activo'),dbo.fn_actor(),dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108),dbo.fn_actor(),dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108));
    SET @Resultado=1; SET @Mensaje='Forma de pago registrada.';
END;
GO
IF OBJECT_ID('dbo.usp_formapago_actualizar','P') IS NOT NULL DROP PROCEDURE dbo.usp_formapago_actualizar;
GO
CREATE PROCEDURE dbo.usp_formapago_actualizar @Id NVARCHAR(50), @Nombre NVARCHAR(100), @Estado NVARCHAR(50)='Activo', @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE FORMA_PAGO SET NOMBRE=@Nombre, ESTADO=@Estado, MODIFICADOPOR=dbo.fn_actor(),
        FECHAMODIFICACION=dbo.fn_fecha_ddmmyyyy(), HORAMODIFICACION=CONVERT(CHAR(8),GETDATE(),108)
    WHERE IDFORMAPAGO=@Id;
    SET @Resultado=1; SET @Mensaje='Forma de pago actualizada.';
END;
GO
IF OBJECT_ID('dbo.usp_formapago_eliminar','P') IS NOT NULL DROP PROCEDURE dbo.usp_formapago_eliminar;
GO
CREATE PROCEDURE dbo.usp_formapago_eliminar @Id NVARCHAR(50), @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM VENTA WHERE IDFORMAPAGO=@Id) BEGIN SET @Resultado=0; SET @Mensaje='No se puede eliminar: hay ventas asociadas.'; RETURN; END
    DELETE FROM FORMA_PAGO WHERE IDFORMAPAGO=@Id; SET @Resultado=1; SET @Mensaje='Forma de pago eliminada.';
END;
GO

/* TIPO_ENTREGA */
IF OBJECT_ID('dbo.usp_tipoentrega_listar','P') IS NOT NULL DROP PROCEDURE dbo.usp_tipoentrega_listar;
GO
CREATE PROCEDURE dbo.usp_tipoentrega_listar
    @Buscar NVARCHAR(200)=NULL, @Estado NVARCHAR(50)=NULL, @OrdenarPor NVARCHAR(50)='NOMBRE',
    @Direccion NVARCHAR(4)='ASC', @Pagina INT=1, @TamanioPagina INT=10, @TotalRegistros INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRegistros = COUNT(*) FROM TIPO_ENTREGA
    WHERE (@Buscar IS NULL OR @Buscar='' OR NOMBRE LIKE '%'+@Buscar+'%') AND (@Estado IS NULL OR @Estado='' OR ESTADO=@Estado);
    SELECT IDTIPOENTREGA, NOMBRE, REQUIEREDIRECCION,
           CASE WHEN REQUIEREDIRECCION=1 THEN 'Sí' ELSE 'No' END AS REQUIEREDIRECCION_TXT,
           ESTADO, CREADOPOR, FECHACREACION, HORACREACION, MODIFICADOPOR, FECHAMODIFICACION, HORAMODIFICACION
    FROM TIPO_ENTREGA
    WHERE (@Buscar IS NULL OR @Buscar='' OR NOMBRE LIKE '%'+@Buscar+'%') AND (@Estado IS NULL OR @Estado='' OR ESTADO=@Estado)
    ORDER BY NOMBRE OFFSET (@Pagina-1)*@TamanioPagina ROWS FETCH NEXT @TamanioPagina ROWS ONLY;
END;
GO
IF OBJECT_ID('dbo.usp_tipoentrega_obtener','P') IS NOT NULL DROP PROCEDURE dbo.usp_tipoentrega_obtener;
GO
CREATE PROCEDURE dbo.usp_tipoentrega_obtener @Id NVARCHAR(50)
AS BEGIN SET NOCOUNT ON;
    SELECT IDTIPOENTREGA, NOMBRE, REQUIEREDIRECCION,
           CASE WHEN REQUIEREDIRECCION=1 THEN 'Sí' ELSE 'No' END AS REQUIEREDIRECCION_TXT, ESTADO
    FROM TIPO_ENTREGA WHERE IDTIPOENTREGA=@Id;
END;
GO
IF OBJECT_ID('dbo.usp_tipoentrega_insertar','P') IS NOT NULL DROP PROCEDURE dbo.usp_tipoentrega_insertar;
GO
CREATE PROCEDURE dbo.usp_tipoentrega_insertar
    @Nombre NVARCHAR(100), @RequiereDireccion BIT=0, @Estado NVARCHAR(50)='Activo',
    @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Id NVARCHAR(50); EXEC dbo.usp_siguiente_id 'TEN','TIPO_ENTREGA','IDTIPOENTREGA',@Id OUTPUT;
    INSERT INTO TIPO_ENTREGA (IDTIPOENTREGA,NOMBRE,REQUIEREDIRECCION,ESTADO,CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
    VALUES (@Id,@Nombre,ISNULL(@RequiereDireccion,0),ISNULL(@Estado,'Activo'),dbo.fn_actor(),dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108),dbo.fn_actor(),dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108));
    SET @Resultado=1; SET @Mensaje='Tipo de entrega registrado.';
END;
GO
IF OBJECT_ID('dbo.usp_tipoentrega_actualizar','P') IS NOT NULL DROP PROCEDURE dbo.usp_tipoentrega_actualizar;
GO
CREATE PROCEDURE dbo.usp_tipoentrega_actualizar
    @Id NVARCHAR(50), @Nombre NVARCHAR(100), @RequiereDireccion BIT=0, @Estado NVARCHAR(50)='Activo',
    @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE TIPO_ENTREGA SET NOMBRE=@Nombre, REQUIEREDIRECCION=ISNULL(@RequiereDireccion,0), ESTADO=@Estado,
        MODIFICADOPOR=dbo.fn_actor(), FECHAMODIFICACION=dbo.fn_fecha_ddmmyyyy(), HORAMODIFICACION=CONVERT(CHAR(8),GETDATE(),108)
    WHERE IDTIPOENTREGA=@Id;
    SET @Resultado=1; SET @Mensaje='Tipo de entrega actualizado.';
END;
GO
IF OBJECT_ID('dbo.usp_tipoentrega_eliminar','P') IS NOT NULL DROP PROCEDURE dbo.usp_tipoentrega_eliminar;
GO
CREATE PROCEDURE dbo.usp_tipoentrega_eliminar @Id NVARCHAR(50), @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM TIPO_ENTREGA WHERE IDTIPOENTREGA=@Id; SET @Resultado=1; SET @Mensaje='Tipo de entrega eliminado.';
END;
GO

PRINT 'SPs catálogos listos.';
GO

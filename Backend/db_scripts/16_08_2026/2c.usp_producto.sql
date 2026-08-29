SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON;
GO

IF OBJECT_ID('dbo.usp_producto_listar','P') IS NOT NULL DROP PROCEDURE dbo.usp_producto_listar;
GO
CREATE PROCEDURE dbo.usp_producto_listar
    @Buscar NVARCHAR(200)=NULL, @Estado NVARCHAR(50)=NULL, @IdCategoria NVARCHAR(50)=NULL,
    @OrdenarPor NVARCHAR(50)='NOMBRE', @Direccion NVARCHAR(4)='ASC',
    @Pagina INT=1, @TamanioPagina INT=10, @TotalRegistros INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRegistros = COUNT(*)
    FROM PRODUCTO p
    WHERE (@Buscar IS NULL OR @Buscar='' OR p.NOMBRE LIKE '%'+@Buscar+'%' OR p.IDPRODUCTO LIKE '%'+@Buscar+'%')
      AND (@Estado IS NULL OR @Estado='' OR p.ESTADO=@Estado)
      AND (@IdCategoria IS NULL OR @IdCategoria='' OR p.IDCATEGORIA=@IdCategoria);

    SELECT p.IDPRODUCTO, p.NOMBRE, p.DESCRIPCION, p.PRECIO, p.STOCK, p.IDCATEGORIA, c.NOMBRE AS CATEGORIA_NOMBRE,
           p.IDUNIDAD, u.NOMBRE AS UNIDAD_NOMBRE, p.ESTADO,
           CASE WHEN p.FOTO IS NULL OR LEN(p.FOTO)=0 THEN 0 ELSE 1 END AS TIENE_FOTO,
           p.CREADOPOR, LTRIM(RTRIM(ISNULL(cu.NOMBRE,'')+' '+ISNULL(cu.APELLIDO,''))) AS CREADOPOR_NOMBRE,
           p.FECHACREACION, p.HORACREACION,
           p.MODIFICADOPOR, LTRIM(RTRIM(ISNULL(mu.NOMBRE,'')+' '+ISNULL(mu.APELLIDO,''))) AS MODIFICADOPOR_NOMBRE,
           p.FECHAMODIFICACION, p.HORAMODIFICACION
    FROM PRODUCTO p
    INNER JOIN CATEGORIA c ON c.IDCATEGORIA=p.IDCATEGORIA
    LEFT JOIN UNIDAD u ON u.IDUNIDAD=p.IDUNIDAD
    LEFT JOIN USUARIO cu ON cu.IDUSUARIO=p.CREADOPOR
    LEFT JOIN USUARIO mu ON mu.IDUSUARIO=p.MODIFICADOPOR
    WHERE (@Buscar IS NULL OR @Buscar='' OR p.NOMBRE LIKE '%'+@Buscar+'%' OR p.IDPRODUCTO LIKE '%'+@Buscar+'%')
      AND (@Estado IS NULL OR @Estado='' OR p.ESTADO=@Estado)
      AND (@IdCategoria IS NULL OR @IdCategoria='' OR p.IDCATEGORIA=@IdCategoria)
    ORDER BY
        CASE WHEN @OrdenarPor='NOMBRE' AND @Direccion='ASC' THEN p.NOMBRE END ASC,
        CASE WHEN @OrdenarPor='NOMBRE' AND @Direccion='DESC' THEN p.NOMBRE END DESC,
        CASE WHEN @OrdenarPor='PRECIO' AND @Direccion='ASC' THEN p.PRECIO END ASC,
        CASE WHEN @OrdenarPor='PRECIO' AND @Direccion='DESC' THEN p.PRECIO END DESC,
        CASE WHEN @OrdenarPor='STOCK' AND @Direccion='ASC' THEN p.STOCK END ASC,
        CASE WHEN @OrdenarPor='STOCK' AND @Direccion='DESC' THEN p.STOCK END DESC,
        p.NOMBRE
    OFFSET (@Pagina-1)*@TamanioPagina ROWS FETCH NEXT @TamanioPagina ROWS ONLY;
END;
GO
IF OBJECT_ID('dbo.usp_producto_obtener','P') IS NOT NULL DROP PROCEDURE dbo.usp_producto_obtener;
GO
CREATE PROCEDURE dbo.usp_producto_obtener @Id NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.*, c.NOMBRE AS CATEGORIA_NOMBRE, u.NOMBRE AS UNIDAD_NOMBRE,
           LTRIM(RTRIM(ISNULL(cu.NOMBRE,'')+' '+ISNULL(cu.APELLIDO,''))) AS CREADOPOR_NOMBRE,
           LTRIM(RTRIM(ISNULL(mu.NOMBRE,'')+' '+ISNULL(mu.APELLIDO,''))) AS MODIFICADOPOR_NOMBRE
    FROM PRODUCTO p
    INNER JOIN CATEGORIA c ON c.IDCATEGORIA=p.IDCATEGORIA
    LEFT JOIN UNIDAD u ON u.IDUNIDAD=p.IDUNIDAD
    LEFT JOIN USUARIO cu ON cu.IDUSUARIO=p.CREADOPOR
    LEFT JOIN USUARIO mu ON mu.IDUSUARIO=p.MODIFICADOPOR
    WHERE p.IDPRODUCTO=@Id;
END;
GO
IF OBJECT_ID('dbo.usp_producto_insertar','P') IS NOT NULL DROP PROCEDURE dbo.usp_producto_insertar;
GO
CREATE PROCEDURE dbo.usp_producto_insertar
    @Nombre NVARCHAR(200), @Descripcion NVARCHAR(MAX)=NULL, @Precio DECIMAL(12,2)=0, @Stock DECIMAL(12,2)=0,
    @IdCategoria NVARCHAR(50), @IdUnidad NVARCHAR(50)=NULL, @Estado NVARCHAR(50)='Activo', @Foto NVARCHAR(MAX)=NULL,
    @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre))='' BEGIN SET @Resultado=0; SET @Mensaje='Ingresa el nombre.'; RETURN; END
    IF @IdCategoria IS NULL OR NOT EXISTS (SELECT 1 FROM CATEGORIA WHERE IDCATEGORIA=@IdCategoria)
    BEGIN SET @Resultado=0; SET @Mensaje='Selecciona una categoría.'; RETURN; END
    DECLARE @Id NVARCHAR(50); EXEC dbo.usp_siguiente_id 'PRD','PRODUCTO','IDPRODUCTO',@Id OUTPUT;
    INSERT INTO PRODUCTO (IDPRODUCTO,NOMBRE,DESCRIPCION,PRECIO,STOCK,IDCATEGORIA,IDUNIDAD,ESTADO,FOTO,
        CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
    VALUES (@Id,@Nombre,@Descripcion,ISNULL(@Precio,0),ISNULL(@Stock,0),@IdCategoria,NULLIF(@IdUnidad,''),ISNULL(@Estado,'Activo'),@Foto,
        dbo.fn_actor(),dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108),dbo.fn_actor(),dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108));
    SET @Resultado=1; SET @Mensaje='Producto registrado.';
END;
GO
IF OBJECT_ID('dbo.usp_producto_actualizar','P') IS NOT NULL DROP PROCEDURE dbo.usp_producto_actualizar;
GO
CREATE PROCEDURE dbo.usp_producto_actualizar
    @Id NVARCHAR(50), @Nombre NVARCHAR(200), @Descripcion NVARCHAR(MAX)=NULL, @Precio DECIMAL(12,2)=0, @Stock DECIMAL(12,2)=0,
    @IdCategoria NVARCHAR(50), @IdUnidad NVARCHAR(50)=NULL, @Estado NVARCHAR(50)='Activo', @Foto NVARCHAR(MAX)=NULL,
    @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM PRODUCTO WHERE IDPRODUCTO=@Id) BEGIN SET @Resultado=0; SET @Mensaje='El producto no existe.'; RETURN; END
    UPDATE PRODUCTO SET NOMBRE=@Nombre, DESCRIPCION=@Descripcion, PRECIO=ISNULL(@Precio,0), STOCK=ISNULL(@Stock,0),
        IDCATEGORIA=@IdCategoria, IDUNIDAD=NULLIF(@IdUnidad,''), ESTADO=@Estado, FOTO=@Foto,
        MODIFICADOPOR=dbo.fn_actor(), FECHAMODIFICACION=dbo.fn_fecha_ddmmyyyy(), HORAMODIFICACION=CONVERT(CHAR(8),GETDATE(),108)
    WHERE IDPRODUCTO=@Id;
    SET @Resultado=1; SET @Mensaje='Producto actualizado.';
END;
GO
IF OBJECT_ID('dbo.usp_producto_eliminar','P') IS NOT NULL DROP PROCEDURE dbo.usp_producto_eliminar;
GO
CREATE PROCEDURE dbo.usp_producto_eliminar @Id NVARCHAR(50), @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM COTIZACION_DETALLE WHERE IDPRODUCTO=@Id) OR EXISTS (SELECT 1 FROM VENTA_DETALLE WHERE IDPRODUCTO=@Id)
    BEGIN SET @Resultado=0; SET @Mensaje='No se puede eliminar: el producto está en cotizaciones o ventas.'; RETURN; END
    DELETE FROM PRODUCTO WHERE IDPRODUCTO=@Id; SET @Resultado=1; SET @Mensaje='Producto eliminado.';
END;
GO

PRINT 'SPs producto listos.';
GO

/* Catálogo público paginado: el peso queda en SQL, no en la vista */
SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON;
GO

IF OBJECT_ID('dbo.usp_tienda_categorias','P') IS NOT NULL DROP PROCEDURE dbo.usp_tienda_categorias;
GO
CREATE PROCEDURE dbo.usp_tienda_categorias
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IDCATEGORIA AS value, NOMBRE AS label, DESCRIPCION
    FROM CATEGORIA
    WHERE ESTADO = 'Activo'
    ORDER BY ORDEN, NOMBRE;
END;
GO

IF OBJECT_ID('dbo.usp_tienda_productos','P') IS NOT NULL DROP PROCEDURE dbo.usp_tienda_productos;
GO
CREATE PROCEDURE dbo.usp_tienda_productos
    @Buscar NVARCHAR(200)=NULL,
    @IdCategoria NVARCHAR(50)=NULL,
    @Pagina INT=1,
    @TamanioPagina INT=12,
    @TotalRegistros INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Q NVARCHAR(200) = LTRIM(RTRIM(ISNULL(@Buscar,'')));
    DECLARE @Cat NVARCHAR(50) = NULLIF(LTRIM(RTRIM(ISNULL(@IdCategoria,''))),'');
    IF @Pagina IS NULL OR @Pagina < 1 SET @Pagina = 1;
    IF @TamanioPagina IS NULL OR @TamanioPagina < 1 OR @TamanioPagina > 24 SET @TamanioPagina = 12;

    SELECT @TotalRegistros = COUNT(*)
    FROM PRODUCTO p
    INNER JOIN CATEGORIA c ON c.IDCATEGORIA = p.IDCATEGORIA
    WHERE p.ESTADO = 'Activo'
      AND (@Cat IS NULL OR p.IDCATEGORIA = @Cat)
      AND (@Q = '' OR p.NOMBRE LIKE '%'+@Q+'%' OR ISNULL(p.DESCRIPCION,'') LIKE '%'+@Q+'%' OR c.NOMBRE LIKE '%'+@Q+'%');

    SELECT p.IDPRODUCTO, p.NOMBRE, p.DESCRIPCION, p.PRECIO, p.STOCK, p.FOTO,
           p.IDCATEGORIA, c.NOMBRE AS CATEGORIA_NOMBRE
    FROM PRODUCTO p
    INNER JOIN CATEGORIA c ON c.IDCATEGORIA = p.IDCATEGORIA
    WHERE p.ESTADO = 'Activo'
      AND (@Cat IS NULL OR p.IDCATEGORIA = @Cat)
      AND (@Q = '' OR p.NOMBRE LIKE '%'+@Q+'%' OR ISNULL(p.DESCRIPCION,'') LIKE '%'+@Q+'%' OR c.NOMBRE LIKE '%'+@Q+'%')
    ORDER BY c.ORDEN, p.NOMBRE
    OFFSET (@Pagina - 1) * @TamanioPagina ROWS FETCH NEXT @TamanioPagina ROWS ONLY;
END;
GO

IF OBJECT_ID('dbo.usp_tienda_destacados','P') IS NOT NULL DROP PROCEDURE dbo.usp_tienda_destacados;
GO
CREATE PROCEDURE dbo.usp_tienda_destacados
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 8 p.IDPRODUCTO, p.NOMBRE, p.DESCRIPCION, p.PRECIO, p.STOCK, p.FOTO,
           p.IDCATEGORIA, c.NOMBRE AS CATEGORIA_NOMBRE
    FROM PRODUCTO p
    INNER JOIN CATEGORIA c ON c.IDCATEGORIA = p.IDCATEGORIA
    WHERE p.ESTADO = 'Activo' AND p.FOTO IS NOT NULL AND LEN(p.FOTO) > 0
    ORDER BY c.ORDEN, p.NOMBRE;
END;
GO

IF OBJECT_ID('dbo.usp_tienda_favoritos','P') IS NOT NULL DROP PROCEDURE dbo.usp_tienda_favoritos;
GO
CREATE PROCEDURE dbo.usp_tienda_favoritos
    @Ids NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.IDPRODUCTO, p.NOMBRE, p.DESCRIPCION, p.PRECIO, p.STOCK, p.FOTO,
           p.IDCATEGORIA, c.NOMBRE AS CATEGORIA_NOMBRE
    FROM PRODUCTO p
    INNER JOIN CATEGORIA c ON c.IDCATEGORIA = p.IDCATEGORIA
    INNER JOIN STRING_SPLIT(@Ids, ',') s ON LTRIM(RTRIM(s.value)) = p.IDPRODUCTO
    WHERE p.ESTADO = 'Activo' AND LTRIM(RTRIM(ISNULL(@Ids,''))) <> ''
    ORDER BY p.NOMBRE;
END;
GO

PRINT 'Catálogo de tienda paginado listo.';
GO

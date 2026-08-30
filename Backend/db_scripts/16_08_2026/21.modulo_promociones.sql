/* Incremental: módulo Catálogo / Promociones */
SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON;
GO

IF OBJECT_ID('dbo.PROMOCION','U') IS NULL
CREATE TABLE dbo.PROMOCION (
    IDPROMOCION         NVARCHAR(50)    NOT NULL PRIMARY KEY,
    TIPO                NVARCHAR(20)    NOT NULL,
    TITULO              NVARCHAR(200)   NOT NULL,
    SUBTITULO           NVARCHAR(120)   NULL,
    DESCRIPCION         NVARCHAR(500)   NULL,
    PRECIO              DECIMAL(12,2)   NULL,
    PRECIOTEXTO         NVARCHAR(80)    NULL,
    ENLACE              NVARCHAR(80)    NULL,
    ESTILO              NVARCHAR(20)    NULL,
    IMAGEN              NVARCHAR(MAX)   NULL,
    ORDEN               INT             NOT NULL CONSTRAINT DF_PROMOCION_ORDEN DEFAULT (0),
    ESTADO              NVARCHAR(50)    NOT NULL,
    CREADOPOR           NVARCHAR(50)    NULL,
    FECHACREACION       CHAR(8)         NULL,
    HORACREACION        CHAR(8)         NULL,
    MODIFICADOPOR       NVARCHAR(50)    NULL,
    FECHAMODIFICACION   CHAR(8)         NULL,
    HORAMODIFICACION    CHAR(8)         NULL
);
GO

IF NOT EXISTS (SELECT 1 FROM dbo.MODULO WHERE IDMODULO = N'MOD011')
BEGIN
    UPDATE dbo.MODULO SET ORDEN = ORDEN + 1 WHERE ORDEN >= 8;
    INSERT INTO dbo.MODULO (IDMODULO, NOMBRE, DESCRIPCION, ICONO, ORDEN, ACTIVO)
    VALUES (N'MOD011', N'Catálogo', N'Carrusel y promociones de la tienda', N'faStore', 8, 1);
END
ELSE
BEGIN
    UPDATE dbo.MODULO
    SET NOMBRE = N'Catálogo', DESCRIPCION = N'Carrusel y promociones de la tienda', ICONO = N'faStore', ACTIVO = 1
    WHERE IDMODULO = N'MOD011';
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.SUBMODULO WHERE IDSUBMODULO = N'SUB006')
    INSERT INTO dbo.SUBMODULO (IDSUBMODULO, IDMODULO, NOMBRE, ICONO, ORDEN, ACTIVO)
    VALUES (N'SUB006', N'MOD011', N'Carrusel', N'faImages', 1, 1);
IF NOT EXISTS (SELECT 1 FROM dbo.SUBMODULO WHERE IDSUBMODULO = N'SUB007')
    INSERT INTO dbo.SUBMODULO (IDSUBMODULO, IDMODULO, NOMBRE, ICONO, ORDEN, ACTIVO)
    VALUES (N'SUB007', N'MOD011', N'Promociones', N'faBullhorn', 2, 1);
GO

INSERT INTO dbo.GRUPO_MODULO (IDGRUPOMODULO, IDTIPOUSUARIO, IDMODULO, IDTIPOPERMISO)
SELECT N'GRM3MOD011' + p.IDTIPOPERMISO, N'3', N'MOD011', p.IDTIPOPERMISO
FROM dbo.TIPO_PERMISO p
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.GRUPO_MODULO g
    WHERE g.IDTIPOUSUARIO = N'3' AND g.IDMODULO = N'MOD011' AND g.IDTIPOPERMISO = p.IDTIPOPERMISO
);

INSERT INTO dbo.GRUPO_MODULO (IDGRUPOMODULO, IDTIPOUSUARIO, IDMODULO, IDTIPOPERMISO)
SELECT N'GRM1MOD011' + p.IDTIPOPERMISO, N'1', N'MOD011', p.IDTIPOPERMISO
FROM dbo.TIPO_PERMISO p
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.GRUPO_MODULO g
    WHERE g.IDTIPOUSUARIO = N'1' AND g.IDMODULO = N'MOD011' AND g.IDTIPOPERMISO = p.IDTIPOPERMISO
);
GO

IF OBJECT_ID('dbo.usp_promocion_listar','P') IS NOT NULL DROP PROCEDURE dbo.usp_promocion_listar;
GO
CREATE PROCEDURE dbo.usp_promocion_listar
    @Buscar NVARCHAR(200)=NULL, @Estado NVARCHAR(50)=NULL, @Tipo NVARCHAR(20)=NULL, @OrdenarPor NVARCHAR(50)='ORDEN',
    @Direccion NVARCHAR(4)='ASC', @Pagina INT=1, @TamanioPagina INT=10, @TotalRegistros INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF @Pagina<1 SET @Pagina=1; IF @TamanioPagina<1 SET @TamanioPagina=10;
    SELECT @TotalRegistros = COUNT(*) FROM PROMOCION p
    WHERE (@Buscar IS NULL OR @Buscar='' OR p.IDPROMOCION LIKE '%'+@Buscar+'%' OR p.TITULO LIKE '%'+@Buscar+'%' OR ISNULL(p.DESCRIPCION,'') LIKE '%'+@Buscar+'%')
      AND (@Estado IS NULL OR @Estado='' OR p.ESTADO=@Estado)
      AND (@Tipo IS NULL OR @Tipo='' OR p.TIPO=@Tipo);
    SELECT p.*
    FROM PROMOCION p
    WHERE (@Buscar IS NULL OR @Buscar='' OR p.IDPROMOCION LIKE '%'+@Buscar+'%' OR p.TITULO LIKE '%'+@Buscar+'%' OR ISNULL(p.DESCRIPCION,'') LIKE '%'+@Buscar+'%')
      AND (@Estado IS NULL OR @Estado='' OR p.ESTADO=@Estado)
      AND (@Tipo IS NULL OR @Tipo='' OR p.TIPO=@Tipo)
    ORDER BY
        CASE WHEN @OrdenarPor='TITULO' AND @Direccion='ASC' THEN p.TITULO END ASC,
        CASE WHEN @OrdenarPor='TITULO' AND @Direccion='DESC' THEN p.TITULO END DESC,
        CASE WHEN @OrdenarPor='ORDEN' AND @Direccion='ASC' THEN p.ORDEN END ASC,
        CASE WHEN @OrdenarPor='ORDEN' AND @Direccion='DESC' THEN p.ORDEN END DESC,
        CASE WHEN @OrdenarPor='ESTADO' AND @Direccion='ASC' THEN p.ESTADO END ASC,
        CASE WHEN @OrdenarPor='ESTADO' AND @Direccion='DESC' THEN p.ESTADO END DESC,
        p.ORDEN, p.TITULO
    OFFSET (@Pagina-1)*@TamanioPagina ROWS FETCH NEXT @TamanioPagina ROWS ONLY;
END;
GO

IF OBJECT_ID('dbo.usp_promocion_obtener','P') IS NOT NULL DROP PROCEDURE dbo.usp_promocion_obtener;
GO
CREATE PROCEDURE dbo.usp_promocion_obtener @Id NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM PROMOCION WHERE IDPROMOCION=@Id;
END;
GO

IF OBJECT_ID('dbo.usp_promocion_publicas','P') IS NOT NULL DROP PROCEDURE dbo.usp_promocion_publicas;
GO
CREATE PROCEDURE dbo.usp_promocion_publicas
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IDPROMOCION, TIPO, TITULO, SUBTITULO, DESCRIPCION, PRECIO, PRECIOTEXTO, ENLACE, ESTILO, IMAGEN, ORDEN
    FROM PROMOCION WHERE ESTADO='Activo' ORDER BY TIPO, ORDEN, TITULO;
END;
GO

IF OBJECT_ID('dbo.usp_promocion_insertar','P') IS NOT NULL DROP PROCEDURE dbo.usp_promocion_insertar;
GO
CREATE PROCEDURE dbo.usp_promocion_insertar
    @Tipo NVARCHAR(20), @Titulo NVARCHAR(200), @Subtitulo NVARCHAR(120), @Descripcion NVARCHAR(500),
    @Precio DECIMAL(12,2), @PrecioTexto NVARCHAR(80), @Enlace NVARCHAR(80), @Estilo NVARCHAR(20),
    @Imagen NVARCHAR(MAX), @Orden INT, @Estado NVARCHAR(50),
    @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Id NVARCHAR(50), @Num INT;
    SET @Titulo = LTRIM(RTRIM(ISNULL(@Titulo,'')));
    IF @Titulo='' BEGIN SET @Resultado=0; SET @Mensaje='Ingresa el título.'; RETURN; END
    IF ISNULL(@Imagen,'')='' BEGIN SET @Resultado=0; SET @Mensaje='Agrega una imagen.'; RETURN; END
    IF @Tipo NOT IN ('slider','card') SET @Tipo='slider';
    SELECT @Num = ISNULL(MAX(TRY_CAST(SUBSTRING(IDPROMOCION, 4, 12) AS INT)), 0) + 1 FROM PROMOCION WHERE IDPROMOCION LIKE 'PRM%';
    SET @Id = 'PRM' + RIGHT('000000' + CAST(@Num AS VARCHAR(12)), 6);
    INSERT INTO PROMOCION (IDPROMOCION,TIPO,TITULO,SUBTITULO,DESCRIPCION,PRECIO,PRECIOTEXTO,ENLACE,ESTILO,IMAGEN,ORDEN,ESTADO,CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
    VALUES (@Id,@Tipo,@Titulo,NULLIF(@Subtitulo,''),NULLIF(@Descripcion,''),@Precio,NULLIF(@PrecioTexto,''),NULLIF(@Enlace,''),NULLIF(@Estilo,''),@Imagen,ISNULL(@Orden,0),ISNULL(@Estado,'Activo'),dbo.fn_actor(),dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108),dbo.fn_actor(),dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108));
    SET @Resultado=1; SET @Mensaje='Promoción registrada.';
END;
GO

IF OBJECT_ID('dbo.usp_promocion_actualizar','P') IS NOT NULL DROP PROCEDURE dbo.usp_promocion_actualizar;
GO
CREATE PROCEDURE dbo.usp_promocion_actualizar
    @Id NVARCHAR(50), @Tipo NVARCHAR(20), @Titulo NVARCHAR(200), @Subtitulo NVARCHAR(120), @Descripcion NVARCHAR(500),
    @Precio DECIMAL(12,2), @PrecioTexto NVARCHAR(80), @Enlace NVARCHAR(80), @Estilo NVARCHAR(20),
    @Imagen NVARCHAR(MAX), @Orden INT, @Estado NVARCHAR(50),
    @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM PROMOCION WHERE IDPROMOCION=@Id) BEGIN SET @Resultado=0; SET @Mensaje='La promoción no existe.'; RETURN; END
    SET @Titulo = LTRIM(RTRIM(ISNULL(@Titulo,'')));
    IF @Titulo='' BEGIN SET @Resultado=0; SET @Mensaje='Ingresa el título.'; RETURN; END
    IF ISNULL(@Imagen,'')='' BEGIN SET @Resultado=0; SET @Mensaje='Agrega una imagen.'; RETURN; END
    IF @Tipo NOT IN ('slider','card') SET @Tipo='slider';
    UPDATE PROMOCION SET TIPO=@Tipo, TITULO=@Titulo, SUBTITULO=NULLIF(@Subtitulo,''), DESCRIPCION=NULLIF(@Descripcion,''),
        PRECIO=@Precio, PRECIOTEXTO=NULLIF(@PrecioTexto,''), ENLACE=NULLIF(@Enlace,''), ESTILO=NULLIF(@Estilo,''),
        IMAGEN=@Imagen, ORDEN=ISNULL(@Orden,0), ESTADO=ISNULL(@Estado,'Activo'),
        MODIFICADOPOR=dbo.fn_actor(), FECHAMODIFICACION=dbo.fn_fecha_ddmmyyyy(), HORAMODIFICACION=CONVERT(CHAR(8),GETDATE(),108)
    WHERE IDPROMOCION=@Id;
    SET @Resultado=1; SET @Mensaje='Promoción actualizada.';
END;
GO

IF OBJECT_ID('dbo.usp_promocion_eliminar','P') IS NOT NULL DROP PROCEDURE dbo.usp_promocion_eliminar;
GO
CREATE PROCEDURE dbo.usp_promocion_eliminar @Id NVARCHAR(50), @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM PROMOCION WHERE IDPROMOCION=@Id) BEGIN SET @Resultado=0; SET @Mensaje='La promoción no existe.'; RETURN; END
    DELETE FROM PROMOCION WHERE IDPROMOCION=@Id;
    SET @Resultado=1; SET @Mensaje='Promoción eliminada.';
END;
GO

PRINT 'Módulo Catálogo / Promociones listo.';
GO

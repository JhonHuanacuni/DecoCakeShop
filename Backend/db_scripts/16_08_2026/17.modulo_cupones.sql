/* Incremental: módulo Cupones */
SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON;
GO

IF OBJECT_ID('dbo.CUPON','U') IS NULL
CREATE TABLE dbo.CUPON (
    IDCUPON             NVARCHAR(50)    NOT NULL PRIMARY KEY,
    CODIGO              NVARCHAR(40)    NOT NULL,
    DESCRIPCION         NVARCHAR(255)   NULL,
    TIPO                NVARCHAR(20)    NOT NULL,
    VALOR               DECIMAL(12,2)   NOT NULL,
    MINIMO              DECIMAL(12,2)   NULL,
    FECHAINICIO         CHAR(8)         NULL,
    FECHAFIN            CHAR(8)         NULL,
    USOSMAX             INT             NULL,
    USOS                INT             NOT NULL CONSTRAINT DF_CUPON_USOS DEFAULT (0),
    ESTADO              NVARCHAR(50)    NOT NULL,
    CREADOPOR           NVARCHAR(50)    NULL,
    FECHACREACION       CHAR(8)         NULL,
    HORACREACION        CHAR(8)         NULL,
    MODIFICADOPOR       NVARCHAR(50)    NULL,
    FECHAMODIFICACION   CHAR(8)         NULL,
    HORAMODIFICACION    CHAR(8)         NULL,
    CONSTRAINT UQ_CUPON_CODIGO UNIQUE (CODIGO)
);
GO

IF NOT EXISTS (SELECT 1 FROM dbo.MODULO WHERE IDMODULO = N'MOD010')
BEGIN
    UPDATE dbo.MODULO SET ORDEN = ORDEN + 1 WHERE ORDEN >= 7;
    INSERT INTO dbo.MODULO (IDMODULO, NOMBRE, DESCRIPCION, ICONO, ORDEN, ACTIVO)
    VALUES (N'MOD010', N'Cupones', N'Cupones de descuento de la tienda', N'faTicket', 7, 1);
END
ELSE
BEGIN
    UPDATE dbo.MODULO
    SET NOMBRE = N'Cupones', DESCRIPCION = N'Cupones de descuento de la tienda', ICONO = N'faTicket', ACTIVO = 1
    WHERE IDMODULO = N'MOD010';
END
GO

INSERT INTO dbo.GRUPO_MODULO (IDGRUPOMODULO, IDTIPOUSUARIO, IDMODULO, IDTIPOPERMISO)
SELECT N'GRM3MOD010' + p.IDTIPOPERMISO, N'3', N'MOD010', p.IDTIPOPERMISO
FROM dbo.TIPO_PERMISO p
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.GRUPO_MODULO g
    WHERE g.IDTIPOUSUARIO = N'3' AND g.IDMODULO = N'MOD010' AND g.IDTIPOPERMISO = p.IDTIPOPERMISO
);

INSERT INTO dbo.GRUPO_MODULO (IDGRUPOMODULO, IDTIPOUSUARIO, IDMODULO, IDTIPOPERMISO)
SELECT N'GRM1MOD010' + p.IDTIPOPERMISO, N'1', N'MOD010', p.IDTIPOPERMISO
FROM dbo.TIPO_PERMISO p
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.GRUPO_MODULO g
    WHERE g.IDTIPOUSUARIO = N'1' AND g.IDMODULO = N'MOD010' AND g.IDTIPOPERMISO = p.IDTIPOPERMISO
);
GO

IF OBJECT_ID('dbo.usp_cupon_listar','P') IS NOT NULL DROP PROCEDURE dbo.usp_cupon_listar;
GO
CREATE PROCEDURE dbo.usp_cupon_listar
    @Buscar NVARCHAR(200)=NULL, @Estado NVARCHAR(50)=NULL, @OrdenarPor NVARCHAR(50)='CODIGO',
    @Direccion NVARCHAR(4)='ASC', @Pagina INT=1, @TamanioPagina INT=10, @TotalRegistros INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF @Pagina<1 SET @Pagina=1; IF @TamanioPagina<1 SET @TamanioPagina=10;
    SELECT @TotalRegistros = COUNT(*) FROM CUPON c
    WHERE (@Buscar IS NULL OR @Buscar='' OR c.IDCUPON LIKE '%'+@Buscar+'%' OR c.CODIGO LIKE '%'+@Buscar+'%' OR ISNULL(c.DESCRIPCION,'') LIKE '%'+@Buscar+'%')
      AND (@Estado IS NULL OR @Estado='' OR c.ESTADO=@Estado);
    SELECT c.*, cu.NOMBRE+' '+cu.APELLIDO AS CREADOPOR_NOMBRE, mu.NOMBRE+' '+mu.APELLIDO AS MODIFICADOPOR_NOMBRE
    FROM CUPON c
    LEFT JOIN USUARIO cu ON cu.IDUSUARIO=c.CREADOPOR
    LEFT JOIN USUARIO mu ON mu.IDUSUARIO=c.MODIFICADOPOR
    WHERE (@Buscar IS NULL OR @Buscar='' OR c.IDCUPON LIKE '%'+@Buscar+'%' OR c.CODIGO LIKE '%'+@Buscar+'%' OR ISNULL(c.DESCRIPCION,'') LIKE '%'+@Buscar+'%')
      AND (@Estado IS NULL OR @Estado='' OR c.ESTADO=@Estado)
    ORDER BY
        CASE WHEN @OrdenarPor='CODIGO' AND @Direccion='ASC' THEN c.CODIGO END ASC,
        CASE WHEN @OrdenarPor='CODIGO' AND @Direccion='DESC' THEN c.CODIGO END DESC,
        CASE WHEN @OrdenarPor='TIPO' AND @Direccion='ASC' THEN c.TIPO END ASC,
        CASE WHEN @OrdenarPor='TIPO' AND @Direccion='DESC' THEN c.TIPO END DESC,
        CASE WHEN @OrdenarPor='VALOR' AND @Direccion='ASC' THEN c.VALOR END ASC,
        CASE WHEN @OrdenarPor='VALOR' AND @Direccion='DESC' THEN c.VALOR END DESC,
        CASE WHEN @OrdenarPor='ESTADO' AND @Direccion='ASC' THEN c.ESTADO END ASC,
        CASE WHEN @OrdenarPor='ESTADO' AND @Direccion='DESC' THEN c.ESTADO END DESC,
        c.CODIGO
    OFFSET (@Pagina-1)*@TamanioPagina ROWS FETCH NEXT @TamanioPagina ROWS ONLY;
END;
GO

IF OBJECT_ID('dbo.usp_cupon_obtener','P') IS NOT NULL DROP PROCEDURE dbo.usp_cupon_obtener;
GO
CREATE PROCEDURE dbo.usp_cupon_obtener @Id NVARCHAR(50)
AS BEGIN SET NOCOUNT ON; SELECT * FROM CUPON WHERE IDCUPON=@Id; END;
GO

IF OBJECT_ID('dbo.usp_cupon_insertar','P') IS NOT NULL DROP PROCEDURE dbo.usp_cupon_insertar;
GO
CREATE PROCEDURE dbo.usp_cupon_insertar
    @Codigo NVARCHAR(40), @Descripcion NVARCHAR(255)=NULL, @Tipo NVARCHAR(20)='Porcentaje',
    @Valor DECIMAL(12,2)=0, @Minimo DECIMAL(12,2)=NULL, @FechaInicio CHAR(8)=NULL, @FechaFin CHAR(8)=NULL,
    @UsosMax INT=NULL, @Estado NVARCHAR(50)='Activo',
    @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @Codigo = UPPER(LTRIM(RTRIM(ISNULL(@Codigo,''))));
    IF @Codigo='' BEGIN SET @Resultado=0; SET @Mensaje='Ingresa el código del cupón.'; RETURN; END
    IF EXISTS (SELECT 1 FROM CUPON WHERE CODIGO=@Codigo) BEGIN SET @Resultado=0; SET @Mensaje='Ya existe un cupón con ese código.'; RETURN; END
    IF ISNULL(@Valor,0) <= 0 BEGIN SET @Resultado=0; SET @Mensaje='Ingresa un valor mayor a cero.'; RETURN; END
    IF @Tipo NOT IN ('Porcentaje','Monto') SET @Tipo='Porcentaje';
    DECLARE @Id NVARCHAR(50); EXEC dbo.usp_siguiente_id 'CUP','CUPON','IDCUPON',@Id OUTPUT;
    INSERT INTO CUPON (IDCUPON,CODIGO,DESCRIPCION,TIPO,VALOR,MINIMO,FECHAINICIO,FECHAFIN,USOSMAX,USOS,ESTADO,CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
    VALUES (@Id,@Codigo,@Descripcion,@Tipo,ISNULL(@Valor,0),@Minimo,NULLIF(@FechaInicio,''),NULLIF(@FechaFin,''),@UsosMax,0,ISNULL(@Estado,'Activo'),dbo.fn_actor(),dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108),dbo.fn_actor(),dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108));
    SET @Resultado=1; SET @Mensaje='Cupón registrado.';
END;
GO

IF OBJECT_ID('dbo.usp_cupon_actualizar','P') IS NOT NULL DROP PROCEDURE dbo.usp_cupon_actualizar;
GO
CREATE PROCEDURE dbo.usp_cupon_actualizar
    @Id NVARCHAR(50), @Codigo NVARCHAR(40), @Descripcion NVARCHAR(255)=NULL, @Tipo NVARCHAR(20)='Porcentaje',
    @Valor DECIMAL(12,2)=0, @Minimo DECIMAL(12,2)=NULL, @FechaInicio CHAR(8)=NULL, @FechaFin CHAR(8)=NULL,
    @UsosMax INT=NULL, @Estado NVARCHAR(50)='Activo',
    @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM CUPON WHERE IDCUPON=@Id) BEGIN SET @Resultado=0; SET @Mensaje='El cupón no existe.'; RETURN; END
    SET @Codigo = UPPER(LTRIM(RTRIM(ISNULL(@Codigo,''))));
    IF @Codigo='' BEGIN SET @Resultado=0; SET @Mensaje='Ingresa el código del cupón.'; RETURN; END
    IF EXISTS (SELECT 1 FROM CUPON WHERE CODIGO=@Codigo AND IDCUPON<>@Id) BEGIN SET @Resultado=0; SET @Mensaje='Ya existe un cupón con ese código.'; RETURN; END
    IF @Tipo NOT IN ('Porcentaje','Monto') SET @Tipo='Porcentaje';
    UPDATE CUPON SET CODIGO=@Codigo, DESCRIPCION=@Descripcion, TIPO=@Tipo, VALOR=ISNULL(@Valor,0), MINIMO=@Minimo,
        FECHAINICIO=NULLIF(@FechaInicio,''), FECHAFIN=NULLIF(@FechaFin,''), USOSMAX=@UsosMax, ESTADO=ISNULL(@Estado,'Activo'),
        MODIFICADOPOR=dbo.fn_actor(), FECHAMODIFICACION=dbo.fn_fecha_ddmmyyyy(), HORAMODIFICACION=CONVERT(CHAR(8),GETDATE(),108)
    WHERE IDCUPON=@Id;
    SET @Resultado=1; SET @Mensaje='Cupón actualizado.';
END;
GO

IF OBJECT_ID('dbo.usp_cupon_eliminar','P') IS NOT NULL DROP PROCEDURE dbo.usp_cupon_eliminar;
GO
CREATE PROCEDURE dbo.usp_cupon_eliminar @Id NVARCHAR(50), @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM CUPON WHERE IDCUPON=@Id) BEGIN SET @Resultado=0; SET @Mensaje='El cupón no existe.'; RETURN; END
    DELETE FROM CUPON WHERE IDCUPON=@Id;
    SET @Resultado=1; SET @Mensaje='Cupón eliminado.';
END;
GO

IF OBJECT_ID('dbo.usp_cupon_validar','P') IS NOT NULL DROP PROCEDURE dbo.usp_cupon_validar;
GO
CREATE PROCEDURE dbo.usp_cupon_validar @Codigo NVARCHAR(40), @Subtotal DECIMAL(12,2)=0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Hoy DATE = CONVERT(date, GETDATE());
    SELECT TOP 1 c.IDCUPON, c.CODIGO, c.DESCRIPCION, c.TIPO, c.VALOR, c.MINIMO, c.ESTADO
    FROM CUPON c
    WHERE c.CODIGO = UPPER(LTRIM(RTRIM(ISNULL(@Codigo,''))))
      AND c.ESTADO='Activo'
      AND (c.USOSMAX IS NULL OR c.USOS < c.USOSMAX)
      AND (c.MINIMO IS NULL OR c.MINIMO=0 OR @Subtotal >= c.MINIMO)
      AND (c.FECHAINICIO IS NULL OR c.FECHAINICIO='' OR TRY_CONVERT(date, STUFF(STUFF(c.FECHAINICIO,5,0,'/'),3,0,'/'), 103) <= @Hoy)
      AND (c.FECHAFIN IS NULL OR c.FECHAFIN='' OR TRY_CONVERT(date, STUFF(STUFF(c.FECHAFIN,5,0,'/'),3,0,'/'), 103) >= @Hoy);
END;
GO

IF OBJECT_ID('dbo.usp_cupon_usar','P') IS NOT NULL DROP PROCEDURE dbo.usp_cupon_usar;
GO
CREATE PROCEDURE dbo.usp_cupon_usar @Codigo NVARCHAR(40), @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE CUPON SET USOS = USOS + 1,
        MODIFICADOPOR=dbo.fn_actor(), FECHAMODIFICACION=dbo.fn_fecha_ddmmyyyy(), HORAMODIFICACION=CONVERT(CHAR(8),GETDATE(),108)
    WHERE CODIGO = UPPER(LTRIM(RTRIM(ISNULL(@Codigo,'')))) AND ESTADO='Activo';
    IF @@ROWCOUNT=0 BEGIN SET @Resultado=0; SET @Mensaje='No se pudo registrar el uso del cupón.'; RETURN; END
    SET @Resultado=1; SET @Mensaje='Cupón aplicado.';
END;
GO

IF NOT EXISTS (SELECT 1 FROM CUPON WHERE CODIGO=N'DULCE10')
INSERT INTO CUPON (IDCUPON,CODIGO,DESCRIPCION,TIPO,VALOR,MINIMO,USOSMAX,USOS,ESTADO,CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
VALUES (N'CUP001',N'DULCE10',N'10% de descuento en el catálogo',N'Porcentaje',10,0,200,0,N'Activo',N'sistema',dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108),N'sistema',dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108));

IF NOT EXISTS (SELECT 1 FROM CUPON WHERE CODIGO=N'BIENVENIDA')
INSERT INTO CUPON (IDCUPON,CODIGO,DESCRIPCION,TIPO,VALOR,MINIMO,USOSMAX,USOS,ESTADO,CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
VALUES (N'CUP002',N'BIENVENIDA',N'S/ 5.00 de descuento de bienvenida',N'Monto',5,20,100,0,N'Activo',N'sistema',dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108),N'sistema',dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108));

IF NOT EXISTS (SELECT 1 FROM CUPON WHERE CODIGO=N'REPOSTERA')
INSERT INTO CUPON (IDCUPON,CODIGO,DESCRIPCION,TIPO,VALOR,MINIMO,USOSMAX,USOS,ESTADO,CREADOPOR,FECHACREACION,HORACREACION,MODIFICADOPOR,FECHAMODIFICACION,HORAMODIFICACION)
VALUES (N'CUP003',N'REPOSTERA',N'15% desde S/ 80.00',N'Porcentaje',15,80,80,0,N'Activo',N'sistema',dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108),N'sistema',dbo.fn_fecha_ddmmyyyy(),CONVERT(CHAR(8),GETDATE(),108));
GO

IF OBJECT_ID('dbo.usp_auditoria_instalar_trigger','P') IS NOT NULL
    EXEC dbo.usp_auditoria_instalar_trigger 'CUPON','IDCUPON';
GO

PRINT 'Módulo Cupones listo.';
GO

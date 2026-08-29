/* ============================================================================
   DECOCAKE SHOP — Stored procedures CRUD
   Ejecutar después de 1.esquema_completo.sql
   ============================================================================ */
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF OBJECT_ID('dbo.usp_siguiente_id', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_siguiente_id;
GO
CREATE PROCEDURE dbo.usp_siguiente_id
    @Prefijo NVARCHAR(10),
    @Tabla   SYSNAME,
    @Columna SYSNAME,
    @Id      NVARCHAR(50) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Sql NVARCHAR(MAX);
    DECLARE @Num INT = 1;
    DECLARE @Like NVARCHAR(20) = CONCAT(@Prefijo, CHAR(37));
    SET @Sql = CONCAT(
        N'SELECT @NumOut = ISNULL(MAX(TRY_CAST(SUBSTRING(', QUOTENAME(@Columna),
        N', ', CAST(LEN(@Prefijo) + 1 AS VARCHAR(10)),
        N', 12) AS INT)), 0) + 1 FROM dbo.', QUOTENAME(@Tabla),
        N' WHERE ', QUOTENAME(@Columna), N' LIKE @Like');
    EXEC sp_executesql @Sql,
        N'@NumOut INT OUTPUT, @Like NVARCHAR(20)',
        @NumOut = @Num OUTPUT, @Like = @Like;
    SET @Id = CONCAT(@Prefijo, RIGHT(CONCAT('000000', CAST(@Num AS VARCHAR(12))), 6));
END;
GO

/* ---------- USUARIO ---------- */
IF OBJECT_ID('dbo.usp_usuario_listar', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_usuario_listar;
GO
CREATE PROCEDURE dbo.usp_usuario_listar
    @Buscar NVARCHAR(200)=NULL, @Estado NVARCHAR(50)=NULL,
    @OrdenarPor NVARCHAR(50)='IDUSUARIO', @Direccion NVARCHAR(4)='ASC',
    @Pagina INT=1, @TamanioPagina INT=10, @TotalRegistros INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF @Pagina < 1 SET @Pagina = 1;
    IF @TamanioPagina < 1 SET @TamanioPagina = 10;
    SELECT @TotalRegistros = COUNT(*)
    FROM USUARIO u
    INNER JOIN TIPOUSUARIO t ON t.IDTIPOUSUARIO = u.IDTIPOUSUARIO
    WHERE (@Buscar IS NULL OR @Buscar = '' OR u.IDUSUARIO LIKE '%'+@Buscar+'%' OR u.NOMBRE LIKE '%'+@Buscar+'%'
           OR u.APELLIDO LIKE '%'+@Buscar+'%' OR u.DNI LIKE '%'+@Buscar+'%' OR u.EMAIL LIKE '%'+@Buscar+'%')
      AND (@Estado IS NULL OR @Estado = '' OR u.ESTADO = @Estado);

    SELECT u.IDUSUARIO, u.NOMBRE, u.APELLIDO, u.DNI, u.EMAIL, u.TELEFONO, u.DIRECCION, u.ESTADO,
           u.IDTIPOUSUARIO, t.DESCRIPCION AS TIPOUSUARIO_DESCRIPCION,
           u.CREADOPOR, u.FECHACREACION, u.HORACREACION, u.MODIFICADOPOR, u.FECHAMODIFICACION, u.HORAMODIFICACION
    FROM USUARIO u
    INNER JOIN TIPOUSUARIO t ON t.IDTIPOUSUARIO = u.IDTIPOUSUARIO
    WHERE (@Buscar IS NULL OR @Buscar = '' OR u.IDUSUARIO LIKE '%'+@Buscar+'%' OR u.NOMBRE LIKE '%'+@Buscar+'%'
           OR u.APELLIDO LIKE '%'+@Buscar+'%' OR u.DNI LIKE '%'+@Buscar+'%' OR u.EMAIL LIKE '%'+@Buscar+'%')
      AND (@Estado IS NULL OR @Estado = '' OR u.ESTADO = @Estado)
    ORDER BY
        CASE WHEN @OrdenarPor='NOMBRE' AND @Direccion='ASC' THEN u.NOMBRE END ASC,
        CASE WHEN @OrdenarPor='NOMBRE' AND @Direccion='DESC' THEN u.NOMBRE END DESC,
        CASE WHEN @OrdenarPor='APELLIDO' AND @Direccion='ASC' THEN u.APELLIDO END ASC,
        CASE WHEN @OrdenarPor='APELLIDO' AND @Direccion='DESC' THEN u.APELLIDO END DESC,
        CASE WHEN @OrdenarPor='DNI' AND @Direccion='ASC' THEN u.DNI END ASC,
        CASE WHEN @OrdenarPor='DNI' AND @Direccion='DESC' THEN u.DNI END DESC,
        CASE WHEN @OrdenarPor='ESTADO' AND @Direccion='ASC' THEN u.ESTADO END ASC,
        CASE WHEN @OrdenarPor='ESTADO' AND @Direccion='DESC' THEN u.ESTADO END DESC,
        u.IDUSUARIO
    OFFSET (@Pagina-1)*@TamanioPagina ROWS FETCH NEXT @TamanioPagina ROWS ONLY;
END;
GO

IF OBJECT_ID('dbo.usp_usuario_obtener', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_usuario_obtener;
GO
CREATE PROCEDURE dbo.usp_usuario_obtener @Id NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.*, t.DESCRIPCION AS TIPOUSUARIO_DESCRIPCION
    FROM USUARIO u INNER JOIN TIPOUSUARIO t ON t.IDTIPOUSUARIO = u.IDTIPOUSUARIO
    WHERE u.IDUSUARIO = @Id;
END;
GO

IF OBJECT_ID('dbo.usp_usuario_insertar', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_usuario_insertar;
GO
CREATE PROCEDURE dbo.usp_usuario_insertar
    @Id NVARCHAR(50), @Contra NVARCHAR(255), @Nombre NVARCHAR(100), @Apellido NVARCHAR(100),
    @Dni NVARCHAR(20), @Email NVARCHAR(150), @Telefono NVARCHAR(20)=NULL, @Direccion NVARCHAR(255)=NULL,
    @IdTipoUsuario NVARCHAR(50), @Estado NVARCHAR(50)='Activo', @Foto NVARCHAR(MAX)=NULL,
    @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM USUARIO WHERE IDUSUARIO=@Id) BEGIN SET @Resultado=0; SET @Mensaje='El usuario ya existe.'; RETURN; END
    IF EXISTS (SELECT 1 FROM USUARIO WHERE DNI=@Dni) BEGIN SET @Resultado=0; SET @Mensaje='El DNI ya está registrado.'; RETURN; END
    IF EXISTS (SELECT 1 FROM USUARIO WHERE EMAIL=@Email) BEGIN SET @Resultado=0; SET @Mensaje='El email ya está registrado.'; RETURN; END
    INSERT INTO USUARIO (IDUSUARIO, CONTRA, NOMBRE, APELLIDO, DNI, EMAIL, TELEFONO, DIRECCION, ESTADO, FOTO, IDTIPOUSUARIO,
        CREADOPOR, FECHACREACION, HORACREACION, MODIFICADOPOR, FECHAMODIFICACION, HORAMODIFICACION)
    VALUES (@Id, ISNULL(NULLIF(@Contra,''), @Dni), @Nombre, @Apellido, @Dni, @Email, @Telefono, @Direccion,
        ISNULL(@Estado,'Activo'), @Foto, @IdTipoUsuario,
        dbo.fn_actor(), dbo.fn_fecha_ddmmyyyy(), CONVERT(CHAR(8), GETDATE(), 108),
        dbo.fn_actor(), dbo.fn_fecha_ddmmyyyy(), CONVERT(CHAR(8), GETDATE(), 108));
    SET @Resultado=1; SET @Mensaje='Usuario registrado.';
END;
GO

IF OBJECT_ID('dbo.usp_usuario_actualizar', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_usuario_actualizar;
GO
CREATE PROCEDURE dbo.usp_usuario_actualizar
    @Id NVARCHAR(50), @Contra NVARCHAR(255)=NULL, @Nombre NVARCHAR(100), @Apellido NVARCHAR(100),
    @Dni NVARCHAR(20), @Email NVARCHAR(150), @Telefono NVARCHAR(20)=NULL, @Direccion NVARCHAR(255)=NULL,
    @IdTipoUsuario NVARCHAR(50), @Estado NVARCHAR(50), @Foto NVARCHAR(MAX)=NULL, @ActualizarFoto INT=0,
    @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM USUARIO WHERE IDUSUARIO=@Id) BEGIN SET @Resultado=0; SET @Mensaje='El usuario no existe.'; RETURN; END
    UPDATE USUARIO SET
        CONTRA = CASE WHEN @Contra IS NULL OR LTRIM(RTRIM(@Contra))='' THEN CONTRA ELSE @Contra END,
        NOMBRE=@Nombre, APELLIDO=@Apellido, DNI=@Dni, EMAIL=@Email, TELEFONO=@Telefono, DIRECCION=@Direccion,
        IDTIPOUSUARIO=@IdTipoUsuario, ESTADO=@Estado,
        FOTO = CASE WHEN @ActualizarFoto=1 THEN @Foto ELSE FOTO END,
        MODIFICADOPOR=dbo.fn_actor(), FECHAMODIFICACION=dbo.fn_fecha_ddmmyyyy(), HORAMODIFICACION=CONVERT(CHAR(8), GETDATE(), 108)
    WHERE IDUSUARIO=@Id;
    SET @Resultado=1; SET @Mensaje='Usuario actualizado.';
END;
GO

IF OBJECT_ID('dbo.usp_usuario_eliminar', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_usuario_eliminar;
GO
CREATE PROCEDURE dbo.usp_usuario_eliminar @Id NVARCHAR(50), @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM USUARIO WHERE IDUSUARIO=@Id) BEGIN SET @Resultado=0; SET @Mensaje='El usuario no existe.'; RETURN; END
    IF @Id IN ('admin','vendedor','almacen') BEGIN SET @Resultado=0; SET @Mensaje='No se puede eliminar un usuario de sistema.'; RETURN; END
    DELETE FROM USUARIO_MODULO WHERE IDUSUARIO=@Id;
    DELETE FROM USUARIO_MODULO_EXCLUIDO WHERE IDUSUARIO=@Id;
    DELETE FROM USUARIO_SUBMODULO_EXCLUIDO WHERE IDUSUARIO=@Id;
    DELETE FROM USUARIO WHERE IDUSUARIO=@Id;
    SET @Resultado=1; SET @Mensaje='Usuario eliminado.';
END;
GO

IF OBJECT_ID('dbo.usp_usuario_resetear_contra', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_usuario_resetear_contra;
GO
CREATE PROCEDURE dbo.usp_usuario_resetear_contra @Id NVARCHAR(50), @Resultado INT OUTPUT, @Mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM USUARIO WHERE IDUSUARIO=@Id) BEGIN SET @Resultado=0; SET @Mensaje='El usuario no existe.'; RETURN; END
    UPDATE USUARIO SET CONTRA=DNI, MODIFICADOPOR=dbo.fn_actor(),
        FECHAMODIFICACION=dbo.fn_fecha_ddmmyyyy(), HORAMODIFICACION=CONVERT(CHAR(8), GETDATE(), 108)
    WHERE IDUSUARIO=@Id;
    SET @Resultado=1; SET @Mensaje='Contraseña restablecida al DNI.';
END;
GO

PRINT 'SPs usuario listos.';
GO

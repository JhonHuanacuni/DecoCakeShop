SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON;
GO

IF OBJECT_ID('dbo.usp_auditoria_siguiente_id','P') IS NOT NULL DROP PROCEDURE dbo.usp_auditoria_siguiente_id;
GO
CREATE PROCEDURE dbo.usp_auditoria_siguiente_id @Id NVARCHAR(50) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Num INT = 1;
    SELECT @Num = ISNULL(MAX(TRY_CAST(SUBSTRING(IDAUDITORIA, 4, 10) AS INT)), 0) + 1
    FROM dbo.AUDITORIA WHERE IDAUDITORIA LIKE 'AUD%';
    SET @Id = 'AUD' + RIGHT('000000' + CAST(@Num AS VARCHAR(10)), 6);
END;
GO

IF OBJECT_ID('dbo.usp_auditoria_listar','P') IS NOT NULL DROP PROCEDURE dbo.usp_auditoria_listar;
GO
CREATE PROCEDURE dbo.usp_auditoria_listar
    @Buscar NVARCHAR(200)=NULL, @Tabla NVARCHAR(100)=NULL, @Accion NVARCHAR(20)=NULL,
    @IdUsuario NVARCHAR(50)=NULL, @FechaDesde CHAR(8)=NULL, @FechaHasta CHAR(8)=NULL,
    @OrdenarPor NVARCHAR(50)='FECHA', @Direccion NVARCHAR(4)='DESC',
    @Pagina INT=1, @TamanioPagina INT=10, @TotalRegistros INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRegistros = COUNT(*)
    FROM AUDITORIA a LEFT JOIN USUARIO u ON u.IDUSUARIO=a.IDUSUARIO
    WHERE (@Buscar IS NULL OR @Buscar='' OR a.TABLA LIKE '%'+@Buscar+'%' OR a.IDREGISTRO LIKE '%'+@Buscar+'%'
           OR ISNULL(u.NOMBRE,'')+' '+ISNULL(u.APELLIDO,'') LIKE '%'+@Buscar+'%')
      AND (@Tabla IS NULL OR @Tabla='' OR a.TABLA=@Tabla)
      AND (@Accion IS NULL OR @Accion='' OR a.ACCION=@Accion)
      AND (@IdUsuario IS NULL OR @IdUsuario='' OR a.IDUSUARIO=@IdUsuario)
      AND (@FechaDesde IS NULL OR @FechaDesde='' OR a.FECHA>=@FechaDesde)
      AND (@FechaHasta IS NULL OR @FechaHasta='' OR a.FECHA<=@FechaHasta);

    SELECT a.IDAUDITORIA, a.TABLA, a.IDREGISTRO, a.ACCION, a.IDUSUARIO,
           LTRIM(RTRIM(ISNULL(u.NOMBRE,'')+' '+ISNULL(u.APELLIDO,''))) AS USUARIO_NOMBRE,
           a.FECHA, a.HORA, a.DATOS_ANTES, a.DATOS_DESPUES
    FROM AUDITORIA a LEFT JOIN USUARIO u ON u.IDUSUARIO=a.IDUSUARIO
    WHERE (@Buscar IS NULL OR @Buscar='' OR a.TABLA LIKE '%'+@Buscar+'%' OR a.IDREGISTRO LIKE '%'+@Buscar+'%'
           OR ISNULL(u.NOMBRE,'')+' '+ISNULL(u.APELLIDO,'') LIKE '%'+@Buscar+'%')
      AND (@Tabla IS NULL OR @Tabla='' OR a.TABLA=@Tabla)
      AND (@Accion IS NULL OR @Accion='' OR a.ACCION=@Accion)
      AND (@IdUsuario IS NULL OR @IdUsuario='' OR a.IDUSUARIO=@IdUsuario)
      AND (@FechaDesde IS NULL OR @FechaDesde='' OR a.FECHA>=@FechaDesde)
      AND (@FechaHasta IS NULL OR @FechaHasta='' OR a.FECHA<=@FechaHasta)
    ORDER BY a.FECHA DESC, a.HORA DESC, a.IDAUDITORIA DESC
    OFFSET (@Pagina-1)*@TamanioPagina ROWS FETCH NEXT @TamanioPagina ROWS ONLY;
END;
GO

IF OBJECT_ID('dbo.usp_auditoria_obtener','P') IS NOT NULL DROP PROCEDURE dbo.usp_auditoria_obtener;
GO
CREATE PROCEDURE dbo.usp_auditoria_obtener @Id NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT a.*, LTRIM(RTRIM(ISNULL(u.NOMBRE,'')+' '+ISNULL(u.APELLIDO,''))) AS USUARIO_NOMBRE
    FROM AUDITORIA a LEFT JOIN USUARIO u ON u.IDUSUARIO=a.IDUSUARIO
    WHERE a.IDAUDITORIA=@Id;
END;
GO

IF OBJECT_ID('dbo.usp_auditoria_tablas_catalogo','P') IS NOT NULL DROP PROCEDURE dbo.usp_auditoria_tablas_catalogo;
GO
CREATE PROCEDURE dbo.usp_auditoria_tablas_catalogo
AS BEGIN SET NOCOUNT ON; SELECT DISTINCT TABLA FROM AUDITORIA ORDER BY TABLA; END;
GO

IF OBJECT_ID('dbo.usp_auditoria_instalar_trigger','P') IS NOT NULL DROP PROCEDURE dbo.usp_auditoria_instalar_trigger;
GO
CREATE PROCEDURE dbo.usp_auditoria_instalar_trigger @Tabla SYSNAME, @ColumnaPk SYSNAME
AS
BEGIN
    SET NOCOUNT ON;
    IF OBJECT_ID(QUOTENAME('dbo')+'.'+QUOTENAME(@Tabla),'U') IS NULL RETURN;
    DECLARE @Trigger SYSNAME = N'tr_' + @Tabla + N'_auditoria';
    DECLARE @Sql NVARCHAR(MAX);
    IF OBJECT_ID(@Trigger,'TR') IS NOT NULL
    BEGIN
        SET @Sql = N'DROP TRIGGER dbo.' + QUOTENAME(@Trigger) + N';';
        EXEC sp_executesql @Sql;
    END
    SET @Sql = N'
CREATE TRIGGER dbo.' + QUOTENAME(@Trigger) + N'
ON dbo.' + QUOTENAME(@Tabla) + N'
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @IdUsuario NVARCHAR(50) = TRY_CAST(SESSION_CONTEXT(N''IDUSUARIO'') AS NVARCHAR(50));
    DECLARE @Fecha CHAR(8) = dbo.fn_fecha_ddmmyyyy();
    DECLARE @Hora CHAR(8) = CONVERT(CHAR(8), GETDATE(), 108);
    DECLARE @IdAud NVARCHAR(50), @IdReg NVARCHAR(50), @JsonAntes NVARCHAR(MAX), @JsonDespues NVARCHAR(MAX);
    DECLARE @TablaNombre NVARCHAR(100) = N''' + @Tabla + N''';
    IF EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted)
    BEGIN
        DECLARE curIns CURSOR LOCAL FAST_FORWARD FOR
            SELECT CAST(i.' + QUOTENAME(@ColumnaPk) + N' AS NVARCHAR(50)), (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
            FROM inserted i;
        OPEN curIns; FETCH NEXT FROM curIns INTO @IdReg, @JsonDespues;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC dbo.usp_auditoria_siguiente_id @Id=@IdAud OUTPUT;
            INSERT INTO dbo.AUDITORIA (IDAUDITORIA,TABLA,IDREGISTRO,ACCION,IDUSUARIO,FECHA,HORA,DATOS_ANTES,DATOS_DESPUES)
            VALUES (@IdAud,@TablaNombre,@IdReg,N''INSERT'',@IdUsuario,@Fecha,@Hora,NULL,@JsonDespues);
            FETCH NEXT FROM curIns INTO @IdReg, @JsonDespues;
        END
        CLOSE curIns; DEALLOCATE curIns;
    END
    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        DECLARE curUpd CURSOR LOCAL FAST_FORWARD FOR
            SELECT CAST(i.' + QUOTENAME(@ColumnaPk) + N' AS NVARCHAR(50)),
                   (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
                   (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
            FROM inserted i INNER JOIN deleted d ON i.' + QUOTENAME(@ColumnaPk) + N' = d.' + QUOTENAME(@ColumnaPk) + N';
        OPEN curUpd; FETCH NEXT FROM curUpd INTO @IdReg, @JsonAntes, @JsonDespues;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC dbo.usp_auditoria_siguiente_id @Id=@IdAud OUTPUT;
            INSERT INTO dbo.AUDITORIA (IDAUDITORIA,TABLA,IDREGISTRO,ACCION,IDUSUARIO,FECHA,HORA,DATOS_ANTES,DATOS_DESPUES)
            VALUES (@IdAud,@TablaNombre,@IdReg,N''UPDATE'',@IdUsuario,@Fecha,@Hora,@JsonAntes,@JsonDespues);
            FETCH NEXT FROM curUpd INTO @IdReg, @JsonAntes, @JsonDespues;
        END
        CLOSE curUpd; DEALLOCATE curUpd;
    END
    IF EXISTS (SELECT 1 FROM deleted) AND NOT EXISTS (SELECT 1 FROM inserted)
    BEGIN
        DECLARE curDel CURSOR LOCAL FAST_FORWARD FOR
            SELECT CAST(d.' + QUOTENAME(@ColumnaPk) + N' AS NVARCHAR(50)), (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
            FROM deleted d;
        OPEN curDel; FETCH NEXT FROM curDel INTO @IdReg, @JsonAntes;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC dbo.usp_auditoria_siguiente_id @Id=@IdAud OUTPUT;
            INSERT INTO dbo.AUDITORIA (IDAUDITORIA,TABLA,IDREGISTRO,ACCION,IDUSUARIO,FECHA,HORA,DATOS_ANTES,DATOS_DESPUES)
            VALUES (@IdAud,@TablaNombre,@IdReg,N''DELETE'',@IdUsuario,@Fecha,@Hora,@JsonAntes,NULL);
            FETCH NEXT FROM curDel INTO @IdReg, @JsonAntes;
        END
        CLOSE curDel; DEALLOCATE curDel;
    END
END;';
    EXEC sp_executesql @Sql;
    PRINT 'Trigger instalado: ' + @Trigger;
END;
GO

EXEC dbo.usp_auditoria_instalar_trigger 'USUARIO','IDUSUARIO';
EXEC dbo.usp_auditoria_instalar_trigger 'CATEGORIA','IDCATEGORIA';
EXEC dbo.usp_auditoria_instalar_trigger 'UNIDAD','IDUNIDAD';
EXEC dbo.usp_auditoria_instalar_trigger 'CLIENTE','IDCLIENTE';
EXEC dbo.usp_auditoria_instalar_trigger 'FORMA_PAGO','IDFORMAPAGO';
EXEC dbo.usp_auditoria_instalar_trigger 'TIPO_ENTREGA','IDTIPOENTREGA';
EXEC dbo.usp_auditoria_instalar_trigger 'PRODUCTO','IDPRODUCTO';
EXEC dbo.usp_auditoria_instalar_trigger 'COTIZACION','IDCOTIZACION';
EXEC dbo.usp_auditoria_instalar_trigger 'COTIZACION_PAGO','IDPAGO';
EXEC dbo.usp_auditoria_instalar_trigger 'VENTA','IDVENTA';
GO
PRINT 'Auditoría instalada.';
GO

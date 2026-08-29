/* Incremental: búsqueda de clientes desde 3 caracteres */
SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON;
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
    WHERE ESTADO = 'Activo'
      AND NOMBRE LIKE '%'+@q+'%'
    ORDER BY NOMBRE;
END;
GO

PRINT 'Búsqueda de clientes lista.';
GO

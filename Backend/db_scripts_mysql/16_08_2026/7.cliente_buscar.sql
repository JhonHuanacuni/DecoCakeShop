-- Convertido desde db_scripts/16_08_2026/7.cliente_buscar.sql
-- MySQL 8 — DecoCake Shop

USE `DecoCakeShop`;

/* Incremental: búsqueda de clientes desde 3 caracteres */

DROP PROCEDURE IF EXISTS usp_cliente_buscar;

DROP PROCEDURE IF EXISTS usp_cliente_buscar;

DELIMITER $$

CREATE PROCEDURE usp_cliente_buscar(
    IN p_Buscar VARCHAR(200)
)
main: BEGIN
DECLARE v_q VARCHAR(200);
    SET v_q = TRIM(IFNULL(p_Buscar,'')); 
    IF CHAR_LENGTH(v_q) < 3 THEN LEAVE main; END IF;
    SELECT IDCLIENTE AS value, NOMBRE AS label
    FROM CLIENTE
    WHERE ESTADO = 'Activo'
      AND NOMBRE LIKE CONCAT('%', v_q, '%')
    ORDER BY NOMBRE LIMIT 10;
END$$

DELIMITER ;

SELECT 'Búsqueda de clientes lista.';

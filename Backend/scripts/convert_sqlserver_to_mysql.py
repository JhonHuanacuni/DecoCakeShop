"""
Convierte scripts T-SQL (SQL Server) de db_scripts/ a MySQL 8 en db_scripts_mysql/.

Uso (desde Backend/):
  python scripts/convert_sqlserver_to_mysql.py
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
SRC_DIR = BASE_DIR / 'db_scripts'
DST_DIR = BASE_DIR / 'db_scripts_mysql'
DB_NAME = 'DecoCakeShop'

SKIP_FILES = {
    '12.datos_prueba_cotizacion_venta.sql',
}

TYPE_MAP = [
    (re.compile(r'\bNVARCHAR\s*\(\s*MAX\s*\)', re.I), 'LONGTEXT'),
    (re.compile(r'\bNVARCHAR\s*\(\s*(\d+)\s*\)', re.I), r'VARCHAR(\1)'),
    (re.compile(r'\bVARCHAR\s*\(\s*MAX\s*\)', re.I), 'LONGTEXT'),
    (re.compile(r'\bSYSNAME\b', re.I), 'VARCHAR(128)'),
    (re.compile(r'\bBIT\b', re.I), 'TINYINT(1)'),
    (re.compile(r'\bDATETIME2\b', re.I), 'DATETIME'),
    (re.compile(r'\bUNIQUEIDENTIFIER\b', re.I), 'CHAR(36)'),
]

PROC_START = re.compile(
    r'CREATE\s+(?:OR\s+ALTER\s+)?PROCEDURE\s+(?:dbo\.)?(?P<name>\w+)\s*',
    re.I,
)
FUNC_START = re.compile(
    r'CREATE\s+(?:OR\s+ALTER\s+)?FUNCTION\s+(?:dbo\.)?(?P<name>\w+)\s*',
    re.I,
)
PARAM_LINE = re.compile(
    r'^\s*@(?P<name>\w+)\s+(?P<type>[\w\(\),\s]+?)(?:\s*=\s*[^,]+)?(?:\s+OUTPUT)?\s*,?\s*$',
    re.I,
)

USP_SIGUIENTE_ID = r'''DROP PROCEDURE IF EXISTS usp_siguiente_id;

DELIMITER $$

CREATE PROCEDURE usp_siguiente_id(
    IN p_Prefijo VARCHAR(10),
    IN p_Tabla VARCHAR(128),
    IN p_Columna VARCHAR(128),
    OUT p_Id VARCHAR(50)
)
main: BEGIN
    DECLARE v_Num INT DEFAULT 1;
    DECLARE v_Like VARCHAR(20);
    SET v_Like = CONCAT(p_Prefijo, '%');
    IF p_Tabla = 'VENTA' THEN
        SELECT IFNULL(MAX(CAST(SUBSTRING(IDVENTA, CHAR_LENGTH(p_Prefijo) + 1, 12) AS UNSIGNED)), 0) + 1
          INTO v_Num FROM VENTA WHERE IDVENTA LIKE v_Like;
    ELSEIF p_Tabla = 'CLIENTE' THEN
        SELECT IFNULL(MAX(CAST(SUBSTRING(IDCLIENTE, CHAR_LENGTH(p_Prefijo) + 1, 12) AS UNSIGNED)), 0) + 1
          INTO v_Num FROM CLIENTE WHERE IDCLIENTE LIKE v_Like;
    ELSEIF p_Tabla = 'COTIZACION' THEN
        SELECT IFNULL(MAX(CAST(SUBSTRING(IDCOTIZACION, CHAR_LENGTH(p_Prefijo) + 1, 12) AS UNSIGNED)), 0) + 1
          INTO v_Num FROM COTIZACION WHERE IDCOTIZACION LIKE v_Like;
    ELSEIF p_Tabla = 'COTIZACION_PAGO' THEN
        SELECT IFNULL(MAX(CAST(SUBSTRING(IDPAGO, CHAR_LENGTH(p_Prefijo) + 1, 12) AS UNSIGNED)), 0) + 1
          INTO v_Num FROM COTIZACION_PAGO WHERE IDPAGO LIKE v_Like;
    ELSEIF p_Tabla = 'PRODUCTO' THEN
        SELECT IFNULL(MAX(CAST(SUBSTRING(IDPRODUCTO, CHAR_LENGTH(p_Prefijo) + 1, 12) AS UNSIGNED)), 0) + 1
          INTO v_Num FROM PRODUCTO WHERE IDPRODUCTO LIKE v_Like;
    ELSEIF p_Tabla = 'CATEGORIA' THEN
        SELECT IFNULL(MAX(CAST(SUBSTRING(IDCATEGORIA, CHAR_LENGTH(p_Prefijo) + 1, 12) AS UNSIGNED)), 0) + 1
          INTO v_Num FROM CATEGORIA WHERE IDCATEGORIA LIKE v_Like;
    ELSEIF p_Tabla = 'UNIDAD' THEN
        SELECT IFNULL(MAX(CAST(SUBSTRING(IDUNIDAD, CHAR_LENGTH(p_Prefijo) + 1, 12) AS UNSIGNED)), 0) + 1
          INTO v_Num FROM UNIDAD WHERE IDUNIDAD LIKE v_Like;
    ELSEIF p_Tabla = 'FORMA_PAGO' THEN
        SELECT IFNULL(MAX(CAST(SUBSTRING(IDFORMAPAGO, CHAR_LENGTH(p_Prefijo) + 1, 12) AS UNSIGNED)), 0) + 1
          INTO v_Num FROM FORMA_PAGO WHERE IDFORMAPAGO LIKE v_Like;
    ELSEIF p_Tabla = 'TIPO_ENTREGA' THEN
        SELECT IFNULL(MAX(CAST(SUBSTRING(IDTIPOENTREGA, CHAR_LENGTH(p_Prefijo) + 1, 12) AS UNSIGNED)), 0) + 1
          INTO v_Num FROM TIPO_ENTREGA WHERE IDTIPOENTREGA LIKE v_Like;
    ELSEIF p_Tabla = 'CUPON' THEN
        SELECT IFNULL(MAX(CAST(SUBSTRING(IDCUPON, CHAR_LENGTH(p_Prefijo) + 1, 12) AS UNSIGNED)), 0) + 1
          INTO v_Num FROM CUPON WHERE IDCUPON LIKE v_Like;
    ELSEIF p_Tabla = 'USUARIO' THEN
        SELECT IFNULL(MAX(CAST(SUBSTRING(IDUSUARIO, CHAR_LENGTH(p_Prefijo) + 1, 12) AS UNSIGNED)), 0) + 1
          INTO v_Num FROM USUARIO WHERE IDUSUARIO LIKE v_Like;
    END IF;
    SET p_Id = CONCAT(p_Prefijo, RIGHT(CONCAT('000000', CAST(v_Num AS CHAR)), 6));
END$$

DELIMITER ;'''

FN_FECHA = r'''DROP FUNCTION IF EXISTS fn_fecha_ddmmyyyy;

DELIMITER $$

CREATE FUNCTION fn_fecha_ddmmyyyy()
RETURNS CHAR(8)
DETERMINISTIC
NO SQL
BEGIN
    RETURN DATE_FORMAT(
        IFNULL(CONVERT_TZ(UTC_TIMESTAMP(), '+00:00', '-05:00'), DATE_SUB(UTC_TIMESTAMP(), INTERVAL 5 HOUR)),
        '%d%m%Y'
    );
END$$

DELIMITER ;'''

FN_ACTOR = r'''DROP FUNCTION IF EXISTS fn_actor;

DELIMITER $$

CREATE FUNCTION fn_actor()
RETURNS VARCHAR(50)
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    RETURN IFNULL(@audit_id_usuario, 'sistema');
END$$

DELIMITER ;'''


def convert_types(text: str) -> str:
    for pattern, repl in TYPE_MAP:
        text = pattern.sub(repl, text)
    return text


def strip_server_directives(text: str) -> str:
    lines = []
    for line in text.splitlines():
        s = line.strip().upper()
        if s in {
            'GO',
            'SET NOCOUNT ON;',
            'SET NOCOUNT ON',
            'SET QUOTED_IDENTIFIER ON;',
            'SET QUOTED_IDENTIFIER ON',
            'SET ANSI_NULLS ON;',
            'SET ANSI_NULLS ON',
            'SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON;',
        }:
            continue
        if s.startswith('SET QUOTED_IDENTIFIER') or s.startswith('SET ANSI_NULLS'):
            continue
        lines.append(line)
    return '\n'.join(lines)


def convert_object_id_drops(text: str) -> str:
    text = re.sub(
        r"IF\s+OBJECT_ID\s*\(\s*'(?:dbo\.)?(?P<name>\w+)'\s*,\s*'P'\s*\)\s+IS\s+NOT\s+NULL\s+"
        r"DROP\s+PROCEDURE\s+(?:dbo\.)?\w+\s*;?",
        r'DROP PROCEDURE IF EXISTS \g<name>;',
        text,
        flags=re.I,
    )
    text = re.sub(
        r"IF\s+OBJECT_ID\s*\(\s*'(?:dbo\.)?(?P<name>\w+)'\s*,\s*'FN'\s*\)\s+IS\s+NOT\s+NULL\s+"
        r"DROP\s+FUNCTION\s+(?:dbo\.)?\w+\s*;?",
        r'DROP FUNCTION IF EXISTS \g<name>;',
        text,
        flags=re.I,
    )
    text = re.sub(
        r"IF\s+OBJECT_ID\s*\(\s*'(?:dbo\.)?(?P<name>\w+)'\s*,\s*'U'\s*\)\s+IS\s+NULL\s*",
        r'-- create if missing \g<name>\n',
        text,
        flags=re.I,
    )
    return text


def convert_col_length_alters(text: str) -> str:
    text = re.sub(
        r"IF\s+COL_LENGTH\s*\(\s*'(?:dbo\.)?(?P<table>\w+)'\s*,\s*'(?P<col>\w+)'\s*\)\s+IS\s+NULL\s+"
        r"ALTER\s+TABLE\s+(?:dbo\.)?\w+\s+ADD\s+(?P<rest>[^;]+);",
        lambda m: (
            f"ALTER TABLE {m.group('table')} ADD COLUMN {m.group('col')} "
            + convert_types(re.sub(
                r'(?i)^' + re.escape(m.group('col')) + r'\s+',
                '',
                m.group('rest').strip(),
            ))
            + ';'
        ),
        text,
        flags=re.I,
    )
    text = re.sub(
        r'\s+CONSTRAINT\s+DF_\w+\s+DEFAULT\s*\(([^)]+)\)',
        r' DEFAULT \1',
        text,
        flags=re.I,
    )
    text = re.sub(r'\s+CONSTRAINT\s+DF_\w+\s+DEFAULT\s+(\S+)', r' DEFAULT \1', text, flags=re.I)
    return text


def convert_functions_and_calls(text: str) -> str:
    text = re.sub(r"\bN'", "'", text)
    text = re.sub(r'\bdbo\.fn_fecha_ddmmyyyy\s*\(\s*\)', 'fn_fecha_ddmmyyyy()', text, flags=re.I)
    text = re.sub(r'\bdbo\.fn_actor\s*\(\s*\)', 'fn_actor()', text, flags=re.I)
    text = re.sub(r'\bdbo\.', '', text, flags=re.I)
    text = re.sub(r'\bISNULL\s*\(', 'IFNULL(', text, flags=re.I)
    text = re.sub(r'\bGETDATE\s*\(\s*\)', 'NOW()', text, flags=re.I)
    text = re.sub(
        r"CONVERT\s*\(\s*CHAR\s*\(\s*8\s*\)\s*,\s*(?:NOW|GETDATE)\s*\(\s*\)\s*,\s*108\s*\)",
        "TIME_FORMAT(NOW(), '%H:%i:%s')",
        text,
        flags=re.I,
    )
    text = re.sub(r'\bTRY_CAST\s*\(', 'CAST(', text, flags=re.I)
    for _ in range(8):
        nxt = re.sub(
            r'\bLTRIM\s*\(\s*RTRIM\s*\(\s*([^()]*(?:\([^()]*\)[^()]*)*)\s*\)\s*\)',
            r'TRIM(\1)',
            text,
            flags=re.I,
        )
        if nxt == text:
            break
        text = nxt
    text = re.sub(r'\bPRINT\s+', 'SELECT ', text, flags=re.I)
    text = re.sub(r'\bCAST\s*\(\s*1\s+AS\s+TINYINT\s*\(\s*1\s*\)\s*\)', '1', text, flags=re.I)
    text = re.sub(r'\bCAST\s*\(\s*0\s+AS\s+TINYINT\s*\(\s*1\s*\)\s*\)', '0', text, flags=re.I)
    text = re.sub(r'\bCAST\s*\(\s*1\s+AS\s+BIT\s*\)', '1', text, flags=re.I)
    text = re.sub(r'\bCAST\s*\(\s*0\s+AS\s+BIT\s*\)', '0', text, flags=re.I)
    text = re.sub(r'\bLEN\s*\(', 'CHAR_LENGTH(', text, flags=re.I)
    text = re.sub(r'\b@@ROWCOUNT\b', 'ROW_COUNT()', text, flags=re.I)
    text = re.sub(
        r"TRY_CONVERT\s*\(\s*date\s*,\s*STUFF\s*\(\s*STUFF\s*\(\s*([^,]+),5,0,'/'\)\s*,3,0,'/'\)\s*,\s*103\s*\)",
        r"STR_TO_DATE(\1, '%d%m%Y')",
        text,
        flags=re.I,
    )
    text = re.sub(
        r'CONVERT\s*\(\s*date\s*,\s*(?:NOW|GETDATE)\s*\(\s*\)\s*\)',
        'CURDATE()',
        text,
        flags=re.I,
    )
    text = re.sub(r'\bCHAR\s*\(\s*37\s*\)', "'%'", text, flags=re.I)
    return text


def convert_string_concat(text: str) -> str:
    def repl_like(m):
        return f"CONCAT('%', {m.group(1)}, '%')"

    text = re.sub(r"'%'\s*\+\s*(@\w+|p_\w+|v_\w+)\s*\+\s*'%'", repl_like, text)

    def repl_plus(m):
        parts = [p.strip() for p in re.split(r'\s*\+\s*', m.group(0))]
        if not any(p.startswith("'") for p in parts):
            return m.group(0)
        return 'CONCAT(' + ', '.join(parts) + ')'

    text = re.sub(
        r"(?:'[^']*'|@\w+|p_\w+|v_\w+|IFNULL\([^)]+\)|\w+\.\w+)\s*"
        r"(?:\+\s*(?:'[^']*'|@\w+|p_\w+|v_\w+|IFNULL\([^)]+\)|\w+\.\w+))+",
        repl_plus,
        text,
    )
    return text


def convert_pagination(text: str) -> str:
    return re.sub(
        r'OFFSET\s*\(\s*(@\w+|p_\w+|v_\w+)\s*-\s*1\s*\)\s*\*\s*(@\w+|p_\w+|v_\w+)\s+ROWS\s+'
        r'FETCH\s+NEXT\s+(@\w+|p_\w+|v_\w+)\s+ROWS\s+ONLY',
        r'LIMIT \3 OFFSET ((\1 - 1) * \2)',
        text,
        flags=re.I,
    )


def convert_top(text: str) -> str:
    def repl_assign(m):
        n, var, rest = m.group(1), m.group(2), m.group(3).rstrip().rstrip(';')
        return f'SELECT {rest} INTO {var} LIMIT {n};'

    text = re.sub(
        r'SELECT\s+TOP\s+(\d+)\s+(@\w+|p_\w+|v_\w+)\s*=\s*(.+?);',
        repl_assign,
        text,
        flags=re.I | re.S,
    )

    def repl_select(m):
        n = m.group(1)
        body = m.group(2).rstrip().rstrip(';')
        if re.search(r'\bLIMIT\b', body, re.I):
            return f'SELECT {body};'
        return f'SELECT {body} LIMIT {n};'

    text = re.sub(
        r'SELECT\s+TOP\s+(\d+)\s+([\s\S]+?);',
        repl_select,
        text,
        flags=re.I,
    )
    return text


def convert_top_with_limit(text: str) -> str:
    """SELECT TOP n cols FROM ... [ORDER BY ...] → SELECT cols FROM ... LIMIT n"""

    def repl(m):
        n = m.group(1)
        body = m.group(2).rstrip().rstrip(';')
        if re.search(r'\bLIMIT\b', body, re.I):
            return m.group(0)
        return f'SELECT {body} LIMIT {n};'

    return re.sub(
        r'SELECT\s+TOP\s+(\d+)\s+([\s\S]+?)(?:;|\n\s*(?:END|GO|IF |CREATE |DROP |PRINT |ALTER ))',
        repl,
        text,
        flags=re.I,
    )


def convert_openjson(text: str) -> str:
    def split_cols(s: str) -> list[str]:
        parts, buf, depth, in_str = [], [], 0, False
        for ch in s:
            if ch == "'" and not in_str:
                in_str = True
                buf.append(ch)
            elif ch == "'" and in_str:
                in_str = False
                buf.append(ch)
            elif ch == '(' and not in_str:
                depth += 1
                buf.append(ch)
            elif ch == ')' and not in_str:
                depth -= 1
                buf.append(ch)
            elif ch == ',' and depth == 0 and not in_str:
                parts.append(''.join(buf).strip())
                buf = []
            else:
                buf.append(ch)
        if buf:
            parts.append(''.join(buf).strip())
        return parts

    def find_with_blocks(src: str):
        out = []
        i = 0
        pat = re.compile(r'FROM\s+OPENJSON\s*\(\s*(@\w+|p_\w+|v_\w+)\s*\)\s*WITH\s*\(', re.I)
        while True:
            m = pat.search(src, i)
            if not m:
                break
            start_inner = m.end()
            depth, in_str, j = 1, False, start_inner
            while j < len(src) and depth:
                ch = src[j]
                if ch == "'" and not in_str:
                    in_str = True
                elif ch == "'" and in_str:
                    in_str = False
                elif ch == '(' and not in_str:
                    depth += 1
                elif ch == ')' and not in_str:
                    depth -= 1
                j += 1
            alias_m = re.match(r'\s*(\w+)', src[j:])
            alias = alias_m.group(1) if alias_m else 'j'
            end = j + (alias_m.end() if alias_m else 0)
            out.append((m.start(), end, m.group(1), src[start_inner:j - 1], alias))
            i = end
        return out

    blocks = find_with_blocks(text)
    if not blocks:
        return text
    pieces, last = [], 0
    for start, end, src_var, cols_raw, alias in blocks:
        col_defs = []
        for raw in split_cols(cols_raw):
            if not raw:
                continue
            cm = re.match(r"(\w+)\s+(.+?)\s+'(\$[^']*)'\s*$", raw.strip())
            if cm:
                col_defs.append(f"{cm.group(1)} {cm.group(2).strip()} PATH '{cm.group(3)}'")
            else:
                col_defs.append(raw)
        cols = ',\n            '.join(col_defs)
        repl = (
            f"FROM JSON_TABLE(IFNULL({src_var}, '[]'), '$[*]' COLUMNS (\n"
            f"            {cols}\n"
            f"        )) AS {alias}"
        )
        pieces.append(text[last:start])
        pieces.append(repl)
        last = end
    pieces.append(text[last:])
    return ''.join(pieces)


def convert_string_split(text: str) -> str:
    return re.sub(
        r'INNER\s+JOIN\s+STRING_SPLIT\s*\(\s*(@\w+|p_\w+|v_\w+)\s*,\s*[\'],\'\s*\)\s+\w+\s+'
        r'ON\s+(?:TRIM\(\w+\.value\)|LTRIM\(RTRIM\(\w+\.value\)\))\s*=\s*(\w+\.\w+)',
        r'AND FIND_IN_SET(\2, \1)',
        text,
        flags=re.I,
    )


def convert_exec_calls(text: str) -> str:
    text = re.sub(
        r"EXEC\s+(?:dbo\.)?usp_siguiente_id\s+'([^']+)'\s*,\s*'([^']+)'\s*,\s*'([^']+)'\s*,\s*(@\w+|p_\w+|v_\w+)\s+OUTPUT\s*;?",
        r"CALL usp_siguiente_id('\1', '\2', '\3', \4);",
        text,
        flags=re.I,
    )
    text = re.sub(
        r"EXEC\s+(?:dbo\.)?usp_cotizacion_pago_insertar\s+"
        r"@Id\s*=\s*(@\w+|p_\w+|v_\w+)\s*,\s*@Monto\s*=\s*(@\w+|p_\w+|v_\w+)\s*,\s*"
        r"@Tipo\s*=\s*'([^']+)'\s*,\s*@IdFormaPago\s*=\s*(@\w+|p_\w+|v_\w+)\s*,\s*"
        r"@Resultado\s*=\s*(@\w+|p_\w+|v_\w+)\s+OUTPUT\s*,\s*@Mensaje\s*=\s*(@\w+|p_\w+|v_\w+)\s+OUTPUT\s*;?",
        r"CALL usp_cotizacion_pago_insertar(\1, \2, '\3', \4, \5, \6);",
        text,
        flags=re.I,
    )
    text = re.sub(
        r"EXEC\s+(?:dbo\.)?usp_cotizacion_pago_insertar\s+"
        r"@Id\s*=\s*(@\w+|p_\w+|v_\w+)\s*,\s*@Monto\s*=\s*(@\w+|p_\w+|v_\w+)\s*,\s*"
        r"@Tipo\s*=\s*'([^']+)'\s*,\s*"
        r"@Resultado\s*=\s*(@\w+|p_\w+|v_\w+)\s+OUTPUT\s*,\s*@Mensaje\s*=\s*(@\w+|p_\w+|v_\w+)\s+OUTPUT\s*;?",
        r"CALL usp_cotizacion_pago_insertar(\1, \2, '\3', NULL, \4, \5);",
        text,
        flags=re.I,
    )
    text = re.sub(
        r"EXEC\s+(?:dbo\.)?usp_venta_anular\s+"
        r"@Id\s*=\s*(@\w+|p_\w+|v_\w+)\s*,\s*"
        r"@Resultado\s*=\s*(@\w+|p_\w+|v_\w+)\s+OUTPUT\s*,\s*@Mensaje\s*=\s*(@\w+|p_\w+|v_\w+)\s+OUTPUT\s*;?",
        r"CALL usp_venta_anular(\1, \2, \3);",
        text,
        flags=re.I,
    )
    text = re.sub(
        r"EXEC\s+(?:dbo\.)?usp_auditoria_siguiente_id\s+@Id\s*=\s*(@\w+|p_\w+|v_\w+)\s+OUTPUT\s*;?",
        r"CALL usp_auditoria_siguiente_id(\1);",
        text,
        flags=re.I,
    )
    text = re.sub(
        r"EXEC\s+(?:dbo\.)?usp_auditoria_instalar_trigger\s+'(\w+)'\s*,\s*'(\w+)'\s*;?",
        r"-- triggers \1.\2: python scripts/install_auditoria_triggers.py",
        text,
        flags=re.I,
    )
    text = re.sub(
        r"IF\s+OBJECT_ID\s*\(\s*'(?:dbo\.)?usp_auditoria_instalar_trigger'\s*,\s*'P'\s*\)\s+IS\s+NOT\s+NULL\s*"
        r"EXEC\s+(?:dbo\.)?usp_auditoria_instalar_trigger\s+'(\w+)'\s*,\s*'(\w+)'\s*;?",
        r"-- triggers \1.\2: python scripts/install_auditoria_triggers.py",
        text,
        flags=re.I,
    )
    text = re.sub(
        r"EXEC\s+(?:dbo\.)?usp_stock_check_json\s+(@\w+|p_\w+|v_\w+)\s*,\s*(@\w+|p_\w+|v_\w+)\s+OUTPUT\s*,\s*(@\w+|p_\w+|v_\w+)\s+OUTPUT\s*;?",
        r"CALL usp_stock_check_json(\1, \2, \3);",
        text,
        flags=re.I,
    )
    text = re.sub(
        r"EXEC\s+(?:dbo\.)?(usp_\w+)\s+(@\w+|p_\w+|v_\w+)\s*,\s*(-?\d+)\s*;?",
        r"CALL \1(\2, \3);",
        text,
        flags=re.I,
    )
    text = re.sub(
        r"EXEC\s+(?:dbo\.)?(usp_\w+)\s+(@\w+|p_\w+|v_\w+)\s*,\s*(@\w+|p_\w+|v_\w+)\s*;?",
        r"CALL \1(\2, \3);",
        text,
        flags=re.I,
    )
    text = re.sub(
        r"EXEC\s+(?:dbo\.)?(usp_\w+)\s+(@\w+|p_\w+|v_\w+)\s*;?",
        r"CALL \1(\2);",
        text,
        flags=re.I,
    )
    return text


def convert_if_blocks(text: str) -> str:
    text = re.sub(
        r'IF\s+(.+?)\s+BEGIN\s+SET\s+([^;]+);\s+SET\s+([^;]+);\s+RETURN;\s+END',
        r'IF \1 THEN SET \2; SET \3; LEAVE main; END IF;',
        text,
        flags=re.I,
    )
    text = re.sub(
        r'IF\s+(.+?)\s+BEGIN\s+SET\s+([^;]+);\s+RETURN;\s+END',
        r'IF \1 THEN SET \2; LEAVE main; END IF;',
        text,
        flags=re.I,
    )
    text = re.sub(
        r'IF\s+([^;\n]+?)\s+SET\s+([^;]+);',
        r'IF \1 THEN SET \2; END IF;',
        text,
        flags=re.I,
    )
    text = re.sub(
        r'IF\s+([^;\n]+?)\s+RETURN\s*;',
        r'IF \1 THEN LEAVE main; END IF;',
        text,
        flags=re.I,
    )
    text = re.sub(r'THEN THEN', 'THEN', text)
    text = re.sub(
        r'END IF;\s*SET ([^;]+);\s*LEAVE main;\s*END IF;',
        r'SET \1; LEAVE main; END IF;',
        text,
    )
    return text


def convert_update_from(text: str) -> str:
    text = re.sub(
        r'UPDATE\s+(\w+)\s+SET\s+([\s\S]+?)\s+FROM\s+(\w+)\s+\1\s+(INNER\s+JOIN\s+[\s\S]+?)\s+WHERE',
        r'UPDATE \3 \1 \4 SET \2 WHERE',
        text,
        flags=re.I,
    )
    text = re.sub(
        r'UPDATE\s+(?:dbo\.)?COTIZACION\s+SET\s+NOMBRECLIENTE\s*=\s*c\.NOMBRE\s+'
        r'FROM\s+(?:dbo\.)?COTIZACION\s+q\s+INNER\s+JOIN\s+(?:dbo\.)?CLIENTE\s+c\s+ON\s+c\.IDCLIENTE\s*=\s*q\.IDCLIENTE\s+'
        r'WHERE\s+q\.NOMBRECLIENTE\s+IS\s+NULL\s*;',
        'UPDATE COTIZACION q INNER JOIN CLIENTE c ON c.IDCLIENTE = q.IDCLIENTE '
        'SET q.NOMBRECLIENTE = c.NOMBRE WHERE q.NOMBRECLIENTE IS NULL;',
        text,
        flags=re.I,
    )
    text = re.sub(
        r'UPDATE\s+(?:dbo\.)?VENTA\s+SET\s+NOMBRECLIENTE\s*=\s*c\.NOMBRE\s+'
        r'FROM\s+(?:dbo\.)?VENTA\s+v\s+INNER\s+JOIN\s+(?:dbo\.)?CLIENTE\s+c\s+ON\s+c\.IDCLIENTE\s*=\s*v\.IDCLIENTE\s+'
        r'WHERE\s+v\.NOMBRECLIENTE\s+IS\s+NULL\s*;',
        'UPDATE VENTA v INNER JOIN CLIENTE c ON c.IDCLIENTE = v.IDCLIENTE '
        'SET v.NOMBRECLIENTE = c.NOMBRE WHERE v.NOMBRECLIENTE IS NULL;',
        text,
        flags=re.I,
    )
    return text


def convert_values_ctor(text: str) -> str:
    def repl(m):
        items = re.findall(r"\('([^']+)'\)", m.group(1))
        alias = m.group(2)
        col = m.group(3)
        parts = [f"SELECT '{items[0]}' AS {col}"] + [f"SELECT '{x}'" for x in items[1:]]
        return 'FROM (' + ' UNION ALL '.join(parts) + f') {alias}'

    return re.sub(
        r'FROM\s+\(VALUES\s+((?:\([^)]+\)\s*,?\s*)+)\)\s+(\w+)\s*\((\w+)\)',
        repl,
        text,
        flags=re.I,
    )


def convert_select_assign(text: str) -> str:
    def repl_multi(m):
        assigns = m.group(1)
        rest = m.group(2)
        pairs = [a.strip() for a in assigns.split(',')]
        names, exprs = [], []
        for p in pairs:
            am = re.match(r'(@\w+|p_\w+|v_\w+)\s*=\s*(.+)$', p)
            if not am:
                return m.group(0)
            names.append(am.group(1))
            exprs.append(am.group(2).strip())
        return f"SELECT {', '.join(exprs)} INTO {', '.join(names)} {rest}"

    text = re.sub(
        r'SELECT\s+((?:(?:@\w+|p_\w+|v_\w+)\s*=\s*[^,;]+)(?:\s*,\s*(?:@\w+|p_\w+|v_\w+)\s*=\s*[^,;]+)+)\s+(FROM\b[\s\S]+?;)',
        repl_multi,
        text,
        flags=re.I,
    )
    text = re.sub(
        r'SELECT\s+((?:p_|v_|@)\w+)\s*=\s*(.+?)\s*(?=;|\n)',
        r'SELECT \2 INTO \1',
        text,
        flags=re.I,
    )
    return text


def convert_if_not_exists_insert(text: str) -> str:
    pattern = re.compile(
        r'IF\s+NOT\s+EXISTS\s+\((SELECT\s+1\s+FROM\s+[\s\S]+?)\)\s+'
        r'INSERT\s+INTO\s+(\w+)\s*\(([^)]+)\)\s*'
        r'VALUES\s*\(([\s\S]+?)\);',
        re.I,
    )

    def repl(m):
        exists, table, cols, vals = m.group(1), m.group(2), m.group(3), m.group(4).strip()
        return (
            f'INSERT INTO {table} ({cols})\n'
            f'SELECT {vals} FROM DUAL WHERE NOT EXISTS ({exists});'
        )

    return pattern.sub(repl, text)


def convert_alter_column(text: str) -> str:
    text = re.sub(
        r'ALTER\s+TABLE\s+(?:dbo\.)?(\w+)\s+ALTER\s+COLUMN\s+(\w+)\s+([\w\(\),\s]+);',
        lambda m: f"ALTER TABLE {m.group(1)} MODIFY {m.group(2)} {convert_types(m.group(3).strip())};",
        text,
        flags=re.I,
    )
    text = re.sub(
        r"IF\s+NOT\s+EXISTS\s+\(SELECT\s+1\s+FROM\s+sys\.foreign_keys\s+WHERE\s+name\s*=\s*'(\w+)'\)\s+"
        r"ALTER\s+TABLE\s+(?:dbo\.)?(\w+)\s+ADD\s+CONSTRAINT\s+\1\s+FOREIGN\s+KEY\s*\(([^)]+)\)\s+"
        r"REFERENCES\s+(?:dbo\.)?(\w+)\s*\(([^)]+)\)\s*;?",
        r'-- FK \1 already in schema or ignored (1826)\n'
        r'ALTER TABLE \2 ADD CONSTRAINT \1 FOREIGN KEY (\3) REFERENCES \4(\5);',
        text,
        flags=re.I,
    )
    text = re.sub(
        r"AND\s+COL_LENGTH\s*\(\s*'[^']+'\s*,\s*'[^']+'\s*\)\s+IS\s+NOT\s+NULL\s+"
        r"ALTER\s+TABLE\s+(?:dbo\.)?(\w+)\s+ADD\s+CONSTRAINT\s+(\w+)\s+"
        r"FOREIGN\s+KEY\s*\(([^)]+)\)\s+REFERENCES\s+(?:dbo\.)?(\w+)\s*\(([^)]+)\)\s*;?",
        r'ALTER TABLE \1 ADD CONSTRAINT \2 FOREIGN KEY (\3) REFERENCES \4(\5);',
        text,
        flags=re.I,
    )
    return text


def convert_outer_apply(text: str) -> str:
    text = re.sub(
        r'UPDATE\s+c\s+'
        r'SET\s+c\.ESTADO\s*=\s*CASE[\s\S]+?END\s+'
        r'FROM\s+(?:dbo\.)?COTIZACION\s+c\s+'
        r'OUTER\s+APPLY\s*\(SELECT\s+SUM\(MONTO\)\s+AS\s+ABONADO\s+FROM\s+(?:dbo\.)?COTIZACION_PAGO\s+'
        r'WHERE\s+IDCOTIZACION\s*=\s*c\.IDCOTIZACION\)\s+pay\s+'
        r"WHERE\s+c\.ESTADO\s*=\s*'Convertida'\s*;",
        """UPDATE COTIZACION c
LEFT JOIN (
    SELECT IDCOTIZACION, SUM(MONTO) AS ABONADO FROM COTIZACION_PAGO GROUP BY IDCOTIZACION
) pay ON pay.IDCOTIZACION = c.IDCOTIZACION
SET c.ESTADO = CASE
    WHEN IFNULL(pay.ABONADO, 0) >= IFNULL(c.TOTAL, 0) AND IFNULL(c.TOTAL, 0) > 0 THEN 'Pagado'
    ELSE 'Deuda'
END
WHERE c.ESTADO = 'Convertida';""",
        text,
        flags=re.I,
    )
    text = re.sub(
        r'OUTER\s+APPLY\s*\(\s*SELECT\s+SUM\s*\(\s*MONTO\s*\)\s+AS\s+ABONADO\s+'
        r'FROM\s+(?:dbo\.)?COTIZACION_PAGO\s+WHERE\s+IDCOTIZACION\s*=\s*(\w+)\.IDCOTIZACION\s*\)\s+(\w+)',
        r'LEFT JOIN (SELECT IDCOTIZACION, SUM(MONTO) AS ABONADO FROM COTIZACION_PAGO GROUP BY IDCOTIZACION) \2 '
        r'ON \2.IDCOTIZACION = \1.IDCOTIZACION',
        text,
        flags=re.I,
    )
    return text


def hoist_declares(body: str) -> str:
    declares: list[str] = []

    def take(m):
        raw = m.group(0).rstrip().rstrip(';').strip()
        inner = re.sub(r'(?i)^DECLARE\s+', '', raw).strip()
        am = re.match(r'(\w+)\s+([\w\(\),\s]+?)\s*=\s*(.+)$', inner)
        if am:
            name, typ, expr = am.group(1), am.group(2).strip(), am.group(3).strip()
            declares.append(f'DECLARE {name} {typ};')
            return f'SET {name} = {expr};'
        declares.append(raw + ';')
        return ''

    body = re.sub(r'DECLARE\s+[^;]+;', take, body, flags=re.I)
    if not declares:
        return body
    head = '\n    '.join(declares)
    return head + '\n    ' + body.lstrip()


def expand_multi_declare(body: str) -> str:
    def split_decl(m):
        inner = m.group(1)
        parts, buf, depth = [], [], 0
        for ch in inner:
            if ch == '(':
                depth += 1
                buf.append(ch)
            elif ch == ')':
                depth -= 1
                buf.append(ch)
            elif ch == ',' and depth == 0:
                parts.append(''.join(buf).strip())
                buf = []
            else:
                buf.append(ch)
        if buf:
            parts.append(''.join(buf).strip())
        return ''.join(f'DECLARE {p}; ' for p in parts if p)

    return re.sub(r'DECLARE\s+((?:@\w+|p_\w+|v_\w+)\s+[^;]+);', split_decl, body, flags=re.I)


def post_process_body(body: str) -> str:
    body = expand_multi_declare(body)
    body = convert_exec_calls(body)
    body = convert_openjson(body)
    body = convert_string_split(body)
    body = convert_if_blocks(body)
    body = convert_update_from(body)
    body = convert_outer_apply(body)
    body = convert_select_assign(body)
    body = convert_pagination(body)
    body = convert_top(body)
    body = re.sub(r'IF\s+@@TRANCOUNT\s*>\s*0\s+ROLLBACK\s+TRAN\s*;?', 'ROLLBACK;', body, flags=re.I)
    body = re.sub(r'\bRETURN\s*;', 'LEAVE main;', body, flags=re.I)
    body = re.sub(r'\bRETURN\b', 'LEAVE main', body, flags=re.I)
    locals_found = re.findall(r'DECLARE\s+(@\w+)', body, flags=re.I)
    for loc in locals_found:
        vname = 'v_' + loc[1:]
        body = re.sub(rf'DECLARE\s+{re.escape(loc)}\b', f'DECLARE {vname}', body, flags=re.I)
        body = re.sub(rf'{re.escape(loc)}\b', vname, body)
    body = hoist_declares(body)
    return body


def parse_procedure_params(header: str) -> tuple[list[str], list[str], str]:
    compact = ' '.join(header.replace('\n', ' ').split())
    found = re.findall(
        r'@(\w+)\s+([A-Za-z][A-Za-z0-9]*(?:\s*\(\s*[\d,]+\s*\))?)(?:\s*=\s*(?:\'[^\']*\'|NULL|[^,]+))?(\s+OUTPUT)?',
        compact,
        flags=re.I,
    )
    in_params: list[str] = []
    parsed: list[tuple[str, str, bool]] = []
    for name, typ, output in found:
        typ_c = convert_types(re.sub(r'\s+', '', typ))
        is_out = bool(output)
        pname = f'p_{name}'
        in_params.append(f'{"OUT" if is_out else "IN"} {pname} {typ_c}')
        parsed.append((name, pname, is_out))
    sig = ',\n    '.join(in_params)
    return [x[1] for x in parsed if not x[2]], [x[1] for x in parsed if x[2]], sig


def convert_procedure_block(block: str) -> str:
    m = PROC_START.search(block)
    if not m:
        return block

    name = m.group('name')
    if name.lower() == 'usp_siguiente_id':
        return USP_SIGUIENTE_ID
    if name.lower() == 'usp_auditoria_instalar_trigger':
        return (
            '-- usp_auditoria_instalar_trigger: MySQL no permite PREPARE de CREATE TRIGGER.\n'
            '-- Los triggers se instalan con scripts/install_auditoria_triggers.py\n'
            'DROP PROCEDURE IF EXISTS usp_auditoria_instalar_trigger;'
        )

    rest = block[m.end():]
    as_idx = re.search(r'\bAS\b', rest, re.I)
    if not as_idx:
        return block
    header = rest[: as_idx.start()]
    body = rest[as_idx.end():]
    body = re.sub(r'\s*END\s*;\s*$', '', body.strip(), flags=re.I)
    body = re.sub(r'^\s*BEGIN\s*', '', body, flags=re.I)
    _in_names, out_names, sig = parse_procedure_params(header)

    for orig in re.findall(r'@(\w+)', header):
        body = re.sub(rf'@{orig}\b', f'p_{orig}', body)

    body = post_process_body(body)

    sig_part = f'(\n    {sig}\n)' if sig else '()'
    drop = f'DROP PROCEDURE IF EXISTS {name};\n\n'
    proc = (
        f'{drop}DELIMITER $$\n\n'
        f'CREATE PROCEDURE {name}{sig_part}\n'
        f'main: BEGIN\n{body.strip()}\nEND$$\n\nDELIMITER ;'
    )
    return proc


def convert_function_block(block: str) -> str:
    m = FUNC_START.search(block)
    if not m:
        return block
    name = m.group('name').lower()
    if name == 'fn_fecha_ddmmyyyy':
        return FN_FECHA
    if name == 'fn_actor':
        return FN_ACTOR
    return block


def split_procedure_blocks(batch: str) -> list[str]:
    parts = re.split(
        r'(?=(?:DROP\s+PROCEDURE\s+IF\s+EXISTS|DROP\s+FUNCTION\s+IF\s+EXISTS|'
        r'IF\s+OBJECT_ID.*DROP\s+PROCEDURE|CREATE\s+PROCEDURE|CREATE\s+FUNCTION))',
        batch,
        flags=re.I,
    )
    return [p.strip() for p in parts if p.strip()]


def split_batches(content: str) -> list[str]:
    parts = re.split(r'^\s*GO\s*$', content, flags=re.I | re.M)
    return [p.strip() for p in parts if p.strip()]


def convert_seed_declares(text: str) -> str:
    text = re.sub(
        r'DECLARE\s+@F\s+CHAR\s*\(\s*8\s*\)\s*=\s*(?:dbo\.)?fn_fecha_ddmmyyyy\s*\(\s*\)\s*;',
        'SET @F = fn_fecha_ddmmyyyy();',
        text,
        flags=re.I,
    )
    text = re.sub(
        r"DECLARE\s+@H\s+CHAR\s*\(\s*8\s*\)\s*=\s*.+?;",
        "SET @H = TIME_FORMAT(NOW(), '%H:%i:%s');",
        text,
        flags=re.I,
    )
    text = re.sub(r'\b@F\b', '@F', text)
    text = re.sub(r'\b@H\b', '@H', text)
    return text


def convert_modulo_if_blocks(text: str) -> str:
    """IF NOT EXISTS modulo BEGIN update+insert END ELSE update END → INSERT SELECT + UPDATE."""
    pattern = re.compile(
        r"IF\s+NOT\s+EXISTS\s+\(SELECT\s+1\s+FROM\s+(?:dbo\.)?MODULO\s+WHERE\s+IDMODULO\s*=\s*'(\w+)'\)\s*"
        r'BEGIN\s+'
        r'(UPDATE\s+(?:dbo\.)?MODULO\s+SET\s+ORDEN\s*=\s*ORDEN\s*\+\s*1\s+WHERE\s+ORDEN\s*>=\s*\d+\s*;)?\s*'
        r'INSERT\s+INTO\s+(?:dbo\.)?MODULO\s*\(([^)]+)\)\s*'
        r'VALUES\s*\(([\s\S]+?)\)\s*;\s*'
        r'END\s*'
        r'ELSE\s*'
        r'BEGIN\s+'
        r'(UPDATE\s+(?:dbo\.)?MODULO[\s\S]+?WHERE\s+IDMODULO\s*=\s*\'\1\'\s*;)?\s*'
        r'END',
        re.I,
    )

    def repl(m):
        mid = m.group(1)
        bump = m.group(2) or ''
        cols = m.group(3)
        vals = m.group(4).strip()
        else_upd = m.group(5) or ''
        bump_sql = ''
        if bump:
            bump_sql = (
                f"{bump.replace('dbo.', '')}\n"
            )
            bump_sql = re.sub(
                r';\s*$',
                f" AND NOT EXISTS (SELECT 1 FROM (SELECT IDMODULO FROM MODULO WHERE IDMODULO='{mid}') t);",
                bump_sql.strip(),
                flags=re.I,
            )
        insert = (
            f"INSERT INTO MODULO ({cols})\n"
            f"SELECT {vals} FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM MODULO WHERE IDMODULO='{mid}');"
        )
        return f'{bump_sql}\n{insert}\n{else_upd}'.strip()

    return pattern.sub(repl, text)


def strip_sys_blocks(text: str) -> str:
    text = re.sub(
        r'DECLARE\s+@sql\s+[\s\S]+?IF\s+@sql\s+IS\s+NOT\s+NULL\s+EXEC\s+sp_executesql\s+@sql\s*;',
        '-- SQL Server sys.foreign_keys skip (esquema MySQL ya tiene IDCLIENTE NULL)',
        text,
        flags=re.I,
    )
    return text


def convert_table_exists_blocks(text: str) -> str:
    text = re.sub(
        r'\bCREATE\s+TABLE\s+(?!IF\s+NOT\s+EXISTS)(\w+)',
        r'CREATE TABLE IF NOT EXISTS \1',
        text,
        flags=re.I,
    )
    text = re.sub(r'\bELSE\s+SELECT\s+[^;]+;', '', text, flags=re.I)
    return text


def convert_batch(batch: str) -> str:
    batch = convert_object_id_drops(batch)
    batch = convert_col_length_alters(batch)
    batch = convert_types(batch)
    batch = convert_functions_and_calls(batch)
    batch = convert_table_exists_blocks(batch)
    batch = convert_string_concat(batch)
    batch = convert_pagination(batch)
    batch = convert_values_ctor(batch)
    batch = convert_alter_column(batch)
    batch = convert_outer_apply(batch)
    batch = convert_update_from(batch)
    batch = convert_if_not_exists_insert(batch)
    batch = convert_modulo_if_blocks(batch)
    batch = convert_seed_declares(batch)
    batch = strip_sys_blocks(batch)
    batch = re.sub(
        r"IF\s+NOT\s+EXISTS\s+\(\s*SELECT\s+1\s+FROM\s+sys\.foreign_keys[\s\S]+?;",
        '-- FK ya existe o se ignora (1826)',
        batch,
        flags=re.I,
    )
    batch = re.sub(
        r"AND\s+NOT\s+EXISTS\s+\(\s*SELECT\s+1\s+FROM\s+sys\.foreign_keys[\s\S]+?;",
        '; -- FK skip sys.foreign_keys',
        batch,
        flags=re.I,
    )
    batch = convert_exec_calls(batch)
    batch = convert_openjson(batch)
    batch = convert_string_split(batch)

    if not PROC_START.search(batch) and not FUNC_START.search(batch):
        return batch.strip()

    chunks = split_procedure_blocks(batch)
    out_parts = []
    for chunk in chunks:
        if PROC_START.search(chunk):
            out_parts.append(convert_procedure_block(chunk))
        elif FUNC_START.search(chunk):
            out_parts.append(convert_function_block(chunk))
        else:
            out_parts.append(chunk.strip())
    return '\n\n'.join(out_parts).strip()


def convert_file_content(content: str, rel_path: str) -> str:
    header = (
        f'-- Convertido desde db_scripts/{rel_path.replace(chr(92), "/")}\n'
        f'-- MySQL 8 — DecoCake Shop\n\n'
        f'USE `{DB_NAME}`;\n\n'
    )
    if rel_path.replace('\\', '/').endswith('1.esquema_completo.sql'):
        header += 'SET FOREIGN_KEY_CHECKS = 0;\n\n'
    # Split on GO before stripping it, or CREATE TABLE batches merge with procedures.
    batches = split_batches(content)
    converted = [convert_batch(strip_server_directives(b)) for b in batches]
    body = '\n\n'.join(c for c in converted if c.strip())
    body = re.sub(r'\n{3,}', '\n\n', body)
    if rel_path.replace('\\', '/').endswith('1.esquema_completo.sql'):
        body += '\n\nSET FOREIGN_KEY_CHECKS = 1;\n'
    return header + polish_mysql(body) + '\n'


def fix_limit_offset_procedures(text: str) -> str:
    """MySQL no acepta expresiones en OFFSET; hay que usar una variable INT."""
    offset_re = re.compile(
        r'OFFSET\s+\(\(\s*p_Pagina\s*-\s*1\s*\)\s*\*\s*p_TamanioPagina\s*\)',
        re.I,
    )

    def repl_proc(m):
        proc = m.group(0)
        if not offset_re.search(proc):
            return proc
        if 'DECLARE v_offset INT' not in proc:
            proc = re.sub(
                r'(main:\s*BEGIN\s*)',
                r'\1DECLARE v_offset INT DEFAULT 0;\n    ',
                proc,
                count=1,
                flags=re.I,
            )
        proc = re.sub(
            r'(SELECT\s+(?!COUNT\s*\()[\s\S]*?LIMIT\s+p_TamanioPagina\s+)'
            r'OFFSET\s+\(\(\s*p_Pagina\s*-\s*1\s*\)\s*\*\s*p_TamanioPagina\s*\)',
            r'SET v_offset = (p_Pagina - 1) * p_TamanioPagina;\n    \1OFFSET v_offset',
            proc,
            flags=re.I,
        )
        # Fallback: LIMIT on same line as ORDER BY
        proc = offset_re.sub('OFFSET v_offset', proc)
        if 'SET v_offset =' not in proc:
            proc = re.sub(
                r'(DECLARE v_offset INT DEFAULT 0;\s*)',
                r'\1SET v_offset = (p_Pagina - 1) * p_TamanioPagina;\n    ',
                proc,
                count=1,
            )
        return proc

    return re.sub(
        r'CREATE PROCEDURE[\s\S]+?END\$\$',
        repl_proc,
        text,
        flags=re.I,
    )


def polish_mysql(text: str) -> str:
    # SQL Server: COL TYPE NOT NULL FOREIGN KEY REFERENCES T(C)
    # MySQL: COL TYPE NOT NULL, FOREIGN KEY (COL) REFERENCES T(C)
    text = re.sub(
        r'(\w+)\s+'
        r'((?:VARCHAR|CHAR|LONGTEXT|DECIMAL|TINYINT|INT)(?:\s*\(\s*[\d,]+\s*\))?)\s+'
        r'(NULL|NOT NULL)\s+'
        r'FOREIGN KEY REFERENCES\s+(\w+)\s*\(\s*(\w+)\s*\)',
        r'\1 \2 \3,\n    FOREIGN KEY (\1) REFERENCES \4(\5)',
        text,
        flags=re.I,
    )
    text = fix_limit_offset_procedures(text)
    text = text.replace('@ObsFROM', 'v_Obs FROM')
    text = re.sub(
        r'BEGIN SET (p_Resultado=0); SET (p_Mensaje=[^;]+); LEAVE main; END',
        r'THEN SET \1; SET \2; LEAVE main; END IF;',
        text,
    )
    text = re.sub(
        r"IF OBJECT_ID\([^)]+\) IS NOT NULL[\s\S]*?(?=\n\S|\n$)",
        '-- skip usp_auditoria_instalar_trigger (Python)\n',
        text,
        flags=re.I,
    )
    text = re.sub(
        r"CONCAT\('GRM([123])',\s*(\w+)\.IDMODULO\)\s*\+\s*p\.IDTIPOPERMISO",
        r"CONCAT('GRM\1', \2.IDMODULO, p.IDTIPOPERMISO)",
        text,
    )
    text = re.sub(
        r"p_Id \+ RIGHT\('000'\s*\+\s*CAST\(ROW_NUMBER\(\) OVER \(ORDER BY j\.IDPRODUCTO\) AS VARCHAR\(4\)\),\s*3\)",
        r"CONCAT(p_Id, RIGHT(CONCAT('000', CAST(ROW_NUMBER() OVER (ORDER BY j.IDPRODUCTO) AS CHAR)), 3))",
        text,
        flags=re.I,
    )
    text = re.sub(
        r'IF ([^\n]+)\n(\s*)BEGIN\n',
        r'IF \1 THEN\n\2',
        text,
    )
    text = re.sub(
        r'\n(\s*)END\n(\s*)ELSE\n',
        r'\n\1ELSE\n',
        text,
    )
    text = re.sub(
        r'IF ([^\n]+)\n(\s*)CALL ',
        r'IF \1 THEN\n\2CALL ',
        text,
    )
    text = re.sub(
        r'(IF [^\n]+ THEN\n\s*CALL [^;\n]+;)\n(\s*SET p_Resultado)',
        r'\1 END IF;\n\2',
        text,
    )
    text = re.sub(
        r'IF (v_\w+ IS NOT NULL)\n(\s*SELECT )',
        r'IF \1 THEN\n\2',
        text,
    )
    text = re.sub(
        r'(ELSE\n\s+SELECT[\s\S]+?;)\s*\nEND\$\$',
        r'\1\n    END IF;\nEND$$',
        text,
    )
    text = re.sub(r'THEN THEN', 'THEN', text)
    text = re.sub(
        r"IF OBJECT_ID\('usp_auditoria_instalar_trigger','P'\) IS NOT NULL\n\s*",
        '',
        text,
    )
    text = re.sub(
        r'SELECT (\w+) FROM (\w+) WHERE (.+?) ORDER BY (.+?) INTO (\w+) LIMIT (\d+);',
        r'SELECT \1 INTO \5 FROM \2 WHERE \3 ORDER BY \4 LIMIT \6;',
        text,
    )
    text = re.sub(
        r'SELECT (.+?) FROM (\w+) WHERE (.+?) INTO (\w+);',
        r'SELECT \1 INTO \4 FROM \2 WHERE \3;',
        text,
    )
    # MySQL: INTO must come before FROM (COUNT(*) FROM t INTO var)
    text = re.sub(
        r'SELECT\s+COUNT\s*\(\s*\*\s*\)\s+FROM\s+(\w+(?:\s+\w+)?)\s+INTO\s+(\w+)',
        r'SELECT COUNT(*) INTO \2 FROM \1',
        text,
        flags=re.I,
    )
    text = re.sub(
        r"""    IF v_IDTIPOUSUARIO IS NOT NULL THEN
        SELECT 1 AS is_valid,
            CASE v_IDTIPOUSUARIO
                WHEN '1' THEN 'vendedor'
                WHEN '2' THEN 'almacen'
                WHEN '3' THEN 'administrador'
                ELSE 'vendedor'
            END AS role;
END\$\$""",
        """    IF v_IDTIPOUSUARIO IS NOT NULL THEN
        SELECT 1 AS is_valid,
            CASE v_IDTIPOUSUARIO
                WHEN '1' THEN 'vendedor'
                WHEN '2' THEN 'almacen'
                WHEN '3' THEN 'administrador'
                ELSE 'vendedor'
            END AS role;
    ELSE
        SELECT 0 AS is_valid, 'vendedor' AS role;
    END IF;
END$$""",
        text,
    )
    text = re.sub(
        r"WHERE IDCLIENTE=v_IdCliente;\n\n      CALL usp_siguiente_id\('VEN'",
        "WHERE IDCLIENTE=v_IdCliente;\n    END IF;\n\n      CALL usp_siguiente_id('VEN'",
        text,
    )
    text = re.sub(
        r'(LEAVE main;)\n(\s*)END\n',
        r'\1\n\2END IF;\n',
        text,
    )
    text = re.sub(r' AS INT\)', ' AS UNSIGNED)', text)
    text = re.sub(r'AS VARCHAR\(\d+\)', 'AS CHAR', text)
    text = re.sub(
        r"SET p_Id = 'AUD' \+ RIGHT\('000000' \+ CAST\(v_Num AS CHAR\), 6\);",
        r"SET p_Id = CONCAT('AUD', RIGHT(CONCAT('000000', CAST(v_Num AS CHAR)), 6));",
        text,
    )
    text = re.sub(
        r"(\w+) \+ RIGHT\('000'\+CAST\(ROW_NUMBER\(\) OVER \(ORDER BY IDDETALLE\) AS CHAR\), 3\)",
        r"CONCAT(\1, RIGHT(CONCAT('000', CAST(ROW_NUMBER() OVER (ORDER BY IDDETALLE) AS CHAR)), 3))",
        text,
    )
    return text


def iter_source_files(single: str | None = None):
    if single:
        yield Path(single)
        return
    for path in sorted(SRC_DIR.rglob('*.sql')):
        if path.name in SKIP_FILES:
            continue
        yield path


def convert_all(single: str | None = None) -> int:
    DST_DIR.mkdir(parents=True, exist_ok=True)
    count = 0
    for src in iter_source_files(single):
        rel = src.relative_to(SRC_DIR)
        dst = DST_DIR / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        out = convert_file_content(src.read_text(encoding='utf-8'), str(rel))
        dst.write_text(out, encoding='utf-8')
        count += 1
        print(f'  {rel}')
    order_src = SRC_DIR / '16_08_2026' / 'ORDEN_EJECUCION.txt'
    if order_src.exists():
        lines = [
            ln for ln in order_src.read_text(encoding='utf-8').splitlines()
            if ln.strip() and ln.strip() not in SKIP_FILES
        ]
        (DST_DIR / '16_08_2026' / 'ORDEN_EJECUCION.txt').write_text(
            '\n'.join(lines) + '\n', encoding='utf-8'
        )
    return count


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--file', help='Ruta relativa dentro de db_scripts/')
    args = parser.parse_args()

    print(f'Origen:  {SRC_DIR}')
    print(f'Destino: {DST_DIR}')
    n = convert_all(args.file)
    print(f'\nOK: {n} archivo(s) convertido(s).')
    print('Siguiente: python scripts/setup_mysql_db.py')


if __name__ == '__main__':
    main()

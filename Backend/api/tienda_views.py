import json
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.db import connection
from . import sp_runner as sp
from .crud_exec import escribir, listar_paginado


def _decode_foto(row):
    foto = row.get('FOTO')
    if isinstance(foto, (bytes, bytearray, memoryview)):
        row['FOTO'] = bytes(foto).decode('utf-8', errors='ignore')
    return row


def _producto_publico(row):
    if row.get('PRECIO') is not None:
        row['PRECIO'] = float(row['PRECIO'])
    if row.get('STOCK') is not None:
        row['STOCK'] = float(row['STOCK'])
    return _decode_foto(row)


def _categorias():
    with connection.cursor() as cursor:
        cursor.execute('EXEC dbo.usp_tienda_categorias')
        return sp.cursor_rows(cursor)


@csrf_exempt
def tienda_catalogo(request):
    if request.method != 'GET':
        return JsonResponse({'error': 'Método no permitido'}, status=405)
    try:
        categorias = _categorias()
        ids = (request.GET.get('ids') or '').strip()
        if ids:
            with connection.cursor() as cursor:
                cursor.execute('EXEC dbo.usp_tienda_favoritos @Ids=%s', [ids])
                productos = [_producto_publico(p) for p in sp.cursor_rows(cursor)]
            return JsonResponse({'categorias': categorias, 'productos': productos, 'total': len(productos)})

        if request.GET.get('destacados') == '1':
            with connection.cursor() as cursor:
                cursor.execute('EXEC dbo.usp_tienda_destacados')
                productos = [_producto_publico(p) for p in sp.cursor_rows(cursor)]
            return JsonResponse({'categorias': categorias, 'productos': productos, 'total': len(productos)})

        try:
            pagina = max(1, int(request.GET.get('pagina', 1) or 1))
        except (TypeError, ValueError):
            pagina = 1
        try:
            tamanio = int(request.GET.get('tamanio', 12) or 12)
        except (TypeError, ValueError):
            tamanio = 12
        if tamanio not in (12, 24):
            tamanio = 12
        buscar = (request.GET.get('buscar') or '').strip() or None
        categoria = (request.GET.get('categoria') or '').strip() or None
        productos, total = listar_paginado(
            'usp_tienda_productos',
            '@Buscar=%s, @IdCategoria=%s, @Pagina=%s, @TamanioPagina=%s',
            [buscar, categoria, pagina, tamanio],
        )
        productos = [_producto_publico(p) for p in productos]
        return JsonResponse({
            'categorias': categorias,
            'productos': productos,
            'total': total,
            'pagina': pagina,
            'tamanioPagina': tamanio,
        })
    except Exception as exc:
        return JsonResponse({'error': str(exc)}, status=500)


def _descuento(cupon, subtotal):
    valor = float(cupon.get('VALOR') or 0)
    if cupon.get('TIPO') == 'Monto':
        return min(subtotal, valor)
    return round(subtotal * valor / 100, 2)


@csrf_exempt
def tienda_cupon(request):
    codigo = (request.GET.get('codigo') or '').strip()
    if request.method == 'POST':
        try:
            body = json.loads(request.body.decode('utf-8') or '{}')
        except Exception:
            body = {}
        codigo = (body.get('codigo') or codigo).strip()
        if not codigo:
            return JsonResponse({'ok': False, 'error': 'Ingresa un cupón.'}, status=400)
        ok, mensaje = escribir('usp_cupon_usar', '@Codigo=%s', [codigo])
        return JsonResponse({'ok': bool(ok), 'mensaje': mensaje}, status=200 if ok else 400)

    if request.method != 'GET':
        return JsonResponse({'error': 'Método no permitido'}, status=405)
    try:
        subtotal = float(request.GET.get('subtotal') or 0)
    except (TypeError, ValueError):
        subtotal = 0
    if not codigo:
        return JsonResponse({'ok': False, 'error': 'Ingresa un cupón.'}, status=400)
    try:
        with connection.cursor() as cursor:
            cursor.execute('EXEC dbo.usp_cupon_validar @Codigo=%s, @Subtotal=%s', [codigo, subtotal])
            rows = sp.cursor_rows(cursor)
        if not rows:
            return JsonResponse({'ok': False, 'error': 'El cupón no es válido o no aplica a este monto.'}, status=400)
        row = rows[0]
        if row.get('VALOR') is not None:
            row['VALOR'] = float(row['VALOR'])
        if row.get('MINIMO') is not None:
            row['MINIMO'] = float(row['MINIMO'])
        desc = _descuento(row, subtotal)
        return JsonResponse({
            'ok': True,
            'cupon': row,
            'descuento': desc,
            'total': max(0, round(subtotal - desc, 2)),
        })
    except Exception as exc:
        return JsonResponse({'error': str(exc)}, status=500)


@csrf_exempt
def tienda_cupones(request):
    if request.method != 'GET':
        return JsonResponse({'error': 'Método no permitido'}, status=405)
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                DECLARE @Hoy DATE = CONVERT(date, GETDATE());
                SELECT CODIGO, DESCRIPCION, TIPO, VALOR, MINIMO, USOSMAX
                FROM CUPON
                WHERE ESTADO = 'Activo'
                  AND (USOSMAX IS NULL OR USOS < USOSMAX)
                  AND (FECHAINICIO IS NULL OR FECHAINICIO = '' OR TRY_CONVERT(date, STUFF(STUFF(FECHAINICIO,5,0,'/'),3,0,'/'), 103) <= @Hoy)
                  AND (FECHAFIN IS NULL OR FECHAFIN = '' OR TRY_CONVERT(date, STUFF(STUFF(FECHAFIN,5,0,'/'),3,0,'/'), 103) >= @Hoy)
                ORDER BY CODIGO
                """
            )
            rows = sp.cursor_rows(cursor)
        cupones = []
        for row in rows:
            if row.get('VALOR') is not None:
                row['VALOR'] = float(row['VALOR'])
            if row.get('MINIMO') is not None:
                row['MINIMO'] = float(row['MINIMO'])
            row['VIGENCIA'] = 'Limitado' if row.get('USOSMAX') else 'Permanente'
            cupones.append(row)
        return JsonResponse({'cupones': cupones})
    except Exception as exc:
        return JsonResponse({'error': str(exc)}, status=500)


@csrf_exempt
def tienda_checkout(request):
    if request.method != 'GET':
        return JsonResponse({'error': 'Método no permitido'}, status=405)
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT IDFORMAPAGO AS value, NOMBRE AS label
                FROM FORMA_PAGO WHERE ESTADO = 'Activo' ORDER BY NOMBRE
                """
            )
            formas = sp.cursor_rows(cursor)
            cursor.execute(
                """
                SELECT IDTIPOENTREGA AS value, NOMBRE AS label, REQUIEREDIRECCION
                FROM TIPO_ENTREGA WHERE ESTADO = 'Activo' ORDER BY NOMBRE
                """
            )
            entregas = sp.cursor_rows(cursor)
        return JsonResponse({'formasPago': formas, 'tiposEntrega': entregas})
    except Exception as exc:
        return JsonResponse({'error': str(exc)}, status=500)


def _texto(val, max_len):
    return str(val or '').strip()[:max_len]


@csrf_exempt
def tienda_pedido(request):
    if request.method != 'POST':
        return JsonResponse({'error': 'Método no permitido'}, status=405)
    try:
        body = json.loads(request.body.decode('utf-8') or '{}')
    except Exception:
        return JsonResponse({'ok': False, 'error': 'JSON inválido'}, status=400)

    nombre = _texto(body.get('NOMBRE'), 200)
    telefono = _texto(body.get('TELEFONO'), 20)
    email = _texto(body.get('EMAIL'), 150)
    direccion = _texto(body.get('DIRECCION'), 255)
    forma = _texto(body.get('IDFORMAPAGO'), 50)
    entrega = _texto(body.get('IDTIPOENTREGA'), 50) or None
    comprobante = str(body.get('COMPROBANTEPAGO') or '').strip()
    notas = _texto(body.get('OBSERVACIONES'), 500)
    detalle = body.get('DETALLE') or []
    cupon = _texto(body.get('CUPON'), 40)

    if not nombre:
        return JsonResponse({'ok': False, 'error': 'Ingresa tu nombre.'}, status=400)
    if not telefono:
        return JsonResponse({'ok': False, 'error': 'Ingresa tu teléfono.'}, status=400)
    if not forma:
        return JsonResponse({'ok': False, 'error': 'Selecciona un método de pago.'}, status=400)
    if not comprobante.startswith('data:image/'):
        return JsonResponse({'ok': False, 'error': 'Adjunta la captura del pago.'}, status=400)
    if len(comprobante) > 450000:
        return JsonResponse({'ok': False, 'error': 'La captura es muy pesada. Usa una imagen más pequeña.'}, status=400)
    lineas = []
    for item in detalle:
        prod = _texto(item.get('IDPRODUCTO') or item.get('id'), 50)
        try:
            cant = float(item.get('CANTIDAD') or item.get('cantidad') or 0)
            precio = float(item.get('PRECIOUNITARIO') or item.get('precio') or 0)
        except (TypeError, ValueError):
            continue
        if prod and cant > 0:
            lineas.append({'IDPRODUCTO': prod, 'CANTIDAD': cant, 'PRECIOUNITARIO': precio})
    if not lineas:
        return JsonResponse({'ok': False, 'error': 'El carrito está vacío.'}, status=400)

    if cupon:
        notas = (notas + ' | ' if notas else '') + f'Cupón {cupon}'

    try:
        ok, mensaje = escribir(
            'usp_tienda_pedido',
            '@Nombre=%s, @Telefono=%s, @Email=%s, @Direccion=%s, @IdFormaPago=%s, '
            '@IdTipoEntrega=%s, @ComprobantePago=%s, @Observaciones=%s, @DetalleJson=%s',
            [
                nombre, telefono, email or None, direccion or None, forma,
                entrega, comprobante, notas or None, json.dumps(lineas, ensure_ascii=False),
            ],
            'tienda',
            body,
        )
        if not ok:
            return JsonResponse({'ok': False, 'error': mensaje}, status=400)
        if cupon:
            escribir('usp_cupon_usar', '@Codigo=%s', [cupon])
        idventa = ''
        for parte in str(mensaje).replace('.', ' ').split():
            if parte.startswith('VEN'):
                idventa = parte
                break
        return JsonResponse({'ok': True, 'mensaje': mensaje, 'idventa': idventa})
    except Exception as exc:
        return JsonResponse({'ok': False, 'error': str(exc)}, status=500)

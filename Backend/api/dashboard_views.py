from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from .dashboard_service import resumen_dashboard


@csrf_exempt
def dashboard_api(request):
    if request.method != 'GET':
        return JsonResponse({'error': 'Método no permitido'}, status=405)
    try:
        return JsonResponse({'data': resumen_dashboard()})
    except Exception as exc:
        return JsonResponse({'error': str(exc)}, status=500)

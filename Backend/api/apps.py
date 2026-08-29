from django.apps import AppConfig
from django.db.backends.signals import connection_created


def _configure_sqlserver_connection(sender, connection, **kwargs):
    engine = connection.settings_dict.get('ENGINE', '')
    if 'mssql' not in engine:
        return
    with connection.cursor() as cursor:
        cursor.execute('SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON;')


class ApiConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'api'

    def ready(self):
        connection_created.connect(_configure_sqlserver_connection)

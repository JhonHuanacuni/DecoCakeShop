from rest_framework import serializers
from .models import Modulo, Submodulo, UsuarioModulo, GrupoModulo, TipoPermiso


class TipoPermisoSerializer(serializers.ModelSerializer):
    class Meta:
        model = TipoPermiso
        fields = ['IDTIPOPERMISO', 'DESCRIPCION']


class SubmoduloSerializer(serializers.ModelSerializer):
    class Meta:
        model = Submodulo
        fields = ['IDSUBMODULO', 'NOMBRE', 'DESCRIPCION', 'ICONO', 'ORDEN', 'ACTIVO']


class ModuloSerializer(serializers.ModelSerializer):
    submodulos = SubmoduloSerializer(source='submodulo_set', many=True, read_only=True)

    class Meta:
        model = Modulo
        fields = [
            'IDMODULO', 'NOMBRE', 'DESCRIPCION', 'ICONO', 'ORDEN', 'ACTIVO', 'submodulos',
        ]


class ModuloSimpleSerializer(serializers.ModelSerializer):
    class Meta:
        model = Modulo
        fields = ['IDMODULO', 'NOMBRE', 'DESCRIPCION', 'ICONO', 'ORDEN']


class UsuarioModuloSerializer(serializers.ModelSerializer):
    modulo_detail = ModuloSimpleSerializer(source='IDMODULO', read_only=True)
    permiso = serializers.CharField(source='IDTIPOPERMISO.DESCRIPCION', read_only=True)

    class Meta:
        model = UsuarioModulo
        fields = ['IDUSUARIOMODULO', 'IDUSUARIO', 'IDMODULO', 'modulo_detail', 'permiso']


class GrupoModuloSerializer(serializers.ModelSerializer):
    modulo_detail = ModuloSimpleSerializer(source='IDMODULO', read_only=True)
    permiso = serializers.CharField(source='IDTIPOPERMISO.DESCRIPCION', read_only=True)

    class Meta:
        model = GrupoModulo
        fields = ['IDGRUPOMODULO', 'IDTIPOUSUARIO', 'IDMODULO', 'modulo_detail', 'permiso']

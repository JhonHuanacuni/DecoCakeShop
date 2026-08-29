import { useEffect, useState } from "react";
import { parseJsonResponse } from "../../utils/api";
import { useCrud } from "../../hooks/useCrud";
import { usuarioConfig } from "./usuario.config";
import PageHeader from "../../components/mantenedor/PageHeader";
import Toolbar from "../../components/mantenedor/Toolbar";
import DataTable from "../../components/mantenedor/DataTable";
import Pagination from "../../components/mantenedor/Pagination";
import FormModal from "../../components/mantenedor/FormModal";
import ConfirmDialog from "../../components/mantenedor/ConfirmDialog";
import Toast from "../../components/mantenedor/feedback/Toast";
import "../../styles/mantenedor.css";

export default function UsuarioPage({ navNonce }) {
  const cfg = usuarioConfig;
  const crud = useCrud({ entidad: cfg.entidad, pk: cfg.pk });
  const [modalAbierto, setModalAbierto] = useState(false);
  const [modo, setModo] = useState("crear");
  const [confirm, setConfirm] = useState(null);
  const [toast, setToast] = useState(null);
  const [catalogos, setCatalogos] = useState({ tiposUsuario: [] });
  const [confirmando, setConfirmando] = useState(false);

  useEffect(() => {
    setModalAbierto(false);
  }, [navNonce]);

  useEffect(() => {
    (async () => {
      try {
        const res = await fetch("/api/tipos-usuario/");
        const data = await parseJsonResponse(res);
        if (res.ok) {
          setCatalogos({
            tiposUsuario: (data.data || []).map((t) => ({ value: t.IDTIPOUSUARIO, label: t.DESCRIPCION })),
          });
        }
      } catch { /* catálogo opcional */ }
    })();
  }, []);

  const abrirCrear = () => { crud.setRegistro(null); setModo("crear"); setModalAbierto(true); };
  const abrirVer = async (row) => {
    try { crud.setRegistro(await crud.obtener(row[cfg.pk])); setModo("ver"); setModalAbierto(true); }
    catch (err) { setToast({ mensaje: err.message, tipo: "error" }); }
  };
  const abrirEditar = async (row) => {
    try { crud.setRegistro(await crud.obtener(row[cfg.pk])); setModo("editar"); setModalAbierto(true); }
    catch (err) { setToast({ mensaje: err.message, tipo: "error" }); }
  };

  return (
    <div className="mantenedor-page">
      <PageHeader
        modulo={cfg.modulo}
        vista={modalAbierto ? (modo === "crear" ? "Nuevo" : modo === "editar" ? "Editar" : "Ver") : "Listado"}
        onNuevo={abrirCrear}
        onIrListado={() => setModalAbierto(false)}
      />
      <div className="mantenedor-card">
        <Toolbar
          buscar={crud.buscar}
          onBuscarChange={crud.onBuscarChange}
          filtros={[{
            key: "estado", etiqueta: "Estado", value: crud.filtros.estado || "",
            opciones: ["Activo", "Inactivo"], onChange: (v) => crud.setFiltro("estado", v),
          }]}
        />
        <DataTable
          columnas={cfg.columnas} items={crud.items} pk={cfg.pk} orden={crud.orden}
          loading={crud.loading} error={crud.error} onOrden={crud.toggleOrden}
          onVer={abrirVer} onEditar={abrirEditar}
          onEliminar={(row) => setConfirm({ id: row[cfg.pk], mensaje: `¿Eliminar a ${row.NOMBRE}?` })}
          onReintentar={crud.listar} pagina={crud.pagina} tamanio={crud.tamanio}
        />
        <Pagination pagina={crud.pagina} tamanio={crud.tamanio} total={crud.total} onChange={crud.setPagina} />
      </div>
      <FormModal
        abierto={modalAbierto} modo={modo}
        titulo={modo === "crear" ? "Nuevo usuario" : modo === "editar" ? "Editar usuario" : "Ver usuario"}
        campos={cfg.campos} secciones={cfg.secciones} registro={crud.registro} catalogos={catalogos}
        onClose={() => setModalAbierto(false)}
        onSubmit={async (payload) => {
          const mensaje = modo === "crear" ? await crud.insertar(payload) : await crud.actualizar(crud.registro[cfg.pk], payload);
          setToast({ mensaje, tipo: "success" });
          await crud.listar();
        }}
      />
      <ConfirmDialog
        abierto={Boolean(confirm)} titulo="Confirmar eliminación" mensaje={confirm?.mensaje}
        confirmando={confirmando} onCancel={() => setConfirm(null)}
        onConfirm={async () => {
          try {
            setConfirmando(true);
            const mensaje = await crud.eliminar(confirm.id);
            setToast({ mensaje, tipo: "success" });
            setConfirm(null);
            await crud.listar();
          } catch (err) { setToast({ mensaje: err.message, tipo: "error" }); }
          finally { setConfirmando(false); }
        }}
      />
      {toast && <Toast mensaje={toast.mensaje} tipo={toast.tipo} onClose={() => setToast(null)} />}
    </div>
  );
}

import { useEffect, useState } from "react";
import { useCrud } from "../../hooks/useCrud";
import PageHeader from "./PageHeader";
import Toolbar from "./Toolbar";
import DataTable from "./DataTable";
import Pagination from "./Pagination";
import FormModal from "./FormModal";
import ConfirmDialog from "./ConfirmDialog";
import Toast from "./feedback/Toast";
import "../../styles/mantenedor.css";

export default function MantenedorPage({ config, catalogos = {}, ordenInicial, extraFiltros = [], navNonce }) {
  const cfg = config;
  const crud = useCrud({
    entidad: cfg.entidad,
    pk: cfg.pk,
    ordenInicial: ordenInicial || { campo: cfg.pk, direccion: "ASC" },
    filtrosIniciales: cfg.filtrosIniciales || {},
  });
  const [modalAbierto, setModalAbierto] = useState(false);
  const [modo, setModo] = useState("crear");
  const [confirm, setConfirm] = useState(null);
  const [toast, setToast] = useState(null);
  const [confirmando, setConfirmando] = useState(false);

  useEffect(() => {
    setModalAbierto(false);
  }, [navNonce]);

  const abrirCrear = () => { crud.setRegistro(null); setModo("crear"); setModalAbierto(true); };
  const abrirVer = async (row) => {
    try { crud.setRegistro(await crud.obtener(row[cfg.pk])); setModo("ver"); setModalAbierto(true); }
    catch (err) { setToast({ mensaje: err.message, tipo: "error" }); }
  };
  const abrirEditar = async (row) => {
    try { crud.setRegistro(await crud.obtener(row[cfg.pk])); setModo("editar"); setModalAbierto(true); }
    catch (err) { setToast({ mensaje: err.message, tipo: "error" }); }
  };
  const abrirEliminar = (row) => {
    setConfirm({ id: row[cfg.pk], mensaje: `¿Eliminar «${row.NOMBRE || row.TITULO || row[cfg.pk]}»?` });
  };
  const handleGuardar = async (payload) => {
    const body = { ...payload, ...(cfg.valoresFijos || {}) };
    const mensaje = modo === "crear" ? await crud.insertar(body) : await crud.actualizar(crud.registro[cfg.pk], body);
    setToast({ mensaje, tipo: "success" });
    await crud.listar();
  };
  const handleConfirmEliminar = async () => {
    if (!confirm) return;
    try {
      setConfirmando(true);
      const mensaje = await crud.eliminar(confirm.id);
      setToast({ mensaje, tipo: "success" });
      setConfirm(null);
      await crud.listar();
    } catch (err) { setToast({ mensaje: err.message, tipo: "error" }); }
    finally { setConfirmando(false); }
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
          filtros={[
            {
              key: "estado", etiqueta: "Estado", value: crud.filtros.estado || "",
              opciones: ["Activo", "Inactivo"], onChange: (v) => crud.setFiltro("estado", v),
            },
            ...extraFiltros.map((f) => ({ ...f, value: crud.filtros[f.key] || "", onChange: (v) => crud.setFiltro(f.key, v) })),
          ]}
        />
        <DataTable
          columnas={cfg.columnas} items={crud.items} pk={cfg.pk} orden={crud.orden}
          loading={crud.loading} error={crud.error} onOrden={crud.toggleOrden}
          onVer={abrirVer} onEditar={abrirEditar} onEliminar={abrirEliminar} onReintentar={crud.listar}
          pagina={crud.pagina} tamanio={crud.tamanio}
        />
        <Pagination pagina={crud.pagina} tamanio={crud.tamanio} total={crud.total} onChange={crud.setPagina} />
      </div>
      <FormModal
        abierto={modalAbierto} modo={modo}
        titulo={modo === "crear" ? `Nuevo` : modo === "editar" ? "Editar" : "Ver"}
        campos={cfg.campos} secciones={cfg.secciones} registro={crud.registro}
        catalogos={catalogos} onClose={() => setModalAbierto(false)} onSubmit={handleGuardar}
      />
      <ConfirmDialog
        abierto={Boolean(confirm)} titulo="Confirmar eliminación" mensaje={confirm?.mensaje}
        confirmando={confirmando} onCancel={() => setConfirm(null)} onConfirm={handleConfirmEliminar}
      />
      {toast && <Toast mensaje={toast.mensaje} tipo={toast.tipo} onClose={() => setToast(null)} />}
    </div>
  );
}

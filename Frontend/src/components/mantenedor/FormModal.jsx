import { useEffect, useMemo, useState } from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faSpinner } from "@fortawesome/free-solid-svg-icons";
import FieldRenderer from "./fields/FieldRenderer";
import { dbToInput, inputToDb, hoyInput } from "../../utils/fecha";

const emptyValues = (campos) =>
  campos.reduce((acc, c) => {
    if (c.defaultHoy && c.control === "date") acc[c.campo] = hoyInput();
    else acc[c.campo] = c.defaultValue ?? "";
    return acc;
  }, {});

function campoVisible(campo, values = {}) {
  if (!campo.visibleSi) return true;
  return String(values[campo.visibleSi.campo] ?? "") === String(campo.visibleSi.valor);
}

function filtrarCampo(campo, modo, values = {}) {
  if (modo === "crear" && campo.soloEditar) return false;
  if (modo !== "crear" && campo.soloCrear) return false;
  if (modo === "ver" && campo.campo === "CONTRA") return false;
  if (modo === "editar" && campo.campo === "IDUSUARIO" && campo.control === "text") return false;
  if (!campoVisible(campo, values)) return false;
  return true;
}

export default function FormModal({
  abierto, modo, titulo, campos, secciones, registro, catalogos = {}, onClose, onSubmit,
}) {
  const [values, setValues] = useState({});
  const [errors, setErrors] = useState({});
  const [enviando, setEnviando] = useState(false);
  const soloLectura = modo === "ver";
  const todosLosCampos = useMemo(
    () => (secciones ? secciones.flatMap((s) => s.campos) : campos || []),
    [secciones, campos],
  );

  useEffect(() => {
    if (!abierto) return;
    if (modo === "crear") {
      const next = emptyValues(todosLosCampos);
      todosLosCampos.forEach((c) => {
        if (!c.defaultCatalogoLabel || !c.catalogo) return;
        const match = (catalogos[c.catalogo] || []).find(
          (op) => String(op.label || "").toLowerCase() === String(c.defaultCatalogoLabel).toLowerCase()
        );
        if (match) next[c.campo] = match.value;
      });
      setValues(next);
    } else if (registro) {
      const next = { ...registro };
      todosLosCampos.forEach((c) => {
        if (c.control === "date" && next[c.campo]) next[c.campo] = dbToInput(String(next[c.campo]));
        if (c.control === "number" && next[c.campo] != null && next[c.campo] !== "") {
          next[c.campo] = Number(next[c.campo]);
        }
      });
      if (next.USOSMAX) next.VIGENCIA = "Limitado";
      else if (!next.VIGENCIA) next.VIGENCIA = "Permanente";
      setValues(next);
    }
    setErrors({});
  }, [abierto, modo, registro, todosLosCampos, catalogos]);

  if (!abierto) return null;

  const validate = () => {
    const next = {};
    todosLosCampos.filter((c) => filtrarCampo(c, modo, values)).forEach((c) => {
      if (soloLectura) return;
      if (c.obligatorio && !String(values[c.campo] ?? "").trim() && c.campo !== "CONTRA") {
        next[c.campo] = `Ingresa ${c.etiqueta.toLowerCase()}.`;
      }
      if (c.validacion === "email" && values[c.campo]) {
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(values[c.campo])) next[c.campo] = "Ingresa un email válido.";
      }
    });
    if (Object.keys(next).length > 0) next._form = "Completa los campos obligatorios marcados en rojo.";
    setErrors(next);
    return Object.keys(next).filter((k) => k !== "_form").length === 0;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (soloLectura) return onClose();
    if (!validate()) return;
    const payload = { ...values };
    todosLosCampos.forEach((c) => {
      if (c.control === "date") payload[c.campo] = inputToDb(values[c.campo]) || null;
    });
    if (payload.VIGENCIA === "Permanente") payload.USOSMAX = null;
    if (modo === "editar" && !payload.CONTRA) delete payload.CONTRA;
    try {
      setEnviando(true);
      await onSubmit(payload);
      onClose();
    } catch (err) {
      setErrors({ _form: err.message });
    } finally {
      setEnviando(false);
    }
  };

  const bloques = secciones
    ? secciones.map((sec) => ({
        titulo: sec.titulo,
        campos: sec.campos.filter((c) => filtrarCampo(c, modo, values)),
      })).filter((sec) => sec.campos.length > 0)
    : [{ titulo: null, campos: (campos || []).filter((c) => filtrarCampo(c, modo, values)) }];

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className={`modal-panel modal-panel--form ${secciones ? "modal-panel--wide" : ""}`} onClick={(e) => e.stopPropagation()}>
        <div className="modal-header"><h2>{titulo}</h2></div>
        <form className="modal-form" onSubmit={handleSubmit}>
          <div className="modal-body">
            {errors._form && <p className="field-error form-error-banner">{errors._form}</p>}
            {bloques.map((bloque) => (
              <section key={bloque.titulo || "default"} className="form-section">
                {bloque.titulo && <h3 className="form-section-title">{bloque.titulo}</h3>}
                <div className="form-grid">
                  {bloque.campos.map((campo) => (
                    <FieldRenderer
                      key={campo.campo}
                      campo={campo}
                      value={values[campo.campo] ?? ""}
                      error={errors[campo.campo]}
                      disabled={soloLectura || (campo.soloCrear && modo === "editar") || campo.bloqueado}
                      catalogo={catalogos[campo.catalogo]}
                      onChange={(val) => setValues((prev) => ({ ...prev, [campo.campo]: val }))}
                    />
                  ))}
                </div>
              </section>
            ))}
          </div>
          <div className="modal-footer">
            <button type="button" className="btn-secondary" onClick={onClose}>{soloLectura ? "Cerrar" : "Cancelar"}</button>
            {!soloLectura && (
              <button type="submit" className="btn-primary" disabled={enviando}>
                {enviando && <FontAwesomeIcon icon={faSpinner} spin />} Guardar
              </button>
            )}
          </div>
        </form>
      </div>
    </div>
  );
}

import { useRef, useState } from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faCloudArrowUp } from "@fortawesome/free-solid-svg-icons";
import { fileToBase64Resized } from "../../../utils/imagen";
import { phIngrese, phSeleccione } from "../../../utils/placeholder";

const MAX_FOTO_MB = 5;

async function leerImagen(file, onChange) {
  if (!file || !file.type.startsWith("image/")) return;
  if (file.size > MAX_FOTO_MB * 1024 * 1024) return;
  try { onChange(await fileToBase64Resized(file)); }
  catch { onChange(""); }
}

function FotoDropzone({ value, disabled, onChange }) {
  const inputRef = useRef(null);
  const [arrastrando, setArrastrando] = useState(false);

  const onFiles = (files) => leerImagen(files?.[0], onChange);

  return (
    <div className="foto-drop">
      <div className="foto-drop-title">Imagen del producto</div>
      <button
        type="button"
        className={`foto-drop-zone${arrastrando ? " is-drag" : ""}${disabled ? " is-disabled" : ""}${value ? " has-foto" : ""}`}
        disabled={disabled}
        onClick={() => !disabled && inputRef.current?.click()}
        onDragEnter={(e) => { e.preventDefault(); if (!disabled) setArrastrando(true); }}
        onDragOver={(e) => { e.preventDefault(); if (!disabled) setArrastrando(true); }}
        onDragLeave={() => setArrastrando(false)}
        onDrop={(e) => {
          e.preventDefault();
          setArrastrando(false);
          if (!disabled) onFiles(e.dataTransfer.files);
        }}
      >
        {value ? (
          <img src={value} alt="" />
        ) : (
          <>
            <FontAwesomeIcon icon={faCloudArrowUp} className="foto-drop-icon" />
            <span className="foto-drop-cta">Seleccionar imagen</span>
            <span className="foto-drop-hint">Formatos .jpg, .png · Máximo 5 MB</span>
          </>
        )}
      </button>
      <input
        ref={inputRef}
        type="file"
        accept="image/jpeg,image/png,image/webp"
        hidden
        disabled={disabled}
        onChange={(e) => {
          onFiles(e.target.files);
          e.target.value = "";
        }}
      />
      {value && !disabled && (
        <button type="button" className="foto-drop-quitar" onClick={() => onChange("")}>Quitar imagen</button>
      )}
    </div>
  );
}

export default function FieldRenderer({ campo, value, error, disabled, catalogo = [], onChange }) {
  const className = `form-field ${campo.full ? "full" : ""} ${error ? "has-error" : ""} ${campo.control === "foto" ? "form-field--foto" : ""}`;
  const renderControl = () => {
    const phSel = phSeleccione(campo.etiqueta);
    const phTxt = phIngrese(campo.etiqueta);
    if (campo.control === "foto") {
      return <FotoDropzone value={value} disabled={disabled} onChange={onChange} />;
    }
    if (campo.control === "select" && campo.catalogo) {
      return (
        <select value={value} disabled={disabled} onChange={(e) => onChange(e.target.value)}>
          <option value="">{phSel}</option>
          {(catalogo || []).map((op) => (
            <option key={op.value} value={op.value}>{op.label}</option>
          ))}
        </select>
      );
    }
    if (campo.control === "select") {
      return (
        <select value={value} disabled={disabled} onChange={(e) => onChange(e.target.value)}>
          <option value="">{phSel}</option>
          {(campo.opciones || []).map((op) => {
            const val = typeof op === "object" ? op.value : op;
            const label = typeof op === "object" ? op.label : op;
            return <option key={val} value={val}>{label}</option>;
          })}
        </select>
      );
    }
    if (campo.control === "textarea") {
      return (
        <textarea rows={3} value={value} disabled={disabled} placeholder={phTxt} onChange={(e) => onChange(e.target.value)} />
      );
    }
    return (
      <input
        type={
          campo.control === "password" ? "password"
            : campo.control === "date" ? "date"
              : campo.control === "number" ? "number"
                : "text"
        }
        step={campo.control === "number" ? (campo.step ?? "0.01") : undefined}
        min={campo.control === "number" ? (campo.min ?? "0") : undefined}
        value={value ?? ""}
        disabled={disabled}
        placeholder={campo.control === "date" ? undefined : phTxt}
        onChange={(e) => onChange(e.target.value)}
      />
    );
  };
  return (
    <div className={className}>
      {campo.control !== "foto" && <label htmlFor={campo.campo}>{campo.etiqueta}</label>}
      {renderControl()}
      {campo.ayuda && !error && <span className="field-hint">{campo.ayuda}</span>}
      {error && <span className="field-error">{error}</span>}
    </div>
  );
}

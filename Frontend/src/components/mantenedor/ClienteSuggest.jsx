import { useEffect, useRef, useState } from "react";
import { parseJsonResponse } from "../../utils/api";

export default function ClienteSuggest({ value, onChange, disabled, placeholder, minChars = 3 }) {
  const [abierto, setAbierto] = useState(false);
  const [resultados, setResultados] = useState([]);
  const wrapRef = useRef(null);
  const debounceRef = useRef(null);

  useEffect(() => {
    const q = String(value || "").trim();
    clearTimeout(debounceRef.current);
    if (q.length < minChars) {
      setResultados([]);
      return undefined;
    }
    debounceRef.current = setTimeout(async () => {
      try {
        const res = await fetch(`/api/clientes/buscar/?q=${encodeURIComponent(q)}`);
        const data = await parseJsonResponse(res);
        setResultados(res.ok ? (data.data || []) : []);
      } catch {
        setResultados([]);
      }
    }, 250);
    return () => clearTimeout(debounceRef.current);
  }, [value, minChars]);

  useEffect(() => {
    const onDoc = (e) => {
      if (!wrapRef.current?.contains(e.target)) setAbierto(false);
    };
    document.addEventListener("mousedown", onDoc);
    return () => document.removeEventListener("mousedown", onDoc);
  }, []);

  const q = String(value || "").trim();
  const mostrar = abierto && !disabled && q.length >= minChars && resultados.length > 0;

  return (
    <div className="suggest" ref={wrapRef}>
      <input
        disabled={disabled}
        value={value || ""}
        placeholder={placeholder}
        autoComplete="off"
        onFocus={() => setAbierto(true)}
        onChange={(e) => {
          onChange(e.target.value, null);
          setAbierto(true);
        }}
      />
      {mostrar && (
        <ul className="suggest-list">
          {resultados.map((c) => (
            <li
              key={c.value}
              onMouseDown={(e) => {
                e.preventDefault();
                onChange(c.label, c.value);
                setAbierto(false);
              }}
            >
              {c.label}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

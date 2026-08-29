export const dbToInput = (s) =>
  s && s.length === 8 ? `${s.slice(4)}-${s.slice(2, 4)}-${s.slice(0, 2)}` : "";

export const inputToDb = (s) => (s ? s.split("-").reverse().join("") : null);

export const dbToView = (s) =>
  s && s.length === 8 ? `${s.slice(0, 2)}/${s.slice(2, 4)}/${s.slice(4)}` : "";

export const hoyInput = () => {
  const hoy = new Date();
  const y = hoy.getFullYear();
  const m = String(hoy.getMonth() + 1).padStart(2, "0");
  const d = String(hoy.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
};

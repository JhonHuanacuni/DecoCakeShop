import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "./index.css";
import App from "./App.jsx";
import ShopApp from "./shop/ShopApp.jsx";

function esRutaSistema() {
  const path = window.location.pathname.replace(/\/+$/, "") || "/";
  return path === "/sistema" || path.startsWith("/sistema/");
}

createRoot(document.getElementById("root")).render(
  <StrictMode>
    {esRutaSistema() ? <App /> : <ShopApp />}
  </StrictMode>,
);

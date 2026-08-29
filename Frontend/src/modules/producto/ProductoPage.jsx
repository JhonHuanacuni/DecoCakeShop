import { useEffect, useState } from "react";
import { parseJsonResponse } from "../../utils/api";
import MantenedorPage from "../../components/mantenedor/MantenedorPage";
import { productoConfig } from "../catalogos/catalogos.config";

export default function ProductoPage({ navNonce }) {
  const [catalogos, setCatalogos] = useState({ categorias: [], unidades: [] });
  useEffect(() => {
    (async () => {
      try {
        const res = await fetch("/api/productos/catalogos/");
        const data = await parseJsonResponse(res);
        if (res.ok) {
          setCatalogos({
            categorias: data.categorias || [],
            unidades: data.unidades || [],
          });
        }
      } catch { /* opcional */ }
    })();
  }, []);
  return (
    <MantenedorPage
      config={productoConfig}
      catalogos={catalogos}
      ordenInicial={{ campo: "NOMBRE", direccion: "ASC" }}
      navNonce={navNonce}
    />
  );
}

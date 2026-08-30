import { useCallback, useEffect, useState } from "react";
import Layout from "./components/layout/Layout";
import LoginPage from "./components/LoginPage";
import "./components/LoginPage.css";
import AdminModulos from "./components/admin/AdminModulos";
import UsuarioPage from "./modules/usuario/UsuarioPage";
import ProductoPage from "./modules/producto/ProductoPage";
import CotizacionPage from "./modules/cotizacion/CotizacionPage";
import VentaPage from "./modules/venta/VentaPage";
import DashboardPage from "./modules/dashboard/DashboardPage";
import AuditoriaPage from "./modules/auditoria/AuditoriaPage";
import PagoPage from "./modules/pago/PagoPage";
import {
  CategoriaPage, UnidadPage, ClientePage, FormaPagoPage, TipoEntregaPage, CuponPage, CarruselPage, PromocionPage,
} from "./modules/catalogos/CatalogoPages";
import "./App.css";

const SEED_USERS_BY_TIPO = { 1: "vendedor", 2: "almacen", 3: "admin" };

function normalizeUserId(raw, role = "") {
  const value = String(raw || "").trim();
  if (SEED_USERS_BY_TIPO[value]) return SEED_USERS_BY_TIPO[value];
  if (!value && role === "administrador") return "admin";
  return value;
}

const pageContent = {
  dashboard: { title: "Dashboard", description: "Resumen operativo.", component: DashboardPage },
  usuarios: { title: "Usuarios", description: "Administración de usuarios.", component: UsuarioPage },
  productos: { title: "Productos", description: "Inventario de la importadora.", component: ProductoPage },
  cotizaciones: { title: "Cotizaciones", description: "Cotizaciones y conversión a pedido.", component: CotizacionPage },
  ventas: { title: "Pedidos", description: "Pedidos confirmados con datos de envío.", component: VentaPage },
  pagos: { title: "Pagos", description: "Pagos y abonos recientes.", component: PagoPage },
  cupones: { title: "Cupones", description: "Descuentos de la tienda.", component: CuponPage },
  auditoria: { title: "Auditoría", description: "Historial de cambios.", component: AuditoriaPage },
  "admin-modulos": { title: "Administración de módulos", description: "Acceso por usuario y rol.", component: AdminModulos },
  mantenedores: { title: "Mantenedores", description: "Catálogos del sistema." },
  "mantenedores-categorias": { title: "Categorías", description: "Categorías de producto.", component: CategoriaPage },
  "mantenedores-clientes": { title: "Clientes", description: "Clientes de la importadora.", component: ClientePage },
  "mantenedores-unidades": { title: "Unidades", description: "Unidades de medida.", component: UnidadPage },
  "mantenedores-formas-pago": { title: "Formas de pago", description: "Medios de pago.", component: FormaPagoPage },
  "mantenedores-tipos-entrega": { title: "Tipos de entrega", description: "Recojo y delivery.", component: TipoEntregaPage },
  "catalogo-tienda": { title: "Catálogo", description: "Carrusel y promociones de la tienda." },
  "catalogo-carrusel": { title: "Carrusel", description: "Imágenes del banner de inicio.", component: CarruselPage },
  "catalogo-promociones": { title: "Promociones", description: "Textos e imágenes de promociones.", component: PromocionPage },
};

function App() {
  const [role, setRole] = useState(() => localStorage.getItem("role") || "vendedor");
  const [idusuario, setIdusuario] = useState(() => {
    const storedRole = localStorage.getItem("role") || "";
    return normalizeUserId(localStorage.getItem("idusuario") || "", storedRole);
  });
  const [activePage, setActivePage] = useState(() => localStorage.getItem("activePage") || "dashboard");
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);
  const [isAuthenticated, setIsAuthenticated] = useState(() => localStorage.getItem("isAuthenticated") === "true");
  const [loginError, setLoginError] = useState("");
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [navNonce, setNavNonce] = useState(0);
  const page = pageContent[activePage] || pageContent.dashboard;

  const handleChangePage = useCallback((pageId) => {
    setActivePage(pageId);
    setNavNonce((n) => n + 1);
    setIsSidebarOpen(false);
  }, []);

  const handleMenuLoaded = useCallback((allowedPages) => {
    setActivePage((current) => {
      if (allowedPages.length === 0) return "dashboard";
      if (allowedPages.includes(current)) return current;
      return allowedPages.includes("dashboard") ? "dashboard" : allowedPages[0];
    });
  }, []);

  const handleLogin = async (event) => {
    event.preventDefault();
    setLoginError("");
    try {
      const response = await fetch("/api/login/", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ username, password }),
      });
      const data = await response.json();
      if (!response.ok) {
        setLoginError(data.error || "Error al iniciar sesión");
        return;
      }
      if (data.valid) {
        const userRole = data.role || "vendedor";
        const userId = normalizeUserId(username || data.idusuario, userRole);
        setIsAuthenticated(true);
        setRole(userRole);
        setIdusuario(userId);
        setActivePage("dashboard");
        setPassword("");
        setUsername("");
        setLoginError("");
        localStorage.setItem("isAuthenticated", "true");
        localStorage.setItem("role", userRole);
        localStorage.setItem("idusuario", userId);
        if (data.idtipousuario) {
          localStorage.setItem("idtipousuario", String(data.idtipousuario));
        }
        localStorage.setItem("activePage", "dashboard");
      } else {
        setLoginError("Usuario o contraseña incorrectos");
      }
    } catch {
      setLoginError("No se pudo conectar con el backend");
    }
  };

  const handleLogout = () => {
    setIsAuthenticated(false);
    setActivePage("dashboard");
    setRole("vendedor");
    setIdusuario("");
    setIsSidebarOpen(false);
    localStorage.removeItem("isAuthenticated");
    localStorage.removeItem("role");
    localStorage.removeItem("idusuario");
    localStorage.removeItem("idtipousuario");
    localStorage.removeItem("activePage");
  };

  useEffect(() => {
    if (isAuthenticated) {
      localStorage.setItem("isAuthenticated", "true");
      localStorage.setItem("role", role);
      localStorage.setItem("idusuario", idusuario);
      localStorage.setItem("activePage", activePage);
    }
  }, [isAuthenticated, role, idusuario, activePage]);

  if (!isAuthenticated) {
    return (
      <LoginPage
        username={username}
        password={password}
        loginError={loginError}
        onUsernameChange={setUsername}
        onPasswordChange={setPassword}
        onSubmit={handleLogin}
      />
    );
  }

  return (
    <Layout
      role={role}
      idusuario={idusuario}
      activePage={activePage}
      onChangePage={handleChangePage}
      onMenuLoaded={handleMenuLoaded}
      isSidebarOpen={isSidebarOpen}
      onToggleSidebar={() => setIsSidebarOpen((prev) => !prev)}
      onCloseSidebar={() => setIsSidebarOpen(false)}
      onLogout={handleLogout}
    >
      {page.component ? (
        <page.component role={role} idusuario={idusuario} onChangePage={handleChangePage} navNonce={navNonce} />
      ) : (
        <>
          <div className="page-header">
            <h1>{page.title}</h1>
            <p>{page.description}</p>
          </div>
          <section className="page-body">
            <div className="page-card">
              <p>Selecciona otra opción del menú para navegar entre módulos.</p>
            </div>
          </section>
        </>
      )}
    </Layout>
  );
}

export default App;

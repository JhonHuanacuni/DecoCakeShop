import { useState, useEffect, useRef } from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faBars, faUser } from "@fortawesome/free-solid-svg-icons";

const ROLE_LABELS = {
  vendedor: "Vendedor",
  almacen: "Almacén",
  administrador: "Administrador",
  admin: "Administrador",
};

const Navbar = ({ role, onToggleSidebar, onLogout }) => {
  const [showUserMenu, setShowUserMenu] = useState(false);
  const userMenuRef = useRef(null);
  const userRole = ROLE_LABELS[role] || "Usuario";

  useEffect(() => {
    const handleClickOutside = (event) => {
      if (userMenuRef.current && !userMenuRef.current.contains(event.target)) {
        setShowUserMenu(false);
      }
    };
    document.addEventListener("click", handleClickOutside);
    return () => document.removeEventListener("click", handleClickOutside);
  }, []);

  return (
    <header className="app-navbar">
      <div className="navbar-left">
        <button className="navbar-toggle" onClick={onToggleSidebar} aria-label="Abrir menú">
          <FontAwesomeIcon icon={faBars} />
        </button>
        <div className="navbar-brand" onClick={() => window.scrollTo(0, 0)}>
          DECOCAKE SHOP
        </div>
      </div>
      <div className="navbar-right">
        <span className="navbar-role">{userRole}</span>
        <div className="navbar-user" ref={userMenuRef}>
          <button
            className="navbar-icon-btn"
            onClick={() => setShowUserMenu((prev) => !prev)}
            aria-label="Abrir menú de usuario"
          >
            <FontAwesomeIcon icon={faUser} />
          </button>
          {showUserMenu && (
            <div className="navbar-dropdown">
              <a className="navbar-dropdown-item" href="/">Ver catálogo</a>
              <button className="navbar-dropdown-item" type="button" onClick={onLogout}>
                Cerrar sesión
              </button>
            </div>
          )}
        </div>
      </div>
    </header>
  );
};

export default Navbar;

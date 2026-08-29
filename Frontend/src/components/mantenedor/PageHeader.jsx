import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faChevronRight, faPlus } from "@fortawesome/free-solid-svg-icons";

export default function PageHeader({
  modulo, vista, titulo, onNuevo, mostrarNuevo = true, nuevoEtiqueta = "Nuevo", onIrListado,
}) {
  const tieneBreadcrumb = Boolean(modulo && vista);
  const enListado = String(vista || "") === "Listado";
  const CrumbModulo = onIrListado ? (
    <button type="button" className="page-breadcrumb-link" onClick={onIrListado}>{modulo}</button>
  ) : (
    <span className="page-breadcrumb-link">{modulo}</span>
  );
  const CrumbListado = onIrListado ? (
    <button type="button" className="page-breadcrumb-link" onClick={onIrListado}>Listado</button>
  ) : (
    <span className="page-breadcrumb-link">Listado</span>
  );

  return (
    <div className={`mantenedor-page-header ${tieneBreadcrumb ? "mantenedor-page-header--breadcrumb" : ""}`}>
      <div className="mantenedor-page-header-main">
        {tieneBreadcrumb ? (
          <nav className="page-breadcrumb" aria-label="Ruta de navegación">
            {CrumbModulo}
            <FontAwesomeIcon icon={faChevronRight} className="page-breadcrumb-sep" />
            {enListado ? (
              <h1 className="page-breadcrumb-vista">Listado</h1>
            ) : (
              <>
                {CrumbListado}
                <FontAwesomeIcon icon={faChevronRight} className="page-breadcrumb-sep" />
                <h1 className="page-breadcrumb-vista">{vista}</h1>
              </>
            )}
          </nav>
        ) : (
          <h1>{titulo}</h1>
        )}
      </div>
      {mostrarNuevo && enListado && (
        <button type="button" className="btn-primary" onClick={onNuevo}>
          <FontAwesomeIcon icon={faPlus} />
          {nuevoEtiqueta}
        </button>
      )}
    </div>
  );
}

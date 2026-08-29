import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faUser, faLock, faArrowRight } from "@fortawesome/free-solid-svg-icons";
import logoImg from "../images/LogoDecoCakeShop.png";

export default function LoginPage({
  username, password, loginError, onUsernameChange, onPasswordChange, onSubmit,
}) {
  return (
    <div className="login-vita">
      <div className="login-vita-bg" aria-hidden="true" />
      <div className="login-vita-content">
        <div className="login-vita-card">
          <div className="login-vita-brand">
            <img src={logoImg} alt="DecoCake Shop" className="login-vita-logo" />
            <p>Importadora</p>
          </div>
          {loginError ? <div className="login-vita-error">{loginError}</div> : null}
          <form className="login-vita-form" onSubmit={onSubmit}>
            <label className="login-vita-field">
              <span className="login-vita-label">
                <FontAwesomeIcon icon={faUser} /> Usuario
              </span>
              <input
                type="text"
                value={username}
                onChange={(event) => onUsernameChange(event.target.value)}
                placeholder="INGRESE USUARIO"
                required
                autoComplete="username"
              />
            </label>
            <label className="login-vita-field">
              <span className="login-vita-label">
                <FontAwesomeIcon icon={faLock} /> Contraseña
              </span>
              <input
                type="password"
                value={password}
                onChange={(event) => onPasswordChange(event.target.value)}
                placeholder="INGRESE CONTRASEÑA"
                required
                autoComplete="current-password"
              />
            </label>
            <button type="submit" className="login-vita-button">
              <span>Ingresar</span>
              <FontAwesomeIcon icon={faArrowRight} />
            </button>
          </form>
          <a className="login-vita-back" href="/">Volver al catálogo</a>
        </div>
      </div>
    </div>
  );
}

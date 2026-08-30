import MantenedorPage from "../../components/mantenedor/MantenedorPage";
import { categoriaConfig, unidadConfig, clienteConfig, formaPagoConfig, tipoEntregaConfig, cuponConfig, carruselConfig, promocionConfig } from "./catalogos.config";

export function CategoriaPage(props) { return <MantenedorPage config={categoriaConfig} ordenInicial={{ campo: "ORDEN", direccion: "ASC" }} navNonce={props.navNonce} />; }
export function UnidadPage(props) { return <MantenedorPage config={unidadConfig} navNonce={props.navNonce} />; }
export function ClientePage(props) { return <MantenedorPage config={clienteConfig} navNonce={props.navNonce} />; }
export function FormaPagoPage(props) { return <MantenedorPage config={formaPagoConfig} navNonce={props.navNonce} />; }
export function TipoEntregaPage(props) { return <MantenedorPage config={tipoEntregaConfig} navNonce={props.navNonce} />; }
export function CuponPage(props) { return <MantenedorPage config={cuponConfig} ordenInicial={{ campo: "CODIGO", direccion: "ASC" }} navNonce={props.navNonce} />; }
export function CarruselPage(props) { return <MantenedorPage config={carruselConfig} ordenInicial={{ campo: "ORDEN", direccion: "ASC" }} navNonce={props.navNonce} />; }
export function PromocionPage(props) { return <MantenedorPage config={promocionConfig} ordenInicial={{ campo: "ORDEN", direccion: "ASC" }} navNonce={props.navNonce} />; }

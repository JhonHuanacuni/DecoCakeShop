import { useEffect, useRef, useState } from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import {
  faSearch, faHeart, faBagShopping, faXmark, faPlus, faMinus,
  faArrowUp, faPhone, faLocationDot, faClock, faBars, faUser, faCloudArrowUp,
} from "@fortawesome/free-solid-svg-icons";
import logoImg from "../images/LogoDecoCakeShop.png";
import slideBowls from "./slides/slide-bowls.png";
import slideFondant from "./slides/slide-fondant.png";
import slideColorantes from "./slides/slide-colorantes.png";
import { fileToBase64Resized } from "../utils/imagen";
import "./shop.css";

const SLIDES = [
  { src: slideBowls, alt: "Set de bowls metálicos anidables" },
  { src: slideFondant, alt: "Fondant y pastas de modelar" },
  { src: slideColorantes, alt: "Colorantes y cortadores" },
];

const PROMOS = [
  {
    src: "/shop-products/05-bols-de-acero-x7und.png",
    kicker: "Combo del mes",
    titulo: "Set de bowls metálicos",
    texto: "7 piezas anidables, de 18 a 30 cm, para batir y guardar con orden.",
    precio: 58,
    precioTexto: "",
    enlace: "CAT004",
    estilo: "rosa",
  },
  {
    src: "/shop-products/12-kekera-rectangular-x5-und.jpeg",
    kicker: "Hornea más",
    titulo: "Kekeras y moldes",
    texto: "Sets listos para tortas, kekes y celebraciones de todo tamaño.",
    precio: 14,
    precioTexto: "Desde",
    enlace: "CAT003",
    estilo: "teal",
  },
];

const WHATSAPP = "51940247576";
const SOCIAL = {
  instagram: "https://www.instagram.com/decocake.shop",
  facebook: "https://www.facebook.com/DecoCaake",
  tiktok: "https://www.tiktok.com/@decocakeshop",
};
const CART_KEY = "decocake-cart";
const WISH_KEY = "decocake-wish";
const PAGE_SIZE = 12;

function money(n) {
  return `S/ ${Number(n || 0).toLocaleString("es-PE", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function loadJson(key, fallback) {
  try {
    const raw = JSON.parse(localStorage.getItem(key) || "");
    return raw ?? fallback;
  } catch {
    return fallback;
  }
}

export default function ShopApp() {
  const [seccion, setSeccion] = useState(() => (window.location.hash || "#inicio").replace("#", "") || "inicio");
  const [categorias, setCategorias] = useState([]);
  const [productos, setProductos] = useState([]);
  const [destacados, setDestacados] = useState([]);
  const [favoritosItems, setFavoritosItems] = useState([]);
  const [totalProductos, setTotalProductos] = useState(0);
  const [consulta, setConsulta] = useState("");
  const [pagina, setPagina] = useState(1);
  const [categoria, setCategoria] = useState("");
  const [buscar, setBuscar] = useState("");
  const [cart, setCart] = useState(() => loadJson(CART_KEY, []));
  const [wish, setWish] = useState(() => loadJson(WISH_KEY, []));
  const [cartOpen, setCartOpen] = useState(false);
  const [topVisible, setTopVisible] = useState(false);
  const [headerHidden, setHeaderHidden] = useState(false);
  const lastScroll = useRef(0);
  const headerLock = useRef(false);
  const [slide, setSlide] = useState(0);
  const [slides, setSlides] = useState(SLIDES);
  const [promos, setPromos] = useState(PROMOS);
  const [cuponCodigo, setCuponCodigo] = useState("");
  const [cupon, setCupon] = useState(null);
  const [cuponError, setCuponError] = useState("");
  const [cuponLoading, setCuponLoading] = useState(false);
  const [cartBump, setCartBump] = useState(false);
  const [wishBump, setWishBump] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [menuTab, setMenuTab] = useState("menu");
  const [menuBuscar, setMenuBuscar] = useState("");
  const [checkoutOps, setCheckoutOps] = useState({ formasPago: [], tiposEntrega: [] });
  const [pedido, setPedido] = useState({
    nombre: "", apellidos: "", telefono: "", email: "",
    idTipoEntrega: "", direccion: "", distrito: "",
    idFormaPago: "", comprobante: "", notas: "",
  });
  const [pedidoError, setPedidoError] = useState("");
  const [pedidoOk, setPedidoOk] = useState("");
  const [pedidoLoading, setPedidoLoading] = useState(false);

  useEffect(() => {
    const onHash = () => setSeccion((window.location.hash || "#inicio").replace("#", "") || "inicio");
    window.addEventListener("hashchange", onHash);
    return () => window.removeEventListener("hashchange", onHash);
  }, []);

  useEffect(() => {
    headerLock.current = menuOpen || cartOpen;
    if (headerLock.current) setHeaderHidden(false);
  }, [menuOpen, cartOpen]);

  useEffect(() => {
    lastScroll.current = window.scrollY || document.documentElement.scrollTop || 0;
    let ticking = false;
    const onScroll = () => {
      if (ticking) return;
      ticking = true;
      window.requestAnimationFrame(() => {
        const y = window.scrollY || document.documentElement.scrollTop || 0;
        const last = lastScroll.current;
        lastScroll.current = y;
        setTopVisible(y > 400);
        if (headerLock.current || y < 80) {
          setHeaderHidden(false);
        } else if (y - last > 6) {
          setHeaderHidden(true);
        } else if (last - y > 6) {
          setHeaderHidden(false);
        }
        ticking = false;
      });
    };
    window.addEventListener("scroll", onScroll, { passive: true });
    document.addEventListener("scroll", onScroll, { passive: true });
    return () => {
      window.removeEventListener("scroll", onScroll);
      document.removeEventListener("scroll", onScroll);
    };
  }, []);

  useEffect(() => { localStorage.setItem(CART_KEY, JSON.stringify(cart)); }, [cart]);
  useEffect(() => { localStorage.setItem(WISH_KEY, JSON.stringify(wish)); }, [wish]);

  useEffect(() => {
    document.body.style.overflow = menuOpen ? "hidden" : "";
    return () => { document.body.style.overflow = ""; };
  }, [menuOpen]);

  useEffect(() => {
    if (seccion !== "inicio") return undefined;
    if (!slides.length) return undefined;
    const timer = setInterval(() => setSlide((n) => (n + 1) % slides.length), 5500);
    return () => clearInterval(timer);
  }, [seccion, slides.length]);

  useEffect(() => {
    (async () => {
      try {
        const res = await fetch("/api/tienda/promociones/");
        const data = await res.json();
        if (!res.ok) return;
        if (data.slides?.length) {
          setSlides(data.slides.map((s) => ({
            src: s.IMAGEN, alt: s.TITULO || "Promoción",
          })));
          setSlide(0);
        }
        if (data.cards?.length) {
          setPromos(data.cards.map((c) => ({
            src: c.IMAGEN,
            kicker: c.SUBTITULO || "",
            titulo: c.TITULO,
            texto: c.DESCRIPCION || "",
            precio: c.PRECIO,
            precioTexto: c.PRECIOTEXTO || "",
            enlace: c.ENLACE || "",
            estilo: c.ESTILO || "rosa",
          })));
        }
      } catch { /* usa el contenido por defecto */ }
    })();
  }, []);

  useEffect(() => {
    (async () => {
      try {
        const res = await fetch("/api/tienda/catalogo/?destacados=1");
        const data = await res.json();
        if (res.ok) {
          setCategorias(data.categorias || []);
          setDestacados(data.productos || []);
        }
      } catch { /* catálogo vacío */ }
    })();
  }, []);

  useEffect(() => {
    const timer = window.setTimeout(() => {
      setConsulta(buscar.trim());
      setPagina(1);
    }, buscar.trim() ? 350 : 0);
    return () => window.clearTimeout(timer);
  }, [buscar]);

  useEffect(() => {
    if (seccion !== "productos") return undefined;
    (async () => {
      try {
        const q = new URLSearchParams({ pagina: String(pagina), tamanio: String(PAGE_SIZE) });
        if (categoria) q.set("categoria", categoria);
        if (consulta) q.set("buscar", consulta);
        const res = await fetch(`/api/tienda/catalogo/?${q}`);
        const data = await res.json();
        if (res.ok) {
          setCategorias(data.categorias || []);
          setProductos(data.productos || []);
          setTotalProductos(Number(data.total || 0));
        }
      } catch { /* listado vacío */ }
    })();
  }, [seccion, pagina, categoria, consulta]);

  useEffect(() => {
    if (seccion !== "favoritos") return undefined;
    if (!wish.length) {
      setFavoritosItems([]);
      return undefined;
    }
    (async () => {
      try {
        const res = await fetch(`/api/tienda/catalogo/?ids=${encodeURIComponent(wish.join(","))}`);
        const data = await res.json();
        if (res.ok) setFavoritosItems(data.productos || []);
      } catch { setFavoritosItems([]); }
    })();
  }, [seccion, wish]);

  useEffect(() => {
    if (seccion !== "checkout") return undefined;
    (async () => {
      try {
        const res = await fetch("/api/tienda/checkout/");
        const data = await res.json();
        if (res.ok) setCheckoutOps({ formasPago: data.formasPago || [], tiposEntrega: data.tiposEntrega || [] });
      } catch { /* catálogos vacíos */ }
    })();
  }, [seccion]);

  const cerrarMenu = () => setMenuOpen(false);

  const ir = (id, cat) => {
    if (id === "productos" && cat !== undefined) {
      setPagina(1);
      setCategoria(cat);
    }
    setSeccion(id);
    window.location.hash = id;
    window.scrollTo({ top: 0, behavior: "smooth" });
    setHeaderHidden(false);
    cerrarMenu();
  };

  const filtrarCategoria = (cat) => {
    setPagina(1);
    setCategoria(cat);
  };

  const buscarDesdeMenu = (e) => {
    e.preventDefault();
    setBuscar(menuBuscar.trim());
    ir("productos");
  };

  const itemsCount = cart.reduce((s, i) => s + Number(i.cantidad || 0), 0);
  const subtotal = cart.reduce((s, i) => s + Number(i.precio || 0) * Number(i.cantidad || 0), 0);
  const descuento = cupon ? Number(cupon.descuento || 0) : 0;
  const total = Math.max(0, subtotal - descuento);

  const addCart = (p) => {
    setCart((prev) => {
      const i = prev.findIndex((x) => x.id === p.IDPRODUCTO);
      if (i >= 0) return prev.map((x, idx) => idx === i ? { ...x, cantidad: x.cantidad + 1 } : x);
      return [...prev, {
        id: p.IDPRODUCTO, nombre: p.NOMBRE, precio: Number(p.PRECIO || 0),
        cantidad: 1, foto: p.FOTO || "",
      }];
    });
    setCupon(null);
    setCartBump(true);
    window.setTimeout(() => setCartBump(false), 650);
    setCartOpen(true);
  };

  const setCant = (id, n) => {
    setCart((prev) => prev.map((x) => x.id === id ? { ...x, cantidad: Math.max(1, n) } : x));
    setCupon(null);
  };
  const quitar = (id) => {
    setCart((prev) => prev.filter((x) => x.id !== id));
    setCupon(null);
  };
  const toggleWish = (id) => {
    setWish((prev) => prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id]);
    setWishBump(true);
    window.setTimeout(() => setWishBump(false), 650);
  };

  const aplicarCupon = async () => {
    setCuponError("");
    setCuponLoading(true);
    try {
      const res = await fetch(`/api/tienda/cupon/?codigo=${encodeURIComponent(cuponCodigo)}&subtotal=${subtotal}`);
      const data = await res.json();
      if (!res.ok || !data.ok) throw new Error(data.error || "Cupón no válido");
      setCupon({ ...data.cupon, descuento: data.descuento });
    } catch (err) {
      setCupon(null);
      setCuponError(err.message);
    } finally {
      setCuponLoading(false);
    }
  };

  const irCheckout = () => {
    setCartOpen(false);
    setPedidoError("");
    setPedidoOk("");
    ir("checkout");
  };

  const enviarPedido = async (e) => {
    e.preventDefault();
    setPedidoError("");
    const nombre = [pedido.nombre, pedido.apellidos].filter(Boolean).join(" ").trim();
    const tipo = checkoutOps.tiposEntrega.find((t) => String(t.value) === String(pedido.idTipoEntrega));
    const requiereDir = Number(tipo?.REQUIEREDIRECCION) === 1;
    const direccion = [pedido.direccion, pedido.distrito].filter(Boolean).join(", ");
    if (!nombre) return setPedidoError("Ingresa tu nombre.");
    if (!pedido.telefono.trim()) return setPedidoError("Ingresa tu teléfono.");
    if (!pedido.email.trim()) return setPedidoError("Ingresa tu correo.");
    if (!pedido.idTipoEntrega) return setPedidoError("Selecciona el tipo de entrega.");
    if (requiereDir && !pedido.direccion.trim()) return setPedidoError("Ingresa la dirección de entrega.");
    if (!pedido.idFormaPago) return setPedidoError("Selecciona un método de pago.");
    if (!pedido.comprobante) return setPedidoError("Adjunta la captura del pago.");
    if (!cart.length) return setPedidoError("Tu carrito está vacío.");
    setPedidoLoading(true);
    try {
      const res = await fetch("/api/tienda/pedido/", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          NOMBRE: nombre,
          TELEFONO: pedido.telefono.trim(),
          EMAIL: pedido.email.trim(),
          DIRECCION: direccion,
          IDFORMAPAGO: pedido.idFormaPago,
          IDTIPOENTREGA: pedido.idTipoEntrega,
          COMPROBANTEPAGO: pedido.comprobante,
          OBSERVACIONES: pedido.notas.trim(),
          CUPON: cupon?.CODIGO || "",
          DETALLE: cart.map((i) => ({ IDPRODUCTO: i.id, CANTIDAD: i.cantidad, PRECIOUNITARIO: i.precio })),
        }),
      });
      const data = await res.json();
      if (!res.ok || !data.ok) throw new Error(data.error || data.mensaje || "No se pudo registrar el pedido");
      setPedidoOk(data.idventa || data.mensaje);
      setCart([]);
      setCupon(null);
      setCuponCodigo("");
    } catch (err) {
      setPedidoError(err.message);
    } finally {
      setPedidoLoading(false);
    }
  };

  const abrirCarrito = () => {
    setCartOpen(false);
    ir("carrito");
  };

  return (
    <div className="shop-root">
      <header className={`shop-header${headerHidden ? " is-hidden" : ""}`}>
        <div className="shop-header-inner">
          <button
            type="button"
            className="shop-burger"
            aria-label={menuOpen ? "Cerrar menú" : "Abrir menú"}
            aria-expanded={menuOpen}
            onClick={() => { setCartOpen(false); setMenuOpen((v) => !v); }}
          >
            <FontAwesomeIcon icon={menuOpen ? faXmark : faBars} />
          </button>
          <button type="button" className="shop-logo" onClick={() => ir("inicio")}>
            <img src={logoImg} alt="DecoCake Shop" />
            <span>
              <strong>DecoCake Shop</strong>
              <em>Insumos de repostería</em>
            </span>
          </button>
          <nav className="shop-nav">
            {[
              ["inicio", "Inicio"],
              ["productos", "Productos"],
              ["nosotros", "Nosotros"],
              ["contacto", "Contacto"],
            ].map(([id, label]) => (
              <button key={id} type="button" className={seccion === id ? "on" : ""} onClick={() => ir(id)}>
                {label}
              </button>
            ))}
          </nav>
          <div className="shop-utils">
            <button type="button" className={`shop-icon shop-icon--wish ${wishBump ? "is-bump" : ""}`} title="Favoritos" aria-label="Favoritos" onClick={() => ir("favoritos")}>
              <FontAwesomeIcon icon={faHeart} />
              <span>{wish.length}</span>
            </button>
            <button type="button" className={`shop-icon shop-icon--cart ${cartBump ? "is-bump" : ""}`} onClick={() => { cerrarMenu(); setCartOpen(true); }} aria-label="Carrito">
              <FontAwesomeIcon icon={faBagShopping} />
              <span>{itemsCount}</span>
              <small>{money(subtotal)}</small>
            </button>
          </div>
        </div>
      </header>

      {menuOpen && <div className="shop-drawer-overlay" onClick={cerrarMenu} />}
      <aside className={`shop-drawer ${menuOpen ? "open" : ""}`} aria-hidden={!menuOpen}>
        <form className="shop-drawer-search" onSubmit={buscarDesdeMenu}>
          <input
            value={menuBuscar}
            onChange={(e) => setMenuBuscar(e.target.value)}
            placeholder="Buscar productos"
            aria-label="Buscar productos"
          />
          <button type="submit" aria-label="Buscar"><FontAwesomeIcon icon={faSearch} /></button>
        </form>
        <div className="shop-drawer-tabs">
          <button type="button" className={menuTab === "menu" ? "on" : ""} onClick={() => setMenuTab("menu")}>Menú</button>
          <button type="button" className={menuTab === "cats" ? "on" : ""} onClick={() => setMenuTab("cats")}>Categorías</button>
        </div>
        {menuTab === "menu" ? (
          <nav className="shop-drawer-list">
            <button type="button" className={seccion === "inicio" ? "on" : ""} onClick={() => ir("inicio")}>Inicio</button>
            <button type="button" className={seccion === "nosotros" ? "on" : ""} onClick={() => ir("nosotros")}>Nosotros</button>
            <button type="button" className={seccion === "productos" ? "on" : ""} onClick={() => ir("productos")}>Productos</button>
            <button type="button" className={seccion === "contacto" ? "on" : ""} onClick={() => ir("contacto")}>Contacto</button>
            <button type="button" className={seccion === "favoritos" ? "on" : ""} onClick={() => ir("favoritos")}>
              <FontAwesomeIcon icon={faHeart} /> Favoritos
            </button>
            <a href="/sistema">
              <FontAwesomeIcon icon={faUser} /> Iniciar sesión
            </a>
          </nav>
        ) : (
          <nav className="shop-drawer-list">
            <button type="button" className={!categoria ? "on" : ""} onClick={() => ir("productos", "")}>Todas</button>
            {categorias.map((c) => (
              <button
                key={c.value}
                type="button"
                className={String(categoria) === String(c.value) ? "on" : ""}
                onClick={() => ir("productos", c.value)}
              >
                {c.label}
              </button>
            ))}
          </nav>
        )}
      </aside>

      <div className="shop-main">
        {seccion === "inicio" && (
          <>
            <section className="shop-slider" aria-label="Promociones">
              <div className="shop-slider-viewport">
                <div className="shop-slider-track" style={{ transform: `translateX(-${slide * 100}%)` }}>
                  {slides.map((item, i) => (
                    <figure key={`${item.alt}-${i}`} className="shop-slider-slide">
                      <img src={item.src} alt={item.alt} />
                    </figure>
                  ))}
                </div>
              </div>
              {slides.length > 1 && (
                <>
                  <button type="button" className="shop-slider-arrow prev" aria-label="Anterior" onClick={() => setSlide((n) => (n - 1 + slides.length) % slides.length)}>‹</button>
                  <button type="button" className="shop-slider-arrow next" aria-label="Siguiente" onClick={() => setSlide((n) => (n + 1) % slides.length)}>›</button>
                  <div className="shop-slider-dots">
                    {slides.map((item, i) => (
                      <button key={`${item.alt}-dot-${i}`} type="button" className={slide === i ? "on" : ""} aria-label={`Ir a imagen ${i + 1}`} onClick={() => setSlide(i)} />
                    ))}
                  </div>
                </>
              )}
            </section>

            <section className="shop-promos">
              <p className="shop-kicker">Temporada dulce</p>
              <h2>Promociones</h2>
              <div className="shop-promo-grid">
                {promos.map((promo) => (
                  <article
                    key={promo.titulo}
                    className={`shop-promo-card${promo.estilo === "teal" ? " shop-promo-card--teal" : ""}`}
                    onClick={() => ir("productos", promo.enlace || "")}
                  >
                    <img src={promo.src} alt={promo.titulo} />
                    <div className="shop-promo-copy">
                      {promo.kicker ? <span>{promo.kicker}</span> : null}
                      <h3>{promo.titulo}</h3>
                      {promo.texto ? <p>{promo.texto}</p> : null}
                      {promo.precio != null && promo.precio !== "" ? (
                        <strong>{promo.precioTexto ? `${promo.precioTexto} ` : ""}{money(promo.precio)}</strong>
                      ) : promo.precioTexto ? <strong>{promo.precioTexto}</strong> : null}
                    </div>
                  </article>
                ))}
              </div>
            </section>

            <section className="shop-block">
              <p className="shop-kicker">Explora</p>
              <h2>¿Qué estás buscando hoy?</h2>
              <div className="shop-cat-tiles">
                <button type="button" className="shop-cat-tile" onClick={() => ir("productos", "")}>Todos</button>
                {categorias.map((c) => (
                  <button key={c.value} type="button" className="shop-cat-tile" onClick={() => ir("productos", c.value)}>
                    {c.label}
                  </button>
                ))}
              </div>
            </section>

            <section className="shop-block">
              <h2>Destacados</h2>
              <div className="shop-grid">
                {destacados.map((p, i) => (
                  <ProductCard key={p.IDPRODUCTO} p={p} hot={i < 2} wished={wish.includes(p.IDPRODUCTO)} onAdd={addCart} onWish={toggleWish} />
                ))}
              </div>
            </section>
          </>
        )}

        {seccion === "productos" && (
          <section className="shop-catalog">
            <aside className="shop-cats">
              <h3>Categorías</h3>
              <button type="button" className={!categoria ? "on" : ""} onClick={() => filtrarCategoria("")}>Todos</button>
              {categorias.map((c) => (
                <button key={c.value} type="button" className={String(categoria) === String(c.value) ? "on" : ""} onClick={() => filtrarCategoria(c.value)}>
                  {c.label}
                </button>
              ))}
            </aside>
            <div className="shop-catalog-main">
              <div className="shop-search">
                <CategorySelect categorias={categorias} value={categoria} onChange={filtrarCategoria} />
                <input value={buscar} onChange={(e) => setBuscar(e.target.value)} placeholder="Buscar productos..." />
                <span><FontAwesomeIcon icon={faSearch} /></span>
              </div>
              <h2>{categoria ? categorias.find((c) => String(c.value) === String(categoria))?.label : "Nuestros productos"}</h2>
              <div className="shop-grid">
                {productos.map((p, i) => (
                  <ProductCard key={p.IDPRODUCTO} p={p} hot={pagina === 1 && i < 2} wished={wish.includes(p.IDPRODUCTO)} onAdd={addCart} onWish={toggleWish} />
                ))}
              </div>
              {!productos.length && <p className="shop-empty">No hay productos en esta búsqueda.</p>}
              <ShopPager
                pagina={pagina}
                total={totalProductos}
                tamanio={PAGE_SIZE}
                onChange={(p) => { setPagina(p); window.scrollTo({ top: 0, behavior: "smooth" }); }}
              />
            </div>
          </section>
        )}

        {seccion === "nosotros" && (
          <section className="shop-about">
            <p className="shop-kicker">Conócenos</p>
            <h2>¿Quiénes somos?</h2>
            <p>En DecoCake Shop somos una tienda especializada en productos, herramientas y accesorios para la repostería creativa y la decoración de postres.</p>
            <p>Nacimos para acompañar a reposteros, emprendedores y amantes de la pastelería con productos prácticos, novedosos y accesibles que conviertan cada idea en una creación especial.</p>
            <p>Contamos con moldes, cortadores, acetatos, toppers, esténciles, sellos, utensilios y accesorios para distintas temporadas y celebraciones.</p>
            <p>Creemos que detrás de cada torta, postre o emprendimiento hay una historia, dedicación y creatividad. Por eso te brindamos variedad, buena atención y productos que impulsen tu pasión o negocio.</p>
            <div className="shop-mv">
              <article>
                <span>01</span>
                <h3>Misión</h3>
                <p>Ofrecer productos, herramientas y accesorios que permitan crear, decorar y emprender con mayor facilidad, brindando variedad, calidad, precios accesibles y una atención cercana.</p>
              </article>
              <article>
                <span>02</span>
                <h3>Visión</h3>
                <p>Ser una marca referente en repostería creativa, reconocida por sus productos innovadores, variados y accesibles, y convertirnos en la primera opción de reposteros y emprendedores del país.</p>
              </article>
            </div>
          </section>
        )}

        {seccion === "contacto" && (
          <section className="shop-page">
            <p className="shop-kicker">Hablemos</p>
            <h2>Contacto</h2>
            <ul className="shop-contact-list">
              <li><FontAwesomeIcon icon={faPhone} /> 940 247 576</li>
              <li><a href={`https://wa.me/${WHATSAPP}`} target="_blank" rel="noreferrer"><WhatsAppIcon /> WhatsApp pedidos</a></li>
              <li><FontAwesomeIcon icon={faClock} /> Lunes a sábado 9:00 a.m. a 6:00 p.m.</li>
              <li><FontAwesomeIcon icon={faLocationDot} /> Lima, Perú</li>
            </ul>
            <div className="shop-social shop-social--page">
              <a href={SOCIAL.instagram} target="_blank" rel="noreferrer">Instagram</a>
              <a href={SOCIAL.facebook} target="_blank" rel="noreferrer">Facebook</a>
              <a href={SOCIAL.tiktok} target="_blank" rel="noreferrer">TikTok</a>
            </div>
          </section>
        )}

        {seccion === "favoritos" && (
          <section className="shop-page">
            <h2>Favoritos</h2>
            <div className="shop-grid">
              {favoritosItems.map((p) => (
                <ProductCard key={p.IDPRODUCTO} p={p} wished onAdd={addCart} onWish={toggleWish} />
              ))}
            </div>
            {!favoritosItems.length && <p className="shop-empty">Aún no guardas productos.</p>}
          </section>
        )}

        {seccion === "carrito" && (
          <section className="shop-cart-page">
            <h2>Tu carrito</h2>
            {!cart.length && (
              <div className="shop-empty-box">
                <p>Tu carrito está vacío.</p>
                <button type="button" className="shop-btn" onClick={() => ir("productos")}>Ver productos</button>
              </div>
            )}
            {!!cart.length && (
              <div className="shop-cart-layout">
                <div className="shop-cart-list">
                  {cart.map((i) => (
                    <article key={i.id} className="shop-cart-row">
                      {i.foto ? <img src={i.foto} alt="" /> : <div className="shop-ph">{i.nombre.slice(0, 1)}</div>}
                      <div className="shop-cart-info">
                        <div className="shop-cart-head">
                          <strong>{i.nombre}</strong>
                          <button type="button" className="shop-remove" onClick={() => quitar(i.id)} aria-label="Quitar">
                            <FontAwesomeIcon icon={faXmark} />
                          </button>
                        </div>
                        <div className="shop-cart-meta">
                          <p>
                            <span>Precio</span>
                            <em>{money(i.precio)}</em>
                          </p>
                          <p>
                            <span>Cantidad</span>
                            <span className="shop-qty">
                              <button type="button" onClick={() => setCant(i.id, i.cantidad - 1)}><FontAwesomeIcon icon={faMinus} /></button>
                              <b>{i.cantidad}</b>
                              <button type="button" onClick={() => setCant(i.id, i.cantidad + 1)}><FontAwesomeIcon icon={faPlus} /></button>
                            </span>
                          </p>
                          <p className="shop-cart-sub">
                            <span>Subtotal</span>
                            <em>{money(i.precio * i.cantidad)}</em>
                          </p>
                        </div>
                      </div>
                    </article>
                  ))}
                </div>
                <aside className="shop-cart-aside">
                  <div className="shop-cupon-box">
                    <input
                      value={cuponCodigo}
                      onChange={(e) => setCuponCodigo(e.target.value.toUpperCase())}
                      placeholder="CODIGO DE PROMOCIÓN"
                      aria-label="Código de promoción"
                    />
                    <button type="button" className="shop-btn shop-btn--full" disabled={cuponLoading} onClick={aplicarCupon}>
                      Aplicar cupón
                    </button>
                    {cuponError && <p className="shop-cupon-msg err">{cuponError}</p>}
                    {cupon && <p className="shop-cupon-msg ok">{cupon.CODIGO} aplicado</p>}
                  </div>
                  <div className="shop-cart-totals">
                    <h3>Totales del carrito</h3>
                    <div className="shop-totals-row">
                      <span>Subtotal</span>
                      <strong>{money(subtotal)}</strong>
                    </div>
                    {descuento > 0 && (
                      <div className="shop-totals-row">
                        <span>Descuento</span>
                        <strong>- {money(descuento)}</strong>
                      </div>
                    )}
                    <div className="shop-totals-row shop-totals-row--envio">
                      <span>Envío</span>
                      <p>Se coordina al finalizar la compra por WhatsApp.</p>
                    </div>
                    <div className="shop-totals-row shop-totals-row--total">
                      <span>Total</span>
                      <strong>{money(total)}</strong>
                    </div>
                    <button type="button" className="shop-btn shop-btn--full" onClick={irCheckout}>Finalizar compra</button>
                  </div>
                  <button type="button" className="shop-btn shop-btn--ghost shop-btn--full" onClick={() => ir("productos")}>Seguir comprando</button>
                </aside>
              </div>
            )}
          </section>
        )}

        {seccion === "checkout" && (
          <CheckoutPage
            cart={cart}
            cupon={cupon}
            descuento={descuento}
            total={total}
            ops={checkoutOps}
            pedido={pedido}
            setPedido={setPedido}
            error={pedidoError}
            ok={pedidoOk}
            loading={pedidoLoading}
            onSubmit={enviarPedido}
            onBack={() => ir("carrito")}
            onShop={() => ir("productos")}
          />
        )}
      </div>

      <footer className="shop-footer">
        <div className="shop-footer-inner">
          <div className="shop-footer-brand">
            <img src={logoImg} alt="DecoCake Shop" />
            <strong>DecoCake Shop</strong>
            <em>Crea con amor</em>
            <p>Insumos, moldes y accesorios para repostería creativa.</p>
          </div>
          <div>
            <h4>Contacto</h4>
            <a href="tel:+51940247576">940 247 576</a>
            <a href={`https://wa.me/${WHATSAPP}`} target="_blank" rel="noreferrer">WhatsApp pedidos</a>
            <p>Lima, Perú</p>
          </div>
          <div>
            <h4>Atención</h4>
            <p>Lunes a sábado</p>
            <p>9:00 a.m. — 6:00 p.m.</p>
            <button type="button" className="shop-footer-link" onClick={() => ir("nosotros")}>Conócenos</button>
          </div>
          <div>
            <h4>Síguenos</h4>
            <div className="shop-soc">
              <a href={SOCIAL.instagram} target="_blank" rel="noreferrer" aria-label="Instagram" className="ig">
                <InstagramIcon />
              </a>
              <a href={SOCIAL.facebook} target="_blank" rel="noreferrer" aria-label="Facebook" className="fb">
                <FacebookIcon />
              </a>
              <a href={SOCIAL.tiktok} target="_blank" rel="noreferrer" aria-label="TikTok" className="tt">
                <TikTokIcon />
              </a>
            </div>
          </div>
        </div>
        <div className="shop-footer-bar">
          <span>© {new Date().getFullYear()} DecoCake Shop. Hecho para crear con amor.</span>
          <a className="shop-staff" href="/sistema">Personal</a>
        </div>
      </footer>

      <a
        className="shop-wa"
        href={`https://wa.me/${WHATSAPP}?text=${encodeURIComponent("Hola, quiero que un asesor me ayude a armar mi pedido de DecoCake Shop.")}`}
        target="_blank"
        rel="noreferrer"
      >
        <span className="shop-wa-icon" aria-hidden="true"><WhatsAppIcon /></span>
        <span className="shop-wa-msg">
          <strong>¿Necesitas ayuda?</strong>
          <em>Un asesor te arma el pedido</em>
        </span>
      </a>
      {topVisible && (
        <button type="button" className="shop-top" onClick={() => window.scrollTo({ top: 0, behavior: "smooth" })} aria-label="Subir">
          <FontAwesomeIcon icon={faArrowUp} />
        </button>
      )}

      {cartOpen && <div className="shop-overlay" onClick={() => setCartOpen(false)} />}
      <aside className={`shop-cart ${cartOpen ? "open" : ""}`}>
        <header>
          <h3>Carrito</h3>
          <button type="button" onClick={() => setCartOpen(false)} aria-label="Cerrar"><FontAwesomeIcon icon={faXmark} /></button>
        </header>
        <div className="shop-cart-body">
          {cart.length === 0 && <p className="shop-empty">Tu carrito está vacío.</p>}
          {cart.map((i) => (
            <div key={i.id} className="shop-cart-item">
              <div>
                <strong>{i.nombre}</strong>
                <p>{money(i.precio)}</p>
              </div>
              <div className="shop-qty">
                <button type="button" onClick={() => setCant(i.id, i.cantidad - 1)}><FontAwesomeIcon icon={faMinus} /></button>
                <span>{i.cantidad}</span>
                <button type="button" onClick={() => setCant(i.id, i.cantidad + 1)}><FontAwesomeIcon icon={faPlus} /></button>
              </div>
              <button type="button" className="shop-remove" onClick={() => quitar(i.id)}>×</button>
            </div>
          ))}
        </div>
        <footer>
          <p>Subtotal <strong>{money(subtotal)}</strong></p>
          <button type="button" className="shop-btn shop-btn--full" disabled={!cart.length} onClick={abrirCarrito}>Ver carrito</button>
          <button type="button" className="shop-btn shop-btn--full" disabled={!cart.length} onClick={irCheckout}>Finalizar compra</button>
        </footer>
      </aside>
    </div>
  );
}

function InstagramIcon() {
  return (
    <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="1.8" aria-hidden="true">
      <rect x="3.5" y="3.5" width="17" height="17" rx="5" />
      <circle cx="12" cy="12" r="4" />
      <circle cx="17.4" cy="6.6" r="0.9" fill="currentColor" stroke="none" />
    </svg>
  );
}

function FacebookIcon() {
  return (
    <svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor" aria-hidden="true">
      <path d="M14.5 9H17V6h-2.5C12.01 6 11 7.2 11 9.2V11H9v3h2v7h3v-7h2.3L17 11h-3V9.4c0-.3.2-.4.5-.4Z" />
    </svg>
  );
}

function TikTokIcon() {
  return (
    <svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor" aria-hidden="true">
      <path d="M14.2 4c.4 2.3 1.8 3.9 4 4.2v2.6c-1.3 0-2.5-.4-3.6-1.1v5.8c0 3.3-2.5 5.7-5.8 5.5-3.2-.2-5.4-3-5-6.2.3-2.6 2.5-4.6 5.2-4.7.3 0 .6 0 .9.1v2.8c-.3-.1-.6-.2-.9-.1-1.4.1-2.4 1.4-2.2 2.8.2 1.3 1.4 2.2 2.7 2.1 1.4 0 2.5-1.1 2.5-2.5V4h2.2Z" />
    </svg>
  );
}

function CategorySelect({ categorias, value, onChange }) {
  const [open, setOpen] = useState(false);
  const box = useRef(null);
  const actual = categorias.find((c) => String(c.value) === String(value))?.label || "Todas las categorías";
  const opciones = [{ value: "", label: "Todas las categorías" }, ...categorias];

  useEffect(() => {
    const cerrar = (e) => {
      if (!box.current?.contains(e.target)) setOpen(false);
    };
    document.addEventListener("mousedown", cerrar);
    return () => document.removeEventListener("mousedown", cerrar);
  }, []);

  return (
    <div className={`shop-dd ${open ? "open" : ""}`} ref={box}>
      <button type="button" className="shop-dd-btn" aria-expanded={open} aria-haspopup="listbox" onClick={() => setOpen((v) => !v)}>
        {actual}
      </button>
      {open && (
        <ul className="shop-dd-list" role="listbox">
          {opciones.map((op) => (
            <li key={op.value || "todas"}>
              <button
                type="button"
                role="option"
                aria-selected={String(value) === String(op.value)}
                className={String(value) === String(op.value) ? "on" : ""}
                onClick={() => { onChange(op.value); setOpen(false); }}
              >
                {op.label}
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

function CheckoutPage({ cart, cupon, descuento, total, ops, pedido, setPedido, error, ok, loading, onSubmit, onBack, onShop }) {
  const setCampo = (campo) => (e) => setPedido((p) => ({ ...p, [campo]: e.target.value }));
  const tipo = ops.tiposEntrega.find((t) => String(t.value) === String(pedido.idTipoEntrega));
  const requiereDir = Number(tipo?.REQUIEREDIRECCION) === 1;

  const onFoto = async (file) => {
    if (!file || !file.type.startsWith("image/")) return;
    try {
      const data = await fileToBase64Resized(file, 720, 0.68);
      setPedido((p) => ({ ...p, comprobante: data }));
    } catch {
      setPedido((p) => ({ ...p, comprobante: "" }));
    }
  };

  if (ok) {
    return (
      <section className="shop-checkout">
        <div className="shop-checkout-ok">
          <h2>Pedido recibido</h2>
          <p>Tu pedido <strong>{ok}</strong> ya está en el módulo de Pedidos. Te contactaremos para coordinar la entrega.</p>
          <button type="button" className="shop-btn" onClick={onShop}>Seguir comprando</button>
        </div>
      </section>
    );
  }

  if (!cart.length) {
    return (
      <section className="shop-checkout">
        <div className="shop-empty-box">
          <p>Tu carrito está vacío.</p>
          <button type="button" className="shop-btn" onClick={onShop}>Ver productos</button>
        </div>
      </section>
    );
  }

  return (
    <section className="shop-checkout">
      <h2>Detalles de facturación</h2>
      <form className="shop-checkout-grid" onSubmit={onSubmit}>
        <div className="shop-checkout-form">
          <label>
            <span>Nombre <i>*</i></span>
            <input value={pedido.nombre} onChange={setCampo("nombre")} required />
          </label>
          <label>
            <span>Apellidos <i>*</i></span>
            <input value={pedido.apellidos} onChange={setCampo("apellidos")} required />
          </label>
          <label>
            <span>Teléfono <i>*</i></span>
            <input value={pedido.telefono} onChange={setCampo("telefono")} inputMode="tel" required />
          </label>
          <label>
            <span>Correo electrónico <i>*</i></span>
            <input type="email" value={pedido.email} onChange={setCampo("email")} required />
          </label>
          <label>
            <span>Entrega <i>*</i></span>
            <select value={pedido.idTipoEntrega} onChange={setCampo("idTipoEntrega")} required>
              <option value="">Elige una opción...</option>
              {ops.tiposEntrega.map((t) => (
                <option key={t.value} value={t.value}>{t.label}</option>
              ))}
            </select>
          </label>
          {requiereDir && (
            <>
              <label>
                <span>Dirección <i>*</i></span>
                <input value={pedido.direccion} onChange={setCampo("direccion")} placeholder="Calle y número" required />
              </label>
              <label>
                <span>Distrito</span>
                <input value={pedido.distrito} onChange={setCampo("distrito")} placeholder="Ej. Surco" />
              </label>
            </>
          )}
          <fieldset className="shop-pay">
            <legend>Método de pago <i>*</i></legend>
            {ops.formasPago.map((f) => (
              <label key={f.value} className={pedido.idFormaPago === f.value ? "on" : ""}>
                <input
                  type="radio"
                  name="pago"
                  value={f.value}
                  checked={pedido.idFormaPago === f.value}
                  onChange={setCampo("idFormaPago")}
                />
                {f.label}
              </label>
            ))}
          </fieldset>
          <div className="shop-upload">
            <span>Captura del pago <i>*</i></span>
            <label className={pedido.comprobante ? "has-file" : ""}>
              {pedido.comprobante ? (
                <img src={pedido.comprobante} alt="Captura del pago" />
              ) : (
                <>
                  <FontAwesomeIcon icon={faCloudArrowUp} />
                  <em>Sube la captura de Yape, Plin o transferencia</em>
                </>
              )}
              <input
                type="file"
                accept="image/jpeg,image/png,image/webp"
                onChange={(e) => { onFoto(e.target.files?.[0]); e.target.value = ""; }}
              />
            </label>
            {pedido.comprobante && (
              <button type="button" className="shop-remove" onClick={() => setPedido((p) => ({ ...p, comprobante: "" }))}>
                Quitar captura
              </button>
            )}
          </div>
          <label>
            <span>Notas (opcional)</span>
            <textarea value={pedido.notas} onChange={setCampo("notas")} rows={3} />
          </label>
        </div>
        <aside className="shop-order-box">
          <h3>Tu pedido</h3>
          <div className="shop-order-head"><span>Producto</span><span>Subtotal</span></div>
          {cart.map((i) => (
            <p key={i.id}>
              <span>{i.nombre} × {i.cantidad}</span>
              <strong>{money(i.precio * i.cantidad)}</strong>
            </p>
          ))}
          {descuento > 0 && (
            <p><span>Descuento{cupon?.CODIGO ? ` (${cupon.CODIGO})` : ""}</span><strong>- {money(descuento)}</strong></p>
          )}
          <p className="shop-order-total"><span>Total</span><strong>{money(total)}</strong></p>
          {error && <p className="shop-cupon-msg err">{error}</p>}
          <button type="submit" className="shop-btn shop-btn--full" disabled={loading}>
            {loading ? "Enviando..." : "Confirmar pedido"}
          </button>
          <button type="button" className="shop-btn shop-btn--ghost shop-btn--full" onClick={onBack}>Volver al carrito</button>
        </aside>
      </form>
    </section>
  );
}

function ShopPager({ pagina, total, tamanio, onChange }) {
  const totalPaginas = Math.max(1, Math.ceil(Number(total || 0) / tamanio));
  if (total <= tamanio) return null;
  const pages = [];
  for (let i = 1; i <= totalPaginas; i += 1) {
    if (i === 1 || i === totalPaginas || Math.abs(i - pagina) <= 1) pages.push(i);
    else if (pages[pages.length - 1] !== "…") pages.push("…");
  }
  return (
    <nav className="shop-pager" aria-label="Paginación de productos">
      <button type="button" disabled={pagina <= 1} onClick={() => onChange(pagina - 1)}>Anterior</button>
      {pages.map((p, idx) =>
        p === "…" ? <span key={`e-${idx}`}>…</span> : (
          <button key={p} type="button" className={p === pagina ? "on" : ""} onClick={() => onChange(p)}>{p}</button>
        ),
      )}
      <button type="button" disabled={pagina >= totalPaginas} onClick={() => onChange(pagina + 1)}>Siguiente</button>
    </nav>
  );
}

function WhatsAppIcon() {
  return (
    <svg viewBox="0 0 24 24" width="1em" height="1em" fill="currentColor" aria-hidden="true">
      <path d="M12 2C6.5 2 2 6.3 2 11.7c0 2 .6 3.9 1.7 5.5L2 22l5-1.6c1.5.8 3.2 1.3 5 1.3 5.5 0 10-4.3 10-9.7S17.5 2 12 2zm0 17.6c-1.6 0-3.1-.4-4.4-1.2l-.3-.2-3 .8.8-2.9-.2-.3C4.2 14.6 3.7 13.2 3.7 11.7 3.7 7.3 7.4 3.7 12 3.7s8.3 3.6 8.3 8c0 4.4-3.7 7.9-8.3 7.9zm4.6-5.9c-.3-.1-1.5-.7-1.7-.8-.2-.1-.4-.1-.6.1-.2.3-.7.8-.8 1-.1.2-.3.2-.6.1-.3-.1-1.1-.4-2.1-1.3-.8-.7-1.3-1.6-1.5-1.9-.1-.2 0-.4.1-.5l.4-.5c.1-.1.2-.3.2-.4 0-.1 0-.3-.1-.4-.1-.1-.6-1.4-.8-1.9-.2-.5-.4-.4-.6-.4h-.5c-.2 0-.4.1-.7.3-.2.3-.9.8-.9 2s.9 2.3 1 2.5c.1.2 1.8 2.8 4.4 3.9 2.6 1.1 2.6.7 3.1.7.5 0 1.5-.6 1.7-1.2.2-.6.2-1.1.1-1.2-.1-.1-.3-.2-.5-.3z" />
    </svg>
  );
}

function ProductArt({ categoria, nombre }) {
  const kind = String(categoria || "");
  return (
    <div className={`shop-ph shop-ph--${kind || "def"}`} aria-hidden="true">
      <span>{nombre?.slice(0, 1) || "D"}</span>
    </div>
  );
}

function ProductCard({ p, hot, wished, onAdd, onWish }) {
  return (
    <article className="shop-card">
      <div className="shop-card-media">
        {hot && <span className="shop-hot">HOT</span>}
        <button type="button" className={`shop-wish ${wished ? "on" : ""}`} aria-label="Favorito" onClick={() => onWish(p.IDPRODUCTO)}>
          <FontAwesomeIcon icon={faHeart} />
        </button>
        {p.FOTO
          ? <img src={p.FOTO} alt={p.NOMBRE} />
          : <ProductArt categoria={p.IDCATEGORIA} nombre={p.NOMBRE} />}
        <button type="button" className="shop-add" onClick={() => onAdd(p)}>Añadir al carrito</button>
      </div>
      <h3>{p.NOMBRE}</h3>
      <p className="shop-price">{money(p.PRECIO)}</p>
    </article>
  );
}

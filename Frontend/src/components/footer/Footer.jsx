const Footer = () => {
  const currentYear = new Date().getFullYear();
  return (
    <footer className="app-footer">
      <span>DecoCake Shop © {currentYear} — Importadora.</span>
    </footer>
  );
};

export default Footer;

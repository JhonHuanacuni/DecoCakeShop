import { useRef, useLayoutEffect, useEffect, useState } from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";

const SidebarSection = ({ icon, label, children, isOpen, onToggle, collapsed }) => {
  const buttonRef = useRef(null);
  const [popoverPos, setPopoverPos] = useState({ top: 0, left: 0 });

  useLayoutEffect(() => {
    if (!collapsed || !isOpen) return;
    const update = () => {
      if (buttonRef.current) {
        const rect = buttonRef.current.getBoundingClientRect();
        setPopoverPos({ top: rect.top, left: rect.right + 8 });
      }
    };
    update();
    window.addEventListener("resize", update);
    return () => window.removeEventListener("resize", update);
  }, [collapsed, isOpen]);

  return (
    <div className="sidebar-section" style={{ position: "relative" }}>
      <button
        type="button"
        ref={buttonRef}
        className={`sidebar-section-toggle ${isOpen ? "open" : ""}`}
        onClick={onToggle}
        aria-expanded={isOpen}
      >
        <span className="sidebar-section-icon"><FontAwesomeIcon icon={icon} /></span>
        <span className={`sidebar-section-label ${collapsed ? "collapsed" : ""}`}>{label}</span>
        <span className="sidebar-section-arrow">›</span>
      </button>
      {collapsed && isOpen && (
        <div className="sidebar-popover" style={{ top: popoverPos.top, left: popoverPos.left }}>
          <div className="sidebar-popover-inner">{children}</div>
        </div>
      )}
      {!collapsed && (
        <div className={`sidebar-section-body ${isOpen ? "open" : "closed"}`}>{children}</div>
      )}
    </div>
  );
};

export default SidebarSection;

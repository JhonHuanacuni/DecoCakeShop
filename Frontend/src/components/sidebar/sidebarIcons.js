import {
  faGauge, faUsers, faBox, faFileInvoice, faCashRegister,
  faTags, faCog, faClipboardList, faLayerGroup, faIdCard,
  faMoneyBill, faTruck, faCircle, faReceipt, faTicket,
} from "@fortawesome/free-solid-svg-icons";

const ICON_MAP = {
  faGauge, faUsers, faBox, faFileInvoice, faCashRegister,
  faTags, faCog, faClipboardList, faLayerGroup, faIdCard,
  faMoneyBill, faTruck, faCircle, faReceipt, faTicket,
};

export function resolveSidebarIcon(iconName) {
  if (!iconName) return faCircle;
  const key = iconName.startsWith("fa") ? iconName : `fa${iconName}`;
  return ICON_MAP[key] || faCircle;
}

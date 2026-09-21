import type { ReactNode } from "react";
import "@/modules/client/ui/client-experience.css";
import "@/modules/admin/ui/admin-experience.css";
import "@/modules/shared/shell/admin-experience.css";

export default function AdministrationLayout({ children }: { children: ReactNode }) {
  return children;
}

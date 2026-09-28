import { canApplyFranchiseSpaceDemo } from "@/modules/franchise/data/spaces/demo";
import type { FranchiseLibraryWorkspace } from "@/modules/franchise/data/library/workspace-model";
import type { Locale } from "@/modules/shared/lib/i18n/locale";

export function overlayFranchiseLibraryDemo(workspace: FranchiseLibraryWorkspace, locale: Locale, query = ""): FranchiseLibraryWorkspace {
  if (!canApplyFranchiseSpaceDemo()) return workspace;
  // Never invent catalogue rows for an empty mandated library — only real scoped data may appear.
  void locale;
  void query;
  return workspace;
}

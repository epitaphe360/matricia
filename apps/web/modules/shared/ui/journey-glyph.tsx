import { BarChart3, ClipboardList, FilePlus2, Flag, Handshake, Search, ShieldCheck, Target } from "lucide-react";

const glyphs = [FilePlus2, Search, BarChart3, ClipboardList, Target, ShieldCheck, Handshake, Flag];

export function JourneyGlyph({ index }: { index: number }) {
  const Icon = glyphs[index % glyphs.length] ?? FilePlus2;
  return <Icon className="size-3.5" strokeWidth={2.1} aria-hidden />;
}

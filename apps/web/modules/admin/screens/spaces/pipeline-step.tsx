import { JourneyGlyph } from "@/modules/shared/ui/journey-glyph";
import type { SpaceTone } from "@/modules/admin/data/spaces/screen-catalog";

export function PipelineGlyph({ index, tone }: { index: number; tone: SpaceTone }) {
  return (
    <i data-tone={tone} aria-hidden>
      <JourneyGlyph index={index} />
    </i>
  );
}

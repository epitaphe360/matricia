import { describe, expect, it, vi } from "vitest";

const complete = vi.fn();
const transition = vi.fn();
vi.mock("../../../../lib/diagnostics-opportunities/server-repository", () => ({ createServerDiagnosticsRepository: async () => ({ complete, transition }) }));
vi.mock("../../../../lib/supabase/server", () => ({ getSupabaseServerClient: vi.fn() }));
vi.mock("next/cache", () => ({ revalidatePath: vi.fn() }));
import { completeAction, opportunityAction } from "./actions";

function form(value: Record<string, string>) { const data = new FormData(); Object.entries(value).forEach(([key, item]) => data.set(key, item)); return data; }
const base = { locale: "fr", idempotencyKey: "00000000-0000-4000-8000-000000000001" };

describe("diagnostic actions", () => {
  it("rejects malformed completion before RPC", async () => {
    expect(await completeAction({ status: "idle" }, form({ ...base, sessionId: "bad", serviceId: "bad" }))).toEqual({ status: "error", reason: "VALIDATION" });
    expect(complete).not.toHaveBeenCalled();
  });
  it("requires a date to defer", async () => {
    expect(await opportunityAction({ status: "idle" }, form({ ...base, runId: "00000000-0000-4000-8000-000000000002", opportunityId: "00000000-0000-4000-8000-000000000003", action: "DEFER", deferredUntil: "", rowVersion: "1" }))).toEqual({ status: "error", reason: "VALIDATION" });
    expect(transition).not.toHaveBeenCalled();
  });
});

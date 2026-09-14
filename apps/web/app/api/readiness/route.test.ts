import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({ rpc: vi.fn() }));
vi.mock("@/lib/supabase/admin", () => ({
  getSupabaseAdminClient: () => ({ rpc: mocks.rpc }),
}));

import { GET } from "./route";

describe("GET /api/readiness", () => {
  beforeEach(() => mocks.rpc.mockReset());

  it("retourne 200 quand la base répond", async () => {
    mocks.rpc.mockResolvedValue({ data: [{ database_ok: true, outbox_ok: true }], error: null });
    const response = await GET();
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({ status: "ready", service: "matricia-web" });
  });

  it("retourne 503 sans exposer le détail interne", async () => {
    mocks.rpc.mockResolvedValue({ data: null, error: { message: "credential detail" } });
    const response = await GET();
    expect(response.status).toBe(503);
    const body = await response.json();
    expect(body.checks.database).toMatchObject({ status: "down", code: "DATABASE_UNAVAILABLE" });
    expect(body.checks.outbox).toMatchObject({ status: "down", code: "OUTBOX_STATUS_UNAVAILABLE" });
    expect(JSON.stringify(body)).not.toContain("credential detail");
  });

  it("distingue une base disponible d'un backlog Outbox", async () => {
    mocks.rpc.mockResolvedValue({ data: [{ database_ok: true, outbox_ok: false }], error: null });
    const response = await GET();
    expect(response.status).toBe(503);
    expect(await response.json()).toMatchObject({
      checks: {
        database: { status: "up" },
        outbox: { status: "down", code: "OUTBOX_BACKLOG" },
      },
    });
  });
});

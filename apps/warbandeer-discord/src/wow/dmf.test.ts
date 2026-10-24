import { describe, expect, test } from "bun:test";

// dmf.ts imports the `config` singleton (env resolved at import time); pin the realm timezone.
process.env.DISCORD_TOKEN ??= "test-token";
process.env.ANNOUNCE_CHANNEL_ID ??= "100";
process.env.WOW_REGION = "us";
process.env.DMF_TIMEZONE = "America/Los_Angeles";
const { dmfWindow, currentOrNextDmf } = await import("./dmf");

describe("dmfWindow", () => {
  test("opens 00:01 realm time on the first Sunday (PDT, UTC-7)", () => {
    // First Sunday of Oct 2026 is the 4th.
    const w = dmfWindow(2026, 9);
    expect(w.start.toISOString()).toBe("2026-10-04T07:01:00.000Z");
    expect(w.end.toISOString()).toBe("2026-10-11T07:01:00.000Z");
  });

  test("uses the winter offset in PST (UTC-8)", () => {
    // First Sunday of Dec 2026 is the 6th.
    expect(dmfWindow(2026, 11).start.toISOString()).toBe("2026-12-06T08:01:00.000Z");
  });

  test("a month starting on a Sunday opens on the 1st", () => {
    // 2026-02-01 is a Sunday.
    expect(dmfWindow(2026, 1).start.toISOString()).toBe("2026-02-01T08:01:00.000Z");
  });
});

describe("currentOrNextDmf", () => {
  test("before the month's fair: inactive, this month's window", () => {
    const r = currentOrNextDmf(new Date("2026-10-02T00:00:00Z"));
    expect(r.active).toBe(false);
    expect(r.window.start.toISOString()).toBe("2026-10-04T07:01:00.000Z");
  });

  test("inside the week: active", () => {
    expect(currentOrNextDmf(new Date("2026-10-06T00:00:00Z")).active).toBe(true);
  });

  test("after the week: inactive, next month's window", () => {
    const r = currentOrNextDmf(new Date("2026-10-20T00:00:00Z"));
    expect(r.active).toBe(false);
    expect(r.window.start.toISOString()).toBe("2026-11-01T07:01:00.000Z");
  });
});

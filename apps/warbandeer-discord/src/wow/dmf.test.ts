import { describe, expect, test } from "bun:test";

process.env.DISCORD_TOKEN ??= "test-token";
process.env.ANNOUNCE_CHANNEL_ID ??= "100";
const { currentOrNextDmf, dmfKey, dmfWindow } = await import("./dmf");

const PARIS = "Europe/Paris";
const LA = "America/Los_Angeles";

describe("dmf east of UTC (Europe/Paris)", () => {
  test("October and November 2026 keys differ", () => {
    const oct = dmfWindow(2026, 9, PARIS);
    const nov = dmfWindow(2026, 10, PARIS);
    // Nov 1 2026 00:01 CET is Oct 31 23:01 UTC.
    expect(nov.start.toISOString()).toBe("2026-10-31T23:01:00.000Z");
    expect(dmfKey(oct)).toBe("2026-10");
    expect(dmfKey(nov)).toBe("2026-11");
  });

  test("at Oct 31 23:30 UTC the November faire is active, not 'opened an hour ago'", () => {
    const { active, window } = currentOrNextDmf(new Date("2026-10-31T23:30:00Z"), PARIS);
    expect(active).toBe(true);
    expect(dmfKey(window)).toBe("2026-11");
  });

  test("just before it opens, November is next and not active", () => {
    const { active, window } = currentOrNextDmf(new Date("2026-10-31T23:00:00Z"), PARIS);
    expect(active).toBe(false);
    expect(dmfKey(window)).toBe("2026-11");
  });

  test("after October's faire ends, the next faire is November", () => {
    const { active, window } = currentOrNextDmf(new Date("2026-10-20T12:00:00Z"), PARIS);
    expect(active).toBe(false);
    expect(dmfKey(window)).toBe("2026-11");
  });

  test("December rolls into January of the next year", () => {
    const { window } = currentOrNextDmf(new Date("2026-12-20T12:00:00Z"), PARIS);
    expect(dmfKey(window)).toBe("2027-1");
  });
});

describe("dmf west of UTC (America/Los_Angeles)", () => {
  test("unchanged: Oct 4 2026 00:01 PDT, key 2026-10", () => {
    const { active, window } = currentOrNextDmf(new Date("2026-10-05T12:00:00Z"), LA);
    expect(active).toBe(true);
    expect(window.start.toISOString()).toBe("2026-10-04T07:01:00.000Z");
    expect(dmfKey(window)).toBe("2026-10");
  });

  test("local month still October while UTC is already November", () => {
    const { window } = currentOrNextDmf(new Date("2026-11-01T03:00:00Z"), LA);
    expect(dmfKey(window)).toBe("2026-11"); // Oct faire ended; next is November
  });
});

describe("dmfWindow (America/Los_Angeles)", () => {
  test("opens 00:01 realm time on the first Sunday (PDT, UTC-7)", () => {
    // First Sunday of Oct 2026 is the 4th.
    const w = dmfWindow(2026, 9, LA);
    expect(w.start.toISOString()).toBe("2026-10-04T07:01:00.000Z");
    expect(w.end.toISOString()).toBe("2026-10-11T07:01:00.000Z");
  });

  test("uses the winter offset in PST (UTC-8)", () => {
    // First Sunday of Dec 2026 is the 6th.
    expect(dmfWindow(2026, 11, LA).start.toISOString()).toBe("2026-12-06T08:01:00.000Z");
  });

  test("a month starting on a Sunday opens on the 1st", () => {
    // 2026-02-01 is a Sunday.
    expect(dmfWindow(2026, 1, LA).start.toISOString()).toBe("2026-02-01T08:01:00.000Z");
  });
});

describe("currentOrNextDmf (America/Los_Angeles)", () => {
  test("before the month's fair: inactive, this month's window", () => {
    const r = currentOrNextDmf(new Date("2026-10-02T00:00:00Z"), LA);
    expect(r.active).toBe(false);
    expect(r.window.start.toISOString()).toBe("2026-10-04T07:01:00.000Z");
  });

  test("inside the week: active", () => {
    expect(currentOrNextDmf(new Date("2026-10-06T00:00:00Z"), LA).active).toBe(true);
  });

  test("after the week: inactive, next month's window", () => {
    const r = currentOrNextDmf(new Date("2026-10-20T00:00:00Z"), LA);
    expect(r.active).toBe(false);
    expect(r.window.start.toISOString()).toBe("2026-11-01T07:01:00.000Z");
  });
});

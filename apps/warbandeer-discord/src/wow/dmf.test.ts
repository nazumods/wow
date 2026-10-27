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

import { describe, expect, test } from "bun:test";

// reset.ts imports the `config` singleton (env resolved at import time); the region defaults to us.
process.env.DISCORD_TOKEN ??= "test-token";
process.env.ANNOUNCE_CHANNEL_ID ??= "100";
process.env.WOW_REGION = "us";
const { nextDailyReset, nextWeeklyReset, lastWeeklyReset } = await import("./reset");

// US: daily 15:00 UTC, weekly Tuesday 15:00 UTC. 2026-10-27 is a Tuesday.
describe("nextDailyReset", () => {
  test("before today's reset returns today", () => {
    expect(nextDailyReset(new Date("2026-10-24T10:00:00Z")).toISOString()).toBe(
      "2026-10-24T15:00:00.000Z",
    );
  });

  test("at or after today's reset rolls to tomorrow", () => {
    expect(nextDailyReset(new Date("2026-10-24T15:00:00Z")).toISOString()).toBe(
      "2026-10-25T15:00:00.000Z",
    );
    expect(nextDailyReset(new Date("2026-10-31T23:59:00Z")).toISOString()).toBe(
      "2026-11-01T15:00:00.000Z",
    );
  });
});

describe("nextWeeklyReset", () => {
  test("mid-week points at the coming Tuesday", () => {
    expect(nextWeeklyReset(new Date("2026-10-24T12:00:00Z")).toISOString()).toBe(
      "2026-10-27T15:00:00.000Z",
    );
  });

  test("on reset day before the hour is today, at or after is next week", () => {
    expect(nextWeeklyReset(new Date("2026-10-27T14:59:00Z")).toISOString()).toBe(
      "2026-10-27T15:00:00.000Z",
    );
    expect(nextWeeklyReset(new Date("2026-10-27T15:00:00Z")).toISOString()).toBe(
      "2026-11-03T15:00:00.000Z",
    );
  });
});

describe("lastWeeklyReset", () => {
  test("is exactly a week before the next one", () => {
    expect(lastWeeklyReset(new Date("2026-10-24T12:00:00Z")).toISOString()).toBe(
      "2026-10-20T15:00:00.000Z",
    );
  });
});

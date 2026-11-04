import { describe, expect, test } from "bun:test";

// realm.ts imports the `config` singleton (env resolved at import time), so prime the
// required vars before pulling it in.
process.env.DISCORD_TOKEN ??= "test-token";
process.env.ANNOUNCE_CHANNEL_ID ??= "100";
const { decideRealmTransition, settleRealmReading } = await import("./realm");

describe("decideRealmTransition", () => {
  test("first observation seeds silently (no announcement)", () => {
    expect(decideRealmTransition(undefined, "UP")).toBeNull();
    expect(decideRealmTransition(undefined, "DOWN")).toBeNull();
  });

  test("no announcement while status is unchanged", () => {
    expect(decideRealmTransition("UP", "UP")).toBeNull();
    expect(decideRealmTransition("DOWN", "DOWN")).toBeNull();
  });

  test("announces down when the realm goes UP → DOWN", () => {
    expect(decideRealmTransition("UP", "DOWN")).toBe("down");
  });

  test("announces up when the realm recovers DOWN → UP", () => {
    expect(decideRealmTransition("DOWN", "UP")).toBe("up");
  });
});

describe("settleRealmReading", () => {
  test("a single DOWN does not flip a confirmed UP", () => {
    expect(settleRealmReading("UP", "DOWN", 0)).toEqual({ status: "UP", downStreak: 1 });
  });

  test("the second consecutive DOWN is believed", () => {
    expect(settleRealmReading("UP", "DOWN", 1)).toEqual({ status: "DOWN", downStreak: 2 });
  });

  test("an UP reading resets the streak and is believed at once", () => {
    expect(settleRealmReading("UP", "UP", 1)).toEqual({ status: "UP", downStreak: 0 });
    expect(settleRealmReading("DOWN", "UP", 3)).toEqual({ status: "UP", downStreak: 0 });
  });

  test("the first observation seeds DOWN immediately", () => {
    expect(settleRealmReading(undefined, "DOWN", 0).status).toBe("DOWN");
  });

  test("a blip between DOWNs restarts the count", () => {
    const a = settleRealmReading("UP", "DOWN", 0);
    const b = settleRealmReading(a.status, "UP", a.downStreak);
    expect(settleRealmReading(b.status, "DOWN", b.downStreak).status).toBe("UP");
  });
});

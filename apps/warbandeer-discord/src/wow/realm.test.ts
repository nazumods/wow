import { describe, expect, test } from "bun:test";

// realm.ts imports the `config` singleton (env resolved at import time), so prime the
// required vars before pulling it in.
process.env.DISCORD_TOKEN ??= "test-token";
process.env.ANNOUNCE_CHANNEL_ID ??= "100";
const { decideRealmTransition } = await import("./realm");

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

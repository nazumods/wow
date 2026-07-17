import { describe, expect, test } from "bun:test";

// `commands.ts` pulls in the `config` singleton, which resolves process.env at import
// time — satisfy the required vars before importing so this file runs standalone.
process.env.DISCORD_TOKEN ??= "test-token";
process.env.ANNOUNCE_CHANNEL_ID ??= "100";
const { isAdmin } = await import("./commands");

describe("isAdmin", () => {
  test("accepts a user on the allowlist", () => {
    expect(isAdmin("111", ["111", "222"])).toBe(true);
    expect(isAdmin("222", ["111", "222"])).toBe(true);
  });

  test("rejects a user not on the allowlist", () => {
    expect(isAdmin("333", ["111", "222"])).toBe(false);
  });

  test("fails closed when no admins are configured", () => {
    expect(isAdmin("111", [])).toBe(false);
  });

  test("matches the whole id, not a prefix or substring", () => {
    expect(isAdmin("11", ["111"])).toBe(false);
    expect(isAdmin("1111", ["111"])).toBe(false);
  });
});

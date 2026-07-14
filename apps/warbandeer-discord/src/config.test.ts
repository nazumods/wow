import { describe, expect, test } from "bun:test";

// The `config` singleton resolves process.env at import time, so satisfy the
// required vars before pulling the module in.
process.env.DISCORD_TOKEN ??= "test-token";
process.env.ANNOUNCE_CHANNEL_ID ??= "100";
const { resolveConfig } = await import("./config");

const base = {
  DISCORD_TOKEN: "test-token",
  ANNOUNCE_CHANNEL_ID: "100",
};

describe("resolveConfig", () => {
  test("release channel falls back to ANNOUNCE_CHANNEL_ID when unset", () => {
    const config = resolveConfig(base);
    expect(config.releaseAnnounceChannelId).toBe("100");
  });

  test("release channel falls back when set to the empty string", () => {
    const config = resolveConfig({ ...base, RELEASE_ANNOUNCE_CHANNEL_ID: "" });
    expect(config.releaseAnnounceChannelId).toBe("100");
  });

  test("release channel uses RELEASE_ANNOUNCE_CHANNEL_ID when set", () => {
    const config = resolveConfig({ ...base, RELEASE_ANNOUNCE_CHANNEL_ID: "200" });
    expect(config.releaseAnnounceChannelId).toBe("200");
    expect(config.announceChannelId).toBe("100");
  });

  test("throws on missing required vars", () => {
    expect(() => resolveConfig({ DISCORD_TOKEN: "t" })).toThrow(/ANNOUNCE_CHANNEL_ID/);
    expect(() => resolveConfig({ ANNOUNCE_CHANNEL_ID: "100" })).toThrow(/DISCORD_TOKEN/);
  });

  test("rejects an invalid WOW_REGION", () => {
    expect(() => resolveConfig({ ...base, WOW_REGION: "kr" })).toThrow(/WOW_REGION/);
  });
});

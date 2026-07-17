import { describe, expect, test } from "bun:test";

// The `config` singleton resolves process.env at import time, so satisfy the
// required vars before pulling the module in.
process.env.DISCORD_TOKEN ??= "test-token";
process.env.ANNOUNCE_CHANNEL_ID ??= "100";
const { resolveConfig, repoForProject } = await import("./config");
const { reportBody } = await import("./report");

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

  test("command prefix defaults to empty and passes through when set", () => {
    expect(resolveConfig(base).commandPrefix).toBe("");
    expect(resolveConfig({ ...base, COMMAND_PREFIX: "r_" }).commandPrefix).toBe("r_");
  });

  test("rejects an uppercase / invalid COMMAND_PREFIX", () => {
    expect(() => resolveConfig({ ...base, COMMAND_PREFIX: "R_" })).toThrow(/COMMAND_PREFIX/);
  });

  test("REPORT_ROLE_ID is optional and passes through", () => {
    expect(resolveConfig(base).reportRoleId).toBeUndefined();
    expect(resolveConfig({ ...base, REPORT_ROLE_ID: "42" }).reportRoleId).toBe("42");
  });
});

describe("report helpers", () => {
  test("repoForProject maps known tokens and rejects unknown", () => {
    expect(repoForProject("wow")).toBe("nazumods/wow");
    expect(repoForProject("abm")).toBe("roshne/ActionBarMaster");
    expect(repoForProject("nope")).toBeUndefined();
  });

  test("reportBody keeps the description and names the reporter", () => {
    const b = reportBody("it crashed on login", "alice");
    expect(b).toContain("it crashed on login");
    expect(b).toContain("alice");
  });
});

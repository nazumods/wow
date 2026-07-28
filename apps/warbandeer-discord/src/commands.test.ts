import { describe, expect, test } from "bun:test";

// `commands.ts` pulls in the `config` singleton, which resolves process.env at import
// time — satisfy the required vars before importing so this file runs standalone.
process.env.DISCORD_TOKEN ??= "test-token";
process.env.ANNOUNCE_CHANNEL_ID ??= "100";
const { isAdmin, bareName, updateReply } = await import("./commands");

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

describe("bareName", () => {
  test("strips the configured prefix", () => {
    expect(bareName("r_dmf", "r_")).toBe("dmf");
    expect(bareName("r_status", "r_")).toBe("status");
  });

  test("is a no-op when no prefix is configured", () => {
    expect(bareName("dmf", "")).toBe("dmf");
    expect(bareName("status", "")).toBe("status");
  });

  // The bug this guards: dispatch used to slice(prefix.length) unconditionally, so a command
  // registered without the prefix became "update" -> "date" and matched no case — it showed up
  // in Discord and silently did nothing.
  test("passes an unprefixed name through instead of mangling it", () => {
    expect(bareName("update", "r_")).toBe("update");
    expect(bareName("report", "r_")).toBe("report");
  });

  test("leaves a name that merely shares a leading letter alone", () => {
    expect(bareName("reset", "r_")).toBe("reset");
  });

  test("strips only the first occurrence", () => {
    expect(bareName("r_r_dmf", "r_")).toBe("r_dmf");
  });
});

describe("updateReply", () => {
  const SHA = "b".repeat(40);

  test("names the build it is restarting to pick up", () => {
    expect(updateReply("restart", SHA)).toContain(SHA.slice(0, 7));
  });

  // The bot now answers this itself, with a follow-up naming the build it landed on —
  // handing the verification back to the user was the whole complaint in #681.
  test("no longer asks the user to check whether the build changed", () => {
    const reply = updateReply("restart", SHA);
    expect(reply).not.toContain("same build");
    expect(reply).toContain("report back");
  });

  test("reports disabled and current without promising a follow-up", () => {
    expect(updateReply("disabled", "")).toContain("GIT_SHA");
    expect(updateReply("current", SHA)).toContain("latest build");
  });
});

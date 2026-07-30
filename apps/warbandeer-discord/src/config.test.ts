import { describe, expect, test } from "bun:test";

// The `config` singleton resolves process.env at import time, so satisfy the
// required vars before pulling the module in.
process.env.DISCORD_TOKEN ??= "test-token";
process.env.ANNOUNCE_CHANNEL_ID ??= "100";
const { resolveConfig, repoForProject } = await import("./config");
const { reportBody, reportAnnouncement } = await import("./report");

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

  test("watchedRepos defaults to just the configured GITHUB_REPO", () => {
    expect(resolveConfig(base).watchedRepos).toEqual(["nazumods/wow"]);
    expect(resolveConfig({ ...base, GITHUB_REPO: "acme/thing" }).watchedRepos).toEqual([
      "acme/thing",
    ]);
  });

  test("WATCHED_REPOS parses, trims, and dedupes a comma-separated list", () => {
    expect(
      resolveConfig({
        ...base,
        WATCHED_REPOS: "nazumods/wow, roshne/ActionBarMaster , nazumods/wow",
      }).watchedRepos,
    ).toEqual(["nazumods/wow", "roshne/ActionBarMaster"]);
  });

  test("an empty WATCHED_REPOS falls back to GITHUB_REPO", () => {
    expect(resolveConfig({ ...base, WATCHED_REPOS: "" }).watchedRepos).toEqual(["nazumods/wow"]);
    expect(resolveConfig({ ...base, WATCHED_REPOS: " , " }).watchedRepos).toEqual(["nazumods/wow"]);
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

// #870: the confirmation is posted in the channel now, so it has to carry the report itself
// rather than just a link — and it has to survive a description longer than Discord allows.
describe("reportAnnouncement", () => {
  const base = {
    repo: "nazumods/wow",
    number: 42,
    url: "https://github.com/nazumods/wow/issues/42",
    title: "Login crash",
    description: "it crashed on login",
    username: "alice",
  };

  test("names the reporter, the issue, and carries the report", () => {
    const m = reportAnnouncement(base);
    expect(m).toContain("alice");
    expect(m).toContain("nazumods/wow#42");
    expect(m).toContain(base.url);
    expect(m).toContain("Login crash");
    expect(m).toContain("it crashed on login");
  });

  test("a description that fits is carried whole, with no truncation note", () => {
    expect(reportAnnouncement(base)).not.toContain("truncated");
  });

  test("clamps to Discord's 2000-char limit and says it truncated", () => {
    const m = reportAnnouncement({ ...base, description: "x".repeat(5000) });
    expect(m.length).toBeLessThanOrEqual(2000);
    expect(m).toContain("truncated");
    // The head survives: a truncated report is still traceable to its issue.
    expect(m).toContain("nazumods/wow#42");
    expect(m).toContain(base.url);
  });

  // The boundary the clamp is actually built around — one char past what fits must still fit.
  test("stays within the limit right at the boundary", () => {
    const head = reportAnnouncement({ ...base, description: "" }).length;
    for (const len of [2000 - head - 1, 2000 - head, 2000 - head + 1]) {
      const m = reportAnnouncement({ ...base, description: "x".repeat(len) });
      expect(m.length).toBeLessThanOrEqual(2000);
    }
  });
});

describe("resolveConfig — self-update", () => {
  test("self-update is off and unconfigured by default", () => {
    const config = resolveConfig(base);
    expect(config.gitSha).toBeUndefined();
    expect(config.autoUpdate).toBe(false);
    expect(config.adminUserIds).toEqual([]);
  });

  test("BOT_BRANCH defaults to main and overrides when set", () => {
    expect(resolveConfig(base).botBranch).toBe("main");
    expect(resolveConfig({ ...base, BOT_BRANCH: "staging" }).botBranch).toBe("staging");
  });

  test("an empty BOT_BRANCH falls back to main rather than querying no branch", () => {
    expect(resolveConfig({ ...base, BOT_BRANCH: "" }).botBranch).toBe("main");
  });

  test("GIT_SHA resolves, and an empty one disables self-update", () => {
    expect(resolveConfig({ ...base, GIT_SHA: "abc1234" }).gitSha).toBe("abc1234");
    expect(resolveConfig({ ...base, GIT_SHA: "" }).gitSha).toBeUndefined();
  });

  test("AUTO_UPDATE is on only for exactly \"true\"", () => {
    expect(resolveConfig({ ...base, AUTO_UPDATE: "true" }).autoUpdate).toBe(true);
    expect(resolveConfig({ ...base, AUTO_UPDATE: "false" }).autoUpdate).toBe(false);
    expect(resolveConfig({ ...base, AUTO_UPDATE: "1" }).autoUpdate).toBe(false);
    expect(resolveConfig({ ...base, AUTO_UPDATE: "" }).autoUpdate).toBe(false);
  });

  test("ADMIN_USER_IDS splits on commas", () => {
    expect(resolveConfig({ ...base, ADMIN_USER_IDS: "111,222" }).adminUserIds).toEqual([
      "111",
      "222",
    ]);
  });

  test("ADMIN_USER_IDS tolerates whitespace and stray commas", () => {
    expect(resolveConfig({ ...base, ADMIN_USER_IDS: " 111 , ,222, " }).adminUserIds).toEqual([
      "111",
      "222",
    ]);
  });

  test("ADMIN_USER_IDS dedupes", () => {
    expect(resolveConfig({ ...base, ADMIN_USER_IDS: "111,111,222" }).adminUserIds).toEqual([
      "111",
      "222",
    ]);
  });

  test("ADMIN_USER_IDS empty yields nobody", () => {
    expect(resolveConfig({ ...base, ADMIN_USER_IDS: "" }).adminUserIds).toEqual([]);
    expect(resolveConfig({ ...base, ADMIN_USER_IDS: " , " }).adminUserIds).toEqual([]);
  });
});

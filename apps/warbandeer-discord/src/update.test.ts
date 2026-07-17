import { describe, expect, test } from "bun:test";

// `update.ts` pulls in the `config` singleton, which resolves process.env at import
// time — satisfy the required vars before importing so this file runs standalone.
process.env.DISCORD_TOKEN ??= "test-token";
process.env.ANNOUNCE_CHANNEL_ID ??= "100";
const { decideUpdate, sameSha } = await import("./update");

const OLD = "a".repeat(40);
const NEW = "b".repeat(40);

describe("sameSha", () => {
  test("matches identical shas", () => {
    expect(sameSha(NEW, NEW)).toBe(true);
  });

  test("matches a short sha against the full one", () => {
    expect(sameSha("abc1234", "abc1234def5678")).toBe(true);
    expect(sameSha("abc1234def5678", "abc1234")).toBe(true);
  });

  test("is case-insensitive", () => {
    expect(sameSha("ABC1234", "abc1234")).toBe(true);
  });

  test("rejects differing shas", () => {
    expect(sameSha(OLD, NEW)).toBe(false);
    expect(sameSha("abc1234", "abc9999")).toBe(false);
  });

  test("an empty sha never matches", () => {
    expect(sameSha("", NEW)).toBe(false);
  });
});

describe("decideUpdate", () => {
  test("disabled without a baked-in GIT_SHA", () => {
    expect(decideUpdate({ latestSha: NEW })).toBe("disabled");
    expect(decideUpdate({ runningSha: "", latestSha: NEW })).toBe("disabled");
  });

  test("current when running the newest bot commit", () => {
    expect(decideUpdate({ runningSha: NEW, latestSha: NEW })).toBe("current");
  });

  test("current when a short GIT_SHA prefixes the newest commit", () => {
    expect(decideUpdate({ runningSha: NEW.slice(0, 7), latestSha: NEW })).toBe("current");
  });

  test("restart when stale", () => {
    expect(decideUpdate({ runningSha: OLD, latestSha: NEW })).toBe("restart");
  });

  test("suppressed when we already exited for this sha and came back unchanged", () => {
    expect(decideUpdate({ runningSha: OLD, latestSha: NEW, attemptedSha: NEW })).toBe("suppressed");
  });

  test("restart when the attempt marker is for an older sha than the one now pending", () => {
    const NEWER = "c".repeat(40);
    expect(decideUpdate({ runningSha: OLD, latestSha: NEWER, attemptedSha: NEW })).toBe("restart");
  });

  test("force overrides suppression", () => {
    expect(
      decideUpdate({ runningSha: OLD, latestSha: NEW, attemptedSha: NEW, force: true }),
    ).toBe("restart");
  });

  test("force still reports current rather than restarting a fresh build", () => {
    expect(decideUpdate({ runningSha: NEW, latestSha: NEW, force: true })).toBe("current");
  });

  test("force cannot enable updates without a GIT_SHA", () => {
    expect(decideUpdate({ latestSha: NEW, force: true })).toBe("disabled");
  });
});

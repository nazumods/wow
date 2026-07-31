import { afterEach, describe, expect, test } from "bun:test";

// `update.ts` pulls in the `config` singleton, which resolves process.env at import
// time — satisfy the required vars before importing so this file runs standalone.
process.env.DISCORD_TOKEN ??= "test-token";
process.env.ANNOUNCE_CHANNEL_ID ??= "100";
const { checkForUpdate, decideUpdate, sameSha, buildUpdateReport, fetchShaRelation } =
  await import("./update");
const { beginHandoff, endHandoff } = await import("./restart");

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

// #871: staleness is an ancestry question, not an equality one. GIT_SHA is the tip the image was
// built from, which on most days is a main commit NEWER than the last bot-touching commit.
describe("decideUpdate ancestry", () => {
  // The regression that motivated the issue: a correct, current deploy built from a main tip that
  // already contains the newest bot commit. Under sha equality this was "restart" every time.
  test("ahead is current — a build newer than the last bot commit is not stale", () => {
    expect(decideUpdate({ runningSha: OLD, latestSha: NEW, relation: "ahead" })).toBe("current");
  });

  test("identical is current", () => {
    expect(decideUpdate({ runningSha: OLD, latestSha: NEW, relation: "identical" })).toBe("current");
  });

  test("behind still restarts — genuinely missing bot code", () => {
    expect(decideUpdate({ runningSha: OLD, latestSha: NEW, relation: "behind" })).toBe("restart");
  });

  // Answers the same question as `behind` with the same no: this build doesn't contain it.
  test("diverged restarts", () => {
    expect(decideUpdate({ runningSha: OLD, latestSha: NEW, relation: "diverged" })).toBe("restart");
  });

  // A sha the remote has never seen can never be matched, so an update would be undeliverable.
  test("unpublished disables rather than offering an update it can never deliver", () => {
    expect(decideUpdate({ runningSha: OLD, latestSha: NEW, relation: "unpublished" })).toBe(
      "disabled",
    );
  });

  test("unpublished outranks the anti-loop suppression", () => {
    expect(
      decideUpdate({ runningSha: OLD, latestSha: NEW, relation: "unpublished", attemptedSha: NEW }),
    ).toBe("disabled");
  });

  test("force cannot turn an unpublished sha into a restart", () => {
    expect(
      decideUpdate({ runningSha: OLD, latestSha: NEW, relation: "unpublished", force: true }),
    ).toBe("disabled");
  });

  // An API failure must not invent a verdict — it degrades to the pre-#871 behaviour.
  test("unknown falls back to treating a sha mismatch as stale", () => {
    expect(decideUpdate({ runningSha: OLD, latestSha: NEW, relation: "unknown" })).toBe("restart");
    expect(
      decideUpdate({ runningSha: OLD, latestSha: NEW, relation: "unknown", attemptedSha: NEW }),
    ).toBe("suppressed");
  });

  // The shortcut is what keeps the common path at one request: matching shas never consult it.
  test("the equality shortcut wins before any relation is read", () => {
    expect(decideUpdate({ runningSha: NEW, latestSha: NEW, relation: "behind" })).toBe("current");
    expect(decideUpdate({ runningSha: NEW.slice(0, 7), latestSha: NEW, relation: "unpublished" })).toBe(
      "current",
    );
  });

  // Missing GIT_SHA is decided before ancestry is even relevant.
  test("no running sha is disabled whatever the relation says", () => {
    expect(decideUpdate({ latestSha: NEW, relation: "ahead" })).toBe("disabled");
  });
});

describe("fetchShaRelation", () => {
  const realFetch = globalThis.fetch;
  const stub = (impl: () => Promise<Response> | Response) => {
    globalThis.fetch = impl as unknown as typeof fetch;
  };
  afterEach(() => {
    globalThis.fetch = realFetch;
  });

  const ok = (status: string) =>
    new Response(JSON.stringify({ status }), { status: 200, headers: { "Content-Type": "application/json" } });

  for (const status of ["identical", "ahead", "behind", "diverged"] as const) {
    test(`passes through ${status}`, async () => {
      stub(() => ok(status));
      expect(await fetchShaRelation(NEW, OLD)).toBe(status);
    });
  }

  test("404 means the running sha isn't on the remote", async () => {
    stub(() => new Response("", { status: 404 }));
    expect(await fetchShaRelation(NEW, OLD)).toBe("unpublished");
  });

  test("a server error is unknown, not a throw", async () => {
    stub(() => new Response("", { status: 500 }));
    expect(await fetchShaRelation(NEW, OLD)).toBe("unknown");
  });

  // Startup awaits this, so a network failure escaping here would take the bot down with it.
  test("a network failure is unknown, not a throw", async () => {
    stub(() => Promise.reject(new Error("ECONNREFUSED")));
    expect(await fetchShaRelation(NEW, OLD)).toBe("unknown");
  });

  test("an unrecognised status is unknown", async () => {
    stub(() => ok("sideways"));
    expect(await fetchShaRelation(NEW, OLD)).toBe("unknown");
  });

  // Base is the newest bot commit, head is us — so `ahead` reads as "we contain it".
  test("compares latest...running, in that order", async () => {
    let seen = "";
    stub((...args: unknown[]) => {
      seen = String((args as [string])[0]);
      return ok("ahead");
    });
    await fetchShaRelation(NEW, OLD);
    expect(seen).toContain(`/compare/${NEW}...${OLD}`);
  });
});

describe("checkForUpdate during a handoff", () => {
  const realFetch = globalThis.fetch;
  afterEach(() => {
    globalThis.fetch = realFetch;
    endHandoff();
  });

  // The guard must come before everything — a second /update mid-swap would overwrite the
  // in-flight attempt's pendingUpdateReport and then force-remove its replacement. Proven by
  // making the network unreachable: `busy` coming back means no sha was ever fetched.
  test("refuses with busy before touching the network", async () => {
    globalThis.fetch = (() => {
      throw new Error("checkForUpdate reached the network while a handoff was active");
    }) as unknown as typeof fetch;
    beginHandoff("test swap in flight");
    expect((await checkForUpdate({ force: true })).decision).toBe("busy");
  });
});

describe("buildUpdateReport", () => {
  const NOW = 1_700_000_000_000;

  test("records who asked, where to reach them, and both shas", () => {
    expect(
      buildUpdateReport({
        runningSha: OLD,
        latestSha: NEW,
        requester: {
          userId: "42",
          channelId: "100",
          applicationId: "999",
          interactionToken: "tok",
        },
        now: NOW,
      }),
    ).toEqual({
      fromSha: OLD,
      toSha: NEW,
      userId: "42",
      channelId: "100",
      applicationId: "999",
      interactionToken: "tok",
      requestedAt: NOW,
    });
  });

  // An AUTO_UPDATE exit or a host reboot has no requester, so it leaves nothing to follow up on.
  test("no requester means no report, so an unattended restart stays silent", () => {
    expect(buildUpdateReport({ runningSha: OLD, latestSha: NEW, now: NOW })).toBeUndefined();
  });
});

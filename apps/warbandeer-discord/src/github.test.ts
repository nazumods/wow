import { afterEach, describe, expect, test } from "bun:test";

// github.ts imports the `config` singleton (resolved from process.env at import time), so
// prime the required vars before pulling the module in — see config.test.ts.
process.env.DISCORD_TOKEN ??= "test-token";
process.env.ANNOUNCE_CHANNEL_ID ??= "100";
const { decideReleaseAnnouncements, fetchReleases, createReachabilityLog } = await import("./github");

const rel = (id: number) => ({ id, name: `v${id}`, tag: `v${id}`, url: `https://x/${id}` });

describe("decideReleaseAnnouncements", () => {
  test("a never-polled repo (undefined) seeds silently — announces nothing, remembers all", () => {
    const { toAnnounce, nextSeen } = decideReleaseAnnouncements([rel(3), rel(2), rel(1)], undefined);
    expect(toAnnounce).toEqual([]);
    expect(nextSeen).toEqual([3, 2, 1]);
  });

  test("announces only unseen releases, oldest-first, and appends them to seen", () => {
    // GitHub returns newest-first: 4 and 3 are new, 2/1 already seen.
    const { toAnnounce, nextSeen } = decideReleaseAnnouncements(
      [rel(4), rel(3), rel(2), rel(1)],
      [1, 2],
    );
    expect(toAnnounce.map((r) => r.id)).toEqual([3, 4]); // oldest-first
    expect(nextSeen).toEqual([1, 2, 3, 4]);
  });

  test("nothing new leaves seen unchanged", () => {
    const { toAnnounce, nextSeen } = decideReleaseAnnouncements([rel(2), rel(1)], [1, 2]);
    expect(toAnnounce).toEqual([]);
    expect(nextSeen).toEqual([1, 2]);
  });

  test("a repo seeded with zero releases still announces its genuine first release later", () => {
    // Seeded empty (repo had no releases at first poll) → seen is [] (defined, not undefined).
    const { toAnnounce, nextSeen } = decideReleaseAnnouncements([rel(1)], []);
    expect(toAnnounce.map((r) => r.id)).toEqual([1]);
    expect(nextSeen).toEqual([1]);
  });
});

describe("fetchReleases", () => {
  const realFetch = globalThis.fetch;
  const stub = (impl: () => Promise<Response> | Response) => {
    globalThis.fetch = impl as unknown as typeof fetch;
  };
  afterEach(() => {
    globalThis.fetch = realFetch;
  });

  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

  const apiRelease = (id: number, over: Record<string, unknown> = {}) => ({
    id,
    name: `v${id}`,
    tag_name: `v${id}`,
    html_url: `https://x/${id}`,
    draft: false,
    prerelease: false,
    ...over,
  });

  test("maps the API payload and drops drafts", async () => {
    stub(() => json([apiRelease(2), apiRelease(1, { draft: true })]));
    expect(await fetchReleases("owner/repo")).toEqual([
      { id: 2, name: "v2", tag: "v2", url: "https://x/2" },
    ]);
  });

  test("an unnamed release falls back to its tag", async () => {
    stub(() => json([apiRelease(1, { name: null })]));
    expect((await fetchReleases("owner/repo"))?.[0]?.name).toBe("v1");
  });

  // The whole point of the null: a repo the token can't see must not throw once a minute.
  test("404 is null — the repo is missing or invisible to the token", async () => {
    stub(() => new Response("", { status: 404 }));
    expect(await fetchReleases("roshne/artifact-console")).toBeNull();
  });

  // A repo with no releases is a 200 with [], never a 404 — so it stays distinguishable
  // from an unreachable one, and still seeds a (defined, empty) seen-id list.
  test("a releaseless repo is an empty list, not null", async () => {
    stub(() => json([]));
    expect(await fetchReleases("owner/repo")).toEqual([]);
  });

  // Everything that isn't a standing 404 stays loud: these are outages worth seeing.
  for (const status of [401, 403, 429, 500, 502]) {
    test(`${status} still throws`, async () => {
      stub(() => new Response("", { status }));
      await expect(fetchReleases("owner/repo")).rejects.toThrow(
        `GitHub releases query failed for owner/repo: ${status}`,
      );
    });
  }
});

describe("createReachabilityLog", () => {
  test("a repo that fails forever reports once, not once per poll", () => {
    const log = createReachabilityLog();
    expect(log.observe("a/b", false)).toBe("lost");
    expect(log.observe("a/b", false)).toBeNull();
    expect(log.observe("a/b", false)).toBeNull();
  });

  test("a healthy repo is silent from the start", () => {
    const log = createReachabilityLog();
    expect(log.observe("a/b", true)).toBeNull();
    expect(log.observe("a/b", true)).toBeNull();
  });

  test("coming back reports once, and can be lost again afterwards", () => {
    const log = createReachabilityLog();
    log.observe("a/b", false);
    expect(log.observe("a/b", true)).toBe("recovered");
    expect(log.observe("a/b", true)).toBeNull();
    expect(log.observe("a/b", false)).toBe("lost");
  });

  test("repos are tracked independently, so one bad repo can't mute another", () => {
    const log = createReachabilityLog();
    expect(log.observe("a/b", false)).toBe("lost");
    expect(log.observe("c/d", false)).toBe("lost");
    expect(log.observe("a/b", true)).toBe("recovered");
    expect(log.observe("c/d", false)).toBeNull();
  });
});

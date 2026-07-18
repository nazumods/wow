import { describe, expect, test } from "bun:test";

// github.ts imports the `config` singleton (resolved from process.env at import time), so
// prime the required vars before pulling the module in — see config.test.ts.
process.env.DISCORD_TOKEN ??= "test-token";
process.env.ANNOUNCE_CHANNEL_ID ??= "100";
const { decideReleaseAnnouncements } = await import("./github");

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

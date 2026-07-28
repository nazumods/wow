import { describe, expect, test } from "bun:test";

// `updateReport.ts` reaches the `config` singleton, which resolves process.env at import
// time — satisfy the required vars before importing so this file runs standalone.
process.env.DISCORD_TOKEN ??= "test-token";
process.env.ANNOUNCE_CHANNEL_ID ??= "100";
const {
  decideUpdateOutcome,
  updateOutcomeMessage,
  tokenUsable,
  reportTooOld,
  deliverUpdateReport,
} = await import("./updateReport");
type PendingUpdateReport = import("./state").PendingUpdateReport;
type Deliverers = import("./updateReport").Deliverers;

const FROM = "a".repeat(40);
const TO = "b".repeat(40);
const THIRD = "c".repeat(40);
const NOW = 1_700_000_000_000;

const report = (over: Partial<PendingUpdateReport> = {}): PendingUpdateReport => ({
  fromSha: FROM,
  toSha: TO,
  userId: "42",
  channelId: "100",
  applicationId: "999",
  interactionToken: "tok",
  requestedAt: NOW,
  ...over,
});

describe("decideUpdateOutcome", () => {
  test("updated when back on the sha we exited for", () => {
    expect(decideUpdateOutcome({ report: report(), runningSha: TO })).toBe("updated");
  });

  // The whole point of the issue: this case otherwise looks identical to success.
  test("noop when back on the sha we left on", () => {
    expect(decideUpdateOutcome({ report: report(), runningSha: FROM })).toBe("noop");
  });

  test("unexpected when back on some third sha", () => {
    expect(decideUpdateOutcome({ report: report(), runningSha: THIRD })).toBe("unexpected");
  });

  test("unknown when the rebuild dropped GIT_SHA", () => {
    expect(decideUpdateOutcome({ report: report() })).toBe("unknown");
    expect(decideUpdateOutcome({ report: report(), runningSha: "" })).toBe("unknown");
  });

  test("tolerates a short GIT_SHA against the full recorded sha", () => {
    expect(decideUpdateOutcome({ report: report(), runningSha: TO.slice(0, 7) })).toBe("updated");
    expect(decideUpdateOutcome({ report: report(), runningSha: FROM.slice(0, 7) })).toBe("noop");
  });

  test("a report whose from and to are the same reads as updated, not noop", () => {
    expect(decideUpdateOutcome({ report: report({ toSha: FROM }), runningSha: FROM })).toBe(
      "updated",
    );
  });
});

describe("updateOutcomeMessage", () => {
  test("each outcome produces distinct text", () => {
    const msgs = (["updated", "noop", "unexpected", "unknown"] as const).map((o) =>
      updateOutcomeMessage(o, report(), TO),
    );
    expect(new Set(msgs).size).toBe(4);
  });

  test("updated names the build it came back on and the one it left", () => {
    const msg = updateOutcomeMessage("updated", report(), TO);
    expect(msg).toContain(TO.slice(0, 7));
    expect(msg).toContain(FROM.slice(0, 7));
  });

  test("noop says plainly that the image wasn't rebuilt", () => {
    const msg = updateOutcomeMessage("noop", report(), FROM);
    expect(msg).toContain("same build");
    expect(msg).toContain("wasn't rebuilt");
    expect(msg).toContain(TO.slice(0, 7));
  });

  test("unexpected names all three shas", () => {
    const msg = updateOutcomeMessage("unexpected", report(), THIRD);
    for (const sha of [THIRD, FROM, TO]) expect(msg).toContain(sha.slice(0, 7));
  });

  test("unknown reports the missing GIT_SHA rather than guessing", () => {
    const msg = updateOutcomeMessage("unknown", report(), undefined);
    expect(msg).toContain("GIT_SHA");
    expect(msg).not.toContain(FROM.slice(0, 7));
  });
});

describe("tokenUsable", () => {
  test("usable immediately after the restart was requested", () => {
    expect(tokenUsable(report(), NOW + 5_000)).toBe(true);
  });

  test("usable just inside the 15-minute window", () => {
    expect(tokenUsable(report(), NOW + 15 * 60 * 1000 - 1)).toBe(true);
  });

  test("expired at and beyond the window", () => {
    expect(tokenUsable(report(), NOW + 15 * 60 * 1000)).toBe(false);
    expect(tokenUsable(report(), NOW + 60 * 60 * 1000)).toBe(false);
  });

  test("unusable without a token or an application id", () => {
    expect(tokenUsable(report({ interactionToken: undefined }), NOW)).toBe(false);
    expect(tokenUsable(report({ applicationId: undefined }), NOW)).toBe(false);
  });
});

describe("reportTooOld", () => {
  test("a restart from minutes ago is still worth reporting", () => {
    expect(reportTooOld(report(), NOW + 60 * 60 * 1000)).toBe(false);
  });

  test("a box that was down for days does not get greeted with stale news", () => {
    expect(reportTooOld(report(), NOW + 25 * 60 * 60 * 1000)).toBe(true);
  });
});

describe("deliverUpdateReport", () => {
  const spies = (fail: Partial<Record<keyof Deliverers, boolean>> = {}) => {
    const calls: string[] = [];
    const route = (name: keyof Deliverers) => async () => {
      calls.push(name);
      if (fail[name]) throw new Error(`${name} unavailable`);
    };
    const deliverers: Deliverers = {
      viaToken: route("viaToken"),
      viaDm: route("viaDm"),
      viaChannel: route("viaChannel"),
    };
    return { calls, deliverers };
  };

  test("prefers the interaction follow-up and stops there", async () => {
    const { calls, deliverers } = spies();
    expect(await deliverUpdateReport(report(), "hi", deliverers, NOW)).toBe("token");
    expect(calls).toEqual(["viaToken"]);
  });

  test("falls back to a DM when the token has expired", async () => {
    const { calls, deliverers } = spies();
    const later = NOW + 60 * 60 * 1000;
    expect(await deliverUpdateReport(report(), "hi", deliverers, later)).toBe("dm");
    expect(calls).toEqual(["viaDm"]);
  });

  test("falls back to a DM when the follow-up throws", async () => {
    const { calls, deliverers } = spies({ viaToken: true });
    expect(await deliverUpdateReport(report(), "hi", deliverers, NOW)).toBe("dm");
    expect(calls).toEqual(["viaToken", "viaDm"]);
  });

  test("falls back to the channel when DMs are closed", async () => {
    const { calls, deliverers } = spies({ viaToken: true, viaDm: true });
    expect(await deliverUpdateReport(report(), "hi", deliverers, NOW)).toBe("channel");
    expect(calls).toEqual(["viaToken", "viaDm", "viaChannel"]);
  });

  // An unreachable requester must degrade quietly, never blow up the boot path.
  test("resolves to none rather than throwing when every route fails", async () => {
    const { deliverers } = spies({ viaToken: true, viaDm: true, viaChannel: true });
    expect(await deliverUpdateReport(report(), "hi", deliverers, NOW)).toBe("none");
  });

  test("skips the channel route when no channel was recorded", async () => {
    const { calls, deliverers } = spies({ viaToken: true, viaDm: true });
    const r = report({ channelId: undefined });
    expect(await deliverUpdateReport(r, "hi", deliverers, NOW)).toBe("none");
    expect(calls).toEqual(["viaToken", "viaDm"]);
  });
});

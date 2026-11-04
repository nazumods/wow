import { describe, expect, mock, test } from "bun:test";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

// announce.ts pulls in the `config` and `state` singletons at import time — prime env first,
// and point state at a temp dir so saveState never touches the real file.
process.env.DISCORD_TOKEN ??= "test-token";
process.env.ANNOUNCE_CHANNEL_ID ??= "100";
process.env.STATE_DIR = mkdtempSync(join(tmpdir(), "bot-announce-"));
const { announce, announceNewReleases } = await import("./announce");
const { state } = await import("./state");

type Sent = { content: string; allowedMentions?: { parse?: string[] } };

function fakeClient(send: (m: Sent) => Promise<void>) {
  return { channels: { fetch: async () => ({ isSendable: () => true, send }) } } as never;
}

const rel = (id: number) => ({ id, name: `r${id}`, tag: `v${id}`, url: `https://example.test/${id}` });

describe("announce", () => {
  test("sends with every mention type suppressed", async () => {
    const sent: Sent[] = [];
    await announce(fakeClient(async (m) => void sent.push(m)), "release", "@everyone hi");
    expect(sent).toHaveLength(1);
    expect(sent[0]!.content).toBe("@everyone hi");
    expect(sent[0]!.allowedMentions?.parse).toEqual([]);
  });
});

describe("announceNewReleases", () => {
  test("a failure on release 2 keeps release 1 marked seen", async () => {
    state.seenReleaseIds["a/b"] = [0];
    const send = mock(async (m: Sent) => {
      if (m.content.includes("r2")) throw new Error("discord 503");
    });
    // Releases come newest-first; they are announced oldest-first (r1, r2, r3).
    await expect(
      announceNewReleases(fakeClient(send), "a/b", [rel(3), rel(2), rel(1), rel(0)]),
    ).rejects.toThrow("503");
    expect(state.seenReleaseIds["a/b"]).toEqual([0, 1]);

    // Next poll resumes at r2 instead of re-posting r1.
    send.mockClear();
    send.mockImplementation(async () => {});
    await announceNewReleases(fakeClient(send), "a/b", [rel(3), rel(2), rel(1), rel(0)]);
    expect(send.mock.calls.map((c) => c[0].content.match(/r\d/)![0])).toEqual(["r2", "r3"]);
    expect(state.seenReleaseIds["a/b"]).toEqual([0, 1, 2, 3]);
  });

  test("the first poll seeds silently", async () => {
    const send = mock(async () => {});
    await announceNewReleases(fakeClient(send), "new/repo", [rel(2), rel(1)]);
    expect(send).not.toHaveBeenCalled();
    expect(state.seenReleaseIds["new/repo"]).toEqual([2, 1]);
  });
});

import { describe, expect, spyOn, test } from "bun:test";
import { mkdtempSync, readdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";

// state.ts imports the `config` singleton (resolved from process.env at import time), so
// prime the required vars before pulling the module in — see config.test.ts.
process.env.DISCORD_TOKEN ??= "test-token";
process.env.ANNOUNCE_CHANNEL_ID ??= "100";
process.env.STATE_DIR = mkdtempSync(join(tmpdir(), "bot-state-"));
const { normalizeSeenReleaseIds, loadState, saveState, state } = await import("./state");

describe("normalizeSeenReleaseIds", () => {
  test("migrates a legacy global array under the default repo", () => {
    expect(normalizeSeenReleaseIds([1, 2, 3], "nazumods/wow")).toEqual({
      "nazumods/wow": [1, 2, 3],
    });
  });

  test("an empty legacy array yields an empty map (nothing to file)", () => {
    expect(normalizeSeenReleaseIds([], "nazumods/wow")).toEqual({});
  });

  test("an already-keyed map passes through untouched", () => {
    const map = { "nazumods/wow": [1], "roshne/ActionBarMaster": [2] };
    expect(normalizeSeenReleaseIds(map, "nazumods/wow")).toEqual(map);
  });

  test("undefined (fresh install) yields an empty map", () => {
    expect(normalizeSeenReleaseIds(undefined, "nazumods/wow")).toEqual({});
  });
});

describe("loadState", () => {
  const fileWith = (text: string) => {
    const path = join(mkdtempSync(join(tmpdir(), "bot-load-")), "state.json");
    writeFileSync(path, text);
    return path;
  };

  test("a truncated file loads as defaults and logs a warning", async () => {
    const warn = spyOn(console, "warn").mockImplementation(() => {});
    const loaded = await loadState(fileWith('{\n  "seenReleaseIds": {\n    "nazumods/wo'));
    expect(loaded).toEqual({ seenReleaseIds: {} });
    expect(warn).toHaveBeenCalledTimes(1);
    warn.mockRestore();
  });

  test("valid JSON that is not an object loads as defaults", async () => {
    const warn = spyOn(console, "warn").mockImplementation(() => {});
    expect(await loadState(fileWith("null"))).toEqual({ seenReleaseIds: {} });
    expect(await loadState(fileWith("[1]"))).toEqual({ seenReleaseIds: {} });
    warn.mockRestore();
  });

  test("concurrent saves all settle and leave a valid file", async () => {
    state.seenReleaseIds = { "a/b": [1] };
    await Promise.all([saveState(), saveState(), saveState(), saveState()]);
    const loaded = await loadState(join(process.env.STATE_DIR!, "state.json"));
    expect(loaded.seenReleaseIds).toEqual({ "a/b": [1] });
  });

  test("an unreadable file is kept aside, not overwritten", async () => {
    const warn = spyOn(console, "warn").mockImplementation(() => {});
    const path = fileWith("{ truncated");
    await loadState(path);
    expect(await Bun.file(path).exists()).toBe(false);
    expect(readdirSync(dirname(path)).some((f) => f.startsWith("state.json.corrupt-"))).toBe(true);
    warn.mockRestore();
  });

  test("a good file round-trips through the atomic save", async () => {
    state.seenReleaseIds = { "a/b": [1, 2] };
    await saveState();
    const loaded = await loadState(join(process.env.STATE_DIR!, "state.json"));
    expect(loaded.seenReleaseIds).toEqual({ "a/b": [1, 2] });
    expect(await Bun.file(join(process.env.STATE_DIR!, "state.json.tmp")).exists()).toBe(false);
  });
});

describe("normalizeSeenReleaseIds with wrong-typed data", () => {
  test("non-object values yield an empty map", () => {
    expect(normalizeSeenReleaseIds("x", "r")).toEqual({});
    expect(normalizeSeenReleaseIds(5, "r")).toEqual({});
  });

  test("drops non-array entries and non-numeric ids", () => {
    expect(normalizeSeenReleaseIds({ a: 5, b: "x", c: [1, "2", 3] }, "r")).toEqual({ c: [1, 3] });
  });
});

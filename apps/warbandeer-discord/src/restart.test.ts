import { beforeEach, describe, expect, test } from "bun:test";
import {
  REDEPLOY_EXIT_CODE,
  RESTART_EXIT_CODE,
  beginCritical,
  endCritical,
  requestRestart,
  resetForTest,
  restartPending,
  setExitFn,
  withCritical,
} from "./restart";

let exits: number[] = [];
let restore: () => void;

beforeEach(() => {
  resetForTest();
  exits = [];
  restore?.();
  restore = setExitFn((code) => exits.push(code));
});

describe("requestRestart", () => {
  test("exits immediately when idle", () => {
    requestRestart("test");
    expect(exits).toEqual([RESTART_EXIT_CODE]);
  });

  test("defers while a critical section is open, then exits once it closes", () => {
    beginCritical();
    requestRestart("test");
    expect(exits).toEqual([]);
    expect(restartPending()).toBe(true);
    endCritical();
    expect(exits).toEqual([RESTART_EXIT_CODE]);
  });

  test("waits for nested critical sections to fully unwind", () => {
    beginCritical();
    beginCritical();
    requestRestart("test");
    endCritical();
    expect(exits).toEqual([]);
    endCritical();
    expect(exits).toEqual([RESTART_EXIT_CODE]);
  });

  test("exits exactly once when requested repeatedly", () => {
    beginCritical();
    requestRestart("first");
    requestRestart("second");
    endCritical();
    expect(exits).toEqual([RESTART_EXIT_CODE]);
  });

  test("does not exit when a critical section opens and closes with none pending", () => {
    beginCritical();
    endCritical();
    expect(exits).toEqual([]);
    expect(restartPending()).toBe(false);
  });
});

// #868: an update-driven exit asks for a REBUILD (76), not a bare respawn (75). The deferral
// machinery is shared, so the risk in adding a second code is that the code gets lost somewhere
// along the deferred path — hence re-running the matrix against it rather than just the idle case.
describe("requestRestart — redeploy", () => {
  test("redeploy exits 76, a plain restart still exits 75", () => {
    requestRestart("update", { redeploy: true });
    expect(exits).toEqual([REDEPLOY_EXIT_CODE]);
  });

  test("the two codes are actually distinct", () => {
    expect(REDEPLOY_EXIT_CODE).not.toBe(RESTART_EXIT_CODE);
  });

  test("an explicit redeploy:false is a plain restart", () => {
    requestRestart("test", { redeploy: false });
    expect(exits).toEqual([RESTART_EXIT_CODE]);
  });

  test("the code survives being deferred through a critical section", () => {
    beginCritical();
    requestRestart("update", { redeploy: true });
    expect(exits).toEqual([]);
    endCritical();
    expect(exits).toEqual([REDEPLOY_EXIT_CODE]);
  });

  test("survives nested sections unwinding", () => {
    beginCritical();
    beginCritical();
    requestRestart("update", { redeploy: true });
    endCritical();
    endCritical();
    expect(exits).toEqual([REDEPLOY_EXIT_CODE]);
  });

  // The first reason wins, and its code has to win with it — otherwise a later plain restart
  // could silently downgrade a pending redeploy to a respawn.
  test("the first request's code wins, not the last", () => {
    beginCritical();
    requestRestart("update", { redeploy: true });
    requestRestart("something else");
    endCritical();
    expect(exits).toEqual([REDEPLOY_EXIT_CODE]);
  });

  test("and the same the other way round", () => {
    beginCritical();
    requestRestart("plain");
    requestRestart("update", { redeploy: true });
    endCritical();
    expect(exits).toEqual([RESTART_EXIT_CODE]);
  });

  test("deferred from inside withCritical", async () => {
    await withCritical(async () => {
      requestRestart("update", { redeploy: true });
    });
    expect(exits).toEqual([REDEPLOY_EXIT_CODE]);
  });
});

describe("withCritical", () => {
  test("defers a restart requested from inside", async () => {
    const seen: number[] = [];
    await withCritical(async () => {
      requestRestart("test");
      seen.push(...exits);
    });
    expect(seen).toEqual([]);
    expect(exits).toEqual([RESTART_EXIT_CODE]);
  });

  test("still releases the section when the body throws", async () => {
    await expect(
      withCritical(async () => {
        requestRestart("test");
        throw new Error("boom");
      }),
    ).rejects.toThrow("boom");
    expect(exits).toEqual([RESTART_EXIT_CODE]);
  });
});

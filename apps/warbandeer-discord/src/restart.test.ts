import { beforeEach, describe, expect, test } from "bun:test";
import {
  RESTART_EXIT_CODE,
  beginCritical,
  beginHandoff,
  endCritical,
  endHandoff,
  handoffActive,
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

// #879: the outgoing bot has to stay alive through a handoff — it is the only thing that can
// remove a replacement which fails to verify, and the only thing that can report the failure.
describe("beginHandoff", () => {
  test("quiesces the scheduler without exiting", () => {
    beginHandoff("redeploy");
    expect(restartPending()).toBe(true);
    expect(handoffActive()).toBe(true);
    expect(exits).toEqual([]);
  });

  test("resuming lets normal work start again", () => {
    beginHandoff("redeploy");
    endHandoff();
    expect(restartPending()).toBe(false);
    expect(handoffActive()).toBe(false);
    expect(exits).toEqual([]);
  });

  test("resuming when no handoff is in flight is a no-op", () => {
    endHandoff();
    expect(restartPending()).toBe(false);
    expect(exits).toEqual([]);
  });

  // A handoff must not mask a genuine exit path, nor be masked by one.
  test("a restart requested during a handoff still exits", () => {
    beginHandoff("redeploy");
    requestRestart("test");
    expect(exits).toEqual([RESTART_EXIT_CODE]);
  });

  test("resuming does not clear a restart that is genuinely pending", () => {
    beginCritical();
    beginHandoff("redeploy");
    requestRestart("test");
    endHandoff();
    expect(restartPending()).toBe(true);
    expect(exits).toEqual([]);
    endCritical();
    expect(exits).toEqual([RESTART_EXIT_CODE]);
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

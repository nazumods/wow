import { beforeEach, describe, expect, test } from "bun:test";
import {
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

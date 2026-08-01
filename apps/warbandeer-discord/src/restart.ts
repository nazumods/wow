// Graceful restart: the process exits, and the orchestrator respawns it.
//
// The bot never updates itself in place — a clean exit only picks up new code if
// whatever supervises the container supplies a rebuilt image. See README.
//
// A restart requested while an announcement or a state write is in flight is
// deferred until the critical section unwinds, so `data/state.json` is never
// truncated mid-write and no announcement is half-posted.

/** Distinct from a crash, so a supervisor can tell an update apart from a failure. */
export const RESTART_EXIT_CODE = 75;

type ExitFn = (code: number) => void;

let critical = 0;
let pending: string | undefined;
let handoff: string | undefined;
let exitFn: ExitFn = (code) => process.exit(code);

/** Swap the exit for tests. Returns a restore fn. */
export function setExitFn(fn: ExitFn): () => void {
  const prev = exitFn;
  exitFn = fn;
  return () => {
    exitFn = prev;
  };
}

/** Reset module state between tests. */
export function resetForTest(): void {
  critical = 0;
  pending = undefined;
  handoff = undefined;
}

export function beginCritical(): void {
  critical += 1;
}

export function endCritical(): void {
  critical = Math.max(0, critical - 1);
  if (critical === 0 && pending !== undefined) doExit(pending);
}

/** Run `fn` with restarts deferred until it settles. */
export async function withCritical<T>(fn: () => Promise<T>): Promise<T> {
  beginCritical();
  try {
    return await fn();
  } finally {
    endCritical();
  }
}

/**
 * Quiesce for a handoff (#879): the scheduler stops ticking, so nothing else writes
 * `data/state.json` while the replacement container comes up sharing that volume.
 *
 * Deliberately *not* a restart — this process must stay alive through the handoff. It is the
 * only thing left that can remove a replacement which fails to verify, and the only thing that
 * can tell the requester it failed. The replacement does the retiring; we never exit ourselves.
 */
export function beginHandoff(reason: string): void {
  handoff = reason;
  console.log(`[handoff] quiesced: ${reason}`);
}

/** Come back from a handoff that didn't happen, so the bot resumes its normal duties. */
export function endHandoff(): void {
  if (handoff === undefined) return;
  handoff = undefined;
  console.log("[handoff] resumed — still on the current build");
}

export function handoffActive(): boolean {
  return handoff !== undefined;
}

/** True while either an exit or a handoff is in flight — both mean "start no new work". */
export function restartPending(): boolean {
  return pending !== undefined || handoff !== undefined;
}

/**
 * Ask the process to exit so the orchestrator respawns it. Exits immediately when
 * idle, otherwise as soon as the in-flight critical section finishes. Repeat calls
 * while one is already pending are no-ops — the first reason wins.
 */
export function requestRestart(reason: string): void {
  if (pending !== undefined) return;
  pending = reason;
  if (critical === 0) doExit(reason);
  else console.log(`[restart] deferred until in-flight work finishes: ${reason}`);
}

function doExit(reason: string): void {
  console.log(`[restart] exiting (${RESTART_EXIT_CODE}): ${reason}`);
  exitFn(RESTART_EXIT_CODE);
}

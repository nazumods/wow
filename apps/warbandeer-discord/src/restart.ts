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

/**
 * "Respawning me is not enough — rebuild the image first" (#868).
 *
 * Separate from 75 because the two ask for different things, and the difference has to survive
 * a host that isn't listening. Under `restart: unless-stopped` Docker respawns on **any** exit
 * code, so with no watcher installed 76 behaves exactly as 75 does today: the bot comes back on
 * the same image and the follow-up reports the no-op honestly. With `ops/bot-redeploy-watch.sh`
 * running, 76 is what triggers `bot-ops.sh rebuild`.
 *
 * An update-driven exit uses this unconditionally rather than keying off `REDEPLOY_SUPERVISOR` —
 * the code states what the bot wants, not what it believes the host can do, so the config flag
 * only ever changes what `/update` *says*, never the exit semantics.
 */
export const REDEPLOY_EXIT_CODE = 76;

type ExitFn = (code: number) => void;
interface Pending {
  reason: string;
  code: number;
}

let critical = 0;
let pending: Pending | undefined;
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

export function restartPending(): boolean {
  return pending !== undefined;
}

/**
 * Ask the process to exit so the orchestrator respawns it. Exits immediately when
 * idle, otherwise as soon as the in-flight critical section finishes. Repeat calls
 * while one is already pending are no-ops — the first reason wins, and so does its
 * exit code.
 *
 * `redeploy` asks for 76 instead of 75: respawning the same image won't do, rebuild it first.
 */
export function requestRestart(reason: string, o: { redeploy?: boolean } = {}): void {
  if (pending !== undefined) return;
  pending = { reason, code: o.redeploy ? REDEPLOY_EXIT_CODE : RESTART_EXIT_CODE };
  if (critical === 0) doExit(pending);
  else console.log(`[restart] deferred until in-flight work finishes: ${reason}`);
}

function doExit(p: Pending): void {
  console.log(`[restart] exiting (${p.code}): ${p.reason}`);
  exitFn(p.code);
}

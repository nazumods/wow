// The handoff contract between the outgoing bot and its replacement (#879).
//
// The replacement is started *before* the original is retired, so nothing ever has to outlive
// its own shutdown. That inverts who does what: the old bot only starts things, and the new
// one — once it has proved itself — does all the retiring.
//
// The signal is a marker file in the shared `state:/app/data` volume both containers already
// mount. Deliberately its own file, never `state.json`: exactly one process writes it (the
// replacement) and exactly one reads it (the original), so the file that actually matters is
// never touched by two writers at once.

import { join } from "node:path";

/** Set on the replacement only. Its presence *is* the instruction to boot in standby. */
export const HANDOFF_FROM_ENV = "HANDOFF_FROM";

/** How long the original waits for the replacement to prove itself before writing it off. */
export const HANDOFF_DEADLINE_MS = 120_000;

/** The replacement's own budget for reaching a gateway login. Inside the deadline above, so a
 *  replacement that gives up says so — the original learns why instead of just timing out. */
export const VERIFY_DEADLINE_MS = 90_000;

/**
 * How long the original stays quiesced after seeing `ready` before deciding it is never going
 * to be retired.
 *
 * Seeing `ready` stops the original counting, because a replacement that has signalled is about
 * to stop it — normally within a second or two. But the marker is written *before* the retiring,
 * so a `retireOriginal` that throws in between leaves the original waiting on a stop that is
 * never coming: quiesced, not announcing, and silent until someone SSHes in. That is the exact
 * failure #879 set out to remove, so the quiesce gets an outer bound of its own. Generous on
 * purpose — every second here is one the ordinary path spends already dead.
 */
export const RETIREMENT_DEADLINE_MS = 180_000;

const DATA_DIR = join(import.meta.dir, "..", "data");
export const MARKER_FILE = join(DATA_DIR, "handoff.json");

export interface HandoffMarker {
  /** `ready` = logged in to the gateway and about to retire the original. */
  status: "ready" | "failed";
  /** The build the replacement is running, so the original can log what replaced it. */
  sha?: string;
  /** Why it gave up, when `failed`. */
  error?: string;
  at: number;
}

/**
 * How the original boots vs. how the replacement does. The replacement must come up in
 * standby — connected enough to verify itself, not yet answering — because both instances
 * hold the same `DISCORD_TOKEN`, and Discord delivers every event to both sessions. A
 * standby that registered handlers would double every command reply for the overlap.
 */
export function bootMode(env: Record<string, string | undefined>): "standby" | "normal" {
  return env[HANDOFF_FROM_ENV] ? "standby" : "normal";
}

export async function writeMarker(marker: HandoffMarker): Promise<void> {
  await Bun.write(MARKER_FILE, JSON.stringify(marker));
}

/** `undefined` when absent or unreadable — a half-written marker must read as "not yet". */
export async function readMarker(): Promise<HandoffMarker | undefined> {
  try {
    const file = Bun.file(MARKER_FILE);
    if (!(await file.exists())) return undefined;
    const raw = (await file.json()) as HandoffMarker;
    return raw.status === "ready" || raw.status === "failed" ? raw : undefined;
  } catch {
    return undefined;
  }
}

export async function clearMarker(): Promise<void> {
  await Bun.file(MARKER_FILE).delete().catch(() => {});
}

/** The replacement container's state, as far as the outcome decision cares. */
export interface ReplacementState {
  running: boolean;
  /** Docker's `State.Status`: `created`, `running`, `exited`, `dead`, … */
  status: string;
  exitCode: number;
}

export type HandoffOutcome =
  /** Verified. It is about to retire us; our last act was starting it. */
  | "ready"
  /** It said so itself, or it died trying. The original stays up and reports. */
  | "failed"
  /** It never answered either way. Same response as `failed`, but a different message. */
  | "timeout"
  /** Verified, then never retired us. Never returned by `decideHandoffOutcome` — this one is
   *  decided by outliving `RETIREMENT_DEADLINE_MS`, which only `redeploy` can observe. */
  | "stalled"
  /** Nothing decided yet — keep waiting. */
  | "waiting";

/**
 * Decide the handoff from one observation.
 *
 * The marker is read before the container state on purpose: a replacement that has signalled
 * `ready` is already retiring us, so it may well be stopping — and a container seen mid-stop
 * would otherwise be misread as one that died. What it *said* outranks how it currently looks.
 */
export function decideHandoffOutcome(o: {
  marker?: HandoffMarker;
  replacement?: ReplacementState;
  elapsedMs: number;
  deadlineMs?: number;
}): HandoffOutcome {
  if (o.marker?.status === "ready") return "ready";
  if (o.marker?.status === "failed") return "failed";
  // Gone entirely, or stopped without ever signalling: it isn't coming back to signal now.
  if (!o.replacement) return "failed";
  if (!o.replacement.running && o.replacement.status !== "created") return "failed";
  if (o.elapsedMs >= (o.deadlineMs ?? HANDOFF_DEADLINE_MS)) return "timeout";
  return "waiting";
}

/** What the requester is told when the swap didn't happen. The original is still running, which
 *  is the part that matters — this is a report, not an apology for being down. */
export function handoffFailureMessage(outcome: "failed" | "timeout" | "stalled", o: {
  targetSha: string;
  error?: string;
}): string {
  const short = o.targetSha.slice(0, 7);
  if (outcome === "timeout") {
    return (
      `⚠️ The replacement for \`${short}\` never reported in within ` +
      `${Math.round(HANDOFF_DEADLINE_MS / 1000)}s — I removed it and stayed on the current build.`
    );
  }
  if (outcome === "stalled") {
    // Distinct from `failed` on purpose: the replacement *worked* and then couldn't retire me,
    // which points at the daemon socket rather than at the new build.
    return (
      `⚠️ The replacement for \`${short}\` verified but never retired me within ` +
      `${Math.round(RETIREMENT_DEADLINE_MS / 60_000)}m — I removed it and stayed on the ` +
      `current build. Check the daemon socket.`
    );
  }
  return (
    `⚠️ The replacement for \`${short}\` failed to start` +
    `${o.error ? `: ${o.error}` : ""}. I removed it and stayed on the current build.`
  );
}

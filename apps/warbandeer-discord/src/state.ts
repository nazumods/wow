import { mkdirSync, renameSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { config } from "./config";
import type { RealmStatus } from "./wow/realm";

/**
 * A `/update`-initiated restart, recorded so the bot can tell the requester what build it
 * actually came back on. Written only by the command path — an `AUTO_UPDATE` exit or a host
 * reboot leaves it unset, and produces no follow-up.
 */
export interface PendingUpdateReport {
  fromSha: string; // sha we were running when /update fired
  toSha: string; // sha we exited to pick up
  userId: string; // who ran /update
  channelId?: string; // last-resort delivery target
  applicationId?: string; // with interactionToken, addresses the follow-up webhook route
  interactionToken?: string; // valid ~15 min from the interaction
  requestedAt: number; // ms epoch, so boot can tell a fresh restart from a week-old one
}

// Persisted so restarts never re-announce something already posted.
export interface BotState {
  // Seen release ids keyed by `owner/repo`, so watched repos never collide and each seeds
  // its "first poll is silent" backlog independently.
  seenReleaseIds: Record<string, number[]>;
  dmfAnnouncedFor?: string; // "2026-7"
  weeklyAnnouncedFor?: string; // ISO timestamp of the reset announced
  realmStatus?: RealmStatus; // last observed realm status; drives up/down transition announcements
  attemptedUpdateToSha?: string; // sha we last exited to update to; guards against an exit loop
  pendingUpdateReport?: PendingUpdateReport; // /update follow-up owed on next boot; consumed once
}

const RELEASE_ID_CAP = 100;

// STATE_DIR is only for tests, so they never touch the real state file.
const DATA_DIR = process.env.STATE_DIR ?? join(import.meta.dir, "..", "data");
const STATE_FILE = join(DATA_DIR, "state.json");

export const state: BotState = await loadState();

/**
 * A state file that is unreadable (truncated by a crash mid-write, or hand-edited badly) loads
 * as defaults rather than throwing: `state` is built by a top-level await, so a throw here
 * crash-loops the bot under `restart: unless-stopped`. The cost is a silent re-seed of the
 * release backlog, which beats never booting.
 */
export async function loadState(path = STATE_FILE): Promise<BotState> {
  const file = Bun.file(path);
  if (!(await file.exists())) return { seenReleaseIds: {} };
  let raw: (Omit<BotState, "seenReleaseIds"> & { seenReleaseIds?: number[] | Record<string, number[]> }) | null;
  try {
    raw = JSON.parse(await file.text());
    if (raw === null || typeof raw !== "object" || Array.isArray(raw)) {
      throw new Error("not a JSON object");
    }
  } catch (err) {
    // Keep the bad file for inspection; the next save would otherwise overwrite it.
    const kept = `${path}.corrupt-${Date.now()}`;
    try {
      renameSync(path, kept);
    } catch {
      // best effort — still boot
    }
    console.warn(`[state] ${path} is unreadable (${err}) — kept as ${kept}, starting from defaults`);
    return { seenReleaseIds: {} };
  }
  return { ...raw, seenReleaseIds: normalizeSeenReleaseIds(raw.seenReleaseIds, config.githubRepo) };
}

/**
 * Migrate the legacy global `seenReleaseIds` array — from when the bot watched a single
 * repo — into the per-repo map, filing it under the repo it used to mean. Non-destructive:
 * an already-keyed map (or a fresh install's `undefined`) passes through as-is.
 */
export function normalizeSeenReleaseIds(
  raw: unknown,
  defaultRepo: string,
): Record<string, number[]> {
  const ids = (v: unknown): number[] | null =>
    Array.isArray(v) ? v.filter((n): n is number => Number.isFinite(n)) : null;
  if (Array.isArray(raw)) return raw.length ? { [defaultRepo]: ids(raw)! } : {};
  if (raw === null || typeof raw !== "object") return {};
  // Drop wrong-typed entries rather than carry them: a non-array value would make every later
  // saveState (`slice`) and poll (`new Set`) throw.
  const out: Record<string, number[]> = {};
  for (const [repo, v] of Object.entries(raw)) {
    const list = ids(v);
    if (list) out[repo] = list;
  }
  return out;
}

/**
 * Writes are chained so they never overlap: they share one tmp path, and the scheduler tick,
 * /update and the update-report path can all save concurrently. Last writer wins. Takes the
 * file and the state to snapshot so tests can drive it without the process-wide singleton.
 */
export function createStateWriter(file: string, current: () => BotState): () => Promise<void> {
  let chain: Promise<void> = Promise.resolve();
  const write = () => {
    mkdirSync(dirname(file), { recursive: true });
    const snapshot = current();
    // Cap each repo's release-id history so the file never grows unbounded.
    for (const [repo, ids] of Object.entries(snapshot.seenReleaseIds)) {
      snapshot.seenReleaseIds[repo] = ids.slice(-RELEASE_ID_CAP);
    }
    // Write beside the target then rename over it: a crash mid-write leaves the old file
    // intact instead of a truncated one. Synchronous, so the snapshot is taken at write time.
    const tmp = `${file}.tmp`;
    writeFileSync(tmp, JSON.stringify(snapshot, null, 2));
    renameSync(tmp, file);
  };
  return () => {
    const run = chain.then(write);
    chain = run.catch(() => {}); // a failed write must not wedge later ones
    return run;
  };
}

export const saveState = createStateWriter(STATE_FILE, () => state);

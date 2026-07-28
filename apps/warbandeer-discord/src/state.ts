import { mkdirSync } from "node:fs";
import { join } from "node:path";
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

const DATA_DIR = join(import.meta.dir, "..", "data");
const STATE_FILE = join(DATA_DIR, "state.json");

export const state: BotState = await loadState();

async function loadState(): Promise<BotState> {
  const file = Bun.file(STATE_FILE);
  if (!(await file.exists())) return { seenReleaseIds: {} };
  const raw = (await file.json()) as Omit<BotState, "seenReleaseIds"> & {
    seenReleaseIds?: number[] | Record<string, number[]>;
  };
  return { ...raw, seenReleaseIds: normalizeSeenReleaseIds(raw.seenReleaseIds, config.githubRepo) };
}

/**
 * Migrate the legacy global `seenReleaseIds` array — from when the bot watched a single
 * repo — into the per-repo map, filing it under the repo it used to mean. Non-destructive:
 * an already-keyed map (or a fresh install's `undefined`) passes through as-is.
 */
export function normalizeSeenReleaseIds(
  raw: number[] | Record<string, number[]> | undefined,
  defaultRepo: string,
): Record<string, number[]> {
  if (Array.isArray(raw)) return raw.length ? { [defaultRepo]: raw } : {};
  return raw ?? {};
}

export async function saveState(): Promise<void> {
  mkdirSync(DATA_DIR, { recursive: true });
  // Cap each repo's release-id history so the file never grows unbounded.
  for (const [repo, ids] of Object.entries(state.seenReleaseIds)) {
    state.seenReleaseIds[repo] = ids.slice(-RELEASE_ID_CAP);
  }
  await Bun.write(STATE_FILE, JSON.stringify(state, null, 2));
}

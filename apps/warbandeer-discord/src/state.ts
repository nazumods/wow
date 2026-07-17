import { mkdirSync } from "node:fs";
import { join } from "node:path";

// Persisted so restarts never re-announce something already posted.
export interface BotState {
  seenReleaseIds: number[];
  dmfAnnouncedFor?: string; // "2026-7"
  weeklyAnnouncedFor?: string; // ISO timestamp of the reset announced
  serversUpAnnouncedFor?: string; // ISO timestamp of the reset whose recovery was announced
  attemptedUpdateToSha?: string; // sha we last exited to update to; guards against an exit loop
}

const DATA_DIR = join(import.meta.dir, "..", "data");
const STATE_FILE = join(DATA_DIR, "state.json");

export const state: BotState = await loadState();

async function loadState(): Promise<BotState> {
  const file = Bun.file(STATE_FILE);
  if (await file.exists()) return (await file.json()) as BotState;
  return { seenReleaseIds: [] };
}

export async function saveState(): Promise<void> {
  mkdirSync(DATA_DIR, { recursive: true });
  // Cap the release-id history so the file never grows unbounded.
  state.seenReleaseIds = state.seenReleaseIds.slice(-100);
  await Bun.write(STATE_FILE, JSON.stringify(state, null, 2));
}

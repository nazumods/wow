import type { Client } from "discord.js";
import { config } from "./config";
import { state, saveState } from "./state";
import { currentOrNextDmf } from "./wow/dmf";
import { lastWeeklyReset } from "./wow/reset";
import { realmStatus, realmWatchConfigured } from "./wow/realm";
import { fetchReleases } from "./github";

const TICK_MS = 60 * 1000;
const RESET_ANNOUNCE_WINDOW_MS = 10 * 60 * 1000;
const REALM_WATCH_MAX_MS = 3 * 3600 * 1000;

// Releases publish from a daily cron at 14:00 UTC (.github/workflows/release.yml),
// so poll only inside a window after it — plus once at startup to catch anything
// published while the bot was offline.
const RELEASE_CRON_HOUR_UTC = 14;
const RELEASE_WINDOW_MS = 90 * 60 * 1000;
const RELEASE_POLL_GAP_MS = 5 * 60 * 1000;

let lastReleasePollAt = 0;
// Active only on reset day: waits for the realm to go DOWN, announces recovery.
let realmWatch: { resetIso: string; sawDown: boolean; startedAt: number } | undefined;

export function startScheduler(client: Client): void {
  const tick = () => onTick(client).catch((err) => console.error("[tick]", err));
  tick();
  setInterval(tick, TICK_MS);
}

async function announce(client: Client, message: string): Promise<void> {
  const channel = await client.channels.fetch(config.announceChannelId);
  if (!channel?.isSendable()) throw new Error("ANNOUNCE_CHANNEL_ID is not a sendable channel");
  await channel.send(message);
  console.log("[announce]", message);
}

async function onTick(client: Client): Promise<void> {
  await checkDmf(client);
  await checkWeeklyReset(client);
  await checkRealmWatch(client);
  if (shouldPollReleases(new Date())) await checkReleases(client);
}

function shouldPollReleases(now: Date): boolean {
  if (lastReleasePollAt === 0) return true; // startup catch-up
  const windowStart = Date.UTC(
    now.getUTCFullYear(),
    now.getUTCMonth(),
    now.getUTCDate(),
    RELEASE_CRON_HOUR_UTC,
  );
  const inWindow = now.getTime() >= windowStart && now.getTime() < windowStart + RELEASE_WINDOW_MS;
  return inWindow && now.getTime() - lastReleasePollAt >= RELEASE_POLL_GAP_MS;
}

async function checkDmf(client: Client): Promise<void> {
  const { active, window } = currentOrNextDmf();
  if (!active) return;
  const key = `${window.start.getUTCFullYear()}-${window.start.getUTCMonth() + 1}`;
  if (state.dmfAnnouncedFor === key) return;
  const closes = Math.floor(window.end.getTime() / 1000);
  await announce(client, `🎪 The **Darkmoon Faire** is open! It runs until <t:${closes}:F>.`);
  state.dmfAnnouncedFor = key;
  await saveState();
}

async function checkWeeklyReset(client: Client): Promise<void> {
  const now = new Date();
  const last = lastWeeklyReset(now);
  if (now.getTime() - last.getTime() > RESET_ANNOUNCE_WINDOW_MS) return;
  const key = last.toISOString();
  if (state.weeklyAnnouncedFor === key) return;
  await announce(client, "📅 **Weekly reset!** Vault, lockouts, and quests have rolled over.");
  state.weeklyAnnouncedFor = key;
  await saveState();
  if (realmWatchConfigured()) {
    realmWatch = { resetIso: key, sawDown: false, startedAt: Date.now() };
  }
}

async function checkRealmWatch(client: Client): Promise<void> {
  if (!realmWatch) return;
  if (Date.now() - realmWatch.startedAt > REALM_WATCH_MAX_MS) {
    realmWatch = undefined; // no maintenance this week
    return;
  }
  const status = await realmStatus();
  if (status === "DOWN") {
    realmWatch.sawDown = true;
  } else if (realmWatch.sawDown && state.serversUpAnnouncedFor !== realmWatch.resetIso) {
    await announce(client, `🟢 **${config.realmSlug}** is back up — servers are live!`);
    state.serversUpAnnouncedFor = realmWatch.resetIso;
    await saveState();
    realmWatch = undefined;
  }
}

async function checkReleases(client: Client): Promise<void> {
  lastReleasePollAt = Date.now();
  const releases = await fetchReleases();
  // First run seeds silently so a fresh install doesn't spam the backlog.
  if (state.seenReleaseIds.length === 0) {
    state.seenReleaseIds = releases.map((r) => r.id);
    await saveState();
    return;
  }
  const seen = new Set(state.seenReleaseIds);
  for (const release of releases.filter((r) => !seen.has(r.id)).reverse()) {
    await announce(client, `📦 New release: **${release.name}**\n${release.url}`);
    state.seenReleaseIds.push(release.id);
  }
  await saveState();
}

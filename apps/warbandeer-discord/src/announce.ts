import type { Client } from "discord.js";
import { config } from "./config";
import { state, saveState } from "./state";
import { currentOrNextDmf } from "./wow/dmf";
import { lastWeeklyReset } from "./wow/reset";
import { realmStatus, realmWatchConfigured, decideRealmTransition, type RealmStatus } from "./wow/realm";
import { fetchReleases, decideReleaseAnnouncements, createReachabilityLog } from "./github";
import { checkForUpdate } from "./update";
import { restartPending, withCritical } from "./restart";

const TICK_MS = 60 * 1000;
const RESET_ANNOUNCE_WINDOW_MS = 10 * 60 * 1000;
// Poll the realm continuously (not only around reset) so an unscheduled outage at any hour is
// caught. The gap keeps the Blizzard call cadence gentle while still catching short outages.
const REALM_POLL_GAP_MS = 2 * 60 * 1000;

// Releases publish from a daily cron at 14:00 UTC (.github/workflows/release.yml),
// so poll only inside a window after it — plus once at startup to catch anything
// published while the bot was offline.
const RELEASE_CRON_HOUR_UTC = 14;
const RELEASE_WINDOW_MS = 90 * 60 * 1000;
const RELEASE_POLL_GAP_MS = 5 * 60 * 1000;

// Bot commits land at any hour, so — unlike releases — this polls on a flat cadence.
const UPDATE_POLL_GAP_MS = 15 * 60 * 1000;

let lastReleasePollAt = 0;
let lastUpdatePollAt = 0;
let lastRealmPollAt = 0;

export function startScheduler(client: Client): void {
  const tick = () => onTick(client).catch((err) => console.error("[tick]", err));
  tick();
  setInterval(tick, TICK_MS);
}

type AnnounceKind = "dmf" | "weeklyReset" | "serverUp" | "serverDown" | "release";

// Per-kind channel routing: future announcement kinds plug in here (see issue #528).
function channelFor(kind: AnnounceKind): string {
  return kind === "release" ? config.releaseAnnounceChannelId : config.announceChannelId;
}

async function announce(client: Client, kind: AnnounceKind, message: string): Promise<void> {
  const channelId = channelFor(kind);
  const channel = await client.channels.fetch(channelId);
  if (!channel?.isSendable()) throw new Error(`Announce channel ${channelId} is not sendable`);
  await channel.send(message);
  console.log("[announce]", message);
}

async function onTick(client: Client): Promise<void> {
  if (restartPending()) return; // on the way out — don't start work we can't finish
  // The whole tick is one critical section: a restart requested by the update check
  // below lands only once every announcement and state write has settled.
  await withCritical(async () => {
    await checkDmf(client);
    await checkWeeklyReset(client);
    await checkRealm(client);
    if (shouldPollReleases(new Date())) await checkReleases(client);
    if (config.autoUpdate && shouldPollUpdate()) await checkAutoUpdate();
  });
}

function shouldPollUpdate(): boolean {
  return Date.now() - lastUpdatePollAt >= UPDATE_POLL_GAP_MS;
}

async function checkAutoUpdate(): Promise<void> {
  lastUpdatePollAt = Date.now();
  await checkForUpdate();
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
  await announce(client, "dmf", `🎪 The **Darkmoon Faire** is open! It runs until <t:${closes}:F>.`);
  state.dmfAnnouncedFor = key;
  await saveState();
}

async function checkWeeklyReset(client: Client): Promise<void> {
  const now = new Date();
  const last = lastWeeklyReset(now);
  if (now.getTime() - last.getTime() > RESET_ANNOUNCE_WINDOW_MS) return;
  const key = last.toISOString();
  if (state.weeklyAnnouncedFor === key) return;
  await announce(client, "weeklyReset", "📅 **Weekly reset!** Vault, lockouts, and quests have rolled over.");
  state.weeklyAnnouncedFor = key;
  await saveState();
}

// Continuously watch the realm and announce every UP↔DOWN transition, so an outage at any hour
// is reported — not only weekly-reset maintenance. A Blizzard error is swallowed: it must never
// masquerade as a DOWN, nor block the rest of the tick.
async function checkRealm(client: Client): Promise<void> {
  if (!realmWatchConfigured()) return;
  if (Date.now() - lastRealmPollAt < REALM_POLL_GAP_MS) return;
  lastRealmPollAt = Date.now();
  let status: RealmStatus;
  try {
    status = await realmStatus();
  } catch (err) {
    console.error("[realm]", err);
    return;
  }
  const transition = decideRealmTransition(state.realmStatus, status);
  if (transition === "down") {
    await announce(client, "serverDown", `🔴 **${config.realmSlug}** is down — servers are offline.`);
  } else if (transition === "up") {
    await announce(client, "serverUp", `🟢 **${config.realmSlug}** is back up — servers are live!`);
  }
  if (state.realmStatus !== status) {
    state.realmStatus = status;
    await saveState();
  }
}

async function checkReleases(client: Client): Promise<void> {
  lastReleasePollAt = Date.now();
  // Poll each watched repo independently: one repo's fetch failure (e.g. a bad name → 404)
  // must not starve the others' announcements on this tick.
  for (const repo of config.watchedRepos) {
    try {
      await checkRepoReleases(client, repo);
    } catch (err) {
      console.error(`[release] ${repo}`, err);
    }
  }
}

// A watched repo can be unreadable for as long as it is watched — renamed, deleted, or private
// to the bot's token — and that must not reprint the same failure every poll, where it would
// bury a real one. Track it here so the condition is reported on its edges only.
const releaseReachability = createReachabilityLog();

async function checkRepoReleases(client: Client, repo: string): Promise<void> {
  const releases = await fetchReleases(repo);
  if (releases === null) {
    if (releaseReachability.observe(repo, false) === "lost") {
      console.warn(
        `[release] ${repo} is unreachable (missing, or GITHUB_TOKEN cannot see it) — ` +
          `skipping it quietly until it answers again`,
      );
    }
    // Leave its seen-id list untouched, so a repo that comes back seeds silently rather
    // than announcing everything published while it was invisible.
    return;
  }
  if (releaseReachability.observe(repo, true) === "recovered") {
    console.log(`[release] ${repo} is reachable again`);
  }
  const { toAnnounce, nextSeen } = decideReleaseAnnouncements(releases, state.seenReleaseIds[repo]);
  for (const release of toAnnounce) {
    await announce(client, "release", `📦 New release: **${release.name}**\n${release.url}`);
  }
  state.seenReleaseIds[repo] = nextSeen;
  await saveState();
}

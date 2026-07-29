import { config } from "../config";
import { blizzardConfigured, blizzardToken } from "./blizzard";

// Connected-realm status via the Blizzard Game Data API (client-credentials OAuth).
// The token itself moved to ./blizzard once a second caller (the character profile read
// behind /transmog) needed it — it was never realm-specific.
export type RealmStatus = "UP" | "DOWN";

export function realmWatchConfigured(): boolean {
  return Boolean(blizzardConfigured() && config.realmSlug);
}

// Decide what (if anything) to announce given the last-known status and a fresh reading.
// A missing `prev` is the first observation: seed it silently so a fresh install or a
// restart never posts a phantom transition. `null` = announce nothing.
export function decideRealmTransition(
  prev: RealmStatus | undefined,
  next: RealmStatus,
): "up" | "down" | null {
  if (prev === undefined || prev === next) return null;
  return next === "DOWN" ? "down" : "up";
}

/**
 * Whether `slug` names a realm in the configured region.
 *
 * Exists to separate two causes the character endpoint can't: Blizzard returns the *same* 404 for
 * a character that doesn't exist and a realm that doesn't exist, so the only way to tell them
 * apart is to ask about the realm on its own. Called only on the failure path, so a successful
 * lookup never pays for it.
 *
 * **Fails open.** If this check can't complete, it reports `true` — an outage or a rate limit must
 * not turn "we couldn't ask" into "your realm is wrong", which would send someone chasing a typo
 * that isn't there.
 */
export async function realmExists(slug: string): Promise<boolean> {
  const url =
    `https://${config.region}.api.blizzard.com/data/wow/search/connected-realm` +
    `?namespace=dynamic-${config.region}&realms.slug=${slug}&_pageSize=1`;
  try {
    const res = await fetch(url, { headers: { Authorization: `Bearer ${await blizzardToken()}` } });
    if (!res.ok) return true;
    const data = (await res.json()) as { results?: unknown[] };
    return (data.results?.length ?? 0) > 0;
  } catch {
    return true;
  }
}

export async function realmStatus(): Promise<RealmStatus> {
  const url =
    `https://${config.region}.api.blizzard.com/data/wow/search/connected-realm` +
    `?namespace=dynamic-${config.region}&realms.slug=${config.realmSlug}&_pageSize=1`;
  const res = await fetch(url, { headers: { Authorization: `Bearer ${await blizzardToken()}` } });
  if (!res.ok) throw new Error(`Blizzard realm query failed: ${res.status}`);
  const data = (await res.json()) as {
    results: { data: { status: { type: RealmStatus } } }[];
  };
  const status = data.results[0]?.data.status.type;
  if (!status) throw new Error(`Realm "${config.realmSlug}" not found in ${config.region}`);
  return status;
}

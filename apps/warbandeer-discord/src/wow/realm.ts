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

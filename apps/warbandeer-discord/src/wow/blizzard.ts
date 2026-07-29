import { config } from "../config";

// Shared Blizzard API access: the client-credentials token, cached until just before it expires.
//
// Client credentials are enough for everything the bot reads — connected-realm status (Game Data)
// and character profiles (Profile API, public characters). Neither needs per-user OAuth or a
// Battle.net account link.

let token: { value: string; expiresAt: number } | undefined;

export function blizzardConfigured(): boolean {
  return Boolean(config.blizzardClientId && config.blizzardClientSecret);
}

export async function blizzardToken(): Promise<string> {
  if (token && Date.now() < token.expiresAt) return token.value;
  const res = await fetch("https://oauth.battle.net/token", {
    method: "POST",
    headers: {
      Authorization: `Basic ${btoa(`${config.blizzardClientId}:${config.blizzardClientSecret}`)}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: "grant_type=client_credentials",
  });
  if (!res.ok) throw new Error(`Blizzard OAuth failed: ${res.status} ${await res.text()}`);
  const data = (await res.json()) as { access_token: string; expires_in: number };
  // Expire a minute early so a request can't set off mid-flight with a token about to lapse.
  token = { value: data.access_token, expiresAt: Date.now() + (data.expires_in - 60) * 1000 };
  return token.value;
}

/** Reset the cached token. Tests only — production has no reason to drop a valid token. */
export function _resetBlizzardToken(): void {
  token = undefined;
}

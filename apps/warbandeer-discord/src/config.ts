export type Region = "us" | "eu";

export interface Config {
  discordToken: string;
  announceChannelId: string;
  guildId?: string;
  region: Region;
  realmSlug?: string;
  blizzardClientId?: string;
  blizzardClientSecret?: string;
  githubRepo: string;
  githubToken?: string;
  dmfTimezone: string;
}

function required(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`Missing required env var ${name} (see .env.example)`);
  return v;
}

function optional(name: string): string | undefined {
  const v = process.env[name];
  return v === "" ? undefined : v;
}

const region = (optional("WOW_REGION") ?? "us") as Region;
if (region !== "us" && region !== "eu") {
  throw new Error(`WOW_REGION must be "us" or "eu", got "${region}"`);
}

export const config: Config = {
  discordToken: required("DISCORD_TOKEN"),
  announceChannelId: required("ANNOUNCE_CHANNEL_ID"),
  guildId: optional("GUILD_ID"),
  region,
  realmSlug: optional("WOW_REALM"),
  blizzardClientId: optional("BLIZZARD_CLIENT_ID"),
  blizzardClientSecret: optional("BLIZZARD_CLIENT_SECRET"),
  githubRepo: optional("GITHUB_REPO") ?? "nazumods/wow",
  githubToken: optional("GITHUB_TOKEN"),
  dmfTimezone:
    optional("DMF_TIMEZONE") ?? (region === "us" ? "America/Los_Angeles" : "Europe/Paris"),
};

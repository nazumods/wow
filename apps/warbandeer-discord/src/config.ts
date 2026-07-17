export type Region = "us" | "eu";

export interface Config {
  discordToken: string;
  announceChannelId: string;
  releaseAnnounceChannelId: string;
  guildId?: string;
  region: Region;
  realmSlug?: string;
  blizzardClientId?: string;
  blizzardClientSecret?: string;
  githubRepo: string;
  githubToken?: string;
  dmfTimezone: string;
  /** Commit this build was made from, baked in via the GIT_SHA build arg. Absent = self-update disabled. */
  gitSha?: string;
  /** Branch self-update measures staleness against. Must exist on `githubRepo`. */
  botBranch: string;
  autoUpdate: boolean;
  /** Discord user IDs allowed to run /update. Empty = nobody. */
  adminUserIds: string[];
}

type Env = Record<string, string | undefined>;

export function resolveConfig(env: Env): Config {
  const required = (name: string): string => {
    const v = env[name];
    if (!v) throw new Error(`Missing required env var ${name} (see .env.example)`);
    return v;
  };

  const optional = (name: string): string | undefined => {
    const v = env[name];
    return v === "" ? undefined : v;
  };

  const list = (name: string): string[] => [
    ...new Set(
      (optional(name) ?? "")
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean),
    ),
  ];

  const region = (optional("WOW_REGION") ?? "us") as Region;
  if (region !== "us" && region !== "eu") {
    throw new Error(`WOW_REGION must be "us" or "eu", got "${region}"`);
  }

  const announceChannelId = required("ANNOUNCE_CHANNEL_ID");

  return {
    discordToken: required("DISCORD_TOKEN"),
    announceChannelId,
    releaseAnnounceChannelId: optional("RELEASE_ANNOUNCE_CHANNEL_ID") ?? announceChannelId,
    guildId: optional("GUILD_ID"),
    region,
    realmSlug: optional("WOW_REALM"),
    blizzardClientId: optional("BLIZZARD_CLIENT_ID"),
    blizzardClientSecret: optional("BLIZZARD_CLIENT_SECRET"),
    githubRepo: optional("GITHUB_REPO") ?? "nazumods/wow",
    githubToken: optional("GITHUB_TOKEN"),
    dmfTimezone:
      optional("DMF_TIMEZONE") ?? (region === "us" ? "America/Los_Angeles" : "Europe/Paris"),
    gitSha: optional("GIT_SHA"),
    botBranch: optional("BOT_BRANCH") ?? "main",
    autoUpdate: optional("AUTO_UPDATE") === "true",
    adminUserIds: list("ADMIN_USER_IDS"),
  };
}

export const config: Config = resolveConfig(process.env);

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
  reportRoleId?: string;
  commandPrefix: string;
}

/** `/report` project token → GitHub `owner/repo`. The slash-command choices are built from
 * these keys, so an unrecognized project token can't reach the handler. */
export const REPORT_PROJECTS: Record<string, string> = {
  wow: "nazumods/wow",
  abm: "roshne/ActionBarMaster",
};

/** The GitHub repo a `/report` project token maps to, or undefined if unknown. */
export function repoForProject(project: string): string | undefined {
  return REPORT_PROJECTS[project];
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

  // Optional prefix for slash-command names, so a second (debug/staging) bot can run in the
  // same server without command collisions. Discord requires lowercase command names.
  const commandPrefix = optional("COMMAND_PREFIX") ?? "";
  if (commandPrefix && !/^[a-z0-9_-]{1,20}$/.test(commandPrefix)) {
    throw new Error(
      `COMMAND_PREFIX must be 1-20 chars of lowercase letters, numbers, "-" or "_" ` +
        `(Discord slash-command name rules), got "${commandPrefix}"`,
    );
  }

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
    reportRoleId: optional("REPORT_ROLE_ID"),
    commandPrefix,
  };
}

export const config: Config = resolveConfig(process.env);

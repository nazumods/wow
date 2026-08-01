import {
  MessageFlags,
  SlashCommandBuilder,
  type ChatInputCommandInteraction,
  type RESTPostAPIChatInputApplicationCommandsJSONBody,
} from "discord.js";
import { config, REPORT_PROJECTS } from "./config";
import { handleReportCommand } from "./report";
import { currentOrNextDmf } from "./wow/dmf";
import { nextDailyReset, nextWeeklyReset } from "./wow/reset";
import { realmStatus, realmWatchConfigured } from "./wow/realm";
import { blizzardConfigured } from "./wow/blizzard";
import {
  fetchTransmog,
  formatTransmogReply,
  realmSlug,
  TransmogLookupError,
} from "./wow/transmog";
import { checkForUpdate, type DisabledReason, type UpdateDecision } from "./update";
import { withCritical } from "./restart";
import { handoffFailureMessage } from "./handoff";
import type { RedeployResult } from "./redeploy";

const ts = (d: Date, style: "F" | "R" = "F") => `<t:${Math.floor(d.getTime() / 1000)}:${style}>`;
const when = (d: Date) => `${ts(d)} (${ts(d, "R")})`;

/**
 * /update is gated on an explicit Discord user-ID allowlist rather than a guild role:
 * roles get reassigned and inherited, an ID list only changes when the operator edits
 * the env. An empty list fails closed.
 */
export function isAdmin(userId: string, adminUserIds: string[]): boolean {
  return adminUserIds.includes(userId);
}

// COMMAND_PREFIX namespaces the command names (e.g. `r_` → `r_dmf`) so a second debug/staging
// bot can coexist in the same server. Empty by default → plain `dmf`/`reset`/`status`.
const prefix = config.commandPrefix;

/** Start a command under the configured prefix. Build every command with this — a hand-written
 *  `new SlashCommandBuilder().setName("foo")` registers outside the namespace. */
const cmd = (name: string) => new SlashCommandBuilder().setName(`${prefix}${name}`);

/**
 * The command name with COMMAND_PREFIX stripped, so dispatch reads the same whether or not a
 * prefix is configured. Tolerates an already-bare name: a command registered without `cmd()`
 * still dispatches, rather than being silently mangled into a name that matches no case.
 */
export function bareName(commandName: string, p: string = prefix): string {
  return commandName.startsWith(p) ? commandName.slice(p.length) : commandName;
}

export const commandData: RESTPostAPIChatInputApplicationCommandsJSONBody[] = [
  cmd("dmf").setDescription("Darkmoon Faire schedule"),
  cmd("reset").setDescription("Next daily and weekly reset times"),
  cmd("status").setDescription(
    `Realm status${config.realmSlug ? ` for ${config.realmSlug}` : ""}`,
  ),
  cmd("report")
    .setDescription("File a GitHub issue for a project")
    .addStringOption((o) =>
      o
        .setName("project")
        .setDescription("Which project the report is about")
        .setRequired(true)
        .addChoices(...Object.keys(REPORT_PROJECTS).map((k) => ({ name: k, value: k }))),
    ),
  cmd("transmog")
    .setDescription("Get a /customset import string for a character's transmog")
    .addStringOption((o) =>
      o.setName("character").setDescription("Character name").setRequired(true),
    )
    .addStringOption((o) =>
      o.setName("realm").setDescription('Realm, e.g. "Argent Dawn"').setRequired(true),
    ),
  cmd("update")
    .setDescription("Restart the bot to pick up the latest build (admins only)")
    // Hides it from non-admins in the UI. Defence in depth — the ID allowlist is the gate.
    .setDefaultMemberPermissions(0),
].map((c) => c.toJSON());

export async function handleCommand(interaction: ChatInputCommandInteraction): Promise<void> {
  switch (bareName(interaction.commandName)) {
    case "dmf": {
      const { active, window } = currentOrNextDmf();
      await interaction.reply(
        active
          ? `🎪 The Darkmoon Faire is **open**! It closes ${when(window.end)}.`
          : `🎪 The Darkmoon Faire opens ${when(window.start)}.`,
      );
      return;
    }
    case "reset": {
      await interaction.reply(
        `🕒 Daily reset: ${when(nextDailyReset())}\n📅 Weekly reset: ${when(nextWeeklyReset())}`,
      );
      return;
    }
    case "status": {
      if (!realmWatchConfigured()) {
        await interaction.reply({
          content:
            "Realm status is not configured — set `WOW_REALM`, `BLIZZARD_CLIENT_ID`, and `BLIZZARD_CLIENT_SECRET`.",
          flags: MessageFlags.Ephemeral,
        });
        return;
      }
      await interaction.deferReply();
      try {
        const status = await realmStatus();
        await interaction.editReply(
          status === "UP"
            ? `🟢 **${config.realmSlug}** is up.`
            : `🔴 **${config.realmSlug}** is down.`,
        );
      } catch (err) {
        await interaction.editReply(`⚠️ Could not query realm status: ${(err as Error).message}`);
      }
      return;
    }
    case "update": {
      if (!isAdmin(interaction.user.id, config.adminUserIds)) {
        await interaction.reply({
          content: config.adminUserIds.length
            ? "⛔ You're not allowed to run this."
            : "⛔ No admins are configured — set `ADMIN_USER_IDS` to enable `/update`.",
          flags: MessageFlags.Ephemeral,
        });
        return;
      }
      await interaction.deferReply({ flags: MessageFlags.Ephemeral });
      // Inside a critical section so the restart waits for the reply to be delivered.
      await withCritical(async () => {
        try {
          const { decision, latestSha, reason, redeploy } = await checkForUpdate({
            force: true,
            // Recorded so the next boot can report back what build it actually landed on.
            requester: {
              userId: interaction.user.id,
              channelId: interaction.channelId ?? undefined,
              applicationId: interaction.applicationId,
              interactionToken: interaction.token,
            },
          });
          await interaction.editReply(
            updateReply(decision, latestSha, { runningSha: config.gitSha, reason, redeploy }),
          );
        } catch (err) {
          await interaction.editReply(`⚠️ Update check failed: ${(err as Error).message}`);
        }
      });
      return;
    }
    case "transmog": {
      if (!blizzardConfigured()) {
        await interaction.reply({
          content:
            "Transmog lookup is not configured — set `BLIZZARD_CLIENT_ID` and `BLIZZARD_CLIENT_SECRET`.",
          flags: MessageFlags.Ephemeral,
        });
        return;
      }
      const character = interaction.options.getString("character", true);
      const realm = interaction.options.getString("realm", true);
      // Deferred: a token refresh plus the profile call can outrun Discord's 3s reply window.
      await interaction.deferReply();
      try {
        const result = await fetchTransmog(character, realm);
        await interaction.editReply(formatTransmogReply(character, realmSlug(realm), result));
      } catch (err) {
        // A lookup error is the user's to act on (wrong name/realm), so it carries its own
        // wording; anything else is ours and gets the generic shape.
        await interaction.editReply(
          err instanceof TransmogLookupError
            ? `⚠️ ${err.message}`
            : `⚠️ Transmog lookup failed: ${(err as Error).message}`,
        );
      }
      return;
    }
    case "report": {
      await handleReportCommand(interaction);
      return;
    }
  }
}

/**
 * `runningSha` is passed in rather than read off the `config` singleton: config resolves
 * process.env at import time and is shared across the whole bun test process, so a formatter
 * that reaches into it can only be tested by winning a race against whichever test file
 * imports config first.
 */
export function updateReply(
  decision: UpdateDecision,
  latestSha: string,
  o: { runningSha?: string; reason?: DisabledReason; redeploy?: RedeployResult } = {},
): string {
  const short = latestSha.slice(0, 7);
  const running = o.runningSha?.slice(0, 7);
  switch (decision) {
    case "busy":
      return "⏳ An update is already in progress — I'll report how it went; ask again after that.";
    case "disabled":
      // Two ways to end up here, and they need different things from the operator: bake a
      // GIT_SHA, versus push the branch you built from (#871).
      if (o.reason === "unpublished-sha") {
        return (
          `⚠️ Self-update is disabled — this build's commit \`${running}\` ` +
          `isn't on \`${config.githubRepo}\`, so I can't tell what I'm missing. ` +
          `Push the branch you built from, or deploy a pushed commit.`
        );
      }
      return "⚠️ Self-update is disabled — this build has no `GIT_SHA` baked in.";
    case "current":
      return `✅ Already on the latest build (\`${running}\`).`;
    case "suppressed":
    case "restart":
      // A self-contained redeploy that *worked* never reaches here: the replacement retires
      // this process mid-await, and delivers the ✅ itself from `pendingUpdateReport`. So a
      // result present at all is a failed swap, and the reply says so instead of promising a
      // return that isn't coming (#879).
      if (o.redeploy) {
        const kind =
          o.redeploy.outcome === "timeout" || o.redeploy.outcome === "stalled"
            ? o.redeploy.outcome
            : "failed";
        return handoffFailureMessage(kind, { targetSha: latestSha, error: o.redeploy.error });
      }
      // No "if I come back on the same build…" caveat: the bot answers that itself now,
      // with a follow-up naming the build it actually landed on (see updateReport.ts).
      return `🔄 Restarting to pick up \`${short}\`. I'll report back once I'm up.`;
  }
}

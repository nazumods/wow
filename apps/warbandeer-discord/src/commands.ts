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

const ts = (d: Date, style: "F" | "R" = "F") => `<t:${Math.floor(d.getTime() / 1000)}:${style}>`;
const when = (d: Date) => `${ts(d)} (${ts(d, "R")})`;

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
    case "report": {
      await handleReportCommand(interaction);
      return;
    }
  }
}

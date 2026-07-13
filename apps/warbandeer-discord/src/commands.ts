import {
  MessageFlags,
  SlashCommandBuilder,
  type ChatInputCommandInteraction,
  type RESTPostAPIChatInputApplicationCommandsJSONBody,
} from "discord.js";
import { config } from "./config";
import { currentOrNextDmf } from "./wow/dmf";
import { nextDailyReset, nextWeeklyReset } from "./wow/reset";
import { realmStatus, realmWatchConfigured } from "./wow/realm";

const ts = (d: Date, style: "F" | "R" = "F") => `<t:${Math.floor(d.getTime() / 1000)}:${style}>`;
const when = (d: Date) => `${ts(d)} (${ts(d, "R")})`;

export const commandData: RESTPostAPIChatInputApplicationCommandsJSONBody[] = [
  new SlashCommandBuilder().setName("dmf").setDescription("Darkmoon Faire schedule"),
  new SlashCommandBuilder()
    .setName("reset")
    .setDescription("Next daily and weekly reset times"),
  new SlashCommandBuilder()
    .setName("status")
    .setDescription(`Realm status${config.realmSlug ? ` for ${config.realmSlug}` : ""}`),
].map((c) => c.toJSON());

export async function handleCommand(interaction: ChatInputCommandInteraction): Promise<void> {
  switch (interaction.commandName) {
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
  }
}

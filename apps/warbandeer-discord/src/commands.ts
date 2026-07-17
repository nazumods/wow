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
import { checkForUpdate, type UpdateDecision } from "./update";
import { withCritical } from "./restart";

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

export const commandData: RESTPostAPIChatInputApplicationCommandsJSONBody[] = [
  new SlashCommandBuilder().setName("dmf").setDescription("Darkmoon Faire schedule"),
  new SlashCommandBuilder()
    .setName("reset")
    .setDescription("Next daily and weekly reset times"),
  new SlashCommandBuilder()
    .setName("status")
    .setDescription(`Realm status${config.realmSlug ? ` for ${config.realmSlug}` : ""}`),
  new SlashCommandBuilder()
    .setName("update")
    .setDescription("Restart the bot to pick up the latest build (admins only)")
    // Hides it from non-admins in the UI. Defence in depth — the ID allowlist is the gate.
    .setDefaultMemberPermissions(0),
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
          const { decision, latestSha } = await checkForUpdate(true);
          await interaction.editReply(updateReply(decision, latestSha));
        } catch (err) {
          await interaction.editReply(`⚠️ Update check failed: ${(err as Error).message}`);
        }
      });
      return;
    }
  }
}

function updateReply(decision: UpdateDecision, latestSha: string): string {
  const short = latestSha.slice(0, 7);
  switch (decision) {
    case "disabled":
      return "⚠️ Self-update is disabled — this build has no `GIT_SHA` baked in.";
    case "current":
      return `✅ Already on the latest build (\`${config.gitSha?.slice(0, 7)}\`).`;
    case "suppressed":
    case "restart":
      return (
        `🔄 Restarting to pick up \`${short}\`.\n` +
        "If I come back on the same build, the image wasn't rebuilt — see the README."
      );
  }
}

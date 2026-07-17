import {
  ActionRowBuilder,
  MessageFlags,
  ModalBuilder,
  TextInputBuilder,
  TextInputStyle,
  type ChatInputCommandInteraction,
  type ModalSubmitInteraction,
} from "discord.js";
import { config, repoForProject } from "./config";
import { createIssue, ensureLabel } from "./github";

const REPORT_LABEL = "automated";
const MODAL_PREFIX = "report:"; // modal customId = report:<project>

/** Issue body: the reporter's text plus a traceability footer naming the Discord user by
 * plain username (never a pingable mention). Pure — unit-tested. */
export function reportBody(description: string, username: string): string {
  return `${description}\n\n---\n_Filed from Discord via \`/report\` by **${username}**._`;
}

/** Does the interacting member hold the configured REPORT_ROLE_ID? Reads roles straight from
 * the interaction payload (no privileged Members intent), handling both a cached role manager
 * and the raw string[] of an uncached member. */
function hasReportRole(interaction: ChatInputCommandInteraction): boolean {
  if (!config.reportRoleId) return false;
  const roles = interaction.member?.roles;
  if (!roles) return false;
  return Array.isArray(roles)
    ? roles.includes(config.reportRoleId)
    : roles.cache.has(config.reportRoleId);
}

/** Is this modal submission one of ours? */
export function isReportModal(customId: string): boolean {
  return customId.startsWith(MODAL_PREFIX);
}

/** `/report project:<..>` → gate on config + role, then pop the Title/Description modal. */
export async function handleReportCommand(interaction: ChatInputCommandInteraction): Promise<void> {
  if (!config.reportRoleId || !config.githubToken) {
    await interaction.reply({
      content: "`/report` isn't configured — an admin must set `REPORT_ROLE_ID` and `GITHUB_TOKEN`.",
      flags: MessageFlags.Ephemeral,
    });
    return;
  }
  if (!hasReportRole(interaction)) {
    await interaction.reply({
      content: "You don't have the role required to file reports.",
      flags: MessageFlags.Ephemeral,
    });
    return;
  }

  const project = interaction.options.getString("project", true);
  const modal = new ModalBuilder()
    .setCustomId(`${MODAL_PREFIX}${project}`)
    .setTitle(`Report an issue — ${project}`)
    .addComponents(
      new ActionRowBuilder<TextInputBuilder>().addComponents(
        new TextInputBuilder()
          .setCustomId("title")
          .setLabel("Title")
          .setStyle(TextInputStyle.Short)
          .setMaxLength(120)
          .setRequired(true),
      ),
      new ActionRowBuilder<TextInputBuilder>().addComponents(
        new TextInputBuilder()
          .setCustomId("description")
          .setLabel("What happened? Steps, expected vs actual")
          .setStyle(TextInputStyle.Paragraph)
          .setRequired(true),
      ),
    );
  await interaction.showModal(modal);
}

/** Modal submit → create the GitHub issue in the mapped repo, reply (ephemeral) with its link. */
export async function handleReportModal(interaction: ModalSubmitInteraction): Promise<void> {
  const project = interaction.customId.slice(MODAL_PREFIX.length);
  const repo = repoForProject(project);
  if (!repo) {
    await interaction.reply({ content: `Unknown project \`${project}\`.`, flags: MessageFlags.Ephemeral });
    return;
  }

  const title = interaction.fields.getTextInputValue("title");
  const description = interaction.fields.getTextInputValue("description");
  await interaction.deferReply({ flags: MessageFlags.Ephemeral });
  try {
    await ensureLabel(repo, REPORT_LABEL);
    const issue = await createIssue(repo, title, reportBody(description, interaction.user.username), [
      REPORT_LABEL,
    ]);
    await interaction.editReply(`✅ Filed **${repo}#${issue.number}** — ${issue.url}`);
  } catch (err) {
    await interaction.editReply(`⚠️ Couldn't file the issue: ${(err as Error).message}`);
  }
}

import { Client, Events, GatewayIntentBits, REST, Routes } from "discord.js";
import { config } from "./config";
import { commandData, handleCommand } from "./commands";
import { isReportModal, handleReportModal } from "./report";
import { startScheduler } from "./announce";
import { reportUpdateOutcome } from "./updateReport";
import { bootMode, clearMarker, writeMarker, HANDOFF_FROM_ENV, VERIFY_DEADLINE_MS } from "./handoff";
import { retireOriginal } from "./redeploy";

const client = new Client({ intents: [GatewayIntentBits.Guilds] });
const mode = bootMode(process.env);

client.once(Events.ClientReady, async (c) => {
  console.log(`Logged in as ${c.user.tag}`);
  clearTimeout(verifyTimer);
  // A completed gateway login is the verification bar: process-alive proves nothing, and this
  // is the first moment the new build has demonstrated it can actually do its job.
  if (mode === "standby") await takeOver();
  await activate(c);
});

/**
 * Everything that makes this process *the* bot. Held back until the handoff completes so the
 * overlap stays silent: both instances hold the same `DISCORD_TOKEN` and Discord delivers
 * every event to both sessions, so a standby that registered these would double each reply.
 */
async function activate(c: Client<true>): Promise<void> {
  const rest = new REST().setToken(config.discordToken);
  await rest.put(
    config.guildId
      ? Routes.applicationGuildCommands(c.user.id, config.guildId)
      : Routes.applicationCommands(c.user.id),
    { body: commandData },
  );
  console.log(`Registered ${commandData.length} slash commands`);

  client.on(Events.InteractionCreate, async (interaction) => {
    try {
      if (interaction.isChatInputCommand()) {
        await handleCommand(interaction);
      } else if (interaction.isModalSubmit() && isReportModal(interaction.customId)) {
        await handleReportModal(interaction);
      }
    } catch (err) {
      console.error("[interaction]", err);
    }
  });

  startScheduler(client);
  // Deliberately not awaited: an owed /update follow-up must never hold up the scheduler,
  // and reportUpdateOutcome already swallows every delivery failure of its own.
  reportUpdateOutcome(client).catch((err) => console.error("[updateReport]", err));
}

/**
 * Retire the container that started us, and take its name.
 *
 * The marker is written *first*, in the same breath: it closes the window where the original
 * could hit its own deadline and remove a replacement that had already verified. Once it reads
 * `ready` it stops counting and simply waits to be stopped.
 */
async function takeOver(): Promise<void> {
  const originalId = process.env[HANDOFF_FROM_ENV]!;
  await writeMarker({ status: "ready", sha: config.gitSha, at: Date.now() });
  await retireOriginal(originalId);
  await clearMarker();
}

// A standby that never reaches ClientReady must say so rather than sit there: the original is
// holding its announcements, waiting on exactly this answer. Saying it beats being timed out —
// the requester gets the reason instead of a shrug. Cleared the moment the login lands.
const verifyTimer =
  mode === "standby"
    ? setTimeout(async () => {
        console.error("[handoff] no gateway login — giving up so the original can resume");
        await writeMarker({
          status: "failed",
          sha: config.gitSha,
          error: "the replacement never completed a gateway login",
          at: Date.now(),
        });
        process.exit(1);
      }, VERIFY_DEADLINE_MS)
    : undefined;

await client.login(config.discordToken);

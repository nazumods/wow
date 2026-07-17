import { Client, Events, GatewayIntentBits, REST, Routes } from "discord.js";
import { config } from "./config";
import { commandData, handleCommand } from "./commands";
import { isReportModal, handleReportModal } from "./report";
import { startScheduler } from "./announce";

const client = new Client({ intents: [GatewayIntentBits.Guilds] });

client.once(Events.ClientReady, async (c) => {
  console.log(`Logged in as ${c.user.tag}`);
  const rest = new REST().setToken(config.discordToken);
  await rest.put(
    config.guildId
      ? Routes.applicationGuildCommands(c.user.id, config.guildId)
      : Routes.applicationCommands(c.user.id),
    { body: commandData },
  );
  console.log(`Registered ${commandData.length} slash commands`);
  startScheduler(client);
});

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

await client.login(config.discordToken);

local G, SlashCmdList = _G, SlashCmdList

-- Global convenience slash commands, unscoped to any single addon. LibNAddOn is
-- always loaded as a dependency of the whole suite, so it's the natural home for
-- a small set of universally useful, stateless commands. Registered directly on
-- WoW's SlashCmdList rather than via ns:registerCommand, since they aren't
-- subcommands of any addon's base command.

---@type table<string, { aliases: string[], handler: fun() }>
local globalCommands = {
  RELOADUI = {
    aliases = {"/rl"},
    handler = ReloadUI,
  },
  FRAMESTACK = {
    aliases = {"/fs"},
    handler = function()
      C_AddOns.LoadAddOn("Blizzard_DebugTools")
      FrameStackTooltip_Toggle(false, true, true)
    end,
  },
  EDITMODE = {
    aliases = {"/etc"},
    handler = function()
      if EditModeManagerFrame:CanEnterEditMode() then
        ShowUIPanel(EditModeManagerFrame)
      end
    end,
  },
}

for base, cmd in pairs(globalCommands) do
  for i, alias in ipairs(cmd.aliases) do
    G["SLASH_"..base..i] = alias
  end
  SlashCmdList[base] = cmd.handler
end

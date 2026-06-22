---@class LibNAddOn
local ns = select(2, ...)
local G, SlashCmdList, insert = _G, SlashCmdList, table.insert
local split = ns.lua.strings.split

---@alias Command { handler: fun(self, args: string), description: string, subcommands?: table<string, Command> }

local registerSlashCommands = function(addOn, slashCommands)
  local bases = {}
  for base,commands in pairs(slashCommands) do
    base = string.upper(base)
    for i,cmd in ipairs(commands) do
      insert(bases, cmd)
      G["SLASH_"..base..i] = cmd
    end
    SlashCmdList[base] = function(msg)
      addOn:SlashCmd(base, msg)
    end
  end

  ---@class AddOn
  ---@field commands table<string, Command> Registered slash commands
  addOn.commands = {}

  ---@class AddOn
  ---@field registerCommand fun(self, cmd: string, subcmd: string, handler: fun(self, args: string), description: string) register a slash command
  function addOn:registerCommand(cmd, subcmd, handler, description)
    if not self.commands[cmd] then
      -- First registration for this cmd sets the base handler, which fires
      -- as the fallback when no subcommand matches in SlashCmd.
      self.commands[cmd] = {
        handler = handler,
        description = description,
      }
    end
    if subcmd then
      if not self.commands[cmd].subcommands then self.commands[cmd].subcommands = {} end
      self.commands[cmd].subcommands[subcmd] = {
        handler = handler,
        description = description,
      }
    end
  end

  local baseCmds = ""
  for _,base in ipairs(bases) do
    if baseCmds ~= "" then baseCmds = baseCmds .. ", " end
    baseCmds = baseCmds .. base
  end

  ---@class AddOn
  ---@field usage fun(self) print usage information for slash commands
  function addOn:usage()
    addOn.Print("Usage: [" .. baseCmds .. "] <command>")
    addOn.Print("Available commands:")
    for name, cmd in pairs(self.commands) do
      if cmd.subcommands then
        addOn.Print(" ", name, "<target>", "-", cmd.description or "")
      else
        addOn.Print(" ", name, "-", cmd.description or "")
      end
    end
  end

  ---@class AddOn
  ---@field SlashCmd fun(self, base: string, msg: string) handle a slash command
  function addOn:SlashCmd(_, msg) -- slashCmd
    local _, _, cmd, args = string.find(msg, "(%S+) ?(.*)")
    if cmd == nil then cmd = "" end
    if self.commands[cmd] then
      if self.commands[cmd].subcommands then
        local _, _, target, options = string.find(args, "(%S+) ?(.*)")
        if self.commands[cmd].subcommands[target] then
          self.commands[cmd].subcommands[target].handler(self, options)
          return
        end
      end
      if self.commands[cmd].handler then
        self.commands[cmd].handler(self, args)
        return
      end
    end
    addOn:usage()
  end
end

---@class LibNAddOn
---@field registerSlashCommands fun(addOn: AddOn, slashCommands: table<string, string[]>?) register slash commands for an add-on
function ns.registerSlashCommands(addOn, slashCommands)
  if slashCommands then
    registerSlashCommands(addOn, slashCommands)
  else
    local commands = addOn:GetMetadata("X-NUI-COMMANDS")
    if commands then
      local cfg = {}
      cfg[addOn._NAME] = split(", ", commands)
      registerSlashCommands(addOn, cfg)
    end
  end
end

if not ns.commands then ns.registerSlashCommands(ns) end

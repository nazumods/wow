local _, ns = ...
local G, SlashCmdList, insert = _G, SlashCmdList, table.insert
local split = ns.lua.strings.split

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

  addOn.commands = {}
  function addOn:registerCommand(cmd, subcmd, handler, description)
    if not self.commands[cmd] then
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

  function addOn:SlashCmd(_, msg) -- slashCmd
    local _, _, cmd, args = string.find(msg, "(%w+) ?(.*)")
    if cmd == nil then cmd = "" end
    if self.commands[cmd] then
      if self.commands[cmd].subcommands then
        local _, _, target, options = string.find(args, "(%w+) ?(.*)")
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

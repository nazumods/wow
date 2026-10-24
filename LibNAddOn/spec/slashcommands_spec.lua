-- Slash command dispatch (slashCommands.lua): which handler a typed command reaches.

local libn = require("LibNAddOn.spec.libn")

describe("slash command dispatch", function()
  local savedList, addOn, calls, usages

  local function register(cmd, sub)
    addOn:registerCommand(cmd, sub, function(_, args)
      calls[#calls + 1] = { cmd = cmd, sub = sub, args = args }
    end, "desc")
  end

  before_each(function()
    savedList = _G.SlashCmdList
    _G.SlashCmdList = {}
    local ns = libn.load()
    ns.commands = {} -- slashCommands.lua only self-registers when ns.commands is unset
    assert(loadfile("LibNAddOn/slashCommands.lua"))("LibNAddOn", ns)
    calls, usages = {}, 0
    addOn = { Print = function() end }
    ns.registerSlashCommands(addOn, { test = { "/test" } })
    addOn.usage = function() usages = usages + 1 end
  end)

  after_each(function()
    _G.SlashCmdList = savedList
  end)

  it("runs the base handler with the arguments for a command without subcommands", function()
    register("flavor")
    addOn:SlashCmd("TEST", "flavor some args")
    assert.same({ { cmd = "flavor", args = "some args" } }, calls)
  end)

  it("runs a matching subcommand with the remaining arguments", function()
    register("clear", "delves")
    register("clear", "dungeons")
    addOn:SlashCmd("TEST", "clear dungeons all")
    assert.same({ { cmd = "clear", sub = "dungeons", args = "all" } }, calls)
    assert.equals(0, usages)
  end)

  it("prints usage, not the first-registered subcommand, when no subcommand is typed", function()
    register("clear", "delves")
    register("clear", "dungeons")
    addOn:SlashCmd("TEST", "clear")
    assert.same({}, calls)
    assert.equals(1, usages)
  end)

  it("prints usage, not the first-registered subcommand, for an unknown subcommand", function()
    register("clear", "delves")
    register("clear", "dungeons")
    addOn:SlashCmd("TEST", "clear typo")
    addOn:SlashCmd("TEST", "clear delve")
    assert.same({}, calls)
    assert.equals(2, usages)
  end)

  it("runs the \"\" subcommand when the command is typed bare, and prints usage for an unknown one", function()
    register("refresh", "")
    register("refresh", "locks")
    addOn:SlashCmd("TEST", "refresh")
    assert.same({ { cmd = "refresh", sub = "", args = "" } }, calls)
    addOn:SlashCmd("TEST", "refresh nope")
    assert.equals(1, #calls)
    assert.equals(1, usages)
    addOn:SlashCmd("TEST", "refresh locks")
    assert.equals("locks", calls[2].sub)
  end)

  it("runs an explicit base handler (registered without a subcommand) only for a bare command", function()
    register("cfg")
    register("cfg", "reset")
    addOn:SlashCmd("TEST", "cfg")
    assert.same({ { cmd = "cfg", args = "" } }, calls)
    addOn:SlashCmd("TEST", "cfg typo")
    assert.equals(1, #calls)
    assert.equals(1, usages)
  end)

  it("prints usage for an unregistered command and for an empty message", function()
    addOn:SlashCmd("TEST", "nothing")
    addOn:SlashCmd("TEST", "")
    assert.same({}, calls)
    assert.equals(2, usages)
  end)
end)

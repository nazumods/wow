-- /wbc delete (#1111): the logged-in character can't be deleted (it would leave ns.currentData dangling).

-- luacheck: globals describe it before_each

local function noop() end

local function load()
  local ns = setmetatable({}, { __index = function() return noop end })
  ns.commands, ns.printed = {}, {}
  ns.wow = { Player = {} }
  ns.Print = function(msg) ns.printed[#ns.printed + 1] = msg end
  ns.registerCommand = function(_, cmd, _, handler) ns.commands[cmd] = handler end
  ns.db = {
    characters = { Me = { name = "Me" }, Alt = { name = "Alt" } },
    numCharacters = 2,
    bank = { characters = { Me = {}, Alt = {} } },
  }
  ns.currentPlayer = "Me"
  assert(loadfile("Warbandeer_Characters/database.lua"))("Warbandeer_Characters", ns)
  return ns
end

describe("/wbc delete (#1111)", function()
  local ns

  before_each(function() ns = load() end)

  it("refuses the logged-in character and changes nothing", function()
    ns.commands.delete(ns, "Me")
    assert.is_not_nil(ns.db.characters.Me)
    assert.is_not_nil(ns.db.bank.characters.Me)
    assert.equal(2, ns.db.numCharacters)
    assert.is_true(ns.printed[1]:find("logged in", 1, true) ~= nil)
  end)

  it("still deletes another character and its cached bank", function()
    ns.commands.delete(ns, "Alt")
    assert.is_nil(ns.db.characters.Alt)
    assert.is_nil(ns.db.bank.characters.Alt)
    assert.equal(1, ns.db.numCharacters)
  end)

  it("reports an unknown name", function()
    ns.commands.delete(ns, "Nobody")
    assert.equal(2, ns.db.numCharacters)
    assert.is_true(ns.printed[1]:find("not found", 1, true) ~= nil)
  end)
end)

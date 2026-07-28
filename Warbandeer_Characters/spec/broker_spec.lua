-- Per-character guards for broker.lua (issue #624): Broker:Reset / Broker:Update must
-- not nil-index a toon that has no data table for this broker yet. InitBrokers Init's
-- ONLY the current character, but the daily/weekly/Sunday reset loops iterate every
-- stored character — so an alt that predates a broker's addition (e.g. professionKnowledge,
-- #426) reaches Reset with `toon[<broker>]` still nil, and the raw index crashed login.
--
-- broker.lua isn't in wbchar.lua's pure-file harness: it reads GetServerTime / C_DateAndTime
-- and ns.lua.Class at load. So we stub those two WoW globals and borrow Class from
-- LibNAddOn's own spec harness, then loadfile broker.lua into a fresh namespace.

-- luacheck: globals GetServerTime C_DateAndTime

local libn = require("LibNAddOn.spec.libn")

-- Load broker.lua into a fresh ns (ns.Broker, ns.RESET_*, ns:RegisterBroker, ...).
-- libn.load() populates ns.lua.Class and sets _G.Mixin; broker.lua's file-scope
-- reset-anchor math is the only user of GetServerTime / C_DateAndTime, and the values
-- are irrelevant to the Reset/Update logic under test.
local function loadBroker()
  _G.GetServerTime = function() return 1700000000 end
  _G.C_DateAndTime = {
    GetSecondsUntilDailyReset = function() return 3600 end,
    GetSecondsUntilWeeklyReset = function() return 86400 end,
  }
  local ns = { lua = { Class = libn.load().lua.Class } }
  assert(loadfile("Warbandeer_Characters/broker.lua"))("Warbandeer_Characters", ns)
  return ns
end

describe("Warbandeer_Characters Broker per-character guards (#624)", function()
  local ns, broker, current

  before_each(function()
    ns = loadBroker()
    broker = ns.Broker:new{
      name = "professionKnowledge",
      fields = {
        weekly = {
          order = 1, resetOn = ns.RESET_WEEKLY,
          reset = function() return "fresh-weekly" end,
          get = function() return "got-weekly" end,
        },
        daily = {
          order = 2, resetOn = ns.RESET_DAILY,
          reset = function() return "fresh-daily" end,
          get = function() return "got-daily" end,
        },
      },
    }
    -- Init the "current" character, exactly as InitBrokers does for currentData only.
    -- This also builds broker.fieldOrder, which Reset/Update iterate.
    current = {}
    broker:Init(current)
  end)

  it("Reset skips an alt that has no data table for this broker (the #624 crash)", function()
    local alt = { name = "Shinsing" } -- never Init'd for this broker
    assert.has_no.errors(function() broker:Reset(ns.RESET_WEEKLY, alt) end)
    assert.is_nil(alt.professionKnowledge) -- the guard doesn't fabricate the table either
  end)

  it("Reset writes the reset value for fields whose resetOn matches the cadence", function()
    broker:Reset(ns.RESET_WEEKLY, current)
    assert.equal("fresh-weekly", current.professionKnowledge.weekly)
  end)

  it("Reset leaves fields of a different cadence untouched", function()
    current.professionKnowledge.daily = "old-daily"
    broker:Reset(ns.RESET_WEEKLY, current)
    assert.equal("fresh-weekly", current.professionKnowledge.weekly)
    assert.equal("old-daily", current.professionKnowledge.daily) -- daily cadence not reset
  end)

  it("mirrors InitBrokers: reset loop over mixed characters resets current, skips the un-Init'd alt", function()
    local alt = { name = "Shinsing" }
    assert.has_no.errors(function()
      for _, toon in pairs({ current, alt }) do
        broker:Reset(ns.RESET_WEEKLY, toon)
      end
    end)
    assert.equal("fresh-weekly", current.professionKnowledge.weekly)
    assert.is_nil(alt.professionKnowledge)
  end)

  it("Update skips an alt that has no data table for this broker (belt-and-suspenders)", function()
    local alt = { name = "Shinsing" }
    assert.has_no.errors(function() broker:Update(alt) end)
    assert.is_nil(alt.professionKnowledge)
  end)

  it("Update re-fetches every field via get for a character with a table", function()
    broker:Update(current)
    assert.equal("got-weekly", current.professionKnowledge.weekly)
    assert.equal("got-daily", current.professionKnowledge.daily)
  end)
end)

-- data/weekly.lua's `hasUnclaimedVault.reset` reads last week's `vault.best`, and `vault` declares
-- no reset so the default nils it — meaning the pair is only correct because neither declares an
-- `order` and "hasUnclaimedVault" sorts before "vault". That contract is load-bearing and invisible:
-- renaming either field, or giving one an `order`, would silently invert the reset sequence (#745-2).
describe("Warbandeer_Characters Broker field ordering", function()
  local ns

  before_each(function() ns = loadBroker() end)

  ---@return table fieldOrder
  local function orderFor(fields)
    local broker = ns.Broker:new{ name = "weeklies", fields = fields }
    broker:Init({})
    return broker.fieldOrder
  end

  local function noop() return nil end

  it("sorts order-less fields alphabetically, so a reset can depend on running before a sibling", function()
    local order = orderFor({
      vault = { get = noop },
      hasUnclaimedVault = { get = noop },
      keystone = { get = noop },
    })
    assert.equal("hasUnclaimedVault", order[1])
    assert.equal("keystone", order[2])
    assert.equal("vault", order[3])
  end)

  it("puts any field carrying an explicit order ahead of every order-less one", function()
    local order = orderFor({
      aardvark = { get = noop },
      vault = { order = 10, get = noop },
    })
    assert.equal("vault", order[1])
    assert.equal("aardvark", order[2])
  end)
end)

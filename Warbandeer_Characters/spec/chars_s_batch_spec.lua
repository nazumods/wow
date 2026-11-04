-- Regression specs for the Characters S bundle: banks that can't be viewed or haven't loaded must not
-- overwrite the cache (#1016, #1017), raid lockouts refresh and survive an empty early read (#1046), and a
-- session spanning a reset applies it in-session (#1107). Each file is loaded into a fresh ns with just the
-- globals it reads stubbed; stubbed globals are restored after each case.

-- luacheck: globals describe it before_each after_each
-- luacheck: globals C_Bank C_Container C_Item C_Timer C_DateAndTime Enum GetServerTime GetGuildInfo
-- luacheck: globals GetNumGuildBankTabs GetGuildBankTabInfo GetGuildBankItemLink GetGuildBankItemInfo
-- luacheck: globals QueryGuildBankTab GetCurrentGuildBankTab SetCurrentGuildBankTab ItemLocation
-- luacheck: globals GetNumSavedInstances GetSavedInstanceInfo RequestRaidInfo MAX_GUILDBANKFRAME_TABS

local libn = require("LibNAddOn.spec.libn")

local STUBBED = {
  "C_Bank", "C_Container", "C_Item", "C_Timer", "C_DateAndTime", "Enum", "GetServerTime", "GetGuildInfo",
  "GetNumGuildBankTabs", "GetGuildBankTabInfo", "GetGuildBankItemLink", "GetGuildBankItemInfo",
  "QueryGuildBankTab", "GetCurrentGuildBankTab", "SetCurrentGuildBankTab", "ItemLocation",
  "GetNumSavedInstances", "GetSavedInstanceInfo", "RequestRaidInfo",
}
local saved
local function saveGlobals()
  saved = {}
  for _, k in ipairs(STUBBED) do saved[k] = { _G[k] } end
end
local function restoreGlobals()
  for _, k in ipairs(STUBBED) do _G[k] = saved[k][1] end
end
local function noop() end

describe("bank scans keep the cache when they can't read the bank", function()
  local ns, canView, guildItems, stored

  before_each(function()
    saveGlobals()
    canView = { [1] = true, [2] = true }
    guildItems = {}
    stored = nil
    _G.GetServerTime = function() return 500 end
    _G.Enum = { BankType = { Character = 1, Account = 2 } }
    _G.C_Item = { GetCurrentItemLevel = noop, GetDetailedItemLevelInfo = noop, GetItemInfo = noop,
                  RequestLoadItemData = noop, GetItemQualityByID = noop }
    _G.C_Bank = { CanViewBank = function(t) return canView[t] end, FetchPurchasedBankTabIDs = function() return {} end }
    _G.C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerItemInfo = noop }
    _G.ItemLocation = { CreateFromBagAndSlot = function() return {} end }
    _G.GetGuildInfo = function() return "Guild" end
    _G.GetNumGuildBankTabs = function() return 1 end
    _G.GetGuildBankTabInfo = function() return "t", "i", true end
    _G.GetGuildBankItemLink = function(_, slot) return guildItems[slot] end
    _G.GetGuildBankItemInfo = function() return nil, 3, nil, nil, 1 end
    _G.QueryGuildBankTab = function() stored = (stored or 0) + 1 end
    _G.GetCurrentGuildBankTab = function() return 1 end
    _G.SetCurrentGuildBankTab = noop
    ns = { events = {}, currentPlayer = "Tester", api = { ClassifyProfGearItem = noop } }
    ns.registerEvent = function(_, ev, fn) ns.events[ev] = fn end
    ns.Supports = function() return true end
    ns.after = noop
    ns.registerDump, ns.RegisterMissing = noop, noop
    ns.db = { bank = {
      characters = { Tester = { scannedAt = 1, marker = "char" } },
      warband = { scannedAt = 1, marker = "wb" },
      guilds = { Guild = { scannedAt = 1, marker = "guild", gear = {}, items = { [9] = 1 } } },
    } }
    assert(loadfile("Warbandeer_Characters/data/bank.lua"))("Warbandeer_Characters", ns)
  end)

  after_each(restoreGlobals)

  it("a normal banker visit refreshes both personal banks (#1016)", function()
    ns.events.BANKFRAME_OPENED()
    assert.equal(500, ns.db.bank.characters.Tester.scannedAt)
    assert.equal(500, ns.db.bank.warband.scannedAt)
    -- a viewable (even empty) bank still overwrites the old record
    assert.is_nil(ns.db.bank.characters.Tester.marker)
    assert.is_nil(ns.db.bank.warband.marker)
  end)

  it("opening the warband bank at an account-only banker keeps the character bank (#1016)", function()
    canView[1] = false
    ns.events.BANKFRAME_OPENED()
    assert.equal("char", ns.db.bank.characters.Tester.marker)
    assert.equal(500, ns.db.bank.warband.scannedAt)
  end)

  it("opening the character bank at a character-only banker keeps the warband (#1016)", function()
    canView[2] = false
    ns.events.BANKFRAME_OPENED()
    assert.equal("wb", ns.db.bank.warband.marker)
    assert.equal(500, ns.db.bank.characters.Tester.scannedAt)
  end)

  it("the final capture on BANKFRAME_CLOSED keeps both when neither can be viewed (#1016)", function()
    ns.events.BANKFRAME_OPENED()
    canView[1], canView[2] = false, false
    ns.db.bank.characters.Tester.marker, ns.db.bank.warband.marker = "char", "wb"
    ns.events.BANKFRAME_CLOSED()
    assert.equal("char", ns.db.bank.characters.Tester.marker)
    assert.equal("wb", ns.db.bank.warband.marker)
  end)

  it("opening the guild bank only queries the tabs; the cache is untouched (#1017)", function()
    ns.events.GUILDBANKFRAME_OPENED()
    assert.equal(1, stored)
    assert.equal("guild", ns.db.bank.guilds.Guild.marker)
  end)

  it("a guild scan that finds no items keeps the stored record (#1017)", function()
    ns.events.GUILDBANKFRAME_OPENED()
    ns.events.GUILDBANKBAGSLOTS_CHANGED()
    assert.equal("guild", ns.db.bank.guilds.Guild.marker)
  end)

  it("a guild scan that finds items replaces the stored record (#1017)", function()
    ns.events.GUILDBANKFRAME_OPENED()
    guildItems[1] = "|cffffffff|Hitem:1234::::|h[Thing]|h|r"
    ns.events.GUILDBANKBAGSLOTS_CHANGED()
    assert.is_nil(ns.db.bank.guilds.Guild.marker)
    assert.equal(3, ns.db.bank.guilds.Guild.items[1234])
  end)

  it("a guild with no stored record still gets its first (even empty) scan (#1017)", function()
    ns.db.bank.guilds.Guild = nil
    ns.events.GUILDBANKFRAME_OPENED()
    ns.events.GUILDBANKBAGSLOTS_CHANGED()
    assert.is_table(ns.db.bank.guilds.Guild)
  end)
end)

describe("instances.locks (#1046)", function()
  local ns, field, numSaved, events

  before_each(function()
    saveGlobals()
    numSaved, events = 0, {}
    _G.GetServerTime = function() return 1000 end
    _G.GetNumSavedInstances = function() return numSaved end
    _G.GetSavedInstanceInfo = function()
      return "Raid", 1, 600, 16, true, false, nil, true, nil, nil, 8, 3, nil, 2657
    end
    _G.RequestRaidInfo = function() events.requested = (events.requested or 0) + 1 end
    local broker = {}
    ns = { RESET_WEEKLY = 7 }
    ns.RegisterBroker = function() return broker end
    ns.registerCommand, ns.registerDump = noop, noop
    ns.registerEvent = function(_, ev, fn) events[ev] = fn end
    assert(loadfile("Warbandeer_Characters/data/instances.lua"))("Warbandeer_Characters", ns)
    field = broker.fields.locks
  end)

  after_each(restoreGlobals)

  it("refreshes on UPDATE_INSTANCE_INFO as well as INSTANCE_LOCK_STOP", function()
    local set = {}
    for _, ev in ipairs(field.event) do set[ev] = true end
    assert.is_true(set.INSTANCE_LOCK_STOP)
    assert.is_true(set.UPDATE_INSTANCE_INFO)
  end)

  it("asks for fresh raid info on a boss kill", function()
    events.BOSS_KILL()
    assert.equal(1, events.requested)
  end)

  it("keeps the stored locks when instance info hasn't arrived yet", function()
    local current = { [2657] = { [16] = { progress = 2, reset = 2000 } } }
    assert.same(current, field:get(nil, current))
  end)

  it("drops a stored lock whose reset has passed on a zero read", function()
    local current = {
      [2657] = { [16] = { progress = 2, reset = 2000 } },  -- running
      [100]  = { [2] = { progress = 1, reset = 900 } },    -- expired dungeon lock
    }
    local out = field:get(nil, current)
    assert.is_table(out[2657])
    assert.is_nil(out[100])
  end)

  it("a zero read with only expired locks stores {}", function()
    assert.same({}, field:get(nil, { [100] = { [2] = { reset = 900 } } }))
  end)

  it("stores {} when nothing is locked and nothing was stored", function()
    assert.same({}, field:get(nil, nil))
    assert.same({}, field:get(nil, {}))
  end)

  it("reads the live locks (progress updates) when instances are saved", function()
    numSaved = 1
    local out = field:get(nil, { [2657] = { [16] = { progress = 1 } } })
    assert.equal(3, out[2657][16].progress)
    assert.equal(8, out[2657][16].total)
  end)
end)

describe("in-session reset (#1107)", function()
  local DAY = 24 * 60 * 60
  local WEEK = 7 * DAY
  local NOW = 1700000000
  local ns, now, untilDaily, untilWeekly, timers, resets, refreshes, requested

  before_each(function()
    saveGlobals()
    now, untilDaily, untilWeekly = NOW, 3600, 3 * DAY
    timers, resets, refreshes, requested = {}, {}, 0, 0
    _G.GetServerTime = function() return now end
    _G.C_DateAndTime = {
      GetSecondsUntilDailyReset = function() return untilDaily end,
      GetSecondsUntilWeeklyReset = function() return untilWeekly end,
    }
    _G.C_Timer = { After = function(delay, fn) timers[#timers + 1] = { delay = delay, fn = fn } end }
    _G.RequestRaidInfo = function() requested = requested + 1 end
    ns = { lua = { Class = libn.load().lua.Class } }
    assert(loadfile("Warbandeer_Characters/broker.lua"))("Warbandeer_Characters", ns)
    ns.brokers.counter = { Init = noop, Reset = function(_, cadence, toon)
      resets[#resets + 1] = cadence
      toon.reset = (toon.reset or 0) + 1
    end }
    ns.brokerOrder = { "counter" }
    ns.currentData = {}
    ns.refresh = function() refreshes = refreshes + 1 end
    ns.db = {
      characters = { a = {}, b = {} },
      lastDailyReset = ns.LAST_DAILY_RESET,
      lastReset = ns.LAST_RESET,
      lastSundayReset = ns.LAST_SUNDAY_RESET,
    }
  end)

  after_each(restoreGlobals)

  local function count(cadence)
    local n = 0
    for _, c in ipairs(resets) do if c == cadence then n = n + 1 end end
    return n
  end

  it("login arms one timer for just after the nearest boundary and applies nothing early", function()
    ns:InitBrokers()
    assert.equal(0, #resets)
    assert.equal(1, #timers)
    assert.equal(3600 + 5, timers[1].delay)
  end)

  it("crossing the weekly reset mid-session resets every character once and stamps the new anchor", function()
    ns:InitBrokers()
    local oldAnchor = ns.db.lastReset
    now, untilDaily, untilWeekly = NOW + 3 * DAY + 10, DAY - 10, WEEK - 10
    timers[1].fn()
    assert.equal(2, count(ns.RESET_WEEKLY)) -- one pass over each of the two characters
    assert.equal(NOW + 3 * DAY, ns.db.lastReset)
    assert.is_true(ns.db.lastReset > oldAnchor)
    assert.equal(ns.db.lastReset, ns.LAST_RESET)
    assert.equal(1, refreshes)
  end)

  it("asks for fresh raid info before refreshing when a reset applies (#1046)", function()
    ns:InitBrokers()
    now, untilDaily, untilWeekly = NOW + 3 * DAY + 10, DAY - 10, WEEK - 10
    timers[1].fn()
    assert.equal(1, requested)
  end)

  it("a daily and weekly boundary crossed together resets each once per character with one refresh", function()
    ns:InitBrokers()
    now, untilDaily, untilWeekly = NOW + 3 * DAY + 10, DAY - 10, WEEK - 10
    timers[1].fn()
    assert.equal(2, count(ns.RESET_DAILY))
    assert.equal(2, count(ns.RESET_WEEKLY))
    assert.equal(1, refreshes)
  end)

  it("a character with no data table for a broker is skipped, not indexed (#624 guard)", function()
    local real = ns:RegisterBroker("real")
    real.fields = { x = { resetOn = ns.RESET_WEEKLY, get = noop } }
    ns.brokerOrder = { "real" }
    ns.db.characters = { a = { real = { x = 5 } }, b = {} }
    ns.currentData = ns.db.characters.a
    ns:InitBrokers()
    now, untilDaily, untilWeekly = NOW + 3 * DAY + 10, DAY - 10, WEEK - 10
    assert.has_no.errors(function() timers[1].fn() end)
    assert.is_nil(ns.db.characters.a.real.x)
    assert.is_nil(ns.db.characters.b.real)
  end)

  it("does not reset a second time on the next login the same week", function()
    ns:InitBrokers()
    now, untilDaily, untilWeekly = NOW + 3 * DAY + 10, DAY - 10, WEEK - 10
    timers[1].fn()
    local before = #resets
    ns:ApplyResets()
    assert.equal(before, #resets)
  end)

  it("re-arms the timer after firing, and a timer that fires with no boundary crossed does nothing", function()
    ns:InitBrokers()
    now, untilDaily = NOW + 10, 3590
    timers[1].fn()
    assert.equal(0, #resets)
    assert.equal(0, refreshes)
    assert.equal(2, #timers)
  end)

  it("a timer superseded by a newer ScheduleResets is a no-op", function()
    ns:InitBrokers()
    ns:ScheduleResets()
    now, untilDaily, untilWeekly = NOW + 3 * DAY + 10, DAY - 10, WEEK - 10
    timers[1].fn()
    assert.equal(0, #resets)
    timers[2].fn()
    assert.equal(2, count(ns.RESET_WEEKLY)) -- once, over both characters
  end)
end)

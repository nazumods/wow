-- Regression specs for the Characters low-severity bundle (#1040, #1051): mail count/expiry, the /played chat
-- mute, empty early reads that must not wipe stored data, the titles unit filter and housing pruning. Files
-- are loaded into a fresh ns whose unknown methods are no-ops; stubbed globals are restored after each case.

-- luacheck: globals describe it before_each after_each
-- luacheck: globals GetInboxNumItems GetInboxHeaderInfo GetInboxItem GetServerTime HasNewMail NUM_CHAT_WINDOWS
-- luacheck: globals ChatFrame1 ChatFrame2 C_Timer RequestTimePlayed GetBuildInfo C_QuestLog C_Reputation bit
-- luacheck: globals C_GossipInfo C_MajorFactions GetTime GetNumTitles IsTitleKnown GetTitleName GetCurrentTitle strtrim
-- luacheck: globals ITEM_ARTIFACT_COLOR ITEM_LEGENDARY_COLOR ITEM_EPIC_COLOR ITEM_SUPERIOR_COLOR ITEM_GOOD_COLOR ITEM_STANDARD_COLOR ITEM_POOR_COLOR

local STUBBED = {
  "GetInboxNumItems", "GetInboxHeaderInfo", "GetInboxItem", "GetServerTime", "HasNewMail", "NUM_CHAT_WINDOWS",
  "ChatFrame1", "ChatFrame2", "C_Timer", "RequestTimePlayed", "GetBuildInfo", "C_QuestLog", "C_Reputation", "bit",
  "C_GossipInfo", "C_MajorFactions", "GetTime", "GetNumTitles", "IsTitleKnown", "GetTitleName", "GetCurrentTitle",
  "strtrim",
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

---A namespace whose unknown methods are no-ops, with broker registration returning a fresh table.
local function newNs()
  local ns = setmetatable({ events = {}, db = { characters = {} } }, { __index = function() return noop end })
  ns.RegisterBroker = function() return {} end
  ns.registerEvent = function(_, ev, fn) ns.events[ev] = fn end
  ns.Supports = function() return true end
  return ns
end

local function load(file, ns)
  assert(loadfile("Warbandeer_Characters/" .. file))("Warbandeer_Characters", ns)
end

describe("mail (#1040)", function()
  local ns, headers

  before_each(function()
    saveGlobals()
    headers = {}
    _G.GetServerTime = function() return 1000000 end
    _G.GetInboxNumItems = function() return #headers, 73 end -- 50-cap view of a larger inbox
    _G.GetInboxHeaderInfo = function(i) return nil, nil, nil, nil, 0, nil, headers[i], 0 end
    _G.GetInboxItem = noop
    _G.HasNewMail = function() return false end
    ns = newNs()
    ns.currentData = {}
    load("data/mail.lua", ns)
  end)

  after_each(restoreGlobals)

  it("counts the inbox total, not just the shown mail", function()
    headers = { 5, 6 }
    ns.events.MAIL_INBOX_UPDATE()
    assert.equal(73, ns.currentData.mail.count)
    assert.equal(2, #ns.currentData.mail.expiries)
  end)

  it("warns on the first expiry still in the future, not an already-expired one", function()
    local printed
    ns.Print = function(msg) printed = msg end
    ns.db.characters = { Old = { mail = { expiries = { 999000 } } } }
    ns:WarnExpiringMail()
    assert.is_nil(printed) -- only expired mail

    ns.db.characters = { Mixed = { mail = { expiries = { 999000, 1000000 + 86400 } } } }
    ns:WarnExpiringMail()
    assert.is_true(printed:find("Mixed %(1d%)") ~= nil)
  end)
end)

describe("playtime /played mute (#1040)", function()
  local ns, frames, requested, timers, broker

  local function makeFrame()
    local f = { registered = true }
    function f:IsEventRegistered() return self.registered end
    function f:UnregisterEvent() self.registered = false end
    function f:RegisterEvent() self.registered = true end
    return f
  end

  before_each(function()
    saveGlobals()
    frames, requested, timers = { makeFrame(), makeFrame() }, 0, {}
    _G.NUM_CHAT_WINDOWS = 2
    _G.ChatFrame1, _G.ChatFrame2 = frames[1], frames[2]
    _G.C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end, NewTicker = noop }
    _G.RequestTimePlayed = function() requested = requested + 1 end
    _G.GetBuildInfo = function() return "12.0.0" end
    _G.GetServerTime = function() return 1000 end
    ns = newNs()
    ns.RegisterBroker = function() broker = { Init = function(_, toon) toon.playtime = {} end }; return broker end
    load("data/playtime.lua", ns)
  end)

  after_each(restoreGlobals)

  it("drops TIME_PLAYED_MSG on the chat frames around the login query and restores it on the answer", function()
    broker:Init({})
    assert.equal(1, requested)
    assert.is_false(frames[1].registered)
    assert.is_false(frames[2].registered)
    ns.events.TIME_PLAYED_MSG(nil, 12345)
    assert.is_true(frames[1].registered)
    assert.is_true(frames[2].registered)
  end)

  it("restores the chat frames on the safety timeout if the answer never comes", function()
    broker:Init({})
    for _, fn in ipairs(timers) do fn() end
    assert.is_true(frames[1].registered)
  end)

  it("does not re-register a frame that never listened", function()
    frames[2].registered = false
    broker:Init({})
    ns.events.TIME_PLAYED_MSG(nil, 1)
    assert.is_false(frames[2].registered)
  end)
end)

describe("empty early reads keep stored data (#1040)", function()
  before_each(saveGlobals)
  after_each(restoreGlobals)

  it("questlog.completed keeps the stored bitmap when the read is empty", function()
    _G.bit = { bor = function(a, b) return (a or 0) + b end, band = noop, lshift = function(_, n) return n end }
    _G.C_QuestLog = { GetAllCompletedQuestIDs = function() return {} end }
    local broker = {}
    local ns = newNs()
    ns.RegisterBroker = function() return broker end
    load("data/questlog.lua", ns)
    local stored = { [1] = 7 }
    assert.equal(stored, broker.fields.completed:get(nil, stored))
    assert.same({}, broker.fields.completed:get(nil, nil))
  end)

  it("questlog.completed replaces the stored bitmap with a non-empty read", function()
    _G.bit = { bor = function(a, b) return (a or 0) + b end, band = noop, lshift = function(_, n) return n end }
    _G.C_QuestLog = { GetAllCompletedQuestIDs = function() return { 33 } end }
    local broker = {}
    local ns = newNs()
    ns.RegisterBroker = function() return broker end
    load("data/questlog.lua", ns)
    local stored = { [1] = 7 }
    assert.is_true(broker.fields.completed:get(nil, stored) ~= stored)
  end)

  it("reputations.factions keeps the stored standings when the faction list reads empty", function()
    _G.GetTime = function() return 0 end
    _G.C_Reputation = {
      IsMajorFaction = noop, IsFactionParagon = noop, GetFactionParagonInfo = noop,
      GetNumFactions = function() return 0 end, GetFactionDataByIndex = noop,
    }
    _G.C_GossipInfo = { GetFriendshipReputation = noop, GetFriendshipReputationRanks = noop }
    _G.C_MajorFactions = {}
    local broker = {}
    local ns = newNs()
    ns.RegisterBroker = function() return broker end
    load("data/reputations.lua", ns)
    local stored = { [2] = { standing = 1 } }
    assert.equal(stored, broker.fields.factions:get(nil, stored))
    assert.same({}, broker.fields.factions:get(nil, nil))
  end)
end)

describe("titles unit filter (#1051)", function()
  before_each(saveGlobals)
  after_each(restoreGlobals)

  it("lets the player's own name update and title events through, drops other units", function()
    _G.GetNumTitles, _G.IsTitleKnown, _G.GetTitleName = function() return 0 end, noop, noop
    _G.GetCurrentTitle, _G.strtrim = function() return 0 end, function(s) return s end
    local broker = {}
    local ns = newNs()
    ns.RegisterBroker = function() return broker end
    load("data/titles.lua", ns)
    for _, name in ipairs({ "current", "currentName" }) do
      local f = broker.fields[name]
      assert.is_true(f:eventFilter(nil, "player"))
      assert.is_true(f:eventFilter(nil, nil))   -- KNOWN_TITLES_UPDATE carries no unit
      assert.is_false(f:eventFilter(nil, "party1"))
      assert.is_false(f:eventFilter(nil, "nameplate3"))
    end
  end)
end)

describe("housing list pruning (#1051)", function()
  local function setup(acct)
    local ns = newNs()
    ns.db.housing = acct
    load("data/housing.lua", ns)
    return ns
  end

  it("drops a relinquished house of the same faction and keeps level/favor for the listed one", function()
    local acct = {
      houses = {
        old = { name = "Gone", level = 5, favor = 9, neighborhoodGUID = "n1" },
        cur = { name = "Home", level = 3, favor = 4, neighborhoodGUID = "n2" },
      },
      neighborhoods = { n1 = { isAlliance = true }, n2 = { isAlliance = true } },
    }
    local ns = setup(acct)
    ns.events.PLAYER_HOUSE_LIST_UPDATED(nil, { { houseGUID = "cur", houseName = "Home2", neighborhoodGUID = "n2" } })
    assert.is_nil(acct.houses.old)
    assert.equal(3, acct.houses.cur.level)
    assert.equal(4, acct.houses.cur.favor)
    assert.equal("Home2", acct.houses.cur.name)
  end)

  it("a list with an Alliance house does not remove a stored Horde house", function()
    local acct = {
      houses = {
        horde = { name = "Orgrimmar home", level = 7, neighborhoodGUID = "nh" },
        old   = { name = "Gone", neighborhoodGUID = "na0" },
      },
      neighborhoods = { nh = { isAlliance = false }, na0 = { isAlliance = true }, na = { isAlliance = true } },
    }
    local ns = setup(acct)
    ns.events.PLAYER_HOUSE_LIST_UPDATED(nil, { { houseGUID = "ally", houseName = "Stormwind home", neighborhoodGUID = "na" } })
    assert.equal(7, acct.houses.horde.level)
    assert.is_nil(acct.houses.old)
    assert.is_table(acct.houses.ally)
  end)

  it("keeps a stored house whose faction is unknown", function()
    local acct = {
      houses = { mystery = { neighborhoodGUID = "nx" } },
      neighborhoods = { na = { isAlliance = true } },
    }
    local ns = setup(acct)
    ns.events.PLAYER_HOUSE_LIST_UPDATED(nil, { { houseGUID = "ally", neighborhoodGUID = "na" } })
    assert.is_table(acct.houses.mystery)
  end)

  it("ignores an empty list rather than wiping every house", function()
    local acct = { houses = { cur = { level = 3, neighborhoodGUID = "n" } }, neighborhoods = { n = { isAlliance = true } } }
    local ns = setup(acct)
    ns.events.PLAYER_HOUSE_LIST_UPDATED(nil, {})
    assert.equal(3, acct.houses.cur.level)
  end)
end)

describe("Summary ilvl tooltip (#1040)", function()
  local COLORS = { "ITEM_ARTIFACT_COLOR", "ITEM_LEGENDARY_COLOR", "ITEM_EPIC_COLOR", "ITEM_SUPERIOR_COLOR",
                   "ITEM_GOOD_COLOR", "ITEM_STANDARD_COLOR", "ITEM_POOR_COLOR" }
  local savedColors

  before_each(function()
    savedColors = {}
    for _, k in ipairs(COLORS) do
      savedColors[k] = { _G[k] }
      _G[k] = { WrapTextInColorCode = function(_, text) return "<" .. tostring(text) .. ">" end }
    end
  end)

  after_each(function()
    for _, k in ipairs(COLORS) do _G[k] = savedColors[k][1] end
  end)

  it("shows ? for a slot with no ilvl instead of crashing or printing a grey 0", function()
    local ns = newNs()
    assert(loadfile("Warbandeer/data.lua"))("Warbandeer", ns)
    local lines = ns.IlvlTooltipLines({ equipment = { slots = { Head = { ilvl = 300 }, Neck = {} } } })
    assert.same({ "Head <300>", "Neck ?" }, lines)
  end)
end)

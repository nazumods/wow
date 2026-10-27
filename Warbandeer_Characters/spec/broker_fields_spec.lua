-- Behaviour of two broker fields that read WoW globals at load, so they can't use wbchar.lua's
-- pure-file harness: weeklies.DMF's live turn-in capture (#1109) and basic.specialization's
-- played-vs-loot spec rule (#1110). Each file is loaded into a fresh ns with just the globals
-- it upvalues stubbed; field handlers are then driven directly.

-- luacheck: globals C_QuestLog C_WeeklyRewards C_MythicPlus GetSpecializationRoleByID GetServerTime C_Bank gsub

local libn = require("LibNAddOn.spec.libn")

describe("weeklies.DMF live capture (#1109)", function()
  local field, stored

  before_each(function()
    _G.C_QuestLog = { IsQuestFlaggedCompleted = function() return false end }
    _G.C_WeeklyRewards = {}
    _G.C_MythicPlus = {}
    local weekly = {}
    local ns = { lua = libn.load().lua, wow = { Player = {} } }
    ns.RegisterBroker = function() return weekly end
    ns.Supports = function() return true end
    ns.registerDump = function() end
    assert(loadfile("Warbandeer_Characters/data/weekly.lua"))("Warbandeer_Characters", ns)
    field = weekly.fields.DMF
    stored = nil
    field.set = function(_, v) stored = v end
  end)

  it("sets DMF when a DMF quest is turned in", function()
    field:eventHandler(nil, 29506) -- Alchemy
    assert.is_true(stored)
  end)

  it("recognises every DMF profession quest", function()
    for _, id in ipairs({ 29508, 29509, 29510, 29511, 29513, 29514, 29515, 29516, 29517, 29518, 29519, 29520 }) do
      stored = nil
      field:eventHandler(nil, id)
      assert.is_true(stored, "quest " .. id)
    end
  end)

  it("ignores an unrelated quest", function()
    field:eventHandler(nil, 12345)
    assert.is_nil(stored)
  end)
end)

describe("basic.specialization keeps the played spec (#1110)", function()
  local field, player

  before_each(function()
    _G.GetSpecializationRoleByID = function(id) return "ROLE" .. id end
    _G.GetServerTime = function() return 0 end
    _G.gsub = string.gsub
    _G.C_Bank = { HasMaxBankTabs = function() end, FetchNumPurchasedBankTabs = function() end }
    player = {
      GetPrimarySpecialization = function() return 72, "Fury" end,
      GetActiveSpecialization = function() return nil end,
    }
    local basic = {}
    local ns = { lua = libn.load().lua, wow = { Player = player } }
    ns.RegisterBroker = function() return basic end
    ns.registerDump = function() end
    assert(loadfile("Warbandeer_Characters/data/basic.lua"))("Warbandeer_Characters", ns)
    field = basic.fields.specialization
  end)

  it("keeps the stored value when no active spec is available yet", function()
    local current = { id = 71, key = "Arms" }
    assert.equal(current, field:get(nil, current))
  end)

  it("stays nil rather than storing the loot spec when nothing is stored", function()
    assert.is_nil(field:get(nil, nil))
  end)

  it("stores the played spec, not the loot spec, when both are present", function()
    player.GetActiveSpecialization = function() return 73, "Protection" end
    local r = field:get(nil, nil)
    assert.equal(73, r.id)
    assert.equal("Protection", r.key)
    assert.equal("ROLE73", r.role)
    assert.equal("Fury", r.primary)
  end)
end)

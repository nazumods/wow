-- Regression specs for the Characters XS bundle: foreign/raced trade-skill capture (#1042, #1045),
-- the stable-only pet scan (#1043) and the mid-session currency refresh (#1048). Files that read WoW
-- globals at load are loaded into a fresh ns with just those globals stubbed.

-- luacheck: globals C_TradeSkillUI C_Timer C_StableInfo C_CurrencyInfo GetMoney GetServerTime date

-- Globals each describe stubs; saved before and restored after so other specs in the same run are unaffected.
local STUBBED = { "C_TradeSkillUI", "C_Timer", "C_StableInfo", "C_CurrencyInfo", "GetMoney", "GetServerTime", "date" }
local saved
local function saveGlobals()
  saved = {}
  for _, k in ipairs(STUBBED) do saved[k] = { _G[k] } end
end
local function restoreGlobals()
  for _, k in ipairs(STUBBED) do _G[k] = saved[k][1] end
end

describe("professions TRADE_SKILL_SHOW capture", function()
  local field, stored, open, foreign, timers

  before_each(function()
    saveGlobals()
    timers = {}
    open, foreign, stored = { professionID = 100 }, {}, nil
    _G.C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
    _G.C_TradeSkillUI = {
      GetBaseProfessionInfo = function() return open end,
      GetChildProfessionInfos = function() return {} end,
      GetAllRecipeIDs = function() return {} end,
      IsTradeSkillLinked = function() return foreign.linked end,
      IsTradeSkillGuild = function() return foreign.guild end,
      IsNPCCrafting = function() return foreign.npc end,
      -- IsRuneforging deliberately absent: a flavor may lack a predicate
    }
    local broker = {}
    local ns = { api = {}, flavor = {} }
    ns.RegisterBroker = function() return broker end
    assert(loadfile("Warbandeer_Characters/data/professions.lua"))("Warbandeer_Characters", ns)
    field = broker.fields.details
    field.set = function(_, v) stored = v end
    field.get_live = function() return {} end
  end)

  after_each(restoreGlobals)

  local function fire()
    field:eventHandler({})
    for _, fn in ipairs(timers) do fn() end
  end

  it("captures the player's own profession", function()
    fire()
    assert.is_table(stored and stored[100])
    assert.is_nil(stored[100].expansions) -- empty children/recipes: nothing invented
    assert.is_nil(stored[100].recipes)
  end)

  it("tolerates C_TradeSkillUI being absent", function()
    _G.C_TradeSkillUI = nil
    assert.has_no.errors(function() field:eventHandler({}) end)
    assert.is_nil(stored)
  end)

  for _, kind in ipairs({ "linked", "guild", "npc" }) do
    it("ignores a " .. kind .. " profession view (#1042)", function()
      foreign[kind] = true
      fire()
      assert.is_nil(stored)
    end)
  end

  it("ignores a view that turns foreign during the delay (#1042)", function()
    field:eventHandler({})
    foreign.linked = true
    for _, fn in ipairs(timers) do fn() end
    assert.is_nil(stored)
  end)

  it("drops the scan when another profession is open when the timer fires (#1045)", function()
    field:eventHandler({})
    open = { professionID = 200 }
    for _, fn in ipairs(timers) do fn() end
    assert.is_nil(stored)
  end)
end)

describe("pets stable scan (#1043)", function()
  local handlers, toon, active, stable

  before_each(function()
    saveGlobals()
    handlers = {}
    active, stable = { { name = "A" } }, { { name = "S" } }
    toon = { classId = 3, pets = { scannedAt = 1, active = { { name = "old" } }, stable = { { name = "oldS" } } } }
    _G.C_StableInfo = {
      GetActivePetList = function() return active end,
      GetStabledPetList = function() return stable end,
    }
    _G.GetServerTime = function() return 99 end
    _G.date = function() return "" end
    local ns = { currentData = toon, registerDump = function() end, RegisterMissing = function() end }
    ns.registerEvent = function(_, ev, fn) handlers[ev] = fn end
    assert(loadfile("Warbandeer_Characters/data/pets.lua"))("Warbandeer_Characters", ns)
  end)

  after_each(restoreGlobals)

  it("keeps the stored stable when PET_STABLE_UPDATE fires away from a stable master", function()
    active, stable = {}, {}
    handlers.PET_STABLE_UPDATE()
    assert.equal("oldS", toon.pets.stable[1].name)
    assert.equal(1, toon.pets.scannedAt)
  end)

  it("keeps the stored lists even with pets in the API when no stable is open", function()
    handlers.PET_STABLE_UPDATE()
    assert.equal("oldS", toon.pets.stable[1].name)
  end)

  it("refreshes both lists during a stable visit", function()
    handlers.PET_STABLE_SHOW()
    assert.equal("S", toon.pets.stable[1].name)
    assert.equal("A", toon.pets.active[1].name)
    stable = { { name = "S2" } }
    handlers.PET_STABLE_UPDATE()
    assert.equal("S2", toon.pets.stable[1].name)
  end)

  it("skips an all-empty read while the stable is open", function()
    handlers.PET_STABLE_SHOW()
    active, stable = {}, {}
    handlers.PET_STABLE_UPDATE()
    assert.equal("S", toon.pets.stable[1].name)
  end)

  it("stops scanning once the stable closes", function()
    handlers.PET_STABLE_SHOW()
    handlers.PET_STABLE_CLOSED()
    stable = { { name = "after" } }
    handlers.PET_STABLE_UPDATE()
    assert.equal("S", toon.pets.stable[1].name)
  end)
end)

describe("currency mid-session refresh (#1048)", function()
  local fields

  before_each(function()
    saveGlobals()
    _G.C_CurrencyInfo = { GetCurrencyInfo = function() return nil end }
    _G.GetMoney = function() return 0 end
    local broker = {}
    local ns = { RESET_WEEKLY = "weekly" }
    ns.RegisterBroker = function() return broker end
    ns.Supports = function() return true end
    assert(loadfile("Warbandeer_Characters/data/currency.lua"))("Warbandeer_Characters", ns)
    fields = broker.fields
  end)

  after_each(restoreGlobals)

  for _, name in ipairs({ "HeroDawncrest", "MythDawncrest", "UntaintedManaCrystal", "CofferKeyShard",
                          "RestoredCofferKey", "FieldAccolade", "UnalloyedAbundance" }) do
    it(name .. " refreshes on its own CURRENCY_DISPLAY_UPDATE", function()
      local f = fields[name]
      assert.equal("CURRENCY_DISPLAY_UPDATE", f.event)
      assert.is_true(f:eventFilter("CURRENCY_DISPLAY_UPDATE", f.id))
      assert.is_false(f:eventFilter("CURRENCY_DISPLAY_UPDATE", f.id + 1))
    end)
  end
end)

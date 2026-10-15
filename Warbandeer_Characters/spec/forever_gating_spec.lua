-- Warbandeer_Characters on Forever: the data files for systems Forever lacks gate themselves off, behind the
-- feature table (`ns:Supports`), not behind an API-existence probe (Forever has the C_* tables, empty). Each
-- file is loaded against a stub namespace whose `Supports` answers per feature: the Forever case must register
-- nothing (no broker, event, dump or command); the Retail case must register as before. Deleting a gate, or
-- inverting it, fails the case named for it (nazumods/wow#957).
-- luacheck: globals describe it before_each after_each

local GLOBALS = {
  "GetServerTime", "GetTime", "C_QuestLog", "C_WeeklyRewards", "C_MythicPlus", "C_Item", "C_Bank", "C_Container",
  "C_SpellBook", "C_Spell", "C_SpecializationInfo", "C_Reputation", "C_MajorFactions", "C_GossipInfo", "Enum",
  "GetFlyoutInfo", "GetFlyoutSlotInfo", "ItemLocation", "strtrim", "geterrorhandler",
}

describe("Warbandeer_Characters on Forever", function()
  local saved
  local ns, unsupported
  local clock   -- what the stubbed GetTime reads (reputations.lua upvalues GetTime at load, so it must read a variable)

  local function noop() end

  -- Everything the data files read at LOAD time (the rest is read inside functions these cases don't call).
  local function stubGlobals()
    _G.GetServerTime = function() return 1000 end
    _G.GetTime = function() return clock end
    _G.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
    _G.C_QuestLog = { IsQuestFlaggedCompleted = function() return false end,
                      IsQuestFlaggedCompletedOnAccount = function() return false end }
    _G.C_WeeklyRewards = { GetActivities = function() return {} end, HasAvailableRewards = function() return false end }
    _G.C_MythicPlus = { GetOwnedKeystoneLevel = noop, GetOwnedKeystoneChallengeMapID = noop }
    _G.C_Item = { GetCurrentItemLevel = noop, GetDetailedItemLevelInfo = noop, GetItemInfo = noop,
                  RequestLoadItemData = noop, GetItemNameByID = noop }
    _G.C_Bank = { CanViewBank = noop, FetchPurchasedBankTabIDs = function() return {} end }
    _G.C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerItemInfo = noop }
    _G.C_SpellBook = { IsSpellKnown = function(id) return id == 555 end, GetNumSpellBookSkillLines = function() return 1 end }
    _G.C_Spell = {}
    _G.C_SpecializationInfo = {
      GetSpecialization = function() return 1 end,
      GetSpecializationInfo = function() return 1482, "Mage" end,
    }
    _G.Enum = { BankType = { Character = 1, Account = 2 }, SpellBookSpellBank = { Player = 0 },
                SpellBookItemType = { Flyout = 3 } }
    _G.GetFlyoutInfo, _G.GetFlyoutSlotInfo = noop, noop
    _G.ItemLocation = { CreateFromBagAndSlot = function() return {} end }
    _G.C_Reputation = {
      ExpandAllFactionHeaders = noop, GetNumFactions = function() return 0 end, GetFactionDataByIndex = noop,
      IsMajorFaction = function() return false end, IsFactionParagon = function() return false end,
      GetFactionParagonInfo = noop,
    }
    _G.C_MajorFactions = { GetMajorFactionData = noop, HasMaximumRenown = function() return false end }
    _G.C_GossipInfo = { GetFriendshipReputation = noop, GetFriendshipReputationRanks = noop }
  end

  before_each(function()
    saved = {}
    for _, name in ipairs(GLOBALS) do saved[name] = _G[name]; _G[name] = nil end
    clock = 100
    stubGlobals()
    unsupported = {}
    ns = {
      brokers = {}, events = {}, dumps = {}, dumpFns = {}, commands = {}, debounced = {}, asked = {},
      db = { characters = {} },
      currentPlayer = "Tester",
      currentData = { name = "Tester", basic = { level = 80 }, classId = 8, classKey = "Mage", race = "Human", isAlliance = true },
      RESET_SUNDAY = 0, RESET_DAILY = 1, RESET_WEEKLY = 7,
      wow = { maxLevel = 80, Player = { GetMaxXP = function() return 0 end } },
      api = { ClassifyGearItem = noop, ClassifyProfGearItem = noop },
      lua = {
        sets = { Set = function(list) local s = {}; for _, v in ipairs(list) do s[v] = true end; return s end },
        lists = { values = function(map) local s = {}; for _, v in pairs(map) do s[v] = true end; return s end },
        maps = { any = function(map, fn) for _, v in pairs(map) do if fn(v) then return true end end return false end,
                 map = function(map, fn) local out = {}; for k, v in pairs(map) do out[k] = fn(v) end return out end },
      },
    }
    function ns.Supports(_, feature)
      ns.asked[#ns.asked + 1] = feature
      return not unsupported[feature]
    end
    function ns.RegisterBroker(_, name) local b = { name = name }; ns.brokers[name] = b; return b end
    function ns.registerEvent(_, event, fn) ns.events[#ns.events + 1] = event; ns.events[event] = fn end
    function ns.registerDump(_, name, _, _, fn) ns.dumps[#ns.dumps + 1] = name; ns.dumpFns[name] = fn end
    function ns.registerCommand(_, verb, name) ns.commands[#ns.commands + 1] = verb .. " " .. name end
    function ns.RegisterMissing() end
    function ns.debounce(_, key, ms, fn) ns.debounced[#ns.debounced + 1] = { key = key, ms = ms, fn = fn } end
    ns.LearnedUnlocks = { [8] = { { spell = 555, label = "x" } } }
    ns.LearnedUnlockTitle = {}
    ns.AppearanceGlyphs, ns.AppearanceUnlocks = {}, {}
  end)

  after_each(function()
    for _, name in ipairs(GLOBALS) do _G[name] = saved[name] end
  end)

  local function load(file)
    assert(loadfile("Warbandeer_Characters/" .. file))("Warbandeer_Characters", ns)
  end

  local function count(t) local n = 0; for _ in pairs(t) do n = n + 1 end return n end
  local function noBrokers() return count(ns.brokers) == 0 end

  describe("D1 file-level gates register nothing where the feature is unsupported", function()
    local CASES = {
      { file = "data/housing.lua", feature = "housing", broker = "housing", events = 2, dump = "housing" },
      { file = "data/artifacts.lua", feature = "legion", broker = "artifacts", dump = "artifact" },
    }
    for _, c in ipairs(CASES) do
      it("Forever: " .. c.file .. " registers no broker, no events, no dump", function()
        unsupported[c.feature] = true
        load(c.file)
        assert.is_true(noBrokers())
        assert.same({}, ns.events)
        assert.same({}, ns.dumps)
        assert.same({ c.feature }, ns.asked)
      end)

      it("Retail: " .. c.file .. " registers its broker and dump", function()
        load(c.file)
        assert.is_not_nil(ns.brokers[c.broker])
        assert.same({ c.dump }, ns.dumps)
        assert.is_true(#ns.events >= (c.events or 1) or c.events == nil)
      end)
    end

    it("Forever: data/housinginfo.lua exports no shapers", function()
      unsupported.housing = true
      load("data/housinginfo.lua")
      assert.is_nil(ns.ShapeHousing)
      assert.is_nil(ns.ShapeHouses)
    end)

    it("Retail: data/housinginfo.lua exports the shapers", function()
      load("data/housinginfo.lua")
      assert.is_function(ns.ShapeHousing)
      assert.is_function(ns.ShapeHouses)
    end)

    it("Forever: data/travelerslog.lua defines no ns:InitTravelersLog and registers no dump", function()
      unsupported.travelersLog = true
      load("data/travelerslog.lua")
      assert.is_nil(ns.InitTravelersLog)
      assert.same({}, ns.dumps)
    end)

    it("Retail: data/travelerslog.lua defines ns:InitTravelersLog and its dump", function()
      load("data/travelerslog.lua")
      assert.is_function(ns.InitTravelersLog)
      assert.same({ "travelerslog" }, ns.dumps)
    end)

    it("Forever: data/delvetimes.lua registers no events, dump or command but keeps the shared helpers", function()
      unsupported.delves = true
      load("data/delvetimes.lua")
      assert.same({}, ns.events)
      assert.same({}, ns.dumps)
      assert.same({}, ns.commands)
      -- data/dungeontimes.lua and api.lua call these on every client
      assert.equals("earthcrawl mines", ns.NormalizeDelveKey("The Earthcrawl Mines"))
      assert.is_function(ns.StartRunXP)
      assert.is_function(ns.FinishRunXP)
    end)

    it("Retail: data/delvetimes.lua registers its events, dump and command", function()
      load("data/delvetimes.lua")
      assert.same({ "PLAYER_ENTERING_WORLD", "SCENARIO_UPDATE", "SCENARIO_COMPLETED" },
        { ns.events[1], ns.events[2], ns.events[3] })
      assert.same({ "delves" }, ns.dumps)
      assert.same({ "clear delves" }, ns.commands)
    end)
  end)

  describe("D2 Legion tables are empty, not absent, where legion is unsupported", function()
    it("Forever: ns.ClassMounts is an empty table", function()
      unsupported.legion = true
      load("data/classmounts.lua")
      assert.same({}, ns.ClassMounts)
    end)

    it("Retail: ns.ClassMounts is populated", function()
      load("data/classmounts.lua")
      assert.is_true(#ns.ClassMounts[1] > 0)
    end)

    it("Forever: the Legion achievement section is empty, the other sections intact", function()
      unsupported.legion = true
      load("data/achievementcatalog.lua")
      assert.same({}, ns.AchievementCatalog.legion)
      assert.is_true(#ns.AchievementCatalog.milestones > 0)
      assert.is_true(#ns.AchievementCatalog.checklist.midnight > 0)
    end)

    it("Retail: the Legion achievement section is populated", function()
      load("data/achievementcatalog.lua")
      assert.same({ 10459, 11160, 11163 }, ns.AchievementCatalog.legion)
    end)
  end)

  describe("D3 weekly: the fields of a missing system are dropped", function()
    local function fieldNames()
      load("data/weekly.lua")
      local names = {}
      for name in pairs(ns.brokers.weeklies.fields) do names[name] = true end
      return names
    end

    it("Forever (all unsupported): vault, delves and Mythic+ fields are absent, quest-flag fields stay", function()
      unsupported.greatVault, unsupported.delves, unsupported.mythicPlus = true, true, true
      local f = fieldNames()
      for _, gone in ipairs({ "vault", "vaultSlots", "hasUnclaimedVault", "delversBounty", "keystone", "keystoneMap", "dungeons" }) do
        assert.is_nil(f[gone], gone)
      end
      for _, kept in ipairs({ "DMF", "preMidnight", "caches" }) do
        assert.is_true(f[kept], kept)
      end
    end)

    it("Retail: every weekly field is present", function()
      local f = fieldNames()
      for _, name in ipairs({ "DMF", "preMidnight", "delversBounty", "caches", "vault", "vaultSlots", "hasUnclaimedVault",
                              "keystone", "keystoneMap", "dungeons" }) do
        assert.is_true(f[name], name)
      end
    end)

    it("greatVault alone unsupported drops the three vault fields and dungeons", function()
      unsupported.greatVault = true
      local f = fieldNames()
      assert.is_nil(f.vault); assert.is_nil(f.vaultSlots); assert.is_nil(f.hasUnclaimedVault); assert.is_nil(f.dungeons)
      assert.is_true(f.keystone); assert.is_true(f.delversBounty)
    end)

    it("delves alone unsupported drops only delversBounty", function()
      unsupported.delves = true
      local f = fieldNames()
      assert.is_nil(f.delversBounty)
      assert.is_true(f.vault); assert.is_true(f.keystone); assert.is_true(f.dungeons)
    end)

    it("mythicPlus alone unsupported drops the keystone fields and dungeons", function()
      unsupported.mythicPlus = true
      local f = fieldNames()
      assert.is_nil(f.keystone); assert.is_nil(f.keystoneMap); assert.is_nil(f.dungeons)
      assert.is_true(f.vault); assert.is_true(f.delversBounty)
    end)
  end)

  describe("D4 reputations: the faction scan does not re-trigger itself", function()
    local field, toon

    local function loadReputations()
      load("data/reputations.lua")
      field = ns.brokers.reputations.fields.factions
      toon = { reputations = {} }
      field._toon = toon
    end

    it("a synchronous UPDATE_FACTION during the expand does not schedule another scan", function()
      loadReputations()
      _G.C_Reputation.ExpandAllFactionHeaders = function() field.eventHandler(field) end  -- Forever: echo inside the expand
      field:get(toon)
      assert.equals(0, #ns.debounced)
    end)

    it("an error inside the expand leaves the next scan possible", function()
      loadReputations()
      _G.C_Reputation.ExpandAllFactionHeaders = function() error("expand failed") end
      local ok = pcall(field.get, field, toon)
      assert.is_false(ok)
      _G.C_Reputation.ExpandAllFactionHeaders = noop
      field.eventHandler(field)                      -- an ordinary UPDATE_FACTION now schedules the scan
      assert.equals(1, #ns.debounced)
    end)

    it("Retail: the async echo inside SELF_WINDOW is still dropped and a later event still scans", function()
      loadReputations()
      field.eventHandler(field)                      -- a rep gain schedules a scan
      assert.equals(1, #ns.debounced)
      local scan = ns.debounced[1].fn
      ns.debounced = {}
      scan()                                         -- the scan runs and stamps lastScanAt = GetTime() (100)
      clock = 100.5                                  -- the async echo, inside SELF_WINDOW (1 s)
      field.eventHandler(field)
      assert.equals(0, #ns.debounced)
      clock = 110                                    -- an unrelated later event
      field.eventHandler(field)
      assert.equals(1, #ns.debounced)
    end)
  end)

  describe("D5 glyphs: no spec-keyed map where specializations are unsupported", function()
    it("Forever: no `applied` field; the per-character `unlocks` field is still recorded", function()
      unsupported.specializations = true
      load("data/glyphs.lua")
      local fields = ns.brokers.glyphs.fields
      assert.is_nil(fields.applied)
      assert.same({ [555] = true }, fields.unlocks.get(fields.unlocks, ns.currentData))
    end)

    it("Forever: `/wbc dump glyphs` reports no active spec and runs no live per-spec scan", function()
      unsupported.specializations = true
      load("data/glyphs.lua")
      local lines = {}
      -- pcall: the dump's later sections read catalog data this stub namespace does not carry; only the head matters.
      pcall(ns.dumpFns.glyphs, nil, { line = function(_, s) lines[#lines + 1] = s end })
      assert.matches("active spec nil", lines[1])
      for _, l in ipairs(lines) do assert.is_nil(l:match("^Live scan")) end
    end)

    it("Retail: `applied` is a spec-keyed map", function()
      load("data/glyphs.lua")
      local fields = ns.brokers.glyphs.fields
      assert.same({ [1482] = {} }, fields.applied.get(fields.applied, ns.currentData, nil))
    end)
  end)

  describe("D6 bank: the account (warband) bank runs only where it is supported", function()
    local viewed

    local function openBank()
      load("data/bank.lua")
      viewed = {}
      _G.C_Bank.CanViewBank = function(bankType) viewed[#viewed + 1] = bankType; return true end
      ns.events.BANKFRAME_OPENED()
    end

    it("Forever: records the character bank and no warband bank, never asking about the account bank", function()
      unsupported.warbandBank = true
      openBank()
      assert.is_table(ns.db.bank.characters.Tester)
      assert.is_nil(ns.db.bank.warband)
      assert.same({ 1 }, viewed)
    end)

    it("Retail: records both banks", function()
      openBank()
      assert.is_table(ns.db.bank.characters.Tester)
      assert.is_table(ns.db.bank.warband)
      assert.same({ 1, 2 }, viewed)
    end)
  end)
end)

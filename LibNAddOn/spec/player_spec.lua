-- globals/player.lua touches C_* tables at load, so it isn't part of the libn.lua harness; this spec
-- loads it standalone against stubs for what it reads at load time, and drives the client-flavor
-- guards: GetActiveSpecialization asks the feature table (Forever's C_SpecializationInfo exists but
-- reports one class-wide spec, so it must not be called there), GetPrimarySpecialization returns nil
-- where the globals it needs are missing, IsSpellKnown spells out Blizzard's deprecated shim over
-- C_SpellBook, and the Great Vault helper must not touch C_WeeklyRewards where the feature table says no.

describe("LibNAddOn Player flavor guards", function()
  local STUBBED = {
    "C_Container", "C_WeeklyRewards", "C_Item", "C_MountJournal",
    "C_SpecializationInfo", "C_SpellBook", "Enum",
    "GetSpecializationInfoByID", "GetLootSpecialization",
    "WOW_PROJECT_ID", "WOW_PROJECT_CAMELOT", "C_AddOns",   -- read by the real flavor.lua in the last block
  }
  local saved
  local ns, Player
  local supportsAsked, supportsResult
  local activityCalls, activities, links, ilvls
  local specCalls, spellBookCalls

  before_each(function()
    saved = {}
    for _, name in ipairs(STUBBED) do saved[name] = _G[name]; _G[name] = nil end

    activityCalls, activities, links, ilvls = 0, {}, {}, {}
    _G.C_Container = { ContainerIDToInventoryID = function(_slot) end }
    _G.C_WeeklyRewards = {
      GetActivities = function() activityCalls = activityCalls + 1; return activities end,
      GetExampleRewardItemHyperlinks = function(id) return links[id] end,
    }
    _G.C_Item = { GetDetailedItemLevelInfo = function(link) return ilvls[link] end }
    _G.C_MountJournal = { SummonByID = function() end }
    specCalls = 0
    _G.C_SpecializationInfo = {
      GetSpecialization = function() specCalls = specCalls + 1; return nil end,
      GetSpecializationInfo = function() specCalls = specCalls + 1; error("must not be asked for a nil spec") end,
    }
    spellBookCalls = {}
    _G.C_SpellBook = {
      IsSpellInSpellBook = function(...) spellBookCalls[#spellBookCalls + 1] = { ... }; return true end,
    }
    _G.Enum = { SpellBookSpellBank = { Player = 0, Pet = 1 } }

    supportsAsked, supportsResult = {}, true
    ns = {
      wow = {},
      registerCommand = function() end,
      Supports = function(feature)
        supportsAsked[#supportsAsked + 1] = feature
        return supportsResult
      end,
    }
    assert(loadfile("LibNAddOn/globals/player.lua"))("LibNAddOn", ns)
    Player = ns.wow.Player
  end)

  after_each(function()
    for _, name in ipairs(STUBBED) do _G[name] = saved[name] end
  end)

  describe("GetActiveSpecialization", function()
    local function forever()
      supportsResult = false
      _G.C_SpecializationInfo = {
        GetSpecialization = function() error("must not be asked on Forever") end,
        GetSpecializationInfo = function() error("must not be asked on Forever") end,
      }
    end

    it("Forever: returns nothing and never asks C_SpecializationInfo", function()
      forever()
      assert.has_no.errors(function() assert.is_nil(Player.GetActiveSpecialization()) end)
      assert.equals(0, select("#", Player.GetActiveSpecialization()))
      assert.same({ "specializations", "specializations" }, supportsAsked)
    end)

    it("Retail: returns C_SpecializationInfo's info for the active spec", function()
      _G.C_SpecializationInfo = {
        GetSpecialization = function() return 2 end,
        GetSpecializationInfo = function(idx)
          return 100 + idx, "Elemental", "desc", 12345, "DAMAGER", "SHAMAN", "Shaman"
        end,
      }
      local id, name, _, icon, role, classFile, className = Player.GetActiveSpecialization()
      assert.equals(102, id)
      assert.equals("Elemental", name)
      assert.equals(12345, icon)
      assert.equals("DAMAGER", role)
      assert.equals("SHAMAN", classFile)
      assert.equals("Shaman", className)
      assert.same({ "specializations" }, supportsAsked)
    end)

    it("Retail: returns nothing while no spec is active yet", function()
      _G.C_SpecializationInfo = {
        GetSpecialization = function() return nil end,
        GetSpecializationInfo = function() error("must not be asked for a nil spec") end,
      }
      assert.equals(0, select("#", Player.GetActiveSpecialization()))
    end)
  end)

  describe("GetPrimarySpecialization", function()
    it("returns nothing, without erroring, where the client has no GetSpecializationInfoByID (Forever)", function()
      _G.GetLootSpecialization = function() return 0 end   -- present on Forever
      assert.has_no.errors(function() assert.is_nil(Player.GetPrimarySpecialization()) end)
      assert.equals(0, select("#", Player.GetPrimarySpecialization()))
    end)

    it("returns nothing where GetLootSpecialization is missing", function()
      _G.GetSpecializationInfoByID = function() error("must not be called") end
      assert.equals(0, select("#", Player.GetPrimarySpecialization()))
    end)

    it("returns the loot spec's info where the client has the spec API (Retail)", function()
      _G.GetLootSpecialization = function() return 262 end
      _G.GetSpecializationInfoByID = function(specId)
        return specId, "Elemental", "desc", 12345, "DAMAGER", "SHAMAN", "Shaman"
      end
      local id, name = Player.GetPrimarySpecialization()
      assert.equals(262, id)
      assert.equals("Elemental", name)
    end)
  end)

  describe("IsSpellKnown", function()
    it("player bank, overrides excluded", function()
      assert.is_true(Player.IsSpellKnown(1459))
      assert.same({ { 1459, 0, false } }, spellBookCalls)
    end)

    it("pet bank when isPet", function()
      assert.is_true(Player.IsSpellKnown(883, true))
      assert.same({ { 883, 1, false } }, spellBookCalls)
    end)

    it("reads C_SpellBook at call time, not at load", function()
      _G.C_SpellBook = { IsSpellInSpellBook = function() return false end }
      assert.is_false(Player.IsSpellKnown(1459))
    end)
  end)

  describe("GreatVault.getRewardOptions", function()
    local function oneCompleteRaidSlot()
      activities = {
        { id = 11, type = 3, progress = 2, threshold = 2 },   -- Raid, complete
        { id = 12, type = 1, progress = 1, threshold = 4 },   -- Dungeons, in progress
      }
      links[11] = "link11"
      ilvls.link11 = 639
    end

    it("returns empties and never touches C_WeeklyRewards where greatVault is unsupported (Forever)", function()
      supportsResult = false
      oneCompleteRaidSlot()
      local rewards, counts, progress, best, bestN = ns.wow.GreatVault.getRewardOptions()
      assert.same({}, rewards)
      assert.same({}, counts)
      assert.same({}, progress)
      assert.equals(0, best)
      assert.equals(0, bestN)
      assert.equals(0, activityCalls)
      assert.same({ "greatVault" }, supportsAsked)
    end)

    it("gives Player:GetRewardOptions a well-formed zero result where unsupported", function()
      supportsResult = false
      local vault = Player:GetRewardOptions()
      assert.equals(0, vault.best)
      assert.equals(0, vault.bestN)
      assert.same({}, vault.progress)
      assert.same({}, vault.counts)
      assert.equals(0, activityCalls)
    end)

    it("reads C_WeeklyRewards and aggregates the vault where greatVault is supported (Retail)", function()
      supportsResult = true
      oneCompleteRaidSlot()
      local _, counts, progress, best, bestN = ns.wow.GreatVault.getRewardOptions()
      assert.equals(1, activityCalls)
      assert.same({ complete = 1, progress = 2, max = 2 }, progress.Raid)
      assert.same({ complete = 0, progress = 1, max = 4 }, progress.Dungeons)
      assert.same({ [639] = 1 }, counts)
      assert.equals(639, best)
      assert.equals(1, bestN)
      assert.same({ "greatVault" }, supportsAsked)
    end)
  end)

  -- The blocks above stub ns.Supports; this one loads the real flavor.lua beside player.lua so the
  -- guard is exercised against the real feature table (the seam between the two files).
  describe("with the real feature table", function()
    local function loadReal(clientProject)
      _G.WOW_PROJECT_CAMELOT, _G.WOW_PROJECT_ID = 18, clientProject
      local real = { wow = {}, registerCommand = function() end }
      assert(loadfile("LibNAddOn/flavor.lua"))("LibNAddOn", real)
      assert(loadfile("LibNAddOn/globals/player.lua"))("LibNAddOn", real)
      return real
    end

    it("Forever: getRewardOptions returns the zero result without reading C_WeeklyRewards", function()
      local real = loadReal(18)
      activities = { { id = 11, type = 3, progress = 2, threshold = 2 } }
      local _, counts, progress, best, bestN = real.wow.GreatVault.getRewardOptions()
      assert.same({}, counts)
      assert.same({}, progress)
      assert.equals(0, best)
      assert.equals(0, bestN)
      assert.equals(0, activityCalls)
    end)

    it("Forever (real table): GetActiveSpecialization returns nothing although C_SpecializationInfo reports class spec 1482", function()
      local real = loadReal(18)
      _G.C_SpecializationInfo = {
        GetSpecialization = function() return 1 end,
        GetSpecializationInfo = function() return 1482, "Mage", "desc", 1, "DAMAGER", "MAGE", "Mage" end,
      }
      assert.equals(0, select("#", real.wow.Player.GetActiveSpecialization()))
    end)

    it("Retail (real table): GetActiveSpecialization returns the active spec", function()
      local real = loadReal(1)
      _G.C_SpecializationInfo = {
        GetSpecialization = function() return 1 end,
        GetSpecializationInfo = function() return 62, "Arcane", "desc", 1, "DAMAGER", "MAGE", "Mage" end,
      }
      local id, name = real.wow.Player.GetActiveSpecialization()
      assert.equals(62, id)
      assert.equals("Arcane", name)
    end)

    it("Retail: getRewardOptions reads C_WeeklyRewards", function()
      local real = loadReal(1)
      activities = { { id = 11, type = 3, progress = 2, threshold = 2 } }
      links[11], ilvls.link11 = "link11", 639
      local _, _, progress, best = real.wow.GreatVault.getRewardOptions()
      assert.equals(1, activityCalls)
      assert.equals(1, progress.Raid.complete)
      assert.equals(639, best)
    end)
  end)
end)

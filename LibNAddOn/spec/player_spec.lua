-- globals/player.lua touches C_* tables at load, so it isn't part of the libn.lua harness; this spec
-- loads it standalone against stubs for what it reads at load time, and drives the client-flavor
-- guards: the spec helpers must return nil (not throw) where Forever has no GetSpecialization*,
-- and the Great Vault helper must not touch C_WeeklyRewards where the feature table says no.

describe("LibNAddOn Player flavor guards", function()
  local STUBBED = {
    "C_Container", "C_WeeklyRewards", "C_Item", "C_MountJournal",
    "GetSpecialization", "GetSpecializationInfo", "GetSpecializationInfoByID", "GetLootSpecialization",
    "WOW_PROJECT_ID", "WOW_PROJECT_CAMELOT", "C_AddOns",   -- read by the real flavor.lua in the last block
  }
  local saved
  local ns, Player
  local supportsAsked, supportsResult
  local activityCalls, activities, links, ilvls

  before_each(function()
    saved = {}
    for _, name in ipairs(STUBBED) do saved[name] = _G[name]; _G[name] = nil end

    activityCalls, activities, links, ilvls = 0, {}, {}, {}
    _G.C_Container = { ContainerIDToInventoryID = function() end }
    _G.C_WeeklyRewards = {
      GetActivities = function() activityCalls = activityCalls + 1; return activities end,
      GetExampleRewardItemHyperlinks = function(id) return links[id] end,
    }
    _G.C_Item = { GetDetailedItemLevelInfo = function(link) return ilvls[link] end }
    _G.C_MountJournal = { SummonByID = function() end }

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
    it("returns nothing, without erroring, where the client has no GetSpecialization (Forever)", function()
      assert.has_no.errors(function() assert.is_nil(Player.GetActiveSpecialization()) end)
      assert.equals(0, select("#", Player.GetActiveSpecialization()))
    end)

    it("returns nothing where GetSpecialization exists but GetSpecializationInfo does not", function()
      _G.GetSpecialization = function() return 1 end
      assert.equals(0, select("#", Player.GetActiveSpecialization()))
    end)

    it("returns nothing where GetSpecializationInfo exists but GetSpecialization does not", function()
      _G.GetSpecializationInfo = function() error("must not be called without a spec index") end
      assert.equals(0, select("#", Player.GetActiveSpecialization()))
    end)

    it("returns the spec info where the client has the spec API (Retail)", function()
      _G.GetSpecialization = function() return 2 end
      _G.GetSpecializationInfo = function(idx)
        return 100 + idx, "Elemental", "desc", 12345, "DAMAGER", "SHAMAN", "Shaman"
      end
      local id, name, _, icon, role, classFile, className = Player.GetActiveSpecialization()
      assert.equals(102, id)
      assert.equals("Elemental", name)
      assert.equals(12345, icon)
      assert.equals("DAMAGER", role)
      assert.equals("SHAMAN", classFile)
      assert.equals("Shaman", className)
    end)

    it("still returns nothing when the client has the API but no spec is active yet", function()
      _G.GetSpecialization = function() return nil end
      _G.GetSpecializationInfo = function() error("must not be asked for a nil spec") end
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

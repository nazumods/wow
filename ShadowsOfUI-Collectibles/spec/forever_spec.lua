local collect = require("ShadowsOfUI-Collectibles.spec.collect")

local SIX_EVENTS = {
  "NEW_RECIPE_LEARNED", "NEW_MOUNT_ADDED", "NEW_PET_ADDED", "TOYS_UPDATED",
  "TRANSMOG_COLLECTION_SOURCE_ADDED", "QUEST_TURNED_IN",
}
local FOREVER = { unsupported = { housing = true } }

describe("ShadowsOfUI-Collectibles on Forever", function()
  describe("housing", function()
    it("Forever: no housing catalog searcher at login", function()
      local ns = collect.load(FOREVER)
      local calls = collect.loadSurfaces(ns)
      ns:onLogin()
      assert.equals(0, calls.searcher)
    end)

    it("Retail: the searcher still runs at login", function()
      local ns = collect.load()
      local calls = collect.loadSurfaces(ns)
      ns:onLogin()
      assert.equals(1, calls.searcher)
    end)

    it("Forever: HOUSING_STORAGE_UPDATED is not registered; the other six collection events still are", function()
      local ns = collect.load(FOREVER)
      assert.is_nil(ns.events.HOUSING_STORAGE_UPDATED)
      for _, e in ipairs(SIX_EVENTS) do assert.is_true(ns.events[e], e) end
    end)

    it("Retail: HOUSING_STORAGE_UPDATED is registered", function()
      local ns = collect.load()
      assert.is_true(ns.events.HOUSING_STORAGE_UPDATED)
      for _, e in ipairs(SIX_EVENTS) do assert.is_true(ns.events[e], e) end
    end)
  end)

  describe("battle pet count", function()
    local PET = "|Hbattlepet:100::::::|h[Some Pet]|h"
    local ns, pj

    before_each(function()
      ns = collect.load(FOREVER)
      pj = _G["C_PetJournal"]
    end)

    it("a battlepet link with GetNumCollectedInfo missing is not known and not cached", function()
      pj.GetNumCollectedInfo = nil
      assert.is_false(ns.IsKnown(PET))
      -- Not cached: once the call exists and answers, the link reads as known.
      pj.GetNumCollectedInfo = function() return 1 end
      assert.is_true(ns.IsKnown(PET))
    end)

    it("a battlepet link with GetNumCollectedInfo present behaves as before", function()
      local asked
      pj.GetNumCollectedInfo = function(species) asked = species return 1 end
      assert.is_true(ns.IsKnown(PET))
      assert.equals(100, asked)
      -- the positive is cached for the session
      pj.GetNumCollectedInfo = function() return 0 end
      assert.is_true(ns.IsKnown(PET))
    end)

    it("a battlepet link with a zero count is not known", function()
      pj.GetNumCollectedInfo = function() return 0 end
      assert.is_false(ns.IsKnown(PET))
    end)

    it("a battlepet link is still collectible without the count call", function()
      pj.GetNumCollectedInfo = nil
      assert.is_true(ns.IsCollectible(PET))
    end)
  end)
end)

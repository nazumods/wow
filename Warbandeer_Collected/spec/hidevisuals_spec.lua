local collected = require("Warbandeer_Collected.spec.collected")

-- The real Enum.TransmogCollectionType values for the eleven armour categories, so a swapped entry
-- in hidevisuals.lua's slot → category map surfaces as a wrong category id rather than passing
-- against a stub that agrees with the mistake.
local CATEGORY = {
  Head = 1, Shoulder = 2, Back = 3, Chest = 4, Shirt = 5, Tabard = 6,
  Wrist = 7, Hands = 8, Waist = 9, Legs = 10, Feet = 11,
}

-- Every paper-doll slot and the category that has to answer for it. The pairing IS the thing under
-- test; the sourceIDs below are derived from the category id so a test can name the one it expects.
local EXPECTED = {
  { slot = "INVSLOT_HEAD",     category = CATEGORY.Head },
  { slot = "INVSLOT_SHOULDER", category = CATEGORY.Shoulder },
  { slot = "INVSLOT_BACK",     category = CATEGORY.Back },
  { slot = "INVSLOT_CHEST",    category = CATEGORY.Chest },
  { slot = "INVSLOT_BODY",     category = CATEGORY.Shirt },
  { slot = "INVSLOT_TABARD",   category = CATEGORY.Tabard },
  { slot = "INVSLOT_WRIST",    category = CATEGORY.Wrist },
  { slot = "INVSLOT_HAND",     category = CATEGORY.Hands },
  { slot = "INVSLOT_WAIST",    category = CATEGORY.Waist },
  { slot = "INVSLOT_LEGS",     category = CATEGORY.Legs },
  { slot = "INVSLOT_FEET",     category = CATEGORY.Feet },
}

-- Synthetic ids, keyed off the category so every assertion can say which category answered:
-- category 4 (Chest) → visual 4000, source 4100, icon 4200.
local function visualFor(category) return category * 1000 end
local function sourceFor(category) return category * 1000 + 100 end
local function iconFor(category) return category * 1000 + 200 end

describe("hide visuals", function()
  local ns, calls, categoriesWithHide

  -- A stub collection where each category holds one ordinary appearance and (unless the test says
  -- otherwise) one flagged isHideVisual, mid-list — the position the real API returns it in.
  local function install()
    calls = {}
    _G.Enum = { TransmogCollectionType = CATEGORY }
    _G.C_TransmogCollection = {
      GetCategoryAppearances = function(category)
        calls[category] = (calls[category] or 0) + 1
        local out = { { visualID = category * 10 + 1, isCollected = true } }
        if categoriesWithHide[category] then
          out[#out + 1] = { visualID = visualFor(category), isCollected = true, isHideVisual = true }
        end
        out[#out + 1] = { visualID = category * 10 + 2, isCollected = false }
        return out
      end,
      GetAppearanceSourceInfo = function(sourceID)
        return { icon = sourceID + 100 }
      end,
    }
    ns = collected.load()
    -- The room's shared visual → source resolver, stubbed to the identity the ids above encode.
    ns.AppearanceSource = function(visualID) return { sourceID = visualID + 100 } end
    collected.loadHideVisuals(ns)
  end

  before_each(function()
    categoriesWithHide = {}
    for _, e in ipairs(EXPECTED) do categoriesWithHide[e.category] = true end
    install()
  end)

  describe("HideVisual", function()
    it("resolves each paper-doll slot through its own category", function()
      for _, e in ipairs(EXPECTED) do
        local sourceID, icon = ns.HideVisual(_G[e.slot])
        assert.equal(sourceFor(e.category), sourceID, e.slot .. " resolved the wrong category")
        assert.equal(iconFor(e.category), icon)
      end
    end)

    it("gives every slot a distinct hide visual", function()
      local seen = {}
      for _, e in ipairs(EXPECTED) do
        local sourceID = ns.HideVisual(_G[e.slot])
        assert.is_nil(seen[sourceID], e.slot .. " shares a hide visual with " .. tostring(seen[sourceID]))
        seen[sourceID] = e.slot
      end
    end)

    it("has none for slots outside the paper doll", function()
      assert.is_nil(ns.HideVisual(INVSLOT_MAINHAND))
      assert.is_nil(ns.HideVisual(INVSLOT_OFFHAND))
      assert.is_nil(ns.HideVisual(2))   -- neck: equippable, never transmoggable
    end)

    it("caches a resolved slot", function()
      ns.HideVisual(INVSLOT_HEAD)
      ns.HideVisual(INVSLOT_HEAD)
      ns.HideVisual(INVSLOT_HEAD)
      assert.equal(1, calls[CATEGORY.Head])
    end)

    it("does not cache a miss, so a slot self-heals once the collection populates", function()
      categoriesWithHide[CATEGORY.Head] = nil
      assert.is_nil(ns.HideVisual(INVSLOT_HEAD))
      categoriesWithHide[CATEGORY.Head] = true
      assert.equal(sourceFor(CATEGORY.Head), ns.HideVisual(INVSLOT_HEAD))
    end)

    it("has none for a slot whose visual resolves to no source", function()
      ns.AppearanceSource = function() return false end
      assert.is_nil(ns.HideVisual(INVSLOT_CHEST))
    end)
  end)

  describe("IsHideVisual", function()
    it("is true only for that slot's own hide visual", function()
      assert.is_true(ns.IsHideVisual(INVSLOT_HEAD, sourceFor(CATEGORY.Head)))
      assert.is_false(ns.IsHideVisual(INVSLOT_HEAD, sourceFor(CATEGORY.Feet)))
      assert.is_false(ns.IsHideVisual(INVSLOT_HEAD, 12345))
    end)

    -- The distinction the whole file exists for: 0 is "no transmog", not "hidden".
    it("is false for an empty slot", function()
      assert.is_false(ns.IsHideVisual(INVSLOT_HEAD, 0))
      assert.is_false(ns.IsHideVisual(INVSLOT_HEAD, nil))
    end)

    it("is false for a slot that has no hide visual", function()
      assert.is_false(ns.IsHideVisual(INVSLOT_MAINHAND, sourceFor(CATEGORY.Head)))
    end)
  end)
end)

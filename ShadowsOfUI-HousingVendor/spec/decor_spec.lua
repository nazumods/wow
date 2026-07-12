local hv = require("ShadowsOfUI-HousingVendor.spec.hvendor")

describe("ShadowsOfUI-HousingVendor decor", function()
  describe("NormalizeEntry — pure count/bonus logic", function()
    local ns
    before_each(function() ns = hv.load() end)

    it("returns nil for a nil entry", function()
      assert.is_nil(ns.NormalizeEntry(nil))
    end)

    it("treats an entry with no instances as unowned and clean", function()
      local d = ns.NormalizeEntry({ totalNumStored = 0, remainingRedeemable = 0, totalNumPlaced = 0, firstAcquisitionBonus = 0 })
      assert.is_false(d.owned)
      assert.equals(0, d.stored)
      assert.equals(0, d.total)
      assert.is_false(d.bonusAvailable)
    end)

    it("counts stored + redeemable as on-hand, and adds placed for total", function()
      local d = ns.NormalizeEntry({ totalNumStored = 2, remainingRedeemable = 1, totalNumPlaced = 3, firstAcquisitionBonus = 0 })
      assert.is_true(d.owned)
      assert.equals(3, d.stored) -- 2 + 1
      assert.equals(6, d.total)  -- 3 + 3
    end)

    it("is owned with a 0 on-hand count when every instance is placed", function()
      local d = ns.NormalizeEntry({ totalNumStored = 0, remainingRedeemable = 0, totalNumPlaced = 1, firstAcquisitionBonus = 0 })
      assert.is_true(d.owned)
      assert.equals(0, d.stored)
      assert.equals(1, d.total)
    end)

    it("flags a first-acquisition bonus only when the decor is unowned", function()
      local avail = ns.NormalizeEntry({ totalNumStored = 0, remainingRedeemable = 0, totalNumPlaced = 0, firstAcquisitionBonus = 500 })
      assert.is_true(avail.bonusAvailable)
      assert.equals(500, avail.bonus)

      local owned = ns.NormalizeEntry({ totalNumStored = 1, remainingRedeemable = 0, totalNumPlaced = 0, firstAcquisitionBonus = 500 })
      assert.is_false(owned.bonusAvailable) -- already owned: the bonus was claimed
    end)

    it("tolerates missing numeric fields", function()
      local d = ns.NormalizeEntry({})
      assert.equals(0, d.stored)
      assert.equals(0, d.total)
      assert.is_false(d.owned)
      assert.is_false(d.bonusAvailable)
    end)
  end)

  describe("DecorEntryFor — class gate + cache", function()
    local ns, state
    before_each(function() ns, state = hv.load() end)

    it("returns nil and permanently caches a non-decor item as not-decor", function()
      state.itemInfo[10] = { classID = Enum.ItemClass.Consumable }
      assert.is_nil(ns.DecorEntryFor("item:10"))
      -- even if a catalog entry appears later, the not-decor negative stands
      state.entries[10] = { totalNumStored = 5 }
      assert.is_nil(ns.DecorEntryFor("item:10"))
    end)

    it("resolves a decor item's counts through the catalog", function()
      state.itemInfo[20] = { classID = Enum.ItemClass.Housing, subClassID = Enum.ItemHousingSubclass.Decor }
      state.entries[20] = { totalNumStored = 4, remainingRedeemable = 0, totalNumPlaced = 0, firstAcquisitionBonus = 0 }
      local d = ns.DecorEntryFor("item:20")
      assert.is_true(d.owned)
      assert.equals(4, d.stored)
    end)

    it("does not cache a decor item the catalog can't resolve yet, so it retries", function()
      state.itemInfo[30] = { classID = Enum.ItemClass.Housing, subClassID = Enum.ItemHousingSubclass.Decor }
      assert.is_nil(ns.DecorEntryFor("item:30")) -- catalog not primed: no entry
      state.entries[30] = { totalNumStored = 1, remainingRedeemable = 0, totalNumPlaced = 0, firstAcquisitionBonus = 0 }
      local d = ns.DecorEntryFor("item:30")
      assert.is_not_nil(d)
      assert.is_true(d.owned)
    end)

    it("re-queries cached decor counts after WipeDecorCache", function()
      state.itemInfo[40] = { classID = Enum.ItemClass.Housing, subClassID = Enum.ItemHousingSubclass.Decor }
      state.entries[40] = { totalNumStored = 1, remainingRedeemable = 0, totalNumPlaced = 0, firstAcquisitionBonus = 0 }
      assert.equals(1, ns.DecorEntryFor("item:40").stored)
      state.entries[40].totalNumStored = 9              -- bought more
      assert.equals(1, ns.DecorEntryFor("item:40").stored) -- still served from cache
      ns.WipeDecorCache()
      assert.equals(9, ns.DecorEntryFor("item:40").stored) -- re-queried
    end)
  end)

  describe("shared decor API (X-NUI-API HousingDecorApi)", function()
    it("exposes DecorEntryFor as ns.api.EntryFor for ShadowsOfUI-Collectibles", function()
      local ns = hv.load()
      assert.equals(ns.DecorEntryFor, ns.api.EntryFor)
    end)
  end)
end)

local hd = require("Warbandeer_Decor.spec.loader")

describe("Warbandeer_Decor", function()
  describe("NormalizeEntry -- pure count/bonus logic", function()
    local ns
    before_each(function() ns = hd.load() end)

    it("returns nil for a nil entry", function()
      assert.is_nil(ns.NormalizeEntry(nil))
    end)

    it("treats an all-zero (or empty) entry as unowned and clean", function()
      local d = ns.NormalizeEntry({})
      assert.is_false(d.owned)
      assert.equals(0, d.stored)
      assert.equals(0, d.total)
      assert.equals(0, d.bonus)
      assert.is_false(d.bonusAvailable)
    end)

    it("sums stored + redeemable, then adds placed for the total", function()
      local d = ns.NormalizeEntry({ totalNumStored = 2, remainingRedeemable = 1, totalNumPlaced = 3 })
      assert.equals(3, d.stored)   -- 2 + 1
      assert.equals(6, d.total)    -- 3 stored + 3 placed
      assert.is_true(d.owned)
    end)

    it("counts placed-only decor as owned with zero stored", function()
      local d = ns.NormalizeEntry({ totalNumPlaced = 2 })
      assert.is_true(d.owned)
      assert.equals(0, d.stored)
      assert.equals(2, d.total)
    end)

    it("marks the first-acquisition bonus available only while unowned", function()
      local unowned = ns.NormalizeEntry({ firstAcquisitionBonus = 50 })
      assert.equals(50, unowned.bonus)
      assert.is_true(unowned.bonusAvailable)

      local owned = ns.NormalizeEntry({ firstAcquisitionBonus = 50, totalNumStored = 1 })
      assert.equals(50, owned.bonus)
      assert.is_false(owned.bonusAvailable)
    end)
  end)

  describe("DedupeVariants -- decor recordIDs in first-seen order", function()
    local ns
    before_each(function() ns = hd.load() end)

    it("returns an empty list for nil", function()
      assert.same({}, ns.DedupeVariants(nil))
    end)

    it("keeps one recordID per decor entry, dropping rooms and dupes", function()
      local variants = {
        { entryType = 1, recordID = 10 },  -- decor
        { entryType = 1, recordID = 10 },  -- dye variant of the same record
        { entryType = 2, recordID = 20 },  -- a room -- dropped
        { entryType = 1, recordID = 30 },  -- decor
        { entryType = 1, recordID = 10 },  -- decor dupe again
      }
      assert.same({ 10, 30 }, ns.DedupeVariants(variants))
    end)
  end)

  describe("wanted model -- keyed by recordID", function()
    local ns
    before_each(function() ns = hd.load() end)

    it("flags, reads, counts, and toggles", function()
      assert.is_false(ns:IsWanted(5))
      ns:SetWanted(5, true)
      assert.is_true(ns:IsWanted(5))
      assert.equals(1, ns:WantedCount())
      assert.is_false(ns:ToggleWanted(5))  -- flips off
      assert.equals(0, ns:WantedCount())
      assert.is_true(ns:ToggleWanted(5))   -- flips back on
    end)

    it("clears the key when set false (no empty-key leak)", function()
      ns:SetWanted(7, true)
      ns:SetWanted(7, false)
      assert.equals(0, ns:WantedCount())
      assert.is_nil(ns.db.wanted[7])
    end)

    it("fires ratings-changed listeners on toggle", function()
      local fired = 0
      ns:OnRatingsChanged(function() fired = fired + 1 end)
      ns:ToggleWanted(9)
      assert.equals(1, fired)
    end)
  end)
end)

local collected = require("Warbandeer_Collected.spec.collected")

-- The Weapons view's half of ratings.lua: per-appearance wanted flags and tiers, keyed by visualID,
-- plus the two aggregates the Weapons grid draws a cell's marks from. All plain `ns.db` reads and
-- writes, so the whole path runs without the client.

describe("ratings", function()
  local ns

  before_each(function()
    ns = collected.loadRatings(collected.load())
  end)

  describe("tier order", function()
    it("indexes the tiers best to worst", function()
      assert.same({"S", "A", "B", "C", "F"}, ns.Ranks)
      assert.equal(1, ns.RankIndex.S)
      assert.equal(#ns.Ranks, ns.RankIndex.F)
    end)

    it("gives every tier a color and a hex string", function()
      for _, letter in ipairs(ns.Ranks) do
        assert.is_table(ns.RankColors[letter], letter .. " needs a color")
        assert.equal(6, #ns.RankHex(letter), letter .. " should render as RRGGBB")
      end
      assert.is_nil(ns.RankHex(nil))
      assert.is_nil(ns.RankHex("Z"))
    end)
  end)

  describe("weapon rank", function()
    it("round-trips a tier for an appearance", function()
      ns:SetWeaponRank(4211, "A")
      assert.equal("A", ns:WeaponRank(4211))
    end)

    it("reports nil for an unranked appearance", function()
      assert.is_nil(ns:WeaponRank(4211))
    end)

    it("clears the tier when set to nil, leaving no key behind", function()
      ns:SetWeaponRank(4211, "S")
      ns:SetWeaponRank(4211, nil)
      assert.is_nil(ns:WeaponRank(4211))
      assert.is_nil(next(ns.db.weaponRank))
    end)

    -- visualIDs and setIds are separate id spaces that overlap numerically, so the two tables must
    -- not see each other's writes: an S-tier weapon must never light up a set's rank pip.
    it("is independent of the set-keyed baseline rank", function()
      ns:SetWeaponRank(1234, "S")
      ns:SetBaselineRank(1234, "F")
      assert.equal("S", ns:WeaponRank(1234))
      assert.equal("F", ns:BaselineRank(1234))
    end)
  end)

  describe("weapon wanted", function()
    it("flips on and back off", function()
      assert.is_false(ns:IsWeaponWanted(77))
      assert.is_true(ns:ToggleWeaponWanted(77))
      assert.is_true(ns:IsWeaponWanted(77))
      assert.is_false(ns:ToggleWeaponWanted(77))
      assert.is_false(ns:IsWeaponWanted(77))
    end)

    -- Storing `false` rather than clearing the key would leave the flag counted forever: the tally
    -- is a `pairs` walk, which sees a false value exactly as it sees a true one.
    it("clears the key rather than storing false", function()
      ns:ToggleWeaponWanted(77)
      ns:ToggleWeaponWanted(77)
      assert.is_nil(next(ns.db.weaponWanted))
      assert.equal(0, ns:WeaponWantedCount())
    end)

    it("counts only weapon flags, not the cosmetic or illusion lists", function()
      ns:ToggleWeaponWanted(1)
      ns:ToggleWeaponWanted(2)
      ns:ToggleCosmeticWanted(3)
      ns:ToggleIllusionWanted(4)
      assert.equal(2, ns:WeaponWantedCount())
      assert.equal(1, ns:CosmeticWantedCount())
      assert.equal(1, ns:IllusionWantedCount())
    end)

    -- A wanted shirt and a wanted weapon can share a visualID; each list has to answer for itself.
    it("keeps its flags out of the cosmetic list", function()
      ns:ToggleWeaponWanted(500)
      assert.is_true(ns:IsWeaponWanted(500))
      assert.is_false(ns:IsCosmeticWanted(500))
    end)
  end)

  describe("weapon cell aggregates", function()
    it("marks a cell wanted when any one of its looks is", function()
      ns:ToggleWeaponWanted(20)
      assert.is_true(ns:WeaponCellWanted({10, 20, 30}))
      assert.is_false(ns:WeaponCellWanted({10, 30}))
    end)

    it("treats an empty cell as unwanted and unranked", function()
      assert.is_false(ns:WeaponCellWanted({}))
      assert.is_nil(ns:WeaponCellRank({}))
    end)

    it("shows the best tier in the cell, ignoring unranked looks", function()
      ns:SetWeaponRank(10, "C")
      ns:SetWeaponRank(30, "A")
      assert.equal("A", ns:WeaponCellRank({10, 20, 30}))
    end)

    it("picks the best tier regardless of the order the looks are listed in", function()
      ns:SetWeaponRank(10, "S")
      ns:SetWeaponRank(30, "F")
      assert.equal("S", ns:WeaponCellRank({10, 30}))
      assert.equal("S", ns:WeaponCellRank({30, 10}))
    end)

    it("reports nil when none of the cell's looks is ranked", function()
      ns:SetWeaponRank(99, "S")   -- ranked, but not in this cell
      assert.is_nil(ns:WeaponCellRank({10, 20, 30}))
    end)
  end)
end)

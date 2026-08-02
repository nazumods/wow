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

  -- The fan-out every surface refreshes from (#765). The setId it carries is what keeps a single
  -- Shift-click from repainting every cell in both grids, so the forwarding is worth pinning down:
  -- a listener that silently received nil would fall back to a full refresh and hide the problem.
  describe("change notification", function()
    it("forwards the changed setId to a listener", function()
      local got, calls = nil, 0
      ns:OnRatingsChanged(function(setId) got, calls = setId, calls + 1 end)
      ns:NotifyRatingsChanged(4242)
      assert.equal(1, calls)
      assert.equal(4242, got)
    end)

    -- nil is the "several changed / caller doesn't know" signal bulk paths rely on, and listeners
    -- read it as "refresh everything". It has to arrive as nil, not as a stale previous setId.
    it("forwards nil when no set is named", function()
      local got = 1   -- seed non-nil so a listener that never fired can't pass this
      ns:OnRatingsChanged(function(setId) got = setId end)
      ns:NotifyRatingsChanged()
      assert.is_nil(got)
    end)

    it("gives every registered listener the same setId", function()
      local seen = {}
      for i = 1, 3 do ns:OnRatingsChanged(function(setId) seen[i] = setId end) end
      ns:NotifyRatingsChanged(7)
      assert.same({7, 7, 7}, seen)
    end)

    it("is a no-op with nothing registered", function()
      assert.has_no.errors(function() ns:NotifyRatingsChanged(1) end)
    end)

    -- The weapon key (#768 L-8). It is a SECOND argument rather than a replacement because the two
    -- id spaces are unrelated and each scopes a different grid — and because appending keeps a
    -- consumer built against the one-argument form working untouched.
    it("forwards the changed visualID to a listener", function()
      local set, vis = 1, nil
      ns:OnRatingsChanged(function(s, v) set, vis = s, v end)
      ns:NotifyRatingsChanged(nil, 8080)
      assert.is_nil(set)
      assert.equal(8080, vis)
    end)

    it("carries both keys independently", function()
      local seen = {}
      ns:OnRatingsChanged(function(s, v) seen[#seen + 1] = {s, v} end)
      ns:NotifyRatingsChanged(11)            -- armour only
      ns:NotifyRatingsChanged(nil, 22)       -- weapon only
      ns:NotifyRatingsChanged()              -- everything
      assert.same({{11}, {nil, 22}, {}}, seen)
    end)

    it("gives every registered listener the same visualID", function()
      local seen = {}
      for i = 1, 3 do ns:OnRatingsChanged(function(_, v) seen[i] = v end) end
      ns:NotifyRatingsChanged(nil, 5)
      assert.same({5, 5, 5}, seen)
    end)

    -- The open hover tip is a fourth surface the broadcast has to reach: a rating changed while a tip
    -- is up must re-render it in place (#890). RefreshInfoTip no-ops when nothing is shown, so firing
    -- it on every notify is safe — and it is the ONE path that covers weapon cells, whose own
    -- Shift-click is a no-op (#857), so a regression here would silently strand the weapon tip.
    it("re-renders an open info tip on any change", function()
      local calls = 0
      ns.RefreshInfoTip = function() calls = calls + 1 end
      ns:NotifyRatingsChanged(7)          -- armour
      ns:NotifyRatingsChanged(nil, 8080)  -- weapon
      ns:NotifyRatingsChanged()           -- everything
      assert.equal(3, calls)
    end)
  end)

  -- The four wishlists come off one `wantedStore` factory since #770 step 2. Before that each was
  -- hand-written over its own db table, and they had already drifted in how they avoided storing
  -- `false`. These assert the shared contract holds for ALL of them, not just the one that happened
  -- to be covered — the counts are `pairs` walks, so a cleared flag left as `false` rather than
  -- removed would be counted as wanted forever.
  describe("wanted stores", function()
    local STORES = {
      { name = "sets",      field = "wanted",         is = "IsWanted",         toggle = "ToggleWanted",         count = "WantedCount" },
      { name = "weapons",   field = "weaponWanted",   is = "IsWeaponWanted",   toggle = "ToggleWeaponWanted",   count = "WeaponWantedCount" },
      { name = "cosmetics", field = "cosmeticWanted", is = "IsCosmeticWanted", toggle = "ToggleCosmeticWanted", count = "CosmeticWantedCount" },
      { name = "illusions", field = "illusionWanted", is = "IsIllusionWanted", toggle = "ToggleIllusionWanted", count = "IllusionWantedCount" },
    }

    for _, s in ipairs(STORES) do
      it(("%s: flips on and back off, reporting each state"):format(s.name), function()
        assert.is_false(ns[s.is](ns, 42))
        assert.is_true(ns[s.toggle](ns, 42))
        assert.is_true(ns[s.is](ns, 42))
        assert.is_false(ns[s.toggle](ns, 42))
        assert.is_false(ns[s.is](ns, 42))
      end)

      it(("%s: clears the key rather than storing false"):format(s.name), function()
        ns[s.toggle](ns, 42)
        ns[s.toggle](ns, 42)
        assert.is_nil(ns.db[s.field][42], "a cleared flag must leave no key behind")
        assert.equal(0, ns[s.count](ns))
      end)

      it(("%s: counts each flagged id once"):format(s.name), function()
        ns[s.toggle](ns, 1)
        ns[s.toggle](ns, 2)
        ns[s.toggle](ns, 3)
        ns[s.toggle](ns, 2)   -- back off
        assert.equal(2, ns[s.count](ns))
      end)
    end

    -- The id spaces overlap numerically (a setId, a visualID and an illusion sourceID can all be
    -- 500), so the tables must not see each other's writes.
    it("keeps the four lists independent for the same id", function()
      ns:ToggleWanted(500)
      assert.is_true(ns:IsWanted(500))
      assert.is_false(ns:IsWeaponWanted(500))
      assert.is_false(ns:IsCosmeticWanted(500))
      assert.is_false(ns:IsIllusionWanted(500))
      assert.equal(1, ns:WantedCount())
      assert.equal(0, ns:WeaponWantedCount())
      assert.equal(0, ns:CosmeticWantedCount())
      assert.equal(0, ns:IllusionWantedCount())
    end)

    -- Sets are the only list with a public setter, and it has to normalise the same way Toggle does.
    it("SetWanted clears the key when given false", function()
      ns:SetWanted(7, true)
      assert.is_true(ns:IsWanted(7))
      ns:SetWanted(7, false)
      assert.is_nil(ns.db.wanted[7])
      assert.equal(0, ns:WantedCount())
    end)
  end)
end)

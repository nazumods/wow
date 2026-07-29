local collected = require("Warbandeer_Collected.spec.collected")

-- `ns.GridRowOrder` — which source rows a grid shows and in what order (#770 step 13).
--
-- This is the only part of either grid that can silently change **what the user sees**: a wrong
-- filter hides rows, a wrong sort reorders them, and a wrong index opens the wrong lockout panel.
-- None of it was reachable by a test while it lived inline in two row builders.
--
-- The values it returns are indices into `source`, NOT display positions — for the armour grid in
-- live mode a group's source index is also its `ns.Sets` index, which the lockout panel keys off.
-- Several of these assertions exist to pin that down.

describe("GridRowOrder", function()
  local ns

  before_each(function()
    ns = collected.loadGridShared(collected.load())
  end)

  ---A view stub: only the filter/sort flags matter to the function under test.
  local function view(o)
    o = o or {}
    return { _ptr = o.ptr, _expansion = o.expansion or "all", _category = o.category or "all",
             _wantedOnly = o.wantedOnly, _reverse = o.reverse }
  end

  local function group(name, release, category)
    return { name = name, release = release, category = category, sets = {} }
  end

  local none = function() return false end
  local all = function() return true end

  describe("selection", function()
    it("keeps every row when no filter is set", function()
      local source = { group("A", 1), group("B", 2) }
      assert.same({ 1, 2 }, ns.GridRowOrder(view(), source, none))
    end)

    it("drops rows failing the expansion filter", function()
      local source = { group("A", 1), group("B", 2), group("C", 1) }
      assert.same({ 1, 3 }, ns.GridRowOrder(view{ expansion = 1 }, source, none))
    end)

    it("drops rows failing the category filter", function()
      local source = { group("A", 1, "Raid"), group("B", 1, "Dungeon") }
      assert.same({ 1 }, ns.GridRowOrder(view{ category = "Raid" }, source, none))
    end)

    it("returns nothing when the filters match nothing", function()
      local source = { group("A", 1, "Raid") }
      assert.same({}, ns.GridRowOrder(view{ category = "Dungeon" }, source, none))
    end)

    -- PTR preview is a small upcoming-only list with no category; filtering it would silently empty
    -- the preview.
    it("ignores the filters under PTR preview", function()
      local source = { group("A", 1, "Raid"), group("B", 2, "Dungeon") }
      assert.same({ 1, 2 }, ns.GridRowOrder(view{ ptr = true, expansion = 9, category = "PvP" }, source, none))
    end)
  end)

  describe("the wanted-only row gate", function()
    it("is not applied while the filter is off", function()
      local source = { group("A", 1), group("B", 1) }
      assert.same({ 1, 2 }, ns.GridRowOrder(view(), source, none))
    end)

    it("drops whole rows holding nothing wanted", function()
      local source = { group("A", 1), group("B", 1) }
      local wanted = function(grp) return grp.name == "B" end
      assert.same({ 2 }, ns.GridRowOrder(view{ wantedOnly = true }, source, wanted))
    end)

    it("keeps every row when all of them hold something wanted", function()
      local source = { group("A", 1), group("B", 1) }
      assert.same({ 1, 2 }, ns.GridRowOrder(view{ wantedOnly = true }, source, all))
    end)

    -- Both gates apply, not either: a wanted row from the wrong expansion still goes.
    it("applies alongside the expansion filter, not instead of it", function()
      local source = { group("A", 1), group("B", 2) }
      assert.same({ 2 }, ns.GridRowOrder(view{ wantedOnly = true, expansion = 2 }, source, all))
    end)

    -- The star is bypassed under PTR preview exactly as the dropdowns are. It used to be the one
    -- filter that still bit there, which left the preview half-filtered — and since the header
    -- counter reads `UpcomingCounts()` and honours no filter at all, a starred PTR view showed
    -- "+227 appearances upcoming" over an empty grid.
    it("ignores the wanted filter under PTR preview", function()
      local source = { group("A", 1), group("B", 1) }
      assert.same({ 1, 2 }, ns.GridRowOrder(view{ ptr = true, wantedOnly = true }, source, none))
    end)

    it("still applies the wanted filter once PTR preview is off", function()
      local source = { group("A", 1), group("B", 1) }
      assert.same({}, ns.GridRowOrder(view{ wantedOnly = true }, source, none))
    end)
  end)

  describe("ordering", function()
    it("sorts oldest expansion first by default", function()
      local source = { group("A", 3), group("B", 1), group("C", 2) }
      assert.same({ 2, 3, 1 }, ns.GridRowOrder(view(), source, none))
    end)

    it("sorts newest expansion first when reversed", function()
      local source = { group("A", 3), group("B", 1), group("C", 2) }
      assert.same({ 1, 3, 2 }, ns.GridRowOrder(view{ reverse = true }, source, none))
    end)

    it("sorts alphabetically within one expansion", function()
      local source = { group("Zulaman", 1), group("Deadmines", 1), group("Karazhan", 1) }
      assert.same({ 2, 3, 1 }, ns.GridRowOrder(view(), source, none))
    end)

    -- Alphabetical ordering is by BASE name, so a set's difficulty/variant rows group together and
    -- fall back to authored order rather than sorting by their parenthetical suffix.
    it("groups variants by base name and keeps them in authored order", function()
      local source = {
        group("Hellfire (Mythic)", 1), group("Ahn'Qiraj", 1), group("Hellfire (Normal)", 1),
      }
      assert.same({ 2, 1, 3 }, ns.GridRowOrder(view(), source, none))
    end)

    it("treats a missing release as oldest", function()
      local source = { group("A", 2), group("B", nil) }
      assert.same({ 2, 1 }, ns.GridRowOrder(view(), source, none))
    end)

    -- **`reverse` orders EXPANSIONS, not rows.** Only the release comparison honours it; rows within
    -- one expansion are always alphabetical. So with a single expansion filtered the sort toggle
    -- legitimately changes nothing — it looks inert but is behaving as designed, and "fixing" it into
    -- a full reverse would scramble the within-expansion ordering everywhere else.
    it("leaves the order alone when every row shares one expansion", function()
      local source = { group("Karazhan", 1), group("Deadmines", 1), group("Zulaman", 1) }
      local forward = ns.GridRowOrder(view(), source, none)
      local reversed = ns.GridRowOrder(view{ reverse = true }, source, none)
      assert.same({ 2, 1, 3 }, forward)   -- alphabetical
      assert.same(forward, reversed)
    end)
  end)

  -- The contract the lockout panel depends on: a returned value indexes `source`, so for the armour
  -- grid in live mode it is also the `ns.Sets` index `ns.ShowLockoutView` is called with. Renumbering
  -- these to display positions would open the wrong lockout instance with nothing erroring.
  describe("the srcIdx contract", function()
    it("returns source indices, not display positions", function()
      local source = { group("Last", 5), group("First", 1) }
      local order = ns.GridRowOrder(view(), source, none)
      assert.same({ 2, 1 }, order)
      assert.equal("First", source[order[1]].name)
      assert.equal("Last", source[order[2]].name)
    end)

    it("keeps the original indices after rows are filtered out", function()
      local source = { group("A", 1), group("B", 9), group("C", 1) }
      local order = ns.GridRowOrder(view{ expansion = 1 }, source, none)
      -- 1 and 3, NOT 1 and 2 — the dropped row must not renumber what follows it.
      assert.same({ 1, 3 }, order)
      assert.equal("C", source[order[2]].name)
    end)
  end)
end)

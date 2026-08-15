local collected = require("Warbandeer_Collected.spec.collected")

-- The lockout-selection gold highlight (DataViewMarks.lua). It is painted straight onto the name
-- label, OUTSIDE the shared per-cell mark walk, so under viewport virtualisation a slot the selected
-- row scrolled out of keeps its gold colour when it recycles to another row (name-cell data carries
-- no `color`, so Cell:Label's guarded re-apply never clears it). `_reapplySelection` therefore has to
-- reset EVERY resident name cell before re-golding the selected one, or the gold smears (#921). These
-- specs drive it over the REAL ns.ResidentCell slot math and fake cells that record their :Color call.

-- Two sentinels for the label colours the selection uses: WHITE_FONT_COLOR is passed whole, while
-- NORMAL_FONT_COLOR is splatted through :GetRGBA() — so a fake label records the first value of
-- whichever call arrives (the WHITE table, or the gold r-component).
local WHITE = setmetatable({}, { __tostring = function() return "WHITE" end })
local GOLD = "gold-r"

---A fake name cell whose label records the colour it was last set to.
local function fakeCell(seed)
  return { label = { color = seed, Color = function(self, first) self.color = first end } }
end

---A fake lockout arrow recording show/hide and its anchor target.
local function fakeArrow()
  return {
    shown = false, anchored = nil,
    TopRight = function(self, target) self.anchored = target end,
    Show = function(self) self.shown = true end,
    Hide = function(self) self.shown = false end,
  }
end

describe("DataView lockout-selection highlight (#921)", function()
  local ns, DV, NAME

  before_each(function()
    ns = collected.loadDataViewMarks(collected.load())
    DV = ns.DataView
    NAME = DV.NAME_COL
    _G.WHITE_FONT_COLOR = WHITE
    _G.NORMAL_FONT_COLOR = { GetRGBA = function() return GOLD, "g", "b", "a" end }
  end)

  -- A virtual grid whose resident window covers DATA rows [first .. first+n-1], one cell per slot in
  -- the name column, every name cell pre-coloured `seed` (simulating whatever the slot held before).
  local function grid(first, n, seed)
    local cells, rows = {}, {}
    for slot = 1, n do
      cells[slot] = { [NAME] = fakeCell(seed) }
      rows[slot] = { slot = slot } -- stand-in row frame for the arrow anchor
    end
    return {
      virtual = true, _residentFirst = first, _residentLast = first + n - 1,
      cells = cells, rows = rows,
    }
  end

  local function nameColor(g, slot) return g.cells[slot][NAME].label.color end

  describe("_reapplySelection", function()
    it("golds the selected row's resident slot", function()
      local g = grid(10, 3, WHITE) -- rows 10,11,12
      g._selectedRow = 11          -- slot 2
      DV._reapplySelection(g)
      assert.equal(GOLD, nameColor(g, 2))
    end)

    it("resets slots the selected row scrolled out of, so gold cannot smear", function()
      -- Every resident name cell starts gold, as if the selection had just been scrolled through them.
      local g = grid(10, 3, GOLD)
      g._selectedRow = 11 -- slot 2 is the one that should actually be selected now
      DV._reapplySelection(g)
      assert.equal(WHITE, nameColor(g, 1))
      assert.equal(GOLD, nameColor(g, 2))
      assert.equal(WHITE, nameColor(g, 3))
    end)

    it("clears stray gold even when the selected row is off-screen", function()
      -- The failure scenario's tail: once the selected row scrolls off, ResidentCell returns nil and
      -- nothing re-golds — but the reset walk must still white every resident cell (the smear used to
      -- persist here across further scrolling and filter changes until /reload).
      local g = grid(10, 3, GOLD) -- rows 10..12 resident
      g._selectedRow = 4          -- above the window: not resident
      DV._reapplySelection(g)
      assert.equal(WHITE, nameColor(g, 1))
      assert.equal(WHITE, nameColor(g, 2))
      assert.equal(WHITE, nameColor(g, 3))
    end)

    it("leaves cells untouched when there is no selection", function()
      local g = grid(10, 3, GOLD)
      g._selectedRow = nil
      DV._reapplySelection(g)
      assert.equal(GOLD, nameColor(g, 1)) -- early return, no reset
    end)

    it("anchors the arrow to the resident selected row and hides it off-screen", function()
      local g = grid(10, 3, WHITE)
      g._arrow = fakeArrow()
      g._selectedRow = 12 -- slot 3, resident
      DV._reapplySelection(g)
      assert.is_true(g._arrow.shown)
      assert.equal(g.rows[3], g._arrow.anchored)

      g._selectedRow = 99 -- not resident
      DV._reapplySelection(g)
      assert.is_false(g._arrow.shown)
    end)
  end)

  describe("onRebind forwarding (#921 root cause)", function()
    -- The wrapper must pass TableFrame's resident range through to ns.OnGridRebind, which records it as
    -- _residentFirst for ns.ResidentCell's data-index -> slot math. Dropping it (the pre-#921 bug) left
    -- _residentFirst nil, so under virtualisation ResidentCell always returned nil and the gold name
    -- never resolved a cell. Reverting DataView:onRebind to drop its args fails this test.
    it("passes TableFrame's resident range through to OnGridRebind", function()
      local g = grid(10, 3, WHITE)
      g._refreshMarks = function() end        -- OnGridRebind calls it unconditionally
      ns.AnchorDressedCursor = function() end  -- would walk real cells; irrelevant to this assertion
      DV.onRebind(g, 5, 9)
      assert.equal(5, g._residentFirst)
      assert.equal(9, g._residentLast)
    end)
  end)

  describe("_clearSelection", function()
    it("whites the selected slot, drops the selection and hides the arrow", function()
      local g = grid(10, 3, WHITE)
      g.cells[2][NAME].label.color = GOLD -- slot 2 is currently selected/gold
      g._selectedRow = 11
      g._arrow = fakeArrow()
      g._arrow.shown = true
      ns.HideLockoutView = function() end -- frame-bound in game; a no-op is enough here

      DV._clearSelection(g)
      assert.equal(WHITE, nameColor(g, 2))
      assert.is_nil(g._selectedRow)
      assert.is_false(g._arrow.shown)
    end)
  end)
end)

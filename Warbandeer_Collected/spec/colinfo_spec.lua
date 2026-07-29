local collected = require("Warbandeer_Collected.spec.collected")

-- The armour grid's column layout (`DataView.BuildColInfo`, DataViewFilters.lua).
--
-- One invariant carries this file: **the name column is index 2 in both hosts** (#864). It used to be
-- index 1 for an embedded host and 2 in the `/collected` window, because the lock column was omitted
-- entirely rather than collapsed to zero width. That single asymmetry was the source of every host
-- branch in the grid — the index recomputed in three places, `colInfo` built two ways, the name cell
-- built from two call sites — and it produced three shipped bugs, most recently a one-argument change
-- to the name cell that half-landed and silently dropped the embedded host's hover tooltip (#865).
--
-- So these are not tests of a table builder; they are the guard on the property that let the branches
-- be deleted. If the leading two columns ever stop being (lock, name) in that order for both hosts, the
-- deletions in DataView.lua, DataViewData.lua and CollectedPanel.lua all become silently wrong.

describe("DataView.BuildColInfo", function()
  local ns, CLASSES

  before_each(function()
    ns = collected.loadDataViewFilters(collected.load())
    CLASSES = #ns.icons.classes
  end)

  -- `embedded = true` is how a host says "I own lockouts" — Warbandeer's view; false/nil is the
  -- standalone `/collected` window, which draws the lock glyph itself.
  local function windowed() return ns.DataView.BuildColInfo(false) end
  local function embedded() return ns.DataView.BuildColInfo(true) end

  it("emits the same number of columns for both hosts", function()
    assert.equals(#windowed(), #embedded())
  end)

  it("emits lock + name ahead of one column per class", function()
    assert.equals(CLASSES + 2, #windowed())
    assert.equals(CLASSES + 2, #embedded())
  end)

  -- THE invariant. Asserted as an index rather than by inspecting the column, because the index is
  -- what the deleted branches hard-coded: `ns.FitNameCol(self, 2)`, `_nameColOf` returning 2, and the
  -- row builder inserting the name cell at 2.
  it("puts the name column at index 2 in BOTH hosts", function()
    assert.equals(0, windowed()[2].width, "windowed name column should be the autosized zero-width one")
    assert.equals(0, embedded()[2].width, "embedded name column should be the autosized zero-width one")
  end)

  -- The lock column is always present; only its width tells the two hosts apart. This is the mechanism
  -- that keeps the index above stable, so it is worth pinning separately from the index itself.
  it("keeps the lock column in both hosts, collapsing it to zero width when the host owns lockouts", function()
    assert.equals(15, windowed()[1].width)
    assert.equals(0, embedded()[1].width)
  end)

  it("starts the class columns at index 3 in both hosts", function()
    for i = 3, CLASSES + 2 do
      assert.equals(ns.gridCellWidth, windowed()[i].width, "windowed column " .. i)
      assert.equals(ns.gridCellWidth, embedded()[i].width, "embedded column " .. i)
      -- The class atlas is what makes it a class column rather than another chrome column.
      assert.equals(ns.icons.classes[i - 2], windowed()[i].atlas)
      assert.equals(ns.icons.classes[i - 2], embedded()[i].atlas)
    end
  end)

  -- Guards the one thing that differs between the two leading columns and the class ones: the class
  -- headers carry a hover tooltip naming the class, since a 28px atlas is a guess for the less-played
  -- ones. A chrome column carrying one would tooltip an empty header.
  it("gives every class column a name tooltip and neither chrome column one", function()
    local cols = windowed()
    assert.is_nil(cols[1].tooltip)
    assert.is_nil(cols[2].tooltip)
    for i = 3, CLASSES + 2 do
      assert.equals("Class" .. (i - 2), cols[i].tooltip)
    end
  end)
end)

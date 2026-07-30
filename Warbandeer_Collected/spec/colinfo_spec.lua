local collected = require("Warbandeer_Collected.spec.collected")

-- The armour grid's column layout (`DataView.BuildColInfo`, DataViewFilters.lua).
--
-- One invariant carries this file: **the name column is index 1, the same in every host** (#864). It
-- used to be index 1 for an embedded host and 2 in the `/collected` window, which prepended a lock
-- column the embedded host omitted. That single asymmetry was the source of every host branch in the
-- grid — the index recomputed in three places, `colInfo` built two ways, the name cell built from two
-- call sites — and it produced three shipped bugs, most recently a one-argument change to the name cell
-- that half-landed and silently dropped the embedded host's hover tooltip (#865).
--
-- So these are not tests of a table builder; they are the guard on the property that let those branches
-- be deleted. `ns.FitNameCol(self, 1)`, `ns.ResidentCell(…, 1)` and `ns.PadNameCol(g, 1, …)` all hard-
-- code this index now, and nothing else would notice if the layout grew a leading column again.

describe("DataView.BuildColInfo", function()
  local ns, CLASSES

  before_each(function()
    ns = collected.loadDataViewFilters(collected.load())
    CLASSES = #ns.icons.classes
  end)

  -- Takes no argument since #864. Called with one anyway in one case below, to prove a stray host flag
  -- can't reintroduce a per-host layout by accident.
  local function cols() return ns.DataView.BuildColInfo() end

  it("emits one name column ahead of one column per class", function()
    assert.equals(CLASSES + 1, #cols())
  end)

  -- THE invariant. Asserted as an index rather than by inspecting the column, because the index is what
  -- the deleted branches hard-code across four files.
  it("puts the name column at index 1", function()
    assert.equals(0, cols()[1].width, "the name column is the autosized zero-width one")
    assert.is_nil(cols()[1].atlas, "index 1 must not be a class column")
  end)

  it("starts the class columns at index 2", function()
    for i = 2, CLASSES + 1 do
      assert.equals(ns.gridCellWidth, cols()[i].width, "column " .. i)
      assert.equals(ns.icons.classes[i - 1], cols()[i].atlas)
    end
  end)

  -- The layout no longer varies by host, so any argument must be inert. This is the regression guard on
  -- the collapse itself: if someone reintroduces a per-host branch, the two calls stop matching.
  it("ignores any argument — the layout is the same for every host", function()
    local a, b, c = ns.DataView.BuildColInfo(), ns.DataView.BuildColInfo(true), ns.DataView.BuildColInfo(false)
    assert.equals(#a, #b)
    assert.equals(#a, #c)
    for i = 1, #a do
      assert.equals(a[i].width, b[i].width, "column " .. i .. " width differs when passed true")
      assert.equals(a[i].width, c[i].width, "column " .. i .. " width differs when passed false")
    end
  end)

  -- Guards the one thing that differs between the name column and the class ones: the class headers
  -- carry a hover tooltip naming the class, since a 28px atlas is a guess for the less-played ones. The
  -- name column carrying one would tooltip an empty header.
  it("gives every class column a name tooltip and the name column none", function()
    assert.is_nil(cols()[1].tooltip)
    for i = 2, CLASSES + 1 do
      assert.equals("Class" .. (i - 1), cols()[i].tooltip)
    end
  end)
end)

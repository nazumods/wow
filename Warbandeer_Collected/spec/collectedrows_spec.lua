local collected = require("Warbandeer_Collected.spec.collected")

-- `ns.CollectedRows` (DataViewData.lua) — specifically the seam between a row's shape and the column
-- layout it has to line up with.
--
-- **This is the spec `colinfo_spec.lua` cannot be.** That one pins the column half: how many chrome
-- columns `BuildColInfo` prepends and at what index the name column lands. This one pins the row half
-- and, crucially, that the two agree. Twice (#864) each half was internally consistent while
-- disagreeing with the other — the second time putting class 1 in the name column and rendering the
-- set name as "C…" inside a 28px class column. Every existing spec passed both times.
--
-- The guard is the `#columns == #cells` assertion below plus the name landing at `NAME_COL`. Those two
-- together are what makes adding or removing a chrome column a single edit to `CHROME` rather than a
-- coordinated edit across two files that nothing checks.

describe("CollectedRows", function()
  local ns, CLASSES

  -- Two groups: one with a set for every class, one stopping short (the Vanilla-raid case where the
  -- newest classes have no entry), so the class-padding path is covered too.
  local function seedSets()
    ns.Sets = {
      { id = 100, name = "Full Group", release = 12, category = "Raid",
        sets = { { id = 1, name = "a" }, { id = 2, name = "b" }, { id = 3, name = "c" } } },
      { id = 200, name = "Short Group", release = 11, category = "Dungeon",
        sets = { { id = 4, name = "d" } } },
    }
    -- The scan's two shapes: `true` (base set collected) and a partial count.
    ns.db.sets = {
      [100] = { [1] = true, [2] = { collected = 2, total = 5 }, [3] = true },
      [200] = { [4] = { collected = 0, total = 3 } },
    }
  end

  -- A minimal stand-in for the grid instance the row builder reads flags off. `_reverse = true` matches
  -- `DataView`'s real default (newest expansion first), which decides the row ORDER — the first draft
  -- omitted it, so release 11 sorted ahead of release 12 and every assertion about `rows[1]` was
  -- reading the wrong group.
  local function view(over)
    local v = { _ptr = false, _wantedOnly = false, _expansion = "all", _category = "all",
                embedded = false, _reverse = true }
    for k, val in pairs(over or {}) do v[k] = val end
    return v
  end

  before_each(function()
    ns = collected.loadDataViewData(collected.load())
    CLASSES = #ns.icons.classes
    seedSets()
  end)

  -- THE cross-file invariant. If someone adds a chrome column to `CHROME` and only the layout picks it
  -- up, or only the row builder does, this is what fails.
  it("emits exactly one cell per column the layout declares", function()
    local rows = ns.CollectedRows(view())
    local columns = #ns.DataView.BuildColInfo()
    assert.is_true(#rows > 0, "fixture should produce rows")
    for i, row in ipairs(rows) do
      assert.equals(columns, #row, "row " .. i .. " cell count must match the column count")
    end
  end)

  it("puts the name cell at NAME_COL, carrying the group's name", function()
    local rows = ns.CollectedRows(view())
    local nameCell = rows[1][ns.DataView.NAME_COL]
    assert.is_table(nameCell)
    assert.is_truthy(nameCell.text, "the name cell is the one with text")
    assert.is_truthy(nameCell.text:find("Full Group", 1, true), "got: " .. tostring(nameCell.text))
  end)

  -- The complement: the cell AFTER the chrome must be class 1's, not a chrome cell that drifted. This
  -- is the assertion that would have caught the "C…" bug from the row side.
  --
  -- Identified by `setId`, not by the absence of text: a partially-collected completion cell carries
  -- `text` too (the uncollected count), which is what makes "the one with text" the wrong test — the
  -- first draft of this spec asserted exactly that and failed against a cell reading "3".
  it("starts the class cells immediately after the chrome columns", function()
    local rows = ns.CollectedRows(view())
    local chrome = #rows[1] - CLASSES
    assert.equals(1, chrome, "exactly one chrome cell is expected today")
    assert.equals(1, rows[1][chrome + 1].setId, "class 1's cell should follow the chrome")
  end)

  it("pads short groups out to the full class count", function()
    local rows = ns.CollectedRows(view())
    -- Both rows are the same width regardless of how many classes the group actually lists.
    assert.equals(#rows[1], #rows[2])
  end)

  -- The group's NAME must appear in exactly one cell. A completion cell's `text` is a count, so the
  -- test is "which cell holds the group name", not "which cell holds text" — and one is the answer
  -- whether the name drifts into a class column or a class cell drifts into the name column.
  it("puts the group name in exactly one cell of the row", function()
    local rows = ns.CollectedRows(view())
    local found = 0
    for i, cell in ipairs(rows[1]) do
      if type(cell.text) == "string" and cell.text:find("Full Group", 1, true) then
        found = found + 1
        assert.equals(ns.DataView.NAME_COL, i, "the group name turned up in column " .. i)
      end
    end
    assert.equals(1, found)
  end)
end)

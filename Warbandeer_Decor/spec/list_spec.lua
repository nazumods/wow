local loader = require("Warbandeer_Decor.spec.loader")

-- list.lua's row height and buffer (ROW_H = 28, BUFFER = 4): the window is the rows in view plus
-- four above and below, recycled from one pool.
local ROW_H, BUFFER = 28, 4

local function entries(n)
  local out = {}
  for i = 1, n do out[i] = { recordID = i, name = ("Decor %03d"):format(i) } end
  return out
end

describe("Warbandeer_Decor list windowing (_window)", function()
  local List, newList
  before_each(function() local _; List, _, newList = loader.loadList() end)

  -- Which entry indexes the pool currently shows, read back off each shown row.
  local function shownIdx(list)
    local idx = {}
    for _, row in ipairs(list._rows) do
      if row.shown then idx[#idx + 1] = row._item.recordID end
    end
    return idx
  end

  it("hides every pooled row and builds none when nothing is shown", function()
    local list = newList{ shown = {}, viewH = 280, offset = 0 }
    list._rows[1] = { shown = true, Hide = function(self) self.shown = false end }
    List._window(list)
    assert.is_false(list._rows[1].shown)
    assert.equals(1, #list._rows)
  end)

  it("at the top builds the viewport's rows plus the trailing buffer, not the whole list", function()
    local list = newList{ shown = entries(100), viewH = 280, offset = 0 }
    List._window(list)
    -- first = 1; last = first + ceil(280/28) + 2*BUFFER - 1 = 1 + 10 + 8 - 1 = 18
    local idx = shownIdx(list)
    assert.equals(1, idx[1])
    assert.equals(18, idx[#idx])
    assert.equals(18, #list._rows)
  end)

  it("scrolled into the middle starts BUFFER rows above the first visible row", function()
    local list = newList{ shown = entries(100), viewH = 280, offset = 50 * ROW_H }
    List._window(list)
    local idx = shownIdx(list)
    assert.equals(50 + 1 - BUFFER, idx[1])   -- 47
    assert.equals(64, idx[#idx])             -- 47 + 10 + 8 - 1
  end)

  it("clamps the last row to the list length at the bottom", function()
    local list = newList{ shown = entries(100), viewH = 280, offset = 100 * ROW_H }
    List._window(list)
    local idx = shownIdx(list)
    assert.equals(100, idx[#idx])
    assert.equals(100 + 1 - BUFFER, idx[1])
  end)

  it("a list shorter than the window shows every entry", function()
    local list = newList{ shown = entries(3), viewH = 280, offset = 0 }
    List._window(list)
    assert.same({ 1, 2, 3 }, shownIdx(list))
  end)

  it("positions each row at its absolute offset in the full-height scroll child", function()
    local list = newList{ shown = entries(100), viewH = 280, offset = 50 * ROW_H }
    List._window(list)
    local row = list._rows[1]            -- entry 47
    assert.equals(47, row._item.recordID)
    assert.equals(-(47 - 1) * ROW_H, row.points[1][5])
    assert.equals(ROW_H, row.height)
  end)

  it("falls back to the list's own height when the scroll frame has not been sized yet", function()
    local list = newList{ shown = entries(100), viewH = 0, selfH = 280, offset = 0 }
    List._window(list)
    assert.equals(18, #shownIdx(list))
  end)

  it("hides pooled rows beyond the new window when the list shrinks", function()
    local list = newList{ shown = entries(100), viewH = 280, offset = 0 }
    List._window(list)
    assert.equals(18, #shownIdx(list))
    list._shown = entries(5)
    List._window(list)
    assert.same({ 1, 2, 3, 4, 5 }, shownIdx(list))
    assert.equals(18, #list._rows)       -- pooled, never destroyed
  end)

  it("reuses the same pooled frames as the window moves", function()
    local list = newList{ shown = entries(100), viewH = 280, offset = 0 }
    List._window(list)
    local first = list._rows[1]
    list.scroll.VerticalScroll = function() return 50 * ROW_H end
    List._window(list)
    assert.equals(first, list._rows[1])
    assert.equals(47, first._item.recordID)
  end)
end)

describe("Warbandeer_Decor list filters (GetItems)", function()
  local List, ns, newList
  before_each(function()
    List, ns, newList = loader.loadList()
    ns._entries = {
      { recordID = 1, name = "Zebra Rug",    owned = true,  categoryIDs = { 10 }, subcategoryIDs = { 100 } },
      { recordID = 2, name = "Apple Crate",  owned = false, categoryIDs = { 10, 11 }, subcategoryIDs = { 101 } },
      { recordID = 3, name = "Brass Lamp",   owned = false, categoryIDs = { 12 }, subcategoryIDs = { 100 } },
      { recordID = 4, name = "Plain Table",  owned = true },
    }
  end)

  local function names(list)
    local out = {}
    for _, e in ipairs(List.GetItems(list)) do out[#out + 1] = e.name end
    return out
  end

  it("returns everything, sorted by name, with no filters", function()
    assert.same({ "Apple Crate", "Brass Lamp", "Plain Table", "Zebra Rug" }, names(newList{}))
  end)

  it("filters by category, matching any of an entry's categoryIDs", function()
    assert.same({ "Apple Crate", "Zebra Rug" }, names(newList{ filters = { _category = 10 } }))
    assert.same({ "Apple Crate" }, names(newList{ filters = { _category = 11 } }))
  end)

  it("a category filter excludes entries with no categoryIDs at all", function()
    assert.same({ "Brass Lamp" }, names(newList{ filters = { _category = 12 } }))
  end)

  it("filters by subcategory, combined with category", function()
    assert.same({ "Brass Lamp", "Zebra Rug" }, names(newList{ filters = { _subcategory = 100 } }))
    assert.same({ "Zebra Rug" }, names(newList{ filters = { _category = 10, _subcategory = 100 } }))
  end)

  it("uncollected-only drops owned entries", function()
    assert.same({ "Apple Crate", "Brass Lamp" }, names(newList{ filters = { _uncollected = true } }))
  end)

  it("wanted-only keeps just the flagged entries", function()
    ns.wanted[3] = true
    assert.same({ "Brass Lamp" }, names(newList{ filters = { _wantedOnly = true } }))
  end)

  it("search is a case-insensitive plain substring on the name", function()
    -- the list stores the search lowercased; the entry name is lowercased at compare time
    assert.same({ "Apple Crate" }, names(newList{ filters = { _search = "crate" } }))
    assert.same({ "Apple Crate", "Plain Table" }, names(newList{ filters = { _search = "pl" } }))
  end)

  it("a search with Lua pattern characters matches literally", function()
    ns._entries[1].name = "Rug (Large)"
    assert.same({ "Rug (Large)" }, names(newList{ filters = { _search = "(large)" } }))
    assert.same({}, names(newList{ filters = { _search = "." } }))
  end)

  it("stacks every filter", function()
    ns.wanted[2] = true
    assert.same({ "Apple Crate" }, names(newList{
      filters = { _category = 10, _uncollected = true, _wantedOnly = true, _search = "apple" } }))
  end)
end)

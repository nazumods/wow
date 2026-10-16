local wb = require("Warbandeer.spec.warbandeer")

-- #958 follow-up: the Races tab handles races the race tables do not know. The REAL
-- views/RaceView.lua runs against a fake TableFrame: addRow records each physical row, and
-- self.data[row][classCol] holds the cell shown for a character. Nothing proves a frame renders.
describe("Warbandeer RaceView", function()
  after_each(function() wb.restoreGlobals() end)

  local ALLIANCE = { "Human", "Dwarf", "Haranir" }
  local HORDE = { "Orc", "Undead", "Haranir" }
  local A_COLOR, H_COLOR = { "alliance" }, { "horde" }

  local function toon(name, class, race, isAlliance, raceIdx, raceId)
    return { name = name, classKey = class, race = race, isAlliance = isAlliance, raceIdx = raceIdx, raceId = raceId }
  end

  -- Build the view for `toons` and return its physical rows ({ label, color, cells = {name...} }).
  local function build(toons, opts)
    opts = opts or {}
    local dividerParents = {}
    -- the real ui table is a UI library; the divider is the only Texture the view creates
    local ui = setmetatable({
      Texture = { new = function(_, o) dividerParents[#dividerParents + 1] = o.parent end },
    }, { __index = function() return wb.anything() end })
    local ns = wb.loadFlavored(opts.flavor or "forever", { "views/RaceView.lua" }, {
      globals = {
        gsub = string.gsub,
        PLAYER_FACTION_COLOR_ALLIANCE = A_COLOR,
        PLAYER_FACTION_COLOR_HORDE = H_COLOR,
        C_CreatureInfo = { GetRaceInfo = opts.getRaceInfo or function() return nil end },
      },
      ns = { ui = ui, api = {
        ALLIANCE_RACES = ALLIANCE, HORDE_RACES = HORDE,
        GetAllCharacters = function() return toons end,
      } },
    })
    local added = {}
    local self = {
      headerWidth = 135, headerHeight = 20, data = {}, rows = added,
      rowArea = { TopLeft = function() end, Width = function() end, Height = function() return 0 end },
      addCol = function() end,
      addRow = function(s, row) added[#added + 1] = row; return s end,
      Width = function() end, Height = function() end, update = function() end,
    }
    assert(ns.views.RaceView, "RaceView did not register")
    ns.views.RaceView.__ctor(self)
    local rows = {}
    for i, r in ipairs(added) do
      local cells = {}
      for col, cell in pairs(self.data[i] or {}) do cells[#cells + 1] = col .. ":" .. cell.text end
      table.sort(cells)
      rows[i] = { label = r.name, color = r.color, cells = cells }
    end
    -- the physical row the Alliance/Horde divider is drawn under
    for i, r in ipairs(added) do
      if r == dividerParents[1] then rows.dividerRow = i end
    end
    return rows
  end

  local function labels(rows)
    local out = {}
    for i, r in ipairs(rows) do out[i] = r.label end
    return out
  end

  local function rowOf(rows, label)
    for i, r in ipairs(rows) do if r.label == label then return i, r end end
  end

  it("an Alliance character with an unknown race gets its own Alliance row", function()
    local rows
    assert.has_no.errors(function()
      rows = build({ toon("Sky", "Priest", "Skyborne", true, 0, 95) })
    end)
    local i, row = rowOf(rows, "Skyborne")
    assert.is_not_nil(i)
    assert.equals(A_COLOR, row.color)
    assert.same({ "1:Sky" }, row.cells)
    -- after the known Alliance races, before the Horde ones
    assert.equals(#ALLIANCE + 1, i)
    assert.equals("Orc", rows[i + 1].label)
  end)

  it("a Horde character with an unknown race gets its own Horde row, not Haranir", function()
    local rows = build({ toon("Sky", "Priest", "Skyborne", false, 0, 96) })
    local i, row = rowOf(rows, "Skyborne")
    assert.equals(H_COLOR, row.color)
    assert.same({ "1:Sky" }, row.cells)
    assert.equals(#rows, i)                 -- after the Horde known races
    for _, r in ipairs(rows) do
      if r.label == "Haranir" then assert.same({}, r.cells) end  -- neither Haranir row got it
    end
  end)

  it("two characters of the same unknown race share one row group", function()
    local rows = build({
      toon("A", "Priest", "Skyborne", true, 0, 95),
      toon("B", "Priest", "Skyborne", true, 0, 95),
      toon("C", "Mage", "Skyborne", true, 0, 95),
    })
    local count = 0
    for _, r in ipairs(rows) do if r.label == "Skyborne" then count = count + 1 end end
    assert.equals(1, count)
    local i = rowOf(rows, "Skyborne")
    assert.equals("", rows[i + 1].label)   -- the second Priest stacks beneath the label
    assert.equals(#ALLIANCE + 2, i + 1)
    assert.equals("Orc", rows[i + 2].label)
  end)

  it("different unknown races of one faction get separate rows, in name order", function()
    local rows = build({
      toon("A", "Priest", "Zeta", true, 0, 201),
      toon("B", "Priest", "Alpha", true, 0, 202),
    })
    local a, z = rowOf(rows, "Alpha"), rowOf(rows, "Zeta")
    assert.is_true(a < z)
    assert.equals(#ALLIANCE + 1, a)
  end)

  it("an unknown race is labelled with the client's race name when it has one, else the saved one", function()
    local withInfo = build({ toon("Sky", "Priest", "Skyborne", true, 0, 95) }, {
      getRaceInfo = function(id) return id == 95 and { raceName = "Himmelsgeboren" } or nil end,
    })
    assert.is_not_nil(rowOf(withInfo, "Himmelsgeboren"))
    assert.is_nil(rowOf(withInfo, "Skyborne"))
    local without = build({ toon("Sky", "Priest", "Skyborne", true, 0, 95) })
    assert.is_not_nil(rowOf(without, "Skyborne"))
  end)

  it("the Alliance/Horde divider sits under the last Alliance row, unknown races included", function()
    assert.equals(#ALLIANCE, build({ toon("H", "Priest", "Human", true, 1, 1) }).dividerRow)
    local rows = build({
      toon("Sky", "Priest", "Skyborne", true, 0, 95),
      toon("Hsky", "Priest", "Hordesky", false, 0, 96),
    })
    assert.equals(#ALLIANCE + 1, rows.dividerRow)   -- under "Skyborne", above "Orc"
    assert.equals("Skyborne", rows[rows.dividerRow].label)
  end)

  it("a character with no faction flag stays on the Horde side, as before", function()
    local rows = build({ toon("N", "Priest", "Orc", nil, 1, 2) })
    assert.same({ "1:N" }, rows[#ALLIANCE + 1].cells)
    assert.equals("Orc", rows[#ALLIANCE + 1].label)
  end)

  it("a raceIdx beyond the table is treated as unknown too", function()
    local rows = build({ toon("Sky", "Priest", "Skyborne", true, 99, 95) })
    assert.is_not_nil(rowOf(rows, "Skyborne"))
  end)

  it("known races are unchanged: same rows, same order, characters on their own race row", function()
    local rows = build({
      toon("H", "Priest", "Human", true, 1, 1),
      toon("O", "Priest", "Orc", false, 1, 2),
      toon("HU", "Mage", "Haranir", false, 3, 91),
    }, { flavor = "retail" })
    assert.same({ "Human", "Dwarf", "Haranir", "Orc", "Undead", "Haranir" }, labels(rows))
    assert.same({ "1:H" }, rows[1].cells)
    assert.same({ "1:O" }, rows[4].cells)
    assert.same({ "2:HU" }, rows[6].cells)   -- the HORDE Haranir row, not the Alliance one
    assert.same({}, rows[3].cells)
  end)
end)

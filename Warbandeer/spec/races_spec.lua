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
        ALLIANCE_RACES = opts.races and opts.races.ALLIANCE_RACES or ALLIANCE,
        HORDE_RACES = opts.races and opts.races.HORDE_RACES or HORDE,
        GetAllCharacters = function() return toons end,
      } },
    })
    local added, cols = {}, {}
    local self = {
      headerWidth = 135, headerHeight = 20, data = {}, rows = added,
      rowArea = { TopLeft = function() end, Width = function() end, Height = function() return 0 end },
      addCol = function(_, col) cols[#cols + 1] = col.name end,
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
      rows[i] = { label = r.name, color = r.color, cells = cells, zebra = r.backdrop.color[4] }
    end
    -- the physical row the Alliance/Horde divider is drawn under
    for i, r in ipairs(added) do
      if r == dividerParents[1] then rows.dividerRow = i end
    end
    rows.cols = cols
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
    -- Alliance rows are Alliance-coloured, Horde rows Horde-coloured; the zebra alternates by row group
    for i = 1, 6 do
      assert.equals(i <= 3 and A_COLOR or H_COLOR, rows[i].color, "row " .. i)
      assert.equals(i % 2 == 0 and 0.2 or 0, rows[i].zebra, "row " .. i)
    end
  end)

  -- #958: the REAL race tables (Warbandeer_Characters/data/races.lua against the real flavor.lua), read by the tab.
  local function realRaces(flavor)
    local cns = { api = {} }
    require("LibNAddOn.spec.libn").load({ flavor = flavor }).linkFlavor(cns)
    assert(loadfile("Warbandeer_Characters/data/races.lua"))("Warbandeer_Characters", cns)
    return cns.api
  end

  -- Forever's Skyborne keep raceIdx 0 (Warbandeer_Characters/spec/forever_races_spec.lua pins that), with the
  -- race token "Skyborne" and the client's faction.
  it("Forever: the tab lists Forever's races only, an Alliance Skyborne on its row, the Horde Skyborne row empty", function()
    local rows = build({ toon("Sky", "Priest", "Skyborne", true, 0, 95) }, { races = realRaces("forever") })
    assert.same({ "Human", "Dwarf", "Night Elf", "Gnome", "Skyborne", "Orc", "Undead", "Tauren", "Troll", "Skyborne" },
      labels(rows))
    assert.same({ "1:Sky" }, rows[5].cells)
    assert.equals(A_COLOR, rows[5].color)
    assert.same({}, rows[10].cells)          -- the Horde Skyborne row shows with no character on it
    assert.equals(H_COLOR, rows[10].color)
    assert.equals(5, rows.dividerRow)
  end)

  it("Forever: a Horde Skyborne character lands on the Horde Skyborne row", function()
    local rows = build({ toon("Windy", "Mage", "Skyborne", false, 0, 96) }, { races = realRaces("forever") })
    assert.equals(10, #rows)
    assert.same({ "2:Windy" }, rows[10].cells)
    assert.same({}, rows[5].cells)
  end)

  it("Forever: several Skyborne on one side share its Skyborne row, with no second Skyborne row", function()
    local rows = build({
      toon("A", "Priest", "Skyborne", true, 0, 95),
      toon("B", "Mage", "Skyborne", true, 0, 95),
      toon("C", "Priest", "Skyborne", true, 0, 95),
    }, { races = realRaces("forever"), getRaceInfo = function() return { raceName = "High Order Skyborne" } end })
    assert.equals(11, #rows)                 -- the second Priest stacks beneath the Alliance Skyborne label
    assert.same({ "1:A", "2:B" }, rows[5].cells)
    assert.same({ "1:C" }, rows[6].cells)
    assert.equals("", rows[6].label)
    assert.is_nil(rowOf(rows, "High Order Skyborne"))
  end)

  it("Forever: the grid has columns for the original nine classes only", function()
    local rows = build({}, { races = realRaces("forever") })
    assert.same({ "Priest", "Mage", "Warlock", "Druid", "Rogue", "Hunter", "Shaman", "Paladin", "Warrior" }, rows.cols)
  end)

  it("Retail: the tab still lists every Retail race and all 13 class columns", function()
    local rows = build({}, { flavor = "retail", races = realRaces("retail") })
    assert.equals(30, #rows)
    assert.equals("Human", rows[1].label)
    assert.equals("Haranir", rows[15].label)
    assert.equals("Orc", rows[16].label)
    assert.is_nil(rowOf(rows, "Skyborne"))
    assert.equals(13, #rows.cols)
    assert.equals("Demon Hunter", rows.cols[4])
  end)

  it("a character with no index joins its own side's row named by its race token (a neutral Pandaren)", function()
    local rows = build({ toon("P", "Monk", "Pandaren", false, 0, 24) }, { flavor = "retail", races = realRaces("retail") })
    assert.equals(30, #rows)                 -- no row of its own
    assert.same({ "6:P" }, rows[22].cells)   -- the Horde Pandaren row (15 Alliance + 7)
    assert.same({}, rows[7].cells)           -- not the Alliance one
  end)

  it("the race-token match stays on the character's own side", function()
    local rows = build({ toon("X", "Priest", "Orc", true, 0, 999) }, { flavor = "retail", races = realRaces("retail") })
    assert.equals(31, #rows)                 -- an Alliance group of its own, after the Alliance races
    assert.same({ "1:X" }, rows[16].cells)
    assert.equals("Orc", rows[16].label)
    assert.equals(A_COLOR, rows[16].color)
    assert.same({}, rows[17].cells)          -- the Horde Orc row
  end)

  it("an empty client race name falls back to the saved one", function()
    local rows = build({ toon("Sky", "Priest", "Skyborne", true, 0, 95) }, {
      getRaceInfo = function() return { raceName = "" } end,
    })
    assert.is_not_nil(rowOf(rows, "Skyborne"))
  end)
end)

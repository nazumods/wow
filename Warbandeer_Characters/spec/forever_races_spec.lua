-- #958: on Forever the race tables list only Forever's races (the original eight and the Skyborne, one per
-- faction); the id map keeps the original eight at their Retail indexes and leaves every other id, the Skyborne
-- included, at raceIdx 0 (the value earlier revisions stored, so a rollback reads the same data). Retail's
-- tables are unchanged. data/races.lua loads for real, against the REAL LibNAddOn/flavor.lua.
-- luacheck: globals describe it before_each after_each

local libn = require("LibNAddOn.spec.libn")

local RETAIL_ALLIANCE = { "Human", "Dwarf", "Night Elf", "Gnome", "Draenei", "Worgen", "Pandaren", "Void Elf",
  "Lightforged Draenei", "Dark Iron Dwarf", "Kul Tiran", "Mechagnome", "Dracthyr", "Earthen", "Haranir" }
local RETAIL_HORDE = { "Orc", "Undead", "Tauren", "Troll", "Blood Elf", "Goblin", "Pandaren", "Nightborne",
  "Highmountain Tauren", "Mag'har Orc", "Zandalari Troll", "Vulpera", "Dracthyr", "Earthen", "Haranir" }

describe("Warbandeer_Characters races on Forever (#958)", function()
  local saved

  before_each(function()
    saved = _G.C_CreatureInfo
    -- NormalizeRaceId reads the faction from the client for a race id its table does not map
    local factions = { [10] = "Horde", [11] = "Alliance", [95] = "Alliance", [96] = "Horde" }
    _G.C_CreatureInfo = {
      GetFactionInfo = function(id) return factions[id] and { groupTag = factions[id] } or nil end,
    }
  end)

  after_each(function() _G.C_CreatureInfo = saved end)

  -- A fresh Warbandeer_Characters namespace with data/races.lua loaded for `flavor`.
  local function races(flavor)
    local ns = { api = {} }
    libn.load({ flavor = flavor }).linkFlavor(ns)
    assert(loadfile("Warbandeer_Characters/data/races.lua"))("Warbandeer_Characters", ns)
    return ns
  end

  it("Forever: the tables list Forever's races only, the Skyborne last on each side", function()
    local ns = races("forever")
    assert.same({ "Human", "Dwarf", "Night Elf", "Gnome", "Skyborne" }, ns.api.ALLIANCE_RACES)
    assert.same({ "Orc", "Undead", "Tauren", "Troll", "Skyborne" }, ns.api.HORDE_RACES)
  end)

  it("Forever: the original eight races keep their Retail index, faction and name", function()
    local forever, retail = races("forever"), races("retail")
    for id = 1, 8 do
      local fIdx, fAlly = forever.NormalizeRaceId(id)
      local rIdx, rAlly = retail.NormalizeRaceId(id)
      assert.same({ rIdx, rAlly }, { fIdx, fAlly }, "race id " .. id)
      assert.is_true(fIdx > 0, "race id " .. id)
      local list = function(ns) return fAlly and ns.api.ALLIANCE_RACES or ns.api.HORDE_RACES end
      assert.equals(list(retail)[rIdx], list(forever)[fIdx], "race id " .. id)
    end
  end)

  it("Forever: both Skyborne ids keep raceIdx 0, their faction read from the client", function()
    local ns = races("forever")
    assert.same({ 0, true }, { ns.NormalizeRaceId(95) })    -- High Order Skyborne
    assert.same({ 0, false }, { ns.NormalizeRaceId(96) })   -- Windshaper Skyborne
  end)

  it("Forever: a Retail-only race is unknown too, on whichever side the client says", function()
    local ns = races("forever")
    assert.same({ 0, false }, { ns.NormalizeRaceId(10) })   -- Blood Elf
    assert.same({ 0, true }, { ns.NormalizeRaceId(11) })    -- Draenei
  end)

  it("Retail: the tables and id map are unchanged", function()
    local ns = races("retail")
    assert.same(RETAIL_ALLIANCE, ns.api.ALLIANCE_RACES)
    assert.same(RETAIL_HORDE, ns.api.HORDE_RACES)
    assert.same({ 5, false }, { ns.NormalizeRaceId(10) })   -- Blood Elf
    assert.same({ 5, true }, { ns.NormalizeRaceId(11) })    -- Draenei
    assert.same({ 0, true }, { ns.NormalizeRaceId(95) })
  end)
end)

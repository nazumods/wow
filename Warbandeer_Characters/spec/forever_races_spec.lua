-- #958: on Forever the race tables list only Forever's races (the original eight and the Skyborne, one per
-- faction) and NormalizeRaceId maps both Skyborne ids; Retail's tables are unchanged. database.lua's login
-- refresh recomputes a stored race index, so a record made before the tables knew a race is corrected.
-- data/races.lua and database.lua are loaded for real, against the REAL LibNAddOn/flavor.lua.
-- luacheck: globals describe it before_each after_each

local libn = require("LibNAddOn.spec.libn")

local GLOBALS = { "C_CreatureInfo", "UnitClassBase", "UnitSex", "UnitGUID", "GetGuildInfo", "GetRealmName" }

local RETAIL_ALLIANCE = { "Human", "Dwarf", "Night Elf", "Gnome", "Draenei", "Worgen", "Pandaren", "Void Elf",
  "Lightforged Draenei", "Dark Iron Dwarf", "Kul Tiran", "Mechagnome", "Dracthyr", "Earthen", "Haranir" }
local RETAIL_HORDE = { "Orc", "Undead", "Tauren", "Troll", "Blood Elf", "Goblin", "Pandaren", "Nightborne",
  "Highmountain Tauren", "Mag'har Orc", "Zandalari Troll", "Vulpera", "Dracthyr", "Earthen", "Haranir" }

describe("Warbandeer_Characters races on Forever (#958)", function()
  local saved

  before_each(function()
    saved = {}
    for _, name in ipairs(GLOBALS) do saved[name] = _G[name] end
    -- NormalizeRaceId reads the faction from the client for a race id its table does not know
    local factions = { [10] = "Horde", [95] = "Alliance", [96] = "Horde" }
    _G.C_CreatureInfo = {
      GetFactionInfo = function(id) return factions[id] and { groupTag = factions[id] } or nil end,
    }
  end)

  after_each(function()
    for _, name in ipairs(GLOBALS) do _G[name] = saved[name] end
  end)

  -- A fresh Warbandeer_Characters namespace with data/races.lua loaded for `flavor`.
  local function races(flavor)
    local ns = { api = {} }
    libn.load({ flavor = flavor }).linkFlavor(ns)
    assert(loadfile("Warbandeer_Characters/data/races.lua"))("Warbandeer_Characters", ns)
    return ns
  end

  describe("the race tables", function()
    it("Forever: list Forever's races only, the Skyborne last on each side", function()
      local ns = races("forever")
      assert.same({ "Human", "Dwarf", "Night Elf", "Gnome", "Skyborne" }, ns.api.ALLIANCE_RACES)
      assert.same({ "Orc", "Undead", "Tauren", "Troll", "Skyborne" }, ns.api.HORDE_RACES)
    end)

    it("Forever: the Alliance and Horde Skyborne ids map to their own faction's Skyborne row", function()
      local ns = races("forever")
      assert.same({ 5, true }, { ns.NormalizeRaceId(95) })
      assert.same({ 5, false }, { ns.NormalizeRaceId(96) })
    end)

    it("Forever: the original eight races keep their Retail index, faction and name", function()
      local forever, retail = races("forever"), races("retail")
      for id = 1, 8 do
        local fIdx, fAlly = forever.NormalizeRaceId(id)
        local rIdx, rAlly = retail.NormalizeRaceId(id)
        assert.same({ rIdx, rAlly }, { fIdx, fAlly }, "race id " .. id)
        local list = function(ns) return fAlly and ns.api.ALLIANCE_RACES or ns.api.HORDE_RACES end
        assert.equals(list(retail)[rIdx], list(forever)[fIdx], "race id " .. id)
      end
    end)

    it("Forever: a Retail-only race is unknown (raceIdx 0), its faction read from the client", function()
      assert.same({ 0, false }, { races("forever").NormalizeRaceId(10) })   -- Blood Elf
    end)

    it("Retail: the tables are unchanged, and a Skyborne id is unknown there", function()
      local ns = races("retail")
      assert.same(RETAIL_ALLIANCE, ns.api.ALLIANCE_RACES)
      assert.same(RETAIL_HORDE, ns.api.HORDE_RACES)
      assert.same({ 0, true }, { ns.NormalizeRaceId(95) })
      assert.same({ 5, false }, { ns.NormalizeRaceId(10) })                -- Blood Elf, as before
    end)
  end)

  describe("the login refresh", function()
    -- data/races.lua and database.lua for `flavor`, with `characters` as the saved records and the logged-in
    -- character's UnitRace answering (raceFile, raceId).
    local function login(flavor, characters, name, raceFile, raceId)
      local ns = races(flavor)
      local count = 0
      for _ in pairs(characters) do count = count + 1 end
      ns.db = { characters = characters, numCharacters = count }
      ns.wow = {
        ClassKeyByToken = { MAGE = "Mage" },
        Player = {
          GetName = function() return name end,
          GetRace = function() return raceFile, raceId end,
          GetClassId = function() return 8 end,
          GetClassName = function() return "Mage" end,
        },
      }
      local noop = function() end
      ns.registerCommand, ns.registerEvent, ns.RegisterMissing = noop, noop, noop
      ns.InitBrokers, ns.InitWarband, ns.InitAchievements, ns.InitTitleCatalog, ns.InitClassCollectibles =
        noop, noop, noop, noop, noop
      _G.UnitClassBase = function() return "Mage", "MAGE", 8 end
      _G.UnitSex = function() return 3 end
      _G.UnitGUID = function() return "Player-1-1" end
      _G.GetGuildInfo = function() return nil end
      _G.GetRealmName = function() return "Realm" end
      assert(loadfile("Warbandeer_Characters/database.lua"))("Warbandeer_Characters", ns)
      ns:initialize()
      return ns
    end

    it("Forever: a Skyborne record saved with raceIdx 0 gets its Skyborne index at the next login", function()
      local ns = login("forever", {
        Vaelithra = { name = "Vaelithra", race = "Skyborne", raceId = 95, raceIdx = 0, isAlliance = true },
      }, "Vaelithra", "Skyborne", 95)
      local c = ns.db.characters.Vaelithra
      assert.equals(5, c.raceIdx)
      assert.is_true(c.isAlliance)
      assert.equals(1, ns.db.numCharacters)
    end)

    it("Forever: a new Horde Skyborne record gets its race, id, Skyborne index and faction", function()
      local ns = login("forever", {}, "Windy", "Skyborne", 96)
      local c = ns.db.characters.Windy
      assert.same({ "Skyborne", 96, 5, false }, { c.race, c.raceId, c.raceIdx, c.isAlliance })
      assert.equals(1, ns.db.numCharacters)
    end)

    it("Retail: a known race is unchanged by the refresh", function()
      local ns = login("retail", {
        Hu = { name = "Hu", race = "Human", raceId = 1, raceIdx = 1, isAlliance = true },
      }, "Hu", "Human", 1)
      local c = ns.db.characters.Hu
      assert.same({ "Human", 1, 1, true }, { c.race, c.raceId, c.raceIdx, c.isAlliance })
    end)
  end)
end)

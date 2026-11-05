-- Which ns.db.profiles key a character's bar profiles live under (#1014): the bare name stays the key (old
-- saves restore, older revisions keep working); a same-named character on another realm gets "Name-Realm"
-- instead of overwriting the first one's snapshot.

-- luacheck: globals describe it before_each

local bars = require("Warbandeer_Bars.spec.bars")

local function env(overrides)
  local e = {
    GetActionInfo = function() return nil end,
    C_PetJournal = {}, C_SpecializationInfo = {
      GetSpecialization = function() return 1 end,
      GetSpecializationInfo = function() return 62, "Arcane", "", 1 end,
    },
    UnitName = function() return "Lurias" end,
    UnitGUID = function() return "Player-2-BBB" end,
    UnitClass = function() return "Mage", "MAGE", 8 end,
    UnitLevel = function() return 80 end,
    GetRealmName = function() return "Area 52" end,
    GetNormalizedRealmName = function() return "Area52" end,
    GetCurrentBindingSet = function() return 1 end,
    time = function() return 1700000000 end,
  }
  for k, v in pairs(overrides or {}) do e[k] = v end
  return e
end

describe("ns.ProfileKey (#1014)", function()
  local key

  before_each(function()
    key = bars.loadCapture(env()).ProfileKey
  end)

  local function profiles(name, guid, realm, class)
    return { [name] = { [62] = { guid = guid, realm = realm, class = class } } }
  end

  it("uses the bare name when nothing is stored", function()
    assert.equal("Lurias", key({}, "Lurias", "Area52", "Player-2-BBB", "MAGE"))
  end)

  it("keeps the bare name for the same character (same GUID)", function()
    assert.equal("Lurias", key(profiles("Lurias", "Player-2-BBB", "Area 52", "MAGE"), "Lurias", "Area52", "Player-2-BBB", "MAGE"))
  end)

  it("qualifies a same-named character on another realm with another GUID and another class", function()
    local p = profiles("Lurias", "Player-1-AAA", "Draenor", "HUNTER")
    assert.equal("Lurias-Area52", key(p, "Lurias", "Area52", "Player-2-BBB", "MAGE"))
  end)

  it("a realm transfer (new realm, new GUID, same class) keeps the existing profiles", function()
    local p = profiles("Lurias", "Player-1-AAA", "Draenor", "MAGE")
    assert.equal("Lurias", key(p, "Lurias", "Area52", "Player-2-BBB", "MAGE"))
  end)

  it("a re-created character on the same realm keeps the existing profiles", function()
    local p = profiles("Lurias", "Player-1-AAA", "Area 52", "HUNTER")
    assert.equal("Lurias", key(p, "Lurias", "Area52", "Player-2-BBB", "MAGE"))
  end)

  it("a profile stored before GUIDs were captured compares realms (spaces ignored) and class", function()
    assert.equal("Lurias", key(profiles("Lurias", nil, "Area 52", "HUNTER"), "Lurias", "Area52", "Player-2-BBB", "MAGE"))
    assert.equal("Lurias-Area52", key(profiles("Lurias", nil, "Draenor", "HUNTER"), "Lurias", "Area52", "Player-2-BBB", "MAGE"))
  end)

  it("keeps using an existing Name-Realm key", function()
    local p = {
      Lurias = { [62] = { guid = "Player-1-AAA" } },
      ["Lurias-Area52"] = { [62] = { guid = "Player-2-BBB" } },
    }
    assert.equal("Lurias-Area52", key(p, "Lurias", "Area52", "Player-2-BBB", "MAGE"))
    assert.equal("Lurias", key(p, "Lurias", "Draenor", "Player-1-AAA", "HUNTER"))
  end)

  it("a stored profile with no realm or class is assumed to be the same character", function()
    assert.equal("Lurias", key({ Lurias = { [62] = {} } }, "Lurias", "Area52", "Player-2-BBB", "MAGE"))
  end)

  it("without a realm there is nothing to qualify with", function()
    assert.equal("Lurias", key(profiles("Lurias", "Player-1-AAA", "Draenor", "HUNTER"), "Lurias", nil, "Player-2-BBB", "MAGE"))
  end)
end)

describe("captured profile key (#1014)", function()
  it("an alt of the same name on another realm is captured under Name-Realm and records its GUID", function()
    local ns = bars.loadCapture(env())
    ns.db = { profiles = { Lurias = { [62] = { guid = "Player-1-AAA", realm = "Draenor", class = "HUNTER" } } } }
    local profile = ns.Capture({ bars = true })
    assert.equal("Lurias-Area52", profile.char)
    assert.equal("Player-2-BBB", profile.guid)
    assert.equal("Lurias-Area52", ns.CurrentProfileKey())
  end)

  it("defers to Warbandeer_Characters\' key when it is loaded, so the two addons always agree", function()
    local prior = _G.WarbandeerApi
    _G.WarbandeerApi = { GetCurrentCharacter = function() return "Lurias-Area52" end }
    local ns = bars.loadCapture(env())
    ns.db = { profiles = { Lurias = { [62] = { guid = "Player-2-BBB", realm = "Area 52", class = "MAGE" } } } }
    local key = ns.CurrentProfileKey() -- own rule alone would say the bare "Lurias"
    _G.WarbandeerApi = prior
    assert.equal("Lurias-Area52", key)
  end)

  it("falls back to its own rule when Characters has no current character", function()
    local prior = _G.WarbandeerApi
    _G.WarbandeerApi = { GetCurrentCharacter = function() return nil end }
    local ns = bars.loadCapture(env())
    ns.db = { profiles = {} }
    local key = ns.CurrentProfileKey()
    _G.WarbandeerApi = prior
    assert.equal("Lurias", key)
  end)

  it("an existing save keeps its bare key", function()
    local ns = bars.loadCapture(env())
    ns.db = { profiles = { Lurias = { [62] = { guid = "Player-2-BBB" } } } }
    assert.equal("Lurias", ns.Capture({ bars = true }).char)
  end)
end)

describe("Warbandeer_Bars API default character (#1014)", function()
  it("reads the current character's profiles under the qualified key", function()
    local ns = bars.loadApi()
    ns.CurrentProfileKey = function() return "Lurias-Area52" end
    ns.db.profiles = {
      Lurias = { [62] = { spec = "Arcane" } },
      ["Lurias-Area52"] = { [62] = { spec = "Fire" } },
    }
    assert.equal("Lurias-Area52", ns.api:GetCurrentCharacter())
    assert.equal("Fire", ns.api:GetProfile(nil, 62).spec)
    assert.equal("Fire", ns.api:GetProfiles()[62].spec)
  end)
end)

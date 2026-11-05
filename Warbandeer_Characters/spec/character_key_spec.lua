-- Which db.characters key the logged-in character uses (#1013): the bare name stays the key (existing saves
-- load untouched, older revisions keep working), and a same-named character on another realm gets its own
-- "Name-Realm" record instead of merging into the first.

-- luacheck: globals describe it before_each after_each UnitClassBase UnitGUID UnitSex GetNormalizedRealmName GetRealmName GetGuildInfo

local STUBBED = { "UnitClassBase", "UnitGUID", "UnitSex", "GetNormalizedRealmName", "GetRealmName", "GetGuildInfo" }
local saved

local function noop() end

local function loadDatabase(playerName)
  local printed = {}
  local ns = setmetatable({}, { __index = function() return noop end })
  ns.wow = {
    Player = {
      GetName = function() return playerName end,
      GetClassName = function() return "Mage" end, GetClassId = function() return 8 end,
      GetRace = function() return "Human", 1 end,
    },
    ClassKeyByToken = { MAGE = "Mage" },
  }
  ns.Print = function(msg) printed[#printed + 1] = msg end
  ns.NormalizeRaceId = function() return 1, true end
  ns.db = { characters = {}, numCharacters = 0 }
  assert(loadfile("Warbandeer_Characters/database.lua"))("Warbandeer_Characters", ns)
  return ns, printed
end

describe("ns.ResolveCharacterKey (#1013)", function()
  local resolve
  local MAGE, HUMAN, DWARF, HUNTER = 8, 1, 3, 3

  before_each(function()
    resolve = loadDatabase("Foo").ResolveCharacterKey
  end)

  local function rec(guid, realm, classId, raceId)
    return { guid = guid, realm = realm, classId = classId, raceId = raceId }
  end

  it("uses the bare name for a brand-new character", function()
    assert.same({ "Foo", false }, { resolve({}, "Foo", "RealmA", "Player-1-AAA", MAGE, HUMAN) })
  end)

  it("keeps the bare name for the same character (same GUID)", function()
    local chars = { Foo = rec("Player-1-AAA", "RealmA", MAGE, HUMAN) }
    assert.same({ "Foo", false }, { resolve(chars, "Foo", "RealmA", "Player-1-AAA", MAGE, HUMAN) })
  end)

  it("qualifies a same-named character on another realm with another GUID and another class", function()
    local chars = { Foo = rec("Player-1-AAA", "RealmA", MAGE, HUMAN) }
    assert.same({ "Foo-RealmB", true }, { resolve(chars, "Foo", "RealmB", "Player-2-BBB", HUNTER, HUMAN) })
  end)

  it("qualifies it when only the race differs", function()
    local chars = { Foo = rec("Player-1-AAA", "RealmA", MAGE, HUMAN) }
    assert.same({ "Foo-RealmB", true }, { resolve(chars, "Foo", "RealmB", "Player-2-BBB", MAGE, DWARF) })
  end)

  it("a realm transfer (new realm, new GUID, same class and race) keeps the bare-key record", function()
    local chars = { Foo = rec("Player-1-AAA", "RealmA", MAGE, HUMAN) }
    assert.same({ "Foo", false }, { resolve(chars, "Foo", "RealmB", "Player-2-BBB", MAGE, HUMAN) })
  end)

  it("a re-created character on the same realm (new GUID) keeps the bare-key record", function()
    local chars = { Foo = rec("Player-1-AAA", "RealmA", MAGE, HUMAN) }
    assert.same({ "Foo", false }, { resolve(chars, "Foo", "RealmA", "Player-9-ZZZ", HUNTER, DWARF) })
  end)

  it("then keeps using that Name-Realm key, and the original keeps the bare key", function()
    local chars = {
      Foo = rec("Player-1-AAA", "RealmA", MAGE, HUMAN),
      ["Foo-RealmB"] = rec("Player-2-BBB", "RealmB", HUNTER, HUMAN),
    }
    assert.same({ "Foo-RealmB", false }, { resolve(chars, "Foo", "RealmB", "Player-2-BBB", HUNTER, HUMAN) })
    assert.same({ "Foo", false }, { resolve(chars, "Foo", "RealmA", "Player-1-AAA", MAGE, HUMAN) })
  end)

  it("a record without a GUID (old save) compares the realm, ignoring spaces: same realm keeps the bare key", function()
    local chars = { Foo = rec(nil, "Area 52", MAGE, HUMAN) }
    assert.same({ "Foo", false }, { resolve(chars, "Foo", "Area52", "Player-1-AAA", HUNTER, DWARF) })
  end)

  it("a record without a GUID on another realm with another class is a different character", function()
    local chars = { Foo = rec(nil, "RealmA", MAGE, HUMAN) }
    assert.same({ "Foo-RealmB", true }, { resolve(chars, "Foo", "RealmB", "Player-2-BBB", HUNTER, HUMAN) })
  end)

  it("a record with neither realm nor class is assumed to be the same character", function()
    assert.same({ "Foo", false }, { resolve({ Foo = {} }, "Foo", "RealmB", "Player-2-BBB", HUNTER, DWARF) })
  end)

  it("without a realm there is nothing to qualify with: keeps the bare key", function()
    local chars = { Foo = rec("Player-1-AAA", "RealmA", MAGE, HUMAN) }
    assert.same({ "Foo", false }, { resolve(chars, "Foo", nil, "Player-2-BBB", HUNTER, DWARF) })
  end)
end)

describe("ns:initialize character record (#1013)", function()
  before_each(function()
    saved = {}
    for _, k in ipairs(STUBBED) do saved[k] = { _G[k] } end
    _G.UnitClassBase = function() return "Mage", "MAGE" end
    _G.UnitSex = function() return 2 end
    _G.GetGuildInfo = noop
  end)

  after_each(function()
    for _, k in ipairs(STUBBED) do _G[k] = saved[k][1] end
  end)

  it("creates a separate qualified record, warns once, and leaves the first character untouched", function()
    _G.GetNormalizedRealmName = function() return "RealmB" end
    _G.GetRealmName = function() return "RealmB" end
    _G.UnitGUID = function() return "Player-2-BBB" end
    local ns, printed = loadDatabase("Foo")
    local first = { name = "Foo", guid = "Player-1-AAA", realm = "RealmA", classId = 3, raceId = 1, marker = "first" }
    ns.db.characters.Foo = first
    ns.db.numCharacters = 1
    ns:initialize()
    assert.equal("Foo-RealmB", ns.currentPlayer)
    assert.equal(first, ns.db.characters.Foo)
    assert.equal("first", first.marker)
    assert.equal("Player-1-AAA", first.guid)
    assert.equal("Foo-RealmB", ns.db.characters["Foo-RealmB"].name)
    assert.equal("Foo", ns.db.characters["Foo-RealmB"].displayName) -- plain name kept apart from the key
    assert.equal(2, ns.db.numCharacters)
    assert.equal(1, #printed)
    assert.equal(ns.db.characters["Foo-RealmB"], ns.currentData)
  end)

  it("an existing save loads under its bare key with no warning", function()
    _G.GetNormalizedRealmName = function() return "RealmA" end
    _G.GetRealmName = function() return "RealmA" end
    _G.UnitGUID = function() return "Player-1-AAA" end
    local ns, printed = loadDatabase("Foo")
    local first = { name = "Foo", guid = "Player-1-AAA", realm = "RealmA", classId = 8, raceId = 1 }
    ns.db.characters.Foo = first
    ns.db.numCharacters = 1
    ns:initialize()
    assert.equal("Foo", ns.currentPlayer)
    assert.equal(first, ns.currentData)
    assert.equal(0, #printed)
    assert.equal(1, ns.db.numCharacters)
  end)

  it("a realm transfer keeps the record, updates its realm, and does not warn", function()
    _G.GetNormalizedRealmName = function() return "RealmB" end
    _G.GetRealmName = function() return "Realm B" end
    _G.UnitGUID = function() return "Player-2-BBB" end
    local ns, printed = loadDatabase("Foo")
    local old = { name = "Foo", guid = "Player-1-AAA", realm = "RealmA", classId = 8, raceId = 1 }
    ns.db.characters.Foo = old
    ns.db.numCharacters = 1
    ns:initialize()
    assert.equal("Foo", ns.currentPlayer)
    assert.equal(old, ns.currentData)
    assert.equal("Realm B", old.realm)
    assert.equal("Player-2-BBB", old.guid)
    assert.equal("Foo", old.displayName)
    assert.equal(0, #printed)
    assert.equal(1, ns.db.numCharacters)
  end)
end)

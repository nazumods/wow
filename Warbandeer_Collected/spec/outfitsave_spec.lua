local collected = require("Warbandeer_Collected.spec.collected")

-- Saving one look into BOTH stores (#699). The rule worth locking down is the asymmetry between
-- them: the account-wide library is the durable half and the game's per-character custom sets are
-- best-effort, so a custom-set refusal — the 25-set cap, a rejected name, a name already taken by a
-- different set — must leave the library entry saved rather than failing the whole action. That is
-- the one behaviour a user would lose a composed look to if it regressed.

-- An outfit list with a recognisable appearance in one slot, so a round-trip can be asserted on
-- something more specific than "it came back non-nil".
---@param head number
---@return table[]
local function lookWith(ns, head)
  local list = ns.EmptyOutfitList()
  list[INVSLOT_HEAD].appearanceID = head
  return list
end

-- Stand in for outfit.lua's `ns.SaveCustomSet`, which wraps C_TransmogCollection and so isn't
-- loaded here. Returns the same `(customSetID, err)` pair the real one does — an id on success, nil
-- plus a reason on refusal — and records its calls so "was the game even asked" is assertable.
local function stubCustomSets(ns, result)
  local calls = {}
  ns.SaveCustomSet = function(name, list)
    calls[#calls + 1] = { name = name, list = list }
    return result.id, result.err
  end
  return calls
end

describe("SaveLookToBoth", function()
  local ns
  before_each(function() ns = collected.load() end)

  it("writes both stores when the game accepts the set", function()
    local calls = stubCustomSets(ns, { id = 12 })
    local res = ns.SaveLookToBoth("mog", lookWith(ns, 7019))
    assert.is_true(res.saved)
    assert.equal(12, res.customSetID)
    assert.is_nil(res.customSetErr)
    assert.equal(1, #calls)
    assert.equal("mog", calls[1].name)
    assert.equal(7019, ns.LibraryOutfitList("mog")[INVSLOT_HEAD].appearanceID)
  end)

  it("keeps the library entry when the game refuses the custom set", function()
    stubCustomSets(ns, { err = "you already have 25 sets" })
    local res = ns.SaveLookToBoth("mog", lookWith(ns, 7019))
    -- The whole point of the split: a refusal downstream does not fail the save, and the look is
    -- still recoverable from the library on any character.
    assert.is_true(res.saved)
    assert.is_nil(res.customSetID)
    assert.equal("you already have 25 sets", res.customSetErr)
    assert.equal(7019, ns.LibraryOutfitList("mog")[INVSLOT_HEAD].appearanceID)
    -- The reason reaches the user rather than being swallowed into a bare "saved".
    assert.matches("you already have 25 sets", res.message)
  end)

  it("fails outright when the library refuses, without asking the game", function()
    local calls = stubCustomSets(ns, { id = 12 })
    local res = ns.SaveLookToBoth("", lookWith(ns, 7019))
    assert.is_false(res.saved)
    -- Whatever made the library refuse would refuse there too; one failure is reported, not two.
    assert.equal(0, #calls)
  end)

  it("reports replacing an existing library entry rather than saving a new one", function()
    stubCustomSets(ns, { id = 12 })
    ns.SaveLookToBoth("mog", lookWith(ns, 1))
    local res = ns.SaveLookToBoth("mog", lookWith(ns, 2))
    assert.is_true(res.replaced)
    assert.matches("Replaced", res.message)
    -- Replaced in place, so the library still holds exactly one entry under that name.
    assert.equal(1, #ns.LibraryOutfits())
    assert.equal(2, ns.LibraryOutfitList("mog")[INVSLOT_HEAD].appearanceID)
  end)

  it("reports a first save as saved, not replaced", function()
    stubCustomSets(ns, { id = 12 })
    local res = ns.SaveLookToBoth("mog", lookWith(ns, 1))
    assert.is_false(res.replaced)
    assert.matches("Saved", res.message)
  end)

  -- #728: the match is case-insensitive and a replaced entry keeps its stored spelling, so both the
  -- report and the game custom set have to use THAT name — reporting what was typed would name a
  -- look the library doesn't list, and would hand the game a second spelling of the same name.
  it("replaces a case variant under the library's own spelling", function()
    local calls = stubCustomSets(ns, { id = 12 })
    ns.SaveLookToBoth("Boylane 3", lookWith(ns, 1))
    local res = ns.SaveLookToBoth("boylane 3", lookWith(ns, 2))
    assert.is_true(res.replaced)
    assert.matches("Replaced \"Boylane 3\"", res.message)
    assert.equal("Boylane 3", calls[2].name)
    assert.equal(1, #ns.LibraryOutfits())
    assert.equal("Boylane 3", ns.LibraryOutfits()[1].name)
  end)
end)

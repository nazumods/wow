local collected = require("Warbandeer_Collected.spec.collected")

-- `ns.PushLookToCharacter` — the one bridge from the account-wide library into the game's
-- per-character transmog sets, and the only verb that can REPLACE something the addon doesn't own.
-- Extracted from two byte-identical button handlers in #770 step 8; these cover the decision, which
-- is the half worth locking down. `ns.CustomSets` / `ns.SaveCustomSet` are resolved at call time, so
-- they are stubbed per-test and the saved arguments are what the assertions read.

describe("PushLookToCharacter", function()
  local ns, saved

  ---Install the two client-side functions the rule reaches, recording what it asks for.
  ---@param sets table[]  what this character already has, `{ id, name }`
  ---@param result number?  the id SaveCustomSet returns; nil makes it fail
  local function withSets(sets, result)
    ns.CustomSets = function() return sets end
    ns.SaveCustomSet = function(name, list, existing)
      saved = { name = name, list = list, existing = existing }
      if result then return result end
      return nil, "name not allowed"
    end
  end

  before_each(function()
    ns = collected.loadOutfitVerbs(collected.load())
    saved = nil
    ns.SaveLibraryOutfit("Boylane 3", collected.lookWith(ns, 7019))
  end)

  it("pushes a look the character doesn't have yet", function()
    withSets({}, 1)
    local res = ns.PushLookToCharacter("Boylane 3")
    assert.is_true(res.ok)
    assert.is_nil(res.needsConfirm)
    assert.equal("Pushed \"Boylane 3\" to this character's transmog sets.", res.message)
    assert.equal("Boylane 3", saved.name)
    assert.is_nil(saved.existing, "a fresh push must not target an existing set id")
  end)

  -- The confirm is the whole reason this verb arms: replacing a character set is destructive and
  -- Blizzard's store has no undo either.
  it("asks before replacing a same-named set, and writes nothing yet", function()
    withSets({ { id = 7, name = "Boylane 3" } }, 1)
    local res = ns.PushLookToCharacter("Boylane 3")
    assert.is_true(res.needsConfirm)
    assert.is_nil(res.ok)
    assert.equal("\"Boylane 3\" is already one of this character's sets — click Push again to replace it.",
      res.message)
    assert.is_nil(saved, "the confirmation must come BEFORE the write")
  end)

  it("replaces that set once confirmed, targeting its id", function()
    withSets({ { id = 7, name = "Boylane 3" } }, 7)
    local res = ns.PushLookToCharacter("Boylane 3", true)
    assert.is_true(res.ok)
    assert.equal(7, saved.existing, "the confirmed push must overwrite the set it asked about")
  end)

  -- The decision of #770 step 8, taken deliberately rather than inherited. The scan was an EXACT
  -- match while the library's own lookup has been case-insensitive since #728, so a look pushed in
  -- different case created a SECOND character set differing only in capitalisation — in a store
  -- capped at 25.
  describe("case-insensitive matching (#728's rule, applied here)", function()
    it("recognises a set whose name differs only in case", function()
      withSets({ { id = 7, name = "boylane 3" } }, 7)
      local res = ns.PushLookToCharacter("Boylane 3")
      assert.is_true(res.needsConfirm, "a case variant is the same set, not a new one")
    end)

    it("replaces it rather than creating a duplicate", function()
      withSets({ { id = 7, name = "BOYLANE 3" } }, 7)
      ns.PushLookToCharacter("Boylane 3", true)
      assert.equal(7, saved.existing)
    end)

    it("writes the library's spelling, which is the canonical one", function()
      withSets({ { id = 7, name = "boylane 3" } }, 7)
      ns.PushLookToCharacter("Boylane 3", true)
      assert.equal("Boylane 3", saved.name)
    end)

    it("still treats a genuinely different name as a new set", function()
      withSets({ { id = 7, name = "Boylane 4" } }, 1)
      local res = ns.PushLookToCharacter("Boylane 3")
      assert.is_true(res.ok)
      assert.is_nil(saved.existing)
    end)
  end)

  describe("refusals", function()
    it("reports a look it can't decode, and writes nothing", function()
      withSets({}, 1)
      local res = ns.PushLookToCharacter("no such look")
      assert.is_nil(res.ok)
      assert.is_nil(res.needsConfirm)
      assert.is_truthy(res.message:find("Couldn't read that look"))
      assert.is_nil(saved)
    end)

    -- Blizzard's name filter and 25-set cap live inside SaveCustomSet; the rule only relays them.
    it("reports the game's refusal of the write", function()
      withSets({}, nil)
      local res = ns.PushLookToCharacter("Boylane 3")
      assert.is_nil(res.ok)
      assert.equal("Couldn't push: name not allowed", res.message)
    end)
  end)
end)

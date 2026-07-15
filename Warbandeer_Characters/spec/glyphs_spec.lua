local wbchar = require("Warbandeer_Characters.spec.wbchar")

-- A small synthetic catalog exercising the three cases: an all-spec glyph and two
-- spec-restricted ones (spec 11 only, and specs 11+12).
local function catalog()
  return {
    { itemID = 1, glyph = 100, label = "All Specs" },
    { itemID = 2, glyph = 200, label = "Spec 11",    specs = { [11] = true } },
    { itemID = 3, glyph = 300, label = "Spec 11+12", specs = { [11] = true, [12] = true } },
  }
end

describe("Warbandeer_Characters ns.MergeGlyphStatus", function()
  local ns
  before_each(function() ns = wbchar.load() end)

  it("returns an empty list for a nil or empty catalog", function()
    assert.same({}, ns.MergeGlyphStatus(nil, 11, {}))
    assert.same({}, ns.MergeGlyphStatus({}, 11, {}))
  end)

  it("keeps every entry and preserves order when no spec is given", function()
    local out = ns.MergeGlyphStatus(catalog(), nil, nil)
    assert.equal(3, #out)
    assert.equal("All Specs", out[1].label)
    assert.equal("Spec 11", out[2].label)
    assert.equal("Spec 11+12", out[3].label)
  end)

  it("filters to the requested spec, always keeping all-spec entries", function()
    local out = ns.MergeGlyphStatus(catalog(), 12, {})
    -- item 2 (spec 11 only) drops; item 1 (all) + item 3 (11/12) stay, in order.
    assert.equal(2, #out)
    assert.equal("All Specs", out[1].label)
    assert.equal("Spec 11+12", out[2].label)
  end)

  it("marks a glyph applied only when its id is in the applied set", function()
    local out = ns.MergeGlyphStatus(catalog(), 11, { [200] = true })
    local byLabel = {}
    for _, e in ipairs(out) do byLabel[e.label] = e end
    assert.is_false(byLabel["All Specs"].applied)
    assert.is_true(byLabel["Spec 11"].applied)
    assert.is_false(byLabel["Spec 11+12"].applied)
  end)

  it("treats a nil applied set as nothing applied", function()
    local out = ns.MergeGlyphStatus(catalog(), nil, nil)
    for _, e in ipairs(out) do assert.is_false(e.applied) end
  end)

  it("carries the itemID and glyph id through to the result", function()
    local out = ns.MergeGlyphStatus(catalog(), 11, {})
    assert.equal(1, out[1].itemID)
    assert.equal(100, out[1].glyph)
  end)
end)

describe("Warbandeer_Characters appearance catalog integrity", function()
  local ns
  before_each(function() ns = wbchar.load() end)

  it("gives every applied-glyph entry an itemID, glyph id and label", function()
    for _, list in pairs(ns.AppearanceGlyphs) do
      for _, e in ipairs(list) do
        assert.is_number(e.itemID)
        assert.is_number(e.glyph)
        assert.is_string(e.label)
      end
    end
    -- Evoker (13) has no glyphs, so it must not appear.
    assert.is_nil(ns.AppearanceGlyphs[13])
  end)

  it("gives every unlock entry an itemID, quest, spell and label", function()
    for _, list in pairs(ns.AppearanceUnlocks) do
      for _, e in ipairs(list) do
        assert.is_number(e.itemID)
        assert.is_number(e.quest)
        assert.is_number(e.spell)
        assert.is_string(e.label)
      end
    end
    -- Only Druid (11) and Warlock (9) have account-wide unlocks.
    assert.is_not_nil(ns.AppearanceUnlocks[9])
    assert.is_not_nil(ns.AppearanceUnlocks[11])
  end)

  it("has no duplicate glyph id within a class", function()
    for classId, list in pairs(ns.AppearanceGlyphs) do
      local seen = {}
      for _, e in ipairs(list) do
        assert.is_nil(seen[e.glyph], "duplicate glyph " .. e.glyph .. " in class " .. classId)
        seen[e.glyph] = true
      end
    end
  end)
end)

describe("Warbandeer_Characters ns.ClassMounts catalog integrity", function()
  local ns
  before_each(function() ns = wbchar.load() end)

  it("gives every entry a spellID or itemID and a string label", function()
    for classId, list in pairs(ns.ClassMounts) do
      for _, e in ipairs(list) do
        assert.is_true(type(e.spellID) == "number" or type(e.itemID) == "number",
          "class " .. classId .. " entry '" .. tostring(e.label) .. "' needs a spellID or itemID")
        assert.is_string(e.label)
      end
    end
  end)

  it("has a roster for every class but Evoker (13)", function()
    for classId = 1, 12 do
      assert.is_not_nil(ns.ClassMounts[classId], "missing class-mount roster for class " .. classId)
    end
    assert.is_nil(ns.ClassMounts[13])
  end)

  -- Distinct raw catalog ids only; two entries resolving to the same mountID (the tint-collapse
  -- risk) can't be caught without C_MountJournal — that's the `/wbc dump mounts` in-game gate.
  it("has no duplicate spellID/itemID within a class", function()
    for classId, list in pairs(ns.ClassMounts) do
      local seen = {}
      for _, e in ipairs(list) do
        local id = e.spellID and ("s" .. e.spellID) or ("i" .. e.itemID)
        assert.is_nil(seen[id], "duplicate id " .. id .. " in class " .. classId)
        seen[id] = true
      end
    end
  end)
end)

describe("Warbandeer_Characters ns.MergeLearnedStatus", function()
  local ns
  before_each(function() ns = wbchar.load() end)

  local function unlockCatalog()
    return {
      { itemID = 1, spell = 100, label = "Unlock A" },
      { itemID = 2, spell = 200, label = "Unlock B" },
    }
  end

  it("returns an empty list for a nil or empty catalog", function()
    assert.same({}, ns.MergeLearnedStatus(nil, {}))
    assert.same({}, ns.MergeLearnedStatus({}, {}))
  end)

  it("marks an unlock known only when its spell is in the known set, preserving order", function()
    local out = ns.MergeLearnedStatus(unlockCatalog(), { [200] = true })
    assert.equal(2, #out)
    assert.equal("Unlock A", out[1].label)
    assert.is_false(out[1].known)
    assert.equal("Unlock B", out[2].label)
    assert.is_true(out[2].known)
    assert.equal(1, out[1].itemID)
    assert.equal(100, out[1].spell)
  end)

  it("treats a nil known set as nothing known", function()
    local out = ns.MergeLearnedStatus(unlockCatalog(), nil)
    for _, e in ipairs(out) do assert.is_false(e.known) end
  end)

  it("gives every learned-unlock entry an itemID, spell and label, and titles every class", function()
    for classId, list in pairs(ns.LearnedUnlocks) do
      for _, e in ipairs(list) do
        assert.is_number(e.itemID)
        assert.is_number(e.spell)
        assert.is_string(e.label)
      end
      assert.is_string(ns.LearnedUnlockTitle[classId])
    end
    -- Every class with a class-book set is present (Paladin, Hunter, Rogue, DK, Shaman, Mage,
    -- Monk, Druid). Priest/Warrior/Demon Hunter/Evoker have no class books, so must not appear.
    for _, classId in ipairs({ 2, 3, 4, 6, 7, 8, 10, 11 }) do
      assert.is_not_nil(ns.LearnedUnlocks[classId], "missing learned-unlock class " .. classId)
    end
    assert.is_nil(ns.LearnedUnlocks[1])  -- Warrior
    assert.is_nil(ns.LearnedUnlocks[5])  -- Priest
    assert.is_nil(ns.LearnedUnlocks[12]) -- Demon Hunter
  end)

  it("has no duplicate itemID or spell within a class", function()
    for classId, list in pairs(ns.LearnedUnlocks) do
      local seenItem, seenSpell = {}, {}
      for _, e in ipairs(list) do
        assert.is_nil(seenItem[e.itemID], "duplicate itemID " .. e.itemID .. " in class " .. classId)
        assert.is_nil(seenSpell[e.spell], "duplicate spell " .. e.spell .. " in class " .. classId)
        seenItem[e.itemID] = true
        seenSpell[e.spell] = true
      end
    end
  end)
end)

local wbchar = require("Warbandeer_Characters.spec.wbchar")

-- A small synthetic catalog exercising the two matching modes: a creatureID-only entry (any recolor
-- counts) and two recolor entries that share one creatureID but pin different displayIDs.
local function catalog()
  return {
    { label = "Single",   creatureID = 100, category = "A", note = "zone A", howTo = "how A" },
    { label = "RecolorX", creatureID = 200, displayID = 10, category = "B" },
    { label = "RecolorY", creatureID = 200, displayID = 20, category = "B" },
  }
end

describe("Warbandeer_Characters ns.MergeChallengeTames", function()
  local ns
  before_each(function() ns = wbchar.load() end)

  it("returns an empty list for a nil or empty catalog", function()
    assert.same({}, ns.MergeChallengeTames(nil, {}, {}))
    assert.same({}, ns.MergeChallengeTames({}, {}, {}))
  end)

  it("treats nil owned sets as nothing owned", function()
    local out = ns.MergeChallengeTames(catalog(), nil, nil)
    assert.equal(3, #out)
    for _, e in ipairs(out) do assert.is_false(e.owned) end
  end)

  it("marks a creatureID-only entry owned for any recolor of that creature", function()
    -- Creature 100 owned with an unrelated display; the creatureID-only entry ignores displayID.
    local out = ns.MergeChallengeTames(catalog(), { [100] = true }, { [100] = { [999] = true } })
    local byLabel = {}
    for _, e in ipairs(out) do byLabel[e.label] = e end
    assert.is_true(byLabel["Single"].owned)
    assert.is_false(byLabel["RecolorX"].owned)
    assert.is_false(byLabel["RecolorY"].owned)
  end)

  it("requires the exact displayID for a recolor entry", function()
    local out = ns.MergeChallengeTames(catalog(), { [200] = true }, { [200] = { [10] = true } })
    local byLabel = {}
    for _, e in ipairs(out) do byLabel[e.label] = e end
    assert.is_true(byLabel["RecolorX"].owned)   -- display 10 pinned + owned
    assert.is_false(byLabel["RecolorY"].owned)  -- display 20 not owned
    assert.is_false(byLabel["Single"].owned)    -- creature 100 not owned at all
  end)

  it("does not mark a recolor entry owned when its creature is absent, even if a display set exists", function()
    -- ownedDisplays carries display 10 but ownedCreatures lacks creature 200 — must stay missing.
    local out = ns.MergeChallengeTames(catalog(), {}, { [200] = { [10] = true } })
    for _, e in ipairs(out) do assert.is_false(e.owned) end
  end)

  it("preserves catalog order and carries every field through", function()
    local out = ns.MergeChallengeTames(catalog(), {}, {})
    assert.equal("Single", out[1].label)
    assert.equal("RecolorX", out[2].label)
    assert.equal("RecolorY", out[3].label)
    assert.equal(100, out[1].creatureID)
    assert.is_nil(out[1].displayID)
    assert.equal("A", out[1].category)
    assert.equal("zone A", out[1].note)
    assert.equal("how A", out[1].howTo)
    assert.equal(20, out[3].displayID)
  end)
end)

describe("Warbandeer_Characters ns.ChallengeTames catalog integrity", function()
  local ns
  before_each(function() ns = wbchar.load() end)

  it("is a non-empty flat list", function()
    assert.is_table(ns.ChallengeTames)
    assert.is_true(#ns.ChallengeTames > 0)
  end)

  it("gives every entry a label, numeric creatureID and category (displayID numeric when present)", function()
    for _, e in ipairs(ns.ChallengeTames) do
      assert.is_string(e.label)
      assert.is_number(e.creatureID)
      assert.is_string(e.category)
      if e.displayID ~= nil then assert.is_number(e.displayID) end
      if e.note ~= nil then assert.is_string(e.note) end
      if e.howTo ~= nil then assert.is_string(e.howTo) end
    end
  end)

  it("has no duplicate (creatureID, displayID) key", function()
    local seen = {}
    for _, e in ipairs(ns.ChallengeTames) do
      local key = e.creatureID .. ":" .. (e.displayID or "*")
      assert.is_nil(seen[key], "duplicate tame key " .. key .. " (" .. e.label .. ")")
      seen[key] = true
    end
  end)
end)

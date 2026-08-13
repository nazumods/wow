-- Crafting view per-expansion skill lookup (sibling of the #910 Horde-BFA fix). The Crafting
-- view matches a profession child's skill by its `expansionName` (a bare continent name, e.g.
-- "Dragon Isles"), while the expansion toggle/tooltips show the marketing name ("Dragonflight").
-- Those differ for DF/TWW, so the match key and the display label must be kept apart -- matching
-- on the label silently never matches the stored name. This pins the two apart and ties every
-- skill-match name to ProfsData's EXP_ABBR (the same expansionName space the grid maps), so a
-- future marketing-name slip fails here.
--
-- CraftingData.lua is pure (only builds tables on `ns`); ProfsData.lua reads ns.ui/ns.theme at
-- load, so stub those. Both load into one ns for the cross-check.
local function load()
  local ns = { ui = {}, theme = { colors = {} } }
  assert(loadfile("Warbandeer/views/crafting/CraftingData.lua"))("Warbandeer", ns)
  assert(loadfile("Warbandeer/views/profs/ProfsData.lua"))("Warbandeer", ns)
  return ns
end

describe("Warbandeer ns.crafting expansion skill lookup", function()
  local ns
  before_each(function() ns = load() end)

  it("derives a label and a skill-name lookup for every expansion", function()
    for _, e in ipairs(ns.crafting.EXPANSIONS) do
      assert.equal(e.label,     ns.crafting.EXP_LABEL[e.key])
      assert.equal(e.skillName, ns.crafting.EXP_SKILL_NAME[e.key])
    end
  end)

  it("matches skill on the continent name, not the marketing label, for DF/TWW", function()
    assert.equal("Dragon Isles", ns.crafting.EXP_SKILL_NAME.df)
    assert.equal("Khaz Algar",   ns.crafting.EXP_SKILL_NAME.tww)
    assert.not_equal(ns.crafting.EXP_LABEL.df,  ns.crafting.EXP_SKILL_NAME.df)
    assert.not_equal(ns.crafting.EXP_LABEL.tww, ns.crafting.EXP_SKILL_NAME.tww)
  end)

  it("uses one name for Midnight, whose continent and marketing names coincide", function()
    assert.equal("Midnight", ns.crafting.EXP_SKILL_NAME.midnight)
    assert.equal(ns.crafting.EXP_LABEL.midnight, ns.crafting.EXP_SKILL_NAME.midnight)
  end)

  it("keys every expansion's skill-name to a real profession category (ProfsData.EXP_ABBR)", function()
    -- The drift guard: exp.name comes from the same expansionName space ProfsData maps, so
    -- every crafting skillName must be a known category there. A marketing-name slip (e.g.
    -- "Dragonflight") is absent from EXP_ABBR and fails here.
    for _, e in ipairs(ns.crafting.EXPANSIONS) do
      assert.is_not_nil(ns.profs.EXP_ABBR[e.skillName],
        e.key .. " skillName '" .. tostring(e.skillName) .. "' is not a ProfsData.EXP_ABBR category")
    end
  end)
end)

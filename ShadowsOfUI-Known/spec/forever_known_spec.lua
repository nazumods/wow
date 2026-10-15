local known = require("ShadowsOfUI-Known.spec.known")

-- #961: Known never states a finding it has no data for, and never shows a header with no rows.
-- The REAL core.lua + tooltip.lua run against fake characters; Forever is the case where
-- Warbandeer_Characters has captured no recipes (the PR's D2 note: inferred from the beta data, not
-- proven), Retail the case where it has.
describe("ShadowsOfUI-Known tooltips", function()
  after_each(function() known.restore() end)

  -- A character with Tailoring, optionally with captured learned recipes.
  local function toon(name, learned)
    local t = {
      name = name, classKey = "Mage",
      basic = { level = 80, professions = { primary = { skillID = 197, skillLevel = 100 } } },
    }
    if learned then
      t.professions = { details = { [197] = { recipes = { midnight = { learned = learned, total = #learned } } } } }
    end
    return t
  end

  local function has(lines, needle)
    for _, l in ipairs(lines) do if l:find(needle, 1, true) then return true end end
    return false
  end

  describe("recipe item tooltip (Learnable by / Known by)", function()
    it("Retail-shaped data renders the full block: Known by and Learnable by", function()
      local d = known.loadTooltips({ toons = {
        toon("Knower", { { id = 1, name = "Bolt of Linen" } }),
        toon("Learner", { { id = 2, name = "Something Else" } }),
      } })
      local lines = d.hoverRecipeItem("Pattern: Bolt of Linen")
      assert.is_true(has(lines, "Known by:"))
      assert.is_true(has(lines, "Learnable by:"))
      assert.is_true(has(lines, "Knower"))
      assert.is_true(has(lines, "Learner"))
    end)

    it("no recipes bucket anywhere: no Known by block (and never a header with no rows)", function()
      local d = known.loadTooltips({ toons = { toon("Alt") } })
      local lines = d.hoverRecipeItem("Pattern: Bolt of Linen")
      assert.is_false(has(lines, "Known by:"))
      assert.is_true(has(lines, "Alt"))                 -- the documented Retail rule: unscanned stays learnable
    end)

    it("data exists but nobody knows THIS recipe: Learnable by only -- the item tooltip never says Not Known", function()
      local d = known.loadTooltips({ toons = { toon("Learner"), toon("Other", { { id = 7, name = "Different Recipe" } }) } })
      local lines = d.hoverRecipeItem("Pattern: Bolt of Linen")
      assert.is_true(has(lines, "Learnable by:"))
      assert.is_false(has(lines, "Not Known"))
      assert.is_false(has(lines, "Known by:"))
    end)

    it("nobody has the profession: nothing is added at all", function()
      local nobody = { name = "Warrior", classKey = "Warrior", basic = { level = 80, professions = {} } }
      local d = known.loadTooltips({ toons = { nobody } })
      assert.same({}, d.hoverRecipeItem("Pattern: Bolt of Linen"))
    end)

    it("everyone who could already knows it: only Known by, no empty Learnable by header", function()
      local d = known.loadTooltips({ toons = { toon("Knower", { { id = 1, name = "Bolt of Linen" } }) } })
      local lines = d.hoverRecipeItem("Pattern: Bolt of Linen")
      assert.is_true(has(lines, "Known by:"))
      assert.is_false(has(lines, "Learnable by:"))
    end)
  end)

  describe("Place Crafting Order tooltip (Known by / Not Known / Guild crafters)", function()
    it("Retail-shaped data: a recipe nobody knows reads 'Not Known: <profession>'", function()
      local d = known.loadTooltips({ profName = "Tailoring", toons = { toon("Alt", { { id = 1, name = "Other" } }) } })
      local lines = d.hoverCraftingOrderRow(999, 77)
      assert.is_true(has(lines, "Not Known: Tailoring"))
    end)

    it("nil profession name: 'Not Known' with no profession suffix (never 'Not Known: nil')", function()
      local d = known.loadTooltips({ profName = nil, toons = { toon("Alt", { { id = 1, name = "Other" } }) } })
      local lines = d.hoverCraftingOrderRow(999, 77)
      assert.is_true(has(lines, "Not Known"))
      assert.is_false(has(lines, "Not Known:"))
      assert.is_false(has(lines, "nil"))
    end)

    it("no recipes bucket anywhere: the Not Known claim is omitted (no data is not a finding)", function()
      local d = known.loadTooltips({ profName = "Tailoring", toons = { toon("Alt"), toon("Alt2") } })
      assert.same({}, d.hoverCraftingOrderRow(999, 77))
    end)

    it("a recipe someone knows still lists them (the guard does not touch the data path)", function()
      local d = known.loadTooltips({ toons = { toon("Crafter", { { id = 999, name = "X" } }) } })
      local lines = d.hoverCraftingOrderRow(999, 77)
      assert.is_true(has(lines, "Known by:"))
      assert.is_true(has(lines, "Crafter"))
    end)

    it("not in a guild / no answer: no guild section", function()
      local d = known.loadTooltips({ toons = { toon("Crafter", { { id = 999, name = "X" } }) }, guild = { nil, nil } })
      assert.is_false(has(d.hoverCraftingOrderRow(999, 77), "Guild crafters"))
    end)

    it("a guild answer with no crafters: no guild section", function()
      local d = known.loadTooltips({ toons = { toon("Crafter", { { id = 999, name = "X" } }) }, guild = { {}, "ready" } })
      assert.is_false(has(d.hoverCraftingOrderRow(999, 77), "Guild crafters"))
    end)

    it("a guild answer with crafters renders them; pending renders the querying placeholder", function()
      local ready = known.loadTooltips({ toons = { toon("Crafter", { { id = 999, name = "X" } }) },
        guild = { { { name = "Gina", classKey = "Mage", online = true } }, "ready" } })
      assert.is_true(has(ready.hoverCraftingOrderRow(999, 77), "Gina"))
      known.restore()
      local pending = known.loadTooltips({ toons = { toon("Crafter", { { id = 999, name = "X" } }) },
        guild = { nil, "pending" } })
      assert.is_true(has(pending.hoverCraftingOrderRow(999, 77), "querying..."))
    end)

    it("the first capture landing mid-session is picked up: a recipe hovered before it is not stuck on 'empty'", function()
      local toons = { toon("Alt") }
      local d = known.loadTooltips({ profName = "Tailoring", toons = toons })
      assert.same({}, d.hoverCraftingOrderRow(999, 77))          -- no data yet: nothing said (and not cached)
      -- Warbandeer_Characters' TRADE_SKILL_SHOW capture writes the bucket; it fires no NEW_RECIPE_LEARNED
      toons[1].professions = { details = { [197] = { recipes = { midnight = { learned = { { id = 999, name = "X" } }, total = 1 } } } } }
      local lines = d.hoverCraftingOrderRow(999, 77)
      assert.is_true(has(lines, "Known by:"))
      assert.is_false(has(lines, "Not Known"))
    end)

    it("no recipes bucket anywhere but a guild answer: the guild section still shows", function()
      local d = known.loadTooltips({ toons = { toon("Alt") },
        guild = { { { name = "Gina", classKey = "Mage", online = true } }, "ready" } })
      local lines = d.hoverCraftingOrderRow(999, 77)
      assert.is_false(has(lines, "Not Known"))
      assert.is_true(has(lines, "Gina"))
    end)
  end)

  describe("/sknown knownby", function()
    it("says no data was captured (not 'Not Known by any character') when nothing is captured", function()
      local d = known.loadTooltips({ toons = { toon("Alt") } })
      d.slash("knownby 999")
      assert.equals(1, #d.printed)
      assert.is_true(d.printed[1]:find("No recipe data captured yet", 1, true) ~= nil)
    end)

    it("says 'Not Known by any character' where recipes exist but nobody knows this one", function()
      local d = known.loadTooltips({ toons = { toon("Alt", { { id = 1, name = "Other" } }) } })
      d.slash("knownby 999")
      assert.is_true(d.printed[1]:find("Not Known by any character", 1, true) ~= nil)
    end)
  end)

  describe("ns.HasRecipeData", function()
    it("is false when the characters API is absent", function()
      local d = known.loadTooltips({ toons = { toon("A", {}) } })
      d.ns.api = nil
      assert.is_false(d.ns.HasRecipeData())
    end)

    it("is false with no characters, no details, and an empty recipes table; true with a bucket", function()
      assert.is_false(known.loadTooltips({ toons = {} }).ns.HasRecipeData())
      known.restore()
      assert.is_false(known.loadTooltips({ toons = { toon("A") } }).ns.HasRecipeData())
      known.restore()
      local empty = toon("B"); empty.professions = { details = { [197] = { recipes = {} } } }
      assert.is_false(known.loadTooltips({ toons = { empty } }).ns.HasRecipeData())
      known.restore()
      assert.is_true(known.loadTooltips({ toons = { toon("C", {}) } }).ns.HasRecipeData())
    end)
  end)
end)

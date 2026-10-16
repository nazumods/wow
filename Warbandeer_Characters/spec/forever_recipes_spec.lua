-- #988: Warbandeer_Characters records Forever's recipes. Forever uses the classic skill-line model
-- (one child per profession, named after it), so no RECIPE_EXP_KEYS name matches; on Forever that
-- child is bucketed as "forever", on Retail an unmapped child is still skipped. data/professions.lua
-- is loaded for real; the trade-skill queries are injected stubs.

local function load(flavor)
  local ns = {
    flavor = { isForever = flavor == "forever", isRetail = flavor ~= "forever" },
    api = { ResolveRecipeOutput = function() return false end },
    RegisterBroker = function() return { fields = nil } end,
  }
  assert(loadfile("Warbandeer_Characters/data/professions.lua"))("Warbandeer_Characters", ns)
  return ns
end

-- A trade-skill stub over `known` (skillLineID -> { [recipeID] = learned? }); IsRecipeInSkillLine
-- answers from it, GetRecipeInfo returns { learned, name } and counts its calls.
local function tradeSkill(known)
  local ts = { infoCalls = 0, qualityCalls = 0 }
  function ts.IsRecipeInSkillLine(id, skillLineID)
    return known[skillLineID] ~= nil and known[skillLineID][id] ~= nil
  end
  function ts.GetRecipeInfo(id)
    ts.infoCalls = ts.infoCalls + 1
    for _, recipes in pairs(known) do
      if recipes[id] ~= nil then return { learned = recipes[id], name = "Recipe " .. id } end
    end
  end
  function ts.GetCraftingOperationInfo()
    ts.qualityCalls = ts.qualityCalls + 1
    return { craftingQuality = 3 }
  end
  return ts
end

describe("Warbandeer_Characters recipe capture (#988)", function()
  -- Forever's beta probe: ONE child named after the profession, expansionName = the profession's name.
  local foreverChildren = { { professionID = 2948, professionName = "Tailoring", expansionName = "Tailoring" } }

  describe("CaptureRecipes", function()
    it("Forever: a single child named after the profession is captured under 'forever' with its learned recipes and total", function()
      local ns = load("forever")
      local ts = tradeSkill({ [2948] = { [10] = true, [11] = false, [12] = true } })
      local recipes = ns.CaptureRecipes(foreverChildren, { 10, 11, 12, 99 }, ts)  -- 99 is in no skill line
      assert.same({ "forever" }, (function() local k = {}; for key in pairs(recipes) do k[#k + 1] = key end; return k end)())
      assert.equals(3, recipes.forever.total)
      assert.same({ { id = 10, name = "Recipe 10" }, { id = 12, name = "Recipe 12" } }, recipes.forever.learned)
    end)

    it("Retail: an unmapped child is still skipped (recipes stay nil)", function()
      local ns = load("retail")
      local ts = tradeSkill({ [2948] = { [10] = true } })
      assert.is_nil(ns.CaptureRecipes(foreverChildren, { 10 }, ts))
      assert.equals(0, ts.infoCalls)
    end)

    it("Retail: a Midnight child is captured under 'midnight', unchanged", function()
      local ns = load("retail")
      local ts = tradeSkill({ [3000] = { [10] = true, [11] = false } })
      local recipes = ns.CaptureRecipes({ { professionID = 3000, expansionName = "Midnight" } }, { 10, 11 }, ts)
      assert.equals(2, recipes.midnight.total)
      assert.same({ { id = 10, name = "Recipe 10" } }, recipes.midnight.learned)
      assert.is_nil(recipes.forever)
    end)

    it("Retail: mapped children bucket per expansion and an unmapped sibling is skipped", function()
      local ns = load("retail")
      local ts = tradeSkill({ [3000] = { [1] = true }, [3001] = { [2] = true }, [3002] = { [3] = true } })
      local recipes = ns.CaptureRecipes({
        { professionID = 3000, expansionName = "Midnight" },
        { professionID = 3001, expansionName = "Khaz Algar" },
        { professionID = 3002, expansionName = "Classic" },
      }, { 1, 2, 3 }, ts)
      assert.is_not_nil(recipes.midnight)
      assert.is_not_nil(recipes.tww)
      assert.is_nil(recipes.forever)
      assert.is_nil(recipes.Classic)
    end)

    it("Forever: a mapped name still uses its key (the Forever bucket is only the fallback)", function()
      local ns = load("forever")
      local ts = tradeSkill({ [3000] = { [1] = true } })
      local recipes = ns.CaptureRecipes({ { professionID = 3000, expansionName = "Midnight" } }, { 1 }, ts)
      assert.is_not_nil(recipes.midnight)
      assert.is_nil(recipes.forever)
    end)

    it("a child with no professionID is skipped on both clients", function()
      for _, flavor in ipairs({ "forever", "retail" }) do
        local ns = load(flavor)
        assert.is_nil(ns.CaptureRecipes({ { expansionName = "Tailoring" } }, { 1 }, tradeSkill({})))
      end
    end)

    it("Forever: an unlearned-only profession still records the bucket with total and no learned rows", function()
      local ns = load("forever")
      local ts = tradeSkill({ [2948] = { [10] = false, [11] = false } })
      local recipes = ns.CaptureRecipes(foreverChildren, { 10, 11 }, ts)
      assert.equals(2, recipes.forever.total)
      assert.same({}, recipes.forever.learned)
    end)
  end)

  describe("CaptureRecipeQuality", function()
    it("Forever: no quality pass runs when 'forever' is the only bucket", function()
      local ns = load("forever")
      ns.api.ResolveRecipeOutput = function() return true end
      local ts = tradeSkill({ [2948] = { [10] = true } })
      local recipes = ns.CaptureRecipes(foreverChildren, { 10 }, ts)
      assert.has_no.errors(function() ns.CaptureRecipeQuality(recipes, ts) end)
      assert.equals(0, ts.qualityCalls)
      assert.is_nil(recipes.forever.learned[1].quality)
    end)

    it("Retail: the current expansion's gear recipes get their quality stamped (unchanged)", function()
      local ns = load("retail")
      ns.api.ResolveRecipeOutput = function() return true end
      local ts = tradeSkill({ [3000] = { [10] = true } })
      local recipes = ns.CaptureRecipes({ { professionID = 3000, expansionName = "Midnight" } }, { 10 }, ts)
      ns.CaptureRecipeQuality(recipes, ts)
      assert.equals(2, ts.qualityCalls)                 -- base + concentration
      assert.equals(3, recipes.midnight.learned[1].quality)
      assert.equals(3, recipes.midnight.learned[1].qualityConc)
    end)

    it("nil recipes (nothing captured) is harmless", function()
      local ns = load("retail")
      assert.has_no.errors(function() ns.CaptureRecipeQuality(nil, tradeSkill({})) end)
    end)
  end)
end)

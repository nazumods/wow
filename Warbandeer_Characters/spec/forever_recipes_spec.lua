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

    it("Forever: several unmapped children share the one bucket (added up, never replaced)", function()
      local ns = load("forever")
      local ts = tradeSkill({ [2948] = { [10] = true, [11] = false }, [2949] = { [20] = true } })
      local recipes = ns.CaptureRecipes({
        { professionID = 2948, expansionName = "Tailoring" },
        { professionID = 2949, expansionName = "Unknown" },
      }, { 10, 11, 20 }, ts)
      assert.equals(3, recipes.forever.total)
      assert.same({ { id = 10, name = "Recipe 10" }, { id = 20, name = "Recipe 20" } }, recipes.forever.learned)
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

  -- The TRADE_SKILL_SHOW handler itself (the consumer of CaptureRecipes / CaptureRecipeQuality):
  -- driven with a synchronous C_Timer and a stubbed C_TradeSkillUI, as the client calls it.
  describe("the TRADE_SKILL_SHOW handler", function()
    local savedTimer, savedTS
    before_each(function() savedTimer, savedTS = _G.C_Timer, _G.C_TradeSkillUI end)
    after_each(function() _G.C_Timer, _G.C_TradeSkillUI = savedTimer, savedTS end)

    -- Run the handler once on `flavor` with the given stub trade-skill API; returns what it wrote
    -- via self:set and the ts stub. `prev` is the stored value the handler merges into.
    local function open(flavor, tsOpts, prev)
      local ns = load(flavor)
      if tsOpts.resolve then ns.api.ResolveRecipeOutput = function() return true end end
      local ts = tradeSkill(tsOpts.known or {})
      ts.GetBaseProfessionInfo = function() return { professionID = 197 } end
      ts.GetChildProfessionInfos = function() return tsOpts.children end
      ts.GetAllRecipeIDs = function() return tsOpts.recipeIDs end
      _G.C_TradeSkillUI = ts
      _G.C_Timer = { After = function(_, fn) fn() end }
      local written
      local self = { set = function(_, data) written = data end }
      -- RegisterBroker's stub returned a bare table; the file assigned .fields onto ns.Professions
      ns.Professions.fields.details.eventHandler(self, prev)
      return written, ns, ts
    end

    it("Forever: opening the Tailoring window stores details[197].recipes.forever (and the unchanged expansions)", function()
      local written = open("forever", {
        children = foreverChildren, recipeIDs = { 10, 11 },
        known = { [2948] = { [10] = true, [11] = false } },
      })
      assert.equals(2, written[197].recipes.forever.total)
      assert.same({ { id = 10, name = "Recipe 10" } }, written[197].recipes.forever.learned)
      assert.equals("Tailoring", written[197].expansions[1].name)   -- D3: the expansions capture is untouched
    end)

    it("Forever: no recipe ids yet keeps the previously stored recipes (the per-field fallback)", function()
      local prev = { [197] = { recipes = { forever = { learned = { { id = 1, name = "Old" } }, total = 1 } } } }
      local written = open("forever", { children = foreverChildren, recipeIDs = {} }, prev)
      assert.equals("Old", written[197].recipes.forever.learned[1].name)
    end)

    it("Retail: the handler stamps crafting quality on the current expansion's gear recipes (unchanged)", function()
      local written, _, ts = open("retail", {
        children = { { professionID = 3000, expansionName = "Midnight" } }, recipeIDs = { 10 },
        known = { [3000] = { [10] = true } }, resolve = true,
      })
      assert.equals(3, written[197].recipes.midnight.learned[1].quality)
      assert.equals(2, ts.qualityCalls)
    end)

    it("Forever: the handler makes no quality query", function()
      local written, _, ts = open("forever", {
        children = foreverChildren, recipeIDs = { 10 }, known = { [2948] = { [10] = true } }, resolve = true,
      })
      assert.equals(0, ts.qualityCalls)
      assert.is_nil(written[197].recipes.forever.learned[1].quality)
    end)

    it("Retail: an unmapped child leaves recipes unset (nothing stored)", function()
      local written = open("retail", {
        children = foreverChildren, recipeIDs = { 10 }, known = { [2948] = { [10] = true } },
      })
      assert.is_nil(written[197].recipes)
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

    it("a trade-skill API without GetCraftingOperationInfo stamps nothing and does not error", function()
      local ns = load("retail")
      ns.api.ResolveRecipeOutput = function() return true end
      local ts = tradeSkill({ [3000] = { [10] = true } })
      local recipes = ns.CaptureRecipes({ { professionID = 3000, expansionName = "Midnight" } }, { 10 }, ts)
      ts.GetCraftingOperationInfo = nil
      assert.has_no.errors(function() ns.CaptureRecipeQuality(recipes, ts) end)
      assert.is_nil(recipes.midnight.learned[1].quality)
    end)

    it("nil recipes (nothing captured) is harmless", function()
      local ns = load("retail")
      assert.has_no.errors(function() ns.CaptureRecipeQuality(nil, tradeSkill({})) end)
    end)
  end)
end)

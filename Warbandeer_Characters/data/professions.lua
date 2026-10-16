---@type Warbandeer_Characters
local ns = select(2, ...)
local API = ns.api
local insert = table.insert

-- Professions broker. The static per-profession id table lives in data/professioninfo.lua
-- (loaded first); this file owns the broker + its `details` (recipe/skill) field, and
-- data/professions_gear.lua adds the `gear` (profession-equipment) field.

-- Expansion display name -> short bucket key for per-expansion recipe capture.
-- Only expansions listed here are captured; add more keys to track DF, etc.
local RECIPE_EXP_KEYS = {
  ["Midnight"]     = "midnight",
  ["Khaz Algar"]   = "tww",
  ["Dragon Isles"] = "df",
}

-- Forever uses the classic skill-line model: a profession has ONE child skill line, named after the
-- profession itself (probed on the beta for Tailoring only: id 2948, `expansionName` "Tailoring"), so no
-- RECIPE_EXP_KEYS name ever matches it. On Forever such a child is bucketed under this key instead
-- (ShadowsOfUI-Known reads every bucket, so the key name is free). Retail still skips an unmapped child.
local FOREVER_RECIPE_KEY = "forever"

-- The recipe bucket key for a child skill line: its mapped expansion key, or on Forever (a data-model
-- difference of the client, so the flavor, not a feature) the Forever key; nil = skip the child.
---@param child table  a ProfessionInfo from C_TradeSkillUI.GetChildProfessionInfos
---@return string?
local function recipeBucketKey(child)
  local key = RECIPE_EXP_KEYS[child.expansionName]
  if key then return key end
  if ns.flavor and ns.flavor.isForever then return FOREVER_RECIPE_KEY end
  return nil
end

-- Profession display name of the current expansion.  A character that has trained
-- this expansion's skill line is expected to have recipe data captured; missing.lua
-- uses this to tell "never scanned / capture gap" apart from "just hasn't trained it".
ns.CURRENT_RECIPE_EXP = "Midnight"

---@class ProfLearnedRecipe
---@field id integer
---@field name string
---@field quality integer? -- crafting quality tier (1-5) reachable at current skill, base reagents, no concentration (prof-gear recipes only)
---@field qualityConc integer? -- crafting quality tier reachable with concentration applied

---@class ProfRecipeBucket
---@field learned ProfLearnedRecipe[]
---@field total integer

---@class ProfDetail
---@field expansions {name:string, skillLevel:integer, maxSkillLevel:integer}[]?
---@field specPoints integer?
---@field recipes table<string, ProfRecipeBucket>? -- keyed by expansion (midnight/tww/df); on Forever the one classic child: "forever"

---@class ProfGearSlot
---@field name string?
---@field link string?
---@field ilvl integer?
---@field rarity integer? -- Enum.ItemQuality: 2=green, 3=blue, 4=purple
---@field tier integer? -- 1-5 crafted-tier stars (nil if item has no crafted tier)
---@field expacID integer? -- LE_EXPANSION_* of the item

---@class ProfGear
---@field slots table<integer, ProfGearSlot> keyed by inventory slot index

---@class Character
---@field professions ProfessionsBroker?

---@class ProfessionsBroker: Broker
---@field details table<integer, ProfDetail>?
---@field gear table<integer, ProfGear>? keyed by parent skillLineID

-- Per-child learned-recipe capture (pure; the trade-skill queries are injected): for each child skill
-- line with a bucket key, count the recipes in it and keep the learned ones. Returns nil when no child
-- has a key (so the caller leaves `recipes` unset and the previous capture survives).
---@param children table[]  ProfessionInfo[] (C_TradeSkillUI.GetChildProfessionInfos)
---@param recipeIDs integer[]  C_TradeSkillUI.GetAllRecipeIDs
---@param ts { IsRecipeInSkillLine: fun(id: integer, skillLineID: integer): boolean, GetRecipeInfo: fun(id: integer): table? }
---@return table<string, ProfRecipeBucket>?
function ns.CaptureRecipes(children, recipeIDs, ts)
  local recipes
  for _, child in ipairs(children) do
    local key = recipeBucketKey(child)
    if key and child.professionID then
      local learned, total = {}, 0
      for _, id in ipairs(recipeIDs) do
        if ts.IsRecipeInSkillLine(id, child.professionID) then
          total = total + 1
          local info = ts.GetRecipeInfo(id)
          if info and info.learned then
            insert(learned, { id = id, name = info.name })
          end
        end
      end
      recipes = recipes or {}
      local bucket = recipes[key]
      if bucket and key == FOREVER_RECIPE_KEY then
        -- several unmapped children share the one Forever bucket: add to it, never replace it
        -- (Retail keys are one per expansion; a repeat there keeps replacing, as it always did)
        bucket.total = bucket.total + total
        for _, r in ipairs(learned) do insert(bucket.learned, r) end
      else
        recipes[key] = { learned = learned, total = total }
      end
    end
  end
  return recipes
end

-- Crafting quality for the current expansion's learned recipes that craft profession gear: the tier
-- reachable with base reagents and with concentration, stamped onto each recipe record. It reads only
-- the CURRENT_RECIPE_EXP bucket ("midnight"); while Forever has just its "forever" bucket (no child there
-- is named "Midnight") it finds nothing and makes no query.
---@param recipes table<string, ProfRecipeBucket>?
---@param ts { GetCraftingOperationInfo: function? }
function ns.CaptureRecipeQuality(recipes, ts)
  local current = recipes and recipes[RECIPE_EXP_KEYS[ns.CURRENT_RECIPE_EXP]]
  for _, r in ipairs(current and current.learned or {}) do
    if API:ResolveRecipeOutput(r.id) and ts.GetCraftingOperationInfo then
      local base = ts.GetCraftingOperationInfo(r.id, {}, nil, false)
      local conc = ts.GetCraftingOperationInfo(r.id, {}, nil, true)
      r.quality     = base and base.craftingQuality
      r.qualityConc = conc and conc.craftingQuality
    end
  end
end

-- True when the stored profession detail shows the character has trained the current
-- expansion's skill line. Only then is recipe capture expected, so only then does a nil
-- recipes table mean "missing data" rather than "not trained yet". (Moved here from
-- missing.lua so the professions completeness check lives beside the data it reads.)
local function hasCurrentExpSkill(detail)
  if not detail or not detail.expansions then return false end
  for _, exp in ipairs(detail.expansions) do
    if exp.name == ns.CURRENT_RECIPE_EXP and (exp.maxSkillLevel or 0) > 0 then
      return true
    end
  end
  return false
end

ns.Professions = ns:RegisterBroker("professions")

ns.Professions.fields = {
  details = {
    -- Missing report: flag each profession with no captured per-expansion skill ("professions
    -- (…)"), and each trained in the current expansion but with no captured recipes ("recipes
    -- (…)"). A profession simply not trained this expansion is intentionally not reported. Two
    -- possible labels, so return a list.
    missing = { order = 270, check = function(toon)
      if not (toon.basic and toon.basic.professions) then return end
      local details = toon.professions and toon.professions.details
      local missingProfs, missingRecipes = {}, {}
      for _, prof in ipairs({ toon.basic.professions.primary, toon.basic.professions.secondary,
                              toon.basic.professions.fishing, toon.basic.professions.cooking }) do
        if prof and prof.name and prof.skillID then
          local detail = details and details[prof.skillID]
          if not detail or not (detail.expansions and #detail.expansions > 0) then
            insert(missingProfs, prof.name)
          elseif not detail.recipes and hasCurrentExpSkill(detail) then
            insert(missingRecipes, prof.name)
          end
        end
      end
      local out = {}
      if #missingProfs > 0 then insert(out, "professions (" .. table.concat(missingProfs, ", ") .. ")") end
      if #missingRecipes > 0 then insert(out, "recipes (" .. table.concat(missingRecipes, ", ") .. ")") end
      return out
    end },
    -- On login/refresh, preserve whatever was cached from prior TRADE_SKILL_SHOW scans.
    get = function(self, toon, currentValue)
      return currentValue or {}
    end,

    -- Fired when the player opens a profession window.  Scans the active profession
    -- and merges its expansion skill levels and spec points into the stored table,
    -- keyed by skillLineID so each profession's data is updated independently.
    event = "TRADE_SKILL_SHOW",
    eventHandler = function(self, currentValue)
      -- Capture which profession was opened NOW, before any timer delay.
      -- Reading GetBaseProfessionInfo() inside the timer is unreliable: if the
      -- player switches professions before the timer fires, the wrong profession
      -- gets updated.
      if not C_TradeSkillUI or not C_TradeSkillUI.GetBaseProfessionInfo then return end
      local baseInfo = C_TradeSkillUI.GetBaseProfessionInfo()
      if not baseInfo or not baseInfo.professionID then return end
      local skillLineID = baseInfo.professionID

      -- Small delay ensures child profession info is fully populated before querying.
      C_Timer.After(0.5, function()
        local profData = {}

        -- Per-expansion skill levels.  Primary professions return one child per
        -- expansion; secondary professions (Fishing, Cooking) return no children.
        if C_TradeSkillUI.GetChildProfessionInfos then
          local children = C_TradeSkillUI.GetChildProfessionInfos()
          if children and #children > 0 then
            local expansions = {}
            for _, child in ipairs(children) do
              insert(expansions, {
                name          = child.expansionName or child.professionName or "?",
                skillLevel    = child.skillLevel    or 0,
                maxSkillLevel = child.maxSkillLevel or 0,
              })
            end
            profData.expansions = expansions
          end
        end

        -- Total spec points spent across all spec trees for this profession.
        -- Returns nil for secondary professions that have no spec tree.
        if C_ProfSpecs and C_ProfSpecs.GetConfigIDForSkillLine then
          local configID = C_ProfSpecs.GetConfigIDForSkillLine(skillLineID)
          if configID and C_Traits and C_Traits.GetConfigInfo then
            local configInfo = C_Traits.GetConfigInfo(configID)
            if configInfo and configInfo.treeIDs then
              local points = 0
              for _, treeID in ipairs(configInfo.treeIDs) do
                if C_Traits.GetTreeInfo then
                  local treeInfo = C_Traits.GetTreeInfo(configID, treeID)
                  if treeInfo and treeInfo.pointsSpent then
                    points = points + treeInfo.pointsSpent
                  end
                end
              end
              profData.specPoints = points
            end
          end
        end

        -- Per-expansion learned recipes (ids + names).  Recipes are only queryable
        -- while the trade-skill window is open.  Every profession (including Fishing
        -- and Cooking) exposes per-expansion child skill lines; we bucket each recipe
        -- by the child it belongs to so future expansions can be added without reshape.
        -- (Forever: one child per profession named after it -- inferred from the Tailoring probe --
        -- bucketed as "forever", see recipeBucketKey; GetAllRecipeIDs lists the whole classic profession.)
        if C_TradeSkillUI.GetChildProfessionInfos and C_TradeSkillUI.GetAllRecipeIDs then
          local children  = C_TradeSkillUI.GetChildProfessionInfos()
          local recipeIDs = C_TradeSkillUI.GetAllRecipeIDs()
          if children and recipeIDs and #recipeIDs > 0 then
            local recipes = ns.CaptureRecipes(children, recipeIDs, C_TradeSkillUI)
            profData.recipes = recipes
            -- Pre-resolve this profession's current-expansion recipes into the
            -- account-wide prof-gear cache while trade-skill data is hot (see
            -- data/recipegear.lua); other consumers then hit a warm cache.  For
            -- the ones that craft profession gear, also capture the crafting
            -- quality THIS character can currently reach — with and without
            -- concentration — so the gear tooltip can tell whether an alt could
            -- actually produce an upgrade (knowing the recipe ≠ having the skill).
            -- Empty reagents ⇒ skill-floor quality, a deliberately conservative
            -- estimate (better mats only ever improve on it).
            ns.CaptureRecipeQuality(recipes, C_TradeSkillUI)
          end
        end

        -- Read the live value at timer-fire time rather than the value captured at
        -- event time; prevents a stale merge if another profession was opened and
        -- saved while this timer was pending.
        local data = {}
        local live = self.get_live and self.get_live() or currentValue
        if live then
          for k, v in pairs(live) do data[k] = v end
        end
        -- Per-field nil-guard: the trade-skill API often returns empty before its
        -- data finishes loading (e.g. GetChildProfessionInfos()/GetAllRecipeIDs()
        -- empty at login).  Since this overwrites the whole detail, any field the
        -- scan didn't populate this pass falls back to the previously-stored value
        -- rather than wiping good cached data.
        local prev = data[skillLineID]
        if prev then
          if not profData.expansions then profData.expansions = prev.expansions end
          if profData.specPoints == nil then profData.specPoints = prev.specPoints end
          if not profData.recipes then profData.recipes = prev.recipes end
        end
        data[skillLineID] = profData
        self:set(data)
      end)
    end,
  },
}

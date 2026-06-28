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
---@field recipes table<string, ProfRecipeBucket>? -- keyed by expansion (midnight/tww/df)

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

ns.Professions = ns:RegisterBroker("professions")

ns.Professions.fields = {
  details = {
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
        if C_TradeSkillUI.GetChildProfessionInfos and C_TradeSkillUI.GetAllRecipeIDs then
          local children  = C_TradeSkillUI.GetChildProfessionInfos()
          local recipeIDs = C_TradeSkillUI.GetAllRecipeIDs()
          if children and recipeIDs and #recipeIDs > 0 then
            local recipes
            for _, child in ipairs(children) do
              local key = RECIPE_EXP_KEYS[child.expansionName]
              if key and child.professionID then
                local learned, total = {}, 0
                for _, id in ipairs(recipeIDs) do
                  if C_TradeSkillUI.IsRecipeInSkillLine(id, child.professionID) then
                    total = total + 1
                    local info = C_TradeSkillUI.GetRecipeInfo(id)
                    if info and info.learned then
                      insert(learned, { id = id, name = info.name })
                    end
                  end
                end
                recipes = recipes or {}
                recipes[key] = { learned = learned, total = total }
              end
            end
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
            local current = recipes and recipes[RECIPE_EXP_KEYS[ns.CURRENT_RECIPE_EXP]]
            for _, r in ipairs(current and current.learned or {}) do
              if API:ResolveRecipeOutput(r.id) and C_TradeSkillUI.GetCraftingOperationInfo then
                local base = C_TradeSkillUI.GetCraftingOperationInfo(r.id, {}, nil, false)
                local conc = C_TradeSkillUI.GetCraftingOperationInfo(r.id, {}, nil, true)
                r.quality     = base and base.craftingQuality
                r.qualityConc = conc and conc.craftingQuality
              end
            end
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

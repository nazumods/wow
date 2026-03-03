local _, ns = ...
local API = ns.api
local insert = table.insert
-- luacheck: globals C_TradeSkillUI C_ProfSpecs C_Traits C_Timer

API.professionInfo = {
  sl171 = {
    name = "Alchemy",
    skillLineID = 171,
    skillLineVariantID = 2871,
    spellID = 423321,
  },
  sl164 = {
    name = "Blacksmithing",
    skillLineID = 164,
    skillLineVariantID = 2872,
    spellID = 423332,
  },
  sl333 = {
    name = "Enchanting",
    skillLineID = 333,
    skillLineVariantID = 2874,
    spellID = 423334,
  },
  sl202 = {
    name = "Engineering",
    skillLineID = 202,
    skillLineVariantID = 2875,
    spellID = 423335,
  },
  sl182 = {
    name = "Herbalism",
    skillLineID = 182,
    skillLineVariantID = 2877,
    spellID = 441327,
  },
  sl773 = {
    name = "Inscription",
    skillLineID = 773,
    skillLineVariantID = 2878,
    spellID = 423338,
  },
  sl755 = {
    name = "Jewelcrafting",
    skillLineID = 755,
    skillLineVariantID = 2879,
    spellID = 423339,
  },
  sl165 = {
    name = "Leatherworking",
    skillLineID = 165,
    skillLineVariantID = 2880,
    spellID = 423340,
  },
  sl186 = {
    name = "Mining",
    skillLineID = 186,
    skillLineVariantID = 2881,
    spellID = 423341,
  },
  sl393 = {
    name = "Skinning",
    skillLineID = 393,
    skillLineVariantID = 2882,
    spellID = 423342,
  },
  sl197 = {
    name = "Tailoring",
    skillLineID = 197,
    skillLineVariantID = 2883,
    spellID = 423343,
  },
}

---@class ProfDetail
---@field expansions {name:string, skillLevel:integer, maxSkillLevel:integer}[]?
---@field specPoints integer?

---@class Character
---@field professions ProfessionsBroker

---@class ProfessionsBroker: Broker
---@field details table<integer, ProfDetail>?

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
      -- Small delay mirrors TRADE_SKILL_SHOW usage elsewhere; ensures child profession
      -- info is fully populated before we query it.
      C_Timer.After(0.5, function()
        if not C_TradeSkillUI or not C_TradeSkillUI.GetBaseProfessionInfo then return end
        local baseInfo = C_TradeSkillUI.GetBaseProfessionInfo()
        if not baseInfo or not baseInfo.professionID then return end

        local skillLineID = baseInfo.professionID
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

        -- Merge with existing entries so data from other professions is preserved.
        local data = {}
        if currentValue then
          for k, v in pairs(currentValue) do data[k] = v end
        end
        data[skillLineID] = profData
        self:set(data)
      end)
    end,
  },
}

---@class ShadowsOfUI_QuestXP: AddOn
local ns = LibNAddOn(...)

local floor = math.floor
local Player = ns.wow.Player

---Whole-percent value of the currently-selected quest's XP reward, relative to the XP needed
---for the player's current level. Nil when there's nothing to show (max level, no XP reward).
---@return number?
local function GetRewardPercent()
  if Player:isMaxLevel() then return end

  local xp = GetQuestLogRewardXP()
  if not xp or xp <= 0 then return end

  local maxXP = Player:GetMaxXP()
  if maxXP == 0 then return end

  return floor(100 * xp / maxXP + 0.5)
end
ns.GetRewardPercent = GetRewardPercent

-- QuestInfoFrame is shared between the map quest-log Details pane and the NPC quest-greeting
-- dialogs, reparenting its rewardsFrame between MapQuestInfoRewardsFrame and
-- QuestInfoRewardsFrame accordingly (see QuestInfo.lua). Only the map pane is in scope here.
hooksecurefunc("QuestInfo_ShowRewards", function()
  if QuestInfoFrame.rewardsFrame ~= MapQuestInfoRewardsFrame then return end
  if not MapQuestInfoRewardsFrame.XPFrame:IsShown() then return end

  local percent = GetRewardPercent()
  if not percent then return end

  local nameText = MapQuestInfoRewardsFrame.XPFrame.Name
  nameText:SetText(nameText:GetText() .. " " .. GRAY_FONT_COLOR:WrapTextInColorCode(("(%d%%)"):format(percent)))
end)

-- /squestxp — dump the computed percent for the currently selected quest log quest (testing
-- aid: the Details pane must be open on a quest with an XP reward for GetQuestLogRewardXP to
-- return anything meaningful).
SLASH_SUI_QUESTXP1 = "/squestxp"
SlashCmdList["SUI_QUESTXP"] = function()
  local questID = C_QuestLog.GetSelectedQuest()
  local percent = GetRewardPercent()
  ns.Print(("Selected quest %d -> %s"):format(questID or 0, percent and ("(%d%%)"):format(percent) or "n/a"))
end

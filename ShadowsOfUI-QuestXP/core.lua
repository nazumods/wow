---@class ShadowsOfUI_QuestXP: AddOn
local ns = LibNAddOn(...)

-- "Changelog" button in settings (ns.changelog from changelog.lua).
ns:RegisterChangelog("Shadows of UI")

local floor = math.floor
local Player = ns.wow.Player

---Whole-percent value of the currently-selected quest's XP reward, relative to the XP needed
---for the player's current level. Nil when there's nothing to show (max level, no XP reward);
---0 for a real reward worth under half a percent of the level (rounds down) — the display
---layer renders that as "<1%" rather than a misleading "(0%)".
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

---The reward-percent tag to append: "(N%)" for a reward worth ≥1% of the level, "(<1%)"
---for a real reward that rounds below 0.5% (so it never reads as a valueless "(0%)"), or
---nil when there's nothing to show.
---@return string?
local function RewardPercentText()
  local percent = GetRewardPercent()
  if not percent then return end
  return percent == 0 and "(<1%)" or ("(%d%%)"):format(percent)
end

-- MapQuestInfoRewardsFrame.XPFrame.Name is the FontString the map quest-log Details pane uses
-- for the XP reward number (confirmed live via /framestack) — distinct from QuestInfoRewardsFrame,
-- which NPC quest-greeting dialogs use, so this is inherently map-only. Whatever code populates it
-- (the render entry point has changed across client reworks and isn't worth chasing) must call
-- SetText on it, so hooking the widget itself is the stable target rather than a render function.
-- appending guards against the recursive SetText call triggering this same hook.
local appending = false
local function OnXPTextSet(fontString, text)
  if appending or not text then return end

  local label = RewardPercentText()
  if not label then return end

  appending = true
  fontString:SetText(text .. " " .. GRAY_FONT_COLOR:WrapTextInColorCode(label))
  appending = false
end

-- MapQuestInfoRewardsFrame belongs to an on-demand Blizzard UI module, so it may not exist yet
-- when this file loads at login; fall back to hooking it the first time the map is shown.
local hooked = false
local function EnsureHooked()
  if hooked or not MapQuestInfoRewardsFrame then return end
  hooked = true
  hooksecurefunc(MapQuestInfoRewardsFrame.XPFrame.Name, "SetText", OnXPTextSet)
end

EnsureHooked()
if not hooked then
  WorldMapFrame:HookScript("OnShow", EnsureHooked)
end

-- /squestxp — dump the computed percent for the currently selected quest log quest (testing
-- aid: the Details pane must be open on a quest with an XP reward for GetQuestLogRewardXP to
-- return anything meaningful).
SLASH_SUI_QUESTXP1 = "/squestxp"
SlashCmdList["SUI_QUESTXP"] = function()
  local questID = C_QuestLog.GetSelectedQuest()
  ns.Print(("Selected quest %d -> %s"):format(questID or 0, RewardPercentText() or "n/a"))
end

---@type ShadowsOfUI_Quests
local ns = select(2, ...)

-- The world-map quest log builds each row's tooltip in QuestMapLogTitleButton_OnEnter, which
-- fires this EventRegistry callback with (button, questID) once the tooltip is populated.
-- Append our cross-alt block and re-Show so GameTooltip resizes around the added lines.
EventRegistry:RegisterCallback("QuestMapLogTitleButton.OnEnter", function(_, _, questID)
  if not questID then return end
  if ns.AppendQuestStatus(GameTooltip, questID) then GameTooltip:Show() end
end)

-- /squests <questID> — print the cross-alt status for a quest (testing aid + a quick
-- "who else needs this?" lookup, since tooltip text can't be copied).
SLASH_SUI_QUESTS1 = "/squests"
SlashCmdList["SUI_QUESTS"] = function(msg)
  local questID = tonumber(msg and msg:match("%d+"))
  if not questID then ns.Print("Usage: /squests <questID>") return end
  local s = ns.api:GetQuestStatus(questID)
  if not s then ns.Print("No tracked character is on or has completed quest", questID) return end
  local function dump(label, list)
    if #list == 0 then return end
    local n = {}
    for _, e in ipairs(list) do n[#n + 1] = e.name end
    ns.Print(label .. ": " .. table.concat(n, ", "))
  end
  ns.Print(("Quest %d:"):format(questID))
  dump("  Active", s.active)
  dump("  Completed", s.completed)
end

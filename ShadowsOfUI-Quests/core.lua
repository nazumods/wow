---@class ShadowsOfUI_Quests: AddOn
local ns = LibNAddOn(...)

local concat = table.concat
local LABEL = NORMAL_FONT_COLOR
local MUTED = GRAY_FONT_COLOR
local className = ns.Colors.className
local MAX = 6 -- names per line before collapsing into "+N more"

-- Class-coloured name list for a set of {name, classKey} entries, excluding the current
-- character (you already know your own status), capped at MAX + "+N more".
local function names(entries, me)
  local out, extra = {}, 0
  for _, e in ipairs(entries) do
    if e.name ~= me then
      if #out < MAX then out[#out + 1] = className(e.name, e.classKey) else extra = extra + 1 end
    end
  end
  if extra > 0 then out[#out + 1] = MUTED:WrapTextInColorCode(("+%d more"):format(extra)) end
  return out
end

-- Append the cross-alt quest block — "Also on this quest:" / "Completed by:" — for one quest
-- to a tooltip, listing other characters only. Returns false (nothing added) when no other
-- character is on or has completed it. Shared by the quest-log hook (+ /squests).
---@return boolean appended
function ns.AppendQuestStatus(tooltip, questID)
  local s = ns.api:GetQuestStatus(questID)
  if not s then return false end
  local me = ns.api:GetCurrentCharacter()
  local onIt, done = names(s.active, me), names(s.completed, me)
  if #onIt == 0 and #done == 0 then return false end
  if #onIt > 0 then
    tooltip:AddLine(LABEL:WrapTextInColorCode("Also on this quest: ") .. concat(onIt, ", "), nil, nil, nil, true)
  end
  if #done > 0 then
    tooltip:AddLine(LABEL:WrapTextInColorCode("Completed by: ") .. concat(done, ", "), nil, nil, nil, true)
  end
  return true
end

---@type ShadowsOfUI_Known
local ns = select(2, ...)

local LABEL = NORMAL_FONT_COLOR
local GetProfessionName = C_TradeSkillUI and C_TradeSkillUI.GetProfessionNameForSkillLineAbility

-- Forward declaration: renderKnownBy is defined further down (with the crafting-order
-- surface) but the recipe-item hook above it also renders a "Known by:" line.
local renderKnownBy

-- Display name wrapped in the alt's class colour, or red when the alt doesn't yet meet
-- the recipe's skill requirement (ns.Colors keys are PascalCase, matching Character.classKey).
---@param e KnownEntry
local function colorName(e)
  if not e.meets then return RED_FONT_COLOR:WrapTextInColorCode(e.name) end
  return ns.Colors.className(e.name, e.classKey)
end

-- Append the "Learnable by:" block. A single alt is one inline line; multiple alts get a
-- header plus up to 5 names, or the first 4 then "and N more." once past 5.
---@param list KnownEntry[]
local function render(tooltip, list)
  local n = #list
  if n == 1 then
    tooltip:AddLine(LABEL:WrapTextInColorCode("Learnable by:") .. " " .. colorName(list[1]))
    return
  end
  tooltip:AddLine(LABEL:WrapTextInColorCode("Learnable by:"))
  local shown = n > 5 and 4 or n
  for i = 1, shown do
    tooltip:AddLine("  " .. colorName(list[i]))
  end
  if n > shown then
    tooltip:AddLine(GRAY_FONT_COLOR:WrapTextInColorCode(("  and %d more."):format(n - shown)))
  end
end

-- The localized "Requires " prefix of the skill line, taken from ITEM_MIN_SKILL
-- ("Requires %s (%d)") — everything before the profession-name placeholder.
local REQ_PREFIX = ITEM_MIN_SKILL and ITEM_MIN_SKILL:match("^(.-)%%s")

-- The recipe's skill threshold, read from the "Requires <Profession> (NN)" line.
-- Anchored to that line via REQ_PREFIX so an earlier incidental "(NN)" — a stat, a
-- set-piece "(2)", a level range — isn't misread as the requirement. Line 1 (the
-- item name) is always skipped. Falls back to the first parenthesised integer on
-- lines 2+ when ITEM_MIN_SKILL is unavailable.
---@param data table  tooltip data (expects `.lines[i].leftText`)
---@return integer
function ns.ReqSkill(data)
  local lines = data.lines
  if not lines then return 0 end
  for i = 2, #lines do
    local txt = lines[i].leftText
    if txt and (not REQ_PREFIX or REQ_PREFIX == "" or txt:find(REQ_PREFIX, 1, true)) then
      local v = txt:match("%((%d+)%)")
      if v then return tonumber(v) end
    end
  end
  return 0
end

ns:OnItemTooltip(function(tooltip, data)
  if not data.id then return end
  local nm = data.lines and data.lines[1] and data.lines[1].leftText
  local list, knownList = ns.BuildLearnable(data.id, ns.ReqSkill(data), nm)
  if not list then return end
  -- Who already knows it first (the common "can I make this?" question), then who could
  -- still learn it. Either line is skipped when its list is empty.
  if #knownList > 0 then renderKnownBy(tooltip, knownList) end
  if #list > 0 then render(tooltip, list) end
end)

-- ─── "Known by" on the Place Crafting Order browse list ─────────────────────────
--
-- Hovering a recipe row there shows the result item's tooltip; the row sets itself as the
-- tooltip owner and carries the recipe on `option.spellID` (C_TradeSkillUI treats that as a
-- recipeID). That's our gate *and* the exact recipe identity in one — so we match by id (vs
-- the recipe-item surface above, which can only name-match), and the line shows only in that UI.
---@param tooltip table
---@return integer? recipeID, integer? skillLineAbilityID
local function customerOrderRecipe(tooltip)
  local frame = ProfessionsCustomerOrdersFrame
  if not (frame and frame:IsShown() and tooltip.GetOwner) then return nil end
  local owner = tooltip:GetOwner()
  local opt = owner and owner.option
  if not (opt and opt.spellID) then return nil end
  return opt.spellID, opt.skillLineAbilityID
end

-- "Known by:" — a single crafter inline, multiple as a header + up to 5 class-coloured names,
-- or a red "Not Known: <Profession>" when no character has learned the recipe (the profession
-- comes from the row's skillLineAbilityID, so it shows even though nobody knows the recipe).
---@param list CrafterEntry[]
---@param skillLineAbilityID integer?  the hovered recipe's ability id, for the profession name
renderKnownBy = function(tooltip, list, skillLineAbilityID)
  local n = #list
  if n == 0 then
    local prof = skillLineAbilityID and GetProfessionName and GetProfessionName(skillLineAbilityID)
    local text = prof and ("Not Known: " .. prof) or "Not Known"
    tooltip:AddLine(RED_FONT_COLOR:WrapTextInColorCode(text))
    return
  end
  if n == 1 then
    tooltip:AddLine(LABEL:WrapTextInColorCode("Known by:") .. " " .. ns.Colors.className(list[1].name, list[1].classKey))
    return
  end
  tooltip:AddLine(LABEL:WrapTextInColorCode("Known by:"))
  local shown = n > 5 and 4 or n
  for i = 1, shown do
    tooltip:AddLine("  " .. ns.Colors.className(list[i].name, list[i].classKey))
  end
  if n > shown then
    tooltip:AddLine(GRAY_FONT_COLOR:WrapTextInColorCode(("  and %d more."):format(n - shown)))
  end
end

ns:OnItemTooltip(function(tooltip)
  local recipeID, skillLineAbilityID = customerOrderRecipe(tooltip)
  if not recipeID then return end
  renderKnownBy(tooltip, ns.BuildKnownBy(recipeID), skillLineAbilityID)
end)

-- /sknown <itemID>            — print the learnable list for a recipe item
-- /sknown knownby <recipeID>  — print which crafters know a recipe (the crafting-order line)
-- Testing aids, since tooltip text can't be copied. With no live tooltip the skill threshold
-- is unknown for the learnable list, so red is not evaluated there.
SLASH_SUI_KNOWN1 = "/sknown"
SlashCmdList["SUI_KNOWN"] = function(msg)
  msg = msg or ""
  local recipeID = tonumber(msg:match("^%s*knownby%s+(%d+)"))
  if recipeID then
    local list = ns.BuildKnownBy(recipeID)
    if #list == 0 then ns.Print("Not Known by any character — recipe", recipeID); return end
    ns.Print(("Known by (%d):"):format(#list))
    for _, e in ipairs(list) do
      ns.Print((" - %s  lvl %d, rank %d"):format(e.name, e.level, e.rank))
    end
    return
  end
  local itemID = tonumber(msg:match("%d+"))
  if not itemID then ns.Print("Usage: /sknown <itemID>") return end
  local nm = GetItemInfo(itemID)
  local list, knownList = ns.BuildLearnable(itemID, 0, nm)
  if not list then ns.Print(itemID, "is not a craftable recipe item (or its data isn't loaded yet).") return end
  if #list == 0 then
    ns.Print(#knownList > 0 and "Already known — no alts left to learn" or "No alts have this profession:", nm or itemID)
  else
    ns.Print(("Learnable by (%d), already known by %d:"):format(#list, #knownList))
    for _, e in ipairs(list) do
      ns.Print((" - %s  lvl %d, skill %d, rank %d"):format(e.name, e.level, e.skill, e.rank))
    end
  end
  for _, e in ipairs(knownList) do
    ns.Print((" known: %s  lvl %d, rank %d"):format(e.name, e.level, e.rank))
  end
end

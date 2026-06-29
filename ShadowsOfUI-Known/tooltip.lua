---@type ShadowsOfUI_Known
local ns = select(2, ...)

local LABEL = NORMAL_FONT_COLOR

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

-- The first parenthesised integer among the requirement lines is the recipe's skill
-- threshold ("Requires Tailoring (425)"). Line 1 (the item name) is skipped so a recipe
-- whose name itself contains "(NN)" can't be misread as a requirement.
local function reqSkill(data)
  local lines = data.lines
  if not lines then return 0 end
  for i = 2, #lines do
    local txt = lines[i].leftText
    local v = txt and txt:match("%((%d+)%)")
    if v then return tonumber(v) end
  end
  return 0
end

ns:OnItemTooltip(function(tooltip, data)
  if not data.id then return end
  local nm = data.lines and data.lines[1] and data.lines[1].leftText
  local list, knownCount = ns.BuildLearnable(data.id, reqSkill(data), nm)
  if not list then return end
  if #list > 0 then
    render(tooltip, list)
  elseif knownCount > 0 then
    -- No one can still learn it, but at least one alt already knows it — say so, so an
    -- empty list reads as "not needed" rather than "data missing".
    tooltip:AddLine(GREEN_FONT_COLOR:WrapTextInColorCode("Already known"))
  end
end)

-- ─── "Known by" on the Place Crafting Order browse list ─────────────────────────
--
-- Hovering a recipe row there shows the result item's tooltip; the row sets itself as the
-- tooltip owner and carries the recipe on `option.spellID` (C_TradeSkillUI treats that as a
-- recipeID). That's our gate *and* the exact recipe identity in one — so we match by id (vs
-- the recipe-item surface above, which can only name-match), and the line shows only in that UI.
---@param tooltip table
---@return integer? recipeID
local function customerOrderRecipeID(tooltip)
  local frame = ProfessionsCustomerOrdersFrame
  if not (frame and frame:IsShown() and tooltip.GetOwner) then return nil end
  local owner = tooltip:GetOwner()
  local opt = owner and owner.option
  return opt and opt.spellID
end

-- "Known by:" — a single crafter inline, multiple as a header + up to 5 class-coloured names,
-- or a red "Not Known" when no character has learned the recipe.
---@param list CrafterEntry[]
local function renderKnownBy(tooltip, list)
  local n = #list
  if n == 0 then
    tooltip:AddLine(RED_FONT_COLOR:WrapTextInColorCode("Not Known"))
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
  local recipeID = customerOrderRecipeID(tooltip)
  if not recipeID then return end
  renderKnownBy(tooltip, ns.BuildKnownBy(recipeID))
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
  local list, knownCount = ns.BuildLearnable(itemID, 0, nm)
  if not list then ns.Print(itemID, "is not a craftable recipe item (or its data isn't loaded yet).") return end
  if #list == 0 then
    ns.Print(knownCount > 0 and "Already known — no alts left to learn" or "No alts have this profession:", nm or itemID)
    return
  end
  ns.Print(("Learnable by (%d), already known by %d:"):format(#list, knownCount))
  for _, e in ipairs(list) do
    ns.Print((" - %s  lvl %d, skill %d, rank %d"):format(e.name, e.level, e.skill, e.rank))
  end
end

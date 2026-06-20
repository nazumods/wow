---@type ShadowsOfUI_Artisan
local ns = select(2, ...)

local floor = math.floor
local GetCurrencyInfo = C_CurrencyInfo.GetCurrencyInfo
local BreakUpLargeNumbers = BreakUpLargeNumbers

-- Class-coloured name (ns.Colors keys are PascalCase, matching Character.classKey).
local function colorName(classKey, name)
  local c = classKey and ns.Colors[classKey]
  if not c or not c[1] then return name end
  return ("|cff%02x%02x%02x%s|r"):format(
    floor(c[1] * 255 + 0.5), floor(c[2] * 255 + 0.5), floor(c[3] * 255 + 0.5), name)
end

local function onEnter(badge)
  local list = ns.BuildBreakdown(badge.skillLineID)
  if not list or #list == 0 then return end
  GameTooltip:SetOwner(badge, "ANCHOR_RIGHT")
  local info = GetCurrencyInfo(badge.currencyId)
  local title = info and info.name or "Artisan Currency"
  if info and info.iconFileID then
    title = ("|T%d:16:16:0:0|t %s"):format(info.iconFileID, title)
  end
  GameTooltip:AddLine(title)
  for _, e in ipairs(list) do
    local nm = colorName(e.classKey, e.name)
    if e.isCurrent then nm = nm .. " " .. GRAY_FONT_COLOR:WrapTextInColorCode("(here)") end
    GameTooltip:AddDoubleLine(nm, BreakUpLargeNumbers(e.quantity), nil, nil, nil,
      HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
  end
  GameTooltip:Show()
end

-- A reusable badge (currency icon + amount), mouse-enabled for the breakdown tooltip.
local function makeBadge(parent, levelOffset)
  local badge = CreateFrame("Frame", nil, parent)
  badge:SetFrameLevel(parent:GetFrameLevel() + levelOffset)
  badge:SetSize(16, 16)
  badge:EnableMouse(true)
  badge.icon = badge:CreateTexture(nil, "ARTWORK")
  badge.icon:SetSize(16, 16)
  badge.icon:SetPoint("LEFT")
  badge.text = badge:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  badge.text:SetPoint("LEFT", badge.icon, "RIGHT", 3, 0)
  badge:SetScript("OnEnter", onEnter)
  badge:SetScript("OnLeave", GameTooltip_Hide)
  return badge
end

-- Point a badge at a profession's artisan currency. Hides it (returns false) when the
-- profession has no mapped currency or the currency isn't known yet.
local function applyBadge(badge, skillLineID, currencyId)
  local info = currencyId and GetCurrencyInfo(currencyId)
  if not info then badge:Hide() return false end
  badge.skillLineID = skillLineID
  badge.currencyId = currencyId
  if info.iconFileID then badge.icon:SetTexture(info.iconFileID) end
  badge.text:SetText(BreakUpLargeNumbers(info.quantity or 0))
  badge:SetWidth(19 + badge.text:GetStringWidth())
  badge:Show()
  return true
end

-- ── Crafting window (Blizzard_Professions) ──────────────────────────────────────────────
-- One badge beside the concentration readout, for the currently open profession.
function ns.UpdateBadge()
  local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
  if not page then return end
  local skillLineID = ns.currentSkill
  local currencyId = skillLineID and ns.ARTISAN_CURRENCIES[skillLineID]
  ns.craftBadge = ns.craftBadge or makeBadge(page, 10)
  if not applyBadge(ns.craftBadge, skillLineID, currencyId) then return end
  -- Sit just right of the concentration display; fall back to its slot when it's hidden.
  ns.craftBadge:ClearAllPoints()
  local conc = page.ConcentrationDisplay
  if conc and conc:IsShown() then
    ns.craftBadge:SetPoint("LEFT", conc, "RIGHT", 18, 0)
  else
    ns.craftBadge:SetPoint("TOPLEFT", page, "TOPLEFT", 120, -35)
  end
end

-- ── Spellbook professions page (Blizzard_ProfessionsBook) ────────────────────────────────
-- A per-profession badge tucked under the right-hand spell-button labels.
local BOOK_FRAMES = {
  "PrimaryProfession1", "PrimaryProfession2",
  "SecondaryProfession1", "SecondaryProfession2", "SecondaryProfession3",
}

function ns.UpdateBookBadges()
  for _, name in ipairs(BOOK_FRAMES) do
    local frame = _G[name]
    local skillLineID = frame and frame.skillLine
    local currencyId = skillLineID and ns.ARTISAN_CURRENCIES[skillLineID]
    if frame then
      if not currencyId then
        if frame.soiArtisanBadge then frame.soiArtisanBadge:Hide() end
      else
        frame.soiArtisanBadge = frame.soiArtisanBadge or makeBadge(frame, 5)
        if applyBadge(frame.soiArtisanBadge, skillLineID, currencyId) then
          -- Anchor under the lowest shown spell-button label (e.g. "Enchanting",
          -- "Skinning Journal") so the icon + amount read beneath that profession's spells.
          local btn = (frame.SpellButton2 and frame.SpellButton2:IsShown())
            and frame.SpellButton2 or frame.SpellButton1
          frame.soiArtisanBadge:ClearAllPoints()
          if btn and btn.spellString then
            frame.soiArtisanBadge:SetPoint("TOPLEFT", btn.spellString, "BOTTOMLEFT", 0, -3)
          else
            frame.soiArtisanBadge:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -12)
          end
        end
      end
    end
  end
end

-- ── Wiring ───────────────────────────────────────────────────────────────────────────────
-- Blizzard_Professions: the LoD crafting window.
EventUtil.ContinueOnAddOnLoaded("Blizzard_Professions", function()
  local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
  if not page then return end
  -- Refresh runs on open + every profession switch; key off the parent skill line.
  hooksecurefunc(page, "Refresh", function(_, professionInfo)
    ns.currentSkill = professionInfo and (professionInfo.parentProfessionID or professionInfo.professionID)
    ns.UpdateBadge()
  end)
  local driver = CreateFrame("Frame")
  driver:SetScript("OnEvent", ns.UpdateBadge)
  ProfessionsFrame:HookScript("OnShow", function() driver:RegisterEvent("CURRENCY_DISPLAY_UPDATE") end)
  ProfessionsFrame:HookScript("OnHide", function() driver:UnregisterEvent("CURRENCY_DISPLAY_UPDATE") end)
end)

-- Blizzard_ProfessionsBook: the spellbook's professions page.
EventUtil.ContinueOnAddOnLoaded("Blizzard_ProfessionsBook", function()
  -- FormatProfession stamps frame.skillLine on each profession frame; this hook fires after
  -- every page rebuild (open + profession change), so badges follow the displayed skills.
  hooksecurefunc("ProfessionsBookFrame_Update", ns.UpdateBookBadges)
  local driver = CreateFrame("Frame")
  driver:SetScript("OnEvent", function()
    if ProfessionsBookFrame and ProfessionsBookFrame:IsShown() then ns.UpdateBookBadges() end
  end)
  EventRegistry:RegisterCallback("ProfessionsBookFrame.Show", function()
    driver:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    ns.UpdateBookBadges()
  end, driver)
  EventRegistry:RegisterCallback("ProfessionsBookFrame.Hide", function()
    driver:UnregisterEvent("CURRENCY_DISPLAY_UPDATE")
  end, driver)
end)

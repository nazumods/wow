---@type ShadowsOfUI_Artisan
local ns = select(2, ...)

local floor = math.floor
local GetCurrencyInfo = C_CurrencyInfo.GetCurrencyInfo
local BreakUpLargeNumbers = BreakUpLargeNumbers

-- The profession frames on the spellbook's professions page (Blizzard_ProfessionsBook).
-- Secondary slots are Cooking/Fishing/Archaeology — no artisan currency — but we iterate
-- them too and let the ARTISAN_CURRENCIES gate hide the badge, so a profession swap never
-- leaves a stale badge behind.
local PROFESSION_FRAMES = {
  "PrimaryProfession1", "PrimaryProfession2",
  "SecondaryProfession1", "SecondaryProfession2", "SecondaryProfession3",
}

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

-- Lazily attach the badge (icon + amount) to a profession frame. One frame level above the
-- profession frame so the icon/text aren't covered; mouse-enabled for the breakdown tooltip.
local function ensureBadge(frame)
  if frame.soiArtisanBadge then return frame.soiArtisanBadge end
  local badge = CreateFrame("Frame", nil, frame)
  badge:SetFrameLevel(frame:GetFrameLevel() + 5)
  badge:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -12)
  badge:SetSize(16, 16)
  badge:EnableMouse(true)
  badge.icon = badge:CreateTexture(nil, "ARTWORK")
  badge.icon:SetSize(16, 16)
  badge.icon:SetPoint("LEFT")
  badge.text = badge:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  badge.text:SetPoint("LEFT", badge.icon, "RIGHT", 2, 0)
  badge:SetScript("OnEnter", onEnter)
  badge:SetScript("OnLeave", GameTooltip_Hide)
  frame.soiArtisanBadge = badge
  return badge
end

local function updateBadge(frame)
  local skillLineID = frame.skillLine
  local currencyId = skillLineID and ns.ARTISAN_CURRENCIES[skillLineID]
  local info = currencyId and GetCurrencyInfo(currencyId)
  if not info then
    if frame.soiArtisanBadge then frame.soiArtisanBadge:Hide() end
    return
  end
  local badge = ensureBadge(frame)
  badge.skillLineID = skillLineID
  badge.currencyId = currencyId
  if info.iconFileID then badge.icon:SetTexture(info.iconFileID) end
  badge.text:SetText(BreakUpLargeNumbers(info.quantity or 0))
  -- Grow the mouse area to cover icon + amount so the whole badge is hoverable.
  badge:SetWidth(18 + badge.text:GetStringWidth())
  badge:Show()
end

-- Re-tag every profession frame currently laid out. Cheap and idempotent, so it's safe to
-- call from the post-Update hook, the page-show callback, and currency updates alike.
function ns.UpdateBadges()
  for _, name in ipairs(PROFESSION_FRAMES) do
    local frame = _G[name]
    if frame then updateBadge(frame) end
  end
end

-- Blizzard_ProfessionsBook is the load-on-demand addon for the spellbook's professions
-- page; wait for it before touching its frames/functions.
EventUtil.ContinueOnAddOnLoaded("Blizzard_ProfessionsBook", function()
  -- FormatProfession stamps frame.skillLine on each profession frame; this hook fires after
  -- every page rebuild (open + profession change), so badges follow the displayed skills.
  hooksecurefunc("ProfessionsBookFrame_Update", ns.UpdateBadges)

  -- Keep the live amount fresh while the page is open without polling: only listen for
  -- currency changes between Show and Hide.
  local driver = CreateFrame("Frame")
  driver:SetScript("OnEvent", function()
    if ProfessionsBookFrame and ProfessionsBookFrame:IsShown() then ns.UpdateBadges() end
  end)
  EventRegistry:RegisterCallback("ProfessionsBookFrame.Show", function()
    driver:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    ns.UpdateBadges()
  end, driver)
  EventRegistry:RegisterCallback("ProfessionsBookFrame.Hide", function()
    driver:UnregisterEvent("CURRENCY_DISPLAY_UPDATE")
  end, driver)
end)

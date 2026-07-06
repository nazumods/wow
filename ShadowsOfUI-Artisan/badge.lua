---@type ShadowsOfUI_Artisan
local ns = select(2, ...)

local GetCurrencyInfo = C_CurrencyInfo.GetCurrencyInfo
local BreakUpLargeNumbers = BreakUpLargeNumbers
local className = ns.Colors.className

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
    local nm = className(e.name, e.classKey)
    if e.isCurrent then nm = nm .. " " .. GRAY_FONT_COLOR:WrapTextInColorCode("(here)") end
    GameTooltip:AddDoubleLine(nm, BreakUpLargeNumbers(e.quantity), nil, nil, nil,
      HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
  end
  GameTooltip:Show()
end

-- A reusable badge (currency icon + amount), mouse-enabled for the breakdown tooltip.
-- opts: iconSize, font, textX (icon→text gap), textY. Defaults suit the small spellbook badge;
-- the crafting badge passes 24px + GameFontNormal to match Blizzard's concentration readout.
local function makeBadge(parent, levelOffset, opts)
  opts = opts or {}
  local iconSize, gapX = opts.iconSize or 16, opts.textX or 3
  local badge = CreateFrame("Frame", nil, parent)
  badge:SetFrameLevel(parent:GetFrameLevel() + levelOffset)
  badge:SetSize(iconSize, iconSize)
  badge:EnableMouse(true)
  badge.iconSize, badge.gapX = iconSize, gapX
  badge.icon = badge:CreateTexture(nil, "ARTWORK")
  badge.icon:SetSize(iconSize, iconSize)
  badge.icon:SetPoint("LEFT")
  badge.text = badge:CreateFontString(nil, "ARTWORK", opts.font or "GameFontHighlight")
  badge.text:SetPoint("LEFT", badge.icon, "RIGHT", gapX, opts.textY or 0)
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
  badge:SetWidth(badge.iconSize + badge.gapX + badge.text:GetStringWidth())
  badge:Show()
  return true
end

-- ── Crafting window (Blizzard_Professions) ──────────────────────────────────────────────
-- One badge beside the concentration readout, for the currently open profession. Sized to
-- match the concentration display, and the two are centered horizontally across the page as a
-- pair (so we re-anchor Blizzard's ConcentrationDisplay too, after its own Refresh positions it).
local CRAFT_GAP = 24          -- space between the concentration amount and our badge
local CRAFT_SECTION_LEFT = 64 -- left edge of the header "section" (just right of the info button)
function ns.UpdateBadge()
  local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
  if not page then return end
  local skillLineID = ns.currentSkill
  local currencyId = skillLineID and ns.ARTISAN_CURRENCIES[skillLineID]
  ns.craftBadge = ns.craftBadge
    or makeBadge(page, 10, { iconSize = 24, font = "GameFontNormal", textX = 6, textY = 2 })
  local badge = ns.craftBadge
  if not applyBadge(badge, skillLineID, currencyId) then return end
  badge.text:SetTextColor(WHITE_FONT_COLOR:GetRGB())  -- match the white concentration amount

  badge:ClearAllPoints()
  local conc = page.ConcentrationDisplay
  local list = page.RecipeList
  if conc and conc:IsShown() and list and list:IsShown() then
    -- Center the [concentration][gap][moxie] pair within the header section it lives in: from
    -- just right of the info button (CRAFT_SECTION_LEFT) to the rank bar that owns the strip to
    -- its right — not the whole page. Use the concentration's *visible* width (its frame is a
    -- fixed 110 but the icon+amount are left-aligned) so the pair centers on what's drawn.
    local concVis = 24 + 6 + (conc.Amount and conc.Amount:GetStringWidth() or 0)
    local total = concVis + CRAFT_GAP + badge:GetWidth()
    local rightBound = 280
    if page.RankBar then local _, _, _, rx = page.RankBar:GetPoint(1); rightBound = rx or rightBound end
    local centerX = (CRAFT_SECTION_LEFT + rightBound) / 2
    local _, _, _, _, y = conc:GetPoint(1)
    conc:ClearAllPoints()
    conc:SetPoint("TOPLEFT", page, "TOPLEFT", centerX - total / 2, y or -35)
    badge:SetPoint("LEFT", conc, "LEFT", concVis + CRAFT_GAP, 0)
  elseif conc and conc:IsShown() then
    -- Minimized view (no recipe list): leave Blizzard's concentration where it is, sit beside it.
    badge:SetPoint("LEFT", conc, "RIGHT", 12, 0)
  else
    badge:SetPoint("TOP", page, "TOP", 0, -35)
  end
end

-- ── Crafting Orders page (Blizzard_Professions OrdersPage) ───────────────────────────────
-- Mirror of the crafting-window badge for the Crafting Orders tab, whose header has no
-- concentration readout to sit beside. Same profession/currency as the crafting window; placed
-- at the header slot the crafting badge falls back to (both pages setAllPoints the frame, so the
-- page-relative offset lands in the same on-screen spot).
function ns.UpdateOrderBadge()
  local page = ProfessionsFrame and ProfessionsFrame.OrdersPage
  if not page then return end
  local skillLineID = ns.currentSkill
  local currencyId = skillLineID and ns.ARTISAN_CURRENCIES[skillLineID]
  ns.orderBadge = ns.orderBadge
    or makeBadge(page, 10, { iconSize = 24, font = "GameFontNormal", textX = 6, textY = 2 })
  local badge = ns.orderBadge
  if not applyBadge(badge, skillLineID, currencyId) then return end
  badge.text:SetTextColor(WHITE_FONT_COLOR:GetRGB())  -- match the white crafting-window amount
  badge:ClearAllPoints()
  -- Selecting an order shows the OrderView's own concentration pool in this same header slot
  -- (TOPLEFT 120,-35); when it's up, sit just to its right so both read cleanly. On the browse
  -- list that display is hidden, so the badge takes the slot on its own.
  local conc = page.OrderView and page.OrderView.ConcentrationDisplay
  if conc and conc:IsShown() then
    badge:SetPoint("LEFT", conc, "RIGHT", 16, 0)
  else
    badge:SetPoint("TOPLEFT", page, "TOPLEFT", 120, -35)
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
      -- Blizzard's FormatProfession stamps frame.skillLine only in the has-profession
      -- branch and never nils it when a slot empties (unlearned profession) — but it DOES
      -- hide the slot's SpellButtons. Gate on SpellButton1 being shown, or a stale skillLine
      -- would float a phantom badge in the now-empty slot (its currency is still known).
      local hasProfession = frame.SpellButton1 and frame.SpellButton1:IsShown()
      if not currencyId or not hasProfession then
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

  -- Crafting Orders tab: Refresh fires for every page on each profession switch, so the same
  -- professionInfo drives this badge too; a dedicated driver refreshes it on currency change.
  local orders = ProfessionsFrame.OrdersPage
  if orders then
    hooksecurefunc(orders, "Refresh", function(_, professionInfo)
      ns.currentSkill = professionInfo and (professionInfo.parentProfessionID or professionInfo.professionID)
      ns.UpdateOrderBadge()
    end)
    local orderDriver = CreateFrame("Frame")
    orderDriver:SetScript("OnEvent", ns.UpdateOrderBadge)
    orders:HookScript("OnShow", function()
      orderDriver:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
      ns.UpdateOrderBadge()
    end)
    orders:HookScript("OnHide", function() orderDriver:UnregisterEvent("CURRENCY_DISPLAY_UPDATE") end)
    -- The OrderView's concentration pool appears/vanishes in our header slot as orders are
    -- selected/closed; re-anchor the badge beside it (or back to the slot) on each toggle.
    local conc = orders.OrderView and orders.OrderView.ConcentrationDisplay
    if conc then
      conc:HookScript("OnShow", ns.UpdateOrderBadge)
      conc:HookScript("OnHide", ns.UpdateOrderBadge)
    end
  end
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

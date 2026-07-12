---@type ShadowsOfUI_HousingVendor
local ns = select(2, ...)

local function db(key) return ns.db and ns.db[key] end

local NUMBER_FONT = "Fonts\\ARIALN.TTF"
local STAR_ATLAS = "auctionhouse-icon-favorite"           -- gold star (AH/profession favourite)
local CHECK_TEX = "Interface\\RaidFrame\\ReadyCheck-Ready" -- green check

-- Overlay layer for an item button (merchant / bags / bank / Bagnon): a frame one
-- level above the icon with three indicators, each in a corner clear of the icon's
-- own stack-count number (bottom-right). Built lazily and reused across refreshes.
-- Decor is never gear, so this never collides with ShadowsOfUI-Ilvl's overlays.
---@param button table item button (frame)
---@return table overlay
function ns.EnsureOverlay(button)
  if button.shvOverlay then return button.shvOverlay end
  local o = CreateFrame("Frame", nil, button)
  o:SetAllPoints()
  o:SetFrameLevel(button:GetFrameLevel() + 1)

  -- Every indicator starts hidden. Textures/FontStrings are created shown by
  -- default, and ApplyOverlay only ever :Show()s the ones that pass their gate
  -- (it leans on CleanOverlay to hide the rest). But on a button's FIRST paint
  -- CleanOverlay runs before this overlay exists — a no-op — so without hiding
  -- them here the freshly-created star/check/count would sit visible regardless of
  -- settings or owned-state until the next repaint (reopen/toggle). That's the
  -- "everything shows on first open" bug.
  local count = o:CreateFontString(nil, "OVERLAY")
  count:SetFont(NUMBER_FONT, 12, "OUTLINE")
  count:SetPoint("BOTTOMLEFT", 4, 4)
  count:Hide()
  o.count = count

  -- Star (unowned + bonus) and check (owned) are mutually exclusive, so they share
  -- the top-left corner. Top-right is left free for other addons' unowned markers.
  local star = o:CreateTexture(nil, "OVERLAY")
  star:SetAtlas(STAR_ATLAS)
  star:SetSize(14, 14)
  star:SetPoint("TOPLEFT", 1, -1)
  star:Hide()
  o.star = star

  local check = o:CreateTexture(nil, "OVERLAY")
  check:SetTexture(CHECK_TEX)
  check:SetSize(14, 14)
  check:SetPoint("TOPLEFT", 1, -1)
  check:Hide()
  o.check = check

  button.shvOverlay = o
  return o
end

-- Hide every indicator on a button. Callers clean before repainting so a disabled
-- indicator (or a slot that no longer holds decor) leaves nothing behind.
---@param button table item button (frame)
function ns.CleanOverlay(button)
  local o = button.shvOverlay
  if o then o.count:Hide(); o.star:Hide(); o.check:Hide() end
end

-- Paint a button's overlay from normalized decor info, honouring the per-indicator
-- toggles. Callers ns.CleanOverlay() first, so a disabled indicator leaves nothing.
---@param button table item button (frame)
---@param d HVDecorInfo normalized decor info
function ns.ApplyOverlay(button, d)
  local o = ns.EnsureOverlay(button)
  if db("countBadge") and d.owned then
    o.count:SetText(d.stored)
    -- Owned but nothing on hand (all placed): dim the 0 so it reads as "none to place".
    if d.stored > 0 then o.count:SetTextColor(1, 1, 1) else o.count:SetTextColor(0.6, 0.6, 0.6) end
    o.count:Show()
  end
  if db("ownedCheck") and d.owned then o.check:Show() end
  if db("bonusBadge") and d.bonusAvailable then o.star:Show() end
end

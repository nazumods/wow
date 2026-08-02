---@type ShadowsOfUI_HousingVendor
local ns = select(2, ...)

local function db(key) return ns.db and ns.db[key] end

local NUMBER_FONT = "Fonts\\ARIALN.TTF"
local STAR_ATLAS = "auctionhouse-icon-favorite"           -- gold star (AH/profession favourite)
local CHECK_TEX = "Interface\\RaidFrame\\ReadyCheck-Ready" -- green check
-- The "wanted" marker's atlas. Warbandeer_Decor publishes the same atlas on its API so
-- every surface that draws the wanted flag reads identically; this literal is the
-- fallback used only when that addon isn't installed (in which case the marker never
-- actually shows), so the two can't visibly drift.
local WANTED_ATLAS = "PetJournal-FavoritesIcon"

-- Warbandeer_Decor's read/write wanted API (a global it publishes), or nil when that
-- addon isn't loaded. A soft dependency: the wanted marker is simply never drawn without
-- it, mirroring how ShadowsOfUI-Collectibles treats *this* addon's HousingDecorApi.
local function wantedApi() return _G.WarbandeerHousingDecorApi end

-- Create an overlay indicator hidden. Textures/FontStrings are created shown by
-- default, and ApplyOverlay only ever :Show()s the ones that pass their gate (it
-- leans on CleanOverlay to hide the rest). But on a button's FIRST paint CleanOverlay
-- runs before the overlay exists — a no-op — so an unhidden indicator would sit visible
-- regardless of settings or owned-state until the next repaint (reopen/toggle): the
-- "everything shows on first open" bug. Routing every indicator through here makes
-- "starts hidden" structural, so a newly-added indicator can't reintroduce it.
local function hidden(region)
  region:Hide()
  return region
end

-- Overlay layer for an item button (merchant / bags / bank / Bagnon): a frame above the
-- icon with four indicators, each in a corner clear of the icon's own stack-count number
-- (bottom-right). Built lazily and reused across refreshes.
-- Decor is never gear, so this never collides with ShadowsOfUI-Ilvl's overlays.
-- Frame level: +1 clears the button's own icon / border / IconOverlay TEXTURES (which sit
-- at the button's level), which is all the count / bonus-star / owned-check corners need.
-- But another addon's overlay draws an "already-collected" check on a higher child FRAME in
-- the top-right — the very corner the wanted star uses — so at +1 the star drew *under* it.
-- Lift the whole overlay well above that; the offset is generous on purpose (the exact
-- level of another addon's frame isn't ours to assume). Verified in-game (#894).
---@param button table item button (frame)
---@return table overlay
function ns.EnsureOverlay(button)
  if button.shvOverlay then return button.shvOverlay end
  local o = CreateFrame("Frame", nil, button)
  o:SetAllPoints()
  o:SetFrameLevel(button:GetFrameLevel() + 20)

  local count = hidden(o:CreateFontString(nil, "OVERLAY"))
  count:SetFont(NUMBER_FONT, 12, "OUTLINE")
  count:SetPoint("BOTTOMLEFT", 4, 4)
  o.count = count

  -- Star (unowned + bonus) and check (owned) are mutually exclusive, so they share
  -- the top-left corner. Top-right is left free for other addons' unowned markers.
  local star = hidden(o:CreateTexture(nil, "OVERLAY"))
  star:SetAtlas(STAR_ATLAS)
  star:SetSize(14, 14)
  star:SetPoint("TOPLEFT", 1, -1)
  o.star = star

  local check = hidden(o:CreateTexture(nil, "OVERLAY"))
  check:SetTexture(CHECK_TEX)
  check:SetSize(14, 14)
  check:SetPoint("TOPLEFT", 1, -1)
  o.check = check

  -- "Wanted" marker, top-right — the corner the star/check block deliberately leaves free.
  -- Reads its atlas from Warbandeer_Decor's API so it matches that addon's own wanted star,
  -- falling back to the identical literal when the addon is absent (the marker never shows then).
  local wanted = hidden(o:CreateTexture(nil, "OVERLAY"))
  local api = wantedApi()
  wanted:SetAtlas(api and api.WantedIcon or WANTED_ATLAS)
  wanted:SetSize(14, 14)
  wanted:SetPoint("TOPRIGHT", -1, -1)
  o.wanted = wanted

  button.shvOverlay = o
  return o
end

-- Hide every indicator on a button. Callers clean before repainting so a disabled
-- indicator (or a slot that no longer holds decor) leaves nothing behind.
---@param button table item button (frame)
function ns.CleanOverlay(button)
  local o = button.shvOverlay
  if o then o.count:Hide(); o.star:Hide(); o.check:Hide(); o.wanted:Hide() end
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
  -- Wanted marker: cross-reference the entry's recordID against Warbandeer_Decor's wanted
  -- flags. The API methods are colon-defined, so `:IsWanted` (not `.IsWanted`) — a dot call
  -- would pass recordID as `self`. No-op when the addon (hence the API) isn't loaded.
  local wanted = wantedApi()
  if db("wantedBadge") and wanted and d.recordID and wanted:IsWanted(d.recordID) then
    o.wanted:Show()
  end
end

---@class LibNAddOn
local ns = select(2, ...)
local floor, min, max = math.floor, math.min, math.max
local sort = table.sort

-- Live action-bar reader on ns.wow. Reads the on-screen buttons addon-agnostically
-- (LibActionButton-1.0 → Bartender/Dominos/ElvUI, plus the Blizzard default bars)
-- and reports each bar's real orientation and shape, so a preview can mirror the
-- user's actual layout instead of Blizzard Edit Mode data (which bar addons override).
-- Guarded so this file is independent of load order (and loadable standalone in specs);
-- globals/wow.lua creates ns.wow with its data.
ns.wow = ns.wow or {}

-- Blizzard default bar button name prefixes, scanned as a fallback when the user
-- isn't running a LibActionButton bar addon.
local BLIZZ_BARS = {
  "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
  "MultiBarRightButton", "MultiBarLeftButton",
  "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
}

-- Current paged action slot for a button, or nil if it isn't an action button.
-- LibActionButton buttons expose _state_type/_state_action; Blizzard buttons carry
-- a plain .action field.
local function actionSlot(btn)
  local t = btn._state_type
  if t == nil then
    local a = btn.action
    return type(a) == "number" and a or nil
  end
  if t ~= "action" then return nil end
  local a = btn._state_action
  return type(a) == "number" and a or nil
end

-- Count clusters among 1-D positions: sort, then start a new cluster wherever the
-- gap to the previous value exceeds `tol`.
local function countClusters(values, tol)
  sort(values)
  local clusters, prev = 0, nil
  for _, v in ipairs(values) do
    if prev == nil or (v - prev) > tol then clusters = clusters + 1 end
    prev = v
  end
  return clusters
end

-- PURE (no WoW API): classify a bar from its buttons' screen rects. Each rect is
-- `{ left, right, bottom, top }` in UI coordinates. Returns the fields the
-- Warbandeer Bars preview's `_showBar` consumes — `orientation` (0=horizontal,
-- 1=vertical), `numIcons`, and `numRows` (stacks along the short axis). Returns
-- nil for an empty rect list.
---@param rects table[]  array of { left, right, bottom, top }
---@return table? info  { orientation = 0|1, numIcons = integer, numRows = integer }
function ns.wow.classifyBarRects(rects)
  local n = #rects
  if n == 0 then return nil end

  local minL, maxR, minB, maxT, sumW, sumH
  for _, r in ipairs(rects) do
    minL = min(minL or r.left,   r.left);   maxR = max(maxR or r.right, r.right)
    minB = min(minB or r.bottom, r.bottom); maxT = max(maxT or r.top,   r.top)
    sumW = (sumW or 0) + (r.right - r.left)
    sumH = (sumH or 0) + (r.top   - r.bottom)
  end

  local vertical = (maxT - minB) > (maxR - minL)

  -- Stacks run along the short axis: rows (horizontal) cluster by Y-centre, columns
  -- (vertical) cluster by X-centre. Tolerance = half the mean button extent on that
  -- axis, so buttons on one line group together and the next line starts a new stack.
  local centers, tol = {}
  if vertical then
    tol = (sumW / n) * 0.5
    for i, r in ipairs(rects) do centers[i] = (r.left + r.right) / 2 end
  else
    tol = (sumH / n) * 0.5
    for i, r in ipairs(rects) do centers[i] = (r.bottom + r.top) / 2 end
  end

  return {
    orientation = vertical and 1 or 0,
    numIcons    = n,
    numRows     = countClusters(centers, tol),
  }
end

-- Gather every candidate action button on screen from both sources.
local function collectButtons(out)
  local LAB = LibStub and LibStub("LibActionButton-1.0", true)
  if LAB and LAB.GetAllButtons then
    for btn in pairs(LAB:GetAllButtons()) do out[#out + 1] = btn end
  end
  for _, prefix in ipairs(BLIZZ_BARS) do
    for i = 1, 12 do
      local b = _G[prefix .. i]
      if b then out[#out + 1] = b end
    end
  end
end

-- Read the live action bars into a per-bar layout map keyed by slot-range bar
-- (`floor((slot-1)/12)+1`, 1-15 — the same bar model Warbandeer_Bars profiles use).
-- Each entry is `{ orientation, numIcons, numRows, enabled = true }`. Only bars with
-- visible, positioned buttons are included, so `enabled` reflects real on-screen state
-- (an enabled-but-empty bar still reports, since its buttons are visible). Reads the
-- currently logged-in character's bars — capture it per profile for a cross-character
-- preview.
---@return table<integer, table>  bar → { orientation, numIcons, numRows, enabled }
function ns.wow.ReadActionBars()
  local buttons = {}
  collectButtons(buttons)

  local byBar = {}
  for _, b in ipairs(buttons) do
    if b:IsVisible() then
      local slot = actionSlot(b)
      if slot and slot >= 1 and slot <= 180 then
        local l, r, bo, t = b:GetLeft(), b:GetRight(), b:GetBottom(), b:GetTop()
        if l and r and bo and t then
          local bar = floor((slot - 1) / 12) + 1
          local arr = byBar[bar]
          if not arr then arr = {}; byBar[bar] = arr end
          arr[#arr + 1] = { left = l, right = r, bottom = bo, top = t }
        end
      end
    end
  end

  local out = {}
  for bar, rects in pairs(byBar) do
    local info = ns.wow.classifyBarRects(rects)
    if info then
      info.enabled = true
      out[bar] = info
    end
  end

  -- Pet bar geometry lives outside the 1-180 slot model; report it under `pet`
  -- (PetActionButtons are reused/repositioned by bar addons, so reading them by
  -- name works for Bartender/Dominos/ElvUI too).
  local petRects = {}
  for i = 1, 12 do
    local b = _G["PetActionButton" .. i]
    if b and b:IsVisible() then
      local l, r, bo, t = b:GetLeft(), b:GetRight(), b:GetBottom(), b:GetTop()
      if l and r and bo and t then
        petRects[#petRects + 1] = { left = l, right = r, bottom = bo, top = t }
      end
    end
  end
  local petInfo = ns.wow.classifyBarRects(petRects)
  if petInfo then
    petInfo.enabled = true
    out.pet = petInfo
  end

  -- Which slot-range bar is currently paging the main action bar (Bar 1's screen
  -- position) — the active stance/form/override page. Lets a consumer distinguish a
  -- real stance bar (it replaces Bar 1) from a dedicated bar that merely uses
  -- class-page slots, programmatically and class-agnostically.
  local mainBtn = _G.ActionButton1
  local mainSlot = mainBtn and actionSlot(mainBtn)
  if mainSlot then out.mainPage = floor((mainSlot - 1) / 12) + 1 end

  return out
end

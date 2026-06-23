---@class Warbandeer
---@field RingKeyDown fun(self: Warbandeer)
---@field RingKeyUp fun(self: Warbandeer)
local ns = select(2, ...)
local ui = ns.ui

-- Hold-to-open radial view selector, paired with the WARBANDEER_TOGGLE keybinding
-- (keybind.lua / Bindings.xml). A quick **tap** toggles the window; **holding** the
-- key past HOLD_THRESHOLD pops a LibNUI RingSelector under the cursor laid out from
-- ns.viewOrder, and releasing switches to the aimed view. Pure insecure UI.

local ICON_PATH = "Interface\\AddOns\\Warbandeer\\icons\\views\\"
local HOLD_THRESHOLD = 0.2 -- seconds held before the ring appears

local ring          -- lazily-created RingSelector
local ringShown     -- whether the ring is currently up
local holdTimer     -- pending "show the ring" timer while the key is held

-- Ordered ring slices from ns.viewOrder, reusing each view class's glyph + title +
-- rotation (the same metadata the IconStrip rail reads) — no icon data duplicated.
local function ringItems()
  local byName = {}
  for _, c in pairs(ns.views) do byName[c.name] = c end
  local items = {}
  for _, name in ipairs(ns.viewOrder) do
    local c = byName[name]
    if c then
      items[#items + 1] = {
        name = name,
        path = ICON_PATH .. name .. ".tga",
        rotation = c._iconRotation,
        title = c._title or name,
      }
    end
  end
  return items
end

local function ensureRing()
  if ring then return ring end
  local theme = ns.theme.colors
  ring = ui.RingSelector:new{
    parent = UIParent,
    strata = "FULLSCREEN_DIALOG",
    items = ringItems(),
    restColor = theme.muted,
    hiColor = theme.gold,
    onSelect = function(name) ns:view(name) end,
  }
  ring:Hide()
  return ring
end

-- Key down: arm the timer that pops the ring if the key is still held.
function ns:RingKeyDown()
  if holdTimer then holdTimer:Cancel() end
  holdTimer = C_Timer.NewTimer(HOLD_THRESHOLD, function()
    holdTimer = nil
    ensureRing():CenterOnCursor()
    ring:Show()
    ring:Raise()
    ringShown = true
  end)
end

-- Key up: a hold commits the aimed view (or cancels if aimed at nothing); a tap
-- (timer never fired) toggles the window like /wb.
function ns:RingKeyUp()
  if holdTimer then holdTimer:Cancel(); holdTimer = nil end
  if ringShown then
    ring:Commit() -- onSelect → ns:view(aimed); no-op in the dead zone
    ring:Hide()
    ringShown = false
  else
    self:Toggle()
  end
end

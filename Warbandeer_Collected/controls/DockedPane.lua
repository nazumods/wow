---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Frame, Label, Texture = ui.Frame, ui.Label, ui.Texture
local DressingRoom = ns.DressingRoom
local k = DressingRoom._k
local IDLE, PAD = k.IDLE, k.PAD

-- The **shell** shared by the dressing room's two docked panes (#770 step 16): the look-builder
-- picker (controls/AppearancePicker.lua) and the weapon-cell chooser (controls/WeaponCellPicker.lua).
-- They dock to the same edge, are mutually exclusive by construction — opening either closes the
-- other — and were building the same panel twice: same fill, same 1px outline, same title line, and
-- the same "refresh once shortly so async item names fill in" timer.
--
-- **The shell only.** Both callers keep their own furniture and their own lists, which is where they
-- genuinely differ: the picker carries mode tabs and a category dropdown, the chooser carries hand
-- buttons and a tier row. The plan's hard stop applies — this is deliberately NOT a step toward one
-- pane serving both, which would need a third `TARGETS` kind and `VirtualList.rowTypes`.
--
-- Reopens the DressingRoom class.

---@class Warbandeer_Collected
---@field paneFill number[]  opaque docked-pane fill
---@field collectedTint number[]  row-name tint for a collected appearance

-- A standalone frame's theme `window` token is alpha-0, so a docked pane needs an explicit opaque
-- fill or it renders transparent over the model.
ns.paneFill      = { 0.05, 0.05, 0.06, 0.96 }
ns.collectedTint = { 0.30, 0.85, 0.40 }   -- illusions have no item quality, so they use this too

local GAP      = 6     -- between the window's right edge and the pane
local NAMEFILL = 0.3   -- seconds to wait before filling in async item names

---Build a docked pane: an opaque, 1px-outlined panel down the window's right edge, hidden, with its
---title line already placed. Returns the pane and its title Label — the picker retitles per target,
---the chooser's is fixed.
---
---There is no drag handle. The picker's header used to double as one for moving the room while
---undocked, but since #708 the room is always docked before either pane can be built, so that branch
---was unreachable and went in #787. The host's titlebar moves the cluster.
---@param width number
---@param title string
---@return table pane
---@return table titleLabel
function DressingRoom:_buildDockedPane(width, title)
  local pane = Frame:new{
    parent = self, background = ns.paneFill,
    position = {
      TopLeft    = {self, ui.edge.TopRight, GAP, 0},
      BottomLeft = {self, ui.edge.BottomRight, GAP, 0},
      Width = width, Hide = true,
    },
  }
  Texture:new{ parent = pane, layer = ui.layer.Border, color = IDLE,
    position = { TopLeft = {-1, 1}, BottomRight = {1, -1} } }
  local titleLabel = Label:new{ parent = pane, fontObj = "GameFontNormal",
    position = { TopLeft = {PAD, -PAD} }, text = title }
  return pane, titleLabel
end

---Refresh a docked pane's list once shortly, so item names that were still loading fill in.
---
---A **debounce**, not a retry, though it rides on retry.lua's bookkeeping: the budget is deliberately
---`1` and reset on every call, so re-opening a pane replaces the pending refresh instead of stacking
---a second one. Going through the shared helper keeps every cancelable timer in the addon owned by
---one file, and drops the two `_*NameTimer` fields this replaced.
---@param key string  distinguishes the two panes' pending refreshes
---@param pane table
---@param list table
function DressingRoom:_fillNamesShortly(key, pane, list)
  ns.ResetRetry(self, key)
  ns.Retry(self, key, { tries = 1, delay = NAMEFILL, again = function()
    if pane._widget:IsShown() then list:Refresh() end
  end })
end

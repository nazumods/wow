---@type Warbandeer_Collected
local ns = select(2, ...)
local ui = ns.ui
local Class = ns.lua.Class
local CleanFrame, Label, TableFrame = ui.CleanFrame, ui.Label, ui.TableFrame
local C_Timer = C_Timer

-- The singleton hover panel behind BOTH collection grids (#856). One frame, one chrome, two bodies:
-- the armour grid's fixed nine-slot table (controls/InfoTipArmor.lua) and the weapon grid's flat,
-- variable-length appearance list (controls/InfoTipWeapon.lua). This file owns everything the two
-- share — the frame, the name/status chrome, the layout + sizing pass, the anchoring, and the
-- async-name retry — and knows nothing about either body beyond the renderer it dispatches to.
--
-- What made the split necessary rather than pointing the weapon path at the existing tip: an armour
-- cell is ONE set with a slot axis, so nine rows are the whole shape; a weapon cell is a
-- (source x weapon type) bucket of N appearances with no slot axis at all. The body had to become
-- the caller's business.

-- The tip, and a descriptor of what it currently shows. `kind` picks the body renderer; the rest is
-- whatever that renderer needs, plus the parent/position to re-anchor with. Held as one table so the
-- three things that re-enter render — the first paint, the async name-load retry (which has to know
-- it is still describing the same cell) and RefreshInfoTip — all read the same state.
---@class InfoTipDesc
---@field kind string  "armor" | "weapon" — selects the body renderer in ns.InfoTipBodies
---@field parent Frame  the hovered cell, for the level bump
---@field position table  LibNUI position spec to anchor by
local _tooltip, _desc

---Body renderers, registered by the two body files. Each fills the panel's own widgets for its kind
---and returns the body widget to show, that body's preferred width, and whether anything it drew is
---still streaming in (which schedules a re-render).
---@class Warbandeer_Collected
---@field InfoTipBodies table<string, fun(tip: InfoTip, desc: InfoTipDesc): Frame, number, boolean?>
ns.InfoTipBodies = {}

---Singleton tooltip panel: a name header, a wanted/rank status line, and one of two swappable bodies.
---@class InfoTip: CleanFrame
---@field name Label set/source name header
---@field status Label wanted/rank line (inline-colored), rewritten per render by the body
---@field items TableFrame armour body — one row per armor slot (head..hands)
---@field list TableFrame weapon body — flat appearance list, grown per render (see the dynamic-table idiom below)
---@field obtain Label wrapped "How to obtain" block; only the weapon body's arsenal rows show it
local InfoTip = Class(CleanFrame, function(self)
  self.name = Label:new{
    parent = self,
    position = {
      TopLeft = {2, -2},
    },
    text = "Name",
  }

  -- Wanted/rank line just under the name. Seeded with the armour hint purely so it has a height to
  -- measure here; every render rewrites it (and for a weapon cell that hint must never appear — see
  -- InfoTipWeapon.lua and #857).
  self.status = Label:new{
    parent = self,
    fontObj = "GameFontNormalSmall",
    position = {
      TopLeft = {self.name, ui.edge.BottomLeft, 0, -2},
    },
    text = "Shift-click to mark wanted",
  }

  self.items = TableFrame:new{
    parent = self,
    position = {
      TopLeft = {self.status, ui.edge.BottomLeft, 0, -2},
    },
    headerHeight = 0,
    headerWidth = 60,
    rowInfo = {
      { name = "Head", backdrop = {color = ns.Colors.TransparentBlack} },
      { name = "Shoulder", backdrop = {color = ns.Colors.TransparentBlack} },
      { name = "Back", backdrop = {color = ns.Colors.TransparentBlack} },
      { name = "Chest", backdrop = {color = ns.Colors.TransparentBlack} },
      { name = "Waist", backdrop = {color = ns.Colors.TransparentBlack} },
      { name = "Legs", backdrop = {color = ns.Colors.TransparentBlack} },
      { name = "Feet", backdrop = {color = ns.Colors.TransparentBlack} },
      { name = "Wrist", backdrop = {color = ns.Colors.TransparentBlack} },
      { name = "Hands", backdrop = {color = ns.Colors.TransparentBlack} },
    },
    colInfo = {
      { backdrop = {color = ns.Colors.TransparentBlack} }
    },
    data = {{""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}},
  }

  -- The weapon body's flat list: no slot axis, so no row headers and a row count that changes with
  -- every cell. `rowNames`/`colNames` are the documented dynamic-table idiom (LibNUI CONTEXT gotcha) —
  -- passing them empty is what keeps offsetX/offsetY right for a table grown by `update`/`addRow`
  -- instead of one declared up front. `headerWidth = 0` because there is no row-name gutter to leave.
  self.list = TableFrame:new{
    parent = self,
    position = {
      TopLeft = {self.status, ui.edge.BottomLeft, 0, -2},
    },
    rowNames = {},
    colNames = {},
    headerHeight = 0,
    headerWidth = 0,
    colInfo = {
      { backdrop = {color = ns.Colors.TransparentBlack} }
    },
    data = {},
  }
  self.list:Hide()

  -- Curated "where from" prose, so it wraps rather than truncating. Width is set per render (a
  -- FontString only wraps against a width it has been given); hidden unless the body asks for it.
  self.obtain = Label:new{
    parent = self,
    fontObj = "GameFontNormalSmall",
    position = {
      TopLeft = {self.items, ui.edge.BottomLeft, 0, -4},
    },
    text = "",
  }
  self.obtain:Hide()

  -- Sized per render by ns.LayoutInfoTip: both bodies vary (the weapon list by row count, the armour
  -- table by its widest item name), so there is no constructor-time height to bake in.
  self:Height(80)
  self:Width(self.items:Width() + 4)
end, {
  -- defaults for inherited settings
  parent = UIParent,
  strata = "DIALOG",
  background = {0, 0, 0, 0.7},
  inset = 3,
  position = {
    TopLeft = {20, -20},
  },
})
---@class Warbandeer_Collected
---@field InfoTip InfoTip
ns.InfoTip = InfoTip

---Position the chosen body under the status line, hide the other, and size the frame around them.
---
---Both bodies anchor to the same point, so the only thing that distinguishes them at layout time is
---which one is shown — hiding the loser is what stops a stale armour table sitting behind a weapon
---list (the panel is a singleton shared by two grids, so this is the failure mode to design out).
---@param tip InfoTip
---@param body Frame  the body widget to show (tip.items or tip.list)
---@param bodyW number  the body's preferred width
---@param obtain string?  wrapped prose to show beneath the body, or nil for none
function ns.LayoutInfoTip(tip, body, bodyW, obtain)
  for _, w in ipairs({tip.items, tip.list}) do w:SetShown(w == body) end

  local w = 4 + math.max(tip.name:Width(), tip.status:Width(), bodyW)
  local h = 4 + tip.name:Height() + tip.status:Height() + 2 + body:Height() + 2

  -- The obtain block hangs off whichever body is showing, so re-anchor it rather than leaving it
  -- pointed at the armour table (Position ADDS anchors — see the LibNUI gotcha — hence the clear).
  if obtain then
    tip.obtain:ClearAllPoints()
    tip.obtain:Position({ TopLeft = {body, ui.edge.BottomLeft, 0, -4} })
    tip.obtain:Width(w - 8)
    tip.obtain:Text(obtain)
    tip.obtain:Show()
    h = h + 4 + tip.obtain:Height()
  else
    tip.obtain:Hide()
  end

  tip:Width(w)
  tip:Height(h)
end

-- Item names from the transmog APIs load asynchronously, so the first hover can render before
-- they're cached (blank armour rows, an "Appearance 12345" weapon line). We request the items to
-- load and re-render until the names resolve, capped so a genuinely nameless source can't loop
-- forever.
local _retryTimer, _retries
local function cancelRetry()
  if _retryTimer then _retryTimer:Cancel(); _retryTimer = nil end
end

-- Build + position + show the tip for one descriptor. `_desc` is committed here so the async
-- name-load retry can tell whether it's still rendering the same cell.
local function render(desc)
  if not _tooltip then
    _tooltip = InfoTip:new{
      position = false,
    }
  end
  _desc = desc

  local body, bodyW, incomplete, obtain = ns.InfoTipBodies[desc.kind](_tooltip, desc)
  ns.LayoutInfoTip(_tooltip, body, bodyW, obtain)

  -- Clear the previous hover's anchor before re-pointing: the tip is a reused singleton, and
  -- InfoTipPosition flips between a TopLeft/TopRight cell anchor by screen side, so stacking points
  -- would anchor it to two cells at once (retail rejects that as an "anchor family connection").
  _tooltip:ClearAllPoints()
  _tooltip:Position(desc.position)
  _tooltip:Show()
  _tooltip:Level(desc.parent:Level() + 1)

  -- Re-render shortly if any name is still loading, as long as the tip is still showing this cell
  -- and we haven't exhausted our attempts.
  cancelRetry()
  if incomplete and _retries > 0 then
    _retries = _retries - 1
    _retryTimer = C_Timer.NewTimer(0.15, function()
      _retryTimer = nil
      if _desc == desc and _tooltip and _tooltip._widget:IsVisible() then
        render(desc)
      end
    end)
  end
end

---Show the shared panel for a descriptor built by one of the body files.
---@class Warbandeer_Collected
---@field ShowInfoTipFor fun(desc: InfoTipDesc)
ns.ShowInfoTipFor = function(desc)
  cancelRetry()
  _retries = 12   -- ~1.8s of re-renders while item names load in
  render(desc)
end

---Hide the shared InfoTip (no-op if never shown).
---@class Warbandeer_Collected
---@field HideInfoTip fun()
ns.HideInfoTip = function()
  cancelRetry()
  _desc = nil
  if _tooltip then _tooltip:Hide() end
  GameTooltip:Hide()   -- the tip can sit alongside a native item tooltip; clear both
end

---Re-render the currently shown tip in place, so a wanted/rank change made while hovering (e.g.
---shift-click on an armour cell) updates the status line immediately. No-op if hidden.
---@class Warbandeer_Collected
---@field RefreshInfoTip fun()
ns.RefreshInfoTip = function()
  if _tooltip and _tooltip._widget:IsVisible() and _desc then
    render(_desc)
  end
end

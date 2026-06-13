---@type Warbandeer_Collected
local ns = select(2, ...)
local ui = ns.ui
-- luacheck: globals C_Timer MouseIsOver C_TransmogCollection
local Class, find, any = ns.lua.Class, ns.lua.lists.find, ns.lua.maps.any
local CleanFrame, Label, TableFrame = ui.CleanFrame, ui.Label, ui.TableFrame
local Frame, Button, Texture = ui.Frame, ui.Button, ui.Texture
local C_Timer, MouseIsOver = C_Timer, MouseIsOver
local getParts = C_TransmogSets.GetSetPrimaryAppearances

-- The singleton tip and the set it currently describes (the Preview button reads
-- these to open the dressing room). Declared up here so the constructor's button
-- closure captures them.
local _tooltip, _group, _set

---Singleton tooltip listing a transmog set's pieces per armor slot, colored by collected status.
---@class InfoTip: CleanFrame
---@field name Label set name header
---@field items TableFrame one row per armor slot (head..hands)
local InfoTip = Class(CleanFrame, function(self)
  local h = 4

  self.name = Label:new{
    parent = self,
    position = {
      TopLeft = {2, -2},
    },
    text = "Name",
  }
  h = h + self.name:Height()

  -- Natural height only (no bottom anchor): the Preview button lives below it and
  -- must stay inside the frame, else the hover-persist check (MouseIsOver self)
  -- fails over the button and the tip hides before it can be clicked.
  self.items = TableFrame:new{
    parent = self,
    position = {
      TopLeft = {self.name, ui.edge.BottomLeft, 0, -2},
    },
    headerHeight = 0,
    headerWidth = 60,
    rowInfo = {
      { name = "Head", backdrop = {color = ns.Colors.TransparentBlack} },
      { name = "Shoulder", backdrop = {color = ns.Colors.TransparentBlack} },
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
    data = {{""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}},
  }
  h = h + self.items:Height() + 2

  -- Preview button: opens the shared dressing room for the current set. The tip is
  -- mouse-enabled and hover-persistent (see armHide) so this stays clickable.
  self.preview = Frame:new{
    parent = self,
    position = {
      TopLeft  = {self.items, ui.edge.BottomLeft, 0, -3},
      TopRight = {self.items, ui.edge.BottomRight, 0, -3},
      Height = 18,
    },
  }
  Texture:new{
    parent = self.preview, layer = ui.layer.Background,
    position = { All = true }, color = {0.28, 0.28, 0.32, 1},
  }
  Texture:new{
    parent = self.preview, layer = ui.layer.Border, color = {0.05, 0.05, 0.06, 1},
    position = { TopLeft = {1, -1}, BottomRight = {-1, 1} },
  }
  Label:new{
    parent = self.preview, justifyH = ui.justify.Center,
    position = { Left = {4, 0}, Right = {-4, 0} }, text = "Preview model",
  }
  Button:new{
    parent = self.preview, position = { All = true }, glow = false,
    OnClick = function() if _group and _set then ns.ShowDressingRoom(_group, _set) end end,
  }
  h = h + 3 + 18 + 2  -- button + a little bottom margin so it sits inside the frame

  self:EnableMouse(true)
  self:Height(h)
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

-- Hover-persistent hide: a cell's onLeave arms a short timer instead of hiding
-- outright, so the user can move onto the tip and click Preview. The timer keeps
-- the tip open while the cursor is still over it (or its Preview button), and a
-- re-entered cell cancels the pending hide.
local _hideTimer
local function cancelHide()
  if _hideTimer then _hideTimer:Cancel(); _hideTimer = nil end
end
local function armHide()
  cancelHide()
  _hideTimer = C_Timer.NewTimer(0.2, function()
    _hideTimer = nil
    if not _tooltip then return end
    if MouseIsOver(_tooltip._widget) then
      armHide()
    else
      _tooltip:Hide()
    end
  end)
end

-- Item names from GetSourcesForSlot load asynchronously, so the first hover can
-- render before they're cached (blank rows). We request the items to load and
-- re-render until the names resolve, capped so a genuinely nameless source can't
-- loop forever.
local _retryTimer, _retries
local function cancelRetry()
  if _retryTimer then _retryTimer:Cancel(); _retryTimer = nil end
end

-- Build + position + show the tip for one set. _group/_set are committed here (not
-- in ShowInfoTip) so a cell merely passed through — whose pending render is
-- cancelled — never becomes the set the Preview button would open.
local function render(group, set, parent, position)
  if not _tooltip then
    _tooltip = InfoTip:new{
      position = false,
    }
  end
  if not ns.db.sets[group.id] or not ns.db.sets[group.id][set.id] then
    _tooltip:Hide()
    return
  end
  _group, _set = group, set
  _tooltip.name:Text(set.name)

  local parts = getParts(set.id)
  local primary = {}
  for _,p in ipairs(parts) do primary[p.appearanceID] = true end

  local incomplete = false
  for i,slot in ipairs({1,3,5,6,7,8,9,10}) do
    local sources = C_TransmogSets.GetSourcesForSlot(set.id, slot)
    local isCollected = any(sources, function(s) return s.isCollected end)
    local _, p = find(sources, function(s) return primary[s.sourceID] end)
    if p and (not p.name or p.name == "") then
      -- Name not cached yet: nudge the item to load and flag a re-render.
      incomplete = true
      local info = C_TransmogCollection.GetSourceInfo(p.sourceID)
      if info and info.itemID then C_Item.RequestLoadItemDataByID(info.itemID) end
    end
    _tooltip.items.data[i][1] = p and {
      text = p.name,
      color = isCollected and { 0, 104/255, 55/255} or {165/255, 0, 38/255},
     } or ""
  end
  _tooltip.items:update()
  _tooltip:Position(position)
  _tooltip:Show()
  _tooltip:Level(parent:Level() + 1)

  -- find the widest one and resize the column
  local w = 0
  for _,r in ipairs(_tooltip.items.cells) do
    w = max(w, r[1].label._widget:GetUnboundedStringWidth())
  end
  _tooltip.items.cols[1]:Width(w)
  _tooltip.items:Width(4 + _tooltip.items.headerWidth + w)

  _tooltip:Width(4 + max(
    _tooltip.name:Width(),
    4 + _tooltip.items.headerWidth + w
  ))

  -- Re-render shortly if any name is still loading, as long as the tip is still
  -- showing this set and we haven't exhausted our attempts.
  cancelRetry()
  if incomplete and _retries > 0 then
    _retries = _retries - 1
    _retryTimer = C_Timer.NewTimer(0.15, function()
      _retryTimer = nil
      if _group == group and _set == set and _tooltip and _tooltip._widget:IsVisible() then
        render(group, set, parent, position)
      end
    end)
  end
end

-- Debounce repositioning so the tip doesn't chase the cursor across cells on the
-- way to the Preview button. First show is immediate; while the tip is already
-- up, a new cell only re-anchors it after a short dwell — cells passed through in
-- transit (their onLeave fires first, cancelling the pending render) are ignored.
local _showTimer
local function cancelShow()
  if _showTimer then _showTimer:Cancel(); _showTimer = nil end
end

---Show the shared InfoTip for a transmog set, positioned relative to a cell.
---@class Warbandeer_Collected
---@field ShowInfoTip fun(group: table, set: table, parent: Frame, position: table) group/set are entries from ns.Sets; position is a LibNUI position spec
ns.ShowInfoTip = function(group, set, parent, position)
  cancelHide()
  cancelShow()
  cancelRetry()
  _retries = 12   -- ~1.8s of re-renders while item names load in
  if not _tooltip or not _tooltip._widget:IsVisible() then
    render(group, set, parent, position)
  else
    _showTimer = C_Timer.NewTimer(0.06, function()
      _showTimer = nil
      render(group, set, parent, position)
    end)
  end
end

---Hide the shared InfoTip — deferred, so the cursor can travel onto the tip and
---click Preview without it vanishing (no-op if never shown).
---@class Warbandeer_Collected
---@field HideInfoTip fun()
ns.HideInfoTip = function()
  cancelShow()
  cancelRetry()
  if _tooltip then
    armHide()
  end
end

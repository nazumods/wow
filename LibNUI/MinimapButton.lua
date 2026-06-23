---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local Class = ns.lua.Class
local Frame, Texture = ui.Frame, ui.Texture
local Minimap, UIParent, GameTooltip = Minimap, UIParent, GameTooltip
local GetMinimapShape, GetCursorPosition = GetMinimapShape, GetCursorPosition
local AddonCompartmentFrame, MenuUtil = AddonCompartmentFrame, MenuUtil
local rad, deg, cos, sin, sqrt, atan2 = math.rad, math.deg, math.cos, math.sin, math.sqrt, math.atan2
local max, min = math.max, math.min

-- Per-quadrant "is this corner rounded?" flags keyed by GetMinimapShape(), so
-- the button hugs the edge of square / partial minimaps too (the table most
-- addons share, via LibDBIcon-1.0). Quadrant order matches updatePosition's
-- sign checks.
local SHAPES = {
  ["ROUND"]                 = { true,  true,  true,  true  },
  ["SQUARE"]                = { false, false, false, false },
  ["CORNER-TOPLEFT"]        = { false, false, false, true  },
  ["CORNER-TOPRIGHT"]       = { false, false, true,  false },
  ["CORNER-BOTTOMLEFT"]     = { false, true,  false, false },
  ["CORNER-BOTTOMRIGHT"]    = { true,  false, false, false },
  ["SIDE-LEFT"]             = { false, true,  false, true  },
  ["SIDE-RIGHT"]            = { true,  false, true,  false },
  ["SIDE-TOP"]              = { false, false, true,  true  },
  ["SIDE-BOTTOM"]           = { true,  true,  false, false },
  ["TRICORNER-TOPLEFT"]     = { false, true,  true,  true  },
  ["TRICORNER-TOPRIGHT"]    = { true,  false, true,  true  },
  ["TRICORNER-BOTTOMLEFT"]  = { true,  true,  false, true  },
  ["TRICORNER-BOTTOMRIGHT"] = { true,  true,  true,  false },
}

-- A draggable button on the minimap edge. The consumer supplies the icon, the
-- click behaviour, the tooltip, and a persistence table; the widget owns the
-- positioning/drag/highlight/compartment boilerplate (and its gotchas).
--
--   ui.MinimapButton:new{
--     name = "MyAddonMinimapButton",
--     icon = "Interface\\AddOns\\MyAddon\\icon.png",
--     iconFillsButton = true,         -- icon carries its own border
--     db   = MyAddonDB.minimap,       -- { angle, hide } persisted here
--     defaultAngle = 198,
--     tooltip = { "My Addon", "Left-click to open", "Drag to move" },
--     onClick = function(self, mouseButton) ... end,
--     compartment = { text = "My Addon", onClick = function() ... end },
--   }
--
-- Build it at/after PLAYER_LOGIN so any GetMinimapShape provider has loaded.
---@class MinimapButton: Frame
---@field icon string|number  icon texture path or fileID
---@field iconFillsButton boolean?  icon fills the button (its art carries the border); else a Blizzard ring+background is drawn around an inset icon
---@field db table  persistence store; the widget reads/writes { angle:number, hide:boolean }
---@field defaultAngle number  ring angle (degrees) used when db.angle is unset
---@field radius number  pixels past the minimap edge
---@field tooltip (string[]|fun(self: MinimapButton): string[])?  tooltip lines (first line is the header); or a function returning them
---@field onClick fun(self: MinimapButton, mouseButton: string)?  click handler (decides left/right behaviour)
---@field compartment table?  { text:string, icon?:string, onClick:fun() } — also register a Blizzard addon-compartment entry
---@field _icon Texture  the icon Texture widget
local MinimapButton = Class(Frame, function(self)
  local b = self._widget
  b:SetSize(31, 31)
  -- Pin strata/level so another addon (or the minimap cluster) can't restack
  -- the button underneath the minimap.
  b:SetFrameStrata("MEDIUM")
  b:SetFixedFrameStrata(true)
  b:SetFrameLevel(b:GetParent():GetFrameLevel() + 8)
  b:SetFixedFrameLevel(true)
  b:RegisterForClicks("AnyUp")
  b:RegisterForDrag("LeftButton")
  b:SetMovable(true)

  if self.iconFillsButton then
    self._icon = Texture:new{ parent = self, layer = ui.layer.Artwork, path = self.icon, position = { All = true } }
  else
    -- Standard minimap-button look: a tracking-border ring + background around
    -- an inset icon (sizes match the LibDBIcon defaults).
    Texture:new{ parent = self, layer = ui.layer.Background, path = "Interface\\Minimap\\UI-Minimap-Background",
      position = { Center = { 0, 0 }, Width = 24, Height = 24 } }
    self._icon = Texture:new{ parent = self, layer = ui.layer.Artwork, path = self.icon,
      position = { Center = { 0, 0 }, Width = 18, Height = 18 } }
    Texture:new{ parent = self, layer = ui.layer.Overlay, path = "Interface\\Minimap\\MiniMap-TrackingBorder",
      position = { TopLeft = { 0, 0 }, Width = 50, Height = 50 } }
  end

  -- Button:SetHighlightTexture defaults to ADD blend, so the glow brightens the
  -- icon on hover instead of painting over it (a plain HIGHLIGHT-layer texture
  -- defaults to BLEND and would hide the icon).
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  if self.compartment and AddonCompartmentFrame then
    self:registerCompartment()
  end

  -- lazy-init the persistence store and place/show the button
  self.db = self.db or {}
  if self.db.angle == nil then self.db.angle = self.defaultAngle end
  self:updatePosition()
  b:SetShown(not self.db.hide)
end, {
  type         = "Button",
  parent       = Minimap,
  radius       = 8,
  defaultAngle = 225,
  scripts      = { "OnClick", "OnEnter", "OnLeave", "OnDragStart", "OnDragStop" },
})
ui.MinimapButton = MinimapButton

-- Place the button on the minimap edge at the saved angle. Shape-aware: on a
-- round quadrant it sits on the circle; on a square one it clamps to the edge.
function MinimapButton:updatePosition()
  local angle = rad(self.db.angle)
  local x, y = cos(angle), sin(angle)
  local q = 1
  if x < 0 then q = q + 1 end
  if y > 0 then q = q + 2 end
  local quad = SHAPES[(GetMinimapShape and GetMinimapShape()) or "ROUND"] or SHAPES.ROUND
  local mm = self._widget:GetParent()
  local w = (mm:GetWidth() / 2) + self.radius
  local h = (mm:GetHeight() / 2) + self.radius
  if quad[q] then
    x, y = x * w, y * h
  else
    x = max(-w, min(x * (sqrt(2 * w * w) - 10), w))
    y = max(-h, min(y * (sqrt(2 * h * h) - 10), h))
  end
  self._widget:ClearAllPoints()
  self._widget:SetPoint("CENTER", mm, "CENTER", x, y)
end

function MinimapButton:OnDragStart()
  self._widget:SetScript("OnUpdate", function() self:dragUpdate() end)
end

function MinimapButton:OnDragStop()
  self._widget:SetScript("OnUpdate", nil)
end

-- Follow the cursor's angle around the minimap centre while dragging.
function MinimapButton:dragUpdate()
  local mm = self._widget:GetParent()
  local mx, my = mm:GetCenter()
  local scale = mm:GetEffectiveScale()
  local px, py = GetCursorPosition()
  self.db.angle = deg(atan2(py / scale - my, px / scale - mx)) % 360
  self:updatePosition()
end

-- The `scripts` bridge calls this as OnClick(self, frame, button, down), so the
-- mouse button is the second positional arg, not the first.
---@param mouseButton string  "LeftButton" / "RightButton" / ...
function MinimapButton:OnClick(_, mouseButton)
  if self.onClick then self:onClick(mouseButton) end
end

-- Anchor on whichever side keeps the tooltip on-screen.
---@return string
function MinimapButton:tooltipAnchor()
  local cx = self._widget:GetCenter()
  if cx and cx > UIParent:GetWidth() / 2 then return "ANCHOR_LEFT" end
  return "ANCHOR_RIGHT"
end

-- Populate GameTooltip from the `tooltip` option (lines or a function); the
-- first line is the white header, the rest are muted.
---@param owner table  the frame to own/anchor the tooltip
---@param anchor string  an ANCHOR_* point
function MinimapButton:showTooltip(owner, anchor)
  local lines = self.tooltip
  if type(lines) == "function" then lines = lines(self) end
  if not lines then return end
  GameTooltip:SetOwner(owner, anchor)
  for i, line in ipairs(lines) do
    if i == 1 then GameTooltip:AddLine(line) else GameTooltip:AddLine(line, 0.8, 0.8, 0.8) end
  end
  GameTooltip:Show()
end

function MinimapButton:OnEnter()
  self:showTooltip(self._widget, self:tooltipAnchor())
end

function MinimapButton:OnLeave()
  GameTooltip:Hide()
end

-- Register a Blizzard addon-compartment entry (top-of-minimap menu) — a stable
-- access point even when the button itself is hidden.
function MinimapButton:registerCompartment()
  local c = self.compartment
  AddonCompartmentFrame:RegisterAddon({
    text         = c.text,
    icon         = c.icon or self.icon,
    notCheckable = true,
    func         = function() c.onClick() end,
    funcOnEnter  = function(frame) self:showTooltip(frame, "ANCHOR_LEFT") end,
    funcOnLeave  = function() GameTooltip:Hide() end,
  })
end

-- Show a Blizzard context menu anchored to the button, so the consumer never
-- has to reach for the backing frame. `generator` is the
-- MenuUtil.CreateContextMenu callback: `function(owner, rootDescription) ... end`.
---@param generator fun(owner: table, rootDescription: table)
function MinimapButton:ShowContextMenu(generator)
  MenuUtil.CreateContextMenu(self._widget, generator)
end

-- Show/hide the button and persist the choice into `db.hide`.
---@param shown boolean?
---@return boolean|MinimapButton
function MinimapButton:Shown(shown)
  if shown == nil then return not self.db.hide end
  self.db.hide = not shown
  self._widget:SetShown(shown)
  if shown then self:updatePosition() end
  return self
end

-- Getter/setter for the ring angle in degrees (normalized 0–360).
---@param degrees number?
---@return number|MinimapButton
function MinimapButton:Angle(degrees)
  if degrees == nil then return self.db.angle end
  self.db.angle = degrees % 360
  self:updatePosition()
  return self
end

-- Getter/setter for the icon texture.
---@param path string|number?
---@return string|number|MinimapButton
function MinimapButton:Icon(path)
  if path == nil then return self.icon end
  self.icon = path
  self._icon:Texture(path)
  return self
end

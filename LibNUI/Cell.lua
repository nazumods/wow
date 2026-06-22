---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local Class, Frame = ns.lua.Class, ui.Frame
local Label, Texture = ui.Label, ui.Texture

---@class Cell: Frame
---@field data table|string  cell data: an options table (text/path/atlas/...) or a plain text string
---@field texture Texture?  icon content, created on first texture-bearing data
---@field label Label?  text content, created on first text-bearing data
-- A cell is normally an icon (path/atlas) OR a label (text). It may also carry
-- BOTH: when data has an icon AND `text`, the icon is pinned by `iconPosition`
-- (e.g. left edge) and a filling label is added so the caller can justify the
-- text independently (e.g. a left status icon beside a right-aligned number).
local Cell = Class(Frame, function(self)
  -- cells are parented to the view, same as the rows and cols,
  -- so raise it above them
  self._widget:Raise()
  local data = type(self.data) == "table" and self.data or {text = self.data}
  if data.onClick then self:SetScript("OnMouseUp", function() data.onClick(self) end) end
  if data.onEnter then self:SetScript("OnEnter", function() data.onEnter(self) end) end
  if data.onLeave then self:SetScript("OnLeave", function() data.onLeave(self) end) end
  if data.path or data.atlas then
    self:Texture(data.text ~= nil and data.iconPosition or nil)
    if data.text ~= nil then self:Label() end
  else
    self:Label()
  end
end)
ui.Cell = Cell

-- Build (or refresh) the cell's texture content from `self.data`. `pos` overrides
-- the icon position (used by the icon+text combo to pin the icon rather than fill
-- the cell); nil falls back to `data.position`, then a full-cell anchor.
---@param pos table?
function Cell:Texture(pos)
  local data = self.data
  pos = pos or data.position
  if self.texture then
    if data.path then
      self.texture:Texture(data.path)
      if data.coords then self.texture:Coords(unpack(data.coords)) end
      if data.vertexColor then self.texture:SetVertexColor(unpack(data.vertexColor)) end
    end
    if data.atlas then
      if data.atlasSize == nil then
        self.texture:Atlas(data.atlas)
      else
        self.texture:Atlas(data.atlas, data.atlasSize)
      end
    end
    if pos then self.texture:Position(pos) end
  else
    self.texture = Texture:new{
      parent = self,
      atlas = data.atlas,
      atlasSize = data.atlasSize,
      path = data.path,
      coords = data.coords,
      vertexColor = data.vertexColor,
      layer = ns.ui.layer.Artwork,
      position = pos or { All = true },
    }
  end
end

-- Build (or refresh) the cell's label content from `self.data`.
function Cell:Label()
  local data = type(self.data) == "table" and self.data or {text = self.data}
  if self.label then
    -- Coerce nil → "" so a reused cell that now has no text is cleared. Label:Text
    -- treats a falsy arg as a getter, so passing data.text directly would leave the
    -- previous occupant's text in place when cells are recycled across re-sorts.
    ---@cast data table
    self.label:Text(data.text or "")
    if data.color then self.label:Color(data.color) end
    -- re-apply font: cells are reused across re-sorts, so a cell that previously
    -- held a value in this column's font must pick it up again (an empty "" cell
    -- carries no fontInfo, so leave the prior font untouched in that case)
    if data.fontInfo then self.label:Font(data.fontInfo) end
    -- re-apply justify: cells are reused across re-sorts, so a cell that
    -- previously held left-aligned data must reset when new data is right-aligned
    self.label:JustifyH(data.justifyH or ui.justify.Left)
  else
    self.label = Label:new{
      parent = self,
      text = data.text,
      color = data.color,
      font = data.font,
      fontInfo = data.fontInfo,
      position = { All = true },
      justifyH = data.justifyH or ui.justify.Left,
    }
  end
end

---@param data table|string  new cell data (same shape as the constructor `data` option)
function Cell:update(data)
  self.data = data
  local tbl = type(data) == "table"
  local hasIcon = tbl and (data.path or data.atlas)
  local hasText = (not tbl) or data.text ~= nil
  -- cells recycle across re-sorts, so show/hide each part for the new data's mode
  -- (icon-only, text-only, or both)
  if hasIcon then
    if self.texture then self.texture:Show() end
    self:Texture(tbl and data.text ~= nil and data.iconPosition or nil)
  elseif self.texture then
    self.texture:Hide()
  end
  if hasText then
    if self.label then self.label:Show() end
    self:Label()
  elseif self.label then
    self.label:Hide()
  end
  if type(data) == "table" then
    if data.onClick then self:SetScript("OnMouseUp", function() data.onClick(self) end) else self:RemoveScript("OnMouseUp") end
    if data.onEnter then self:SetScript("OnEnter", function() data.onEnter(self) end) else self:RemoveScript("OnEnter") end
    if data.onLeave then self:SetScript("OnLeave", function() data.onLeave(self) end) else self:RemoveScript("OnLeave") end
  else
    self:RemoveScript("OnMouseUp")
    self:RemoveScript("OnEnter")
    self:RemoveScript("OnLeave")
  end
end

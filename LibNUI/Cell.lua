---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local Class, Frame, unpack = ns.lua.Class, ui.Frame, unpack
local Label, Texture = ui.Label, ui.Texture

-- Position-table keys whose first arg is an anchor target. Only these get symbolic
-- target resolution ("cell" / a part index) in composite cells; scalar keys (Size,
-- Width, All, ...) pass through untouched.
local ANCHORS = {
  Top = true, Center = true, TopLeft = true, TopRight = true, Bottom = true,
  BottomLeft = true, BottomRight = true, Left = true, Right = true,
}

---@class Cell: Frame
---@field data table|string  cell data: an options table (text/path/atlas/parts/...) or a plain text string
---@field texture Texture?  icon content, created on first texture-bearing data
---@field label Label?  text content, created on first text-bearing data
---@field parts table[]?  composite children: `{kind = "texture"|"label", widget = Texture|Label}[]`
---@field border BorderBox?  optional outline around a composite sub-region
local Cell = Class(Frame, function(self)
  -- cells are parented to the view, same as the rows and cols,
  -- so raise it above them
  self._widget:Raise()
  local data = type(self.data) == "table" and self.data or {text = self.data}
  if data.onClick then self:SetScript("OnMouseUp", function() data.onClick(self) end) end
  if data.onEnter then self:SetScript("OnEnter", function() data.onEnter(self) end) end
  if data.onLeave then self:SetScript("OnLeave", function() data.onLeave(self) end) end
  if data.parts then
    self:Composite()
  elseif data.path or data.atlas then
    self:Texture()
  else
    self:Label()
  end
end)
ui.Cell = Cell

-- Copy a part/border position table, resolving symbolic anchor targets: the string
-- "cell" → this cell, an integer N → part N's widget (a part may only anchor to an
-- earlier part). Only anchor keys (see ANCHORS) are resolved, so scalar keys like Size
-- pass through. Returns a fresh table — never mutates the caller's (possibly shared) data.
---@param pos table?
---@return table
function Cell:_resolvePosition(pos)
  if not pos then return {} end
  local out = {}
  for k, v in pairs(pos) do
    local target = ANCHORS[k] and type(v) == "table" and v[1]
    -- A part index must be followed by an EDGE string ({1, "RIGHT", 3, 0}); the bare {x, y}
    -- offset shorthand (Region:SetPoint's 3-arg form) carries a number or nothing at v[2].
    -- Without that discriminator a documented `Center = {0, -2}` resolved as "part 0" and
    -- placed silently wrong instead of erroring. A "cell" target is a string, so unambiguous.
    local symbolic = target == "cell" or (type(target) == "number" and type(v[2]) == "string")
    if symbolic then
      local copy = { target == "cell" and self or self.parts[target].widget }
      for i = 2, #v do copy[i] = v[i] end
      out[k] = copy
    else
      out[k] = v
    end
  end
  return out
end

-- Create a fresh part widget of the given kind from a part spec. The spec is the caller's
-- (possibly shared) table, so its fields are copied into a new options table rather than
-- passed through — Class:new aliases its options into the instance.
---@param kind string  "texture" | "label"
---@param spec table
---@return Texture|Label
function Cell:_buildPart(kind, spec)
  local pos = self:_resolvePosition(spec.position)
  if kind == "texture" then
    return Texture:new{
      parent = self, position = pos, layer = spec.layer or ui.layer.Artwork,
      atlas = spec.atlas, atlasSize = spec.atlasSize, path = spec.path,
      coords = spec.coords, vertexColor = spec.vertexColor, color = spec.color,
      rotation = spec.rotation, blendMode = spec.blendMode,
    }
  end
  -- Defaults are spelled out rather than left to Label's own, so a freshly built part and a
  -- recycled one (see _applyPart) resolve an omitted field to the *same* value. They disagreed
  -- before, so a composite label could render differently depending only on whether its cell
  -- happened to be new or reused.
  return Label:new{
    parent = self, position = pos, layer = spec.layer or ui.layer.Artwork,
    text = spec.text, color = spec.color or "text", font = spec.font, fontInfo = spec.fontInfo,
    justifyH = spec.justifyH or ui.justify.Left,
    justifyV = spec.justifyV or ui.justify.Middle,
    wordWrap = spec.wordWrap ~= false,
  }
end

-- Re-apply a part spec to an existing widget (recycled across re-sorts): reposition, then
-- refresh its content in place.
--
-- Fields are applied UNCONDITIONALLY, each omitted one falling back to its neutral value. The
-- conditional form this replaced meant "an omitted field keeps the previous occupant's value",
-- which is precisely the recycling bug the whole reuse path has to defend against — the same
-- rule CONTEXT states for plain cells. Sort a table whose composite column renders a rotated
-- arrow and the recycled cell used to keep the previous row's rotation until a /reload.
---@param widget Texture|Label
---@param kind string  "texture" | "label"
---@param spec table
function Cell:_applyPart(widget, kind, spec)
  widget:ClearAllPoints()
  widget:Position(self:_resolvePosition(spec.position))
  if kind == "texture" then
    -- path / atlas / color stay conditional: they are mutually exclusive texture *sources* and
    -- each replaces whatever the others set, so an omitted one leaves no stale state to clear.
    -- (Defaulting `color` would be actively wrong — Texture:Color is SetColorTexture, which
    -- would replace the part's texture with a solid fill on every refresh.)
    if spec.path then widget:Texture(spec.path) end
    if spec.atlas then
      if spec.atlasSize == nil then widget:Atlas(spec.atlas) else widget:Atlas(spec.atlas, spec.atlasSize) end
    end
    if spec.color then widget:Color(spec.color) end
    -- These four are modifiers layered over that source, so each needs an explicit reset.
    widget:Rotation(spec.rotation or 0)
    widget:BlendMode(spec.blendMode or "BLEND")
    if spec.coords then widget:Coords(unpack(spec.coords)) else widget:Coords(0, 0, 1, 1) end
    widget:SetVertexColor(spec.vertexColor or {1, 1, 1, 1})
  else
    -- Coerce nil → "" so a reused part with no text is cleared (Label:Text treats a
    -- falsy arg as a getter). Defaults mirror _buildPart field for field.
    widget:Text(spec.text or "")
    widget:Color(spec.color or "text")
    -- fontInfo alone stays conditional, deliberately: an empty part carries no font and there is
    -- no "no font" to reset to, so the prior one is kept. Don't align this with the others.
    if spec.fontInfo then widget:Font(spec.fontInfo) end
    widget:JustifyH(spec.justifyH or ui.justify.Left)
    widget:JustifyV(spec.justifyV or ui.justify.Middle)
    widget:WordWrap(spec.wordWrap ~= false)
  end
end

-- Build (or refresh) the cell's composite content from `self.data.parts` (+ optional
-- `self.data.border`). Parts and the border are reconciled in place — reused when the
-- part kind matches, rebuilt otherwise, surplus hidden — so composite cells survive
-- re-sort recycling. The single-texture / single-label content is hidden.
function Cell:Composite()
  if self.texture then self.texture:Hide() end
  -- Clear the text as well as hiding it. TableFrame:Autosize measures any cell with a truthy
  -- `.label`, and a cell recycled from plain-label to composite still has one — holding the
  -- previous occupant's text. Hiding alone left Autosize measuring that ghost, which is why
  -- "Autosize skips composite cells" wasn't actually true. Emptied, it contributes 0 width, so
  -- the claim holds without TableFrame needing to know composites exist.
  if self.label then self.label:Text(""); self.label:Hide() end
  self.parts = self.parts or {}
  local specs = self.data.parts
  for i, spec in ipairs(specs) do
    local kind = (spec.path or spec.atlas) and "texture" or "label"
    local slot = self.parts[i]
    if slot and slot.kind == kind then
      self:_applyPart(slot.widget, kind, spec)
      slot.widget:Show()
    else
      if slot then slot.widget:Hide() end
      self.parts[i] = { kind = kind, widget = self:_buildPart(kind, spec) }
    end
  end
  for j = #specs + 1, #self.parts do self.parts[j].widget:Hide() end

  local b = self.data.border
  if b then
    if not self.border then
      self.border = ui.BorderBox:new{
        parent = self, thickness = b.thickness or 1, color = b.color or "border", position = {},
      }
    else
      self.border:Thickness(b.thickness or 1)
      self.border:Color(b.color or "border")
    end
    self.border:ClearAllPoints()
    self.border:Position(self:_resolvePosition(b.position))
    self.border:Show()
  elseif self.border then
    self.border:Hide()
  end
end

-- Hide all composite content (parts + border) — used when a recycled cell switches from
-- composite back to a plain texture/label.
function Cell:_hideComposite()
  if self.parts then for _, p in ipairs(self.parts) do p.widget:Hide() end end
  if self.border then self.border:Hide() end
end

-- Build (or refresh) the cell's texture content from `self.data`.
function Cell:Texture()
  local data = self.data
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
    -- Position ADDS anchors rather than replacing them, so without clearing first they
    -- accumulate across re-sorts. Falls back to the same default the constructor below applies
    -- instead of skipping, so a recycled cell can't keep the previous occupant's anchors.
    self.texture:ClearAllPoints()
    self.texture:Position(data.position or { All = true })
  else
    self.texture = Texture:new{
      parent = self,
      atlas = data.atlas,
      atlasSize = data.atlasSize,
      path = data.path,
      coords = data.coords,
      vertexColor = data.vertexColor,
      layer = ns.ui.layer.Artwork,
      position = data.position or { All = true },
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
  if type(data) == "table" and data.parts then
    self:Composite()
  elseif type(data) == "table" and (data.path or data.atlas) then
    self:_hideComposite()
    if self.label then self.label:Hide() end
    if self.texture then self.texture:Show() end
    self:Texture()
  else
    self:_hideComposite()
    if self.texture then self.texture:Hide() end
    if self.label then self.label:Show() end
    self:Label()
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

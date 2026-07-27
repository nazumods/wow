---@type Warbandeer_Decor
local ns = select(2, ...)
local ITEM_QUALITY_COLORS, HIGHLIGHT_FONT_COLOR, GameTooltip =
  ITEM_QUALITY_COLORS, HIGHLIGHT_FONT_COLOR, GameTooltip

-- Shared decor hover tooltip, rendered on the game's GameTooltip. Owner-anchored, so it
-- stays on-screen and repositions itself off the window edge (a custom frame anchored to
-- a full-width row's right edge would land off the window) and costs nothing to lay out —
-- the per-hover cost matters because scrolling drags every row under the cursor. Content
-- mirrors the Collected InfoTip: name, owned breakdown, first-acquisition bonus, source,
-- and the shift-click hint.

-- The entry/row currently described, so RefreshInfoTip can re-render in place after a
-- shift-click wanted toggle.
local _entry, _parent

local function render(entry, parent)
  _entry, _parent = entry, parent
  GameTooltip:SetOwner(parent._widget, "ANCHOR_RIGHT")

  local qc = (entry.quality and ITEM_QUALITY_COLORS[entry.quality]) or HIGHLIGHT_FONT_COLOR
  GameTooltip:SetText(entry.name, qc.r, qc.g, qc.b)

  if entry.owned then
    GameTooltip:AddLine(
      ("Owned: %d  (%d stored, %d placed)"):format(entry.total, entry.stored, entry.total - entry.stored),
      0.36, 0.80, 0.47)
  else
    GameTooltip:AddLine("Not collected", 0.6, 0.6, 0.62)
  end

  if entry.bonusAvailable and entry.bonus > 0 then
    GameTooltip:AddLine(("First-acquisition bonus: +%d House XP"):format(entry.bonus), 0.40, 0.80, 1.0)
  end

  if entry.sourceText and entry.sourceText ~= "" then
    GameTooltip:AddLine(entry.sourceText, 0.7, 0.7, 0.7, true)   -- wrap
  end

  if ns:IsWanted(entry.recordID) then
    GameTooltip:AddLine("|A:" .. ns.WantedIcon .. ":14:14|a Wanted - Shift-click to unmark", 1.0, 0.82, 0.0)
  else
    GameTooltip:AddLine("Shift-click to mark wanted", 0.5, 0.5, 0.5)
  end

  GameTooltip:Show()
end

---Show the shared decor tooltip anchored to a hovered row.
---@class Warbandeer_Decor
---@field ShowInfoTip fun(entry: HousingDecorEntry, parent: Frame)
ns.ShowInfoTip = function(entry, parent)
  render(entry, parent)
end

---Hide the shared tooltip (no-op if not shown).
---@class Warbandeer_Decor
---@field HideInfoTip fun()
ns.HideInfoTip = function()
  GameTooltip:Hide()
end

---Re-render the tooltip in place if it's still showing the same row, so a wanted change
---made while hovering (shift-click) updates the wanted line immediately.
---@class Warbandeer_Decor
---@field RefreshInfoTip fun()
ns.RefreshInfoTip = function()
  if _entry and _parent and GameTooltip:IsOwned(_parent._widget) then
    render(_entry, _parent)
  end
end

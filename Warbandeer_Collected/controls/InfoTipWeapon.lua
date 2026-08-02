---@type Warbandeer_Collected
local ns = select(2, ...)

-- The weapon grid's body for the shared hover panel (controls/InfoTip.lua): the cell's individual
-- appearances, each with a collected mark, under the same wanted/rank status line the armour body
-- draws. Replaces the raw GameTooltip the weapon cells used to open (#856) — same window, same
-- gesture, one visual language.
--
-- The body is a FLAT list rather than the armour body's nine-slot table because a weapon cell has no
-- slot axis: it is a (source x weapon type) bucket holding N appearances (one raid drops four
-- daggers). Content derivation is `weapontip.lua`, which is pure and spec-covered; this file only
-- renders it.

-- The "… and N more" tail: muted, and deliberately mark-free — it stands for appearances whose
-- collected state isn't shown, so a check or an X there would be a claim about looks the panel is
-- not listing.
local MUTED = {0.6, 0.6, 0.62, 1}
-- A PTR-preview row has no collected state to colour by, but it still needs a colour of its OWN:
-- `Cell:Label` only applies `data.color` when there is one, so a row left uncoloured keeps whatever
-- the last hover put in that recycled cell — which would paint upcoming looks in the previous cell's
-- collected greens and reds. Plain white, as the GameTooltip these rows replaced used.
local PLAIN = {1, 1, 1, 1}

---Fill the panel's flat list for one weapon cell. Registered as the "weapon" body renderer.
---@param tip InfoTip
---@param desc InfoTipDesc  carries `grp`, `t` (weapon type), `visuals` and the PTR-preview flag
---@return Frame body, number bodyW, boolean incomplete, string? obtain
ns.InfoTipBodies.weapon = function(tip, desc)
  local grp, t, visuals, ptr = desc.grp, desc.t, desc.visuals, desc.ptr
  -- PTR preview drops the collected map wholesale, exactly as `ns.WeaponRows` and
  -- `ns.WeaponSourceInfo` do: an upcoming appearance isn't obtainable yet, so there is no
  -- collected/remaining state to shade, mark or count — on either client.
  local cmap = (not ptr) and ns:WeaponCollectedMap() or nil
  tip.name:Text(("%s — %s"):format(grp.name, ns.WeaponTypeName[t] or "?"))

  -- Status line composed in the pure weapontip.lua (ns.WeaponTipStatusLine), NOT here — so #857's
  -- rule that a weapon cell carries no "Shift-click to mark wanted" hint (unlike the armour grid, and
  -- permanently: writing a flag back through a bucket summary has no unambiguous answer) is guarded
  -- by a spec reading the composed text. The collected/upcoming count fills that slot instead.
  tip.status:Text(ns.WeaponTipStatusLine(ns.WeaponTipStatus(visuals, cmap), ptr))

  local lines, overflow = ns.WeaponTipLines(visuals, cmap)
  local incomplete = false
  local data = {}
  for i, line in ipairs(lines) do
    if line.pending then
      -- Name still streaming: nudge the item to load and flag a re-render.
      incomplete = true
      C_Item.RequestLoadItemDataByID(line.pending)
    end
    local text, color = line.text, PLAIN
    if line.collected ~= nil then
      -- Atlas check/redx (the grid's own icons) render reliably in this font, unlike a raw
      -- ✓/✗ glyph (which shows as a missing-glyph box). Colour matches the armour body's slot rows,
      -- which is the whole point of the shared panel.
      text = ("|A:%s:12:12|a "):format(line.collected and ns.icons.CheckGreen or ns.icons.RedX) .. text
      color = line.collected and ns.slotOK or ns.slotMissing
    end
    data[i] = {{ text = text, color = color }}
  end
  if overflow > 0 then
    data[#data + 1] = {{ text = ("… and %d more"):format(overflow), color = MUTED }}
  end
  tip.list.data = data
  tip.list:update()
  -- Grown by `update` (which appends a row per data entry) but never shrunk by it, so a smaller cell
  -- after a larger one has to hide the surplus — otherwise the previous hover's tail rows stay on
  -- screen under the new one's.
  tip.list:ResizeRows(#data)

  local w = 0
  for i = 1, #data do
    local cell = tip.list.cells[i] and tip.list.cells[i][1]
    if cell and cell.label then w = max(w, cell.label:UnboundedWidth()) end
  end
  tip.list.cols[1]:Width(w)
  tip.list:Width(4 + w)

  -- A curated "where from" block, carried only by the arsenal rows (data/arsenals.lua). The
  -- generated rows are named for their source already — "Black Temple" says where it drops — but an
  -- arsenal is named for the bundle, so without this the move out of the armour grid would lose the
  -- one thing that row was telling you (#653). Its gold heading rides in the same string rather than
  -- as a second widget — the panel's obtain block is one wrapping Label, and a FontString honours the
  -- newline and the inline colour alike.
  return tip.list, 4 + w, incomplete,
    grp.obtain and ("|cffffd100How to obtain|r\n" .. grp.obtain) or nil
end

---Show the shared InfoTip for a weapon cell, positioned relative to that cell.
---@class Warbandeer_Collected
---@field ShowWeaponCellTip fun(grp: table, t: number, visuals: number[], parent: Frame, position: table, ptr: boolean?)
ns.ShowWeaponCellTip = function(grp, t, visuals, parent, position, ptr)
  ns.ShowInfoTipFor{ kind = "weapon", grp = grp, t = t, visuals = visuals, ptr = ptr,
    parent = parent, position = position }
end

---@type Warbandeer_Collected
local ns = select(2, ...)

-- Content for a weapon cell's hover panel, derived without touching a frame: the appearance list
-- and the status counts behind `controls/InfoTipWeapon.lua`. Split out because everything here is a
-- walk over the cell's visual ids plus an injected collected map, which makes the two rules worth
-- pinning — the line cap and what the status line counts — reachable from busted, while the
-- rendering stays in-game-tested like the rest of the panel.
--
-- `ns.WeaponSource` is called rather than captured, so a spec installs its own resolver (the same
-- arrangement outfitsave.lua uses for its savers).

---@class Warbandeer_Collected
---@field WeaponTipCap number  most appearance lines a weapon tip renders before the "and N more" tail
---@field WeaponTipLines fun(visuals: number[], cmap: table<number, boolean>?, cap: number?): WeaponTipLine[], number
---@field WeaponTipStatus fun(visuals: number[], cmap: table<number, boolean>?): WeaponTipStatus

---One appearance in the cell, ready to render.
---@class WeaponTipLine
---@field text string  item name, with the difficulty suffix already inlined
---@field collected boolean?  nil under PTR preview — an upcoming look has no collected state, so the row draws no mark
---@field pending number?  itemID whose name is still streaming; the renderer requests it and re-renders

---What the status line under the header counts.
---@class WeaponTipStatus
---@field wanted number  appearances in the cell flagged wanted
---@field rank string?  BEST tier among them (ns:WeaponCellRank), nil if none is ranked
---@field collected number  appearances owned; 0 under PTR preview, where `total` is the "upcoming" count instead
---@field total number  appearances in the cell

-- The cell holding 249 appearances is why a cap survived the move off GameTooltip (#856): a panel
-- can size itself, but not to 249 rows. Raised from the tooltip's 12 because a panel body has the
-- room — 20 rows is roughly twice a full armour tip and still well inside the screen.
ns.WeaponTipCap = 20

---The cell's appearances as renderable lines, plus how many the cap dropped.
---
---A look whose name hasn't streamed in yet falls back to its visual id rather than blanking, so a
---still-loading tip reads as "this many looks, names pending" instead of an empty panel — and
---carries the itemID to request, so the renderer can nudge it and re-render. A look with no
---resolvable source at all gets the same fallback text but nothing to wait on.
---@param visuals number[]
---@param cmap table<number, boolean>?  collected lookup; nil under PTR preview (no collected state)
---@param cap number?  defaults to ns.WeaponTipCap
---@return WeaponTipLine[] lines, number overflow  appearances beyond the cap (0 when none)
function ns.WeaponTipLines(visuals, cmap, cap)
  cap = cap or ns.WeaponTipCap
  local lines = {}
  for i, v in ipairs(visuals) do
    if i > cap then return lines, #visuals - cap end
    local src = ns.WeaponSource(v)
    local name = (src and src.name) or ("Appearance " .. v)
    -- Suffix the boss-drop difficulty (muted gold) so same-named recolours read apart, matching the
    -- chooser. Inlined into the text rather than returned apart: the panel renders one Label per row.
    if src and src.difficulty then name = name .. "  |cffb0a060" .. src.difficulty .. "|r" end
    -- Branch rather than an `and`/`or` chain: "not collected" has to stay `false` while "no collected
    -- state at all" stays `nil`, and a trailing `or nil` flattens the first into the second.
    local isCollected
    if cmap then isCollected = cmap[v] or false end
    lines[#lines + 1] = {
      text = name,
      collected = isCollected,
      pending = (src and not src.name) and src.itemID or nil,
    }
  end
  return lines, 0
end

---The status line's counts for a weapon cell.
---
---Wanted is counted per APPEARANCE, matching `ns.WeaponSourceInfo` and the ★ filter's unit —
---`ns:WeaponCellWanted` answers "does this bucket hold anything wanted", which is the cell's marker
---rule, not a total. The tier defers to `ns:WeaponCellRank` rather than re-deriving "best" here.
---@param visuals number[]
---@param cmap table<number, boolean>?  collected lookup; nil under PTR preview
---@return WeaponTipStatus
function ns.WeaponTipStatus(visuals, cmap)
  local wanted, coll = 0, 0
  for _, v in ipairs(visuals) do
    if ns.db.weaponWanted[v] then wanted = wanted + 1 end
    if cmap and cmap[v] then coll = coll + 1 end
  end
  return { wanted = wanted, rank = ns:WeaponCellRank(visuals), collected = coll, total = #visuals }
end

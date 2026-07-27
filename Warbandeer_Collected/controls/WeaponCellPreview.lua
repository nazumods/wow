---@type Warbandeer_Collected
local ns = select(2, ...)
local DressingRoom = ns.DressingRoom

-- Browsing a weapon cell **on the one paper doll** (#673) — the load path, the staging, and the
-- ←/→ ↑/↓ navigation that belongs to it. The docked chooser pane those gestures drive is the
-- companion controls/WeaponCellPicker.lua. Reopens the DressingRoom class.
--
-- **There used to be two dolls.** A weapon cell loaded through `_load` like a set, replacing
-- `_group`/`_set` with a synthetic weapon "set" — and since that set has no armour behind it, the
-- render forked to a bare body (`_dressWeapon`), which meant hiding every slot column, closing the
-- look builder, and wiping the composed look off the actor so nothing could re-appear on a body
-- with no widget left to take it off (#641). The cost was that a weapon found in the Weapons view
-- couldn't be *shown* in your look at all: staging it printed a chat line and asked you to go
-- preview an armour set to see it.
--
-- Now the two are independent state on one model. `_group`/`_set` stay the previewed ARMOUR set,
-- untouched by anything here; a browsed cell lives in `_cell` and its shown look is a live pick in
-- the composed look, exactly as a look-builder pick is. Nothing technical ever blocked this: the
-- old bare-body path already forced the weapon on with `SlotTransmog` — the primitive that renders
-- any appearance on any character regardless of class — which is the same primitive `_applyLook`
-- composes with. The two paths differed by policy, not capability.
--
-- **`_focus`** is what the split costs: with both surfaces live at once, ←/→ and ↑/↓ have two
-- plausible targets, so they follow the last cell clicked ("armor"|"weapons"). The collection
-- window's Armor|Weapons toggle deliberately doesn't touch it — that toggle swaps grids and
-- nothing else.

---@class DressingRoom
---@field _focus string?  which surface the arrow keys drive ("armor"|"weapons") — the last cell clicked
---@field _cell table?  the browsed weapon cell, { group, set }; nil until one is browsed
---@field _cellHand string?  which hand the browsed look occupies ("main"|"off"), nil when it isn't staged
---@field _loadCell fun(self: DressingRoom, group: table, set: table)
---@field _stageCellLook fun(self: DressingRoom, hand: string?)
---@field _shownCellLook fun(self: DressingRoom): table?
---@field _stepWeaponPiece fun(self: DressingRoom, dir: number)
---@field _stepWeaponType fun(self: DressingRoom, dir: number)
---@field _titleWeapon fun(self: DressingRoom)

---Browse a weapon cell: dock its chooser and put its first look on the doll. The weapon-cell half
---of `_load`, which routes here — and which is the whole of the difference between the two: not one
---field of the armour preview is touched, so the set on the body, its slot columns, its class icon,
---tier bars and ratings row all stay exactly as they were.
---@param group table  the synthetic weapon-cell group from ns.PreviewWeaponCell
---@param set table    its single set, carrying `_looks`
function DressingRoom:_loadCell(group, set)
  self._focus = "weapons"
  self._cell = { group = group, set = set }
  self._weaponPiece = 1
  -- A fresh cell has claimed no hand yet, so its type's default applies and the OTHER hand is left
  -- alone — which is what lets browsing a sword and then a shield build a pair.
  self._cellHand = nil
  -- Only when nothing has ever skinned the actor (a weapon cell clicked before any armour set):
  -- Dress renders the race with no set as a bare body for the weapon to hang on. Otherwise the
  -- staging below is an in-place override on the doll already there — no re-skin, no flicker.
  if not self._dressed then self:Dress() end
  -- Dock before staging, so the staging's own repaint of the row highlight and the hand buttons
  -- lands on this cell's list rather than the outgoing one's.
  self:ShowCellChooser(set._looks)
  self:_stageCellLook()
  -- Each surface owns its own grid cursor now that both are on the doll at once; `_load` leaves
  -- this one alone, and only closing the room (or loading a library look) clears both.
  ns:NotifyDressedWeaponCellChanged(group._source, group._type)
end

---The cell look currently being shown, or nil when nothing is browsed.
---@return table?
function DressingRoom:_shownCellLook()
  local set = self._cell and self._cell.set
  local list = set and set._looks
  return list and list[self._weaponPiece or 1]
end

---Put the shown cell look on the model, in `hand` or in the hand it already occupies. The one path
---for every gesture that changes what the Weapons view is showing — a cell clicked, ↑/↓, a chooser
---row, a hand button — so all four land the weapon the same way and repaint the same surfaces.
---
---`ns.StageCellWeapon` owns the rules (which hand, what it vacates, what it does to `_lookNoOH`);
---this is the part that has to touch the model and the frames.
---@param hand string?  the hand asked for, nil to keep the one this cell's look is in
function DressingRoom:_stageCellLook(hand)
  local look = self:_shownCellLook()
  if not look or not look.sourceID then return end
  local staged = ns.StageCellWeapon(self._cell.group._type, hand or self._cellHand, look.sourceID,
    { mainHand = self._lookMH, offHand = self._lookOH,
      noOffHand = self._lookNoOH, hand = self._cellHand })
  self._lookMH, self._lookOH, self._lookNoOH = staged.mainHand, staged.offHand, staged.noOffHand
  self._cellHand = staged.hand
  self:_applyLook()       -- in place: the armour and the rest of the look stay put (+ repaints the slots)
  self:_titleWeapon()
  self:_syncCellActions()
  if self._cellList then self._cellList:Refresh() end
  -- The look builder is a view of the same fields, so keep its selection borders honest if it's the
  -- pane that happens to be docked.
  if self._picker and self._picker._widget:IsShown() then self._pickerList:Refresh() end
end

---Cycle the shown look within the browsed cell, wrapping — the ↑/↓ nav, which has no difficulty
---tiers to step here. Re-renders in place on the outfit.
---@param dir number  -1 = previous look, +1 = next
function DressingRoom:_stepWeaponPiece(dir)
  local list = self._cell and self._cell.set._looks
  if not list or #list < 2 then return end
  local cur = (self._weaponPiece or 1) - 1                -- to 0-based
  self._weaponPiece = (cur + dir) % #list + 1             -- step, wrap, back to 1-based
  self:_stageCellLook()
end

---Step to the adjacent weapon TYPE the browsed source has — the ←/→ nav, wrapping over the types
---that source actually drops. Rebuilds the cell through `PreviewWeaponCell`, so it re-enters
---`_loadCell` and the new type's default hand applies.
---@param dir number  +1 = next type, -1 = previous
function DressingRoom:_stepWeaponType(dir)
  local grp, t = self._cell.group._source, self._cell.group._type
  if not grp then return end
  local avail, cur = {}, nil
  for _, ty in ipairs(ns.WeaponTypeOrder) do
    if grp.types[ty] then avail[#avail + 1] = ty; if ty == t then cur = #avail end end
  end
  if not cur or #avail < 2 then return end
  cur = (cur - 1 + dir) % #avail + 1
  local newT = avail[cur]
  -- Carry the PTR flag (#767 L-13). host stays nil, which keeps the current dock host.
  ns.PreviewWeaponCell(grp, newT, grp.types[newT], nil, self._cell.group._ptr)
end

-- Title the window with the browsed weapon's real name (+ position when the cell holds several:
-- "Frostbrand (2/5)"). Item names load async, so retitle shortly (capped) until the name is cached,
-- guarding against a cell/piece change mid-wait.
--
-- The title follows `_focus` like the arrow keys do: browsing a weapon names the weapon, previewing
-- a set names the set (`_load`). The armour set is still on the doll either way — its slot columns
-- and class icon say so — and the position readout is what makes ↑/↓ legible.
function DressingRoom:_titleWeapon()
  local set, idx = self._cell.set, self._weaponPiece or 1
  local count = #set._looks
  local look = set._looks[idx]
  local name = look and C_Item.GetItemNameByID(look.itemID)
  if look and not name then C_Item.RequestLoadItemDataByID(look.itemID) end
  if name and look.difficulty then name = name .. " — " .. look.difficulty end   -- disambiguate difficulty recolours
  self:Title((name or set.name) .. (count > 1 and (" (%d/%d)"):format(idx, count) or ""))

  -- The shared capped retry (#770 step 14). Unlike the slot updaters this one resets on SUCCESS —
  -- a resolved name means the next cell browsed starts with a full budget — and its re-run is
  -- guarded against the cell or piece having moved on while the name was still loading.
  if name then
    ns.ResetRetry(self, "weaponTitle")
  elseif not ns.Retry(self, "weaponTitle", { again = function()
    -- Guarded: the cell or the piece can move on while a name is still loading.
    if self._cell and self._cell.set == set and (self._weaponPiece or 1) == idx then self:_titleWeapon() end
  end }) then
    -- **Budget spent — clear it**, so the next cell browsed starts with a full one. This path resets
    -- on exhaustion as well as on success; the slot updaters deliberately do NOT, staying spent until
    -- their own reset site fires. Both behaviours are as they were, which is why the reset stays a
    -- caller decision rather than something `ns.Retry` does.
    ns.ResetRetry(self, "weaponTitle")
  end
end

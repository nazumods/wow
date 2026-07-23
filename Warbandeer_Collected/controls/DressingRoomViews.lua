---@type Warbandeer_Collected
local ns = select(2, ...)
local DressingRoom = ns.DressingRoom

-- Per-view preview memory (#656) — the room-coupled half of the Armor/Weapons split; the decision
-- itself is `ns.PreviewToRestore` in the pure viewsync.lua. Reopens the DressingRoom class.
--
-- The two grids and the room used to be independent surfaces: `MainWindow:SetMode` swapped which
-- grid was shown and never touched the room, so previewing a set, toggling to Weapons, clicking a
-- cell and toggling back left the *weapon* on the model with the Armor grid on screen. The room now
-- remembers the last preview from each view, and the toggle switches to it — which is what "switch
-- to what I was looking at over here" ought to mean.
--
-- **Classified on `group.weaponCell` alone**, deliberately not by enumerating what lives in which
-- grid: a weapon-grid drill-in belongs to the Weapons view, everything else to the Armor view. The
-- `kind`-only groups (Illusions / Arsenals) sit in the ARMOR grid today, and nazumods/wow#653 is
-- about moving the arsenals into the Weapons view — naming them here would hard-code exactly the
-- arrangement that issue changes, while `weaponCell` keeps answering correctly either way.

---@class DressingRoom
---@field _view string?  which view's preview is on screen ("armor"|"weapons"), nil in outfit mode
---@field _viewMemory table<string, { group: table, set: table, piece: number? }>?  last preview per view
---@field _modeToggle table  the room's own Armor|Weapons toggle (DressingRoomControls.lua)
---@field _rememberPreview fun(self: DressingRoom, group: table, set: table)
---@field _syncViewToggle fun(self: DressingRoom)
---@field SwitchView fun(self: DressingRoom, weapons: boolean)
---@field RestoreViewPreview fun(self: DressingRoom, weapons: boolean)

---Record the preview `_load` is applying, under the view it belongs to. The one place a preview
---changes, so the one place the memory is written.
---@param group table
---@param set table
function DressingRoom:_rememberPreview(group, set)
  local view = group.weaponCell and "weapons" or "armor"
  self._view = view
  self._viewMemory = self._viewMemory or {}
  self._viewMemory[view] = { group = group, set = set }
  self:_syncViewToggle()
end

---Light the room's toggle for the view whose preview is on screen. Deliberately keyed to `_view`
---— what the ROOM is showing — rather than to the grid's mode: they agree whenever the toggle was
---used, and where they can't (a loaded look, which belongs to neither grid) lighting neither half
---is the honest answer.
function DressingRoom:_syncViewToggle()
  if not self._modeToggle then return end
  -- Spelled out rather than folded into an `and/or` chain: `_view == "armor" and false or nil`
  -- evaluates to nil, which would light neither half for the Armor view.
  local weapons
  if self._view == "weapons" then weapons = true
  elseif self._view == "armor" then weapons = false end
  self._modeToggle:Select(weapons)
end

---The room's toggle: switch the collection window to the other view, which since #656 also brings
---that view's last preview back onto the model. With no window open — the room is reachable from
---Warbandeer's embedded collected view — there is no grid to switch, so just move the preview.
---@param weapons boolean  true = the Weapons view
function DressingRoom:SwitchView(weapons)
  if ns.window then ns.window:SetMode(weapons) else self:RestoreViewPreview(weapons) end
end

---Switch the room to the last preview from the view the grid just toggled to — or leave it exactly
---as it is, which is the answer in three of the four cases (see `ns.PreviewToRestore` for the table
---and the reasoning). Called from `MainWindow:SetMode`, and only ever on an OPEN room: toggling a
---grid never opens the preview window.
---@param weapons boolean  true when the grid switched to the Weapons view
function DressingRoom:RestoreViewPreview(weapons)
  -- Snapshot which look within the outgoing view's cell is showing, so coming back lands on it
  -- rather than resetting to the first. Done on the way out, which is the only moment it's known,
  -- and harmless for an armour set (which has no piece).
  local leaving = self._view and self._viewMemory and self._viewMemory[self._view]
  if leaving then leaving.piece = self._weaponPiece end

  local mem = ns.PreviewToRestore(self._view, weapons and "weapons" or "armor", self._viewMemory)
  if not mem then return end
  -- `_load` rather than `ns.ShowDressingRoom`: the room is already open, so there is nothing to
  -- show, and going the long way would reset the picked race back to the logged-in character's.
  self:_load(mem.group, mem.set, mem.piece)
end

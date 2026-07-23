---@type Warbandeer_Collected
local ns = select(2, ...)

-- The **outfit library** (#655): looks saved into our own account-wide SavedVariables, so a
-- transmog composed on one character is available on every character.
--
-- Why this exists at all: the game's custom sets are **per-character**. Measured 2026-07-22 — the
-- five sets created on one alt were absent on another, and `id 0` resolved to a different set on
-- each. So `C_TransmogCollection`'s store, which controls/DressingRoomOutfitActions.lua writes,
-- can't move a look between characters; only the `/customset` string could, by hand. This is that
-- workaround made automatic.
--
-- Pure Lua over `ns.db` and the codec — no `C_*` calls, no frames — so it is **unit-tested**
-- (spec/outfitlibrary_spec.lua), unlike the rest of the outfit chain.
--
-- Entries store the **encoded `/customset v1 …` string**, not the list:
--
--   db.outfits = { { name = "Rootwarden", look = "v1 298102,…" }, … }
--
-- One line per outfit; no schema of our own to migrate as the wire format is already versioned;
-- the codec is reused unchanged; and every stored outfit *is* its own export. An array rather than
-- a name-keyed map so insertion order is stable (the order the dropdown shows) and rename is a
-- field write rather than a re-key.
--
-- Names are validated only for non-empty + unique. Deliberately NOT `IsValidCustomSetName`: that's
-- a C call, it would cost this file its testability, and Blizzard's name rules govern *their*
-- store — they apply when pushing a look across, not to ours.

---@class LibraryOutfit
---@field name string  the user's name for it, unique within the library
---@field look string  the `/customset v1 …` encoding of the outfit
---@field char string?  "Name-Realm" of whoever saved it
---@field class string?  that character's class file ("DRUID") — provenance, NOT what the look is for
---@field forClass string?  class file of the SET the look was composed from ("WARRIOR")
---@field armor string?  armour type the look's pieces are ("Leather"), or "Any"

---@class OutfitMeta
---@field char string?
---@field class string?
---@field forClass string?
---@field armor string?

---@class Warbandeer_Collected
---@field LibraryOutfits fun(): LibraryOutfit[]
---@field LibraryOutfit fun(name: string): LibraryOutfit?, number?
---@field LibraryOutfitList fun(name: string): table[]?, string?
---@field SaveLibraryOutfit fun(name: string, list: table[], meta: OutfitMeta?): boolean, string?
---@field RenameLibraryOutfit fun(oldName: string, newName: string): boolean, string?
---@field DeleteLibraryOutfit fun(name: string): boolean

-- The provenance fields a save records. Captured at save time because none of it can be recovered
-- later: the encoded look carries appearance ids and nothing about where it came from.
local META = { "char", "class", "forClass", "armor" }

-- Trim, so a name that's only whitespace reads as empty and " x " and "x" can't both exist.
---@param name string?
---@return string
local function clean(name)
  return (name or ""):match("^%s*(.-)%s*$")
end

-- Non-empty and not already taken by a DIFFERENT entry (`exceptName` lets a rename keep its own
-- name). Returns nil when the name is fine, else the message to show. Mirrors `nameError` in
-- outfit.lua, but over our store and without the C-side filter.
---@param name string
---@param exceptName string?
---@return string?
local function nameError(name, exceptName)
  if name == "" then return "a name is required" end
  if exceptName and name == exceptName then return nil end
  if ns.LibraryOutfit(name) then return ("\"%s\" is already in the library"):format(name) end
end

---Every saved look, in the order they were added.
---@return LibraryOutfit[]
function ns.LibraryOutfits()
  return (ns.db and ns.db.outfits) or {}
end

---Find a saved look by name, with its index. nil when there's no such entry.
---@param name string
---@return LibraryOutfit? entry, number? index
function ns.LibraryOutfit(name)
  name = clean(name)
  if name == "" then return nil end
  for i, o in ipairs(ns.LibraryOutfits()) do
    if o.name == name then return o, i end
  end
end

---A saved look decoded back into an outfit list, ready for `DressingRoom:ApplyOutfit`.
---
---Returns the decoder's own error rather than a partial list when the stored string is unreadable
---— a hand-edited SavedVariables file shouldn't dress the model with half an outfit.
---@param name string
---@return table[]? list, string? err  exactly one is non-nil
function ns.LibraryOutfitList(name)
  local entry = ns.LibraryOutfit(name)
  if not entry then return nil, ("no saved look named \"%s\""):format(clean(name)) end
  return ns.DecodeOutfit(entry.look)
end

---Save `list` under `name`, replacing an entry of the same name in place.
---
---Replacing in place rather than removing and appending keeps the library's order stable: re-saving
---the third look leaves it third instead of jumping to the end. `meta` (who saved it, which class,
---which set's class, the armour type) overwrites the stored provenance on a replace — the entry now
---holds a different look, so the old attribution would be a lie.
---@param name string
---@param list table[]
---@param meta OutfitMeta?  provenance; the caller collects it, this file just stores it
---@return boolean ok, string? err
function ns.SaveLibraryOutfit(name, list, meta)
  name = clean(name)
  if name == "" then return false, "a name is required" end
  local entry = ns.LibraryOutfit(name)
  if not entry then
    entry = { name = name }
    local outfits = ns.LibraryOutfits()
    outfits[#outfits + 1] = entry
  end
  entry.look = ns.EncodeOutfit(list)
  for _, field in ipairs(META) do entry[field] = meta and meta[field] or nil end
  return true
end


---Rename a saved look. Keeping its own name is allowed, so re-committing an untouched field isn't
---an error.
---@param oldName string
---@param newName string
---@return boolean ok, string? err
function ns.RenameLibraryOutfit(oldName, newName)
  local entry = ns.LibraryOutfit(oldName)
  if not entry then return false, ("no saved look named \"%s\""):format(clean(oldName)) end
  newName = clean(newName)
  local err = nameError(newName, entry.name)
  if err then return false, err end
  entry.name = newName
  return true
end

---Remove a saved look. False when there was nothing by that name.
---@param name string
---@return boolean removed
function ns.DeleteLibraryOutfit(name)
  local _, index = ns.LibraryOutfit(name)
  if not index then return false end
  table.remove(ns.LibraryOutfits(), index)
  return true
end

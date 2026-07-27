---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui

-- The `/collected outfit …` command surface: save the previewed look into the game's own custom-set
-- store and load one back, plus the `/customset v1` string export/import. Split out of commands.lua
-- (which was over the file-size budget with these in it); the store wrappers and validation are
-- outfit.lua, the codec is outfitcodec.lua, and the button equivalents are
-- controls/DressingRoomOutfits.lua. Every path here drives the SAME functions the buttons do, so
-- this doubles as the scriptable/verification surface for them.

-- ─── The two guards every command here is built from ─────────────────────────
-- Five commands need the preview open and three need a look to exist, and each spelled its guard
-- out again. Collapsing them isn't only line count: the boilerplate is what let the one save path
-- that forgot its provenance `meta` sit unnoticed beside four that needed none (#758). What's left
-- in each command body below is what that command actually does.

---Run `fn(room)` against the shared dressing room, or explain why it can't run.
---@param clause string  completes "Open a set's Preview first — …"; the only part that ever varied
---@param fn fun(room: table)
local function withRoom(clause, fn)
  local room = ns.OpenDressingRoom()
  if not room then
    ns.Print("Open a set's Preview first — " .. clause)
    return
  end
  fn(room)
end

---Run `fn(entry)` with the library look `name` resolves to, or say there isn't one.
---
---Resolution is `ns.LibraryOutfit`, so a typed name matches case-insensitively with an exact match
---winning (#728) — and every caller takes `entry.name` back from it rather than reusing what was
---typed, which is what keeps the stored capitalisation.
---@param name string
---@param fn fun(entry: LibraryOutfit)
local function withLook(name, fn)
  local entry = ns.LibraryOutfit(name)
  if not entry then
    ns.Print(("No saved look named \"%s\". Try /collected outfit list."):format(name))
    return
  end
  fn(entry)
end

-- Outfit interchange: read the look currently on screen out as Blizzard's shareable
-- `/customset v1 …` string or as a clickable chat link, and put either back in. Each of these
-- calls straight into the share row's own method (controls/DressingRoomOutfitShare.lua), so the
-- command and the button are literally one implementation — the command adds only the "is the
-- room open?" guard the button never needs.
local function outfitExport()
  withRoom("export reads the look currently on screen.", function(room) room:ExportOutfit() end)
end

-- Shift-click a transmog link into `/collected outfit import ` and it arrives here whole, which
-- is the practical way to import someone's posted link: our own field can't receive a shift-click.
---@param arg string
local function outfitImport(arg)
  withRoom("import dresses the window on screen.", function(room) room:ImportOutfit(arg) end)
end

local function outfitPost()
  withRoom("posting shares the look currently on screen.", function(room) room:PostOutfit() end)
end

-- Both stores at once, so the difference between them is visible where it matters: the library is
-- account-wide, the game's custom sets are this character's only.
local function outfitList()
  local lib, sets = ns.LibraryOutfits(), ns.CustomSets()
  local max = C_TransmogCollection.GetNumMaxCustomSets()
  local lines = { ("Library (account-wide) — %d"):format(#lib) }
  for _, o in ipairs(lib) do
    -- Full provenance here, where there's width for it: who saved it, their class, its armour type,
    -- and which class's set it was built from.
    local origin = ns.OutfitOrigin(o)
    local forClass = o.forClass and ns.ClassLabel(o.forClass)
    lines[#lines + 1] = ("  %-28s %s%s"):format(o.name, origin,
      forClass and ("   (a %s look)"):format(forClass) or "")
  end
  if #lib == 0 then lines[#lines + 1] = "  (empty)" end
  lines[#lines + 1] = ""
  lines[#lines + 1] = ("This character's transmog sets — %d/%s"):format(#sets, tostring(max))
  for _, s in ipairs(sets) do lines[#lines + 1] = ("  %-6d %s"):format(s.id, s.name) end
  if #sets == 0 then lines[#lines + 1] = "  (none)" end
  ui.ShowCopyWindow("Saved outfits", table.concat(lines, "\n"))
  ns.Print(("%d in your library, %s/%s on this character."):format(#lib, #sets, tostring(max)))
end

-- Resolving a typed name to the stored one — exact, then case-insensitive — used to be a local
-- here, so only these commands could drive a look by the name in the dropdown without matching its
-- case. `ns.LibraryOutfit` does it for everyone since #728, which is what closed the same gap on
-- the outfit row's Save; each command below just takes `entry.name` back from it.

---@param name string
local function outfitSave(name)
  withRoom("save writes the look currently on screen.", function(room)
    if name == "" then
      ns.Print("Usage: /collected outfit save <name>")
      return
    end
    local list = room:ComposeOutfit()
    local issues = ns.OutfitIssues(list)
    if issues.filled == 0 then
      ns.Print("Nothing to save — the preview is empty.")
      return
    end
    if issues.pending then
      ns.Print("Item data is still loading — try again in a moment.")
      return
    end
    -- Unlike the button this replaces a same-named look outright: a scripted call has no
    -- arm-then-confirm step to answer. Not `withLook`, which would refuse a name that doesn't
    -- exist yet — saving under a NEW name is the normal case here.
    local existing = ns.LibraryOutfit(name)
    local target = existing and existing.name or name
    -- Stamped exactly as the row's Save button stamps it (#758). This used to pass no meta at all,
    -- which wiped the provenance off an entry it replaced — the one save path that recorded nothing.
    -- The room's stamper rather than `ns.LocalOutfitMeta` because only it can derive `forClass`.
    local ok, err = ns.SaveLibraryOutfit(target, list, room:_outfitMeta(list))
    if not ok then
      ns.Print("Couldn't save: " .. err)
      return
    end
    -- No `room:RefreshOutfits()`: the save announces itself and every open surface refreshes (#727).
    ns.Print((existing and "Replaced \"%s\" in your library." or "Saved \"%s\" to your library."):format(target))
  end)
end

---@param name string
local function outfitLoad(name)
  withRoom("load dresses the window on screen.", function(room)
    withLook(name, function(look)
      room:LoadOutfit(look.name)   -- prints its own confirmation, with the look's provenance
    end)
  end)
end

---@param name string
local function outfitDelete(name)
  withLook(name, function(look)
    -- This used to reach for the room and refresh it, and knew nothing of the library window —
    -- which is exactly the gap #727 closed: the delete announces itself, and whichever surfaces
    -- are open refresh themselves.
    local deleted = look.name
    ns.DeleteLibraryOutfit(deleted)
    ns.Print(("Deleted \"%s\" from your library."):format(deleted))
  end)
end

-- Copy a library look into THIS character's transmog sets — the bridge across the two stores, and
-- the only path where Blizzard's name filter and 25-set cap apply.
---@param name string
local function outfitPush(name)
  withLook(name, function(entry)
    local look = entry.name
    local list, err = ns.LibraryOutfitList(look)
    if not list then
      ns.Print("Couldn't read that look: " .. err)
      return
    end
    local existing
    for _, s in ipairs(ns.CustomSets()) do if s.name == look then existing = s.id end end
    local id, saveErr = ns.SaveCustomSet(look, list, existing)
    if not id then
      ns.Print("Couldn't push: " .. saveErr)
      return
    end
    ns.Print(("Pushed \"%s\" to this character's transmog sets."):format(look))
  end)
end

ns:registerCommand("outfit", nil, function(_, args)
  local sub, rest = (args or ""):match("^%s*(%S*)%s*(.-)%s*$")
  sub = (sub or ""):lower()
  if sub == "export" then outfitExport()
  elseif sub == "post" then outfitPost()
  elseif sub == "import" then outfitImport(rest)
  elseif sub == "list" then outfitList()
  elseif sub == "save" then outfitSave(rest)
  elseif sub == "load" then outfitLoad(rest)
  elseif sub == "delete" then outfitDelete(rest)
  elseif sub == "push" then outfitPush(rest)
  else
    ns.Print("Usage: /collected outfit list | save <name> | load <name> | delete <name> | push <name>")
    ns.Print("                       | export | post | import <string or link>")
    ns.Print("  list   — your account-wide library, plus this character's transmog sets")
    ns.Print("  save   — save the previewed look to your library (available on every character)")
    ns.Print("  load   — dress the open preview from your library")
    ns.Print("  delete — remove a look from your library")
    ns.Print("  push   — copy a look into THIS character's transmog sets, to wear at a transmogrifier")
    ns.Print("  export — the previewed look as a shareable /customset string (copy window)")
    ns.Print("  post   — put the previewed look in your chat box as a clickable link")
    ns.Print("  import — dress the open preview from a /customset string, or a shift-clicked link")
  end
end, "Save looks to your account-wide library, push one to this character, or share it as a string")

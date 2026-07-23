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

-- Outfit interchange: read the look currently on screen out as Blizzard's shareable
-- `/customset v1 …` string, put one back in, and list the game's saved custom sets. The
-- verification surface for the outfit layer (outfitcodec.lua + outfit.lua +
-- controls/DressingRoomOutfit.lua) ahead of the buttons that will drive the same paths.
local function outfitExport()
  local room = ns.OpenDressingRoom()
  if not room then
    ns.Print("Open a set's Preview first — export reads the look currently on screen.")
    return
  end
  local list = room:ComposeOutfit()
  local issues = ns.OutfitIssues(list)
  if issues.filled == 0 then
    ns.Print("Nothing to export — the preview is empty.")
    return
  end

  -- String first so it's the top of the selection; the per-slot listing below is what lets a
  -- mismatch between the string and the model be spotted at a glance.
  local body = { ns.EncodeOutfit(list), "", ns.OutfitSummary(list) }
  if issues.pending then
    body[#body + 1] = ""
    body[#body + 1] = "NOTE: some item data is still loading — re-run to re-check."
  end
  ui.ShowCopyWindow("Outfit export", table.concat(body, "\n"))
  ns.Print(("Exported %d slots."):format(issues.filled))
end

---@param arg string
local function outfitImport(arg)
  local room = ns.OpenDressingRoom()
  if not room then
    ns.Print("Open a set's Preview first — import dresses the window on screen.")
    return
  end
  local list, err = ns.DecodeOutfit(arg)
  if not list then
    ns.Print("Couldn't read that outfit string: " .. err)
    ns.Print("Expected a /customset v1 string (17 comma-separated ids).")
    return
  end
  room:ApplyOutfit(list)
  local issues = ns.OutfitIssues(list)
  ns.Print(("Imported %d slots into the preview."):format(issues.filled))
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

-- Resolve a library name the user typed (exact, then case-insensitive), so a command can be driven
-- by the name shown in the dropdown without matching its case.
---@param name string
---@return string?  the stored name
local function findLook(name)
  if name == "" then return nil end
  local lowered = name:lower()
  local fuzzy
  for _, o in ipairs(ns.LibraryOutfits()) do
    if o.name == name then return o.name end
    if o.name:lower() == lowered then fuzzy = fuzzy or o.name end
  end
  return fuzzy
end

---@param name string
local function outfitSave(name)
  local room = ns.OpenDressingRoom()
  if not room then
    ns.Print("Open a set's Preview first — save writes the look currently on screen.")
    return
  end
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
  -- arm-then-confirm step to answer.
  local existing = findLook(name)
  local ok, err = ns.SaveLibraryOutfit(existing or name, list)
  if not ok then
    ns.Print("Couldn't save: " .. err)
    return
  end
  room:RefreshOutfits()
  ns.Print((existing and "Replaced \"%s\" in your library." or "Saved \"%s\" to your library."):format(existing or name))
end

---@param name string
local function outfitLoad(name)
  local room = ns.OpenDressingRoom()
  if not room then
    ns.Print("Open a set's Preview first — load dresses the window on screen.")
    return
  end
  local look = findLook(name)
  if not look then
    ns.Print(("No saved look named \"%s\". Try /collected outfit list."):format(name))
    return
  end
  room:LoadOutfit(look)   -- prints its own confirmation, with the look's provenance
end

---@param name string
local function outfitDelete(name)
  local look = findLook(name)
  if not look then
    ns.Print(("No saved look named \"%s\". Try /collected outfit list."):format(name))
    return
  end
  ns.DeleteLibraryOutfit(look)
  -- Only if the room is on screen; deleting doesn't need it open, unlike save/load.
  local room = ns.OpenDressingRoom()
  if room then room:RefreshOutfits() end
  ns.Print(("Deleted \"%s\" from your library."):format(look))
end

-- Copy a library look into THIS character's transmog sets — the bridge across the two stores, and
-- the only path where Blizzard's name filter and 25-set cap apply.
---@param name string
local function outfitPush(name)
  local look = findLook(name)
  if not look then
    ns.Print(("No saved look named \"%s\". Try /collected outfit list."):format(name))
    return
  end
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
end

ns:registerCommand("outfit", nil, function(_, args)
  local sub, rest = (args or ""):match("^%s*(%S*)%s*(.-)%s*$")
  sub = (sub or ""):lower()
  if sub == "export" then outfitExport()
  elseif sub == "import" then outfitImport(rest)
  elseif sub == "list" then outfitList()
  elseif sub == "save" then outfitSave(rest)
  elseif sub == "load" then outfitLoad(rest)
  elseif sub == "delete" then outfitDelete(rest)
  elseif sub == "push" then outfitPush(rest)
  else
    ns.Print("Usage: /collected outfit list | save <name> | load <name> | delete <name> | push <name>")
    ns.Print("                       | export | import <string>")
    ns.Print("  list   — your account-wide library, plus this character's transmog sets")
    ns.Print("  save   — save the previewed look to your library (available on every character)")
    ns.Print("  load   — dress the open preview from your library")
    ns.Print("  delete — remove a look from your library")
    ns.Print("  push   — copy a look into THIS character's transmog sets, to wear at a transmogrifier")
    ns.Print("  export — the previewed look as a shareable /customset string (copy window)")
    ns.Print("  import — dress the open preview from a /customset string")
  end
end, "Save looks to your account-wide library, push one to this character, or share it as a string")

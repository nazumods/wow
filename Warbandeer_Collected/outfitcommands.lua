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
  if #issues.unusable > 0 then
    local names = {}
    for i, slotID in ipairs(issues.unusable) do names[i] = ns.SlotLabel(slotID) end
    body[#body + 1] = ""
    body[#body + 1] = ("NOTE: %d of %d pieces can't be collected by this character (%s) —"):format(
      #issues.unusable, issues.filled, table.concat(names, ", "))
    body[#body + 1] = "the string above carries them and re-imports fine, but saving this look as a"
    body[#body + 1] = "custom set would silently drop those slots. Pieces merely not owned yet are fine."
  end
  if issues.pending then
    body[#body + 1] = ""
    body[#body + 1] = "NOTE: some item data is still loading — re-run to re-check."
  end
  ui.ShowCopyWindow("Outfit export", table.concat(body, "\n"))
  ns.Print(("Exported %d slots%s."):format(issues.filled,
    #issues.unusable > 0 and (", %d unusable by this character"):format(#issues.unusable) or ""))
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

local function outfitList()
  local sets = ns.CustomSets()
  local max = C_TransmogCollection.GetNumMaxCustomSets()
  if #sets == 0 then
    ns.Print(("No saved transmog sets (room for %s)."):format(tostring(max)))
    return
  end
  local lines = {}
  for _, s in ipairs(sets) do lines[#lines + 1] = ("%-6d %s"):format(s.id, s.name) end
  ui.ShowCopyWindow(("Saved transmog sets — %d/%s"):format(#sets, tostring(max)),
    table.concat(lines, "\n"))
  ns.Print(("%d/%s saved transmog sets."):format(#sets, tostring(max)))
end

-- Find a saved custom set by name (exact, then case-insensitive), so `load`/`save` can be driven
-- by the name the user sees in the dropdown rather than an id they'd have to look up.
---@param name string
---@return { id: number, name: string }?
local function findSet(name)
  local lowered = name:lower()
  local fuzzy
  for _, s in ipairs(ns.CustomSets()) do
    if s.name == name then return s end
    if s.name:lower() == lowered then fuzzy = fuzzy or s end
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
  local existing = findSet(name)
  local id, err = ns.SaveCustomSet(name, list, existing and existing.id or nil)
  if not id then
    ns.Print("Couldn't save: " .. err)
    return
  end
  -- Unlike the button, this reports the drop AFTER writing: the command form has no arm-then-
  -- confirm step, and refusing outright would make a scripted save unusable.
  if #issues.unusable > 0 then
    local names = {}
    for i, slotID in ipairs(issues.unusable) do names[i] = ns.SlotLabel(slotID) end
    ns.Print(("NOTE: %d slot(s) this character can't collect were dropped: %s")
      :format(#issues.unusable, table.concat(names, ", ")))
  end
  room:RefreshOutfits()
  ns.Print((existing and "Overwrote \"%s\"." or "Saved \"%s\"."):format(name))
end

---@param name string
local function outfitLoad(name)
  local room = ns.OpenDressingRoom()
  if not room then
    ns.Print("Open a set's Preview first — load dresses the window on screen.")
    return
  end
  local set = name ~= "" and findSet(name)
  if not set then
    ns.Print(("No saved set named \"%s\". Try /collected outfit list."):format(name))
    return
  end
  room:LoadOutfit(set.id)
  ns.Print(("Loaded \"%s\"."):format(set.name))
end

ns:registerCommand("outfit", nil, function(_, args)
  local sub, rest = (args or ""):match("^%s*(%S*)%s*(.-)%s*$")
  sub = (sub or ""):lower()
  if sub == "export" then outfitExport()
  elseif sub == "import" then outfitImport(rest)
  elseif sub == "list" then outfitList()
  elseif sub == "save" then outfitSave(rest)
  elseif sub == "load" then outfitLoad(rest)
  else
    ns.Print("Usage: /collected outfit export | import <string> | list | save <name> | load <name>")
    ns.Print("  export — the previewed look as a shareable /customset string (copy window)")
    ns.Print("  import — dress the open preview from a /customset string")
    ns.Print("  list   — the transmog sets saved in game")
    ns.Print("  save   — write the previewed look to a saved set (overwrites a matching name)")
    ns.Print("  load   — dress the open preview from a saved set")
  end
end, "Save/load the previewed look as a transmog set, or export/import it as a /customset string")

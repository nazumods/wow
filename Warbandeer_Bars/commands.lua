---@type Warbandeer_Bars
local ns = select(2, ...)

-- Headless data layer: these commands are for inspection/testing only.
-- The UI lives in a separate addon that consumes WarbandeerBarsApi.

ns:registerCommand("", nil, function()
  ns.Print("Warbandeer Bars (headless profile tracker). Commands: snapshot | list | restore <char> [specID] | forget <char> [specID]")
end, "Show status")

ns:registerCommand("snapshot", nil, function()
  local p = ns.Snapshot()
  if p then
    ns.Print(("Captured |cffffd100%s|r — %s (spec %d): %d slots, %d macros")
      :format(p.char, p.spec or "?", p.specID, #(p.slots or {}), #(p.macros or {})))
  else
    ns.Print("Snapshot skipped (in combat, mid-drag, or no active spec).")
  end
end, "Capture the current character now")

ns:registerCommand("list", nil, function()
  local n = 0
  for char, byChar in pairs(ns.db.profiles) do
    for specID, p in pairs(byChar) do
      n = n + 1
      ns.Print(("|cffffd100%s|r [%d] %s — %d slots (captured %s)")
        :format(char, specID, p.spec or "?", #(p.slots or {}),
                p.captured and date("%Y-%m-%d %H:%M", p.captured) or "?"))
    end
  end
  if n == 0 then ns.Print("No profiles stored yet.") end
end, "List stored profiles")

ns:registerCommand("restore", nil, function(_, args)
  local char, specStr = args:match("^(%S+)%s*(%S*)$")
  if not char or char == "" then
    ns.Print("Usage: /wbb restore <char> [specID]"); return
  end
  local specID = tonumber(specStr) or ns.api:GetCurrentSpecID()
  if not ns.api:RestoreProfile(char, specID) then
    ns.Print(("No profile for %s spec %d. Try /wbb list."):format(char, specID))
  end
end, "Restore a stored profile to the current character")

-- Temporary diagnostic for L10: dumps override map data to clipboard.
ns:registerCommand("overrides", nil, function()
  local lines = {}
  local function out(s) lines[#lines+1] = s end
  local function name(id) return id and (C_Spell.GetSpellName(id) or "?") or "nil" end

  out("== spellbook: spellId -> GetOverrideSpell(spellId) ==")
  local n = 0
  for idx = 1, C_SpellBook.GetNumSpellBookSkillLines() do
    local info = C_SpellBook.GetSpellBookSkillLineInfo(idx)
    if info then
      for i = 1, info.numSpellBookItems do
        local si = info.itemIndexOffset + i
        local _, _, spellId = C_SpellBook.GetSpellBookItemType(si, Enum.SpellBookSpellBank.Player)
        if spellId then
          local ovr = C_Spell.GetOverrideSpell(spellId)
          if ovr ~= spellId then
            out(("  %d(%s) -> %d(%s)"):format(spellId, name(spellId), ovr, name(ovr)))
            n = n + 1; if n >= 6 then break end
          end
        end
      end
    end
    if n >= 6 then break end
  end
  if n == 0 then out("  (none)") end

  out("== action bar: bar spellId -> GetOverrideSpell ==")
  n = 0
  for i = 1, 72 do
    local t, index = GetActionInfo(i)
    if t == "spell" and index then
      local ovr = C_Spell.GetOverrideSpell(index)
      out(("  slot%d: %d(%s) -> %d(%s)"):format(i, index, name(index), ovr, name(ovr)))
      n = n + 1; if n >= 6 then break end
    end
  end
  if n == 0 then out("  (none)") end

  out("== flyout slot 1 of first flyout on bar ==")
  local found = false
  for i = 1, 72 do
    local t, id = GetActionInfo(i)
    if t == "flyout" then
      local sid, ovr = GetFlyoutSlotInfo(id, 1)
      out(("  flyout %d: sid=%s(%s) ovr=%s(%s)"):format(
        id, tostring(sid), name(sid), tostring(ovr), name(ovr)))
      found = true; break
    end
  end
  if not found then out("  (no flyout on bar)") end

  local text = table.concat(lines, "\n")
  CopyToClipboard(text)
  ns.Print("Output copied to clipboard — paste it into chat with Ctrl+V.")
end, "Dump spell override maps to clipboard (L10 diagnostic)")

ns:registerCommand("forget", nil, function(_, args)
  local char, specStr = args:match("^(%S+)%s*(%S*)$")
  if not char or char == "" then
    ns.Print("Usage: /wbb forget <char> [specID]"); return
  end
  local specID = tonumber(specStr)
  if specID then
    ns.api:DeleteProfile(char, specID)
    ns.Print(("Forgot %s spec %d."):format(char, specID))
  else
    ns.db.profiles[char] = nil
    ns.Print(("Forgot all profiles for %s."):format(char))
  end
end, "Delete stored profile(s)")

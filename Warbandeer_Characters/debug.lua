local _, ns = ...
local ui = ns.ui
local TitleFrame, ScrollFrame, EditBox = ui.TitleFrame, ui.ScrollFrame, ui.EditBox
local insert, concat = table.insert, table.concat

local SCROLLBAR_W = 26
local LINE_H      = 16
local PADDING     = 20
local MIN_W       = 400
local MAX_W       = 1000

local window    = nil
local measureFS = nil

local function maxLineWidth(text)
  if not measureFS then
    measureFS = UIParent:CreateFontString(nil, "ARTWORK")
    measureFS:SetFontObject(GameFontHighlightSmall)
  end
  local maxW = 0
  for line in text:gmatch("[^\n]+") do
    measureFS:SetText(line)
    local w = measureFS:GetStringWidth()
    if w > maxW then maxW = w end
  end
  return maxW
end

local function createWindow()
  local f = TitleFrame:new{
    name     = "WarbandeerDebugWindow",
    title    = "Debug",
    special  = true,
    level    = 600,
    position = { Center = {}, Height = 500 },
  }
  local scroll = ScrollFrame:new{
    parent   = f,
    position = {
      TopLeft     = {f.titlebar, ui.edge.BottomLeft,  2, -4},
      BottomRight = {f,          ui.edge.BottomRight, -2,  4},
    },
  }
  local eb = EditBox:new{
    parent    = scroll,
    multiline = true,
    template  = "",
    fontObj   = GameFontHighlightSmall,
    position  = {},
    OnEscapePressed = function() f:Hide() end,
  }
  scroll:Child(eb)
  f._eb = eb
  return f
end

-- Recursive table dump. Cycle-safe via `seen`.  Output is roughly Lua-table
-- literal so it can be re-pasted.
local function escapeString(s)
  return '"' .. s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n') .. '"'
end

local function dump(v, indent, seen)
  indent = indent or ""
  seen = seen or {}
  local t = type(v)
  if t == "string"  then return escapeString(v) end
  if t == "number"  then return tostring(v) end
  if t == "boolean" then return tostring(v) end
  if t == "nil"     then return "nil" end
  if t ~= "table"   then return "<"..t..">" end
  if seen[v] then return "<cycle>" end
  seen[v] = true

  -- Compact empty tables.
  local hasAny = false
  for _ in pairs(v) do hasAny = true; break end
  if not hasAny then return "{}" end

  local lines = {"{"}
  local inner = indent .. "  "
  -- Sort keys for stable output; mix string/number keys.
  local keys = {}
  for k in pairs(v) do insert(keys, k) end
  table.sort(keys, function(a, b)
    if type(a) == type(b) then return tostring(a) < tostring(b) end
    return type(a) < type(b)
  end)
  for _, k in ipairs(keys) do
    local keyStr
    if type(k) == "string" and k:match("^[%a_][%w_]*$") then
      keyStr = k
    else
      keyStr = "[" .. (type(k) == "string" and escapeString(k) or tostring(k)) .. "]"
    end
    insert(lines, inner .. keyStr .. " = " .. dump(v[k], inner, seen) .. ",")
  end
  insert(lines, indent .. "}")
  return concat(lines, "\n")
end

ns.dump = dump

local function runCode(code)
  local buffer = {}
  local realPrint = _G.print
  _G.print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring(select(i, ...))
    end
    insert(buffer, concat(parts, "\t"))
  end

  -- Try expression first (wraps with `return`), fall back to a statement so
  -- `local x = ...` style code still runs (though local vars vanish).
  local fn, err = loadstring("return " .. code, "debug")
  if not fn then
    fn, err = loadstring(code, "debug")
  end

  if not fn then
    insert(buffer, "compile error: " .. tostring(err))
  else
    setfenv(fn, _G)
    local results = { pcall(fn) }
    local ok = table.remove(results, 1)
    if not ok then
      insert(buffer, "error: " .. tostring(results[1]))
    elseif #results > 0 then
      for _, r in ipairs(results) do
        insert(buffer, dump(r))
      end
    end
  end

  _G.print = realPrint
  return concat(buffer, "\n")
end

ns:registerCommand("debug", "", function(self, code)
  if not code or code == "" then
    ns.Print("usage: /wbc debug <lua code>")
    return
  end
  if not window then window = createWindow() end

  local text = runCode(code)
  if text == "" then text = "(no output)" end

  local ebW     = math.min(math.max(maxLineWidth(text) + PADDING, MIN_W), MAX_W)
  local windowW = ebW + SCROLLBAR_W
  local nLines  = 1
  for _ in text:gmatch("\n") do nLines = nLines + 1 end

  window:Width(windowW)
  window._eb:Width(ebW)
  window._eb:Height(math.max(nLines * LINE_H + 10, 50))
  window._eb:Text(text)
  window._eb:HighlightText()
  window:Show()
end, "Run lua code and show output in a copyable window")

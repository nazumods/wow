---@type LibNUI_AddOn
local ns = select(2, ...)
local ui = ns.ui
local insert, concat = table.insert, table.concat

-- Recursive table dump. Cycle-safe via `seen`.  Output is roughly a Lua-table
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
  if next(v) == nil then return "{}" end

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
  local fn, err = loadstring("return " .. code, "wdebug")
  if not fn then
    fn, err = loadstring(code, "wdebug")
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

-- `/wdebug <code>` is registered directly (not through the shared `/nui`
-- dispatcher) so the entire argument string reaches the eval verbatim — the
-- dispatcher would otherwise strip the first word as a sub-command.
SLASH_WDEBUG1 = "/wdebug"
SlashCmdList["WDEBUG"] = function(code)
  if not code or code == "" then
    ns.Print("usage: /wdebug <lua code>")
    return
  end
  local text = runCode(code)
  if text == "" then text = "(no output)" end
  ui.ShowCopyWindow("Debug", text)
end

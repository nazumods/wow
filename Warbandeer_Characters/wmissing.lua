---@type Warbandeer_Characters
local ns = select(2, ...)

ns:registerCommand("wmissing", "", function(self)
  local missing = self:getMissingReport()
  local text
  if #missing == 0 then
    text = "All characters have complete data."
  else
    local lines = { #missing .. " characters missing data:" }
    for _, line in ipairs(missing) do
      table.insert(lines, line)
    end
    text = table.concat(lines, "\n")
  end
  ns.ui.ShowCopyWindow("Missing Data", text)
end, "Show missing character data in a copyable window")

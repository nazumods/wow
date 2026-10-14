-- LibNAddOn.toc holds two things the flavor detection depends on that no module spec can see: the
-- `## X-Game: [Game]` line detection falls back on when the WOW_PROJECT_* comparison doesn't say
-- Forever, and flavor.lua's position in the file list. flavor.lua registers `/lib flavor` through
-- registerCommand, which slashCommands.lua provides; if flavor.lua loaded first, ns.registerCommand
-- would be nil and the command would be skipped without any error.

describe("LibNAddOn.toc", function()
  local text, files

  setup(function()
    local f = assert(io.open("LibNAddOn/LibNAddOn.toc", "rb"))
    text = f:read("*a")
    f:close()
    files = {}
    for line in text:gmatch("[^\r\n]+") do
      if not line:match("^%s*#") then files[#files + 1] = line:match("^%s*(%S+)") end
    end
  end)

  local function indexOf(name)
    for i, file in ipairs(files) do
      if file == name then return i end
    end
  end

  it("declares the X-Game metadata the flavor fallback reads", function()
    assert.is_truthy(text:find("\n## X%-Game: %[Game%]%s"))
  end)

  it("declares X-Family", function()
    assert.is_truthy(text:find("\n## X%-Family: %[Family%]%s"))
  end)

  it("lists flavor.lua exactly once", function()
    local count = 0
    for _, file in ipairs(files) do
      if file == "flavor.lua" then count = count + 1 end
    end
    assert.equals(1, count)
  end)

  it("loads flavor.lua after slashCommands.lua, so registerCommand exists for /lib flavor", function()
    assert.is_truthy(indexOf("slashCommands.lua"))
    assert.is_true(indexOf("flavor.lua") > indexOf("slashCommands.lua"))
  end)
end)

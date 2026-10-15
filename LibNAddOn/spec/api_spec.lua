-- api.lua's LibNAddOn(...) is what hands every addon in the suite its helpers. It is loaded
-- standalone here against a namespace whose link* functions are inert, except flavor.lua's, which
-- is the real one -- so this pins only that the entry point wires the flavor helpers in.

describe("LibNAddOn() entry point", function()
  local saved

  ---A namespace where everything api.lua calls exists but does nothing, plus the real flavor.lua.
  local function load()
    local ns = {}
    local function noop() end
    ns.linkCommonFunctions = function(addOn) addOn.GetMetadata = function() return nil end end
    ns.registerSettings, ns.getSettingsParent, ns.registerChangelog = noop, noop, noop
    ns.linkGlobals, ns.createEventListener = noop, noop
    ns.linkCVarHelpers, ns.linkTooltipHelpers = noop, noop
    ns.setupDB, ns.registerSlashCommands = noop, noop
    assert(loadfile("LibNAddOn/flavor.lua"))("LibNAddOn", ns)
    assert(loadfile("LibNAddOn/api.lua"))("LibNAddOn", ns)
    return ns
  end

  before_each(function()
    saved = { api = _G.LibNAddOn, id = _G.WOW_PROJECT_ID, camelot = _G.WOW_PROJECT_CAMELOT, addons = _G.C_AddOns }
    _G.WOW_PROJECT_ID, _G.WOW_PROJECT_CAMELOT, _G.C_AddOns = nil, nil, nil
  end)

  after_each(function()
    _G.LibNAddOn, _G.WOW_PROJECT_ID, _G.WOW_PROJECT_CAMELOT, _G.C_AddOns =
      saved.api, saved.id, saved.camelot, saved.addons
  end)

  it("links the shared flavor and :Supports onto the addon (Retail)", function()
    local ns = load()
    local addOn = {}
    assert.equals(addOn, _G.LibNAddOn("MyAddOn", addOn))
    assert.equals(ns.flavor, addOn.flavor)
    assert.is_true(addOn.flavor.isRetail)
    assert.is_true(addOn:Supports("housing"))
  end)

  it("links the same helpers when the addon is passed as an options table (Forever)", function()
    _G.WOW_PROJECT_CAMELOT, _G.WOW_PROJECT_ID = 18, 18
    local ns = load()
    local addOn = {}
    _G.LibNAddOn({ name = "MyAddOn", addOn = addOn })
    assert.equals(ns.flavor, addOn.flavor)
    assert.is_true(addOn.flavor.isForever)
    assert.is_false(addOn:Supports("housing"))
  end)
end)

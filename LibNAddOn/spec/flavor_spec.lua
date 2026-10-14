-- flavor.lua is loaded standalone (not through libn.load) so each case controls exactly the
-- globals detection reads: WOW_PROJECT_ID, WOW_PROJECT_CAMELOT and C_AddOns. They are saved
-- before each case and restored after, so no case leaks a flavor into another spec file.

describe("LibNAddOn flavor", function()
  local saved

  ---Load flavor.lua into a namespace (a fresh bare one unless the case supplies its own).
  local function load(ns)
    ns = ns or {}
    assert(loadfile("LibNAddOn/flavor.lua"))("LibNAddOn", ns)
    return ns
  end

  ---Stub C_AddOns.GetAddOnMetadata so only ("LibNAddOn", "X-Game") answers; anything else is nil.
  local function stubXGame(value)
    _G.C_AddOns = {
      GetAddOnMetadata = function(addon, field)
        if addon == "LibNAddOn" and field == "X-Game" then return value end
      end,
    }
  end

  before_each(function()
    saved = { id = _G.WOW_PROJECT_ID, camelot = _G.WOW_PROJECT_CAMELOT, addons = _G.C_AddOns }
    _G.WOW_PROJECT_ID, _G.WOW_PROJECT_CAMELOT, _G.C_AddOns = nil, nil, nil
  end)

  after_each(function()
    _G.WOW_PROJECT_ID, _G.WOW_PROJECT_CAMELOT, _G.C_AddOns = saved.id, saved.camelot, saved.addons
  end)

  describe("detection", function()
    it("is Forever when WOW_PROJECT_ID equals WOW_PROJECT_CAMELOT", function()
      _G.WOW_PROJECT_CAMELOT, _G.WOW_PROJECT_ID = 18, 18
      local ns = load()
      assert.equals("forever", ns.flavor.id)
      assert.is_true(ns.flavor.isForever)
      assert.is_false(ns.flavor.isRetail)
    end)

    it("is Retail when the client project is not Camelot", function()
      _G.WOW_PROJECT_CAMELOT, _G.WOW_PROJECT_ID = 18, 1
      local ns = load()
      assert.equals("retail", ns.flavor.id)
      assert.is_false(ns.flavor.isForever)
      assert.is_true(ns.flavor.isRetail)
    end)

    it("is Forever from the X-Game metadata 'Camelot' when the constants are absent", function()
      stubXGame("Camelot")
      local ns = load()
      assert.equals("forever", ns.flavor.id)
      assert.is_true(ns.flavor.isForever)
    end)

    it("is Forever from the X-Game metadata 'Forever' (the [Game] value may be renamed)", function()
      stubXGame("Forever")
      assert.equals("forever", load().flavor.id)
    end)

    it("is Forever from the metadata when only WOW_PROJECT_ID exists", function()
      _G.WOW_PROJECT_ID = 18          -- WOW_PROJECT_CAMELOT undefined: no constant comparison possible
      stubXGame("Camelot")
      assert.equals("forever", load().flavor.id)
    end)

    it("is Retail for any other X-Game value (including the unexpanded token)", function()
      stubXGame("Standard")
      assert.equals("retail", load().flavor.id)
      stubXGame("[Game]")
      assert.equals("retail", load().flavor.id)
    end)

    it("reads the X-Game field of LibNAddOn itself, not another field or addon", function()
      _G.C_AddOns = {
        GetAddOnMetadata = function(addon, field)
          if addon == "LibNAddOn" and field == "X-Family" then return "Camelot" end
          if addon == "SomeOtherAddOn" and field == "X-Game" then return "Camelot" end
        end,
      }
      assert.equals("retail", load().flavor.id)
    end)

    it("is Retail, without erroring, when neither signal exists", function()
      assert.is_nil(_G.WOW_PROJECT_ID)
      assert.is_nil(_G.C_AddOns)
      local ns = load()
      assert.equals("retail", ns.flavor.id)
      assert.is_true(ns.flavor.isRetail)
    end)

    it("is Retail, without erroring, when C_AddOns lacks GetAddOnMetadata", function()
      _G.C_AddOns = {}
      assert.equals("retail", load().flavor.id)
    end)

    it("is Retail when the metadata is unset (nil)", function()
      stubXGame(nil)
      assert.equals("retail", load().flavor.id)
    end)
  end)

  describe("Supports", function()
    local function forever() _G.WOW_PROJECT_CAMELOT, _G.WOW_PROJECT_ID = 18, 18; return load() end
    local function retail() _G.WOW_PROJECT_CAMELOT, _G.WOW_PROJECT_ID = 18, 1; return load() end

    it("reports the systems Forever lacks as unsupported there", function()
      local ns = forever()
      for _, feature in ipairs({
        "specializations", "housing", "delves", "mythicPlus", "encounterJournal",
        "travelersLog", "garrison", "legion", "greatVault", "warbandBank",
      }) do
        assert.is_false(ns.Supports(feature), feature)
      end
    end)

    it("supports every one of those systems on Retail", function()
      local ns = retail()
      for _, feature in ipairs({
        "specializations", "housing", "delves", "mythicPlus", "encounterJournal",
        "travelersLog", "garrison", "legion", "greatVault", "warbandBank",
      }) do
        assert.is_true(ns.Supports(feature), feature)
      end
    end)

    it("supports a feature that isn't in the table on either flavor", function()
      assert.is_true(forever().Supports("transmog"))
      assert.is_true(retail().Supports("transmog"))
    end)

    it("follows the metadata-detected flavor too", function()
      stubXGame("Camelot")
      assert.is_false(load().Supports("housing"))
    end)
  end)

  describe("linkFlavor", function()
    it("gives an addon the shared flavor and a working :Supports", function()
      _G.WOW_PROJECT_CAMELOT, _G.WOW_PROJECT_ID = 18, 18
      local ns = load()
      local addOn = {}
      ns.linkFlavor(addOn)
      assert.equals(ns.flavor, addOn.flavor)
      assert.is_true(addOn.flavor.isForever)
      assert.is_false(addOn:Supports("housing"))
      assert.is_true(addOn:Supports("transmog"))
    end)

    it("answers :Supports as Retail on a Retail client", function()
      _G.WOW_PROJECT_CAMELOT, _G.WOW_PROJECT_ID = 18, 1
      local ns = load()
      local addOn = {}
      ns.linkFlavor(addOn)
      assert.is_true(addOn.flavor.isRetail)
      assert.is_true(addOn:Supports("housing"))
    end)
  end)

  describe("/lib flavor", function()
    local registered, printed, ns

    before_each(function()
      registered, printed = {}, {}
      ns = {
        registerCommand = function(self, cmd, subcmd, handler, description)
          registered[cmd] = { self = self, subcmd = subcmd, handler = handler, description = description }
        end,
        Print = function(msg) printed[#printed + 1] = msg end,
      }
    end)

    it("registers a 'flavor' command on the namespace", function()
      load(ns)
      assert.is_table(registered.flavor)
      assert.equals(ns, registered.flavor.self)
      assert.is_function(registered.flavor.handler)
      assert.is_string(registered.flavor.description)
    end)

    it("prints the Forever flavor and the signals behind it", function()
      _G.WOW_PROJECT_CAMELOT, _G.WOW_PROJECT_ID = 18, 18
      stubXGame("Camelot")
      load(ns)
      registered.flavor.handler(ns, "")
      assert.same({ "flavor: forever (WOW_PROJECT_ID 18, WOW_PROJECT_CAMELOT 18, X-Game Camelot)" }, printed)
    end)

    it("prints the Retail flavor, showing missing signals as nil", function()
      load(ns)
      registered.flavor.handler(ns, "")
      assert.same({ "flavor: retail (WOW_PROJECT_ID nil, WOW_PROJECT_CAMELOT nil, X-Game nil)" }, printed)
    end)

    it("is skipped quietly when the namespace has no command registry", function()
      assert.has_no.errors(function() load({}) end)
    end)
  end)
end)

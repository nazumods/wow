-- cvar.lua isn't part of the libn.lua harness (it touches the GetCVar/SetCVar
-- globals), so this spec loads it standalone against a fake CVar store + a minimal
-- fake addon, then drives the temporary-CVar helpers.

describe("LibNAddOn CVar helpers", function()
  local addOn, store

  before_each(function()
    store = { OutlineEngineMode = "0", Foo = "bar" }
    _G.GetCVar = function(k) return store[k] end
    _G.SetCVar = function(k, v) store[k] = tostring(v) end

    local ns = {}
    assert(loadfile("LibNAddOn/cvar.lua"))("LibNAddOn", ns)

    -- Minimal addon: registerEvent just stashes the handler so the spec can fire it.
    addOn = {
      _events = {},
      registerEvent = function(self, name, handler) self._events[name] = handler end,
    }
    ns.linkCVarHelpers(addOn)
  end)

  it("sets the CVar and backs up the original", function()
    addOn:SetTemporaryCVar("OutlineEngineMode", 1)
    assert.equals("1", store.OutlineEngineMode)
    assert.equals("0", addOn._cvarBackup.OutlineEngineMode)
  end)

  it("restores the original value", function()
    addOn:SetTemporaryCVar("OutlineEngineMode", 1)
    addOn:RestoreCVar("OutlineEngineMode")
    assert.equals("0", store.OutlineEngineMode)
    assert.is_nil(addOn._cvarBackup.OutlineEngineMode)
  end)

  it("backs up only once, so a repeated set keeps the true original", function()
    addOn:SetTemporaryCVar("OutlineEngineMode", 1)
    addOn:SetTemporaryCVar("OutlineEngineMode", 2)  -- must not record "1" as the original
    addOn:RestoreCVar("OutlineEngineMode")
    assert.equals("0", store.OutlineEngineMode)
  end)

  it("arms a PLAYER_LOGOUT restore on first override", function()
    assert.is_nil(addOn._events.PLAYER_LOGOUT)
    addOn:SetTemporaryCVar("OutlineEngineMode", 1)
    assert.is_function(addOn._events.PLAYER_LOGOUT)
  end)

  it("restores every override on logout", function()
    addOn:SetTemporaryCVar("OutlineEngineMode", 1)
    addOn:SetTemporaryCVar("Foo", "baz")
    addOn._events.PLAYER_LOGOUT(addOn)   -- simulate the logout event
    assert.equals("0", store.OutlineEngineMode)
    assert.equals("bar", store.Foo)
  end)

  it("RestoreCVar is a no-op for a CVar we never set", function()
    addOn:RestoreCVar("Unknown")
    assert.is_nil(store.Unknown)
  end)

  it("doesn't write back a CVar whose original was unset", function()
    addOn:SetTemporaryCVar("Brand new", "x")   -- GetCVar → nil → backed up as false
    assert.equals(false, addOn._cvarBackup["Brand new"])
    addOn:RestoreCVar("Brand new")             -- must not SetCVar(nil)
    assert.equals("x", store["Brand new"])     -- left as-is, backup cleared
    assert.is_nil(addOn._cvarBackup["Brand new"])
  end)

  describe("enforce mode", function()
    it("arms a CVAR_UPDATE handler only when enforce is set", function()
      addOn:SetTemporaryCVar("OutlineEngineMode", 1)          -- plain: no enforcement
      assert.is_nil(addOn._events.CVAR_UPDATE)
      addOn:SetTemporaryCVar("OutlineEngineMode", 1, true)    -- enforce
      assert.is_function(addOn._events.CVAR_UPDATE)
    end)

    it("re-asserts the forced value when it drifts", function()
      addOn:SetTemporaryCVar("OutlineEngineMode", 1, true)
      store.OutlineEngineMode = "0"                            -- user/other code changes it
      addOn._events.CVAR_UPDATE(addOn)                         -- simulate the CVAR_UPDATE
      assert.equals("1", store.OutlineEngineMode)              -- forced back
    end)

    it("leaves non-enforced overrides alone on CVAR_UPDATE", function()
      addOn:SetTemporaryCVar("OutlineEngineMode", 1, true)     -- arms the handler
      addOn:SetTemporaryCVar("Foo", "baz")                     -- plain override
      store.Foo = "changed"                                    -- user changes the plain one
      addOn._events.CVAR_UPDATE(addOn)
      assert.equals("changed", store.Foo)                      -- not re-asserted
    end)

    it("stops enforcing once the CVar is restored", function()
      addOn:SetTemporaryCVar("OutlineEngineMode", 1, true)
      addOn:RestoreCVar("OutlineEngineMode")
      assert.is_nil(addOn._cvarEnforce.OutlineEngineMode)
      store.OutlineEngineMode = "0"
      addOn._events.CVAR_UPDATE(addOn)
      assert.equals("0", store.OutlineEngineMode)              -- left as the user set it
    end)

    it("doesn't re-assert when the value already matches", function()
      addOn:SetTemporaryCVar("OutlineEngineMode", 1, true)
      local writes = 0
      local realSet = _G.SetCVar
      _G.SetCVar = function(k, v) writes = writes + 1; realSet(k, v) end
      addOn._events.CVAR_UPDATE(addOn)                         -- value is already "1"
      _G.SetCVar = realSet
      assert.equals(0, writes)                                 -- no redundant write / no loop
    end)
  end)
end)

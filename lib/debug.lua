-- Developer-only in-game harness. Every engine interaction here goes through a
-- public Mod API surface: content registries, mod.ui, mod.world, and built-in
-- script commands read from the public commands registry.

local Debug = {}

local DEBUG_TEXT = "TEXT_DSCRETE_DEBUG"
local DEBUG_COMMAND = "dscrete_items:debug"

local WARPS = {
  { key="pallet", label="PALLET TOWN", mapId="PALLET_TOWN", x=10, y=10, facing="down" },
  { key="forest", label="VIRIDIAN FOREST", mapId="VIRIDIAN_FOREST", x=16, y=46, facing="up" },
  { key="rock", label="ROCK TUNNEL", mapId="ROCK_TUNNEL_1F", x=15, y=4, facing="down" },
  { key="safari", label="SAFARI ZONE", mapId="SAFARI_ZONE_CENTER", x=14, y=24, facing="up" },
  { key="silph", label="SILPH CO.", mapId="SILPH_CO_1F", x=10, y=16, facing="up" },
  { key="cinnabar", label="CINNABAR ISLAND", mapId="CINNABAR_ISLAND", x=11, y=10, facing="down" },
}

local function commandFn(mod, id)
  local value = mod.content.commands:get(id)
  if type(value) == "table" then value = value.fn end
  assert(type(value) == "function", "missing public command: " .. id)
  return value
end

local function itemKeys(Items)
  local out = {}
  for _, item in ipairs(Items.all) do out[#out + 1] = item.key end
  return out
end

function Debug.install(mod, Items, runtime, diagnostics)
  if not mod.developer then return end
  diagnostics=diagnostics or {}

  local giveItem = commandFn(mod, "give_item")
  local takeItem = commandFn(mod, "take_item")
  local showText = commandFn(mod, "show_text")

  local function choose(ctx, title, rows)
    local picked, finished = nil, false
    local runner = ctx.runner
    local menu
    local function finish(value)
      if finished then return end
      finished = true
      picked = value
      if menu then menu:close() end
      runner:resume()
    end
    menu = mod.ui.ListMenu.new(ctx.game, title, rows, {
      pageJump = true,
      onChoose = function(item) finish(item.value) end,
      onCancel = function() finish(nil) end,
    })
    ctx.game.stack:push(menu)
    runner:yield()
    return picked
  end

  local function grantMenu(ctx)
    local action = choose(ctx, "GET ITEMS", {
      { label="PRISM SCENT", value="prism" },
      { label="ELUSIVE SCENT", value="elusive" },
      { label="MYSTERY LURE", value="mystery" },
      { label="PKMN WHISTLE", value="whistle" },
      { label="PROTO RESONATOR", value="resonator" },
      { label="SAFARI KIT", value="safari" },
      { label="GLITCH DET.", value="glitch" },
      { label="ALL IMPLEMENTED", value="all" },
      { label="UNLOCK GADGETS", value="unlock" },
      { label="REMOVE TEST ITEMS", value="remove" },
      { label="BACK", value="back" },
    })
    if action == "prism" then
      giveItem(ctx, Items.byKey.prism_scent.itemId, 1)
    elseif action == "elusive" then
      giveItem(ctx, Items.byKey.elusive_scent.itemId, 1)
    elseif action == "mystery" then
      giveItem(ctx, Items.byKey.mystery_lure.itemId, 1)
    elseif action == "whistle" then
      giveItem(ctx, Items.byKey.species_whistle.itemId, 1)
    elseif action == "resonator" then
      giveItem(ctx, Items.byKey.prototype_resonator.itemId, 1)
    elseif action == "safari" then
      giveItem(ctx, Items.byKey.safari_kit.itemId, 1)
    elseif action == "glitch" then
      giveItem(ctx, Items.byKey.glitch_detector.itemId, 1)
    elseif action == "all" then
      for _, item in ipairs(Items.consumables(true)) do
        local stop = giveItem(ctx, item.itemId, 1, false)
        if stop == math.huge then break end
      end
      showText(ctx, "Implemented test items\nwere added.")
    elseif action == "unlock" then
      for _, item in ipairs(Items.permanent(true)) do runtime:unlock(item.key) end
      showText(ctx, "Implemented gadgets\nwere unlocked.")
    elseif action == "remove" then
      for _, item in ipairs(Items.consumables(true)) do takeItem(ctx, item.itemId, 99) end
      showText(ctx, "Implemented test items\nwere removed.")
    end
  end

  local function warpMenu(ctx)
    local rows = {}
    for _, dest in ipairs(WARPS) do rows[#rows + 1] = { label=dest.label, value=dest.key } end
    rows[#rows + 1] = { label="RETURN", value="return" }
    rows[#rows + 1] = { label="BACK", value="back" }
    local key = choose(ctx, "DEBUG WARP", rows)
    if not key or key == "back" then return false end
    local dest
    if key == "return" then
      dest = runtime.debugReturn
      if not dest then showText(ctx, "No debug return\npoint is stored.") return false end
      runtime.debugReturn = nil
    else
      for _, row in ipairs(WARPS) do if row.key == key then dest = row break end end
      if not runtime.debugReturn then runtime.debugReturn = mod.world:current() end
    end
    if not dest then return false end
    local ok, err = mod.world:warpTo(dest.mapId, dest.x, dest.y, dest.facing)
    if not ok then showText(ctx, "Warp failed:\n" .. tostring(err)) return false end
    return true
  end

  local function inspect(ctx)
    local permanent = {}
    for _, item in ipairs(Items.permanent(true)) do permanent[#permanent + 1] = item.key end
    local state = runtime:snapshot(permanent)
    local unlocked = #state.unlocked > 0 and table.concat(state.unlocked, ", ") or "none"
    local effect = state.activeFieldEffect or "none"
    local selected = runtime:getReusableState("species_whistle_target", nil) or state.selectedSpecies or "none"
    -- Safari Kit session state is persisted under the catalogue key itself.
    local safari = runtime:getReusableState("safari_kit", nil) or "none"
    local exp = state.pendingExpMultiplier or "none"

    local treasureBand,treasureDistance,treasureSound,treasureLast="n/a","n/a","n/a","n/a"
    local treasure=diagnostics.treasure
    if treasure and type(treasure.reading)=="function" then
      local ok,band,d=pcall(treasure.reading)
      if ok and type(band)=="table" then
        treasureBand=tostring(band.name or "?")
        treasureDistance=d~=nil and tostring(d) or "none"
      end
      if type(treasure.lastSoundStatus)=="function" then
        local sok,s=pcall(treasure.lastSoundStatus)
        if sok then treasureSound=tostring(s) end
      end
      if type(treasure.lastTriggerBand)=="function" then
        local bok,b=pcall(treasure.lastTriggerBand)
        if bok then treasureLast=tostring(b) end
      end
    end

    local glitchTiles=0
    local glitch=diagnostics.glitch
    if glitch and type(glitch.tiles)=="function" then
      local ok,tiles=pcall(glitch.tiles)
      if ok and type(tiles)=="table" then glitchTiles=#tiles end
    end

    local text = ("DScrete v%s\nSAVE SCHEMA %s\fEFFECT %s\nSTEPS %d\nSPECIES %s\fSAFARI %s\nEXP MOD %s\fTREASURE %s\nDIST %s\nLAST %s\nSOUND %s\fGLITCH TILES %d\nPRISM %d/%d\fUNLOCKED:\n%s")
      :format(tostring(mod.version), tostring(state.schemaVersion), tostring(effect),
        tonumber(state.remainingSteps) or 0, tostring(selected), tostring(safari), tostring(exp),
        treasureBand,treasureDistance,treasureLast,treasureSound,glitchTiles,
        tonumber(state.debugSuccesses) or 0, tonumber(state.debugRolls) or 0, unlocked)
    showText(ctx, text)
  end

  local function resetMenu(ctx)
    local action = choose(ctx, "RESET", {
      { label="ACTIVE EFFECT", value="effect" },
      { label="RUNTIME STATE", value="runtime" },
      { label="DSCRETE SAVE", value="save" },
      { label="TEST INVENTORY", value="inventory" },
      { label="PERMANENT UNLOCKS", value="unlocks" },
      { label="DEBUG TELEMETRY", value="telemetry" },
      { label="BACK", value="back" },
    })
    if action == "effect" then runtime:clearFieldEffect()
    elseif action == "runtime" then runtime:resetRuntime()
    elseif action == "save" then runtime:resetPersistent(itemKeys(Items))
    elseif action == "inventory" then for _, item in ipairs(Items.consumables(true)) do takeItem(ctx, item.itemId, 99) end
    elseif action == "unlocks" then for _, item in ipairs(Items.permanent(true)) do runtime:lock(item.key) end
    elseif action == "telemetry" then runtime.debugRolls, runtime.debugSuccesses = 0, 0
    else return end
    showText(ctx, "DScrete state reset.")
  end

  mod.content.commands:register(DEBUG_COMMAND, {
    foreground = true,
    fn = function(ctx)
      while true do
        local action = choose(ctx, "DSCRETE DEBUG", {
          { label="GET ITEMS", value="items" },
          { label="WARP", value="warp" },
          { label="INSPECT", value="inspect" },
          { label="RESET", value="reset" },
          { label="CANCEL", value="cancel" },
        })
        if action == "items" then grantMenu(ctx)
        elseif action == "warp" then if warpMenu(ctx) then return end
        elseif action == "inspect" then inspect(ctx)
        elseif action == "reset" then resetMenu(ctx)
        else return end
      end
    end,
  })

  mod.content.maps:patch("PALLET_TOWN", {
    objects = { __append = {
      { index=4, name="DSCRETE_DEBUG_NPC", sprite="SPRITE_OAK",
        movement="STAY", range="NONE", text=DEBUG_TEXT, x=9, y=10 },
    } },
  })
  mod.content.map_scripts:register("PALLET_TOWN", { talk = { [DEBUG_TEXT] = { { DEBUG_COMMAND } } } })
end

return Debug

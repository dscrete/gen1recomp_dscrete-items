-- Player-facing permanent gadget menu. The Start menu row appears once at
-- least one DScrete permanent/reusable gadget has been unlocked.

local Gadgets = {}

function Gadgets.install(mod, Items, runtime, handlers)
  handlers = handlers or {}

  local function unlockedItems()
    local out = {}
    for _, item in ipairs(Items.permanent()) do
      if runtime:isUnlocked(item.key) then out[#out + 1] = item end
    end
    return out
  end

  local function open(game)
    local rows = {}
    for _, item in ipairs(unlockedItems()) do
      rows[#rows + 1] = { label=item.name, value=item.key }
    end
    rows[#rows + 1] = { label="CANCEL", value="cancel" }

    local menu
    menu = mod.ui.ListMenu.new(game, "GADGETS", rows, {
      pageJump=true,
      onChoose=function(row)
        local key = row and row.value
        if menu then menu:close() end
        if not key or key == "cancel" then return end
        local fn = handlers[key]
        if type(fn) == "function" then fn(game) end
      end,
      onCancel=function()
        if menu then menu:close() end
      end,
    })
    game.stack:push(menu)
  end

  -- v0.2.5 already exposes ui.start_menu.items specifically so mods can add
  -- rows without patching engine UI code.
  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    local out = next(game, items)
    if type(out) ~= "table" then out = items end
    if #unlockedItems() == 0 then return out end

    local row = { label="GADGETS", onSelect=function() open(game) end }
    local inserted = false
    for i, item in ipairs(out) do
      if item.label == "OPTION" then
        table.insert(out, i, row)
        inserted = true
        break
      end
    end
    if not inserted then out[#out + 1] = row end
    return out
  end)

  Gadgets.open = open
  Gadgets.unlockedItems = unlockedItems
  return Gadgets
end

return Gadgets

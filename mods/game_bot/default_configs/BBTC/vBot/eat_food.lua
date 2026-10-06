setDefaultTab("HP")

-- mantém o mesmo bloco do seu arquivo, apenas saneando a união por ID numérico
if voc() ~= 1 and voc() ~= 11 then
    if storage.foodItems then
        local t = {}
        for i, v in pairs(storage.foodItems) do
            local id = (type(v) == "table" and tonumber(v.id)) or tonumber(v)
            if id and not table.find(t, id) then
                table.insert(t, id)
            end
        end
        local foodItems = { 3607, 3585, 3592, 3600, 3601 }
        for i, item in pairs(foodItems) do
            if not table.find(t, item) then
                table.insert(storage.foodItems, item)
            end
        end
    end
    -- Cast Food preservado como no original
    macro(500, "Cast Food", function()
        if player:getRegenerationTime() <= 400 then
            cast("exevo pan", 5000)
        end
    end)
end

UI.Label("Eatable items:")
if type(storage.foodItems) ~= "table" then
  storage.foodItems = {3582, 3577}
end

local foodContainer = UI.Container(function(widget, items)
  -- preserva a UI original; só guardamos como veio
  storage.foodItems = items
end, true)
foodContainer:setHeight(100)
foodContainer:setItems(storage.foodItems)

-- ===== Helpers leves para comer com BP fechada =====
local lastBackOpenAttempt = 0

local function _toId(v)
  if type(v) == "number" then return v end
  if type(v) == "string" then return tonumber(v) end
  if type(v) == "table" then
    if v.id ~= nil then return tonumber(v.id) end
    if v.getId and type(v.getId) == "function" then
      local ok, iid = pcall(function() return v:getId() end)
      if ok and type(iid) == "number" then return iid end
    end
  end
  return nil
end

local function _normalizeFoodIds(list)
  local out, seen = {}, {}
  if type(list) ~= "table" then return out end
  for _, v in ipairs(list) do
    local id = _toId(v)
    if id and id > 0 and not seen[id] then
      table.insert(out, id)
      seen[id] = true
    end
  end
  return out
end

local function _isMainBackpackOpen()
  local back = getBack()
  if not back then return false end
  for _, cont in pairs(g_game.getContainers() or {}) do
    local citem = cont.getContainerItem and cont:getContainerItem() or nil
    if citem and citem:getId() == back:getId() then
      return true
    end
  end
  return false
end

local function _tryOpenMainBackpack()
  if now - lastBackOpenAttempt < 3000 then return end -- sem flood
  lastBackOpenAttempt = now
  local back = getBack()
  if back then g_game.use(back) end
end

local function _safeFindPlayerItem(id)
  id = _toId(id)
  if not id or id <= 0 then return nil end
  if type(g_game.findPlayerItem) ~= "function" then return nil end
  return g_game.findPlayerItem(id, -1)
end

-- ===== Macro original (15s), com lógica de comer melhorada e leve =====
macro(15000, "Eat Food", function()
  if player:getRegenerationTime() > 400 or not storage.foodItems[1] then return end

  -- converte a lista atual para IDs numéricos (aceita {id=...} e números)
  local foodIds = _normalizeFoodIds(storage.foodItems)
  if #foodIds == 0 then return end

  -- 1) tentativa rápida: encontrar diretamente por ID (funciona mesmo com BP fechada, em clientes que suportam)
  for _, fid in ipairs(foodIds) do
    local it = _safeFindPlayerItem(fid)
    if it then
      g_game.use(it)
      return
    end
  end

  -- 2) se a BP principal estiver fechada, abre 1x e volta no próximo ciclo
  if not _isMainBackpackOpen() then
    _tryOpenMainBackpack()
    return
  end

  -- 3) fallback: varre apenas containers ABERTOS (como no seu original)
  for _, container in pairs(g_game.getContainers()) do
    for __, item in ipairs(container:getItems()) do
      local iid = item:getId()
      for i, cfg in ipairs(foodIds) do
        if iid == cfg then
          return g_game.use(item)
        end
      end
    end
  end
end)

UI.Separator()

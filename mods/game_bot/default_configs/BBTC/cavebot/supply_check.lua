CaveBot.Extensions.SupplyCheck = {}

local supplyRetries = 0
local missedChecks = 0
local rawRound = 0
local time = now
vBot.CaveBotData =
  vBot.CaveBotData or
  {
    refills = 0,
    rounds = 0,
    time = {},
    lastRefill = os.time(),
    refillTime = {}
  }

local function setCaveBotData(hunting)
  if hunting then
    supplyRetries = supplyRetries + 1
  else
    supplyRetries = 0
    table.insert(vBot.CaveBotData.refillTime, os.difftime(os.time() - vBot.CaveBotData.lastRefill))
    vBot.CaveBotData.lastRefill = os.time()
    vBot.CaveBotData.refills = vBot.CaveBotData.refills + 1
  end

  table.insert(vBot.CaveBotData.time, rawRound)
  vBot.CaveBotData.rounds = vBot.CaveBotData.rounds + 1
  missedChecks = 0
end

-- Função para obter configurações do perfil ativo
local function getActiveSupplyConfig()
  -- Verificar se SuppliesConfig existe
  if not SuppliesConfig then
    print("CaveBot[SupplyCheck]: SuppliesConfig not found, using fallback method")
    return nil
  end
  
  -- Obter perfil ativo
  local activeProfile = SuppliesConfig.currentSupplyProfile or 1
  if activeProfile < 1 or activeProfile > 5 then
    activeProfile = 1
  end
  
  -- Obter configuração do perfil ativo
  local panelName = "supplies"
  if SuppliesConfig[panelName] and SuppliesConfig[panelName][activeProfile] then
    return SuppliesConfig[panelName][activeProfile]
  end
  
  return nil
end

-- Função para verificar supplies baseada no perfil ativo
local function checkActiveProfileSupplies()
  local config = getActiveSupplyConfig()
  
  if not config then
    -- Fallback para método antigo se não conseguir acessar as configurações
    print("CaveBot[SupplyCheck]: Using fallback supply check")
    return Supplies.hasEnough()
  end
  
  -- Verificar cada item do perfil ativo
  for itemId, itemData in pairs(config.items) do
    local id = tonumber(itemId)
    local minimum = itemData.min or 0
    local current = player:getItemsCount(id) or 0
    
    if current < minimum then
      return {id = id, amount = current, required = minimum}
    end
  end
  
  return true
end

-- Função para obter dados adicionais do perfil ativo
local function getActiveProfileAdditionalData()
  local config = getActiveSupplyConfig()
  
  if not config then
    -- Fallback para método antigo
    if Supplies and Supplies.getAdditionalData then
      return Supplies.getAdditionalData()
    else
      return {
        stamina = {enabled = false, value = 0},
        capacity = {enabled = false, value = 0},
        softBoots = {enabled = false},
        imbues = {enabled = false}
      }
    end
  end
  
  -- Retornar dados do perfil ativo
  return {
    stamina = {enabled = config.staminaSwitch or false, value = config.staminaValue or 0},
    capacity = {enabled = config.capSwitch or false, value = config.capValue or 0},
    softBoots = {enabled = config.SoftBoots or false},
    imbues = {enabled = config.imbues or false}
  }
end

CaveBot.Extensions.SupplyCheck.setup = function()
  CaveBot.registerAction(
    "supplyCheck",
    "#db5a5a",
    function(value)
      local data = string.split(value, ",")
      local round = 0
      rawRound = 0
      local label = data[1]:trim()
      local pos = nil
      if #data == 4 then
        pos = {x = tonumber(data[2]), y = tonumber(data[3]), z = tonumber(data[4])}
      end

      -- Configuração de checagem de posição (pode ser desabilitada)
      local CHECK_POSITION = false  -- Mude para true se quiser verificar posição
      local MAX_DISTANCE = 15       -- Distância máxima permitida (aumentada de 10 para 15)
      
      if pos and CHECK_POSITION then
        local currentDistance = getDistanceBetween(player:getPosition(), pos)
        if missedChecks >= 4 then
          missedChecks = 0
          supplyRetries = 0
          if ENABLE_DETAILED_LOGS then
            print("CaveBot[SupplyCheck]: Missed 5 supply checks, proceeding with waypoints")
          end
          return true
        end
        if currentDistance > MAX_DISTANCE then
          missedChecks = missedChecks + 1
          if ENABLE_DETAILED_LOGS then
            print("CaveBot[SupplyCheck]: Missed supply check! Distance: " .. currentDistance .. "/" .. MAX_DISTANCE .. ". " .. (5 - missedChecks) .. " tries left.")
          end
          return CaveBot.gotoLabel(label)
        end
      end

      if time then
        rawRound = math.ceil((now - time) / 1000)
        round = rawRound .. "s"
      else
        round = ""
      end
      time = now

      -- Obter informações do perfil ativo (apenas se logs detalhados estiverem habilitados)
      local profileInfo = ""
      if ENABLE_DETAILED_LOGS then
        local config = getActiveSupplyConfig()
        if config and config.name then
          profileInfo = " [Profile: " .. config.name .. "]"
        elseif SuppliesConfig and SuppliesConfig.currentSupplyProfile then
          local defaultNames = {"EK", "MS", "ED", "RP", "MK"}
          profileInfo = " [Profile: " .. defaultNames[SuppliesConfig.currentSupplyProfile] .. "]"
        end
      end

      local softCount = itemAmount(6529) + itemAmount(3549)
      local supplyData = checkActiveProfileSupplies()
      local supplyInfo = getActiveProfileAdditionalData()

      if storage.caveBot.forceRefill then
        print("CaveBot[SupplyCheck]: User forced, going back on refill. Last round took: " .. round .. profileInfo)
        storage.caveBot.forceRefill = false
        supplyRetries = 0
        missedChecks = 0
        return false
      elseif storage.caveBot.backStop then
        print("CaveBot[SupplyCheck]: User forced, going back to city and turning off CaveBot. Last round took: " .. round .. profileInfo)
        supplyRetries = 0
        missedChecks = 0
        return false
      elseif storage.caveBot.backTrainers then
        print("CaveBot[SupplyCheck]: User forced, going back to city, then on trainers. Last round took: " .. round .. profileInfo)
        supplyRetries = 0
        missedChecks = 0
        return false
      elseif storage.caveBot.backOffline then
        print("CaveBot[SupplyCheck]: User forced, going back to city, then on offline training. Last round took: " .. round .. profileInfo)
        supplyRetries = 0
        missedChecks = 0
        return false
      -- Removido: limite artificial de rodadas (huntRoutes)
      -- O bot agora só vai refilar quando realmente precisar de supplies
      elseif (supplyInfo.imbues.enabled and player:getSkillLevel(11) == 0) then
        print("CaveBot[SupplyCheck]: Imbues ran out. Going on refill. Last round took: " .. round .. profileInfo)
        setCaveBotData()
        return false
      elseif (supplyInfo.stamina.enabled and stamina() < tonumber(supplyInfo.stamina.value)) then
        print("CaveBot[SupplyCheck]: Stamina ran out (" .. stamina() .. "/" .. supplyInfo.stamina.value .. "). Going on refill. Last round took: " .. round .. profileInfo)
        setCaveBotData()
        return false
      elseif (supplyInfo.softBoots.enabled and softCount < 1) then
        print("CaveBot[SupplyCheck]: No soft boots left. Going on refill. Last round took: " .. round .. profileInfo)
        setCaveBotData()
        return false
      elseif type(supplyData) == "table" then
        local requiredText = ""
        if supplyData.required then
          requiredText = ", required: " .. supplyData.required
        end
        print("CaveBot[SupplyCheck]: Not enough item: " .. supplyData.id .. " (only " .. supplyData.amount .. " left" .. requiredText .. "). Going on refill. Last round took: " .. round .. profileInfo)
        setCaveBotData()
        return false
      elseif (supplyInfo.capacity.enabled and freecap() < tonumber(supplyInfo.capacity.value)) then
        print("CaveBot[SupplyCheck]: Not enough capacity (" .. freecap() .. "/" .. supplyInfo.capacity.value .. "). Going on refill. Last round took: " .. round .. profileInfo)
        setCaveBotData()
        return false
      else
        -- print("CaveBot[SupplyCheck]: Enough supplies. Hunting. Round (" .. supplyRetries .. "). Last round took: " .. round .. profileInfo)
        setCaveBotData(true)
        return CaveBot.gotoLabel(label)
      end
    end
  )

  CaveBot.Editor.registerAction(
    "supplycheck",
    "supply check",
    {
      value = function()
        return "startHunt," .. posx() .. "," .. posy() .. "," .. posz()
      end,
      title = "Supply check label",
      description = "Insert here hunting start label",
      validation = [[[^,]+,\d{1,5},\d{1,5},\d{1,2}$]]
    }
  )
end
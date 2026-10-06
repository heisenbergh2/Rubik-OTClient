setDefaultTab("Cave")
local panelName = "supplies"

-- Verificar se SuppliesConfig existe (pode ser carregado pelo configs.lua)
if not SuppliesConfig then
  SuppliesConfig = {}
end

-- Inicializar estrutura de configuração com 5 perfis
if not SuppliesConfig[panelName] then
  SuppliesConfig[panelName] = {}
end

-- Garantir que existam 5 perfis
local defaultNames = {"EK", "MS", "ED", "RP", "MK"}
for i = 1, 5 do
  if not SuppliesConfig[panelName][i] then
    SuppliesConfig[panelName][i] = {
      items = {},
      capSwitch = false,
      SoftBoots = false,
      imbues = false,
      staminaSwitch = false,
      capValue = 0,
      staminaValue = 0,
      name = defaultNames[i]
    }
  end
end

-- Inicializar currentSupplyProfile se não existir
if not SuppliesConfig.currentSupplyProfile or SuppliesConfig.currentSupplyProfile == 0 or SuppliesConfig.currentSupplyProfile > 5 then 
  SuppliesConfig.currentSupplyProfile = 1
end

-- Migrar configuração antiga se existir
if SuppliesConfig[panelName].currentProfile or SuppliesConfig[panelName].item1 then
  local oldConfig = SuppliesConfig[panelName]
  
  -- Salvar configuração antiga no perfil 1
  if oldConfig.Default or oldConfig.item1 then
    local configToMigrate = oldConfig.Default or oldConfig
    
    local function convertOldConfig(config)
      if config and config.items then
        return config
      end -- config is new

      local newConfig = {
        items = {},
        capSwitch = config.capSwitch,
        SoftBoots = config.SoftBoots,
        imbues = config.imbues,
        staminaSwitch = config.staminaSwitch,
        capValue = config.capValue,
        staminaValue = config.staminaValue
      }

      local items = {
        config.item1,
        config.item2,
        config.item3,
        config.item4,
        config.item5,
        config.item6
      }
      local mins = {
        config.item1Min,
        config.item2Min,
        config.item3Min,
        config.item4Min,
        config.item5Min,
        config.item6Min
      }
      local maxes = {
        config.item1Max,
        config.item2Max,
        config.item3Max,
        config.item4Max,
        config.item5Max,
        config.item6Max
      }

      for i, item in ipairs(items) do
        if item and item > 100 then
          local min = mins[i]
          local max = maxes[i]
          newConfig.items[tostring(item)] = {
            min = min,
            max = max,
            avg = 0
          }
        end
      end

      return newConfig
    end
    
    SuppliesConfig[panelName][1] = convertOldConfig(configToMigrate)
  end
  
  -- Limpar estrutura antiga
  SuppliesConfig[panelName].currentProfile = nil
  SuppliesConfig[panelName].Default = nil
  SuppliesConfig[panelName].item1 = nil
  SuppliesConfig[panelName].item2 = nil
  SuppliesConfig[panelName].item3 = nil
  SuppliesConfig[panelName].item4 = nil
  SuppliesConfig[panelName].item5 = nil
  SuppliesConfig[panelName].item6 = nil
end

-- Função para definir perfil ativo
local currentSettings
local function setActiveProfile()
  local n = SuppliesConfig.currentSupplyProfile
  currentSettings = SuppliesConfig[panelName][n]
end
setActiveProfile()

-- Salvar configuração (usar função segura)
local function safeSave()
  if vBotConfigSave then
    vBotConfigSave("supply")
  end
end
safeSave()

function getEmptyItemPanels()
  local panel = SuppliesWindow.items
  local count = 0

  for i, child in ipairs(panel:getChildren()) do
    count = child:getId() == "blank" and count + 1 or count
  end

  return count
end

function deleteFirstEmptyPanel()
  local panel = SuppliesWindow.items

  for i, child in ipairs(panel:getChildren()) do
    if child:getId() == "blank" then
      child:destroy()
      break
    end
  end
end

function clearEmptyPanels()
  local panel = SuppliesWindow.items

  if panel:getChildCount() > 1 then
    if getEmptyItemPanels() > 1 then
      deleteFirstEmptyPanel()
    end
  end
end

function addItemPanel()
  local parent = SuppliesWindow.items
  local childs = parent:getChildCount()
  local panel = UI.createWidget("ItemPanel", parent)
  local item = panel.id
  local min = panel.min
  local max = panel.max
  local avg = panel.avg

  panel:setId("blank")
  item:setShowCount(false)

  item.onItemChange = function(widget)
    local id = widget:getItemId()
    local panelId = panel:getId()

    -- empty, verify
    if id < 100 then
      currentSettings.items[panelId] = nil
      panel:setId("blank")
      clearEmptyPanels() -- clear empty panels if any
      return
    end

    -- itemId was not changed, ignore
    if tonumber(panelId) == id then
      return
    end

    -- check if isnt already added
    if currentSettings.items[tostring(id)] then
      warn("vBot[Supply]: Item already added!")
      widget:setItemId(0)
      return
    end

    -- new item id
    currentSettings.items[tostring(id)] = currentSettings.items[tostring(id)] or {} -- min, max, avg
    panel:setId(id)
    addItemPanel() -- add new panel
  end

  return panel
end

SuppliesWindow = UI.createWindow("SuppliesWindow")
SuppliesWindow:hide()

UI.Button(
  "Supply Settings",
  function()
    SuppliesWindow:setVisible(not SuppliesWindow:isVisible())
  end
)

-- load settings
local function loadSettings()
  -- panels
  SuppliesWindow.items:destroyChildren()

  for id, data in pairs(currentSettings.items) do
    local widget = addItemPanel()
    widget:setId(id)
    widget.id:setItemId(tonumber(id))
    widget.min:setText(data.min)
    widget.max:setText(data.max)
    widget.avg:setText(data.avg)
  end
  addItemPanel() -- add empty panel

  -- switches and values
  SuppliesWindow.capSwitch:setOn(currentSettings.capSwitch)
  SuppliesWindow.SoftBoots:setOn(currentSettings.SoftBoots)
  SuppliesWindow.imbues:setOn(currentSettings.imbues)
  SuppliesWindow.staminaSwitch:setOn(currentSettings.staminaSwitch)
  SuppliesWindow.capValue:setText(currentSettings.capValue or 0)
  SuppliesWindow.staminaValue:setText(currentSettings.staminaValue or 0)
  
  -- Atualizar nome do perfil
  local defaultNames = {"EK", "MS", "ED", "RP", "MK"}
  local profileName = currentSettings.name or defaultNames[SuppliesConfig.currentSupplyProfile]
  SuppliesWindow.profileName:setText(profileName)
end

-- Função para atualizar cores dos botões
local function activeProfileColor()
  for i=1,5 do
    if i == SuppliesConfig.currentSupplyProfile then
      SuppliesWindow[tostring(i)]:setColor("green")
    else
      SuppliesWindow[tostring(i)]:setColor("white")
    end
  end
end

-- Função para mudança de perfil
local function profileChange()
  setActiveProfile()
  activeProfileColor()
  loadSettings()
  safeSave()
end

-- Configurar botões de perfil (1-5)
for i=1,5 do
  SuppliesWindow[tostring(i)].onClick = function()
    SuppliesConfig.currentSupplyProfile = i
    profileChange()
  end
end

-- Configurar edição do nome do perfil
SuppliesWindow.profileName.onDoubleClick = function(widget)
  local window = modules.client_textedit.show(
    widget,
    {title = "Set Profile Name", description = "Enter a new name for selected profile"}
  )
  schedule(50, function()
    window:raise()
    window:focus()
  end)
end

SuppliesWindow.profileName.onTextChange = function(widget, text)
  currentSettings.name = text
  safeSave()
end

loadSettings()
activeProfileColor()

-- save settings
SuppliesWindow.onVisibilityChange = function(widget, visible)
  if not visible then
    currentSettings.items = {}
    local parent = SuppliesWindow.items

    -- items
    for i, panel in ipairs(parent:getChildren()) do
      if panel.id:getItemId() > 100 then
        local id = tostring(panel.id:getItemId())
        local min = panel.min:getValue()
        local max = panel.max:getValue()
        local avg = panel.avg:getValue()

        currentSettings.items[id] = {
          min = min,
          max = max,
          avg = avg
        }
      end
    end

    safeSave()
  end
end

SuppliesWindow.capSwitch.onClick = function(widget)
  currentSettings.capSwitch = not currentSettings.capSwitch
  widget:setOn(currentSettings.capSwitch)
end

SuppliesWindow.SoftBoots.onClick = function(widget)
  currentSettings.SoftBoots = not currentSettings.SoftBoots
  widget:setOn(currentSettings.SoftBoots)
end

SuppliesWindow.imbues.onClick = function(widget)
  currentSettings.imbues = not currentSettings.imbues
  widget:setOn(currentSettings.imbues)
end

SuppliesWindow.staminaSwitch.onClick = function(widget)
  currentSettings.staminaSwitch = not currentSettings.staminaSwitch
  widget:setOn(currentSettings.staminaSwitch)
end

SuppliesWindow.capValue.onTextChange = function(widget, text)
  local value = tonumber(SuppliesWindow.capValue:getText())
  if not value then
    SuppliesWindow.capValue:setText(0)
    currentSettings.capValue = 0
  else
    text = text:match("0*(%d+)")
    currentSettings.capValue = text
  end
end

SuppliesWindow.staminaValue.onTextChange = function(widget, text)
  local value = tonumber(SuppliesWindow.staminaValue:getText())
  if not value then
    SuppliesWindow.staminaValue:setText(0)
    currentSettings.staminaValue = 0
  else
    text = text:match("0*(%d+)")
    currentSettings.staminaValue = text
  end
end

SuppliesWindow.increment.onClick = function(widget)
  for i, panel in ipairs(SuppliesWindow.items:getChildren()) do
    if panel.id:getItemId() > 100 then
      local max = panel.max:getValue()
      local avg = panel.avg:getValue()

      if avg > 0 then
        panel.max:setText(max + avg)
      end
    end
  end
end

SuppliesWindow.decrement.onClick = function(widget)
  for i, panel in ipairs(SuppliesWindow.items:getChildren()) do
    if panel.id:getItemId() > 100 then
      local max = panel.max:getValue()
      local avg = panel.avg:getValue()

      if avg > 0 then
        panel.max:setText(math.max(0, max - avg)) -- dont go below 0
      end
    end
  end
end

SuppliesWindow.increment.onMouseWheel = function(widget, mousePos, dir)
  if dir == 1 then
    SuppliesWindow.increment.onClick()
  elseif dir == 2 then
    SuppliesWindow.decrement.onClick()
  end
end

SuppliesWindow.decrement.onMouseWheel = SuppliesWindow.increment.onMouseWheel

-- Sistema de auto-profile por vocação
local function checkVocationProfile()
  local player = g_game.getLocalPlayer()
  if player then
    local vocation = player:getVocation()
    local targetProfile = 1 -- padrão
    
    if vocation == 1 or vocation == 11 then      -- Knight/Elite Knight
      targetProfile = 1
    elseif vocation == 3 or vocation == 13 then  -- Sorcerer/Master Sorcerer
      targetProfile = 2
    elseif vocation == 4 or vocation == 14 then  -- Druid/Elder Druid
      targetProfile = 3
    elseif vocation == 2 or vocation == 12 then  -- Paladin/Royal Paladin
      targetProfile = 4
    elseif vocation == 5 or vocation == 15 then  -- Monk/Exalted Monk
      targetProfile = 5
    end
    
    -- Verificar se auto profile está ativado
    local settings = g_settings.getNode('bot') or {}
    if settings.vocationConfig and settings.vocationConfig.enabled then
      if SuppliesConfig.currentSupplyProfile ~= targetProfile then
        -- IMPORTANTE: Sincronizar profile global ANTES de mudar o interno
        if modules and modules.client_options and modules.client_options.setOption then
          modules.client_options.setOption('profile', targetProfile)
        end
        
        SuppliesConfig.currentSupplyProfile = targetProfile
        profileChange()
        print("[Supplies] Profile alterado para: " .. targetProfile)
      end
    end
  end
end

-- Executar verificação de vocação após 3 segundos
schedule(3000, function() checkVocationProfile() end)

Supplies = {} -- public functions
Supplies.show = function()
  SuppliesWindow:show()
  SuppliesWindow:raise()
  SuppliesWindow:focus()
end

Supplies.getItemsData = function()
  local t = {}
  -- items
  for i, panel in ipairs(SuppliesWindow.items:getChildren()) do
    if panel.id:getItemId() > 100 then
      local id = tostring(panel.id:getItemId())
      local min = panel.min:getValue()
      local max = panel.max:getValue()
      local avg = panel.avg:getValue()

      t[id] = {
        min = min,
        max = max,
        avg = avg
      }
    end
  end

  return t
end

Supplies.isSupplyItem = function(id)
  local data = Supplies.getItemsData()
  id = tostring(id)

  if data[id] then
    return data[id]
  else
    return false
  end
end

Supplies.hasEnough = function()
  local data = Supplies.getItemsData()

  for id, values in pairs(data) do
    id = tonumber(id)
    local minimum = values.min
    local current = player:getItemsCount(id) or 0

    if current < minimum then
      return {id=id, amount=current}
    end
  end

  return true
end

hasSupplies = Supplies.hasEnough

Supplies.setAverageValues = function(data)
  for id, amount in pairs(data) do
    local widget = SuppliesWindow.items[id]

    if widget then
      widget.avg:setText(amount)
    end
  end
end

Supplies.addSupplyItem = function(id, min, max, avg)
  if not id then
    return
  end

  local widget = addItemPanel()
  widget:setId(id)
  widget.id:setItemId(tonumber(id))
  widget.min:setText(min or 0)
  widget.max:setText(max or 0)
  widget.avg:setText(avg or 0)
end

Supplies.getAdditionalData = function()
  local data = {
    stamina = {enabled = currentSettings.staminaSwitch, value = currentSettings.staminaValue},
    capacity = {enabled = currentSettings.capSwitch, value = currentSettings.capValue},
    softBoots = {enabled = currentSettings.SoftBoots},
    imbues = {enabled = currentSettings.imbues}
  }
  return data
end

Supplies.getFullData = function()
  local data = {
    items = Supplies.getItemsData(),
    additional = Supplies.getAdditionalData()
  }

  return data
end

-- Funções públicas para controle de perfil
Supplies.getActiveProfile = function()
  return SuppliesConfig.currentSupplyProfile -- returns number 1-5
end

Supplies.setActiveProfile = function(n)
  if not n or not tonumber(n) or n < 1 or n > 5 then
    local errorMsg = "[Supplies] wrong profile parameter! should be 1 to 5 is " .. tostring(n)
    if g_logger then
      g_logger.error(errorMsg)
    else
      print(errorMsg)
    end
    return false
  else
    SuppliesConfig.currentSupplyProfile = n
    profileChange()
    return true
  end
end


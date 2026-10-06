-- Auto Equipper by HP / MP %
-- Interface amigável com lógica avançada de regras independentes
-- CORRIGIDO: Lógica de desequipar igual ao script original

-- CONFIGURAÇÕES DE PERFORMANCE CRÍTICA
local MACRO_INTERVAL = 50    -- 50ms para máxima responsividade
local RULE_COOLDOWN = 250    -- cooldown por regra
local SLOT_COOLDOWN = 150    -- cooldown por slot

local stName = "AutoEquipV2"
if not storage[stName] or type(storage[stName]) ~= "table" then
  storage[stName] = {
    enabled = false,
    sPanels = 6,
    sHeight = 610,
    sIcon = true,
    sIPX = 200,
    sIPY = 270,
    sTab = "Main",
    sHotkey = "End",
    sPz = true,
    items = {}
  }
end
local config = storage[stName]
setDefaultTab(config.sTab)
UI.Label("Hotkey: "..config.sHotkey):setFont('verdana-11px-rounded')

-- ===== SISTEMA DE REGRAS INDEPENDENTES (CORRIGIDO) =====
local ruleCD = {}  -- cooldown por regra (ms)
local slotCD = {}  -- cooldown por slot (ms)

-- helpers
local function clamp(n,a,b) if n<a then return a elseif n>b then return b else return n end end

local function hpPct()
  return player:getHealthPercent()
end

local function mpPct()
  return math.min(100, math.floor(100 * (player:getMana() / player:getMaxMana())))
end

-- encontra backpack principal
local function findMainBackpack()
  local bad = { "store","inbox","stash","reward","depot","mail","market","supply" }
  for _, cont in pairs(g_game.getContainers()) do
    local name = (cont.getName and cont:getName() or ""):lower()
    local skip=false
    for __,k in ipairs(bad) do if name:find(k,1,true) then skip=true break end end
    if not skip then return cont end
  end
  local containers = g_game.getContainers()
  if #containers > 0 then return containers[1] end
  return nil
end

-- equipar item
local function equipFromContainers(itemId, slot)
  if not itemId or itemId<=0 or not slot or slot<=0 then return false end
  local s=getSlot(slot); if s and s:getId()==itemId then return false end
  for _, cont in pairs(g_game.getContainers()) do
    local name=(cont.getName and cont:getName() or ""):lower()
    if not (name:find("store",1,true) or name:find("inbox",1,true)) then
      for __, it in ipairs(cont:getItems()) do
        if it:getId()==itemId then
          g_game.move(it,{x=65535,y=slot,z=0},it:getCount())
          return true
        end
      end
    end
  end
  return false
end

-- desequipar item
local function unequipToMainBackpack(slot)
  if not slot or slot<=0 then return false end
  local it=getSlot(slot); if not it then return false end
  local cont=findMainBackpack(); if not cont then return false end
  local dest=(cont.getSlotPosition and cont:getSlotPosition()) or (cont.getPosition and cont:getPosition()) or cont
  g_game.move(it, dest, it:getCount())
  return true
end

-- precisa agir?
local function needAction(slot, targetId)
  local s=getSlot(slot)
  if targetId < 0 then return false end
  if targetId == 0 then return s ~= nil end
  return (not s) or s:getId() ~= targetId
end

-- SISTEMA DE CANDIDATOS (SEM REGRA PZ - MOVIDA PARA O MACRO)
local function getAllCandidates(hpP, mpP)
  local candidates = {}

  for i, entry in ipairs(config.items) do
    if not (entry.on and (entry.slot or 0) > 0) then
      goto nextItem
    end

    local slot = entry.slot
    local HPmin = entry.HP.min
    local HPmax = entry.HP.max
    local MPmin = entry.MP.min
    local MPmax = entry.MP.max
    
    -- REGRA 1: Equipar item1 quando dentro da faixa (se configurado) - OR logic
    local ruleId1 = i * 10 + 1
    if ((hpP >= HPmin and hpP <= HPmax) or (mpP >= MPmin and mpP <= MPmax)) and now >= (ruleCD[ruleId1] or 0) then
      if entry.item1 > 0 and needAction(slot, entry.item1) then
        table.insert(candidates, {
          ruleId = ruleId1,
          configIdx = i,
          slot = slot,
          target = entry.item1,
          priority = 2,
          desc = string.format("Item%d: equip item1 %d (HP:%d%% MP:%d%%)", 
            i, entry.item1, hpP, mpP)
        })
      end
    end

    -- REGRA 2: Ação quando FORA da faixa (se unequip ativado) - OR logic
    local ruleId2 = i * 10 + 2
    if entry.unequip and now >= (ruleCD[ruleId2] or 0) then
      if not ((hpP >= HPmin and hpP <= HPmax) or (mpP >= MPmin and mpP <= MPmax)) then
        local target
        local priority
        
        -- Lógica correta: item2 configurado = trocar, item2 vazio = desequipar
        if entry.item2 > 0 then
          -- Item2 configurado: equipar item2 (trocar)
          target = entry.item2
          priority = 2
        else
          -- Item2 vazio: desequipar completamente
          target = 0
          priority = 3
        end
        
        if needAction(slot, target) then
          table.insert(candidates, {
            ruleId = ruleId2,
            configIdx = i,
            slot = slot,
            target = target,
            priority = priority,
            desc = string.format("Item%d: %s (HP:%d%% MP:%d%% fora da faixa)", 
              i, target == 0 and "unequip (item2 empty)" or "switch to item2 "..target, hpP, mpP)
          })
        end
      end
    end

    ::nextItem::
  end

  return candidates
end

-- aplica ação
local function applyAction(slot, targetId)
  if targetId == 0 then
    return unequipToMainBackpack(slot)
  else
    return equipFromContainers(targetId, slot)
  end
end

-- Bot Panel
local ui = setupUI([[
Panel
  height: 19

  BotSwitch
    id: main
    anchors.top: parent.top
    anchors.left: parent.left
    text-align: center
    width: 130
    !text: tr('Auto Equipper')
    font: verdana-11px-rounded

  Button
    id: edit
    anchors.top: prev.top
    anchors.left: prev.right
    anchors.right: parent.right
    margin-left: 3
    height: 17
    text: Setup
    font: verdana-11px-rounded

]])

-- Main Window
g_ui.loadUIFromString([[
AE_MainWindow < MainWindow
  !text: tr('Auto Equipper HP/MP %% - Advanced Rules System (Fixed)')
  size: 400 350
  @onEscape: self:hide()

  VerticalScrollBar
    id: contentScroll
    anchors.top: parent.top
    margin-top: 3
    anchors.right: parent.right
    anchors.bottom: separator.top
    step: 28
    pixels-scroll: true
    margin-right: -10
    margin-top: 5
    margin-bottom: 5

  ScrollablePanel
    id: content
    anchors.top: prev.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: separator.top
    vertical-scrollbar: contentScroll
    margin-bottom: 10
    
    Panel
      id: left
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.horizontalCenter
      margin-top: 5
      margin-left: 10
      margin-right: 10
      layout:
        type: verticalBox
        fit-children: true

    Panel
      id: right
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.left: parent.horizontalCenter
      margin-top: 5
      margin-left: 10
      margin-right: 10
      layout:
        type: verticalBox
        fit-children: true

    VerticalSeparator
      anchors.top: parent.top
      anchors.bottom: prev.bottom
      anchors.left: parent.horizontalCenter

  HorizontalSeparator
    id: separator
    anchors.right: parent.right
    anchors.left: parent.left
    anchors.bottom: closeButton.top
    margin-bottom: 8    

  Button
    id: closeButton
    !text: tr('Close')
    font: cipsoftFont
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    size: 45 21
    margin-top: 15
    margin-right: 5
    font: verdana-11px-rounded
    
  Button
    id: info
    text: Logic Fixed
    font: cipsoftFont
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    size: 80 21
    color: green
    font: verdana-11px-rounded
    !tooltip: tr('Equip/Unequip logic now matches original behavior')

  Button
    id: settings
    !text: tr('Settings')
    anchors.left: info.right
    margin-left: 5 
    size: 65 21
    font: verdana-11px-rounded  
    anchors.verticalCenter: info.verticalCenter

  BotSwitch
    id: sPz
    !text: tr('Stop In PZ')
    anchors.left: settings.right
    margin-left: 5 
    size: 70 20
    font: verdana-11px-rounded  
    anchors.top: settings.top 
    margin-top: 1

DualScroll < Panel
  height: 29
  margin-top: 3
    
  Label
    id: title
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    text-align: center
    
  HorizontalScrollBar
    id: scroll1
    anchors.left: title.left
    anchors.right: title.horizontalCenter
    anchors.top: title.bottom
    margin-right: 2
    margin-top: 2
    minimum: 0
    maximum: 100
    step: 1
    &disableScroll: true
    
  HorizontalScrollBar
    id: scroll2
    anchors.left: title.horizontalCenter
    anchors.right: title.right
    anchors.top: prev.top
    margin-left: 2
    minimum: 0
    maximum: 100
    step: 1
    &disableScroll: true

TwoItems < Panel
  height: 35
  margin-top: 4
      
  BotItem
    id: item1
    anchors.left: parent.left
    anchors.top: parent.top
    margin-top: 1

  BotItem
    id: item2
    anchors.left: prev.right
    anchors.top: prev.top
    margin-left: 1
    
  SmallBotSwitch
    id: title
    anchors.left: prev.right
    anchors.top: prev.top
    text-align: center
    width: 45
    margin-left: 2
    margin-top: 0
    tooltip: equip this item if under these conditions

  SmallBotSwitch
    id: title2
    anchors.left: prev.right
    anchors.right: parent.right
    anchors.top: prev.top
    text-align: center
    width: 55
    margin-left: 2
    margin-top: 0
    tooltip: unequip this item if out of these conditions

  SlotComboBox
    id: slot
    anchors.left: item2.right
    anchors.right: prev.right
    anchors.top: prev.bottom
    anchors.bottom: item2.bottom
    margin-top: 2
    margin-bottom: 1
    margin-left: 2
    &disableScroll: true
]])

-- Settings Window
g_ui.loadUIFromString([[
AES_CheckBox < CheckBox
  anchors.left: parent.left
  anchors.right: parent.right
  anchors.top: prev.bottom
  margin-top: 6

AES_Sep < HorizontalSeparator
  anchors.right: parent.right
  anchors.left: parent.left
  anchors.top: prev.bottom
  margin-top: 6

AE_SettingsWindow < MainWindow
  text: Auto Equipper Settings
  size: 230 280
  @onEscape: self:hide()

  Label
    !text: tr('Advanced Rules System Settings')
    text-align: center
    text-wrap: true
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: 40

  AES_Sep    

  AES_CheckBox
    id: sIcon
    text: Create Icon / Icon Position:

  Label
    anchors.left: prev.left
    anchors.top: prev.bottom
    text-align: center
    margin-top: 5
    width: 40
    height: 20
    !text: ('Pos X: ')

  SpinBox
    id: sIPX
    anchors.left: prev.right
    anchors.top: prev.top
    anchors.bottom: prev.bottom
    minimum: 0
    maximum: 2000
    width: 50
    step: 10

  Label
    anchors.right: sIPY.left
    anchors.top: prev.top
    anchors.bottom: prev.bottom
    text-align: center
    width: 40
    !text: ('Pos Y: ')

  SpinBox
    id: sIPY
    anchors.right: parent.right
    anchors.top: sIPX.top
    anchors.bottom: sIPX.bottom
    minimum: 0
    maximum: 2000
    width: 50
    step: 10

  AES_Sep

  Label
    anchors.left: parent.left
    anchors.top: prev.bottom
    margin-top: 5
    height: 20
    text-align: center
    text: How Many Items Panels:

  SpinBox
    id: sPanels
    anchors.right: parent.right
    anchors.top: prev.top
    anchors.bottom: prev.bottom
    minimum: 2
    maximum: 20
    width: 50
    step: 2
    text-align: center

  AES_Sep

  Label
    anchors.left: parent.left
    anchors.top: prev.bottom
    margin-top: 5
    height: 20
    text-align: center
    text: Window Max Height:

  SpinBox
    id: sHeight
    anchors.right: parent.right
    anchors.top: prev.top
    anchors.bottom: prev.bottom
    minimum: 300
    maximum: 610
    step: 10
    width: 50
    text-align: center  

  AES_Sep

  Label
    anchors.left: parent.left
    anchors.top: prev.bottom
    margin-top: 5
    height: 20
    text-align: center
    text: Set Default Tab:

  BotTextEdit
    id: sTab
    width: 100
    anchors.right: parent.right
    anchors.top: prev.top
    anchors.bottom: prev.bottom
    editable: true
    focusable: true
    text-align: center

  AES_Sep

  Label
    anchors.left: parent.left
    anchors.top: prev.bottom
    margin-top: 5
    height: 20
    text-align: center
    text: Toggle Hotkey:

  BotTextEdit
    id: sHotkey
    width: 100
    anchors.right: parent.right
    anchors.top: prev.top
    anchors.bottom: prev.bottom
    editable: true
    focusable: true
    text-align: center  

  AES_Sep

  Button
    id: closeButton
    text: Close
    font: verdana-11px-rounded
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    size: 55 21
]])

-- Switch
ui.main:setOn(config.enabled)
ui.main.onClick = function(widget)
  config.enabled = not config.enabled
  broadcastMessage(config.enabled and "Auto-Equipper: ON" or "Auto-Equipper: OFF")
  widget:setOn(config.enabled)
end

-- Icon / Hotkey
if config.sIcon then
  local icon = addIcon("AutoEquipV2", {item = 3088, text="Auto\nEquip", hotkey=config.sHotkey, switchable=false}, 
  function(widget,isOn) ui.main.onClick(ui.main) end)
  macro(50,function()
    icon.text:setColor(config.enabled and "green" or "red")
    icon.item:setItemId(config.enabled and 3089 or 3100)
    ui.main:setOn(config.enabled)
  end)
  icon:setSize({height=60,width=40})
  icon:breakAnchors()
  icon:move(config.sIPX,config.sIPY)
  icon.hotkey:setText('')
  icon.text:setFont('verdana-11px-rounded')
else
  hotkey(config.sHotkey, function() 
    ui.main.onClick(ui.main)
  end)
end

-- UI Functions
rootWidget = g_ui.getRootWidget()
if rootWidget then
  AE_MainWindow = UI.createWindow('AE_MainWindow', rootWidget)
  AE_MainWindow:hide()
  AE_MainWindow.closeButton.onClick = function(widget)
    AE_MainWindow:hide()
  end

  AE_SettingsWindow = UI.createWindow('AE_SettingsWindow', rootWidget)
  AE_SettingsWindow:hide()
  AE_SettingsWindow.closeButton.onClick = function(widget)
    AE_SettingsWindow:hide()
  end

  ui.edit.onClick = function(widget)
    AE_MainWindow:show()
    AE_MainWindow:raise()
    AE_MainWindow:focus()
  end
  AE_MainWindow.settings.onClick = function(widget)
    AE_SettingsWindow:show()
    AE_SettingsWindow:raise()
    AE_SettingsWindow:focus()
  end

  -- Settings
  AE_SettingsWindow.sIcon:setChecked(config.sIcon)
  AE_SettingsWindow.sIcon.onClick = function(widget)
    config.sIcon = not config.sIcon
    widget:setChecked(config.sIcon)
  end

  AE_SettingsWindow.sIPX:setValue(config.sIPX)
  AE_SettingsWindow.sIPX:setStep(10)
  AE_SettingsWindow.sIPX.onValueChange = function(widget, value)
    config.sIPX = value
  end
  AE_SettingsWindow.sIPY:setValue(config.sIPY)
  AE_SettingsWindow.sIPY:setStep(10)
  AE_SettingsWindow.sIPY.onValueChange = function(widget, value)
    config.sIPY = value
  end
  AE_SettingsWindow.sPanels:setValue(config.sPanels)
  AE_SettingsWindow.sPanels:setStep(2)
  AE_SettingsWindow.sPanels.onValueChange = function(widget, value)
    config.sPanels = value
  end
  AE_SettingsWindow.sHeight:setValue(config.sHeight)
  AE_SettingsWindow.sHeight:setStep(10)
  AE_SettingsWindow.sHeight.onValueChange = function(widget, value)
    config.sHeight = value
  end

  AE_SettingsWindow.sTab:setText(config.sTab)
  AE_SettingsWindow.sTab.onTextChange = function(widget, text)
    config.sTab = text
  end
  AE_SettingsWindow.sHotkey:setText(config.sHotkey)
  AE_SettingsWindow.sHotkey.onTextChange = function(widget, text)
    config.sHotkey = text
  end

  AE_MainWindow.sPz:setOn(config.sPz)
  AE_MainWindow.sPz.onClick = function(widget)
    config.sPz = not config.sPz
    widget:setOn(config.sPz)
  end

  local maxH = (math.ceil(config.sPanels / 2)*133)+87
  AE_MainWindow:setHeight(maxH > config.sHeight and config.sHeight or maxH)

  UI.DualScroll = function(params, callback, parent)
    params.title = params.title or "title"
    params.min = params.min or 20
    params.max = params.max or 80
    
    local widget = UI.createWidget('DualScroll', parent)
    
    local update  = function(dontSignal)
      widget.title:setText("" .. params.min .. "% <= " .. params.title .. " <= " .. params.max .. "%")  
      if callback and not dontSignal then
        callback(widget, params)
      end
    end
    
    widget.scroll1:setValue(params.min)
    widget.scroll2:setValue(params.max)

    widget.scroll1.onValueChange = function(scroll, value)
      params.min = value
      update()
    end
    widget.scroll2.onValueChange = function(scroll, value)
      params.max = value
      update()
    end
    update(true)
  end

  UI.TwoItems = function(params, callback, parent)
    params.title = params.title or "title"
    params.title = params.title or "title2"
    params.item1 = params.item1 or 0
    params.item2 = params.item2 or 0
    params.slot = params.slot or 1
    
    local widget = UI.createWidget("TwoItems", parent)
      
    widget.title:setText(params.title)
    widget.title:setOn(params.on)
    widget.title.onClick = function()
      params.on = not params.on
      widget.title:setOn(params.on)
      if callback then
        callback(widget, params)
      end
    end

    widget.title2:setText(params.title2)
    widget.title2:setOn(params.unequip)
    widget.title2.onClick = function()
      params.unequip = not params.unequip
      widget.title2:setOn(params.unequip)
      if callback then
        callback(widget, params)
      end
    end
    
    widget.slot:setCurrentIndex(params.slot)
    widget.slot.onOptionChange = function()
      params.slot = widget.slot.currentIndex
      if callback then
        callback(widget, params)
      end
    end
    
    widget.item1:setItemId(params.item1)
    widget.item1.onItemChange = function()
      params.item1 = widget.item1:getItemId()
      if callback then
        callback(widget, params)
      end
    end

    widget.item2:setItemId(params.item2)
    widget.item2.onItemChange = function()
      params.item2 = widget.item2:getItemId()
      if callback then
        callback(widget, params)
      end
    end 
    
    return widget
  end

  for i=1,config.sPanels do
    local destUi = i % 2 == 0 and AE_MainWindow.content.right or AE_MainWindow.content.left
    if not config.items[i] then
      config.items[i] = {
        on = i == 1 and true or false, 
        title = "Equip", 
        item1 = i == 1 and 3052 or 0, 
        item2 = i == 1 and 3089 or 0, 
        slot = 1,
        unequip = i == 1 and true or false,
        title2 = "Unequip",
        HP = {      
          title="HP%",
          min=0,
          max=100},
        MP = {      
          title="MP%",
          min=0,
          max=i == 1 and 90 or 100},
      }
    end

    UI.Label("Item "..i,destUi)
    UI.TwoItems(config.items[i], function(widget, newParams)
      config.items[i] = newParams
    end,destUi)
    UI.DualScroll(config.items[i].HP, function(widget, newParams) 
      config.items[i].HP = newParams
    end,destUi)
    UI.DualScroll(config.items[i].MP, function(widget, newParams) 
      config.items[i].MP = newParams
    end,destUi)
    UI.Separator(destUi)
  end
end

-- ===== MACRO PRINCIPAL COM LÓGICA CORRIGIDA =====
macro(MACRO_INTERVAL, function()
  if not config.enabled then return end
  
  -- verifica se pelo menos um item está ativo
  local anyOn = false
  for i=1,config.sPanels do
    local entry = config.items[i]
    if entry and entry.on then anyOn=true break end
  end
  if not anyOn then return end

  -- STOP IN PZ: Se ativo e em PZ, só desequipa e para tudo
  if config.sPz and isInPz() then
    for i=1,config.sPanels do
      local entry = config.items[i]
      if entry and entry.on and (entry.slot or 0) > 0 then
        local slot = entry.slot
        local slotItem = getSlot(slot)
        -- Se tem item equipado que está configurado no script, remove
        if slotItem and (slotItem:getId() == entry.item1 or slotItem:getId() == entry.item2) then
          if (slotCD[slot] or 0) <= now then
            local ok = unequipToMainBackpack(slot)
            if ok then
              slotCD[slot] = now + SLOT_COOLDOWN
              return -- uma ação por ciclo
            end
          end
        end
      end
    end
    return -- em PZ, não processa mais nada
  end

  -- FORA DE PZ: Processa regras normais
  local hpP = hpPct()
  local mpP = mpPct()

  local allCandidates = getAllCandidates(hpP, mpP)
  if #allCandidates == 0 then return end

  -- agrupa por slot e filtra por cooldown do slot
  local bySlot = {}
  for _, cand in ipairs(allCandidates) do
    local slot = cand.slot
    if (slotCD[slot] or 0) <= now then
      if not bySlot[slot] then bySlot[slot] = {} end
      table.insert(bySlot[slot], cand)
    end
  end

  for slot, list in pairs(bySlot) do
    -- ordena por prioridade (desc) e por configIdx (asc)
    table.sort(list, function(a,b)
      if a.priority ~= b.priority then return a.priority > b.priority end
      return a.configIdx < b.configIdx
    end)

    local winner = list[1]
    local ok = applyAction(winner.slot, winner.target)
    if ok then
      ruleCD[winner.ruleId] = now + RULE_COOLDOWN
      slotCD[slot] = now + SLOT_COOLDOWN
      return -- uma acao por ciclo
    end
  end
end)

UI.Separator()
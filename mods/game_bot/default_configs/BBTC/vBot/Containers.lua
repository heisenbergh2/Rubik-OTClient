setDefaultTab("Tools")
local panelName = "renameContainers"

-- CONFIGURAÇÕES DE TIMING (EDITE AQUI)
local MOVE_DELAY = 300      -- Delay entre verificações de organização de itens (ms)
local OPEN_DELAY = 250       -- Delay entre abertura de containers (ms)
local INITIAL_DELAY = 500    -- Delay inicial após fechar containers (ms)
local BASE_DELAY = 200       -- Delay base antes de começar abertura sequencial (ms)

if type(storage[panelName]) ~= "table" then
    storage[panelName] = {
        enabled = false;
        height = 170,
        purse = true;
        list = {
            {
                value = "Main Backpack",
                enabled = true,
                item = 9601,
                min = false,
                items = { 3081, 3048 }
            },
            {
                value = "Runes",
                enabled = true,
                item = 2866,
                min = true,
                items = { 3161, 3180 }
            },
            {
                value = "Money",
                enabled = true,
                item = 2871,
                min = true,
                items = { 3031, 3035, 3043 }
            },
            {
                value = "Purse",
                enabled = true,
                item = 23396,
                min = true,
                items = {}
            },
        }
    }
end

local config = storage[panelName]

-- Função auxiliar para logs de debug
local function debugLog(message)
    if config.debugMode then
        print("[ContainerScript] " .. message)
    end
end

-- Função para verificar se o jogador está conectado
local function isPlayerConnected()
    return g_game.isOnline() and player ~= nil
end

UI.Separator()
local renameContui = setupUI([[
Panel
  height: 50

  Label
    text-align: center
    text: Container Panel
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    font: verdana-11px-rounded

  BotSwitch
    id: title
    anchors.top: prev.bottom
    anchors.left: parent.left
    text-align: center
    width: 130
    !text: tr('Open Minimised')
    font: verdana-11px-rounded

  Button
    id: editContList
    anchors.top: prev.top
    anchors.left: prev.right
    anchors.right: parent.right
    margin-left: 3
    height: 17
    text: Setup
    font: verdana-11px-rounded

  Button
    id: reopenCont
    !text: tr('Reopen All')
    anchors.left: parent.left
    anchors.top: prev.bottom
    anchors.right: parent.horizontalCenter
    margin-right: 2
    height: 17
    margin-top: 3
    font: verdana-11px-rounded

  Button
    id: minimiseCont
    !text: tr('Minimise All')
    anchors.top: prev.top
    anchors.left: parent.horizontalCenter
    anchors.right: parent.right
    margin-right: 2
    height: 17
    font: verdana-11px-rounded
  ]])
renameContui:setId(panelName)

g_ui.loadUIFromString([[
BackpackName < Label
  background-color: alpha
  text-offset: 18 2
  focusable: true
  height: 17
  font: verdana-11px-rounded

  CheckBox
    id: enabled
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: 15
    height: 15
    margin-top: 1
    margin-left: 3

  $focus:
    background-color: #00000055

  Button
    id: state
    !text: tr('M')
    anchors.right: remove.left
    anchors.verticalCenter: parent.verticalCenter
    margin-right: 1
    width: 15
    height: 15

  Button
    id: remove
    !text: tr('X')
    !tooltip: tr('Remove')
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    margin-right: 15
    width: 15
    height: 15

  Button
    id: openNext
    !text: tr('N')
    anchors.right: state.left
    anchors.verticalCenter: parent.verticalCenter
    margin-right: 1
    width: 15
    height: 15
    tooltip: Open container inside with the same ID.

ContListsWindow < MainWindow
  !text: tr('Container Names')
  size: 465 170
  @onEscape: self:hide()

  TextList
    id: itemList
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: separator.top
    width: 200
    margin-bottom: 6
    margin-top: 3
    margin-left: 3
    vertical-scrollbar: itemListScrollBar

  VerticalScrollBar
    id: itemListScrollBar
    anchors.top: itemList.top
    anchors.bottom: itemList.bottom
    anchors.right: itemList.right
    step: 14
    pixels-scroll: true

  VerticalSeparator
    id: sep
    anchors.top: parent.top
    anchors.left: itemList.right
    anchors.bottom: separator.top
    margin-top: 3
    margin-bottom: 6
    margin-left: 10

  Label
    id: lblName
    anchors.left: sep.right
    anchors.top: sep.top
    width: 70
    text: Name:
    margin-left: 10
    margin-top: 3
    font: verdana-11px-rounded

  TextEdit
    id: contName
    anchors.left: lblName.right
    anchors.top: sep.top
    anchors.right: parent.right
    font: verdana-11px-rounded

  Label
    id: lblCont
    anchors.left: lblName.left
    anchors.verticalCenter: contId.verticalCenter
    width: 70
    text: Container:
    font: verdana-11px-rounded

  BotItem
    id: contId
    anchors.left: contName.left
    anchors.top: contName.bottom
    margin-top: 3

  BotContainer
    id: sortList
    anchors.left: prev.left
    anchors.right: parent.right
    anchors.top: prev.bottom
    anchors.bottom: separator.top
    margin-bottom: 6
    margin-top: 3

  Label
    anchors.left: lblCont.left
    anchors.verticalCenter: sortList.verticalCenter
    width: 70
    text: Items: 
    font: verdana-11px-rounded

  Button
    id: addItem
    anchors.right: contName.right
    anchors.top: contName.bottom
    margin-top: 5
    text: Add
    width: 40
    font: cipsoftFont

  HorizontalSeparator
    id: separator
    anchors.right: parent.right
    anchors.left: parent.left
    anchors.bottom: closeButton.top
    margin-bottom: 8

  CheckBox
    id: purse
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    text: Open Purse
    tooltip: Opens Store/Charm Purse
    width: 85
    height: 15
    margin-top: 2
    margin-left: 3
    font: verdana-11px-rounded

  CheckBox
    id: sort
    anchors.left: prev.right
    anchors.bottom: parent.bottom
    text: Sort Items
    tooltip: Sort items based on items widget
    width: 85
    height: 15
    margin-top: 2
    margin-left: 15
    font: verdana-11px-rounded

  CheckBox
    id: forceOpen
    anchors.left: prev.right
    anchors.bottom: parent.bottom
    text: Keep Open
    tooltip: Will keep open containers all the time
    width: 85
    height: 15
    margin-top: 2
    margin-left: 15
    font: verdana-11px-rounded

  CheckBox
    id: lootBag
    anchors.left: prev.right
    anchors.bottom: parent.bottom
    text: Loot Bag
    tooltip: Open Loot Bag (gunzodus franchaise)
    width: 85
    height: 15
    margin-top: 2
    margin-left: 15
    font: verdana-11px-rounded

  CheckBox
    id: debugMode
    anchors.left: parent.left
    anchors.top: prev.top
    margin-top: -20
    text: Debug Mode
    tooltip: Show debug messages in console
    width: 85
    height: 15
    margin-left: 3
    font: verdana-11px-rounded

  Button
    id: closeButton
    !text: tr('Close')
    font: cipsoftFont
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    size: 45 21
    margin-top: 15

  ResizeBorder
    id: bottomResizeBorder
    anchors.fill: separator
    height: 3
    minimum: 170
    maximum: 245
    margin-left: 3
    margin-right: 3
    background: #ffffff88
]])

function findItemsInArray(t, tfind)
    local tArray = {}
    for x,v in pairs(t) do
        if type(v) == "table" then
            local aItem = t[x].item
            local aEnabled = t[x].enabled
                if aItem then
                    if tfind and aItem == tfind then
                        return x
                    elseif not tfind then
                        if aEnabled then
                            table.insert(tArray, aItem)
                        end
                    end
                end
            end
        end
    if not tfind then return tArray end
end

local lstBPs

-- Função melhorada para abrir containers com retry
local openContainer = function(id, maxRetries)
    maxRetries = maxRetries or 3
    
    local function attemptOpen(retries)
        if not isPlayerConnected() then
            debugLog("Player not connected, skipping container open")
            return false
        end
        
        local t = {getRight(), getLeft(), getAmmo()} -- if more slots needed then add them here
        for i=1,#t do
            local slotItem = t[i]
            if slotItem and slotItem:getId() == id then
                debugLog("Opening container from slot: " .. id)
                return g_game.open(slotItem, nil)
            end
        end

        for i, container in pairs(g_game.getContainers()) do
            for i, item in ipairs(container:getItems()) do
                if item:isContainer() and item:getId() == id then
                    debugLog("Opening container from container: " .. id)
                    return g_game.open(item, nil)
                end
            end
        end
        
        -- Retry se não encontrou e ainda tem tentativas
        if retries > 0 then
            debugLog("Retrying to open container " .. id .. " (attempts left: " .. retries .. ")")
            schedule(500, function()
                attemptOpen(retries - 1)
            end)
        else
            debugLog("Failed to open container " .. id .. " after " .. maxRetries .. " attempts")
        end
    end
    
    attemptOpen(maxRetries)
end

function reopenBackpacks()
    if not isPlayerConnected() then
        debugLog("Cannot reopen backpacks - player not connected")
        return
    end
    
    lstBPs = findItemsInArray(config.list)
    debugLog("Reopening " .. #lstBPs .. " configured containers")

    for _, container in pairs(g_game.getContainers()) do 
        g_game.close(container) 
    end
    
    bpItem = getBack()
    if bpItem ~= nil then
        g_game.open(bpItem)
    end

    schedule(INITIAL_DELAY, function()
        local delay = BASE_DELAY

        if config.purse then
            local item = getPurse()
            if item then
                debugLog("Opening purse")
                use(item)
            end
        end
        
        for i=1,#lstBPs do
            schedule(delay, function()
                openContainer(lstBPs[i])
            end)
            delay = delay + OPEN_DELAY
        end
    end)
end

rootWidget = g_ui.getRootWidget()
if rootWidget then
    contListWindow = UI.createWindow('ContListsWindow', rootWidget)
    contListWindow:hide()

    contListWindow.onGeometryChange = function(widget, old, new)
        if old.height == 0 then return end
        
        config.height = new.height
    end

    contListWindow:setHeight(250) -- Ajustado para altura original
    contListWindow:setWidth(550)

    renameContui.editContList.onClick = function(widget)
        contListWindow:show()
        contListWindow:raise()
        contListWindow:focus()
    end

    -- Configuração do SpinBox removida - agora usa constantes fixas do script

    renameContui.reopenCont.onClick = function(widget)
        reopenBackpacks()
    end

    renameContui.minimiseCont.onClick = function(widget)
        for i, container in ipairs(getContainers()) do
            local containerWindow = container.window
            if containerWindow then
                containerWindow:setContentHeight(34)
            end
        end
    end

    renameContui.title:setOn(config.enabled)
    renameContui.title.onClick = function(widget)
        config.enabled = not config.enabled
        widget:setOn(config.enabled)
    end

    contListWindow.closeButton.onClick = function(widget)
        contListWindow:hide()
    end

    contListWindow.purse.onClick = function(widget)
        config.purse = not config.purse
        contListWindow.purse:setChecked(config.purse)
    end
    contListWindow.purse:setChecked(config.purse)

    contListWindow.sort.onClick = function(widget)
        config.sort = not config.sort
        contListWindow.sort:setChecked(config.sort)
    end
    contListWindow.sort:setChecked(config.sort)

    contListWindow.forceOpen.onClick = function(widget)
        config.forceOpen = not config.forceOpen
        contListWindow.forceOpen:setChecked(config.forceOpen)
    end
    contListWindow.forceOpen:setChecked(config.forceOpen)
    
    contListWindow.lootBag.onClick = function(widget)
        config.lootBag = not config.lootBag
        contListWindow.lootBag:setChecked(config.lootBag)
    end
    contListWindow.lootBag:setChecked(config.lootBag)

    -- Novo: Debug Mode checkbox
    contListWindow.debugMode.onClick = function(widget)
        config.debugMode = not config.debugMode
        contListWindow.debugMode:setChecked(config.debugMode)
    end
    contListWindow.debugMode:setChecked(config.debugMode or false)

    local function refreshSortList(k, t)
        t = t or {}
        UI.Container(function()
            t = contListWindow.sortList:getItems()
            if k and config.list[k] then
                config.list[k].items = t
            end
            end, true, nil, contListWindow.sortList) 
        contListWindow.sortList:setItems(t)
    end
    refreshSortList(t)

    local refreshContNames = function(tFocus)
        local storageVal = config.list
        if storageVal and #storageVal > 0 then
            for i, child in pairs(contListWindow.itemList:getChildren()) do
                child:destroy()
            end
            for k, entry in pairs(storageVal) do
                local label = g_ui.createWidget("BackpackName", contListWindow.itemList)
                label.onMouseRelease = function()
                    contListWindow.contId:setItemId(entry.item)
                    contListWindow.contName:setText(entry.value)
                    if not entry.items then
                        entry.items = {}
                    end
                    contListWindow.sortList:setItems(entry.items)
                    refreshSortList(k, entry.items)
                end
                label.enabled.onClick = function(widget)
                    entry.enabled = not entry.enabled
                    label.enabled:setChecked(entry.enabled)
                    label.enabled:setTooltip(entry.enabled and 'Disable' or 'Enable')
                    label.enabled:setImageColor(entry.enabled and '#00FF00' or '#FF0000')
                end
                label.remove.onClick = function(widget)
                    table.removevalue(config.list, entry)
                    label:destroy()
                end
                label.state:setChecked(entry.min)
                label.state.onClick = function(widget)
                    entry.min = not entry.min
                    label.state:setChecked(entry.min)
                    label.state:setColor(entry.min and '#00FF00' or '#FF0000')
                    label.state:setTooltip(entry.min and 'Open Minimised' or 'Do not minimise')
                end
                label.openNext.onClick = function(widget)
                    entry.openNext = not entry.openNext
                    label.openNext:setChecked(entry.openNext)
                    label.openNext:setColor(entry.openNext and '#00FF00' or '#FF0000')
                end
                label:setText(entry.value)
                label.enabled:setChecked(entry.enabled)
                label.enabled:setTooltip(entry.enabled and 'Disable' or 'Enable')
                label.enabled:setImageColor(entry.enabled and '#00FF00' or '#FF0000')
                label.state:setColor(entry.min and '#00FF00' or '#FF0000')
                label.state:setTooltip(entry.min and 'Open Minimised' or 'Do not minimise')
                label.openNext:setColor(entry.openNext and '#00FF00' or '#FF0000')

                if tFocus and entry.item == tFocus then
                    tFocus = label
                end
            end
            if tFocus then contListWindow.itemList:focusChild(tFocus) end
        end
    end
    contListWindow.addItem.onClick = function(widget)
        local id = contListWindow.contId:getItemId()
        local trigger = contListWindow.contName:getText()

        if id > 100 and trigger:len() > 0 then
            local ifind = findItemsInArray(config.list, id)
            if ifind then
                config.list[ifind] = { item = id, value = trigger, enabled = config.list[ifind].enabled, min = config.list[ifind].min, items = config.list[ifind].items}
            else
                table.insert(config.list, { item = id, value = trigger, enabled = true, min = false, items = {} })
            end
            contListWindow.contId:setItemId(0)
            contListWindow.contName:setText('')
            contListWindow.contName:setColor('white')
            contListWindow.contName:setImageColor('#ffffff')
            contListWindow.contId:setImageColor('#ffffff')
            refreshContNames(id)
        else
            contListWindow.contId:setImageColor('red')
            contListWindow.contName:setImageColor('red')
            contListWindow.contName:setColor('red')
        end
    end
    refreshContNames()
end

-- Função corrigida para eventos de container
onContainerOpen(function(container, previousContainer)
    if not container.window then return end
    local containerWindow = container.window
    if not previousContainer then
        containerWindow:setContentHeight(34)
    end

    local storageVal = config.list
    if storageVal and #storageVal > 0 then
        for _, entry in pairs(storageVal) do
            -- CORRIGIDO: Comparação correta de IDs numéricos
            if entry.enabled and container:getContainerItem():getId() == entry.item then
                if entry.min then
                    containerWindow:minimize()
                end
                if renameContui.title:isOn() then
                    containerWindow:setText(entry.value)
                end
                if entry.openNext then
                    local currentDelay = 0
                    for i, item in ipairs(container:getItems()) do
                        if item:getId() == entry.item then
                            currentDelay = currentDelay + OPEN_DELAY
                            -- CORRIGIDO: Cada item tem seu próprio delay incrementado
                            schedule(currentDelay, function()
                                if isPlayerConnected() then
                                    g_game.open(item)
                                end
                            end)
                        end
                    end
                end
            end
        end
    end
end)

local function nameContainersOnLogin()
    if not isPlayerConnected() then return end
    
    for i, container in ipairs(getContainers()) do
        if renameContui.title:isOn() then
            if not container.window then return end
            local containerWindow = container.window
            local storageVal = config.list
            if storageVal and #storageVal > 0 then
                for _, entry in pairs(storageVal) do
                    -- CORRIGIDO: Comparação correta de IDs numéricos
                    if entry.enabled and container:getContainerItem():getId() == entry.item then
                        containerWindow:setText(entry.value)
                    end
                end
            end
        end
    end
end
nameContainersOnLogin()

-- Função melhorada para mover itens com retry
local function moveItem(item, destination)
    if not isPlayerConnected() or not item or not destination then
        return false
    end
    
    if containerIsFull(destination) then
        debugLog("Destination container is full, cannot move item: " .. item:getId())
        return false
    end
    
    debugLog("Moving item " .. item:getId() .. " to " .. destination:getName())
    return g_game.move(item, destination:getSlotPosition(destination:getItemsCount()), item:getCount())
end

local function properTable(t)
    local r = {}
    for _, entry in pairs(t) do
      if type(entry) == "number" then
        table.insert(r, entry)
      else
        table.insert(r, entry.id)
      end
    end
    return r
end

-- Função para criar o macro principal com delay configurável
local function createMainLoop()
    return macro(MOVE_DELAY, function(macro)
        if not config.sort and not config.purse and not config.forceOpen then 
            macro:setOff()
            return 
        end
        
        if not isPlayerConnected() then
            macro:setOff()
            return
        end

        local storageVal = config.list
        
        -- CORREÇÃO CRÍTICA: Limitar processamento para evitar lag durante caça
        local processedItems = 0
        local MAX_ITEMS_PER_CYCLE = 5 -- Processa no máximo 5 itens por ciclo
        
        for _, entry in pairs(storageVal) do
            if processedItems >= MAX_ITEMS_PER_CYCLE then
                break -- Para após processar limite de itens
            end
            
            local dId = entry.item
            local items = properTable(entry.items)
            
            -- sorting
            if config.sort and #items > 0 then
                for _, container in pairs(getContainers()) do
                    if processedItems >= MAX_ITEMS_PER_CYCLE then
                        break
                    end
                    
                    local cName = container:getName():lower()
                    -- CORRIGIDO: Removida condição duplicada
                    if not cName:find("depot") and not cName:find("store") and not cName:find("quiver") then
                        local cId = container:getContainerItem():getId()
                        for __, item in ipairs(container:getItems()) do
                            if processedItems >= MAX_ITEMS_PER_CYCLE then
                                break
                            end
                            
                            local id = item:getId()
                            if table.find(items, id) and cId ~= dId then
                                local destination = getContainerByItem(dId, true)
                                if destination and not containerIsFull(destination) then
                                    if moveItem(item, destination) then
                                        debugLog("Successfully moved item " .. id .. " to container " .. dId)
                                        processedItems = processedItems + 1
                                        macro:setOff()
                                        return
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            -- keep open / purse 23396
            if config.forceOpen then
                local container = getContainerByItem(dId)
                if not container then
                    local t = {getBack(), getAmmo(), getFinger(), getNeck(), getLeft(), getRight()}
                    for i=1,#t do
                        local slot = t[i]
                        if slot and slot:getId() == dId then
                            debugLog("Opening container from slot: " .. dId)
                            g_game.open(slot)
                            macro:setOff()
                            return
                        end
                    end
                    local cItem = findItem(dId)
                    if cItem then
                        debugLog("Opening container from inventory: " .. dId)
                        g_game.open(cItem)
                        macro:setOff()
                        return
                    end
                end
            end
        end
        
        if config.purse and config.forceOpen and not getContainerByItem(23396) then
            local purse = getPurse()
            if purse then
                debugLog("Opening purse")
                use(purse)
                macro:setOff()
                return
            end
        end
        
        if config.lootBag and config.forceOpen and not getContainerByItem(23721) then
            if findItem(23721) then
                debugLog("Opening loot bag")
                g_game.open(findItem(23721), getContainerByItem(23396))
            else
                local purse = getPurse()
                if purse then
                    use(purse)
                end
            end
            macro:setOff()
            return
        end
        macro:setOff()
    end)
end

-- Inicializa o macro principal
local mainLoop = createMainLoop()

onContainerOpen(function(container, previousContainer)
    if mainLoop then
        mainLoop:setOn()
    end
end)
  
onAddItem(function(container, slot, item, oldItem)
    if mainLoop then
        mainLoop:setOn()
    end
end)

onPlayerInventoryChange(function(slot, item, oldItem)
    if mainLoop then
        mainLoop:setOn()
    end
end)

onContainerClose(function(container)
    if not container.lootContainer and mainLoop then
        mainLoop:setOn()
    end
end)
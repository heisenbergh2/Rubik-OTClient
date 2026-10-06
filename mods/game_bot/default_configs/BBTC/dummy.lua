-- ========================================================================
-- SCRIPT DUMMY INTELIGENTE - Versão 2.3 (LIMPO - SEM LOGS)
-- Versão final sem logs/debugs no console
-- ========================================================================

addSeparator()
setDefaultTab("Suport")

local panelName = "Dummy Train Smart"
local ui = setupUI([[
Panel
  height: 50

  BotItem
    id: item
    anchors.top: parent.top
    anchors.left: parent.left

  BotItem
    id: Target
    anchors.top: parent.top
    anchors.right: parent.right
    margin-left: 2

  BotSwitch
    id: title
    anchors.top: Target.top
    anchors.left: item.right
    anchors.right: parent.right
    anchors.bottom: Target.bottom
    text-align: center
    !text: tr('Dummy Smart')
    margin-top: 4
    margin-left: 6
    margin-right: 40

  Label
    id: status
    anchors.top: title.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    text-align: center
    text: Status: Desligado
    font: verdana-11px-antialised
    color: #888888
    margin-top: 2

]], parent)
ui:setId(panelName)

-- Configurações padrão
if not storage[panelName] then
  storage[panelName] = {
      id = 28557,        -- Item de exercício (ex: varinha)
      id2 = 28559,       -- Dummy alvo
      enabled = false    -- Estado do macro
  }
end

-- =========================[ VARIÁVEIS DE CONTROLE ]======================
local isCurrentlyTraining = false  -- Estado de treinamento
local lastClickTime = 0            -- Timestamp do último clique
local trainingStartTime = 0        -- Quando começou a treinar
local lastTrainingMessage = 0      -- Última mensagem de treino recebida
local lastPlayerPosition = nil     -- Última posição do jogador
local searchCooldown = 0           -- Cooldown entre buscas por dummy
local CLICK_COOLDOWN = 3000        -- 3 segundos entre cliques no dummy
local TRAINING_TIMEOUT = 10000     -- 10 segundos sem mensagem = parou de treinar

-- =========================[ FUNÇÕES AUXILIARES ]==========================

local function updateStatus(text, color)
    ui.status:setText("Status: " .. text)
    ui.status:setColor(color or "#888888")
end

local function playerMoved()
    -- Verifica se o jogador se moveu desde a última verificação
    local currentPos = player:getPosition()
    if not currentPos then return false end
    
    if not lastPlayerPosition then
        lastPlayerPosition = currentPos
        return false
    end
    
    local moved = (currentPos.x ~= lastPlayerPosition.x or 
                   currentPos.y ~= lastPlayerPosition.y or 
                   currentPos.z ~= lastPlayerPosition.z)
    
    lastPlayerPosition = currentPos
    return moved
end

local function stopTraining(reason)
    -- Para o treinamento e atualiza status
    if isCurrentlyTraining then
        isCurrentlyTraining = false
        updateStatus("Treino parou", "#FFAA00")
    end
end

local function checkTrainingStatus()
    -- Verifica se o treinamento deve continuar
    if not isCurrentlyTraining then return end
    
    -- Verificar se o jogador se moveu
    if playerMoved() then
        stopTraining("movimento")
        return
    end
    
    -- Verificar timeout (sem mensagem de treino há muito tempo)
    if now - lastTrainingMessage > TRAINING_TIMEOUT then
        stopTraining("timeout")
        return
    end
    
    -- Se chegou aqui, ainda está treinando
    local trainingTime = math.floor((now - trainingStartTime) / 1000)
    updateStatus("Treinando (" .. trainingTime .. "s)", "#66FF66")
end

local function findNearbyDummy()
    -- Procura por dummies próximos (até 7 SQMs)
    local playerPos = player:getPosition()
    if not playerPos then return nil end
    
    for _, tile in ipairs(g_map.getTiles(playerPos.z)) do
        local tilePos = tile:getPosition()
        local distance = getDistanceBetween(playerPos, tilePos)
        
        if distance <= 7 then
            local item = tile:getTopUseThing()
            if item and item:getId() == storage[panelName].id2 then
                return item
            end
        end
    end
    
    return nil
end

local function hasExerciseItem()
    -- Verifica se o jogador tem o item de exercício
    local exercise = findItem(storage[panelName].id)
    return exercise ~= nil
end

local function attackDummy(dummy)
    -- Ataca o dummy uma única vez com cooldown
    if not dummy then return false end
    
    -- Verificar cooldown
    if now - lastClickTime < CLICK_COOLDOWN then
        return false
    end
    
    local exercise = findItem(storage[panelName].id)
    if not exercise then
        updateStatus("Item de exercício não encontrado", "#FF6666")
        return false
    end
    
    useWith(storage[panelName].id, dummy)
    lastClickTime = now
    updateStatus("Clicou no dummy - Aguardando...", "#FFAA00")
    return true
end

-- =========================[ DETECÇÃO DE MENSAGENS ]======================

-- Monitorar mensagens do servidor para detectar início/fim do treinamento
onTextMessage(function(mode, text)
    if not storage[panelName].enabled then return end
    
    local lowerText = text:lower()
    
    -- Detectar início do treinamento
    if mode == 18 or mode == 17 or mode == 19 or mode == 20 then
        if lowerText:find("you started training") or 
           lowerText:find("you are already training") or
           lowerText:find("you have started training") or
           lowerText:find("training") then
            
            if not isCurrentlyTraining then
                isCurrentlyTraining = true
                trainingStartTime = now
                lastTrainingMessage = now
                updateStatus("Treinando!", "#66FF66")
            else
                -- Atualizar timestamp da última mensagem de treino
                lastTrainingMessage = now
            end
        end
        
        -- Detectar fim do treinamento (várias possibilidades)
        if lowerText:find("you stopped training") or
           lowerText:find("training interrupted") or
           lowerText:find("you are no longer training") or
           lowerText:find("you stop training") or
           lowerText:find("training has been interrupted") or
           lowerText:find("you have stopped training") then
            
            stopTraining("mensagem do servidor")
        end
    end
end)

-- =========================[ LÓGICA PRINCIPAL ]============================

local function smartDummyLogic()
    if not storage[panelName].enabled then
        updateStatus("Desligado", "#888888")
        return
    end
    
    -- Verificar se tem o item de exercício
    if not hasExerciseItem() then
        updateStatus("Item de exercicio nao encontrado", "#FF6666")
        return
    end
    
    -- Verificar status do treinamento
    checkTrainingStatus()
    
    -- Se está treinando, não fazer nada
    if isCurrentlyTraining then
        return
    end
    
    -- Se não está treinando, verificar se pode procurar dummy
    if now - searchCooldown < 2000 then
        -- Cooldown entre buscas
        updateStatus("Aguardando...", "#FFAA00")
        return
    end
    
    -- Procurar dummy próximo
    updateStatus("Procurando dummy...", "#FFAA00")
    local dummy = findNearbyDummy()
    
    if dummy then
        if attackDummy(dummy) then
            searchCooldown = now
        end
    else
        updateStatus("Nenhum dummy encontrado", "#FF6666")
        searchCooldown = now
    end
end

-- =========================[ MACRO PRINCIPAL ]============================

-- Macro principal - executa a cada 1 segundo
dummySmart = macro(1000, function()
    smartDummyLogic()
end)

-- =========================[ INTERFACE E EVENTOS ]======================

-- Configurar UI inicial
ui.title:setOn(storage[panelName].enabled)
ui.title.onClick = function(widget)
    storage[panelName].enabled = not storage[panelName].enabled
    widget:setOn(storage[panelName].enabled)
    
    if storage[panelName].enabled then
        updateStatus("Ativado", "#66FF66")
        -- Reset do estado quando ativar
        isCurrentlyTraining = false
        lastClickTime = 0
        lastPlayerPosition = player:getPosition()
    else
        updateStatus("Desligado", "#888888")
        isCurrentlyTraining = false
    end
end

ui.item.onItemChange = function(widget)
    storage[panelName].id = widget:getItemId()
end
ui.item:setItemId(storage[panelName].id)

ui.Target.onItemChange = function(widget)
    storage[panelName].id2 = widget:getItemId()
end
ui.Target:setItemId(storage[panelName].id2)

-- =========================[ FUNÇÕES DE CONTROLE ]======================

function setDummySmartOff()
    storage[panelName].enabled = false
    ui.title:setOn(false)
    updateStatus("Desligado", "#888888")
    isCurrentlyTraining = false
end

function setDummySmartOn()
    storage[panelName].enabled = true
    ui.title:setOn(true)
    updateStatus("Ativado", "#66FF66")
    isCurrentlyTraining = false
    lastClickTime = 0
    lastPlayerPosition = player:getPosition()
end


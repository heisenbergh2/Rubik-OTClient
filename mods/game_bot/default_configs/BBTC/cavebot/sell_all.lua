CaveBot.Extensions.SellAll = {}

local sellAllCap = 0
local sellAllState = {
    lastSellTime = 0,
    emptyAttempts = 0,
    totalItemsSold = 0,
    startTime = 0,
    lastCapacity = 0,
    forceAttempts = 0,
    lastItemCounts = {},
    lastCallTime = 0,
    processingDelay = 0,
    isProcessing = false,
    currentRetry = 0,
    itemsSoldThisSession = {},
    lastSuccessTime = 0
}

-- Constantes de configuracao
local SELL_BATCH_SIZE = 1000
local MAX_EMPTY_ATTEMPTS = 20
local MAX_FORCE_ATTEMPTS = 20
local SELL_TIMEOUT = 180000
local SELL_DELAY = 1200
local BATCH_DELAY = 600
local FORCE_DELAY = 1500
local CAVEBOT_SYNC_DELAY = 300

-- Funcao para verificar se o NPC trade esta ativo
local function isNpcTradeActive()
    return modules.game_npctrade and 
           modules.game_npctrade.npcWindow and 
           modules.game_npctrade.npcWindow:isVisible() and
           g_game.isOnline()
end

-- Funcao para obter quantidade real vendavel de um item
local function getSellableQuantity(itemId)
    if not modules.game_npctrade.playerItems[itemId] then
        return 0
    end
    
    local totalAmount = modules.game_npctrade.playerItems[itemId]
    local removeAmount = 0
    
    -- Remove itens equipados se a opcao estiver marcada
    if modules.game_npctrade.ignoreEquipped and modules.game_npctrade.ignoreEquipped:isChecked() then
        local localPlayer = g_game.getLocalPlayer()
        for i = 1, 10 do
            local inventoryItem = localPlayer:getInventoryItem(i)
            if inventoryItem and inventoryItem:getId() == itemId then
                removeAmount = removeAmount + inventoryItem:getCount()
            end
        end
    end
    
    return math.max(0, totalAmount - removeAmount)
end

-- Funcao de timing corrigida
local function shouldProcessNow()
    local currentTime = os.time() * 1000
    
    if sellAllState.isProcessing then
        if currentTime - sellAllState.lastCallTime < sellAllState.processingDelay then
            return false
        end
    end
    
    if currentTime - sellAllState.lastCallTime < CAVEBOT_SYNC_DELAY then
        return false
    end
    
    return true
end

-- Funcao para definir delay corrigida
local function setProcessingDelay(delayMs, reason)
    sellAllState.processingDelay = delayMs
    sellAllState.lastCallTime = os.time() * 1000
    sellAllState.isProcessing = true
end

-- Funcao para finalizar processamento
local function finishProcessing(reason)
    sellAllState.isProcessing = false
    sellAllState.processingDelay = 0
end

-- Funcao para verificar desconexao
local function checkConnection()
    return g_game.isOnline()
end

-- Funcao para refresh controlado dos dados do NPC
local function safeRefreshNpcData()
    if not checkConnection() then
        return false
    end
    
    if modules.game_npctrade.refreshPlayerGoods then
        modules.game_npctrade.refreshPlayerGoods()
    end
    
    setProcessingDelay(800, "Safe NPC refresh delay")
    return true
end

-- Funcao de venda item melhorada
local function sellItemSafely(tradeItem, amount, batchNumber)
    local itemId = tradeItem.ptr:getId()
    local itemName = tradeItem.name
    
    if not checkConnection() then
        return false
    end
    
    if not isNpcTradeActive() then
        return false
    end
    
    local quantityBefore = getSellableQuantity(itemId)
    if quantityBefore <= 0 then
        return false
    end
    
    local actualAmount = math.min(amount, quantityBefore)
    
    local itemToSell = Item.create(itemId)
    local success = g_game.sellItem(itemToSell, actualAmount, 
                                   modules.game_npctrade.ignoreEquipped and 
                                   modules.game_npctrade.ignoreEquipped:isChecked())
    
    if not success then
        return false
    end
    
    setProcessingDelay(BATCH_DELAY, "Post-sell processing delay")
    
    if modules.game_npctrade.refreshPlayerGoods then
        modules.game_npctrade.refreshPlayerGoods()
    end
    
    local quantityAfter = getSellableQuantity(itemId)
    local actualSold = quantityBefore - quantityAfter
    
    if actualSold > 0 then
        sellAllState.lastSellTime = os.time()
        sellAllState.lastSuccessTime = os.time()
        sellAllState.itemsSoldThisSession[itemId] = (sellAllState.itemsSoldThisSession[itemId] or 0) + actualSold
        return true
    else
        return false
    end
end

-- Funcao principal de venda reescrita
local function performSellAttempt(exceptions, forceMode)
    if not checkConnection() then
        return false
    end
    
    if not isNpcTradeActive() then
        return false
    end
    
    local exceptionSet = {}
    for _, id in ipairs(exceptions or {}) do
        if type(id) == "number" and id > 0 then
            exceptionSet[id] = true
        elseif type(id) == "string" and tonumber(id) then
            local numId = tonumber(id)
            if numId then
                exceptionSet[numId] = true
            end
        end
    end
    
    if forceMode then
        if not safeRefreshNpcData() then
            return "processing"
        end
    end
    
    local sellTradeItems = modules.game_npctrade.tradeItems[2] or {}
    if table.empty(sellTradeItems) then
        return false
    end
    
    local itemsProcessed = 0
    local itemsSold = 0
    local hasItemsAvailable = false
    
    for _, tradeItem in pairs(sellTradeItems) do
        local itemId = tradeItem.ptr:getId()
        
        if not exceptionSet[itemId] then
            local sellableAmount = getSellableQuantity(itemId)
            
            if sellableAmount > 0 then
                hasItemsAvailable = true
                itemsProcessed = itemsProcessed + 1
                
                if sellItemSafely(tradeItem, sellableAmount, 1) then
                    itemsSold = itemsSold + 1
                end
                
                if not checkConnection() then
                    return false
                end
                
                if not isNpcTradeActive() then
                    return false
                end
                
                if itemsProcessed < table.size(sellTradeItems) then
                    setProcessingDelay(200, "Inter-item delay")
                    return "processing"
                end
            end
        end
    end
    
    if itemsSold > 0 then
        return true
    elseif hasItemsAvailable then
        return "retry"
    else
        return false
    end
end

-- Funcao para verificar se ainda ha itens
local function hasItemsToSell(exceptions)
    if not isNpcTradeActive() then
        return false
    end
    
    local exceptionSet = {}
    for _, id in ipairs(exceptions or {}) do
        if type(id) == "number" and id > 0 then
            exceptionSet[id] = true
        elseif type(id) == "string" and tonumber(id) then
            exceptionSet[tonumber(id)] = true
        end
    end
    
    local sellTradeItems = modules.game_npctrade.tradeItems[2] or {}
    local totalItems = 0
    
    for _, tradeItem in pairs(sellTradeItems) do
        local itemId = tradeItem.ptr:getId()
        if not exceptionSet[itemId] then
            local qty = getSellableQuantity(itemId)
            if qty > 0 then
                totalItems = totalItems + qty
            end
        end
    end
    
    return totalItems > 0
end

-- Funcao principal do SellAll
CaveBot.Extensions.SellAll.setup = function()
    CaveBot.registerAction("SellAll", "#C300FF", function(value, retries)
        if not shouldProcessNow() then
            return "retry"
        end
        
        sellAllState.lastCallTime = os.time() * 1000
        sellAllState.currentRetry = retries
        
        local val = string.split(value, ",")
        local wait = false
        
        for i, v in ipairs(val) do
            v = v:trim()
            if v == "yes" then
                wait = true
            else
                val[i] = tonumber(v) or v
            end
        end
        
        local npcName = val[1]
        
        local npc = getCreatureByName(npcName)
        if not npc then
            finishProcessing("NPC not found")
            return false
        end
        
        if retries == 0 then
            sellAllState = {
                lastSellTime = os.time(),
                emptyAttempts = 0,
                totalItemsSold = 0,
                startTime = os.time(),
                lastCapacity = freecap(),
                forceAttempts = 0,
                lastItemCounts = {},
                lastCallTime = os.time() * 1000,
                processingDelay = 0,
                isProcessing = false,
                currentRetry = 0,
                itemsSoldThisSession = {},
                lastSuccessTime = os.time()
            }
        end
        
        local currentTime = os.time()
        if (currentTime - sellAllState.startTime) * 1000 > SELL_TIMEOUT then
            finishProcessing("Timeout reached")
            return true
        end
        
        if not checkConnection() then
            finishProcessing("Connection lost")
            return false
        end
        
        if retries > 100 then
            finishProcessing("Max retries reached")
            return true
        end
        
        if not CaveBot.ReachNPC(npcName) then
            setProcessingDelay(SELL_DELAY, "NPC reach retry")
            return "retry"
        end
        
        if not isNpcTradeActive() then
            CaveBot.OpenNpcTrade()
            setProcessingDelay(storage.extras.talkDelay * 2, "Opening NPC trade")
            return "retry"
        end
        
        if table.empty(modules.game_npctrade.tradeItems[2] or {}) then
            setProcessingDelay(800, "Loading trade data")
            return "retry"
        end
        
        storage.cavebotSell = storage.cavebotSell or {}
        
        for _, item in ipairs(storage.cavebotSell) do
            local id = type(item) == 'number' and item or 
                      (type(item) == 'table' and item.id) or 
                      tonumber(item)
            if id and id > 0 and not table.find(val, id) then
                table.insert(val, id)
            end
        end
        
        local forceMode = sellAllState.emptyAttempts >= MAX_EMPTY_ATTEMPTS
        
        local result = performSellAttempt(val, forceMode)
        
        if result == "processing" then
            return "retry"
        elseif result == true then
            sellAllState.emptyAttempts = 0
            sellAllState.forceAttempts = 0
            setProcessingDelay(BATCH_DELAY, "Post-success delay")
            return "retry"
        else
            if forceMode then
                sellAllState.forceAttempts = sellAllState.forceAttempts + 1
                
                if sellAllState.forceAttempts >= MAX_FORCE_ATTEMPTS then
                    finishProcessing("Force attempts exhausted")
                    return true
                else
                    sellAllState.emptyAttempts = 0
                end
            else
                sellAllState.emptyAttempts = sellAllState.emptyAttempts + 1
            end
            
            setProcessingDelay(SELL_DELAY, "Retry delay after failure")
            return "retry"
        end
    end)
    
    CaveBot.Editor.registerAction("sellall", "sell all", {
        value="NPC",
        title="Sell All",
        description="NPC Name, 'yes' if sell with delay, exceptions: id separated by comma",
    })
end
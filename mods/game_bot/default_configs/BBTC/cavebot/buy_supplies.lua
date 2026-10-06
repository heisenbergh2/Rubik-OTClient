CaveBot.Extensions.BuySupplies = {}

-- Contador global de retries para evitar reset
local buySuppliesRetries = {}

CaveBot.Extensions.BuySupplies.setup = function()
  CaveBot.registerAction("BuySupplies", "#C300FF", function(value, retries)
    local possibleItems = {}

    local val = string.split(value, ",")
    local waitVal
    if #val == 0 or #val > 2 then
      warn("CaveBot[BuySupplies]: incorrect BuySupplies value")
      return false
    elseif #val == 2 then
      waitVal = tonumber(val[2]:trim())
    end

    local npcName = val[1]:trim()
    local npc = getCreatureByName(npcName)
    if not npc then
      print("CaveBot[BuySupplies]: NPC not found (retry " .. retries .. ")")
      return false
    end

    if not waitVal and #val == 2 then
      warn("CaveBot[BuySupplies]: incorrect delay values!")
    elseif waitVal and #val == 2 then
      delay(waitVal)
    end

    -- Inicializar contador se nao existe
    if not buySuppliesRetries[npcName] then
      buySuppliesRetries[npcName] = 0
    end
    
    -- Incrementar contador
    buySuppliesRetries[npcName] = buySuppliesRetries[npcName] + 1
    
    -- DEBUG: Log a cada 10 tentativas
    if buySuppliesRetries[npcName] % 10 == 0 then
      print("CaveBot[BuySupplies]: Tentativa " .. buySuppliesRetries[npcName] .. " de comprar de " .. npcName)
    end

    -- PROTECAO: Pausa apenas se realmente exceder o limite
    if buySuppliesRetries[npcName] > 100 then
      print("CaveBot[BuySupplies]: Too many tries (" .. buySuppliesRetries[npcName] .. "), can't buy from " .. npcName)
      warn("CaveBot PAUSADO: Muitas falhas ao comprar suprimentos de " .. npcName .. "!")
      buySuppliesRetries[npcName] = 0  -- Reset contador
      -- Pausa o CaveBot para evitar loop infinito
      if CaveBot and CaveBot.setOff then
        CaveBot.setOff()
      end
      return false
    end

    if not CaveBot.ReachNPC(npcName) then
      if buySuppliesRetries[npcName] % 20 == 0 then
        print("CaveBot[BuySupplies]: Nao conseguiu alcancar NPC " .. npcName .. " (tentativa " .. buySuppliesRetries[npcName] .. ")")
      end
      return "retry"
    end

    if not NPC.isTrading() then
      CaveBot.OpenNpcTrade()
      CaveBot.delay(storage.extras.talkDelay*2)
      if buySuppliesRetries[npcName] % 20 == 0 then
        print("CaveBot[BuySupplies]: Esperando janela de trade abrir... (tentativa " .. buySuppliesRetries[npcName] .. ")")
      end
      return "retry"
    end

    -- get items from npc
    local npcItems = NPC.getBuyItems()
    for i,v in pairs(npcItems) do
      table.insert(possibleItems, v.id)
    end

    local boughtSomething = false
    for id, values in pairs(Supplies.getItemsData()) do
      id = tonumber(id)
      if table.find(possibleItems, id) then
        local max = values.max
        local current = player:getItemsCount(id)
        local toBuy = max - current

        if toBuy > 0 then
          toBuy = math.min(100, toBuy)

          NPC.buy(id, math.min(100, toBuy))
          boughtSomething = true
          if buySuppliesRetries[npcName] % 20 == 0 then
            print("CaveBot[BuySupplies]: Comprando " .. toBuy .. "x item " .. id .. " (tentativa " .. buySuppliesRetries[npcName] .. ")")
          end
          -- CORRECAO CRITICA: Delay para servidor processar a compra
          -- Usa o talkDelay configurado ou minimo de 1000ms
          local buyDelay = math.max(1000, (storage.extras.talkDelay or 500) * 3)
          delay(buyDelay)
          return "retry"
        end
      end
    end

    -- SUCCESS: Reset contador quando completa com sucesso
    if not boughtSomething then
      print("CaveBot[BuySupplies]: Compra completa de " .. npcName .. " (tentativas: " .. buySuppliesRetries[npcName] .. ")")
      buySuppliesRetries[npcName] = 0
    end

    -- print("CaveBot[BuySupplies]: bought everything, proceeding")
    return true
 end)

 CaveBot.Editor.registerAction("buysupplies", "buy supplies", {
  value="NPC name",
  title="Buy Supplies",
  description="NPC Name, delay(in ms, optional)",
 })
end

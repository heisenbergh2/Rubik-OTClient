CaveBot.Extensions.OpenDoors = {}

CaveBot.Extensions.OpenDoors.setup = function()
  CaveBot.registerAction("OpenDoors", "#00FFFF", function(value, retries)
    local pos = string.split(value, ",")
    local key = nil
    if #pos == 4 then
      key = tonumber(pos[4])
    end
    if not pos[1] then
      warn("CaveBot[OpenDoors]: invalid value. It should be position (x,y,z), is: " .. value)
      return false
    end

    if retries >= 20 then
      print("CaveBot[OpenDoors]: too many tries (" .. retries .. "), can't open doors at " .. value)
      warn("CaveBot PAUSADO: Nao conseguiu abrir porta apos " .. retries .. " tentativas!")
      if CaveBot and CaveBot.setOff then
        CaveBot.setOff()
      end
      return false
    end

    pos = {x=tonumber(pos[1]), y=tonumber(pos[2]), z=tonumber(pos[3])}
    
    -- Verificar distancia do player ate a porta
    local playerPos = player:getPosition()
    local distance = math.max(math.abs(playerPos.x - pos.x), math.abs(playerPos.y - pos.y))
    
    -- Se player passou da porta (distancia > 2), considera que abriu com sucesso
    if distance > 2 then
      if retries > 0 then
        print("CaveBot[OpenDoors]: player passou pela porta em " .. value .. " (distancia: " .. distance .. ")")
      end
      return true
    end

    local doorTile
    if not doorTile then
      for i, tile in ipairs(g_map.getTiles(posz())) do
        if tile:getPosition().x == pos.x and tile:getPosition().y == pos.y and tile:getPosition().z == pos.z then
          doorTile = tile
        end
      end
    end

    if not doorTile then
      -- Tile nao encontrado, mas se player esta longe, considera sucesso
      if distance > 1 then
        print("CaveBot[OpenDoors]: tile nao encontrado mas player ja passou")
        return true
      end
      return false
    end

    if not doorTile:isWalkable() then
      -- CORRECAO: Delay maior para servidor processar abertura da porta
      local doorDelay = math.max(600, (storage.extras.talkDelay or 300) * 2)
      
      -- CORRECAO CRITICA: Apos 10 tentativas, assume que a porta abriu e prossegue
      -- Isso resolve o problema de dessincronia entre servidor e client
      if retries >= 10 then
        print("CaveBot[OpenDoors]: assumindo que porta em " .. value .. " foi aberta apos " .. retries .. " tentativas (ignorando validacao)")
        return true
      end
      
      if retries % 5 == 0 and retries > 0 then
        print("CaveBot[OpenDoors]: tentando abrir porta em " .. value .. " (tentativa " .. retries .. ", distancia: " .. distance .. ")")
      end
      
      if not key then
        use(doorTile:getTopUseThing())
        delay(doorDelay)
        return "retry"
      else
        useWith(key, doorTile:getTopUseThing())
        delay(doorDelay)
        return "retry"
      end
    else
      if retries > 5 then
        print("CaveBot[OpenDoors]: porta aberta com sucesso em " .. value .. " apos " .. retries .. " tentativas")
      else
        print("CaveBot[OpenDoors]: possible to cross, proceeding")
      end
      return true
    end
  end)

  CaveBot.Editor.registerAction("opendoors", "open doors", {
    value=function() return posx() .. "," .. posy() .. "," .. posz() end,
    title="Door position",
    description="doors position (x,y,z) and key id (optional)",
    multiline=false,
    validation=[[\d{1,5},\d{1,5},\d{1,2}(?:,\d{1,5}$|$)]]
})
end

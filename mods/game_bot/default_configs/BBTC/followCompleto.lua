addSeparator()
setDefaultTab("Suport")
addSeparator()

local followThis = tostring(storage.followLeader or "")
local followspeaker = tostring(storage.Leaderspeaker or "")

-- Usando a estrutura simples que funciona
FloorChangers = {
  RopeSpots = {
    Up = {386, 421, 12202, 12935, 17238, 23363, 21966, 21965},
    Down = {}
  },
  Use = {
    Up = {1948, 5542, 16693, 16692, 1723, 7771, 1856, 33086, 16692, 8065, 8263, 20573, 20475, 31262, 21297 },
    Down = {435, 432, 412, 469, 1080}
  }
}

local openDoors = { 9567, 31570, 34847, 1764, 21051, 30823, 6264, 5282, 20453, 11705, 6256, 2772, 27260, 2773, 1632, 6252, 5007, 1629, 5107, 5281, 1968, 31116, 31120, 30742, 31115, 31118, 20474, 5736, 5733, 31202, 31228, 31199, 31200, 33262, 30824, 5125, 5126, 5116, 8257, 8258, 8255, 8256, 5120, 30777, 30776, 23873, 23877, 5736, 6264, 31130, 6249, 5122, 30049, 7727, 25803, 16277, 5098, 5104, 5102, 5106, 5109, 5111, 5113, 5118, 5120, 5102, 5100, 1638, 1640, 19250, 3500, 3497, 3498, 3499, 2177, 17709, 1642, 23875, 1644, 5131, 5115, 28546, 6254, 28546, 30364, 30365, 30367, 30368, 30363, 30366, 31139, 31138, 31136, 31137, 4981, 4977, 11714, 7771, 9558, 9559, 20475, 2909, 2907, 8618, 31366, 1646, 1648, 4997, 22506, 8259, 27503, 27505, 27507, 31476, 31477, 31477, 31475, 31474, 8363, 5097, 1644, 7712, 7715, 11237, 11246, 9874, 6260, 33634, 33633, 22632, 22639, 1631, 1628, 20446, 20443, 20444, 2334, 9357, 9355 }

-- IDs de buracos para quando o líder sumiu
local HOLE_TEST_IDS = {
  868,594, 607, 293, 35500, 294, 595, 1949, 4728, 385, 9853, 37000, 37001, 35499, 35497, 29979,
  25047, 25048, 25049, 25050, 25051, 25052, 25053, 25054, 25055, 25056, 25057, 25058, 21046, 21048
}

-- Procurar buracos próximos quando líder sumiu
local function stepIntoNearbyOpenHole(range)
  range = range or 1
  local p = player:getPosition(); if not p then return false end
  for dx = -range, range do
    for dy = -range, range do
      local pos = {x = p.x + dx, y = p.y + dy, z = p.z}
      local tile = g_map.getTile(pos)
      if tile then
        local ground = tile:getGround(); local gid = ground and ground:getId() or nil
        local top    = tile:getTopUseThing(); local tid = top and top:getId() or nil
        if (gid and table.find(HOLE_TEST_IDS, gid)) or (tid and table.find(HOLE_TEST_IDS, tid)) then
          if autoWalk(pos, 20, { ignoreNonPathable = true, precision = 1 }) then
            delay(120)
            return true
          end
        end
      end
    end
  end
  return false
end

local Travels = { cities = "hi " }
local Repeat = { reapeat = "say: ", dist = "dist: " }
local NPCRepeat = { npcreapeat = "npc: " }

-- Variáveis globais
local lastLeaderFloor
local leaderPositions = {}
local leaderDirections = {}

-- === NOVO: distância padrão do Follow simples (usada também no Advanced)
local function getFollowDistance()
  local key = followdist or "disttofollow"
  local cfg = storage[key]
  local d = 3
  if cfg and cfg.dist then
    local n = tonumber(cfg.dist)
    if n and n >= 0 then d = n end
  end
  return d
end

-- Abrir portas se necessário (respeita a distância configurada)
local function autoUseNearbyDoors(leaderRef, minDist)
  if not leaderRef then return end
  local lpos = leaderRef:getPosition(); if not lpos then return end
  local threshold = tonumber(minDist) or getFollowDistance() or 3
  if getDistanceBetween(player:getPosition(), lpos) < threshold then return end
  local tiles = g_map.getTiles(posz()); if not tiles then return end
  for _, tile in pairs(tiles) do
    local tpos = tile:getPosition()
    if math.abs(tpos.x - pos().x) + math.abs(tpos.y - pos().y) == 1 then
      local top = tile:getTopUseThing()
      if top and table.find(openDoors, top:getId()) then
        g_game.use(top)
        delay(math.random(400, 800))
        return
      end
    end
  end
end

-- Helpers
local function isRopeSpotId(id) return id and table.contains(FloorChangers.RopeSpots.Up, id) end
local ROPE_ITEM_IDS = {9594, 9596, 9598, 3003}
local function pickRopeId()
  if storage.extras and storage.extras.rope then return storage.extras.rope end
  if findItem then
    for _, id in ipairs(ROPE_ITEM_IDS) do
      local it = findItem(id)
      if it then return id end
    end
  end
  return 9596
end

local function handleUse(pos)
  if not pos then return end
  local lastZ = posz()
  if posz() == lastZ then
    local tile = g_map.getTile({x = pos.x, y = pos.y, z = pos.z})
    if not tile then return end
    local thing = tile:getTopUseThing()
    if thing then g_game.use(thing) end
  end
end

local function handleRope(pos)
  if not pos then return end
  local lastZ = posz()
  if posz() == lastZ then
    local tile = g_map.getTile({x = pos.x, y = pos.y, z = pos.z})
    if not tile then return end
    local rid = pickRopeId()

    local ground = tile:getGround()
    if ground and isRopeSpotId(ground:getId()) then
      useWith(rid, ground); return
    end

    local top = tile:getTopUseThing()
    if top and isRopeSpotId(top:getId()) then
      useWith(rid, top); return
    end

    if top then useWith(rid, top) end
  end
end

local floorChangeSelector = {
  RopeSpots = {Up = handleRope, Down = handleRope},
  Use = {Up = handleUse, Down = handleUse}
}

local function distance(pos1, pos2)
  local p2 = pos2 or player:getPosition()
  return math.abs((pos1.x or 0) - (p2.x or 0)) + math.abs((pos1.y or 0) - (p2.y or 0))
end

local function executeClosest(possibilities)
  local closest; local closestDistance = 99999
  for _, data in ipairs(possibilities) do
    local dist = distance(data.pos)
    if dist < closestDistance then closest = data; closestDistance = dist end
  end
  if closest then closest.changer(closest.pos); return true end
  return false
end

local function handleFloorChange()
  local lastZ = posz()
  local p = player:getPosition(); if not p then return false end
  local possibleChangers = {}

  local tryDirections = {"Down", "Up"}
  for _, dir in ipairs(tryDirections) do
    for changer, data in pairs(FloorChangers) do
      for x = -1, 1 do
        for y = -1, 1 do
          local tile = g_map.getTile({x = p.x + x, y = p.y + y, z = p.z})
          if tile then
            local match = false
            if changer == "RopeSpots" then
              local g = tile:getGround()
              local t = tile:getTopUseThing()
              match = (g and isRopeSpotId(g:getId())) or (t and isRopeSpotId(t:getId()))
            else
              local top = tile:getTopUseThing()
              match = top and table.find(data[dir], top:getId())
            end
            if match then
              table.insert(possibleChangers, {
                changer = floorChangeSelector[changer][dir],
                pos = {x = p.x + x, y = p.y + y, z = p.z}
              })
            end
          end
        end
      end
    end
  end
  if #possibleChangers > 0 and posz() == lastZ then
    return executeClosest(possibleChangers)
  end
  return false
end

local lastLevitateAt = 0
local function levitate(dir)
  if now - lastLevitateAt < 400 then return end
  lastLevitateAt = now
  if dir then turn(dir) end
  schedule(120, function() say("exani tera") end)
  schedule(120, function() say("exani hur \"down") end)
  schedule(200, function() say("exani hur \"up") end)
end

local function handleUsing() handleFloorChange() end

-- ====== Controle via chat ======
onTalk(function(name, level, mode, text, channelId, pos)
  if AdvancedFollow:isOff() and followMacro:isOff() then
    if mode == 4 and (name == storage.followLeader or name == storage.Leaderspeaker) then
      if string.find(text, "only advanced") then
        AdvancedFollow.setOn()
      elseif string.find(text, "only normal") then
        followMacro.setOn()
      end
    end
  end
end)

onTalk(function(name, level, mode, text, channelId, pos)
  if AdvancedFollow:isOn() or followMacro:isOn() then
    if mode == 4 and (name == storage.followLeader or name == storage.Leaderspeaker) then
      if string.find(text, Travels.cities) then
        local cidade = text:gsub("hi ", "")
        CaveBot.Travel(cidade)
      elseif string.find(text, Repeat.reapeat) then
        local again = text:gsub("say: ", ""); say(again)
      elseif string.find(text, NPCRepeat.npcreapeat) then
        local npcsay = text:gsub("npc: ", ""); NPC.say(npcsay)
      elseif string.find(text, "advanced on") then
        AdvancedFollow.setOn(); followMacro.setOff()
      elseif string.find(text, "normal on") then
        followMacro.setOn(); AdvancedFollow.setOff()
      elseif string.find(text, "all off") then
        followMacro.setOff(); AdvancedFollow.setOff()
      elseif string.find(text, "target off") then
        TargetBot.setOff()
      elseif string.find(text, "target on") then
        TargetBot.setOn()
      elseif string.find(text, Repeat.dist) then
        local dista = text:gsub("dist: ", "")
        storage[followdist].dist = dista
      end
    end
  end
end)

local targetspealer = followspeaker
local target = followThis
local lastKnownPosition
local lastKnownDirection

-- === Função que vira na direção do líder
local function turnDir()
  if not storage.followLeader or storage.followLeader == "" then return end
  local targetZ = getCreatureByName(storage.followLeader)
  local pdir = player:getDirection()
  for _, n in ipairs(getSpectators(true)) do
    if n:getName() == storage.followLeader then
      targetZ = n; break
    end
  end
  if not targetZ then return end
  local targetPos = targetZ:getPosition(); if not targetPos then return end
  local targetDir = targetZ:getDirection()
  if targetZ and targetPos.z == posz() and pdir ~= targetDir then
    lastKnownDirection = targetDir
    turn(targetDir)
  end
end

-- === TOGGLE: botão para ligar/desligar o "virar com o líder"
turnWithLeader = macro(200, "Virar com o lider (turnDir)", function() end)
if turnWithLeader and turnWithLeader.setOn then
  turnWithLeader.setOn() -- padrão ligado (comportamento antigo)
end

followChange = macro(200, "Follow Change", function() end)

local toFollowPos = {}

local function followIsOn()
  return AdvancedFollow and AdvancedFollow.isOn and AdvancedFollow:isOn()
end

function getFollowName()
  local name = storage.followLeader
  if not name or name == "" then return "" end
  return name
end

-- === ADVANCED FOLLOW (usa a distância do Follow simples + toggle de direção corrigido)
AdvancedFollow = macro(20, "Advanced Follow", "", function(macro)
  if followMacro.isOn() then followMacro.setOff() end
  local followName = getFollowName()
  local leader = getCreatureByName(storage.followLeader or "")
  
  if not leader then
    -- Líder não visível: usar última posição conhecida
    local leaderPos = leaderPositions[posz()]
    if leaderPos and getDistanceBetween(player:getPosition(), leaderPos) > 0 then
      if autoWalk(leaderPos, 80, { ignoreNonPathable = true, precision = 0 }) then
        delay(100); return
      end
    end
    -- Tentar cair em buraco adjacente
    if stepIntoNearbyOpenHole(1) then return end
    -- Tentar troca de andar
    if handleFloorChange() then return end
    -- Levitar se tiver direção conhecida do andar anterior
    local dir = leaderDirections[posz()]
    if dir then levitate(dir) end
  else
    -- Líder visível: seguir normalmente
    local lpos = leader:getPosition()
    if lpos then
      toFollowPos[lpos.z] = lpos
      local desiredDist = getFollowDistance()
      local dist = getDistanceBetween(player:getPosition(), lpos)

      -- >>> CORREÇÃO: virar ANTES do autoWalk, controlado pelo toggle <<<
      if turnWithLeader:isOn() then
        turnDir()
      end

      -- Abrir portas conforme distância configurada
      autoUseNearbyDoors(leader, desiredDist)

      -- Seguir com a mesma distância do Follow simples
      if autoWalk(lpos, 40, {
            ignoreNonPathable = true,
            precision = 1,
            ignoreCreatures = true,
            marginMin = desiredDist,
            marginMax = desiredDist
          }) then
        delay(100)
        return
      end

      -- Se não conseguir encontrar caminho, tentar troca de andar
      if dist > desiredDist and not findPath(player:getPosition(), lpos, 20, { ignoreNonPathable = true, precision = 1 }) then
        handleUsing()
      end
    end
  end
end)

-- ====== UI Leader/NPC ======
LeaderSpeaker = addTextEdit("Leader speaker", storage.Leaderspeaker or "Leader speaker", function(widget, text)
  storage.Leaderspeaker = text
  targetspealer = tostring(text)
end)

followled = addTextEdit("playerToFollow", storage.followLeader or "Leader name", function(widget, text)
  storage.followLeader = text
  target = tostring(text)
end)

-- ====== Eventos de posição/creature ======
onPlayerPositionChange(function(newPos, oldPos)
  if followChange:isOff() then return end
  if (g_game.isFollowing()) then
    tfollow = g_game.getFollowingCreature()
    if tfollow then
      if tfollow:getName() ~= storage.followLeader then
        followled:setText(tfollow:getName())
        storage.followLeader = tfollow:getName()
      end
    end
  end
end)

onCreaturePositionChange(function(creature, newPos, oldPos)
  if not followIsOn() then return end
  if creature:getName() == player:getName() then return end

  local followName = getFollowName()
  if followName == "" then return end
  if creature:getName():lower() ~= followName:lower() then return end

  if newPos then
    leaderPositions[newPos.z] = newPos
    lastLeaderFloor = newPos.z
    toFollowPos[newPos.z] = newPos
  end

  if oldPos then
    if newPos and oldPos.z ~= newPos.z then
      leaderDirections[oldPos.z] = creature:getDirection()
    end
    local oldTile = g_map.getTile(oldPos)
    local walkPrecision = 1
    if oldTile and type(oldTile.hasCreature) == "function" and not oldTile:hasCreature() then
      walkPrecision = 0
    end
    autoWalk(oldPos, 40, { ignoreNonPathable = true, precision = walkPrecision })
  end
end)

onCreatureAppear(function(creature)
  if not followIsOn() then return end
  local cpos = creature:getPosition(); if not cpos or cpos.z ~= posz() then return end

  local followName = getFollowName()
  if followName ~= "" and creature:getName():lower() == followName:lower() then
    -- Líder apareceu
  elseif creature:getName() == player:getName() then
    if lastLeaderFloor and lastLeaderFloor == posz() then
      -- Player mudou de andar
    end
  end
end)

onCreatureDisappear(function(creature)
  if not followIsOn() then return end
  local followName = getFollowName()
  if followName ~= "" and creature:getName():lower() == followName:lower() then
    -- Líder desapareceu
    return
  end
  if creature:getName() == player:getName() then
    if lastLeaderFloor and posz() ~= lastLeaderFloor then 
      -- Player mudou de andar
    end
  end
end)

---------------------------- FOLLOW COM DISTANCIA (NÃO USAR JUNTO COM O ADVANCED FOLLOW)

followdist = "disttofollow"
if not storage[followdist] then
 storage[followdist] = { dist = "3" }
end
UI.Label("Distance from player:")
UI.TextEdit(storage[followdist].dist or "3", function(widget, newText)
  storage[followdist].dist = newText
end)

UI.Label("Walk Delay")
UI.TextEdit(storage.delayf or "100", function(widget, newText)
  storage.delayf = newText
end)

followMacro = macro(20, "Follow", function()
  if AdvancedFollow.isOn() then AdvancedFollow.setOff() end
  local target = getCreatureByName(storage.followLeader or "")
  local pPos = player:getPosition()
  if target then
    local tpos = target:getPosition()
    if tpos then
      toFollowPos[tpos.z] = tpos
    end
  end
  if player:isWalking() then return end
  local p = toFollowPos[posz()]
  if not p then return end
  if autoWalk(p, 20, {
        ignoreNonPathable = true,
        precision = 1,
        marginMin = tonumber(storage[followdist].dist),
        marginMax = tonumber(storage[followdist].dist)
      }) then
    delay(tonumber(storage.delayf))
  end
end)
UI.Separator()

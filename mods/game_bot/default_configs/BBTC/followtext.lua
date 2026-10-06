-- Follow script NAVI - OTClient / vBot
-- Revisão:
-- - Remove prints em loop (lag). DEBUG opcional via dprint() (padrão OFF).
-- - Remove uso de rawget (ambiente sandbox sem rawget). Uso seguro via _G?.
-- - Substitui getOrCreateTile por getTile (compat).
-- - Guardas contra nil em vários pontos (leader, tiles, topUseThing).
-- - Lógica de limpar leader/aproximação e troca de andar mais robusta.
-- - Extra: subir rope pelo GROUND/TOP (com checagem por lista de RopeSpots); cair em buraco (868/607) só quando líder sumiu.

-- =========================[ Config / Debug ]=========================
local DEBUG = false
local function dprint(...) if DEBUG then print(...) end end
-- ===================================================================

local lastLeaderFloor
local leader

local standTime = now
local function getStandTime() return now - standTime end

local leaderPositions = {}
local leaderDirections = {}

-- =========================[ Floor Changers ]=========================
-- (dedupe leve no RopeSpots.Up só para evitar repetição)
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

-- =========================[ Portas ]=========================
local openDoors = {
  9567, 34847, 1764, 21051, 30823, 6264, 5282, 20453, 11705, 6256, 2772, 27260, 2773, 1632, 6252, 5007, 1629, 5107,
  5281, 1968, 31116, 31120, 30742, 31115, 31118, 20474, 5736, 5733, 31202, 31228, 31199, 31200, 33262, 30824, 5125,
  5126, 5116, 8257, 8258, 8255, 8256, 5120, 30777, 30776, 23873, 23877, 31130, 6249, 5122, 30049, 7727, 25803, 16277,
  5098, 5104, 5102, 5106, 5109, 5111, 5113, 5118, 5120, 5102, 5100, 1638, 1640, 19250, 3500, 3497, 3498, 3499, 2177,
  17709, 1642, 23875, 1644, 5131, 5115, 28546, 6254, 28546, 30364, 30365, 30367, 30368, 30363, 30366, 31139, 31138,
  31136, 31137, 4981, 4977, 11714, 7771, 9558, 9559, 20475, 2909, 2907, 8618, 31366, 1646, 1648, 4997, 22506, 8259,
  27503, 27505, 27507, 31476, 31477, 31475, 31474, 8363, 5097, 1644, 7712, 7715, 11237, 11246, 9874, 6260, 33634,
  33633, 22632, 22639, 1631, 1628, 20446, 20443, 20444, 2334, 9357, 9355, 8265, 1669, 1672, 17701, 17710, 4912, 6251,
  5291, 1683, 1696, 1692, 5006, 2179, 30772, 30774, 6248, 5735, 5732, 30042, 5293, 1687
}

local function autoUseNearbyDoors(leaderRef, minDist)
  if not leaderRef then return end
  local lpos = leaderRef:getPosition(); if not lpos then return end
  if getDistanceBetween(player:getPosition(), lpos) < (minDist or 3) then return end
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

-- === Buracos (só quando líder sumiu) ===
local HOLE_TEST_IDS = {
  868,594, 607, 293, 35500, 294, 595, 1949, 4728, 385, 9853, 37000, 37001, 35499, 35497, 29979,
  25047, 25048, 25049, 25050, 25051, 25052, 25053, 25054, 25055, 25056, 25057, 25058, 21046, 21048
}

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

-- =========================[ Rope helpers ]=========================
-- usa SEMPRE a sua lista FloorChangers.RopeSpots.Up
local function isRopeSpotId(id)
  return id and table.contains(FloorChangers.RopeSpots.Up, id)
end

-- seleção do item rope (9594, 9596, 9598, 3003) + storage.extras.rope
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

local function safeTopUseThingAt(pos)
  if not pos then return nil end
  local tile = g_map.getTile({x = pos.x, y = pos.y, z = pos.z})
  if not tile then return nil end
  return tile:getTopUseThing()
end

local function handleUse(pos)
  if not pos then return end
  local lastZ = posz()
  if posz() == lastZ then
    local thing = safeTopUseThingAt(pos)
    if thing then g_game.use(thing) end
  end
end

-- rope no GROUND OU TOP conforme RopeSpots.Up
local function handleRope(pos)
  if not pos then return end
  local lastZ = posz()
  if posz() == lastZ then
    local tile = g_map.getTile({x = pos.x, y = pos.y, z = pos.z})
    if not tile then return end
    local rid = pickRopeId()

    local ground = tile:getGround()
    if ground and isRopeSpotId(ground:getId()) then
      useWith(rid, ground)
      return
    end

    local top = tile:getTopUseThing()
    if top and isRopeSpotId(top:getId()) then
      useWith(rid, top)
      return
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
  local closest
  local closestDistance = 99999
  for _, data in ipairs(possibilities) do
    local dist = distance(data.pos)
    if dist < closestDistance then
      closest = data
      closestDistance = dist
    end
  end
  if closest then
    closest.changer(closest.pos)
    return true
  end
  return false
end

-- detectar RopeSpots pelo GROUND **ou** TOP; Use pelo TOP
local function handleFloorChange()
  local lastZ = posz()
  local p = player:getPosition()
  if not p then return false end
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

local function matchPos(p1,p2) return (p1 and p2 and p1.x == p2.x and p1.y == p2.y) end

local function handleUsing()
  if BotServerFollow.isOff() then
    handleFloorChange()
    return
  end
  local leaderUsePositions = (_G and _G.leaderUsePositions) or nil
  if leaderUsePositions then
    local usePos = leaderUsePositions[posz()]
    if usePos then
      local tile = g_map.getTile(usePos)
      if tile then
        local thing = tile:getTopUseThing()
        if thing then g_game.use(thing); return end
      end
    end
  end
end

local function useRope(pos)
  pos = pos or player:getPosition()
  if not pos then return false end

  local rid = pickRopeId()
  local around_offsets = {
    { 0,  0}, {-1,  0}, { 1,  0}, { 0, -1},
    { 0,  1}, { 1, -1}, { 1,  1}, {-1,  1}, {-1, -1}
  }

  for i=1,#around_offsets do
    local tpos = {x = pos.x + around_offsets[i][1], y = pos.y + around_offsets[i][2], z = posz()}
    local tile = g_map.getTile(tpos)
    if tile then
      local ground = tile:getGround()
      if ground and isRopeSpotId(ground:getId()) then
        local waitMs = getDistanceBetween(player:getPosition(), tpos) * 60
        useWith(rid, ground); delay(waitMs); return true
      end
      local top = tile:getTopUseThing()
      if top and isRopeSpotId(top:getId()) then
        local waitMs = getDistanceBetween(player:getPosition(), tpos) * 60
        useWith(rid, top); delay(waitMs); return true
      end
    end
  end
  return false
end

-- =========================[ Macro principal ]========================
ultimateFollow = macro(500, "Inject Follow", function()
  local followName = getFollowName()

  if not leader then
    local leaderPos = leaderPositions[posz()]
    if leaderPos and getDistanceBetween(player:getPosition(), leaderPos) > 0 then
      if autoWalk(leaderPos, 80, { ignoreNonPathable = true, precision = 0 }) then
        delay(100)
        return
      end
    end

    -- Se o líder sumiu: tentar cair em buraco adjacente (868/607 etc.)
    if stepIntoNearbyOpenHole(1) then return end

    if BotServerFollow.isOff() then
      if handleFloorChange() then return end
      local dir = leaderDirections[posz()]
      if dir then levitate(dir) end
    else
      local listenedLeaderPosDir = (_G and _G.listenedLeaderPosDir) or nil
      local listenedLeaderDir = (_G and _G.listenedLeaderDir) or nil
      if listenedLeaderPosDir and listenedLeaderDir and matchPos(player:getPosition(), listenedLeaderPosDir) then
        levitate(listenedLeaderDir); return
      end
      if useRope(leaderPos) then return end
      handleUsing()
    end
  else
    if _G and _G.listenedLeaderPosDir then _G.listenedLeaderPosDir = nil end
    if _G and _G.listenedLeaderDir then _G.listenedLeaderDir = nil end

    local lpos = leader:getPosition()
    if lpos then
      local dist = getDistanceBetween(player:getPosition(), lpos)
      if dist >= 2 then
        if getStandTime() > 100 then
          if autoWalk(lpos, 40, { ignoreNonPathable = true, precision = 1, ignoreCreatures = true }) then
            delay(100); return
          end
        end
      end

      autoUseNearbyDoors(leader, 3)

      if dist > 1 and not findPath(player:getPosition(), lpos, 20, { ignoreNonPathable = true, precision = 1 }) then
        handleUsing()
      end
    else
      leader = nil
    end
  end
end)

BotServerFollow = macro(1000000, "With BotServer", function() end)

UI.Label("Player Name:")
UI.TextEdit(storage.followLeader or "Name", function(widget, text)
  storage.followLeader = text or ""
  if storage.followLeader ~= "" then leader = getCreatureByName(storage.followLeader) else leader = nil end
end)

-- ====== (NOVO) helper: respeitar botão ON/OFF do macro ======
local function followIsOn()
  return ultimateFollow and ultimateFollow.isOn and ultimateFollow:isOn()
end

onCreaturePositionChange(function(creature, newPos, oldPos)
  if not followIsOn() then return end
  if creature:getName() == player:getName() then standTime = now; return end

  local followName = getFollowName()
  if followName == "" then return end
  if creature:getName():lower() ~= followName:lower() then return end

  if newPos then
    leaderPositions[newPos.z] = newPos
    lastLeaderFloor = newPos.z
    if newPos.z == posz() then leader = creature else leader = nil end
  else
    leader = nil
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
    leader = creature
  elseif creature:getName() == player:getName() then
    if lastLeaderFloor and lastLeaderFloor == posz() then
      leader = getCreatureByName(followName)
    end
  end
end)

onCreatureDisappear(function(creature)
  if not followIsOn() then return end
  local followName = getFollowName()
  if followName ~= "" and creature:getName():lower() == followName:lower() then
    leader = nil
    return
  end
  if creature:getName() == player:getName() then
    if lastLeaderFloor and posz() ~= lastLeaderFloor then leader = nil end
  end
end)

function getFollowName()
  local name = storage.followLeader
  if not name or name == "" then return "" end
  return name
end

UI.Label("Follow - Bad Boys")

local followThis = tostring(storage.followLeader)

FloorChangers = {
    Ladders = {
        Up = {1948, 5542, 16693, 16692, 8065, 8263},
        Down = {432, 412, 469, 1949, 469}
    },

    Holes = {
        Up = {},
        Down = {293, 294, 595, 4728, 385, 9853}
    },

    RopeSpots = {
        Up = {386,},
        Down = {}
    },

    Stairs = {
        Up = {16690, 1958, 7548, 7544, 1952, 1950, 1947, 7542, 855, 856, 1978, 1977, 6911, 6915, 1954, 5259, 20492, 1956, 1957, 1955, 5257, 5258, 775, 25058, 22566, 22747, 30757, 20225, 20253, 25050, 25056, 25058, 25054},
        Down = {482, 414, 413, 437, 7731, 469, 413, 434, 469, 859, 438, 6127, 566, 7476, 4826, 484, 433, 369, 20259, 19960, 411}
    },

    Sewers = {
        Up = {},
        Down = {435}
    },
}



local target = followThis
local lastKnownPosition

local function goLastKnown()
    if getDistanceBetween(pos(), {x = lastKnownPosition.x, y = lastKnownPosition.y, z = lastKnownPosition.z}) > 1 then
        local newTile = g_map.getTile({x = lastKnownPosition.x, y = lastKnownPosition.y, z = lastKnownPosition.z})
        if newTile then
            g_game.use(newTile:getTopUseThing())
            delay(math.random(300, 700))
        end
    end
end

local function handleUse(pos)
    goLastKnown()
    local lastZ = posz()
    if posz() == lastZ then
        local newTile = g_map.getTile({x = pos.x, y = pos.y, z = pos.z})
        if newTile then
            g_game.use(newTile:getTopUseThing())
            delay(math.random(400, 800))
        end
    end
end

local function handleStep(pos)
    goLastKnown()
    local lastZ = posz()
    if posz() == lastZ then
        autoWalk(pos)
        delay(math.random(400, 800))
    end
end

local function handleRope(pos)
    goLastKnown()
    local lastZ = posz()
    if posz() == lastZ then
        local newTile = g_map.getTile({x = pos.x, y = pos.y, z = pos.z})
        if newTile then
            useWith(3003, newTile:getTopUseThing())
            delay(math.random(400, 800))
        end
    end
end

local floorChangeSelector = {
    Ladders = {Up = handleUse, Down = handleStep},
    Holes = {Up = handleStep, Down = handleStep},
    RopeSpots = {Up = handleRope, Down = handleRope},
    Stairs = {Up = handleStep, Down = handleStep},
    Sewers = {Up = handleUse, Down = handleUse},
}

local function checkTargetPos()
    local c = getCreatureByName(target)
    if c and c:getPosition().z == posz() then
        lastKnownPosition = c:getPosition()
    end
end

local function distance(pos1, pos2)
    local pos2 = pos2 or lastKnownPosition or pos()
    return math.abs(pos1.x - pos2.x) + math.abs(pos1.y - pos2.y)
end

local function executeClosest(possibilities)
    local closest
    local closestDistance = 99999
    for _, data in ipairs(possibilities) do
        local dist = distance(data.pos)
        if dist < closestDistance then
            closest = data
            closestDistance = dist
        end
    end

    if closest then
        closest.changer(closest.pos)
    end
end

local function handleFloorChange()
    local c = getCreatureByName(target)
    local range = 2
    local p = pos()
    local possibleChangers = {}
    for _, dir in ipairs({"Down", "Up"}) do
        for changer, data in pairs(FloorChangers) do
            for x = -range, range do
                for y = -range, range do
                    local tile = g_map.getTile({x = p.x + x, y = p.y + y, z = p.z})
                    if tile then
                        if table.find(data[dir], tile:getTopUseThing():getId()) then
                            table.insert(possibleChangers, {changer = floorChangeSelector[changer][dir], pos = {x = p.x + x, y = p.y + y, z = p.z}})
                        end
                    end
                end
            end
        end
    end
    executeClosest(possibleChangers)
end

local function targetMissing()
    for _, n in ipairs(getSpectators(false)) do
        if n:getName() == target then
            return n:getPosition().z ~= posz()
        end
    end
    return true
end


Follow = macro(1000,"Follow",function()

nome = storage.followLeader
end)

UI.Label("Follow Player:")
addTextEdit("playerToFollow", storage.followLeader or "Guarda Chulapa", function(widget, text)
    storage.followLeader = text
    target = tostring(text)
end)

nome = storage.followLeader
pos_p = player:getPosition()

p = getCreatureByName(nome)

onCreaturePositionChange(function(creature, newPos, oldPos)
    if Follow.isOn() then
    
        if creature:getName()==player:getName() and getCreatureByName(nome) == nil and newPos.z>oldPos.z then
        
            say('exani tera')
            for i = -1,1 do
              for j = -1,1 do
            
                local useTile = g_map.getTile({x=posx()+i,y=posy()+j,z=posz()})
                 g_game.use(useTile:getTopUseThing())
                
            
              end
            end
        end
        if creature:getName()==nome then
          
            
            if newPos==nil then
                
                
                lastPos = oldPos
                
                schedule(200,function()
                 autoWalk(oldPos)
                end)
                
                schedule(1000,function()
                    for i = -1,1 do
                      for j = -1,1 do
                    
                        local useTile = g_map.getTile({x=posx()+i,y=posy()+j,z=posz()})
                        g_game.use(useTile:getTopUseThing())
                        
                    
                      end
                    end
                end)
            
            
            end
            
            if oldPos.z == newPos.z then
                     
                schedule(300,function()
                 local useTile = g_map.getTile({x=oldPos.x,y=oldPos.y,z=oldPos.z})
                 topThing = useTile:getTopThing()
                 
                 if not useTile:isWalkable() then
                   use(topThing)
                 end
                
                end)
            
            
                autoWalk({x=oldPos.x,y=oldPos.y,z=oldPos.z})
            else
            
                lastPos = oldPos
                autoWalk(oldPos)
                for i = 1,6 do
                    schedule(i*200,function()
                      autoWalk(oldPos)
                    
                      if getDistanceBetween(pos(), oldPos) == 0 and (posz()>newPos.z and getCreatureByName(nome) == nil) then
                        say('exani tera')
                      end
                    end)
                end
                local useTile = g_map.getTile({x=newPos.x,y=newPos.y-1,z=oldPos.z})
                 g_game.use(useTile:getTopUseThing())
                            
            
            end
          
        
        end
    
    end
end)

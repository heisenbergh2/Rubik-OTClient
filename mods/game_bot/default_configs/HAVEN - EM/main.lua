-- main tab
VERSION = "15.21"

UI.Label("HAVEN OPTIONAL-PVP " .. VERSION)
UI.Label("BAD BOYS OT SERVERS")

UI.Separator()

UI.Button("Site Haven - Bad Boys OT", function()
  g_platform.openUrl("https://haven.badboysot.com")
end)

UI.Button("Discord", function()
  g_platform.openUrl("https://discord.com/invite/mUU83bWndd")
end)

UI.Button("Whatsapp Group", function()
  g_platform.openUrl("http://wa.me/5554996516912/")
end)

UI.Separator()

local txtImbuis = UI.Label()
txtImbuis:setColor("yellow")
txtImbuis:setText("BBTC MONK")
UI.Separator()

local txtImbuis = UI.Label()
txtImbuis:setColor("green")
txtImbuis:setText("Ataque Spells")

macro(250, "EM AOE", nil, function()
  if not g_game.isAttacking() then return end
  say("exori mas pug")
  delay(2000)
  say("exori gran mas pug")
  delay(2000)
end)

local pvp = false
local Spells = {
  {name = "exori mas nia", cast = true, amount = 1, distance = 1, manaCost = 10, level = 60},
  {name = "exori mas pug", cast = true, amount = 1, distance = 1, manaCost = 28, level = 60},
  {name = "exori gran mas pug", cast = true, amount = 1, distance = 1, safe = true, manaCost = 70, level = 55},
}

macro(500, "EM ROTATION", function()
  if not g_game.isAttacking() then return end

  local target = g_game.getAttackingCreature()
  if not target then return end

  local isSafe = true
  local direct
  local whitelistMonsters = {"Paladin Familiar","Knight Familiar","Druid Familiar","Sorcerer Familiar"}

  if player:getPosition().z == target:getPosition().z then
    if player:getPosition().x > target:getPosition().x then direct = 3
    elseif player:getPosition().x < target:getPosition().x then direct = 1
    elseif player:getPosition().y > target:getPosition().y then direct = 0
    elseif player:getPosition().y < target:getPosition().y then direct = 2 end
  end

  for _, spell in ipairs(Spells) do
    local count = 0
    for _, mob in ipairs(getSpectators()) do
      if mob:isMonster() and getDistanceBetween(player:getPosition(), mob:getPosition()) <= spell.distance then
        if not table.find(whitelistMonsters, mob:getName()) then
          count = count + 1
        end
      end
      if mob:isPlayer() and mob:getName() ~= player:getName() then
        isSafe = false
      end
    end

    if spell.cast and count >= spell.amount and mana() >= spell.manaCost and lvl() >= spell.level then
      say(spell.name)
      delay(300)
    end
  end
end)

UI.Separator()
local txtImbuis = UI.Label()
txtImbuis:setColor("green")
txtImbuis:setText("Magias e Utilitários")

macro(2000, "Auto Spell", function()
  if storage.AutoSpell and storage.AutoSpell ~= "" then
    say(storage.AutoSpell)
  end
end)

addTextEdit("AutoSpell", storage.AutoSpell or "", function(_, text)
  storage.AutoSpell = text
end)

macro(2500, "Exori Gran Mas Nia", function() saySpell("exori gran mas nia",200) end)
macro(4000, "Exori Mas Nia", function() saySpell("exori mas nia",200) end)
macro(2500, "Exori Gran Nia", function() saySpell("exori gran nia",200) end)
macro(2500, "Exori Med Pug", function() saySpell("exori med pug",200) end)
macro(2500, "Exori Gran Pug", function() saySpell("exori gran pug",200) end)
macro(2500, "Exori Amp Pug", function() saySpell("exori amp pug",200) end)

-- =========================
-- MAGIAS DE SUPORTE
-- =========================

macro(2500, "Utevo Nia", function()
    saySpell("utevo nia", 200)
    delay(3000)
end)

macro(2500, "Utamo Tio", function()
    saySpell("utamo tio", 200)
    delay(3000)
end)

macro(2500, "Exura Mas Nia", function()
    saySpell("exura mas nia", 200)
    delay(3000)
end)

macro(2500, "Utori Virtu", function()
    saySpell("utori virtu", 200)
    delay(3000)
end)

macro(2500, "Utito Virtu", function()
    saySpell("utito virtu", 200)
    delay(3000)
end)

macro(2500, "Utura Tio", function()
    saySpell("utura tio", 200)
    delay(3000)
end)

macro(4000, "Utevo Mas Sio", function()
    saySpell("utevo mas sio", 200)
    delay(30000)
end)

macro(2500, "Exori Mas Res", function()
    saySpell("exori mas res", 200)
    delay(3000)
end)


macro(3000, "Exana pox", function()
  if g_game.isAttacking() then
    say("exana pox")
  end
end)

macro(15000, "FireCamp", function()
  if g_game.isAttacking() then
    g_game.useInventoryItemWith(3192, player)
  end
end)

UI.Label("Auto Amulets")

UI.Label("AMULET ID:")
UI.TextEdit(storage.ssaId or "3081", function(widget, text)
  storage.ssaId = tonumber(text)
end)

macro(500, "Auto Amulet", function()
  local ssaId = storage.ssaId
  local amuletId = storage.amuletId
  if not ssaId or not amuletId then return end

  local neck = getNeck()
  if neck and neck:getId() == ssaId then return end

  local ssaItem = findItem(ssaId)
  if ssaItem then
    g_game.move(ssaItem, {x = 65535, y = 2, z = 0}, 1)
    return
  end

  local amuletItem = findItem(amuletId)
  if amuletItem and (not neck or neck:getId() ~= amuletId) then
    g_game.move(amuletItem, {x = 65535, y = 2, z = 0}, 1)
  end
end)

UI.Separator()

UI.Label("Auto Ring")

UI.Label("RING ID:")
UI.TextEdit(storage.mightRingId or "3048", function(widget, text)
  storage.mightRingId = tonumber(text)
end)

macro(500, "Auto Ring", function()
  local mightRingId = storage.mightRingId
  local mainRingId = storage.mainRingId
  if not mightRingId or not mainRingId then return end

  local ring = getFinger()
  if ring and ring:getId() == mightRingId then return end

  local mightRing = findItem(mightRingId)
  if mightRing then
    g_game.move(mightRing, {x = 65535, y = 9, z = 0}, 1)
    return
  end

  local normalRing = findItem(mainRingId)
  if normalRing and (not ring or ring:getId() ~= mainRingId) then
    g_game.move(normalRing, {x = 65535, y = 9, z = 0}, 1)
  end
end)

local gpHealFriends = {}
local gpHealPercent = 75

local enableHealFriends = macro(1000, "Exura Tio Sio", function()
end)


addLabel("gpHealFriendLabel", "Friends:")
addTextEdit("healfriend", table.concat(gpHealFriends, ","), function(widget, text)   
  setFriends(text)
  widget:setText(text)
end)

onCreatureHealthPercentChange(function (creature, healthPrecent)
  checkFriend(creature)
end)

onCreatureAppear(function (creature)
  checkFriend(creature)
end)

onCreaturePositionChange (function ()
  checkFriends()
end)

function checkFriends()
    if enableHealFriends:isOff() then
        return
    end
    local spectators = getSpectators(pos(), false)
    for i, spec in pairs(spectators) do
        checkFriend(spec)
    end
end

function checkFriend(creature)
  if enableHealFriends:isOff() or not creature:isPlayer() then
    return
  end

  if not table.contains(gpHealFriends, creature:getName()) then
    return
  end

  if creature:getHealthPercent() <= gpHealPercent then
    say(string.format("exura tio sio \"%s", creature:getName()))
  end
end

function setFriends(text)
  local result = {}
  for friend in text:gmatch("([^,]+)") do
    table.insert(result, friend)
  end

  gpHealFriends = result
end

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

UI.Separator()
UI.Label({text = "Runas e Itens", color = "green"})

sdMacro = macro(1000,"Sudden Death",function()
  local t=g_game.getAttackingCreature()
  if t then useWith(3155,t) end
end)
addIcon("sdIcon",{item=3155,text="SD"},sdMacro)

gfbMacro = macro(800,"Great Fireball",function()
  local t=g_game.getAttackingCreature()
  if t then useWith(3191,t) end
end)
addIcon("gfbIcon",{item=3191,text="GFB"},gfbMacro)

avaMacro = macro(1000,"Avalanche",function()
  local t=g_game.getAttackingCreature()
  if t then useWith(3161,t) end
end)
addIcon("avaIcon",{item=3161,text="AVA"},avaMacro)

tsMacro = macro(1000,"Thunderstorm",function()
  local t=g_game.getAttackingCreature()
  if t then useWith(3202,t) end
end)
addIcon("tsIcon",{item=3202,text="TS"},tsMacro)

ssMacro = macro(1000,"Stone Shower",function()
  local t=g_game.getAttackingCreature()
  if t then useWith(3175,t) end
end)
addIcon("ssIcon",{item=3175,text="SS"},ssMacro)

macro(500,"Stamina",function()
  if stamina() < 2400 then use(36725) end
end)

UI.Separator()

UI.Label("BAD BOYS OPEN TIBIA SERVERS")
UI.Label("BY BAD BOYS GUILD - 16 YEARS")

UI.Separator()
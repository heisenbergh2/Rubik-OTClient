
addSeparator()
setDefaultTab("Suport")
addSeparator()
local spells = {}

local addSpell = function(spell, dist, delay, isSafe)
  table.insert(spells, {
    spell = spell:lower(),
    dist = dist,
    delay = delay,
    isSafe = isSafe,
    nextAvailableTime = 0
  })
end

-- [Config]
local safe = false
local notSafe = false

-- [spell], [distance], [delay seconds], [isSafe]
--[spell], [distance], [delay] in seconds, [isSafe]
addSpell("Exori Gran Ico", 1, 2, safe)
addSpell("Exori Gran", 1, 2, notSafe)
addSpell("Exori", 1, 2, notSafe)
addSpell("Exori mas", 1, 2, notSafe)
addSpell("Exori Hur", 5, 1, safe)
addSpell("Exori Ico", 1, 1, safe)

local safeDistance = 8
local delayBetweenSpells = 1000
local keepUtitoWhileAttacking = true
local multifloorCheck = false

-- [Skulls To Attack]
local SkullYellow = 1
local SkullWhite = 3
local SkullRed = 4
local SkullBlack = 5
local SkullOrange = 6
local PKSkulls = { SkullWhite, SkullRed, SkullBlack }

local spellIndex = 1
local lastSpell = 0

local function hasPkSkull(spec)
  return table.find(PKSkulls, spec:getSkull())
end

local function hasNonPKPlayer()
  for _, spec in pairs(getSpectators(multifloorCheck)) do
    if spec:isPlayer() and not spec:isLocalPlayer() and distanceFromPlayer(spec:getPosition()) <= safeDistance then
      if not table.find(storage.playerList.friendList, spec:getName(), true) and not hasPkSkull(spec) then
        return true
      end
    end
  end
  return false
end

local function nextSpell()
  spellIndex = (spellIndex % #spells) + 1
end

macro(50, "Custom EK Rotation [PK]", function()
  local target = g_game.getAttackingCreature()
  if not target then return end
  if now < lastSpell then return end

  if keepUtitoWhileAttacking and not hasPartyBuff() then
    say("Utito Tempo")
    lastSpell = now + 1000
    return
  end

  local currentSpell = spells[spellIndex]
  if not currentSpell then return end

  local dist = distanceFromPlayer(target:getPosition())
  local playersNearby = hasNonPKPlayer()

  -- Verifica se a magia pode ser usada com segurança
  if (currentSpell.isSafe and playersNearby) or (not currentSpell.isSafe and not playersNearby) then
    nextSpell()
    return
  end

  -- Verifica cooldown e distância
  if now >= currentSpell.nextAvailableTime and dist <= currentSpell.dist then
    say(currentSpell.spell)
    currentSpell.nextAvailableTime = now + currentSpell.delay * 1000
    lastSpell = now + delayBetweenSpells
    nextSpell()
  end
end)

-- Atualiza cooldown manualmente se o jogador usar a magia pelo chat
onTalk(function(name, level, mode, text, channelId, pos)
  if name ~= player:getName() then return end
  for i, spellInfo in ipairs(spells) do
    if spellInfo.spell == text:lower() then
      spells[i].nextAvailableTime = now + spellInfo.delay * 1000
      lastSpell = now + delayBetweenSpells
      nextSpell()
      break
    end
  end
end)

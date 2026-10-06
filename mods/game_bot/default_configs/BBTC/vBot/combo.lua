setDefaultTab("Main")
local panelName = "combobot"
local ui = setupUI([[
Panel
  height: 19

  BotSwitch
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    text-align: center
    width: 130
    !text: tr('ComboBot')

  Button
    id: combos
    anchors.top: prev.top
    anchors.left: prev.right
    anchors.right: parent.right
    margin-left: 3
    height: 17
    text: Setup
]])
ui:setId(panelName)

-- ================= CONFIG =================
if not storage[panelName] then
  storage[panelName] = {
    enabled = false,
    onSayEnabled = false,
    onShootEnabled = false,
    onCastEnabled = false,
    followLeaderEnabled = false,
    attackLeaderTargetEnabled = false,
    attackSpellEnabled = false,
    attackItemEnabled = false,   -- padronizado
    sayLeader = "",
    shootLeader = "",
    castLeader = "",
    sayPhrase = "",
    spell = "",
    serverLeader = "",
    item = 3155,
    attack = "",
    follow = "",
    commandsEnabled = true,
    serverEnabled = false,
    serverLeaderTarget = false,
    serverTriggers = true
  }
end
local config = storage[panelName]
-- compatibilidade com configs antigas:
if config.attackItemEnabled == nil and config.attackItemToggle ~= nil then
  config.attackItemEnabled = config.attackItemToggle
end

-- ================= ESTADO =================
local startCombo = false
local serverTarget = nil
local leaderTarget = nil

-- Função para detectar spells de ataque (ADICIONADA)
local function isAttSpell(text)
  local attackSpells = {
    "exori", "exevo", "utori", "adori", 
    "vis lux", "kal vas", "corp por", "in vas",
    "gran", "min", "mas", "hur"
  }
  text = text:lower()
  for _, spell in ipairs(attackSpells) do
    if text:find(spell) then return true end
  end
  return false
end

ui.title:setOn(config.enabled)
ui.title.onClick = function(widget)
  config.enabled = not config.enabled
  widget:setOn(config.enabled)
end

ui.combos.onClick = function()
  if comboWindow then
    comboWindow:show()
    comboWindow:raise()
    comboWindow:focus()
  end
end

-- ================= UI EXISTENTE =================
rootWidget = g_ui.getRootWidget()
if rootWidget then
  comboWindow = UI.createWindow('ComboWindow', rootWidget)
  comboWindow:hide()

  -- bot item
  comboWindow.actions.attackItem:setItemId(config.item)
  comboWindow.actions.attackItem.onItemChange = function(widget)
    config.item = widget:getItemId()
  end

  -- switches
  comboWindow.actions.commandsToggle:setOn(config.commandsEnabled)
  comboWindow.actions.commandsToggle.onClick = function(widget)
    config.commandsEnabled = not config.commandsEnabled
    widget:setOn(config.commandsEnabled)
  end

  comboWindow.server.botServerToggle:setOn(config.serverEnabled)
  comboWindow.server.botServerToggle.onClick = function(widget)
    config.serverEnabled = not config.serverEnabled
    widget:setOn(config.serverEnabled)
  end

  comboWindow.server.Triggers:setOn(config.serverTriggers)
  comboWindow.server.Triggers.onClick = function(widget)
    config.serverTriggers = not config.serverTriggers
    widget:setOn(config.serverTriggers)
  end

  comboWindow.server.targetServerLeaderToggle:setOn(config.serverLeaderTarget)
  comboWindow.server.targetServerLeaderToggle.onClick = function(widget)
    config.serverLeaderTarget = not config.serverLeaderTarget
    widget:setOn(config.serverLeaderTarget)
  end

  -- buttons
  comboWindow.closeButton.onClick = function() comboWindow:hide() end

  -- combo boxes
  comboWindow.actions.followLeader:setOption(config.follow)
  comboWindow.actions.followLeader.onOptionChange = function(widget)
    config.follow = widget:getCurrentOption().text
  end

  comboWindow.actions.attackLeaderTarget:setOption(config.attack)
  comboWindow.actions.attackLeaderTarget.onOptionChange = function(widget)
    config.attack = widget:getCurrentOption().text
  end

  -- checkboxes
  comboWindow.trigger.onSayToggle:setChecked(config.onSayEnabled)
  comboWindow.trigger.onSayToggle.onClick = function(widget)
    config.onSayEnabled = not config.onSayEnabled
    widget:setChecked(config.onSayEnabled)
  end

  comboWindow.trigger.onShootToggle:setChecked(config.onShootEnabled)
  comboWindow.trigger.onShootToggle.onClick = function(widget)
    config.onShootEnabled = not config.onShootEnabled
    widget:setChecked(config.onShootEnabled)
  end

  comboWindow.trigger.onCastToggle:setChecked(config.onCastEnabled)
  comboWindow.trigger.onCastToggle.onClick = function(widget)
    config.onCastEnabled = not config.onCastEnabled
    widget:setChecked(config.onCastEnabled)
  end

  comboWindow.actions.followLeaderToggle:setChecked(config.followLeaderEnabled)
  comboWindow.actions.followLeaderToggle.onClick = function(widget)
    config.followLeaderEnabled = not config.followLeaderEnabled
    widget:setChecked(config.followLeaderEnabled)
  end

  comboWindow.actions.attackLeaderTargetToggle:setChecked(config.attackLeaderTargetEnabled)
  comboWindow.actions.attackLeaderTargetToggle.onClick = function(widget)
    config.attackLeaderTargetEnabled = not config.attackLeaderTargetEnabled
    widget:setChecked(config.attackLeaderTargetEnabled)
  end

  comboWindow.actions.attackSpellToggle:setChecked(config.attackSpellEnabled)
  comboWindow.actions.attackSpellToggle.onClick = function(widget)
    config.attackSpellEnabled = not config.attackSpellEnabled
    widget:setChecked(config.attackSpellEnabled)
  end

  comboWindow.actions.attackItemToggle:setChecked(config.attackItemEnabled)
  comboWindow.actions.attackItemToggle.onClick = function(widget)
    config.attackItemEnabled = not config.attackItemEnabled
    widget:setChecked(config.attackItemEnabled)
  end

  -- text edits
  comboWindow.trigger.onSayLeader:setText(config.sayLeader)
  comboWindow.trigger.onSayLeader.onTextChange = function(widget, text) config.sayLeader = text end

  comboWindow.trigger.onShootLeader:setText(config.shootLeader)
  comboWindow.trigger.onShootLeader.onTextChange = function(widget, text) config.shootLeader = text end

  comboWindow.trigger.onCastLeader:setText(config.castLeader)
  comboWindow.trigger.onCastLeader.onTextChange = function(widget, text) config.castLeader = text end

  comboWindow.trigger.onSayPhrase:setText(config.sayPhrase)
  comboWindow.trigger.onSayPhrase.onTextChange = function(widget, text) config.sayPhrase = text end

  comboWindow.actions.attackSpell:setText(config.spell)
  comboWindow.actions.attackSpell.onTextChange = function(widget, text) config.spell = text end

  comboWindow.server.botServerLeader:setText(config.serverLeader)
  comboWindow.server.botServerLeader.onTextChange = function(widget, text) config.serverLeader = text end
end

-- ================= BOT SERVER / PARTY =================
-- [[ join party made by Frosty ]] --
local shouldCloseWindow = false
local firstInvitee = true
local isInComboTeam = false

macro(10, function()
  if shouldCloseWindow and config.serverEnabled and config.enabled then
    local channelsWindow = modules.game_console.channelsWindow
    if channelsWindow then
      local child = channelsWindow:getChildById("buttonCancel")
      if child then
        child:onClick()
        shouldCloseWindow = false
        isInComboTeam = true
      end
    end
  end
end)

-- Party: protegido contra canal nil
comboWindow.server.partyButton.onClick = function()
  if config.serverEnabled and config.enabled then
    local chan = tostring(storage.BotServerChannel or "")
    if (config.serverLeader or ""):len() > 0 and chan:len() > 0 then
      talkPrivate(config.serverLeader, "request invite " .. chan)
    else
      error("Request failed. Lack of data.")
    end
  end
end

-- Aceitar convite (nome com espaço)
onTextMessage(function(mode, text)
  if not (config.serverEnabled and config.enabled) then return end
  if mode ~= 20 then return end
  if not text:find("invited you to") then return end

  local leaderName = text:match("^(.-) invited you to")
  if leaderName and (config.serverLeader or ""):len() > 0
     and leaderName:lower() == config.serverLeader:lower() then
    local leader = getCreatureByName(leaderName)
    if leader then
      g_game.partyJoin(leader:getId())
      g_game.requestChannels()
      g_game.joinChannel(1)
      shouldCloseWindow = true
    end
  end
end)

-- PM para convite
onTalk(function(name, level, mode, text, channelId, pos)
  if config.serverEnabled and config.enabled and mode == 4 then
    if text:find("request invite") then
      local access = text:match("%d.*")
      local chan = tostring(storage.BotServerChannel or "")
      if access and access == chan then
        local minion = getCreatureByName(name)
        if minion then
          g_game.partyInvite(minion:getId())
          if firstInvitee then
            g_game.requestChannels()
            g_game.joinChannel(1)
            shouldCloseWindow = true
            firstInvitee = false
          end
        end
      else
        talkPrivate(name, "Incorrect access key!")
      end
    end
  end
  -- [[ End of Frosty's Code ]]

  -- Triggers locais
  if config.enabled then
    if (config.sayLeader or ""):len() > 0
       and name:lower() == (config.sayLeader or ""):lower()
       and (config.onSayEnabled and text:find(config.sayPhrase or "")) then
      startCombo = true
    end
    if (config.castLeader or ""):len() > 0
       and name:lower() == (config.castLeader or ""):lower()
       and (config.onCastEnabled and isAttSpell(text)) then
      startCombo = true
    end
  end

  -- Comandos por texto (precedência correta)
  if config.enabled and config.commandsEnabled and (
      ((config.shootLeader or ""):len() > 0 and name:lower() == (config.shootLeader or ""):lower()) or
      ((config.sayLeader   or ""):len() > 0 and name:lower() == (config.sayLeader   or ""):lower()) or
      ((config.castLeader  or ""):len() > 0 and name:lower() == (config.castLeader  or ""):lower())
    ) then

    if text:find("ue") then
      if (config.spell or ""):len() > 0 then say(config.spell) end

    elseif text:find("sd") then
      local params = string.split(text, ",")
      if #params == 2 then
        local targetName = params[2]:trim()
        local c = getCreatureByName(targetName)
        if c then useWith(3155, c) end
      end

    elseif text:find("att") then
      local attParams = string.split(text, ",")
      if #attParams == 2 then
        local atTarget = attParams[2]:trim()
        local c = getCreatureByName(atTarget)
        if c and config.attack == "COMMAND TARGET" then g_game.attack(c) end
      end
    end
  end

  -- Somente o líder emite trigger "start" para o servidor
  if isAttSpell(text) and config.enabled and config.serverEnabled
     and (config.serverLeader or ""):len() > 0
     and name:lower() == config.serverLeader:lower() then
    if BotServer and BotServer.send then
      BotServer.send("trigger", "start")
    end
  end
end)

-- ================= MISSILE (On Shoot) - CORREÇÃO BASEADA NO SCRIPT FUNCIONANDO =================
onMissle(function(missle)
  if not (config.enabled and config.onShootEnabled) then return end
  if not config.shootLeader or config.shootLeader:len() == 0 then return end

  local src = missle:getSource()
  if src.z ~= posz() then return end

  local from = g_map.getTile(src)
  local to = g_map.getTile(missle:getDestination())
  if not from or not to then return end

  local fromCreatures = from:getCreatures()
  local toCreatures = to:getCreatures()
  if #fromCreatures ~= 1 or #toCreatures ~= 1 then return end

  local c1 = fromCreatures[1]
  local t1 = toCreatures[1]
  
  -- VERIFICA SE É O LEADER ATIRANDO
  if c1:getName():lower() == config.shootLeader:lower() then
    leaderTarget = t1
    
    -- CORREÇÃO PRINCIPAL: ATACA IMEDIATAMENTE como no script funcionando
    if config.attackLeaderTargetEnabled and config.attack == "LEADER TARGET" then
      local currentTarget = g_game.getAttackingCreature()
      if not currentTarget or currentTarget ~= t1 then
        g_game.attack(t1)
      end
    end
    
    -- Executa outras ações
    if config.attackItemEnabled and config.item and config.item > 100 and findItem(config.item) then
      useWith(config.item, t1)
    end
    if config.attackSpellEnabled and (config.spell or ""):len() > 1 then
      say(config.spell)
    end
  end
end)

-- ================= ATAQUE: seguir alvo do líder (ORIGINAL) =================
macro(10, function()
  if not config.enabled then return end

  -- Leader Target local
  if config.attackLeaderTargetEnabled and leaderTarget and config.attack == "LEADER TARGET" then
    if (not getTarget()) or (getTarget() and getTarget():getName() ~= leaderTarget:getName()) then
      g_game.attack(leaderTarget)
    end
  end

  -- Server Leader Target
  if config.serverEnabled and config.attack == "SERVER LEADER TARGET" and serverTarget then
    if (not getTarget()) or (getTarget() and getTarget():getName() ~= serverTarget:getName()) then
      g_game.attack(serverTarget)
    end
  end
end)

-- ================= FOLLOW (ORIGINAL) =================
local toFollow
local toFollowPos = {}
macro(100, function()
  toFollow = nil
  if not (config.enabled and config.followLeaderEnabled) then return end

  if leaderTarget and config.follow == "LEADER TARGET" and leaderTarget:isPlayer() then
    toFollow = leaderTarget:getName()
  elseif config.follow == "SERVER LEADER TARGET" and (config.serverLeader or ""):len() ~= 0 then
    toFollow = serverTarget and serverTarget:getName() or nil
  elseif config.follow == "SERVER LEADER" and (config.serverLeader or ""):len() ~= 0 then
    toFollow = config.serverLeader
  elseif config.follow == "LEADER" then
    if config.onSayEnabled and (config.sayLeader or ""):len() ~= 0 then
      toFollow = config.sayLeader
    elseif config.onCastEnabled and (config.castLeader or ""):len() ~= 0 then
      toFollow = config.castLeader
    elseif config.onShootEnabled and (config.shootLeader or ""):len() ~= 0 then
      toFollow = config.shootLeader
    end
  end

  if not toFollow then return end
  local target = getCreatureByName(toFollow)
  if target then
    local tpos = target:getPosition()
    toFollowPos[tpos.z] = tpos
  end

  if player:isWalking() then return end
  local p = toFollowPos[posz()]
  if not p then return end
  if CaveBot.walkTo(p, 20, {ignoreNonPathable=true, precision=1, ignoreStairs=false}) then
    delay(100)
  end
end)

onCreaturePositionChange(function(creature, oldPos, newPos)
  if toFollow and creature:getName() == toFollow and newPos then
    toFollowPos[newPos.z] = newPos
  end
end)

-- ================= EXECUÇÃO DO COMBO & ENVIO DE TARGET (ORIGINAL) =================
local lastTargetSend = 0
macro(10, function()
  if not config.enabled then return end

  -- execução local quando startCombo = true
  if startCombo then
    startCombo = false
    if config.attackItemEnabled and config.item and config.item > 100 and findItem(config.item) then
      if getTarget() then
        useWith(config.item, getTarget())
      end
    end
    if config.attackSpellEnabled and (config.spell or ""):len() > 1 then
      say(config.spell)
    end
  end

  -- enviar nome do alvo ao BotServer (a cada 500ms)
  if BotServer and BotServer._websocket and config.serverEnabled then
    local t = getTarget()
    if t and now - lastTargetSend > 500 then
      BotServer.send("target", t:getName())
      lastTargetSend = now
    end
  end
end)

-- replicar useWith (ex.: SD)
onUseWith(function(pos, itemId, target, subType)
  if BotServer and BotServer._websocket and itemId == 3155 and target then
    BotServer.send("useWith", target:getPosition())
  end
end)

-- ================= LISTENERS DO BOTSERVER (ORIGINAL) =================
local listenersRegistered = false
local function registerBotServerListeners()
  if listenersRegistered then return end
  if not (BotServer and BotServer._websocket) then return end

  BotServer.listen("trigger", function(name, message)
    if not (config.enabled and config.serverEnabled) then return end
    if message == "start"
       and name:lower() ~= player:getName():lower()
       and (config.serverLeader or ""):len() > 0
       and name:lower() == config.serverLeader:lower()
       and config.serverTriggers then
      startCombo = true
    end
  end)

  BotServer.listen("target", function(name, message)
    if not (config.enabled and config.serverEnabled) then return end
    if name:lower() ~= player:getName():lower()
       and (config.serverLeader or ""):len() > 0
       and name:lower() == config.serverLeader:lower() then
      local creature = getCreatureByName(message)
      if creature and config.serverLeaderTarget then
        serverTarget = creature
        if (not getTarget()) or (getTarget():getName() ~= creature:getName()) then
          g_game.attack(creature)
        end
      end
    end
  end)

  BotServer.listen("useWith", function(name, message)
    if not (config.enabled and config.serverEnabled) then return end
    if name:lower() ~= player:getName():lower()
       and (config.serverLeader or ""):len() > 0
       and name:lower() == config.serverLeader:lower()
       and config.serverTriggers
       and config.attackItemEnabled
       and config.item
       and findItem(config.item) then
      local tile = g_map.getTile(message)
      if tile and tile:getTopUseThing() then
        useWith(config.item, tile:getTopUseThing())
      end
    end
  end)

  listenersRegistered = true
end

-- macro em background
macro(200, function()
  if not config.serverEnabled then
    listenersRegistered = false
    return
  end
  if not (BotServer and BotServer._websocket) then
    listenersRegistered = false
    return
  end
  registerBotServerListeners()
end)
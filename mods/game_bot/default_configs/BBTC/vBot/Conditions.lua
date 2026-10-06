setDefaultTab("HP")
local panelName = "ConditionPanel"
local ui = setupUI([[
Panel
  height: 19

  BotSwitch
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    text-align: center
    width: 130
    !text: tr('Conditions')

  Button
    id: conditionList
    anchors.top: prev.top
    anchors.left: prev.right
    anchors.right: parent.right
    margin-left: 3
    height: 17
    text: Setup

  ]])
  ui:setId(panelName)

  if not HealBotConfig[panelName] then
    HealBotConfig[panelName] = {
      enabled = false,
      curePosion = false,
      poisonCost = 20,
      cureCurse = false,
      curseCost = 80,
      cureBleed = false,
      bleedCost = 45,
      cureBurn = false,
      burnCost = 30,
      cureElectrify = false,
      electrifyCost = 22,
      cureParalyse = false,
      paralyseCost = 60,
      paralyseSpell = "utani hur",
      holdHaste = false,
      hasteCost = 60,
      hasteSpell = "utani hur",
      holdUtamo = false,
      utamoCost = 50,
      holdUtana = false,
      utanaCost = 440,
      holdUtura = false,
      uturaType = "",
      uturaCost = 100,
      ignoreInPz = true,
      stopHaste = false
    }
  end

  local config = HealBotConfig[panelName]

  ui.title:setOn(config.enabled)
  ui.title.onClick = function(widget)
    config.enabled = not config.enabled
    widget:setOn(config.enabled)
    vBotConfigSave("heal")
  end

  ui.conditionList.onClick = function(widget)
    conditionsWindow:show()
    conditionsWindow:raise()
    conditionsWindow:focus()
  end

  local rootWidget = g_ui.getRootWidget()
  if rootWidget then
    conditionsWindow = UI.createWindow('ConditionsWindow', rootWidget)
    conditionsWindow:hide()

    conditionsWindow.onVisibilityChange = function(widget, visible)
      if not visible then
        vBotConfigSave("heal")
      end
    end

    -- text edits
    conditionsWindow.Cure.PoisonCost:setText(config.poisonCost)
    conditionsWindow.Cure.PoisonCost.onTextChange = function(widget, text)
      config.poisonCost = tonumber(text)
    end

    conditionsWindow.Cure.CurseCost:setText(config.curseCost)
    conditionsWindow.Cure.CurseCost.onTextChange = function(widget, text)
      config.curseCost = tonumber(text)
    end

    conditionsWindow.Cure.BleedCost:setText(config.bleedCost)
    conditionsWindow.Cure.BleedCost.onTextChange = function(widget, text)
      config.bleedCost = tonumber(text)
    end

    conditionsWindow.Cure.BurnCost:setText(config.burnCost)
    conditionsWindow.Cure.BurnCost.onTextChange = function(widget, text)
      config.burnCost = tonumber(text)
    end

    conditionsWindow.Cure.ElectrifyCost:setText(config.electrifyCost)
    conditionsWindow.Cure.ElectrifyCost.onTextChange = function(widget, text)
      config.electrifyCost = tonumber(text)
    end

    conditionsWindow.Cure.ParalyseCost:setText(config.paralyseCost)
    conditionsWindow.Cure.ParalyseCost.onTextChange = function(widget, text)
      config.paralyseCost = tonumber(text)
    end

    conditionsWindow.Cure.ParalyseSpell:setText(config.paralyseSpell)
    conditionsWindow.Cure.ParalyseSpell.onTextChange = function(widget, text)
      config.paralyseSpell = text
    end

    conditionsWindow.Hold.HasteSpell:setText(config.hasteSpell)
    conditionsWindow.Hold.HasteSpell.onTextChange = function(widget, text)
      config.hasteSpell = text
    end

    conditionsWindow.Hold.HasteCost:setText(config.hasteCost)
    conditionsWindow.Hold.HasteCost.onTextChange = function(widget, text)
      config.hasteCost = tonumber(text)
    end

    conditionsWindow.Hold.UtamoCost:setText(config.utamoCost)
    conditionsWindow.Hold.UtamoCost.onTextChange = function(widget, text)
      config.utamoCost = tonumber(text)
    end

    conditionsWindow.Hold.UtanaCost:setText(config.utanaCost)
    conditionsWindow.Hold.UtanaCost.onTextChange = function(widget, text)
      config.utanaCost = tonumber(text)
    end

    conditionsWindow.Hold.UturaCost:setText(config.uturaCost)
    conditionsWindow.Hold.UturaCost.onTextChange = function(widget, text)
      config.uturaCost = tonumber(text)
    end

    -- combo box
    conditionsWindow.Hold.UturaType:setOption(config.uturaType)
    conditionsWindow.Hold.UturaType.onOptionChange = function(widget)
      config.uturaType = widget:getCurrentOption().text
    end

    -- checkboxes
    conditionsWindow.Cure.CurePoison:setChecked(config.curePoison)
    conditionsWindow.Cure.CurePoison.onClick = function(widget)
      config.curePoison = not config.curePoison
      widget:setChecked(config.curePoison)
    end

    conditionsWindow.Cure.CureCurse:setChecked(config.cureCurse)
    conditionsWindow.Cure.CureCurse.onClick = function(widget)
      config.cureCurse = not config.cureCurse
      widget:setChecked(config.cureCurse)
    end

    conditionsWindow.Cure.CureBleed:setChecked(config.cureBleed)
    conditionsWindow.Cure.CureBleed.onClick = function(widget)
      config.cureBleed = not config.cureBleed
      widget:setChecked(config.cureBleed)
    end

    conditionsWindow.Cure.CureBurn:setChecked(config.cureBurn)
    conditionsWindow.Cure.CureBurn.onClick = function(widget)
      config.cureBurn = not config.cureBurn
      widget:setChecked(config.cureBurn)
    end

    conditionsWindow.Cure.CureElectrify:setChecked(config.cureElectrify)
    conditionsWindow.Cure.CureElectrify.onClick = function(widget)
      config.cureElectrify = not config.cureElectrify
      widget:setChecked(config.cureElectrify)
    end

    conditionsWindow.Cure.CureParalyse:setChecked(config.cureParalyse)
    conditionsWindow.Cure.CureParalyse.onClick = function(widget)
      config.cureParalyse = not config.cureParalyse
      widget:setChecked(config.cureParalyse)
    end

    conditionsWindow.Hold.HoldHaste:setChecked(config.holdHaste)
    conditionsWindow.Hold.HoldHaste.onClick = function(widget)
      config.holdHaste = not config.holdHaste
      widget:setChecked(config.holdHaste)
    end

    conditionsWindow.Hold.HoldUtamo:setChecked(config.holdUtamo)
    conditionsWindow.Hold.HoldUtamo.onClick = function(widget)
      config.holdUtamo = not config.holdUtamo
      widget:setChecked(config.holdUtamo)
    end

    conditionsWindow.Hold.HoldUtana:setChecked(config.holdUtana)
    conditionsWindow.Hold.HoldUtana.onClick = function(widget)
      config.holdUtana = not config.holdUtana
      widget:setChecked(config.holdUtana)
    end

    conditionsWindow.Hold.HoldUtura:setChecked(config.holdUtura)
    conditionsWindow.Hold.HoldUtura.onClick = function(widget)
      config.holdUtura = not config.holdUtura
      widget:setChecked(config.holdUtura)
    end

    conditionsWindow.Hold.IgnoreInPz:setChecked(config.ignoreInPz)
    conditionsWindow.Hold.IgnoreInPz.onClick = function(widget)
      config.ignoreInPz = not config.ignoreInPz
      widget:setChecked(config.ignoreInPz)
    end

    conditionsWindow.Hold.StopHaste:setChecked(config.stopHaste)
    conditionsWindow.Hold.StopHaste.onClick = function(widget)
      config.stopHaste = not config.stopHaste
      widget:setChecked(config.stopHaste)
    end

    -- buttons
    conditionsWindow.closeButton.onClick = function(widget)
      conditionsWindow:hide()
    end

    Conditions = {}
    Conditions.show = function()
      conditionsWindow:show()
      conditionsWindow:raise()
      conditionsWindow:focus()
    end
  end

  -- Variáveis para controle de cooldown e organização
  local utanaCast = nil
  local utamoCast = nil
  local lastSpellCast = nil
  local spellDelay = 1500 -- 1.5 segundos entre magias para evitar conflitos

  -- SISTEMA MELHORADO PARA MANA SHIELD
  local function hasManaShield()
    -- Método 1: Função global mais comum
    if hasManaShield and type(hasManaShield) == "function" then
      local success, result = pcall(hasManaShield)
      if success then return result end
    end
    
    -- Método 2: Variações de nome
    if hasUtamo and type(hasUtamo) == "function" then
      local success, result = pcall(hasUtamo)
      if success then return result end
    end
    
    if isManaShielded and type(isManaShielded) == "function" then
      local success, result = pcall(isManaShielded)
      if success then return result end
    end
    
    -- Método 3: Via módulo de cooldown
    if modules and modules.game_cooldown then
      if modules.game_cooldown.isConditionIconActive then
        local success, result = pcall(function()
          return modules.game_cooldown.isConditionIconActive(CONDITION_MANASHIELD)
        end)
        if success then return result end
      end
      
      if modules.game_cooldown.isConditionActive then
        local success, result = pcall(function()
          return modules.game_cooldown.isConditionActive(CONDITION_MANASHIELD)
        end)
        if success then return result end
      end
    end
    
    -- Método 4: Via player conditions
    local player = g_game.getLocalPlayer()
    if player and player.getConditions then
      local success, conditions = pcall(function() return player:getConditions() end)
      if success and conditions then
        for _, condition in pairs(conditions) do
          if condition and condition.getType then
            local success2, condType = pcall(function() return condition:getType() end)
            if success2 and (condType == CONDITION_MANASHIELD or condType == 16) then
              return true
            end
          end
        end
      end
    end
    
    return false
  end

  -- Função para verificar se pode usar magia (evita conflitos)
  local function canCastSpell()
    return not lastSpellCast or (now - lastSpellCast > spellDelay)
  end

  -- Função para registrar que uma magia foi usada
  local function registerSpellCast()
    lastSpellCast = now
  end

  -- Macro para curas de condições negativas e Recovery (500ms)
  macro(500, function()
    if not config.enabled or modules.game_cooldown.isGroupCooldownIconActive(2) then return end
    
    -- Curas de condições negativas (prioridade quando HP > 95%)
    if hppercent() > 95 and canCastSpell() then
      if config.curePoison and mana() >= config.poisonCost and isPoisioned() then 
        say("exana pox")
        registerSpellCast()
        return
      elseif config.cureCurse and mana() >= config.curseCost and isCursed() then 
        say("exana mort")
        registerSpellCast()
        return
      elseif config.cureBleed and mana() >= config.bleedCost and isBleeding() then 
        say("exana kor")
        registerSpellCast()
        return
      elseif config.cureBurn and mana() >= config.burnCost and isBurning() then 
        say("exana flam")
        registerSpellCast()
        return
      elseif config.cureElectrify and mana() >= config.electrifyCost and isEnergized() then 
        say("exana vis")
        registerSpellCast()
        return
      end
    end
    
    -- Recovery (Utura) - verifica se pode usar e se HP está baixo
    if (not config.ignoreInPz or not isInPz()) and config.holdUtura and mana() >= config.uturaCost and 
       canCast(config.uturaType) and hppercent() < 90 and canCastSpell() then 
      say(config.uturaType)
      registerSpellCast()
      return
    end
    
    -- Utana Vid - COOLDOWN FIXO de 2 minutos (120 segundos) + delay entre magias
    if (not config.ignoreInPz or not isInPz()) and config.holdUtana and mana() >= config.utanaCost and 
       (not utanaCast or (now - utanaCast > 120000)) and canCastSpell() then 
      say("utana vid") 
      utanaCast = now
      registerSpellCast()
      return
    end
  end)

  -- Macro para verificação de status e magias de proteção com priorização (100ms)
  macro(100, function()
    if not config.enabled then return end
    
    -- PRIORIDADE 1: Cura de paralisia (EMERGÊNCIA ABSOLUTA)
    if config.cureParalyse and mana() >= config.paralyseCost and isParalyzed() then 
      say(config.paralyseSpell)
      registerSpellCast()
      return
    end
    
    -- PRIORIDADE 2: Utamo Vita - SISTEMA CORRIGIDO COM DETECÇÃO REAL
    if (not config.ignoreInPz or not isInPz()) and config.holdUtamo and mana() >= config.utamoCost and 
       not hasManaShield() and canCastSpell() and
       (not utamoCast or (now - utamoCast > 14000)) then -- Cooldown mínimo de 14s
      say("utamo vita")
      utamoCast = now
      registerSpellCast()
      return
    end
    
    -- PRIORIDADE 3: Haste - USA hasHaste() que existe no player_conditions.lua
    if (not config.ignoreInPz or not isInPz()) and config.holdHaste and mana() >= config.hasteCost and 
       not hasHaste() and canCastSpell() and
       (not target() or not config.stopHaste or TargetBot.isCaveBotActionAllowed()) then 
      say(config.hasteSpell)
      registerSpellCast()
      return
    end
  end)


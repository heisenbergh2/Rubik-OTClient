setDefaultTab('main')
-- locales
local panelName = "AttackBot"
local currentSettings
local showSettings = false
local showItem = false
local category = 1
local patternCategory = 1
local pattern = 1
local mainWindow

-- === SISTEMA HÍBRIDO DE COOLDOWN GROUPS ===
-- Fallback interno caso o sistema oficial não funcione corretamente
local internalCooldowns = {
  [4] = 0,   -- Strong Strikes (8 segundos)
  [6] = 0,   -- Ultimate Areas + Buffs (40 segundos)  
  [7] = 0,   -- Ultimate Strikes (30 segundos)
  [8] = 0,   -- Great Beams (6 segundos)
  [9] = 0    -- Burst Spells (6 segundos)
}

-- Mapeamento das magias para grupos de cooldown
local spellGroups = {
  -- Grupo 6 (40 segundos) - Ultimate Area Spells
  ["exevo gran mas vis"] = 6,      -- Rage of the Skies
  ["exevo gran mas flam"] = 6,     -- Hells Core  
  ["exevo gran mas tera"] = 6,     -- Wrath of Nature
  ["exevo gran mas frigo"] = 6,    -- Eternal Winter
  
  -- Grupo 4 (8 segundos) - Strong Strikes
  ["exori gran flam"] = 4,
  ["exori gran frigo"] = 4, 
  ["exori gran tera"] = 4,
  ["exori gran vis"] = 4,
  
  -- Grupo 7 (30 segundos) - Ultimate Strikes
  ["exori max flam"] = 7,
  ["exori max frigo"] = 7,
  ["exori max tera"] = 7, 
  ["exori max vis"] = 7,
  
  -- Grupo 8 (6 segundos) - Great Beams  
  ["exevo gran vis lux"] = 8,
  ["exevo max mort"] = 8,
  
  -- Grupo 9 (6 segundos) - Burst Spells
  ["exevo ulus frigo"] = 9,
  ["exevo ulus tera"] = 9,
  
  -- Grupo 6 especial para outras magias de 10+ segundos
  ["utito tempo san"] = 6,    -- Sharpshooter (10s)
  ["utamo tempo san"] = 6,    -- Swift Foot (10s)
  ["utamo tempo"] = 6,        -- Protector (2s base + grupo)
  ["utito tempo"] = 6,        -- Blood Rage (2s base + grupo)
}

-- Cooldowns por grupo em milissegundos
local groupCooldownTimes = {
  [4] = 8000,   -- 8 segundos
  [6] = 40000,  -- 40 segundos
  [7] = 30000,  -- 30 segundos
  [8] = 6000,   -- 6 segundos
  [9] = 6000    -- 6 segundos
}

-- Função para obter tempo atual em milissegundos (compatível com vBot)
local function getCurrentTime()
  return os.time() * 1000
end

-- Função híbrida para verificar se um grupo está em cooldown
local function isGroupOnCooldownHybrid(groupId)
  -- Primeiro tenta o sistema oficial
  if modules.game_cooldown and modules.game_cooldown.isGroupCooldownIconActive then
    local officialResult = modules.game_cooldown.isGroupCooldownIconActive(groupId)
    if officialResult then
      return true
    end
  end
  
  -- Fallback para sistema interno
  if not internalCooldowns[groupId] then return false end
  return getCurrentTime() < internalCooldowns[groupId]
end

-- Função para ativar cooldown interno de um grupo
local function activateGroupCooldownInternal(groupId)
  if groupCooldownTimes[groupId] then
    internalCooldowns[groupId] = getCurrentTime() + groupCooldownTimes[groupId]
    -- Debug removido para não sobrecarregar logs
  end
end

-- Função para verificar se uma spell pode ser usada (considerando grupo)
local function canUseSpellWithGroup(spellWords)
  if not spellWords or spellWords == "" then return true end
  
  local words = spellWords:lower():trim()
  local groupId = spellGroups[words]
  
  -- Se não tem grupo especial, pode usar (apenas cooldown normal)
  if not groupId then return true end
  
  -- Verificar se o grupo está em cooldown (sistema híbrido)
  if isGroupOnCooldownHybrid(groupId) then
    -- Debug removido para não sobrecarregar logs
    return false
  end
  
  return true
end

-- Função para registrar uso de uma spell (ativar seu grupo)
local function registerSpellUsed(spellWords)
  if not spellWords or spellWords == "" then return end
  
  local words = spellWords:lower():trim()
  local groupId = spellGroups[words]
  
  if groupId then
    activateGroupCooldownInternal(groupId)
    -- Debug removido para não sobrecarregar logs
  end
end
-- === FIM DO SISTEMA HÍBRIDO ===

-- SISTEMA AUTOMÃTICO DE COOLDOWNS - CORREÇÃO PARA ELIMINAR EXHAUST
local spellCooldowns = {
  -- RUNAS (todas com 2000ms = 2 segundos)
  ["sudden death rune"] = 2000,
  ["great fireball rune"] = 2000,
  ["avalanche rune"] = 2000,
  ["stone shower rune"] = 2000,
  ["thunderstorm rune"] = 2000,
  ["icicle rune"] = 2000,
  ["holy missile rune"] = 2000,
  ["explosion rune"] = 2000,
  ["fire bomb rune"] = 2000,
  
  -- SPELLS DE ATAQUE MAIS COMUNS
  ["exori"] = 4000,
  ["exori gran"] = 6000,
  ["exori hur"] = 6000,
  ["exori ico"] = 6000,
  ["exori gran ico"] = 30000,
  ["exori min"] = 6000,
  ["exori flam"] = 2000,
  ["exori frigo"] = 2000,
  ["exori tera"] = 2000,
  ["exori vis"] = 2000,
  ["exori mort"] = 2000,
  ["exori san"] = 2000,
  ["exori con"] = 2000,
  ["exori gran con"] = 8000,
  ["exori gran flam"] = 8000,
  ["exori gran frigo"] = 8000,
  ["exori gran tera"] = 8000,
  ["exori gran vis"] = 8000,
  ["exori mas"] = 8000,
  ["exori mas pug"] = 4000,
  ["exori gran mas pug"] = 16000,
  ["exori mas nia"] = 8000,
  ["exori nia"] = 8000,
  ["exori med pug"] = 4000,
  ["exori pug"] = 4000,
  ["exori kor"] = 12000,
  
  -- SPELLS DE ÁREA
  ["exevo mas san"] = 4000,
  ["exevo mas flam"] = 4000,
  ["exevo mas frigo"] = 4000,
  ["exevo mas tera"] = 4000,
  ["exevo mas vis"] = 4000,
  ["exevo mas pox"] = 4000,
  ["exevo gran mas flam"] = 40000,
  ["exevo gran mas frigo"] = 40000,
  ["exevo gran mas tera"] = 40000,
  ["exevo gran mas vis"] = 40000,
  ["exevo vis hur"] = 8000,
  ["exevo tera hur"] = 4000,
  ["exevo flam hur"] = 4000,
  ["exevo frigo hur"] = 4000,
  ["exevo gran flam hur"] = 4000,
  ["exevo gran frigo hur"] = 8000,
  ["exevo vis lux"] = 4000,
  ["exevo gran vis lux"] = 6000,
  
  -- EMPOWERMENT SPELLS
  ["utito tempo"] = 2000,
  ["utito tempo san"] = 2000,
  ["utito mas sio"] = 2000,
  ["utito virtu"] = 10000,
  
  -- HEALING SPELLS
  ["exura"] = 1000,
  ["exura gran"] = 1000,
  ["exura ico"] = 1000,
  ["exura sio"] = 1000,
  ["exura gran sio"] = 60000,
  ["exura san"] = 1000,
  ["exura vita"] = 1000,
}

-- Função para obter cooldown automático de uma spell
local function getSpellCooldown(spellWords)
  if not spellWords or spellWords == "" or type(spellWords) ~= "string" then
    return 2000 -- Padrão para runas
  end
  
  local words = spellWords:lower():trim()
  return spellCooldowns[words] or 2000 -- Padrão 2 segundos se não encontrar
end

-- label library

local categories = {
  "Targeted Spell (exori hur, exori flam, etc)",
  "Area Rune (avalanche, great fireball, etc)",
  "Targeted Rune (sudden death, icycle, etc)",
  "Empowerment (utito tempo, etc)",
  "Absolute Spell (exori, hells core, etc)",
}

local patterns = {
  -- targeted spells
  {
    "1 Sqm Range (exori ico)",
    "2 Sqm Range",
    "3 Sqm Range (strike spells)",
    "4 Sqm Range (exori san)",
    "5 Sqm Range (exori hur)",
    "6 Sqm Range",
    "7 Sqm Range (exori con)",
    "8 Sqm Range",
    "9 Sqm Range",
    "10 Sqm Range"
  },
  -- area runes
  {
    "Cross (explosion)",
    "Bomb (fire bomb)",
    "Ball (gfb, avalanche)"
  },
  -- empowerment/targeted rune
  {
    "1 Sqm Range",
    "2 Sqm Range",
    "3 Sqm Range",
    "4 Sqm Range",
    "5 Sqm Range",
    "6 Sqm Range",
    "7 Sqm Range",
    "8 Sqm Range",
    "9 Sqm Range",
    "10 Sqm Range",
  },
  -- absolute
  {
    "Adjacent (exori, exori gran)",
    "3x3 Wave (vis hur, tera hur)", 
    "Small Area (mas san, exori mas)",
    "Medium Area (mas flam, mas frigo)",
    "Large Area (mas vis, mas tera)",
    "Short Beam (vis lux)", 
    "Large Beam (gran vis lux)", 
    "Sweep (exori min)", -- 8
    "Small Wave (gran frigo hur)",
    "Small Wave (monk)",
    "Big Wave (mas nia)",
    "Big Wave (flam hur, frigo hur)",
    "Huge Wave (gran flam hur)",
  }
}

  -- spellPatterns[category][pattern][1 - normal, 2 - safe]
local spellPatterns = {
  {}, -- blank, wont be used
  -- Area Runes,
  { 
    {     -- cross
     [[ 
      010
      111
      010
     ]],
     -- cross SAFE
     [[
       01110
       01110
       11111
       11111
       11111
       01110
       01110
     ]]
    },
    { -- bomb
      [[
        111
        111
        111
      ]],
      -- bomb SAFE
      [[
        11111
        11111
        11111
        11111
        11111
      ]]
    },
    { -- ball
      [[
        0011100
        0111110
        1111111
        1111111
        1111111
        0111110
        0011100
      ]],
      -- ball SAFE
      [[
        000111000
        001111100
        011111110
        111111111
        111111111
        111111111
        011111110
        001111100
        000111000
      ]]
    },
  },
  {
  
  
  
  
  
  }, -- blank, wont be used
  -- Absolute
  {
    {-- adjacent
      [[
        111
        111
        111
      ]],
      -- adjacent SAFE
      [[
        11111
        11111
        11111
        11111
        11111
      ]]
    },
    { -- 3x3 Wave
      [[
        0000NNN0000
        0000NNN0000
        0000NNN0000
        00000N00000
        WWW00N00EEE
        WWWWW0EEEEE
        WWW00S00EEE
        00000S00000
        0000SSS0000
        0000SSS0000
        0000SSS0000
      ]],
      -- 3x3 Wave SAFE
      [[
        0000NNNNN0000
        0000NNNNN0000
        0000NNNNN0000
        0000NNNNN0000
        WWWW0NNN0EEEE
        WWWWWNNNEEEEE
        WWWWWW0EEEEEE
        WWWWWSSSEEEEE
        WWWW0SSS0EEEE
        0000SSSSS0000
        0000SSSSS0000
        0000SSSSS0000
        0000SSSSS0000
      ]]
    },
    { -- small area
      [[
        0011100
        0111110
        1111111
        1111111
        1111111
        0111110
        0011100
      ]],
      -- small area SAFE
      [[
        000111000
        001111100
        011111110
        111111111
        111111111
        111111111
        011111110
        001111100
        000111000
      ]]
    },
    { -- medium area
      [[
        00000100000
        00011111000
        00111111100
        01111111110
        01111111110
        11111111111
        01111111110
        01111111110
        00111111100
        00001110000
        00000100000
      ]],
      -- medium area SAFE
      [[
        0000011100000
        0000111110000
        0001111111000
        0011111111100
        0111111111110
        0111111111110
        1111111111111
        0111111111110
        0111111111110
        0011111111100
        0001111111000
        0000111110000
        0000011100000
      ]]
    },
    { -- large area
      [[
        000000010000000
        000000111000000
        000001111100000
        000011111110000
        000111111111000
        001111111111100
        011111111111110
        111111111111111
        011111111111110
        001111111111100
        000111111111000
        000011111110000
        000001111100000
        000000111000000
        000000010000000
      ]],
      -- large area SAFE
      [[
        00000000100000000
        00000001110000000
        00000011111000000
        00000111111100000
        00001111111110000
        00011111111111000
        00111111111111100
        01111111111111110
        00111111111111100
        00011111111111000
        00001111111110000
        00000111111100000
        00000011111000000
        00000001110000000
        00000000100000000
      ]]
    },
    { -- short beam
      [[
        00000N00000
        00000N00000
        00000N00000
        00000N00000
        00000N00000
        WWWWW0EEEEE
        00000S00000
        00000S00000
        00000S00000
        00000S00000
        00000S00000
      ]],
      -- short beam SAFE
      [[
        00000NNN00000
        00000NNN00000
        00000NNN00000
        00000NNN00000
        00000NNN00000
        WWWWWNNNEEEEE
        WWWWWW0EEEEEE
        00000SSS00000
        00000SSS00000
        00000SSS00000
        00000SSS00000
        00000SSS00000
        00000SSS00000
      ]]
    },
    { -- large beam
      [[
        0000000N0000000
        0000000N0000000
        0000000N0000000
        0000000N0000000
        0000000N0000000
        0000000N0000000
        0000000N0000000
        WWWWWWW0EEEEEEE
        0000000S0000000
        0000000S0000000
        0000000S0000000
        0000000S0000000
        0000000S0000000
        0000000S0000000
        0000000S0000000
      ]],
      -- large beam SAFE
      [[
        0000000NNN0000000
        0000000NNN0000000
        0000000NNN0000000
        0000000NNN0000000
        0000000NNN0000000
        0000000NNN0000000
        0000000NNN0000000
        WWWWWWWNNNEEEEEEE
        WWWWWWWW0EEEEEEEE
        WWWWWWWSSSEEEEEEE
        0000000SSS0000000
        0000000SSS0000000
        0000000SSS0000000
        0000000SSS0000000
        0000000SSS0000000
        0000000SSS0000000
        0000000SSS0000000
      ]],
    },
    {}, -- sweep, wont be used
    { -- small wave
      [[
        00NNN00
        00NNN00
        WW0N0EE
        WWW0EEE
        WW0S0EE
        00SSS00
        00SSS00
      ]],
      -- small wave SAFE
      [[
        00NNNNN00
        00NNNNN00
        WWNNNNNEE
        WWWWNEEEE
        WWWW0EEEE
        WWWWSEEEE
        WWSSSSSEE
        00SSSSS00
        00SSSSS00
      ]]
    },    
	
	{ -- small wave (monk)
      [[
        000N000
        00NNN00
        WWNNNEE
        WWW0EEE
        WWSSSEE
        00SSS00
        000S000
      ]],
      -- small wave (monk) SAFE
      [[
        00NNNNN00
        00NNNNN00
        WWNNNNNEE
        WWWWNEEEE
        WWWW0EEEE
        WWWWSEEEE
        WWSSSSSEE
        00SSSSS00
        00SSSSS00
      ]]
    },
    { -- large wave (monk)
      [[
		  W00NNN00E
		  00NNNNN00
		  0NNNNEEE0
		  NNNNNEEEE
		  WWWW0EEEE
		  WWWWSEEEE
		  0WWWSEEE0
		  00SSSSS00
		  W00SSS00E
      ]],
      [[
		  WW00NNN00EE
		  W00NNNNN00E
		  00NNNNEEE00
		  0NNNNNEEEE0
		  NNNNN0EEEEE
		  NWWWWSEEEEN
		  NWWWWSEEEEN
		  0WWWWSEEE0N
		  00WWWSEEE00
		  W00SSSSS00E
		  WW00SSS00EE
      ]]
    }, 
	
	{ -- large wave
      [[
        000NNNNN000
        000NNNNN000
        0000NNN0000
        WW00NNN00EE
        WWWW0N0EEEE
        WWWWW0EEEEE
        WWWW0S0EEEE
        WW00SSS00EE
        0000SSS0000
        000SSSSS000
        000SSSSS000
      ]],
      [[
        000NNNNNNN000
        000NNNNNNN000
        000NNNNNNN000
        WWWWNNNNNEEEE
        WWWWNNNNNEEEE
        WWWWWNNNEEEEE
        WWWWWW0EEEEEE
        WWWWWSSSEEEEE
        WWWWSSSSSEEEE
        WWWWSSSSSEEEE
        000SSSSSSS000
        000SSSSSSS000
        000SSSSSSS000
      ]]
    },
    { -- huge wave
      [[
        0000NNNNN0000
        0000NNNNN0000
        00000NNN00000
        00000NNN00000
        WW0000N0000EE
        WWWW00N00EEEE
        WWWWWW0EEEEEE
        WWWW00S00EEEE
        WW0000S0000EE
        00000SSS00000
        00000SSS00000
        0000SSSSS0000
        0000SSSSS0000
      ]],
      [[
        0000000NNN0000000
        0000000NNN0000000
        0000000NNN0000000
        0000000NNN0000000
        0000000NNN0000000
        0000000NNN0000000
        0000000NNN0000000
        WWWWWWWNNNEEEEEEE
        WWWWWWWW0EEEEEEEE
        WWWWWWWSSSEEEEEEE
        0000000SSS0000000
        0000000SSS0000000
        0000000SSS0000000
        0000000SSS0000000
        0000000SSS0000000
        0000000SSS0000000
        0000000SSS0000000
      ]]
    }
  }
}

-- direction patterns
local ek = (voc() == 1 or voc() == 11) and true

local posN = ek and [[
  111
  000
  000
]] or [[
  00011111000
  00011111000
  00011111000
  00011111000
  00000100000
  00000000000
  00000000000
  00000000000
  00000000000
  00000000000
  00000000000
]]

local posE = ek and [[
  001
  001
  001
]] or   [[
  00000000000
  00000000000
  00000000000
  00000001111
  00000001111
  00000011111
  00000001111
  00000001111
  00000000000
  00000000000
  00000000000
]]
local posS = ek and [[
  000
  000
  111
]] or   [[
  00000000000
  00000000000
  00000000000
  00000000000
  00000000000
  00000000000
  00000100000
  00011111000
  00011111000
  00011111000
  00011111000
]]
local posW = ek and [[
  100
  100
  100
]] or   [[
  00000000000
  00000000000
  00000000000
  11110000000
  11110000000
  11111000000
  11110000000
  11110000000
  00000000000
  00000000000
  00000000000
]]

-- AttackBotConfig
-- create blank profiles 
if not AttackBotConfig[panelName] or not AttackBotConfig[panelName][1] or #AttackBotConfig[panelName] ~= 5 then
  AttackBotConfig[panelName] = {
    [1] = {
      enabled = false,
      attackTable = {},
      ignoreMana = true,
      Kills = false,
      Rotate = false,
      name = "Profile #1",
      Cooldown = true,
      Visible = true,
      pvpMode = false,
      KillsAmount = 1,
      PvpSafe = true,
      BlackListSafe = false,
      AntiRsRange = 5
    },
    [2] = {
      enabled = false,
      attackTable = {},
      ignoreMana = true,
      Kills = false,
      Rotate = false,
      name = "Profile #2",
      Cooldown = true,
      Visible = true,
      pvpMode = false,
      KillsAmount = 1,
      PvpSafe = true,
      BlackListSafe = false,
      AntiRsRange = 5
    },
    [3] = {
      enabled = false,
      attackTable = {},
      ignoreMana = true,
      Kills = false,
      Rotate = false,
      name = "Profile #3",
      Cooldown = true,
      Visible = true,
      pvpMode = false,
      KillsAmount = 1,
      PvpSafe = true,
      BlackListSafe = false,
      AntiRsRange = 5
    },
    [4] = {
      enabled = false,
      attackTable = {},
      ignoreMana = true,
      Kills = false,
      Rotate = false,
      name = "Profile #4",
      Cooldown = true,
      Visible = true,
      pvpMode = false,
      KillsAmount = 1,
      PvpSafe = true,
      BlackListSafe = false,
      AntiRsRange = 5
    },
    [5] = {
      enabled = false,
      attackTable = {},
      ignoreMana = true,
      Kills = false,
      Rotate = false,
      name = "Profile #5",
      Cooldown = true,
      Visible = true,
      pvpMode = false,
      KillsAmount = 1,
      PvpSafe = true,
      BlackListSafe = false,
      AntiRsRange = 5
    },
  }
end
  
if not AttackBotConfig.currentBotProfile or AttackBotConfig.currentBotProfile == 0 or AttackBotConfig.currentBotProfile > 5 then 
  AttackBotConfig.currentBotProfile = 1
end

-- create panel UI
ui = UI.createWidget("AttackBotBotPanel")

-- finding correct table, manual unfortunately
local setActiveProfile = function()
  local n = AttackBotConfig.currentBotProfile
  currentSettings = AttackBotConfig[panelName][n]
end
setActiveProfile()

-- VERIFICACAO DE VOCACAO PARA PROFILES AUTOMATICOS
local function checkVocationProfile()
  local player = g_game.getLocalPlayer()
  if player then
    local vocation = player:getVocation()
    local targetProfile = 1 -- padrao
    
    -- Mapeamento de vocacao para profile
    if vocation == 1 or vocation == 11 then -- Knight/Elite Knight
      targetProfile = 1
    elseif vocation == 3 or vocation == 13 then -- Sorcerer/Master Sorcerer  
      targetProfile = 2
    elseif vocation == 4 or vocation == 14 then -- Druid/Elder Druid
      targetProfile = 3
    elseif vocation == 2 or vocation == 12 then -- Paladin/Royal Paladin
      targetProfile = 4
    elseif vocation == 5 or vocation == 15 then -- Monk/Exalted Monk
      targetProfile = 5
    end
    
    -- Verificar se auto profile esta ativado
    local settings = g_settings.getNode('bot') or {}
    if settings.vocationConfig and settings.vocationConfig.enabled then
      if AttackBotConfig.currentBotProfile ~= targetProfile then
        AttackBotConfig.currentBotProfile = targetProfile
        setActiveProfile()
        print("[AttackBot] Profile alterado para: " .. targetProfile)
        
        -- Atualizar interface visual apos um delay maior
        schedule(1000, function()
          -- Executar mudanca completa de profile (simular clique no botao)
          if profileChange then
            profileChange()
          else
            -- Fallback: executar funcoes manualmente na ordem correta
            setActiveProfile()
            
            -- Atualizar cores dos botoes
            for i=1,5 do
              if i == AttackBotConfig.currentBotProfile then
                ui[i]:setColor("green")
              else
                ui[i]:setColor("white")
              end
            end
            
            -- IMPORTANTE: Carregar configuracoes do profile
            if loadSettings then
              loadSettings()
            end
            
            -- IMPORTANTE: Resetar campos da interface
            if resetFields then
              resetFields()
            end
            
            -- Atualizar nome do profile na UI
            ui.name:setText(currentSettings.name)
            
            -- Salvar configuracoes
            vBotConfigSave("atk")
          end
        end)
      end
    end
  end
end

-- Executar verificacao apos 3 segundos do carregamento
schedule(3000, function() checkVocationProfile() end)

if not currentSettings.AntiRsRange then
  currentSettings.AntiRsRange = 5 
end

local setProfileName = function()
  ui.name:setText(currentSettings.name)
end

-- small UI elements
ui.title.onClick = function(widget)
  currentSettings.enabled = not currentSettings.enabled
  widget:setOn(currentSettings.enabled)
  vBotConfigSave("atk")
end
  
ui.settings.onClick = function(widget)
  mainWindow:show()
  mainWindow:raise()
  mainWindow:focus()
end

  mainWindow = UI.createWindow("AttackBotWindow")
  mainWindow:hide()

  local panel = mainWindow.mainPanel
  local settingsUI = mainWindow.settingsPanel

  mainWindow.onVisibilityChange = function(widget, visible)
    if not visible then
      currentSettings.attackTable = {}
      for i, child in ipairs(panel.entryList:getChildren()) do
        table.insert(currentSettings.attackTable, child.params)
      end
      vBotConfigSave("atk")
    end
  end

  -- main panel

    -- functions
    function toggleSettings()
      panel:setVisible(not showSettings)
      mainWindow.shooterLabel:setVisible(not showSettings)
      settingsUI:setVisible(showSettings)
      mainWindow.settingsLabel:setVisible(showSettings)
      mainWindow.settings:setText(showSettings and "Back" or "Settings")
    end
    toggleSettings()

    mainWindow.settings.onClick = function()
      showSettings = not showSettings
      toggleSettings()
    end

    function toggleItem()
      panel.monsters:setWidth(showItem and 405 or 341)
      panel.itemId:setVisible(showItem)
      panel.spellName:setVisible(not showItem)
    end
    toggleItem()

    function setCategoryText()
      panel.category.description:setText(categories[category])
    end
    setCategoryText()

    function setPatternText()
      panel.range.description:setText(patterns[patternCategory][pattern])
    end
    setPatternText()

    -- in/de/crementation buttons
    panel.previousCategory.onClick = function()
      if category == 1 then
        category = #categories
      else
        category = category - 1
      end

      showItem = (category == 2 or category == 3) and true or false
      patternCategory = category == 4 and 3 or category == 5 and 4 or category
      pattern = 1
      toggleItem()
      setPatternText()
      setCategoryText()
    end
    panel.nextCategory.onClick = function()
      if category == #categories then
        category = 1 
      else
        category = category + 1
      end

      showItem = (category == 2 or category == 3) and true or false
      patternCategory = category == 4 and 3 or category == 5 and 4 or category
      pattern = 1
      toggleItem()
      setPatternText()
      setCategoryText()
    end
    panel.previousSource.onClick = function()
      warn("[AttackBot] TODO, reserved for future use.")
    end
    panel.nextSource.onClick = function()
      warn("[AttackBot] TODO, reserved for future use.")
    end
    panel.previousRange.onClick = function()
      local t = patterns[patternCategory]
      if pattern == 1 then
        pattern = #t 
      else
        pattern = pattern - 1
      end
      setPatternText()
    end
    panel.nextRange.onClick = function()
      local t = patterns[patternCategory]
      if pattern == #t then
        pattern = 1 
      else
        pattern = pattern + 1
      end
      setPatternText()
    end
    -- eo in/de/crementation

  ------- [[core table function]] -------
    function setupWidget(widget)
      local params = widget.params

      widget:setText(params.description)
      if params.itemId > 0 then
        widget.spell:setVisible(false)
        widget.id:setVisible(true)
        widget.id:setItemId(params.itemId)
      end
      widget:setTooltip(params.tooltip)
      widget.remove.onClick = function()
        panel.up:setEnabled(false)
        panel.down:setEnabled(false)
        widget:destroy()
      end
      widget.enabled:setChecked(params.enabled)
      widget.enabled.onClick = function()
        params.enabled = not params.enabled
        widget.enabled:setChecked(params.enabled)
      end
      -- will serve as edit
      widget.onDoubleClick = function(widget)
        panel.manaPercent:setValue(params.mana)
        panel.creatures:setValue(params.count)
        panel.minHp:setValue(params.minHp)
        panel.maxHp:setValue(params.maxHp)
        panel.cooldown:setValue(params.cooldown)
        showItem = params.itemId > 100 and true or false
        panel.itemId:setItemId(params.itemId)
        panel.spellName:setText(params.spell or "")
        panel.orMore:setChecked(params.orMore)
        toggleItem()
        category = params.category
        patternCategory = params.patternCategory
        pattern = params.pattern
        setPatternText()
        setCategoryText()
        widget:destroy()
      end
      widget.onClick = function(widget)
        if #panel.entryList:getChildren() == 1 then
          panel.up:setEnabled(false)
          panel.down:setEnabled(false)
        elseif panel.entryList:getChildIndex(widget) == 1 then
          panel.up:setEnabled(false)
          panel.down:setEnabled(true)
        elseif panel.entryList:getChildIndex(widget) == panel.entryList:getChildCount() then
          panel.up:setEnabled(true)
          panel.down:setEnabled(false)
        else
          panel.up:setEnabled(true)
          panel.down:setEnabled(true)
        end
      end
    end


    -- refreshing values
    function refreshAttacks()
      if not currentSettings.attackTable then return end

      panel.entryList:destroyChildren()
      for i, entry in pairs(currentSettings.attackTable) do
        local label = UI.createWidget("AttackEntry", panel.entryList)
        label.params = entry
        setupWidget(label)
      end
    end
    refreshAttacks()
    panel.up:setEnabled(false)
    panel.down:setEnabled(false)

    -- adding values
    panel.addEntry.onClick = function(wdiget)
      -- first variables
      local creatures = panel.monsters:getText():lower()
      local monsters = (creatures:len() == 0 or creatures == "*" or creatures == "monster names") and true or string.split(creatures, ",")
      local mana = panel.manaPercent:getValue()
      local count = panel.creatures:getValue()
      local minHp = panel.minHp:getValue()
      local maxHp = panel.maxHp:getValue()
      local cooldown = panel.cooldown:getValue()
      local itemId = panel.itemId:getItemId()
      local spell = panel.spellName:getText()
      local tooltip = monsters ~= true and creatures
      local orMore = panel.orMore:isChecked()

      -- validation
      if showItem and itemId < 100 then
        return warn("[AttackBot]: please fill item ID!")
      elseif not showItem and (spell:lower() == "spell name" or spell:len() == 0) then
        return warn("[AttackBot]: please fill spell name!")
      end

      local regex = patternCategory ~= 1 and [[^[^\(]+]] or [[^[^R]+]]
      local type = regexMatch(patterns[patternCategory][pattern], regex)[1][1]:trim()
      regex = [[^[^ ]+]]
      local categoryName = regexMatch(categories[category], regex)[1][1]:trim():lower()
      local specificMonsters = monsters == true and "Any Creatures" or "Creatures"
      local attackType = showItem and "rune "..itemId or spell

      local countDescription = orMore and count.."+" or count

      local params = {
        creatures = creatures,
        monsters = monsters,
        mana = mana,
        count = count,
        minHp = minHp,
        maxHp = maxHp,
        cooldown = cooldown,
        itemId = itemId,
        spell = spell,
        enabled = true,
        category = category,
        patternCategory = patternCategory,
        pattern = pattern,
        tooltip = tooltip,
        orMore = orMore,
        description = '['..type..'] '..countDescription.. ' '..specificMonsters..': '..attackType..', '..categoryName..' ('..minHp..'%-'..maxHp..'%)'
      }

      local label = UI.createWidget("AttackEntry", panel.entryList)
      label.params = params
      setupWidget(label)
      resetFields()
    end

    -- moving values
    -- up
    panel.up.onClick = function(widget)
      local focused = panel.entryList:getFocusedChild()
      local n = panel.entryList:getChildIndex(focused)

      if n-1 == 1 then
        widget:setEnabled(false)
      end
      panel.down:setEnabled(true)
      panel.entryList:moveChildToIndex(focused, n-1)
      panel.entryList:ensureChildVisible(focused)
    end
    -- down
    panel.down.onClick = function(widget)
      local focused = panel.entryList:getFocusedChild()
      local n = panel.entryList:getChildIndex(focused)

      if n + 1 == panel.entryList:getChildCount() then
        widget:setEnabled(false)
      end
      panel.up:setEnabled(true)
      panel.entryList:moveChildToIndex(focused, n+1)
      panel.entryList:ensureChildVisible(focused)
    end

  -- [[settings panel]] --
  settingsUI.profileName.onTextChange = function(widget, text)
    currentSettings.name = text
    setProfileName()
  end
  settingsUI.IgnoreMana.onClick = function(widget)
    currentSettings.ignoreMana = not currentSettings.ignoreMana
    settingsUI.IgnoreMana:setChecked(currentSettings.ignoreMana)
  end
  settingsUI.Rotate.onClick = function(widget)
    currentSettings.Rotate = not currentSettings.Rotate
    settingsUI.Rotate:setChecked(currentSettings.Rotate)
  end
  settingsUI.Kills.onClick = function(widget)
    currentSettings.Kills = not currentSettings.Kills
    settingsUI.Kills:setChecked(currentSettings.Kills)
  end
  settingsUI.Cooldown.onClick = function(widget)
    currentSettings.Cooldown = not currentSettings.Cooldown
    settingsUI.Cooldown:setChecked(currentSettings.Cooldown)
  end
  settingsUI.Visible.onClick = function(widget)
    currentSettings.Visible = not currentSettings.Visible
    settingsUI.Visible:setChecked(currentSettings.Visible)
  end
  settingsUI.PvpMode.onClick = function(widget)
    currentSettings.pvpMode = not currentSettings.pvpMode
    settingsUI.PvpMode:setChecked(currentSettings.pvpMode)
    
    -- CORREÇÃO: Conflito entre PvpMode e PvpSafe - só um pode estar ativo
    if currentSettings.pvpMode and currentSettings.PvpSafe then
      currentSettings.PvpSafe = false
      settingsUI.PvpSafe:setChecked(false)
      warn("[AttackBot] PVP Safe desativado automaticamente (conflito com PVP Mode)")
    end
    vBotConfigSave("atk")
  end
  settingsUI.PvpSafe.onClick = function(widget)
    currentSettings.PvpSafe = not currentSettings.PvpSafe
    settingsUI.PvpSafe:setChecked(currentSettings.PvpSafe)
    
    -- CORREÇÃO: Conflito entre PvpSafe e PvpMode - só um pode estar ativo
    if currentSettings.PvpSafe and currentSettings.pvpMode then
      currentSettings.pvpMode = false
      settingsUI.PvpMode:setChecked(false)
      warn("[AttackBot] PVP Mode desativado automaticamente (conflito com PVP Safe)")
    end
    vBotConfigSave("atk")
  end
  settingsUI.Training.onClick = function(widget)
    currentSettings.Training = not currentSettings.Training
    settingsUI.Training:setChecked(currentSettings.Training)
  end
  settingsUI.BlackListSafe.onClick = function(widget)
    currentSettings.BlackListSafe = not currentSettings.BlackListSafe
    settingsUI.BlackListSafe:setChecked(currentSettings.BlackListSafe)
  end
  settingsUI.KillsAmount.onValueChange = function(widget, value)
    currentSettings.KillsAmount = value
  end
  settingsUI.AntiRsRange.onValueChange = function(widget, value)
    currentSettings.AntiRsRange = value
  end


   -- window elements
  mainWindow.closeButton.onClick = function()
    showSettings = false
    toggleSettings()
    resetFields()
    mainWindow:hide()
  end

  -- core functions
  function resetFields()
    showItem = false
    toggleItem()
    pattern = 1
    patternCategory = 1
    category = 1
    setPatternText()
    setCategoryText()
    panel.manaPercent:setText(1)
    panel.creatures:setText(1)
    panel.minHp:setValue(0)
    panel.maxHp:setValue(100)
    panel.cooldown:setText(1)
    panel.monsters:setText("monster names")
    panel.itemId:setItemId(0)
    panel.spellName:setText("spell name")
    panel.orMore:setChecked(false)
  end
  resetFields()

  function loadSettings()
    -- BOT panel
    ui.title:setOn(currentSettings.enabled)
    setProfileName()
    -- main panel
    refreshAttacks()
    -- settings
    settingsUI.profileName:setText(currentSettings.name)
    settingsUI.Visible:setChecked(currentSettings.Visible)
    settingsUI.Cooldown:setChecked(currentSettings.Cooldown)
    settingsUI.PvpMode:setChecked(currentSettings.pvpMode)
    settingsUI.PvpSafe:setChecked(currentSettings.PvpSafe)
    settingsUI.BlackListSafe:setChecked(currentSettings.BlackListSafe)
    settingsUI.AntiRsRange:setValue(currentSettings.AntiRsRange)
    settingsUI.IgnoreMana:setChecked(currentSettings.ignoreMana)
    settingsUI.Rotate:setChecked(currentSettings.Rotate)
    settingsUI.Kills:setChecked(currentSettings.Kills)
    settingsUI.KillsAmount:setValue(currentSettings.KillsAmount)
    settingsUI.Training:setChecked(currentSettings.Training)
  end
  loadSettings()

  local activeProfileColor = function()
    for i=1,5 do
      if i == AttackBotConfig.currentBotProfile then
        ui[i]:setColor("green")
      else
        ui[i]:setColor("white")
      end
    end
  end
  activeProfileColor()

  local profileChange = function()
    setActiveProfile()
    activeProfileColor()
    loadSettings()
    resetFields()
    vBotConfigSave("atk")
  end

  for i=1,5 do
    local button = ui[i]
      button.onClick = function()
      AttackBotConfig.currentBotProfile = i
      profileChange()
    end
  end

    -- public functions
    AttackBot = {} -- global table
  
    AttackBot.isOn = function()
      return currentSettings.enabled
    end
    
    AttackBot.isOff = function()
      return not currentSettings.enabled
    end
    
    AttackBot.setOff = function()
      currentSettings.enabled = false
      ui.title:setOn(currentSettings.enabled)
      vBotConfigSave("atk")
    end
    
    AttackBot.setOn = function()
      currentSettings.enabled = true
      ui.title:setOn(currentSettings.enabled)
      vBotConfigSave("atk")
    end
    
    AttackBot.getActiveProfile = function()
      return AttackBotConfig.currentBotProfile -- returns number 1-5
    end
  
    AttackBot.setActiveProfile = function(n)
      if not n or not tonumber(n) or n < 1 or n > 5 then
        return error("[AttackBot] wrong profile parameter! should be 1 to 5 is " .. n)
      else
        AttackBotConfig.currentBotProfile = n
        profileChange()
      end
    end

    AttackBot.show = function()
      mainWindow:show()
      mainWindow:raise()
      mainWindow:focus()
    end


-- otui covered, now support functions
function getPattern(category, pattern, safe)
  safe = safe and 2 or 1

  return spellPatterns[category][pattern][safe]
end


function getMonstersInArea(category, posOrCreature, pattern, minHp, maxHp, safePattern, monsterNamesTable)
  -- monsterNamesTable can be nil
  local monsters = 0
  local t = {}
  if monsterNamesTable == true or not monsterNamesTable then
    t = {}
  else
    t = monsterNamesTable
  end

  if safePattern then
    for i, spec in pairs(getSpectators(posOrCreature, safePattern)) do
      if spec ~= player and (spec:isPlayer() and not spec:isPartyMember()) then
        return 0
      end
    end
  end 

  if category == 1 or category == 3 or category == 4 then
    if category == 1 or category == 3 then
      local name = getTarget() and getTarget():getName()
      if #t ~= 0 and not table.find(t, name, true) then
        return 0
      end
    end
    for i, spec in pairs(getSpectators()) do
      local specHp = spec:getHealthPercent()
      local name = spec:getName():lower()
      monsters = spec:isMonster() and specHp >= minHp and specHp <= maxHp and (#t == 0 or table.find(t, name, true)) and
                 (g_game.getClientVersion() < 960 or spec:getType() < 3) and monsters + 1 or monsters
    end
    return monsters
  end

  for i, spec in pairs(getSpectators(posOrCreature, pattern)) do
      if spec ~= player then
        local specHp = spec:getHealthPercent()
        local name = spec:getName():lower()
        monsters = spec:isMonster() and specHp >= minHp and specHp <= maxHp and (#t == 0 or table.find(t, name)) and
                   (g_game.getClientVersion() < 960 or spec:getType() < 3) and monsters + 1 or monsters
      end
  end

  return monsters
end

-- for area runes only
-- should return valid targets number (int) and position
function getBestTileByPattern(pattern, minHp, maxHp, safePattern, monsterNamesTable)
  local tiles = g_map.getTiles(posz())
  local targetTile = {amount=0,pos=false}

  for i, tile in pairs(tiles) do
    local tPos = tile:getPosition()
    local distance = distanceFromPlayer(tPos)
    local MAX_RUNE_RANGE = 7
	if tile:canShoot() and tile:isWalkable() and distance <= MAX_RUNE_RANGE then
      local amount = getMonstersInArea(2, tPos, pattern, minHp, maxHp, safePattern, monsterNamesTable)
      if amount > targetTile.amount then
        targetTile = {amount=amount,pos=tPos}
      end
    end
  end

  return targetTile.amount > 0 and targetTile or false
end

-- === PVP helpers (patterns) ===
local function isTargetPlayerInArea(anchor, pattern)
  local tgt = target()
  if not tgt or not anchor or not pattern then return false end
  for _, spec in pairs(getSpectators(anchor, pattern)) do
    if spec == tgt then
      return true
    end
  end
  return false
end

-- Escolhe tile (até 4 sqms do player) que, ao aplicar o padrão, inclua o TARGET
local function getBestTileByPatternForPlayer(pattern)
  if not pattern then return false end
  local tgt = target()
  if not tgt then return false end
  local tiles = g_map.getTiles(posz())
  local best, bestDist
  for _, tile in pairs(tiles) do
    local tPos = tile:getPosition()
    local dist = distanceFromPlayer(tPos)
    if tile:canShoot() and tile:isWalkable() and dist < 4 then
      for _, spec in pairs(getSpectators(tPos, pattern)) do
        if spec == tgt then
          if not best or dist < bestDist then
            best, bestDist = tPos, dist
          end
          break
        end
      end
    end
  end
  return best and {amount = 1, pos = best} or false
end



-- === Real Spell Mana Table (auto-generated) ===
local __spellManaCost = {
  ["adana ani"] = 1400,
  ["adana mort"] = 600,
  ["adana pox"] = 200,
  ["adeta sio"] = 200,
  ["adevo grav flam"] = 240,
  ["adevo grav pox"] = 200,
  ["adevo grav tera"] = 750,
  ["adevo grav vis"] = 320,
  ["adevo grav vita"] = 600,
  ["adevo ina"] = 600,
  ["adevo mas flam"] = 600,
  ["adevo mas grav flam"] = 780,
  ["adevo mas grav pox"] = 640,
  ["adevo mas grav vis"] = 1000,
  ["adevo mas hur"] = 570,
  ["adevo mas pox"] = 520,
  ["adevo mas vis"] = 880,
  ["adevo res flam"] = 420,
  ["adito grav"] = 120,
  ["adito tera"] = 200,
  ["adori blank"] = 50,
  ["adori dis min vis"] = 5,
  ["adori flam"] = 460,
  ["adori frigo"] = 460,
  ["adori gran mort"] = 985,
  ["adori infir mas tera"] = 6,
  ["adori infir vis"] = 6,
  ["adori mas flam"] = 530,
  ["adori mas frigo"] = 530,
  ["adori mas tera"] = 430,
  ["adori mas vis"] = 430,
  ["adori min vis"] = 120,
  ["adori san"] = 300,
  ["adori tera"] = 350,
  ["adori vis"] = 350,
  ["adura gran"] = 120,
  ["adura vita"] = 400,
  ["exana amp res"] = 80,
  ["exana flam"] = 30,
  ["exana ina"] = 200,
  ["exana kor"] = 30,
  ["exana mort"] = 40,
  ["exana pox"] = 30,
  ["exana vis"] = 30,
  ["exana vita"] = 50,
  ["exani hur"] = 50,
  ["exani tera"] = 20,
  ["exeta amp res"] = 80,
  ["exeta con"] = 350,
  ["exeta res"] = 30,
  ["exeta vis"] = 80,
  ["exevo con"] = 100,
  ["exevo con flam"] = 290,
  ["exevo con grav"] = 180,
  ["exevo con hur"] = 160,
  ["exevo con mort"] = 140,
  ["exevo con pox"] = 130,
  ["exevo con vis"] = 700,
  ["exevo dis flam hur"] = 5,
  ["exevo flam hur"] = 25,
  ["exevo frigo hur"] = 25,
  ["exevo gran con grav"] = 1000,
  ["exevo gran flam hur"] = 120,
  ["exevo gran frigo hur"] = 170,
  ["exevo gran mas flam"] = 1100,
  ["exevo gran mas frigo"] = 1050,
  ["exevo gran mas tera"] = 700,
  ["exevo gran mas vis"] = 600,
  ["exevo gran mort"] = 250,
  ["exevo gran vis lux"] = 110,
  ["exevo infir con"] = 10,
  ["exevo infir flam hur"] = 8,
  ["exevo infir frigo hur"] = 8,
  ["exevo mas san"] = 160,
  ["exevo max mort"] = 140,
  ["exevo pan"] = 120,
  ["exevo tempo mas san"] = 160,
  ["exevo tera hur"] = 170,
  ["exevo ulus frigo"] = 230,
  ["exevo ulus tera"] = 230,
  ["exevo vis hur"] = 170,
  ["exevo vis lux"] = 40,
  ["exiva"] = 20,
  ["exiva moe res"] = 20,
  ["exori"] = 115,
  ["exori amp kor"] = 225,
  ["exori amp pug"] = 150,
  ["exori amp vis"] = 60,
  ["exori con"] = 25,
  ["exori flam"] = 20,
  ["exori frigo"] = 20,
  ["exori gran"] = 340,
  ["exori gran con"] = 55,
  ["exori gran flam"] = 60,
  ["exori gran frigo"] = 60,
  ["exori gran ico"] = 300,
  ["exori gran mas nia"] = 425,
  ["exori gran mas pug"] = 300,
  ["exori gran nia"] = 210,
  ["exori gran pug"] = 325,
  ["exori gran tera"] = 60,
  ["exori gran vis"] = 60,
  ["exori hur"] = 40,
  ["exori ico"] = 30,
  ["exori infir nia"] = 18,
  ["exori infir pug"] = 3,
  ["exori infir tera"] = 6,
  ["exori infir vis"] = 6,
  ["exori kor"] = 300,
  ["exori mas"] = 160,
  ["exori mas nia"] = 195,
  ["exori mas pug"] = 110,
  ["exori mas res"] = 80,
  ["exori max flam"] = 100,
  ["exori max frigo"] = 100,
  ["exori max tera"] = 100,
  ["exori max vis"] = 100,
  ["exori med pug"] = 180,
  ["exori min"] = 200,
  ["exori min flam"] = 6,
  ["exori moe"] = 400,
  ["exori moe ico"] = 20,
  ["exori mort"] = 20,
  ["exori nia"] = 50,
  ["exori pug"] = 30,
  ["exori san"] = 20,
  ["exori tera"] = 20,
  ["exori vis"] = 20,
  ["exura dis"] = 5,
  ["exura gran sio"] = 400,
  ["exura gran tio"] = 210,
  ["exura infir"] = 6,
  ["exura infir ico"] = 10,
  ["exura mas nia"] = 250,
  ["utamo mas sio"] = 90,
  ["utamo tempo"] = 200,
  ["utamo tempo san"] = 400,
  ["utamo tio"] = 500,
  ["utamo vita"] = 50,
  ["utana vid"] = 440,
  ["utani gran hur"] = 100,
  ["utani hur"] = 60,
  ["utani tempo hur"] = 100,
  ["uteta res dru"] = 2200,
  ["uteta res eq"] = 800,
  ["uteta res sac"] = 1500,
  ["uteta res tio"] = 1200,
  ["uteta res ven"] = 2200,
  ["uteta tio"] = 110,
  ["utevo gran lux"] = 60,
  ["utevo gran res dru"] = 3000,
  ["utevo gran res eq"] = 1000,
  ["utevo gran res sac"] = 2000,
  ["utevo gran res tio"] = 1500,
  ["utevo gran res ven"] = 3000,
  ["utevo grav san"] = 500,
  ["utevo lux"] = 20,
  ["utevo mas sio"] = 75,
  ["utevo nia"] = 500,
  ["utevo res ina"] = 100,
  ["utevo vis lux"] = 140,
  ["utito mas sio"] = 60,
  ["utito tempo"] = 290,
  ["utito tempo san"] = 450,
  ["utito virtu"] = 210,
  ["utori flam"] = 30,
  ["utori kor"] = 30,
  ["utori mas sio"] = 120,
  ["utori mort"] = 30,
  ["utori pox"] = 30,
  ["utori san"] = 30,
  ["utori virtu"] = 210,
  ["utori vis"] = 30,
  ["utura"] = 75,
  ["utura gran"] = 165,
  ["utura mas sio"] = 120,
  ["utura tio"] = 210
}

local function __normalizeSpellWords(words)
  if not words or words == "" then return "" end
  local w = words:lower()
  w = w:gsub("%s+", " ")
  w = w:match("^%s*(.-)%s*$") or w
  return w
end

local function getSpellManaCost(words)
  local key = __normalizeSpellWords(words)
  return __spellManaCost[key] or 0
end

local function __hasMana(spellWords)
  local need = getSpellManaCost(spellWords)
  if need <= 0 then return true end -- unknown cost: don't block
  return mana() >= need
end

-- === /Real Spell Mana Table ===

function executeAttackBotAction(categoryOrPos, idOrFormula, cooldown)
  -- CORREÇÃO: Priorizar cooldown automático quando "Check spell cooldowns" está ativado
  local finalCooldown = cooldown or 0
  
  if currentSettings.Cooldown and type(idOrFormula) == "string" then
    -- Se cooldown automático está ativado E é uma spell, usar cooldown automático
    local autoCooldown = getSpellCooldown(idOrFormula)
    finalCooldown = autoCooldown
  elseif currentSettings.Cooldown and type(idOrFormula) == "number" then
    -- Se cooldown automático está ativado E é uma runa, usar 2000ms
    finalCooldown = 2000
  else
    -- Usar cooldown manual configurado pelo usuário
    finalCooldown = cooldown or 0
  end
  
  -- NOVO: Registrar uso da spell para ativar cooldown do grupo
  if type(idOrFormula) == "string" then
    registerSpellUsed(idOrFormula)
  end
  
  if categoryOrPos == 4 or categoryOrPos == 5 or categoryOrPos == 1 then
    if type(idOrFormula) == "string" then
      if not __hasMana(idOrFormula) then return end
    end
    cast(idOrFormula, finalCooldown)
  elseif categoryOrPos == 3 then 
    useWith(idOrFormula, target())
  end
end

-- support function covered, now the main loop
macro(100, function()
  if not currentSettings.enabled then return end
  if #currentSettings.attackTable == 0 or isInPz() or not target() then return end
  
  -- CORREÇÃO CRÍTICA: Verificação rigorosa do cooldown group
  -- Verifica se há qualquer cooldown ativo no grupo 1 (spells/runas)
  if modules.game_cooldown.isGroupCooldownIconActive(1) then return end

  if currentSettings.Training and target() and target():getName():lower():find("training") then return end

  -- CORREÇÃO: Delay baseado no cooldown automático
  if currentSettings.Cooldown then
    -- Com cooldown automático: delay menor mas seguro
    delay(150)
  else
    -- Sem cooldown automático: delay maior para segurança
    delay(600)
  end

  local monstersN = 0
  local monstersE = 0
  local monstersS = 0
  local monstersW = 0
  monstersN = getCreaturesInArea(pos(), posN, 2)
  monstersE = getCreaturesInArea(pos(), posE, 2)
  monstersS = getCreaturesInArea(pos(), posS, 2)
  monstersW = getCreaturesInArea(pos(), posW, 2)
  local posTable = {monstersE, monstersN, monstersS, monstersW}
  local bestSide = 0
  local bestDir
  -- pulling out the biggest number
  for i, v in pairs(posTable) do
    if v > bestSide then
        bestSide = v
    end
  end
  -- associate biggest number with turn direction
  if monstersN == bestSide then bestDir = 0
    elseif monstersE == bestSide then bestDir = 1
    elseif monstersS == bestSide then bestDir = 2
    elseif monstersW == bestSide then bestDir = 3
  end

  if currentSettings.Rotate then
    if player:getDirection() ~= bestDir and bestSide > 0 then
      turn(bestDir)
      return
    end
  end

  -- support functions done, main spells now
  for i, child in ipairs(panel.entryList:getChildren()) do
    local entry = child.params
    local attackData = entry.itemId > 100 and entry.itemId or entry.spell
    if entry.enabled and manapercent() >= entry.mana then
        
        if currentSettings.pvpMode then
          -- ===== MODO PVP: Atacar APENAS players =====
          local canUseInPvp = false
          if type(attackData) == "string" then
            -- CORREÇÃO APLICADA: Verificação de grupo híbrida incluída
            canUseInPvp = attackData ~= "" and __hasMana(entry.spell) and canUseSpellWithGroup(entry.spell) and canCast(entry.spell, currentSettings.ignoreMana, not currentSettings.Cooldown)
          else
            -- Para runas/items: verificar se tem item disponível (e visível, se configurado)
            canUseInPvp = entry.itemId > 100 and (not currentSettings.Visible or findItem(entry.itemId))
          end

          local tgt = target()
          if canUseInPvp and tgt and tgt:isPlayer() and tgt:canShoot() then

            -- CORREÇÃO: Turn para o player target (igual ao sistema de monsters)
            if currentSettings.Rotate then
              local targetPos = tgt:getPosition()
              local playerPos = player:getPosition()
              
              if targetPos and playerPos then
                -- Calcular direção para o player target (mesma lógica dos monsters)
                local deltaX = targetPos.x - playerPos.x
                local deltaY = targetPos.y - playerPos.y
                local direction = 0
                
                -- Determinar direção principal (priorizar X se igual)
                if math.abs(deltaX) >= math.abs(deltaY) then
                  if deltaX > 0 then direction = 1 -- East
                  else direction = 3 -- West
                  end
                else
                  if deltaY > 0 then direction = 2 -- South
                  else direction = 0 -- North
                  end
                end
                
                -- Virar se necessário (igual aos monsters)
                if player:getDirection() ~= direction then
                  turn(direction)
                  return -- Aguarda próximo ciclo após virar
                end
              end
            end

            -- 4) Empowerment (buff) dentro do range (entry.pattern guarda range)
            if entry.category == 4 and not isBuffed() then
              if distanceFromPlayer(tgt:getPosition()) <= entry.pattern then
                return executeAttackBotAction(entry.category, attackData, entry.cooldown)
              end

            -- 1/3) Single-target spells (ou armas especiais single)
            elseif entry.category == 1 or entry.category == 3 then
              if distanceFromPlayer(tgt:getPosition()) <= entry.pattern then
                return executeAttackBotAction(entry.category, attackData, entry.cooldown)
              end

            -- 5) Magias de área: só lança se o TARGET estiver dentro do padrão
            elseif entry.category == 5 then
              local pCat = entry.patternCategory
              local basePattern = spellPatterns[pCat][entry.pattern][1] -- padrão geometria base
              -- mesma âncora usada no PVE: waves/beams ancoram no player; áreas circulares em pos()
              -- small wave (pattern == 9) must also anchor on player â€" usar >=9 cobre 9,10,11
			  local anchorParam = (entry.pattern == 2 or entry.pattern == 6 or entry.pattern == 7 or entry.pattern >= 9) and player or pos()
              if isTargetPlayerInArea(anchorParam, basePattern) then
                return executeAttackBotAction(entry.category, attackData, entry.cooldown)
              end

            -- 2) Runas de área: escolhe tile que inclua o TARGET dentro do padrão
            elseif entry.category == 2 then
              local pCat = entry.patternCategory
              local basePattern = spellPatterns[pCat][entry.pattern][1]
              local data = getBestTileByPatternForPlayer(basePattern)
              if data and data.pos then
                local tile = g_map.getTile(data.pos)
                if tile and tile:getTopUseThing() then
                  return useWith(attackData, tile:getTopUseThing())
                end
              end
            end
          end
        else
          -- ===== MODO PVE: Atacar APENAS monsters =====
          -- CORREÇÃO APLICADA: Verificação de grupo híbrida incluída
          if (type(attackData) == "string" and __hasMana(entry.spell) and canUseSpellWithGroup(entry.spell) and canCast(entry.spell, currentSettings.ignoreMana, not currentSettings.Cooldown)) or (entry.itemId > 100 and (not currentSettings.Visible or findItem(entry.itemId))) then
            if target():isMonster() and target():canShoot() then
            -- empowerment
            if entry.category == 4 and not isBuffed() then
              local monsterAmount = getMonstersInArea(entry.category, nil, nil, entry.minHp, entry.maxHp, false, entry.monsters)
              if (entry.orMore and monsterAmount >= entry.count or not entry.orMore and monsterAmount == entry.count) and distanceFromPlayer(target():getPosition()) <= entry.pattern then
                return executeAttackBotAction(entry.category, attackData, entry.cooldown)
              end
            --
            elseif entry.category == 1 or entry.category == 3 then
              local monsterAmount = getMonstersInArea(entry.category, nil, nil, entry.minHp, entry.maxHp, false, entry.monsters)
              if (entry.orMore and monsterAmount >= entry.count or not entry.orMore and monsterAmount == entry.count) and distanceFromPlayer(target():getPosition()) <= entry.pattern then
                return executeAttackBotAction(entry.category, attackData, entry.cooldown)
              end
            elseif entry.category == 5 then
              local pCat = entry.patternCategory
              local pattern = entry.pattern
              local anchorParam = (pattern == 2 or pattern == 6 or pattern == 7 or pattern >= 9) and player or pos()
              local safe = currentSettings.PvpSafe and spellPatterns[pCat][entry.pattern][2] or false
              local monsterAmount = pCat ~= 8 and getMonstersInArea(entry.category, anchorParam, spellPatterns[pCat][entry.pattern][1], entry.minHp, entry.maxHp, safe, entry.monsters)
              if (pattern ~= 8 and (entry.orMore and monsterAmount >= entry.count or not entry.orMore and monsterAmount == entry.count)) or (pattern == 8 and bestSide >= entry.count and (not currentSettings.PvpSafe or getPlayers(2) == 0)) then
                if (not currentSettings.BlackListSafe or not isBlackListedPlayerInRange(currentSettings.AntiRsRange)) and (not currentSettings.Kills or killsToRs() > currentSettings.KillsAmount) then
                  return executeAttackBotAction(entry.category, attackData, entry.cooldown)
                end
              end
            elseif entry.category == 2 then
              local pCat = entry.patternCategory
              local safe = currentSettings.PvpSafe and spellPatterns[pCat][entry.pattern][2] or false
              local data = getBestTileByPattern(spellPatterns[pCat][entry.pattern][1], entry.minHp, entry.maxHp, safe, entry.monsters)
              local monsterAmount
              local pos
              if data then
                monsterAmount = data.amount
                pos = data.pos
              end
              if monsterAmount and (entry.orMore and monsterAmount >= entry.count or not entry.orMore and monsterAmount == entry.count) then
                if (not currentSettings.BlackListSafe or not isBlackListedPlayerInRange(currentSettings.AntiRsRange)) and (not currentSettings.Kills or killsToRs() > currentSettings.KillsAmount) then
                  return useWith(attackData, g_map.getTile(pos):getTopUseThing())
                end
              end
            end
            
          end
        end
      end
    end
  end
end)
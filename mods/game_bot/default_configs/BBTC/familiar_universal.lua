-- ========================================================================
-- SCRIPT FAMILIAR UNIVERSAL - Versão 1.5 (LOGIN-SAFE)
-- - Cria o macro apenas após estar online (evita callback nil no cooldown.lua)
-- - Força 'callback' presente no objeto macro, mesmo em forks que não setam
-- - Compatível com macro() de 2 ou 3 argumentos; usa saySpell() se houver
-- ========================================================================

-- =========================[ HELPERS GERAIS ]==============================

local function timeNow()
  if type(now) == "number" then return now end
  if type(now) == "function" then
    local ok, val = pcall(now)
    if ok and type(val) == "number" then return val end
  end
  if g_clock and type(g_clock.millis) == "function" then
    local ok, val = pcall(g_clock.millis, g_clock)
    if ok and type(val) == "number" then return val end
  end
  return math.floor((os.clock() or 0) * 1000)
end

local function addEventCompat(fn, delay)
  delay = delay or 0
  if type(scheduleEvent) == "function" then
    local ok = pcall(function() scheduleEvent(fn, delay) end)
    if ok then return end
  end
  if type(addEvent) == "function" then
    local ok = pcall(function() addEvent(fn, delay) end)
    if ok then return end
  end
  if type(schedule) == "function" then
    local ok = pcall(function() schedule(delay, fn) end)
    if ok then return end
  end
  -- Fallback: chama direto (último recurso)
  pcall(fn)
end

local function isGameOnline()
  if not g_game then return false end
  local f = g_game.isOnline
  if type(f) == "boolean" then return f end
  if type(f) == "function" then
    local ok, res = pcall(function() return f(g_game) end)
    if ok and type(res) == "boolean" then return res end
    ok, res = pcall(function() return g_game:isOnline() end)
    if ok and type(res) == "boolean" then return res end
    ok, res = pcall(function() return g_game.isOnline() end)
    if ok and type(res) == "boolean" then return res end
  end
  return false
end

local function whenOnline(fn, checkEveryMs)
  checkEveryMs = checkEveryMs or 200
  local function retry()
    if isGameOnline() and player then
      pcall(fn)
    else
      addEventCompat(retry, checkEveryMs)
    end
  end
  addEventCompat(retry, checkEveryMs)
end

local function safeSay(text)
  local ok, res = pcall(function()
    if isGameOnline() then
      say(text); return true
    end
    return false
  end)
  return ok and res
end

local function castSpellCompat(spellText)
  if type(saySpell) == "function" then
    local ok = pcall(function() saySpell(spellText) end)
    if ok then return true end
  end
  return safeSay(spellText)
end

-- macro compatível: sempre devolve objeto com .callback
local function createMacroCompat(interval, title, fn)
  -- tenta (interval, title, fn)
  local ok, obj = pcall(function() return macro(interval, title, fn) end)
  if ok and type(obj) == "table" then
    if obj.callback == nil then obj.callback = fn end
    return obj
  end
  -- tenta (interval, fn)
  ok, obj = pcall(function() return macro(interval, fn) end)
  if ok and type(obj) == "table" then
    if obj.callback == nil then obj.callback = fn end
    return obj
  end
  -- fallback inócuo
  return { isFallback = true, callback = fn }
end

-- =========================[ CONFIG DEFAULT UI ]===========================
if type(UI) == "table" and type(UI.Separator) == "function" then UI.Separator() end

-- =========================[ ESTADO E CONFIG ]=============================
local CONFIG = {
  enabled    = true,
  autoSummon = true
}

local VOCATION_CONFIG = nil
local lastSummonTime = 0
local lastCheckTime  = 0
local initStartTime  = timeNow()

-- =========================[ FUNÇÕES DO FAMILIAR ]========================
local function isFamiliarOnScreen()
  local ok, res = pcall(function()
    local specs = getSpectators and getSpectators() or {}
    for _, spec in ipairs(specs) do
      if spec and not spec:isPlayer() and VOCATION_CONFIG and spec:getName() == VOCATION_CONFIG.familiarName then
        return true
      end
    end
    return false
  end)
  if not ok then return false end
  return res
end

local function canSummonFamiliar()
  local nowMs = timeNow()
  if (nowMs - initStartTime) < 5000 then return false end -- aguarda 5s pós-login
  if not player or not VOCATION_CONFIG then return false end

  local lvl  = player.getLevel and player:getLevel() or 0
  if not lvl or lvl < VOCATION_CONFIG.minLevel then return false end

  local mana = player.getMana and player:getMana() or 0
  if not mana or mana < VOCATION_CONFIG.manaCost then return false end

  if (nowMs - lastSummonTime) < VOCATION_CONFIG.cooldown then return false end
  return true
end

local function executeFamiliarSummon()
  if not CONFIG.enabled or not CONFIG.autoSummon then return end
  if not isGameOnline() or not player or not VOCATION_CONFIG then return end

  local nowMs = timeNow()
  if (nowMs - lastCheckTime) < 1000 then return end -- throttle 1s
  lastCheckTime = nowMs

  if isFamiliarOnScreen() then return end
  if not canSummonFamiliar() then return end

  if castSpellCompat(VOCATION_CONFIG.spell) then
    lastSummonTime = nowMs
  end
end

local function familiarTick()
  pcall(executeFamiliarSummon) -- nunca propaga erro ao scheduler
end

-- =========================[ BOOT PÓS-LOGIN ]=============================
local familiarMacro -- declarado aqui para ficar global no ambiente

local function initAfterOnline()
  if not player then return end

  local voc = player:getVocation()
  -- Apenas 5 vocações (e promovidas)
  local supported = (voc == 1 or voc == 11 or voc == 2 or voc == 12 or voc == 3 or voc == 13 or voc == 4 or voc == 14 or voc == 5 or voc == 15)
  if not supported then
    return -- não cria macro para vocações não suportadas
  end

  -- Monta VOCATION_CONFIG já com player on-line (evita acessar player nil)
  if voc == 1 or voc == 11 then
    VOCATION_CONFIG = {
      spell = "utevo gran res eq",
      familiarName = "Knight Familiar",
      macroName = "Knight Familiar",
      manaCost = 1000,
      cooldown = 1800000,
      minLevel = 200,
      vocationName = (voc == 1) and "Knight" or "Elite Knight"
    }
    if type(setDefaultTab) == "function" then setDefaultTab("Cave") end

  elseif voc == 2 or voc == 12 then
    VOCATION_CONFIG = {
      spell = "utevo gran res sac",
      familiarName = "Paladin Familiar",
      macroName = "Paladin Familiar",
      manaCost = 2000,
      cooldown = 1800000,
      minLevel = 200,
      vocationName = (voc == 2) and "Paladin" or "Royal Paladin"
    }
    if type(setDefaultTab) == "function" then setDefaultTab("Cave") end

  elseif voc == 3 or voc == 13 then
    VOCATION_CONFIG = {
      spell = "utevo gran res ven",
      familiarName = "Sorcerer Familiar",
      macroName = "Sorcerer Familiar",
      manaCost = 3000,
      cooldown = 1800000,
      minLevel = 200,
      vocationName = (voc == 3) and "Sorcerer" or "Master Sorcerer"
    }
    if type(setDefaultTab) == "function" then setDefaultTab("Cave") end

  elseif voc == 4 or voc == 14 then
    VOCATION_CONFIG = {
      spell = "utevo gran res dru",
      familiarName = "Druid Familiar",
      macroName = "Druid Familiar",
      manaCost = 3000,
      cooldown = 1800000,
      minLevel = 200,
      vocationName = (voc == 4) and "Druid" or "Elder Druid"
    }
    if type(setDefaultTab) == "function" then setDefaultTab("Cave") end

  elseif voc == 5 or voc == 15 then
    VOCATION_CONFIG = {
      spell = "utevo gran res tio",
      familiarName = "Monk Familiar",
      macroName = "Monk Familiar",
      manaCost = 1500,
      cooldown = 1800000,
      minLevel = 200,
      vocationName = (voc == 5) and "Monk" or "Exalted Monk"
    }
    if type(setDefaultTab) == "function" then setDefaultTab("Cave") end
  end

  -- Reseta marcadores de tempo no primeiro login
  initStartTime  = timeNow()
  lastCheckTime  = 0
  lastSummonTime = 0

  -- >>> CRIA O MACRO SÓ AGORA (após login e VOCATION_CONFIG pronta) <<<
  familiarMacro = createMacroCompat(1000, VOCATION_CONFIG.macroName, familiarTick)
end

-- Aguarda realmente estar online e com player disponível antes de inicializar
whenOnline(initAfterOnline, 200)

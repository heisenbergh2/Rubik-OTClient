-- ===== Auto Equip 2 regras independentes (HP/Mana), otimizado para performance máxima =====
setDefaultTab("HP")

-- CONFIGURAÇÕES DE PERFORMANCE CRÍTICA
local MACRO_INTERVAL = 100    -- 100ms = detecção 2x mais rápida
local RULE_COOLDOWN = 250     -- reduzido para permitir reação mais rápida
local SLOT_COOLDOWN = 150     -- permite trocas rápidas em emergências

local RULES = 2  -- 2 regras independentes por configuracao

UI.Label("Auto equip por HP/Mana (2 regras independentes)")
UI.Separator()

if type(storage.autoEquip2) ~= "table" then storage.autoEquip2 = {} end
if type(storage.autoEquip2Rules) ~= "table" then storage.autoEquip2Rules = {} end

-- ===== helpers =====
local function clamp(n,a,b) if n<a then return a elseif n>b then return b else return n end end
local function toint(x,def) x=tonumber(x) return x and math.floor(x) or def end

local function hpPct()
  if type(hppercent)=="function" then return hppercent() end
  local p=g_game.getLocalPlayer and g_game.getLocalPlayer()
  if p and p.getHealth and p.getMaxHealth and p:getMaxHealth()>0 then
    return math.floor((p:getHealth()/p:getMaxHealth())*100)
  end
  return 100
end

local function mpPct()
  if type(manapercent)=="function" then return manapercent() end
  local p=g_game.getLocalPlayer and g_game.getLocalPlayer()
  if p and p.getMana and p.getMaxMana and p:getMaxMana()>0 then
    return math.floor((p:getMana()/p:getMaxMana())*100)
  end
  return 100
end

-- encontra backpack principal (evita store/inbox/stash/reward/depot/market/mail/supply)
local function findMainBackpack()
  local bad = { "store","inbox","stash","reward","depot","mail","market","supply" }
  for _, cont in pairs(g_game.getContainers()) do
    local name = (cont.getName and cont:getName() or ""):lower()
    local skip=false
    for __,k in ipairs(bad) do if name:find(k,1,true) then skip=true break end end
    if not skip then return cont end
  end
  -- fallback: usar qualquer container se não encontrar um "limpo"
  local containers = g_game.getContainers()
  if #containers > 0 then return containers[1] end
  return nil
end

-- equipar item do container para slot (ignora store/inbox como fonte)
local function equipFromContainers(itemId, slot)
  if not itemId or itemId<=0 or not slot or slot<=0 then return false end
  local s=getSlot(slot); if s and s:getId()==itemId then return false end -- ja esta equipado
  for _, cont in pairs(g_game.getContainers()) do
    local name=(cont.getName and cont:getName() or ""):lower()
    if not (name:find("store",1,true) or name:find("inbox",1,true)) then
      for __, it in ipairs(cont:getItems()) do
        if it:getId()==itemId then
          g_game.move(it,{x=65535,y=slot,z=0},it:getCount())
          return true
        end
      end
    end
  end
  return false
end

-- desequipar para a backpack principal
local function unequipToMainBackpack(slot)
  if not slot or slot<=0 then return false end
  local it=getSlot(slot); if not it then return false end -- ja esta vazio
  local cont=findMainBackpack(); if not cont then return false end
  local dest=(cont.getSlotPosition and cont:getSlotPosition()) or (cont.getPosition and cont:getPosition()) or cont
  g_game.move(it, dest, it:getCount())
  return true
end

-- precisa agir? (compara com o que esta no slot)
local function needAction(slot, targetId)
  local s=getSlot(slot)
  if targetId < 0 then return false end  -- nada a fazer
  if targetId == 0 then return s ~= nil end -- desequipar se tem algo
  return (not s) or s:getId() ~= targetId -- equipar se nao tem ou tem item diferente
end

-- ===== UI (2 configuracoes independentes). Cada configuracao gera 2 regras =====
for i=1,RULES do
  storage.autoEquip2[i] = storage.autoEquip2[i] or { on=false, title="Config "..i, item1=0, item2=0, slot=0 }
  storage.autoEquip2Rules[i] = storage.autoEquip2Rules[i] or { mode="MANA", low=40, high=41, actionHigh="equip2" }

  local config = storage.autoEquip2[i]
  local extra = storage.autoEquip2Rules[i]

  UI.TwoItemsAndSlotPanel(config, function(_, np) storage.autoEquip2[i]=np end)

  UI.Label(string.format("Configuracao %d -> Modo / Item1:<=%% / Item2:>=%% / Acao para Item2", i))

  local btnMode = UI.Button("Modo: "..(extra.mode or "MANA"))
  btnMode.onClick = function(w)
    extra.mode = ((extra.mode or "MANA")=="MANA") and "HP" or "MANA"
    w:setText("Modo: "..extra.mode)
  end

  local lowEdit  = UI.TextEdit(tostring(extra.low or 40))
  local highEdit = UI.TextEdit(tostring(extra.high or 41))
  lowEdit.onTextChange = function(_,txt)
    extra.low = clamp(toint(txt,extra.low or 40),0,100)
    if extra.high <= extra.low then 
      extra.high = math.min(extra.low + 1, 100) -- corrigido: garante que nao ultrapasse 100
    end
  end
  highEdit.onTextChange= function(_,txt)
    extra.high = clamp(toint(txt,extra.high or 41),0,100)
    if extra.high <= extra.low then 
      extra.low = math.max(extra.high - 1, 0) -- corrigido: garante que nao fique negativo
    end
  end

  local btnHigh = UI.Button((extra.actionHigh=="unequip") and "Item2: Desequipar" or "Item2: Equipar")
  btnHigh.onClick = function(w)
    extra.actionHigh = (extra.actionHigh=="unequip") and "equip2" or "unequip"
    w:setText((extra.actionHigh=="unequip") and "Item2: Desequipar" or "Item2: Equipar")
  end

  UI.Separator()
end

-- ===== CORE: cada configuracao gera 2 regras independentes =====
local ruleCD   = {}  -- cooldown por regra (ms)
local slotCD   = {}  -- cooldown por slot (ms)

-- gera candidatos de TODAS as regras (2 configs x 2 regras cada = 4 no total)
local function getAllCandidates(hpP, mpP)
  local candidates = {}

  for configIdx=1,RULES do
    local config = storage.autoEquip2[configIdx]
    local extra = storage.autoEquip2Rules[configIdx]

    if not (config and config.on and (config.slot or 0) > 0) then
      goto nextConfig
    end

    local slot = config.slot
    local mode = (extra.mode or "MANA")
    local pct = (mode=="HP") and hpP or mpP
    local low = extra.low or 0
    local high = extra.high or 0

    -- REGRA 1: Item1 quando pct <= low
    local ruleId1 = configIdx * 10 + 1 -- 11, 21
    if (config.item1 or 0) > 0 and pct <= low and now >= (ruleCD[ruleId1] or 0) then
      local target = config.item1
      if needAction(slot, target) then
        table.insert(candidates, {
          ruleId = ruleId1,
          configIdx = configIdx,
          slot = slot,
          target = target,
          priority = 1 -- menor prioridade (equipar item1)
        })
      end
    end

    -- REGRA 2: Item2 ou Desequipar quando pct >= high
    local ruleId2 = configIdx * 10 + 2 -- 12, 22
    if pct >= high and now >= (ruleCD[ruleId2] or 0) then
      local target
      local priority

      if extra.actionHigh == "unequip" or (config.item2 or 0) <= 0 then
        target = 0
        priority = 3 -- maior prioridade (desequipar)
      else
        target = config.item2
        priority = 2 -- prioridade media (equipar item2)
      end

      if needAction(slot, target) then
        table.insert(candidates, {
          ruleId = ruleId2,
          configIdx = configIdx,
          slot = slot,
          target = target,
          priority = priority
        })
      end
    end

    ::nextConfig::
  end

  return candidates
end

-- aplica alvo
local function applyAction(slot, targetId)
  if targetId == 0 then
    return unequipToMainBackpack(slot)
  else
    return equipFromContainers(targetId, slot)
  end
end

-- ===== MACRO PRINCIPAL OTIMIZADO =====
macro(MACRO_INTERVAL, function()
  -- pelo menos uma configuracao ON?
  local anyOn=false
  for i=1,RULES do
    local cfg = storage.autoEquip2[i]
    if cfg and cfg.on then anyOn=true break end
  end
  if not anyOn then return end

  local hpP = hpPct()
  local mpP = mpPct()

  local allCandidates = getAllCandidates(hpP, mpP)
  if #allCandidates == 0 then return end

  -- agrupa por slot e filtra por cooldown do slot
  local bySlot = {}
  for _, cand in ipairs(allCandidates) do
    local slot = cand.slot
    if (slotCD[slot] or 0) <= now then
      if not bySlot[slot] then bySlot[slot] = {} end
      table.insert(bySlot[slot], cand)
    end
  end

  for slot, list in pairs(bySlot) do
    -- ordena por prioridade (desc) e por configIdx (asc)
    table.sort(list, function(a,b)
      if a.priority ~= b.priority then return a.priority > b.priority end
      return a.configIdx < b.configIdx
    end)

    local winner = list[1]
    local ok = applyAction(winner.slot, winner.target)
    if ok then
      ruleCD[winner.ruleId] = now + RULE_COOLDOWN
      slotCD[slot] = now + SLOT_COOLDOWN
      return -- uma acao por ciclo
    end
  end
end)
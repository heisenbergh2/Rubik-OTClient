-- Friend Healer (new_healer.lua) — versão reforçada
-- Ajustes principais já aplicados:
-- 1) Gate de auto-proteção menos agressivo (HP & MP) em vez de (HP or MP)
-- 2) Removido bloqueio global por canShoot; itens continuam respeitando alcance/uso
-- 3) Vocação: blocklist (bloqueia só se detectar voc desmarcada; desconhecidos não bloqueiam)
-- 4) Substituição segura de 'me = g_game.getLocalPlayer()'
-- 5) Normalização do nome ao adicionar Custom Players (sem espaço inicial)
-- 6) Uso de item de cura robusto (useInventoryItemWith → fallback useWith)
-- 7) Mas Res (raio 3), cluster simples e mínimo configurado
-- 8) ***Novo*** Detector interno de vocação por LOOK + regex, silencioso e com cache

setDefaultTab("Main")
local panelName = "newHealer"
local ui = setupUI([[
Panel
  height: 19

  BotSwitch
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    text-align: center
    width: 130
    !text: tr('Friend Healer')

  Button
    id: edit
    anchors.top: prev.top
    anchors.left: prev.right
    anchors.right: parent.right
    margin-left: 3
    height: 17
    text: Setup

]])
ui:setId(panelName)

-- =========================
-- Config / Storage padrão
-- =========================
if not storage[panelName] or not storage[panelName].priorities then
    storage[panelName] = nil
end

-- Forçar recriação se ainda tiver Mana Item (versão antiga)
if storage[panelName] and storage[panelName].priorities then
    for i, priority in ipairs(storage[panelName].priorities) do
        if priority.name == "Mana Item" then
            storage[panelName] = nil
            break
        end
    end
end

if not storage[panelName] then
    storage[panelName] = {
        enabled = false,
        customPlayers = {},
        vocations = {},
        groups = {},
        priorities = {
            {name="Custom Spell",           enabled=false, custom=true},
            {name="Exura Gran Sio",         enabled=true,  strong = true},
            {name="Exura Sio",              enabled=true,  normal = true},
            {name="Exura Gran Mas Res",     enabled=true,  area   = true},
            {name="Health Item",            enabled=true,  health = true},
        },
        settings = {
            {type="HealScroll",     text="Item Range: ",                 value=6},    -- [1]
            {type="HealItem",       text="Health Item ",                 value=3160}, -- [2]
            {type="HealScroll",     text="Mas Res Players: ",            value=2},    -- [3]
            {type="HealScroll",     text="Heal Friend at: ",             value=80},   -- [4]
            {type="HealScroll",     text="Use Gran Sio at: ",            value=30},   -- [5]
            {type="HealScroll",     text="Min Player HP%: ",             value=90},   -- [6]
            {type="HealScroll",     text="Min Player MP%: ",             value=30},   -- [7]
        },
        conditions = {
            knights = true,
            paladins = true,
            druids = false,
            sorcerers = false,
            monks = true,
            party = true,
            guild = false,
            friends = false,
            customPlayers = true
        }
    }
end

local config = storage[panelName]
local healerWindow = UI.createWindow('FriendHealer')
healerWindow:hide()
healerWindow:setId(panelName)

ui.title:setOn(config.enabled)
ui.title.onClick = function(widget)
    config.enabled = not config.enabled
    widget:setOn(config.enabled)

    -- [Plano B opcional]: ligar automaticamente o extras.checkPlayer quando houver restrições de vocação
    if config.enabled then
      local hasRestrictions = not (config.conditions.knights and config.conditions.paladins and
                                   config.conditions.druids and config.conditions.sorcerers and
                                   config.conditions.monks)
      if hasRestrictions then
        storage.extras = storage.extras or {}
        storage.extras.checkPlayer = true   -- força o script 'extras' a checar jogadores
      end
    end
end

ui.edit.onClick = function()
    healerWindow:show()
    healerWindow:raise()
    healerWindow:focus()
end

local conditions = healerWindow.conditions
local targetSettings = healerWindow.targetSettings
local customList = healerWindow.customList
local priority = healerWindow.priority

-- =========================
-- Custom Players UI
-- =========================
local function capitalizeFirstLetter(str) return (string.gsub(str, "^%l", string.upper)) end
local function normalizeName(raw)
  local words = string.split(raw or "", " ")
  local parts = {}
  for _, w in ipairs(words) do if w and w:len() > 0 then parts[#parts+1] = capitalizeFirstLetter(w:lower()) end end
  return table.concat(parts, " ")
end

for name, health in pairs(config.customPlayers) do
    local widget = UI.createWidget("HealerPlayerEntry", customList.playerList.list)
    widget.remove.onClick = function() config.customPlayers[name] = nil; widget:destroy() end
    widget:setText("["..health.."%]  "..name)
end

customList.playerList.onDoubleClick = function() customList.playerList:hide() end
local function clearFields()
    customList.addPanel.name:setText("friend name")
    customList.addPanel.health:setText("1")
    customList.playerList:show()
end
customList.addPanel.add.onClick = function()
    local raw = customList.addPanel.name:getText()
    local health = tonumber(customList.addPanel.health:getText())
    local name = normalizeName(raw)
    if not health then clearFields(); return warn("[Friend Healer] Please enter health percent value!") end
    if name:len() == 0 or name:lower() == "friend name" then clearFields(); return warn("[Friend Healer] Please enter friend name to be added!") end
    if config.customPlayers[name] or config.customPlayers[name:lower()] then clearFields(); return warn("[Friend Healer] Player already added to custom list.") end
    config.customPlayers[name] = health
    local widget = UI.createWidget("HealerPlayerEntry", customList.playerList.list)
    widget.remove.onClick = function() config.customPlayers[name] = nil; widget:destroy() end
    widget:setText("["..health.."%]  "..name)
    clearFields()
end

-- =========================
-- Validação visual
-- =========================
local function validate(widget, category)
    local list = widget:getParent()
    local label = list:getParent().title
    category = category or 0
    -- Mantemos o aviso visual se o usuário quiser, mas o detector interno cobre a necessidade
    if category == 2 and storage.extras and storage.extras.checkPlayer == false then
        label:setColor("#d9321f")
        label:setTooltip("! WARNING ! \nTurn on check players in extras to use this feature! (ou use o detector interno do healer)")
        return
    else
        label:setColor("#dfdfdf")
        label:setTooltip("")
    end
    local checked = false
    for _, child in ipairs(list:getChildren()) do
        if (category == 1 and child.enabled:isChecked()) or child:isChecked() then checked = true end
    end
    if not checked then
        label:setColor("#d9321f")
        label:setTooltip("! WARNING ! \nNo category selected!")
    else
        label:setColor("#dfdfdf")
        label:setTooltip("")
    end
end

-- =========================
-- Vocações / Grupos (UI)
-- =========================
targetSettings.vocations.box.knights:setChecked(config.conditions.knights)
targetSettings.vocations.box.knights.onClick = function(w) config.conditions.knights = not config.conditions.knights; w:setChecked(config.conditions.knights); validate(w, 2) end
targetSettings.vocations.box.paladins:setChecked(config.conditions.paladins)
targetSettings.vocations.box.paladins.onClick = function(w) config.conditions.paladins = not config.conditions.paladins; w:setChecked(config.conditions.paladins); validate(w, 2) end
targetSettings.vocations.box.druids:setChecked(config.conditions.druids)
targetSettings.vocations.box.druids.onClick = function(w) config.conditions.druids = not config.conditions.druids; w:setChecked(config.conditions.druids); validate(w, 2) end
targetSettings.vocations.box.sorcerers:setChecked(config.conditions.sorcerers)
targetSettings.vocations.box.sorcerers.onClick = function(w) config.conditions.sorcerers = not config.conditions.sorcerers; w:setChecked(config.conditions.sorcerers); validate(w, 2) end
if targetSettings.vocations.box.monks then
    targetSettings.vocations.box.monks:setChecked(config.conditions.monks)
    targetSettings.vocations.box.monks.onClick = function(w) config.conditions.monks = not config.conditions.monks; w:setChecked(config.conditions.monks); validate(w, 2) end
end

targetSettings.groups.box.friends:setChecked(config.conditions.friends)
targetSettings.groups.box.friends.onClick = function(w) config.conditions.friends = not config.conditions.friends; w:setChecked(config.conditions.friends); validate(w) end
targetSettings.groups.box.party:setChecked(config.conditions.party)
targetSettings.groups.box.party.onClick   = function(w) config.conditions.party   = not config.conditions.party;   w:setChecked(config.conditions.party);   validate(w) end
targetSettings.groups.box.guild:setChecked(config.conditions.guild)
targetSettings.groups.box.guild.onClick   = function(w) config.conditions.guild   = not config.conditions.guild;   w:setChecked(config.conditions.guild);   validate(w) end
if targetSettings.groups.box.customPlayers then
    targetSettings.groups.box.customPlayers:setChecked(config.conditions.customPlayers)
    targetSettings.groups.box.customPlayers.onClick = function(w) config.conditions.customPlayers = not config.conditions.customPlayers; w:setChecked(config.conditions.customPlayers); validate(w) end
end
targetSettings.groups.box.botserver:hide()

validate(targetSettings.vocations.box.knights)
validate(targetSettings.groups.box.friends)
validate(targetSettings.vocations.box.sorcerers, 2)

-- =========================
-- Settings (sliders e itens)
-- =========================
for _, setting in ipairs(config.settings) do
    local widget = UI.createWidget(setting.type, conditions.box)
    local text, val = setting.text, setting.value
    widget.text:setText(text)
    if setting.type == "HealScroll" then
        widget.text:setText(widget.text:getText()..val)
        if not (text:find("Range") or text:find("Mas Res")) then
            widget.text:setText(widget.text:getText().."%")
        end
        widget.scroll:setValue(val)
        widget.scroll.onValueChange = function(_, value)
            setting.value = value
            widget.text:setText(text..value..( (text:find("Range") or text:find("Mas Res")) and "" or "%"))
        end
        if text:find("Range") or text:find("Mas Res") then widget.scroll:setMaximum(10) end
    else
        widget.item:setItemId(val)
        widget.item:setShowCount(false)
        widget.item.onItemChange = function(w) setting.value = w:getItemId() end
    end
end

-- =========================
-- Prioridades (UI)
-- =========================
local function setCrementalButtons()
    local children = priority.list:getChildren()
    local last = #children
    for i, child in ipairs(children) do
        if i == 1 then child.increment:disable(); child.decrement:enable()
        elseif i == last then child.increment:enable(); child.decrement:disable()
        else child.increment:enable(); child.decrement:enable() end
    end
end

for _, action in ipairs(config.priorities) do
    local widget = UI.createWidget("PriorityEntry", priority.list)
    widget:setText(action.name)
    widget.increment.onClick = function()
        local index = priority.list:getChildIndex(widget)
        local t = config.priorities
        priority.list:moveChildToIndex(widget, index-1)
        t[index], t[index-1] = t[index-1], t[index]
        setCrementalButtons()
    end
    widget.decrement.onClick = function()
        local index = priority.list:getChildIndex(widget)
        local t = config.priorities
        priority.list:moveChildToIndex(widget, index+1)
        t[index], t[index+1] = t[index+1], t[index]
        setCrementalButtons()
    end
    widget.enabled:setChecked(action.enabled)
    widget:setColor(action.enabled and "#98BF64" or "#dfdfdf")
    widget.enabled.onClick = function()
        action.enabled = not action.enabled
        widget:setColor(action.enabled and "#98BF64" or "#dfdfdf")
        widget.enabled:setChecked(action.enabled)
        -- validate(widget, 1) -- (opcional)
    end
    if action.custom then
        widget.onDoubleClick = function()
            local window = modules.client_textedit.show(widget, {title = "Custom Spell", description = "Enter below formula for a custom healing spell"})
            schedule(50, function() window:raise(); window:focus() end)
        end
        widget.onTextChange = function(_, text) action.name = text end
        widget:setTooltip("Double click to set spell formula.")
    end
end
setCrementalButtons()

-- =========================
-- Helpers (grupos)
-- =========================
local function isVipFriend(spec)
    if not spec then return false end
    local name = spec:getName(); if not name then return false end
    local me = g_game.getLocalPlayer(); if not me then return false end
    for _, vip in pairs(g_game.getVips()) do
        if vip[1] == name then
            local icon = tonumber(vip[3]) or 0
            local status = tonumber(vip[2]) or 0
            if icon > 0 or status == 2 then return true end
            return true
        end
    end
    return false
end

local function isGuildMemberOrAlly(spec)
    local emblem = spec and spec:getEmblem()
    return emblem == 1 or emblem == 4 -- 1=ALLY, 4=MEMBER
end

-- =========================
-- Cooldowns + Item helper
-- =========================
local lastItemUse, lastStrongHeal, lastMasRes, lastSio = 0, 0, 0, 0

local function tryUseHealItemOn(target, itemId)
    if g_game.useInventoryItemWith then g_game.useInventoryItemWith(itemId, target); return true end
    local it = findItem(itemId); if it then g_game.useWith(it, target); return true end
    return false
end

-- ==================================================================
-- *** Detector interno de vocação (sem depender do extras.checkPlayer)
-- ==================================================================
local INTERNAL_VOC_DETECT = true
local vocCache = {}     -- [name] = { ek/rp/ms/ed/mk booleans, ts=now }
local lastLookAt = 0
local LOOK_PERIOD = 400 -- ms entre looks para não spammar
local SUPPRESS_WINDOW = 600 -- ms para limpar mensagens de "You see ..." sem poluir chat

-- Regex baseada no extras.lua para capturar texto de look. (não desenhamos nada na tela aqui) :contentReference[oaicite:1]{index=1}
local lookRegex = [[You see ([^\(]*) \(Level ([0-9]*)\)((?:.)* of the ([\w ]*),|)]]

local lastLookMessageAt = 0
onTextMessage(function(mode, text)
    if not INTERNAL_VOC_DETECT then return end
    -- Tentamos mapear vocação a partir do texto do look
    local re = regexMatch(text, lookRegex)
    if #re ~= 0 then
        local name = re[1][2]
        local low = text:lower()
        local ek = low:find("knight") ~= nil
        local rp = low:find("paladin") ~= nil
        local ms = low:find("sorcerer") ~= nil or low:find("mage") ~= nil
        local ed = low:find("druid") ~= nil
        local mk = low:find("monk") ~= nil
        vocCache[name] = {isKnight=ek, isPaladin=rp, isSorcerer=ms, isDruid=ed, isMonk=mk, ts=now}
        lastLookMessageAt = now
        -- Limpa mensagens do chat logo após capturar (não exibe nada ao usuário)
        if now - lastLookMessageAt <= SUPPRESS_WINDOW then
            modules.game_textmessage.clearMessages()
        end
    end
end)

local function queueLook(spec)
    if not INTERNAL_VOC_DETECT then return end
    if now - lastLookAt < LOOK_PERIOD then return end
    lastLookAt = now
    g_game.look(spec, true)  -- forçamos o look no player
end

-- =========================
-- Vocação (detecção + filtro)
-- =========================
local function detectVocation(spec)
    -- 1) API direta (quando existir)
    local ok, voc = pcall(function() return spec:getVocation() end)
    if ok and voc then
        return true,
          (voc==1 or voc==11),(voc==2 or voc==12),(voc==3 or voc==13),
          (voc==4 or voc==14),(voc==5 or voc==15)
    end
    -- 2) Cache interno por look silencioso
    local nm = spec:getName()
    local cached = vocCache[nm]
    if cached then
        return true, cached.isKnight, cached.isPaladin, cached.isSorcerer, cached.isDruid, cached.isMonk
    end
    -- 3) Se houver restrição, pedimos um look (sem poluir UI)
    queueLook(spec)
    return false
end

local function vocationAllowed(spec)
    local allOn = (config.conditions.knights and config.conditions.paladins and
                   config.conditions.druids and config.conditions.sorcerers and
                   config.conditions.monks)
    if allOn then return true end
    local det,isK,isP,isS,isD,isM = detectVocation(spec)
    if not det then return true end -- desconhecido não bloqueia (até o cache popular)
    if (isK and not config.conditions.knights) or
       (isP and not config.conditions.paladins) or
       (isS and not config.conditions.sorcerers) or
       (isD and not config.conditions.druids) or
       (isM and not config.conditions.monks) then
        local nm = spec:getName()
        if config.conditions.customPlayers and config.customPlayers[nm] then
            return true
        end
        return false
    end
    return true
end

-- =========================
-- Threshold helpers
-- =========================
local function getHealThresholdFor(spec)
    local nm = spec:getName()
    local base = config.settings[4].value -- Heal Friend at
    if config.customPlayers[nm] then return config.customPlayers[nm] end
    return base
end
local function deficitPercent(spec)
    local hp = spec:getHealthPercent()
    local th = getHealThresholdFor(spec)
    if hp < th then return (th - hp) end
    return 0
end

-- =========================
-- Execução das ações de cura
-- =========================
local function friendHealerAction(spec)
    local me = g_game.getLocalPlayer(); if not me or not spec then return end

    local name   = spec:getName()
    local health = spec:getHealthPercent()
    local dist   = distanceFromPlayer(spec:getPosition()) or 99

    local itemRange    = config.settings[1].value      -- Item Range
    local healItem     = config.settings[2].value      -- Health Item
    local masResAmount = config.settings[3].value      -- mínimo de players
    local normalHeal   = config.customPlayers[name] or config.settings[4].value
    local strongHeal   = config.customPlayers[name] and (normalHeal/2) or config.settings[5].value

    for _, action in ipairs(config.priorities) do
        if not action.enabled then goto CONTINUE end

        -- ====== EXURA GRAN MAS RES (aprimorado; raio 3) ======
        if action.area and now > lastMasRes then
            local RADIUS = 3
            local othersNeeding = 0
            local selfNeed = (me:getHealthPercent() <= normalHeal) and 1 or 0

            for _, other in ipairs(getSpectators(posz())) do
                if other ~= me and other:isPlayer() then
                    local otherDist = distanceFromPlayer(other:getPosition()) or 99
                    if otherDist <= RADIUS then
                        local ohp = other:getHealthPercent()

                        -- filtros de grupo
                        local myShield = me:getShield()
                        local oShield  = other:getShield()
                        local inActiveParty = other:isPartyMember() and oShield > 0 and oShield <= 10 and myShield > 0 and myShield <= 10
                        local okParty  = config.conditions.party   and inActiveParty
                        local okFriend = config.conditions.friends and isVipFriend(other)
                        local okGuild  = config.conditions.guild   and isGuildMemberOrAlly(other)

                        -- filtro de vocação com detector interno
                        local okVoc    = vocationAllowed(other)

                        if okVoc and (okParty or okFriend or okGuild) and ohp <= normalHeal then
                            othersNeeding = othersNeeding + 1
                        end
                    end
                end
            end

            local totalNeeding = selfNeed + othersNeeding
            if totalNeeding >= masResAmount and totalNeeding > 0 then
                if canCast('exura gran mas res', false, true) then
                    lastMasRes = now + 2000
                    return say('exura gran mas res')
                end
            end
        end
        -- ====== FIM MAS RES ======

        -- *** CURA POR ITEM ***
        if action.health and health <= normalHeal and dist <= itemRange and (now - lastItemUse) >= 1000 then
            if tryUseHealItemOn(spec, healItem) then
                lastItemUse = now
                return
            end
        end

        -- exura gran sio
        if action.strong and health <= strongHeal and now > lastStrongHeal then
            if canCast('exura gran sio', false, true) then
                lastStrongHeal = now + 60000
                return say('exura gran sio "'..name)
            end
        end

        -- exura sio (ou custom spell tratada como normal)
        if (action.normal or action.custom) and health <= normalHeal and now > lastSio then
            if canCast('exura sio', false, true) then
                lastSio = now + 1000
                return say('exura sio "'..name)
            end
        end

        ::CONTINUE::
    end
end

-- =========================
-- Seleção de candidatos
-- =========================
local function isCandidate(spec)
    if not spec or not spec:isPlayer() or spec:isLocalPlayer() then return nil end

    local name  = spec:getName()
    local curHp = spec:getHealthPercent()
    if curHp == 100 or (config.customPlayers[name] and curHp > config.customPlayers[name]) then
        return nil
    end

    -- Vocação: blocklist (desconhecido NÃO bloqueia, mas pedimos look se houver restrição)
    local hasRestrictions = not (config.conditions.knights and config.conditions.paladins and
                                 config.conditions.druids and config.conditions.sorcerers and
                                 config.conditions.monks)
    if hasRestrictions then
        local det,isK,isP,isS,isD,isM = detectVocation(spec)
        if det then
            if (isK and not config.conditions.knights) or
               (isP and not config.conditions.paladins) or
               (isS and not config.conditions.sorcerers) or
               (isD and not config.conditions.druids) or
               (isM and not config.conditions.monks) then
                if not (config.conditions.customPlayers and config.customPlayers[name]) then
                    return nil
                end
            end
        end
        -- se ainda não detectou, a fila de look foi acionada; não bloqueia por enquanto
    end

    -- Regras de grupo
    local me = g_game.getLocalPlayer(); if not me then return nil end
    local oShield  = spec:getShield()
    local myShield = me:getShield()
    local inActiveParty = spec:isPartyMember() and oShield > 0 and oShield <= 10 and myShield > 0 and myShield <= 10

    local okParty  = config.conditions.party   and inActiveParty
    local okFriend = config.conditions.friends and isVipFriend(spec)
    local okGuild  = config.conditions.guild   and isGuildMemberOrAlly(spec)
    local okCustom = config.conditions.customPlayers and (config.customPlayers[name] ~= nil)

    if not (okParty or okFriend or okGuild or okCustom) then
        return nil
    end

    local scoreHp = okCustom and (curHp/2) or curHp
    local dist    = distanceFromPlayer(spec:getPosition())
    return scoreHp, dist
end

-- =========================
-- Loop principal
-- =========================
macro(100, function()
    if not config.enabled then return end

    local minHp = config.settings[6].value   -- self-protect HP%
    local minMp = config.settings[7].value   -- self-protect MP%

    -- Gate menos agressivo: pausa só quando HP E MP estão baixos
    if hppercent() <= minHp and manapercent() <= minMp then
        return
    end

    local healTarget = {creature=nil, hp=100}
    for _, spec in ipairs(getSpectators(posz())) do
        local health, dist = isCandidate(spec)
        if health and dist then
            if health <= healTarget.hp then
                healTarget = {creature = spec, hp = health}
            end
        end
    end

    if healTarget.creature then
        return friendHealerAction(healTarget.creature)
    end
end)

-- ========================================================================
-- SCRIPT CHALLENGE MULTI-VOCAÇÃO - Versão 1.8 (LIMPO - SEM LOGS)
-- Versão final sem logs/debugs no console
-- ========================================================================

-- =========================[ VERIFICAÇÃO DE VOCAÇÃO ]====================
local voc = player:getVocation()

-- Verificar se é uma vocação suportada
if not (voc == 1 or voc == 11 or voc == 2 or voc == 12) then
    return
end

-- Configurações baseadas na vocação
local VOCATION_CONFIG = {}

if voc == 1 or voc == 11 then  -- Knight / Elite Knight
    VOCATION_CONFIG = {
        spell = "exeta amp res",
        spellName = "Chivalrous Challenge",
        macroName = "Exeta Amp Res",
        manaCost = 80,
        cooldown = 2200, -- 2.2 segundos
        minLevel = 150,
        vocationName = voc == 1 and "Knight" or "Elite Knight"
    }
    setDefaultTab("Cave")
elseif voc == 2 or voc == 12 then  -- Paladin / Royal Paladin
    VOCATION_CONFIG = {
        spell = "exana amp res",
        spellName = "Divine Challenge", 
        macroName = "Exana Amp Res",
        manaCost = 80,
        cooldown = 16200, -- 16.2 segundos
        minLevel = 150,
        vocationName = voc == 2 and "Paladin" or "Royal Paladin"
    }
    setDefaultTab("Cave")
end

UI.Separator()

-- =========================[ CONFIGURAÇÕES ]====================

-- Configurações (edite aqui para personalizar)
local CONFIG = {
    enabled = true,
    maxDistance = 7 -- Distância máxima para considerar criaturas
}

-- =========================[ LISTAS DE CRIATURAS ]=========================

-- Lista de criaturas que atacam à distância
local RANGED_CREATURES = {
    "acolyte of the cult", "gorerilla", "adept of the cult", "amazon", "angry sugar fairy",
    "animated snowman", "apprentice sheng", "barbarian brutetamer", "black vixen",
    "blemished spawn", "bonelord", "braindeath", "bulltaur forgepriest",
    "candy floss elemental", "capricious phantom", "carnivostrich", "cave chimera",
    "chakoya windcaller", "cobra scout", "converter", "cursed prospector",
    "dark apprentice", "dark magician", "darklight matter", "deadeye devious",
    "diabolic imp", "distorted phantom", "magma crawler", "manticore", 
    "meandering mushroom", "mega dragon", "memory of a carnisylvan", 
    "memory of a manticore", "mephiles", "mercurial menace", "merlkin", 
    "minotaur amazon", "minotaur archer", "minotaur hunter", "minotaur mage",
    "mitmah scout", "mould phantom", "naga archer", "necromancer", "necropharus", 
    "ogre sage", "ogre shaman", "orc marauder", "orc shaman", "orc spearman", 
    "pirat bombardier", "pirat scoundrel", "pixie", "poisonous carnisylvan", 
    "priestess", "the evil eye", "hydra", "serpent spawn", "wyvern", "hellhound", 
    "thalas", "deathbringer", "betrayed wraith", "frazzlemaw", "fury", 
    "grim reaper", "rift scythe", "water elemental", "massive water elemental", 
    "spirit of water", "dragon lord", "mahrdis", "morgarot", "gaz'haragoth", 
    "ferumbras", "apocalypse", "gnorre chyllson", "demon parrot", "diremaw",
    
    -- Criaturas adicionais para Paladins
    "ancient scarab", "larva", "scarab", "bonebeast", "elder bonelord",
    "gazer", "elder gazer", "beholder", "elder beholder", "stalker",
    "hero", "warlock", "demon", "destroyer", "hellfire fighter",
    "plaguesmith", "hand of cursed fate", "juggernaut", "nightmare",
    "nightmare scion", "retching horror", "spawn of the welter", "undead dragon"
}

-- =========================[ VARIÁVEIS DE CONTROLE ]======================
local lastChallengeTime = 0

-- =========================[ FUNÇÕES AUXILIARES ]==========================

local function isRangedCreature(creatureName)
    if not creatureName then return false end
    
    local lowerName = creatureName:lower()
    for _, name in ipairs(RANGED_CREATURES) do
        if lowerName:find(name) then
            return true
        end
    end
    return false
end

local function canUseChallenge()
    -- Verificar level
    if player:getLevel() < VOCATION_CONFIG.minLevel then
        return false
    end
    
    -- Verificar mana
    if player:getMana() < VOCATION_CONFIG.manaCost then
        return false
    end
    
    -- Verificar cooldown
    if now - lastChallengeTime < VOCATION_CONFIG.cooldown then
        return false
    end
    
    return true
end

local function getRangedCreaturesOnScreen()
    local rangedCreatures = {}
    
    for _, creature in ipairs(getSpectators()) do
        if creature:isMonster() then
            local creatureName = creature:getName()
            local distance = getDistanceBetween(player:getPosition(), creature:getPosition())
            
            if distance <= CONFIG.maxDistance and isRangedCreature(creatureName) then
                local creatureInfo = {
                    creature = creature,
                    name = creatureName,
                    distance = distance
                }
                
                table.insert(rangedCreatures, creatureInfo)
            end
        end
    end
    
    return rangedCreatures
end

local function shouldUseChallenge(rangedCreatures)
    -- Se não há criaturas ranged, não usar
    if #rangedCreatures == 0 then
        return false
    end
    
    -- Contar criaturas ranged que estão a mais de 1 sqm
    local creaturesDistant = 0
    
    for _, creatureInfo in ipairs(rangedCreatures) do
        if creatureInfo.distance > 1 then
            creaturesDistant = creaturesDistant + 1
        end
    end
    
    -- REGRA PRINCIPAL: Usar se há 1 ou mais criaturas a mais de 1 sqm
    if creaturesDistant >= 1 then
        return true
    else
        return false
    end
end

-- =========================[ FUNÇÃO PRINCIPAL ]============================

local function executeChallenge()
    if not CONFIG.enabled then return end
    
    local canUse = canUseChallenge()
    if not canUse then
        return
    end
    
    local rangedCreatures = getRangedCreaturesOnScreen()
    
    local shouldUse = shouldUseChallenge(rangedCreatures)
    if not shouldUse then
        return
    end
    
    -- Usar a magia
    say(VOCATION_CONFIG.spell)
    lastChallengeTime = now
end

-- =========================[ MACROS ]====================================

-- Macro principal com nome baseado na vocação
challengeMacro = macro(200, VOCATION_CONFIG.macroName, function()
    executeChallenge()
end)


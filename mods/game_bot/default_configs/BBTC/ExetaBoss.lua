addSeparator()
setDefaultTab("Suport")

local config = {
  exeta = "exeta res",
  minMonsters = 1,  -- precisa pelo menos 1 mob
  monsterDist = 1,  -- distancia entre member e mob para acionar
  tryDelay = 3000   -- anti-spam entre tentativas (ms)
}

-- ===== Estado =====
local s = { }
local returning = false
local anchorPosition = storage.exetaBossAnchor or nil  -- âncora persistente
local lastEnabled = false           -- detecção de "ligou agora"
local lastTry = 0                   -- antispam geral

-- ===== Funções =====
s.getPositions = function()
  local members, mobs = {}, {}
  for _, spec in ipairs(getSpectators(posz())) do
    if spec:isPlayer() and spec:isPartyMember() and spec ~= player then
      table.insert(members, spec)
    end
    if spec:isMonster() then
      table.insert(mobs, spec)
    end
  end
  return members, mobs
end

local function fmtPos(p)
  return p and string.format("(%d,%d,%d)", p.x, p.y, p.z) or "-"
end

local function setAnchor(p)
  anchorPosition = {x = p.x, y = p.y, z = p.z}
  storage.exetaBossAnchor = anchorPosition
  anchorLabel:setText("Anchor: " .. fmtPos(anchorPosition))
end

-- ===== UI =====
UI.Separator()
UI.Label("Exeta Boss")

local labelStatus   = UI.Label("Status:")
local monstersLabel = UI.Label("Monsters: 0")
local playersLabel  = UI.Label("Players: 0")
local distanceLabel = UI.Label("Distance: 0")
anchorLabel         = UI.Label("Anchor: " .. fmtPos(anchorPosition))

UI.Button("Set Anchor (save here)", function()
  local p = pos()
  setAnchor(p)
  labelStatus:setText("Status: Anchor definida em " .. fmtPos(p))
end)

UI.Button("Clear Anchor", function()
  anchorPosition = nil
  storage.exetaBossAnchor = nil
  anchorLabel:setText("Anchor: -")
  labelStatus:setText("Status: Anchor limpa")
end)

UI.Separator()

-- Guardamos referência ao macro para detectar "ligar agora"
local exetaMacro
exetaMacro = macro(100, "Exeta PT", function()
  local nowt = now

  -- Detecta "ligou agora": define Anchor automaticamente se não existir
  if exetaMacro and exetaMacro.isOn and exetaMacro.isOn() and not lastEnabled then
    lastEnabled = true
    if not anchorPosition then
      setAnchor(pos())
      labelStatus:setText("Status: Anchor auto-set em " .. fmtPos(anchorPosition))
    end
  elseif exetaMacro and exetaMacro.isOff and exetaMacro.isOff() then
    lastEnabled = false
  end

  -- Anti-spam geral
  if nowt - lastTry < config.tryDelay then return end

  local members, mobs = s.getPositions()
  playersLabel:setText(string.format("Players: %d", #members))
  monstersLabel:setText(string.format("Monsters: %d", #mobs))

  if #members == 0 then
    labelStatus:setText("Status: Procurando party...")
    return
  end

  if #mobs < config.minMonsters then
    labelStatus:setText("Status: Aguardando monstros...")
    return
  end

  -- Se não tem Anchor (após Clear), define ao primeiro ciclo útil
  if not anchorPosition then
    setAnchor(pos())
    labelStatus:setText("Status: Anchor auto-set em " .. fmtPos(anchorPosition))
  end

  local myPos   = pos()
  local bestDist = 99
  local walkTo   = nil  -- para onde vamos "buscar" o boss

  -- Procura um par (member, mob) tal que a distância entre eles <= monsterDist
  -- Nesse caso: vamos até o mob e usamos exeta, depois retornamos para Anchor.
  for _, m in ipairs(members) do
    local mp = m:getPosition()
    if mp and mp.z == myPos.z then
      for _, mob in ipairs(mobs) do
        local mobPos = mob:getPosition()
        if mobPos and mobPos.z == myPos.z then
          local dist = getDistanceBetween(mp, mobPos)
          if dist <= config.monsterDist then
            walkTo = mobPos
            break
          end
          if dist < bestDist then
            bestDist = dist
          end
        end
      end
      if walkTo then break end
    end
  end

  distanceLabel:setText(string.format("Distance: %d", bestDist ~= 99 and bestDist or 0))

  -- 1) Ir até o mob colado no member, usar exeta, e marcar "retornando"
  if walkTo and not returning then
    autoWalk(walkTo, 20, { precision = 2, ignoreNonPathable = true, ignoreCreatures = true })
    if getDistanceBetween(walkTo, pos()) <= 1 then
      walkTo = nil
      say(config.exeta)
      lastTry = nowt
      labelStatus:setText("Status: Exeta usado")

      -- 2) Voltar para a âncora
      if anchorPosition and anchorPosition.z == posz() then
        returning = true
        autoWalk(anchorPosition, 20, { precision = 2, ignoreNonPathable = true, ignoreCreatures = true })
      else
        -- âncora fora do andar atual: apenas para status
        labelStatus:setText("Status: Anchor em outro andar")
      end
    else
      labelStatus:setText("Status: Indo ao alvo")
    end

  -- 3) Enquanto retorna, insiste até encostar na Anchor (sem apagar Anchor)
  elseif returning then
    if anchorPosition then
      if getDistanceBetween(anchorPosition, pos()) <= 1 then
        returning = false
        labelStatus:setText("Status: Posição restaurada " .. fmtPos(anchorPosition))
      else
        labelStatus:setText("Status: Retornando...")
        autoWalk(anchorPosition, 20, { precision = 2, ignoreNonPathable = true, ignoreCreatures = true })
      end
    else
      returning = false
      labelStatus:setText("Status: Anchor ausente")
    end

  else
    labelStatus:setText("Status: Idle (aguardando troca de alvo)")
    -- Se quiser “grudar” na anchor sempre que estiver livre:
    -- if anchorPosition and getDistanceBetween(anchorPosition, pos()) > 1 then
    --   autoWalk(anchorPosition, 20, { precision = 2, ignoreNonPathable = true, ignoreCreatures = true })
    -- end
  end
end)

UI.Separator()

-- Paleta de cores mantida (somente decorativo)
local colors = {
  "#000000","#0000FF","#8A2BE2","#A52A2A","#5F9EA0","#7FFF00","#D2691E","#FF7F50","#6495ED","#FFF8DC",
  "#DC143C","#00FFFF","#00008B","#008B8B","#B8860B","#A9A9A9","#006400","#BDB76B","#8B008B","#556B2F",
  "#FF8C00","#9932CC","#8B0000","#E9967A","#8FBC8F","#483D8B","#2F4F4F","#00CED1","#9400D3","#FF1493",
  "#00BFFF","#696969","#1E90FF","#B22222","#FFFAF0","#228B22","#FF00FF","#DCDCDC","#F8F8FF","#FFD700",
  "#DAA520","#808080","#008000","#ADFF2F","#F0FFF0","#FF69B4","#CD5C5C","#4B0082","#FFFFF0","#F0E68C",
  "#E6E6FA","#FFF0F5","#7CFC00","#FFFACD","#ADD8E6","#F08080","#E0FFFF","#FAFAD2","#D3D3D3","#90EE90",
  "#FFB6C1","#FFA07A","#20B2AA","#87CEFA","#778899","#B0C4DE","#FFFFE0","#00FF00","#32CD32","#FAF0E6",
  "#FF00FF","#800000","#66CDAA","#0000CD","#BA55D3","#9370DB","#3CB371","#7B68EE","#00FA9A","#48D1CC",
  "#C71585","#191970","#F5FFFA","#FFE4E1","#FFE4B5","#FFDEAD","#000080","#FDF5E6","#808000","#6B8E23",
  "#FFA500","#FF4500","#DA70D6","#EEE8AA","#98FB98","#AFEEEE","#DB7093","#FFEFD5","#FFDAB9","#CD853F",
  "#FFC0CB","#DDA0DD","#B0E0E6","#800080","#663399","#FF0000","#BC8F8F","#4169E1","#8B4513","#FA8072",
  "#F4A460","#2E8B57","#A0522D","#87CEEB","#6A5ACD","#708090","#FFFAFA","#4682B4","#D2B48C","#D8BFD8",
  "#FF6347","#40E0D0","#EE82EE","#F5DEB3","#9ACD32",
}

-- (Bloco de teste que você usava para creature 'GOD' removido por segurança; mantenha se precisar)

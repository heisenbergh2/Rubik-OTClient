-- SwapSet_Otimizado_Final.lua – versão completa corrigida e otimizada
-- Objetivos:
-- 1) Equipar o SET COMPLETO (fila de pendências; sem return prematuro)
-- 2) Reduzir "slow macro" (macro leve + offload via schedule)
-- 3) Listas de mobs robustas (trim/lower; hash sets)
-- 4) Cache de equipamento atualizado após cada equip
-- 5) Sem prints no console (DEBUG opcional)

-------------------------------------------------
-- Settings / Estado
-------------------------------------------------
addSeparator()
setDefaultTab("Suport")
addSeparator()

if not storage.SwapElemental then storage.SwapElemental = {} end
local settings = storage.SwapElemental
if settings.enabled == nil then settings.enabled = true end

local DEBUG = false
local function dlog(...) if DEBUG then print("[SwapSet]", ...) end end

-------------------------------------------------
-- UI (idêntica à sua, preservada)
-------------------------------------------------
g_ui.loadUIFromString([[
BaseNameScrollBar < Panel
  height: 28
  margin-top: 3

  UIWidget
    id: text
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    text-align: center
    
  HorizontalScrollBar
    id: scroll
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: prev.bottom
    margin-top: 3
    minimum: 0
    maximum: 10
    step: 1

SwapSetWindow < MainWindow
  !text: tr('SwapSet')
  size: 440 360
  padding: 25

  Label
    anchors.left: parent.left
    anchors.right: parent.horizontalCenter
    anchors.top: parent.top
    text-align: center

  Label
    anchors.left: parent.horizontalCenter
    anchors.right: parent.right
    anchors.top: parent.top
    text-align: center

  VerticalScrollBar
    id: contentScroll
    anchors.top: prev.bottom
    margin-top: 3
    anchors.right: parent.right
    anchors.bottom: separator.top
    step: 28
    pixels-scroll: true
    margin-right: -10
    margin-top: 5
    margin-bottom: 5

  ScrollablePanel
    id: content
    anchors.top: prev.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: separator.top
    vertical-scrollbar: contentScroll
    margin-bottom: 10
      
    Panel
      id: left
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.horizontalCenter
      margin-top: 5
      margin-left: 10
      margin-right: 10
      layout:
        type: verticalBox
        fit-children: true

    Panel
      id: right
      anchors.top: parent.top
      anchors.left: parent.horizontalCenter
      anchors.right: parent.right
      margin-top: 5
      margin-left: 10
      margin-right: 10
      layout:
        type: verticalBox
        fit-children: true

    VerticalSeparator
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.left: parent.horizontalCenter

  HorizontalSeparator
    id: separator
    anchors.right: parent.right
    anchors.left: parent.left
    anchors.bottom: closeButton.top
    margin-bottom: 8

  ResizeBorder
    id: bottomResizeBorder
    anchors.fill: separator
    height: 3
    minimum: 260
    maximum: 600
    margin-left: 3
    margin-right: 3
    background: #ffffff88    

  Button
    id: closeButton
    !text: tr('Close')
    font: cipsoftFont
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    size: 45 21
    margin-right: 5

  Label
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    

SlotBotItem < BotItem
  border-width: 0
  $on:
    image-source: /images/ui/item
  $checked:
    border-width: 1
    border-color: #FF0000

EQPanel < FlatPanel
  size: 100 220
  padding-left: 10
  padding-right: 10
  padding-bottom: 10

  Label
    id: title
    anchors.verticalCenter: parent.top
    anchors.left: parent.left    
    font: verdana-11px-rounded
    color: #03C04A

  SlotBotItem
    id: head
    image-source: /images/game/slots/head
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: prev.bottom
    margin-top: 15
    $on:
      image-source: /images/ui/item

  SlotBotItem
    id: body
    image-source: /images/game/slots/body
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: prev.bottom
    margin-top: 5
    $on:
      image-source: /images/ui/item

  SlotBotItem
    id: legs
    image-source: /images/game/slots/legs
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: prev.bottom
    margin-top: 5
    $on:
      image-source: /images/ui/item

  SlotBotItem
    id: feet
    image-source: /images/game/slots/feet
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: prev.bottom
    margin-top: 5
    $on:
      image-source: /images/ui/item

  SlotBotItem
    id: neck
    image-source: /images/game/slots/neck
    anchors.top: head.top
    margin-top: 13
    anchors.right: head.left
    margin-right: 5
    $on:
      image-source: /images/ui/item

  SlotBotItem
    id: left-hand
    image-source: /images/game/slots/left-hand
    anchors.horizontalCenter: prev.horizontalCenter
    anchors.top: prev.bottom
    margin-top: 5
    $on:
      image-source: /images/ui/item

  SlotBotItem
    id: finger
    image-source: /images/game/slots/finger
    anchors.horizontalCenter: prev.horizontalCenter
    anchors.top: prev.bottom
    margin-top: 5
    $on:
      image-source: /images/ui/item

  Item
    id: back
    image-source: /images/game/slots/back-blessed
    anchors.top: head.top
    margin-top: 13
    anchors.left: head.right
    margin-left: 5
    tooltip: Main back container modifications are unavailable.

  SlotBotItem
    id: right-hand
    image-source: /images/game/slots/right-hand
    anchors.horizontalCenter: prev.horizontalCenter
    anchors.top: prev.bottom
    margin-top: 5
    $on:
      image-source: /images/ui/item

  SlotBotItem
    id: ammo
    image-source: /images/game/slots/ammo
    anchors.horizontalCenter: prev.horizontalCenter
    anchors.top: prev.bottom
    margin-top: 5  
    
  Button 
    id:list
    text: mobs
    size: 60 20
    margin-left: 10
    anchors.left: head.right
    anchors.verticalCenter: head.verticalCenter
    

  BotButton
    id: cloneEq
    anchors.top: feet.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 15
    text: Clone Current EQ
    font: verdana-11px-rounded
    tooltip: Copy currently equipped and non-equipped items.

]])

-- basic elements
local SwapSetWindow = UI.createWindow('SwapSetWindow', rootWidget)
SwapSetWindow:hide()
SwapSetWindow.closeButton.onClick = function() SwapSetWindow:hide() end
SwapSetWindow:setHeight(560)
SwapSetWindow:setWidth(500)
SwapSetWindow:setText("Swap Elemental")

local ui = setupUI([[
Panel
  height: 19

  BotSwitch
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    text-align: center
    width: 130
    !text: tr('Swap Elemental')

  Button
    id: push
    anchors.top: prev.top
    anchors.left: prev.right
    anchors.right: parent.right
    margin-left: 3
    height: 17
    text: Setup

]])
ui.title:setOn(settings.enabled)
ui.title.onClick = function(widget)
  settings.enabled = not settings.enabled
  widget:setOn(settings.enabled)
end
ui.push.onClick = function()
  SwapSetWindow:show()
  SwapSetWindow:raise()
  SwapSetWindow:focus()
end

-- panels
local rightPanel = SwapSetWindow.content.right
local leftPanel  = SwapSetWindow.content.left

-------------------------------------------------
-- Utils
-------------------------------------------------
local function trim(s) return (s and s:match("^%s*(.-)%s*$") or "") end
local function normName(s) s = trim(s or "") return s:lower() end

local function splitLinesToSet(text)
  local set = {}
  if not text or text == "" then return set end
  for line in text:gmatch("[^\r\n]+") do
    local k = normName(line)
    if #k > 0 then set[k] = true end
  end
  return set
end

-------------------------------------------------
-- Equip helpers / cache
-------------------------------------------------
local equipmentCache, lastCacheUpdate = {}, 0
local function safeGetActiveItemId(id)   if type(getActiveItemId)   == "function" then return getActiveItemId(id)   end end
local function safeGetInactiveItemId(id) if type(getInactiveItemId) == "function" then return getInactiveItemId(id) end end

local function refreshEquipmentCache()
  equipmentCache = {}
  local slots = {getNeck(), getHead(), getBody(), getRight(), getLeft(), getLeg(), getFeet(), getFinger(), getAmmo()}
  for _, slot in pairs(slots) do
    if slot then
      local sid = slot:getId()
      equipmentCache[sid] = true
      local a = safeGetActiveItemId(sid);   if a and a ~= sid then equipmentCache[a] = true end
      local i = safeGetInactiveItemId(sid); if i and i ~= sid then equipmentCache[i] = true end
    end
  end
  lastCacheUpdate = now
end

local function isEquipped(id)
  if not id or id <= 0 then return false end
  if (now - lastCacheUpdate) > 1200 then refreshEquipmentCache() end
  return equipmentCache[id] == true
end

local function markEquippedInCache(id)
  if not id or id <= 0 then return end
  equipmentCache[id] = true
  local a = safeGetActiveItemId(id);   if a and a ~= id then equipmentCache[a] = true end
  local i = safeGetInactiveItemId(id); if i and i ~= id then equipmentCache[i] = true end
end

-- compat slots (mantido do seu script)
local function equipItem(id, slot)
  local slotMap = {[2]=4, [3]=7, [8]=9, [5]=2, [4]=8, [9]=10, [7]=5}
  slot = slotMap[slot] or slot
  if g_game.getClientVersion() >= 910 then
    local item = Item.create(id)
    return g_game.equipItem(item)
  else
    local item = g_game.findPlayerItem(id, -1)
    return item and moveToSlot(item, slot)
  end
end

-------------------------------------------------
-- UI dos sets (idêntica; apenas sanidade)
-------------------------------------------------
local parts = {"head","body","legs","feet","neck","left-hand","right-hand","finger","ammo"}

local function loadIds(widget)
  local ids = settings[widget:getId()]
  if not ids then return end
  for key, val in pairs(ids) do
    if widget[key] then
      widget[key]:setItemId(val or 0)
      widget[key]:setOn((val or 0) > 100)
    end
  end
end

local function addEq(id, title, parent, color, withList)
  local w = UI.createWidget("EQPanel", parent)
  w.title:setText(title)
  w:setId(id)
  w.title:setColor(color)

  if withList then
    local listId = id .. "List"
    if not settings[listId] then settings[listId] = "" end
    w.list.onClick = function()
      UI.MultilineEditorWindow(
        settings[listId],
        { title = title .. ' Mobs', description = 'name\nname\nname\n' },
        function(text) settings[listId] = text end
      )
    end
  else
    w.list:hide()
  end

  if not settings[id] then settings[id] = {} end

  for _, part in ipairs(parts) do
    w[part].onItemChange = function(item)
      local selfId = item and item:getItemId() or 0
      settings[id][part] = selfId
      w[part]:setOn(selfId > 100)
    end
  end

  loadIds(w)
  w.back:hide()

  w.cloneEq.onClick = function()
    w.head:setItemId(getHead() and getHead():getId() or 0)
    w.body:setItemId(getBody() and getBody():getId() or 0)
    w.legs:setItemId(getLeg() and getLeg():getId() or 0)
    w.feet:setItemId(getFeet() and getFeet():getId() or 0)
    w.neck:setItemId(getNeck() and getNeck():getId() or 0)
    w["left-hand"]:setItemId(getLeft() and getLeft():getId() or 0)
    w["right-hand"]:setItemId(getRight() and getRight():getId() or 0)
    w.finger:setItemId(getFinger() and getFinger():getId() or 0)
    w.ammo:setItemId(getAmmo() and getAmmo():getId() or 0)
  end

  return w
end

addEq("PVP",   "PVP",    leftPanel,  "white",   false)
addEq("Fire",  "Fire",   rightPanel, "red",     true)
addEq("Energy","Energy", leftPanel,  "#5DF2BD", true)
addEq("Poison","Poison", rightPanel, "green",   true)

-------------------------------------------------
-- Listas de mobs (hash set + cache)
-------------------------------------------------
local mobSets = { fire={}, energy={}, poison={} }
local lastListUpdate = 0
local function updateMobLists(force)
  if not force and (now - lastListUpdate) < 10000 then return end -- 10s
  lastListUpdate = now
  mobSets.fire   = splitLinesToSet(settings.FireList)
  mobSets.energy = splitLinesToSet(settings.EnergyList)
  mobSets.poison = splitLinesToSet(settings.PoisonList)
end

-------------------------------------------------
-- Verificação de set completo
-------------------------------------------------
local orderedSlots   = {2,3,4,5,6,7,8,9,10}
local orderedPartKey = {"head","body","legs","feet","neck","left-hand","right-hand","finger","ammo"}

local function isSetEquippedFull(setData)
  if not setData then return true end
  for i, part in ipairs(orderedPartKey) do
    local id = setData[part]
    if id and id > 0 and not isEquipped(id) then return false end
  end
  return true
end

-------------------------------------------------
-- Fila de equips (pendências) + offload
-------------------------------------------------
local currentSetName, currentSetData = "", nil
local pendingEquips = {}
local lastEquipTime = 0
local EQUIP_INTERVAL_MS = 600      -- espaçamento entre equips
local TARGET_STICK_MS   = 900      -- anti-spin no mesmo alvo
local lastTargetName, lastTargetTime = "", 0

local function rebuildPending(setData)
  pendingEquips = {}
  if not setData then return end
  for i, slot in ipairs(orderedSlots) do
    local part = orderedPartKey[i]
    local id   = setData[part]
    if id and id > 0 and not isEquipped(id) then
      table.insert(pendingEquips, {slot=slot, part=part, id=id})
    end
  end
end

local function determineSetForTarget(t)
  if not t then return "", nil end
  if t:isPlayer() then return "PVP", settings.PVP end
  local name = normName(t:getName() or "")
  if name == "" then return "", nil end
  updateMobLists(false)
  if mobSets.fire[name]   then return "Fire",   settings.Fire   end
  if mobSets.energy[name] then return "Energy", settings.Energy end
  if mobSets.poison[name] then return "Poison", settings.Poison end
  return "", nil
end

-------------------------------------------------
-- Macro principal (leve e completo)
-------------------------------------------------
macro(420, function()
  if not settings.enabled then return end

  local t = target()
  if not t then return end
  local tname = t:getName() or ""
  if tname == "" then return end

  if tname == lastTargetName and (now - lastTargetTime) < TARGET_STICK_MS then
    -- continua processando pendências se houver
  else
    lastTargetName = tname
    lastTargetTime = now

    local setName, setData = determineSetForTarget(t)
    if setName == "" or not setData then return end

    if setName ~= currentSetName then
      currentSetName = setName
      currentSetData = setData
      rebuildPending(currentSetData)
      dlog("novo set:", currentSetName, "pendências:", #pendingEquips)
    else
      if #pendingEquips == 0 and not isSetEquippedFull(currentSetData) then
        rebuildPending(currentSetData)
      end
    end
  end

  -- processa 1 item por vez, mas até concluir o set (fila)
  if #pendingEquips > 0 and (now - lastEquipTime) >= EQUIP_INTERVAL_MS then
    local job = table.remove(pendingEquips, 1)
    if job and job.id and job.id > 0 and not isEquipped(job.id) then
      lastEquipTime = now
      -- offload do equip fora do corpo do macro (reduz tempo do macro)
      schedule(1, function()
        if g_game.getClientVersion() >= 910 or g_game.findPlayerItem(job.id, -1) then
          equipItem(job.id, job.slot)
          schedule(30, function() markEquippedInCache(job.id) end)
        end
      end)
      dlog("equip", job.part, job.id, "restam:", #pendingEquips)
    end
    return
  end

  -- sem pendências mas incompleto: reconstruir
  if currentSetData and not isSetEquippedFull(currentSetData) then
    rebuildPending(currentSetData)
  end
end)

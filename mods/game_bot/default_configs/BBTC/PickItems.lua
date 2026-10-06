addSeparator()
setDefaultTab("Suport")
addSeparator()

if not storage.PickItems then
  storage.PickItems = {}
end

local settings = storage.PickItems

if settings.enabled == nil then
  settings.enabled = true
end

g_ui.loadUIFromString([[
BotContainer < Panel
  height: 68
  margin-bottom:10

  UIWidget
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    text-align: center
  
  ScrollablePanel
    id: items
    anchors.fill: parent
    padding-top:20
    vertical-scrollbar: scroll
    layout:
      type: grid
      cell-size: 34 34
      flow: true

  BotSmallScrollBar
    id: scroll
    anchors.top: prev.top
    anchors.bottom: prev.bottom
    anchors.right: parent.right
    step: 10
    pixels-scroll: true

PickItemsScrollBar < Panel
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

PickItemsTextEdit < Panel
  height: 40
  margin-top: 7

  UIWidget
    id: text
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    text-align: center
    
  TextEdit
    id: textEdit
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: prev.bottom
    margin-top: 5
    minimum: 0
    maximum: 10
    step: 1
    text-align: center

PickItemsItem < Panel
  height: 34
  margin-top: 7
  margin-left: 25
  margin-right: 25

  UIWidget
    id: text
    anchors.left: parent.left
    anchors.verticalCenter: next.verticalCenter

  BotItem
    id: item
    anchors.top: parent.top
    anchors.right: parent.right


PickItemsCheckBox < BotSwitch
  height: 20
  margin-top: 7

PickItemsWindow < MainWindow
  !text: tr('PickItems')
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
]])

-- basic elements
PickItemsWindow = UI.createWindow('PickItemsWindow', rootWidget)
PickItemsWindow:hide()
PickItemsWindow.closeButton.onClick = function(widget)
  PickItemsWindow:hide()
end

PickItemsWindow:setHeight(340)
PickItemsWindow:setWidth(450)
PickItemsWindow:setText("PickItems")

local ui = setupUI([[
Panel
  height: 19

  BotSwitch
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    text-align: center
    width: 130
    !text: tr('PickItems')

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

ui.push.onClick = function(widget)
  PickItemsWindow:show()
  PickItemsWindow:raise()
  PickItemsWindow:focus()
end

-- available options for dest param
local rightPanel = PickItemsWindow.content.right
local leftPanel = PickItemsWindow.content.left

-- objects made by Kondrah - taken from creature editor, minor changes to adapt
local addCheckBox = function(id, title, defaultValue, dest, tooltip)
  local widget = UI.createWidget('PickItemsCheckBox', dest)
  widget.onClick = function()
    widget:setOn(not widget:isOn())
    settings[id] = widget:isOn()
    
  end
  widget:setText(title)
  widget:setTooltip(tooltip)
  if settings[id] == nil then
    widget:setOn(defaultValue)
  else
    widget:setOn(settings[id])
  end
  settings[id] = widget:isOn()
end

local addItem = function(id, title, defaultItem, dest, tooltip)
  local widget = UI.createWidget('PickItemsItem', dest)
  widget.text:setText(title)
  widget.text:setTooltip(tooltip)
  widget.item:setTooltip(tooltip)
  widget.item:setItemId(settings[id] or defaultItem)
  widget.item.onItemChange = function(widget)
    settings[id] = widget:getItemId()
  end
  settings[id] = settings[id] or defaultItem
end

local addTextEdit = function(id, title, defaultValue, dest, tooltip)
  local widget = UI.createWidget('PickItemsTextEdit', dest)
  widget.text:setText(title)
  widget.textEdit:setText(settings[id] or defaultValue or "")
  widget.text:setTooltip(tooltip)
  widget.textEdit.onTextChange = function(widget,text)
    settings[id] = text
  end
  settings[id] = settings[id] or defaultValue or ""
end

local addScrollBar = function(id, title, min, max, defaultValue, dest, tooltip)
  local widget = UI.createWidget('PickItemsScrollBar', dest)
  widget.text:setTooltip(tooltip)
  widget.scroll.onValueChange = function(scroll, value)
    widget.text:setText(title .. ": " .. value)
    if value == 0 then
      value = 1
    end
    settings[id] = value
  end
  widget.scroll:setRange(min, max)
  widget.scroll:setTooltip(tooltip)
  if max-min > 1000 then
    widget.scroll:setStep(100)
  elseif max-min > 100 then
    widget.scroll:setStep(10)
  end
  widget.scroll:setValue(settings[id] or defaultValue)
  widget.scroll.onValueChange(widget.scroll, widget.scroll:getValue())
end

local addContainer = function(id, title, unique, parent, defaultValue)
  local widget = UI.createWidget("BotContainer", parent)
  widget:setId(id)
  widget.title:setText(title)
  local oldItems = {}
  if not settings[id] then
    settings[id] = defaultValue
  end
  local updateItems = function()
    local items = widget:getItems()
    -- callback part
    local somethingNew = (#items ~= #oldItems)
    for i, item in ipairs(items) do
      if type(oldItems[i]) ~= "table" then
        somethingNew = true
        break
      end
      if oldItems[i].id ~= item.id or oldItems[i].count ~= item.count then
        somethingNew = true
        break      
      end
    end
    
    if somethingNew then
      oldItems = items
      settings[id] = items
    end
    widget:setItems(items)    
  end
  
  widget.setItems = function(self, items)
    if type(self) == 'table' then
      items = self
    end
    local itemsToShow = math.max(10, #items + 2)
    if itemsToShow % 5 ~= 0 then
      itemsToShow = itemsToShow + 5 - itemsToShow % 5
    end
    widget.items:destroyChildren()
    for i = 1, itemsToShow do 
      local widget = g_ui.createWidget("BotItem", widget.items)
      if type(items[i]) == 'number' then
        items[i] = {id=items[i], count=1}
      end
      if type(items[i]) == 'table' then
        widget:setItem(Item.create(items[i].id, items[i].count))
      end
    end
    oldItems = items
    for i, child in ipairs(widget.items:getChildren()) do
      child.onItemChange = updateItems
    end
  end
  
  widget.getItems = function()
    local items = {}
    local duplicates = {}
    for i, child in ipairs(widget.items:getChildren()) do
      if child:getItemId() >= 100 then
        if not duplicates[child:getItemId()] or not unique then
          table.insert(items, {id=child:getItemId(), count=child:getItemCountOrSubType()})
          duplicates[child:getItemId()] = true
        end
      end
    end
    return items
  end
  
  widget:setItems(settings[id])
  
  return widget
end

function getContainerItemsIds(data)
  local idsTable = {}
  for _, item in ipairs(data) do
    table.insert(idsTable, item.id)
  end
  
  return idsTable
end

-- addLabel("","Label", rightPanel):setColor("white")
-- addLabel("","", rightPanel)
-- addTextEdit("exampletxt", "Title", "default", rightPanel, "")
-- addCheckBox("examplecheck", "title", false, rightPanel)
-- addScrollBar("example scroll", "title:", 0, 100, 50, rightPanel, "")
-- addItem("exampleItem", "Rune", 3192, leftPanel, "")


local c = addContainer("Items", "items", true, rightPanel, {3031})
c:setHeight(100)

macro(50, function(m)
  if not settings.enabled then return end
  local items = getContainerItemsIds(settings.Items)
  local tiles = getNearTiles(pos())
  table.insert(tiles, g_map.getTile(pos()))
  for _, t in ipairs(tiles) do
    local i = t:getTopThing()
    if i and table.find(items, i:getId()) then
      moveToSlot(i, SlotBack, i:getCount())
    end
  end
end)
local context = G.botContext

local iconsWithoutPosition = 0

context.addIcon = function(id, options, callback)
--[[
  Available options:
    item: {id=2160, count=100}  |  item: 2160
    outfit: outfit table ({})
    text: string
    x: float (0.0 - 1.0)
    y: float (0.0 - 1.0)
    hotkey: string
    switchable: true / false [default: true]
    movable: true / false [default: true]
    phantom: true / false [default: false]
]]--
  local panel = modules.game_interface.gameMapPanel
  if type(id) ~= "string" or id:len() < 1 then
    return context.error("Invalid id for addIcon")
  end

  -- ícone não-switchable exige callback função (comportamento original mantido)
  if options and options.switchable == false and type(callback) ~= 'function' then
    return context.error("Invalid callback for addIcon (non-switchable requires function)")
  end

  options = options or {}
  if type(context.storage._icons) ~= "table" then
    context.storage._icons = {}
  end
  if type(context.storage._icons[id]) ~= "table" then
    context.storage._icons[id] = {}
  end
  local config = context.storage._icons[id]

  local widget = g_ui.createWidget("BotIcon", panel)
  widget.botWidget = true
  widget.botIcon = true

  -- posição inicial
  if type(config.x) ~= 'number' or type(config.y) ~= 'number' then
    if type(options.x) == 'number' and type(options.y) == 'number' then
      config.x = math.min(1.0, math.max(0.0, options.x))
      config.y = math.min(1.0, math.max(0.0, options.y))
    else
      config.x = 0.01 + math.floor(iconsWithoutPosition / 5) / 10
      config.y = 0.05 + (iconsWithoutPosition % 5) / 5
      iconsWithoutPosition = iconsWithoutPosition + 1
    end
  end

  -- item
  if options.item then
    if type(options.item) == 'number' then
      widget.item:setItemId(options.item)
    else
      widget.item:setItemId(options.item.id)
      widget.item:setItemCount(options.item.count or 1)
      widget.item:setShowCount(false)
    end
  end

  -- outfit
  if options.outfit then
    widget.creature:setOutfit(options.outfit)
  end

  -- estado inicial (switch)
  if options.switchable == false then
    widget.status:hide()
    widget.status:setOn(true)
  else
    if config.enabled ~= true then
      config.enabled = false
    end
    widget.status:setOn(config.enabled)
  end

  -- texto e cor
  if options.text then
    if options.switchable ~= false then
      widget.status:hide()
      if widget.status:isOn() then
        widget.text:setColor('green')
      else
        widget.text:setColor('red')
      end
    end
    widget.text:setText(options.text)
  end

  -- setter público
  widget.setOn = function(val)
    widget.status:setOn(val)
    if options.text and options.switchable ~= false then
      widget.text:setColor(widget.status:isOn() and 'green' or 'red')
    end
    config.enabled = widget.status:isOn()
  end

  -- clique
  widget.onClick = function(widget)
    if options.switchable ~= false then
      widget.setOn(not widget.status:isOn())
      -- callback "tabela" (macro/objeto) com setOn
      if type(callback) == 'table' and type(callback.setOn) == 'function' then
        callback.setOn(config.enabled)
        return
      end
    end
    -- callback função
    if type(callback) == 'function' then
      callback(widget, widget.status:isOn())
    end
  end

  -- hotkey para toggle/click
  if options.hotkey then
    widget.hotkey:setText(options.hotkey)
    context.hotkey(options.hotkey, "", function()
      widget:onClick()
    end, nil, options.switchable ~= false)
  else
    widget.hotkey:hide()
  end

  -- mover com CTRL
  if options.movable ~= false then
    widget.onDragEnter = function(widget, mousePos)
      if not g_keyboard.isCtrlPressed() then return false end
      widget:breakAnchors()
      widget.movingReference = { x = mousePos.x - widget:getX(), y = mousePos.y - widget:getY() }
      return true
    end

    widget.onDragMove = function(widget, mousePos, moved)
      local parentRect = widget:getParent():getRect()
      local x = math.min(math.max(parentRect.x, mousePos.x - widget.movingReference.x), parentRect.x + parentRect.width - widget:getWidth())
      local y = math.min(math.max(parentRect.y - widget:getParent():getMarginTop(), mousePos.y - widget.movingReference.y), parentRect.y + parentRect.height - widget:getHeight())
      widget:move(x, y)
      return true
    end

    widget.onDragLeave = function(widget, pos)
      local parent = widget:getParent()
      local parentRect = parent:getRect()
      local x = widget:getX() - parentRect.x
      local y = widget:getY() - parentRect.y
      local width = parentRect.width - widget:getWidth()
      local height = parentRect.height - widget:getHeight()

      config.x = math.min(1, math.max(0, x / width))
      config.y = math.min(1, math.max(0, y / height))

      widget:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
      widget:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
      widget:setMarginTop(math.max(height * (-0.5) - parent:getMarginTop(), height * (-0.5 + config.y)))
      widget:setMarginLeft(width * (-0.5 + config.x))
      return true
    end
  end

  widget.onGeometryChange = function(widget)
    if widget:isDragging() then return end
    local parent = widget:getParent()
    local parentRect = parent:getRect()
    local width = parentRect.width - widget:getWidth()
    local height = parentRect.height - widget:getHeight()
    widget:setMarginTop(math.max(height * (-0.5) - parent:getMarginTop(), height * (-0.5 + config.y)))
    widget:setMarginLeft(width * (-0.5 + config.x))
  end

  if options.phantom ~= true then
    widget.onMouseRelease = function() return true end
  end

  -- inicialização: sincroniza estado sem estourar callback nil
  if options.switchable ~= false then
    if type(callback) == 'table' and type(callback.setOn) == 'function' then
      callback.setOn(config.enabled)
      callback.icon = widget
    elseif type(callback) == 'function' then
      callback(widget, widget.status:isOn())
    end
  end

  return widget
end

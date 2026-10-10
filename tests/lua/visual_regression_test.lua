-- Execute production Lua with small UI doubles; no native build or server needed.
local function read(path)
  local file = assert(io.open(path, 'rb'))
  local text = file:read('*a')
  file:close()
  return text:gsub('\r\n', '\n')
end

local function section(path, first, following)
  local text = read(path)
  local start = assert(text:find(first, 1, true), first)
  local finish = assert(text:find(following, start + #first, true), following)
  return text:sub(start, finish - 1)
end

local function run(text, env)
  setmetatable(env, { __index = _G })
  local chunk = assert(loadstring(text))
  setfenv(chunk, env)
  return chunk()
end

-- Native named rows and legacy tuples both populate Boss Cooldowns.
local bossEnv = { g_things = { getRaceData = function() return {name = 'Boss'} end } }
run(read('modules/game_analysers/menus/BossCooldown.lua'), bossEnv)
local boss = bossEnv.BossCooldown
boss.rebuild = function() end
boss:setupCooldown({{bossRaceId = 123, cooldownTime = 3600}})
assert(#boss.entries == 1 and boss.entries[1].bossId == 123)
assert(boss.entries[1].untilTs > os.time())
boss:setupCooldown({{456, 60}, {}, false})
assert(#boss.entries == 1 and boss.entries[1].bossId == 456)
boss:setupCooldown(nil)
assert(#boss.entries == 0)

-- Repeated MarketEnter must preserve scrollbar, filters, focus and offset.
local marketSource = section('mods/game_tibia_market/t_market.lua',
  'function onMarketEnter(', '-- The engine emits onMarketBrowse')
local scroll = { maximum = 92, value = 37, onValueChange = function() end }
local callback = scroll.onValueChange
local refreshed, gold = 0, 0
local marketEnv = {
  marketWindow = { isVisible = function() return true end },
  lastSelectedItem = {itemId = 123},
  table = setmetatable({empty = function(t) return next(t) == nil end}, {__index = table}),
  configureList = function() error('visible updates must not rebuild categories') end,
  refreshSelectedItemDepotDisplay = function() refreshed = refreshed + 1 end,
  requestMarketGoldRefresh = function() gold = gold + 1 end
}
run(marketSource, marketEnv)
local items = {{123, 4}}
marketEnv.onMarketEnter(0, items)
assert(marketEnv.depotLockerItems == items and refreshed == 1 and gold == 1)
assert(scroll.maximum == 92 and scroll.value == 37 and scroll.onValueChange == callback)

-- First entry still resets the virtual list and opens the window normally.
local shown, configured = 0, 0
local categories = { destroyChildren = function() end }
local filter = { clearOptions = function() end }
marketEnv.marketWindow = {
  isVisible = function() return false end,
  recursiveGetChildById = function() return scroll end,
  focus = function() end,
  contentPanel = {category = categories, classFilter = filter, tierFilter = filter}
}
scroll.setValue = function(self, v) self.value = v end
scroll.setMinimum = function(self, v) self.minimum = v end
scroll.setMaximum = function(self, v) self.maximum = v end
categories.getChildById = function() return nil end
marketEnv.configureList = function() configured = configured + 1 end
marketEnv.categoryList = {}
marketEnv.updateCategoryRowColors = function() end
marketEnv.show = function() shown = shown + 1 end
marketEnv.onMarketEnter(0, items)
assert(shown == 1 and configured == 1 and scroll.maximum == 0 and scroll.onValueChange == nil)

-- New sparse containers have three rows, capped by capacity; maximize still works.
local containerSource = section('modules/game_containers/containers.lua',
  'local function computeExpectedNumLines(', 'local function applyContainerHeight(')
local containerEnv = {modules = {client_options = {getOption = function() return false end}}}
local apply = run(containerSource .. '\nreturn applyDefaultContentHeightForWindow', containerEnv)
local height
local window = {setContentHeight = function(_, v) height = v end}
local layout = {getNumColumns = function() return 4 end, getNumLines = function() return 5 end}
local container = {getCapacity = function() return 20 end, getItemsCount = function() return 1 end}
apply(window, layout, {height = 36}, container)
assert(height == 108)
container.getCapacity = function() return 4 end
apply(window, layout, {height = 36}, container)
assert(height == 36)
container.getCapacity = function() return 20 end
containerEnv.modules.client_options.getOption = function() return true end
apply(window, layout, {height = 36}, container)
assert(height == 180)
layout.getNumColumns = function() return 0 end
containerEnv.modules.client_options.getOption = function() return false end
apply(window, layout, {height = 36}, container)
assert(height >= 36)

-- Character uses local outfit only while a valid inspection outfit is absent.
local characterSource = section('modules/game_cyclopedia/tab/character/character.lua',
  'function Cyclopedia.applyCharacterOutfitWidgets()', 'local function formatPercentFraction(')
local drawn
local portrait = {setOutfit = function(_, v) drawn = v end}
local localOutfit = {type = 128}
local characterEnv = {
  Cyclopedia = {Character = {}},
  g_game = {getLocalPlayer = function() return {getOutfit = function() return localOutfit end} end},
  UI = {isDestroyed = function() return false end, CharacterBase = {Outfit = portrait}}
}
run(characterSource, characterEnv)
characterEnv.Cyclopedia.applyCharacterOutfitWidgets()
assert(drawn == localOutfit)
local inspected = {type = 129}
characterEnv.Cyclopedia.Character.InspectionOutfit = inspected
characterEnv.Cyclopedia.applyCharacterOutfitWidgets()
assert(drawn == inspected)
characterEnv.Cyclopedia.Character.InspectionOutfit = nil
characterEnv.g_game.getLocalPlayer = function() return nil end
characterEnv.Cyclopedia.applyCharacterOutfitWidgets()

-- Tabs wrap at normal font size and reflow when the sidebar changes width.
local available = 160
local tabs = {tabs = {}, buttonsPanel = {getWidth = function() return available end},
  isDestroyed = function() return false end, setOn = function() end,
  setHeight = function(self, v) self.height = v end}
tabs.getTab = function(self, name)
  for _, tab in ipairs(self.tabs) do if tab.name == name then return tab end end
end
tabs.addTab = function(self, name)
  local tab = {name = name, tabPanel = {content = {}},
    getTextSize = function() return {width = #name * 7} end,
    getPaddingLeft = function() return 4 end, getPaddingRight = function() return 5 end,
    setWidth = function(self, v) self.width = v end,
    setMarginLeft = function(self, v) self.x = v end,
    setMarginTop = function(self, v) self.y = v end}
  self.tabs[#self.tabs + 1] = tab
  return tab
end
local botEnv = {G = {botContext = {tabs = tabs}}, g_ui = {createWidget = function() return {} end}}
run(read('mods/game_bot/functions/ui_legacy.lua'), botEnv)
for _, name in ipairs({'Main', 'Cave', 'Suport', 'Tools', 'Target', 'HP'}) do
  botEnv.G.botContext.addTab(name)
end
local function checkTabs()
  for _, tab in ipairs(tabs.tabs) do
    assert(tab.x >= 0 and tab.x + tab.width <= available)
    assert(tab.y + 21 <= tabs.height)
  end
end
checkTabs()
assert(tabs.height > 21 and tabs:getTab('HP'))
available = 100
tabs.buttonsPanel.onGeometryChange()
checkTabs()
available = 600
tabs.onGeometryChange(tabs)
checkTabs()
assert(tabs.height == 21)
botEnv.G.botContext.addTab('HP')
assert(#tabs.tabs == 6)

local graphics = read('modules/client_options/styles/graphics/graphics.otui')
assert(not graphics:find('hdGraphics', 1, true))
local options = run(read('modules/client_options/data_options.lua'), {})
assert(options.hdGraphics == nil)
print('Visual regression checks passed: bosses, market, containers, outfit, bot tabs and options')

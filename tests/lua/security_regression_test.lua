local function loadIn(path, env)
  local file = assert(io.open(path, 'rb'))
  local source = file:read('*a'):gsub('^\239\187\191', '')
  file:close()
  local chunk = assert(loadstring(source, '@' .. path))
  setfenv(chunk, env)
  return chunk()
end

-- Exercise the actual script loader: HTTP must not reach the network, HTTPS
-- executes in the bot context, and an empty reply must report a useful error.
local context = { storage = {}, error = function(message) error(message) end }
local reply, networkCalls = 'loaded = true', 0
local loaderEnv = setmetatable({
  G = { botContext = context },
  HTTP = { get = function(_, callback) networkCalls = networkCalls + 1; callback(reply, nil) end }
}, { __index = _G })
setmetatable(context, { __index = _G })
loadIn('mods/game_bot/functions/script_loader.lua', loaderEnv)
assert(not pcall(context.loadRemoteScript, 'http://example.com/a.lua'))
assert(networkCalls == 0, 'HTTP remote code reached the network')
context.loadRemoteScript('https://example.com/a.lua')
assert(context.loaded == true, 'HTTPS remote code did not run in the bot context')
reply = ''
local ok, message = pcall(context.loadRemoteScript, 'https://example.com/empty.lua')
assert(not ok and tostring(message):find('empty response', 1, true), 'empty response was not handled')

-- Archive errors and unsafe config names must never delete an existing config.
local directories, writes, deletes = { ['/bot/Test'] = true }, {}, 0
local archiveFiles = {}
local botEnv = setmetatable({
  g_resources = {
    decompressArchive = function() return archiveFiles end,
    directoryExists = function(path) return directories[path] == true end,
    makeDir = function(path) directories[path] = true end,
    deleteFile = function(path) deletes = deletes + 1; directories[path] = nil end,
    writeFileContents = function(path, contents) writes[path] = contents; return true end
  }
}, { __index = _G })
loadIn('modules/corelib/table.lua', botEnv)
loadIn('modules/corelib/string.lua', botEnv)
loadIn('mods/game_bot/bot.lua', botEnv)
-- The real onError displays a client window; replace only that presentation.
botEnv.onError = function(message) error(message) end
assert(not pcall(botEnv.decompressConfig, '../escape', 'zip'))
assert(not pcall(botEnv.decompressConfig, 'Test', 'invalid'))
assert(deletes == 0, 'invalid config deleted existing data')
archiveFiles = { ['main.lua'] = 'code', ['nested/data.json'] = '{}' }
botEnv.decompressConfig('Test', 'valid')
assert(writes['/bot/Test/main.lua'] == 'code', 'config path is missing its separator')
assert(writes['/bot/Test/nested/data.json'] == '{}', 'nested config path is wrong')

-- Minimal UI adapter for the real Highscores request/response lifecycle.
local function widget()
  return { setEnabled = function() end, setColor = function() end,
    setText = function(self, text) self.text = text end,
    isChecked = function() return false end, setChecked = function() end }
end
local function combo()
  local box = widget()
  box.options = {}
  function box:clearOptions() self.options = {}; self.current = nil end
  function box:addOption(text, data)
    local option = { text = text, data = data }
    self.options[#self.options + 1] = option
    self.current = self.current or option
  end
  function box:isOption(text)
    for _, option in ipairs(self.options) do if option.text == text then return true end end
    return false
  end
  function box:getCurrentOption() return self.current end
  function box:setCurrentOption(text)
    for _, option in ipairs(self.options) do if option.text == text then self.current = option end end
  end
  function box:setCurrentOptionByData(data)
    for _, option in ipairs(self.options) do if option.data == data then self.current = option end end
  end
  return box
end
local filters = { gameworldbox = combo(), vocationbox = combo(), categorybox = combo(), submit = widget() }
for _, name in ipairs({ 'openPvpCheck', 'optionalPvpCheck', 'hardcorePvpCheck', 'retroOpenPvpCheck', 'retroHardcorePvpCheck' }) do
  filters[name] = widget()
end
local ui = { filters = filters, highscoreList = { destroyChildren = function() end },
  hide = function() end, page = widget(), lastUpdate = widget(), showOwnRank = widget(),
  first = widget(), prevButton = widget(), nextButton = widget(), last = widget() }
local requests, handler = 0, nil
local highscoreEnv = setmetatable({
  tr = function(text) return text end,
  g_ui = { createWidget = function() return { setBackgroundColor = function() end } end },
  g_game = { isOnline = function() return true end, getWorldName = function() return 'World A' end,
    requestHighscore = function() requests = requests + 1 end },
  Controller = { new = function()
    return { ui = ui, setUI = function() end,
      registerEvents = function(_, _, callbacks) handler = callbacks.onProcessHighscores end }
  end }
}, { __index = _G })
loadIn('modules/game_highscore/game_highscore.lua', highscoreEnv)
highscoreEnv.highscoreController:onInit()
assert(type(handler) == 'function')
ui.filters.submit.onClick()
ui.filters.submit.onClick()
assert(requests == 1, 'parallel Highscores requests were not blocked')
handler({}, '', 0, 0, {}, {}, 1, 1, {}, 0)
assert(ui.lastUpdate.text == 'No entries found')
ui.filters.submit.onClick()
assert(requests == 2, 'empty Highscores response did not release the request lock')
handler({ 'World A', 'World B' }, 'World A', 0, 0, {}, { {0, 'Experience Points'} }, 1, 1, {}, os.time())
assert(filters.gameworldbox:isOption('World B'), 'second world was lost')
ui.filters.submit.onClick()
assert(requests == 3, 'populated Highscores response did not release the request lock')
print('Security regression checks passed: remote scripts, config extraction, Highscores lifecycle')

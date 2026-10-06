TargetBot.Creature = {}
TargetBot.Creature.configsCache = {}
TargetBot.Creature.cached = 0
TargetBot.Creature.globalBlacklist = {}

TargetBot.Creature.resetConfigs = function()
  TargetBot.targetList:destroyChildren()
  TargetBot.Creature.resetConfigsCache()
  TargetBot.Creature.rebuildGlobalBlacklist()
end

TargetBot.Creature.resetConfigsCache = function()
  TargetBot.Creature.configsCache = {}
  TargetBot.Creature.cached = 0
end

TargetBot.Creature.rebuildGlobalBlacklist = function()
  TargetBot.Creature.globalBlacklist = {}
  
  for _, config in ipairs(TargetBot.targetList:getChildren()) do
    local configValue = config.value
    if configValue.blacklist then
      for _, blacklistItem in ipairs(configValue.blacklist) do
        table.insert(TargetBot.Creature.globalBlacklist, blacklistItem)
      end
    end
  end
end

TargetBot.Creature.isGloballyBlacklisted = function(creatureName)
  local name = creatureName:lower()
  
  for _, blacklistPattern in ipairs(TargetBot.Creature.globalBlacklist) do
    local regex = "^" .. blacklistPattern:gsub("%*", ".*"):gsub("%?", ".?") .. "$"
    if regexMatch(name, regex)[1] then
      return true
    end
  end
  
  return false
end

local function processConfigName(configName)
  local blacklist = {}
  local whitelist = {}
  local hasWildcard = false
  local isBlacklistOnly = true
  
  for part in string.gmatch(configName, "[^,]+") do
    local trimmed = part:trim()
    if trimmed:sub(1,1) == "-" then
      local blacklistItem = trimmed:sub(2):trim()
      if blacklistItem:len() > 0 then
        table.insert(blacklist, blacklistItem:lower())
      end
    else
      isBlacklistOnly = false
      if trimmed == "*" then
        hasWildcard = true
      else
        table.insert(whitelist, trimmed:lower())
      end
    end
  end
  
  return blacklist, whitelist, hasWildcard, isBlacklistOnly
end

local function createRegexFromList(nameList)
  if #nameList == 0 then return "" end
  
  local regex = ""
  for i, name in ipairs(nameList) do
    if regex:len() > 0 then
      regex = regex .. "|"
    end
    regex = regex .. "^" .. name:gsub("%*", ".*"):gsub("%?", ".?") .. "$"
  end
  return regex
end

TargetBot.Creature.addConfig = function(config, focus)
  if type(config) ~= 'table' or type(config.name) ~= 'string' then
    return error("Invalid targetbot creature config (missing name)")
  end
  TargetBot.Creature.resetConfigsCache()

  local blacklist, whitelist, hasWildcard, isBlacklistOnly = processConfigName(config.name)
  
  local blacklistRegex = createRegexFromList(blacklist)
  
  local whitelistRegex = ""
  if hasWildcard then
    whitelistRegex = ".*"
  else
    whitelistRegex = createRegexFromList(whitelist)
  end

  config.blacklist = blacklist
  config.whitelist = whitelist
  config.hasWildcard = hasWildcard
  config.blacklistRegex = blacklistRegex
  config.whitelistRegex = whitelistRegex
  config.isBlacklistOnly = isBlacklistOnly
  
  if not config.regex then
    config.regex = whitelistRegex
  end

  local widget = UI.createWidget("TargetBotEntry", TargetBot.targetList)
  widget:setText(config.name)
  widget.value = config

  widget.onDoubleClick = function(entry)
    schedule(20, function()
      TargetBot.Creature.edit(entry.value, function(newConfig)
        entry:setText(newConfig.name)
        entry.value = newConfig
        TargetBot.Creature.resetConfigsCache()
        TargetBot.Creature.rebuildGlobalBlacklist()
        TargetBot.save()
      end)
    end)
  end

  TargetBot.Creature.rebuildGlobalBlacklist()

  if focus then
    widget:focus()
    TargetBot.targetList:ensureChildVisible(widget)
  end
  return widget
end

TargetBot.Creature.getConfigs = function(creature)
  if not creature then return {} end
  local name = creature:getName():trim():lower()
  
  if TargetBot.Creature.isGloballyBlacklisted(name) then
    return {}
  end
  
  if TargetBot.Creature.configsCache[name] then
    return TargetBot.Creature.configsCache[name]
  end
  
  local configs = {}
  for _, config in ipairs(TargetBot.targetList:getChildren()) do
    local configValue = config.value
    
    if configValue.isBlacklistOnly then
      goto continue
    end
    
    if configValue.blacklistRegex and configValue.blacklistRegex:len() > 0 then
      if regexMatch(name, configValue.blacklistRegex)[1] then
        goto continue
      end
    end
    
    if configValue.hasWildcard then
      table.insert(configs, configValue)
    elseif configValue.whitelistRegex and configValue.whitelistRegex:len() > 0 then
      if regexMatch(name, configValue.whitelistRegex)[1] then
        table.insert(configs, configValue)
      end
    elseif configValue.regex then
      if regexMatch(name, configValue.regex)[1] then
        table.insert(configs, configValue)
      end
    end
    
    ::continue::
  end
  
  if TargetBot.Creature.cached > 1000 then
    TargetBot.Creature.resetConfigsCache()
  end
  TargetBot.Creature.configsCache[name] = configs
  TargetBot.Creature.cached = TargetBot.Creature.cached + 1
  return configs
end

TargetBot.Creature.calculateParams = function(creature, path)
  local configs = TargetBot.Creature.getConfigs(creature)
  local priority = 0
  local danger = 0
  local selectedConfig = nil
  for _, config in ipairs(configs) do
    local config_priority = TargetBot.Creature.calculatePriority(creature, config, path)
    if config_priority > priority then
      priority = config_priority
      danger = TargetBot.Creature.calculateDanger(creature, config, path)
      selectedConfig = config
    end
  end
  return {
    config = selectedConfig,
    creature = creature,
    danger = danger,
    priority = priority
  }
end

TargetBot.Creature.calculateDanger = function(creature, config, path)
  return config.danger
end
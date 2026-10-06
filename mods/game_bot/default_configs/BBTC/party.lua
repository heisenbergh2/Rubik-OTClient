setDefaultTab("Main")

local panelName = "autoParty"
local autopartyui = setupUI([[
Panel
  height: 38

  BotSwitch
    id: status
    anchors.top: parent.top
    anchors.left: parent.left
    text-align: center
    width: 130
    height: 18
    text: Auto Party

  Button
    id: editPlayerList
    anchors.top: prev.top
    anchors.left: prev.right
    anchors.right: parent.right
    margin-left: 3
    height: 17
    text: Setup

  Button
    id: ptLeave
    text: Leave Party
    anchors.left: parent.left
    anchors.top: prev.bottom
    width: 86
    height: 17
    margin-top: 3
    color: #ee0000

  Button
    id: ptShare
    text: Share XP
    anchors.left: prev.right
    anchors.top: prev.top
    margin-left: 5
    height: 17
    width: 86

  ]], parent)

g_ui.loadUIFromString([[
AutoPartyName < Label
  background-color: alpha
  text-offset: 2 0
  focusable: true
  height: 16

  $focus:
    background-color: #00000055

  Button
    id: remove
    text: x
    anchors.right: parent.right
    margin-right: 15
    width: 15
    height: 15

AutoPartyListWindow < MainWindow
  text: Auto Party
  size: 185 445
  @onEscape: self:hide()

  Label
    id: lblLeader
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.right: parent.right
    text-align: center
    text: Leader Name

  TextEdit
    id: txtLeader
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: prev.bottom
    margin-top: 5

  Label
    id: lblParty
    anchors.left: parent.left
    anchors.top: prev.bottom
    anchors.right: parent.right
    margin-top: 5
    text-align: center
    text: Party List

  TextList
    id: lstAutoParty
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 5
    margin-bottom: 5
    padding: 1
    height: 103
    vertical-scrollbar: AutoPartyListListScrollBar

  VerticalScrollBar
    id: AutoPartyListListScrollBar
    anchors.top: lstAutoParty.top
    anchors.bottom: lstAutoParty.bottom
    anchors.right: lstAutoParty.right
    step: 14
    pixels-scroll: true

  TextEdit
    id: playerName
    anchors.left: parent.left
    anchors.top: lstAutoParty.bottom
    margin-top: 5
    width: 120

  Button
    id: addPlayer
    text: +
    anchors.right: parent.right
    anchors.left: prev.right
    anchors.top: prev.top
    margin-left: 3

  HorizontalSeparator
    id: separator
    anchors.right: parent.right
    anchors.left: parent.left
    anchors.top: prev.bottom
    margin-top: 8

  CheckBox
    id: creatureMove
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: prev.bottom
    margin-top: 9
    text: Invite on move
    tooltip: This will activate the invite on player move.

  CheckBox
    id: passlK
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: prev.bottom
    margin-top: 10
    text: Pass leader keyword
    tooltip: This will make the LEADER pass the leadership to the player who claims it.

  TextEdit
    id: textpasslK
    anchors.left: parent.left
    anchors.top: prev.bottom
    margin-top: 5
    text: Invite on move
    width: 150

  CheckBox
    id: leaveK
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: prev.bottom
    margin-top: 10
    text: Leave keyword
    tooltip: This will make the LEADER leave the party.

  TextEdit
    id: textleaveK
    anchors.left: parent.left
    anchors.top: prev.bottom
    margin-top: 5
    width: 150

  CheckBox
    id: joinK
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: prev.bottom
    margin-top: 10
    text: Join keyword
    tooltip: This will make the player join the party.

  TextEdit
    id: textjoinK
    anchors.left: parent.left
    anchors.top: prev.bottom
    margin-top: 5
    width: 150

  HorizontalSeparator
    id: separator
    anchors.right: parent.right
    anchors.left: parent.left
    anchors.bottom: closeButton.top
    margin-bottom: 12

  Button
    id: closeButton
    text: Close
    font: cipsoftFont
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    size: 38 21

  Label
    id: lblTextMinLvl
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    margin-bottom: 5
    text-align: center
    text: Min level: 

  Label
    id: lblMinLvl
    anchors.verticalCenter: lblTextMinLvl.verticalCenter
    anchors.left: lblTextMinLvl.right
    margin-left: 5
    text-align: center

  Button
    id: resetButton
    text: R
    font: cipsoftFont
    anchors.right: closeButton.left
    margin-right: 6
    anchors.bottom: parent.bottom
    size: 21 21
    tooltip: Reset min level to share exp based on player level.

]])

if not storage[panelName] then
    storage[panelName] = {
        leaderName = 'Leader name',
        joinkey = 'Join key',
        leaderkey = 'Pass leader',
        leavekey = 'Leave key',
        autoPartyList = {},
        enabled = true,
        passleaderenabled = false,
        joinenabled = false,
        leaveenabled = false,
    }
end

if not storage[panelName].onMove then
    storage[panelName].onMove = false
end


local tableteste = {}
local levelTable = {}
storage.highlvl = player:getLevel()
lvlmember = math.ceil(player:getLevel()*2/3)

rootWidget = g_ui.getRootWidget()
if rootWidget then
    tcAutoParty = autopartyui.status

    autoPartyListWindow = UI.createWindow('AutoPartyListWindow', rootWidget)
    autoPartyListWindow:hide()

    autopartyui.editPlayerList.onClick = function(widget)
        if autoPartyListWindow:isVisible() then
            autoPartyListWindow:hide()
        else
            autoPartyListWindow:show()
            autoPartyListWindow:raise()
            autoPartyListWindow:focus()
        end
    end

    autopartyui.ptShare.onClick = function(widget)
        g_game.partyShareExperience(not player:isPartySharedExperienceActive())
    end

    autopartyui.ptLeave.onClick = function(widget)
        g_game.partyLeave()
    end

    autoPartyListWindow.closeButton.onClick = function(widget)
        autoPartyListWindow:hide()
    end

    autoPartyListWindow.resetButton.onClick = function(widget)
        tableteste = {}
        levelTable = {}
        storage.highlvl = player:getLevel()
        lvlmember = math.ceil(player:getLevel()*2/3)
        autoPartyListWindow.lblMinLvl:setText(lvlmember)
    end

    if storage[panelName].autoPartyList and #storage[panelName].autoPartyList > 0 then
        for _, pName in ipairs(storage[panelName].autoPartyList) do
            local label = g_ui.createWidget("AutoPartyName", autoPartyListWindow.lstAutoParty)
            label.remove.onClick = function(widget)
                table.removevalue(storage[panelName].autoPartyList, label:getText())
                label:destroy()
            end
            label:setText(pName)
        end
    end
    autoPartyListWindow.addPlayer.onClick = function(widget)
        local playerName = autoPartyListWindow.playerName:getText()
        if playerName:len() > 0 and not (table.contains(storage[panelName].autoPartyList, playerName, true)
                or storage[panelName].leaderName == playerName) then
            table.insert(storage[panelName].autoPartyList, playerName)
            local label = g_ui.createWidget("AutoPartyName", autoPartyListWindow.lstAutoParty)
            label.remove.onClick = function(widget)
                table.removevalue(storage[panelName].autoPartyList, label:getText())
                label:destroy()
            end
            label:setText(playerName)
            autoPartyListWindow.playerName:setText('')
        end
    end

    autopartyui.status:setOn(storage[panelName].enabled)
    autopartyui.status.onClick = function(widget)
        storage[panelName].enabled = not storage[panelName].enabled
        widget:setOn(storage[panelName].enabled)
    end

    autoPartyListWindow.creatureMove:setChecked(storage[panelName].onMove)
    autoPartyListWindow.creatureMove.onClick = function(widget)
        storage[panelName].onMove = not storage[panelName].onMove
        widget:setChecked(storage[panelName].onMove)
    end

    autoPartyListWindow.passlK:setChecked(storage[panelName].passleaderenabled)
    autoPartyListWindow.passlK.onClick = function(widget)
        storage[panelName].passleaderenabled = not storage[panelName].passleaderenabled
        widget:setChecked(storage[panelName].passleaderenabled)
    end

    autoPartyListWindow.joinK:setChecked(storage[panelName].joinenabled)
    autoPartyListWindow.joinK.onClick = function(widget)
        storage[panelName].joinenabled = not storage[panelName].joinenabled
        widget:setChecked(storage[panelName].joinenabled)
    end

    autoPartyListWindow.leaveK:setChecked(storage[panelName].leaveenabled)
    autoPartyListWindow.leaveK.onClick = function(widget)
        storage[panelName].leaveenabled = not storage[panelName].leaveenabled
        widget:setChecked(storage[panelName].leaveenabled)
    end

    autoPartyListWindow.playerName.onKeyPress = function(self, keyCode, keyboardModifiers)
        if not (keyCode == 5) then
            return false
        end
        autoPartyListWindow.addPlayer.onClick()
        return true
    end

    autoPartyListWindow.playerName.onTextChange = function(widget, text)
        if table.contains(storage[panelName].autoPartyList, text, true) then
            autoPartyListWindow.addPlayer:setColor("#FF0000")
        else
            autoPartyListWindow.addPlayer:setColor("#FFFFFF")
        end
    end

    autoPartyListWindow.txtLeader.onTextChange = function(widget, text)
        storage[panelName].leaderName = text
    end
    autoPartyListWindow.txtLeader:setText(storage[panelName].leaderName)

    autoPartyListWindow.textpasslK.onTextChange = function(widget, text)
        storage[panelName].leaderkey = text
    end
    autoPartyListWindow.textpasslK:setText(storage[panelName].leaderkey)

    autoPartyListWindow.textjoinK.onTextChange = function(widget, text)
        storage[panelName].joinkey = text
    end
    autoPartyListWindow.textjoinK:setText(storage[panelName].joinkey)

    autoPartyListWindow.textleaveK.onTextChange = function(widget, text)
        storage[panelName].leavekey = text
    end
    autoPartyListWindow.textleaveK:setText(storage[panelName].leavekey)

    autoPartyListWindow.lblMinLvl:setText(lvlmember)

    onTextMessage(function(mode, text)
        if tcAutoParty:isOn() or storage[panelName].joinenabled then
            if mode == 20 then
                if text:find("has joined the party") then
                    local data = regexMatch(text, "([a-z A-Z-]*) has joined the party")[1][2]
                    if data then
                        if table.contains(storage[panelName].autoPartyList, data, true) then
                            if not player:isPartySharedExperienceActive() then
                                g_game.partyShareExperience(true)
                            end
                        end
                    end
                elseif text:find("has invited you") then
                    local data = regexMatch(text, "([a-z A-Z-]*) has invited you")[1][2]
                    if data then
                        if storage[panelName].leaderName:lower() == data:lower() then
                            local leader = getCreatureByName(data, true)
                            if leader then
                                g_game.partyJoin(leader:getId())
                                return
                            end
                        end
                    end
                end
            end
        end
    end)

    onTalk(function(name, level, mode, text, channelId, pos)
        if mode ~= 1 then return end
  if storage[panelName].leavekey then
           if player:getName():lower() == name and string.find(text, storage[panelName].leavekey) and storage[panelName].leaveenabled then
             g_game.partyLeave()
           end
     end
        if player:getName():lower() == name then return end
        if player:getName():lower() == storage[panelName].leaderName:lower() then
            if player:getShield() == 4 then
              g_game.partyShareExperience(not player:isPartySharedExperienceActive())
            end
            if player:getShield() == 1 then
                g_game.partyJoin(player:getId())
                return
            end
            local friend = getPlayerByName(name)
            if friend and not table.contains(storage[panelName].autoPartyList, friend:getName(), true) then return end
   if storage[panelName].joinkey then
             if string.find(text, storage[panelName].joinkey) and storage[panelName].joinenabled then
              g_game.partyInvite(friend:getId())
             end
         end
        end
  if storage[panelName].leaderkey then
       local friend = getPlayerByName(name)
       if friend and player:isPartyLeader() and string.find(text, storage[panelName].leaderkey) and storage[panelName].passleaderenabled then
          g_game.partyPassLeadership(friend:getId())
         end
     end
    end)

    function creatureInvites(creature)
        if not creature:isPlayer() or creature == player then return end
        if creature:getName():lower() == storage[panelName].leaderName:lower() then
            if creature:getShield() == 1 then
                g_game.partyJoin(creature:getId())
                return
            end
        end
        if player:getName():lower() ~= storage[panelName].leaderName:lower() then return end
        if not table.contains(storage[panelName].autoPartyList, creature:getName(), true) then return end
        if creature:isPartyMember() or creature:getShield() == 2 then return end
        g_game.partyInvite(creature:getId())
    end

    onCreatureAppear(function(creature)
        if tcAutoParty:isOn() then
            creatureInvites(creature)
        end
    end)
    onCreaturePositionChange(function(creature, newPos, oldPos)
        if tcAutoParty:isOn() and storage[panelName].onMove then
            creatureInvites(creature)
        end
    end)
end

onCreatureAppear(function(creature)
  if not tcAutoParty:isOn() then return end
    if table.contains(tableteste, creature:getName()) then return end
    if creature ~= player and creature:isPlayer() and not creature:isNpc() then
      g_game.look(creature)
      table.insert(tableteste, creature:getName())
    end
end)

onTextMessage(function(mode, text)
 if not tcAutoParty:isOn() then return end
  local re = regexMatch(text, [[You see ([A-z -]) \(Level ([0-9])\)(?:.|)]])
  if #re ~= 0 then
   local name = re[1][2]
   local level = tonumber(re[1][3])
   local friendname = getCreatureByName(name)
    if friendname and table.contains(storage[panelName].autoPartyList, friendname:getName(), true) then
       table.insert(levelTable, {niv = level})
        if level and level > storage.highlvl then
    storage.highlvl = level
          lvlmember = math.ceil(storage.highlvl*2/3)
          autoPartyListWindow.lblMinLvl:setText(lvlmember)
        end
    end
 end
end)
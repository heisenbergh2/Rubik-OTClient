local version = "12.1"
local currentVersion
local available = false

storage.checkVersion = storage.checkVersion or 0


UI.Label("BBTC ".. version .." \n Haven Optional-PVP")
UI.Button("Bad Boys OT Site", function() g_platform.openUrl("http://badboysot.com/") end)
UI.Button("Whatsapp Bad Boys OT", function() g_platform.openUrl("https://wa.me/5554996516912") end)
UI.Separator()


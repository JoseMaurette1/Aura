print("Hello world, from client!")

-- Initialize Spin UI
local SpinUI = require(script.SpinUI)
SpinUI.init()

-- Initialize Inventory Controller
local InventoryController = require(script.InventoryController)
InventoryController.init()

-- Initialize Roll Controller
local RollController = require(script.RollController)
RollController.init()

-- Initialize Shop Controller
local ShopController = require(script.ShopController)
ShopController.init()

-- Initialize Rebirth Controller
local RebirthController = require(script.RebirthController)
RebirthController.init()

-- Initialize Invite Controller
local InviteController = require(script.InviteController)
InviteController.init()

-- Initialize Settings Controller
local SettingsController = require(script.SettingsController)
SettingsController.init()

-- Initialize Auto Click Controller
local AutoClickController = require(script.AutoClickController)
AutoClickController.init()

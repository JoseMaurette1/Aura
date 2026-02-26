print("Hello world, from client!")

-- Auto-register all brainrots from ReplicatedStorage folder structure FIRST
-- so all controllers have the full brainrot list
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BrainrotConfig    = require(ReplicatedStorage.Shared.BrainrotConfig)
BrainrotConfig.autoRegisterFromFolders(ReplicatedStorage:WaitForChild("Brainrots"))

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

-- Initialize Simulator Circle Controller
local SimulatorCircleController = require(script.SimulatorCircleController)
SimulatorCircleController.init()

-- Initialize Codes Controller
local CodesController = require(script.CodesController)
CodesController.init()

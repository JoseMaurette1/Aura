print("Hello world, from server!")

-- Auto-register all brainrots from ServerStorage folder structure FIRST
-- so SpinHandler and PetController have the full brainrot list
local ServerStorage  = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BrainrotConfig = require(ReplicatedStorage.Shared.BrainrotConfig)
BrainrotConfig.autoRegisterFromFolders(ServerStorage:WaitForChild("Brainrots"))

-- Initialize Spin Handler first — it creates the RemoteEvents folder
local SpinHandler = require(script.SpinHandler)
print("[Server] Spin Handler loaded")

-- Initialize Pet Controller — adds EquipRemote to the existing RemoteEvents folder
local PetController = require(script.PetController)
print("[Server] Pet Controller loaded")

-- Initialize Rebirth Handler — adds RebirthRemote to the existing RemoteEvents folder
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local RebirthHandler = require(script.RebirthHandler)
RebirthHandler.init(remoteEventsFolder)
print("[Server] Rebirth Handler loaded")

-- Initialize Gamepass Handler — checks/grants all gamepasses on join and purchase
local GamepassHandler = require(script.GamepassHandler)
GamepassHandler.init(remoteEventsFolder)
print("[Server] Gamepass Handler loaded")

-- Initialize Codes Handler — validates and redeems promo codes
local CodesHandler = require(script.CodesHandler)
CodesHandler.init(remoteEventsFolder)
print("[Server] Codes Handler loaded")

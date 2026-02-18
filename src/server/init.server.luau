print("Hello world, from server!")

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

-- Initialize Gamepass Handler — checks/grants AutoClick pass on join and purchase
local GamepassHandler = require(script.GamepassHandler)
GamepassHandler.init()
print("[Server] Gamepass Handler loaded")

-- Initialize Codes Handler — validates and redeems promo codes
local CodesHandler = require(script.CodesHandler)
CodesHandler.init(remoteEventsFolder)
print("[Server] Codes Handler loaded")

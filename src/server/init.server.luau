print("Hello world, from server!")

-- Initialize Spin Handler first — it creates the RemoteEvents folder
local SpinHandler = require(script.SpinHandler)
print("[Server] Spin Handler loaded")

-- Initialize Pet Controller — adds EquipRemote to the existing RemoteEvents folder
local PetController = require(script.PetController)
print("[Server] Pet Controller loaded")

-- Configuration for all brainrots in the game
local BrainrotConfig = {}

-- Pity system configuration
BrainrotConfig.PityConfig = {
	Enabled = true,
	PityThreshold = 2000, -- Guarantee a 1/1000+ rarity after this many rolls
	MinRarityForPity = 1000 -- Only count brainrots with rarity >= 1000 for pity
}

-- Near-miss configuration
BrainrotConfig.NearMissConfig = {
	Enabled = true,
	Chance = 0.25, -- 25% chance to show a near-miss
	MinRarityToShow = 500 -- Only show near-misses for brainrots with rarity >= 500
}

-- Brainrot data structure:
-- {
--   Name: string,
--   Rarity: number (1 in X chance),
--   MoneyReward: number,
--   Description: string,
--   ImageId: string (rbxassetid://),
--   Color: Color3
-- }

-- Rarity tier colors:
--   Common     (1/10  – 1/25):   White
--   Uncommon   (1/50  – 1/100):  Green
--   Rare       (1/250 – 1/1000): Purple
--   Legendary  (1/2500– 1/5000): Gold
--   Mythic     (1/10000+):       Red

BrainrotConfig.Brainrots = {
	{
		Name = "Skibidi Toilet",
		Rarity = 10,
		MoneyReward = 50,
		Description = "The classic brainrot. Nothing special.",
		ImageId = "rbxassetid://0",
		Color = Color3.fromRGB(220, 220, 220)  -- Common: white
	},
	{
		Name = "Sigma Male",
		Rarity = 25,
		MoneyReward = 150,
		Description = "Gigachad energy detected.",
		ImageId = "rbxassetid://0",
		Color = Color3.fromRGB(220, 220, 220)  -- Common: white
	},
	{
		Name = "Ohio Moment",
		Rarity = 50,
		MoneyReward = 300,
		Description = "Only in Ohio...",
		ImageId = "rbxassetid://0",
		Color = Color3.fromRGB(80, 200, 80)    -- Uncommon: green
	},
	{
		Name = "Grimace Shake",
		Rarity = 100,
		MoneyReward = 750,
		Description = "Purple power unleashed!",
		ImageId = "rbxassetid://0",
		Color = Color3.fromRGB(80, 200, 80)    -- Uncommon: green
	},
	{
		Name = "Giga Chad",
		Rarity = 250,
		MoneyReward = 2000,
		Description = "The ultimate alpha.",
		ImageId = "rbxassetid://0",
		Color = Color3.fromRGB(180, 80, 255)   -- Rare: purple
	},
	{
		Name = "Mewing Master",
		Rarity = 500,
		MoneyReward = 5000,
		Description = "Jawline of the gods.",
		ImageId = "rbxassetid://0",
		Color = Color3.fromRGB(180, 80, 255)   -- Rare: purple
	},
	{
		Name = "Fanum Tax",
		Rarity = 1000,
		MoneyReward = 12500,
		Description = "They're taxing your rizz!",
		ImageId = "rbxassetid://0",
		Color = Color3.fromRGB(180, 80, 255)   -- Rare: purple
	},
	{
		Name = "Rizz God",
		Rarity = 2500,
		MoneyReward = 35000,
		Description = "Infinite W rizz energy.",
		ImageId = "rbxassetid://0",
		Color = Color3.fromRGB(255, 215, 0)    -- Legendary: gold
	},
	{
		Name = "Kai Cenat",
		Rarity = 5000,
		MoneyReward = 100000,
		Description = "AMP WORLDDDD!",
		ImageId = "rbxassetid://0",
		Color = Color3.fromRGB(255, 215, 0)    -- Legendary: gold
	},
	{
		Name = "GYATT OMEGA",
		Rarity = 10000,
		MoneyReward = 500000,
		Description = "The rarest brainrot of them all.",
		ImageId = "rbxassetid://0",
		Color = Color3.fromRGB(255, 60, 60)    -- Mythic: red
	}
}

-- Calculate total weight for weighted random selection
function BrainrotConfig.calculateTotalWeight()
	local totalWeight = 0
	for _, brainrot in ipairs(BrainrotConfig.Brainrots) do
		-- Weight is inversely proportional to rarity (1/rarity chance)
		local weight = 1 / brainrot.Rarity
		totalWeight = totalWeight + weight
	end
	return totalWeight
end

-- Get a random brainrot based on weighted probability
function BrainrotConfig.getRandomBrainrot()
	local totalWeight = BrainrotConfig.calculateTotalWeight()
	local random = math.random() * totalWeight

	local currentWeight = 0
	for _, brainrot in ipairs(BrainrotConfig.Brainrots) do
		local weight = 1 / brainrot.Rarity
		currentWeight = currentWeight + weight

		if random <= currentWeight then
			return brainrot
		end
	end

	-- Fallback to first brainrot (should never reach here)
	return BrainrotConfig.Brainrots[1]
end

-- Get brainrot by name
function BrainrotConfig.getBrainrotByName(name: string)
	for _, brainrot in ipairs(BrainrotConfig.Brainrots) do
		if brainrot.Name == name then
			return brainrot
		end
	end
	return nil
end

-- Get rare brainrots (for pity system)
function BrainrotConfig.getRareBrainrots()
	local rareBrainrots = {}
	for _, brainrot in ipairs(BrainrotConfig.Brainrots) do
		if brainrot.Rarity >= BrainrotConfig.PityConfig.MinRarityForPity then
			table.insert(rareBrainrots, brainrot)
		end
	end
	return rareBrainrots
end

-- Get a guaranteed rare brainrot (for pity)
function BrainrotConfig.getGuaranteedRareBrainrot()
	local rareBrainrots = BrainrotConfig.getRareBrainrots()
	if #rareBrainrots > 0 then
		return rareBrainrots[math.random(1, #rareBrainrots)]
	end
	return BrainrotConfig.Brainrots[#BrainrotConfig.Brainrots] -- Fallback to rarest
end

-- Check if brainrot counts for pity reset
function BrainrotConfig.countsForPityReset(brainrot)
	return brainrot.Rarity >= BrainrotConfig.PityConfig.MinRarityForPity
end

-- Get a super rare brainrot for near-miss effect
function BrainrotConfig.getSuperRareBrainrot()
	local superRares = {}
	for _, brainrot in ipairs(BrainrotConfig.Brainrots) do
		if brainrot.Rarity >= BrainrotConfig.NearMissConfig.MinRarityToShow then
			table.insert(superRares, brainrot)
		end
	end
	if #superRares > 0 then
		return superRares[math.random(1, #superRares)]
	end
	return nil
end

return BrainrotConfig

-- Configuration for all brainrots in the game
local BrainrotConfig = {}

-- Pity system configuration (per-tier thresholds)
BrainrotConfig.PityConfig = {
	Enabled = true,
	-- Per-tier: spins without hitting that tier triggers a guarantee
	Uncommon  = { Threshold = 50,   MinRarity = 75    },  -- dev: 50,   prod: 200
	Legendary = { Threshold = 300,  MinRarity = 2500  },  -- dev: 300,  prod: 1500
	Mythic    = { Threshold = 1000, MinRarity = 10000 },  -- dev: 1000, prod: 5000
	-- Legacy fields kept for RollController pity-shake animation
	PityThreshold    = 50,
	MinRarityForPity = 75,
}

-- Near-miss configuration
BrainrotConfig.NearMissConfig = {
	Enabled = true,
	Chance = 0.25,           -- 25% chance to show a near-miss
	MinRarityToShow = 500    -- Only show near-misses for brainrots with rarity >= 500
}

-- Rebirth / luck configuration
local LUCK_SEQUENCE = {0.25, 0.5, 0.75, 1, 1.5, 2, 2.5, 3, 3.5}
local LUCK_CAP = 6.0

-- Returns the luck multiplier for a given rebirthCount (0-indexed), capped at LUCK_CAP
function BrainrotConfig.getLuck(rebirthCount)
	local raw
	if rebirthCount < #LUCK_SEQUENCE then
		raw = LUCK_SEQUENCE[rebirthCount + 1]
	else
		raw = 3.5 + (rebirthCount - (#LUCK_SEQUENCE - 1)) * 0.5
	end
	return math.min(raw, LUCK_CAP)
end

-- Returns the luck multiplier for the next rebirth
function BrainrotConfig.getNextLuck(rebirthCount)
	return BrainrotConfig.getLuck(rebirthCount + 1)
end

-- Returns rolls earned per spin based on equipped pet's rarity tier.
-- brainrot = nil means no pet equipped (base income = 1).
function BrainrotConfig.getRollsForBrainrot(brainrot)
	if not brainrot then return 1 end  -- no pet equipped
	local r = brainrot.Rarity
	if r <= 25   then return 1  end  -- Common
	if r <= 100  then return 2  end  -- Uncommon
	if r <= 1000 then return 5  end  -- Rare
	if r <= 5000 then return 15 end  -- Legendary
	return 50                         -- Mythic
end

-- Returns the cost to rebirth from rebirthCount to rebirthCount+1
function BrainrotConfig.getRebirthCost(rebirthCount)
	return math.floor(100 * (1.5 ^ rebirthCount))
end

-- Brainrot data structure:
-- {
--   Name: string,
--   ModelName: string,         -- exact name of Model in ServerStorage/Brainrots
--   Rarity: number,            -- 1-in-X chance
--   RollsReward: number,
--   Description: string,
--   ImageId: string,           -- rbxassetid://... (placeholder for now)
--   Color: Color3
-- }

-- Rarity tier colors:
--   Common     (1/15):    White  RGB(220, 220, 220)
--   Uncommon   (1/75):    Green  RGB(80,  200, 80)
--   Rare       (1/500):   Purple RGB(180, 80,  255)
--   Legendary  (1/2500):  Gold   RGB(255, 215, 0)
--   Mythic     (1/10000): Red    RGB(255, 60,  60)

local WHITE  = Color3.fromRGB(220, 220, 220)
local GREEN  = Color3.fromRGB(80,  200, 80)
local PURPLE = Color3.fromRGB(180, 80,  255)
local GOLD   = Color3.fromRGB(255, 215, 0)
local RED    = Color3.fromRGB(255, 60,  60)

-- Default values per rarity tier for auto-registration
local TIER_DEFAULTS = {
	Common    = { Rarity = 15,    Color = WHITE,  RollsReward = 100    },
	Uncommon  = { Rarity = 75,    Color = GREEN,  RollsReward = 750    },
	Rare      = { Rarity = 500,   Color = PURPLE, RollsReward = 5000   },
	Legendary = { Rarity = 2500,  Color = GOLD,   RollsReward = 50000  },
	Mythic    = { Rarity = 10000, Color = RED,    RollsReward = 500000 },
}

-- Scans a Brainrots folder (ServerStorage or ReplicatedStorage) and auto-registers
-- any model not already in BrainrotConfig.Brainrots.
-- Call once on startup: server passes ServerStorage.Brainrots, client passes ReplicatedStorage.Brainrots.
function BrainrotConfig.autoRegisterFromFolders(brainrotsFolder)
	if not brainrotsFolder then return end

	-- Build a fast lookup of already-registered names (lowercase, spaces normalized)
	local registered = {}
	for _, b in ipairs(BrainrotConfig.Brainrots) do
		registered[b.Name:lower():gsub("_", " ")] = true
	end

	local added = 0
	for tierName, defaults in pairs(TIER_DEFAULTS) do
		local folder = brainrotsFolder:FindFirstChild(tierName)
		if folder then
			for _, model in ipairs(folder:GetChildren()) do
				-- Normalize: use spaces as the canonical display name
				local displayName = model.Name:gsub("_", " ")
				local key         = displayName:lower()

				if not registered[key] then
					table.insert(BrainrotConfig.Brainrots, {
						Name        = displayName,
						ModelName   = model.Name,   -- keep original for exact folder lookup
						Rarity      = defaults.Rarity,
						RollsReward = defaults.RollsReward,
						Description = "???",
						ImageId     = "rbxassetid://0",
						Color       = defaults.Color,
					})
					registered[key] = true
					added += 1
				end
			end
		end
	end

	if added > 0 then
		print(string.format("[BrainrotConfig] Auto-registered %d brainrots from folders", added))
	end
end

BrainrotConfig.Brainrots = {

	-- ============================================================
	-- COMMON (1/15) — 31 brainrots
	-- ============================================================
	{
		Name = "Tralalero Tralala",
		ModelName = "Tralalero Tralala",
		AuraName = "CommonAura",
		Rarity = 15,
		RollsReward = 100,
		Description = "La la la la la.",
		ImageId = "rbxassetid://0",
		Color = WHITE,
	},
	{
		Name = "Brr Brr Patapim",
		ModelName = "Brr Brr Patapim",
		AuraName = "CommonAura",
		Rarity = 15,
		RollsReward = 100,
		Description = "Brrr.",
		ImageId = "rbxassetid://0",
		Color = WHITE,
	},
	{
		Name = "Chimpanzini Bananini",
		ModelName = "Chimpanzini Bananini",
		AuraName = "CommonAura",
		Rarity = 15,
		RollsReward = 100,
		Description = "He's got bananas.",
		ImageId = "rbxassetid://0",
		Color = WHITE,
	},
	{
		Name = "Odin Din Din Dun",
		ModelName = "Odin Din Din Dun",
		AuraName = "CommonAura",
		Rarity = 15,
		RollsReward = 100,
		Description = "Din din din.",
		ImageId = "rbxassetid://0",
		Color = WHITE,
	},
	{
		Name = "Espresso Signora",
		ModelName = "Espresso Signora",
		AuraName = "CommonAura",
		Rarity = 15,
		RollsReward = 100,
		Description = "Un espresso, per favore.",
		ImageId = "rbxassetid://0",
		Color = WHITE,
	},
	{
		Name = "Los Combinasionas",
		ModelName = "Los Combinasionas",
		AuraName = "CommonAura",
		Rarity = 15,
		RollsReward = 100,
		Description = "The combination squad.",
		ImageId = "rbxassetid://0",
		Color = WHITE,
	},
	{
		Name = "Piccione Macchina",
		ModelName = "Piccione Macchina",
		AuraName = "CommonAura",
		Rarity = 15,
		RollsReward = 100,
		Description = "Pigeon machine.",
		ImageId = "rbxassetid://0",
		Color = WHITE,
	},
	{
		Name = "Ballerino Lololo",
		ModelName = "Ballerino Lololo",
		AuraName = "CommonAura",
		Rarity = 15,
		RollsReward = 100,
		Description = "He dances.",
		ImageId = "rbxassetid://0",
		Color = WHITE,
	},
	{
		Name = "Pandaccini Bananini",
		ModelName = "Pandaccini Bananini",
		AuraName = "CommonAura",
		Rarity = 15,
		RollsReward = 100,
		Description = "Panda with bananas.",
		ImageId = "rbxassetid://0",
		Color = WHITE,
	},
	{
		Name = "Tukanno Bananno",
		ModelName = "Tukanno Bananno",
		AuraName = "CommonAura",
		Rarity = 15,
		RollsReward = 100,
		Description = "Toucan with a banana.",
		ImageId = "rbxassetid://0",
		Color = WHITE,
	},
	{
		Name = "Agarrini la Palini",
		ModelName = "Agarrini la Palini",
		AuraName = "CommonAura",
		Rarity = 15,
		RollsReward = 100,
		Description = "Grab the palm.",
		ImageId = "rbxassetid://0",
		Color = WHITE,
	},
	{
		Name = "Las Tralaleritas",
		ModelName = "Las Tralaleritas",
		AuraName = "CommonAura",
		Rarity = 15,
		RollsReward = 100,
		Description = "The tralalero sisters.",
		ImageId = "rbxassetid://0",
		Color = WHITE,
	},
	{
		Name = "Cocofanto Elefanto",
		ModelName = "Cocofanto Elefanto",
		AuraName = "CommonAura",
		Rarity = 15,
		RollsReward = 100,
		Description = "Coconut elephant.",
		ImageId = "rbxassetid://0",
		Color = WHITE,
	},
	{
		Name = "Avocadorilla",
		ModelName = "Avocadorilla",
		AuraName = "CommonAura",
		Rarity = 15,
		RollsReward = 100,
		Description = "Avocado gorilla.",
		ImageId = "rbxassetid://0",
		Color = WHITE,
	},
	{
		Name = "Noobini Pizzanini",
		ModelName = "Noobini Pizzanini",
		AuraName = "CommonAura",
		Rarity = 15,
		RollsReward = 100,
		Description = "Noob pizza enjoyer.",
		ImageId = "rbxassetid://0",
		Color = WHITE,
	},
	{
		Name = "Gangster Footera",
		ModelName = "Gangster Footera",
		AuraName = "CommonAura",
		Rarity = 15,
		RollsReward = 100,
		Description = "Foot gang.",
		ImageId = "rbxassetid://0",
		Color = WHITE,
	},
	{
		Name = "Tim Cheese",
		ModelName = "Tim Cheese",
		AuraName = "CommonAura",
		Rarity = 15,
		RollsReward = 100,
		Description = "Just Tim and his cheese.",
		ImageId = "rbxassetid://0",
		Color = WHITE,
	},
	{
		Name = "Talpa Di Fero",
		ModelName = "Talpa Di Fero",
		AuraName = "CommonAura",
		Rarity = 15,
		RollsReward = 100,
		Description = "Iron mole.",
		ImageId = "rbxassetid://0",
		Color = WHITE,
	},
	{
		Name = "Pipi Corni",
		ModelName = "Pipi Corni",
		AuraName = "CommonAura",
		Rarity = 15,
		RollsReward = 100,
		Description = "Corny.",
		ImageId = "rbxassetid://0",
		Color = WHITE,
	},
	{
		Name = "Pipi Avocado",
		ModelName = "Pipi Avocado",
		AuraName = "CommonAura",
		Rarity = 15,
		RollsReward = 100,
		Description = "Avocado vibes.",
		ImageId = "rbxassetid://0",
		Color = WHITE,
	},
	{
		Name = "Salamino Penguino",
		ModelName = "Salamino Penguino",
		AuraName = "CommonAura",
		Rarity = 15,
		RollsReward = 100,
		Description = "Salami penguin.",
		ImageId = "rbxassetid://0",
		Color = WHITE,
	},
	{
		Name = "Fluriflura",
		ModelName = "Fluriflura",
		AuraName = "CommonAura",
		Rarity = 15,
		RollsReward = 100,
		Description = "Flurry of flura.",
		ImageId = "rbxassetid://0",
		Color = WHITE,
	},
	{
		Name = "Penguino Cocosino",
		ModelName = "Penguino Cocosino",
		AuraName = "CommonAura",
		Rarity = 15,
		RollsReward = 100,
		Description = "Coconut penguin.",
		ImageId = "rbxassetid://0",
		Color = WHITE,
	},
	{
		Name = "Sigma Boy",
		ModelName = "Sigma Boy",
		AuraName = "CommonAura",
		Rarity = 15,
		RollsReward = 100,
		Description = "Sigma grindset.",
		ImageId = "rbxassetid://0",
		Color = WHITE,
	},
	{
		Name = "Bambini_Crostini",
		ModelName = "Bambini_Crostini",
		AuraName = "CommonAura",
		Rarity = 15,
		RollsReward = 100,
		Description = "Baby crostini.",
		ImageId = "rbxassetid://0",
		Color = WHITE,
	},
	{
		Name = "Ta Ta Ta Ta Sahur",
		ModelName = "Ta Ta Ta Ta Sahur",
		AuraName = "CommonAura",
		Rarity = 15,
		RollsReward = 100,
		Description = "Ta ta ta sahur!",
		ImageId = "rbxassetid://0",
		Color = WHITE,
	},
	{
		Name = "Cacto Hipopotamo",
		ModelName = "Cacto Hipopotamo",
		AuraName = "CommonAura",
		Rarity = 15,
		RollsReward = 100,
		Description = "Cactus hippo.",
		ImageId = "rbxassetid://0",
		Color = WHITE,
	},

	-- ============================================================
	-- UNCOMMON (1/75) — 30 brainrots
	-- ============================================================
	{
		Name = "Dragon Cannelloni",
		ModelName = "Dragon Cannelloni",
		Rarity = 75,
		RollsReward = 750,
		Description = "Cannelloni dragon breathes pasta.",
		ImageId = "rbxassetid://0",
		Color = GREEN,
	},
	{
		Name = "Zibra Zubra Zibralini",
		ModelName = "Zibra Zubra Zibralini",
		Rarity = 75,
		RollsReward = 750,
		Description = "Zebra vibes.",
		ImageId = "rbxassetid://0",
		Color = GREEN,
	},
	{
		Name = "Tigroligre Frutonni",
		ModelName = "Tigroligre Frutonni",
		Rarity = 75,
		RollsReward = 750,
		Description = "Fruity tiger.",
		ImageId = "rbxassetid://0",
		Color = GREEN,
	},
	{
		Name = "Las Vaquitas Saturnitas",
		ModelName = "Las Vaquitas Saturnitas",
		Rarity = 75,
		RollsReward = 750,
		Description = "Little Saturn cows.",
		ImageId = "rbxassetid://0",
		Color = GREEN,
	},
	{
		Name = "Los Tungtungtungcitos",
		ModelName = "Los Tungtungtungcitos",
		Rarity = 75,
		RollsReward = 750,
		Description = "The little tung tung squad.",
		ImageId = "rbxassetid://0",
		Color = GREEN,
	},
	{
		Name = "Pot Hotspot",
		ModelName = "Pot Hotspot",
		Rarity = 75,
		RollsReward = 750,
		Description = "Hot pot hotspot.",
		ImageId = "rbxassetid://0",
		Color = GREEN,
	},
	{
		Name = "Frigo Camelo",
		ModelName = "Frigo Camelo",
		Rarity = 75,
		RollsReward = 750,
		Description = "Fridge camel.",
		ImageId = "rbxassetid://0",
		Color = GREEN,
	},
	{
		Name = "Los Tralaleritos",
		ModelName = "Los Tralaleritos",
		Rarity = 75,
		RollsReward = 750,
		Description = "Little tralalero gang.",
		ImageId = "rbxassetid://0",
		Color = GREEN,
	},
	{
		Name = "Tigrilini Watermelini",
		ModelName = "Tigrilini Watermelini",
		Rarity = 75,
		RollsReward = 750,
		Description = "Watermelon tiger cub.",
		ImageId = "rbxassetid://0",
		Color = GREEN,
	},
	{
		Name = "Torrtuginni Dragonfrutini",
		ModelName = "Torrtuginni Dragonfrutini",
		Rarity = 75,
		RollsReward = 750,
		Description = "Dragon fruit tortoise.",
		ImageId = "rbxassetid://0",
		Color = GREEN,
	},
	{
		Name = "Los Crocodillitos",
		ModelName = "Los Crocodillitos",
		Rarity = 75,
		RollsReward = 750,
		Description = "The little croc squad.",
		ImageId = "rbxassetid://0",
		Color = GREEN,
	},
	{
		Name = "Ti Ti Ti Sahur",
		ModelName = "Ti Ti Ti Sahur",
		Rarity = 75,
		RollsReward = 750,
		Description = "Ti ti ti.",
		ImageId = "rbxassetid://0",
		Color = GREEN,
	},
	{
		Name = "Bananita Dolphinita",
		ModelName = "Bananita Dolphinita",
		Rarity = 75,
		RollsReward = 750,
		Description = "Banana dolphin.",
		ImageId = "rbxassetid://0",
		Color = GREEN,
	},
	{
		Name = "Gattatino_Nyanino",
		ModelName = "Gattatino_Nyanino",
		Rarity = 75,
		RollsReward = 750,
		Description = "Nyan kitten.",
		ImageId = "rbxassetid://0",
		Color = GREEN,
	},
	{
		Name = "Chef Crabracadabra",
		ModelName = "Chef Crabracadabra",
		Rarity = 75,
		RollsReward = 750,
		Description = "Crab chef magic.",
		ImageId = "rbxassetid://0",
		Color = GREEN,
	},
	{
		Name = "Avocadini Guffo",
		ModelName = "Avocadini Guffo",
		Rarity = 75,
		RollsReward = 750,
		Description = "Avocado owl.",
		ImageId = "rbxassetid://0",
		Color = GREEN,
	},
	{
		Name = "Chicleteira Bicicleteira",
		ModelName = "Chicleteira Bicicleteira",
		Rarity = 75,
		RollsReward = 750,
		Description = "Bubblegum bicycle.",
		ImageId = "rbxassetid://0",
		Color = GREEN,
	},
	{
		Name = "Trippi Troppi",
		ModelName = "Trippi Troppi",
		Rarity = 75,
		RollsReward = 750,
		Description = "Trippy tropical.",
		ImageId = "rbxassetid://0",
		Color = GREEN,
	},

	-- ============================================================
	-- RARE (1/500) — 25 brainrots
	-- ============================================================
	{
		Name = "Bombardiro Crocodilo",
		ModelName = "Bombardiro Crocodilo",
		Rarity = 500,
		RollsReward = 5000,
		Description = "Crocodile bomber.",
		ImageId = "rbxassetid://0",
		Color = PURPLE,
	},
	{
		Name = "Tung Tung Tung Sahur",
		ModelName = "Tung Tung Tung Sahur",
		Rarity = 500,
		RollsReward = 5000,
		Description = "Tung tung tung!",
		ImageId = "rbxassetid://0",
		Color = PURPLE,
	},
	{
		Name = "Bombombini Gusini",
		ModelName = "Bombombini Gusini",
		Rarity = 500,
		RollsReward = 5000,
		Description = "Goose bomber.",
		ImageId = "rbxassetid://0",
		Color = PURPLE,
	},
	{
		Name = "Ballerina Cappuccina",
		ModelName = "Ballerina Cappuccina",
		Rarity = 500,
		RollsReward = 5000,
		Description = "Cappuccino ballerina.",
		ImageId = "rbxassetid://0",
		Color = PURPLE,
	},
	{
		Name = "Sammyni_Spyderini",
		ModelName = "Sammyni_Spyderini",
		Rarity = 500,
		RollsReward = 5000,
		Description = "Sammy the spider.",
		ImageId = "rbxassetid://0",
		Color = PURPLE,
	},
	{
		Name = "Cavallo_Virtuoso",
		ModelName = "Cavallo_Virtuoso",
		Rarity = 500,
		RollsReward = 5000,
		Description = "Virtuoso horse.",
		ImageId = "rbxassetid://0",
		Color = PURPLE,
	},
	{
		Name = "Spioniro Golubiro",
		ModelName = "Spioniro Golubiro",
		Rarity = 500,
		RollsReward = 5000,
		Description = "Spy pigeon.",
		ImageId = "rbxassetid://0",
		Color = PURPLE,
	},
	{
		Name = "TungTungSahur",
		ModelName = "TungTungSahur",
		Rarity = 500,
		RollsReward = 5000,
		Description = "The original sahur.",
		ImageId = "rbxassetid://0",
		Color = PURPLE,
	},
	{
		Name = "Gorillo Watermelondrillo",
		ModelName = "Gorillo Watermelondrillo",
		Rarity = 500,
		RollsReward = 5000,
		Description = "Watermelon gorilla.",
		ImageId = "rbxassetid://0",
		Color = PURPLE,
	},
	{
		Name = "Rhino Toasterino",
		ModelName = "Rhino Toasterino",
		Rarity = 500,
		RollsReward = 5000,
		Description = "Rhino toaster.",
		ImageId = "rbxassetid://0",
		Color = PURPLE,
	},
	{
		Name = "Svinina Bombardino",
		ModelName = "Svinina Bombardino",
		Rarity = 500,
		RollsReward = 5000,
		Description = "Pig bomber.",
		ImageId = "rbxassetid://0",
		Color = PURPLE,
	},
	{
		Name = "Tric_Trac_Baraboom",
		ModelName = "Tric_Trac_Baraboom",
		Rarity = 500,
		RollsReward = 5000,
		Description = "Tric trac baraboom!",
		ImageId = "rbxassetid://0",
		Color = PURPLE,
	},
	{
		Name = "Trulimero Trulicina",
		ModelName = "Trulimero Trulicina",
		Rarity = 500,
		RollsReward = 5000,
		Description = "Trulimero and Trulicina.",
		ImageId = "rbxassetid://0",
		Color = PURPLE,
	},
	{
		Name = "Orangutini Ananassini",
		ModelName = "Orangutini Ananassini",
		Rarity = 500,
		RollsReward = 5000,
		Description = "Pineapple orangutan.",
		ImageId = "rbxassetid://0",
		Color = PURPLE,
	},
	{
		Name = "Graipuss Medussi",
		ModelName = "Graipuss Medussi",
		Rarity = 500,
		RollsReward = 5000,
		Description = "Grape jellyfish.",
		ImageId = "rbxassetid://0",
		Color = PURPLE,
	},
	{
		Name = "Burbaloni Loliloli",
		ModelName = "Burbaloni Loliloli",
		Rarity = 500,
		RollsReward = 5000,
		Description = "Loliloli burbaloni.",
		ImageId = "rbxassetid://0",
		Color = PURPLE,
	},
	{
		Name = "Bandito_Bobritto",
		ModelName = "Bandito_Bobritto",
		Rarity = 500,
		RollsReward = 5000,
		Description = "Bandit beaver.",
		ImageId = "rbxassetid://0",
		Color = PURPLE,
	},
	{
		Name = "Strawberrelli Flamingelli",
		ModelName = "Strawberrelli Flamingelli",
		Rarity = 500,
		RollsReward = 5000,
		Description = "Strawberry flamingo.",
		ImageId = "rbxassetid://0",
		Color = PURPLE,
	},
	{
		Name = "Pipi_Kiwi",
		ModelName = "Pipi_Kiwi",
		Rarity = 500,
		RollsReward = 5000,
		Description = "Kiwi pipi.",
		ImageId = "rbxassetid://0",
		Color = PURPLE,
	},
	{
		Name = "Perochello_Lemonchello",
		ModelName = "Perochello_Lemonchello",
		Rarity = 500,
		RollsReward = 5000,
		Description = "Lemon parrot.",
		ImageId = "rbxassetid://0",
		Color = PURPLE,
	},
	{
		Name = "Unclito_Samito",
		ModelName = "Unclito_Samito",
		Rarity = 500,
		RollsReward = 5000,
		Description = "Uncle Sam, but smaller.",
		ImageId = "rbxassetid://0",
		Color = PURPLE,
	},
	{
		Name = "Trippi_Troppi",
		ModelName = "Trippi_Troppi",
		Rarity = 500,
		RollsReward = 5000,
		Description = "Too trippy.",
		ImageId = "rbxassetid://0",
		Color = PURPLE,
	},

	-- ============================================================
	-- LEGENDARY (1/2500) — 15 brainrots
	-- ============================================================
	{
		Name = "Boneca Ambalabu",
		ModelName = "Boneca Ambalabu",
		Rarity = 2500,
		RollsReward = 50000,
		Description = "The legendary doll.",
		ImageId = "rbxassetid://0",
		Color = GOLD,
	},
	{
		Name = "Trenostruzzo_Turbo_3000",
		ModelName = "Trenostruzzo_Turbo_3000",
		Rarity = 2500,
		RollsReward = 50000,
		Description = "Turbo train 3000.",
		ImageId = "rbxassetid://0",
		Color = GOLD,
	},
	{
		Name = "Lirili Larila",
		ModelName = "Lirilì Larilà",   -- keep original to match Studio model name
		Rarity = 2500,
		RollsReward = 50000,
		Description = "Lirili larila...",
		ImageId = "rbxassetid://0",
		Color = GOLD,
	},
	{
		Name = "Garama_and_Madundung",
		ModelName = "Garama_and_Madundung",
		Rarity = 2500,
		RollsReward = 50000,
		Description = "Garam and madundung.",
		ImageId = "rbxassetid://0",
		Color = GOLD,
	},
	{
		Name = "Orcalero Orcala",
		ModelName = "Orcalero Orcala",
		Rarity = 2500,
		RollsReward = 50000,
		Description = "The orca legend.",
		ImageId = "rbxassetid://0",
		Color = GOLD,
	},
	{
		Name = "Strawberry Elephant",
		ModelName = "Strawberry Elephant",
		Rarity = 2500,
		RollsReward = 50000,
		Description = "Sweet and massive.",
		ImageId = "rbxassetid://0",
		Color = GOLD,
	},
	{
		Name = "Glorbo Fruttodrillo",
		ModelName = "Glorbo Fruttodrillo",
		Rarity = 2500,
		RollsReward = 50000,
		Description = "Glorbo the fruit croc.",
		ImageId = "rbxassetid://0",
		Color = GOLD,
	},
	{
		Name = "Girafa_Celestre",
		ModelName = "Girafa_Celestre",
		Rarity = 2500,
		RollsReward = 50000,
		Description = "Celestial giraffe.",
		ImageId = "rbxassetid://0",
		Color = GOLD,
	},
	{
		Name = "Cappuccino Assassino",
		ModelName = "Cappuccino Assassino",
		Rarity = 2500,
		RollsReward = 50000,
		Description = "The cappuccino killer.",
		ImageId = "rbxassetid://0",
		Color = GOLD,
	},
	{
		Name = "Trippi Troppi Troppa Trippa",
		ModelName = "Trippi Troppi Troppa Trippa",
		Rarity = 2500,
		RollsReward = 50000,
		Description = "Maximum trippa.",
		ImageId = "rbxassetid://0",
		Color = GOLD,
	},
	{
		Name = "La_Vacca_Saturno_Saturnita",
		ModelName = "La_Vacca_Saturno_Saturnita",
		Rarity = 2500,
		RollsReward = 50000,
		Description = "The Saturn cow.",
		ImageId = "rbxassetid://0",
		Color = GOLD,
	},
	{
		Name = "Ganganzelli Trulala",
		ModelName = "Ganganzelli Trulala",
		Rarity = 2500,
		RollsReward = 50000,
		Description = "Trulala gang.",
		ImageId = "rbxassetid://0",
		Color = GOLD,
	},
	{
		Name = "Blueberrinni_Octopusini",
		ModelName = "Blueberrinni_Octopusini",
		Rarity = 2500,
		RollsReward = 50000,
		Description = "Blueberry octopus.",
		ImageId = "rbxassetid://0",
		Color = GOLD,
	},
	{
		Name = "Lionel_Cactuseli",
		ModelName = "Lionel_Cactuseli",
		Rarity = 2500,
		RollsReward = 50000,
		Description = "Lionel the cactus.",
		ImageId = "rbxassetid://0",
		Color = GOLD,
	},

	-- ============================================================
	-- MYTHIC (1/10000) — 5 brainrots
	-- ============================================================
	{
		Name = "Brainrot God Lucky Block",
		ModelName = "Brainrot God Lucky Block",
		Rarity = 10000,
		RollsReward = 500000,
		Description = "The god block itself.",
		ImageId = "rbxassetid://0",
		Color = RED,
	},
	{
		Name = "Secret Lucky Block",
		ModelName = "Secret Lucky Block",
		Rarity = 10000,
		RollsReward = 500000,
		Description = "Nobody knows what's inside.",
		ImageId = "rbxassetid://0",
		Color = RED,
	},
	{
		Name = "Mythic Lucky Block",
		ModelName = "Mythic Lucky Block",
		Rarity = 10000,
		RollsReward = 500000,
		Description = "Beyond legendary.",
		ImageId = "rbxassetid://0",
		Color = RED,
	},
	{
		Name = "La_Grande_Combinasion",
		ModelName = "La_Grande_Combinasion",
		Rarity = 10000,
		RollsReward = 500000,
		Description = "The ultimate combination.",
		ImageId = "rbxassetid://0",
		Color = RED,
	},
	{
		Name = "Nuclearo Dinossauro",
		ModelName = "Nuclearo Dinossauro",
		Rarity = 10000,
		RollsReward = 500000,
		Description = "Nuclear dinosaur. Run.",
		ImageId = "rbxassetid://0",
		Color = RED,
	},
}

local COMMON_MAX_RARITY = 25  -- Rarity <= this value is treated as common (no luck bonus)

-- Get a random brainrot based on weighted probability.
-- luck: multiplier applied to non-common item weights (default 0.25)
function BrainrotConfig.getRandomBrainrot(luck)
	luck = luck or 0.25

	local totalWeight = 0
	for _, brainrot in ipairs(BrainrotConfig.Brainrots) do
		if brainrot.Rarity <= COMMON_MAX_RARITY then
			totalWeight += 1 / brainrot.Rarity
		else
			totalWeight += luck / brainrot.Rarity
		end
	end

	local roll    = math.random() * totalWeight
	local current = 0
	for _, brainrot in ipairs(BrainrotConfig.Brainrots) do
		if brainrot.Rarity <= COMMON_MAX_RARITY then
			current += 1 / brainrot.Rarity
		else
			current += luck / brainrot.Rarity
		end
		if roll <= current then return brainrot end
	end

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

-- Get a guaranteed rare brainrot (for uncommon pity)
function BrainrotConfig.getGuaranteedRareBrainrot()
	local rareBrainrots = BrainrotConfig.getRareBrainrots()
	if #rareBrainrots > 0 then
		return rareBrainrots[math.random(1, #rareBrainrots)]
	end
	return BrainrotConfig.Brainrots[#BrainrotConfig.Brainrots]
end

-- Get a guaranteed legendary-or-better brainrot (for legendary pity)
function BrainrotConfig.getGuaranteedLegendaryBrainrot()
	local pool = {}
	for _, b in ipairs(BrainrotConfig.Brainrots) do
		if b.Rarity >= BrainrotConfig.PityConfig.Legendary.MinRarity then
			table.insert(pool, b)
		end
	end
	if #pool > 0 then return pool[math.random(1, #pool)] end
	return BrainrotConfig.Brainrots[#BrainrotConfig.Brainrots]
end

-- Get a guaranteed mythic brainrot (for mythic pity)
function BrainrotConfig.getGuaranteedMythicBrainrot()
	local pool = {}
	for _, b in ipairs(BrainrotConfig.Brainrots) do
		if b.Rarity >= BrainrotConfig.PityConfig.Mythic.MinRarity then
			table.insert(pool, b)
		end
	end
	if #pool > 0 then return pool[math.random(1, #pool)] end
	return BrainrotConfig.Brainrots[#BrainrotConfig.Brainrots]
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

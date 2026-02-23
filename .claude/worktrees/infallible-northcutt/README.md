# Aura - Roblox Brainrot Spinner Game

A Roblox game where players spin a wheel to collect rare brainrots and earn money!

## Features

- **10 Unique Brainrots** with different rarities (1/10 to 1/10,000)
- **Text Cycling Animation** - Names rapidly cycle through in the center of the screen
- **Money System** - Each brainrot gives you money based on its rarity
- **Clean UI** - Simple, centered display with color-coded text
- **Pity System** - Guaranteed rare drop (1/1000+) after 2000 spins
- **Near-Miss Mechanic** - Sometimes shows rare brainrots just before the result to keep you spinning!
- **Live Pity Counter** - Track your progress toward the next guaranteed rare in the top-right

## Brainrots & Rarities

| Brainrot | Rarity | Money Reward |
|----------|--------|--------------|
| Skibidi Toilet | 1/10 | $50 |
| Sigma Male | 1/25 | $150 |
| Ohio Moment | 1/50 | $300 |
| Grimace Shake | 1/100 | $750 |
| Giga Chad | 1/250 | $2,000 |
| Mewing Master | 1/500 | $5,000 |
| Fanum Tax | 1/1,000 | $12,500 |
| Rizz God | 1/2,500 | $35,000 |
| Kai Cenat | 1/5,000 | $100,000 |
| GYATT OMEGA | 1/10,000 | $500,000 |

## Setup

1. Install [Rojo](https://rojo.space/) if you haven't already
2. Build the project: `rojo build -o "Aura.rbxlx"`
3. Open the place file in Roblox Studio
4. Start Rojo server: `rojo serve`
5. Test the game!

## Customization

### Adding Images
To add custom images for each brainrot:
1. Upload your images to Roblox as Decals/Images
2. Copy the asset IDs
3. Edit `src/shared/BrainrotConfig.luau` and replace the `ImageId` values

Example:
```lua
ImageId = "rbxassetid://1234567890"
```

### Modifying Rarities
Edit the `Rarity` values in `src/shared/BrainrotConfig.luau`:
```lua
{
    Name = "My Custom Brainrot",
    Rarity = 100,  -- 1/100 chance
    MoneyReward = 1000,
    -- ...
}
```

### Adding More Brainrots
Add new entries to the `BrainrotConfig.Brainrots` table in `src/shared/BrainrotConfig.luau`.

### Adjusting Pity System
Edit the pity configuration in `src/shared/BrainrotConfig.luau`:
```lua
BrainrotConfig.PityConfig = {
    Enabled = true,
    PityThreshold = 2000,  -- Change this number
    MinRarityForPity = 1000  -- Only brainrots with rarity >= this count for pity
}
```

### Adjusting Near-Miss Effect
Edit the near-miss configuration in `src/shared/BrainrotConfig.luau`:
```lua
BrainrotConfig.NearMissConfig = {
    Enabled = true,
    Chance = 0.25,  -- 25% chance (0.0 to 1.0)
    MinRarityToShow = 500  -- Only show rare brainrots with rarity >= this
}
```

## File Structure

```
src/
├── client/
│   ├── init.client.luau    # Client entry point
│   └── SpinUI.luau          # UI controller
├── server/
│   ├── init.server.luau    # Server entry point
│   └── SpinHandler.luau     # Spin logic & data
└── shared/
    └── BrainrotConfig.luau  # Brainrot definitions
```

## How It Works

1. **Client**: Player clicks the "SPIN!" button
2. **Client → Server**: Client sends spin request via RemoteEvent
3. **Server**:
   - Checks pity counter (guarantees rare after 2000 rolls)
   - Generates random brainrot based on weighted probability
   - Determines if near-miss effect should trigger (25% chance)
   - Updates player money, inventory, and pity counter
4. **Server → Client**: Sends result with near-miss info and pity data
5. **Client**:
   - Shows center display frame
   - Rapidly cycles through brainrot names
   - Shows near-miss brainrot just before the result (if triggered)
   - Lands on the final result
   - Displays money reward with fade-in animation
   - Shows "SO CLOSE!" message if near-miss
   - Updates pity counter display

## Game Psychology Features

### Near-Miss Effect
The game implements a "near-miss" mechanic where players occasionally see a super rare brainrot flash by just before landing on the actual result. This creates a feeling of "I was so close!" and encourages continued play.

- Triggers 25% of the time on non-rare drops
- Shows rare brainrots (1/500+) just before the result in the cycle
- "SO CLOSE TO [NAME]!" message appears after the spin
- Message pulses 3 times for emphasis

### Pity System
Prevents player frustration with bad RNG by guaranteeing progress:
- Counter starts at 0 and increments with each spin
- Resets when player naturally gets a rare drop (1/1000+)
- At 2000 spins, guarantees a random rare brainrot
- Visual feedback: counter turns orange at 50%, red at 80%
- Creates a sense of guaranteed progress

## Next Steps

- Add DataStore persistence to save player progress
- Add sound effects for spinning and winning
- Add particle effects for rare spins
- Add trading system between players
- Add collection/inventory UI to view all brainrots
- Add achievements and milestones

## Notes

- Money is currently stored in memory - add DataStores for persistence!
- Asset IDs are placeholder (0) - replace with actual uploaded images
- FilteringEnabled is on for security
- Uses proper client-server architecture with RemoteEvents
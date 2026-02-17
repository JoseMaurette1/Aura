# Aura - Roblox Brainrot Game

## Project Overview
A Roblox game where players spin a wheel to collect different "brainrots" with varying rarities and rewards.

## Project Structure
- **src/client/** - Client-side scripts (UI, animations, local logic)
- **src/server/** - Server-side scripts (game logic, data handling)
- **src/shared/** - Shared modules (configurations, utilities)

## File Responsibilities
- `src/client/init.client.luau` — Entry point; requires and inits SpinUI, InventoryController, RollController in that order
- `src/client/SpinUI.luau` — Handles spin animation (5s cycling), fires SpinRemote, receives result, calls InventoryController.addItem after shake
- `src/client/InventoryController.luau` — Manages inventory grid, SelectedAura panel, item selection, and delete
- `src/client/RollController.luau` — Handles pity counter on RollButton, shakes button at pity threshold
- `src/server/SpinHandler.luau` — Listens for SpinRemote, runs weighted random roll, fires result back to client
- `src/server/init.server.luau` — Server entry point
- `src/shared/BrainrotConfig.luau` — All brainrot definitions plus weighted roll, pity, and near-miss helpers

## Tech Stack
- Roblox Luau
- Rojo for project management
- Client-Server architecture with FilteringEnabled

## ScreenGui Hierarchy (relevant nodes)
```
ScreenGui
├── RollButton          -- spin trigger; has Pity TextLabel child
├── SpinningFrame       -- center-screen spin result display
│   ├── BrainrotName    -- TextLabel with BrainrotNameStroke child
│   └── BrainrotRarity  -- TextLabel with BrainrotRarityStroke child
├── AuraButton          -- opens InventoryGUI
└── InventoryGUI
    ├── InventoryHeader
    │   └── ExitButton
    ├── InventoryArea
    │   └── ItemsScroll         -- ScrollingFrame; items added here dynamically
    │       └── (Frame)*        -- each item frame (created by InventoryController.addItem)
    │           ├── ItemButton  -- ImageButton (full size, image = brainrot.ImageId)
    │           ├── RarityBar   -- ImageLabel (thin colored strip at bottom)
    │           └── ItemName    -- TextLabel (name in rarity color)
    └── SelectedAura
        ├── BrainrotPic     -- ImageLabel; shows selected brainrot image
        ├── SelectedName    -- TextLabel; shows selected brainrot name
        ├── SelectedRarity  -- TextLabel; shows "1 in X"
        └── DeleteButton    -- removes selected item from inventory
```

## Brainrot Data Structure
```lua
{
  Name: string,
  Rarity: number,        -- 1-in-X chance
  MoneyReward: number,
  Description: string,
  ImageId: string,       -- "rbxassetid://..." (all currently rbxassetid://0)
  Color: Color3          -- rarity-tier color used for text and UI accents
}
```

## Rarity Tiers
| Tier      | Rarity Range   | Color  |
|-----------|----------------|--------|
| Common    | 1/10 – 1/25    | White  |
| Uncommon  | 1/50 – 1/100   | Green  |
| Rare      | 1/250 – 1/1000 | Purple |
| Legendary | 1/2500–1/5000  | Gold   |
| Mythic    | 1/10000+       | Red    |

## Implemented Features
### Spin Flow
- RollButton click → fires SpinRemote to server → server does weighted roll → fires result back
- Client animates 5s cycling through random brainrots, slowing down, then snaps to result
- Land punch animation (TextSize bounce) then frame shake
- After shake: result added to inventory via InventoryController.addItem

### Inventory
- Items stored as Frames in ItemsScroll; each frame has brainrot data stored as Instance Attributes
- Clicking an item selects it (gold UIStroke border) and populates the SelectedAura panel
- Clicking the same item deselects it and clears the SelectedAura panel
- DeleteButton removes the selected frame from the grid and clears the panel
- Closing the inventory clears the current selection

### Pity System (RollController)
- Tracks clicks since last reset (PITY_MAX = 10 in dev, 2000 in production config)
- At pity: button turns green and shakes until next click resets it
- RollButton.Active = false during spin to prevent double-clicking

### Near-Miss (configured, not yet wired to UI)
- 25% chance, only for non-rare drops
- Config lives in BrainrotConfig.NearMissConfig

## Code Style
- Use .luau file extension
- PascalCase for services, classes, and module tables
- camelCase for variables and functions
- Store per-instance data on Frames using Instance:SetAttribute / :GetAttribute
- Use task.spawn for async UI setup inside init() to avoid yielding the main thread

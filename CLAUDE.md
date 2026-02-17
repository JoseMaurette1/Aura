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
- `src/client/InventoryController.luau` — Manages inventory grid, SelectedAura panel, item selection, delete, and equip/unequip
- `src/client/RollController.luau` — Handles pity counter on RollButton, shakes button at pity threshold
- `src/server/SpinHandler.luau` — Listens for SpinRemote, runs weighted random roll, fires result back to client
- `src/server/PetController.luau` — Listens on EquipRemote; clones model from ServerStorage, anchors all parts, runs Heartbeat follow loop beside player's HRP
- `src/server/init.server.luau` — Server entry point; loads SpinHandler then PetController
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
        ├── Frame               -- inner container for the display panel
        │   ├── BrainrotPic     -- ImageLabel; shows selected brainrot image
        │   ├── SelectedName    -- TextLabel; shows selected brainrot name
        │   └── SelectedRarity  -- TextLabel; shows "1 in X"
        ├── EquipButton         -- TextButton/ImageButton; fires EquipRemote; label toggles "Equip"/"Unequip"
        └── DeleteButton        -- TextButton/ImageButton; removes selected item from inventory
```

> **Important:** `EquipButton` and `DeleteButton` must be **direct children** of `SelectedAura` (not inside `Frame`). `BrainrotPic`, `SelectedName`, and `SelectedRarity` must be inside the `Frame` child. The code's `WaitForChild` paths depend on this exact layout.

## Brainrot Data Structure
```lua
{
  Name: string,
  Rarity: number,        -- 1-in-X chance
  MoneyReward: number,
  Description: string,
  ImageId: string,       -- "rbxassetid://..." (all currently rbxassetid://0)
  Color: Color3,         -- rarity-tier color used for text and UI accents
  ModelName: string,     -- exact folder name in ServerStorage/Brainrots/; nil if no model yet
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
- Clicking an item selects it (rarity-colored UIStroke border) and populates the SelectedAura panel
- Clicking the same item deselects it and clears the SelectedAura panel
- DeleteButton destroys the selected frame first, then clears the panel (order matters — panel clear must come after destroy to avoid errors blocking it)
- If the deleted item is equipped, fires `EquipRemote` with `nil` to unequip on server before destroying
- Closing the inventory clears the current selection

### Equip / Pet System
- EquipButton fires `EquipRemote` to server with the brainrot's `Name`; label toggles "Equip"/"Unequip"
- `equippedFrame` tracked locally for button state; equipped item gets an "EQUIPPED" badge overlay
- Server (`PetController`) clones the model from `ServerStorage/Brainrots/<ModelName>`, force-anchors all parts (`Anchored = true`, `CanCollide = false`), parents to Workspace
- Heartbeat loop lerps the clone's pivot to float beside the player's HRP (`PET_SIDE_DISTANCE = 5`, `PET_FLOAT_HEIGHT = 3`, `PET_FOLLOW_SPEED = 8`)
- Pet is cleaned up on unequip, re-equip, or player disconnect

### Pity System (RollController)
- Tracks clicks since last reset (PITY_MAX = 10 in dev, 2000 in production config)
- At pity: button turns green and shakes until next click resets it
- RollButton.Active = false during spin to prevent double-clicking

### Near-Miss (configured, not yet wired to UI)
- 25% chance, only for non-rare drops
- Config lives in BrainrotConfig.NearMissConfig

## Pet / Model System

### Storage Architecture
- **`ServerStorage/Brainrots/`** — Master copy of every brainrot model lives here (server-only, invisible to clients, unexploitable).
- **`Workspace`** — When a player equips a brainrot, the server clones its model from ServerStorage and parents the clone into Workspace.
- Models in `ServerStorage/Brainrots/` must be named **exactly** to match the `ModelName` field in BrainrotConfig.
- Each model must have a **PrimaryPart** set so `PivotTo` works correctly.
- **Do NOT pre-anchor parts in Studio** — `PetController` force-anchors and disables collision on every `BasePart` at spawn time. Pre-anchoring in Studio is fine but the code handles it either way.

### BrainrotConfig Fields
- `ModelName: string` — exact folder name in `ServerStorage/Brainrots/` used for model lookup.
- `ModelName = nil` means no model exists yet; equip button should be hidden/disabled for that item.

### RemoteEvents
- **`EquipRemote`** (in `ReplicatedStorage/RemoteEvents/`) — Client fires `(brainrotName: string)` to equip, or `nil` to unequip. Created by PetController on server startup.

### Rojo Project Mapping
- `ServerStorage/Brainrots/` is **not** managed by Rojo file sync — models are placed directly in Studio and saved with the place file. Only scripts under `src/` are synced via Rojo.

## Robux Shop
### Skip Spin Animation — 150 Robux
- One-time purchase via Roblox's MarketplaceService (Developer Product or GamePass, TBD)
- When owned: clicking RollButton skips the 5s cycling animation entirely
- Result is resolved server-side as normal, then immediately displayed (snap straight to result + punch animation + shake), bypassing all intermediate cycling frames
- `SpinUI` must check a `playerOwnsSkip` flag before starting the animation loop; if true, jump directly to the result display step
- Ownership should be verified server-side and communicated to the client via a RemoteFunction or stored as a player attribute on join
- Pity counter and all other game logic remain unaffected

## Implementation Philosophy

### UI / GUI — Always use Roblox Studio
Any visual element that can be built in Studio **must** be built in Studio, not in code. This produces better results and is faster to iterate on.

**Do in Studio:**
- All ScreenGui layouts, frames, buttons, labels, and their visual properties (size, position, color, font, transparency, corner radius, padding, etc.)
- BillboardGuis, SurfaceGuis, and any world-space UI
- Static UI hierarchy — if a frame always exists, build it in Studio
- Animations done via AnimationEditor or Tweens triggered from code but designed visually first

**Do in code:**
- Dynamically created UI that cannot exist at edit time (e.g. inventory item frames spawned per roll result, equipped badges added at runtime)
- Reading/writing UI state (`.Text`, `.Visible`, `.Image`, colors driven by data)
- Connecting events (`.MouseButton1Click`, `.Changed`, etc.)
- Tweens and programmatic animations that respond to gameplay events
- Anything driven by server data or player actions

**When a new UI feature is needed:** always tell the user what to build in Studio first (hierarchy, element names, properties), then write only the code that wires it up. Never recreate in code what Studio can do visually.

## Code Style
- Use .luau file extension
- PascalCase for services, classes, and module tables
- camelCase for variables and functions
- Store per-instance data on Frames using Instance:SetAttribute / :GetAttribute
- Use task.spawn for async UI setup inside init() to avoid yielding the main thread

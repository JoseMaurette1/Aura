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

### Currency & Progression System
**Rarity-Based Money Rewards (per drop)**
- Common (rarity ≤ 25): +1 money
- Uncommon (rarity ≤ 100): +3 money
- Rare (rarity ≤ 1000): +15 money
- Legendary (rarity ≤ 5000): +75 money
- Mythic (rarity > 5000): +300 money

Money is awarded immediately on spin, regardless of inventory duplication. The reward is based on rarity tier, not the unused `MoneyReward` field in BrainrotConfig.

**Rebirth (Prestige) System**
- Rebirth cost scales exponentially: `cost = floor(100 * 1.5 ^ rebirthCount)`
  - 0 → 1: 100, 1 → 2: 150, 2 → 3: 225, ... 10 → 11: ~5,766
- Rebirth **resets money to 0** (intentional sacrifice—players commit to the prestige choice)
- Rebirth increments `rebirthCount` and unlocks better luck on next spins
- UI shows current money / next rebirth cost and luck multipliers (before → after)

**Luck Cap**
- `getLuck(rebirthCount)` is capped at 6.0x to prevent late-game triviality
- Even at very high rebirth counts, luck multiplier will never exceed 6.0x
- Rebirth remains valuable for cost-of-rebirth milestones (badges, cosmetics in future) and for bragging rights

**Endgame Goals** (documented, not yet implemented)
- **Primary**: Collect all brainrots (Brainrot Dex complete)
- **Secondary**: Reach rebirth milestone (target TBD, e.g. 25 or 50)

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

### Multiple Equip — TBD Robux (idea)
- Allows equipping 2+ brainrots simultaneously instead of just 1
- Each equipped brainrot contributes its full money bonus per spin
  - Example: Equip one Legendary (75 money) + one Rare (15 money) = 90 money per spin
- UI: SelectedAura panel shows all equipped items (or a dedicated "Equipped" list)
- On server: `DataManager.getEquippedBrainrot()` returns array instead of single value; money reward calculation sums all equipped bonuses
- Implement multi-equip slot limit (e.g., max 3-5 equipped at once) to maintain balance

## UI Color Palette

These are the **only** color schemes used across the project. Never introduce purple, violet, lavender, or any other color not listed here — purple is a common AI-generated default and is explicitly banned.

### Established Colors

| Role | Color | RGB |
|------|-------|-----|
| **Green — primary panels/headers** | Medium green | `RGB(45, 155, 85)` |
| **Green — panel background** | Mint / light green | `RGB(200, 235, 215)` |
| **Green — gradient top** | Bright mint | `RGB(215, 245, 228)` |
| **Green — gradient bottom** | Deeper mint | `RGB(185, 225, 205)` |
| **Green — action button** | Vivid green | `RGB(55, 180, 100)` |
| **Blue — panel background** | Light sky blue | `RGB(195, 228, 255)` |
| **Blue — header/accent** | Medium blue | `RGB(80, 160, 230)` |
| **Blue — settings** | Solid blue | `RGB(44, 128, 255)` |
| **Red — destructive / exit** | Vivid red | `RGB(200, 50, 70)` |
| **White text** | Labels on dark/colored backgrounds | `RGB(255, 255, 255)` |
| **Dark text** | Labels on light backgrounds | `RGB(25, 90, 50)` (dark green) |

### Rules
- **SpinningFrame** uses the dark semi-transparent overlay style (no color tint — neutral dark)
- **InventoryGUI** uses the green scheme
- **CodesGUI** uses the blue scheme
- **SettingsGUI** uses the blue scheme (`RGB(44, 128, 255)`)
- **All exit buttons** are red (`RGB(200, 50, 70)`) with a gradient
- **All delete buttons** are red (`RGB(200, 50, 70)`)
- **All confirm/equip/yes buttons** are green (`RGB(55, 180, 100)`)
- **Never use purple, violet, or lavender anywhere in the UI**

---

## Implementation Philosophy

### Rojo Workflow — How Code Changes Are Made
This project uses **Rojo** to sync files from disk into Roblox Studio. This is the single most important thing to understand about the dev workflow.

**The golden rule: all script changes happen on disk, never inside Studio's script editor.**

- All `.luau` files live under `src/` on disk. Rojo watches this folder and syncs changes into Studio automatically.
- **Never edit scripts inside Studio's script editor.** The next Rojo sync will overwrite any Studio-side edits with the disk version, losing your work.
- When creating a **new script**, create the `.luau` file in the correct `src/` subdirectory on disk. If needed, update `default.project.json` to map it to the right Studio location, then Rojo will sync it in.
- When Claude writes or edits code, it edits the files on disk (`src/`). Rojo handles getting them into Studio.
- **Non-script instances** (Frames, Buttons, Models, etc.) are NOT managed by Rojo — they live in the `.rbxl` place file and are built/edited directly in Studio.

**What Rojo manages (disk → Studio):**
- Everything under `src/client/`, `src/server/`, `src/shared/`
- Mapped via `default.project.json`

**What Rojo does NOT manage (Studio only):**
- All ScreenGui UI hierarchy (Frames, Buttons, Labels, etc.)
- `ServerStorage/Brainrots/` models
- Any other non-script instances placed in Studio

---

### UI / GUI — Always use Roblox Studio
Any visual element that can be built in Studio **must** be built in Studio, not in code. This produces better results and is faster to iterate on.

**Do in Studio:**
- All ScreenGui layouts, frames, buttons, labels, and their visual properties (size, position, color, font, transparency, corner radius, padding, etc.)
- BillboardGuis, SurfaceGuis, and any world-space UI
- Static UI hierarchy — if a frame always exists, build it in Studio
- Animations done via AnimationEditor or Tweens triggered from code but designed visually first

**Do in code (on disk via Rojo):**
- Dynamically created UI that cannot exist at edit time (e.g. inventory item frames spawned per roll result, equipped badges added at runtime)
- Reading/writing UI state (`.Text`, `.Visible`, `.Image`, colors driven by data)
- Connecting events (`.MouseButton1Click`, `.Changed`, etc.)
- Tweens and programmatic animations that respond to gameplay events
- Anything driven by server data or player actions

**When a new UI feature is needed:** tell the user what to build in Studio first (hierarchy, element names, properties), then write only the code that wires it up on disk. Never recreate in code what Studio can do visually.

## Code Style
- Use .luau file extension
- PascalCase for services, classes, and module tables
- camelCase for variables and functions
- Store per-instance data on Frames using Instance:SetAttribute / :GetAttribute
- Use task.spawn for async UI setup inside init() to avoid yielding the main thread

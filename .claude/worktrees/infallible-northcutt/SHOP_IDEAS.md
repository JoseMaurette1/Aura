# Shop Ideas

## VIP
- **Price:** 450 Robux
- **Perk:** 2x Luck on all Pulls
- VIP players get double the luck boost at pity instead of the normal rate

---

## 2x Luck
- **Price:** 199 Robux
- **Perk:** 2x Luck on the 10th pull
- VIP players get double the luck boost at pity instead of the normal rate

---

## Starter Pack
- **Price:** 200 Robux
- **Contains:** 3 brainrots
- **Rarity:** ~1/1000 each (placeholder)

---

## OP Pack
- **Price:** 300 Robux
- **Contains:** 3 brainrots
- **Rarity:** ~1/100,000 each

---

## Auto Click
- **Price:** 150 Robux
- **Contains:** AFK Auto Clicker

---

## Robux Shop
### Skip Spin Animation — 150 Robux
- One-time purchase via Roblox's MarketplaceService (Developer Product or GamePass, TBD)
- When owned: clicking RollButton skips the 5s cycling animation entirely
- Result is resolved server-side as normal, then immediately displayed (snap straight to result + punch animation + shake), bypassing all intermediate cycling frames
- `SpinUI` must check a `playerOwnsSkip` flag before starting the animation loop; if true, jump directly to the result display step
- Ownership should be verified server-side and communicated to the client via a RemoteFunction or stored as a player attribute on join
- Pity counter and all other game logic remain unaffected

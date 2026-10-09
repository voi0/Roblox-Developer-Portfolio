# 🌟 STARWEAVE: Visual & Technical Showcase
### Flagship Systems Architecture & UI/UX Demonstration by Yassein ([@intradient](https://www.roblox.com/search/users?keyword=intradient))

Welcome to the visual and systems breakdown of **STARWEAVE**, a cosmic gardening and exponential RNG mutation game built entirely with production-grade Luau standards, server-authoritative networking, and custom glassmorphism interfaces.

---

## 🏛️ 1. Environmental Architecture & 3D Spatial Design

The world of STARWEAVE is engineered as a pure 3D cosmic sanctuary featuring custom high-detail models and spatial composition:

- **Central Sanctuary Deck:** Solid circular stone deck (96x2x96 studs) anchored over a floating sanctuary island rock.
- **Cobblestone Grand Promenade:** Clear, central walkway leading directly from the arrival dais to the Sacred Altar.
- **Symmetrical Flanking Gardens:** Two 4-plot garden wings with 10-stud spacing flanking a 28-stud wide central avenue, with a centerpiece plot framing the altar approach.
- **Sacred Transmutation Altar:** Ornate 3D altar equipped with glowing runes, server proximity prompts, and dynamic point lights.
- **Bioluminescent Foliage:** Custom Weeping Willow trees framing the perimeter corners with color-coded foliage and ambient spore lights.
- **Satellite Islands & Crystalline Bridges:** East Market Satellite (Gazebo & Stardust Well) and West Shrine Satellite (Mystery Egg & Companion Pets) connected via walkable crystal bridges.

---

## 🎨 2. Cosmic Glassmorphism UI/UX Suite

All interfaces in STARWEAVE are built through a centralized token engine ([`UILib.luau`](../src/client/UI/UILib.luau)), ensuring 100% visual consistency and responsive ergonomics:

### A. The HUD & Navigation
- **TopBar Banner:** Right-anchored floating container safely clear of Roblox CoreGui and chat messages, featuring a live Player Profile card, real-time currency capsules (Stardust, Gems, Starlight), and dynamic cosmic multiplier pills.
- **Bottom Navigation Dock:** Chunky candy-styled floating dock with 7 core action buttons (`CODEX`, `STARS`, `FORGE`, `PETS`, `GUESTS`, `TRANSCEND`, `SHOP`) with responsive spring hover states and audio triggers.
- **Objective Tracker:** Sleek quest banner anchored mid-left displaying real-time objectives, progress bars, and reward previews.

### B. Specialized Modal Windows
- **Seed Shop Modal:** Multi-tier seed catalog with tier pill badges, dynamic buy buttons, and stock counters.
- **Sacred Altar (Forge) Modal:** 3:1 seed transmutation system with circular glowing altar preview, animated transformation indicators, and instant inventory refresh.
- **Transcendence (Rebirth) Modal:** Side-by-side progression comparison cards ("Current Level" vs "After Transcendence"), stardust progress bars, and reward badges.
- **Pet & Codex Modals:** Clean multi-slot grids with rarity coloring and real-time multiplier previews.

---

## ⚙️ 3. Core Server Systems & Security

### Zero-Trust Networking
- All mutations, currency transactions, seed purchases, and plot harvests are **100% server-authoritative**.
- The client merely sends *intent* requests via `RemoteFunction` and `RemoteEvent` boundaries; the server validates timestamps, ownership, balances, and cooldowns before mutating state.

### Enterprise Data Persistence
- Built on top of **ProfileService** with multi-server session locking.
- Schema migrations ensure that adding new currencies, pets, or plots never corrupts existing player data.
- Built-in Studio mock fallback allows development offline without touching live production DataStores.

### Exponential RNG Mutation Engine
- 7-tier mutation distribution with compound luck scaling:
  - `Common` → `Uncommon` → `Rare` → `Epic` → `Celestial` → `Cosmic` → `Primordial` (up to 500x multiplier).
- Mathematical curves calibrated for high retention and active engagement.

---

## 📁 Key File Directory Reference

| Component | File Path | Focus Area |
| :--- | :--- | :--- |
| **World Architecture** | [`src/server/Services/WorldService.luau`](../src/server/Services/WorldService.luau) | 3D procedural positioning & model integration |
| **Data Persistence** | [`src/server/Services/DataService.luau`](../src/server/Services/DataService.luau) | ProfileService wrapper & session locking |
| **Garden Simulation** | [`src/server/Services/GardenService.luau`](../src/server/Services/GardenService.luau) | Growth timers, harvesting, and seed forging |
| **Mutation Math** | [`src/server/Services/MutationService.luau`](../src/server/Services/MutationService.luau) | Exponential RNG rolls & luck calculations |
| **Economy & DevProducts** | [`src/server/Services/EconomyService.luau`](../src/server/Services/EconomyService.luau) | Idempotent `ProcessReceipt` monetization |
| **UI Design System** | [`src/client/UI/UILib.luau`](../src/client/UI/UILib.luau) | Design tokens, factory functions, and animations |
| **HUD Controller** | [`src/client/UI/HUDController.luau`](../src/client/UI/HUDController.luau) | Live HUD rendering, profile cards, and dock |

---

## 📬 Contact Yassein

- **Roblox Profile:** [@intradient](https://www.roblox.com/search/users?keyword=intradient)
- **Discord:** Available via direct message (`intradient` / `yassein`)
- **GitHub:** [@voi0](https://github.com/voi0)

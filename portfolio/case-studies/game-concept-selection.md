# 📊 Case Study: Data-Driven Game Concept Selection
## How I Used Market Research to Design a Hybrid Simulator for Maximum ROI

**Author:** Yassein Shehata  
**Date:** September 2026  
**Methodology:** Multi-source market analysis across player psychology, genre economics, platform algorithm mechanics, and viral content patterns

---

## The Challenge

Select a game concept for the Roblox platform that satisfies:
1. Solo developer feasibility (minimal 3D art, maximal code/math)
2. High monetization ceiling (target: 5+ ARPDAU)
3. Strong 28-day retention (target: D1 18%+, D7 4%+, D30 1.5%+)
4. TikTok-native virality potential
5. Alignment with the 2026 Roblox recommendation algorithm

## Research Process

Conducted parallel analysis across 5 domains:
- **Player Psychology** — Demographics, spending triggers, retention drivers
- **Front Page Analysis** — Top 30 games by CCU, genre distribution, new entrant patterns
- **Monetization Economics** — ARPDAU benchmarks, Creator Rewards system, whale economics
- **Genre Evolution** — 2024→2026 trend mapping across RNG, Idle, Simulator, and Tycoon categories
- **Virality Patterns** — TikTok content formats, devlog hooks, Clip It integration

## Key Findings

### Critical Discovery: Platform Monetization Shift
Identified that the legacy "Premium Payouts" system had been replaced by "Creator Rewards" — a fundamentally different economic model that invalidates AFK-first design strategies. This finding pivoted the entire game concept away from session-time optimization toward active-engagement monetization.

### Genre Hybridization Trend
The #1 pattern among 2026 breakout hits is combining 2-3 proven mechanics into a novel experience:
- Growth/Farming loops (from Grow a Garden)
- RNG/Mutation chase mechanics (from Sol's RNG)
- Incremental rebirth depth (from Grass Cutting Incremental)

## The Decision: STARWEAVE — Growth-RNG Hybrid Simulator

Selected a concept that combines the three highest-performing solo-dev-friendly mechanics on the platform into a cosmic garden simulator with RNG mutations and infinite prestige scaling.

### Technical Architecture
- **Server-authoritative economy** with ProfileService
- **Modular service architecture** (EconomyService, GardenService, MutationService, ProgressionService)
- **Grid-based garden system** with procedural growth calculations
- **Exponential rebirth math** with unfolding prestige trees

### Monetization Design
- 6 Gamepasses ranging from 49 R$ (barrier breaker) to 1,499 R$ (whale anchor)
- 6 Developer Products for repeatable purchases
- Native subscription tier at $4.99/month
- Projected ARPDAU: 3-8 R$ based on genre benchmarks

---

*This case study demonstrates systems-level thinking, data-driven decision making, and deep understanding of Roblox platform economics.*

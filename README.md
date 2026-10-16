# Pocket Station

A tense pocket dungeon crawler built with Godot 4.4.1, hosted via GitHub Pages.
Each monster shows a level. Beat monsters weaker than you (green) to level up; stronger or equal ones (red) kill you.
Reach the exit gate's level before the dark eats the board from the edges.

- `index.*` at the repo root is the exported web build (no-threads variant, GL Compatibility, 720x1280 portrait).
- `godot-project/` is the Godot project source. Themes are data in `_make_themes()` in `main.gd`; a new theme starts every 3 floors. Boards grow 6x6 -> 7x7 -> 8x8. All art is generated in code. Mechanics: level-or-die fights, gold-star elites (+2), shield, spikes, lanterns, portals, walls, coins, boss at the gate. Add `?floor=5` to the URL to start on a later floor. The gate is always in the innermost ring (never eaten by the dark). RESET restarts the same map. Music and sound effects are synthesized in code.

## Rebuild

```
godot --headless --path godot-project --import
godot --headless --path godot-project -- --test      # checks the generator always makes winnable floors
godot --headless --path godot-project --export-release "Web"
```

The web export needs the `web_nothreads_release` template for 4.4.1.

## Depth systems
- **Relics:** after every floor clear you pick 1 of 3 run-long relics (Vanguard, Slow Dark, Aegis, Heavy Boots, Midas Touch, Phoenix Feather, Lantern Bearer, Skeleton Key, Alchemist). Defined in `_make_defs()`.
- **Monster abilities:** sleepers (+3 level once the dark first advances), feeders (+1 level per ring of dark), thieves (steal coins when you stand beside them; beat them to get coins back). The solver models all of these, so floors stay winnable.
- **Shop:** coins are banked on death and buy permanent upgrades (Veteran, Iron Will, Packed Shield, Lucky Finds). Saved in `user://best.cfg`.
- Dev URLs: `?floor=5`, `?demo=relic`, `?demo=shop`.
- **Scaling:** monster levels grow with depth (`_scaled()`), keep pace with 70% of your permanent power (Veteran + Vanguard), more monsters appear on deeper floors, the dark speeds up every 3 floors, sleepers get stronger, and gates ask for a larger share of the board.

## v5 systems
- **Classes** (Scout, Brute, Mystic, Gambler) chosen at the start of each run.
- **Relics** now include cursed ones (Glass Cannon, Greedy Pact, Hungry Blade, Ember Lantern) mixed with normal ones, plus synergies between some pairs.
- **Tools** (2-4 slots): Bomb, Time Crystal, Blink Scroll, Shadow Cloak, Elixir, Magnet, Pickaxe, Zap Rod. Found on floors, in vaults, from the Merchant, or as class kits. The generator never relies on them, so floors stay winnable without them.
- **Paths:** after each floor choose a door: Steady, Perilous, Quiet, Vault or Merchant.
- **Boss floors** every 5th floor (colossus / king / warden rules).
- **Vaults:** a key on the floor opens a locked vault (+10 coins, +1 level, a free tool).
- Dev URLs: `?floor=5&class=brute`, `?demo=relic|fork|market|shop`.

## v6
- Relic screen has a SKIP button (+3 coins), so cursed relics are never forced.
- Shop is paged (6 per page) with 10 new permanent upgrades: Deep Pockets, Treasure Hunter, Lantern Oil, Toolbox, Gate Whisperer, Steel Boots, Haggler, Head Start, Phoenix Ash, Interest.
- Class screen has a two-tap RESET ALL PROGRESS button (wipes bank, upgrades, best).

## v7: Adventure mode
- New mode selector before class select: **Puzzle** (the original) and **Adventure**.
- Adventure: sprawling rooms-and-corridors station (36x36 growing to 56x56), scrolling camera, tap-to-walk, fog of war (you only see nearby; explored areas are remembered, monsters only show when in sight), a minimap, and an exit that needs X points (kills, coins, items, vaults) before it opens.
- Air replaces the dark: every step costs air, air pods refill it, running out kills you. Leftover air becomes bonus coins. Class/relic/shop "dark" perks are reinterpreted as air/sight/points perks.
- Hunters chase at half speed, thieves steal coins, every 5th floor a boss guards the exit, key + vault rooms, scanners reveal the map.
- Maps are generated so everything is reachable and monsters can always be beaten in ascending order; check with `godot --headless --path godot-project -- --advtest`.
- Dev URL: `?mode=adv&class=scout&floor=N`.

## v8: Adventure combat, O2 stations
- Adventure combat is now health-based: every tap on a monster is one round (you hit for your level + bonuses, it hits back for its level minus your armour). Monsters have HP bars; shield is its own pool that soaks damage first; armour plates and medkits are new pickups. Levels still raise attack and max HP.
- O2 stations (infinite air, step on to refill) are spaced 29+ steps apart so every room is within ~30 steps of one.
- Adventure uses air-themed names (Deep Lungs, Wide Scanner, Air Canister...). Pickaxe removed from Adventure. Reset button removed from both modes (death screen still has Retry).

## v9: XP, persistent levels, inventory
- Adventure: kills, potions, vaults and elixirs give XP; levels persist for the whole run (each level = +1 attack, +3 max HP). Monsters scale with your current level and the floor depth so fights stay costly.
- New BAG button (top right in Adventure) opens an inventory screen with STATS, TOOLS (with USE buttons), RELICS and GEAR tabs. The tool bar stays at the bottom. GEAR has weapon/armour/trinket slots reserved for future items.

## v10: Gear
- Adventure: Phoenix Feather now fully restores health and air instead of restarting the floor.
- 32 pieces of gear in 5 slots (weapon, helmet, armour, boots, trinket) across 4 tiers, with stats like attack, crit, leech, armour, thorns, dodge, max HP, air, air saving, sight, XP, coin and kill-heal bonuses.
- Findable: gear crates in rooms (at least one per floor), elite and boss drops. Buyable: an Outfitter stall in some rooms (step on it, or tap it, to trade). Starter Kit shop upgrade gives starting gear.
- Inventory has GEAR (equipped) and PACK (12 slots, equip or sell for half price) tabs. Monster scaling eased slightly.
- Dev URL: `?mode=adv&class=brute&floor=3&gear=trade` (gives gear and opens the Outfitter).

## v11 – Sprite overhaul
All art is regenerated by `godot-project/sprites.gd` at 32x32 (up from 12-16px): astronaut player with class-specific gear, richer monsters (belly, brows, teeth, spots, crowns for bosses), detailed items, riveted/grated/overgrown floor and wall tiles per theme, and former vector icons (tools, key, vault, spikes, O2 pod/station, merchant stall, gear crates, medkit, armour plate, exit door) are now pixel sprites.

## v12 – Animation pass
- Smooth player and hunter movement (slide, hop, lean, 3-frame walk cycle, facing flip), idle breathing, monster blinking and breathing.
- Combat feedback: slash streaks, white hit-flash silhouettes, knock-back, attack lunges, screen shake, crit rings, red damage vignette, death shrink-and-burst (bigger for elites and bosses).
- Pickups fly to the matching HUD counter; level-up banner and rings; exit door opens with a light burst; tool effects (bomb, zap bolt, blink, air bubbles).
- Fog fades in and out; spinning coins, item glints, O2 station bubbles, per-theme ambient particles (dust, spores, embers). Low-air pulse.
- Dev URL: `?mode=adv&floor=2&demo=fx` triggers a burst of effects for checking.

## v13 – Humanoid aliens, tile variety
- Monsters redrawn as humanoids (head/torso/arms/legs, varied heads, eyes, mouths, crests, per-theme outfits, held items; bosses crowned and caped).
- 16 floor-tile variants per parity per theme (vents, cables, oil, hatches, flowers, mushrooms, rocks, crates, chains...), picked by a coordinate hash so patterns don't repeat in a grid.
- Stars no longer show through the puzzle board; level-up fanfare is adventure-only.

## v14 – How to Play
Mode menu has a HOW TO PLAY button: 8 Puzzle pages and 9 Adventure pages, each illustrated with the real in-game sprites (player classes, monsters with badges and markers, items, tools, gear crates, doors, stations).

## v15 – Leaderboard
LEADERBOARD button under HOW TO PLAY: per-mode (Puzzle / Adventure) top 12 with player names and floors cleared, change-name button. Scores submit on floor clear and death. Needs a free Firebase Realtime Database: see LEADERBOARD_SETUP.md. Until `LB_URL` is set it shows a "not switched on yet" message and the player's own best.

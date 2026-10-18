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

## v16 - armour, medical stations, new tools and gear
- Armour plates no longer cap at 6 (the old cap made total armour stop at 9 with gear).
- New tools: Nano Injector (full heal), Shield Cell, Plating Kit (+1 armour), Pulse Scanner, Ration Pack (adventure only).
- Medical stations (green cross, from floor 2): step on one (or tap it) to open a menu with Quick patch / Half repair / Full heal, each showing the HP gained and the coin cost. Prices rise steeply on deeper floors.
- 31 new gear pieces across all slots and tiers.
- XP potions are now a percent of the current level's XP need (20% / 25% x multipliers); Elixir gives 75%.
- Floor tiles: each theme now uses one plain base tile most of the time, a subtle alternate now and then, and sparse, never-adjacent feature tiles.

## v17 - directions, worn gear, item sprites, spike damage
- Player sprites now exist for 4 directions (down, up, left, right) x 3 walk frames, for every class.
- Every equipped item is drawn on the character (weapon in hand, helmet, armour, boots, trinket), in each direction.
- All 62 gear items have their own sprite (sprites.gd `ART` table); shown on floor pickups, the outfitter, GEAR and PACK tabs.
- Adventure spikes now damage health (scales with floor and level; shield soaks it; Heavy Boots still negate; Steel halves it; Ember doubles it) instead of costing air.

## v18 - Turrets and themed hazards (adventure)
- Two turret types per theme (Laser Sentry / Plasma Cannon, Thorn Shooter / Spore Spitter, Auto Gun / Rocket Rack). They never move, face one of four directions (set at spawn) and shoot 5 tiles down that lane. Sentries fire every step, cannons every other step. Damage equals a monster of their level. They can be fought, zapped or bombed; other monsters block their shots.
- Six hazards: Arc plate (shocks only while lit) and Hull breach (-8 air) on the station; Toxic pool (poison 4 steps, cured by Nano Injector or medical station) and Slick patch (skid one tile) in the jungle; Mine (big blast, hurts nearby monsters) and Alarm gate (wakes nearby monsters into hunters) in the smuggler world. Bombs clear hazards.
- Tutorial pages TURRETS and HAZARDS added.

## v19 - Ranged weapons, corpses, kill behaviour
- Turrets no longer hit back when you attack them; they only damage you when they shoot.
- A killing blow no longer moves you onto the enemy's tile; press again to step there.
- Five ranged weapons (Blaster Pistol, Thorn Crossbow, Arc Carbine, Plasma Rifle, Rail Sniper). Tap a monster in a straight, clear line within range to shoot it (no counter-hit, but the turn still passes). Walking into a monster with one equipped also shoots.
- Every killed enemy leaves a corpse sprite (derived from its own sprite, with a themed pool; wrecked turrets smoulder) that stays on the floor.

## v20 - Ranged balance
- Each shot costs air equal to the weapon's tier (reduced by air-saving gear) instead of a normal step.
- A shot monster that survives starts hunting you (bosses, turrets and thieves excepted).
- Shooting a monster that is adjacent gets hit back like melee (not turrets).
- Shooting lanes are tinted; shootable monsters get a reticle with the air cost, and monsters within range but not lined up get a dim "line up" marker.

## v21 - Gunslinger class
- New fifth class. Puzzle: two Zap Rods, dark 1 step faster. Adventure: starts with a Blaster Pistol equipped and 2 Zap Rods, but has 4 less max health and 10 less air.
- Brown hat and bandolier sprites for all four facings; class cards re-laid out to fit five.

## v22 - Crystal Deep, shooters, facings, gear and relics, sounds
- New world CRYSTAL DEEP (4th; worlds cycle every 3 floors): crystal floor and wall tiles, twinkling ambient, own music, monsters, Crystal Titan boss, turrets (Prism Beam, Shard Launcher) and hazards (Warp pad, Crystal shards).
- Mobile ranged enemies ("shooters", from floor 3): keep their distance, line up with you and fire down a 5-tile lane every other step.
- Monsters now have sprites for all four directions and turn to face you.
- 15 new gear pieces (4 weapons incl. Scatter Gun and Gauss Repeater, helmets, armour, boots, trinkets with new stats: range bonus, shot air saving, ranged damage reduction, hazard resistance).
- 6 adventure relics: Deadeye Scope, Efficient Barrel, Deflector Plating, Hazmat Suit, Grave Robber, Heavy Ammo (cursed).
- New sounds: player shot, turret, enemy shot, arc, hull breach, poison, slide, explosion, alarm, crystal shard, enemy aggro, corpse thud.

## v23 - Ranged tuning
- Monsters you shoot (that were not already hunters/shooters/turrets/bosses) now CHARGE: they move every turn instead of every second turn, so backing away from them no longer works forever.
- Air per shot is 1 for a tier 1 weapon and rises by 0.5 per tier (1, 1.5, 2, 2.5), still reduced by air-saving gear, Efficient Barrel and Ammo Recycler.

## v24 - Gun air cost up 50% more
- Air per shot is now 1.5 / 2.25 / 3 / 3.75 for tier 1-4 weapons (before air-saving gear and relics). Each gun's description states its number.
- v24b: multiplier raised again (x1.5): 2.25 / 3.4 / 4.5 / 5.6 per tier. Tutorial body text shrinks to fit above the PREV/NEXT buttons.
- v24c: multiplier x0.8 (1.8 base): 1.8 / 2.7 / 3.6 / 4.5 air per shot for tiers 1-4.
- v24d: air per shot rounded up to whole numbers: 2 / 3 / 4 / 5 for tiers 1-4.
- v24e: How to Play PREV/NEXT now level with BACK; page number below BACK.
- v25: installable offline PWA (service worker caches the game; Add to Home screen/Install in Chrome).

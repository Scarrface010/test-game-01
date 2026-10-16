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

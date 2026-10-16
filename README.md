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

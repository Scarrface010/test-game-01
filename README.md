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

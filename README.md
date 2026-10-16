# Tap and Tumble

A draw-to-build physics puzzler built with Godot 4.4.1, hosted via GitHub Pages.
Draw beams, bouncers and heavy weights, press GO, and get the ball into the green cup.

- `index.*` at the repo root is the exported web build (no-threads variant, GL Compatibility, 720x1280 portrait).
- `godot-project/` is the Godot project source. Levels live in `_make_levels()` in `main.gd`.

## Rebuild

```
godot --headless --path godot-project --import
godot --headless --fixed-fps 60 --path godot-project -- --test      # checks every level: do-nothing loses, stored solution wins even when nudged
godot --headless --path godot-project --export-release "Web"        # writes ../index.html and friends
```

The web export needs the `web_nothreads_release` template for 4.4.1.

Extra dev tools: `-- --search <level> <ink> <tries> <strokes> [seed]` random-searches solutions, `-- --try <level> <ink> x1 y1 x2 y2 ...` traces one attempt.

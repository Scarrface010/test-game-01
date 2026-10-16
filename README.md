# Tap and Tumble

A tap-to-pop physics puzzler built with Godot 4.4.1, hosted via GitHub Pages.
Tap blocks to remove them and guide the ball into the green cup.

- `index.*` at the repo root is the exported web build (no-threads variant, GL Compatibility, 720x1280 portrait).
- `godot-project/` is the Godot project source. Levels live in `_make_levels()` in `main.gd`.

## Rebuild

```
godot --headless --path godot-project --import
godot --headless --fixed-fps 60 --path godot-project -- --test      # solver: proves every level is winnable and checks par
godot --headless --path godot-project --export-release "Web"        # writes ../index.html and friends
```

The web export needs the `web_nothreads_release` template for 4.4.1.

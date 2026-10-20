extends SceneTree
# godot --headless --path . -s res://tools/player_preview.gd  -> user://player_review.png
func _init() -> void:
	var sg = load("res://sprites.gd").new([])
	var accent := Color("4fd1ff")
	var sets := [
		{}, {"weapon": "katana"}, {"weapon": "plasmarifle"}, {"weapon": "gravhammer"}, {"weapon": "blaster"},
		{"helmet": "hardcap"}, {"helmet": "pilothelm"}, {"helmet": "voidcrown"}, {"helmet": "scholar"},
		{"armour": "kevlar"}, {"armour": "titan"}, {"armour": "jacket"},
		{"boots": "padded"}, {"trinket": "luckychip"},
		{"weapon": "katana", "helmet": "riothelm", "armour": "exo", "boots": "riveted"},
	]
	var out := Image.create(64 * 3 * 3, 64 * sets.size() / 1 + 0, false, Image.FORMAT_RGBA8)
	out = Image.create(64 * 4, 64 * sets.size(), false, Image.FORMAT_RGBA8)
	out.fill(Color(0.18, 0.19, 0.25))
	for r in sets.size():
		var i := 0
		for d in [0, 1, 3, 2]:
			var t = sg.player(accent, "scout", 0, d, sets[r])
			out.blend_rect(t.get_image(), Rect2i(0, 0, 64, 64), Vector2i(i * 64, r * 64))
			i += 1
	out.resize(out.get_width() * 2, out.get_height() * 2, Image.INTERPOLATE_NEAREST)
	out.save_png("/tmp/claude-0/-home-claude/49c68f05-fd6c-5e3b-b947-5d8036b7e973/scratchpad/player_review.png")
	quit()

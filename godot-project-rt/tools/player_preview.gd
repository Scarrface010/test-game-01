extends SceneTree
# godot --headless --path . -s res://tools/player_preview.gd  -> writes the review sheet to PREVIEW_PATH
const PREVIEW_PATH := "/tmp/claude-0/-home-claude/7b5a16eb-60a4-53eb-a998-df3fba14e51f/scratchpad/player_review.png"
func _init() -> void:
	var sg = load("res://sprites.gd").new([])
	var classes := ["scout", "brute", "mystic", "gunslinger", "gambler"]
	var accent := Color("4fd1ff")
	var eq := {"weapon": "katana", "helmet": "hardcap", "armour": "kevlar", "boots": "padded"}
	# rows: 5 classes bare, then 5 classes geared; columns: front, back, side-right, side-left, then walk f1/f2 front and side
	var rows: Array = []
	for c in classes:
		rows.append([c, {}])
	for c in classes:
		rows.append([c, eq])
	var out := Image.create(64 * 8, 64 * rows.size(), false, Image.FORMAT_RGBA8)
	out.fill(Color(0.18, 0.19, 0.25))
	for r in rows.size():
		var cols := [[0, 0], [0, 1], [0, 3], [0, 2], [1, 0], [2, 0], [1, 3], [2, 3]]
		for i in cols.size():
			var t = sg.player(accent, rows[r][0], cols[i][0], cols[i][1], rows[r][1])
			out.blend_rect(t.get_image(), Rect2i(0, 0, 64, 64), Vector2i(i * 64, r * 64))
	out.resize(out.get_width() * 2, out.get_height() * 2, Image.INTERPOLATE_NEAREST)
	out.save_png(PREVIEW_PATH)
	quit()

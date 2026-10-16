extends Control
# Pocket Station - level-or-die pocket dungeon with a creeping dark.
# Beat monsters weaker than you (green badge) to level up; stronger or equal ones (red) kill you.
# Reach the gate's level before the dark eats the board from the edges.
# Extras: gold-star elites (+2), shield (survive one losing fight), spikes (+2 dark steps),
# lanterns, portals, walls, coins. Add "?floor=5" to the URL to start on a later (bigger) floor.

const START_LEVEL := 2
const GX := 40
const GY := 330
const GW := 640.0
enum { PLAY, DEAD, CLEAR }

var themes: Array = []
var font: Font = ThemeDB.fallback_font
var tex_cache: Dictionary = {}

var N := 6
var cell := 106.0
var period := 9
var maxd := 2

var floor_n := 1
var level := START_LEVEL
var moves := 0
var coins := 0
var shield := false
var pos := Vector2i.ZERO
var start := Vector2i.ZERO
var stairs := Vector2i.ZERO
var req := 4
var boss_cell := Vector2i(-1, -1)
var mons: Dictionary = {}     # Vector2i -> int level
var elite: Dictionary = {}    # Vector2i -> true (gold star: +2 levels when beaten)
var items: Dictionary = {}    # Vector2i -> "pot" | "big" | "lamp" | "shield"
var spikes: Dictionary = {}   # Vector2i -> true (stepping on them costs 2 extra steps)
var coin_at: Dictionary = {}  # Vector2i -> true
var walls: Dictionary = {}    # Vector2i -> true
var portals: Dictionary = {}  # Vector2i -> Vector2i (both directions)
var walk: Array[Vector2i] = []
var walk_t := 0.0
var state := PLAY
var msg := ""
var over_title := ""
var over_sub := ""
var best := 0
var t := 0.0
var pops: Array = []
var stars: Array = []
var saved: Dictionary = {}
var snd_on := true
var sfx_cache: Dictionary = {}
var sfx_players: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer
var music_cache: Dictionary = {}
var music_building: Dictionary = {}
var music_theme := -1
var btn_sound := Rect2(20, 20, 104, 46)
var btn_reset := Rect2(596, 20, 104, 46)
var btn_retry := Rect2(160, 810, 400, 84)
var btn_newrun := Rect2(160, 920, 400, 84)

const SR_SFX := 22050
const SR_MUS := 11025


func _ready() -> void:
	randomize()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_make_themes()
	var cfg := ConfigFile.new()
	if cfg.load("user://best.cfg") == OK:
		best = int(cfg.get_value("s", "best", 0))
	var rs := RandomNumberGenerator.new()
	rs.seed = 4242
	for i in 60:
		stars.append([rs.randf() * 720.0, rs.randf() * 1280.0, rs.randf() * 6.28, 1.0 + rs.randf() * 2.0])
	var args := OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("new URLSearchParams(location.search).get('floor')")
		if q != null and int(q) > 0:
			floor_n = int(q)
	if "--test" in args:
		await _self_test()
		get_tree().quit()
		return
	_setup_audio()
	_new_floor()


func _make_themes() -> void:
	themes = [
		{
			"name": "DERELICT STATION", "bg": Color("0b1020"), "tile": Color("18213f"), "tile2": Color("1e2950"),
			"wall": Color("56607f"), "accent": Color("4fd1ff"), "dark": Color("02030a"),
			"mcols": [Color("9be36b"), Color("ffb347"), Color("8fa3c9"), Color("e0e7ff"), Color("c07cff"), Color("ff6f91"), Color("4fd1ff"), Color("ffe066"), Color("ff7b54")],
			"mons": ["Rat-bot", "Drone", "Crawler", "Turret", "Mech", "Warden", "Hunter", "Overseer", "Core AI"],
			"pot": "Power cell", "gate": "Airlock", "boss": "Station Core",
		},
		{
			"name": "OVERGROWN GREENHOUSE", "bg": Color("0c1a12"), "tile": Color("183625"), "tile2": Color("1f4530"),
			"wall": Color("3f6b3a"), "accent": Color("7dff9b"), "dark": Color("020a05"),
			"mcols": [Color("d9f26b"), Color("ff9ecb"), Color("b6e3ff"), Color("ffcf5c"), Color("e56bff"), Color("ff7a5c"), Color("7dffe0"), Color("fff08a"), Color("ff5c8a")],
			"mons": ["Aphid", "Vine", "Beetle", "Spore pod", "Stalker", "Bloom", "Mantis", "Elder root", "Hive heart"],
			"pot": "Nectar", "gate": "Hatch", "boss": "Hive Queen",
		},
		{
			"name": "SMUGGLER HOLD", "bg": Color("1c120c"), "tile": Color("3a2416"), "tile2": Color("472c1b"),
			"wall": Color("8a6a45"), "accent": Color("ffb14f"), "dark": Color("0a0502"),
			"mcols": [Color("b0b0b0"), Color("ff8a5c"), Color("8cc7ff"), Color("ffe08a"), Color("c8a2ff"), Color("ff5c5c"), Color("7dffb0"), Color("ffd0a0"), Color("ff3d7f")],
			"mons": ["Pest", "Cutpurse", "Bruiser", "Gunhand", "Enforcer", "Captain", "Assassin", "Warlord", "Kingpin"],
			"pot": "Medkit", "gate": "Cargo door", "boss": "Crime Lord",
		},
	]


func tidx() -> int:
	return ((floor_n - 1) / 3) % themes.size()


func cur_theme() -> Dictionary:
	return themes[tidx()]


func ring(c: Vector2i) -> int:
	return mini(mini(c.x, c.y), mini(N - 1 - c.x, N - 1 - c.y))


func depth_for(m: int) -> int:
	return mini(m / period, maxd)


func is_dark(c: Vector2i) -> bool:
	return ring(c) < depth_for(moves)


func in_b(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < N and c.y < N


# ---------- sprites (all generated in code) ----------

func _tex_from_rows(rows: Array, pal: Dictionary) -> ImageTexture:
	var h := rows.size()
	var w: int = String(rows[0]).length()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var r: String = rows[y]
		for x in w:
			var ch: String = r[x]
			if pal.has(ch):
				img.set_pixel(x, y, pal[ch])
	return ImageTexture.create_from_image(img)


func _player_tex() -> ImageTexture:
	var key := "player%d" % tidx()
	if tex_cache.has(key):
		return tex_cache[key]
	var rows := [
		"....oooooo....",
		"...owwwwwwo...",
		"..owwwwwwwwo..",
		".owwoooooowwo.",
		".owovvvvvvowo.",
		".owovhhvvvowo.",
		".owovvvvVVowo.",
		".owwoooooowwo.",
		"..owwwwwwwwo..",
		".owlwwrrwwlwo.",
		"owwlwwyywwlwwo",
		"owwlwwwwwwlwwo",
		".owwwwwwwwwwo.",
		"..owwwooowwwo.",
		".obbbo..obbbo.",
		".ooooo..ooooo.",
	]
	var acc: Color = cur_theme()["accent"]
	var pal := {
		"o": Color("10131f"), "w": Color("eef2ff"), "l": Color("aab3d1"), "v": acc, "V": acc.darkened(0.45),
		"h": Color("ffffff"), "r": Color("ff5d5d"), "y": Color("ffd84f"), "b": Color("5a6280"),
	}
	var tx := _tex_from_rows(rows, pal)
	tex_cache[key] = tx
	return tx


func _item_tex(kind: String) -> ImageTexture:
	if tex_cache.has(kind):
		return tex_cache[kind]
	var rows: Array
	var pal: Dictionary = {"o": Color("10131f"), "h": Color("ffffff")}
	if kind == "pot" or kind == "big":
		rows = [
			"....oooo....", "....occo....", "....oggo....", "...oggggo...", "..oyyyyyyo..",
			".oyhhyyyyyo.", ".oyhyyyyyYo.", ".oyyyyyyyYo.", ".oyyyyyyYYo.", "..oyyyYYYo..",
			"...oooooo...", "............",
		]
		pal["c"] = Color("a8743a")
		pal["g"] = Color("cfe6ff")
		pal["y"] = Color("ffd84f") if kind == "pot" else Color("4fd1ff")
		pal["Y"] = Color("e0a92a") if kind == "pot" else Color("2a8fc4")
	elif kind == "lamp":
		rows = [
			"....oooo....", "...o....o...", "..oooooooo..", "..oyyyyyyo..", "..oyhhyyyo..",
			"..oyhwwyyo..", "..oywwwyyo..", "..oyyyyyyo..", "..oooooooo..", "...oggggo...",
			"...oooooo...", "............",
		]
		pal["y"] = Color("ffcf4f")
		pal["w"] = Color("fff6c8")
		pal["g"] = Color("8a8f9c")
	elif kind == "shield":
		rows = [
			"..oooooooo..", ".obbbbbbbbo.", ".obhbbbbbbo.", ".obhbbwwbbo.", ".obbbbwwbbo.",
			".obbbbwwbbo.", "..obbbbbbo..", "..obbbbbBo..", "...obbbbBo..", "....obbBo...",
			".....oBo....", "............",
		]
		pal["b"] = Color("4f8cff")
		pal["B"] = Color("2a56b3")
		pal["w"] = Color("ffffff")
		pal["h"] = Color("a9c8ff")
	else:
		rows = [
			"....oooo....", "..ooyyyyoo..", ".oyyyhhyyyo.", ".oyyhyyyYyo.", "oyyhyYYYYyyo",
			"oyyhyYYYYyyo", "oyyyyYYYYyyo", ".oyyyYYYYyo.", ".oyyyyyyyyo.", "..ooyyyyoo..",
			"....oooo....", "............",
		]
		pal["y"] = Color("ffc93c")
		pal["Y"] = Color("e09a1a")
	var tx := _tex_from_rows(rows, pal)
	tex_cache[kind] = tx
	return tx


func _floor_tex(ti: int, parity: int, variant: int) -> ImageTexture:
	var key := "floor%d_%d_%d" % [ti, parity, variant]
	if tex_cache.has(key):
		return tex_cache[key]
	var base: Color = themes[ti]["tile"] if parity == 0 else themes[ti]["tile2"]
	var rng := RandomNumberGenerator.new()
	rng.seed = ti * 100 + parity * 10 + variant
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(base)
	if ti == 0:
		for i in 16:
			img.set_pixel(i, 0, base.darkened(0.3))
			img.set_pixel(0, i, base.darkened(0.3))
			img.set_pixel(i, 1, base.lightened(0.08))
			img.set_pixel(1, i, base.lightened(0.08))
		for p in [Vector2i(3, 3), Vector2i(12, 3), Vector2i(3, 12), Vector2i(12, 12)]:
			img.set_pixel(p.x, p.y, base.lightened(0.3))
			img.set_pixel(p.x + 1, p.y + 1, base.darkened(0.3))
		if variant == 1:
			for y in range(5, 11, 2):
				for x in range(4, 12):
					img.set_pixel(x, y, base.darkened(0.35))
		elif variant == 2:
			for x in 16:
				if (x / 2) % 2 == 0:
					img.set_pixel(x, 14, Color("b8901e"))
					img.set_pixel(x, 13, Color("b8901e").darkened(0.3))
	elif ti == 1:
		for i in 12:
			var gx := rng.randi_range(1, 14)
			var gy := rng.randi_range(2, 14)
			img.set_pixel(gx, gy, base.lightened(0.28))
			img.set_pixel(gx, gy - 1, base.lightened(0.45))
		for i in 8:
			img.set_pixel(rng.randi_range(0, 15), rng.randi_range(0, 15), base.darkened(0.2))
		if variant == 2:
			var fx := rng.randi_range(3, 12)
			var fy := rng.randi_range(3, 12)
			img.set_pixel(fx, fy, Color("ffe066"))
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				img.set_pixel(fx + d.x, fy + d.y, Color("ff9ecb"))
	else:
		for y in [0, 8]:
			for x in 16:
				img.set_pixel(x, y, base.darkened(0.35))
				img.set_pixel(x, y + 1, base.lightened(0.07))
		for i in 14:
			var gx2 := rng.randi_range(0, 15)
			var gy2: int = rng.randi_range(0, 1) * 8 + rng.randi_range(2, 6)
			img.set_pixel(gx2, gy2, base.darkened(0.15))
			if gx2 < 14:
				img.set_pixel(gx2 + 1, gy2, base.darkened(0.15))
		var seam := 5 + variant * 3
		for y in range(0, 8):
			img.set_pixel(seam, y, base.darkened(0.35))
		for y in range(8, 16):
			img.set_pixel((seam + 7) % 16, y, base.darkened(0.35))
		for p in [Vector2i(1, 3), Vector2i(14, 3), Vector2i(1, 11), Vector2i(14, 11)]:
			img.set_pixel(p.x, p.y, base.lightened(0.35))
	var tx := ImageTexture.create_from_image(img)
	tex_cache[key] = tx
	return tx


func _wall_tex(ti: int) -> ImageTexture:
	var key := "wall%d" % ti
	if tex_cache.has(key):
		return tex_cache[key]
	var base: Color = themes[ti]["wall"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 555 + ti
	var S := 16
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(base)
	if ti == 0:
		for i in S:
			for e in [0, S - 1]:
				img.set_pixel(i, e, base.darkened(0.6))
				img.set_pixel(e, i, base.darkened(0.6))
			img.set_pixel(i, 1, base.lightened(0.25))
			img.set_pixel(1, i, base.lightened(0.15))
			img.set_pixel(i, S - 2, base.darkened(0.3))
			img.set_pixel(S - 2, i, base.darkened(0.3))
		for y in [5, 7, 9]:
			for x in range(3, 13):
				img.set_pixel(x, y, base.darkened(0.45))
				img.set_pixel(x, y + 1, base.lightened(0.15))
		for p in [Vector2i(3, 3), Vector2i(12, 3), Vector2i(3, 12), Vector2i(12, 12)]:
			img.set_pixel(p.x, p.y, base.lightened(0.5))
		for x in range(2, 14):
			if (x / 2) % 2 == 0:
				img.set_pixel(x, 12, Color("d9b020"))
				img.set_pixel(x, 13, Color("d9b020").darkened(0.35))
	elif ti == 1:
		var g1 := base.darkened(0.45)
		var g2 := base
		var g3 := base.lightened(0.3)
		for y in S:
			for x in S:
				var v := sin(x * 1.1 + rng.randf()) + cos(y * 0.9 + rng.randf()) + rng.randf() * 0.8
				var c := g2
				if v < -0.4:
					c = g1
				elif v > 1.1:
					c = g3
				img.set_pixel(x, y, c)
		for i in S:
			if rng.randf() < 0.5:
				img.set_pixel(i, 0, g1)
			if rng.randf() < 0.5:
				img.set_pixel(i, S - 1, g1)
			if rng.randf() < 0.5:
				img.set_pixel(0, i, g1)
			if rng.randf() < 0.5:
				img.set_pixel(S - 1, i, g1)
		for i in 4:
			img.set_pixel(rng.randi_range(2, 13), rng.randi_range(2, 13), Color("ff5c7a"))
	else:
		for i in S:
			for e in [0, S - 1]:
				img.set_pixel(i, e, base.darkened(0.6))
				img.set_pixel(e, i, base.darkened(0.6))
			img.set_pixel(i, 1, base.lightened(0.2))
			img.set_pixel(1, i, base.lightened(0.2))
		for i in range(2, S - 2):
			img.set_pixel(i, i, base.darkened(0.35))
			img.set_pixel(i, i + 1 if i + 1 < S - 1 else i, base.darkened(0.35))
			img.set_pixel(S - 1 - i, i, base.darkened(0.35))
			img.set_pixel(S - 1 - i, i + 1 if i + 1 < S - 1 else i, base.darkened(0.35))
		for p in [Vector2i(2, 2), Vector2i(13, 2), Vector2i(2, 13), Vector2i(13, 13)]:
			img.set_pixel(p.x, p.y, base.lightened(0.6))
		for i in 12:
			img.set_pixel(rng.randi_range(2, 13), rng.randi_range(2, 13), base.lightened(0.1))
	var tx := ImageTexture.create_from_image(img)
	tex_cache[key] = tx
	return tx


func _monster_tex(ti: int, lvl: int, boss: bool) -> ImageTexture:
	var key := "m%d_%d_%d" % [ti, lvl, 1 if boss else 0]
	if tex_cache.has(key):
		return tex_cache[key]
	var cols: Array = themes[ti]["mcols"]
	var body: Color = cols[(lvl - 1) % cols.size()]
	var W := 15 if boss else 13
	var half := W / 2
	var rng := RandomNumberGenerator.new()
	rng.seed = ti * 7919 + lvl * 104729 + (13 if boss else 0)
	var g: Array = []
	for y in W:
		var row: Array = []
		for x in W:
			row.append(0)
		g.append(row)
	# 0 empty, 1 body, 2 eye white, 3 pupil, 4 mouth, 5 tooth, 6 spot, 7 horn, 8 glow bulb
	var rx := float(half) - 0.6 - rng.randf() * 1.3
	var cy := (W - 1) * 0.5 + rng.randf() * 0.8
	var ry := W * 0.5 - 1.9 - rng.randf() * 1.2
	var ex := 2.0 + rng.randf() * 1.6
	for y in W:
		for x in range(0, half + 1):
			var dx := absf(float(x - half)) / rx
			var dy := absf(float(y) - cy) / ry
			var v := pow(dx, ex) + pow(dy, ex)
			if v <= 1.0 + (rng.randf() - 0.5) * 0.3:
				g[y][x] = 1
	# arms
	if rng.randf() < 0.65:
		var ay := int(cy) + rng.randi_range(-1, 1)
		for x in range(0, maxi(1, half - int(rx)) + 1):
			g[ay][x] = 1
			if rng.randf() < 0.5:
				g[ay + 1][x] = 1
	# horns
	var horns := rng.randi_range(0, 2)
	if boss:
		horns = 2
	for h in horns:
		var hx := half - 2 - h * 2 - rng.randi_range(0, 1)
		if hx < 1:
			hx = 1
		g[0][hx] = 7
		g[1][hx] = 7
		g[2][hx] = 7
		if hx > 0:
			g[0][hx - 1] = 7
	if rng.randf() < 0.3 or boss:
		g[0][half] = 8
		g[1][half] = 7
	# legs
	if rng.randf() < 0.75:
		var lx := half - 1 - rng.randi_range(0, 1)
		for k in rng.randi_range(1, 2):
			var x := lx - k * 2
			if x >= 0:
				g[W - 1][x] = 1
				g[W - 2][x] = 1
	# eyes
	var ey := int(cy - ry * 0.35)
	var etype := rng.randi() % 3
	if etype == 0:
		var ex0 := half - 3
		for yy in range(ey, ey + 2):
			for xx in range(ex0, ex0 + 2):
				g[yy][xx] = 2
		g[ey + 1][ex0 + 1] = 3
		g[ey][ex0 + 1] = 3
	elif etype == 1:
		for yy in range(ey - 1, ey + 2):
			for xx in range(half - 1, half + 1):
				g[yy][xx] = 2
		g[ey][half] = 3
		g[ey + 1][half] = 3
	else:
		g[ey - 1][half] = 2
		g[ey][half] = 3
		g[ey + 1][half - 3] = 2
		g[ey + 1][half - 2] = 3
	# mouth
	var my := ey + 3
	if my < W - 2:
		for xx in range(half - 2, half + 1):
			if int(g[my][xx]) != 0:
				g[my][xx] = 4
		if rng.randf() < 0.65 and int(g[my][half - 1]) == 4:
			g[my][half - 1] = 5
			if int(g[my][half - 2]) == 4 and rng.randf() < 0.5:
				g[my][half - 2] = 5
	# spots
	for i in 5:
		var sx := rng.randi_range(1, half)
		var sy := rng.randi_range(2, W - 3)
		if int(g[sy][sx]) == 1 and absi(sy - ey) > 1:
			g[sy][sx] = 6
	# mirror
	for y in W:
		for x in range(0, half):
			if int(g[y][x]) != 0:
				g[y][W - 1 - x] = g[y][x]
	var S := W + 2
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var outline := body.darkened(0.82)
	var horn_c := body.lightened(0.55)
	for y in S:
		for x in S:
			var gx := x - 1
			var gy := y - 1
			var v := 0
			if gx >= 0 and gy >= 0 and gx < W and gy < W:
				v = int(g[gy][gx])
			if v == 0:
				var near := false
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = gx + d.x
					var ny: int = gy + d.y
					if nx >= 0 and ny >= 0 and nx < W and ny < W and int(g[ny][nx]) != 0:
						near = true
				if near:
					img.set_pixel(x, y, outline)
				continue
			var c := body
			if v == 1 or v == 6 or v == 7:
				var top_empty := gy == 0 or int(g[gy - 1][gx]) == 0
				var left_empty := gx == 0 or int(g[gy][gx - 1]) == 0
				var bot_empty := gy == W - 1 or int(g[gy + 1][gx]) == 0
				var right_empty := gx == W - 1 or int(g[gy][gx + 1]) == 0
				if v == 7:
					c = horn_c
				elif v == 6:
					c = body.darkened(0.28)
				if top_empty or left_empty:
					c = c.lightened(0.3)
				elif bot_empty or right_empty:
					c = c.darkened(0.35)
				elif gy > W * 0.65:
					c = c.darkened(0.15)
			elif v == 2:
				c = Color.WHITE
			elif v == 3:
				c = Color("14141c")
			elif v == 4:
				c = Color("2a0f18")
			elif v == 5:
				c = Color("f2ead3")
			elif v == 8:
				c = Color("fff27a")
			img.set_pixel(x, y, c)
	var tx := ImageTexture.create_from_image(img)
	tex_cache[key] = tx
	return tx


# ---------- floor generation ----------

func _setup_size() -> void:
	N = 6 if floor_n <= 2 else (7 if floor_n <= 4 else 8)
	cell = GW / N
	period = 8 + (N - 5)
	maxd = (N + 1) / 2 - 1


func _new_floor() -> void:
	_setup_size()
	var tries := 0
	while true:
		_random_layout(tries)
		tries += 1
		if _solvable():
			break
		if tries >= 60:
			walls.clear()
			portals.clear()
			spikes.clear()
			req = START_LEVEL
			break
	saved = {
		"mons": mons.duplicate(), "elite": elite.duplicate(), "items": items.duplicate(), "spikes": spikes.duplicate(),
		"coin_at": coin_at.duplicate(), "walls": walls.duplicate(), "portals": portals.duplicate(),
		"coins": coins,
	}
	_begin_floor()
	_play_music(tidx())


func _begin_floor() -> void:
	level = START_LEVEL
	moves = 0
	shield = false
	pos = start
	walk.clear()
	pops.clear()
	state = PLAY
	msg = "Reach Lv %d to open the %s" % [req, cur_theme()["gate"]]


func _reset_floor() -> void:
	mons = saved["mons"].duplicate()
	elite = saved["elite"].duplicate()
	items = saved["items"].duplicate()
	spikes = saved["spikes"].duplicate()
	coin_at = saved["coin_at"].duplicate()
	walls = saved["walls"].duplicate()
	portals = saved["portals"].duplicate()
	coins = saved["coins"]
	_begin_floor()


func _take(free: Array[Vector2i]) -> Vector2i:
	return free.pop_front()


func _random_layout(tries: int) -> void:
	var k := N - 6
	var cells: Array[Vector2i] = []
	for x in N:
		for y in N:
			cells.append(Vector2i(x, y))
	cells.shuffle()
	start = Vector2i.ZERO
	for c in cells:
		if ring(c) == 0:
			start = c
			break
	stairs = Vector2i(N / 2, N / 2)
	for c in cells:
		if ring(c) == maxd:
			stairs = c   # innermost ring: the dark never reaches it
			break
	var free: Array[Vector2i] = []
	for c in cells:
		if c != start and c != stairs:
			free.append(c)
	mons.clear()
	elite.clear()
	items.clear()
	spikes.clear()
	coin_at.clear()
	walls.clear()
	portals.clear()
	boss_cell = Vector2i(-1, -1)
	var nm: int = [6, 8, 10][k] + mini((floor_n - 1) / 4, 1)
	var base := [1, 1, 2, 2, 3, 3, 4, 4, 5, 6, 6]
	var bump := (floor_n - 1) / 3
	var levels: Array[int] = []
	for i in nm:
		var lv: int = base[i]
		if lv >= 3:
			lv += bump
		levels.append(lv)
	levels.sort()
	levels.reverse()
	var first := true
	for lv in levels:
		var spot := Vector2i(-1, -1)
		if first:
			for c in free:
				if absi(c.x - stairs.x) + absi(c.y - stairs.y) == 1:
					spot = c
					break
			first = false
			if spot.x >= 0:
				boss_cell = spot
		if spot.x < 0:
			spot = free[0]
		free.erase(spot)
		mons[spot] = lv
	var ne: int = [1, 2, 2][k]
	var cand: Array[Vector2i] = []
	for c in mons:
		if c != boss_cell and int(mons[c]) >= 2:
			cand.append(c)
	cand.shuffle()
	for i in mini(ne, cand.size()):
		elite[cand[i]] = true
	var np := 2 + k
	var nbig: int = [1, 1, 2][k]
	var nlamp: int = [1, 2, 2][k]
	var nshield: int = [1, 1, 2][k]
	for i in np:
		items[_take(free)] = "pot"
	for i in nbig:
		items[_take(free)] = "big"
	for i in nlamp:
		items[_take(free)] = "lamp"
	for i in nshield:
		items[_take(free)] = "shield"
	var npairs: int = [1, 1, 2][k]
	for i in npairs:
		var a := _take(free)
		var b := _take(free)
		portals[a] = b
		portals[b] = a
	for i in [3, 5, 7][k]:
		walls[_take(free)] = true
	for i in [2, 3, 4][k]:
		spikes[_take(free)] = true
	for i in N + 2:
		coin_at[_take(free)] = true
	var total := nm + elite.size() + np + 2 * nbig
	var ratio := maxf(0.3, 0.55 - 0.04 * (tries / 2))
	req = START_LEVEL + int(total * ratio)


func _solvable() -> bool:
	var list: Array[Vector2i] = []
	var gain: Array[int] = []
	for c in mons:
		list.append(c)
		gain.append(2 if elite.has(c) else 1)
	for c in items:
		list.append(c)
		var kd: String = items[c]
		gain.append(1 if kd == "pot" else (2 if kd == "big" else 0))
	var idx: Dictionary = {}
	for i in list.size():
		idx[list[i]] = i
	var cap := maxd * period
	var seen: Dictionary = {}
	# state: pos, mask, moves, level, shield
	var stack: Array = [[start, 0, 0, START_LEVEL, 0]]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var pops_n := 0
	while stack.size() > 0:
		pops_n += 1
		if pops_n > 15000:
			return false
		var s: Array = stack.pop_back()
		var p: Vector2i = s[0]
		var mask: int = s[1]
		var m: int = s[2]
		var lvl: int = s[3]
		var sh: int = s[4]
		for d in dirs:
			var nc: Vector2i = p + d
			if not in_b(nc) or walls.has(nc):
				continue
			var m2 := mini(m + 1 + (2 if spikes.has(nc) else 0), cap)
			var dp := mini(m2 / period, maxd)
			if ring(nc) < dp:
				continue
			var dest := nc
			if portals.has(nc):
				dest = portals[nc]
				if ring(dest) < dp:
					continue
			var mask2 := mask
			var lvl2 := lvl
			var sh2 := sh
			var m3 := m2
			if nc == stairs:
				if lvl >= req:
					return true
				continue
			if idx.has(nc) and not (mask & (1 << int(idx[nc]))):
				var bi: int = idx[nc]
				if mons.has(nc):
					if lvl > int(mons[nc]):
						lvl2 = lvl + gain[bi]
					elif sh == 1:
						sh2 = 0
					else:
						continue
				else:
					var kind: String = items[nc]
					lvl2 = lvl + gain[bi]
					if kind == "lamp":
						m3 = maxi(m2 - 4, dp * period)
					elif kind == "shield":
						sh2 = 1
				mask2 = mask | (1 << bi)
			var key := (((((dest.x * N + dest.y) * 2097152 + mask2) * 64 + m3) * 32 + lvl2) * 2) + sh2
			if seen.has(key):
				continue
			seen[key] = true
			stack.append([dest, mask2, m3, lvl2, sh2])
	return false


# ---------- gameplay ----------

func _pop(c: Vector2i, text: String, col: Color) -> void:
	pops.append({"p": _cell_rect(c).get_center(), "s": text, "c": col, "t": t})


func _step(nc: Vector2i) -> void:
	var th := cur_theme()
	var names: Array = th["mons"]
	var landing := nc
	var lamp := false
	var extra := 0
	var snd := "step"
	if mons.has(nc):
		var lv: int = mons[nc]
		var nm: String = th["boss"] if nc == boss_cell else names[(lv - 1) % names.size()]
		if level > lv:
			var gain := 2 if elite.has(nc) else 1
			mons.erase(nc)
			elite.erase(nc)
			level += gain
			msg = "Beat %s! Level %d" % [nm, level]
			_pop(nc, "LEVEL +%d" % gain, Color("6dff9a"))
			snd = "elite" if gain == 2 else "win"
		elif shield:
			shield = false
			mons.erase(nc)
			elite.erase(nc)
			msg = "Shield shattered! %s defeated" % nm
			_pop(nc, "SHIELD!", Color("7db2ff"))
			snd = "shieldbreak"
		else:
			pos = nc
			_die("%s (Lv %d) was too strong" % [nm, lv])
			return
	elif nc == stairs:
		if level < req:
			msg = "%s needs Lv %d" % [th["gate"], req]
			_sfx("blocked")
			walk.clear()
			return
	elif items.has(nc):
		var kind: String = items[nc]
		items.erase(nc)
		if kind == "pot":
			level += 1
			msg = "%s! Level %d" % [th["pot"], level]
			_pop(nc, "+1", Color("ffd84f"))
			snd = "pot"
		elif kind == "big":
			level += 2
			msg = "Overcharged %s! Level %d" % [th["pot"], level]
			_pop(nc, "+2", Color("4fd1ff"))
			snd = "big"
		elif kind == "shield":
			shield = true
			msg = "Shield! It saves you from one losing fight"
			_pop(nc, "SHIELD", Color("7db2ff"))
			snd = "shield"
		else:
			lamp = true
			msg = "Lantern lit! The dark is held back"
			_pop(nc, "LIGHT", Color("ffe9a0"))
			snd = "lamp"
	elif spikes.has(nc):
		extra = 2
		msg = "Spikes! The dark gains 2 steps"
		_pop(nc, "OUCH", Color("ff7a7a"))
		snd = "spike"
	elif coin_at.has(nc):
		coin_at.erase(nc)
		coins += 1
		msg = "Coin! %d total" % coins
		_pop(nc, "+1 coin", Color("ffc93c"))
		snd = "coin"
	elif portals.has(nc):
		landing = portals[nc]
		if is_dark(landing):
			msg = "The far portal is swallowed by the dark"
			_sfx("blocked")
			walk.clear()
			return
		msg = "Warp!"
		snd = "warp"
	pos = landing
	var before := depth_for(moves)
	moves = mini(moves + 1 + extra, maxd * period)
	if depth_for(moves) > before:
		msg = "The dark swallows the edge!"
		snd = "swallow"
	if is_dark(pos):
		_die("Swallowed by the dark")
		return
	if lamp:
		moves = maxi(moves - 4, depth_for(moves) * period)
	if pos == stairs:
		_clear()
		return
	if snd == "step" and moves < maxd * period and (depth_for(moves) + 1) * period - moves <= 3:
		snd = "tick"
	_sfx(snd)


func _die(why: String) -> void:
	state = DEAD
	walk.clear()
	var reached := floor_n - 1
	if reached > best:
		best = reached
		var cfg := ConfigFile.new()
		cfg.set_value("s", "best", best)
		cfg.save("user://best.cfg")
	_sfx("death")
	over_title = "YOU DIED"
	over_sub = "%s\nFloors cleared: %d   Best: %d\nCoins: %d" % [why, reached, best, coins]


func _clear() -> void:
	state = CLEAR
	walk.clear()
	_sfx("clear")
	over_title = "FLOOR %d CLEAR" % floor_n
	var nxt := floor_n + 1
	over_sub = "Next: floor %d" % nxt
	if (nxt - 1) % 3 == 0:
		over_sub += "\nNew sector ahead!"
	if nxt == 3 or nxt == 5:
		over_sub += "\nThe station gets bigger..."


func _blocking(c: Vector2i) -> bool:
	return mons.has(c) or spikes.has(c)


func _plan(target: Vector2i) -> void:
	if portals.has(target):
		target = portals[target]
		if target == pos:
			return
	# BFS through free cells; portals are edges; monsters and spikes are only entered as the final step.
	var dist: Dictionary = {pos: 0}
	var prev: Dictionary = {}
	var via: Dictionary = {}
	var q: Array[Vector2i] = [pos]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while q.size() > 0:
		var c: Vector2i = q.pop_front()
		for d in dirs:
			var n: Vector2i = c + d
			if not in_b(n) or is_dark(n) or walls.has(n) or _blocking(n):
				continue
			if n == stairs and level < req:
				continue
			var dest := n
			if portals.has(n):
				dest = portals[n]
				if is_dark(dest):
					continue
			if dist.has(dest):
				continue
			dist[dest] = int(dist[c]) + 1
			prev[dest] = c
			if dest != n:
				via[dest] = n
			q.append(dest)
	var goal := target
	var attack := false
	if _blocking(target) or (target == stairs and level < req):
		var bestd := 999
		var bestc := Vector2i(-1, -1)
		for d in dirs:
			var n2: Vector2i = target + d
			if dist.has(n2) and int(dist[n2]) < bestd:
				bestd = int(dist[n2])
				bestc = n2
		if bestc.x < 0:
			msg = "Can't reach that"; _sfx("blocked")
			return
		goal = bestc
		attack = true
	elif not dist.has(goal):
		msg = "Can't reach that"; _sfx("blocked")
		return
	var path: Array[Vector2i] = []
	var c2 := goal
	while c2 != pos:
		if via.has(c2):
			path.push_front(via[c2])
		else:
			path.push_front(c2)
		c2 = prev[c2]
	if attack:
		path.append(target)
	walk = path
	walk_t = 0.1


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = event.position
	if btn_sound.has_point(p):
		snd_on = not snd_on
		_apply_sound()
		_sfx("ui")
		return
	if state == CLEAR:
		floor_n += 1
		_new_floor()
		return
	if state == DEAD:
		if btn_retry.has_point(p):
			_reset_floor()
			_sfx("ui")
		elif btn_newrun.has_point(p):
			floor_n = 1
			coins = 0
			_new_floor()
			_sfx("ui")
		return
	if btn_reset.has_point(p):
		_reset_floor()
		_sfx("ui")
		return
	if p.x < GX or p.y < GY:
		return
	var cx := int((p.x - GX) / cell)
	var cy := int((p.y - GY) / cell)
	var target := Vector2i(cx, cy)
	if not in_b(target) or target == pos or is_dark(target) or walls.has(target):
		return
	_plan(target)


func _process(dt: float) -> void:
	t += dt
	if state == PLAY and walk.size() > 0:
		walk_t += dt
		if walk_t >= 0.12:
			walk_t = 0.0
			var nc: Vector2i = walk.pop_front()
			if is_dark(nc):
				walk.clear()
			else:
				_step(nc)
	var i := pops.size() - 1
	while i >= 0:
		if t - float(pops[i]["t"]) > 0.9:
			pops.remove_at(i)
		i -= 1
	queue_redraw()


# ---------- drawing ----------

func _txt(s: String, p: Vector2, size: int, col: Color, w := 720.0, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	draw_string(font, p, s, align, w, size, col)


func _ctext(s: String, c: Vector2, size: int, col: Color) -> void:
	draw_string(font, Vector2(c.x - 100.0, c.y + size * 0.35), s, HORIZONTAL_ALIGNMENT_CENTER, 200.0, size, col)


func _cell_rect(c: Vector2i) -> Rect2:
	return Rect2(GX + c.x * cell, GY + c.y * cell, cell, cell)


func _spr(tex: Texture2D, ctr: Vector2, size: float) -> void:
	draw_texture_rect(tex, Rect2(ctr.x - size * 0.5, ctr.y - size * 0.5, size, size), false)


func _button(r: Rect2, label: String, col: Color, size := 20) -> void:
	draw_rect(r, Color(col.r, col.g, col.b, 0.14))
	draw_rect(r, col, false, 2.0)
	_ctext(label, r.get_center(), size, col)


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, Color("5a3d00"), 1.5)


func _draw_spikes(ctr: Vector2) -> void:
	var w := cell * 0.62
	draw_rect(Rect2(ctr.x - w * 0.5, ctr.y - w * 0.32, w, w * 0.64), Color("20242f"))
	for i in 3:
		for j in 2:
			var bx := ctr.x - w * 0.34 + i * w * 0.34
			var by := ctr.y - w * 0.12 + j * w * 0.3
			var tri := PackedVector2Array([Vector2(bx - w * 0.14, by + w * 0.12), Vector2(bx + w * 0.14, by + w * 0.12), Vector2(bx, by - w * 0.16)])
			draw_colored_polygon(tri, Color("c3cad8"))
			var side := PackedVector2Array([Vector2(bx, by - w * 0.16), Vector2(bx + w * 0.14, by + w * 0.12), Vector2(bx, by + w * 0.12)])
			draw_colored_polygon(side, Color("7c8497"))
			draw_circle(Vector2(bx, by - w * 0.14), 1.8, Color("ff5d5d"))


func _draw() -> void:
	if themes.is_empty():
		return
	var ti := tidx()
	var th := cur_theme()
	var acc: Color = th["accent"]
	draw_rect(Rect2(0, 0, 720, 1280), th["bg"])
	for s in stars:
		var a := 0.12 + 0.28 * (0.5 + 0.5 * sin(t * 1.5 + float(s[2])))
		var sz: float = s[3]
		var drift := 0.0
		if ti == 1:
			drift = sin(t * 0.7 + float(s[2])) * 6.0
		draw_rect(Rect2(float(s[0]) + drift, float(s[1]), sz, sz), Color(acc.r, acc.g, acc.b, a))
	# HUD
	_button(btn_sound, "SOUND ON" if snd_on else "SOUND OFF", acc)
	_button(btn_reset, "RESET", acc)
	_txt(th["name"], Vector2(0, 62), 28, acc)
	_txt("FLOOR %d    BEST %d" % [floor_n, best], Vector2(0, 112), 24, Color(1, 1, 1, 0.6))
	_txt("LV %d" % level, Vector2(40, 205), 72, Color.WHITE, 300.0, HORIZONTAL_ALIGNMENT_LEFT)
	_txt("COINS %d" % coins, Vector2(40, 256), 26, Color("ffc93c"), 300.0, HORIZONTAL_ALIGNMENT_LEFT)
	if shield:
		_spr(_item_tex("shield"), Vector2(232, 244), 40)
		_txt("SHIELD", Vector2(256, 252), 22, Color("7db2ff"), 120.0, HORIZONTAL_ALIGNMENT_LEFT)
	var depth := depth_for(moves)
	var dark_txt := "DARK FINAL"
	var frac := 1.0
	var left := 0
	var cap := maxd * period
	if moves < cap:
		left = (depth + 1) * period - moves
		frac = 1.0 - float(left) / period
		dark_txt = "DARK IN %d" % left
	var warn := moves < cap and left <= 3
	var dcol := Color("ff5d5d") if warn else acc
	_txt(dark_txt, Vector2(360, 200), 44, dcol, 320.0, HORIZONTAL_ALIGNMENT_RIGHT)
	draw_rect(Rect2(380, 218, 300, 14), Color(1, 1, 1, 0.12))
	draw_rect(Rect2(380, 218, 300 * frac, 14), dcol)
	_txt("%s: Lv %d" % [th["gate"], req], Vector2(0, 298), 28, Color.WHITE if level >= req else Color(1, 1, 1, 0.55))
	# grid
	var names: Array = th["mons"]
	var wall_tex := _wall_tex(ti)
	for x in N:
		for y in N:
			var c := Vector2i(x, y)
			var r := _cell_rect(c)
			if is_dark(c):
				draw_rect(r, th["dark"])
				continue
			draw_texture_rect(_floor_tex(ti, (x + y) % 2, (x * 7 + y * 3) % 3), r.grow(-1.0), false)
			if ring(c) == depth:
				draw_rect(r.grow(-1.0), Color(0, 0, 0, 0.28))
				if warn:
					draw_rect(r.grow(-1.0), Color(1, 0.2, 0.2, 0.12 + 0.12 * sin(t * 8.0)))
			var ctr := r.get_center()
			var bob := sin(t * 3.0 + x * 1.7 + y) * 2.0
			if walls.has(c):
				draw_texture_rect(wall_tex, r.grow(-1.0), false)
			elif c == stairs:
				var ok := level >= req
				var dc := Color("6dff9a") if ok else Color(1, 1, 1, 0.4)
				var hw := cell * 0.28
				var hh := cell * 0.38
				draw_rect(Rect2(ctr.x - hw, ctr.y - hh, hw * 2, hh * 2), Color(dc.r, dc.g, dc.b, 0.16))
				draw_rect(Rect2(ctr.x - hw, ctr.y - hh, hw * 2, hh * 2), dc, false, 4.0)
				draw_rect(Rect2(ctr.x - hw + 6, ctr.y - hh + 6, hw * 2 - 12, hh * 2 - 12), Color(dc.r, dc.g, dc.b, 0.35), false, 1.5)
				_ctext("Lv %d" % req, ctr, int(cell * 0.24), dc)
			elif mons.has(c):
				var lv: int = mons[c]
				var is_boss := c == boss_cell
				var safe := level > lv
				var mc := Color("49d17a") if safe else (Color("ffb02e") if shield else Color("ef4b55"))
				var sz := cell * (0.92 if is_boss else 0.8)
				if is_boss:
					draw_circle(ctr, cell * 0.5, Color(acc.r, acc.g, acc.b, 0.12 + 0.08 * sin(t * 3.0)))
				draw_circle(ctr + Vector2(0, cell * 0.3), cell * 0.28, Color(0, 0, 0, 0.3))
				_spr(_monster_tex(ti, lv, is_boss), ctr + Vector2(0, bob), sz)
				if elite.has(c):
					_star(Vector2(r.position.x + cell * 0.2, r.position.y + cell * 0.2 + bob), cell * 0.16, Color("ffd84f"))
				var bp := Vector2(r.end.x - cell * 0.2, r.position.y + cell * 0.2)
				draw_circle(bp, cell * 0.17, Color("0a0c14"))
				draw_circle(bp, cell * 0.145, mc)
				_ctext(str(lv), bp, int(cell * 0.22), Color.WHITE)
				if N <= 7:
					_txt(names[(lv - 1) % names.size()], Vector2(r.position.x, r.end.y - 5), 13, Color(1, 1, 1, 0.65), cell)
			elif items.has(c):
				var kind: String = items[c]
				draw_circle(ctr + Vector2(0, cell * 0.25), cell * 0.2, Color(0, 0, 0, 0.25))
				_spr(_item_tex(kind), ctr + Vector2(0, bob), cell * 0.58)
				if kind == "pot":
					_txt("+1", Vector2(r.position.x, r.end.y - 6), 15, Color("ffd84f"), cell)
				elif kind == "big":
					_txt("+2", Vector2(r.position.x, r.end.y - 6), 15, Color("4fd1ff"), cell)
				elif kind == "shield":
					_txt("shield", Vector2(r.position.x, r.end.y - 6), 13, Color("7db2ff"), cell)
				else:
					_txt("light", Vector2(r.position.x, r.end.y - 6), 13, Color("ffe9a0"), cell)
			elif spikes.has(c):
				_draw_spikes(ctr)
			elif coin_at.has(c):
				_spr(_item_tex("coin"), ctr + Vector2(0, bob), cell * 0.42)
			elif portals.has(c):
				var pc := Color("c07cff")
				draw_circle(ctr, cell * 0.34, Color(pc.r, pc.g, pc.b, 0.18))
				draw_arc(ctr, cell * 0.32, t * 3.0, t * 3.0 + PI * 1.3, 18, pc, 4.0)
				draw_arc(ctr, cell * 0.2, -t * 4.0, -t * 4.0 + PI * 1.3, 14, Color("e6c8ff"), 3.0)
				draw_circle(ctr, cell * 0.07, pc)
	# player
	var prc := _cell_rect(pos).get_center()
	draw_circle(prc + Vector2(0, cell * 0.3), cell * 0.25, Color(0, 0, 0, 0.35))
	if shield:
		draw_arc(prc, cell * 0.46, 0, TAU, 28, Color(0.5, 0.7, 1.0, 0.5 + 0.2 * sin(t * 5.0)), 3.0)
	_spr(_player_tex(), prc + Vector2(0, sin(t * 4.0) * 2.0), cell * 0.78)
	# floating pops
	for pp in pops:
		var age: float = t - float(pp["t"])
		var pcol: Color = pp["c"]
		pcol.a = 1.0 - age / 0.9
		var pp_pos: Vector2 = pp["p"]
		_ctext(pp["s"], pp_pos + Vector2(0, -cell * 0.3 - age * 50.0), 26, pcol)
	# footer
	_txt(msg, Vector2(0, 1040), 30, Color.WHITE)
	_txt("Green badge = you win the fight. Red = you die. Equal loses!", Vector2(0, 1100), 23, Color(1, 1, 1, 0.55))
	_txt("Gold star = beat it for +2 levels. Shield saves you once.", Vector2(0, 1134), 23, Color(1, 1, 1, 0.55))
	_txt("Spikes cost 2 extra steps. Portals warp. Lanterns slow the dark.", Vector2(0, 1168), 23, Color(1, 1, 1, 0.55))
	_txt("Tap a tile to walk there. The dark eats the outer ring.", Vector2(0, 1202), 23, Color(1, 1, 1, 0.55))
	if state != PLAY:
		draw_rect(Rect2(0, 0, 720, 1280), Color(0, 0, 0, 0.72))
		var tc := Color("ff5d5d") if state == DEAD else acc
		_txt(over_title, Vector2(0, 560), 64, tc)
		var ly := 640
		for line in over_sub.split("\n"):
			_txt(line, Vector2(0, ly), 30, Color.WHITE)
			ly += 44
		if state == DEAD:
			_button(btn_retry, "RETRY THIS FLOOR", acc, 30)
			_button(btn_newrun, "NEW RUN", Color("ff9d9d"), 30)
		else:
			_txt("Tap to continue", Vector2(0, ly + 50), 28, Color(1, 1, 1, 0.6))
		_button(btn_sound, "SOUND ON" if snd_on else "SOUND OFF", acc)


# ---------- audio (all synthesized in code) ----------

func _setup_audio() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -11.0
	add_child(music_player)
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.volume_db = -3.0
		add_child(p)
		sfx_players.append(p)
	_make_sfx()


func _apply_sound() -> void:
	if music_player:
		music_player.volume_db = -11.0 if snd_on else -80.0


func _sfx(n: String) -> void:
	if not snd_on or not sfx_cache.has(n):
		return
	var chosen: AudioStreamPlayer = sfx_players[0]
	for p in sfx_players:
		if not p.playing:
			chosen = p
			break
	chosen.stream = sfx_cache[n]
	chosen.pitch_scale = randf_range(0.97, 1.04) if n == "step" else 1.0
	chosen.play()


func _midi(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


func _osc(kind: int, ph: float) -> float:
	var f := ph - floorf(ph)
	if kind == 0:
		return sin(f * TAU)
	if kind == 1:
		return 4.0 * absf(f - 0.5) - 1.0
	if kind == 2:
		return 0.6 if f < 0.5 else -0.6
	return (2.0 * f - 1.0) * 0.6


func _add_note(buf: PackedFloat32Array, rate: int, t0: float, dur: float, freq: float, vol: float, kind: int, decay: float, pad := false, wrap := false) -> void:
	var i0 := int(t0 * rate)
	var n := int(dur * rate)
	var size := buf.size()
	for i in n:
		var idx := i0 + i
		if idx >= size:
			if wrap:
				idx = idx % size
			else:
				break
		var tt := float(i) / rate
		var env := 0.0
		if pad:
			env = sin(PI * float(i) / n)
		else:
			env = exp(-decay * tt) * minf(1.0, tt / 0.004) * minf(1.0, float(n - i) / (0.02 * rate))
		buf[idx] += _osc(kind, freq * tt) * vol * env


func _add_sweep(buf: PackedFloat32Array, rate: int, t0: float, dur: float, f0: float, f1: float, vol: float, kind: int, decay: float) -> void:
	var i0 := int(t0 * rate)
	var n := int(dur * rate)
	var ph := 0.0
	for i in n:
		var idx := i0 + i
		if idx >= buf.size():
			break
		var tt := float(i) / rate
		ph += lerpf(f0, f1, float(i) / n) / rate
		var env := exp(-decay * tt) * minf(1.0, tt / 0.004) * minf(1.0, float(n - i) / (0.01 * rate))
		buf[idx] += _osc(kind, ph) * vol * env


func _add_noise(buf: PackedFloat32Array, rate: int, t0: float, dur: float, vol: float, decay: float, lp: float, wrap := false) -> void:
	var i0 := int(t0 * rate)
	var n := int(dur * rate)
	var y := 0.0
	for i in n:
		var idx := i0 + i
		if idx >= buf.size():
			if wrap:
				idx = idx % buf.size()
			else:
				break
		y += (randf() * 2.0 - 1.0 - y) * lp
		buf[idx] += y * vol * exp(-decay * float(i) / rate)


func _stream(buf: PackedFloat32Array, rate: int, loop := false) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 30000.0))
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w


func _buf(dur: float, rate: int) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(dur * rate))
	return b


func _sfx_notes(freqs: Array, nd: float, vol: float, kind: int, decay: float) -> AudioStreamWAV:
	var b := _buf(nd * freqs.size() + 0.25, SR_SFX)
	for i in freqs.size():
		_add_note(b, SR_SFX, i * nd, nd * 1.8, float(freqs[i]), vol, kind, decay)
	return _stream(b, SR_SFX)


func _sfx_sweep(dur: float, f0: float, f1: float, vol: float, kind: int, decay: float) -> AudioStreamWAV:
	var b := _buf(dur + 0.02, SR_SFX)
	_add_sweep(b, SR_SFX, 0.0, dur, f0, f1, vol, kind, decay)
	return _stream(b, SR_SFX)


func _make_sfx() -> void:
	var d := sfx_cache
	d["step"] = _sfx_sweep(0.07, 330.0, 220.0, 0.3, 0, 25.0)
	d["tick"] = _sfx_notes([988.0], 0.07, 0.22, 2, 28.0)
	d["win"] = _sfx_notes([392.0, 523.0, 659.0], 0.07, 0.35, 1, 9.0)
	d["elite"] = _sfx_notes([392.0, 523.0, 659.0, 784.0, 1047.0], 0.06, 0.35, 1, 8.0)
	d["pot"] = _sfx_notes([659.0, 880.0, 1175.0], 0.06, 0.3, 0, 10.0)
	d["big"] = _sfx_notes([523.0, 659.0, 784.0, 1047.0, 1319.0], 0.055, 0.3, 0, 8.0)
	d["coin"] = _sfx_notes([988.0, 1319.0], 0.06, 0.2, 2, 14.0)
	d["shield"] = _sfx_sweep(0.3, 500.0, 1500.0, 0.22, 3, 5.0)
	d["lamp"] = _sfx_sweep(0.4, 260.0, 880.0, 0.3, 0, 3.0)
	d["blocked"] = _sfx_notes([150.0], 0.12, 0.3, 2, 12.0)
	d["ui"] = _sfx_notes([700.0, 900.0], 0.04, 0.25, 0, 20.0)
	var b := _buf(0.4, SR_SFX)
	_add_sweep(b, SR_SFX, 0.0, 0.18, 300.0, 1300.0, 0.25, 1, 4.0)
	_add_sweep(b, SR_SFX, 0.18, 0.18, 1300.0, 300.0, 0.25, 1, 4.0)
	d["warp"] = _stream(b, SR_SFX)
	b = _buf(0.3, SR_SFX)
	_add_noise(b, SR_SFX, 0.0, 0.22, 0.5, 12.0, 0.5)
	_add_sweep(b, SR_SFX, 0.0, 0.2, 220.0, 80.0, 0.25, 3, 6.0)
	d["spike"] = _stream(b, SR_SFX)
	b = _buf(0.4, SR_SFX)
	_add_noise(b, SR_SFX, 0.0, 0.25, 0.4, 10.0, 0.9)
	_add_sweep(b, SR_SFX, 0.0, 0.3, 1000.0, 200.0, 0.2, 2, 6.0)
	d["shieldbreak"] = _stream(b, SR_SFX)
	b = _buf(0.75, SR_SFX)
	_add_noise(b, SR_SFX, 0.0, 0.7, 0.6, 3.0, 0.12)
	_add_sweep(b, SR_SFX, 0.0, 0.7, 140.0, 45.0, 0.5, 0, 2.0)
	d["swallow"] = _stream(b, SR_SFX)
	b = _buf(1.0, SR_SFX)
	_add_sweep(b, SR_SFX, 0.0, 0.9, 440.0, 90.0, 0.35, 3, 2.2)
	_add_noise(b, SR_SFX, 0.0, 0.5, 0.2, 5.0, 0.3)
	d["death"] = _stream(b, SR_SFX)
	b = _buf(1.4, SR_SFX)
	var fan := [523.0, 659.0, 784.0, 1047.0, 1319.0, 1568.0]
	for i in fan.size():
		_add_note(b, SR_SFX, i * 0.09, 0.4, float(fan[i]), 0.3, 1, 5.0)
	_add_note(b, SR_SFX, 0.55, 0.8, 1047.0, 0.18, 0, 3.0)
	_add_note(b, SR_SFX, 0.55, 0.8, 1319.0, 0.18, 0, 3.0)
	d["clear"] = _stream(b, SR_SFX)


func _play_music(ti: int) -> void:
	if music_player == null:
		return
	if music_theme == ti and music_player.playing:
		return
	if music_cache.has(ti):
		music_theme = ti
		music_player.stream = music_cache[ti]
		music_player.play()
		return
	if music_building.has(ti):
		return
	music_building[ti] = true
	var s: AudioStreamWAV = await _build_music(ti)
	music_cache[ti] = s
	music_building.erase(ti)
	if tidx() == ti or music_theme == -1:
		music_theme = ti
		music_player.stream = s
		music_player.play()


func _build_music(ti: int) -> AudioStreamWAV:
	var cfgs := [
		{"bpm": 84.0, "kind": 1, "vol": 0.24, "pat": [0, 1, 2, 3, 2, 1, 2, 1],
			"ch": [[45, [57, 60, 64, 69]], [41, [53, 57, 60, 65]], [48, [55, 60, 64, 67]], [43, [50, 55, 59, 67]]]},
		{"bpm": 96.0, "kind": 0, "vol": 0.32, "pat": [0, 2, 1, 3, 2, 3, 1, 2],
			"ch": [[36, [60, 64, 67, 72]], [45, [57, 60, 64, 69]], [41, [60, 65, 69, 72]], [43, [59, 62, 67, 71]]]},
		{"bpm": 100.0, "kind": 2, "vol": 0.12, "pat": [0, 1, 2, 1, 3, 2, 1, 2],
			"ch": [[38, [62, 65, 69, 74]], [34, [58, 62, 65, 70]], [36, [60, 64, 67, 72]], [33, [57, 61, 64, 69]]]},
	]
	var cfg: Dictionary = cfgs[ti % cfgs.size()]
	var bpm: float = cfg["bpm"]
	var kind: int = cfg["kind"]
	var avol: float = cfg["vol"]
	var pat: Array = cfg["pat"]
	var chords: Array = cfg["ch"]
	var beat := 60.0 / bpm
	var eighth := beat / 2.0
	var buf := _buf(16.0 * beat, SR_MUS)
	for bar in 4:
		var chord: Array = chords[bar]
		var bass: int = chord[0]
		var arp: Array = chord[1]
		var tb := bar * 4.0 * beat
		_add_note(buf, SR_MUS, tb, 4.0 * beat, _midi(float(int(arp[0]) - 12)), 0.1, 0, 0.0, true, true)
		_add_note(buf, SR_MUS, tb, 4.0 * beat, _midi(float(int(arp[2]) - 12)), 0.06, 0, 0.0, true, true)
		await get_tree().process_frame
		_add_note(buf, SR_MUS, tb, beat * 1.8, _midi(float(bass)), 0.32, 1, 2.5, false, true)
		_add_note(buf, SR_MUS, tb + 2.0 * beat, beat * 1.8, _midi(float(bass)), 0.28, 1, 2.5, false, true)
		for e in 8:
			var nidx: int = pat[e]
			_add_note(buf, SR_MUS, tb + e * eighth, eighth * 2.4, _midi(float(int(arp[nidx]))), avol, kind, 7.0, false, true)
			if e % 2 == 1:
				_add_noise(buf, SR_MUS, tb + e * eighth, 0.03, 0.04, 80.0, 0.9, true)
			if e % 4 == 3:
				await get_tree().process_frame
	var peak := 0.001
	for i in buf.size():
		peak = maxf(peak, absf(buf[i]))
	if peak > 0.6:
		var k := 0.6 / peak
		for i in buf.size():
			buf[i] *= k
	return _stream(buf, SR_MUS, true)


# ---------- headless check ----------

func _self_test() -> void:
	_make_sfx()
	var mus: AudioStreamWAV = await _build_music(0)
	var nz := 0
	for i in range(0, mus.data.size(), 2):
		if mus.data.decode_s16(i) != 0:
			nz += 1
	var st: AudioStreamWAV = sfx_cache["win"]
	var nz2 := 0
	for i in range(0, st.data.size(), 2):
		if st.data.decode_s16(i) != 0:
			nz2 += 1
	print("audio ok sfx=%d music_nonzero=%d win_nonzero=%d" % [sfx_cache.size(), nz, nz2])
	var bad := 0
	for f in range(1, 16):
		floor_n = f
		_setup_size()
		var t0 := Time.get_ticks_msec()
		var tries := 0
		var ok := false
		while tries < 60 and not ok:
			_random_layout(tries)
			tries += 1
			ok = _solvable()
		print("floor %d N %d %s tries %d solvable %s req %d mons %d %dms" % [f, N, cur_theme()["name"], tries, ok, req, mons.size(), Time.get_ticks_msec() - t0])
		if not ok:
			bad += 1
		if ring(stairs) != maxd:
			print("GATE NOT CENTER")
			bad += 1
		for ti in 3:
			for lv in range(1, 10):
				_monster_tex(ti, lv, lv == 9)
			for p in 2:
				for v in 3:
					_floor_tex(ti, p, v)
			_wall_tex(ti)
		_player_tex()
		for kind in ["pot", "big", "lamp", "shield", "coin"]:
			_item_tex(kind)
	print("TEST DONE unsolvable=%d" % bad)

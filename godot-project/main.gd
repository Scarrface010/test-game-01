extends Control
# Pocket Station - level-or-die pocket dungeon with a creeping dark.
# Beat monsters weaker than you (green badge) to level up; stronger or equal ones (red) kill you.
# Reach the gate's level before the dark eats the board from the edges.

const START_LEVEL := 2
const GX := 40
const GY := 330
const GW := 640.0
enum { PLAY, DEAD, CLEAR }

var themes: Array = []
var font: Font = ThemeDB.fallback_font
var tex_cache: Dictionary = {}

var N := 5
var cell := 128.0
var period := 8
var maxd := 2

var floor_n := 1
var level := START_LEVEL
var moves := 0
var coins := 0
var pos := Vector2i.ZERO
var start := Vector2i.ZERO
var stairs := Vector2i.ZERO
var req := 4
var boss_cell := Vector2i(-1, -1)
var mons: Dictionary = {}     # Vector2i -> int level
var items: Dictionary = {}    # Vector2i -> "pot" | "big" | "lamp"
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


func _ready() -> void:
	randomize()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_make_themes()
	var cfg := ConfigFile.new()
	if cfg.load("user://best.cfg") == OK:
		best = int(cfg.get_value("s", "best", 0))
	var args := OS.get_cmdline_user_args()
	if "--test" in args:
		_self_test()
		get_tree().quit()
		return
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
			"wall": Color("3f6b3a"), "accent": Color("7dff9b"), "dark": Color("020a05",),
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
		"...oooo...", "..owwwwo..", ".owvvvvwo.", ".owvhvvwo.", ".owvvvvwo.",
		"..owwwwo..", ".owwwwwwo.", "owwwggwwwo", "owwwwwwwwo", ".owwoowwo.", "..obo.obo..",
	]
	var pal := {"o": Color("10131f"), "w": Color("eef2ff"), "g": Color("aab3d1"), "v": cur_theme()["accent"], "h": Color("ffffff"), "b": Color("5a6280")}
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
			"...oooo...", "...occo...", "....oo....", "...oyyo...", "..oyyyyo..",
			".oyyhyyyo.", ".oyyyyyyo.", ".oyyyyyyo.", "..oyyyyo..", "...oooo...",
		]
		pal["c"] = Color("c9a55a")
		pal["y"] = Color("ffd84f") if kind == "pot" else Color("4fd1ff")
	elif kind == "lamp":
		rows = [
			"....oo....", "...o..o...", "..oooooo..", "..oyyyyo..", "..oyhhyo..",
			"..oyhhyo..", "..oyyyyo..", "..oooooo..", "...oggo...", "..oooooo..",
		]
		pal["y"] = Color("ffe9a0")
		pal["g"] = Color("8a8f9c")
	else:
		rows = [
			"...oooo...", "..oyyyyo..", ".oyyhhyyo.", ".oyhyyyyo.", ".oyhyyyyo.",
			".oyyyyyyo.", ".oyyyyyyo.", "..oyyyyo..", "...oooo...", "..........",
		]
		pal["y"] = Color("ffc93c")
	var tx := _tex_from_rows(rows, pal)
	tex_cache[kind] = tx
	return tx


func _wall_tex(ti: int) -> ImageTexture:
	var key := "wall%d" % ti
	if tex_cache.has(key):
		return tex_cache[key]
	var base: Color = themes[ti]["wall"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 555 + ti
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	for y in 12:
		for x in 12:
			var c := base
			if x == 0 or y == 0 or x == 11 or y == 11:
				c = base.darkened(0.55)
			elif x == 1 or y == 1:
				c = base.lightened(0.2)
			elif x == 10 or y == 10:
				c = base.darkened(0.25)
			elif rng.randf() < 0.12:
				c = base.lightened(0.12)
			img.set_pixel(x, y, c)
	for p in [Vector2i(2, 2), Vector2i(9, 2), Vector2i(2, 9), Vector2i(9, 9)]:
		img.set_pixel(p.x, p.y, base.darkened(0.6))
	var tx := ImageTexture.create_from_image(img)
	tex_cache[key] = tx
	return tx


func _speck_tex(ti: int, variant: int) -> ImageTexture:
	var key := "speck%d_%d" % [ti, variant]
	if tex_cache.has(key):
		return tex_cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 99 + ti * 31 + variant
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for i in 14:
		var c := Color(1, 1, 1, 0.07) if rng.randf() < 0.6 else Color(0, 0, 0, 0.18)
		img.set_pixel(rng.randi_range(0, 15), rng.randi_range(0, 15), c)
	var tx := ImageTexture.create_from_image(img)
	tex_cache[key] = tx
	return tx


func _monster_tex(ti: int, lvl: int, boss: bool) -> ImageTexture:
	var key := "m%d_%d_%d" % [ti, lvl, 1 if boss else 0]
	if tex_cache.has(key):
		return tex_cache[key]
	var cols: Array = themes[ti]["mcols"]
	var body: Color = cols[(lvl - 1) % cols.size()]
	var W := 11 if boss else 9
	var half := W / 2
	var rng := RandomNumberGenerator.new()
	rng.seed = ti * 7919 + lvl * 104729 + (13 if boss else 0)
	var g: Array = []
	for y in W:
		var row: Array = []
		for x in W:
			row.append(0)
		g.append(row)
	for y in range(1, W - 1):
		for x in range(0, half + 1):
			var f := rng.randf() < 0.58
			if x == half and y >= 2 and y <= W - 3:
				f = true
			if f:
				g[y][x] = 1
				g[y][W - 1 - x] = 1
	var ey := 4 if boss else 3
	var ex := half - 2
	for x in range(half - 1, half + 2):
		g[ey][x] = 1
	g[ey][ex] = 2
	g[ey][W - 1 - ex] = 2
	if boss:
		g[0][1] = 1
		g[0][W - 2] = 1
		g[1][1] = 1
		g[1][2] = 1
		g[1][W - 2] = 1
		g[1][W - 3] = 1
		g[2][1] = 1
		g[2][W - 2] = 1
	var S := W + 2
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var outline := Color("0a0c14")
	for y in S:
		for x in S:
			var gx := x - 1
			var gy := y - 1
			var v := 0
			if gx >= 0 and gy >= 0 and gx < W and gy < W:
				v = g[gy][gx]
			if v == 1:
				var c := body
				if gy <= 2:
					c = body.lightened(0.25)
				elif gy >= W - 3:
					c = body.darkened(0.3)
				img.set_pixel(x, y, c)
			elif v == 2:
				img.set_pixel(x, y, Color.WHITE)
			else:
				var near := false
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = gx + d.x
					var ny: int = gy + d.y
					if nx >= 0 and ny >= 0 and nx < W and ny < W and int(g[ny][nx]) != 0:
						near = true
				if near:
					img.set_pixel(x, y, outline)
	# pupils
	img.set_pixel(1 + ex, 1 + ey, Color("151515"))
	img.set_pixel(1 + W - 1 - ex, 1 + ey, Color("151515"))
	var tx := ImageTexture.create_from_image(img)
	tex_cache[key] = tx
	return tx


# ---------- floor generation ----------

func _setup_size() -> void:
	N = 5 if floor_n <= 2 else (6 if floor_n <= 4 else 7)
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
			req = START_LEVEL
			break
	level = START_LEVEL
	moves = 0
	pos = start
	walk.clear()
	pops.clear()
	state = PLAY
	msg = "Reach Lv %d to open the %s" % [req, cur_theme()["gate"]]


func _take(free: Array[Vector2i]) -> Vector2i:
	return free.pop_front()


func _random_layout(tries: int) -> void:
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
		if ring(c) >= 1 and absi(c.x - start.x) + absi(c.y - start.y) >= N - 2:
			stairs = c
			break
	var free: Array[Vector2i] = []
	for c in cells:
		if c != start and c != stairs:
			free.append(c)
	mons.clear()
	items.clear()
	coin_at.clear()
	walls.clear()
	portals.clear()
	boss_cell = Vector2i(-1, -1)
	var nm: int = [4, 6, 8][N - 5] + mini((floor_n - 1) / 4, 1)
	var base := [1, 1, 2, 2, 3, 3, 4, 5, 6, 6]
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
	var np := 2 + (N - 5)
	var nbig := 0 if N == 5 else 1
	var nlamp: int = [0, 1, 2][N - 5]
	for i in np:
		items[_take(free)] = "pot"
	for i in nbig:
		items[_take(free)] = "big"
	for i in nlamp:
		items[_take(free)] = "lamp"
	if N >= 6:
		var a := _take(free)
		var b := _take(free)
		portals[a] = b
		portals[b] = a
	var nw: int = [0, 3, 5][N - 5]
	for i in nw:
		walls[_take(free)] = true
	for i in N + 1:
		coin_at[_take(free)] = true
	var total := nm + np + 2 * nbig
	var ratio := maxf(0.35, 0.6 - 0.05 * (tries / 8))
	req = START_LEVEL + int(total * ratio)


func _solvable() -> bool:
	var list: Array[Vector2i] = []
	var gain: Array[int] = []
	for c in mons:
		list.append(c)
		gain.append(1)
	for c in items:
		list.append(c)
		var k: String = items[c]
		gain.append(1 if k == "pot" else (2 if k == "big" else 0))
	var idx: Dictionary = {}
	for i in list.size():
		idx[list[i]] = i
	var cap := maxd * period
	var seen: Dictionary = {}
	var stack: Array = [[start, 0, 0, START_LEVEL]]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var pops_n := 0
	while stack.size() > 0:
		pops_n += 1
		if pops_n > 40000:
			return false
		var s: Array = stack.pop_back()
		var p: Vector2i = s[0]
		var mask: int = s[1]
		var m: int = s[2]
		var lvl: int = s[3]
		for d in dirs:
			var nc: Vector2i = p + d
			if not in_b(nc) or walls.has(nc):
				continue
			var m2 := mini(m + 1, cap)
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
			var m3 := m2
			if nc == stairs:
				if lvl >= req:
					return true
				continue
			if idx.has(nc) and not (mask & (1 << int(idx[nc]))):
				var bi: int = idx[nc]
				if mons.has(nc):
					if lvl <= int(mons[nc]):
						continue
					lvl2 = lvl + 1
				else:
					lvl2 = lvl + gain[bi]
					if items[nc] == "lamp":
						m3 = maxi(m2 - 4, dp * period)
				mask2 = mask | (1 << bi)
			var key := ((dest.x * N + dest.y) * 32768 + mask2) * 64 + m3
			if seen.has(key):
				continue
			seen[key] = true
			stack.append([dest, mask2, m3, lvl2])
	return false


# ---------- gameplay ----------

func _pop(c: Vector2i, text: String, col: Color) -> void:
	pops.append({"p": _cell_rect(c).get_center(), "s": text, "c": col, "t": t})


func _step(nc: Vector2i) -> void:
	var th := cur_theme()
	var names: Array = th["mons"]
	var landing := nc
	var lamp := false
	if mons.has(nc):
		var lv: int = mons[nc]
		var nm: String = th["boss"] if nc == boss_cell else names[(lv - 1) % names.size()]
		if level > lv:
			mons.erase(nc)
			level += 1
			msg = "Beat %s! Level %d" % [nm, level]
			_pop(nc, "LEVEL UP", Color("6dff9a"))
		else:
			pos = nc
			_die("%s (Lv %d) was too strong" % [nm, lv])
			return
	elif nc == stairs:
		if level < req:
			msg = "%s needs Lv %d" % [th["gate"], req]
			walk.clear()
			return
	elif items.has(nc):
		var kind: String = items[nc]
		items.erase(nc)
		if kind == "pot":
			level += 1
			msg = "%s! Level %d" % [th["pot"], level]
			_pop(nc, "+1", Color("ffd84f"))
		elif kind == "big":
			level += 2
			msg = "Overcharged %s! Level %d" % [th["pot"], level]
			_pop(nc, "+2", Color("4fd1ff"))
		else:
			lamp = true
			msg = "Lantern lit! The dark is held back"
			_pop(nc, "LIGHT", Color("ffe9a0"))
	elif coin_at.has(nc):
		coin_at.erase(nc)
		coins += 1
		msg = "Coin! %d total" % coins
		_pop(nc, "+1 coin", Color("ffc93c"))
	elif portals.has(nc):
		landing = portals[nc]
		if is_dark(landing):
			msg = "The far portal is swallowed by the dark"
			walk.clear()
			return
		msg = "Warp!"
	pos = landing
	var before := depth_for(moves)
	moves = mini(moves + 1, maxd * period)
	if depth_for(moves) > before:
		msg = "The dark swallows the edge!"
	if is_dark(pos):
		_die("Swallowed by the dark")
		return
	if lamp:
		moves = maxi(moves - 4, depth_for(moves) * period)
	if pos == stairs:
		_clear()


func _die(why: String) -> void:
	state = DEAD
	walk.clear()
	var reached := floor_n - 1
	if reached > best:
		best = reached
		var cfg := ConfigFile.new()
		cfg.set_value("s", "best", best)
		cfg.save("user://best.cfg")
	over_title = "YOU DIED"
	over_sub = "%s\nFloors cleared: %d   Best: %d\nCoins: %d" % [why, reached, best, coins]


func _clear() -> void:
	state = CLEAR
	walk.clear()
	over_title = "FLOOR %d CLEAR" % floor_n
	var nxt := floor_n + 1
	over_sub = "Next: floor %d" % nxt
	if (nxt - 1) % 3 == 0:
		over_sub += "\nNew sector ahead!"
	if nxt == 3 or nxt == 5:
		over_sub += "\nThe station gets bigger..."


func _plan(target: Vector2i) -> void:
	if portals.has(target):
		target = portals[target]
		if target == pos:
			return
	# BFS through free cells; portals are edges; monsters are only entered as the final step.
	var dist: Dictionary = {pos: 0}
	var prev: Dictionary = {}
	var via: Dictionary = {}
	var q: Array[Vector2i] = [pos]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while q.size() > 0:
		var c: Vector2i = q.pop_front()
		for d in dirs:
			var n: Vector2i = c + d
			if not in_b(n) or is_dark(n) or walls.has(n) or mons.has(n):
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
	if mons.has(target) or (target == stairs and level < req):
		var bestd := 999
		var bestc := Vector2i(-1, -1)
		for d in dirs:
			var n2: Vector2i = target + d
			if dist.has(n2) and int(dist[n2]) < bestd:
				bestd = int(dist[n2])
				bestc = n2
		if bestc.x < 0:
			msg = "Can't reach that"
			return
		goal = bestc
		attack = true
	elif not dist.has(goal):
		msg = "Can't reach that"
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
	if state == CLEAR:
		floor_n += 1
		_new_floor()
		return
	if state == DEAD:
		floor_n = 1
		coins = 0
		_new_floor()
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


func _draw() -> void:
	if themes.is_empty():
		return
	var ti := tidx()
	var th := cur_theme()
	var acc: Color = th["accent"]
	draw_rect(Rect2(0, 0, 720, 1280), th["bg"])
	# HUD
	_txt(th["name"], Vector2(0, 70), 34, acc)
	_txt("FLOOR %d    BEST %d" % [floor_n, best], Vector2(0, 112), 24, Color(1, 1, 1, 0.6))
	_txt("LV %d" % level, Vector2(40, 205), 72, Color.WHITE, 300.0, HORIZONTAL_ALIGNMENT_LEFT)
	_txt("COINS %d" % coins, Vector2(40, 256), 26, Color("ffc93c"), 300.0, HORIZONTAL_ALIGNMENT_LEFT)
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
	_txt("%s: Lv %d" % [th["gate"], req], Vector2(0, 295), 28, Color.WHITE if level >= req else Color(1, 1, 1, 0.55))
	# grid
	var names: Array = th["mons"]
	var wall_tex := _wall_tex(ti)
	for x in N:
		for y in N:
			var c := Vector2i(x, y)
			var r := _cell_rect(c)
			var col: Color = th["tile"] if (x + y) % 2 == 0 else th["tile2"]
			if is_dark(c):
				draw_rect(r, th["dark"])
				continue
			draw_rect(r.grow(-1.5), col)
			draw_texture_rect(_speck_tex(ti, (x * 3 + y) % 2), r.grow(-1.5), false)
			if ring(c) == depth and warn:
				var a := 0.15 + 0.15 * sin(t * 8.0)
				draw_rect(r.grow(-1.5), Color(1, 0.2, 0.2, a))
			var ctr := r.get_center()
			var bob := sin(t * 3.0 + x * 1.7 + y) * 2.0
			if walls.has(c):
				draw_texture_rect(wall_tex, r.grow(-3), false)
			elif c == stairs:
				var ok := level >= req
				var dc := Color("6dff9a") if ok else Color(1, 1, 1, 0.4)
				var hw := cell * 0.27
				var hh := cell * 0.36
				draw_rect(Rect2(ctr.x - hw, ctr.y - hh, hw * 2, hh * 2), Color(dc.r, dc.g, dc.b, 0.18))
				draw_rect(Rect2(ctr.x - hw, ctr.y - hh, hw * 2, hh * 2), dc, false, 4.0)
				_ctext("Lv %d" % req, ctr, int(cell * 0.24), dc)
			elif mons.has(c):
				var lv: int = mons[c]
				var is_boss := c == boss_cell
				var safe := level > lv
				var mc := Color("49d17a") if safe else Color("ef4b55")
				var sz := cell * (0.92 if is_boss else 0.8)
				draw_circle(ctr + Vector2(0, cell * 0.3), cell * 0.28, Color(0, 0, 0, 0.3))
				_spr(_monster_tex(ti, lv, is_boss), ctr + Vector2(0, bob), sz)
				var bp := Vector2(r.end.x - cell * 0.2, r.position.y + cell * 0.2)
				draw_circle(bp, cell * 0.17, Color("0a0c14"))
				draw_circle(bp, cell * 0.145, mc)
				_ctext(str(lv), bp, int(cell * 0.22), Color.WHITE)
				if N <= 6:
					_txt(names[(lv - 1) % names.size()], Vector2(r.position.x, r.end.y - 5), 13, Color(1, 1, 1, 0.65), cell)
			elif items.has(c):
				var kind: String = items[c]
				_spr(_item_tex(kind), ctr + Vector2(0, bob), cell * 0.55)
				if kind == "pot":
					_txt("+1", Vector2(r.position.x, r.end.y - 6), 15, Color("ffd84f"), cell)
				elif kind == "big":
					_txt("+2", Vector2(r.position.x, r.end.y - 6), 15, Color("4fd1ff"), cell)
				else:
					_txt("light", Vector2(r.position.x, r.end.y - 6), 13, Color("ffe9a0"), cell)
			elif coin_at.has(c):
				_spr(_item_tex("coin"), ctr + Vector2(0, bob), cell * 0.4)
			elif portals.has(c):
				var pc := Color("c07cff")
				draw_arc(ctr, cell * 0.32, t * 3.0, t * 3.0 + PI * 1.3, 18, pc, 4.0)
				draw_arc(ctr, cell * 0.2, -t * 4.0, -t * 4.0 + PI * 1.3, 14, Color("e6c8ff"), 3.0)
				draw_circle(ctr, cell * 0.07, pc)
	# player
	var prc := _cell_rect(pos).get_center()
	draw_circle(prc + Vector2(0, cell * 0.3), cell * 0.25, Color(0, 0, 0, 0.35))
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
	_txt("Green badge = you win the fight. Red = you die.", Vector2(0, 1110), 24, Color(1, 1, 1, 0.55))
	_txt("Beat weaker monsters to level up. Equal level loses!", Vector2(0, 1146), 24, Color(1, 1, 1, 0.55))
	_txt("Tap a tile to walk there. The dark eats the outer ring.", Vector2(0, 1182), 24, Color(1, 1, 1, 0.55))
	if state != PLAY:
		draw_rect(Rect2(0, 0, 720, 1280), Color(0, 0, 0, 0.72))
		var tc := Color("ff5d5d") if state == DEAD else acc
		_txt(over_title, Vector2(0, 560), 64, tc)
		var ly := 640
		for line in over_sub.split("\n"):
			_txt(line, Vector2(0, ly), 30, Color.WHITE)
			ly += 44
		_txt("Tap to continue", Vector2(0, ly + 50), 28, Color(1, 1, 1, 0.6))


# ---------- headless check ----------

func _self_test() -> void:
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
		# sprite generation must not crash
		for lv in range(1, 10):
			_monster_tex(tidx(), lv, lv == 9)
		_player_tex()
		_item_tex("pot")
		_wall_tex(tidx())
	print("TEST DONE unsolvable=%d" % bad)

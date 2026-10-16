extends Control
# Pocket Station - level-or-die pocket dungeon with a creeping dark.
# Beat monsters weaker than you (green) to level up, avoid stronger ones (red),
# reach Level R to open the exit gate before the dark eats the board.

const N := 5
const CELL := 128
const GX := 40
const GY := 330
const PERIOD := 8          # moves between each ring of darkness
const START_LEVEL := 2
enum { PLAY, DEAD, CLEAR }

var themes: Array = []
var font: Font = ThemeDB.fallback_font

var floor_n := 1
var level := START_LEVEL
var moves := 0
var pos := Vector2i.ZERO
var start := Vector2i.ZERO
var stairs := Vector2i.ZERO
var req := 4
var mons: Dictionary = {}   # Vector2i -> int level
var pots: Dictionary = {}   # Vector2i -> true
var walk: Array[Vector2i] = []
var walk_t := 0.0
var state := PLAY
var msg := ""
var over_title := ""
var over_sub := ""
var best := 0
var t := 0.0


func _ready() -> void:
	randomize()
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
			"accent": Color("4fd1ff"), "dark": Color("02030a"),
			"mons": ["Rat-bot", "Drone", "Crawler", "Turret", "Mech", "Warden", "Overseer", "Core AI"],
			"pot": "Power cell", "gate": "Airlock",
		},
		{
			"name": "OVERGROWN GREENHOUSE", "bg": Color("0c1a12"), "tile": Color("183625"), "tile2": Color("1f4530"),
			"accent": Color("7dff9b"), "dark": Color("020a05"),
			"mons": ["Aphid", "Vine", "Beetle", "Spore pod", "Stalker", "Bloom", "Elder root", "Hive heart"],
			"pot": "Nectar", "gate": "Hatch",
		},
		{
			"name": "SMUGGLER HOLD", "bg": Color("1c120c"), "tile": Color("3a2416"), "tile2": Color("472c1b"),
			"accent": Color("ffb14f"), "dark": Color("0a0502"),
			"mons": ["Pest", "Cutpurse", "Bruiser", "Gun-for-hire", "Enforcer", "Captain", "Warlord", "Boss"],
			"pot": "Medkit", "gate": "Cargo door",
		},
	]


func cur_theme() -> Dictionary:
	return themes[((floor_n - 1) / 3) % themes.size()]


func ring(c: Vector2i) -> int:
	return mini(mini(c.x, c.y), mini(N - 1 - c.x, N - 1 - c.y))


func depth_for(m: int) -> int:
	return mini(m / PERIOD, 2)


func is_dark(c: Vector2i) -> bool:
	return ring(c) < depth_for(moves)


# ---------- floor generation ----------

func _new_floor() -> void:
	var tries := 0
	while true:
		tries += 1
		_random_layout()
		if _solvable() or tries > 400:
			break
	level = START_LEVEL
	moves = 0
	pos = start
	walk.clear()
	state = PLAY
	msg = "Reach Lv %d to open the %s" % [req, cur_theme()["gate"]]


func _random_layout() -> void:
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
	stairs = Vector2i(2, 2)
	for c in cells:
		if ring(c) >= 1 and absi(c.x - start.x) + absi(c.y - start.y) >= 3:
			stairs = c
			break
	var free: Array[Vector2i] = []
	for c in cells:
		if c != start and c != stairs:
			free.append(c)
	var nm := mini(4 + (floor_n - 1) / 2, 7)
	var base := [1, 1, 2, 2, 3, 4, 5]
	var bump := (floor_n - 1) / 3
	var levels: Array[int] = []
	for i in nm:
		var lv: int = base[i]
		if lv >= 3:
			lv += bump
		levels.append(lv)
	levels.sort()
	levels.reverse()
	mons.clear()
	pots.clear()
	# strongest monster guards the gate if there is a free neighbour
	var first := true
	for lv in levels:
		var spot := Vector2i(-1, -1)
		if first:
			for c in free:
				if absi(c.x - stairs.x) + absi(c.y - stairs.y) == 1:
					spot = c
					break
			first = false
		if spot.x < 0:
			spot = free[0]
		free.erase(spot)
		mons[spot] = lv
	for i in 2:
		var spot2: Vector2i = free[0]
		free.erase(spot2)
		pots[spot2] = true
	req = START_LEVEL + int((nm + 2) * 0.6)


func _solvable() -> bool:
	var items: Array[Vector2i] = []
	for c in mons:
		items.append(c)
	for c in pots:
		items.append(c)
	var idx: Dictionary = {}
	for i in items.size():
		idx[items[i]] = i
	var seen: Dictionary = {}
	var stack: Array = [[start, 0, 0]]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while stack.size() > 0:
		var s: Array = stack.pop_back()
		var p: Vector2i = s[0]
		var mask: int = s[1]
		var m: int = s[2]
		var pc := 0
		for i in items.size():
			if mask & (1 << i):
				pc += 1
		var lvl := START_LEVEL + pc
		for d in dirs:
			var nc: Vector2i = p + d
			if nc.x < 0 or nc.y < 0 or nc.x >= N or nc.y >= N:
				continue
			var m2 := mini(m + 1, 2 * PERIOD)
			if ring(nc) < depth_for(m2):
				continue
			var mask2 := mask
			if nc == stairs:
				if lvl >= req:
					return true
				continue
			if idx.has(nc) and not (mask & (1 << int(idx[nc]))):
				if mons.has(nc) and lvl <= int(mons[nc]):
					continue
				mask2 = mask | (1 << int(idx[nc]))
			var key := ((nc.x * N + nc.y) * 1024 + mask2) * 20 + m2
			if seen.has(key):
				continue
			seen[key] = true
			stack.append([nc, mask2, m2])
	return false


# ---------- gameplay ----------

func _step(nc: Vector2i) -> void:
	var th := cur_theme()
	var names: Array = th["mons"]
	if mons.has(nc):
		var lv: int = mons[nc]
		if level > lv:
			mons.erase(nc)
			level += 1
			msg = "Beat %s! Level %d" % [names[(lv - 1) % names.size()], level]
		else:
			pos = nc
			_die("%s (Lv %d) was too strong" % [names[(lv - 1) % names.size()], lv])
			return
	elif nc == stairs:
		if level < req:
			msg = "%s needs Lv %d" % [th["gate"], req]
			walk.clear()
			return
	elif pots.has(nc):
		pots.erase(nc)
		level += 1
		msg = "%s! Level %d" % [th["pot"], level]
	pos = nc
	var before := depth_for(moves)
	moves = mini(moves + 1, 2 * PERIOD)
	if depth_for(moves) > before:
		msg = "The dark swallows the edge!"
	if is_dark(pos):
		_die("Swallowed by the dark")
		return
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
	over_sub = "%s\nFloors cleared: %d   Best: %d" % [why, reached, best]


func _clear() -> void:
	state = CLEAR
	walk.clear()
	over_title = "FLOOR %d CLEAR" % floor_n
	var nxt := floor_n + 1
	over_sub = "Next: floor %d" % nxt
	if (nxt - 1) % 3 == 0:
		over_sub += "\nNew sector ahead!"


func _plan(target: Vector2i) -> void:
	# BFS through free cells; monsters are only entered as the final step.
	var dist: Dictionary = {pos: 0}
	var prev: Dictionary = {}
	var q: Array[Vector2i] = [pos]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while q.size() > 0:
		var c: Vector2i = q.pop_front()
		for d in dirs:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= N or n.y >= N or dist.has(n) or is_dark(n):
				continue
			if mons.has(n):
				continue
			if n == stairs and level < req:
				continue
			dist[n] = int(dist[c]) + 1
			prev[n] = c
			q.append(n)
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
		_new_floor()
		return
	var cx := int((p.x - GX) / CELL)
	var cy := int((p.y - GY) / CELL)
	if p.x < GX or p.y < GY or cx >= N or cy >= N:
		return
	var target := Vector2i(cx, cy)
	if target == pos or is_dark(target):
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
	queue_redraw()


# ---------- drawing ----------

func _txt(s: String, p: Vector2, size: int, col: Color, w := 720.0, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	draw_string(font, p, s, align, w, size, col)


func _cell_rect(c: Vector2i) -> Rect2:
	return Rect2(GX + c.x * CELL, GY + c.y * CELL, CELL, CELL)


func _draw() -> void:
	if themes.is_empty() or false:
		return
	var th := cur_theme()
	var acc: Color = th["accent"]
	draw_rect(Rect2(0, 0, 720, 1280), th["bg"])
	# HUD
	_txt(th["name"], Vector2(0, 70), 34, acc)
	_txt("FLOOR %d    BEST %d" % [floor_n, best], Vector2(0, 112), 24, Color(1, 1, 1, 0.6))
	_txt("LV %d" % level, Vector2(40, 215), 72, Color.WHITE, 300.0, HORIZONTAL_ALIGNMENT_LEFT)
	var depth := depth_for(moves)
	var dark_txt := "DARK FINAL"
	var frac := 1.0
	var left := 0
	if moves < 2 * PERIOD:
		left = (depth + 1) * PERIOD - moves
		frac = 1.0 - float(left) / PERIOD
		dark_txt = "DARK IN %d" % left
	var warn := moves < 2 * PERIOD and left <= 3
	var dcol := Color("ff5d5d") if warn else acc
	_txt(dark_txt, Vector2(360, 200), 44, dcol, 320.0, HORIZONTAL_ALIGNMENT_RIGHT)
	draw_rect(Rect2(380, 218, 300, 14), Color(1, 1, 1, 0.12))
	draw_rect(Rect2(380, 218, 300 * frac, 14), dcol)
	_txt("%s: Lv %d" % [th["gate"], req], Vector2(0, 285), 28, Color.WHITE if level >= req else Color(1, 1, 1, 0.55))
	# grid
	var names: Array = th["mons"]
	for x in N:
		for y in N:
			var c := Vector2i(x, y)
			var r := _cell_rect(c)
			var col: Color = th["tile"] if (x + y) % 2 == 0 else th["tile2"]
			if is_dark(c):
				draw_rect(r, th["dark"])
				continue
			draw_rect(r.grow(-2), col)
			if ring(c) == depth and warn:
				var a := 0.15 + 0.15 * sin(t * 8.0)
				draw_rect(r.grow(-2), Color(1, 0.2, 0.2, a))
			var ctr := r.get_center()
			if c == stairs:
				var ok := level >= req
				var dc := Color("6dff9a") if ok else Color(1, 1, 1, 0.35)
				draw_rect(Rect2(ctr.x - 34, ctr.y - 44, 68, 88), dc, false, 5.0)
				draw_rect(Rect2(ctr.x - 26, ctr.y - 36, 52, 72), Color(dc.r, dc.g, dc.b, 0.18))
				_txt("Lv %d" % req, Vector2(r.position.x, ctr.y + 10), 30, dc, CELL)
			elif mons.has(c):
				var lv: int = mons[c]
				var safe := level > lv
				var mc := Color("49d17a") if safe else Color("ef4b55")
				var pts := PackedVector2Array()
				for i in 20:
					var ang := TAU * i / 20.0
					var rad := 50.0 if i % 2 == 0 else 38.0
					pts.append(ctr + Vector2(cos(ang), sin(ang)) * rad)
				draw_colored_polygon(pts, Color(mc.r, mc.g, mc.b, 0.35))
				draw_circle(ctr, 34, mc)
				_txt(str(lv), Vector2(r.position.x, ctr.y + 17), 48, Color.WHITE, CELL)
				_txt(names[(lv - 1) % names.size()], Vector2(r.position.x, r.end.y - 6), 15, Color(1, 1, 1, 0.7), CELL)
			elif pots.has(c):
				var dm := PackedVector2Array([ctr + Vector2(0, -26), ctr + Vector2(22, 0), ctr + Vector2(0, 26), ctr + Vector2(-22, 0)])
				draw_colored_polygon(dm, Color("ffd84f"))
				_txt("+1", Vector2(r.position.x, ctr.y + 8), 22, Color("3a2b00"), CELL)
	# player
	var pc := _cell_rect(pos).get_center()
	draw_circle(pc, 30, Color("f4f7ff"))
	draw_rect(Rect2(pc.x - 18, pc.y - 12, 36, 18), acc)
	draw_circle(pc, 30, Color(1, 1, 1, 0.9), false, 3.0)
	# footer
	_txt(msg, Vector2(0, 1030), 30, Color.WHITE)
	_txt("Green = you win the fight. Red = you die.", Vector2(0, 1110), 24, Color(1, 1, 1, 0.55))
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
	for f in range(1, 13):
		floor_n = f
		var tries := 0
		var ok := false
		while tries < 400 and not ok:
			tries += 1
			_random_layout()
			ok = _solvable()
		print("floor %d theme %s tries %d solvable %s req %d mons %d" % [f, cur_theme()["name"], tries, ok, req, mons.size()])
		if not ok:
			bad += 1
	print("TEST DONE unsolvable=%d" % bad)

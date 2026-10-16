extends Node2D
# Tap and Tumble - tap blocks to pop them and guide the ball into the cup.
# Everything is built in code from the level data below, so adding a level
# means adding one entry to _make_levels().

const W := 720.0
const H := 1280.0
const BALL_R := 26.0
const LAYER_WORLD := 1
const LAYER_BLOCK := 2
const LAYER_BALL := 4

# ---------------------------------------------------------------- views ----

class Background extends Node2D:
	func _draw() -> void:
		var top := Color("1d2346")
		var bot := Color("111530")
		draw_polygon(
			PackedVector2Array([Vector2(-300, -300), Vector2(1020, -300), Vector2(1020, 1580), Vector2(-300, 1580)]),
			PackedColorArray([top, top, bot, bot]))


class BlockView extends Node2D:
	var size := Vector2(10, 10)
	var color := Color.WHITE
	var solid := false
	func _draw() -> void:
		var r := Rect2(-size * 0.5, size)
		draw_rect(r, color)
		draw_rect(r, color.darkened(0.4), false, 4.0)
		if not solid:
			var hl := Rect2(r.position + Vector2(6, 6), Vector2(maxf(size.x - 12.0, 2.0), minf(8.0, maxf(size.y - 12.0, 2.0))))
			draw_rect(hl, color.lightened(0.35))


class BallView extends Node2D:
	const R := 26.0
	func _draw() -> void:
		draw_circle(Vector2.ZERO, R, Color("fff1cf"))
		draw_arc(Vector2.ZERO, R - 2.0, 0.0, TAU, 40, Color("c9a55a"), 4.0)
		draw_circle(Vector2(12, 0), 6.0, Color("c9a55a"))
		draw_circle(Vector2(-7, -9), 5.0, Color.WHITE)


class GoalGlow extends Node2D:
	var t := 0.0
	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
	func _draw() -> void:
		var p := 0.5 + 0.5 * sin(t * 3.0)
		draw_rect(Rect2(-55, -50, 110, 100), Color(0.3, 1.0, 0.55, 0.10 + 0.10 * p))


class PopFx extends Node2D:
	var color := Color.WHITE
	var t := 0.0
	func _process(delta: float) -> void:
		t += delta * 3.2
		if t >= 1.0:
			queue_free()
		else:
			queue_redraw()
	func _draw() -> void:
		var c := color
		c.a = 1.0 - t
		draw_arc(Vector2.ZERO, 18.0 + 70.0 * t, 0.0, TAU, 32, c, 6.0 * (1.0 - t) + 1.0)


class StarsView extends Control:
	var count := 0
	func _draw() -> void:
		for i in 3:
			var c := Vector2(60 + i * 120, 60)
			var pts := PackedVector2Array()
			for k in 10:
				var ang := -PI / 2.0 + k * PI / 5.0
				var rad := 52.0 if k % 2 == 0 else 22.0
				pts.append(c + Vector2(cos(ang), sin(ang)) * rad)
			if i < count:
				draw_colored_polygon(pts, Color("ffd24a"))
			else:
				pts.append(pts[0])
				draw_polyline(pts, Color("6b7399"), 4.0)

# ----------------------------------------------------------------- state ---

var MATS := {
	"wood": {"color": Color("e8a04c"), "fric": 0.8, "bounce": 0.05},
	"ice": {"color": Color("8fdcff"), "fric": 0.03, "bounce": 0.05},
	"rubber": {"color": Color("ff6fa5"), "fric": 0.9, "bounce": 0.9},
	"stone": {"color": Color("4b5578"), "fric": 0.7, "bounce": 0.05},
	"goal": {"color": Color("3fd28a"), "fric": 0.7, "bounce": 0.05},
}

var LEVELS: Array = []
var level_idx := 0
var world: Node2D
var level_root: Node2D
var all_blocks: Array = []
var balls: Array = []
var goals: Array = []
var taps := 0
var state := "play"          # play | won | lost
var lose_reason := ""        # fell | stuck
var goal_time := 0.0
var stuck_time := 0.0
var phys_frames := 0
var run_id := 0
var test_mode := false

var ui: CanvasLayer
var title_lbl: Label
var taps_lbl: Label
var hint_lbl: Label
var overlay: Control
var stars: StarsView
var over_info: Label

# ----------------------------------------------------------- level data ----

func _fx(x: float, y: float, w: float, h: float, rot := 0.0, mat := "stone") -> Dictionary:
	return {"t": "fix", "x": x, "y": y, "w": w, "h": h, "rot": rot, "m": mat}

func _bk(x: float, y: float, w: float, h: float, rot := 0.0, mat := "wood") -> Dictionary:
	return {"t": "blk", "x": x, "y": y, "w": w, "h": h, "rot": rot, "m": mat}

func _ball(x: float, y: float) -> Dictionary:
	return {"t": "ball", "x": x, "y": y}

func _goal(x: float, y: float) -> Dictionary:
	return {"t": "goal", "x": x, "y": y}

# Point on top of a fixed ramp: s = distance along the ramp from its centre,
# lift = distance above the surface.
func _ramp_point(r: Dictionary, s: float, lift: float) -> Vector2:
	var a := deg_to_rad(float(r["rot"]))
	var tv := Vector2(cos(a), sin(a))
	var nv := Vector2(sin(a), -cos(a))
	return Vector2(float(r["x"]), float(r["y"])) + tv * s + nv * (float(r["h"]) * 0.5 + lift)

func _bk_on(r: Dictionary, s: float, w: float, h: float, mat := "wood") -> Dictionary:
	var p := _ramp_point(r, s, h * 0.5)
	return _bk(p.x, p.y, w, h, float(r["rot"]), mat)

func _ball_on(r: Dictionary, s: float) -> Dictionary:
	var p := _ramp_point(r, s, BALL_R)
	return _ball(p.x, p.y)

func _make_levels() -> Array:
	var out: Array = []

	# 1 - Bridge: pop the plank under the ball.
	out.append({"name": "Bridge", "hint": "Tap a block to pop it.", "par": 1, "items": [
		_fx(130, 520, 260, 40), _fx(590, 520, 260, 40),
		_bk(360, 485, 240, 30), _ball(360, 444), _goal(360, 900)]})

	# 2 - Slide: let the ball roll down the ramp.
	var r2 := _fx(250, 520, 420, 30, 18.0)
	out.append({"name": "Slide", "hint": "Get the ball into the cup.", "par": 1, "items": [
		r2, _bk_on(r2, 170.0, 40.0, 80.0), _bk_on(r2, 60.0, 40.0, 40.0),
		_ball_on(r2, 124.0), _goal(595, 950)]})

	# 3 - Zigzag: two ramps, two stoppers.
	var r3a := _fx(240, 380, 440, 30, 14.0)
	var r3b := _fx(480, 760, 440, 30, -14.0)
	out.append({"name": "Zigzag", "hint": "Free the ball, one stopper at a time.", "par": 2, "items": [
		r3a, r3b, _bk_on(r3a, 185.0, 40.0, 80.0), _ball_on(r3a, 139.0),
		_bk_on(r3b, -185.0, 40.0, 80.0), _goal(130, 1090)]})

	# 4 - Boing: pink pads are bouncy.
	out.append({"name": "Boing", "hint": "Pink pads are bouncy.", "par": 1, "items": [
		_fx(125, 450, 250, 40), _fx(595, 450, 250, 40),
		_bk(360, 415, 260, 30), _ball(360, 389),
		_fx(360, 720, 160, 24, 25.0, "rubber"), _goal(610, 1060)]})

	return out

# ------------------------------------------------------------ lifecycle ----

func _ready() -> void:
	LEVELS = _make_levels()
	add_child(Background.new())
	world = Node2D.new()
	add_child(world)
	_build_ui()
	if "--test" in OS.get_cmdline_user_args():
		test_mode = true
		run_tests.call_deferred()
		return
	build_level(0)


func _physics_process(delta: float) -> void:
	phys_frames += 1
	if state != "play" or balls.is_empty():
		return

	var all_in := true
	for b in balls:
		var inside := false
		for g in goals:
			if g.overlaps_body(b):
				inside = true
		if not inside:
			all_in = false
	if all_in:
		goal_time += delta
		if goal_time >= 0.6:
			_win()
			return
	else:
		goal_time = 0.0

	for b in balls:
		var p: Vector2 = b.global_position
		if p.y > H + 150.0 or p.x < -150.0 or p.x > W + 150.0:
			_lose("Oops! Try again.", "fell")
			return

	# Nothing left to tap and everything has come to rest outside the cup.
	if taps > 0 and not all_in:
		var resting := true
		for o in balls:
			if not o.sleeping:
				resting = false
		for o in all_blocks:
			if is_instance_valid(o):
				resting = false   # a block is still available to tap
		if resting:
			stuck_time += delta
			if stuck_time >= 1.2:
				_lose("Stuck! Starting over.", "stuck")
		else:
			stuck_time = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if state == "play":
			tap_at(get_global_mouse_position())

# ---------------------------------------------------------------- build ----

func build_level(i: int) -> void:
	if level_root:
		level_root.free()
	level_root = Node2D.new()
	world.add_child(level_root)
	all_blocks.clear()
	balls.clear()
	goals.clear()
	taps = 0
	state = "play"
	lose_reason = ""
	goal_time = 0.0
	stuck_time = 0.0
	level_idx = i
	for it in LEVELS[i]["items"]:
		match it["t"]:
			"fix":
				_add_fixed(it)
			"blk":
				_add_block(it)
			"ball":
				_add_ball(it)
			"goal":
				_add_goal(it)
	title_lbl.text = "Level %d: %s" % [i + 1, LEVELS[i]["name"]]
	hint_lbl.text = LEVELS[i]["hint"]
	_update_hud()


func _pm(mat: String) -> PhysicsMaterial:
	var pm := PhysicsMaterial.new()
	pm.friction = MATS[mat]["fric"]
	pm.bounce = MATS[mat]["bounce"]
	return pm


func _rect_shape(size: Vector2) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	cs.shape = rs
	return cs


func _view(size: Vector2, color: Color, solid: bool) -> BlockView:
	var v := BlockView.new()
	v.size = size
	v.color = color
	v.solid = solid
	return v


func _add_fixed(it: Dictionary, parent: Node = null) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(it["x"], it["y"])
	body.rotation_degrees = float(it["rot"])
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	body.physics_material_override = _pm(it["m"])
	var size := Vector2(it["w"], it["h"])
	body.add_child(_rect_shape(size))
	body.add_child(_view(size, MATS[it["m"]]["color"], true))
	(parent if parent else level_root).add_child(body)


func _add_block(it: Dictionary) -> void:
	var rb := RigidBody2D.new()
	rb.position = Vector2(it["x"], it["y"])
	rb.rotation_degrees = float(it["rot"])
	rb.collision_layer = LAYER_BLOCK
	rb.collision_mask = LAYER_WORLD | LAYER_BLOCK | LAYER_BALL
	rb.physics_material_override = _pm(it["m"])
	var size := Vector2(it["w"], it["h"])
	rb.mass = maxf(size.x * size.y / 500.0, 1.0)
	rb.add_child(_rect_shape(size))
	rb.add_child(_view(size, MATS[it["m"]]["color"], false))
	rb.set_meta("col", MATS[it["m"]]["color"])
	level_root.add_child(rb)
	all_blocks.append(rb)


func _add_ball(it: Dictionary) -> void:
	var rb := RigidBody2D.new()
	rb.position = Vector2(it["x"], it["y"])
	rb.collision_layer = LAYER_BALL
	rb.collision_mask = LAYER_WORLD | LAYER_BLOCK | LAYER_BALL
	rb.mass = 1.5
	rb.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	rb.linear_damp = 0.05
	rb.angular_damp = 0.3
	var pm := PhysicsMaterial.new()
	pm.friction = 0.6
	pm.bounce = 0.05
	rb.physics_material_override = pm
	var cs := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = BALL_R
	cs.shape = circ
	rb.add_child(cs)
	rb.add_child(BallView.new())
	level_root.add_child(rb)
	balls.append(rb)


func _add_goal(it: Dictionary) -> void:
	var g := Node2D.new()
	g.position = Vector2(it["x"], it["y"])
	level_root.add_child(g)
	g.add_child(GoalGlow.new())
	# Cup: interior is 110 wide and 100 tall, centred on the goal position.
	_add_fixed({"x": 0, "y": 59, "w": 146, "h": 18, "rot": 0.0, "m": "goal"}, g)
	_add_fixed({"x": -64, "y": 9, "w": 18, "h": 118, "rot": 0.0, "m": "goal"}, g)
	_add_fixed({"x": 64, "y": 9, "w": 18, "h": 118, "rot": 0.0, "m": "goal"}, g)
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = LAYER_BALL
	area.position = Vector2(0, 15)
	area.add_child(_rect_shape(Vector2(100, 70)))
	g.add_child(area)
	goals.append(area)

# ---------------------------------------------------------------- play -----

func tap_at(p: Vector2) -> void:
	var space := get_world_2d().direct_space_state
	var q := PhysicsPointQueryParameters2D.new()
	q.position = p
	q.collision_mask = LAYER_BLOCK
	q.collide_with_bodies = true
	var hits := space.intersect_point(q, 8)
	var target: Node = null
	if hits.size() > 0:
		target = hits[0]["collider"]
	else:
		# Be forgiving to fat fingers: nearest block within a small radius.
		var sq := PhysicsShapeQueryParameters2D.new()
		var circ := CircleShape2D.new()
		circ.radius = 24.0
		sq.shape = circ
		sq.transform = Transform2D(0.0, p)
		sq.collision_mask = LAYER_BLOCK
		var best := 1.0e9
		for e in space.intersect_shape(sq, 8):
			var d: float = e["collider"].global_position.distance_to(p)
			if d < best:
				best = d
				target = e["collider"]
	if target:
		remove_block(target)


func remove_block(b: Node) -> void:
	if state != "play" or not is_instance_valid(b):
		return
	taps += 1
	var pop := PopFx.new()
	pop.position = b.global_position
	pop.color = b.get_meta("col")
	level_root.add_child(pop)
	b.queue_free()
	# Wake everything so nothing is left floating on the removed block.
	for o in all_blocks + balls:
		if is_instance_valid(o) and o != b:
			o.sleeping = false
	stuck_time = 0.0
	_update_hud()


func _win() -> void:
	state = "won"
	if test_mode:
		return
	var par: int = LEVELS[level_idx]["par"]
	var n := 3 if taps <= par else (2 if taps == par + 1 else 1)
	stars.count = n
	stars.queue_redraw()
	over_info.text = "%d tap%s  (par %d)" % [taps, "" if taps == 1 else "s", par]
	overlay.visible = true


func _lose(msg: String, why: String) -> void:
	state = "lost"
	lose_reason = why
	if test_mode:
		return
	hint_lbl.text = msg
	get_tree().create_timer(1.0).timeout.connect(_auto_restart.bind(run_id))


func _auto_restart(id: int) -> void:
	if id == run_id and state == "lost":
		restart()


func restart() -> void:
	run_id += 1
	overlay.visible = false
	build_level(level_idx)


func go_level(i: int) -> void:
	level_idx = posmod(i, LEVELS.size())
	restart()


func _update_hud() -> void:
	taps_lbl.text = "Taps %d    Par %d" % [taps, LEVELS[level_idx]["par"]]

# ------------------------------------------------------------------ UI -----

func _label(pos: Vector2, size: Vector2, fsize: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, pos: Vector2, size: Vector2, cb: Callable, fsize := 34) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", fsize)
	b.add_theme_color_override("font_color", Color("f2f4ff"))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	var cols := {"normal": Color("38426e"), "hover": Color("445084"), "pressed": Color("5663a0")}
	for k in cols:
		var sb := StyleBoxFlat.new()
		sb.bg_color = cols[k]
		sb.set_corner_radius_all(20)
		b.add_theme_stylebox_override(k, sb)
	b.pressed.connect(cb)
	return b


func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	title_lbl = _label(Vector2(0, 28), Vector2(W, 60), 42, Color("f2f4ff"))
	taps_lbl = _label(Vector2(0, 86), Vector2(W, 44), 30, Color("9aa5d6"))
	hint_lbl = _label(Vector2(40, 130), Vector2(W - 80, 70), 30, Color("ffd9a0"))
	ui.add_child(title_lbl)
	ui.add_child(taps_lbl)
	ui.add_child(hint_lbl)
	ui.add_child(_button("<", Vector2(40, 1170), Vector2(110, 80), func() -> void: go_level(level_idx - 1)))
	ui.add_child(_button("Restart", Vector2(240, 1170), Vector2(240, 80), func() -> void: restart()))
	ui.add_child(_button(">", Vector2(570, 1170), Vector2(110, 80), func() -> void: go_level(level_idx + 1)))

	overlay = Control.new()
	overlay.position = Vector2.ZERO
	overlay.size = Vector2(W, H)
	overlay.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.size = Vector2(W, H)
	overlay.add_child(dim)
	var panel := Panel.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color("232a52")
	ps.set_corner_radius_all(32)
	panel.add_theme_stylebox_override("panel", ps)
	panel.position = Vector2(110, 380)
	panel.size = Vector2(500, 470)
	overlay.add_child(panel)
	overlay.add_child(_label(Vector2(110, 410), Vector2(500, 80), 56, Color("ffffff")))
	(overlay.get_child(overlay.get_child_count() - 1) as Label).text = "Cleared!"
	stars = StarsView.new()
	stars.position = Vector2(180, 500)
	stars.size = Vector2(360, 120)
	overlay.add_child(stars)
	over_info = _label(Vector2(110, 630), Vector2(500, 50), 32, Color("9aa5d6"))
	overlay.add_child(over_info)
	overlay.add_child(_button("Next", Vector2(170, 700), Vector2(380, 80), func() -> void: go_level(level_idx + 1), 40))
	overlay.add_child(_button("Replay", Vector2(170, 790 - 0), Vector2(380, 50), func() -> void: restart(), 28))
	ui.add_child(overlay)

# ---------------------------------------------------------------- tests ----
# Headless solver: godot --headless --fixed-fps 60 --path godot-project -- --test
# Tries every ordered sequence of up to 3 taps per level, so each level is
# proven solvable (and par is computed) before it ships.

func _wait(n: int) -> void:
	var target := phys_frames + n
	while phys_frames < target:
		await get_tree().process_frame


func _sequences(n: int, maxlen: int) -> Array:
	var out: Array = []
	var cur: Array = [[]]
	for _l in range(1, maxlen + 1):
		var nxt: Array = []
		for s in cur:
			for k in range(n):
				if not s.has(k):
					var s2: Array = s.duplicate()
					s2.append(k)
					nxt.append(s2)
		out.append_array(nxt)
		cur = nxt
	return out


func _trial(li: int, seq: Array, gap: int) -> Dictionary:
	build_level(li)
	await _wait(45)
	for k in seq:
		if state != "play":
			break
		remove_block(all_blocks[k])
		await _wait(gap)
	var guard := 0
	while state == "play" and guard < 480:
		await _wait(10)
		guard += 10
	var bp := Vector2.ZERO
	if balls.size() > 0:
		bp = balls[0].global_position
	return {"state": state, "why": lose_reason, "taps": taps, "ball": bp}


func run_tests() -> void:
	var total_fail := 0
	for li in LEVELS.size():
		var n := 0
		build_level(li)
		n = all_blocks.size()
		var seqs := _sequences(n, 3)
		var wins: Dictionary = {}
		var trials := 0
		for s in seqs:
			var r: Dictionary = await _trial(li, s, 30)
			trials += 1
			if r["state"] == "won":
				var used: Array = s.slice(0, int(r["taps"]))
				wins[str(used)] = used
		var best := 99
		for k in wins:
			best = mini(best, (wins[k] as Array).size())
		var robust := 0
		var par_wins: Array = []
		for k in wins:
			if (wins[k] as Array).size() == best:
				par_wins.append(wins[k])
		for s in par_wins:
			var ok := true
			for gap in [12, 75]:
				var r2: Dictionary = await _trial(li, s, gap)
				if r2["state"] != "won":
					ok = false
					print("   seq %s fails at gap %d -> %s/%s ball=%s" % [str(s), gap, r2["state"], r2["why"], str(r2["ball"])])
			if ok:
				robust += 1
		var declared: int = LEVELS[li]["par"]
		var line := "LEVEL %d %s: removable=%d trials=%d winning_seqs=%d best=%d robust_best=%d declared_par=%d  e.g. %s" % [
			li + 1, LEVELS[li]["name"], n, trials, wins.size(), best, robust, declared, str(par_wins.slice(0, 3))]
		print(line)
		if wins.is_empty() or robust == 0 or best != declared:
			total_fail += 1
			print("  !! needs attention")
		if wins.is_empty():
			# Help tuning: where does the ball end up for each single tap?
			for k in range(n):
				var r3: Dictionary = await _trial(li, [k], 30)
				print("   tap [%d] -> %s ball=%s" % [k, r3["state"], str(r3["ball"])])
	print("TESTS_DONE problems=%d" % total_fail)
	get_tree().quit()

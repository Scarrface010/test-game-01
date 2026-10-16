extends Node2D
# Tap and Tumble v2 - draw beams, bouncers and heavy weights, press GO, and let
# the physics play out. Levels are data (see _make_levels); every level ships
# with a known solution that the headless solver checks.

const W := 720.0
const H := 1280.0
const BALL_R := 26.0
const STROKE_R := 9.0
const LAYER_WORLD := 1
const LAYER_BODY := 2
const LAYER_BALL := 4
const CUP_IW := 130.0     # cup interior width
const CUP_IH := 120.0     # cup interior height
const RUN_TIMEOUT := 15.0

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


class StrokeView extends Node2D:
	var pts := PackedVector2Array()
	var color := Color.WHITE
	var wid := 18.0
	func _draw() -> void:
		if pts.size() == 0:
			return
		if pts.size() == 1:
			draw_circle(pts[0], wid * 0.5, color)
			return
		draw_polyline(pts, color.darkened(0.45), wid + 5.0, true)
		for p in pts:
			draw_circle(p, wid * 0.5 + 2.5, color.darkened(0.45))
		draw_polyline(pts, color, wid, true)
		for p in pts:
			draw_circle(p, wid * 0.5, color)


class PendView extends Node2D:
	var length := 300.0
	var radius := 40.0
	func _draw() -> void:
		draw_line(Vector2.ZERO, Vector2(0, length), Color("9aa5d6"), 8.0, true)
		draw_circle(Vector2(0, length), radius + 3.0, Color("1c2140"))
		draw_circle(Vector2(0, length), radius, Color("7d8bd0"))
		draw_circle(Vector2(-radius * 0.3, length - radius * 0.3), radius * 0.28, Color("b9c4f5"))
		draw_circle(Vector2.ZERO, 11.0, Color("f2f4ff"))


class BallView extends Node2D:
	const R := 26.0
	func _draw() -> void:
		draw_circle(Vector2.ZERO, R, Color("fff1cf"))
		draw_arc(Vector2.ZERO, R - 2.0, 0.0, TAU, 40, Color("c9a55a"), 4.0)
		draw_circle(Vector2(12, 0), 6.0, Color("c9a55a"))
		draw_circle(Vector2(-7, -9), 5.0, Color.WHITE)


class GoalGlow extends Node2D:
	var t := 0.0
	var iw := 130.0
	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
	func _draw() -> void:
		var p := 0.5 + 0.5 * sin(t * 3.0)
		draw_rect(Rect2(-iw * 0.5, -60, iw, 120), Color(0.3, 1.0, 0.55, 0.10 + 0.10 * p))


class PivotView extends Node2D:
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 12.0, Color("1c2140"))
		draw_circle(Vector2.ZERO, 8.0, Color("f2f4ff"))


class Preview extends Node2D:
	var pts := PackedVector2Array()
	var color := Color.WHITE
	func _draw() -> void:
		if pts.size() == 0:
			return
		var c := color
		c.a = 0.75
		if pts.size() == 1:
			draw_circle(pts[0], 9.0, c)
			return
		draw_polyline(pts, c, 18.0, true)
		for p in pts:
			draw_circle(p, 9.0, c)


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

# ----------------------------------------------------------------- data ----

var MATS := {
	"stone": {"color": Color("4b5578"), "fric": 0.7, "bounce": 0.05, "dens": 1.0},
	"wood": {"color": Color("e8a04c"), "fric": 0.8, "bounce": 0.05, "dens": 1.0},
	"heavy": {"color": Color("8a93b8"), "fric": 0.8, "bounce": 0.02, "dens": 3.0},
	"ice": {"color": Color("8fdcff"), "fric": 0.03, "bounce": 0.05, "dens": 1.0},
	"rubber": {"color": Color("ff6fa5"), "fric": 0.9, "bounce": 0.9, "dens": 1.0},
	"goal": {"color": Color("3fd28a"), "fric": 0.7, "bounce": 0.05, "dens": 1.0},
}

# Ink types the player can draw with.
var INKS := {
	"beam": {"name": "Beam", "color": Color("c9d3ff"), "static": true, "fric": 0.7, "bounce": 0.05, "cost": 1.0, "dens": 0.0},
	"bounce": {"name": "Bouncer", "color": Color("ff6fa5"), "static": true, "fric": 0.9, "bounce": 0.95, "cost": 1.5, "dens": 0.0},
	"ice": {"name": "Ice", "color": Color("8fdcff"), "static": true, "fric": 0.02, "bounce": 0.05, "cost": 1.0, "dens": 0.0},
	"weight": {"name": "Weight", "color": Color("e8a04c"), "static": false, "fric": 0.8, "bounce": 0.05, "cost": 1.0, "dens": 0.08},
}

var LEVELS: Array = []
var level_idx := 0
var world: Node2D
var level_root: Node2D
var balls: Array = []
var goals: Array = []
var strokes: Array = []          # [{"ink": String, "pts": PackedVector2Array}]
var cur_ink := "beam"
var ink_used := 0.0
var phase := "setup"             # setup | run | won | lost
var lose_reason := ""
var goal_time := 0.0
var stuck_time := 0.0
var run_frames := 0
var phys_frames := 0
var test_mode := false
var trace := false

var drawing := false
var cur_pts := PackedVector2Array()
var preview: Preview

var ui: CanvasLayer
var title_lbl: Label
var ink_lbl: Label
var hint_lbl: Label
var ink_bar_fill: ColorRect
var go_btn: Button
var ink_btn: Button
var overlay: Control
var stars: StarsView
var over_info: Label

# ----------------------------------------------------------- level data ----

func _fx(x: float, y: float, w: float, h: float, rot := 0.0, mat := "stone") -> Dictionary:
	return {"t": "fix", "x": x, "y": y, "w": w, "h": h, "rot": rot, "m": mat}

func _bk(x: float, y: float, w: float, h: float, rot := 0.0, mat := "wood") -> Dictionary:
	return {"t": "blk", "x": x, "y": y, "w": w, "h": h, "rot": rot, "m": mat}

func _see(x: float, y: float, w: float, h: float, rot := 0.0) -> Dictionary:
	return {"t": "see", "x": x, "y": y, "w": w, "h": h, "rot": rot, "m": "wood"}

func _pend(px: float, py: float, length: float, radius: float, ang: float) -> Dictionary:
	return {"t": "pend", "x": px, "y": py, "len": length, "r": radius, "ang": ang}

func _ball(x: float, y: float) -> Dictionary:
	return {"t": "ball", "x": x, "y": y}

func _goal(x: float, y: float, iw := 130.0) -> Dictionary:
	return {"t": "goal", "x": x, "y": y, "iw": iw}

func _ramp_point(r: Dictionary, s: float, lift: float) -> Vector2:
	var a := deg_to_rad(float(r["rot"]))
	var tv := Vector2(cos(a), sin(a))
	var nv := Vector2(sin(a), -cos(a))
	return Vector2(float(r["x"]), float(r["y"])) + tv * s + nv * (float(r["h"]) * 0.5 + lift)

func _ball_on(r: Dictionary, s: float) -> Dictionary:
	var p := _ramp_point(r, s, BALL_R)
	return _ball(p.x, p.y)

func _s(ink: String, pts: Array) -> Dictionary:
	var pv := PackedVector2Array()
	for p in pts:
		pv.append(Vector2(p[0], p[1]))
	return {"ink": ink, "pts": pv}

func _make_levels() -> Array:
	var out: Array = []

	# 1 - Catch: the ball rolls off a ledge. Guide it into the cup.
	var r1 := _fx(150, 450, 260, 30, 12.0)
	out.append({"name": "Catch", "hint": "Draw a beam, then press GO.",
		"ink": 400.0, "inks": ["beam"], "par": 150.0,
		"items": [r1, _ball_on(r1, -60.0), _fx(360, 1130, 720, 40), _goal(610, 1032)],
		"sol": [_s("beam", [[280, 855], [545, 1010]])]})

	# 2 - Wrecker: a wrecking ball smacks the ball off its shelf. Bring it back.
	out.append({"name": "Wrecker", "hint": "The big ball swings on its own.",
		"ink": 450.0, "inks": ["beam"], "par": 200.0,
		"items": [_pend(200, 250, 340, 42, 30.0),
			_fx(390, 650, 260, 24), _ball(320, 612),
			_fx(360, 1130, 720, 40), _goal(300, 1032)],
		"sol": [_s("beam", [[470, 785], [665, 690]])]})

	# 3 - Chain reaction: pendulum, dominoes, ball. Build the way home.
	var doms: Array = [_bk(235, 598, 80, 80, 0.0, "ice")]
	var items3: Array = [_pend(110, 250, 340, 42, 52.0), _fx(380, 650, 560, 24), _ball(345, 612),
		_fx(360, 1130, 720, 40), _goal(380, 1032, 180)]
	items3.append_array(doms)
	out.append({"name": "Chain", "hint": "Bob hits the crate, crate hits the ball.",
		"ink": 500.0, "inks": ["beam"], "par": 200.0,
		"items": items3, "sol": [_s("beam", [[715, 725], [555, 800]])]})

	# 4 - Trampoline: the ball drops from above. Bounce it up and over.
	out.append({"name": "Trampoline", "hint": "Pink ink is bouncy.",
		"ink": 520.0, "inks": ["bounce", "beam"], "par": 330.0,
		"items": [_ball(180, 300), _fx(360, 1130, 720, 40),
			_fx(595, 835, 250, 30), _goal(600, 742, 170)],
		"sol": [_s("bounce", [[365, 470], [130, 425]])]})

	return out

# ------------------------------------------------------------ lifecycle ----

func _ready() -> void:
	LEVELS = _make_levels()
	add_child(Background.new())
	world = Node2D.new()
	add_child(world)
	preview = Preview.new()
	add_child(preview)
	_build_ui()
	var args := OS.get_cmdline_user_args()
	if "--test" in args or "--search" in args or "--try" in args:
		test_mode = true
		run_tests.call_deferred(args)
		return
	build_level(0)


func _physics_process(delta: float) -> void:
	phys_frames += 1
	if phase != "run" or balls.is_empty():
		return
	run_frames += 1

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
		if p.y > H + 150.0 or p.x < -150.0 or p.x > W + 150.0 or p.y < -600.0:
			_lose("The ball got away. Press Reset.", "fell")
			return

	var all_sleep := true
	for b in balls:
		if not b.sleeping:
			all_sleep = false
	if all_sleep and not all_in:
		stuck_time += delta
		if stuck_time >= 1.5:
			_lose("It stopped. Press Reset.", "stuck")
			return
	else:
		stuck_time = 0.0
	if run_frames > int(RUN_TIMEOUT * 60.0):
		_lose("Time's up. Press Reset.", "timeout")

# ---------------------------------------------------------------- build ----

func build_level(i: int) -> void:
	if level_root:
		level_root.free()
	level_root = Node2D.new()
	world.add_child(level_root)
	balls.clear()
	goals.clear()
	phase = "setup"
	lose_reason = ""
	goal_time = 0.0
	stuck_time = 0.0
	run_frames = 0
	level_idx = i
	for it in LEVELS[i]["items"]:
		match it["t"]:
			"fix":
				_add_fixed(it)
			"blk":
				_add_block(it)
			"see":
				_add_seesaw(it)
			"pend":
				_add_pendulum(it)
			"ball":
				_add_ball(it)
			"goal":
				_add_goal(it)
	ink_used = 0.0
	for st in strokes:
		_add_stroke(st)
		ink_used += _stroke_cost(st)
	var allowed: Array = LEVELS[i]["inks"]
	if not (cur_ink in allowed):
		cur_ink = allowed[0]
	title_lbl.text = "Level %d: %s" % [i + 1, LEVELS[i]["name"]]
	hint_lbl.text = LEVELS[i]["hint"]
	overlay.visible = false
	drawing = false
	cur_pts = PackedVector2Array()
	preview.pts = cur_pts
	preview.queue_redraw()
	_update_hud()
	PhysicsServer2D.set_active(false)   # frozen until GO


func _pm(fric: float, bounce: float) -> PhysicsMaterial:
	var pm := PhysicsMaterial.new()
	pm.friction = fric
	pm.bounce = bounce
	return pm


func _rect_shape(size: Vector2, pos := Vector2.ZERO) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	cs.shape = rs
	cs.position = pos
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
	body.physics_material_override = _pm(MATS[it["m"]]["fric"], MATS[it["m"]]["bounce"])
	var size := Vector2(it["w"], it["h"])
	body.add_child(_rect_shape(size))
	body.add_child(_view(size, MATS[it["m"]]["color"], true))
	(parent if parent else level_root).add_child(body)


func _dyn_body(pos: Vector2, rot_deg: float, mat: String) -> RigidBody2D:
	var rb := RigidBody2D.new()
	rb.position = pos
	rb.rotation_degrees = rot_deg
	rb.collision_layer = LAYER_BODY
	rb.collision_mask = LAYER_WORLD | LAYER_BODY | LAYER_BALL
	rb.physics_material_override = _pm(MATS[mat]["fric"], MATS[mat]["bounce"])
	return rb


func _add_block(it: Dictionary) -> void:
	var rb := _dyn_body(Vector2(it["x"], it["y"]), float(it["rot"]), it["m"])
	var size := Vector2(it["w"], it["h"])
	rb.mass = maxf(size.x * size.y / 500.0 * float(MATS[it["m"]]["dens"]), 1.0)
	rb.add_child(_rect_shape(size))
	rb.add_child(_view(size, MATS[it["m"]]["color"], false))
	level_root.add_child(rb)


func _pin(body: Node2D, pivot: Vector2) -> void:
	var anchor := StaticBody2D.new()
	anchor.position = pivot
	anchor.collision_layer = 0
	anchor.collision_mask = 0
	level_root.add_child(anchor)
	var j := PinJoint2D.new()
	j.position = pivot
	j.node_a = anchor.get_path()
	j.node_b = body.get_path()
	level_root.add_child(j)
	var pv := PivotView.new()
	pv.position = pivot
	level_root.add_child(pv)


func _add_seesaw(it: Dictionary) -> void:
	var pos := Vector2(it["x"], it["y"])
	var rb := _dyn_body(pos, float(it["rot"]), "wood")
	var size := Vector2(it["w"], it["h"])
	rb.mass = 8.0
	rb.angular_damp = 0.4
	rb.contact_monitor = true
	rb.max_contacts_reported = 8
	rb.add_child(_rect_shape(size))
	rb.add_child(_view(size, MATS["wood"]["color"], false))
	level_root.add_child(rb)
	_pin(rb, pos)


func _add_pendulum(it: Dictionary) -> void:
	var pos := Vector2(it["x"], it["y"])
	var length := float(it["len"])
	var radius := float(it["r"])
	var rb := _dyn_body(pos, float(it["ang"]), "heavy")
	rb.mass = 10.0
	rb.center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
	rb.center_of_mass = Vector2(0, length)
	rb.angular_damp = 0.05
	var cs := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = radius
	cs.shape = circ
	cs.position = Vector2(0, length)
	rb.add_child(cs)
	var rod := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 5.0
	cap.height = length
	rod.shape = cap
	rod.position = Vector2(0, length * 0.5)
	rb.add_child(rod)
	var v := PendView.new()
	v.length = length
	v.radius = radius
	rb.add_child(v)
	level_root.add_child(rb)
	_pin(rb, pos)


func _add_ball(it: Dictionary) -> void:
	var rb := RigidBody2D.new()
	rb.position = Vector2(it["x"], it["y"])
	rb.collision_layer = LAYER_BALL
	rb.collision_mask = LAYER_WORLD | LAYER_BODY | LAYER_BALL
	rb.mass = 1.5
	rb.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	rb.linear_damp = 0.05
	rb.angular_damp = 0.3
	rb.physics_material_override = _pm(0.6, 0.05)
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
	var iw: float = float(it["iw"])
	var glow := GoalGlow.new()
	glow.iw = iw
	g.add_child(glow)
	var hw := iw * 0.5
	var hh := CUP_IH * 0.5
	_add_fixed({"x": 0, "y": hh + 9.0, "w": iw + 36.0, "h": 18.0, "rot": 0.0, "m": "goal"}, g)
	_add_fixed({"x": -(hw + 9.0), "y": 9.0, "w": 18.0, "h": CUP_IH + 18.0, "rot": 0.0, "m": "goal"}, g)
	_add_fixed({"x": hw + 9.0, "y": 9.0, "w": 18.0, "h": CUP_IH + 18.0, "rot": 0.0, "m": "goal"}, g)
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = LAYER_BALL
	area.position = Vector2(0, hh - 40.0)
	area.add_child(_rect_shape(Vector2(iw - 20.0, 80.0)))
	g.add_child(area)
	goals.append(area)

# --------------------------------------------------------------- strokes ---

func _stroke_len(pts: PackedVector2Array) -> float:
	var l := 0.0
	for i in range(1, pts.size()):
		l += pts[i - 1].distance_to(pts[i])
	return l


func _stroke_cost(st: Dictionary) -> float:
	return _stroke_len(st["pts"]) * float(INKS[st["ink"]]["cost"])


func _add_stroke(st: Dictionary) -> void:
	var ink: Dictionary = INKS[st["ink"]]
	var pts: PackedVector2Array = st["pts"]
	var body: PhysicsBody2D
	var local := PackedVector2Array()
	if ink["static"]:
		var sb := StaticBody2D.new()
		sb.collision_layer = LAYER_WORLD
		sb.collision_mask = 0
		sb.physics_material_override = _pm(ink["fric"], ink["bounce"])
		body = sb
		local = pts
	else:
		var centroid := Vector2.ZERO
		for p in pts:
			centroid += p
		centroid /= float(pts.size())
		var rb := _dyn_body(centroid, 0.0, "wood")
		rb.physics_material_override = _pm(ink["fric"], ink["bounce"])
		rb.mass = maxf(_stroke_len(pts) * float(ink["dens"]), 1.0)
		body = rb
		for p in pts:
			local.append(p - centroid)
	if local.size() == 1:
		var cs := CollisionShape2D.new()
		var circ := CircleShape2D.new()
		circ.radius = STROKE_R
		cs.shape = circ
		cs.position = local[0]
		body.add_child(cs)
	else:
		for i in range(1, local.size()):
			var a := local[i - 1]
			var b := local[i]
			var d := b - a
			var ln := d.length()
			if ln < 1.0:
				continue
			var cs2 := CollisionShape2D.new()
			var cap := CapsuleShape2D.new()
			cap.radius = STROKE_R
			cap.height = ln + 2.0 * STROKE_R
			cs2.shape = cap
			cs2.position = (a + b) * 0.5
			cs2.rotation = d.angle() - PI / 2.0
			body.add_child(cs2)
	var sv := StrokeView.new()
	sv.pts = local
	sv.color = ink["color"]
	body.add_child(sv)
	level_root.add_child(body)


func _rdp(pts: PackedVector2Array, keep: PackedByteArray, a: int, b: int, eps: float) -> void:
	var dmax := 0.0
	var imax := -1
	for i in range(a + 1, b):
		var q := Geometry2D.get_closest_point_to_segment(pts[i], pts[a], pts[b])
		var d := pts[i].distance_to(q)
		if d > dmax:
			dmax = d
			imax = i
	if imax >= 0 and dmax > eps:
		keep[imax] = 1
		_rdp(pts, keep, a, imax, eps)
		_rdp(pts, keep, imax, b, eps)


func _simplify(pts: PackedVector2Array, eps: float) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var keep := PackedByteArray()
	keep.resize(pts.size())
	keep[0] = 1
	keep[pts.size() - 1] = 1
	_rdp(pts, keep, 0, pts.size() - 1, eps)
	var out := PackedVector2Array()
	for i in pts.size():
		if keep[i] == 1:
			out.append(pts[i])
	return out

# ----------------------------------------------------------------- input ---

func _unhandled_input(event: InputEvent) -> void:
	if phase != "setup":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_stroke(get_global_mouse_position())
		else:
			_end_stroke()
	elif event is InputEventMouseMotion and drawing:
		_extend_stroke(get_global_mouse_position())


func _budget() -> float:
	return float(LEVELS[level_idx]["ink"])


func _begin_stroke(p: Vector2) -> void:
	if ink_used >= _budget() - 1.0:
		hint_lbl.text = "Out of ink. Undo something."
		return
	drawing = true
	cur_pts = PackedVector2Array([p])
	_refresh_preview()


func _extend_stroke(p: Vector2) -> void:
	if not drawing or cur_pts.size() == 0:
		return
	var last := cur_pts[cur_pts.size() - 1]
	var step := last.distance_to(p)
	if step < 8.0:
		return
	var cost := step * float(INKS[cur_ink]["cost"])
	if ink_used + _pending_cost() + cost > _budget():
		hint_lbl.text = "Out of ink."
		return
	cur_pts.append(p)
	_refresh_preview()


func _pending_cost() -> float:
	return _stroke_len(cur_pts) * float(INKS[cur_ink]["cost"])


func _refresh_preview() -> void:
	preview.pts = cur_pts
	preview.color = INKS[cur_ink]["color"]
	preview.queue_redraw()
	_update_hud()


func _end_stroke() -> void:
	if not drawing:
		return
	drawing = false
	var pts := _simplify(cur_pts, 5.0)
	var ok := _stroke_len(pts) >= 24.0
	cur_pts = PackedVector2Array()
	preview.pts = cur_pts
	preview.queue_redraw()
	if ok:
		strokes.append({"ink": cur_ink, "pts": pts})
		rebuild()
	else:
		_update_hud()

# ------------------------------------------------------------------ flow ---

func rebuild() -> void:
	build_level(level_idx)


func go() -> void:
	if phase != "setup":
		return
	phase = "run"
	run_frames = 0
	PhysicsServer2D.set_active(true)
	_update_hud()


func reset_run() -> void:
	rebuild()


func _win() -> void:
	phase = "won"
	if test_mode:
		return
	var par: float = LEVELS[level_idx]["par"]
	var n := 3 if ink_used <= par else (2 if ink_used <= par * 1.5 else 1)
	stars.count = n
	stars.queue_redraw()
	over_info.text = "Ink used %d  (par %d)" % [int(ink_used), int(par)]
	overlay.visible = true
	_update_hud()


func _lose(msg: String, why: String) -> void:
	phase = "lost"
	lose_reason = why
	if test_mode:
		return
	hint_lbl.text = msg
	_update_hud()


func go_level(i: int) -> void:
	strokes.clear()
	level_idx = posmod(i, LEVELS.size())
	rebuild()


func _undo() -> void:
	if phase != "setup":
		rebuild()
		return
	if strokes.size() > 0:
		strokes.pop_back()
		rebuild()


func _clear() -> void:
	strokes.clear()
	rebuild()


func _cycle_ink() -> void:
	if phase != "setup":
		rebuild()
	var allowed: Array = LEVELS[level_idx]["inks"]
	var k := allowed.find(cur_ink)
	cur_ink = allowed[(k + 1) % allowed.size()]
	_update_hud()


func _on_go() -> void:
	if phase == "setup":
		go()
	else:
		reset_run()

# ------------------------------------------------------------------ UI -----

func _update_hud() -> void:
	var budget := _budget()
	var used := ink_used + (_pending_cost() if drawing else 0.0)
	ink_lbl.text = "Ink  %d / %d" % [int(used), int(budget)]
	ink_bar_fill.size.x = 400.0 * clampf(used / budget, 0.0, 1.0)
	ink_bar_fill.color = Color("ff8a80") if used / budget > 0.9 else Color("7fd6a6")
	ink_btn.text = "Ink: " + String(INKS[cur_ink]["name"])
	ink_btn.visible = (LEVELS[level_idx]["inks"] as Array).size() > 1
	go_btn.text = "GO!" if phase == "setup" else "Reset"


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


func _button(text: String, pos: Vector2, size: Vector2, cb: Callable, fsize := 32, base := Color("38426e")) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", fsize)
	b.add_theme_color_override("font_color", Color("f2f4ff"))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	var cols := {"normal": base, "hover": base.lightened(0.12), "pressed": base.lightened(0.25)}
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
	title_lbl = _label(Vector2(100, 24), Vector2(W - 200, 56), 40, Color("f2f4ff"))
	ink_lbl = _label(Vector2(0, 80), Vector2(W, 36), 28, Color("9aa5d6"))
	hint_lbl = _label(Vector2(40, 146), Vector2(W - 80, 60), 28, Color("ffd9a0"))
	ui.add_child(title_lbl)
	ui.add_child(ink_lbl)
	ui.add_child(hint_lbl)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color("2a3157")
	bar_bg.position = Vector2(160, 122)
	bar_bg.size = Vector2(400, 14)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bar_bg)
	ink_bar_fill = ColorRect.new()
	ink_bar_fill.position = Vector2(160, 122)
	ink_bar_fill.size = Vector2(0, 14)
	ink_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(ink_bar_fill)

	ui.add_child(_button("<", Vector2(20, 24), Vector2(70, 56), func() -> void: go_level(level_idx - 1), 30))
	ui.add_child(_button(">", Vector2(630, 24), Vector2(70, 56), func() -> void: go_level(level_idx + 1), 30))

	ui.add_child(_button("Undo", Vector2(20, 1170), Vector2(130, 80), func() -> void: _undo(), 28))
	ui.add_child(_button("Clear", Vector2(160, 1170), Vector2(130, 80), func() -> void: _clear(), 28))
	ink_btn = _button("Ink", Vector2(300, 1170), Vector2(190, 80), func() -> void: _cycle_ink(), 28, Color("4a3f70"))
	ui.add_child(ink_btn)
	go_btn = _button("GO!", Vector2(500, 1170), Vector2(200, 80), func() -> void: _on_go(), 38, Color("2f9e6b"))
	ui.add_child(go_btn)

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
	panel.size = Vector2(500, 480)
	overlay.add_child(panel)
	var cleared := _label(Vector2(110, 410), Vector2(500, 80), 56, Color.WHITE)
	cleared.text = "Solved!"
	overlay.add_child(cleared)
	stars = StarsView.new()
	stars.position = Vector2(180, 500)
	stars.size = Vector2(360, 120)
	overlay.add_child(stars)
	over_info = _label(Vector2(110, 630), Vector2(500, 50), 30, Color("9aa5d6"))
	overlay.add_child(over_info)
	overlay.add_child(_button("Next", Vector2(170, 700), Vector2(380, 80), func() -> void: go_level(level_idx + 1), 40))
	overlay.add_child(_button("Replay", Vector2(170, 790), Vector2(380, 56), func() -> void: reset_run(), 28))
	ui.add_child(overlay)

# ---------------------------------------------------------------- tests ----
# Headless checks:
#   godot --headless --fixed-fps 60 --path godot-project -- --test
#   godot --headless --fixed-fps 60 --path godot-project -- --search <level 1-based> <ink> <tries> <strokes> [seed]
# --test proves each level: doing nothing does not win, the stored solution wins,
# and it still wins when nudged a few pixels. --search random-samples straight
# strokes to find solutions and to see how forgiving a level is.

func _wait(n: int) -> void:
	var target := phys_frames + n
	while phys_frames < target:
		await get_tree().process_frame


func _run(li: int, sts: Array, off: Vector2) -> Dictionary:
	strokes = []
	for s in sts:
		var pv := PackedVector2Array()
		for p in (s["pts"] as PackedVector2Array):
			pv.append(p + off)
		strokes.append({"ink": s["ink"], "pts": pv})
	level_idx = li
	build_level(li)
	await _wait(2)
	go()
	var guard := 0
	var tr := ""
	var apex := 1.0e9
	while phase == "run" and guard < 1000:
		await _wait(5)
		guard += 5
		if trace and balls.size() > 0:
			apex = minf(apex, balls[0].global_position.y)
			if guard <= 600 and guard % 20 == 0:
				tr += " (%d,%d)" % [int(balls[0].global_position.x), int(balls[0].global_position.y)]
			if guard <= 90 and guard % 5 == 0:
				var d := ""
				for n in level_root.get_children():
					if n is RigidBody2D and not (n in balls):
						d += " [%d,%d r%d w%.1f]" % [int(n.global_position.x), int(n.global_position.y), int(n.rotation_degrees), n.angular_velocity]
						if n.contact_monitor:
							for cb in n.get_colliding_bodies():
								d += " hits:%s@(%d,%d)" % [cb.get_class(), int(cb.global_position.x), int(cb.global_position.y)]
				print("     t=%d%s ball=(%d,%d)" % [guard, d, int(balls[0].global_position.x), int(balls[0].global_position.y)])
	if trace:
		tr += "  apex_y=%d" % int(apex)
	if trace:
		print("   trace:" + tr)
		for n in level_root.get_children():
			if n is RigidBody2D and not (n in balls):
				print("   body %s pos=(%d,%d) rot=%d" % [n.name, int(n.global_position.x), int(n.global_position.y), int(n.rotation_degrees)])
	var bp := Vector2.ZERO
	if balls.size() > 0:
		bp = balls[0].global_position
	return {"won": phase == "won", "phase": phase, "why": lose_reason, "ball": bp, "ink": ink_used}


func run_tests(args: PackedStringArray) -> void:
	if "--search" in args:
		var k := args.find("--search")
		var li := int(args[k + 1]) - 1
		var ink := String(args[k + 2])
		var tries := int(args[k + 3])
		var nstr := int(args[k + 4])
		var sd := int(args[k + 5]) if args.size() > k + 5 else 1
		await run_search(li, ink, tries, nstr, sd)
		get_tree().quit()
		return
	if "--try" in args:
		# --try <level> <ink> x1 y1 x2 y2 [x1 y1 x2 y2 ...]
		var k2 := args.find("--try")
		var tl := int(args[k2 + 1]) - 1
		var tink := String(args[k2 + 2])
		var nums := args.slice(k2 + 3)
		var sts: Array = []
		var i := 0
		while i + 3 < nums.size():
			sts.append({"ink": tink, "pts": PackedVector2Array([Vector2(float(nums[i]), float(nums[i + 1])), Vector2(float(nums[i + 2]), float(nums[i + 3]))])})
			i += 4
		trace = true
		var tr: Dictionary = await _run(tl, sts, Vector2.ZERO)
		print("TRY -> %s/%s ball=%s ink=%d" % [tr["phase"], tr["why"], str(tr["ball"]), int(tr["ink"])])
		get_tree().quit()
		return
	var problems := 0
	for li in LEVELS.size():
		var name: String = LEVELS[li]["name"]
		var base: Dictionary = await _run(li, [], Vector2.ZERO)
		var sol: Array = LEVELS[li]["sol"]
		var line := "LEVEL %d %s: do-nothing=%s(%s) ball=%s" % [li + 1, name, base["phase"], base["why"], str(base["ball"])]
		print(line)
		if base["won"]:
			print("  !! level is solved by doing nothing")
			problems += 1
		if sol.is_empty():
			print("  !! no stored solution yet")
			problems += 1
			continue
		var cost := 0.0
		for s in sol:
			cost += _stroke_cost(s)
		if cost > float(LEVELS[li]["ink"]):
			print("  !! solution needs %d ink but budget is %d" % [int(cost), int(LEVELS[li]["ink"])])
			problems += 1
		var offs := [Vector2(0, 0), Vector2(8, 0), Vector2(-8, 0), Vector2(0, 8), Vector2(0, -8), Vector2(6, 6), Vector2(-6, -6), Vector2(14, 0), Vector2(-14, 0)]
		var wins := 0
		for o in offs:
			var r: Dictionary = await _run(li, sol, o)
			if r["won"]:
				wins += 1
			else:
				print("   offset %s -> %s/%s ball=%s" % [str(o), r["phase"], r["why"], str(r["ball"])])
		print("  solution ink=%d (budget %d, par %d)  wins under nudges: %d/%d" % [int(cost), int(LEVELS[li]["ink"]), int(LEVELS[li]["par"]), wins, offs.size()])
		if wins < 7:
			print("  !! solution is too fragile")
			problems += 1
	print("TESTS_DONE problems=%d" % problems)
	get_tree().quit()


func run_search(li: int, ink_spec: String, tries: int, nstr: int, sd: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var budget := float(LEVELS[li]["ink"])
	var found := 0
	var tried := 0
	var inks := ink_spec.split("+")
	var hammer := false
	var biasr := false
	if inks[0] == "hammer":
		hammer = true
		inks[0] = "weight"
	if inks[0] == "beamR":
		biasr = true
		inks[0] = "beam"
	for k in tries:
		var sts: Array = []
		var cost := 0.0
		for j in nstr:
			var ink: String = inks[j % inks.size()]
			var a := Vector2(rng.randf_range(30.0, 690.0), rng.randf_range(220.0, 1100.0))
			var ang := rng.randf_range(0.0, TAU)
			var ln := rng.randf_range(70.0, minf(540.0, budget))
			if hammer and j == 0:
				ln = rng.randf_range(90.0, 200.0)
				a = Vector2(rng.randf_range(80.0, 360.0), rng.randf_range(200.0, 520.0))
				ang = 0.0
			if biasr and j == 0:
				a = Vector2(rng.randf_range(640.0, 715.0), rng.randf_range(690.0, 800.0))
				ang = deg_to_rad(rng.randf_range(110.0, 200.0))
			var b := a + Vector2(cos(ang), sin(ang)) * ln
			b.x = clampf(b.x, 15.0, 705.0)
			b.y = clampf(b.y, 215.0, 1105.0)
			sts.append({"ink": ink, "pts": PackedVector2Array([a.snapped(Vector2(5, 5)), b.snapped(Vector2(5, 5))])})
			cost += a.distance_to(b) * float(INKS[ink]["cost"])
		if cost > budget:
			continue
		tried += 1
		var r: Dictionary = await _run(li, sts, Vector2.ZERO)
		if r["won"]:
			found += 1
			var desc := ""
			for s2 in sts:
				var p: PackedVector2Array = s2["pts"]
				desc += " %s[%d,%d -> %d,%d]" % [s2["ink"], int(p[0].x), int(p[0].y), int(p[1].x), int(p[1].y)]
			var robust := 0
			for o in [Vector2(8, 0), Vector2(-8, 0), Vector2(0, 8), Vector2(0, -8), Vector2(6, 6), Vector2(-6, -6), Vector2(14, 0), Vector2(-14, 0)]:
				var r2: Dictionary = await _run(li, sts, o)
				if r2["won"]:
					robust += 1
			print("WIN robust=%d/8 cost=%d %s" % [robust, int(cost), desc])
	print("SEARCH_DONE level=%d spec=%s tried=%d wins=%d" % [li + 1, ink_spec, tried, found])

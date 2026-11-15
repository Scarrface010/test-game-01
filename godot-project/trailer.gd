extends RefCounted
# Trailer driver: run with  -- --trailer  plus --write-movie. Drives main.gd through feature beats with captions.

const FPS := 30
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
var m
var layer: CanvasLayer
var cap: Label
var sub: Label
var fade: ColorRect
var band: ColorRect
var logo: TextureRect


func run(main) -> void:
	m = main
	seed(20261113)
	_build_ui()
	m.mode = "adv"
	m.cls = "brute"
	m.tutorial = false
	m.adv_best = 20
	# 1. title (game intro)
	m.state = m.INTRO
	m.state_t = m.t
	await _wait(4.5)
	# 2. explore: hop from item to item straight away
	_setup_floor(2, 1234, 6)
	_caption("EXPLORE", "a new station every run")
	var seen: Array = []
	var t0: float = m.t
	for i in 14:
		if m.t - t0 > 6.5:
			break
		var ic := _nearest_item("", seen)
		if ic.x < 0:
			await _roam(5)
			continue
		seen.append(ic)
		await _walk_to(ic, 1.6)
	# 3. air: drain slowly, then two pods push the frost back
	_caption("WATCH YOUR AIR", "grab pods before it runs out")
	var o0: float = m.oxy
	var n := int(2.5 * FPS)
	for i in n:
		m.oxy = lerpf(o0, m.oxy_max * 0.07, float(i + 1) / n)
		await _wait(1.0 / FPS, true)
	await _wait(0.6, true)
	var pods := _place_pods()
	for pc in pods:
		await _walk_to(pc, 2.0)
		await _wait(0.5, true)
	# 4. combat
	_caption("FIGHT", "every kill levels you up")
	m.level = 20
	for i in 3:
		var mc := _nearest_mon()
		if mc.x < 0:
			break
		await _fight(mc, 2.2)
	# 5. inventory
	_give_loot()
	_caption("LOOT & GEAR", "tools, relics and gear")
	for tab in m.INV_TABS:
		m.state = m.INV
		m.inv_tab = int(tab)
		m.queue_redraw()
		await _wait(1.4)
	# 6. skills / builds
	_caption("SKILL TREE", "build your way")
	m.skill_pts = 4
	m.skills["b0n0"] = 2
	m.skills["b0n1"] = 1
	m.skills["b2n5"] = 1
	m.state = m.SKILLS
	for s in ["b0n0", "b0n1", "b2n5"]:
		m.sk_sel = s
		m.queue_redraw()
		await _wait(1.5)
	# 7. boss: weave toward it through its attacks, then fight
	_caption("", "")
	_setup_floor(3, 555, 14, true)
	await _wait(1.5, true)
	_caption("FACE THE BOSSES", "")
	for wp in [Vector2i(4, 9), Vector2i(8, 8), Vector2i(4, 6), Vector2i(8, 5), Vector2i(5, 4)]:
		await _walk_to(wp, 1.4, 0.3)
	await _fight(m.boss_cell, 5.0)
	# 8. end card
	_caption("", "")
	await _end_card()


func _setup_floor(f: int, sd: int, lvl: int, ar := false) -> void:
	m.floor_n = f
	m.adv_seed = sd
	m._adv_init_run()
	m.arena = ar
	m.level = lvl
	m._adv_gen()
	m._adv_snapshot()
	m._adv_begin()
	if m.ev_id != "":
		m.items.erase(m.ev_c)
		m.ev_id = ""
		m.ev_run = ""
	m.state = m.PLAY
	m.msg = ""
	m._adv_update_vis()


func _wait(sec: float, play := false) -> void:
	for i in maxi(1, int(round(sec * FPS))):
		m.hp = m.hp_cap()
		if play and m.state != m.PLAY:
			m.state = m.PLAY
		await m.get_tree().process_frame


# walk along a path; step_s slows steps down (0.15 is the game's own pace)
func _walk_to(c: Vector2i, max_s: float, step_s := 0.15) -> void:
	var p: Array = m._adv_path(c)
	if p.is_empty():
		return
	m.walk.clear()
	var t := 0.0
	while not p.is_empty() and t < max_s:
		if m.state != m.PLAY:
			m.state = m.PLAY
		var nc: Vector2i = p.pop_front()
		if m.mons.has(nc):
			break
		m._adv_step(nc, p.is_empty())
		await _wait(step_s, true)
		t += step_s


var roam_dir := Vector2i(1, 0)


# hop through open cells, keeping a heading and turning at walls
func _roam(steps: int) -> void:
	for i in steps:
		var opts: Array = []
		for dv in DIRS:
			var c: Vector2i = m.pos + dv
			if dv != -roam_dir and m._aopen(c) and not m.mons.has(c):
				opts.append(dv)
		if opts.is_empty():
			roam_dir = -roam_dir
			continue
		if not opts.has(roam_dir) or randf() < 0.15:
			roam_dir = opts[randi() % opts.size()]
		m.state = m.PLAY
		m._adv_step(m.pos + roam_dir, true)
		await _wait(0.15, true)


func _place_pods() -> Array:
	var out: Array = []
	for r in [3, 6]:
		var c := _open_ring(r, out)
		if c.x >= 0:
			m.items[c] = "pod"
			out.append(c)
	return out


func _open_ring(r: int, skip: Array) -> Vector2i:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if absi(dx) + absi(dy) != r:
				continue
			var c: Vector2i = m.pos + Vector2i(dx, dy)
			if m._aopen(c) and not m.mons.has(c) and not m.items.has(c) and not skip.has(c) and not m._adv_path(c).is_empty():
				return c
	return Vector2i(-1, -1)


func _fight(mc: Vector2i, sec: float) -> void:
	# get next to the target, then hit it until it dies or time runs out
	var adj := Vector2i(-1, -1)
	var bd := 999
	for dv in DIRS:
		var c: Vector2i = mc + dv
		if m._aopen(c) and not m.mons.has(c) and not m.items.has(c):
			var d: int = absi(c.x - m.pos.x) + absi(c.y - m.pos.y)
			if d < bd:
				bd = d
				adj = c
	if adj.x < 0:
		return
	if adj != m.pos:
		await _walk_to(adj, 1.2)
	if (m.pos - mc).length_squared() != 1:
		m.walk.clear()
		m.pos = adj
		m.vis_pos = Vector2(adj)
		m.cam = Vector2(adj)
		m._adv_update_vis()
		await _wait(0.3, true)
	for i in int(sec / 0.45):
		if not m.mons.has(mc):
			await _wait(0.6, true)
			return
		if m.state == m.PLAY:
			m._adv_step(mc, true)
		await _wait(0.45, true)


func _nearest_item(kind: String, skip: Array = []) -> Vector2i:
	var best := Vector2i(-1, -1)
	var bd := 999
	var cells: Array = m.items.keys()
	if kind == "":
		cells.append_array(m.coin_at.keys())
	for c in cells:
		var k := String(m.items.get(c, "coin"))
		if (kind != "" and k != kind) or k.begins_with("ev_") or skip.has(c) or c == m.pos:
			continue
		var d: int = absi(c.x - m.pos.x) + absi(c.y - m.pos.y)
		if d < bd and d < 24 and not m._adv_path(c).is_empty():
			bd = d
			best = c
	return best


func _nearest_mon() -> Vector2i:
	var best := Vector2i(-1, -1)
	var bd := 999
	for c in m.mons:
		if c == m.stairs:
			continue
		var d: int = absi(c.x - m.pos.x) + absi(c.y - m.pos.y)
		if d < bd:
			bd = d
			best = c
	return best


func _give_loot() -> void:
	m.coins = 300
	m.equip["weapon"] = "novacleaver@ignite,static,toxin"
	m.equip["armour"] = "titan"
	m.bag.append("katana@siphon,rampage")
	m.bag.append("plasmarifle@pierce,execute")
	for i in 5:
		m._adv_give_gear(m._adv_roll_gear(null, 2))
	for i in 6:
		m._give_use(m._random_use())
	for i in 3:
		for d in m._roll_relics(2):
			if m.relics.size() >= 7:
				break
			m.relics[String(d["id"])] = 1


func _build_ui() -> void:
	layer = CanvasLayer.new()
	layer.layer = 50
	m.add_child(layer)
	fade = ColorRect.new()
	fade.color = Color(0.02, 0.03, 0.08, 0.0)
	fade.size = Vector2(720, 1280)
	layer.add_child(fade)
	logo = TextureRect.new()
	logo.texture = m._intro_tex("title.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.position = Vector2(60, 330)
	logo.size = Vector2(600, 360)
	logo.modulate.a = 0.0
	layer.add_child(logo)
	band = ColorRect.new()
	band.color = Color(0.02, 0.03, 0.08, 0.0)
	band.position = Vector2(0, 1090)
	band.size = Vector2(720, 190)
	layer.add_child(band)
	cap = _label(64, 1100, Color("ffd34f"))
	sub = _label(32, 1190, Color("e8f4ff"))


func _label(fs: int, y: float, col: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, y)
	l.size = Vector2(720, fs * 1.4)
	l.add_theme_font_override("font", m.font_pix if m.font_pix != null else m.font_clear)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color("0b1020"))
	l.add_theme_constant_override("outline_size", 16)
	layer.add_child(l)
	return l


func _caption(a: String, b: String) -> void:
	cap.text = a
	sub.text = b
	band.color.a = 0.0
	if a != "" and fade.color.a < 0.5:
		band.create_tween().tween_property(band, "color:a", 0.96, 0.3)
	for l in [cap, sub]:
		l.modulate.a = 0.0
		l.create_tween().tween_property(l, "modulate:a", 1.0, 0.3)


func _end_card() -> void:
	fade.create_tween().tween_property(fade, "color:a", 1.0, 0.8)
	await _wait(0.8)
	logo.create_tween().tween_property(logo, "modulate:a", 1.0, 0.6)
	await _wait(0.8)
	cap.position.y = 760
	sub.position.y = 850
	cap.add_theme_font_size_override("font_size", 56)
	sub.add_theme_font_size_override("font_size", 44)
	sub.add_theme_color_override("font_color", Color("7dff9b"))
	_caption("COMING SOON", "to Google Play")
	await _wait(4.0)


func _far_cell() -> Vector2i:
	var best: Vector2i = m.pos
	var bd := -1
	for r in m.adv_rooms:
		var c: Vector2i = r.get_center()
		var d: int = absi(c.x - m.pos.x) + absi(c.y - m.pos.y)
		if m._aopen(c) and not m.mons.has(c) and d > bd and d < 18 and not m._adv_path(c).is_empty():
			bd = d
			best = c
	return best
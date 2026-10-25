extends SubViewport
# Phase 3 slice: 3D view of the adventure map. Reads main.gd state, never changes it.

var m  # main.gd
var root3d: Node3D
var cam3d: Camera3D
var floor_mm: MultiMeshInstance3D
var wall_mm: MultiMeshInstance3D
var player: Node3D
var p_body: Node3D
var exit_mk: MeshInstance3D
var rebuild_t := 0.0
var last_key := ""

const TOON := """
shader_type spatial;
uniform vec4 col : source_color = vec4(1.0);
void fragment() { ALBEDO = col.rgb * COLOR.rgb; }
void light() {
	float d = dot(NORMAL, LIGHT);
	float b = d > 0.4 ? 1.0 : (d > -0.1 ? 0.7 : 0.45);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * b * ATTENUATION;
}
"""
const OUTLINE := """
shader_type spatial;
render_mode unshaded, cull_front;
uniform float grow = 0.04;
void vertex() { VERTEX += NORMAL * grow; }
void fragment() { ALBEDO = vec3(0.06, 0.05, 0.1); }
"""


func _init() -> void:
	size = Vector2i(720, 712)
	transparent_bg = false
	msaa_3d = Viewport.MSAA_2X
	own_world_3d = true
	render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _ready() -> void:
	root3d = Node3D.new()
	add_child(root3d)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.04, 0.04, 0.07)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.55, 0.65)
	e.ambient_light_energy = 0.5
	env.environment = e
	root3d.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = false
	root3d.add_child(sun)
	cam3d = Camera3D.new()
	cam3d.fov = 45.0
	root3d.add_child(cam3d)
	floor_mm = _mm(BoxMesh.new(), Vector3(1.0, 0.1, 1.0), false)
	wall_mm = _mm(BoxMesh.new(), Vector3(1.0, 1.2, 1.0), true)
	_build_player()
	exit_mk = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.35
	cyl.height = 0.08
	exit_mk.mesh = cyl
	exit_mk.material_override = _toon(Color("6dff9a"), false)
	root3d.add_child(exit_mk)


func _toon(c: Color, outline: bool, grow := 0.04) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = TOON
	mat.shader = sh
	mat.set_shader_parameter("col", c)
	if outline:
		var om := ShaderMaterial.new()
		var os := Shader.new()
		os.code = OUTLINE
		om.shader = os
		om.set_shader_parameter("grow", grow)
		mat.next_pass = om
	return mat


func _mm(mesh: BoxMesh, sz: Vector3, outline: bool) -> MultiMeshInstance3D:
	mesh.size = sz
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _toon(Color.WHITE, outline, 0.03)
	root3d.add_child(mi)
	return mi


func _part(mesh: Mesh, c: Color, p: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _toon(c, true, 0.035)
	mi.position = p
	parent.add_child(mi)
	return mi


func _build_player() -> void:
	player = Node3D.new()
	root3d.add_child(player)
	p_body = Node3D.new()
	player.add_child(p_body)
	var suit := Color("4fa3ff")
	var body := CapsuleMesh.new()
	body.radius = 0.22
	body.height = 0.62
	_part(body, suit, Vector3(0, 0.42, 0), p_body)
	var head := SphereMesh.new()
	head.radius = 0.2
	head.height = 0.4
	_part(head, Color("ffd9b0"), Vector3(0, 0.88, 0), p_body)
	var visor := BoxMesh.new()
	visor.size = Vector3(0.26, 0.09, 0.08)
	_part(visor, Color("20263a"), Vector3(0, 0.9, 0.18), p_body)
	var pack := BoxMesh.new()
	pack.size = Vector3(0.3, 0.32, 0.14)
	_part(pack, Color("ffd84f"), Vector3(0, 0.5, -0.24), p_body)
	var shadow := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.3
	disc.bottom_radius = 0.3
	disc.height = 0.01
	shadow.mesh = disc
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(0, 0, 0, 0.35)
	shadow.material_override = sm
	shadow.position.y = 0.06
	player.add_child(shadow)


func _rebuild() -> void:
	var th: Dictionary = m.cur_theme()
	var fc: Color = (th["dark"] as Color).lightened(0.25)
	var wc: Color = (th["accent"] as Color).darkened(0.35)
	var fl: Array = []
	var wl: Array = []
	for x in m.AW:
		for y in m.AH:
			var c := Vector2i(x, y)
			if not m._aseen(c):
				continue
			if m._aopen(c):
				fl.append(c)
			else:
				wl.append(c)
	var fmm := floor_mm.multimesh
	fmm.instance_count = fl.size()
	for i in fl.size():
		var c: Vector2i = fl[i]
		fmm.set_instance_transform(i, Transform3D(Basis(), Vector3(c.x, 0.0, c.y)))
		fmm.set_instance_color(i, fc.darkened(0.08 if (c.x + c.y) & 1 else 0.0))
	var wmm := wall_mm.multimesh
	wmm.instance_count = wl.size()
	for i in wl.size():
		var c: Vector2i = wl[i]
		wmm.set_instance_transform(i, Transform3D(Basis(), Vector3(c.x, 0.6, c.y)))
		wmm.set_instance_color(i, wc.lightened(0.06 * float((c.x * 7 + c.y * 3) % 3)))


func sync(dt: float) -> void:
	if m == null or root3d == null:
		return
	rebuild_t -= dt
	var key := "%d_%d_%d" % [m.adv_seed, m.level, m.adv_seen.size()]
	if rebuild_t <= 0.0 or key != last_key:
		rebuild_t = 0.4
		last_key = key
		_rebuild()
	var fp: Vector2 = m.rt_fp
	player.position = Vector3(fp.x, 0.0, fp.y)
	var yaw: float = [0.0, PI, -PI / 2.0, PI / 2.0][m.pdir]
	player.rotation.y = lerp_angle(player.rotation.y, yaw, minf(1.0, dt * 14.0))
	var walking: bool = m.t - m.rt_move_t < 0.1
	var sn := absf(sin(m.walk_phase * PI)) if walking else 0.0
	p_body.position.y = sn * 0.05
	p_body.rotation.z = sin(m.walk_phase * PI) * 0.06 if walking else 0.0
	var st: Vector2i = m.stairs
	exit_mk.visible = m._aseen(st)
	exit_mk.position = Vector3(st.x, 0.1, st.y)
	exit_mk.material_override.set_shader_parameter("col", Color("6dff9a") if m.adv_pts >= m.adv_req else Color(0.6, 0.6, 0.7))
	var target := Vector3(fp.x, 0.0, fp.y)
	cam3d.position = target + Vector3(0.0, 9.0, 5.5)
	cam3d.look_at(target, Vector3.UP)
	_sync_things()


# Screen point (main.gd canvas) for a tile-space position at height h.
func proj(cf: Vector2, h: float) -> Vector2:
	return cam3d.unproject_position(Vector3(cf.x, h, cf.y)) + Vector2(0, 318)


# ---------- enemies and items (pooled, rebuilt each frame from main's dictionaries) ----------
var pools := {}   # kind -> Array[Node3D]
var used := {}    # kind -> int


func _pool(kind: String) -> Node3D:
	if not pools.has(kind):
		pools[kind] = []
	var n: int = used.get(kind, 0)
	used[kind] = n + 1
	var arr: Array = pools[kind]
	if n < arr.size():
		arr[n].visible = true
		return arr[n]
	var nd := _make(kind)
	root3d.add_child(nd)
	arr.append(nd)
	return nd


func _mi(mesh: Mesh, c: Color, p: Vector3, parent: Node3D, outline := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _toon(c, outline, 0.03)
	mi.position = p
	parent.add_child(mi)
	return mi


func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


func _ball(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	return s


func _cyl(r: float, h: float, top := -1.0) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r if top < 0.0 else top
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 16
	return c


func _eyes(parent: Node3D, y: float, z: float, sp: float) -> void:
	for sx in [-1.0, 1.0]:
		_mi(_ball(0.07), Color.WHITE, Vector3(sx * sp, y, z), parent, false)
		_mi(_ball(0.035), Color("101018"), Vector3(sx * sp, y, z + 0.05), parent, false)


# Each model has a child "b" (body, recoloured per use) and optional parts.
func _make(kind: String) -> Node3D:
	var nd := Node3D.new()
	var b := Node3D.new()
	b.name = "b"
	nd.add_child(b)
	match kind:
		"mon0":   # blob
			_mi(_ball(0.3), Color.WHITE, Vector3(0, 0.3, 0), b).name = "body"
			_eyes(b, 0.38, 0.24, 0.1)
		"mon1":   # walker: box body, antenna
			_mi(_box(0.46, 0.42, 0.4), Color.WHITE, Vector3(0, 0.33, 0), b).name = "body"
			_mi(_cyl(0.02, 0.25), Color("cccccc"), Vector3(0, 0.66, 0), b)
			_mi(_ball(0.05), Color("ff5d5d"), Vector3(0, 0.8, 0), b, false)
			_eyes(b, 0.38, 0.21, 0.11)
		"mon2":   # spiker: cone
			_mi(_cyl(0.3, 0.6, 0.04), Color.WHITE, Vector3(0, 0.3, 0), b).name = "body"
			_eyes(b, 0.3, 0.17, 0.08)
		"mon3":   # floater: ball with ring
			_mi(_ball(0.24), Color.WHITE, Vector3(0, 0.5, 0), b).name = "body"
			var ring := _mi(_cyl(0.36, 0.04), Color("ffd84f"), Vector3(0, 0.5, 0), b)
			ring.rotation_degrees.x = 15
			_eyes(b, 0.55, 0.2, 0.08)
		"turret":
			_mi(_cyl(0.3, 0.3), Color.WHITE, Vector3(0, 0.15, 0), b).name = "body"
			_mi(_ball(0.2), Color("8890a8"), Vector3(0, 0.38, 0), b)
			var gun := _mi(_cyl(0.06, 0.4), Color("40465a"), Vector3(0, 0.4, 0.2), b)
			gun.rotation_degrees.x = 90
		"coin":
			var cn := _mi(_cyl(0.16, 0.05), Color("ffc93c"), Vector3(0, 0.35, 0), b)
			cn.rotation_degrees.x = 90
		"key":
			_mi(_cyl(0.1, 0.05), Color("ffd84f"), Vector3(0, 0.45, 0), b).rotation_degrees.x = 90
			_mi(_box(0.05, 0.05, 0.28), Color("ffd84f"), Vector3(0, 0.45, 0.16), b)
		"crate":
			_mi(_box(0.42, 0.36, 0.42), Color("b07a45"), Vector3(0, 0.18, 0), b)
			_mi(_box(0.44, 0.06, 0.44), Color("7a4f2a"), Vector3(0, 0.3, 0), b, false)
		"hp":
			_mi(_ball(0.16), Color("ff5d6a"), Vector3(0, 0.35, 0), b)
			_mi(_cyl(0.05, 0.08), Color("eeeeee"), Vector3(0, 0.52, 0), b)
		"armor":
			_mi(_box(0.34, 0.36, 0.1), Color("9fb2cc"), Vector3(0, 0.38, 0), b)
		"item":
			_mi(_ball(0.15), Color("c38aff"), Vector3(0, 0.38, 0), b).name = "body"
		"vault":
			_mi(_box(0.6, 0.45, 0.45), Color("d9a93a"), Vector3(0, 0.23, 0), b)
			_mi(_box(0.62, 0.08, 0.47), Color("8a6420"), Vector3(0, 0.36, 0), b, false)
		"station":
			_mi(_cyl(0.25, 0.9), Color("7fd8ff"), Vector3(0, 0.45, 0), b)
			_mi(_ball(0.16), Color("e8fbff"), Vector3(0, 0.98, 0), b, false)
		"med":
			_mi(_box(0.5, 0.5, 0.3), Color("eef5f0"), Vector3(0, 0.25, 0), b)
			_mi(_box(0.3, 0.09, 0.02), Color("39c36a"), Vector3(0, 0.3, 0.16), b, false)
			_mi(_box(0.09, 0.3, 0.02), Color("39c36a"), Vector3(0, 0.3, 0.16), b, false)
		"merchant":
			_mi(_cyl(0.22, 0.7, 0.12), Color("9a6bff"), Vector3(0, 0.35, 0), b)
			_mi(_ball(0.17), Color("ffd9b0"), Vector3(0, 0.82, 0), b)
			_mi(_cyl(0.24, 0.2, 0.0), Color("6a3fd0"), Vector3(0, 1.02, 0), b)
		"spikes":
			for i in 4:
				_mi(_cyl(0.07, 0.22, 0.0), Color("b8bcc8"), Vector3((i % 2 - 0.5) * 0.3, 0.12, (i / 2 - 0.5) * 0.3), b, false)
		"haz":
			_mi(_cyl(0.42, 0.03), Color("ff8a3a"), Vector3(0, 0.07, 0), b, false).name = "body"
	return nd


func _sync_things() -> void:
	for k in used:
		used[k] = 0
	var th: Dictionary = m.cur_theme()
	var acc: Color = th["accent"]
	var tt: float = m.t
	var px: Vector2 = m.rt_fp
	var cl: float = m.cell
	for c in m.mons:
		if not m.adv_vis.has(c) or String(m.kinds.get(c, "")) == "shard":
			continue
		var is_boss: bool = m.boss_floor and c == m.boss_cell
		var kind := "turret" if m.tur.has(c) else "mon%d" % (int(m.mons[c]) % 4)
		var nd := _pool(kind)
		var off: Vector2 = Vector2(c) + m._mon_off(c) / cl
		nd.position = Vector3(off.x, 0.0, off.y)
		var sc := 1.6 if is_boss else 1.0
		nd.scale = Vector3.ONE * sc
		var to := Vector3(px.x, 0.0, px.y) - nd.position
		if to.length() > 0.05:
			nd.rotation.y = atan2(to.x, to.z)
		var b: Node3D = nd.get_node("b")
		b.position.y = absf(sin(tt * 5.0 + c.x + c.y)) * 0.06
		var col := acc.lerp(Color.from_hsv(fposmod(float(m.mons[c]) * 0.13, 1.0), 0.6, 0.95), 0.45)
		if m.elite.has(c):
			col = col.lerp(Color("ffd84f"), 0.35)
		if m.mon_hit.has(c) and tt - float(m.mon_hit[c][0]) < 0.12:
			col = Color(1.0, 0.35, 0.35)
		var body := b.get_node_or_null("body")
		if body:
			body.material_override.set_shader_parameter("col", col)
	for c in m.items:
		if not m._aseen(c):
			continue
		var k2: String = m.items[c]
		var kind2 := "item"
		if k2 == "key":
			kind2 = "key"
		elif k2.begins_with("gear_"):
			kind2 = "crate"
		elif k2 == "hp" or k2 == "armor":
			kind2 = k2
		_place(_pool(kind2), c, tt, true)
	for c in m.coin_at:
		if m._aseen(c):
			_place(_pool("coin"), c, tt, true)
	for pair in [["vault", m.vaults], ["station", m.stations], ["med", m.meds], ["merchant", m.merchants], ["spikes", m.spikes], ["haz", m.haz]]:
		for c in pair[1]:
			if m._aseen(c):
				_place(_pool(pair[0]), c, tt, false)
	for k in pools:
		var arr: Array = pools[k]
		for i in range(used.get(k, 0), arr.size()):
			arr[i].visible = false


func _place(nd: Node3D, c: Vector2i, tt: float, spin: bool) -> void:
	nd.position = Vector3(c.x, 0.0, c.y)
	if spin:
		nd.rotation.y = tt * 2.0 + c.x
		nd.get_node("b").position.y = sin(tt * 3.0 + c.x * 1.7 + c.y) * 0.05

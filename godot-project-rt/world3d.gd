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

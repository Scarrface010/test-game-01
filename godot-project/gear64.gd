extends RefCounted
# Worn gear drawn natively at 64px and fitted to the chibi body in art/player_base64.png.
# Directions: 0 = front, 1 = back, 3 = side (facing right; dir 2 is the mirror of 3).
# HEAD[dir][y - 4] = [min_x, max_x] of the helmet silhouette for rows 4..33, VIS = the cyan visor span (-1 = none).

const HEAD := {
	0: [[28,36],[24,40],[22,42],[20,44],[19,45],[17,47],[16,48],[15,49],[15,50],[14,50],[13,51],[13,51],[12,52],[12,52],[11,53],[10,54],[9,54],[8,55],[8,55],[8,55],[8,55],[8,55],[8,55],[8,55],[9,54],[9,54],[10,52],[12,52],[13,51],[14,51]],
	1: [[28,36],[24,40],[22,42],[20,44],[19,45],[17,47],[16,48],[15,49],[15,50],[14,50],[13,51],[13,51],[12,52],[12,52],[11,53],[10,54],[9,54],[8,55],[8,55],[8,55],[8,55],[8,55],[8,55],[8,55],[9,54],[9,54],[10,52],[12,52],[13,51],[16,51]],
	3: [[27,37],[24,41],[21,43],[20,45],[18,46],[17,48],[16,49],[15,50],[14,50],[13,51],[13,51],[12,52],[12,52],[11,53],[11,53],[10,54],[10,54],[10,54],[9,54],[8,54],[8,54],[8,54],[8,54],[8,54],[8,54],[9,53],[9,53],[11,53],[12,52],[12,52]],
}
const VIS := {
	0: [[-1,-1],[-1,-1],[-1,-1],[-1,-1],[-1,-1],[-1,-1],[33,38],[29,42],[26,44],[25,45],[24,46],[23,47],[22,48],[21,49],[21,49],[20,49],[20,50],[20,50],[20,50],[20,50],[20,50],[20,50],[20,50],[20,50],[20,49],[21,49],[21,48],[22,47],[23,47],[24,45]],
	3: [[-1,-1],[-1,-1],[-1,-1],[-1,-1],[-1,-1],[-1,-1],[-1,-1],[-1,-1],[34,44],[31,47],[29,49],[28,50],[27,51],[26,51],[25,52],[25,52],[25,52],[24,52],[24,53],[24,53],[24,53],[24,53],[24,53],[24,52],[24,52],[25,52],[25,52],[26,51],[26,51],[27,50]],
}

# id -> spec. k = shape family, a/b/c = colours; the remaining keys are per-family options.
const SPEC := {
	# ---- helmets
	"visor": {"k": "visor", "a": "9aa3c7", "b": "4fd1ff"},
	"targetvisor": {"k": "visor", "a": "6a7a5a", "b": "ff5d5d", "scope": true},
	"hardcap": {"k": "cap", "a": "ffd23a", "b": "c9961a"},
	"rebreather": {"k": "mask", "a": "5a6280", "b": "9fe0ff"},
	"hazmask": {"k": "hood", "a": "e0912a", "b": "3a3a3a"},
	"tachelm": {"k": "tac", "a": "3d5a40", "b": "6dff9a"},
	"scholar": {"k": "scholar", "a": "2a3a6a", "b": "ffd84f"},
	"oracle": {"k": "oracle", "a": "e8e0f8", "b": "c07cff"},
	"weldmask": {"k": "weld", "a": "2b2f3d", "b": "ff9a3c"},
	"pilothelm": {"k": "pilot", "a": "e8ebf5", "b": "4f8cff"},
	"riothelm": {"k": "riot", "a": "3a4160", "b": "9fe0ff"},
	"sentinel": {"k": "sentinel", "a": "9fb3d9", "b": "ff5d5d"},
	"voidcrown": {"k": "crown", "a": "2a1c46", "b": "c07cff", "c": "e8d0ff"},
	"eclipsecrown": {"k": "crown", "a": "e0b030", "b": "fff3b0", "c": "0a0614", "eclipse": true},
	"crystalhelm": {"k": "crystal", "a": "6a4fc0", "b": "d0a8ff"},
	# ---- body armour
	"jacket": {"k": "plate", "a": "6b7a9a", "b": "c9a55a", "tex": "jacket", "sh": "none", "belt": true},
	"scrap": {"k": "plate", "a": "8a7a6a", "b": "b8683a", "tex": "patch", "sh": "pad", "c": "5a4a40"},
	"kevlar": {"k": "plate", "a": "2f3a4a", "b": "7b8aa8", "tex": "x", "sh": "none"},
	"reactive": {"k": "plate", "a": "7a2a2a", "b": "ff5d5d", "tex": "panels", "sh": "spike", "em": "dot"},
	"exo": {"k": "plate", "a": "9fb3d9", "b": "4fd1ff", "tex": "ribs", "sh": "pad", "em": "core"},
	"bulwark": {"k": "plate", "a": "5a6a9a", "b": "ffd84f", "tex": "panels", "sh": "big", "em": "diamond", "trim": true},
	"padded": {"k": "plate", "a": "7a5a3a", "b": "b8946a", "tex": "quilt", "sh": "none"},
	"riveted": {"k": "plate", "a": "6a727f", "b": "c5cde6", "tex": "rivets", "sh": "pad", "belt": true, "c": "6b4423"},
	"ablative": {"k": "plate", "a": "e8dcc0", "b": "7db2ff", "tex": "burn", "sh": "none", "c": "6a5a48"},
	"titan": {"k": "plate", "a": "8a8f9f", "b": "ffd84f", "tex": "panels", "sh": "big", "em": "diamond", "trim": true, "belt": true},
	"phaseweave": {"k": "plate", "a": "3a2a6a", "b": "7fe8ff", "tex": "weave", "sh": "none", "ghost": true},
	"aegiscore": {"k": "plate", "a": "2a3a5a", "b": "4fffb0", "tex": "panels", "sh": "pad", "em": "core", "trim": true},
	"crystalmail": {"k": "plate", "a": "8a5ad0", "b": "7fe8ff", "tex": "scales", "sh": "spike", "em": "diamond"},
	"ghillie": {"k": "plate", "a": "4a6a3a", "b": "9ac86a", "tex": "shag", "sh": "fur"},
	"mirrorvest": {"k": "plate", "a": "c5cde6", "b": "ffffff", "tex": "mirror", "sh": "none", "trim": true},
	"horizonplate": {"k": "plate", "a": "1a1626", "b": "ff8a3c", "c": "05030a", "tex": "panels", "sh": "big", "em": "horizon", "trim": true},
	"starweave": {"k": "plate", "a": "14204a", "b": "ffd0ff", "c": "7fe8ff", "tex": "stars", "sh": "fur"},
	# ---- boots
	"sneakers": {"k": "boot", "a": "f0f0f0", "b": "4fd1ff", "c": "d0d4e0", "f": "laces"},
	"magboots": {"k": "boot", "a": "4a4f6a", "b": "ff5d5d", "c": "2a2d40", "f": "mag"},
	"jets": {"k": "boot", "a": "6b7388", "b": "ff9a3c", "c": "3a3f50", "f": "jet"},
	"grip": {"k": "boot", "a": "3d4a3a", "b": "6dff9a", "c": "1f261e", "f": "tread"},
	"gravity": {"k": "boot", "a": "4a3a6a", "b": "c07cff", "c": "2a2040", "f": "ring"},
	"phase": {"k": "boot", "a": "1b2440", "b": "7fe8ff", "c": "0e1426", "f": "ghost"},
	"soles": {"k": "boot", "a": "5a4a3a", "b": "d9c9a0", "c": "d9c9a0", "f": "plain"},
	"spiked": {"k": "boot", "a": "3a3a44", "b": "e8e8f0", "c": "22222a", "f": "spike"},
	"runner": {"k": "boot", "a": "ff7a45", "b": "ffe0b0", "c": "c9501f", "f": "bolt"},
	"hover": {"k": "boot", "a": "5a6280", "b": "7fe8ff", "c": "343a50", "f": "pad"},
	"warp": {"k": "boot", "a": "2a1c46", "b": "ffd84f", "c": "160e2a", "f": "swirl"},
	"crystaltreads": {"k": "boot", "a": "6a4fc0", "b": "ff8ad0", "c": "40307a", "f": "crys"},
	"hazboots": {"k": "boot", "a": "c9a23a", "b": "2b2f3d", "c": "8a6f1f", "f": "hazard"},
	"wormhole": {"k": "boot", "a": "14102a", "b": "7fe8ff", "c": "0a081a", "f": "worm"},
}


static func col(s: String) -> Color:
	return Color(s)


static func hs(dir: int, y: int) -> Vector2i:
	var r: Array = HEAD[dir][clampi(y, 4, 33) - 4]
	return Vector2i(int(r[0]), int(r[1]))


static func vs(dir: int, y: int) -> Vector2i:
	var d := 3 if dir == 3 else 0
	var r: Array = VIS[d][clampi(y, 4, 33) - 4]
	return Vector2i(int(r[0]), int(r[1]))


static func dome(cv, dir: int, y0: int, y1: int, c: Color, grow: int = 0) -> void:
	for y in range(y0, y1 + 1):
		var sp := hs(dir, y)
		cv.rect(sp.x - grow, y, sp.y - sp.x + 1 + 2 * grow, 1, c)


static func draw(cv, slot: String, id: String, dir: int) -> void:
	var s: Dictionary = SPEC[id]
	var k := String(s["k"])
	if k == "plate":
		plate(cv, dir, s)
	elif k == "boot":
		boots(cv, dir, s)
	else:
		helm(cv, dir, s)
	cv.shade(0.16)


# ------------------------------------------------------------------ helmets
static func helm(cv, dir: int, s: Dictionary) -> void:
	var k := String(s["k"])
	var a := col(String(s["a"]))
	var b := col(String(s["b"]))
	var side := dir == 3
	var back := dir == 1
	var cx := 31
	if k == "cap":
		dome(cv, dir, 4, 14, a)
		for y in range(14, 17):
			var sp := hs(dir, y)
			cv.rect(sp.x - 2, y, sp.y - sp.x + 5 + (5 if side else 0), 1, b if y == 16 else a.darkened(0.1))
		cv.rect(cx - 1, 4, 3, 10, a.lightened(0.35))
		cv.line(15, 11, 21, 6, a.lightened(0.5), 1.0)
	elif k == "visor":
		var y0 := 14
		for y in range(y0, y0 + 6):
			var sp := hs(dir, y)
			var v := vs(dir, y)
			var x0 := sp.x if (back or v.x < 0) else v.x - 2
			var x1 := sp.y if (back or v.x < 0) else v.y + 2
			cv.rect(x0, y, x1 - x0 + 1, 1, a.darkened(0.3))
		var l := hs(dir, 16)
		var vv := vs(dir, 16)
		if back:
			cv.rect(l.x, 16, l.y - l.x + 1, 1, b)
		else:
			cv.rect(vv.x, 16, vv.y - vv.x + 1, 2, b)
			cv.rect(vv.x - 2, 14, 3, 6, a)
			if not side:
				cv.rect(vv.y, 14, 3, 6, a)
		var ax := 19 if side else 48
		cv.line(ax, 12, ax + (-4 if side else 3), 2, a, 1.0)
		cv.rect(ax + (-5 if side else 3), 0, 3, 3, b)
		if bool(s.get("scope", false)) and not back:
			var sx := 48 if side else 44
			cv.ell(sx, 17, 4.0, 3.0, a.darkened(0.2))
			cv.disc(sx, 17, 1.6, b)
	elif k == "mask":
		if back:
			cv.rect(8, 22, 48, 2, a)
			cv.line(12, 24, 11, 34, b, 2.0)
			cv.line(51, 24, 52, 34, b, 2.0)
		elif side:
			cv.rrect(37, 25, 17, 9, 3.0, a)
			cv.rect(40, 27, 11, 1, b)
			cv.rect(40, 30, 11, 1, b)
			cv.disc(37, 30, 4.0, a.lightened(0.15))
			cv.disc(37, 30, 2.0, b)
			cv.line(36, 33, 30, 44, b, 2.0)
		else:
			cv.rrect(24, 24, 22, 10, 4.0, a)
			cv.rect(28, 26, 14, 1, b)
			cv.rect(28, 29, 14, 1, b)
			cv.rect(28, 32, 14, 1, b)
			cv.disc(22, 29, 4.0, a.lightened(0.15))
			cv.disc(22, 29, 2.0, b)
			cv.disc(48, 29, 4.0, a.lightened(0.15))
			cv.disc(48, 29, 2.0, b)
	elif k == "hood":
		dome(cv, dir, 4, 13, a)
		for y in range(14, 33):
			var sp := hs(dir, y)
			cv.rect(sp.x - 1, y, 4, 1, a)
			if not side:
				cv.rect(sp.y - 2, y, 4, 1, a)
		cv.rect(10, 12, 44, 2, b)
		if not back:
			var fx := 30 if side else 31
			var fy := 30
			if side:
				fx = 46
			cv.disc(fx, fy, 6.0, b)
			cv.disc(fx, fy, 4.0, a.darkened(0.3))
			cv.rect(fx - 3, fy, 7, 1, b)
			cv.rect(fx, fy - 3, 1, 7, b)
	elif k == "tac":
		dome(cv, dir, 4, 17, a)
		cv.rect(cx - 1, 4, 3, 12, a.lightened(0.18))
		cv.line(14, 11, 49, 11, a.lightened(0.25), 1.0)
		if side:
			cv.disc(18, 24, 5.0, a.darkened(0.2))
			cv.disc(18, 24, 2.0, b)
			cv.rect(36, 17, 16, 2, b)
		elif back:
			cv.rect(18, 17, 28, 2, a.darkened(0.3))
		else:
			cv.rect(21, 17, 22, 2, b)
			for y in range(18, 30):
				var sp := hs(dir, y)
				cv.rect(sp.x, y, 4, 1, a.darkened(0.15))
				cv.rect(sp.y - 3, y, 4, 1, a.darkened(0.15))
	elif k == "scholar":
		dome(cv, dir, 7, 11, a.darkened(0.2))
		cv.rect(10, 4, 44, 3, a)
		cv.rect(14, 2, 36, 2, a.lightened(0.1))
		cv.rect(14, 2, 36, 1, a.lightened(0.35))
		cv.rect(cx - 1, 2, 3, 2, b)
		var tx := 52 if not side else 14
		cv.line(tx, 5, tx, 16, b, 1.0)
		cv.rect(tx - 1, 16, 3, 4, b)
	elif k == "oracle":
		dome(cv, dir, 4, 13, a)
		dome(cv, dir, 13, 14, b)
		cv.rect(cx - 1, 4, 3, 9, a.darkened(0.12))
		var gx := 40 if side else 32
		cv.disc(gx, 12, 3.0, b.darkened(0.2))
		cv.disc(gx, 12, 2.0, b.lightened(0.3))
		cv.px(gx - 1, 11, Color.WHITE)
		for y in range(15, 36):
			var sp := hs(dir, y)
			var lx := sp.x - 1
			cv.rect(lx, y, 3, 1, a)
			cv.px(lx + 1, y, b)
			if not side:
				cv.rect(sp.y - 1, y, 3, 1, a)
				cv.px(sp.y, y, b)
	elif k == "weld":
		if back:
			cv.rect(8, 14, 48, 3, a)
			cv.disc(10, 15, 2.0, b)
			cv.disc(53, 15, 2.0, b)
			dome(cv, dir, 4, 11, a.lightened(0.1))
		else:
			var x0 := 17 if not side else 24
			var x1 := 49 if not side else 54
			cv.rrect(x0, 11, x1 - x0, 20, 3.0, a)
			cv.rect(x0 + 3, 17, x1 - x0 - 6, 6, b.darkened(0.55))
			cv.rect(x0 + 4, 18, x1 - x0 - 8, 4, b)
			cv.rect(x0 + 4, 18, x1 - x0 - 8, 1, b.lightened(0.5))
			cv.rect(x0 + 2, 25, x1 - x0 - 4, 1, a.lightened(0.2))
			cv.rect(x0 + 2, 28, x1 - x0 - 4, 1, a.lightened(0.2))
			dome(cv, dir, 5, 10, a.lightened(0.1))
	elif k == "pilot":
		dome(cv, dir, 4, 13, a)
		cv.rect(10, 9, 44, 2, b)
		cv.rect(cx - 1, 4, 3, 5, a.darkened(0.12))
		if back:
			cv.rect(8, 13, 48, 2, a.darkened(0.3))
		elif side:
			cv.disc(40, 15, 4.0, a.darkened(0.45))
			cv.disc(40, 15, 2.5, b)
			cv.px(39, 14, Color.WHITE)
			cv.rect(8, 13, 32, 2, a.darkened(0.3))
		else:
			cv.disc(23, 15, 4.0, a.darkened(0.45))
			cv.disc(23, 15, 2.5, b)
			cv.px(22, 14, Color.WHITE)
			cv.disc(40, 15, 4.0, a.darkened(0.45))
			cv.disc(40, 15, 2.5, b)
			cv.px(39, 14, Color.WHITE)
			cv.rect(26, 14, 11, 2, a.darkened(0.3))
	elif k == "riot":
		dome(cv, dir, 4, 12, a)
		cv.rect(cx - 1, 4, 3, 8, a.lightened(0.2))
		for y in range(13, 32):
			var sp := hs(dir, y)
			cv.rect(sp.x - 1, y, 5, 1, a)
			if not side:
				cv.rect(sp.y - 3, y, 5, 1, a)
		if not back:
			var v := vs(dir, 14)
			var x0 := 18 if not side else 24
			var x1 := 49 if not side else 54
			cv.rect(x0, 13, x1 - x0, 2, a.lightened(0.15))
			cv.line(x0 + 6, 28, x0 + 14, 17, b, 1.0)
			cv.line(x0 + 10, 28, x0 + 18, 17, b, 1.0)
			cv.rect(x0, 30, x1 - x0, 2, a)
		else:
			cv.rect(10, 13, 44, 2, a.lightened(0.15))
	elif k == "sentinel":
		dome(cv, dir, 4, 14, a)
		var fx := cx - 1
		cv.rect(fx, 0, 3, 14, b)
		cv.rect(fx, 0, 1, 14, b.lightened(0.4))
		cv.rect(10, 13, 44, 3, a.darkened(0.15))
		for y in range(16, 33):
			var sp := hs(dir, y)
			cv.rect(sp.x - 1, y, 5, 1, a.darkened(0.1))
			if not side:
				cv.rect(sp.y - 3, y, 5, 1, a.darkened(0.1))
	elif k == "crown":
		var ecl := bool(s.get("eclipse", false))
		var c := col(String(s.get("c", "ffffff")))
		var span := hs(dir, 9)
		var xl := span.x + 1
		var xr := span.y - 1
		var by := 8
		cv.rect(xl, by, xr - xl + 1, 4, a)
		cv.rect(xl, by, xr - xl + 1, 1, a.lightened(0.45))
		var n := 5 if not side else 4
		for i in n:
			var x := xl + 2 + int(float(xr - xl - 4) * float(i) / float(n - 1))
			var h := 6 if (i % 2 == 0) else 4
			if i == n / 2:
				h = 8
			cv.poly([Vector2(x - 3, by), Vector2(x + 3, by), Vector2(x, by - h)], a)
			cv.px(x, by - h, b)
		if ecl:
			cv.disc(cx, 6, 6.0, b)
			cv.disc(cx, 6, 4.5, c)
		else:
			cv.disc(cx, by + 2, 2.0, b)
			cv.px(cx - 1, by + 1, c)
			if not back:
				cv.px(xl + 4, by + 2, b)
				cv.px(xr - 4, by + 2, b)
	elif k == "crystal":
		dome(cv, dir, 9, 13, a.darkened(0.15))
		var shards: Array = [[22, 3, 11, 14], [30, 0, 9, 16], [40, 2, 10, 12]]
		for sh in shards:
			var sx: int = int(sh[0])
			var h: int = int(sh[2])
			var w: int = int(sh[3]) / 2
			var bx: int = sx - 5 if side else sx
			cv.poly([Vector2(bx - w / 2, 11), Vector2(bx + w / 2, 11), Vector2(bx, 11 - h)], a)
			cv.poly([Vector2(bx, 11), Vector2(bx + w / 2, 11), Vector2(bx, 11 - h)], a.lightened(0.3))
			cv.px(bx, 11 - h, b)
		if not back:
			var sp := hs(dir, 22)
			cv.poly([Vector2(sp.x - 3, 20), Vector2(sp.x + 3, 18), Vector2(sp.x - 1, 28)], b)
			if not side:
				cv.poly([Vector2(sp.y + 3, 20), Vector2(sp.y - 3, 18), Vector2(sp.y + 1, 28)], b)


# ------------------------------------------------------------------ body armour
static func plate(cv, dir: int, s: Dictionary) -> void:
	var a := col(String(s["a"]))
	var b := col(String(s["b"]))
	var c := col(String(s.get("c", s["a"])))
	var tex := String(s.get("tex", "plain"))
	var sh := String(s.get("sh", "none"))
	var side := dir == 3
	var back := dir == 1
	var tx0 := 19
	var tx1 := 44
	var ty0 := 39
	var ty1 := 51
	if side:
		tx0 = 22
		tx1 = 45
		ty1 = 52
	elif back:
		tx0 = 18
		tx1 = 45
	var w := tx1 - tx0
	var cx := (tx0 + tx1) / 2
	var ghost := bool(s.get("ghost", false))
	cv.poly([Vector2(tx0 + 1, ty0), Vector2(tx1, ty0), Vector2(tx1 + 1, ty1 - 3), Vector2(tx1 - 1, ty1 + 1), Vector2(tx0 + 2, ty1 + 1), Vector2(tx0 - 1, ty1 - 3)], a)
	# collar / top highlight
	cv.rect(tx0 + 2, ty0, w - 2, 1, a.lightened(0.3))
	if bool(s.get("trim", false)):
		cv.rect(tx0 + 1, ty0 + 1, w - 1, 1, b)
		cv.rect(tx0 + 1, ty1, w - 1, 1, b)
	# texture
	if tex == "jacket":
		cv.rect(cx, ty0 + 1, 1, ty1 - ty0, b)
		if not back and not side:
			cv.rect(tx0 + 2, ty0 + 6, 6, 4, a.darkened(0.2))
			cv.rect(tx1 - 7, ty0 + 6, 6, 4, a.darkened(0.2))
		cv.rect(tx0, ty0 + 3, w, 1, b.lightened(0.3))
	elif tex == "patch":
		cv.rect(tx0 + 3, ty0 + 2, 6, 5, b)
		cv.rect(tx1 - 9, ty0 + 5, 7, 5, b.darkened(0.2))
		cv.rect(cx - 2, ty0 + 8, 5, 3, c)
		for i in 4:
			cv.px(tx0 + 3 + i * 6, ty0 + 1, b.lightened(0.4))
	elif tex == "x":
		cv.line(tx0 + 2, ty0 + 1, tx1 - 2, ty1 - 1, b, 1.0)
		cv.line(tx1 - 2, ty0 + 1, tx0 + 2, ty1 - 1, b, 1.0)
		cv.rect(tx0 + 2, ty1 - 4, 5, 3, b.darkened(0.2))
		cv.rect(tx1 - 6, ty1 - 4, 5, 3, b.darkened(0.2))
	elif tex == "panels":
		cv.rect(cx, ty0 + 1, 1, ty1 - ty0 - 1, a.darkened(0.3))
		cv.rect(tx0 + 1, ty0 + 5, w - 2, 1, a.darkened(0.25))
		cv.rect(tx0 + 2, ty1 - 3, w - 4, 1, a.lightened(0.2))
	elif tex == "ribs":
		for i in range(ty0 + 2, ty1, 3):
			cv.rect(tx0 + 1, i, w - 2, 1, b)
		cv.rect(cx, ty0 + 1, 1, ty1 - ty0 - 1, a.darkened(0.25))
	elif tex == "quilt":
		for x in range(tx0 + 2, tx1, 5):
			cv.rect(x, ty0 + 1, 1, ty1 - ty0, a.darkened(0.3))
		for y in range(ty0 + 3, ty1, 4):
			cv.rect(tx0 + 1, y, w - 1, 1, b)
	elif tex == "rivets":
		for x in range(tx0 + 3, tx1 - 1, 5):
			cv.px(x, ty0 + 2, b)
			cv.px(x, ty1 - 2, b)
		cv.rect(cx, ty0 + 1, 1, ty1 - ty0 - 1, a.darkened(0.25))
	elif tex == "burn":
		cv.rect(tx0 + 2, ty0 + 3, 5, 3, c)
		cv.rect(tx1 - 8, ty0 + 7, 6, 3, c)
		cv.rect(cx - 3, ty1 - 4, 4, 2, c)
		cv.rect(tx0 + 1, ty0 + 1, w - 1, 1, b)
		cv.rect(tx0 + 1, ty1 - 1, w - 1, 1, b)
	elif tex == "weave":
		for yy in range(ty0 + 1, ty1):
			for xx in range(tx0 + 1, tx1):
				if (xx + yy) % 5 == 0:
					cv.px(xx, yy, b)
	elif tex == "scales":
		for y in range(ty0 + 2, ty1, 3):
			for x in range(tx0 + 2 + ((y - ty0) / 3 % 2) * 2, tx1 - 1, 4):
				cv.px(x, y, b)
				cv.px(x - 1, y + 1, a.darkened(0.25))
	elif tex == "shag":
		for y in range(ty0, ty1 + 1, 2):
			for x in range(tx0 + ((y / 2) % 3), tx1, 3):
				cv.px(x, y, b if ((x + y) % 4) < 2 else a.darkened(0.25))
	elif tex == "mirror":
		cv.rect(cx, ty0 + 1, 1, ty1 - ty0 - 1, a.darkened(0.3))
		cv.line(tx0 + 3, ty1 - 2, tx0 + 9, ty0 + 2, b, 1.0)
		cv.line(cx + 3, ty1 - 2, cx + 9, ty0 + 2, b, 1.0)
	elif tex == "stars":
		var pts: Array = [[3, 2], [9, 5], [15, 2], [6, 9], [20, 7], [12, 10], [18, 11], [1, 7], [23, 3]]
		for p in pts:
			var px: int = tx0 + int(p[0]) % w
			cv.px(px, ty0 + int(p[1]), b)
		cv.px(tx0 + 9, ty0 + 5, c)
		cv.px(tx0 + 15, ty0 + 2, c)
		cv.px(tx0 + 12, ty0 + 10, c)
	if bool(s.get("belt", false)):
		cv.rect(tx0, ty1 - 2, w + 1, 2, c if String(s.get("c", "")) != "" else b)
		if not back:
			cv.rect(cx - 1, ty1 - 2, 3, 2, Color("ffd84f"))
	# emblem on the chest (front and side only)
	if not back:
		var ex := cx if not side else 38
		var ey := ty0 + 5
		var em := String(s.get("em", "none"))
		if em == "dot":
			cv.disc(ex, ey, 2.0, b)
		elif em == "core":
			cv.disc(ex, ey, 3.5, a.darkened(0.45))
			cv.disc(ex, ey, 2.4, b)
			cv.px(ex - 1, ey - 1, Color.WHITE)
		elif em == "diamond":
			cv.poly([Vector2(ex, ey - 4), Vector2(ex + 4, ey), Vector2(ex, ey + 4), Vector2(ex - 4, ey)], b)
			cv.poly([Vector2(ex, ey - 2), Vector2(ex + 2, ey), Vector2(ex, ey + 2), Vector2(ex - 2, ey)], a.darkened(0.35))
		elif em == "horizon":
			cv.disc(ex, ey, 5.0, b)
			cv.disc(ex, ey, 3.5, c)
			cv.px(ex + 2, ey - 3, b.lightened(0.5))
	# shoulders
	var sxs: Array = []
	if side:
		sxs = [29]
	else:
		sxs = [tx0 - 4, tx1 + 4]
	for sx in sxs:
		var sy := ty0 + 2
		if sh == "pad":
			cv.ell(sx, sy, 5.0, 4.0, a.lightened(0.1))
			cv.ell(sx, sy - 1, 3.0, 1.5, a.lightened(0.4))
		elif sh == "big":
			cv.ell(sx, sy, 7.0, 5.5, a.lightened(0.05))
			cv.ell(sx, sy - 1, 5.0, 2.0, a.lightened(0.4))
			cv.rect(sx - 6, sy + 3, 13, 1, b)
		elif sh == "spike":
			cv.ell(sx, sy, 5.0, 4.0, a.lightened(0.1))
			cv.poly([Vector2(sx - 3, sy - 2), Vector2(sx + 3, sy - 2), Vector2(sx, sy - 8)], b)
		elif sh == "fur":
			for i in 5:
				cv.line(sx - 4 + i * 2, sy - 2, sx - 5 + i * 2, sy + 4, b if i % 2 == 0 else a, 1.0)
	if ghost:
		cv.px(tx0 - 2, ty0 + 4, b)
		cv.px(tx1 + 2, ty0 + 7, b)
		cv.px(tx0 - 1, ty1 - 1, b)
		cv.px(tx1 + 1, ty1 - 3, b)


# ------------------------------------------------------------------ boots
static func boots(cv, dir: int, s: Dictionary) -> void:
	var a := col(String(s["a"]))
	var b := col(String(s["b"]))
	var c := col(String(s.get("c", s["a"])))
	var f := String(s.get("f", "plain"))
	var feet: Array = []
	var y0 := 54
	if dir == 0:
		feet = [[20, 11], [36, 11]]
	elif dir == 1:
		feet = [[21, 10], [36, 10]]
		y0 = 58
	else:
		feet = [[23, 11], [35, 11]]
		y0 = 55
	for ft in feet:
		var x: int = int(ft[0])
		var w: int = int(ft[1])
		var h := 62 - y0
		cv.rrect(x, y0, w, h - 1, 2.0, a)
		cv.rect(x, 61, w, 1, c)
		cv.rect(x + 1, y0, w - 2, 1, a.lightened(0.35))
		if dir == 3:
			cv.rrect(x + w - 6, y0 + 2, 7, h - 3, 2.0, a.lightened(0.12))
		if f == "laces":
			for i in 3:
				cv.rect(x + 3 + i * 3, y0 + 1, 2, 1, b)
			cv.rect(x, 60, w, 1, b)
		elif f == "mag":
			cv.rect(x, y0 + 2, w, 2, b)
			cv.rect(x + 1, 60, w - 2, 2, b.darkened(0.3))
		elif f == "jet":
			cv.rect(x, y0 + 1, w, 2, c)
			if dir == 3:
				cv.poly([Vector2(x - 1, 58), Vector2(x - 6, 61), Vector2(x - 1, 62)], b)
			else:
				cv.poly([Vector2(x + 2, 62), Vector2(x + w - 2, 62), Vector2(x + w / 2, 64)], b)
		elif f == "tread":
			cv.rect(x, y0 + 2, w, 1, b)
			for i in range(x + 1, x + w, 2):
				cv.px(i, 61, b)
		elif f == "ring":
			cv.ell(x + w / 2, y0 + 1, w * 0.5 + 1.0, 2.0, b.darkened(0.25))
			cv.ell(x + w / 2, y0, w * 0.5 + 1.0, 1.4, b)
		elif f == "ghost":
			for i in range(x, x + w, 2):
				cv.px(i, y0 + 1 + (i % 3), b)
			cv.rect(x, 61, w, 1, b)
		elif f == "plain":
			cv.rect(x, 60, w, 2, b)
		elif f == "spike":
			for i in range(x + 1, x + w - 1, 3):
				cv.poly([Vector2(i, 61), Vector2(i + 2, 61), Vector2(i + 1, 63)], b)
			if dir == 3:
				cv.poly([Vector2(x + w, 57), Vector2(x + w + 3, 59), Vector2(x + w, 60)], b)
		elif f == "bolt":
			cv.line(x + 2, y0 + 1, x + 5, y0 + 3, b, 1.0)
			cv.line(x + 5, y0 + 3, x + 3, y0 + 5, b, 1.0)
			cv.rect(x, 60, w, 1, b)
		elif f == "pad":
			cv.rect(x - 1, 62, w + 2, 1, b)
			cv.rect(x + 1, 63, w - 2, 1, b.darkened(0.3))
			cv.rect(x, 61, w, 1, c)
		elif f == "swirl":
			cv.px(x + 3, y0 + 2, b)
			cv.px(x + 5, y0 + 3, b.lightened(0.4))
			cv.px(x + 7, y0 + 2, b)
			cv.rect(x, 60, w, 1, b)
		elif f == "crys":
			for i in range(x + 1, x + w - 1, 4):
				cv.poly([Vector2(i, 61), Vector2(i + 3, 61), Vector2(i + 1, 58)], b)
			cv.rect(x, y0 + 1, w, 1, b)
		elif f == "hazard":
			for i in range(x, x + w, 4):
				cv.rect(i, y0 + 2, 2, 2, b)
			cv.rect(x, 60, w, 1, b)
		elif f == "worm":
			cv.px(x + 3, y0 + 2, Color("ff6ad5"))
			cv.px(x + 5, y0 + 3, b)
			cv.px(x + 7, y0 + 2, Color("ffd84f"))
			cv.px(x + 4, y0 + 4, Color("9bff6a"))

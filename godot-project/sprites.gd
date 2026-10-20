extends RefCounted
# Procedural pixel-art generator for Pocket Station. Everything is drawn into small
# Images with a tiny raster toolkit (shapes, shading pass, outline pass) and cached.

var themes: Array = []
var cache: Dictionary = {}

const FONT3 := {
	"O": ["111", "101", "101", "101", "111"],
	"2": ["111", "001", "111", "100", "111"],
	"$": ["011", "110", "111", "011", "110"],
}


class Cv:
	var img: Image
	var w: int
	var h: int

	func _init(w_: int = 32, h_: int = 32) -> void:
		w = w_
		h = h_
		img = Image.create(w, h, false, Image.FORMAT_RGBA8)

	func px(x: int, y: int, c: Color) -> void:
		if x >= 0 and y >= 0 and x < w and y < h:
			img.set_pixel(x, y, c)

	func sa(src: Image, x: int, y: int) -> float:
		if x < 0 or y < 0 or x >= w or y >= h:
			return 0.0
		return src.get_pixel(x, y).a

	func rect(x: int, y: int, rw: int, rh: int, c: Color) -> void:
		for yy in range(y, y + rh):
			for xx in range(x, x + rw):
				px(xx, yy, c)

	func rrect(x: int, y: int, rw: int, rh: int, r: float, c: Color) -> void:
		for yy in range(y, y + rh):
			for xx in range(x, x + rw):
				var cx := clampf(float(xx) + 0.5, float(x) + r, float(x + rw) - r)
				var cy := clampf(float(yy) + 0.5, float(y) + r, float(y + rh) - r)
				var dx := float(xx) + 0.5 - cx
				var dy := float(yy) + 0.5 - cy
				if dx * dx + dy * dy <= r * r + 0.01:
					px(xx, yy, c)

	func disc(cx: float, cy: float, r: float, c: Color) -> void:
		ell(cx, cy, r, r, c)

	func ell(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
		for yy in range(int(cy - ry) - 1, int(cy + ry) + 2):
			for xx in range(int(cx - rx) - 1, int(cx + rx) + 2):
				var dx := (float(xx) + 0.5 - cx) / rx
				var dy := (float(yy) + 0.5 - cy) / ry
				if dx * dx + dy * dy <= 1.0:
					px(xx, yy, c)

	func line(x0: float, y0: float, x1: float, y1: float, c: Color, th: float = 1.0) -> void:
		var n := int(maxf(absf(x1 - x0), absf(y1 - y0)) * 2.0) + 1
		for i in n + 1:
			var t := float(i) / float(n)
			var x := lerpf(x0, x1, t)
			var y := lerpf(y0, y1, t)
			if th <= 1.0:
				px(int(floor(x)), int(floor(y)), c)
			else:
				disc(x, y, th * 0.5, c)

	func poly(pts: Array, c: Color) -> void:
		var miny := 9999
		var maxy := -9999
		for p in pts:
			miny = mini(miny, int(p.y))
			maxy = maxi(maxy, int(p.y))
		for yy in range(miny, maxy + 1):
			var ys := float(yy) + 0.5
			var xs: Array = []
			for i in pts.size():
				var p0: Vector2 = pts[i]
				var p1: Vector2 = pts[(i + 1) % pts.size()]
				if (p0.y <= ys and p1.y > ys) or (p1.y <= ys and p0.y > ys):
					xs.append(p0.x + (ys - p0.y) / (p1.y - p0.y) * (p1.x - p0.x))
			xs.sort()
			var k := 0
			while k + 1 < xs.size():
				for xx in range(int(round(xs[k])), int(round(xs[k + 1]))):
					px(xx, yy, c)
				k += 2

	func shade(strength: float = 0.28) -> void:
		var src := img.duplicate() as Image
		for yy in h:
			for xx in w:
				var c := src.get_pixel(xx, yy)
				if c.a < 0.5:
					continue
				var t := float(xx + yy) / float(w + h)
				if t < 0.5:
					c = c.lightened((0.5 - t) * strength * 0.7)
				else:
					c = c.darkened((t - 0.5) * strength * 0.9)
				if sa(src, xx - 1, yy) < 0.5 or sa(src, xx, yy - 1) < 0.5 or sa(src, xx - 1, yy - 1) < 0.5:
					c = c.lightened(strength)
				elif sa(src, xx + 1, yy) < 0.5 or sa(src, xx, yy + 1) < 0.5 or sa(src, xx + 1, yy + 1) < 0.5:
					c = c.darkened(strength * 1.2)
				img.set_pixel(xx, yy, c)

	func outline(col: Color) -> void:
		var src := img.duplicate() as Image
		for yy in h:
			for xx in w:
				if src.get_pixel(xx, yy).a >= 0.5:
					continue
				if sa(src, xx - 1, yy) >= 0.5 or sa(src, xx + 1, yy) >= 0.5 or sa(src, xx, yy - 1) >= 0.5 or sa(src, xx, yy + 1) >= 0.5:
					img.set_pixel(xx, yy, col)

	func mirror() -> void:
		for yy in h:
			for xx in range(0, w / 2):
				var c := img.get_pixel(xx, yy)
				if c.a >= 0.5:
					img.set_pixel(w - 1 - xx, yy, c)

	func speckle(rng: RandomNumberGenerator, c: Color, n: int) -> void:
		for i in n:
			var x := rng.randi_range(0, w - 1)
			var y := rng.randi_range(0, h - 1)
			if img.get_pixel(x, y).a >= 0.5:
				img.set_pixel(x, y, c)

	func glyph(rows: Array, x: int, y: int, c: Color) -> void:
		for ry in rows.size():
			var r: String = rows[ry]
			for rx in r.length():
				if r[rx] == "1":
					px(x + rx, y + ry, c)

	# Procedural art is drawn on 32x32 canvases; every texture is handed out at 2x (nearest) so it lines up with 64px atlas art.
	func tex() -> ImageTexture:
		var im: Image = img.duplicate()
		im.resize(w * 2, h * 2, Image.INTERPOLATE_NEAREST)
		return ImageTexture.create_from_image(im)


var _atlas_img: Dictionary = {}


func _init(th: Array) -> void:
	themes = th


# Hand-drawn sci-fi atlases (art/*.png). Returns null if missing so the procedural art stays as fallback.
const TEX_PX := 64


# cell = pixel size of one cell in the atlas file (32 for the current atlases, 64 for new ones). Output is always TEX_PX.
func _atlas_cell(path: String, col: int, row: int, cell: int = 32) -> ImageTexture:
	if not _atlas_img.has(path):
		var src: Texture2D = load(path) as Texture2D
		_atlas_img[path] = src.get_image() if src != null else null
	var im: Image = _atlas_img[path]
	if im == null or (col + 1) * cell > im.get_width() or (row + 1) * cell > im.get_height():
		return null
	var out: Image = im.get_region(Rect2i(col * cell, row * cell, cell, cell))
	if cell != TEX_PX:
		out.resize(TEX_PX, TEX_PX, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(out)


func _text(cv: Cv, s: String, x: int, y: int, c: Color) -> void:
	var cx := x
	for ch in s:
		if FONT3.has(ch):
			cv.glyph(FONT3[ch], cx, y, c)
		cx += 4


# ---------------------------------------------------------------- player

# ---------------------------------------------------------------- player + gear art

const ART := {
	"dagger": {"s": "dagger", "a": "d5dbe8", "b": "8a93b5", "c": "7a4a1e"},
	"wrench": {"s": "wrench", "a": "c9a23a", "b": "ff7a45", "c": "6b7388"},
	"arcblade": {"s": "blade", "a": "7fe8ff", "b": "e8fbff", "c": "3a4160"},
	"plasmaaxe": {"s": "axe", "a": "ff6ad5", "b": "ffd1f2", "c": "5a3d20"},
	"leechfang": {"s": "fang", "a": "e8f2d0", "b": "6dff9a", "c": "3a4a2a"},
	"railspike": {"s": "rail", "a": "c5cde6", "b": "4f9bff", "c": "3a4160"},
	"voidcutter": {"s": "cutter", "a": "b57cff", "b": "f0e0ff", "c": "2a1c46"},
	"stunbaton": {"s": "baton", "a": "ffe14f", "b": "fff6b0", "c": "2b2f3d"},
	"cutlass": {"s": "cutlass", "a": "ffb347", "b": "fff0c8", "c": "6b4a2a"},
	"gravhammer": {"s": "hammer", "a": "6b86c9", "b": "9fe0ff", "c": "4a3a2a"},
	"ionlance": {"s": "lance", "a": "e8f2ff", "b": "4fd1ff", "c": "5a6280"},
	"katana": {"s": "katana", "a": "eef2fa", "b": "ff5d5d", "c": "2a2f40"},
	"singedge": {"s": "edge", "a": "2a2147", "b": "c07cff", "c": "14101f"},
	"novacleaver": {"s": "cleaver", "a": "d8dde8", "b": "ff7a45", "c": "6b3a1e"},
	"blaster": {"s": "pistol", "a": "9aa3c7", "b": "7fe8ff", "c": "3a4160"},
	"thornbow": {"s": "xbow", "a": "8a5a2a", "b": "c9e8a0", "c": "4a3a2a"},
	"arccarbine": {"s": "carbine", "a": "6b7388", "b": "ffe14f", "c": "2b2f3d"},
	"plasmarifle": {"s": "rifle", "a": "5a6280", "b": "ff6ad5", "c": "2a2f40"},
	"railsniper": {"s": "sniper", "a": "c5cde6", "b": "4f9bff", "c": "3a4160"},
	"visor": {"s": "visor", "a": "9aa3c7", "b": "4fd1ff"},
	"hardcap": {"s": "cap", "a": "ffd23a", "b": "c9961a"},
	"rebreather": {"s": "mask", "a": "5a6280", "b": "9fe0ff"},
	"tachelm": {"s": "tac", "a": "3d5a40", "b": "6dff9a"},
	"scholar": {"s": "scholar", "a": "2a3a6a", "b": "ffd84f"},
	"oracle": {"s": "oracle", "a": "e8e0f8", "b": "c07cff"},
	"weldmask": {"s": "weld", "a": "2b2f3d", "b": "ff9a3c"},
	"pilothelm": {"s": "pilot", "a": "e8ebf5", "b": "4f8cff"},
	"riothelm": {"s": "riot", "a": "3a4160", "b": "9fe0ff"},
	"sentinel": {"s": "sentinel", "a": "9fb3d9", "b": "ff5d5d"},
	"voidcrown": {"s": "crown", "a": "2a1c46", "b": "c07cff"},
	"jacket": {"s": "jacket", "a": "6b7a9a", "b": "c9a55a"},
	"scrap": {"s": "scrap", "a": "8a7a6a", "b": "b8683a"},
	"kevlar": {"s": "kevlar", "a": "2f3a4a", "b": "7b8aa8"},
	"reactive": {"s": "reactive", "a": "7a2a2a", "b": "ff5d5d"},
	"exo": {"s": "exo", "a": "9fb3d9", "b": "4fd1ff"},
	"bulwark": {"s": "bulwark", "a": "5a6a9a", "b": "ffd84f"},
	"padded": {"s": "padded", "a": "7a5a3a", "b": "b8946a"},
	"riveted": {"s": "riveted", "a": "6a727f", "b": "c5cde6"},
	"ablative": {"s": "ablative", "a": "e8dcc0", "b": "7db2ff"},
	"titan": {"s": "titan", "a": "8a8f9f", "b": "ffd84f"},
	"phaseweave": {"s": "weave", "a": "3a2a6a", "b": "7fe8ff"},
	"aegiscore": {"s": "core", "a": "2a3a5a", "b": "4fffb0"},
	"sneakers": {"s": "sneak", "a": "f0f0f0", "b": "4fd1ff"},
	"magboots": {"s": "mag", "a": "4a4f6a", "b": "ff5d5d"},
	"jets": {"s": "jet", "a": "6b7388", "b": "ff9a3c"},
	"grip": {"s": "grip", "a": "3d4a3a", "b": "6dff9a"},
	"gravity": {"s": "grav", "a": "4a3a6a", "b": "c07cff"},
	"phase": {"s": "phase", "a": "1b2440", "b": "7fe8ff"},
	"soles": {"s": "soles", "a": "5a4a3a", "b": "d9c9a0"},
	"spiked": {"s": "spiked", "a": "3a3a44", "b": "e8e8f0"},
	"runner": {"s": "runner", "a": "ff7a45", "b": "ffe0b0"},
	"hover": {"s": "hover", "a": "5a6280", "b": "7fe8ff"},
	"warp": {"s": "warp", "a": "2a1c46", "b": "ffd84f"},
	"luckychip": {"s": "chip", "a": "ffd84f", "b": "fff3a8"},
	"battery": {"s": "cell", "a": "4f9bff", "b": "e6f4ff"},
	"medpatch": {"s": "patch", "a": "ff6b6b", "b": "ffffff"},
	"podamp": {"s": "amp", "a": "7fd8ff", "b": "e6fbff"},
	"ward": {"s": "ward", "a": "7db2ff", "b": "e0f0ff"},
	"reaperchip": {"s": "reaper", "a": "e8e8f0", "b": "ff4f4f"},
	"datalens": {"s": "lens", "a": "4fd1ff", "b": "e6fbff"},
	"goldtooth": {"s": "tooth", "a": "ffd84f", "b": "fff3a8"},
	"stimpack": {"s": "stim", "a": "ff8a9a", "b": "ffe0e6"},
	"aegisemit": {"s": "emit", "a": "9fb3ff", "b": "ffffff"},
	"battlecore": {"s": "bcore", "a": "ff7a45", "b": "ffe0a0"},
	"fusioncell": {"s": "fusion", "a": "6dff9a", "b": "eaffee"},
	"stationheart": {"s": "heart", "a": "ff4f6a", "b": "ffc0cc"},
	"overlord": {"s": "overlord", "a": "c07cff", "b": "ffd84f"},
	"prismblade": {"s": "blade", "a": "d58cff", "b": "f5e6ff", "c": "3a2a6a"},
	"shardspear": {"s": "lance", "a": "c9a0ff", "b": "7fe8ff", "c": "4a3a6a"},
	"scattergun": {"s": "carbine", "a": "8a6a4a", "b": "ff9a3c", "c": "3a2a1a"},
	"gaussrep": {"s": "rifle", "a": "4a6a6a", "b": "7fffd4", "c": "1a2a2a"},
	"targetvisor": {"s": "visor", "a": "6a7a5a", "b": "ff5d5d"},
	"crystalhelm": {"s": "riot", "a": "6a4fc0", "b": "d0a8ff"},
	"hazmask": {"s": "mask", "a": "c9a23a", "b": "3a3a3a"},
	"crystalmail": {"s": "titan", "a": "8a5ad0", "b": "7fe8ff"},
	"ghillie": {"s": "jacket", "a": "4a6a3a", "b": "9ac86a"},
	"mirrorvest": {"s": "kevlar", "a": "c5cde6", "b": "ffffff"},
	"crystaltreads": {"s": "hover", "a": "6a4fc0", "b": "ff8ad0"},
	"hazboots": {"s": "grip", "a": "c9a23a", "b": "2b2f3d"},
	"ammorecycler": {"s": "cell", "a": "ffd84f", "b": "fff6b0"},
	"scopemod": {"s": "lens", "a": "ff5d5d", "b": "ffd0d0"},
	"critoptics": {"s": "lens", "a": "d58cff", "b": "f5e6ff"},
}

const SLOT_ORDER := ["weapon", "helmet", "armour", "boots", "trinket"]


func _ac(art: Dictionary, k: String) -> Color:
	return Color(String(art[k]))


func _quad(cv: Cv, o: Vector2, d: Vector2, a0: float, a1: float, w0: float, w1: float, c: Color, off := 0.0) -> void:
	var p := Vector2(-d.y, d.x)
	var s0 := o + d * a0 + p * off
	var s1 := o + d * a1 + p * off
	cv.poly([s0 + p * w0, s1 + p * w1, s1 - p * w1, s0 - p * w0], c)


func _weapon(cv: Cv, art: Dictionary, g: Vector2, d: Vector2, k: float) -> void:
	var a := _ac(art, "a")
	var b := _ac(art, "b")
	var c := _ac(art, "c")
	var s := String(art["s"])
	var p := Vector2(-d.y, d.x)
	_quad(cv, g, d, -2.5 * k, 2.8 * k, 0.9 * k, 0.9 * k, c)
	if s == "dagger":
		_quad(cv, g, d, 2.6 * k, 3.7 * k, 2.2 * k, 2.2 * k, b)
		_quad(cv, g, d, 3.7 * k, 11.0 * k, 1.5 * k, 0.4 * k, a)
		cv.line((g + d * 4.5 * k).x, (g + d * 4.5 * k).y, (g + d * 10.0 * k).x, (g + d * 10.0 * k).y, a.lightened(0.5))
	elif s == "wrench":
		_quad(cv, g, d, 2.5 * k, 10.0 * k, 1.0 * k, 1.0 * k, a)
		_quad(cv, g, d, -2.5 * k, 2.5 * k, 1.2 * k, 1.2 * k, b)
		_quad(cv, g, d, 9.5 * k, 12.8 * k, 2.7 * k, 2.7 * k, a)
		_quad(cv, g, d, 11.4 * k, 13.2 * k, 1.0 * k, 1.0 * k, Color(0, 0, 0, 0))
		var hp := g + d * 10.5 * k
		cv.px(int(hp.x - p.x * 1.6 * k), int(hp.y - p.y * 1.6 * k), a.lightened(0.5))
	elif s == "blade":
		_quad(cv, g, d, 2.2 * k, 3.4 * k, 3.4 * k, 3.4 * k, c.lightened(0.35))
		_quad(cv, g, d, 3.4 * k, 14.0 * k, 1.9 * k, 1.2 * k, a)
		_quad(cv, g, d, 3.4 * k, 13.2 * k, 0.8 * k, 0.5 * k, b)
		var tp := g + d * 14.6 * k
		cv.px(int(tp.x), int(tp.y), b)
	elif s == "cutlass":
		cv.disc((g + d * 2.6 * k).x, (g + d * 2.6 * k).y, 2.4 * k, c.lightened(0.2))
		var lastp := g + d * 3.0 * k
		for i in range(1, 9):
			var tt := float(i) / 8.0
			var np := g + d * (3.0 + 11.0 * tt) * k + p * sin(tt * PI * 0.9) * 2.6 * k
			cv.line(lastp.x, lastp.y, np.x, np.y, a, maxf(1.0, 2.6 * k * (1.0 - 0.6 * tt)))
			cv.px(int(np.x - p.x * 0.8 * k), int(np.y - p.y * 0.8 * k), b)
			lastp = np
	elif s == "axe":
		_quad(cv, g, d, 2.5 * k, 12.0 * k, 0.9 * k, 0.9 * k, c)
		cv.poly([g + d * 8.0 * k + p * 1.0 * k, g + d * 8.0 * k + p * 5.6 * k, g + d * 12.8 * k + p * 6.6 * k, g + d * 12.8 * k + p * 0.9 * k], a)
		cv.poly([g + d * 8.5 * k - p * 0.9 * k, g + d * 11.8 * k - p * 0.9 * k, g + d * 10.2 * k - p * 3.6 * k], c.lightened(0.3))
		var e0 := g + d * 8.2 * k + p * 5.6 * k
		var e1 := g + d * 12.8 * k + p * 6.6 * k
		cv.line(e0.x, e0.y, e1.x, e1.y, b)
	elif s == "fang":
		cv.disc((g + d * 3.0 * k).x, (g + d * 3.0 * k).y, 1.9 * k, b)
		for i in 8:
			var tt := float(i) / 7.0
			var fp := g + d * (3.0 + 11.0 * tt) * k - p * tt * tt * 4.2 * k
			cv.disc(fp.x, fp.y, maxf(0.7, 2.0 * k * (1.0 - tt) + 0.3 * k), a)
	elif s == "rail":
		_quad(cv, g, d, 2.5 * k, 16.0 * k, 0.9 * k, 0.5 * k, a)
		_quad(cv, g, d, 2.8 * k, 5.0 * k, 2.0 * k, 2.0 * k, b)
		var r0 := g + d * 5.0 * k
		var r1 := g + d * 14.0 * k
		cv.line(r0.x + p.x * 1.4 * k, r0.y + p.y * 1.4 * k, r1.x + p.x * 0.8 * k, r1.y + p.y * 0.8 * k, b)
		cv.line(r0.x - p.x * 1.4 * k, r0.y - p.y * 1.4 * k, r1.x - p.x * 0.8 * k, r1.y - p.y * 0.8 * k, b)
		var tp2 := g + d * 16.6 * k
		cv.px(int(tp2.x), int(tp2.y), b.lightened(0.5))
	elif s == "cutter":
		var outer: Array = []
		var inner: Array = []
		for i in 10:
			var tt := float(i) / 9.0
			var base := g + d * (2.6 + 11.0 * tt) * k
			outer.append(base + p * sin(tt * PI) * 5.2 * k)
			inner.append(base + p * sin(tt * PI) * 1.2 * k)
		inner.reverse()
		cv.poly(outer + inner, a)
		for i in range(outer.size() - 1):
			var o0: Vector2 = outer[i]
			var o1: Vector2 = outer[i + 1]
			cv.line(o0.x, o0.y, o1.x, o1.y, b)
	elif s == "baton":
		_quad(cv, g, d, -2.0 * k, 9.0 * k, 1.2 * k, 1.2 * k, c)
		_quad(cv, g, d, 9.0 * k, 12.5 * k, 0.7 * k, 0.7 * k, a, 1.5 * k)
		_quad(cv, g, d, 9.0 * k, 12.5 * k, 0.7 * k, 0.7 * k, a, -1.5 * k)
		var sp := g + d * 11.2 * k
		cv.px(int(sp.x), int(sp.y), b)
		cv.px(int(sp.x + p.x * 2.4 * k), int(sp.y + p.y * 2.4 * k), b)
		cv.px(int(sp.x - p.x * 2.4 * k), int(sp.y - p.y * 2.4 * k), b)
		_quad(cv, g, d, 2.0 * k, 4.0 * k, 1.5 * k, 1.5 * k, a)
	elif s == "hammer":
		_quad(cv, g, d, 2.5 * k, 11.0 * k, 0.9 * k, 0.9 * k, c)
		_quad(cv, g, d, 9.0 * k, 13.4 * k, 3.7 * k, 3.7 * k, a)
		_quad(cv, g, d, 10.0 * k, 12.4 * k, 1.9 * k, 1.9 * k, b)
		_quad(cv, g, d, 9.0 * k, 9.8 * k, 3.7 * k, 3.7 * k, a.darkened(0.25))
	elif s == "lance":
		_quad(cv, g, d, 2.5 * k, 14.0 * k, 0.9 * k, 0.9 * k, c)
		_quad(cv, g, d, 11.0 * k, 17.5 * k, 1.1 * k, 0.3 * k, a)
		_quad(cv, g, d, 10.5 * k, 15.0 * k, 0.5 * k, 0.3 * k, a, 2.0 * k)
		_quad(cv, g, d, 10.5 * k, 15.0 * k, 0.5 * k, 0.3 * k, a, -2.0 * k)
		var op := g + d * 10.0 * k
		cv.disc(op.x, op.y, 1.4 * k, b)
	elif s == "katana":
		_quad(cv, g, d, -2.5 * k, 2.2 * k, 1.1 * k, 1.1 * k, c)
		for i in range(-2, 3):
			var wp := g + d * float(i) * k
			cv.px(int(wp.x), int(wp.y), b)
		cv.disc((g + d * 2.8 * k).x, (g + d * 2.8 * k).y, 1.9 * k, c.lightened(0.35))
		var lp := g + d * 3.2 * k
		for i in range(1, 9):
			var tt := float(i) / 8.0
			var kp := g + d * (3.2 + 12.4 * tt) * k + p * sin(tt * PI) * 1.2 * k
			cv.line(lp.x, lp.y, kp.x, kp.y, a, maxf(1.0, 1.7 * k * (1.0 - 0.55 * tt)))
			lp = kp
	elif s == "edge":
		_quad(cv, g, d, 2.2 * k, 3.6 * k, 3.0 * k, 3.0 * k, b)
		_quad(cv, g, d, 3.6 * k, 15.0 * k, 2.6 * k, 1.2 * k, b)
		_quad(cv, g, d, 3.6 * k, 14.6 * k, 1.8 * k, 0.7 * k, a)
		var c0 := g + d * 5.0 * k
		var c1 := g + d * 13.0 * k
		cv.line(c0.x, c0.y, c1.x, c1.y, b.lightened(0.4))
	elif s == "cleaver":
		_quad(cv, g, d, 2.5 * k, 3.5 * k, 2.6 * k, 2.6 * k, c.lightened(0.3))
		_quad(cv, g, d, 3.5 * k, 13.5 * k, 3.1 * k, 3.1 * k, a)
		_quad(cv, g, d, 3.5 * k, 13.5 * k, 0.8 * k, 0.8 * k, b, 2.9 * k)
		_quad(cv, g, d, 3.5 * k, 13.5 * k, 0.7 * k, 0.7 * k, a.darkened(0.3), -2.6 * k)
		var hp2 := g + d * 10.0 * k
		cv.disc(hp2.x, hp2.y, 0.9 * k, Color(0, 0, 0, 0))
	elif s == "xbow":
		_quad(cv, g, d, 1.0 * k, 11.0 * k, 1.0 * k, 1.0 * k, a)
		var l0 := g + d * 8.5 * k - p * 6.0 * k
		var l1 := g + d * 11.0 * k
		var l2 := g + d * 8.5 * k + p * 6.0 * k
		cv.line(l0.x, l0.y, l1.x, l1.y, c.lightened(0.2), maxf(1.0, 1.4 * k))
		cv.line(l1.x, l1.y, l2.x, l2.y, c.lightened(0.2), maxf(1.0, 1.4 * k))
		cv.line(l0.x, l0.y, g.x + d.x * 4.0 * k, g.y + d.y * 4.0 * k, b)
		cv.line(l2.x, l2.y, g.x + d.x * 4.0 * k, g.y + d.y * 4.0 * k, b)
		var bp2 := g + d * 12.0 * k
		cv.px(int(bp2.x), int(bp2.y), b)
	elif s == "pistol" or s == "carbine" or s == "rifle" or s == "sniper":
		var ln := 7.0
		if s == "carbine":
			ln = 10.0
		elif s == "rifle":
			ln = 13.0
		elif s == "sniper":
			ln = 17.0
		_quad(cv, g, d, 2.0 * k, ln * k, 1.6 * k, 1.1 * k, a)
		_quad(cv, g, d, 3.0 * k, ln * 0.7 * k, 0.5 * k, 0.5 * k, b)
		_quad(cv, g, d, 1.0 * k, 3.5 * k, 2.2 * k, 2.2 * k, c.lightened(0.25))
		if s == "sniper":
			_quad(cv, g, d, 6.0 * k, 10.0 * k, 0.8 * k, 0.8 * k, b, -1.9 * k)
		var mzp := g + d * (ln + 0.9) * k
		cv.px(int(mzp.x), int(mzp.y), b.lightened(0.5))


func _helm(cv: Cv, dir: int, art: Dictionary) -> void:
	var a := _ac(art, "a")
	var b := _ac(art, "b")
	var s := String(art["s"])
	var side := dir >= 2
	var back := dir == 1
	var hx := 16.5 if side else 16.0
	if s == "visor":
		if back:
			cv.rect(8, 7, 16, 1, a)
			cv.line(22, 3, 25, 0, a)
			cv.px(25, 0, b)
		elif side:
			cv.ell(20.3, 8.8, 3.9, 2.3, a.darkened(0.35))
			cv.rect(18, 8, 6, 1, b)
			cv.line(12, 4, 10, 0, a)
			cv.px(10, 0, b)
		else:
			cv.rect(9, 7, 14, 4, a.darkened(0.35))
			cv.rect(10, 8, 12, 1, b)
			cv.rect(8, 8, 2, 3, a)
			cv.rect(22, 8, 2, 3, a)
			cv.line(23, 4, 25, 0, a)
			cv.px(25, 0, b)
	elif s == "cap":
		cv.ell(hx, 5.0, 8.6, 5.0, a)
		cv.rect(int(hx) - 9, 7, 18, 2, a.darkened(0.15))
		if side:
			cv.rect(int(hx) + 4, 7, 6, 2, a.darkened(0.15))
		cv.rect(int(hx) - 1, 1, 2, 5, a.lightened(0.35))
		cv.px(int(hx) - 4, 3, a.lightened(0.5))
	elif s == "mask":
		if back:
			cv.rect(8, 10, 16, 2, a)
			cv.line(9, 12, 8, 20, b)
			cv.line(23, 12, 24, 20, b)
		elif side:
			cv.rrect(19, 10, 6, 6, 2.0, a)
			cv.disc(22.5, 13, 1.8, b)
			cv.line(21, 15, 19, 22, b)
		else:
			cv.rrect(10, 10, 12, 6, 2.0, a)
			cv.disc(11.5, 13, 2.0, b)
			cv.disc(20.5, 13, 2.0, b)
			cv.line(10, 15, 8, 22, a.darkened(0.2))
			cv.line(22, 15, 24, 22, a.darkened(0.2))
			cv.rect(14, 13, 4, 1, a.lightened(0.4))
	elif s == "tac":
		cv.ell(hx, 5.4, 8.5, 5.2, a)
		cv.rect(int(hx) - 1, 0, 2, 5, a.lightened(0.3))
		if back:
			cv.rect(10, 8, 12, 1, a.darkened(0.3))
		elif side:
			cv.rect(18, 6, 6, 2, b)
			cv.rect(9, 6, 8, 2, a.darkened(0.2))
		else:
			cv.rect(7, 6, 3, 4, b)
			cv.rect(8, 7, 1, 2, Color.WHITE)
			cv.rect(10, 6, 12, 1, a.darkened(0.2))
	elif s == "scholar":
		cv.poly([Vector2(hx, 0), Vector2(hx + 12, 3), Vector2(hx, 6), Vector2(hx - 12, 3)], a)
		cv.rect(int(hx) - 6, 3, 12, 1, a.lightened(0.25))
		cv.px(int(hx), 3, b)
		var tx := int(hx) + 9
		cv.line(tx, 4, tx, 9, b)
		cv.px(tx, 10, b)
		cv.px(tx, 9, b.lightened(0.4))
	elif s == "oracle":
		if back:
			cv.rect(8, 8, 16, 1, a)
		elif side:
			cv.rrect(21, 7, 3, 7, 1.0, a)
			cv.poly([Vector2(19, 2), Vector2(21, 4), Vector2(19, 6), Vector2(17, 4)], b)
			cv.px(19, 3, Color.WHITE)
		else:
			cv.rrect(7, 7, 3, 7, 1.0, a)
			cv.rrect(22, 7, 3, 7, 1.0, a)
			cv.rect(10, 5, 12, 1, a)
			cv.poly([Vector2(16, 1), Vector2(18, 3.5), Vector2(16, 6), Vector2(14, 3.5)], b)
			cv.px(15, 2, Color.WHITE)
	elif s == "weld":
		if back:
			cv.rrect(9, 3, 14, 7, 3.0, a)
			cv.rect(9, 7, 14, 1, a.lightened(0.2))
		elif side:
			cv.rrect(13, 3, 11, 12, 3.0, a)
			cv.rect(18, 8, 6, 2, b)
			cv.rect(14, 4, 9, 1, a.lightened(0.25))
		else:
			cv.rrect(8, 3, 16, 12, 3.0, a)
			cv.rect(10, 8, 12, 2, b)
			cv.rect(9, 4, 14, 1, a.lightened(0.25))
			cv.px(10, 12, a.lightened(0.3))
			cv.px(21, 12, a.lightened(0.3))
	elif s == "pilot":
		cv.ell(hx, 5.0, 8.6, 5.0, a)
		cv.rect(int(hx) - 1, 0, 2, 4, a.darkened(0.15))
		if back:
			cv.rect(8, 6, 16, 1, b.darkened(0.3))
		elif side:
			cv.disc(19.5, 5.5, 2.3, a.darkened(0.4))
			cv.disc(19.5, 5.5, 1.5, b)
			cv.rect(10, 5, 8, 1, b.darkened(0.3))
		else:
			cv.disc(12, 5.5, 2.3, a.darkened(0.4))
			cv.disc(20, 5.5, 2.3, a.darkened(0.4))
			cv.disc(12, 5.5, 1.5, b)
			cv.disc(20, 5.5, 1.5, b)
			cv.rect(8, 5, 16, 1, b.darkened(0.3))
	elif s == "riot":
		cv.ell(hx, 4.6, 8.9, 4.6, a)
		if back:
			cv.rect(8, 8, 16, 1, a.lightened(0.2))
		elif side:
			cv.rrect(17, 3, 8, 12, 3.0, Color(b.r, b.g, b.b, 0.32))
			cv.rect(17, 3, 8, 1, b)
		else:
			cv.rrect(8, 3, 16, 13, 4.0, Color(b.r, b.g, b.b, 0.3))
			cv.rect(9, 3, 14, 1, b)
			cv.line(10, 5, 12, 12, Color(1, 1, 1, 0.5))
		cv.rect(int(hx) - 3, 1, 6, 1, a.lightened(0.3))
	elif s == "sentinel":
		cv.ell(hx, 5.0, 8.5, 5.0, a)
		if back:
			cv.rect(15, 0, 2, 9, b)
			cv.rect(8, 9, 3, 6, a.darkened(0.15))
			cv.rect(21, 9, 3, 6, a.darkened(0.15))
		elif side:
			cv.poly([Vector2(8, 5), Vector2(14, 0), Vector2(22, 1), Vector2(14, 5)], b)
			cv.rect(21, 9, 3, 6, a.darkened(0.15))
		else:
			cv.poly([Vector2(14, 0), Vector2(18, 0), Vector2(17, 6), Vector2(15, 6)], b)
			cv.rect(7, 9, 3, 6, a.darkened(0.15))
			cv.rect(22, 9, 3, 6, a.darkened(0.15))
	elif s == "crown":
		var cx := int(hx)
		cv.rect(cx - 7, 4, 14, 2, a)
		cv.rect(cx - 7, 4, 14, 1, b)
		for i in 4:
			var sx := cx - 7 + i * 4
			cv.poly([Vector2(sx, 4), Vector2(sx + 3, 4), Vector2(sx + 1.5, 0)], b)
		cv.px(cx - 1, 5, Color.WHITE)


func _armor_fb(cv: Cv, dir: int, art: Dictionary) -> void:
	var a := _ac(art, "a")
	var b := _ac(art, "b")
	var s := String(art["s"])
	var back := dir == 1
	cv.rrect(9, 13, 14, 10, 2.5, a)
	cv.rrect(5, 14, 5, 6, 2.0, a)
	cv.rrect(22, 14, 5, 6, 2.0, a)
	cv.rect(10, 14, 12, 1, a.lightened(0.25))
	cv.rect(9, 22, 14, 1, a.darkened(0.3))
	if s == "jacket":
		cv.rect(12, 13, 8, 2, a.lightened(0.3))
		cv.line(16, 15, 16, 22, b)
		if not back:
			cv.rect(10, 18, 3, 3, a.darkened(0.25))
			cv.rect(19, 18, 3, 3, a.darkened(0.25))
			cv.px(11, 18, b)
			cv.px(20, 18, b)
	elif s == "scrap":
		cv.rect(10, 14, 6, 5, b)
		cv.rect(17, 17, 5, 5, b.darkened(0.25))
		cv.px(11, 15, Color("40485e"))
		cv.px(14, 17, Color("40485e"))
		cv.px(19, 19, Color("40485e"))
		cv.rect(6, 15, 3, 3, b.darkened(0.1))
	elif s == "kevlar":
		cv.line(9, 14, 22, 22, b, 2.0)
		cv.line(22, 14, 9, 22, b, 2.0)
		cv.rect(12, 19, 8, 3, a.darkened(0.3))
		cv.rect(12, 19, 8, 1, b)
	elif s == "reactive":
		cv.poly([Vector2(5, 14), Vector2(9, 14), Vector2(5, 9)], b)
		cv.poly([Vector2(23, 14), Vector2(27, 14), Vector2(27, 9)], b)
		cv.rect(11, 17, 10, 1, b)
		cv.px(12, 19, b.lightened(0.4))
		cv.px(19, 19, b.lightened(0.4))
	elif s == "exo":
		cv.rect(15, 14, 2, 8, b)
		cv.line(10, 14, 10, 22, b)
		cv.line(21, 14, 21, 22, b)
		cv.disc(7.5, 16, 1.8, b)
		cv.disc(24.5, 16, 1.8, b)
		cv.px(15, 15, Color.WHITE)
	elif s == "bulwark":
		cv.ell(6.5, 15, 4.6, 3.6, b)
		cv.ell(25.5, 15, 4.6, 3.6, b)
		cv.poly([Vector2(11, 14), Vector2(21, 14), Vector2(20, 21), Vector2(16, 23), Vector2(12, 21)], b)
		cv.poly([Vector2(13, 15), Vector2(19, 15), Vector2(18.5, 20), Vector2(16, 21), Vector2(13.5, 20)], a)
		cv.rect(15, 16, 2, 4, Color.WHITE)
	elif s == "padded":
		for yy in range(15, 23, 3):
			cv.rect(10, yy, 12, 1, b)
		cv.line(16, 14, 16, 22, a.darkened(0.3))
	elif s == "riveted":
		cv.rect(10, 15, 12, 1, b.darkened(0.3))
		cv.rect(10, 19, 12, 1, b.darkened(0.3))
		for px_ in [Vector2i(11, 14), Vector2i(20, 14), Vector2i(11, 21), Vector2i(20, 21), Vector2i(6, 16), Vector2i(25, 16)]:
			cv.px(px_.x, px_.y, b)
	elif s == "ablative":
		cv.rect(8, 23, 16, 5, a)
		cv.rect(8, 27, 16, 1, b)
		cv.line(16, 23, 16, 27, a.darkened(0.3))
		cv.rect(9, 17, 14, 1, b)
	elif s == "titan":
		cv.rect(9, 13, 14, 1, b)
		cv.rect(9, 22, 14, 1, b)
		cv.ell(6.5, 15.5, 4.8, 3.8, a.lightened(0.1))
		cv.ell(25.5, 15.5, 4.8, 3.8, a.lightened(0.1))
		cv.rect(2, 15, 9, 1, b)
		cv.rect(21, 15, 9, 1, b)
		cv.disc(16, 18, 2.6, b)
		cv.disc(16, 18, 1.4, a)
	elif s == "weave":
		for i in range(-2, 4):
			cv.line(9 + i * 5, 13, 13 + i * 5, 22, b.darkened(0.2))
		cv.px(12, 16, Color.WHITE)
		cv.px(18, 19, Color.WHITE)
		cv.px(7, 17, b)
		cv.px(25, 17, b)
	elif s == "core":
		cv.disc(16, 17.5, 3.4, a.darkened(0.3))
		cv.disc(16, 17.5, 2.4, b)
		cv.px(15, 16, Color.WHITE)
		cv.poly([Vector2(5, 14), Vector2(9, 14), Vector2(6, 10)], b.darkened(0.2))
		cv.poly([Vector2(23, 14), Vector2(27, 14), Vector2(26, 10)], b.darkened(0.2))
		cv.rect(10, 14, 12, 1, b.darkened(0.2))
	if back and s != "ablative":
		cv.rect(10, 15, 12, 1, a.lightened(0.15))


func _armor_side(cv: Cv, art: Dictionary, ax: int) -> void:
	var a := _ac(art, "a")
	var b := _ac(art, "b")
	var s := String(art["s"])
	cv.rrect(10, 13, 12, 10, 2.5, a)
	cv.rect(11, 14, 10, 1, a.lightened(0.25))
	cv.rect(10, 22, 12, 1, a.darkened(0.3))
	if s == "ablative":
		cv.rect(9, 23, 14, 5, a)
		cv.rect(9, 27, 14, 1, b)
	elif s == "jacket":
		cv.line(21, 14, 21, 22, b)
		cv.rect(12, 18, 3, 3, a.darkened(0.25))
	elif s == "scrap":
		cv.rect(11, 14, 6, 5, b)
		cv.px(12, 15, Color("40485e"))
	elif s == "kevlar":
		cv.line(11, 14, 21, 22, b, 2.0)
		cv.rect(13, 19, 6, 3, a.darkened(0.3))
	elif s == "reactive":
		cv.rect(12, 17, 8, 1, b)
		cv.px(14, 19, b.lightened(0.4))
	elif s == "exo":
		cv.rect(15, 14, 2, 8, b)
		cv.line(11, 14, 11, 22, b)
	elif s == "bulwark" or s == "titan":
		cv.poly([Vector2(12, 14), Vector2(21, 14), Vector2(20, 21), Vector2(16, 23), Vector2(12, 21)], b)
		cv.rect(14, 16, 4, 4, a)
	elif s == "padded":
		for yy in range(15, 23, 3):
			cv.rect(11, yy, 10, 1, b)
	elif s == "riveted":
		cv.rect(11, 15, 10, 1, b.darkened(0.3))
		cv.px(12, 14, b)
		cv.px(20, 14, b)
		cv.px(12, 21, b)
		cv.px(20, 21, b)
	elif s == "weave":
		for i in range(-1, 3):
			cv.line(10 + i * 5, 13, 14 + i * 5, 22, b.darkened(0.2))
		cv.px(15, 17, Color.WHITE)
	elif s == "core":
		cv.disc(19, 17.5, 2.6, a.darkened(0.3))
		cv.disc(19, 17.5, 1.7, b)
		cv.px(18, 16, Color.WHITE)
	# sleeve + pauldron on the near arm
	cv.rrect(13 + ax, 14, 5, 6, 2.0, a)
	if s == "bulwark" or s == "titan":
		cv.ell(15.5 + ax, 14.5, 4.4, 3.4, b)
	elif s == "reactive" or s == "core":
		cv.poly([Vector2(13 + ax, 14), Vector2(18 + ax, 14), Vector2(15.5 + ax, 9)], b)
	elif s == "exo":
		cv.disc(15.5 + ax, 15, 1.8, b)


func _boot(cv: Cv, x: int, y: int, w: int, art: Dictionary, toe_right: bool) -> void:
	var a := _ac(art, "a")
	var b := _ac(art, "b")
	var s := String(art["s"])
	cv.rrect(x, y, w, 5, 1.5, a)
	cv.rect(x + 1, y - 2, w - 2, 3, a.lightened(0.12))
	cv.rect(x, y + 4, w, 1, b if s == "soles" or s == "grip" or s == "mag" else a.darkened(0.35))
	cv.rect(x + 1, y, w - 2, 1, a.lightened(0.3))
	var tx := x + w - 2 if toe_right else x + 1
	if s == "sneak":
		cv.rect(x + 1, y + 1, w - 2, 1, b)
		cv.px(x + w / 2, y - 1, b)
	elif s == "mag":
		cv.rect(x, y - 1, w, 1, b)
		cv.rect(x, y + 3, w, 2, a.darkened(0.4))
	elif s == "jet":
		cv.rect(x + 1, y - 2, 2, 2, b)
		cv.px(x + w / 2, y + 5, b)
		cv.px(x + w / 2 - 1, y + 5, b.lightened(0.4))
	elif s == "grip":
		for i in range(0, w, 2):
			cv.px(x + i, y + 4, b)
		cv.rect(x + 1, y - 1, w - 2, 1, b)
	elif s == "grav":
		cv.rect(x, y + 2, w, 1, b)
		cv.px(x + w / 2, y + 1, Color.WHITE)
	elif s == "phase":
		cv.rect(x, y + 4, w, 1, b)
		cv.px(x + 1, y + 1, b)
		cv.px(x + w - 2, y + 2, b)
	elif s == "soles":
		cv.rect(x + 1, y - 1, w - 2, 1, b.darkened(0.2))
	elif s == "spiked":
		cv.px(tx, y, b)
		cv.px(tx, y - 1, b)
		cv.px(x + w / 2, y - 1, b)
		cv.px(x + w / 2, y - 2, b)
	elif s == "runner":
		cv.rect(x, y + 2, w, 1, b)
		cv.rect(x + 1, y - 1, w - 2, 1, b)
	elif s == "hover":
		cv.rect(x, y + 4, w, 1, b)
		cv.px(x + 1, y + 3, b)
		cv.px(x + w - 2, y + 3, b)
	elif s == "warp":
		cv.poly([Vector2(x - 1, y - 1), Vector2(x + 1, y - 3), Vector2(x + 2, y)], b)
		cv.poly([Vector2(x + w + 1, y - 1), Vector2(x + w - 1, y - 3), Vector2(x + w - 2, y)], b)


func _trinket(cv: Cv, art: Dictionary, ox: int, oy: int, k: float) -> void:
	var a := _ac(art, "a")
	var b := _ac(art, "b")
	var s := String(art["s"])
	var f := func(x: float, y: float, w: float, h: float, c: Color) -> void:
		cv.rect(ox + int(x * k), oy + int(y * k), maxi(1, int(w * k)), maxi(1, int(h * k)), c)
	if s == "chip":
		f.call(0, 1, 6, 4, a)
		f.call(1, 2, 4, 2, a.darkened(0.3))
		f.call(0, 0, 1, 1, b)
		f.call(5, 5, 1, 1, b)
		f.call(2, 2, 1, 1, b)
	elif s == "cell":
		f.call(1, 1, 4, 5, a)
		f.call(2, 0, 2, 1, b)
		f.call(2, 2, 1, 2, b)
	elif s == "patch":
		f.call(0, 0, 6, 6, b)
		f.call(2, 1, 2, 4, a)
		f.call(1, 2, 4, 2, a)
	elif s == "amp":
		f.call(2, 3, 2, 3, a)
		f.call(3, 0, 1, 3, b)
		f.call(1, 1, 1, 1, b)
		f.call(5, 1, 1, 1, b)
	elif s == "ward":
		cv.disc(ox + 3 * k, oy + 3 * k, 3.0 * k, a)
		cv.disc(ox + 3 * k, oy + 3 * k, 1.6 * k, b)
	elif s == "reaper":
		cv.disc(ox + 3 * k, oy + 2.6 * k, 2.7 * k, a)
		f.call(2, 4, 2, 2, a)
		f.call(1, 2, 1, 1, b)
		f.call(4, 2, 1, 1, b)
	elif s == "lens":
		cv.disc(ox + 3 * k, oy + 3 * k, 3.0 * k, a)
		cv.disc(ox + 3 * k, oy + 3 * k, 1.7 * k, b.darkened(0.3))
		f.call(1, 1, 1, 1, b)
	elif s == "tooth":
		cv.poly([Vector2(ox, oy), Vector2(ox + 6 * k, oy), Vector2(ox + 5 * k, oy + 3 * k), Vector2(ox + 3 * k, oy + 6 * k), Vector2(ox + 1 * k, oy + 3 * k)], a)
		f.call(1, 1, 2, 1, b)
	elif s == "stim":
		cv.line(ox, oy + 5 * k, ox + 4 * k, oy + 1 * k, a, maxf(1.0, 2.0 * k))
		f.call(4, 0, 2, 1, b)
		f.call(0, 5, 1, 1, b)
	elif s == "emit":
		cv.disc(ox + 3 * k, oy + 3 * k, 2.4 * k, a)
		f.call(0, 3, 1, 1, b)
		f.call(5, 3, 1, 1, b)
		f.call(3, 0, 1, 1, b)
		f.call(3, 5, 1, 1, b)
		f.call(2, 2, 1, 1, Color.WHITE)
	elif s == "bcore":
		cv.poly([Vector2(ox + 3 * k, oy), Vector2(ox + 6 * k, oy + 3 * k), Vector2(ox + 3 * k, oy + 6 * k), Vector2(ox, oy + 3 * k)], a)
		f.call(2, 2, 2, 2, b)
	elif s == "fusion":
		f.call(1, 1, 4, 4, a)
		f.call(2, 2, 2, 2, b)
		f.call(0, 0, 1, 1, b)
		f.call(5, 5, 1, 1, b)
		f.call(0, 5, 1, 1, b)
		f.call(5, 0, 1, 1, b)
	elif s == "heart":
		cv.disc(ox + 1.8 * k, oy + 2 * k, 1.9 * k, a)
		cv.disc(ox + 4.2 * k, oy + 2 * k, 1.9 * k, a)
		cv.poly([Vector2(ox, oy + 2.5 * k), Vector2(ox + 6 * k, oy + 2.5 * k), Vector2(ox + 3 * k, oy + 6 * k)], a)
		f.call(1, 1, 1, 1, b)
	elif s == "overlord":
		f.call(0, 3, 6, 3, a)
		f.call(0, 0, 1, 3, b)
		f.call(2, 1, 2, 2, b)
		f.call(5, 0, 1, 3, b)
		f.call(2, 4, 2, 1, Color.WHITE)


func _art(eq: Dictionary, slot: String) -> Dictionary:
	var id := String(eq.get(slot, ""))
	if id != "" and ART.has(id):
		return ART[id]
	return {}


func _eq_key(eq: Dictionary) -> String:
	var parts: Array[String] = []
	for sl in SLOT_ORDER:
		parts.append(String(eq.get(sl, "")))
	return "|".join(parts)


func player(accent: Color, cls: String, frame: int = 0, dir: int = 0, eq: Dictionary = {}) -> ImageTexture:
	var key := "pl_%s_%d_%d_%s" % [cls, frame, dir, _eq_key(eq)]
	if cache.has(key):
		return cache[key]
	var t: ImageTexture
	if dir == 2:
		var img: Image = player(accent, cls, frame, 3, eq).get_image()
		img.flip_x()
		t = ImageTexture.create_from_image(img)
	else:
		var ai: ImageTexture = _player_ai(accent, cls, frame, dir, eq)
		t = ai if ai != null else _build_player(accent, cls, frame, dir, eq).tex()
	cache[key] = t
	return t


# ---- AI base body (art/player_base64.png: cols front, back, side) + procedural gear overlays
const PBASE := "res://art/player_base64.png"
const PCOL := {0: 0, 1: 1, 3: 2}
# Fit of the 32px gear art (already 2x'd to 64px) onto the chibi body: [pivot_x, pivot_y, scale_x, scale_y, shift_x, shift_y]
const GFIT := {
	"helmet": {0: [32, 17, 1.15, 1.0, 0, 8], 1: [32, 17, 1.15, 1.0, 0, 8], 3: [33, 17, 1.15, 1.0, -1, 8]},
	"armour": {0: [32, 36, 0.85, 0.7, 0, 12], 1: [32, 36, 0.85, 0.7, 0, 12], 3: [32, 36, 0.85, 0.7, 0, 12]},
	"boots": {0: [32, 57, 0.95, 0.7, 0, 1], 1: [32, 57, 0.95, 0.7, 0, 1], 3: [32, 57, 0.95, 0.7, 0, 1]},
	"trinket": {0: [20, 44, 1.0, 1.0, 0, 3], 1: [40, 44, 1.0, 1.0, 0, 3], 3: [22, 44, 1.0, 1.0, 0, 3]},
}
# weapon grip (32px space), direction and scale per facing
const WGRIP := {0: [Vector2(9.0, 23.0), Vector2(-0.22, -0.97), 1.35], 1: [Vector2(23.0, 23.0), Vector2(0.22, -0.97), 1.35], 3: [Vector2(19.0, 23.0), Vector2(0.8, -0.6), 1.35]}


func _player_ai(accent: Color, cls: String, frame: int, dir: int, eq: Dictionary) -> ImageTexture:
	if not PCOL.has(dir):
		return null
	var bt: ImageTexture = _atlas_cell(PBASE, PCOL[dir], 0, 64)
	if bt == null or bt.get_image().is_invisible():
		return null
	var base: Image = bt.get_image()
	if dir != 1:
		_tint_visor(base, accent)
	var front := _class_deco(accent, cls, dir, false)
	if front != null:
		base.blend_rect(front, Rect2i(0, 0, 64, 64), Vector2i.ZERO)
	for slot in ["armour", "boots", "trinket", "helmet"]:
		var art := _art(eq, slot)
		if art.is_empty():
			continue
		var cv := Cv.new(32, 32)
		_draw_gear(cv, slot, art, dir)
		cv.outline(Color("0a0d1a"))
		var g: Image = cv.img.duplicate()
		g.resize(64, 64, Image.INTERPOLATE_NEAREST)
		_blit_fit(base, g, GFIT[slot][dir])
	base = _walk_frame(base, frame, dir)
	var behind := _class_deco(accent, cls, dir, true)
	if behind != null:
		behind.blend_rect(base, Rect2i(0, 0, 64, 64), Vector2i.ZERO)
		base = behind
	var wa := _art(eq, "weapon")
	if not wa.is_empty():
		var wc := Cv.new(32, 32)
		var wg: Array = WGRIP[dir]
		_weapon(wc, wa, wg[0], wg[1], wg[2])
		wc.outline(Color("0a0d1a"))
		var wi: Image = wc.img.duplicate()
		wi.resize(64, 64, Image.INTERPOLATE_NEAREST)
		base.blend_rect(wi, Rect2i(0, 0, 64, 64), Vector2i.ZERO)
	return ImageTexture.create_from_image(base)


# class decorations drawn in 64px space; behind=true is the layer under the body (mystic cloak)
func _class_deco(accent: Color, cls: String, dir: int, behind: bool) -> Image:
	var cv := Cv.new(64, 64)
	var ol := Color("0a0d1a")
	var used := false
	var side := dir == 3
	var cloak := accent.darkened(0.45)
	var brown := Color("6b4423")
	var gold := Color("ffd84f")
	if cls == "mystic":
		if behind and not (dir == 1):
			used = true
			if side:
				cv.poly([Vector2(24, 36), Vector2(34, 36), Vector2(26, 61), Vector2(6, 61)], cloak)
			else:
				cv.poly([Vector2(14, 36), Vector2(50, 36), Vector2(60, 61), Vector2(4, 61)], cloak)
		elif not behind and dir == 1:
			used = true
			cv.poly([Vector2(13, 35), Vector2(51, 35), Vector2(60, 61), Vector2(4, 61)], cloak)
			cv.line(32, 37, 32, 60, accent.darkened(0.6), 1.0)
			cv.line(22, 37, 17, 60, accent.darkened(0.55), 1.0)
			cv.line(42, 37, 47, 60, accent.darkened(0.55), 1.0)
		if not behind:
			used = true
			var gx := 30 if side else 32
			cv.poly([Vector2(gx, 0), Vector2(gx + 4, 4), Vector2(gx, 8), Vector2(gx - 4, 4)], accent.lightened(0.45))
			cv.px(gx - 1, 3, Color.WHITE)
	elif not behind:
		if cls == "scout":
			used = true
			if side:
				cv.line(24, 8, 19, 1, ol, 2.0)
				cv.disc(19, 2, 2.6, accent.lightened(0.5))
			else:
				cv.line(44, 8, 50, 1, ol, 2.0)
				cv.disc(50, 2, 2.6, accent.lightened(0.5))
				if dir == 0:
					cv.rect(7, 19, 4, 9, accent.darkened(0.2))
		elif cls == "brute":
			used = true
			if side:
				cv.ell(27, 38, 5.0, 4.0, accent)
				cv.px(25, 36, accent.lightened(0.5))
			else:
				cv.ell(12, 38, 5.5, 4.2, accent)
				cv.ell(52, 38, 5.5, 4.2, accent)
				cv.px(10, 36, accent.lightened(0.5))
				cv.px(50, 36, accent.lightened(0.5))
		elif cls == "gunslinger":
			used = true
			var hx0 := 16 if side else 12
			var hx1 := 56 if side else 52
			cv.rect(hx0, 9, hx1 - hx0, 4, brown)
			cv.rect(hx0, 9, hx1 - hx0, 1, Color("a67238"))
			cv.rrect(22, 0, 20, 11, 3.0, Color("7a4e2a"))
			cv.rect(22, 7, 20, 2, accent)
			if side:
				cv.line(26, 38, 40, 52, Color("8a5a2a"), 3.0)
			else:
				cv.line(14, 38, 46, 54, Color("8a5a2a"), 3.0)
				cv.px(22, 44, accent.lightened(0.4))
				cv.px(32, 48, accent.lightened(0.4))
				cv.px(41, 52, accent.lightened(0.4))
		elif cls == "gambler":
			used = true
			cv.rect(15, 10, 35, 4, gold)
			cv.rect(15, 10, 35, 1, Color("fff1a0"))
			if dir == 0:
				cv.rect(27, 40, 9, 9, Color.WHITE)
				cv.rect(29, 42, 2, 2, Color("14141c"))
				cv.rect(33, 46, 2, 2, Color("14141c"))
				cv.rect(33, 42, 2, 2, Color("14141c"))
				cv.rect(29, 46, 2, 2, Color("14141c"))
	if not used:
		return null
	cv.outline(ol)
	return cv.img.duplicate()


func _draw_gear(cv: Cv, slot: String, art: Dictionary, dir: int) -> void:
	if slot == "armour":
		if dir == 3:
			_armor_side(cv, art, 0)
		else:
			_armor_fb(cv, dir, art)
	elif slot == "boots":
		if dir == 3:
			_boot(cv, 12, 26, 8, art, true)
			_boot(cv, 15, 26, 8, art, true)
		else:
			_boot(cv, 9, 26, 7, art, false)
			_boot(cv, 16, 26, 7, art, false)
	elif slot == "trinket":
		_trinket(cv, art, (10 if dir == 0 else (20 if dir == 1 else 11)), 22, 0.9)
	elif slot == "helmet":
		_helm(cv, dir, art)


func _blit_fit(dst: Image, src: Image, f: Array) -> void:
	var px: float = f[0]
	var py: float = f[1]
	var sx: float = f[2]
	var sy: float = f[3]
	for y in 64:
		for x in 64:
			var u := int(floor((x - f[4] - px) / sx + px))
			var v := int(floor((y - f[5] - py) / sy + py))
			if u < 0 or v < 0 or u >= 64 or v >= 64:
				continue
			var c := src.get_pixel(u, v)
			if c.a >= 0.5:
				dst.set_pixel(x, y, c)


# recolour the cyan visor of the base body to the class accent colour, keeping its shading
func _tint_visor(im: Image, accent: Color) -> void:
	var sat := maxf(accent.s, 0.45)
	for y in 64:
		for x in 64:
			var c := im.get_pixel(x, y)
			if c.a < 0.5:
				continue
			if c.h > 0.45 and c.h < 0.62 and c.s > 0.22 and c.v > 0.3:
				im.set_pixel(x, y, Color.from_hsv(accent.h, minf(1.0, c.s * sat / 0.55), c.v))


# walk cycle (legs are rows 53-61): front/back lift one leg 3px and sway the upper body 1px over the planted leg;
# side view strides (one leg back and up, the other forward)
func _walk_frame(im: Image, frame: int, dir: int = 0) -> Image:
	if frame == 0:
		return im
	var out := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var left := frame == 1
	var sway := 0 if dir == 3 else (1 if left else -1)
	for y in 64:
		for x in 64:
			var c := im.get_pixel(x, y)
			if c.a < 0.5:
				continue
			if y < 53:
				var nx := x + sway
				if nx >= 0 and nx < 64:
					out.set_pixel(nx, y, c)
				continue
			var in_left := x < 32
			var lift := in_left == left
			var ny := y
			var nx2 := x
			if dir == 3:
				nx2 = x + (-2 if lift else 2)
				ny = y - (2 if lift else 0)
			elif lift:
				ny = y - 3
			if nx2 >= 0 and nx2 < 64 and ny >= 0:
				out.set_pixel(nx2, ny, c)
	return out


func _build_player(accent: Color, cls: String, frame: int, dir: int, eq: Dictionary) -> Cv:
	var cv := Cv.new(32, 32)
	var suit := Color("e6ebf8")
	var suit_d := Color("a9b3d1")
	var dark := Color("2b3254")
	var metal := Color("69759a")
	var wa := _art(eq, "weapon")
	var ha := _art(eq, "helmet")
	var aa := _art(eq, "armour")
	var ba := _art(eq, "boots")
	var ta := _art(eq, "trinket")
	var dl := -3 if frame == 1 else 0
	var dr := -3 if frame == 2 else 0
	if dir == 3:
		# ---- side view, facing right
		var nx := 15
		var ndy := 0
		var fx := 12
		var fdy := 0
		var ax := 0
		if frame == 1:
			nx = 17
			ndy = -3
			fx = 10
			ax = -3
		elif frame == 2:
			nx = 11
			fx = 17
			fdy = -3
			ax = 3
		if cls == "mystic":
			cv.poly([Vector2(11, 13), Vector2(14, 13), Vector2(12, 29), Vector2(2, 29)], accent.darkened(0.45))
		cv.rrect(6, 13, 6, 10, 2.0, metal)
		cv.rrect(7, 14, 2, 8, 1.0, metal.lightened(0.25))
		cv.rrect(fx, 21 + fdy, 5, 8, 1.5, suit_d)
		cv.rrect(nx, 21 + ndy, 5, 8, 1.5, suit)
		cv.rrect(fx, 26 + fdy, 8, 5, 1.5, dark)
		cv.rrect(nx, 26 + ndy, 8, 5, 1.5, dark)
		cv.rrect(10, 13, 12, 10, 2.5, suit)
		cv.rrect(12 - ax, 15, 4, 8, 1.5, suit_d)
		cv.ell(16.5, 8.5, 7.0, 7.5, suit)
		cv.shade(0.22)
		cv.ell(20.2, 9, 4.3, 4.3, dark)
		cv.ell(20.5, 9, 3.6, 3.6, accent.darkened(0.5))
		cv.ell(20.7, 8.7, 3.3, 2.7, accent)
		cv.ell(20, 7.6, 1.8, 0.9, accent.lightened(0.6))
		cv.rect(10, 22, 12, 2, accent.darkened(0.25))
		cv.rect(15, 22, 2, 2, Color("ffd84f"))
		cv.rect(nx + 1, 28 + ndy, 6, 1, metal)
		cv.rect(fx + 1, 28 + fdy, 6, 1, metal)
		cv.rect(11, 17, 1, 3, suit_d)
		cv.rrect(13 + ax, 14, 5, 9, 2.0, suit)
		cv.rrect(13 + ax, 21, 5, 4, 1.5, dark)
		if cls == "scout":
			cv.line(11, 4, 9, 0, dark)
			cv.disc(9, 1, 1.4, accent.lightened(0.5))
			cv.rect(10, 6, 2, 4, accent.darkened(0.2))
		elif cls == "brute":
			cv.ell(15.5 + ax, 14.5, 3.8, 3.0, accent)
			cv.px(14 + ax, 13, accent.lightened(0.5))
			cv.rect(11, 12, 8, 2, accent.darkened(0.1))
		elif cls == "mystic":
			cv.poly([Vector2(16, 0), Vector2(18, 2), Vector2(16, 4), Vector2(14, 2)], accent.lightened(0.45))
			cv.px(15, 1, Color.WHITE)
		elif cls == "gunslinger":
			cv.rect(6, 4, 20, 2, Color("6b4423"))
			cv.rect(6, 4, 20, 1, Color("a67238"))
			cv.rrect(10, 0, 12, 5, 1.5, Color("7a4e2a"))
			cv.rect(10, 3, 12, 1, accent)
			cv.line(11, 14, 19, 22, Color("8a5a2a"), 2.0)
			cv.px(13, 16, accent.lightened(0.4))
			cv.px(16, 19, accent.lightened(0.4))
			cv.rect(9, 6, 5, 1, Color("6b4423"))
		elif cls == "gambler":
			cv.rect(9, 5, 14, 2, Color("ffd84f"))
			cv.rect(9, 5, 14, 1, Color("fff1a0"))
		if not aa.is_empty():
			_armor_side(cv, aa, ax)
		if not ba.is_empty():
			_boot(cv, fx, 26 + fdy, 8, ba, true)
			_boot(cv, nx, 26 + ndy, 8, ba, true)
		if not ta.is_empty():
			_trinket(cv, ta, 11, 22, 0.9)
		if not ha.is_empty():
			_helm(cv, 3, ha)
		if not wa.is_empty():
			_weapon(cv, wa, Vector2(16.0 + ax * 0.6, 22.0), Vector2(0.8, -0.6), 0.8)
	elif dir == 1:
		# ---- back view
		cv.rrect(7, 12, 18, 11, 2.0, metal)
		cv.rrect(4, 14, 4, 8, 1.5, dark)
		cv.rrect(24, 14, 4, 8, 1.5, dark)
		cv.rrect(10, 21 + dl, 5, 8, 1.5, suit_d)
		cv.rrect(17, 21 + dr, 5, 8, 1.5, suit_d)
		cv.rrect(9, 26 + dl, 7, 5, 1.5, dark)
		cv.rrect(16, 26 + dr, 7, 5, 1.5, dark)
		cv.rrect(9, 13, 14, 10, 2.5, suit)
		cv.rrect(5, 14, 5, 9, 2.0, suit)
		cv.rrect(22, 14, 5, 9, 2.0, suit)
		cv.rrect(5, 21, 5, 4, 1.5, dark)
		cv.rrect(22, 21, 5, 4, 1.5, dark)
		cv.ell(16, 8.5, 8.0, 7.5, suit)
		cv.shade(0.22)
		cv.rect(10, 7, 12, 1, suit_d)
		cv.rect(14, 3, 4, 1, accent)
		cv.rect(13, 11, 6, 2, suit_d)
		cv.rect(9, 22, 14, 2, accent.darkened(0.25))
		cv.rect(11, 24 + dl, 4, 1, accent.darkened(0.2))
		cv.rect(17, 24 + dr, 4, 1, accent.darkened(0.2))
		cv.rect(10, 28 + dl, 5, 1, metal)
		cv.rect(17, 28 + dr, 5, 1, metal)
		if frame == 1:
			cv.rect(23, 20, 4, 2, dark)
		elif frame == 2:
			cv.rect(5, 20, 4, 2, dark)
		if cls == "mystic":
			cv.poly([Vector2(9, 13), Vector2(23, 13), Vector2(28, 29), Vector2(4, 29)], accent.darkened(0.45))
			cv.line(16, 14, 16, 28, accent.darkened(0.6))
			cv.line(11, 14, 9, 28, accent.darkened(0.55))
			cv.line(21, 14, 23, 28, accent.darkened(0.55))
			cv.poly([Vector2(16, 0), Vector2(18, 2), Vector2(16, 4), Vector2(14, 2)], accent.lightened(0.45))
		if not aa.is_empty():
			_armor_fb(cv, 1, aa)
		if cls != "mystic":
			cv.rrect(10, 14, 12, 9, 2.0, metal)
			cv.rrect(11, 15, 4, 7, 1.5, metal.lightened(0.3))
			cv.rrect(17, 15, 4, 7, 1.5, metal.lightened(0.3))
			cv.rect(11, 17, 4, 1, accent)
			cv.rect(17, 17, 4, 1, accent)
		if cls == "scout":
			cv.line(23, 4, 25, 0, dark)
			cv.disc(25, 1, 1.4, accent.lightened(0.5))
		elif cls == "brute":
			cv.ell(6.5, 14, 3.6, 2.8, accent)
			cv.ell(25.5, 14, 3.6, 2.8, accent)
			cv.rect(13, 12, 6, 2, accent.darkened(0.1))
		elif cls == "gunslinger":
			cv.rect(6, 4, 20, 2, Color("6b4423"))
			cv.rect(6, 4, 20, 1, Color("a67238"))
			cv.rrect(10, 0, 12, 5, 1.5, Color("7a4e2a"))
			cv.rect(10, 3, 12, 1, accent)
			cv.line(10, 14, 22, 22, Color("8a5a2a"), 2.0)
			cv.px(13, 16, accent.lightened(0.4))
			cv.px(19, 20, accent.lightened(0.4))
		elif cls == "gambler":
			cv.rect(9, 5, 14, 2, Color("ffd84f"))
			cv.rect(9, 5, 14, 1, Color("fff1a0"))
		if not ba.is_empty():
			_boot(cv, 9, 26 + dl, 7, ba, false)
			_boot(cv, 16, 26 + dr, 7, ba, false)
		if not ta.is_empty():
			_trinket(cv, ta, 20, 22, 0.9)
		if not ha.is_empty():
			_helm(cv, 1, ha)
		if not wa.is_empty():
			_weapon(cv, wa, Vector2(25.5, 22.0), Vector2(0.22, -0.97), 0.8)
	else:
		# ---- front view
		if cls == "mystic":
			cv.poly([Vector2(9, 13), Vector2(23, 13), Vector2(28, 29), Vector2(4, 29)], accent.darkened(0.45))
		cv.rrect(7, 12, 18, 11, 2.0, metal)
		cv.rrect(4, 14, 4, 8, 1.5, dark)
		cv.rrect(24, 14, 4, 8, 1.5, dark)
		cv.rrect(10, 21 + dl, 5, 8, 1.5, suit_d)
		cv.rrect(17, 21 + dr, 5, 8, 1.5, suit_d)
		cv.rrect(9, 26 + dl, 7, 5, 1.5, dark)
		cv.rrect(16, 26 + dr, 7, 5, 1.5, dark)
		cv.rrect(9, 13, 14, 10, 2.5, suit)
		cv.rrect(5, 14, 5, 9, 2.0, suit)
		cv.rrect(22, 14, 5, 9, 2.0, suit)
		cv.rrect(5, 21, 5, 4, 1.5, dark)
		cv.rrect(22, 21, 5, 4, 1.5, dark)
		cv.ell(16, 8.5, 8.0, 7.5, suit)
		cv.shade(0.22)
		cv.ell(16, 9, 5.8, 4.6, dark)
		cv.ell(16, 9, 5.0, 3.8, accent.darkened(0.5))
		cv.ell(16, 8.6, 5.0, 3.0, accent)
		cv.ell(14.5, 7.4, 2.6, 1.0, accent.lightened(0.6))
		cv.px(19, 10, accent.lightened(0.7))
		cv.rect(12, 15, 8, 5, dark)
		cv.px(13, 16, Color("ff5d5d"))
		cv.px(15, 16, Color("ffd84f"))
		cv.px(17, 16, Color("6dff9a"))
		cv.rect(13, 18, 6, 1, accent)
		cv.rect(9, 22, 14, 2, accent.darkened(0.25))
		cv.rect(15, 22, 2, 2, Color("ffd84f"))
		cv.line(16, 20, 16, 21, suit_d)
		cv.line(10, 14, 21, 14, suit_d)
		cv.rect(10, 17, 1, 4, suit_d)
		cv.rect(21, 17, 1, 4, suit_d)
		cv.rect(11, 24 + dl, 4, 1, accent.darkened(0.2))
		cv.rect(17, 24 + dr, 4, 1, accent.darkened(0.2))
		cv.rect(10, 28 + dl, 5, 1, metal)
		cv.rect(17, 28 + dr, 5, 1, metal)
		if frame == 1:
			cv.rect(23, 20, 4, 2, dark)
		elif frame == 2:
			cv.rect(5, 20, 4, 2, dark)
		if cls == "scout":
			cv.line(23, 4, 25, 0, dark)
			cv.disc(25, 1, 1.4, accent.lightened(0.5))
			cv.rect(8, 7, 2, 4, accent.darkened(0.2))
		elif cls == "brute":
			cv.ell(6.5, 14, 3.6, 2.8, accent)
			cv.ell(25.5, 14, 3.6, 2.8, accent)
			cv.px(5, 13, accent.lightened(0.5))
			cv.rect(13, 12, 6, 2, accent.darkened(0.1))
			cv.line(7, 11, 9, 12, accent.lightened(0.3))
		elif cls == "mystic":
			cv.poly([Vector2(16, 0), Vector2(18, 2), Vector2(16, 4), Vector2(14, 2)], accent.lightened(0.45))
			cv.px(15, 1, Color.WHITE)
		elif cls == "gunslinger":
			cv.rect(6, 4, 20, 2, Color("6b4423"))
			cv.rect(6, 4, 20, 1, Color("a67238"))
			cv.rrect(10, 0, 12, 5, 1.5, Color("7a4e2a"))
			cv.rect(10, 3, 12, 1, accent)
			cv.line(10, 14, 22, 22, Color("8a5a2a"), 2.0)
			cv.px(13, 16, accent.lightened(0.4))
			cv.px(16, 19, accent.lightened(0.4))
			cv.px(19, 21, accent.lightened(0.4))
			cv.rect(12, 9, 8, 2, accent.darkened(0.2))
		elif cls == "gambler":
			cv.rect(9, 5, 14, 2, Color("ffd84f"))
			cv.rect(9, 5, 14, 1, Color("fff1a0"))
			cv.rect(14, 15, 5, 5, Color.WHITE)
			cv.px(15, 16, Color("14141c"))
			cv.px(17, 18, Color("14141c"))
			cv.px(17, 16, Color("14141c"))
			cv.px(15, 18, Color("14141c"))
		if not aa.is_empty():
			_armor_fb(cv, 0, aa)
		if not ba.is_empty():
			_boot(cv, 9, 26 + dl, 7, ba, false)
			_boot(cv, 16, 26 + dr, 7, ba, false)
		if not ta.is_empty():
			_trinket(cv, ta, 10, 22, 0.9)
		if not ha.is_empty():
			_helm(cv, 0, ha)
		if not wa.is_empty():
			_weapon(cv, wa, Vector2(6.5, 22.0), Vector2(-0.22, -0.97), 0.8)
	cv.outline(Color("0a0d1a"))
	return cv


func gear_icon(id: String, slot: String) -> ImageTexture:
	var key := "gearicon_" + id
	if cache.has(key):
		return cache[key]
	var cv := Cv.new(32, 32)
	var ol := Color("0e1322")
	if not ART.has(id):
		cv.disc(16, 16, 9, Color("c9d3f0"))
		cv.outline(ol)
		var tf := cv.tex()
		cache[key] = tf
		return tf
	var art: Dictionary = ART[id]
	if slot == "weapon":
		_weapon(cv, art, Vector2(5.5, 27.0), Vector2(0.62, -0.78).normalized(), 1.55)
		cv.shade(0.16)
		cv.outline(ol)
	elif slot == "trinket":
		_trinket(cv, art, 7, 7, 3.0)
		cv.shade(0.2)
		cv.outline(ol)
	else:
		var eq := {slot: id}
		var full := _build_player(Color("4fd1ff"), "", 0, 0, eq)
		var rect := Rect2i(8, 0, 16, 16)
		if slot == "armour":
			rect = Rect2i(8, 10, 16, 16)
		elif slot == "boots":
			rect = Rect2i(8, 16, 16, 16)
		var sub: Image = full.img.get_region(rect)
		sub.resize(32, 32, Image.INTERPOLATE_NEAREST)
		cv.img = sub
	cv.img.fix_alpha_edges()
	var t := cv.tex()
	cache[key] = t
	return t


# ---------------------------------------------------------------- corpses

func _pool(im: Image, cx: int, cy: int, rx: float, ry: float, col: Color) -> void:
	for y in range(maxi(0, int(cy - ry) - 1), mini(im.get_height(), int(cy + ry) + 2)):
		for x in range(maxi(0, int(cx - rx) - 1), mini(im.get_width(), int(cx + rx) + 2)):
			var dx := (x - cx) / rx
			var dy := (y - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				im.set_pixel(x, y, col)


func corpse(ti: int, lvl: int, boss: bool, tv: int, td: int, fl: int) -> ImageTexture:
	var key := "corpse_%d_%d_%d_%d_%d_%d" % [ti, lvl, 1 if boss else 0, tv, td, fl]
	if cache.has(key):
		return cache[key]
	var pcols: Array = [Color("7a1f2e"), Color("3f7a2a"), Color("5a2a8a"), Color("3a5aa0")]
	var pc: Color = pcols[ti % 4]
	var out := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var src: Image
	if tv >= 0:
		src = turret(ti, tv, td).get_image().duplicate()
	else:
		src = monster(ti, lvl, boss, true).get_image().duplicate()
	src.convert(Image.FORMAT_RGBA8)
	src.resize(32, 32, Image.INTERPOLATE_NEAREST)  # textures are 64px now; the corpse is composed on a 32 canvas, then upscaled
	var dim := 0.78 if tv < 0 else 0.5
	for y in src.get_height():
		for x in src.get_width():
			var c := src.get_pixel(x, y)
			if c.a > 0.05:
				var l := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
				src.set_pixel(x, y, Color(lerpf(c.r, l, 0.5) * dim * 1.1, lerpf(c.g, l, 0.5) * dim * 1.1, lerpf(c.b, l, 0.5) * dim * 1.1, c.a))
	if tv >= 0:
		_pool(out, 16, 26, 13.0, 4.5, Color(0.05, 0.05, 0.07, 0.8))
		_pool(out, 16, 26, 9.0, 3.0, Color(0.12, 0.1, 0.1, 0.9))
		src.resize(32, 22, Image.INTERPOLATE_NEAREST)
		out.blend_rect(src, Rect2i(0, 0, 32, 22), Vector2i(0, 7))
		for i in 5:
			var sx := 6 + i * 5
			out.set_pixel(sx, 22 - (i % 3) * 3 - 2, Color(0.55, 0.55, 0.6, 0.6))
		for e in [Vector2i(9, 25), Vector2i(21, 24), Vector2i(15, 27), Vector2i(25, 27)]:
			out.set_pixel(e.x, e.y, Color("ff9a3c"))
	else:
		_pool(out, 16, 25, 14.0, 5.5, pc.darkened(0.25))
		_pool(out, 16, 25, 12.0, 4.4, pc)
		_pool(out, 12, 24, 4.0, 1.6, pc.lightened(0.25))
		if fl == 1:
			src.rotate_90(COUNTERCLOCKWISE)
		else:
			src.rotate_90(CLOCKWISE)
		src.resize(32, 20, Image.INTERPOLATE_NEAREST)
		out.blend_rect(src, Rect2i(0, 0, 32, 20), Vector2i(0, 9))
		for sp in [Vector2i(3, 28), Vector2i(28, 22), Vector2i(26, 29)]:
			out.set_pixel(sp.x, sp.y, pc.darkened(0.1))
	out.resize(TEX_PX, TEX_PX, Image.INTERPOLATE_NEAREST)
	var t := ImageTexture.create_from_image(out)
	cache[key] = t
	return t


# ---------------------------------------------------------------- turrets

# dir: 0 faces down (towards the viewer), 1 up, 2 left, 3 right
func _tbarrel(cv: Cv, dir: int, hx: int, hy: int, th: int, blen: int, col: Color, glow: Color, twin: bool) -> void:
	var offs: Array[int] = []
	if twin:
		offs.append(-2)
		offs.append(2)
	else:
		offs.append(0)
	var bt := 2 if twin else th
	for o in offs:
		if dir == 3:
			cv.rect(hx + 3, hy + o - bt / 2, blen, bt, col)
			cv.rect(hx + 3, hy + o - bt / 2, blen, 1, col.lightened(0.3))
			cv.rect(hx + 3 + blen - 2, hy + o - bt / 2, 2, bt, col.darkened(0.3))
			cv.px(hx + 3 + blen, hy + o, glow)
		elif dir == 2:
			cv.rect(hx - 3 - blen, hy + o - bt / 2, blen, bt, col)
			cv.rect(hx - 3 - blen, hy + o - bt / 2, blen, 1, col.lightened(0.3))
			cv.rect(hx - 3 - blen, hy + o - bt / 2, 2, bt, col.darkened(0.3))
			cv.px(hx - 4 - blen, hy + o, glow)
		elif dir == 1:
			cv.rect(hx + o - bt / 2, hy - 3 - blen, bt, blen, col)
			cv.rect(hx + o - bt / 2, hy - 3 - blen, 1, blen, col.lightened(0.3))
			cv.rect(hx + o - bt / 2, hy - 3 - blen, bt, 2, col.darkened(0.3))
			cv.px(hx + o, hy - 4 - blen, glow)
		else:
			cv.rect(hx + o - bt / 2, hy + 2, bt, 5, col.darkened(0.15))
			cv.disc(hx + o, hy + 3, float(bt) * 0.75, Color("0a0d1a"))
			cv.disc(hx + o, hy + 3, float(bt) * 0.4, glow)


func turret(ti: int, v: int, dir: int) -> ImageTexture:
	var key := "tur_%d_%d_%d" % [ti, v, dir]
	if cache.has(key):
		return cache[key]
	var cv := Cv.new(32, 32)
	var hx := 16
	var hy := 13
	var base := Color("39415f")
	var head := Color("9aa3c7")
	var trim := Color("4a5270")
	var glow := Color("7fe8ff")
	var barrel := Color("6b7388")
	var bth := 3
	var blen := 10
	var twin := false
	if ti == 0 and v == 0:
		pass
	elif ti == 0:
		base = Color("2a3050")
		head = Color("4a5a8a")
		trim = Color("ff9a3c")
		glow = Color("ff7a45")
		barrel = Color("3a4160")
		bth = 6
		blen = 8
	elif ti == 1 and v == 0:
		base = Color("6a4a2a")
		head = Color("3fa84a")
		trim = Color("8fe89a")
		glow = Color("e8ffd0")
		barrel = Color("c9e8a0")
	elif ti == 1:
		base = Color("6a4a2a")
		head = Color("8a4fc0")
		trim = Color("ff8ad0")
		glow = Color("9dff4f")
		barrel = Color("5a2f8a")
		bth = 6
		blen = 8
	elif ti == 3 and v == 0:
		base = Color("3a2a6a")
		head = Color("b58cff")
		trim = Color("e8d0ff")
		glow = Color("ff8ad0")
		barrel = Color("7fe8ff")
		bth = 2
		blen = 11
	elif ti == 3:
		base = Color("3a2a6a")
		head = Color("6a4fc0")
		trim = Color("ffd0ff")
		glow = Color("7fe8ff")
		barrel = Color("a070ff")
		bth = 6
		blen = 8
	elif v == 0:
		base = Color("7a4a1e")
		head = Color("40485e")
		trim = Color("c9a55a")
		glow = Color("ffd84f")
		barrel = Color("2a2f40")
		blen = 11
		twin = true
	else:
		base = Color("7a4a1e")
		head = Color("5a6280")
		trim = Color("ff5d5d")
		glow = Color("ff7a45")
		barrel = Color("3a4160")
		bth = 6
		blen = 8
	# ---- pedestal
	if ti == 0:
		cv.ell(16, 27, 12, 4.5, base.darkened(0.3))
		cv.ell(16, 26, 11, 4.0, base)
		if v == 0:
			cv.line(10, 25, 14, 19, trim, 2.0)
			cv.line(22, 25, 18, 19, trim, 2.0)
			cv.rect(15, 18, 2, 5, trim)
		else:
			cv.rrect(10, 18, 12, 9, 2.0, base.lightened(0.1))
			cv.rect(10, 22, 12, 1, trim.darkened(0.3))
	elif ti == 1:
		cv.poly([Vector2(9, 21), Vector2(23, 21), Vector2(21, 30), Vector2(11, 30)], base)
		cv.rect(8, 20, 16, 2, base.lightened(0.2))
		cv.rect(10, 26, 12, 1, base.darkened(0.25))
		var lf := Color("2f8a3a") if v == 0 else Color("5a8a2f")
		cv.poly([Vector2(8, 21), Vector2(2, 17), Vector2(5, 22)], lf)
		cv.poly([Vector2(24, 21), Vector2(30, 17), Vector2(27, 22)], lf)
		cv.rect(15, 18, 2, 4, Color("2f7a3a"))
	elif ti == 3:
		cv.poly([Vector2(8, 30), Vector2(10, 21), Vector2(13, 30)], base.lightened(0.15))
		cv.poly([Vector2(12, 30), Vector2(16, 19), Vector2(20, 30)], base.lightened(0.3))
		cv.poly([Vector2(19, 30), Vector2(22, 21), Vector2(25, 30)], base.lightened(0.1))
		cv.line(16, 21, 16, 29, trim.darkened(0.2))
		cv.ell(16, 29.5, 11, 2.5, base.darkened(0.3))
	else:
		cv.rrect(7, 19, 18, 11, 1.5, base)
		cv.rect(7, 23, 18, 1, base.darkened(0.35))
		cv.rect(7, 26, 18, 1, base.darkened(0.35))
		cv.rect(7, 19, 18, 1, base.lightened(0.2))
		for p in [Vector2i(8, 20), Vector2i(23, 20), Vector2i(8, 28), Vector2i(23, 28)]:
			cv.px(p.x, p.y, trim)
	# ---- barrel behind the head when facing up
	if dir == 1:
		_tbarrel(cv, dir, hx, hy, bth, blen - 1, barrel, glow, twin)
	# ---- head
	if ti == 0 and v == 0:
		cv.ell(hx, hy, 6.5, 6.0, head)
		cv.ell(hx, hy, 4.0, 3.6, trim)
	elif ti == 0:
		cv.ell(hx, hy - 0.5, 9.0, 7.0, head)
		cv.rect(hx - 6, hy + 1, 3, 2, trim)
		cv.rect(hx + 3, hy + 1, 3, 2, trim)
	elif ti == 1 and v == 0:
		cv.ell(hx, hy, 6.5, 6.5, head)
		cv.poly([Vector2(hx - 7, hy + 4), Vector2(hx - 2, hy + 6), Vector2(hx - 6, hy + 8)], Color("2f8a3a"))
		cv.poly([Vector2(hx + 7, hy + 4), Vector2(hx + 2, hy + 6), Vector2(hx + 6, hy + 8)], Color("2f8a3a"))
		cv.px(hx - 3, hy - 3, trim)
		cv.px(hx + 3, hy - 2, trim)
	elif ti == 1:
		cv.ell(hx, hy - 0.5, 9.0, 7.5, head)
		cv.disc(hx - 4, hy - 3, 1.6, trim)
		cv.disc(hx + 4, hy - 2, 1.3, trim)
		cv.disc(hx + 1, hy - 5, 1.1, trim)
	elif ti == 3 and v == 0:
		cv.poly([Vector2(hx, hy - 8), Vector2(hx + 6, hy), Vector2(hx, hy + 7), Vector2(hx - 6, hy)], head)
		cv.poly([Vector2(hx, hy - 8), Vector2(hx + 2, hy), Vector2(hx, hy + 7), Vector2(hx - 6, hy)], head.lightened(0.25))
		cv.px(hx - 2, hy - 3, trim)
	elif ti == 3:
		cv.poly([Vector2(hx - 4, hy - 8), Vector2(hx + 5, hy - 6), Vector2(hx + 9, hy + 1), Vector2(hx + 4, hy + 7), Vector2(hx - 6, hy + 6), Vector2(hx - 9, hy - 1)], head)
		cv.poly([Vector2(hx - 4, hy - 8), Vector2(hx + 1, hy - 1), Vector2(hx - 9, hy - 1)], head.lightened(0.3))
		cv.px(hx + 4, hy - 3, trim)
	elif v == 0:
		cv.rrect(hx - 7, hy - 4, 14, 11, 2.0, head)
		cv.rect(hx - 7, hy - 4, 14, 2, trim)
		cv.px(hx - 6, hy + 5, trim)
		cv.px(hx + 5, hy + 5, trim)
	else:
		cv.rrect(hx - 8, hy - 5, 16, 12, 2.0, head)
		cv.rect(hx - 8, hy + 1, 16, 1, trim.darkened(0.4))
		cv.px(hx - 6, hy - 3, trim)
		cv.px(hx + 6, hy - 3, trim)
	# ---- barrel in front of the head for the other directions
	if dir != 1:
		_tbarrel(cv, dir, hx, hy, bth, blen, barrel, glow, twin)
	# eye / sensor
	if dir == 1:
		cv.px(hx, hy + 2, glow)
	elif dir == 0:
		cv.px(hx - 4, hy - 3, glow)
		cv.px(hx + 4, hy - 3, glow)
	elif dir == 3:
		cv.px(hx + 1, hy - 3, glow)
	else:
		cv.px(hx - 1, hy - 3, glow)
	cv.shade(0.2)
	cv.outline(Color("0a0d1a"))
	cv.img.fix_alpha_edges()
	var t := cv.tex()
	cache[key] = t
	return t


# ---------------------------------------------------------------- items

func item(kind: String) -> ImageTexture:
	if cache.has("item_" + kind):
		return cache["item_" + kind]
	var cv := Cv.new(32, 32)
	if kind == "pot" or kind == "big":
		var liq := Color("ffd84f") if kind == "pot" else Color("4fd1ff")
		var glass := Color("c9dcf2")
		if kind == "big":
			cv.disc(16, 19, 13, Color(liq.r, liq.g, liq.b, 0.18))
			cv.disc(16, 19, 10, Color(liq.r, liq.g, liq.b, 0.0))
		cv.rrect(8, 12, 16, 17, 6.0, glass)
		cv.rect(12, 6, 8, 8, glass)
		cv.rect(11, 5, 10, 2, glass.darkened(0.2))
		cv.shade(0.2)
		cv.rrect(9, 16, 14, 12, 5.0, liq.darkened(0.15))
		cv.rrect(9, 16, 14, 4, 2.0, liq)
		cv.rect(10, 16, 12, 1, liq.lightened(0.5))
		cv.rect(12, 2, 8, 4, Color("a86a38"))
		cv.rect(12, 2, 8, 1, Color("d09a60"))
		cv.rect(13, 4, 6, 1, Color("6e4220"))
		cv.line(11, 19, 11, 25, Color(1, 1, 1, 0.8))
		cv.px(14, 22, Color(1, 1, 1, 0.7))
		cv.px(19, 24, Color(1, 1, 1, 0.6))
		cv.px(17, 20, Color(1, 1, 1, 0.6))
		if kind == "big":
			cv.px(15, 21, Color.WHITE)
			cv.px(14, 21, liq.lightened(0.6))
			cv.px(16, 21, liq.lightened(0.6))
			cv.px(15, 20, liq.lightened(0.6))
			cv.px(15, 22, liq.lightened(0.6))
		cv.outline(Color("0e1322"))
	elif kind == "lamp":
		var gold := Color("c9a24a")
		cv.rrect(10, 4, 12, 4, 2.0, gold)
		cv.rect(14, 1, 4, 3, gold.darkened(0.2))
		cv.rrect(8, 8, 16, 16, 3.0, Color("ffcf4f"))
		cv.rect(8, 24, 16, 4, gold)
		cv.shade(0.22)
		cv.disc(16, 16, 5.5, Color("fff6c8"))
		cv.disc(16, 16, 3.0, Color.WHITE)
		cv.line(8, 12, 24, 12, gold.darkened(0.2))
		cv.line(8, 20, 24, 20, gold.darkened(0.2))
		cv.line(16, 8, 16, 24, gold.darkened(0.2))
		cv.rect(9, 25, 14, 1, gold.lightened(0.4))
		cv.outline(Color("2a1c06"))
	elif kind == "shield":
		var pts := [Vector2(5, 5), Vector2(27, 5), Vector2(27, 15), Vector2(22, 24), Vector2(16, 29), Vector2(10, 24), Vector2(5, 15)]
		cv.poly(pts, Color("b9c6e6"))
		cv.poly([Vector2(7, 7), Vector2(25, 7), Vector2(25, 15), Vector2(21, 22), Vector2(16, 26), Vector2(11, 22), Vector2(7, 15)], Color("4f8cff"))
		cv.shade(0.22)
		cv.poly([Vector2(16, 8), Vector2(25, 8), Vector2(25, 15), Vector2(21, 22), Vector2(16, 26)], Color("2a56b3"))
		cv.rect(14, 9, 4, 14, Color.WHITE)
		cv.rect(10, 13, 12, 4, Color.WHITE)
		cv.rect(15, 10, 2, 12, Color("a9c8ff"))
		for p in [Vector2(8, 8), Vector2(23, 8), Vector2(8, 14), Vector2(23, 14)]:
			cv.px(int(p.x), int(p.y), Color("eef3ff"))
		cv.line(8, 9, 8, 13, Color(1, 1, 1, 0.5))
		cv.outline(Color("0d1a3a"))
	elif kind == "coin":
		var gold := Color("ffc93c")
		cv.disc(16, 16, 12, Color("c98a12"))
		cv.disc(16, 16, 10.5, gold)
		cv.shade(0.25)
		cv.disc(16, 16, 8, gold.darkened(0.12))
		cv.disc(16, 16, 7, gold.lightened(0.1))
		var star: Array = []
		for i in 10:
			var a := -PI / 2.0 + i * PI / 5.0
			var rr := 6.0 if i % 2 == 0 else 2.6
			star.append(Vector2(16 + cos(a) * rr, 16.5 + sin(a) * rr))
		cv.poly(star, Color("e0a01a"))
		cv.line(9, 11, 12, 8, Color("fff3b0"))
		cv.px(11, 9, Color.WHITE)
		cv.px(21, 22, Color("a8700a"))
		cv.outline(Color("4a2e00"))
	elif kind == "hp":
		cv.rrect(11, 5, 10, 6, 2.0, Color("39415f"))
		cv.rrect(4, 9, 24, 19, 3.0, Color("f2f4fa"))
		cv.shade(0.2)
		cv.rrect(13, 7, 6, 3, 1.0, Color("0e1322"))
		cv.rect(14, 12, 4, 13, Color("e8505b"))
		cv.rect(10, 16, 12, 5, Color("e8505b"))
		cv.rect(14, 12, 4, 1, Color("ff9aa5"))
		cv.rect(10, 16, 12, 1, Color("ff9aa5"))
		cv.rect(5, 24, 22, 3, Color("c8cddd"))
		cv.px(6, 11, Color.WHITE)
		cv.px(25, 11, Color("9aa3c7"))
		cv.outline(Color("151a2e"))
	elif kind == "armor":
		var pts2 := [Vector2(5, 7), Vector2(11, 5), Vector2(16, 7), Vector2(21, 5), Vector2(27, 7), Vector2(26, 19), Vector2(21, 27), Vector2(16, 29), Vector2(11, 27), Vector2(6, 19)]
		cv.poly(pts2, Color("8a93b5"))
		cv.shade(0.24)
		cv.poly([Vector2(16, 9), Vector2(23, 10), Vector2(22, 19), Vector2(16, 26), Vector2(10, 19), Vector2(9, 10)], Color("aab4d8"))
		cv.line(16, 9, 16, 26, Color("e4eaff"))
		cv.line(16, 9, 16, 26, Color("e4eaff"))
		cv.rect(10, 13, 12, 1, Color("6d7699"))
		for p in [Vector2(8, 9), Vector2(24, 9), Vector2(10, 21), Vector2(22, 21)]:
			cv.disc(p.x, p.y, 1.2, Color("eaf0ff"))
		cv.outline(Color("10142a"))
	cv.img.fix_alpha_edges()
	var t := cv.tex()
	cache["item_" + kind] = t
	return t


# ---------------------------------------------------------------- icons

func icon(name: String) -> ImageTexture:
	if cache.has("icon_" + name):
		return cache["icon_" + name]
	var cv := Cv.new(32, 32)
	var ol := Color("0e1322")
	if name == "spikes":
		cv.rrect(2, 15, 28, 14, 2.0, Color("3a4054"))
		cv.shade(0.2)
		cv.rect(3, 16, 26, 1, Color("5c6482"))
		for row in 2:
			for col in 3:
				var bx := 7.0 + col * 9.0
				var by := 24.0 - row * 6.0
				cv.poly([Vector2(bx - 3.5, by + 3), Vector2(bx + 3.5, by + 3), Vector2(bx, by - 7)], Color("d3d9e8"))
				cv.poly([Vector2(bx, by - 7), Vector2(bx + 3.5, by + 3), Vector2(bx, by + 3)], Color("7c8497"))
				cv.px(int(bx), int(by - 7), Color("ff5d5d"))
				cv.px(int(bx), int(by - 6), Color("c93b3b"))
		cv.disc(5, 27, 1.0, Color("8a93b5"))
		cv.disc(27, 27, 1.0, Color("8a93b5"))
		cv.outline(ol)
	elif name == "vault":
		cv.rrect(3, 13, 26, 16, 2.0, Color("7a4a1e"))
		cv.rrect(3, 6, 26, 12, 5.0, Color("a46a2a"))
		cv.shade(0.22)
		cv.rect(3, 16, 26, 2, Color("3a2410"))
		cv.rect(8, 6, 3, 23, Color("40485e"))
		cv.rect(21, 6, 3, 23, Color("40485e"))
		cv.rect(8, 6, 1, 23, Color("7b86a8"))
		cv.rect(21, 6, 1, 23, Color("7b86a8"))
		cv.rrect(13, 14, 6, 8, 1.5, Color("ffd84f"))
		cv.rect(13, 14, 6, 1, Color("fff3a8"))
		cv.px(16, 17, Color("3a2410"))
		cv.rect(16, 18, 1, 2, Color("3a2410"))
		cv.rect(5, 8, 2, 1, Color("d9a566"))
		for p in [Vector2(9, 8), Vector2(22, 8), Vector2(9, 26), Vector2(22, 26)]:
			cv.px(int(p.x), int(p.y), Color("c5cde6"))
		cv.outline(Color("1a0e04"))
	elif name == "key":
		var gold := Color("ffd84f")
		cv.disc(10, 12, 7, gold)
		cv.disc(10, 12, 3.5, Color(0, 0, 0, 0))
		for yy in range(8, 17):
			for xx in range(7, 14):
				if (xx - 10) * (xx - 10) + (yy - 12) * (yy - 12) <= 10:
					cv.img.set_pixel(xx, yy, Color(0, 0, 0, 0))
		cv.rect(14, 11, 15, 3, gold)
		cv.rect(22, 14, 3, 5, gold)
		cv.rect(26, 14, 3, 7, gold)
		cv.shade(0.25)
		cv.rect(14, 11, 15, 1, Color("fff3a8"))
		cv.px(6, 8, Color.WHITE)
		cv.outline(Color("4a3000"))
	elif name == "pod":
		cv.rrect(9, 7, 14, 22, 5.0, Color("2f78b8"))
		cv.rect(13, 3, 6, 5, Color("9aa3c7"))
		cv.rect(11, 2, 10, 2, Color("c9d3f0"))
		cv.rrect(9, 7, 14, 6, 3.0, Color("9fe0ff"))
		cv.shade(0.22)
		cv.rrect(11, 15, 10, 9, 1.5, Color("0b2a44"))
		_text(cv, "O2", 12, 17, Color("e6f8ff"))
		cv.line(11, 9, 11, 26, Color(1, 1, 1, 0.45))
		cv.outline(Color("07182a"))
	elif name == "station":
		cv.ell(16, 19, 14, 10, Color("39415f"))
		cv.ell(16, 18, 12, 8, Color("1b2440"))
		cv.ell(16, 18, 9, 6, Color("2a6fa8"))
		cv.ell(16, 17.5, 7, 4.5, Color("9fe0ff"))
		cv.shade(0.2)
		for i in 8:
			var a := i * TAU / 8.0
			cv.px(int(16 + cos(a) * 12), int(19 + sin(a) * 8), Color("7fd8ff"))
		_text(cv, "O2", 12, 15, Color("0b2a44"))
		cv.outline(Color("07182a"))
	elif name == "merchant":
		cv.rect(5, 17, 22, 12, Color("5a3a1a"))
		cv.rect(5, 17, 22, 2, Color("8a5a2a"))
		cv.rect(7, 21, 18, 7, Color("3a2410"))
		for i in 6:
			var col := Color("d84a3a") if i % 2 == 0 else Color("f4e9d0")
			cv.poly([Vector2(3 + i * 4.3, 16), Vector2(3 + (i + 1) * 4.3, 16), Vector2(16 + (i - 2.5) * 1.0 + 0.5, 4)], col)
		cv.shade(0.2)
		cv.rect(4, 15, 24, 2, Color("b83a2c"))
		cv.rect(5, 5, 22, 1, Color("f4e9d0"))
		cv.disc(24, 21, 2.5, Color("ffd84f"))
		cv.disc(10, 22, 2.5, Color("ffd84f"))
		_text(cv, "$", 14, 20, Color("ffd84f"))
		cv.px(16, 12, Color("ffd84f"))
		cv.outline(Color("1a0e08"))
	elif name == "door_locked" or name == "door_open":
		var ok := name == "door_open"
		var glow := Color("6dff9a") if ok else Color("ff7a7a")
		cv.rrect(5, 2, 22, 28, 3.0, Color("56607f"))
		cv.rrect(8, 5, 16, 25, 2.0, Color("2a3150"))
		cv.shade(0.2)
		cv.rect(8, 5, 8, 25, Color("3a4468") if not ok else Color("2d6a4a"))
		cv.rect(16, 5, 8, 25, Color("323b5c") if not ok else Color("267a52"))
		cv.rect(15, 5, 2, 25, Color("11162a"))
		for i in 5:
			cv.rect(8 + i * 3, 6, 2, 2, Color("e8b82a") if i % 2 == 0 else Color("1a1a1a"))
		cv.rect(12, 14, 3, 4, Color("11162a"))
		cv.rect(17, 14, 3, 4, Color("11162a"))
		cv.px(13, 15, glow)
		cv.px(18, 15, glow)
		cv.rect(14, 3, 4, 2, glow)
		cv.rect(10, 22, 12, 1, Color("11162a"))
		cv.outline(Color("0a0d1a"))
	elif name.begins_with("crate_"):
		var slot := name.substr(6)
		var col := _slot_col(slot)
		cv.rrect(4, 6, 24, 22, 2.0, Color("5b3f22"))
		cv.shade(0.22)
		cv.rect(4, 11, 24, 2, Color("3a2814"))
		cv.rect(4, 21, 24, 2, Color("3a2814"))
		cv.rect(4, 6, 3, 22, col.darkened(0.2))
		cv.rect(25, 6, 3, 22, col.darkened(0.2))
		cv.rect(4, 6, 24, 1, Color("8a6538"))
		cv.rrect(10, 12, 12, 10, 2.0, col.darkened(0.55))
		_slot_picto(cv, slot, col)
		cv.outline(Color("120c06"))
	elif name == "haz_arc":
		cv.rrect(3, 3, 26, 26, 3.0, Color("2a3050"))
		cv.rect(4, 4, 24, 1, Color("5a6a9a"))
		for p in [Vector2i(5, 5), Vector2i(26, 5), Vector2i(5, 26), Vector2i(26, 26)]:
			cv.rect(p.x - 1, p.y - 1, 3, 3, Color("ffe14f"))
		cv.rect(7, 7, 18, 18, Color("181e38"))
		cv.poly([Vector2(18, 6), Vector2(10, 17), Vector2(15, 17), Vector2(12, 27), Vector2(23, 14), Vector2(17, 14)], Color("ffe14f"))
		cv.poly([Vector2(18, 9), Vector2(13, 16), Vector2(17, 16), Vector2(15, 22), Vector2(20, 15), Vector2(16, 15)], Color("fff6b0"))
		cv.outline(Color("0a0d1a"))
	elif name == "haz_breach":
		cv.rrect(3, 3, 26, 26, 3.0, Color("2f3550"))
		cv.ell(16, 16, 9, 7, Color("05080f"))
		cv.ell(16, 16, 6, 4.5, Color("0b1730"))
		cv.line(4, 6, 12, 11, Color("7fd8ff"))
		cv.line(28, 5, 21, 11, Color("7fd8ff"))
		cv.line(5, 27, 11, 21, Color("7fd8ff"))
		cv.line(27, 26, 21, 21, Color("7fd8ff"))
		cv.ell(16, 16, 9, 7, Color(0, 0, 0, 0))
		cv.ell(16, 16, 9, 7, Color("05080f"))
		cv.px(13, 14, Color("cfeeff"))
		cv.px(18, 17, Color("cfeeff"))
		cv.rect(5, 4, 4, 1, Color("5a6a9a"))
		cv.outline(Color("0a0d1a"))
	elif name == "haz_toxic":
		cv.ell(16, 19, 14, 9, Color("1f5a2a"))
		cv.ell(16, 18, 12.5, 8, Color("3fb04a"))
		cv.ell(16, 17.5, 10, 6, Color("6fe06a"))
		cv.disc(11, 17, 2.2, Color("b8ffa8"))
		cv.disc(20, 20, 1.6, Color("b8ffa8"))
		cv.disc(17, 15, 1.2, Color("e8ffd8"))
		cv.px(10, 16, Color.WHITE)
		cv.ell(16, 18, 14, 9, Color(0, 0, 0, 0))
		cv.ell(16, 19, 14, 9, Color("1f5a2a"))
		cv.ell(16, 18, 12.5, 8, Color("3fb04a"))
		cv.ell(16, 17.5, 10, 6, Color("6fe06a"))
		cv.disc(11, 17, 2.2, Color("b8ffa8"))
		cv.disc(20, 20, 1.6, Color("b8ffa8"))
		cv.disc(17, 15, 1.2, Color("e8ffd8"))
		cv.px(10, 16, Color.WHITE)
		cv.outline(Color("0a2a10"))
	elif name == "haz_slick":
		cv.ell(16, 19, 14, 9, Color("2a8a80"))
		cv.ell(16, 18, 12.5, 8, Color("6fe0c8"))
		cv.line(7, 16, 16, 13, Color("e8fff8"))
		cv.line(18, 22, 25, 19, Color("b8fff0"))
		cv.rect(10, 11, 2, 4, Color("e8dcc0"))
		cv.ell(11, 10.5, 3.2, 2.2, Color("c07cff"))
		cv.rect(21, 14, 2, 3, Color("e8dcc0"))
		cv.ell(22, 13.5, 2.5, 1.8, Color("ff8ad0"))
		cv.px(10, 10, Color("f0d8ff"))
		cv.outline(Color("0a3a34"))
	elif name == "haz_mine":
		cv.ell(16, 26, 10, 3, Color(0, 0, 0, 0.35))
		for i in 8:
			var a := i * TAU / 8.0
			cv.disc(16 + cos(a) * 9.5, 17 + sin(a) * 9.5, 1.8, Color("5a6070"))
		cv.disc(16, 17, 8.5, Color("3a3f4f"))
		cv.disc(16, 17, 6.0, Color("4a5062"))
		cv.rect(10, 16, 12, 2, Color("2a2f3f"))
		cv.disc(16, 17, 2.6, Color("ff4f4f"))
		cv.px(15, 16, Color("ffc0c0"))
		cv.px(11, 13, Color("8a93a8"))
		cv.px(12, 12, Color("8a93a8"))
		cv.outline(Color("0a0d1a"))
	elif name == "haz_warp":
		cv.rrect(3, 3, 26, 26, 3.0, Color("2a1c46"))
		cv.ell(16, 16, 10, 10, Color("120a22"))
		for i in 3:
			var rr := 9.0 - i * 3.0
			cv.ell(16, 16, rr, rr * 0.9, [Color("7fe8ff"), Color("d58cff"), Color("ff8ad0")][i])
			cv.ell(16, 16, rr - 1.5, (rr - 1.5) * 0.9, Color("120a22"))
		cv.disc(16, 16, 1.6, Color("ffffff"))
		for p in [Vector2i(5, 5), Vector2i(26, 5), Vector2i(5, 26), Vector2i(26, 26)]:
			cv.px(p.x, p.y, Color("d58cff"))
		cv.outline(Color("0a0d1a"))
	elif name == "haz_shard":
		cv.ell(16, 26, 12, 3.5, Color(0, 0, 0, 0.35))
		cv.poly([Vector2(4, 27), Vector2(8, 12), Vector2(12, 27)], Color("8a5ad0"))
		cv.poly([Vector2(10, 27), Vector2(16, 4), Vector2(22, 27)], Color("c9a0ff"))
		cv.poly([Vector2(16, 4), Vector2(18, 16), Vector2(22, 27), Vector2(16, 27)], Color("a070e8"))
		cv.poly([Vector2(20, 27), Vector2(25, 10), Vector2(29, 27)], Color("7fe8ff"))
		cv.line(16, 6, 16, 14, Color("f0e0ff"))
		cv.px(8, 14, Color.WHITE)
		cv.px(25, 12, Color.WHITE)
		cv.outline(Color("0a0d1a"))
	elif name == "haz_alarm":
		cv.rect(3, 6, 4, 22, Color("5a6070"))
		cv.rect(25, 6, 4, 22, Color("5a6070"))
		cv.rect(3, 6, 1, 22, Color("8a93a8"))
		cv.rect(25, 6, 1, 22, Color("8a93a8"))
		cv.rect(2, 4, 6, 3, Color("ff4f4f"))
		cv.rect(24, 4, 6, 3, Color("ff4f4f"))
		cv.line(7, 16, 25, 16, Color("ff7a7a"))
		cv.line(7, 17, 25, 17, Color("a82a2a"))
		cv.rrect(13, 11, 6, 7, 1.5, Color("ffd84f"))
		cv.px(15, 14, Color("5a4500"))
		cv.px(16, 14, Color("5a4500"))
		cv.rect(3, 27, 4, 2, Color("3a3f4f"))
		cv.rect(25, 27, 4, 2, Color("3a3f4f"))
		cv.outline(Color("0a0d1a"))
	elif name == "medstation":
		cv.ell(16, 27, 13, 3, Color("1b2440"))
		cv.rrect(6, 5, 20, 21, 3.0, Color("dfe8f2"))
		cv.shade(0.22)
		cv.rrect(8, 7, 16, 12, 2.0, Color("0f3a28"))
		cv.rect(14, 8, 4, 10, Color("3ddc84"))
		cv.rect(10, 11, 12, 4, Color("3ddc84"))
		cv.rect(14, 8, 4, 1, Color("b6ffd2"))
		cv.rect(10, 11, 12, 1, Color("b6ffd2"))
		cv.rect(9, 21, 10, 2, Color("9aa8bd"))
		cv.rect(21, 21, 3, 3, Color("ff6b6b"))
		cv.px(21, 21, Color("ffc2c2"))
		cv.outline(Color("0b1a14"))
	elif name.begins_with("use_"):
		_tool_icon(cv, name.substr(4))
	cv.img.fix_alpha_edges()
	var t := cv.tex()
	cache["icon_" + name] = t
	return t


func _slot_col(slot: String) -> Color:
	var cols := {"weapon": Color("ff8a4f"), "helmet": Color("4fd1ff"), "armour": Color("9fb3d9"), "boots": Color("6dff9a"), "trinket": Color("c07cff")}
	return cols.get(slot, Color.WHITE)


func _slot_picto(cv: Cv, slot: String, col: Color) -> void:
	if slot == "weapon":
		cv.line(12, 21, 20, 13, col.lightened(0.4), 2.0)
		cv.px(11, 21, col)
		cv.px(12, 22, col)
	elif slot == "helmet":
		cv.ell(16, 18, 4.5, 4.0, col)
		cv.rect(12, 18, 9, 2, col.darkened(0.3))
	elif slot == "armour":
		cv.poly([Vector2(12, 13), Vector2(20, 13), Vector2(19, 21), Vector2(13, 21)], col)
		cv.rect(15, 13, 2, 8, col.darkened(0.3))
	elif slot == "boots":
		cv.rect(13, 13, 4, 7, col)
		cv.rect(13, 19, 8, 3, col)
	else:
		cv.poly([Vector2(16, 12), Vector2(20, 17), Vector2(16, 22), Vector2(12, 17)], col)
		cv.px(15, 15, Color.WHITE)


func _tool_icon(cv: Cv, id: String) -> void:
	var ol := Color("0e1322")
	if id == "bomb":
		cv.disc(15, 19, 9, Color("2b2f3d"))
		cv.shade(0.3)
		cv.rect(13, 8, 5, 3, Color("6b7388"))
		cv.line(17, 8, 22, 4, Color("c9a55a"), 1.5)
		cv.disc(23, 3, 2.2, Color("ffb347"))
		cv.px(23, 3, Color("fff3a8"))
		cv.px(25, 2, Color("ff7a45"))
		cv.px(21, 1, Color("ff7a45"))
		cv.px(11, 15, Color(1, 1, 1, 0.8))
		cv.px(12, 14, Color(1, 1, 1, 0.6))
		cv.line(10, 16, 10, 18, Color(1, 1, 1, 0.5))
		cv.ell(15, 22, 4, 2, Color("ff7a45"))
		cv.outline(ol)
	elif id == "crystal":
		var c := Color("4fd1ff")
		cv.poly([Vector2(16, 2), Vector2(24, 11), Vector2(21, 28), Vector2(11, 28), Vector2(8, 11)], c)
		cv.shade(0.28)
		cv.poly([Vector2(16, 2), Vector2(24, 11), Vector2(16, 14)], c.lightened(0.45))
		cv.poly([Vector2(16, 14), Vector2(24, 11), Vector2(21, 28), Vector2(16, 28)], c.darkened(0.25))
		cv.line(8, 11, 24, 11, c.darkened(0.2))
		cv.line(16, 2, 16, 28, c.lightened(0.2))
		cv.px(12, 9, Color.WHITE)
		cv.px(13, 8, Color.WHITE)
		cv.outline(Color("0b2a44"))
	elif id == "blink":
		cv.rrect(5, 8, 22, 16, 3.0, Color("e8d9b0"))
		cv.ell(6, 16, 3, 8, Color("c9b27f"))
		cv.ell(26, 16, 3, 8, Color("c9b27f"))
		cv.shade(0.22)
		cv.ell(6, 16, 1.2, 4, Color("8a7648"))
		cv.ell(26, 16, 1.2, 4, Color("8a7648"))
		for i in 12:
			var a := i * 0.5
			var r := 1.0 + i * 0.55
			cv.px(int(16 + cos(a) * r), int(16 + sin(a) * r * 0.8), Color("8b4fe0"))
		cv.px(16, 16, Color("e6c8ff"))
		cv.rect(12, 26, 8, 2, Color("c0392b"))
		cv.outline(Color("2a1c06"))
	elif id == "cloak":
		cv.poly([Vector2(16, 2), Vector2(23, 8), Vector2(27, 29), Vector2(5, 29), Vector2(9, 8)], Color("5a6280"))
		cv.ell(16, 9, 7, 7, Color("4a5270"))
		cv.shade(0.25)
		cv.ell(16, 10, 4.5, 4.5, Color("0e1322"))
		cv.px(14, 10, Color("9fe0ff"))
		cv.px(18, 10, Color("9fe0ff"))
		cv.line(16, 15, 16, 28, Color("3a4160"))
		cv.rect(14, 15, 4, 2, Color("ffd84f"))
		cv.line(8, 26, 24, 26, Color("7a84a8"))
		cv.outline(ol)
	elif id == "draught":
		var liq := Color("6dff9a")
		cv.rrect(8, 12, 16, 17, 6.0, Color("c9dcf2"))
		cv.rect(12, 6, 8, 8, Color("c9dcf2"))
		cv.shade(0.2)
		cv.rrect(9, 16, 14, 12, 5.0, liq.darkened(0.15))
		cv.rrect(9, 16, 14, 4, 2.0, liq)
		cv.rect(12, 2, 8, 4, Color("a86a38"))
		cv.line(11, 19, 11, 25, Color(1, 1, 1, 0.8))
		cv.px(18, 22, Color(1, 1, 1, 0.7))
		cv.px(15, 24, liq.lightened(0.6))
		cv.px(21, 8, liq.lightened(0.5))
		cv.px(24, 6, liq.lightened(0.5))
		cv.outline(ol)
	elif id == "magnet":
		cv.ell(16, 16, 11, 11, Color("e8505b"))
		cv.ell(16, 17, 6, 6, Color(0, 0, 0, 0))
		for yy in range(10, 28):
			for xx in range(10, 23):
				if (xx - 16) * (xx - 16) + (yy - 17) * (yy - 17) <= 30:
					cv.img.set_pixel(xx, yy, Color(0, 0, 0, 0))
		cv.rect(5, 17, 6, 11, Color("e8505b"))
		cv.rect(21, 17, 6, 11, Color("e8505b"))
		cv.shade(0.28)
		cv.rect(5, 23, 6, 5, Color("e8eaf2"))
		cv.rect(21, 23, 6, 5, Color("e8eaf2"))
		cv.rect(5, 23, 6, 1, Color("9aa3c7"))
		cv.rect(21, 23, 6, 1, Color("9aa3c7"))
		cv.px(8, 8, Color("ff9aa5"))
		cv.outline(Color("2a0a10"))
	elif id == "pick":
		cv.line(8, 25, 21, 8, Color("8a5a2a"), 2.5)
		cv.poly([Vector2(8, 10), Vector2(16, 5), Vector2(26, 8), Vector2(28, 12), Vector2(22, 9), Vector2(14, 9), Vector2(10, 13)], Color("c5cde6"))
		cv.shade(0.26)
		cv.line(9, 24, 20, 9, Color("b07a3a"))
		cv.rect(14, 6, 10, 1, Color("f4f7ff"))
		cv.px(26, 9, Color("9aa3c7"))
		cv.outline(ol)
	elif id == "zap":
		cv.rrect(12, 4, 8, 24, 3.0, Color("6b7388"))
		cv.shade(0.25)
		cv.rect(12, 9, 8, 2, Color("ffe14f"))
		cv.rect(12, 21, 8, 2, Color("ffe14f"))
		cv.disc(16, 4, 3.5, Color("fff3a8"))
		cv.poly([Vector2(19, 0), Vector2(13, 8), Vector2(17, 8), Vector2(14, 15), Vector2(22, 6), Vector2(18, 6)], Color("ffe14f"))
		cv.px(8, 7, Color("fff3a8"))
		cv.px(25, 11, Color("fff3a8"))
		cv.px(7, 13, Color("ffe14f"))
		cv.outline(ol)
	elif id == "nano":
		cv.rect(11, 2, 10, 2, Color("c5cde6"))
		cv.rect(15, 4, 2, 5, Color("c5cde6"))
		cv.rect(9, 9, 14, 2, Color("c5cde6"))
		cv.rrect(11, 10, 10, 14, 2.0, Color("e8f2ff"))
		cv.shade(0.2)
		cv.rrect(12, 14, 8, 9, 1.5, Color("ff5d7a"))
		cv.rect(12, 14, 8, 2, Color("ff9aa8"))
		cv.rect(15, 24, 2, 6, Color("9aa3c7"))
		cv.line(13, 12, 13, 22, Color(1, 1, 1, 0.7))
		cv.outline(ol)
	elif id == "cell":
		cv.rrect(8, 6, 16, 22, 3.0, Color("2d5fb8"))
		cv.rect(13, 3, 6, 3, Color("9aa3c7"))
		cv.shade(0.26)
		cv.poly([Vector2(18, 9), Vector2(11, 18), Vector2(15, 18), Vector2(13, 25), Vector2(21, 15), Vector2(17, 15)], Color("e6f4ff"))
		cv.rect(9, 7, 1, 19, Color("7db2ff"))
		cv.outline(Color("0b1a3a"))
	elif id == "plate":
		cv.rrect(6, 7, 20, 20, 4.0, Color("9fb3d9"))
		cv.shade(0.28)
		cv.rect(7, 8, 18, 1, Color("d6e0f5"))
		for rp in [Vector2(9, 10), Vector2(22, 10), Vector2(9, 24), Vector2(22, 24)]:
			cv.px(int(rp.x), int(rp.y), Color("40485e"))
			cv.px(int(rp.x) - 1, int(rp.y) - 1, Color("e8eefc"))
		cv.rect(14, 12, 4, 11, Color("1a2236"))
		cv.rect(11, 15, 10, 4, Color("1a2236"))
		cv.outline(ol)
	elif id == "scan":
		cv.disc(16, 16, 13, Color("163a3a"))
		for i in 28:
			var a := i * TAU / 28.0
			cv.px(int(16 + cos(a) * 9.0), int(16 + sin(a) * 9.0), Color("5fe0b0"))
			cv.px(int(16 + cos(a) * 4.5), int(16 + sin(a) * 4.5), Color("3fa584"))
		cv.poly([Vector2(16, 16), Vector2(27, 7), Vector2(28, 14)], Color(0.4, 1.0, 0.7, 0.4))
		cv.line(16, 16, 27, 7, Color("a8ffd8"), 1.5)
		cv.px(21, 21, Color("ffe14f"))
		cv.px(10, 11, Color("ffe14f"))
		cv.px(22, 13, Color("ffe14f"))
		cv.shade(0.18)
		cv.outline(Color("07201f"))
	elif id == "ration":
		cv.rrect(7, 8, 18, 20, 3.0, Color("c7852f"))
		cv.rect(7, 14, 18, 9, Color("e8d9b0"))
		cv.shade(0.22)
		cv.rect(6, 7, 20, 3, Color("c5cde6"))
		cv.rect(6, 26, 20, 3, Color("c5cde6"))
		cv.disc(14, 17, 2.2, Color("d9453f"))
		cv.disc(18, 17, 2.2, Color("d9453f"))
		cv.poly([Vector2(11.5, 18), Vector2(20.5, 18), Vector2(16, 22.5)], Color("d9453f"))
		cv.px(13, 16, Color("ff9a94"))
		cv.outline(Color("2a1c06"))
	else:
		cv.disc(16, 16, 9, Color("c9d3f0"))
		cv.outline(ol)


# ---------------------------------------------------------------- tiles

const NV := 16


func floor_tile(ti: int, parity: int, variant: int) -> ImageTexture:
	variant = variant % NV
	var key := "floor%d_%d_%d" % [ti, parity, variant]
	if cache.has(key):
		return cache[key]
	var art_f: ImageTexture = _atlas_cell("res://art/tile_atlas.png", variant, ti * 2 + parity)
	if art_f != null:
		cache[key] = art_f
		return art_f
	var base: Color = themes[ti]["tile"] if parity == 0 else themes[ti]["tile2"]
	var rng := RandomNumberGenerator.new()
	rng.seed = ti * 1000 + parity * 100 + variant * 7 + 11
	var cv := Cv.new(32, 32)
	cv.rect(0, 0, 32, 32, base)
	for i in 110:
		var x := rng.randi_range(0, 31)
		var y := rng.randi_range(0, 31)
		cv.px(x, y, base.lightened(0.05) if rng.randf() < 0.5 else base.darkened(0.07))
	if ti == 0:
		_floor0(cv, base, rng, variant)
	elif ti == 1:
		_floor1(cv, base, rng, variant)
	elif ti == 3:
		_floor3(cv, base, rng, variant)
	else:
		_floor2(cv, base, rng, variant)
	cv.img.fix_alpha_edges()
	var t := cv.tex()
	cache[key] = t
	return t


func _floor0(cv: Cv, base: Color, rng: RandomNumberGenerator, v: int) -> void:
	var dk := base.darkened(0.4)
	for i in 32:
		cv.px(i, 0, dk)
		cv.px(0, i, dk)
		cv.px(i, 1, base.lightened(0.12))
		cv.px(1, i, base.lightened(0.12))
		cv.px(i, 31, base.darkened(0.18))
		cv.px(31, i, base.darkened(0.18))
	if v % 3 != 2 or v >= 6:
		for p in [Vector2i(4, 4), Vector2i(26, 4), Vector2i(4, 26), Vector2i(26, 26)]:
			if rng.randf() < 0.85:
				cv.disc(p.x + 1, p.y + 1, 2.0, base.darkened(0.3))
				cv.disc(p.x + 0.5, p.y + 0.5, 1.5, base.lightened(0.18))
				cv.px(p.x, p.y, base.lightened(0.5))
	if v < 6:
		if v % 3 == 1:
			cv.rect(2, 15, 28, 1, base.darkened(0.3))
			cv.rect(2, 16, 28, 1, base.lightened(0.1))
		elif v % 3 == 2:
			cv.rect(15, 2, 1, 28, base.darkened(0.3))
			cv.rect(16, 2, 1, 28, base.lightened(0.1))
		for i in rng.randi_range(2, 5):
			var sx := rng.randi_range(5, 24)
			var sy := rng.randi_range(5, 26)
			cv.line(sx, sy, sx + rng.randi_range(2, 6), sy + rng.randi_range(-2, 2), base.darkened(0.25) if rng.randf() < 0.6 else base.lightened(0.15))
	elif v == 6:
		cv.rect(8, 9, 16, 14, base.darkened(0.45))
		for x in range(9, 23, 2):
			cv.rect(x, 10, 1, 12, base.darkened(0.12))
		cv.rect(8, 9, 16, 1, base.darkened(0.7))
		cv.rect(8, 23, 16, 1, base.lightened(0.15))
	elif v == 7:
		for x in range(0, 40, 6):
			cv.poly([Vector2(x - 4, 26), Vector2(x - 1, 26), Vector2(x + 2, 30), Vector2(x - 1, 30)], Color("d9a81e"))
		cv.rect(0, 25, 32, 1, base.darkened(0.5))
		cv.rect(0, 30, 32, 1, base.darkened(0.5))
	elif v == 8:
		var cy := rng.randi_range(9, 19)
		cv.rect(1, cy, 30, 5, Color("2a2f40"))
		cv.rect(1, cy, 30, 1, Color("5a6280"))
		cv.rect(1, cy + 4, 30, 1, Color("14182a"))
		for x in [8, 20]:
			cv.rect(x, cy - 1, 3, 7, Color("7b86a8"))
			cv.px(x + 1, cy + 2, Color("14182a"))
		cv.line(1, cy + 2, 30, cy + 2, Color("c9a23a") if rng.randf() < 0.5 else Color("4fd1ff"))
	elif v == 9:
		var ox := rng.randf_range(11.0, 21.0)
		var oy := rng.randf_range(11.0, 21.0)
		cv.ell(ox, oy, 8.0, 5.0, base.darkened(0.55))
		cv.ell(ox - 1.0, oy - 1.0, 5.5, 3.0, base.darkened(0.7))
		cv.px(int(ox) - 3, int(oy) - 2, Color("6a8bd8"))
		cv.px(int(ox) - 2, int(oy) - 2, Color("a05ac8"))
	elif v == 10:
		cv.rrect(7, 7, 18, 18, 2.0, base.darkened(0.35))
		cv.rrect(8, 8, 16, 16, 2.0, base.lightened(0.04))
		cv.rect(13, 14, 6, 3, Color("39415f"))
		cv.rect(13, 14, 6, 1, Color("7b86a8"))
		for p in [Vector2i(9, 9), Vector2i(22, 9), Vector2i(9, 22), Vector2i(22, 22)]:
			cv.px(p.x, p.y, base.lightened(0.5))
	elif v == 11:
		var bx := rng.randf_range(10.0, 22.0)
		var by := rng.randf_range(10.0, 22.0)
		for r in range(9, 0, -2):
			cv.ell(bx, by, r, r * 0.8, base.darkened(0.08 * (10 - r) * 0.5 + 0.08))
		cv.line(bx - 6, by + 1, bx + 5, by - 2, base.darkened(0.7))
	elif v == 12:
		cv.rect(4, 9, 24, 14, base.darkened(0.45))
		for k in 3:
			var ax := 7 + k * 7
			cv.poly([Vector2(ax, 12), Vector2(ax + 4, 16), Vector2(ax, 20), Vector2(ax + 2, 20), Vector2(ax + 6, 16), Vector2(ax + 2, 12)], Color("e8b82a"))
	elif v == 13:
		for i in 22:
			var rx := rng.randi_range(3, 28)
			var ry := rng.randi_range(3, 28)
			cv.px(rx, ry, Color("8a4a2a") if rng.randf() < 0.7 else Color("b8683a"))
			if rng.randf() < 0.5:
				cv.px(rx + 1, ry, Color("6a3a20"))
	elif v == 14:
		for x in range(3, 29, 5):
			cv.rect(x, 15, 3, 2, base.lightened(0.28))
		cv.rect(3, 12, 26, 1, base.darkened(0.3))
		cv.rect(3, 19, 26, 1, base.darkened(0.3))
	else:
		var sx2 := rng.randi_range(4, 10)
		var pts: Array = []
		var cx := float(sx2)
		var cy2 := 2.0
		while cy2 < 30.0:
			pts.append(Vector2(cx, cy2))
			cx += rng.randf_range(-3.0, 4.0)
			cy2 += rng.randf_range(3.0, 5.0)
		for i in range(pts.size() - 1):
			cv.line(pts[i].x, pts[i].y, pts[i + 1].x, pts[i + 1].y, base.darkened(0.7))
			cv.line(pts[i].x + 1, pts[i].y, pts[i + 1].x + 1, pts[i + 1].y, base.lightened(0.18))


func _floor1(cv: Cv, base: Color, rng: RandomNumberGenerator, v: int) -> void:
	for i in 34 + (v % 4) * 6:
		var gx := rng.randi_range(1, 30)
		var gy := rng.randi_range(3, 30)
		cv.px(gx, gy, base.lightened(0.28))
		cv.px(gx, gy - 1, base.lightened(0.5))
		cv.px(gx - 1, gy - 2, base.lightened(0.4))
		cv.px(gx + 1, gy - 2, base.lightened(0.3))
	for i in 22:
		cv.px(rng.randi_range(0, 31), rng.randi_range(0, 31), base.darkened(0.28))
	if v < 6:
		for i in v % 3 + 1:
			var lx := rng.randi_range(4, 26)
			var ly := rng.randi_range(4, 26)
			cv.line(lx, ly, lx + 2, ly - 3, Color("3b9a4a"))
			cv.line(lx + 2, ly, lx + 2, ly - 4, Color("5fc06a"))
		return
	var px_ := rng.randi_range(6, 24)
	var py_ := rng.randi_range(7, 24)
	if v == 6:
		for k in 3:
			var fx := px_ + rng.randi_range(-5, 5)
			var fy := py_ + rng.randi_range(-4, 4)
			cv.line(fx, fy + 1, fx, fy + 5, Color("2f7a3a"))
			var pet: Color = [Color("ff9ecb"), Color("fff3a8"), Color("b8a0ff"), Color("ffffff")][rng.randi() % 4]
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				cv.px(fx + d.x, fy + d.y, pet)
			cv.px(fx, fy, Color("ffe066"))
	elif v == 7:
		for k in 3:
			var mx := px_ + rng.randi_range(-5, 5)
			var my := py_ + rng.randi_range(-3, 3)
			cv.rect(mx, my, 2, 4, Color("e8dcc0"))
			cv.ell(mx + 1, my, 3.5, 2.5, Color("c0485a") if k != 1 else Color("a06ac0"))
			cv.px(mx, my - 1, Color("fff0e0"))
			cv.px(mx + 2, my, Color("fff0e0"))
	elif v == 8:
		for k in 2:
			var rx := px_ + rng.randi_range(-6, 6)
			var ry := py_ + rng.randi_range(-4, 4)
			cv.ell(rx, ry, 4.5, 3.5, Color("7a8078"))
			cv.ell(rx - 1, ry - 1, 3.0, 2.0, Color("a3a99f"))
			cv.px(rx - 2, ry - 2, Color("d8ddd2"))
			cv.ell(rx + 1, ry + 2, 3.5, 1.0, base.darkened(0.4))
	elif v == 9:
		cv.ell(px_, py_, 9.0, 6.0, Color("6a4f2a"))
		cv.ell(px_, py_, 6.5, 4.0, Color("7d5f34"))
		for i in 14:
			cv.px(px_ + rng.randi_range(-7, 7), py_ + rng.randi_range(-4, 4), Color("4a3519"))
	elif v == 10:
		cv.ell(px_, py_, 8.0, 5.0, Color("2f5f6a"))
		cv.ell(px_, py_, 6.5, 3.6, Color("3f7f8a"))
		cv.line(px_ - 4, py_ - 1, px_ - 1, py_ - 2, Color("a8dfe8"))
		cv.px(px_ + 2, py_ + 1, Color("a8dfe8"))
		for i in 3:
			cv.px(px_ + rng.randi_range(-8, 8), py_ + rng.randi_range(-5, 5), Color("2f8a4a"))
	elif v == 11:
		var rx2 := rng.randf_range(2.0, 8.0)
		for k in 3:
			cv.line(rx2, 0, rx2 + rng.randf_range(4.0, 14.0), 12 + k * 8, Color("5a3d20"), 2.0)
			cv.line(rx2, 0, rx2 + rng.randf_range(4.0, 14.0), 12 + k * 8, Color("7d5a34"))
	elif v == 12:
		for i in 14:
			var lx2 := rng.randi_range(3, 28)
			var ly2 := rng.randi_range(3, 28)
			var lc: Color = [Color("c9772a"), Color("b8452a"), Color("d9a63a")][rng.randi() % 3]
			cv.rect(lx2, ly2, 2, 2, lc)
			cv.px(lx2 + 2, ly2 + 1, lc.darkened(0.3))
	elif v == 13:
		for k in 4:
			var cx3 := px_ + rng.randi_range(-7, 7)
			var cy3 := py_ + rng.randi_range(-5, 5)
			for d in [Vector2i(0, 0), Vector2i(-2, 1), Vector2i(2, 1)]:
				cv.disc(cx3 + d.x, cy3 + d.y, 1.8, Color("2f9a4a"))
			cv.px(cx3, cy3, Color("8fe89a"))
	elif v == 14:
		for k in 5:
			var rx3 := 4 + k * 5 + rng.randi_range(-1, 1)
			var rh := rng.randi_range(8, 14)
			cv.line(rx3, 29, rx3 + rng.randi_range(-2, 2), 29 - rh, Color("5fa84a"))
			cv.px(rx3, 29 - rh, Color("a06a3a"))
			cv.px(rx3, 28 - rh, Color("6a4a2a"))
	else:
		var fx2 := px_
		var fy2 := py_ + 4
		for k in 5:
			var a := -PI / 2.0 + (k - 2) * 0.55
			var p2 := Vector2(fx2 + cos(a) * 9.0, fy2 + sin(a) * 9.0)
			cv.line(fx2, fy2, p2.x, p2.y, Color("2f8a3a"))
			for j in 4:
				var q := Vector2(fx2, fy2).lerp(p2, (j + 1) / 5.0)
				cv.px(int(q.x) + 1, int(q.y), Color("5fc06a"))
				cv.px(int(q.x) - 1, int(q.y), Color("5fc06a"))


func _floor3(cv: Cv, base: Color, rng: RandomNumberGenerator, v: int) -> void:
	var dk := base.darkened(0.4)
	for i in rng.randi_range(2, 4):
		var sx := rng.randi_range(2, 28)
		var sy := rng.randi_range(2, 28)
		cv.line(sx, sy, sx + rng.randi_range(-8, 8), sy + rng.randi_range(-8, 8), dk)
	for i in 32:
		cv.px(i, 0, dk)
		cv.px(0, i, dk)
		cv.px(i, 31, base.darkened(0.15))
		cv.px(31, i, base.darkened(0.15))
	if v == 3:
		cv.poly([Vector2(4, 28), Vector2(8, 22), Vector2(12, 28)], base.lightened(0.1))
	elif v == 6 or v == 7:
		var ox := rng.randi_range(8, 22)
		var oy := rng.randi_range(14, 26)
		cv.poly([Vector2(ox - 3, oy), Vector2(ox - 1, oy - 9), Vector2(ox + 1, oy)], Color("a070ff"))
		cv.poly([Vector2(ox, oy), Vector2(ox + 2, oy - 12), Vector2(ox + 5, oy)], Color("d0a8ff"))
		cv.poly([Vector2(ox + 4, oy), Vector2(ox + 6, oy - 6), Vector2(ox + 8, oy)], Color("7fe8ff"))
		cv.px(ox + 2, oy - 11, Color.WHITE)
	elif v == 8 or v == 9:
		var vy := rng.randi_range(6, 24)
		cv.line(0, vy, 31, vy + rng.randi_range(-6, 6), Color("7fe8ff").darkened(0.3))
		cv.line(0, vy + 1, 31, vy + 1 + rng.randi_range(-6, 6), Color("d58cff").darkened(0.2))
	elif v == 10 or v == 11:
		var ox2 := rng.randf_range(11.0, 21.0)
		var oy2 := rng.randf_range(11.0, 21.0)
		cv.ell(ox2, oy2, 7.0, 4.5, base.darkened(0.5))
		cv.ell(ox2 - 1.0, oy2 - 1.0, 4.0, 2.5, Color("5a3aa0"))
		cv.px(int(ox2) - 2, int(oy2) - 2, Color("ffd0ff"))
	elif v >= 12:
		for k in 5:
			var gx := rng.randi_range(3, 28)
			var gy := rng.randi_range(3, 28)
			cv.px(gx, gy, Color("d0a8ff"))
			cv.px(gx + 1, gy, Color("7fe8ff"))


func _floor2(cv: Cv, base: Color, rng: RandomNumberGenerator, v: int) -> void:
	for y in [0, 16]:
		cv.rect(0, y, 32, 1, base.darkened(0.45))
		cv.rect(0, y + 1, 32, 1, base.lightened(0.1))
	var seam := 6 + (v % 5) * 4
	cv.rect(seam, 1, 1, 15, base.darkened(0.45))
	cv.rect(seam + 1, 1, 1, 15, base.lightened(0.08))
	cv.rect((seam + 14) % 30 + 1, 17, 1, 15, base.darkened(0.45))
	cv.rect((seam + 15) % 30 + 2, 17, 1, 15, base.lightened(0.08))
	for p in [Vector2i(3, 4), Vector2i(28, 4), Vector2i(3, 21), Vector2i(28, 21)]:
		if rng.randf() < 0.8:
			cv.px(p.x, p.y, base.lightened(0.45))
			cv.px(p.x + 1, p.y + 1, base.darkened(0.4))
	for i in 8:
		var sx := rng.randi_range(2, 28)
		var sy := rng.randi_range(0, 1) * 16 + rng.randi_range(3, 13)
		cv.line(sx, sy, sx + 3, sy, base.darkened(0.2))
	if v < 6:
		for i in rng.randi_range(1, 4):
			var sx2 := rng.randi_range(4, 26)
			var sy2 := rng.randi_range(4, 27)
			cv.line(sx2, sy2, sx2 + rng.randi_range(2, 5), sy2 + rng.randi_range(-3, 3), base.darkened(0.25) if rng.randf() < 0.5 else base.lightened(0.14))
		return
	var px_ := rng.randi_range(8, 22)
	var py_ := rng.randi_range(8, 22)
	if v == 6:
		cv.rect(px_ - 5, py_ - 4, 10, 8, Color("6a4a26"))
		cv.rect(px_ - 5, py_ - 4, 10, 1, Color("9a7440"))
		cv.rect(px_ - 5, py_ + 3, 10, 1, Color("3a2814"))
		cv.line(px_ - 4, py_ - 3, px_ + 4, py_ + 3, Color("3a2814"))
		cv.line(px_ + 4, py_ - 3, px_ - 4, py_ + 3, Color("3a2814"))
	elif v == 7:
		cv.ell(px_, py_, 8.0, 5.0, base.darkened(0.55))
		cv.ell(px_ - 1, py_ - 1, 5.0, 3.0, base.darkened(0.7))
		cv.px(px_ - 3, py_ - 2, Color("8a6ad8"))
	elif v == 8:
		for i in 26:
			var rx := px_ + rng.randi_range(-9, 9)
			var ry := py_ + rng.randi_range(-7, 7)
			cv.px(rx, ry, Color("8a4a2a") if rng.randf() < 0.7 else Color("b8683a"))
	elif v == 9:
		var chy := py_
		for k in 7:
			var lx := 3 + k * 4
			cv.ell(lx, chy + (k % 2), 2.2, 1.6 if k % 2 == 0 else 2.2, Color("8a93b5"))
			cv.ell(lx, chy + (k % 2), 1.0, 0.7, base.darkened(0.5))
		cv.line(3, chy + 3, 28, chy + 3, base.darkened(0.35))
	elif v == 10:
		cv.rect(px_ - 7, py_ - 5, 14, 10, base.darkened(0.45))
		cv.rect(px_ - 6, py_ - 4, 12, 8, Color("c9a23a"))
		cv.glyph(["111", "001", "010", "010", "010"], px_ - 2, py_ - 2, Color("14141c"))
	elif v == 11:
		for i in 6:
			var ax := rng.randi_range(3, 24)
			var ay := rng.randi_range(3, 28)
			cv.line(ax, ay, ax + rng.randi_range(4, 8), ay + rng.randi_range(-3, 3), base.lightened(0.3))
			cv.line(ax, ay + 1, ax + rng.randi_range(4, 8), ay + rng.randi_range(-2, 4), base.darkened(0.4))
	elif v == 12:
		cv.poly([Vector2(px_ - 7, py_ - 4), Vector2(px_ + 6, py_ - 5), Vector2(px_ + 8, py_ + 3), Vector2(px_ - 5, py_ + 5)], Color("4a5a78"))
		cv.line(px_ - 7, py_ - 4, px_ + 6, py_ - 5, Color("7a8aa8"))
		cv.line(px_ - 3, py_ - 3, px_ - 4, py_ + 4, Color("3a4a68"))
		cv.px(px_ + 4, py_ + 2, Color("ffd84f"))
	elif v == 13:
		for i in 6:
			var gx := px_ + rng.randi_range(-8, 8)
			var gy := py_ + rng.randi_range(-6, 6)
			cv.disc(gx, gy, 1.6, Color("e0a01a"))
			cv.px(gx - 1, gy - 1, Color("fff3b0"))
	elif v == 14:
		cv.ell(px_, py_ - 2, 3.5, 3.0, Color("e8e2cf"))
		cv.rect(px_ - 2, py_ + 1, 5, 2, Color("e8e2cf"))
		cv.px(px_ - 1, py_ - 2, Color("14141c"))
		cv.px(px_ + 1, py_ - 2, Color("14141c"))
		cv.line(px_ - 7, py_ + 5, px_ + 7, py_ + 7, Color("e8e2cf"))
	else:
		cv.disc(16, 16, 8.0, base.darkened(0.5))
		cv.disc(16, 16, 6.5, base.darkened(0.25))
		for k in range(-4, 5, 2):
			cv.rect(12, 16 + k, 9, 1, base.darkened(0.6))
		cv.rect(11, 11, 10, 1, base.lightened(0.2))


func wall_tile(ti: int) -> ImageTexture:
	var key := "wall%d" % ti
	if cache.has(key):
		return cache[key]
	var art_w: ImageTexture = _atlas_cell("res://art/tile_atlas.png", ti, 8)
	if art_w != null:
		cache[key] = art_w
		return art_w
	var base: Color = themes[ti]["wall"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 555 + ti
	var cv := Cv.new(32, 32)
	cv.rect(0, 0, 32, 32, base)
	if ti == 0:
		for i in 32:
			for e in [0, 31]:
				cv.px(i, e, base.darkened(0.65))
				cv.px(e, i, base.darkened(0.65))
			cv.px(i, 1, base.lightened(0.3))
			cv.px(1, i, base.lightened(0.18))
			cv.px(i, 2, base.lightened(0.1))
			cv.px(i, 30, base.darkened(0.35))
			cv.px(30, i, base.darkened(0.35))
		cv.rect(4, 5, 24, 14, base.darkened(0.25))
		cv.rect(4, 5, 24, 1, base.darkened(0.6))
		cv.rect(4, 18, 24, 1, base.lightened(0.2))
		for x in range(6, 26, 3):
			cv.rect(x, 8, 2, 8, base.darkened(0.55))
			cv.rect(x + 1, 8, 1, 8, base.lightened(0.1))
		for p in [Vector2i(3, 3), Vector2i(27, 3), Vector2i(3, 27), Vector2i(27, 27)]:
			cv.disc(p.x + 1, p.y + 1, 1.8, base.lightened(0.45))
			cv.px(p.x + 1, p.y + 1, Color.WHITE)
		for x in range(3, 29):
			if (x / 3) % 2 == 0:
				cv.rect(x, 22, 1, 4, Color("d9b020"))
			else:
				cv.rect(x, 22, 1, 4, Color("20242c"))
		cv.px(16, 12, Color("ff5d5d"))
	elif ti == 1:
		var g1 := base.darkened(0.5)
		var g3 := base.lightened(0.3)
		for y in 32:
			for x in 32:
				var v := sin(x * 0.55 + rng.randf() * 0.8) + cos(y * 0.5 + rng.randf() * 0.8) + rng.randf() * 0.9
				var c := base
				if v < -0.5:
					c = g1
				elif v > 1.15:
					c = g3
				cv.px(x, y, c)
		for i in 32:
			if rng.randf() < 0.7:
				cv.px(i, 0, g1)
				cv.px(i, 1, g1.lightened(0.05))
			if rng.randf() < 0.7:
				cv.px(i, 31, g1)
			if rng.randf() < 0.7:
				cv.px(0, i, g1)
			if rng.randf() < 0.7:
				cv.px(31, i, g1)
		for i in 5:
			var vx := rng.randi_range(4, 27)
			var vy := rng.randi_range(4, 27)
			cv.line(vx, vy, vx + rng.randi_range(-4, 4), vy + rng.randi_range(4, 8), base.darkened(0.6))
		for i in 4:
			var fx := rng.randi_range(4, 27)
			var fy := rng.randi_range(4, 27)
			cv.disc(fx, fy, 1.6, Color("ff5c7a"))
			cv.px(fx, fy, Color("ffd0da"))
	elif ti == 3:
		for i in 32:
			for e in [0, 31]:
				cv.px(i, e, base.darkened(0.7))
				cv.px(e, i, base.darkened(0.7))
			cv.px(i, 1, base.lightened(0.2))
			cv.px(1, i, base.lightened(0.2))
		for k in 6:
			var cx := 4 + k * 5
			var ch := rng.randi_range(8, 20)
			cv.poly([Vector2(cx, 29), Vector2(cx + 2, 29 - ch), Vector2(cx + 5, 29)], base.lightened(0.1 + 0.08 * (k % 3)))
			cv.line(cx + 2, 29 - ch, cx + 2, 28, base.lightened(0.45))
		cv.rect(2, 29, 28, 2, base.darkened(0.45))
		for i in 8:
			cv.px(rng.randi_range(3, 28), rng.randi_range(3, 26), Color("ffd0ff"))
	else:
		for i in 32:
			for e in [0, 31]:
				cv.px(i, e, base.darkened(0.65))
				cv.px(e, i, base.darkened(0.65))
			cv.px(i, 1, base.lightened(0.22))
			cv.px(1, i, base.lightened(0.22))
		for i in range(3, 29):
			cv.px(i, i, base.darkened(0.4))
			cv.px(i + 1, i, base.darkened(0.25))
			cv.px(31 - i, i, base.darkened(0.4))
			cv.px(30 - i, i, base.darkened(0.25))
		cv.rect(12, 12, 8, 8, base.lightened(0.12))
		cv.rect(12, 12, 8, 1, base.lightened(0.4))
		cv.rect(12, 19, 8, 1, base.darkened(0.5))
		cv.rect(14, 14, 4, 4, base.darkened(0.5))
		for p in [Vector2i(3, 3), Vector2i(27, 3), Vector2i(3, 27), Vector2i(27, 27)]:
			cv.disc(p.x + 1, p.y + 1, 1.8, base.lightened(0.6))
			cv.px(p.x + 1, p.y + 1, Color.WHITE)
		for i in 24:
			cv.px(rng.randi_range(3, 28), rng.randi_range(3, 28), base.lightened(0.1))
		cv.rect(2, 28, 10, 2, Color("8a5a2a"))
	cv.img.fix_alpha_edges()
	var t := cv.tex()
	cache[key] = t
	return t


# ---------------------------------------------------------------- monsters

func monster(ti: int, lvl: int, boss: bool, blink: bool = false, dir: int = 0) -> ImageTexture:
	var key := "m%d_%d_%d_%d_%d" % [ti, lvl, 1 if boss else 0, 1 if blink else 0, dir]
	if cache.has(key):
		return cache[key]
	var art_idx := 9 if boss else (lvl - 1) % 9
	var art_t: ImageTexture = _atlas_cell("res://art/mon_atlas64.png", dir * 2 + (1 if blink else 0), ti * 10 + art_idx, 64)
	if art_t != null and art_t.get_image().is_invisible():
		art_t = null  # empty cell in the 64px atlas: fall back to the old 32px art
	if art_t == null:
		art_t = _atlas_cell("res://art/mon_atlas.png", dir * 2 + (1 if blink else 0), ti * 10 + art_idx)
	if art_t != null:
		cache[key] = art_t
		return art_t
	var cols: Array = themes[ti]["mcols"]
	var skin: Color = cols[(lvl - 1) % cols.size()]
	var rng := RandomNumberGenerator.new()
	rng.seed = ti * 7919 + lvl * 104729 + (13 if boss else 0)
	var cv := Cv.new(32, 32)
	var skin_dk := skin.darkened(0.35)
	var skin_lt := skin.lightened(0.35)
	var outfits := [
		[Color("3f5f8f"), Color("7a8296"), Color("8a3f3f"), Color("4a4f68")],
		[Color("3f7a3f"), Color("6a4f2a"), Color("2f6a5a"), Color("7a6a2a")],
		[Color("6a3a2a"), Color("3a3a4a"), Color("7a2f3f"), Color("4a4a2a")],
		[Color("4a3a8a"), Color("6a5ab0"), Color("2a4a7a"), Color("5a2a6a")],
	]
	var cloth: Color = (outfits[ti] as Array)[rng.randi() % 4]
	if absf(cloth.h - skin.h) < 0.05 and absf(cloth.v - skin.v) < 0.25:
		cloth = cloth.darkened(0.35)
	var cloth_dk := cloth.darkened(0.35)
	var cloth_lt := cloth.lightened(0.3)
	var metal := Color("8a93b5")
	var bulk := 1.0 if not boss else 1.25
	var hs := rng.randi() % 4
	var hcy := 8.5
	var hrx := 6.2
	var hry := 6.0
	if hs == 1:
		hrx = 5.2
		hry = 7.2
	elif hs == 2:
		hrx = 7.0
		hry = 5.2
		hcy = 9.0
	elif hs == 3:
		hrx = 5.8
		hry = 6.4
	if boss:
		hrx += 0.6
		hry += 0.4
	var shoulder := 6.0 * bulk
	var tw := 6.0 * bulk
	# --- legs and feet
	var stance := rng.randi() % 2
	cv.rrect(11 - (1 if boss else 0), 21, 5, 9, 1.5, cloth_dk)
	cv.rrect(16 + (1 if boss else 0), 21, 5, 9, 1.5, cloth_dk)
	cv.rrect(10 - (1 if boss else 0), 27, 7, 4, 1.5, Color("2a2a38"))
	cv.rrect(15 + (1 if boss else 0), 27, 7, 4, 1.5, Color("2a2a38"))
	if stance == 1:
		cv.rect(11, 24, 5, 1, cloth)
		cv.rect(16, 24, 5, 1, cloth)
	# --- arms
	var arm_c := skin if ti != 0 or rng.randf() < 0.5 else cloth
	cv.rrect(int(16.0 - shoulder) - 3, 13, 4, 10, 1.8, arm_c)
	cv.rrect(int(16.0 + shoulder) - 1, 13, 4, 10, 1.8, arm_c)
	cv.disc(int(16.0 - shoulder) - 1, 24, 2.2, skin)
	cv.disc(int(16.0 + shoulder) + 1, 24, 2.2, skin)
	# --- torso
	cv.rrect(int(16.0 - tw), 12, int(tw * 2.0), 12, 3.0, cloth)
	cv.ell(16.0 - shoulder + 1.0, 14.0, 3.4 * bulk, 2.8 * bulk, cloth_lt if ti != 1 else skin_dk)
	cv.ell(16.0 + shoulder - 1.0, 14.0, 3.4 * bulk, 2.8 * bulk, cloth_lt if ti != 1 else skin_dk)
	# --- neck + ears + head
	cv.rect(14, 11, 4, 3, skin_dk)
	var ears := rng.randi() % 3
	if ears == 1:
		cv.poly([Vector2(16 - hrx + 1, hcy), Vector2(16 - hrx - 4, hcy - 4), Vector2(16 - hrx + 1.5, hcy - 2.5)], skin)
		cv.poly([Vector2(16 + hrx - 1, hcy), Vector2(16 + hrx + 4, hcy - 4), Vector2(16 + hrx - 1.5, hcy - 2.5)], skin)
	elif ears == 2:
		cv.ell(16 - hrx, hcy, 2.0, 3.0, skin_dk)
		cv.ell(16 + hrx, hcy, 2.0, 3.0, skin_dk)
	if hs == 3:
		cv.rrect(int(16 - hrx), int(hcy - hry), int(hrx * 2), int(hry * 2), 4.0, skin)
	else:
		cv.ell(16, hcy, hrx, hry, skin)
	# crest / horns / antennae behind the face
	var top := rng.randi() % 5
	if boss:
		top = 1
	var topy := hcy - hry
	if top == 1:
		for k in 2:
			var sgn := -1.0 if k == 0 else 1.0
			cv.poly([Vector2(16 + sgn * 2.5, topy + 1.5), Vector2(16 + sgn * 5.5, topy + 2.5), Vector2(16 + sgn * 6.5, topy - 5.5)], Color("ece3c8"))
	elif top == 2:
		for k in 3:
			var sx := 16.0 + (k - 1) * 3.2
			cv.poly([Vector2(sx - 1.6, topy + 2), Vector2(sx + 1.6, topy + 2), Vector2(sx, topy - 3.5 - (1.5 if k == 1 else 0.0))], skin_lt)
	elif top == 3:
		for k in 2:
			var sgn2 := -1.0 if k == 0 else 1.0
			cv.line(16 + sgn2 * 2.0, topy + 1, 16 + sgn2 * 5.0, topy - 4, skin_dk)
			cv.disc(16 + sgn2 * 5.0, topy - 4.5, 1.6, Color("fff27a"))
	elif top == 4:
		for k in 5:
			var hx := 16.0 + (k - 2) * 2.6
			cv.line(hx, topy + 2, hx + (k - 2) * 1.4, topy - 2.5 + abs(k - 2) * 1.0, skin_dk, 2.0)
	cv.shade(0.3)
	# --- details (after shading so they stay crisp)
	var real_cv: Cv = cv
	if dir != 0:
		cv = Cv.new(32, 32)
	var ey := hcy - 0.8
	var etype := rng.randi() % 4
	var glow := Color("ff4a4a") if boss else Color("fffbe6")
	var pupil := Color("14141c")
	var blink_c := skin.darkened(0.05)
	var eyes: Array = []
	if etype == 0:
		eyes = [Vector3(13.2, ey, 2.0), Vector3(18.8, ey, 2.0)]
	elif etype == 1:
		eyes = [Vector3(12.6, ey + 0.8, 1.8), Vector3(19.4, ey + 0.8, 1.8), Vector3(16.0, ey - 2.8, 1.5)]
	elif etype == 2:
		eyes = [Vector3(16.0, ey, 3.2)]
	else:
		eyes = [Vector3(12.8, ey - 1.6, 1.4), Vector3(19.2, ey - 1.6, 1.4), Vector3(13.6, ey + 1.8, 1.4), Vector3(18.4, ey + 1.8, 1.4)]
	for e in eyes:
		var ex: float = e.x
		var eyy: float = e.y
		var er: float = e.z
		if blink:
			cv.ell(ex, eyy, er + 0.8, er + 0.8, skin)
			cv.line(ex - er, eyy + 0.5, ex + er, eyy + 0.5, pupil)
		else:
			cv.ell(ex, eyy, er + 0.9, er + 1.1, pupil)
			cv.ell(ex, eyy, er, er + 0.2, glow)
			cv.disc(ex + (0.3 if ex < 16 else -0.3), eyy + 0.5, maxf(0.9, er * 0.55), pupil if not boss else Color("7a0a0a"))
			cv.px(int(ex - er * 0.4), int(eyy - er * 0.5), Color.WHITE)
	# brow
	if etype != 2:
		cv.line(11, ey - 3.2, 15, ey - 2.2, skin_dk.darkened(0.3), 1.5)
		cv.line(17, ey - 2.2, 21, ey - 3.2, skin_dk.darkened(0.3), 1.5)
	else:
		cv.line(12.5, ey - 4.6, 19.5, ey - 4.6, skin_dk.darkened(0.3), 1.5)
	# nose slits
	cv.px(15, int(hcy + 1.5), skin_dk.darkened(0.3))
	cv.px(17, int(hcy + 1.5), skin_dk.darkened(0.3))
	# mouth
	var my := hcy + hry * 0.55
	var mt := rng.randi() % 4
	if mt == 0:
		cv.rect(13, int(my), 6, 2, Color("2a0f18"))
		cv.px(13, int(my) + 2, Color("f6efd6"))
		cv.px(18, int(my) + 2, Color("f6efd6"))
		cv.px(14, int(my), Color("f6efd6"))
		cv.px(17, int(my), Color("f6efd6"))
	elif mt == 1:
		cv.rect(12, int(my), 8, 3, Color("2a0f18"))
		for k in range(12, 20, 2):
			cv.px(k, int(my), Color("f6efd6"))
		cv.px(13, int(my) + 2, Color("f6efd6"))
		cv.px(18, int(my) + 2, Color("f6efd6"))
	elif mt == 2:
		cv.line(12, my, 15, my + 2, skin_dk.darkened(0.4), 1.5)
		cv.line(20, my, 17, my + 2, skin_dk.darkened(0.4), 1.5)
		cv.line(15, my + 2, 17, my + 2, Color("2a0f18"))
	else:
		cv.rect(14, int(my), 4, 2, Color("2a0f18"))
		for k in 3:
			var tx := 13.5 + k * 2.5
			cv.line(tx, my + 2, tx + (k - 1) * 0.8, my + 5.5, skin_dk, 1.4)
	cv = real_cv
	if dir == 1:
		cv.line(12, hcy - 1, 20, hcy - 1, skin_dk)
		cv.line(13, hcy + 2, 19, hcy + 2, skin_dk)
		cv.rect(14, int(hcy) - 4, 4, 2, skin_lt)
	# --- outfit details per theme
	if ti == 0:
		cv.rect(int(16 - tw), 19, int(tw * 2), 2, cloth_dk)
		cv.rect(15, 19, 2, 2, Color("ffd84f"))
		cv.rect(int(16 - tw) + 2, 14, 4, 3, Color("e8e2d0"))
		cv.px(int(16 - tw) + 3, 15, Color("c93b3b"))
		cv.line(14, 12, 16, 15, cloth_lt)
		cv.line(18, 12, 16, 15, cloth_lt)
		if rng.randf() < 0.6:
			cv.poly([Vector2(16 + tw - 3, 21), Vector2(16 + tw, 20), Vector2(16 + tw - 1, 24), Vector2(16 + tw - 3, 23)], arm_c)
	elif ti == 1:
		for k in 4:
			var lx := 16.0 - tw + 2 + k * 3.0
			cv.poly([Vector2(lx, 16), Vector2(lx + 2.5, 14), Vector2(lx + 1.5, 19)], Color("5fc06a"))
		cv.line(16 - tw - 2, 15, 16 - tw - 2, 22, Color("2f7a3a"))
		cv.line(16 + tw + 2, 15, 16 + tw + 2, 22, Color("2f7a3a"))
		cv.rect(int(16 - tw), 20, int(tw * 2), 2, Color("6a4f2a"))
		cv.px(15, 20, Color("ffe066"))
		for k in 3:
			var lh := 16.0 + (k - 1) * 3.6
			cv.poly([Vector2(lh - 1.5, topy + 3), Vector2(lh + 1.5, topy + 3), Vector2(lh, topy - 2.5 - (k % 2))], Color("5fc06a"))
	elif ti == 3:
		for k in 2:
			var sg := -1.0 if k == 0 else 1.0
			var sx3 := 16.0 + sg * (tw - 1.0)
			cv.poly([Vector2(sx3 - 2.0, 14), Vector2(sx3 + 2.0, 14), Vector2(sx3 + sg * 1.0, 6.5)], Color("c9a0ff"))
			cv.poly([Vector2(sx3 - 1.0, 14), Vector2(sx3 + 1.0, 14), Vector2(sx3, 9)], Color("f0e0ff"))
		cv.poly([Vector2(16, 14), Vector2(18.5, 17.5), Vector2(16, 21), Vector2(13.5, 17.5)], Color("7fe8ff"))
		cv.poly([Vector2(16, 14), Vector2(16.8, 17.5), Vector2(16, 21), Vector2(13.5, 17.5)], Color("d6fbff"))
		cv.rect(int(16 - tw), 22, int(tw * 2), 1, cloth_lt)
	else:
		cv.line(16 - tw + 1, 12, 16 + tw - 1, 22, Color("4a3220"), 2.0)
		cv.rect(int(16 - tw), 20, int(tw * 2), 2, Color("3a2814"))
		cv.rect(15, 20, 3, 2, Color("ffd84f"))
		cv.rect(int(16 - hrx) + 1, int(topy) + 2, int(hrx * 2) - 2, 3, Color("b83a2c"))
		cv.line(16 + hrx - 2, topy + 3, 16 + hrx + 3, topy + 6, Color("b83a2c"), 1.5)
		if rng.randf() < 0.5 and etype != 2:
			cv.disc(19.0, ey, 2.4, Color("14141c"))
			cv.line(14, topy + 4, 24, ey + 5, Color("14141c"))
	# --- held item on the right hand
	var wep := rng.randi() % 4
	var hxw := 16.0 + shoulder + 1.0
	if wep == 0:
		cv.line(hxw, 24, hxw + 2, 6, Color("d3d9e8"), 2.0)
		cv.line(hxw - 1, 24, hxw + 1, 6, Color("f4f7ff"))
		cv.rect(int(hxw) - 2, 23, 5, 2, Color("8a5a2a"))
	elif wep == 1:
		cv.line(hxw, 25, hxw + 1, 10, Color("8a5a2a"), 2.5)
		cv.ell(hxw + 1, 9, 3.0, 3.4, Color("6a6f80"))
		cv.px(int(hxw), 8, Color("a8aec0"))
	elif wep == 2:
		for k in 3:
			cv.line(hxw + (k - 1) * 1.6, 24, hxw + (k - 1) * 2.2, 19, Color("ece3c8"))
	else:
		cv.rect(int(hxw) - 1, 23, 5, 3, Color("39415f"))
		cv.rect(int(hxw) + 3, 23, 3, 1, Color("39415f"))
		cv.px(int(hxw) + 2, 23, Color("4fd1ff"))
	# --- boss extras
	if boss and ti == 3:
		var cy3 := int(topy) - 1
		for k in 5:
			var kx := 9.0 + k * 3.5
			cv.poly([Vector2(kx - 1.8, cy3 + 4), Vector2(kx + 1.8, cy3 + 4), Vector2(kx, cy3 - 4 - (3 if k == 2 else 0))], Color("d58cff") if k % 2 == 0 else Color("7fe8ff"))
		cv.rect(4, 13, 24, 2, Color("6a3aa0"))
		cv.px(8, 13, Color("7fe8ff"))
		cv.px(23, 13, Color("ff8ad0"))
	elif boss:
		var cy0 := int(topy) - 1
		cv.poly([Vector2(9, cy0 + 4), Vector2(9, cy0 - 3), Vector2(12.5, cy0 + 1), Vector2(16, cy0 - 5), Vector2(19.5, cy0 + 1), Vector2(23, cy0 - 3), Vector2(23, cy0 + 4)], Color("ffc93c"))
		cv.rect(9, cy0 + 3, 14, 2, Color("c98a12"))
		cv.px(16, cy0 - 1, Color("ff5252"))
		cv.px(12, cy0 + 2, Color("4fd1ff"))
		cv.px(20, cy0 + 2, Color("4fd1ff"))
		cv.rect(4, 13, 24, 2, Color("c93b3b"))
		cv.px(8, 13, Color("ffd84f"))
		cv.px(23, 13, Color("ffd84f"))
	if dir >= 2:
		var side_src: Image = cv.img.duplicate()
		side_src.resize(22, 32, Image.INTERPOLATE_NEAREST)
		cv.img.fill(Color(0, 0, 0, 0))
		cv.img.blend_rect(side_src, Rect2i(0, 0, 22, 32), Vector2i(5, 0))
		var fx0 := 16.0 + hrx * 0.3
		if blink:
			cv.line(fx0 - 1.5, ey + 0.5, fx0 + 1.5, ey + 0.5, pupil)
		else:
			cv.ell(fx0, ey, 1.8, 2.1, pupil)
			cv.ell(fx0, ey, 1.3, 1.6, glow)
			cv.disc(fx0 + 0.4, ey + 0.4, 0.8, pupil if not boss else Color("7a0a0a"))
			cv.px(int(fx0 - 0.4), int(ey - 0.8), Color.WHITE)
			if etype != 2:
				cv.ell(fx0 - 3.2, ey + 0.3, 1.2, 1.5, pupil)
				cv.ell(fx0 - 3.2, ey + 0.3, 0.8, 1.1, glow)
		cv.line(fx0 - 1.5, ey - 3.0, fx0 + 2.0, ey - 2.2, skin_dk.darkened(0.3), 1.5)
		cv.px(int(16.0 + hrx * 0.69) - 1, int(hcy + 1.5), skin_dk.darkened(0.3))
		cv.rect(int(fx0) - 1, int(my), 4, 2, Color("2a0f18"))
		cv.px(int(fx0), int(my), Color("f6efd6"))
	cv.outline(skin.darkened(0.85))
	cv.img.fix_alpha_edges()
	if dir == 2:
		cv.img.flip_x()
	var t := cv.tex()
	cache[key] = t
	return t


func white(tex: ImageTexture) -> ImageTexture:
	var key := "white_%d" % tex.get_instance_id()
	if cache.has(key):
		return cache[key]
	var img := tex.get_image().duplicate() as Image
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				img.set_pixel(x, y, Color(1, 1, 1, c.a))
	var t := ImageTexture.create_from_image(img)
	cache[key] = t
	return t

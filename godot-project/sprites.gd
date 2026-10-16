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

	func tex() -> ImageTexture:
		return ImageTexture.create_from_image(img)


func _init(th: Array) -> void:
	themes = th


func _text(cv: Cv, s: String, x: int, y: int, c: Color) -> void:
	var cx := x
	for ch in s:
		if FONT3.has(ch):
			cv.glyph(FONT3[ch], cx, y, c)
		cx += 4


# ---------------------------------------------------------------- player

func player(accent: Color, cls: String, frame: int = 0) -> ImageTexture:
	var key := "player_%s_%d" % [cls, frame]
	if cache.has(key):
		return cache[key]
	var cv := Cv.new(32, 32)
	var suit := Color("e6ebf8")
	var suit_d := Color("a9b3d1")
	var dark := Color("2b3254")
	var metal := Color("69759a")
	if cls == "mystic":
		cv.poly([Vector2(9, 13), Vector2(23, 13), Vector2(28, 29), Vector2(4, 29)], accent.darkened(0.45))
	cv.rrect(7, 12, 18, 11, 2.0, metal)
	cv.rrect(4, 14, 4, 8, 1.5, dark)
	cv.rrect(24, 14, 4, 8, 1.5, dark)
	var dl := -3 if frame == 1 else 0
	var dr := -3 if frame == 2 else 0
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
	# visor
	cv.ell(16, 9, 5.8, 4.6, dark)
	cv.ell(16, 9, 5.0, 3.8, accent.darkened(0.5))
	cv.ell(16, 8.6, 5.0, 3.0, accent)
	cv.ell(14.5, 7.4, 2.6, 1.0, accent.lightened(0.6))
	cv.px(19, 10, accent.lightened(0.7))
	# suit details
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
	# arm swing opposite to the raised leg
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
	elif cls == "gambler":
		cv.rect(9, 5, 14, 2, Color("ffd84f"))
		cv.rect(9, 5, 14, 1, Color("fff1a0"))
		cv.rect(14, 15, 5, 5, Color.WHITE)
		cv.px(15, 16, Color("14141c"))
		cv.px(17, 18, Color("14141c"))
		cv.px(17, 16, Color("14141c"))
		cv.px(15, 18, Color("14141c"))
	cv.outline(Color("0a0d1a"))
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
	else:
		cv.disc(16, 16, 9, Color("c9d3f0"))
		cv.outline(ol)


# ---------------------------------------------------------------- tiles

func floor_tile(ti: int, parity: int, variant: int) -> ImageTexture:
	var key := "floor%d_%d_%d" % [ti, parity, variant]
	if cache.has(key):
		return cache[key]
	var base: Color = themes[ti]["tile"] if parity == 0 else themes[ti]["tile2"]
	var rng := RandomNumberGenerator.new()
	rng.seed = ti * 100 + parity * 10 + variant + 7
	var cv := Cv.new(32, 32)
	cv.rect(0, 0, 32, 32, base)
	# subtle noise
	for i in 90:
		var x := rng.randi_range(0, 31)
		var y := rng.randi_range(0, 31)
		cv.px(x, y, base.lightened(0.05) if rng.randf() < 0.5 else base.darkened(0.07))
	if ti == 0:
		for i in 32:
			cv.px(i, 0, base.darkened(0.4))
			cv.px(0, i, base.darkened(0.4))
			cv.px(i, 1, base.lightened(0.12))
			cv.px(1, i, base.lightened(0.12))
			cv.px(i, 31, base.darkened(0.18))
			cv.px(31, i, base.darkened(0.18))
		for p in [Vector2i(4, 4), Vector2i(26, 4), Vector2i(4, 26), Vector2i(26, 26)]:
			cv.disc(p.x + 1, p.y + 1, 2.0, base.darkened(0.3))
			cv.disc(p.x + 0.5, p.y + 0.5, 1.5, base.lightened(0.18))
			cv.px(p.x, p.y, base.lightened(0.5))
		if variant == 1:
			cv.rect(8, 9, 16, 14, base.darkened(0.45))
			for x in range(9, 23, 2):
				cv.rect(x, 10, 1, 12, base.darkened(0.15))
			cv.rect(8, 9, 16, 1, base.darkened(0.7))
			cv.rect(8, 23, 16, 1, base.lightened(0.15))
		elif variant == 2:
			for x in range(0, 32, 6):
				cv.poly([Vector2(x, 26), Vector2(x + 3, 26), Vector2(x + 6, 30), Vector2(x + 3, 30)], Color("d9a81e"))
			cv.rect(0, 25, 32, 1, base.darkened(0.5))
			cv.rect(0, 30, 32, 1, base.darkened(0.5))
		else:
			cv.line(10, 14, 16, 18, base.darkened(0.3))
			cv.line(16, 18, 15, 24, base.darkened(0.3))
			cv.px(11, 14, base.lightened(0.15))
	elif ti == 1:
		for i in 34:
			var gx := rng.randi_range(1, 30)
			var gy := rng.randi_range(3, 30)
			cv.px(gx, gy, base.lightened(0.28))
			cv.px(gx, gy - 1, base.lightened(0.5))
			cv.px(gx - 1, gy - 2, base.lightened(0.4))
			cv.px(gx + 1, gy - 2, base.lightened(0.3))
		for i in 22:
			cv.px(rng.randi_range(0, 31), rng.randi_range(0, 31), base.darkened(0.28))
		if variant == 1:
			for i in 3:
				var sx := rng.randi_range(6, 24)
				var sy := rng.randi_range(6, 24)
				cv.disc(sx, sy, 2.5, base.darkened(0.3))
				cv.disc(sx - 0.5, sy - 0.5, 1.5, base.darkened(0.15))
		elif variant == 2:
			for k in 2:
				var fx := rng.randi_range(6, 25)
				var fy := rng.randi_range(6, 25)
				cv.line(fx, fy + 1, fx, fy + 5, Color("2f7a3a"))
				var pet := Color("ff9ecb") if k == 0 else Color("fff3a8")
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					cv.px(fx + d.x, fy + d.y, pet)
				cv.px(fx, fy, Color("ffe066"))
		else:
			for i in 3:
				var lx := rng.randi_range(4, 26)
				var ly := rng.randi_range(4, 26)
				cv.line(lx, ly, lx + 2, ly - 3, Color("3b9a4a"))
				cv.line(lx + 2, ly, lx + 2, ly - 4, Color("5fc06a"))
	else:
		for y in [0, 16]:
			cv.rect(0, y, 32, 1, base.darkened(0.45))
			cv.rect(0, y + 1, 32, 1, base.lightened(0.1))
		var seam := 8 + variant * 6
		cv.rect(seam, 1, 1, 15, base.darkened(0.45))
		cv.rect(seam + 1, 1, 1, 15, base.lightened(0.08))
		cv.rect((seam + 14) % 32, 17, 1, 15, base.darkened(0.45))
		cv.rect((seam + 15) % 32, 17, 1, 15, base.lightened(0.08))
		for p in [Vector2i(3, 4), Vector2i(28, 4), Vector2i(3, 21), Vector2i(28, 21)]:
			cv.px(p.x, p.y, base.lightened(0.45))
			cv.px(p.x + 1, p.y + 1, base.darkened(0.4))
		for i in 8:
			var sx2 := rng.randi_range(2, 28)
			var sy2 := rng.randi_range(0, 1) * 16 + rng.randi_range(3, 13)
			cv.line(sx2, sy2, sx2 + 3, sy2, base.darkened(0.2))
		if variant == 2:
			cv.rect(18, 6, 8, 6, Color("6a4a26"))
			cv.rect(18, 6, 8, 1, Color("9a7440"))
			cv.rect(18, 9, 8, 1, Color("3a2814"))
	cv.img.fix_alpha_edges()
	var t := cv.tex()
	cache[key] = t
	return t


func wall_tile(ti: int) -> ImageTexture:
	var key := "wall%d" % ti
	if cache.has(key):
		return cache[key]
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

func monster(ti: int, lvl: int, boss: bool, blink: bool = false) -> ImageTexture:
	var key := "m%d_%d_%d_%d" % [ti, lvl, 1 if boss else 0, 1 if blink else 0]
	if cache.has(key):
		return cache[key]
	var cols: Array = themes[ti]["mcols"]
	var body: Color = cols[(lvl - 1) % cols.size()]
	var rng := RandomNumberGenerator.new()
	rng.seed = ti * 7919 + lvl * 104729 + (13 if boss else 0)
	var cv := Cv.new(32, 32)
	var lt := body.lightened(0.45)
	var dk := body.darkened(0.4)
	var hornc := Color("ece3c8")
	var cx := 16.0
	var rx := (11.0 if boss else 9.0) + rng.randf() * 2.5
	var ry := (11.0 if boss else 9.0) + rng.randf() * 2.5
	var cy := 17.0 + rng.randf() * 1.5
	var shape := rng.randi() % 3
	# --- left-half appendages (mirrored later)
	var legs := rng.randi_range(0, 2)
	if legs == 1:
		for k in 2:
			var lx := 9 + k * 4
			cv.rrect(lx, int(cy + ry - 3), 4, 6, 1.5, dk)
			cv.rect(lx - 1, int(cy + ry + 2), 6, 2, dk.darkened(0.2))
	elif legs == 2:
		for k in 3:
			var lx2 := 6.0 + k * 3.5
			cv.line(lx2, cy + ry - 3, lx2 - 1 + (k % 2) * 2, minf(cy + ry + 4.0, 30.0), dk, 2.0)
	if rng.randf() < 0.75:
		var ay := cy + rng.randf_range(-2, 2)
		cv.line(cx - rx + 1, ay, cx - rx - 3.5, ay + 4, body.darkened(0.15), 3.0)
		cv.disc(cx - rx - 4, ay + 5, 2.0, lt)
		cv.px(int(cx - rx - 5), int(ay + 7), hornc)
		cv.px(int(cx - rx - 3), int(ay + 7), hornc)
	var horns := 2 if boss else rng.randi_range(0, 2)
	for h in horns:
		var hx := cx - 3.5 - h * 4.0
		cv.poly([Vector2(hx - 2, cy - ry + 2), Vector2(hx + 2, cy - ry + 2), Vector2(hx - 3 - h, cy - ry - 6 - (3 if boss else 0))], hornc)
	if shape == 2 or boss:
		for k in 3:
			var sxk := cx - 2.0 - k * 3.5
			cv.poly([Vector2(sxk - 1.5, cy - ry + 2), Vector2(sxk + 1.5, cy - ry + 2), Vector2(sxk, cy - ry - 3)], lt)
	# --- body
	if shape == 0:
		cv.ell(cx, cy, rx, ry, body)
	elif shape == 1:
		cv.rrect(int(cx - rx), int(cy - ry), int(rx * 2), int(ry * 2), 5.0, body)
	else:
		cv.ell(cx, cy - 1, rx, ry - 1, body)
		cv.ell(cx, cy + 3, rx - 1.5, ry - 3, body)
	cv.mirror()
	cv.shade(0.34)
	# belly + spots + pattern
	var belly := body.lightened(0.28)
	cv.ell(16, cy + ry * 0.45, rx * 0.55, ry * 0.4, belly)
	for k in 6:
		var sx := rng.randi_range(8, 15)
		var sy := rng.randi_range(int(cy - ry) + 4, int(cy + ry) - 5)
		var sr := rng.randf_range(0.9, 1.8)
		for s2 in [sx, 31 - sx]:
			cv.disc(s2, sy, sr, dk)
			cv.px(int(s2), sy - 1, body.lightened(0.1))
	# --- face
	var ey := cy - ry * 0.28
	var etype := rng.randi() % 3
	var glow := Color("ff5252") if boss else Color.WHITE
	if etype == 0:
		for sgn in [-1, 1]:
			var ex: float = 16.0 + sgn * 4.0
			cv.ell(ex, ey, 3.3, 3.8, Color("14141c"))
			cv.ell(ex, ey, 2.6, 3.1, glow)
			cv.disc(ex + sgn * -0.2, ey + 0.8, 1.5, Color("14141c") if not boss else Color("2a0a0a"))
			cv.px(int(ex - 1), int(ey - 1), Color.WHITE)
			if blink:
				cv.ell(ex, ey, 3.6, 4.1, body.darkened(0.08))
				cv.line(ex - 3, ey + 1, ex + 3, ey + 1, Color("14141c"))
	elif etype == 1:
		cv.ell(16, ey, 5.2, 5.0, Color("14141c"))
		cv.ell(16, ey, 4.4, 4.2, glow)
		cv.disc(16, ey + 0.5, 2.4, body.darkened(0.2) if not boss else Color("c91d1d"))
		cv.disc(16, ey + 0.5, 1.3, Color("14141c"))
		cv.px(14, int(ey - 1), Color.WHITE)
		cv.px(15, int(ey - 2), Color.WHITE)
		if blink:
			cv.ell(16, ey, 5.5, 5.3, body.darkened(0.08))
			cv.line(11, ey + 1, 21, ey + 1, Color("14141c"))
			cv.line(12, ey + 2, 20, ey + 2, body.darkened(0.3))
	else:
		for sgn in [-1, 1]:
			var ex2: float = 16.0 + sgn * 5.0
			cv.disc(ex2, ey - 1, 2.2, Color("14141c"))
			cv.disc(ex2, ey - 1, 1.6, glow)
			cv.px(int(ex2), int(ey - 1), Color("14141c"))
		cv.disc(16, ey + 3, 1.6, Color("14141c"))
		cv.px(16, int(ey + 3), glow)
		if blink:
			for sgn2 in [-1, 1]:
				cv.disc(16.0 + sgn2 * 5.0, ey - 1, 2.5, body.darkened(0.08))
				cv.line(16.0 + sgn2 * 5.0 - 2, ey, 16.0 + sgn2 * 5.0 + 2, ey, Color("14141c"))
			cv.disc(16, ey + 3, 2.0, body.darkened(0.08))
	# brow
	var browy := int(ey - 4.5)
	cv.line(10, browy + 1, 14, browy + (2 if etype != 1 else 1), dk.darkened(0.3))
	cv.line(21, browy + (2 if etype != 1 else 1), 25, browy + 1, dk.darkened(0.3))
	# mouth
	var my := int(cy + ry * 0.3)
	var mw := rng.randi_range(4, 6)
	cv.rect(16 - mw, my, mw * 2, 3, Color("2a0f18"))
	cv.rect(16 - mw, my + 3, mw * 2, 1, Color("7a1f2f"))
	if rng.randf() < 0.75:
		for k in range(0, mw * 2, 3):
			cv.rect(16 - mw + k, my, 2, 2, Color("f6efd6"))
		if rng.randf() < 0.5:
			cv.rect(16 - mw + 1, my + 2, 2, 1, Color("f6efd6"))
			cv.rect(16 + mw - 3, my + 2, 2, 1, Color("f6efd6"))
	else:
		cv.rect(15, my + 1, 2, 2, Color("ff7a8a"))
	# antenna / bulb
	if rng.randf() < 0.35 or boss:
		cv.line(16, cy - ry + 1, 16, cy - ry - 4, dk)
		cv.disc(16, cy - ry - 5, 2.4, Color("fff27a"))
		cv.px(15, int(cy - ry - 6), Color.WHITE)
	# boss crown
	if boss:
		var cy0 := int(cy - ry) - 1
		cv.poly([Vector2(8, cy0 + 4), Vector2(8, cy0 - 3), Vector2(12, cy0 + 1), Vector2(16, cy0 - 5), Vector2(20, cy0 + 1), Vector2(24, cy0 - 3), Vector2(24, cy0 + 4)], Color("ffc93c"))
		cv.rect(8, cy0 + 3, 16, 2, Color("c98a12"))
		cv.px(16, cy0 - 1, Color("ff5252"))
		cv.px(11, cy0 + 2, Color("4fd1ff"))
		cv.px(21, cy0 + 2, Color("4fd1ff"))
	# theme flavour
	if ti == 1:
		for k in 3:
			var vx := rng.randi_range(9, 22)
			cv.line(vx, cy + ry - 1, vx + rng.randi_range(-2, 2), cy + ry + 2, Color("3b9a4a"))
	elif ti == 2:
		cv.rect(int(cx - rx) + 1, int(cy + 1), int(rx * 2) - 2, 1, Color(0, 0, 0, 0.35))
	cv.outline(body.darkened(0.82))
	cv.img.fix_alpha_edges()
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

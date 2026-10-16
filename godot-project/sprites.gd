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

const NV := 16


func floor_tile(ti: int, parity: int, variant: int) -> ImageTexture:
	variant = variant % NV
	var key := "floor%d_%d_%d" % [ti, parity, variant]
	if cache.has(key):
		return cache[key]
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
	if boss:
		var cy0 := int(topy) - 1
		cv.poly([Vector2(9, cy0 + 4), Vector2(9, cy0 - 3), Vector2(12.5, cy0 + 1), Vector2(16, cy0 - 5), Vector2(19.5, cy0 + 1), Vector2(23, cy0 - 3), Vector2(23, cy0 + 4)], Color("ffc93c"))
		cv.rect(9, cy0 + 3, 14, 2, Color("c98a12"))
		cv.px(16, cy0 - 1, Color("ff5252"))
		cv.px(12, cy0 + 2, Color("4fd1ff"))
		cv.px(20, cy0 + 2, Color("4fd1ff"))
		cv.rect(4, 13, 24, 2, Color("c93b3b"))
		cv.px(8, 13, Color("ffd84f"))
		cv.px(23, 13, Color("ffd84f"))
	cv.outline(skin.darkened(0.85))
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

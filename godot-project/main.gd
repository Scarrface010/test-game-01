extends Control
# Pocket Station - level-or-die pocket dungeon with a creeping dark.
# Beat monsters weaker than you (green badge) to level up; stronger or equal ones (red) kill you.
# Reach the gate's level before the dark eats the board from the edges.
# Extras: gold-star elites (+2), shield (survive one losing fight), spikes (+2 dark steps),
# lanterns, portals, walls, coins. Add "?floor=5" to the URL to start on a later (bigger) floor.

const START_LEVEL := 2
const GX := 40
const GY := 330
const GW := 640.0
enum { PLAY, DEAD, CLEAR, RELIC, SHOP, CLASS, FORK, MARKET }

var themes: Array = []
var font: Font = ThemeDB.fallback_font
var tex_cache: Dictionary = {}

var N := 6
var cell := 106.0
var period := 9
var maxd := 2

var floor_n := 1
var level := START_LEVEL
var moves := 0
var coins := 0
var shield := false
var pos := Vector2i.ZERO
var start := Vector2i.ZERO
var stairs := Vector2i.ZERO
var req := 4
var boss_cell := Vector2i(-1, -1)
var mons: Dictionary = {}     # Vector2i -> int level
var elite: Dictionary = {}    # Vector2i -> true (gold star: +2 levels when beaten)
var items: Dictionary = {}    # Vector2i -> "pot" | "big" | "lamp" | "shield"
var spikes: Dictionary = {}   # Vector2i -> true (stepping on them costs 2 extra steps)
var coin_at: Dictionary = {}  # Vector2i -> true
var walls: Dictionary = {}    # Vector2i -> true
var portals: Dictionary = {}  # Vector2i -> Vector2i (both directions)
var walk: Array[Vector2i] = []
var walk_t := 0.0
var state := PLAY
var msg := ""
var over_title := ""
var over_sub := ""
var best := 0
var t := 0.0
var pops: Array = []
var stars: Array = []
var saved: Dictionary = {}
var kinds: Dictionary = {}       # Vector2i -> "sleeper" | "feeder" | "thief"
var thief_held: Dictionary = {}  # Vector2i -> coins the thief is holding
var relics: Dictionary = {}      # id -> count (this run only)
var relic_defs: Array = []
var synergies: Array = []
var use_defs: Dictionary = {}
var class_defs: Array = []
var door_defs: Dictionary = {}
var cls := "scout"
var inv: Array[String] = []
var aim := -1
var boost := 0
var keys := 0
var vaults: Dictionary = {}
var boss_floor := false
var boss_kind := "warden"
var boss_base := 5
var fmod := "standard"
var door_choices: Array = []
var market_stock: Array = []
var shop_return := 0
var relic_choices: Array = []
var shop_defs: Array = []
var bank := 0
var run_banked := 0
var ups: Dictionary = {"vet": 0, "iron": 0, "packed": 0, "lucky": 0, "pockets": 0, "treasure": 0, "oil": 0, "toolbox": 0, "gate": 0, "steel": 0, "haggle": 0, "ash": 0, "head": 0, "interest": 0}
var shop_page := 0
var reset_armed := -10.0
var btn_skip := Rect2(160, 1140, 400, 70)
var btn_wipe := Rect2(160, 1210, 400, 56)
var snd_on := true
var sfx_cache: Dictionary = {}
var sfx_players: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer
var music_cache: Dictionary = {}
var music_building: Dictionary = {}
var music_theme := -1
var btn_sound := Rect2(20, 20, 104, 46)
var btn_reset := Rect2(596, 20, 104, 46)
var btn_retry := Rect2(160, 790, 400, 76)
var btn_newrun := Rect2(160, 880, 400, 76)
var btn_shop := Rect2(160, 970, 400, 76)
var btn_back := Rect2(250, 1010, 220, 64)
var btn_shop2 := Rect2(160, 1100, 400, 76)
var btn_prev := Rect2(40, 1010, 190, 64)
var btn_next := Rect2(490, 1010, 190, 64)

const SR_SFX := 22050
const SR_MUS := 11025


func _ready() -> void:
	randomize()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_make_themes()
	var cfg := ConfigFile.new()
	if cfg.load("user://best.cfg") == OK:
		best = int(cfg.get_value("s", "best", 0))
		bank = int(cfg.get_value("s", "bank", 0))
		for k in ups:
			ups[k] = int(cfg.get_value("ups", k, 0))
	_make_defs()
	var rs := RandomNumberGenerator.new()
	rs.seed = 4242
	for i in 60:
		stars.append([rs.randf() * 720.0, rs.randf() * 1280.0, rs.randf() * 6.28, 1.0 + rs.randf() * 2.0])
	var args := OS.get_cmdline_user_args()
	if "--gen" in args:
		cls = "gambler"
		for r in 12:
			var t0 := Time.get_ticks_msec()
			_new_run(10)
			print("gen run %d relics %s tries? ms %d boss %s" % [r, relics, Time.get_ticks_msec() - t0, boss_floor])
		get_tree().quit()
		return
	if "--test" in args:
		await _self_test()
		get_tree().quit()
		return
	_setup_audio()
	_new_floor()
	state = CLASS
	if OS.has_feature("web"):
		var demo = JavaScriptBridge.eval("new URLSearchParams(location.search).get('demo')")
		var fq = JavaScriptBridge.eval("new URLSearchParams(location.search).get('floor')")
		var cq = JavaScriptBridge.eval("new URLSearchParams(location.search).get('class')")
		if cq != null:
			cls = String(cq)
		if fq != null and int(fq) > 0:
			_new_run(int(fq))
		if demo == "relic":
			if fq == null:
				_new_run()
			_clear()
		elif demo == "fork":
			if fq == null:
				_new_run()
			relic_choices = []
			_finish_clear()
		elif demo == "market":
			if fq == null:
				_new_run()
			coins = 20
			_open_market()
		elif demo == "shop":
			bank = 40
			shop_return = CLASS
			state = SHOP


func _make_themes() -> void:
	themes = [
		{
			"name": "DERELICT STATION", "bg": Color("0b1020"), "tile": Color("18213f"), "tile2": Color("1e2950"),
			"wall": Color("56607f"), "accent": Color("4fd1ff"), "dark": Color("02030a"),
			"mcols": [Color("9be36b"), Color("ffb347"), Color("8fa3c9"), Color("e0e7ff"), Color("c07cff"), Color("ff6f91"), Color("4fd1ff"), Color("ffe066"), Color("ff7b54")],
			"mons": ["Rat-bot", "Drone", "Crawler", "Turret", "Mech", "Warden", "Hunter", "Overseer", "Core AI"],
			"pot": "Power cell", "gate": "Airlock", "boss": "Station Core",
		},
		{
			"name": "OVERGROWN GREENHOUSE", "bg": Color("0c1a12"), "tile": Color("183625"), "tile2": Color("1f4530"),
			"wall": Color("3f6b3a"), "accent": Color("7dff9b"), "dark": Color("020a05"),
			"mcols": [Color("d9f26b"), Color("ff9ecb"), Color("b6e3ff"), Color("ffcf5c"), Color("e56bff"), Color("ff7a5c"), Color("7dffe0"), Color("fff08a"), Color("ff5c8a")],
			"mons": ["Aphid", "Vine", "Beetle", "Spore pod", "Stalker", "Bloom", "Mantis", "Elder root", "Hive heart"],
			"pot": "Nectar", "gate": "Hatch", "boss": "Hive Queen",
		},
		{
			"name": "SMUGGLER HOLD", "bg": Color("1c120c"), "tile": Color("3a2416"), "tile2": Color("472c1b"),
			"wall": Color("8a6a45"), "accent": Color("ffb14f"), "dark": Color("0a0502"),
			"mcols": [Color("b0b0b0"), Color("ff8a5c"), Color("8cc7ff"), Color("ffe08a"), Color("c8a2ff"), Color("ff5c5c"), Color("7dffb0"), Color("ffd0a0"), Color("ff3d7f")],
			"mons": ["Pest", "Cutpurse", "Bruiser", "Gunhand", "Enforcer", "Captain", "Assassin", "Warlord", "Kingpin"],
			"pot": "Medkit", "gate": "Cargo door", "boss": "Crime Lord",
		},
	]


func _make_defs() -> void:
	relic_defs = [
		{"id": "vanguard", "name": "Vanguard", "desc": "+1 starting level every floor", "max": 2},
		{"id": "slowdark", "name": "Slow Dark", "desc": "The dark waits 2 steps longer per ring", "max": 2},
		{"id": "aegis", "name": "Aegis", "desc": "Start every floor with a shield", "max": 1},
		{"id": "boots", "name": "Heavy Boots", "desc": "Spikes no longer cost extra steps", "max": 1},
		{"id": "midas", "name": "Midas Touch", "desc": "Coins are worth double", "max": 1},
		{"id": "phoenix", "name": "Phoenix Feather", "desc": "Survive one death: the floor restarts", "max": 1},
		{"id": "lantern", "name": "Lantern Bearer", "desc": "Lanterns hold the dark back twice as long", "max": 1},
		{"id": "skeleton", "name": "Skeleton Key", "desc": "Gates need 1 less level", "max": 2},
		{"id": "alchemist", "name": "Alchemist", "desc": "Potions and power cells give +1 extra level", "max": 1},
		{"id": "slayer", "name": "Slayer", "desc": "Gold-star elites give +1 extra level", "max": 1},
		{"id": "bandolier", "name": "Bandolier", "desc": "+1 item slot", "max": 1},
		{"id": "scavenger", "name": "Scavenger", "desc": "One extra tool appears on every floor", "max": 1},
		{"id": "glass", "name": "Glass Cannon", "desc": "+3 starting levels, but the dark is 3 steps faster", "max": 1, "curse": true},
		{"id": "greedy", "name": "Greedy Pact", "desc": "Coins are worth triple, but every monster gets +1 level", "max": 1, "curse": true},
		{"id": "blade", "name": "Hungry Blade", "desc": "Every kill gives +1 extra level, but gates need 3 more", "max": 1, "curse": true},
		{"id": "ember", "name": "Ember Lantern", "desc": "Lanterns hold the dark back 12 steps, but spikes cost 2 more", "max": 1, "curse": true},
	]
	synergies = [
		{"a": "vanguard", "b": "alchemist", "text": "Potions give +1 more level"},
		{"a": "slowdark", "b": "lantern", "text": "Lanterns hold the dark back 12 steps"},
		{"a": "skeleton", "b": "boots", "text": "Gates need 1 less level again"},
		{"a": "phoenix", "b": "aegis", "text": "Phoenix revive also gives +1 level"},
	]
	use_defs = {
		"bomb": {"name": "Bomb", "desc": "Destroys adjacent walls, spikes and weak monsters", "col": Color("ff7a45")},
		"crystal": {"name": "Time Crystal", "desc": "Pushes the dark back 6 steps", "col": Color("4fd1ff")},
		"blink": {"name": "Blink Scroll", "desc": "Teleport to any free tile (costs 1 step)", "col": Color("c07cff")},
		"cloak": {"name": "Shadow Cloak", "desc": "Your next fight counts as +3 levels", "col": Color("9aa3c7")},
		"draught": {"name": "Elixir", "desc": "+2 levels right now", "col": Color("6dff9a")},
		"magnet": {"name": "Magnet", "desc": "Pulls in every coin on the board", "col": Color("ff5d5d")},
		"pick": {"name": "Pickaxe", "desc": "Breaks any one wall", "col": Color("c9a55a")},
		"zap": {"name": "Zap Rod", "desc": "Zaps a monster within 2 tiles (up to your level +1)", "col": Color("ffe14f")},
	}
	class_defs = [
		{"id": "scout", "name": "Scout", "desc": "The dark waits +1 step per ring. Starts with a Blink Scroll and a Time Crystal.", "col": Color("4fd1ff"), "lvl": 0, "per": 1, "kit": ["blink", "crystal"]},
		{"id": "brute", "name": "Brute", "desc": "+2 starting levels, but the dark is 1 step faster. Starts with a Bomb.", "col": Color("ff6a5c"), "lvl": 2, "per": -1, "kit": ["bomb"]},
		{"id": "mystic", "name": "Mystic", "desc": "A shield every floor and +1 item slot. Starts with a Shadow Cloak.", "col": Color("c07cff"), "lvl": 0, "per": 0, "kit": ["cloak"]},
		{"id": "gambler", "name": "Gambler", "desc": "Begins with 2 random relics (maybe cursed!) and sees 4 relic cards, not 3.", "col": Color("ffd84f"), "lvl": 0, "per": 0, "kit": []},
	]
	door_defs = {
		"standard": {"name": "Steady Path", "desc": "A normal floor.", "col": Color("9fb3d9")},
		"danger": {"name": "Perilous Path", "desc": "Monsters +2 levels, coins worth +1, and an extra relic card afterwards.", "col": Color("ff6a5c")},
		"calm": {"name": "Quiet Path", "desc": "Monsters -1 level and the dark waits 2 steps longer, but no relic afterwards.", "col": Color("7dffb0")},
		"vault": {"name": "Vault Path", "desc": "A locked vault and its key are on this floor. Worth a detour?", "col": Color("ffd84f")},
		"market": {"name": "Merchant", "desc": "Spend your run coins on tools, then continue to a normal floor.", "col": Color("c07cff")},
	}
	shop_defs = [
		{"id": "vet", "name": "Veteran", "desc": "Start every run with +1 level", "costs": [15, 35, 60]},
		{"id": "iron", "name": "Iron Will", "desc": "The dark waits 1 step longer per ring", "costs": [20, 40, 70]},
		{"id": "packed", "name": "Packed Shield", "desc": "Start every floor with a shield", "costs": [45]},
		{"id": "lucky", "name": "Lucky Finds", "desc": "Relic choices offer 4 relics instead of 3", "costs": [50]},
		{"id": "pockets", "name": "Deep Pockets", "desc": "+1 tool slot", "costs": [40, 90]},
		{"id": "treasure", "name": "Treasure Hunter", "desc": "Every coin is worth +1", "costs": [25, 55, 100]},
		{"id": "oil", "name": "Lantern Oil", "desc": "Lanterns hold the dark back 2 steps longer", "costs": [25, 50, 85]},
		{"id": "toolbox", "name": "Toolbox", "desc": "Start every run with a random tool", "costs": [30, 70]},
		{"id": "gate", "name": "Gate Whisperer", "desc": "Gates and bosses need 1 less level", "costs": [60, 120]},
		{"id": "steel", "name": "Steel Boots", "desc": "Spikes cost 1 less extra step", "costs": [35]},
		{"id": "haggle", "name": "Haggler", "desc": "Merchant prices are 2 coins cheaper", "costs": [30]},
		{"id": "head", "name": "Head Start", "desc": "Begin every run with a random relic", "costs": [75, 150]},
		{"id": "ash", "name": "Phoenix Ash", "desc": "Begin every run with a Phoenix Feather", "costs": [120]},
		{"id": "interest", "name": "Interest", "desc": "+10% bonus on coins you bank", "costs": [40, 80, 130]},
	]


func up(id: String) -> int:
	return int(ups.get(id, 0))


func relic_n(id: String) -> int:
	return int(relics.get(id, 0))


func syn(a: String, b: String) -> bool:
	return relic_n(a) > 0 and relic_n(b) > 0


func cdef() -> Dictionary:
	for d in class_defs:
		if d["id"] == cls:
			return d
	return class_defs[0]


func start_lvl() -> int:
	return START_LEVEL + int(ups["vet"]) + relic_n("vanguard") + 3 * relic_n("glass") + int(cdef()["lvl"])


func pot_g() -> int:
	return 1 + relic_n("alchemist") + (1 if syn("vanguard", "alchemist") else 0)


func big_g() -> int:
	return 2 + relic_n("alchemist") + (1 if syn("vanguard", "alchemist") else 0)


func lamp_amt() -> int:
	var base := 4
	if relic_n("ember") > 0 or syn("slowdark", "lantern"):
		base = 12
	elif relic_n("lantern") > 0:
		base = 8
	return base + 2 * up("oil")


func spike_x() -> int:
	if relic_n("boots") > 0:
		return 0
	return maxi(0, 2 + (2 if relic_n("ember") > 0 else 0) - up("steel"))


func start_shield() -> bool:
	return relic_n("aegis") > 0 or int(ups["packed"]) > 0 or cls == "mystic"


func slots_n() -> int:
	return 2 + (1 if cls == "mystic" else 0) + relic_n("bandolier") + up("pockets")


func kill_gain(c: Vector2i) -> int:
	return (2 + relic_n("slayer") if elite.has(c) else 1) + relic_n("blade")


func coin_val() -> int:
	var v := 1 + up("treasure")
	if relic_n("midas") > 0:
		v *= 2
	if relic_n("greedy") > 0:
		v *= 3
	if fmod == "danger":
		v += 1
	return v


func req_adjust() -> int:
	return 3 * relic_n("blade") - relic_n("skeleton") - (1 if syn("skeleton", "boots") else 0) - up("gate")


func stairs_blocked() -> bool:
	return boss_floor or level < req


func _boss_level(m: int) -> int:
	var dp := mini(m / period, maxd)
	if boss_kind == "colossus":
		return boss_base + 2 * dp
	if boss_kind == "king":
		return boss_base + (6 if dp >= 1 else 0)
	return boss_base


func _scaled(lv: int) -> int:
	# Monsters keep pace with the player's permanent power (70%) and grow steadily with depth.
	var power := start_lvl() - START_LEVEL
	var r := lv + int(round(power * 0.7))
	if lv >= 2:
		r += (floor_n - 1) / 2
	else:
		r += (floor_n - 1) / 4
	r += relic_n("greedy")
	if fmod == "danger":
		r += 2
	elif fmod == "calm":
		r -= 1
	return maxi(1, r)


func sleeper_bonus() -> int:
	return 3 + floor_n / 6


func _mon_level(c: Vector2i, m: int = -1) -> int:
	var mm := moves if m < 0 else m
	var base: int = mons[c]
	var dp := mini(mm / period, maxd)
	var k := String(kinds.get(c, ""))
	if k == "sleeper" and dp >= 1:
		return base + sleeper_bonus()
	if k == "feeder":
		return base + dp
	return base


func _save_meta() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://best.cfg")
	cfg.set_value("s", "best", best)
	cfg.set_value("s", "bank", bank)
	for k in ups:
		cfg.set_value("ups", k, int(ups[k]))
	cfg.save("user://best.cfg")


func tidx() -> int:
	return ((floor_n - 1) / 3) % themes.size()


func cur_theme() -> Dictionary:
	return themes[tidx()]


func ring(c: Vector2i) -> int:
	return mini(mini(c.x, c.y), mini(N - 1 - c.x, N - 1 - c.y))


func depth_for(m: int) -> int:
	return mini(m / period, maxd)


func is_dark(c: Vector2i) -> bool:
	return ring(c) < depth_for(moves)


func in_b(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < N and c.y < N


# ---------- sprites (all generated in code) ----------

func _tex_from_rows(rows: Array, pal: Dictionary) -> ImageTexture:
	var h := rows.size()
	var w: int = String(rows[0]).length()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var r: String = rows[y]
		for x in w:
			var ch: String = r[x]
			if pal.has(ch):
				img.set_pixel(x, y, pal[ch])
	return ImageTexture.create_from_image(img)


func _player_tex() -> ImageTexture:
	var key := "player_" + cls
	if tex_cache.has(key):
		return tex_cache[key]
	var rows := [
		"....oooooo....",
		"...owwwwwwo...",
		"..owwwwwwwwo..",
		".owwoooooowwo.",
		".owovvvvvvowo.",
		".owovhhvvvowo.",
		".owovvvvVVowo.",
		".owwoooooowwo.",
		"..owwwwwwwwo..",
		".owlwwrrwwlwo.",
		"owwlwwyywwlwwo",
		"owwlwwwwwwlwwo",
		".owwwwwwwwwwo.",
		"..owwwooowwwo.",
		".obbbo..obbbo.",
		".ooooo..ooooo.",
	]
	var acc: Color = cdef()["col"]
	var pal := {
		"o": Color("10131f"), "w": Color("eef2ff"), "l": Color("aab3d1"), "v": acc, "V": acc.darkened(0.45),
		"h": Color("ffffff"), "r": Color("ff5d5d"), "y": Color("ffd84f"), "b": Color("5a6280"),
	}
	var tx := _tex_from_rows(rows, pal)
	tex_cache[key] = tx
	return tx


func _item_tex(kind: String) -> ImageTexture:
	if tex_cache.has(kind):
		return tex_cache[kind]
	var rows: Array
	var pal: Dictionary = {"o": Color("10131f"), "h": Color("ffffff")}
	if kind == "pot" or kind == "big":
		rows = [
			"....oooo....", "....occo....", "....oggo....", "...oggggo...", "..oyyyyyyo..",
			".oyhhyyyyyo.", ".oyhyyyyyYo.", ".oyyyyyyyYo.", ".oyyyyyyYYo.", "..oyyyYYYo..",
			"...oooooo...", "............",
		]
		pal["c"] = Color("a8743a")
		pal["g"] = Color("cfe6ff")
		pal["y"] = Color("ffd84f") if kind == "pot" else Color("4fd1ff")
		pal["Y"] = Color("e0a92a") if kind == "pot" else Color("2a8fc4")
	elif kind == "lamp":
		rows = [
			"....oooo....", "...o....o...", "..oooooooo..", "..oyyyyyyo..", "..oyhhyyyo..",
			"..oyhwwyyo..", "..oywwwyyo..", "..oyyyyyyo..", "..oooooooo..", "...oggggo...",
			"...oooooo...", "............",
		]
		pal["y"] = Color("ffcf4f")
		pal["w"] = Color("fff6c8")
		pal["g"] = Color("8a8f9c")
	elif kind == "shield":
		rows = [
			"..oooooooo..", ".obbbbbbbbo.", ".obhbbbbbbo.", ".obhbbwwbbo.", ".obbbbwwbbo.",
			".obbbbwwbbo.", "..obbbbbbo..", "..obbbbbBo..", "...obbbbBo..", "....obbBo...",
			".....oBo....", "............",
		]
		pal["b"] = Color("4f8cff")
		pal["B"] = Color("2a56b3")
		pal["w"] = Color("ffffff")
		pal["h"] = Color("a9c8ff")
	else:
		rows = [
			"....oooo....", "..ooyyyyoo..", ".oyyyhhyyyo.", ".oyyhyyyYyo.", "oyyhyYYYYyyo",
			"oyyhyYYYYyyo", "oyyyyYYYYyyo", ".oyyyYYYYyo.", ".oyyyyyyyyo.", "..ooyyyyoo..",
			"....oooo....", "............",
		]
		pal["y"] = Color("ffc93c")
		pal["Y"] = Color("e09a1a")
	var tx := _tex_from_rows(rows, pal)
	tex_cache[kind] = tx
	return tx


func _floor_tex(ti: int, parity: int, variant: int) -> ImageTexture:
	var key := "floor%d_%d_%d" % [ti, parity, variant]
	if tex_cache.has(key):
		return tex_cache[key]
	var base: Color = themes[ti]["tile"] if parity == 0 else themes[ti]["tile2"]
	var rng := RandomNumberGenerator.new()
	rng.seed = ti * 100 + parity * 10 + variant
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(base)
	if ti == 0:
		for i in 16:
			img.set_pixel(i, 0, base.darkened(0.3))
			img.set_pixel(0, i, base.darkened(0.3))
			img.set_pixel(i, 1, base.lightened(0.08))
			img.set_pixel(1, i, base.lightened(0.08))
		for p in [Vector2i(3, 3), Vector2i(12, 3), Vector2i(3, 12), Vector2i(12, 12)]:
			img.set_pixel(p.x, p.y, base.lightened(0.3))
			img.set_pixel(p.x + 1, p.y + 1, base.darkened(0.3))
		if variant == 1:
			for y in range(5, 11, 2):
				for x in range(4, 12):
					img.set_pixel(x, y, base.darkened(0.35))
		elif variant == 2:
			for x in 16:
				if (x / 2) % 2 == 0:
					img.set_pixel(x, 14, Color("b8901e"))
					img.set_pixel(x, 13, Color("b8901e").darkened(0.3))
	elif ti == 1:
		for i in 12:
			var gx := rng.randi_range(1, 14)
			var gy := rng.randi_range(2, 14)
			img.set_pixel(gx, gy, base.lightened(0.28))
			img.set_pixel(gx, gy - 1, base.lightened(0.45))
		for i in 8:
			img.set_pixel(rng.randi_range(0, 15), rng.randi_range(0, 15), base.darkened(0.2))
		if variant == 2:
			var fx := rng.randi_range(3, 12)
			var fy := rng.randi_range(3, 12)
			img.set_pixel(fx, fy, Color("ffe066"))
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				img.set_pixel(fx + d.x, fy + d.y, Color("ff9ecb"))
	else:
		for y in [0, 8]:
			for x in 16:
				img.set_pixel(x, y, base.darkened(0.35))
				img.set_pixel(x, y + 1, base.lightened(0.07))
		for i in 14:
			var gx2 := rng.randi_range(0, 15)
			var gy2: int = rng.randi_range(0, 1) * 8 + rng.randi_range(2, 6)
			img.set_pixel(gx2, gy2, base.darkened(0.15))
			if gx2 < 14:
				img.set_pixel(gx2 + 1, gy2, base.darkened(0.15))
		var seam := 5 + variant * 3
		for y in range(0, 8):
			img.set_pixel(seam, y, base.darkened(0.35))
		for y in range(8, 16):
			img.set_pixel((seam + 7) % 16, y, base.darkened(0.35))
		for p in [Vector2i(1, 3), Vector2i(14, 3), Vector2i(1, 11), Vector2i(14, 11)]:
			img.set_pixel(p.x, p.y, base.lightened(0.35))
	var tx := ImageTexture.create_from_image(img)
	tex_cache[key] = tx
	return tx


func _wall_tex(ti: int) -> ImageTexture:
	var key := "wall%d" % ti
	if tex_cache.has(key):
		return tex_cache[key]
	var base: Color = themes[ti]["wall"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 555 + ti
	var S := 16
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(base)
	if ti == 0:
		for i in S:
			for e in [0, S - 1]:
				img.set_pixel(i, e, base.darkened(0.6))
				img.set_pixel(e, i, base.darkened(0.6))
			img.set_pixel(i, 1, base.lightened(0.25))
			img.set_pixel(1, i, base.lightened(0.15))
			img.set_pixel(i, S - 2, base.darkened(0.3))
			img.set_pixel(S - 2, i, base.darkened(0.3))
		for y in [5, 7, 9]:
			for x in range(3, 13):
				img.set_pixel(x, y, base.darkened(0.45))
				img.set_pixel(x, y + 1, base.lightened(0.15))
		for p in [Vector2i(3, 3), Vector2i(12, 3), Vector2i(3, 12), Vector2i(12, 12)]:
			img.set_pixel(p.x, p.y, base.lightened(0.5))
		for x in range(2, 14):
			if (x / 2) % 2 == 0:
				img.set_pixel(x, 12, Color("d9b020"))
				img.set_pixel(x, 13, Color("d9b020").darkened(0.35))
	elif ti == 1:
		var g1 := base.darkened(0.45)
		var g2 := base
		var g3 := base.lightened(0.3)
		for y in S:
			for x in S:
				var v := sin(x * 1.1 + rng.randf()) + cos(y * 0.9 + rng.randf()) + rng.randf() * 0.8
				var c := g2
				if v < -0.4:
					c = g1
				elif v > 1.1:
					c = g3
				img.set_pixel(x, y, c)
		for i in S:
			if rng.randf() < 0.5:
				img.set_pixel(i, 0, g1)
			if rng.randf() < 0.5:
				img.set_pixel(i, S - 1, g1)
			if rng.randf() < 0.5:
				img.set_pixel(0, i, g1)
			if rng.randf() < 0.5:
				img.set_pixel(S - 1, i, g1)
		for i in 4:
			img.set_pixel(rng.randi_range(2, 13), rng.randi_range(2, 13), Color("ff5c7a"))
	else:
		for i in S:
			for e in [0, S - 1]:
				img.set_pixel(i, e, base.darkened(0.6))
				img.set_pixel(e, i, base.darkened(0.6))
			img.set_pixel(i, 1, base.lightened(0.2))
			img.set_pixel(1, i, base.lightened(0.2))
		for i in range(2, S - 2):
			img.set_pixel(i, i, base.darkened(0.35))
			img.set_pixel(i, i + 1 if i + 1 < S - 1 else i, base.darkened(0.35))
			img.set_pixel(S - 1 - i, i, base.darkened(0.35))
			img.set_pixel(S - 1 - i, i + 1 if i + 1 < S - 1 else i, base.darkened(0.35))
		for p in [Vector2i(2, 2), Vector2i(13, 2), Vector2i(2, 13), Vector2i(13, 13)]:
			img.set_pixel(p.x, p.y, base.lightened(0.6))
		for i in 12:
			img.set_pixel(rng.randi_range(2, 13), rng.randi_range(2, 13), base.lightened(0.1))
	var tx := ImageTexture.create_from_image(img)
	tex_cache[key] = tx
	return tx


func _monster_tex(ti: int, lvl: int, boss: bool) -> ImageTexture:
	var key := "m%d_%d_%d" % [ti, lvl, 1 if boss else 0]
	if tex_cache.has(key):
		return tex_cache[key]
	var cols: Array = themes[ti]["mcols"]
	var body: Color = cols[(lvl - 1) % cols.size()]
	var W := 15 if boss else 13
	var half := W / 2
	var rng := RandomNumberGenerator.new()
	rng.seed = ti * 7919 + lvl * 104729 + (13 if boss else 0)
	var g: Array = []
	for y in W:
		var row: Array = []
		for x in W:
			row.append(0)
		g.append(row)
	# 0 empty, 1 body, 2 eye white, 3 pupil, 4 mouth, 5 tooth, 6 spot, 7 horn, 8 glow bulb
	var rx := float(half) - 0.6 - rng.randf() * 1.3
	var cy := (W - 1) * 0.5 + rng.randf() * 0.8
	var ry := W * 0.5 - 1.9 - rng.randf() * 1.2
	var ex := 2.0 + rng.randf() * 1.6
	for y in W:
		for x in range(0, half + 1):
			var dx := absf(float(x - half)) / rx
			var dy := absf(float(y) - cy) / ry
			var v := pow(dx, ex) + pow(dy, ex)
			if v <= 1.0 + (rng.randf() - 0.5) * 0.3:
				g[y][x] = 1
	# arms
	if rng.randf() < 0.65:
		var ay := int(cy) + rng.randi_range(-1, 1)
		for x in range(0, maxi(1, half - int(rx)) + 1):
			g[ay][x] = 1
			if rng.randf() < 0.5:
				g[ay + 1][x] = 1
	# horns
	var horns := rng.randi_range(0, 2)
	if boss:
		horns = 2
	for h in horns:
		var hx := half - 2 - h * 2 - rng.randi_range(0, 1)
		if hx < 1:
			hx = 1
		g[0][hx] = 7
		g[1][hx] = 7
		g[2][hx] = 7
		if hx > 0:
			g[0][hx - 1] = 7
	if rng.randf() < 0.3 or boss:
		g[0][half] = 8
		g[1][half] = 7
	# legs
	if rng.randf() < 0.75:
		var lx := half - 1 - rng.randi_range(0, 1)
		for k in rng.randi_range(1, 2):
			var x := lx - k * 2
			if x >= 0:
				g[W - 1][x] = 1
				g[W - 2][x] = 1
	# eyes
	var ey := int(cy - ry * 0.35)
	var etype := rng.randi() % 3
	if etype == 0:
		var ex0 := half - 3
		for yy in range(ey, ey + 2):
			for xx in range(ex0, ex0 + 2):
				g[yy][xx] = 2
		g[ey + 1][ex0 + 1] = 3
		g[ey][ex0 + 1] = 3
	elif etype == 1:
		for yy in range(ey - 1, ey + 2):
			for xx in range(half - 1, half + 1):
				g[yy][xx] = 2
		g[ey][half] = 3
		g[ey + 1][half] = 3
	else:
		g[ey - 1][half] = 2
		g[ey][half] = 3
		g[ey + 1][half - 3] = 2
		g[ey + 1][half - 2] = 3
	# mouth
	var my := ey + 3
	if my < W - 2:
		for xx in range(half - 2, half + 1):
			if int(g[my][xx]) != 0:
				g[my][xx] = 4
		if rng.randf() < 0.65 and int(g[my][half - 1]) == 4:
			g[my][half - 1] = 5
			if int(g[my][half - 2]) == 4 and rng.randf() < 0.5:
				g[my][half - 2] = 5
	# spots
	for i in 5:
		var sx := rng.randi_range(1, half)
		var sy := rng.randi_range(2, W - 3)
		if int(g[sy][sx]) == 1 and absi(sy - ey) > 1:
			g[sy][sx] = 6
	# mirror
	for y in W:
		for x in range(0, half):
			if int(g[y][x]) != 0:
				g[y][W - 1 - x] = g[y][x]
	var S := W + 2
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var outline := body.darkened(0.82)
	var horn_c := body.lightened(0.55)
	for y in S:
		for x in S:
			var gx := x - 1
			var gy := y - 1
			var v := 0
			if gx >= 0 and gy >= 0 and gx < W and gy < W:
				v = int(g[gy][gx])
			if v == 0:
				var near := false
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = gx + d.x
					var ny: int = gy + d.y
					if nx >= 0 and ny >= 0 and nx < W and ny < W and int(g[ny][nx]) != 0:
						near = true
				if near:
					img.set_pixel(x, y, outline)
				continue
			var c := body
			if v == 1 or v == 6 or v == 7:
				var top_empty := gy == 0 or int(g[gy - 1][gx]) == 0
				var left_empty := gx == 0 or int(g[gy][gx - 1]) == 0
				var bot_empty := gy == W - 1 or int(g[gy + 1][gx]) == 0
				var right_empty := gx == W - 1 or int(g[gy][gx + 1]) == 0
				if v == 7:
					c = horn_c
				elif v == 6:
					c = body.darkened(0.28)
				if top_empty or left_empty:
					c = c.lightened(0.3)
				elif bot_empty or right_empty:
					c = c.darkened(0.35)
				elif gy > W * 0.65:
					c = c.darkened(0.15)
			elif v == 2:
				c = Color.WHITE
			elif v == 3:
				c = Color("14141c")
			elif v == 4:
				c = Color("2a0f18")
			elif v == 5:
				c = Color("f2ead3")
			elif v == 8:
				c = Color("fff27a")
			img.set_pixel(x, y, c)
	var tx := ImageTexture.create_from_image(img)
	tex_cache[key] = tx
	return tx


# ---------- floor generation ----------

func _setup_size() -> void:
	N = 6 if floor_n <= 2 else (7 if floor_n <= 4 else 8)
	cell = GW / N
	period = maxi(5, 8 + (N - 5) + int(ups["iron"]) + 2 * relic_n("slowdark") - 3 * relic_n("glass") + int(cdef()["per"]) + (2 if fmod == "calm" else 0) - (floor_n - 1) / 3)
	maxd = (N + 1) / 2 - 1


func _new_floor() -> void:
	_setup_size()
	var gen_t0 := Time.get_ticks_msec()
	var tries := 0
	while true:
		_random_layout(tries)
		tries += 1
		if _solvable():
			break
		if tries >= 24:
			walls.clear()
			portals.clear()
			spikes.clear()
			vaults.clear()
			boss_kind = "warden"
			boss_base = maxi(1, start_lvl() - 1)
			req = boss_base + 1 if boss_floor else start_lvl()
			break
	print("floor %d generated in %d ms (%d tries)" % [floor_n, Time.get_ticks_msec() - gen_t0, tries])
	saved = {
		"mons": mons.duplicate(), "elite": elite.duplicate(), "items": items.duplicate(), "spikes": spikes.duplicate(),
		"coin_at": coin_at.duplicate(), "walls": walls.duplicate(), "portals": portals.duplicate(),
		"coins": coins, "kinds": kinds.duplicate(), "thief_held": thief_held.duplicate(),
		"vaults": vaults.duplicate(), "inv": inv.duplicate(),
	}
	_begin_floor()
	_play_music(tidx())


func _begin_floor() -> void:
	level = start_lvl()
	moves = 0
	shield = start_shield()
	pos = start
	keys = 0
	boost = 0
	aim = -1
	walk.clear()
	pops.clear()
	state = PLAY
	if boss_floor:
		msg = "BOSS FLOOR: defeat the %s to leave" % cur_theme()["boss"]
	else:
		msg = "Reach Lv %d to open the %s" % [req, cur_theme()["gate"]]


func _reset_floor() -> void:
	mons = saved["mons"].duplicate()
	elite = saved["elite"].duplicate()
	items = saved["items"].duplicate()
	spikes = saved["spikes"].duplicate()
	coin_at = saved["coin_at"].duplicate()
	walls = saved["walls"].duplicate()
	portals = saved["portals"].duplicate()
	kinds = saved["kinds"].duplicate()
	thief_held = saved["thief_held"].duplicate()
	vaults = saved["vaults"].duplicate()
	inv.clear()
	for it in saved["inv"]:
		inv.append(String(it))
	coins = saved["coins"]
	_begin_floor()


func _take(free: Array[Vector2i]) -> Vector2i:
	return free.pop_front()


func _take_ring(free: Array[Vector2i], lo: int, hi: int) -> Vector2i:
	for c in free:
		var r := ring(c)
		if r >= lo and r <= hi:
			free.erase(c)
			return c
	return free.pop_front()


func _random_layout(tries: int) -> void:
	var k := N - 6
	boss_floor = floor_n % 5 == 0
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
	stairs = Vector2i(N / 2, N / 2)
	for c in cells:
		if ring(c) == maxd:
			stairs = c   # innermost ring: the dark never reaches it
			break
	var free: Array[Vector2i] = []
	for c in cells:
		if c != start and c != stairs:
			free.append(c)
	mons.clear()
	elite.clear()
	kinds.clear()
	thief_held.clear()
	items.clear()
	spikes.clear()
	coin_at.clear()
	walls.clear()
	portals.clear()
	vaults.clear()
	boss_cell = Vector2i(-1, -1)
	var nm: int = [6, 8, 10][k] + mini((floor_n - 1) / 3, 2) - (3 if boss_floor else 0)
	var base := [1, 1, 2, 2, 3, 3, 4, 4, 5, 6, 6, 7, 7]
	var levels: Array[int] = []
	for i in nm:
		levels.append(_scaled(base[i]))
	levels.sort()
	levels.reverse()
	var first := not boss_floor
	for lv in levels:
		var spot := Vector2i(-1, -1)
		if first:
			for c in free:
				if absi(c.x - stairs.x) + absi(c.y - stairs.y) == 1:
					spot = c
					break
			first = false
			if spot.x >= 0:
				boss_cell = spot
		if spot.x < 0:
			spot = free[0]
		free.erase(spot)
		mons[spot] = lv
	var ne: int = [1, 2, 2][k] + (1 if fmod == "danger" else 0) + (1 if boss_floor else 0)
	var cand: Array[Vector2i] = []
	for c in mons:
		if c != boss_cell and int(mons[c]) >= 2:
			cand.append(c)
	cand.shuffle()
	for i in mini(ne, cand.size()):
		elite[cand[i]] = true
	var kc: Array[Vector2i] = []
	for c in mons:
		if c != boss_cell and not elite.has(c):
			kc.append(c)
	kc.shuffle()
	var kinds_plan: Array[String] = []
	if floor_n >= 2:
		for i in [1, 1, 2][k]:
			kinds_plan.append("sleeper")
	if floor_n >= 3:
		for i in [1, 1, 2][k]:
			kinds_plan.append("feeder")
	if floor_n >= 4:
		kinds_plan.append("thief")
	for i in mini(kinds_plan.size(), kc.size()):
		kinds[kc[i]] = kinds_plan[i]
	var np := 2 + k - (1 if floor_n >= 8 else 0)
	var nbig: int = [1, 1, 2][k]
	var nlamp: int = [1, 2, 2][k]
	var nshield: int = [1, 1, 2][k]
	for i in np:
		items[_take(free)] = "pot"
	for i in nbig:
		items[_take(free)] = "big"
	for i in nlamp:
		items[_take(free)] = "lamp"
	for i in nshield:
		items[_take(free)] = "shield"
	var uids := use_defs.keys()
	var nuse := 1 + (1 if k >= 1 else 0) + relic_n("scavenger")
	for i in nuse:
		items[_take(free)] = "use_" + String(uids[randi() % uids.size()])
	var npairs: int = [1, 1, 2][k]
	for i in npairs:
		var a := _take(free)
		var b := _take(free)
		portals[a] = b
		portals[b] = a
	for i in [3, 5, 7][k] if tries < 8 else 1:
		walls[_take(free)] = true
	for i in [2, 3, 4][k] if tries < 8 else 1:
		spikes[_take(free)] = true
	if floor_n >= 3 and (fmod == "vault" or randf() < 0.4):
		vaults[_take_ring(free, 1, maxd)] = true
		items[_take_ring(free, 0, 0)] = "key"
	for i in N + 2:
		coin_at[_take(free)] = true
	var total := nm * (1 + relic_n("blade")) + elite.size() + np * pot_g() + nbig * big_g()
	var ratio := maxf(0.2, minf(0.7, 0.55 + 0.012 * (floor_n - 1)) - 0.04 * (tries / 2))
	var target := start_lvl() + int(total * ratio)
	req = maxi(start_lvl(), target + req_adjust())
	if boss_floor:
		var bk := ["colossus", "king", "warden"]
		boss_kind = bk[(floor_n / 5) % 3]
		var adj := 3 if boss_kind == "colossus" else (4 if boss_kind == "king" else 0)
		boss_base = maxi(3, target + 1 + floor_n / 5 - adj - tries / 3 + req_adjust())
		req = boss_base + 1


func _solvable() -> bool:
	var list: Array[Vector2i] = []
	var gain: Array[int] = []
	for c in mons:
		list.append(c)
		gain.append(kill_gain(c))
	for c in items:
		var kd: String = items[c]
		if kd == "key" or kd.begins_with("use_"):
			continue
		list.append(c)
		gain.append(pot_g() if kd == "pot" else (big_g() if kd == "big" else 0))
	var idx: Dictionary = {}
	for i in list.size():
		idx[list[i]] = i
	var cap := maxd * period
	var seen: Dictionary = {}
	# state: pos, mask, moves, level, shield
	var stack: Array = [[start, 0, 0, start_lvl(), 1 if start_shield() else 0]]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var pops_n := 0
	while stack.size() > 0:
		pops_n += 1
		if pops_n > 8000:
			return false
		var s: Array = stack.pop_back()
		var p: Vector2i = s[0]
		var mask: int = s[1]
		var m: int = s[2]
		var lvl: int = s[3]
		var sh: int = s[4]
		for d in dirs:
			var nc: Vector2i = p + d
			if not in_b(nc) or walls.has(nc) or vaults.has(nc):
				continue
			var m2 := mini(m + 1 + (spike_x() if spikes.has(nc) else 0), cap)
			var dp := mini(m2 / period, maxd)
			if ring(nc) < dp:
				continue
			var dest := nc
			if portals.has(nc):
				dest = portals[nc]
				if ring(dest) < dp:
					continue
			var mask2 := mask
			var lvl2 := lvl
			var sh2 := sh
			var m3 := m2
			if nc == stairs:
				if boss_floor:
					if lvl > _boss_level(m):
						return true
				elif lvl >= req:
					return true
				continue
			if idx.has(nc) and not (mask & (1 << int(idx[nc]))):
				var bi: int = idx[nc]
				if mons.has(nc):
					if lvl > _mon_level(nc, m):
						lvl2 = lvl + gain[bi]
					elif sh == 1:
						sh2 = 0
					else:
						continue
				else:
					var kind: String = items[nc]
					lvl2 = lvl + gain[bi]
					if kind == "lamp":
						m3 = maxi(m2 - lamp_amt(), dp * period)
					elif kind == "shield":
						sh2 = 1
				mask2 = mask | (1 << bi)
			var key := (((((dest.x * N + dest.y) * 8388608 + mask2) * 64 + m3) * 64 + lvl2) * 2) + sh2
			if seen.has(key):
				continue
			seen[key] = true
			stack.append([dest, mask2, m3, lvl2, sh2])
	return false


# ---------- gameplay ----------

func _pop(c: Vector2i, text: String, col: Color) -> void:
	pops.append({"p": _cell_rect(c).get_center(), "s": text, "c": col, "t": t})


func _use_name(id: String) -> String:
	return String(use_defs[id]["name"])


func _give_use(id: String) -> bool:
	if inv.size() >= slots_n():
		return false
	inv.append(id)
	return true


func _random_use() -> String:
	var ids := use_defs.keys()
	return String(ids[randi() % ids.size()])


func _step(nc: Vector2i) -> void:
	var th := cur_theme()
	var names: Array = th["mons"]
	var landing := nc
	var lamp := false
	var extra := 0
	var snd := "step"
	if mons.has(nc):
		var lv: int = _mon_level(nc)
		var nm: String = th["boss"] if nc == boss_cell else names[(int(mons[nc]) - 1) % names.size()]
		if level + boost > lv:
			var gain := kill_gain(nc)
			var back := 0
			if thief_held.has(nc):
				back = int(thief_held[nc])
				coins += back
			_remove_mon(nc)
			level += gain
			boost = 0
			msg = "Beat %s! Level %d" % [nm, level]
			if back > 0:
				msg += "  (+%d coins back)" % back
			_pop(nc, "LEVEL +%d" % gain, Color("6dff9a"))
			snd = "elite" if gain >= 2 else "win"
		elif shield:
			shield = false
			boost = 0
			_remove_mon(nc)
			msg = "Shield shattered! %s defeated" % nm
			_pop(nc, "SHIELD!", Color("7db2ff"))
			snd = "shieldbreak"
		else:
			pos = nc
			_die("%s (Lv %d) was too strong" % [nm, lv])
			return
	elif nc == stairs:
		if boss_floor:
			var bl := _boss_level(moves)
			if level + boost > bl:
				boost = 0
				msg = "The %s falls!" % th["boss"]
				_pop(nc, "BOSS DOWN", Color("ffd84f"))
				snd = "elite"
			elif shield:
				shield = false
				msg = "Your shield blocks the boss! It shatters"
				_pop(nc, "BLOCKED", Color("7db2ff"))
				_sfx("shieldbreak")
				walk.clear()
				return
			else:
				pos = nc
				_die("The %s (Lv %d) crushed you" % [th["boss"], bl])
				return
		elif level < req:
			msg = "%s needs Lv %d" % [th["gate"], req]
			_sfx("blocked")
			walk.clear()
			return
	elif vaults.has(nc):
		if keys > 0:
			keys -= 1
			vaults.erase(nc)
			coins += 10
			level += 1
			var got := _random_use()
			var gm := ""
			if _give_use(got):
				gm = " + " + _use_name(got)
			msg = "Vault opened! +10 coins, +1 level%s" % gm
			_pop(nc, "VAULT!", Color("ffd84f"))
			snd = "big"
		else:
			msg = "Locked vault - find the key first"
			_sfx("blocked")
			walk.clear()
			return
	elif items.has(nc):
		var kind: String = items[nc]
		items.erase(nc)
		if kind.begins_with("use_"):
			var uid := kind.substr(4)
			if _give_use(uid):
				msg = "Got %s: %s" % [_use_name(uid), use_defs[uid]["desc"]]
				_pop(nc, _use_name(uid), use_defs[uid]["col"])
				snd = "pot"
			else:
				items[nc] = kind
				msg = "Inventory full! Use a tool first"
				snd = "blocked"
		elif kind == "key":
			keys += 1
			msg = "Key! Find the locked vault"
			_pop(nc, "KEY", Color("ffd84f"))
			snd = "coin"
		elif kind == "pot":
			level += pot_g()
			msg = "%s! Level %d" % [th["pot"], level]
			_pop(nc, "+%d" % pot_g(), Color("ffd84f"))
			snd = "pot"
		elif kind == "big":
			level += big_g()
			msg = "Overcharged %s! Level %d" % [th["pot"], level]
			_pop(nc, "+%d" % big_g(), Color("4fd1ff"))
			snd = "big"
		elif kind == "shield":
			shield = true
			msg = "Shield! It saves you from one losing fight"
			_pop(nc, "SHIELD", Color("7db2ff"))
			snd = "shield"
		else:
			lamp = true
			msg = "Lantern lit! The dark is held back"
			_pop(nc, "LIGHT", Color("ffe9a0"))
			snd = "lamp"
	elif spikes.has(nc):
		extra = spike_x()
		if extra > 0:
			msg = "Spikes! The dark gains %d steps" % extra
			_pop(nc, "OUCH", Color("ff7a7a"))
			snd = "spike"
		else:
			msg = "Heavy Boots shrug off the spikes"
	elif coin_at.has(nc):
		coin_at.erase(nc)
		var cv := coin_val()
		coins += cv
		msg = "Coin! %d total" % coins
		_pop(nc, "+%d coin" % cv, Color("ffc93c"))
		snd = "coin"
	elif portals.has(nc):
		landing = portals[nc]
		if is_dark(landing):
			msg = "The far portal is swallowed by the dark"
			_sfx("blocked")
			walk.clear()
			return
		msg = "Warp!"
		snd = "warp"
	pos = landing
	var before := depth_for(moves)
	moves = mini(moves + 1 + extra, maxd * period)
	if depth_for(moves) > before:
		msg = "The dark swallows the edge!"
		snd = "swallow"
	if is_dark(pos):
		_die("Swallowed by the dark")
		return
	if lamp:
		moves = maxi(moves - lamp_amt(), depth_for(moves) * period)
	if pos == stairs:
		_clear()
		return
	_thief_check()
	if snd == "step" and moves < maxd * period and (depth_for(moves) + 1) * period - moves <= 3:
		snd = "tick"
	_sfx(snd)


func _remove_mon(c: Vector2i) -> void:
	mons.erase(c)
	elite.erase(c)
	kinds.erase(c)
	thief_held.erase(c)


func _kill_free(c: Vector2i) -> void:
	if thief_held.has(c):
		coins += int(thief_held[c])
	_remove_mon(c)


func _thief_check() -> void:
	for c in kinds:
		if String(kinds[c]) != "thief" or not mons.has(c) or thief_held.has(c):
			continue
		if absi(c.x - pos.x) + absi(c.y - pos.y) == 1 and coins > 0:
			var n := mini(coins, 3)
			coins -= n
			thief_held[c] = n
			msg = "A thief stole %d coins! Beat it to get them back" % n
			_pop(c, "-%d coins" % n, Color("ff7a7a"))
			_sfx("spike")


func _die(why: String) -> void:
	if relic_n("phoenix") > 0:
		relics.erase("phoenix")
		_reset_floor()
		msg = "Phoenix Feather burns up! The floor restarts"
		if syn("phoenix", "aegis"):
			level += 1
			msg += " (+1 level)"
		_sfx("shield")
		return
	state = DEAD
	walk.clear()
	aim = -1
	var reached := floor_n - 1
	if reached > best:
		best = reached
	var delta := maxi(0, coins - run_banked)
	delta += int(delta * 0.1 * up("interest"))
	bank += delta
	run_banked += delta
	_save_meta()
	_sfx("death")
	over_title = "YOU DIED"
	over_sub = "%s\nFloors cleared: %d   Best: %d\nBanked +%d coins (total %d)" % [why, reached, best, delta, bank]


func _clear() -> void:
	walk.clear()
	aim = -1
	_sfx("clear")
	over_title = "BOSS DEFEATED" if boss_floor else "FLOOR %d CLEAR" % floor_n
	over_sub = "Next: floor %d" % (floor_n + 1)
	var extra_cards := 0
	if boss_floor:
		coins += 10
		var it := _random_use()
		var tail := ""
		if _give_use(it):
			tail = " + " + _use_name(it)
		over_sub += "  -  +10 coins%s" % tail
		extra_cards += 1
	if fmod == "danger":
		extra_cards += 1
	if fmod == "calm" and not boss_floor:
		relic_choices = []
	else:
		relic_choices = _roll_relics(extra_cards)
	state = RELIC if relic_choices.size() > 0 else CLEAR


func _roll_relics(extra: int) -> Array:
	var normal: Array = []
	var cursed: Array = []
	for d in relic_defs:
		if relic_n(String(d["id"])) < int(d["max"]):
			if d.has("curse"):
				cursed.append(d)
			else:
				normal.append(d)
	normal.shuffle()
	cursed.shuffle()
	var n := 3 + int(ups["lucky"]) + (1 if cls == "gambler" else 0) + extra
	var out: Array = []
	if cursed.size() > 0 and randf() < 0.65:
		out.append(cursed.pop_front())
	if n >= 5 and cursed.size() > 0 and randf() < 0.4:
		out.append(cursed.pop_front())
	while out.size() < n and normal.size() > 0:
		out.append(normal.pop_front())
	while out.size() < n and cursed.size() > 0:
		out.append(cursed.pop_front())
	out.shuffle()
	return out


func _finish_clear() -> void:
	if (floor_n + 1) % 5 == 0:
		_go_floor("standard")
	else:
		door_choices = _roll_doors()
		state = FORK


func _go_floor(fm: String) -> void:
	floor_n += 1
	fmod = fm
	_new_floor()


func _roll_doors() -> Array:
	var pool := ["danger", "calm", "vault", "market"]
	pool.shuffle()
	var doors: Array = ["standard", pool[0]]
	if randf() < 0.7:
		doors.append(pool[1])
	doors.shuffle()
	return doors


func _open_market() -> void:
	var ids := use_defs.keys()
	ids.shuffle()
	market_stock.clear()
	for i in 3:
		market_stock.append({"id": String(ids[i]), "price": maxi(2, randi_range(5, 8) + floor_n / 5 - 2 * up("haggle"))})
	state = MARKET


func _relic_rect(i: int) -> Rect2:
	return Rect2(50, 380 + i * 150, 620, 134)


func _shop_rect(i: int) -> Rect2:
	return Rect2(50, 350 + i * 108, 620, 98)


func _shop_pages() -> int:
	return (shop_defs.size() + 5) / 6


func _class_rect(i: int) -> Rect2:
	return Rect2(50, 270 + i * 190, 620, 172)


func _door_rect(i: int) -> Rect2:
	return Rect2(50, 380 + i * 200, 620, 180)


func _market_rect(i: int) -> Rect2:
	return Rect2(50, 380 + i * 150, 620, 134)


func _slot_rect(i: int) -> Rect2:
	return Rect2(40 + i * 118, 982, 108, 62)


func _blocking(c: Vector2i) -> bool:
	return mons.has(c) or spikes.has(c) or (vaults.has(c) and keys == 0)


func _plan(target: Vector2i) -> void:
	if portals.has(target):
		target = portals[target]
		if target == pos:
			return
	# BFS through free cells; portals are edges; monsters, spikes and locked things are only entered as the final step.
	var dist: Dictionary = {pos: 0}
	var prev: Dictionary = {}
	var via: Dictionary = {}
	var q: Array[Vector2i] = [pos]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while q.size() > 0:
		var c: Vector2i = q.pop_front()
		for d in dirs:
			var n: Vector2i = c + d
			if not in_b(n) or is_dark(n) or walls.has(n) or _blocking(n):
				continue
			if n == stairs and stairs_blocked():
				continue
			var dest := n
			if portals.has(n):
				dest = portals[n]
				if is_dark(dest):
					continue
			if dist.has(dest):
				continue
			dist[dest] = int(dist[c]) + 1
			prev[dest] = c
			if dest != n:
				via[dest] = n
			q.append(dest)
	var goal := target
	var attack := false
	if _blocking(target) or (target == stairs and stairs_blocked()):
		var bestd := 999
		var bestc := Vector2i(-1, -1)
		for d in dirs:
			var n2: Vector2i = target + d
			if dist.has(n2) and int(dist[n2]) < bestd:
				bestd = int(dist[n2])
				bestc = n2
		if bestc.x < 0:
			msg = "Can't reach that"; _sfx("blocked")
			return
		goal = bestc
		attack = true
	elif not dist.has(goal):
		msg = "Can't reach that"; _sfx("blocked")
		return
	var path: Array[Vector2i] = []
	var c2 := goal
	while c2 != pos:
		if via.has(c2):
			path.push_front(via[c2])
		else:
			path.push_front(c2)
		c2 = prev[c2]
	if attack:
		path.append(target)
	walk = path
	walk_t = 0.1


# ----- usable tools -----

func _aim_valid(id: String, c: Vector2i) -> bool:
	if not in_b(c) or is_dark(c):
		return false
	if id == "blink":
		return not walls.has(c) and not mons.has(c) and not vaults.has(c) and c != stairs and c != pos and not portals.has(c)
	if id == "pick":
		return walls.has(c)
	if id == "zap":
		return mons.has(c) and absi(c.x - pos.x) + absi(c.y - pos.y) <= 2 and _mon_level(c) <= level + 1
	return false


func _aim_any(id: String) -> bool:
	for x in N:
		for y in N:
			if _aim_valid(id, Vector2i(x, y)):
				return true
	return false


func _use_slot(i: int) -> void:
	if state != PLAY or i >= inv.size():
		return
	if aim == i:
		aim = -1
		msg = "Cancelled"
		return
	var id: String = inv[i]
	aim = -1
	walk.clear()
	if id == "bomb":
		var hit := 0
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var c := pos + Vector2i(dx, dy)
				if c == pos:
					continue
				if walls.has(c):
					walls.erase(c)
					hit += 1
				if spikes.has(c):
					spikes.erase(c)
					hit += 1
				if mons.has(c) and _mon_level(c) <= level + 1:
					_pop(c, "BOOM", Color("ff7a45"))
					_kill_free(c)
					hit += 1
		if hit == 0:
			msg = "Nothing nearby to blast"
			_sfx("blocked")
			return
		msg = "Boom! Cleared %d things" % hit
		_sfx("spike")
	elif id == "crystal":
		moves = maxi(moves - 6, depth_for(moves) * period)
		msg = "Time Crystal shatters: the dark is held back"
		_sfx("lamp")
	elif id == "draught":
		level += 2
		msg = "Elixir! Level %d" % level
		_pop(pos, "+2", Color("6dff9a"))
		_sfx("big")
	elif id == "cloak":
		if boost > 0:
			msg = "Cloak already active"
			return
		boost = 3
		msg = "Shadow Cloak: your next fight counts +3 levels"
		_sfx("shield")
	elif id == "magnet":
		var n := 0
		for c in coin_at.keys():
			if not is_dark(c):
				coin_at.erase(c)
				n += 1
		if n == 0:
			msg = "No coins to pull in"
			_sfx("blocked")
			return
		coins += n * coin_val()
		msg = "Magnet! +%d coins" % (n * coin_val())
		_sfx("coin")
	else:
		if not _aim_any(id):
			msg = "No valid target right now"
			_sfx("blocked")
			return
		aim = i
		msg = "%s: tap a highlighted tile (tap the tool again to cancel)" % _use_name(id)
		_sfx("ui")
		return
	inv.remove_at(i)


func _aim_apply(c: Vector2i) -> void:
	var id: String = inv[aim]
	if not _aim_valid(id, c):
		msg = "Not a valid target"
		_sfx("blocked")
		return
	inv.remove_at(aim)
	aim = -1
	if id == "blink":
		_sfx("warp")
		_step(c)
	elif id == "pick":
		walls.erase(c)
		_pop(c, "CRACK", Color("c9a55a"))
		msg = "The wall crumbles"
		_sfx("spike")
	elif id == "zap":
		_pop(c, "ZAP", Color("ffe14f"))
		_kill_free(c)
		msg = "Zap!"
		_sfx("elite")


# ----- run flow -----

func _wipe_progress() -> void:
	bank = 0
	best = 0
	for k in ups.keys():
		ups[k] = 0
	reset_armed = -10.0
	_save_meta()
	_sfx("death")


func _new_run(start_floor := 1) -> void:
	floor_n = start_floor
	coins = 0
	run_banked = 0
	relics.clear()
	inv.clear()
	fmod = "standard"
	for id in cdef()["kit"]:
		inv.append(String(id))
	if cls == "gambler":
		var pool: Array = relic_defs.duplicate()
		pool.shuffle()
		for i in 2:
			var d: Dictionary = pool[i]
			relics[d["id"]] = 1
	if up("ash") > 0:
		relics["phoenix"] = 1
	var safe_pool: Array = []
	for d2 in relic_defs:
		if not d2.has("curse") and relic_n(String(d2["id"])) < int(d2["max"]):
			safe_pool.append(d2)
	safe_pool.shuffle()
	for i in mini(up("head"), safe_pool.size()):
		relics[safe_pool[i]["id"]] = relic_n(String(safe_pool[i]["id"])) + 1
	for i in up("toolbox"):
		if inv.size() < slots_n():
			inv.append(_random_use())
	_new_floor()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = event.position
	if btn_sound.has_point(p):
		snd_on = not snd_on
		_apply_sound()
		_sfx("ui")
		return
	if state == CLASS:
		for i in class_defs.size():
			if _class_rect(i).has_point(p):
				cls = String(class_defs[i]["id"])
				_sfx("big")
				_new_run()
				return
		if btn_shop2.has_point(p):
			shop_return = CLASS
			shop_page = 0
			state = SHOP
			_sfx("ui")
		elif btn_wipe.has_point(p):
			if t - reset_armed < 4.0:
				_wipe_progress()
			else:
				reset_armed = t
				_sfx("blocked")
		return
	if state == CLEAR:
		_finish_clear()
		return
	if state == RELIC:
		if btn_skip.has_point(p):
			coins += 3
			_sfx("coin")
			_finish_clear()
			return
		for i in relic_choices.size():
			if _relic_rect(i).has_point(p):
				var id: String = relic_choices[i]["id"]
				relics[id] = relic_n(id) + 1
				_sfx("big")
				_finish_clear()
				return
		return
	if state == FORK:
		for i in door_choices.size():
			if _door_rect(i).has_point(p):
				var dc: String = door_choices[i]
				_sfx("big")
				if dc == "market":
					_open_market()
				else:
					_go_floor(dc)
				return
		return
	if state == MARKET:
		if btn_back.has_point(p):
			_go_floor("standard")
			return
		for i in market_stock.size():
			if _market_rect(i).has_point(p):
				var it: Dictionary = market_stock[i]
				if coins >= int(it["price"]) and inv.size() < slots_n():
					coins -= int(it["price"])
					inv.append(String(it["id"]))
					market_stock.remove_at(i)
					_sfx("coin")
				else:
					_sfx("blocked")
				return
		return
	if state == SHOP:
		if btn_back.has_point(p):
			state = shop_return
			_sfx("ui")
			return
		if btn_prev.has_point(p):
			shop_page = (shop_page + _shop_pages() - 1) % _shop_pages()
			_sfx("ui")
			return
		if btn_next.has_point(p):
			shop_page = (shop_page + 1) % _shop_pages()
			_sfx("ui")
			return
		for i in 6:
			var idx := shop_page * 6 + i
			if idx >= shop_defs.size():
				break
			if _shop_rect(i).has_point(p):
				var d: Dictionary = shop_defs[idx]
				var lv: int = up(String(d["id"]))
				var costs: Array = d["costs"]
				if lv < costs.size() and bank >= int(costs[lv]):
					bank -= int(costs[lv])
					ups[d["id"]] = lv + 1
					_save_meta()
					_sfx("coin")
				else:
					_sfx("blocked")
		return
	if state == DEAD:
		if btn_retry.has_point(p):
			_reset_floor()
			_sfx("ui")
		elif btn_newrun.has_point(p):
			state = CLASS
			_sfx("ui")
		elif btn_shop.has_point(p):
			shop_return = DEAD
			shop_page = 0
			state = SHOP
			_sfx("ui")
		return
	# playing
	if btn_reset.has_point(p):
		_reset_floor()
		_sfx("ui")
		return
	for i in slots_n():
		if _slot_rect(i).has_point(p):
			_use_slot(i)
			return
	if p.x < GX or p.y < GY:
		return
	var cx := int((p.x - GX) / cell)
	var cy := int((p.y - GY) / cell)
	var target := Vector2i(cx, cy)
	if aim >= 0:
		if in_b(target):
			_aim_apply(target)
		return
	if not in_b(target) or target == pos or is_dark(target) or walls.has(target):
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
	var i := pops.size() - 1
	while i >= 0:
		if t - float(pops[i]["t"]) > 0.9:
			pops.remove_at(i)
		i -= 1
	queue_redraw()


# ---------- drawing ----------

func _txt(s: String, p: Vector2, size: int, col: Color, w := 720.0, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	draw_string(font, p, s, align, w, size, col)


func _ctext(s: String, c: Vector2, size: int, col: Color) -> void:
	draw_string(font, Vector2(c.x - 100.0, c.y + size * 0.35), s, HORIZONTAL_ALIGNMENT_CENTER, 200.0, size, col)


func _cell_rect(c: Vector2i) -> Rect2:
	return Rect2(GX + c.x * cell, GY + c.y * cell, cell, cell)


func _spr(tex: Texture2D, ctr: Vector2, size: float, mod := Color.WHITE) -> void:
	draw_texture_rect(tex, Rect2(ctr.x - size * 0.5, ctr.y - size * 0.5, size, size), false, mod)


func _button(r: Rect2, label: String, col: Color, size := 20) -> void:
	draw_rect(r, Color(col.r, col.g, col.b, 0.14))
	draw_rect(r, col, false, 2.0)
	_ctext(label, r.get_center(), size, col)


func _para(s: String, p: Vector2, size: int, col: Color, w: float) -> void:
	draw_multiline_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, w, size, -1, col)


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, Color("5a3d00"), 1.5)


func _draw_spikes(ctr: Vector2) -> void:
	var w := cell * 0.62
	draw_rect(Rect2(ctr.x - w * 0.5, ctr.y - w * 0.32, w, w * 0.64), Color("20242f"))
	for i in 3:
		for j in 2:
			var bx := ctr.x - w * 0.34 + i * w * 0.34
			var by := ctr.y - w * 0.12 + j * w * 0.3
			var tri := PackedVector2Array([Vector2(bx - w * 0.14, by + w * 0.12), Vector2(bx + w * 0.14, by + w * 0.12), Vector2(bx, by - w * 0.16)])
			draw_colored_polygon(tri, Color("c3cad8"))
			var side := PackedVector2Array([Vector2(bx, by - w * 0.16), Vector2(bx + w * 0.14, by + w * 0.12), Vector2(bx, by + w * 0.12)])
			draw_colored_polygon(side, Color("7c8497"))
			draw_circle(Vector2(bx, by - w * 0.14), 1.8, Color("ff5d5d"))


func _draw_vault(ctr: Vector2) -> void:
	var w := cell * 0.7
	draw_rect(Rect2(ctr.x - w * 0.5, ctr.y - w * 0.12, w, w * 0.52), Color("7a4a1e"))
	draw_rect(Rect2(ctr.x - w * 0.5, ctr.y - w * 0.4, w, w * 0.3), Color("9a5f28"))
	draw_rect(Rect2(ctr.x - w * 0.5, ctr.y - w * 0.4, w, w * 0.8), Color("3a2410"), false, 2.0)
	draw_rect(Rect2(ctr.x - w * 0.1, ctr.y - w * 0.4, w * 0.2, w * 0.8), Color("e0b030"))
	draw_circle(ctr + Vector2(0, -w * 0.02), w * 0.1, Color("ffd84f"))
	draw_circle(ctr + Vector2(0, -w * 0.02), w * 0.04, Color("3a2410"))


func _draw_key(ctr: Vector2, s: float) -> void:
	var gold := Color("ffd84f")
	draw_arc(ctr + Vector2(-s * 0.25, 0), s * 0.2, 0, TAU, 16, gold, s * 0.09)
	draw_line(ctr + Vector2(-s * 0.05, 0), ctr + Vector2(s * 0.42, 0), gold, s * 0.09)
	draw_line(ctr + Vector2(s * 0.3, 0), ctr + Vector2(s * 0.3, s * 0.16), gold, s * 0.08)
	draw_line(ctr + Vector2(s * 0.42, 0), ctr + Vector2(s * 0.42, s * 0.12), gold, s * 0.08)


func _use_icon(id: String, c: Vector2, s: float) -> void:
	var col: Color = use_defs[id]["col"]
	var r := s * 0.5
	draw_circle(c, r, Color(0.07, 0.08, 0.13))
	draw_arc(c, r, 0, TAU, 20, col, 2.0)
	if id == "bomb":
		draw_circle(c + Vector2(0, r * 0.12), r * 0.5, Color("2b2f3a"))
		draw_circle(c + Vector2(-r * 0.15, 0), r * 0.1, Color(1, 1, 1, 0.5))
		draw_line(c + Vector2(r * 0.25, -r * 0.3), c + Vector2(r * 0.5, -r * 0.62), Color("c9a55a"), 2.0)
		draw_circle(c + Vector2(r * 0.5, -r * 0.65), r * 0.14, Color("ffd84f"))
	elif id == "crystal":
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.62), c + Vector2(r * 0.42, 0), c + Vector2(0, r * 0.62), c + Vector2(-r * 0.42, 0)]), col)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.62), c + Vector2(-r * 0.42, 0), c + Vector2(-r * 0.1, -r * 0.05)]), col.lightened(0.5))
	elif id == "blink":
		draw_arc(c, r * 0.45, 0.6, 4.6, 14, col, 3.0)
		draw_arc(c, r * 0.22, 3.6, 7.6, 10, Color.WHITE, 2.0)
	elif id == "cloak":
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.58), c + Vector2(r * 0.52, r * 0.58), c + Vector2(-r * 0.52, r * 0.58)]), col)
		draw_circle(c + Vector2(-r * 0.15, -r * 0.05), r * 0.09, Color("151515"))
		draw_circle(c + Vector2(r * 0.15, -r * 0.05), r * 0.09, Color("151515"))
	elif id == "draught":
		draw_circle(c + Vector2(0, r * 0.15), r * 0.42, col)
		draw_rect(Rect2(c.x - r * 0.12, c.y - r * 0.62, r * 0.24, r * 0.42), col.lightened(0.35))
		draw_circle(c + Vector2(-r * 0.12, r * 0.05), r * 0.09, Color(1, 1, 1, 0.6))
	elif id == "magnet":
		draw_arc(c + Vector2(0, -r * 0.02), r * 0.42, PI, TAU, 12, col, r * 0.26)
		draw_rect(Rect2(c.x - r * 0.55, c.y - r * 0.02, r * 0.26, r * 0.55), col)
		draw_rect(Rect2(c.x + r * 0.29, c.y - r * 0.02, r * 0.26, r * 0.55), col)
		draw_rect(Rect2(c.x - r * 0.55, c.y + r * 0.35, r * 0.26, r * 0.18), Color.WHITE)
		draw_rect(Rect2(c.x + r * 0.29, c.y + r * 0.35, r * 0.26, r * 0.18), Color.WHITE)
	elif id == "pick":
		draw_line(c + Vector2(-r * 0.42, r * 0.55), c + Vector2(r * 0.25, -r * 0.35), Color("8a5a2b"), 3.0)
		draw_line(c + Vector2(-r * 0.3, -r * 0.5), c + Vector2(r * 0.6, 0.1 * r), Color("c8cfdc"), 4.0)
	elif id == "zap":
		draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.18, -r * 0.62), c + Vector2(-r * 0.32, r * 0.05), c + Vector2(0, r * 0.05), c + Vector2(-r * 0.16, r * 0.62), c + Vector2(r * 0.34, -r * 0.1), c + Vector2(0, -r * 0.1)]), col)


func _mod_label() -> String:
	if boss_floor:
		return "   BOSS FLOOR"
	if fmod == "danger":
		return "   PERILOUS"
	if fmod == "calm":
		return "   QUIET"
	if fmod == "vault":
		return "   VAULT"
	return ""


func _draw() -> void:
	if themes.is_empty():
		return
	var ti := tidx()
	var th := cur_theme()
	var acc: Color = th["accent"]
	draw_rect(Rect2(0, 0, 720, 1280), th["bg"])
	for s in stars:
		var a := 0.12 + 0.28 * (0.5 + 0.5 * sin(t * 1.5 + float(s[2])))
		var sz: float = s[3]
		var drift := 0.0
		if ti == 1:
			drift = sin(t * 0.7 + float(s[2])) * 6.0
		draw_rect(Rect2(float(s[0]) + drift, float(s[1]), sz, sz), Color(acc.r, acc.g, acc.b, a))
	# HUD
	_button(btn_sound, "SOUND ON" if snd_on else "SOUND OFF", acc)
	_button(btn_reset, "RESET", acc)
	_txt(th["name"], Vector2(0, 62), 28, acc)
	_txt("FLOOR %d    BEST %d%s" % [floor_n, best, _mod_label()], Vector2(0, 112), 24, Color(1, 1, 1, 0.6))
	_txt("LV %d" % level, Vector2(40, 205), 72, Color.WHITE, 300.0, HORIZONTAL_ALIGNMENT_LEFT)
	_txt("COINS %d   BANK %d" % [coins, bank], Vector2(40, 238), 24, Color("ffc93c"), 330.0, HORIZONTAL_ALIGNMENT_LEFT)
	var sx := 40.0
	if shield:
		_spr(_item_tex("shield"), Vector2(sx + 14, 266), 28)
		_txt("SHIELD", Vector2(sx + 32, 272), 18, Color("7db2ff"), 100.0, HORIZONTAL_ALIGNMENT_LEFT)
		sx += 112.0
	if boost > 0:
		_txt("CLOAK +%d" % boost, Vector2(sx, 272), 18, Color("9aa3c7"), 130.0, HORIZONTAL_ALIGNMENT_LEFT)
		sx += 120.0
	if keys > 0:
		_draw_key(Vector2(sx + 14, 266), 26)
		_txt("KEY x%d" % keys, Vector2(sx + 36, 272), 18, Color("ffd84f"), 100.0, HORIZONTAL_ALIGNMENT_LEFT)
	var depth := depth_for(moves)
	var dark_txt := "DARK FINAL"
	var frac := 1.0
	var left := 0
	var cap := maxd * period
	if moves < cap:
		left = (depth + 1) * period - moves
		frac = 1.0 - float(left) / period
		dark_txt = "DARK IN %d" % left
	var warn := moves < cap and left <= 3
	var dcol := Color("ff5d5d") if warn else acc
	_txt(dark_txt, Vector2(360, 200), 44, dcol, 320.0, HORIZONTAL_ALIGNMENT_RIGHT)
	draw_rect(Rect2(380, 218, 300, 14), Color(1, 1, 1, 0.12))
	draw_rect(Rect2(380, 218, 300 * frac, 14), dcol)
	if boss_floor:
		var hint := "steady"
		if boss_kind == "colossus":
			hint = "+2 per ring of dark"
		elif boss_kind == "king":
			hint = "+6 once the dark moves"
		_txt("BOSS %s: Lv %d (%s)" % [th["boss"], _boss_level(moves), hint], Vector2(0, 306), 24, Color("ffd84f") if level + boost > _boss_level(moves) else Color("ff8a8a"))
	else:
		_txt("%s: Lv %d" % [th["gate"], req], Vector2(0, 306), 26, Color.WHITE if level >= req else Color(1, 1, 1, 0.55))
	# grid
	var names: Array = th["mons"]
	var wall_tex := _wall_tex(ti)
	for x in N:
		for y in N:
			var c := Vector2i(x, y)
			var r := _cell_rect(c)
			if is_dark(c):
				draw_rect(r, th["dark"])
				continue
			draw_texture_rect(_floor_tex(ti, (x + y) % 2, (x * 7 + y * 3) % 3), r.grow(-1.0), false)
			if ring(c) == depth:
				draw_rect(r.grow(-1.0), Color(0, 0, 0, 0.28))
				if warn:
					draw_rect(r.grow(-1.0), Color(1, 0.2, 0.2, 0.12 + 0.12 * sin(t * 8.0)))
			var ctr := r.get_center()
			var bob := sin(t * 3.0 + x * 1.7 + y) * 2.0
			if walls.has(c):
				draw_texture_rect(wall_tex, r.grow(-1.0), false)
			elif c == stairs:
				if boss_floor:
					continue
				var ok := level >= req
				var dc := Color("6dff9a") if ok else Color(1, 1, 1, 0.4)
				var hw := cell * 0.28
				var hh := cell * 0.38
				draw_rect(Rect2(ctr.x - hw, ctr.y - hh, hw * 2, hh * 2), Color(dc.r, dc.g, dc.b, 0.16))
				draw_rect(Rect2(ctr.x - hw, ctr.y - hh, hw * 2, hh * 2), dc, false, 4.0)
				draw_rect(Rect2(ctr.x - hw + 6, ctr.y - hh + 6, hw * 2 - 12, hh * 2 - 12), Color(dc.r, dc.g, dc.b, 0.35), false, 1.5)
				_ctext("Lv %d" % req, ctr, int(cell * 0.24), dc)
			elif mons.has(c):
				var base_lv: int = mons[c]
				var lv: int = _mon_level(c)
				var kind := String(kinds.get(c, ""))
				var asleep := kind == "sleeper" and depth < 1
				var is_boss := c == boss_cell
				var safe := level + boost > lv
				var mc := Color("49d17a") if safe else (Color("ffb02e") if shield else Color("ef4b55"))
				var sz := cell * (0.92 if is_boss else 0.8)
				if is_boss:
					draw_circle(ctr, cell * 0.5, Color(acc.r, acc.g, acc.b, 0.12 + 0.08 * sin(t * 3.0)))
				draw_circle(ctr + Vector2(0, cell * 0.3), cell * 0.28, Color(0, 0, 0, 0.3))
				var mmod := Color(0.62, 0.7, 1.0) if asleep else Color.WHITE
				_spr(_monster_tex(ti, base_lv, is_boss), ctr + Vector2(0, 0 if asleep else bob), sz, mmod)
				if elite.has(c):
					_star(Vector2(r.position.x + cell * 0.2, r.position.y + cell * 0.2 + bob), cell * 0.16, Color("ffd84f"))
				var bp := Vector2(r.end.x - cell * 0.2, r.position.y + cell * 0.2)
				draw_circle(bp, cell * 0.17, Color("0a0c14"))
				draw_circle(bp, cell * 0.145, mc)
				_ctext(str(lv), bp, int(cell * 0.22), Color.WHITE)
				var mk := Vector2(r.position.x + cell * 0.2, r.end.y - cell * 0.2)
				if kind == "sleeper":
					if asleep:
						_ctext("zZ", mk, int(cell * 0.26), Color("9ec0ff"))
						_ctext("wakes at %d" % (base_lv + sleeper_bonus()), Vector2(r.end.x - cell * 0.3, r.end.y - 8), 12, Color("ffb02e"))
					else:
						_ctext("!", mk, int(cell * 0.3), Color("ff5d5d"))
				elif kind == "feeder":
					draw_circle(mk, cell * 0.13, Color("5a1f8a"))
					_ctext("+", mk, int(cell * 0.24), Color("e6b3ff"))
					_ctext("feeds on dark", Vector2(r.end.x - cell * 0.38, r.end.y - 8), 11, Color("c07cff"))
				elif kind == "thief":
					draw_circle(mk, cell * 0.13, Color("5a4500"))
					_ctext("$", mk, int(cell * 0.24), Color("ffd84f"))
					if thief_held.has(c):
						_ctext("holds %d" % int(thief_held[c]), Vector2(r.end.x - cell * 0.32, r.end.y - 8), 12, Color("ff7a7a"))
					else:
						_ctext("steals coins", Vector2(r.end.x - cell * 0.38, r.end.y - 8), 11, Color("ffd84f"))
				elif N <= 7:
					_txt(names[(base_lv - 1) % names.size()], Vector2(r.position.x, r.end.y - 5), 13, Color(1, 1, 1, 0.65), cell)
			elif vaults.has(c):
				_draw_vault(ctr + Vector2(0, bob * 0.3))
				_txt("vault", Vector2(r.position.x, r.end.y - 6), 13, Color("ffd84f"), cell)
			elif items.has(c):
				var kind2: String = items[c]
				draw_circle(ctr + Vector2(0, cell * 0.25), cell * 0.2, Color(0, 0, 0, 0.25))
				if kind2.begins_with("use_"):
					var uid := kind2.substr(4)
					_use_icon(uid, ctr + Vector2(0, bob), cell * 0.55)
					_txt(_use_name(uid), Vector2(r.position.x, r.end.y - 6), 11, use_defs[uid]["col"], cell)
				elif kind2 == "key":
					_draw_key(ctr + Vector2(0, bob), cell * 0.8)
					_txt("key", Vector2(r.position.x, r.end.y - 6), 13, Color("ffd84f"), cell)
				else:
					_spr(_item_tex(kind2), ctr + Vector2(0, bob), cell * 0.58)
					if kind2 == "pot":
						_txt("+%d" % pot_g(), Vector2(r.position.x, r.end.y - 6), 15, Color("ffd84f"), cell)
					elif kind2 == "big":
						_txt("+%d" % big_g(), Vector2(r.position.x, r.end.y - 6), 15, Color("4fd1ff"), cell)
					elif kind2 == "shield":
						_txt("shield", Vector2(r.position.x, r.end.y - 6), 13, Color("7db2ff"), cell)
					else:
						_txt("light", Vector2(r.position.x, r.end.y - 6), 13, Color("ffe9a0"), cell)
			elif spikes.has(c):
				_draw_spikes(ctr)
			elif coin_at.has(c):
				_spr(_item_tex("coin"), ctr + Vector2(0, bob), cell * 0.42)
			elif portals.has(c):
				var pc := Color("c07cff")
				draw_circle(ctr, cell * 0.34, Color(pc.r, pc.g, pc.b, 0.18))
				draw_arc(ctr, cell * 0.32, t * 3.0, t * 3.0 + PI * 1.3, 18, pc, 4.0)
				draw_arc(ctr, cell * 0.2, -t * 4.0, -t * 4.0 + PI * 1.3, 14, Color("e6c8ff"), 3.0)
				draw_circle(ctr, cell * 0.07, pc)
	# boss on top of its cell
	if boss_floor:
		var br := _cell_rect(stairs)
		var bc := br.get_center()
		var bl := _boss_level(moves)
		var bsafe := level + boost > bl
		draw_circle(bc, cell * 0.85, Color(acc.r, acc.g, acc.b, 0.14 + 0.08 * sin(t * 2.5)))
		draw_circle(bc + Vector2(0, cell * 0.45), cell * 0.5, Color(0, 0, 0, 0.35))
		_spr(_monster_tex(ti, 9 + (floor_n / 5) % 3, true), bc + Vector2(0, -cell * 0.1 + sin(t * 2.0) * 3.0), cell * 1.6)
		var bp2 := bc + Vector2(cell * 0.62, -cell * 0.62)
		draw_circle(bp2, cell * 0.26, Color("0a0c14"))
		draw_circle(bp2, cell * 0.22, Color("49d17a") if bsafe else Color("ef4b55"))
		_ctext(str(bl), bp2, int(cell * 0.3), Color.WHITE)
	# aim highlights
	if aim >= 0 and aim < inv.size():
		var aid: String = inv[aim]
		for x in N:
			for y in N:
				var ac := Vector2i(x, y)
				if _aim_valid(aid, ac):
					var ar := _cell_rect(ac).grow(-3)
					draw_rect(ar, Color(1, 0.88, 0.3, 0.15 + 0.1 * sin(t * 8.0)))
					draw_rect(ar, Color("ffe14f"), false, 3.0)
	# player
	var prc := _cell_rect(pos).get_center()
	draw_circle(prc + Vector2(0, cell * 0.3), cell * 0.25, Color(0, 0, 0, 0.35))
	if shield:
		draw_arc(prc, cell * 0.46, 0, TAU, 28, Color(0.5, 0.7, 1.0, 0.5 + 0.2 * sin(t * 5.0)), 3.0)
	if boost > 0:
		draw_arc(prc, cell * 0.52, 0, TAU, 28, Color(0.7, 0.72, 0.9, 0.5), 2.0)
	_spr(_player_tex(), prc + Vector2(0, sin(t * 4.0) * 2.0), cell * 0.78)
	# floating pops
	for pp in pops:
		var age: float = t - float(pp["t"])
		var pcol: Color = pp["c"]
		pcol.a = 1.0 - age / 0.9
		var pp_pos: Vector2 = pp["p"]
		_ctext(pp["s"], pp_pos + Vector2(0, -cell * 0.3 - age * 50.0), 26, pcol)
	# tool slots
	for i in slots_n():
		var sr := _slot_rect(i)
		var has := i < inv.size()
		var scol := Color(1, 1, 1, 0.25)
		if has:
			scol = use_defs[inv[i]]["col"]
		if aim == i:
			scol = Color("ffe14f")
		draw_rect(sr, Color(scol.r, scol.g, scol.b, 0.12))
		draw_rect(sr, scol, false, 2.0)
		if has:
			_use_icon(inv[i], Vector2(sr.position.x + 25, sr.position.y + 31), 38)
			draw_multiline_string(font, Vector2(sr.position.x + 50, sr.position.y + 26), _use_name(inv[i]), HORIZONTAL_ALIGNMENT_LEFT, 56, 13, 3, Color.WHITE)
		else:
			_ctext("empty", sr.get_center(), 14, Color(1, 1, 1, 0.3))
	_txt("TOOLS: tap one to use it", Vector2(40 + slots_n() * 118 + 8, 1020), 17, Color(1, 1, 1, 0.45), 300.0, HORIZONTAL_ALIGNMENT_LEFT)
	# footer
	_txt(msg, Vector2(0, 1084), 26, Color.WHITE, 720.0)
	_txt("Green badge = you win the fight. Red = you die. Equal loses!", Vector2(0, 1122), 22, Color(1, 1, 1, 0.55))
	_txt("Gold star = +2 levels. Shield saves you once. Spikes cost steps.", Vector2(0, 1150), 22, Color(1, 1, 1, 0.55))
	var tips := [
		"Sleepers (zZ) gain levels once the dark first moves. Kill them early!",
		"Feeders (violet +) grow +1 level every time the dark advances.",
		"Thieves ($) steal coins when you stand beside them. Beat one to get them back.",
		"Coins are banked when you die and buy permanent upgrades in the SHOP.",
		"Relics last the whole run. Cursed ones are powerful but risky.",
		"A key opens a vault: coins, +1 level and a free tool.",
		"Every 5th floor is a boss. Read its rule in the line under the dark meter.",
		"Portals warp you. Lanterns hold the dark back.",
	]
	_txt(tips[int(t / 5.0) % tips.size()], Vector2(0, 1180), 20, Color(acc.r, acc.g, acc.b, 0.85))
	_txt("Tap a tile to walk there. The dark eats the outer ring.", Vector2(0, 1208), 22, Color(1, 1, 1, 0.55))
	if relics.size() > 0:
		var parts: Array[String] = []
		for d in relic_defs:
			var n := relic_n(String(d["id"]))
			if n > 0:
				parts.append(String(d["name"]) + (" x%d" % n if n > 1 else ""))
		_para("RELICS: " + ", ".join(parts), Vector2(20, 1240), 15, Color(1, 1, 1, 0.6), 680.0)
	if state != PLAY:
		_draw_overlay(acc)


func _draw_overlay(acc: Color) -> void:
	draw_rect(Rect2(0, 0, 720, 1280), Color(0, 0, 0, 0.9))
	if state == DEAD:
		_txt(over_title, Vector2(0, 540), 64, Color("ff5d5d"))
		var ly := 620
		for line in over_sub.split("\n"):
			_txt(line, Vector2(0, ly), 28, Color.WHITE)
			ly += 42
		_button(btn_retry, "RETRY THIS FLOOR", acc, 28)
		_button(btn_newrun, "NEW RUN", Color("ff9d9d"), 28)
		_button(btn_shop, "SHOP  (bank %d)" % bank, Color("ffc93c"), 28)
	elif state == CLEAR:
		_txt(over_title, Vector2(0, 560), 64, acc)
		_txt(over_sub, Vector2(0, 630), 26, Color.WHITE)
		_txt("Tap to continue", Vector2(0, 700), 28, Color(1, 1, 1, 0.6))
	elif state == RELIC:
		_txt(over_title, Vector2(0, 230), 52, acc)
		_txt(over_sub, Vector2(0, 276), 22, Color(1, 1, 1, 0.7))
		_txt("Choose a relic for the rest of the run", Vector2(0, 340), 28, Color.WHITE)
		for i in relic_choices.size():
			var d: Dictionary = relic_choices[i]
			var rr := _relic_rect(i)
			var cursed := d.has("curse")
			var col := Color("ff6a5c") if cursed else acc
			draw_rect(rr, Color(col.r, col.g, col.b, 0.12))
			draw_rect(rr, col, false, 2.0)
			var own := relic_n(String(d["id"]))
			var title := String(d["name"]) + ("   (you have %d)" % own if own > 0 else "")
			_txt(title, Vector2(rr.position.x + 22, rr.position.y + 40), 30, col, rr.size.x - 40, HORIZONTAL_ALIGNMENT_LEFT)
			if cursed:
				_txt("CURSED", Vector2(rr.end.x - 150, rr.position.y + 40), 22, Color("ff6a5c"), 130.0, HORIZONTAL_ALIGNMENT_RIGHT)
			_para(String(d["desc"]), Vector2(rr.position.x + 22, rr.position.y + 74), 21, Color.WHITE, rr.size.x - 44)
			for sy in synergies:
				var other := ""
				if sy["a"] == d["id"]:
					other = String(sy["b"])
				elif sy["b"] == d["id"]:
					other = String(sy["a"])
				if other != "":
					var have := relic_n(other) > 0
					var oname := other
					for dd in relic_defs:
						if dd["id"] == other:
							oname = String(dd["name"])
					var stxt := ("SYNERGY ACTIVE: " + String(sy["text"])) if have else ("Synergy with %s: %s" % [oname, sy["text"]])
					_txt(stxt, Vector2(rr.position.x + 22, rr.end.y - 10), 16, Color("ffd84f") if have else Color(1, 1, 1, 0.45), rr.size.x - 44, HORIZONTAL_ALIGNMENT_LEFT)
					break
		_button(btn_skip, "SKIP  (+3 coins)", Color(1, 1, 1, 0.75), 26)
	elif state == FORK:
		_txt("CHOOSE YOUR PATH", Vector2(0, 250), 54, acc)
		_txt("Floor %d awaits" % (floor_n + 1), Vector2(0, 310), 26, Color(1, 1, 1, 0.7))
		for i in door_choices.size():
			var dd: Dictionary = door_defs[String(door_choices[i])]
			var dr := _door_rect(i)
			var dcol: Color = dd["col"]
			draw_rect(dr, Color(dcol.r, dcol.g, dcol.b, 0.12))
			draw_rect(dr, dcol, false, 3.0)
			draw_rect(Rect2(dr.position.x + 24, dr.position.y + 28, 60, 120), Color(dcol.r, dcol.g, dcol.b, 0.25))
			draw_rect(Rect2(dr.position.x + 24, dr.position.y + 28, 60, 120), dcol, false, 3.0)
			_txt(String(dd["name"]), Vector2(dr.position.x + 110, dr.position.y + 62), 36, dcol, 480.0, HORIZONTAL_ALIGNMENT_LEFT)
			_para(String(dd["desc"]), Vector2(dr.position.x + 110, dr.position.y + 106), 23, Color.WHITE, 480.0)
	elif state == MARKET:
		_txt("MERCHANT", Vector2(0, 250), 56, Color("c07cff"))
		_txt("Your coins: %d      Tool slots: %d / %d" % [coins, inv.size(), slots_n()], Vector2(0, 310), 26, Color("ffc93c"))
		for i in market_stock.size():
			var it: Dictionary = market_stock[i]
			var mr := _market_rect(i)
			var uid: String = it["id"]
			var can := coins >= int(it["price"]) and inv.size() < slots_n()
			var mcol := Color("6dff9a") if can else Color(1, 1, 1, 0.4)
			draw_rect(mr, Color(mcol.r, mcol.g, mcol.b, 0.1))
			draw_rect(mr, mcol, false, 2.0)
			_use_icon(uid, Vector2(mr.position.x + 56, mr.position.y + 67), 70)
			_txt(_use_name(uid), Vector2(mr.position.x + 110, mr.position.y + 50), 30, Color.WHITE, 340.0, HORIZONTAL_ALIGNMENT_LEFT)
			_para(String(use_defs[uid]["desc"]), Vector2(mr.position.x + 110, mr.position.y + 84), 19, Color(1, 1, 1, 0.75), 340.0)
			_txt("%d coins" % int(it["price"]), Vector2(mr.end.x - 170, mr.position.y + 76), 28, mcol, 150.0, HORIZONTAL_ALIGNMENT_RIGHT)
		if market_stock.is_empty():
			_txt("Sold out!", Vector2(0, 520), 32, Color(1, 1, 1, 0.6))
		_button(btn_back, "LEAVE", acc, 28)
	elif state == CLASS:
		_txt("CHOOSE YOUR CLASS", Vector2(0, 180), 52, acc)
		_txt("Best: %d floors   Bank: %d coins" % [best, bank], Vector2(0, 230), 24, Color(1, 1, 1, 0.6))
		for i in class_defs.size():
			var cd: Dictionary = class_defs[i]
			var cr := _class_rect(i)
			var ccol: Color = cd["col"]
			draw_rect(cr, Color(ccol.r, ccol.g, ccol.b, 0.12))
			draw_rect(cr, ccol, false, 3.0)
			_txt(String(cd["name"]), Vector2(cr.position.x + 24, cr.position.y + 54), 40, ccol, 500.0, HORIZONTAL_ALIGNMENT_LEFT)
			_para(String(cd["desc"]), Vector2(cr.position.x + 24, cr.position.y + 98), 23, Color.WHITE, 570.0)
			var kx := cr.end.x - 40.0
			for kid in cd["kit"]:
				_use_icon(String(kid), Vector2(kx, cr.position.y + 40), 44)
				kx -= 56.0
		_button(btn_shop2, "SHOP  (bank %d)" % bank, Color("ffc93c"), 28)
		var armed := t - reset_armed < 4.0
		_button(btn_wipe, "TAP AGAIN: ERASE ALL PROGRESS" if armed else "RESET ALL PROGRESS", Color("ff5d5d") if armed else Color(1, 1, 1, 0.4), 20)
	elif state == SHOP:
		_txt("SHOP", Vector2(0, 230), 56, Color("ffc93c"))
		_txt("Bank: %d coins      Page %d / %d" % [bank, shop_page + 1, _shop_pages()], Vector2(0, 290), 26, Color.WHITE)
		for i in 6:
			var idx := shop_page * 6 + i
			if idx >= shop_defs.size():
				break
			var d2: Dictionary = shop_defs[idx]
			var rr2 := _shop_rect(i)
			var lv: int = up(String(d2["id"]))
			var costs: Array = d2["costs"]
			var maxed := lv >= costs.size()
			var can2 := (not maxed) and bank >= int(costs[lv])
			var col2 := Color("6dff9a") if can2 else Color(1, 1, 1, 0.45)
			draw_rect(rr2, Color(col2.r, col2.g, col2.b, 0.1))
			draw_rect(rr2, col2, false, 2.0)
			_txt("%s  (%d/%d)" % [d2["name"], lv, costs.size()], Vector2(rr2.position.x + 20, rr2.position.y + 38), 26, Color.WHITE, 420.0, HORIZONTAL_ALIGNMENT_LEFT)
			_txt(String(d2["desc"]), Vector2(rr2.position.x + 20, rr2.position.y + 76), 19, Color(1, 1, 1, 0.7), 440.0, HORIZONTAL_ALIGNMENT_LEFT)
			var ptxt := "MAXED" if maxed else "%d coins" % int(costs[lv])
			_txt(ptxt, Vector2(rr2.end.x - 170, rr2.position.y + 62), 26, col2, 150.0, HORIZONTAL_ALIGNMENT_RIGHT)
		_button(btn_prev, "< PREV", acc, 24)
		_button(btn_next, "NEXT >", acc, 24)
		_button(btn_back, "BACK", acc, 26)
	_button(btn_sound, "SOUND ON" if snd_on else "SOUND OFF", acc)


# ---------- audio (all synthesized in code) ----------

func _setup_audio() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -11.0
	add_child(music_player)
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.volume_db = -3.0
		add_child(p)
		sfx_players.append(p)
	_make_sfx()


func _apply_sound() -> void:
	if music_player:
		music_player.volume_db = -11.0 if snd_on else -80.0


func _sfx(n: String) -> void:
	if not snd_on or not sfx_cache.has(n):
		return
	var chosen: AudioStreamPlayer = sfx_players[0]
	for p in sfx_players:
		if not p.playing:
			chosen = p
			break
	chosen.stream = sfx_cache[n]
	chosen.pitch_scale = randf_range(0.97, 1.04) if n == "step" else 1.0
	chosen.play()


func _midi(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


func _osc(kind: int, ph: float) -> float:
	var f := ph - floorf(ph)
	if kind == 0:
		return sin(f * TAU)
	if kind == 1:
		return 4.0 * absf(f - 0.5) - 1.0
	if kind == 2:
		return 0.6 if f < 0.5 else -0.6
	return (2.0 * f - 1.0) * 0.6


func _add_note(buf: PackedFloat32Array, rate: int, t0: float, dur: float, freq: float, vol: float, kind: int, decay: float, pad := false, wrap := false) -> void:
	var i0 := int(t0 * rate)
	var n := int(dur * rate)
	var size := buf.size()
	for i in n:
		var idx := i0 + i
		if idx >= size:
			if wrap:
				idx = idx % size
			else:
				break
		var tt := float(i) / rate
		var env := 0.0
		if pad:
			env = sin(PI * float(i) / n)
		else:
			env = exp(-decay * tt) * minf(1.0, tt / 0.004) * minf(1.0, float(n - i) / (0.02 * rate))
		buf[idx] += _osc(kind, freq * tt) * vol * env


func _add_sweep(buf: PackedFloat32Array, rate: int, t0: float, dur: float, f0: float, f1: float, vol: float, kind: int, decay: float) -> void:
	var i0 := int(t0 * rate)
	var n := int(dur * rate)
	var ph := 0.0
	for i in n:
		var idx := i0 + i
		if idx >= buf.size():
			break
		var tt := float(i) / rate
		ph += lerpf(f0, f1, float(i) / n) / rate
		var env := exp(-decay * tt) * minf(1.0, tt / 0.004) * minf(1.0, float(n - i) / (0.01 * rate))
		buf[idx] += _osc(kind, ph) * vol * env


func _add_noise(buf: PackedFloat32Array, rate: int, t0: float, dur: float, vol: float, decay: float, lp: float, wrap := false) -> void:
	var i0 := int(t0 * rate)
	var n := int(dur * rate)
	var y := 0.0
	for i in n:
		var idx := i0 + i
		if idx >= buf.size():
			if wrap:
				idx = idx % buf.size()
			else:
				break
		y += (randf() * 2.0 - 1.0 - y) * lp
		buf[idx] += y * vol * exp(-decay * float(i) / rate)


func _stream(buf: PackedFloat32Array, rate: int, loop := false) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 30000.0))
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w


func _buf(dur: float, rate: int) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(dur * rate))
	return b


func _sfx_notes(freqs: Array, nd: float, vol: float, kind: int, decay: float) -> AudioStreamWAV:
	var b := _buf(nd * freqs.size() + 0.25, SR_SFX)
	for i in freqs.size():
		_add_note(b, SR_SFX, i * nd, nd * 1.8, float(freqs[i]), vol, kind, decay)
	return _stream(b, SR_SFX)


func _sfx_sweep(dur: float, f0: float, f1: float, vol: float, kind: int, decay: float) -> AudioStreamWAV:
	var b := _buf(dur + 0.02, SR_SFX)
	_add_sweep(b, SR_SFX, 0.0, dur, f0, f1, vol, kind, decay)
	return _stream(b, SR_SFX)


func _make_sfx() -> void:
	var d := sfx_cache
	d["step"] = _sfx_sweep(0.07, 330.0, 220.0, 0.3, 0, 25.0)
	d["tick"] = _sfx_notes([988.0], 0.07, 0.22, 2, 28.0)
	d["win"] = _sfx_notes([392.0, 523.0, 659.0], 0.07, 0.35, 1, 9.0)
	d["elite"] = _sfx_notes([392.0, 523.0, 659.0, 784.0, 1047.0], 0.06, 0.35, 1, 8.0)
	d["pot"] = _sfx_notes([659.0, 880.0, 1175.0], 0.06, 0.3, 0, 10.0)
	d["big"] = _sfx_notes([523.0, 659.0, 784.0, 1047.0, 1319.0], 0.055, 0.3, 0, 8.0)
	d["coin"] = _sfx_notes([988.0, 1319.0], 0.06, 0.2, 2, 14.0)
	d["shield"] = _sfx_sweep(0.3, 500.0, 1500.0, 0.22, 3, 5.0)
	d["lamp"] = _sfx_sweep(0.4, 260.0, 880.0, 0.3, 0, 3.0)
	d["blocked"] = _sfx_notes([150.0], 0.12, 0.3, 2, 12.0)
	d["ui"] = _sfx_notes([700.0, 900.0], 0.04, 0.25, 0, 20.0)
	var b := _buf(0.4, SR_SFX)
	_add_sweep(b, SR_SFX, 0.0, 0.18, 300.0, 1300.0, 0.25, 1, 4.0)
	_add_sweep(b, SR_SFX, 0.18, 0.18, 1300.0, 300.0, 0.25, 1, 4.0)
	d["warp"] = _stream(b, SR_SFX)
	b = _buf(0.3, SR_SFX)
	_add_noise(b, SR_SFX, 0.0, 0.22, 0.5, 12.0, 0.5)
	_add_sweep(b, SR_SFX, 0.0, 0.2, 220.0, 80.0, 0.25, 3, 6.0)
	d["spike"] = _stream(b, SR_SFX)
	b = _buf(0.4, SR_SFX)
	_add_noise(b, SR_SFX, 0.0, 0.25, 0.4, 10.0, 0.9)
	_add_sweep(b, SR_SFX, 0.0, 0.3, 1000.0, 200.0, 0.2, 2, 6.0)
	d["shieldbreak"] = _stream(b, SR_SFX)
	b = _buf(0.75, SR_SFX)
	_add_noise(b, SR_SFX, 0.0, 0.7, 0.6, 3.0, 0.12)
	_add_sweep(b, SR_SFX, 0.0, 0.7, 140.0, 45.0, 0.5, 0, 2.0)
	d["swallow"] = _stream(b, SR_SFX)
	b = _buf(1.0, SR_SFX)
	_add_sweep(b, SR_SFX, 0.0, 0.9, 440.0, 90.0, 0.35, 3, 2.2)
	_add_noise(b, SR_SFX, 0.0, 0.5, 0.2, 5.0, 0.3)
	d["death"] = _stream(b, SR_SFX)
	b = _buf(1.4, SR_SFX)
	var fan := [523.0, 659.0, 784.0, 1047.0, 1319.0, 1568.0]
	for i in fan.size():
		_add_note(b, SR_SFX, i * 0.09, 0.4, float(fan[i]), 0.3, 1, 5.0)
	_add_note(b, SR_SFX, 0.55, 0.8, 1047.0, 0.18, 0, 3.0)
	_add_note(b, SR_SFX, 0.55, 0.8, 1319.0, 0.18, 0, 3.0)
	d["clear"] = _stream(b, SR_SFX)


func _play_music(ti: int) -> void:
	if music_player == null:
		return
	if music_theme == ti and music_player.playing:
		return
	if music_cache.has(ti):
		music_theme = ti
		music_player.stream = music_cache[ti]
		music_player.play()
		return
	if music_building.has(ti):
		return
	music_building[ti] = true
	var s: AudioStreamWAV = await _build_music(ti)
	music_cache[ti] = s
	music_building.erase(ti)
	if tidx() == ti or music_theme == -1:
		music_theme = ti
		music_player.stream = s
		music_player.play()


func _build_music(ti: int) -> AudioStreamWAV:
	var cfgs := [
		{"bpm": 84.0, "kind": 1, "vol": 0.24, "pat": [0, 1, 2, 3, 2, 1, 2, 1],
			"ch": [[45, [57, 60, 64, 69]], [41, [53, 57, 60, 65]], [48, [55, 60, 64, 67]], [43, [50, 55, 59, 67]]]},
		{"bpm": 96.0, "kind": 0, "vol": 0.32, "pat": [0, 2, 1, 3, 2, 3, 1, 2],
			"ch": [[36, [60, 64, 67, 72]], [45, [57, 60, 64, 69]], [41, [60, 65, 69, 72]], [43, [59, 62, 67, 71]]]},
		{"bpm": 100.0, "kind": 2, "vol": 0.12, "pat": [0, 1, 2, 1, 3, 2, 1, 2],
			"ch": [[38, [62, 65, 69, 74]], [34, [58, 62, 65, 70]], [36, [60, 64, 67, 72]], [33, [57, 61, 64, 69]]]},
	]
	var cfg: Dictionary = cfgs[ti % cfgs.size()]
	var bpm: float = cfg["bpm"]
	var kind: int = cfg["kind"]
	var avol: float = cfg["vol"]
	var pat: Array = cfg["pat"]
	var chords: Array = cfg["ch"]
	var beat := 60.0 / bpm
	var eighth := beat / 2.0
	var buf := _buf(16.0 * beat, SR_MUS)
	for bar in 4:
		var chord: Array = chords[bar]
		var bass: int = chord[0]
		var arp: Array = chord[1]
		var tb := bar * 4.0 * beat
		_add_note(buf, SR_MUS, tb, 4.0 * beat, _midi(float(int(arp[0]) - 12)), 0.1, 0, 0.0, true, true)
		_add_note(buf, SR_MUS, tb, 4.0 * beat, _midi(float(int(arp[2]) - 12)), 0.06, 0, 0.0, true, true)
		await get_tree().process_frame
		_add_note(buf, SR_MUS, tb, beat * 1.8, _midi(float(bass)), 0.32, 1, 2.5, false, true)
		_add_note(buf, SR_MUS, tb + 2.0 * beat, beat * 1.8, _midi(float(bass)), 0.28, 1, 2.5, false, true)
		for e in 8:
			var nidx: int = pat[e]
			_add_note(buf, SR_MUS, tb + e * eighth, eighth * 2.4, _midi(float(int(arp[nidx]))), avol, kind, 7.0, false, true)
			if e % 2 == 1:
				_add_noise(buf, SR_MUS, tb + e * eighth, 0.03, 0.04, 80.0, 0.9, true)
			if e % 4 == 3:
				await get_tree().process_frame
	var peak := 0.001
	for i in buf.size():
		peak = maxf(peak, absf(buf[i]))
	if peak > 0.6:
		var k := 0.6 / peak
		for i in buf.size():
			buf[i] *= k
	return _stream(buf, SR_MUS, true)


# ---------- headless check ----------

func _self_test() -> void:
	_make_sfx()
	var mus: AudioStreamWAV = await _build_music(0)
	var nz := 0
	for i in range(0, mus.data.size(), 2):
		if mus.data.decode_s16(i) != 0:
			nz += 1
	var st: AudioStreamWAV = sfx_cache["win"]
	var nz2 := 0
	for i in range(0, st.data.size(), 2):
		if st.data.decode_s16(i) != 0:
			nz2 += 1
	print("audio ok sfx=%d music_nonzero=%d win_nonzero=%d" % [sfx_cache.size(), nz, nz2])
	var bad := 0
	for f in range(1, 31):
		floor_n = f
		relics.clear()
		ups = {"vet": 0, "iron": 0, "packed": 0, "lucky": 0}
		cls = ["scout", "brute", "mystic", "gambler"][f % 4]
		fmod = ["standard", "danger", "calm", "vault"][(f / 2) % 4]
		if f > 6:
			relics = {"vanguard": 2, "slowdark": 1, "aegis": 1, "boots": 1, "alchemist": 1, "lantern": 1, "skeleton": 1}
			ups = {"vet": 2, "iron": 3, "packed": 1, "lucky": 1}
		if f > 14 and f % 2 == 0:
			relics["glass"] = 1
			relics["greedy"] = 1
			relics["blade"] = 1
			relics["ember"] = 1
		_setup_size()
		var t0 := Time.get_ticks_msec()
		var tries := 0
		var ok := false
		while tries < 24 and not ok:
			_random_layout(tries)
			tries += 1
			ok = _solvable()
		print("floor %d N %d %s cls %s fmod %s boss %s(%s %d) vault %d tries %d solvable %s req %d mons %d %dms" % [f, N, cur_theme()["name"].substr(0, 6), cls, fmod, boss_floor, boss_kind, boss_base, vaults.size(), tries, ok, req, mons.size(), Time.get_ticks_msec() - t0])
		if not ok:
			bad += 1
		if ring(stairs) != maxd:
			print("GATE NOT CENTER")
			bad += 1
		for ti in 3:
			for lv in range(1, 10):
				_monster_tex(ti, lv, lv == 9)
			for p in 2:
				for v in 3:
					_floor_tex(ti, p, v)
			_wall_tex(ti)
		_player_tex()
		for kind in ["pot", "big", "lamp", "shield", "coin"]:
			_item_tex(kind)
	print("TEST DONE unsolvable=%d" % bad)

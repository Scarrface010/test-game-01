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
enum { PLAY, DEAD, CLEAR, RELIC, SHOP, CLASS, FORK, MARKET, MODE, INV, TRADE, TUTORIAL, LEADER, SKILLS, SAVES, SETTINGS, INTRO }
const GEAR_SLOTS := ["weapon", "ranged", "helmet", "armour", "boots", "trinket"]

const BAG_MAX := 12
const ADV_ZOOM := 88.0
var AC := 88.0   # adventure cell size on screen (arena floors keep 72)
var adv_ex := 0.0   # extra view height on tall phones, adventure only
var MAPB := 1030.0   # bottom edge of the adventure map window
const AMX := 360.0
var AMY := 674.0

var themes: Array = []
var font: Font = ThemeDB.fallback_font
var tex_cache: Dictionary = {}
var vis_pos := Vector2.ZERO
var pface := 1.0
var pdir := 0   # 0 down, 1 up, 2 left, 3 right
var walk_phase := 0.0
var idle_t := 0.0
var fx: Array = []
var mon_slide: Dictionary = {}
var mon_hit: Dictionary = {}
var mon_lunge: Dictionary = {}
var p_hit_t0 := -10.0
var p_atk_t0 := -10.0
var p_atk_dir := Vector2.ZERO
var shake_amp := 0.0
var shake_t0 := -10.0
var shake_dur := 0.3
var tr_base := Vector2.ZERO
var reveal: Dictionary = {}
var vfade: Dictionary = {}
var anim_floor := -1
var anim_mode := ""
var anim_level := 0
var door_prev := false
var door_t0 := -10.0
var lvl_t0 := -10.0
var lvl_n := 0
var pick_c := Vector2i(-1, -1)
var pick_kind := ""
var amb: Array = []
var fx_demo := false
var spr_gen
const SpritesLib := preload("res://sprites.gd")

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
var haz: Dictionary = {}      # Vector2i -> hazard id (adventure)
var corpses: Dictionary = {}  # Vector2i -> {ti, lv, boss, tv, td, fl}
var tur: Dictionary = {}      # Vector2i -> {"v": 0|1, "d": 0 down|1 up|2 left|3 right}
var poison_n := 0
var poison_d := 1
var slide_depth := 0
const TDIRS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]
const TUR_RANGE := 5
const TUR_NAMES := [["Laser Sentry", "Plasma Cannon"], ["Thorn Shooter", "Spore Spitter"], ["Auto Gun", "Rocket Rack"], ["Prism Beam", "Shard Launcher"]]
const TUR_COLS := [[Color("7fe8ff"), Color("ff9a3c")], [Color("9dff6a"), Color("c07cff")], [Color("ffe14f"), Color("ff5d5d")], [Color("ff8ad0"), Color("7fe8ff")]]
const HAZ_IDS := [["arc", "breach"], ["toxic", "slick"], ["mine", "alarm"], ["warp", "shard"]]
const HAZ_NAMES := {"arc": "Arc plate", "breach": "Hull breach", "toxic": "Toxic pool", "slick": "Slick patch", "mine": "Mine", "alarm": "Alarm gate", "warp": "Warp pad", "shard": "Crystal shards"}
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
var cloak_steps := 0
var hex_armed := false
var act_cd := 0
var station_uses := 0
const STATION_USES := 3
var act_free := 0
var act_stance := 0
var act_rico := false
var keys := 0
var vaults: Dictionary = {}
var boss_floor := false
var boss_kind := "warden"
var boss_base := 5
var arena := false
var arena_d: Dictionary = {}
var fmod := "standard"
var door_choices: Array = []
var market_stock: Array = []
var shop_return := 0
var relic_choices: Array = []
var shop_defs: Array = []
var bank := 0
var run_banked := 0
var run_kills := 0
var ups: Dictionary = {"c_brute": 0, "c_mystic": 0, "c_gunslinger": 0, "c_gambler": 0, "kit": 0, "toolbox": 0, "head": 0, "ash": 0, "p_elem": 0, "p_blood": 0, "p_combo": 0, "p_relic": 0, "p_fort": 0, "p_surv": 0, "p_curse": 0, "sp": 0, "suit": 0, "tank": 0, "belt": 0, "vet": 0}
# Shop v2 (unlocks only). The old stat-boost shop is refunded once, using these old prices.
const OLD_SHOP_COSTS := {"vet": [15, 35, 60], "iron": [20, 40, 70], "packed": [45], "lucky": [50], "pockets": [40, 90], "treasure": [25, 55, 100], "oil": [25, 50, 85], "toolbox": [30, 70], "gate": [60, 120], "steel": [35], "haggle": [30], "head": [75, 150], "ash": [120], "interest": [40, 80, 130], "kit": [40, 90]}
# Drop-pool packs: traits and relics that stay out of drops until the pack is bought.
const PACKS := {
	"p_elem": {"t": ["ignite", "volatile", "static", "arc", "frostbite", "shatter", "toxin", "plague"], "r": ["pyro", "storm", "frost", "toxi"]},
	"p_blood": {"t": ["siphon", "bloodlust", "execute", "adrenaline", "barrier"], "r": ["bloodpact", "hood"]},
	"p_combo": {"t": ["rampage", "rhythm", "marked", "deadly", "harvest"], "r": ["overclock"]},
	"p_relic": {"t": [], "r": ["deadeye", "plating", "hazmat", "gravedigger", "thornmail", "scrapper"]},
	"p_fort": {"t": [], "r": ["midas", "scavenger", "luckychip"]},
	"p_surv": {"t": [], "r": ["aegis", "boots", "lantern", "slowdark"]},
	"p_curse": {"t": [], "r": ["glass", "greedy", "blade", "heavyammo", "ember", "prism"]},
}
var shop_page := 0
var shop_tab := 0   # 0 characters, 1 relics, 2 permanent upgrades
var mode := "puzzle"
var adv_best := 0
var AW := 40
var AH := 40
var adv_open := PackedByteArray()
var adv_seen := PackedByteArray()
var adv_rooms: Array = []
var adv_vis: Dictionary = {}
var adv_pts := 0
var adv_req := 10
var adv_pts_total := 0
var oxy := 100.0
var oxy_max := 100.0
var adv_steps := 0
var adv_seed := 0
var cam := Vector2.ZERO
var scan_steps := 0
var mirror_n := 0      # Mirror Shard: hits left to reflect
var lucky_n := 0       # Lucky Coin: coins left that pay double
var bounty_n := 0      # Bounty Chip: kills left that pay coins
var oil_steps := 0     # Lantern Oil: steps of extra sight left
var decoy_steps := 0   # Decoy Beacon: steps left
var decoy_c := Vector2i(-1, -1)
var rw_hist: Array = []   # Rewind Device: last positions, health and air
var scan_r := 0
var xp := 0
var bag: Array[String] = []
var gear_list: Array = []
var gear_defs: Dictionary = {}
var merchants: Dictionary = {}
var trade_cell := Vector2i(-1, -1)
var pack_page := 0
var inv_tab := 3   # 3 = CHARACTER (default bag tab); 0 stats, 1 tools, 2 relics
var inv_page := 0
var chr_sel := -1  # pack index being previewed on the character tab
var chr_dir := 0   # facing of the character model (0 front, 3 side, 1 back)
var chr_drag := false   # a touch started inside the scrollable pack list
var chr_moved := false
var chr_press := Vector2.ZERO
var equip: Dictionary = {}
var ammo := 0
var ranged_mode := false
var btn_mode := Rect2(40, 1114, 230, 54)
var pk: Dictionary = {}
var shooting := false
var wbox_from := false
var wbox_t0 := -1000
var btn_inv := Rect2(596, 20, 104, 46)
var btn_icl := Rect2(250, 1150, 220, 64)
var btn_ipv := Rect2(40, 1070, 190, 56)
var btn_inx := Rect2(490, 1070, 190, 56)
var btn_tpv := Rect2(40, 1150, 190, 64)
var btn_tnx := Rect2(490, 1150, 190, 64)
var hp := 24
var hp_max := 24
var armor := 0
var sh := 0
var sh_max := 16
var mon_hp: Dictionary = {}
var stations: Dictionary = {}
var trade_med := false
var meds: Dictionary = {}   # medical stations: cell -> true
var adv_names := {
	"slowdark": "Deep Lungs", "lantern": "Wide Scanner", "ember": "Overclock Scanner",
	"iron": "Iron Lungs", "oil": "Air Filter", "crystal": "Air Canister",
}
const CLASS_BLURB := {
	"scout": "Quick on his feet: great for exploring.",
	"brute": "Hardy and strong: best for head-on combat.",
	"mystic": "Shielded and resourceful: steady and safe.",
	"gambler": "Lives on luck: risky relics, big rewards.",
	"gunslinger": "Deadly at range, but fragile up close.",
}
var adv_mini: ImageTexture
var btn_modeback := Rect2(20, 76, 160, 44)
var cls_page := 0
var btn_cl_l := Rect2(12, 520, 76, 150)
var btn_cl_r := Rect2(632, 520, 76, 150)
var btn_cpick := Rect2(160, 1000, 400, 80)
var btn_mode_p := Rect2(30, 330, 320, 380)
var btn_mode_a := Rect2(370, 330, 320, 380)
var btn_tut := Rect2(50, 740, 620, 84)
var tut_mode := 0
var btn_lb := Rect2(50, 840, 620, 84)
var btn_lbname := Rect2(40, 1100, 300, 64)
var btn_lbback := Rect2(380, 1100, 300, 64)
const LB_URL := "https://pocket-station-lb.scarrface010-7e8.workers.dev"
var lb_url := LB_URL
var lb_name := ""
var lb_uid := ""
var lb_sent := {"puzzle": 0, "adv": 0}
var lb_rows: Array = []
var lb_status := ""
var lb_mode := 0
var tut_page := 0
var btn_cont := Rect2(50, 940, 620, 72)
var btn_saves := Rect2(50, 1220, 300, 52)
var btn_sv_copy := Rect2(110, 400, 500, 84)
var btn_sv_paste := Rect2(110, 510, 500, 84)
var btn_sv_fexp := Rect2(110, 680, 500, 84)
var btn_sv_fimp := Rect2(110, 790, 500, 84)
var btn_sv_back := Rect2(110, 1100, 500, 80)
var name_edit: LineEdit = null
var inv_scroll := 0.0
var inv_scroll_max := 0.0
var tut_back := MODE
var tutorial := false
var tut_zone := -1
var tut_prev_cls := "scout"
# hidden gear test room: tap the SETTINGS title 5 times to unlock its button
var testroom := false
var test_pending := false
var test_unlocked := false
var set_taps := 0
var set_tap_t := -10.0
var test_prev_save_off := false
const BTN_TEST := Rect2(110, 1196, 500, 64)
const SET_TITLE := Rect2(160, 150, 400, 80)
var tut_prev_save_off := false
var inv_more := false
var btn_inmore := Rect2(190, 1062, 340, 58)
var btn_inhelp := Rect2(510, 76, 190, 56)
var font_pix: Font = null
var font_clear: Font = null
var font_title: Font = ThemeDB.fallback_font
var font_mode := 1
var btn_font := Rect2(626, 24, 70, 70)
var tut_seen := {"puzzle": false, "adv": false}
var set_res := 0
var set_fit := 0
var set_fps := 60
var set_filt := 1   # always smooth
var set_ret := 8
var btn_inset := Rect2(510, 76, 190, 56)
var set_shake := 1
var set_mus := 0     # music volume step: 0 = 100%, 1 = 60%, 2 = 30%, 3 = off
var set_sfxv := 0    # sound effects volume step, same scale
var set_vib := 1     # vibration on phones
var set_big := 0     # 1 = large buttons
var tool_sel := -1   # tool slot selected, waiting for a second tap to use it
var swipe_on := false
var swipe_start := Vector2.ZERO
var cswipe_start := Vector2(-1, -1)
const VOL_STEPS := [1.0, 0.6, 0.3, 0.0]
const VOL_NAMES := ["100%", "60%", "30%", "OFF"]
var inv_vel := 0.0
var inv_mv_t := -10.0
var press_p := Vector2(-999, -999)
const JOY_STEP := 0.16  # seconds per step while the stick is held
var joy_on := false
var joy_dir := Vector2i.ZERO
var joy_v := Vector2.ZERO
var joy_t := 0.0
var press_t := -10.0
var last_state := -1
var state_t := 0.0
var bank_disp := -1.0
const BUILD := 59
var imp_wait := false
var xfer_msg := ""
var xfer_t := -10.0
var save_info := ""
var save_last_sig := 0
var save_t := 0.0
var save_off := false
const SAVE_PATH := "user://run.sav"
const SAVE_VARS := ["mode", "cls", "N", "cell", "period", "maxd", "floor_n", "level", "moves", "coins", "shield", "pos", "start", "stairs", "req",
	"boss_cell", "mons", "elite", "items", "spikes", "coin_at", "haz", "corpses", "tur", "poison_n", "poison_d", "walls", "portals", "kinds",
	"thief_held", "relics", "boost", "cloak_steps", "keys", "vaults", "boss_floor", "boss_kind", "boss_base", "fmod", "run_banked", "adv_open", "adv_seen",
	"adv_rooms", "adv_pts", "adv_req", "adv_pts_total", "oxy", "oxy_max", "adv_steps", "adv_seed", "AW", "AH", "cam", "scan_steps", "scan_r",
	"xp", "merchants", "trade_cell", "equip", "hp", "hp_max", "armor", "sh", "mon_hp", "stations", "meds", "saved", "msg", "door_choices",
	"market_stock", "relic_choices", "shop_return", "affix", "mstat", "skills", "skill_pts", "ammo", "pk", "sk_wind", "sk_phx", "act_cd", "act_free", "act_stance", "act_rico", "station_uses", "arena", "arena_d", "mirror_n", "lucky_n", "bounty_n", "oil_steps"]
var adv_text := {
	"slowdark": "+15 air", "glass": "Gain 3 levels now, but 15 less air and air drains faster", "vanguard": "Gain a level now (each extra copy another)", "alchemist": "Potions give +20% of a level's XP more, overcharged ones +25% more", "slayer": "Elites give 50% more XP",
	"lantern": "+1 sight and bigger scanner pulses", "ember": "+1 sight and bigger scanners, but spikes hurt 2x more",
	"boots": "Spikes no longer hurt you", "skeleton": "The exit needs 4 fewer points",
	"blade": "Every kill gives 50% more XP, but the exit needs 12 more points",
	"iron": "+8 starting air per level", "oil": "Air pods give +5 air; +1 sight per 2 levels",
	"steel": "Spikes hurt half as much", "haggle": "Gear is 2 coins cheaper; tools and heals 1 cheaper",
	"syn_vanguard_alchemist": "Potions give another +20% of a level's XP (+25% for overcharged)",
	"syn_slowdark_lantern": "Scanner pulses reach even further",
	"syn_skeleton_boots": "The exit needs another 4 fewer points",
	"syn_phoenix_aegis": "Phoenix revive also gives +1 level", "gate": "The exit needs 4 fewer points per level",
	"cls_scout": "+10 air and +1 sight. Starts with a Time Crystal.",
	"cls_brute": "Starts +2 levels, +1 armour, but 10 less air. Starts with a Bomb.",
	"cls_gunslinger": "Starts with a Blaster Pistol (full ammo, +4 max ammo) and an Ammo Pack, but is frail: 4 less health and 10 less air.",
	"cls_mystic": "An 8-point shield every floor and +1 item slot. Starts with a Shadow Cloak.",
	"aegis": "Start every floor with an 8-point shield", "packed": "Start every floor with an 8-point shield",
	"phoenix": "Survive one death: restores full health and air",
	"tool_bomb": "Blasts adjacent walls and spikes and hits adjacent monsters hard. Damage grows with depth and level",
	"tool_zap": "Zaps a monster within 3 tiles for heavy damage. Damage grows with depth and level",
	"tool_crystal": "+20 air", "tool_cloak": "Invisible for 16 steps or until you attack",
	"tool_draught": "Gives 75% of a level's worth of XP", "tool_magnet": "Pulls in coins within 14 tiles",
	"tool_blink": "Teleport to a nearby explored tile",
}
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
var btn_menu := Rect2(596, 20, 104, 46)
var btn_invmenu := Rect2(20, 76, 190, 56)
var menu_armed := -10.0
var btn_retry := Rect2(160, 790, 400, 76)
var btn_newrun := Rect2(160, 790, 400, 76)
var btn_shop := Rect2(160, 880, 400, 76)
var btn_back := Rect2(250, 1010, 220, 64)
var btn_shop2 := Rect2(160, 1100, 400, 76)
var btn_prev := Rect2(40, 1010, 190, 64)
var btn_next := Rect2(490, 1010, 190, 64)

const SR_SFX := 22050
const SR_MUS := 11025


func _ready() -> void:
	randomize()
	_layout_buttons()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	font_clear = ThemeDB.fallback_font
	var pf = load("res://fonts/Fredoka.ttf")
	if pf is Font:
		var wt := TextServerManager.get_primary_interface().name_to_tag("wght")
		var fb := FontVariation.new()
		fb.base_font = pf
		fb.variation_opentype = {wt: 520}
		font_clear = fb
		var fv := FontVariation.new()
		fv.base_font = pf
		fv.variation_opentype = {wt: 700}
		font_pix = fv
	_apply_font()
	_make_themes()
	spr_gen = SpritesLib.new(themes)
	var ar := RandomNumberGenerator.new()
	ar.seed = 99
	for i in 40:
		amb.append([ar.randf() * 720.0, ar.randf() * 1280.0, ar.randf_range(0.3, 1.0), ar.randf() * TAU, ar.randf_range(2.0, 4.5)])
	var cfg := ConfigFile.new()
	var migrate_shop := false
	if cfg.load("user://best.cfg") == OK:
		best = int(cfg.get_value("s", "best", 0))
		bank = int(cfg.get_value("s", "bank", 0))
		adv_best = int(cfg.get_value("s", "best_adv", 0))
		if bool(cfg.get_value("s", "shop_v2", false)):
			for k in ups:
				ups[k] = int(cfg.get_value("ups", k, 0))
		else:
			var old_ups := {}
			for k in OLD_SHOP_COSTS:
				old_ups[k] = int(cfg.get_value("ups", k, 0))
			bank += _shop_refund(old_ups)
			migrate_shop = true
		lb_name = String(cfg.get_value("lb", "name", ""))
		font_mode = 2
		_apply_font()
		set_res = clampi(int(cfg.get_value("ui", "res", 0)), 0, 1)
		set_fit = clampi(int(cfg.get_value("ui", "fit", 0)), 0, 1)
		set_fps = int(cfg.get_value("ui", "fps", 60)) if int(cfg.get_value("ui", "fps", 60)) in [30, 60, 120] else 60
		set_filt = 1
		set_shake = clampi(int(cfg.get_value("ui", "shake", 1)), 0, 1)
		set_mus = clampi(int(cfg.get_value("ui", "music", 0)), 0, 3)
		set_sfxv = clampi(int(cfg.get_value("ui", "sfxvol", 0)), 0, 3)
		set_vib = clampi(int(cfg.get_value("ui", "vibrate", 1)), 0, 1)
		set_big = 0
		tut_seen["puzzle"] = bool(cfg.get_value("ui", "tut_p", false))
		tut_seen["adv"] = bool(cfg.get_value("ui", "tut_a", false))
		_layout_buttons()
		_apply_sound()
		_apply_display()
		lb_uid = String(cfg.get_value("lb", "uid", ""))
		lb_sent["puzzle"] = int(cfg.get_value("lb", "sent_puzzle", 0))
		lb_sent["adv"] = int(cfg.get_value("lb", "sent_adv", 0))
		if migrate_shop:
			_save_meta()
	if lb_uid == "":
		var ur := RandomNumberGenerator.new()
		ur.randomize()
		for i in 14:
			lb_uid += "abcdefghijklmnopqrstuvwxyz0123456789"[ur.randi() % 36]
		_save_meta()
	_make_defs()
	_make_gear()
	_make_skills()
	if OS.get_cmdline_user_args().size() > 0:
		save_off = true
	var sd0 := _read_save()
	if not sd0.is_empty():
		save_info = _save_label(sd0)
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
	if "--savetest" in args or "--acttest" in args or "--advtest" in args or "--test" in args:
		var test_seed := 20261021
		for ta in args:
			if String(ta).begins_with("--seed="):
				test_seed = int(String(ta).substr(7))
		seed(test_seed)
	if "--savetest" in args:
		_save_selftest()
		get_tree().quit()
		return
	if "--acttest" in args:
		_act_selftest()
		get_tree().quit()
		return
	if "--advtest" in args:
		_adv_selftest()
		get_tree().quit()
		return
	if "--drawtest" in args:
		_setup_audio()
		await _draw_selftest()
		get_tree().quit()
		return
	if "--test" in args:
		await _self_test()
		get_tree().quit()
		return
	_setup_audio()
	_new_floor()
	state = INTRO
	if OS.has_feature("web"):
		var demo = JavaScriptBridge.eval("new URLSearchParams(location.search).get('demo')")
		var fq = JavaScriptBridge.eval("new URLSearchParams(location.search).get('floor')")
		var cq = JavaScriptBridge.eval("new URLSearchParams(location.search).get('class')")
		var mq = JavaScriptBridge.eval("new URLSearchParams(location.search).get('mode')")
		fx_demo = demo != null and String(demo) == "fx"
		var lbq = JavaScriptBridge.eval("new URLSearchParams(location.search).get('lb')")
		if lbq != null and String(lbq) != "":
			lb_url = String(lbq)
		if demo != null and String(demo) == "lb":
			best = 3
			adv_best = 5
			lb_name = "Dev"
			_lb_resubmit()
		if mq != null and String(mq) == "adv":
			mode = "adv"
		if cq != null:
			cls = String(cq)
		if fq != null and int(fq) > 0:
			_new_run(int(fq))
		var gq = JavaScriptBridge.eval("new URLSearchParams(location.search).get('gear')")
		if gq != null and mode == "adv" and fq != null:
			coins = 99
			for gi in 7:
				_adv_give_gear(_adv_roll_gear(null, 0))
			if String(gq) == "trade":
				var tmc := start + Vector2i(1, 0)
				var toffers: Array = []
				for k in 3:
					var tg := _adv_roll_gear(null, 0)
					toffers.append({"kind": "gear", "id": tg, "price": gprice(tg), "sold": false})
				toffers.append({"kind": "tool", "id": "blink", "price": 6, "sold": false})
				merchants[tmc] = toffers
				_adv_open_trade(tmc)
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
		{
			"name": "CRYSTAL DEEP", "bg": Color("120a22"), "tile": Color("221540"), "tile2": Color("2a1b4e"),
			"wall": Color("6a4fa0"), "accent": Color("d58cff"), "dark": Color("04020a"),
			"mcols": [Color("c9a0ff"), Color("7fe8ff"), Color("ff8ad0"), Color("a0ffd8"), Color("ffe08a"), Color("8fa0ff"), Color("ff9a7a"), Color("e0c8ff"), Color("ff5cc8")],
			"mons": ["Glimmer", "Geode", "Wisp", "Shardling", "Prism", "Golem", "Stalker", "Oracle", "Heart crystal"],
			"pot": "Shard tonic", "gate": "Rift door", "boss": "Crystal Titan",
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
		{"id": "deadeye", "name": "Deadeye Scope", "desc": "Ranged weapons reach 1 tile further", "max": 2, "adv": true},
		{"id": "plating", "name": "Deflector Plating", "desc": "Enemy ranged shots deal 2 less damage", "max": 2, "adv": true},
		{"id": "hazmat", "name": "Hazmat Suit", "desc": "Floor hazards hurt half as much", "max": 1, "adv": true},
		{"id": "gravedigger", "name": "Grave Robber", "desc": "Walking over a fresh corpse gives 2 coins", "max": 2, "adv": true},
		{"id": "heavyammo", "name": "Heavy Ammo", "desc": "Ranged shots deal 1.5x damage but use double ammo", "max": 1, "curse": true, "adv": true},
		{"id": "pyro", "name": "Pyromaniac", "desc": "+4 max health. Fire traits: burns last 2 steps longer and hurt double, Volatile blasts +20%", "max": 1, "adv": true, "tag": "fire"},
		{"id": "storm", "name": "Storm Capacitor", "desc": "+4 max health. Stuns +1 step, Arc Chain hits 3, Decoys last 4 longer and stun neighbours", "max": 1, "adv": true, "tag": "shock"},
		{"id": "frost", "name": "Frost Core", "desc": "+4 max health. Shatter deals +100% instead of +50%. Frozen Ground: Frost Charge stuns 2 steps longer", "max": 1, "adv": true, "tag": "cryo"},
		{"id": "toxi", "name": "Toxicologist", "desc": "+4 max health. Poison stacks up to 7 instead of 4", "max": 1, "adv": true, "tag": "toxic"},
		{"id": "bloodpact", "name": "Blood Pact", "desc": "+4 max health. Siphon heals double", "max": 1, "adv": true, "tag": "blood"},
		{"id": "hood", "name": "Executioner's Hood", "desc": "+4 max health. Executioner works below 35% health", "max": 1, "adv": true, "tag": "execute"},
		{"id": "luckychip", "name": "Lucky Chip", "desc": "+10% crit chance, and crits restore 1 air", "max": 1, "adv": true, "tag": "crit"},
		{"id": "prism", "name": "Prism Lens", "desc": "+1 attack for each different trait type on your weapon (max +4)", "max": 1, "adv": true, "tag": "variety"},
		{"id": "overclock", "name": "Overclock", "desc": "Rampage can stack 3 higher", "max": 1, "adv": true, "tag": "streak"},
		{"id": "thornmail", "name": "Thornmail", "desc": "Reflect 2 damage whenever you are hit", "max": 1, "adv": true},
		{"id": "scrapper", "name": "Scrapper", "desc": "35% chance of an extra coin on every kill", "max": 1, "adv": true},
		{"id": "ember", "name": "Ember Lantern", "desc": "Lanterns hold the dark back 12 steps, but spikes cost 2 more", "max": 1, "curse": true},
	]
	synergies = [
		{"a": "vanguard", "b": "alchemist", "text": "Potions give +1 more level"},
		{"a": "slowdark", "b": "lantern", "text": "Lanterns hold the dark back 12 steps"},
		{"a": "skeleton", "b": "boots", "text": "Gates need 1 less level again"},
		{"a": "phoenix", "b": "aegis", "text": "Phoenix revive also gives +1 level"},
		{"a": "pyro", "b": "storm", "text": "Stunning a burning enemy deals bonus damage"},
		{"a": "storm", "b": "toxi", "text": "Arcs also poison the enemies they hit"},
		{"a": "bloodpact", "b": "hood", "text": "Executions heal 10% of your max health"},
	]
	use_defs = {
		"bomb": {"name": "Bomb", "desc": "Destroys adjacent walls, spikes and weak monsters", "col": Color("ff7a45")},
		"crystal": {"name": "Time Crystal", "desc": "Pushes the dark back 6 steps", "col": Color("4fd1ff")},
		"blink": {"name": "Blink Scroll", "desc": "Teleport to any free tile (costs 1 step)", "col": Color("c07cff")},
		"cloak": {"name": "Shadow Cloak", "desc": "Adventure: invisible for 16 steps or until you attack. Puzzle: your next fight counts as +3 levels", "col": Color("9aa3c7")},
		"draught": {"name": "Elixir", "desc": "+2 levels right now", "col": Color("6dff9a")},
		"magnet": {"name": "Magnet", "desc": "Pulls in every coin on the board", "col": Color("ff5d5d")},
		"pick": {"name": "Pickaxe", "desc": "Breaks any one wall", "col": Color("c9a55a")},
		"zap": {"name": "Zap Rod", "desc": "Zaps a monster within 2 tiles (up to your level +1)", "col": Color("ffe14f")},
		"nano": {"name": "Nano Injector", "desc": "Fully restores your health", "col": Color("ff8a9a"), "adv": true},
		"cell": {"name": "Shield Cell", "desc": "Fully recharges your shield", "col": Color("7db2ff"), "adv": true},
		"plate": {"name": "Plating Kit", "desc": "+1 armour for the rest of the run", "col": Color("c9d3f0"), "adv": true},
		"scan": {"name": "Pulse Scanner", "desc": "Reveals the map around you", "col": Color("5fe0b0"), "adv": true},
		"ration": {"name": "Ration Pack", "desc": "Heals 40% health and gives +15 air", "col": Color("ffb347"), "adv": true},
		"decoy": {"name": "Decoy Beacon", "desc": "Place a decoy up to 6 tiles away: monsters chase it instead of you for 8 steps", "col": Color("ffb347"), "adv": true},
		"foam": {"name": "Foam Canister", "desc": "Smothers every spike and hazard within 2 tiles", "col": Color("e8f4ff"), "adv": true},
		"frost": {"name": "Frost Charge", "desc": "Stuns every enemy within 2 tiles for 4 steps", "col": Color("9fe8ff"), "adv": true},
		"grapple": {"name": "Grapple Hook", "desc": "Fire a hook along a straight line: it grabs the nearest enemy or wall at any distance and pulls you in", "col": Color("c9d3f0"), "adv": true},
		"mirror": {"name": "Mirror Shard", "desc": "Reflects the next hit you take back at the attacker", "col": Color("c8f1ff"), "adv": true},
		"rewind": {"name": "Rewind Device", "desc": "Return to where you stood 8 steps ago and recover the health and air lost since", "col": Color("c07cff"), "adv": true},
		"ammopack": {"name": "Ammo Pack", "desc": "Refills half your max ammo", "col": Color("ffc24f"), "adv": true},
	}
	class_defs = [
		{"id": "scout", "name": "Scout", "desc": "The dark waits +1 step per ring. Starts with a Time Crystal.", "col": Color("4fd1ff"), "lvl": 0, "per": 1, "kit": ["crystal"]},
		{"id": "brute", "name": "Brute", "desc": "+2 starting levels, but the dark is 1 step faster. Starts with a Bomb.", "col": Color("ff6a5c"), "lvl": 2, "per": -1, "kit": ["bomb"]},
		{"id": "mystic", "name": "Mystic", "desc": "A shield every floor and +1 item slot. Starts with a Shadow Cloak.", "col": Color("c07cff"), "lvl": 0, "per": 0, "kit": ["cloak"]},
		{"id": "gambler", "name": "Gambler", "desc": "Begins with 2 random relics (maybe cursed!) and sees 4 relic cards, not 3.", "col": Color("ffd84f"), "lvl": 0, "per": 0, "kit": []},
		{"id": "gunslinger", "name": "Gunslinger", "desc": "Starts with an Ammo Pack, but the dark is 1 step faster.", "col": Color("ff9a4f"), "lvl": 0, "per": -1, "kit": ["ammopack"]},
	]
	door_defs = {
		"standard": {"name": "Steady Path", "desc": "A normal floor.", "col": Color("9fb3d9")},
		"danger": {"name": "Perilous Path", "desc": "Monsters +2 levels, coins worth +1, and an extra relic card afterwards.", "col": Color("ff6a5c")},
		"calm": {"name": "Quiet Path", "desc": "Monsters -1 level and the dark waits 2 steps longer, but no relic afterwards.", "col": Color("7dffb0")},
		"vault": {"name": "Vault Path", "desc": "A locked vault and its key are on this floor. Worth a detour?", "col": Color("ffd84f")},
		"market": {"name": "Merchant", "desc": "Spend your run coins on tools, then continue to a normal floor.", "col": Color("c07cff")},
	}
	shop_defs = [
		{"id": "c_brute", "name": "Brute Class", "desc": "Unlock the Brute: +2 levels, starts with a Bomb", "costs": [90]},
		{"id": "c_mystic", "name": "Mystic Class", "desc": "Unlock the Mystic: shield each floor, +1 slot", "costs": [150]},
		{"id": "c_gunslinger", "name": "Gunslinger Class", "desc": "Unlock the Gunslinger: starts with a Blaster and an Ammo Pack", "costs": [180]},
		{"id": "c_gambler", "name": "Gambler Class", "desc": "Unlock the Gambler: 2 random relics, 4 cards", "costs": [240]},
		{"id": "kit", "name": "Starter Kit", "desc": "Adventure: begin each run with random starter gear", "costs": [160, 360]},
		{"id": "toolbox", "name": "Toolbox", "desc": "Start every run with a random tool", "costs": [120, 280]},
		{"id": "p_elem", "name": "Elemental Pack", "desc": "8 fire, shock, cryo and toxic traits + 4 relics", "costs": [80]},
		{"id": "p_blood", "name": "Bloodthirst Pack", "desc": "5 heal, execute and kill traits + 3 relics", "costs": [70]},
		{"id": "p_combo", "name": "Combo Pack", "desc": "5 streak, crit and XP traits + 1 relic", "costs": [70]},
		{"id": "p_relic", "name": "Relic Cache", "desc": "7 utility relics join the relic pool", "costs": [60]},
	{"id": "p_fort", "name": "Fortune Pack", "desc": "3 coin, tool and crit relics join the relic pool", "costs": [70]},
	{"id": "p_surv", "name": "Survivor Pack", "desc": "4 shield, spike and dark-control relics join the pool", "costs": [70]},
	{"id": "p_curse", "name": "Curse Pack", "desc": "6 risky high-reward relics join the relic pool", "costs": [80]},
		{"id": "head", "name": "Head Start", "desc": "Begin every run with a random relic", "costs": [300]},
		{"id": "ash", "name": "Phoenix Ash", "desc": "Begin every run with a Phoenix Feather", "costs": [480]},
	{"id": "suit", "name": "Reinforced Suit", "desc": "Adventure: +4 starting max health per rank", "costs": [120, 240, 400]},
	{"id": "tank", "name": "Spare Tank", "desc": "Adventure: +8 starting air per rank", "costs": [100, 200, 340]},
	{"id": "belt", "name": "Ammo Belt", "desc": "Adventure: +4 max ammo per rank", "costs": [80, 180, 300]},
	{"id": "sp", "name": "Quick Study", "desc": "Adventure: start each run with +1 skill point per rank", "costs": [400, 800, 1400]},
	{"id": "vet", "name": "Veteran Training", "desc": "Adventure: start each run 1 level higher per rank", "costs": [180, 360, 600]},
	]


func up(id: String) -> int:
	return int(ups.get(id, 0))


func _shop_refund(old: Dictionary) -> int:
	var total := 0
	for k in OLD_SHOP_COSTS:
		var costs: Array = OLD_SHOP_COSTS[k]
		for i in mini(int(old.get(k, 0)), costs.size()):
			total += int(costs[i])
	return total


func class_open(id: String) -> bool:
	return id == "scout" or up("c_" + id) > 0


func _pack_open(kind: String, id: String) -> bool:
	for pk in PACKS:
		if (PACKS[pk][kind] as Array).has(id):
			return up(String(pk)) > 0
	return true


func trait_open(id: String) -> bool:
	return _pack_open("t", id)


func relic_open(id: String) -> bool:
	return _pack_open("r", id)


func _aname(id: String, fb: String) -> String:
	if mode == "adv" and adv_names.has(id):
		return String(adv_names[id])
	return fb


func _atext(id: String, fb: String) -> String:
	if mode == "adv" and adv_text.has(id):
		return String(adv_text[id])
	return fb


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
	return START_LEVEL + (up("vet") if mode == "adv" else 0) + relic_n("vanguard") + 3 * relic_n("glass") + int(cdef()["lvl"])


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
	return base + int(sk("lamp")) + (3 if oil_steps > 0 else 0)


func spike_x() -> int:
	if relic_n("boots") > 0:
		return 0
	return maxi(0, 2 + (2 if relic_n("ember") > 0 else 0))


func start_shield() -> bool:
	return relic_n("aegis") > 0 or cls == "mystic"


func slots_n() -> int:
	return 2 + (1 if cls == "mystic" else 0) + relic_n("bandolier") + int(sk("slots"))


func kill_gain(c: Vector2i) -> int:
	return (2 + relic_n("slayer") if elite.has(c) else 1) + relic_n("blade")


func coin_val() -> int:
	var v := 1 + int(gear("coin")) + int(sk("coin"))
	if relic_n("midas") > 0:
		v *= 2
	if relic_n("greedy") > 0:
		v *= 3
	if fmod == "danger":
		v += 1
	return v


func req_adjust() -> int:
	return 3 * relic_n("blade") - relic_n("skeleton") - (1 if syn("skeleton", "boots") else 0)


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
	if save_off:
		return
	var cfg := ConfigFile.new()
	cfg.load("user://best.cfg")
	cfg.set_value("s", "best", best)
	cfg.set_value("s", "bank", bank)
	cfg.set_value("s", "best_adv", adv_best)
	cfg.set_value("lb", "name", lb_name)
	cfg.set_value("ui", "font", font_mode)
	cfg.set_value("ui", "res", set_res)
	cfg.set_value("ui", "fit", set_fit)
	cfg.set_value("ui", "fps", set_fps)
	cfg.set_value("ui", "smooth", set_filt)
	cfg.set_value("ui", "shake", set_shake)
	cfg.set_value("ui", "music", set_mus)
	cfg.set_value("ui", "sfxvol", set_sfxv)
	cfg.set_value("ui", "vibrate", set_vib)
	cfg.set_value("ui", "bigbtn", 0)
	cfg.set_value("ui", "tut_p", tut_seen["puzzle"])
	cfg.set_value("ui", "tut_a", tut_seen["adv"])
	cfg.set_value("lb", "uid", lb_uid)
	cfg.set_value("lb", "sent_puzzle", int(lb_sent["puzzle"]))
	cfg.set_value("lb", "sent_adv", int(lb_sent["adv"]))
	cfg.set_value("s", "shop_v2", true)
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


func _player_tex(frame := 0, dir := -1, geared := true) -> ImageTexture:
	var dd := pdir if dir < 0 else dir
	var eq: Dictionary = {}
	if geared and mode == "adv":
		for sl in equip:
			eq[sl] = gb(String(equip[sl]))
		if ranged_mode and _weapon_range() > 0 and eq.has("ranged"):
			eq["weapon"] = eq["ranged"]
	return spr_gen.player((cdef()["col"] as Color), cls, frame, dd, eq)


func _gear_tex(id: String) -> ImageTexture:
	var sl := String(gear_defs[gb(id)]["slot"])
	return spr_gen.gear_icon(gb(id), "weapon" if sl == "ranged" else sl)


func _item_tex(kind: String) -> ImageTexture:
	return spr_gen.item(kind)


func _tile_hash(x: int, y: int) -> int:
	var h := (x * 374761393 + y * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return h ^ (h >> 16)


func _tile_feat(x: int, y: int) -> bool:
	return _tile_hash(x, y) % 100 < 7


# Variant 0 is the plain base tile of each theme. Variant 3 is a subtle alternate of it,
# and variants 6-15 are the feature tiles (grates, puddles, flowers...), kept sparse and never adjacent.
func _tile_var(x: int, y: int) -> int:
	var h := _tile_hash(x, y)
	var r := h % 100
	if r < 7:
		if _tile_feat(x - 1, y) or _tile_feat(x, y - 1) or _tile_feat(x + 1, y) or _tile_feat(x, y + 1):
			return 0
		return 6 + (h / 100) % 10
	if r < 24:
		return 3
	return 0


func _floor_tex(ti: int, parity: int, variant: int) -> ImageTexture:
	return spr_gen.floor_tile(ti, parity, variant)


func _wall_tex(ti: int) -> ImageTexture:
	return spr_gen.wall_tile(ti)


const WALL_VARS := 6
var wall_sets: Dictionary = {}


# All wall variants of a theme, cached so the draw loops never build texture keys per cell.
func _wall_set(ti: int) -> Array:
	if not wall_sets.has(ti):
		var a: Array = []
		for v in WALL_VARS:
			a.append(spr_gen.wall_tile(ti, v))
		wall_sets[ti] = a
	return wall_sets[ti]


# Stable per-cell pick, so a wall keeps the same look every frame.
func _wall_var(x: int, y: int) -> int:
	return _tile_hash(x + 57, y + 91) % WALL_VARS


func _monster_tex(ti: int, lvl: int, boss: bool, blink := false, dir := 0) -> ImageTexture:
	return spr_gen.monster(ti, lvl, boss, blink, dir)


func _mon_face(c: Vector2i) -> int:
	if mode != "adv":
		return 0
	var dx := pos.x - c.x
	var dy := pos.y - c.y
	if maxi(absi(dx), absi(dy)) > 9:
		return 0
	if absi(dx) > absi(dy):
		return 3 if dx > 0 else 2
	return 0 if dy >= 0 else 1


func _setup_size() -> void:
	N = 6 if floor_n <= 2 else (7 if floor_n <= 4 else 8)
	cell = GW / N
	period = maxi(5, 8 + (N - 5) + 2 * relic_n("slowdark") - 3 * relic_n("glass") + int(cdef()["per"]) + (2 if fmod == "calm" else 0) - (floor_n - 1) / 3)
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
	if OS.is_debug_build():
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
	cloak_steps = 0
	hex_armed = false
	aim = -1
	walk.clear()
	pops.clear()
	state = PLAY
	if boss_floor:
		msg = "BOSS FLOOR: defeat the %s to leave" % cur_theme()["boss"]
	else:
		msg = "Reach Lv %d to open the %s" % [req, cur_theme()["gate"]]


func _reset_floor() -> void:
	if mode == "adv":
		_adv_reset()
		return
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
	var uids := _use_ids()
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

func _pvf() -> Vector2:
	return vis_pos


const POP_GAP := 0.45   # delay between floating texts on one tile
const POP_LIFE := 1.5   # how long a floating text lasts


func _pop(c: Vector2i, text: String, col: Color) -> void:
	# pops on the same tile come out one after another instead of all at once
	var start := t
	for q in pops:
		if q["cell"] == c:
			start = maxf(start, float(q["t"]) + POP_GAP)
	pops.append({"p": _cell_rect(c).get_center(), "cell": c, "s": text, "c": col, "t": start})
	var cf := Vector2(c)
	if text.ends_with("AMMO"):
		_fx_burst(cf, Color("ffc24f"), 10, 3.0, 0.5, 5.0)
		_fx_ring(cf, Color("ffc24f"), 0.8, 0.4, 4.0, maxf(0.0, start - t))
	if text == "VAULT!":
		_fx_burst(cf, Color("ffd84f"), 24, 4.2, 0.8, 6.0)
		_fx_ring(cf, Color("ffd84f"), 1.1, 0.5, 4.0)
		_shake(3.0, 0.2)
	elif text == "SHIELD!" or text == "BLOCKED":
		_fx_ring(cf, Color("7db2ff"), 1.0, 0.4, 5.0)
		_fx_burst(cf, Color("7db2ff"), 12, 3.4, 0.5, 5.0)
	elif text == "BOSS DOWN":
		_fx_burst(cf, Color("ffd84f"), 40, 5.0, 0.9, 7.0)
		_fx_ring(cf, Color("ffd84f"), 2.0, 0.7, 6.0)
		_shake(9.0, 0.5)
	elif text == "OUCH":
		_fx_burst(_pvf(), Color("ff7a7a"), 12, 3.0, 0.4, 5.0)
		_fx_ring(_pvf(), Color("ff5d5d"), 0.8, 0.35, 4.0)
		p_hit_t0 = t
		_shake(4.0, 0.22)
	elif text == "AIR FULL":
		_fx_ring(cf, Color("7fd8ff"), 1.3, 0.6, 5.0)
		for i in 10:
			_fx_spark(cf + Vector2(randf_range(-0.3, 0.3), 0.2), Vector2(randf_range(-0.4, 0.4), randf_range(-2.4, -1.0)), Color("c8f1ff"), randf_range(0.6, 1.0), randf_range(3.0, 6.0), 1.2)
	elif text == "SCAN":
		_fx_ring(cf, Color("ffe9a0"), 3.0, 0.7, 4.0)
		_fx_ring(cf, Color("ffe9a0"), 5.0, 0.9, 2.0, 0.12)
	elif text == "ARMOUR":
		_fx_ring(cf, Color("c9d3f0"), 1.0, 0.45, 5.0)
		_fx_burst(cf, Color("c9d3f0"), 10, 3.0, 0.5, 5.0)


func _use_ids() -> Array:
	var out: Array = []
	for k in use_defs.keys():
		if mode == "adv" or not bool(use_defs[k].get("adv", false)):
			out.append(k)
	return out


func _use_name(id: String) -> String:
	return _aname(id, String(use_defs[id]["name"]))


func _give_use(id: String) -> bool:
	if inv.size() >= slots_n():
		return false
	inv.append(id)
	return true


func _random_use() -> String:
	var ids := _use_ids()
	var id := String(ids[randi() % ids.size()])
	while mode == "adv" and id == "pick":
		id = String(ids[randi() % ids.size()])
	return id


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
		pick_c = nc
		pick_kind = kind
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
		pick_c = nc
		pick_kind = "coin"
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
	_act_tick()
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
	_fx_death(c)
	if mode == "adv":
		_sfx("corpse")
	if mode == "adv" and mons.has(c) and not themes.is_empty():
		var isb := boss_floor and c == boss_cell
		corpses[c] = {"ti": tidx(), "lv": int(mons[c]), "boss": isb, "tv": int(tur[c]["v"]) if tur.has(c) else -1, "td": int(tur[c]["d"]) if tur.has(c) else 0, "fl": (c.x * 7 + c.y * 13) % 2}
	mons.erase(c)
	mon_hp.erase(c)
	elite.erase(c)
	kinds.erase(c)
	thief_held.erase(c)
	tur.erase(c)
	affix.erase(c)
	mstat.erase(c)


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
	if tutorial or testroom:
		hp = hp_cap()
		oxy = oxy_max
		msg = "Knocked out! Tutorial: you are back on your feet"
		_sfx("shield")
		return
	if mode == "adv" and relic_n("phoenix") > 0:
		relics.erase("phoenix")
		hp = hp_cap()
		oxy = oxy_max
		msg = "Phoenix Feather burns up! Health and air fully restored"
		if syn("phoenix", "aegis"):
			_adv_level_up(1)
			msg += " (+1 level)"
		_pop(pos, "REBORN", Color("ffb347"))
		_sfx("shield")
		return
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	save_info = ""
	var reached := floor_n - 1
	var was_best := false
	if mode == "adv":
		if reached > adv_best:
			adv_best = reached
			was_best = true
	elif reached > best:
		best = reached
		was_best = true
	var delta := maxi(0, coins - run_banked)
	bank += delta
	run_banked += delta
	_save_meta()
	_lb_note(reached, true)
	_sfx("death")
	over_title = "YOU DIED"
	var dl: PackedStringArray = PackedStringArray([why, "Floor %d   Level %d" % [floor_n, level]])
	if mode == "adv":
		dl.append("Kills %d" % run_kills)
	dl.append("Floors cleared %d   Best %d%s" % [reached, adv_best if mode == "adv" else best, "   NEW BEST!" if was_best else ""])
	dl.append("Banked +%d coins (total %d)" % [delta, bank])
	over_sub = "\n".join(dl)


func _clear() -> void:
	_lb_note(floor_n, false)
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
		if d.has("adv") and mode != "adv":
			continue
		if not relic_open(String(d["id"])):
			continue
		if relic_n(String(d["id"])) < int(d["max"]):
			if d.has("curse"):
				cursed.append(d)
			else:
				normal.append(d)
	normal.shuffle()
	cursed.shuffle()
	if mode == "adv" and randf() < 0.7:
		var mine: Array = []
		var rest: Array = []
		for d2 in normal:
			var tg := String(d2.get("tag", ""))
			if tg != "" and (tg == "variety" and tag_kinds() > 1 or tag_n(tg) > 0):
				mine.append(d2)
			else:
				rest.append(d2)
		normal = mine + rest
	var n := 3 + (1 if cls == "gambler" else 0) + extra
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
	if mode == "adv":
		_adv_next()
		return
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
	var ids := _use_ids()
	ids.shuffle()
	market_stock.clear()
	for i in 3:
		market_stock.append({"id": String(ids[i]), "price": maxi(2, randi_range(5, 8) + floor_n / 5)})
	state = MARKET


func _relic_rect(i: int) -> Rect2:
	return Rect2(50, 380 + i * 150, 620, 134)


func _shop_rect(i: int) -> Rect2:
	return Rect2(50, 350 + i * 108, 620, 98)


const SHOP_TABS := ["CHARACTERS", "RELICS", "UPGRADES"]
const SHOP_RELIC_IDS := ["p_elem", "p_blood", "p_combo", "p_relic", "p_fort", "p_surv", "p_curse", "head", "ash"]


func _shop_tab_of(id: String) -> int:
	if id.begins_with("c_"):
		return 0
	if SHOP_RELIC_IDS.has(id):
		return 1
	return 2


# indices into shop_defs shown on the current tab
func _shop_list() -> Array:
	var out: Array = []
	for i in shop_defs.size():
		if _shop_tab_of(String(shop_defs[i]["id"])) == shop_tab:
			out.append(i)
	return out


func _shop_tab_rect(i: int) -> Rect2:
	return Rect2(50 + i * 210, 302, 200, 40)


func _shop_pages() -> int:
	return maxi(1, (_shop_list().size() + 5) / 6)


func _class_rect(i: int) -> Rect2:
	return Rect2(50, 252 + i * 164, 620, 156)


func _act_desc(cid: String) -> String:
	if mode == "adv":
		return {
			"scout": "Deep Breath: +10 air and your next 8 steps cost no air. Recharges in 40 steps.",
			"brute": "Iron Stance: blocks the next 2 hits. Recharges in 30 steps.",
			"mystic": "Hex Mark: the next enemy you hit takes double damage until it dies. Recharges in 35 steps.",
			"gambler": "Reshuffle: rerolls all your tools. Recharges in 50 steps.",
			"gunslinger": "Ricochet: your next shot bounces to a second enemy within 3 tiles. Recharges in 25 steps.",
		}.get(cid, "")
	return {
		"scout": "Deep Breath: pushes the dark back 3 steps. Recharges in 40 steps.",
		"brute": "Iron Stance: your next fight counts as +3 levels. Recharges in 30 steps.",
		"mystic": "Hex Pulse: monsters within 3 tiles lose a level. Recharges in 35 steps.",
		"gambler": "Reshuffle: rerolls all your tools. Recharges in 50 steps.",
		"gunslinger": "Ricochet: zaps a monster within 2 tiles, then another beside it. Recharges in 25 steps.",
	}.get(cid, "")


func _door_rect(i: int) -> Rect2:
	return Rect2(50, 380 + i * 200, 620, 180)


func _market_rect(i: int) -> Rect2:
	return Rect2(50, 380 + i * 150, 620, 134)


func _slot_rect(i: int) -> Rect2:
	if mode == "adv":
		var sz := _slot_sz()
		return Rect2(712.0 - (slots_n() - i) * (sz + 8.0), 1166.0 + adv_ex, sz, sz)
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


# ----- class actives -----

const ACTS := {
	"scout": {"n": "Deep Breath", "cd": 40},
	"brute": {"n": "Iron Stance", "cd": 30},
	"gambler": {"n": "Reshuffle", "cd": 50},
	"gunslinger": {"n": "Ricochet", "cd": 25},
	"mystic": {"n": "Hex Mark", "cd": 35},
}


func _act_tick() -> void:
	if act_cd > 0:
		act_cd -= 1
	if cloak_steps > 0:
		cloak_steps -= 1
		if cloak_steps == 0 and mode == "adv":
			msg = "Your Shadow Cloak fades"


func _act_rect() -> Rect2:
	if mode == "adv":
		var ah := _row2_h()
		var ax1 := 704.0 - ah - 8.0 if _weapon_range() > 0 else 704.0
		return Rect2(16, 1062.0 + adv_ex, ax1 - 16.0, ah)
	var sy := 982.0
	var x0 := 40.0 + slots_n() * 118.0
	if 616.0 - x0 >= 110.0:
		return Rect2(x0, sy, 616.0 - x0, 62.0)
	return Rect2(40.0, sy + 64.0, 640.0, 30.0)


func _act_status() -> String:
	if act_cd > 0:
		return "%d steps" % act_cd
	if cls == "scout" and act_free > 0:
		return "%d free" % act_free
	if cls == "brute" and act_stance > 0:
		return "%d blocks" % act_stance
	if cls == "gunslinger" and act_rico:
		return "LOADED"
	return "READY"


func _act_draw() -> void:
	if not ACTS.has(cls):
		return
	var r := _act_rect()
	var col: Color = cdef()["col"]
	var rdy := act_cd <= 0
	var live := act_free > 0 or act_stance > 0 or act_rico
	var bc := col if (rdy or live) else Color(1, 1, 1, 0.3)
	_panel(r, bc, 0.22 if rdy else 0.07, false)
	if act_cd > 0:
		var frac := float(act_cd) / float(ACTS[cls]["cd"])
		draw_rect(Rect2(r.position.x, r.end.y - 5.0, r.size.x * (1.0 - frac), 5.0), Color(col.r, col.g, col.b, 0.8))
	var tc := Color.WHITE if (rdy or live) else Color(1, 1, 1, 0.5)
	if r.size.y >= 50.0:
		_ctext(String(ACTS[cls]["n"]), r.get_center() + Vector2(0, -13), 26, tc)
		_ctext(_act_status(), r.get_center() + Vector2(0, 18), 20, Color(bc.r, bc.g, bc.b, 1.0))
	else:
		_ctext("%s: %s" % [ACTS[cls]["n"], _act_status()], r.get_center(), 18, tc)


func _act_fx(col: Color) -> void:
	var vp := vis_pos if mode == "adv" else _pvf()
	_fx_ring(vp, col, 1.4, 0.5, 5.0)
	_fx_burst(vp, col, 14, 3.0, 0.5, 5.0)


func _act_fail(m: String) -> bool:
	msg = m
	_sfx("blocked")
	return false


func _act_use() -> void:
	if state != PLAY or not ACTS.has(cls):
		return
	if act_cd > 0:
		msg = "%s recharging: %d steps" % [ACTS[cls]["n"], act_cd]
		_sfx("blocked")
		return
	walk.clear()
	aim = -1
	var ok := false
	match cls:
		"scout":
			ok = _act_scout()
		"brute":
			ok = _act_brute()
		"gambler":
			ok = _act_gambler()
		"gunslinger":
			ok = _act_gunslinger()
		"mystic":
			ok = _act_mystic()
	if ok:
		act_cd = int(ACTS[cls]["cd"])


func _act_scout() -> bool:
	if mode == "adv":
		oxy = minf(oxy_max, oxy + 10.0)
		act_free = 8
		msg = "Deep Breath: +10 air, your next 8 steps cost no air"
		_pop(pos, "+10 AIR", Color("7fd8ff"))
	else:
		if moves <= depth_for(moves) * period:
			return _act_fail("The dark is not close yet")
		moves = maxi(moves - 3, depth_for(moves) * period)
		msg = "Deep Breath: the dark is pushed back"
		_pop(pos, "BREATH", Color("7fd8ff"))
	_act_fx(Color("7fd8ff"))
	_sfx("lamp")
	return true


func _act_brute() -> bool:
	if mode == "adv":
		act_stance = 2
		msg = "Iron Stance: blocks the next 2 hits"
	else:
		boost = maxi(boost, 3)
		msg = "Iron Stance: your next fight counts +3 levels"
	_pop(pos, "STANCE", Color("ff6a5c"))
	_act_fx(Color("ff6a5c"))
	_sfx("shield")
	return true


func _act_gambler() -> bool:
	if inv.is_empty():
		return _act_fail("No tools to reshuffle")
	for i in inv.size():
		inv[i] = _random_use()
	msg = "Reshuffle! Every tool was rerolled"
	_pop(pos, "RESHUFFLE", Color("ffd84f"))
	_act_fx(Color("ffd84f"))
	_sfx("big")
	return true


func _act_gunslinger() -> bool:
	if mode == "adv":
		if _shoot_range() <= 0:
			return _act_fail("Ricochet needs a ranged weapon")
		if act_rico:
			return _act_fail("Ricochet is already loaded")
		act_rico = true
		msg = "Ricochet loaded: your next shot bounces to a second target"
		_pop(pos, "LOADED", Color("ff9a4f"))
		_act_fx(Color("ff9a4f"))
		_sfx("ui")
		return true
	var best := Vector2i(-1, -1)
	var bd := 99
	for c in mons.keys():
		if is_dark(c) or _mon_level(c) > level + 1:
			continue
		var d: int = absi(c.x - pos.x) + absi(c.y - pos.y)
		if d <= 2 and d < bd:
			best = c
			bd = d
	if bd == 99:
		return _act_fail("No target within 2 tiles")
	var second := Vector2i(-1, -1)
	var sd := 99
	for c in mons.keys():
		if c == best or is_dark(c) or _mon_level(c) > level + 1:
			continue
		var d2: int = absi(c.x - best.x) + absi(c.y - best.y)
		if d2 <= 3 and d2 < sd:
			second = c
			sd = d2
	_fx_bolt(Vector2(pos), Vector2(best), Color("ff9a4f"))
	_pop(best, "RICOCHET", Color("ff9a4f"))
	_kill_free(best)
	if sd != 99:
		_fx_bolt(Vector2(best), Vector2(second), Color("ffd84f"))
		_pop(second, "RICOCHET", Color("ffd84f"))
		_kill_free(second)
		msg = "Ricochet! Two monsters down"
	else:
		msg = "Ricochet! One monster down"
	_sfx("elite")
	return true


func _act_ricochet(from: Vector2i, dmg: int) -> void:
	var best := Vector2i(-1, -1)
	var bd := 99
	for m in mons.keys():
		if m == from or not adv_vis.has(m):
			continue
		var d: int = absi(m.x - from.x) + absi(m.y - from.y)
		if d <= 3 and d < bd:
			best = m
			bd = d
	if bd == 99:
		msg += "  (no second target for the ricochet)"
		return
	_fx_bolt(Vector2(from), Vector2(best), Color("ffd84f"))
	_pop(best, "RICOCHET", Color("ffd84f"))
	_adv_damage_mon(best, dmg, Color("ffd84f"))
	msg += "  It ricochets for %d!" % dmg


func _act_mystic() -> bool:
	if mode == "adv":
		hex_armed = true
		msg = "Hex Mark: the next enemy you hit takes double damage until it dies"
		_act_fx(Color("c07cff"))
		_sfx("shield")
		return true
	var n := 0
	for c in mons.keys():
		if absi(c.x - pos.x) + absi(c.y - pos.y) > 3:
			continue
		if mode == "adv":
			if not adv_vis.has(c) or not _st_ok(c) or _boss_cell(c) or tur.has(c):
				continue
			_st_stun(c, 3)
			n += 1
		else:
			if is_dark(c) or int(mons[c]) <= 1:
				continue
			mons[c] = int(mons[c]) - 1
			_pop(c, "HEX -1", Color("c07cff"))
			n += 1
	if n == 0:
		return _act_fail("No monsters in reach of the pulse")
	msg = ("Hex Pulse: %d monsters stunned for 3 steps" % n) if mode == "adv" else ("Hex Pulse: %d monsters weakened by a level" % n)
	_act_fx(Color("c07cff"))
	_sfx("shield")
	return true


func _act_selftest() -> void:
	var bad := 0
	for m in ["adv", "puzzle"]:
		for cid in ["scout", "brute", "gambler", "gunslinger", "mystic"]:
			mode = m
			cls = cid
			_new_run(7)
			state = PLAY
			if cid == "gambler" and inv.is_empty():
				inv.append("bomb")
			_act_use()
			var cd1 := act_cd
			_act_use()
			_act_tick()
			print("ACT ", m, " ", cid, " cd=", cd1, " msg=", msg)
			if cd1 != 0 and cd1 != int(ACTS[cid]["cd"]):
				bad += 1
	act_stance = 2
	mode = "adv"
	cls = "brute"
	_new_run(7)
	state = PLAY
	act_stance = 2
	hp = hp_max
	_adv_hurt(5, "Test")
	if act_stance != 1 or hp != hp_max:
		bad += 1
		print("STANCE FAIL ", act_stance, " ", hp)
	mode = "adv"
	cls = "scout"
	_new_run(7)
	state = PLAY
	mons.clear()
	haz.clear()
	spikes.clear()
	items.clear()
	coin_at.clear()
	var sa := pos
	var sb := Vector2i(-1, -1)
	for dv in TDIRS:
		var nb: Vector2i = sa + dv
		if _aopen(nb) and not vaults.has(nb) and nb != stairs:
			sb = nb
			break
	if sb.x < 0:
		print("STATION TEST SKIPPED (no open neighbour)")
	else:
		stations[sa] = true
		stations[sb] = true
		skills["b1n4"] = 1
		station_uses = 0
		for i in 5:
			oxy = oxy_max - 20.0
			hp = hp_cap() - 10
			var h0 := hp
			_adv_step(sb if i % 2 == 0 else sa, true)
			var healed := hp > h0
			if oxy < oxy_max - 0.01 or healed != (i < 3) or station_uses != mini(i + 1, 3):
				bad += 1
				print("STATION FAIL step ", i, " oxy=", oxy, " healed=", healed, " uses=", station_uses)
		station_uses = 0
		hp = hp_cap()
		oxy = oxy_max - 20.0
		_adv_step(sb, true)
		if station_uses != 0 or oxy < oxy_max - 0.01:
			bad += 1
			print("STATION FAIL: heal spent at full health or air not refilled")
		skills.clear()
	print("ACT TEST DONE bad=", bad)


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
		_cloak_break()
		_pop(c, "ZAP", Color("ffe14f"))
		_kill_free(c)
		msg = "Zap!"
		_sfx("elite")


# ----- run flow -----

func _save_selftest() -> void:
	save_off = false
	var bad := 0
	for m in ["adv", "puzzle"]:
		mode = m
		cls = "gunslinger"
		_new_run(7)
		coins = 77
		_save_run()
		var f0 := floor_n
		var p0 := pos
		var m0 := mons.size()
		var w0 := walls.size()
		var ao := adv_open.size()
		var eq0 := equip.duplicate()
		var inv0 := inv.duplicate()
		coins = 5
		floor_n = 1
		mons.clear()
		pos = Vector2i(-3, -3)
		equip.clear()
		inv.clear()
		if not _load_run():
			bad += 1
			print("LOAD FAILED ", m)
			continue
		if coins != 77 or floor_n != f0 or pos != p0 or mons.size() != m0 or walls.size() != w0 or adv_open.size() != ao or equip != eq0 or inv != inv0 or state != PLAY:
			bad += 1
			print("MISMATCH ", m, " ", coins, " ", floor_n, " ", pos, " ", mons.size(), "/", m0, " ", equip, " ", inv)
	print("SAVE TEST DONE bad=", bad, " info=", save_info)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _save_sig() -> int:
	return [floor_n, moves, adv_steps, coins, hp, int(oxy * 10.0), pos, level, xp, keys, boost, cloak_steps, sh, inv.hash(), bag.hash(), equip.hash(), relics.hash(), mons.size(), items.size(), corpses.size(), msg].hash()


func _save_run() -> void:
	if save_off:
		return
	var d := {"ver": 1}
	for k in SAVE_VARS:
		d[k] = get(k)
	d["inv"] = Array(inv)
	d["bag"] = Array(bag)
	var f := FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
	if f == null:
		return
	f.store_var(d, true)
	f.close()
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.rename("run.sav.tmp", "run.sav")
	save_info = _save_label(d)


func _save_label(d: Dictionary) -> String:
	var cn := String(d.get("cls", "scout")).capitalize()
	for cd in class_defs:
		if cd["id"] == d.get("cls", ""):
			cn = String(cd["name"])
	return "%s  -  floor %d, %s, LV %d" % ["Adventure" if d.get("mode", "") == "adv" else "Puzzle", int(d.get("floor_n", 1)), cn, int(d.get("level", 1))]


func _read_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var d = f.get_var(true)
	f.close()
	if d is Dictionary and int(d.get("ver", 0)) == 1:
		return d
	return {}


func _load_run() -> bool:
	var d := _read_save()
	if d.is_empty():
		return false
	for k in SAVE_VARS:
		if d.has(k):
			set(k, d[k])
	inv.assign(d.get("inv", []))
	bag.assign(d.get("bag", []))
	walk.clear()
	pops.clear()
	fx.clear()
	mon_slide.clear()
	mon_hit.clear()
	mon_lunge.clear()
	reveal.clear()
	vfade.clear()
	aim = -1
	anim_floor = -1
	menu_armed = -10.0
	if mode == "adv":
		_adv_update_vis()
		_play_music(tidx())
	else:
		_play_music(tidx())
	state = PLAY
	save_last_sig = _save_sig()
	save_t = t
	return true


func _xfer_pack() -> PackedByteArray:
	var meta := {"best": best, "adv_best": adv_best, "bank": bank, "ups": ups.duplicate(), "v2": true}
	var pkg := {"ver": 1, "meta": meta, "run": _read_save()}
	var raw := var_to_bytes(pkg)
	var comp := raw.compress(FileAccess.COMPRESSION_GZIP)
	var out := PackedByteArray("PSAV".to_utf8_buffer())
	out.append_array(comp)
	return out


func _xfer_export() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.download_buffer(_xfer_pack(), "pocket-station-save.psav", "application/octet-stream")
	xfer_msg = "Save file exported - send it to your other device"
	xfer_t = t


func _xfer_copy_code() -> void:
	DisplayServer.clipboard_set(Marshalls.raw_to_base64(_xfer_pack()))
	xfer_msg = "Save code copied - paste it into a chat or note, then use PASTE on your other device"
	xfer_t = t


func _xfer_paste_code() -> void:
	var txt := ""
	if OS.has_feature("web"):
		var r = JavaScriptBridge.eval("prompt('Paste your save code here:', '')")
		if r == null:
			return
		txt = String(r)
	else:
		txt = DisplayServer.clipboard_get()
	if txt.strip_edges() == "":
		xfer_msg = "Nothing to paste - copy the save code first"
		xfer_t = t
		return
	_xfer_apply_b64(txt)


func _xfer_import_start() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("window.__psv='';(function(){var i=document.createElement('input');i.type='file';i.onchange=function(){var f=i.files[0];if(!f)return;var r=new FileReader();r.onload=function(){var u=new Uint8Array(r.result);var s='';for(var k=0;k<u.length;k++)s+=String.fromCharCode(u[k]);window.__psv=btoa(s);};r.readAsArrayBuffer(f);};i.click();})()")
	imp_wait = true


func _xfer_import_poll() -> void:
	var v = JavaScriptBridge.eval("window.__psv||''")
	var b64 := String(v)
	if b64 == "":
		return
	JavaScriptBridge.eval("window.__psv=''")
	imp_wait = false
	_xfer_apply_b64(b64)


func _xfer_apply_b64(b64: String) -> void:
	xfer_t = t
	var raw := Marshalls.base64_to_raw(b64.strip_edges().replace("\n", "").replace("\r", "").replace(" ", ""))
	if raw.size() < 8 or raw.slice(0, 4).get_string_from_utf8() != "PSAV":
		xfer_msg = "That is not a Pocket Station save file"
		return
	var un := raw.slice(4).decompress_dynamic(30000000, FileAccess.COMPRESSION_GZIP)
	var pkg = bytes_to_var(un) if un.size() > 0 else null
	if not (pkg is Dictionary) or int(pkg.get("ver", 0)) != 1:
		xfer_msg = "Could not read that save file"
		return
	var meta: Dictionary = pkg.get("meta", {})
	best = maxi(best, int(meta.get("best", 0)))
	adv_best = maxi(adv_best, int(meta.get("adv_best", 0)))
	bank = int(meta.get("bank", bank))
	var iu: Dictionary = meta.get("ups", {})
	if bool(meta.get("v2", false)):
		for k in ups:
			if iu.has(k):
				ups[k] = int(iu[k])
	else:
		bank += _shop_refund(iu)
	_save_meta()
	var run = pkg.get("run", {})
	if run is Dictionary and not run.is_empty():
		var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f != null:
			f.store_var(run, true)
			f.close()
			save_info = _save_label(run)
	xfer_msg = "Imported! Tap CONTINUE to resume" if save_info != "" else "Imported progress (no run in file)"
	_sfx("big")


func _wipe_progress() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	save_info = ""
	bank = 0
	best = 0
	adv_best = 0
	for k in ups.keys():
		ups[k] = 0
	reset_armed = -10.0
	_save_meta()
	_sfx("death")


func _new_run(start_floor := 1) -> void:
	floor_n = start_floor
	coins = 0
	run_kills = 0
	guide_seen.clear()
	run_banked = 0
	mirror_n = 0
	lucky_n = 0
	bounty_n = 0
	oil_steps = 0
	relics.clear()
	inv.clear()
	act_cd = 0
	act_free = 0
	act_stance = 0
	act_rico = false
	fmod = "standard"
	for id in cdef()["kit"]:
		inv.append(String(id))
	if cls == "gambler":
		var pool: Array = []
		for rd in relic_defs:
			if (not rd.has("adv") or mode == "adv") and relic_open(String(rd["id"])):
				pool.append(rd)
		pool.shuffle()
		for i in 2:
			var d: Dictionary = pool[i]
			relics[d["id"]] = 1
	if up("ash") > 0:
		relics["phoenix"] = 1
	var safe_pool: Array = []
	for d2 in relic_defs:
		if d2.has("adv") and mode != "adv":
			continue
		if not relic_open(String(d2["id"])):
			continue
		if not d2.has("curse") and relic_n(String(d2["id"])) < int(d2["max"]):
			safe_pool.append(d2)
	safe_pool.shuffle()
	for i in mini(up("head"), safe_pool.size()):
		relics[safe_pool[i]["id"]] = relic_n(String(safe_pool[i]["id"])) + 1
	for i in up("toolbox"):
		if inv.size() < slots_n():
			inv.append(_random_use())
	if mode == "adv":
		_adv_init_run()
		_adv_new_floor()
	else:
		_new_floor()


func _gui_input(event: InputEvent) -> void:
	if state == INTRO:
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed) or (event is InputEventScreenTouch and event.pressed):
			state = MODE
		return
	if state == INV and inv_tab == 3 and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			chr_drag = event.position.y >= CHR_LIST_TOP and event.position.y <= CHR_LIST_BOT
			if chr_drag:
				chr_press = event.position
				chr_moved = false
				inv_vel = 0.0
				return
		elif chr_drag:
			chr_drag = false
			if Time.get_ticks_msec() / 1000.0 - inv_mv_t > 0.1:
				inv_vel = 0.0
			if not chr_moved:
				_chr_input(chr_press)
			return
	if state == INV and (inv_tab == 0 or (inv_tab == 3 and chr_drag)):
		if inv_tab == 3 and event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			if event.position.distance_to(chr_press) > 14.0:
				chr_moved = true
			if not chr_moved:
				return
		if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			var now_s := Time.get_ticks_msec() / 1000.0
			var mdt := maxf(now_s - inv_mv_t, 0.008)
			inv_scroll = clampf(inv_scroll - event.relative.y, 0.0, inv_scroll_max)
			inv_vel = clampf(lerpf(inv_vel, -event.relative.y / mdt, 0.5), -4000.0, 4000.0)
			inv_mv_t = now_s
			return
		if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if Time.get_ticks_msec() / 1000.0 - inv_mv_t > 0.1:
				inv_vel = 0.0
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			inv_vel = 0.0
		if event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			inv_vel = 0.0
			inv_scroll = clampf(inv_scroll + (60.0 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -60.0), 0.0, inv_scroll_max)
			return
	if state == PLAY and mode == "adv" and swipe_on and event is InputEventMouseMotion:
		var jd: Vector2 = event.position - swipe_start
		if jd.length() > 90.0:
			swipe_start = event.position - jd.normalized() * 90.0
			jd = event.position - swipe_start
		if jd.length() >= 28.0:
			joy_on = true
			joy_v = jd
			var nd := Vector2i(signi(int(jd.x)), 0) if absf(jd.x) > absf(jd.y) else Vector2i(0, signi(int(jd.y)))
			if nd != joy_dir:
				joy_dir = nd
				joy_t = JOY_STEP
		elif joy_on:
			joy_dir = Vector2i.ZERO
			joy_v = jd
		return
	var tap_pos := Vector2(-1, -1)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if state == CLASS:
			if event.pressed:
				cswipe_start = event.position if Rect2(100, 262, 520, 690).has_point(event.position) else Vector2(-1, -1)
			elif cswipe_start.x >= 0.0:
				var cd2: Vector2 = event.position - cswipe_start
				cswipe_start = Vector2(-1, -1)
				if absf(cd2.x) > 70.0 and absf(cd2.x) > absf(cd2.y) * 1.5:
					var np := cls_page + (1 if cd2.x < 0.0 else -1)
					if np >= 0 and np < class_defs.size():
						cls_page = np
						_sfx("ui")
		# Adventure map: swipe to step, tap to walk (a tap is decided on release)
		elif state == PLAY and mode == "adv":
			if event.pressed:
				if event.position.y > 318.0 and event.position.y < MAPB:
					swipe_on = true
					swipe_start = event.position
					return
			elif swipe_on:
				swipe_on = false
				if joy_on:
					joy_on = false
					joy_dir = Vector2i.ZERO
					return
				tap_pos = swipe_start
	if tap_pos.x < 0.0 and not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = tap_pos if tap_pos.x >= 0.0 else event.position
	press_p = p
	press_t = t
	if state == PLAY and mode == "puzzle" and btn_menu.has_point(p):
		_menu_leave()
		return
	if state == TUTORIAL:
		_tut_input(p)
		return
	if state == LEADER:
		_lb_input(p)
		return
	if state == SAVES:
		_saves_input(p)
		return
	if state == SETTINGS:
		_settings_input(p)
		return
	if state == MODE:
		if btn_lb.has_point(p):
			_lb_open()
			_sfx("ui")
			return
		if btn_tut.has_point(p):
			state = TUTORIAL
			tut_page = 0
			_sfx("ui")
			return
		if btn_font.get_center().distance_to(p) <= 40.0:
			state = SETTINGS
			_sfx("ui")
			return
		if save_info != "" and btn_cont.has_point(p):
			if _load_run():
				_sfx("big")
			else:
				save_info = ""
				_sfx("blocked")
			return
		if btn_mode_p.has_point(p):
			mode = "puzzle"
			state = CLASS
			_sfx("big")
		elif btn_mode_a.has_point(p):
			mode = "adv"
			state = CLASS
			_sfx("big")
		return
	if state == INV:
		_inv_input(p)
		return
	if state == SKILLS:
		_skill_input(p)
		return
	if state == TRADE:
		_trade_input(p)
		return
	if state == CLASS:
		if btn_modeback.has_point(p):
			state = MODE
			test_pending = false
			_sfx("ui")
			return
		if btn_cl_l.has_point(p):
			if cls_page > 0:
				cls_page -= 1
				_sfx("ui")
			return
		if btn_cl_r.has_point(p):
			if cls_page < class_defs.size() - 1:
				cls_page += 1
				_sfx("ui")
			return
		if btn_cpick.has_point(p):
			if not class_open(String(class_defs[cls_page]["id"])):
				shop_return = CLASS
				shop_tab = 0
				shop_page = 0
				state = SHOP
				_sfx("ui")
				return
			cls = String(class_defs[cls_page]["id"])
			_sfx("big")
			if test_pending:
				_test_room_start()
				return
			_new_run()
			_first_tut()
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
				if mode == "adv":
					_adv_relic_applied(id)
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
		for ti in SHOP_TABS.size():
			if _shop_tab_rect(ti).has_point(p):
				shop_tab = ti
				shop_page = 0
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
		var slist := _shop_list()
		for i in 6:
			var idx := shop_page * 6 + i
			if idx >= slist.size():
				break
			if _shop_rect(i).has_point(p):
				var d: Dictionary = shop_defs[int(slist[idx])]
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
		if btn_newrun.has_point(p):
			state = CLASS
			_sfx("ui")
		elif btn_shop.has_point(p):
			shop_return = DEAD
			shop_page = 0
			state = SHOP
			_sfx("ui")
		return
	# playing
	if mode == "adv":
		_adv_input(p)
		return
	if _act_rect().has_point(p):
		_act_use()
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
	_adv_layout()
	if state != last_state:
		last_state = state
		state_t = t
	if state == INTRO and t - state_t > INTRO_LEN:
		state = MODE
	if bank_disp < 0.0 or absf(bank_disp - bank) < 1.0:
		bank_disp = float(bank)
	else:
		bank_disp = move_toward(bank_disp, float(bank), maxf(2.0, absf(bank_disp - bank) * dt * 5.0))
	if state == MODE or state == SAVES or state == LEADER or state == TUTORIAL or state == SHOP or state == CLASS or state == SETTINGS:
		modulate.a = clampf(0.3 + (t - state_t) * 6.0, 0.0, 1.0)
	elif modulate.a < 1.0:
		modulate.a = 1.0
	_anim_update(dt)
	if inv_vel != 0.0:
		if state == INV and (inv_tab == 0 or inv_tab == 3):
			inv_scroll += inv_vel * dt
			inv_vel *= exp(-dt * 3.5)
			if inv_scroll <= 0.0 or inv_scroll >= inv_scroll_max:
				inv_scroll = clampf(inv_scroll, 0.0, inv_scroll_max)
				inv_vel = 0.0
			elif absf(inv_vel) < 8.0:
				inv_vel = 0.0
		else:
			inv_vel = 0.0
	if state == PLAY and mode == "adv":
		cam = cam.lerp(Vector2(6, 6) if arena else vis_pos, minf(1.0, dt * 12.0))
		joy_t += dt
		if joy_on:
			walk.clear()
			if joy_dir != Vector2i.ZERO and joy_t >= JOY_STEP and _aopen(pos + joy_dir):
				joy_t = 0.0
				_adv_step(pos + joy_dir, true)
		elif walk.size() > 0:
			walk_t += dt
			if walk_t >= 0.11:
				walk_t = 0.0
				var anc: Vector2i = walk.pop_front()
				_adv_step(anc, walk.is_empty())
	elif state == PLAY and walk.size() > 0:
		walk_t += dt
		if walk_t >= 0.12:
			walk_t = 0.0
			var nc: Vector2i = walk.pop_front()
			if is_dark(nc):
				walk.clear()
			else:
				_step(nc)
	if imp_wait and state == SAVES and OS.has_feature("web"):
		_xfer_import_poll()
	if state == PLAY and walk.is_empty() and not save_off and t - save_t > 0.4:
		var sg := _save_sig()
		if sg != save_last_sig:
			save_last_sig = sg
			save_t = t
			_save_run()
	var i := pops.size() - 1
	while i >= 0:
		if t - float(pops[i]["t"]) > POP_LIFE:
			pops.remove_at(i)
		i -= 1
	queue_redraw()


# ---------- animation layer ----------

func _wp(cf: Vector2) -> Vector2:
	if mode == "adv":
		return Vector2(AMX + (cf.x - cam.x) * AC, AMY + (cf.y - cam.y) * AC)
	return Vector2(GX + (cf.x + 0.5) * cell, GY + (cf.y + 0.5) * cell)


func _fx_band() -> Rect2:
	if mode == "adv":
		return Rect2(0, 318, 720, MAPB - 318.0)
	return Rect2(GX, GY, N * cell, N * cell)


func _shake(amp: float, dur := 0.25) -> void:
	if set_shake == 0:
		return
	var age := t - shake_t0
	var cur := 0.0
	if age < shake_dur:
		cur = shake_amp * (1.0 - age / shake_dur)
	if amp >= cur:
		shake_amp = amp
		shake_t0 = t
		shake_dur = dur


func _shake_off() -> Vector2:
	var age := t - shake_t0
	if age >= shake_dur:
		return Vector2.ZERO
	var k := 1.0 - age / shake_dur
	return Vector2(sin(t * 83.0), cos(t * 71.0)) * shake_amp * k * k


func _map_begin() -> void:
	tr_base = _shake_off()
	draw_set_transform(tr_base)


func _map_end() -> void:
	tr_base = Vector2.ZERO
	draw_set_transform(Vector2.ZERO)


func _spr_ex(tex: Texture2D, ctr: Vector2, ssz: float, mod: Color, flip: float, rot: float, sx: float, sy: float) -> void:
	if tex.has_meta("scl"):
		ssz *= float(tex.get_meta("scl"))
	draw_set_transform_matrix(Transform2D(rot, Vector2(sx * flip, sy), 0.0, ctr + tr_base))
	draw_texture_rect(tex, Rect2(-ssz * 0.5, -ssz * 0.5, ssz, ssz), false, mod)
	draw_set_transform(tr_base)


func _fx_spark(p: Vector2, v: Vector2, col: Color, life: float, size: float, drag := 3.0) -> void:
	if fx.size() > 420:
		return
	fx.append({"k": "spark", "p": p, "v": v, "t0": t, "life": life, "col": col, "s": size, "drag": drag})


func _fx_burst(p: Vector2, col: Color, n: int, speed: float, life := 0.5, size := 6.0) -> void:
	for i in n:
		var a := randf() * TAU
		var sp := speed * (0.35 + randf() * 0.85)
		_fx_spark(p, Vector2(cos(a), sin(a)) * sp, col.lerp(Color.WHITE, randf() * 0.4), life * (0.7 + randf() * 0.6), size * (0.6 + randf() * 0.8))


func _fx_ring(p: Vector2, col: Color, r1: float, life := 0.45, w := 4.0, delay := 0.0, scr := false) -> void:
	if fx.size() > 420:
		return
	fx.append({"k": "ring", "p": p, "t0": t, "d": delay, "life": life, "col": col, "r": r1, "w": w, "scr": scr})


func _fx_hit(c: Vector2i, crit: bool, lunge := true) -> void:
	var cf := Vector2(c)
	var dv := Vector2(c - pos).normalized() if c != pos else Vector2(0, -1)
	if lunge:
		p_atk_t0 = t
		p_atk_dir = dv
	mon_hit[c] = [t, dv, 0]
	var col := Color("ffd84f") if crit else Color("fff0d0")
	fx.append({"k": "slash", "p": cf, "t0": t, "life": 0.3, "ang": dv.angle(), "col": col, "crit": crit})
	_fx_burst(cf, col, 14 if crit else 7, 3.6 if crit else 2.8, 0.35, 5.0)
	_shake(6.0 if crit else 2.6, 0.3 if crit else 0.18)
	if crit:
		_fx_ring(cf, col, 0.8, 0.35, 5.0)


func _fx_death(c: Vector2i) -> void:
	if not mons.has(c) or themes.is_empty():
		return
	var base_lv: int = mons[c]
	var is_boss := boss_floor and c == boss_cell
	var ti := tidx()
	var cols: Array = themes[ti]["mcols"]
	var body: Color = cols[(base_lv - 1) % cols.size()]
	var big := is_boss or elite.has(c)
	var cf := Vector2(c)
	fx.append({"k": "ghost", "p": cf, "t0": t, "life": 0.55, "ti": ti, "lv": base_lv, "boss": is_boss, "face": _mon_face(c), "tex": spr_gen.turret(ti, int(tur[c]["v"]), int(tur[c]["d"])) if tur.has(c) else null})
	_fx_burst(cf, body, 40 if is_boss else (26 if big else 16), 4.4 if big else 3.4, 0.7, 7.0)
	_fx_burst(cf, Color.WHITE, 8, 5.0, 0.3, 4.0)
	_fx_ring(cf, body.lightened(0.4), 0.9, 0.45, 5.0)
	if big:
		_fx_burst(cf, Color("ffd84f"), 16, 5.0, 0.8, 6.0)
		_fx_ring(cf, Color("ffd84f"), 1.4, 0.6, 4.0, 0.08)
	if is_boss:
		_fx_ring(cf, Color.WHITE, 2.2, 0.8, 5.0, 0.18)
	_shake(9.0 if is_boss else (5.0 if big else 3.0), 0.5 if is_boss else 0.3)


func _fx_pickup(c: Vector2i, kind: String) -> void:
	var from := _wp(Vector2(c))
	var tgt := Vector2(110, 232)
	var col := Color("ffc93c")
	if kind == "coin":
		pass
	elif kind == "pot" or kind == "big":
		tgt = Vector2(170, 251)
		col = Color("ffd84f") if kind == "pot" else Color("4fd1ff")
	elif kind == "hp" or kind == "armor" or kind == "shield":
		tgt = Vector2(530, 234)
		col = Color("ff8a9a") if kind == "hp" else Color("9fb3d9")
	elif kind == "pod":
		tgt = Vector2(530, 206)
		col = Color("7fd8ff")
	elif kind == "key":
		tgt = Vector2(70, 266)
		col = Color("ffd84f")
	elif kind.begins_with("use_"):
		tgt = _slot_rect(clampi(inv.size() - 1, 0, maxi(0, slots_n() - 1))).get_center()
		col = use_defs[kind.substr(4)]["col"]
	elif kind.begins_with("gear_"):
		tgt = Vector2(648, 43)
		col = _gear_col(String(gear_defs[gb(kind.substr(5))]["slot"]))
	else:
		tgt = _wp(vis_pos)
		col = Color("ffe9a0")
	fx.append({"k": "fly", "sp": from, "tp": tgt, "t0": t, "life": 0.6, "col": col, "kind": kind})
	_fx_burst(Vector2(c), col, 8, 2.6, 0.4, 4.0)
	_fx_ring(Vector2(c), col, 0.5, 0.3, 3.0)


func _fx_levelup() -> void:
	lvl_t0 = t
	lvl_n = level
	var cf := vis_pos
	_fx_ring(cf, Color("ffd84f"), 0.9, 0.5, 6.0)
	_fx_ring(cf, Color.WHITE, 1.5, 0.6, 4.0, 0.1)
	_fx_ring(cf, Color("ffd84f"), 2.2, 0.7, 3.0, 0.2)
	for i in 26:
		var a := randf_range(-PI * 0.95, -PI * 0.05)
		_fx_spark(cf + Vector2(randf_range(-0.4, 0.4), 0.1), Vector2(cos(a) * 1.6, sin(a) * 4.2), Color("ffe680").lerp(Color.WHITE, randf() * 0.5), randf_range(0.7, 1.2), randf_range(4.0, 8.0), 1.6)
	_shake(3.0, 0.2)


func _fx_door() -> void:
	door_t0 = t
	var cf := Vector2(stairs)
	_fx_burst(cf, Color("6dff9a"), 30, 4.0, 0.8, 6.0)
	_fx_ring(cf, Color("6dff9a"), 1.2, 0.6, 5.0)
	_fx_ring(cf, Color.WHITE, 1.9, 0.8, 3.0, 0.12)
	_shake(4.0, 0.3)
	_sfx("big")


func _fx_bolt(a: Vector2, b: Vector2, col := Color("ffe14f")) -> void:
	var pts: Array = [a]
	var n := 7
	var d := b - a
	var perp := Vector2(-d.y, d.x).normalized()
	for i in range(1, n):
		pts.append(a + d * (float(i) / n) + perp * randf_range(-0.22, 0.22))
	pts.append(b)
	fx.append({"k": "bolt", "pts": pts, "t0": t, "life": 0.3, "col": col})
	_fx_burst(b, col, 10, 3.5, 0.4, 5.0)
	_shake(4.0, 0.22)


func _p_off() -> Vector2:
	var o := Vector2.ZERO
	var a := t - p_atk_t0
	if a < 0.2:
		o += p_atk_dir * cell * 0.28 * sin(a / 0.2 * PI)
	var h := t - p_hit_t0
	if h < 0.25:
		o += Vector2(sin(h * 90.0), 0.0) * 5.0 * (1.0 - h / 0.25)
	return o


func _mon_off(c: Vector2i) -> Vector2:
	var o := Vector2.ZERO
	if mon_slide.has(c):
		var sl: Array = mon_slide[c]
		var k := clampf((t - float(sl[1])) / 0.22, 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		o += (sl[0] as Vector2) * (1.0 - e) * cell
	if mon_hit.has(c):
		var h: Array = mon_hit[c]
		var a := t - float(h[0])
		if a < 0.3:
			var kk := 1.0 - a / 0.3
			o += (h[1] as Vector2) * cell * 0.22 * kk * kk + Vector2(sin(a * 95.0) * 4.0 * kk, 0.0)
	if mon_lunge.has(c):
		var l: Array = mon_lunge[c]
		var a2 := t - float(l[0])
		if a2 >= 0.0 and a2 < 0.26:
			o += (l[1] as Vector2) * cell * 0.34 * sin(a2 / 0.26 * PI)
	return o


func _draw_player(prc: Vector2, sz: float) -> void:
	var moving := vis_pos.distance_to(Vector2(pos)) > 0.05
	var fr := 0
	var hop := 0.0
	var wob := 0.0
	var sy := 1.0 + 0.025 * sin(t * 2.6)
	var lean := 0.0
	if moving:
		fr = 1 + int(walk_phase) % 2
		var sn := absf(sin(walk_phase * PI))
		hop = sn * sz * 0.1
		sy = 1.0 + 0.06 * sn - 0.05 * (1.0 - sn)
		wob = sin(walk_phase * PI) * 0.05
		lean = clampf(Vector2(pos).x - vis_pos.x, -1.0, 1.0) * 0.1
	var sx := 1.0 + (1.0 - sy) * 0.8
	var feet := -(sy - 1.0) * sz * 0.5
	var tex := _player_tex(fr)
	var at := prc + Vector2(0, -hop + feet)
	_spr_ex(tex, at, sz, Color(0.7, 0.8, 1.0, 0.45 + 0.1 * sin(t * 4.0)) if cloak_steps > 0 else Color.WHITE, 1.0, wob + lean, sx, sy)
	var fl := clampf(1.0 - (t - p_hit_t0) / 0.3, 0.0, 1.0)
	if fl > 0.0:
		_spr_ex(spr_gen.white(tex), at, sz, Color(1.0, 0.35, 0.35, fl * 0.85), 1.0, wob + lean, sx, sy)


func _draw_mon_sprite(c: Vector2i, ctr: Vector2, ti: int, base_lv: int, is_boss: bool, sz: float, mod := Color.WHITE, asleep := false, yoff := 0.0, tex_over: ImageTexture = null) -> void:
	var hop := 0.0
	var fl := 0.0
	var squash := 1.0
	if mon_slide.has(c):
		var sl: Array = mon_slide[c]
		var k := clampf((t - float(sl[1])) / 0.22, 0.0, 1.0)
		if k < 1.0:
			hop = sin(k * PI) * sz * 0.14
			squash = 1.0 + 0.08 * sin(k * PI)
	if mon_hit.has(c):
		var h: Array = mon_hit[c]
		var a := t - float(h[0])
		if a < 0.3:
			var kk := 1.0 - a / 0.3
			fl = kk
			squash *= 1.0 - 0.18 * kk
	var ph := t * 2.2 + float(c.x * 7 + c.y * 13)
	var sy := squash * (1.0 + (0.0 if asleep else 0.035 * sin(ph)))
	var sx := 1.0 + (1.0 - sy) * 0.7
	var bl := asleep or fmod(t * 0.42 + float(c.x * 37 + c.y * 91) * 0.173, 1.0) > 0.93
	var tex: ImageTexture = tex_over if tex_over != null else _monster_tex(ti, base_lv, is_boss, bl, 0 if asleep else _mon_face(c))
	var at := ctr + Vector2(0, -hop + yoff - (sy - 1.0) * sz * 0.5)
	_spr_ex(tex, at, sz, mod, 1.0, 0.0, sx, sy)
	if fl > 0.0:
		_spr_ex(spr_gen.white(tex), at, sz, Color(1, 1, 1, fl * 0.85), 1.0, 0.0, sx, sy)


func _glint(c: Vector2, gs: float, ph: float, col := Color(1, 1, 0.9)) -> void:
	var g := pow(maxf(0.0, sin(t * 1.9 + ph)), 16.0)
	if g < 0.06:
		return
	var l := gs * g
	var cc := Color(col.r, col.g, col.b, g)
	draw_line(c + Vector2(-l, 0), c + Vector2(l, 0), cc, 2.0)
	draw_line(c + Vector2(0, -l), c + Vector2(0, l), cc, 2.0)
	draw_line(c + Vector2(-l, -l) * 0.5, c + Vector2(l, l) * 0.5, Color(cc.r, cc.g, cc.b, g * 0.5), 1.5)
	draw_line(c + Vector2(l, -l) * 0.5, c + Vector2(-l, l) * 0.5, Color(cc.r, cc.g, cc.b, g * 0.5), 1.5)
	draw_circle(c, 1.5 + 2.0 * g, Color(1, 1, 1, g))


func _draw_coin(ctr: Vector2, bob: float, csz: float, ph: float) -> void:
	var spin := absf(cos(t * 3.2 + ph))
	var w := csz * (0.18 + 0.82 * spin)
	draw_texture_rect(_item_tex("coin"), Rect2(ctr.x - w * 0.5, ctr.y + bob - csz * 0.5, w, csz), false)
	_glint(ctr + Vector2(csz * 0.28, -csz * 0.3 + bob), csz * 0.4, ph * 1.7)


func _fog_a(c: Vector2i, dim: float) -> float:
	var rv: float = reveal.get(c, 0.0)
	var vf: float = vfade.get(c, 0.0)
	return 1.0 - rv * (1.0 - dim * (1.0 - vf))


func _amb_draw(band: Rect2, ti: int) -> void:
	var cx := cam.x * AC * 0.35 if mode == "adv" else 0.0
	var cy := cam.y * AC * 0.35 if mode == "adv" else 0.0
	for a in amb:
		var sp: float = a[2]
		var ph: float = a[3]
		var sz: float = a[4]
		var x := fposmod(float(a[0]) - cx + sin(t * sp + ph) * 24.0, 720.0)
		var y := 0.0
		if ti == 0:
			y = fposmod(float(a[1]) - cy + t * 7.0 * sp, 1280.0)
		elif ti == 1:
			y = fposmod(float(a[1]) - cy - t * 15.0 * sp, 1280.0)
		elif ti == 3:
			y = fposmod(float(a[1]) - cy - t * 9.0 * sp, 1280.0)
		else:
			y = fposmod(float(a[1]) - cy - t * 30.0 * sp, 1280.0)
		if not band.has_point(Vector2(x, y)):
			continue
		if ti == 0:
			draw_rect(Rect2(x, y, sz * 0.6, sz * 0.6), Color(0.75, 0.88, 1.0, 0.1))
		elif ti == 1:
			var g := 0.5 + 0.5 * sin(t * 1.6 * sp + ph)
			var col := Color(0.55, 1.0, 0.65) if int(ph * 10.0) % 3 != 0 else Color(1.0, 0.65, 0.85)
			draw_circle(Vector2(x, y), sz * 2.4, Color(col.r, col.g, col.b, 0.07 + 0.08 * g))
			draw_circle(Vector2(x, y), sz * 0.55, Color(col.r, col.g, col.b, 0.35 + 0.5 * g))
		elif ti == 3:
			var tw2 := pow(maxf(0.0, sin(t * 2.2 * sp + ph * 4.0)), 6.0)
			var col3 := Color(0.85, 0.6, 1.0) if int(ph * 10.0) % 2 == 0 else Color(0.5, 0.92, 1.0)
			draw_circle(Vector2(x, y), sz * 1.4, Color(col3.r, col3.g, col3.b, 0.05 + 0.06 * tw2))
			draw_line(Vector2(x - sz * 1.2 * tw2, y), Vector2(x + sz * 1.2 * tw2, y), Color(col3.r, col3.g, col3.b, 0.2 + 0.7 * tw2), 1.5)
			draw_line(Vector2(x, y - sz * 1.2 * tw2), Vector2(x, y + sz * 1.2 * tw2), Color(col3.r, col3.g, col3.b, 0.2 + 0.7 * tw2), 1.5)
		else:
			var fl := 0.5 + 0.5 * sin(t * 9.0 * sp + ph * 3.0)
			var col2 := Color(1.0, 0.55 + 0.25 * fl, 0.2)
			draw_circle(Vector2(x, y), sz * 1.6, Color(col2.r, col2.g, col2.b, 0.08))
			draw_rect(Rect2(x, y, sz * 0.5, sz * 0.5), Color(col2.r, col2.g, col2.b, 0.35 + 0.45 * fl))


func _fx_draw() -> void:
	for f in fx:
		var k: String = f["k"]
		if k == "fly" or (k == "ring" and f["scr"]):
			continue
		var age := t - float(f["t0"]) - float(f.get("d", 0.0))
		if age < 0.0:
			continue
		var u := age / float(f["life"])
		if k == "spark":
			var drag: float = f["drag"]
			var wp: Vector2 = (f["p"] as Vector2) + (f["v"] as Vector2) * ((1.0 - exp(-drag * age)) / drag)
			var sp := _wp(wp)
			var col: Color = f["col"]
			var s := float(f["s"]) * (1.0 - u * 0.75)
			draw_circle(sp, s * 1.9, Color(col.r, col.g, col.b, 0.2 * (1.0 - u)))
			draw_rect(Rect2(sp - Vector2(s, s) * 0.5, Vector2(s, s)), Color(col.r, col.g, col.b, 1.0 - u * u))
		elif k == "ring":
			var col3: Color = f["col"]
			var e := 1.0 - (1.0 - u) * (1.0 - u)
			var rr := float(f["r"]) * cell * (0.25 + 0.75 * e)
			var cc2 := _wp(f["p"])
			draw_arc(cc2, rr, 0, TAU, 40, Color(col3.r, col3.g, col3.b, (1.0 - u) * 0.9), maxf(1.0, float(f["w"]) * (1.0 - u)))
			draw_arc(cc2, rr * 0.82, 0, TAU, 36, Color(col3.r, col3.g, col3.b, (1.0 - u) * 0.3), 2.0)
		elif k == "slash":
			var col4: Color = f["col"]
			var cc3 := _wp(f["p"])
			var dd := Vector2.from_angle(float(f["ang"]) + 0.9)
			var pp := Vector2(-dd.y, dd.x)
			var lens := cell * (0.62 if f["crit"] else 0.48)
			for j in range(-1, 2):
				var off := pp * j * cell * 0.13
				var a0 := cc3 + off - dd * lens
				var a1 := cc3 + off + dd * lens
				var hd := a0.lerp(a1, clampf(u * 2.4, 0.0, 1.0))
				var tl := a0.lerp(a1, clampf(u * 2.4 - 0.7, 0.0, 1.0))
				var w := (7.0 if j == 0 else 3.5) * (1.0 - u * 0.6)
				draw_line(tl, hd, Color(col4.r, col4.g, col4.b, (1.0 - u) * 0.95), w)
			draw_circle(cc3, cell * 0.3 * (1.0 - u), Color(1, 1, 1, 0.35 * (1.0 - u)))
		elif k == "ghost":
			var tex = f.get("tex")
			if tex == null:
				tex = _monster_tex(int(f["ti"]), int(f["lv"]), bool(f["boss"]), false, int(f.get("face", 0)))
			var gsz := (AC if mode == "adv" else cell) * ((0.98 if mode == "adv" else 0.92) if f["boss"] else 0.8) * (1.08 if f.get("tex") != null else 1.0)
			var gc := _wp(f["p"])
			if u < 0.2:
				var q := u / 0.2
				var sc := 1.0 + 0.25 * q
				_spr_ex(tex, gc + Vector2(0, -4), gsz, Color.WHITE, 1.0, 0.0, sc, sc)
				_spr_ex(spr_gen.white(tex), gc + Vector2(0, -4), gsz, Color(1, 1, 1, 0.9 - 0.4 * q), 1.0, 0.0, sc, sc)
			else:
				var q2 := (u - 0.2) / 0.8
				var sc2 := 1.25 * (1.0 - q2) * (1.0 - q2)
				_spr_ex(tex, gc + Vector2(0, -4 - q2 * 14.0), gsz, Color(1, 1, 1, 1.0 - q2), 1.0, q2 * 0.9, sc2, sc2)
				_spr_ex(spr_gen.white(tex), gc + Vector2(0, -4 - q2 * 14.0), gsz, Color(1, 1, 1, 0.5 * (1.0 - q2)), 1.0, q2 * 0.9, sc2, sc2)
		elif k == "bolt":
			var pts: Array = f["pts"]
			var pl := PackedVector2Array()
			for pt in pts:
				pl.append(_wp(pt))
			var bc: Color = f["col"]
			draw_polyline(pl, Color(bc.r, bc.g, bc.b, (1.0 - u) * 0.4), 10.0)
			draw_polyline(pl, Color(1, 1, 0.8, 1.0 - u), 3.0)
		elif k == "rope":
			var rp0 := _wp(vis_pos)
			var rtip := _wp(f["a"]).lerp(_wp(f["b"]), clampf(u / 0.3, 0.0, 1.0))
			var ral := 1.0 if u < 0.7 else (1.0 - u) / 0.3
			var rdir := (rtip - rp0).normalized()
			var rprp := Vector2(-rdir.y, rdir.x)
			draw_line(rp0, rtip, Color(0.3, 0.19, 0.08, ral), 6.0)
			draw_line(rp0, rtip, Color(0.82, 0.66, 0.42, ral), 3.0)
			var rhc := Color(0.82, 0.88, 1.0, ral)
			draw_circle(rtip, 7.0, rhc)
			draw_line(rtip, rtip + rdir * 6.0 + rprp * 10.0, rhc, 4.0)
			draw_line(rtip, rtip + rdir * 6.0 - rprp * 10.0, rhc, 4.0)


func _bez(a: Vector2, b: Vector2, c: Vector2, u: float) -> Vector2:
	return a.lerp(b, u).lerp(b.lerp(c, u), u)


func _fx_draw_top() -> void:
	var band := _fx_band()
	for f in fx:
		var k: String = f["k"]
		var age := t - float(f["t0"]) - float(f.get("d", 0.0))
		if age < 0.0:
			continue
		var u := age / float(f["life"])
		if k == "fly":
			var sp: Vector2 = f["sp"]
			var tp: Vector2 = f["tp"]
			var col: Color = f["col"]
			var ctl := (sp + tp) * 0.5 + Vector2(0, -150)
			var e := u * u * (3.0 - 2.0 * u)
			var p := _bez(sp, ctl, tp, e)
			for j in range(1, 7):
				var pj := _bez(sp, ctl, tp, maxf(0.0, e - j * 0.05))
				draw_circle(pj, 6.0 - j * 0.8, Color(col.r, col.g, col.b, 0.5 * (1.0 - j / 7.0)))
			var kind: String = f["kind"]
			var fsz := 44.0 * (1.0 - 0.5 * u)
			if kind == "coin":
				var w := fsz * (0.2 + 0.8 * absf(cos(age * 14.0)))
				draw_texture_rect(_item_tex("coin"), Rect2(p.x - w * 0.5, p.y - fsz * 0.5, w, fsz), false)
			elif kind in ["pot", "big", "shield", "hp", "armor", "lamp"]:
				_spr(_item_tex(kind), p, fsz)
			else:
				draw_circle(p, fsz * 0.5, Color(col.r, col.g, col.b, 0.3))
				draw_circle(p, fsz * 0.24, col.lightened(0.3))
				draw_circle(p, fsz * 0.1, Color.WHITE)
		elif k == "ring" and f["scr"]:
			var col2: Color = f["col"]
			var rr := float(f["r"]) * (0.3 + 0.7 * (1.0 - (1.0 - u) * (1.0 - u)))
			draw_arc(f["p"], rr, 0, TAU, 28, Color(col2.r, col2.g, col2.b, 1.0 - u), 3.0)
	# level-up flash and banner
	var a := t - lvl_t0
	if a < 1.7:
		var fk := clampf(1.0 - a / 0.4, 0.0, 1.0)
		if fk > 0.0:
			draw_rect(band, Color(1, 0.96, 0.7, 0.3 * fk))
		var e2 := minf(a / 0.25, 1.0)
		var fs := int(66.0 * (0.4 + 0.6 * e2 + 0.18 * sin(e2 * PI)))
		var al := clampf((1.7 - a) / 0.5, 0.0, 1.0)
		var y := band.position.y + band.size.y * 0.36 - a * 14.0
		_txt("LEVEL UP!", Vector2(3, y + 4), fs, Color(0, 0, 0, 0.6 * al))
		_txt("LEVEL UP!", Vector2(0, y), fs, Color(1, 0.85, 0.25, al))
		_txt("LV %d" % lvl_n, Vector2(0, y + 52), 36, Color(1, 1, 1, al))
	# damage and low air vignettes
	var hurt := clampf(1.0 - (t - p_hit_t0) / 0.5, 0.0, 1.0)
	var low := 0.0
	if mode == "adv" and state == PLAY and oxy < oxy_max * 0.25:
		low = 0.5 + 0.5 * sin(t * 5.0)
	if hurt > 0.0 or low > 0.0:
		for i in 7:
			var fade := 1.0 - i / 7.0
			var rr2 := Rect2(band.position.x + i * 7, band.position.y + i * 7, band.size.x - i * 14, band.size.y - i * 14)
			if hurt > 0.0:
				draw_rect(rr2, Color(1, 0.1, 0.1, 0.5 * hurt * fade), false, 7.0)
			if low > 0.0:
				draw_rect(rr2, Color(1, 0.2, 0.2, 0.25 * low * fade), false, 7.0)


func _anim_update(dt: float) -> void:
	if themes.is_empty():
		return
	var tgt := Vector2(pos)
	if anim_floor != floor_n or anim_mode != mode:
		anim_floor = floor_n
		anim_mode = mode
		vis_pos = tgt
		reveal.clear()
		vfade.clear()
		mon_slide.clear()
		mon_hit.clear()
		mon_lunge.clear()
		fx.clear()
		door_prev = mode == "adv" and adv_pts >= adv_req
		anim_level = level
	var d := tgt - vis_pos
	var dist := d.length()
	if dist > 2.6:
		vis_pos = tgt
		dist = 0.0
	elif dist > 0.001:
		vis_pos = vis_pos.move_toward(tgt, dt * 10.5)
	if dist > 0.05:
		walk_phase += dt * 9.0
		idle_t = 0.0
		if absf(d.x) > 0.02 or absf(d.y) > 0.02:
			if absf(d.x) >= absf(d.y):
				pdir = 3 if d.x > 0.0 else 2
			else:
				pdir = 0 if d.y > 0.0 else 1
	else:
		idle_t += dt
		if idle_t > 0.12:
			walk_phase = 0.0
	var steps := adv_steps if mode == "adv" else moves
	if level < anim_level:
		anim_level = level
	elif level > anim_level:
		if steps > 0 and state == PLAY and mode == "adv":
			_fx_levelup()
		anim_level = level
	if mode == "adv" and state == PLAY:
		var op := adv_pts >= adv_req
		if op and not door_prev:
			_fx_door()
		door_prev = op
		for cx in range(int(floor(vis_pos.x)) - 7, int(floor(vis_pos.x)) + 8):
			for cy in range(int(floor(vis_pos.y)) - 7, int(floor(vis_pos.y)) + 8):
				var c := Vector2i(cx, cy)
				if not _ain(c):
					continue
				reveal[c] = move_toward(float(reveal.get(c, 0.0)), 1.0 if _aseen(c) else 0.0, dt * 4.0)
				vfade[c] = move_toward(float(vfade.get(c, 0.0)), 1.0 if adv_vis.has(c) else 0.0, dt * 3.5)
	if fx_demo and state == PLAY and t > 3.0:
		fx_demo = false
		mons[pos + Vector2i(2, 0)] = 3
		_fx_hit(pos + Vector2i(1, 0), true)
		_fx_death(pos + Vector2i(2, 0))
		mons.erase(pos + Vector2i(2, 0))
		_fx_pickup(pos + Vector2i(-1, 0), "coin")
		_fx_pickup(pos + Vector2i(-1, 1), "hp")
		_fx_levelup()
		_fx_bolt(vis_pos, Vector2(pos + Vector2i(0, -2)))
		p_hit_t0 = t
	if pick_kind != "":
		var gone := not coin_at.has(pick_c) if pick_kind == "coin" else not items.has(pick_c)
		if gone:
			_fx_pickup(pick_c, pick_kind)
		pick_kind = ""
	for key in mon_slide.keys():
		if t - float(mon_slide[key][1]) > 0.6:
			mon_slide.erase(key)
	for key2 in mon_hit.keys():
		if t - float(mon_hit[key2][0]) > 0.6:
			mon_hit.erase(key2)
	for key3 in mon_lunge.keys():
		if t - float(mon_lunge[key3][0]) > 0.8:
			mon_lunge.erase(key3)
	var i := fx.size() - 1
	while i >= 0:
		var f: Dictionary = fx[i]
		if t - float(f["t0"]) - float(f.get("d", 0.0)) > float(f["life"]):
			if f["k"] == "fly":
				_fx_ring(f["tp"], f["col"], 26.0, 0.3, 3.0, 0.0, true)
			fx.remove_at(i)
		i -= 1


# ---------- saves menu ----------

func _saves_input(p: Vector2) -> void:
	if btn_sv_back.has_point(p):
		state = MODE
		_sfx("ui")
		return
	if btn_sv_copy.has_point(p):
		_xfer_copy_code()
		_sfx("ui")
		return
	if btn_sv_paste.has_point(p):
		_xfer_paste_code()
		_sfx("ui")
		return
	if OS.has_feature("web"):
		if btn_sv_fexp.has_point(p):
			_xfer_export()
			_sfx("ui")
		elif btn_sv_fimp.has_point(p):
			_xfer_import_start()
			_sfx("ui")


func _draw_saves(acc: Color) -> void:
	_txt("SAVES", Vector2(0, 200), 60, acc)
	_txt("Move your progress between devices", Vector2(0, 252), 24, Color(1, 1, 1, 0.7))
	_panel(Rect2(80, 360, 560, 252), Color("7fd8ff"), 0.05, false)
	_txt("SAVE CODE (works everywhere)", Vector2(0, 386), 20, Color(1, 1, 1, 0.6))
	_button(btn_sv_copy, "COPY SAVE CODE", Color("7dffb0"), 28, "copy")
	_button(btn_sv_paste, "PASTE SAVE CODE", Color("7fd8ff"), 28, "paste")
	if OS.has_feature("web"):
		_panel(Rect2(80, 640, 560, 252), Color("c9d3f0"), 0.05, false)
		_txt("SAVE FILE (web only)", Vector2(0, 666), 20, Color(1, 1, 1, 0.6))
		_button(btn_sv_fexp, "EXPORT FILE", Color("c9d3f0"), 28, "file")
		_button(btn_sv_fimp, "IMPORT FILE", Color("c9d3f0"), 28, "file")
	if t - xfer_t < 8.0:
		_para(xfer_msg, Vector2(60, 930), 24, Color("6dff9a"), 600.0)
	_button(btn_sv_back, "BACK", Color("ffd84f"), 28, "back")


func _sk_banner() -> void:
	var k := t - sk_ban_t0
	if sk_ban_n <= 0 or k < 0.0 or k > 4.0:
		return
	var a := minf(1.0, minf(k / 0.4, (4.0 - k) / 0.6))
	var br := Rect2(110, 352, 500, 84)
	draw_rect(br, Color(0.05, 0.06, 0.1, 0.88 * a))
	draw_rect(br, Color(1.0, 0.85, 0.31, a), false, 3.0)
	_ctext("+%d SKILL POINT%s" % [sk_ban_n, "S" if sk_ban_n > 1 else ""], br.get_center() + Vector2(0, -12), 30, Color(1.0, 0.85, 0.31, a))
	_ctext("Tap SKILLS to spend it", br.get_center() + Vector2(0, 20), 20, Color(1, 1, 1, 0.85 * a))


func _wbox_info(r: bool) -> Array:
	var sv := shooting
	shooting = r
	var id := String(equip.get("ranged" if r else "weapon", ""))
	var ok := id != "" and gear_defs.has(gb(id))
	var nm := gname(id) if ok else ("None" if r else "Fists")
	var l2 := ""
	if r:
		var dmg := _ranged_hv()
		l2 = "DMG %d   RNG %d   AMMO %d/%d" % [dmg, _shoot_range(), ammo, ammo_max()]
	else:
		l2 = "DMG %d" % p_atk()
		var cr := int(gear("crit"))
		if cr > 0:
			l2 += "   CRIT %d%%" % cr
	var tr := gtrait_line(id) if ok else ""
	shooting = sv
	return [nm, l2, tr]


# Weapon box: flips between the melee and ranged weapon stats.
func _wbox_draw() -> void:
	var has_r := _weapon_range() > 0
	var rg := ranged_mode and has_r
	var k := clampf(float(Time.get_ticks_msec() - wbox_t0) / 260.0, 0.0, 1.0) if has_r else 1.0
	var side := (wbox_from and has_r) if k < 0.5 else rg
	var sc := maxf(0.03, absf(cos(k * PI)))
	var bx := Rect2(24, 80, 324, 62)
	draw_set_transform(bx.get_center(), 0.0, Vector2(sc, 1.0))
	var lr := Rect2(-bx.size * 0.5, bx.size)
	var col := Color("ffc24f") if side else Color("ff8a4f")
	_panel(lr, col, 0.08, false)
	var info := _wbox_info(side)
	_txt(String(info[0]), Vector2(lr.position.x + 12, -12), 20, Color.WHITE, 210.0, HORIZONTAL_ALIGNMENT_LEFT)
	_txt("RANGED" if side else "MELEE", Vector2(lr.end.x - 112, -12), 14, col, 100.0, HORIZONTAL_ALIGNMENT_RIGHT)
	_txt(String(info[1]), Vector2(lr.position.x + 12, 9), 18, Color("ffd84f"), 300.0, HORIZONTAL_ALIGNMENT_LEFT)
	if String(info[2]) != "":
		_txt(String(info[2]), Vector2(lr.position.x + 12, 24), 13, Color(1, 1, 1, 0.6), 300.0, HORIZONTAL_ALIGNMENT_LEFT)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _hud_panels(acc: Color, right_h: float) -> void:
	_panel(Rect2(24, 146, 336, 134), acc, 0.08, false)
	_panel(Rect2(366, 156, 330, right_h), acc, 0.08, false)
	_panel(Rect2(40, 284, 640, 34), acc, 0.06, false)


func _edge_glow(col: Color, k: float) -> void:
	var pulse := 0.5 + 0.5 * sin(t * (4.0 + 5.0 * k))
	for i in 7:
		var a := (0.30 + 0.25 * pulse) * (1.0 - float(i) / 7.0) * (0.5 + 0.5 * k)
		draw_rect(Rect2(i * 7 + 3, i * 7 + 3, 720 - i * 14 - 6, 1280.0 + adv_ex - i * 14 - 6), Color(col.r, col.g, col.b, a), false, 7.0)


# Adventure on a tall phone: grow the view downward so the top HUD sits at the very top of the display and the
# bottom HUD at the very bottom; the extra height goes to the map window.
func _adv_layout() -> void:
	var w := get_window()
	var ex := 0.0
	if w != null and state == PLAY and mode == "adv" and set_fit == 0 and w.size.x > 0:
		var vh := 720.0 * float(w.size.y) / float(w.size.x)
		if vh > 1290.0:
			ex = floorf(minf(vh - 1280.0, 760.0))
	if w != null and set_fit == 0:
		var want := Window.CONTENT_SCALE_ASPECT_EXPAND if ex > 0.0 else Window.CONTENT_SCALE_ASPECT_KEEP
		if w.content_scale_aspect != want:
			w.content_scale_aspect = want
	adv_ex = ex
	MAPB = 1030.0 + ex
	AMY = 674.0 + ex * 0.5
	AC = 72.0 if arena else ADV_ZOOM


func _apply_display() -> void:
	var w := get_window()
	if w != null:
		w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS if set_res == 0 else Window.CONTENT_SCALE_MODE_VIEWPORT
		w.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP if set_fit == 0 else Window.CONTENT_SCALE_ASPECT_IGNORE
	Engine.max_fps = set_fps
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if set_filt == 0 else CanvasItem.TEXTURE_FILTER_LINEAR


func _set_rect(i: int) -> Rect2:
	return Rect2(110, 262 + i * 100, 500, 58)


# Top-row buttons: 64px tall (74 with large buttons) so they are easy to hit with a thumb.
func _layout_buttons() -> void:
	var h := 64.0 if set_big == 0 else 74.0
	var w := 116.0 if set_big == 0 else 128.0
	btn_sound = Rect2(10, 40, w, h)
	btn_invmenu = btn_sound   # bag "menu" and class "< mode" take the sound button's spot and size
	btn_modeback = btn_sound
	btn_inv = Rect2(710.0 - w, 40, w, h)
	btn_menu = btn_inv
	btn_reset = btn_inv
	btn_skill = Rect2(btn_inv.position.x - 6.0 - w, 40, w, h)


# Adventure bottom cluster (thumb zone): tool row, then badges + class power + weapon toggle.
func _slot_sz() -> float:
	return 84.0 if set_big == 0 else 92.0


func _row2_h() -> float:
	return 96.0 if set_big == 0 else 100.0


func _cancel_rect() -> Rect2:
	return Rect2(16, 992.0 + adv_ex, 688, 62)


func _settings_input(p: Vector2) -> void:
	if SET_TITLE.has_point(p) and not test_unlocked:
		set_taps = set_taps + 1 if t - set_tap_t < 1.5 else 1
		set_tap_t = t
		if set_taps >= 5:
			test_unlocked = true
			_sfx("big")
		return
	if test_unlocked and BTN_TEST.has_point(p):
		test_pending = true
		mode = "adv"
		set_ret = MODE
		state = CLASS
		_sfx("big")
		return
	if btn_sound.has_point(p):
		snd_on = not snd_on
		_apply_sound()
		_sfx("ui")
		return
	if btn_sv_back.has_point(p):
		state = set_ret
		set_ret = MODE
		_sfx("ui")
		return
	for i in 7:
		if _set_rect(i).has_point(p):
			if i == 0:
				set_res = 1 - set_res
			elif i == 1:
				set_fit = 1 - set_fit
			elif i == 2:
				set_fps = 60 if set_fps == 30 else (120 if set_fps == 60 else 30)
			elif i == 3:
				set_shake = 1 - set_shake
			elif i == 4:
				set_mus = (set_mus + 1) % 4
				_apply_sound()
			elif i == 5:
				set_sfxv = (set_sfxv + 1) % 4
			else:
				set_vib = 1 - set_vib
				_buzz(60)
			_apply_display()
			_save_meta()
			_sfx("ui")
			return


func _draw_gear(gc: Vector2, col: Color) -> void:
	var pr := t - press_t < 0.14 and gc.distance_to(press_p) <= 40.0
	var r := 33.0 if pr else 35.0
	draw_circle(gc, r, Color(0.06, 0.09, 0.17, 0.92))
	draw_arc(gc, r, 0.0, TAU, 40, col, 3.0)
	for k in 8:
		var a := float(k) * TAU / 8.0
		draw_line(gc + Vector2.from_angle(a) * 14.0, gc + Vector2.from_angle(a) * 23.0, col, 7.0)
	draw_arc(gc, 15.0, 0.0, TAU, 28, col, 7.0)
	draw_circle(gc, 7.0, Color(0.06, 0.09, 0.17))


func _draw_settings(acc: Color) -> void:
	_button(btn_sound, "SOUND ON" if snd_on else "SOUND OFF", acc)
	_txt("SETTINGS", Vector2(0, 200), 60, acc)
	_txt("Saved on this device", Vector2(0, 252), 24, Color(1, 1, 1, 0.7))
	var labels := [
		"RESOLUTION: " + ("NATIVE" if set_res == 0 else "720p"),
		"SCREEN: " + ("FIT" if set_fit == 0 else "STRETCH"),
		"FRAME RATE: %d" % set_fps,
		"SHAKE: " + ("ON" if set_shake == 1 else "OFF"),
		"MUSIC: " + String(VOL_NAMES[set_mus]),
		"SOUND FX: " + String(VOL_NAMES[set_sfxv]),
		"VIBRATION: " + ("ON" if set_vib == 1 else "OFF"),
	]
	var hints := [
		"Native is sharpest. 720p is faster on weak phones.",
		"Fit keeps proportions. Stretch fills the screen.",
		"30 saves battery. 60 is smoother.",
		"Screen shake on hits and blasts.",
		"Music volume. SOUND ON/OFF (top left) mutes all.",
		"Volume of sound effects.",
		"Short buzzes on hits, kills and taps (phones).",
	]
	for i in 7:
		var r := _set_rect(i)
		_button(r, String(labels[i]), Color("c9d3f0"), 24)
		_txt(String(hints[i]), Vector2(0, r.end.y + 30), 23, Color(1, 1, 1, 0.7))
	_button(btn_sv_back, "BACK", Color("ffd84f"), 28, "back")
	if test_unlocked:
		_button(BTN_TEST, "TEST ROOM (all gear)", Color("ff8af0"), 26)


func _para_fit(s: String, p: Vector2, size: int, col: Color, w: float, max_lines: int) -> void:
	var fs := size
	while fs > 11:
		var sz := font.get_multiline_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, w, fs)
		if int(round(sz.y / font.get_height(fs))) <= max_lines:
			break
		fs -= 1
	draw_multiline_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, w, fs, -1, col)


func _lb_name_edit_open() -> void:
	if name_edit == null:
		name_edit = LineEdit.new()
		name_edit.max_length = 12
		name_edit.placeholder_text = "Your name"
		name_edit.add_theme_font_size_override("font_size", 30)
		name_edit.position = Vector2(110, 340)
		name_edit.size = Vector2(500, 76)
		name_edit.text_submitted.connect(_lb_name_done)
		add_child(name_edit)
	name_edit.text = lb_name
	name_edit.visible = true
	name_edit.grab_focus()


func _lb_name_done(txt: String) -> void:
	if name_edit != null:
		name_edit.visible = false
		name_edit.release_focus()
	DisplayServer.virtual_keyboard_hide()
	var n := _lb_clean(txt)
	if n == "":
		return
	lb_name = n
	_save_meta()
	_lb_resubmit()
	_lb_fetch()


# ---------- leaderboard ----------

func _lb_key(i: int) -> String:
	return "puzzle" if i == 0 else "adv"


func _lb_clean(s: String) -> String:
	var out := ""
	for ch in s.strip_edges():
		var ok := (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == " " or ch == "_" or ch == "-" or ch == "."
		if ok:
			out += ch
	return out.strip_edges().substr(0, 12)


func _lb_ask_name() -> bool:
	if not OS.has_feature("web"):
		if lb_name == "":
			lb_name = "Player"
			_save_meta()
		return true
	var r = JavaScriptBridge.eval("prompt('Your name for the leaderboard (max 12 letters or numbers):', %s)" % JSON.stringify(lb_name))
	if r == null:
		return false
	var n := _lb_clean(String(r))
	if n == "":
		return false
	lb_name = n
	_save_meta()
	return true


func _lb_note(reached: int, allow_prompt: bool) -> void:
	if lb_url == "" or reached <= 0:
		return
	var key := "adv" if mode == "adv" else "puzzle"
	if reached <= int(lb_sent.get(key, 0)):
		return
	if lb_name == "":
		if not allow_prompt or not _lb_ask_name():
			return
	_lb_put(key, reached)


func _lb_resubmit() -> void:
	if lb_url == "" or lb_name == "":
		return
	if best > 0:
		_lb_put("puzzle", best)
	if adv_best > 0:
		_lb_put("adv", adv_best)


func _lb_put(key: String, floors: int) -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(_lb_put_done.bind(req, key, floors))
	var body := JSON.stringify({"n": lb_name, "f": floors, "c": cls, "t": int(Time.get_unix_time_from_system())})
	var err := req.request(lb_url + "/lb/%s/%s.json" % [key, lb_uid], PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_PUT, body)
	if err != OK:
		req.queue_free()


func _lb_put_done(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray, req: HTTPRequest, key: String, floors: int) -> void:
	req.queue_free()
	if result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300:
		lb_sent[key] = maxi(int(lb_sent.get(key, 0)), floors)
		_save_meta()
		if state == LEADER:
			_lb_fetch()


func _lb_fetch() -> void:
	lb_rows = []
	if lb_url == "":
		lb_status = "notset"
		return
	lb_status = "loading"
	var key := _lb_key(lb_mode)
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(_lb_fetch_done.bind(req, key))
	if req.request(lb_url + "/lb/%s.json" % key) != OK:
		req.queue_free()
		lb_status = "error"


func _lb_fetch_done(result: int, code: int, _h: PackedStringArray, body: PackedByteArray, req: HTTPRequest, key: String) -> void:
	req.queue_free()
	if key != _lb_key(lb_mode):
		return
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		lb_status = "error"
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	var rows: Array = []
	if data is Dictionary:
		for uid in data:
			var e = data[uid]
			if e is Dictionary and e.has("n") and e.has("f"):
				rows.append({"uid": String(uid), "n": _lb_clean(String(e["n"])), "f": int(e["f"]), "c": String(e.get("c", "")), "t": int(e.get("t", 0))})
	rows.sort_custom(func(a, b): return a["f"] > b["f"] or (a["f"] == b["f"] and a["t"] < b["t"]))
	lb_rows = rows.slice(0, 12)
	lb_status = "ok"


func _lb_open() -> void:
	state = LEADER
	_lb_fetch()


func _lb_input(p: Vector2) -> void:
	if name_edit != null and name_edit.visible:
		if not name_edit.get_global_rect().has_point(p):
			_lb_name_done(name_edit.text)
		return
	if btn_lbback.has_point(p):
		state = MODE
		_sfx("ui")
		return
	for i in 2:
		if _tut_tabs(i).has_point(p):
			lb_mode = i
			_lb_fetch()
			_sfx("ui")
			return
	if btn_lbname.has_point(p):
		_sfx("ui")
		if not OS.has_feature("web"):
			_lb_name_edit_open()
		elif _lb_ask_name():
			_lb_resubmit()
			_lb_fetch()


func _draw_lb(acc: Color) -> void:
	_txt("LEADERBOARD", Vector2(0, 150), 52, acc)
	var names := ["PUZZLE", "ADVENTURE"]
	for i in 2:
		var tr := _tut_tabs(i)
		var tc := Color("ffd84f") if i == lb_mode else Color(1, 1, 1, 0.5)
		draw_rect(tr, Color(tc.r, tc.g, tc.b, 0.16 if i == lb_mode else 0.06))
		draw_rect(tr, tc, false, 2.0)
		_ctext(names[i], tr.get_center(), 24, tc)
	var mine := best if lb_mode == 0 else adv_best
	var nm := lb_name if lb_name != "" else "(no name yet)"
	_txt("You: %s    Best: %d floors" % [nm, mine], Vector2(0, 280), 24, Color(1, 1, 1, 0.8))
	if lb_status == "notset":
		_para("The online board is not switched on yet. Your best is saved on this device. Once the game owner connects the free online database, everyone's names and floors will appear here.", Vector2(60, 380), 26, Color(1, 1, 1, 0.8), 600.0)
	elif lb_status == "loading":
		_txt("Loading...", Vector2(0, 420), 30, Color(1, 1, 1, 0.6))
	elif lb_status == "error":
		_txt("Could not reach the leaderboard", Vector2(0, 420), 28, Color("ff8a8a"))
		_txt("Check your connection and reopen this screen", Vector2(0, 460), 22, Color(1, 1, 1, 0.6))
	elif lb_rows.is_empty():
		_txt("No scores yet. Be the first!", Vector2(0, 420), 30, Color(1, 1, 1, 0.7))
	else:
		for i in lb_rows.size():
			var row: Dictionary = lb_rows[i]
			var y := 336.0 + i * 58.0
			var me: bool = String(row["uid"]) == lb_uid
			var rc := Rect2(40, y - 34, 640, 50)
			if me:
				_obox(rc, Color(1, 0.85, 0.3, 0.16))
				draw_rect(rc, Color("ffd84f"), false, 2.0)
			var tc2 := Color("ffd84f") if me else Color.WHITE
			var medal := [Color("ffd84f"), Color("c9d3f0"), Color("d08a4a")]
			if i < 3:
				draw_circle(Vector2(72, y - 9), 16, medal[i])
				_ctext(str(i + 1), Vector2(72, y - 9), 20, Color("14141c"))
			else:
				_ctext(str(i + 1), Vector2(72, y - 9), 22, Color(1, 1, 1, 0.6))
			var cc := Color.WHITE
			for d in class_defs:
				if String(d["id"]) == String(row["c"]):
					cc = d["col"]
			draw_circle(Vector2(128, y - 9), 9, cc)
			_txt(String(row["n"]), Vector2(150, y), 28, tc2, 360.0, HORIZONTAL_ALIGNMENT_LEFT)
			_txt("%d floors" % int(row["f"]), Vector2(50, y), 28, tc2, 620.0, HORIZONTAL_ALIGNMENT_RIGHT)
	_button(btn_lbname, "CHANGE NAME", Color("ffd84f"), 22)
	_button(btn_lbback, "BACK", acc, 26)


# ---------- tutorial ----------

func _tut_need_page() -> Dictionary:
	return {"t": "SHOP AND SAVES", "ti": 0, "s": [["pcls:gambler", "Classes"], ["item:big", "Packs"], ["item:shield", "Head starts"]],
	"x": "Coins are banked when a run ends. Spend them in the SHOP to unlock classes, packs and head starts.\n\nYour run saves itself. Use CONTINUE SAVED RUN on the main menu to pick it up. SAVES copies your progress to another device."}


func _tut_pages(which: int) -> Array:
	if which == 0:
		return [
			{"t": "THE GOAL", "ti": 0, "s": [["player", "You"], ["icon:door_locked", "Gate (locked)"], ["icon:door_open", "Gate (open)"]],
			"x": "Walk to the gate to reach the next floor. It shows the level you need (Lv N).\n\nTap any tile and you walk there. You stop early if something new needs attention."},
			{"t": "MONSTERS AND LEVELS", "ti": 1, "s": [["mon:1:2:none:g", "Easy"], ["mon:1:5:none:r", "Deadly"], ["mon:1:4:none:r", "Equal = lose"]],
			"x": "Walk into a monster to fight it. Your level HIGHER means you win and level up. Equal or higher means you die.\n\nGreen badge: win. Red: die. Amber: only your shield saves you."},
			{"t": "THE DARK", "ti": 1, "s": [["dark", "Dark tile"], ["player", "You"], ["icon:spikes", "Spikes"]],
			"x": "The dark eats the board from the outside in. The meter at the top right counts steps until it advances. Standing in the dark kills you.\n\nEvery step counts, and spikes cost extra steps."},
			{"t": "ITEMS", "ti": 1, "s": [["item:pot", "Potion +1"], ["item:shield", "Shield"], ["item:lamp", "Lantern"], ["item:coin", "Coin"]], "s2": [["icon:key", "Key"], ["icon:vault", "Vault"], ["portal", "Portal"]],
			"x": "Potions raise your level. A shield saves you from one losing fight. A lantern holds the dark back. A key opens a vault. Portals teleport you to their twin."},
			{"t": "TOOLS AND DOORS", "ti": 0, "s": [["use:bomb", "Bomb"], ["use:blink", "Blink"], ["use:crystal", "Crystal"], ["door:standard", "Doors"]],
			"x": "Tools sit in the bar under the board: tap one to use it. They are used up, but your class power recharges.\n\nBetween floors pick a door: Steady is normal, Perilous is harder, Quiet is easier, Vault holds a key, Merchant sells tools. A boss guards every 5th gate."},
			_tut_need_page(),
		]
	return [
		{"t": "THE GOAL", "ti": 0, "s": [["player", "You"], ["icon:door_locked", "Exit (sealed)"], ["icon:door_open", "Exit (open)"]],
		"x": "Collect POINTS from kills, coins and items until the bar is full, then walk to the exit.\n\nTap a tile to walk there, or swipe to step. You stop when something new appears."},
		{"t": "CONTROLS", "ti": 0, "s": [["use:blink", "Tool"], ["pcls:scout", "Power"], ["icon:crate_weapon", "Weapon"]],
		"x": "Tools: tap one to select it, tap again to use it. The CANCEL bar backs out.\n\nThe coloured button is your class power. It recharges as you walk.\n\nThe round button swaps melee and ranged. With a ranged weapon, tap a monster in a clear line to shoot it."},
		{"t": "FIGHTING", "ti": 1, "s": [["player", "You"], ["mon:1:3:none:g", "Easy"], ["mon:1:5:none:a", "Costly"], ["mon:1:8:none:r", "Deadly"]],
		"x": "Walk into a monster to trade blows. Tap again to keep fighting, or retreat.\n\nThe badge shows the cost: green is easy, amber hurts, red will probably kill you.\n\nHunters (!) chase you, thieves ($) steal coins, turrets shoot down a lane."},
		{"t": "AIR AND HEALTH", "ti": 0, "s": [["icon:pod", "Air pod"], ["icon:station", "O2 station"], ["item:hp", "Medkit"], ["icon:medstation", "Medical"]],
		"x": "Every step costs 1 air. At 0 air you die. O2 stations refill you fully: use them as bases and explore outward.\n\nAt 0 health you die too. Medkits and medical stations heal you. Armour cuts every hit, and a shield soaks damage first."},
		{"t": "LEVELS AND GEAR", "ti": 1, "s": [["item:pot", "XP"], ["skn:0", "Skills"], ["icon:crate_weapon", "Gear"], ["icon:merchant", "Outfitter"]],
		"x": "Kills give XP and levels. Every 3rd level gives a skill point: tap SKILLS to spend it.\n\nTap BAG to equip gear from crates, and to read your tools and relics. Outfitter stalls sell gear for coins.\n\nAfter each floor you pick a relic that lasts the run."},
		{"t": "WATCH OUT", "ti": 2, "s": [["haz:arc", "Hazards"], ["aff:plated", "Tagged"], ["boss:2", "Boss"]],
		"x": "Hazards are drawn on the tile and differ by world. Bombs clear them.\n\nMonsters with a name tag (Plated, Regen, Leech...) are tougher but give better loot.\n\nBosses guard some exits. Beat them for gear and coins."},
		_tut_need_page(),
	]


func _tut_tabs(i: int) -> Rect2:
	return Rect2(40 + i * 220, 186, 200, 56)


func _tut_icon(spec: String, ctr: Vector2, s: float, ti: int) -> void:
	var p := spec.split(":")
	var k := p[0]
	var rr := Rect2(ctr - Vector2(s, s) * 0.5, Vector2(s, s))
	draw_texture_rect(_floor_tex(ti, int(ctr.x / 100.0) % 2, int(ctr.x * 0.37 + ctr.y * 0.11) % 16), rr, false)
	draw_rect(rr, Color(0, 0, 0, 0.18))
	draw_rect(rr, Color(1, 1, 1, 0.25), false, 2.0)
	var th: Dictionary = themes[ti]
	if k == "player":
		_spr(_player_tex(0, 0, false), ctr, s * 0.8)
	elif k == "pcls":
		var col := Color.WHITE
		for d in class_defs:
			if String(d["id"]) == String(p[1]):
				col = d["col"]
		_spr(spr_gen.player(col, String(p[1]), 0), ctr, s * 0.85)
	elif k == "mon" or k == "boss":
		var boss := k == "boss"
		var lv := 9 if boss else int(p[2])
		var tt := int(p[1])
		_spr(_monster_tex(tt, lv, boss), ctr + Vector2(0, -2), s * (0.98 if boss else 0.82))
		if not boss:
			var mk := String(p[3])
			var bc := Color("49d17a") if String(p[4]) == "g" else (Color("ffb02e") if String(p[4]) == "a" else Color("ef4b55"))
			var bp := rr.position + Vector2(s - 16, 16)
			draw_circle(bp, 15, Color("0a0c14"))
			draw_circle(bp, 12.5, bc)
			_ctext(str(lv), bp, 17, Color.WHITE)
			var mp := rr.position + Vector2(18, s - 18)
			if mk == "elite":
				_star(rr.position + Vector2(18, 18), 13, Color("ffd84f"))
			elif mk == "sleeper":
				_ctext("zZ", mp, 20, Color("9ec0ff"))
			elif mk == "feeder":
				draw_circle(mp, 12, Color("5a1f8a"))
				_ctext("+", mp, 20, Color("e6b3ff"))
			elif mk == "thief":
				draw_circle(mp, 12, Color("5a4500"))
				_ctext("$", mp, 20, Color("ffd84f"))
			elif mk == "hunter":
				draw_circle(mp, 12, Color("6a1218"))
				_ctext("!", mp, 20, Color("ff7a7a"))
		else:
			bpos_badge(rr.position + Vector2(s - 16, 16), "12")
	elif k == "tur":
		_spr(spr_gen.turret(int(p[1]), int(p[2]), int(p[3])), ctr, s * 0.9)
	elif k == "haz":
		_spr(spr_gen.icon("haz_" + String(p[1])), ctr, s * 0.85)
	elif k == "item":
		_spr(_item_tex(String(p[1])), ctr, s * 0.7)
	elif k == "icon":
		_spr(spr_gen.icon(String(p[1])), ctr, s * 0.85)
	elif k == "use":
		_use_icon(String(p[1]), ctr, s * 0.72)
	elif k == "dark":
		draw_rect(rr.grow(-2), th["dark"])
		_ctext("DARK", ctr, 22, Color(1, 1, 1, 0.5))
	elif k == "badge":
		var bc2 := Color("49d17a") if String(p[1]) == "g" else Color("ef4b55")
		draw_circle(ctr, 30, Color("0a0c14"))
		draw_circle(ctr, 25, bc2)
		_ctext(String(p[2]), ctr, 30, Color.WHITE)
	elif k == "door":
		var dcol: Color = door_defs[String(p[1])]["col"]
		_spr(spr_gen.icon("door_open"), ctr, s * 0.85)
		draw_rect(rr, Color(dcol.r, dcol.g, dcol.b, 0.22))
		draw_rect(rr, dcol, false, 4.0)
	elif k == "aff":
		_spr(_monster_tex(ti, 6, false), ctr + Vector2(0, -2), s * 0.82)
		_aff_pill(rr.position + Vector2(s - 4, s - 16), String(p[1]), 15, true)
	elif k == "skn":
		var sb := int(p[1])
		var scl: Color = SK_BR[sb][1]
		draw_circle(ctr, s * 0.4, Color(0.07, 0.08, 0.13))
		draw_arc(ctr, s * 0.4, 0, TAU, 28, scl, 4.0)
		draw_circle(ctr, s * 0.22, Color(scl.r, scl.g, scl.b, 0.55))
		_ctext(String(SK_BR[sb][0]).substr(0, 3), ctr, 20, Color.WHITE)
	elif k == "portal":
		var pc := Color("c07cff")
		draw_circle(ctr, s * 0.34, Color(pc.r, pc.g, pc.b, 0.18))
		draw_arc(ctr, s * 0.32, t * 3.0, t * 3.0 + PI * 1.3, 18, pc, 4.0)
		draw_arc(ctr, s * 0.2, -t * 4.0, -t * 4.0 + PI * 1.3, 14, Color("e6c8ff"), 3.0)
		draw_circle(ctr, s * 0.07, pc)


func bpos_badge(c: Vector2, txt: String) -> void:
	draw_circle(c, 15, Color("0a0c14"))
	draw_circle(c, 12.5, Color("ef4b55"))
	_ctext(txt, c, 17, Color.WHITE)


func _tut_rows(pg: Dictionary) -> Array:
	var rows: Array = []
	if not (pg["s"] as Array).is_empty():
		rows.append(pg["s"])
	if pg.has("s2"):
		rows.append(pg["s2"])
	return rows


func _tut_layout(pg: Dictionary) -> Dictionary:
	var rows := _tut_rows(pg)
	var ty := 340.0 if rows.is_empty() else 395.0 + rows.size() * 132.0 - 40.0
	var body := String(pg["x"]).replace("\\n", "\n")
	var fs := 24 if rows.size() <= 1 else 22
	while fs > 14 and font.get_multiline_string_size(body, HORIZONTAL_ALIGNMENT_LEFT, 620.0, fs).y + ty > 1130.0:
		fs -= 1
	return {"ty": ty, "fs": fs, "body": body, "rows": rows}


func _draw_tut(acc: Color) -> void:
	_txt("NEED TO KNOW", Vector2(0, 150), 52, acc)
	var names := ["PUZZLE", "ADVENTURE", "PRACTICE"]
	for i in (3 if tut_back == MODE else 2):
		var tr := _tut_tabs(i)
		var tc := Color("ffd84f") if i == tut_mode else Color(1, 1, 1, 0.5)
		if i == 2:
			tc = Color("6dff9a")
		draw_rect(tr, Color(tc.r, tc.g, tc.b, 0.16 if i == tut_mode else 0.06))
		draw_rect(tr, tc, false, 2.0)
		_ctext(names[i], tr.get_center(), 24, tc)
	var pages := _tut_pages(tut_mode)
	tut_page = clampi(tut_page, 0, pages.size() - 1)
	var pg: Dictionary = pages[tut_page]
	_txt(String(pg["t"]), Vector2(0, 300), 40, acc)
	var lay := _tut_layout(pg)
	var rows: Array = lay["rows"]
	var ti: int = pg["ti"]
	for r in rows.size():
		var row: Array = rows[r]
		var cy := 395.0 + r * 132.0
		var n := row.size()
		var sz := 88.0 if n <= 4 else 80.0
		for i in n:
			var cx := 40.0 + (i + 0.5) * 640.0 / n
			_tut_icon(String(row[i][0]), Vector2(cx, cy), sz, ti)
			_ctext(String(row[i][1]), Vector2(cx, cy + sz * 0.5 + 18), 19 if n <= 4 else 16, Color(1, 1, 1, 0.85))
	_para(String(lay["body"]), Vector2(50, float(lay["ty"])), int(lay["fs"]), Color(1, 1, 1, 0.9), 620.0)
	_button(btn_tpv, "PREV", acc, 24)
	_button(btn_tnx, "NEXT", acc, 24)
	_ctext("%d / %d" % [tut_page + 1, pages.size()], Vector2(360, 1244), 24, Color(1, 1, 1, 0.7))
	_button(btn_icl, "BACK", acc, 28)


func _first_tut() -> void:
	var k := "adv" if mode == "adv" else "puzzle"
	if bool(tut_seen.get(k, false)):
		return
	tut_seen[k] = true
	_save_meta()
	tut_back = state
	tut_mode = 1 if mode == "adv" else 0
	tut_page = 0
	state = TUTORIAL


func _tut_input(p: Vector2) -> void:
	if btn_icl.has_point(p):
		state = tut_back
		tut_back = MODE
		_sfx("ui")
		return
	for i in 3:
		if _tut_tabs(i).has_point(p):
			if i == 2:
				if tut_back == MODE:
					_tut_map_start()
				return
			tut_mode = i
			tut_page = 0
			_sfx("ui")
			return
	var n := _tut_pages(tut_mode).size()
	if btn_tpv.has_point(p):
		tut_page = (tut_page + n - 1) % n
		_sfx("ui")
	elif btn_tnx.has_point(p):
		tut_page = (tut_page + 1) % n
		_sfx("ui")


# ---------- drawing ----------

func _apply_font() -> void:
	font = font_clear
	font_title = font_pix if font_pix != null else font_clear


func _fit(s: String, size: int, w: float, f: Font = null) -> int:
	var ft: Font = f if f != null else font
	var fs := size
	while fs > 10 and ft.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w - 6.0:
		fs -= 1
	return fs


func _txt(s: String, p: Vector2, size: int, col: Color, w := 720.0, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var ft: Font = font_title if size >= 26 else font
	var fs := _fit(s, size, w, ft)
	if fs >= 22 and col.a > 0.5:
		var so := 4.0 if fs >= 48 else 2.0
		draw_string(ft, p + Vector2(0, so), s, align, w, fs, Color(0, 0, 0, 0.55) if fs < 48 else Color(col.r * 0.3, col.g * 0.3, col.b * 0.3, 0.9))
	draw_string(ft, p, s, align, w, fs, col)


func _ctext(s: String, c: Vector2, size: int, col: Color) -> void:
	var fs := _fit(s, size, 200.0, font_title)
	draw_string(font_title, Vector2(c.x - 100.0, c.y + fs * 0.35), s, HORIZONTAL_ALIGNMENT_CENTER, 200.0, fs, col)


func _panel(r: Rect2, col: Color, fill := 0.14, press := true) -> Rect2:
	var d := 0.0
	if press and t - press_t < 0.14 and r.has_point(press_p):
		d = 3.0
	var x := r.position.x
	var y := r.position.y + d
	var w := r.size.x
	var h := r.size.y
	var c := minf(8.0, h * 0.25)
	var pts := PackedVector2Array([Vector2(x + c, y), Vector2(x + w - c, y), Vector2(x + w, y + c), Vector2(x + w, y + h - c), Vector2(x + w - c, y + h), Vector2(x + c, y + h), Vector2(x, y + h - c), Vector2(x, y + c)])
	if d == 0.0:
		var sh := PackedVector2Array()
		for q in pts:
			sh.append(q + Vector2(0, 4))
		draw_colored_polygon(sh, Color(0, 0, 0, 0.5))
	draw_colored_polygon(pts, Color(0.03, 0.04, 0.08, 0.94))
	draw_colored_polygon(pts, Color(col.r, col.g, col.b, fill * 0.6))
	if h > 30.0:
		draw_rect(Rect2(x + c, y + 3, w - 2.0 * c, h * 0.42), Color(col.r, col.g, col.b, fill * 0.7))
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, Color(col.r, col.g, col.b, 0.14), 7.0)
	draw_polyline(loop, col, 2.0)
	draw_line(Vector2(x + c + 2, y + 4), Vector2(x + w - c - 2, y + 4), Color(1, 1, 1, 0.28), 2.0)
	draw_line(Vector2(x + c + 2, y + h - 4), Vector2(x + w - c - 2, y + h - 4), Color(0, 0, 0, 0.4), 2.0)
	return Rect2(x, y, w, h)


const ICONS := {
	"save": ["#######", "#.###.#", "#.###.#", "#.....#", "#.###.#", "#.###.#", "#######"],
	"trophy": ["#######", "#.###.#", "#.###.#", ".#####.", "..###..", "...#...", "..###.."],
	"help": [".#####.", "##...##", ".....##", "...###.", "...#...", ".......", "...#..."],
	"copy": ["#####..", "#...#..", "#.#####", "#.#...#", "###...#", "..#...#", "..#####"],
	"paste": ["..###..", "#######", "#.....#", "#.###.#", "#.....#", "#.###.#", "#######"],
	"back": ["..#....", ".##....", "#######", ".##....", "..#....", ".......", "......."],
	"file": ["#####..", "#...##.", "#...#.#", "#...###", "#.....#", "#.....#", "#######"],
}


func _icon(kind: String, c: Vector2, col: Color) -> void:
	if not ICONS.has(kind):
		return
	var rows: Array = ICONS[kind]
	for ry in rows.size():
		var row: String = rows[ry]
		for rx in row.length():
			if row[rx] == "#":
				draw_rect(Rect2(c.x - 10.5 + rx * 3.0, c.y - 10.5 + ry * 3.0, 3.0, 3.0), col)


func _cell_rect(c: Vector2i) -> Rect2:
	return Rect2(GX + c.x * cell, GY + c.y * cell, cell, cell)


func _spr(tex: Texture2D, ctr: Vector2, size: float, mod := Color.WHITE) -> void:
	if tex.has_meta("scl"):
		size *= float(tex.get_meta("scl"))
	draw_texture_rect(tex, Rect2(ctr.x - size * 0.5, ctr.y - size * 0.5, size, size), false, mod)


func _button(r: Rect2, label: String, col: Color, size := 20, icon := "") -> void:
	var rr := _panel(r, col)
	var tx := rr.position.x
	var tw := rr.size.x
	if icon != "":
		_icon(icon, Vector2(rr.position.x + 34, rr.get_center().y), col)
		tx += 30.0
		tw -= 30.0
	var fs := _fit(label, size, tw, font_title)
	draw_string(font_title, Vector2(tx, rr.get_center().y + fs * 0.33 + 2.0), label, HORIZONTAL_ALIGNMENT_CENTER, tw, fs, Color(0, 0, 0, 0.5))
	draw_string(font_title, Vector2(tx, rr.get_center().y + fs * 0.33), label, HORIZONTAL_ALIGNMENT_CENTER, tw, fs, col)


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
	_spr(spr_gen.icon("spikes"), ctr, cell * 0.8)


func _draw_vault(ctr: Vector2) -> void:
	_spr(spr_gen.icon("vault"), ctr, cell * 0.8)


func _draw_key(ctr: Vector2, s: float) -> void:
	_spr(spr_gen.icon("key"), ctr, s)


func _use_icon(id: String, c: Vector2, s: float) -> void:
	var col: Color = use_defs[id]["col"]
	var r := s * 0.5
	draw_circle(c, r, Color(0.07, 0.08, 0.13))
	draw_arc(c, r, 0, TAU, 20, col, 2.0)
	_spr(spr_gen.icon("use_" + id), c, s * 0.86)


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


var draw_count := 0


const INTRO_LEN := 4.6


func _draw_intro() -> void:
	var u := t - state_t
	var W := size.x
	var H := size.y
	draw_rect(Rect2(0, 0, W, H), Color(0.03, 0.04, 0.09))
	var fade_in := clampf(u / 0.8, 0.0, 1.0)
	for i in 70:
		var sx := fmod(float(i) * 97.3 + 31.0, W)
		var sy := fmod(float(i) * 211.7 + u * (6.0 + float(i % 5) * 3.0), H)
		var tw := 0.25 + 0.55 * (0.5 + 0.5 * sin(u * 2.0 + float(i)))
		draw_rect(Rect2(sx, sy, 2.0 + float(i % 3), 2.0 + float(i % 3)), Color(0.7, 0.85, 1.0, tw * fade_in))
	var cx := W * 0.5
	var cy := H * 0.36
	var gr := clampf(u / 1.4, 0.0, 1.0)
	gr = 1.0 - (1.0 - gr) * (1.0 - gr)
	var R := 150.0 * gr
	var pulse := 0.5 + 0.5 * sin(u * 3.0)
	draw_circle(Vector2(cx, cy), R * 1.25, Color(0.2, 0.5, 0.8, 0.10 + 0.05 * pulse))
	draw_circle(Vector2(cx, cy), R, Color(0.05, 0.09, 0.16))
	draw_arc(Vector2(cx, cy), R, 0.0, TAU, 64, Color("7fd8ff"), 6.0)
	draw_arc(Vector2(cx, cy), R * 0.82, u * 0.8, u * 0.8 + TAU * 0.7, 48, Color(0.5, 0.85, 1.0, 0.7), 4.0)
	draw_arc(Vector2(cx, cy), R * 0.64, -u * 1.2, -u * 1.2 + TAU * 0.5, 40, Color("ffd84f"), 4.0)
	for k in 8:
		var a := float(k) * TAU / 8.0 + u * 0.3
		draw_line(Vector2(cx, cy) + Vector2.from_angle(a) * R * 0.95, Vector2(cx, cy) + Vector2.from_angle(a) * R * 1.12, Color("7fd8ff"), 5.0)
	var tu := clampf((u - 1.2) / 0.9, 0.0, 1.0)
	var te := 1.0 - (1.0 - tu) * (1.0 - tu)
	var ty := H * 0.62
	_txt("POCKET", Vector2(-(1.0 - te) * 80.0, ty), 104, Color(1, 1, 1, te))
	_txt("STATION", Vector2((1.0 - te) * 80.0, ty + 100.0), 104, Color(1.0, 0.85, 0.31, te))
	var su := clampf((u - 2.4) / 0.8, 0.0, 1.0)
	_txt("tap to skip", Vector2(0, H - 70.0), 22, Color(1, 1, 1, 0.45 * su))
	var fo := clampf((u - (INTRO_LEN - 0.5)) / 0.5, 0.0, 1.0)
	if fo > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, fo))

func _draw() -> void:
	draw_count += 1
	if themes.is_empty():
		return
	if state == INTRO:
		_draw_intro()
		return
	var ti := tidx()
	var th := cur_theme()
	var acc: Color = th["accent"]
	if mode == "adv" and state != MODE and state != CLASS and state != SHOP and state != TUTORIAL and state != LEADER and state != SAVES and state != SETTINGS:
		_adv_draw()
		_fx_draw_top()
		if state != PLAY:
			_draw_overlay(acc)
		return
	draw_rect(Rect2(0, 0, 720, 1280), th["bg"])
	var grid_r := Rect2(GX - 4, GY - 4, N * cell + 8, N * cell + 8)
	for s in stars:
		var a := 0.12 + 0.28 * (0.5 + 0.5 * sin(t * 1.5 + float(s[2])))
		var sz: float = s[3]
		var drift := 0.0
		if ti == 1:
			drift = sin(t * 0.7 + float(s[2])) * 6.0
		if grid_r.has_point(Vector2(float(s[0]) + drift, float(s[1]))):
			continue
		draw_rect(Rect2(float(s[0]) + drift, float(s[1]), sz, sz), Color(acc.r, acc.g, acc.b, a))
	if state == MODE or state == TUTORIAL or state == LEADER or state == SAVES or state == SETTINGS:
		_draw_overlay(acc)
		return
	# HUD
	if state == PLAY:
		var marm := t - menu_armed < 3.0
		_button(btn_menu, "SURE?" if marm else "MENU", Color("ff8a8a") if marm else acc)
	_hud_panels(acc, 84.0)
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
	_map_begin()
	var names: Array = th["mons"]
	var wall_set: Array = _wall_set(ti)
	for x in N:
		for y in N:
			var c := Vector2i(x, y)
			var r := _cell_rect(c)
			if is_dark(c):
				draw_rect(r, th["dark"])
				continue
			draw_texture_rect(_floor_tex(ti, (x + y) % 2, _tile_var(x, y)), r.grow(-1.0), false)
			if ring(c) == depth:
				draw_rect(r.grow(-1.0), Color(0, 0, 0, 0.28))
				if warn:
					draw_rect(r.grow(-1.0), Color(1, 0.2, 0.2, 0.12 + 0.12 * sin(t * 8.0)))
			var ctr := r.get_center()
			var bob := sin(t * 3.0 + x * 1.7 + y) * 2.0
			if walls.has(c):
				draw_texture_rect(wall_set[_wall_var(x, y)], r.grow(-1.0), false)
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
				_draw_mon_sprite(c, ctr + _mon_off(c), ti, base_lv, is_boss, sz, mmod, asleep, 0.0 if asleep else bob)
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
				_draw_coin(ctr, bob, cell * 0.42, float(x * 5 + y * 3))
			elif portals.has(c):
				var pc := Color("c07cff")
				draw_circle(ctr, cell * 0.34, Color(pc.r, pc.g, pc.b, 0.18))
				draw_arc(ctr, cell * 0.32, t * 3.0, t * 3.0 + PI * 1.3, 18, pc, 4.0)
				draw_arc(ctr, cell * 0.2, -t * 4.0, -t * 4.0 + PI * 1.3, 14, Color("e6c8ff"), 3.0)
				draw_circle(ctr, cell * 0.07, pc)
	_amb_draw(_fx_band(), ti)
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
	var prc := _wp(vis_pos) + _p_off()
	draw_circle(prc + Vector2(0, cell * 0.3), cell * 0.25, Color(0, 0, 0, 0.35))
	if shield:
		draw_arc(prc, cell * 0.46, 0, TAU, 28, Color(0.5, 0.7, 1.0, 0.5 + 0.2 * sin(t * 5.0)), 3.0)
	if boost > 0:
		draw_arc(prc, cell * 0.52, 0, TAU, 28, Color(0.7, 0.72, 0.9, 0.5), 2.0)
	_draw_player(prc, cell * 0.78)
	_fx_draw()
	# floating pops
	for pp in pops:
		var age: float = t - float(pp["t"])
		if age < 0.0:
			continue
		var pcol: Color = pp["c"]
		pcol.a = clampf((POP_LIFE - age) / 0.5, 0.0, 1.0)
		var pp_pos: Vector2 = pp["p"]
		_ctext(pp["s"], pp_pos + Vector2(0, -cell * 0.3 - age * 40.0), 26, pcol)
	_map_end()
	# tool slots
	for i in slots_n():
		var sr := _slot_rect(i)
		var has := i < inv.size()
		var scol := Color(1, 1, 1, 0.25)
		if has:
			scol = use_defs[inv[i]]["col"]
		if aim == i:
			scol = Color("ffe14f")
		_panel(sr, scol, 0.16, false)
		if has:
			_use_icon(inv[i], Vector2(sr.position.x + 25, sr.position.y + 31), 38)
			draw_multiline_string(font, Vector2(sr.position.x + 50, sr.position.y + 26), _use_name(inv[i]), HORIZONTAL_ALIGNMENT_LEFT, 56, 13, 3, Color.WHITE)
		else:
			_ctext("empty", sr.get_center(), 14, Color(1, 1, 1, 0.3))
	_act_draw()
	# footer
	_txt(msg, Vector2(0, 1084), 26, Color.WHITE, 720.0)
	_txt("Green badge = you win the fight. Red = you die. Equal loses!", Vector2(0, 1122), 22, Color(1, 1, 1, 0.55))
	_txt("Gold star = +2 levels. Shield saves you once. Spikes cost steps.", Vector2(0, 1150), 22, Color(1, 1, 1, 0.55))
	_txt("Tap a tile to walk there. The dark eats the outer ring.", Vector2(0, 1208), 22, Color(1, 1, 1, 0.55))
	if relics.size() > 0:
		var parts: Array[String] = []
		for d in relic_defs:
			var n := relic_n(String(d["id"]))
			if n > 0:
				parts.append(_aname(String(d["id"]), String(d["name"])) + (" x%d" % n if n > 1 else ""))
		_para("RELICS: " + ", ".join(parts), Vector2(20, 1240), 15, Color(1, 1, 1, 0.6), 680.0)
	_fx_draw_top()
	if state != PLAY:
		_draw_overlay(acc)


func _menu_tint(acc: Color) -> Color:
	match state:
		SHOP:
			return Color("ffc93c")
		MARKET:
			return Color("7dffb0")
		TRADE:
			return Color("ff9d6b")
		INV:
			return Color("7fd8ff")
		SKILLS:
			return Color("c79bff")
		CLASS, TUTORIAL:
			return Color("ffd84f")
		RELIC:
			return Color("ff8ad8")
		LEADER:
			return Color("7fd8ff")
		SAVES:
			return Color("c9d3f0")
		SETTINGS:
			return Color("c9d3f0")
	return acc


const MENU_PLANETS := [
	# [file, size px, start x, start y, drift x px/s, drift y px/s, spin rad/s]
	["planet_ringed", 300.0, 560.0, 250.0, -4.0, 2.5, 0.0],
	["planet_blue", 170.0, 120.0, 900.0, 5.0, -3.0, 0.02],
	["planet_purple", 120.0, 610.0, 1090.0, -6.0, -2.0, -0.03],
	["moon_grey", 64.0, 230.0, 160.0, 9.0, 4.0, 0.1],
	["moon_ice", 52.0, 470.0, 700.0, -10.0, 6.0, -0.12],
]
var menu_tex := {}


func _menu_tex(n: String) -> Texture2D:
	if not menu_tex.has(n):
		var pth := "res://art/menu/%s.png" % n
		menu_tex[n] = load(pth) if ResourceLoader.exists(pth) else null
	return menu_tex[n]


func _draw_menu_space() -> bool:
	var bg := _menu_tex("space_bg")
	if bg == null:
		return false
	# backdrop slowly breathes so the nebula feels alive
	var z := 1.06 + 0.02 * sin(t * 0.12)
	var bw := 720.0 * z
	var bh := 1280.0 * z
	draw_texture_rect(bg, Rect2(360.0 - bw / 2 + sin(t * 0.07) * 12.0, 640.0 - bh / 2 + cos(t * 0.05) * 14.0, bw, bh), false)
	# three star layers moving at different speeds (parallax)
	for s in amb:
		var layer := int(s[4] * 3.0) % 3
		var sp: float = [8.0, 18.0, 36.0][layer]
		var sx := fposmod(float(s[0]) - t * sp * 0.35, 720.0)
		var sy := fposmod(float(s[1]) + t * sp, 1280.0)
		var tw := 0.45 + 0.55 * absf(sin(t * (1.2 + layer) + float(s[3])))
		var r: float = [1.2, 1.8, 2.6][layer]
		draw_circle(Vector2(sx, sy), r * 2.2, Color(0.6, 0.8, 1.0, 0.12 * tw))
		draw_circle(Vector2(sx, sy), r, Color(1, 1, 1, tw))
	# a shooting star now and then
	var ph := fposmod(t, 7.0)
	if ph < 0.9:
		var k := ph / 0.9
		var sd := int(t / 7.0)
		var st := Vector2(120.0 + float(sd * 173 % 480), 80.0 + float(sd * 97 % 400))
		var hd := st + Vector2(260, 160) * k
		draw_line(hd - Vector2(70, 43) * (1.0 - k * 0.5), hd, Color(1, 1, 1, 0.8 * (1.0 - k)), 3.0)
		draw_circle(hd, 3.0, Color(1, 1, 0.9, 1.0 - k))
	# planets and moons drift and wrap around the screen
	for pl in MENU_PLANETS:
		var tx := _menu_tex(pl[0])
		if tx == null:
			continue
		var sz: float = pl[1]
		var px := fposmod(float(pl[2]) + t * float(pl[4]) + sz, 720.0 + sz * 2.0) - sz
		var py := fposmod(float(pl[3]) + t * float(pl[5]) + sz, 1280.0 + sz * 2.0) - sz
		var ts := tx.get_size()
		var sc := sz / maxf(ts.x, ts.y)
		draw_set_transform(Vector2(px, py), t * float(pl[6]), Vector2(sc, sc))
		draw_texture(tx, -ts / 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


func _obox(r: Rect2, c: Color) -> void:
	draw_rect(r, Color(0.03, 0.04, 0.08, 0.93))
	draw_rect(r, c)


func _draw_menu_bg(tint: Color) -> void:
	if _draw_menu_space():
		return
	for i in 20:
		var f := i / 19.0
		var c := Color(0.02, 0.025, 0.06).lerp(Color(0.05, 0.07, 0.14), f).lerp(tint, 0.05 + 0.05 * f)
		draw_rect(Rect2(0, i * 64, 720, 65), c)
	var gc := Color(tint.r, tint.g, tint.b, 0.045)
	for gx in range(0, 721, 48):
		draw_line(Vector2(gx, 0), Vector2(gx, 1280), gc, 1.0)
	for gy in range(0, 1281, 48):
		draw_line(Vector2(0, gy), Vector2(720, gy), gc, 1.0)
	for s in amb:
		var my := fposmod(float(s[1]) - t * (6.0 + float(s[4]) * 5.0), 1280.0)
		var ma := 0.15 + 0.25 * absf(sin(t * 0.8 + float(s[3])))
		draw_rect(Rect2(float(s[0]), my, 3, 3), Color(tint.r, tint.g, tint.b, ma))
	var sy := fposmod(t * 70.0, 1700.0) - 200.0
	draw_rect(Rect2(0, sy, 720, 3), Color(tint.r, tint.g, tint.b, 0.07))
	for i in 8:
		var a := 0.3 * (1.0 - i / 8.0)
		draw_rect(Rect2(0, i * 10, 720, 10), Color(0, 0, 0, a))
		draw_rect(Rect2(0, 1280 - (i + 1) * 10, 720, 10), Color(0, 0, 0, a))
		draw_rect(Rect2(i * 10, 0, 10, 1280), Color(0, 0, 0, a))
		draw_rect(Rect2(720 - (i + 1) * 10, 0, 10, 1280), Color(0, 0, 0, a))
	draw_rect(Rect2(14, 14, 692, 1252), Color(tint.r, tint.g, tint.b, 0.35), false, 2.0)
	draw_rect(Rect2(22, 22, 676, 1236), Color(tint.r, tint.g, tint.b, 0.14), false, 1.0)
	var bc := Color(tint.r, tint.g, tint.b, 0.9)
	for cx in [14.0, 706.0]:
		for cy in [14.0, 1266.0]:
			var dx := 36.0 if cx < 360.0 else -36.0
			var dy := 36.0 if cy < 640.0 else -36.0
			draw_line(Vector2(cx, cy), Vector2(cx + dx, cy), bc, 4.0)
			draw_line(Vector2(cx, cy), Vector2(cx, cy + dy), bc, 4.0)


func _draw_menu_hero(acc: Color) -> void:
	for i in 32:
		var f := i / 31.0
		var c := Color(0.02, 0.02, 0.07).lerp(Color(0.07, 0.10, 0.22), f).lerp(acc, 0.05)
		draw_rect(Rect2(0, i * 40, 720, 41), c)
	for s in amb:
		var tw := 0.35 + 0.65 * absf(sin(t * float(s[4]) * 0.6 + float(s[3])))
		var sz := 4.0 if float(s[2]) > 0.8 else 2.0
		draw_rect(Rect2(float(s[0]), float(s[1]) * 0.55, sz, sz), Color(1, 1, 1, tw * 0.85))
	var pc := Vector2(570.0, 175.0)
	var base := Color(0.22, 0.27, 0.5).lerp(acc, 0.3)
	for dy in range(-84, 84, 6):
		var half := sqrt(maxf(0.0, 84.0 * 84.0 - float(dy * dy)))
		var sh := base.lerp(Color.WHITE, 0.22 if dy < -30 else 0.0).lerp(Color.BLACK, 0.35 if dy > 30 else 0.0)
		draw_rect(Rect2(pc.x - half, pc.y + dy, half * 2.0, 6), sh)
	for cr in [Vector2(-30, -20), Vector2(20, 10), Vector2(-10, 40), Vector2(40, -40)]:
		draw_rect(Rect2(pc.x + cr.x, pc.y + cr.y, 14, 8), Color(0, 0, 0, 0.22))
	draw_arc(pc, 108.0, 3.4, 6.0, 40, Color(acc.r, acc.g, acc.b, 0.4), 4.0)
	var mods := [[312, 700, 96, 580], [232, 820, 80, 460], [408, 780, 88, 500], [160, 960, 72, 320], [496, 900, 80, 380], [88, 1060, 72, 220], [576, 1020, 64, 260], [0, 1140, 88, 140], [640, 1100, 80, 180]]
	for m in mods:
		var mx: int = m[0]
		var my: int = m[1]
		var mw: int = m[2]
		var mh: int = m[3]
		draw_rect(Rect2(mx, my, mw, mh), Color(0.05, 0.07, 0.14, 0.95))
		draw_rect(Rect2(mx, my, mw, 4), Color(acc.r, acc.g, acc.b, 0.55))
		draw_rect(Rect2(mx + mw - 4, my, 4, mh), Color(0, 0, 0, 0.35))
		for wy in range(my + 18, my + mh - 10, 26):
			for wx in range(mx + 12, mx + mw - 14, 20):
				var k := (int(wx / 20) * 7 + int(wy / 26) * 13) % 5
				if k < 2:
					var fl := fmod(t * 0.6 + float(wx) * 0.013 + float(wy) * 0.007, 4.0) < 0.12
					if not fl:
						draw_rect(Rect2(wx, wy, 9, 12), Color(1.0, 0.85, 0.45, 0.55) if k == 0 else Color(acc.r, acc.g, acc.b, 0.5))
	draw_rect(Rect2(358, 620, 4, 80), Color(0.1, 0.12, 0.22))
	if fmod(t, 1.4) < 0.6:
		draw_rect(Rect2(352, 608, 16, 16), Color(1, 0.2, 0.2, 0.25))
		draw_rect(Rect2(356, 612, 8, 8), Color(1, 0.3, 0.3, 0.95))
	for i in 10:
		draw_rect(Rect2(0, 960 + i * 32, 720, 33), Color(0.01, 0.02, 0.05, 0.05 + 0.06 * i))


func _draw_overlay(acc: Color) -> void:
	if state == MODE:
		_draw_menu_bg(_menu_tint(acc))
	elif state in [INV, SKILLS, TRADE, TUTORIAL, LEADER, SAVES, FORK, MARKET, CLASS, SHOP, RELIC]:
		_draw_menu_bg(_menu_tint(acc))
	else:
		draw_rect(Rect2(0, 0, 720, 1280), Color(0, 0, 0, 0.9))
	if state == INV:
		_draw_inv(acc)
	elif state == SKILLS:
		_draw_skills(acc)
	elif state == TRADE:
		_draw_trade(acc)
	elif state == TUTORIAL:
		_draw_tut(acc)
	elif state == LEADER:
		_draw_lb(acc)
	elif state == SAVES:
		_draw_saves(acc)
	elif state == SETTINGS:
		_draw_settings(acc)
	elif state == MODE:
		_txt("POCKET STATION", Vector2(0, 200), 60, acc)
		_txt("Choose your mode", Vector2(0, 252), 28, Color(1, 1, 1, 0.7))
		var mp := Color("9fb3d9")
		_panel(btn_mode_p, mp, 0.2)
		_txt("PUZZLE", Vector2(btn_mode_p.position.x + 24, btn_mode_p.position.y + 70), 44, mp, 280.0, HORIZONTAL_ALIGNMENT_LEFT)
		_para("Small tense rooms. Level up by beating monsters, then reach the gate before the dark swallows the board. Every step counts.", Vector2(btn_mode_p.position.x + 24, btn_mode_p.position.y + 118), 23, Color.WHITE, 276.0)
		var ma := Color("7dffb0")
		_panel(btn_mode_a, ma, 0.2)
		_txt("ADVENTURE", Vector2(btn_mode_a.position.x + 24, btn_mode_a.position.y + 70), 44, ma, 280.0, HORIZONTAL_ALIGNMENT_LEFT)
		_button(btn_tut, "HOW TO PLAY", Color("ffd84f"), 34, "help")
		_button(btn_lb, "LEADERBOARD", Color("7fd8ff"), 34, "trophy")
		if save_info != "":
			_panel(btn_cont, Color("6dff9a"), 0.2)
			_txt("CONTINUE SAVED RUN", Vector2(btn_cont.position.x, btn_cont.position.y + 32), 30, Color("6dff9a"), btn_cont.size.x)
			_txt(save_info, Vector2(btn_cont.position.x, btn_cont.position.y + 60), 19, Color(1, 1, 1, 0.7), btn_cont.size.x)
		_draw_gear(btn_font.get_center(), Color("c9d3f0"))
		var bt := get_node_or_null("/root/Boot")
		_txt("build %d  %s" % [BUILD, (bt.status if bt else "")], Vector2(0, 1274), 14, Color(1, 1, 1, 0.4))
		if t - xfer_t < 6.0:
			_txt(xfer_msg, Vector2(0, 252), 24, Color("6dff9a"))
		_para("Explore sprawling stations in fog of war. Collect points to unlock the exit, outsmart hunters, find air pods, and open vaults. Watch your air!", Vector2(btn_mode_a.position.x + 24, btn_mode_a.position.y + 118), 23, Color.WHITE, 276.0)
	elif state == DEAD:
		_txt(over_title, Vector2(0, 430), 64, Color("ff5d5d"))
		var ly := 510
		var li := 0
		for line in over_sub.split("\n"):
			var lc := Color.WHITE
			if li == 0:
				lc = Color("ffb0a0")
			elif line.contains("NEW BEST"):
				lc = Color("ffd84f")
			_txt(line, Vector2(0, ly), 28, lc)
			ly += 46
			li += 1
		_button(btn_newrun, "NEW RUN", Color("ff9d9d"), 28)
		_button(btn_shop, "SHOP  (bank %d)" % int(bank_disp), Color("ffc93c"), 28)
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
			_obox(rr, Color(col.r, col.g, col.b, 0.12))
			draw_rect(rr, col, false, 2.0)
			var own := relic_n(String(d["id"]))
			var title := _aname(String(d["id"]), String(d["name"])) + ("   (you have %d)" % own if own > 0 else "")
			_txt(title, Vector2(rr.position.x + 22, rr.position.y + 40), 30, col, rr.size.x - 40, HORIZONTAL_ALIGNMENT_LEFT)
			if cursed:
				_txt("CURSED", Vector2(rr.end.x - 150, rr.position.y + 40), 22, Color("ff6a5c"), 130.0, HORIZONTAL_ALIGNMENT_RIGHT)
			_para(_atext(String(d["id"]), String(d["desc"])), Vector2(rr.position.x + 22, rr.position.y + 74), 21, Color.WHITE, rr.size.x - 44)
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
					var sytxt := _atext("syn_%s_%s" % [String(sy["a"]), String(sy["b"])], String(sy["text"]))
					var stxt := ("SYNERGY ACTIVE: " + sytxt) if have else ("Synergy with %s: %s" % [oname, sytxt])
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
			_obox(dr, Color(dcol.r, dcol.g, dcol.b, 0.12))
			draw_rect(dr, dcol, false, 3.0)
			_obox(Rect2(dr.position.x + 24, dr.position.y + 28, 60, 120), Color(dcol.r, dcol.g, dcol.b, 0.25))
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
			_obox(mr, Color(mcol.r, mcol.g, mcol.b, 0.1))
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
		_button(btn_modeback, "< MODE", acc)
		_txt("%s   Best: %d floors   Bank: %d coins" % ["ADVENTURE" if mode == "adv" else "PUZZLE", adv_best if mode == "adv" else best, bank], Vector2(0, 230), 24, Color(1, 1, 1, 0.6))
		var cd: Dictionary = class_defs[cls_page]
		var ccol: Color = cd["col"]
		var cid := String(cd["id"])
		var copen := class_open(cid)
		var cc := Color(ccol.r, ccol.g, ccol.b) if copen else Color(1, 1, 1, 0.45)
		var card := Rect2(100, 262, 520, 690)
		_obox(card, Color(cc.r, cc.g, cc.b, 0.12))
		draw_rect(card, cc, false, 3.0)
		_ctext(String(cd["name"]).to_upper(), Vector2(360, 318), 44, cc)
		# idle animation: gentle breathing squash and sway
		var isy := 1.0 + 0.03 * sin(t * 2.6)
		var isx := 1.0 + (1.0 - isy) * 0.8
		var ipx := 200.0
		_spr_ex(spr_gen.player(ccol, cid, 0, 0, {}), Vector2(360, 446 - (isy - 1.0) * ipx * 0.5), ipx, Color.WHITE if copen else Color(0.45, 0.45, 0.5, 0.9), 1.0, 0.02 * sin(t * 1.3), isx, isy)
		if copen:
			_txt(String(CLASS_BLURB.get(cid, "")), Vector2(100, 578), 22, cc, 520.0)
			var dtxt := ""
			if mode != "adv":
				var dk := int(cd["per"])
				dtxt = "DARK NORMAL"
				if dk > 0:
					dtxt = "DARK SLOWER +%d" % dk
				elif dk < 0:
					dtxt = "DARK FASTER %d" % dk
			_txt("START LV %d" % (START_LEVEL + int(cd["lvl"])), Vector2(124, 620), 22, Color("ffd84f"), 230.0, HORIZONTAL_ALIGNMENT_LEFT)
			_txt(dtxt, Vector2(346, 620), 22, Color("7fd8ff"), 250.0, HORIZONTAL_ALIGNMENT_RIGHT)
			_para_fit(_atext("cls_" + cid, String(cd["desc"])), Vector2(124, 664), 20, Color.WHITE, 472.0, 5)
			_txt("POWER", Vector2(124, 806), 18, ccol, 200.0, HORIZONTAL_ALIGNMENT_LEFT)
			_para_fit(_act_desc(cid), Vector2(124, 830), 17, Color(1, 1, 1, 0.8), 472.0, 3)
			_txt("KIT", Vector2(124, 928), 18, ccol, 60.0, HORIZONTAL_ALIGNMENT_LEFT)
			var kx := 200.0
			for kid in cd["kit"]:
				_use_icon(String(kid), Vector2(kx, 920), 40)
				kx += 50.0
			if cd["kit"].size() == 0:
				_txt("none", Vector2(190, 928), 18, Color(1, 1, 1, 0.5), 100.0, HORIZONTAL_ALIGNMENT_LEFT)
		else:
			_para("LOCKED. Unlock this class in the SHOP.", Vector2(124, 640), 24, Color(1, 1, 1, 0.6), 472.0)
		_button(btn_cl_l, "<", acc if cls_page > 0 else Color(1, 1, 1, 0.2), 56)
		_button(btn_cl_r, ">", acc if cls_page < class_defs.size() - 1 else Color(1, 1, 1, 0.2), 56)
		for i in class_defs.size():
			draw_circle(Vector2(360 + (i - (class_defs.size() - 1) * 0.5) * 30.0, 978), 8.0 if i == cls_page else 5.0, cc if i == cls_page else Color(1, 1, 1, 0.3))
		_button(btn_cpick, ("PLAY AS " + String(cd["name"]).to_upper()) if copen else "LOCKED - OPEN SHOP", cc if copen else Color("ffc93c"), 28)
		_button(btn_shop2, "SHOP  (bank %d)" % int(bank_disp), Color("ffc93c"), 28)
		var armed := t - reset_armed < 4.0
		_button(btn_wipe, "TAP AGAIN: ERASE ALL PROGRESS" if armed else "RESET ALL PROGRESS", Color("ff5d5d") if armed else Color(1, 1, 1, 0.4), 20)
	elif state == SHOP:
		_txt("SHOP", Vector2(0, 230), 56, Color("ffc93c"))
		_txt("Bank: %d coins      Page %d / %d" % [bank, shop_page + 1, _shop_pages()], Vector2(0, 280), 24, Color.WHITE)
		for ti in SHOP_TABS.size():
			var tr2 := _shop_tab_rect(ti)
			var tc2 := Color("ffc93c") if ti == shop_tab else Color(1, 1, 1, 0.5)
			draw_rect(tr2, Color(tc2.r, tc2.g, tc2.b, 0.16 if ti == shop_tab else 0.06))
			draw_rect(tr2, tc2, false, 2.0)
			_ctext(String(SHOP_TABS[ti]), tr2.get_center(), 18, tc2)
		var slist := _shop_list()
		if slist.is_empty():
			_txt("Nothing here yet. More coming soon!", Vector2(0, 560), 26, Color(1, 1, 1, 0.5))
		for i in 6:
			var idx := shop_page * 6 + i
			if idx >= slist.size():
				break
			var d2: Dictionary = shop_defs[int(slist[idx])]
			var rr2 := _shop_rect(i)
			var lv: int = up(String(d2["id"]))
			var costs: Array = d2["costs"]
			var maxed := lv >= costs.size()
			var can2 := (not maxed) and bank >= int(costs[lv])
			var col2 := Color("6dff9a") if can2 else Color(1, 1, 1, 0.45)
			_obox(rr2, Color(col2.r, col2.g, col2.b, 0.1))
			draw_rect(rr2, col2, false, 2.0)
			var nm2 := _aname(String(d2["id"]), String(d2["name"]))
			if costs.size() > 1:
				nm2 += "  (%d/%d)" % [lv, costs.size()]
			_txt(nm2, Vector2(rr2.position.x + 20, rr2.position.y + 38), 26, Color.WHITE, 420.0, HORIZONTAL_ALIGNMENT_LEFT)
			_txt(_atext(String(d2["id"]), String(d2["desc"])), Vector2(rr2.position.x + 20, rr2.position.y + 76), 19, Color(1, 1, 1, 0.7), 440.0, HORIZONTAL_ALIGNMENT_LEFT)
			var ptxt := ("OWNED" if costs.size() == 1 else "MAXED") if maxed else "%d coins" % int(costs[lv])
			_txt(ptxt, Vector2(rr2.end.x - 170, rr2.position.y + 62), 26, col2, 150.0, HORIZONTAL_ALIGNMENT_RIGHT)
		_button(btn_prev, "< PREV", acc, 24)
		_button(btn_next, "NEXT >", acc, 24)
		_button(btn_back, "BACK", acc, 26)


# ---------- ADVENTURE MODE (sprawling map, fog of war, points gate, air) ----------

func adv_vis_r() -> int:
	return 4 + relic_n("lantern") + relic_n("ember") + (1 if cls == "scout" else 0) + int(gear("sight")) + int(sk("sight")) - (1 if _world_rule() == "glare" else 0)


func adv_oxy_max() -> float:
	return 90.0 + 10.0 * int(cdef()["per"]) + 15.0 * relic_n("slowdark") - 15.0 * relic_n("glass") + gear("air") + sk("air") + 10.0 * float(pk.get("air", 0)) + 2.0 * float(level - START_LEVEL) + 8.0 * float(up("tank"))


func adv_pod_amt() -> float:
	return (30.0 + gear("pod")) * (1.0 + sk("pod") / 100.0)


func _ai(c: Vector2i) -> int:
	return c.y * AW + c.x


func _ain(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < AW and c.y < AH


func _aopen(c: Vector2i) -> bool:
	return _ain(c) and adv_open[_ai(c)] == 1


func _aseen(c: Vector2i) -> bool:
	return _ain(c) and adv_seen[_ai(c)] == 1


func _actr(c: Vector2i) -> Vector2:
	return Vector2(AMX + (float(c.x) - cam.x) * AC, AMY + (float(c.y) - cam.y) * AC)


func _rc(r: Rect2i) -> Vector2i:
	return Vector2i(r.position.x + r.size.x / 2, r.position.y + r.size.y / 2)


func _adv_corridor(a: Vector2i, b: Vector2i, hfirst: bool) -> void:
	var c := a
	var sx := signi(b.x - a.x)
	var sy := signi(b.y - a.y)
	if hfirst:
		while c.x != b.x:
			c.x += sx
			adv_open[_ai(c)] = 1
		while c.y != b.y:
			c.y += sy
			adv_open[_ai(c)] = 1
	else:
		while c.y != b.y:
			c.y += sy
			adv_open[_ai(c)] = 1
		while c.x != b.x:
			c.x += sx
			adv_open[_ai(c)] = 1


func _adv_bfs(src: Vector2i, limit: int = 100000) -> Dictionary:
	var dist := {src: 0}
	var q: Array[Vector2i] = [src]
	var head := 0
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		var d: int = dist[c]
		if d >= limit:
			continue
		for dv in dirs:
			var n: Vector2i = c + dv
			if _aopen(n) and not dist.has(n):
				dist[n] = d + 1
				q.append(n)
	return dist


func _adv_pick(rng: RandomNumberGenerator, r: Rect2i, inner: bool, taken: Dictionary) -> Vector2i:
	var rr := r.grow(-1) if inner else r
	for k in 16:
		var c := Vector2i(rng.randi_range(rr.position.x, rr.end.x - 1), rng.randi_range(rr.position.y, rr.end.y - 1))
		if not taken.has(c):
			taken[c] = true
			return c
	return Vector2i(-1, -1)


func _titan_immune(c: Vector2i) -> bool:
	return arena and boss_floor and String(arena_d.get("kind", "")) == "titan" and c == boss_cell and bool(arena_d.get("shield", false))


func _arena_hint() -> String:
	var k := String(arena_d.get("kind", ""))
	if k == "core":
		return "Orange tiles blast on the next step: move off them"
	if k == "queen":
		return "Drones heal her through the green links: kill them first"
	if k == "lord":
		return "Lure the Crime Lord onto his mines"
	return "Break the pulsing crystals to expose the Titan"


func _arena_free(c: Vector2i) -> bool:
	return _aopen(c) and c.x >= 2 and c.x <= 10 and c.y >= 2 and c.y <= 10 and not mons.has(c) and c != pos and c != stairs and not items.has(c) and not haz.has(c) and not stations.has(c) and not coin_at.has(c)


func _arena_shard_count() -> int:
	var n := 0
	for c in kinds:
		if String(kinds[c]) == "shard" and mons.has(c):
			n += 1
	return n


func _arena_spawn_shards(n: int) -> void:
	var cand: Array[Vector2i] = []
	for x in range(3, 10):
		for y in range(3, 9):
			var c := Vector2i(x, y)
			if _arena_free(c) and absi(c.x - boss_cell.x) + absi(c.y - boss_cell.y) >= 2 and absi(c.x - pos.x) + absi(c.y - pos.y) >= 2:
				cand.append(c)
	cand.shuffle()
	for i in mini(n, cand.size()):
		var sc: Vector2i = cand[i]
		mons[sc] = 1
		kinds[sc] = "shard"
		mon_hp[sc] = 1
		_fx_ring(Vector2(sc), Color("b48cff"), 1.6, 0.5, 4.0)


func _adv_gen_tutorial() -> void:
	AW = 15
	AH = 15
	adv_open.resize(AW * AH)
	adv_open.fill(0)
	adv_seen.resize(AW * AH)
	adv_seen.fill(0)
	adv_rooms.clear()
	mons.clear()
	elite.clear()
	items.clear()
	spikes.clear()
	haz.clear()
	tur.clear()
	corpses.clear()
	coin_at.clear()
	walls.clear()
	portals.clear()
	kinds.clear()
	thief_held.clear()
	vaults.clear()
	stations.clear()
	meds.clear()
	merchants.clear()
	mon_hp.clear()
	affix.clear()
	mstat.clear()
	for r in [Rect2i(3, 11, 9, 3), Rect2i(3, 6, 9, 3), Rect2i(3, 1, 9, 3)]:
		adv_rooms.append(r)
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				adv_open[_ai(Vector2i(x, y))] = 1
	for cy in [4, 5, 9, 10]:
		adv_open[_ai(Vector2i(7, cy))] = 1
	start = Vector2i(7, 13)
	pos = start
	stairs = Vector2i(7, 1)
	boss_floor = false
	boss_cell = Vector2i(-1, -1)
	adv_req = 3
	adv_pts_total = 6
	mons[Vector2i(7, 7)] = 1
	mons[Vector2i(7, 3)] = 1
	items[Vector2i(7, 2)] = "use_zap"
	stations[Vector2i(4, 2)] = true
	for cc in [Vector2i(5, 12), Vector2i(9, 12), Vector2i(7, 11)]:
		coin_at[cc] = true


func _tut_map_start() -> void:
	tut_prev_cls = cls
	tut_prev_save_off = save_off
	save_off = true
	tutorial = true
	tut_zone = -1
	cls = "scout"
	mode = "adv"
	_new_run(1)
	relics.clear()
	equip.clear()
	equip["ranged"] = "blaster"
	bag.clear()
	inv.clear()
	inv.append("blink")
	ammo = ammo_max()
	ranged_mode = false
	coins = 0
	_adv_snapshot()
	_adv_begin()
	_tut_hint()
	_sfx("big")


func _adv_gen_test() -> void:
	AW = 9
	AH = 9
	adv_open.resize(AW * AH)
	adv_open.fill(0)
	adv_seen.resize(AW * AH)
	adv_seen.fill(1)
	adv_rooms.clear()
	for dd in [mons, elite, items, spikes, haz, tur, corpses, coin_at, walls, portals, kinds, thief_held, vaults, stations, meds, merchants, mon_hp, affix, mstat]:
		dd.clear()
	var r := Rect2i(3, 3, 3, 3)
	adv_rooms.append(r)
	for x in range(3, 6):
		for y in range(3, 6):
			adv_open[_ai(Vector2i(x, y))] = 1
	adv_open[_ai(Vector2i(4, 2))] = 1
	start = Vector2i(4, 4)
	pos = start
	stairs = Vector2i(4, 2)
	boss_floor = false
	boss_cell = Vector2i(-1, -1)
	adv_req = 999
	adv_pts_total = 0
	stations[Vector2i(3, 5)] = true


func _test_room_start() -> void:
	test_pending = false
	test_prev_save_off = save_off
	save_off = true
	testroom = true
	mode = "adv"
	_new_run(1)
	bag.clear()
	var ids: Array = gear_defs.keys()
	ids.sort()
	for id in ids:
		bag.append(String(id))
	ammo = ammo_max()
	hp = hp_cap()
	_adv_snapshot()
	msg = "TEST ROOM: open your bag to try every item. MENU leaves."
	inv_tab = 3
	state = INV


func _test_room_end() -> void:
	testroom = false
	save_off = test_prev_save_off
	walk.clear()
	aim = -1
	bag.clear()


func _tut_map_end(done: bool) -> void:
	tutorial = false
	save_off = tut_prev_save_off
	cls = tut_prev_cls
	walk.clear()
	aim = -1
	tool_sel = -1
	state = MODE
	if done:
		xfer_msg = "Tutorial complete! You are ready to play"
		xfer_t = t


const TUT_HINTS := [
	"Tap any tile to walk there, or swipe to step one tile. Walk up the corridor.",
	"A monster! Walk into it to fight. The round button swaps melee and ranged: tap a monster in a clear line to shoot.",
	"Tools: tap one in the bar to select it, tap again to use it. The CANCEL bar backs out.",
	"O2 station: walk onto it to refill your air. Air drops with every step.",
	"Exit open! Points unlock it. Walk to the gate at the top to finish.",
]


func _tut_hint() -> void:
	var z := 0
	if pos.y <= 8:
		z = 1
	if pos.y <= 5:
		z = 2
	if absi(pos.x - 4) + absi(pos.y - 2) <= 2:
		z = 3
	if adv_pts >= adv_req and pos.y <= 3:
		z = 4
	if z == tut_zone:
		return
	tut_zone = z
	msg = String(TUT_HINTS[z])


const WORLD_RULES := ["leak", "spore", "black", "glare"]
const WORLD_RULE_TEXT := {
	"leak": "Vacuum leaks: corridors drain extra air. Rooms are safe.",
	"spore": "Spore bursts: every 30 steps you are briefly poisoned.",
	"black": "Black market: more merchants, but more thieves.",
	"glare": "Crystal glare: you see 1 tile less, but kills give +25% XP.",
}
var guide_seen: Dictionary = {}
var banner_rule := ""
var banner_t0 := -100.0
const WORLD_BANNER_TIME := 10.0
const WORLD_RULE_COL := {"leak": Color("7fd8ff"), "spore": Color("b6ff6a"), "black": Color("ffc93c"), "glare": Color("e6c8ff")}


# warning banner shown for ~10 s at the top of the map when a new world's rule starts
func _draw_world_banner() -> void:
	if banner_rule == "" or state != PLAY:
		return
	var age := t - banner_t0
	if age < 0.0 or age > WORLD_BANNER_TIME:
		return
	var a := clampf(minf(age / 0.3, (WORLD_BANNER_TIME - age) / 1.0), 0.0, 1.0)
	var col: Color = WORLD_RULE_COL[banner_rule]
	var r := Rect2(24, 330, 672, 124)
	draw_rect(r, Color(0.02, 0.03, 0.07, 0.88 * a))
	draw_rect(r, Color(col.r, col.g, col.b, a), false, 3.0)
	_txt("WORLD RULE", Vector2(r.position.x, r.position.y + 36), 28, Color(col.r, col.g, col.b, a), r.size.x)
	_para(String(WORLD_RULE_TEXT[banner_rule]), Vector2(r.position.x + 20, r.position.y + 66), 22, Color(1, 1, 1, a), r.size.x - 40.0)


func _world_rule() -> String:
	if mode != "adv" or tutorial or testroom or arena or themes.is_empty():
		return ""
	return String(WORLD_RULES[tidx() % WORLD_RULES.size()])


func _adv_in_room(c: Vector2i) -> bool:
	for rm in adv_rooms:
		if (rm as Rect2i).has_point(c):
			return true
	return false


func _guide_on() -> bool:
	return mode == "adv" and not tutorial and not arena and floor_n == 1 and adv_best == 0


func _guide_say(k: String, text: String) -> bool:
	if guide_seen.has(k):
		return false
	guide_seen[k] = true
	msg = text
	return true


func _guide_tick() -> void:
	if not _guide_on() or state != PLAY:
		return
	if adv_pts >= adv_req and _guide_say("exit", "Exit unlocked! Walk to the exit gate to finish the floor."):
		return
	if hp * 3 < hp_cap() and _guide_say("lowhp", "Low health! Pick up health items, and check a monster's fight cost before you fight it."):
		return
	if oxy < oxy_max * 0.5 and _guide_say("air", "Half your air is gone. Walk onto an O2 station to refill it, or grab an air pod."):
		return
	if skill_pts > 0 and _guide_say("skill", "You have a skill point! Tap SKILLS to spend it."):
		return
	for dx in range(-3, 4):
		for dy in range(-3, 4):
			var gc := pos + Vector2i(dx, dy)
			if not items.has(gc):
				continue
			var gk := String(items[gc])
			if gk == "shrine" and _guide_say("shrine", "A shrine: pay a slice of health for a big burst of XP."):
				return
			if gk == "idol" and _guide_say("idol", "A Golden Idol: pure coins and points. Safe to grab."):
				return
	if inv.size() > 0 and _guide_say("tool", "You hold a tool. Tap it in the bar to select it, tap again to use it."):
		return


func _adv_gen_arena() -> void:
	AW = 13
	AH = 13
	adv_open.resize(AW * AH)
	adv_open.fill(0)
	adv_seen.resize(AW * AH)
	adv_seen.fill(0)
	adv_rooms.clear()
	mons.clear()
	elite.clear()
	items.clear()
	spikes.clear()
	haz.clear()
	tur.clear()
	corpses.clear()
	coin_at.clear()
	walls.clear()
	portals.clear()
	kinds.clear()
	thief_held.clear()
	vaults.clear()
	stations.clear()
	meds.clear()
	merchants.clear()
	mon_hp.clear()
	affix.clear()
	mstat.clear()
	adv_rooms.append(Rect2i(2, 2, 9, 9))
	for x in range(2, 11):
		for y in range(2, 11):
			adv_open[_ai(Vector2i(x, y))] = 1
	start = Vector2i(6, 10)
	pos = start
	stairs = Vector2i(6, 2)
	boss_floor = true
	boss_cell = stairs
	adv_pts_total = 0
	adv_req = 0
	var kind_ids := ["core", "queen", "lord", "titan"]
	var k: String = kind_ids[tidx() % 4]
	arena_d = {"kind": k, "mark": [], "n": 0, "shield": false, "resh": 0, "intro": false}
	mons[stairs] = _adv_scaled(3 + floor_n / 2) + 2
	stations[Vector2i(2, 10)] = true
	stations[Vector2i(10, 10)] = true
	items[Vector2i(2, 6)] = "hp"
	items[Vector2i(10, 6)] = "hp"
	items[Vector2i(4, 10)] = "pod"
	items[Vector2i(8, 10)] = "pod"
	items[Vector2i(6, 8)] = "shield"
	for cc in [Vector2i(3, 8), Vector2i(9, 8), Vector2i(2, 4), Vector2i(10, 4)]:
		coin_at[cc] = true
	if k == "lord":
		for mc in [Vector2i(6, 3), Vector2i(6, 5), Vector2i(4, 6), Vector2i(8, 6), Vector2i(3, 4), Vector2i(9, 4)]:
			haz[mc] = "mine"
	elif k == "titan":
		arena_d["shield"] = true
		_arena_spawn_shards(3)


func _arena_pick_marks(cnt: int) -> Array:
	var out: Array = [pos]
	var pool: Array[Vector2i] = []
	for dx in range(-3, 4):
		for dy in range(-3, 4):
			var c := pos + Vector2i(dx, dy)
			if c != pos and _aopen(c) and c != boss_cell and c != stairs and c.x >= 2 and c.x <= 10 and c.y >= 2 and c.y <= 10:
				pool.append(c)
	pool.shuffle()
	for i in mini(cnt, pool.size()):
		out.append(pool[i])
	var dirs4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var free := false
	for dv in dirs4:
		var nb: Vector2i = pos + dv
		if _aopen(nb) and not mons.has(nb) and not out.has(nb):
			free = true
	if not free:
		for dv in dirs4:
			out.erase(pos + dv)
	return out


func _arena_boss_move(a: Vector2i, b: Vector2i) -> void:
	_adv_move_mon(a, b)
	if String(haz.get(b, "")) == "mine" and mons.has(b):
		haz.erase(b)
		_fx_ring(Vector2(b), Color("ff9a3c"), 2.0, 0.5, 8.0)
		_fx_burst(Vector2(b), Color("ff7a45"), 30, 5.0, 0.6, 7.0)
		_shake(7.0, 0.35)
		var md := maxi(1, mini(mon_hp_now(b) - 1, int(mon_hp_max(b) * 0.3)))
		_pop(b, "BOOM -%d" % md, Color("ff7a45"))
		mon_hp[b] = mon_hp_now(b) - md
		_sfx("boom")
		msg = "The Crime Lord stepped on a mine! -%d HP" % md


func _arena_tick(fought: bool) -> void:
	if not arena or not boss_floor:
		return
	var k := String(arena_d.get("kind", ""))
	var n := int(arena_d.get("n", 0)) + 1
	arena_d["n"] = n
	var bc := boss_cell
	if not mons.has(bc):
		arena_d["mark"] = []
		for c in kinds.keys():
			if (String(kinds[c]) == "drone" or String(kinds[c]) == "shard") and mons.has(c):
				_remove_mon(c)
		return
	var dirs4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	if k == "core" or k == "titan":
		var marks: Array = arena_d.get("mark", [])
		if marks.size() > 0:
			var hit := false
			for mcell in marks:
				_fx_burst(Vector2(mcell), Color("ff9a3c"), 14, 3.5, 0.5, 6.0)
				if mcell == pos:
					hit = true
			_shake(5.0, 0.3)
			_sfx("boom")
			arena_d["mark"] = []
			if hit:
				var bd := maxi(2, int(round(float(2 + floor_n / 2 + level / 4) * 1.5)))
				if not _adv_env_hurt(bd, "Blast! You lose %d health", "You were caught in the %s's blast" % String(cur_theme()["boss"]), "boom"):
					return
		elif n % (2 if k == "core" else 3) == 0:
			arena_d["mark"] = _arena_pick_marks((4 + floor_n / 8) if k == "core" else 3)
			msg = "Orange tiles blast on the next step!"
			_sfx("alarm")
	if k == "queen":
		var dr: Array[Vector2i] = []
		for c in kinds:
			if String(kinds[c]) == "drone" and mons.has(c):
				dr.append(c)
		if n % 2 == 0 and dr.size() > 0 and mon_hp_now(bc) < mon_hp_max(bc):
			var heal := dr.size() * (1 + floor_n / 6)
			mon_hp[bc] = mini(mon_hp_max(bc), mon_hp_now(bc) + heal)
			_pop(bc, "+%d" % heal, Color("6dff9a"))
		if n % 8 == 0 and dr.size() < 2:
			var spots: Array[Vector2i] = []
			for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1)]:
				var sp: Vector2i = bc + dv
				if _arena_free(sp):
					spots.append(sp)
			if spots.size() > 0:
				var dc: Vector2i = spots[randi() % spots.size()]
				mons[dc] = maxi(1, _adv_scaled(2) - 1)
				kinds[dc] = "drone"
				_fx_ring(Vector2(dc), Color("6dff9a"), 1.4, 0.5, 4.0)
				_fx_burst(Vector2(dc), Color("6dff9a"), 10, 2.5, 0.5, 5.0)
				msg = "The Hive Queen spawns a drone! It heals her while it lives"
				_sfx("aggro")
	elif k == "lord":
		if not bool(arena_d.get("intro", false)):
			arena_d["intro"] = true
			var fwd := bc + Vector2i(0, 1)
			if _aopen(fwd) and not mons.has(fwd) and fwd != pos:
				_arena_boss_move(bc, fwd)
				msg = "The Crime Lord charges in... and steps on his own mine!"
			return
		if n % 2 == 0:
			var dd := absi(bc.x - pos.x) + absi(bc.y - pos.y)
			if dd == 1:
				if not fought:
					mon_lunge[bc] = [t, Vector2(pos - bc).normalized()]
					msg = "The Crime Lord strikes!"
					if not _adv_hurt(mon_atk(bc), String(cur_theme()["boss"]), bc):
						return
			else:
				var dist := _adv_bfs(pos, 30)
				var best := bc
				var bdv := int(dist.get(bc, 9999))
				for dv in dirs4:
					var nb: Vector2i = bc + dv
					if dist.has(nb) and int(dist[nb]) < bdv and not mons.has(nb) and nb != pos:
						bdv = int(dist[nb])
						best = nb
				if best != bc:
					_arena_boss_move(bc, best)
	elif k == "titan":
		var shield_up := bool(arena_d.get("shield", false))
		if shield_up and _arena_shard_count() == 0:
			arena_d["shield"] = false
			_fx_ring(Vector2(bc), Color("7fe8ff"), 2.4, 0.7, 6.0)
			_shake(6.0, 0.3)
			msg = "The crystals shatter! The Titan is exposed"
			_sfx("big")
		elif not shield_up:
			var rs := int(arena_d.get("resh", 0))
			var frac := float(mon_hp_now(bc)) / float(maxi(1, mon_hp_max(bc)))
			if rs < 2 and frac <= (0.66 if rs == 0 else 0.33):
				arena_d["resh"] = rs + 1
				arena_d["shield"] = true
				_arena_spawn_shards(3 + rs)
				msg = "The Titan re-forms its crystals!"
				_sfx("alarm")


func _draw_shard(ctr: Vector2) -> void:
	var p := 0.5 + 0.5 * sin(t * 4.0 + ctr.x * 0.05)
	var s := AC * (0.30 + 0.04 * p)
	draw_circle(ctr, AC * (0.62 + 0.12 * p), Color(0.55, 0.85, 1.0, 0.08 + 0.10 * p))
	draw_circle(ctr, AC * (0.44 + 0.06 * p), Color(0.7, 0.6, 1.0, 0.12 + 0.12 * p))
	draw_circle(ctr + Vector2(0, AC * 0.34), AC * 0.2, Color(0, 0, 0, 0.3))
	var top := ctr + Vector2(0, -s * 1.6)
	var bot := ctr + Vector2(0, s * 1.3)
	var lft := ctr + Vector2(-s * 0.85, -s * 0.1)
	var rgt := ctr + Vector2(s * 0.85, -s * 0.1)
	draw_colored_polygon(PackedVector2Array([top, lft, bot]), Color(0.72, 0.92, 1.0, 0.96))
	draw_colored_polygon(PackedVector2Array([top, rgt, bot]), Color(0.42, 0.55, 0.95, 0.96))
	draw_polyline(PackedVector2Array([top, rgt, bot, lft, top]), Color(1, 1, 1, 0.55 + 0.4 * p), 2.0)
	draw_line(top, bot, Color(1, 1, 1, 0.35), 1.5)
	for i in 3:
		var a := t * 1.6 + float(i) * TAU / 3.0
		draw_circle(ctr + Vector2.from_angle(a) * AC * 0.5, 2.5, Color(0.85, 0.8, 1.0, 0.4 + 0.5 * p))


func _arena_draw_under() -> void:
	if not arena:
		return
	var marks: Array = arena_d.get("mark", [])
	for mc in marks:
		var r := Rect2(_actr(mc) - Vector2(AC, AC) * 0.5, Vector2(AC, AC)).grow(-3)
		var pl := 0.5 + 0.5 * sin(t * 10.0)
		draw_rect(r, Color(1, 0.5, 0.1, 0.22 + 0.2 * pl))
		draw_rect(r, Color(1, 0.65, 0.2, 0.9), false, 3.0)
		_ctext("!", _actr(mc), int(AC * 0.5), Color(1, 0.85, 0.4, 0.9))
	var k := String(arena_d.get("kind", ""))
	if not mons.has(boss_cell):
		return
	var qp := _actr(boss_cell) + _mon_off(boss_cell)
	var lc := Color(0.3, 1.0, 0.5)
	var lc2 := Color(0.6, 1.0, 0.7)
	var srcs: Array[Vector2i] = []
	if k == "queen":
		for c in kinds:
			if String(kinds[c]) == "drone" and mons.has(c):
				srcs.append(c)
	elif k == "titan" and bool(arena_d.get("shield", false)):
		lc = Color(0.55, 0.6, 1.0)
		lc2 = Color(0.8, 0.9, 1.0)
		for c in kinds:
			if String(kinds[c]) == "shard" and mons.has(c):
				srcs.append(c)
	for c in srcs:
		var dp := _actr(c) + _mon_off(c)
		draw_line(qp, dp, Color(lc.r, lc.g, lc.b, 0.22), 9.0)
		draw_line(qp, dp, Color(lc2.r, lc2.g, lc2.b, 0.85), 3.0)
		for i in 3:
			var ph := fmod(t * 1.2 + float(i) / 3.0, 1.0)
			draw_circle(dp.lerp(qp, ph), 5.0, Color(lc2.r, lc2.g, lc2.b, sin(ph * PI)))


func _arena_selftest() -> int:
	var bad := 0
	var saved_floor := floor_n
	for i in 4:
		floor_n = 3 + 3 * i
		arena = true
		level = 6
		_adv_gen()
		_adv_begin()
		if not mons.has(boss_cell) or not _aopen(start) or not _aopen(stairs):
			print("FAIL arena setup %d" % i)
			bad += 1
		var dirs4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		for s in 40:
			var dv: Vector2i = dirs4[randi() % 4]
			var nb: Vector2i = pos + dv
			if _aopen(nb):
				_adv_step(nb, true)
			if state != PLAY:
				state = PLAY
				hp = hp_cap()
			if i == 3 and s == 10:
				for c in kinds.keys():
					if String(kinds[c]) == "shard":
						_adv_damage_mon(c, 5)
		print("arena %d kind %s steps %d drones/shards ok boss %s" % [i, String(arena_d.get("kind", "")), int(arena_d.get("n", 0)), mons.has(boss_cell)])
	arena = false
	arena_d = {}
	floor_n = saved_floor
	return bad


func _adv_gen() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = adv_seed
	if tutorial:
		_adv_gen_tutorial()
		return
	if testroom:
		_adv_gen_test()
		return
	if arena:
		_adv_gen_arena()
		return
	AW = mini(34 + floor_n * 2, 56)
	AH = AW
	adv_open.resize(AW * AH)
	adv_open.fill(0)
	adv_seen.resize(AW * AH)
	adv_seen.fill(0)
	adv_rooms.clear()
	mons.clear()
	elite.clear()
	items.clear()
	spikes.clear()
	haz.clear()
	tur.clear()
	corpses.clear()
	coin_at.clear()
	walls.clear()
	portals.clear()
	kinds.clear()
	thief_held.clear()
	vaults.clear()
	var want := mini(8 + floor_n, 15)
	var tries := 0
	while adv_rooms.size() < want and tries < 800:
		tries += 1
		var w := rng.randi_range(5, 9)
		var h := rng.randi_range(5, 8)
		var x := rng.randi_range(2, AW - w - 3)
		var y := rng.randi_range(2, AH - h - 3)
		var r := Rect2i(x, y, w, h)
		var ok := true
		for o in adv_rooms:
			if r.grow(2).intersects(o):
				ok = false
				break
		if ok:
			adv_rooms.append(r)
			for xx in range(r.position.x, r.end.x):
				for yy in range(r.position.y, r.end.y):
					adv_open[_ai(Vector2i(xx, yy))] = 1
	var rdeg: Array[int] = []
	rdeg.resize(adv_rooms.size())
	rdeg.fill(0)
	for i in range(1, adv_rooms.size()):
		var a: Rect2i = adv_rooms[i]
		var bj := 0
		var bd := 1e9
		for j in i:
			var dd := Vector2(_rc(a)).distance_to(Vector2(_rc(adv_rooms[j])))
			if dd < bd:
				bd = dd
				bj = j
		_adv_corridor(_rc(a), _rc(adv_rooms[bj]), rng.randf() < 0.5)
		rdeg[i] += 1
		rdeg[bj] += 1
	for k in 2 + floor_n / 4:
		var i2 := rng.randi_range(0, adv_rooms.size() - 1)
		var j2 := rng.randi_range(0, adv_rooms.size() - 1)
		if i2 != j2:
			_adv_corridor(_rc(adv_rooms[i2]), _rc(adv_rooms[j2]), rng.randf() < 0.5)
			rdeg[i2] += 1
			rdeg[j2] += 1
	start = _rc(adv_rooms[0])
	pos = start
	var dist := _adv_bfs(start)
	var far := 1
	var fd := -1
	for i in range(1, adv_rooms.size()):
		var d2: int = dist.get(_rc(adv_rooms[i]), 0)
		if d2 > fd:
			fd = d2
			far = i
	stairs = _rc(adv_rooms[far])
	boss_floor = floor_n % 5 == 0
	boss_cell = stairs if boss_floor else Vector2i(-1, -1)
	var taken := {start: true, stairs: true}
	var pts := 0
	var gain := 0
	var mon_cells: Array[Vector2i] = []
	var tool_ids: Array = []
	for k in use_defs.keys():
		if k != "pick":
			tool_ids.append(k)
	stations.clear()
	meds.clear()
	merchants.clear()
	mon_hp.clear()
	stations[start] = true
	var smin: Dictionary = dist.duplicate()
	for guard in 8:
		var worst := -1
		var wd := 0
		for i in range(1, adv_rooms.size()):
			var dd2: int = smin.get(_rc(adv_rooms[i]), 0)
			if dd2 > wd:
				wd = dd2
				worst = i
		if worst < 0 or wd <= 28:
			break
		var stc := _adv_pick(rng, adv_rooms[worst], true, taken)
		if stc.x < 0:
			break
		stations[stc] = true
		var d3 := _adv_bfs(stc)
		for k in d3:
			if int(d3[k]) < int(smin.get(k, 99999)):
				smin[k] = d3[k]
	for i in adv_rooms.size():
		var r: Rect2i = adv_rooms[i]
		var is_start := i == 0
		var nm := 0
		if not is_start:
			nm = rng.randi_range(0, 2)
			if i == far:
				nm = maxi(nm, 1)
			if r.size.x * r.size.y >= 45 and floor_n >= 3 and rng.randf() < 0.5:
				nm += 1
		for k in nm:
			var mc := _adv_pick(rng, r, true, taken)
			if mc.x >= 0:
				mons[mc] = 1
				mon_cells.append(mc)
		for k in rng.randi_range(1, 4):
			var cc := _adv_pick(rng, r, false, taken)
			if cc.x >= 0:
				coin_at[cc] = true
				pts += 1
		if rng.randf() < 0.55:
			var pc := _adv_pick(rng, r, false, taken)
			if pc.x >= 0:
				items[pc] = "pot"
				pts += 2
				gain += pot_g()
		if rng.randf() < 0.12:
			var bc := _adv_pick(rng, r, false, taken)
			if bc.x >= 0:
				items[bc] = "big"
				pts += 4
				gain += big_g()
		if rng.randf() < (0.3 if is_start else 0.45):
			var oc := _adv_pick(rng, r, false, taken)
			if oc.x >= 0:
				items[oc] = "pod"
		if rng.randf() < 0.15:
			var sc := _adv_pick(rng, r, false, taken)
			if sc.x >= 0:
				items[sc] = "shield"
				pts += 2
		if rng.randf() < 0.6:
			var hc := _adv_pick(rng, r, false, taken)
			if hc.x >= 0:
				items[hc] = "hp"
				pts += 1
		if not is_start and rng.randf() < 0.24:
			var gcell := _adv_pick(rng, r, false, taken)
			if gcell.x >= 0:
				items[gcell] = "gear_" + _adv_roll_gear(rng)
				pts += 2
		if rng.randf() < 0.2:
			var arc := _adv_pick(rng, r, false, taken)
			if arc.x >= 0:
				items[arc] = "armor"
				pts += 3
		if rng.randf() < 0.18:
			var lc := _adv_pick(rng, r, false, taken)
			if lc.x >= 0:
				items[lc] = "lamp"
				pts += 2
		if not is_start and rng.randf() < 0.16:
			var xc := _adv_pick(rng, r, false, taken)
			if xc.x >= 0:
				var xpool := ["shieldbattery", "shieldbattery", "luckycoin", "luckycoin", "bounty", "bounty", "lanternoil", "lanternoil", "idol", "shrine", "shrine", "altar", "trapcache", "heartcell", "ammocrate", "ammocrate", "ammocrate"]
				items[xc] = String(xpool[rng.randi() % xpool.size()])
				pts += 2
		if rng.randf() < 0.22:
			var tc := _adv_pick(rng, r, false, taken)
			if tc.x >= 0:
				items[tc] = "use_" + String(tool_ids[rng.randi() % tool_ids.size()])
				pts += 3
		if not is_start and rng.randf() < 0.3:
			for k in rng.randi_range(1, 3):
				var spc := _adv_pick(rng, r, false, taken)
				if spc.x >= 0:
					spikes[spc] = true
	var crates := 0
	for ic in items:
		if String(items[ic]).begins_with("gear_"):
			crates += 1
	if crates == 0 and adv_rooms.size() > 2:
		var cr: Rect2i = adv_rooms[rng.randi_range(1, adv_rooms.size() - 1)]
		var cc2 := _adv_pick(rng, cr, false, taken)
		if cc2.x >= 0:
			items[cc2] = "gear_" + _adv_roll_gear(rng)
			pts += 2
	if rng.randf() < (0.9 if _world_rule() == "black" else 0.6) and adv_rooms.size() > 3:
		var mi := rng.randi_range(1, adv_rooms.size() - 1)
		if mi != far:
			var mcell2 := _adv_pick(rng, adv_rooms[mi], true, taken)
			if mcell2.x >= 0:
				var offers: Array = []
				for k in 3:
					var gid3 := _adv_roll_gear(rng)
					offers.append({"kind": "gear", "id": gid3, "price": maxi(5, gprice(gid3)), "sold": false})
				var tid := String(tool_ids[rng.randi() % tool_ids.size()])
				var tprice := 6 + floor_n / 5 + (4 if tid == "nano" or tid == "plate" else 0)
				offers.append({"kind": "tool", "id": tid, "price": maxi(3, tprice), "sold": false})
				merchants[mcell2] = offers
	if floor_n >= 2 and adv_rooms.size() > 3 and rng.randf() < 0.75:
		var mdr := rng.randi_range(1, adv_rooms.size() - 1)
		var mdc := _adv_pick(rng, adv_rooms[mdr], true, taken)
		if mdc.x >= 0 and not merchants.has(mdc) and not stations.has(mdc):
			meds[mdc] = true
	if relic_n("scavenger") > 0:
		var er: Rect2i = adv_rooms[rng.randi_range(1, adv_rooms.size() - 1)]
		var ec := _adv_pick(rng, er, false, taken)
		if ec.x >= 0:
			items[ec] = "use_" + String(tool_ids[rng.randi() % tool_ids.size()])
			pts += 3
	if floor_n >= 2 and adv_rooms.size() >= 4 and rng.randf() < 0.6:
		var ki := rng.randi_range(1, adv_rooms.size() - 1)
		var vi := rng.randi_range(1, adv_rooms.size() - 1)
		if ki != vi:
			var kc := _adv_pick(rng, adv_rooms[ki], false, taken)
			var vc := _adv_pick(rng, adv_rooms[vi], true, taken)
			if kc.x >= 0 and vc.x >= 0:
				items[kc] = "key"
				vaults[vc] = true
				pts += 12
				gain += 1
	var de_n := 0
	for de_i in range(1, adv_rooms.size()):
		if de_n >= 2:
			break
		if de_i == far or rdeg[de_i] != 1 or rng.randf() > 0.7:
			continue
		var de_c := _adv_pick(rng, adv_rooms[de_i], true, taken)
		if de_c.x < 0:
			continue
		items[de_c] = "idol" if rng.randf() < 0.4 else "shrine"
		pts += 2
		de_n += 1
		if floor_n >= 3 and rng.randf() < 0.6:
			var de_g := _adv_pick(rng, adv_rooms[de_i], true, taken)
			if de_g.x >= 0:
				mons[de_g] = 1
				mon_cells.append(de_g)
	if floor_n >= 2 and adv_rooms.size() > 2:
		var hids: Array = HAZ_IDS[tidx()]
		var corr: Array[Vector2i] = []
		for cy in range(1, AH - 1):
			for cx in range(1, AW - 1):
				var cc := Vector2i(cx, cy)
				if not _aopen(cc) or taken.has(cc) or cc == start or cc == stairs:
					continue
				var in_room := false
				for rm in adv_rooms:
					if (rm as Rect2i).grow(1).has_point(cc):
						in_room = true
						break
				if in_room:
					continue
				var oh := _aopen(cc + Vector2i(1, 0)) and _aopen(cc + Vector2i(-1, 0)) and not _aopen(cc + Vector2i(0, 1)) and not _aopen(cc + Vector2i(0, -1))
				var ov := _aopen(cc + Vector2i(0, 1)) and _aopen(cc + Vector2i(0, -1)) and not _aopen(cc + Vector2i(1, 0)) and not _aopen(cc + Vector2i(-1, 0))
				if oh or ov:
					corr.append(cc)
		for k in clampi(2 + floor_n / 3, 2, 8):
			if corr.is_empty():
				break
			var hi := rng.randi_range(0, corr.size() - 1)
			var hcell: Vector2i = corr[hi]
			corr.remove_at(hi)
			taken[hcell] = true
			haz[hcell] = String(hids[rng.randi() % hids.size()])
		var tn := clampi(1 + floor_n / 4 + rng.randi_range(0, 1), 1, 5)
		var ttries := 0
		while tn > 0 and ttries < 40:
			ttries += 1
			var tcell := _adv_pick(rng, adv_rooms[rng.randi_range(1, adv_rooms.size() - 1)], true, taken)
			if tcell.x < 0 or int(dist.get(tcell, 0)) < 4:
				continue
			var okd: Array[int] = []
			for di in 4:
				var open_n := 0
				for st in range(1, TUR_RANGE + 1):
					if _aopen(tcell + TDIRS[di] * st):
						open_n += 1
					else:
						break
				if open_n >= 3:
					okd.append(di)
			if okd.is_empty():
				continue
			var traw := 1 + int(dist.get(tcell, 0)) / 10 + rng.randi_range(0, 1)
			var tlv := maxi(1, mini(_adv_scaled(traw), level + 2))
			mons[tcell] = tlv
			kinds[tcell] = "turret"
			tur[tcell] = {"v": rng.randi_range(0, 1), "d": okd[rng.randi() % okd.size()]}
			pts += tlv
			tn -= 1
	var lvls: Array = []
	for c in mon_cells:
		var d: int = dist.get(c, 0)
		var raw := 1 + d / 10 + rng.randi_range(0, 1)
		lvls.append({"c": c, "lv": _adv_scaled(raw)})
	lvls.sort_custom(func(a, b): return int(a["lv"]) < int(b["lv"]))
	var budget := level + 1 + floor_n / 6
	for k in lvls.size():
		var e: Dictionary = lvls[k]
		var lv2: int = maxi(1, mini(int(e["lv"]), budget + k / 2 + 1))
		var mcell: Vector2i = e["c"]
		mons[mcell] = lv2
		if floor_n >= 2 and rng.randf() < 0.25:
			kinds[mcell] = "hunter"
		elif floor_n >= 3 and rng.randf() < (0.3 if _world_rule() == "black" else 0.15):
			kinds[mcell] = "thief"
		elif floor_n >= 3 and rng.randf() < 0.14:
			kinds[mcell] = "shooter"
		var el := rng.randf() < 0.15
		if el:
			elite[mcell] = true
		pts += lv2 + (2 if el else 0)
	if boss_floor:
		var bl := _adv_scaled(3 + floor_n / 2) + 1
		mons[stairs] = bl
		pts += 25 + bl
	adv_pts_total = pts
	adv_req = maxi(6, int(pts * minf(0.5, 0.35 + 0.015 * floor_n)) + 4 * req_adjust())
	_roll_affixes()


func gear(stat: String) -> float:
	var tot := 0.0
	for slot in equip:
		if slot == ("weapon" if shooting else "ranged"):
			continue
		var id := String(equip[slot])
		if id == "" or not gear_defs.has(gb(id)):
			continue
		var st: Dictionary = gear_defs[gb(id)]["stats"]
		tot += float(st.get(stat, 0))
	return tot


func hp_cap() -> int:
	return hp_max + int(gear("hp")) + int(sk("hp")) + 4 * (relic_n("pyro") + relic_n("storm") + relic_n("frost") + relic_n("toxi") + relic_n("bloodpact") + relic_n("hood"))


func sh_cap() -> int:
	return sh_max + int(gear("shield")) + int(sk("shield")) + 3 * int(pk.get("shield", 0))


func armor_total() -> int:
	return armor + int(gear("armor")) + int(sk("armor")) + int(pk.get("armor", 0))


func p_atk() -> int:
	return level + boost + int(gear("atk")) + int(sk("atk")) + int(pk.get("mel", 0)) + (int(sk("berserk")) if hp * 2 < hp_cap() else 0)


func _ranged_atk() -> int:
	return 1 + (level - START_LEVEL) / 2 + boost + int(gear("atk")) + int(sk("atk")) + int(pk.get("rng", 0)) + (3 if cls == "gunslinger" else 0)


func ammo_max() -> int:
	return 12 + 4 * int(pk.get("ammo", 0)) + int(sk("ammomax")) + 4 * up("belt") + (4 if cls == "gunslinger" else 0)


func _is_frenzied(c: Vector2i) -> bool:
	return String(affix.get(c, "")) == "frenzy" and mon_hp_now(c) * 2 < mon_hp_max(c)


func _frenzy_tint(c: Vector2i) -> Color:
	if not _is_frenzied(c):
		return Color.WHITE
	var k := 0.5 + 0.5 * sin(t * 8.0)
	return Color(1.0, 0.32 + 0.14 * k, 0.28 + 0.1 * k, 1.0)


func _aff_pill(p: Vector2, key: String, fs: int, right: bool) -> void:
	var ad: Dictionary = AFFIX_DEFS[key]
	var col: Color = ad["col"]
	var txt := String(ad["s"])
	var w := font_title.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 10.0
	var h := float(fs) + 6.0
	var cx := p.x - w * 0.5 if right else p.x
	var r := Rect2(cx - w * 0.5, p.y - h * 0.5, w, h)
	draw_rect(r.grow(1.5), Color("0a0c14"))
	draw_rect(r, Color(col.r * 0.5, col.g * 0.5, col.b * 0.5))
	_ctext(txt, Vector2(cx, p.y), fs, col)


func mon_atk(c: Vector2i) -> int:
	var a := maxi(1, _mon_level(c))
	if mode == "adv":
		a += armor_total() / 3 + floor_n / 10
		if _is_frenzied(c):
			a += maxi(2, a / 2)
	return a


func mon_hp_max(c: Vector2i) -> int:
	var h := 4 + 3 * _mon_level(c)
	if elite.has(c):
		h = int(h * 1.5)
	if boss_floor and c == boss_cell:
		h = int(h * 1.6)
	if mode == "adv":
		h = int(h * (1.0 + minf(0.6, 0.03 * float(threat()))) * (1.0 + 0.02 * float(floor_n)))
	return h


func mon_hp_now(c: Vector2i) -> int:
	return int(mon_hp.get(c, mon_hp_max(c)))


func dmg_taken(a: int) -> int:
	var d := maxi(1, a - armor_total())
	if mode == "adv" and sk("laststand") > 0.0 and hp * 100 < hp_cap() * 30:
		d = maxi(1, int(round(float(d) * (1.0 - sk("laststand") / 100.0))))
	return d


func _adv_cost(c: Vector2i) -> int:
	if tur.has(c):
		return 0
	var hits := int(ceil(float(mon_hp_now(c)) / float(maxi(1, p_atk()))))
	return maxi(0, hits - 1) * dmg_taken(mon_atk(c))


func _adv_outcome(c: Vector2i) -> int:
	var cost := _adv_cost(c)
	var pool := hp + sh
	if cost >= pool:
		return 2
	if cost * 2 >= pool:
		return 1
	return 0


func _adv_mname(c: Vector2i) -> String:
	var th := cur_theme()
	var names: Array = th["mons"]
	if boss_floor and c == boss_cell:
		return String(th["boss"])
	if String(kinds.get(c, "")) == "shard":
		return "Crystal Shard"
	if String(kinds.get(c, "")) == "drone":
		return "Hive Drone"
	if tur.has(c):
		return String(TUR_NAMES[tidx()][int(tur[c]["v"])])
	return _affix_name(c, String(names[(int(mons[c]) - 1) % names.size()]))


func _adv_level_up(n: int, pick := false) -> void:
	var old := level
	var oh := hp_cap()
	var oo := oxy_max
	level += n
	hp_max += 3 * n
	_adv_apply_change(oh, oo)
	var got := 0
	for l in range(old + 1, level + 1):
		if l % 3 == 0:
			got += 1
	if got > 0:
		skill_pts += got
		sk_ban_n = got
		sk_ban_t0 = t + 1.0


func _adv_hurt(a: int, who: String, src := Vector2i(-1, -1)) -> bool:
	if mirror_n > 0:
		mirror_n -= 1
		_pop(pos, "REFLECT", Color("c8f1ff"))
		_fx_ring(vis_pos, Color("c8f1ff"), 1.2, 0.4, 5.0)
		msg += "   Mirror Shard reflects %s!" % who
		_sfx("shield")
		if mons.has(src):
			_adv_damage_mon(src, a)
		return true
	if randf() * 100.0 < dodge_chance():
		_pop(pos, "DODGE", Color("9fe8ff"))
		_fx_ring(vis_pos, Color("9fe8ff"), 1.1, 0.35, 3.0)
		msg += "   You dodge %s!" % who
		return true
	_buzz(35)
	if act_stance > 0:
		act_stance -= 1
		_pop(pos, "BLOCKED", Color("7db2ff"))
		msg += "   Iron Stance blocks %s!" % who
		_sfx("shield")
		return true
	var d := dmg_taken(a)
	var absorbed := mini(sh, d)
	sh -= absorbed
	hp -= d - absorbed
	_pop(pos, "-%d" % d, Color("ff6a6a") if absorbed < d else Color("7db2ff"))
	if absorbed > 0:
		_fx_ring(vis_pos, Color("7db2ff"), 0.9, 0.35, 5.0)
		_fx_burst(vis_pos, Color("7db2ff"), 8, 3.0, 0.4, 5.0)
	if absorbed < d:
		p_hit_t0 = t
		_fx_burst(vis_pos, Color("ff5d5d"), 10, 3.2, 0.45, 5.0)
		_shake(4.0 + minf(4.0, d * 0.3), 0.25)
	msg += "   %s hits you for %d" % [who, d]
	_sfx("spike")
	if absorbed < d or relic_n("overclock") == 0:
		tr_streak = 0
	if mons.has(src) and String(affix.get(src, "")) == "leech":
		mon_hp[src] = mini(mon_hp_max(src), mon_hp_now(src) + d)
		_pop(src, "+%d" % d, Color("ff5d8a"))
	var th := thorns_dmg()
	if th > 0 and mons.has(src):
		_adv_damage_mon(src, th)
	if hp <= 0 and _phoenix():
		return true
	if hp <= 0:
		hp = 0
		_die("%s was too strong" % who)
		return false
	return true


func _adv_spike_hurt(d: int) -> bool:
	return _adv_env_hurt(d, "Spikes! You lose %d health", "You were impaled on spikes")


func _adv_env_hurt(d: int, text: String, why: String, snd := "spike") -> bool:
	var absorbed := mini(sh, d)
	sh -= absorbed
	hp -= d - absorbed
	_pop(pos, "-%d" % d, Color("ff6a6a") if absorbed < d else Color("7db2ff"))
	if absorbed > 0:
		_fx_ring(vis_pos, Color("7db2ff"), 0.9, 0.35, 5.0)
	if absorbed < d:
		p_hit_t0 = t
		_fx_burst(vis_pos, Color("ff5d5d"), 10, 3.2, 0.45, 5.0)
		_shake(4.0, 0.25)
	msg = text % d
	_sfx(snd)
	if hp <= 0 and _phoenix():
		return true
	if hp <= 0:
		hp = 0
		_die(why)
		return state == PLAY
	return true


func _adv_damage_mon(c: Vector2i, dmg: int, col := Color("ff9a3c")) -> void:
	if not mons.has(c):
		return
	if _titan_immune(c):
		_pop(c, "SHIELDED", Color("7fe8ff"))
		return
	if hex_armed:
		hex_armed = false
		_st_get(c)["hex"] = true
		_pop(c, "HEXED", Color("c07cff"))
	if mstat.has(c) and mstat[c].has("hex"):
		dmg *= 2
	var left := mon_hp_now(c) - dmg
	_pop(c, "-%d" % dmg, col)
	_fx_hit(c, false, false)
	if left <= 0:
		adv_pts += _mon_level(c) / 2 + (25 if (boss_floor and c == boss_cell) else 0)
		_adv_gain_xp((3 + _mon_level(c)) / 2)
		_tr_on_kill(c, mon_hp_max(c))
		_kill_free(c)
	else:
		mon_hp[c] = left


# ---------------------------------------------------------------- weapon traits, monster affixes, status effects
var affix: Dictionary = {}    # Vector2i -> affix id on a monster
var mstat: Dictionary = {}    # Vector2i -> {"burn": [steps, dmg], "psn": [stacks, steps], "stun": steps, "chill": true}
var tr_streak := 0            # hits in a row without being damaged
var tr_hits := 0              # hits landed this floor (Rhythm)
var tr_last := Vector2i(-1, -1)
var tr_mark := 0              # consecutive hits on the same target
var tr_depth := 0

const TRAIT_DEFS := {
	"ignite": {"n": "Ignite", "d": "Hits set the enemy ablaze: 2+ damage a step for 3 steps", "t": ["fire"]},
	"volatile": {"n": "Volatile", "d": "Kills explode, hurting nearby enemies for 40% of the victim's HP", "t": ["fire", "kill"]},
	"static": {"n": "Static", "d": "25% chance to stun on hit (it loses its next action)", "t": ["shock"]},
	"arc": {"n": "Arc Chain", "d": "Hits arc to another enemy within 2 tiles for 50% damage", "t": ["shock"]},
	"frostbite": {"n": "Frostbite", "d": "The first hit on each enemy freezes it for a step", "t": ["cryo"]},
	"shatter": {"n": "Shatter", "d": "+50% damage to stunned or frozen enemies", "t": ["cryo", "shock"]},
	"toxin": {"n": "Toxin", "d": "Hits poison: 1 damage a step per stack, up to 4 stacks", "t": ["toxic"]},
	"plague": {"n": "Plague", "d": "Poisoned enemies spread poison to neighbours when they die", "t": ["toxic", "kill"]},
	"siphon": {"n": "Siphon", "d": "Heal 20% of the damage you deal (at least 1)", "t": ["blood"]},
	"bloodlust": {"n": "Bloodlust", "d": "Kills heal 10% of your max health", "t": ["blood", "kill"]},
	"execute": {"n": "Executioner", "d": "Enemies under 20% health die instantly (not bosses)", "t": ["execute"]},
	"brutal": {"n": "Brutal", "d": "+25% damage", "t": ["raw"]},
	"ambush": {"n": "Ambush", "d": "Double damage against enemies at full health", "t": ["raw"]},
	"sharp": {"n": "Keen Edge", "d": "+12% crit chance", "t": ["crit"]},
	"deadly": {"n": "Deadly Crits", "d": "Crits deal triple damage instead of double", "t": ["crit"]},
	"rampage": {"n": "Rampage", "d": "+1 damage per hit in a row without being hurt (max +5)", "t": ["streak"]},
	"rhythm": {"n": "Rhythm", "d": "Every 4th hit deals double damage", "t": ["streak"]},
	"marked": {"n": "Marked", "d": "Each hit on the same enemy deals +1 more (max +4)", "t": ["streak"]},
	"cleave": {"n": "Cleave", "d": "Melee hits also strike enemies beside the target for 50%", "t": ["melee"]},
	"pierce": {"n": "Pierce", "d": "Shots also hit the enemy behind the target for 60%", "t": ["ranged"]},
	"overkill": {"n": "Overkill", "d": "Excess damage on a kill carries to a nearby enemy", "t": ["kill"]},
	"bounty": {"n": "Bounty", "d": "Kills drop extra coins", "t": ["econ", "kill"]},
	"harvest": {"n": "Soul Harvest", "d": "+30% XP from kills", "t": ["econ", "kill"]},
	"adrenaline": {"n": "Adrenaline", "d": "Kills restore 3 air", "t": ["kill"]},
	"barrier": {"n": "Barrier", "d": "Kills grant +3 shield", "t": ["kill", "defense"]},
	"thorned": {"n": "Spiked", "d": "Reflect 2 damage (more on deeper floors) when hit", "t": ["defense"]},
	"duelist": {"n": "Duelist", "d": "+10% dodge chance", "t": ["defense"]},
	"tireless": {"n": "Efficient Rounds", "d": "Shots cost 1 less air", "t": ["ranged"]},
}

const AFFIX_DEFS := {
	"plated": {"n": "Plated", "d": "Takes 2+ less damage from every hit", "col": Color("9fb3d9"), "s": "plated"},
	"regen": {"n": "Regenerating", "d": "Heals 2 health every step", "col": Color("6dff9a"), "s": "regen"},
	"leech": {"n": "Leeching", "d": "Heals itself when it hits you", "col": Color("ff5d8a"), "s": "leech"},
	"spiny": {"n": "Spiny", "d": "Reflects damage back at you", "col": Color("ffb347"), "s": "spiny"},
	"frenzy": {"n": "Frenzied", "d": "Hits much harder when below half health", "col": Color("ff4a4a"), "s": "frenzy"},
	"volatile": {"n": "Bomb", "d": "Explodes when killed, hurting you if you are adjacent", "col": Color("ff8a3c"), "s": "bomb"},
	"evasive": {"n": "Evasive", "d": "20% chance to dodge your attacks", "col": Color("9fe8ff"), "s": "evasive"},
	"warded": {"n": "Immune", "d": "Immune to burn, poison and stun", "col": Color("c07cff"), "s": "immune"},
}


func gb(id: String) -> String:
	return id.get_slice("@", 0)


func gtr(id: String) -> Array:
	var out: Array = []
	if id.contains("@"):
		for s in id.get_slice("@", 1).split(","):
			if TRAIT_DEFS.has(s):
				out.append(String(s))
	return out


func wtr() -> Array:
	if mode != "adv":
		return []
	return gtr(String(equip.get("ranged" if shooting else "weapon", "")))


func has_tr(id: String) -> bool:
	return wtr().has(id)


func tag_n(tag: String) -> int:
	var n := 0
	for tid in wtr():
		if (TRAIT_DEFS[tid]["t"] as Array).has(tag):
			n += 1
	return n


func tag_kinds() -> int:
	var seen := {}
	for tid in wtr():
		for tg in TRAIT_DEFS[tid]["t"]:
			seen[tg] = true
	return seen.size()


func gname(id: String) -> String:
	return String(gear_defs[gb(id)]["name"])


func gtrait_line(id: String) -> String:
	var parts: Array[String] = []
	for tid in gtr(id):
		parts.append(String(TRAIT_DEFS[tid]["n"]))
	return " + ".join(parts)


func gprice(id: String) -> int:
	return int(gear_defs[gb(id)]["price"]) + 14 * gtr(id).size()


func _gear_desc_id(id: String) -> String:
	return _gear_desc(gear_defs[gb(id)])


func _roll_traits(rng: RandomNumberGenerator, tier: int, ranged: bool) -> String:
	var r := rng.randf() if rng != null else randf()
	var n := 0
	if tier <= 1:
		n = 1 if r < 0.4 else 0
	elif tier == 2:
		n = 0 if r < 0.25 else (1 if r < 0.8 else 2)
	elif tier == 3:
		n = 1 if r < 0.55 else (2 if r < 0.95 else 3)
	elif tier == 4:
		n = 2 if r < 0.7 else 3
	else:
		n = 2 if r < 0.4 else 3
	if n == 0:
		return ""
	var pool: Array = []
	for tid in TRAIT_DEFS:
		var tg: Array = TRAIT_DEFS[tid]["t"]
		if tg.has("ranged") and not ranged:
			continue
		if tg.has("melee") and ranged:
			continue
		if not trait_open(String(tid)):
			continue
		pool.append(String(tid))
	var picked: Array[String] = []
	while picked.size() < n and pool.size() > 0:
		var i := (rng.randi() if rng != null else randi()) % pool.size()
		picked.append(String(pool[i]))
		pool.remove_at(i)
	return "@" + ",".join(picked)


func crit_chance() -> float:
	return gear("crit") + sk("crit") + (sk("rcrit") if shooting else 0.0) + 4.0 * float(pk.get("crit", 0)) + (12.0 if has_tr("sharp") else 0.0) + 10.0 * relic_n("luckychip")


func dodge_chance() -> float:
	return gear("dodge") + sk("dodge") + (10.0 if has_tr("duelist") else 0.0)


func thorns_dmg() -> int:
	return int(gear("thorns")) + int(sk("thorns")) + ((2 + floor_n / 6) if has_tr("thorned") else 0) + 2 * relic_n("thornmail")


func _stunned(c: Vector2i) -> bool:
	return mstat.has(c) and int(mstat[c].get("stun", 0)) > 0


func _st_ok(c: Vector2i) -> bool:
	return String(affix.get(c, "")) != "warded"


func _st_get(c: Vector2i) -> Dictionary:
	if not mstat.has(c):
		mstat[c] = {}
	return mstat[c]


func _boss_cell(c: Vector2i) -> bool:
	return boss_floor and c == boss_cell


func _st_stun(c: Vector2i, steps: int) -> void:
	if not mons.has(c) or not _st_ok(c) or _boss_cell(c) or tur.has(c):
		return
	_st_get(c)["stun"] = maxi(int(_st_get(c).get("stun", 0)), steps)
	_pop(c, "STUN", Color("ffe14f"))
	_fx_ring(Vector2(c), Color("ffe14f"), 0.8, 0.3, 3.0)
	if syn("pyro", "storm") and mstat[c].has("burn"):
		_adv_damage_mon(c, 2 + level / 3, Color("ff7a45"))


func _st_burn(c: Vector2i, steps: int, dmg: int) -> void:
	if not mons.has(c) or not _st_ok(c):
		return
	var m := 2 if relic_n("pyro") > 0 and tag_n("fire") > 0 else 1
	_st_get(c)["burn"] = [steps + (2 if m > 1 else 0), dmg * m]
	_fx_burst(Vector2(c), Color("ff7a45"), 6, 2.4, 0.4, 4.0)


func _st_poison(c: Vector2i, add: int) -> void:
	if not mons.has(c) or not _st_ok(c):
		return
	var cap := 4 + (3 if relic_n("toxi") > 0 else 0)
	var cur: Array = _st_get(c).get("psn", [0, 0])
	mstat[c]["psn"] = [mini(cap, int(cur[0]) + add), 6]
	_fx_burst(Vector2(c), Color("8aff6a"), 5, 2.0, 0.4, 4.0)


func _tr_heal(n: int) -> void:
	if n <= 0:
		return
	hp = mini(hp_cap(), hp + n)
	_pop(pos, "+%d" % n, Color("ff8a9a"))


func _near_mons(c: Vector2i, r: int, exclude: Array) -> Array:
	var out: Array = []
	for m in mons:
		if m == c or exclude.has(m) or m == pos:
			continue
		if absi(m.x - c.x) <= r and absi(m.y - c.y) <= r and adv_vis.has(m):
			out.append(m)
	return out


func _tr_hit_mod(c: Vector2i, dmg: int) -> int:
	var tl := wtr()
	var add := 0
	var mul := 1.0
	if not tl.is_empty():
		if tl.has("brutal"):
			mul += 0.25
		if tl.has("ambush") and mon_hp_now(c) >= mon_hp_max(c):
			mul += 1.0
		if tl.has("shatter") and _stunned(c):
			mul += 0.5 + (0.5 if relic_n("frost") > 0 else 0.0)
		if tl.has("rampage"):
			add += mini(5 + 3 * relic_n("overclock"), tr_streak)
		if tl.has("marked"):
			add += mini(4, tr_mark if tr_last == c else 0)
		if tl.has("rhythm") and (tr_hits + 1) % 4 == 0:
			mul += 1.0
	add += mini(4, tag_kinds()) * relic_n("prism")
	if sk("finish") > 0.0 and mon_hp_now(c) * 2 <= mon_hp_max(c):
		mul += sk("finish") / 100.0
	if sk("opener") > 0.0 and mon_hp_now(c) >= mon_hp_max(c):
		mul += sk("opener") / 100.0
	var d := maxi(1, int(round(float(dmg + add) * mul)))
	if String(affix.get(c, "")) == "plated":
		d = maxi(1, d - 2 - floor_n / 8)
	if hex_armed and _st_ok(c):
		hex_armed = false
		_st_get(c)["hex"] = true
		_pop(c, "HEXED", Color("c07cff"))
	if mstat.has(c) and mstat[c].has("hex"):
		d *= 2
	return d


func _tr_on_hit(c: Vector2i, dealt: int, crit: bool, ranged: bool, left: int) -> int:
	# returns the target's remaining health after trait effects (<= 0 means dead)
	var tl := wtr()
	tr_streak += 1
	tr_hits += 1
	tr_mark = (tr_mark + 1) if tr_last == c else 1
	tr_last = c
	if relic_n("luckychip") > 0 and crit:
		oxy = minf(oxy_max, oxy + 1.0)
	if tl.is_empty() or tr_depth > 2:
		return left
	tr_depth += 1
	if tl.has("siphon"):
		_tr_heal(maxi(1, int(dealt * 0.2)) * (2 if relic_n("bloodpact") > 0 else 1))
	if left > 0:
		if tl.has("execute") and not _boss_cell(c):
			var thr := 0.2 + 0.15 * relic_n("hood")
			if float(left) <= float(mon_hp_max(c)) * thr:
				left = 0
				_pop(c, "EXECUTED", Color("ff4a4a"))
				if syn("bloodpact", "hood"):
					_tr_heal(maxi(1, hp_cap() / 10))
		if left > 0 and tl.has("ignite"):
			_st_burn(c, 3, 2 + floor_n / 6)
		if left > 0 and tl.has("static") and randf() < 0.25:
			_st_stun(c, 1 + relic_n("storm"))
		if left > 0 and tl.has("frostbite") and _st_ok(c) and not bool(_st_get(c).get("chill", false)):
			mstat[c]["chill"] = true
			_st_stun(c, 1)
		if left > 0 and tl.has("toxin"):
			_st_poison(c, 1)
	if tl.has("arc"):
		var tg := _near_mons(c, 2, [])
		var cnt := 1 + (2 if relic_n("storm") > 0 else 0)
		for i in mini(cnt, tg.size()):
			var o: Vector2i = tg[i]
			_fx_bolt(Vector2(c), Vector2(o), Color("9fe8ff"))
			if syn("storm", "toxi") and _st_ok(o):
				_st_poison(o, 1)
			_adv_damage_mon(o, maxi(1, dealt / 2), Color("9fe8ff"))
	if tl.has("cleave") and not ranged:
		for o in _near_mons(c, 1, []):
			_adv_damage_mon(o, maxi(1, dealt / 2))
	if tl.has("pierce") and ranged:
		var st := Vector2i(signi(c.x - pos.x), signi(c.y - pos.y))
		for k in range(1, 3):
			var b: Vector2i = c + st * k
			if not _aopen(b):
				break
			if mons.has(b):
				_adv_damage_mon(b, maxi(1, int(dealt * 0.6)))
				break
	if left <= 0 and tl.has("overkill"):
		var ex := -left
		if ex > 0:
			var nb := _near_mons(c, 2, [])
			if nb.size() > 0:
				_adv_damage_mon(nb[0], ex)
	tr_depth -= 1
	return left


func _tr_on_kill(c: Vector2i, mxh: int) -> void:
	var tl := wtr()
	if tr_depth <= 3:
		tr_depth += 1
		if tl.has("volatile") or String(affix.get(c, "")) == "volatile":
			if tl.has("volatile"):
				var bd := int(mxh * (0.4 + 0.2 * relic_n("pyro")))
				for o in _near_mons(c, 1, []):
					_adv_damage_mon(o, maxi(1, bd), Color("ff7a45"))
				_fx_burst(Vector2(c), Color("ff7a45"), 14, 3.4, 0.5, 5.0)
			if String(affix.get(c, "")) == "volatile" and maxi(absi(pos.x - c.x), absi(pos.y - c.y)) <= 1 and mode == "adv":
				_adv_env_hurt(maxi(1, _mon_level(c) / 2 + 1), "Bomb blast! You lose %d health", "You were caught in an explosion")
		if tl.has("plague") and mstat.has(c) and mstat[c].has("psn"):
			for o in _near_mons(c, 1, []):
				_st_poison(o, 2)
		tr_depth -= 1
	var echo := 1
	if tl.has("bloodlust"):
		_tr_heal(maxi(1, hp_cap() / 10) * echo)
	if tl.has("adrenaline"):
		oxy = minf(oxy_max, oxy + 3.0 * echo)
		_pop(pos, "+%d AIR" % (3 * echo), Color("7fd8ff"))
	if tl.has("barrier"):
		sh = mini(sh_cap(), sh + 3 * echo)
		_pop(pos, "+%d SHIELD" % (3 * echo), Color("7db2ff"))
	if tl.has("bounty"):
		var cn := (1 + floor_n / 5) * echo * coin_val()
		coins += cn
		_pop(c, "+%d coins" % cn, Color("ffc93c"))
	if sk("kcoin") > 0.0:
		coins += int(sk("kcoin"))
		_pop(c, "+%d coin" % int(sk("kcoin")), Color("ffc93c"))
	if relic_n("scrapper") > 0 and randf() < 0.35:
		coins += coin_val()
		_pop(c, "+%d coin" % coin_val(), Color("ffc93c"))


func _tr_tick() -> void:
	# end of the player's step: damage over time and status wear-off
	if mstat.is_empty() and affix.is_empty():
		return
	for c in mstat.keys():
		if not mons.has(c):
			mstat.erase(c)
			continue
		var st: Dictionary = mstat[c]
		if st.has("burn"):
			var b: Array = st["burn"]
			_adv_damage_mon(c, int(b[1]), Color("ff7a45"))
			if not mons.has(c):
				mstat.erase(c)
				continue
			b[0] = int(b[0]) - 1
			if int(b[0]) <= 0:
				st.erase("burn")
		if st.has("psn"):
			var p: Array = st["psn"]
			_adv_damage_mon(c, int(p[0]), Color("8aff6a"))
			if not mons.has(c):
				mstat.erase(c)
				continue
			p[1] = int(p[1]) - 1
			if int(p[1]) <= 0:
				st.erase("psn")
		if st.has("stun"):
			st["stun"] = int(st["stun"]) - 1
			if int(st["stun"]) <= 0:
				st.erase("stun")
	for c in affix.keys():
		if mons.has(c) and String(affix[c]) == "regen":
			var mx := mon_hp_max(c)
			var cur := mon_hp_now(c)
			if cur < mx:
				mon_hp[c] = mini(mx, cur + 2)


func _roll_affixes() -> void:
	affix.clear()
	mstat.clear()
	if floor_n < 3:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = adv_seed * 31 + floor_n * 7 + 5
	var chance := minf(0.5, 0.05 * float(floor_n - 1)) + 0.1 * relic_n("greedy")
	var ids := AFFIX_DEFS.keys()
	var keys := mons.keys()
	keys.sort_custom(func(a, b): return a.x * 1000 + a.y < b.x * 1000 + b.y)
	for c in keys:
		if c == stairs or tur.has(c) or _boss_cell(c):
			continue
		var ch := chance + (0.25 if elite.has(c) else 0.0)
		if rng.randf() < ch:
			affix[c] = String(ids[rng.randi() % ids.size()])


func _affix_name(c: Vector2i, nm: String) -> String:
	if affix.has(c):
		return String(AFFIX_DEFS[affix[c]]["n"]) + " " + nm
	return nm


# how strong the player's gear/relic build is; monsters grow tougher with it
func threat() -> int:
	return int(gear("atk")) + 2 * armor_total() + 2 * wtr().size() + skill_spent() / 2 + relic_n("prism") + relic_n("pyro") + relic_n("storm") + relic_n("toxi") + relic_n("frost") + relic_n("bloodpact") + relic_n("hood") + relic_n("echo") + relic_n("overclock")


# ---------------------------------------------------------------- skill web (Adventure): a point every 3 levels, per run
var skills: Dictionary = {}    # node id -> rank (0-2)
var skill_pts := 0
var sk_sel := ""
var sk_wind := false           # Second Wind used this floor
var sk_phx := false            # Phoenix used this run
var sk_ban_n := 0
var sk_ban_t0 := -100.0
var mom_steps := 0             # Momentum: free steps left
var sk_armed := -10.0
var sk_defs: Dictionary = {}
var sk_adj: Dictionary = {}
var sk_edges: Array = []
var btn_skill := Rect2(486, 20, 100, 46)
var btn_sk_buy := Rect2(500, 962, 180, 44)
var btn_sk_respec := Rect2(40, 1150, 310, 64)
var btn_sk_close := Rect2(380, 1150, 300, 64)
const SK_C := Vector2(360, 620)
const SK_N := 6
const SK_A0 := -75.0
const SK_BR := [
	["VITALITY", Color("ff6a5c"), [
		["Sturdy Frame", "+%s max health", "hp", [5, 10]],
		["Plating", "+%s armour", "armor", [1, 2]],
		["Field Generator", "+%s starting shield", "shield", [4, 8]],
		["Trauma Kit", "Medkits heal %s%% more", "medk", [25, 50]],
		["Spiked Plating", "Enemies that hit you take %s damage", "thorns", [1, 3]],
		["Last Stand", "Below 30%% health you take %s%% less damage", "laststand", [30, 50]]]],
	["OFFENSE", Color("ffb347"), [
		["Edge", "+%s melee attack", "atk", [1, 2]],
		["Precision", "+%s%% crit chance", "crit", [6, 12]],
		["Siphon Core", "Heal %s on every hit", "leech", [1, 2]],
		["Finisher", "+%s%% damage to enemies under half health", "finish", [25, 50]],
		["Berserker", "+%s attack while under half health", "berserk", [2, 4]],
		["Overdrive", "Crits deal %s%% more damage", "critmult", [50, 100]]]],
	["RANGED", Color("6dff9a"), [
		["Marksman", "+%s damage with ranged weapons", "rdmg", [2, 3]],
		["Deep Quiver", "+%s max ammo", "ammomax", [4, 8]],
		["Scavenger", "+%s%% chance for kills to drop ammo", "ammodrop", [20, 40]],
		["Long Barrel", "+%s shot range", "rrange", [1, 2]],
		["Hawk Eye", "+%s%% crit chance with ranged weapons", "rcrit", [10, 20]],
		["Ghost Rounds", "%s%% chance a shot uses no ammo", "noammo", [20, 40]]]],
	["FORTUNE", Color("ffd84f"), [
		["Prospector", "Coins are worth +%s each", "coin", [1, 2]],
		["Salvager", "+%s%% gear drop chance from elites and affixed enemies", "drop", [10, 20]],
		["Haggler", "Shops charge %s%% less", "haggle", [10, 20]],
		["Bounty Hunter", "Every kill drops +%s coin(s)", "kcoin", [1, 2]],
		["Alchemy", "XP potions give %s%% more XP", "pot", [25, 50]],
		["Lucky Day", "%s%% chance for a kill to give double XP", "lucky", [8, 16]]]],
	["TACTICS", Color("c07cff"), [
		["Evasion Matrix", "+%s%% dodge chance", "dodge", [5, 10]],
		["Opening Strike", "+%s%% damage to enemies at full health", "opener", [40, 80]],
		["Momentum", "After a kill your next %s step(s) cost no air", "momentum", [1, 2]],
		["Utility Belt", "+%s tool slot(s)", "slots", [1, 2]],
		["Quartermaster", "Every new floor starts with %s free random tool(s)", "quarter", [1, 2]],
		["Phoenix", "Once per run, a killing blow leaves you at %s%% health instead", "phoenix", [30, 60]]]],
	["OXYGEN", Color("7fd8ff"), [
		["Deep Lungs", "+%s max air", "air", [12, 24]],
		["Easy Breathing", "%s%% less air used per step", "airsave", [6, 12]],
		["Pod Boost", "Air pods give %s%% more air", "pod", [25, 50]],
		["Air Siphon", "Every kill restores %s air", "airkill", [1, 2]],
		["Recycler", "O2 stations also heal %s%% of max health (3 times per floor)", "stationheal", [15, 30]],
		["Second Wind", "Once per floor, running out of air gives %s air instead", "wind", [20, 40]]]],
]

func _make_skills() -> void:
	sk_defs.clear()
	sk_adj.clear()
	sk_edges.clear()
	var rr := [78.0, 147.0, 147.0, 216.0, 216.0, 280.0]
	var ph := [0.0, -11.0, 11.0, -8.0, 8.0, 0.0]
	for b in SK_N:
		var th := deg_to_rad(SK_A0 + 60.0 * b)
		var nodes: Array = SK_BR[b][2]
		for n in 6:
			var a := th + deg_to_rad(float(ph[n]))
			var nd: Array = nodes[n]
			var id := "b%dn%d" % [b, n]
			sk_defs[id] = {"b": b, "n": n, "name": nd[0], "d": nd[1], "stat": nd[2], "v": nd[3], "key": n == 5, "ring": 1 if n == 0 else (2 if n < 3 else (3 if n < 5 else 4)),
				"pos": SK_C + Vector2(cos(a), sin(a)) * float(rr[n]), "col": SK_BR[b][1]}
			sk_adj[id] = []
	for b in SK_N:
		var b2 := (b + 1) % SK_N
		for e in [[0, 1], [0, 2], [1, 3], [2, 4], [3, 5], [4, 5]]:
			_sk_link("b%dn%d" % [b, e[0]], "b%dn%d" % [b, e[1]])
		_sk_link("b%dn2" % b, "b%dn1" % b2)
		_sk_link("b%dn4" % b, "b%dn3" % b2)


func _sk_link(a: String, b: String) -> void:
	sk_edges.append([a, b])
	sk_adj[a].append(b)
	sk_adj[b].append(a)


func sk(stat: String) -> float:
	if mode != "adv" or skills.is_empty():
		return 0.0
	var tot := 0.0
	for id in skills:
		var r := int(skills[id])
		if r > 0 and sk_defs.has(id) and String(sk_defs[id]["stat"]) == stat:
			tot += float((sk_defs[id]["v"] as Array)[r - 1])
	return tot


func sk_rank(id: String) -> int:
	return int(skills.get(id, 0))


func sk_cost(id: String) -> int:
	return 2 if bool(sk_defs[id]["key"]) else 1


func skill_spent() -> int:
	var tot := 0
	for id in skills:
		if sk_defs.has(id):
			tot += int(skills[id]) * sk_cost(String(id))
	return tot


func sk_unlocked(id: String) -> bool:
	var d: Dictionary = sk_defs[id]
	if int(d["n"]) == 0:
		return true
	for o in sk_adj[id]:
		if bool(d["key"]):
			if int(sk_defs[o]["ring"]) == 3 and sk_rank(String(o)) >= 2:
				return true
		elif sk_rank(String(o)) >= 1:
			return true
	return false


func sk_can_buy(id: String) -> bool:
	return sk_rank(id) < 2 and sk_unlocked(id) and skill_pts >= sk_cost(id)


func sk_buy(id: String) -> bool:
	if not sk_defs.has(id) or not sk_can_buy(id):
		return false
	var oh := hp_cap()
	var oo := oxy_max
	skill_pts -= sk_cost(id)
	skills[id] = sk_rank(id) + 1
	_adv_apply_change(oh, oo)
	return true


func sk_respec_cost() -> int:
	return 100 + 20 * skill_spent()


func sk_respec() -> bool:
	var sp := skill_spent()
	if sp <= 0 or coins < sk_respec_cost():
		return false
	var oh := hp_cap()
	var oo := oxy_max
	coins -= sk_respec_cost()
	skill_pts += sp
	skills.clear()
	_adv_apply_change(oh, oo)
	return true


func _nfmt(v: float) -> String:
	return str(int(v)) if v == floorf(v) else str(v)


func sk_text(id: String, rank: int) -> String:
	var d: Dictionary = sk_defs[id]
	return String(d["d"]) % _nfmt(float((d["v"] as Array)[rank - 1]))


func crit_mult() -> float:
	return (3.0 if has_tr("deadly") else 2.0) + sk("critmult") / 100.0


func _phoenix() -> bool:
	if sk("phoenix") <= 0.0 or sk_phx:
		return false
	sk_phx = true
	hp = maxi(1, int(hp_cap() * sk("phoenix") / 100.0))
	_pop(pos, "PHOENIX", Color("ffb347"))
	_fx_ring(vis_pos, Color("ffb347"), 1.6, 0.6, 6.0)
	msg += "   Phoenix! You rise again"
	return true


func _oxy_dead() -> bool:
	if oxy > 0.0:
		return false
	if sk("wind") > 0.0 and not sk_wind:
		sk_wind = true
		oxy = sk("wind")
		_pop(pos, "SECOND WIND", Color("7fd8ff"))
		return false
	oxy = 0.0
	_die("You ran out of air")
	return true


func _eff_price(o: Dictionary) -> int:
	return maxi(1, int(round(float(o["price"]) * (1.0 - sk("haggle") / 100.0))))


func _skill_input(p: Vector2) -> void:
	if btn_sk_close.has_point(p):
		state = PLAY
		_sfx("ui")
		return
	if btn_sk_respec.has_point(p):
		if skill_spent() <= 0:
			_sfx("blocked")
		elif t - sk_armed < 3.0:
			if sk_respec():
				_sfx("big")
			else:
				_sfx("blocked")
			sk_armed = -10.0
		else:
			sk_armed = t
			_sfx("ui")
		return
	if sk_sel != "" and btn_sk_buy.has_point(p):
		if sk_buy(sk_sel):
			_sfx("shield")
		else:
			_sfx("blocked")
		return
	var best := ""
	var bd := 40.0
	for id in sk_defs:
		var dd: float = (sk_defs[id]["pos"] as Vector2).distance_to(p)
		if dd < bd:
			bd = dd
			best = String(id)
	if best != "":
		sk_sel = best
		_sfx("ui")


func _draw_skills(acc: Color) -> void:
	_txt("SKILL WEB", Vector2(0, 130), 52, acc)
	var nxt := (level / 3 + 1) * 3
	_txt("Points: %d      next at level %d      Coins: %d" % [skill_pts, nxt, coins], Vector2(0, 178), 26, Color("ffd84f") if skill_pts > 0 else Color(1, 1, 1, 0.7))
	for e in sk_edges:
		var pa: Vector2 = sk_defs[e[0]]["pos"]
		var pb: Vector2 = sk_defs[e[1]]["pos"]
		var on := sk_rank(String(e[0])) > 0 and sk_rank(String(e[1])) > 0
		var ec: Color = sk_defs[e[0]]["col"]
		draw_line(pa, pb, Color(ec.r, ec.g, ec.b, 0.8) if on else Color(1, 1, 1, 0.13), 3.0 if on else 2.0)
	for b in SK_N:
		var p0: Vector2 = sk_defs["b%dn0" % b]["pos"]
		var bc: Color = SK_BR[b][1]
		draw_line(SK_C, p0, Color(bc.r, bc.g, bc.b, 0.8) if sk_rank("b%dn0" % b) > 0 else Color(1, 1, 1, 0.13), 3.0)
		var th := deg_to_rad(SK_A0 + 60.0 * b)
		var lp := SK_C + Vector2(cos(th), sin(th)) * 322.0
		lp.x = clampf(lp.x, 56.0, 664.0)
		_ctext(String(SK_BR[b][0]), lp, 18, bc)
	draw_circle(SK_C, 24.0, Color("0a0c14"))
	draw_arc(SK_C, 24.0, 0.0, TAU, 24, Color(1, 1, 1, 0.5), 2.0)
	_ctext("YOU", SK_C, 15, Color(1, 1, 1, 0.75))
	for id in sk_defs:
		var d: Dictionary = sk_defs[id]
		var c: Vector2 = d["pos"]
		var col: Color = d["col"]
		var rk := sk_rank(String(id))
		var can := sk_can_buy(String(id))
		var unl := sk_unlocked(String(id))
		var rad := 31.0 if bool(d["key"]) else 24.0
		var fill := Color(col.r, col.g, col.b, 0.9 if rk >= 2 else (0.5 if rk == 1 else 0.07))
		if bool(d["key"]):
			var dp := PackedVector2Array([c + Vector2(0, -rad), c + Vector2(rad, 0), c + Vector2(0, rad), c + Vector2(-rad, 0)])
			draw_colored_polygon(dp, Color("0a0c14"))
			draw_colored_polygon(dp, fill)
			dp.append(dp[0])
			draw_polyline(dp, col if unl else Color(col.r, col.g, col.b, 0.35), 3.0)
		else:
			draw_circle(c, rad, Color("0a0c14"))
			draw_circle(c, rad, fill)
			draw_arc(c, rad, 0.0, TAU, 28, col if unl else Color(col.r, col.g, col.b, 0.35), 3.0)
		if can:
			draw_arc(c, rad + 6.0 + 2.0 * sin(t * 5.0), 0.0, TAU, 28, Color(1, 1, 1, 0.55), 2.0)
		if String(id) == sk_sel:
			draw_arc(c, rad + 10.0, 0.0, TAU, 28, Color.WHITE, 3.0)
		for k in 2:
			var pc := c + Vector2(-6.0 + 12.0 * k, rad + 11.0)
			draw_circle(pc, 3.5, col if rk > k else Color(1, 1, 1, 0.2))
	# detail panel
	_obox(Rect2(30, 956, 660, 178), Color(1, 1, 1, 0.05))
	if sk_sel == "":
		_txt("Tap a node to inspect it. Paths grow outward from the centre; the diamonds at the ends are the strongest.", Vector2(46, 1000), 20, Color(1, 1, 1, 0.6), 600.0, HORIZONTAL_ALIGNMENT_LEFT)
	else:
		var sd: Dictionary = sk_defs[sk_sel]
		var sc: Color = sd["col"]
		var srk := sk_rank(sk_sel)
		_txt(String(sd["name"]) + ("   KEYSTONE" if bool(sd["key"]) else "") + "   %d/2" % srk, Vector2(46, 992), 26, sc, 450.0, HORIZONTAL_ALIGNMENT_LEFT)
		var warn := ""
		if srk >= 2:
			_txt("MAXED", Vector2(500, 994), 28, sc, 180.0, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			_button(btn_sk_buy, ("UPGRADE  (%d pt)" % sk_cost(sk_sel)) if sk_can_buy(sk_sel) else "LOCKED", sc if sk_can_buy(sk_sel) else Color(1, 1, 1, 0.35), 19)
			if not sk_unlocked(sk_sel):
				warn = "Needs a connected node first" if not bool(sd["key"]) else "Needs an outer node at rank 2"
			elif skill_pts < sk_cost(sk_sel):
				warn = "Not enough skill points"
		var ry := 1022.0
		if warn != "":
			_txt(warn, Vector2(46, 1016), 16, Color("ff9a8a"), 450.0, HORIZONTAL_ALIGNMENT_LEFT)
			ry = 1044.0
		for rk2 in [1, 2]:
			var rtxt := "Rank %d: %s" % [rk2, sk_text(sk_sel, rk2)]
			_para(rtxt, Vector2(46, ry), 18, Color.WHITE if srk >= rk2 else Color(1, 1, 1, 0.7), 620.0)
			ry += font.get_multiline_string_size(rtxt, HORIZONTAL_ALIGNMENT_LEFT, 620.0, 18).y + 4.0
	var armed := t - sk_armed < 3.0
	var rc := sk_respec_cost()
	_button(btn_sk_respec, "TAP AGAIN: -%d" % rc if armed else "RESPEC (%d coins)" % rc, Color("ff8a8a") if armed else (Color("ffc93c") if coins >= rc and skill_spent() > 0 else Color(1, 1, 1, 0.35)), 20)
	_button(btn_sk_close, "CLOSE", acc, 24)


func _make_gear() -> void:
	gear_list = [
		{"id": "dagger", "slot": "weapon", "name": "Rusty Dagger", "tier": 1, "price": 14, "stats": {"atk": 1, "crit": 10}},
		{"id": "wrench", "slot": "weapon", "name": "Maintenance Wrench", "tier": 1, "price": 16, "stats": {"atk": 2}},
		{"id": "arcblade", "slot": "weapon", "name": "Arc Blade", "tier": 2, "price": 34, "stats": {"atk": 3, "crit": 15}},
		{"id": "plasmaaxe", "slot": "weapon", "name": "Plasma Axe", "tier": 2, "price": 38, "stats": {"atk": 4}},
		{"id": "leechfang", "slot": "weapon", "name": "Leech Fang", "tier": 2, "price": 36, "stats": {"atk": 2, "leech": 2}},
		{"id": "railspike", "slot": "weapon", "name": "Rail Spike", "tier": 3, "price": 60, "stats": {"atk": 6, "crit": 20}},
		{"id": "voidcutter", "slot": "weapon", "name": "Void Cutter", "tier": 4, "price": 90, "stats": {"atk": 8, "crit": 25, "leech": 2}},
		{"id": "visor", "slot": "helmet", "name": "Scanner Visor", "tier": 1, "price": 12, "stats": {"sight": 1}},
		{"id": "hardcap", "slot": "helmet", "name": "Hard Cap", "tier": 1, "price": 12, "stats": {"armor": 1}},
		{"id": "rebreather", "slot": "helmet", "name": "Rebreather", "tier": 2, "price": 30, "stats": {"air": 20}},
		{"id": "tachelm", "slot": "helmet", "name": "Tactical Helm", "tier": 2, "price": 34, "stats": {"armor": 1, "sight": 1, "crit": 5}},
		{"id": "scholar", "slot": "helmet", "name": "Scholar Helm", "tier": 3, "price": 55, "stats": {"xp": 25}},
		{"id": "oracle", "slot": "helmet", "name": "Oracle Mask", "tier": 3, "price": 58, "stats": {"sight": 2, "dodge": 8}},
		{"id": "jacket", "slot": "armour", "name": "Work Jacket", "tier": 1, "price": 14, "stats": {"armor": 1}},
		{"id": "scrap", "slot": "armour", "name": "Scrap Plating", "tier": 1, "price": 18, "stats": {"armor": 1, "hp": 6}},
		{"id": "kevlar", "slot": "armour", "name": "Kevlar Vest", "tier": 2, "price": 34, "stats": {"armor": 2, "hp": 6}},
		{"id": "reactive", "slot": "armour", "name": "Reactive Suit", "tier": 2, "price": 38, "stats": {"armor": 2, "thorns": 3}},
		{"id": "exo", "slot": "armour", "name": "Exo Frame", "tier": 3, "price": 62, "stats": {"armor": 3, "hp": 12}},
		{"id": "bulwark", "slot": "armour", "name": "Bulwark Rig", "tier": 4, "price": 92, "stats": {"armor": 4, "hp": 16, "shield": 6}},
		{"id": "sneakers", "slot": "boots", "name": "Quiet Sneakers", "tier": 1, "price": 14, "stats": {"airsave": 8}},
		{"id": "magboots", "slot": "boots", "name": "Mag Boots", "tier": 1, "price": 16, "stats": {"dodge": 5}},
		{"id": "jets", "slot": "boots", "name": "Jet Boots", "tier": 2, "price": 34, "stats": {"airsave": 15}},
		{"id": "grip", "slot": "boots", "name": "Grip Boots", "tier": 2, "price": 34, "stats": {"armor": 1, "dodge": 6}},
		{"id": "gravity", "slot": "boots", "name": "Gravity Boots", "tier": 3, "price": 58, "stats": {"airsave": 22, "dodge": 8}},
		{"id": "phase", "slot": "boots", "name": "Phase Boots", "tier": 4, "price": 90, "stats": {"airsave": 30, "dodge": 12}},
		{"id": "luckychip", "slot": "trinket", "name": "Lucky Chip", "tier": 1, "price": 14, "stats": {"coin": 1}},
		{"id": "battery", "slot": "trinket", "name": "Spare Battery", "tier": 1, "price": 14, "stats": {"air": 15}},
		{"id": "medpatch", "slot": "trinket", "name": "Med Patch", "tier": 2, "price": 32, "stats": {"killheal": 3}},
		{"id": "podamp", "slot": "trinket", "name": "Pod Amplifier", "tier": 2, "price": 30, "stats": {"pod": 15}},
		{"id": "ward", "slot": "trinket", "name": "Ward Emitter", "tier": 2, "price": 36, "stats": {"shield": 8}},
		{"id": "reaperchip", "slot": "trinket", "name": "Reaper Chip", "tier": 3, "price": 60, "stats": {"killheal": 6, "atk": 1}},
		{"id": "datalens", "slot": "trinket", "name": "Data Lens", "tier": 3, "price": 55, "stats": {"xp": 30}},
		{"id": "stunbaton", "slot": "weapon", "name": "Stun Baton", "tier": 1, "price": 16, "stats": {"atk": 2, "crit": 5}},
		{"id": "cutlass", "slot": "weapon", "name": "Vibro Cutlass", "tier": 2, "price": 36, "stats": {"atk": 3, "leech": 1}},
		{"id": "gravhammer", "slot": "weapon", "name": "Gravity Hammer", "tier": 2, "price": 40, "stats": {"atk": 5}},
		{"id": "ionlance", "slot": "weapon", "name": "Ion Lance", "tier": 3, "price": 62, "stats": {"atk": 6, "crit": 10, "leech": 1}},
		{"id": "katana", "slot": "weapon", "name": "Pulse Katana", "tier": 3, "price": 64, "stats": {"atk": 5, "crit": 25}},
		{"id": "singedge", "slot": "weapon", "name": "Singularity Edge", "tier": 4, "price": 95, "stats": {"atk": 9, "crit": 15, "leech": 3}},
		{"id": "novacleaver", "slot": "weapon", "name": "Nova Cleaver", "tier": 4, "price": 94, "stats": {"atk": 10, "crit": 20}},
		{"id": "weldmask", "slot": "helmet", "name": "Welder Mask", "tier": 1, "price": 13, "stats": {"sight": 1, "dodge": 4}},
		{"id": "pilothelm", "slot": "helmet", "name": "Pilot Helm", "tier": 2, "price": 32, "stats": {"air": 15, "sight": 1}},
		{"id": "riothelm", "slot": "helmet", "name": "Riot Helm", "tier": 2, "price": 36, "stats": {"armor": 2}},
		{"id": "sentinel", "slot": "helmet", "name": "Sentinel Helm", "tier": 3, "price": 56, "stats": {"armor": 2, "hp": 8}},
		{"id": "voidcrown", "slot": "helmet", "name": "Void Crown", "tier": 4, "price": 88, "stats": {"sight": 2, "xp": 30, "crit": 10}},
		{"id": "padded", "slot": "armour", "name": "Padded Vest", "tier": 1, "price": 15, "stats": {"hp": 8}},
		{"id": "riveted", "slot": "armour", "name": "Riveted Plate", "tier": 2, "price": 36, "stats": {"armor": 2, "dodge": 3}},
		{"id": "ablative", "slot": "armour", "name": "Ablative Coat", "tier": 2, "price": 36, "stats": {"armor": 1, "shield": 6, "hp": 4}},
		{"id": "titan", "slot": "armour", "name": "Titan Plate", "tier": 3, "price": 64, "stats": {"armor": 4, "hp": 8}},
		{"id": "phaseweave", "slot": "armour", "name": "Phase Weave", "tier": 3, "price": 60, "stats": {"armor": 2, "dodge": 10, "shield": 6}},
		{"id": "aegiscore", "slot": "armour", "name": "Aegis Core", "tier": 4, "price": 96, "stats": {"armor": 5, "hp": 14, "shield": 8, "thorns": 3}},
		{"id": "soles", "slot": "boots", "name": "Rubber Soles", "tier": 1, "price": 14, "stats": {"dodge": 3, "airsave": 4}},
		{"id": "spiked", "slot": "boots", "name": "Spiked Boots", "tier": 2, "price": 34, "stats": {"thorns": 3, "armor": 1}},
		{"id": "runner", "slot": "boots", "name": "Runner Boots", "tier": 2, "price": 35, "stats": {"airsave": 18}},
		{"id": "hover", "slot": "boots", "name": "Hover Treads", "tier": 3, "price": 58, "stats": {"airsave": 20, "armor": 1, "dodge": 6}},
		{"id": "warp", "slot": "boots", "name": "Warp Striders", "tier": 4, "price": 92, "stats": {"airsave": 34, "dodge": 10, "sight": 1}},
		{"id": "goldtooth", "slot": "trinket", "name": "Gold Tooth", "tier": 2, "price": 32, "stats": {"coin": 2}},
		{"id": "stimpack", "slot": "trinket", "name": "Stim Pack", "tier": 2, "price": 34, "stats": {"killheal": 2, "atk": 1}},
		{"id": "aegisemit", "slot": "trinket", "name": "Aegis Emitter", "tier": 3, "price": 56, "stats": {"shield": 12}},
		{"id": "battlecore", "slot": "trinket", "name": "Battle Core", "tier": 3, "price": 62, "stats": {"atk": 2, "crit": 10}},
		{"id": "fusioncell", "slot": "trinket", "name": "Fusion Cell", "tier": 3, "price": 56, "stats": {"air": 35}},
		{"id": "stationheart", "slot": "trinket", "name": "Station Heart", "tier": 4, "price": 95, "stats": {"hp": 20, "killheal": 4}},
		{"id": "blaster", "slot": "weapon", "name": "Blaster Pistol", "tier": 1, "price": 18, "stats": {"atk": 2, "range": 2}},
		{"id": "thornbow", "slot": "weapon", "name": "Thorn Crossbow", "tier": 2, "price": 36, "stats": {"atk": 3, "range": 3, "leech": 1}},
		{"id": "arccarbine", "slot": "weapon", "name": "Arc Carbine", "tier": 2, "price": 40, "stats": {"atk": 4, "range": 3}},
		{"id": "plasmarifle", "slot": "weapon", "name": "Plasma Rifle", "tier": 3, "price": 66, "stats": {"atk": 6, "range": 4, "crit": 10}},
		{"id": "railsniper", "slot": "weapon", "name": "Rail Sniper", "tier": 4, "price": 98, "stats": {"atk": 9, "range": 5, "crit": 20}},
		{"id": "prismblade", "slot": "weapon", "name": "Prism Blade", "tier": 3, "price": 66, "stats": {"atk": 6, "crit": 20}},
		{"id": "shardspear", "slot": "weapon", "name": "Shard Spear", "tier": 3, "price": 62, "stats": {"atk": 5, "leech": 2}},
		{"id": "scattergun", "slot": "weapon", "name": "Scatter Gun", "tier": 3, "price": 64, "stats": {"atk": 8, "range": 2}},
		{"id": "gaussrep", "slot": "weapon", "name": "Gauss Repeater", "tier": 2, "price": 42, "stats": {"atk": 4, "range": 4}},
		{"id": "targetvisor", "slot": "helmet", "name": "Targeting Visor", "tier": 3, "price": 56, "stats": {"rangeb": 1, "sight": 1}},
		{"id": "crystalhelm", "slot": "helmet", "name": "Crystal Helm", "tier": 3, "price": 58, "stats": {"armor": 3, "hp": 4}},
		{"id": "hazmask", "slot": "helmet", "name": "Hazmat Mask", "tier": 2, "price": 34, "stats": {"hazres": 40, "air": 10}},
		{"id": "crystalmail", "slot": "armour", "name": "Crystal Mail", "tier": 4, "price": 94, "stats": {"armor": 5, "hp": 12, "dodge": 4}},
		{"id": "ghillie", "slot": "armour", "name": "Ghillie Suit", "tier": 2, "price": 36, "stats": {"dodge": 10, "sight": 1}},
		{"id": "mirrorvest", "slot": "armour", "name": "Mirror Vest", "tier": 3, "price": 60, "stats": {"armor": 2, "rangedef": 2}},
		{"id": "crystaltreads", "slot": "boots", "name": "Crystal Treads", "tier": 3, "price": 58, "stats": {"airsave": 24, "dodge": 5}},
		{"id": "hazboots", "slot": "boots", "name": "Hazard Boots", "tier": 2, "price": 34, "stats": {"hazres": 50, "armor": 1}},
		{"id": "ammorecycler", "slot": "trinket", "name": "Ammo Recycler", "tier": 3, "price": 58, "stats": {"shotsave": 1}},
		{"id": "scopemod", "slot": "trinket", "name": "Scope Module", "tier": 3, "price": 56, "stats": {"rangeb": 1, "crit": 8}},
		{"id": "critoptics", "slot": "trinket", "name": "Crit Optics", "tier": 2, "price": 34, "stats": {"crit": 15, "sight": 1}},
		{"id": "overlord", "slot": "trinket", "name": "Overlord Chip", "tier": 4, "price": 96, "stats": {"atk": 3, "xp": 40}},
		{"id": "oblivion", "slot": "weapon", "name": "Oblivion Edge", "tier": 5, "price": 150, "stats": {"atk": 13, "crit": 25, "leech": 3}},
		{"id": "starmaul", "slot": "weapon", "name": "Starforged Maul", "tier": 5, "price": 148, "stats": {"atk": 16, "crit": 10}},
		{"id": "eventrail", "slot": "weapon", "name": "Event Horizon Rail", "tier": 5, "price": 156, "stats": {"atk": 12, "range": 6, "crit": 25}},
		{"id": "eclipsecrown", "slot": "helmet", "name": "Eclipse Crown", "tier": 5, "price": 148, "stats": {"armor": 3, "hp": 10, "sight": 2, "xp": 35}},
		{"id": "horizonplate", "slot": "armour", "name": "Event Horizon Plate", "tier": 5, "price": 160, "stats": {"armor": 7, "hp": 22, "shield": 10, "thorns": 4}},
		{"id": "starweave", "slot": "armour", "name": "Starweave Shroud", "tier": 5, "price": 150, "stats": {"armor": 4, "hp": 14, "dodge": 14, "shield": 8}},
		{"id": "wormhole", "slot": "boots", "name": "Wormhole Treads", "tier": 5, "price": 150, "stats": {"airsave": 42, "dodge": 14, "sight": 1, "hazres": 30}},
		{"id": "voidheart", "slot": "trinket", "name": "Void Heart", "tier": 5, "price": 152, "stats": {"hp": 26, "killheal": 6, "atk": 2}},
		{"id": "infinitylens", "slot": "trinket", "name": "Infinity Lens", "tier": 5, "price": 150, "stats": {"crit": 20, "xp": 40, "rangeb": 1}},
		{"id": "midasengine", "slot": "trinket", "name": "Midas Engine", "tier": 5, "price": 148, "stats": {"coin": 4, "xp": 30, "pod": 20}},
	]
	gear_defs.clear()
	for d in gear_list:
		if String(d["slot"]) == "weapon" and int((d["stats"] as Dictionary).get("range", 0)) > 0:
			d["slot"] = "ranged"
		gear_defs[String(d["id"])] = d


func _gear_col(slot: String) -> Color:
	var cols := {"ranged": Color("ffc24f"), "weapon": Color("ff8a4f"), "helmet": Color("4fd1ff"), "armour": Color("9fb3d9"), "boots": Color("6dff9a"), "trinket": Color("c07cff")}
	return cols.get(slot, Color.WHITE)


func _tier_col(t: int) -> Color:
	if t >= 5:
		return Color("ff6a4f")
	if t >= 4:
		return Color("ffd84f")
	if t == 3:
		return Color("d58cff")
	if t == 2:
		return Color("6fd8ff")
	return Color.WHITE


func _gear_desc(d: Dictionary) -> String:
	var labels := {
		"atk": "+%d attack", "crit": "%d%% crit chance", "leech": "heal %d per hit", "armor": "+%d armour", "hp": "+%d max HP",
		"shield": "+%d start shield", "air": "+%d max air", "airsave": "%d%% less air per step", "sight": "+%d sight",
		"xp": "+%d%% XP", "coin": "+%d per coin", "dodge": "%d%% dodge", "thorns": "%d thorns damage", "killheal": "heal %d on kill",
		"pod": "+%d air per pod", "range": "shoots %d tiles in a line, %s air per shot", "rangeb": "+%d range for ranged weapons", "shotsave": "shots cost %d less air", "rangedef": "-%d damage from enemy shots", "hazres": "%d%% less hazard damage",
	}
	var parts: Array[String] = []
	var st: Dictionary = d["stats"]
	for k in st:
		if k == "range":
			parts.append(String(labels[k]) % [int(st[k]), str(int(_tier_shot_air(int(d["tier"]))))])
		else:
			parts.append(String(labels[k]) % int(st[k]))
	return ", ".join(parts)


func _adv_roll_gear(rng: RandomNumberGenerator, bonus := 0) -> String:
	var r := rng.randf() if rng != null else randf()
	var tier := 1
	if floor_n <= 3:
		tier = 1 if r < 0.7 else 2
	elif floor_n <= 7:
		tier = 1 if r < 0.3 else (2 if r < 0.8 else 3)
	elif floor_n <= 12:
		tier = 2 if r < 0.4 else (3 if r < 0.85 else 4)
	else:
		tier = 2 if r < 0.1 else (3 if r < 0.4 else (4 if r < 0.8 else 5))
	tier = clampi(tier + bonus, 1, 5 if floor_n >= 13 else 4)
	var pool: Array = []
	for d in gear_list:
		if int(d["tier"]) == tier:
			pool.append(d)
	if pool.is_empty():
		pool = gear_list
	var idx := (rng.randi() if rng != null else randi()) % pool.size()
	var gd: Dictionary = pool[idx]
	var rid := String(gd["id"])
	if String(gd["slot"]) == "weapon" or String(gd["slot"]) == "ranged":
		rid += _roll_traits(rng, int(gd["tier"]), int((gd["stats"] as Dictionary).get("range", 0)) > 0)
	return rid


func _adv_apply_change(old_hp: int, old_ox: float) -> void:
	var nh := hp_cap()
	if nh > old_hp:
		hp += nh - old_hp
	hp = mini(hp, nh)
	oxy_max = adv_oxy_max()
	if oxy_max > old_ox:
		oxy += oxy_max - old_ox
	oxy = minf(oxy, oxy_max)


func _rand_tool() -> String:
	var ids: Array = []
	for k in use_defs.keys():
		if k != "pick":
			ids.append(k)
	return String(ids[randi() % ids.size()])


func _adv_give_gear(id: String) -> bool:
	var slot := String(gear_defs[gb(id)]["slot"])
	if not equip.has(slot) or String(equip[slot]) == "":
		var oh := hp_cap()
		var oo := oxy_max
		equip[slot] = id
		_adv_apply_change(oh, oo)
		return true
	if bag.size() >= BAG_MAX:
		return false
	bag.append(id)
	return true


func _adv_equip(id: String) -> void:
	var slot := String(gear_defs[gb(id)]["slot"])
	var oh := hp_cap()
	var oo := oxy_max
	var prev := String(equip.get(slot, ""))
	bag.erase(id)
	equip[slot] = id
	if prev != "":
		bag.append(prev)
	_adv_apply_change(oh, oo)


func _adv_unequip(slot: String) -> bool:
	if not equip.has(slot) or String(equip[slot]) == "":
		return false
	if bag.size() >= BAG_MAX:
		return false
	var oh := hp_cap()
	var oo := oxy_max
	bag.append(String(equip[slot]))
	equip.erase(slot)
	_adv_apply_change(oh, oo)
	return true


func _adv_open_trade(c: Vector2i) -> void:
	trade_med = false
	trade_cell = c
	state = TRADE
	walk.clear()
	aim = -1
	_sfx("ui")


func _trade_rect(i: int) -> Rect2:
	return Rect2(50, 296 + i * 154, 620, 146)


func _trade_input(p: Vector2) -> void:
	if trade_med:
		_med_input(p)
		return
	if btn_back.has_point(p):
		state = PLAY
		_sfx("ui")
		return
	var offers: Array = merchants.get(trade_cell, [])
	for i in offers.size():
		if _trade_rect(i).has_point(p):
			var o: Dictionary = offers[i]
			if bool(o["sold"]) or coins < _eff_price(o):
				_sfx("blocked")
				return
			if String(o["kind"]) == "gear":
				if not _adv_give_gear(String(o["id"])):
					msg = "Pack is full!"
					_sfx("blocked")
					return
			else:
				if not _give_use(String(o["id"])):
					msg = "Tool slots are full!"
					_sfx("blocked")
					return
			coins -= _eff_price(o)
			o["sold"] = true
			_sfx("coin")
			return


func _draw_trade(acc: Color) -> void:
	if trade_med:
		_draw_med_menu(acc)
		return
	_txt("OUTFITTER", Vector2(0, 220), 56, Color("ffc93c"))
	_txt("Your coins: %d      Pack: %d / %d" % [coins, bag.size(), BAG_MAX], Vector2(0, 270), 26, Color.WHITE)
	var offers: Array = merchants.get(trade_cell, [])
	for i in offers.size():
		var o: Dictionary = offers[i]
		var rr := _trade_rect(i)
		var sold := bool(o["sold"])
		var can := coins >= _eff_price(o) and not sold
		var col := Color("6dff9a") if can else Color(1, 1, 1, 0.4)
		_obox(rr, Color(col.r, col.g, col.b, 0.1))
		draw_rect(rr, col, false, 2.0)
		if String(o["kind"]) == "gear":
			var gd: Dictionary = gear_defs[gb(String(o["id"]))]
			var gc := _gear_col(String(gd["slot"]))
			_spr(_gear_tex(String(o["id"])), Vector2(rr.position.x + 56, rr.position.y + 67), 78.0)
			_txt(String(gd["name"]), Vector2(rr.position.x + 108, rr.position.y + 40), 28, _tier_col(int(gd["tier"])), 340.0, HORIZONTAL_ALIGNMENT_LEFT)
			_txt(String(gd["slot"]).to_upper() + "  T" + str(gd["tier"]), Vector2(rr.position.x + 108, rr.position.y + 62), 18, gc, 300.0, HORIZONTAL_ALIGNMENT_LEFT)
			var otr := gtrait_line(String(o["id"]))
			var dy := 86.0
			if otr != "":
				_txt(otr, Vector2(rr.position.x + 108, rr.position.y + 84), 17, Color("ffd84f"), 340.0, HORIZONTAL_ALIGNMENT_LEFT)
				dy = 108.0
			_para(_gear_desc(gd), Vector2(rr.position.x + 108, rr.position.y + dy), 17, Color(1, 1, 1, 0.8), 340.0)
		else:
			var uid := String(o["id"])
			_use_icon(uid, Vector2(rr.position.x + 56, rr.position.y + 67), 70)
			_txt(_use_name(uid), Vector2(rr.position.x + 110, rr.position.y + 50), 30, Color.WHITE, 340.0, HORIZONTAL_ALIGNMENT_LEFT)
			_para(_atext("tool_" + uid, String(use_defs[uid]["desc"])), Vector2(rr.position.x + 110, rr.position.y + 84), 19, Color(1, 1, 1, 0.75), 340.0)
		_txt("SOLD" if sold else "%d coins" % _eff_price(o), Vector2(rr.end.x - 170, rr.position.y + 76), 28, col, 150.0, HORIZONTAL_ALIGNMENT_RIGHT)
	_button(btn_back, "LEAVE", acc, 28)


func _draw_crate(ctr: Vector2, id: String, bob: float) -> void:
	var d: Dictionary = gear_defs[gb(id)]
	var csl := String(d["slot"])
	_spr(spr_gen.icon("crate_" + ("weapon" if csl == "ranged" else csl)), ctr + Vector2(0, bob), AC * 0.62)


func _draw_merchant(ctr: Vector2) -> void:
	_spr(spr_gen.icon("merchant"), ctr + Vector2(0, -AC * 0.04), AC * 0.9)
	_ctext("SHOP", ctr + Vector2(0, AC * 0.42), 12, Color("ffc93c"))


func _adv_snapshot() -> void:
	saved = {
		"mons": mons.duplicate(), "elite": elite.duplicate(), "items": items.duplicate(), "spikes": spikes.duplicate(), "haz": haz.duplicate(), "tur": tur.duplicate(),
		"coin_at": coin_at.duplicate(), "kinds": kinds.duplicate(), "thief_held": thief_held.duplicate(),
		"vaults": vaults.duplicate(), "inv": inv.duplicate(), "coins": coins,
		"level": level, "xp": xp, "hp_max": hp_max, "armor": armor, "sh": sh,
		"equip": equip.duplicate(), "bag": bag.duplicate(), "merchants": merchants.duplicate(true), "affix": affix.duplicate(), "skills": skills.duplicate(), "skill_pts": skill_pts, "ammo": ammo, "pk": pk.duplicate(), "run_kills": run_kills,
	}


func _adv_new_floor() -> void:
	cell = AC
	period = 100000
	maxd = 0
	fmod = "standard"
	adv_seed = randi()
	_adv_gen()
	_adv_snapshot()
	_adv_begin()
	_play_music(tidx())


func _adv_reset() -> void:
	mons = saved["mons"].duplicate()
	elite = saved["elite"].duplicate()
	items = saved["items"].duplicate()
	spikes = saved["spikes"].duplicate()
	haz = saved["haz"].duplicate()
	tur = saved["tur"].duplicate()
	corpses.clear()
	coin_at = saved["coin_at"].duplicate()
	kinds = saved["kinds"].duplicate()
	thief_held = saved["thief_held"].duplicate()
	vaults = saved["vaults"].duplicate()
	inv.clear()
	for it in saved["inv"]:
		inv.append(String(it))
	coins = saved["coins"]
	level = int(saved["level"])
	xp = int(saved["xp"])
	hp_max = int(saved["hp_max"])
	armor = int(saved["armor"])
	sh = int(saved["sh"])
	equip = saved["equip"].duplicate()
	bag.clear()
	for g in saved["bag"]:
		bag.append(String(g))
	merchants = saved["merchants"].duplicate(true)
	affix = saved.get("affix", {}).duplicate()
	skills = saved.get("skills", {}).duplicate()
	skill_pts = int(saved.get("skill_pts", 0))
	ammo = int(saved.get("ammo", ammo))
	run_kills = int(saved.get("run_kills", run_kills))
	pk = saved.get("pk", {}).duplicate()
	_adv_begin()


func _adv_init_run() -> void:
	arena = false
	arena_d = {}
	skills.clear()
	skill_pts = up("sp")
	pk = {}
	sk_sel = ""
	sk_phx = false
	mom_steps = 0
	level = start_lvl()
	xp = 0
	hp_max = 24 + 4 * up("suit") + 3 * (level - START_LEVEL) - (4 if cls == "gunslinger" else 0)
	armor = 1 if cls == "brute" else 0
	sh = 0
	equip.clear()
	bag.clear()
	if cls == "gunslinger":
		equip["ranged"] = "blaster"
	ammo = ammo_max() if cls == "gunslinger" else 0
	ranged_mode = false
	for i in up("kit"):
		var kid := _adv_roll_gear(null, -1)
		if not equip.has(String(gear_defs[gb(kid)]["slot"])):
			equip[String(gear_defs[gb(kid)]["slot"])] = kid
		else:
			bag.append(kid)


func xp_need() -> int:
	return 12 + 6 * level


func _adv_gain_xp(n: int) -> void:
	xp += int(round(n * (1.0 + (gear("xp") + sk("xp")) / 100.0)))
	var gained := 0
	while xp >= xp_need():
		xp -= xp_need()
		_adv_level_up(1)
		gained += 1
	if gained > 0:
		_pop(pos, "LEVEL UP! %d" % level, Color("ffd84f"))
		_sfx("big")


func _adv_relic_applied(id: String) -> void:
	if id == "vanguard":
		_adv_level_up(1)
	elif id == "glass":
		_adv_level_up(3)
	elif ["pyro", "storm", "frost", "toxi", "bloodpact", "hood"].has(id):
		hp += 4


func _adv_scaled(raw: int) -> int:
	var r := raw + int(round(0.7 * float(level - START_LEVEL)))
	if raw >= 2:
		r += (floor_n - 1) * 2 / 3
	else:
		r += (floor_n - 1) / 4
	r += relic_n("greedy")
	return maxi(1, r)


func _adv_begin() -> void:
	hp = hp_cap()
	sh = maxi(sh, (8 if start_shield() else 0) + int(gear("shield")) + int(sk("shield")))
	sk_wind = false
	shield = false
	mon_hp.clear()
	mstat.clear()
	tr_streak = 0
	tr_hits = 0
	tr_last = Vector2i(-1, -1)
	tr_mark = 0
	pos = start
	keys = 0
	boost = 0
	cloak_steps = 0
	poison_n = 0
	aim = -1
	walk.clear()
	pops.clear()
	adv_pts = 0
	adv_steps = 0
	station_uses = 0
	scan_steps = 0
	decoy_steps = 0
	rw_hist.clear()
	oxy_max = adv_oxy_max()
	oxy = oxy_max
	adv_seen.fill(0)
	cam = Vector2(pos)
	_adv_update_vis()
	state = PLAY
	if arena:
		cam = Vector2(6, 6)
		msg = "BOSS ARENA: the %s. %s" % [cur_theme()["boss"], _arena_hint()]
	elif boss_floor:
		msg = "BOSS FLOOR: the %s guards the exit" % cur_theme()["boss"]
	else:
		msg = "Explore! Collect %d points to unlock the %s" % [adv_req, cur_theme()["gate"]]
		var wr := _world_rule()
		if wr != "" and floor_n % 3 == 1:
			msg = "%s  Collect %d points to unlock the %s" % [String(WORLD_RULE_TEXT[wr]), adv_req, cur_theme()["gate"]]
	# banner at the top of the map on the first floor of each themed world
	var wrb := _world_rule()
	if wrb != "" and floor_n % 3 == 1 and not arena:
		banner_rule = wrb
		banner_t0 = t
	else:
		banner_rule = ""


func _adv_next() -> void:
	if not arena and floor_n % 3 == 0:
		arena = true
	else:
		arena = false
		floor_n += 1
	_adv_new_floor()
	for qi in int(sk("quarter")):
		_give_use(_random_use())


func _adv_update_vis() -> void:
	adv_vis.clear()
	var R := adv_vis_r()
	var q: Array[Vector2i] = [pos]
	var dist := {pos: 0}
	var head := 0
	adv_vis[pos] = true
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		var d: int = dist[c]
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var n := c + Vector2i(dx, dy)
				if not _ain(n) or dist.has(n):
					continue
				if _aopen(n):
					if d + 1 <= R:
						dist[n] = d + 1
						q.append(n)
						adv_vis[n] = true
				else:
					dist[n] = 99
					adv_vis[n] = true
	if scan_steps > 0:
		for dx in range(-scan_r, scan_r + 1):
			for dy in range(-scan_r, scan_r + 1):
				var sc := pos + Vector2i(dx, dy)
				if _ain(sc):
					adv_vis[sc] = true
	if arena:
		for ax in range(1, 12):
			for ay in range(1, 12):
				adv_vis[Vector2i(ax, ay)] = true
	for c in adv_vis:
		adv_seen[_ai(c)] = 1
	_adv_mini_update()


func _adv_mini_update() -> void:
	var img := Image.create(AW, AH, false, Image.FORMAT_RGBA8)
	var col: Color = cur_theme()["accent"]
	for x in AW:
		for y in AH:
			if adv_seen[y * AW + x] == 1 and adv_open[y * AW + x] == 1:
				img.set_pixel(x, y, Color(col.r, col.g, col.b, 0.75))
	adv_mini = ImageTexture.create_from_image(img)


func _adv_vis_mons() -> Dictionary:
	var out := {}
	for c in mons:
		if adv_vis.has(c):
			out[c] = true
	return out


func _adv_path_try(target: Vector2i, avoid_spikes: bool) -> Array[Vector2i]:
	var prev := {pos: pos}
	var q: Array[Vector2i] = [pos]
	var head := 0
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		if c == target:
			break
		for dv in dirs:
			var n: Vector2i = c + dv
			if prev.has(n) or not _aopen(n) or not _aseen(n):
				continue
			if n != target and (mons.has(n) or vaults.has(n) or (avoid_spikes and spikes.has(n))):
				continue
			prev[n] = c
			q.append(n)
	var out: Array[Vector2i] = []
	if not prev.has(target):
		return out
	var c2 := target
	while c2 != pos:
		out.push_front(c2)
		c2 = prev[c2]
	return out


func _adv_path(target: Vector2i) -> Array[Vector2i]:
	var p := _adv_path_try(target, true)
	if p.is_empty():
		p = _adv_path_try(target, false)
	return p


func _adv_kill(nc: Vector2i, nm: String, lv: int, is_boss: bool) -> void:
	run_kills += 1
	var back := 0
	if thief_held.has(nc):
		back = int(thief_held[nc])
		coins += back
	var was_elite := elite.has(nc)
	var was_affix := affix.has(nc)
	var bounty_hit := false
	if bounty_n > 0 and was_elite:
		bounty_n -= 1
		bounty_hit = true
	var ammo_got := 0
	if _weapon_range() > 0 and ammo < ammo_max() and randf() < (0.8 if was_elite else 0.5) + sk("ammodrop") / 100.0:
		var ag := 1 + (randi() % 2)
		ammo = mini(ammo_max(), ammo + ag)
		ammo_got = ag
		_pop(nc, "+%d AMMO" % ag, Color("ffc24f"))
	mom_steps += int(sk("momentum"))
	if sk("airkill") > 0.0 and oxy < oxy_max:
		oxy = minf(oxy_max, oxy + sk("airkill"))
	var mult := 1.0 + 0.5 * relic_n("blade")
	if _world_rule() == "glare":
		mult += 0.25
	if was_elite:
		mult += 1.0 + 0.5 * relic_n("slayer")
	if is_boss:
		mult += 3.0
	if affix.has(nc):
		mult += 0.4
	if has_tr("harvest"):
		mult += 0.3
	if randf() * 100.0 < sk("lucky"):
		mult += 1.0
		_pop(nc, "LUCKY!", Color("ffd84f"))
	var xg := int(round((3 + lv) * mult))
	_tr_on_kill(nc, mon_hp_max(nc))
	_remove_mon(nc)
	boost = 0
	adv_pts += lv + (2 if was_elite else 0) + (25 if is_boss else 0)
	msg = "Defeated %s! +%d XP" % [nm, xg]
	if back > 0:
		msg += "  (+%d coins back)" % back
	if ammo_got > 0:
		msg += "  +%d ammo" % ammo_got
	_pop(nc, "+%d XP" % xg, Color("6dff9a"))
	_adv_gain_xp(xg)
	var kh := int(gear("killheal"))
	if kh > 0:
		hp = mini(hp_cap(), hp + kh)
	if was_elite or is_boss or was_affix:
		if randf() < (1.0 if (is_boss or bounty_hit) else ((0.3 if was_elite else 0.12) + sk("drop") / 100.0)):
			var gid := _adv_roll_gear(null, 1 if is_boss else 0)
			if _adv_give_gear(gid):
				msg += "  Dropped: " + gname(gid) + (" [" + gtrait_line(gid) + "]" if gtr(gid).size() > 0 else "")
	if is_boss:
		coins += 10
		var it := _random_use()
		if _give_use(it):
			msg += "  +10 coins + " + _use_name(it)
		else:
			msg += "  +10 coins"
	_sfx("elite" if (was_elite or is_boss) else "win")


# returns 0 = you died, 1 = monster defeated, 2 = fight goes on
func _adv_fight(nc: Vector2i) -> int:
	_cloak_break()
	var lv: int = _mon_level(nc)
	var is_boss := boss_floor and nc == boss_cell
	var nm := _adv_mname(nc)
	if _titan_immune(nc):
		_pop(nc, "SHIELDED", Color("7fe8ff"))
		_fx_ring(Vector2(nc), Color("7fe8ff"), 1.4, 0.4, 4.0)
		msg = "The crystals shield the Titan! Break them first"
		_sfx("blocked")
		if not _adv_hurt(mon_atk(nc), nm, nc):
			return 0
		return 2
	var dmg := _tr_hit_mod(nc, p_atk())
	var crit := randf() * 100.0 < crit_chance()
	if crit:
		dmg = int(round(float(dmg) * crit_mult()))
	var missed := String(affix.get(nc, "")) == "evasive" and randf() < 0.2
	if missed:
		dmg = 0
		_pop(nc, "MISS", Color("9fe8ff"))
	else:
		_pop(nc, ("CRIT -%d" % dmg) if crit else ("-%d" % dmg), Color("ffd84f") if crit else Color.WHITE)
		_fx_hit(nc, crit)
	var left := mon_hp_now(nc) - dmg
	if not missed:
		var lk := int(gear("leech") + sk("leech"))
		if lk > 0 and hp < hp_cap():
			hp = mini(hp_cap(), hp + lk)
		left = _tr_on_hit(nc, dmg, crit, false, left)
	if left <= 0 and mons.has(nc):
		_adv_kill(nc, nm, lv, is_boss)
		return 1
	if not mons.has(nc):
		return 1
	mon_hp[nc] = left
	msg = ("%s dodges!" % nm) if missed else ("You hit %s for %d (%d/%d HP)" % [nm, dmg, left, mon_hp_max(nc)])
	_sfx("step")
	mon_lunge[nc] = [t + 0.12, Vector2(pos - nc).normalized()]
	if tur.has(nc):
		_sfx("spike")
		return 2
	if not missed and String(affix.get(nc, "")) == "spiny":
		if not _adv_env_hurt(1 + floor_n / 4, "Spiny! You lose %d health", "You were skewered by a spiny enemy"):
			return 0
	if _stunned(nc):
		msg += "  (stunned: it can't strike back)"
		return 2
	if not _adv_hurt(mon_atk(nc), nm, nc):
		return 0
	return 2


func _adv_step(nc: Vector2i, final: bool) -> void:
	var th := cur_theme()
	var snd := "step"
	var extra := 0.0
	var spike_dmg := 0
	var from_c := pos
	var haz_hit := ""
	var moved := true
	var fought := false
	var before_m := _adv_vis_mons()
	if mons.has(nc):
		if not final:
			walk.clear()
			msg = "Something blocks the way"
			_sfx("blocked")
			return
		if ranged_mode and not shooting and _weapon_range() > 0:
			if ammo > 0:
				_adv_shoot(nc)  # ranged out: the attack is a shot (ranged damage)
				return
			# out of ammo: auto-press the swap button and attack in melee
			wbox_from = ranged_mode
			wbox_t0 = Time.get_ticks_msec()
			ranged_mode = false
			_sfx("ui")
			_pop(pos, "MELEE", Color("ff8a4f"))
		var res := _adv_fight(nc)
		if res == 0:
			return
		fought = true
		snd = ""
		if res == 2 or res == 1:
			moved = false
			walk.clear()
	elif vaults.has(nc):
		if keys > 0:
			keys -= 1
			vaults.erase(nc)
			coins += 10
			_adv_gain_xp(12)
			adv_pts += 10
			var got := _random_use()
			var gm := ""
			if _give_use(got):
				gm = " + " + _use_name(got)
			msg = "Vault opened! +10 coins, +12 XP%s" % gm
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
		pick_c = nc
		pick_kind = kind
		if kind.begins_with("use_"):
			var uid := kind.substr(4)
			if _give_use(uid):
				msg = "Got %s: %s" % [_use_name(uid), _atext("tool_" + uid, String(use_defs[uid]["desc"]))]
				_pop(nc, _use_name(uid), use_defs[uid]["col"])
				adv_pts += 3
				snd = "pot"
			else:
				items[nc] = kind
				msg = "Inventory full! Select a tool and tap DROP to swap"
				snd = "blocked"
		elif kind == "key":
			keys += 1
			adv_pts += 2
			msg = "Key! Find the locked vault"
			_pop(nc, "KEY", Color("ffd84f"))
			snd = "coin"
		elif kind == "pod":
			if oxy >= oxy_max:
				items[nc] = kind
				msg = "Air is full - the pod stays for later"
			else:
				var amt := adv_pod_amt()
				oxy = minf(oxy_max, oxy + amt)
				msg = "Air pod! +%d air" % int(amt)
				_pop(nc, "+%d AIR" % int(amt), Color("7fd8ff"))
				snd = "lamp"
		elif kind == "hp":
			if hp >= hp_cap():
				items[nc] = kind
				msg = "Health is full - the medkit stays for later"
			else:
				var heal := int(hp_cap() * 0.4 * (1.0 + sk("medk") / 100.0))
				hp = mini(hp_cap(), hp + heal)
				adv_pts += 1
				msg = "Medkit! +%d HP" % heal
				_pop(nc, "+%d HP" % heal, Color("ff8a9a"))
				snd = "pot"
		elif kind == "shieldbattery":
			pk["shield"] = int(pk.get("shield", 0)) + 1
			sh = mini(sh_cap(), sh + 3)
			adv_pts += 3
			msg = "Shield Battery! +3 max shield"
			_pop(nc, "+3 MAX SHIELD", Color("9fd0ff"))
			snd = "shield"
		elif kind == "heartcell":
			hp_max += 4
			hp = mini(hp_cap(), hp + 4)
			adv_pts += 4
			msg = "Heart Cell! +4 max health"
			_pop(nc, "+4 MAX HP", Color("ff8a9a"))
			snd = "big"
		elif kind == "luckycoin":
			lucky_n += 5
			adv_pts += 2
			msg = "Lucky Coin! Your next %d coins are worth double" % lucky_n
			_pop(nc, "LUCKY", Color("ffd84f"))
			snd = "coin"
		elif kind == "bounty":
			bounty_n += 1
			adv_pts += 2
			msg = "Bounty Token! The next elite you kill drops gear"
			_pop(nc, "BOUNTY", Color("ffc93c"))
			snd = "coin"
		elif kind == "idol":
			var iv := 8  # flat: the extra-coin bonus does not apply to idols
			coins += iv
			adv_pts += 6
			msg = "Golden Idol! +%d coins" % iv
			_pop(nc, "+%d coins" % iv, Color("ffc93c"))
			snd = "big"
		elif kind == "lanternoil":
			oil_steps = 80
			adv_pts += 2
			msg = "Lantern Oil! Your light reaches 3 tiles further for 80 steps"
			_pop(nc, "+3 SIGHT", Color("ffe9a0"))
			snd = "lamp"
		elif kind == "ammocrate":
			if ammo >= ammo_max():
				items[nc] = kind
				msg = "Ammo is full - the crate stays for later"
			else:
				var ac := maxi(4, ammo_max() / 2)
				var got := mini(ac, ammo_max() - ammo)
				ammo += got
				adv_pts += 2
				msg = "Ammo crate! +%d ammo" % got
				_pop(nc, "+%d AMMO" % got, Color("ffc24f"))
				snd = "pot"
		elif kind == "shrine":
			var scost := maxi(1, int(hp_cap() * 0.15))
			if hp <= scost + 1:
				items[nc] = kind
				msg = "The shrine asks for %d health - you are too weak" % scost
				snd = "blocked"
			else:
				hp -= scost
				var sxp := maxi(5, int(round(xp_need() * 0.8)))
				adv_pts += 4
				msg = "Shrine: paid %d health for +%d XP" % [scost, sxp]
				_pop(nc, "-%d HP" % scost, Color("ff6a6a"))
				_adv_gain_xp(sxp)
				snd = "big"
		elif kind == "armor":
			armor += 1
			adv_pts += 3
			msg = "Armour plate! Every hit you take is reduced by %d" % armor_total()
			_pop(nc, "ARMOUR", Color("c9d3f0"))
			snd = "shield"
		elif kind.begins_with("gear_"):
			var gid2 := kind.substr(5)
			var gd: Dictionary = gear_defs[gb(gid2)]
			adv_pts += 2
			if _adv_give_gear(gid2):
				msg = "Found %s! %s" % [gd["name"], _gear_desc(gd)]
				for tid2 in gtr(gid2):
					msg += "   %s: %s" % [TRAIT_DEFS[tid2]["n"], TRAIT_DEFS[tid2]["d"]]
				_pop(nc, String(gd["name"]), _gear_col(String(gd["slot"])))
				snd = "big"
			else:
				items[nc] = kind
				adv_pts -= 2
				msg = "Pack is full! Sell or drop something in the BAG"
				snd = "blocked"
		elif kind == "altar":
			var acost := 4 + floor_n
			if coins < acost:
				items[nc] = kind
				msg = "Gambling Altar: it wants %d coins" % acost
				snd = "blocked"
			else:
				coins -= acost
				adv_pts += 3
				var ar := randf()
				var apaid := true
				if ar < 0.4:
					var arng := RandomNumberGenerator.new()
					arng.randomize()
					var agid := _adv_roll_gear(arng, 1)
					if _adv_give_gear(agid):
						msg = "The altar pays out: %s!" % gname(agid)
					else:
						apaid = false
				elif ar < 0.75:
					var atid := _rand_tool()
					if _give_use(atid):
						msg = "The altar pays out: %s" % String(use_defs[atid]["name"])
					else:
						apaid = false
				else:
					msg = "The altar takes %d coins and stays silent" % acost
				if not apaid:
					coins += acost
					adv_pts -= 3
					items[nc] = kind
					msg = "Your pack is full - the altar waits"
					snd = "blocked"
				else:
					_pop(nc, "-%d coins" % acost, Color("ffc93c"))
					snd = "big"
		elif kind == "trapcache":
			adv_pts += 3
			var tmsg := ""
			if randf() < 0.5:
				var tdm := mini(hp - 1, 2 + floor_n / 3)
				if tdm > 0:
					hp -= tdm
					_pop(nc, "-%d HP" % tdm, Color("ff6a6a"))
					tmsg = "A trap fires! -%d health. " % tdm
			var tcoin := 6 + floor_n
			coins += tcoin
			tmsg += "Cache: +%d coins" % tcoin
			if randf() < 0.4:
				var ttid := _rand_tool()
				if _give_use(ttid):
					tmsg += " and a %s" % String(use_defs[ttid]["name"])
			msg = tmsg
			snd = "big"
		elif kind == "pot":
			var pxp := maxi(2, int(round(xp_need() * 0.2 * pot_g() * (1.0 + sk("pot") / 100.0))))
			adv_pts += 2
			msg = "%s! +%d XP" % [th["pot"], pxp]
			_pop(nc, "+%d XP" % pxp, Color("ffd84f"))
			_adv_gain_xp(pxp)
			snd = "pot"
		elif kind == "big":
			var bxp := maxi(3, int(round(xp_need() * 0.25 * big_g() * (1.0 + sk("pot") / 100.0))))
			adv_pts += 4
			msg = "Overcharged %s! +%d XP" % [th["pot"], bxp]
			_pop(nc, "+%d XP" % bxp, Color("4fd1ff"))
			_adv_gain_xp(bxp)
			snd = "big"
		elif kind == "shield":
			sh = mini(sh_cap(), sh + 8)
			adv_pts += 2
			msg = "Shield +8! It soaks damage before your health does"
			_pop(nc, "SHIELD", Color("7db2ff"))
			snd = "shield"
		else:
			adv_pts += 2
			scan_r = 5 + lamp_amt() / 4
			scan_steps = 16
			msg = "Scanner pulse! Nearby rooms revealed"
			_pop(nc, "SCAN", Color("ffe9a0"))
			snd = "lamp"
	elif spikes.has(nc):
		var sx := spike_x()
		if sx > 0:
			spike_dmg = maxi(1, int(round(float(2 + floor_n / 2 + level / 4) * float(sx) / 2.0)))
			msg = "Spikes! They tear into you"
			snd = "spike"
		else:
			msg = "Heavy Boots shrug off the spikes"
	elif haz.has(nc):
		haz_hit = String(haz[nc])
	elif coin_at.has(nc):
		coin_at.erase(nc)
		pick_c = nc
		pick_kind = "coin"
		var cv := coin_val()
		if lucky_n > 0:
			lucky_n -= 1
			cv *= 2
		coins += cv
		adv_pts += 1
		msg = "Coin! %d total" % coins
		_pop(nc, "+%d coin" % cv, Color("ffc93c"))
		snd = "coin"
	if moved:
		pos = nc
	adv_steps += 1
	rw_hist.append([pos, hp, oxy])
	if rw_hist.size() > 9:
		rw_hist.pop_front()
	_act_tick()
	if act_free > 0:
		act_free -= 1
		oxy -= extra
	elif mom_steps > 0:
		mom_steps -= 1
		oxy -= extra
	else:
		oxy -= (1.0 - (gear("airsave") + sk("airsave")) / 100.0) + (0.5 if relic_n("glass") > 0 else 0.0) + extra
	if _world_rule() == "leak" and not _adv_in_room(pos):
		oxy -= 0.25
	if moved and corpses.has(pos) and relic_n("gravedigger") > 0 and not bool(corpses[pos].get("looted", false)):
		corpses[pos]["looted"] = true
		var lc := 2 * relic_n("gravedigger") * coin_val()
		coins += lc
		_pop(pos, "+%d loot" % lc, Color("ffc93c"))
		snd = "coin"
	if moved and stations.has(pos):
		var healed := 0
		var heal_spent := false
		if sk("stationheal") > 0.0 and hp < hp_cap():
			if station_uses < STATION_USES:
				station_uses += 1
				healed = maxi(1, int(hp_cap() * sk("stationheal") / 100.0))
				hp = mini(hp_cap(), hp + healed)
				_pop(pos, "+%d HP" % healed, Color("ff8a9a"))
			else:
				heal_spent = true
		if oxy < oxy_max - 0.5:
			msg = "O2 station: air fully restored"
			_pop(pos, "AIR FULL", Color("7fd8ff"))
			snd = "lamp"
		if healed > 0:
			msg = ("O2 station: air restored, +%d HP" if oxy < oxy_max - 0.5 else "Recycler: +%d HP") % healed
			msg += " (%d heals left on this floor)" % (STATION_USES - station_uses)
			snd = "lamp"
		elif heal_spent:
			msg += "   Recycler is spent: %d heals per floor" % STATION_USES
		oxy = oxy_max
	if scan_steps > 0:
		scan_steps -= 1
	if decoy_steps > 0:
		decoy_steps -= 1
	if oil_steps > 0:
		oil_steps -= 1
	_adv_update_vis()
	if spike_dmg > 0 and not _adv_spike_hurt(spike_dmg):
		return
	if _world_rule() == "spore" and adv_steps % 30 == 0:
		poison_n = maxi(poison_n, 3)
		poison_d = maxi(poison_d, 1)
		msg = "Spore burst! You are poisoned for a few steps"
		_pop(pos, "SPORES", Color("b6ff6a"))
	if poison_n > 0:
		poison_n -= 1
		if not _adv_env_hurt(poison_d, "Poison! You lose %d health", "You succumbed to poison", "poison"):
			return
	if moved and haz_hit != "":
		if not _adv_haz_trigger(haz_hit, nc, nc - from_c):
			return
	if _oxy_dead():
		return
	if moved and pos == stairs and not mons.has(stairs):
		if adv_pts >= adv_req and (not arena or not mons.has(boss_cell)):
			_adv_clear()
			return
		msg = "Defeat the boss first!" if arena else "Exit sealed: %d / %d points" % [adv_pts, adv_req]
		walk.clear()
		snd = "blocked"
	_thief_check()
	_adv_hunters()
	if state != PLAY:
		return
	_adv_shooters()
	if state != PLAY:
		return
	_adv_turrets()
	if state != PLAY:
		return
	_arena_tick(fought)
	if state != PLAY:
		return
	_tr_tick()
	if state != PLAY:
		return
	if not fought:
		for c in _adv_vis_mons():
			if not before_m.has(c):
				if walk.size() > 0:
					walk.clear()
				msg = "%s spotted: Lv %d, %d HP. Fighting it would cost about %d HP" % [_adv_mname(c), _mon_level(c), mon_hp_now(c), _adv_cost(c)]
				if affix.has(c):
					msg += " [%s: %s]" % [AFFIX_DEFS[affix[c]]["n"], AFFIX_DEFS[affix[c]]["d"]]
				if String(kinds.get(c, "")) == "hunter":
					msg += " (it hunts you!)"
				elif tur.has(c):
					msg += " (it fires down a 5-tile lane!)"
				elif String(kinds.get(c, "")) == "shooter":
					msg += " (it shoots from range and keeps its distance!)"
				break
	if moved and meds.has(pos) and state == PLAY:
		walk.clear()
		_adv_med_touch()
		snd = ""
	if moved and merchants.has(pos) and state == PLAY:
		_adv_open_trade(pos)
	if tutorial and state == PLAY:
		_tut_hint()
	elif state == PLAY:
		_guide_tick()
	if snd != "":
		if snd == "step" and oxy < 20.0:
			snd = "tick"
		_sfx(snd)


func _adv_move_mon(a: Vector2i, b: Vector2i) -> void:
	if mode == "adv" and boss_floor and a == boss_cell:
		boss_cell = b
	mon_slide[b] = [Vector2(a - b), t]
	if mon_hit.has(a):
		mon_hit[b] = mon_hit[a]
		mon_hit.erase(a)
	mons[b] = mons[a]
	mons.erase(a)
	if mon_hp.has(a):
		mon_hp[b] = mon_hp[a]
		mon_hp.erase(a)
	if elite.has(a):
		elite[b] = true
		elite.erase(a)
	if kinds.has(a):
		kinds[b] = kinds[a]
		kinds.erase(a)
	if thief_held.has(a):
		thief_held[b] = thief_held[a]
		thief_held.erase(a)
	if affix.has(a):
		affix[b] = affix[a]
		affix.erase(a)
	if mstat.has(a):
		mstat[b] = mstat[a]
		mstat.erase(a)


func _cloak_break() -> void:
	if cloak_steps > 0 and mode == "adv":
		cloak_steps = 0
		_pop(pos, "REVEALED", Color("9aa3c7"))


func _adv_hunters() -> void:
	var tgt := pos
	var dec := decoy_steps > 0
	if dec:
		tgt = decoy_c
	elif cloak_steps > 0:
		return
	var hs: Array[Vector2i] = []
	for c in kinds:
		if (String(kinds[c]) == "hunter" or String(kinds[c]) == "rager" or String(kinds[c]) == "drone") and mons.has(c):
			hs.append(c)
	if hs.is_empty():
		return
	var dist := _adv_bfs(tgt, 9)
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for c in hs:
		if not mons.has(c) or not dist.has(c) or _stunned(c):
			continue
		var bd: int = dist[c]
		if bd == 1:
			if dec:
				continue
			walk.clear()
			mon_lunge[c] = [t, Vector2(pos - c).normalized()]
			msg = "%s attacks!" % _adv_mname(c)
			if not _adv_hurt(mon_atk(c), _adv_mname(c), c):
				return
			continue
		if adv_steps % 2 != 0 and String(kinds[c]) != "rager":
			continue
		var bn := c
		for dv in dirs:
			var n: Vector2i = c + dv
			if dist.has(n) and int(dist[n]) < bd and n != pos and n != tgt and not (mons.has(n) or vaults.has(n)):
				bd = dist[n]
				bn = n
		if bn != c:
			_adv_move_mon(c, bn)


func _weapon_range() -> int:
	var wid := String(equip.get("ranged", ""))
	if wid == "" or not gear_defs.has(gb(wid)):
		return 0
	return int((gear_defs[gb(wid)]["stats"] as Dictionary).get("range", 0))


func _shoot_range() -> int:
	var w := _weapon_range()
	if w <= 0:
		return 0
	return w + int(gear("rangeb")) + relic_n("deadeye") + int(sk("rrange"))


func _haz_mult() -> float:
	return clampf(1.0 - gear("hazres") / 100.0 - (0.5 if relic_n("hazmat") > 0 else 0.0), 0.2, 1.0)


func _ranged_dmg(c: Vector2i) -> int:
	return maxi(1, mon_atk(c) - 2 * relic_n("plating") - int(gear("rangedef")) - int(sk("rdef")))


func _lane_ok(a: Vector2i, b: Vector2i, rg: int) -> bool:
	var d := b - a
	if (d.x != 0 and d.y != 0) or (d.x == 0 and d.y == 0):
		return false
	var n := maxi(absi(d.x), absi(d.y))
	if n > rg:
		return false
	var st := Vector2i(signi(d.x), signi(d.y))
	for i in range(1, n):
		var m: Vector2i = a + st * i
		if not _aopen(m) or mons.has(m) or vaults.has(m):
			return false
	return true


func _tier_shot_air(tier: int) -> float:
	return float(ceili(1.8 * (1.0 + 0.5 * float(tier - 1))))


func _ranged_hv() -> int:
	var b := _ranged_atk() + int(sk("rdmg"))
	if relic_n("heavyammo") > 0:
		b = int(round(float(b) * 1.5))
	return b


func _shot_cost() -> float:
	var wid := String(equip.get("ranged", ""))
	var tier := 1
	if wid != "" and gear_defs.has(gb(wid)):
		tier = int(gear_defs[gb(wid)]["tier"])
	return 1.0


func _adv_draw_shoot_lanes() -> void:
	var rg := _shoot_range()
	if rg <= 0 or aim >= 0 or not ranged_mode:
		return
	for dv in TDIRS:
		for st in range(1, rg + 1):
			var lc: Vector2i = pos + dv * st
			if not _aopen(lc) or vaults.has(lc) or not _aseen(lc):
				break
			var lr := Rect2(_actr(lc) - Vector2(AC, AC) * 0.5, Vector2(AC, AC)).grow(-6)
			draw_rect(lr, Color(1.0, 0.7, 0.3, 0.07))
			if mons.has(lc):
				break


func _adv_can_shoot(c: Vector2i) -> bool:
	var rg := _shoot_range()
	if rg <= 0 or ammo <= 0 or not mons.has(c) or not adv_vis.has(c):
		return false
	if maxi(absi(c.x - pos.x), absi(c.y - pos.y)) <= 1:
		return false
	var d := c - pos
	if (d.x != 0 and d.y != 0) or (d.x == 0 and d.y == 0):
		return false
	var n := maxi(absi(d.x), absi(d.y))
	if n > rg:
		return false
	var st := Vector2i(signi(d.x), signi(d.y))
	for i in range(1, n):
		var m: Vector2i = pos + st * i
		if not _aopen(m) or mons.has(m) or vaults.has(m):
			return false
	return true


func _adv_shoot(c: Vector2i) -> void:
	shooting = true
	_adv_shoot_do(c)
	shooting = false


func _adv_shoot_do(c: Vector2i) -> void:
	_cloak_break()
	walk.clear()
	aim = -1
	var lv := _mon_level(c)
	var nm := _adv_mname(c)
	if _titan_immune(c):
		_pop(c, "SHIELDED", Color("7fe8ff"))
		msg = "The crystals shield the Titan! Shoot the crystals"
		_sfx("blocked")
		return
	var is_boss := boss_floor and c == boss_cell
	if randf() * 100.0 < sk("noammo"):
		_pop(pos, "FREE SHOT", Color("6dff9a"))
	else:
		ammo = maxi(0, ammo - (2 if relic_n("heavyammo") > 0 else 1))
	var dmg := _tr_hit_mod(c, _ranged_hv())
	var crit := randf() * 100.0 < crit_chance()
	if crit:
		dmg = int(round(float(dmg) * crit_mult()))
	var missed := String(affix.get(c, "")) == "evasive" and randf() < 0.2
	if missed:
		dmg = 0
	p_atk_t0 = t
	p_atk_dir = Vector2(c - pos).normalized()
	_fx_bolt(Vector2(pos), Vector2(c), Color("ffb36b"))
	if missed:
		_pop(c, "MISS", Color("9fe8ff"))
	else:
		_pop(c, ("CRIT -%d" % dmg) if crit else ("-%d" % dmg), Color("ffd84f") if crit else Color.WHITE)
		_fx_hit(c, crit)
		var lk := int(gear("leech") + sk("leech"))
		if lk > 0 and hp < hp_cap():
			hp = mini(hp_cap(), hp + lk)
	var left := mon_hp_now(c) - dmg
	if not missed:
		left = _tr_on_hit(c, dmg, crit, true, left)
	if not mons.has(c):
		pass
	elif left <= 0:
		_adv_kill(c, nm, lv, is_boss)
	else:
		mon_hp[c] = left
		msg = ("%s dodges the shot!" % nm) if missed else ("You shoot %s for %d (%d/%d HP)" % [nm, dmg, left, mon_hp_max(c)])
	_sfx("shoot")
	if act_rico and dmg > 0:
		act_rico = false
		_act_ricochet(c, dmg)
	if mons.has(c) and not tur.has(c) and not is_boss:
		var kd := String(kinds.get(c, ""))
		if kd == "" or kd == "sleeper" or kd == "feeder":
			kinds[c] = "rager"
			msg += "  It charges you at full speed!"
			_sfx("aggro")
	if mons.has(c) and absi(c.x - pos.x) + absi(c.y - pos.y) == 1 and not tur.has(c):
		mon_lunge[c] = [t + 0.12, Vector2(pos - c).normalized()]
		if not _adv_hurt(mon_atk(c), nm, c):
			return
	adv_steps += 1
	rw_hist.append([pos, hp, oxy])
	if rw_hist.size() > 9:
		rw_hist.pop_front()
	_act_tick()
	oxy -= _shot_cost()
	if scan_steps > 0:
		scan_steps -= 1
	if decoy_steps > 0:
		decoy_steps -= 1
	if oil_steps > 0:
		oil_steps -= 1
	_adv_update_vis()
	if poison_n > 0:
		poison_n -= 1
		if not _adv_env_hurt(poison_d, "Poison! You lose %d health", "You succumbed to poison", "poison"):
			return
	if _oxy_dead():
		return
	_thief_check()
	_adv_hunters()
	if state != PLAY:
		return
	_adv_shooters()
	if state != PLAY:
		return
	_adv_turrets()
	if state == PLAY:
		_arena_tick(false)
	if state == PLAY:
		_tr_tick()


func _tur_ready(c: Vector2i, steps: int) -> bool:
	return int(tur[c]["v"]) == 0 or (steps + c.x + c.y) % 2 == 0


func _tur_lane(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var dv: Vector2i = TDIRS[int(tur[c]["d"])]
	for st in range(1, TUR_RANGE + 1):
		var n: Vector2i = c + dv * st
		if not _aopen(n) or vaults.has(n):
			break
		out.append(n)
		if mons.has(n):
			break
	return out


func _shooter_score(n: Vector2i) -> int:
	var d := pos - n
	var man := absi(d.x) + absi(d.y)
	if _lane_ok(n, pos, TUR_RANGE):
		return -10 + absi(man - 4)
	return mini(absi(d.x), absi(d.y)) * 3 + absi(man - 4)


func _adv_shooters() -> void:
	if cloak_steps > 0 or decoy_steps > 0:
		return
	var ss: Array[Vector2i] = []
	for c in kinds:
		if String(kinds[c]) == "shooter" and mons.has(c):
			ss.append(c)
	if ss.is_empty():
		return
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for c in ss:
		if not mons.has(c) or _stunned(c):
			continue
		if maxi(absi(pos.x - c.x), absi(pos.y - c.y)) > 9:
			continue
		if _lane_ok(c, pos, TUR_RANGE):
			if (adv_steps + c.x + c.y) % 2 == 0:
				var dvv := Vector2(pos - c).normalized()
				walk.clear()
				mon_lunge[c] = [t, dvv]
				_fx_bolt(Vector2(c) + dvv * 0.3, Vector2(pos), TUR_COLS[tidx()][1])
				_sfx("enemyshot")
				msg = "%s shoots!" % _adv_mname(c)
				if not _adv_hurt(_ranged_dmg(c), _adv_mname(c)):
					return
			continue
		if adv_steps % 2 != 1:
			continue
		var best := c
		var bs := _shooter_score(c)
		for dv in dirs:
			var n: Vector2i = c + dv
			if not _aopen(n) or mons.has(n) or vaults.has(n) or n == pos or spikes.has(n) or haz.has(n) or n == stairs or merchants.has(n) or stations.has(n) or meds.has(n):
				continue
			if absi(pos.x - n.x) + absi(pos.y - n.y) < 2:
				continue
			var sc := _shooter_score(n)
			if sc < bs:
				bs = sc
				best = n
		if best != c:
			_adv_move_mon(c, best)


func _adv_turrets() -> void:
	if cloak_steps > 0:
		return
	var ts: Array[Vector2i] = []
	for c in tur:
		if mons.has(c):
			ts.append(c)
	for c in ts:
		if not mons.has(c) or not _tur_ready(c, adv_steps):
			continue
		if not _tur_lane(c).has(pos):
			continue
		var v := int(tur[c]["v"])
		var col: Color = TUR_COLS[tidx()][v]
		var dvv: Vector2i = TDIRS[int(tur[c]["d"])]
		walk.clear()
		mon_lunge[c] = [t, Vector2(-dvv.x, -dvv.y)]
		_fx_bolt(Vector2(c) + Vector2(dvv) * 0.3, Vector2(pos), col)
		msg = "%s fires!" % _adv_mname(c)
		_sfx("turret")
		if not _adv_hurt(_ranged_dmg(c), _adv_mname(c)):
			return


func _arc_live(c: Vector2i, steps: int) -> bool:
	return (steps + c.x + c.y) % 2 == 0


func _slick_clear(n: Vector2i) -> bool:
	return _ain(n) and _aopen(n) and not mons.has(n) and not vaults.has(n) and not items.has(n) and not coin_at.has(n) and not stations.has(n) and not meds.has(n) and not merchants.has(n) and not spikes.has(n) and n != stairs


func _adv_haz_trigger(id: String, c: Vector2i, dv: Vector2i) -> bool:
	var base := 2 + floor_n / 2 + level / 4
	var hm := _haz_mult()
	if id == "arc":
		if not _arc_live(c, adv_steps):
			_fx_bolt(Vector2(c) + Vector2(0, -0.4), Vector2(c), Color("ffe14f"))
			return _adv_env_hurt(maxi(1, int(round(base * 1.5 * hm))), "Electric arc! You lose %d health", "You were electrocuted", "arc")
		msg = "The arc plate is dead. Lucky timing!"
	elif id == "breach":
		oxy = maxf(0.0, oxy - 8.0)
		msg = "Hull breach! Air vents away (-8)"
		_pop(c, "-8 AIR", Color("7fd8ff"))
		_fx_ring(Vector2(c), Color("7fd8ff"), 1.3, 0.5, 4.0)
		_sfx("breach")
		if oxy <= 0.0:
			_die("You ran out of air")
			return false
	elif id == "toxic":
		poison_n = 4
		poison_d = maxi(1, int(round(float(base) / 3.0 * hm)))
		msg = "Toxic pool! Poisoned for 4 steps (Nano Injector or a medical station cures it)"
		_pop(c, "POISON", Color("9dff6a"))
		_fx_burst(Vector2(c), Color("9dff6a"), 14, 2.5, 0.7, 5.0)
		_sfx("poison")
	elif id == "slick":
		var sl_cur := c
		var sl_n := 0
		while sl_n < 16 and dv != Vector2i.ZERO and _slick_clear(sl_cur + dv):
			sl_cur += dv
			sl_n += 1
			pos = sl_cur
			if haz.has(sl_cur) and String(haz[sl_cur]) != "slick":
				break
		if sl_n > 0:
			walk.clear()
			_adv_update_vis()
			msg = "Slippery! You slide %d tiles" % sl_n
			_pop(c, "SLIDE", Color("6fe0c8"))
			_sfx("slide")
			if haz.has(sl_cur) and String(haz[sl_cur]) != "slick":
				return _adv_haz_trigger(String(haz[sl_cur]), sl_cur, dv)
		else:
			msg = "Slick patch, but you keep your footing"
	elif id == "mine":
		haz.erase(c)
		_fx_ring(Vector2(c), Color("ff9a3c"), 2.0, 0.5, 8.0)
		_fx_burst(Vector2(c), Color("ff7a45"), 30, 5.0, 0.6, 7.0)
		_shake(7.0, 0.35)
		var near: Array[Vector2i] = []
		for mc in mons:
			if maxi(absi(mc.x - c.x), absi(mc.y - c.y)) <= 1:
				near.append(mc)
		for mc in near:
			if mons.has(mc):
				_pop(mc, "BOOM", Color("ff7a45"))
				_adv_damage_mon(mc, 5 + floor_n)
		return _adv_env_hurt(maxi(1, int(round(base * 2.0 * hm))), "Mine! It blows for %d damage", "You stepped on a mine", "boom")
	elif id == "alarm":
		haz.erase(c)
		var woke := 0
		for mc in mons.keys():
			if boss_floor and mc == boss_cell:
				continue
			if kinds.has(mc) or maxi(absi(mc.x - c.x), absi(mc.y - c.y)) > 28:
				continue
			kinds[mc] = "hunter"
			woke += 1
		msg = "ALARM! %d monsters are now hunting you" % woke
		_pop(c, "ALARM", Color("ff5d5d"))
		_fx_ring(Vector2(c), Color("ff5d5d"), 2.4, 0.7, 5.0)
		walk.clear()
		_sfx("alarm")
	elif id == "warp":
		var dest := Vector2i(-1, -1)
		for k in 40:
			var n2 := Vector2i(c.x + randi_range(-8, 8), c.y + randi_range(-8, 8))
			if not _ain(n2) or not _aopen(n2) or mons.has(n2) or vaults.has(n2) or haz.has(n2) or spikes.has(n2) or items.has(n2) or coin_at.has(n2) or merchants.has(n2) or stations.has(n2) or meds.has(n2) or n2 == stairs:
				continue
			if maxi(absi(n2.x - c.x), absi(n2.y - c.y)) < 3:
				continue
			dest = n2
			break
		if dest.x >= 0:
			_fx_ring(Vector2(c), Color("d58cff"), 1.6, 0.5, 4.0)
			pos = dest
			walk.clear()
			_adv_update_vis()
			_fx_ring(Vector2(dest), Color("7fe8ff"), 1.6, 0.5, 4.0)
			_fx_burst(Vector2(dest), Color("d58cff"), 16, 3.0, 0.6, 5.0)
			msg = "Warp pad! You are flung across the cave"
			_pop(dest, "WARP", Color("d58cff"))
		else:
			msg = "The warp pad fizzles"
		_sfx("warp")
	elif id == "shard":
		oxy = maxf(0.0, oxy - 1.0)
		_fx_burst(Vector2(c), Color("d0a8ff"), 14, 3.2, 0.6, 5.0)
		return _adv_env_hurt(maxi(1, int(round(float(base) * hm))), "Crystal shards! You lose %d health", "You were skewered by crystal", "shard")
	return true


func _adv_clear() -> void:
	if tutorial:
		_tut_map_end(true)
		return
	_lb_note(floor_n, false)
	walk.clear()
	aim = -1
	_sfx("clear")
	var bonus := int(oxy / 20.0)
	coins += bonus
	over_title = "BOSS DEFEATED" if boss_floor else "FLOOR %d CLEAR" % floor_n
	var nxt := "floor %d" % (floor_n + 1)
	if not arena and floor_n % 3 == 0:
		nxt = "BOSS ARENA"
	if arena:
		over_sub = "Air bonus +%d coins\nNext: %s" % [bonus, nxt]
	else:
		over_sub = "Points %d / %d   Air bonus +%d coins\nNext: %s" % [adv_pts, adv_req, bonus, nxt]
	relic_choices = _roll_relics(1 if boss_floor else 0)
	state = RELIC if relic_choices.size() > 0 else CLEAR


func _adv_aim_valid(id: String, c: Vector2i) -> bool:
	if not _ain(c) or not _aseen(c):
		return false
	var dd := maxi(absi(c.x - pos.x), absi(c.y - pos.y))
	if id == "blink":
		return dd <= 8 and _aopen(c) and not mons.has(c) and not vaults.has(c) and c != pos
	if id == "zap":
		return dd <= 3 and mons.has(c) and adv_vis.has(c)
	if id == "decoy":
		return dd <= 6 and _aopen(c) and not mons.has(c) and not vaults.has(c) and c != pos
	if id == "grapple":
		return _grapple_ok(c)
	return false


# Any seen tile on a straight line from you picks that direction; the hook flies until it hits an enemy or wall.
func _grapple_ok(c: Vector2i) -> bool:
	var d := c - pos
	if (d.x != 0 and d.y != 0) or (d.x == 0 and d.y == 0):
		return false
	var dv := Vector2i(signi(d.x), signi(d.y))
	return _grapple_hit(dv) - dv != pos


func _grapple_hit(dv: Vector2i) -> Vector2i:
	var c := pos
	for i in 80:
		c += dv
		if not _ain(c) or not _aopen(c) or mons.has(c) or vaults.has(c):
			return c
	return c


func _adv_aim_any(id: String) -> bool:
	for dx in range(-8, 9):
		for dy in range(-8, 9):
			if _adv_aim_valid(id, pos + Vector2i(dx, dy)):
				return true
	return false


func _med_rate() -> float:
	return 0.3 + 0.07 * float(floor_n) + 0.002 * float(floor_n * floor_n)


func _med_cost(missing: int) -> int:
	return maxi(1, int(ceil(missing * _med_rate())))


func _adv_med_touch() -> void:
	if hp_cap() - hp <= 0:
		msg = "Medical station: you are at full health"
		_sfx("blocked")
		return
	trade_med = true
	state = TRADE
	walk.clear()
	aim = -1
	_sfx("ui")


func _med_opts() -> Array:
	var out: Array = []
	var miss := hp_cap() - hp
	if miss <= 0:
		return out
	var last := 0
	for d in [["Quick patch", 0.25], ["Half repair", 0.5]]:
		var amt := mini(miss, int(ceil(hp_cap() * float(d[1]))))
		if amt > last and amt < miss:
			out.append({"name": d[0], "amt": amt})
			last = amt
	out.append({"name": "Full heal", "amt": miss})
	return out


func _med_input(p: Vector2) -> void:
	if btn_back.has_point(p):
		state = PLAY
		_sfx("ui")
		return
	var opts := _med_opts()
	for i in opts.size():
		if _trade_rect(i).has_point(p):
			var o: Dictionary = opts[i]
			var amt := int(o["amt"])
			var cost := _med_cost(amt)
			if coins < cost:
				_sfx("blocked")
				return
			coins -= cost
			hp = mini(hp_cap(), hp + amt)
			poison_n = 0
			msg = "Medical station: +%d HP for %d coins" % [amt, cost]
			_pop(pos, "+%d HP" % amt, Color("6dff9a"))
			_fx_ring(vis_pos, Color("6dff9a"), 1.4, 0.6, 5.0)
			_fx_burst(vis_pos, Color("b6ffd2"), 18, 3.0, 0.9, 5.0)
			_sfx("pot")
			return


func _draw_med_menu(acc: Color) -> void:
	_txt("MEDICAL STATION", Vector2(0, 220), 52, Color("6dff9a"))
	_txt("Your coins: %d      Health: %d / %d" % [coins, hp, hp_cap()], Vector2(0, 270), 26, Color.WHITE)
	var opts := _med_opts()
	if opts.is_empty():
		_txt("You are at full health", Vector2(0, 400), 34, Color("6dff9a"))
	for i in opts.size():
		var o: Dictionary = opts[i]
		var amt := int(o["amt"])
		var cost := _med_cost(amt)
		var rr := _trade_rect(i)
		var can := coins >= cost
		var col := Color("6dff9a") if can else Color(1, 1, 1, 0.4)
		_obox(rr, Color(col.r, col.g, col.b, 0.1))
		draw_rect(rr, col, false, 2.0)
		_spr(spr_gen.icon("medstation"), Vector2(rr.position.x + 56, rr.position.y + 67), 72.0)
		_txt("+%d HP" % amt, Vector2(rr.position.x + 110, rr.position.y + 52), 34, Color.WHITE, 300.0, HORIZONTAL_ALIGNMENT_LEFT)
		_txt(String(o["name"]), Vector2(rr.position.x + 110, rr.position.y + 82), 20, Color("6dff9a"), 300.0, HORIZONTAL_ALIGNMENT_LEFT)
		_txt("Health after: %d / %d" % [mini(hp_cap(), hp + amt), hp_cap()], Vector2(rr.position.x + 110, rr.position.y + 110), 19, Color(1, 1, 1, 0.7), 330.0, HORIZONTAL_ALIGNMENT_LEFT)
		_txt("%d coins" % cost, Vector2(rr.end.x - 170, rr.position.y + 76), 28, col, 150.0, HORIZONTAL_ALIGNMENT_RIGHT)
	_button(btn_back, "LEAVE", acc, 28)


func bomb_dmg() -> int:
	return 14 + 3 * floor_n + level


func zap_dmg() -> int:
	return 16 + 2 * floor_n + level


func _adv_use_slot(i: int) -> void:
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
		_cloak_break()
		var hit := 0
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var c := pos + Vector2i(dx, dy)
				if c == pos or not _ain(c):
					continue
				if not _aopen(c) and c.x > 0 and c.y > 0 and c.x < AW - 1 and c.y < AH - 1:
					adv_open[_ai(c)] = 1
					hit += 1
				if spikes.has(c):
					spikes.erase(c)
					hit += 1
				if haz.has(c):
					haz.erase(c)
					hit += 1
				if mons.has(c):
					_pop(c, "BOOM", Color("ff7a45"))
					_adv_damage_mon(c, bomb_dmg())
					hit += 1
		if hit == 0:
			msg = "Nothing nearby to blast"
			_sfx("blocked")
			return
		msg = "Boom! Cleared %d things" % hit
		_fx_ring(vis_pos, Color("ff9a3c"), 2.0, 0.5, 8.0)
		_fx_ring(vis_pos, Color("ffe14f"), 1.2, 0.4, 5.0)
		_fx_burst(vis_pos, Color("ff7a45"), 36, 5.5, 0.7, 8.0)
		_fx_burst(vis_pos, Color("ffe14f"), 14, 4.0, 0.5, 5.0)
		_shake(9.0, 0.4)
		_sfx("spike")
		_adv_update_vis()
	elif id == "crystal":
		oxy = minf(oxy_max, oxy + 20.0)
		_fx_ring(vis_pos, Color("7fd8ff"), 1.2, 0.5, 5.0)
		for k in 10:
			_fx_spark(vis_pos + Vector2(randf_range(-0.3, 0.3), 0.1), Vector2(randf_range(-0.4, 0.4), randf_range(-2.4, -1.0)), Color("c8f1ff"), randf_range(0.6, 1.0), randf_range(3.0, 6.0), 1.2)
		msg = "Air Canister: +20 air"
		_sfx("lamp")
	elif id == "draught":
		var dxp := maxi(5, int(round(xp_need() * 0.75)))
		_adv_gain_xp(dxp)
		_fx_burst(vis_pos, Color("6dff9a"), 18, 3.0, 0.8, 5.0)
		_fx_ring(vis_pos, Color("6dff9a"), 1.1, 0.5, 5.0)
		msg = "Elixir! +%d XP" % dxp
		_pop(pos, "+%d XP" % dxp, Color("6dff9a"))
		_sfx("boom")
	elif id == "cloak":
		if cloak_steps > 0:
			msg = "Cloak already active"
			return
		cloak_steps = 16
		walk.clear()
		_fx_burst(vis_pos, Color("9aa3c7"), 16, 2.6, 0.7, 6.0)
		msg = "Shadow Cloak: monsters cannot see you for 16 steps, or until you attack"
		_sfx("shield")
	elif id == "magnet":
		var n := 0
		for c in coin_at.keys():
			if maxi(absi(c.x - pos.x), absi(c.y - pos.y)) <= 14:
				coin_at.erase(c)
				_fx_pickup(c, "coin")
				n += 1
		if n == 0:
			msg = "No coins nearby"
			_sfx("blocked")
			return
		coins += n * coin_val()
		adv_pts += n
		msg = "Magnet! +%d coins" % (n * coin_val())
		_sfx("coin")
	elif id == "foam":
		var fc := 0
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				var c := pos + Vector2i(dx, dy)
				if spikes.has(c):
					spikes.erase(c)
					fc += 1
				if haz.has(c):
					haz.erase(c)
					fc += 1
		if fc == 0:
			msg = "Nothing to smother nearby"
			_sfx("blocked")
			return
		_fx_ring(vis_pos, Color("e8f4ff"), 2.0, 0.5, 6.0)
		_fx_burst(vis_pos, Color("e8f4ff"), 24, 3.5, 0.7, 6.0)
		msg = "Foam! Smothered %d hazards" % fc
		_pop(pos, "FOAM", Color("e8f4ff"))
		_sfx("shield")
	elif id == "frost":
		var fn := 0
		for c in mons.keys():
			if maxi(absi(c.x - pos.x), absi(c.y - pos.y)) <= 2:
				_st_stun(c, 6 if relic_n("frost") > 0 else 4)
				if _stunned(c):
					fn += 1
		if fn == 0:
			msg = "No enemy in reach"
			_sfx("blocked")
			return
		_fx_ring(vis_pos, Color("9fe8ff"), 3.0, 0.6, 6.0)
		_fx_burst(vis_pos, Color("c8f1ff"), 24, 3.5, 0.7, 6.0)
		msg = "Frost Charge: %d enemies stunned" % fn
		_sfx("lamp")
	elif id == "mirror":
		if mirror_n > 0:
			msg = "Mirror already up"
			_sfx("blocked")
			return
		mirror_n = 1
		_fx_ring(vis_pos, Color("c8f1ff"), 1.2, 0.5, 5.0)
		_fx_burst(vis_pos, Color("c8f1ff"), 12, 2.6, 0.6, 5.0)
		msg = "Mirror Shard: the next hit you take is reflected"
		_sfx("shield")
	elif id == "rewind":
		if rw_hist.size() < 4:
			msg = "Not enough history to rewind yet"
			_sfx("blocked")
			return
		var snap: Array = rw_hist[0]
		var rp: Vector2i = snap[0]
		if mons.has(rp) or vaults.has(rp) or rp == pos:
			msg = "Nothing to rewind to from here"
			_sfx("blocked")
			return
		inv.remove_at(i)
		_sfx("warp")
		_fx_burst(vis_pos, Color("c07cff"), 16, 3.0, 0.5, 5.0)
		_adv_step(rp, true)
		if state == PLAY:
			hp = maxi(hp, int(snap[1]))
			oxy = maxf(oxy, float(snap[2]))
			rw_hist.clear()
			msg = "Rewind! Back where you were 8 steps ago"
		return
	elif id == "ammopack":
		if ammo >= ammo_max():
			msg = "Ammo is already full"
			_sfx("blocked")
			return
		var ga := mini(maxi(4, ammo_max() / 2), ammo_max() - ammo)
		ammo += ga
		_fx_ring(vis_pos, Color("ffc24f"), 1.0, 0.4, 4.0)
		msg = "Ammo Pack: +%d ammo" % ga
		_pop(pos, "+%d AMMO" % ga, Color("ffc24f"))
		_sfx("pot")
	elif id == "nano":
		if hp >= hp_cap():
			msg = "Health is already full"
			_sfx("blocked")
			return
		var nh := hp_cap() - hp
		hp = hp_cap()
		poison_n = 0
		_fx_ring(vis_pos, Color("ff8a9a"), 1.2, 0.5, 5.0)
		_fx_burst(vis_pos, Color("ff8a9a"), 18, 3.0, 0.8, 5.0)
		msg = "Nano Injector: health fully restored (+%d HP)" % nh
		_pop(pos, "+%d HP" % nh, Color("ff8a9a"))
		_sfx("pot")
	elif id == "cell":
		if sh >= sh_cap():
			msg = "Shield is already full"
			_sfx("blocked")
			return
		var ns := sh_cap() - sh
		sh = sh_cap()
		_fx_ring(vis_pos, Color("7db2ff"), 1.3, 0.5, 5.0)
		_fx_burst(vis_pos, Color("9fd0ff"), 16, 3.0, 0.7, 5.0)
		msg = "Shield Cell: shield fully recharged (+%d)" % ns
		_pop(pos, "+%d SHIELD" % ns, Color("7db2ff"))
		_sfx("shield")
	elif id == "plate":
		armor += 1
		_fx_ring(vis_pos, Color("c9d3f0"), 1.0, 0.45, 5.0)
		_fx_burst(vis_pos, Color("c9d3f0"), 10, 3.0, 0.5, 5.0)
		msg = "Plating Kit: armour is now %d" % armor_total()
		_pop(pos, "+1 ARMOUR", Color("c9d3f0"))
		_sfx("shield")
	elif id == "scan":
		scan_r = 6 + lamp_amt() / 4
		scan_steps = 8
		_adv_update_vis()
		_fx_ring(vis_pos, Color("5fe0b0"), 2.4, 0.7, 4.0)
		msg = "Pulse Scanner: nearby rooms revealed"
		_pop(pos, "SCAN", Color("5fe0b0"))
		_sfx("lamp")
	elif id == "ration":
		if hp >= hp_cap() and oxy >= oxy_max:
			msg = "You are already at full health and air"
			_sfx("blocked")
			return
		var rh := mini(hp_cap() - hp, int(hp_cap() * 0.4))
		hp += rh
		oxy = minf(oxy_max, oxy + 15.0)
		_fx_burst(vis_pos, Color("ffb347"), 14, 2.6, 0.7, 5.0)
		msg = "Ration Pack: +%d HP, +15 air" % rh
		_pop(pos, "+%d HP" % rh, Color("ffb347"))
		_sfx("pot")
	else:
		if not _adv_aim_any(id):
			msg = "No valid target right now"
			_sfx("blocked")
			return
		aim = i
		msg = "%s: tap a highlighted tile (tap the tool again to cancel)" % _use_name(id)
		_sfx("ui")
		return
	inv.remove_at(i)


func _adv_aim_apply(c: Vector2i) -> void:
	var id: String = inv[aim]
	if not _adv_aim_valid(id, c):
		msg = "Not a valid target"
		_sfx("blocked")
		return
	inv.remove_at(aim)
	aim = -1
	if id == "decoy":
		decoy_c = c
		decoy_steps = 8
		msg = "Decoy placed: monsters chase it for 8 steps"
		if relic_n("storm") > 0:
			decoy_steps = 12
			var dn := 0
			for mc in mons.keys():
				if maxi(absi(mc.x - c.x), absi(mc.y - c.y)) <= 1:
					_st_stun(mc, 3)
					if _stunned(mc):
						dn += 1
			msg = "Decoy Chain: lasts 12 steps, %d enemies stunned" % dn
		_fx_ring(Vector2(c), Color("ffb347"), 1.2, 0.5, 5.0)
		_fx_burst(Vector2(c), Color("ffb347"), 12, 2.6, 0.6, 5.0)
		_sfx("lamp")
		return
	if id == "grapple":
		var gdv := Vector2i(signi(c.x - pos.x), signi(c.y - pos.y))
		var ghit := _grapple_hit(gdv)
		_sfx("warp")
		fx.append({"k": "rope", "a": Vector2(pos), "b": Vector2(ghit), "t0": t, "life": 0.5})
		_fx_burst(Vector2(ghit), Color("c9d3f0"), 8, 2.4, 0.4, 4.0)
		msg = "Grapple! Hooked %s and pulled in" % ("an enemy" if mons.has(ghit) else "the wall")
		_adv_step(ghit - gdv, true)
		return
	if id == "blink":
		_sfx("warp")
		_fx_burst(vis_pos, Color("b57cff"), 16, 3.0, 0.5, 5.0)
		_fx_ring(vis_pos, Color("b57cff"), 1.0, 0.4, 4.0)
		_adv_step(c, true)
		_fx_burst(Vector2(c), Color("b57cff"), 16, 3.0, 0.5, 5.0)
		_fx_ring(Vector2(c), Color("e6c8ff"), 1.0, 0.4, 4.0)
	elif id == "zap":
		_cloak_break()
		_pop(c, "ZAP", Color("ffe14f"))
		_fx_bolt(vis_pos, Vector2(c))
		_adv_damage_mon(c, zap_dmg())
		msg = "Zap! %d damage" % zap_dmg()
		_sfx("elite")


func _adv_swipe(d: Vector2) -> void:
	if aim >= 0:
		return
	var dv := Vector2i(int(signf(d.x)), 0) if absf(d.x) > absf(d.y) else Vector2i(0, int(signf(d.y)))
	var sc := pos + dv
	if _ain(sc):
		_adv_input(_actr(sc))


# DROP button shown beside the description of a selected tool
func _drop_rect() -> Rect2:
	var cr := _cancel_rect()
	return Rect2(cr.end.x - 152.0, cr.position.y + 4.0, 148.0, cr.size.y - 8.0)


# drop tool i on the tile you stand on; if a tool already lies here (you walked onto it with a full bag) they swap
func _adv_drop_tool(i: int) -> void:
	if i < 0 or i >= inv.size():
		return
	var id: String = inv[i]
	tool_sel = -1
	if items.has(pos) and String(items[pos]).begins_with("use_"):
		var fid := String(items[pos]).substr(4)
		inv.remove_at(i)
		if _give_use(fid):
			items[pos] = "use_" + id
			msg = "Swapped %s for %s" % [_use_name(id), _use_name(fid)]
			_pop(pos, _use_name(fid), use_defs[fid]["col"])
			_sfx("pot")
		else:
			inv.insert(i, id)
			msg = "Could not swap"
			_sfx("blocked")
		return
	var dest := Vector2i(-9, -9)
	if not items.has(pos):
		dest = pos
	else:
		for dv in TDIRS:
			var nc: Vector2i = pos + dv
			if _aopen(nc) and not items.has(nc) and not mons.has(nc) and not vaults.has(nc) and not merchants.has(nc):
				dest = nc
				break
	if dest.x < -1:
		msg = "No room to drop it here"
		_sfx("blocked")
		return
	inv.remove_at(i)
	items[dest] = "use_" + id
	msg = "Dropped %s" % _use_name(id)
	_pop(pos, "DROPPED", Color("ffb347"))
	_sfx("ui")


func _adv_input(p: Vector2) -> void:
	if tool_sel >= 0 and aim < 0 and _drop_rect().has_point(p):
		_adv_drop_tool(tool_sel)
		return
	if (tool_sel >= 0 or aim >= 0) and _cancel_rect().has_point(p):
		tool_sel = -1
		aim = -1
		msg = "Cancelled"
		_sfx("ui")
		return
	var on_slot := false
	for si in slots_n():
		if _slot_rect(si).has_point(p):
			on_slot = true
	if not on_slot:
		tool_sel = -1
	if btn_skill.has_point(p):
		state = SKILLS
		walk.clear()
		aim = -1
		sk_sel = ""
		sk_armed = -10.0
		_sfx("ui")
		return
	if btn_inv.has_point(p):
		state = INV
		walk.clear()
		aim = -1
		inv_tab = 3
		chr_sel = -1
		pack_page = 0
		inv_page = 0
		inv_scroll = 0.0
		_sfx("ui")
		return
	if _weapon_range() > 0 and p.distance_to(btn_mode.get_center()) <= btn_mode.size.x * 0.5 + 6.0:
		wbox_from = ranged_mode
		wbox_t0 = Time.get_ticks_msec()
		ranged_mode = not ranged_mode
		walk.clear()
		_sfx("ui")
		return
	if _act_rect().has_point(p):
		_act_use()
		return
	for i in slots_n():
		if _slot_rect(i).has_point(p):
			if i >= inv.size():
				return
			if aim == i or tool_sel == i:
				tool_sel = -1
				_adv_use_slot(i)
			else:
				tool_sel = i
				aim = -1
				walk.clear()
				msg = "%s: %s" % [_use_name(inv[i]), String(use_defs[inv[i]]["desc"])]
				_sfx("ui")
			return
	if p.y < 318.0 or p.y > MAPB:
		return
	var c := Vector2i(int(floor(cam.x + (p.x - AMX) / AC + 0.5)), int(floor(cam.y + (p.y - AMY) / AC + 0.5)))
	if aim >= 0:
		_adv_aim_apply(c)
		return
	if c == pos and merchants.has(pos):
		_adv_open_trade(pos)
		return
	if c == pos and meds.has(pos):
		_adv_med_touch()
		return
	if ranged_mode and mons.has(c) and _adv_can_shoot(c):
		_adv_shoot(c)
		return
	if c == pos or not _aopen(c) or not _aseen(c):
		return
	var path := _adv_path(c)
	if path.is_empty():
		msg = "No path there"
		_sfx("blocked")
		return
	walk = path
	walk_t = 0.11  # first step fires on the next frame instead of waiting out the step timer


func _adv_draw_mon(c: Vector2i, ctr: Vector2, ti: int, names: Array, acc: Color) -> void:
	var base_lv: int = mons[c]
	var lv: int = _mon_level(c)
	var kind := String(kinds.get(c, ""))
	var is_boss := boss_floor and c == boss_cell
	var oc := _adv_outcome(c)
	var mc := Color("49d17a") if oc == 0 else (Color("ffb02e") if oc == 1 else Color("ef4b55"))
	var sz := AC * (0.98 if is_boss else 0.8)
	var bob := 0.0
	ctr += _mon_off(c)
	if kind == "shard":
		_draw_shard(ctr)
		return
	if is_boss:
		draw_circle(ctr, AC * 0.55, Color(acc.r, acc.g, acc.b, 0.15 + 0.08 * sin(t * 3.0)))
		if _titan_immune(c):
			draw_arc(ctr, AC * 0.62, 0.0, TAU, 32, Color(0.5, 0.9, 1.0, 0.5 + 0.3 * sin(t * 5.0)), 4.0)
			_ctext("SHIELDED", ctr + Vector2(0, -AC * 0.62), 13, Color("7fe8ff"))
		elif arena and String(arena_d.get("kind", "")) in ["core", "titan"] and (arena_d.get("mark", []) as Array).size() > 0:
			_ctext("BLAST NEXT STEP", ctr + Vector2(0, -AC * 0.62), 13, Color("ffb04f"))
	draw_circle(ctr + Vector2(0, AC * 0.3), AC * 0.28, Color(0, 0, 0, 0.3))
	if tur.has(c):
		_draw_mon_sprite(c, ctr, ti, base_lv, false, sz * 1.08, Color.WHITE, false, -4.0, spr_gen.turret(ti, int(tur[c]["v"]), int(tur[c]["d"])))
	else:
		_draw_mon_sprite(c, ctr, ti, base_lv, is_boss, sz, _frenzy_tint(c), false, -4.0)
	if elite.has(c):
		_star(ctr + Vector2(-AC * 0.3, -AC * 0.3 + bob), AC * 0.16, Color("ffd84f"))
	if affix.has(c):
		_aff_pill(ctr + Vector2(AC * 0.48, AC * 0.1), String(affix[c]), int(AC * 0.17), true)
	if mstat.has(c):
		var sx2 := -AC * 0.12
		for sk in ["burn", "psn", "stun"]:
			if mstat[c].has(sk):
				var sc2 := Color("ff7a45") if sk == "burn" else (Color("8aff6a") if sk == "psn" else Color("ffe14f"))
				draw_circle(ctr + Vector2(sx2, -AC * 0.42), AC * 0.07, sc2)
				sx2 += AC * 0.16
		if int(mstat[c].get("stun", 0)) > 0:
			draw_arc(ctr, AC * 0.46, 0.0, TAU, 20, Color(1, 0.88, 0.3, 0.7), 2.0)
	var bp := ctr + Vector2(AC * 0.3, -AC * 0.3)
	draw_circle(bp, AC * 0.17, Color("0a0c14"))
	draw_circle(bp, AC * 0.145, mc)
	_ctext(str(dmg_taken(mon_atk(c))), bp, int(AC * 0.22), Color.WHITE)
	var hpn := mon_hp_now(c)
	var hpm := mon_hp_max(c)
	var bw := AC * 0.7
	var bx := ctr.x - bw * 0.5
	var by := ctr.y + AC * 0.36
	draw_rect(Rect2(bx - 1, by - 1, bw + 2, 11), Color(0, 0, 0, 0.75))
	draw_rect(Rect2(bx, by, bw * clampf(float(hpn) / float(hpm), 0.0, 1.0), 9), Color("e8505b"))
	_ctext("%d" % hpn, Vector2(ctr.x, by + 4.5), 10, Color.WHITE)
	var rgw := _shoot_range()
	if rgw > 0 and ranged_mode and adv_vis.has(c):
		if _adv_can_shoot(c):
			var rc := Color(1.0, 0.7, 0.3, 0.55 + 0.3 * sin(t * 7.0))
			draw_arc(ctr, AC * 0.5, 0.0, TAU, 28, rc, 2.5)
			draw_line(ctr + Vector2(-AC * 0.58, 0), ctr + Vector2(-AC * 0.4, 0), rc, 2.5)
			draw_line(ctr + Vector2(AC * 0.4, 0), ctr + Vector2(AC * 0.58, 0), rc, 2.5)
			draw_line(ctr + Vector2(0, -AC * 0.58), ctr + Vector2(0, -AC * 0.4), rc, 2.5)
			draw_line(ctr + Vector2(0, AC * 0.4), ctr + Vector2(0, AC * 0.58), rc, 2.5)
			_ctext("SHOOT  %d ammo" % ammo, ctr + Vector2(0, AC * 0.56), 11, Color("ffcf8a"))
		elif maxi(absi(c.x - pos.x), absi(c.y - pos.y)) <= rgw:
			var dc := Color(1.0, 0.7, 0.3, 0.3)
			for qa in 4:
				draw_arc(ctr, AC * 0.5, qa * PI * 0.5 + 0.25, qa * PI * 0.5 + 0.9, 6, dc, 2.0)
			_ctext("in range: line up" if ammo > 0 else "out of ammo", ctr + Vector2(0, AC * 0.56), 11, Color(1, 0.8, 0.5, 0.5))
	var mk := ctr + Vector2(-AC * 0.3, AC * 0.2)
	if kind == "turret":
		var rdy := _tur_ready(c, adv_steps + 1)
		var tcol: Color = TUR_COLS[ti][int(tur[c]["v"])]
		_ctext("fires" if rdy else "reload", ctr + Vector2(0, -AC * 0.47), 12, tcol if rdy else Color(1, 1, 1, 0.55))
	elif kind == "shooter":
		_spr(spr_gen.gear_icon("blaster", "weapon"), ctr + Vector2(AC * 0.3, AC * 0.12), AC * 0.46)
		var scol: Color = TUR_COLS[ti][1]
		var srd := _lane_ok(c, pos, TUR_RANGE) and (adv_steps + 1 + c.x + c.y) % 2 == 0
		_ctext("shoots" if srd else "aims", ctr + Vector2(0, -AC * 0.47), 12, scol if srd else Color(1, 1, 1, 0.6))
	elif kind == "hunter" or kind == "rager" or kind == "drone":
		draw_circle(mk, AC * 0.13, Color("a01824") if kind == "rager" else Color("6a1218"))
		_ctext("!!" if kind == "rager" else "!", mk, int(AC * 0.26), Color("ff7a7a"))
		if kind == "drone":
			_ctext("heals her", ctr + Vector2(0, -AC * 0.47), 12, Color("6dff9a"))
		else:
			_ctext("hunts" if kind == "hunter" else "CHARGES", ctr + Vector2(0, -AC * 0.47), 12, Color("ff7a7a") if kind == "hunter" else Color("ff4a4a"))
	elif kind == "thief":
		draw_circle(mk, AC * 0.13, Color("5a4500"))
		_ctext("$", mk, int(AC * 0.24), Color("ffd84f"))
		if thief_held.has(c):
			_ctext("holds %d" % int(thief_held[c]), ctr + Vector2(0, -AC * 0.47), 12, Color("ff7a7a"))


func _draw_corpse(ctr: Vector2, c: Vector2i) -> void:
	var cp: Dictionary = corpses[c]
	var tex: Texture2D = spr_gen.corpse(int(cp["ti"]), int(cp["lv"]), bool(cp["boss"]), int(cp["tv"]), int(cp["td"]), int(cp["fl"]))
	var sz := AC * (0.98 if bool(cp["boss"]) else 0.84)
	_spr(tex, ctr + Vector2(0, AC * 0.04), sz)


func _adv_draw_lanes(ti: int) -> void:
	for sc2 in kinds:
		if String(kinds[sc2]) == "shooter" and mons.has(sc2) and adv_vis.has(sc2) and _lane_ok(sc2, pos, TUR_RANGE):
			var scc: Color = TUR_COLS[ti][1]
			draw_line(_actr(sc2), _actr(pos), Color(scc.r, scc.g, scc.b, 0.35 + 0.2 * sin(t * 8.0)), 3.0)
	for tc in tur:
		if not mons.has(tc) or not _aseen(tc):
			continue
		var rdy := _tur_ready(tc, adv_steps + 1)
		var col: Color = TUR_COLS[ti][int(tur[tc]["v"])]
		var al := (0.16 + 0.08 * sin(t * 6.0)) if rdy else 0.06
		for lc in _tur_lane(tc):
			if not _aseen(lc):
				continue
			var lr := Rect2(_actr(lc) - Vector2(AC, AC) * 0.5, Vector2(AC, AC)).grow(-4)
			draw_rect(lr, Color(col.r, col.g, col.b, al))
			if rdy:
				draw_rect(lr, Color(col.r, col.g, col.b, 0.35), false, 2.0)


func _draw_hazard(ctr: Vector2, c: Vector2i) -> void:
	var id := String(haz[c])
	var tex: Texture2D = spr_gen.icon("haz_" + id)
	var ph := float(c.x * 7 + c.y * 3)
	var sz := AC * 0.9
	if id == "arc":
		var live := _arc_live(c, adv_steps + 1)
		if live:
			draw_circle(ctr, AC * 0.5, Color(1, 0.88, 0.3, 0.12 + 0.08 * sin(t * 14.0)))
			_spr(tex, ctr, sz)
			for i in 3:
				var a := t * 9.0 + i * 2.1 + ph
				var p1 := ctr + Vector2(cos(a), sin(a)) * AC * 0.15
				var p2 := ctr + Vector2(cos(a + 0.9), sin(a * 1.3)) * AC * 0.42
				draw_line(p1, p2, Color(1, 1, 0.7, 0.9), 2.0)
		else:
			_spr_ex(tex, ctr, sz, Color(0.45, 0.45, 0.55, 1.0), 1.0, 0.0, 1.0, 1.0)
	elif id == "breach":
		draw_circle(ctr, AC * 0.46, Color(0.5, 0.85, 1.0, 0.07))
		_spr(tex, ctr, sz)
		for i in 4:
			var q := fmod(t * 0.9 + i * 0.25 + ph, 1.0)
			var a2 := ph + i * 1.7 + q * 2.0
			var rr := AC * 0.5 * (1.0 - q)
			draw_circle(ctr + Vector2(cos(a2), sin(a2)) * rr * 0.9, 2.2, Color(0.8, 0.95, 1.0, q))
	elif id == "toxic":
		_spr(tex, ctr, sz)
		for i in 3:
			var q := fmod(t * 0.6 + i * 0.33 + ph, 1.0)
			var bp := ctr + Vector2((i - 1) * AC * 0.2 + sin(t * 2.0 + i) * 4.0, AC * 0.1 - q * AC * 0.55)
			draw_arc(bp, 2.0 + q * 3.0, 0, TAU, 8, Color(0.7, 1.0, 0.6, sin(q * PI) * 0.8), 1.5)
	elif id == "slick":
		_spr(tex, ctr, sz)
		var sh2 := fmod(t * 0.7 + ph, 1.0)
		draw_line(ctr + Vector2(-AC * 0.35 + sh2 * AC * 0.7, -AC * 0.2), ctr + Vector2(-AC * 0.25 + sh2 * AC * 0.7, AC * 0.2), Color(1, 1, 1, sin(sh2 * PI) * 0.6), 3.0)
	elif id == "mine":
		_spr(tex, ctr, sz * 0.9)
		var on := fmod(t * 1.4 + ph, 1.0) < 0.25
		if on:
			draw_circle(ctr + Vector2(0, 2), AC * 0.12, Color(1, 0.3, 0.3, 0.55))
			draw_circle(ctr + Vector2(0, 2), AC * 0.05, Color(1, 0.85, 0.85, 1))
	elif id == "warp":
		draw_circle(ctr, AC * 0.46, Color(0.7, 0.5, 1.0, 0.08 + 0.05 * sin(t * 3.0 + ph)))
		_spr(tex, ctr, sz)
		draw_arc(ctr, AC * 0.3, t * 2.5 + ph, t * 2.5 + ph + PI * 1.2, 14, Color(0.9, 0.8, 1.0, 0.8), 2.0)
		draw_arc(ctr, AC * 0.18, -t * 3.5 + ph, -t * 3.5 + ph + PI * 1.2, 10, Color(0.5, 0.95, 1.0, 0.8), 2.0)
	elif id == "shard":
		_spr(tex, ctr, sz)
		_glint(ctr + Vector2(AC * 0.05, -AC * 0.25), AC * 0.2, ph)
	else:
		_spr(tex, ctr, sz)
		var on2 := fmod(t * 2.0 + ph, 1.0) < 0.5
		var lc2 := Color(1, 0.3, 0.3, 0.9) if on2 else Color(0.5, 0.1, 0.1, 0.9)
		draw_circle(ctr + Vector2(-AC * 0.3, -AC * 0.34), 4.0, lc2)
		draw_circle(ctr + Vector2(AC * 0.3, -AC * 0.34), 4.0, lc2)


func _draw_med(ctr: Vector2) -> void:
	var pc := Color("6dff9a")
	var fl := 0.5 + 0.5 * sin(t * 2.4)
	draw_circle(ctr, AC * 0.58, Color(pc.r, pc.g, pc.b, 0.06 + 0.04 * fl))
	draw_circle(ctr, AC * 0.44, Color(pc.r, pc.g, pc.b, 0.10 + 0.05 * fl))
	_spr(spr_gen.icon("medstation"), ctr, AC * 0.85)
	for bi in 3:
		var ph := fmod(t * 0.5 + bi * 0.33, 1.0)
		var bp := Vector2(ctr.x + (bi - 1) * AC * 0.22, ctr.y + AC * 0.1 - ph * AC * 0.55)
		var ba := sin(ph * PI) * 0.8
		var ar := AC * 0.05
		draw_rect(Rect2(bp.x - ar * 0.4, bp.y - ar, ar * 0.8, ar * 2.0), Color(0.7, 1.0, 0.8, ba))
		draw_rect(Rect2(bp.x - ar, bp.y - ar * 0.4, ar * 2.0, ar * 0.8), Color(0.7, 1.0, 0.8, ba))


func _draw_station(ctr: Vector2) -> void:
	var pc := Color("7fd8ff")
	var fl := 0.5 + 0.5 * sin(t * 3.0)
	var flick := 0.85 + 0.15 * sin(t * 17.0) * sin(t * 5.3)
	draw_circle(ctr, AC * 0.6, Color(pc.r, pc.g, pc.b, 0.06 * flick))
	draw_circle(ctr, AC * 0.46, Color(pc.r, pc.g, pc.b, (0.12 + 0.06 * fl) * flick))
	_spr(spr_gen.icon("station"), ctr, AC * 0.85)
	draw_arc(ctr, AC * 0.4, t * 1.6, t * 1.6 + PI * 0.7, 14, Color(0.9, 0.97, 1.0, 0.75), 2.5)
	draw_arc(ctr, AC * 0.4, t * 1.6 + PI, t * 1.6 + PI * 1.7, 14, Color(0.9, 0.97, 1.0, 0.75), 2.5)
	for bi in 6:
		var ph := fmod(t * 0.45 + bi * 0.167, 1.0)
		var bp := Vector2(ctr.x + sin(bi * 2.3 + t) * AC * 0.18, ctr.y + AC * 0.15 - ph * AC * 0.6)
		var ba := sin(ph * PI) * 0.75
		draw_arc(bp, 1.8 + (bi % 3) * 0.9, 0, TAU, 8, Color(0.85, 0.97, 1.0, ba), 1.3)


func _draw_pod(ctr: Vector2, s: float) -> void:
	_spr(spr_gen.icon("pod"), ctr, s)


func _adv_draw() -> void:
	var ti := tidx()
	var th := cur_theme()
	var acc: Color = th["accent"]
	var names: Array = th["mons"]
	draw_rect(Rect2(0, 0, 720, 1280.0 + adv_ex), th["dark"])
	_map_begin()
	var mlist: Array = []
	var wall_set: Array = _wall_set(ti)
	var rx := int(ceil(360.0 / AC)) + 1
	var ry := int(ceil(maxf(AMY - 318.0, 1280.0 + adv_ex - AMY) / AC)) + 2
	var x0 := int(floor(cam.x)) - rx
	var y0 := int(floor(cam.y)) - ry
	for cx in range(x0, x0 + 2 * rx + 2):
		for cy in range(y0, y0 + 2 * ry + 2):
			var c := Vector2i(cx, cy)
			if not _aseen(c):
				continue
			var ctr := _actr(c)
			if ctr.y < 260.0 or ctr.y > 1280.0 + adv_ex + 70.0 or ctr.x < -60.0 or ctr.x > 780.0:
				continue
			var r := Rect2(ctr - Vector2(AC, AC) * 0.5, Vector2(AC, AC))
			var vis := adv_vis.has(c)
			if not _aopen(c):
				draw_texture_rect(wall_set[_wall_var(cx, cy)], r.grow(-1.0), false)
				var wfa := _fog_a(c, 0.6)
				if wfa > 0.01:
					draw_rect(r, Color(0, 0, 0, wfa))
				continue
			draw_texture_rect(_floor_tex(ti, (cx + cy) & 1, _tile_var(cx, cy)), r.grow(-1.0), false)
			var bob := sin(t * 3.0 + cx * 1.7 + cy) * 2.0
			if c == stairs:
				var ok := adv_pts >= adv_req
				var dc := Color("6dff9a") if ok else Color(1, 1, 1, 0.45)
				var hw := AC * 0.28
				var hh := AC * 0.38
				var dk := clampf((t - door_t0) / 0.6, 0.0, 1.0)
				if ok:
					var pulse := 0.5 + 0.5 * sin(t * 2.4)
					draw_circle(ctr, AC * 0.56, Color(0.4, 1.0, 0.6, 0.08 + 0.07 * pulse))
					for ri in 5:
						var rang := -PI / 2.0 + (ri - 2) * 0.3
						var rl := AC * (0.52 + 0.12 * sin(t * 3.0 + ri))
						draw_line(ctr + Vector2.from_angle(rang) * AC * 0.2, ctr + Vector2.from_angle(rang) * rl, Color(0.6, 1.0, 0.75, 0.22), 3.0)
					if dk < 1.0:
						_spr(spr_gen.icon("door_locked"), ctr, AC * 0.92, Color(1, 1, 1, 1.0 - dk))
						_spr(spr_gen.icon("door_open"), ctr, AC * (0.92 + 0.14 * sin(dk * PI)), Color(1, 1, 1, dk))
					else:
						_spr(spr_gen.icon("door_open"), ctr, AC * 0.92)
					for si in 4:
						var sph := fmod(t * 0.6 + si * 0.25, 1.0)
						draw_circle(ctr + Vector2((si - 1.5) * AC * 0.11, AC * 0.28 - sph * AC * 0.7), 2.2, Color(0.7, 1.0, 0.8, sin(sph * PI) * 0.8))
				else:
					_spr(spr_gen.icon("door_locked"), ctr, AC * 0.92)
					if fmod(t, 1.4) < 0.18:
						draw_circle(ctr + Vector2(0, -AC * 0.42), 3.5, Color(1, 0.3, 0.3, 0.9))
				_ctext("EXIT" if ok else "%d" % adv_req, ctr + Vector2(0, AC * 0.1), int(AC * 0.2), dc)
			elif stations.has(c):
				_draw_station(ctr)
			elif meds.has(c):
				_draw_med(ctr)
			elif merchants.has(c):
				_draw_merchant(ctr)
			elif vaults.has(c):
				_draw_vault(ctr + Vector2(0, bob * 0.3))
			elif items.has(c):
				var kind2: String = items[c]
				draw_circle(ctr + Vector2(0, AC * 0.25), AC * 0.2, Color(0, 0, 0, 0.25))
				if kind2.begins_with("use_"):
					_use_icon(kind2.substr(4), ctr + Vector2(0, bob), AC * 0.55)
				elif kind2 == "key":
					_draw_key(ctr + Vector2(0, bob), AC * 0.8)
				elif kind2 == "pod":
					_draw_pod(ctr + Vector2(0, bob), AC * 0.7)
				elif kind2.begins_with("gear_"):
					_draw_crate(ctr, kind2.substr(5), bob)
				elif kind2 == "hp" or kind2 == "armor":
					_spr(_item_tex(kind2), ctr + Vector2(0, bob), AC * 0.56)
				else:
					_spr(_item_tex(kind2), ctr + Vector2(0, bob), AC * 0.58)
				_glint(ctr + Vector2(AC * 0.2, -AC * 0.2 + bob), AC * 0.16, float(cx * 3 + cy * 5))
			elif spikes.has(c):
				_draw_spikes(ctr)
			elif haz.has(c):
				_draw_hazard(ctr, c)
			elif coin_at.has(c):
				_draw_coin(ctr, bob, AC * 0.42, float(cx * 5 + cy * 3))
			if corpses.has(c) and not mons.has(c) and c != stairs:
				_draw_corpse(ctr, c)
			if vis and mons.has(c):
				mlist.append([c, ctr])
			var ffa := _fog_a(c, 0.55)
			if ffa > 0.01:
				draw_rect(r, Color(0, 0, 0, ffa))
	_adv_draw_lanes(ti)
	_adv_draw_shoot_lanes()
	if decoy_steps > 0:
		_use_icon("decoy", _actr(decoy_c), AC * 0.5)
	_arena_draw_under()
	mlist.sort_custom(func(a, b): return a[1].y < b[1].y)
	for mm2 in mlist:
		_adv_draw_mon(mm2[0], mm2[1], ti, names, acc)
	_amb_draw(Rect2(0, 318, 720, MAPB - 318.0), ti)
	if aim >= 0 and aim < inv.size():
		var aid: String = inv[aim]
		for dx in range(-8, 9):
			for dy in range(-8, 9):
				var ac := pos + Vector2i(dx, dy)
				if _adv_aim_valid(aid, ac):
					var ar := Rect2(_actr(ac) - Vector2(AC, AC) * 0.5, Vector2(AC, AC)).grow(-3)
					draw_rect(ar, Color(1, 0.88, 0.3, 0.15 + 0.1 * sin(t * 8.0)))
					draw_rect(ar, Color("ffe14f"), false, 3.0)
	var prc := _wp(vis_pos) + _p_off()
	var lf := 1.0 + 0.04 * sin(t * 7.0) * sin(t * 3.1)
	for hi in 5:
		draw_circle(prc, AC * (1.3 - hi * 0.2) * lf, Color(1.0, 0.95, 0.8, 0.014))
	draw_circle(prc + Vector2(0, AC * 0.3), AC * 0.25, Color(0, 0, 0, 0.35))
	if sh > 0:
		draw_arc(prc, AC * 0.46, 0, TAU, 28, Color(0.5, 0.7, 1.0, 0.5 + 0.2 * sin(t * 5.0)), 3.0)
	if boost > 0:
		draw_arc(prc, AC * 0.52, 0, TAU, 28, Color(0.7, 0.72, 0.9, 0.5), 2.0)
	if scan_steps > 0:
		draw_arc(prc, AC * (1.0 + 0.4 * sin(t * 6.0)), 0, TAU, 32, Color(1, 0.9, 0.6, 0.4), 2.0)
	_draw_player(prc, AC * 0.9)
	_fx_draw()
	for pp in pops:
		var age: float = t - float(pp["t"])
		if age < 0.0:
			continue
		var pcol: Color = pp["c"]
		pcol.a = clampf((POP_LIFE - age) / 0.5, 0.0, 1.0)
		var pc2: Vector2 = _actr(pp["cell"])
		_ctext(pp["s"], pc2 + Vector2(0, -AC * 0.3 - age * 40.0), 26, pcol)
	_map_end()
	# frame: cover everything outside the map window, then HUD
	draw_rect(Rect2(0, 0, 720, 318), th["bg"])
	draw_rect(Rect2(0, MAPB, 720, 250), Color(th["bg"].r, th["bg"].g, th["bg"].b, 0.3))
	draw_line(Vector2(0, 318), Vector2(720, 318), Color(acc.r, acc.g, acc.b, 0.5), 2.0)
	for s in stars:
		if float(s[1]) < 318.0 or float(s[1]) > MAPB:
			var a := 0.12 + 0.28 * (0.5 + 0.5 * sin(t * 1.5 + float(s[2])))
			var sz: float = s[3]
			draw_rect(Rect2(float(s[0]), float(s[1]), sz, sz), Color(acc.r, acc.g, acc.b, a))
	# minimap
	var mm := Rect2(8, 326, 134, 134)
	draw_rect(mm, Color(0, 0, 0, 0.7))
	draw_rect(mm, Color(acc.r, acc.g, acc.b, 0.6), false, 2.0)
	if adv_mini != null:
		draw_texture_rect(adv_mini, Rect2(mm.position + Vector2(3, 3), Vector2(128, 128)), false)
	var msc := 128.0 / float(AW)
	if _aseen(stairs):
		draw_rect(Rect2(mm.position.x + 3 + stairs.x * msc - 1, mm.position.y + 3 + stairs.y * msc - 1, 5, 5), Color("6dff9a") if adv_pts >= adv_req else Color("ff8a8a"))
	for stc in stations:
		if _aseen(stc):
			draw_rect(Rect2(mm.position.x + 3 + stc.x * msc - 1, mm.position.y + 3 + stc.y * msc - 1, 4, 4), Color("7fd8ff"))
	for mdc in meds:
		if _aseen(mdc):
			draw_rect(Rect2(mm.position.x + 3 + mdc.x * msc - 1, mm.position.y + 3 + mdc.y * msc - 1, 4, 4), Color("6dff9a"))
	draw_rect(Rect2(mm.position.x + 3 + pos.x * msc - 2, mm.position.y + 3 + pos.y * msc - 2, 5, 5), Color.WHITE)
	# HUD
	_button(btn_inv, "MENU", acc)
	_button(btn_skill, "SKILLS", Color("ffd84f") if skill_pts > 0 else acc, 19)
	if skill_pts > 0:
		draw_circle(btn_skill.position + Vector2(btn_skill.size.x - 6, 6), 13.0, Color("ff5d5d"))
		_ctext(str(skill_pts), btn_skill.position + Vector2(btn_skill.size.x - 6, 6), 16, Color.WHITE)
	var xpf := clampf(float(xp) / float(xp_need()), 0.0, 1.0)
	draw_rect(Rect2(40, 245, 240, 11), Color(1, 1, 1, 0.14))
	draw_rect(Rect2(40, 245, 240.0 * xpf, 11), Color("ffd84f"))
	_txt("XP %d/%d" % [xp, xp_need()], Vector2(288, 256), 14, Color("ffd84f"), 100.0, HORIZONTAL_ALIGNMENT_LEFT)
	_hud_panels(acc, 124.0)
	_wbox_draw()
	_sk_banner()
	_txt("LV %d" % level, Vector2(40, 205), 72, Color.WHITE, 300.0, HORIZONTAL_ALIGNMENT_LEFT)
	_txt("COINS %d   BANK %d" % [coins, bank], Vector2(40, 238), 24, Color("ffc93c"), 330.0, HORIZONTAL_ALIGNMENT_LEFT)
	_adv_badges()
	var low := oxy < oxy_max * 0.25
	var acol := Color("3d9bff") if low else Color("7fd8ff")
	_txt("AIR %d" % int(ceil(oxy)), Vector2(360, 192), 38, acol, 320.0, HORIZONTAL_ALIGNMENT_RIGHT)
	draw_rect(Rect2(380, 200, 300, 12), Color(1, 1, 1, 0.12))
	draw_rect(Rect2(380, 200, 300.0 * clampf(oxy / oxy_max, 0.0, 1.0), 12), acol)
	var hpf := clampf(float(hp) / float(hp_cap()), 0.0, 1.0)
	draw_rect(Rect2(380, 222, 300, 24), Color(1, 1, 1, 0.12))
	draw_rect(Rect2(380, 222, 300.0 * hpf, 24), Color("e8505b") if hpf > 0.3 else Color("ff2b3d"))
	_txt("HP %d / %d" % [hp, hp_cap()], Vector2(380, 240), 18, Color.WHITE, 300.0)
	if _weapon_range() > 0:
		var md := _row2_h()
		btn_mode = Rect2(704.0 - md, 1062.0 + adv_ex, md, md)
		var mcol := Color("ffc24f") if ranged_mode else Color("ff8a4f")
		draw_circle(btn_mode.get_center(), md * 0.5, Color(0.03, 0.04, 0.08, 0.94))
		draw_circle(btn_mode.get_center(), md * 0.5, Color(mcol.r, mcol.g, mcol.b, 0.2))
		draw_arc(btn_mode.get_center(), md * 0.5 - 1.0, 0.0, TAU, 36, mcol, 3.0)
		_ctext("RANGED" if ranged_mode else "MELEE", btn_mode.get_center() + Vector2(0, -8), 20, mcol)
		_ctext("tap: swap", btn_mode.get_center() + Vector2(0, 14), 12, Color(1, 1, 1, 0.55))
	draw_rect(Rect2(380, 252, 300, 16), Color(1, 1, 1, 0.12))
	if sh > 0:
		draw_rect(Rect2(380, 252, 300.0 * clampf(float(sh) / float(sh_cap()), 0.0, 1.0), 16), Color("5aa8ff"))
		_txt("SHIELD %d" % sh, Vector2(380, 265), 14, Color.WHITE, 300.0)
	var okp := adv_pts >= adv_req
	var ptxt := "POINTS %d / %d" % [adv_pts, adv_req]
	if okp:
		ptxt += "   EXIT OPEN"
	if boss_floor:
		ptxt += "   BOSS GUARDS EXIT"
	if arena:
		ptxt = "ARENA: " + _arena_hint()
	_txt(ptxt, Vector2(0, 308), 26, Color("6dff9a") if okp else Color(1, 1, 1, 0.75))
	# tool slots (thumb cluster)
	for i in slots_n():
		var sr := _slot_rect(i)
		var has := i < inv.size()
		var scol := Color(1, 1, 1, 0.25)
		if has:
			scol = use_defs[inv[i]]["col"]
		var picked := aim == i or tool_sel == i
		if picked:
			scol = Color("ffe14f")
		_panel(sr, scol, 0.3 if picked else 0.16, false)
		if has:
			_use_icon(inv[i], sr.position + Vector2(sr.size.x * 0.5, sr.size.y * 0.4), sr.size.x * 0.5)
			_txt(_use_name(inv[i]), Vector2(sr.position.x, sr.end.y - 8.0), 13, Color.WHITE, sr.size.x)
		else:
			_ctext("empty", sr.get_center(), 14, Color(1, 1, 1, 0.3))
	_act_draw()
	if (tool_sel >= 0 or aim >= 0) and state == PLAY:
		var cnr := _cancel_rect()
		_panel(cnr, Color("ff8a8a"), 0.18, false)
		_para_fit(msg, Vector2(cnr.position.x + 14, cnr.position.y + 26), 20, Color.WHITE, 520.0, 2)
		if tool_sel >= 0 and aim < 0:
			_button(_drop_rect(), "DROP", Color("ffb347"), 22)
		else:
			_txt("TAP HERE TO CANCEL", Vector2(cnr.end.x - 170, cnr.position.y + 36), 14, Color("ff8a8a"), 160.0, HORIZONTAL_ALIGNMENT_RIGHT)
	else:
		if msg != "":
			draw_rect(Rect2(8, 1006.0 + adv_ex, 704, 38), Color(0.03, 0.04, 0.08, 0.9))
			draw_rect(Rect2(8, 1006.0 + adv_ex, 704, 38), Color(acc.r, acc.g, acc.b, 0.5), false, 2.0)
		_txt(msg, Vector2(0, 1034.0 + adv_ex), 24, Color.WHITE, 720.0)
	_draw_world_banner()
	if state == PLAY and hp > 0:
		if low:
			_edge_glow(Color("3d9bff"), clampf(1.0 - oxy / (oxy_max * 0.25), 0.0, 1.0))
		if hpf <= 0.3:
			_edge_glow(Color("ff2b3d"), clampf(1.0 - hpf / 0.3, 0.0, 1.0))
	if joy_on and state == PLAY:
		draw_circle(swipe_start, 90.0, Color(1, 1, 1, 0.07))
		draw_arc(swipe_start, 90.0, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
		draw_circle(swipe_start + joy_v, 34.0, Color(1, 1, 1, 0.35))


func _adv_badges() -> void:
	var items: Array = []
	items.append(["armor", str(armor_total()), Color("c9d3f0") if armor_total() > 0 else Color(1, 1, 1, 0.4)])
	if _weapon_range() > 0:
		items.append(["ammocrate", str(ammo), Color("ffc24f") if ammo > 0 else Color("ff6a5c")])
	if bounty_n > 0:
		items.append(["bounty", "x%d" % bounty_n, Color("ffc93c")])
	if keys > 0:
		items.append(["key", "x%d" % keys, Color("ffd84f")])
	if boost > 0:
		items.append(["boost", "+%d" % boost, Color("ff9a4f")])
	if cloak_steps > 0:
		items.append(["hidden", str(cloak_steps), Color("9aa3c7")])
	if poison_n > 0:
		items.append(["poison", str(poison_n), Color("9dff6a")])
	var h := 152.0 - btn_inv.end.y - 4.0
	var bw := 76.0
	var bx := 696.0 - bw
	for it in items:
		if bx < 366.0:
			break
		var br := Rect2(bx, btn_inv.end.y + 2.0, bw, h)
		var bcol: Color = it[2]
		_panel(br, bcol, 0.1, false)
		var kind := String(it[0])
		var ic := Vector2(br.position.x + 22, br.get_center().y)
		if kind == "key":
			_draw_key(ic, 24)
		elif kind == "armor" or kind == "ammocrate" or kind == "bounty":
			_spr(_item_tex(kind), ic, 28)
		else:
			_ctext({"boost": "ATK", "hidden": "HID", "poison": "PSN"}[kind], ic, 13, bcol)
		_txt(String(it[1]), Vector2(br.position.x + 38, br.get_center().y + 7), 20, bcol, 36.0, HORIZONTAL_ALIGNMENT_LEFT)
		bx -= bw + 4.0

const INV_TABS := [3, 0, 1, 2]   # display order -> inv_tab id: CHARACTER, STATS, TOOLS, RELICS
const CHR_SLOTS := ["helmet", "armour", "boots", "weapon", "ranged", "trinket"]


func _inv_tab_rect(i: int) -> Rect2:
	return Rect2(40 + i * 164, 186, 156, 56)


func _chr_model_rect() -> Rect2:
	return Rect2(196, 262, 328, 306)


func _chr_slot_rect(i: int) -> Rect2:
	return Rect2(40 if i < 3 else 540, 266 + (i % 3) * 104, 140, 96)


const CHR_LIST_TOP := 662.0
const CHR_LIST_BOT := 1062.0


# k = index in the pack; rows scroll with inv_scroll
func _chr_row_rect(k: int) -> Rect2:
	return Rect2(40, 666 + k * 110 - inv_scroll, 640, 102)


func _chr_equip_rect(k: int) -> Rect2:
	return Rect2(548, 666 + k * 110 - inv_scroll + 8, 124, 42)


func _chr_sell_rect(k: int) -> Rect2:
	return Rect2(548, 666 + k * 110 - inv_scroll + 54, 124, 38)


func _chr_row_visible(k: int) -> bool:
	var r := _chr_row_rect(k)
	return r.position.y >= CHR_LIST_TOP and r.end.y <= CHR_LIST_BOT


# the character model, optionally wearing a pack item (preview) in place of what is equipped
func _chr_tex(prev: String) -> ImageTexture:
	var eq: Dictionary = {}
	for sl in equip:
		eq[sl] = gb(String(equip[sl]))
	var psl := ""
	if prev != "":
		psl = String(gear_defs[gb(prev)]["slot"])
		eq[psl] = gb(prev)
	var show_rng := psl == "ranged" or (ranged_mode and psl != "weapon")
	if show_rng and eq.has("ranged"):
		eq["weapon"] = eq["ranged"]
	return spr_gen.player((cdef()["col"] as Color), cls, 0, chr_dir, eq)


func _chr_input(p: Vector2) -> void:
	if _chr_model_rect().has_point(p):
		chr_dir = {0: 3, 3: 1, 1: 0}.get(chr_dir, 0)
		_sfx("ui")
		return
	for i in 6:
		if _chr_slot_rect(i).has_point(p):
			if _adv_unequip(String(CHR_SLOTS[i])):
				chr_sel = -1
				_sfx("ui")
			else:
				_sfx("blocked")
			return
	for k in bag.size():
		if not _chr_row_visible(k):
			continue
		if _chr_equip_rect(k).has_point(p):
			_adv_equip(bag[k])
			chr_sel = -1
			_sfx("shield")
			return
		if _chr_sell_rect(k).has_point(p):
			coins += gprice(String(bag[k])) / 2
			bag.remove_at(k)
			chr_sel = -1
			_sfx("coin")
			return
		if _chr_row_rect(k).has_point(p):
			chr_sel = -1 if chr_sel == k else k
			_sfx("ui")
			return


func _draw_char_tab(acc: Color) -> void:
	inv_scroll_max = maxf(0.0, bag.size() * 110.0 - (CHR_LIST_BOT - 666.0 + 8.0))
	inv_scroll = clampf(inv_scroll, 0.0, inv_scroll_max)
	if chr_sel >= bag.size():
		chr_sel = -1
	var prev := String(bag[chr_sel]) if chr_sel >= 0 else ""
	var psl := String(gear_defs[gb(prev)]["slot"]) if prev != "" else ""
	var mr := _chr_model_rect()
	_obox(mr, Color(1, 1, 1, 0.04))
	draw_rect(mr, Color(1, 1, 1, 0.18), false, 2.0)
	_spr(_chr_tex(prev), mr.get_center() + Vector2(0, -4), 272.0)
	_ctext("PREVIEW: tap EQUIP to wear it" if prev != "" else "tap the model to turn it", Vector2(mr.get_center().x, mr.end.y - 14), 15, Color("ffd84f") if prev != "" else Color(1, 1, 1, 0.4))
	var wid := String(equip.get("ranged" if ranged_mode and _weapon_range() > 0 else "weapon", ""))
	var tsrc := prev if prev != "" else wid
	if tsrc != "" and gtr(tsrc).size() > 0:
		var tt := ""
		for tid3 in gtr(tsrc):
			tt += "%s: %s\n" % [TRAIT_DEFS[tid3]["n"], TRAIT_DEFS[tid3]["d"]]
		tt = tt.strip_edges()
		var tsz := font.get_multiline_string_size(tt, HORIZONTAL_ALIGNMENT_LEFT, 620.0, 14)
		var strip := Rect2(40, mr.end.y + 4.0, 640.0, minf(tsz.y + 12.0, 80.0))
		draw_rect(strip, Color(0.02, 0.03, 0.08, 0.88))
		draw_rect(strip, Color("ffd84f", 0.5), false, 1.0)
		_para(tt, strip.position + Vector2(8, 6 + font.get_ascent(14)), 14, Color("ffd84f"), 620.0)
	for i in 6:
		var slot := String(CHR_SLOTS[i])
		var r := _chr_slot_rect(i)
		var col := _gear_col(slot)
		var hl := psl == slot
		_obox(r, Color(col.r, col.g, col.b, 0.22 if hl else 0.08))
		draw_rect(r, Color(col.r, col.g, col.b, 0.95 if hl else 0.55), false, 2.0)
		_ctext(slot.to_upper(), r.position + Vector2(70, 14), 14, col)
		var gid := String(equip.get(slot, ""))
		if gid == "":
			_ctext("empty", r.position + Vector2(70, 54), 20, Color(1, 1, 1, 0.35))
		else:
			var gd: Dictionary = gear_defs[gb(gid)]
			_spr(_gear_tex(gid), r.position + Vector2(70, 40), 44.0)
			_ctext(String(gd["name"]), r.position + Vector2(70, 72), 14, _tier_col(int(gd["tier"])))
			_ctext("tap: remove", r.position + Vector2(70, 88), 12, Color(1, 1, 1, 0.4))
	_ctext("PACK  %d / %d     tap an item to preview it" % [bag.size(), BAG_MAX], Vector2(360, 654), 18, Color(1, 1, 1, 0.6))
	if bag.is_empty():
		_ctext("Your pack is empty.", Vector2(360, 800), 26, Color(1, 1, 1, 0.5))
	for idx in bag.size():
		if not _chr_row_visible(idx):
			continue
		var bid := String(bag[idx])
		var gd2: Dictionary = gear_defs[gb(bid)]
		var gc := _gear_col(String(gd2["slot"]))
		var rr := _chr_row_rect(idx)
		var sel := idx == chr_sel
		_obox(rr, Color(gc.r, gc.g, gc.b, 0.22 if sel else 0.08))
		draw_rect(rr, Color(gc.r, gc.g, gc.b, 0.95 if sel else 0.55), false, 3.0 if sel else 2.0)
		_spr(_gear_tex(bid), rr.position + Vector2(50, 51), 64.0)
		_txt(String(gd2["name"]), rr.position + Vector2(98, 32), 24, _tier_col(int(gd2["tier"])), 290.0, HORIZONTAL_ALIGNMENT_LEFT)
		_txt(String(gd2["slot"]).to_upper(), rr.position + Vector2(98, 56), 16, gc, 90.0, HORIZONTAL_ALIGNMENT_LEFT)
		if gtr(bid).size() > 0:
			_txt(gtrait_line(bid), rr.position + Vector2(190, 56), 14, Color("ffd84f"), 240.0, HORIZONTAL_ALIGNMENT_LEFT)
		_txt(_gear_desc(gd2), rr.position + Vector2(98, 84), 15, Color(1, 1, 1, 0.75), 440.0, HORIZONTAL_ALIGNMENT_LEFT)
		_button(_chr_equip_rect(idx), "EQUIP", gc, 22)
		_button(_chr_sell_rect(idx), "SELL %d" % (int(gd2["price"]) / 2), Color("ffc93c"), 18)
	if inv_scroll_max > 0.0:
		var tot := bag.size() * 110.0
		var vh := CHR_LIST_BOT - CHR_LIST_TOP
		var bh := vh * vh / tot
		var by := CHR_LIST_TOP + (vh - bh) * inv_scroll / inv_scroll_max
		draw_rect(Rect2(692, by, 6, bh), Color(1, 1, 1, 0.35))
		_ctext("drag to scroll", Vector2(360, 1100), 16, Color(1, 1, 1, 0.4))


func _inv_use_rect(i: int) -> Rect2:
	return Rect2(540, 286 + i * 104 + 22, 120, 52)


func _owned_relics() -> Array:
	var out: Array = []
	for d in relic_defs:
		if relic_n(String(d["id"])) > 0:
			out.append(d)
	return out


func _menu_leave() -> void:
	if t - menu_armed < 3.0:
		menu_armed = -10.0
		walk.clear()
		aim = -1
		_save_run()
		if tutorial:
			_tut_map_end(false)
		if testroom:
			_test_room_end()
		state = MODE
		_sfx("ui")
	else:
		menu_armed = t
		_sfx("blocked")


func _inv_input(p: Vector2) -> void:
	if btn_invmenu.has_point(p):
		_menu_leave()
		return
	if btn_inset.has_point(p):
		set_ret = INV
		state = SETTINGS
		_sfx("ui")
		return
	if btn_icl.has_point(p) or btn_inv.has_point(p):
		state = PLAY
		_sfx("ui")
		return
	for i in 4:
		if _inv_tab_rect(i).has_point(p):
			inv_tab = int(INV_TABS[i])
			chr_sel = -1
			inv_page = 0
			pack_page = 0
			inv_scroll = 0.0
			_sfx("ui")
			return
	if inv_tab == 0 and btn_inmore.has_point(p):
		inv_more = not inv_more
		inv_scroll = 0.0
		_sfx("ui")
		return
	if inv_tab == 1:
		for i in inv.size():
			if _inv_use_rect(i).has_point(p):
				state = PLAY
				_adv_use_slot(i)
				return
	elif inv_tab == 2:
		var pages := maxi(1, (_owned_relics().size() + 5) / 6)
		if btn_ipv.has_point(p):
			inv_page = (inv_page + pages - 1) % pages
			_sfx("ui")
		elif btn_inx.has_point(p):
			inv_page = (inv_page + 1) % pages
			_sfx("ui")
	elif inv_tab >= 3:
		_chr_input(p)


func _inv_extra_rows() -> Array:
	var leech := int(gear("leech") + sk("leech"))
	var rng_t := _shoot_range()
	var hz := int(round((1.0 - _haz_mult()) * 100.0))
	var sdef := int(gear("rangedef") + sk("rdef")) + 2 * relic_n("plating")
	var sc := gear("shotsave") + sk("shotsave")
	return [
		["#OFFENSE"],
		["CRIT CHANCE", "%d%%" % int(round(crit_chance())), "Chance for a hit to crit."],
		["CRIT DAMAGE", "x%.1f" % crit_mult(), "Damage multiplier when you crit."],
		["BERSERKER", "+%d" % int(sk("berserk")), "Extra attack while under half health."],
		["OPENING STRIKE", "+%d%%" % int(sk("opener")), "Bonus damage to enemies at full health."],
		["LIFESTEAL", "%d per hit" % leech, "Health restored on every hit."],
		["KILL HEAL", "%d" % int(gear("killheal")), "Health restored when you kill."],
		["FINISHER", "+%d%%" % int(sk("finish")), "Bonus damage to enemies under half health."],
		["RANGE", ("%d tiles" % rng_t) if rng_t > 0 else "none", "How far your ranged weapon shoots."],
		["RANGED BONUS", "+%d" % (_ranged_hv() - _ranged_atk()), "Extra damage on ranged shots."],
		["RANGED CRIT", "+%d%%" % int(sk("rcrit")), "Extra crit chance with ranged weapons."],
		["MAX AMMO", "%d" % ammo_max(), "Most ammo you can carry."],
		["AMMO DROPS", "%d%%" % int(sk("ammodrop")), "Chance for a kill to drop ammo."],
		["FREE SHOTS", "%d%%" % int(sk("noammo")), "Chance a shot uses no ammo."],
		["THORNS", "%d" % thorns_dmg(), "Damage reflected when you are hit."],
		["#DEFENCE"],
		["DODGE", "%d%%" % int(round(dodge_chance())), "Chance to avoid a hit completely."],
		["SHOT DEFENCE", "-%d" % sdef, "Damage removed from enemy ranged shots."],
		["HAZARD RESIST", "%d%%" % hz, "Less damage from floor hazards."],
		["LAST STAND", "%d%%" % int(sk("laststand")), "Less damage taken below 30% health."],
		["MEDKIT BONUS", "+%d%%" % int(sk("medk")), "Medkits heal this much more."],
		["STATION HEAL", "%d%%" % int(sk("stationheal")), "Health O2 stations restore (3 times per floor)."],
		["PHOENIX", ("used" if sk_phx else "%d%%" % int(sk("phoenix"))) if sk("phoenix") > 0 else "none", "Health you keep once per run after a killing blow."],
		["MIRROR", "%d" % mirror_n, "Hits left that Mirror Shard reflects."],
		["#AIR"],
		["AIR SAVING", "%d%%" % int(gear("airsave") + sk("airsave")), "Less air used per step."],
		["SHOT AIR SAVING", "%.1f" % sc, "Air saved on every ranged shot."],
		["POD AIR", "%d" % int(adv_pod_amt()), "Air restored by each air pod."],
		["SECOND WIND", "%d" % int(sk("wind")), "Air you get once per floor when you run out."],
		["AIR PER KILL", "%d" % int(sk("airkill")), "Air restored by every kill."],
		["MOMENTUM", "%d" % int(sk("momentum")), "Free steps after each kill."],
		["#EXPLORING"],
		["SIGHT", "%d" % adv_vis_r(), "How far you see around you."],
		["LANTERN OIL", ("%d steps" % oil_steps) if oil_steps > 0 else "none", "+3 sight while it lasts."],
		["SCANNER POWER", "%d" % (5 + lamp_amt() / 4), "Reach of a scanner pulse."],
		["TOOL SLOTS", "%d" % slots_n(), "How many tools you can carry."],
		["FREE TOOLS", "%d" % int(sk("quarter")), "Random tools you start every floor with."],
		["#FORTUNE"],
		["XP BONUS", "+%d%%" % int(gear("xp") + sk("xp")), "Extra XP from everything."],
		["LUCKY XP", "%d%%" % int(sk("lucky")), "Chance for a kill to give double XP."],
		["POTION BONUS", "+%d%%" % int(sk("pot")), "Extra XP from potions."],
		["COIN VALUE", "%d" % coin_val(), "Coins you get per coin pickup."],
		["LUCKY COINS", "%d" % lucky_n, "Next coins that are worth double."],
		["BOUNTY", "%d" % bounty_n, "Next elite kills that are sure to drop gear."],
		["KILL COINS", "+%d" % int(sk("kcoin")), "Extra coins dropped by every kill."],
		["GEAR DROPS", "+%d%%" % int(sk("drop")), "Extra gear drop chance from elites."],
		["SHOP DISCOUNT", "%d%%" % int(sk("haggle")), "Cheaper prices at shops."],
	]


func _draw_inv(acc: Color) -> void:
	var armed := t - menu_armed < 3.0
	_button(btn_invmenu, "SURE?" if armed else "MENU", Color("ff8a8a") if armed else acc)
	_button(btn_inset, "SETTINGS", Color("c9d3f0"), 18)
	_txt("INVENTORY", Vector2(0, 150), 52, acc)
	var tabs := ["CHARACTER", "STATS", "TOOLS", "RELICS"]
	for i in 4:
		var tr := _inv_tab_rect(i)
		var cur := int(INV_TABS[i]) == mini(inv_tab, 3)
		var tc := Color("ffd84f") if cur else Color(1, 1, 1, 0.5)
		_obox(tr, Color(tc.r, tc.g, tc.b, 0.16 if cur else 0.06))
		draw_rect(tr, tc, false, 2.0)
		_ctext(tabs[i], tr.get_center(), 20, tc)
	if inv_tab == 0:
		var rows := [
			["LEVEL", "%d" % level, "Each level adds attack and max health."],
			["XP", "%d / %d" % [xp, xp_need()], "Kills, potions and vaults give XP. Monsters grow with you."],
			["HEALTH", "%d / %d" % [hp, hp_cap()], "Reach 0 and you die. Medkits heal 40%."],
			["ATTACK", "%d" % p_atk(), "Damage per hit: your level plus bonuses."],
			["ARMOUR", "%d" % armor_total(), "Reduces every hit you take (minimum 1)."],
			["SHIELD", "%d / %d" % [sh, sh_cap()], "Soaks damage before your health does."],
			["AIR", "%d / %d" % [int(ceil(oxy)), int(oxy_max)], "Walking costs air. O2 stations refill it."],
			["POINTS", "%d / %d" % [adv_pts, adv_req], "Reach the total to unlock the exit. Coins: %d" % coins],
		]
		rows.append(["COINS", "%d" % coins, ""])
		var allrows: Array = rows
		if inv_more:
			allrows = [["#CORE"]] + rows + _inv_extra_rows()
		var vt := 276.0
		var vb := 1050.0
		var yy := vt - inv_scroll
		var total := 0.0
		for r in allrows:
			var hdr := String(r[0]).begins_with("#")
			var hh := 48.0 if hdr else (80.0 if inv_more else 66.0)
			if yy >= vt - 2.0 and yy + hh <= vb + 2.0:
				if hdr:
					_txt(String(r[0]).substr(1), Vector2(50, yy + 34), 24, Color("ffd84f"), 600.0, HORIZONTAL_ALIGNMENT_LEFT)
					draw_line(Vector2(40, yy + 42), Vector2(680, yy + 42), Color(1, 0.85, 0.3, 0.35), 2.0)
				else:
					_obox(Rect2(40, yy, 640, 72 if inv_more else 58), Color(1, 1, 1, 0.05))
					if inv_more:
						_txt(String(r[0]), Vector2(60, yy + 30), 22, Color(1, 1, 1, 0.65), 300.0, HORIZONTAL_ALIGNMENT_LEFT)
						_txt(String(r[1]), Vector2(360, yy + 32), 28, Color.WHITE, 300.0, HORIZONTAL_ALIGNMENT_RIGHT)
						_txt(String(r[2]), Vector2(60, yy + 60), 18, Color(1, 1, 1, 0.55), 610.0, HORIZONTAL_ALIGNMENT_LEFT)
					else:
						_txt(String(r[0]), Vector2(60, yy + 38), 26, Color(1, 1, 1, 0.75), 300.0, HORIZONTAL_ALIGNMENT_LEFT)
						_txt(String(r[1]), Vector2(360, yy + 40), 34, Color.WHITE, 300.0, HORIZONTAL_ALIGNMENT_RIGHT)
			yy += hh
			total += hh
		inv_scroll_max = maxf(0.0, total - (vb - vt))
		inv_scroll = clampf(inv_scroll, 0.0, inv_scroll_max)
		if inv_scroll_max > 0.0:
			var bh := (vb - vt) * (vb - vt) / total
			var by := vt + (vb - vt - bh) * inv_scroll / inv_scroll_max
			draw_rect(Rect2(690, by, 6, bh), Color(1, 1, 1, 0.35))
			_txt("drag to scroll", Vector2(0, 1134), 16, Color(1, 1, 1, 0.4))
		_button(btn_inmore, "FEWER STATS" if inv_more else "ALL STATS", Color("ffd84f"), 22)
	elif inv_tab == 1:
		_txt("Tools also sit on the bar at the bottom of the screen.", Vector2(0, 268), 20, Color(1, 1, 1, 0.55))
		if inv.is_empty():
			_txt("No tools yet. Find them in rooms and vaults.", Vector2(0, 520), 26, Color(1, 1, 1, 0.5))
		for i in inv.size():
			var id: String = inv[i]
			var y := 286.0 + i * 104.0
			var col: Color = use_defs[id]["col"]
			_obox(Rect2(40, y, 640, 94), Color(col.r, col.g, col.b, 0.1))
			draw_rect(Rect2(40, y, 640, 94), col, false, 2.0)
			_use_icon(id, Vector2(86, y + 47), 52)
			_txt(_use_name(id), Vector2(130, y + 38), 28, Color.WHITE, 400.0, HORIZONTAL_ALIGNMENT_LEFT)
			_para(_atext("tool_" + id, String(use_defs[id]["desc"])), Vector2(130, y + 66), 19, Color(1, 1, 1, 0.7), 390.0)
			_button(_inv_use_rect(i), "USE", col, 24)
	elif inv_tab == 2:
		var owned := _owned_relics()
		var pages := maxi(1, (owned.size() + 5) / 6)
		if owned.is_empty():
			_txt("No relics yet. Pick one after clearing a floor.", Vector2(0, 520), 26, Color(1, 1, 1, 0.5))
		for k in 6:
			var idx := inv_page * 6 + k
			if idx >= owned.size():
				break
			var d: Dictionary = owned[idx]
			var y := 262.0 + k * 130.0
			var cursed := d.has("curse")
			var col := Color("ff6a5c") if cursed else acc
			_obox(Rect2(40, y, 640, 120), Color(col.r, col.g, col.b, 0.1))
			draw_rect(Rect2(40, y, 640, 120), col, false, 2.0)
			var n := relic_n(String(d["id"]))
			_txt(_aname(String(d["id"]), String(d["name"])) + (" x%d" % n if n > 1 else "") + ("   CURSED" if cursed else ""), Vector2(58, y + 40), 30, col, 600.0, HORIZONTAL_ALIGNMENT_LEFT)
			_para(_atext(String(d["id"]), String(d["desc"])), Vector2(58, y + 76), 21, Color(1, 1, 1, 0.8), 610.0)
		if pages > 1:
			_button(btn_ipv, "< PREV", acc, 22)
			_button(btn_inx, "NEXT >", acc, 22)
			_txt("Page %d / %d" % [inv_page + 1, pages], Vector2(0, 1106), 20, Color(1, 1, 1, 0.55))
	else:
		_draw_char_tab(acc)
	_button(btn_icl, "CLOSE", acc, 26)


func _trait_selftest() -> int:
	var bad := 0
	var rt := _roll_traits(null, 4, true)
	if gb("katana@ignite,static") != "katana" or gtr("katana@ignite,static").size() != 2 or gb("katana") != "katana" or not gtr("katana").is_empty():
		print("FAIL trait id parse")
		bad += 1
	for i in 300:
		for tier in [1, 2, 3, 4]:
			for rg in [true, false]:
				var r := _roll_traits(null, tier, rg)
				for tid in gtr("x" + r):
					var tg: Array = TRAIT_DEFS[tid]["t"]
					if (tg.has("ranged") and not rg) or (tg.has("melee") and rg):
						bad += 1
	var a := Vector2i(-1, -1)
	var b := Vector2i(-1, -1)
	var dv := Vector2i(1, 0)
	for dix in 4:
		if _aopen(pos + TDIRS[dix]) and _aopen(pos + TDIRS[dix] * 2):
			a = pos + TDIRS[dix]
			b = pos + TDIRS[dix] * 2
			dv = TDIRS[dix]
			break
	if a.x < 0:
		print("trait sim skipped (no free lane)")
		return bad
	var all_ids: Array = TRAIT_DEFS.keys()
	var cases: Array = []
	for tid in all_ids:
		cases.append({"w": "novacleaver@" + String(tid), "r": false})
		cases.append({"w": "railsniper@" + String(tid), "r": true})
	cases.append({"w": "novacleaver@ignite,static,arc,toxin,siphon,rampage", "r": false})
	cases.append({"w": "railsniper@pierce,execute,volatile,plague,overkill,bounty", "r": true})
	for rid in ["pyro", "storm", "frost", "toxi", "bloodpact", "hood", "luckychip", "prism", "echo", "overclock", "thornmail", "scrapper"]:
		relics[rid] = 1
	for cs in cases:
		equip.erase("weapon")
		equip.erase("ranged")
		equip["ranged" if bool(cs["r"]) else "weapon"] = String(cs["w"])
		ammo = 9999
		hp_max = 600
		hp = hp_cap()
		sh = 0
		mons.clear()
		mon_hp.clear()
		affix.clear()
		mstat.clear()
		mons[a] = 3
		mons[b] = 3
		adv_vis[a] = true
		adv_vis[b] = true
		state = PLAY
		var guard := 0
		while (mons.has(a) or mons.has(b)) and guard < 60 and state == PLAY:
			oxy = oxy_max
			if mons.has(a):
				if bool(cs["r"]):
					_adv_shoot(a)
				else:
					_adv_fight(a)
			elif bool(cs["r"]):
				_adv_shoot(b)
			else:
				mons.erase(b)
			_tr_tick()
			guard += 1
		if state != PLAY or guard >= 60:
			print("FAIL trait case ", cs["w"], " state ", state, " guard ", guard)
			bad += 1
			state = PLAY
	for aid in AFFIX_DEFS:
		equip["weapon"] = "novacleaver@ignite,toxin,static"
		hp = hp_cap()
		mons.clear()
		mon_hp.clear()
		mstat.clear()
		mons[a] = 4
		affix.clear()
		affix[a] = aid
		adv_vis[a] = true
		var g2 := 0
		while mons.has(a) and g2 < 80 and state == PLAY:
			_adv_fight(a)
			_tr_tick()
			g2 += 1
		if state != PLAY or g2 >= 80:
			print("FAIL affix case ", aid)
			bad += 1
			state = PLAY
	for rid in ["pyro", "storm", "frost", "toxi", "bloodpact", "hood", "luckychip", "prism", "echo", "overclock", "thornmail", "scrapper"]:
		relics.erase(rid)
	mons.clear()
	affix.clear()
	mstat.clear()
	equip.erase("weapon")
	equip["ranged"] = "railsniper"
	# scaling and affix roll sanity
	floor_n = 12
	adv_seed = 4242
	_adv_gen()
	if affix.size() == 0:
		print("FAIL no affixes rolled on floor 12")
		bad += 1
	var hp1 := mon_hp_max(mons.keys()[0])
	equip["armour"] = "titan"
	equip["weapon"] = "novacleaver@brutal,ignite"
	if mon_hp_max(mons.keys()[0]) <= hp1:
		print("FAIL scaling")
		bad += 1
	print("trait sim done: cases %d affixes on floor 12: %d" % [cases.size(), affix.size()])
	return bad


func _skill_selftest() -> int:
	var bad := 0
	mode = "adv"
	skills.clear()
	skill_pts = 0
	level = 3
	_adv_level_up(6)
	if skill_pts != 2:
		print("FAIL skill points ", skill_pts)
		bad += 1
	if sk_buy("b0n3"):
		print("FAIL locked node bought")
		bad += 1
	if not sk_buy("b0n0") or not sk_buy("b0n0") or sk_rank("b0n0") != 2:
		print("FAIL buy ranks")
		bad += 1
	if sk_buy("b0n0"):
		print("FAIL bought past max")
		bad += 1
	if int(sk("hp")) != 10:
		print("FAIL hp stat ", sk("hp"))
		bad += 1
	skill_pts = 30
	if sk_buy("b0n5"):
		print("FAIL keystone without path")
		bad += 1
	for id in ["b0n1", "b0n1", "b0n3", "b0n3", "b0n5", "b0n5"]:
		if not sk_buy(id):
			print("FAIL path buy ", id)
			bad += 1
	if skill_pts != 30 - 8:
		print("FAIL point accounting ", skill_pts)
		bad += 1
	if int(sk("laststand")) != 50 or int(sk("armor")) != 2:
		print("FAIL stats after path")
		bad += 1
	hp_max = 100
	hp = 20
	if dmg_taken(10) >= maxi(1, 10 - armor_total()):
		print("FAIL last stand")
		bad += 1
	coins = 0
	if sk_respec():
		print("FAIL respec without coins")
		bad += 1
	coins = 99999
	var spent := skill_spent()
	var pts := skill_pts
	if not sk_respec() or not skills.is_empty() or skill_pts != pts + spent:
		print("FAIL respec")
		bad += 1
	# every node must be reachable from the centre
	var seen := {}
	var queue: Array = []
	for b in SK_N:
		queue.append("b%dn0" % b)
		seen["b%dn0" % b] = true
	while queue.size() > 0:
		var cur: String = queue.pop_front()
		for o in sk_adj[cur]:
			if not seen.has(o):
				seen[o] = true
				queue.append(o)
	if seen.size() != 36 or sk_defs.size() != 36:
		print("FAIL web connectivity ", seen.size())
		bad += 1
	skills.clear()
	skill_pts = 0
	print("skill sim done bad=%d" % bad)
	return bad


func _draw_selftest() -> void:
	mode = "adv"
	cls = "brute"
	floor_n = 8
	adv_seed = 777
	_adv_init_run()
	level = 12
	_adv_gen()
	_adv_snapshot()
	_adv_begin()
	coins = 300
	equip["weapon"] = "novacleaver@ignite,static,toxin"
	equip["armour"] = "titan"
	bag.append("katana@siphon,rampage")
	bag.append("plasmarifle@pierce,execute")
	skill_pts = 3
	skills["b0n0"] = 2
	skills["b0n1"] = 1
	skills["b2n5"] = 1
	sk_sel = "b0n1"
	var mc: Vector2i = mons.keys()[0]
	affix[mc] = "warded"
	mstat[mc] = {"burn": [2, 2], "psn": [2, 3], "stun": 1}
	pos = mc + Vector2i(1, 0)
	_adv_update_vis()
	var offers: Array = []
	for k in 3:
		var tg := _adv_roll_gear(null, 2)
		offers.append({"kind": "gear", "id": tg, "price": gprice(tg), "sold": false})
	offers.append({"kind": "tool", "id": "blink", "price": 6, "sold": false})
	merchants[start + Vector2i(1, 0)] = offers
	var plan: Array = [[PLAY, 0], [SKILLS, 0], [INV, 0], [INV, 1], [INV, 2], [INV, 3], [INV, 4], [TRADE, 0], [RELIC, 0]]
	for step in plan:
		state = int(step[0])
		inv_tab = int(step[1])
		if state == TRADE:
			trade_cell = start + Vector2i(1, 0)
			trade_med = false
		if state == RELIC:
			relic_choices = _roll_relics(0)
		var before := draw_count
		queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		print("draw state %d tab %d drawn %d" % [state, inv_tab, draw_count - before])
	for tm in 2:
		for pgi in _tut_pages(tm).size():
			state = TUTORIAL
			tut_mode = tm
			tut_page = pgi
			var b3 := draw_count
			queue_redraw()
			await get_tree().process_frame
			await get_tree().process_frame
			var lay := _tut_layout(_tut_pages(tm)[pgi])
			print("tut %d page %d drawn %d font %d" % [tm, pgi, draw_count - b3, int(lay["fs"])])
	print("DRAW TEST DONE")


func _batch_selftest() -> int:
	var bad := 0
	var sv_ups := ups.duplicate()
	var sv_best := adv_best
	var sv_bank := bank
	var sv_off := save_off
	var sv_relics := relics.duplicate()
	var sv_items := items.duplicate()
	var sv_inv := inv.duplicate()
	var sv_floor := floor_n
	var sv_level := level
	var sv_hp := hp
	var sv_oxy := oxy
	var sv_pts := adv_pts
	var sv_req := adv_req
	var sv_sp := skill_pts
	save_off = true
	mode = "adv"
	tutorial = false
	arena = false
	# ammo belt
	ups["belt"] = 0
	var a0 := ammo_max()
	ups["belt"] = 2
	if ammo_max() != a0 + 8:
		print("FAIL ammo belt")
		bad += 1
	ups["belt"] = 0
	# world rule per floor
	var want := {1: "leak", 4: "spore", 7: "black", 10: "glare", 13: "leak"}
	for wf in want:
		floor_n = int(wf)
		if _world_rule() != String(want[wf]):
			print("FAIL world rule floor %d" % int(wf))
			bad += 1
	arena = true
	floor_n = 3
	if _world_rule() != "":
		print("FAIL world rule in arena")
		bad += 1
	arena = false
	# every rule floor generates a fully reachable level (shrines, idols, guards included)
	for gf in [1, 4, 7, 10, 16]:
		for gs in 6:
			floor_n = gf
			adv_seed = gf * 101 + gs * 17 + 3
			_adv_init_run()
			_adv_gen()
			var gd := _adv_bfs(start)
			for gc in items:
				if not gd.has(gc):
					print("FAIL unreachable item floor %d seed %d" % [gf, adv_seed])
					bad += 1
			for gm in mons:
				if gm != stairs and not gd.has(gm):
					print("FAIL unreachable monster floor %d seed %d" % [gf, adv_seed])
					bad += 1
			if not _adv_in_room(start):
				print("FAIL start not in a room")
				bad += 1
	# leak rule: a corridor cell is outside every room
	var corr_found := false
	for cy in AH:
		for cx in AW:
			var cc := Vector2i(cx, cy)
			if _aopen(cc) and not _adv_in_room(cc):
				corr_found = true
				break
		if corr_found:
			break
	if not corr_found:
		print("FAIL no corridor cell found")
		bad += 1
	# guided first floor: each hint shows once
	floor_n = 1
	adv_best = 0
	guide_seen.clear()
	state = PLAY
	items.clear()
	inv.clear()
	skill_pts = 0
	hp = hp_cap()
	oxy = oxy_max
	adv_req = 1
	adv_pts = 5
	_guide_tick()
	if not msg.contains("Exit unlocked"):
		print("FAIL guide exit hint")
		bad += 1
	msg = "zzz"
	_guide_tick()
	if msg != "zzz":
		print("FAIL guide hint repeated")
		bad += 1
	adv_best = 3
	guide_seen.clear()
	msg = "zzz"
	_guide_tick()
	if msg != "zzz":
		print("FAIL guide shown after a floor was cleared")
		bad += 1
	# death screen text
	adv_best = 0
	guide_seen.clear()
	floor_n = 4
	level = 5
	run_kills = 7
	coins = 3
	run_banked = 0
	relics.clear()
	_die("Test cause")
	if state != DEAD or not over_sub.contains("Kills 7") or not over_sub.contains("NEW BEST") or not over_sub.contains("Floor 4") or not over_sub.contains("Level 5") or not over_sub.begins_with("Test cause"):
		print("FAIL death screen text: " + over_sub)
		bad += 1
	state = PLAY
	run_kills = 0
	# restore what this test touched
	ups = sv_ups
	adv_best = sv_best
	bank = sv_bank
	save_off = sv_off
	relics = sv_relics
	items = sv_items
	inv = sv_inv
	floor_n = sv_floor
	level = sv_level
	hp = sv_hp
	oxy = sv_oxy
	adv_pts = sv_pts
	adv_req = sv_req
	skill_pts = sv_sp
	print("batch selftest bad=%d" % bad)
	return bad


func _adv_selftest() -> void:
	var bad := 0
	mode = "adv"
	cls = "scout"
	for f in range(1, 41):
		floor_n = f
		cls = String(class_defs[f % class_defs.size()]["id"])
		relics.clear()
		var t0 := Time.get_ticks_msec()
		cell = AC
		period = 100000
		maxd = 0
		adv_seed = f * 7919 + 13
		_adv_init_run()
		level = 2 + f
		_adv_gen()
		var dist := _adv_bfs(start)
		var ok := dist.has(stairs)
		for c in items:
			if not dist.has(c):
				ok = false
		for c in coin_at:
			if not dist.has(c):
				ok = false
		for c in vaults:
			if not dist.has(c):
				ok = false
		var lvs: Array = []
		for c in mons:
			if c != stairs:
				lvs.append(int(mons[c]))
		lvs.sort()
		for k in lvs.size():
			if int(lvs[k]) > level + 2 + k / 2 + f / 6:
				ok = false
		if adv_req > adv_pts_total:
			ok = false
		if not ok:
			bad += 1
		print("adv floor %d size %d rooms %d mons %d pts %d req %d boss %s ok %s %dms" % [f, AW, adv_rooms.size(), mons.size(), adv_pts_total, adv_req, boss_floor, ok, Time.get_ticks_msec() - t0])
	# station coverage + a short combat/tool simulation
	for f in [1, 8, 20, 35]:
		floor_n = f
		cls = "brute"
		relics.clear()
		adv_seed = f * 31 + 5
		_adv_gen()
		var worst := 0
		var sm := {}
		for sc in stations:
			var dd := _adv_bfs(sc)
			for k in dd:
				if int(dd[k]) < int(sm.get(k, 99999)):
					sm[k] = dd[k]
		for r in adv_rooms:
			worst = maxi(worst, int(sm.get(_rc(r), 0)))
		print("floor %d stations %d worst room distance to a station %d" % [f, stations.size(), worst])
		if worst > 30:
			bad += 1
	floor_n = 6
	cls = "brute"
	adv_seed = 99
	_adv_init_run()
	for sd in 40:
		adv_seed = 99 + sd
		_adv_gen()
		if merchants.size() > 0:
			break
	_adv_snapshot()
	_adv_begin()
	var steps_ok := 0
	for c in mons.keys():
		if c == stairs:
			continue
		hp = 999
		hp_max = 999
		var guard := 0
		while mons.has(c) and guard < 40 and state == PLAY:
			_adv_fight(c)
			guard += 1
		steps_ok += 1
		if steps_ok > 6:
			break
	inv.append("bomb")
	inv.append("zap")
	_adv_use_slot(0)
	_adv_hurt(5, "Test")
	_adv_hunters()
	_adv_step(start, true)
	_adv_gain_xp(500)
	for gd in gear_list:
		_adv_give_gear(String(gd["id"]))
	for i in 5:
		if bag.size() > 0:
			_adv_equip(bag[0])
	_adv_unequip("weapon")
	_adv_unequip("ranged")
	var okc := 0
	for c in merchants:
		okc += 1
	var gcount := 0
	for ic in items:
		if String(items[ic]).begins_with("gear_"):
			gcount += 1
	print("gear sim: equipped %d bag %d atk %d armour %d hpcap %d merchants %d crates %d gear_defs %d" % [equip.size(), bag.size(), p_atk(), armor_total(), hp_cap(), okc, gcount, gear_defs.size()])
	if merchants.size() > 0:
		var mc: Vector2i = merchants.keys()[0]
		coins = 999
		bag.clear()
		inv.clear()
		_adv_open_trade(mc)
		_trade_input(_trade_rect(0).get_center())
		_trade_input(_trade_rect(3).get_center())
		print("trade sim ok coins %d state %d" % [coins, state])
	relics["phoenix"] = 1
	hp = 1
	_die("test")
	print("phoenix sim hp %d cap %d state %d" % [hp, hp_cap(), state])
	print("combat sim ok hp %d sh %d armor %d level %d state %d" % [hp, sh, armor_total(), level, state])
	# turret lane + hazards sim
	tur.clear()
	haz.clear()
	var tc0 := Vector2i(-1, -1)
	for dix in 4:
		if _aopen(pos + TDIRS[dix] * 3) and _aopen(pos + TDIRS[dix] * 2) and _aopen(pos + TDIRS[dix]):
			tc0 = pos + TDIRS[dix] * 3
			mons.erase(tc0)
			mons[tc0] = 3
			kinds[tc0] = "turret"
			tur[tc0] = {"v": 0, "d": dix ^ 1}
			break
	if tc0.x >= 0:
		hp = hp_cap()
		sh = 0
		var hp0 := hp
		_adv_turrets()
		if hp >= hp0:
			print("FAIL turret did not hit")
			bad += 1
		_remove_mon(tc0)
	haz[start] = "toxic"
	_adv_haz_trigger("toxic", start, Vector2i.ZERO)
	if poison_n != 4:
		print("FAIL poison")
		bad += 1
	for hid in ["arc", "breach", "slick", "mine", "alarm", "warp", "shard"]:
		hp = hp_cap()
		oxy = oxy_max
		_adv_haz_trigger(hid, start, Vector2i(1, 0))
		state = PLAY
	var as0 := adv_steps
	for par in 2:
		adv_steps = 100 + par
		hp = hp_cap()
		sh = 0
		var hp_a := hp
		_adv_haz_trigger("arc", start, Vector2i(1, 0))
		if _arc_live(start, adv_steps) and hp < hp_a:
			print("FAIL unlit arc plate shocked")
			bad += 1
		if not _arc_live(start, adv_steps) and hp >= hp_a:
			print("FAIL lit arc plate did not shock")
			bad += 1
		state = PLAY
	adv_steps = as0
	haz.clear()
	poison_n = 0
	# shooter sim
	var shc := Vector2i(-1, -1)
	for dix in 4:
		if _aopen(pos + TDIRS[dix]) and _aopen(pos + TDIRS[dix] * 2) and _aopen(pos + TDIRS[dix] * 3):
			shc = pos + TDIRS[dix] * 3
			mons[shc] = 2
			kinds[shc] = "shooter"
			break
	if shc.x >= 0:
		hp = hp_cap()
		sh = 0
		var hps := hp
		adv_steps = (shc.x + shc.y) % 2 + 2 * 0
		adv_steps = adv_steps if (adv_steps + shc.x + shc.y) % 2 == 0 else adv_steps + 1
		_adv_shooters()
		if hp >= hps:
			print("FAIL shooter did not hit")
			bad += 1
		_remove_mon(shc)
	relics["deadeye"] = 2
	relics["heavyammo"] = 1
	if _shot_cost() < 0.5:
		print("FAIL shot cost")
		bad += 1
	relics.erase("deadeye")
	relics.erase("heavyammo")
	# ranged + corpse sim
	for dix in 4:
		var tcell: Vector2i = pos + TDIRS[dix] * 2
		if _aopen(pos + TDIRS[dix]) and _aopen(tcell):
			mons.erase(tcell)
			mons[tcell] = 1
			kinds.erase(tcell)
			equip["ranged"] = "railsniper"
			ammo = 9999
			adv_vis[tcell] = true
			mon_hp.erase(tcell)
			if not _adv_can_shoot(tcell):
				print("FAIL cannot shoot")
				bad += 1
			var gh := 0
			while mons.has(tcell) and gh < 30 and state == PLAY:
				_adv_shoot(tcell)
				gh += 1
			if not corpses.has(tcell):
				print("FAIL no corpse")
				bad += 1
			var posb := pos
			mons[tcell + TDIRS[dix]] = 1
			break
	bad += _arena_selftest()
	bad += _trait_selftest()
	bad += _skill_selftest()
	bad += _batch_selftest()
	print("ADV TEST DONE bad=%d" % bad)



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
		var mv: float = VOL_STEPS[set_mus]
		music_player.volume_db = -11.0 + linear_to_db(mv) if (snd_on and mv > 0.0) else -80.0


var buzz_ok := -1   # -1 unknown, 0 no, 1 yes


# An APK installed before the vibrate permission was added (self-updates only swap the .pck) would crash on vibrate_handheld, so check the permission first.
func _buzz(ms: int) -> void:
	if set_vib != 1:
		return
	if buzz_ok < 0:
		buzz_ok = 0
		if OS.get_name() == "Android":
			if OS.get_granted_permissions().has("android.permission.VIBRATE"):
				buzz_ok = 1
		elif OS.has_feature("web"):
			buzz_ok = 1
	if buzz_ok == 1:
		Input.vibrate_handheld(ms)


const SFX_BUZZ := {"ui": 10, "blocked": 18, "shieldbreak": 45, "death": 160, "elite": 40, "boom": 50, "breach": 30, "spike": 25, "big": 25}


func _sfx(n: String) -> void:
	if SFX_BUZZ.has(n):
		_buzz(int(SFX_BUZZ[n]))
	var sv: float = VOL_STEPS[set_sfxv]
	if not snd_on or sv <= 0.0 or not sfx_cache.has(n):
		return
	var chosen: AudioStreamPlayer = sfx_players[0]
	for p in sfx_players:
		if not p.playing:
			chosen = p
			break
	chosen.stream = sfx_cache[n]
	chosen.volume_db = -3.0 + linear_to_db(sv)
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
	b = _buf(0.22, SR_SFX)
	_add_noise(b, SR_SFX, 0.0, 0.05, 0.5, 40.0, 0.9)
	_add_sweep(b, SR_SFX, 0.0, 0.16, 1500.0, 260.0, 0.3, 3, 9.0)
	d["shoot"] = _stream(b, SR_SFX)
	b = _buf(0.3, SR_SFX)
	_add_sweep(b, SR_SFX, 0.0, 0.26, 1000.0, 180.0, 0.28, 1, 6.0)
	_add_noise(b, SR_SFX, 0.0, 0.06, 0.25, 30.0, 0.8)
	d["turret"] = _stream(b, SR_SFX)
	b = _buf(0.26, SR_SFX)
	_add_sweep(b, SR_SFX, 0.0, 0.2, 780.0, 140.0, 0.28, 2, 8.0)
	_add_noise(b, SR_SFX, 0.0, 0.04, 0.2, 40.0, 0.7)
	d["enemyshot"] = _stream(b, SR_SFX)
	b = _buf(0.4, SR_SFX)
	_add_noise(b, SR_SFX, 0.0, 0.3, 0.45, 9.0, 0.95)
	_add_sweep(b, SR_SFX, 0.0, 0.08, 200.0, 2000.0, 0.28, 2, 14.0)
	_add_sweep(b, SR_SFX, 0.1, 0.14, 1800.0, 300.0, 0.22, 3, 9.0)
	d["arc"] = _stream(b, SR_SFX)
	b = _buf(0.7, SR_SFX)
	_add_noise(b, SR_SFX, 0.0, 0.6, 0.5, 4.0, 0.98)
	_add_sweep(b, SR_SFX, 0.0, 0.5, 600.0, 200.0, 0.1, 0, 4.0)
	d["breach"] = _stream(b, SR_SFX)
	b = _buf(0.5, SR_SFX)
	_add_sweep(b, SR_SFX, 0.0, 0.25, 260.0, 150.0, 0.3, 3, 5.0)
	_add_sweep(b, SR_SFX, 0.2, 0.25, 150.0, 240.0, 0.3, 3, 5.0)
	d["poison"] = _stream(b, SR_SFX)
	b = _buf(0.4, SR_SFX)
	_add_sweep(b, SR_SFX, 0.0, 0.35, 900.0, 420.0, 0.2, 0, 5.0)
	_add_noise(b, SR_SFX, 0.0, 0.3, 0.2, 6.0, 0.9)
	d["slide"] = _stream(b, SR_SFX)
	b = _buf(0.9, SR_SFX)
	_add_noise(b, SR_SFX, 0.0, 0.8, 0.7, 4.0, 0.35)
	_add_sweep(b, SR_SFX, 0.0, 0.6, 140.0, 38.0, 0.55, 0, 3.0)
	d["boom"] = _stream(b, SR_SFX)
	b = _buf(1.0, SR_SFX)
	for i in 6:
		_add_note(b, SR_SFX, i * 0.15, 0.14, 880.0 if i % 2 == 0 else 640.0, 0.28, 2, 8.0)
	d["alarm"] = _stream(b, SR_SFX)
	b = _buf(0.6, SR_SFX)
	for i in 4:
		_add_note(b, SR_SFX, i * 0.035, 0.3, float([1568.0, 2093.0, 1319.0, 2637.0][i]), 0.2, 1, 9.0)
	_add_noise(b, SR_SFX, 0.0, 0.1, 0.25, 25.0, 0.7)
	d["shard"] = _stream(b, SR_SFX)
	b = _buf(0.5, SR_SFX)
	_add_sweep(b, SR_SFX, 0.0, 0.4, 200.0, 110.0, 0.35, 3, 4.0)
	_add_noise(b, SR_SFX, 0.0, 0.15, 0.2, 14.0, 0.5)
	d["aggro"] = _stream(b, SR_SFX)
	b = _buf(0.3, SR_SFX)
	_add_sweep(b, SR_SFX, 0.0, 0.2, 160.0, 55.0, 0.4, 0, 9.0)
	_add_noise(b, SR_SFX, 0.0, 0.06, 0.25, 30.0, 0.4)
	d["corpse"] = _stream(b, SR_SFX)


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
		{"bpm": 76.0, "kind": 1, "vol": 0.2, "pat": [0, 2, 1, 3, 1, 2, 3, 2],
			"ch": [[40, [64, 67, 71, 76]], [36, [60, 64, 67, 72]], [43, [62, 67, 71, 74]], [38, [62, 65, 69, 74]]]},
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
		cls = ["scout", "brute", "mystic", "gambler", "gunslinger"][f % 5]
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
		for ti in themes.size():
			for lv in range(1, 10):
				_monster_tex(ti, lv, lv == 9)
				_monster_tex(ti, lv, false, false, 1)
				_monster_tex(ti, lv, false, false, 2)
				_monster_tex(ti, lv, lv == 9, false, 3)
			for p in 2:
				for v in 3:
					_floor_tex(ti, p, v)
			_wall_set(ti)
		_player_tex()
		for kind in ["pot", "big", "lamp", "shield", "coin"]:
			_item_tex(kind)
	print("TEST DONE unsolvable=%d" % bad)

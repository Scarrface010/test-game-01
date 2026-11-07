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
enum { PLAY, DEAD, CLEAR, RELIC, SHOP, CLASS, FORK, MARKET, MODE, INV, TRADE, TUTORIAL, LEADER, SKILLS, SAVES, SETTINGS, INTRO, MASTERY, CODEX, WORKSHOP, CONTRACTS }
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
var adv_fresh := false        # true only at the start of a run: next _adv_begin fully heals
var root_n := 0               # rooted: move presses left before you can move again
var fab_steps := 0            # Ammo Fabricator counter
var tool_uses := 0            # Spare Parts counter
var anchor_used := false      # Phase Anchor used this floor
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
var run_best := 0
var run_dmg := 0
var run_steps := 0
var run_gear := 0
var ups: Dictionary = {"c_brute": 0, "c_mystic": 0, "c_gunslinger": 0, "c_gambler": 0, "kit": 0, "toolbox": 0, "head": 0, "ash": 0, "p_elem": 0, "p_blood": 0, "p_combo": 0, "p_relic": 0, "p_fort": 0, "p_surv": 0, "p_curse": 0, "sp": 0, "suit": 0, "tank": 0, "belt": 0, "vet": 0}
# Shop v2 (unlocks only). The old stat-boost shop is refunded once, using these old prices.
const OLD_SHOP_COSTS := {"vet": [15, 35, 60], "iron": [20, 40, 70], "packed": [45], "lucky": [50], "pockets": [40, 90], "treasure": [25, 55, 100], "oil": [25, 50, 85], "toolbox": [30, 70], "gate": [60, 120], "steel": [35], "haggle": [30], "head": [75, 150], "ash": [120], "interest": [40, 80, 130], "kit": [40, 90]}
# Drop-pool packs: traits and relics that stay out of drops until the pack is bought.
const PACKS := {
	"p_elem": {"t": ["ignite", "volatile", "static", "arc", "frostbite", "shatter", "toxin", "plague", "stormfront", "conduit", "inferno", "flashpoint", "permafrost", "icicle", "rot", "contagion", "stormcaller"], "r": ["pyro", "storm", "frost", "toxi"]},
	"p_blood": {"t": ["siphon", "bloodlust", "execute", "adrenaline", "barrier", "vampedge"], "r": ["bloodpact", "hood"]},
	"p_combo": {"t": ["rampage", "rhythm", "marked", "deadly", "harvest", "echostep"], "r": ["overclock"]},
	"p_relic": {"t": [], "r": ["deadeye", "plating", "hazmat", "gravedigger", "thornmail", "scrapper"]},
	"p_fort": {"t": [], "r": ["midas", "scavenger", "luckychip", "amidas"]},
	"p_surv": {"t": [], "r": ["aegis", "boots", "lantern", "slowdark"]},
	"p_curse": {"t": [], "r": ["glass", "greedy", "blade", "heavyammo", "ember", "prism", "agreedy"]},
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
var btn_mode_a := Rect2(30, 330, 660, 380)
var btn_tut := Rect2(50, 950, 300, 76)
var tut_mode := 0
var btn_lb := Rect2(370, 950, 300, 76)
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
var inv_filter := 0
var inv_sort := 0
var inv_scroll_max := 0.0
var mods_open := true
var chr_off := 0.0    # extra height of the modifiers strip in the gear tab
var tut_back := MODE
var tutorial := false
var tut_dlg := ""            # tutorial dialog box text (blocks input until tapped)
var fade_a := 0.0            # black screen fade (floor transitions)
var fade_to := 0.0
var fade_cb: Callable
var relic_pick := -1         # -1 none, >=0 relic picked, -2 skip picked
var pick_t := 0.0
var floor_msg_t := -100.0
var clear_pend := false      # left to menu from the floor-cleared popup
var mini := false            # puzzle mini-game started from the shop
var mini_world := 0
var mini_ret := 0
var mini_done := false
var mini_prev_save_off := false
var mini_msg := ""
var btn_mini := Rect2(160, 1000, 400, 70)
var btn_tleave := Rect2(250, 1130, 220, 64)
var btn_reroll := Rect2(160, 924, 400, 62)
var puz_used := {}           # outfitter cells whose puzzle run was used (this floor)
var mini_snap: Dictionary = {}
var mini_pick := false
var btn_quit := Rect2(250, 1150, 220, 60)
var btn_cl_next := Rect2(110, 690, 500, 76)
var btn_cl_menu := Rect2(110, 782, 500, 60)
var tut_zone := -1
var tut_prev_cls := "scout"
# hidden gear test room: tap the SETTINGS title 5 times to unlock its button
var testroom := false
var in_base := false      # B85: walking around the Station Base hub before a run
var base_prev_save_off := false
var test_pending := false
var test_unlocked := false
var set_taps := 0
var set_tap_t := -10.0
var test_prev_save_off := false
const BTN_TEST := Rect2(110, 1196, 245, 64)
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
var set_mus := 1     # music volume step: 0 = 100%, 1 = 60%, 2 = 30%, 3 = off
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
const JOY_STEP := 0.21  # seconds per step while the stick is held
var joy_on := false
var joy_dir := Vector2i.ZERO
var joy_v := Vector2.ZERO
var joy_t := 0.0
var press_t := -10.0
var last_state := -1
var state_t := 0.0
var bank_disp := -1.0
const BUILD := 111
var imp_wait := false
var xfer_msg := ""
var xfer_t := -10.0
var save_info := ""
var save_last_sig := 0
var save_t := 0.0
var save_off := false
const SAVE_PATH := "user://run.sav"
const SAVE_VARS := ["mode", "cls", "hz_run", "N", "cell", "period", "maxd", "floor_n", "level", "moves", "coins", "shield", "pos", "start", "stairs", "req",
	"boss_cell", "mons", "elite", "items", "spikes", "coin_at", "haz", "corpses", "tur", "poison_n", "poison_d", "walls", "portals", "kinds",
	"thief_held", "relics", "boost", "cloak_steps", "keys", "vaults", "boss_floor", "boss_kind", "boss_base", "fmod", "run_banked", "adv_open", "adv_seen",
	"adv_rooms", "adv_pts", "adv_req", "adv_pts_total", "oxy", "oxy_max", "adv_steps", "adv_seed", "AW", "AH", "cam", "scan_steps", "scan_r",
	"xp", "merchants", "trade_cell", "equip", "hp", "hp_max", "armor", "sh", "mon_hp", "stations", "meds", "saved", "msg", "door_choices",
	"market_stock", "relic_choices", "shop_return", "affix", "mstat", "skills", "skill_pts", "ammo", "pk", "sk_wind", "sk_phx", "act_cd", "act_free", "act_stance", "act_rico", "station_uses", "arena", "arena_d", "mirror_n", "lucky_n", "bounty_n", "oil_steps", "scrap", "fr_uses", "sup_done", "can_n", "run_best", "run_dmg", "run_steps", "run_gear", "clear_pend", "puz_used", "run_ghost", "floor_spotted", "deep_run"]
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
var btn_wipe := Rect2(160, 1010, 400, 60)
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
var btn_newrun := Rect2(160, 1060, 400, 76)
# Rewarded/interstitial ads (Play build only, see ads.gd)
var btn_ad_revive := Rect2(160, 640, 400, 84)
var btn_ad_giveup := Rect2(160, 750, 400, 64)
var btn_ad_double := Rect2(160, 966, 400, 76)
var btn_ad_core := Rect2(110, 890, 500, 64)
var btn_ad_privacy := Rect2(536, 20, 164, 46)
var btn_ad_remove := Rect2(134, 20, 392, 46)
var rv_ask := false
var rv_why := ""
var rv_used := false
var rv_busy := false
var ad_delta := 0
var ad_doubled := false
var ad_boss := false
var ad_run_pending := false
var btn_shop := Rect2(160, 1150, 400, 76)
var btn_back := Rect2(250, 1010, 220, 64)
var btn_shop2 := Rect2(480, 1100, 200, 76)
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
		cos_kill = String(cfg.get_value("s", "cos_kill", "none"))
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
		set_mus = clampi(int(cfg.get_value("ui", "music", 1)), 0, 3)
		set_sfxv = clampi(int(cfg.get_value("ui", "sfxvol", 0)), 0, 3)
		set_vib = clampi(int(cfg.get_value("ui", "vibrate", 1)), 0, 1)
		set_big = 0
		tut_seen["puzzle"] = bool(cfg.get_value("ui", "tut_p", false))
		tut_seen["adv"] = bool(cfg.get_value("ui", "tut_a", false))
		tut_seen["map"] = bool(cfg.get_value("ui", "tut_m", false))
		_layout_buttons()
		_apply_sound()
		_apply_display()
		lb_uid = String(cfg.get_value("lb", "uid", ""))
		lb_sent["puzzle"] = int(cfg.get_value("lb", "sent_puzzle", 0))
		lb_sent["adv"] = int(cfg.get_value("lb", "sent_adv", 0))
		_mx_load(cfg)
		_ul_load(cfg)
		if migrate_shop:
			_save_meta()
	if lb_uid == "":
		var ur := RandomNumberGenerator.new()
		ur.randomize()
		for i in 14:
			lb_uid += "abcdefghijklmnopqrstuvwxyz0123456789"[ur.randi() % 36]
		_save_meta()
	_make_defs()
	if bool(cfg.get_value("s", "shop_v2", false)):
		for k in NR_PACKS:
			ups[k] = int(cfg.get_value("ups", k, 0))
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
	if "--mxtest" in args:
		_mx_selftest()
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
		{"id": "frost", "name": "Frost Core", "desc": "+4 max health. Frozen enemies take +100% damage instead of +50%. Frost Charge stuns 2 steps longer", "max": 1, "adv": true, "tag": "cryo"},
		{"id": "toxi", "name": "Toxicologist", "desc": "+4 max health. Poison stacks up to 7 instead of 4", "max": 1, "adv": true, "tag": "toxic"},
		{"id": "bloodpact", "name": "Blood Pact", "desc": "+4 max health. Siphon heals double", "max": 1, "adv": true, "tag": "blood"},
		{"id": "hood", "name": "Executioner's Hood", "desc": "+4 max health. Executioner works below 35% health", "max": 1, "adv": true, "tag": "execute"},
		{"id": "luckychip", "name": "Lucky Chip", "desc": "+5% crit chance, and crits restore 1 air", "max": 1, "adv": true, "tag": "crit"},
		{"id": "prism", "name": "Prism Lens", "desc": "+1 attack for each different trait type on your weapon (max +4), but attacking costs double air", "max": 1, "curse": true, "adv": true, "tag": "variety"},
		{"id": "overclock", "name": "Overclock", "desc": "Rampage can stack 3 higher", "max": 1, "adv": true, "tag": "streak"},
		{"id": "thornmail", "name": "Thornmail", "desc": "Reflect 2 damage whenever you are hit", "max": 1, "adv": true},
		{"id": "scrapper", "name": "Scrapper", "desc": "35% chance of an extra coin on every kill", "max": 1, "adv": true},
		{"id": "amidas", "name": "Midas Touch", "desc": "Every coin you pick up is worth +1", "max": 1, "adv": true},
		{"id": "agreedy", "name": "Greedy Pact", "desc": "Every enemy you kill drops +2 coins, but every enemy is +1 level", "max": 1, "curse": true, "adv": true},
		{"id": "medic", "name": "Medic Drone", "desc": "When you leave a floor, 50% of your remaining shield turns into healing", "max": 1, "adv": true},
		{"id": "bedge", "name": "Bleeding Edge", "desc": "Bleed damage counts as a hit for Siphon and lifesteal", "max": 1, "adv": true, "tag": "blood"},
		{"id": "ccore", "name": "Catalyst Core", "desc": "Elemental Reactions have no cooldown on the same enemy", "max": 1, "adv": true},
		{"id": "spare", "name": "Spare Parts", "desc": "Every 3rd tool you use is refunded", "max": 1, "adv": true},
		{"id": "smagnet", "name": "Salvage Magnet", "desc": "Elites and bosses always drop 2 extra scrap", "max": 1, "adv": true},
		{"id": "uplink", "name": "Drone Uplink", "desc": "Your drone's zaps apply your melee weapon's elemental traits", "max": 1, "adv": true},
		{"id": "anchor", "name": "Phase Anchor", "desc": "Warping to your beacon gives you a random tool (once per floor)", "max": 1, "adv": true},
		{"id": "lullaby", "name": "Lullaby", "desc": "Each unseen kill has a 25% chance to put the nearest awake enemy to sleep", "max": 1, "adv": true},
		{"id": "amark", "name": "Assassin's Mark", "desc": "After a sneak attack the target can't strike back, wake its partner or raise the alarm for 3 steps", "max": 1, "adv": true},
		{"id": "ammofab", "name": "Ammo Fabricator", "desc": "Every 8 steps without shooting restores 1 ammo", "max": 1, "adv": true},
		{"id": "scrubber", "name": "Oxygen Scrubber", "desc": "Kills while under half air restore +3 air", "max": 1, "adv": true},
		{"id": "gcoin", "name": "Gambler's Coin", "desc": "Each floor rolls a random buff for that floor: +10% crit, +10% dodge, or +1 coin value", "max": 1, "adv": true},
		{"id": "bbattery", "name": "Blood Battery", "desc": "+30% damage, but every attack costs 1% of your max health", "max": 1, "curse": true, "adv": true},
		{"id": "uwarp", "name": "Unstable Warp", "desc": "Beacon warps don't use up the beacon, but every warp roots you: press move 5 times to break free", "max": 1, "curse": true, "adv": true},
		{"id": "ocell", "name": "Overcharged Cell", "desc": "Your class power recharges twice as fast, but your max shield is cut to 25%", "max": 1, "curse": true, "adv": true},
		{"id": "ember", "name": "Ember Lantern", "desc": "Lanterns hold the dark back 12 steps, but spikes cost 2 more", "max": 1, "curse": true},
	]
	synergies = [
		{"a": "vanguard", "b": "alchemist", "text": "Potions give +1 more level"},
		{"a": "slowdark", "b": "lantern", "text": "Lanterns hold the dark back 12 steps"},
		{"a": "skeleton", "b": "boots", "text": "Gates need 1 less level again"},
		{"a": "phoenix", "b": "aegis", "text": "Phoenix revive also gives +1 level"},
		{"a": "pyro", "b": "frost", "adv": true, "text": "Steam: enemies both burning and frozen take +50% damage"},
		{"a": "storm", "b": "frost", "adv": true, "text": "Arc Chain also chills its targets for 1 step"},
		{"a": "pyro", "b": "toxi", "adv": true, "text": "Burning enemies take double poison damage"},
		{"a": "bloodpact", "b": "thornmail", "adv": true, "text": "Reflected thorn damage heals you 1"},
		{"a": "hood", "b": "deadeye", "adv": true, "text": "Shots at max range execute below +10% more health"},
		{"a": "luckychip", "b": "prism", "adv": true, "text": "Crits refund the extra air Prism Lens costs"},
		{"a": "amidas", "b": "scrapper", "adv": true, "text": "Scrapper's extra coin chance rises to 50%"},
		{"a": "uplink", "b": "storm", "adv": true, "text": "Drone zaps arc to another enemy within 2 tiles for 50%"},
		{"a": "bedge", "b": "bloodpact", "adv": true, "text": "Bleeding Edge heals double"},
		{"a": "spare", "b": "anchor", "adv": true, "text": "Refunded tools also give 3 shield"},
		{"a": "plating", "b": "thornmail", "adv": true, "text": "Enemy shots you take reflect 2 damage at the shooter"},
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
		"beacon": {"name": "Warp Beacon", "desc": "Use to drop a beacon, use again to warp back to it", "col": Color("a68cff"), "adv": true, "sk": true},
		"ammopack": {"name": "Ammo Pack", "desc": "Refills half your max ammo", "col": Color("ffc24f"), "adv": true},
		"sleepdart": {"name": "Sleep Dart", "desc": "Puts an enemy within 4 tiles that hasn't seen you to sleep for 10 steps", "col": Color("c9a2ff"), "adv": true},
		"smoke": {"name": "Smoke Bomb", "desc": "A smoke cloud around you for 5 steps: enemies can't see you inside it and lose track of you", "col": Color("b8c0d0"), "adv": true},
		"noise": {"name": "Noise Maker", "desc": "Throw it up to 6 tiles: enemies within 4 tiles of it turn to look, and hunters chase it for 4 steps", "col": Color("ffb347"), "adv": true},
		"patch": {"name": "Cloak Patch", "desc": "Invisible and silent for 4 steps, or until you attack", "col": Color("8f9bd8"), "adv": true},
	}
	class_defs = [
		{"id": "scout", "name": "Scout", "desc": "The dark waits +1 step per ring. Starts with a Time Crystal.", "col": Color("4fd1ff"), "lvl": 0, "per": 1, "kit": ["crystal"]},
		{"id": "brute", "name": "Brute", "desc": "+2 starting levels, but the dark is 1 step faster. Starts with a Bomb.", "col": Color("ff6a5c"), "lvl": 2, "per": -1, "kit": ["bomb"]},
		{"id": "mystic", "name": "Mystic", "desc": "A shield every floor and +1 item slot. Starts with a Shadow Cloak.", "col": Color("c07cff"), "lvl": 0, "per": 0, "kit": ["cloak"]},
		{"id": "gambler", "name": "Gambler", "desc": "Begins with 2 random relics (maybe cursed!) and sees 4 relic cards, not 3.", "col": Color("ffd84f"), "lvl": 0, "per": 0, "kit": []},
		{"id": "gunslinger", "name": "Gunslinger", "desc": "Starts with an Ammo Pack, but the dark is 1 step faster.", "col": Color("ff9a4f"), "lvl": 0, "per": -1, "kit": ["ammopack"]},
		{"id": "engineer", "name": "Engineer", "desc": "A combat drone follows you and zaps enemies. Starts with a Pulse Scanner.", "col": Color("4fd1c5"), "lvl": 0, "per": 0, "kit": ["scan"]},
		{"id": "medic", "name": "Medic", "desc": "Medkits heal 50% more and kills heal 3% of max health. Starts with a Nano Injector.", "col": Color("ff8a9a"), "lvl": 0, "per": 0, "kit": ["nano"]},
		{"id": "hacker", "name": "Hacker", "desc": "Bump enemy turrets to hack them for 8 steps. Starts with a Decoy Beacon.", "col": Color("6dff9a"), "lvl": 0, "per": 0, "kit": ["decoy"]},
		{"id": "salvager", "name": "Salvager", "desc": "+1 starting level. Selling gear gives scrap and sells for 25% more. Starts with a Plating Kit.", "col": Color("c9a36b"), "lvl": 1, "per": 0, "kit": ["plate"]},
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
		{"id": "p_elem", "name": "Elemental Pack", "desc": "17 fire, shock, cryo and toxic traits + 4 relics", "costs": [80]},
		{"id": "p_blood", "name": "Bloodthirst Pack", "desc": "6 heal, execute and kill traits + 3 relics", "costs": [70]},
		{"id": "p_combo", "name": "Combo Pack", "desc": "6 streak, crit, XP and step traits + 1 relic", "costs": [70]},
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
	_nr_setup()


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
	return id == "scout" or up("c_" + id) > 0 or _deed_done(id)


func _pack_open(kind: String, id: String) -> bool:
	for pk in PACKS:
		if (PACKS[pk][kind] as Array).has(id):
			return up(String(pk)) > 0
	if kind == "r" and id.begins_with("nr_"):
		return up(_nr_pack_of(id)) > 0
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
	if relic_n(a) <= 0 or relic_n(b) <= 0:
		return false
	for sy in synergies:
		if (sy["a"] == a and sy["b"] == b) or (sy["a"] == b and sy["b"] == a):
			return bool(sy.get("adv", false)) == (mode == "adv")
	return false


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
	if relic_n("boots") > 0 or gm("surefoot"):
		return 0
	return maxi(0, 2 + (2 if relic_n("ember") > 0 else 0))


func start_shield() -> bool:
	return relic_n("aegis") > 0 or cls == "mystic"


func slots_n() -> int:
	return 2 + (1 if cls == "mystic" else 0) + relic_n("bandolier") + int(sk("slots")) + int(gear("slots"))


func kill_gain(c: Vector2i) -> int:
	return (2 + relic_n("slayer") if elite.has(c) else 1) + relic_n("blade")


func gcoin_buff() -> int:
	if mode != "adv" or relic_n("gcoin") <= 0:
		return -1
	return absi(adv_seed + floor_n * 7) % 3


func coin_val() -> int:
	var cvb := _coin_val_base()
	if not gm("gcompass"):
		return cvb
	var cvf := float(cvb) * 1.25
	return int(cvf) + (1 if randf() < fmod(cvf, 1.0) else 0)


func _coin_val_base() -> int:
	var v := 1 + int(gear("coin")) + int(sk("coin")) + (1 if gcoin_buff() == 2 else 0)
	if relic_n("midas") > 0:
		v *= 2
	v += relic_n("amidas")
	if relic_n("greedy") > 0:
		v *= 3
	if relic_n("nr_debt") > 0:
		v = int(round(float(v) * 1.5))
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
	cfg.set_value("ui", "tut_m", bool(tut_seen.get("map", false)))
	cfg.set_value("lb", "uid", lb_uid)
	cfg.set_value("lb", "sent_puzzle", int(lb_sent["puzzle"]))
	cfg.set_value("lb", "sent_adv", int(lb_sent["adv"]))
	cfg.set_value("s", "shop_v2", true)
	cfg.set_value("s", "cos_kill", cos_kill)
	_mx_save(cfg)
	_ul_save(cfg)
	for k in ups:
		cfg.set_value("ups", k, int(ups[k]))
	cfg.save("user://best.cfg")


func tidx() -> int:
	return ((floor_n - 1) / 3) % themes.size()


# Deep worlds: adventure floors 21+ use darker variants of the four worlds (same art set, new names and palettes).
const DEEP_THEMES := [
	{"name": "VOID REACTOR", "bg": Color("06040f"), "tile": Color("140e2c"), "tile2": Color("1a1238"), "wall": Color("4a3a7a"), "accent": Color("8a6cff"), "dark": Color("010006"), "boss": "Void Core"},
	{"name": "BLIGHTED ARBORETUM", "bg": Color("120d06"), "tile": Color("2a2410"), "tile2": Color("332c14"), "wall": Color("6b5a2a"), "accent": Color("d8ff4f"), "dark": Color("050300"), "boss": "Blight Mother"},
	{"name": "DROWNED VAULT", "bg": Color("04101a"), "tile": Color("0c2433"), "tile2": Color("102c3e"), "wall": Color("2f6a80"), "accent": Color("4fffe0"), "dark": Color("000508"), "boss": "Drowned Baron"},
	{"name": "SHATTERED RIFT", "bg": Color("1a0610"), "tile": Color("340e22"), "tile2": Color("40122a"), "wall": Color("a03a6a"), "accent": Color("ff4f9a"), "dark": Color("080005"), "boss": "Rift Titan"},
]
var themes_deep: Array = []


func _deep_world() -> bool:
	return mode == "adv" and floor_n > 20 and not in_base and not tutorial and not testroom


func cur_theme() -> Dictionary:
	if _deep_world():
		if themes_deep.size() != themes.size():
			themes_deep.clear()
			for i in themes.size():
				var d: Dictionary = themes[i].duplicate()
				d.merge(DEEP_THEMES[i % DEEP_THEMES.size()], true)
				themes_deep.append(d)
		return themes_deep[tidx()]
	return themes[tidx()]


# Theme index of the current boss (Deep Station rematches pick a random arena boss).
func _boss_ti() -> int:
	if deep_run and arena:
		var i := ["core", "queen", "lord", "titan"].find(String(arena_d.get("kind", "")))
		if i >= 0:
			return i
	return tidx()


func _boss_name() -> String:
	var bi := _boss_ti()
	if bi == tidx():
		return String(cur_theme()["boss"])
	if _deep_world():
		return String(DEEP_THEMES[bi % DEEP_THEMES.size()]["boss"])
	return String(themes[bi]["boss"])


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
			eq[sl] = _gart(gb(String(equip[sl])))
		if ranged_mode and _weapon_range() > 0 and eq.has("ranged"):
			eq["weapon"] = eq["ranged"]
	return spr_gen.player((cdef()["col"] as Color), _cls_art(cls), frame, dd, eq)


func _gear_tex(id: String) -> ImageTexture:
	var sl := String(gear_defs[gb(id)]["slot"])
	return spr_gen.gear_icon(_gart(gb(id)), "weapon" if sl == "ranged" else sl)


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


# Mostly one floor tile, others scattered by a stable hash (no checker).
func _floor_at(ti: int, x: int, y: int) -> ImageTexture:
	var h: int = _tile_hash(x + 13, y + 211)
	if h % 100 < 80:
		return _floor_tex(ti, 0, 0)
	return _floor_tex(ti, (h / 100) % 2, (h / 200) % 16)


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
	var h: int = _tile_hash(x + 57, y + 91)
	if h % 100 < 80:
		return 0
	return 1 + (h / 100) % (WALL_VARS - 1)


func _monster_tex(ti: int, lvl: int, boss: bool, blink := false, dir := 0) -> ImageTexture:
	return spr_gen.monster(ti, lvl, boss, blink, dir)


func _mon_face(c: Vector2i) -> int:
	if mode != "adv":
		return 0
	if mon_idle.has(c):
		return _idle_dir(c)
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
		msg = "BOSS FLOOR: defeat the %s to leave" % _boss_name()
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
	boss_floor = (floor_n == mini_world * 3 + 3) if mini else floor_n % 5 == 0
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
		if use_defs[k].has("sk"):
			continue
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
				back = int(thief_held[nc]) * maxi(1, int(sk("repo")))
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
	nr_m.erase(c)
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
	if mini:
		_mini_end("Knocked out: " + why)
		return
	if tutorial or testroom or in_base:
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
	if not rv_used and not test_pending and _ads().rewarded_ready():
		rv_ask = true
		rv_why = why
		walk.clear()
		aim = -1
		state = DEAD
		state_t = t
		_sfx("death")
		over_title = "KNOCKED DOWN"
		return
	_die_final(why)


func _ads() -> Node:
	return get_node("/root/Ads")


func _ad_revive_done(ok: bool) -> void:
	rv_busy = false
	rv_ask = false
	if not ok:
		_die_final(rv_why)
		return
	rv_used = true
	hp = maxi(1, hp_cap() / 2)
	oxy = oxy_max
	state = PLAY
	state_t = t
	msg = "Revived! Back on your feet with half health"
	_pop(pos, "REVIVED", Color("6dff9a"))
	_sfx("shield")


func _ad_double_done(ok: bool) -> void:
	rv_busy = false
	if not ok or ad_doubled:
		return
	ad_doubled = true
	bank += ad_delta
	_save_meta()
	over_sub += "\nAd bonus: +%d coins (total %d)" % [ad_delta, bank]
	_sfx("coin")


func _ad_core_done(ok: bool) -> void:
	rv_busy = false
	if not ok or not ad_boss:
		return
	ad_boss = false
	_ads().boss_bonus_used()
	cores += 1
	run_cores += 1
	_save_meta()
	over_sub += "\nAd bonus: +1 CORE"
	_sfx("coin")


func _die_final(why: String) -> void:
	ad_run_pending = true
	if mode == "adv":
		_fx_burst(vis_pos, Color("ff5d5d"), 30, 5.0, 1.0, 7.0)
		_fx_ring(vis_pos, Color("ff5d5d"), 1.6, 0.8, 6.0)
		_fx_ring(vis_pos, Color.WHITE, 0.9, 0.5, 3.0)
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
	var mxb := _mx_bank_bonus(delta)
	delta += mxb
	bank += delta
	run_banked += delta
	ad_delta = delta
	ad_doubled = false
	_mx_death()
	var ul_line := _ul_run_end()
	_save_meta()
	_lb_note(reached, true)
	_sfx("death")
	over_title = "YOU DIED"
	var dl: PackedStringArray = PackedStringArray([why, "Floor %d   Level %d" % [floor_n, level]])
	if mode == "adv":
		dl.append("Kills %d   Best hit %d   Damage %d" % [run_kills, run_best, run_dmg])
		dl.append("Steps %d   Gear found %d" % [run_steps, run_gear])
	dl.append("Floors cleared %d   Best %d%s" % [reached, adv_best if mode == "adv" else best, "   NEW BEST!" if was_best else ""])
	dl.append("Banked +%d coins (total %d)" % [delta, bank])
	if mode == "adv" and _mx_on() and ul(4):
		dl.append(_mx_death_line(mxb))
	if ul_line != "":
		dl.append(ul_line)
	over_sub = "\n".join(dl)


func _clear() -> void:
	if not mini:
		_lb_note(floor_n, false)
	walk.clear()
	aim = -1
	_sfx("clear")
	clear_t0 = t
	if mode == "adv":
		var cac: Color = cur_theme()["accent"]
		_fx_burst(vis_pos, cac, 34, 5.5, 0.9, 7.0)
		_fx_burst(vis_pos, Color("ffd84f"), 18, 3.5, 1.1, 5.0)
		_fx_ring(vis_pos, cac, 1.4, 0.6, 6.0)
		_fx_ring(vis_pos, Color.WHITE, 2.4, 0.8, 3.0, 0.15)
	over_title = "BOSS DEFEATED" if boss_floor else "FLOOR %d CLEARED" % floor_n
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
	relic_choices = []
	mini_done = mini and boss_floor
	if mini_done:
		over_sub = "You earned %d coins" % coins
	state = CLEAR


func _roll_relics(extra: int) -> Array:
	var normal: Array = []
	var cursed: Array = []
	for d in relic_defs:
		if d.has("adv") != (mode == "adv"):
			continue
		if not relic_open(String(d["id"])):
			continue
		if relic_n(String(d["id"])) < int(d["max"]):
			if d.has("curse"):
				if ul(5):
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
	if mini:
		_go_floor("standard")
		return
	if (floor_n + 1) % 5 == 0:
		_go_floor("standard")
	else:
		door_choices = _roll_doors()
		state = FORK


func _fade_out(cb: Callable) -> void:
	fade_to = 1.0
	fade_cb = cb


func _after_clear_fade() -> void:
	clear_pend = false
	relic_pick = -1
	if relic_choices.size() > 0:
		state = RELIC
	else:
		_relic_done()


func _relic_done() -> void:
	relic_pick = -1
	_finish_clear()
	floor_msg_t = t


func _intro_done() -> void:
	if not bool(tut_seen.get("map", false)):
		tut_seen["map"] = true
		_save_meta()
		_tut_map_start()
	else:
		state = MODE


func _draw_fade() -> void:
	if fade_a > 0.0:
		draw_rect(Rect2(-60, -60, 840, 1500), Color(0, 0, 0, fade_a))


func _draw_floor_msg(acc: Color) -> void:
	_streak_draw()
	var u := t - floor_msg_t
	if arena and mode == "adv" and not in_base:
		_boss_card(u, acc)
		return
	if u < 0.0 or u > 2.4 or state != PLAY:
		return
	var a := clampf(minf(u / 0.35, (2.4 - u) / 0.5), 0.0, 1.0)
	draw_rect(Rect2(-60, -60, 840, 1500), Color(0, 0, 0, 0.35 * a))
	var r := Rect2(110, 520 + (1.0 - a) * 30.0, 500, 170)
	_abox(r, Color(0.03, 0.04, 0.08, 0.92 * a))
	_aline(r, Color(acc.r, acc.g, acc.b, a), 3.0)
	var ttl := "BOSS ARENA" if (mode == "adv" and arena) else "FLOOR %d" % floor_n
	_txt(ttl, Vector2(r.position.x, r.position.y + 90), 60, Color(acc.r, acc.g, acc.b, a), r.size.x)
	_txt(String(cur_theme()["name"]), Vector2(r.position.x, r.position.y + 140), 22, Color(1, 1, 1, 0.75 * a), r.size.x)


func _draw_clear_pop(acc: Color) -> void:
	var w0 := t - clear_t0

	if w0 < 0.6:
		var k := clampf(w0 / 0.18, 0.0, 1.0)
		var sc := 1.6 - 0.6 * (1.0 - pow(1.0 - k, 3.0))
		draw_rect(Rect2(-60, -60, 840, 1500), Color(1, 1, 1, 0.25 * (1.0 - clampf(w0 / 0.25, 0.0, 1.0))))
		_txt("BOSS DOWN!" if boss_floor else "CLEAR!", Vector2(0, 600), int(78.0 * sc), Color(acc.r, acc.g, acc.b, k))
		return
	var u := clampf((w0 - 0.6) / 0.35, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - u, 3.0)
	draw_rect(Rect2(-60, -60, 840, 1500), Color(0, 0, 0, 0.6 * e))
	var dy := (1.0 - e) * 120.0
	var r := Rect2(70, 400 + dy, 580, 470)
	_abox(r, Color(0.03, 0.04, 0.08, 0.95 * e))
	_abox(r, Color(acc.r, acc.g, acc.b, 0.1 * e))
	_aline(r, Color(acc.r, acc.g, acc.b, e), 3.0)
	_txt(over_title, Vector2(r.position.x, r.position.y + 86), T_TITLE, Color(acc.r, acc.g, acc.b, e), r.size.x)
	var ly := r.position.y + 150.0
	for line in over_sub.split("\n"):
		_txt(line, Vector2(r.position.x, ly), 24, Color(1, 1, 1, 0.85 * e), r.size.x)
		ly += 36.0
	if u < 1.0:
		return
	if mini_done:
		_button(btn_cl_next, "COLLECT %d COINS" % coins, Color("ffc93c"), 28)
		return
	_button(btn_cl_next, "NEXT FLOOR", Color("6dff9a"), 30)
	_button(btn_cl_menu, ("LEAVE WITH %d COINS" % coins) if mini else "MENU", Color(1, 1, 1, 0.75), 24)
	if ad_boss and _ads().rewarded_ready():
		_button(btn_ad_core, "BONUS BOSS CORE (%s)" % _ads().tag(), Color("ff4fd8"), 24)


# ---------- puzzle mini-game (from the shop) ----------
func _mini_rect(i: int) -> Rect2:
	return Rect2(60, 360 + i * 150, 600, 130)


func _deep(v: Variant) -> Variant:
	if v is Dictionary or v is Array:
		return v.duplicate(true)
	if typeof(v) >= TYPE_PACKED_BYTE_ARRAY:
		return v.duplicate()
	return v


func _adv_stash() -> void:
	mini_snap = {}
	for k in SAVE_VARS + ["run_kills", "guide_seen", "trade_cell"]:
		mini_snap[k] = _deep(get(k))
	mini_snap["inv"] = inv.duplicate()
	mini_snap["bag"] = bag.duplicate()


func _adv_unstash() -> void:
	for k in mini_snap:
		if k != "inv" and k != "bag":
			set(k, mini_snap[k])
	inv.assign(mini_snap["inv"])
	bag.assign(mini_snap["bag"])
	mini_snap = {}
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
	_adv_update_vis()
	_play_music(tidx())


func _mini_start(w: int) -> void:
	_adv_stash()
	mini = true
	mini_world = w
	mini_ret = shop_return
	mini_done = false
	mini_pick = false
	mini_prev_save_off = save_off
	save_off = true
	mode = "puzzle"
	if cls == "" or not class_open(cls):
		cls = "scout"
	_new_run(w * 3 + 1)
	relics.clear()
	_begin_floor()
	floor_msg_t = t


func _mini_win() -> void:
	_mini_end("Boss beaten!")


func _mini_end(why: String) -> void:
	var g := maxi(0, coins)
	mini = false
	mini_done = false
	save_off = mini_prev_save_off
	_adv_unstash()
	if in_base:
		state = PLAY
		msg = "Puzzle practice: %s" % why
		_sfx("ui")
		return
	coins += g
	state = TRADE
	trade_med = false
	mini_msg = "%s\n+%d coins" % [why, g]
	_sfx("coin")


func _go_floor(fm: String) -> void:
	floor_n += 1
	sw_used = false
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
	if SHOP_RELIC_IDS.has(id) or NR_PACKS.has(id):
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
			"brute": "Iron Stance: blocks 75% of the next 2 hits. Recharges in 30 steps.",
			"mystic": "Hex Mark: your next hit deals double damage. Recharges in 35 steps.",
			"gambler": "Reshuffle: rerolls all your tools. Recharges in 50 steps.",
			"gunslinger": "Ricochet: your next shot deals double damage and bounces to a second enemy within 3 tiles for the same damage. Recharges in 25 steps.",
			"engineer": "Arc Pulse: zaps every enemy within 2 tiles for your attack and stuns them for a step. Recharges in 30 steps.",
			"medic": "Field Surgery: heals 30% of max health and cures acid, frost and burns. Recharges in 45 steps.",
			"hacker": "Hijack: take control of the toughest enemy within 4 tiles for 8 steps. It hunts and attacks other enemies for you. Recharges in 35 steps.",
			"salvager": "Strip Down: tear into the nearest enemy within 2 tiles for 200% of your attack. If it dies it is salvaged for scrap, coins and a 25% gear chance. Recharges in 25 steps.",
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
		return Rect2(712.0 - (slots_n() - i) * (sz + 8.0), 1054.0 - sz + adv_ex, sz, sz)
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
	"engineer": {"n": "Arc Pulse", "cd": 30},
	"medic": {"n": "Field Surgery", "cd": 45},
	"hacker": {"n": "Hijack", "cd": 35},
	"salvager": {"n": "Strip Down", "cd": 25},
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
		"engineer":
			ok = _act_engineer()
		"medic":
			ok = _act_medic()
		"hacker":
			ok = _act_hacker()
		"salvager":
			ok = _act_salvager()
	if ok:
		if gm("overcell"):
			sh = mini(sh_cap(), sh + 4)
		_mx_power_used()
		act_cd = int(ceil(float(ACTS[cls]["cd"]) * _mx_cd_mult() * (0.8 if gm("cdgem") else 1.0) * (1.0 - (sk("pcell") + gear("pcell")) / 100.0) * (0.5 if relic_n("ocell") > 0 else 1.0)))
		act_cd = maxi(0, act_cd - pw_refund)
		pw_refund = 0


func _act_scout() -> bool:
	if mode == "adv":
		_mx_scout_breath()
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
		_mx_brute_stance()
	else:
		boost = maxi(boost, 3)
		msg = "Iron Stance: your next fight counts +3 levels"
	_pop(pos, "STANCE", Color("ff6a5c"))
	_act_fx(Color("ff6a5c"))
	_sfx("shield")
	return true


func _act_gambler() -> bool:
	if inv.is_empty() and not (mode == "adv" and _pw() >= 1):
		return _act_fail("No tools to reshuffle")
	for i in inv.size():
		inv[i] = _random_use()
	_mx_reshuffle()
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
		_mx_rico_load()
		msg = "Ricochet loaded: your next shot deals double damage and bounces to a second target for the same damage"
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


func _act_ricochet(from: Vector2i, dmg: int, quiet := false) -> void:
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
		if not quiet:
			msg += "  (no second target for the ricochet)"
		return
	_fx_bolt(Vector2(from), Vector2(best), Color("ffd84f"))
	_pop(best, "RICOCHET", Color("ffd84f"))
	_adv_damage_mon(best, dmg, Color("ffd84f"))
	if not quiet:
		msg += "  It ricochets for %d!" % dmg


func _act_mystic() -> bool:
	if mode == "adv":
		hex_armed = true
		hex_left = int(sk("hexn"))
		msg = "Hex Mark: your next hit deals %s damage" % _mx_hex_txt()
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
	if save_off or mini:
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
	state = CLEAR if clear_pend else PLAY
	save_last_sig = _save_sig()
	save_t = t
	return true


func _xfer_pack() -> PackedByteArray:
	var meta := {"best": best, "adv_best": adv_best, "bank": bank, "ups": ups.duplicate(), "v2": true, "mx": _mx_pack()}
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
	_mx_unpack(meta.get("mx", {}))
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
	_mx_wipe()
	reset_armed = -10.0
	_save_meta()
	_sfx("death")


func _new_run(start_floor := 1) -> void:
	deep_run = false
	floor_n = start_floor
	clear_pend = false
	coins = 0
	run_kills = 0
	run_best = 0
	run_dmg = 0
	run_steps = 0
	run_gear = 0
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
			if rd.has("adv") == (mode == "adv") and relic_open(String(rd["id"])):
				pool.append(rd)
		pool.shuffle()
		for i in 2:
			var d: Dictionary = pool[i]
			relics[d["id"]] = 1
	if up("ash") > 0:
		relics["phoenix"] = 1
	var safe_pool: Array = []
	for d2 in relic_defs:
		if d2.has("adv") != (mode == "adv"):
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
	if state == SKILLS and _sk_gui(event):
		return
	if state == CODEX and _cx_gui(event):
		return
	if state == INTRO:
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed) or (event is InputEventScreenTouch and event.pressed):
			_intro_done()
		return
	if fade_to > 0.0 or (state == RELIC and relic_pick != -1):
		return
	if tutorial and state == PLAY and tut_dlg != "":
		if event is InputEventMouseButton and event.pressed:
			tut_dlg = ""
			swipe_on = false
			_sfx("ui")
		return
	if state == TUTORIAL and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			tut_sw = event.position
		elif tut_sw.x >= 0.0:
			var tdx: float = event.position.x - tut_sw.x
			tut_sw = Vector2(-1, -1)
			if absf(tdx) > 90.0:
				var tn := _tut_pages(tut_mode).size()
				tut_page = (tut_page + (1 if tdx < 0.0 else tn - 1)) % tn
				_sfx("ui")
				return
	if state == INV and inv_tab == 0 and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			chr_drag = event.position.y >= 256.0 and event.position.y <= 1132.0
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
				_stat_tap(chr_press)
			return
	if state == INV and inv_tab == 0:
		if chr_drag and event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
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
	if _lst_state() and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN or event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				lst_off = clampi(lst_off + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, _lst_max())
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _lst_area().has_point(event.position):
					lst_on = true
					lst_press = event.position
					lst_moved = false
					lst_acc = 0.0
					return
			elif lst_on:
				lst_on = false
				if lst_moved:
					return
				tap_pos = lst_press
	if lst_on and event is InputEventMouseMotion:
		if not lst_moved and event.position.distance_to(lst_press) > 14.0:
			lst_moved = true
		if lst_moved:
			lst_acc -= event.relative.y
			while absf(lst_acc) >= 80.0:
				var lstp := 1 if lst_acc > 0.0 else -1
				lst_off = clampi(lst_off + lstp, 0, _lst_max())
				lst_acc -= 80.0 * lstp
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if state == CLASS:
			if wd_open:
				cswipe_start = Vector2(-1, -1)
			elif event.pressed:
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
	if state == MASTERY:
		_mx_input(p)
		return
	if state == CODEX:
		_cx_input(p)
		return
	if state == CONTRACTS:
		_ctb_input(p)
		return
	if state == WORKSHOP:
		_ws_input(p)
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
		if btn_quit.has_point(p):
			get_tree().quit()
			return
		if btn_mode_a.has_point(p):
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
		if wd_open:
			_wd_input(p)
			return
		if btn_wd.has_point(p):
			wd_open = true
			wd_prev = ""
			_sfx("ui")
			return
		if btn_modeback.has_point(p):
			state = MODE
			test_pending = false
			_sfx("ui")
			return
		if btn_cl_l.has_point(p):
			if cls_page > 0:
				cls_page -= 1
				cls_det = false
				_sfx("ui")
			return
		if btn_cl_r.has_point(p):
			if cls_page < class_defs.size() - 1:
				cls_page += 1
				cls_det = false
				_sfx("ui")
			return
		if btn_cpick.has_point(p):
			if DEEDS.has(String(class_defs[cls_page]["id"])) and not class_open(String(class_defs[cls_page]["id"])):
				_sfx("blocked")
				return
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
			_base_start()
			return
		if class_open(String(class_defs[cls_page]["id"])) and btn_cdet.has_point(p):
			cls_det = not cls_det
			_sfx("ui")
		return
	if state == CLEAR:
		if t - state_t < 0.35 or t - clear_t0 < 0.95 or rv_busy:
			return
		if ad_boss and _ads().rewarded_ready() and btn_ad_core.has_point(p):
			_sfx("ui")
			rv_busy = _ads().show_rewarded(_ad_core_done)
			return
		if btn_cl_next.has_point(p):
			ad_boss = false
			_sfx("ui")
			_fade_out(_mini_win if mini_done else _after_clear_fade)
		elif btn_cl_menu.has_point(p) and not mini_done:
			_sfx("ui")
			if mini:
				_mini_end("You left the puzzle run")
			else:
				clear_pend = true
				_save_run()
				state = MODE
		return
	if state == RELIC:
		if btn_skip.has_point(p):
			coins += _skip_val()
			_sfx("coin")
			relic_pick = -2
			pick_t = t
			return
		for i in relic_choices.size():
			if _relic_rect(i).has_point(p):
				var ids: Array = relic_choices[i].get("pair", [relic_choices[i]["id"]])
				for id0 in ids:
					var id := String(id0)
					relics[id] = relic_n(id) + 1
					if mode == "adv":
						_adv_relic_applied(id)
				_sfx("big")
				relic_pick = i
				pick_t = t
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
		if mini_msg != "":
			mini_msg = ""
			_sfx("ui")
			return
		if mini_pick:
			for wi in themes.size():
				if _mini_rect(wi).has_point(p):
					_sfx("big")
					_mini_start(wi)
					return
			if btn_back.has_point(p):
				mini_pick = false
				if in_base:
					state = PLAY
				_sfx("ui")
			return
		if btn_back.has_point(p):
			state = shop_return
			_sfx("ui")
			return
		for ti in SHOP_TABS.size():
			if _shop_tab_rect(ti).has_point(p):
				shop_tab = ti
				shop_page = 0
				lst_off = 0
				_sfx("ui")
				return
		var slist := _shop_list()
		for i in 6:
			var idx := lst_off + i
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
		if t - state_t < 0.7 or rv_busy:
			return
		if rv_ask:
			if btn_ad_revive.has_point(p):
				_sfx("ui")
				rv_busy = _ads().show_rewarded(_ad_revive_done)
				if not rv_busy:
					rv_ask = false
					_die_final(rv_why)
			elif btn_ad_giveup.has_point(p):
				_sfx("ui")
				rv_ask = false
				_die_final(rv_why)
			return
		if ad_delta > 0 and not ad_doubled and _ads().rewarded_ready() and btn_ad_double.has_point(p):
			_sfx("ui")
			rv_busy = _ads().show_rewarded(_ad_double_done)
			return
		if btn_newrun.has_point(p):
			state = CLASS
			_sfx("ui")
		return
	# playing
	if mode == "adv":
		_adv_input(p)
		return
	if sk("breathe") > 0.0 and _breathe_rect().has_point(p):
		_breathe()
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
	var tsc := 0.35 if (state == DEAD and t - state_t < 0.45) else 1.0
	if Engine.time_scale != tsc:
		Engine.time_scale = tsc
	if state == INTRO and t - state_t > INTRO_LEN:
		_intro_done()
	if fade_to > 0.0 or fade_a > 0.0:
		fade_a = move_toward(fade_a, fade_to, dt * 2.6)
		if fade_to > 0.0 and fade_a >= 1.0:
			fade_to = 0.0
			var fcb := fade_cb
			fade_cb = Callable()
			if fcb.is_valid():
				fcb.call()
	if state == RELIC and relic_pick != -1 and fade_to == 0.0 and t - pick_t > 0.8:
		_fade_out(_relic_done)
	if tutorial and tut_dlg != "":
		walk.clear()
		joy_on = false
	if bank_disp < 0.0 or absf(bank_disp - bank) < 1.0:
		bank_disp = float(bank)
	else:
		bank_disp = move_toward(bank_disp, float(bank), maxf(2.0, absf(bank_disp - bank) * dt * 5.0))
	if state == MODE or state == SAVES or state == LEADER or state == TUTORIAL or state == SHOP or state == CLASS or state == SETTINGS or state == MASTERY or state == CODEX or state == WORKSHOP or state == CONTRACTS:
		modulate.a = clampf(0.3 + (t - state_t) * 6.0, 0.0, 1.0)
	elif modulate.a < 1.0:
		modulate.a = 1.0
	_anim_update(dt)
	_o2_muffle(dt)
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
	if state != PLAY and joy_on:
		joy_on = false
		joy_dir = Vector2i.ZERO
		swipe_on = false
	if mode == "adv" and state == CLEAR:
		cam = cam.lerp(Vector2(6, 6) if arena else vis_pos, minf(1.0, dt * 12.0))
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
			if walk_t >= 0.15:
				walk_t = 0.0
				var anc: Vector2i = walk.pop_front()
				_adv_step(anc, walk.is_empty())
	elif state == PLAY and walk.size() > 0:
		walk_t += dt
		if walk_t >= 0.16:
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
	if mode == "adv":
		_idle_noise(c, 3)
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
	if mode == "adv":
		_cos_kill_fx(cf, body)
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
	if mode == "adv" and state == PLAY:
		var hd := (Vector2(pos) - vis_pos).length()
		if hd > 0.01 and hd < 1.2:
			o.y -= sin(clampf(hd, 0.0, 1.0) * PI) * AC * 0.08
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
	_trail_tick(prc, sz)
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
	if is_boss and deep_run and arena and c == boss_cell:
		ti = _boss_ti()
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
	_amb_update(dt)
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
		vis_pos = vis_pos.move_toward(tgt, dt * (5.0 + dist * 10.0))
	if dist > 0.05:
		walk_phase += dt * 7.0
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
	_txt("SAVES", Vector2(0, 200), T_TITLE, acc)
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
	if not ul(2):
		return
	var k := t - sk_ban_t0
	if sk_ban_n <= 0 or k < 0.0 or k > 4.0:
		return
	var a := minf(1.0, minf(k / 0.4, (4.0 - k) / 0.6))
	var br := Rect2(110, 352, 500, 84)
	_abox(br, Color(0.05, 0.06, 0.1, 0.88 * a))
	_aline(br, Color(1.0, 0.85, 0.31, a), 3.0)
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
	MAPB = 962.0 + ex
	AMY = 640.0 + ex * 0.5
	AC = 72.0 if arena else ADV_ZOOM


func _apply_display() -> void:
	var w := get_window()
	if w != null:
		w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS if set_res == 0 else Window.CONTENT_SCALE_MODE_VIEWPORT
		w.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP if set_fit == 0 else Window.CONTENT_SCALE_ASPECT_IGNORE
	Engine.max_fps = set_fps
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if set_filt == 0 else CanvasItem.TEXTURE_FILTER_LINEAR


func _set_rect(i: int) -> Rect2:
	return Rect2(40, 262 + i * 92, 640, 80)


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
	btn_inset = Rect2(btn_invmenu.end.x + 8.0, 40, 150, h)
	btn_incx = Rect2(290, 40, 140, h)


# Adventure bottom cluster (thumb zone): tool row, then badges + class power + weapon toggle.
func _slot_sz() -> float:
	return 84.0 if set_big == 0 else 92.0


func _row2_h() -> float:
	return 96.0 if set_big == 0 else 100.0


func _cancel_rect() -> Rect2:
	return Rect2(16, 1176.0 + adv_ex, 688, 62)


func _settings_input(p: Vector2) -> void:
	if SET_TITLE.has_point(p) and not test_unlocked:
		set_taps = set_taps + 1 if t - set_tap_t < 1.5 else 1
		set_tap_t = t
		if set_taps >= 5:
			test_unlocked = true
			_sfx("big")
		return
	if test_unlocked and BTN_UNLOCK.has_point(p):
		if t - ua_armed < 3.0:
			ua_armed = -10.0
			_unlock_all()
			_sfx("big")
		else:
			ua_armed = t
			_sfx("ui")
		return
	if test_unlocked and BTN_TEST.has_point(p):
		test_pending = true
		if in_base:
			_base_end()
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
	if btn_ad_remove.has_point(p) and _ads().enabled:
		if _ads().no_ads:
			_ads().restore()
		else:
			_ads().buy_remove_ads()
		_sfx("ui")
		return
	if btn_ad_privacy.has_point(p) and _ads().privacy_options_required():
		_ads().show_privacy_options()
		_sfx("ui")
		return
	if btn_sv_back.has_point(p):
		state = set_ret
		set_ret = MODE
		_sfx("ui")
		return
	if set_ret == MODE and btn_wipe.has_point(p):
		if t - reset_armed < 4.0:
			_wipe_progress()
		else:
			reset_armed = t
			_sfx("blocked")
		return
	for i in 8:
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
			elif i == 6:
				set_vib = 1 - set_vib
				_buzz(60)
			else:
				ul_all = 1 - ul_all
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
	if _ads().privacy_options_required():
		_button(btn_ad_privacy, "AD PRIVACY", acc, 18)
	if _ads().enabled:
		var ap: String = _ads().noads_price
		_button(btn_ad_remove, "ADS REMOVED" if _ads().no_ads else ("REMOVE ADS " + ap).strip_edges(), C_GOLD, 18)
		if _ads().buy_msg != "":
			_txt(_ads().buy_msg, Vector2(0, 104), T_SMALL, C_DIM)
	_txt("SETTINGS", Vector2(0, 200), T_TITLE, acc)
	var rows := [
		["RESOLUTION", "NATIVE" if set_res == 0 else "720p", "Native is sharpest. 720p runs faster."],
		["SCREEN", "FIT" if set_fit == 0 else "STRETCH", "Fit keeps the shape. Stretch fills."],
		["FRAME RATE", "%d" % set_fps, "30 saves battery. 60 is smoother."],
		["SCREEN SHAKE", "ON" if set_shake == 1 else "OFF", "Shake on hits and blasts."],
		["MUSIC", String(VOL_NAMES[set_mus]), "Music volume."],
		["SOUND FX", String(VOL_NAMES[set_sfxv]), "Effects volume."],
		["VIBRATION", "ON" if set_vib == 1 else "OFF", "Buzz on hits and taps."],
		["ALL FEATURES", "ON" if ul_all == 1 else "OFF", "Off: features unlock over your first runs."],
	]
	var sc := Color("c9d3f0")
	for i in 8:
		var r := _panel(_set_rect(i), sc, 0.08)
		_txt(String(rows[i][0]), r.position + Vector2(20, 34), T_BODY, Color.WHITE, 400.0, HORIZONTAL_ALIGNMENT_LEFT)
		_txt(String(rows[i][2]), r.position + Vector2(20, 62), T_SMALL, C_DIM, 440.0, HORIZONTAL_ALIGNMENT_LEFT)
		_txt(String(rows[i][1]), r.position + Vector2(400, 52), T_HEAD, C_GOLD, 220.0, HORIZONTAL_ALIGNMENT_RIGHT)
	if set_ret == MODE:
		var armed := t - reset_armed < 4.0
		_button(btn_wipe, "TAP AGAIN: ERASE ALL" if armed else "RESET ALL PROGRESS", C_BAD if armed else Color(1, 1, 1, 0.4), 20)
	_button(btn_sv_back, "BACK", C_GOLD, 28, "back")
	if test_unlocked:
		_button(BTN_TEST, "TEST ROOM", Color("ff8af0"), 24)
		_button(BTN_UNLOCK, "TAP AGAIN!" if t - ua_armed < 3.0 else "UNLOCK ALL", C_BAD if t - ua_armed < 3.0 else C_GOLD, 24)


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
	_txt("LEADERBOARD", Vector2(0, 150), T_TITLE, acc)
	var names := ["PUZZLE", "ADVENTURE"]
	for i in 2:
		var tr := _tut_tabs(i)
		var tc := Color("ffd84f") if i == lb_mode else Color(1, 1, 1, 0.5)
		_abox(tr, Color(tc.r, tc.g, tc.b, 0.16 if i == lb_mode else 0.06))
		_aline(tr, tc, 2.0)
		_ctext(names[i], tr.get_center(), 24, tc)
	var mine := best if lb_mode == 0 else adv_best
	var nm := lb_name if lb_name != "" else "(no name yet)"
	_txt("You: %s    Best: %d floors" % [nm, mine], Vector2(0, 280), 24, Color(1, 1, 1, 0.8))
	if lb_status == "notset":
		_para("Online board is off. Your best is saved on this device.", Vector2(60, 380), 26, Color(1, 1, 1, 0.8), 600.0)
	elif lb_status == "loading":
		_txt("Loading...", Vector2(0, 420), 30, Color(1, 1, 1, 0.6))
	elif lb_status == "error":
		_txt("Could not reach the leaderboard", Vector2(0, 420), 28, Color("ff8a8a"))
		_txt("Check your connection and try again", Vector2(0, 460), T_BODY, C_DIM)
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
				_aline(rc, Color("ffd84f"), 2.0)
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
	return {}


func _tut_pages(which: int) -> Array:
	if which == 0:
		return [
			{"t": "THE GOAL", "ti": 0, "s": [["player", "You"], ["icon:door_locked", "Locked"], ["icon:door_open", "Open"]],
			"b": ["Reach the gate. It shows the level you need.", "Tap any tile to walk there.", "Coins are kept after the run. Spend them in the Outfitter."]},
			{"t": "MONSTERS", "ti": 1, "s": [["mon:1:2:none:g", "Win"], ["mon:1:5:none:a", "Shield"], ["mon:1:4:none:r", "Lose"]],
			"b": ["Walk into a monster to fight it.", "Your level must be HIGHER to win. A win levels you up.", "Green badge wins. Red loses. Amber: only a shield saves you."]},
			{"t": "THE DARK", "ti": 1, "s": [["dark", "Dark"], ["player", "You"], ["icon:spikes", "Spikes"]],
			"b": ["The dark closes in from the edges.", "The meter at the top counts steps until it moves.", "Standing in the dark kills you. Spikes cost extra steps."]},
			{"t": "ITEMS", "ti": 1, "s": [["item:pot", "Potion"], ["item:shield", "Shield"], ["item:lamp", "Lantern"], ["icon:key", "Key"], ["portal", "Portal"]],
			"b": ["Potion: +1 level. Shield: survive one losing fight.", "Lantern: holds the dark back. Key: opens a vault.", "Portals teleport you to their twin."]},
		]
	return [
		{"t": "THE GOAL", "ti": 0, "s": [["player", "You"], ["icon:door_locked", "Sealed"], ["icon:door_open", "Open"]],
		"b": ["Kills, coins and items fill your POINTS bar.", "A full bar opens the exit. Walk in to go deeper.", "Tap a tile to walk there, or drag to steer."]},
		{"t": "FIGHTING", "ti": 1, "s": [["mon:1:3:none:g", "Easy"], ["mon:1:5:none:a", "Costly"], ["mon:1:8:none:r", "Deadly"], ["icon:crate_weapon", "Weapon"]],
		"b": ["Walk into a monster to attack. Tap again to keep fighting.", "Badge colour shows the cost: green, amber, red.", "The round button swaps melee and ranged. Tap a monster to shoot."]},
		{"t": "AIR AND HEALTH", "ti": 0, "s": [["icon:pod", "Air pod"], ["icon:station", "O2"], ["item:hp", "Medkit"], ["icon:medstation", "Medical"]],
		"b": ["Every step costs 1 air. 0 air or 0 health ends the run.", "O2 stations refill your air. Use them as bases.", "Armour cuts every hit. Shield soaks damage first."]},
		{"t": "GEAR AND SKILLS", "ti": 1, "s": [["item:pot", "XP"], ["skn:0", "Skills"], ["use:blink", "Tool"], ["pcls:scout", "Power"]],
		"b": ["Every 3rd level gives a skill point. Spend it in SKILLS.", "BAG: equip gear, use tools, read relics.", "Tools: tap to pick, tap again to use. The coloured button is your class power."]},
		{"t": "DANGER", "ti": 2, "s": [["haz:arc", "Hazard"], ["aff:plated", "Tagged"], ["boss:2", "Boss"]],
		"b": ["Hazards change by world. Bombs clear them.", "Tagged monsters are tougher but drop better loot.", "Hunters (!) chase you. Thieves ($) steal coins."]},
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
	_txt("HOW TO PLAY", Vector2(0, 150), T_TITLE, acc)
	var names := ["PUZZLE", "ADVENTURE", "PRACTICE"]
	for i in (3 if tut_back == MODE else 2):
		var tr := _tut_tabs(i)
		var tc := C_GOLD if i == tut_mode else Color(1, 1, 1, 0.5)
		if i == 2:
			tc = C_GOOD
		_obox(tr, Color(tc.r, tc.g, tc.b, 0.16 if i == tut_mode else 0.06))
		_aline(tr, tc, 2.0)
		_ctext(names[i], tr.get_center(), 22, tc)
	var pages := _tut_pages(tut_mode)
	tut_page = clampi(tut_page, 0, pages.size() - 1)
	var pg: Dictionary = pages[tut_page]
	var card := Rect2(40, 266, 640, 816)
	_frame(card, acc)
	_txt(String(pg["t"]), Vector2(40, 332), 36, acc, 640.0)
	draw_line(Vector2(120, 352), Vector2(600, 352), Color(acc.r, acc.g, acc.b, 0.35), 2.0)
	var icons: Array = pg["s"]
	var n := icons.size()
	var sz := 112.0 if n <= 3 else (96.0 if n == 4 else 84.0)
	var ti: int = pg["ti"]
	for i in n:
		var cx := 40.0 + (i + 0.5) * 640.0 / n
		_tut_icon(String(icons[i][0]), Vector2(cx, 450), sz, ti)
		_txt(String(icons[i][1]), Vector2(cx - 80.0, 450 + sz * 0.5 + 30), T_SMALL, C_TEXT, 160.0)
	_bullets(pg["b"], Vector2(76, 600), 568.0, 24, C_TEXT, acc)
	_dots(pages.size(), tut_page, Vector2(360, 1110), acc)
	_button(btn_tpv, "<", acc, 30)
	_button(btn_tnx, ">", acc, 30)
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


const INTRO_LEN := 6.0
const INTRO_STARS := [Vector3(0.7699, 0.5683, 578), Vector3(0.4027, 0.4893, 476), Vector3(0.1592, 0.0892, 285), Vector3(0.0575, 0.1144, 249), Vector3(0.6661, 0.5650, 193), Vector3(0.4189, 0.0412, 115), Vector3(0.5387, 0.6589, 115), Vector3(0.3444, 0.3438, 110), Vector3(0.3360, 0.4435, 107), Vector3(0.5439, 0.3467, 102), Vector3(0.4691, 0.6590, 101), Vector3(0.5544, 0.4402, 100), Vector3(0.6896, 0.5369, 97), Vector3(0.3494, 0.6950, 93), Vector3(0.4171, 0.6269, 85), Vector3(0.2938, 0.5763, 83), Vector3(0.4111, 0.3306, 82), Vector3(0.4573, 0.5862, 82), Vector3(0.2348, 0.5748, 78), Vector3(0.2392, 0.5156, 68), Vector3(0.2734, 0.5826, 62), Vector3(0.5514, 0.6222, 56), Vector3(0.3662, 0.3267, 50), Vector3(0.5762, 0.4735, 50)]
# x, y (fraction of bg image), radius (fraction of bg width)
const INTRO_PLANETS := [Vector3(0.6958, 0.3049, 0.0581), Vector3(0.1783, 0.4557, 0.0587), Vector3(0.7945, 0.4670, 0.0515), Vector3(0.6286, 0.6001, 0.0260)]
var intro_tex: Dictionary = {}


func _intro_tex(n: String) -> Texture2D:
	if not intro_tex.has(n):
		var p := "res://art/intro/%s" % n
		intro_tex[n] = load(p) if ResourceLoader.exists(p) else null
	return intro_tex[n]


# Intro: art/intro/bg.jpg (1125x2000 corridor + sky, title and planets cut out), planets drift/spin,
# stars twinkle, two shooting stars, title (art/intro/title.png) drops in lower down and floats.
func _draw_intro() -> void:
	var u := t - state_t
	var W := size.x
	var H := size.y
	draw_rect(Rect2(0, 0, W, H), Color(0.03, 0.04, 0.09))
	var bg := _intro_tex("bg.jpg")
	if bg == null:
		return
	var zoom := 1.06 - 0.06 * clampf(u / INTRO_LEN, 0.0, 1.0)
	var sc := maxf(W / 1125.0, H / 2000.0) * zoom
	var iw := 1125.0 * sc
	var ih := 2000.0 * sc
	var o := Vector2((W - iw) * 0.5, (H - ih) * 0.5)
	draw_texture_rect(bg, Rect2(o, Vector2(iw, ih)), false)
	for i in INTRO_PLANETS.size():
		var ptx := _intro_tex("planet%d.png" % i)
		if ptx == null:
			continue
		var pl: Vector3 = INTRO_PLANETS[i]
		var pc := o + Vector2(pl.x * iw + sin(u * 0.7 + i * 1.7) * 6.0 * sc, pl.y * ih + cos(u * 0.9 + i * 2.3) * 9.0 * sc)
		var pr := pl.z * iw
		draw_set_transform(pc, u * (0.12 if i % 2 == 0 else -0.09), Vector2.ONE)
		draw_texture_rect(ptx, Rect2(-pr, -pr, 2.0 * pr, 2.0 * pr), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in INTRO_STARS.size():
		var sv: Vector3 = INTRO_STARS[i]
		var sp := o + Vector2(sv.x * iw, sv.y * ih)
		var tw := pow(0.5 + 0.5 * sin(u * (1.6 + fmod(i * 0.37, 1.3)) + i * 2.1), 3.0)
		var L := (6.0 + sqrt(sv.z) * 1.2) * sc * (0.6 + 0.9 * tw)
		var sc_col := Color(1, 1, 1, 0.85 * tw)
		draw_circle(sp, L * 0.35, Color(0.7, 0.85, 1.0, 0.25 * tw))
		draw_line(sp - Vector2(L, 0), sp + Vector2(L, 0), sc_col, 2.0)
		draw_line(sp - Vector2(0, L), sp + Vector2(0, L), sc_col, 2.0)
	for k in 2:
		var su := (u - (1.2 + k * 2.4)) / 0.7
		if su > 0.0 and su < 1.0:
			var dir := Vector2(1.0, 0.45).normalized()
			var head := Vector2(W * (0.12 + 0.45 * k), H * (0.06 + 0.08 * k)) + dir * su * W * 0.45
			draw_line(head - dir * 140.0 * sc, head, Color(1, 1, 1, 0.8 * (1.0 - su)), 3.0)
	var ttx := _intro_tex("title.png")
	if ttx != null:
		var tu := clampf((u - 0.6) / 0.9, 0.0, 1.0)
		var e := 1.0 + 2.70158 * pow(tu - 1.0, 3.0) + 1.70158 * pow(tu - 1.0, 2.0)
		var tw2 := minf(W * 0.88, iw * 0.80)
		var th := tw2 * 486.0 / 1273.0
		var ty := H * 0.36 - th * 0.5 + sin(u * 1.6) * 6.0 * tu
		draw_texture_rect(ttx, Rect2((W - tw2) * 0.5, lerpf(-th - 40.0, ty, e), tw2, th), false, Color(1, 1, 1, clampf(tu * 3.0, 0.0, 1.0)))
	var su2 := clampf((u - 2.4) / 0.8, 0.0, 1.0)
	_txt("tap to skip", Vector2(0, H - 70.0), 22, Color(1, 1, 1, 0.45 * su2))
	var fi := 1.0 - clampf(u / 0.6, 0.0, 1.0)
	var fo := clampf((u - (INTRO_LEN - 0.5)) / 0.5, 0.0, 1.0)
	if maxf(fi, fo) > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, maxf(fi, fo)))

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
		_draw_tut_dlg()
		_draw_floor_msg(acc)
		_draw_fade()
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
	if state == MODE or state == TUTORIAL or state == LEADER or state == SAVES or state == SETTINGS or state == MASTERY or state == CODEX or state == WORKSHOP or state == CONTRACTS:
		_draw_overlay(acc)
		return
	# HUD
	if state == PLAY:
		var marm := t - menu_armed < 3.0
		_button(btn_menu, "SURE?" if marm else "MENU", Color("ff8a8a") if marm else acc)
	_hud_panels(acc, 84.0)
	_txt("FLOOR %d    BEST %d%s" % [floor_n, best, _mod_label()], Vector2(0, 112), 24, Color(1, 1, 1, 0.6))
	_txt("LV %d" % level, Vector2(40, 205), 72, Color.WHITE, 300.0, HORIZONTAL_ALIGNMENT_LEFT)
	_txt("COINS %d   BANK %d" % [coins, bank], Vector2(40, 238), 22, Color("ffc93c"), 330.0, HORIZONTAL_ALIGNMENT_LEFT)
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
			draw_texture_rect(_floor_at(ti, x, y), r.grow(-1.0), false)
			var dk0 := _deco_at(x, y)
			if dk0 >= 0:
				draw_texture_rect(spr_gen.floor_deco(ti, dk0), r.grow(-1.0), false)
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
	_txt("Green badge wins. Red or equal loses.", Vector2(0, 1130), T_SMALL, C_DIM)
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
	_draw_floor_msg(acc)
	_draw_fade()


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
	for pl in (MENU_PLANETS if state != SKILLS else []):
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
	_abox(r, Color(0.03, 0.04, 0.08, 0.93))
	_abox(r, c)


# angled-corner box, same corner cut as _panel (menu buttons)
func _apts(r: Rect2) -> PackedVector2Array:
	var c := minf(8.0, r.size.y * 0.25)
	var x := r.position.x
	var y := r.position.y
	var w := r.size.x
	var h := r.size.y
	return PackedVector2Array([Vector2(x + c, y), Vector2(x + w - c, y), Vector2(x + w, y + c), Vector2(x + w, y + h - c), Vector2(x + w - c, y + h), Vector2(x + c, y + h), Vector2(x, y + h - c), Vector2(x, y + c)])


func _abox(r: Rect2, col: Color) -> void:
	draw_colored_polygon(_apts(r), col)


func _aline(r: Rect2, col: Color, w := 2.0) -> void:
	var pts := _apts(r)
	pts.append(pts[0])
	draw_polyline(pts, col, w)


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
	elif state in [INV, SKILLS, TRADE, TUTORIAL, LEADER, SAVES, FORK, MARKET, CLASS, SHOP, RELIC, MASTERY, CODEX, WORKSHOP, CONTRACTS]:
		_draw_menu_bg(_menu_tint(acc))
	elif state == DEAD:
		var du := clampf((t - state_t - 0.3) / 0.5, 0.0, 1.0)
		draw_rect(Rect2(0, 0, 720, 1280), Color(0, 0, 0, 0.9 * du))
		draw_rect(Rect2(0, 0, 720, 1280), Color(1, 0.1, 0.1, 0.35 * (1.0 - clampf((t - state_t) / 0.45, 0.0, 1.0))))
	elif state != CLEAR:
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
	elif state == MASTERY:
		_draw_mastery(acc)
	elif state == CODEX:
		_draw_codex(acc)
	elif state == WORKSHOP:
		_draw_workshop(acc)
	elif state == CONTRACTS:
		_draw_contracts(acc)
	elif state == MODE:
		_txt("POCKET STATION", Vector2(0, 300), 64, acc)
		draw_line(Vector2(160, 332), Vector2(560, 332), Color(acc.r, acc.g, acc.b, 0.4), 2.0)
		_txt("Survive the station. Find the exit.", Vector2(0, 376), T_BODY, C_DIM)
		var has_sv := save_info != ""
		btn_cont = Rect2(110, 640, 500, 120)
		btn_mode_a = Rect2(110, 784, 500, 96) if has_sv else Rect2(110, 660, 500, 130)
		if has_sv:
			_panel(btn_cont, C_GOOD, 0.22)
			_txt("CONTINUE", Vector2(btn_cont.position.x, btn_cont.position.y + 62), 44, C_GOOD, btn_cont.size.x)
			_txt(save_info, Vector2(btn_cont.position.x, btn_cont.position.y + 96), T_SMALL, C_TEXT, btn_cont.size.x)
			_button(btn_mode_a, "NEW RUN", C_INFO, 32)
		else:
			_button(btn_mode_a, "PLAY", Color("7dffb0"), 48)
		_button(btn_tut, "HOW TO PLAY", C_GOLD, 22, "help")
		_button(btn_lb, "LEADERBOARD", C_INFO, 22, "trophy")
		_button(btn_quit, "QUIT", Color(1, 1, 1, 0.45), 22)
		_draw_gear(btn_font.get_center(), Color("c9d3f0"))
		var bt := get_node_or_null("/root/Boot")
		_txt("build %d  %s" % [BUILD, (bt.status if bt else "")], Vector2(0, 1274), 14, Color(1, 1, 1, 0.4))
		if t - xfer_t < 6.0:
			_txt(xfer_msg, Vector2(0, 430), T_BODY, C_GOOD)
	elif state == DEAD and rv_ask:
		_txt(over_title, Vector2(0, 400), 64, Color("ffb347"))
		_txt(rv_why, Vector2(0, 470), 26, Color("ffb0a0"))
		_txt("Watch an ad to get back up with half health (once per run)", Vector2(0, 540), 22, Color.WHITE)
		if t - state_t >= 0.7:
			_button(btn_ad_revive, "REVIVE (%s)" % _ads().tag(), Color("6dff9a"), 30)
			_button(btn_ad_giveup, "GIVE UP", Color(1, 1, 1, 0.7), 24)
	elif state == DEAD and t - state_t < 0.65:
		var dk := clampf((t - state_t - 0.2) / 0.4, 0.0, 1.0)
		_txt(over_title, Vector2(0, 400.0 - (1.0 - dk) * 40.0), int(64.0 + 30.0 * (1.0 - dk)), Color(1, 0.36, 0.36, dk))
	elif state == DEAD:
		_txt(over_title, Vector2(0, 400), 64, Color("ff5d5d"))
		var ly := 476
		var li := 0
		for line in over_sub.split("\n"):
			var lc := Color.WHITE
			if li == 0:
				lc = Color("ffb0a0")
			elif line.contains("NEW BEST"):
				lc = Color("ffd84f")
			if line.begins_with("NEW! "):
				# bold yellow: draw twice, 2px apart
				_txt(line, Vector2(-1, ly), 28, Color("ffd84f"))
				_txt(line, Vector2(1, ly), 28, Color("ffd84f"))
			else:
				_txt(line, Vector2(0, ly), 26, lc)
			ly += 42
			li += 1
		if ad_delta > 0 and not ad_doubled and _ads().rewarded_ready():
			_button(btn_ad_double, "DOUBLE COINS +%d (%s)" % [ad_delta, _ads().tag()], Color("ffc93c"), 26)
		_button(btn_newrun, "NEW RUN", Color("ff9d9d"), 28)
	elif state == CLEAR:
		_draw_clear_pop(acc)
	elif state == RELIC:
		_txt(over_title, Vector2(0, 230), T_TITLE, acc)
		_txt(over_sub, Vector2(0, 276), T_SMALL, C_DIM)
		_txt("PICK A RELIC FOR THIS RUN", Vector2(0, 340), T_BODY, C_TEXT)
		for i in relic_choices.size():
			var d: Dictionary = relic_choices[i]
			var rr := _relic_rect(i)
			var cursed := d.has("curse")
			var col := Color("ff6a5c") if cursed else acc
			_obox(rr, Color(col.r, col.g, col.b, 0.12))
			_aline(rr, col, 2.0)
			var own := relic_n(String(d["id"]))
			var title := _aname(String(d["id"]), String(d["name"])) + ("  (have %d)" % own if own > 0 else "")
			_txt(title, Vector2(rr.position.x + 22, rr.position.y + 40), T_HEAD, col, rr.size.x - 40, HORIZONTAL_ALIGNMENT_LEFT)
			if cursed:
				_txt("CURSED", Vector2(rr.end.x - 150, rr.position.y + 40), T_SMALL, C_BAD, 130.0, HORIZONTAL_ALIGNMENT_RIGHT)
			_para_fit(_atext(String(d["id"]), String(d["desc"])), Vector2(rr.position.x + 22, rr.position.y + 74), T_BODY, C_TEXT, rr.size.x - 44, 3)
			var sy_list: Array = []
			for sy0 in synergies:
				if bool(sy0.get("adv", false)) == (mode == "adv") and (sy0["a"] == d["id"] or sy0["b"] == d["id"]):
					var oth0 := String(sy0["b"]) if sy0["a"] == d["id"] else String(sy0["a"])
					if relic_n(oth0) > 0:
						sy_list.push_front(sy0)
					else:
						sy_list.append(sy0)
			for sy in sy_list:
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
					var stxt := ("SYNERGY ON: " + sytxt) if have else ("+ %s: %s" % [oname, sytxt])
					_txt(stxt, Vector2(rr.position.x + 22, rr.end.y - 10), 16, Color("ffd84f") if have else Color(1, 1, 1, 0.45), rr.size.x - 44, HORIZONTAL_ALIGNMENT_LEFT)
					break
		_button(btn_skip, "SKIP  +%d COINS" % _skip_val(), Color(1, 1, 1, 0.75), 24)
		if relic_pick != -1:
			var pk2 := clampf((t - pick_t) / 0.3, 0.0, 1.0)
			for i in relic_choices.size():
				if i != relic_pick:
					_abox(_relic_rect(i), Color(0, 0, 0, 0.65 * pk2))
			var hr := btn_skip if relic_pick == -2 else _relic_rect(relic_pick)
			_abox(hr, Color(1, 0.9, 0.4, 0.12 * pk2))
			_aline(hr.grow(5.0), Color(1, 0.9, 0.4, 0.5 + 0.5 * absf(sin(t * 10.0))), 4.0)
	elif state == FORK:
		_txt("CHOOSE YOUR PATH", Vector2(0, 250), T_TITLE, acc)
		_txt("FLOOR %d" % (floor_n + 1), Vector2(0, 306), T_BODY, C_DIM)
		for i in door_choices.size():
			var dd: Dictionary = door_defs[String(door_choices[i])]
			var dr := _door_rect(i)
			var dcol: Color = dd["col"]
			_obox(dr, Color(dcol.r, dcol.g, dcol.b, 0.12))
			_aline(dr, dcol, 3.0)
			_obox(Rect2(dr.position.x + 24, dr.position.y + 28, 60, 120), Color(dcol.r, dcol.g, dcol.b, 0.25))
			_aline(Rect2(dr.position.x + 24, dr.position.y + 28, 60, 120), dcol, 3.0)
			_txt(String(dd["name"]), Vector2(dr.position.x + 110, dr.position.y + 62), 36, dcol, 480.0, HORIZONTAL_ALIGNMENT_LEFT)
			_para_fit(String(dd["desc"]), Vector2(dr.position.x + 110, dr.position.y + 106), T_BODY, C_TEXT, 480.0, 3)
	elif state == MARKET:
		_txt("MERCHANT", Vector2(0, 250), T_TITLE, C_RARE)
		_txt("COINS %d        SLOTS %d / %d" % [coins, inv.size(), slots_n()], Vector2(0, 306), T_BODY, C_GOLD)
		for i in market_stock.size():
			var it: Dictionary = market_stock[i]
			var mr := _market_rect(i)
			var uid: String = it["id"]
			var can := coins >= int(it["price"]) and inv.size() < slots_n()
			var mcol := Color("6dff9a") if can else Color(1, 1, 1, 0.4)
			_obox(mr, Color(mcol.r, mcol.g, mcol.b, 0.1))
			_aline(mr, mcol, 2.0)
			_use_icon(uid, Vector2(mr.position.x + 56, mr.position.y + 67), 70)
			_txt(_use_name(uid), Vector2(mr.position.x + 110, mr.position.y + 50), 30, Color.WHITE, 340.0, HORIZONTAL_ALIGNMENT_LEFT)
			_para_fit(String(use_defs[uid]["desc"]), Vector2(mr.position.x + 110, mr.position.y + 84), T_SMALL, C_DIM, 340.0, 3)
			_txt("%d coins" % int(it["price"]), Vector2(mr.end.x - 170, mr.position.y + 76), 28, mcol, 150.0, HORIZONTAL_ALIGNMENT_RIGHT)
		if market_stock.is_empty():
			_txt("Sold out!", Vector2(0, 520), 32, Color(1, 1, 1, 0.6))
		_button(btn_back, "LEAVE", acc, 28)
	elif state == CLASS:
		_txt("CHOOSE YOUR CLASS", Vector2(0, 180), T_TITLE, acc)
		_button(btn_modeback, "< BACK", acc)
		_txt("BEST  %d floors        BANK  %d coins" % [adv_best if mode == "adv" else best, bank], Vector2(0, 230), T_SMALL, C_DIM)
		var cd: Dictionary = class_defs[cls_page]
		var ccol: Color = cd["col"]
		var cid := String(cd["id"])
		var copen := class_open(cid)
		var cc := Color(ccol.r, ccol.g, ccol.b) if copen else Color(1, 1, 1, 0.45)
		var card := Rect2(100, 262, 520, 690)
		_obox(card, Color(cc.r, cc.g, cc.b, 0.12))
		_aline(card, cc, 3.0)
		_ctext(String(cd["name"]).to_upper(), Vector2(360, 318), 44, cc)
		if copen:
			_mx_card_line(cid)
		# idle animation: gentle breathing squash and sway
		var isy := 1.0 + 0.03 * sin(t * 2.6)
		var isx := 1.0 + (1.0 - isy) * 0.8
		var ipx := 200.0
		_spr_ex(spr_gen.player(ccol, _cls_art(cid), 0, 0, {}), Vector2(360, 446 - (isy - 1.0) * ipx * 0.5), ipx, Color.WHITE if copen else Color(0.45, 0.45, 0.5, 0.9), 1.0, 0.02 * sin(t * 1.3), isx, isy)
		if copen:
			if cls_det:
				draw_rect(Rect2(112, 348, 496, 212), Color(0.03, 0.04, 0.08, 1.0))
				var ay := _section("ABOUT", 352, cc, 124, 472)
				_para_fit(_atext("cls_" + cid, String(cd["desc"])), Vector2(124, ay + 20), T_BODY, C_TEXT, 472.0, 7)
			else:
				_txt(String(CLASS_BLURB.get(cid, NEW_BLURB.get(cid, ""))), Vector2(100, 596), T_BODY, cc, 520.0)
			_chip(Rect2(124, 624, 180, 40), "START LV %d" % (START_LEVEL + int(cd["lvl"])), C_GOLD)
			if mode != "adv":
				var dk := int(cd["per"])
				_chip(Rect2(314, 624, 150, 40), "DARK NORMAL" if dk == 0 else ("DARK +%d" % dk if dk > 0 else "DARK %d" % dk), C_INFO)
			var kx := 576.0
			for kid in cd["kit"]:
				_use_icon(String(kid), Vector2(kx, 644), 38)
				kx -= 46.0
			var py := _section("POWER", 684, cc, 124, 472)
			_para_fit(_act_desc(cid), Vector2(124, py + 22), 18, C_TEXT, 472.0, 4)
			_button(btn_cdet, "LESS" if cls_det else "DETAILS", cc, 20)
		else:
			_para(_lock_text(cid), Vector2(124, 640), 24, Color(1, 1, 1, 0.6), 472.0)
		_button(btn_cl_l, "<", acc if cls_page > 0 else Color(1, 1, 1, 0.2), 56)
		_button(btn_cl_r, ">", acc if cls_page < class_defs.size() - 1 else Color(1, 1, 1, 0.2), 56)
		for i in (0 if mode == "adv" else class_defs.size()):
			draw_circle(Vector2(360 + (i - (class_defs.size() - 1) * 0.5) * 30.0, 978), 8.0 if i == cls_page else 5.0, cc if i == cls_page else Color(1, 1, 1, 0.3))
		_button(btn_cpick, ("PLAY AS " + String(cd["name"]).to_upper()) if copen else _lock_btn(cid), cc if copen else Color("ffc93c"), 28)
		_button(btn_wd, "WARDROBE", Color("a35cff"), 20)
		if wd_open:
			_draw_wardrobe()

	elif state == SHOP and mini_pick:
		_txt("PUZZLE RUN", Vector2(0, 230), T_TITLE, Color("9fb3d9"))
		_txt("3 floors and a boss. Keep every coin.", Vector2(0, 290), T_BODY, C_DIM)
		for wi in themes.size():
			var wr := _mini_rect(wi)
			var wc: Color = themes[wi]["accent"]
			_obox(wr, Color(wc.r, wc.g, wc.b, 0.12))
			_aline(wr, wc, 2.0)
			_txt(String(themes[wi]["name"]), Vector2(wr.position.x + 24, wr.position.y + 56), 32, wc, wr.size.x - 48, HORIZONTAL_ALIGNMENT_LEFT)
			_txt("Boss: %s" % String(themes[wi]["boss"]), Vector2(wr.position.x + 24, wr.position.y + 98), 22, Color(1, 1, 1, 0.75), wr.size.x - 48, HORIZONTAL_ALIGNMENT_LEFT)
		_button(btn_back, "BACK", acc, 26)
	elif state == SHOP:
		_txt("SHOP", Vector2(0, 230), T_TITLE, C_GOLD)
		_cur_line(284.0)
		_draw_shop_list(acc)
		_button(btn_back, "BACK", acc, 26)
		if mini_msg != "":
			draw_rect(Rect2(0, 0, 720, 1280), Color(0, 0, 0, 0.6))
			var mr3 := Rect2(80, 480, 560, 240)
			_panel(mr3, Color("ffc93c"), 0.2, false)
			var my3 := mr3.position.y + 80.0
			for ml in mini_msg.split("\n"):
				_txt(ml, Vector2(mr3.position.x, my3), 30, Color("ffc93c") if my3 > mr3.position.y + 100.0 else Color.WHITE, mr3.size.x)
				my3 += 52.0
			_txt("Tap to continue", Vector2(mr3.position.x, mr3.end.y - 24), 20, Color(1, 1, 1, 0.6), mr3.size.x)


# ---------- ADVENTURE MODE (sprawling map, fog of war, points gate, air) ----------

func adv_vis_r() -> int:
	if _blackout():
		return 1
	return 4 + relic_n("lantern") + relic_n("ember") + (1 if cls == "scout" else 0) + int(gear("sight")) + int(sk("sight")) - _an_sight() - (1 if _world_rule() == "glare" else 0) - (2 if _world_rule() == "outage" else 0)


var cracked: Dictionary = {}
var crk_f := -1


func _by_wall(c: Vector2i) -> bool:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if (dx != 0 or dy != 0) and not _aopen(c + Vector2i(dx, dy)):
				return true
	return false


func _supply_drop() -> void:
	var opts: Array[Vector2i] = []
	for dx in range(-6, 7):
		for dy in range(-6, 7):
			var c := pos + Vector2i(dx, dy)
			var d := maxi(absi(dx), absi(dy))
			if d < 3 or not _aopen(c) or c == stairs or mons.has(c) or items.has(c) or coin_at.has(c) or spikes.has(c) or haz.has(c):
				continue
			opts.append(c)
	if opts.is_empty():
		return
	var c2: Vector2i = opts[randi() % opts.size()]
	if randf() < 0.5:
		items[c2] = "pod"
	else:
		coin_at[c2] = true
	_fx_ring(Vector2(c2), Color("ffd84f"), 1.6, 0.6, 6.0)
	_fx_burst(Vector2(c2), Color("ffd84f"), 12, 2.6, 0.6, 5.0)
	_pop(c2, "SUPPLY DROP", Color("ffd84f"))
	msg = "Supply drop! A crate landed nearby"


func _blackout() -> bool:
	return _world_rule() == "outage" and adv_steps > 0 and adv_steps % 25 < 3


func _in_room(c: Vector2i) -> bool:
	for rm in adv_rooms:
		if (rm as Rect2i).has_point(c):
			return true
	return false


func _mon_seen(c: Vector2i) -> bool:
	if gm("thermal") and mons.has(c) and maxi(absi(c.x - pos.x), absi(c.y - pos.y)) <= 6:
		return true
	if not adv_vis.has(c):
		return false
	return _world_rule() != "outage" or maxi(absi(c.x - pos.x), absi(c.y - pos.y)) <= 3


func adv_oxy_max() -> float:
	return _oxy_max_base() * (1.25 if gm("heartstation") else 1.0) * (0.5 if relic_n("nr_thin") > 0 else 1.0)


func _oxy_max_base() -> float:
	return 90.0 + 10.0 * int(cdef()["per"]) + 15.0 * relic_n("slowdark") - 15.0 * relic_n("glass") + gear("air") + sk("air") + 10.0 * float(pk.get("air", 0)) + 2.0 * float(level - START_LEVEL) + 8.0 * float(up("tank")) + air_bonus


func adv_pod_amt() -> float:
	return (30.0 + gear("pod")) * (1.0 + (sk("pod") + gear("podp")) / 100.0)


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
	AH = 42
	adv_open.resize(AW * AH)
	adv_open.fill(0)
	adv_seen.resize(AW * AH)
	adv_seen.fill(0)
	adv_rooms.clear()
	for dd in [mons, elite, items, spikes, haz, tur, corpses, coin_at, walls, portals, kinds, thief_held, vaults, stations, meds, merchants, mon_hp, affix, mstat]:
		dd.clear()
	for ry in TUT_ROOMS:
		var r := Rect2i(3, ry, 9, 3)
		adv_rooms.append(r)
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				adv_open[_ai(Vector2i(x, y))] = 1
		if ry > 3:
			for cy in [ry - 2, ry - 1]:
				adv_open[_ai(Vector2i(7, cy))] = 1
	start = Vector2i(7, 39)
	pos = start
	stairs = Vector2i(7, 3)
	boss_floor = false
	boss_cell = Vector2i(-1, -1)
	adv_req = 6
	adv_pts_total = 16
	for cc in [Vector2i(4, 39), Vector2i(10, 39), Vector2i(7, 38), Vector2i(4, 19), Vector2i(10, 19)]:
		coin_at[cc] = true
	for sc in [Vector2i(6, 34), Vector2i(7, 34), Vector2i(8, 34)]:
		spikes[sc] = true
	items[Vector2i(10, 33)] = "pot"
	mons[Vector2i(7, 29)] = 1
	mons[Vector2i(7, 23)] = 1
	items[Vector2i(5, 14)] = "use_zap"
	mons[Vector2i(4, 13)] = 1
	stations[Vector2i(10, 15)] = true
	items[Vector2i(10, 13)] = "pod"
	items[Vector2i(5, 9)] = "gear_hardcap"


func _tut_map_start() -> void:
	tut_prev_cls = cls
	tut_prev_save_off = save_off
	save_off = true
	tutorial = true
	tut_zone = -1
	tut_dlg = ""
	cls = "scout"
	mode = "adv"
	_new_run(1)
	relics.clear()
	equip.clear()
	equip["ranged"] = "blaster"
	bag.clear()
	inv.clear()
	skill_pts = 1
	ammo = ammo_max()
	ranged_mode = false
	coins = 0
	_adv_snapshot()
	adv_fresh = true
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


const TUT_ROOMS := [38, 33, 28, 23, 18, 13, 8, 3]
const TUT_HINTS := [
	"Tap a tile to walk there, or swipe to step. Grab the coins!",
	"Spikes hurt, so walk around them. Bottles give XP to level up.",
	"A monster! Tap it or walk into it to attack. The number on it is the damage you will take.",
	"Tap the round button at the bottom right to swap to your gun, then tap a monster in a straight line. Shots use ammo.",
	"Your class power is the long button at the bottom. Tap it to use it. It recharges as you walk.",
	"Tools: walk over one to pick it up. In your bar, tap once to select, again to confirm, and a third time to use it.",
	"Air drops with every step. Stand on an O2 station or grab air pods to refill.",
	"Gear! Pick it up, open the MENU, tap the item and EQUIP it. Modifiers add extra effects: tap SHOW MODIFIERS to read them.",
	"Levels give skill points. Tap SKILLS to spend them on upgrades and shape your build. You have 1 point to try.",
	"Coins and kills give points. Enough points open the exit. Walk to the gate to finish!",
]


func _tut_hint() -> void:
	var z := 0
	for zl in [[35, 1], [30, 2], [25, 3], [20, 4], [15, 5], [10, 7], [5, 8]]:
		if pos.y <= int(zl[0]):
			z = int(zl[1])
	if z == 5 and absi(pos.x - 10) + absi(pos.y - 15) <= 2:
		z = 6
	if adv_pts >= adv_req and pos.y <= 5:
		z = 9
	if z <= tut_zone:
		return
	tut_zone = z
	msg = String(TUT_HINTS[z])
	tut_dlg = msg
	walk.clear()


func _draw_tut_dlg() -> void:
	if not tutorial or tut_dlg == "" or state != PLAY:
		return
	draw_rect(Rect2(-60, -60, 840, 1500), Color(0, 0, 0, 0.45))
	var r := Rect2(60, 440, 600, 300)
	_panel(r, Color("ffd84f"), 0.18, false)
	_txt("TUTORIAL  %d / %d" % [tut_zone + 1, TUT_HINTS.size()], Vector2(r.position.x, r.position.y + 52), 24, Color("ffd84f"), r.size.x)
	_para(tut_dlg, Vector2(r.position.x + 36, r.position.y + 110), 28, Color.WHITE, r.size.x - 72)
	_txt("Tap to continue", Vector2(r.position.x, r.end.y - 24), 20, Color(1, 1, 1, 0.6), r.size.x)


# ---------- floor details (looks only) ----------
func _deco_at(x: int, y: int) -> int:
	var h := _tile_hash(x + 311, y + 97)
	if h % 100 < 5:
		return (h / 100) % 4
	return -1


const WORLD_RULES := ["supply", "spore", "outage", "glare"]
const WORLD_RULE_TEXT := {
	"supply": "Supply drops: every 40 steps a crate of coins or air lands nearby.",
	"spore": "Spore bursts: every 30 steps you are briefly poisoned.",
	"outage": "Power outage: you see 2 tiles less, and enemies stay hidden until within 3 tiles. Every 25 steps a 3-step blackout leaves you seeing only adjacent tiles while Hunters move every turn.",
	"glare": "Crystal storm: you see 1 tile less. Tiles crack as you walk; stepping on a cracked tile costs 3 health. Every 20 steps crystals shatter, hurting you unless you stand next to a wall. Kills give +25% XP.",
}
var guide_seen: Dictionary = {}
var banner_rule := ""
var banner_t0 := -100.0
const WORLD_BANNER_TIME := 10.0
const WORLD_RULE_COL := {"supply": Color("ffd84f"), "spore": Color("b6ff6a"), "outage": Color("ff9a5b"), "glare": Color("e6c8ff")}


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
	_abox(r, Color(0.02, 0.03, 0.07, 0.88 * a))
	_aline(r, Color(col.r, col.g, col.b, a), 3.0)
	_txt("WORLD RULE", Vector2(r.position.x, r.position.y + 36), 28, Color(col.r, col.g, col.b, a), r.size.x)
	_para(String(WORLD_RULE_TEXT[banner_rule]), Vector2(r.position.x + 20, r.position.y + 66), 22, Color(1, 1, 1, a), r.size.x - 40.0)


func _world_rule() -> String:
	if mode != "adv" or tutorial or testroom or in_base or arena or themes.is_empty():
		return ""
	return String(WORLD_RULES[tidx() % WORLD_RULES.size()])


func _adv_in_room(c: Vector2i) -> bool:
	for rm in adv_rooms:
		if (rm as Rect2i).has_point(c):
			return true
	return false


func _guide_on() -> bool:
	return mode == "adv" and not tutorial and not in_base and not arena and floor_n == 1 and adv_best == 0


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
	if ul(2) and skill_pts > 0 and _guide_say("skill", "You have a skill point! Tap SKILLS to spend it."):
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
	if deep_run:
		k = kind_ids[(adv_seed & 0x7fffffff) % 4]   # Deep Station: random boss rematch
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
				if not _adv_env_hurt(bd, "Blast! You lose %d health", "You were caught in the %s's blast" % String(_boss_name()), "boom"):
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
					if not _adv_hurt(mon_atk(bc), String(_boss_name()), bc):
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
	if in_base:
		_adv_gen_base()
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
			if relic_n("nr_hunger") > 0 and rng.randf() < 0.35:
				nm += 1
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


# ---------------------------------------------------------------- gear sets
const GEAR_SETS := {
	"crew": ["Station Crew", ["wrench", "hardcap", "scrap", "magboots", "battery"], "+1 armour, +10 air", "+2 coins every floor, tools 15% not used up"],
	"hazmat": ["Hazmat", ["hazmask", "hazboots", "rebreather", "podamp"], "+60% hazard resist", "air pods also heal 3"],
	"marksman": ["Marksman", ["targetvisor", "scopemod", "critoptics", "railsniper", "ghillie"], "+1 range, +10% ranged crit", "ranged crits refund 1 ammo"],
	"riot": ["Riot Squad", ["riothelm", "bulwark", "aegiscore", "aegisemit", "ward"], "+5 max shield", "while shielded: +3 thorns, 25% less damage"],
	"crystal": ["Crystal", ["crystalhelm", "crystalmail", "crystaltreads", "prismblade", "shardspear"], "+10% crit", "crits splash 50% to adjacent enemies"],
	"phase": ["Phase", ["phase", "phaseweave", "warp", "wormhole"], "+8% dodge", "dodging gives +3 shield and a free step"],
	"void": ["Void", ["voidcutter", "voidcrown", "singedge", "voidheart"], "+3 attack", "kills hit enemies within 2 tiles for 2 and heal you 2"],
	"cosmic": ["Cosmic", ["eventrail", "horizonplate", "starmaul", "starweave", "eclipsecrown", "oblivion"], "+15% damage", "+2 attack, +20% XP"],
}
const SET_STATS := {
	"crew": [{"armor": 1, "air": 10}, {}],
	"hazmat": [{"hazres": 60}, {}],
	"marksman": [{"rangeb": 1, "rcrit": 10}, {}],
	"riot": [{"shield": 5}, {}],
	"crystal": [{"crit": 10}, {}],
	"phase": [{"dodge": 8}, {}],
	"void": [{"atk": 3}, {}],
	"cosmic": [{}, {"atk": 2, "xp": 20}],
}


func set_n(sid: String) -> int:
	if mode != "adv":
		return 0
	var list: Array = GEAR_SETS[sid][1]
	var n := 0
	for slot in equip:
		var id := String(equip[slot])
		if id != "" and list.has(gb(id)):
			n += 1
	return n


func set_on(sid: String, need: int) -> bool:
	return set_n(sid) >= need


func _set_stat(stat: String) -> float:
	var tot := 0.0
	if mode != "adv":
		return tot
	for sid in SET_STATS:
		var n := set_n(String(sid))
		if n >= 2:
			tot += float((SET_STATS[sid][0] as Dictionary).get(stat, 0))
		if n >= 3:
			tot += float((SET_STATS[sid][1] as Dictionary).get(stat, 0))
	return tot


func _set_lines() -> String:
	var out := ""
	for sid in GEAR_SETS:
		var n := set_n(String(sid))
		if n < 2:
			continue
		var g: Array = GEAR_SETS[sid]
		out += "[SET] %s %d/%d  %s%s\n" % [g[0], n, (g[1] as Array).size(), g[2], ("   " + String(g[3])) if n >= 3 else ""]
	return out


func gear(stat: String) -> float:
	var tot := 0.0
	for slot in equip:
		if slot == ("weapon" if shooting else "ranged"):
			continue
		var id := String(equip[slot])
		if id == "" or not gear_defs.has(gb(id)):
			continue
		var st: Dictionary = gstats(id)
		tot += float(st.get(stat, 0))
		if mode == "adv":
			for mid in gmods(id):
				tot += float((MOD_DEFS[mid]["s"] as Dictionary).get(stat, 0))
	return tot + _set_stat(stat)


func hp_cap() -> int:
	return maxi(1, int(float(_hp_cap_base()) * (1.25 if gm("heartstation") else 1.0) * (_hz_frag() if mode == "adv" else 1.0) * (0.5 if relic_n("nr_fragile") > 0 else 1.0)))


func _hp_cap_base() -> int:
	return hp_max + int(gear("hp")) + int(sk("hp")) + 4 * (relic_n("pyro") + relic_n("storm") + relic_n("frost") + relic_n("toxi") + relic_n("bloodpact") + relic_n("hood"))


func sh_cap() -> int:
	return int(float(_sh_cap_base()) * (1.25 if gm("heartstation") else 1.0))


func _sh_cap_base() -> int:
	var c := sh_max + int(gear("shield")) + int(sk("maxsh")) + int(gear("maxsh")) + 3 * int(pk.get("shield", 0))
	return c / 4 if relic_n("ocell") > 0 else c


func armor_total() -> int:
	var at := armor + int(gear("armor")) + int(sk("armor")) + int(pk.get("armor", 0))
	if sk("hold") > 0.0 and not _near_mons(pos, 1, []).is_empty():
		at += int(sk("hold"))
	if gm("bulwarkp") and _wall_adj(pos):
		at += 3
	if relic_n("nr_pack") > 0:
		at += _near_mons(pos, 1, []).size()
	if gm("fortress") and hp * 4 > hp_cap() * 3:
		at *= 2
	return at / 2 if p_acid > 0 else at


func p_atk() -> int:
	var pa := _p_atk_raw()
	return maxi(1, pa / 2) if p_frost > 0 else pa


func _p_atk_raw() -> int:
	return level + boost + int(gear("atk")) + int(sk("atk")) + int(pk.get("mel", 0)) + nr_l_atk + nr_thin_atk


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
		a += armor_total() / 3 + (floor_n - 1) / 2
		if _is_frenzied(c):
			a += maxi(2, a / 2)
		a += _hz_atk(c)
		if relic_n("nr_ledger") > 0:
			var rc := 0
			for rk in relics:
				rc += int(relics[rk])
			a = int(round(float(a) * (1.0 + 0.02 * float(rc))))
	return a


func mon_hp_max(c: Vector2i) -> int:
	var h := 4 + 3 * _mon_level(c)
	if elite.has(c):
		h = int(h * 1.5)
	if boss_floor and c == boss_cell:
		h = int(h * 1.6)
	if mode == "adv":
		h = int(h * (1.0 + minf(0.6, 0.03 * float(threat()))) * (1.0 + 0.09 * float(floor_n - 1)))
		if String(affix.get(c, "")) == "brute":
			h *= 2
		h = int(float(h) * _hz_hp(c))
		if relic_n("nr_fragile") > 0:
			h = maxi(1, h / 2)
		if ev_idol:
			h = int(float(h) * 1.25)
	return h


func mon_hp_now(c: Vector2i) -> int:
	return int(mon_hp.get(c, mon_hp_max(c)))


func dmg_taken(a: int) -> int:
	var d := maxi(1, a - armor_total())
	if mode == "adv" and sk("laststand") > 0.0 and hp * 100 < hp_cap() * 30:
		d = maxi(1, int(round(float(d) * (1.0 - sk("laststand") / 100.0))))
	if gm("laststand") and hp * 100 < hp_cap() * 25:
		d = maxi(1, int(round(float(d) * 0.7)))
	if sh > 0 and set_on("riot", 3):
		d = maxi(1, int(round(float(d) * 0.75)))
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
		return ("Ascended " if mode == "adv" and floor_n > 20 else "") + _boss_name()
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
	if gm("memchip"):
		_p_heal(3 * n)
	if gm("mindforge"):
		sh = mini(sh_cap(), sh + 3 * n)
		oxy = oxy_max
	var got := 0
	for l in range(old + 1, level + 1):
		if l % 3 == 0:
			got += 1
	if got > 0:
		skill_pts += got
		sk_ban_n = got
		sk_ban_t0 = t + 1.0


func _adv_hurt(a: int, who: String, src := Vector2i(-1, -1)) -> bool:
	floor_spotted = true
	if mirror_n > 0:
		mirror_n -= 1
		_pop(pos, "REFLECT", Color("c8f1ff"))
		_fx_ring(vis_pos, Color("c8f1ff"), 1.2, 0.4, 5.0)
		msg += "   Mirror Shard reflects %s!" % who
		_sfx("shield")
		if mons.has(src):
			_adv_damage_mon(src, a)
		return true
	if _nr_dodge(src):
		return true
	if randf() * 100.0 < dodge_chance():
		_pop(pos, "DODGE", Color("9fe8ff"))
		_fx_ring(vis_pos, Color("9fe8ff"), 1.1, 0.35, 3.0)
		if set_on("phase", 3):
			sh = mini(sh_cap(), sh + 3)
			mom_steps += 1
		msg += "   You dodge %s!" % who
		ck_src = src
		_mx_dodged()
		return true
	if gm("ablative") and not abl_used:
		abl_used = true
		_pop(pos, "ABSORBED", Color("c8f1ff"))
		msg += "   Your ablative layer absorbs %s!" % who
		_sfx("shield")
		return true
	if gm("windrun") and p_moved and mons.has(src) and maxi(absi(src.x - p_prev.x), absi(src.y - p_prev.y)) <= 1:
		_pop(pos, "SLIPPED", Color("c8f1ff"))
		msg += "   You slip away from %s!" % who
		return true
	var rsrc := rshot_src
	rshot_src = Vector2i(-1, -1)
	if gm("mirrorhull") and src.x < 0 and rsrc.x >= 0 and mons.has(rsrc) and randf() < 0.25:
		_pop(pos, "MIRRORED", Color("c8f1ff"))
		_adv_damage_mon(rsrc, maxi(1, int(float(a) * 1.5)), Color("c8f1ff"))
		msg += "   Your hull reflects %s's shot!" % who
		_sfx("shield")
		return true
	if _any_tr("parry") and mons.has(src) and randf() < 0.15:
		_pop(pos, "PARRY", Color("c8f1ff"))
		_adv_damage_mon(src, maxi(1, p_atk() / 2), Color("c8f1ff"))
		msg += "   You parry %s!" % who
		_sfx("shield")
		return true
	_buzz(35)
	if act_stance > 0:
		act_stance -= 1
		_pop(pos, "BLOCKED 75%", Color("7db2ff"))
		msg += "   Iron Stance blocks most of %s's hit!" % who
		_mx_blocked(src)
		_sfx("shield")
		a = maxi(1, int(round(float(a) * 0.25)))
	if sk("msupp") > 0.0 and _mk(src):
		a = maxi(1, int(round(float(a) * (1.0 - sk("msupp") / 100.0))))
	a = _ck_hurt(a, src)
	a = _nr_flip(a)
	if a <= 0:
		return true
	var d := dmg_taken(a)
	var absorbed := mini(sh, d)
	sh -= absorbed
	hp -= d - absorbed
	_nr_hurt(src, d)
	_ck_hurt_after(src, d, absorbed)
	if _any_tr("reprisal"):
		repr_ready = true
	if gm("counterw"):
		cw_ready = true
	if absorbed > 0 and gm("siphonp"):
		_tr_heal(maxi(1, int(float(absorbed) * 0.2)))
	if hp > 0 and gm("lastditch") and not ld_used and hp * 5 < hp_cap():
		ld_used = true
		sh = mini(sh_cap(), sh + 6)
		_pop(pos, "+6 SHIELD", Color("7db2ff"))
	if hp > 0 and gm("stim") and not stim_used and hp * 10 < hp_cap() * 3:
		stim_used = true
		_p_heal(maxi(1, int(hp_cap() * 0.4)))
		_pop(pos, "STIM", Color("ff8a9a"))
	if hp > 0 and gm("adrenal") and not adr_used and hp * 10 < hp_cap() * 3:
		adr_used = true
		oxy = oxy_max
		_pop(pos, "AIR REFILL", Color("7fd8ff"))
	if gm("reactorp"):
		reactor_n += 1
		if reactor_n >= 10:
			reactor_n = 0
			for ro in _near_mons(pos, 1, []):
				_adv_damage_mon(ro, maxi(1, p_atk()), Color("ffe14f"))
				_st_stun(ro, 1)
			_pop(pos, "SHOCKWAVE", Color("ffe14f"))
	if gm("reactive") and hp > 0:
		sh = mini(sh_cap(), sh + 2)
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
	if hp > 0:
		_aff_on_hit(src, a)
	if mons.has(src) and String(affix.get(src, "")) == "leech":
		mon_hp[src] = mini(mon_hp_max(src), mon_hp_now(src) + d)
		_pop(src, "+%d" % d, Color("ff5d8a"))
	var th := thorns_dmg() + (maxi(1, int(round(float(d) * sk("thorns") / 100.0))) if sk("thorns") > 0.0 else 0)
	if th > 0 and mons.has(src):
		_adv_damage_mon(src, th)
		if syn("bloodpact", "thornmail") and hp > 0:
			_p_heal(1)
	if hp <= 0 and gm("secondwind") and not sw_used:
		sw_used = true
		hp = 1
		_pop(pos, "SECOND WIND", Color("9fffc0"))
		msg += "   Second Wind! You cling on"
		return true
	if hp <= 0 and _nr_rewind():
		return true
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
	if gm("gravity") and snd != "poison" and hp * 2 < hp_cap():
		_p_heal(d)
		_pop(pos, "+%d" % d, Color("a68cff"))
		return true
	var absorbed := mini(sh, d)
	sh -= absorbed
	hp -= d - absorbed
	_nr_hurt(Vector2i(-1, -1), d)
	_pop(pos, "-%d" % d, Color("ff6a6a") if absorbed < d else Color("7db2ff"))
	if absorbed > 0:
		_fx_ring(vis_pos, Color("7db2ff"), 0.9, 0.35, 5.0)
	if absorbed < d:
		p_hit_t0 = t
		_fx_burst(vis_pos, Color("ff5d5d"), 10, 3.2, 0.45, 5.0)
		_shake(4.0, 0.25)
	msg = text % d
	_sfx(snd)
	if hp <= 0 and gm("secondwind") and not sw_used:
		sw_used = true
		hp = 1
		_pop(pos, "SECOND WIND", Color("9fffc0"))
		msg += "   Second Wind! You cling on"
		return true
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
		_hex_use()
		dmg = int(round(float(dmg) * _hex_mult()))
		_pop(c, "HEX " + _mx_hex_txt(), Color("c07cff"))
	if sk("mark") > 0.0 and _mk(c):
		dmg = int(round(float(dmg) * (1.0 + sk("mark") / 100.0)))
	if _any_tr("rot") and mstat.has(c) and mstat[c].has("psn"):
		dmg = int(round(float(dmg) * 1.15))
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
var kb_pend := Vector2i(-1, -1)
var tgt_crit := 0.0
var sneak_slp := false
var cw_ready := false
var abl_used := false
var ld_used := false
var stim_used := false
var adr_used := false
var echoc_used := false
var reactor_n := 0
var eye_k := 0
var p_moved := false
var p_prev := Vector2i(-1, -1)
var rshot_src := Vector2i(-1, -1)
var hair_free := false
var repr_ready := false
var tr_streak := 0            # hits in a row without being damaged
var tr_hits := 0              # hits landed this floor (Rhythm)
var tr_last := Vector2i(-1, -1)
var tr_mark := 0              # consecutive hits on the same target
var tr_depth := 0

const TRAIT_DEFS := {
	"ignite": {"n": "Ignite", "d": "Hits set the enemy ablaze: 2 damage a step for 3 steps, +1 more every 2 floors", "t": ["fire"]},
	"volatile": {"n": "Volatile", "d": "Kills explode, hurting nearby enemies for 40% of the victim's HP", "t": ["fire", "kill"]},
	"static": {"n": "Static", "d": "25% chance to stun on hit (it loses its next action)", "t": ["shock"]},
	"arc": {"n": "Arc Chain", "d": "Hits arc to another enemy within 2 tiles for 50% damage", "t": ["shock"]},
	"frostbite": {"n": "Frostbite", "d": "The first hit on each enemy freezes it for a step", "t": ["cryo"]},
	"shatter": {"n": "Shatter", "d": "+50% damage to stunned or frozen enemies", "t": ["cryo", "shock"]},
	"toxin": {"n": "Toxin", "d": "Hits poison: 1 damage a step per stack, up to 4 stacks. Poison hurts more the deeper you go (x3 on floor 8, x5 on floor 16)", "t": ["toxic"]},
	"plague": {"n": "Plague", "d": "Poisoned enemies spread poison to neighbours when they die", "t": ["toxic", "kill"]},
	"siphon": {"n": "Siphon", "d": "Heal 20% of the damage you deal (at least 1)", "t": ["blood"]},
	"bloodlust": {"n": "Bloodlust", "d": "Kills heal 10% of your max health", "t": ["blood", "kill"]},
	"execute": {"n": "Executioner", "d": "Enemies under 20% health die instantly (not bosses)", "t": ["execute"]},
	"brutal": {"n": "Brutal", "d": "+25% damage", "t": ["raw"]},
	"ambush": {"n": "Ambush", "d": "+50% damage against enemies at full health", "t": ["raw"]},
	"sharp": {"n": "Keen Edge", "d": "+12% crit chance", "t": ["crit"]},
	"deadly": {"n": "Deadly Crits", "d": "Crits deal 2.5x damage instead of double", "t": ["crit"]},
	"rampage": {"n": "Rampage", "d": "+3% damage per hit in a row without being hurt (max +15%)", "t": ["streak"]},
	"rhythm": {"n": "Rhythm", "d": "Every 4th hit deals double damage", "t": ["streak"]},
	"marked": {"n": "Marked", "d": "Each hit on the same enemy deals +1 more (max +4)", "t": ["streak"]},
	"cleave": {"n": "Cleave", "d": "Melee hits also strike enemies beside the target for 50%", "t": ["melee"]},
	"pierce": {"n": "Pierce", "d": "Shots also hit the enemy behind the target for 60%", "t": ["ranged"]},
	"overkill": {"n": "Overkill", "d": "Excess damage on a kill carries to a nearby enemy", "t": ["kill"]},
	"bounty": {"n": "Bounty", "d": "Kills drop extra coins", "t": ["econ", "kill"]},
	"harvest": {"n": "Soul Harvest", "d": "+30% XP from kills", "t": ["econ", "kill"]},
	"adrenaline": {"n": "Adrenaline", "d": "Kills restore 20 air", "t": ["kill"]},
	"barrier": {"n": "Barrier", "d": "Kills grant +8 shield", "t": ["kill", "defense"]},
	"thorned": {"n": "Spiked", "d": "Reflect 2 damage (more on deeper floors) when hit", "t": ["defense"]},
	"duelist": {"n": "Duelist", "d": "+10% dodge chance", "t": ["defense"]},
	"echoslam": {"n": "Echo Slam", "d": "Every 4th hit strikes twice", "t": ["streak"], "min": 4},
	"rooting": {"n": "Rooting", "d": "50% chance on hit to root the enemy: it can't move on its next turn", "t": ["control"]},
	"tireless": {"n": "Efficient Rounds", "d": "15% chance a shot uses no ammo", "t": ["ranged"]},
	"stormfront": {"n": "Storm Front", "d": "Killing a stunned enemy stuns the enemies next to it for 2 steps", "t": ["shock", "kill"]},
	"conduit": {"n": "Conduit", "d": "Crits stun the enemy for 2 steps", "t": ["shock", "crit"]},
	"inferno": {"n": "Inferno", "d": "Burning enemies spread their burn to a neighbour each step (50% chance)", "t": ["fire"]},
	"flashpoint": {"n": "Flashpoint", "d": "A burn deals double damage on its first tick", "t": ["fire"]},
	"permafrost": {"n": "Permafrost", "d": "Every 3rd hit on a chilled enemy freezes it solid for 2 steps", "t": ["cryo"]},
	"icicle": {"n": "Icicle", "d": "Hitting a frozen enemy splashes 50% damage to the enemies beside it", "t": ["cryo"]},
	"rot": {"n": "Rot", "d": "Poisoned enemies take +15% damage from all sources", "t": ["toxic"]},
	"contagion": {"n": "Contagion", "d": "Hitting a poisoned enemy spreads a poison stack to a neighbour", "t": ["toxic"]},
	"stormcaller": {"n": "Storm Caller", "d": "When an enemy carries 3 different elements, lightning hits it for 3x your damage (once per enemy)", "t": ["shock"]},
	"heavy": {"n": "Heavy Hitter", "d": "+40% damage, but every hit costs 1 extra air", "t": ["raw"]},
	"firstblood": {"n": "First Blood", "d": "The first hit on each floor deals double damage", "t": ["raw"]},
	"underdog": {"n": "Underdog", "d": "+30% damage while 3 or more enemies are in view", "t": ["raw"]},
	"crush": {"n": "Crush", "d": "+50% damage to rooted enemies or enemies with their back to a wall", "t": ["raw"]},
	"gambler": {"n": "Gambler's Edge", "d": "20% chance to deal double damage, 10% chance to deal none", "t": ["raw"]},
	"ricochet": {"n": "Ricochet", "d": "30% chance a shot bounces to a second enemy for 50% damage", "t": ["ranged"]},
	"sniper": {"n": "Sniper", "d": "+1 damage per tile of distance (max +4)", "t": ["ranged"]},
	"hairtrig": {"n": "Hair Trigger", "d": "The first shot after a melee kill uses no ammo", "t": ["ranged", "kill"]},
	"hollow": {"n": "Hollow Point", "d": "+30% damage to full-health enemies, but shots reach 1 tile less", "t": ["ranged"]},
	"scav": {"n": "Scavenger Rounds", "d": "Shots that kill have a 25% chance to refund the ammo", "t": ["ranged", "kill"]},
	"knockback": {"n": "Knockback", "d": "30% chance to knock the enemy back 1 tile", "t": ["control"]},
	"intimidate": {"n": "Intimidate", "d": "Enemies you leave under 30% health skip their next action", "t": ["control"]},
	"pin": {"n": "Pin", "d": "Rooted enemies take +25% damage", "t": ["control"]},
	"parry": {"n": "Parry", "d": "15% chance to block a hit and counter for half your attack", "t": ["defense"]},
	"reprisal": {"n": "Reprisal", "d": "After you are hit, your next hit deals +50% damage", "t": ["defense"]},
	"regen": {"n": "Regenerator", "d": "Heal 1 health every 5 steps (2 when below half health)", "t": ["defense"]},
	"vampedge": {"n": "Vampire Edge", "d": "Crits make enemies bleed, and your bleeds heal you for 25% of their damage", "t": ["blood"]},
	"echostep": {"n": "Echo Step", "d": "Every 6th step costs no air", "t": ["streak"]},
	"assassin": {"n": "Assassin", "d": "Sneak attacks deal +50% damage", "t": ["raw"]},
}

# Gear mods for helmet / armour / boots / trinket (stored in the same "@" list as weapon traits).
const MOD_DEFS := {
	"nightsight": {"n": "Night Sight", "d": "+1 sight radius", "slot": "helmet", "s": {"sight": 1}},
	"focus": {"n": "Focus", "d": "+8% crit chance", "slot": "helmet", "s": {"crit": 8}},
	"scholar": {"n": "Scholar", "d": "+20% XP", "slot": "helmet", "s": {"xp": 20}},
	"rebreather": {"n": "Rebreather", "d": "Steps use a third less air", "slot": "helmet", "s": {"airsave": 33}},
	"reinforced": {"n": "Reinforced", "d": "+2 armour", "slot": "armour", "s": {"armor": 2}},
	"reactive": {"n": "Reactive Plating", "d": "Getting hit grants +2 shield", "slot": "armour", "s": {}},
	"laststand": {"n": "Last Stand", "d": "Below 25% health, take 30% less damage", "slot": "armour", "s": {}},
	"regenweave": {"n": "Regen Weave", "d": "Heal 1 health every 5 steps", "slot": "armour", "s": {}},
	"retaliate": {"n": "Retaliation", "d": "Reflect 3 damage when hit", "slot": "armour", "s": {"thorns": 3}},
	"surefoot": {"n": "Sure-Footed", "d": "Spikes don't hurt you", "slot": "boots", "s": {}},
	"swift": {"n": "Swift", "d": "+8% dodge chance", "slot": "boots", "s": {"dodge": 8}},
	"sprinter": {"n": "Sprinter", "d": "Kills make your next 2 steps cost no air", "slot": "boots", "s": {}},
	"trail": {"n": "Trailblazer", "d": "Each step has a 4% chance to find a coin", "slot": "boots", "s": {}},
	"charger": {"n": "Charger", "d": "+15% damage on your first hit after 2+ steps", "slot": "boots", "s": {}},
	"lucky": {"n": "Lucky Charm", "d": "+1 coin per coin picked up", "slot": "trinket", "s": {"coin": 1}},
	"airtank": {"n": "Air Tank", "d": "+10 max air", "slot": "trinket", "s": {"air": 10}},
	"locket": {"n": "Vital Locket", "d": "+4 max health", "slot": "trinket", "s": {"hp": 4}},
	"cdgem": {"n": "Cooldown Gem", "d": "Class power recharges 20% faster", "slot": "trinket", "s": {}},
	"magnet": {"n": "Magnet", "d": "Collect coins on tiles next to you", "slot": "trinket", "s": {}},
	"huntereye": {"n": "Hunter's Eye", "d": "+2 damage against enemies at full health", "slot": "helmet", "s": {}},
	"headlamp": {"n": "Headlamp", "d": "Scanner pulses reach 2 tiles further and last longer", "slot": "helmet", "s": {}},
	"ironwill": {"n": "Iron Will", "d": "Immune to stun", "slot": "helmet", "s": {}},
	"vampmesh": {"n": "Vampiric Mesh", "d": "Kills heal 2 health", "slot": "armour", "s": {}},
	"insulated": {"n": "Insulated", "d": "Immune to burn", "slot": "armour", "s": {}},
	"vinestep": {"n": "Vinestep", "d": "Enemies that hit you are rooted for their next turn", "slot": "boots", "s": {}},
	"anchored": {"n": "Anchored", "d": "Immune to root", "slot": "armour", "s": {}},
	"explorer": {"n": "Explorer", "d": "The exit shows on the minimap when you arrive", "slot": "boots", "s": {}},
	"secondwind": {"n": "Second Wind", "d": "Once per floor, survive a lethal hit at 1 health", "slot": "trinket", "s": {}},
	"tvisor": {"n": "Targeting Visor", "d": "+10% crit chance against stunned or rooted enemies", "slot": "helmet", "s": {}},
	"airfilter": {"n": "Air Filter", "d": "Air pods give +25% more air", "slot": "helmet", "s": {"podp": 25}},
	"thermal": {"n": "Thermal Lens", "d": "See enemies through walls within 6 tiles", "slot": "helmet", "s": {}},
	"bfocus": {"n": "Battle Focus", "d": "+1 damage per enemy in view (max +3)", "slot": "helmet", "s": {}},
	"mindshield": {"n": "Mind Shield", "d": "Acid and frost on you wear off sooner (2 steps instead of 3)", "slot": "helmet", "s": {}},
	"prospect": {"n": "Prospector's Visor", "d": "Vaults and caches show on the minimap", "slot": "helmet", "s": {}},
	"adrenal": {"n": "Adrenal Cap", "d": "The first time each floor you drop below 30% health, your air is refilled", "slot": "helmet", "s": {}},
	"memchip": {"n": "Memory Chip", "d": "+10% XP, and level-ups restore 3 health", "slot": "helmet", "s": {"xp": 10}},
	"ablative": {"n": "Ablative Layer", "d": "Absorbs the first hit each floor completely", "slot": "armour", "s": {}},
	"kinetic": {"n": "Kinetic Weave", "d": "Gain 1 shield every 3 steps (up to 6)", "slot": "armour", "s": {}},
	"toxfilter": {"n": "Toxin Filter", "d": "Poison damage on you is halved", "slot": "armour", "s": {}},
	"counterw": {"n": "Counterweight", "d": "After being hit, your next hit deals +2 damage", "slot": "armour", "s": {}},
	"bulwarkp": {"n": "Bulwark Plate", "d": "+3 armour while standing next to a wall", "slot": "armour", "s": {}},
	"reservec": {"n": "Reserve Cell", "d": "Overflow healing becomes shield (up to 4)", "slot": "armour", "s": {}},
	"siphonp": {"n": "Siphon Plating", "d": "20% of the damage your shield absorbs heals you", "slot": "armour", "s": {}},
	"lastditch": {"n": "Last Ditch", "d": "If a hit leaves you below 20% health, gain 6 shield (once per floor)", "slot": "armour", "s": {}},
	"shockabs": {"n": "Shock Absorbers", "d": "Hazard tiles deal 50% less damage", "slot": "boots", "s": {}},
	"grapple": {"n": "Grapple Heels", "d": "Moving along a wall costs no air", "slot": "boots", "s": {}},
	"skipper": {"n": "Skipper", "d": "10% chance a step costs no air", "slot": "boots", "s": {}},
	"dash": {"n": "Dash Soles", "d": "Every 8th step moves you two tiles", "slot": "boots", "s": {}},
	"reflex": {"n": "Reflex Treads", "d": "+10% dodge while moving", "slot": "boots", "s": {}},
	"toolbelt": {"n": "Tool Belt", "d": "+1 tool slot", "slot": "trinket", "s": {"slots": 1}},
	"medpouch": {"n": "Medic's Pouch", "d": "Medkits heal 25% more", "slot": "trinket", "s": {"medk": 25}},
	"luckycoin": {"n": "Lucky Coin", "d": "+4% crit chance", "slot": "trinket", "s": {"crit": 4}},
	"compass": {"n": "Compass", "d": "An arrow on the minimap points to the exit", "slot": "trinket", "s": {}},
	"gcompass": {"n": "Golden Compass", "d": "+25% coins from pickups, and vaults and caches show on the minimap", "slot": "trinket", "s": {}},
	"gamblerchip": {"n": "Gambler's Chip", "d": "The first shop reroll is free and offers a tier higher", "slot": "trinket", "s": {}},
	"salvcore": {"n": "Salvage Core", "d": "Selling gear gives double scrap, and 15% of the time a random tool", "slot": "trinket", "s": {}},
	"aegis": {"n": "Aegis Locket", "d": "+8 max shield", "slot": "trinket", "s": {"maxsh": 8}},
	"stim": {"n": "Stim Injector", "d": "Once per floor, dropping below 30% health heals you for 40% of max health", "slot": "trinket", "s": {}},
	"lifeline": {"n": "Lifeline Charm", "d": "All healing is 25% stronger", "slot": "trinket", "s": {}},
	"deepres": {"n": "Deep Reserve", "d": "+20 max air, and you start each floor with 10 bonus air", "slot": "trinket", "s": {"air": 20}},
	"berserkb": {"n": "Berserker's Band", "d": "+20% damage while under half health", "slot": "trinket", "s": {}},
	"overcell": {"n": "Overcharge Cell", "d": "Class power recharges 30% faster, and using it grants 4 shield", "slot": "trinket", "s": {"pcell": 30}},
	"pdrone": {"n": "Pocket Drone", "d": "Every 15 steps a drone zaps the nearest enemy for 25% of your damage", "slot": "trinket", "s": {}},
	"echoc": {"n": "Echo Charm", "d": "The first tool you use each floor isn't consumed", "slot": "trinket", "s": {}},
	"mindforge": {"n": "Mindforge", "d": "Level-ups grant +3 shield and fully refill your air", "slot": "helmet", "s": {}, "hi": true},
	"eyestorm": {"n": "Eye of the Storm", "d": "Every 5th kill unleashes lightning on the 3 nearest enemies for 100% of your attack", "slot": "helmet", "s": {}, "hi": true},
	"seerhalo": {"n": "Seer's Halo", "d": "The whole floor layout is revealed when you arrive", "slot": "helmet", "s": {}, "hi": true},
	"fortress": {"n": "Fortress Core", "d": "Armour counts double while you are above 75% health", "slot": "armour", "s": {}, "hi": true},
	"reactorp": {"n": "Reactor Plating", "d": "Taking hits charges the plating: at 10 charges it blasts and stuns adjacent enemies", "slot": "armour", "s": {}, "hi": true},
	"mirrorhull": {"n": "Mirror Hull", "d": "25% chance to reflect a ranged shot back at the shooter for 150%", "slot": "armour", "s": {}, "hi": true},
	"windrun": {"n": "Windrunners", "d": "Enemies that were next to you get no attack when you step away", "slot": "boots", "s": {}, "hi": true},
	"earthshake": {"n": "Earthshakers", "d": "Kills stun every enemy within 2 tiles for 1 step", "slot": "boots", "s": {}, "hi": true},
	"gravity": {"n": "Gravity Soles", "d": "Hazard tiles heal you instead of hurting you while you are below half health", "slot": "boots", "s": {}, "hi": true},
	"heartstation": {"n": "Heart of the Station", "d": "+25% max health, air and shield, but it can't be sold", "slot": "trinket", "s": {}, "hi": true},
	"hushvisor": {"n": "Hush Visor", "d": "Enemies take 1 extra step to notice you", "slot": "helmet", "s": {}},
	"quietweave": {"n": "Quiet Weave", "d": "Awake enemies don't hear you when you're next to them", "slot": "armour", "s": {}},
	"softsoles": {"n": "Soft Soles", "d": "Sleeping enemies never hear you walk past", "slot": "boots", "s": {}},
	"shadowcharm": {"n": "Shadow Charm", "d": "Sneak attacks deal +30% damage", "slot": "trinket", "s": {}},
}
var sw_used := false
var chg_n := 0
var p_burn := 0
var scrap := 0
var fr_uses := 0
var sup_done: Dictionary = {}


func _p_heal(n: int) -> void:
	var h := int(round(float(n) * (2.0 if sk("crimson") > 0.0 else 1.0) * (1.25 if gm("lifeline") else 1.0) * _hz_heal()))
	var room := hp_cap() - hp
	var tfc := int(sk("transf")) + (4 if gm("reservec") else 0)
	if h > room and tfc > 0:
		sh = mini(sh_cap(), sh + mini(h - room, tfc))
	hp = mini(hp + h, hp_cap())


var warp_bc := Vector2i(-1, -1)
var warp_home := Vector2i(-1, -1)
var warp_rc := false
var can_n := 2
var fab_n := 0    # Auto-Fabricator coin counter


func _breathe_rect() -> Rect2:
	var sz := _slot_sz()
	return Rect2(16.0, 1054.0 - sz + adv_ex, sz + 20.0, sz)


func _breathe() -> void:
	if state != PLAY:
		return
	if can_n <= 0:
		msg = "No breaths left this floor"
		_sfx("blocked")
		return
	if hp >= hp_cap():
		msg = "Health is already full"
		_sfx("blocked")
		return
	if oxy < 10.0:
		msg = "Not enough air to breathe deep"
		_sfx("blocked")
		return
	can_n -= 1
	oxy *= 0.5
	var bh := maxi(1, int(hp_cap() * sk("breathe") / 100.0))
	_p_heal(bh)
	_fx_ring(vis_pos, Color("7fd8ff"), 1.2, 0.5, 5.0)
	_pop(pos, "+%d HP" % bh, Color("ff8a9a"))
	msg = "Deep breath: +%d HP for half your air (%d left this floor)" % [bh, can_n]
	_sfx("pot")


func _breathe_draw() -> void:
	var r := _breathe_rect()
	var col := Color("7fd8ff") if can_n > 0 else Color(1, 1, 1, 0.3)
	_panel(r, col, 0.2 if can_n > 0 else 0.06, false)
	_ctext("BREATHE", r.get_center() + Vector2(0, -10), 18, col)
	_ctext("x%d" % can_n, r.get_center() + Vector2(0, 16), 20, Color.WHITE if can_n > 0 else Color(1, 1, 1, 0.4))


func _mk(c: Vector2i) -> bool:
	return mstat.has(c) and (mstat[c] as Dictionary).has("mk")


func _rally() -> float:
	return 1.0 + sk("rally") / 100.0


func _on_warp(from: Vector2i) -> void:
	if relic_n("uwarp") > 0:
		_root(5)
	if sk("apx_jump") > 0.0:
		for jc in _near_mons(pos, int(sk("apx_jump")), []):
			if mons.has(jc) and _st_ok(jc) and not _mk(jc):
				_st_get(jc)["mk"] = true
				_pop(jc, "MARKED", Color("8fa8ff"))
		if sk("drone") > 0.0:
			_drone_fire()
	if sk("apx_brift") > 0.0:
		_tr_heal(maxi(1, int(hp_cap() * sk("apx_brift") / 100.0)))
		if from.x >= 0 and from != pos:
			for bc in _near_mons(from, 1, []):
				if mons.has(bc) and _st_ok(bc):
					_st_get(bc)["bleed"] = [maxi(3, int(sk("bleed"))), _bleed_dmg(bc)]
					_pop(bc, "BLEED", Color("ff4d6d"))
	if sk("wslip") > 0.0:
		mom_steps += int(sk("wslip"))
	if sk("wshield") > 0.0:
		sh = mini(sh_cap(), sh + int(sk("wshield")))
	if sk("wair") > 0.0:
		oxy = minf(oxy_max, oxy + sk("wair"))
	if sk("rift") > 0.0 and from != pos and from.x >= 0:
		var rd := maxi(1, int(float(p_atk()) * sk("rift") / 100.0))
		_fx_ring(Vector2(from), Color("a68cff"), 1.3, 0.45, 5.0)
		for rc in _near_mons(from, 1, []):
			if tur.has(rc) and int(tur[rc].get("hk", 0)) > 0:
				continue
			_adv_damage_mon(rc, rd, Color("a68cff"))


func _root(n: int) -> void:
	if gm("anchored"):
		_pop(pos, "ANCHORED", Color("6fcf5a"))
		return
	root_n = maxi(root_n, n)
	walk.clear()
	_pop(pos, "ROOTED", Color("c07cff"))


func _recall() -> bool:
	if mode != "adv" or sk("recall") <= 0.0 or warp_rc:
		return false
	var dst := warp_bc if warp_bc.x >= 0 else warp_home
	if dst.x < 0 or mons.has(dst) or dst == pos:
		return false
	warp_rc = true
	hp = maxi(1, int(hp_cap() * sk("recall") / 100.0))
	pos = dst
	walk.clear()
	_adv_update_vis()
	_pop(pos, "RECALL", Color("a68cff"))
	_fx_ring(Vector2(pos), Color("a68cff"), 1.6, 0.6, 6.0)
	msg += "   Emergency Recall! Warped to safety"
	_sfx("warp")
	return true


func _tool_spend(i: int) -> void:
	_ck_tool()
	if sk("apx_asm") > 0.0:
		scrap += int(sk("apx_asm"))
	if sk("apx_arc") > 0.0:
		_arc_foundry()
	if sk("overclk") > 0.0:
		sh = mini(sh_cap(), sh + int(sk("overclk")))
	if _nr_encore():
		return
	tool_uses += 1
	if relic_n("spare") > 0 and tool_uses % 3 == 0:
		_pop(pos, "REFUNDED", Color("4fd1c5"))
		if syn("spare", "anchor"):
			sh = mini(sh_cap(), sh + 3)
		return
	if gm("echoc") and not echoc_used:
		echoc_used = true
		_pop(pos, "TOOL SAVED", Color("4fd1c5"))
		return
	if randf() * 100.0 < sk("tinker") + (15.0 if set_on("crew", 3) else 0.0):
		_pop(pos, "TOOL SAVED", Color("4fd1c5"))
		return
	inv.remove_at(i)


func _skip_val() -> int:
	return 3 + floor_n


func _drone_fire() -> void:
	var dts: Array = []
	for dt0 in _near_mons(pos, 3, []):
		if tur.has(dt0) and int(tur[dt0].get("hk", 0)) > 0:
			continue
		if _mk(dt0):
			dts.push_front(dt0)
		else:
			dts.append(dt0)
	for dt in dts:
		_fx_bolt(Vector2(pos) + Vector2(0, -0.4), Vector2(dt), Color("4fd1c5"))
		var ddmg := maxi(1, int(float(p_atk()) * sk("drone") / 100.0 * _rally()))
		_adv_damage_mon(dt, ddmg, Color("4fd1c5"))
		_ck_drone(dt, ddmg)
		if mons.has(dt) and not tur.has(dt) and not _boss_cell(dt) and ["hunter", "rager"].find(String(kinds.get(dt, ""))) < 0:
			kinds[dt] = "hunter"
			_pop(dt, "HUNTS YOU", Color("ff8a5b"))
		if relic_n("uplink") > 0:
			_uplink_apply(dt)
			if syn("uplink", "storm"):
				for ao in _near_mons(dt, 2, [dt]):
					if mons.has(ao) and ao != dt:
						_fx_bolt(Vector2(dt), Vector2(ao), Color("9fe8ff"))
						_adv_damage_mon(ao, maxi(1, ddmg / 2), Color("9fe8ff"))
						_uplink_apply(ao)
						break
		if sk("apx_merc") > 0.0 and not mons.has(dt):
			coins += int(sk("apx_merc"))
			_pop(dt, "+%d" % int(sk("apx_merc")), Color("ffd84f"))
			if randf() < 0.10 and _adv_give_gear(_adv_roll_gear(null, 0)):
				_pop(pos, "GEAR!", Color("ffd84f"))
		break


func _uplink_apply(c: Vector2i) -> void:
	if not mons.has(c):
		return
	var wt := gtr(String(equip.get("weapon", "")))
	if wt.has("ignite"):
		_st_burn(c, 3 + int(sk("kindle")), 2 + floor_n / 2)
	if wt.has("toxin"):
		_st_poison(c, 1)
	if wt.has("static") and randf() < 0.25 + sk("conduct") / 100.0:
		_st_stun(c, 1 + relic_n("storm"))
	if wt.has("frostbite") and _st_ok(c) and mons.has(c) and not bool(_st_get(c).get("chill", false)):
		mstat[c]["chill"] = true
		_st_stun(c, 1)


func _arc_foundry() -> void:
	for mc in _near_mons(pos, int(sk("apx_arc")), []):
		if not mons.has(mc) or (tur.has(mc) and int(tur[mc].get("hk", 0)) > 0):
			continue
		var pre := _elems(mc)
		match randi() % 4:
			0:
				_st_burn(mc, 3 + int(sk("kindle")), 2 + floor_n / 6)
			1:
				_st_poison(mc, 2)
			2:
				_st_stun(mc, 1)
			_:
				if _st_ok(mc):
					_st_get(mc)["chill"] = true
				_st_stun(mc, 1)
		_fx_bolt(Vector2(pos), Vector2(mc), Color("ff5fd2"))
		var hit := maxi(1, p_atk() / 3)
		if not mons.has(mc):
			continue
		var left := _react(mc, pre, mon_hp_now(mc) - hit)
		_adv_damage_mon(mc, mon_hp_now(mc) - left, Color("ff5fd2"))


func _asm_build() -> void:
	if sk("apx_asm") > 0.0 and _give_use(_random_use()):
		_pop(pos, "TOOL BUILT", Color("4fd1c5"))


func _sell_val(id: String) -> int:
	return int(float(gprice(id) / 2) * (1.0 + sk("apprais") / 100.0)) + int(gear_defs[gb(id)]["tier"]) * int(sk("c_trade"))


func _forge_cost(id: String) -> int:
	return int(gear_defs[gb(id)]["tier"]) * int(sk("reforge"))


func _chr_forge_rect(k: int) -> Rect2:
	return Rect2(416, 666 + chr_off + _inv_y(k) + 8, 124, 42)


func _reforge(k: int) -> void:
	var id := String(bag[k])
	var cost := _forge_cost(id)
	if scrap < cost:
		_sfx("blocked")
		return
	scrap -= cost
	var base := gb(id)
	var gd: Dictionary = gear_defs[base]
	var sl := String(gd["slot"])
	if sl == "weapon" or sl == "ranged":
		bag[k] = _with_stats(base + _roll_traits(null, int(gd["tier"]), int((gd["stats"] as Dictionary).get("range", 0)) > 0), id)
	else:
		bag[k] = _with_stats(base + _roll_mods(null, int(gd["tier"]), sl), id)
	_asm_build()
	_sfx("big")


func _elems(c: Vector2i) -> Array:
	var out: Array = []
	if not mstat.has(c):
		return out
	var st: Dictionary = mstat[c]
	if st.has("burn"):
		out.append("fire")
	if st.has("psn"):
		out.append("toxic")
	if int(st.get("stun", 0)) > 0:
		out.append("cryo" if st.has("chill") else "shock")
	if sk("apx_blood") > 0.0 and st.has("bleed"):
		out.append("blood")
	return out


func _react(c: Vector2i, pre: Array, left: int) -> int:
	if sk("react") <= 0.0 or left <= 0 or not mons.has(c) or (int(_st_get(c).get("rcd", 0)) > 0 and relic_n("ccore") <= 0):
		return left
	var post := _elems(c)
	var pair := ""
	for e in post:
		if pre.has(e):
			continue
		for o in post:
			if o != e:
				var ab := PackedStringArray([String(e), String(o)])
				ab.sort()
				pair = "+".join(ab)
	if pair == "":
		return left
	var m := sk("react")
	var base := 2 + level / 2
	var st: Dictionary = mstat[c]
	match pair:
		"cryo+fire":
			left -= int(base * m)
			for o2 in _near_mons(c, 1, []):
				_adv_damage_mon(o2, int(base * m), Color("e8f4ff"))
			_pop(c, "STEAM", Color("e8f4ff"))
			_fx_burst(Vector2(c), Color("e8f4ff"), 14, 3.0, 0.5, 5.0)
		"shock+toxic":
			st["corr"] = 3
			_pop(c, "CORRODE", Color("b6ff3c"))
		"fire+toxic":
			var bd: Array = st.get("burn", [0, 0])
			var pd: Array = st.get("psn", [0, 0])
			left -= int(float(int(pd[0]) * 3 + int(bd[1])) * m)
			st.erase("burn")
			st.erase("psn")
			_pop(c, "DETONATE", Color("ff9a3c"))
			_fx_burst(Vector2(c), Color("ff9a3c"), 18, 3.6, 0.5, 5.0)
		"cryo+shock":
			st["stun"] = maxi(int(st.get("stun", 0)), 2)
			left -= int((base + 1) * m)
			_pop(c, "SHATTER", Color("9fe8ff"))
			_fx_ring(Vector2(c), Color("9fe8ff"), 1.2, 0.4, 5.0)
		"blood+cryo", "blood+fire", "blood+shock", "blood+toxic":
			left -= int((base + 2) * m)
			_pop(c, "BOIL", Color("ff4d6d"))
			_fx_burst(Vector2(c), Color("ff4d6d"), 14, 3.0, 0.5, 5.0)
		_:
			return left
	if sk("apx_blood") > 0.0:
		_tr_heal(maxi(1, int(hp_cap() * sk("apx_blood") / 100.0)))
	st["rcd"] = 2
	return left


func _tur_friendly(c: Vector2i) -> void:
	for di in TDIRS.size():
		var dv: Vector2i = TDIRS[di]
		for s in range(1, TUR_RANGE + 1):
			var n: Vector2i = c + dv * s
			if not _aopen(n) or vaults.has(n) or n == pos:
				break
			if mons.has(n):
				if tur.has(n) and int(tur[n].get("hk", 0)) > 0:
					break
				tur[c]["d"] = di
				_fx_bolt(Vector2(c) + Vector2(dv) * 0.3, Vector2(n), Color("4fd1c5"))
				_adv_damage_mon(n, maxi(1, int(float(_ranged_dmg(c)) * _rally())), Color("4fd1c5"))
				_sfx("turret")
				return
var p_burn_d := 0
var p_acid := 0
var p_frost := 0
var stun_hits := 0


# Extra effects when an affixed enemy lands a hit on you.
func _aff_on_hit(src: Vector2i, a: int) -> void:
	if not mons.has(src):
		return
	if gm("vinestep"):
		_st_root(src, 1)
	var af := String(affix.get(src, ""))
	match af:
		"snare":
			_root(2)
		"burn":
			if not gm("insulated"):
				p_burn = 3
				p_burn_d = maxi(1, int(round(float(mon_atk(src)) * 0.1)))
				_pop(pos, "BURNING", Color("ff7a2e"))
		"acid":
			p_acid = 2 if gm("mindshield") else 3
			_pop(pos, "ARMOUR MELTS", Color("b6ff3c"))
		"frost":
			p_frost = 2 if gm("mindshield") else 3
			_pop(pos, "CHILLED", Color("8fd8ff"))
		"void":
			oxy = maxf(0.0, oxy - 5.0)
			_pop(pos, "-5 AIR", Color("a77bff"))
		"stun", "fast":
			if af == "stun":
				if gm("ironwill"):
					return
				stun_hits += 1
				if stun_hits % 3 != 0:
					return
			var d2 := dmg_taken(a)
			var ab2 := mini(sh, d2)
			sh -= ab2
			hp -= d2 - ab2
			_pop(pos, ("STUNNED -%d" if af == "stun" else "-%d") % d2, Color("fff07a") if af == "stun" else Color("ff6a6a"))
			msg += "   %s free hit for %d" % [("Stunned!" if af == "stun" else "Second strike!"), d2]


func _p_status_tick() -> bool:
	if p_acid > 0:
		p_acid -= 1
	if p_frost > 0:
		p_frost -= 1
	if p_burn > 0:
		p_burn -= 1
		return _adv_env_hurt(p_burn_d, "Burning! You lose %d health", "You burned to death", "spike")
	return true


func gmods(id: String) -> Array:
	var out: Array = []
	if id.contains("@"):
		for s in id.get_slice("@", 1).split(","):
			if MOD_DEFS.has(s):
				out.append(String(s))
	return out


func gm(mid: String) -> bool:
	if mode != "adv":
		return false
	for slot in ["helmet", "armour", "boots", "trinket"]:
		if gmods(String(equip.get(slot, ""))).has(mid):
			return true
	return false


func _roll_mods(rng: RandomNumberGenerator, tier: int, slot: String) -> String:
	var r := rng.randf() if rng != null else randf()
	var n := 0
	if tier <= 1:
		n = 1 if r < 0.3 else 0
	elif tier == 2:
		n = 1 if r < 0.6 else 0
	elif tier == 3:
		n = 1 if r < 0.7 else 2
	else:
		n = 2
	if sk("master") > 0.0:
		n += 1
	if tier >= 6:
		n += 1
	var pool: Array = []
	var hipool: Array = []
	for mid in MOD_DEFS:
		if String(MOD_DEFS[mid]["slot"]) == slot:
			if bool(MOD_DEFS[mid].get("hi", false)):
				hipool.append(String(mid))
			else:
				pool.append(String(mid))
	var picked: Array[String] = []
	while picked.size() < n and (pool.size() > 0 or hipool.size() > 0):
		if tier >= 4 and hipool.size() > 0 and randf() < 0.12:
			var hix := randi() % hipool.size()
			picked.append(String(hipool[hix]))
			hipool.remove_at(hix)
			continue
		if pool.is_empty():
			break
		var i := (rng.randi() if rng != null else randi()) % pool.size()
		picked.append(String(pool[i]))
		pool.remove_at(i)
	if picked.is_empty():
		return ""
	return "@" + ",".join(picked)

const AFFIX_DEFS := {
	"plated": {"n": "Plated", "d": "Takes 2+ less damage from every hit", "col": Color("9fb3d9"), "s": "plated"},
	"regen": {"n": "Regenerating", "d": "Heals 2 health every step", "col": Color("6dff9a"), "s": "regen"},
	"leech": {"n": "Leeching", "d": "Heals itself when it hits you", "col": Color("ff5d8a"), "s": "leech"},
	"spiny": {"n": "Spiny", "d": "Reflects damage back at you", "col": Color("ffb347"), "s": "spiny"},
	"frenzy": {"n": "Frenzied", "d": "Hits much harder when below half health", "col": Color("ff4a4a"), "s": "frenzy"},
	"volatile": {"n": "Bomb", "d": "Explodes when killed, hurting you if you are adjacent", "col": Color("ff8a3c"), "s": "bomb"},
	"evasive": {"n": "Evasive", "d": "20% chance to dodge your attacks", "col": Color("9fe8ff"), "s": "evasive"},
	"warded": {"n": "Immune", "d": "Immune to burn, poison and stun", "col": Color("c07cff"), "s": "immune"},
	"burn": {"n": "Burning", "d": "Hits set you on fire: 10% of its damage a step for 3 steps", "col": Color("ff7a2e"), "s": "burn"},
	"acid": {"n": "Acidic", "d": "Hits halve your armour for 3 steps", "col": Color("b6ff3c"), "s": "acid"},
	"frost": {"n": "Frost", "d": "Hits halve your damage for 3 steps", "col": Color("8fd8ff"), "s": "frost"},
	"stun": {"n": "Stunning", "d": "Every 3rd hit stuns you, giving it a free hit", "col": Color("fff07a"), "s": "stun"},
	"snare": {"n": "Snaring", "d": "Hits root you: 2 extra move presses to break free", "col": Color("6fcf5a"), "s": "snare"},
	"void": {"n": "Void", "d": "Hits drain 5 air", "col": Color("a77bff"), "s": "void"},
	"brute": {"n": "Brute", "d": "Double health", "col": Color("d98a5b"), "s": "brute"},
	"fast": {"n": "Fast", "d": "Hits twice per turn", "col": Color("7affd8"), "s": "fast"},
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
	var wa: Array = gtr(String(equip.get("ranged" if shooting else "weapon", "")))
	if nr_tmp_tr.is_empty():
		return wa
	wa = wa.duplicate()
	wa.append_array(nr_tmp_tr)
	return wa


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
	for mid in gmods(id):
		parts.append(String(MOD_DEFS[mid]["n"]))
	return " + ".join(parts)


func gprice(id: String) -> int:
	return int(gear_defs[gb(id)]["price"]) + 14 * (gtr(id).size() + gmods(id).size())


func _gear_desc_id(id: String) -> String:
	return _gear_desc(gear_defs[gb(id)], id)


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
	if sk("master") > 0.0:
		n += 1
	if tier >= 6:
		n += 1
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
		if int(TRAIT_DEFS[tid].get("min", 0)) > tier:
			continue
		pool.append(String(tid))
	var picked: Array[String] = []
	while picked.size() < n and pool.size() > 0:
		var i := (rng.randi() if rng != null else randi()) % pool.size()
		if randf() * 100.0 < sk("attune") or (ranged and picked.is_empty() and randf() < 0.5):
			var ei: Array = []
			for j in pool.size():
				for tg2 in TRAIT_DEFS[pool[j]]["t"]:
					if ["fire", "shock", "cryo", "toxic"].has(tg2):
						ei.append(j)
						break
			if ei.size() > 0:
				i = int(ei[randi() % ei.size()])
		picked.append(String(pool[i]))
		pool.remove_at(i)
	return "@" + ",".join(picked)


const CRIT_CAP := 60.0


func crit_chance() -> float:
	if sneak_slp:
		return 1000.0
	return minf(CRIT_CAP, _crit_raw())


func _crit_raw() -> float:
	return gear("crit") + sk("crit") + ((sk("rcrit") + _set_stat("rcrit")) if shooting else 0.0) + 4.0 * float(pk.get("crit", 0)) + (12.0 if has_tr("sharp") else 0.0) + 5.0 * relic_n("luckychip") + (10.0 if gcoin_buff() == 0 else 0.0) + tgt_crit + nr_l_crit


const DODGE_CAP := 50.0


func dodge_chance() -> float:
	return minf(DODGE_CAP, _dodge_raw())


func _dodge_raw() -> float:
	return gear("dodge") + sk("dodge") + (10.0 if has_tr("duelist") else 0.0) + (10.0 if gcoin_buff() == 1 else 0.0) + (10.0 if gm("reflex") and p_moved else 0.0) + nr_l_dodge


func _bleed_dmg(c: Vector2i) -> int:
	if sk("bleed") > 0.0:
		return maxi(1, mon_hp_max(c) / 10)
	return 1 + floor_n / 6


func _repo_bonus() -> int:
	var hi := int(sk("repo"))
	if hi <= 0:
		return 0
	return randi_range(1 if hi <= 10 else 10, hi)


func thorns_dmg() -> int:
	return (3 if sh > 0 and set_on("riot", 3) else 0) + int(gear("thorns")) + ((2 + floor_n / 6) if has_tr("thorned") else 0) + 2 * relic_n("thornmail")


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


func _st_root(c: Vector2i, steps: int) -> void:
	if not mons.has(c) or not _st_ok(c) or tur.has(c):
		return
	_st_get(c)["root"] = maxi(int(_st_get(c).get("root", 0)), steps)
	_pop(c, "ROOT", Color("6fcf5a"))
	_fx_ring(Vector2(c), Color("6fcf5a"), 0.8, 0.3, 3.0)


func _rooted(c: Vector2i) -> bool:
	return mstat.has(c) and int(mstat[c].get("root", 0)) > 0


func _st_stun(c: Vector2i, steps: int) -> void:
	if not mons.has(c) or not _st_ok(c) or _boss_cell(c) or tur.has(c):
		return
	_st_get(c)["stun"] = maxi(int(_st_get(c).get("stun", 0)), steps)
	_pop(c, "STUN", Color("ffe14f"))
	_fx_ring(Vector2(c), Color("ffe14f"), 0.8, 0.3, 3.0)


func _st_burn(c: Vector2i, steps: int, dmg: int) -> void:
	if not mons.has(c) or not _st_ok(c):
		return
	var m := 2 if relic_n("pyro") > 0 and tag_n("fire") > 0 else 1
	_st_get(c)["burn"] = [steps + (2 if m > 1 else 0), dmg * m, 1 if _any_tr("flashpoint") else 0]
	_fx_burst(Vector2(c), Color("ff7a45"), 6, 2.4, 0.4, 4.0)


func _st_poison(c: Vector2i, add: int) -> void:
	if not mons.has(c) or not _st_ok(c):
		return
	var cap := 4 + (3 if relic_n("toxi") > 0 else 0) + int(sk("catal"))
	var cur: Array = _st_get(c).get("psn", [0, 0])
	mstat[c]["psn"] = [mini(cap, int(cur[0]) + add), 6]
	_fx_burst(Vector2(c), Color("8aff6a"), 5, 2.0, 0.4, 4.0)


func _tr_heal(n: int) -> void:
	if n <= 0:
		return
	_p_heal(n)
	_pop(pos, "+%d" % n, Color("ff8a9a"))


func _near_mons(c: Vector2i, r: int, exclude: Array) -> Array:
	var out: Array = []
	for m in mons:
		if m == c or exclude.has(m) or m == pos or _turned(m):
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
			mul += 0.5
		if tl.has("shatter") and _stunned(c):
			mul += 0.5 + (0.5 if relic_n("frost") > 0 else 0.0)
		if tl.has("rampage"):
			mul += 0.03 * float(mini(5 + 3 * relic_n("overclock"), tr_streak))
		if tl.has("marked"):
			add += mini(4, tr_mark if tr_last == c else 0)
		if tl.has("rhythm") and (tr_hits + 1) % 4 == 0:
			mul += 1.0
	var gz := false
	sneak_slp = false
	tgt_crit = 10.0 if (gm("tvisor") and (_stunned(c) or _rooted(c))) else 0.0
	if _st_unaware(c):
		st_hit_c = c
		st_quiet = true
		var slp := _idle_sleep(c)
		# halved in b102 (was 1.0/0.5 base, and full crit mult on sleepers)
		mul += 0.5 * ((1.0 if slp else 0.5) + sk("st_sneak") / 100.0 + (0.3 if gm("shadowcharm") else 0.0) + (0.5 if tl.has("assassin") else 0.0))
		if slp:
			sneak_slp = true
		_pop(c, "SNEAK", Color("c07cff"))
	if gm("bfocus"):
		var bn := 0
		for bm in mons:
			if bm != pos and adv_vis.has(bm):
				bn += 1
		add += mini(3, bn)
	if gm("berserkb") and hp * 2 < hp_cap():
		mul += 0.2
	if cw_ready and gm("counterw"):
		add += 2
		cw_ready = false
	if not tl.is_empty():
		if tl.has("heavy"):
			mul += 0.4
		if tl.has("firstblood") and tr_hits == 0:
			mul += 1.0
		if tl.has("underdog"):
			var vn := 0
			for vm in mons:
				if vm != pos and adv_vis.has(vm):
					vn += 1
			if vn >= 3:
				mul += 0.3
		if tl.has("crush") and (_rooted(c) or not _aopen(c + Vector2i(signi(c.x - pos.x), signi(c.y - pos.y)))):
			mul += 0.5
		if tl.has("pin") and _rooted(c):
			mul += 0.25
		if tl.has("rot") and mstat.has(c) and mstat[c].has("psn"):
			mul += 0.15
		if shooting and tl.has("sniper"):
			add += mini(4, maxi(absi(c.x - pos.x), absi(c.y - pos.y)))
		if shooting and tl.has("hollow") and mon_hp_now(c) >= mon_hp_max(c):
			mul += 0.3
		if tl.has("gambler"):
			var gr := randf()
			if gr < 0.2:
				mul += 1.0
				_pop(c, "DOUBLE", Color("ffd84f"))
			elif gr < 0.3:
				gz = true
	if repr_ready and _any_tr("reprisal"):
		mul += 0.5
		repr_ready = false
	add += mini(4, tag_kinds()) * relic_n("prism")
	if sk("finish") > 0.0 and mon_hp_now(c) * 2 <= mon_hp_max(c):
		mul += sk("finish") / 100.0
	if sk("opener") > 0.0 and mon_hp_now(c) >= mon_hp_max(c):
		mul += sk("opener") / 100.0
	if sk("berserk") > 0.0 and hp * 2 < hp_cap():
		mul += sk("berserk") / 100.0
	if sk("pain") > 0.0:
		mul += sk("pain") * float(int((hp_cap() - hp) * 10 / maxi(1, hp_cap()))) / 100.0
	if syn("pyro", "frost") and _stunned(c) and mstat[c].has("chill") and mstat[c].has("burn"):
		mul += 0.5
	if sk("dfreeze") > 0.0 and _stunned(c) and mstat[c].has("chill"):
		mul += sk("dfreeze") / 100.0
	if set_on("cosmic", 2):
		mul += 0.15
	if relic_n("bbattery") > 0:
		mul += 0.3
	if sk("mark") > 0.0 and _st_ok(c):
		if _mk(c):
			mul += sk("mark") / 100.0
		else:
			_st_get(c)["mk"] = true
			_pop(c, "MARKED", Color("8fa8ff"))
	mul += _mx_hit_mul(c)
	var d := maxi(1, int(round(float(dmg + add) * mul)))
	if String(affix.get(c, "")) == "plated":
		d = maxi(1, d - 2 - floor_n / 8)
	if hex_armed and _st_ok(c):
		_hex_use()
		d = int(round(float(d) * _hex_mult()))
		hex_hit = true
		_pop(c, "HEX " + _mx_hex_txt(), Color("c07cff"))
	if mstat.has(c) and mstat[c].has("corr"):
		d = int(round(float(d) * 1.5))
	if gz:
		_pop(c, "WHIFF", Color("9aa3c7"))
		return 0
	return d


func _tr_on_hit(c: Vector2i, dealt: int, crit: bool, ranged: bool, left: int) -> int:
	# returns the target's remaining health after trait effects (<= 0 means dead)
	var tl := wtr()
	if relic_n("bbattery") > 0 and tr_depth == 0:
		hp = maxi(1, hp - maxi(1, hp_cap() / 100))
	tr_streak += 1
	tr_hits += 1
	tr_mark = (tr_mark + 1) if tr_last == c else 1
	tr_last = c
	if relic_n("luckychip") > 0 and crit:
		oxy = minf(oxy_max, oxy + 1.0 + (1.0 if syn("luckychip", "prism") else 0.0))
	if crit and set_on("crystal", 3):
		for so in _near_mons(c, 1, []):
			_adv_damage_mon(so, maxi(1, dealt / 2), Color("9fe8ff"))
	if crit and ranged and set_on("marksman", 3):
		ammo = mini(ammo_max(), ammo + 1)
		_pop(pos, "+1 AMMO", Color("6dff9a"))
	if crit and left > 0 and sk("bleed") > 0.0 and mons.has(c) and _st_ok(c):
		_st_get(c)["bleed"] = [int(sk("bleed")), _bleed_dmg(c)]
		_pop(c, "BLEED", Color("ff4d6d"))
	ck_crit = crit
	left = _mx_on_hit(c, dealt, left)
	if tl.is_empty() or tr_depth > 2:
		return left
	var el_pre := _elems(c)
	var els := _wels()
	tr_depth += 1
	if tl.has("siphon"):
		_tr_heal(int(float(maxi(1, int(dealt * 0.2)) * (2 if relic_n("bloodpact") > 0 else 1)) * (1.0 + sk("bpact") / 100.0)))
	if left > 0:
		if tl.has("execute") and not _boss_cell(c):
			var thr := 0.2 + 0.15 * relic_n("hood")
			if ranged and syn("hood", "deadeye") and maxi(absi(c.x - pos.x), absi(c.y - pos.y)) >= _shoot_range():
				thr += 0.1
			if float(left) <= float(mon_hp_max(c)) * thr:
				left = 0
				_pop(c, "EXECUTED", Color("ff4a4a"))
		if left > 0 and els.has("fire"):
			_st_burn(c, 3 + int(sk("kindle")), 2 + floor_n / 2)
		if left > 0 and els.has("shock") and randf() < 0.25 + sk("conduct") / 100.0:
			_st_stun(c, 1 + relic_n("storm"))
		if left > 0 and els.has("cryo") and _st_ok(c) and not bool(_st_get(c).get("chill", false)):
			mstat[c]["chill"] = true
			_st_stun(c, 1)
		if left > 0 and els.has("toxic"):
			_st_poison(c, 1)
		if left > 0 and tl.has("rooting") and randf() < 0.5:
			_st_root(c, 1)
	if tl.has("arc"):
		var tg := _near_mons(c, 2, [])
		var cnt := 1 + (2 if relic_n("storm") > 0 else 0)
		for i in mini(cnt, tg.size()):
			var o: Vector2i = tg[i]
			_fx_bolt(Vector2(c), Vector2(o), Color("9fe8ff"))
			if syn("storm", "frost") and _st_ok(o) and mons.has(o):
				_st_get(o)["chill"] = true
				_st_stun(o, 1)
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
	if left > 0 and tl.has("echoslam") and tr_hits % 4 == 0 and mons.has(c):
		left -= maxi(1, dealt)
		_pop(c, "ECHO -%d" % maxi(1, dealt), Color("c9a2ff"))
		_fx_ring(Vector2(c), Color("c9a2ff"), 0.8, 0.3, 3.0)
		if left > 0 and els.has("fire"):
			_st_burn(c, 3 + int(sk("kindle")), 2 + floor_n / 2)
		if left > 0 and els.has("shock") and randf() < 0.25 + sk("conduct") / 100.0:
			_st_stun(c, 1 + relic_n("storm"))
		if left > 0 and els.has("toxic"):
			_st_poison(c, 1)
	left = _tr_new_hit(c, dealt, crit, ranged, left, el_pre)
	left = _react(c, el_pre, left)
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
	if tl.has("stormfront") and _stunned(c) and tr_depth <= 3:
		for sfo in _near_mons(c, 1, []):
			_st_stun(sfo, 2)
	if shooting and tl.has("scav") and randf() < 0.25:
		ammo = mini(ammo_max(), ammo + 1)
		_pop(pos, "+1 AMMO", Color("6dff9a"))
	if not shooting and _rhas("hairtrig"):
		hair_free = true
	if gm("eyestorm"):
		eye_k += 1
		if eye_k >= 5 and tr_depth <= 3:
			eye_k = 0
			tr_depth += 1
			var ets := _near_mons(pos, 6, [c])
			for ei in mini(3, ets.size()):
				_fx_bolt(Vector2(pos), Vector2(ets[ei]), Color("ffe14f"))
				_adv_damage_mon(ets[ei], maxi(1, p_atk()), Color("ffe14f"))
			tr_depth -= 1
	if gm("earthshake") and tr_depth <= 3:
		for eo in _near_mons(pos, 2, [c]):
			_st_stun(eo, 1)
	if tr_depth <= 3 and set_on("void", 3):
		tr_depth += 1
		for vo in _near_mons(c, 2, []):
			_adv_damage_mon(vo, 2, Color("a68cff"))
		_tr_heal(2)
		tr_depth -= 1
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
		_tr_heal(int(float(maxi(1, hp_cap() / 10) * echo) * (1.0 + sk("bpact") / 100.0)))
	if tl.has("adrenaline"):
		oxy = minf(oxy_max, oxy + 20.0 * echo)
		_pop(pos, "+%d AIR" % (20 * echo), Color("7fd8ff"))
	if tl.has("barrier"):
		sh = mini(sh_cap(), sh + 8 * echo)
		_pop(pos, "+%d SHIELD" % (8 * echo), Color("7db2ff"))
	if tl.has("bounty"):
		var cn := (1 + floor_n / 5) * echo * coin_val()
		coins += cn
		_pop(c, "+%d coins" % cn, Color("ffc93c"))
	if relic_n("agreedy") > 0:
		coins += 2 * relic_n("agreedy")
		_pop(c, "+%d coins" % (2 * relic_n("agreedy")), Color("ffc93c"))
	if sk("kcoin") > 0.0:
		coins += int(sk("kcoin"))
		_pop(c, "+%d coin" % int(sk("kcoin")), Color("ffc93c"))
	if relic_n("scrapper") > 0 and randf() < (0.5 if syn("amidas", "scrapper") else 0.35):
		coins += coin_val()
		_pop(c, "+%d coin" % coin_val(), Color("ffc93c"))


func _wels() -> Array:
	var out: Array = []
	for e in ["fire", "shock", "cryo", "toxic"]:
		if tag_n(e) > 0:
			out.append(e)
	return out


func _any_tr(id: String) -> bool:
	return mode == "adv" and (gtr(String(equip.get("weapon", ""))).has(id) or gtr(String(equip.get("ranged", ""))).has(id))


func _rhas(id: String) -> bool:
	return mode == "adv" and gtr(String(equip.get("ranged", ""))).has(id)


func _tr_step_traits() -> void:
	if kb_pend.x >= 0:
		var kc := kb_pend
		kb_pend = Vector2i(-1, -1)
		if mons.has(kc):
			var kd := Vector2i(signi(kc.x - pos.x), signi(kc.y - pos.y))
			var kn := kc + kd
			if kd != Vector2i.ZERO and _aopen(kn) and not mons.has(kn) and not vaults.has(kn) and kn != pos:
				_adv_move_mon(kc, kn)
				_pop(kn, "KNOCKBACK", Color("ffd84f"))
	if _any_tr("regen") and adv_steps % 5 == 0:
		_tr_heal(2 if hp * 2 < hp_cap() else 1)
	if _any_tr("echostep") and adv_steps % 6 == 0:
		mom_steps += 1
	if gm("kinetic") and adv_steps % 3 == 0 and sh < mini(6, sh_cap()):
		sh += 1
	if gm("pdrone") and adv_steps % 15 == 0:
		var pdt := _near_mons(pos, 3, [])
		if pdt.size() > 0:
			_fx_bolt(Vector2(pos), Vector2(pdt[0]), Color("4fd1c5"))
			_adv_damage_mon(pdt[0], maxi(1, p_atk() / 4), Color("4fd1c5"))


func _tr_new_hit(c: Vector2i, dealt: int, crit: bool, ranged: bool, left: int, el_pre: Array) -> int:
	var tl := wtr()
	if tl.has("heavy"):
		oxy = maxf(0.0, oxy - 1.0)
	if tl.has("icicle") and el_pre.has("cryo"):
		for io in _near_mons(c, 1, []):
			_adv_damage_mon(io, maxi(1, dealt / 2), Color("9fe8ff"))
	if tl.has("ricochet") and ranged and randf() < 0.3:
		_act_ricochet(c, maxi(1, dealt / 2), true)
	if left <= 0 or not mons.has(c):
		return left
	if tl.has("conduit") and crit:
		_st_stun(c, 2)
	if tl.has("permafrost") and mstat.has(c) and mstat[c].has("chill") and not _stunned(c):
		var ph := int(mstat[c].get("pfh", 0)) + 1
		if ph >= 3:
			ph = 0
			_st_stun(c, 2)
			_pop(c, "FROZEN SOLID", Color("9fe8ff"))
		mstat[c]["pfh"] = ph
	if tl.has("contagion") and mstat.has(c) and mstat[c].has("psn"):
		var cn := _near_mons(c, 1, [])
		if cn.size() > 0:
			_st_poison(cn[0], 1)
	if tl.has("intimidate") and not _boss_cell(c) and not tur.has(c) and _st_ok(c) and not _stunned(c) and float(left) <= float(mon_hp_max(c)) * 0.3:
		_st_get(c)["stun"] = 1
		_pop(c, "SCARED", Color("ffb36b"))
	if tl.has("vampedge") and crit and _st_ok(c):
		_st_get(c)["bleed"] = [3, _bleed_dmg(c)]
		_pop(c, "BLEED", Color("ff4d6d"))
	if tl.has("knockback") and not _boss_cell(c) and not tur.has(c) and randf() < 0.3:
		kb_pend = c
	if tl.has("stormcaller") and _st_ok(c) and not bool(_st_get(c).get("sc", false)) and _elems(c).size() >= 3:
		mstat[c]["sc"] = true
		left -= dealt * 3
		_pop(c, "STORM x3", Color("ffe14f"))
	return left


func _tr_tick() -> void:
	# end of the player's step: damage over time and status wear-off
	_tr_step_traits()
	if mstat.is_empty() and affix.is_empty():
		return
	for c in mstat.keys():
		if not mons.has(c):
			mstat.erase(c)
			continue
		var st: Dictionary = mstat[c]
		if st.has("burn"):
			var b: Array = st["burn"]
			_adv_damage_mon(c, int(b[1]) * (2 if b.size() > 2 and int(b[2]) == 1 else 1), Color("ff7a45"))
			if not mons.has(c):
				mstat.erase(c)
				continue
			if b.size() > 2:
				b[2] = 0
			if _any_tr("inferno") and randf() < 0.5:
				for io in _near_mons(c, 1, []):
					if not mstat.has(io) or not mstat[io].has("burn"):
						_st_burn(io, 2, int(b[1]))
						break
			b[0] = int(b[0]) - 1
			if int(b[0]) <= 0:
				st.erase("burn")
		if st.has("psn"):
			var p: Array = st["psn"]
			_adv_damage_mon(c, int(p[0]) * (1 + 2 * (floor_n / 8)) * (2 if syn("pyro", "toxi") and st.has("burn") else 1), Color("8aff6a"))
			if not mons.has(c):
				mstat.erase(c)
				continue
			p[1] = int(p[1]) - 1
			if int(p[1]) <= 0:
				st.erase("psn")
		if st.has("bleed"):
			var bl: Array = st["bleed"]
			_adv_damage_mon(c, int(bl[1]), Color("ff4d6d"))
			if sk("crimson") >= 20.0:
				_tr_heal(maxi(1, int(bl[1]) / 2))
			if _any_tr("vampedge"):
				_tr_heal(maxi(1, int(bl[1]) / 4))
			if relic_n("bedge") > 0:
				var bh := int(gear("leech") + sk("leech"))
				if has_tr("siphon"):
					bh += maxi(1, int(int(bl[1]) * 0.2))
				if syn("bedge", "bloodpact"):
					bh *= 2
				if bh > 0:
					_tr_heal(bh)
			if not mons.has(c):
				mstat.erase(c)
				continue
			bl[0] = int(bl[0]) - 1
			if int(bl[0]) <= 0:
				st.erase("bleed")
		for tk in ["corr", "rcd", "root"]:
			if st.has(tk):
				st[tk] = int(st[tk]) - 1
				if int(st[tk]) <= 0:
					st.erase(tk)
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
	if floor_n < 3 or not ul(5):
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
var air_bonus := 0.0
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
		["Spiked Plating", "Enemies that hit you take %s%% of the damage back", "thorns", [10, 15]],
		["Trauma Kit", "Medkits heal %s%% more", "medk", [25, 50]],
		["Max Shields", "+%s max shields", "maxsh", [8, 16]],
		["Last Stand", "Below 30%% health you take %s%% less damage", "laststand", [30, 50]]]],
	["OFFENSE", Color("ffb347"), [
		["Edge", "+%s melee attack", "atk", [1, 2]],
		["Precision", "+%s%% crit chance", "crit", [6, 12]],
		["Siphon Core", "Heal %s on every hit", "leech", [1, 2]],
		["Finisher", "+%s%% damage to enemies under half health", "finish", [25, 50]],
		["Berserker", "+%s%% damage while under half health", "berserk", [15, 25]],
		["Overdrive", "Crits deal %s%% more damage", "critmult", [25, 50]]]],
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
	["SHADOW", Color("c07cff"), [
		["Backstab", "Sneak attacks deal +%s%% more damage", "st_sneak", [25, 50]],
		["Soft Step", "Enemies need %s extra step(s) to notice you", "st_slow", [1, 2]],
		["Low Profile", "Enemy sight reaches %s tile(s) less", "st_cone", [1, 2]],
		["Silent Kill", "Unseen kills give %s%% more XP", "st_xp", [25, 50]],
		["Shadow Mend", "Unseen kills restore %s air", "st_air", [5, 10]],
		["Vanish", "Unseen kills cloak you for %s steps", "st_vanish", [2, 4]]]],
	["OXYGEN", Color("7fd8ff"), [
		["Deep Lungs", "+%s max air", "air", [12, 24]],
		["Easy Breathing", "%s%% less air used per step", "airsave", [6, 12]],
		["Pod Boost", "Air pods give %s%% more air", "pod", [25, 50]],
		["Air Siphon", "Every kill raises your max air by %s", "airkill", [1, 2]],
		["Recycler", "O2 stations also heal %s%% of max health (3 times per floor)", "stationheal", [15, 30]],
		["Deep Breath", "Adds a BREATHE button: spend half your current air to heal %s%% of max health (2 uses per floor)", "breathe", [25, 50]]]],
]

# Outer hybrid branches: branch g sits in the gap between inner branches g and g+1.
const SK_BR2 := [
	["BLOODWORK", Color("ff4d6d"), [
		["Blood Price", "Kills heal %s%% of max health", "kheal", [5, 10]],
		["Hemorrhage", "Crits make enemies bleed for 10%% of their max health a step, for %s steps", "bleed", [3, 5]],
		["Transfusion", "Healing past max health becomes shield (up to %s per heal)", "transf", [4, 8]],
		["Pain Engine", "+%s%% damage for every 10%% of health you are missing", "pain", [3, 5]],
		["Blood Pact", "Siphon and Bloodlust traits heal %s%% more", "bpact", [50, 100]],
		["Crimson Engine", "Medkits don't work, but all healing is doubled and kills heal %s%% of max health. Rank 2: bleeding enemies heal you for 50%% of the bleed damage", "crimson", [10, 20]]]],
	["ELEMENTAL", Color("ff5fd2"), [
		["Kindling", "Your burns last +%s step(s)", "kindle", [1, 2]],
		["Conductor", "+%s%% stun chance from Static", "conduct", [10, 20]],
		["Deep Freeze", "Frozen enemies take +%s%% damage", "dfreeze", [25, 50]],
		["Catalyst", "Poison can stack +%s higher", "catal", [2, 4]],
		["Attunement", "Found weapons are %s%% more likely to roll elemental traits", "attune", [25, 50]],
		["Elemental Reactions", "Mixing elements on an enemy triggers reactions: fire+cryo Steam, shock+toxic Corrode, fire+toxic Detonate, shock+cryo Shatter (power x%s)", "react", [1, 1.5]]]],
	["ENGINEERING", Color("4fd1c5"), [
		["Tinkerer", "%s%% chance a tool isn't used up", "tinker", [25, 50]],
		["Overclocked", "Using a tool gives +%s shield", "overclk", [4, 8]],
		["Power Cell", "Your class power recharges %s%% faster", "pcell", [25, 50]],
		["Supply Line", "The first visit to each merchant gives %s free tool(s)", "supply", [1, 2]],
		["Field Repair", "O2 stations give +%s shield (3 times per floor)", "frepair", [5, 10]],
		["Auto-Fabricator", "Every %sth coin you pick up builds a random tool into a free slot (if your slots are full, gain 4 shield instead)", "fab", [6, 4]]]],
	["SALVAGE", Color("c9a36b"), [
		["Dismantle", "Selling gear also gives %s scrap per tier", "dismantle", [1, 2]],
		["Reforge", "In the BAG, reroll an item's traits or mods for %s scrap per tier", "reforge", [3, 2]],
		["Vault Cracker", "Vaults give %s extra tool(s)", "vault", [1, 2]],
		["Repo Man", "Thieves you kill drop a random extra amount of coins, up to %s (at least 1, or 10 at rank 2)", "repo", [10, 20]],
		["Appraiser", "Gear sells for %s%% more", "apprais", [25, 50]],
		["Masterwork", "Found gear rolls +1 trait or mod, with a %s%% chance of a higher tier", "master", [5, 15]]]],
	["COMMAND", Color("8fa8ff"), [
		["Mark Target", "Your first hit on an enemy marks it: marked enemies take +%s%% damage from all sources", "mark", [15, 30]],
		["Turret Hack", "Bump an enemy turret to hack it: it turns on its friends for %s steps", "thack", [6, 12]],
		["Hold the Line", "+%s armour while an enemy is next to you", "hold", [2, 4]],
		["Rally", "Your drone and hacked turrets deal +%s%% damage", "rally", [25, 50]],
		["Suppress", "Marked enemies deal %s%% less damage to you", "msupp", [20, 35]],
		["Drone Companion", "Every 12 steps a drone zaps an enemy within 3 tiles (marked enemies first) for %s%% of your attack. Enemies it zaps turn into Hunters", "drone", [100, 200]]]],
	["WARP", Color("a68cff"), [
		["Warp Beacon", "Each floor you get %s Warp Beacon: use one to drop a beacon, use it again to warp back. Rank 2: warping to the beacon heals 25%% of max health", "beacon", [1, 1]],
		["Slipstream", "After any warp (Blink, Grapple, Rewind, Beacon) your next %s steps cost no air", "wslip", [6, 12]],
		["Phase Shield", "Warping gives +%s shield", "wshield", [8, 16]],
		["Rift", "Warping leaves a rift that hits enemies next to where you left for %s%% of your attack", "rift", [100, 200]],
		["Warp Lungs", "Warping restores %s air", "wair", [25, 50]],
		["Emergency Recall", "Once per floor, a killing blow warps you to your beacon (or the floor start) with %s%% health instead", "recall", [25, 40]]]],
]

# Apex keystones: between outer branch g and g+1, need both keystones, 3 points, 1 rank.
const SK_APX := [
	["Boiling Blood", "Bleeds count as an element for reactions, and every reaction heals you %s%% of max health", "apx_blood", [10]],
	["Arc Foundry", "Every tool you use hits each enemy within %s tiles with a random element", "apx_arc", [2]],
	["Assembly Line", "Every sale or reforge builds a random tool, and every tool you use gives %s scrap", "apx_asm", [1]],
	["Mercenaries", "Your drone fires every 6 steps, and drone kills drop %s coins with a 10%% gear chance", "apx_merc", [2]],
	["Tactical Jump", "Warping marks every enemy within %s tiles and fires your drone", "apx_jump", [2]],
	["Blood Rift", "Warping heals %s%% of max health and makes enemies next to where you left bleed", "apx_brift", [15]],
]


func _sk_max(id: String) -> int:
	return 1 if bool(sk_defs[id].get("apex", false)) else 2


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
	var rr2 := [350.0, 420.0, 420.0, 490.0, 490.0, 560.0]
	var ph2 := [0.0, -7.0, 7.0, -5.0, 5.0, 0.0]
	for g in SK_BR2.size():
		var th2 := deg_to_rad(SK_A0 + 60.0 * g + 30.0)
		var nodes2: Array = SK_BR2[g][2]
		for n in 6:
			var a2 := th2 + deg_to_rad(float(ph2[n]))
			var nd2: Array = nodes2[n]
			var id2 := "o%dn%d" % [g, n]
			sk_defs[id2] = {"b": 10 + g, "n": n, "name": nd2[0], "d": nd2[1], "stat": nd2[2], "v": nd2[3], "key": n == 5, "outer": true, "ring": 1 if n == 0 else (2 if n < 3 else (3 if n < 5 else 4)),
				"pos": SK_C + Vector2(cos(a2), sin(a2)) * float(rr2[n]), "col": SK_BR2[g][1]}
			sk_adj[id2] = []
		for e in [[0, 1], [0, 2], [1, 3], [2, 4], [3, 5], [4, 5]]:
			_sk_link("o%dn%d" % [g, e[0]], "o%dn%d" % [g, e[1]])
		_sk_link("o%dn0" % g, "b%dn4" % g)
		_sk_link("o%dn0" % g, "b%dn3" % ((g + 1) % SK_N))
	for g in SK_APX.size():
		var g2 := (g + 1) % SK_BR2.size()
		var tha := deg_to_rad(SK_A0 + 60.0 * g + 60.0)
		var ax: Array = SK_APX[g]
		var ida := "x%d" % g
		var ka := "o%dn5" % g
		var kb := "o%dn5" % g2
		sk_defs[ida] = {"b": 20 + g, "n": 6, "name": ax[0], "d": ax[1], "stat": ax[2], "v": ax[3], "key": true, "apex": true, "req": [ka, kb], "ring": 5,
			"pos": SK_C + Vector2(cos(tha), sin(tha)) * 610.0, "col": (SK_BR2[g][1] as Color).lerp(SK_BR2[g2][1], 0.5)}
		sk_adj[ida] = []
		_sk_link(ida, ka)
		_sk_link(ida, kb)
	_ck_make()


func _sk_label(txt: String, c: Vector2, col: Color) -> void:
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 16.0
	draw_rect(Rect2(c.x - w * 0.5, c.y - 14.0, w, 28.0), Color(0.04, 0.05, 0.08, 0.85))
	_ctext(txt, c, 18, col)


func _sk_link(a: String, b: String) -> void:
	sk_edges.append([a, b])
	sk_adj[a].append(b)
	sk_adj[b].append(a)


func sk(stat: String) -> float:
	if mode != "adv":
		return 0.0
	var tot := float(_cls_pass().get(stat, 0.0))
	for id in skills:
		var r := int(skills[id])
		if r > 0 and sk_defs.has(id) and String(sk_defs[id]["stat"]) == stat:
			if sk_defs[id].has("cls") and not _ck_on(String(id)):
				continue
			var va: Array = sk_defs[id]["v"]
			tot += float(va[mini(r, va.size()) - 1])
	return tot


func sk_rank(id: String) -> int:
	return int(skills.get(id, 0))


func sk_cost(id: String) -> int:
	if bool(sk_defs[id].get("apex", false)):
		return 3
	return 2 if bool(sk_defs[id]["key"]) else 1


func skill_spent() -> int:
	var tot := 0
	for id in skills:
		if sk_defs.has(id):
			tot += int(skills[id]) * sk_cost(String(id))
	return tot


func sk_unlocked(id: String) -> bool:
	var d: Dictionary = sk_defs[id]
	if d.has("cls"):
		return _ck_unlocked(id)
	if bool(d.get("apex", false)):
		return sk_rank(String(d["req"][0])) >= 1 and sk_rank(String(d["req"][1])) >= 1
	if int(d["n"]) == 0 and not bool(d.get("outer", false)):
		return true
	for o in sk_adj[id]:
		if bool(d["key"]):
			if bool(sk_defs[o].get("apex", false)):
				continue
			if int(sk_defs[o]["ring"]) == 3 and sk_rank(String(o)) >= 2:
				return true
		elif sk_rank(String(o)) >= 1:
			return true
	return false


func sk_can_buy(id: String) -> bool:
	return sk_rank(id) < _sk_max(id) and sk_unlocked(id) and skill_pts >= sk_cost(id)


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
	return (2.5 if has_tr("deadly") else 2.0) + sk("critmult") / 100.0


func _phoenix() -> bool:
	if _recall():
		return true
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
	return maxi(1, int(round(float(o["price"]) * (1.0 - sk("haggle") / 100.0) * _hz_price())))


var sk_off := Vector2.ZERO
var sk_zoom := 0.75
var sk_press := Vector2.ZERO
var sk_drag := false
var sk_moved := false
var sk_touch: Dictionary = {}
var sk_pinch_d := 0.0
var btn_sk_ctr := Rect2(556, 214, 144, 54)
const SK_MAP_TOP := 206.0
const SK_MAP_BOT := 946.0


func _sk_to_screen(w: Vector2) -> Vector2:
	return SK_C + (w - SK_C) * sk_zoom + sk_off


func _sk_zoom_at(f: float, at: Vector2) -> void:
	var nz := clampf(sk_zoom * f, 0.5, 2.6)
	var w := SK_C + (at - SK_C - sk_off) / sk_zoom
	sk_zoom = nz
	sk_off = at - SK_C - (w - SK_C) * sk_zoom
	_sk_clamp()


func _sk_clamp() -> void:
	var lim := 700.0 * sk_zoom
	sk_off = sk_off.clamp(Vector2(-lim, -lim), Vector2(lim, lim))


# Drag to pan, pinch / wheel to zoom. Returns true when the event was used.
func _sk_gui(event: InputEvent) -> bool:
	if sk_view == 1:
		return false
	if event is InputEventScreenTouch:
		if event.pressed:
			sk_touch[event.index] = event.position
		else:
			sk_touch.erase(event.index)
		if sk_touch.size() >= 2:
			var ks := sk_touch.keys()
			sk_pinch_d = (sk_touch[ks[0]] as Vector2).distance_to(sk_touch[ks[1]])
			sk_moved = true
		return sk_touch.size() >= 2
	if event is InputEventScreenDrag:
		sk_touch[event.index] = event.position
		if sk_touch.size() >= 2:
			var ks2 := sk_touch.keys()
			var a: Vector2 = sk_touch[ks2[0]]
			var b: Vector2 = sk_touch[ks2[1]]
			var nd := a.distance_to(b)
			if sk_pinch_d > 10.0:
				_sk_zoom_at(nd / sk_pinch_d, (a + b) * 0.5)
			sk_pinch_d = nd
			sk_moved = true
			return true
		return false
	if event is InputEventMagnifyGesture:
		_sk_zoom_at(event.factor, event.position)
		return true
	if event is InputEventMouseButton:
		if event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			_sk_zoom_at(1.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1, event.position)
			return true
		if event.button_index != MOUSE_BUTTON_LEFT:
			return false
		if event.pressed:
			if event.position.y < SK_MAP_TOP or event.position.y > SK_MAP_BOT or btn_sk_ctr.has_point(event.position):
				return false
			sk_drag = true
			sk_moved = false
			sk_press = event.position
			return true
		if sk_drag:
			sk_drag = false
			if not sk_moved and sk_touch.size() < 2:
				_skill_input(sk_press)
			return true
		return false
	if event is InputEventMouseMotion and sk_drag:
		if sk_touch.size() >= 2:
			return true
		if not sk_moved and event.position.distance_to(sk_press) < 14.0:
			return true
		sk_moved = true
		sk_off += event.relative
		_sk_clamp()
		return true
	return false


func _skill_input(p: Vector2) -> void:
	if btn_sk_view.has_point(p):
		sk_view = 1 - sk_view
		sk_sel = ""
		_sfx("ui")
		return
	if sk_view == 0 and btn_sk_ctr.has_point(p):
		sk_off = Vector2.ZERO
		sk_zoom = 0.75
		_sfx("ui")
		return
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
	if p.y < SK_MAP_TOP or p.y > SK_MAP_BOT:
		return
	for id in sk_defs:
		if sk_defs[id].has("cls") != (sk_view == 1) or (sk_view == 1 and String(sk_defs[id]["cls"]) != cls):
			continue
		var spos: Vector2 = sk_defs[id]["pos"]
		var dd: float = (spos if sk_view == 1 else _sk_to_screen(spos)).distance_to(p)
		if dd < bd:
			bd = dd
			best = String(id)
	if best != "":
		sk_sel = best
		_sfx("ui")


func _draw_skills(acc: Color) -> void:
	if sk_view == 1:
		_ck_draw_map()
	else:
		_draw_skill_web()
	_draw_skills_ui(acc)


func _draw_skill_web() -> void:
	draw_set_transform(SK_C + sk_off - SK_C * sk_zoom, 0.0, Vector2(sk_zoom, sk_zoom))
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
	draw_circle(SK_C, 24.0, Color("0a0c14"))
	draw_arc(SK_C, 24.0, 0.0, TAU, 24, Color(1, 1, 1, 0.5), 2.0)
	_ctext("YOU", SK_C, 15, Color(1, 1, 1, 0.75))
	for id in sk_defs:
		var d: Dictionary = sk_defs[id]
		if d.has("cls"):
			continue
		var c: Vector2 = d["pos"]
		var col: Color = d["col"]
		var rk := sk_rank(String(id))
		var can := sk_can_buy(String(id))
		var unl := sk_unlocked(String(id))
		var apx := bool(d.get("apex", false))
		var rad := 38.0 if apx else (31.0 if bool(d["key"]) else 24.0)
		var fill := Color(col.r, col.g, col.b, 0.9 if rk >= _sk_max(String(id)) else (0.5 if rk == 1 else 0.07))
		if apx:
			draw_arc(c, rad + 4.0, 0.0, TAU, 32, Color(1, 1, 1, 0.25 + 0.15 * sin(t * 3.0)), 2.0)
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
		for k in _sk_max(String(id)):
			var pc := c + Vector2((-6.0 + 12.0 * k) if _sk_max(String(id)) == 2 else 0.0, rad + 11.0)
			draw_circle(pc, 3.5, col if rk > k else Color(1, 1, 1, 0.2))
	for b in SK_N:
		var th := deg_to_rad(SK_A0 + 60.0 * b)
		_sk_label(String(SK_BR[b][0]), SK_C + Vector2(cos(th), sin(th)) * 345.0, SK_BR[b][1])
	for g in SK_BR2.size():
		var th3 := deg_to_rad(SK_A0 + 60.0 * g + 30.0)
		_sk_label(String(SK_BR2[g][0]), SK_C + Vector2(cos(th3), sin(th3)) * 628.0, SK_BR2[g][1])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_skills_ui(acc: Color) -> void:
	# cover anything panned outside the map area
	var vw := get_viewport_rect().size
	draw_rect(Rect2(0, 0, vw.x, SK_MAP_TOP), Color("0a0c14"))
	draw_rect(Rect2(0, SK_MAP_BOT, vw.x, vw.y - SK_MAP_BOT + 400.0), Color("0a0c14"))
	draw_line(Vector2(0, SK_MAP_TOP), Vector2(vw.x, SK_MAP_TOP), Color(1, 1, 1, 0.15), 2.0)
	_txt("CLASS TREE" if sk_view == 1 else "SKILL WEB", Vector2(0, 130), T_TITLE, acc)
	var nxt := (level / 3 + 1) * 3
	_txt("POINTS %d      NEXT AT LV %d      COINS %d" % [skill_pts, nxt, coins], Vector2(0, 178), T_BODY, Color("ffd84f") if skill_pts > 0 else Color(1, 1, 1, 0.7))
	if sk_view == 0:
		_button(btn_sk_ctr, "RECENTRE", acc, 18)
	_button(btn_sk_view, "SKILL WEB" if sk_view == 1 else "CLASS TREE", acc, 18)
	# detail panel
	_obox(Rect2(30, 956, 660, 178), Color(1, 1, 1, 0.05))
	if sk_sel == "":
		_txt("Tap a node to inspect it. Diamonds at the ends are strongest.", Vector2(46, 1000), T_SMALL, C_DIM, 600.0, HORIZONTAL_ALIGNMENT_LEFT)
	else:
		var sd: Dictionary = sk_defs[sk_sel]
		var sc: Color = sd["col"]
		var srk := sk_rank(sk_sel)
		var smax := _sk_max(sk_sel)
		var kw := "   APEX" if smax == 1 else ("   KEYSTONE" if bool(sd["key"]) else "")
		_txt(String(sd["name"]) + kw + "   %d/%d" % [srk, smax], Vector2(46, 992), 26, sc, 450.0, HORIZONTAL_ALIGNMENT_LEFT)
		var warn := ""
		if srk >= smax:
			_txt("MAXED", Vector2(500, 994), 28, sc, 180.0, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			_button(btn_sk_buy, ("UPGRADE  (%d pt)" % sk_cost(sk_sel)) if sk_can_buy(sk_sel) else "LOCKED", sc if sk_can_buy(sk_sel) else Color(1, 1, 1, 0.35), 19)
			if not sk_unlocked(sk_sel):
				warn = "Needs both neighbouring keystones" if smax == 1 else ("Needs a connected node first" if not bool(sd["key"]) else "Needs an outer node at rank 2")
				if sd.has("cls"):
					warn = _ck_lock_reason(sk_sel)
			elif skill_pts < sk_cost(sk_sel):
				warn = "Not enough skill points"
		var ry := 1022.0
		if warn != "":
			_txt(warn, Vector2(46, 1016), 16, Color("ff9a8a"), 450.0, HORIZONTAL_ALIGNMENT_LEFT)
			ry = 1044.0
		for rk2 in range(1, smax + 1):
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
		# b98 new scout gear (art/chars/gear/<id>_scout.png)
		{"id": "minerlamp", "slot": "helmet", "name": "Miner Lamp", "tier": 1, "price": 13, "stats": {"sight": 2}},
		{"id": "beacon", "slot": "helmet", "name": "Beacon Helm", "tier": 1, "price": 14, "stats": {"sight": 1, "air": 10}},
		{"id": "medhelm", "slot": "helmet", "name": "Medic Helm", "tier": 2, "price": 32, "stats": {"hp": 6, "killheal": 1}},
		{"id": "drillcap", "slot": "helmet", "name": "Drill Cap", "tier": 2, "price": 34, "stats": {"armor": 1, "atk": 1}},
		{"id": "smugglerhood", "slot": "helmet", "name": "Smuggler Hood", "tier": 2, "price": 33, "stats": {"coin": 1, "dodge": 5}},
		{"id": "frosthelm", "slot": "helmet", "name": "Frost Helm", "tier": 3, "price": 56, "stats": {"armor": 2, "hazres": 25}},
		{"id": "divehelm", "slot": "helmet", "name": "Dive Helm", "tier": 3, "price": 58, "stats": {"air": 30, "armor": 1}},
		{"id": "bughelm", "slot": "helmet", "name": "Bug Helm", "tier": 3, "price": 55, "stats": {"sight": 2, "crit": 8}},
		{"id": "nebulahelm", "slot": "helmet", "name": "Nebula Helm", "tier": 4, "price": 90, "stats": {"sight": 2, "xp": 25, "dodge": 8}},
		{"id": "kingcrown", "slot": "helmet", "name": "King's Helm", "tier": 4, "price": 92, "stats": {"armor": 3, "coin": 2, "xp": 20}},
		{"id": "minerrig", "slot": "armour", "name": "Miner Rig", "tier": 1, "price": 16, "stats": {"armor": 1, "air": 10}},
		{"id": "cargoharness", "slot": "armour", "name": "Cargo Harness", "tier": 1, "price": 15, "stats": {"coin": 1, "hp": 4}},
		{"id": "flakvest", "slot": "armour", "name": "Flak Vest", "tier": 2, "price": 35, "stats": {"armor": 2, "rangedef": 1}},
		{"id": "medcoat", "slot": "armour", "name": "Medic Coat", "tier": 2, "price": 34, "stats": {"hp": 10, "killheal": 1}},
		{"id": "chainmail", "slot": "armour", "name": "Chain Shirt", "tier": 2, "price": 36, "stats": {"armor": 2, "hp": 4}},
		{"id": "frostplate", "slot": "armour", "name": "Frost Plate", "tier": 3, "price": 62, "stats": {"armor": 3, "hazres": 25, "hp": 6}},
		{"id": "solarweave", "slot": "armour", "name": "Solar Weave", "tier": 3, "price": 60, "stats": {"shield": 8, "hp": 8}},
		{"id": "bugshell", "slot": "armour", "name": "Bug Shell", "tier": 3, "price": 58, "stats": {"armor": 2, "dodge": 8, "thorns": 2}},
		{"id": "voidcarapace", "slot": "armour", "name": "Void Carapace", "tier": 4, "price": 94, "stats": {"armor": 4, "dodge": 8, "thorns": 3}},
		{"id": "royalplate", "slot": "armour", "name": "Royal Plate", "tier": 4, "price": 96, "stats": {"armor": 5, "hp": 12, "coin": 2}},
		{"id": "minerboots", "slot": "boots", "name": "Miner Boots", "tier": 1, "price": 15, "stats": {"armor": 1, "airsave": 4}},
		{"id": "medboots", "slot": "boots", "name": "Medic Boots", "tier": 2, "price": 33, "stats": {"airsave": 10, "hp": 4}},
		{"id": "springers", "slot": "boots", "name": "Spring Boots", "tier": 2, "price": 35, "stats": {"dodge": 8, "airsave": 8}},
		{"id": "smugglerboots", "slot": "boots", "name": "Smuggler Boots", "tier": 2, "price": 34, "stats": {"dodge": 6, "coin": 1}},
		{"id": "diveboots", "slot": "boots", "name": "Dive Boots", "tier": 2, "price": 34, "stats": {"armor": 1, "hazres": 30}},
		{"id": "frostboots", "slot": "boots", "name": "Frost Boots", "tier": 3, "price": 57, "stats": {"airsave": 18, "hazres": 25}},
		{"id": "solarboots", "slot": "boots", "name": "Solar Boots", "tier": 3, "price": 58, "stats": {"airsave": 20, "shield": 4}},
		{"id": "bugboots", "slot": "boots", "name": "Bug Boots", "tier": 3, "price": 56, "stats": {"dodge": 10, "airsave": 12}},
		{"id": "voidstriders", "slot": "boots", "name": "Void Striders", "tier": 4, "price": 90, "stats": {"airsave": 28, "dodge": 12}},
		{"id": "royalboots", "slot": "boots", "name": "Royal Boots", "tier": 4, "price": 92, "stats": {"airsave": 26, "armor": 2, "coin": 1}},
		{"id": "ammorecycler", "slot": "trinket", "name": "Ammo Recycler", "tier": 3, "price": 58, "stats": {"noammo": 15}},
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
		{"id": "riftblade", "slot": "weapon", "name": "Rift Blade", "tier": 6, "price": 220, "art": "oblivion", "stats": {"atk": 17, "crit": 30, "leech": 4}},
		{"id": "titanbreaker", "slot": "weapon", "name": "Titan Breaker", "tier": 6, "price": 218, "art": "starmaul", "stats": {"atk": 21, "crit": 12}},
		{"id": "singlance", "slot": "weapon", "name": "Singularity Lance", "tier": 6, "price": 226, "art": "eventrail", "stats": {"atk": 16, "range": 6, "crit": 30}},
		{"id": "abysscrown", "slot": "helmet", "name": "Abyssal Crown", "tier": 6, "price": 214, "art": "eclipsecrown", "stats": {"armor": 4, "hp": 14, "sight": 2, "xp": 45}},
		{"id": "riftplate", "slot": "armour", "name": "Rift Plate", "tier": 6, "price": 230, "art": "horizonplate", "stats": {"armor": 9, "hp": 30, "shield": 14, "thorns": 5}},
		{"id": "nullweave", "slot": "armour", "name": "Null Weave", "tier": 6, "price": 220, "art": "starweave", "stats": {"armor": 6, "hp": 18, "dodge": 18, "shield": 10}},
		{"id": "riftstriders", "slot": "boots", "name": "Rift Striders", "tier": 6, "price": 216, "art": "wormhole", "stats": {"airsave": 50, "dodge": 18, "sight": 1, "hazres": 40}},
		{"id": "abyssheart", "slot": "trinket", "name": "Abyssal Heart", "tier": 6, "price": 222, "art": "voidheart", "stats": {"hp": 34, "killheal": 8, "atk": 3}},
		{"id": "omnilens", "slot": "trinket", "name": "Omni Lens", "tier": 6, "price": 218, "art": "infinitylens", "stats": {"crit": 26, "xp": 50, "rangeb": 1}},
		{"id": "starkiller", "slot": "weapon", "name": "Starkiller", "tier": 7, "price": 300, "art": "oblivion", "stats": {"atk": 23, "crit": 35, "leech": 5}},
		{"id": "worldender", "slot": "weapon", "name": "World Ender", "tier": 7, "price": 306, "art": "eventrail", "stats": {"atk": 21, "range": 7, "crit": 35}},
		{"id": "corecrown", "slot": "helmet", "name": "Crown of the Core", "tier": 7, "price": 296, "art": "eclipsecrown", "stats": {"armor": 6, "hp": 20, "sight": 3, "xp": 60}},
		{"id": "coreplate", "slot": "armour", "name": "Core Plate", "tier": 7, "price": 310, "art": "horizonplate", "stats": {"armor": 12, "hp": 42, "shield": 18, "thorns": 7}},
		{"id": "voidwalkers", "slot": "boots", "name": "Void Walkers", "tier": 7, "price": 298, "art": "wormhole", "stats": {"airsave": 60, "dodge": 22, "sight": 2, "hazres": 60}},
		{"id": "coreheart", "slot": "trinket", "name": "Heart of the Core", "tier": 7, "price": 304, "art": "voidheart", "stats": {"hp": 44, "killheal": 10, "atk": 4, "coin": 4}},
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
	if t >= 7:
		return Color("7ffcff")
	if t >= 6:
		return Color("ff4fd8")
	if t >= 5:
		return Color("ff6a4f")
	if t >= 4:
		return Color("ffd84f")
	if t == 3:
		return Color("d58cff")
	if t == 2:
		return Color("6fd8ff")
	return Color.WHITE


func _gear_desc(d: Dictionary, gid := "") -> String:
	var labels := {
		"atk": "+%d attack", "crit": "%d%% crit chance", "leech": "heal %d per hit", "armor": "+%d armour", "hp": "+%d max HP",
		"shield": "+%d start shield", "air": "+%d max air", "airsave": "%d%% less air per step", "sight": "+%d sight",
		"xp": "+%d%% XP", "coin": "+%d per coin", "dodge": "%d%% dodge", "thorns": "%d thorns damage", "killheal": "heal %d on kill",
		"pod": "+%d air per pod", "range": "shoots %d tiles in a line", "rangeb": "+%d range for ranged weapons", "noammo": "%d%% chance not to consume ammo", "rangedef": "-%d damage from enemy shots", "hazres": "%d%% less hazard damage",
	}
	var parts: Array[String] = []
	var st: Dictionary = gstats(gid) if gid != "" else d["stats"]
	for k in st:
		parts.append(String(labels.get(k, "+%d " + String(k))) % int(st[k]))
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
	if randf() * 100.0 < sk("master"):
		tier += 1
	if floor_n >= 19 and r > 0.55:
		tier += 1
	if floor_n >= 26 and r > 0.85:
		tier += 1
	tier = clampi(tier + bonus, 1, 7 if floor_n >= 26 else (6 if floor_n >= 19 else (5 if floor_n >= 13 else 4)))
	var pool: Array = []
	var guns_ok := ul(1) or cls == "gunslinger"
	for d in gear_list:
		if int(d["tier"]) == tier and (guns_ok or String(d["slot"]) != "ranged"):
			pool.append(d)
	if pool.is_empty():
		pool = gear_list
	var idx := (rng.randi() if rng != null else randi()) % pool.size()
	var gd: Dictionary = pool[idx]
	var rid := String(gd["id"])
	if not ul(3) and (String(gd["slot"]) == "weapon" or String(gd["slot"]) == "ranged"):
		pass
	elif String(gd["slot"]) == "weapon" or String(gd["slot"]) == "ranged":
		rid += _roll_traits(rng, int(gd["tier"]), int((gd["stats"] as Dictionary).get("range", 0)) > 0)
	else:
		rid += _roll_mods(rng, int(gd["tier"]), String(gd["slot"]))
	return _roll_base(rid, rng)


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
	if not tutorial and (not equip.has(slot) or String(equip[slot]) == ""):
		var oh := hp_cap()
		var oo := oxy_max
		equip[slot] = id
		_adv_apply_change(oh, oo)
		run_gear += 1
		return true
	if bag.size() >= BAG_MAX:
		return false
	bag.append(id)
	run_gear += 1
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
	if sk("supply") > 0.0 and not sup_done.has(c):
		sup_done[c] = true
		for sk_i in int(sk("supply")):
			_give_use(_random_use())
		_pop(c, "SUPPLIES", Color("4fd1c5"))
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
	if mini_msg != "":
		mini_msg = ""
		_sfx("ui")
		return
	if btn_tleave.has_point(p):
		state = PLAY
		_sfx("ui")
		return
	if btn_mini.has_point(p):
		if puz_used.has(trade_cell):
			_sfx("blocked")
			return
		puz_used[trade_cell] = true
		_sfx("big")
		_mini_start(tidx())
		return
	var offers: Array = merchants.get(trade_cell, [])
	if btn_reroll.has_point(p):
		_trade_reroll()
		return
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


func _wall_adj(c: Vector2i) -> bool:
	for wd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not _aopen(c + wd):
			return true
	return false


func _reroll_cost() -> int:
	var offers: Array = merchants.get(trade_cell, [])
	if offers.is_empty():
		return 0
	var n := int(offers[0].get("rr", 0))
	if n == 0 and gm("gamblerchip"):
		return 0
	return 6 + 5 * n + floor_n


func _trade_reroll() -> void:
	var offers: Array = merchants.get(trade_cell, [])
	if offers.is_empty():
		return
	var n := int(offers[0].get("rr", 0))
	var cost := _reroll_cost()
	if coins < cost:
		_sfx("blocked")
		return
	coins -= cost
	var bonus := 1 if (n == 0 and gm("gamblerchip")) else 0
	var fresh: Array = []
	for k in 3:
		var gid := _adv_roll_gear(null, bonus)
		fresh.append({"kind": "gear", "id": gid, "price": maxi(5, gprice(gid)), "sold": false})
	var tid := _rand_tool()
	fresh.append({"kind": "tool", "id": tid, "price": maxi(3, 6 + floor_n / 5 + (4 if tid == "nano" or tid == "plate" else 0)), "sold": false})
	fresh[0]["rr"] = n + 1
	merchants[trade_cell] = fresh
	_sfx("big")


func _draw_trade(acc: Color) -> void:
	if trade_med:
		_draw_med_menu(acc)
		return
	_txt("OUTFITTER", Vector2(0, 220), T_TITLE, C_GOLD)
	_txt("Your coins: %d      Pack: %d / %d" % [coins, bag.size(), BAG_MAX], Vector2(0, 270), 26, Color.WHITE)
	var offers: Array = merchants.get(trade_cell, [])
	for i in offers.size():
		var o: Dictionary = offers[i]
		var rr := _trade_rect(i)
		var sold := bool(o["sold"])
		var can := coins >= _eff_price(o) and not sold
		var col := Color("6dff9a") if can else Color(1, 1, 1, 0.4)
		_obox(rr, Color(col.r, col.g, col.b, 0.1))
		_aline(rr, col, 2.0)
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
			_para_fit(_gear_desc(gd, String(o["id"])), Vector2(rr.position.x + 108, rr.position.y + dy), T_SMALL, C_TEXT, 340.0, 3)
		else:
			var uid := String(o["id"])
			_use_icon(uid, Vector2(rr.position.x + 56, rr.position.y + 67), 70)
			_txt(_use_name(uid), Vector2(rr.position.x + 110, rr.position.y + 50), 30, Color.WHITE, 340.0, HORIZONTAL_ALIGNMENT_LEFT)
			_para_fit(_atext("tool_" + uid, String(use_defs[uid]["desc"])), Vector2(rr.position.x + 110, rr.position.y + 84), T_SMALL, C_DIM, 340.0, 3)
		_txt("SOLD" if sold else "%d coins" % _eff_price(o), Vector2(rr.end.x - 170, rr.position.y + 76), 28, col, 150.0, HORIZONTAL_ALIGNMENT_RIGHT)
	var rcost := _reroll_cost()
	_button(btn_reroll, "REROLL  (FREE)" if rcost == 0 else "REROLL  %d coins" % rcost, Color("ffc93c") if coins >= rcost else Color(1, 1, 1, 0.4), 26)
	var pused := puz_used.has(trade_cell)
	_button(btn_mini, "PUZZLE  (USED)" if pused else "PUZZLE", Color(1, 1, 1, 0.4) if pused else Color("9fb3d9"), 28)
	_txt("Try a puzzle to get some extra coin.", Vector2(0, btn_mini.end.y + 32), 22, Color(1, 1, 1, 0.75))
	_button(btn_tleave, "LEAVE", acc, 28)
	if mini_msg != "":
		draw_rect(Rect2(0, 0, 720, 1400), Color(0, 0, 0, 0.6))
		var mr3 := Rect2(80, 480, 560, 240)
		_panel(mr3, Color("ffc93c"), 0.2, false)
		var my3 := mr3.position.y + 80.0
		for ml in mini_msg.split("\n"):
			_txt(ml, Vector2(mr3.position.x, my3), 30, Color("ffc93c") if my3 > mr3.position.y + 100.0 else Color.WHITE, mr3.size.x)
			my3 += 52.0
		_txt("Tap to continue", Vector2(mr3.position.x, mr3.end.y - 24), 20, Color(1, 1, 1, 0.6), mr3.size.x)


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
		"level": level, "xp": xp, "hp_max": hp_max, "hp": hp, "armor": armor, "sh": sh,
		"equip": equip.duplicate(), "bag": bag.duplicate(), "merchants": merchants.duplicate(true), "affix": affix.duplicate(), "skills": skills.duplicate(), "skill_pts": skill_pts, "ammo": ammo, "pk": pk.duplicate(), "run_kills": run_kills,
	}


func _adv_new_floor() -> void:
	cell = AC
	period = 100000
	maxd = 0
	fmod = "standard"
	adv_seed = randi()
	puz_used.clear()
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
	hp = int(saved.get("hp", 0))
	_adv_begin()


func _adv_init_run() -> void:
	adv_fresh = true
	tool_uses = 0
	fab_steps = 0
	scrap = 0
	arena = false
	arena_d = {}
	skills.clear()
	skill_pts = up("sp")
	pk = {}
	sk_sel = ""
	sk_phx = false
	air_bonus = 0.0
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
	ranged_mode = (cls == "gunslinger")
	for i in up("kit"):
		var kid := _adv_roll_gear(null, -1)
		if not equip.has(String(gear_defs[gb(kid)]["slot"])):
			equip[String(gear_defs[gb(kid)]["slot"])] = kid
		else:
			bag.append(kid)
	if not equip.has("weapon"):
		equip["weapon"] = "wrench"
	_nr_init_run()
	_mx_init_run()


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
	elif id == "nr_crown":
		_adv_level_up(5)
	elif id == "nr_lung2":
		nr_lung2_v = 30.0
	elif id == "nr_thin" or id == "nr_fragile":
		oxy_max = adv_oxy_max()
		oxy = minf(oxy, oxy_max)
		hp = mini(hp, hp_cap())


func _adv_scaled(raw: int) -> int:
	var r := raw + int(round(0.7 * float(level - START_LEVEL)))
	if raw >= 2:
		r += floor_n - 1
	else:
		r += (floor_n - 1) / 2
	r += relic_n("greedy") + relic_n("agreedy")
	return maxi(1, r)


func _adv_begin() -> void:
	joy_on = false
	joy_dir = Vector2i.ZERO
	swipe_on = false
	if adv_fresh or hp <= 0:
		hp = hp_cap()
	adv_fresh = false
	hp = mini(hp, hp_cap())
	root_n = 0
	anchor_used = false
	abl_used = false
	ld_used = false
	stim_used = false
	adr_used = false
	echoc_used = false
	_cx_scan()
	_an_announce()
	sh = maxi(sh, (8 if start_shield() else 0) + int(gear("shield")))
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
	_st_floor_reset()
	rw_hist.clear()
	oxy_max = adv_oxy_max()
	oxy = oxy_max + (10.0 if gm("deepres") else 0.0)
	adv_seen.fill(0)
	p_burn = 0
	p_acid = 0
	p_frost = 0
	fr_uses = 0
	sup_done.clear()
	warp_bc = Vector2i(-1, -1)
	warp_home = pos
	warp_rc = false
	can_n = 2
	if gm("seerhalo") and not arena:
		adv_seen.fill(1)
	if gm("explorer") and not arena:
		for ey in range(-1, 2):
			for ex in range(-1, 2):
				var ec: Vector2i = stairs + Vector2i(ex, ey)
				if _ain(ec):
					adv_seen[_ai(ec)] = 1
	cam = Vector2(pos)
	_adv_update_vis()
	state = PLAY
	if arena:
		cam = Vector2(6, 6)
		msg = "BOSS ARENA: the %s. %s" % [_boss_name(), _arena_hint()]
	elif boss_floor:
		msg = "BOSS FLOOR: the %s guards the exit" % _boss_name()
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
	_nr_begin()
	_ev_begin()


func _adv_next() -> void:
	if relic_n("medic") > 0 and sh > 0 and hp < hp_cap():
		var mh := maxi(1, sh / 2)
		hp = mini(hp_cap(), hp + mh)
		_pop(pos, "+%d HP" % mh, Color("6dff9a"))
	if not arena and floor_n % 3 == 0:
		arena = true
	else:
		arena = false
		floor_n += 1
		sw_used = false
	_adv_new_floor()
	if gcoin_buff() >= 0:
		msg = "Gambler's Coin: " + ["+10% crit", "+10% dodge", "+1 coin value"][gcoin_buff()] + " this floor"
	for qi in int(sk("quarter")):
		_give_use(_random_use())
	if set_on("crew", 3):
		coins += 2
	for bi in int(sk("beacon")) - inv.count("beacon"):
		_give_use("beacon")


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
		if _mon_seen(c):
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
	if streak_n > 0 and run_steps - streak_step <= 2:
		streak_n += 1
	else:
		streak_n = 1
	streak_step = run_steps
	if streak_n >= 2:
		streak_txt = String(["DOUBLE!", "TRIPLE!", "QUAD!", "RAMPAGE!"][mini(streak_n - 2, 3)])
		if streak_n > 5:
			streak_txt = "RAMPAGE x%d!" % streak_n
		streak_t = t
		_sfx("big", 1.0 + 0.12 * float(mini(streak_n - 2, 5)))
	_nr_kill_pre(nc)
	_mx_kill(nc, is_boss)
	var back := 0
	if thief_held.has(nc):
		back = int(thief_held[nc]) + _repo_bonus()
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
	mom_steps += int(sk("momentum")) + (2 if gm("sprinter") else 0)
	if gm("vampmesh"):
		_p_heal(2)
	if sk("airkill") > 0.0:
		air_bonus += sk("airkill")
		oxy_max = adv_oxy_max()
		oxy = minf(oxy_max, oxy + sk("airkill"))
	if relic_n("scrubber") > 0 and oxy < oxy_max * 0.5:
		oxy = minf(oxy_max, oxy + 3.0)
		_pop(pos, "+3 AIR", Color("7fd8ff"))
	if relic_n("smagnet") > 0 and (was_elite or is_boss):
		scrap += 2
		_pop(nc, "+2 SCRAP", Color("c9a36b"))
	var mult := 1.0 + 0.5 * relic_n("blade")
	mult += _an_xp()
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
	mult += 0.25 * relic_n("nr_hunger")
	if randf() * 100.0 < sk("lucky"):
		mult += 1.0
		_pop(nc, "LUCKY!", Color("ffd84f"))
	var unseen := _st_on_kill(nc)
	if unseen:
		mult += 0.5 + sk("st_xp") / 100.0
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
	var kh := int(gear("killheal")) + (maxi(1, int(float(hp_cap()) * sk("kheal") / 100.0)) if sk("kheal") > 0.0 else 0) + int(float(hp_cap()) * sk("crimson") / 100.0)
	if kh > 0:
		_p_heal(kh)
	if was_elite or is_boss or was_affix:
		if randf() < (1.0 if (is_boss or bounty_hit) else ((0.3 if was_elite else 0.12) + sk("drop") / 100.0 + (1.0 if was_elite and _an("hunt") else 0.0))):
			var gid := _adv_roll_gear(null, 1 if is_boss else 0)
			if _adv_give_gear(gid):
				msg += "  Dropped: " + gname(gid) + (" [" + gtrait_line(gid) + "]" if gtrait_line(gid) != "" else "")
	if is_boss:
		coins += 10
		var it := _random_use()
		if _give_use(it):
			msg += "  +10 coins + " + _use_name(it)
		else:
			msg += "  +10 coins"
	_nr_kill(nc, was_elite, is_boss, was_affix)
	_sfx("elite" if (was_elite or is_boss) else "win")


# returns 0 = you died, 1 = monster defeated, 2 = fight goes on
func _adv_fight(nc: Vector2i) -> int:
	if _turned(nc):
		msg = "Your hijacked %s holds its ground" % _adv_mname(nc)
		_pop(nc, "ALLY", Color("6dff9a"))
		return 2
	_cloak_break()
	var hks := int(sk("thack"))
	if tur.has(nc) and hks > 0 and int(tur[nc].get("hk", 0)) <= 0:
		tur[nc]["hk"] = hks
		_pop(nc, "HACKED", Color("4fd1c5"))
		_fx_ring(Vector2(nc), Color("4fd1c5"), 1.2, 0.4, 5.0)
		msg = "Turret hacked! It fights for you for the rest of the floor" if hks > 9999 else "Turret hacked! It fights for you for %d steps" % hks
		_sfx("shield")
		return 2
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
	var dmg := _nr_dmg(nc, _tr_hit_mod(nc, p_atk()), false)
	if gm("huntereye") and mon_hp_now(nc) >= mon_hp_max(nc):
		dmg += 2
	if gm("charger") and chg_n >= 2:
		dmg = int(round(float(dmg) * 1.15))
		_pop(nc, "CHARGE", Color("ffd27a"))
	chg_n = 0
	var crit := randf() * 100.0 < crit_chance()
	if crit:
		dmg = int(round(float(dmg) * ((1.0 + (crit_mult() - 1.0) * 0.5) if sneak_slp else crit_mult())))
	sneak_slp = false
	var missed := String(affix.get(nc, "")) == "evasive" and randf() < 0.2
	if missed:
		dmg = 0
		_pop(nc, "MISS", Color("9fe8ff"))
	else:
		_pop(nc, ("CRIT -%d" % dmg) if crit else ("-%d" % dmg), Color("ffd84f") if crit else Color.WHITE)
		_fx_hit(nc, crit)
		_run_hit(dmg)
	var left := mon_hp_now(nc) - dmg
	if not missed:
		var lk := int(gear("leech") + sk("leech"))
		if lk > 0 and hp < hp_cap():
			_p_heal(lk)
		left = _tr_on_hit(nc, dmg, crit, false, left)
		left -= _nr_ghost(nc, dmg)
	if left <= 0 and mons.has(nc):
		_adv_kill(nc, nm, lv, is_boss)
		return 1
	if not mons.has(nc):
		return 1
	mon_hp[nc] = left
	if not missed and _nr_after_hit(nc):
		return 2
	msg = ("%s dodges!" % nm) if missed else ("You hit %s for %d (%d/%d HP)" % [nm, dmg, left, mon_hp_max(nc)])
	_sfx("step")
	mon_lunge[nc] = [t + 0.12, Vector2(pos - nc).normalized()]
	if tur.has(nc):
		_sfx("spike")
		return 2
	if not missed and String(affix.get(nc, "")) == "spiny":
		if not _adv_env_hurt(1 + floor_n / 4, "Spiny! You lose %d health", "You were skewered by a spiny enemy"):
			return 0
	if st_hit_c == nc:
		_st_after_hit(nc)
		msg += "  (caught off guard)"
		return 2
	if amark.has(nc):
		msg += "  (marked: it can't strike back)"
		return 2
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
			_nr_swap()
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
	elif root_n > 0 and nc != pos:
		root_n -= 1
		moved = false
		walk.clear()
		snd = ""
		_pop(pos, ("ROOTED %d" % root_n) if root_n > 0 else "FREE!", Color("c07cff"))
		msg = ("Rooted! Keep pressing move to break free (%d left)" % root_n) if root_n > 0 else "You break free"
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
			_nr_vault()
			for vk in int(sk("vault")):
				var vx := _random_use()
				if _give_use(vx):
					msg += " + " + _use_name(vx)
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
		if kind.begins_with("bs_"):
			items[nc] = kind
			snd = ""
			call_deferred("_bs_open", kind)
		elif kind.begins_with("ev_"):
			_ev_touch(nc, kind)
			snd = ""
		elif kind.begins_with("use_"):
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
			_nr_key()
			snd = "coin"
		elif kind == "pod":
			if oxy >= oxy_max:
				items[nc] = kind
				msg = "Air is full - the pod stays for later"
			else:
				var amt := adv_pod_amt()
				oxy = minf(oxy_max, oxy + amt)
				msg = "Air pod! +%d air" % int(amt)
				if set_on("hazmat", 3):
					_tr_heal(3)
				_pop(nc, "+%d AIR" % int(amt), Color("7fd8ff"))
				snd = "lamp"
		elif kind == "hp" and sk("crimson") > 0.0:
			items[nc] = kind
			msg = "Crimson Engine: medkits don't work for you"
		elif kind == "hp":
			if hp >= hp_cap():
				items[nc] = kind
				msg = "Health is full - the medkit stays for later"
			else:
				var heal := int(hp_cap() * 0.4 * (1.0 + (sk("medk") + gear("medk")) / 100.0))
				_p_heal(heal)
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
			_p_heal(4)
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
				msg = "Found %s! %s" % [gd["name"], _gear_desc(gd, gid2)]
				for tid2 in gtr(gid2):
					msg += "   %s: %s" % [TRAIT_DEFS[tid2]["n"], TRAIT_DEFS[tid2]["d"]]
				for mid2 in gmods(gid2):
					msg += "   %s: %s" % [MOD_DEFS[mid2]["n"], MOD_DEFS[mid2]["d"]]
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
			var pxp := maxi(2, int(round(xp_need() * 0.12 * pot_g() * (1.0 + sk("pot") / 100.0))))
			adv_pts += 2
			msg = "%s! +%d XP" % [th["pot"], pxp]
			_pop(nc, "+%d XP" % pxp, Color("ffd84f"))
			_adv_gain_xp(pxp)
			snd = "pot"
		elif kind == "big":
			var bxp := maxi(3, int(round(xp_need() * 0.15 * big_g() * (1.0 + sk("pot") / 100.0))))
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
			scan_r = 5 + lamp_amt() / 4 + (2 if gm("headlamp") else 0)
			scan_steps = 16 + (8 if gm("headlamp") else 0)
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
		var cv := coin_val() * _an_coin()
		if lucky_n > 0:
			lucky_n -= 1
			cv *= 2
		coins += cv
		adv_pts += 1
		msg = "Coin! %d total" % coins
		_ck_coin()
		_pop(nc, "+%d coin" % cv, Color("ffc93c"))
		snd = "coin"
		if sk("fab") > 0.0:
			fab_n += 1
			if fab_n >= int(sk("fab")):
				fab_n = 0
				if _give_use(_random_use()):
					msg = "Auto-Fabricator built a tool!"
				else:
					sh = mini(sh_cap(), sh + 4)
					msg = "Auto-Fabricator: slots full, +4 shield"
	if moved:
		pos = nc
		chg_n += 1
		if gm("dash") and (adv_steps + 1) % 8 == 0:
			var dn: Vector2i = nc + (nc - from_c)
			if _ain(dn) and _aopen(dn) and not mons.has(dn) and not vaults.has(dn) and not items.has(dn) and not coin_at.has(dn) and not spikes.has(dn) and not haz.has(dn) and not merchants.has(dn) and not stations.has(dn) and not meds.has(dn) and not tur.has(dn) and dn != stairs:
				pos = dn
				_pop(pos, "DASH", Color("ffd84f"))
	p_moved = moved
	p_prev = from_c
	adv_steps += 1
	run_steps += 1
	if not _p_status_tick():
		return
	if sk("drone") > 0.0 and adv_steps % (6 if sk("apx_merc") > 0.0 else 12) == 0:
		_drone_fire()
	if gm("regenweave") and adv_steps % 5 == 0 and hp < hp_cap():
		hp += 1
	if moved and gm("trail") and pick_kind == "" and randf() < 0.04:
		var tcv := coin_val()
		coins += tcv
		_pop(pos, "+%d coin" % tcv, Color("ffc93c"))
	if gm("magnet"):
		for mo in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			var mc: Vector2i = pos + mo
			if coin_at.has(mc):
				coin_at.erase(mc)
				var mcv := coin_val()
				coins += mcv
				_pop(mc, "+%d coin" % mcv, Color("ffc93c"))
	rw_hist.append([pos, hp, oxy])
	if rw_hist.size() > 9:
		rw_hist.pop_front()
	_act_tick()
	_an_step()
	_ck_step(moved)
	if relic_n("ammofab") > 0 and _weapon_range() > 0:
		fab_steps += 1
		if fab_steps >= 8:
			fab_steps = 0
			if ammo < ammo_max():
				ammo += 1
				_pop(pos, "+1 AMMO", Color("ffc24f"))
	if act_free > 0:
		act_free -= 1
		oxy -= extra
	elif moved and ((gm("skipper") and randf() < 0.1) or (gm("grapple") and _wall_adj(pos))):
		oxy -= extra
	elif mom_steps > 0:
		mom_steps -= 1
		oxy -= extra
	else:
		var base_air := 1.0 - (gear("airsave") + sk("airsave")) / 100.0
		base_air *= _hz_air()
		oxy -= base_air * (2.0 if relic_n("prism") > 0 and not moved else 1.0) + (0.5 if relic_n("glass") > 0 else 0.0) + extra
	if moved and corpses.has(pos) and relic_n("gravedigger") > 0 and not bool(corpses[pos].get("looted", false)):
		corpses[pos]["looted"] = true
		var lc := 2 * relic_n("gravedigger") * coin_val()
		coins += lc
		_pop(pos, "+%d loot" % lc, Color("ffc93c"))
		snd = "coin"
	if moved and stations.has(pos):
		if sk("frepair") > 0.0 and fr_uses < 3 and sh < sh_cap():
			fr_uses += 1
			sh = mini(sh_cap(), sh + int(sk("frepair")))
			_pop(pos, "+%d SHIELD" % int(sk("frepair")), Color("7db2ff"))
		var healed := 0
		var heal_spent := false
		if sk("stationheal") > 0.0 and hp < hp_cap():
			if station_uses < STATION_USES:
				station_uses += 1
				healed = maxi(1, int(hp_cap() * sk("stationheal") / 100.0))
				_p_heal(healed)
				_pop(pos, "+%d HP" % healed, Color("ff8a9a"))
			else:
				heal_spent = true
		var o2_left := _o2_left(pos)
		if oxy < oxy_max - 0.5 and o2_left <= 0:
			msg = "O2 station depleted - find another one"
			_pop(pos, "DEPLETED", Color("8a93a8"))
		elif oxy < oxy_max - 0.5:
			o2_used[pos] = int(o2_used.get(pos, 0)) + 1
			msg = "O2 station: air fully restored (%d uses left)" % (o2_left - 1)
			_pop(pos, "AIR FULL", Color("7fd8ff"))
			snd = "lamp"
		if healed > 0:
			msg = ("O2 station: air restored, +%d HP" if oxy < oxy_max - 0.5 else "Recycler: +%d HP") % healed
			msg += " (%d heals left on this floor)" % (STATION_USES - station_uses)
			snd = "lamp"
		elif heal_spent:
			msg += "   Recycler is spent: %d heals per floor" % STATION_USES
		if o2_left > 0:
			oxy = oxy_max
	if scan_steps > 0:
		scan_steps -= 1
	if decoy_steps > 0:
		decoy_steps -= 1
	if oil_steps > 0:
		oil_steps -= 1
	_st_tick()
	_adv_update_vis()
	if spike_dmg > 0 and not _adv_spike_hurt(spike_dmg):
		return
	if _world_rule() == "supply" and adv_steps > 0 and adv_steps % 40 == 0:
		_supply_drop()
	if _world_rule() == "outage":
		if adv_steps > 0 and adv_steps % 25 == 0:
			_pop(pos, "BLACKOUT", Color("ff9a5b"))
			msg = "Blackout! The lights are out and Hunters move fast"
		elif adv_steps % 25 >= 22:
			_pop(pos, "LIGHTS FLICKER", Color("ff9a5b"))
	if _world_rule() == "glare":
		if crk_f != floor_n:
			cracked.clear()
			crk_f = floor_n
		if moved:
			if cracked.has(pos):
				_pop(pos, "CRACK", Color("e6c8ff"))
				if not _adv_env_hurt(3, "The glass gives way! You lose %d health", "You fell through the cracked glass", "spike"):
					return
			cracked[pos] = true
		var sl := 20 - adv_steps % 20
		if sl <= 3 and sl > 0 and adv_steps % 20 != 0:
			_pop(pos, "SHATTER IN %d" % sl, Color("e6c8ff"))
		if adv_steps % 20 == 0:
			_fx_ring(Vector2(pos), Color("e6c8ff"), 2.4, 0.6, 6.0)
			if _by_wall(pos):
				_pop(pos, "SHELTERED", Color("e6c8ff"))
			elif not _adv_env_hurt(4 + floor_n / 3, "Crystals shatter! You lose %d health", "You were shredded by crystal shards", "spike"):
				return
	if _world_rule() == "spore" and adv_steps % 30 == 0:
		poison_n = maxi(poison_n, 3)
		poison_d = maxi(poison_d, 1)
		msg = "Spore burst! You are poisoned for a few steps"
		_pop(pos, "SPORES", Color("b6ff6a"))
	if poison_n > 0:
		poison_n -= 1
		if not _adv_env_hurt(maxi(1, poison_d / (2 if gm("toxfilter") else 1)), "Poison! You lose %d health", "You succumbed to poison", "poison"):
			return
	if moved and haz_hit != "":
		if not _adv_haz_trigger(haz_hit, nc, nc - from_c):
			return
	_nr_step(moved, fought)
	if _oxy_dead():
		return
	if moved and pos == stairs and not mons.has(stairs):
		if adv_pts >= adv_req and (not arena or not mons.has(boss_cell)):
			joy_on = false
			joy_dir = Vector2i.ZERO
			swipe_on = false
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
	if nr_m.has(a):
		nr_m[b] = nr_m[a]
		nr_m.erase(a)


func _cloak_break() -> void:
	if cloak_steps > 0 and mode == "adv":
		st_was_cloaked = true
		cloak_steps = 0
		_pop(pos, "REVEALED", Color("9aa3c7"))


func _adv_hunters() -> void:
	_idle_notice()
	var tgt := pos
	var dec := decoy_steps > 0
	if dec:
		tgt = decoy_c
	elif noise_steps > 0:
		tgt = noise_c
		dec = true
	elif _hidden():
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
		if not mons.has(c) or not dist.has(c) or _stunned(c) or _turned(c) or mon_idle.has(c) or amark.has(c):
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
		if adv_steps % 2 != 0 and String(kinds[c]) != "rager" and not _blackout():
			continue
		if _rooted(c):
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
	return maxi(1, w + int(gear("rangeb")) + relic_n("deadeye") + int(sk("rrange")) - (1 if _rhas("hollow") else 0))


func _haz_mult() -> float:
	return clampf(1.0 - gear("hazres") / 100.0 - (0.5 if relic_n("hazmat") > 0 else 0.0) - (0.5 if gm("shockabs") else 0.0), 0.2, 1.0)


func _ranged_dmg(c: Vector2i) -> int:
	rshot_src = c
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
		if a != pos and corpses.has(m) and relic_n("nr_hollow") > 0:
			return false
	return true


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
	return 2.0 if relic_n("prism") > 0 else 1.0


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
	if rg <= 0 or ammo <= 0 or not mons.has(c) or not _mon_seen(c):
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
	p_moved = false
	_cloak_break()
	fab_steps = 0
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
	var hfree := hair_free
	hair_free = false
	if hfree or randf() * 100.0 < sk("noammo") + gear("noammo") + (15.0 if has_tr("tireless") else 0.0):
		_pop(pos, "FREE SHOT", Color("6dff9a"))
	else:
		ammo = maxi(0, ammo - (2 if relic_n("heavyammo") > 0 else 1))
	var dmg := _nr_dmg(c, _tr_hit_mod(c, _ranged_hv()), true)
	if sk("fardmg") > 0.0 and maxi(absi(c.x - pos.x), absi(c.y - pos.y)) >= 3:
		dmg = int(round(float(dmg) * (1.0 + sk("fardmg") / 100.0)))
	if act_rico:
		dmg *= 2
	var crit := randf() * 100.0 < crit_chance()
	if crit:
		dmg = int(round(float(dmg) * ((1.0 + (crit_mult() - 1.0) * 0.5) if sneak_slp else crit_mult())))
	sneak_slp = false
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
		_run_hit(dmg)
		var lk := int(gear("leech") + sk("leech"))
		if lk > 0 and hp < hp_cap():
			_p_heal(lk)
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
		if not missed:
			_nr_after_hit(c)
	_sfx("shoot")
	var snk := st_hit_c == c
	if snk:
		_st_after_hit(c)
	_nr_shot(c, dmg)
	if act_rico and dmg > 0:
		act_rico = false
		_act_ricochet(c, dmg)
		for rb in _rico_extra():
			_act_ricochet(c, dmg, true)
	if mons.has(c) and not tur.has(c) and not is_boss and not amark.has(c):
		var kd := String(kinds.get(c, ""))
		if kd == "" or kd == "sleeper" or kd == "feeder":
			kinds[c] = "rager"
			msg += "  It charges you at full speed!"
			_sfx("aggro")
	if mons.has(c) and absi(c.x - pos.x) + absi(c.y - pos.y) == 1 and not tur.has(c) and not _turned(c) and not snk and not amark.has(c):
		mon_lunge[c] = [t + 0.12, Vector2(pos - c).normalized()]
		if not _adv_hurt(mon_atk(c), nm, c):
			return
	adv_steps += 1
	run_steps += 1
	rw_hist.append([pos, hp, oxy])
	if rw_hist.size() > 9:
		rw_hist.pop_front()
	_act_tick()
	oxy -= _shot_cost()
	_nr_step(false, true)
	if scan_steps > 0:
		scan_steps -= 1
	if decoy_steps > 0:
		decoy_steps -= 1
	if oil_steps > 0:
		oil_steps -= 1
	_st_tick()
	_adv_update_vis()
	if poison_n > 0:
		poison_n -= 1
		if not _adv_env_hurt(maxi(1, poison_d / (2 if gm("toxfilter") else 1)), "Poison! You lose %d health", "You succumbed to poison", "poison"):
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
		if not _aopen(n) or vaults.has(n) or (corpses.has(n) and relic_n("nr_hollow") > 0):
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
	if _hidden() or decoy_steps > 0:
		return
	var ss: Array[Vector2i] = []
	for c in kinds:
		if String(kinds[c]) == "shooter" and mons.has(c) and not mon_idle.has(c) and not amark.has(c):
			ss.append(c)
	if ss.is_empty():
		return
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for c in ss:
		if not mons.has(c) or _stunned(c) or _turned(c):
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
				if syn("plating", "thornmail") and mons.has(c):
					_adv_damage_mon(c, 2, Color("c9d3f0"))
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
	var ts: Array[Vector2i] = []
	for c in tur:
		if mons.has(c):
			ts.append(c)
	for c in ts:
		if not mons.has(c):
			continue
		var hk := int(tur[c].get("hk", 0))
		if hk > 0:
			tur[c]["hk"] = hk - 1
			if _tur_ready(c, adv_steps):
				_tur_friendly(c)
			continue
		if _hidden() or not _tur_ready(c, adv_steps):
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
		haz.erase(c)  # one-shot: a pad in the exit corridor must not trap the player
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
	_mx_floor_clear()
	var bonus := int(oxy / 20.0)
	coins += bonus
	over_title = "BOSS DEFEATED" if boss_floor else "FLOOR %d CLEARED" % floor_n
	var nxt := "floor %d" % (floor_n + 1)
	if not arena and floor_n % 3 == 0:
		nxt = "BOSS ARENA"
	if arena:
		over_sub = "Air bonus +%d coins\nNext: %s" % [bonus, nxt]
	else:
		over_sub = "Points %d / %d   Air bonus +%d coins\nNext: %s" % [adv_pts, adv_req, bonus, nxt]
	relic_choices = _roll_relics(1 if boss_floor else 0)
	_nr_clear()
	ad_boss = boss_floor and _mx_on() and _ads().boss_bonus_available()
	state = CLEAR


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
	if id == "sleepdart":
		return dd <= 4 and mons.has(c) and adv_vis.has(c) and _st_unaware(c) and not _idle_sleep(c) and _idle_ok(c) and not elite.has(c)
	if id == "noise":
		return dd <= 6 and _aopen(c) and not mons.has(c) and c != pos
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
			_p_heal(amt)
			poison_n = 0
			msg = "Medical station: +%d HP for %d coins" % [amt, cost]
			_pop(pos, "+%d HP" % amt, Color("6dff9a"))
			_fx_ring(vis_pos, Color("6dff9a"), 1.4, 0.6, 5.0)
			_fx_burst(vis_pos, Color("b6ffd2"), 18, 3.0, 0.9, 5.0)
			_sfx("pot")
			return


func _draw_med_menu(acc: Color) -> void:
	_txt("MEDICAL STATION", Vector2(0, 220), T_TITLE, C_GOOD)
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
		_aline(rr, col, 2.0)
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
		msg = "Shadow Cloak: monsters can't see or hear you for 16 steps, or until you attack"
		_sfx("shield")
	elif id == "patch":
		if cloak_steps >= 4:
			msg = "A cloak is already active"
			_sfx("blocked")
			return
		cloak_steps = 4
		walk.clear()
		_fx_burst(vis_pos, Color("8f9bd8"), 12, 2.2, 0.6, 5.0)
		msg = "Cloak Patch: invisible and silent for 4 steps, or until you attack"
		_sfx("shield")
	elif id == "smoke":
		smoke_c = pos
		smoke_steps = 5
		for sc in mons.keys():
			if mon_idle.has(sc) and _cheb(sc, pos) <= 3:
				mon_idle[sc]["sus"] = 0
		_fx_burst(vis_pos, Color("b8c0d0"), 30, 3.0, 1.0, 9.0)
		_fx_ring(vis_pos, Color("b8c0d0"), 2.4, 0.6, 6.0)
		msg = "Smoke Bomb: enemies can't see you inside the smoke for 5 steps"
		_sfx("shieldbreak")
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
		var rwf := pos
		_tool_spend(i)
		_sfx("warp")
		_fx_burst(vis_pos, Color("c07cff"), 16, 3.0, 0.5, 5.0)
		_adv_step(rp, true)
		if state == PLAY:
			_on_warp(rwf)
			hp = maxi(hp, int(snap[1]))
			oxy = maxf(oxy, float(snap[2]))
			rw_hist.clear()
			msg = "Rewind! Back where you were 8 steps ago"
		return
	elif id == "beacon":
		if warp_bc.x < 0:
			warp_bc = pos
			_fx_ring(vis_pos, Color("a68cff"), 1.2, 0.5, 5.0)
			msg = "Warp Beacon placed: use it again to warp back here"
			_sfx("lamp")
			return
		if mons.has(warp_bc) or warp_bc == pos:
			msg = "Can't warp to the beacon right now"
			_sfx("blocked")
			return
		var bfrom := pos
		var bdst := warp_bc
		warp_bc = Vector2i(-1, -1)
		if relic_n("uwarp") <= 0:
			_tool_spend(i)
		_sfx("warp")
		_fx_burst(vis_pos, Color("a68cff"), 16, 3.0, 0.5, 5.0)
		_adv_step(bdst, true)
		if state == PLAY:
			msg = "Warped to your beacon"
			if sk_rank("o5n0") >= 2:
				_tr_heal(maxi(1, hp_cap() / 4))
			_on_warp(bfrom)
			if relic_n("anchor") > 0 and not anchor_used:
				anchor_used = true
				_give_use(_random_use())
				_pop(pos, "+TOOL", Color("a68cff"))
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
		scan_r = 6 + lamp_amt() / 4 + (2 if gm("headlamp") else 0)
		scan_steps = 8 + (8 if gm("headlamp") else 0)
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
	_tool_spend(i)


func _adv_aim_apply(c: Vector2i) -> void:
	var id: String = inv[aim]
	if not _adv_aim_valid(id, c):
		msg = "Not a valid target"
		_sfx("blocked")
		return
	_tool_spend(aim)
	aim = -1
	if id == "sleepdart":
		_fx_bolt(vis_pos, Vector2(c), Color("c9a2ff"))
		mon_idle[c] = {"s": "sleep", "ph": 0, "sus": 0, "zz": 10}
		amark.erase(c)
		_pop(c, "ZZZ", Color("c9a2ff"))
		msg = "Sleep Dart: %s is asleep for 10 steps" % _adv_mname(c)
		_sfx("lamp")
		return
	if id == "noise":
		noise_c = c
		noise_steps = 4
		for nc2 in mon_idle.keys():
			if _cheb(nc2, c) <= 4 and mons.has(nc2) and String(mon_idle[nc2]["s"]) != "sleep":
				var dl: Vector2i = c - nc2
				mon_idle[nc2]["s"] = "look"
				mon_idle[nc2]["fd"] = (3 if dl.x > 0 else 2) if absi(dl.x) > absi(dl.y) else (0 if dl.y >= 0 else 1)
				mon_idle[nc2]["sus"] = 0
				_pop(nc2, "?", Color("ffb347"))
		_fx_ring(Vector2(c), Color("ffb347"), 1.6, 0.6, 5.0)
		_fx_ring(Vector2(c), Color("ffb347"), 2.6, 0.8, 3.0, 0.2)
		msg = "Noise Maker: heads turn towards the noise"
		_sfx("elite")
		return
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
		var gfr := pos
		_adv_step(ghit - gdv, true)
		if state == PLAY:
			_on_warp(gfr)
		return
	if id == "blink":
		_sfx("warp")
		_fx_burst(vis_pos, Color("b57cff"), 16, 3.0, 0.5, 5.0)
		_fx_ring(vis_pos, Color("b57cff"), 1.0, 0.4, 4.0)
		var bkf := pos
		_adv_step(c, true)
		if state == PLAY:
			_on_warp(bkf)
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
	if ul(2) and btn_skill.has_point(p):
		_ul_tap(2)
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
		_nr_swap()
		walk.clear()
		_sfx("ui")
		return
	if sk("breathe") > 0.0 and _breathe_rect().has_point(p):
		_breathe()
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
		_draw_mon_sprite(c, ctr, ti, base_lv, is_boss, sz, _frenzy_tint(c), _idle_sleep(c), -4.0)
	_idle_draw(c, ctr)
	if elite.has(c):
		_star(ctr + Vector2(-AC * 0.3, -AC * 0.3 + bob), AC * 0.16, Color("ffd84f"))
	if affix.has(c):
		_aff_pill(ctr + Vector2(AC * 0.48, AC * 0.1), String(affix[c]), int(AC * 0.17), true)
	if mstat.has(c):
		_draw_status_icons(c, ctr)
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


func _draw_status_icons(c: Vector2i, ctr: Vector2) -> void:
	var st: Dictionary = mstat[c]
	var ic: Array = []
	if st.has("burn"):
		ic.append(["burn", Color("ff7a45"), int((st["burn"] as Array)[0])])
	if st.has("psn"):
		ic.append(["psn", Color("8aff6a"), int((st["psn"] as Array)[0])])
	var sn := int(st.get("stun", 0))
	if sn > 0:
		ic.append(["chill" if st.has("chill") else "stun", Color("8fe8ff") if st.has("chill") else Color("ffe14f"), sn])
	if st.has("bleed"):
		ic.append(["bleed", Color("ff4d6d"), int((st["bleed"] as Array)[0])])
	if st.has("corr"):
		ic.append(["corr", Color("c07cff"), int(st["corr"])])
	if int(st.get("root", 0)) > 0:
		ic.append(["root", Color("6fcf5a"), int(st["root"])])
	if st.has("mk"):
		ic.append(["mk", Color("8fa8ff"), 0])
	if ic.is_empty():
		return
	var r := AC * 0.075
	var gap := AC * 0.2
	var x0 := ctr.x - gap * float(ic.size() - 1) * 0.5
	var y := ctr.y - AC * 0.43
	for i in ic.size():
		var p := Vector2(x0 + gap * float(i), y)
		var col: Color = ic[i][1]
		draw_circle(p, r * 1.45, Color(0.04, 0.05, 0.09, 0.88))
		draw_arc(p, r * 1.45, 0.0, TAU, 16, col, 1.5)
		match String(ic[i][0]):
			"burn":
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r * 0.8, r * 0.3), p + Vector2(0, r), p + Vector2(-r * 0.8, r * 0.3)]), col)
			"psn", "bleed":
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r * 0.6, r * 0.1), p + Vector2(-r * 0.6, r * 0.1)]), col)
				draw_circle(p + Vector2(0, r * 0.35), r * 0.6, col)
			"stun":
				draw_polyline(PackedVector2Array([p + Vector2(r * 0.3, -r), p + Vector2(-r * 0.3, r * 0.1), p + Vector2(r * 0.3, -r * 0.1), p + Vector2(-r * 0.3, r)]), col, 2.0)
			"chill":
				for k in 3:
					var a := PI * float(k) / 3.0
					var d := Vector2(cos(a), sin(a)) * r
					draw_line(p - d, p + d, col, 1.6)
			"root":
				draw_line(p + Vector2(0, -r), p + Vector2(0, r * 0.4), col, 1.8)
				draw_line(p + Vector2(0, r * 0.4), p + Vector2(-r * 0.7, r), col, 1.6)
				draw_line(p + Vector2(0, r * 0.4), p + Vector2(r * 0.7, r), col, 1.6)
			"corr":
				draw_arc(p, r * 0.7, 0.0, TAU, 12, col, 2.0)
				draw_circle(p, r * 0.25, col)
			"mk":
				draw_arc(p, r * 0.7, 0.0, TAU, 12, col, 1.6)
				draw_line(p + Vector2(-r, 0), p + Vector2(r, 0), col, 1.4)
				draw_line(p + Vector2(0, -r), p + Vector2(0, r), col, 1.4)
		var nn := int(ic[i][2])
		if nn > 1:
			_ctext(str(nn), p + Vector2(r * 1.6, r * 1.4), maxi(8, int(AC * 0.13)), col)


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
				if in_base:
					_dc_draw(c, ctr)
				var wfa := _fog_a(c, 0.6)
				if wfa > 0.01:
					draw_rect(r, Color(0, 0, 0, wfa))
				continue
			draw_texture_rect(_floor_at(ti, cx, cy), r.grow(-1.0), false)
			var dk1 := _deco_at(cx, cy)
			if dk1 >= 0:
				draw_texture_rect(spr_gen.floor_deco(ti, dk1), r.grow(-1.0), false)
			if cracked.has(c) and crk_f == floor_n:
				var cc := Color(0.9, 0.8, 1.0, 0.7)
				draw_line(ctr + Vector2(-AC * 0.35, -AC * 0.2), ctr + Vector2(AC * 0.05, AC * 0.05), cc, 2.0)
				draw_line(ctr + Vector2(AC * 0.05, AC * 0.05), ctr + Vector2(AC * 0.3, -AC * 0.3), cc, 2.0)
				draw_line(ctr + Vector2(AC * 0.05, AC * 0.05), ctr + Vector2(-AC * 0.05, AC * 0.38), cc, 2.0)
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
				var o2n := _o2_left(c)
				if o2n > 0:
					var o2p := ctr + Vector2(AC * 0.34, -AC * 0.3)
					var o2c := Color("7fd8ff") if o2n > 1 else Color("ffb347")
					draw_circle(o2p, AC * 0.17, Color("0a0c14"))
					draw_arc(o2p, AC * 0.17, 0.0, TAU, 20, o2c, 2.0)
					_ctext(str(o2n), o2p + Vector2(0, AC * 0.06), int(AC * 0.2), o2c)
				if _o2_left(c) <= 0:
					draw_circle(ctr, AC * 0.42, Color(0.05, 0.06, 0.1, 0.6))
					_ctext("EMPTY", ctr + Vector2(0, AC * 0.08), int(AC * 0.2), Color("8a93a8"))
			elif meds.has(c):
				_draw_med(ctr)
			elif merchants.has(c):
				_draw_merchant(ctr)
			elif vaults.has(c):
				_draw_vault(ctr + Vector2(0, bob * 0.3))
			elif items.has(c):
				var kind2: String = items[c]
				draw_circle(ctr + Vector2(0, AC * 0.25), AC * 0.2, Color(0, 0, 0, 0.25))
				if kind2.begins_with("bs_"):
					_bs_draw(ctr, kind2, bob)
				elif kind2.begins_with("ev_"):
					_ev_draw(ctr, kind2, bob)
				elif kind2.begins_with("use_"):
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
			if vis and mons.has(c) and _mon_seen(c):
				mlist.append([c, ctr])
			var ffa := _fog_a(c, 0.55)
			if ffa > 0.01:
				draw_rect(r, Color(0, 0, 0, ffa))
	_amb_world_draw(ti)
	_adv_draw_lanes(ti)
	_adv_draw_shoot_lanes()
	for bl in bs_lbls:
		_ctext(bl[0], bl[1], bl[2], bl[3])
	bs_lbls.clear()
	if decoy_steps > 0:
		_use_icon("decoy", _actr(decoy_c), AC * 0.5)
	if warp_bc.x >= 0 and mode == "adv":
		_use_icon("beacon", _actr(warp_bc), AC * 0.5)
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
	if sk("drone") > 0.0:
		var dpp := prc + Vector2(cos(t * 2.2) * AC * 0.5, -AC * 0.45 + sin(t * 4.4) * AC * 0.08)
		draw_circle(dpp, AC * 0.1, Color("0a0c14"))
		draw_circle(dpp, AC * 0.08, Color("4fd1c5"))
		draw_circle(dpp, AC * 0.035, Color.WHITE)
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
	if mode == "adv" and state == PLAY and oxy < oxy_max * 0.25:
		_frost_draw(Rect2(0, 318, 720, 1280.0 - 318.0), clampf(1.0 - oxy / maxf(0.01, oxy_max * 0.25), 0.15, 1.0))
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
			draw_rect(Rect2(mm.position.x + 3 + stc.x * msc - 1, mm.position.y + 3 + stc.y * msc - 1, 4, 4), Color("7fd8ff") if _o2_left(stc) > 0 else Color("5a6070"))
	for mdc in meds:
		if _aseen(mdc):
			draw_rect(Rect2(mm.position.x + 3 + mdc.x * msc - 1, mm.position.y + 3 + mdc.y * msc - 1, 4, 4), Color("6dff9a"))
	if ev_c.x >= 0 and items.has(ev_c):
		draw_rect(Rect2(mm.position.x + 3 + ev_c.x * msc - 2, mm.position.y + 3 + ev_c.y * msc - 2, 6, 6), Color("ff5dff"))
	if gm("prospect") or gm("gcompass"):
		for vcc in vaults:
			draw_rect(Rect2(mm.position.x + 3 + vcc.x * msc - 1, mm.position.y + 3 + vcc.y * msc - 1, 4, 4), Color("ffd84f"))
		for icc in items:
			if String(items[icc]) == "trapcache" or String(items[icc]).begins_with("gear_"):
				draw_rect(Rect2(mm.position.x + 3 + icc.x * msc - 1, mm.position.y + 3 + icc.y * msc - 1, 4, 4), Color("ffd84f"))
	if gm("compass"):
		var cdv := Vector2(stairs - pos)
		if cdv.length() > 0.5:
			var cpp := mm.position + Vector2(3, 3) + Vector2(pos) * msc
			draw_line(cpp, cpp + cdv.normalized() * 22.0, Color("6dff9a"), 2.0)
	draw_rect(Rect2(mm.position.x + 3 + pos.x * msc - 2, mm.position.y + 3 + pos.y * msc - 2, 5, 5), Color.WHITE)
	# B86: floor event tag, so the event on this floor is always readable
	if ev_id != "" and EV_DEFS.has(ev_id) and (items.has(ev_c) or ev_run != "") and not in_base:
		var evd: Dictionary = EV_DEFS[ev_id]
		var evc: Color = evd["col"]
		var evr := Rect2(mm.end.x + 8, mm.position.y, 330, 62)
		_panel(evr, evc, 0.16, false)
		var evt := "EVENT: " + String(evd["n"]).to_upper()
		if ev_run != "" and ev_run != "crew" and ev_end - adv_steps > 0 and ev_end - adv_steps < 500:
			evt += "  (%d steps)" % (ev_end - adv_steps)
		_txt(evt, Vector2(evr.position.x + 10, evr.position.y + 20), 17, evc, evr.size.x - 20.0, HORIZONTAL_ALIGNMENT_LEFT)
		_para_fit(String(evd["d"]), Vector2(evr.position.x + 10, evr.position.y + 38), 14, Color(1, 1, 1, 0.85), evr.size.x - 20.0, 2)
	# HUD
	_button(btn_inv, "MENU", acc)
	_cur_badges()
	if ul(2):
		_button(btn_skill, "SKILLS", Color("ffd84f") if skill_pts > 0 else acc, 19)
		_ul_dot(btn_skill, 2)
	if ul(2) and skill_pts > 0:
		draw_circle(btn_skill.position + Vector2(btn_skill.size.x - 6, 6), 13.0, Color("ff5d5d"))
		_ctext(str(skill_pts), btn_skill.position + Vector2(btn_skill.size.x - 6, 6), 16, Color.WHITE)
	_hud_panels(acc, 124.0)
	_wbox_draw()
	_sk_banner()
	_txt("LV %d" % level, Vector2(40, 205), 72, Color.WHITE, 300.0, HORIZONTAL_ALIGNMENT_LEFT)
	_txt("BANK %d" % bank, Vector2(40, 238), 22, Color("ffc93c"), 330.0, HORIZONTAL_ALIGNMENT_LEFT)
	var xpf := clampf(float(xp) / float(xp_need()), 0.0, 1.0)
	draw_rect(Rect2(40, 252, 200, 10), Color(1, 1, 1, 0.14))
	draw_rect(Rect2(40, 252, 200.0 * xpf, 10), Color("ffd84f"))
	_txt("EXP %d/%d" % [xp, xp_need()], Vector2(248, 263), 15, Color("ffd84f"), 110.0, HORIZONTAL_ALIGNMENT_LEFT)
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
	if sk("breathe") > 0.0:
		_breathe_draw()
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
			draw_rect(Rect2(8, 1186.0 + adv_ex, 704, 38), Color(0.03, 0.04, 0.08, 0.9))
			draw_rect(Rect2(8, 1186.0 + adv_ex, 704, 38), Color(acc.r, acc.g, acc.b, 0.5), false, 2.0)
		_txt(msg, Vector2(0, 1214.0 + adv_ex), 24, Color.WHITE, 720.0)
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
	return Rect2(196, 258, 328, 316)


func _chr_slot_rect(i: int) -> Rect2:
	return Rect2(40 if i < 3 else 540, 258 + (i % 3) * 108, 140, 100)


const CHR_LIST_TOP := 662.0
const INV_FILT := ["ALL", "weapon", "ranged", "helmet", "armour", "boots", "trinket"]
var btn_inv_filt := Rect2(40, 1070, 200, 40)
var btn_inv_sort := Rect2(520, 892, 160, 36)


func _inv_view() -> Array:
	var out: Array = []
	for i in bag.size():
		if inv_filter == 0 or String(gear_defs[gb(String(bag[i]))]["slot"]) == String(INV_FILT[inv_filter]):
			out.append(i)
	return out


func _inv_y(k: int) -> float:
	var vp := _inv_view().find(k)
	if vp < 0:
		return -99999.0
	return vp * 110.0 - inv_scroll


func _inv_do_sort() -> void:
	var by_tier := inv_sort == 1
	bag.sort_custom(func(a, b):
		var da: Dictionary = gear_defs[gb(String(a))]
		var db: Dictionary = gear_defs[gb(String(b))]
		var sa := CHR_SLOTS.find(String(da["slot"]))
		var sb := CHR_SLOTS.find(String(db["slot"]))
		var ta := int(da["tier"])
		var tb := int(db["tier"])
		if by_tier:
			return ta > tb if ta != tb else sa < sb
		return sa < sb if sa != sb else ta > tb)


func _cmp_line(prev: String) -> String:
	var sl := String(gear_defs[gb(prev)]["slot"])
	var cur := String(equip.get(sl, ""))
	var a: Dictionary = gstats(prev)
	var b: Dictionary = gstats(cur) if cur != "" else {}
	var keys: Array = a.keys()
	for k in b.keys():
		if not keys.has(k):
			keys.append(k)
	var parts := PackedStringArray()
	for k in keys:
		var dv := int(float(a.get(k, 0)) - float(b.get(k, 0)))
		if dv != 0:
			parts.append("%+d %s" % [dv, String(k).to_upper()])
	if cur == "":
		return "COMPARE (slot empty): " + ", ".join(parts)
	if parts.is_empty():
		return "COMPARE vs %s: same base stats" % String(gear_defs[gb(cur)]["name"])
	return "COMPARE vs %s: %s" % [String(gear_defs[gb(cur)]["name"]), ", ".join(parts)]


func _run_hit(d: int) -> void:
	run_dmg += maxi(0, d)
	run_best = maxi(run_best, d)
const CHR_LIST_BOT := 1062.0


# k = index in the pack; rows scroll with inv_scroll
func _chr_row_rect(k: int) -> Rect2:
	return Rect2(40, 666 + chr_off + _inv_y(k), 640, 102)


func _chr_equip_rect(k: int) -> Rect2:
	return Rect2(548, 666 + chr_off + _inv_y(k) + 8, 124, 42)


func _chr_sell_rect(k: int) -> Rect2:
	return Rect2(548, 666 + chr_off + _inv_y(k) + 54, 124, 38)


func _chr_row_visible(k: int) -> bool:
	var r := _chr_row_rect(k)
	return r.position.y >= CHR_LIST_TOP + chr_off and r.end.y <= CHR_LIST_BOT


# the character model, optionally wearing a pack item (preview) in place of what is equipped
func _chr_tex(prev: String) -> ImageTexture:
	var eq: Dictionary = {}
	for sl in equip:
		eq[sl] = _gart(gb(String(equip[sl])))
	var psl := ""
	if prev != "":
		psl = String(gear_defs[gb(prev)]["slot"])
		eq[psl] = _gart(gb(prev))
	var show_rng := psl == "ranged" or (ranged_mode and psl != "weapon")
	if show_rng and eq.has("ranged"):
		eq["weapon"] = eq["ranged"]
	return spr_gen.player((cdef()["col"] as Color), _cls_art(cls), 0, chr_dir, eq)


func _mods_btn_rect() -> Rect2:
	return Rect2(40, _chr_model_rect().end.y + 4.0, 640.0, 40.0)


func _chr_input(p: Vector2) -> void:
	for b in _card_btns():
		if (b[3] as Rect2).has_point(p):
			_card_act(String(b[0]))
			return
	if _chr_model_rect().has_point(p):
		chr_dir = {0: 3, 3: 1, 1: 0}.get(chr_dir, 0)
		_sfx("ui")
		return
	if bag.size() > 1 and btn_inv_sort.has_point(p):
		inv_sort = 1 - inv_sort
		_inv_do_sort()
		chr_sel = -1
		_sfx("ui")
		return
	for i in 6:
		if _chr_slot_rect(i).has_point(p):
			chr_sel = -1
			slot_sel = -1 if slot_sel == i or String(equip.get(String(CHR_SLOTS[i]), "")) == "" else i
			_sfx("ui")
			return
	for k in bag.size():
		if _pack_cell(k).has_point(p):
			slot_sel = -1
			chr_sel = -1 if chr_sel == k else k
			_sfx("ui")
			return
	if not _card_rect().has_point(p):
		chr_sel = -1
		slot_sel = -1


func _draw_char_tab(_acc: Color) -> void:
	if chr_sel >= bag.size():
		chr_sel = -1
	if slot_sel >= 0 and String(equip.get(String(CHR_SLOTS[slot_sel]), "")) == "":
		slot_sel = -1
	var prev := String(bag[chr_sel]) if chr_sel >= 0 else ""
	var psl := String(gear_defs[gb(prev)]["slot"]) if prev != "" else ""
	var mr := _chr_model_rect()
	_obox(mr, Color(1, 1, 1, 0.04))
	_aline(mr, Color(1, 1, 1, 0.18), 2.0)
	_spr(_chr_tex(prev), mr.get_center() + Vector2(0, -4), 272.0)
	var tcn := mr.end - Vector2(26, 26)
	draw_arc(tcn, 11.0, 0.5, 5.3, 18, C_DIM, 2.5)
	draw_colored_polygon(PackedVector2Array([tcn + Vector2(4, -17), tcn + Vector2(14, -10), tcn + Vector2(3, -5)]), C_DIM)
	for i in 6:
		var slot := String(CHR_SLOTS[i])
		var r := _chr_slot_rect(i)
		var col := _gear_col(slot)
		var gid := String(equip.get(slot, ""))
		var sel := slot_sel == i or psl == slot
		if gid == "":
			_frame(r, Color(1, 1, 1, 0.5), sel)
			_txt(slot.to_upper(), r.position + Vector2(0, 24), T_SMALL, col, r.size.x)
			_txt("empty", r.position + Vector2(0, 68), T_SMALL, C_DIM, r.size.x)
		else:
			_frame(r, _tier_col(int(gear_defs[gb(gid)]["tier"])), sel)
			_txt(slot.to_upper(), r.position + Vector2(0, 24), T_SMALL, col, r.size.x)
			_spr(_gear_tex(gid), r.position + Vector2(70, 62), 56.0)
	_txt("PACK  %d / %d" % [bag.size(), BAG_MAX], Vector2(46, 918), T_SMALL, C_DIM, 300.0, HORIZONTAL_ALIGNMENT_LEFT)
	if bag.size() > 1:
		_chip(btn_inv_sort, "SORT: " + ("TIER" if inv_sort == 1 else "SLOT"), C_INFO)
	for k in BAG_MAX:
		var cr := _pack_cell(k)
		if k >= bag.size():
			_obox(cr, Color(1, 1, 1, 0.03))
			_aline(cr, Color(1, 1, 1, 0.12), 2.0)
			continue
		var bid := String(bag[k])
		var gd2: Dictionary = gear_defs[gb(bid)]
		_frame(cr, _tier_col(int(gd2["tier"])), k == chr_sel)
		_spr(_gear_tex(bid), cr.get_center() + Vector2(0, -4), 64.0)
		draw_rect(Rect2(cr.position.x + 12, cr.end.y - 12, cr.size.x - 24, 4), _gear_col(String(gd2["slot"])))
		var bt := _gear_better(bid)
		if bt != 0:
			var ac := cr.position + Vector2(cr.size.x - 16, 18)
			var pts := PackedVector2Array([ac + Vector2(0, -8), ac + Vector2(8, 6), ac + Vector2(-8, 6)])
			if bt < 0:
				pts = PackedVector2Array([ac + Vector2(0, 8), ac + Vector2(8, -6), ac + Vector2(-8, -6)])
			draw_colored_polygon(pts, C_GOOD if bt > 0 else C_BAD)
	_draw_item_card()


# a pack row cut by the list edge: draw the part that is inside the list
func _draw_row_partial(idx: int) -> void:
	var lt := CHR_LIST_TOP + chr_off
	var lb := CHR_LIST_BOT
	var area := Rect2(0, lt, 720, lb - lt)
	var bid := String(bag[idx])
	var gd2: Dictionary = gear_defs[gb(bid)]
	var gc := _gear_col(String(gd2["slot"]))
	var rr := _chr_row_rect(idx)
	var cr := rr.intersection(area)
	if cr.size.y <= 0.0:
		return
	_obox(cr, Color(gc.r, gc.g, gc.b, 0.08))
	var oc := Color(gc.r, gc.g, gc.b, 0.55)
	draw_line(cr.position, Vector2(cr.position.x, cr.end.y), oc, 2.0)
	draw_line(Vector2(cr.end.x, cr.position.y), cr.end, oc, 2.0)
	if rr.position.y >= lt:
		draw_line(rr.position, Vector2(rr.end.x, rr.position.y), oc, 2.0)
	if rr.end.y <= lb:
		draw_line(Vector2(rr.position.x, rr.end.y), rr.end, oc, 2.0)
	var tex := _gear_tex(bid)
	var ssz := 64.0
	if tex.has_meta("scl"):
		ssz *= float(tex.get_meta("scl"))
	var sc := rr.position + Vector2(50, 51)
	var srect := Rect2(sc.x - ssz * 0.5, sc.y - ssz * 0.5, ssz, ssz)
	var sclip := srect.intersection(area)
	if sclip.size.y > 0.0:
		var ts := tex.get_size()
		var src := Rect2((sclip.position - srect.position) / ssz * ts, sclip.size / ssz * ts)
		draw_texture_rect_region(tex, sclip, src)
	var y0 := rr.position.y
	if y0 + 32.0 - 24.0 >= lt and y0 + 32.0 + 6.0 <= lb:
		_txt(String(gd2["name"]), rr.position + Vector2(98, 32), 24, _tier_col(int(gd2["tier"])), 290.0, HORIZONTAL_ALIGNMENT_LEFT)
	if y0 + 56.0 - 16.0 >= lt and y0 + 56.0 + 5.0 <= lb:
		_txt(String(gd2["slot"]).to_upper(), rr.position + Vector2(98, 56), 16, gc, 90.0, HORIZONTAL_ALIGNMENT_LEFT)
		if gtrait_line(bid) != "":
			_txt(gtrait_line(bid), rr.position + Vector2(190, 56), 14, Color("ffd84f"), 240.0, HORIZONTAL_ALIGNMENT_LEFT)
	if y0 + 84.0 - 15.0 >= lt and y0 + 84.0 + 5.0 <= lb:
		_txt(_gear_desc(gd2, bid), rr.position + Vector2(98, 84), 15, Color(1, 1, 1, 0.75), 440.0, HORIZONTAL_ALIGNMENT_LEFT)
	var btns: Array = [[_chr_equip_rect(idx), "EQUIP", gc, 22], [_chr_sell_rect(idx), "SELL %d" % _sell_val(bid), Color("ffc93c"), 18]]
	if sk("reforge") > 0.0:
		btns.append([_chr_forge_rect(idx), "FORGE %d/%d" % [_forge_cost(bid), scrap], Color("c9a36b") if scrap >= _forge_cost(bid) else Color(1, 1, 1, 0.35), 15])
	for b in btns:
		var br: Rect2 = b[0]
		var bc: Color = b[2]
		if br.position.y >= lt and br.end.y <= lb:
			_button(br, String(b[1]), bc, int(b[3]))
		else:
			var bcl := br.intersection(area)
			if bcl.size.y > 0.0:
				draw_rect(bcl, Color(bc.r, bc.g, bc.b, 0.14))


func _inv_use_rect(i: int) -> Rect2:
	return Rect2(548, 262 + i * 100 + 19, 120, 52)


func _owned_relics() -> Array:
	var out: Array = []
	for d in relic_defs:
		if relic_n(String(d["id"])) > 0:
			out.append(d)
	return out


func _menu_leave() -> void:
	if t - menu_armed < 3.0:
		menu_armed = -10.0
		if mini:
			_mini_end("You left the puzzle run")
			return
		walk.clear()
		aim = -1
		_save_run()
		if tutorial:
			_tut_map_end(false)
		if testroom:
			_test_room_end()
		if in_base:
			_base_end()
		state = MODE
		_sfx("ui")
	else:
		menu_armed = t
		_sfx("blocked")


func _inv_input(p: Vector2) -> void:
	if btn_invmenu.has_point(p):
		_menu_leave()
		return
	if btn_incx.has_point(p):
		cx_ret = INV
		_cx_open()
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
			slot_sel = -1
			stat_open = -1
			inv_page = 0
			pack_page = 0
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
		var pages := maxi(1, (_owned_relics().size() + RELIC_PP - 1) / RELIC_PP)
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
	return [
		["#OFFENSE"],
		["CRIT CHANCE", "%d%%" % int(round(crit_chance())), "Chance for a hit to crit."],
		["CRIT DAMAGE", "x%.1f" % crit_mult(), "Damage multiplier when you crit."],
		["BERSERKER", "+%d%%" % int(sk("berserk")), "Extra damage while under half health."],
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
		["THORNS", "%d" % thorns_dmg() + ("  +%d%%" % int(sk("thorns")) if sk("thorns") > 0.0 else ""), "Damage reflected when you are hit."],
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
		["FREE SHOT", "%d%%" % int(gear("noammo") + sk("noammo")), "Chance a ranged shot uses no ammo."],
		["POD AIR", "%d" % int(adv_pod_amt()), "Air restored by each air pod."],
		["BREATHS", ("%d left" % can_n) if sk("breathe") > 0 else "none", "Deep breaths left this floor (heal for half your air)."],
		["AIR PER KILL", "%d" % int(sk("airkill")), "Max air gained by every kill."],
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
	_button(btn_invmenu, "SURE?" if armed else "MENU", C_BAD if armed else acc)
	_button(btn_inset, "SETTINGS", Color("c9d3f0"), 18)
	_button(btn_incx, "CODEX", C_RARE, 20)
	_txt("INVENTORY", Vector2(0, 150), T_TITLE, acc)
	var tabs := ["GEAR", "STATS", "TOOLS", "RELICS"]
	for i in 4:
		var tr := _inv_tab_rect(i)
		var cur := int(INV_TABS[i]) == mini(inv_tab, 3)
		var tc := C_GOLD if cur else Color(1, 1, 1, 0.5)
		_obox(tr, Color(tc.r, tc.g, tc.b, 0.16 if cur else 0.06))
		_aline(tr, tc, 2.0)
		_ctext(tabs[i], tr.get_center(), 20, tc)
	if inv_tab == 0:
		var all := _stat_list()
		var vt := 258.0
		var vb := 1132.0
		var yy := vt - inv_scroll
		var total := 0.0
		stat_hits.clear()
		for i in all.size():
			var r: Array = all[i]
			var hdr := r.size() == 1
			var op := i == stat_open and not hdr
			var hh := 46.0 if hdr else (90.0 if op else 54.0)
			if yy >= vt - 2.0 and yy + hh <= vb + 2.0:
				if hdr:
					_section(String(r[0]).substr(1), yy + 2.0)
				else:
					var rr := Rect2(40, yy, 640, hh - 6.0)
					_obox(rr, Color(C_INFO.r, C_INFO.g, C_INFO.b, 0.12 if op else 0.05))
					if op:
						_aline(rr, Color(C_INFO.r, C_INFO.g, C_INFO.b, 0.6), 2.0)
					_stat_row(Rect2(40, yy, 640, 48), String(r[0]), String(r[1]), Color.WHITE, T_BODY, 24)
					if op:
						_txt(String(r[2]), Vector2(54, yy + 72), T_SMALL, C_INFO, 612.0, HORIZONTAL_ALIGNMENT_LEFT)
					stat_hits.append([rr, i])
			yy += hh
			total += hh
		inv_scroll_max = maxf(0.0, total - (vb - vt))
		inv_scroll = clampf(inv_scroll, 0.0, inv_scroll_max)
		if inv_scroll_max > 0.0:
			var bh := (vb - vt) * (vb - vt) / total
			var by := vt + (vb - vt - bh) * inv_scroll / inv_scroll_max
			draw_rect(Rect2(690, by, 6, bh), Color(1, 1, 1, 0.35))
	elif inv_tab == 1:
		if inv.is_empty():
			_txt("No tools yet", Vector2(0, 520), T_HEAD, C_DIM)
		for i in inv.size():
			var id: String = inv[i]
			var y := 262.0 + i * 100.0
			var col: Color = use_defs[id]["col"]
			_frame(Rect2(40, y, 640, 90), col)
			_use_icon(id, Vector2(86, y + 45), 52)
			_txt(_use_name(id), Vector2(130, y + 34), T_BODY, Color.WHITE, 400.0, HORIZONTAL_ALIGNMENT_LEFT)
			_para_fit(_atext("tool_" + id, String(use_defs[id]["desc"])), Vector2(130, y + 58), T_SMALL, C_DIM, 400.0, 2)
			_button(_inv_use_rect(i), "USE", col, 24)
	elif inv_tab == 2:
		var owned := _owned_relics()
		var pages := maxi(1, (owned.size() + RELIC_PP - 1) / RELIC_PP)
		if owned.is_empty():
			_txt("No relics yet", Vector2(0, 520), T_HEAD, C_DIM)
		for k in RELIC_PP:
			var idx := inv_page * RELIC_PP + k
			if idx >= owned.size():
				break
			var d: Dictionary = owned[idx]
			var y := 262.0 + k * 112.0
			var cursed := d.has("curse")
			var col := C_BAD if cursed else C_RARE
			_frame(Rect2(40, y, 640, 102), col)
			var n := relic_n(String(d["id"]))
			_txt(_aname(String(d["id"]), String(d["name"])) + (" x%d" % n if n > 1 else ""), Vector2(58, y + 36), T_HEAD, col, 480.0, HORIZONTAL_ALIGNMENT_LEFT)
			if cursed:
				_txt("CURSED", Vector2(500, y + 32), T_SMALL, C_BAD, 164.0, HORIZONTAL_ALIGNMENT_RIGHT)
			_para_fit(_atext(String(d["id"]), String(d["desc"])), Vector2(58, y + 66), T_SMALL, C_TEXT, 610.0, 2)
		if pages > 1:
			_button(btn_ipv, "<", acc, 26)
			_button(btn_inx, ">", acc, 26)
			_dots(pages, inv_page, Vector2(360, 1098))
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
	var ul_old := ul_all
	ul_all = 1    # affixes unlock after 5 runs; the test save may not have them
	_adv_gen()
	ul_all = ul_old
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
	if seen.size() != 36 + 6 * SK_BR2.size() + SK_APX.size() or sk_defs.size() - _ck_count() != 36 + 6 * SK_BR2.size() + SK_APX.size():
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
	var want := {1: "supply", 4: "spore", 7: "outage", 10: "glare", 13: "supply"}
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
			# get_granted_permissions() only lists dangerous permissions, so VIBRATE (a normal one) never shows up there. The APK built from B83 on ships it.
			buzz_ok = 1
		elif OS.has_feature("web"):
			buzz_ok = 1
	if buzz_ok == 1:
		Input.vibrate_handheld(ms)


const SFX_BUZZ := {"ui": 10, "blocked": 18, "shieldbreak": 45, "death": 160, "elite": 40, "boom": 50, "breach": 30, "spike": 25, "big": 25}


func _sfx(n: String, pit := 1.0) -> void:
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
	chosen.pitch_scale = randf_range(0.97, 1.04) if n == "step" else pit
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
	if ResourceLoader.exists("res://art/music/main_theme.mp3"):
		if music_player.playing and music_theme == -2:
			return
		var mm := load("res://art/music/main_theme.mp3") as AudioStreamMP3
		if mm != null:
			mm.loop = true
			music_theme = -2
			music_player.stream = mm
			music_player.play()
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


# ===== B75: Class Mastery, class trees, specialisations and the Codex =====

var mxp: Dictionary = {}      # class id -> total mastery XP
var mspec: Dictionary = {}    # class id -> "a" / "b" (chosen at mastery 10)
var msub: Dictionary = {}     # class id -> "1" / "2" (chosen at mastery 20)
var cx: Dictionary = {}       # codex progress: stats, best floors, builds, things found
var run_mxp := 0
var mx_cls := "scout"
var cp: Dictionary = {}
var cp_cls := ""
var cp_lv := 0
var cp_dirty := true
var hex_left := 0
var hex_hit := false
var dodge_ready := false
var sk_view := 0              # 0 skill web, 1 class tree
var ck_edges: Array = []
var cx_tab := 0
var cx_scroll := 0.0
var cx_max := 0.0
var cx_lay: Array = []
var btn_sk_view := Rect2(20, 214, 200, 54)
var btn_mast := Rect2(40, 1100, 200, 76)
var btn_codex := Rect2(50, 1032, 620, 80)
var btn_mx_l := Rect2(20, 100, 90, 70)
var btn_mx_r := Rect2(610, 100, 90, 70)
var btn_mx_back := Rect2(160, 1190, 400, 70)
var btn_cx_t0 := Rect2(40, 168, 310, 64)
var btn_cx_t1 := Rect2(370, 168, 310, 64)
var btn_cx_back := Rect2(160, 1190, 400, 70)
const CX_TOP := 250.0
const CX_BOT := 1170.0
const MX_MAX := 30
const MX_STAR := 1500
const CK_MREQ := [1, 3, 6, 8, 12, 16]
const CK_SREQ := [10, 11, 13, 17]
const MX_REW := ["node", "hp", "node", "sp", "pw", "node", "air", "node", "tool", "spec",
	"hp", "node", "coin", "sp", "pw", "node", "air", "slot", "hp", "sub",
	"coin", "sp", "air", "hp", "pw", "gear", "sp", "hp", "coin", "master"]

# Class trees. Node = [name, description (%s = value), stat, [rank 1, rank 2]].
# Spec passives ("s") are always on once chosen. Sub keystones have one rank and cost 3 points.
const CK := {
	"scout": {
		"core": [
			["Trailblazer", "+%s sight radius", "sight", [1, 2]],
			["Fleet Foot", "Walking refunds 1 air every %s steps", "c_fleet", [4, 3]],
			["Afterimage", "While above half air, %s%% of enemy hits miss you (counts as a dodge)", "c_afterimg", [6, 12]],
			["Second Breath", "Deep Breath gives %s more free steps", "brfree", [2, 4]],
			["Scavenger's Nose", "Kills restore %s air", "killair", [2, 4]],
			["Windwalker", "Dodging restores %s air and heals 2 health", "dodgeair", [5, 10]]],
		"a": {"n": "PATHFINDER", "d": "+20 max air and +1 sight. A survivor who lives off the station.", "s": {"air": 20, "sight": 1},
			"nodes": [
				["Scout Ahead", "The first %s steps on each floor cost no air", "c_scoutah", [8, 16]],
				["Second Wind", "Once per floor, dropping below 25%% air instantly restores %s air", "c_2wind", [20, 40]],
				["Runner's High", "Every 10 steps without attacking heals %s health", "c_runhigh", [2, 4]],
				["Breath Control", "Deep Breath also restores %s air", "c_brair", [15, 30]]],
			"subs": {
				"1": {"n": "VOIDRUNNER", "d": "10% less air used per step.", "s": {"airsave": 10}, "k": ["Void Sprint", "While above half air you deal %s%% more damage", "airdmg", [30]]},
				"2": {"n": "SURVIVOR", "d": "+8 max health.", "s": {"hp": 8}, "k": ["Last Gasp", "Once per floor, running out of air refills %s air instead", "wind", [40]]}}},
		"b": {"n": "SKIRMISHER", "d": "+6% dodge and +5% crit. Strike, slip away, strike again.", "s": {"dodge": 6, "crit": 5},
			"nodes": [
				["Feint", "Dodging heals %s health", "dodgeheal", [2, 4]],
				["Blindside", "+%s%% damage to enemies with no other enemy next to them", "c_blind", [20, 40]],
				["Dancer", "+%s%% damage for each dodge this floor (up to 5)", "c_dancer", [5, 8]],
				["Riposte", "Dodging a melee attack strikes back for %s%% of your attack", "c_riposte", [50, 100]]],
			"subs": {
				"1": {"n": "PHANTOM", "d": "+5% dodge.", "s": {"dodge": 5}, "k": ["Phantom Step", "After you dodge, your next hit deals %s%% more damage", "dodgedmg", [100]]},
				"2": {"n": "HUNTER", "d": "+10% ranged crit.", "s": {"rcrit": 10}, "k": ["Hunter's Mark", "+%s%% damage to elites, affixed enemies and bosses", "bigdmg", [35]]}}},
	},
	"brute": {
		"core": [
			["Shrug Off", "%s%% chance a hit deals only 1 damage to you", "c_shrug", [8, 15]],
			["Haymaker", "Every 4th melee hit deals +%s%% damage and stuns for 1 step", "c_haymaker", [50, 100]],
			["Brace", "+%s%% damage while Iron Stance is up", "c_brace", [20, 40]],
			["Unbreakable", "Iron Stance blocks %s more hit(s)", "stancen", [1, 2]],
			["Intimidate", "Kills stun every enemy next to you for %s step(s)", "c_intim", [1, 2]],
			["Retaliation", "Hits blocked by Iron Stance strike back for %s%% of your attack", "stancedmg", [100, 200]]],
		"a": {"n": "JUGGERNAUT", "d": "+1 armour and +10 max health. Nothing gets through.", "s": {"armor": 1, "hp": 10},
			"nodes": [
				["Immovable Object", "Taking a hit while standing still gives %s shield", "c_still", [2, 4]],
				["Stand Firm", "While standing still you take %s%% less damage", "c_firm", [10, 20]],
				["Iron Will", "Each hit Iron Stance blocks cuts its recharge by %s steps", "c_ironwill", [2, 4]],
				["Unstoppable", "Below half health, every hit Iron Stance blocks heals %s", "c_unstop", [2, 4]]],
			"subs": {
				"1": {"n": "WARDEN", "d": "+8 max shields.", "s": {"maxsh": 8}, "k": ["Fortress Stance", "Iron Stance also gives %s shield", "stancesh", [12]]},
				"2": {"n": "COLOSSUS", "d": "+15 max health.", "s": {"hp": 15}, "k": ["Earthshaker", "Kills deal %s%% of your attack to every enemy next to you", "c_quake", [75]]}}},
		"b": {"n": "BERSERKER", "d": "+1 attack and +10% damage under half health. Pain is fuel.", "s": {"atk": 1, "berserk": 10},
			"nodes": [
				["Rage Meter", "Every hit you take adds +%s%% damage to your next hit (stacks up to 5)", "c_rage", [8, 15]],
				["Bloodthirst", "Melee killing blows heal %s%% of the damage dealt", "c_bthirst", [25, 50]],
				["Cleave", "Melee hits splash %s%% damage onto another enemy next to you", "c_cleave", [30, 50]],
				["Death Wish", "+%s%% damage while you have no shield", "c_dwish", [10, 20]]],
			"subs": {
				"1": {"n": "WARLORD", "d": "+8% crit.", "s": {"crit": 8}, "k": ["Warcry", "Kills cut your power's recharge by %s steps", "killcd", [3]]},
				"2": {"n": "BLOODRAGER", "d": "Kills heal 4% of max health.", "s": {"kheal": 4}, "k": ["Rampage", "Kills give +%s%% damage for 3 steps (stacks up to 3)", "c_rampage", [20]]}}},
	},
	"mystic": {
		"core": [
			["Ward Weave", "Hexed hits give %s shield", "c_hexsh", [4, 8]],
			["Focus", "+%s%% XP", "xp", [10, 20]],
			["Echo Hex", "%s%% chance a hexed hit doesn't use up your Hex", "c_echohex", [15, 30]],
			["Deep Hex", "Hex Mark deals +%s%% more damage", "hexmult", [25, 50]],
			["Mana Shield", "Using your class power gives %s shield", "pwsh", [4, 8]],
			["Hex Lock", "A hexed hit stuns the target for %s step(s)", "hexstun", [1, 2]]],
		"a": {"n": "ELEMENTALIST", "d": "Burns last +1 step and found weapons roll elements 25% more often.", "s": {"kindle": 1, "attune": 25},
			"nodes": [
				["Fire Weave", "Hexed hits set the target on fire for %s steps", "c_hexfire", [3, 5]],
				["Static Aura", "Every 8 steps, a spark stuns a random enemy within %s tiles", "c_saura", [2, 3]],
				["Frost Ward", "%s%% chance an enemy that hits you is frozen for 1 step", "c_fward", [15, 30]],
				["Elemental Flux", "+%s%% damage for each different element on the target", "c_flux", [10, 20]]],
			"subs": {
				"1": {"n": "ARCHMAGE", "d": "Elemental Reactions are always on (power x1, stacks with the skill).", "s": {"react": 1}, "k": ["Arcane Surge", "+%s%% damage to enemies carrying any element", "eldmg", [30]]},
				"2": {"n": "STORMCALLER", "d": "+15% stun chance from shock.", "s": {"conduct": 15}, "k": ["Chain Lightning", "Every hit has a %s%% chance to arc to an enemy within 2 tiles for half damage", "chain", [30]]}}},
		"b": {"n": "WARLOCK", "d": "Your first hit marks enemies (+15% damage taken) and every hit heals 1. Hexed enemies are cursed for the floor.", "s": {"mark": 15, "leech": 1},
			"nodes": [
				["Lingering Curse", "Cursed enemies take +%s%% damage from you", "c_curse", [10, 20]],
				["Life Tap", "Hits on cursed enemies heal %s", "c_ltap", [1, 2]],
				["Wither", "Cursed enemies deal %s%% less damage to you", "c_wither", [15, 30]],
				["Soul Harvest", "Killing a cursed enemy cuts Hex Mark's recharge by %s steps", "c_harvest", [3, 6]]],
			"subs": {
				"1": {"n": "HEXBLADE", "d": "+1 attack.", "s": {"atk": 1}, "k": ["Twin Hex", "Hex Mark lasts for %s extra hit(s)", "hexn", [1]]},
				"2": {"n": "SOULREAPER", "d": "Kills cut your power's recharge by 2 steps.", "s": {"killcd": 2}, "k": ["Reap", "Kills restore %s air and give 2 shield", "reap", [6]]}}},
	},
	"gambler": {
		"core": [
			["Double or Nothing", "%s%% chance a hit deals double damage, but a 10%% chance it deals half", "c_ddown", [10, 20]],
			["Pickpocket", "Hits have a %s%% chance to steal a coin", "c_pick", [15, 30]],
			["Loaded Dice", "Every %sth kill gives you a random tool", "c_dice", [8, 5]],
			["House Edge", "Reshuffle also gives %s coins", "rscoin", [3, 6]],
			["Card Trick", "Using a tool flings a card at a random enemy within 3 tiles for %s%% of your attack", "c_ctrick", [50, 100]],
			["Jackpot", "Kills have a %s%% chance to drop a pile of coins", "jackpot", [8, 15]]],
		"a": {"n": "HIGH ROLLER", "d": "Shops charge 10% less and coins are worth +1. Money talks.", "s": {"haggle": 10, "coin": 1},
			"nodes": [
				["High Stakes", "+%s%% damage for every 50 coins you carry (up to 5 times)", "c_stakes", [3, 6]],
				["Bribe", "Elites and affixed enemies drop %s extra coins", "c_bribe", [3, 6]],
				["Insurance", "When a hit would leave you under 25%% health, pay %s coins to halve it", "c_insure", [15, 8]],
				["Golden Touch", "Killing an enemy from full health in one hit gives %s coins", "c_onehit", [2, 4]]],
			"subs": {
				"1": {"n": "TYCOON", "d": "Every kill drops +1 coin.", "s": {"kcoin": 1}, "k": ["Compound Interest", "Clearing a floor pays %s%% of your run coins as interest (up to 25)", "interest", [10]]},
				"2": {"n": "FIXER", "d": "The first visit to each merchant gives a free tool.", "s": {"supply": 1}, "k": ["Rigged Deck", "After Reshuffle, your next hit deals x%s damage", "c_rigged", [3]]}}},
		"b": {"n": "TRICKSTER", "d": "+1 tool slot and a 10% chance a tool isn't used up.", "s": {"slots": 1, "tinker": 10},
			"nodes": [
				["Sleight of Hand", "Using a tool makes your next hit deal +%s%% damage", "c_sleight", [30, 60]],
				["Wild Card", "Reshuffle gives %s shield", "rssh", [6, 12]],
				["Misdirection", "Using a tool stuns every enemy next to you for %s step(s)", "c_misdir", [1, 2]],
				["Quick Fingers", "Every tool you use cuts Reshuffle's recharge by %s steps", "c_qfing", [2, 4]]],
			"subs": {
				"1": {"n": "CHAOS MAGE", "d": "+5% crit.", "s": {"crit": 5}, "k": ["Wild Magic", "Every %sth hit triggers a random effect: burn, poison, stun, coins or shield", "c_wild", [4]]},
				"2": {"n": "CARDSHARP", "d": "8% chance for a kill to give double XP.", "s": {"lucky": 8}, "k": ["Ace Up the Sleeve", "Crits have a %s%% chance to give you a random tool", "c_ace", [25]]}}},
	},
	"gunslinger": {
		"core": [
			["Steady Aim", "Shots deal +%s%% damage if you didn't move last step", "c_steady", [20, 40]],
			["Bandolier", "Reload 1 ammo every %s steps", "c_band", [10, 6]],
			["Quickdraw", "Your first shot at each enemy deals +%s%% damage", "c_qdraw", [30, 60]],
			["Trick Shot", "Loading Ricochet refunds %s ammo", "ricoammo", [1, 2]],
			["Dead Man's Hand", "Below 30%% health, shots refund their ammo and deal +%s%% damage", "c_dmhand", [15, 30]],
			["Double Tap", "Ricochet bounces %s extra time(s)", "ricob", [1, 2]]],
		"a": {"n": "DEADEYE", "d": "+1 shot range and +5% ranged crit. One shot, one kill.", "s": {"rrange": 1, "rcrit": 5},
			"nodes": [
				["Called Shot", "Shots at enemies 4 or more tiles away stun them for %s step(s)", "c_called", [1, 2]],
				["Hollow Points", "Shots make enemies bleed for %s steps", "c_hollow", [2, 4]],
				["Focus Fire", "Each shot in a row at the same enemy deals +%s%% more damage (up to 5)", "c_focus", [5, 10]],
				["Kill Shot", "Shots finish off enemies left under %s%% health (not bosses)", "c_kshot", [10, 15]]],
			"subs": {
				"1": {"n": "SNIPER", "d": "+2 ranged damage.", "s": {"rdmg": 2}, "k": ["Headshot", "Shots deal +%s%% damage to enemies 3 or more tiles away", "fardmg", [50]]},
				"2": {"n": "SPOTTER", "d": "Your first hit marks enemies (+15% damage taken).", "s": {"mark": 15}, "k": ["Overwatch", "Every 4 steps, auto-fire 1 ammo at a marked enemy within 3 tiles for %s%% of your attack", "c_owatch", [100]]}}},
		"b": {"n": "DESPERADO", "d": "+4 max ammo and a 10% chance a shot uses no ammo.", "s": {"ammomax": 4, "noammo": 10},
			"nodes": [
				["Fan the Hammer", "Shots also hit another enemy next to the target for %s%% damage", "c_fan", [30, 60]],
				["Gunsmoke", "After you shoot, %s%% of hits miss you until your next step", "c_gsmoke", [15, 30]],
				["Reload", "Kills with a shot have a %s%% chance to refund 1 ammo", "c_reload", [50, 100]],
				["Pistol Whip", "Melee hits have a %s%% chance to give 1 ammo", "c_pwhip", [50, 100]]],
			"subs": {
				"1": {"n": "OUTLAW", "d": "Every kill drops +1 coin.", "s": {"kcoin": 1}, "k": ["Wanted", "Kills with a shot drop %s extra coins", "c_wanted", [3]]},
				"2": {"n": "PISTOLERO", "d": "+6% crit.", "s": {"crit": 6}, "k": ["Gun Kata", "+%s%% damage to all attacks while an enemy is next to you", "adjdmg", [25]]}}},
	},
	"engineer": {
		"core": [
			["Arc Stun", "Arc Pulse stuns for %s more step(s)", "c_arcstun", [1, 2]],
			["Tesla Coil", "Hits on stunned enemies arc %s damage to every enemy next to them", "c_tesla", [2, 4]],
			["Capacitor", "Arc Pulse gives %s shield for each enemy it hits", "c_capsh", [1, 2]],
			["Arc Coils", "Arc Pulse deals +%s%% damage", "arcp", [25, 50]],
			["Overload", "Killing a stunned enemy stuns %s other enemy(ies) within 2 tiles", "c_overload", [1, 2]],
			["Overclock", "+%s%% damage while Arc Pulse is recharging", "c_ovclk", [10, 20]]],
		"a": {"n": "MECHANIST", "d": "Your drone fires every 6 steps and drone kills drop coins. +1 tool slot.", "s": {"apx_merc": 1, "slots": 1},
			"nodes": [
				["Twin Drone", "Your drone also zaps a second enemy for %s%% damage", "c_dtwin", [50, 100]],
				["Drone Salvage", "Drone kills give %s scrap", "c_dscrap", [1, 2]],
				["Drone Shield", "Each drone zap gives %s shield", "c_dsh", [1, 2]],
				["Drone Recall", "Drone kills cut Arc Pulse's recharge by %s steps", "c_drecall", [2, 4]]],
			"subs": {
				"1": {"n": "DRONE MASTER", "d": "Drone and hacked turrets +25% damage.", "s": {"rally": 25}, "k": ["Heavy Drone", "Drone zaps stun and burn their target for %s steps", "c_hdrone", [2]]},
				"2": {"n": "TECHNICIAN", "d": "10% chance a tool isn't used up.", "s": {"tinker": 10}, "k": ["Recharge Station", "Stepping on an O2 station recharges Arc Pulse by %s%%", "c_recst", [100]]}}},
		"b": {"n": "DEMOLITIONIST", "d": "+1 attack and Arc Pulse sets enemies on fire.", "s": {"atk": 1, "arcburn": 1},
			"nodes": [
				["Shrapnel", "Kills explode for %s%% of the victim's max health to enemies next to it", "blast", [15, 30]],
				["Napalm", "Burning enemies that die spread fire to enemies next to them for %s steps", "c_napalm", [2, 4]],
				["Blast Shield", "Kills give %s shield for each enemy next to the victim", "c_bsh", [1, 2]],
				["Big Bang", "Arc Pulse reaches %s more tile(s)", "arcr", [1, 2]]],
			"subs": {
				"1": {"n": "SAPPER", "d": "Enemies that hit you take 15% of the damage back.", "s": {"thorns": 15}, "k": ["Chain Reaction", "Every Arc Pulse kill cuts its recharge by %s steps", "arckill", [8]]},
				"2": {"n": "BOMBARDIER", "d": "Kills explode for 15% of the victim's max health.", "s": {"blast": 15}, "k": ["Detonator", "Arc Pulse detonates burning enemies for %s%% of your attack", "c_deton", [150]]}}},
	},
	"medic": {
		"core": [
			["Triage", "Below half health, Field Surgery heals another %s%% of max health", "c_triage", [10, 20]],
			["Vital Signs", "+%s%% damage while at full health", "c_vital", [10, 20]],
			["Antiseptic", "Field Surgery heals +%s%% of max health", "surg", [10, 20]],
			["Adrenal Shot", "Field Surgery gives %s air", "surgair", [15, 30]],
			["Adrenaline", "Taking a hit below half health gives %s shield (once every 5 steps)", "c_adren", [3, 6]],
			["Lifeline", "%s time(s) per floor, a killing blow is cancelled and Field Surgery fires for free", "c_lifeline", [1, 2]]],
		"a": {"n": "SURGEON", "d": "+10 max health, and healing past max becomes shield (up to 4).", "s": {"hp": 10, "transf": 4},
			"nodes": [
				["Incision", "Hits on enemies under half health make them bleed for %s steps", "c_incise", [2, 4]],
				["Anatomy", "+%s%% damage to bleeding enemies", "c_anat", [20, 40]],
				["Transfusion", "Hitting a bleeding enemy heals you %s", "c_bheal", [1, 2]],
				["Blood Bank", "Kills bank 1 blood (up to %s). Field Surgery heals 3%% more per blood and spends it", "c_bbank", [5, 10]]],
			"subs": {
				"1": {"n": "FIELD DOCTOR", "d": "O2 stations also heal 15% of max health.", "s": {"stationheal": 15}, "k": ["Miracle Worker", "Field Surgery makes you immune to damage for %s steps", "c_miracle", [2]]},
				"2": {"n": "PLAGUE DOCTOR", "d": "Poison can stack 2 higher.", "s": {"catal": 2}, "k": ["Contagion", "Field Surgery poisons every enemy within 3 tiles for %s stacks", "surgpsn", [3]]}}},
		"b": {"n": "GUARDIAN", "d": "+8 max shields and +1 armour.", "s": {"maxsh": 8, "armor": 1},
			"nodes": [
				["Barrier Burst", "When your shield breaks, enemies next to you are stunned for %s step(s)", "c_sbreak", [1, 2]],
				["Guardian Angel", "Steps where you don't attack restore 1 shield, up to %s", "c_gangel", [4, 8]],
				["Phase Shield", "Field Surgery gives %s shield", "surgsh", [6, 12]],
				["Martyr", "Below 30%% health, every hit you take cuts Field Surgery's recharge by %s steps", "c_martyr", [2, 4]]],
			"subs": {
				"1": {"n": "PALADIN", "d": "Enemies that hit you take 15% of the damage back.", "s": {"thorns": 15}, "k": ["Retribution", "Field Surgery hits every enemy within 2 tiles for %s%% of your attack", "c_retrib", [200]]},
				"2": {"n": "SENTINEL", "d": "+6% dodge.", "s": {"dodge": 6}, "k": ["Aegis Field", "Kills give %s shield", "killsh", [3]]}}},
	},
	"hacker": {
		"core": [
			["Backdoor", "Hijacked enemies stay yours %s more steps", "c_hjlen", [3, 6]],
			["Packet Sniffer", "Hijack reaches %s more tile(s)", "c_hjr", [1, 2]],
			["Exploit", "+%s%% damage to enemies next to a hijacked enemy", "c_exploit", [15, 30]],
			["Overclocked Rig", "Hijacked enemies hit %s%% harder", "c_hjdmg", [25, 50]],
			["Firewall", "While you control a hijacked enemy you take %s%% less damage", "c_fwall", [10, 20]],
			["System Crash", "When a hijack ends, the enemy takes %s%% of its max health as damage", "c_kswitch", [20, 40]]],
		"a": {"n": "NETRUNNER", "d": "Hijack reaches 1 more tile and lasts 2 more steps.", "s": {"c_hjr": 1, "c_hjlen": 2},
			"nodes": [
				["Signal Boost", "Hijacked enemies regain %s health every step", "c_hjheal", [1, 2]],
				["Puppet Master", "Kills by hijacked enemies cut Hijack's recharge by %s steps", "c_puppet", [3, 6]],
				["Zero Day", "Hijacked enemies' attacks stun for %s step(s)", "c_hjstun", [1, 2]],
				["Data Leech", "Kills by hijacked enemies give you %s shield", "c_dleech", [3, 6]]],
			"subs": {
				"1": {"n": "GHOST", "d": "+8% dodge.", "s": {"dodge": 8}, "k": ["Ghost Protocol", "Hijacking cloaks you for %s steps", "c_ghost", [4]]},
				"2": {"n": "BOTNET", "d": "Hijacked enemies hit 25% harder.", "s": {"c_hjdmg": 25}, "k": ["Swarm Logic", "Hijack takes %s more enemy", "c_hjn", [1]]}}},
		"b": {"n": "SABOTEUR", "d": "Stunned enemies take +25% damage.", "s": {"stundmg": 25},
			"nodes": [
				["Short Circuit", "Hijack stuns every other enemy within %s tile(s) of its target for 1 step", "c_hjemp", [1, 2]],
				["EMP Rounds", "+%s%% damage to stunned enemies", "stundmg", [15, 30]],
				["Feedback Loop", "Hits on stunned enemies have a %s%% chance to stun them 1 step longer", "c_feedback", [20, 40]],
				["Logic Bomb", "Stunned enemies you kill explode for %s%% of your attack to enemies next to them", "c_lbomb", [50, 100]]],
			"subs": {
				"1": {"n": "GLITCH", "d": "+8% crit.", "s": {"crit": 8}, "k": ["Corrupt", "Hits have a %s%% chance to scramble the target: it attacks an enemy next to it", "c_corrupt", [20]]},
				"2": {"n": "BLACKOUT", "d": "Hijack stuns enemies within 1 tile of its target.", "s": {"c_hjemp": 1}, "k": ["Blackout", "Hijack's stun also deals %s%% of your attack", "c_bout", [150]]}}},
	},
	"salvager": {
		"core": [
			["Scrap Collector", "Kills have a %s%% chance to drop 1 scrap", "c_scrapk", [15, 30]],
			["Price Check", "Strip Down deals +%s%% damage to elites, affixed enemies and bosses", "c_pcheck", [30, 60]],
			["Long Reach", "Strip Down reaches %s more tile(s)", "c_sdr", [1, 2]],
			["Scrap Power", "+%s%% damage for each scrap you hold (up to 20)", "c_pawn", [1, 2]],
			["Salvage Rights", "Strip Down kills give %s extra scrap", "c_sdscrap", [1, 2]],
			["Recycle", "Strip Down kills cut its recharge by %s steps", "c_sdref", [5, 10]]],
		"a": {"n": "SCRAPPER", "d": "+1 armour, and kills give 1 shield.", "s": {"armor": 1, "killsh": 1},
			"nodes": [
				["Junk Plating", "Strip Down gives shield equal to %s%% of the damage it deals", "c_jplate", [30, 60]],
				["Scrap Wall", "While you hold 10+ scrap, hits deal %s less damage to you", "c_swall", [1, 2]],
				["Spare Parts", "A hit that takes over a quarter of your health spends 1 scrap to heal %s", "c_spare", [4, 8]],
				["Shrapnel Coat", "Enemies that hit you take %s damage for every 5 scrap you hold (up to 4x)", "c_scoat", [1, 2]]],
			"subs": {
				"1": {"n": "JUNKER", "d": "+8 max shields.", "s": {"maxsh": 8}, "k": ["Junk Shield", "Strip Down also gives %s shield", "c_jshield", [10]]},
				"2": {"n": "WRECKER", "d": "+2 attack.", "s": {"atk": 2}, "k": ["Wrecking Ball", "Strip Down also hits every enemy next to its target for %s%% damage", "c_wball", [75]]}}},
		"b": {"n": "PROSPECTOR", "d": "Coins are worth +1 and vaults give an extra tool.", "s": {"coin": 1, "vault": 1},
			"nodes": [
				["Strip Mining", "Strip Down kills drop %s extra coins", "c_sdcoin", [3, 6]],
				["Trade-In", "Selling gear also gives %s coin(s) per tier", "c_trade", [2, 4]],
				["Treasure Sense", "Strip Down kills have +%s%% gear chance", "c_sdgear", [15, 30]],
				["Deep Pockets", "Coin pickups have a %s%% chance to also give 1 scrap", "c_dpock", [15, 30]]],
			"subs": {
				"1": {"n": "MAGNATE", "d": "Every kill drops +1 coin.", "s": {"kcoin": 1}, "k": ["Gold Rush", "Strip Down kills drop coins worth %s times as much", "c_grush", [2]]},
				"2": {"n": "RELIC HUNTER", "d": "+10% gear drop chance.", "s": {"drop": 10}, "k": ["Relic Hunter", "Strip Down kills on elites and bosses always drop %s gear", "c_rhunt", [1]]}}},
	},
}


func _mx_on() -> bool:
	return mode == "adv" and not tutorial and not testroom and not mini and not in_base


func _mx_need(l: int) -> int:
	return 50 + 20 * l


func mx_level(c: String) -> int:
	var x := int(mxp.get(c, 0))
	var l := 0
	while l < MX_MAX and x >= _mx_need(l):
		x -= _mx_need(l)
		l += 1
	return l


func _mx_base(l: int) -> int:
	var s := 0
	for i in l:
		s += _mx_need(i)
	return s


func mx_stars(c: String) -> int:
	if mx_level(c) < MX_MAX:
		return 0
	return (int(mxp.get(c, 0)) - _mx_base(MX_MAX)) / MX_STAR


func _mx_prog(c: String) -> Vector2i:
	var l := mx_level(c)
	var x := int(mxp.get(c, 0)) - _mx_base(l)
	if l >= MX_MAX:
		return Vector2i(x % MX_STAR, MX_STAR)
	return Vector2i(x, _mx_need(l))


func _cls_col(cid: String) -> Color:
	for d in class_defs:
		if String(d["id"]) == cid:
			return d["col"]
	return Color.WHITE


func _cls_name(cid: String) -> String:
	for d in class_defs:
		if String(d["id"]) == cid:
			return String(d["name"])
	return cid


func _ck_scol(cid: String, sp: String) -> Color:
	return _cls_col(cid).lerp(Color("ffd84f") if sp == "a" else Color("7fd8ff"), 0.4)


func _spec_name(cid: String) -> String:
	var lv := mx_level(cid)
	var sp := String(mspec.get(cid, ""))
	if lv < 10 or not CK.has(cid) or not CK[cid].has(sp):
		return ""
	var nm := String(CK[cid][sp]["n"])
	var sb := String(msub.get(cid, ""))
	if lv >= 20 and CK[cid][sp]["subs"].has(sb):
		nm += " / " + String(CK[cid][sp]["subs"][sb]["n"])
	return nm


# Always-on class stats (mastery rewards + chosen specialisation), read through sk().
func _cls_pass() -> Dictionary:
	if save_off:
		return {}
	if cp_dirty or cp_cls != cls:
		cp_dirty = false
		cp_cls = cls
		cp = {}
		cp_lv = mx_level(cls)
		_cp_add(CLS_BASE.get(cls, {}))
		_cp_add(_ws_stats())
		for i in cp_lv:
			var k := String(MX_REW[i])
			if k == "hp":
				_cp_add({"hp": 3})
			elif k == "air":
				_cp_add({"air": 10})
			elif k == "slot":
				_cp_add({"slots": 1})
		if CK.has(cls) and cp_lv >= 10:
			var sp := String(mspec.get(cls, ""))
			if CK[cls].has(sp):
				_cp_add(CK[cls][sp]["s"])
				var sb := String(msub.get(cls, ""))
				if cp_lv >= 20 and CK[cls][sp]["subs"].has(sb):
					_cp_add(CK[cls][sp]["subs"][sb]["s"])
	return cp


func _cp_add(s: Dictionary) -> void:
	for k in s:
		cp[k] = float(cp.get(k, 0.0)) + float(s[k])


func _ck_on(id: String) -> bool:
	var d: Dictionary = sk_defs[id]
	if String(d["cls"]) != cls:
		return false
	_cls_pass()
	var sp := String(d["spec"])
	if sp != "" and (cp_lv < 10 or String(mspec.get(cls, "")) != sp):
		return false
	var sb := String(d["sub"])
	return sb == "" or (cp_lv >= 20 and String(msub.get(cls, "")) == sb)


func _pw() -> int:
	if not _mx_on():
		return 0
	var lv := mx_level(cls)
	return (1 if lv >= 5 else 0) + (1 if lv >= 15 else 0) + (1 if lv >= 25 else 0)


func _pw_lines(cid: String) -> Array:
	match cid:
		"scout":
			return ["+5 air and 2 more free steps", "also heals 15% of max health", "also gives 6 shield and recharges 25% faster"]
		"brute":
			return ["blocks 1 more hit", "blocked hits strike back for your full attack", "also heals 10% of max health and gives 4 shield"]
		"mystic":
			return ["Hex deals x2.5 damage", "a hexed hit stuns the target for 2 steps", "Hex deals x3 damage and recharges 25% faster"]
		"gambler":
			return ["also builds a tool in an empty slot (works with no tools)", "also pays 3 + floor coins", "fills every empty slot and gives 8 shield"]
		"gunslinger":
			return ["loading refunds 2 ammo", "the shot bounces 1 extra time", "bounces 1 more time and recharges 25% faster"]
	if NEW_PW.has(cid):
		return NEW_PW[cid]
	return ["-", "-", "-"]


func _mx_cd_mult() -> float:
	if not _mx_on():
		return 1.0
	var m := 1.0
	if mx_level(cls) >= MX_MAX:
		m *= 0.9
	if _pw() >= 3 and cls in ["scout", "mystic", "gunslinger", "medic", "hacker", "salvager"]:
		m *= 0.75
	if _an("surge"):
		m *= 0.5
	return m


func _mx_rew_text(cid: String, l: int) -> String:
	if l < 1 or l > MX_MAX:
		return ""
	var k := String(MX_REW[l - 1])
	var tx := ""
	match k:
		"node":
			var ix := CK_MREQ.find(l)
			tx = "Class node: " + (String(CK[cid]["core"][ix][0]) if CK.has(cid) and ix >= 0 else "?")
		"hp":
			tx = "+3 max health"
		"sp":
			tx = "+1 starting skill point"
		"pw":
			tx = "Power upgrade " + ["I", "II", "III"][[5, 15, 25].find(l)]
		"air":
			tx = "+10 max air"
		"tool":
			tx = "+1 starting tool"
		"spec":
			tx = "Choose a specialisation"
		"coin":
			tx = "+15 starting coins"
		"slot":
			tx = "+1 tool slot"
		"sub":
			tx = "Choose a sub-specialisation"
		"gear":
			tx = "Start with a random gear piece"
		"master":
			tx = "MASTER: power 10% faster, stars"
	if l in CK_SREQ and l != 10:
		tx += " (+spec node)"
	return tx


func _mx_gain(n: int) -> void:
	if not _mx_on() or n <= 0:
		return
	var old := mx_level(cls)
	var os := mx_stars(cls)
	n = int(round(float(n) * _ex_mx_mult()))
	mxp[cls] = int(mxp.get(cls, 0)) + n
	run_mxp += n
	var nl := mx_level(cls)
	if nl > old:
		cp_dirty = true
		_pop(pos, "MASTERY %d!" % nl, Color("ffd84f"))
		_fx_ring(vis_pos, Color("ffd84f"), 1.6, 0.6, 6.0)
		msg += "   %s Mastery %d: %s" % [_cls_name(cls), nl, _mx_rew_text(cls, nl)]
		_sfx("big")
		_save_meta()
	elif mx_stars(cls) > os:
		_pop(pos, "MASTERY STAR!", Color("ffd84f"))
		_save_meta()


func _mx_init_run() -> void:
	hex_left = 0
	hex_hit = false
	dodge_ready = false
	run_mxp = 0
	cp_dirty = true
	_ex_init_run()
	if not _mx_on():
		return
	_cx_st("runs", 1)
	var lv := mx_level(cls)
	for i in lv:
		var k := String(MX_REW[i])
		if k == "sp":
			skill_pts += 1
		elif k == "coin":
			coins += 15
		elif k == "tool":
			if inv.size() < slots_n():
				inv.append(_random_use())
		elif k == "gear":
			var kid := _adv_roll_gear(null, -1)
			var ks := String(gear_defs[gb(kid)]["slot"])
			if not equip.has(ks):
				equip[ks] = kid
			else:
				bag.append(kid)


func _mx_scout_breath() -> void:
	var p := _pw()
	var air := 10.0 + (5.0 if p >= 1 else 0.0)
	var free := 8 + (2 if p >= 1 else 0) + int(sk("brfree"))
	oxy = minf(oxy_max, oxy + air)
	act_free = free
	msg = "Deep Breath: +%d air, your next %d steps cost no air" % [int(air), free]
	_pop(pos, "+%d AIR" % int(air), Color("7fd8ff"))
	if p >= 2:
		_p_heal(maxi(1, int(hp_cap() * 0.15)))
	if p >= 3:
		sh = mini(sh_cap(), sh + 6)


func _mx_brute_stance() -> void:
	var p := _pw()
	act_stance = 2 + (1 if p >= 1 else 0) + int(sk("stancen"))
	msg = "Iron Stance: blocks 75%% of the next %d hits" % act_stance
	if sk("stancesh") > 0.0:
		sh = mini(sh_cap(), sh + int(sk("stancesh")))
	if p >= 3:
		_p_heal(maxi(1, int(hp_cap() * 0.1)))
		sh = mini(sh_cap(), sh + 4)


func _mx_blocked(src: Vector2i) -> void:
	_ck_blocked(src)
	var pct := sk("stancedmg") + (100.0 if cls == "brute" and _pw() >= 2 else 0.0)
	if pct > 0.0 and mons.has(src):
		_adv_damage_mon(src, maxi(1, int(float(p_atk()) * pct / 100.0)), Color("ff6a5c"))
		_pop(src, "RETALIATE", Color("ff6a5c"))


func _hex_mult() -> float:
	var p := _pw() if cls == "mystic" else 0
	return 2.0 + (0.5 if p >= 1 else 0.0) + (0.5 if p >= 3 else 0.0) + sk("hexmult") / 100.0


func _mx_hex_txt() -> String:
	return "x" + _nfmt(_hex_mult())


func _hex_use() -> void:
	if hex_left > 0:
		hex_left -= 1
	else:
		hex_armed = false


func _mx_reshuffle() -> void:
	if mode != "adv":
		return
	var p := _pw()
	if p >= 1 and inv.size() < slots_n():
		inv.append(_random_use())
	if p >= 3:
		while inv.size() < slots_n():
			inv.append(_random_use())
		sh = mini(sh_cap(), sh + 8)
	var cn := int(sk("rscoin")) + ((3 + floor_n) if p >= 2 else 0)
	if cn > 0:
		coins += cn
		_pop(pos, "+%d COINS" % cn, Color("ffd84f"))
	if sk("rssh") > 0.0:
		sh = mini(sh_cap(), sh + int(sk("rssh")))


func _mx_rico_load() -> void:
	var n := int(sk("ricoammo")) + (2 if _pw() >= 1 else 0)
	if n > 0:
		ammo = mini(ammo_max(), ammo + n)


func _rico_extra() -> int:
	var p := _pw() if cls == "gunslinger" else 0
	return int(sk("ricob")) + (1 if p >= 2 else 0) + (1 if p >= 3 else 0)


func _mx_power_used() -> void:
	_ck_power()
	if sk("pwsh") > 0.0:
		sh = mini(sh_cap(), sh + int(sk("pwsh")))


func _mx_hit_mul(c: Vector2i) -> float:
	var m := 0.0
	if sk("airdmg") > 0.0 and oxy * 2.0 > oxy_max:
		m += sk("airdmg") / 100.0
	if dodge_ready:
		dodge_ready = false
		m += sk("dodgedmg") / 100.0
	if sk("bigdmg") > 0.0 and (elite.has(c) or affix.has(c) or _boss_cell(c)):
		m += sk("bigdmg") / 100.0
	if sk("eldmg") > 0.0 and not _elems(c).is_empty():
		m += sk("eldmg") / 100.0
	if sk("adjdmg") > 0.0 and not _near_mons(pos, 1, []).is_empty():
		m += sk("adjdmg") / 100.0
	return m + _ex_hit_mul(c) + _ck_hit_mul(c)


func _mx_on_hit(c: Vector2i, dealt: int, left: int) -> int:
	left = _ck_on_hit(c, dealt, left, hex_hit)
	if hex_hit:
		hex_hit = false
		var hs := int(sk("hexstun")) + (2 if cls == "mystic" and _pw() >= 2 else 0)
		if hs > 0 and left > 0 and mons.has(c) and _st_ok(c):
			_st_stun(c, hs)
	if sk("chain") > 0.0 and tr_depth <= 1 and randf() * 100.0 < sk("chain"):
		var tg := _near_mons(c, 2, [])
		if tg.size() > 0:
			var o: Vector2i = tg[0]
			_fx_bolt(Vector2(c), Vector2(o), Color("9fe8ff"))
			tr_depth += 1
			_adv_damage_mon(o, maxi(1, dealt / 2), Color("9fe8ff"))
			tr_depth -= 1
	return left


func _mx_dodged() -> void:
	dodge_ready = true
	_ck_dodged()
	if sk("dodgeheal") > 0.0:
		_p_heal(int(sk("dodgeheal")))
	if sk("dodgeair") > 0.0:
		oxy = minf(oxy_max, oxy + sk("dodgeair"))
		_p_heal(2)


func _mx_kill(nc: Vector2i, is_boss: bool) -> void:
	_ex_kill(nc, is_boss)
	_ck_kill(nc, is_boss)
	if _mx_on():
		var el := elite.has(nc)
		_mx_gain(1 + (2 if el else 0) + (1 if affix.has(nc) else 0) + (20 if is_boss else 0))
		_cx_st("kills", 1)
		if el:
			_cx_st("elites", 1)
		if is_boss:
			_cx_st("bosses", 1)
	if sk("killair") > 0.0:
		oxy = minf(oxy_max, oxy + sk("killair"))
	if sk("reap") > 0.0:
		oxy = minf(oxy_max, oxy + sk("reap"))
		sh = mini(sh_cap(), sh + 2)
	if sk("killsh") > 0.0:
		sh = mini(sh_cap(), sh + int(sk("killsh")))
	if sk("killcd") > 0.0 and act_cd > 0:
		act_cd = maxi(0, act_cd - int(sk("killcd")))
	if sk("jackpot") > 0.0 and randf() * 100.0 < sk("jackpot"):
		var jc := 3 + floor_n
		coins += jc
		_pop(nc, "JACKPOT +%d" % jc, Color("ffd84f"))


func _mx_floor_clear() -> void:
	if sk("interest") > 0.0 and coins > 0:
		var ic := mini(25, int(float(coins) * sk("interest") / 100.0))
		if ic > 0:
			coins += ic
			_pop(pos, "+%d INTEREST" % ic, Color("ffd84f"))
	if not _mx_on():
		return
	_mx_gain(8 + 2 * floor_n)
	_cx_st("floors", 1)
	_cx_build(floor_n)
	_cx_scan()
	_ex_floor_clear()
	_save_meta()


func _mx_death() -> void:
	if not _mx_on():
		return
	_cx_st("deaths", 1)
	_cx_scan()
	_ex_death()


func _mx_bank_bonus(delta: int) -> int:
	if not _mx_on() or delta <= 0:
		return 0
	return delta * (mx_level(cls) + mini(25, mx_stars(cls)) + 15 * hz_run + 2 * mini(25, _ws("w_bank"))) / 100


func _mx_death_line(b: int) -> String:
	var lv := mx_level(cls)
	var s := "%s Mastery %d   +%d mastery XP" % [_cls_name(cls), lv, run_mxp]
	if b > 0:
		s += "   (+%d bonus coins)" % b
	return s + _ex_death_line()


func _mx_save(cfg: ConfigFile) -> void:
	cfg.set_value("mx", "xp", mxp)
	cfg.set_value("mx", "spec", mspec)
	cfg.set_value("mx", "sub", msub)
	cfg.set_value("mx", "cx", cx)
	_ex_save(cfg)


func _mx_load(cfg: ConfigFile) -> void:
	var a = cfg.get_value("mx", "xp", {})
	if a is Dictionary:
		mxp = a
	var b = cfg.get_value("mx", "spec", {})
	if b is Dictionary:
		mspec = b
	var c = cfg.get_value("mx", "sub", {})
	if c is Dictionary:
		msub = c
	var d = cfg.get_value("mx", "cx", {})
	if d is Dictionary:
		cx = d
	_ex_load(cfg)
	cp_dirty = true


func _mx_pack() -> Dictionary:
	return {"xp": mxp.duplicate(), "spec": mspec.duplicate(), "sub": msub.duplicate(), "cx": cx.duplicate(true), "ex": _ex_pack()}


func _mx_unpack(d) -> void:
	if not (d is Dictionary) or d.is_empty():
		return
	var ix: Dictionary = d.get("xp", {})
	for k in ix:
		mxp[k] = maxi(int(mxp.get(k, 0)), int(ix[k]))
	var isp: Dictionary = d.get("spec", {})
	for k in isp:
		mspec[k] = String(isp[k])
	var isb: Dictionary = d.get("sub", {})
	for k in isb:
		msub[k] = String(isb[k])
	var icx: Dictionary = d.get("cx", {})
	if not icx.is_empty():
		cx = icx.duplicate(true)
	_ex_unpack(d.get("ex", {}))
	cp_dirty = true


func _mx_wipe() -> void:
	mxp = {}
	mspec = {}
	msub = {}
	cx = {}
	_ex_wipe()
	cp_dirty = true


# ----- class tree nodes (live in sk_defs with a "cls" key, drawn on their own page) -----

func _ck_make() -> void:
	ck_edges.clear()
	for cid in CK:
		var cd: Dictionary = CK[cid]
		var col := _cls_col(String(cid))
		var core: Array = cd["core"]
		for n in core.size():
			_ck_add("k%s_c%d" % [cid, n], String(cid), "", "", core[n], Vector2(360, 262 + 110 * n), col, n == 5, false)
			if n > 0:
				ck_edges.append(["k%s_c%d" % [cid, n - 1], "k%s_c%d" % [cid, n]])
		for spv in ["a", "b"]:
			var sp := String(spv)
			var sd: Dictionary = cd[sp]
			var x := 130.0 if sp == "a" else 590.0
			var scol := _ck_scol(String(cid), sp)
			var nodes: Array = sd["nodes"]
			for n in nodes.size():
				_ck_add("k%s_s%s%d" % [cid, sp, n], String(cid), sp, "", nodes[n], Vector2(x, 372 + 110 * n), scol, false, false)
				if n > 0:
					ck_edges.append(["k%s_s%s%d" % [cid, sp, n - 1], "k%s_s%s%d" % [cid, sp, n]])
			ck_edges.append(["k%s_c1" % cid, "k%s_s%s0" % [cid, sp]])
			for sbv in ["1", "2"]:
				var sb := String(sbv)
				var kid := "k%s_x%s%s" % [cid, sp, sb]
				_ck_add(kid, String(cid), sp, sb, sd["subs"][sb]["k"], Vector2(x + (-62.0 if sb == "1" else 62.0), 840), scol, true, true)
				ck_edges.append(["k%s_s%s3" % [cid, sp], kid])


func _ck_add(id: String, cid: String, sp: String, sb: String, nd: Array, p: Vector2, col: Color, key: bool, apex: bool) -> void:
	sk_defs[id] = {"b": 30, "n": 0, "name": nd[0], "d": nd[1], "stat": nd[2], "v": nd[3], "key": key, "apex": apex, "cls": cid, "spec": sp, "sub": sb, "ring": 0, "pos": p, "col": col, "req": []}
	sk_adj[id] = []


func _ck_count() -> int:
	var n := 0
	for id in sk_defs:
		if sk_defs[id].has("cls"):
			n += 1
	return n


func _ck_unlocked(id: String) -> bool:
	return _ck_lock_reason(id) == ""


func _ck_lock_reason(id: String) -> String:
	var d: Dictionary = sk_defs[id]
	var cid := String(d["cls"])
	if cid != cls:
		return "Another class's node"
	var lv := mx_level(cid)
	var sp := String(d["spec"])
	var sb := String(d["sub"])
	var ix := int(id.right(1))
	if sp == "":
		var need: int = CK_MREQ[ix]
		if lv < need:
			return "Needs %s Mastery %d" % [_cls_name(cid), need]
		if ix > 0 and sk_rank("k%s_c%d" % [cid, ix - 1]) < 1:
			return "Needs the node above it first"
		return ""
	var spn := String(CK[cid][sp]["n"])
	if lv < 10 or String(mspec.get(cid, "")) != sp:
		return "Needs the %s specialisation (Mastery 10)" % spn
	if sb == "":
		var need2: int = CK_SREQ[ix]
		if lv < need2:
			return "Needs %s Mastery %d" % [_cls_name(cid), need2]
		if ix > 0 and sk_rank("k%s_s%s%d" % [cid, sp, ix - 1]) < 1:
			return "Needs the node above it first"
		return ""
	if lv < 20 or String(msub.get(cid, "")) != sb:
		return "Needs the %s sub-specialisation (Mastery 20)" % String(CK[cid][sp]["subs"][sb]["n"])
	if sk_rank("k%s_s%s3" % [cid, sp]) < 1:
		return "Needs the last %s node first" % spn
	return ""


func _ck_fmt(nd: Array) -> String:
	var vs: PackedStringArray = []
	for v in nd[3]:
		vs.append(_nfmt(float(v)))
	return String(nd[1]) % "/".join(vs)


func _ck_draw_map() -> void:
	var cid := cls
	if not CK.has(cid):
		_txt("This class has no tree", Vector2(0, 560), 26, Color(1, 1, 1, 0.6))
		return
	var lv := mx_level(cid)
	var ccol := _cls_col(cid)
	var pre := "k%s_" % cid
	_txt("%s  -  MASTERY %d" % [_cls_name(cid).to_upper(), lv], Vector2(230, 232), 18, ccol, 260.0)
	for e in ck_edges:
		if not String(e[0]).begins_with(pre):
			continue
		var pa: Vector2 = sk_defs[e[0]]["pos"]
		var pb: Vector2 = sk_defs[e[1]]["pos"]
		var on := sk_rank(String(e[0])) > 0 and sk_rank(String(e[1])) > 0
		var ec: Color = sk_defs[e[1]]["col"]
		draw_line(pa, pb, Color(ec.r, ec.g, ec.b, 0.8) if on else Color(1, 1, 1, 0.13), 3.0 if on else 2.0)
	for spv in ["a", "b"]:
		var sp := String(spv)
		var sd: Dictionary = CK[cid][sp]
		var x := 130.0 if sp == "a" else 590.0
		var act := lv >= 10 and String(mspec.get(cid, "")) == sp
		var hc := _ck_scol(cid, sp)
		_txt(String(sd["n"]), Vector2(x - 115.0, 300), 20, hc if act else Color(hc.r, hc.g, hc.b, 0.45), 230.0)
		var stt := "ACTIVE" if act else ("MASTERY 10" if lv < 10 else "CHOOSE IN MASTERY")
		_txt(stt, Vector2(x - 115.0, 322), 13, Color(1, 1, 1, 0.75 if act else 0.4), 230.0)
	for id in sk_defs:
		var d: Dictionary = sk_defs[id]
		if not d.has("cls") or String(d["cls"]) != cid:
			continue
		var c: Vector2 = d["pos"]
		var col: Color = d["col"]
		var rk := sk_rank(String(id))
		var can := sk_can_buy(String(id))
		var unl := sk_unlocked(String(id))
		var apx := bool(d.get("apex", false))
		var rad := 32.0 if apx else (30.0 if bool(d["key"]) else 24.0)
		var mxr := _sk_max(String(id))
		var fill := Color(col.r, col.g, col.b, 0.9 if rk >= mxr else (0.5 if rk == 1 else 0.07))
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
		if apx:
			draw_arc(c, rad + 4.0, 0.0, TAU, 32, Color(1, 1, 1, 0.25 + 0.15 * sin(t * 3.0)), 2.0)
		if can:
			draw_arc(c, rad + 6.0 + 2.0 * sin(t * 5.0), 0.0, TAU, 28, Color(1, 1, 1, 0.55), 2.0)
		if String(id) == sk_sel:
			draw_arc(c, rad + 10.0, 0.0, TAU, 28, Color.WHITE, 3.0)
		for k in mxr:
			var pc := c + Vector2((-6.0 + 12.0 * k) if mxr == 2 else 0.0, rad + 9.0)
			draw_circle(pc, 3.5, col if rk > k else Color(1, 1, 1, 0.2))
		var lw := 124.0 if apx else 210.0
		_txt(String(d["name"]), Vector2(c.x - lw * 0.5, c.y + rad + 28.0), 14, Color(1, 1, 1, 0.8 if unl or rk > 0 else 0.35), lw)


# ----- MASTERY screen -----

func _mx_spec_rect(i: int) -> Rect2:
	return Rect2(40 + 330 * i, 326, 310, 196)


func _mx_sub_rect(i: int) -> Rect2:
	return Rect2(40 + 330 * i, 562, 310, 140)


func _draw_mastery(acc: Color) -> void:
	var cid := mx_cls
	var col := _cls_col(cid)
	_obox(Rect2(24, 90, 672, 1086), Color(col.r, col.g, col.b, 0.06))
	_aline(Rect2(24, 90, 672, 1086), Color(col.r, col.g, col.b, 0.7), 2.0)
	var lv := mx_level(cid)
	_button(btn_mx_l, "<", col, 40)
	_button(btn_mx_r, ">", col, 40)
	_txt(_cls_name(cid).to_upper() + " MASTERY", Vector2(0, 150), T_TITLE, col)
	var pr := _mx_prog(cid)
	var head := ("MASTER  -  %d stars" % mx_stars(cid)) if lv >= MX_MAX else ("Level %d / %d" % [lv, MX_MAX])
	_txt("%s     %d / %d XP" % [head, pr.x, pr.y], Vector2(0, 198), T_BODY, C_GOLD)
	draw_rect(Rect2(60, 212, 600, 12), Color(1, 1, 1, 0.1))
	draw_rect(Rect2(60, 212, 600.0 * clampf(float(pr.x) / float(maxi(1, pr.y)), 0.0, 1.0), 12), col)
	var pct := lv + mini(25, mx_stars(cid))
	var note := "Play this class to earn mastery XP: kills, elites, bosses and every floor cleared. Each level also adds +1%% coins banked at the end of a run (now +%d%%)." % pct
	if not class_open(cid):
		note = "LOCKED - unlock this class in the shop first. " + note
	_para(note, Vector2(40, 252), 16, Color(1, 1, 1, 0.7), 640.0)
	if not CK.has(cid):
		_button(btn_mx_back, "BACK", acc, 28)
		return
	_txt("SPECIALISATION  -  MASTERY 10", Vector2(40, 314), T_SMALL, C_GOLD, 640.0, HORIZONTAL_ALIGNMENT_LEFT)
	for i in 2:
		var sp := "a" if i == 0 else "b"
		var sd: Dictionary = CK[cid][sp]
		var r := _mx_spec_rect(i)
		var on := String(mspec.get(cid, "")) == sp
		var sc := _ck_scol(cid, sp)
		var can := lv >= 10
		_obox(r, Color(sc.r, sc.g, sc.b, 0.22 if on else 0.07))
		_aline(r, sc if (on or can) else Color(1, 1, 1, 0.25), 3.0 if on else 2.0)
		_txt(String(sd["n"]), Vector2(r.position.x, r.position.y + 34), 26, sc, r.size.x)
		_para_fit(String(sd["d"]), Vector2(r.position.x + 14, r.position.y + 62), 16, Color.WHITE, r.size.x - 28, 3)
		var nn: PackedStringArray = []
		for nd in sd["nodes"]:
			nn.append(String(nd[0]))
		_para_fit("Nodes: " + ", ".join(nn), Vector2(r.position.x + 14, r.position.y + 128), T_SMALL, Color(1, 1, 1, 0.6), r.size.x - 28, 2)
		_txt("ACTIVE" if on else ("TAP TO CHOOSE" if can else "LOCKED"), Vector2(r.position.x, r.end.y - 12), 18, sc if on else Color(1, 1, 1, 0.55), r.size.x)
	_txt("SUB-SPECIALISATION  -  MASTERY 20", Vector2(40, 550), T_SMALL, C_GOLD, 640.0, HORIZONTAL_ALIGNMENT_LEFT)
	var csp := String(mspec.get(cid, ""))
	if lv < 10 or not CK[cid].has(csp):
		_para("Pick a specialisation. At Mastery 20 it splits in two.", Vector2(40, 600), 18, Color(1, 1, 1, 0.5), 640.0)
	else:
		for i in 2:
			var sb := "1" if i == 0 else "2"
			var sbd: Dictionary = CK[cid][csp]["subs"][sb]
			var r2 := _mx_sub_rect(i)
			var on2 := String(msub.get(cid, "")) == sb
			var sc2 := _ck_scol(cid, csp)
			var can2 := lv >= 20
			_obox(r2, Color(sc2.r, sc2.g, sc2.b, 0.22 if on2 else 0.07))
			_aline(r2, sc2 if (on2 or can2) else Color(1, 1, 1, 0.25), 3.0 if on2 else 2.0)
			_txt(String(sbd["n"]), Vector2(r2.position.x, r2.position.y + 30), 22, sc2, r2.size.x)
			var kn: Array = sbd["k"]
			_para_fit(String(sbd["d"]) + "  Keystone " + String(kn[0]) + ": " + _ck_fmt(kn), Vector2(r2.position.x + 12, r2.position.y + 54), T_SMALL, Color.WHITE, r2.size.x - 24, 4)
			_txt("ACTIVE" if on2 else ("TAP TO CHOOSE" if can2 else "MASTERY 20"), Vector2(r2.position.x, r2.end.y - 8), 16, sc2 if on2 else Color(1, 1, 1, 0.55), r2.size.x)
	_txt("POWER: " + String(ACTS[cid]["n"]).to_upper() if ACTS.has(cid) else "POWER", Vector2(40, 732), 20, col, 640.0, HORIZONTAL_ALIGNMENT_LEFT)
	var pl := _pw_lines(cid)
	for i in 3:
		var need: int = [5, 15, 25][i]
		_txt("%s   M%d   %s" % [["I", "II", "III"][i], need, pl[i]], Vector2(40, 758 + 24 * i), T_SMALL, Color("ffd84f") if lv >= need else Color(1, 1, 1, 0.45), 640.0, HORIZONTAL_ALIGNMENT_LEFT)
	_txt("REWARDS", Vector2(40, 846), T_SMALL, C_GOLD, 640.0, HORIZONTAL_ALIGNMENT_LEFT)
	for i in MX_MAX:
		var colx := 40.0 + 330.0 * float(i / 15)
		var ry := 870.0 + 20.0 * float(i % 15)
		_txt("%d  %s" % [i + 1, _mx_rew_text(cid, i + 1)], Vector2(colx, ry), T_SMALL, Color("ffd84f") if lv >= i + 1 else Color(1, 1, 1, 0.45), 320.0, HORIZONTAL_ALIGNMENT_LEFT)
	_button(btn_mx_back, "BACK", acc, 28)


func _mx_input(p: Vector2) -> void:
	if btn_mx_back.has_point(p):
		state = PLAY if in_base else CLASS
		_sfx("ui")
		return
	if btn_mx_l.has_point(p) or btn_mx_r.has_point(p):
		var ix := 0
		for i in class_defs.size():
			if String(class_defs[i]["id"]) == mx_cls:
				ix = i
		ix = (ix + (1 if btn_mx_r.has_point(p) else -1) + class_defs.size()) % class_defs.size()
		mx_cls = String(class_defs[ix]["id"])
		cls_page = ix
		_sfx("ui")
		return
	if not CK.has(mx_cls):
		return
	var lv := mx_level(mx_cls)
	for i in 2:
		if _mx_spec_rect(i).has_point(p):
			if lv < 10:
				_sfx("blocked")
				return
			var sp := "a" if i == 0 else "b"
			if String(mspec.get(mx_cls, "")) != sp:
				mspec[mx_cls] = sp
				msub[mx_cls] = ""
				cp_dirty = true
				_save_meta()
			_sfx("shield")
			return
		if _mx_sub_rect(i).has_point(p) and lv >= 10 and CK[mx_cls].has(String(mspec.get(mx_cls, ""))):
			if lv < 20:
				_sfx("blocked")
				return
			msub[mx_cls] = "1" if i == 0 else "2"
			cp_dirty = true
			_save_meta()
			_sfx("shield")
			return


func _mx_card_line(cid: String) -> void:
	var lv := mx_level(cid)
	_txt(("MASTER *%d" % mx_stars(cid)) if lv >= MX_MAX else ("MASTERY %d" % lv), Vector2(114, 284), 16, Color("ffd84f"), 200.0, HORIZONTAL_ALIGNMENT_LEFT)
	var sn := _spec_name(cid)
	if sn != "":
		_txt(sn, Vector2(386, 284), 16, _cls_col(cid), 220.0, HORIZONTAL_ALIGNMENT_RIGHT)


# ----- CODEX -----

func _cx_st(k: String, n: int) -> void:
	var st: Dictionary = cx.get("st", {})
	st[k] = int(st.get(k, 0)) + n
	cx["st"] = st


func _cx_note(g: String, gs: Dictionary, ts: Dictionary, ms: Dictionary) -> void:
	if g == "" or not gear_defs.has(gb(g)):
		return
	gs[gb(g)] = 1
	for tid in gtr(g):
		ts[String(tid)] = 1
	for mid in gmods(g):
		ms[String(mid)] = 1


func _cx_scan() -> void:
	if not _mx_on():
		return
	var gs: Dictionary = cx.get("gear", {})
	var ts: Dictionary = cx.get("tr", {})
	var ms: Dictionary = cx.get("md", {})
	var rs: Dictionary = cx.get("rl", {})
	for g in equip.values():
		_cx_note(String(g), gs, ts, ms)
	for g2 in bag:
		_cx_note(String(g2), gs, ts, ms)
	for rid in relics:
		rs[String(rid)] = 1
	cx["gear"] = gs
	cx["tr"] = ts
	cx["md"] = ms
	cx["rl"] = rs


func _cx_build(f: int) -> void:
	if f <= 0:
		return
	var lv := mx_level(cls)
	var sp := String(mspec.get(cls, "")) if lv >= 10 else ""
	var sb := String(msub.get(cls, "")) if (lv >= 20 and sp != "") else ""
	var key := cls + "/" + sp + "/" + sb
	var bl: Dictionary = cx.get("builds", {})
	bl[key] = maxi(int(bl.get(key, 0)), f)
	cx["builds"] = bl
	var cb: Dictionary = cx.get("cbest", {})
	cb[cls] = maxi(int(cb.get(cls, 0)), f)
	cx["cbest"] = cb


func _cx_open() -> void:
	state = CODEX
	cx_tab = 0
	cx_sec = -1
	cx_scroll = 0.0
	_cx_layout()
	_sfx("ui")


func _cx_layout_old() -> void:
	var pm := mode
	mode = "adv"
	var lines: Array = _cx_prog_lines() if cx_tab == 0 else _cx_guide_lines()
	mode = pm
	cx_lay.clear()
	var y := 0.0
	for ln in lines:
		var k := String(ln[0])
		var fs := 30 if k == "h" else (22 if k == "s" else (17 if k == "p" else 15))
		if k == "h" and y > 0.0:
			y += 24.0
		elif k == "s":
			y += 8.0
		var h := font.get_multiline_string_size(String(ln[1]), HORIZONTAL_ALIGNMENT_LEFT, 640.0, fs).y
		cx_lay.append([y, fs, String(ln[1]), ln[2], h])
		y += h + 6.0
	cx_max = maxf(0.0, y - (CX_BOT - CX_TOP) + 40.0)
	cx_scroll = clampf(cx_scroll, 0.0, cx_max)


func _cx_gui_old(event: InputEvent) -> bool:
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and event.position.y > CX_TOP:
		cx_scroll = clampf(cx_scroll - event.relative.y, 0.0, cx_max)
		return true
	if event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		cx_scroll = clampf(cx_scroll + (80.0 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -80.0), 0.0, cx_max)
		return true
	return false


func _cx_input_old(p: Vector2) -> void:
	if btn_cx_back.has_point(p):
		state = MODE
		_sfx("ui")
		return
	if btn_cx_t0.has_point(p) or btn_cx_t1.has_point(p):
		var nt := 0 if btn_cx_t0.has_point(p) else 1
		if nt != cx_tab:
			cx_tab = nt
			cx_scroll = 0.0
			_cx_layout()
		_sfx("ui")


func _draw_codex(acc: Color) -> void:
	_obox(Rect2(24, CX_TOP - 4.0, 672, CX_BOT - CX_TOP + 8.0), Color(acc.r, acc.g, acc.b, 0.06))
	_cx_draw_list()
	for ln in cx_lay:
		var y: float = CX_TOP + float(ln[0]) - cx_scroll
		var h: float = ln[4]
		if y + h < CX_TOP - 40.0 or y > CX_BOT + 10.0:
			continue
		_para(String(ln[2]), Vector2(40, y + float(ln[1])), int(ln[1]), ln[3], 640.0)
	draw_rect(Rect2(0, 0, 720, CX_TOP - 6.0), Color("0a0c14"))
	draw_rect(Rect2(0, CX_BOT, 720, 400), Color("0a0c14"))
	_aline(Rect2(24, CX_TOP - 4.0, 672, CX_BOT - CX_TOP + 8.0), Color(acc.r, acc.g, acc.b, 0.7), 2.0)
	_txt("CODEX", Vector2(0, 130), T_TITLE, acc)
	_button(btn_cx_t0, "PROGRESS", Color("ffd84f") if cx_tab == 0 else Color(1, 1, 1, 0.45), 24)
	_button(btn_cx_t1, "GUIDE", Color("7fd8ff") if cx_tab == 1 else Color(1, 1, 1, 0.45), 24)
	if cx_max > 0.0:
		var fr := cx_scroll / cx_max
		draw_rect(Rect2(706, CX_TOP + fr * (CX_BOT - CX_TOP - 60.0), 6, 60), Color(1, 1, 1, 0.3))
	_button(btn_cx_back, "SECTIONS" if cx_sec >= 0 else "BACK", acc, 28)


func _cx_prog_lines() -> Array:
	var L: Array = []
	var W := Color.WHITE
	var G := Color(1, 1, 1, 0.6)
	var Y := Color("ffd84f")
	var st: Dictionary = cx.get("st", {})
	L.append(["h", "OVERVIEW", Y])
	L.append(["p", "Best adventure floor: %d     Best puzzle floor: %d" % [adv_best, best], W])
	L.append(["p", "Bank: %d coins     Runs: %d     Deaths: %d" % [bank, int(st.get("runs", 0)), int(st.get("deaths", 0))], W])
	L.append(["p", "Kills: %d     Elites: %d     Bosses: %d     Floors cleared: %d" % [int(st.get("kills", 0)), int(st.get("elites", 0)), int(st.get("bosses", 0)), int(st.get("floors", 0))], W])
	var tl := 0
	for d in class_defs:
		tl += mx_level(String(d["id"]))
	L.append(["p", "Total mastery: %d / %d" % [tl, MX_MAX * class_defs.size()], W])
	L.append(["g", "Stats count from build 75 onward.", G])
	L.append(["h", "CLASSES AND MASTERY", Y])
	var cb: Dictionary = cx.get("cbest", {})
	for d in class_defs:
		var cid := String(d["id"])
		var lv := mx_level(cid)
		var pr := _mx_prog(cid)
		var c: Color = d["col"]
		L.append(["s", "%s   -   %s" % [String(d["name"]).to_upper(), ("MASTER, %d stars" % mx_stars(cid)) if lv >= MX_MAX else ("Mastery %d  (%d / %d XP)" % [lv, pr.x, pr.y])], c])
		if not class_open(cid):
			L.append(["p", "Locked - unlock it in the shop.", G])
			continue
		var sn := _spec_name(cid)
		L.append(["p", "Best floor: %d     Build: %s" % [int(cb.get(cid, 0)), sn if sn != "" else "base class"], W])
		if lv < MX_MAX:
			L.append(["g", "Next: level %d - %s" % [lv + 1, _mx_rew_text(cid, lv + 1)], G])
	var bl: Dictionary = cx.get("builds", {})
	var bn := 0
	var bt := 0
	var brow: Array = []
	for d in class_defs:
		var cid := String(d["id"])
		if not CK.has(cid):
			continue
		var nm := String(d["name"])
		var keys: Array = [[cid + "//", nm + " (base)"]]
		for spv in ["a", "b"]:
			var sp := String(spv)
			var sd: Dictionary = CK[cid][sp]
			keys.append([cid + "/" + sp + "/", nm + " - " + String(sd["n"])])
			for sbv in ["1", "2"]:
				keys.append([cid + "/" + sp + "/" + String(sbv), nm + " - " + String(sd["n"]) + " - " + String(sd["subs"][String(sbv)]["n"])])
		brow.append(["s", nm.to_upper(), d["col"]])
		for k in keys:
			bt += 1
			var f := int(bl.get(String(k[0]), 0))
			if f > 0:
				bn += 1
			brow.append(["p", ("[x] %s  -  best floor %d" % [String(k[1]), f]) if f > 0 else ("[  ] %s" % String(k[1])), Y if f > 0 else G])
	L.append(["h", "BUILDS ACHIEVED  %d / %d" % [bn, bt], Y])
	L.append(["g", "A build counts once you clear a floor with that class, specialisation and sub-specialisation active.", G])
	L.append_array(brow)
	var own := 0
	var urow: Array = []
	for sd2 in shop_defs:
		var mr := (sd2["costs"] as Array).size()
		var r := up(String(sd2["id"]))
		if r >= mr:
			own += 1
		var tag := "[x] " if r >= mr else (("[%d/%d] " % [r, mr]) if r > 0 else "[  ] ")
		urow.append(["p", tag + String(sd2["name"]) + "  -  " + String(sd2["desc"]), Y if r >= mr else (W if r > 0 else G)])
	L.append(["h", "SHOP UNLOCKS  %d / %d" % [own, shop_defs.size()], Y])
	L.append_array(urow)
	L.append(["h", "COLLECTION", Y])
	L.append(["g", "Everything you have carried at the end of a floor is recorded here.", G])
	var gs: Dictionary = cx.get("gear", {})
	for slot in ["weapon", "ranged", "helmet", "armour", "boots", "trinket"]:
		var tot := 0
		var fn: PackedStringArray = []
		for gd in gear_list:
			if String(gd["slot"]) != slot:
				continue
			tot += 1
			if gs.has(String(gd["id"])):
				fn.append(String(gd["name"]))
		L.append(["s", "%s  %d / %d" % [String(slot).to_upper(), fn.size(), tot], W])
		L.append(["g", ", ".join(fn) if fn.size() > 0 else "Nothing found yet", G])
	var ts: Dictionary = cx.get("tr", {})
	var tn: PackedStringArray = []
	for k2 in TRAIT_DEFS:
		if ts.has(String(k2)):
			tn.append(String(TRAIT_DEFS[k2]["n"]))
	L.append(["s", "WEAPON TRAITS  %d / %d" % [tn.size(), TRAIT_DEFS.size()], W])
	L.append(["g", ", ".join(tn) if tn.size() > 0 else "Nothing found yet", G])
	var ms: Dictionary = cx.get("md", {})
	var mn: PackedStringArray = []
	for k3 in MOD_DEFS:
		if ms.has(String(k3)):
			mn.append(String(MOD_DEFS[k3]["n"]))
	L.append(["s", "GEAR MODS  %d / %d" % [mn.size(), MOD_DEFS.size()], W])
	L.append(["g", ", ".join(mn) if mn.size() > 0 else "Nothing found yet", G])
	var rs: Dictionary = cx.get("rl", {})
	var rn: PackedStringArray = []
	var rt := 0
	for rd in relic_defs:
		if not rd.has("adv"):
			continue
		rt += 1
		if rs.has(String(rd["id"])):
			rn.append(_aname(String(rd["id"]), String(rd["name"])))
	L.append(["s", "RELICS  %d / %d" % [rn.size(), rt], W])
	L.append(["g", ", ".join(rn) if rn.size() > 0 else "Nothing found yet", G])
	L.append_array(_ex_prog_lines())
	return L


func _cx_guide_lines() -> Array:
	var L: Array = []
	var W := Color.WHITE
	var G := Color(1, 1, 1, 0.62)
	var Y := Color("ffd84f")
	var B := Color("7fd8ff")
	L.append(["h", "CLASS MASTERY", Y])
	L.append(["p", "Every class has its own mastery level (1 to 30). You earn mastery XP for the class you are playing: 1 per kill, +2 for elites, +1 for affixed enemies, +20 for bosses, and 8 + 2 x floor for every floor cleared. Level n needs 50 + 20 x n XP.", W])
	L.append(["p", "Every level adds +1% coins banked when a run ends. Past level 30 you earn a Mastery Star every 1500 XP; each star adds another +1% (up to 25).", W])
	L.append(["p", "Rewards apply automatically at the start of each run: max health, air, skill points, coins, tools, a gear piece and a tool slot. Power upgrades change your class power. Class nodes open on the CLASS TREE page of the skill screen and cost normal skill points.", W])
	var rl: PackedStringArray = []
	for i in MX_MAX:
		rl.append("%d: %s" % [i + 1, _mx_rew_text("scout", i + 1).replace("Trailblazer", "class node").replace("Light Feet", "class node").replace("Evasive", "class node").replace("Second Breath", "class node").replace("Scavenger's Nose", "class node").replace("Windwalker", "class keystone")])
	L.append(["g", "Reward track:  " + ",  ".join(rl), G])
	L.append(["s", "Specialisations", B])
	L.append(["p", "At Mastery 10 pick one of two specialisations (on the MASTERY screen, from class select). It gives an always-on passive and opens 4 spec nodes. At Mastery 20 pick one of its two sub-specialisations: another passive and a keystone worth 3 points. You can switch between runs for free; nodes from an inactive spec stop working.", W])
	L.append(["s", "Class tree unlocks", B])
	L.append(["p", "Core nodes open at Mastery 1, 3, 6, 8, 12 and 16 (each needs the one above it). Spec nodes open at 10, 11, 13 and 17. Sub keystones need Mastery 20 and the last spec node.", W])
	L.append(["h", "CLASSES, POWERS AND BUILDS", Y])
	for d in class_defs:
		var cid := String(d["id"])
		var c: Color = d["col"]
		L.append(["s", String(d["name"]).to_upper(), c])
		L.append(["p", _atext("cls_" + cid, String(d["desc"])), W])
		L.append(["p", _act_desc(cid), W])
		var pl := _pw_lines(cid)
		L.append(["g", "Power upgrades - I (Mastery 5): %s.  II (Mastery 15): %s.  III (Mastery 25): %s." % [pl[0], pl[1], pl[2]], G])
		if not CK.has(cid):
			continue
		var cn: PackedStringArray = []
		for nd in CK[cid]["core"]:
			cn.append("%s - %s" % [String(nd[0]), _ck_fmt(nd)])
		L.append(["g", "Core tree: " + ".  ".join(cn) + ".", G])
		for spv in ["a", "b"]:
			var sp := String(spv)
			var sd: Dictionary = CK[cid][sp]
			L.append(["p", "%s (Mastery 10): %s" % [String(sd["n"]), String(sd["d"])], _ck_scol(cid, sp)])
			var sn: PackedStringArray = []
			for nd2 in sd["nodes"]:
				sn.append("%s - %s" % [String(nd2[0]), _ck_fmt(nd2)])
			L.append(["g", "Nodes: " + ".  ".join(sn) + ".", G])
			for sbv in ["1", "2"]:
				var sbd: Dictionary = sd["subs"][String(sbv)]
				var kn: Array = sbd["k"]
				L.append(["g", "   %s (Mastery 20): %s  Keystone %s - %s." % [String(sbd["n"]), String(sbd["d"]), String(kn[0]), _ck_fmt(kn)], W])
	L.append(["h", "ELEMENTS", Y])
	L.append(["p", "Any weapon trait tagged with an element applies it on hit, so element skills, relics and specs work with every element trait.", W])
	L.append(["p", "FIRE - burns the enemy every step (Ignite: 2 + floor/2 damage for 3 steps). Kindling, Pyromancy and Elementalist add steps.", Color("ff9a3c")])
	L.append(["p", "SHOCK - 25% chance to stun on hit; a stunned enemy loses its next action. Conductor, Storm Call and Stormcaller raise the chance.", Color("ffe14f")])
	L.append(["p", "CRYO - the first hit chills and freezes an enemy for a step. Frozen = stunned + chilled. Deep Freeze and Frost Bite add damage to frozen enemies.", Color("9fe8ff")])
	L.append(["p", "TOXIC - poison stacks and hurts every step. Catalyst and Venom raise the stack cap.", Color("9dff6a")])
	L.append(["p", "BLOOD - bleeding enemies lose 10% of their max health every step (Hemorrhage, Blood Frenzy). With the Boiling Blood apex, bleed also counts as an element for reactions.", Color("ff4d6d")])
	L.append(["s", "Reactions", B])
	L.append(["p", "Need the Elemental Reactions skill or the Archmage sub-spec (they stack). Power = the sum of both. Base = 2 + level/2. The same enemy can't react again for 2 steps.", W])
	L.append(["p", "FIRE + CRYO = STEAM: base x power to the target and every enemy next to it.", W])
	L.append(["p", "SHOCK + TOXIC = CORRODE: the target takes +50% damage from everything for 3 steps.", W])
	L.append(["p", "FIRE + TOXIC = DETONATE: consumes burn and poison for (poison stacks x 3 + burn damage) x power.", W])
	L.append(["p", "CRYO + SHOCK = SHATTER: stuns for 2 steps and deals (base + 1) x power.", W])
	L.append(["p", "BLOOD + ANY = BOIL (Boiling Blood): (base + 2) x power, and every reaction heals you.", W])
	L.append(["s", "Element traits", B])
	for tk in TRAIT_DEFS:
		var td: Dictionary = TRAIT_DEFS[tk]
		var tags: Array = td.get("t", [])
		var el := false
		for tg in tags:
			if String(tg) in ["fire", "shock", "cryo", "toxic"]:
				el = true
		if el:
			L.append(["g", "%s [%s]: %s" % [String(td["n"]), ", ".join(PackedStringArray(tags)), String(td["d"])], W])
	L.append(["h", "STATUS EFFECTS", Y])
	L.append(["p", "Stun: loses its next action.  Freeze: stunned and chilled.  Root: can't move but can still hit.  Mark: takes extra damage from mark bonuses.  Bleed / Burn / Poison: damage each step.  Corrode: +50% damage taken.", W])
	L.append(["p", "On you - Acid halves your armour, Frost halves your attack, Poison and Burn hurt every step. Mind Shield and Toxin Filter mods reduce them.", W])
	L.append(["h", "WEAPON TRAITS  (%d)" % TRAIT_DEFS.size(), Y])
	var packed := {}
	for pkid in PACKS:
		var pn := String(pkid)
		for sd3 in shop_defs:
			if String(sd3["id"]) == pn:
				pn = String(sd3["name"])
		var tl: Array = PACKS[pkid]["t"]
		if tl.is_empty():
			continue
		L.append(["s", pn + "  (shop pack)", B])
		for tid in tl:
			packed[String(tid)] = true
			if TRAIT_DEFS.has(tid):
				L.append(["g", "%s: %s" % [String(TRAIT_DEFS[tid]["n"]), String(TRAIT_DEFS[tid]["d"])], W])
	L.append(["s", "Standard pool", B])
	for tk2 in TRAIT_DEFS:
		if not packed.has(String(tk2)):
			L.append(["g", "%s: %s" % [String(TRAIT_DEFS[tk2]["n"]), String(TRAIT_DEFS[tk2]["d"])], W])
	L.append(["h", "GEAR MODS  (%d)" % MOD_DEFS.size(), Y])
	L.append(["p", "Helmets, armour, boots and trinkets roll mods. RARE mods only roll on tier 4+ gear (12% per mod slot).", W])
	for slot in ["helmet", "armour", "boots", "trinket"]:
		L.append(["s", String(slot).to_upper(), B])
		for mk in MOD_DEFS:
			var md: Dictionary = MOD_DEFS[mk]
			if String(md.get("slot", "")) == slot:
				L.append(["g", "%s%s: %s" % [String(md["n"]), "  (RARE)" if bool(md.get("hi", false)) else "", String(md["d"])], Color("ffb347") if bool(md.get("hi", false)) else W])
	L.append(["h", "GEAR SETS", Y])
	for sid in GEAR_SETS:
		var gsd: Array = GEAR_SETS[sid]
		var pn2: PackedStringArray = []
		for gid in gsd[1]:
			pn2.append(String(gear_defs[gid]["name"]) if gear_defs.has(gid) else String(gid))
		L.append(["s", String(gsd[0]), B])
		L.append(["g", "Pieces: " + ", ".join(pn2), G])
		L.append(["g", "2 pieces: %s.   3 pieces: %s." % [String(gsd[2]), String(gsd[3])], W])
	L.append(["h", "MONSTER AFFIXES", Y])
	for ak in AFFIX_DEFS:
		var ad: Dictionary = AFFIX_DEFS[ak]
		L.append(["g", "%s: %s" % [String(ad["n"]), String(ad["d"])], ad["col"]])
	L.append(["h", "RELICS", Y])
	for rd in relic_defs:
		if not rd.has("adv"):
			continue
		L.append(["g", "%s%s: %s" % [_aname(String(rd["id"]), String(rd["name"])), "  (CURSED)" if rd.has("curse") else "", _atext(String(rd["id"]), String(rd["desc"]))], Color("ff8a7a") if rd.has("curse") else W])
	L.append(["s", "Relic synergies", B])
	for sy in synergies:
		if not bool(sy.get("adv", false)):
			continue
		var an := String(sy["a"])
		var bn := String(sy["b"])
		for rd2 in relic_defs:
			if String(rd2["id"]) == an:
				an = _aname(an, String(rd2["name"]))
			elif String(rd2["id"]) == bn:
				bn = _aname(bn, String(rd2["name"]))
		L.append(["g", "%s + %s: %s" % [an, bn, _atext("syn_%s_%s" % [String(sy["a"]), String(sy["b"])], String(sy["text"]))], W])
	L.append(["h", "TOOLS", Y])
	for uid in use_defs:
		var ud: Dictionary = use_defs[uid]
		L.append(["g", "%s: %s" % [_use_name(String(uid)), String(ud.get("desc", ""))], W])
	L.append(["h", "WORLD RULES", Y])
	for wk in WORLD_RULE_TEXT:
		L.append(["g", String(WORLD_RULE_TEXT[wk]), W])
	L.append(["h", "FLOOR EVENTS", Y])
	L.append(["p", "From floor 2, most floors hide one event (magenta dot on the minimap). A tag by the minimap names it. Events are optional.", W])
	for evk in EV_DEFS:
		var evd: Dictionary = EV_DEFS[evk]
		L.append(["g", "%s: %s" % [String(evd["n"]), String(evd["d"])], evd["col"]])
	L.append(["h", "SKILL WEB TIPS", Y])
	L.append(["p", "You get a skill point every 3 levels. Inner branches start at the centre; keystones (diamonds) cost 2 points and need a rank 2 node next to them. Outer hybrid branches sit between two inner branches, and apex nodes need both neighbouring outer keystones (3 points). Respec costs coins and refunds everything, including class nodes.", W])
	L.append_array(_ex_guide_lines())
	return L


func _mx_selftest() -> void:
	var bad := 0
	mode = "adv"
	var keep_x := mxp.duplicate()
	var keep_s := mspec.duplicate()
	var keep_b := msub.duplicate()
	var keep_c := cx.duplicate(true)
	save_off = false
	for d in class_defs:
		var cid := String(d["id"])
		mxp[cid] = _mx_base(25) + 10
		mspec[cid] = "b"
		msub[cid] = "2"
		cls = cid
		cp_dirty = true
		if mx_level(cid) != 25:
			print("FAIL level ", cid, " ", mx_level(cid))
			bad += 1
		for l in range(1, MX_MAX + 1):
			if _mx_rew_text(cid, l) == "":
				print("FAIL reward text ", cid, " ", l)
				bad += 1
		var p := _cls_pass()
		if float(p.get("hp", 0.0)) <= 0.0:
			print("FAIL passives ", cid, " ", p)
			bad += 1
		skills.clear()
		skill_pts = 999
		var bought := 0
		for pass_i in 6:
			for id in sk_defs:
				if sk_defs[id].has("cls") and String(sk_defs[id]["cls"]) == cid:
					_ck_lock_reason(String(id))
					while sk_can_buy(String(id)):
						sk_buy(String(id))
						bought += 1
		if bought != 6 * 2 + 4 * 2 + 1:
			print("FAIL class tree buys ", cid, " ", bought)
			bad += 1
		for id2 in skills:
			if sk_defs[id2].has("cls") and String(sk_defs[id2]["spec"]) == "a":
				print("FAIL bought other spec ", id2)
				bad += 1
		print("mx ", cid, " pass ", p, " pw ", _pw_lines(cid)[0], " sk(hp) ", sk("hp"))
	var pl := _cx_prog_lines()
	var gl := _cx_guide_lines()
	cx_tab = 1
	_cx_layout()
	print("codex progress lines %d guide lines %d height %d" % [pl.size(), gl.size(), int(cx_max)])
	if pl.size() < 20 or gl.size() < 100:
		bad += 1
	bad += _ex_selftest()
	skills.clear()
	mxp = keep_x
	mspec = keep_s
	msub = keep_b
	cx = keep_c
	save_off = true
	cp_dirty = true
	mode = "puzzle"
	cls = "scout"
	print("MX TEST DONE bad=%d" % bad)


# ===== B76: deed classes, threat levels, workshop + cores + contracts, the deep station =====

var hz_run := 0                 # threat level of the current run
var hz_max: Dictionary = {}     # class id -> highest threat unlocked
var hz_sel: Dictionary = {}     # class id -> threat picked on class select
var cores := 0                  # boss cores (second currency)
var ws: Dictionary = {}         # workshop research ranks
var ct: Array = []              # active contracts
var run_elites := 0
var run_bosses := 0
var run_cores := 0
var run_cts := 0
var pw_refund := 0
var an_key := -1
var an_cur: Array = []
var btn_work := Rect2(260, 1100, 200, 76)
var btn_hz_m := Rect2(150, 954, 80, 44)
var btn_hz_p := Rect2(490, 954, 80, 44)
var btn_ws_back := Rect2(160, 1184, 400, 70)

const CLS_BASE := {
	"engineer": {"drone": 100},
	"medic": {"medk": 50, "kheal": 3},
	"hacker": {"thack": 8},
	"salvager": {"dismantle": 1, "apprais": 25},
}
const NEW_BLURB := {
	"engineer": "Brings a drone to every fight",
	"medic": "Keeps everyone - mostly you - alive",
	"hacker": "Turns the station against itself",
	"salvager": "Nothing is junk, everything is money",
}
const NEW_PW := {
	"engineer": ["deals 150% of your attack", "reaches 3 tiles", "stuns for 2 steps and gives 6 shield"],
	"medic": ["heals 10% more", "also gives 8 shield", "also gives 20 air and recharges 25% faster"],
	"hacker": ["lasts 4 more steps", "also hacks every enemy turret in range", "takes a second enemy and recharges 25% faster"],
	"salvager": ["deals 250% and reaches 3 tiles", "salvaged enemies also give a random tool", "hits the 2 nearest enemies and recharges 25% faster"],
}
const DEEDS := {
	"engineer": ["Defeat 5 bosses in total", "bosses", 5],
	"medic": ["Clear 25 floors in total", "floors", 25],
	"hacker": ["Reach Mastery 10 with any class", "mx10", 1],
	"salvager": ["Find 40 different gear pieces", "gear", 40],
}
# Threat level modifiers, cumulative: [name, text, kind, value]
const HZ := [
	["Hardened", "Enemies +10% health", "hp", 10],
	["Vicious", "Enemies hit 1 harder", "atk", 1],
	["Thin Air", "Air drains 10% faster", "air", 10],
	["Hardened II", "Enemies +10% health", "hp", 10],
	["Warlords", "Bosses +25% health", "boss", 25],
	["Scarce Meds", "Healing -15%", "heal", 15],
	["Vicious II", "Enemies hit 1 harder", "atk", 1],
	["Inflation", "Shops +20% prices", "price", 20],
	["Thin Air II", "Air drains 10% faster", "air", 10],
	["Fragile", "-10% max health", "frag", 10],
	["Hardened III", "Enemies +15% health", "hp", 15],
	["Elite Guard", "Elites hit 2 harder", "elite", 2],
	["Scarce Meds II", "Healing -15%", "heal", 15],
	["Vicious III", "Enemies hit 2 harder", "atk", 2],
	["Warlords II", "Bosses +25% health", "boss", 25],
	["Thin Air III", "Air drains 15% faster", "air", 15],
	["Fragile II", "-10% max health", "frag", 10],
	["Hardened IV", "Enemies +15% health", "hp", 15],
	["Inflation II", "Shops +20% prices", "price", 20],
	["Nightmare", "Enemies +20% health and hit 1 harder", "night", 0],
]
# Workshop research: [id, name, text (%s = total), stat ("" = special), per rank, max, coin base, growth, cores per rank]
const WS_DEFS := [
	["w_hull", "Hull Plating", "+%s max health", "hp", 1, 40, 40, 1.12, 0],
	["w_o2", "O2 Reserves", "+%s max air", "air", 2, 40, 40, 1.12, 0],
	["w_train", "Field Training", "+%s%% XP", "xp", 3, 20, 60, 1.15, 0],
	["w_bank", "Salvage Rights", "+%s%% coins banked", "", 2, 25, 80, 1.12, 0],
	["w_crit", "Targeting AI", "+%s%% crit chance", "crit", 1, 10, 70, 1.15, 0],
	["w_dodge", "Evasion Drills", "+%s%% dodge chance", "dodge", 1, 10, 90, 1.18, 0],
	["w_deal", "Insider Deals", "Shops charge %s%% less", "haggle", 2, 10, 100, 1.2, 0],
	["w_mast", "Mastery Accelerator", "+%s%% mastery XP", "", 10, 10, 150, 1.25, 1],
	["w_atk", "Weapon Lab", "+%s attack", "atk", 1, 3, 200, 1.5, 2],
	["w_arm", "Armour Lab", "+%s armour", "armor", 1, 3, 250, 1.6, 3],
	["w_sp", "Neural Link", "+%s starting skill points", "", 1, 5, 300, 1.5, 3],
	["w_slot", "Pocket Dimension", "+%s tool slots", "slots", 1, 2, 500, 2.0, 8],
]
const AN_DEFS := {
	"rich": ["Rich Veins", "Coins are worth double"],
	"volatile": ["Volatile Hull", "Kills explode for 25% of the victim's max health to enemies next to it"],
	"market": ["Black Market", "Shops charge 30% less"],
	"lowg": ["Low Gravity", "Air drains 20% slower"],
	"surge": ["Power Surge", "Your class power recharges twice as fast"],
	"bounty": ["Bounty Night", "Every kill drops 1 + floor/10 coins"],
	"hunt": ["Elite Hunt", "Elites always drop gear"],
	"nanite": ["Nanite Cloud", "You heal 1 health every 4 steps"],
	"rad": ["Radiation", "Every 12 steps you take 2 + floor/5 damage unless your shield is up (it can't kill you)"],
	"frenzy": ["Blood Moon", "Enemies hit 2 harder, but kills give +50% XP"],
	"fog": ["Void Fog", "You see 1 tile less"],
	"decay": ["Hull Decay", "Air drains 25% faster"],
}
const AN_MILD := ["rich", "volatile", "market", "lowg", "surge", "bounty", "hunt", "nanite"]
const AN_HARSH := ["rad", "frenzy", "fog", "decay"]


func _cls_art(cid: String) -> String:
	return cid


func _gart(b: String) -> String:
	if gear_defs.has(b):
		return String(gear_defs[b].get("art", b))
	return b


# ----- deed classes -----

func _deed_prog(cid: String) -> Vector2i:
	var dd: Array = DEEDS[cid]
	var st: Dictionary = cx.get("st", {})
	var cur := 0
	match String(dd[1]):
		"bosses":
			cur = int(st.get("bosses", 0))
		"floors":
			cur = int(st.get("floors", 0))
		"gear":
			cur = (cx.get("gear", {}) as Dictionary).size()
		"mx10":
			for d in class_defs:
				if not DEEDS.has(String(d["id"])) and mx_level(String(d["id"])) >= 10:
					cur = 1
	return Vector2i(mini(cur, int(dd[2])), int(dd[2]))


func _deed_done(id: String) -> bool:
	if not DEEDS.has(id):
		return false
	var p := _deed_prog(id)
	return p.x >= p.y


func _lock_text(cid: String) -> String:
	if DEEDS.has(cid):
		var p := _deed_prog(cid)
		return "LOCKED. Deed: %s  (%d / %d)" % [String(DEEDS[cid][0]), p.x, p.y]
	return "LOCKED. Unlock this class in the SHOP."


func _lock_btn(cid: String) -> String:
	return "LOCKED - DO THE DEED" if DEEDS.has(cid) else "LOCKED - OPEN SHOP"


# ----- new class powers -----

func _act_engineer() -> bool:
	var p := _pw()
	var r := 2 + (1 if p >= 2 else 0) + int(sk("arcr"))
	var hit: Array = []
	for c in _near_mons(pos, r, []):
		if adv_vis.has(c):
			hit.append(c)
	if hit.is_empty():
		return _act_fail("No enemies within %d tiles" % r)
	var dmg := maxi(1, int(float(p_atk()) * ((1.5 if p >= 1 else 1.0) + sk("arcp") / 100.0)))
	var kills := 0
	for c in hit:
		if not mons.has(c):
			continue
		_fx_bolt(Vector2(pos), Vector2(c), Color("4fd1c5"))
		if _st_ok(c):
			_st_stun(c, 2 if p >= 3 else 1)
		if sk("arcburn") > 0.0:
			_st_burn(c, 3 + int(sk("kindle")), 2 + floor_n / 2)
		_adv_damage_mon(c, dmg, Color("4fd1c5"))
		if not mons.has(c):
			kills += 1
	if p >= 3:
		sh = mini(sh_cap(), sh + 6)
	pw_refund = kills * int(sk("arckill"))
	msg = "Arc Pulse hits %d enemies for %d" % [hit.size(), dmg]
	_pop(pos, "ARC PULSE", Color("4fd1c5"))
	_act_fx(Color("4fd1c5"))
	_sfx("elite")
	return true


func _act_medic() -> bool:
	var p := _pw()
	var pct := 30.0 + (10.0 if p >= 1 else 0.0) + sk("surg") + _ck_surg()
	_p_heal(maxi(1, int(float(hp_cap()) * pct / 100.0)))
	p_acid = 0
	p_frost = 0
	p_burn = 0
	var shg := int(sk("surgsh")) + (8 if p >= 2 else 0)
	if shg > 0:
		sh = mini(sh_cap(), sh + shg)
	var ag := sk("surgair") + (20.0 if p >= 3 else 0.0)
	if ag > 0.0:
		oxy = minf(oxy_max, oxy + ag)
	if sk("surgpsn") > 0.0:
		for c in _near_mons(pos, 3, []):
			if mons.has(c) and _st_ok(c):
				_st_poison(c, int(sk("surgpsn")))
	msg = "Field Surgery: healed %d%% and cleansed" % int(pct)
	_pop(pos, "SURGERY", Color("ff8a9a"))
	_act_fx(Color("ff8a9a"))
	_sfx("shield")
	return true


# ----- threat levels -----

func _hz_sum(kind: String) -> float:
	if mode != "adv" or hz_run <= 0:
		return 0.0
	var s := 0.0
	for i in mini(hz_run, HZ.size()):
		var h: Array = HZ[i]
		if String(h[2]) == kind:
			s += float(h[3])
		elif String(h[2]) == "night" and (kind == "hp" or kind == "atk"):
			s += 20.0 if kind == "hp" else 1.0
	return s


func _hz_hp(c: Vector2i) -> float:
	var m := 1.0 + _hz_sum("hp") / 100.0
	if _boss_cell(c):
		m *= 1.0 + _hz_sum("boss") / 100.0
		if floor_n > 20:
			m *= 1.5
	return m


func _hz_atk(c: Vector2i) -> int:
	return int(_hz_sum("atk")) + (int(_hz_sum("elite")) if elite.has(c) else 0) + (2 if _an("frenzy") else 0)


func _hz_air() -> float:
	return (1.0 + _hz_sum("air") / 100.0) * (0.8 if _an("lowg") else 1.0) * (1.25 if _an("decay") else 1.0)


func _hz_heal() -> float:
	return maxf(0.2, 1.0 - _hz_sum("heal") / 100.0)


func _hz_price() -> float:
	return (1.0 + _hz_sum("price") / 100.0) * (0.7 if _an("market") else 1.0)


func _hz_frag() -> float:
	return maxf(0.3, 1.0 - _hz_sum("frag") / 100.0)


func _hz_row(cid: String) -> void:
	if not class_open(cid) or mode != "adv":
		return
	var mx := int(hz_max.get(cid, 0))
	var cur := clampi(int(hz_sel.get(cid, 0)), 0, mx)
	var col := Color("ff6a5c") if cur > 0 else Color(1, 1, 1, 0.7)
	_button(btn_hz_m, "-", col if cur > 0 else Color(1, 1, 1, 0.25), 30)
	_button(btn_hz_p, "+", col if cur < mx else Color(1, 1, 1, 0.25), 30)
	_txt("THREAT %d / %d" % [cur, mx], Vector2(230, 972), 22, col, 260.0)
	var sub := "MAX THREAT" if mx >= HZ.size() else "Clear floor 5 at Threat %d to unlock %d" % [mx, mx + 1]
	if cur > 0:
		sub = "+%d%% coins  +%d%% mastery XP" % [15 * cur, 10 * cur]
	_txt(sub, Vector2(230, 994), 14, Color(1, 1, 1, 0.6), 260.0)


func _hz_tap(cid: String, up_: bool) -> void:
	if not class_open(cid):
		_sfx("blocked")
		return
	var mx := int(hz_max.get(cid, 0))
	var cur := clampi(int(hz_sel.get(cid, 0)), 0, mx)
	var nv := clampi(cur + (1 if up_ else -1), 0, mx)
	if nv == cur:
		_sfx("blocked")
		return
	hz_sel[cid] = nv
	_save_meta()
	_sfx("ui")


# ----- workshop, cores, contracts -----

func _ws(id: String) -> int:
	return int(ws.get(id, 0))


func _ws_cost(i: int) -> Vector2i:
	var d: Array = WS_DEFS[i]
	var r := _ws(String(d[0]))
	return Vector2i(int(round(float(d[6]) * pow(float(d[7]), r))), int(d[8]) * (r + 1))


func _ws_stats() -> Dictionary:
	var out := {}
	for d in WS_DEFS:
		var st := String(d[3])
		if st != "" and _ws(String(d[0])) > 0:
			out[st] = float(out.get(st, 0.0)) + float(d[4]) * float(mini(_ws(String(d[0])), int(d[5])))
	return out


func _ws_buy(i: int) -> void:
	var d: Array = WS_DEFS[i]
	var r := _ws(String(d[0]))
	var c := _ws_cost(i)
	if r >= int(d[5]) or bank < c.x or cores < c.y:
		_sfx("blocked")
		return
	bank -= c.x
	cores -= c.y
	ws[String(d[0])] = r + 1
	cp_dirty = true
	_save_meta()
	_sfx("big")


func _ex_mx_mult() -> float:
	return 1.0 + 0.1 * float(hz_run) + 0.1 * float(_ws("w_mast"))


func _ct_new(pri := false) -> Dictionary:
	var s := int((cx.get("st", {}) as Dictionary).get("contracts", 0))
	var kinds := ["kills", "elites", "floor", "bosses", "coins", "cls", "threat", "ghost", "level", "relics", "scrap", "skills", "tier"]
	var k := ""
	for tries in 16:
		k = String(kinds[randi() % kinds.size()])
		var dup := false
		for o in ct:
			if String(o["k"]) == k:
				dup = true
		if not dup:
			break
	var c := {"k": k, "r": mini(5, 1 + s / 4), "c": 30 + 10 * mini(s, 30), "n": 1}
	match k:
		"kills":
			c["n"] = mini(300, 40 + 10 * s)
		"elites":
			c["n"] = mini(30, 4 + s)
		"floor":
			c["n"] = mini(30, 6 + s / 2)
		"bosses":
			c["n"] = mini(6, 1 + s / 3)
		"coins":
			c["n"] = mini(600, 80 + 20 * s)
		"cls":
			var op: Array = []
			for d in class_defs:
				if class_open(String(d["id"])):
					op.append(String(d["id"]))
			c["cl"] = op[randi() % op.size()] if op.size() > 0 else "scout"
			c["n"] = mini(25, 5 + s / 3)
		"threat":
			c["n"] = mini(HZ.size(), 1 + s / 2)
			c["r"] = int(c["r"]) + 1
		"ghost":
			c["n"] = mini(6, 1 + s / 4)
		"level":
			c["n"] = mini(70, 12 + s)
		"relics":
			c["n"] = mini(14, 4 + s / 3)
		"scrap":
			c["n"] = mini(200, 20 + 5 * s)
		"skills":
			c["n"] = mini(20, 3 + s / 3)
		"tier":
			c["n"] = mini(7, 3 + s / 6)
	if pri:
		c["p"] = true
		if k != "tier" and k != "threat":
			c["n"] = int(ceil(float(c["n"]) * 1.5))
		c["r"] = int(c["r"]) * 3
		c["c"] = int(c["c"]) * 2
	return c


func _ct_fill() -> void:
	var has_p := false
	for o in ct:
		if bool(o.get("p", false)):
			has_p = true
	while ct.size() < CT_SLOTS:
		ct.append(_ct_new(not has_p))
		has_p = true


func _ct_text(c: Dictionary) -> String:
	var n := int(c.get("n", 1))
	match String(c.get("k", "")):
		"kills":
			return "Defeat %d enemies in one run" % n
		"elites":
			return "Defeat %d elites in one run" % n
		"floor":
			return "Clear floor %d" % n
		"bosses":
			return "Defeat %d bosses in one run" % n
		"coins":
			return "Hold %d coins at once in one run" % n
		"cls":
			return "Clear floor %d as the %s" % [n, _cls_name(String(c.get("cl", "scout")))]
		"threat":
			return "Clear floor 5 at Threat %d or higher" % n
		"ghost":
			return ("Clear a floor without being spotted" if n == 1 else "Clear %d floors unseen in one run" % n)
		"level":
			return "Reach level %d in one run" % n
		"relics":
			return "Hold %d relics at once" % n
		"scrap":
			return "Hold %d scrap at once" % n
		"skills":
			return "Spend %d skill points in one run" % n
		"tier":
			return "Wear a tier %d item" % n
	return "?"


func _ct_met(c: Dictionary, cleared: int) -> bool:
	var n := int(c.get("n", 1))
	match String(c.get("k", "")):
		"kills":
			return run_kills >= n
		"elites":
			return run_elites >= n
		"floor":
			return cleared >= n
		"bosses":
			return run_bosses >= n
		"coins":
			return coins >= n
		"cls":
			return cls == String(c.get("cl", "")) and cleared >= n
		"threat":
			return hz_run >= n and cleared >= 5
		"ghost":
			return run_ghost >= n
		"level":
			return level >= n
		"relics":
			var rn := 0
			for rid in relics:
				rn += int(relics[rid])
			return rn >= n
		"scrap":
			return scrap >= n
		"skills":
			return skill_spent() >= n
		"tier":
			for sl in equip:
				var gid := String(equip[sl])
				if gid != "" and gear_defs.has(gb(gid)) and int(gear_defs[gb(gid)]["tier"]) >= n:
					return true
	return false


func _ct_check(cleared: int) -> void:
	if not _mx_on() or not ul(6):
		return
	for i in range(ct.size() - 1, -1, -1):
		var c: Dictionary = ct[i]
		if _ct_met(c, cleared):
			cores += int(c["r"])
			bank += int(c["c"])
			run_cores += int(c["r"])
			run_cts += 1
			_cx_st("contracts", 1)
			_pop(pos, "CONTRACT DONE", Color("ff4fd8"))
			msg += "   Contract done: %s (+%d cores, +%d coins)" % [_ct_text(c), int(c["r"]), int(c["c"])]
			ct.remove_at(i)
	_ct_fill()


func _ws_rect(i: int) -> Rect2:
	return Rect2(40, 244 + i * 108, 640, 98)


func _draw_workshop(acc: Color) -> void:
	var pk := Color("ff4fd8")
	_txt("WORKSHOP", Vector2(0, 118), T_TITLE, pk)
	_cur_line(168.0)
	_txt("RESEARCH  -  PERMANENT, ALL CLASSES", Vector2(40, 226), T_SMALL, C_GOLD, 640.0, HORIZONTAL_ALIGNMENT_LEFT)
	lst_off = clampi(lst_off, 0, maxi(0, WS_DEFS.size() - 8))
	for vi in 8:
		var i := lst_off + vi
		if i >= WS_DEFS.size():
			break
		var d: Array = WS_DEFS[i]
		var r2 := _ws_rect(vi)
		var rk := _ws(String(d[0]))
		var mxr := int(d[5])
		var cst := _ws_cost(i)
		var maxed := rk >= mxr
		var can := not maxed and bank >= cst.x and cores >= cst.y
		var col := C_GOOD if can else (C_GOLD if maxed else Color(1, 1, 1, 0.45))
		_row_box(r2, col)
		_row_icon(String(d[0]), r2)
		_txt("%s  %d/%d" % [String(d[1]), rk, mxr], Vector2(r2.position.x + 100, r2.position.y + 38), 26, Color.WHITE, 360.0, HORIZONTAL_ALIGNMENT_LEFT)
		var now := String(d[2]) % _nfmt(float(d[4]) * float(rk))
		var per := String(d[2]) % _nfmt(float(d[4]))
		_txt("Now: " + now, Vector2(r2.position.x + 100, r2.position.y + 64), T_SMALL, Color(1, 1, 1, 0.75), 360.0, HORIZONTAL_ALIGNMENT_LEFT)
		_txt("Each rank: " + per, Vector2(r2.position.x + 100, r2.position.y + 86), T_SMALL, C_DIM, 360.0, HORIZONTAL_ALIGNMENT_LEFT)
		if maxed:
			_txt("MAXED", Vector2(r2.end.x - 170, r2.position.y + 58), 24, col, 156.0, HORIZONTAL_ALIGNMENT_RIGHT)
		else:
			var cy := r2.position.y + (40.0 if cst.y > 0 else 58.0)
			_txt("%d" % cst.x, Vector2(r2.end.x - 190, cy), 24, col, 140.0, HORIZONTAL_ALIGNMENT_RIGHT)
			_sym("coin", Vector2(r2.end.x - 30, cy - 8), 12.0, C_GOLD)
			if cst.y > 0:
				_txt("%d" % cst.y, Vector2(r2.end.x - 190, cy + 34), 24, pk if cores >= cst.y else Color(1, 1, 1, 0.45), 140.0, HORIZONTAL_ALIGNMENT_RIGHT)
				_sym("core", Vector2(r2.end.x - 30, cy + 26), 13.0, pk)
	_lst_bar(244.0, 8, WS_DEFS.size(), 108.0)
	_button(btn_ws_back, "BACK", acc, 28)

func _draw_contracts(acc: Color) -> void:
	var pk := Color("4fd1c5")
	var st: Dictionary = cx.get("st", {})
	_ct_fill()
	_txt("CONTRACT BOARD", Vector2(0, 118), T_TITLE, pk)
	_cur_line(168.0)
	_txt("%d CONTRACTS DONE" % int(st.get("contracts", 0)), Vector2(0, 216), T_SMALL, C_DIM)
	_txt("ACTIVE", Vector2(40, 270), T_SMALL, C_GOLD, 640.0, HORIZONTAL_ALIGNMENT_LEFT)
	for i in ct.size():
		var c: Dictionary = ct[i]
		var pri := bool(c.get("p", false))
		var r := _ct_rect(i)
		var col := C_GOLD if pri else pk
		_row_box(r, col, 0.12 if pri else 0.08)
		_row_icon("ct_" + String(c["k"]), r)
		if pri:
			_txt("PRIORITY", Vector2(r.position.x + 100, r.position.y + 24), T_SMALL, C_GOLD, 200.0, HORIZONTAL_ALIGNMENT_LEFT)
		_para_fit(_ct_text(c), Vector2(r.position.x + 100, r.position.y + (50 if pri else 40)), T_BODY, Color.WHITE, 400.0, 2)
		var ry := r.end.y - 18.0
		_sym("core", Vector2(r.position.x + 112, ry - 7), 11.0, Color("ff4fd8"))
		_txt("%d" % int(c["r"]), Vector2(r.position.x + 128, ry), T_BODY, Color("ff4fd8"), 80.0, HORIZONTAL_ALIGNMENT_LEFT)
		_sym("coin", Vector2(r.position.x + 202, ry - 7), 11.0, C_GOLD)
		_txt("%d" % int(c["c"]), Vector2(r.position.x + 218, ry), T_BODY, C_GOLD, 100.0, HORIZONTAL_ALIGNMENT_LEFT)
		_button(_ct_swap_rect(i), "SWAP %d" % CT_SWAP, C_INFO if bank >= CT_SWAP else Color(1, 1, 1, 0.35), 16)
	_para("Finish one and a harder one takes its place. Priority pays triple cores.", Vector2(60, 896), T_SMALL, C_DIM, 600.0)
	_button(btn_ws_back, "BACK", acc, 28)


func _ctb_input(p: Vector2) -> void:
	if btn_ws_back.has_point(p):
		state = PLAY if in_base else CLASS
		_sfx("ui")
		return
	for i in ct.size():
		if _ct_swap_rect(i).has_point(p):
			if bank < CT_SWAP:
				_sfx("blocked")
				return
			bank -= CT_SWAP
			var pri := bool(ct[i].get("p", false))
			ct.remove_at(i)
			ct.insert(i, _ct_new(pri))
			_save_meta()
			_sfx("coin")
			return



func _ws_input(p: Vector2) -> void:
	if btn_ws_back.has_point(p):
		state = PLAY if in_base else CLASS
		_sfx("ui")
		return
	for vi in 8:
		var i := lst_off + vi
		if i < WS_DEFS.size() and _ws_rect(vi).has_point(p):
			_ws_buy(i)
			return


# ----- the deep station: anomalies (floor 14+), ascended bosses (floor 21+) -----

func _an_list() -> Array:
	if mode != "adv" or floor_n < 14 or tutorial or testroom:
		return []
	var key := adv_seed + floor_n * 7919
	if key != an_key:
		an_key = key
		an_cur = []
		var r := RandomNumberGenerator.new()
		r.seed = key
		if floor_n >= 20:
			an_cur.append(String(AN_HARSH[r.randi() % AN_HARSH.size()]))
			an_cur.append(String(AN_MILD[r.randi() % AN_MILD.size()]))
		else:
			var all: Array = AN_MILD + AN_HARSH
			an_cur.append(String(all[r.randi() % all.size()]))
	return an_cur


func _an(id: String) -> bool:
	return _an_list().has(id)


func _an_coin() -> int:
	return 2 if _an("rich") else 1


func _an_sight() -> int:
	return 1 if _an("fog") else 0


func _an_xp() -> float:
	return 0.5 if _an("frenzy") else 0.0


func _an_step() -> void:
	if mode != "adv" or state != PLAY:
		return
	if _an("rad") and run_steps > 0 and run_steps % 12 == 0 and sh <= 0:
		var d := mini(2 + floor_n / 5, hp - 1)
		if d > 0:
			hp -= d
			_pop(pos, "RAD -%d" % d, Color("b6ff3c"))
	if _an("nanite") and run_steps % 4 == 0 and hp < hp_cap():
		hp += 1


func _an_announce() -> void:
	var al := _an_list()
	if al.is_empty():
		return
	var parts: PackedStringArray = []
	for a in al:
		parts.append("%s - %s" % [String(AN_DEFS[a][0]), String(AN_DEFS[a][1])])
	msg = ("ABYSS ANOMALY: " if floor_n >= 20 else "DEEP ANOMALY: ") + ".  ".join(parts)
	_pop(pos, String(AN_DEFS[al[0]][0]).to_upper(), Color("b6ff3c"))


# ----- hooks called from the mastery code -----

func _ex_init_run() -> void:
	ck_st = {}
	run_elites = 0
	run_bosses = 0
	run_cores = 0
	run_cts = 0
	run_ghost = 0
	pw_refund = 0
	hz_run = 0
	an_key = -1
	if not _mx_on():
		return
	hz_run = clampi(int(hz_sel.get(cls, 0)), 0, int(hz_max.get(cls, 0)))
	skill_pts += _ws("w_sp")
	_ct_fill()


func _ex_kill(nc: Vector2i, is_boss: bool) -> void:
	var el := elite.has(nc)
	if el:
		run_elites += 1
	if is_boss:
		run_bosses += 1
	if _mx_on():
		var cg := 0
		if is_boss:
			cg = 1 + hz_run / 5 + (1 if floor_n > 20 else 0)
		elif el and randf() < 0.03 + 0.005 * float(hz_run):
			cg = 1
		if cg > 0:
			cores += cg
			run_cores += cg
			_pop(nc, "+%d CORE" % cg, Color("ff4fd8"))
		if is_boss and floor_n > 20:
			var gid := _adv_roll_gear(null, 2)
			if _adv_give_gear(gid):
				msg += "  Ascended drop: " + gname(gid)
	var pct := sk("blast") + (25.0 if _an("volatile") else 0.0)
	if pct > 0.0 and tr_depth <= 2:
		var bd := maxi(1, int(float(mon_hp_max(nc)) * pct / 100.0))
		tr_depth += 1
		for o in _near_mons(nc, 1, []):
			if mons.has(o) and o != nc:
				_adv_damage_mon(o, bd, Color("ff9a3c"))
		tr_depth -= 1
		_fx_burst(Vector2(nc), Color("ff9a3c"), 14, 3.0, 0.5, 5.0)
	if _an("bounty"):
		coins += 1 + floor_n / 10


func _ex_hit_mul(c: Vector2i) -> float:
	var m := 0.0
	if sk("stundmg") > 0.0 and _stunned(c):
		m += sk("stundmg") / 100.0
	if cls == "__none__" and _mk(c):
		m += 0.15
	return m


func _ex_floor_clear() -> void:
	if not floor_spotted and not in_base:
		run_ghost += 1
		_pop(pos, "GHOST", Color("c07cff"))
		msg += "   Ghost: you cleared the floor unseen!"
	if floor_n >= 5 and hz_run >= int(hz_max.get(cls, 0)) and hz_run < HZ.size():
		hz_max[cls] = hz_run + 1
		_pop(pos, "THREAT %d UNLOCKED" % (hz_run + 1), Color("ff6a5c"))
		msg += "   Threat %d unlocked for the %s!" % [hz_run + 1, _cls_name(cls)]
	_ct_check(floor_n)


func _ex_death() -> void:
	_ct_check(floor_n - 1)


func _ex_death_line() -> String:
	var s := "\nCores +%d (total %d)" % [run_cores, cores]
	if run_cts > 0:
		s += "   Contracts done %d" % run_cts
	if hz_run > 0:
		s += "   Threat %d" % hz_run
	return s


func _ex_save(cfg: ConfigFile) -> void:
	cfg.set_value("mx", "cores", cores)
	cfg.set_value("mx", "ws", ws)
	cfg.set_value("mx", "ct", ct)
	cfg.set_value("mx", "hzmax", hz_max)
	cfg.set_value("mx", "hzsel", hz_sel)
	cfg.set_value("cos", "tr_own", tr_own)
	cfg.set_value("cos", "tr_eq", tr_eq)


func _ex_load(cfg: ConfigFile) -> void:
	cores = int(cfg.get_value("mx", "cores", 0))
	var tro = cfg.get_value("cos", "tr_own", {"none": true})
	if tro is Dictionary:
		tr_own = tro
	tr_own["none"] = true
	tr_eq = String(cfg.get_value("cos", "tr_eq", "none"))
	if not tr_own.has(tr_eq):
		tr_eq = "none"
	var a = cfg.get_value("mx", "ws", {})
	if a is Dictionary:
		ws = a
	var b = cfg.get_value("mx", "ct", [])
	if b is Array:
		ct = b
	var c = cfg.get_value("mx", "hzmax", {})
	if c is Dictionary:
		hz_max = c
	var d = cfg.get_value("mx", "hzsel", {})
	if d is Dictionary:
		hz_sel = d


func _ex_pack() -> Dictionary:
	return {"cores": cores, "ws": ws.duplicate(), "ct": ct.duplicate(true), "hzmax": hz_max.duplicate(), "hzsel": hz_sel.duplicate()}


func _ex_unpack(d) -> void:
	if not (d is Dictionary) or d.is_empty():
		return
	cores = maxi(cores, int(d.get("cores", 0)))
	var iw: Dictionary = d.get("ws", {})
	for k in iw:
		ws[k] = maxi(int(ws.get(k, 0)), int(iw[k]))
	var ih: Dictionary = d.get("hzmax", {})
	for k in ih:
		hz_max[k] = maxi(int(hz_max.get(k, 0)), int(ih[k]))
	var isel: Dictionary = d.get("hzsel", {})
	for k in isel:
		hz_sel[k] = int(isel[k])
	var ic: Array = d.get("ct", [])
	if not ic.is_empty():
		ct = ic.duplicate(true)


func _ex_wipe() -> void:
	cores = 0
	ws = {}
	ct = []
	hz_max = {}
	hz_sel = {}


# ----- codex pages -----

func _ex_prog_lines() -> Array:
	var L: Array = []
	var W := Color.WHITE
	var G := Color(1, 1, 1, 0.6)
	var Y := Color("ffd84f")
	var st: Dictionary = cx.get("st", {})
	L.append(["h", "THREAT, CORES AND CONTRACTS", Y])
	L.append(["p", "Boss cores: %d     Contracts done: %d" % [cores, int(st.get("contracts", 0))], W])
	for d in class_defs:
		var cid := String(d["id"])
		if class_open(cid):
			L.append(["g", "%s: highest Threat unlocked %d / %d" % [String(d["name"]), int(hz_max.get(cid, 0)), HZ.size()], d["col"]])
	L.append(["s", "Active contracts", W])
	for c in ct:
		L.append(["g", "%s  (+%d cores, +%d coins)" % [_ct_text(c), int(c["r"]), int(c["c"])], W])
	L.append(["h", "DEEDS", Y])
	for k in DEEDS:
		var p := _deed_prog(String(k))
		var done := p.x >= p.y
		L.append(["p", "%s %s - %s  (%d / %d)" % ["[x]" if done else "[  ]", _cls_name(String(k)), String(DEEDS[k][0]), p.x, p.y], Y if done else G])
	L.append(["h", "WORKSHOP", Y])
	var tr := 0
	var tm := 0
	for i in WS_DEFS.size():
		var d2: Array = WS_DEFS[i]
		tr += _ws(String(d2[0]))
		tm += int(d2[5])
		L.append(["g", "%s  %d / %d  -  now %s" % [String(d2[1]), _ws(String(d2[0])), int(d2[5]), String(d2[2]) % _nfmt(float(d2[4]) * float(_ws(String(d2[0]))))], W if _ws(String(d2[0])) > 0 else G])
	L.append(["p", "Research ranks: %d / %d" % [tr, tm], W])
	return L


func _ex_guide_lines() -> Array:
	var L: Array = []
	var W := Color.WHITE
	var G := Color(1, 1, 1, 0.62)
	var Y := Color("ffd84f")
	var B := Color("7fd8ff")
	L.append(["h", "THREAT LEVELS", Y])
	L.append(["p", "Pick a Threat level for each class on class select (the - / + row). Threat 0 is normal. Clear floor 5 at your highest Threat to unlock the next one, up to 20. Modifiers stack: Threat 7 has all of the first 7.", W])
	L.append(["p", "Each Threat level gives +15% coins banked and +10% mastery XP, and bosses drop an extra core for every 5 levels.", W])
	for i in HZ.size():
		L.append(["g", "%d  %s: %s" % [i + 1, String(HZ[i][0]), String(HZ[i][1])], Color("ff8a7a")])
	L.append(["h", "BOSS CORES AND THE WORKSHOP", Y])
	L.append(["p", "Bosses drop 1 core (+1 per 5 Threat, +1 past floor 20). Elites have a small chance to drop one. Contracts pay cores too. Spend coins and cores in the WORKSHOP (Station Base) on research that never runs out: every rank costs more than the last.", W])
	for d in WS_DEFS:
		var cc := ("  +%d cores per rank level" % int(d[8])) if int(d[8]) > 0 else ""
		L.append(["g", "%s: %s per rank, %d ranks, from %d coins%s" % [String(d[1]), String(d[2]) % _nfmt(float(d[4])), int(d[5]), int(d[6]), cc], W])
	L.append(["s", "Contracts", B])
	L.append(["p", "Three contracts are always open on the CONTRACTS board in the Station Base. They check when you clear a floor and when a run ends; finishing one pays cores and coins right away and a harder one replaces it.", W])
	L.append(["h", "STEALTH", Y])
	L.append(["p", "Sleeping, chatting and watching enemies haven't seen you. A '?' over one means it is getting suspicious: step out of its sight or it will spot you ('!'). Watchers see in a cone in front of them, chatting pairs only look at each other, and sleepers wake if you stand next to them for 2 steps.", W])
	L.append(["p", "Sneak attacks on enemies that haven't seen you deal +50% damage (double and a sure crit on sleepers), and they can't strike back. Killing one before it sees you is an unseen kill: +50% XP and no noise. A sneak attack that doesn't kill wakes the target and its chat partner.", W])
	L.append(["p", "Dark patches on the floor are shadows: enemy sight reaches 1 tile less while you stand in one. Brownout floors have more of them. O2 stations and merchants light up the tiles around them.", W])
	L.append(["g", "Sleep Dart, Smoke Bomb, Noise Maker, Cloak Patch and Shadow Cloak are stealth tools. A cloak hides you from sight and sound until it runs out or you attack.", W])
	L.append(["g", "Clear a floor without being spotted or hit for GHOST. The Ghost contract asks for several in one run.", W])
	L.append(["h", "CRITTERS", Y])
	L.append(["p", "Small creatures roam the floors and the Station Base. They never attack you. Walk into one to squash it. They all run from awake hunters, ragers and drones.", W])
	L.append(["g", "Cleaner Bot: sweeps up spikes and hazards as it rolls. Squash it for a coin or a scrap.", B])
	L.append(["g", "Rat: runs away from you and squeaks, which wakes sleepers within 2 tiles. Squashing it gives a coin, but it squeals and wakes sleepers within 2 tiles. A cloak keeps it silent.", Color("ffb0a0")])
	L.append(["g", "Moth: drawn to O2 stations and merchants. Squash it for a dust cloud that hides you for 3 steps.", Color("e8e0d0")])
	L.append(["g", "Wisp: drifts toward vaults. Pop it for +6 air.", Color("b6ff3c")])
	L.append(["h", "THE DEEP STATION", Y])
	L.append(["p", "From floor 14 every floor has a Deep Anomaly. From floor 20 the Abyss adds a harsh anomaly on top. Past floor 20 bosses are ASCENDED: +50% health, an extra core and a bonus high-tier gear drop.", W])
	L.append(["p", "Gear: tier 6 can drop from floor 19 and tier 7 from floor 26. Tier 6 and 7 weapons roll one extra trait and armour one extra mod.", W])
	for k in AN_DEFS:
		L.append(["g", "%s%s: %s" % [String(AN_DEFS[k][0]), "  (harsh)" if AN_HARSH.has(k) else "", String(AN_DEFS[k][1])], Color("ff8a7a") if AN_HARSH.has(k) else Color("b6ff3c")])
	L.append(["h", "DEED CLASSES", Y])
	L.append(["p", "Four classes can't be bought: they unlock when you complete their deed.", W])
	for k2 in DEEDS:
		L.append(["g", "%s - %s" % [_cls_name(String(k2)), String(DEEDS[k2][0])], _cls_col(String(k2))])
	return L


func _ex_selftest() -> int:
	var bad := 0
	mode = "adv"
	var kf := floor_n
	floor_n = 30
	var tiers := {}
	for i in 200:
		var gid := _adv_roll_gear(null, 1)
		if gname(gid) == "":
			bad += 1
		tiers[int(gear_defs[gb(gid)]["tier"])] = true
		_tier_col(int(gear_defs[gb(gid)]["tier"]))
	for d in gear_list:
		if int(d["tier"]) >= 6 and not gear_defs.has(_gart(String(d["id"]))):
			print("FAIL art alias ", d["id"])
			bad += 1
	hz_run = 20
	if _hz_sum("hp") <= 0.0 or _hz_heal() >= 1.0 or _hz_sum("atk") < 5.0:
		print("FAIL threat sums")
		bad += 1
	hz_run = 0
	adv_seed = 12345
	an_key = -1
	if _an_list().size() != 2:
		print("FAIL anomalies")
		bad += 1
	var kct := ct.duplicate(true)
	ct = []
	for i in 20:
		var c := _ct_new()
		if _ct_text(c) == "?":
			print("FAIL contract ", c)
			bad += 1
	ct = kct
	for i in WS_DEFS.size():
		_ws_cost(i)
	for k in DEEDS:
		_deed_prog(String(k))
	var a := _ex_prog_lines()
	var b := _ex_guide_lines()
	print("ex test: tiers %s anomalies %s prog %d guide %d" % [str(tiers.keys()), str(_an_list()), a.size(), b.size()])
	floor_n = kf
	an_key = -1
	return bad


# ===== B77: codex sections, rolled gear base stats =====

var cx_sec := -1                # -1 = section list, else the open section
var cx_secs: Array = []         # [title, colour, lines]
var cx_press := Vector2(-1, -1)
var cx_moved := false
var gs_cache: Dictionary = {}
var tp_cache: Dictionary = {}
# Extra stats a slot + tier can roll on top of what that tier's base items have.
# Format: {"armour": {3: {"hazres": [10, 30]}}}  (values are [min, max])
const GEAR_POOL_EXTRA := {}


func _cx_layout() -> void:
	var pm := mode
	mode = "adv"
	var lines: Array = _cx_prog_lines() if cx_tab == 0 else _cx_guide_lines()
	mode = pm
	cx_secs.clear()
	for ln in lines:
		if String(ln[0]) == "h" or cx_secs.is_empty():
			cx_secs.append([String(ln[1]) if String(ln[0]) == "h" else "GENERAL", ln[2], []])
			if String(ln[0]) == "h":
				continue
		(cx_secs[cx_secs.size() - 1][2] as Array).append(ln)
	cx_lay.clear()
	var y := 0.0
	if cx_sec < 0 or cx_sec >= cx_secs.size():
		cx_sec = -1
		y = float(cx_secs.size()) * 66.0 + 16.0
	else:
		var sec: Array = cx_secs[cx_sec]
		var th := font.get_multiline_string_size(String(sec[0]), HORIZONTAL_ALIGNMENT_LEFT, 640.0, 30).y
		cx_lay.append([0.0, 30, String(sec[0]), sec[1], th])
		y = th + 12.0
		for ln in sec[2]:
			var k := String(ln[0])
			var fs := 22 if k == "s" else (17 if k == "p" else 15)
			if k == "s":
				y += 8.0
			var h := font.get_multiline_string_size(String(ln[1]), HORIZONTAL_ALIGNMENT_LEFT, 640.0, fs).y
			cx_lay.append([y, fs, String(ln[1]), ln[2], h])
			y += h + 6.0
	cx_max = maxf(0.0, y - (CX_BOT - CX_TOP) + 40.0)
	cx_scroll = clampf(cx_scroll, 0.0, cx_max)


func _cx_draw_list() -> void:
	if cx_sec >= 0:
		return
	for i in cx_secs.size():
		var r := Rect2(40, CX_TOP + 8.0 + float(i) * 66.0 - cx_scroll, 640, 58)
		if r.end.y < CX_TOP or r.position.y > CX_BOT:
			continue
		var c: Color = cx_secs[i][1]
		_obox(r, Color(c.r, c.g, c.b, 0.10))
		_aline(r, Color(c.r, c.g, c.b, 0.7), 2.0)
		_txt(String(cx_secs[i][0]), Vector2(r.position.x + 20, r.position.y + 38), 24, c, 540.0, HORIZONTAL_ALIGNMENT_LEFT)
		_txt(">", Vector2(r.end.x - 50, r.position.y + 39), 28, c, 30.0)


func _cx_tap_list(p: Vector2) -> void:
	if cx_sec >= 0 or p.x < 40.0 or p.x > 680.0:
		return
	var fy := p.y - CX_TOP - 8.0 + cx_scroll
	var i := int(floor(fy / 66.0))
	if fy < 0.0 or fy - float(i) * 66.0 > 58.0 or i < 0 or i >= cx_secs.size():
		return
	cx_sec = i
	cx_scroll = 0.0
	_cx_layout()
	_sfx("ui")


func _cx_gui(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.position.y > CX_TOP and event.position.y < CX_BOT:
				cx_press = event.position
				cx_moved = false
				return true
			cx_press = Vector2(-1, -1)
			return false
		if cx_press.x >= 0.0:
			var pp := cx_press
			cx_press = Vector2(-1, -1)
			if not cx_moved:
				_cx_tap_list(pp)
			return true
		return false
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and cx_press.x >= 0.0:
		if event.position.distance_to(cx_press) > 12.0:
			cx_moved = true
		if cx_moved:
			cx_scroll = clampf(cx_scroll - event.relative.y, 0.0, cx_max)
		return true
	if event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		cx_scroll = clampf(cx_scroll + (80.0 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -80.0), 0.0, cx_max)
		return true
	return false


func _cx_input(p: Vector2) -> void:
	if btn_cx_back.has_point(p):
		if cx_sec >= 0:
			cx_sec = -1
			cx_scroll = 0.0
			_cx_layout()
		else:
			state = cx_ret
		_sfx("ui")
		return
	if btn_cx_t0.has_point(p) or btn_cx_t1.has_point(p):
		var nt := 0 if btn_cx_t0.has_point(p) else 1
		if nt != cx_tab or cx_sec >= 0:
			cx_tab = nt
			cx_sec = -1
			cx_scroll = 0.0
			_cx_layout()
		_sfx("ui")


# ----- rolled base stats: item id = base@traits_or_mods@stat=v,stat=v -----

func gstats(id: String) -> Dictionary:
	if gs_cache.has(id):
		return gs_cache[id]
	var out := {}
	if id.get_slice_count("@") >= 3:
		for p in id.get_slice("@", 2).split(","):
			if p.contains("="):
				out[p.get_slice("=", 0)] = int(p.get_slice("=", 1))
	if out.is_empty() and gear_defs.has(gb(id)):
		out = gear_defs[gb(id)]["stats"]
	gs_cache[id] = out
	return out


func _with_stats(nid: String, old: String) -> String:
	if old.get_slice_count("@") < 3:
		return nid
	return nid + ("@" if nid.contains("@") else "@@") + old.get_slice("@", 2)


# stat -> [min, max] over every base item of this slot and tier (+ GEAR_POOL_EXTRA)
func _tier_pool(slot: String, tier: int) -> Dictionary:
	var key := "%s_%d" % [slot, tier]
	if tp_cache.has(key):
		return tp_cache[key]
	var pool := {}
	for d in gear_list:
		if String(d["slot"]) != slot or int(d["tier"]) != tier:
			continue
		var st: Dictionary = d["stats"]
		for k in st:
			var v := int(st[k])
			if pool.has(k):
				pool[k] = [mini(int(pool[k][0]), v), maxi(int(pool[k][1]), v)]
			else:
				pool[k] = [v, v]
	var ex: Dictionary = GEAR_POOL_EXTRA.get(slot, {})
	var ext: Dictionary = ex.get(tier, {})
	for k2 in ext:
		pool[k2] = [int(ext[k2][0]), int(ext[k2][1])]
	tp_cache[key] = pool
	return pool


func _rv(pool: Dictionary, k: String, rng: RandomNumberGenerator) -> int:
	var lo := int(pool[k][0])
	var hi := int(pool[k][1])
	if lo == hi:
		lo = maxi(1, int(floor(float(lo) * 0.75)))
		hi = maxi(lo, int(ceil(float(hi) * 1.25)))
	return rng.randi_range(lo, hi) if rng != null else randi_range(lo, hi)


func _roll_base(rid: String, rng: RandomNumberGenerator) -> String:
	var b := gb(rid)
	if not gear_defs.has(b):
		return rid
	var gd: Dictionary = gear_defs[b]
	var pool := _tier_pool(String(gd["slot"]), int(gd["tier"]))
	var base: Dictionary = gd["stats"]
	var out := {}
	if base.has("atk"):
		out["atk"] = _rv(pool, "atk", rng)
	if base.has("range"):
		out["range"] = int(base["range"])
	var keys: Array = []
	for k in pool:
		if String(k) != "range" and not out.has(k):
			keys.append(String(k))
	for i in range(keys.size() - 1, 0, -1):
		var j := (rng.randi() if rng != null else randi()) % (i + 1)
		var tmp = keys[i]
		keys[i] = keys[j]
		keys[j] = tmp
	var n := maxi(1, base.size())
	while out.size() < n and keys.size() > 0:
		var k2 := String(keys.pop_back())
		out[k2] = _rv(pool, k2, rng)
	# b102: higher tiers hit harder, and gear found deeper rolls stronger attack/armour
	var tr_n := int(gd["tier"])
	var fmul := 1.0 + 0.05 * float(maxi(0, floor_n - 1))
	if out.has("atk") and ["weapon", "ranged", "trinket"].has(String(gd["slot"])):
		var tmul := 2.0 if tr_n >= 5 else (1.5 if tr_n >= 3 else 1.0)
		out["atk"] = maxi(1, int(round(float(out["atk"]) * tmul * fmul)))
	if out.has("armor"):
		out["armor"] = maxi(1, int(round(float(out["armor"]) * fmul)))
	var parts: PackedStringArray = []
	for k3 in out:
		parts.append("%s=%d" % [k3, int(out[k3])])
	return rid + ("@" if rid.contains("@") else "@@") + ",".join(parts)


var cx_ret := MODE
var btn_incx := Rect2(290, 40, 140, 64)


const BTN_UNLOCK := Rect2(365, 1196, 245, 64)
var ua_armed := -10.0


# Testing: unlock every shop item, master every class, open all threat levels and research, mark everything found.
func _unlock_all() -> void:
	for sd in shop_defs:
		ups[String(sd["id"])] = (sd["costs"] as Array).size()
	for d in class_defs:
		var cid := String(d["id"])
		mxp[cid] = maxi(int(mxp.get(cid, 0)), _mx_base(MX_MAX))
		if String(mspec.get(cid, "")) == "":
			mspec[cid] = "a"
		if String(msub.get(cid, "")) == "":
			msub[cid] = "1"
		hz_max[cid] = HZ.size()
	for wd in WS_DEFS:
		ws[String(wd[0])] = int(wd[5])
	cores += 100
	bank += 10000
	var st: Dictionary = cx.get("st", {})
	st["bosses"] = maxi(int(st.get("bosses", 0)), 5)
	st["floors"] = maxi(int(st.get("floors", 0)), 25)
	cx["st"] = st
	var gs: Dictionary = cx.get("gear", {})
	for gd in gear_list:
		gs[String(gd["id"])] = 1
	cx["gear"] = gs
	var ts: Dictionary = cx.get("tr", {})
	for k in TRAIT_DEFS:
		ts[String(k)] = 1
	cx["tr"] = ts
	var ms: Dictionary = cx.get("md", {})
	for k2 in MOD_DEFS:
		ms[String(k2)] = 1
	cx["md"] = ms
	var rs: Dictionary = cx.get("rl", {})
	for rd in relic_defs:
		rs[String(rd["id"])] = 1
	cx["rl"] = rs
	cp_dirty = true
	_save_meta()


# ----- B86: fresh class tree effects, Hijack and Strip Down -----
var ck_st: Dictionary = {}
var ck_src := Vector2i(-1, -1)
var ck_crit := false


func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _ck_foe(c: Vector2i) -> bool:
	return mons.has(c) and not (tur.has(c) and int(tur[c].get("hk", 0)) > 0) and not _turned(c)


func _turned(c: Vector2i) -> bool:
	return mstat.has(c) and int(mstat[c].get("tn", 0)) > 0


func _turned_n() -> int:
	var n := 0
	for c in mstat:
		if mons.has(c) and int(mstat[c].get("tn", 0)) > 0:
			n += 1
	return n


func _turned_near(c: Vector2i) -> bool:
	for o in mstat:
		if o != c and mons.has(o) and int(mstat[o].get("tn", 0)) > 0 and _cheb(o, c) <= 1:
			return true
	return false


func _ck_cut(n: int) -> void:
	ck_st["cdcut"] = int(ck_st.get("cdcut", 0)) + n


func _ck_hit_mul(c: Vector2i) -> float:
	if mode != "adv":
		return 0.0
	var m := 0.0
	ck_st["full"] = mon_hp_now(c) >= mon_hp_max(c)
	if not shooting and sk("c_haymaker") > 0.0:
		ck_st["mh"] = int(ck_st.get("mh", 0)) + 1
		if int(ck_st["mh"]) % 4 == 0:
			m += sk("c_haymaker") / 100.0
			ck_st["hay"] = true
			_pop(c, "HAYMAKER", Color("ff6a5c"))
	if sk("c_brace") > 0.0 and act_stance > 0:
		m += sk("c_brace") / 100.0
	if sk("c_rage") > 0.0 and int(ck_st.get("rage", 0)) > 0:
		m += sk("c_rage") / 100.0 * float(ck_st["rage"])
		ck_st["rage"] = 0
	if sk("c_dwish") > 0.0 and sh <= 0:
		m += sk("c_dwish") / 100.0
	if sk("c_rampage") > 0.0 and adv_steps <= int(ck_st.get("rpt", -1)):
		m += sk("c_rampage") / 100.0 * float(ck_st.get("rp", 0))
	if sk("c_blind") > 0.0 and _near_mons(c, 1, []).is_empty():
		m += sk("c_blind") / 100.0
	if sk("c_dancer") > 0.0:
		m += sk("c_dancer") / 100.0 * float(mini(5, int(ck_st.get("dodges", 0))))
	if sk("c_curse") > 0.0 and mstat.has(c) and mstat[c].has("cu"):
		m += sk("c_curse") / 100.0
	if sk("c_flux") > 0.0:
		m += sk("c_flux") / 100.0 * float(_elems(c).size())
	if sk("c_ddown") > 0.0:
		var r := randf() * 100.0
		if r < sk("c_ddown"):
			m += 1.0
			_pop(c, "DOUBLE!", Color("ffd84f"))
		elif r < sk("c_ddown") + 10.0:
			m -= 0.5
			_pop(c, "HALF", Color("9aa3c7"))
	if sk("c_stakes") > 0.0:
		m += sk("c_stakes") / 100.0 * float(mini(5, coins / 50))
	if sk("c_rigged") > 0.0 and bool(ck_st.get("lucky", false)):
		ck_st["lucky"] = false
		m += sk("c_rigged") - 1.0
		_pop(c, "RIGGED", Color("ffd84f"))
	if sk("c_sleight") > 0.0 and bool(ck_st.get("sl", false)):
		ck_st["sl"] = false
		m += sk("c_sleight") / 100.0
	if shooting:
		if sk("c_steady") > 0.0 and not p_moved:
			m += sk("c_steady") / 100.0
		if sk("c_qdraw") > 0.0 and not (mstat.has(c) and mstat[c].has("qd")):
			m += sk("c_qdraw") / 100.0
			if _st_ok(c):
				_st_get(c)["qd"] = true
		if sk("c_focus") > 0.0:
			if ck_st.get("ft", Vector2i(-99, -99)) == c:
				ck_st["fn"] = int(ck_st.get("fn", 0)) + 1
			else:
				ck_st["ft"] = c
				ck_st["fn"] = 0
			m += sk("c_focus") / 100.0 * float(mini(5, int(ck_st["fn"])))
		if sk("c_dmhand") > 0.0 and hp * 10 < hp_cap() * 3:
			m += sk("c_dmhand") / 100.0
	if sk("c_ovclk") > 0.0 and act_cd > 0:
		m += sk("c_ovclk") / 100.0
	if sk("c_vital") > 0.0 and hp >= hp_cap():
		m += sk("c_vital") / 100.0
	if sk("c_anat") > 0.0 and mstat.has(c) and mstat[c].has("bleed"):
		m += sk("c_anat") / 100.0
	if sk("c_exploit") > 0.0 and _turned_near(c):
		m += sk("c_exploit") / 100.0
	if sk("c_pawn") > 0.0:
		m += sk("c_pawn") / 100.0 * float(mini(20, scrap))
	return m


func _ck_on_hit(c: Vector2i, dealt: int, left: int, hexed: bool) -> int:
	if mode != "adv":
		return left
	ck_st["la"] = adv_steps
	var alive := left > 0 and mons.has(c)
	if bool(ck_st.get("hay", false)):
		ck_st["hay"] = false
		if alive:
			_st_stun(c, 1)
	if hexed:
		if mons.has(c) and _st_ok(c) and cls == "mystic":
			_st_get(c)["cu"] = true
		if sk("c_hexsh") > 0.0:
			sh = mini(sh_cap(), sh + int(sk("c_hexsh")))
		if sk("c_hexfire") > 0.0 and alive:
			_st_burn(c, int(sk("c_hexfire")), 2 + floor_n / 2)
		if sk("c_echohex") > 0.0 and randf() * 100.0 < sk("c_echohex"):
			hex_armed = true
			_pop(pos, "ECHO HEX", Color("c07cff"))
	if sk("c_ltap") > 0.0 and mstat.has(c) and mstat[c].has("cu"):
		_p_heal(int(sk("c_ltap")))
	if sk("c_pick") > 0.0 and randf() * 100.0 < sk("c_pick"):
		var pc := coin_val()
		coins += pc
		_pop(c, "+%d STOLEN" % pc, Color("ffd84f"))
	if not shooting:
		if sk("c_cleave") > 0.0 and tr_depth <= 1:
			for o in _near_mons(pos, 1, [c]):
				if _ck_foe(o):
					tr_depth += 1
					_adv_damage_mon(o, maxi(1, int(float(dealt) * sk("c_cleave") / 100.0)), Color("ff6a5c"))
					tr_depth -= 1
					break
		if sk("c_bthirst") > 0.0 and left <= 0:
			_tr_heal(maxi(1, int(float(dealt) * sk("c_bthirst") / 100.0)))
		if sk("c_pwhip") > 0.0 and _weapon_range() > 0 and ammo < ammo_max() and randf() * 100.0 < sk("c_pwhip"):
			ammo += 1
			_pop(pos, "+1 AMMO", Color("ffc24f"))
	else:
		ck_st["gs"] = adv_steps
		if sk("c_called") > 0.0 and alive and _cheb(c, pos) >= 4:
			_st_stun(c, int(sk("c_called")))
		if sk("c_hollow") > 0.0 and alive and _st_ok(c):
			_st_get(c)["bleed"] = [int(sk("c_hollow")), _bleed_dmg(c)]
		if sk("c_kshot") > 0.0 and alive and not _boss_cell(c) and float(left) * 100.0 <= float(mon_hp_max(c)) * sk("c_kshot"):
			left = 0
			alive = false
			_pop(c, "KILL SHOT", Color("ffc24f"))
		if sk("c_fan") > 0.0 and tr_depth <= 1:
			for o in _near_mons(c, 1, []):
				if _ck_foe(o):
					tr_depth += 1
					_adv_damage_mon(o, maxi(1, int(float(dealt) * sk("c_fan") / 100.0)), Color("ffc24f"))
					tr_depth -= 1
					break
		if sk("c_dmhand") > 0.0 and hp * 10 < hp_cap() * 3:
			ammo = mini(ammo_max(), ammo + 1)
		if left <= 0 and sk("c_reload") > 0.0 and randf() * 100.0 < sk("c_reload"):
			ammo = mini(ammo_max(), ammo + 1)
		if left <= 0 and sk("c_wanted") > 0.0:
			coins += int(sk("c_wanted"))
			_pop(c, "+%d BOUNTY" % int(sk("c_wanted")), Color("ffd84f"))
	if sk("c_incise") > 0.0 and alive and _st_ok(c) and left * 2 <= mon_hp_max(c):
		_st_get(c)["bleed"] = [int(sk("c_incise")), _bleed_dmg(c)]
	if sk("c_bheal") > 0.0 and mstat.has(c) and mstat[c].has("bleed"):
		_p_heal(int(sk("c_bheal")))
	if sk("c_tesla") > 0.0 and _stunned(c) and tr_depth <= 1:
		tr_depth += 1
		for o in _near_mons(c, 1, []):
			if _ck_foe(o):
				_fx_bolt(Vector2(c), Vector2(o), Color("9fe8ff"))
				_adv_damage_mon(o, int(sk("c_tesla")), Color("9fe8ff"))
		tr_depth -= 1
	if sk("c_feedback") > 0.0 and alive and _stunned(c) and randf() * 100.0 < sk("c_feedback"):
		mstat[c]["stun"] = int(mstat[c]["stun"]) + 1
	if sk("c_corrupt") > 0.0 and alive and not _boss_cell(c) and randf() * 100.0 < sk("c_corrupt"):
		for o in _near_mons(c, 1, []):
			if _ck_foe(o):
				_fx_bolt(Vector2(c), Vector2(o), Color("6dff9a"))
				_adv_damage_mon(o, mon_atk(c), Color("6dff9a"))
				_pop(c, "SCRAMBLED", Color("6dff9a"))
				break
	if sk("c_wild") > 0.0:
		ck_st["wild"] = int(ck_st.get("wild", 0)) + 1
		if int(ck_st["wild"]) % maxi(1, int(sk("c_wild"))) == 0:
			match randi() % 5:
				0:
					if alive:
						_st_burn(c, 3, 2 + floor_n / 2)
				1:
					if alive:
						_st_poison(c, 2)
				2:
					if alive:
						_st_stun(c, 1)
				3:
					coins += 3
					_pop(pos, "+3 COINS", Color("ffd84f"))
				_:
					sh = mini(sh_cap(), sh + 3)
			_pop(c, "WILD MAGIC", Color("ff5fd2"))
	if ck_crit and sk("c_ace") > 0.0 and randf() * 100.0 < sk("c_ace"):
		if _give_use(_random_use()):
			_pop(pos, "ACE!", Color("ffd84f"))
	return left


func _ck_kill(nc: Vector2i, is_boss: bool) -> void:
	if mode != "adv":
		return
	var vic := _near_mons(nc, 1, [])
	if sk("c_intim") > 0.0:
		for o in _near_mons(pos, 1, [nc]):
			_st_stun(o, int(sk("c_intim")))
	if sk("c_quake") > 0.0:
		for o in _near_mons(pos, 1, [nc]):
			if _ck_foe(o):
				_adv_damage_mon(o, maxi(1, int(float(p_atk()) * sk("c_quake") / 100.0)), Color("c9a36b"))
		_fx_ring(Vector2(pos), Color("c9a36b"), 1.4, 0.4, 5.0)
	if sk("c_rampage") > 0.0:
		if adv_steps > int(ck_st.get("rpt", -1)):
			ck_st["rp"] = 0
		ck_st["rp"] = mini(3, int(ck_st.get("rp", 0)) + 1)
		ck_st["rpt"] = adv_steps + 3
	if sk("c_harvest") > 0.0 and mstat.has(nc) and mstat[nc].has("cu"):
		_ck_cut(int(sk("c_harvest")))
	if sk("c_dice") > 0.0:
		ck_st["kc"] = int(ck_st.get("kc", 0)) + 1
		if int(ck_st["kc"]) % maxi(1, int(sk("c_dice"))) == 0:
			if _give_use(_random_use()):
				_pop(pos, "LOADED DICE", Color("ffd84f"))
			else:
				coins += 5
	if sk("c_bribe") > 0.0 and (elite.has(nc) or affix.has(nc)):
		coins += int(sk("c_bribe"))
		_pop(nc, "+%d BRIBE" % int(sk("c_bribe")), Color("ffd84f"))
	if sk("c_onehit") > 0.0 and bool(ck_st.get("full", false)):
		coins += int(sk("c_onehit"))
		_pop(nc, "+%d" % int(sk("c_onehit")), Color("ffd84f"))
	ck_st["full"] = false
	if sk("c_napalm") > 0.0 and mstat.has(nc) and mstat[nc].has("burn"):
		for o in vic:
			if _ck_foe(o):
				_st_burn(o, int(sk("c_napalm")), 2 + floor_n / 2)
	if sk("c_bsh") > 0.0 and vic.size() > 0:
		sh = mini(sh_cap(), sh + int(sk("c_bsh")) * vic.size())
	var was_st := _stunned(nc)
	if sk("c_overload") > 0.0 and was_st:
		var on := 0
		for o in _near_mons(nc, 2, []):
			if on >= int(sk("c_overload")):
				break
			if _ck_foe(o) and not _stunned(o):
				_st_stun(o, 1)
				on += 1
	if sk("c_lbomb") > 0.0 and was_st:
		for o in vic:
			if _ck_foe(o):
				_adv_damage_mon(o, maxi(1, int(float(p_atk()) * sk("c_lbomb") / 100.0)), Color("6dff9a"))
		_fx_burst(Vector2(nc), Color("6dff9a"), 14, 3.0, 0.5, 5.0)
	if sk("c_bbank") > 0.0:
		ck_st["bb"] = mini(int(sk("c_bbank")), int(ck_st.get("bb", 0)) + 1)
	if sk("c_scrapk") > 0.0 and randf() * 100.0 < sk("c_scrapk"):
		scrap += 1
		_pop(nc, "+1 SCRAP", Color("c9a36b"))


func _ck_dodged() -> void:
	ck_st["dodges"] = int(ck_st.get("dodges", 0)) + 1
	if sk("c_riposte") > 0.0 and mons.has(ck_src) and _cheb(ck_src, pos) <= 1:
		_adv_damage_mon(ck_src, maxi(1, int(float(p_atk()) * sk("c_riposte") / 100.0)), Color("9fe8ff"))
		_pop(ck_src, "RIPOSTE", Color("9fe8ff"))
	ck_src = Vector2i(-1, -1)


func _ck_hurt(a: int, src: Vector2i) -> int:
	if mode != "adv":
		return a
	if adv_steps < int(ck_st.get("inv", -1)):
		_pop(pos, "IMMUNE", Color("ff8a9a"))
		return 0
	if sk("c_afterimg") > 0.0 and oxy * 2.0 > oxy_max and randf() * 100.0 < sk("c_afterimg"):
		_pop(pos, "AFTERIMAGE", Color("9fe8ff"))
		ck_src = src
		_mx_dodged()
		return 0
	if sk("c_gsmoke") > 0.0 and int(ck_st.get("gs", -9)) >= adv_steps - 1 and randf() * 100.0 < sk("c_gsmoke"):
		_pop(pos, "GUNSMOKE", Color("c8c8c8"))
		return 0
	if sk("c_shrug") > 0.0 and randf() * 100.0 < sk("c_shrug"):
		a = 1
		_pop(pos, "SHRUG", Color("ff6a5c"))
	if sk("c_firm") > 0.0 and not p_moved:
		a = maxi(1, int(round(float(a) * (1.0 - sk("c_firm") / 100.0))))
	if sk("c_wither") > 0.0 and mstat.has(src) and mstat[src].has("cu"):
		a = maxi(1, int(round(float(a) * (1.0 - sk("c_wither") / 100.0))))
	if sk("c_fwall") > 0.0 and _turned_n() > 0:
		a = maxi(1, int(round(float(a) * (1.0 - sk("c_fwall") / 100.0))))
	if sk("c_swall") > 0.0 and scrap >= 10:
		a = maxi(1, a - int(sk("c_swall")))
	if sk("c_insure") > 0.0 and coins >= int(sk("c_insure")) and (hp - a) * 4 < hp_cap():
		coins -= int(sk("c_insure"))
		a = maxi(1, a / 2)
		_pop(pos, "INSURED", Color("ffd84f"))
	if sk("c_lifeline") > 0.0 and int(ck_st.get("lf", 0)) < int(sk("c_lifeline")) and dmg_taken(a) >= hp + sh:
		ck_st["lf"] = int(ck_st.get("lf", 0)) + 1
		_act_medic()
		_pop(pos, "LIFELINE", Color("ff8a9a"))
		return 0
	return a


func _ck_hurt_after(src: Vector2i, d: int, absorbed: int) -> void:
	if mode != "adv":
		return
	var lost := d - absorbed
	if sk("c_rage") > 0.0 and d > 0:
		ck_st["rage"] = mini(5, int(ck_st.get("rage", 0)) + 1)
	if sk("c_still") > 0.0 and not p_moved:
		sh = mini(sh_cap(), sh + int(sk("c_still")))
	if sk("c_sbreak") > 0.0 and absorbed > 0 and sh <= 0:
		for o in _near_mons(pos, 1, []):
			_st_stun(o, int(sk("c_sbreak")))
		_fx_ring(vis_pos, Color("7db2ff"), 1.4, 0.4, 5.0)
	if sk("c_adren") > 0.0 and hp > 0 and hp * 2 < hp_cap() and adv_steps - int(ck_st.get("ad", -99)) >= 5:
		ck_st["ad"] = adv_steps
		sh = mini(sh_cap(), sh + int(sk("c_adren")))
		_pop(pos, "ADRENALINE", Color("ff8a9a"))
	if sk("c_martyr") > 0.0 and hp * 10 < hp_cap() * 3 and act_cd > 0:
		act_cd = maxi(0, act_cd - int(sk("c_martyr")))
	if sk("c_spare") > 0.0 and hp > 0 and lost * 4 > hp_cap() and scrap > 0:
		scrap -= 1
		_tr_heal(int(sk("c_spare")))
	if sk("c_fward") > 0.0 and mons.has(src) and _st_ok(src) and randf() * 100.0 < sk("c_fward"):
		_st_get(src)["chill"] = true
		_st_stun(src, 1)
	if sk("c_scoat") > 0.0 and mons.has(src) and scrap >= 5:
		_adv_damage_mon(src, int(sk("c_scoat")) * mini(4, scrap / 5), Color("c9a36b"))


func _ck_blocked(src: Vector2i) -> void:
	if sk("c_ironwill") > 0.0 and act_cd > 0:
		act_cd = maxi(0, act_cd - int(sk("c_ironwill")))
	if sk("c_unstop") > 0.0 and hp * 2 < hp_cap():
		_tr_heal(int(sk("c_unstop")))


func _ck_power() -> void:
	if mode != "adv":
		return
	match cls:
		"scout":
			if sk("c_brair") > 0.0:
				oxy = minf(oxy_max, oxy + sk("c_brair"))
		"gambler":
			if sk("c_rigged") > 0.0:
				ck_st["lucky"] = true
		"engineer":
			var p := _pw()
			var r := 2 + (1 if p >= 2 else 0) + int(sk("arcr"))
			var n := 0
			for c in _near_mons(pos, r, []):
				if not _ck_foe(c):
					continue
				n += 1
				if sk("c_arcstun") > 0.0:
					_st_stun(c, (2 if p >= 3 else 1) + int(sk("c_arcstun")))
				if sk("c_deton") > 0.0 and mstat.has(c) and mstat[c].has("burn"):
					mstat[c].erase("burn")
					_pop(c, "DETONATE", Color("ff9a3c"))
					_fx_burst(Vector2(c), Color("ff9a3c"), 16, 3.4, 0.5, 5.0)
					_adv_damage_mon(c, maxi(1, int(float(p_atk()) * sk("c_deton") / 100.0)), Color("ff9a3c"))
			if sk("c_capsh") > 0.0 and n > 0:
				sh = mini(sh_cap(), sh + n * int(sk("c_capsh")))
		"medic":
			if sk("c_miracle") > 0.0:
				ck_st["inv"] = adv_steps + int(sk("c_miracle")) + 1
			if sk("c_retrib") > 0.0:
				for c in _near_mons(pos, 2, []):
					if _ck_foe(c):
						_fx_bolt(Vector2(pos), Vector2(c), Color("ff8a9a"))
						_adv_damage_mon(c, maxi(1, int(float(p_atk()) * sk("c_retrib") / 100.0)), Color("ff8a9a"))
			ck_st["bb"] = 0


func _ck_surg() -> float:
	var v := 0.0
	if sk("c_triage") > 0.0 and hp * 2 < hp_cap():
		v += sk("c_triage")
	if sk("c_bbank") > 0.0:
		v += 3.0 * float(ck_st.get("bb", 0))
	return v


func _ck_tool() -> void:
	if mode != "adv":
		return
	if sk("c_ctrick") > 0.0:
		var ts: Array = []
		for o in _near_mons(pos, 3, []):
			if _ck_foe(o):
				ts.append(o)
		if not ts.is_empty():
			var tc: Vector2i = ts[randi() % ts.size()]
			_fx_bolt(Vector2(pos), Vector2(tc), Color("ffd84f"))
			_adv_damage_mon(tc, maxi(1, int(float(p_atk()) * sk("c_ctrick") / 100.0)), Color("ffd84f"))
	if sk("c_sleight") > 0.0:
		ck_st["sl"] = true
	if sk("c_misdir") > 0.0:
		for o in _near_mons(pos, 1, []):
			_st_stun(o, int(sk("c_misdir")))
	if sk("c_qfing") > 0.0 and act_cd > 0:
		act_cd = maxi(0, act_cd - int(sk("c_qfing")))


func _ck_drone(dt: Vector2i, ddmg: int) -> void:
	if sk("c_dsh") > 0.0:
		sh = mini(sh_cap(), sh + int(sk("c_dsh")))
	if sk("c_hdrone") > 0.0 and mons.has(dt):
		_st_stun(dt, int(sk("c_hdrone")))
		_st_burn(dt, int(sk("c_hdrone")), 2 + floor_n / 2)
	if sk("c_dtwin") > 0.0:
		for o in _near_mons(pos, 3, [dt]):
			if _ck_foe(o):
				_fx_bolt(Vector2(pos) + Vector2(0, -0.4), Vector2(o), Color("4fd1c5"))
				_adv_damage_mon(o, maxi(1, int(float(ddmg) * sk("c_dtwin") / 100.0)), Color("4fd1c5"))
				break
	if not mons.has(dt):
		if sk("c_dscrap") > 0.0:
			scrap += int(sk("c_dscrap"))
			_pop(dt, "+%d SCRAP" % int(sk("c_dscrap")), Color("c9a36b"))
		if sk("c_drecall") > 0.0 and act_cd > 0:
			act_cd = maxi(0, act_cd - int(sk("c_drecall")))


func _ck_coin() -> void:
	if sk("c_dpock") > 0.0 and randf() * 100.0 < sk("c_dpock"):
		scrap += 1
		_pop(pos, "+1 SCRAP", Color("c9a36b"))


func _ck_step(moved: bool) -> void:
	if mode != "adv":
		return
	if int(ck_st.get("fl", -1)) != floor_n:
		ck_st["fl"] = floor_n
		ck_st["dodges"] = 0
		ck_st["lf"] = 0
		ck_st["w2"] = false
		if sk("c_scoutah") > 0.0:
			mom_steps += int(sk("c_scoutah"))
	var cut := int(ck_st.get("cdcut", 0))
	if cut > 0:
		ck_st["cdcut"] = 0
		act_cd = maxi(0, act_cd - cut)
	if moved and sk("c_fleet") > 0.0 and adv_steps % maxi(1, int(sk("c_fleet"))) == 0:
		oxy = minf(oxy_max, oxy + 1.0)
	var idle := adv_steps - int(ck_st.get("la", 0))
	if sk("c_runhigh") > 0.0 and idle >= 10 and idle % 10 == 0:
		_tr_heal(int(sk("c_runhigh")))
	if sk("c_2wind") > 0.0 and not bool(ck_st.get("w2", false)) and oxy * 4.0 < oxy_max:
		ck_st["w2"] = true
		oxy = minf(oxy_max, oxy + sk("c_2wind"))
		_pop(pos, "SECOND WIND", Color("7fd8ff"))
	if sk("c_saura") > 0.0 and adv_steps % 8 == 0:
		var sa: Array = []
		for o in _near_mons(pos, int(sk("c_saura")), []):
			if _ck_foe(o) and _st_ok(o):
				sa.append(o)
		if not sa.is_empty():
			var sc: Vector2i = sa[randi() % sa.size()]
			_fx_bolt(Vector2(pos), Vector2(sc), Color("9fe8ff"))
			_st_stun(sc, 1)
	if sk("c_band") > 0.0 and adv_steps % maxi(1, int(sk("c_band"))) == 0 and _weapon_range() > 0 and ammo < ammo_max():
		ammo += 1
		_pop(pos, "+1 AMMO", Color("ffc24f"))
	if sk("c_owatch") > 0.0 and adv_steps % 4 == 0 and ammo > 0 and _weapon_range() > 0:
		for oc in _near_mons(pos, 3, []):
			if _ck_foe(oc) and _mk(oc):
				ammo -= 1
				_fx_bolt(Vector2(pos), Vector2(oc), Color("ffc24f"))
				_pop(pos, "OVERWATCH", Color("ffc24f"))
				_adv_damage_mon(oc, maxi(1, int(float(p_atk()) * sk("c_owatch") / 100.0)), Color("ffc24f"))
				break
	if sk("c_gangel") > 0.0 and idle >= 2 and sh < mini(sh_cap(), int(sk("c_gangel"))):
		sh += 1
	if sk("c_recst") > 0.0 and moved and stations.has(pos) and act_cd > 0:
		act_cd = 0
		_pop(pos, "RECHARGED", Color("4fd1c5"))
	_ck_turned_tick()


# Hijacked enemies: count down, then attack (or walk toward) the nearest other enemy.
func _ck_turned_tick() -> void:
	var tl: Array = []
	for c in mstat:
		if mons.has(c) and int(mstat[c].get("tn", 0)) > 0:
			tl.append(c)
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for c0 in tl:
		var c: Vector2i = c0
		if not mons.has(c) or not mstat.has(c):
			continue
		var st: Dictionary = mstat[c]
		st["tn"] = int(st.get("tn", 0)) - 1
		if int(st["tn"]) <= 0:
			st.erase("tn")
			_pop(c, "FREE", Color("ff8a5b"))
			if sk("c_kswitch") > 0.0:
				_adv_damage_mon(c, maxi(1, int(float(mon_hp_max(c)) * sk("c_kswitch") / 100.0)), Color("6dff9a"))
			continue
		if sk("c_hjheal") > 0.0:
			mon_hp[c] = mini(mon_hp_max(c), mon_hp_now(c) + int(sk("c_hjheal")))
		var tg: Array = []
		for o in _near_mons(c, 1, []):
			if _ck_foe(o):
				tg.append(o)
		if tg.is_empty():
			var best_o := Vector2i(-1, -1)
			var bd := 99
			for o in _near_mons(c, 6, []):
				if _ck_foe(o) and _cheb(o, c) < bd:
					bd = _cheb(o, c)
					best_o = o
			if best_o.x < 0:
				continue
			var bn := c
			for dv in dirs:
				var n: Vector2i = c + dv
				if _aopen(n) and not mons.has(n) and not vaults.has(n) and n != pos and _cheb(n, best_o) < bd:
					bd = _cheb(n, best_o)
					bn = n
			if bn == c:
				continue
			_adv_move_mon(c, bn)
			c = bn
			for o in _near_mons(c, 1, []):
				if _ck_foe(o):
					tg.append(o)
			if tg.is_empty():
				continue
		var o2: Vector2i = tg[0]
		var dm := maxi(1, int(float(mon_atk(c)) * (1.0 + sk("c_hjdmg") / 100.0)))
		mon_lunge[c] = [t, Vector2(o2 - c).normalized()]
		_fx_bolt(Vector2(c), Vector2(o2), Color("6dff9a"))
		_adv_damage_mon(o2, dm, Color("6dff9a"))
		if mons.has(o2):
			if sk("c_hjstun") > 0.0:
				_st_stun(o2, int(sk("c_hjstun")))
		else:
			if sk("c_puppet") > 0.0 and act_cd > 0:
				act_cd = maxi(0, act_cd - int(sk("c_puppet")))
			if sk("c_dleech") > 0.0:
				sh = mini(sh_cap(), sh + int(sk("c_dleech")))
				_pop(pos, "+%d SHIELD" % int(sk("c_dleech")), Color("7db2ff"))


func _act_hacker() -> bool:
	var p := _pw()
	var r := 4 + int(sk("c_hjr"))
	var dur := 8 + (4 if p >= 1 else 0) + int(sk("c_hjlen"))
	var want := 1 + (1 if p >= 3 else 0) + int(sk("c_hjn"))
	var cands: Array = []
	for c in _near_mons(pos, r, []):
		if mons.has(c) and not tur.has(c) and not _boss_cell(c) and _st_ok(c):
			cands.append(c)
	cands.sort_custom(func(x, y): return mon_hp_now(x) > mon_hp_now(y))
	var got := 0
	for c0 in cands:
		if got >= want:
			break
		var c: Vector2i = c0
		if not mons.has(c):
			continue
		var st := _st_get(c)
		st["tn"] = dur
		st.erase("stun")
		got += 1
		_fx_bolt(Vector2(pos), Vector2(c), Color("6dff9a"))
		_fx_ring(Vector2(c), Color("6dff9a"), 1.2, 0.4, 5.0)
		_pop(c, "HIJACKED", Color("6dff9a"))
		var em := int(sk("c_hjemp"))
		if em > 0:
			for o in _near_mons(c, em, []):
				if _ck_foe(o):
					_st_stun(o, 1)
					if sk("c_bout") > 0.0:
						_adv_damage_mon(o, maxi(1, int(float(p_atk()) * sk("c_bout") / 100.0)), Color("6dff9a"))
	var hn := 0
	if p >= 2:
		var hk := 8 + int(sk("thack"))
		for c in tur.keys():
			if _cheb(c, pos) <= r and adv_vis.has(c) and int(tur[c].get("hk", 0)) <= 0:
				tur[c]["hk"] = hk
				_pop(c, "HACKED", Color("6dff9a"))
				hn += 1
	if got == 0 and hn == 0:
		return _act_fail("No enemy within %d tiles to hijack" % r)
	if sk("c_ghost") > 0.0:
		cloak_steps = maxi(cloak_steps, int(sk("c_ghost")))
	msg = "Hijack! %d enemy(ies) now fight for you for %d steps" % [got, dur]
	_pop(pos, "HIJACK", Color("6dff9a"))
	_act_fx(Color("6dff9a"))
	_sfx("elite")
	return true


func _act_salvager() -> bool:
	var p := _pw()
	var r := 2 + (1 if p >= 1 else 0) + int(sk("c_sdr"))
	var cands: Array = []
	for c in _near_mons(pos, r, []):
		if _ck_foe(c):
			cands.append(c)
	if cands.is_empty():
		return _act_fail("No enemy within %d tiles" % r)
	cands.sort_custom(func(x, y): return _cheb(x, pos) < _cheb(y, pos))
	var mult := 2.5 if p >= 1 else 2.0
	var total := 0
	var kills := 0
	for i in mini(2 if p >= 3 else 1, cands.size()):
		var c: Vector2i = cands[i]
		if not mons.has(c):
			continue
		var big := elite.has(c) or affix.has(c) or _boss_cell(c)
		var dmg := maxi(1, int(float(p_atk()) * (mult + (sk("c_pcheck") / 100.0 if big else 0.0))))
		_fx_bolt(Vector2(pos), Vector2(c), Color("c9a36b"))
		_fx_burst(Vector2(c), Color("c9a36b"), 14, 3.0, 0.5, 5.0)
		_adv_damage_mon(c, dmg, Color("c9a36b"))
		total += dmg
		if sk("c_wball") > 0.0:
			for o in _near_mons(c, 1, []):
				if _ck_foe(o):
					_adv_damage_mon(o, maxi(1, int(float(dmg) * sk("c_wball") / 100.0)), Color("c9a36b"))
		if not mons.has(c):
			kills += 1
			_ck_salvage(c, big, p)
	var shg := int(float(total) * sk("c_jplate") / 100.0) + int(sk("c_jshield"))
	if shg > 0:
		sh = mini(sh_cap(), sh + shg)
	msg = "Strip Down! %d damage" % total + ("  (%d salvaged)" % kills if kills > 0 else "")
	_pop(pos, "STRIP DOWN", Color("c9a36b"))
	_act_fx(Color("c9a36b"))
	_sfx("big")
	return true


func _ck_salvage(c: Vector2i, big: bool, p: int) -> void:
	scrap += 2 + int(sk("c_sdscrap"))
	var cv := (coin_val() * 2 + int(sk("c_sdcoin"))) * maxi(1, int(sk("c_grush")))
	coins += cv
	_pop(c, "SALVAGED +%d" % cv, Color("ffd84f"))
	var gch := 0.25 + sk("c_sdgear") / 100.0
	if big and sk("c_rhunt") > 0.0:
		gch = 1.0
	if randf() < gch and _adv_give_gear(_adv_roll_gear(null, 0)):
		_pop(pos, "GEAR!", Color("ffd84f"))
	if p >= 2 and _give_use(_random_use()):
		_pop(pos, "TOOL!", Color("4fd1c5"))
	if sk("c_sdref") > 0.0:
		_ck_cut(int(sk("c_sdref")))


# ===== B81: gradual unlocks (systems appear over the first runs; content stays open) =====

var runs_done := 0     # finished Adventure runs
var ul_all := 0        # settings: show every feature straight away
var ul_tapped := 0     # bit per step: its new button was tapped (clears the red dot)
const UL_STEPS := [
	["", ""],
	["RANGED WEAPONS", "Guns can drop now. Tap MELEE/RANGED to swap."],
	["SKILL WEB", "Levels give skill points. Tap SKILLS in a run."],
	["WEAPON TRAITS", "Weapons drop with random bonus traits."],
	["CLASS MASTERY", "Runs level your class. Tap MASTERY on class select."],
	["CURSED RELICS + ELITES", "Risky relics (you can skip) and tougher enemies."],
	["WORKSHOP + CONTRACTS", "Two new Station Base terminals: research with coins and cores, and a contract board."],
	["CODEX", "Everything you have found, on the main menu."],
	["THREAT LEVELS", "Raise the threat on class select for bigger rewards."],
	["WEAPON FUSION", "On an O2 station, open the BAG and FUSE a spare weapon into yours."],
]


func ul(step: int) -> bool:
	if ul_all == 1 or runs_done >= step:
		return true
	return step == 8 and int((cx.get("st", {}) as Dictionary).get("bosses", 0)) > 0


func _ul_tap(step: int) -> void:
	if ul_tapped & (1 << step) == 0:
		ul_tapped |= 1 << step
		_save_meta()


func _ul_dot(r: Rect2, step: int) -> void:
	if ul_all == 0 and ul_tapped & (1 << step) == 0:
		draw_circle(r.position + Vector2(r.size.x - 8, 8), 10.0, Color("ff5d5d"))


func _ul_run_end() -> String:
	if not _mx_on() or runs_done >= UL_STEPS.size() - 1:
		return ""
	runs_done += 1
	var s := ""
	var nw: Array = UL_STEPS[runs_done]
	s = "NEW! %s\n%s" % [nw[0], nw[1]]
	if runs_done < UL_STEPS.size() - 1 and ul_all == 0:
		s += "\nNext run unlocks: %s" % String(UL_STEPS[runs_done + 1][0])
	return s


func _ul_load(cfg: ConfigFile) -> void:
	ul_all = clampi(int(cfg.get_value("ul", "all", 0)), 0, 1)
	var r := int(cfg.get_value("ul", "runs", -1))
	if r < 0:
		# existing save from before B81: players with progress get everything open
		var st: Dictionary = cx.get("st", {})
		r = int(st.get("deaths", 0))
		if not mxp.is_empty() or cores > 0 or adv_best > 0:
			r = maxi(r, UL_STEPS.size() - 1)
		ul_tapped = (1 << UL_STEPS.size()) - 1 if r >= UL_STEPS.size() - 1 else 0
	else:
		ul_tapped = int(cfg.get_value("ul", "tap", 0))
	runs_done = r


func _ul_save(cfg: ConfigFile) -> void:
	cfg.set_value("ul", "runs", runs_done)
	cfg.set_value("ul", "all", ul_all)
	cfg.set_value("ul", "tap", ul_tapped)



# ---------------------------------------------------------------- B84: new relic packs (Adventure)
const NR_DEFS := [
	{"id": "nr_after", "name": "Afterimage", "desc": "Every 5th melee hit is repeated by a ghost copy for half damage", "max": 1, "adv": true},
	{"id": "nr_rewind", "name": "Rewind Coil", "desc": "Once per floor, a killing blow sends you back to where you stood 8 steps ago, with the health you had then", "max": 1, "adv": true},
	{"id": "nr_encore", "name": "Encore", "desc": "The first tool you use each floor is not used up", "max": 1, "adv": true},
	{"id": "nr_copycat", "name": "Copycat Lens", "desc": "The first elite you kill each floor lends you its power: +25% damage for the rest of the floor", "max": 1, "adv": true},
	{"id": "nr_patient", "name": "Patient Strike", "desc": "Your first hit on each enemy deals +50% damage (+100% on elites)", "max": 1, "adv": true},
	{"id": "nr_hitrun", "name": "Hit and Run", "desc": "After a kill, melee attacks can't hit you for your next 3 moves", "max": 1, "adv": true},
	{"id": "nr_metro", "name": "Metronome", "desc": "Alternate move, attack, move, attack: each beat adds +10% damage (max +50%). Breaking the rhythm resets it", "max": 1, "adv": true},
	{"id": "nr_grudge", "name": "Grudge Plate", "desc": "Each time an enemy hits you, you deal +10% damage to that enemy (stacks)", "max": 1, "adv": true},
	{"id": "nr_wager", "name": "Wager Chip", "desc": "Each floor you bet some coins. Clear the floor without taking damage to win 3x back", "max": 1, "adv": true},
	{"id": "nr_flip", "name": "Coin-Flip Armour", "desc": "Every hit you take is a coin flip: no damage, or double damage", "max": 1, "adv": true},
	{"id": "nr_double", "name": "Double or Nothing", "desc": "One relic card after each floor is two relics fused: take both, or something else", "max": 1, "adv": true},
	{"id": "nr_jackpot", "name": "Jackpot Counter", "desc": "Every 7th kill pays out coins and a random tool", "max": 1, "adv": true},
	{"id": "nr_leech", "name": "Leech Hook", "desc": "Each kill steals a stat until the floor ends: +1 attack, +3% crit or +3% dodge", "max": 1, "adv": true},
	{"id": "nr_thief", "name": "Trait Thief", "desc": "Elites with an affix have a 25% chance to drop gear with stronger traits", "max": 1, "adv": true},
	{"id": "nr_puppet", "name": "Puppet String", "desc": "The first enemy you hit each floor (not bosses) fights for you for 6 steps", "max": 1, "adv": true},
	{"id": "nr_hollow", "name": "Hollow Host", "desc": "Corpses become cover: enemy shots can't pass through them", "max": 1, "adv": true},
	{"id": "nr_hunger", "name": "Hunger Beacon", "desc": "About 30% more enemies, and every kill gives +1 coin and +25% XP", "max": 1, "adv": true},
	{"id": "nr_chain", "name": "Chain Reaction", "desc": "A kill within 2 steps of your last kill sends out a shockwave that hits nearby enemies", "max": 1, "adv": true},
	{"id": "nr_pack", "name": "Pack Leader", "desc": "+1 armour for each enemy next to you", "max": 1, "adv": true},
	{"id": "nr_laststd", "name": "Last Standing", "desc": "Killing the last enemy on a floor gives you a random relic", "max": 1, "adv": true},
	{"id": "nr_lung", "name": "Lung Bank", "desc": "Air left when you clear a floor is banked, and refills you when you drop under 20% air", "max": 1, "adv": true},
	{"id": "nr_lung2", "name": "Second Lung", "desc": "A 30-air reserve that only drains once your air is empty. Refills at O2 stations", "max": 1, "adv": true},
	{"id": "nr_thin", "name": "Thin Air", "desc": "Half max air, but every kill restores 20 air and gives +1 attack for the floor", "max": 1, "adv": true, "curse": true},
	{"id": "nr_bubble", "name": "Bubble Shield", "desc": "The first time you drop under 25% air each floor, gain a shield worth 20% of max health", "max": 1, "adv": true},
	{"id": "nr_quick", "name": "Quickdraw", "desc": "The first shot after swapping to ranged deals double damage", "max": 1, "adv": true},
	{"id": "nr_bayo", "name": "Bayonet", "desc": "The first melee hit after swapping to melee refunds 1 ammo", "max": 1, "adv": true},
	{"id": "nr_hot", "name": "Hot Barrel", "desc": "Every 3rd shot in a row sets the target on fire", "max": 1, "adv": true},
	{"id": "nr_brass", "name": "Brass Collector", "desc": "Shots have a 30% chance to give their ammo back", "max": 1, "adv": true},
	{"id": "nr_skel", "name": "Skeleton Swarm", "desc": "Each key you pick up has a 30% chance to spawn a bonus loot cache with gear nearby", "max": 1, "adv": true},
	{"id": "nr_tsense", "name": "Treasure Sense", "desc": "Vaults also contain a piece of gear, one rarity higher", "max": 1, "adv": true},
	{"id": "nr_bounty", "name": "Bounty Board", "desc": "Each floor names an enemy type. Kill all of them to get a random relic", "max": 1, "adv": true},
	{"id": "nr_overtime", "name": "Overtime", "desc": "Every kill after the exit is unlocked gives +3 coins", "max": 1, "adv": true},
	{"id": "nr_debt", "name": "Mark of Debt", "desc": "Coins are worth +50%, but you pay 50 coins every floor until you kill a boss", "max": 1, "adv": true, "curse": true},
	{"id": "nr_crown", "name": "Withered Crown", "desc": "+5 levels, but you lose 50 max health for every floor you leave with an enemy still alive", "max": 1, "adv": true, "curse": true},
	{"id": "nr_fragile", "name": "Fragile Time", "desc": "Enemies have half health, and so do you. 3 kills in a row without taking damage fully heal you (once per floor)", "max": 1, "adv": true, "curse": true},
	{"id": "nr_ledger", "name": "Soul Ledger", "desc": "Bosses give 2 random relics, but every relic you own makes enemies hit 2% harder", "max": 1, "adv": true, "curse": true},
	{"id": "nr_pit", "name": "Pit Stop", "desc": "Your first visit to each O2 station gives your weapon a random trait for that floor", "max": 1, "adv": true},
	{"id": "nr_relay", "name": "Relay Node", "desc": "Your warp beacon also refills your air like an O2 station", "max": 1, "adv": true},
	{"id": "nr_dmedic", "name": "Drone Medic", "desc": "A med drone heals you 5% of max health after every 3 kills", "max": 1, "adv": true},
	{"id": "nr_last", "name": "Last Stand", "desc": "Below 20% health you deal double damage and kills heal 10% of max health", "max": 1, "adv": true},
]
const NR_PACKS := {
	"p_echo": {"t": [], "r": ["nr_after", "nr_rewind", "nr_encore", "nr_copycat"]},
	"p_mom": {"t": [], "r": ["nr_patient", "nr_hitrun", "nr_metro", "nr_grudge"]},
	"p_gamb": {"t": [], "r": ["nr_wager", "nr_flip", "nr_double", "nr_jackpot"]},
	"p_para": {"t": [], "r": ["nr_leech", "nr_thief", "nr_puppet", "nr_hollow"]},
	"p_swarm": {"t": [], "r": ["nr_hunger", "nr_chain", "nr_pack", "nr_laststd"]},
	"p_oxy": {"t": [], "r": ["nr_lung", "nr_lung2", "nr_thin", "nr_bubble"]},
	"p_arse": {"t": [], "r": ["nr_quick", "nr_bayo", "nr_hot", "nr_brass"]},
	"p_vault": {"t": [], "r": ["nr_skel", "nr_tsense", "nr_bounty", "nr_overtime"]},
	"p_hex": {"t": [], "r": ["nr_debt", "nr_crown", "nr_fragile", "nr_ledger"]},
	"p_stat": {"t": [], "r": ["nr_pit", "nr_relay", "nr_dmedic", "nr_last"]},
}
const NR_SHOP := [
	{"id": "p_echo", "name": "Echo Pack", "desc": "4 relics that repeat, rewind and copy", "costs": [90]},
	{"id": "p_mom", "name": "Momentum Pack", "desc": "4 relics for timing, first strikes and grudges", "costs": [90]},
	{"id": "p_gamb", "name": "Gambit Pack", "desc": "4 relics that bet on your luck", "costs": [90]},
	{"id": "p_para", "name": "Parasite Pack", "desc": "4 relics that steal from enemies", "costs": [90]},
	{"id": "p_swarm", "name": "Swarm Pack", "desc": "4 relics: more enemies, more reward", "costs": [90]},
	{"id": "p_oxy", "name": "Oxygen Pack", "desc": "4 relics that turn air into a resource", "costs": [90]},
	{"id": "p_arse", "name": "Arsenal Pack", "desc": "4 relics for swapping melee and ranged", "costs": [90]},
	{"id": "p_vault", "name": "Vault Pack", "desc": "4 relics for keys, vaults and bounties", "costs": [90]},
	{"id": "p_hex", "name": "Hex Pack", "desc": "4 cursed relics with a way out", "costs": [110]},
	{"id": "p_stat", "name": "Station Pack", "desc": "4 relics for O2 stations, beacons and last stands", "costs": [90]},
]

var nr_m: Dictionary = {}          # Vector2i -> {"h": first hit done, "g": grudge stacks}
var nr_hits := 0
var nr_hr := 0
var nr_metro := 0
var nr_last := ""
var nr_copy := false
var nr_encore_used := false
var nr_rw_used := false
var nr_puppet_used := false
var nr_ls_done := false
var nr_wager := 0
var nr_wlost := false
var nr_kills := 0
var nr_l_atk := 0
var nr_l_crit := 0.0
var nr_l_dodge := 0.0
var nr_lk_step := -99
var nr_ktype := -1
var nr_btype := -1
var nr_bank := 0.0
var nr_lung2_v := 30.0
var nr_thin_atk := 0
var nr_bubble_used := false
var nr_qd := false
var nr_bay := false
var nr_shots := 0
var nr_debt_paid := false
var nr_frag_k := 0
var nr_frag_done := false
var nr_pit: Dictionary = {}
var nr_tmp_tr: Array = []


func _nr_setup() -> void:
	for d in NR_DEFS:
		relic_defs.append(d)
	for d2 in NR_SHOP:
		var dup := false
		for s in shop_defs:
			if s["id"] == d2["id"]:
				dup = true
		if not dup:
			shop_defs.append(d2)
	for k in NR_PACKS:
		if not ups.has(k):
			ups[k] = 0


func _nr_pack_of(id: String) -> String:
	for pk0 in NR_PACKS:
		if (NR_PACKS[pk0]["r"] as Array).has(id):
			return String(pk0)
	return ""


func _nr_md(c: Vector2i) -> Dictionary:
	if not nr_m.has(c):
		nr_m[c] = {}
	return nr_m[c]


func _nr_foes() -> int:
	var n := 0
	for c in mons:
		if _ck_foe(c):
			n += 1
	return n


func _nr_give_relic(why: String) -> void:
	for d in _roll_relics(0):
		if d.has("curse"):
			continue
		var id := String(d["id"])
		relics[id] = relic_n(id) + 1
		_adv_relic_applied(id)
		_pop(pos, String(d["name"]).to_upper(), Color("ffd84f"))
		msg += "   %s: you get %s!" % [why, String(d["name"])]
		_sfx("big")
		return


func _nr_free_near(c0: Vector2i) -> Vector2i:
	for r in range(1, 4):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var c := c0 + Vector2i(dx, dy)
				if c == pos or c == c0 or not _ain(c) or not _aopen(c):
					continue
				if mons.has(c) or items.has(c) or vaults.has(c) or coin_at.has(c) or spikes.has(c) or haz.has(c) or stations.has(c) or merchants.has(c) or meds.has(c) or tur.has(c) or c == stairs:
					continue
				return c
	return Vector2i(-1, -1)


# damage multiplier for one of your attacks
func _nr_dmg(c: Vector2i, dmg: int, ranged: bool) -> int:
	var m := 1.0
	if relic_n("nr_patient") > 0 and not _nr_md(c).has("h"):
		_nr_md(c)["h"] = true
		m += 1.0 if elite.has(c) else 0.5
		_pop(c, "FIRST STRIKE", Color("ffd27a"))
	if relic_n("nr_grudge") > 0 and nr_m.has(c):
		m += 0.1 * float(int(nr_m[c].get("g", 0)))
	if relic_n("nr_metro") > 0:
		nr_metro = 0 if nr_last == "a" else mini(5, nr_metro + 1)
		m += 0.1 * float(nr_metro)
	nr_last = "a"
	if nr_copy:
		m += 0.25
	if relic_n("nr_last") > 0 and hp * 5 < hp_cap():
		m += 1.0
	if ranged:
		nr_bay = false
		if nr_qd:
			nr_qd = false
			m += 1.0
			_pop(pos, "QUICKDRAW", Color("ffc24f"))
	else:
		nr_qd = false
		nr_shots = 0
		if nr_bay:
			nr_bay = false
			if ammo < ammo_max():
				ammo += 1
				_pop(pos, "+1 AMMO", Color("ffc24f"))
	if m == 1.0:
		return dmg
	return maxi(1, int(round(float(dmg) * m)))


func _nr_ghost(c: Vector2i, dmg: int) -> int:
	if relic_n("nr_after") <= 0 or dmg <= 0:
		return 0
	nr_hits += 1
	if nr_hits % 5 != 0:
		return 0
	var g := maxi(1, dmg / 2)
	_pop(c, "ECHO -%d" % g, Color("c8f1ff"))
	return g


# returns true when the enemy was turned into a puppet
func _nr_after_hit(c: Vector2i) -> bool:
	if relic_n("nr_puppet") <= 0 or nr_puppet_used or not mons.has(c) or tur.has(c) or (boss_floor and c == boss_cell):
		return false
	nr_puppet_used = true
	_st_get(c)["tn"] = 6
	_pop(c, "PUPPET", Color("6dff9a"))
	msg += "   Puppet String: it fights for you for 6 steps"
	return true


func _nr_shot(c: Vector2i, dmg: int) -> void:
	if relic_n("nr_hot") > 0:
		nr_shots += 1
		if nr_shots % 3 == 0 and mons.has(c):
			_st_burn(c, 3, maxi(1, dmg / 4))
			_pop(c, "HOT BARREL", Color("ff7a45"))
	if relic_n("nr_brass") > 0 and ammo < ammo_max() and randf() < 0.3:
		ammo += 1
		_pop(pos, "+1 AMMO", Color("ffc24f"))


func _nr_swap() -> void:
	if ranged_mode:
		nr_qd = relic_n("nr_quick") > 0
	else:
		nr_bay = relic_n("nr_bayo") > 0


func _nr_kill_pre(c: Vector2i) -> void:
	nr_ktype = -1 if tur.has(c) else int(mons.get(c, -1))


func _nr_kill(c: Vector2i, was_elite: bool, is_boss: bool, was_affix: bool) -> void:
	nr_kills += 1
	nr_m.erase(c)
	if relic_n("nr_hitrun") > 0:
		nr_hr = 3
	if relic_n("nr_leech") > 0:
		var r := randi() % 3
		if r == 0:
			nr_l_atk += 1
			_pop(pos, "+1 ATK", Color("ff5d8a"))
		elif r == 1:
			nr_l_crit += 3.0
			_pop(pos, "+3% CRIT", Color("ff5d8a"))
		else:
			nr_l_dodge += 3.0
			_pop(pos, "+3% DODGE", Color("ff5d8a"))
	if relic_n("nr_thief") > 0 and was_elite and was_affix and randf() < 0.25:
		var gid := _adv_roll_gear(null, 1)
		if _adv_give_gear(gid):
			msg += "   Trait Thief: " + gname(gid)
	if relic_n("nr_copycat") > 0 and was_elite and not nr_copy:
		nr_copy = true
		_pop(pos, "COPIED +25%", Color("c07cff"))
	if relic_n("nr_jackpot") > 0 and nr_kills % 7 == 0:
		var jc := 5 + floor_n
		coins += jc
		var jt := _random_use()
		_give_use(jt)
		_pop(c, "JACKPOT +%d" % jc, Color("ffd84f"))
		_sfx("coin")
	if relic_n("nr_hunger") > 0:
		coins += coin_val()
	if relic_n("nr_chain") > 0:
		if adv_steps - nr_lk_step <= 2:
			for o in _near_mons(c, 1, []):
				_adv_damage_mon(o, maxi(1, p_atk() / 2), Color("ffe14f"))
			_fx_ring(Vector2(c), Color("ffe14f"), 1.4, 0.4, 5.0)
			_pop(c, "CHAIN", Color("ffe14f"))
		nr_lk_step = adv_steps
	if relic_n("nr_thin") > 0:
		oxy = minf(oxy_max, oxy + 20.0)
		nr_thin_atk += 1
	if relic_n("nr_overtime") > 0 and adv_pts >= adv_req:
		coins += 3
		_pop(c, "+3 OVERTIME", Color("ffc93c"))
	if relic_n("nr_bounty") > 0 and nr_btype >= 0 and nr_ktype == nr_btype:
		var left := 0
		for m2 in mons:
			if not tur.has(m2) and int(mons[m2]) == nr_btype:
				left += 1
		if left == 0:
			nr_btype = -1
			_nr_give_relic("Bounty complete")
	if is_boss:
		nr_debt_paid = true
		if relic_n("nr_ledger") > 0:
			_nr_give_relic("Soul Ledger")
			_nr_give_relic("Soul Ledger")
	if relic_n("nr_fragile") > 0 and not nr_frag_done:
		nr_frag_k += 1
		if nr_frag_k >= 3:
			nr_frag_done = true
			hp = hp_cap()
			_pop(pos, "FULL HEAL", Color("6dff9a"))
	if relic_n("nr_dmedic") > 0 and nr_kills % 3 == 0:
		_p_heal(maxi(1, hp_cap() / 20))
		_pop(pos, "DRONE HEAL", Color("6dff9a"))
	if relic_n("nr_last") > 0 and hp * 5 < hp_cap():
		_p_heal(maxi(1, hp_cap() / 10))
	if relic_n("nr_laststd") > 0 and not nr_ls_done and _nr_foes() == 0:
		nr_ls_done = true
		_nr_give_relic("Last Standing")


func _nr_dodge(src: Vector2i) -> bool:
	if nr_hr <= 0 or src.x < 0 or not mons.has(src):
		return false
	_pop(pos, "UNTOUCHABLE", Color("9fe8ff"))
	msg += "   Hit and Run: you slip the attack"
	return true


func _nr_flip(a: int) -> int:
	if relic_n("nr_flip") <= 0 or a <= 0:
		return a
	if randf() < 0.5:
		_pop(pos, "FLIP: 0", Color("ffd84f"))
		return 0
	_pop(pos, "FLIP: x2", Color("ff6a5c"))
	return a * 2


func _nr_hurt(src: Vector2i, d: int) -> void:
	if d <= 0:
		return
	if relic_n("nr_grudge") > 0 and mons.has(src):
		_nr_md(src)["g"] = int(_nr_md(src).get("g", 0)) + 1
	if nr_wager > 0 and not nr_wlost:
		nr_wlost = true
		_pop(pos, "WAGER LOST", Color("ff6a5c"))
	nr_frag_k = 0


func _nr_rewind() -> bool:
	if relic_n("nr_rewind") <= 0 or nr_rw_used or rw_hist.is_empty():
		return false
	nr_rw_used = true
	var snap: Array = rw_hist[0]
	var rp: Vector2i = snap[0]
	if not mons.has(rp) and not vaults.has(rp):
		pos = rp
	hp = maxi(1, int(snap[1]))
	walk.clear()
	_fx_burst(vis_pos, Color("c07cff"), 16, 3.0, 0.5, 5.0)
	_pop(pos, "REWIND", Color("c07cff"))
	msg += "   Rewind Coil pulls you back in time!"
	_sfx("warp")
	_adv_update_vis()
	return true


func _nr_encore() -> bool:
	if relic_n("nr_encore") <= 0 or nr_encore_used:
		return false
	nr_encore_used = true
	_pop(pos, "ENCORE", Color("4fd1c5"))
	return true


func _nr_key() -> void:
	if relic_n("nr_skel") <= 0 or randf() >= 0.3:
		return
	var c := _nr_free_near(pick_c)
	if c.x < 0:
		return
	items[c] = "gear_" + _adv_roll_gear(null, 0)
	_pop(c, "LOOT CACHE", Color("ffd84f"))
	msg += "   Skeleton Swarm: a loot cache appears nearby"


func _nr_vault() -> void:
	if relic_n("nr_tsense") <= 0:
		return
	var gid := _adv_roll_gear(null, 1)
	if _adv_give_gear(gid):
		msg += " + " + gname(gid)


func _nr_step(moved: bool, attacked: bool) -> void:
	if in_base:
		oxy = oxy_max
	_ev_tick()
	if moved and not attacked:
		if nr_last == "m":
			nr_metro = 0
		nr_last = "m"
		if nr_hr > 0:
			nr_hr -= 1
	if moved and relic_n("nr_pit") > 0 and stations.has(pos) and not nr_pit.has(pos):
		nr_pit[pos] = true
		var pool: Array = []
		var have := wtr()
		for k in TRAIT_DEFS:
			if trait_open(String(k)) and not have.has(k):
				pool.append(k)
		if not pool.is_empty():
			var tid = pool[randi() % pool.size()]
			nr_tmp_tr.append(tid)
			_pop(pos, String(TRAIT_DEFS[tid]["n"]).to_upper(), Color("4fd1c5"))
			msg += "   Pit Stop: %s for this floor" % String(TRAIT_DEFS[tid]["n"])
	if moved and relic_n("nr_lung2") > 0 and stations.has(pos):
		nr_lung2_v = 30.0
	if moved and relic_n("nr_relay") > 0 and warp_bc.x >= 0 and pos == warp_bc and oxy < oxy_max - 0.5:
		oxy = oxy_max
		_pop(pos, "AIR FULL", Color("7fd8ff"))
	if relic_n("nr_lung2") > 0 and oxy < 0.0 and nr_lung2_v > 0.0:
		var take := minf(nr_lung2_v, -oxy + 1.0)
		nr_lung2_v -= take
		oxy += take
		_pop(pos, "SECOND LUNG", Color("7fd8ff"))
	if relic_n("nr_lung") > 0 and nr_bank > 0.0 and oxy < oxy_max * 0.2:
		var give := minf(nr_bank, oxy_max - oxy)
		nr_bank -= give
		oxy += give
		_pop(pos, "+%d AIR (BANK)" % int(give), Color("7fd8ff"))
	if relic_n("nr_bubble") > 0 and not nr_bubble_used and oxy < oxy_max * 0.25:
		nr_bubble_used = true
		var b := maxi(1, hp_cap() / 5)
		sh += b
		_pop(pos, "+%d BUBBLE" % b, Color("7db2ff"))


func _nr_init_run() -> void:
	nr_debt_paid = false
	nr_bank = 0.0
	nr_lung2_v = 30.0
	nr_kills = 0
	nr_hits = 0


func _nr_begin() -> void:
	nr_hr = 0
	nr_l_atk = 0
	nr_l_crit = 0.0
	nr_l_dodge = 0.0
	nr_copy = false
	nr_encore_used = false
	nr_rw_used = false
	nr_puppet_used = false
	nr_ls_done = false
	nr_frag_k = 0
	nr_frag_done = false
	nr_bubble_used = false
	nr_pit.clear()
	nr_tmp_tr.clear()
	nr_thin_atk = 0
	nr_metro = 0
	nr_last = ""
	nr_shots = 0
	nr_qd = false
	nr_bay = false
	nr_lk_step = -99
	nr_m.clear()
	nr_wager = 0
	nr_wlost = false
	nr_btype = -1
	o2_used.clear()
	if mode != "adv" or tutorial:
		return
	if relic_n("nr_wager") > 0 and coins > 0:
		nr_wager = mini(coins, 10 + 2 * floor_n)
		coins -= nr_wager
		msg += "   Wager Chip: %d coins bet" % nr_wager
	if relic_n("nr_bounty") > 0 and not arena:
		var types: Array = []
		for c in mons:
			if not tur.has(c) and not (boss_floor and c == boss_cell) and not types.has(int(mons[c])):
				types.append(int(mons[c]))
		if not types.is_empty():
			nr_btype = int(types[randi() % types.size()])
			var names: Array = cur_theme()["mons"]
			msg += "   Bounty: kill every %s" % String(names[(nr_btype - 1) % names.size()])


func _nr_clear() -> void:
	if nr_wager > 0:
		if nr_wlost:
			over_sub += "\nWager lost (%d coins)" % nr_wager
		else:
			coins += nr_wager * 3
			over_sub += "\nWager won! +%d coins" % (nr_wager * 3)
		nr_wager = 0
	if relic_n("nr_lung") > 0 and oxy > 0.0:
		nr_bank = minf(adv_oxy_max(), nr_bank + oxy)
	if relic_n("nr_debt") > 0 and not nr_debt_paid:
		var lose := mini(coins, 50)
		coins -= lose
		over_sub += "\nMark of Debt: -%d coins" % lose
	if relic_n("nr_crown") > 0 and _nr_foes() > 0:
		hp_max = maxi(1, hp_max - 50)
		hp = mini(hp, hp_cap())
		over_sub += "\nWithered Crown: -50 max health"
	if relic_n("nr_double") > 0 and relic_choices.size() >= 2:
		var used: Array = []
		for d0 in relic_choices:
			used.append(String(d0["id"]))
		var pair: Array = []
		for d in _roll_relics(2):
			if not d.has("curse") and not used.has(String(d["id"])) and pair.size() < 2:
				pair.append(d)
		if pair.size() == 2:
			relic_choices[relic_choices.size() - 1] = {"id": String(pair[0]["id"]), "name": "%s + %s" % [pair[0]["name"], pair[1]["name"]], "desc": "DOUBLE: take both.  %s.  %s" % [pair[0]["desc"], pair[1]["desc"]], "max": 1, "pair": [String(pair[0]["id"]), String(pair[1]["id"])]}



# ---------------------------------------------------------------- B84: O2 station limit
var o2_used: Dictionary = {}   # Vector2i -> refills used this floor


func o2_cap() -> int:
	if arena or tutorial:
		return 999
	return maxi(3, 11 - floor_n)


func _o2_left(c: Vector2i) -> int:
	return o2_cap() - int(o2_used.get(c, 0))


# ---------------------------------------------------------------- B84: weapon fusion (unlock step 9)
const FUSE_MAX := 5


func _fuse_rect(k: int) -> Rect2:
	return Rect2(416, 666 + chr_off + _inv_y(k) + 54, 124, 38)


# a spare weapon in the pack can be fused into the equipped weapon of the same slot
func _fuse_ok(k: int) -> bool:
	if mode != "adv" or not ul(9) or not stations.has(pos) or k < 0 or k >= bag.size():
		return false
	var bid := String(bag[k])
	var slot := String(gear_defs[gb(bid)]["slot"])
	if slot != "weapon" and slot != "ranged":
		return false
	var eid := String(equip.get(slot, ""))
	if eid == "":
		return false
	var et := gtr(eid)
	if et.size() >= FUSE_MAX:
		return false
	for tid in gtr(bid):
		if not et.has(tid):
			return true
	return false


func _fuse(k: int) -> void:
	var bid := String(bag[k])
	var slot := String(gear_defs[gb(bid)]["slot"])
	var eid := String(equip[slot])
	var et: Array = gtr(eid)
	var pool: Array = []
	for tid in gtr(bid):
		if not et.has(tid):
			pool.append(tid)
	var got = pool[randi() % pool.size()]
	var keep: Array = []
	for tid2 in et:
		keep.append(String(tid2))
	keep.append(String(got))
	for mid in gmods(eid):
		keep.append(String(mid))
	var nid := gb(eid) + "@" + ",".join(keep)
	equip[slot] = nid
	bag.remove_at(k)
	chr_sel = -1
	_pop(pos, "FUSED: " + String(TRAIT_DEFS[got]["n"]).to_upper(), Color("c07cff"))
	msg = "Fusion! Your %s gained %s" % [gname(nid), String(TRAIT_DEFS[got]["n"])]
	_sfx("big")


# ---------------------------------------------------------------- B84: floor events (one per floor from floor 2)
const EV_DEFS := {
	"distress": {"n": "Distress Beacon", "d": "Answer it: 2 hunters ambush you. Kill both within 20 steps for gear and coins", "col": Color("ff6a5c"), "g": "!"},
	"reactor": {"n": "Unstable Reactor", "d": "Reach it before the countdown ends for XP and shield, or it blows up", "col": Color("ffb347"), "g": "R"},
	"lab": {"n": "Sealed Lab", "d": "Break in for 15% of your health: 2 tools and XP inside", "col": Color("6dff9a"), "g": "L"},
	"crew": {"n": "Trapped Crew", "d": "Free them and an elite guard wakes up. Kill it for a relic", "col": Color("7fd8ff"), "g": "C"},
	"drone": {"n": "Black Market Drone", "d": "Sells one random relic for coins", "col": Color("c07cff"), "g": "$"},
	"supply": {"n": "Supply Beacon", "d": "Call in a drop: medkit, air and ammo land here 10 steps later", "col": Color("ffc24f"), "g": "S"},
	"purge": {"n": "Purge Console", "d": "Clears every spike and hazard on the floor, but every enemy charges you", "col": Color("e8f4ff"), "g": "P"},
	"training": {"n": "Training Terminal", "d": "Kill 3 enemies within 25 steps for a skill point", "col": Color("ffd84f"), "g": "T"},
	"idol": {"n": "Cursed Idol", "d": "+1 level now, but enemies on this floor get 25% more health", "col": Color("ff5d8a"), "g": "I"},
	"datacore": {"n": "Data Core", "d": "Download a full level of XP, but 3 hunters come for you", "col": Color("4fd1c5"), "g": "D"},
	"medbay": {"n": "Med Bay Overload", "d": "Full health and shield, but every O2 station on the floor drops to 1 use", "col": Color("ff8a9a"), "g": "+"},
}
var ev_id := ""
var ev_c := Vector2i(-1, -1)
var ev_run := ""       # active timed event
var ev_end := 0        # adv_steps deadline
var ev_k0 := 0
var ev_idol := false


func _ev_free(c: Vector2i) -> bool:
	return _ain(c) and _aopen(c) and c != pos and c != stairs and not mons.has(c) and not items.has(c) and not vaults.has(c) and not coin_at.has(c) and not spikes.has(c) and not haz.has(c) and not stations.has(c) and not merchants.has(c) and not meds.has(c) and not tur.has(c)


func _ev_far_cell(mind: int) -> Vector2i:
	for i in 300:
		var c := Vector2i(randi() % AW, randi() % AH)
		if _ev_free(c) and _cheb(c, pos) >= mind:
			return c
	return Vector2i(-1, -1)


func _ev_spawn(c: Vector2i, el: bool) -> void:
	if c.x < 0:
		return
	mons[c] = _adv_scaled(2 if el else 1)
	kinds[c] = "hunter"
	if el:
		elite[c] = true
	_nr_md(c)["ev"] = true
	_fx_ring(Vector2(c), Color("ff6a5c"), 1.2, 0.4, 5.0)


func _ev_left() -> int:
	var n := 0
	for c in nr_m:
		if mons.has(c) and bool(nr_m[c].get("ev", false)):
			n += 1
	return n


func _ev_begin() -> void:
	ev_id = ""
	ev_c = Vector2i(-1, -1)
	ev_run = ""
	ev_idol = false
	if mode != "adv" or tutorial or testroom or in_base or arena or boss_floor or floor_n < 2 or randf() > 0.75:
		return
	var c := _ev_far_cell(8)
	if c.x < 0:
		return
	var keys0: Array = EV_DEFS.keys()
	ev_id = String(keys0[randi() % keys0.size()])
	ev_c = c
	items[c] = "ev_" + ev_id
	adv_seen[_ai(c)] = 1
	var d: Dictionary = EV_DEFS[ev_id]
	msg += "   EVENT: %s - %s" % [d["n"], d["d"]]
	if ev_id == "reactor":
		ev_run = "reactor"
		ev_end = adv_steps + _cheb(c, pos) * 2 + 25
	_adv_mini_update()


func _ev_touch(c: Vector2i, kind: String) -> void:
	var id := kind.substr(3)
	var d: Dictionary = EV_DEFS.get(id, {"n": "Event"})
	var nm := String(d["n"])
	match id:
		"distress":
			_ev_spawn(_nr_free_near(c), false)
			_ev_spawn(_nr_free_near(c), false)
			ev_run = "distress"
			ev_end = adv_steps + 20
			msg = "%s: it's an ambush! Kill both within 20 steps" % nm
		"reactor":
			if ev_run == "reactor":
				ev_run = ""
				_adv_gain_xp(maxi(5, xp_need() / 2))
				sh += 10
				coins += 5 + floor_n
				msg = "Reactor vented! +XP, +10 shield, +%d coins" % (5 + floor_n)
			else:
				msg = "The reactor is already cold"
		"lab":
			var cost := maxi(1, int(hp_cap() * 0.15))
			if hp <= cost + 1:
				items[c] = kind
				msg = "%s: you need %d health to break in" % [nm, cost]
				return
			hp -= cost
			_give_use(_random_use())
			_give_use(_random_use())
			_adv_gain_xp(maxi(4, xp_need() / 3))
			msg = "%s: -%d health, 2 tools and XP" % [nm, cost]
		"crew":
			_ev_spawn(_nr_free_near(c), true)
			ev_run = "crew"
			ev_end = adv_steps + 9999
			msg = "%s freed! Their elite guard wakes up - kill it for a relic" % nm
		"drone":
			var price := 25 + 5 * floor_n
			if coins < price:
				items[c] = kind
				msg = "%s: a relic for %d coins (you have %d)" % [nm, price, coins]
				return
			coins -= price
			_nr_give_relic(nm)
		"supply":
			ev_run = "supply"
			ev_end = adv_steps + 10
			msg = "%s: drop incoming in 10 steps" % nm
		"purge":
			spikes.clear()
			haz.clear()
			for m in mons:
				if not tur.has(m) and not (boss_floor and m == boss_cell):
					kinds[m] = "rager"
			msg = "%s: hazards cleared - every enemy is coming for you!" % nm
			_sfx("aggro")
		"training":
			ev_run = "training"
			ev_end = adv_steps + 25
			ev_k0 = run_kills
			msg = "%s: kill 3 enemies within 25 steps" % nm
		"idol":
			_adv_level_up(1)
			ev_idol = true
			msg = "%s: +1 level, enemies are tougher this floor" % nm
		"datacore":
			_adv_gain_xp(xp_need())
			for i in 3:
				_ev_spawn(_ev_far_cell(7), false)
			msg = "%s downloaded! 3 hunters are on their way" % nm
		"medbay":
			hp = hp_cap()
			sh = maxi(sh, sh_cap())
			for st in stations:
				o2_used[st] = maxi(int(o2_used.get(st, 0)), o2_cap() - 1)
			msg = "%s: fully healed, O2 stations drop to 1 use" % nm
	_pop(c, nm.to_upper(), d.get("col", Color.WHITE))
	_sfx("big")


func _ev_tick() -> void:
	if ev_run == "" or mode != "adv":
		return
	var left := ev_end - adv_steps
	match ev_run:
		"reactor":
			if left <= 0:
				ev_run = ""
				items.erase(ev_c)
				_fx_ring(Vector2(ev_c), Color("ffb347"), 3.0, 0.6, 8.0)
				_shake(8.0, 0.4)
				_adv_env_hurt(maxi(1, hp_cap() / 4), "The reactor blows! You lose %d health", "Caught in a reactor blast")
			elif left <= 10 or left % 5 == 0:
				_pop(pos, "REACTOR %d" % left, Color("ffb347"))
		"distress", "crew":
			if _ev_left() == 0:
				var was := ev_run
				ev_run = ""
				if was == "crew":
					_nr_give_relic("Crew rescued")
				else:
					var gid := _adv_roll_gear(null, 1)
					_adv_give_gear(gid)
					coins += 8 + floor_n
					msg += "   Ambush beaten! +%d coins and %s" % [8 + floor_n, gname(gid)]
					_pop(pos, "AMBUSH BEATEN", Color("6dff9a"))
			elif left <= 0:
				ev_run = ""
				_pop(pos, "TOO SLOW", Color("ff8a8a"))
			elif ev_run == "distress" and (left <= 5 or left % 5 == 0):
				_pop(pos, "AMBUSH %d" % left, Color("ff6a5c"))
		"supply":
			if left <= 0:
				ev_run = ""
				for k in ["hp", "pod", "ammocrate"]:
					var sc := _nr_free_near(ev_c)
					if sc.x >= 0:
						items[sc] = k
				_fx_ring(Vector2(ev_c), Color("ffc24f"), 2.0, 0.5, 6.0)
				msg += "   Supply drop has landed!"
		"training":
			if run_kills - ev_k0 >= 3:
				ev_run = ""
				skill_pts += 1
				_pop(pos, "+1 SKILL POINT", Color("ffd84f"))
				msg += "   Training complete: +1 skill point"
			elif left <= 0:
				ev_run = ""
				_pop(pos, "TRAINING FAILED", Color("ff8a8a"))
			elif left <= 5 or left % 5 == 0:
				_pop(pos, "TRAINING %d/3  %d" % [run_kills - ev_k0, left], Color("ffd84f"))


func _ev_draw(ctr: Vector2, kind: String, bob: float) -> void:
	var d: Dictionary = EV_DEFS.get(kind.substr(3), {})
	var col: Color = d.get("col", Color.WHITE)
	var k := 0.5 + 0.5 * sin(t * 4.0)
	var p := ctr + Vector2(0, bob)
	draw_circle(p, AC * 0.36, Color(col.r, col.g, col.b, 0.18 + 0.12 * k))
	_spr(spr_gen.icon(kind), p, AC * 0.85)

# ===== B85: Station Base hub (walk into rooms; START begins the run) =====

# id, label, unlock step, colour, glyph, terminal cell
var bs_lbls: Array = []

const BS_ROOMS := [
	["start", "START", 0, Color("6dff9a"), ">", Vector2i(7, 1)],
	["shop", "OUTFITTER", 0, Color("ffc93c"), "$", Vector2i(6, 12)],
	["puzzle", "PUZZLE", 0, Color("9fb3d9"), "#", Vector2i(6, 10)],
	["mastery", "MASTERY", 4, Color("ffd84f"), "M", Vector2i(9, 12)],
	["workshop", "WORKSHOP", 6, Color("ff4fd8"), "W", Vector2i(6, 8)],
	["codex", "CODEX", 7, Color("c9a2ff"), "C", Vector2i(9, 10)],
	["thr_m", "THREAT -", 8, Color("ff6a5c"), "-", Vector2i(6, 6)],
	["thr_p", "THREAT +", 8, Color("ff6a5c"), "+", Vector2i(9, 6)],
	["contracts", "CONTRACTS", 6, Color("4fd1c5"), "!", Vector2i(9, 8)],
	["deep", "DEEP STATION", 0, Color("7a5cff"), "D", Vector2i(6, 4)],
	["style", "STYLE", 0, Color("ff8ad0"), "S", Vector2i(9, 4)],
]

# ===== B110: cosmetics - kill effects (picked at the STYLE terminal) and base decor (unlocks on milestones) =====
# id, name, unlock kind ("" free / "runs" / "best" floor / "boss" kills), amount
const KILL_FX := [
	["none", "Standard", "", 0],
	["pixel", "Pixel Pop", "runs", 2],
	["confetti", "Confetti", "runs", 5],
	["ember", "Ember Rise", "best", 8],
	["frost", "Frost Shatter", "best", 12],
	["gold", "Gold Rush", "boss", 3],
	["bolt", "Thunder Strike", "boss", 8],
	["void", "Void Implosion", "best", 21],
]
# id, name, unlock kind, amount, wall cell beside the corridor
const DECOR := [
	["plant", "Potted Plant", "runs", 1, Vector2i(6, 13)],
	["crates", "Cargo Crates", "runs", 3, Vector2i(9, 13)],
	["poster", "Recruit Poster", "runs", 6, Vector2i(6, 11)],
	["lamp", "Lava Lamp", "best", 6, Vector2i(9, 11)],
	["trophy", "Boss Trophy", "boss", 1, Vector2i(6, 9)],
	["tank", "Aquarium", "best", 10, Vector2i(9, 9)],
	["arcade", "Arcade Cabinet", "runs", 12, Vector2i(6, 7)],
	["bot", "Pet Bot", "boss", 5, Vector2i(9, 7)],
	["crystal", "Deep Crystal", "best", 15, Vector2i(6, 5)],
	["banner", "Abyss Banner", "best", 21, Vector2i(9, 5)],
]
var cos_kill := "none"


func _cos_bosses() -> int:
	return int((cx.get("st", {}) as Dictionary).get("bosses", 0))


func _cos_open(kind: String, n: int) -> bool:
	if ul_all == 1 or kind == "":
		return true
	match kind:
		"runs": return runs_done >= n
		"best": return adv_best >= n
		"boss": return _cos_bosses() >= n
	return false


func _cos_need(kind: String, n: int) -> String:
	match kind:
		"runs": return "finish %d runs" % n
		"best": return "reach floor %d" % n
		"boss": return "beat %d bosses" % n
	return ""


func _style_tap() -> void:
	var open: Array = []
	for d in KILL_FX:
		if _cos_open(String(d[2]), int(d[3])):
			open.append(String(d[0]))
	var i := open.find(cos_kill)
	cos_kill = String(open[(i + 1) % open.size()])
	_save_meta()
	var nm := ""
	for d in KILL_FX:
		if String(d[0]) == cos_kill:
			nm = String(d[1])
	var nd := 0
	for d in DECOR:
		if _cos_open(String(d[2]), int(d[3])):
			nd += 1
	msg = "KILL EFFECT: %s (%d / %d unlocked). Base decor %d / %d." % [nm, open.size(), KILL_FX.size(), nd, DECOR.size()]
	for d in KILL_FX + DECOR:
		if not _cos_open(String(d[2]), int(d[3])):
			msg += "  Next: %s - %s." % [String(d[1]), _cos_need(String(d[2]), int(d[3]))]
			break
	_pop(pos, nm.to_upper(), Color("ff8ad0"))


func _cos_kill_fx(cf: Vector2, body: Color) -> void:
	match cos_kill:
		"pixel":
			for i in 14:
				var a := randf() * TAU
				_fx_spark(cf, Vector2(cos(a), sin(a)) * (2.0 + randf() * 3.0), [Color("4fd1ff"), Color.WHITE, body][i % 3], 0.6, 9.0, 5.0)
		"confetti":
			for i in 26:
				var a := -PI / 2.0 + (randf() - 0.5) * 2.2
				_fx_spark(cf, Vector2(cos(a), sin(a)) * (3.0 + randf() * 3.5), Color.from_hsv(randf(), 0.75, 1.0), 1.1, 5.0, 1.6)
		"ember":
			for i in 18:
				_fx_spark(cf + Vector2(randf() - 0.5, 0.2) * 0.6, Vector2((randf() - 0.5) * 0.8, -1.5 - randf() * 2.0), Color("ff7b2e").lerp(Color("ffd84f"), randf()), 1.0, 5.0, 0.6)
		"frost":
			_fx_ring(cf, Color("9fe8ff"), 1.1, 0.5, 6.0)
			_fx_burst(cf, Color("dff8ff"), 20, 4.0, 0.8, 6.0)
		"gold":
			_fx_burst(cf, Color("ffd84f"), 22, 3.6, 0.9, 7.0)
			_fx_ring(cf, Color("ffe98a"), 0.8, 0.4, 3.0)
		"bolt":
			_fx_bolt(cf + Vector2(0.3, -3.5), cf, Color("bfe6ff"))
			_fx_ring(cf, Color("bfe6ff"), 1.0, 0.35, 5.0)
			_shake(4.0, 0.2)
		"void":
			_fx_ring(cf, Color("8a6cff"), 1.6, 0.5, 6.0)
			_fx_ring(cf, Color("2a1060"), 0.5, 0.5, 9.0, 0.15)
			for i in 16:
				var a := randf() * TAU
				_fx_spark(cf + Vector2(cos(a), sin(a)) * 1.2, -Vector2(cos(a), sin(a)) * 2.6, Color("b49cff"), 0.45, 5.0, 0.0)


func _dc_draw(c: Vector2i, ctr: Vector2) -> void:
	for d in DECOR:
		if d[4] != c or not _cos_open(String(d[2]), int(d[3])):
			continue
		var s := AC
		var id := String(d[0])
		var fl := ctr + Vector2(0, s * 0.36)   # floor line of the alcove
		draw_rect(Rect2(ctr - Vector2(s, s) * 0.42, Vector2(s, s) * 0.84), Color(0.03, 0.04, 0.08, 0.55))
		match id:
			"plant":
				draw_rect(Rect2(fl + Vector2(-s * 0.14, -s * 0.2), Vector2(s * 0.28, s * 0.2)), Color("b0643a"))
				for k in 5:
					var a := -PI / 2.0 + (k - 2) * 0.42 + sin(t * 1.3 + k) * 0.05
					draw_line(fl + Vector2(0, -s * 0.2), fl + Vector2(0, -s * 0.2) + Vector2.from_angle(a) * s * 0.34, Color("5fd36a"), s * 0.07)
			"crates":
				draw_rect(Rect2(fl + Vector2(-s * 0.34, -s * 0.26), Vector2(s * 0.34, s * 0.26)), Color("8a6a45"))
				draw_rect(Rect2(fl + Vector2(0.02 * s, -s * 0.22), Vector2(s * 0.3, s * 0.22)), Color("a07a4f"))
				draw_rect(Rect2(fl + Vector2(-s * 0.2, -s * 0.5), Vector2(s * 0.3, s * 0.24)), Color("b88a55"))
				draw_line(fl + Vector2(-s * 0.34, -s * 0.13), fl + Vector2(0, -s * 0.13), Color("5a4028"), 2.0)
			"poster":
				var pr := Rect2(ctr + Vector2(-s * 0.22, -s * 0.34), Vector2(s * 0.44, s * 0.56))
				draw_rect(pr, Color("e8f4ff"))
				draw_rect(pr.grow(-3.0), Color("2a3a6a"))
				draw_circle(pr.get_center() + Vector2(0, -s * 0.06), s * 0.1, Color("4fd1ff"))
				draw_rect(Rect2(pr.position + Vector2(5, pr.size.y - 12), Vector2(pr.size.x - 10, 5)), Color("ffd84f"))
			"lamp":
				var k := 0.5 + 0.5 * sin(t * 1.7)
				draw_rect(Rect2(fl + Vector2(-s * 0.1, -s * 0.08), Vector2(s * 0.2, s * 0.08)), Color("56607f"))
				draw_rect(Rect2(fl + Vector2(-s * 0.08, -s * 0.5), Vector2(s * 0.16, s * 0.42)), Color(1.0, 0.4, 0.6, 0.5))
				draw_circle(fl + Vector2(0, -s * (0.16 + 0.26 * k)), s * 0.05, Color("ffb347"))
				draw_circle(fl + Vector2(0, -s * 0.3), s * 0.3, Color(1.0, 0.5, 0.6, 0.08))
			"trophy":
				draw_rect(Rect2(fl + Vector2(-s * 0.14, -s * 0.08), Vector2(s * 0.28, s * 0.08)), Color("8a6a2a"))
				draw_rect(Rect2(fl + Vector2(-s * 0.03, -s * 0.2), Vector2(s * 0.06, s * 0.12)), Color("ffd84f"))
				draw_circle(fl + Vector2(0, -s * 0.32), s * 0.14, Color("ffd84f"))
				draw_arc(fl + Vector2(-s * 0.16, -s * 0.34), s * 0.06, 0, TAU, 10, Color("ffd84f"), 2.0)
				draw_arc(fl + Vector2(s * 0.16, -s * 0.34), s * 0.06, 0, TAU, 10, Color("ffd84f"), 2.0)
				if fmod(t, 2.5) < 0.3:
					draw_circle(fl + Vector2(s * 0.06, -s * 0.38), 2.5, Color.WHITE)
			"tank":
				var tr := Rect2(ctr + Vector2(-s * 0.36, -s * 0.24), Vector2(s * 0.72, s * 0.5))
				draw_rect(tr, Color(0.2, 0.6, 0.9, 0.45))
				draw_rect(tr, Color("9fe8ff"), false, 2.0)
				for k in 2:
					var fx2 := tr.position.x + fmod(t * (14.0 + k * 9.0) + k * 30.0, tr.size.x)
					draw_circle(Vector2(fx2, tr.position.y + tr.size.y * (0.35 + 0.3 * k)), s * 0.045, [Color("ffb347"), Color("ff6f91")][k])
				for k in 3:
					var by := fmod(t * 20.0 + k * 13.0, tr.size.y)
					draw_circle(Vector2(tr.position.x + tr.size.x * (0.2 + 0.3 * k), tr.end.y - by), 1.5, Color(1, 1, 1, 0.5))
			"arcade":
				draw_rect(Rect2(ctr + Vector2(-s * 0.2, -s * 0.38), Vector2(s * 0.4, s * 0.74)), Color("3a2a6a"))
				var sc := Color.from_hsv(fmod(t * 0.2, 1.0), 0.6, 1.0)
				draw_rect(Rect2(ctr + Vector2(-s * 0.15, -s * 0.3), Vector2(s * 0.3, s * 0.22)), sc.darkened(0.5))
				draw_circle(ctr + Vector2(-s * 0.04, -s * 0.2), s * 0.03, sc)
				draw_circle(ctr + Vector2(-s * 0.08, s * 0.02), s * 0.03, Color("ff5d5d"))
				draw_circle(ctr + Vector2(s * 0.06, s * 0.02), s * 0.03, Color("ffd84f"))
			"bot":
				var bp := ctr + Vector2(sin(t * 0.9) * s * 0.12, sin(t * 2.6) * s * 0.04 - s * 0.04)
				draw_circle(bp + Vector2(0, s * 0.36), s * 0.12, Color(0, 0, 0, 0.3))
				draw_circle(bp, s * 0.17, Color("c9d3f0"))
				draw_rect(Rect2(bp + Vector2(-s * 0.1, -s * 0.05), Vector2(s * 0.2, s * 0.08)), Color("10142a"))
				var blink := fmod(t, 3.0) < 0.12
				if not blink:
					draw_circle(bp + Vector2(-s * 0.045, -s * 0.01), s * 0.025, Color("4fd1ff"))
					draw_circle(bp + Vector2(s * 0.045, -s * 0.01), s * 0.025, Color("4fd1ff"))
				draw_line(bp + Vector2(0, -s * 0.17), bp + Vector2(0, -s * 0.26), Color("c9d3f0"), 2.0)
				draw_circle(bp + Vector2(0, -s * 0.27), 3.0, Color("ff6f91"))
			"crystal":
				var g := 0.5 + 0.5 * sin(t * 2.0)
				draw_circle(ctr, s * 0.32, Color(0.6, 0.4, 1.0, 0.1 + 0.08 * g))
				draw_colored_polygon(PackedVector2Array([fl + Vector2(-s * 0.14, 0), fl + Vector2(0, -s * 0.6), fl + Vector2(s * 0.14, 0)]), Color("b49cff"))
				draw_colored_polygon(PackedVector2Array([fl + Vector2(-s * 0.26, 0), fl + Vector2(-s * 0.16, -s * 0.34), fl + Vector2(-s * 0.08, 0)]), Color("8a6cff"))
				draw_colored_polygon(PackedVector2Array([fl + Vector2(s * 0.08, 0), fl + Vector2(s * 0.2, -s * 0.28), fl + Vector2(s * 0.28, 0)]), Color("8a6cff"))
			"banner":
				var w := sin(t * 1.5) * s * 0.03
				draw_line(ctr + Vector2(-s * 0.26, -s * 0.38), ctr + Vector2(s * 0.26, -s * 0.38), Color("8a93a8"), 3.0)
				draw_colored_polygon(PackedVector2Array([ctr + Vector2(-s * 0.2, -s * 0.36), ctr + Vector2(s * 0.2, -s * 0.36), ctr + Vector2(s * 0.2 + w, s * 0.3), ctr + Vector2(w, s * 0.18), ctr + Vector2(-s * 0.2 + w, s * 0.3)]), Color("5a0f3a"))
				draw_circle(ctr + Vector2(w * 0.5, -s * 0.06), s * 0.1, Color("ff4f9a"))
const DEEP_NEED := 15      # best adventure floor needed to open the Deep Station dive
const DEEP_START := 13     # dives start here (anomalies from 14, deep worlds from 21)
var deep_run := false      # this run is a Deep Station dive: arena bosses are random rematches


func _deep_locked() -> bool:
	return adv_best < DEEP_NEED and ul_all == 0


func _deep_dive() -> void:
	_base_end()
	deep_run = true
	_new_run(DEEP_START)
	deep_run = true
	_adv_level_up(14)
	for i in 4:
		_adv_give_gear(_adv_roll_gear(null, 1))
	hp = hp_cap()
	oxy = oxy_max
	msg = "DEEP STATION DIVE: you start on floor %d at level %d with 4 pieces of gear. Every world's boss is a random rematch." % [floor_n, level]
	_pop(pos, "DEEP DIVE", Color("7a5cff"))


func _bs_def(id: String) -> Array:
	for d in BS_ROOMS:
		if String(d[0]) == id:
			return d
	return []


func _base_start() -> void:
	deep_run = false
	rv_used = false
	rv_ask = false
	ad_boss = false
	if ad_run_pending:
		ad_run_pending = false
		_ads().on_return_to_base()
	in_base = true
	base_prev_save_off = save_off
	save_off = true
	mode = "adv"
	_new_run(1)
	adv_seen.fill(1)
	hp = hp_cap()
	oxy = oxy_max
	msg = "STATION BASE: walk into a room. Walk through START to begin the run."
	_sfx("big")


func _base_end() -> void:
	in_base = false
	save_off = base_prev_save_off
	walk.clear()
	aim = -1
	joy_on = false
	joy_dir = Vector2i.ZERO


func _adv_gen_base() -> void:
	AW = 17
	AH = 17
	adv_open.resize(AW * AH)
	adv_open.fill(0)
	adv_seen.resize(AW * AH)
	adv_seen.fill(1)
	adv_rooms.clear()
	for dd in [mons, elite, items, spikes, haz, tur, corpses, coin_at, walls, portals, kinds, thief_held, vaults, stations, meds, merchants, mon_hp, affix, mstat, cracked]:
		dd.clear()
	var cor := Rect2i(7, 2, 2, 13)
	adv_rooms.append(cor)
	for x in range(cor.position.x, cor.end.x):
		for y in range(cor.position.y, cor.end.y):
			adv_open[_ai(Vector2i(x, y))] = 1
	for d in BS_ROOMS:
		var c: Vector2i = d[5]
		items[c] = "bs_" + String(d[0])
		adv_open[_ai(c)] = 1
	items[Vector2i(8, 1)] = "bs_start"
	adv_open[_ai(Vector2i(8, 1))] = 1
	start = Vector2i(7, 14)
	pos = start
	stairs = Vector2i(8, 0)   # closed wall cell: the run starts from the START door
	boss_floor = false
	boss_cell = Vector2i(-1, -1)
	adv_req = 999
	adv_pts_total = 0


func _bs_new(step: int) -> bool:
	return step > 0 and ul_all == 0 and ul_tapped & (1 << step) == 0


func _bs_open(kind: String) -> void:
	if not in_base or state != PLAY:
		return
	walk.clear()
	joy_on = false
	joy_dir = Vector2i.ZERO
	swipe_on = false
	var id := kind.substr(3)
	var d := _bs_def(id)
	if id == "deep" and _deep_locked():
		msg = "LOCKED: DEEP STATION opens after you reach floor %d in an adventure run (best %d)." % [DEEP_NEED, adv_best]
		_sfx("blocked")
		return
	if d.size() > 0 and not ul(int(d[2])):
		var un: Array = UL_STEPS[int(d[2])]
		msg = "LOCKED: %s unlocks after run %d. %s" % [String(d[1]), int(d[2]), String(un[1])]
		_sfx("blocked")
		return
	if d.size() > 0 and int(d[2]) > 0:
		_ul_tap(int(d[2]))
	match id:
		"start":
			_sfx("big")
			_base_end()
			_new_run()
			_first_tut()
		"deep":
			_sfx("big")
			_deep_dive()
		"style":
			_sfx("ui")
			_style_tap()
		"shop":
			shop_return = PLAY
			shop_tab = 0
			shop_page = 0
			state = SHOP
			_sfx("ui")
		"puzzle":
			shop_return = PLAY
			mini_pick = true
			state = SHOP
			_sfx("ui")
		"mastery":
			mx_cls = cls
			state = MASTERY
			_sfx("ui")
		"contracts":
			_ct_fill()
			state = CONTRACTS
			_sfx("ui")
		"workshop":
			state = WORKSHOP
			_sfx("ui")
		"codex":
			cx_ret = PLAY
			_cx_open()
		"thr_m", "thr_p":
			_hz_tap(cls, id == "thr_p")
			var mx := int(hz_max.get(cls, 0))
			var cur := clampi(int(hz_sel.get(cls, 0)), 0, mx)
			msg = "THREAT %d / %d for this class" % [cur, mx]
			if cur > 0:
				msg += ": +%d%% coins, +%d%% mastery XP" % [15 * cur, 10 * cur]
			elif mx == 0:
				msg += " (clear floor 5 to unlock threat 1)"


func _bs_draw(ctr: Vector2, kind: String, bob: float) -> void:
	var d := _bs_def(kind.substr(3))
	if d.is_empty():
		return
	var col: Color = d[3]
	var locked := not ul(int(d[2])) or (String(d[0]) == "deep" and _deep_locked())
	if locked:
		col = Color(0.55, 0.58, 0.68)
	var k := 0.5 + 0.5 * sin(t * 3.0)
	var p := ctr + Vector2(0, bob * 0.5)
	if String(d[0]) == "start":
		draw_circle(ctr, AC * 0.5, Color(col.r, col.g, col.b, 0.1 + 0.08 * k))
		_spr(spr_gen.icon("door_open"), ctr, AC * 0.92)
	else:
		var bt := float(bs_boot.get(String(d[0]), 0.0))
		if not locked and bt > 0.5:
			draw_circle(p, AC * 0.46, Color(col.r, col.g, col.b, (0.1 + 0.08 * k) * (bt - 0.5) * 2.0))
		if not _bs_term(d, ctr, locked, bt, col):
			_spr(spr_gen.icon("bs_" + String(d[0]) + ("_off" if locked else "")), ctr, AC * 0.92)
		if not locked:
			if bt < 0.999 and _bs_tex(String(d[0]) + "_dark") == null:
				draw_rect(Rect2(ctr - Vector2(AC * 0.46, AC * 0.46), Vector2(AC * 0.92, AC * 0.92)), Color(0, 0, 0, 0.5 * (1.0 - bt)))
			if bt > 0.02 and bt < 0.999:
				var scy := ctr.y - AC * 0.4 + AC * 0.8 * fmod(bt * 3.0, 1.0)
				draw_rect(Rect2(ctr.x - AC * 0.38, scy, AC * 0.76, 3), Color(col.r, col.g, col.b, 0.85 if sin(t * 40.0) > -0.3 else 0.3))
			elif bt >= 0.999:
				var sw := fmod(t * 0.45 + float((d[5] as Vector2i).y) * 0.17, 1.0)
				draw_rect(Rect2(ctr.x - AC * 0.38, ctr.y - AC * 0.4 + AC * 0.8 * sw, AC * 0.76, 2), Color(col.r, col.g, col.b, 0.22))
			col = Color(col.r, col.g, col.b, 0.45 + 0.55 * bt)
	var lbl := String(d[1])
	if String(d[0]).begins_with("thr_"):
		lbl += " (%d)" % clampi(int(hz_sel.get(cls, 0)), 0, int(hz_max.get(cls, 0)))
	bs_lbls.append([lbl, ctr + Vector2(0, AC * 0.62), int(AC * 0.17), col])
	if locked:
		_ctext("LOCKED", ctr + Vector2(0, -AC * 0.5), int(AC * 0.17), Color("ffb02e"))
	elif _bs_new(int(d[2])):
		_ctext("NEW!", ctr + Vector2(0, -AC * 0.55 + sin(t * 5.0) * 3.0), int(AC * 0.2), Color("ff5d5d"))

# ===== B88: living floors (themed ambient critters + decor) =====
var amb_crit: Array = []
var amb_dec: Array = []
var amb_key := ""
var amb_rng := RandomNumberGenerator.new()
var clear_t0 := -10.0


func _amb_free(c: Vector2i) -> bool:
	return _aopen(c) and not walls.has(c) and not items.has(c) and not stations.has(c) and not vaults.has(c) and not merchants.has(c) and not meds.has(c) and c != stairs


func _amb_build() -> void:
	mon_idle.clear()
	amb_ev = ""
	amb_crit.clear()
	amb_dec.clear()
	if adv_open.size() != AW * AH:
		return
	var ti := tidx() % 4
	amb_rng.seed = hash(amb_key)
	var open: Array = []
	for y in AH:
		for x in AW:
			var c := Vector2i(x, y)
			if _amb_free(c):
				open.append(c)
	if open.is_empty():
		return
	var every: int = [14, 5, 16, 9][ti]
	for c in open:
		if amb_dec.size() < 320 and amb_rng.randi() % every == 0:
			amb_dec.append([c, Vector2(amb_rng.randf_range(-0.3, 0.3), amb_rng.randf_range(-0.25, 0.3)), amb_rng.randf() * TAU])
	var n := 2 if in_base else clampi(2 + open.size() / 140, 2, 6)
	var kinds := ["bot", "moth", "rat", "wisp"]
	var spd := {"bot": 1.6, "moth": 1.3, "rat": 4.5, "wisp": 0.8}
	for i in n:
		var c2: Vector2i = open[amb_rng.randi() % open.size()]
		var k := String(kinds[ti])
		amb_crit.append({"k": k, "p": Vector2(c2), "to": Vector2(c2), "d": Vector2i(1, 0), "w": amb_rng.randf() * 2.0, "ph": amb_rng.randf() * TAU, "sp": float(spd[k])})
	if in_base:
		return
	if amb_rng.randf() < 0.5:
		amb_ev = String(["brownout", "leaves", "dust", "hum"][ti])
		amb_ev_ph = amb_rng.randf() * 10.0
	if arena:
		return
	var ml: Array = mons.keys()
	for c3 in ml:
		if not _idle_ok(c3) or mon_idle.has(c3):
			continue
		var roll := amb_rng.randf()
		if roll < 0.35:
			var pal := Vector2i(-1, -1)
			for o in ml:
				if o != c3 and not mon_idle.has(o) and _idle_ok(o) and _cheb(o, c3) <= 2:
					pal = o
					break
			if pal.x >= 0:
				mon_idle[c3] = {"s": "talk", "p": pal, "ph": 0}
				mon_idle[pal] = {"s": "talk", "p": c3, "ph": 1}
				continue
		if roll < 0.7:
			mon_idle[c3] = {"s": "sleep", "ph": 0}
		else:
			mon_idle[c3] = {"s": "look", "ph": amb_rng.randi() % 4}


func _amb_pick(m: Dictionary) -> void:
	var mp: Vector2 = m["p"]
	var c := Vector2i(roundi(mp.x), roundi(mp.y))
	var keep: Vector2i = m["d"]
	var opts: Array = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nc: Vector2i = c + d
		if _amb_free(nc) and nc != pos and not mons.has(nc):
			opts.append(d)
	if String(m["k"]) == "bot" and (spikes.has(c) or haz.has(c)) and amb_rng.randf() < 0.4:
		spikes.erase(c)
		haz.erase(c)
		_pop(c, "CLEANED", Color("c0cbdc"))
		_fx_burst(Vector2(c), Color("ead4aa"), 8, 2.0, 0.4, 4.0)
	if opts.is_empty():
		m["w"] = 1.0
		return
	var nd: Vector2i = keep if (opts.has(keep) and amb_rng.randf() < 0.65) else opts[amb_rng.randi() % opts.size()]
	var gv := _crit_goal(m, c)
	if gv != Vector2.ZERO and amb_rng.randf() < (0.95 if m.get("scared", false) else 0.7):
		var bsc := -9.0
		for od in opts:
			var sc := Vector2(od).dot(gv)
			if sc > bsc:
				bsc = sc
				nd = od
	m["d"] = nd
	m["to"] = Vector2(c + nd)
	match String(m["k"]):
		"rat":
			m["w"] = amb_rng.randf_range(0.0, 0.25) if amb_rng.randf() < 0.7 else amb_rng.randf_range(0.8, 2.2)
		"bot":
			m["w"] = amb_rng.randf_range(0.2, 1.4)
		"moth":
			m["w"] = amb_rng.randf_range(0.0, 0.3)
		_:
			m["w"] = amb_rng.randf_range(0.4, 1.8)
	if m.get("scared", false):
		m["w"] = 0.02


func _amb_update(dt: float) -> void:
	if mode != "adv" or mini:
		if amb_key != "":
			amb_key = ""
			amb_crit.clear()
			amb_dec.clear()
		return
	var key := "%d_%d_%d_%d_%d" % [adv_seed, floor_n, int(in_base), AW, AH]
	if key != amb_key:
		amb_key = key
		_amb_build()
	if in_base:
		for bd in BS_ROOMS:
			var bc: Vector2i = bd[5]
			var want := 1.0 if Vector2(bc).distance_to(vis_pos) < 2.7 else 0.0
			bs_boot[String(bd[0])] = move_toward(float(bs_boot.get(String(bd[0]), 0.0)), want, dt * (1.6 if want > 0.0 else 0.8))
	for m in amb_crit:
		var p: Vector2 = m["p"]
		var to: Vector2 = m["to"]
		if m.get("dead", false):
			continue
		if Vector2i(roundi(p.x), roundi(p.y)) == pos and vis_pos.distance_to(p) < 0.5:
			_amb_squash(m)
			continue
		if p.distance_to(to) < 0.001:
			m["w"] = float(m["w"]) - dt
			if float(m["w"]) <= 0.0:
				_amb_pick(m)
		else:
			m["p"] = p.move_toward(to, dt * float(m["sp"]) * (2.2 if m.get("scared", false) else 1.0))


func _amb_world_draw(ti: int) -> void:
	if mode != "adv":
		return
	var acc: Color = cur_theme()["accent"]
	var k4 := ti % 4
	_st_world_draw()
	for dd in amb_dec:
		var c: Vector2i = dd[0]
		if not _aseen(c) or items.has(c) or mons.has(c):
			continue
		var a := 1.0 - _fog_a(c, 0.55)
		if a < 0.05:
			continue
		var o: Vector2 = dd[1]
		var ph: float = dd[2]
		var q := _actr(c) + o * AC
		if k4 == 0:
			var gl := 0.5 + 0.5 * sin(t * 1.3 + ph)
			if fmod(t * 0.37 + ph, 5.0) < 0.08:
				gl = 0.0
			draw_rect(Rect2(q - Vector2(AC * 0.12, AC * 0.025), Vector2(AC * 0.24, AC * 0.05)), Color(0.1, 0.13, 0.22, a))
			draw_rect(Rect2(q - Vector2(AC * 0.1, AC * 0.012), Vector2(AC * 0.2, AC * 0.024)), Color(acc.r, acc.g, acc.b, a * (0.25 + 0.6 * gl)))
		elif k4 == 1:
			var near := 1.0 + 1.5 * clampf(1.6 - Vector2(c).distance_to(vis_pos), 0.0, 1.0)
			var sw := sin(t * 2.1 + float(c.x) * 0.8 + float(c.y) * 0.5) * AC * 0.05 * near
			var gc := Color(acc.r * 0.6, acc.g * 0.75, acc.b * 0.55, a * 0.9)
			for b in 3:
				var bx := (float(b) - 1.0) * AC * 0.06
				var hh := AC * (0.16 + 0.05 * float((b + int(ph * 3.0)) % 3))
				draw_line(q + Vector2(bx, 0), q + Vector2(bx + sw * (0.7 + 0.3 * float(b)), -hh), gc, 2.0)
		elif k4 == 2:
			var fl := 0.6 + 0.4 * sin(t * 13.0 + ph) * sin(t * 7.3 + ph * 2.0)
			draw_rect(Rect2(q - Vector2(AC * 0.03, 0), Vector2(AC * 0.06, AC * 0.1)), Color(0.9, 0.85, 0.7, a))
			draw_circle(q + Vector2(0, -AC * 0.04), AC * 0.11 * fl, Color(1, 0.6, 0.2, a * 0.18))
			draw_circle(q + Vector2(0, -AC * 0.03), AC * 0.03 * (0.8 + 0.3 * fl), Color(1, 0.8, 0.35, a))
		else:
			var pu := pow(0.5 + 0.5 * sin(t * 1.7 + ph), 3.0)
			var s := AC * 0.09
			draw_circle(q, s * 2.2, Color(acc.r, acc.g, acc.b, a * 0.08 * pu))
			draw_colored_polygon(PackedVector2Array([q + Vector2(0, -s * 1.8), q + Vector2(s * 0.7, 0), q + Vector2(0, s * 0.5), q + Vector2(-s * 0.7, 0)]), Color(acc.r, acc.g, acc.b, a * (0.45 + 0.5 * pu)))
	for m in amb_crit:
		var p: Vector2 = m["p"]
		var c2 := Vector2i(roundi(p.x), roundi(p.y))
		if not _aseen(c2):
			continue
		var a2 := 1.0 - _fog_a(c2, 0.55)
		if a2 < 0.3:
			continue
		var ph2: float = m["ph"]
		var dv0 := Vector2(m["d"])
		var dv: Vector2 = Vector2(m.get("sd", dv0)).slerp(dv0, clampf(get_process_delta_time() * 9.0, 0.0, 1.0))
		if dv.length() < 0.5:
			dv = dv0
		m["sd"] = dv
		var q2 := _wp(p)
		var moving := p.distance_to(m["to"]) > 0.001
		if m.get("dead", false):
			_amb_dead_draw(m, q2, a2, acc)
			continue
		if _crit_draw(m, q2, a2, acc, moving, dv):
			continue
		match String(m["k"]):
			"bot":
				var ol := Color("181425", a2)
				var bq := q2 + Vector2(0, AC * 0.1)
				draw_circle(bq + Vector2(0, AC * 0.06), AC * 0.18, Color(0, 0, 0, 0.3 * a2))
				var spin := t * (14.0 if moving else 4.0)
				for bs in [-1.0, 1.0]:
					var bc: Vector2 = bq + Vector2(-dv.y, dv.x) * bs * AC * 0.13 + dv * AC * 0.08
					for bi in 3:
						draw_line(bc, bc + Vector2.from_angle(spin * bs + float(bi) * TAU / 3.0) * AC * 0.09, Color("ead4aa", a2 * 0.9), 2.0)
				draw_circle(bq, AC * 0.185, ol)
				draw_circle(bq, AC * 0.165, Color("5a6988", a2))
				draw_circle(bq + Vector2(0, -AC * 0.015), AC * 0.15, Color("8b9bb4", a2))
				draw_circle(bq + Vector2(0, -AC * 0.035), AC * 0.12, Color("c0cbdc", a2))
				draw_circle(bq + Vector2(-AC * 0.05, -AC * 0.08), AC * 0.03, Color(1, 1, 1, 0.6 * a2))
				var on := fmod(t + ph2, 1.2) < 0.6
				var lp := bq + dv * AC * 0.07 + Vector2(0, -AC * 0.05)
				draw_circle(lp, AC * 0.042, ol)
				draw_circle(lp, AC * 0.03, Color("63c74d", a2) if on else Color("265c42", a2))
			"moth":
				var hv := q2 + Vector2(sin(t * 1.9 + ph2) * AC * 0.18, -AC * 0.22 + sin(t * 3.7 + ph2) * AC * 0.08)
				var fw := 0.35 + 0.65 * absf(sin(t * 22.0 + ph2))
				var ax := Vector2(-dv.y, dv.x)
				var ol2 := Color("181425", a2)
				draw_circle(hv, AC * 0.16, Color(1, 1, 1, 0.08 * a2))
				for ws in [-1.0, 1.0]:
					var wc: Vector2 = hv + ax * ws * AC * 0.07 * fw
					var wr := AC * (0.03 + 0.045 * fw)
					draw_circle(wc, wr + 1.5, ol2)
					draw_circle(wc, wr, Color("ffffff", a2))
					draw_circle(wc + dv * AC * 0.02, wr * 0.55, Color("c0cbdc", a2))
					draw_circle(wc - dv * AC * 0.01, wr * 0.28, Color("3e2731", a2))
				draw_line(hv - dv * AC * 0.05, hv + dv * AC * 0.05, ol2, 5.0)
				draw_line(hv - dv * AC * 0.04, hv + dv * AC * 0.04, Color("ead4aa", a2), 3.0)
			"rat":
				var rb := q2 + Vector2(0, AC * 0.12)
				var wig := sin(t * 30.0) * AC * 0.01 if moving else 0.0
				var side := Vector2(-dv.y, dv.x)
				var ol3 := Color("181425", a2)
				var rw := Vector2(0, wig)
				draw_circle(rb + Vector2(0, AC * 0.05), AC * 0.1, Color(0, 0, 0, 0.3 * a2))
				var tl := rb - dv * AC * 0.24 + side * AC * 0.05 * sin(t * 9.0 + ph2)
				draw_line(rb - dv * AC * 0.08, tl, ol3, 4.0)
				draw_line(rb - dv * AC * 0.08, tl, Color("b86f50", a2), 2.0)
				draw_circle(rb + rw, AC * 0.095, ol3)
				draw_circle(rb + rw, AC * 0.08, Color("3a4466", a2))
				draw_circle(rb + rw + Vector2(0, -AC * 0.015), AC * 0.065, Color("5a6988", a2))
				var hd := rb + dv * AC * 0.09 + rw
				for es in [-1.0, 1.0]:
					var ep: Vector2 = hd - dv * AC * 0.02 + side * es * AC * 0.045 + Vector2(0, -AC * 0.02)
					draw_circle(ep, AC * 0.03, ol3)
					draw_circle(ep, AC * 0.02, Color("e4a6c0", a2))
				draw_circle(hd, AC * 0.065, ol3)
				draw_circle(hd, AC * 0.052, Color("5a6988", a2))
				draw_circle(hd + dv * AC * 0.05, AC * 0.017, Color("e4a6c0", a2))
				draw_circle(hd + dv * AC * 0.02 + side * AC * 0.025 + Vector2(0, -AC * 0.015), AC * 0.012, Color(0, 0, 0, a2))
			_:
				var wq := q2 + Vector2(0, -AC * 0.2 + sin(t * 2.3 + ph2) * AC * 0.1)
				var g2 := 0.6 + 0.4 * sin(t * 4.0 + ph2)
				var cy := Color("2ce8f5")
				draw_circle(wq, AC * 0.22, Color(cy.r, cy.g, cy.b, 0.1 * a2 * g2))
				for tj in 3:
					var tp := wq - dv * AC * 0.08 * float(tj + 1) + Vector2(0, AC * 0.03 * float(tj + 1))
					draw_circle(tp, AC * (0.035 - 0.008 * float(tj)), Color(cy.r, cy.g, cy.b, a2 * (0.35 - 0.1 * float(tj))))
				var r0 := AC * 0.11
				var ang := dv.angle() * 0.15 + sin(t * 1.3 + ph2) * 0.15
				var dm := PackedVector2Array()
				for di in 4:
					dm.append(wq + Vector2.from_angle(ang + float(di) * PI * 0.5 - PI * 0.5) * r0)
				var dmo := PackedVector2Array()
				for v in dm:
					dmo.append(wq + (v - wq) * 1.2)
				draw_colored_polygon(dmo, Color("181425", a2))
				draw_colored_polygon(dm, Color("0099db", a2))
				var dmi := PackedVector2Array()
				for v in dm:
					dmi.append(wq + (v - wq) * 0.7 + Vector2(0, -AC * 0.015))
				draw_colored_polygon(dmi, Color("2ce8f5", a2))
				draw_circle(wq + Vector2(-AC * 0.02, -AC * 0.03), AC * 0.022, Color(1, 1, 1, 0.9 * a2 * g2))
	_amb_ev_draw()


# ===== B88: idle enemies, kill streaks, boss card, frost, floor events =====
var mon_idle: Dictionary = {}   # Vector2i -> {"s": sleep|talk|look, "p": partner, "ph": int}
var bs_boot: Dictionary = {}
var amb_ev := ""
var amb_ev_ph := 0.0
var streak_n := 0
var streak_step := -99
var streak_t := -10.0
var streak_txt := ""
var muf := 0.0
var lp_fx: AudioEffectLowPassFilter = null
var lp_idx := -1


func _idle_ok(c: Vector2i) -> bool:
	if not mons.has(c) or tur.has(c) or (boss_floor and c == boss_cell):
		return false
	return not (String(kinds.get(c, "")) in ["rager", "shard"])


func _idle_sleep(c: Vector2i) -> bool:
	return mon_idle.has(c) and String(mon_idle[c]["s"]) == "sleep"


func _idle_dir(c: Vector2i) -> int:
	var d: Dictionary = mon_idle[c]
	var s := String(d["s"])
	if s == "talk":
		var o: Vector2i = d["p"]
		var dx := o.x - c.x
		var dy := o.y - c.y
		if absi(dx) > absi(dy):
			return 3 if dx > 0 else 2
		return 0 if dy >= 0 else 1
	if s == "sleep":
		return 0
	if d.has("fd"):
		return int(d["fd"])
	return (adv_steps / 3 + int(d["ph"])) % 4


func _idle_wake(c: Vector2i, chain := true) -> void:
	if not mon_idle.has(c):
		return
	var d: Dictionary = mon_idle[c]
	mon_idle.erase(c)
	if mons.has(c):
		_pop(c, "!", Color("ffd84f"))
		floor_spotted = true
	if chain and String(d["s"]) == "talk":
		_idle_wake(d["p"])


func _idle_noise(c: Vector2i, r: int) -> void:
	if cloak_steps > 0 or st_quiet:
		return
	for o in mon_idle.keys():
		if _cheb(o, c) <= r:
			_idle_wake(o)


func _idle_los(a: Vector2i, b: Vector2i) -> bool:
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in range(1, n):
		var k := float(i) / float(n)
		var m := Vector2i(roundi(lerpf(float(a.x), float(b.x), k)), roundi(lerpf(float(a.y), float(b.y), k)))
		if not _aopen(m):
			return false
	return true


func _idle_notice() -> void:
	if mon_idle.is_empty() or mode != "adv":
		return
	var woke: Array = []
	var hid := _hidden()
	var need := 2 + int(sk("st_slow")) + (1 if gm("hushvisor") else 0)
	for c in mon_idle.keys():
		if not mons.has(c):
			mon_idle.erase(c)
			continue
		var md: Dictionary = mon_idle[c]
		var s := String(md["s"])
		var d := _cheb(c, pos)
		var gain := 0
		if not hid:
			if _st_sees(c):
				gain = 2 if d <= 1 else 1
			elif d <= 1 and not (gm("softsoles") if s == "sleep" else gm("quietweave")):
				gain = 1
		gain += int(md.get("hear", 0))
		md.erase("hear")
		var sus := int(md.get("sus", 0))
		sus = sus + gain if gain > 0 else maxi(0, sus - 1)
		md["sus"] = sus
		if sus >= need or (gain >= 2 and sus >= 2):
			woke.append(c)
	for c in woke:
		_idle_wake(c)
	if not woke.is_empty():
		_sfx("aggro")


func _idle_draw(c: Vector2i, ctr: Vector2) -> void:
	if not mon_idle.has(c):
		return
	var d: Dictionary = mon_idle[c]
	var s := String(d["s"])
	if s == "sleep":
		for i in 2:
			var u := fmod(t * 0.5 + float(i) * 0.5 + float(c.x) * 0.13, 1.0)
			_ctext("z", ctr + Vector2(AC * (0.2 + 0.15 * u), -AC * (0.35 + 0.35 * u)), int(AC * (0.16 + 0.1 * u)), Color(0.75, 0.85, 1.0, 1.0 - u))
	elif s == "talk":
		if int(t / 1.6) % 2 == int(d["ph"]):
			var bp := ctr + Vector2(0, -AC * 0.62)
			var wc := Color(1, 1, 1, 0.85)
			draw_rect(Rect2(bp - Vector2(AC * 0.2, AC * 0.1), Vector2(AC * 0.4, AC * 0.2)), wc)
			draw_colored_polygon(PackedVector2Array([bp + Vector2(-AC * 0.05, AC * 0.1), bp + Vector2(AC * 0.05, AC * 0.1), bp + Vector2(0, AC * 0.17)]), wc)
			for j in 3:
				var on := fmod(t * 3.0, 3.0) >= float(j)
				draw_circle(bp + Vector2((float(j) - 1.0) * AC * 0.1, 0), AC * 0.03, Color(0.1, 0.12, 0.2, 1.0 if on else 0.3))
	else:
		var dv4 := [Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]
		var fd := Vector2(dv4[_idle_dir(c)])
		var side := Vector2(-fd.y, fd.x)
		var rl := float(_cone_r()) + 0.4
		var p1 := ctr + fd * AC * rl + side * AC * rl
		var p2 := ctr + fd * AC * rl - side * AC * rl
		draw_colored_polygon(PackedVector2Array([ctr + fd * AC * 0.4, p1, p2]), Color(1, 0.9, 0.4, 0.06 + 0.06 * float(mini(1, int(d.get("sus", 0))))))
	if s == "talk":
		var dv5 := [Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]
		var fd2 := Vector2(dv5[_idle_dir(c)])
		var rl2 := float(_cone_r()) + 0.4
		draw_colored_polygon(PackedVector2Array([ctr + fd2 * AC * 0.4 + Vector2(-fd2.y, fd2.x) * AC * 0.35, ctr + fd2 * AC * rl2 + Vector2(-fd2.y, fd2.x) * AC * 1.4, ctr + fd2 * AC * rl2 - Vector2(-fd2.y, fd2.x) * AC * 1.4, ctr + fd2 * AC * 0.4 - Vector2(-fd2.y, fd2.x) * AC * 0.35]), Color(1, 0.9, 0.4, 0.05))
	if int(d.get("sus", 0)) > 0:
		var qb := 1.0 + 0.12 * sin(t * 9.0)
		_ctext("?", ctr + Vector2(-AC * 0.22, -AC * 0.62), int(AC * 0.34 * qb), Color("ffd84f"))


func _amb_squash(m: Dictionary) -> void:
	m["dead"] = true
	m["dt"] = t
	var p: Vector2 = m["p"]
	m["to"] = p
	var c := Vector2i(roundi(p.x), roundi(p.y))
	var k := String(m["k"])
	if k == "bot":
		_fx_burst(p, Color("ffd84f"), 12, 3.0, 0.5, 4.0)
		_sfx("shieldbreak")
		if in_base:
			_pop(c, "CRUNCH", Color("c9d3f0"))
		elif amb_rng.randf() < 0.5:
			coins += coin_val()
			_pop(c, "+%d COIN" % coin_val(), Color("ffd84f"))
			_sfx("coin")
		else:
			scrap += 1
			_pop(c, "+1 SCRAP", Color("c9a36b"))
	elif k == "wisp":
		_fx_burst(p, cur_theme()["accent"], 14, 2.5, 0.6, 4.0)
		_sfx("ui")
		if in_base:
			_pop(c, "POP", cur_theme()["accent"])
		else:
			oxy = minf(oxy_max, oxy + 6.0)
			_pop(c, "+6 AIR", Color("7fd8ff"))
	elif k == "moth":
		_fx_burst(p, Color("e8e0d0"), 22, 2.4, 0.9, 6.0)
		_pop(c, "DUST", Color("e8e0d0"))
		_sfx("spike")
		if not in_base:
			smoke_c = c
			smoke_steps = maxi(smoke_steps, 3)
	else:
		_fx_burst(p, Color("9be36b") if k == "moth" else Color("c0392b"), 8, 2.0, 0.4, 4.0)
		_pop(c, "SQUISH", Color("ffb0a0"))
		_sfx("spike")
		if not in_base:
			coins += coin_val()
			_pop(c, "+%d COIN" % coin_val(), Color("ffd84f"))
			if cloak_steps <= 0:
				_pop(c, "SQUEAL", Color("ffb0a0"))
				for o in mon_idle:
					if String(mon_idle[o]["s"]) == "sleep" and _cheb(o, c) <= 2:
						mon_idle[o]["hear"] = 1


func _amb_dead_draw(m: Dictionary, q2: Vector2, a2: float, acc: Color) -> void:
	var k := String(m["k"])
	var age := t - float(m["dt"])
	var ph2: float = m["ph"]
	var dtx := _crit_tex(k + "_dead")
	if dtx != null:
		var dfl := -1.0 if (m["d"] as Vector2i).x < 0 else 1.0
		var pop := 1.0 + 0.35 * clampf(1.0 - age / 0.15, 0.0, 1.0)
		var ds: float = {"bot": 0.36, "rat": 0.36}.get(k, 0.3) * AC
		draw_circle(q2 + Vector2(0, AC * 0.12), AC * 0.14, Color(0, 0, 0, 0.22 * a2))
		_crit_blit(dtx, q2 + Vector2(0, AC * 0.08 + ds * 0.5), ds / pop, dfl * pop, Color(1, 1, 1, a2))
		if k == "bot" and fmod(t + ph2, 2.3) < 0.12:
			var sp3 := q2 + Vector2(0, AC * 0.02)
			draw_line(sp3, sp3 + Vector2(AC * 0.08, -AC * 0.1), Color(1, 0.9, 0.4, a2), 2.0)
			draw_line(sp3, sp3 + Vector2(-AC * 0.07, -AC * 0.08), Color(1, 0.9, 0.4, a2), 2.0)
		elif k == "wisp" and age < 1.5:
			draw_circle(q2, AC * 0.12 * (1.0 + age), Color(acc.r, acc.g, acc.b, 0.15 * (1.0 - age / 1.5) * a2))
		return
	if k == "bot":
		var dk := Color(0.12, 0.12, 0.16, a2)
		draw_circle(q2 + Vector2(0, AC * 0.1), AC * 0.18, Color(0, 0, 0, 0.3 * a2))
		draw_circle(q2 + Vector2(0, AC * 0.04), AC * 0.16, Color(0.35, 0.37, 0.44, a2))
		draw_line(q2 + Vector2(-AC * 0.1, -AC * 0.02), q2 + Vector2(AC * 0.04, AC * 0.1), dk, 2.0)
		draw_line(q2 + Vector2(AC * 0.02, -AC * 0.06), q2 + Vector2(AC * 0.12, AC * 0.04), dk, 2.0)
		draw_line(q2 + Vector2(AC * 0.1, AC * 0.06), q2 + Vector2(AC * 0.24, AC * 0.12), Color(0.8, 0.75, 0.5, a2 * 0.7), 2.0)
		if fmod(t + ph2, 2.3) < 0.12:
			var sp2 := q2 + Vector2(0, -AC * 0.06)
			draw_line(sp2, sp2 + Vector2(AC * 0.08, -AC * 0.1), Color(1, 0.9, 0.4, a2), 2.0)
			draw_line(sp2, sp2 + Vector2(-AC * 0.07, -AC * 0.08), Color(1, 0.9, 0.4, a2), 2.0)
	elif k == "wisp":
		var fa := clampf(1.0 - age / 1.5, 0.0, 1.0)
		if fa > 0.0:
			draw_circle(q2, AC * 0.12 * (1.0 + age), Color(acc.r, acc.g, acc.b, 0.15 * fa * a2))
	else:
		var sc := Color(0.5, 0.12, 0.1, 0.75 * a2) if k == "rat" else Color(0.55, 0.75, 0.3, 0.7 * a2)
		var sp := q2 + Vector2(0, AC * 0.14)
		draw_circle(sp, AC * 0.09, sc)
		draw_circle(sp + Vector2(AC * 0.1, AC * 0.02), AC * 0.04, sc)
		draw_circle(sp + Vector2(-AC * 0.09, -AC * 0.03), AC * 0.035, sc)
		draw_circle(sp + Vector2(AC * 0.02, -AC * 0.08), AC * 0.03, sc)


func _amb_ev_draw() -> void:
	if amb_ev == "" or state != PLAY:
		return
	var band := Rect2(0, 318, 720, MAPB - 318.0)
	var acc: Color = cur_theme()["accent"]
	match amb_ev:
		"brownout":
			var u := fmod(t + amb_ev_ph, 16.0)
			if u < 1.0:
				var fl := (1.0 if sin(u * 47.0) > -0.2 else 0.4) * sin(u * PI)
				draw_rect(band, Color(0, 0, 0.02, 0.3 * fl))
		"leaves":
			for i in 12:
				var fi := float(i)
				var x := fposmod(fi * 97.3 + t * (12.0 + float(i % 4) * 5.0) + sin(t * 0.8 + fi) * 30.0, 760.0) - 20.0
				var y := band.position.y + fposmod(fi * 131.7 + t * (20.0 + float(i % 3) * 7.0), band.size.y)
				var dv := Vector2.from_angle(t * (1.2 + 0.3 * float(i % 3)) + fi) * 7.0
				var nv := Vector2(-dv.y, dv.x) * 0.4
				var q := Vector2(x, y)
				draw_colored_polygon(PackedVector2Array([q - dv, q + nv, q + dv, q - nv]), Color(acc.r * 0.6, acc.g * 0.7, acc.b * 0.35, 0.45))
		"dust":
			var u2 := fmod(t + amb_ev_ph, 10.0)
			if u2 < 1.8:
				var n := int((t + amb_ev_ph) / 10.0)
				var x0 := 80.0 + float((n * 7919) % 560)
				for j in 16:
					var fj := float(j)
					var py := band.position.y + (u2 * 300.0 - fj * 16.0)
					if py < band.position.y:
						continue
					draw_rect(Rect2(x0 + sin(fj * 2.1) * 10.0 + fj * 0.8, py, 3, 3), Color(0.85, 0.75, 0.6, 0.35 * (1.0 - u2 / 1.8)))
		"hum":
			var u3 := fmod(t + amb_ev_ph, 11.0)
			if u3 < 2.2:
				var n2 := int((t + amb_ev_ph) / 11.0)
				var c0 := Vector2(80.0 + float((n2 * 4513) % 560), band.position.y + 60.0 + float((n2 * 2741) % int(maxf(1.0, band.size.y - 120.0))))
				var al := 0.14 * (1.0 - u3 / 2.2)
				draw_arc(c0, u3 * 260.0, 0.0, TAU, 64, Color(acc.r, acc.g, acc.b, al), 3.0)
				draw_arc(c0, u3 * 208.0, 0.0, TAU, 64, Color(acc.r, acc.g, acc.b, al * 0.5), 2.0)
				draw_rect(band, Color(acc.r, acc.g, acc.b, 0.03 * (1.0 - u3 / 2.2)))


func _streak_draw() -> void:
	var u := t - streak_t
	if u < 0.0 or u > 1.1 or state != PLAY or mode != "adv":
		return
	var k := clampf(u / 0.12, 0.0, 1.0)
	var sc := 1.0 + 0.5 * (1.0 - k)
	var a := clampf((1.1 - u) / 0.35, 0.0, 1.0)
	var col := Color("ffd84f").lerp(Color("ff5d5d"), clampf(float(streak_n - 2) / 3.0, 0.0, 1.0))
	var y := 432.0 - u * 20.0
	_txt(streak_txt, Vector2(3, y + 3), int(46.0 * sc), Color(0, 0, 0, 0.6 * a))
	_txt(streak_txt, Vector2(0, y), int(46.0 * sc), Color(col.r, col.g, col.b, a))


func _boss_card(u: float, acc: Color) -> void:
	if u < 0.0 or u > 3.0 or state != PLAY:
		return
	var a := clampf(minf(u / 0.2, (3.0 - u) / 0.45), 0.0, 1.0)
	var e := 1.0 - pow(1.0 - clampf(u / 0.35, 0.0, 1.0), 3.0)
	var red := Color("ff4f4f")
	draw_rect(Rect2(-60, -60, 840, 1500), Color(0, 0, 0, 0.5 * a))
	var bh := 90.0 * a
	draw_rect(Rect2(-60, 318, 840, bh), Color(0, 0, 0, 0.9))
	draw_rect(Rect2(-60, MAPB - bh, 840, bh), Color(0, 0, 0, 0.9))
	var cy := 600.0
	var bx := (1.0 - e) * -900.0
	draw_rect(Rect2(bx - 60, cy - 90, 840, 180), Color(0.05, 0.02, 0.04, 0.95 * a))
	for i in 24:
		var x := bx + float(i) * 40.0 - 60.0 + fmod(t * 50.0, 40.0)
		for yy in [cy - 90.0, cy + 78.0]:
			draw_colored_polygon(PackedVector2Array([Vector2(x, yy), Vector2(x + 20, yy), Vector2(x + 8, yy + 12), Vector2(x - 12, yy + 12)]), Color(red.r, red.g, red.b, 0.85 * a))
	_txt("WARNING", Vector2(bx, cy - 40), 26, Color(red.r, red.g, red.b, a * (0.6 + 0.4 * sin(t * 12.0))))
	var bn := String(_boss_name()).to_upper()
	_txt(bn, Vector2(bx + 3, cy + 33), 62, Color(0, 0, 0, 0.7 * a))
	_txt(bn, Vector2(bx, cy + 30), 62, Color(1, 1, 1, a))
	_txt("BOSS  -  FLOOR %d" % floor_n, Vector2(bx, cy + 66), 20, Color(acc.r, acc.g, acc.b, a))


func _frost_draw(band: Rect2, k: float) -> void:
	if frost_tx.is_empty():
		for i in 10:
			var fp := "res://art/fx/frost_%d.png" % i
			frost_tx.append(load(fp) if ResourceLoader.exists(fp) else null)
	if frost_tx[0] == null or frost_tx[9] == null:
		_frost_draw_code(band, k)
		return
	if t - frost_last > 0.4:
		frost_vis = 0.0
	frost_last = t
	frost_vis = lerpf(frost_vis, k, 0.04)
	var f := clampf((frost_vis - 0.05) / 0.95, 0.0, 1.0) * 9.0
	var i0 := int(floor(f))
	var i1 := mini(i0 + 1, 9)
	var u := f - float(i0)
	var br := 0.9 + 0.1 * sin(t * 1.6)
	var fade := 0.2 + 0.8 * clampf(f / 3.0, 0.0, 1.0)
	draw_texture_rect(frost_tx[i0], band, false, Color(1, 1, 1, br * fade))
	if u > 0.001 and i1 != i0:
		draw_texture_rect(frost_tx[i1], band, false, Color(1, 1, 1, u * br * fade))
	draw_rect(band, Color(0.7, 0.85, 1.0, 0.05 * k * (0.8 + 0.2 * sin(t * 2.0))))


# ===== B89: ComfyUI critters + frost =====
var frost_tx: Array = []
var frost_vis := 0.0
var frost_last := -10.0
var bs_png: Dictionary = {}
var crit_tx: Dictionary = {}


func _bs_tex(n: String) -> Texture2D:
	if not bs_png.has(n):
		var bp := "res://art/pickups/bs_%s_64.png" % n
		bs_png[n] = load(bp) if ResourceLoader.exists(bp) else null
	return bs_png[n]


func _spr_fl(tx: Texture2D, ctr: Vector2, size: float, flip: bool, mod: Color) -> void:
	var w := -size if flip else size
	draw_texture_rect(tx, Rect2(ctr.x - size * 0.5, ctr.y - size * 0.5, w, size), false, mod)


func _bs_term(d: Array, ctr: Vector2, locked: bool, bt: float, col: Color) -> bool:
	var id := String(d[0])
	var lit := _bs_tex(id)
	var dark := _bs_tex(id + "_dark")
	if lit == null or dark == null:
		return false
	var flip := (d[5] as Vector2i).x > 7   # right-hand terminals face left
	var sz := AC * 0.92
	if locked:
		var off := _bs_tex(id + "_off")
		_spr_fl(off if off != null else dark, ctr, sz, flip, Color.WHITE)
		return true
	_spr_fl(dark, ctr, sz, flip, Color.WHITE)
	if bt > 0.0:
		_spr_fl(lit, ctr, sz, flip, Color(1, 1, 1, clampf(bt * 1.4, 0.0, 1.0)))
	var gl := _bs_tex(id + "_glow")
	if gl != null and bt > 0.2:
		var flick := 1.0 if bt > 0.98 else (0.4 if sin(t * 45.0) > 0.3 else 1.0)
		var pa := clampf((bt - 0.2) / 0.8, 0.0, 1.0) * (0.6 + 0.25 * sin(t * 2.4 + ctr.x * 0.01)) * flick
		_spr_fl(gl, ctr, sz * 1.18, flip, Color(col.r, col.g, col.b, pa * 0.45))
		_spr_fl(gl, ctr, sz, flip, Color(lerpf(col.r, 1.0, 0.5), lerpf(col.g, 1.0, 0.5), lerpf(col.b, 1.0, 0.5), pa * 0.7))
	return true


func _crit_tex(k: String) -> Texture2D:
	if not crit_tx.has(k):
		var cp := "res://art/critters/%s.png" % k
		crit_tx[k] = load(cp) if ResourceLoader.exists(cp) else null
	return crit_tx[k]


func _crit_blit(tx: Texture2D, foot: Vector2, s: float, sx: float, c: Color) -> void:
	var w := s * sx
	draw_texture_rect(tx, Rect2(foot.x - absf(w) * 0.5, foot.y - s, w, s), false, c)


func _crit_draw(m: Dictionary, q2: Vector2, a2: float, acc: Color, moving: bool, dv: Vector2) -> bool:
	var k := String(m["k"])
	var tx := _crit_tex(k)
	if tx == null or true:   # live critters use the code-drawn versions (smooth rotation)
		return false
	var ph: float = m["ph"]
	var fx0 := float(m.get("fx", 1.0))
	var tgt := -1.0 if dv.x < 0.0 else (1.0 if dv.x > 0.0 else (1.0 if fx0 >= 0.0 else -1.0))
	var fx := move_toward(fx0, tgt, get_process_delta_time() * 7.0)
	m["fx"] = fx
	var fl := fx if absf(fx) > 0.12 else (0.12 if fx >= 0.0 else -0.12)
	var c := Color(1, 1, 1, a2)
	match k:
		"rat":
			var hop := absf(sin(t * 18.0)) * AC * 0.03 if moving else 0.0
			draw_circle(q2 + Vector2(0, AC * 0.2), AC * 0.12, Color(0, 0, 0, 0.25 * a2))
			_crit_blit(tx, q2 + Vector2(0, AC * 0.22 - hop), AC * 0.46, fl, c)
		"bot":
			var bob := sin(t * (16.0 if moving else 3.0) + ph) * AC * 0.012
			draw_circle(q2 + Vector2(0, AC * 0.2), AC * 0.16, Color(0, 0, 0, 0.3 * a2))
			var spin := t * (14.0 if moving else 4.0) + ph
			for bs in [-1.0, 1.0]:
				var bc := q2 + Vector2(bs * AC * 0.15 * absf(fl), AC * 0.19)
				for bi in 3:
					var bv := Vector2.from_angle(spin * bs + float(bi) * TAU / 3.0) * AC * 0.09
					draw_line(bc, bc + Vector2(bv.x, bv.y * 0.5), Color(0.8, 0.75, 0.5, a2 * 0.85), 2.0)
			_crit_blit(tx, q2 + Vector2(0, AC * 0.22 + bob), AC * 0.5, fl, c)
		"moth":
			var hv := q2 + Vector2(sin(t * 1.9 + ph) * AC * 0.18, -AC * 0.22 + sin(t * 3.7 + ph) * AC * 0.08)
			var fw := 0.55 + 0.45 * absf(sin(t * 22.0 + ph))
			draw_circle(hv, AC * 0.16, Color(1, 0.8, 0.95, 0.1 * a2))
			_crit_blit(tx, hv + Vector2(0, AC * 0.18), AC * 0.4, fw * fl, c)
		_:
			var wq := q2 + Vector2(0, -AC * 0.2 + sin(t * 2.3 + ph) * AC * 0.1)
			var g2 := 0.6 + 0.4 * sin(t * 4.0 + ph)
			draw_circle(wq, AC * 0.24, Color(acc.r, acc.g, acc.b, 0.1 * a2 * g2))
			_crit_blit(tx, wq + Vector2(0, AC * 0.2), AC * 0.4, fl, Color(1, 1, 1, a2 * (0.8 + 0.2 * g2)))
	return true


func _frost_draw_code(band: Rect2, k: float) -> void:
	var fc := Color(0.82, 0.93, 1.0)
	for i in 9:
		var fade := 1.0 - float(i) / 9.0
		draw_rect(band.grow(-float(i) * 6.0), Color(fc.r, fc.g, fc.b, 0.13 * k * fade * fade), false, 6.0)
	var w := band.size.x
	var h := band.size.y
	var per := 2.0 * (w + h)
	for j in 56:
		var hh := float((j * 7919) % 997) / 997.0
		var s := float(j) / 56.0 * per + hh * 30.0
		var p: Vector2
		var inw: Vector2
		if s < w:
			p = band.position + Vector2(s, 0)
			inw = Vector2(0, 1)
		elif s < w + h:
			p = band.position + Vector2(w, s - w)
			inw = Vector2(-1, 0)
		elif s < 2.0 * w + h:
			p = band.position + Vector2(w - (s - w - h), h)
			inw = Vector2(0, -1)
		else:
			p = band.position + Vector2(0, h - (s - 2.0 * w - h))
			inw = Vector2(1, 0)
		var ln := (14.0 + 46.0 * hh) * k
		var dir := inw.rotated((hh - 0.5) * 0.9)
		var col := Color(fc.r, fc.g, fc.b, (0.35 + 0.3 * hh) * k)
		draw_line(p, p + dir * ln, col, 2.0)
		var mid := p + dir * ln * 0.55
		draw_line(mid, mid + dir.rotated(0.7) * ln * 0.35, col, 1.5)
		draw_line(mid, mid + dir.rotated(-0.7) * ln * 0.35, col, 1.5)
	draw_rect(band, Color(0.7, 0.85, 1.0, 0.04 * k * (0.8 + 0.2 * sin(t * 2.0))))


func _o2_muffle(dt: float) -> void:
	var want := 0.0
	if mode == "adv" and state == PLAY and oxy_max > 0.0 and oxy < oxy_max * 0.25:
		want = clampf(1.0 - oxy / (oxy_max * 0.25), 0.25, 1.0)
	muf = move_toward(muf, want, dt * 1.5)
	if lp_fx == null:
		if muf <= 0.0:
			return
		lp_fx = AudioEffectLowPassFilter.new()
		AudioServer.add_bus_effect(0, lp_fx)
		lp_idx = AudioServer.get_bus_effect_count(0) - 1
	AudioServer.set_bus_effect_enabled(0, lp_idx, muf > 0.01)
	lp_fx.cutoff_hz = lerpf(12000.0, 650.0, muf)

# ===== B91: stealth (sneak attacks, suspicion, shadows, stealth tools) and critter behaviours =====
var floor_spotted := false
var run_ghost := 0
var smoke_c := Vector2i(-1, -1)
var smoke_steps := 0
var noise_c := Vector2i(-1, -1)
var noise_steps := 0
var amark: Dictionary = {}       # Assassin's Mark: cell -> steps left
var st_hit_c := Vector2i(-1, -1) # target of the sneak attack being resolved
var st_quiet := false            # the current hit makes no noise
var st_was_cloaked := false      # a cloak broke on this action
var st_shadow: Dictionary = {}
var st_sh_key := ""


func _hidden() -> bool:
	return cloak_steps > 0 or (smoke_steps > 0 and _cheb(pos, smoke_c) <= 2)


func _st_build_shadow() -> void:
	st_sh_key = amb_key
	st_shadow.clear()
	if in_base or arena or adv_open.size() != AW * AH:
		return
	var pct := 36 if amb_ev == "brownout" else 22
	var lights: Array = stations.keys() + merchants.keys()
	for y in AH:
		for x in AW:
			var c := Vector2i(x, y)
			if not _aopen(c):
				continue
			if absi(hash(Vector3i(x / 3, y / 3, floor_n * 977 + adv_seed))) % 100 >= pct or absi(hash(c * 7 + Vector2i(adv_seed, floor_n))) % 100 >= 85:
				continue
			var lit := false
			for l in lights:
				if _cheb(l, c) <= 2:
					lit = true
					break
			if not lit:
				st_shadow[c] = true


func _st_shadow(c: Vector2i) -> bool:
	if mode != "adv":
		return false
	if st_sh_key != amb_key:
		_st_build_shadow()
	return st_shadow.has(c)


func _cone_r() -> int:
	return maxi(1, 3 - (1 if _st_shadow(pos) else 0) - int(sk("st_cone")))


func _st_sees(c: Vector2i) -> bool:
	var md: Dictionary = mon_idle[c]
	var s := String(md["s"])
	if s == "sleep":
		return false
	if smoke_steps > 0 and _cheb(c, smoke_c) <= 2:
		return false
	var dv4 := [Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]
	var fd: Vector2i = dv4[_idle_dir(c)]
	var to: Vector2i = pos - c
	var fw := to.x * fd.x + to.y * fd.y
	var lat := absi(to.x * fd.y - to.y * fd.x)
	if fw < 1 or fw > _cone_r():
		return false
	if s == "talk":
		if lat > 1:
			return false
	elif lat > fw:
		return false
	return _idle_los(c, pos)


# an enemy that hasn't seen you: idle (asleep, chatting, watching) or you are cloaked
func _st_unaware(c: Vector2i) -> bool:
	if mode != "adv" or not mons.has(c) or (boss_floor and c == boss_cell):
		return false
	return mon_idle.has(c) or cloak_steps > 0 or st_was_cloaked


# a sneak attack that didn't kill: the target wakes (and its chat partner), unless Assassin's Mark silences it
func _st_after_hit(c: Vector2i) -> void:
	st_hit_c = Vector2i(-1, -1)
	st_quiet = false
	if not mons.has(c):
		return
	if relic_n("amark") > 0:
		mon_idle.erase(c)
		amark[c] = 3
		_pop(c, "MARKED", Color("c07cff"))
	else:
		_idle_wake(c)


# called from _adv_kill before the monster is removed; true for an unseen kill
func _st_on_kill(nc: Vector2i) -> bool:
	if mode != "adv":
		return false
	var un := st_hit_c == nc or mon_idle.has(nc) or cloak_steps > 0 or st_was_cloaked or amark.has(nc)
	st_hit_c = Vector2i(-1, -1)
	st_quiet = false
	amark.erase(nc)
	if mon_idle.has(nc):
		var md: Dictionary = mon_idle[nc]
		if String(md["s"]) == "talk":
			var pc: Vector2i = md["p"]
			if mon_idle.has(pc):
				var dl: Vector2i = nc - pc
				mon_idle[pc]["s"] = "look"
				mon_idle[pc]["fd"] = (3 if dl.x > 0 else 2) if absi(dl.x) > absi(dl.y) else (0 if dl.y >= 0 else 1)
				_pop(pc, "?", Color("ffd84f"))
		mon_idle.erase(nc)
	if not un or (boss_floor and nc == boss_cell):
		return false
	_pop(nc, "SILENT", Color("c07cff"))
	if sk("st_air") > 0.0:
		oxy = minf(oxy_max, oxy + sk("st_air"))
	if sk("st_vanish") > 0.0:
		cloak_steps = maxi(cloak_steps, int(sk("st_vanish")))
	if relic_n("lullaby") > 0 and randf() < 0.25:
		var best := Vector2i(-1, -1)
		var bd := 99
		for m in mons:
			if m == nc or mon_idle.has(m) or not _idle_ok(m) or not adv_vis.has(m):
				continue
			var d := _cheb(m, nc)
			if d < bd and d <= 6:
				bd = d
				best = m
		if best.x >= 0:
			mon_idle[best] = {"s": "sleep", "ph": 0, "sus": 0, "zz": 8}
			amark.erase(best)
			_pop(best, "ZZZ", Color("c9a2ff"))
	return true


func _st_floor_reset() -> void:
	floor_spotted = false
	smoke_steps = 0
	noise_steps = 0
	amark.clear()
	st_hit_c = Vector2i(-1, -1)
	st_quiet = false
	st_was_cloaked = false


# once per turn (step or shot)
func _st_tick() -> void:
	if mode != "adv":
		return
	st_was_cloaked = false
	st_quiet = false
	st_hit_c = Vector2i(-1, -1)
	if smoke_steps > 0:
		smoke_steps -= 1
	if noise_steps > 0:
		noise_steps -= 1
		if noise_steps == 0:
			for c in mon_idle:
				(mon_idle[c] as Dictionary).erase("fd")
	for c in amark.keys():
		amark[c] = int(amark[c]) - 1
		if int(amark[c]) <= 0 or not mons.has(c):
			amark.erase(c)
	for c in mon_idle.keys():
		var md: Dictionary = mon_idle[c]
		if md.has("zz"):
			md["zz"] = int(md["zz"]) - 1
			if int(md["zz"]) <= 0:
				md.erase("zz")
				md["s"] = "look"
				md["ph"] = randi() % 4
				md["sus"] = 0
				_pop(c, "?", Color("ffd84f"))
	if cloak_steps > 0:
		return
	for m in amb_crit:
		if m.get("dead", false) or String(m["k"]) != "rat":
			continue
		var mp: Vector2 = m["p"]
		var rc := Vector2i(roundi(mp.x), roundi(mp.y))
		if _cheb(rc, pos) > 2 or adv_steps - int(m.get("sq", -99)) < 4:
			continue
		m["sq"] = adv_steps
		_pop(rc, "SQUEAK", Color("ffb0a0"))
		_sfx("ui", 1.8)
		for o in mon_idle:
			if String(mon_idle[o]["s"]) == "sleep" and _cheb(o, rc) <= 2:
				mon_idle[o]["hear"] = 1


# critter goals: everything flees awake hunters, rats flee you, moths seek light, wisps drift to vaults
func _crit_goal(m: Dictionary, c: Vector2i) -> Vector2:
	var k := String(m["k"])
	var flee := Vector2.ZERO
	for hc in kinds:
		var kd := String(kinds[hc])
		if (kd == "hunter" or kd == "rager" or kd == "drone") and mons.has(hc) and not mon_idle.has(hc) and _cheb(hc, c) <= 3:
			flee += Vector2(c - hc).normalized()
	if k == "rat" and cloak_steps <= 0 and _cheb(c, pos) <= 2:
		flee += Vector2(c - pos).normalized() * 1.5
	m["scared"] = flee != Vector2.ZERO
	if flee != Vector2.ZERO:
		return flee.normalized()
	var tgts: Array = []
	var rng := 0
	if k == "moth":
		tgts = stations.keys() + merchants.keys()
		rng = 7
	elif k == "wisp":
		tgts = vaults.keys()
		rng = 12
	var best := Vector2i(-1, -1)
	var bd := 999
	for g in tgts:
		var d := _cheb(g, c)
		if d < bd and d <= rng:
			bd = d
			best = g
	if best.x < 0 or bd <= 1:
		return Vector2.ZERO
	return Vector2(best - c).normalized()


func _st_world_draw() -> void:
	if mode != "adv":
		return
	if st_sh_key != amb_key:
		_st_build_shadow()
	for c in st_shadow:
		if not _aseen(c):
			continue
		var a := 1.0 - _fog_a(c, 0.55)
		if a < 0.05:
			continue
		draw_rect(Rect2(_actr(c) - Vector2(AC * 0.5, AC * 0.5), Vector2(AC, AC)), Color(0.02, 0.03, 0.09, 0.34 * a))
	if smoke_steps > 0 and _aseen(smoke_c):
		var sc := _actr(smoke_c)
		var sa := clampf(float(smoke_steps) / 2.0, 0.3, 1.0)
		for i in 9:
			var an := float(i) * TAU / 9.0 + t * 0.3
			var rr := AC * (1.2 + 0.5 * sin(t * 0.8 + float(i)))
			draw_circle(sc + Vector2(cos(an), sin(an)) * rr, AC * (0.9 + 0.15 * sin(t + float(i) * 2.0)), Color(0.72, 0.76, 0.84, 0.16 * sa))
		draw_circle(sc, AC * 1.3, Color(0.75, 0.78, 0.86, 0.2 * sa))
	if noise_steps > 0 and _aseen(noise_c):
		var nq := _actr(noise_c)
		var u := fmod(t * 1.4, 1.0)
		draw_arc(nq, AC * (0.3 + 1.2 * u), 0, TAU, 24, Color(1, 0.7, 0.3, 0.6 * (1.0 - u)), 3.0)
		draw_circle(nq, AC * 0.12, Color("ffb347"))



const T_TITLE := 48


const T_HEAD := 28


const T_BODY := 20


const T_SMALL := 16


const C_GOLD := Color(1.0, 0.847, 0.31)


const C_INFO := Color(0.498, 0.847, 1.0)


const C_GOOD := Color(0.427, 1.0, 0.604)


const C_BAD := Color(1.0, 0.416, 0.361)


const C_RARE := Color(0.753, 0.486, 1.0)


const C_DIM := Color(1, 1, 1, 0.55)


const C_TEXT := Color(1, 1, 1, 0.92)


func _frame(r: Rect2, col: Color, sel := false) -> void:
	_obox(r, Color(col.r, col.g, col.b, 0.2 if sel else 0.07))
	_aline(r, Color(col.r, col.g, col.b, 0.95 if sel else 0.45), 3.0 if sel else 2.0)


func _section(title: String, y: float, col := C_GOLD, x := 40.0, w := 640.0) -> float:
	_txt(title, Vector2(x + 6, y + 22), T_SMALL, col, w - 12.0, HORIZONTAL_ALIGNMENT_LEFT)
	draw_line(Vector2(x, y + 32), Vector2(x + w, y + 32), Color(col.r, col.g, col.b, 0.35), 2.0)
	return y + 40.0


func _stat_row(r: Rect2, label: String, value: String, vcol := Color.WHITE, size := T_BODY, vsize := -1) -> void:
	var vs := size if vsize < 0 else vsize
	var cy := r.position.y + r.size.y * 0.5
	_txt(label, Vector2(r.position.x + 12, cy + size * 0.36), size, C_DIM, r.size.x * 0.62, HORIZONTAL_ALIGNMENT_LEFT)
	_txt(value, Vector2(r.position.x + r.size.x * 0.38 - 12, cy + vs * 0.36), vs, vcol, r.size.x * 0.62, HORIZONTAL_ALIGNMENT_RIGHT)


func _chip(r: Rect2, s: String, col: Color, sel := false) -> void:
	_frame(r, col, sel)
	var fs := _fit(s, T_SMALL, r.size.x - 8)
	draw_string(font, Vector2(r.position.x, r.get_center().y + fs * 0.36), s, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, col)


func _dots(n: int, cur: int, c: Vector2, col := C_GOLD) -> void:
	for i in n:
		var p := Vector2(c.x + (i - (n - 1) * 0.5) * 28.0, c.y)
		draw_circle(p, 8.0 if i == cur else 5.0, col if i == cur else Color(1, 1, 1, 0.3))


func _bullets(lines: Array, p: Vector2, w: float, size := T_BODY, col := C_TEXT, dot := C_GOLD) -> float:
	var y := p.y
	for s in lines:
		draw_circle(Vector2(p.x + 6, y + size * 0.6), 4.0, dot)
		var sz := font.get_multiline_string_size(String(s), HORIZONTAL_ALIGNMENT_LEFT, w - 24.0, size)
		draw_multiline_string(font, Vector2(p.x + 24, y + font.get_ascent(size)), String(s), HORIZONTAL_ALIGNMENT_LEFT, w - 24.0, size, -1, col)
		y += sz.y + size * 0.6
	return y


var slot_sel := -1   # equipped slot being inspected on the gear tab


var stat_open := -1  # stats tab row whose explanation is shown


var stat_hits: Array = []


const RELIC_PP := 7


const STAT_LBL := {
	"atk": ["ATTACK", "+%d"], "crit": ["CRIT", "%d%%"], "leech": ["LIFESTEAL", "%d"], "armor": ["ARMOUR", "+%d"], "hp": ["MAX HP", "+%d"],
	"shield": ["START SHIELD", "+%d"], "air": ["MAX AIR", "+%d"], "airsave": ["AIR SAVING", "%d%%"], "sight": ["SIGHT", "+%d"],
	"xp": ["XP", "+%d%%"], "coin": ["COIN VALUE", "+%d"], "dodge": ["DODGE", "%d%%"], "thorns": ["THORNS", "%d"], "killheal": ["KILL HEAL", "%d"],
	"pod": ["POD AIR", "+%d"], "range": ["RANGE", "%d"], "rangeb": ["RANGE BONUS", "+%d"], "noammo": ["FREE SHOT", "%d%%"], "rangedef": ["SHOT DEFENCE", "-%d"], "hazres": ["HAZARD RESIST", "%d%%"],
}


func _card_rect() -> Rect2:
	return Rect2(40, 586, 640, 300)


func _pack_cell(k: int) -> Rect2:
	return Rect2(47 + (k % 6) * 106, 936 + (k / 6) * 106, 96, 96)


func _card_gid() -> String:
	if chr_sel >= 0 and chr_sel < bag.size():
		return String(bag[chr_sel])
	if slot_sel >= 0:
		return String(equip.get(String(CHR_SLOTS[slot_sel]), ""))
	return ""


func _gear_rows(gid: String, cmp: String) -> Array:
	var a: Dictionary = gstats(gid)
	var b: Dictionary = gstats(cmp) if cmp != "" else {}
	var keys: Array = a.keys()
	for k in b.keys():
		if not keys.has(k):
			keys.append(k)
	var out: Array = []
	for k in keys:
		var lb: Array = STAT_LBL.get(k, [String(k).to_upper(), "+%d"])
		var v := int(a.get(k, 0))
		var dv := 0
		if cmp != "":
			dv = v - int(b.get(k, 0))
		out.append([String(lb[0]), (String(lb[1]) % v) if a.has(k) else "-", dv])
	return out


func _gear_better(gid: String) -> int:
	var sl := String(gear_defs[gb(gid)]["slot"])
	var cur := String(equip.get(sl, ""))
	if cur == "":
		return 1
	var wts := {"ATTACK": 3.0, "ARMOUR": 3.0, "MAX HP": 0.3}
	var sc := 0.0
	for r in _gear_rows(gid, cur):
		sc += float(r[2]) * float(wts.get(String(r[0]), 1.0))
	sc += 2.0 * (gtr(gid).size() + gmods(gid).size() - gtr(cur).size() - gmods(cur).size())
	return 1 if sc > 0.0 else (-1 if sc < 0.0 else 0)


func _card_btns() -> Array:
	var out: Array = []
	var r := _card_rect()
	if chr_sel >= 0 and chr_sel < bag.size():
		var bid := String(bag[chr_sel])
		out.append(["equip", "EQUIP", C_GOOD])
		out.append(["sell", "SELL %d" % _sell_val(bid), C_GOLD])
		if sk("reforge") > 0.0:
			out.append(["forge", "FORGE %d" % _forge_cost(bid), Color("c9a36b") if scrap >= _forge_cost(bid) else Color(1, 1, 1, 0.35)])
		if _fuse_ok(chr_sel):
			out.append(["fuse", "FUSE", C_RARE])
	elif _card_gid() != "":
		out.append(["unequip", "UNEQUIP", C_INFO])
	var n := out.size()
	var w := (r.size.x - 24.0 - 10.0 * (n - 1)) / maxf(1.0, float(n))
	for i in n:
		out[i].append(Rect2(r.position.x + 12 + i * (w + 10.0), r.end.y - 58, w, 48))
	return out


func _draw_gear_totals(r: Rect2) -> void:
	var y := _section("EQUIPPED", r.position.y + 6, C_INFO, r.position.x + 12, r.size.x - 24)
	var rows := [["ATTACK", "%d" % p_atk()], ["ARMOUR", "%d" % armor_total()], ["MAX HEALTH", "%d" % hp_cap()], ["MAX SHIELD", "%d" % sh_cap()]]
	for i in rows.size():
		_stat_row(Rect2(r.position.x + 12 + (i % 2) * 312, y + (i / 2) * 40, 304, 36), String(rows[i][0]), String(rows[i][1]))
	y += 86.0
	var sl := _set_lines().strip_edges()
	if sl != "":
		y = _section("SET BONUSES", y, C_GOOD, r.position.x + 12, r.size.x - 24)
		for ln in sl.split("\n"):
			if y > r.end.y - 20:
				break
			_txt(ln.replace("[SET] ", ""), Vector2(r.position.x + 18, y + 16), T_SMALL, C_GOOD, r.size.x - 36, HORIZONTAL_ALIGNMENT_LEFT)
			y += 26.0
	else:
		_txt("Tap a slot or item to inspect it", Vector2(r.position.x, r.end.y - 30), T_SMALL, C_DIM, r.size.x)


func _draw_item_card() -> void:
	var r := _card_rect()
	var gid := _card_gid()
	if gid == "":
		_frame(r, C_INFO)
		_draw_gear_totals(r)
		return
	var gd: Dictionary = gear_defs[gb(gid)]
	var slot := String(gd["slot"])
	var tc := _tier_col(int(gd["tier"]))
	_frame(r, tc, true)
	_spr(_gear_tex(gid), r.position + Vector2(48, 44), 60.0)
	_txt(gname(gid), r.position + Vector2(92, 40), T_HEAD, tc, 530.0, HORIZONTAL_ALIGNMENT_LEFT)
	var cmp := ""
	if chr_sel >= 0:
		cmp = String(equip.get(slot, ""))
	_txt("TIER %d  %s" % [int(gd["tier"]), slot.to_upper()], r.position + Vector2(92, 66), T_SMALL, _gear_col(slot), 240.0, HORIZONTAL_ALIGNMENT_LEFT)
	if chr_sel >= 0:
		_txt(("vs " + gname(cmp)) if cmp != "" else "slot empty", r.position + Vector2(336, 66), T_SMALL, C_DIM, 290.0, HORIZONTAL_ALIGNMENT_RIGHT)
	var stats := _gear_rows(gid, cmp)
	var txts: Array = []   # [name, text, colour]
	for tid in gtr(gid):
		txts.append([String(TRAIT_DEFS[tid]["n"]), String(TRAIT_DEFS[tid]["d"]), C_GOLD])
	for mid in gmods(gid):
		txts.append([String(MOD_DEFS[mid]["n"]), String(MOD_DEFS[mid]["d"]), C_INFO])
	for sid in GEAR_SETS:
		var g: Array = GEAR_SETS[sid]
		if (g[1] as Array).has(gb(gid)):
			txts.append(["%s SET %d/%d" % [String(g[0]).to_upper(), set_n(String(sid)), (g[1] as Array).size()], "2: " + String(g[2]), C_GOOD])
			txts.append(["", "3: " + String(g[3]), C_GOOD])
	var y0 := r.position.y + 82.0
	var y1 := r.end.y - 64.0
	var srows := (stats.size() + 1) / 2
	var two := (srows + txts.size() * 2) * 26.0 <= y1 - y0
	var n := srows + txts.size() * (2 if two else 1)
	var rh := clampf((y1 - y0) / maxf(1.0, float(n)), 22.0, 34.0)
	var y := y0
	for i in stats.size():
		var s: Array = stats[i]
		var dv := int(s[2])
		var vt := String(s[1]) + (("  (%+d)" % dv) if dv != 0 else "")
		_stat_row(Rect2(r.position.x + 12 + (i % 2) * 312, y + (i / 2) * rh, 304, rh), String(s[0]), vt, C_GOOD if dv > 0 else (C_BAD if dv < 0 else Color.WHITE), T_SMALL)
	y += srows * rh
	for tx in txts:
		if y + rh > y1 + 4.0:
			break
		var tcol: Color = tx[2]
		if two:
			if String(tx[0]) != "":
				_txt(String(tx[0]), Vector2(r.position.x + 24, y + rh * 0.7), T_SMALL, tcol, 600.0, HORIZONTAL_ALIGNMENT_LEFT)
				y += rh
			_txt(String(tx[1]), Vector2(r.position.x + 24, y + rh * 0.7), T_SMALL, C_TEXT, 600.0, HORIZONTAL_ALIGNMENT_LEFT)
		else:
			_txt(String(tx[0]), Vector2(r.position.x + 24, y + rh * 0.7), T_SMALL, tcol, 190.0, HORIZONTAL_ALIGNMENT_LEFT)
			_txt(String(tx[1]), Vector2(r.position.x + 220, y + rh * 0.7), T_SMALL, C_TEXT, 404.0, HORIZONTAL_ALIGNMENT_LEFT)
		y += rh
	for b in _card_btns():
		_button(b[3], String(b[1]), b[2], 20)


func _card_act(id: String) -> void:
	var k := chr_sel
	if id == "unequip":
		if _adv_unequip(String(CHR_SLOTS[slot_sel])):
			slot_sel = -1
			_sfx("ui")
		else:
			_sfx("blocked")
	elif id == "equip":
		_adv_equip(bag[k])
		chr_sel = -1
		_sfx("shield")
	elif id == "forge":
		_reforge(k)
	elif id == "fuse":
		_fuse(k)
		chr_sel = -1
	elif id == "sell":
		if gmods(String(bag[k])).has("heartstation"):
			_pop(pos, "CAN'T SELL", C_BAD)
			_sfx("blocked")
			return
		coins += _sell_val(String(bag[k]))
		scrap += int(gear_defs[gb(String(bag[k]))]["tier"]) * (int(sk("dismantle")) * (2 if gm("salvcore") else 1) + (1 if gm("salvcore") else 0))
		if gm("salvcore") and randf() < 0.15:
			_give_use(_random_use())
		bag.remove_at(k)
		chr_sel = -1
		_asm_build()
		_sfx("coin")


func _stat_empty(v: String) -> bool:
	var s := v.strip_edges()
	if s == "none":
		return true
	var num := s.get_slice(" ", 0).replace("+", "").replace("-", "").replace("%", "").replace("x", "")
	return num.is_valid_float() and float(num) == 0.0


func _stat_list() -> Array:
	var rows: Array = [
		["#CORE"],
		["LEVEL", "%d" % level, "Each level adds attack and max health."],
		["XP", "%d / %d" % [xp, xp_need()], "Kills, potions and vaults give XP."],
		["HEALTH", "%d / %d" % [hp, hp_cap()], "Reach 0 and you die."],
		["ATTACK", "%d" % p_atk(), "Damage per hit."],
		["ARMOUR", "%d" % armor_total(), "Cuts every hit you take (minimum 1)."],
		["SHIELD", "%d / %d" % [sh, sh_cap()], "Soaks damage before your health."],
		["AIR", "%d / %d" % [int(ceil(oxy)), int(oxy_max)], "Each step costs air. O2 stations refill it."],
		["POINTS", "%d / %d" % [adv_pts, adv_req], "Fill this to open the exit."],
		["COINS", "%d" % coins, "Spend at Outfitters and the Station Base."],
	]
	for r in _inv_extra_rows():
		if r.size() == 1 or not _stat_empty(String(r[1])):
			rows.append(r)
	var out: Array = []
	for i in rows.size():
		if rows[i].size() == 1 and (i + 1 >= rows.size() or rows[i + 1].size() == 1):
			continue
		out.append(rows[i])
	return out


func _stat_tap(p: Vector2) -> void:
	for h in stat_hits:
		if (h[0] as Rect2).has_point(p):
			stat_open = -1 if stat_open == int(h[1]) else int(h[1])
			_sfx("ui")
			return


var tut_sw := Vector2(-1, -1)   # tutorial swipe start


var btn_cdet := Rect2(250, 884, 220, 48)


var cls_det := false


var lst_off := 0          # first visible row in the scrollable shop / workshop lists


var lst_on := false


var lst_moved := false


var lst_press := Vector2.ZERO


var lst_acc := 0.0


const SYM := {
	"p_elem": ["flame", "ff8a3d"], "p_blood": ["drop", "ff4f5e"], "p_combo": ["bolt", "ffd84f"], "p_relic": ["gem", "c07cff"],
	"p_fort": ["coin", "ffc93c"], "p_surv": ["shield", "5aa8ff"], "p_curse": ["skull", "ff5d8f"], "head": ["star", "ffd84f"],
	"ash": ["flame", "ff5d3d"], "p_echo": ["echo", "7fd8ff"], "p_mom": ["arrows", "6dff9a"], "p_gamb": ["die", "f2f2f2"],
	"p_para": ["eye", "b56dff"], "p_swarm": ["swarm", "9dff6a"],
	"kit": ["crate", "c9a36b"], "toolbox": ["toolbox", "ff9a4f"], "suit": ["shield", "9fb3d9"], "tank": ["tank", "7fd8ff"],
	"belt": ["bullets", "ffc24f"], "sp": ["nodes", "c07cff"], "vet": ["chevrons", "ffd84f"],
	"w_hull": ["cross", "ff5d6a"], "w_o2": ["tank", "7fd8ff"], "w_train": ["chevrons", "6dff9a"], "w_bank": ["coin", "ffc93c"],
	"w_crit": ["crosshair", "ff8a4f"], "w_dodge": ["arrows", "9aa3c7"], "w_deal": ["tag", "ffd84f"], "w_mast": ["star", "ff4fd8"],
	"w_atk": ["sword", "ff8a4f"], "w_arm": ["shield", "c9d3f0"], "w_sp": ["nodes", "c07cff"], "w_slot": ["grid", "4fd1c5"],
	"ct_kills": ["crosshair", "ff6a5c"], "ct_elites": ["skull", "c07cff"], "ct_floor": ["chevrons", "6dff9a"], "ct_bosses": ["core", "ff4fd8"],
	"ct_coins": ["coin", "ffc93c"], "ct_cls": ["star", "7fd8ff"], "ct_threat": ["skull", "ff4f5e"], "ct_ghost": ["eye", "9aa3c7"],
	"ct_level": ["chevrons", "ffd84f"], "ct_relics": ["gem", "c07cff"], "ct_scrap": ["scrap", "c9a36b"], "ct_skills": ["nodes", "c07cff"],
	"ct_tier": ["shield", "ff4fd8"],
}


func _poly(c: Vector2, s: float, pts: Array, col: Color) -> void:
	var pv := PackedVector2Array()
	for q in pts:
		pv.append(c + Vector2(q[0], q[1]) * s)
	draw_colored_polygon(pv, col)


func _sym(kind: String, c: Vector2, s: float, col: Color) -> void:
	var dk := Color(col.r * 0.35, col.g * 0.35, col.b * 0.35)
	var lt := col.lerp(Color.WHITE, 0.55)
	match kind:
		"flame", "drop":
			draw_circle(c + Vector2(0, 0.28) * s, 0.62 * s, col)
			_poly(c, s, [[-0.6, 0.12], [0.6, 0.12], [0, -0.95]], col)
			if kind == "flame":
				draw_circle(c + Vector2(0, 0.42) * s, 0.32 * s, Color("ffe14f"))
				_poly(c, s, [[-0.3, 0.36], [0.3, 0.36], [0, -0.25]], Color("ffe14f"))
			else:
				draw_circle(c + Vector2(-0.22, 0.2) * s, 0.13 * s, lt)
		"bolt":
			_poly(c, s, [[0.2, -1.0], [-0.55, 0.12], [-0.05, 0.12], [-0.25, 1.0], [0.55, -0.18], [0.05, -0.18]], col)
		"gem":
			_poly(c, s, [[0, -0.9], [0.78, -0.25], [0, 0.95], [-0.78, -0.25]], col)
			_poly(c, s, [[0, -0.9], [0.78, -0.25], [0, -0.1], [-0.78, -0.25]], lt)
		"coin":
			draw_circle(c, 0.82 * s, col)
			draw_arc(c, 0.58 * s, 0.0, TAU, 24, dk, 0.12 * s)
			draw_rect(Rect2(c - Vector2(0.1, 0.32) * s, Vector2(0.2, 0.64) * s), dk)
		"shield":
			_poly(c, s, [[-0.78, -0.82], [0.78, -0.82], [0.78, 0.05], [0, 0.95], [-0.78, 0.05]], col)
			_poly(c, s, [[-0.5, -0.58], [0.5, -0.58], [0.5, 0.0], [0, 0.6], [-0.5, 0.0]], dk)
			_poly(c, s, [[-0.5, -0.58], [0, -0.58], [0, 0.6], [-0.5, 0.0]], lt)
		"skull":
			draw_circle(c + Vector2(0, -0.18) * s, 0.72 * s, col)
			draw_rect(Rect2(c + Vector2(-0.42, 0.22) * s, Vector2(0.84, 0.6) * s), col)
			draw_circle(c + Vector2(-0.28, -0.15) * s, 0.2 * s, dk)
			draw_circle(c + Vector2(0.28, -0.15) * s, 0.2 * s, dk)
			for k in 3:
				draw_rect(Rect2(c + Vector2(-0.3 + k * 0.22, 0.52) * s, Vector2(0.1, 0.3) * s), dk)
		"star":
			_star(c, 0.95 * s, col)
		"echo":
			draw_circle(c + Vector2(-0.55, 0) * s, 0.2 * s, col)
			for k in 3:
				draw_arc(c + Vector2(-0.55, 0) * s, (0.45 + 0.32 * k) * s, -0.9, 0.9, 12, col if k < 2 else lt, 0.14 * s)
		"arrows":
			for k in 2:
				var ox := -0.45 + k * 0.6
				draw_polyline(PackedVector2Array([c + Vector2(ox - 0.25, -0.6) * s, c + Vector2(ox + 0.3, 0) * s, c + Vector2(ox - 0.25, 0.6) * s]), col if k == 1 else lt, 0.22 * s)
		"die":
			draw_rect(Rect2(c - Vector2(0.75, 0.75) * s, Vector2(1.5, 1.5) * s), col)
			for q in [[-0.4, -0.4], [0.4, -0.4], [0, 0], [-0.4, 0.4], [0.4, 0.4]]:
				draw_circle(c + Vector2(q[0], q[1]) * s, 0.14 * s, Color("1a1d2b"))
		"eye":
			_poly(c, s, [[-0.95, 0], [-0.5, -0.5], [0, -0.62], [0.5, -0.5], [0.95, 0], [0.5, 0.5], [0, 0.62], [-0.5, 0.5]], col)
			draw_circle(c, 0.36 * s, dk)
			draw_circle(c + Vector2(-0.1, -0.1) * s, 0.12 * s, lt)
		"swarm":
			for q in [[-0.5, -0.4], [0.3, -0.6], [0.6, 0.1], [-0.1, 0.1], [-0.6, 0.5], [0.25, 0.6]]:
				draw_circle(c + Vector2(q[0], q[1]) * s, 0.2 * s, col)
		"crate":
			draw_rect(Rect2(c - Vector2(0.8, 0.7) * s, Vector2(1.6, 1.4) * s), col)
			draw_rect(Rect2(c - Vector2(0.8, 0.7) * s, Vector2(1.6, 1.4) * s), dk, false, 0.12 * s)
			draw_line(c + Vector2(-0.8, -0.7) * s, c + Vector2(0.8, 0.7) * s, dk, 0.12 * s)
			draw_line(c + Vector2(0.8, -0.7) * s, c + Vector2(-0.8, 0.7) * s, dk, 0.12 * s)
		"toolbox":
			draw_arc(c + Vector2(0, -0.35) * s, 0.35 * s, PI, TAU, 10, col, 0.16 * s)
			draw_rect(Rect2(c + Vector2(-0.85, -0.35) * s, Vector2(1.7, 1.1) * s), col)
			draw_rect(Rect2(c + Vector2(-0.85, 0.05) * s, Vector2(1.7, 0.14) * s), dk)
		"tank":
			draw_rect(Rect2(c + Vector2(-0.38, -0.6) * s, Vector2(0.76, 1.5) * s), col)
			draw_circle(c + Vector2(0, -0.6) * s, 0.38 * s, col)
			draw_rect(Rect2(c + Vector2(-0.14, -1.05) * s, Vector2(0.28, 0.25) * s), lt)
			draw_rect(Rect2(c + Vector2(-0.38, 0.1) * s, Vector2(0.76, 0.14) * s), dk)
		"bullets":
			for k in 3:
				var bx := -0.55 + k * 0.55
				draw_rect(Rect2(c + Vector2(bx - 0.17, -0.2) * s, Vector2(0.34, 0.95) * s), col)
				_poly(c, s, [[bx - 0.17, -0.2], [bx + 0.17, -0.2], [bx, -0.75]], lt)
		"nodes":
			var pa := c + Vector2(0, -0.6) * s
			var pb := c + Vector2(-0.6, 0.5) * s
			var pc := c + Vector2(0.6, 0.5) * s
			draw_line(pa, pb, col, 0.14 * s)
			draw_line(pa, pc, col, 0.14 * s)
			for q in [pa, pb, pc]:
				draw_circle(q, 0.28 * s, col)
				draw_circle(q, 0.13 * s, lt)
		"chevrons":
			for k in 3:
				var oy := -0.55 + k * 0.45
				draw_polyline(PackedVector2Array([c + Vector2(-0.7, oy + 0.35) * s, c + Vector2(0, oy) * s, c + Vector2(0.7, oy + 0.35) * s]), col if k > 0 else lt, 0.2 * s)
		"cross":
			draw_rect(Rect2(c + Vector2(-0.25, -0.8) * s, Vector2(0.5, 1.6) * s), col)
			draw_rect(Rect2(c + Vector2(-0.8, -0.25) * s, Vector2(1.6, 0.5) * s), col)
		"crosshair":
			draw_arc(c, 0.62 * s, 0.0, TAU, 24, col, 0.14 * s)
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				draw_line(c + d * 0.35 * s, c + d * 0.95 * s, col, 0.14 * s)
			draw_circle(c, 0.12 * s, lt)
		"tag":
			_poly(c, s, [[-0.85, -0.45], [0.35, -0.45], [0.85, 0], [0.35, 0.45], [-0.85, 0.45]], col)
			draw_circle(c + Vector2(0.35, 0) * s, 0.13 * s, dk)
		"sword":
			draw_line(c + Vector2(-0.6, 0.6) * s, c + Vector2(0.75, -0.75) * s, lt, 0.22 * s)
			draw_line(c + Vector2(-0.65, 0.15) * s, c + Vector2(-0.15, 0.65) * s, col, 0.2 * s)
			draw_line(c + Vector2(-0.45, 0.45) * s, c + Vector2(-0.8, 0.8) * s, col, 0.2 * s)
		"grid":
			for q in [[-0.75, -0.75], [0.08, -0.75], [-0.75, 0.08], [0.08, 0.08]]:
				draw_rect(Rect2(c + Vector2(q[0], q[1]) * s, Vector2(0.67, 0.67) * s), col)
		"core":
			var hx: Array = []
			for k in 6:
				var a := PI / 6.0 + k * PI / 3.0
				hx.append([cos(a) * 0.9, sin(a) * 0.9])
			_poly(c, s, hx, dk.lerp(col, 0.5))
			draw_circle(c, 0.5 * s, col)
			draw_circle(c, 0.24 * s, lt)
		"scrap":
			var nt: Array = []
			for k in 6:
				var a2 := k * PI / 3.0
				nt.append([cos(a2) * 0.85, sin(a2) * 0.85])
			_poly(c, s, nt, col)
			draw_circle(c, 0.32 * s, Color("1a1d2b"))
		_:
			_poly(c, s, [[0, -0.8], [0.8, 0], [0, 0.8], [-0.8, 0]], col)


func _row_icon(id: String, r: Rect2) -> void:
	var tr := Rect2(r.position.x + 10, r.position.y + 10, r.size.y - 20, r.size.y - 20)
	var col := Color(1, 1, 1, 0.7)
	if id.begins_with("c_"):
		var cid := id.substr(2)
		for d in class_defs:
			if String(d["id"]) == cid:
				col = d["col"]
		_abox(tr, Color(0.06, 0.07, 0.12, 1.0))
		_aline(tr, Color(col.r, col.g, col.b, 0.8), 2.0)
		_spr(spr_gen.player(col, _cls_art(cid), 0, 0, {}), tr.get_center() + Vector2(0, 2), tr.size.y * 1.25)
		return
	var sd: Array = SYM.get(id, ["diamond", "c9d3f0"])
	col = Color(String(sd[1]))
	_abox(tr, Color(0.06, 0.07, 0.12, 1.0))
	_abox(tr, Color(col.r, col.g, col.b, 0.12))
	_aline(tr, Color(col.r, col.g, col.b, 0.8), 2.0)
	_sym(String(sd[0]), tr.get_center(), tr.size.y * 0.32, col)


func _row_box(r: Rect2, col: Color, a := 0.08) -> void:
	_abox(r, Color(0.015, 0.02, 0.045, 1.0))
	_abox(r, Color(col.r, col.g, col.b, a))
	_aline(r, col, 2.0)


func _lst_state() -> bool:
	return state == WORKSHOP or (state == SHOP and not mini_pick and mini_msg == "")


func _lst_area() -> Rect2:
	return Rect2(40, 244, 650, 864) if state == WORKSHOP else Rect2(40, 350, 650, 648)


func _lst_max() -> int:
	var n := WS_DEFS.size() if state == WORKSHOP else _shop_list().size()
	return maxi(0, n - (8 if state == WORKSHOP else 6))


func _lst_bar(top: float, rows: int, n: int, rh: float) -> void:
	if n <= rows:
		return
	var vh := rows * rh - 10.0
	var bh := vh * float(rows) / float(n)
	var by := top + (vh - bh) * float(lst_off) / float(n - rows)
	draw_rect(Rect2(684, top, 5, vh), Color(1, 1, 1, 0.08))
	draw_rect(Rect2(684, by, 5, bh), Color(1, 1, 1, 0.45))


func _draw_shop_list(_acc: Color) -> void:
	for ti in SHOP_TABS.size():
		var tr2 := _shop_tab_rect(ti)
		var tc2 := C_GOLD if ti == shop_tab else Color(1, 1, 1, 0.5)
		_abox(tr2, Color(0.015, 0.02, 0.045, 1.0))
		_abox(tr2, Color(tc2.r, tc2.g, tc2.b, 0.16 if ti == shop_tab else 0.06))
		_aline(tr2, tc2, 2.0)
		_ctext(String(SHOP_TABS[ti]), tr2.get_center(), 18, tc2)
	var slist := _shop_list()
	lst_off = clampi(lst_off, 0, maxi(0, slist.size() - 6))
	if slist.is_empty():
		_txt("Nothing here yet", Vector2(0, 560), T_HEAD, C_DIM)
	for i in 6:
		var idx := lst_off + i
		if idx >= slist.size():
			break
		var d2: Dictionary = shop_defs[int(slist[idx])]
		var rr2 := _shop_rect(i)
		var lv: int = up(String(d2["id"]))
		var costs: Array = d2["costs"]
		var maxed := lv >= costs.size()
		var can2 := (not maxed) and bank >= int(costs[lv])
		var col2 := C_GOOD if can2 else (C_GOLD if maxed else Color(1, 1, 1, 0.45))
		_row_box(rr2, col2)
		_row_icon(String(d2["id"]), rr2)
		var nm2 := _aname(String(d2["id"]), String(d2["name"]))
		if costs.size() > 1:
			nm2 += "  %d/%d" % [lv, costs.size()]
		_txt(nm2, Vector2(rr2.position.x + 100, rr2.position.y + 38), 26, Color.WHITE, 340.0, HORIZONTAL_ALIGNMENT_LEFT)
		_para_fit(_atext(String(d2["id"]), String(d2["desc"])), Vector2(rr2.position.x + 100, rr2.position.y + 64), T_SMALL, Color(1, 1, 1, 0.75), 350.0, 2)
		if maxed:
			_txt("OWNED" if costs.size() == 1 else "MAXED", Vector2(rr2.end.x - 170, rr2.position.y + 58), 24, col2, 156.0, HORIZONTAL_ALIGNMENT_RIGHT)
		else:
			_txt("%d" % int(costs[lv]), Vector2(rr2.end.x - 190, rr2.position.y + 58), 26, col2, 140.0, HORIZONTAL_ALIGNMENT_RIGHT)
			_sym("coin", Vector2(rr2.end.x - 30, rr2.position.y + 49), 13.0, C_GOLD)
	_lst_bar(350.0, 6, slist.size(), 108.0)


func _cur_line(y: float) -> void:
	var items := [["coin", "%d" % bank, C_GOLD], ["core", "%d" % cores, Color("ff4fd8")]]
	var x := 360.0 - items.size() * 90.0
	for it in items:
		_sym(String(it[0]), Vector2(x + 30, y - 8), 14.0, it[2])
		_txt(String(it[1]), Vector2(x + 52, y), T_BODY + 4, it[2], 120.0, HORIZONTAL_ALIGNMENT_LEFT)
		x += 180.0


const CT_SLOTS := 5


const CT_SWAP := 25


func _ct_rect(i: int) -> Rect2:
	return Rect2(40, 286 + i * 118, 640, 108)


func _ct_swap_rect(i: int) -> Rect2:
	var r := _ct_rect(i)
	return Rect2(r.end.x - 124, r.position.y + 54, 112, 44)


func _cur_badges() -> void:
	var items := [["coin", coins, C_GOLD], ["core", cores, Color("ff4fd8")], ["scrap", scrap, Color("c9a36b")]]
	var x := 24.0
	for it in items:
		var br := Rect2(x, 22, 136, 50)
		var bc: Color = it[2]
		_panel(br, bc, 0.1, false)
		_sym(String(it[0]), Vector2(br.position.x + 24, br.get_center().y), 13.0, bc)
		_txt("%d" % int(it[1]), Vector2(br.position.x + 44, br.get_center().y + 8), 22, bc, 86.0, HORIZONTAL_ALIGNMENT_LEFT)
		x += 144.0


const TRAILS := [
	{"id": "none", "name": "NO TRAIL", "cost": 0, "col": Color("8090a8")},
	{"id": "sparks", "name": "SPARKS", "cost": 2, "col": Color("ffd23f")},
	{"id": "frost", "name": "FROST", "cost": 2, "col": Color("9be7ff")},
	{"id": "ember", "name": "EMBER", "cost": 3, "col": Color("ff7a3c")},
	{"id": "pixel", "name": "PIXEL DUST", "cost": 3, "col": Color("7cff6b")},
	{"id": "void", "name": "VOID", "cost": 4, "col": Color("a35cff")},
]


const TR_LIFE := 0.7


var tr_own := {"none": true}


var tr_eq := "none"


var tr_pts: Array = []
var wt_last := Vector2(-99, -99)


var wd_open := false


var wd_prev := ""


var btn_wd := Rect2(540, 76, 160, 44)


var btn_wd_close := Rect2(260, 1060, 200, 56)


func _wd_row(i: int) -> Rect2:
	return Rect2(90, 460 + i * 96, 540, 86)


func _trail_tick(prc: Vector2, sz: float) -> void:
	if tr_eq == "none":
		return
	if vis_pos.distance_to(wt_last) > 0.2:
		wt_last = vis_pos
		tr_pts.append([vis_pos, t, randi() % 1000])
	while tr_pts.size() > 0 and (t - float(tr_pts[0][1]) > TR_LIFE or tr_pts.size() > 40):
		tr_pts.pop_front()
	var off := prc - _wp(vis_pos)
	for q in tr_pts:
		_trail_fx(tr_eq, _wp(q[0]) + off + Vector2(0, sz * 0.32), (t - float(q[1])) / TR_LIFE, int(q[2]), sz)


func _trail_fx(kind: String, p: Vector2, a: float, sd: int, sz: float) -> void:
	var k := clampf(1.0 - a, 0.0, 1.0)
	var r := sz * 0.08
	var j := Vector2(fmod(float(sd) * 0.37, 1.0) - 0.5, fmod(float(sd) * 0.61, 1.0) - 0.5) * sz * 0.3
	match kind:
		"sparks":
			var q := p + j * (0.5 + a)
			draw_line(q, q + Vector2(j.x, -absf(j.y) - sz * 0.05) * 0.4 * k, Color(1, 0.85, 0.3, k), 2.0)
			draw_circle(q, r * 0.6 * k + 0.5, Color(1, 1, 0.8, k))
		"frost":
			var q := p + j * 0.6
			var s := r * 1.3 * k + 0.5
			var an := t * 2.0 + float(sd)
			var pd := PackedVector2Array()
			for vi in 4:
				pd.append(q + Vector2(cos(an + vi * PI * 0.5), sin(an + vi * PI * 0.5)) * s * (1.0 if vi % 2 == 0 else 0.55))
			draw_colored_polygon(pd, Color(0.65, 0.9, 1.0, 0.85 * k))
		"ember":
			var q := p + Vector2(j.x * 0.6, -a * sz * 0.5)
			draw_circle(q, r * (1.0 - a * 0.5), Color(1.0, 0.55 - 0.3 * a, 0.15, 0.85 * k))
		"pixel":
			var q := p + j * 0.7
			var s := r * 1.4 * k + 1.0
			draw_rect(Rect2(q - Vector2(s, s) * 0.5, Vector2(s, s)), Color.from_hsv(fmod(float(sd) * 0.013 + t * 0.3, 1.0), 0.8, 1.0, k))
		"void":
			var q := p + j * 0.3
			draw_circle(q, r * (1.0 + a * 1.6), Color(0.55, 0.25, 1.0, 0.35 * k))
			draw_circle(q, r * 0.7 * (1.0 + a), Color(0.05, 0.0, 0.1, 0.8 * k))


func _wd_path(tt: float) -> Vector2:
	return Vector2(360 + cos(tt * 1.6) * 200.0, 360 + sin(tt * 3.2) * 40.0)


func _draw_wardrobe() -> void:
	draw_rect(Rect2(0, 0, 720, 1280), Color(0, 0, 0, 0.7))
	var pr := Rect2(60, 180, 600, 960)
	draw_rect(pr, Color(0.03, 0.04, 0.08, 1.0))
	_aline(pr, Color("a35cff"), 3.0)
	_ctext("WARDROBE  -  STEP TRAILS", Vector2(360, 220), 30, Color.WHITE)
	_cur_line(240.0)
	var box := Rect2(90, 280, 540, 160)
	draw_rect(box, Color(0.07, 0.08, 0.14, 1.0))
	var pk := wd_prev if wd_prev != "" else tr_eq
	if pk != "none":
		var n := int(t / 0.04)
		for i in 18:
			var ts := float(n - i) * 0.04
			_trail_fx(pk, _wd_path(ts) + Vector2(0, 22), (t - ts) / TR_LIFE, (n - i) * 97 % 1000, 70.0)
	var cd: Dictionary = class_defs[cls_page]
	_spr(spr_gen.player(cd["col"], _cls_art(String(cd["id"])), 0, 0, {}), _wd_path(t), 70.0)
	for i in TRAILS.size():
		var tr: Dictionary = TRAILS[i]
		var id := String(tr["id"])
		var rr := _wd_row(i)
		var col: Color = tr["col"]
		var sel := id == pk
		draw_rect(rr, Color(col.r, col.g, col.b, 0.22 if sel else 0.08))
		_aline(rr, col if sel else Color(1, 1, 1, 0.15), 2.0)
		draw_circle(rr.position + Vector2(44, 43), 18.0, col)
		_txt(String(tr["name"]), Vector2(rr.position.x + 80, rr.position.y + 54), 26, Color.WHITE, 300.0, HORIZONTAL_ALIGNMENT_LEFT)
		var st := ""
		var sc := C_DIM
		if id == tr_eq:
			st = "EQUIPPED"
			sc = C_GOLD
		elif tr_own.has(id):
			st = "TAP TO EQUIP" if sel else "OWNED"
		else:
			st = ("BUY  %d CORES" if sel else "%d CORES") % int(tr["cost"])
			sc = Color("ffc93c") if cores >= int(tr["cost"]) else Color(1, 0.4, 0.4)
		_txt(st, Vector2(rr.position.x + 300, rr.position.y + 54), 22, sc, 220.0, HORIZONTAL_ALIGNMENT_RIGHT)
	_button(btn_wd_close, "CLOSE", Color("a35cff"), 26)


func _wd_input(p: Vector2) -> void:
	if btn_wd_close.has_point(p):
		wd_open = false
		wd_prev = ""
		_sfx("ui")
		return
	for i in TRAILS.size():
		if not _wd_row(i).has_point(p):
			continue
		var tr: Dictionary = TRAILS[i]
		var id := String(tr["id"])
		if wd_prev != id and id != tr_eq:
			wd_prev = id
			_sfx("ui")
			return
		if tr_own.has(id):
			tr_eq = id
			tr_pts.clear()
			_sfx("ui")
		elif cores >= int(tr["cost"]):
			cores -= int(tr["cost"])
			tr_own[id] = true
			tr_eq = id
			tr_pts.clear()
			_sfx("big")
		else:
			_sfx("blocked")
			return
		_save_meta()
		return

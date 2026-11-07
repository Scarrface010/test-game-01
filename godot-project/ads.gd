extends Node
# Ads autoload (AdMob via Poing plugin). Active only in the Play build ("play" feature, Android, Gradle).
# Web and sideload APK: enabled=false, every call is a no-op. Real unit IDs. Register test phones in AdMob > Settings > Test devices.
const REWARDED_ID := "ca-app-pub-4166427319338832/7877767153"
const INTERSTITIAL_ID := "ca-app-pub-4166427319338832/9458442136"
const CFG := "user://ads.cfg"
const BOSS_DAILY_CAP := 3

var enabled := false
var _ready_ads := false
var _rewarded = null
var _interstitial = null
var _reward_cb: Callable
var _earned := false
var runs_done := 0
var boss_day := ""
var boss_count := 0
# Remove Ads (one-time in-app product). With it: no interstitials, rewarded offers are free (no video).
const NOADS_ID := "remove_ads"
var no_ads := false
var noads_price := ""
var billing = null
var buy_msg := ""

func _ready() -> void:
	enabled = OS.has_feature("android") and OS.has_feature("play")
	_load_cfg()
	if enabled:
		_consent.call_deferred()
		_billing_start.call_deferred()

# --- Billing (GodotGooglePlayBilling 3.x) ---
func _billing_start() -> void:
	if not ClassDB.class_exists("JNISingleton") or not Engine.has_singleton("GodotGooglePlayBilling"):
		return
	billing = load("res://addons/GodotGooglePlayBilling/BillingClient.gd").new()
	add_child(billing)
	billing.connected.connect(_on_bill_connected)
	billing.query_product_details_response.connect(_on_bill_details)
	billing.query_purchases_response.connect(_on_bill_purchases)
	billing.on_purchase_updated.connect(_on_bill_purchases)
	billing.start_connection()

func _on_bill_connected() -> void:
	billing.query_product_details(PackedStringArray([NOADS_ID]), 0)
	billing.query_purchases(0)

func _on_bill_details(r: Dictionary) -> void:
	for d in r.get("product_details", []):
		if String(d.get("product_id", "")) == NOADS_ID:
			var o = d.get("one_time_purchase_offer_details", {})
			if o is Dictionary:
				noads_price = String(o.get("formatted_price", ""))

func _on_bill_purchases(r: Dictionary) -> void:
	if int(r.get("response_code", -1)) != 0:
		if int(r.get("response_code", -1)) == 7:
			billing.query_purchases(0)
		return
	for p in r.get("purchases", []):
		if not (NOADS_ID in Array(p.get("product_ids", []))):
			continue
		if int(p.get("purchase_state", 0)) != 1:
			buy_msg = "Purchase pending"
			continue
		if not no_ads:
			no_ads = true
			buy_msg = "Ads removed. Thank you!"
			_save_cfg()
		if not bool(p.get("is_acknowledged", false)):
			billing.acknowledge_purchase(String(p.get("purchase_token", "")))

func billing_ready() -> bool:
	return billing != null and billing.is_ready()

func buy_remove_ads() -> void:
	if no_ads:
		return
	if not billing_ready():
		buy_msg = "Store not available right now"
		if billing != null:
			billing.start_connection()
		return
	billing.purchase(NOADS_ID)

func restore() -> void:
	if billing_ready():
		billing.query_purchases(0)

func tag() -> String:
	return "FREE" if no_ads else "AD"

func _load_cfg() -> void:
	var c := ConfigFile.new()
	if c.load(CFG) == OK:
		runs_done = int(c.get_value("ads", "runs", 0))
		boss_day = String(c.get_value("ads", "boss_day", ""))
		boss_count = int(c.get_value("ads", "boss_count", 0))
		no_ads = bool(c.get_value("ads", "no_ads", false))

func _save_cfg() -> void:
	var c := ConfigFile.new()
	c.set_value("ads", "no_ads", no_ads)
	c.set_value("ads", "runs", runs_done)
	c.set_value("ads", "boss_day", boss_day)
	c.set_value("ads", "boss_count", boss_count)
	c.save(CFG)

# --- UMP consent (EU/UK), then init ---
func _consent() -> void:
	UserMessagingPlatform.consent_information.update(ConsentRequestParameters.new(), _on_consent_info, func(_e): _init_ads())

func _on_consent_info() -> void:
	if UserMessagingPlatform.consent_information.get_is_consent_form_available():
		UserMessagingPlatform.load_consent_form(_on_form_loaded, func(_e): _init_ads())
	else:
		_init_ads()

func _on_form_loaded(form) -> void:
	if UserMessagingPlatform.consent_information.get_consent_status() == UserMessagingPlatform.consent_information.ConsentStatus.REQUIRED:
		form.show(func(_e): _init_ads())
	else:
		_init_ads()

func privacy_options_required() -> bool:
	return enabled and UserMessagingPlatform.consent_information.get_privacy_options_requirement_status() == ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED

func show_privacy_options() -> void:
	if enabled:
		UserMessagingPlatform.show_privacy_options_form(func(_e): pass)

func _init_ads() -> void:
	if _ready_ads or not UserMessagingPlatform.consent_information.get_can_request_ads():
		return
	_ready_ads = true
	var l := OnInitializationCompleteListener.new()
	l.on_initialization_complete = func(_s): _load_rewarded(); _load_interstitial()
	MobileAds.initialize(l)

# --- Rewarded ---
func _load_rewarded() -> void:
	var cb := RewardedAdLoadCallback.new()
	cb.on_ad_loaded = func(ad): _rewarded = ad
	cb.on_ad_failed_to_load = func(_e): get_tree().create_timer(30.0).timeout.connect(_load_rewarded)
	RewardedAdLoader.new().load(REWARDED_ID, AdRequest.new(), cb)

func rewarded_ready() -> bool:
	return enabled and (no_ads or _rewarded != null)

# cb(granted: bool) is called after the ad closes.
func show_rewarded(cb: Callable) -> bool:
	if not rewarded_ready():
		return false
	if no_ads:
		cb.call_deferred(true)
		return true
	var ad = _rewarded
	_rewarded = null
	_reward_cb = cb
	_earned = false
	var fs := FullScreenContentCallback.new()
	fs.on_ad_dismissed_full_screen_content = func(): _rewarded_done(ad)
	fs.on_ad_failed_to_show_full_screen_content = func(_e): _rewarded_done(ad)
	ad.full_screen_content_callback = fs
	var rl := OnUserEarnedRewardListener.new()
	rl.on_user_earned_reward = func(_item): _earned = true
	ad.show(rl)
	return true

func _rewarded_done(ad) -> void:
	ad.destroy()
	var cb := _reward_cb
	_reward_cb = Callable()
	_load_rewarded()
	if cb.is_valid():
		cb.call_deferred(_earned)

# Bonus boss core: max BOSS_DAILY_CAP per day.
func boss_bonus_available() -> bool:
	_roll_day()
	return rewarded_ready() and boss_count < BOSS_DAILY_CAP

func boss_bonus_used() -> void:
	_roll_day()
	boss_count += 1
	_save_cfg()

func _roll_day() -> void:
	var d := Time.get_date_string_from_system()
	if d != boss_day:
		boss_day = d
		boss_count = 0

# --- Interstitial: on return to Station Base, every 3rd run, never in runs 1-3 ---
func _load_interstitial() -> void:
	var cb := InterstitialAdLoadCallback.new()
	cb.on_ad_loaded = func(ad): _interstitial = ad
	cb.on_ad_failed_to_load = func(_e): get_tree().create_timer(60.0).timeout.connect(_load_interstitial)
	InterstitialAdLoader.new().load(INTERSTITIAL_ID, AdRequest.new(), cb)

func on_return_to_base() -> void:
	runs_done += 1
	_save_cfg()
	if not enabled or no_ads or _interstitial == null or runs_done <= 3 or runs_done % 3 != 0:
		return
	var ad = _interstitial
	_interstitial = null
	var fs := FullScreenContentCallback.new()
	fs.on_ad_dismissed_full_screen_content = func(): ad.destroy(); _load_interstitial()
	fs.on_ad_failed_to_show_full_screen_content = func(_e): ad.destroy(); _load_interstitial()
	ad.full_screen_content_callback = fs
	ad.show()

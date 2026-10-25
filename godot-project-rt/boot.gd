extends Node
# Boot autoload (Android self-update). Loads a previously downloaded update pack before the game scene loads,
# then checks for a newer pack. Packs are only accepted if their RSA-SHA256 signature matches PUBLIC_KEY.
const BASE_URL := "https://scarrface010.github.io/test-game-01/rt/"
const BASE_VERSION := 1
const PACK := "user://update.pck"
const VER_FILE := "user://update_ver.txt"
const PUBLIC_KEY := """-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAkHpYCWXHqZHM8m1QenuJ
d1mS+aWLSbYYy85ZlBezOsrsq2MwD8qHgX7/2JxXwqNutDMS9NRtOUe9G8b3xyij
WSSIwoaHdKfbzHqML3Ry0KILxS/++s4Sc0guaL1Ra5RrLd0m/3xOceows0NEp5pf
ofC9yovEF2JW+59Y9vJ2VXVSY1HsX2dzFoA0Pn/dhPmFKgUaVK2JAPM9lUxKRFE0
RLoEwGhUjjYC7BpUJpL7b3DRdlCHs/8n4CnG8xpEjMHtLvD7WTlhciU5W3s6vzFJ
TNHj9ucxUjXGFV6tZ6tl8E8doR5DLL61BscvKSpA3q4rm8GN5Os0It9TNgYZr639
bwIDAQAB
-----END PUBLIC KEY-----"""

var status := "idle"

func _ready() -> void:
	var android := OS.has_feature("android")
	if android and FileAccess.file_exists(PACK) and _stored_ver() > BASE_VERSION:
		if ProjectSettings.load_resource_pack(PACK, true):
			status = "loaded v%d" % _stored_ver()
		else:
			status = "load failed"
			DirAccess.remove_absolute(PACK)
	if android:
		_check.call_deferred()

func _stored_ver() -> int:
	if not FileAccess.file_exists(VER_FILE):
		return 0
	return int(FileAccess.get_file_as_string(VER_FILE).strip_edges())

func _signature_ok(path: String, sig_b64: String) -> bool:
	var key := CryptoKey.new()
	if key.load_from_string(PUBLIC_KEY, true) != OK:
		return false
	var sig := Marshalls.base64_to_raw(sig_b64)
	var hash := FileAccess.get_sha256(path).hex_decode()
	if sig.is_empty() or hash.size() != 32:
		return false
	return Crypto.new().verify(HashingContext.HASH_SHA256, hash, sig, key)

func _check() -> void:
	var r := HTTPRequest.new()
	r.timeout = 15
	add_child(r)
	r.request(BASE_URL + "version.json?t=" + str(Time.get_unix_time_from_system()))
	var res = await r.request_completed
	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
		status = "check fail r%d h%d" % [res[0], res[1]]
		return
	var j = JSON.parse_string(res[3].get_string_from_utf8())
	if typeof(j) != TYPE_DICTIONARY:
		return
	var v := int(j.get("version", 0))
	if v <= maxi(_stored_ver(), BASE_VERSION):
		status += " up-to-date"
		return
	var d := HTTPRequest.new()
	d.timeout = 120
	d.download_file = "user://update.tmp"
	add_child(d)
	d.request(BASE_URL + "android.pck?v=" + str(v))
	var dr = await d.request_completed
	if dr[0] != HTTPRequest.RESULT_SUCCESS or dr[1] != 200 \
			or not _signature_ok("user://update.tmp", str(j.get("sig", ""))):
		status = "dl/sig fail r%d h%d" % [dr[0], dr[1]]
		DirAccess.remove_absolute("user://update.tmp")
		return
	DirAccess.rename_absolute("user://update.tmp", PACK)
	var f := FileAccess.open(VER_FILE, FileAccess.WRITE)
	f.store_string(str(v))
	f.close()
	status += " | got v%d, restart" % v

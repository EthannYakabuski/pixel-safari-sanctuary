extends Node
## Android-only native integrations. Web and editor never simulate ad entitlement.

signal availability_changed
signal service_notice(message: String)

var settings: Dictionary = {}
var _native_ads := false
var _ads_ready := false
var _pgs_ready := false
var _signed_in := false
var _menu_visible := true
var _round_count := 0
var _banner: AdView
var _interstitial: InterstitialAd
var _rewarded: RewardedAd
var _reward_callback := Callable()
var _reward_granted := false
var _reward_showing := false
var _reward_context := ""
var _interstitial_showing := false
var _sign_in_client: PlayGamesSignInClient
var _achievements_client: PlayGamesAchievementsClient
var _leaderboards_client: PlayGamesLeaderboardsClient
var _pending_unlocks: Dictionary = {}
var _pending_scores: Dictionary = {}
var _notice := "Offline progress is available."

const PENDING_PATH := "user://platform_pending_v1.json"

func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://platform/config.json"))
	if parsed is Dictionary:
		settings = parsed
	_load_pending()
	if OS.get_name() != "Android":
		_notice = "Local play: Android ads and Play Games are unavailable on this platform."
		return
	_start_play_games()
	_native_ads = Engine.has_singleton("PoingGodotAdMob")
	if not _native_ads:
		_notice = "Native AdMob is unavailable; the game remains fully playable."
		return
	_refresh_consent()

func status() -> String:
	return _notice

func _set_notice(message: String) -> void:
	_notice = message
	service_notice.emit(message)
	availability_changed.emit()

func _refresh_consent() -> void:
	if not Engine.has_singleton("PoingGodotAdMobUserMessagingPlatform"):
		_set_notice("Consent service unavailable; ad requests are paused.")
		return
	var parameters := ConsentRequestParameters.new()
	parameters.tag_for_under_age_of_consent = bool(settings.get("admob", {}).get("tag_for_under_age_of_consent", false))
	UserMessagingPlatform.consent_information.update(parameters, _consent_updated, _consent_update_failed)

func _consent_updated() -> void:
	var information := UserMessagingPlatform.consent_information
	if information.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED and information.get_is_consent_form_available():
		UserMessagingPlatform.load_consent_form(_consent_form_loaded, _consent_update_failed)
	else:
		_finish_consent()

func _consent_form_loaded(form: ConsentForm) -> void:
	UserMessagingPlatform.active_consent_form = form
	form.show(func(_error: FormError) -> void: _finish_consent())

func _consent_update_failed(error: FormError) -> void:
	_set_notice("Consent update unavailable: " + error.message)
	_finish_consent()

func _finish_consent() -> void:
	var consent_status := UserMessagingPlatform.consent_information.get_consent_status()
	if consent_status not in [ConsentInformation.ConsentStatus.OBTAINED, ConsentInformation.ConsentStatus.NOT_REQUIRED]:
		_set_notice("Ads are paused until consent information is available. Local play is unaffected.")
		return
	if _ads_ready:
		return
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = _on_ads_initialized
	MobileAds.initialize(listener)

func privacy_options() -> void:
	if OS.get_name() == "Android" and Engine.has_singleton("PoingGodotAdMobUserMessagingPlatform"):
		UserMessagingPlatform.show_privacy_options_form(func(_error: FormError) -> void: _refresh_consent())
	else:
		_set_notice("Privacy options for advertising are available in the Android app.")

func _on_ads_initialized(_initialization: InitializationStatus) -> void:
	_ads_ready = true
	_load_banner()
	_load_interstitial()
	_load_rewarded()
	_set_notice("Android test ads are enabled." if bool(settings.get("admob", {}).get("test_mode", true)) else "Android ad services are ready.")

func _ad_id(kind: String) -> String:
	return str(settings.get("admob", {}).get(kind + "_unit_id", ""))

func set_menu_visible(visible: bool) -> void:
	_menu_visible = visible
	if is_instance_valid(_banner):
		if visible:
			_banner.show()
		else:
			_banner.hide()

func _load_banner() -> void:
	if not _ads_ready or _ad_id("banner").is_empty():
		return
	_banner = AdView.new(_ad_id("banner"), AdSize.BANNER, AdPosition.BOTTOM)
	var listener := AdListener.new()
	listener.on_ad_loaded = func() -> void: set_menu_visible(_menu_visible)
	listener.on_ad_failed_to_load = func(error: LoadAdError) -> void: _set_notice("Banner unavailable: " + error.message)
	_banner.ad_listener = listener
	_banner.load_ad(AdRequest.new())
	if not _menu_visible:
		_banner.hide()

func _load_interstitial() -> void:
	if not _ads_ready or _ad_id("interstitial").is_empty():
		return
	var callback := InterstitialAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: InterstitialAd) -> void:
		_interstitial = ad
		var content := FullScreenContentCallback.new()
		content.on_ad_dismissed_full_screen_content = _interstitial_closed
		content.on_ad_failed_to_show_full_screen_content = func(_error: AdError) -> void: _interstitial_closed()
		ad.full_screen_content_callback = content
	callback.on_ad_failed_to_load = func(error: LoadAdError) -> void: _set_notice("Interstitial unavailable: " + error.message)
	InterstitialAdLoader.new().load(_ad_id("interstitial"), AdRequest.new(), callback)

func round_finished() -> void:
	_round_count += 1
	if _round_count % 2 != 0 or _interstitial_showing or _reward_showing:
		return
	if is_instance_valid(_interstitial):
		_interstitial_showing = true
		_interstitial.show()
	elif _ads_ready:
		_load_interstitial()

func _interstitial_closed() -> void:
	_interstitial_showing = false
	if is_instance_valid(_interstitial):
		_interstitial.destroy()
	_interstitial = null
	_load_interstitial()

func _load_rewarded() -> void:
	if not _ads_ready or _ad_id("rewarded").is_empty():
		return
	var callback := RewardedAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: RewardedAd) -> void:
		_rewarded = ad
		var content := FullScreenContentCallback.new()
		content.on_ad_dismissed_full_screen_content = _rewarded_closed
		content.on_ad_failed_to_show_full_screen_content = func(_error: AdError) -> void: _rewarded_closed()
		ad.full_screen_content_callback = content
		availability_changed.emit()
	callback.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		_set_notice("Rewarded ad unavailable: " + error.message)
		availability_changed.emit()
	RewardedAdLoader.new().load(_ad_id("rewarded"), AdRequest.new(), callback)

func can_reward() -> bool:
	return _native_ads and _ads_ready and is_instance_valid(_rewarded) and not _reward_showing and not _interstitial_showing

func reward_requested(context: String, callback: Callable) -> void:
	if not can_reward():
		if callback.is_valid():
			callback.call_deferred(false)
		_set_notice("No rewarded ad is available. You can keep playing normally.")
		return
	_reward_context = context
	_reward_callback = callback
	_reward_granted = false
	_reward_showing = true
	var listener := OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = _earned_reward
	_rewarded.show(listener)
	availability_changed.emit()

func _earned_reward(_item: RewardedItem) -> void:
	if _reward_granted or not _reward_callback.is_valid():
		return
	_reward_granted = true
	var callback := _reward_callback
	_reward_callback = Callable()
	callback.call(true)
	_set_notice("Reward earned: " + _reward_context)

func _rewarded_closed() -> void:
	_reward_showing = false
	if _reward_callback.is_valid():
		var callback := _reward_callback
		_reward_callback = Callable()
		callback.call(false)
	if is_instance_valid(_rewarded):
		_rewarded.destroy()
	_rewarded = null
	_reward_context = ""
	_load_rewarded()
	availability_changed.emit()

func _start_play_games() -> void:
	var pgs: Dictionary = settings.get("play_games", {})
	if not bool(pgs.get("enabled", false)) or str(pgs.get("game_id", "")).is_empty():
		_set_notice("Play Games configuration is pending; achievements and scores are saved locally.")
		return
	var plugin := get_node_or_null("/root/GodotPlayGameServices")
	if plugin == null or not Engine.has_singleton("GodotPlayGameServices"):
		return
	if plugin.initialize() != 0:
		return
	_sign_in_client = PlayGamesSignInClient.new()
	_achievements_client = PlayGamesAchievementsClient.new()
	_leaderboards_client = PlayGamesLeaderboardsClient.new()
	add_child(_sign_in_client)
	add_child(_achievements_client)
	add_child(_leaderboards_client)
	_pgs_ready = true
	_sign_in_client.user_authenticated.connect(_authentication_changed)
	_sign_in_client.is_authenticated()

func sign_in() -> void:
	if _pgs_ready:
		_sign_in_client.sign_in()
	else:
		_set_notice("Play Games requires your app ID, credentials and tester configuration. Local progress is saved.")

func _authentication_changed(authenticated: bool) -> void:
	_signed_in = authenticated
	if authenticated:
		_flush_pending()
		_set_notice("Signed in to Google Play Games.")
	else:
		_set_notice("Play Games sign-in was unavailable or cancelled; local progress is safe.")

func unlock(key: String) -> void:
	_pending_unlocks[key] = true
	_save_pending()
	_flush_pending()

func submit(key: String, value: int) -> void:
	_pending_scores[key] = maxi(value, int(_pending_scores.get(key, value)))
	_save_pending()
	_flush_pending()

func _flush_pending() -> void:
	if not _pgs_ready or not _signed_in:
		return
	var pgs: Dictionary = settings.get("play_games", {})
	var achievements: Dictionary = pgs.get("achievements", {})
	var leaderboards: Dictionary = pgs.get("leaderboards", {})
	for key in _pending_unlocks:
		var remote_id := str(achievements.get(key, ""))
		if not remote_id.is_empty():
			_achievements_client.unlock_achievement(remote_id)
	for key in _pending_scores:
		var remote_id := str(leaderboards.get(key, ""))
		if not remote_id.is_empty():
			_leaderboards_client.submit_score(remote_id, int(_pending_scores[key]))
	# Retain best scores and unlocks locally; resubmission is idempotent and survives failed uploads.

func open_achievements() -> void:
	if _pgs_ready and _signed_in:
		_achievements_client.show_achievements()
	else:
		_set_notice("Local achievements remain available; online achievements need Play Games sign-in.")

func open_leaderboards(key: String = "") -> void:
	if not _pgs_ready or not _signed_in:
		_set_notice("Local records remain available; online leaderboards need Play Games sign-in.")
		return
	var remote_id := str(settings.get("play_games", {}).get("leaderboards", {}).get(key, ""))
	if remote_id.is_empty():
		_leaderboards_client.show_all_leaderboards()
	else:
		_leaderboards_client.show_leaderboard(remote_id)

func _load_pending() -> void:
	if not FileAccess.file_exists(PENDING_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PENDING_PATH))
	if parsed is Dictionary:
		_pending_unlocks = parsed.get("unlocks", {})
		_pending_scores = parsed.get("scores", {})

func _save_pending() -> void:
	var file := FileAccess.open(PENDING_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"unlocks": _pending_unlocks, "scores": _pending_scores}))

func _exit_tree() -> void:
	if is_instance_valid(_banner):
		_banner.destroy()
	if is_instance_valid(_interstitial):
		_interstitial.destroy()
	if is_instance_valid(_rewarded):
		_rewarded.destroy()

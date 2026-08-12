extends Node

const CatalogScript := preload("res://scripts/catalog.gd")
const SAVE_VERSION := 1
const SAVE_PATH := "user://pocket_paludarium_v1.json"
const MAX_OFFLINE_SECONDS := 8.0 * 60.0 * 60.0
const FULLNESS_DECAY_PER_HOUR := 8.0
const HAPPINESS_DECAY_PER_HOUR := 4.0
const WATER_DECAY_PER_HOUR := 6.0
const MIN_PLACEMENT_DISTANCE := 0.11

signal state_changed
signal saved

var catalog = CatalogScript.new()
var fullness: float = 78.0
var happiness: float = 76.0
var water_quality: float = 84.0
var pearls: int = 42
var inventory: Dictionary = {"berry_bites": 3, "water_fern": 1, "moon_stone": 1}
var equipment: Dictionary = {}
var placements: Array[Dictionary] = []
var settings: Dictionary = {"sound": true, "reduced_motion": false, "large_targets": false}
var tutorial_complete := false
var last_utc: int = 0
var welcome_summary := ""
var _next_instance := 1
var claimed_rounds: Dictionary = {}

func _ready() -> void:
	load_game()

func defaults() -> void:
	fullness = 78.0; happiness = 76.0; water_quality = 84.0; pearls = 42
	inventory = {"berry_bites": 3, "water_fern": 1, "moon_stone": 1}
	equipment = {}; placements = []; settings = {"sound": true, "reduced_motion": false, "large_targets": false}
	tutorial_complete = false; last_utc = Time.get_unix_time_from_system(); welcome_summary = ""; _next_instance = 1; claimed_rounds = {}

func clamp_needs() -> void:
	fullness = clampf(fullness, 0.0, 100.0)
	happiness = clampf(happiness, 0.0, 100.0)
	water_quality = clampf(water_quality, 0.0, 100.0)

func recompute_equipment() -> void:
	equipment = {}
	for placed in placements:
		var item = catalog.get_item(str(placed.get("item_id", "")))
		if item != null and (item.kind == "equipment" or item.kind == "cosmetic"):
			equipment[item.id] = true

func filter_multiplier() -> float:
	return 0.45 if equipment.has("gentle_filter") else 1.0

func has_bubbler() -> bool:
	return equipment.has("pearl_bubbler")

func bubbler_happiness_per_hour() -> float:
	var item = catalog.get_item("pearl_bubbler")
	return float(item.power) if item != null and has_bubbler() else 0.0

func apply_elapsed(seconds: float) -> Dictionary:
	var capped := minf(maxf(seconds, 0.0), MAX_OFFLINE_SECONDS)
	var hours := capped / 3600.0
	var old := {"fullness": fullness, "happiness": happiness, "water": water_quality}
	fullness -= FULLNESS_DECAY_PER_HOUR * hours
	happiness -= HAPPINESS_DECAY_PER_HOUR * hours
	water_quality -= WATER_DECAY_PER_HOUR * filter_multiplier() * hours
	happiness += bubbler_happiness_per_hour() * hours
	clamp_needs()
	return {"seconds": capped, "fullness": old.fullness - fullness, "happiness": old.happiness - happiness, "water": old.water - water_quality}

func resume_from_timestamp(now_utc: int = Time.get_unix_time_from_system(), persist: bool = true) -> Dictionary:
	var report := apply_elapsed(float(maxi(0, now_utc - last_utc)))
	last_utc = now_utc
	if report.seconds > 60.0:
		welcome_summary = "While you were away: -%d full, -%d water." % [roundi(report.fullness), roundi(report.water)]
	if persist: save_game()
	state_changed.emit()
	return report

func tick(seconds: float) -> void:
	apply_elapsed(seconds)
	state_changed.emit()

func feed(item_id: String) -> bool:
	var item = catalog.get_item(item_id)
	if item == null or item.kind != "food" or int(inventory.get(item_id, 0)) < 1: return false
	inventory[item_id] = int(inventory[item_id]) - 1
	fullness += item.power; happiness += 3.0; clamp_needs(); save_game(); state_changed.emit(); return true

func clean() -> void:
	water_quality += 28.0; happiness += 3.0; clamp_needs(); save_game(); state_changed.emit()

func pet() -> void:
	happiness += 9.0; clamp_needs(); save_game(); state_changed.emit()

func buy(item_id: String) -> bool:
	var item = catalog.get_item(item_id)
	if item == null or pearls < item.price: return false
	pearls -= item.price; inventory[item_id] = int(inventory.get(item_id, 0)) + 1; save_game(); state_changed.emit(); return true

func place(item_id: String, position_normalized: Vector2, flip: bool = false) -> Dictionary:
	var item = catalog.get_item(item_id)
	if item == null or item.kind == "food" or int(inventory.get(item_id, 0)) < 1: return {}
	var normalized := Vector2(clampf(position_normalized.x, 0.06, 0.94), clampf(position_normalized.y, 0.14, 0.86))
	for existing in placements:
		var existing_position := Vector2(float(existing.get("x", 0.0)), float(existing.get("y", 0.0)))
		if existing_position.distance_to(normalized) < MIN_PLACEMENT_DISTANCE: return {}
	var p := {"instance_id": _next_instance, "item_id": item_id, "x": normalized.x, "y": normalized.y, "layer": item.layer, "flip": flip}
	_next_instance += 1; placements.append(p); inventory[item_id] = int(inventory[item_id]) - 1
	recompute_equipment(); save_game(); state_changed.emit(); return p

func return_placement(instance_id: int) -> bool:
	for i in placements.size():
		if int(placements[i].get("instance_id", -1)) == instance_id:
			var item_id: String = str(placements[i].get("item_id", ""))
			inventory[item_id] = int(inventory.get(item_id, 0)) + 1
			placements.remove_at(i); recompute_equipment(); save_game(); state_changed.emit(); return true
	return false

func add_pearls(amount: int) -> void:
	pearls = maxi(0, pearls + amount); save_game(); state_changed.emit()

func reward_for(score: int, mode: String) -> Dictionary:
	var thresholds := [12, 25] if mode == "bubble" else [8, 18]
	var tier := "Sprout"; var reward := 4
	if score >= thresholds[1]: tier = "Pearl"; reward = 16
	elif score >= thresholds[0]: tier = "Ripple"; reward = 9
	return {"tier": tier, "pearls": reward, "mode": mode}

func award_minigame_round(round_id: String, score: int, mode: String) -> Dictionary:
	if claimed_rounds.has(round_id): return {"awarded": false, "reward": claimed_rounds[round_id]}
	var reward := reward_for(score, mode)
	claimed_rounds[round_id] = reward; pearls += int(reward.pearls); save_game(); state_changed.emit()
	return {"awarded": true, "reward": reward}

func _data() -> Dictionary:
	return {"version": SAVE_VERSION, "fullness": fullness, "happiness": happiness, "water_quality": water_quality, "pearls": pearls, "inventory": inventory, "equipment": equipment, "placements": placements, "settings": settings, "tutorial_complete": tutorial_complete, "last_utc": last_utc, "next_instance": _next_instance, "claimed_rounds": claimed_rounds}

func save_game() -> void:
	last_utc = Time.get_unix_time_from_system()
	var temp_path := SAVE_PATH + ".tmp"
	var backup_path := SAVE_PATH + ".bak"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify(_data())); file.close()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(backup_path)
		if DirAccess.rename_absolute(SAVE_PATH, backup_path) != OK: return
	if DirAccess.rename_absolute(temp_path, SAVE_PATH) != OK:
		if FileAccess.file_exists(backup_path): DirAccess.rename_absolute(backup_path, SAVE_PATH)
		return
	saved.emit()

func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK: return {}
	var parsed = json.data
	if not (parsed is Dictionary) or int(parsed.get("version", -1)) != SAVE_VERSION: return {}
	return parsed

func _load_data(parsed: Dictionary) -> void:
	fullness = float(parsed.get("fullness", fullness)); happiness = float(parsed.get("happiness", happiness)); water_quality = float(parsed.get("water_quality", water_quality)); pearls = int(parsed.get("pearls", pearls))
	inventory = parsed.get("inventory", inventory) as Dictionary; settings = parsed.get("settings", settings) as Dictionary
	placements = []
	var raw_placements = parsed.get("placements", [])
	if raw_placements is Array:
		for entry in raw_placements:
			if entry is Dictionary: placements.append(entry)
	tutorial_complete = bool(parsed.get("tutorial_complete", false)); _next_instance = int(parsed.get("next_instance", 1)); claimed_rounds = parsed.get("claimed_rounds", {}) as Dictionary
	last_utc = int(parsed.get("last_utc", Time.get_unix_time_from_system())); recompute_equipment(); clamp_needs()

func load_game() -> void:
	defaults()
	var parsed := _read_save(SAVE_PATH)
	if parsed.is_empty(): parsed = _read_save(SAVE_PATH + ".bak")
	if parsed.is_empty(): return
	_load_data(parsed)
	resume_from_timestamp(Time.get_unix_time_from_system(), false)
	save_game()

func notify_app_paused() -> void:
	save_game()

func notify_app_resumed() -> void:
	resume_from_timestamp()

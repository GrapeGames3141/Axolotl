extends SceneTree

var failures := 0

func expect(condition: bool, note: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + note)

func clear_saves(game) -> void:
	DirAccess.remove_absolute(str(game.SAVE_PATH))
	DirAccess.remove_absolute(str(game.SAVE_PATH) + ".tmp")
	DirAccess.remove_absolute(str(game.SAVE_PATH) + ".bak")
	DirAccess.remove_absolute(str(game.V1_PATH))

func _init() -> void:
	var game = load("res://scripts/game_state.gd").new()
	clear_saves(game)
	game.defaults()
	game.fullness = -5; game.happiness = 120; game.water_quality = 101; game.clamp_needs()
	expect(game.fullness == 0 and game.happiness == 100 and game.water_quality == 100, "need clamping")

	game.defaults(); var cap_report = game.apply_elapsed(999999.0)
	expect(cap_report.seconds == game.MAX_OFFLINE_SECONDS, "offline cap")
	expect(game.fullness >= 0 and game.happiness >= 0 and game.water_quality >= 0, "eight-hour cap stays recoverable")

	game.defaults(); var no_filter = game.apply_elapsed(3600.0).water
	game.defaults(); game.equipment["gentle_filter"] = true; var with_filter = game.apply_elapsed(3600.0).water
	expect(with_filter < no_filter, "filter reduces water decay")

	game.defaults(); game.happiness = 100; game.equipment["pearl_bubbler"] = true; var bubbler_report = game.apply_elapsed(3600.0)
	expect(is_equal_approx(game.happiness, 97.5) and is_equal_approx(bubbler_report.happiness, 2.5), "bubbler is a gentle +1.5 happiness per hour modifier")

	game.defaults(); game.pearls = 0; expect(not game.buy("cloud_hide"), "affordability")
	game.pearls = 42; var pearls_before = game.pearls; expect(game.buy("berry_bites"), "buy inventory"); expect(game.pearls < pearls_before, "purchase spends pearls")

	game.defaults(); game.inventory["moon_stone"] = 2
	var placed = game.place("moon_stone", Vector2(2.0, -1.0))
	expect(not placed.is_empty() and float(placed.x) <= 0.94 and float(placed.y) >= 0.14, "bounded normalized placement")
	expect(game.place("moon_stone", Vector2(0.94, 0.14)).is_empty(), "overlapping placement rejected")
	expect(game.return_placement(int(placed.instance_id)), "placement return round trip")

	game.defaults(); game.inventory["pearl_bubbler"] = 2
	var bubbler_one = game.place("pearl_bubbler", Vector2(0.20, 0.25))
	var bubbler_two = game.place("pearl_bubbler", Vector2(0.55, 0.25))
	expect(not bubbler_one.is_empty() and not bubbler_two.is_empty() and game.has_bubbler(), "duplicate equipment placement")
	game.return_placement(int(bubbler_one.instance_id))
	expect(game.has_bubbler(), "removing one duplicate equipment keeps remaining modifier")

	game.defaults(); game.last_utc = 1000; game.happiness = 100; game.equipment["pearl_bubbler"] = true
	var resume_report = game.resume_from_timestamp(4600, false); var resumed_happiness = game.happiness
	game.resume_from_timestamp(4600, false)
	expect(resume_report.seconds == 3600.0 and is_equal_approx(resumed_happiness, 97.5) and is_equal_approx(game.happiness, resumed_happiness), "resume applies elapsed decay exactly once")
	game.defaults(); game.last_utc = 1000; var capped_resume = game.resume_from_timestamp(1000 + 999999, false)
	expect(capped_resume.seconds == game.MAX_OFFLINE_SECONDS, "resume uses eight-hour cap")

	game.defaults(); var reward_start = game.pearls; var first_award = game.award_minigame_round("round_once", 30, "bubble"); var second_award = game.award_minigame_round("round_once", 30, "bubble")
	expect(first_award.awarded and not second_award.awarded and game.pearls == reward_start + 16, "minigame reward granted once")
	expect(game.reward_for(0, "bubble").tier == "Sprout" and game.reward_for(30, "bubble").pearls == 16, "deterministic reward tiers")

	game.defaults(); expect(game.validate_pet_name("  Luna!@#  ") == "Luna", "name sanitization")
	expect(game.validate_pet_name(" ") == "Pip" and game.validate_pet_name("abcdefghijklmnopq") == "abcdefghijklmnop", "name fallback and max length")
	game.defaults(); game.award_bond(40, false, "2026-08-14"); expect(game.award_bond(4, false, "2026-08-14") == 0 and game.bond_points == 40, "daily bond cap")
	expect(game.award_bond(8, true, "2026-08-14") == 8 and game.bond_points == 48, "wish bond bypasses cap")
	expect(game.award_bond(4, false, "2026-08-15") == 4 and game.bond_daily_earned == 4, "bond date reset and permanence")
	game.bond_points = 300; expect(game.bond_title() == "Kindred" and game.bond_unlocked("Cherished"), "bond thresholds")
	game.defaults(); game.ensure_daily_wishes("2026-08-14"); var wish_ids: Dictionary = {}
	for wish in game.wishes: wish_ids[str(wish.id)] = true
	expect(game.wishes.size() == 3 and wish_ids.size() == 3 and game.available_wish_actions().has("pet") and game.available_wish_actions().has("bubble"), "unique feasible daily wishes")
	var test_wishes: Array[Dictionary] = []; test_wishes.append({"id":"pet", "title":"Pet", "claimed":false}); test_wishes.append({"id":"clean", "title":"Clean", "claimed":false}); test_wishes.append({"id":"bubble", "title":"Bubble", "claimed":false}); game.wishes = test_wishes; game.wishes_date = game.local_date(); var wish_pearls: int = game.pearls
	expect(game.record_action("pet") and not game.record_action("pet") and game.pearls == wish_pearls + 6, "one wish reward per matching action")
	var behavior = load("res://scripts/pet_behavior.gd").new()
	expect(not behavior.trigger_feed(29) and behavior.pose == "swim", "eating stays locked below Curious")
	expect(behavior.trigger_feed(30) and behavior.update(0.1, 30, [], false) == "eat", "Curious unlocks manual eating")
	behavior.update(2.3, 30, [], false); expect(behavior.update(0.1, 30, [], false) == "swim", "eating duration expires to swim")
	var plants = [{"item_id":"water_fern", "x":0.75, "y":0.44}]
	expect(behavior.update(0.1, 30, plants, false) == "curious" and behavior.travel_progress > 0.0 and behavior.travel_progress < 1.0 and behavior.target_position.x > 0.5, "normal curiosity visit travels toward placed plant")
	behavior.update(behavior.VISIT_SECONDS + 0.1, 30, plants, false); expect(behavior.pose == "swim" and behavior.visit_cooldown > 0.0, "ambient visit expires into cooldown")
	expect(behavior.update(1.0, 30, plants, false) == "swim", "ambient cooldown prevents permanent curiosity")
	var reduced_behavior = load("res://scripts/pet_behavior.gd").new(); reduced_behavior.update(0.1, 30, plants, true)
	expect(reduced_behavior.pose == "curious" and is_equal_approx(reduced_behavior.travel_progress, 1.0) and reduced_behavior.current_position == reduced_behavior.target_position, "reduced motion snaps target without travel")
	var hides = [{"item_id":"cozy_log", "x":0.32, "y":0.45}]; var hide_behavior = load("res://scripts/pet_behavior.gd").new()
	expect(hide_behavior.update(0.1, 90, hides + plants, false) == "peek" and hide_behavior.target_kind == "hide", "trusting hide visit prioritizes its decor")
	hide_behavior.idle_seconds = 75.0; expect(hide_behavior.update(0.1, 180, hides, true) == "sleep" and hide_behavior.visit_remaining == 0.0, "Cherished sleep overrides ambient visit")
	hide_behavior.on_care_action("minigame"); expect(hide_behavior.pose == "swim" and hide_behavior.idle_seconds == 0.0 and hide_behavior.visit_remaining == 0.0, "any care action wakes/interupts pet state")

	clear_saves(game); var legacy := FileAccess.open(str(game.V1_PATH), FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"version":1, "pearls":77, "inventory":{"berry_bites":2}, "placements":[], "settings":{"sound":true,"reduced_motion":false,"large_targets":false}, "claimed_rounds":{"old": {"tier":"Pearl","pearls":16}}, "last_utc":Time.get_unix_time_from_system()})); legacy.close()
	game.defaults(); game.load_game(); expect(game.pearls == 77 and game.naming_prompt_state == "pending" and FileAccess.file_exists(game.V1_PATH) and FileAccess.file_exists(game.SAVE_PATH), "v1 migration preserves rollback and fields")

	clear_saves(game); game.defaults(); game.pearls = 50; game.save_game(); game.pearls = 60; game.save_game()
	var bad_file := FileAccess.open(str(game.SAVE_PATH), FileAccess.WRITE); bad_file.store_string("not json"); bad_file.close()
	game.defaults(); game.load_game(); expect(game.pearls == 50, "backup save recovery")
	clear_saves(game); var malformed := FileAccess.open(str(game.SAVE_PATH), FileAccess.WRITE); malformed.store_string("not json"); malformed.close()
	game.defaults(); game.load_game(); expect(game.pearls == 42, "malformed save recovery")
	clear_saves(game)
	print("Pocket Paludarium tests: %d failures" % failures)
	game.free()
	quit(0 if failures == 0 else 1)

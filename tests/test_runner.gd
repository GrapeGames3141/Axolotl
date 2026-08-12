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

	clear_saves(game); game.defaults(); game.pearls = 50; game.save_game(); game.pearls = 60; game.save_game()
	var bad_file := FileAccess.open(str(game.SAVE_PATH), FileAccess.WRITE); bad_file.store_string("not json"); bad_file.close()
	game.defaults(); game.load_game(); expect(game.pearls == 50, "backup save recovery")
	clear_saves(game); var malformed := FileAccess.open(str(game.SAVE_PATH), FileAccess.WRITE); malformed.store_string("not json"); malformed.close()
	game.defaults(); game.load_game(); expect(game.pearls == 42, "malformed save recovery")
	clear_saves(game)
	print("Pocket Paludarium tests: %d failures" % failures)
	quit(0 if failures == 0 else 1)

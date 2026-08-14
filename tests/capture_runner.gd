extends Node

const MainScript := preload("res://scripts/main.gd")

func capture(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://captures/" + name + ".png")

func _ready() -> void:
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path("user://captures"))
	GameState.defaults(); GameState.tutorial_complete = false; GameState.naming_prompt_state = "new"
	var main = MainScript.new(); add_child(main)
	await get_tree().process_frame
	main.screen = "onboarding"; main.refresh(); await capture("onboarding")
	GameState.set_pet_name("Lumi"); GameState.tutorial_complete = true; GameState.bond_points = 30; GameState.ensure_daily_wishes("2026-08-14")
	main.screen = "home"; main.refresh(); await capture("named-home")
	GameState.bond_points = 300; main.refresh(); await capture("kindred")
	GameState.bond_points = 30
	main.screen = "wishes"; main.refresh(); await capture("wishes")
	main.pet_behavior.trigger_feed(30); main.screen = "home"; main.refresh(); await capture("eating")
	main.pet_behavior.manual_remaining = 0.0; main.pet_behavior.idle_seconds = 76.0; GameState.bond_points = 180; GameState.placements = [{"item_id":"cozy_log", "x":0.5, "y":0.42, "layer":1, "instance_id":1}]; main.pet_behavior.update(0.0, 180, GameState.placements, true); main.refresh(); await capture("sleeping")
	GameState.bond_points = 90; main.pet_behavior.wake(); main.pet_behavior.update(0.1, 90, GameState.placements, true); main.refresh(); await capture("hide-peek")
	get_tree().quit()

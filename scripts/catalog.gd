class_name Catalog
extends RefCounted

const Item := preload("res://scripts/item_def.gd")

func all() -> Dictionary:
	return {
		"berry_bites": Item.new("berry_bites", "Berry Bites", "food", 8, "fullness", 24.0, Color("f5a6b8"), "Sweet little sinking bites."),
		"moss_pellets": Item.new("moss_pellets", "Moss Pellets", "food", 13, "fullness", 38.0, Color("9fcf91"), "A hearty algae snack."),
		"water_fern": Item.new("water_fern", "Water Fern", "decor", 18, "happiness", 2.0, Color("5cae86"), "A leafy place to hide."),
		"moon_stone": Item.new("moon_stone", "Moon Stone", "decor", 14, "happiness", 1.0, Color("8899bb"), "A smooth, silvery pebble."),
		"cozy_log": Item.new("cozy_log", "Cozy Log", "decor", 28, "happiness", 3.0, Color("9a7059"), "A hollow hideaway.", 2),
		"cloud_hide": Item.new("cloud_hide", "Cloud Hide", "decor", 42, "happiness", 5.0, Color("ddc9ed"), "A dreamy ceramic cave.", 2),
		"gentle_filter": Item.new("gentle_filter", "Gentle Filter", "equipment", 55, "water", 0.55, Color("8bc1d1"), "Slows water-quality decay.", 3),
		"pearl_bubbler": Item.new("pearl_bubbler", "Pearl Bubbler", "equipment", 65, "happiness", 1.5, Color("ffd788"), "Adds +1.5 happiness each hour and happy bubbles.", 3),
		"ribbon_hat": Item.new("ribbon_hat", "Ribbon Hat", "cosmetic", 35, "happiness", 4.0, Color("ff8fad"), "A jaunty aquatic bow.", 4),
	}

func get_item(id: String):
	return all().get(id)

func ids() -> Array[String]:
	var result: Array[String] = []
	for id in all().keys(): result.append(id)
	return result

extends Node2D

const CatalogScript := preload("res://scripts/catalog.gd")
const PetBehaviorScript := preload("res://scripts/pet_behavior.gd")
var catalog = CatalogScript.new()

const W := 720.0
const H := 1280.0
var screen := "onboarding"
var selected_item := ""
var mini_mode := ""
var mini_time := 0.0
var mini_score := 0
var combo := 0
var current_round_id := ""
var completed_mode := ""
var completed_reward: Dictionary = {}
var player_x := 360.0
var targets: Array[Dictionary] = []
var bubbles: Array[Dictionary] = []
var message := ""
var message_timer := 0.0
var elapsed_accum := 0.0
var canvas: Control
var ui: Control
var title_label: Label
var stat_label: Label
var toast: Label
var mini_hud_label: Label
var audio_player: AudioStreamPlayer
var backdrop_texture: Texture2D
var axolotl_texture: Texture2D
var axolotl_eat_texture: Texture2D
var axolotl_sleep_texture: Texture2D
var axolotl_peek_texture: Texture2D
var decor_atlas_texture: Texture2D
var pet_behavior = PetBehaviorScript.new()
var stage: Node2D
var ad_reserve := 0.0
## Forces a banner reserve in captures/tests so the shrunken layout can be checked
## on desktop, where no real banner loads.
var validation_ad_reserve := 0.0

func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	get_tree().auto_accept_quit = true
	stage = Node2D.new(); stage.name = "Stage"; add_child(stage)
	canvas = Control.new(); canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE; canvas.draw.connect(_draw_world); stage.add_child(canvas)
	ui = Control.new(); ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); stage.add_child(ui)
	audio_player = AudioStreamPlayer.new(); add_child(audio_player)
	backdrop_texture = load("res://assets/storybook/paludarium-backdrop-v1.png") as Texture2D
	axolotl_texture = load("res://assets/storybook/axolotl-swim-v1.png") as Texture2D
	axolotl_eat_texture = load("res://assets/storybook/axolotl-eat-v1.png") as Texture2D
	axolotl_sleep_texture = load("res://assets/storybook/axolotl-sleep-v1.png") as Texture2D
	axolotl_peek_texture = load("res://assets/storybook/axolotl-peek-v1.png") as Texture2D
	decor_atlas_texture = load("res://assets/storybook/decor-atlas-v1.png") as Texture2D
	GameState.state_changed.connect(refresh)
	GameState.care_action.connect(func(action: String): pet_behavior.on_care_action(action))
	screen = "home" if GameState.tutorial_complete and GameState.naming_prompt_state != "pending" else "onboarding"
	refresh()
	call_deferred("_sync_ad_bar")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED: GameState.notify_app_paused()
	elif what == NOTIFICATION_APPLICATION_RESUMED: GameState.notify_app_resumed()

func _process(delta: float) -> void:
	elapsed_accum += delta
	if elapsed_accum >= 10.0: GameState.tick(elapsed_accum); elapsed_accum = 0.0
	message_timer = maxf(0, message_timer - delta)
	if mini_mode != "": _mini_process(delta)
	pet_behavior.update(delta, GameState.bond_points, GameState.placements, bool(GameState.settings.get("reduced_motion", false)))
	canvas.queue_redraw()
	if toast != null: toast.text = message
	if stage != null and not is_equal_approx(ad_reserve, ad_bottom_reserve()): _apply_ad_reserve()

func _layout() -> void:
	_apply_ad_reserve()
	canvas.queue_redraw()

## Shrink the 720x1280 stage uniformly so the native AdMob banner never covers
## the bottom row of buttons. The banner itself is drawn by the OS below us.
func _sync_ad_bar() -> void:
	var service := _ad_service()
	if service == null:
		return
	service.attach_to(self)
	_apply_ad_reserve()

## Looked up by path rather than by the autoload identifier so this script also
## parses in the headless test/capture harnesses, which run without autoloads.
func _ad_service() -> Node:
	var tree := get_tree()
	if tree == null or not tree.root.has_node("AdBarService"):
		return null
	return tree.root.get_node("AdBarService")

func ad_bottom_reserve() -> float:
	if validation_ad_reserve > 0.0:
		return validation_ad_reserve
	var service := _ad_service()
	if service == null or not service.ads_enabled():
		return 0.0
	return clampf(service.banner_height(), 0.0, H * 0.25)

func _apply_ad_reserve() -> void:
	if stage == null:
		return
	ad_reserve = ad_bottom_reserve()
	var factor := clampf((H - ad_reserve) / H, 0.5, 1.0)
	stage.scale = Vector2(factor, factor)
	stage.position = Vector2((W - W * factor) * 0.5, 0.0)

func clear_ui() -> void:
	for child in ui.get_children(): child.queue_free()

func make_label(text_value: String, pos: Vector2, size: Vector2, font_size: int = 24, color: Color = Color.WHITE) -> Label:
	var l := Label.new(); l.text = text_value; l.position = pos; l.size = size; l.add_theme_font_size_override("font_size", font_size); l.add_theme_color_override("font_color", color); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; ui.add_child(l); return l

func make_button(text_value: String, rect: Rect2, action: Callable, tint: Color = Color("547c78")) -> Button:
	var b := Button.new(); b.text = text_value; b.position = rect.position; b.size = rect.size; b.add_theme_font_size_override("font_size", 22 if not GameState.settings.get("large_targets", false) else 26)
	var style := StyleBoxFlat.new(); style.bg_color = tint; style.corner_radius_top_left = 18; style.corner_radius_top_right = 18; style.corner_radius_bottom_left = 18; style.corner_radius_bottom_right = 18; style.border_width_left = 2; style.border_width_right = 2; style.border_width_top = 2; style.border_width_bottom = 2; style.border_color = Color("ffffff80")
	b.add_theme_stylebox_override("normal", style); b.pressed.connect(func(): play_sfx(330.0, 0.045, 0.08); action.call()); ui.add_child(b); return b

func play_sfx(frequency: float, duration: float = 0.06, volume: float = 0.10) -> void:
	if audio_player == null or not bool(GameState.settings.get("sound", true)): return
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050.0; generator.buffer_length = maxf(0.08, duration + 0.03)
	audio_player.stream = generator; audio_player.play()
	var playback = audio_player.get_stream_playback()
	if playback == null: return
	var frames := int(generator.mix_rate * duration)
	for i in frames:
		var envelope := 1.0 - float(i) / float(maxi(1, frames))
		var sample := sin(TAU * frequency * float(i) / generator.mix_rate) * volume * envelope
		playback.push_frame(Vector2(sample, sample))

func refresh() -> void:
	clear_ui(); canvas.queue_redraw()
	if screen == "onboarding": build_onboarding()
	elif screen == "home": build_home()
	elif screen == "shop": build_shop()
	elif screen == "decorate": build_decorate()
	elif screen == "mini_select": build_minis()
	elif screen == "mini": build_mini()
	elif screen == "results": build_results()
	elif screen == "settings": build_settings()
	elif screen == "wishes": build_wishes()

func build_onboarding() -> void:
	make_label("Pocket Paludarium", Vector2(40, 125), Vector2(640, 80), 42, Color("fff4d6"))
	make_label("What should we call this little friend?\nYou can change it later in settings.", Vector2(75, 710), Vector2(570, 105), 25, Color("f7faf7"))
	var field := LineEdit.new(); field.text = GameState.pet_name; field.placeholder_text = "Pip"; field.max_length = 16; field.position = Vector2(130, 835); field.size = Vector2(460, 58); field.alignment = HORIZONTAL_ALIGNMENT_CENTER; field.add_theme_font_size_override("font_size", 27); ui.add_child(field)
	make_button("Meet your new friend", Rect2(90, 925, 540, 82), func(): GameState.set_pet_name(field.text); GameState.tutorial_complete = true; GameState.save_game(); screen = "home"; refresh(), Color("d87691"))

func build_home() -> void:
	var home_title := "%s's Paludarium" % GameState.pet_name
	make_label(home_title, Vector2(30, 28), Vector2(455, 52), home_title_font_size(GameState.pet_name), Color("fff6dc"))
	make_label("◌ %d pearls" % GameState.pearls, Vector2(505, 30), Vector2(180, 48), 21, Color("ffe3a3"))
	make_label("Fullness  %d     Happiness  %d     Water  %d" % [roundi(GameState.fullness), roundi(GameState.happiness), roundi(GameState.water_quality)], Vector2(35, 775), Vector2(650, 46), 19, Color("f5fff8"))
	make_label("%s · %d bond · Wishes %d/3" % [GameState.bond_title(), GameState.bond_points, GameState.completed_wishes()], Vector2(35, 817), Vector2(650, 28), 17, Color("ffe3a3"))
	make_button("Feed", Rect2(45, 855, 195, 70), func(): quick_feed(), Color("d87691"))
	make_button("Clean", Rect2(262, 855, 195, 70), func(): care_clean(), Color("5395ad"))
	make_button("Pet", Rect2(480, 855, 195, 70), func(): care_pet(), Color("8a769e"))
	make_button("Decorate", Rect2(45, 950, 195, 70), func(): screen = "decorate"; refresh())
	make_button("Shop", Rect2(262, 950, 195, 70), func(): screen = "shop"; refresh())
	make_button("Play", Rect2(480, 950, 195, 70), func(): screen = "mini_select"; refresh(), Color("ce8a5f"))
	make_button("Wishes", Rect2(262, 1035, 195, 54), func(): screen = "wishes"; refresh(), Color("7b739e"))
	make_button("⚙", Rect2(615, 1090, 60, 60), func(): screen = "settings"; refresh(), Color("526b76"))
	toast = make_label(message, Vector2(75, 1060), Vector2(570, 55), 20, Color("fff1c3"))
	if GameState.welcome_summary != "": say(GameState.welcome_summary); GameState.welcome_summary = ""

func home_title_font_size(pet_name: String) -> int:
	return 23 if ("%s's Paludarium" % pet_name).length() > 22 else 31

func quick_feed() -> void:
	if GameState.feed("berry_bites"):
		if pet_behavior.trigger_feed(GameState.bond_points): say("Nom nom! Berry bites served.")
		else: say("A gentle snack — eating unlocks at Curious bond.")
	else: say("No Berry Bites left — visit the shop.")

func care_clean() -> void:
	pet_behavior.wake(); GameState.clean(); say("Sparkly clean water!")

func care_pet() -> void:
	pet_behavior.wake(); GameState.pet(); say("A happy little wiggle!")

func build_wishes() -> void:
	GameState.ensure_daily_wishes()
	make_label("Today's little wishes", Vector2(35, 60), Vector2(650, 60), 35, Color("fff4d6"))
	make_label("Each wish gives 6 pearls and 8 bonus bond.", Vector2(45, 120), Vector2(630, 35), 18, Color("e4f7f2"))
	var y := 230
	for wish in GameState.wishes:
		var done := bool(wish.get("claimed", false))
		var card := make_label(("Done: " if done else "Wish: ") + str(wish.get("title", "A little wish")) + ("\nClaimed" if done else "\nComplete the matching action"), Vector2(55, y), Vector2(610, 105), 22, Color("bce5c2") if done else Color("fff2d1"))
		var card_style := StyleBoxFlat.new(); card_style.bg_color = Color("102f3c", 0.82); card_style.corner_radius_top_left = 18; card_style.corner_radius_top_right = 18; card_style.corner_radius_bottom_left = 18; card_style.corner_radius_bottom_right = 18; card.add_theme_stylebox_override("normal", card_style)
		y += 150
	make_button("Home", Rect2(35, 1110, 160, 65), func(): screen = "home"; refresh())

func build_shop() -> void:
	make_label("The Ripple Shop", Vector2(40, 38), Vector2(640, 60), 34, Color("fff4d6")); make_button("← Home", Rect2(35, 1110, 160, 65), func(): screen = "home"; refresh())
	var y := 125
	for id in catalog.ids():
		var item = catalog.get_item(id)
		var item_id: String = id
		make_atlas_icon(item_id, Rect2(42, y + 2, 70, 70))
		make_label("%s  ·  %d pearls\n%s" % [item.title, item.price, item.description], Vector2(115, y), Vector2(355, 76), 18, item.color)
		make_button("Buy", Rect2(510, y + 8, 150, 56), func(): buy_from_shop(item_id), Color("7a9c83"))
		y += 96

func buy_from_shop(item_id: String) -> void:
	var item = catalog.get_item(item_id)
	if GameState.buy(item_id):
		say("Added %s!" % item.title)
	else:
		say("Not enough pearls.")
	refresh()

func build_decorate() -> void:
	make_label("Decorate your water world", Vector2(25, 30), Vector2(670, 56), 29, Color("fff4d6")); make_label("Tap an item, then tap the tank to place it. Tap placed decor to return it.", Vector2(38, 780), Vector2(644, 42), 17, Color("f5fff8"))
	var y := 850; var x := 35
	for id in catalog.ids():
		var item = catalog.get_item(id)
		if item.kind == "food": continue
		var item_id: String = id
		var count := int(GameState.inventory.get(id, 0))
		make_button("%s\n×%d" % [item.title, count], Rect2(x, y, 200, 75), func(): select_decor(item_id), item.color.darkened(0.25))
		x += 220
		if x > 500: x = 35; y += 90
	make_button("← Home", Rect2(35, 1120, 160, 60), func(): selected_item = ""; screen = "home"; refresh())
	toast = make_label(message, Vector2(220, 1120), Vector2(450, 60), 19, Color("fff1c3"))

func select_decor(item_id: String) -> void:
	selected_item = item_id
	var item = catalog.get_item(item_id)
	say("Place %s in the tank." % item.title)

func atlas_region(item_id: String) -> Rect2:
	var cell := 418.0
	var cells := {
		"water_fern": Vector2i(0, 0), "moon_stone": Vector2i(1, 0), "cozy_log": Vector2i(2, 0),
		"cloud_hide": Vector2i(0, 1), "gentle_filter": Vector2i(1, 1), "pearl_bubbler": Vector2i(2, 1),
		"berry_bites": Vector2i(0, 2), "moss_pellets": Vector2i(1, 2), "ribbon_hat": Vector2i(2, 2)
	}
	var cell_index: Vector2i = cells.get(item_id, Vector2i(-1, -1))
	return Rect2(Vector2(cell_index.x * cell, cell_index.y * cell), Vector2(cell, cell))

func make_atlas_icon(item_id: String, rect: Rect2) -> TextureRect:
	var icon := TextureRect.new()
	icon.position = rect.position; icon.size = rect.size; icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if decor_atlas_texture != null:
		var atlas := AtlasTexture.new(); atlas.atlas = decor_atlas_texture; atlas.region = atlas_region(item_id); icon.texture = atlas
	ui.add_child(icon)
	return icon

func build_minis() -> void:
	make_label("Play together", Vector2(50, 70), Vector2(620, 58), 36, Color("fff4d6"))
	make_label("Bubble Pop\n30 seconds · Build combos by popping pearly bubbles.", Vector2(65, 270), Vector2(590, 120), 24, Color("dff7ff"))
	make_button("Play Bubble Pop", Rect2(115, 410, 490, 75), func(): start_mini("bubble"), Color("579eb8"))
	make_label("Food Catch\n45 seconds · Steer your axolotl and dodge drifting debris.", Vector2(65, 590), Vector2(590, 120), 24, Color("ffe6b2"))
	make_button("Play Food Catch", Rect2(115, 730, 490, 75), func(): start_mini("catch"), Color("ca865e"))
	make_button("← Home", Rect2(35, 1110, 160, 65), func(): screen = "home"; refresh())

func start_mini(mode: String) -> void:
	mini_mode = mode; mini_time = 30.0 if mode == "bubble" else 45.0
	if OS.has_feature("debug") and ProjectSettings.has_setting("debug/minigame_duration_override"): mini_time = float(ProjectSettings.get_setting("debug/minigame_duration_override"))
	mini_score = 0; combo = 0; player_x = 360.0; targets = []; completed_mode = ""; completed_reward = {}; current_round_id = "%s_%d" % [mode, Time.get_ticks_msec()]; screen = "mini"; refresh()

func build_mini() -> void:
	make_label("Bubble Pop" if mini_mode == "bubble" else "Food Catch", Vector2(30, 30), Vector2(370, 50), 31, Color("fff4d6"))
	mini_hud_label = make_label("%02d  ·  Score %d" % [ceili(mini_time), mini_score], Vector2(400, 30), Vector2(290, 50), 25, Color("fff4d6"))
	make_label("Tap bubbles for a combo!" if mini_mode == "bubble" else "Tap left/right to steer. Catch food, avoid debris!", Vector2(35, 1120), Vector2(650, 50), 20, Color("f6fff8"))

func build_results() -> void:
	var reward := completed_reward if not completed_reward.is_empty() else GameState.reward_for(mini_score, completed_mode)
	var mode_title := "Bubble Pop" if completed_mode == "bubble" else "Food Catch"
	make_label("%s complete!" % mode_title, Vector2(50, 230), Vector2(620, 62), 38, Color("fff4d6")); make_label("%s tier\n+%d pearls" % [reward.tier, reward.pearls], Vector2(120, 420), Vector2(480, 180), 38, Color("ffe09c"))
	make_button("Back home", Rect2(130, 810, 460, 80), func(): screen = "home"; refresh(), Color("d87691"))

func build_settings() -> void:
	make_label("Cozy settings", Vector2(50, 100), Vector2(620, 60), 36, Color("fff4d6"))
	make_button("Sound: %s" % ("On" if GameState.settings.sound else "Off"), Rect2(95, 300, 530, 74), func(): GameState.settings.sound = not GameState.settings.sound; GameState.save_game(); refresh())
	make_button("Reduced motion: %s" % ("On" if GameState.settings.reduced_motion else "Off"), Rect2(95, 405, 530, 74), func(): GameState.settings.reduced_motion = not GameState.settings.reduced_motion; GameState.save_game(); refresh())
	make_button("Large targets: %s" % ("On" if GameState.settings.large_targets else "Off"), Rect2(95, 510, 530, 74), func(): GameState.settings.large_targets = not GameState.settings.large_targets; GameState.save_game(); refresh())
	var name_field := LineEdit.new(); name_field.text = GameState.pet_name; name_field.max_length = 16; name_field.position = Vector2(95, 640); name_field.size = Vector2(350, 65); name_field.add_theme_font_size_override("font_size", 24); ui.add_child(name_field)
	make_button("Save name", Rect2(460, 640, 165, 65), func(): GameState.set_pet_name(name_field.text); say("Hello, %s!" % GameState.pet_name); refresh(), Color("d87691"))
	make_button("← Home", Rect2(35, 1110, 160, 65), func(): screen = "home"; refresh())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var p: Vector2 = event.position * Vector2(W / get_viewport_rect().size.x, H / get_viewport_rect().size.y)
		if stage != null:
			p = (p - stage.position) / stage.scale
		if screen == "decorate" and p.y > 130 and p.y < 755:
			for placed in GameState.placements:
				var q := Vector2(float(placed.x) * W, float(placed.y) * H)
				if q.distance_to(p) < 48.0: GameState.return_placement(int(placed.instance_id)); say("Returned to your inventory."); refresh(); return
			if selected_item != "":
				var placed := GameState.place(selected_item, Vector2(p.x / W, p.y / H))
				if placed.is_empty(): say("That spot is too close to another item.")
				else: say("Placed! Tap it to put it away.")
				refresh()
		elif screen == "mini": mini_tap(p)

func mini_tap(p: Vector2) -> void:
	if mini_mode == "bubble":
		for i in range(targets.size() - 1, -1, -1):
			if Vector2(targets[i].pos).distance_to(p) < 55.0: targets.remove_at(i); combo += 1; mini_score += 1 + mini(combo / 5, 4); say("Combo ×%d" % combo); play_sfx(620.0 + combo * 18.0, 0.05, 0.12); return
		combo = 0; say("Ripple! Try a bubble.")
	else: player_x = clampf(p.x, 80.0, 640.0)

func _mini_process(delta: float) -> void:
	mini_time -= delta
	if mini_time <= 0.0:
		finish_mini()
		return
	var chance := 1.6 if mini_mode == "bubble" else 1.2
	if randf() < chance * delta:
		targets.append({"pos": Vector2(randf_range(80, 640), randf_range(180, 970)), "kind": "bubble" if mini_mode == "bubble" else ("food" if randf() < 0.72 else "debris"), "age": 0.0})
	for i in range(targets.size() - 1, -1, -1):
		targets[i].age = float(targets[i].age) + delta
		if mini_mode == "catch":
			targets[i].pos.y = float(targets[i].pos.y) + 125.0 * delta
			if Vector2(targets[i].pos).distance_to(Vector2(player_x, 955)) < 62.0:
				if targets[i].kind == "food": mini_score += 1
				else: mini_score = maxi(0, mini_score - 2)
				targets.remove_at(i); continue
		if float(targets[i].age) > 5.5 or Vector2(targets[i].pos).y > 1070: targets.remove_at(i)
	if not GameState.settings.reduced_motion: player_x = lerpf(player_x, player_x + sin(Time.get_ticks_msec() * 0.004) * 4.0, delta)
	refresh_mini_labels()

func refresh_mini_labels() -> void:
	if is_instance_valid(mini_hud_label): mini_hud_label.text = "%02d  ·  Score %d" % [ceili(maxf(0.0, mini_time)), mini_score]

func finish_mini() -> void:
	if mini_mode == "": return
	mini_time = 0.0; completed_mode = mini_mode
	var award := GameState.award_minigame_round(current_round_id, mini_score, completed_mode)
	completed_reward = award.get("reward", {}) as Dictionary
	mini_mode = ""; screen = "results"; refresh()

func say(value: String) -> void:
	message = value; message_timer = 3.5

func _draw_world() -> void:
	var scale := minf(get_viewport_rect().size.x / W, get_viewport_rect().size.y / H)
	var offset := (get_viewport_rect().size - Vector2(W, H) * scale) * 0.5
	canvas.draw_set_transform(offset, 0.0, Vector2(scale, scale))
	if backdrop_texture != null:
		canvas.draw_texture_rect(backdrop_texture, Rect2(0, 0, W, H), false)
		canvas.draw_rect(Rect2(0, 0, W, 118), Color("092333", 0.42))
		canvas.draw_rect(Rect2(0, 760, W, 520), Color("092333", 0.30))
	else:
		canvas.draw_rect(Rect2(0, 0, W, H), Color("203e52"))
	# Soft storybook sky, land, and rounded glass tank.
	if backdrop_texture == null:
		canvas.draw_circle(Vector2(600, 160), 105, Color("f7cb82", 0.35))
		canvas.draw_rect(Rect2(0, 680, W, 600), Color("355d65"))
	var tank := Rect2(38, 130, 644, 610)
	canvas.draw_style_box(_rounded(Color("d4f5ed", 0.12), 34), tank)
	if backdrop_texture == null:
		canvas.draw_style_box(_rounded(Color("7ec8d5", 0.86), 34), tank)
		canvas.draw_style_box(_rounded(Color("d4f5ed", 0.32), 34), Rect2(53, 146, 614, 580))
		canvas.draw_rect(Rect2(55, 500, 610, 225), Color("4ca9bf", 0.60))
		canvas.draw_circle(Vector2(190, 230), 120, Color("6cae84", 0.75)); canvas.draw_circle(Vector2(570, 215), 145, Color("75b58d", 0.70))
	# gravel
	if backdrop_texture == null:
		for x in range(75, 655, 43): canvas.draw_circle(Vector2(x, 694 + (x % 3) * 6), 18, Color("65869a"))
	if pet_behavior.pose == "peek" and mini_mode == "":
		_draw_axolotl(pet_draw_position()); _draw_placements()
	else:
		_draw_placements(); _draw_axolotl(pet_draw_position() if mini_mode == "" else Vector2(player_x, 955))
	if mini_mode != "":
		for target in targets:
			var p: Vector2 = target.pos
			if target.kind == "bubble": canvas.draw_circle(p, 30, Color("e7faff", 0.75)); canvas.draw_circle(p - Vector2(9, 9), 7, Color.WHITE)
			elif target.kind == "food": canvas.draw_circle(p, 23, Color("f8d477")); canvas.draw_circle(p - Vector2(6, 6), 5, Color("fff4c4"))
			else: canvas.draw_rect(Rect2(p - Vector2(19, 14), Vector2(38, 28)), Color("765c56"))
	if GameState.has_bubbler() and mini_mode == "":
		for n in 5: canvas.draw_circle(Vector2(555 + sin(Time.get_ticks_msec() * .002 + n) * 10, 590 - n * 35), 6 + n, Color("e6faff", 0.65))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _rounded(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new(); box.bg_color = color; box.corner_radius_top_left = radius; box.corner_radius_top_right = radius; box.corner_radius_bottom_left = radius; box.corner_radius_bottom_right = radius; return box

func pet_draw_position() -> Vector2:
	return pet_behavior.current_position * Vector2(W, H)

func _draw_axolotl(p: Vector2) -> void:
	var pose_texture := axolotl_texture
	if pet_behavior.pose == "eat" and axolotl_eat_texture != null: pose_texture = axolotl_eat_texture
	elif pet_behavior.pose == "sleep" and axolotl_sleep_texture != null: pose_texture = axolotl_sleep_texture
	elif pet_behavior.pose == "peek" and axolotl_peek_texture != null: pose_texture = axolotl_peek_texture
	if pose_texture != null:
		var idle := 0.0 if GameState.settings.reduced_motion else sin(Time.get_ticks_msec() * 0.003) * 7.0
		var scale := 1.0 if GameState.settings.reduced_motion else 1.0 + sin(Time.get_ticks_msec() * 0.002) * 0.025
		var tint := Color(1.0, 1.0 - maxf(0.0, 45.0 - GameState.happiness) * 0.006, 1.0 - maxf(0.0, 45.0 - GameState.water_quality) * 0.008, 1.0)
		var size := Vector2(260, 208) * scale
		canvas.draw_texture_rect(pose_texture, Rect2(p + Vector2(-130, -104 + idle), size), false, tint)
		if GameState.bond_unlocked("Kindred"): _draw_kindred_celebration(p)
		return
	canvas.draw_circle(p + Vector2(0, 15), 62, Color("f5a0b4")); canvas.draw_circle(p + Vector2(48, 25), 35, Color("f5a0b4"))
	for s in [-1, 1]:
		canvas.draw_circle(p + Vector2(-35, -35) * s, 17, Color("e77799")); canvas.draw_circle(p + Vector2(-25, -58) * s, 13, Color("f38ba6"))
	canvas.draw_circle(p + Vector2(18, -11), 8, Color("263949")); canvas.draw_circle(p + Vector2(38, -11), 8, Color("263949")); canvas.draw_arc(p + Vector2(28, 15), 13, 0.2, 2.9, 16, Color("613b50"), 3)

func _draw_kindred_celebration(p: Vector2) -> void:
	var heart := p + Vector2(105, -92)
	var gold := Color("ffd56b")
	canvas.draw_circle(heart + Vector2(-8, -5), 9, gold)
	canvas.draw_circle(heart + Vector2(8, -5), 9, gold)
	canvas.draw_colored_polygon(PackedVector2Array([heart + Vector2(-16, -4), heart + Vector2(16, -4), heart + Vector2(0, 19)]), gold)
	canvas.draw_circle(heart + Vector2(-5, -6), 2.5, Color("fff3bd"))
	if bool(GameState.settings.get("reduced_motion", false)): return
	var phase := Time.get_ticks_msec() * 0.002
	for n in 6:
		var angle := phase + float(n) * TAU / 6.0
		var radius := 52.0 + fmod(phase * 17.0 + n * 9.0, 22.0)
		var sparkle := heart + Vector2(cos(angle), sin(angle)) * radius + Vector2(0, sin(phase * 2.0 + n) * 8.0)
		canvas.draw_circle(sparkle, 3.0 + float(n % 2), Color("ffe8a4", 0.9))

func _draw_placements() -> void:
	var sorted := GameState.placements.duplicate(); sorted.sort_custom(func(a, b): return int(a.layer) < int(b.layer))
	for placed in sorted:
		var item = catalog.get_item(str(placed.item_id)); if item == null: continue
		var p := Vector2(float(placed.x) * W, float(placed.y) * H)
		if decor_atlas_texture != null:
			canvas.draw_texture_rect_region(decor_atlas_texture, Rect2(p - Vector2(54, 54), Vector2(108, 108)), atlas_region(item.id))
			continue
		if item.id == "water_fern":
			for n in 4: canvas.draw_line(p, p + Vector2((n - 1.5) * 17, -62 + abs(n - 1) * 12), item.color, 11)
		elif item.id == "cozy_log" or item.id == "cloud_hide": canvas.draw_circle(p, 48, item.color); canvas.draw_circle(p + Vector2(8, 8), 22, Color("254357"))
		elif item.id == "gentle_filter": canvas.draw_rect(Rect2(p - Vector2(28, 38), Vector2(56, 76)), item.color); canvas.draw_line(p + Vector2(0, -38), p + Vector2(0, -73), item.color, 10)
		elif item.id == "pearl_bubbler": canvas.draw_circle(p, 30, item.color); canvas.draw_circle(p - Vector2(0, 34), 8, Color("e6faff"))
		elif item.id == "ribbon_hat": canvas.draw_circle(p, 22, item.color); canvas.draw_circle(p + Vector2(34, 0), 22, item.color); canvas.draw_circle(p + Vector2(17, 0), 12, Color("ffe4ec"))
		else: canvas.draw_circle(p, 34, item.color); canvas.draw_circle(p - Vector2(9, 8), 10, Color("ffffff55"))

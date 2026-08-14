class_name PetBehavior
extends RefCounted

const EAT_SECONDS := 2.4
const SLEEP_IDLE_SECONDS := 75.0
const VISIT_SECONDS := 4.0
const VISIT_COOLDOWN_SECONDS := 12.0

var pose := "swim"
var manual_remaining := 0.0
var idle_seconds := 0.0
var visit_remaining := 0.0
var visit_cooldown := 0.0
var target_kind := ""
var target_position := Vector2(0.5, 0.43)
var current_position := Vector2(0.5, 0.43)
var travel_progress := 0.0

func trigger_feed(bond_points: int) -> bool:
	wake()
	if bond_points < 30:
		return false
	pose = "eat"
	manual_remaining = EAT_SECONDS
	return true

func wake() -> void:
	manual_remaining = 0.0
	idle_seconds = 0.0
	visit_remaining = 0.0
	pose = "swim"
	target_kind = ""

func on_care_action(_action: String = "") -> void:
	wake()

func _placement_for(ids: Array, placements: Array) -> Dictionary:
	for placement in placements:
		if str(placement.get("item_id", "")) in ids:
			return placement
	return {}

func _position_for(placement: Dictionary, kind: String) -> Vector2:
	var p := Vector2(float(placement.get("x", 0.5)), float(placement.get("y", 0.48)))
	if kind == "hide": p += Vector2(-0.06, -0.04)
	elif kind == "rest": p += Vector2(0.02, -0.12)
	else: p += Vector2(0.02, -0.10)
	return Vector2(clampf(p.x, 0.18, 0.82), clampf(p.y, 0.24, 0.55))

func _move_to(target: Vector2, delta: float, reduced_motion: bool, home: Vector2) -> void:
	target_position = target
	if reduced_motion:
		current_position = target
		travel_progress = 1.0 if target.distance_to(home) > 0.01 else 0.0
		return
	current_position = current_position.lerp(target, minf(1.0, delta * 3.2))
	travel_progress = clampf(current_position.distance_to(home) / maxf(0.01, target.distance_to(home)), 0.0, 1.0) if target.distance_to(home) > 0.01 else 0.0

func update(delta: float, bond_points: int, placements: Array, reduced_motion: bool, home: Vector2 = Vector2(0.5, 0.43)) -> String:
	idle_seconds += maxf(0.0, delta)
	visit_cooldown = maxf(0.0, visit_cooldown - delta)
	var hide := _placement_for(["cozy_log", "cloud_hide"], placements)
	var curiosity := _placement_for(["water_fern", "pearl_bubbler"], placements)
	var rest := hide if not hide.is_empty() else curiosity
	# Sleeping deliberately overrides an in-flight ambient visit, but never manual eating.
	if manual_remaining > 0.0:
		manual_remaining = maxf(0.0, manual_remaining - delta)
		pose = "eat"; target_kind = "feed"; _move_to(home, delta, reduced_motion, home)
		return pose
	if bond_points >= 180 and idle_seconds >= SLEEP_IDLE_SECONDS and not rest.is_empty():
		pose = "sleep"; target_kind = "rest"; visit_remaining = 0.0; _move_to(_position_for(rest, "rest"), delta, reduced_motion, home)
		return pose
	if visit_remaining > 0.0:
		visit_remaining = maxf(0.0, visit_remaining - delta)
		if visit_remaining > 0.0:
			pose = "peek" if target_kind == "hide" else "curious"
			var active := hide if target_kind == "hide" else curiosity
			if not active.is_empty(): _move_to(_position_for(active, target_kind), delta, reduced_motion, home)
			return pose
		visit_cooldown = VISIT_COOLDOWN_SECONDS; target_kind = ""
	# Start only bounded visits; after expiry a cooldown ensures the pet returns to swimming.
	if visit_cooldown <= 0.0:
		if bond_points >= 90 and not hide.is_empty():
			target_kind = "hide"; visit_remaining = VISIT_SECONDS; pose = "peek"; _move_to(_position_for(hide, "hide"), delta, reduced_motion, home); return pose
		if bond_points >= 30 and not curiosity.is_empty():
			target_kind = "plant"; visit_remaining = VISIT_SECONDS; pose = "curious"; _move_to(_position_for(curiosity, "plant"), delta, reduced_motion, home); return pose
	pose = "swim"; target_kind = ""; _move_to(home, delta, reduced_motion, home)
	return pose

func snapshot() -> Dictionary:
	return {"pose": pose, "manual_remaining": manual_remaining, "idle_seconds": idle_seconds, "visit_remaining": visit_remaining, "visit_cooldown": visit_cooldown, "target_kind": target_kind, "target_position": target_position, "current_position": current_position, "travel_progress": travel_progress}

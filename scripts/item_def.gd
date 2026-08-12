class_name ItemDef
extends RefCounted

var id: String
var title: String
var kind: String
var price: int
var stat: String
var power: float
var color: Color
var description: String
var layer: int

func _init(p_id: String, p_title: String, p_kind: String, p_price: int, p_stat: String, p_power: float, p_color: Color, p_description: String, p_layer: int = 1) -> void:
	id = p_id
	title = p_title
	kind = p_kind
	price = p_price
	stat = p_stat
	power = p_power
	color = p_color
	description = p_description
	layer = p_layer

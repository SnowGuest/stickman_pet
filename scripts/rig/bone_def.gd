class_name BoneDef
extends RefCounted

var id: StringName = &""
var parent: StringName = &""
var start_joint: StringName = &""
var end_joint: StringName = &""
var length: float = 20.0
var rest_abs_deg: float = 0.0
var limit_lo_deg: float = -180.0
var limit_hi_deg: float = 180.0
var mass: float = 1.0
var width: float = 6.0
var depth_layer: int = 0
var mirror: bool = false

# compile() 填充
var index: int = -1
var parent_index: int = -1
var start_idx: int = -1
var end_idx: int = -1
var rest_rel: float = 0.0
var lo: float = 0.0
var hi: float = 0.0


func from_dict(data: Dictionary) -> void:
	id = StringName(str(data.get("id", "")))
	parent = StringName(str(data.get("parent", "")))
	start_joint = StringName(str(data.get("start_joint", "")))
	end_joint = StringName(str(data.get("end_joint", "")))
	length = float(data.get("length", 20.0))
	rest_abs_deg = float(data.get("rest_abs_deg", 0.0))
	limit_lo_deg = float(data.get("limit_lo_deg", -180.0))
	limit_hi_deg = float(data.get("limit_hi_deg", 180.0))
	mass = float(data.get("mass", 1.0))
	width = float(data.get("width", 6.0))
	depth_layer = int(data.get("depth_layer", 0))
	mirror = bool(data.get("mirror", false))

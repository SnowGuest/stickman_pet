extends Node3D

## 3D fixed-orthographic-camera stickman prototype.
## Renders 13 bone capsules + joint spheres + hollow torus head into a
## transparent SubViewport, then saves a screenshot for comparison.

const COLOR := Color("#FF6600")
const LINE_RADIUS := 3.0
const JOINT_RADIUS := 3.0
const Z_BACK := -2.0
const Z_FRONT := 2.0

var definition: RigDefinition
var pose: RigPose
var _material: StandardMaterial3D


func _ready() -> void:
	definition = RigDefinition.new()
	definition.load_from_file("res://assets/rigs/stickman.json")
	definition.compile()
	pose = definition.create_rest_pose()
	pose.root_pos = Vector2.ZERO
	_apply_display_pose()
	RigState.resolve(definition, pose)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 640)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.12, 0.15, 1.0)
	world_env.environment = env
	viewport.add_child(world_env)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 200.0
	camera.position = Vector3(2.0, 0.0, 10.0)
	camera.look_at_from_position(Vector3(2.0, 0.0, 10.0), Vector3.ZERO,
			Vector3.UP)
	viewport.add_child(camera)

	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = COLOR
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_build_character(viewport)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.save_png("user://stickman3d_prototype.png")
	print("[3d] saved ", image.get_size())
	get_tree().quit()


func _apply_display_pose() -> void:
	_set_rel(&"upper_arm_l", -150.0)
	_set_rel(&"upper_arm_r", 150.0)
	_set_rel(&"forearm_l", 0.0)
	_set_rel(&"forearm_r", 0.0)
	_set_rel(&"thigh_l", 100.0)
	_set_rel(&"thigh_r", 80.0)
	_set_rel(&"shin_l", -10.0)
	_set_rel(&"shin_r", 10.0)


func _set_rel(bone_id: StringName, degrees: float) -> void:
	for i in definition.bones.size():
		if definition.bones[i].id == bone_id:
			pose.rel[i] = deg_to_rad(degrees)
			return


func _build_character(viewport: SubViewport) -> void:
	for b in definition.bones:
		var is_left := str(b.id).ends_with("_l")
		var is_right := str(b.id).ends_with("_r")
		var z := Z_BACK if is_left else (Z_FRONT if is_right else 0.0)
		if str(b.id).begins_with("spine") or str(b.id).begins_with("neck") \
				or str(b.id).begins_with("head"):
			z = 0.0
		_add_bone(viewport, pose.joint_pos[b.start_idx], pose.joint_pos[b.end_idx],
				z)
		if b.id not in [&"spine", &"neck", &"head"]:
			_add_joint(viewport, pose.joint_pos[b.start_idx], z)

	_add_joint(viewport, pose.joint_pos[definition.joint_index[&"chest"]], 0.0)
	_add_joint(viewport, pose.joint_pos[definition.joint_index[&"pelvis"]], 0.0)
	_add_head(viewport)


func _world_point(local: Vector2, z: float) -> Vector3:
	return Vector3(local.x, -local.y, z)


func _add_bone(viewport: SubViewport, start_local: Vector2, end_local: Vector2,
		z: float) -> void:
	var a := _world_point(start_local, z)
	var b := _world_point(end_local, z)
	var dir := b - a
	var length := dir.length()
	if length < 0.01:
		return
	var mesh := CylinderMesh.new()
	mesh.height = length
	mesh.top_radius = LINE_RADIUS
	mesh.bottom_radius = LINE_RADIUS
	mesh.radial_segments = 12
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material
	instance.position = (a + b) * 0.5
	instance.rotation.z = atan2(dir.y, dir.x) - PI * 0.5
	viewport.add_child(instance)


func _add_joint(viewport: SubViewport, local: Vector2, z: float) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = JOINT_RADIUS
	mesh.height = JOINT_RADIUS * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material
	instance.position = _world_point(local, z)
	viewport.add_child(instance)


func _add_head(viewport: SubViewport) -> void:
	var neck := pose.joint_pos[definition.joint_index[&"neck_top"]]
	var center := neck + Vector2(0.0, -definition.head_radius)
	var mesh := TorusMesh.new()
	mesh.inner_radius = definition.head_radius - definition.head_line_width * 0.5
	mesh.outer_radius = definition.head_radius + definition.head_line_width * 0.5
	mesh.rings = 24
	mesh.ring_segments = 12
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material
	instance.position = _world_point(center, 0.0)
	instance.rotation.x = PI * 0.5
	viewport.add_child(instance)

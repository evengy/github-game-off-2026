extends Node3D
class_name PieceCooldown

## Group holding every cooldown whose timer is running (piece still in the tower).
const ACTIVE_GROUP := &"active_cooldowns"

## Seconds left when the piece starts blinking red.
@export_range(1.0, 120.0, 1.0) var warning_time: float = 30.0
## Seconds between blink toggles.
@export_range(0.05, 2.0, 0.05) var blink_interval: float = 0.25
## Material shown while blinking.
@export var warning_material: Material
## Pieces within this distance of the centre are pushed when it explodes (m).
@export_range(0.1, 5.0, 0.1) var explosion_radius: float = 1.0
## Impulse applied to each pushed piece (N·s). A piece weighs 1 kg by default.
@export_range(0.0, 50.0, 0.5) var explosion_impulse: float = 6.0

@onready var _piece := get_parent() as RigidBody3D
@onready var _timer := $CooldownTimer as Timer
@onready var _labels := $CooldownLabels as Node3D
@onready var _mesh := get_parent().get_node("MeshInstance3D") as MeshInstance3D

var _shown_seconds: int = -1

func _ready() -> void:
	_timer.timeout.connect(_explode)
	set_process(false)

func has_cooldown() -> bool:
	return not _timer.is_stopped()

func get_time_left() -> float:
	return _timer.time_left

func start_cooldown(seconds: float) -> void:
	_timer.start(seconds)
	add_to_group(ACTIVE_GROUP)
	_labels.show()
	_shown_seconds = -1
	set_process(true)

func defuse() -> void:
	_timer.stop()
	remove_from_group(ACTIVE_GROUP)
	_labels.hide()
	_mesh.material_override = null
	set_process(false)

func _process(_delta: float) -> void:
	var left = _timer.time_left
	var seconds = ceili(left)
	if seconds != _shown_seconds:
		_shown_seconds = seconds
		for label: Label3D in _labels.get_children():
			label.text = str(seconds)
	var blink_on = left < warning_time and int(left / blink_interval) % 2 == 0
	_mesh.material_override = warning_material if blink_on else null

# Pushes nearby pieces outward (pieces straight above get pushed up), then removes the piece.
func _explode() -> void:
	remove_from_group(ACTIVE_GROUP)
	var sphere = SphereShape3D.new()
	sphere.radius = explosion_radius
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, _piece.global_position)
	query.collision_mask = _piece.collision_mask
	query.exclude = [_piece.get_rid()]
	for hit in _piece.get_world_3d().direct_space_state.intersect_shape(query, 32):
		var body = hit.collider as RigidBody3D
		if body == null:
			continue
		var away = body.global_position - _piece.global_position
		away.y = 0.0
		var dir = (away.normalized() + Vector3.UP * 0.3).normalized()
		body.apply_central_impulse(dir * explosion_impulse)
	_piece.queue_free()

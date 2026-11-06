extends RigidBody3D
class_name JengaPiece

@export_group("Drag")
## How quickly the pull reaches full speed (m/s²). Higher feels lighter; too high can kick the stack.
@export_range(1.0, 100.0, 0.5) var drag_acceleration = 20.0
## Top speed of the pulled piece (m/s).
@export_range(0.5, 20.0, 0.1) var max_drag_speed = 6.0
## How far a piece can be pulled from where the drag started (m).
@export_range(0.5, 10.0, 0.1) var max_drag_distance = 3.0
## Friction of the pulled piece. Lower slides out more easily and disturbs neighbours less.
@export_range(0.0, 1.0, 0.01) var drag_friction = 0.1
@export_group("")
@export_group("Sound")
## Required: where drop sounds are requested.
@export var sfx_channel: SfxChannel
## Optional: played at the piece when it hits the ground or another piece. Empty is silent.
@export var drop_sound: AudioStream
## Minimum impact speed relative to the other body (m/s).
@export_range(0.0, 20.0, 0.1) var drop_min_speed: float = 1.5
## Minimum time between two drop sounds from this piece (s).
@export_range(0.0, 2.0, 0.01) var drop_sound_interval: float = 0.15
@export_group("")
@onready var _cooldown := $Cooldown as PieceCooldown

# Blocking probe: slightly wider than the block so it stops just short of a neighbour (no shove),
# and thinner so blocks resting above/below never stop the slide.
const PROBE_PADDING = Vector3(0.01, -0.06, 0.01)

const AXIS_PICK_PIXELS = 4.0
const REBASE_MOUSE_STILL_PIXELS = 1.0
const REBASE_DISTANCE_THRESHOLD = 0.2
# Swept blocking check: sub-step length (shorter than a block's width) and contact search precision.
const MAX_STEP = 0.1
const SEARCH_ITERATIONS = 8

var _dragging = false
var _rest_material: PhysicsMaterial
var _drag_material: PhysicsMaterial
var _drag_axis = Vector3.ZERO
var _drag_start = Vector3.ZERO
var _drag_mouse = Vector2.ZERO
var _last_mouse = Vector2.ZERO
var _drag_t0 = 0.0
var _drag_distance = 0.0
var _axes: Array[Vector3] = []
var _query: PhysicsShapeQueryParameters3D
var _start_height: float = 0.0
var _was_dragged: bool = false
var _last_drop_msec: int = -1

func _ready() -> void:
	_start_height = global_position.y
	if sfx_channel == null:
		push_error("JengaPiece requires an sfx_channel for drop sounds.")
		return
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if drop_sound == null:
		return
	var other_velocity := Vector3.ZERO
	if body is JengaPiece:
		other_velocity = (body as JengaPiece).linear_velocity
	elif not (body is StaticBody3D):
		return
	if (linear_velocity - other_velocity).length() < drop_min_speed:
		return
	var now := Time.get_ticks_msec()
	if _last_drop_msec >= 0 and now - _last_drop_msec < int(drop_sound_interval * 1000.0):
		return
	_last_drop_msec = now
	sfx_channel.play_at(drop_sound, global_position)

## True when this piece was never pulled and has dropped more than `drop` below where it spawned.
func has_fallen(drop: float) -> bool:
	return not _was_dragged and global_position.y < _start_height - drop

func has_cooldown() -> bool:
	return _cooldown.has_cooldown()

func start_cooldown(seconds: float) -> void:
	_cooldown.start_cooldown(seconds)

func defuse() -> void:
	_cooldown.defuse()

func begin_drag(_camera: Camera3D, mouse: Vector2) -> void:
	var shape = $CollisionShape3D.shape as BoxShape3D
	if shape == null:
		push_error("JengaPiece requires a BoxShape3D on CollisionShape3D.")
		return
	_was_dragged = true
	var length = _flat(global_basis.x)
	var width = _flat(global_basis.z)
	_axes = [length, -length, width, -width]
	var probe = BoxShape3D.new()
	probe.size = shape.size + PROBE_PADDING
	_query = PhysicsShapeQueryParameters3D.new()
	_query.shape = probe
	_query.collision_mask = collision_mask
	_query.exclude = [get_rid()]
	_dragging = true
	_drag_axis = Vector3.ZERO
	_drag_start = global_position
	_drag_mouse = mouse
	_last_mouse = mouse
	_drag_distance = 0.0
	_rest_material = physics_material_override
	if _drag_material == null:
		_drag_material = PhysicsMaterial.new()
	_drag_material.friction = drag_friction
	physics_material_override = _drag_material

func drag_to(camera: Camera3D, mouse: Vector2, delta: float) -> void:
	if not _dragging:
		return
	if _drag_axis == Vector3.ZERO:
		var screen_delta = mouse - _drag_mouse
		if screen_delta.length() < AXIS_PICK_PIXELS:
			return
		_drag_axis = _best_axis(camera, screen_delta)
		_drag_t0 = _line_param(camera, _drag_mouse, 0.0)
		_drag_distance = clampf((global_position - _drag_start).dot(_drag_axis), 0.0, max_drag_distance)
	var t = _line_param(camera, mouse, _drag_t0 + _drag_distance)
	var target_distance = clampf(t - _drag_t0, 0.0, max_drag_distance)
	# If camera motion changed the ray while the mouse stayed nearly still, shift the baseline
	# to preserve the current drag distance and avoid sudden jumps.
	if (mouse - _last_mouse).length() <= REBASE_MOUSE_STILL_PIXELS and absf(target_distance - _drag_distance) > REBASE_DISTANCE_THRESHOLD:
		_drag_t0 = t - _drag_distance
		target_distance = _drag_distance
	_last_mouse = mouse
	var allowed = _limit_until_blocked(_drag_start + _drag_axis * target_distance)
	_drag_distance = clampf((allowed - _drag_start).dot(_drag_axis), 0.0, max_drag_distance)
	_apply_drag_velocity(delta)

func stop_drag() -> void:
	if _dragging:
		physics_material_override = _rest_material
	_dragging = false
	_drag_axis = Vector3.ZERO
	_query = null

func _apply_drag_velocity(delta: float) -> void:
	if _drag_axis == Vector3.ZERO or delta <= 0.0:
		return
	var along = (global_position - _drag_start).dot(_drag_axis)
	var error = _drag_distance - along
	var along_velocity = linear_velocity.dot(_drag_axis)
	var target_velocity = clampf(error * max_drag_speed, -max_drag_speed, max_drag_speed)
	var next_along = move_toward(along_velocity, target_velocity, drag_acceleration * delta)
	linear_velocity += _drag_axis * (next_along - along_velocity)

func _limit_until_blocked(target: Vector3) -> Vector3:
	var motion = target - global_position
	var steps = ceili(motion.length() / MAX_STEP)
	if steps == 0:
		return global_position
	var dir = motion.normalized()
	var pos = global_position
	for i in range(steps):
		var next = pos + motion / steps
		if _blocked(next, dir):
			var lo = 0.0
			var hi = 1.0
			for j in range(SEARCH_ITERATIONS):
				var mid = (lo + hi) * 0.5
				if _blocked(pos.lerp(next, mid), dir): hi = mid
				else: lo = mid
			pos = pos.lerp(next, lo)
			break
		pos = next
	return pos

# Only bodies ahead of the movement block it, so a block wedged against a neighbour can still move away.
func _blocked(pos: Vector3, dir: Vector3) -> bool:
	if _query == null:
		return false
	_query.transform = Transform3D(global_basis, pos)
	for hit in get_world_3d().direct_space_state.intersect_shape(_query, 8):
		var body = hit.collider as Node3D
		if body != null and (body.global_position - pos).dot(dir) > 0.0:
			return true
	return false

# Picks the axis whose on-screen direction best matches the mouse movement.
func _best_axis(camera: Camera3D, screen_delta: Vector2) -> Vector3:
	var origin = camera.unproject_position(_drag_start)
	var best = _axes[0]
	var best_score = -INF
	for axis in _axes:
		var screen_axis = camera.unproject_position(_drag_start + axis) - origin
		var score = screen_delta.normalized().dot(screen_axis.normalized())
		if score > best_score:
			best_score = score
			best = axis
	return best

# Position along the drag line closest to the mouse ray; keeps the fallback when the line faces the camera.
func _line_param(camera: Camera3D, mouse: Vector2, fallback: float) -> float:
	var ro = camera.project_ray_origin(mouse)
	var rd = camera.project_ray_normal(mouse)
	var b = _drag_axis.dot(rd)
	var denom = 1.0 - b * b
	if denom < 0.0001:
		return fallback
	var w = _drag_start - ro
	return (b * rd.dot(w) - _drag_axis.dot(w)) / denom

func _flat(v: Vector3) -> Vector3:
	var p = Vector3(v.x, 0.0, v.z)
	return Vector3.RIGHT if p.length() < 0.001 else p.normalized()

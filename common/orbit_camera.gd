extends Camera3D

# The camera orbits the tower; rotating the tower node would teleport its rigid bodies.

## Lets the player orbit with the tower_rotate_left / tower_rotate_right actions.
@export var player_controlled: bool = true
## Constant orbit speed in radians per second. 0 disables auto-spin.
@export_range(-2.0, 2.0, 0.01) var auto_spin_speed: float = 0.0
## Point the camera looks at.
@export var focus: Vector3 = Vector3(0.0, 2.5, 0.0)
## Camera position relative to the orbit centre at yaw 0.
@export var offset: Vector3 = Vector3(4.0, 5.0, 7.0)
## Yaw change per key press (radians).
@export_range(0.05, PI, 0.01) var step: float = PI / 4.0
## How quickly the camera catches up with the target yaw.
@export_range(0.5, 20.0, 0.1) var smoothing: float = 4.0

var _yaw: float = 0.0
var _target: float = 0.0

func _ready() -> void:
	_place()

func _process(delta: float) -> void:
	_target += auto_spin_speed * delta
	_yaw = lerpf(_yaw, _target, 1.0 - exp(-smoothing * delta))
	_place()

func _unhandled_input(event: InputEvent) -> void:
	if not player_controlled:
		return
	if event.is_action_pressed(&"tower_rotate_left", false):
		_target -= step
	elif event.is_action_pressed(&"tower_rotate_right", false):
		_target += step

func _place() -> void:
	position = offset.rotated(Vector3.UP, _yaw)
	look_at(focus, Vector3.UP)

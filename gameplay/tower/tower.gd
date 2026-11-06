extends Node3D
class_name JengaTower

@export var piece_scene: PackedScene = preload("res://gameplay/tower/piece/piece.tscn")
@export_range(1, 30, 1) var layers = 18
@export_range(1, 6, 1) var pieces_per_layer = 3
@export_range(0.1, 2.0, 0.01) var piece_width = 0.5
@export_range(0.1, 1.0, 0.01) var piece_height = 0.3
@export_range(0.0, 0.1, 0.001) var piece_gap = 0.015
@export_range(10.0, 500.0, 1.0) var pick_ray_length = 100.0

@export_group("Round End")
## Raised once when the tower collapses. Leave empty to disable collapse detection (menu tower).
@export var collapsed_channel: TowerCollapsedChannel
## How far a never-dragged piece must drop below its start height to count as a collapse (m).
@export_range(0.05, 2.0, 0.05) var collapse_drop: float = 0.3
@export_group("")

@export_group("Interaction")
## Topmost layers that cannot be picked.
@export_range(0, 30, 1) var locked_top_layers: int = 0
@export_group("")

var _pieces: Array[JengaPiece] = []
var _pieces_by_layer: Array[Array] = []
var _piece_layer: Dictionary = {}
var _dragging: JengaPiece
var _mouse = Vector2.ZERO
var _round_ended = false

func _ready() -> void:
	if piece_scene == null:
		push_error("Tower requires a piece scene.")
		return
	_pieces_by_layer.clear()
	_pieces.clear()
	_piece_layer.clear()
	for layer in range(layers):
		var layer_pieces: Array = []
		for i in range(pieces_per_layer):
			var p = piece_scene.instantiate() as JengaPiece
			if p == null:
				push_error("Piece scene must instantiate a JengaPiece.")
				return
			# Positioned before add_child so the piece records its start height in _ready.
			p.name = "Block_%02d_%02d" % [layer, i]
			p.position = _pos(layer, i, layer % 2 == 0); p.rotation.y = 0.0 if layer % 2 == 0 else PI / 2.0
			add_child(p)
			_pieces.append(p)
			layer_pieces.append(p)
			_piece_layer[p.get_instance_id()] = layer
			p.tree_exiting.connect(_pieces.erase.bind(p))
		_pieces_by_layer.append(layer_pieces)

func _physics_process(delta: float) -> void:
	if _live(_dragging):
		var cam = get_viewport().get_camera_3d()
		if cam != null:
			_dragging.drag_to(cam, _mouse, delta)
	if not _round_ended and collapsed_channel != null and _any_fallen():
		_round_ended = true
		# The round-end popup swallows the mouse release, so end any drag here.
		_end_drag()
		collapsed_channel.raise()

func _any_fallen() -> bool:
	for p in _pieces:
		if p.has_fallen(collapse_drop):
			return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if _round_ended:
		return
	if event is InputEventMouseMotion: _mouse = event.position; return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse = event.position
		if event.pressed:
			_on_press(event.position)
		else:
			_end_drag()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_end_drag()

func _exit_tree() -> void:
	_end_drag()

func _on_press(mouse: Vector2) -> void:
	_end_drag()
	var cam = get_viewport().get_camera_3d()
	if cam == null: return
	var piece = _pick_piece(cam, mouse)
	if piece == null: return
	_dragging = piece
	_dragging.begin_drag(cam, mouse)

func _end_drag() -> void:
	if _live(_dragging):
		_dragging.stop_drag()
	_dragging = null

func _pick_piece(cam: Camera3D, mouse: Vector2) -> JengaPiece:
	var o = cam.project_ray_origin(mouse); var q = PhysicsRayQueryParameters3D.create(o, o + cam.project_ray_normal(mouse) * pick_ray_length)
	q.collision_mask = 1; q.collide_with_bodies = true; q.collide_with_areas = false
	var piece = get_world_3d().direct_space_state.intersect_ray(q).get("collider", null) as JengaPiece
	if piece == null:
		return null
	return null if _is_locked_piece(piece) else piece

func _is_locked_piece(piece: JengaPiece) -> bool:
	var locked = clampi(locked_top_layers, 0, layers)
	if locked == 0:
		return false
	var layer = int(_piece_layer.get(piece.get_instance_id(), -1))
	return layer >= layers - locked

func get_layer_count() -> int:
	return _pieces_by_layer.size()

func get_pieces_in_layer(layer: int) -> Array[JengaPiece]:
	if layer < 0 or layer >= _pieces_by_layer.size():
		return []
	var result: Array[JengaPiece] = []
	for piece in _pieces_by_layer[layer]:
		var p = piece as JengaPiece
		if p != null and _live(p):
			result.append(p)
	return result

## Returns the live piece whose node name is `id` (Block_<layer>_<index>), or null.
func get_piece(id: StringName) -> JengaPiece:
	var piece = get_node_or_null(NodePath(String(id))) as JengaPiece
	return piece if _live(piece) else null

func end_round() -> void:
	if _round_ended:
		return
	_round_ended = true
	_end_drag()

func _pos(layer: int, i: int, horizontal: bool) -> Vector3:
	# Layers rest directly on each other so the stack starts settled instead of dropping.
	var y = layer * piece_height + piece_height / 2.0
	var off = (i - (pieces_per_layer - 1) * 0.5) * (piece_width + piece_gap)
	return Vector3(0.0, y, off) if horizontal else Vector3(off, y, 0.0)

# Untyped on purpose: a dragged piece can explode, and typed parameters reject freed instances.
func _live(piece) -> bool:
	return is_instance_valid(piece) and not piece.is_queued_for_deletion()

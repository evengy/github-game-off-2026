extends Node3D

@export_group("Level Rules")
@export var easy_rules: RandomTowerLevelRules
@export var medium_rules: RandomTowerLevelRules
@export var hard_rules: RandomTowerLevelRules
@export var competitive_rules: CompetitiveTowerLevelRules
## A piece this far from the tower's centre line counts as removed and is defused (m).
@export_range(0.1, 10.0, 0.1) var removal_distance: float = 1.5
@export_group("")

@export_group("Round End")
@export var collapsed_channel: TowerCollapsedChannel
@export var defused_channel: TowerDefusedChannel
@export_group("")

@onready var _tower := $Tower as JengaTower

var _round_ended = false
var _cooldown_target_count: int = 0
var _cooldowns_defused: int = 0
var _cooldown_pieces: Array[JengaPiece] = []

func _ready() -> void:
	if _tower == null:
		push_error("World requires a JengaTower child named 'Tower'.")
		return
	var complexity := GameSettings.load_complexity()
	var rules := _rules_for(complexity)
	if rules == null:
		push_error("World has no level rules assigned for complexity %s." % GameSettings.Complexity.keys()[complexity])
		return
	_apply_level_rules(rules)

func _enter_tree() -> void:
	if collapsed_channel != null:
		collapsed_channel.collapsed.connect(_on_collapsed)

func _exit_tree() -> void:
	if collapsed_channel != null and collapsed_channel.collapsed.is_connected(_on_collapsed):
		collapsed_channel.collapsed.disconnect(_on_collapsed)

func _physics_process(_delta: float) -> void:
	if _round_ended:
		return
	_defuse_removed()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart_round", false):
		get_tree().reload_current_scene()

func _on_collapsed() -> void:
	_round_ended = true
	if _tower != null:
		_tower.end_round()

func _rules_for(complexity: GameSettings.Complexity) -> TowerLevelRules:
	match complexity:
		GameSettings.Complexity.EASY:
			return easy_rules
		GameSettings.Complexity.MEDIUM:
			return medium_rules
		GameSettings.Complexity.HARD:
			return hard_rules
		GameSettings.Complexity.COMPETITIVE:
			return competitive_rules
	return null

func _apply_level_rules(rules: TowerLevelRules) -> void:
	_cooldown_target_count = 0
	_cooldowns_defused = 0
	_cooldown_pieces.clear()
	var locked = clampi(rules.locked_top_layers, 0, _tower.layers)
	_tower.locked_top_layers = locked
	if rules is RandomTowerLevelRules:
		_apply_random_cooldowns(rules as RandomTowerLevelRules, locked)
	elif rules is CompetitiveTowerLevelRules:
		_apply_competitive_cooldowns(rules as CompetitiveTowerLevelRules)

func _apply_competitive_cooldowns(rules: CompetitiveTowerLevelRules) -> void:
	var setup := rules.get_cooldown_setup()
	for id in setup:
		var seconds: float = setup[id]
		var piece := _tower.get_piece(id)
		if piece == null:
			push_error("Competitive rules reference unknown piece '%s'." % id)
			continue
		if seconds <= 0.0:
			push_error("Competitive rules give piece '%s' a non-positive cooldown (%s s)." % [id, seconds])
			continue
		_assign_cooldown(piece, seconds)
	if _cooldown_target_count == 0:
		push_error("Competitive rules assigned no cooldown pieces, so the round can't be won.")

func _apply_random_cooldowns(rules: RandomTowerLevelRules, locked: int) -> void:
	var requested = maxi(rules.cooldown_piece_count, 0)
	if requested == 0:
		return
	var playable_layers = _tower.get_layer_count() - locked
	if playable_layers <= 0:
		push_error("Tower level rules lock all layers, so no cooldown pieces can be assigned.")
		return
	var layer_caps: Array[int] = []
	var max_total = 0
	for layer in range(playable_layers):
		var cap = _max_non_adjacent_slots(_tower.get_pieces_in_layer(layer).size())
		layer_caps.append(cap)
		max_total += cap
	if requested > max_total:
		push_error("Tower level rules request %d cooldown pieces, but max possible with no-adjacent rule is %d." % [requested, max_total])
		return
	var counts_by_layer: Array[int] = []
	for _i in range(playable_layers):
		counts_by_layer.append(0)
	var remaining = requested
	while remaining > 0:
		var candidate_layers: Array[int] = []
		for layer in range(playable_layers):
			if counts_by_layer[layer] < layer_caps[layer]:
				candidate_layers.append(layer)
		if candidate_layers.is_empty():
			push_error("Cooldown assignment ran out of valid layers before reaching the requested count.")
			return
		var chosen_layer = candidate_layers[randi() % candidate_layers.size()]
		counts_by_layer[chosen_layer] += 1
		remaining -= 1
	var min_seconds = minf(rules.cooldown_min_seconds, rules.cooldown_max_seconds)
	var max_seconds = maxf(rules.cooldown_min_seconds, rules.cooldown_max_seconds)
	for layer in range(playable_layers):
		var target = counts_by_layer[layer]
		if target == 0:
			continue
		var layer_pieces = _tower.get_pieces_in_layer(layer)
		var indices = _choose_non_adjacent_indices(layer_pieces.size(), target)
		if indices.is_empty():
			push_error("Failed to choose %d non-adjacent slots for layer %d." % [target, layer])
			return
		for index in indices:
			_assign_cooldown(layer_pieces[index], randf_range(min_seconds, max_seconds))

func _assign_cooldown(piece: JengaPiece, seconds: float) -> void:
	piece.start_cooldown(seconds)
	_cooldown_pieces.append(piece)
	_cooldown_target_count += 1

func _defuse_removed() -> void:
	for piece in _cooldown_pieces:
		if not _live_piece(piece):
			continue
		if not piece.has_cooldown():
			continue
		var offset = piece.global_position - _tower.global_position
		if Vector2(offset.x, offset.z).length() <= removal_distance:
			continue
		piece.defuse()
		_cooldowns_defused += 1
	if _cooldown_target_count <= 0 or _cooldowns_defused < _cooldown_target_count:
		return
	_round_ended = true
	_tower.end_round()
	if defused_channel != null:
		defused_channel.raise()

func _max_non_adjacent_slots(slot_count: int) -> int:
	return int(ceili(slot_count * 0.5))

func _choose_non_adjacent_indices(slot_count: int, target_count: int) -> Array[int]:
	if target_count <= 0:
		return []
	var solutions: Array[Array] = []
	_collect_non_adjacent_indices(slot_count, target_count, 0, [], solutions)
	if solutions.is_empty():
		return []
	var picked = solutions[randi() % solutions.size()]
	var result: Array[int] = []
	for index in picked:
		result.append(int(index))
	return result

func _collect_non_adjacent_indices(slot_count: int, target_count: int, start: int, current: Array[int], solutions: Array[Array]) -> void:
	if current.size() == target_count:
		solutions.append(current.duplicate())
		return
	for i in range(start, slot_count):
		if not current.is_empty() and i - current[current.size() - 1] == 1:
			continue
		current.append(i)
		_collect_non_adjacent_indices(slot_count, target_count, i + 1, current, solutions)
		current.pop_back()

func _live_piece(piece) -> bool:
	return is_instance_valid(piece) and not piece.is_queued_for_deletion()

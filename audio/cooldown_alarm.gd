class_name CooldownAlarm
extends AudioStreamPlayer

## Plays the (looping) stream while any piece still in the tower has this many seconds or fewer left.
@export_range(0.0, 120.0, 0.5) var alarm_threshold: float = 10.0
## Fade-out time when the round ends (s).
@export_range(0.0, 5.0, 0.05) var fade_out_seconds: float = 1.0
@export var collapsed_channel: TowerCollapsedChannel
@export var defused_channel: TowerDefusedChannel

var _round_ended: bool = false

func _enter_tree() -> void:
	if collapsed_channel == null or defused_channel == null:
		push_error("CooldownAlarm requires collapsed and defused channels.")
		return
	collapsed_channel.collapsed.connect(_on_round_ended)
	defused_channel.defused.connect(_on_round_ended)

func _exit_tree() -> void:
	if collapsed_channel != null and collapsed_channel.collapsed.is_connected(_on_round_ended):
		collapsed_channel.collapsed.disconnect(_on_round_ended)
	if defused_channel != null and defused_channel.defused.is_connected(_on_round_ended):
		defused_channel.defused.disconnect(_on_round_ended)

func _ready() -> void:
	# An empty stream is a valid "no alarm" setup.
	set_process(stream != null)

func _process(_delta: float) -> void:
	var in_range := _any_piece_in_range()
	if in_range and not playing:
		play()
	elif not in_range and playing:
		stop()

func _any_piece_in_range() -> bool:
	for node in get_tree().get_nodes_in_group(PieceCooldown.ACTIVE_GROUP):
		var cooldown := node as PieceCooldown
		if cooldown.is_queued_for_deletion():
			continue
		if cooldown.get_time_left() <= alarm_threshold:
			return true
	return false

func _on_round_ended() -> void:
	if _round_ended:
		return
	_round_ended = true
	# Disable processing first so _process can't restart the alarm during the fade.
	set_process(false)
	if not playing:
		return
	var tween := create_tween()
	tween.tween_property(self, "volume_linear", 0.0, fade_out_seconds)
	tween.tween_callback(stop)

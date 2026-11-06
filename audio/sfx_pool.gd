class_name SfxPool
extends Node

## Random pitch offset (±) per play so repeated sounds don't sound identical.
@export_range(0.0, 0.5, 0.01) var pitch_variation: float = 0.05

var _players: Array[AudioStreamPlayer3D] = []

func _ready() -> void:
	for child in get_children():
		if child is AudioStreamPlayer3D:
			_players.append(child)
	if _players.is_empty():
		push_error("SfxPool has no AudioStreamPlayer3D children.")

## Plays `stream` at `position` on a free player. Skipped when the stream is empty or every player is busy.
func play_at(stream: AudioStream, position: Vector3) -> void:
	if stream == null:
		return
	for player in _players:
		if player.playing:
			continue
		player.global_position = position
		player.stream = stream
		player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
		player.play()
		return

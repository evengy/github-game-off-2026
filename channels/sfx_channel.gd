class_name SfxChannel
extends Resource

## Requests a one-shot positional sound at a world position.
signal sfx_requested(stream: AudioStream, position: Vector3)

func play_at(stream: AudioStream, position: Vector3) -> void:
	sfx_requested.emit(stream, position)

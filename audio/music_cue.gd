extends Node

## Requests menu or game music when its scene loads.
enum Context { MENU, GAME }

@export var channel: MusicChannel
@export var context: Context = Context.MENU

func _ready() -> void:
	if channel == null:
		push_error("MusicCue requires a music channel.")
		return
	match context:
		Context.MENU:
			channel.request_menu()
		Context.GAME:
			channel.request_game(GameSettings.load_complexity())

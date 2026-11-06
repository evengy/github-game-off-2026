class_name MusicChannel
extends Resource

signal menu_music_requested
signal game_music_requested(complexity: GameSettings.Complexity)

func request_menu() -> void:
	menu_music_requested.emit()

func request_game(complexity: GameSettings.Complexity) -> void:
	game_music_requested.emit(complexity)

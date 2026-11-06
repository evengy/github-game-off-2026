# Autoload "SoundManager". No class_name: it would clash with the autoload name.
extends Node

@export_group("Channels")
@export var music_channel: MusicChannel
@export var sfx_channel: SfxChannel
@export var collapsed_channel: TowerCollapsedChannel
@export var defused_channel: TowerDefusedChannel
@export_group("")

@export_group("Music")
## Every slot is optional. An empty menu/complexity slot fades the music to silence.
@export var menu_loop: AudioStream
@export var easy_loop: AudioStream
@export var medium_loop: AudioStream
@export var hard_loop: AudioStream
@export var competitive_loop: AudioStream
## Played when a round is won. Empty keeps the game loop playing.
@export var win_music: AudioStream
## Played when the tower collapses. Empty keeps the game loop playing.
@export var lose_music: AudioStream
@export_range(0.0, 5.0, 0.05) var crossfade_seconds: float = 1.0
@export_group("")

@export_group("Volume")
## Buses whose saved volume is applied at startup.
@export var volume_buses: Array[StringName] = [&"Master", &"Music", &"SFX"]
@export_group("")

@onready var _music_a := $MusicA as AudioStreamPlayer
@onready var _music_b := $MusicB as AudioStreamPlayer
@onready var _sfx_pool := $SfxPool as SfxPool

var _active: AudioStreamPlayer
var _fade: Tween

func _enter_tree() -> void:
	if music_channel == null or sfx_channel == null or collapsed_channel == null or defused_channel == null:
		push_error("SoundManager requires music, sfx, collapsed, and defused channels.")
		return
	music_channel.menu_music_requested.connect(_on_menu_music_requested)
	music_channel.game_music_requested.connect(_on_game_music_requested)
	sfx_channel.sfx_requested.connect(_on_sfx_requested)
	collapsed_channel.collapsed.connect(_on_collapsed)
	defused_channel.defused.connect(_on_defused)

func _exit_tree() -> void:
	if music_channel != null and music_channel.menu_music_requested.is_connected(_on_menu_music_requested):
		music_channel.menu_music_requested.disconnect(_on_menu_music_requested)
	if music_channel != null and music_channel.game_music_requested.is_connected(_on_game_music_requested):
		music_channel.game_music_requested.disconnect(_on_game_music_requested)
	if sfx_channel != null and sfx_channel.sfx_requested.is_connected(_on_sfx_requested):
		sfx_channel.sfx_requested.disconnect(_on_sfx_requested)
	if collapsed_channel != null and collapsed_channel.collapsed.is_connected(_on_collapsed):
		collapsed_channel.collapsed.disconnect(_on_collapsed)
	if defused_channel != null and defused_channel.defused.is_connected(_on_defused):
		defused_channel.defused.disconnect(_on_defused)

func _ready() -> void:
	_active = _music_a
	for bus in volume_buses:
		var index := AudioServer.get_bus_index(bus)
		if index < 0:
			push_error("SoundManager references unknown audio bus '%s'." % bus)
			continue
		AudioServer.set_bus_volume_linear(index, GameSettings.load_volume(bus))

func _on_menu_music_requested() -> void:
	_play_music(menu_loop)

func _on_game_music_requested(complexity: GameSettings.Complexity) -> void:
	_play_music(_loop_for(complexity))

func _on_collapsed() -> void:
	if lose_music != null:
		_play_music(lose_music)

func _on_defused() -> void:
	if win_music != null:
		_play_music(win_music)

func _on_sfx_requested(stream: AudioStream, position: Vector3) -> void:
	_sfx_pool.play_at(stream, position)

func _loop_for(complexity: GameSettings.Complexity) -> AudioStream:
	match complexity:
		GameSettings.Complexity.EASY:
			return easy_loop
		GameSettings.Complexity.MEDIUM:
			return medium_loop
		GameSettings.Complexity.HARD:
			return hard_loop
		GameSettings.Complexity.COMPETITIVE:
			return competitive_loop
	return null

# Crossfades from the active player to `stream` on the other player; null fades to silence.
func _play_music(stream: AudioStream) -> void:
	if stream == _active.stream and (stream == null or _active.playing):
		return
	if _fade != null:
		_fade.kill()
	var old := _active
	var next := _music_b if old == _music_a else _music_a
	# `next` may still be fading out from an interrupted crossfade.
	next.stop()
	next.stream = stream
	_active = next
	_fade = create_tween().set_parallel()
	if stream != null:
		next.volume_linear = 0.0
		next.play()
		_fade.tween_property(next, "volume_linear", 1.0, crossfade_seconds)
	_fade.tween_property(old, "volume_linear", 0.0, crossfade_seconds)
	_fade.chain().tween_callback(old.stop)

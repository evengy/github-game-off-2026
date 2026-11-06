extends Label

## Shown and running only on Competitive complexity; counts from round load until the round ends.
@export var collapsed_channel: TowerCollapsedChannel
@export var defused_channel: TowerDefusedChannel
## Receives the final time when the round is won.
@export var time_channel: CompetitiveTimeChannel

var _elapsed: float = 0.0
var _stopped: bool = false

func _enter_tree() -> void:
	if collapsed_channel != null:
		collapsed_channel.collapsed.connect(_on_collapsed)
	if defused_channel != null:
		defused_channel.defused.connect(_on_defused)

func _exit_tree() -> void:
	if collapsed_channel != null and collapsed_channel.collapsed.is_connected(_on_collapsed):
		collapsed_channel.collapsed.disconnect(_on_collapsed)
	if defused_channel != null and defused_channel.defused.is_connected(_on_defused):
		defused_channel.defused.disconnect(_on_defused)

func _ready() -> void:
	var competitive := GameSettings.load_complexity() == GameSettings.Complexity.COMPETITIVE
	visible = competitive
	_stopped = not competitive
	set_process(competitive)
	if competitive and time_channel == null:
		push_error("RoundTimer requires a time_channel on Competitive.")
	text = CompetitiveTimeChannel.format_seconds(_elapsed)

func _process(delta: float) -> void:
	_elapsed += delta
	text = CompetitiveTimeChannel.format_seconds(_elapsed)

func _on_collapsed() -> void:
	_stop()

func _on_defused() -> void:
	if _stop() and time_channel != null:
		time_channel.raise(_elapsed)

# Freezes the timer; returns false if it was already stopped or isn't running on this level.
func _stop() -> bool:
	if _stopped:
		return false
	_stopped = true
	set_process(false)
	return true

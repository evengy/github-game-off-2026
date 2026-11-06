class_name CompetitiveTimeChannel
extends Resource

## Raised once when a Competitive round is won, with the time it took (s).
signal time_recorded(seconds: float)

func raise(seconds: float) -> void:
	time_recorded.emit(seconds)

## Formats seconds as mm:ss.cc.
@warning_ignore("integer_division")
static func format_seconds(seconds: float) -> String:
	var total_centis := int(seconds * 100.0)
	var minutes := total_centis / 6000
	var secs := (total_centis / 100) % 60
	var centis := total_centis % 100
	return "%02d:%02d.%02d" % [minutes, secs, centis]

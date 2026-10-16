class_name SessionDurationEstimator
extends RefCounted

const RANGE_FACTOR: = 0.15
const MINUTES_STEP: = 5


static func estimate(mode: String, rounds: int, seats: int) -> Dictionary:
	var safe_rounds: = maxi(1, rounds)
	var safe_seats: = 1 if mode == "solo" else clampi(seats, 2, 8)
	var per_round: = 1.25
	match mode:
		"ai":
			per_round = 1.0 + 0.14 * float(safe_seats - 1)
		"multi":
			per_round = 0.7 + 0.55 * float(safe_seats)
	var center: = 5.0 + float(safe_rounds) * per_round
	var minimum: = _round_to_step(center * (1.0 - RANGE_FACTOR))
	var maximum: = _round_to_step(center * (1.0 + RANGE_FACTOR))
	maximum = maxi(minimum, maximum)
	return {
		"minimum": minimum, 
		"maximum": maximum, 
		"label": "预计 %d—%d 分钟" % [minimum, maximum], 
	}


static func _round_to_step(value: float) -> int:
	return maxi(MINUTES_STEP, roundi(value / float(MINUTES_STEP)) * MINUTES_STEP)

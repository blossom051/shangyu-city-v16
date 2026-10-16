class_name RandomSource
extends RefCounted


static func shuffle(values: Array) -> Array:
	var result: = values.duplicate(true)
	shuffle_in_place(result)
	return result


static func shuffle_in_place(values: Array) -> void :
	for index in range(values.size() - 1, 0, -1):
		var other: = GameState.rng.randi_range(0, index)
		var value: Variant = values[index]
		values[index] = values[other]
		values[other] = value

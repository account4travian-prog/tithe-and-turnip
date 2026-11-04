class_name TargetResolver
extends RefCounted

## Pure targeting helpers shared by Player and the headless characterization
## tests. This class deliberately knows nothing about FarmGrid, NPCs, or
## screen coordinates: it only orders logical grid offsets in front of a
## facing direction and advances a logical aim cell one step at a time.

const ANGLE_EPSILON: float = 0.000001


static func forward_offsets(facing: Vector2i, max_range: int, cone_degrees: float) -> Array[Vector2i]:
	var offsets: Array[Vector2i] = []
	if max_range < 1 or facing == Vector2i.ZERO:
		return offsets
	var facing_vector := Vector2(facing).normalized()
	var minimum_dot := cos(deg_to_rad(cone_degrees))
	for y: int in range(-max_range, max_range + 1):
		for x: int in range(-max_range, max_range + 1):
			var offset := Vector2i(x, y)
			if offset == Vector2i.ZERO:
				continue
			if maxi(absi(x), absi(y)) > max_range:
				continue
			var dot := facing_vector.dot(Vector2(offset).normalized())
			if dot + ANGLE_EPSILON < minimum_dot:
				continue
			offsets.append(offset)
	_sort_offsets(offsets, facing_vector)
	return offsets


static func aim_step(current: Vector2i, direction: Vector2i) -> Vector2i:
	if direction == Vector2i.ZERO:
		return current
	return current + direction


static func _sort_offsets(offsets: Array[Vector2i], facing_vector: Vector2) -> void:
	# The candidate list is tiny, so insertion sort keeps the comparator fully
	# typed and deterministic without relying on a Variant-backed lambda.
	for index: int in range(1, offsets.size()):
		var current := offsets[index]
		var insert_at := index
		while insert_at > 0 and _offset_precedes(current, offsets[insert_at - 1], facing_vector):
			offsets[insert_at] = offsets[insert_at - 1]
			insert_at -= 1
		offsets[insert_at] = current


static func _offset_precedes(a: Vector2i, b: Vector2i, facing_vector: Vector2) -> bool:
	var a_distance := a.x * a.x + a.y * a.y
	var b_distance := b.x * b.x + b.y * b.y
	if a_distance != b_distance:
		return a_distance < b_distance
	var a_angle := 1.0 - facing_vector.dot(Vector2(a).normalized())
	var b_angle := 1.0 - facing_vector.dot(Vector2(b).normalized())
	if not is_equal_approx(a_angle, b_angle):
		return a_angle < b_angle
	if a.x != b.x:
		return a.x < b.x
	return a.y < b.y

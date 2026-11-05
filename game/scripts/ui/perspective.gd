class_name Perspective
## The mapping that lays a flat floor into a four-sided shape on screen, the way a floor seen at an angle narrows
## toward the back, so a shader can find which point of the floor shows at each pixel.


## For a point (x, y, 1) inside the shape, the three rows give (u, v, w); u / w and v / w are where it falls on the
## floor, from 0 to 1. The corners are the floor's back left, back right, front right and front left, in that order.
static func to_floor(corners: Array) -> Array:
	var p0: Vector2 = corners[0]
	var p1: Vector2 = corners[1]
	var p2: Vector2 = corners[2]
	var p3: Vector2 = corners[3]
	var d1 := p1 - p2
	var d2 := p3 - p2
	var d3 := p0 - p1 + p2 - p3
	var den := d1.x * d2.y - d2.x * d1.y
	var g := (d3.x * d2.y - d2.x * d3.y) / den
	var h := (d1.x * d3.y - d3.x * d1.y) / den
	var m := [
		[p1.x - p0.x + g * p1.x, p3.x - p0.x + h * p3.x, p0.x],
		[p1.y - p0.y + g * p1.y, p3.y - p0.y + h * p3.y, p0.y],
		[g, h, 1.0],
	]
	return _inverse(m)


static func _inverse(m: Array) -> Array:
	var a: float = m[0][0]
	var b: float = m[0][1]
	var c: float = m[0][2]
	var d: float = m[1][0]
	var e: float = m[1][1]
	var f: float = m[1][2]
	var g: float = m[2][0]
	var h: float = m[2][1]
	var i: float = m[2][2]
	var det := a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)
	return [
		Vector3(e * i - f * h, c * h - b * i, b * f - c * e) / det,
		Vector3(f * g - d * i, a * i - c * g, c * d - a * f) / det,
		Vector3(d * h - e * g, b * g - a * h, a * e - b * d) / det,
	]


## Where a point on screen falls on the floor, for checking the mapping.
static func apply(rows: Array, at: Vector2) -> Vector2:
	var p := Vector3(at.x, at.y, 1.0)
	var w := (rows[2] as Vector3).dot(p)
	return Vector2((rows[0] as Vector3).dot(p), (rows[1] as Vector3).dot(p)) / w

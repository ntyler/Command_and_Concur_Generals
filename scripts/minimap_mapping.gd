class_name MinimapMapping
extends RefCounted
## Fixed orientation: world +X is right, world +Z is down. Content is letterboxed.

var bounds := Rect2()
var content_rect := Rect2()
var ground_y: float = 0.0
var valid: bool = false


func configure(world_bounds: Rect2, area: Rect2, height: float = 0.0) -> void:
	bounds = world_bounds
	ground_y = height
	valid = bounds.position.is_finite() and bounds.size.is_finite() and area.position.is_finite() and area.size.is_finite() and is_finite(height) and bounds.size.x > 0.0 and bounds.size.y > 0.0 and area.size.x > 0.0 and area.size.y > 0.0
	content_rect = Rect2()
	if not valid:
		return
	var scale_factor := minf(area.size.x / bounds.size.x, area.size.y / bounds.size.y)
	var extent := bounds.size * scale_factor
	content_rect = Rect2(area.position + (area.size - extent) / 2.0, extent)


func world_to_content(point: Vector3) -> Vector2:
	if not valid or not point.is_finite():
		return Vector2(INF, INF)
	return content_rect.position + (Vector2(point.x, point.z) - bounds.position) / bounds.size * content_rect.size


func content_to_world(point: Vector2) -> Variant:
	# Include mathematical map corners; panel borders/margins lie outside this rect.
	if not valid or not point.is_finite() or point.x < content_rect.position.x or point.y < content_rect.position.y or point.x > content_rect.end.x or point.y > content_rect.end.y:
		return null
	var ground := bounds.position + (point - content_rect.position) / content_rect.size * bounds.size
	return Vector3(ground.x, ground_y, ground.y)


func world_rectangle(rectangle: Rect2) -> Rect2:
	return Rect2(world_to_content(Vector3(rectangle.position.x, ground_y, rectangle.position.y)), rectangle.size / bounds.size * content_rect.size) if valid else Rect2()


func camera_footprint(camera: Camera3D, viewport_rect: Rect2) -> PackedVector2Array:
	var empty := PackedVector2Array()
	if not valid or not is_instance_valid(camera) or not viewport_rect.has_area():
		return empty
	var ground := Plane(Vector3.UP, ground_y)
	var polygon := PackedVector2Array()
	for point in [viewport_rect.position, Vector2(viewport_rect.end.x, viewport_rect.position.y), viewport_rect.end, Vector2(viewport_rect.position.x, viewport_rect.end.y)]:
		var hit: Variant = ground.intersects_ray(camera.project_ray_origin(point), camera.project_ray_normal(point))
		if hit == null or not (hit as Vector3).is_finite():
			return empty
		polygon.append(Vector2(hit.x, hit.z))
	var boundary := PackedVector2Array([bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)])
	var clipped := Geometry2D.intersect_polygons(polygon, boundary)
	if clipped.is_empty():
		return empty
	var result := PackedVector2Array()
	for point in clipped[0]:
		result.append(world_to_content(Vector3(point.x, ground_y, point.y)))
	return result

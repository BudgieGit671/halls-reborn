@tool

class_name LowPolyAsset2D
extends Resource

enum CollisionExportMode { Concave, Convex }

@export var width: int = 512;
@export var height: int = 512;

var size: Vector2:
	get:
		return Vector2(width, height);

@export
var points: PackedVector2Array;


@export var edges: Array[LowPolyAsset2DEdge];
@export var polygons: Array[LowPolyAsset2DPolygon];

@export_group("SVG Export")
@export_custom(PropertyHint.PROPERTY_HINT_SAVE_FILE, "*.svg") var svg_export_path: String = "";
@export_tool_button("Export SVG", "Save") var export_svg_action: Callable = export_svg_to_configured_path;

@export_group("Collision Export")
@export_custom(PropertyHint.PROPERTY_HINT_SAVE_FILE, "*.tscn") var collision_export_path: String = "";
@export_enum("Concave", "Convex") var collision_export_mode: int = CollisionExportMode.Concave;
@export_tool_button("Export Collision", "CollisionPolygon2D") var export_collision_action: Callable = export_collision_to_configured_path;


func try_append_edge(a: int, b: int) -> bool:
	var new_edge := LowPolyAsset2DEdge.new();
	new_edge.a = a;
	new_edge.b = b;
	
	for edge in edges:
		if edge.equals(new_edge):
			return false;
	
	edges.append(new_edge);
	return true;


func try_append_polygon(points: Array[int], color: Color) -> bool:
	var new_polygon := LowPolyAsset2DPolygon.new();
	new_polygon.points = points.duplicate();
	new_polygon.color = color;
	
	for polygon in polygons:
		if polygon.equals(new_polygon):
			return false;
	
	polygons.append(new_polygon);
	return true;


func export_svg(path: String) -> Error:
	var svg := PackedStringArray([
		"<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
		"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\">" % [width, height, width, height],
	]);

	for polygon in polygons:
		var polygon_points := PackedStringArray();
		for point_index in polygon.points:
			var point := points[point_index];
			polygon_points.append("%f,%f" % [point.x, point.y]);
		var opacity := "%.6f" % polygon.color.a;
		svg.append("<polygon points=\"%s\" fill=\"#%s\" fill-opacity=\"%s\"/>" % [" ".join(polygon_points), polygon.color.to_html(false), opacity]);

	svg.append("</svg>");
	var file := FileAccess.open(path, FileAccess.WRITE);
	if file == null:
		return FileAccess.get_open_error();
	file.store_string("\n".join(svg));
	file.close();
	notify_editor_file_saved(path);
	return OK;


func export_svg_to_configured_path() -> void:
	if svg_export_path.is_empty():
		push_error("Set an SVG export path before exporting.");
		return;
	var error := export_svg(svg_export_path);
	if error != OK:
		push_error("Unable to export SVG: %s" % error_string(error));


func export_collision_scene(path: String) -> Error:
	var collision_polygons := get_collision_polygons();
	if collision_polygons.size() != 1:
		return ERR_INVALID_DATA;

	var collision_polygon := CollisionPolygon2D.new();
	collision_polygon.name = "LowPolyCollision";
	collision_polygon.polygon = collision_polygons[0];

	var scene := PackedScene.new();
	var error := scene.pack(collision_polygon);
	collision_polygon.free();
	if error != OK:
		return error;
	error = ResourceSaver.save(scene, path);
	if error == OK:
		notify_editor_file_saved(path);
	return error;


func export_collision_to_configured_path() -> void:
	if collision_export_path.is_empty():
		push_error("Set a collision export path before exporting.");
		return;
	var error := export_collision_scene(collision_export_path);
	if error != OK:
		push_error("Unable to export collision scene: %s" % error_string(error));


func get_collision_polygons() -> Array[PackedVector2Array]:
	if collision_export_mode == CollisionExportMode.Convex:
		return get_convex_collision_polygons();
	return get_concave_collision_polygons();


func get_concave_collision_polygons() -> Array[PackedVector2Array]:
	var merged_polygons: Array[PackedVector2Array];
	for asset_polygon in polygons:
		var pending_polygon := get_asset_polygon_points(asset_polygon);
		if pending_polygon.size() < 3:
			continue;

		var merged := true;
		while merged:
			merged = false;
			for polygon_index in range(merged_polygons.size()):
				var merge_result := Geometry2D.merge_polygons(merged_polygons[polygon_index], pending_polygon);
				if merge_result.size() == 1:
					pending_polygon = merge_result[0];
					merged_polygons.remove_at(polygon_index);
					merged = true;
					break;

		merged_polygons.append(pending_polygon);
	return merged_polygons;


func get_convex_collision_polygons() -> Array[PackedVector2Array]:
	var polygon_points := PackedVector2Array();
	for asset_polygon in polygons:
		polygon_points.append_array(get_asset_polygon_points(asset_polygon));

	var hull := Geometry2D.convex_hull(polygon_points);
	if hull.size() > 1 and hull[0] == hull[-1]:
		hull.remove_at(hull.size() - 1);
	if hull.size() < 3:
		return [];
	return [hull];


func get_asset_polygon_points(asset_polygon: LowPolyAsset2DPolygon) -> PackedVector2Array:
	var polygon_points := PackedVector2Array();
	var offset := - self.size * 0.5;
	for point_index in asset_polygon.points:
		if point_index >= 0 and point_index < points.size():
			polygon_points.append(points[point_index] + offset);
	return polygon_points;


func notify_editor_file_saved(path: String) -> void:
	if Engine.is_editor_hint() and path.begins_with("res://"):
		var filesystem := EditorInterface.get_resource_filesystem();
		filesystem.update_file(path);
		if path in EditorInterface.get_open_scenes():
			EditorInterface.reload_scene_from_path(path);
			return;
		if not filesystem.is_scanning() and not filesystem.is_importing():
			filesystem.scan();


func remove_point(index: int) -> void:
	for edge_index in range(edges.size() - 1, -1, -1):
		var edge := edges[edge_index];
		if edge.a == index or edge.b == index:
			edges.remove_at(edge_index);

	for polygon_index in range(polygons.size() - 1, -1, -1):
		if index in polygons[polygon_index].points:
			polygons.remove_at(polygon_index);

	for edge in edges:
		if edge.a > index:
			edge.a -= 1;
		if edge.b > index:
			edge.b -= 1;

	for polygon in polygons:
		for point_index in range(polygon.points.size()):
			if polygon.points[point_index] > index:
				polygon.points[point_index] -= 1;

	points.remove_at(index);

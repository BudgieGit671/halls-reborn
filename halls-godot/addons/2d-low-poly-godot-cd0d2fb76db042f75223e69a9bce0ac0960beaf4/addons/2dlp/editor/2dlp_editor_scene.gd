@tool

class_name LowPolyAsset2DEditorScene;
extends Node2D;


enum Mode { Select, Pan, Move, Rotate }
enum MoveAxis { X = 0, Y = 1, XY }
	
var camera_node: Camera2D;
var reference_rect_node: ReferenceRect;

var file: LowPolyAsset2D;
var mode: Mode = Mode.Select;
var previous_mode: Mode;
const toggle_modes: Array[Mode] = [Mode.Pan, Mode.Select];

var panning := false;
var panning_prev_pos: Vector2;

var show_points: bool = true;
var show_edges: bool = true;
var show_polygons: bool = true;

var polygon_draw_points: Array[PackedVector2Array];

var hover_point: int = -1;
var selected_points: Array[int];

var selection_drag_active := false;
var selection_dragging := false;
var selection_drag_additive := false;
var selection_drag_start: Vector2;
var selection_drag_start_mouse_position: Vector2;
var selection_drag_initial_points: Array[int];

var undo_redo: EditorUndoRedoManager;

var rotation_start_pos: Vector2;
var rotation_angle: float = 0;

var move_start_pos: Vector2;
var move_delta: Vector2;
var move_axis: MoveAxis = MoveAxis.XY;

var previous_global_pos: Vector2;

var value_input: String = "";

var edit_color: Color;


func _ready() -> void:
	self.camera_node = Camera2D.new();
	add_child(self.camera_node);
	
	self.reference_rect_node = ReferenceRect.new();
	add_child(self.reference_rect_node);
	self.reference_rect_node.visible = false;
	
	if self.undo_redo != null:
		self.undo_redo.version_changed.connect(func(): self.mode = self.previous_mode);


func set_file(file: LowPolyAsset2D) -> void:
	if file == self.file:
		return;
	
	var auto_zoom = self.file == null;
	self.file = file;
	clean_scene();
	
	if self.file == null:
		self.reference_rect_node.visible = false;
		return;
	
	# Set up reference rect
	self.reference_rect_node.visible = true;
	self.reference_rect_node.size = self.file.size;
	
	center_camera(auto_zoom);
	queue_redraw();


func clean_scene() -> void:
	pass


func center_camera(auto_zoom: bool) -> void:
	if self.file == null:
		return;
	
	camera_node.position = reference_rect_node.position + reference_rect_node.size / 2;
	
	if auto_zoom:
		var viewport_rect := get_viewport().get_visible_rect();
		var zoom_factor = 0.98 * min(
			viewport_rect.size.x / reference_rect_node.size.x,  
			viewport_rect.size.y / reference_rect_node.size.y);
		camera_node.zoom = Vector2(zoom_factor, zoom_factor);


func set_mode(mode: Mode) -> void:
	self.mode = mode;
	self.previous_mode = mode;
	self.value_input = "";
		

func left_mouse_panning_allowed() -> bool:
	return mode == Mode.Pan;


func right_mouse_panning_allowed() -> bool:
	return mode == Mode.Select or mode == Mode.Pan;


func _process(delta: float) -> void:
	if file == null:
		return;
	
	queue_redraw();
	
	self.reference_rect_node.size = self.file.size;
	
	var mouse_inside := get_viewport().get_visible_rect().has_point(get_viewport().get_mouse_position());
	
	if panning:
		var pan_down: bool = (
			Input.is_action_pressed(LowPoly2DAssetsConstants.PAN_LEFT_CLICK_ACTION) 
				and left_mouse_panning_allowed()
			or Input.is_action_pressed(LowPoly2DAssetsConstants.PAN_RIGHT_CLICK_ACTION) 
				and right_mouse_panning_allowed()
		);
		if pan_down:
			var new_pos := camera_node.get_local_mouse_position();
			camera_node.position -= new_pos - self.panning_prev_pos;
			self.panning_prev_pos = new_pos;
		else:
			panning = false;
			DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW);
	else:
		var pan_pressed: bool = (
			Input.is_action_just_pressed(LowPoly2DAssetsConstants.PAN_LEFT_CLICK_ACTION)
				and left_mouse_panning_allowed()
			or Input.is_action_just_pressed(LowPoly2DAssetsConstants.PAN_RIGHT_CLICK_ACTION) 
				and right_mouse_panning_allowed()
		);
		
		if pan_pressed and mouse_inside:
			panning = true;
			self.panning_prev_pos = camera_node.get_local_mouse_position();
			DisplayServer.cursor_set_shape(DisplayServer.CURSOR_DRAG);
	
	# Handle point hover
	hover_point = -1;
	if not panning and show_points:
		var closest_point := -1;
		var closest_dist := 1.0e300;
		
		var mouse_pos := camera_node.get_global_mouse_position();
		for i in range(file.points.size()):
			var point := file.points[i];
			var dist := point.distance_squared_to(mouse_pos);
			
			if dist < closest_dist:
				closest_dist = dist;
				closest_point = i;
		
		if closest_dist <= LowPoly2DAssetsConstants.POINT_SELECT_RADIUS * LowPoly2DAssetsConstants.POINT_SELECT_RADIUS:
			hover_point = closest_point;
			
	if mode == Mode.Select:
		if Input.is_action_just_pressed(LowPoly2DAssetsConstants.SELECT_ACTION) and mouse_inside:
			selection_drag_active = true;
			selection_dragging = false;
			selection_drag_additive = Input.is_key_pressed(KEY_SHIFT);
			selection_drag_start = camera_node.get_global_mouse_position();
			selection_drag_start_mouse_position = get_viewport().get_mouse_position();
			selection_drag_initial_points = selected_points.duplicate();
		elif selection_drag_active:
			if Input.is_action_pressed(LowPoly2DAssetsConstants.SELECT_ACTION):
				selection_dragging = selection_dragging or selection_drag_start_mouse_position.distance_to(get_viewport().get_mouse_position()) >= 4.0;
			elif Input.is_action_just_released(LowPoly2DAssetsConstants.SELECT_ACTION):
				if selection_dragging:
					select_points_in_drag_rect();
				else:
					select_hover_point(selection_drag_additive);
				selection_drag_active = false;
	
	# Only allow add and remove when in classic mode, not editing mode
	if mode in toggle_modes:
		if Input.is_action_just_pressed(LowPoly2DAssetsConstants.ADD_POINT_ACTION):
			undo_redo.create_action("Add point");
			undo_redo.add_undo_property(file, "points", file.points.duplicate());
			undo_redo.add_undo_property(self, "selected_points", selected_points.duplicate());
			file.points.append(get_cursor_position());
			selected_points = [file.points.size() - 1];
			undo_redo.add_do_property(self, "selected_points", selected_points.duplicate());
			undo_redo.add_do_property(file, "points", file.points.duplicate());
			undo_redo.commit_action(false);
		
		if Input.is_action_just_pressed(LowPoly2DAssetsConstants.REMOVE_ACTION) and not selected_points.is_empty():
			undo_redo.create_action("Remove point" if selected_points.size() == 1 else "Remove points");
			undo_redo.add_undo_property(file, "points", file.points.duplicate());
			undo_redo.add_undo_property(file, "edges", file.edges.duplicate_deep());
			undo_redo.add_undo_property(file, "polygons", file.polygons.duplicate_deep());
			undo_redo.add_undo_property(self, "selected_points", selected_points.duplicate());
			
			# Remove points in reverse order, so that indices don't change
			selected_points.sort();
			selected_points.reverse();
			for point_index in selected_points:
				file.remove_point(point_index);
			selected_points.clear();
			
			undo_redo.add_do_property(file, "points", file.points.duplicate());
			undo_redo.add_do_property(file, "edges", file.edges.duplicate_deep());
			undo_redo.add_do_property(file, "polygons", file.polygons.duplicate_deep());
			undo_redo.add_do_property(self, "selected_points", selected_points.duplicate());
			undo_redo.commit_action(false);
		
		if Input.is_action_just_pressed(LowPoly2DAssetsConstants.LINK_ACTION) and selected_points.size() > 1:
			undo_redo.create_action("Link points");
			undo_redo.add_undo_property(file, "edges", file.edges.duplicate_deep());
			for i in range(1, selected_points.size()):
				self.file.try_append_edge(selected_points[i - 1], selected_points[i]);
			
			if selected_points.size() > 2:
				self.file.try_append_edge(selected_points[0], selected_points[selected_points.size() - 1]);
				undo_redo.add_undo_property(file, "polygons", file.polygons.duplicate_deep());
				self.file.try_append_polygon(selected_points, self.edit_color);
				undo_redo.add_do_property(file, "polygons", file.polygons.duplicate_deep());
			
			undo_redo.add_do_property(file, "edges", file.edges.duplicate_deep());
			undo_redo.commit_action(false);
				
	
	if Input.is_action_just_pressed(LowPoly2DAssetsConstants.ROTATE_ACTION) and not selected_points.is_empty():
		if mode in toggle_modes:
			previous_mode = mode;
		mode = Mode.Rotate;
		rotation_start_pos = camera_node.get_global_mouse_position();
		rotation_angle = 0;
		value_input = "";
	
	if mode == Mode.Rotate:
		var mouse_pos := camera_node.get_global_mouse_position();
		if mouse_pos != previous_global_pos:
			var center := get_cursor_position();
			rotation_angle = (rotation_start_pos - center).angle_to(mouse_pos - center);
			
		if Input.is_action_just_pressed(LowPoly2DAssetsConstants.CONFIRM_ACTION) or Input.is_action_just_pressed(LowPoly2DAssetsConstants.SELECT_ACTION):
			mode = previous_mode;
			value_input = "";
			var center := get_cursor_position();
			undo_redo.create_action("Rotate point" if selected_points.size() == 1 else "Rotate points");
			undo_redo.add_undo_property(file, "points", file.points.duplicate());
			for i in selected_points:
				file.points[i] = center + (file.points[i] - center).rotated(rotation_angle);
			undo_redo.add_do_property(file, "points", file.points.duplicate());
			undo_redo.commit_action(false);

		if Input.is_action_just_pressed(LowPoly2DAssetsConstants.CANCEL_ACTION):
			mode = previous_mode;
			value_input = "";
			
	if Input.is_action_just_pressed(LowPoly2DAssetsConstants.MOVE_ACTION) and not selected_points.is_empty():
		if mode in toggle_modes:
			previous_mode = mode;
		mode = Mode.Move;
		move_start_pos = camera_node.get_global_mouse_position() if mouse_inside else get_cursor_position();
		move_delta = Vector2.ZERO;
		move_axis = MoveAxis.XY;
		value_input = "";
	
	if mode == Mode.Move:
		var mouse_pos := camera_node.get_global_mouse_position();
		if mouse_pos != previous_global_pos:
			move_delta = mouse_pos - move_start_pos;
		
		if Input.is_action_just_pressed(LowPoly2DAssetsConstants.CONFIRM_ACTION) or Input.is_action_just_pressed(LowPoly2DAssetsConstants.SELECT_ACTION):
			mode = previous_mode;
			value_input = "";
			undo_redo.create_action("Move point" if selected_points.size() == 1 else "Move points");
			undo_redo.add_undo_property(file, "points", file.points.duplicate());
			for i in selected_points:
				file.points[i] = move_position(file.points[i]);
			undo_redo.add_do_property(file, "points", file.points.duplicate());
			undo_redo.commit_action(false);
		
		if Input.is_action_just_pressed(LowPoly2DAssetsConstants.CANCEL_ACTION):
			mode = previous_mode;
			value_input = "";
	
	var zoom_input := Input.get_axis(LowPoly2DAssetsConstants.ZOOM_OUT_ACTION, LowPoly2DAssetsConstants.ZOOM_IN_ACTION);
	if zoom_input != 0 and mouse_inside:
		var zoom_factor := 1.0 + zoom_input * LowPoly2DAssetsConstants.ZOOM_SPEED * delta;
		zoom(zoom_factor);
	
	previous_global_pos = camera_node.get_global_mouse_position();
		

func select_hover_point(additive: bool) -> void:
	if additive:
		if hover_point == -1:
			return;
		if hover_point in selected_points:
			undo_redo.create_action("Unselect point");
			undo_redo.add_undo_property(self, "selected_points", selected_points.duplicate());
			selected_points.erase(hover_point);
			undo_redo.add_do_property(self, "selected_points", selected_points.duplicate());
			undo_redo.commit_action(false);
		else:
			undo_redo.create_action("Select point inclusively");
			undo_redo.add_undo_property(self, "selected_points", selected_points.duplicate());
			selected_points.append(hover_point);
			undo_redo.add_do_property(self, "selected_points", selected_points.duplicate());
			undo_redo.commit_action(false);
	elif hover_point == -1:
		if not selected_points.is_empty():
			undo_redo.create_action("Unselect point" if selected_points.size() == 1 else "Unselect points");
			undo_redo.add_do_property(self, "selected_points", []);
			undo_redo.add_undo_property(self, "selected_points", selected_points.duplicate());
			undo_redo.commit_action(false);
		selected_points.clear();
	else:
		undo_redo.create_action("Select point");
		undo_redo.add_undo_property(self, "selected_points", selected_points.duplicate());
		selected_points = [hover_point];
		undo_redo.add_do_property(self, "selected_points", selected_points.duplicate());
		undo_redo.commit_action(false);


func select_points_in_drag_rect() -> void:
	var selection_rect := Rect2(selection_drag_start, camera_node.get_global_mouse_position() - selection_drag_start).abs();
	var new_selection: Array[int];
	if selection_drag_additive:
		new_selection = selected_points.duplicate();
	for i in range(file.points.size()):
		if selection_rect.has_point(file.points[i]) and i not in new_selection:
			new_selection.append(i);

	if new_selection == selected_points:
		return;

	undo_redo.create_action("Select points");
	undo_redo.add_undo_property(self, "selected_points", selected_points.duplicate());
	selected_points = new_selection;
	undo_redo.add_do_property(self, "selected_points", selected_points.duplicate());
	undo_redo.commit_action(false);


func handle_input(event: InputEvent) -> bool:
		
	if self.file == null:
		return false;

	var mouse_inside := get_viewport().get_visible_rect().has_point(get_viewport().get_mouse_position());
	if not mouse_inside:
		return false;

	if event is InputEventMagnifyGesture:
		zoom(event.factor);
		return true;
	
	if mode == Mode.Rotate or mode == Mode.Move:
		if event is InputEventKey and event.is_pressed():
			if event.keycode == KEY_BACKSPACE and not value_input.is_empty():
				value_input = value_input.erase(value_input.length() - 1);
				update_value_input()
				return true;
			
			elif event.unicode != 0:
				var char := char(event.unicode);
				if char in "0123456789.-":
					value_input += char;
					update_value_input();
					return true;
				
				elif mode == Mode.Move:
					if char == "x":
						move_axis = MoveAxis.X;
					elif char == "y":
						move_axis = MoveAxis.Y;
		
	return false;


func zoom(factor: float) -> void:
	var zoom := clamp(camera_node.zoom.x * factor, 0.02, 50.0);
	var mouse_pos_before_zoom := camera_node.get_local_mouse_position();
	camera_node.zoom = Vector2(zoom, zoom);
	var mouse_pos_after_zoom := camera_node.get_local_mouse_position();
	
	# Shift camera position to keep mouse position the same
	camera_node.position += mouse_pos_before_zoom - mouse_pos_after_zoom;
	

func _draw() -> void:
	if file == null:
		return;
	
	var points := file.points.duplicate();
	for i in range(points.size()):
		var point := points[i];

		match mode:
			Mode.Rotate:
				if i in selected_points:
					var center := get_cursor_position();
					point = center + (point - center).rotated(rotation_angle);
			Mode.Move:
				if i in selected_points:
					point = move_position(point);
		points[i] = point;
		
	if show_polygons:
		self.polygon_draw_points.clear();
		for polygon in file.polygons:
			var draw_points := PackedVector2Array();
			for point in polygon.points:
				draw_points.append(points[point]);
			draw_colored_polygon(draw_points, polygon.color);
			# Save points array until the next frame, because draw_colored_polygon needs a long-lived array.
			self.polygon_draw_points.append(draw_points);

	if show_edges:
		for edge in file.edges:
			var color := Color.LIGHT_GRAY;
			if edge.a in selected_points and edge.b in selected_points:
				color = Color.YELLOW;
			draw_line(points[edge.a], points[edge.b], color, 1, true);

	if selection_drag_active and selection_dragging:
		var selection_rect := Rect2(selection_drag_start, camera_node.get_global_mouse_position() - selection_drag_start).abs();
		draw_rect(selection_rect, Color(0.4, 0.7, 1, 0.2), true);
		draw_rect(selection_rect, Color(0.4, 0.7, 1), false, 1, true);
	
	if show_points:
		for i in range(points.size()):
			var point := points[i];
			var radius := LowPoly2DAssetsConstants.POINT_RENDER_RADIUS;
			
			if i == hover_point:
				radius = LowPoly2DAssetsConstants.POINT_SELECT_RADIUS;
				draw_circle(point, radius, Color(1, 1, 1, 0.3), true);
			elif i in selected_points:
				draw_circle(point, radius, Color.YELLOW, true);
			draw_circle(point, 0.25 * radius, Color.WHITE, true);
			draw_arc(point, radius, 0, TAU, 32, Color.WHITE, 1, true);
	
	if mode == Mode.Rotate:
		var center := get_cursor_position();
		
		# Draw rotation center
		draw_circle(center, LowPoly2DAssetsConstants.POINT_RENDER_RADIUS * 0.25, Color.BLUE, true);
		
		# Draw rotation limits
		var vector := (rotation_start_pos - center).normalized() * LowPoly2DAssetsConstants.ROTATION_INDICATOR_RADIUS * 1.2;
		draw_line(center, center + vector, Color.GRAY, 1, true);
		draw_line(center, center + vector.rotated(rotation_angle), Color.LIGHT_GRAY, 1, true);
		
		# Draw arc
		var start_angle := Vector2.RIGHT.angle_to(rotation_start_pos - center);
		draw_arc(center, LowPoly2DAssetsConstants.ROTATION_INDICATOR_RADIUS, start_angle, start_angle + rotation_angle, 16, Color.LIGHT_GRAY, 1, true);
	
	if mode == Mode.Move:
		var center := get_cursor_position();
		
		# Draw move axis if applicable
		if move_axis == MoveAxis.X:
			var start := Vector2(0, center.y);
			var end := Vector2(reference_rect_node.size.x, center.y);
			draw_line(start, end, Color.RED, 1, true);
		elif move_axis == MoveAxis.Y:
			var start := Vector2(center.x, 0);
			var end := Vector2(center.x, reference_rect_node.size.y);
			draw_line(start, end, Color.GREEN, 1, true);
		
		# Draw delta move
		draw_line(center, move_position(center), Color.LIGHT_GRAY, 1, true);


func get_cursor_position() -> Vector2:
	return get_barycentric_position();


func get_barycentric_position() -> Vector2:
	var total := Vector2.ZERO;
	
	for i in range(selected_points.size()):
		total += file.points[selected_points[i]];
	if not selected_points.is_empty():
		total /= selected_points.size();
	
	return total;

func update_value_input() -> void:
	match mode:
		Mode.Rotate:
			if value_input.is_valid_float():
				rotation_angle = deg_to_rad(value_input.to_float());
			else:
				rotation_angle = 0;
		Mode.Move:
			if move_axis == MoveAxis.XY:
				value_input = "";
			elif value_input.is_valid_float():
				move_delta[move_axis] = value_input.to_float();
			else:
				move_delta[move_axis] = 0;


func move_position(position: Vector2) -> Vector2:
	match move_axis:
		MoveAxis.X:
			return position + Vector2(move_delta.x, 0);
		MoveAxis.Y:
			return position + Vector2(0, move_delta.y);
		MoveAxis.XY:
			return position + move_delta;
	return position;

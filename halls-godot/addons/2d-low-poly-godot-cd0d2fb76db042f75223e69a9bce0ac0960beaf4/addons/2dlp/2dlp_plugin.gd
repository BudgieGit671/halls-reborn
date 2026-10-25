@tool
extends EditorPlugin

var dock: EditorDock;
var editor: LowPolyAsset2DEditor;
var current_asset: LowPolyAsset2D;
var created_input_actions: Array[String];


func _enter_tree() -> void:
	const EditorWindow := preload("res://addons/2dlp/editor/2dlp_window.tscn");
	
	editor = EditorWindow.instantiate();
	editor.undo_redo = self.get_undo_redo();
	
	dock = EditorDock.new();
	dock.add_child(editor);
	
	dock.name = "2D Low Poly Assets";
	dock.default_slot = EditorDock.DockSlot.DOCK_SLOT_BOTTOM;
	dock.available_layouts = EditorDock.DOCK_LAYOUT_HORIZONTAL | EditorDock.DOCK_LAYOUT_FLOATING;
	
	add_dock(dock);
	
	# Register custom actions
	
	if not InputMap.has_action(LowPoly2DAssetsConstants.PAN_LEFT_CLICK_ACTION):
		var event := InputEventMouseButton.new();
		event.button_index = MOUSE_BUTTON_LEFT;
		InputMap.add_action(LowPoly2DAssetsConstants.PAN_LEFT_CLICK_ACTION);
		created_input_actions.append(LowPoly2DAssetsConstants.PAN_LEFT_CLICK_ACTION);
		InputMap.action_add_event(LowPoly2DAssetsConstants.PAN_LEFT_CLICK_ACTION, event);
	
	if not InputMap.has_action(LowPoly2DAssetsConstants.PAN_RIGHT_CLICK_ACTION):
		var event := InputEventMouseButton.new();
		event.button_index = MOUSE_BUTTON_RIGHT;
		InputMap.add_action(LowPoly2DAssetsConstants.PAN_RIGHT_CLICK_ACTION);
		created_input_actions.append(LowPoly2DAssetsConstants.PAN_RIGHT_CLICK_ACTION);
		InputMap.action_add_event(LowPoly2DAssetsConstants.PAN_RIGHT_CLICK_ACTION, event);
		
	if not InputMap.has_action(LowPoly2DAssetsConstants.ZOOM_IN_ACTION):
		var event := InputEventMouseButton.new();
		event.button_index = MOUSE_BUTTON_WHEEL_UP;
		InputMap.add_action(LowPoly2DAssetsConstants.ZOOM_IN_ACTION);
		created_input_actions.append(LowPoly2DAssetsConstants.ZOOM_IN_ACTION);
		InputMap.action_add_event(LowPoly2DAssetsConstants.ZOOM_IN_ACTION, event);
	
	if not InputMap.has_action(LowPoly2DAssetsConstants.ZOOM_OUT_ACTION):
		var event := InputEventMouseButton.new();
		event.button_index = MOUSE_BUTTON_WHEEL_DOWN;
		InputMap.add_action(LowPoly2DAssetsConstants.ZOOM_OUT_ACTION);
		created_input_actions.append(LowPoly2DAssetsConstants.ZOOM_OUT_ACTION);
		InputMap.action_add_event(LowPoly2DAssetsConstants.ZOOM_OUT_ACTION, event);
	
	if not InputMap.has_action(LowPoly2DAssetsConstants.SELECT_ACTION):
		var event := InputEventMouseButton.new();
		event.button_index = MOUSE_BUTTON_LEFT;
		InputMap.add_action(LowPoly2DAssetsConstants.SELECT_ACTION);
		created_input_actions.append(LowPoly2DAssetsConstants.SELECT_ACTION);
		InputMap.action_add_event(LowPoly2DAssetsConstants.SELECT_ACTION, event);
		
	if not InputMap.has_action(LowPoly2DAssetsConstants.ADD_POINT_ACTION):
		var event := InputEventKey.new();
		event.key_label = Key.KEY_A;
		InputMap.add_action(LowPoly2DAssetsConstants.ADD_POINT_ACTION);
		created_input_actions.append(LowPoly2DAssetsConstants.ADD_POINT_ACTION);
		InputMap.action_add_event(LowPoly2DAssetsConstants.ADD_POINT_ACTION, event);
	
	if not InputMap.has_action(LowPoly2DAssetsConstants.REMOVE_ACTION):
		var event := InputEventKey.new();
		event.key_label = Key.KEY_BACKSPACE;
		InputMap.add_action(LowPoly2DAssetsConstants.REMOVE_ACTION);
		created_input_actions.append(LowPoly2DAssetsConstants.REMOVE_ACTION);
		InputMap.action_add_event(LowPoly2DAssetsConstants.REMOVE_ACTION, event);
	
	if not InputMap.has_action(LowPoly2DAssetsConstants.MOVE_ACTION):
		var event := InputEventKey.new();
		event.key_label = Key.KEY_M;
		InputMap.add_action(LowPoly2DAssetsConstants.MOVE_ACTION);
		created_input_actions.append(LowPoly2DAssetsConstants.MOVE_ACTION);
		InputMap.action_add_event(LowPoly2DAssetsConstants.MOVE_ACTION, event);
	
	if not InputMap.has_action(LowPoly2DAssetsConstants.ROTATE_ACTION):
		var event := InputEventKey.new();
		event.key_label = Key.KEY_R;
		InputMap.add_action(LowPoly2DAssetsConstants.ROTATE_ACTION);
		created_input_actions.append(LowPoly2DAssetsConstants.ROTATE_ACTION);
		InputMap.action_add_event(LowPoly2DAssetsConstants.ROTATE_ACTION, event);
	
	if not InputMap.has_action(LowPoly2DAssetsConstants.CONFIRM_ACTION):
		var event := InputEventKey.new();
		event.key_label = Key.KEY_ENTER;
		InputMap.add_action(LowPoly2DAssetsConstants.CONFIRM_ACTION);
		created_input_actions.append(LowPoly2DAssetsConstants.CONFIRM_ACTION);
		InputMap.action_add_event(LowPoly2DAssetsConstants.CONFIRM_ACTION, event);
		
	if not InputMap.has_action(LowPoly2DAssetsConstants.CANCEL_ACTION):
		var mouse_event := InputEventMouseButton.new();
		mouse_event.button_index = MOUSE_BUTTON_RIGHT;
		var key_event := InputEventKey.new();
		key_event.key_label = Key.KEY_ESCAPE;
		InputMap.add_action(LowPoly2DAssetsConstants.CANCEL_ACTION);
		created_input_actions.append(LowPoly2DAssetsConstants.CANCEL_ACTION);
		InputMap.action_add_event(LowPoly2DAssetsConstants.CANCEL_ACTION, mouse_event);
		InputMap.action_add_event(LowPoly2DAssetsConstants.CANCEL_ACTION, key_event);
		
	if not InputMap.has_action(LowPoly2DAssetsConstants.LINK_ACTION):
		var event := InputEventKey.new();
		event.key_label = Key.KEY_L;
		InputMap.add_action(LowPoly2DAssetsConstants.LINK_ACTION);
		created_input_actions.append(LowPoly2DAssetsConstants.LINK_ACTION);
		InputMap.action_add_event(LowPoly2DAssetsConstants.LINK_ACTION, event);
		


func _exit_tree() -> void:
	if dock:
		remove_dock(dock);
		dock.queue_free();
		
	# Unregister custom actions
	for action in created_input_actions:
		if InputMap.has_action(action):
			InputMap.erase_action(action);
	created_input_actions.clear();


func _handles(object: Object) -> bool:
	return object is LowPolyAsset2D;


func _edit(object: Object) -> void:
	if object is LowPolyAsset2D:
		self.current_asset = object;
		editor.open_file(object);
		dock.make_visible();
	else:
		self.current_asset = null;

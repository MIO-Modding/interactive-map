@tool
class_name StatePanel extends PanelContainer


@export var text: String:
	set(v):
		text = v
		if is_inside_tree():
			if get_child_count() > 0:
				$H/Name.text = v

var is_save_panel := false

var save_index: int:
	set(v):
		save_index = v
		if is_inside_tree():
			if get_child_count() > 0:
				$H/OrderLabel.text = "#%d" % (v + 1)
				$H/OrderLabel.self_modulate = Color.GOLDENROD if v < 3 else Color.WHITE
				
				await get_tree().process_frame
				$H/MoveDown.disabled = v >= get_parent().get_child_count() - 1
				$H/MoveUp.disabled = v <= 0


func _init() -> void:
	if not is_inside_tree():
		await tree_entered
	if get_child_count() <= 0:
		for child in preload("res://Scenes/state_panel.tscn").instantiate().get_children():
			child.owner = null
			child.reparent(self)
			child.owner = self
	$H/Save.pressed.connect(save_file)
	$H/Load.pressed.connect(load_file)
	$H/Delete.pressed.connect(delete_file)
	$H/MoveUp.pressed.connect(move_up)
	$H/MoveDown.pressed.connect(move_down)
	if is_save_panel:
		get_saves_tab().mode_changed.connect(change_mode)
	else:
		get_saves_tab().toggle_delete.connect(toggle_delete)
	text = text


func get_saves_tab() -> SavesMenu:
	return Globals.main.get_node("TabContainer/Saves")


func save_file() -> void:
	if is_save_panel:
		get_saves_tab().save_save(Main.player_state, text)
	else:
		get_saves_tab().save_state(Main.player_state, text)


func load_file() -> void:
	var ap_items: Array[String]
	var state: Main.PlayerState
	if is_save_panel:
		state = get_saves_tab().load_save(text)
	else:
		state = get_saves_tab().load_state(text)
	ap_items = Main.player_state.ap_prog_items
	state.ap_prog_items = ap_items
	Main.player_state = state
	Globals.main.update_itempool.emit()


func delete_file() -> void:
	if is_save_panel:
		get_saves_tab().delete_save(text)
	else:
		get_saves_tab().delete_state(text)
	get_saves_tab().update_display()


func move_up() -> void:
	save_index -= 1
	var displacing: StatePanel = get_parent().get_child(save_index)
	displacing.save_index += 1
	get_parent().move_child(self, save_index)


func move_down() -> void:
	save_index += 1
	var displacing: StatePanel = get_parent().get_child(save_index)
	displacing.save_index -= 1
	get_parent().move_child(self, save_index)


func toggle_delete(on: bool) -> void:
	$H/Save.visible = not on
	$H/Load.visible = not on
	$H/Delete.visible = on


func change_mode(mode: int) -> void:
	var node_indexes: Dictionary[Control, int] = {
		$H/Save: 0,
		$H/Load: 0,
		$H/Delete: 1,
		$H/MoveUp: 2,
		$H/OrderLabel: 2,
		$H/MoveDown: 2,
	}
	for i in node_indexes:
		i.visible = node_indexes[i] == mode

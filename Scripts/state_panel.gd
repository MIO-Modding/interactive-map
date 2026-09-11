@tool
class_name StatePanel extends PanelContainer


@export var text: String:
	set(v):
		text = v
		if is_inside_tree():
			if get_child_count() > 0:
				$H/Name.text = v

var is_save_panel := false


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


func toggle_delete(on: bool) -> void:
	$H/Save.visible = not on
	$H/Load.visible = not on
	$H/Delete.visible = on

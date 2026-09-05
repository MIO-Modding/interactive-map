class_name LocationPanel extends FeaturePanel


const BASE_WIKITEXT: String = """
# Location: %s: %s (%s)

This location is in %s (%s), found %s.
Its type is %s, and it usually has %s.

### Vanilla Item
Item Name: %s
Save Flag: %s
Type: %s

### Logic
Intended: %s
Simple Skips: %s
Advanced Skips: %s

### Collected
%s

### Coordinates
Position: %s

### Notes
%s
"""


var region_name: String:
	set(v):
		region_name = v
		$HBoxContainer/Region.text = v
var room_id: String:
	set(v):
		room_id = v
		$HBoxContainer/Room.text = v
var loc_description: String:
	set(v):
		loc_description = v
		$HBoxContainer/LocationDescription.text = v
var coords: Vector2i:
	set(v):
		coords = v
		$HBoxContainer/LocationCoords.text = str(v)
var vanilla_item: String:
	set(v):
		vanilla_item = v
		$HBoxContainer/Item.text = v
var save_flag: String:
	set(v):
		save_flag = v
		$HBoxContainer/Flag.text = v

var intended_string: String:
	set(v):
		intended_string = v
		intended_logic = await TransitionPanel.string_to_logic(v, "intended", self)
		$HBoxContainer/Intended.text = v
var simple_string: String:
	set(v):
		simple_string = v
		simple_logic = await TransitionPanel.string_to_logic(v, "simple", self)
		$HBoxContainer/Simple.text = v
var advanced_string: String:
	set(v):
		advanced_string = v
		advanced_logic = await TransitionPanel.string_to_logic(v, "advanced", self)
		$HBoxContainer/Advanced.text = v

var intended_logic: Callable
var simple_logic: Callable
var advanced_logic: Callable

var notes: String:
	set(v):
		notes = v
		$HBoxContainer/Notes.text = v
var type: String:
	set(v):
		type = v
		$HBoxContainer/Type.text = v

var checked := false:
	set(v):
		checked = v
		$HBoxContainer/Checked.button_pressed = v

var point_node: Polygon2D

var original_color: Color


func update() -> void:
	if Main.player_state.checked_locations.has(self):
		modulate = Color(0.232, 0.566, 0.61)
		point_node.color = Color(0.1, 0.1, 0.1)
	elif $/root/Main.highlight_rows_in_logic:
		point_node.color = Color.WHITE
		await get_tree().process_frame
		if $/root/Main.reachable_locations.has(self):
			modulate = TransitionPanel.LOGIC_LEVEL_COLORS["intended"]
		elif $/root/Main.simple_reachable_locations.has(self):
			modulate = TransitionPanel.LOGIC_LEVEL_COLORS["simple"]
		elif $/root/Main.advanced_reachable_locations.has(self):
			modulate = TransitionPanel.LOGIC_LEVEL_COLORS["advanced"]
		else:
			modulate = Color.WHITE
	checked = Main.player_state.checked_locations.has(self)


func serialize() -> String:
	return Main.PlayerState.serialize_location(self)


func get_wikitext() -> String:
	return BASE_WIKITEXT % [
		Globals.fix_underscores(room_id), loc_description, region_name,
		Globals.fix_underscores(room_id), region_name, decapitalize(loc_description),
		type, vanilla_item,
		vanilla_item, Globals.fix_underscores(save_flag), type,
		Globals.fix_underscores(intended_string), Globals.fix_underscores(simple_string), Globals.fix_underscores(advanced_string),
		("Yes" if checked else "No"),
		str(coords),
		notes
	]


func get_pagename() -> String:
	print(serialize())
	return serialize()


func decapitalize(string: String) -> String:
	string[0] = string[0].to_lower()
	return string


func _on_checked_toggled(toggled_on: bool) -> void:
	checked = toggled_on
	if Archipelago.is_ap_connected():
		Globals.check_location(Globals.main.get_location_panel(serialize()), toggled_on)
	if point_node == null:
		modulate = Color(0.232, 0.566, 0.61) if toggled_on else original_color
	Main.player_state.check_location_serialized(serialize(), not toggled_on)


func _on_link_pressed() -> void:
	Globals.main.get_node("TabContainer/Info").add_page(Globals.main.get_location_panel(serialize()))

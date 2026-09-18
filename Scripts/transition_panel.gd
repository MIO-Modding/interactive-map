class_name TransitionPanel extends FeaturePanel


const LOGIC_LEVEL_COLORS = {
	"intended": Color(0.0, 1.0, 0.0, 1.0),
	"simple": Color(1.0, 1.0, 0.0, 1.0),
	"advanced": Color(1.0, 0.5, 0.0, 1.0)
}
const BASE_WIKITEXT = """
# Location: %s -> %s

This transition goes from %s (%s) to %s (%s).

### Logic
Intended: %s
Simple Skips: %s
Advanced Skips: %s
#### Computerized Logic
Intended: %s
Simple Skips: %s
Advanced Skips: %s

### Door
State: %s

### Notes
%s
"""


var from: String:
	set(v):
		from = v
		$HBoxContainer/From.text = v
var to: String:
	set(v):
		to = v
		$HBoxContainer/To.text = v

var first_pass: bool:
	set(v):
		first_pass = v
		$HBoxContainer/FirstPass.button_pressed = v

var intended_string: String:
	set(v):
		intended_string = v
		intended_logic = await LogicLevel.string_to_logic(v, "intended", self)
		$HBoxContainer/Intended.text = v
var simple_string: String:
	set(v):
		simple_string = v
		simple_logic = await LogicLevel.string_to_logic(v, "simple", self)
		$HBoxContainer/Simple.text = v
var advanced_string: String:
	set(v):
		advanced_string = v
		advanced_logic = await LogicLevel.string_to_logic(v, "advanced", self)
		$HBoxContainer/Advanced.text = v

var intended_logic: Callable
var simple_logic: Callable
var advanced_logic: Callable

var door: String:
	set(v):
		door = v
		if v == "Wrong Side":
			intended_logic = func(): return false
			simple_logic = intended_logic
			advanced_logic = simple_logic
		$HBoxContainer/Door.text = v

var notes: String:
	set(v):
		notes = v
		$HBoxContainer/Notes.text = v


func _init() -> void:
	await tree_entered
	for i in get_child(0).get_children():
		if i is Label:
			i.add_theme_color_override("font_color", Color.WHITE)


func update() -> void:
	if $/root/Main.highlight_rows_in_logic:
		if $/root/Main.highlight_reachable_rows:
			await get_tree().process_frame
			if $/root/Main.reachable_rooms.has(from) and $/root/Main.in_logic(self):
				modulate = LOGIC_LEVEL_COLORS["intended"]
			elif $/root/Main.simple_reachable_rooms.has(from) and $/root/Main.in_logic(self, LogicLevel.LogicLevels.SIMPLE_SKIPS):
				modulate = LOGIC_LEVEL_COLORS["simple"]
			elif $/root/Main.advanced_reachable_rooms.has(from) and $/root/Main.in_logic(self, LogicLevel.LogicLevels.ADVANCED_SKIPS):
				modulate = LOGIC_LEVEL_COLORS["advanced"]
			else:
				modulate = Color.WHITE
			
		else:
			if get_logic_result(intended_logic):
				modulate = LOGIC_LEVEL_COLORS["intended"]
			elif get_logic_result(simple_logic):
				modulate = LOGIC_LEVEL_COLORS["simple"]
			elif get_logic_result(advanced_logic):
				modulate = LOGIC_LEVEL_COLORS["advanced"]
			else:
				modulate = Color.WHITE


func get_logic_result(logic: Callable) -> bool:
	if logic == null or logic.is_null():
		return false
	else:
		return logic.call()


static func comp_info_string(string: String):
	return Globals.fix_underscores(LogicLevel.computerize_logic_string(string).replace("||", "or").replace("&&", "and"))


func get_pagename() -> String:
	return from + " -> " + to


func get_wikitext() -> String:
	return BASE_WIKITEXT % [
		Globals.fix_underscores(from), Globals.fix_underscores(to),
		Globals.fix_underscores(from), Globals.main.get_room_panel(from).region_name, 
		Globals.fix_underscores(to), Globals.main.get_room_panel(to).region_name,
		Globals.fix_underscores(intended_string), Globals.fix_underscores(simple_string), Globals.fix_underscores(advanced_string),
		comp_info_string(intended_string), comp_info_string(simple_string), comp_info_string(advanced_string),
		door,
		notes
	]


func _on_link_pressed() -> void:
	Globals.main.get_node("TabContainer/Info").add_page(Globals.main.get_transition_panel($HBoxContainer/To.text, $HBoxContainer/From.text))

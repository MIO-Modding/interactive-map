class_name Bingo extends Control


var prog_options: Array[String]
var type_options: Array[String]
var exclusions: Array[Dictionary]
var all_goals: Array[BingoGoal]


func load_bingo(data: Dictionary) -> void:
	Globals.free_all_children($Split/ScrollContainer/VBoxContainer)
	prog_options.assign(data["prog_options"])
	type_options.assign(data["type_options"])
	for goal in data["goals"]:
		var types: Array[String]
		var prog: Array[String]
		types.assign(goal["types"])
		prog.assign(goal["progression"])
		var resource := BingoGoal.new(goal["name"], types, prog)
		all_goals.append(resource)
		var node: PanelContainer = preload("res://Scenes/bingo_goal_panel.tscn").instantiate()
		node.get_node("HBoxContainer/Label").text = goal["name"]
		$Split/ScrollContainer/VBoxContainer.add_child(node)
		#print(goal["name"])


class BingoGoal:
	
	var goal_name: String
	var goal_types: Array[String]
	var progression: Array[String]
	
	
	func _init(name_value: String = "", types_value: Array[String] = [], progression_value: Array[String] = []) -> void:
		goal_name = name_value
		goal_types = types_value
		progression = progression_value

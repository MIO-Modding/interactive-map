class_name TransitionPanel extends PanelContainer


const LOGIC_LEVEL_COLORS = {
	"intended": Color(0.0, 1.0, 0.0, 1.0),
	"simple": Color(1.0, 1.0, 0.0, 1.0),
	"advanced": Color(1.0, 0.5, 0.0, 1.0)
}


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
		intended_logic = await string_to_logic(v, "intended")
		$HBoxContainer/Intended.text = v
var simple_string: String:
	set(v):
		simple_string = v
		simple_logic = await string_to_logic(v, "simple")
		$HBoxContainer/Simple.text = v
var advanced_string: String:
	set(v):
		advanced_string = v
		advanced_logic = await string_to_logic(v, "advanced")
		$HBoxContainer/Advanced.text = v

var intended_logic: Callable
var simple_logic: Callable
var advanced_logic: Callable

var door: String:
	set(v):
		door = v
		$HBoxContainer/Door.text = v

var notes: String:
	set(v):
		notes = v
		$HBoxContainer/Notes.text = v


func update() -> void:
	if get_node("/root/Main").highlight_rows_in_logic:
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


func string_to_logic(string: String, from_type: String) -> Callable:
	var heirarchy = ["intended", "simple", "advanced"]
	
	if string == "-":
		if from_type == "intended":
			return func(): return true
		else:
			if not is_inside_tree():
				await tree_entered
			await get_tree().process_frame
			return get("%s_logic" % heirarchy[heirarchy.find(from_type) - 1])
	elif string == "True":
		return func(): return true
	elif string == "False":
		return func(): return false
	else:
		string = string.replace("(", "{ ").replace(")", " }").replace(" and ", " && ").replace(" or ", " || ").replace("glide", "sail")
		string = string.replace("attack", "slash") # TODO
		for i in ["airstall", "crystal_stall", "ground_pogo", "enemy_pogo", "pogo_jump"]:
			string = string.replace(i, "slash")
		string = string.replace("hairpin_launch", "hairpin").replace("slope_boost", "True")
		string = string.replace("e_dodge", "{ dodge && TRINKET:BETTER_DODGE }").replace("defrag", "TRINKET:ORB_RECOVERY")
		string = string.replace("latency", "TRINKET:FAST_RECOVERY")
		string = string.replace("defrag_pogo", "{ slash && TRINKET:ORB_BLOCK && TRINKET:FAST_RECOVERY }")
		string = string.replace("glide_stall", "{ slash && sail }").replace("strider_triple", "striders")
		string = string.replace("splodge", "{ dodge && TRINKET:ORB_BLOCK }")
		string = string.replace("shairpin", "{ slash && hairpin && TRINKET:HOOK_SLASH }")
		string = string.replace("pain_conv", "TRINKET:KINETIC_CONVERSION")
		string = string.replace("hazard_striders", "striders").replace("wall_climb", "{ slash && dodge }")
		string = string.replace("hazard_respawn", "True")
		string = string.replace("super_spring", "True")
		string = string.replace("laser_skip", "slash") #hmmm
		string = string.replace("flower_warp", "slash")
		string = string.replace("harvester", "{ harvester && slash }").replace("slingshot", "{ slingshot && slash }")
		string = string.replace("flowing_steps", "{ striders && flowing_steps }").replace("striders", "{ striders || flowing_steps }")
		string = string.replace("{ striders || flowing_steps } & flowing_steps", "striders & flowing_steps")
		string = string.replace("CHEST_KEY:0-5", "{ CHEST_KEY:0 && CHEST_KEY:1 && CHEST_KEY:2 && CHEST_KEY:3 && CHEST_KEY:4 && CHEST_KEY:5 }")
		
		return await parse_logic(string)


func parse_logic(logic_string: String) -> Callable:
	var logic_list: Array[Callable]
	var edited_string: String = logic_string
	if not edited_string.is_empty():
		edited_string = trim_redundant_parentheses(edited_string)
	
	if not is_inside_tree():
		await tree_entered
	var state = get_node("/root/Main").player_state
	
	while edited_string.contains("{"):
		var right_brace_pos: int = edited_string.find("}")
		var left_brace_pos: int = edited_string.left(right_brace_pos + 1).rfind("{")
		var section = edited_string.substr(left_brace_pos + 2, right_brace_pos - left_brace_pos - 3)
		var converted = convert_item_text(section)
		var logic: Callable
		if converted.contains("&&"):
			var hases: Array[Callable] = []
			for i in converted.split(" && "):
				if i.contains("@"):
					hases.append(logic_list[i.substr(i.find("@")).to_int()])
					continue
				hases.append(state.has_call(i))
			logic = state.and_call(hases)
		elif converted.contains("||"):
			var hases: Array[Callable] = []
			for i in converted.split(" || "):
				if i.contains("@"):
					hases.append(logic_list[i.substr(i.find("@")).to_int()])
					continue
				hases.append(state.has_call(i))
			logic = state.or_call(hases)
		else:
			break
		
		edited_string = edited_string.replace("{ " + section + " }", "@" + str(logic_list.size()))
		logic_list.append(logic)
	
	var last_converted = convert_item_text(edited_string)
	var last_logic: Callable
	if last_converted.contains("&&"):
		var hases: Array[Callable] = []
		for i in last_converted.split(" && "):
			if i.contains("@"):
				hases.append(logic_list[i.substr(i.find("@")).to_int()])
				continue
			hases.append(state.has_call(i))
		last_logic = state.and_call(hases)
	elif last_converted.contains("||"):
		var hases: Array[Callable] = []
		for i in last_converted.split(" || "):
			if i.contains("@"):
				hases.append(logic_list[i.substr(i.find("@")).to_int()])
				continue
			hases.append(state.has_call(i))
		last_logic = state.or_call(hases)
	else:
		last_logic = state.has_call(last_converted)
	
	#print(logic_string)
	#print(last_converted)
	
	return last_logic


func convert_item_text(text: String) -> String:
	for i in get_node("/root/Main").items_sheet:
		if text.contains(i[6]):
			if text.split(" ").has(i[6]):
				text = text.replace(i[6], i[0]) 
				break
	
	for i in ["slash", "hairpin", "dodge", "sail", "harvester", "striders", "slingshot", "flowing_steps"]:
		text = text.replace(i, i.capitalize())
	return text


static func trim_redundant_parentheses(text: String) -> String:
	if text[0] != "{":
		return text
	
	var amount = 0
	
	for i in range(text.length()):
		var character = text[i]
		if character == "{":
			amount += 1
		elif character == "}":
			amount -= 1
		
		if amount <= 0:
			if i == text.length() - 1:
				return text.trim_prefix("{ ").trim_suffix(" }")
			else:
				return text
	
	return text.trim_prefix("{ ")

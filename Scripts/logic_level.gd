class_name LogicLevel extends Resource


## The levels of logic used
enum LogicLevels {
	NONE, ## Out of logic (ool)
	INTENDED_LOGIC, ## The player is intended in the game to be able to reach this room/location.
	SIMPLE_SKIPS, ## The player can preform simple skips to be able to reach this room/location.
	ADVANCED_SKIPS, ## The player can preform advanced skips to be able to reach this room/location.
}

## The associated colors for [enum LogicLevels]
const LEVEL_COLORS: Dictionary[LogicLevels, Color] = {
	LogicLevels.NONE: Color.WHITE,
	LogicLevels.INTENDED_LOGIC: Color.GREEN,
	LogicLevels.SIMPLE_SKIPS: Color.YELLOW,
	LogicLevels.ADVANCED_SKIPS: Color(1.0, 0.5, 0.0),
}

var level: LogicLevels

var string: String:
	set(v):
		string = v
		logic = Callable()
var logic := Callable():
	get():
		if logic != Callable():
			return logic
		else:
			return await string_to_logic(string, "", Node.new())


static func combine_logic(l1: LogicLevel, l2: LogicLevel) -> LogicLevel:
	var result := LogicLevel.new()
	result.level = get_higher_logic(l1.level, l2.level)
	result.text = combine_logic_strings(l1.string, l2.string)
	return l1


static func combine_logic_strings(string1: String, string2: String) -> String:
	if string1 == "":
		return string2
	elif string2 == "":
		return string1
	elif string1 == "False":
		return string1
	elif string2 == "False":
		return string2
	elif string1 == "True":
		return string2
	elif string2 == "True":
		return string1
	return "(%s) and (%s)" % [string1, string2]


## Returns the harder logic between the two
static func get_higher_logic(logic1: LogicLevel.LogicLevels, logic2: LogicLevel.LogicLevels) -> LogicLevel.LogicLevels:
	return maxi(logic1, logic2) as LogicLevel.LogicLevels


static func string_to_logic(logic_string: String, from_type: String, node: Node) -> Callable:
	var heirarchy = ["intended", "simple", "advanced"]
	
	if logic_string == "-":
		if from_type == "intended":
			return func(): return true
		else:
			await Globals.get_tree().process_frame
			var getting: String = "%s_logic" % heirarchy[heirarchy.find(from_type) - 1]
			if getting in node:
				return node.get(getting)
	elif logic_string == "True":
		return func(): return true
	elif logic_string == "False":
		return func(): return false
	else:
		return await parse_logic(computerize_logic_string(logic_string), node)
	
	return func(): return false


static func computerize_logic_string(logic_string: String) -> String:
	logic_string = logic_string.replace("(", "{ ").replace(")", " }").replace(" and ", " && ").replace(" or ", " || ").replace("glide", "sail")
	for i in ["airstall", "crystal_stall", "ground_pogo", "enemy_pogo", "pogo_jump", "enemy_pogos"]:
		logic_string = logic_string.replace(i, "slash")
	logic_string = logic_string.replace("Meet Mel", "Find Mel")
	logic_string = logic_string.replace("hairpin_launch", "hairpin").replace("slope_boost", "True")
	logic_string = logic_string.replace("e_dodge", "{ dodge && TRINKET:BETTER_DODGE }")
	logic_string = logic_string.replace("latency", "TRINKET:FAST_RECOVERY")
	logic_string = logic_string.replace("defrag_pogo", "{ slash && TRINKET:ORB_RECOVERY && TRINKET:FAST_RECOVERY }").replace("defrag", "TRINKET:ORB_RECOVERY")
	logic_string = logic_string.replace("sail_stall", "{ slash && sail }").replace("strider_triple", "striders")
	logic_string = logic_string.replace("splodge", "{ dodge && TRINKET:ORB_BLOCK }")
	logic_string = logic_string.replace("shairpin", "{ slash && hairpin && TRINKET:HOOK_SLASH }")
	for way in ["stroost", "striders boost", "striders_boost"]:
		logic_string = logic_string.replace(way, "{ striders && dodge }")
	logic_string = logic_string.replace("pain_conv", "TRINKET:KINETIC_CONVERSION")
	logic_string = logic_string.replace("hazard_striders", "striders").replace("wall_climb", "{ slash && dodge }")
	logic_string = logic_string.replace("hazard_respawn", "True")
	logic_string = logic_string.replace("super_spring", "True")
	logic_string = logic_string.replace("laser_skip", "slash")
	logic_string = logic_string.replace("flower_warp", "slash")
	logic_string = logic_string.replace("enemy_lure", "True")
	logic_string = logic_string.replace("harvester", "{ harvester && slash }").replace("slingshot", "{ slingshot && slash }")
	logic_string = logic_string.replace("flowing_steps", "{ striders && flowing_steps }").replace("striders", "{ striders || flowing_steps }")
	logic_string = logic_string.replace("{ striders || flowing_steps } && flowing_steps", "striders && flowing_steps")
	logic_string = logic_string.replace("CHEST_KEY:0-5", "{ CHEST_KEY:0 && CHEST_KEY:1 && CHEST_KEY:2 && CHEST_KEY:3 && CHEST_KEY:4 && CHEST_KEY:5 }")
	logic_string = logic_string.replace("Find Mel && Mel Freed", "Mel Freed").replace("Mel Freed", "Find Mel && Mel Freed")
	logic_string = logic_string.replace("1 Scrapling", "{ Find Sin || Find Cos || Find Tan }")
	logic_string = logic_string.replace("2 Scraplings", "{ { Find Sin && Find Cos } || { Find Sin && Find Tan } || { Find Cos && Find Tan } }")
	logic_string = logic_string.replace("3 Scraplings", "{ Find Sin && Find Cos && Find Tan }")
	logic_string = logic_string.replace("attack", "{ slash || { hairpin && TRINKET:CARLO_HOOK } || { hairpin && TRINKET:DECOY } || { sail && TRINKET:GLIDE_STATIC } }") # TODO
	
	return logic_string


static func parse_logic(logic_string: String, node: Node) -> Callable:
	var logic_list: Array[Callable]
	var edited_string: String = logic_string
	if not edited_string.is_empty():
		edited_string = trim_redundant_parentheses(edited_string)
	
	if not node.is_inside_tree():
		await node.tree_entered
	var state: Main.PlayerState = Globals.main.player_state
	
	while edited_string.contains("{"):
		var right_brace_pos: int = edited_string.find("}")
		var left_brace_pos: int = edited_string.left(right_brace_pos + 1).rfind("{")
		var section = edited_string.substr(left_brace_pos + 2, right_brace_pos - left_brace_pos - 3)
		var converted = convert_item_text(section, node)
		var current_logic: Callable
		if converted.contains("&&") and converted.contains("||"):
			var at: String
			if node is LocationPanel:
				at = Main.PlayerState.serialize_location(node)
			elif node is TransitionPanel:
				at = node.from + " -> " + node.to
			printerr("Invalid logic: %s @ %s" % [logic_string, at])
		if converted.contains("&&"):
			var hases: Array[Callable] = []
			for i in converted.split(" && "):
				if i.contains("@"):
					hases.append(logic_list[i.substr(i.find("@")).to_int()])
					continue
				hases.append(state.has_call(i))
			current_logic = state.and_call(hases)
		elif converted.contains("||"):
			var hases: Array[Callable] = []
			for i in converted.split(" || "):
				if i.contains("@"):
					hases.append(logic_list[i.substr(i.find("@")).to_int()])
					continue
				hases.append(state.has_call(i))
			current_logic = state.or_call(hases)
		else:
			break
		
		edited_string = edited_string.replace("{ " + section + " }", "@" + str(logic_list.size()))
		logic_list.append(current_logic)
	
	var last_converted = convert_item_text(edited_string, node)
	var last_logic: Callable
	if last_converted.contains("&&") and last_converted.contains("||"):
		var at: String
		if node is LocationPanel:
			at = Main.PlayerState.serialize_location(node)
		elif node is TransitionPanel:
			at = node.from + " -> " + node.to
		printerr("Invalid logic: %s @ %s" % [logic_string, at])
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
	
	return last_logic


static func convert_item_text(text: String, node: Node) -> String:
	for i in node.get_node("/root/Main").items_sheet:
		if text.contains(i[6]):
			if text.split(" ").has(i[6]):
				text = text.replace(i[6], i[0]) 
	
	for i in ["slash", "hairpin", "dodge", "sail", "harvester", "striders", "slingshot", "flowing_steps"]:
		text = text.replace(i, i.capitalize())
	return text


static func trim_redundant_parentheses(text: String) -> String:
	if text[0] != "{":
		return text
	
	var amount := 0
	
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

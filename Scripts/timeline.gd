class_name Timeline extends PanelContainer


var timeline_name: String:
	set(v):
		timeline_name = v
		$V/Name.text = v


func _init(t_name: String = "", start: String = Globals.STARTING_LOC_LIST[0]) -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var v_box := VBoxContainer.new()
	v_box.name = &"V"
	add_child(v_box)
	
	var name_label := Label.new()
	name_label.name = &"Name"
	name_label.add_theme_font_size_override("font_size", 20)
	v_box.add_child(name_label)
	
	var seperator := HSeparator.new()
	v_box.add_child(seperator)
	
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 200
	scroll.name = &"S"
	v_box.add_child(scroll)
	
	var h_box := HBoxContainer.new()
	h_box.name = &"H"
	h_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(h_box)
	
	add_object(TimelineObject.TimelineStart.new(start))
	
	timeline_name = t_name


func add_object(obj: TimelineObject) -> void:
	if not is_inside_tree():
		await tree_entered
	
	$"V/S/H".add_child(obj)

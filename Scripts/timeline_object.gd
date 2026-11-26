class_name TimelineObject extends PanelContainer


var main_display: String:
	set(v):
		main_display = v
		$V/Display.text = main_display

var icon: Texture2D:
	set(v):
		icon = v
		$V/Icon.texture = v


func _init() -> void:
	custom_minimum_size = Vector2.ONE * 200
	
	var v_box := VBoxContainer.new()
	v_box.name = &"V"
	add_child(v_box)
	
	var label := Label.new()
	label.text = main_display
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.name = &"Display"
	v_box.add_child(label)
	
	var texture := TextureRect.new()
	texture.name = &"Icon"
	texture.custom_minimum_size.y = 140
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v_box.add_child(texture)
	
	main_display = main_display


class TimelineStart extends TimelineObject:
	
	var room_id: String:
		set(v):
			room_id = v
			if $V/Room.get_item_text($V/Room.selected) != v:
				for i in range($V/Room.item_count):
					if $V/Room.get_item_text(i) == v:
						$V/Room.select(i)
						break
	
	
	func _init(room: String = Globals.STARTING_LOC_LIST[0]):
		super()
		
		var option := OptionButton.new()
		var ref_option: OptionButton = Globals.main.get_node("TabContainer/PlayerState/ControlPanel/ScrollContainer/VBoxContainer/HBoxContainer/StartingLocation")
		for i in range(ref_option.item_count):
			if i == 0:
				continue
			var current_text = ref_option.get_item_text(i)
			option.add_item(current_text)
			if current_text == room:
				option.select(i - 1)
		option.item_selected.connect(func(idx: int): room_id = option.get_item_text(idx))
		option.add_theme_font_size_override("font_size", 12)
		option.name = &"Room"
		$V.add_child(option)
		$V.move_child(option, 1)
		
		main_display = "Start in:"
		room_id = room
		icon = preload("res://Sprites/map-icons/MAP_CHECKPOINT.png")

extends PanelContainer


@onready var filter_nodes: Array[Control] = [$VBoxContainer/Operations/ScrollContainer/VBoxContainer/Search, $VBoxContainer/Operations/ScrollContainer/VBoxContainer/EntryOption]


func _ready() -> void:
	filter_nodes.append_array($VBoxContainer/Operations/ScrollContainer/VBoxContainer/Filters/Box/Simple.get_children())
	for i in filter_nodes:
		if i is OptionButton:
			i.item_selected.connect(update_search.unbind(1))
		elif i is LineEdit:
			i.text_changed.connect(update_search.unbind(1))
	$VBoxContainer/Operations/ScrollContainer/VBoxContainer/Filters/Box/CategoryFilter/ToggleGrid.toggle_toggled.connect(update_search.unbind(2))
	$VBoxContainer/Operations/ScrollContainer/VBoxContainer/Sort.item_selected.connect(update_sort.unbind(1))
	$VBoxContainer/Operations/ScrollContainer/VBoxContainer/ReverseSort.toggled.connect(update_sort.unbind(1))
	$VBoxContainer/Operations/ScrollContainer/VBoxContainer/MapTo.item_selected.connect(update_mappings.unbind(1))
	Archipelago.connected.connect(func(c: ConnectionInfo, _j: Dictionary): await get_tree().process_frame; c.obtained_item.connect(update_sort.unbind(1)))


func _process(_delta: float) -> void:
	$VBoxContainer/Operations/ScrollContainer.custom_minimum_size.y = clamp($VBoxContainer/Operations/ScrollContainer/VBoxContainer.get_global_rect().size.y, 0, get_viewport_rect().size.y / 2)


func update_search() -> void:
	for i: Item in %ItemPool.get_children():
		i.show()
		
		if not $VBoxContainer/Operations/ScrollContainer/VBoxContainer/Search.text.is_empty():
			match $VBoxContainer/Operations/ScrollContainer/VBoxContainer/EntryOption.selected:
				0:
					if not i.item_name.containsn($VBoxContainer/Operations/ScrollContainer/VBoxContainer/Search.text):
						i.hide()
				1:
					if not i.save_entry.containsn($VBoxContainer/Operations/ScrollContainer/VBoxContainer/Search.text):
						i.hide()
				2:
					if not i.room.containsn($VBoxContainer/Operations/ScrollContainer/VBoxContainer/Search.text):
						i.hide()
		
		match $VBoxContainer/Operations/ScrollContainer/VBoxContainer/Filters/Box/Simple/TypeOption.selected:
			1:
				if i.type != Item.ItemTypes.ITEM:
					i.hide()
			2:
				if i.type != Item.ItemTypes.EVENT:
					i.hide()
		
		if $VBoxContainer/Operations/ScrollContainer/VBoxContainer/Filters/Box/Simple/ClassOption.selected > 0:
			if i.classification != $VBoxContainer/Operations/ScrollContainer/VBoxContainer/Filters/Box/Simple/ClassOption.selected - 1:
				i.hide()
		
		match $VBoxContainer/Operations/ScrollContainer/VBoxContainer/Filters/Box/Simple/HasButton.selected:
			1:
				if not Globals.main.player_state.prog_items.has(i.item_name):
					i.hide()
			2:
				if Globals.main.player_state.prog_items.has(i.item_name):
					i.hide()
		
		match $VBoxContainer/Operations/ScrollContainer/VBoxContainer/Filters/Box/Simple/APHasButton.selected:
			1:
				if not Globals.main.player_state.ap_prog_items.has(i.item_name):
					i.hide()
			2:
				if Globals.ap_items_recieved_this_session.has(i.item_name):
					i.hide()
				if not Globals.main.player_state.ap_prog_items.has(i.item_name):
					i.hide()
			3:
				if not Globals.ap_items_recieved_this_session.has(i.item_name):
					i.hide()
			4:
				if Globals.main.player_state.ap_prog_items.has(i.item_name):
					i.hide()
		
		if $VBoxContainer/Operations/ScrollContainer/VBoxContainer/Filters/Box/Simple/CategoryOption.selected > 0:
			if i.category != $VBoxContainer/Operations/ScrollContainer/VBoxContainer/Filters/Box/Simple/CategoryOption.get_item_text($VBoxContainer/Operations/ScrollContainer/VBoxContainer/Filters/Box/Simple/CategoryOption.selected):
				i.hide()
		
		if not i.category in $VBoxContainer/Operations/ScrollContainer/VBoxContainer/Filters/Box/CategoryFilter/ToggleGrid.get_toggled_toggles():
			i.hide()


func update_sort() -> void:
	var all_items: Array[Item]
	for i: Item in %ItemPool.get_children():
		all_items.append(i)
	
	var logic := Callable()
	
	match $VBoxContainer/Operations/ScrollContainer/VBoxContainer/Sort.selected:
		0:
			var order: Array[String]
			var skip_first := true
			for i in Globals.main.items_sheet:
				if skip_first:
					skip_first = false
					continue
				order.append(i[0])
			logic = func(x: Item, y: Item): 
				return order.find(x.item_name) < order.find(y.item_name)
		1:
			if Archipelago.is_ap_connected():
				var order: Array[String]
				for i: NetworkItem in Archipelago.conn.received_items:
					if Globals.is_manual:
						order.append(Main.PlayerState.convert_from_manual_item(i.get_name()))
					else:
						order.append(i.get_name())
				logic = func(x: Item, y: Item): 
					var x_val: int = order.find(x.item_name)
					var y_val: int = order.find(y.item_name)
					if x_val == -1:
						x_val = order.size()
					if y_val == -1:
						y_val = order.size()
					return x_val < y_val
		2:
			logic = func(x: Item, y: Item): return x.item_name < y.item_name
	
	if logic != Callable():
		if $VBoxContainer/Operations/ScrollContainer/VBoxContainer/ReverseSort.button_pressed:
			all_items.sort_custom(func(x: Item, y: Item): return not logic.call(x, y))
		else:
			all_items.sort_custom(logic)
	else:
		return
	
	for i: Item in all_items:
		%ItemPool.remove_child(i)
		%ItemPool.add_child(i)


func update_mappings() -> void:
	var logic: Callable
	match $VBoxContainer/Operations/ScrollContainer/VBoxContainer/MapTo.selected:
		0:
			logic = func(e: Item): return e.item_name
		1:
			logic = func(e: Item): return e.save_entry
	for i: Item in %ItemPool.get_children():
		i.get_node("Name").text = logic.call(i)

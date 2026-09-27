extends PanelContainer


@onready var filter_nodes: Array[Control] = [$VBoxContainer/Search, $VBoxContainer/EntryOption]


func _ready() -> void:
	filter_nodes.append_array($VBoxContainer/Filters.get_children())
	for i in filter_nodes:
		if i is OptionButton:
			i.item_selected.connect(update_search.unbind(1))
		elif i is LineEdit:
			i.text_changed.connect(update_search.unbind(1))


func update_search() -> void:
	for i: Item in %ItemPool.get_children():
		i.show()
		
		if not $VBoxContainer/Search.text.is_empty():
			match $VBoxContainer/EntryOption.selected:
				0:
					if not i.item_name.containsn($VBoxContainer/Search.text):
						i.hide()
				1:
					if not i.save_entry.containsn($VBoxContainer/Search.text):
						i.hide()
				2:
					if not i.room.containsn($VBoxContainer/Search.text):
						i.hide()
		
		match $VBoxContainer/Filters/TypeOption.selected:
			1:
				if i.type != Item.ItemTypes.ITEM:
					i.hide()
			2:
				if i.type != Item.ItemTypes.EVENT:
					i.hide()
		
		if $VBoxContainer/Filters/ClassOption.selected > 0:
			if i.classification != $VBoxContainer/Filters/ClassOption.selected - 1:
				i.hide()
		
		match $VBoxContainer/Filters/HasButton.selected:
			1:
				if not Globals.main.player_state.prog_items.has(i.item_name):
					i.hide()
			2:
				if Globals.main.player_state.prog_items.has(i.item_name):
					i.hide()
		
		match $VBoxContainer/Filters/APHasButton.selected:
			1:
				if not Globals.main.player_state.ap_prog_items.has(i.item_name):
					i.hide()
			2:
				if Globals.main.player_state.ap_prog_items.has(i.item_name):
					i.hide()
		
		if $VBoxContainer/Filters/CategoryOption.selected > 0:
			if i.category != $VBoxContainer/Filters/CategoryOption.get_item_text($VBoxContainer/Filters/CategoryOption.selected):
				i.hide()

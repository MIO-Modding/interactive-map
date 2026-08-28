extends PanelContainer


func _on_search_text_changed(_new_text: String) -> void:
	update_search()


func _on_entry_option_item_selected(_index: int) -> void:
	update_search()


func _on_type_option_item_selected(_index: int) -> void:
	update_search()


func _on_class_option_item_selected(_index: int) -> void:
	update_search()


func _on_option_button_item_selected(_index: int) -> void:
	update_search()


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
				if not get_node("/root/Main").player_state.prog_items.has(i.item_name):
					hide()
			2:
				if get_node("/root/Main").player_state.prog_items.has(i.item_name):
					hide()

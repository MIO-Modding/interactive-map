extends Control


func _ready() -> void:
	await get_tree().process_frame
	$VBoxContainer/Tabs/Main.update()


func select_tab(tab: int) -> void:
	assert($VBoxContainer/Tabs.get_child_count() > 0)
	
	for i in $VBoxContainer/Tabs.get_children():
		i.hide()
	$VBoxContainer/Tabs.get_child(tab).show()


func close_tab(tab: int) -> void:
	assert($VBoxContainer/Tabs.get_child_count() > 0)
	
	$VBoxContainer/Tabs.get_child(tab).queue_free()
	$VBoxContainer/TabBar.remove_tab(tab)
	
	if $VBoxContainer/Tabs.get_child_count() <= 0:
		var page := InfoPage.new()
		page.name = "Main"
		page.text = """
#### Info Tab
This is the main page for the Information Tab, a section of this tool that lets you see info about features in a wiki-like way.
This feature is in no way finished."""
		add_page_node(page)
	
	select_tab(tab - 1)
	

func add_page(feature_info: FeaturePanel) -> void:
	add_page_node(create_page(feature_info))
	var index: int = $VBoxContainer/Tabs.get_child_count() - 1
	$VBoxContainer/TabBar.current_tab = index
	select_tab(index)


func create_page(feature_info: FeaturePanel) -> InfoPage:
	var result = InfoPage.new()
	result.text = feature_info.get_wikitext()
	result.name = feature_info.get_pagename()
	result.feature_panel = feature_info
	return result


func add_page_node(page: InfoPage) -> void:
	$VBoxContainer/TabBar.add_tab(str(page.name))
	$VBoxContainer/Tabs.add_child(page)
	page.update()

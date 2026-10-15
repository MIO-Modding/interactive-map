class_name InfoManager extends Control


func _ready() -> void:
	await get_tree().process_frame
	$VBoxContainer/Tabs/Main.text = load_page("Main")
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
	
	if $VBoxContainer/Tabs.get_child_count() <= 1:
		add_page_node(make_new_page_from_file("Main"))
	
	select_tab(tab - 1)


func add_page(feature_info: FeaturePanel) -> void:
	add_page_node(await create_page(feature_info))
	select_last_page()


func select_last_page() -> void:
	var index: int = $VBoxContainer/Tabs.get_child_count() - 1
	$VBoxContainer/TabBar.current_tab = index
	select_tab(index)
	get_parent().current_tab = get_index()


func create_page(feature_info: FeaturePanel) -> InfoPage:
	if feature_info == null:
		return null
	var result = InfoPage.new()
	@warning_ignore("redundant_await")
	result.text = await feature_info.get_wikitext()
	@warning_ignore("redundant_await")
	result.name = await feature_info.get_pagename()
	result.feature_panel = feature_info
	return result


func add_page_node(page: InfoPage) -> void:
	$VBoxContainer/TabBar.add_tab(str(page.name))
	$VBoxContainer/Tabs.add_child(page)
	page.update()


func add_page_node_and_select(page: InfoPage) -> void:
	add_page_node(page)
	select_last_page()


static func load_page(page_name: String) -> String:
	var path: String = "res://Speeches/InfoPages/%s.md" % page_name.to_snake_case()
	if FileAccess.file_exists(path):
		return FileAccess.open(path, FileAccess.READ).get_as_text()
	return ""


static func make_new_page_from_file(page_name: String) -> InfoPage:
	var page := InfoPage.new()
	page.name = page_name
	page.text = load_page(page_name)
	return page

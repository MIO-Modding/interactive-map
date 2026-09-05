@tool
class_name InfoPage extends ScrollContainer


@export_multiline() var text: String:
	set(v):
		text = v
		if is_inside_tree():
			if get_child_count() > 0:
				$Text.markdown_text = v


var feature_panel: FeaturePanel


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if is_inside_tree():
		if get_child_count() > 0:
			return
	var scene: ScrollContainer = preload("res://Scenes/info_page.tscn").instantiate()
	for i in scene.get_children():
		scene.remove_child(i)
		i.owner = null
		add_child(i)
		i.owner = self


func update() -> void:
	$Text.markdown_text = text


func repull_data() -> void:
	var temp_text: String = feature_panel.get_wikitext()
	if not temp_text.is_empty():
		text = temp_text
	var temp_name: String = feature_panel.get_pagename()
	if not temp_name.is_empty():
		name = temp_name

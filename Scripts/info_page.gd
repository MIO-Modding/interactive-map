@tool
class_name InfoPage extends ScrollContainer


@export_multiline() var text: String:
	set(v):
		text = v
		if is_inside_tree():
			if get_child_count() > 0:
				$Text.markdown_text = v


func _init() -> void:
	if is_inside_tree():
		if get_child_count() > 0:
			return
	var scene: ScrollContainer = preload("res://Scenes/info_page.tscn").instantiate()
	for i in scene.get_children():
		scene.remove_child(i)
		i.owner = null
		add_child(i)
		i.owner = self

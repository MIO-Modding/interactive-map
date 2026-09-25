extends PanelContainer


func _process(_delta: float) -> void:
	var node: Control = get_parent().get_parent().get_parent()
	custom_minimum_size = Vector2.ONE * floor((min(node.size.x, node.size.y) - 16) / 5.0) 

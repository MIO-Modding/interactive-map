extends Control


@onready var map_node: Node2D = $SubViewportContainer/SubViewport/Node2D


func _process(_delta: float) -> void:
	var viewport_size := get_viewport_rect().size
	$SubViewportContainer/SubViewport.size = viewport_size - Vector2(0, 31)
	$ScrollContainer.size.x = viewport_size.x
	$ScrollContainer/PanelContainer.custom_minimum_size.x = viewport_size.x
	
	map_node.get_node("Camera2D").zoom = map_node.get_node("Camera2D").zoom.clamp(Vector2(0.5, 0.5), Vector2(20, 20))
	$"ZoomBox/+".disabled = map_node.get_node("Camera2D").zoom >= Vector2(20, 20)
	$"ZoomBox/-".disabled = map_node.get_node("Camera2D").zoom <= Vector2(0.5, 0.5)


func _on_room_points_toggled(toggled_on: bool) -> void:
	map_node.get_node("Points").visible = toggled_on


func _on_transitions_toggled(toggled_on: bool) -> void:
	map_node.get_node("Lines").visible = toggled_on


func _on_plus_pressed() -> void:
	map_node.get_node("Camera2D").zoom *= 1.1


func _on_minus_pressed() -> void:
	map_node.get_node("Camera2D").zoom /= 1.1


func _on_reset_pressed() -> void:
	map_node.get_node("Camera2D").zoom = Vector2.ONE

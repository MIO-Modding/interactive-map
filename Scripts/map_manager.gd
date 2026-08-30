extends Control


@onready var map_node: Node2D = $SubViewportContainer/SubViewport/Node2D


func _process(_delta: float) -> void:
	var viewport_size := get_viewport_rect().size
	$SubViewportContainer/SubViewport.size = viewport_size - Vector2(0, 31)
	$ScrollContainer.size.x = viewport_size.x
	$ScrollContainer/PanelContainer.custom_minimum_size.x = viewport_size.x


func _on_room_points_toggled(toggled_on: bool) -> void:
	map_node.get_node("Points").visible = toggled_on


func _on_transitions_toggled(toggled_on: bool) -> void:
	map_node.get_node("Lines").visible = toggled_on

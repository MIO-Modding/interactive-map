extends Control


@onready var map_node: Node2D = $SubViewportContainer/SubViewport/Node2D


func _on_room_points_toggled(toggled_on: bool) -> void:
	map_node.get_node("Points").visible = toggled_on


func _on_transitions_toggled(toggled_on: bool) -> void:
	map_node.get_node("Lines").visible = toggled_on

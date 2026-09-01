@tool
class_name Vector2iBox extends HBoxContainer


@export var text: String:
	set(value):
		text = value
		if is_inside_tree():
			if get_child_count() > 0:
				$Label.text = value
				$Label.visible = not value.is_empty()
@export var editable := true:
	set(value):
		editable = value
		if is_inside_tree():
			if get_child_count() > 0:
				$XSpin.editable = value
				$YSpin.editable = value

@export var minimums := Vector2i(-4000, 0):
	set(value):
		minimums = value
		if is_inside_tree():
			if get_child_count() > 0:
				$XSpin.min_value = value.x
				$YSpin.min_value = value.y
@export var maximums := Vector2i(1000, 3000):
	set(value):
		maximums = value
		if is_inside_tree():
			if get_child_count() > 0:
				$XSpin.max_value = value.x
				$YSpin.max_value = value.y
@export var values: Vector2i:
	set(value):
		values = Vector2i(clampi(value.x, minimums.x, maximums.x), clampi(value.y, minimums.y, maximums.y))
		value_changed.emit(values)
		if is_inside_tree():
			if get_child_count() > 0:
				$XSpin.value = value.x
				$YSpin.value = value.y

signal value_changed(new_value: Vector2i)


func _init() -> void:
	if not is_inside_tree():
		await tree_entered
	if get_child_count() <= 0:
		for child in preload("res://Scenes/vector_2i_box.tscn").instantiate().get_children():
			child.get_parent().remove_child(child)
			child.owner = null
			add_child(child)
			child.owner = self
	text = text
	editable = editable
	minimums = minimums
	maximums = maximums
	values = values
	$XSpin.value_changed.connect(func(e): values.x = roundi(e))
	$YSpin.value_changed.connect(func(e): values.y = roundi(e))

@tool
class_name ToggleGrid extends GridContainer


@export_tool_button("Update") var update_button: Callable = update

@export var all_toggles: Dictionary[String, bool]:
	set(v):
		all_toggles = v
		update()

@export var toggle_for_all_default_value: bool

@export var toggle_for_all: bool:
	set(v):
		toggle_for_all = v
		if not v:
			if all_toggles.has("All"):
				all_toggles.erase("All")
		elif not all_toggles.has("All"):
			all_toggles["All"] = toggle_for_all_default_value
		update()
		if v:
			set_toggle_value("All", toggle_for_all_default_value)

signal toggle_toggled(toggle: String, toggled_on: bool)


func _ready() -> void:
	toggle_toggled.connect(func(t, v): all_toggles[t] = v)
	toggle_toggled.connect(func(t, v): if t == "All" and toggle_for_all: set_toggled_toggles(v))
	toggle_for_all = toggle_for_all


func update() -> void:
	@warning_ignore("static_called_on_instance")
	for i in get_children():
		i.queue_free()
	for i in all_toggles:
		add_toggle(i, all_toggles[i])


func add_toggle(t_name: String, value: bool) -> void:
	all_toggles[t_name] = value
	var toggle := CheckButton.new()
	toggle.button_pressed = value
	toggle.text = t_name
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle.toggled.connect(func(t): toggle_toggled.emit(t_name, t))
	add_child(toggle)


func set_toggle_value(t_name: String, value: bool) -> void:
	_get_toggle_node(t_name).button_pressed = value


func get_toggle_value(t_name: String) -> bool:
	return _get_toggle_node(t_name).button_pressed


func set_toggled_toggles(on: bool) -> void:
	for i in all_toggles:
		all_toggles[i] = on
		set_toggle_value(i, on)


func get_toggled_toggles(on := true) -> Array[String]:
	var result: Array[String]
	for i in all_toggles:
		if all_toggles[i] == on:
			result.append(i)
	return result


func _get_toggle_node(t_name: String) -> CheckButton:
	for i: CheckButton in get_children():
		if i.text == t_name:
			return i
	return null

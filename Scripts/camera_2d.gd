extends Camera2D


var pos_last_frame: Vector2


func _ready() -> void:
	pos_last_frame = get_viewport().get_mouse_position()


func _process(_delta: float) -> void:
	var previous_zoom: Vector2 = zoom
	
	if is_visible_in_tree():
		if get_viewport().get_mouse_position().y < get_viewport_rect().size.y - 130:
			if Input.is_action_just_released("scroll_up"):
				zoom *= 1.1
			if Input.is_action_just_released("scroll_down"):
				zoom /= 1.1
			zoom = zoom.clamp(Vector2(0.5, 0.5), Vector2(20, 20))
			
			if zoom != previous_zoom:
				position = get_global_mouse_position() - ((get_global_mouse_position() - position) * (previous_zoom / zoom))
			
			if Input.is_action_just_pressed("mouse1"):
				run_click()
				pos_last_frame = get_viewport().get_mouse_position()
			if Input.is_action_pressed("mouse1"):
				position = position + (pos_last_frame - get_viewport().get_mouse_position())
				pos_last_frame = get_viewport().get_mouse_position()


func run_click() -> void:
	var closest_point := find_closest_point()
	if closest_point != null:
		get_node("/root/Main").point_clicked(closest_point)
		return
	var closest_line := find_closest_line()
	if closest_line != null:
		get_node("/root/Main").line_clicked(closest_line)
		return


func find_closest_point() -> Polygon2D:
	var mouse_pos := get_global_mouse_position()
	var closest_point: Polygon2D = null
	var closest_dist: float = -1.0
	
	for i: Polygon2D in $"../Points".get_children():
		if not i.is_visible_in_tree():
			continue
		
		var dist: float = i.position.distance_to(mouse_pos)
		if dist < 2 and (dist < closest_dist or closest_dist == -1.0):
			closest_point = i
			closest_dist = dist
	
	return closest_point


func find_closest_line() -> TransitionLine:
	var mouse_pos := get_global_mouse_position()
	var closest_line: TransitionLine = null
	var closest_dist: float = -1.0
	
	for i: TransitionLine in $"../Lines".get_children():
		if not i.is_visible_in_tree():
			continue
		if i.points.size() < 2:
			continue
		if i.points[0] == i.points[1]:
			printerr("Equal transition line points (%s)" % str(i.points[0]))
			continue
		var dist = distance_to_line(mouse_pos, i.points[0], i.points[1])
		if dist > 2:
			continue
		if dist < closest_dist or closest_dist == -1.0:
			closest_dist = dist
			closest_line = i
	return closest_line


static func distance_to_line(point: Vector2, end1: Vector2, end2: Vector2) -> float:
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, end1, end2))

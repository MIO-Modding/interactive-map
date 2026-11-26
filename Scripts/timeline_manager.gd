extends Control


func add_timeline(timeline: Timeline) -> void:
	$VBoxContainer/ScrollContainer/VBoxContainer.add_child(timeline)


func get_new_timeline_name() -> String:
	var all_names: Array[String]
	for tline in get_timelines():
		all_names.append(tline.timeline_name)
	var current: int = 1
	while ("Timeline " + str(current)) in all_names:
		current += 1
	return "Timeline " + str(current)


func get_timelines() -> Array[Timeline]:
	var result: Array[Timeline]
	result.assign($VBoxContainer/ScrollContainer/VBoxContainer.get_children())
	return result


func new_timeline() -> void:
	add_timeline(Timeline.new(get_new_timeline_name()))

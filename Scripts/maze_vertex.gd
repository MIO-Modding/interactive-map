class_name MazeVertex extends Resource


enum VertexType {
	ENTRANCE,
	EXIT,
	CORNER,
	SPLIT,
	DEAD_END
}

static var all_mazes: Dictionary[String, Array]

var maze: String
var vertex_id: String
var from_vertex_id: String
var region_name: String
var room_id: String
var type: VertexType
var coords: Vector2
var background: bool
var notes: String


func get_from_vertex() -> MazeVertex:
	assert(all_mazes.has(maze))
	for vertex: MazeVertex in all_mazes[maze]:
		if vertex.vertex_id == from_vertex_id:
			return vertex
	return null


class VertexNode extends Polygon2D:
	
	var vertex: MazeVertex
	
	
	func update() -> void:
		pass


class MazeSegmentNode extends Line2D:
	
	var from_vertex: MazeVertex
	var to_vertex: MazeVertex:
		set(v):
			to_vertex = v
			from_vertex = to_vertex.get_from_vertex()
			update()
	
	
	func _init() -> void:
		width = 0.5
	
	
	func update() -> void:
		clear_points()
		add_point(from_vertex.coords / 5 * Vector2(1, -1))
		add_point(to_vertex.coords / 5 * Vector2(1, -1))

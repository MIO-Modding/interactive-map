class_name TypeInfer
extends RefCounted
## Excel 导表工具 M2 —— 列类型推断 + 值规范化。
##
## 推断顺序（对每列的「去空格后的非空单元格」）：
##   1) 用户显式覆盖 overrides{ 列名: 类型 } 优先；
##   2) 全部 is_valid_int()                               -> int
##   3) 全部 is_valid_float()（含小数/科学计数）           -> float
##   4) 全部为 true/false（不区分大小写）                  -> bool
##   5) 全部为 "x,y" 两段数字                              -> Vector2
##   6) 全部为 "x,y,z" 三段数字                            -> Vector3
##   7) 全部按分隔符(默认逗号)拆分 >= 2 段                 -> Array(elem_type)
##   8) 全部以 res:// 开头                                 -> Resource
##   9) 去重后值少且均为标识符                             -> enum(values)
##  10) 其余                                              -> String
##
## coerce()：按推断类型把原始字符串转成实际 Variant（M3 写 .tres / 读表代码用）。

const T_INT := "int"
const T_FLOAT := "float"
const T_STRING := "String"
const T_BOOL := "bool"
const T_VECTOR2 := "Vector2"
const T_VECTOR3 := "Vector3"
const T_ARRAY := "Array"
const T_ENUM := "enum"
const T_RESOURCE := "Resource"

const ARRAY_DELIM := ","
const MAX_ENUM := 8


## 全表推断。返回 {ok: true, columns: [ {name, type, elem_type?, has_empty, ...} ]}
static func infer(headers: Array, rows: Array, overrides := {}) -> Dictionary:
	var columns: Array = []
	for ci in headers.size():
		var cells: Array = []
		for row in rows:
			var val: Variant = row[ci] if ci < row.size() else ""
			cells.append(val)
		var name := _norm(headers[ci])
		var override := ""
		if overrides.has(name):
			override = _norm(overrides[name])
		columns.append(infer_column(name, cells, override))
	return {"ok": true, "columns": columns}


## 单列推断。
static func infer_column(name: String, cells: Array, override := "") -> Dictionary:
	var meta := {
		"name": name,
		"type": T_STRING,
		"elem_type": "",
		"has_empty": false,
		"distinct": 0,
		"values": [],
	}
	var non_empty: Array = []
	for c in cells:
		var s := _norm(c)
		if s == "":
			meta["has_empty"] = true
			continue
		non_empty.append(s)

	if override != "":
		meta["type"] = override
		meta["override"] = true
		return meta
	if non_empty.is_empty():
		return meta

	if _all_bool(non_empty):
		meta["type"] = T_BOOL
		return meta
	if _all_int(non_empty):
		meta["type"] = T_INT
		return meta
	if _all_float(non_empty):
		meta["type"] = T_FLOAT
		return meta
	if _all_vec(non_empty, 3):
		meta["type"] = T_VECTOR3
		return meta
	if _all_vec(non_empty, 2):
		meta["type"] = T_VECTOR2
		return meta
	if _all_array(non_empty):
		meta["type"] = T_ARRAY
		meta["elem_type"] = _array_elem_type(non_empty)
		meta["delim"] = ARRAY_DELIM
		return meta
	if _all_resource(non_empty):
		meta["type"] = T_RESOURCE
		return meta
	# 枚举启发式：去重后值少且均为标识符
	var distinct := _distinct(non_empty)
	if distinct.size() > 0 and distinct.size() <= MAX_ENUM and _all_identifier(distinct):
		meta["type"] = T_ENUM
	meta["distinct"] = distinct.size()
	meta["values"] = distinct
	return meta


## 按类型把原始值规范化为实际 Variant。
static func coerce(type_name: String, raw: Variant, elem_type := "", delim := ARRAY_DELIM) -> Variant:
	var s := _norm(raw)
	match type_name:
		T_INT:
			return s.to_int()
		T_FLOAT:
			return s.to_float()
		T_BOOL:
			return s.to_lower() == "true"
		T_VECTOR2:
			return _mk_vec(s, 2)
		T_VECTOR3:
			return _mk_vec(s, 3)
		T_ARRAY:
			return _mk_array(s, elem_type, delim)
		_:
			return s


# ---------------- 内部工具 ----------------

static func _norm(v: Variant) -> String:
	if v is String:
		return (v as String).strip_edges()
	return str(v).strip_edges()


static func _all_bool(cells: Array) -> bool:
	for s in cells:
		var t: String = String(s).to_lower()
		if t != "true" and t != "false":
			return false
	return true


static func _all_int(cells: Array) -> bool:
	for s in cells:
		if not s.is_valid_int():
			return false
	return true


static func _all_float(cells: Array) -> bool:
	for s in cells:
		if not s.is_valid_float():
			return false
	return true


static func _all_vec(cells: Array, n: int) -> bool:
	for s in cells:
		if _num_parts(s, n) < 0:
			return false
	return true


## 返回 -1 表示不是恰好 n 段数字；否则返回段数。
static func _num_parts(s: String, n: int) -> int:
	var parts := s.split(ARRAY_DELIM, false)
	if parts.size() != n:
		return -1
	for part in parts:
		var p := part.strip_edges()
		if not p.is_valid_float():
			return -1
	return parts.size()


static func _mk_vec(s: String, n: int) -> Variant:
	var parts := s.split(ARRAY_DELIM, false)
	if n == 3:
		return Vector3(
			parts[0].strip_edges().to_float(),
			parts[1].strip_edges().to_float(),
			parts[2].strip_edges().to_float())
	var limit := parts.size() if parts.size() < 2 else 2
	var x := parts[0].strip_edges().to_float() if limit >= 1 else 0.0
	var y := parts[1].strip_edges().to_float() if limit >= 2 else 0.0
	return Vector2(x, y)


static func _all_array(cells: Array) -> bool:
	for s in cells:
		var parts: PackedStringArray = String(s).split(ARRAY_DELIM, false)
		if parts.size() < 2:
			return false
	return true


static func _array_elem_type(cells: Array) -> String:
	# 收集所有元素做标量分类
	var collected: Array = []
	for s in cells:
		for part in s.split(ARRAY_DELIM, false):
			collected.append(part.strip_edges())
	if _all_bool(collected):
		return T_BOOL
	if _all_int(collected):
		return T_INT
	if _all_float(collected):
		return T_FLOAT
	if _all_resource(collected):
		return T_RESOURCE
	return T_STRING


static func _mk_array(s: String, elem_type: String, delim: String) -> Array:
	var out: Array = []
	for part in s.split(delim, false):
		var p := part.strip_edges()
		out.append(coerce(elem_type, p) if elem_type != "" else p)
	return out


static func _all_resource(cells: Array) -> bool:
	for s in cells:
		if not s.begins_with("res://"):
			return false
	return true


static func _distinct(cells: Array) -> Array:
	var out: Array = []
	for s in cells:
		if not out.has(s):
			out.append(s)
	return out


static func _all_identifier(vals: Array) -> bool:
	for v in vals:
		if not _is_identifier(v):
			return false
	return true


static func _is_identifier(s: String) -> bool:
	if s.is_empty():
		return false
	var first := s[0]
	if not ((first >= "a" and first <= "z") or (first >= "A" and first <= "Z") or first == "_"):
		return false
	for i in range(1, s.length()):
		var ch := s[i]
		if not ((ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "_"):
			return false
	return true

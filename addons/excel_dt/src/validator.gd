class_name Validator
extends RefCounted
## Excel 导表工具 M2 —— 数据校验。
##
## 校验项：
##   1) 必填列空值（required_columns，可配置；默认 = ID 列）
##   2) 同列类型不一致（基于 TypeInfer 推断类型 / 用户覆盖类型）
##   3) ID 列重复
##
## 错误定位：
##   row      —— 数据行号（从 1 起，不含表头行）
##   col      —— 列号（从 1 起）
##   col_name —— 列名
##
## validate() 返回 {ok: bool, error_count: int, errors: [Dictionary, ...]}

const TypeInferScript := preload("type_infer.gd")


static func validate(headers: Array, rows: Array, inferred: Dictionary, opts := {}) -> Dictionary:
	var errors: Array = []
	var id_column: int = int(opts.get("id_column", 0))
	var required: Array = opts.get("required_columns", [])
	if required.is_empty():
		required = [id_column]

	var columns: Array = inferred.get("columns", [])

	# ---- 1) 必填列空值 ----
	for ci in required:
		var cname := _col_name(headers, ci)
		for ri in rows.size():
			var cell := _cell(rows, ri, ci)
			if _blank(cell):
				errors.append({
					"type": "required",
					"row": ri + 1,
					"col": ci + 1,
					"col_name": cname,
					"message": "列 %s 数据行 %d 的必填值为空" % [cname, ri + 1],
				})

	# ---- 2) 类型一致性 ----
	for ci in columns.size():
		if ci >= headers.size():
			break
		var meta: Dictionary = columns[ci]
		var t: String = meta.get("type", "")
		if t == "" or t == TypeInferScript.T_STRING:
			continue
		var cname := _col_name(headers, ci)
		var allow: Array = meta.get("values", [])
		for ri in rows.size():
			var cell := _cell(rows, ri, ci)
			if not (cell is String):
				continue
			var s := (cell as String).strip_edges()
			if s == "":
				continue
			if not _matches(t, s, allow):
				var why := _expected_desc(t)
				errors.append({
					"type": "type_mismatch",
					"row": ri + 1,
					"col": ci + 1,
					"col_name": cname,
					"expected": t,
					"message": "列 %s 数据行 %d 应为 %s，实际为「%s」" % [cname, ri + 1, why, s],
				})

	# ---- 3) ID 重复 ----
	if id_column >= 0 and id_column < headers.size():
		var cname := _col_name(headers, id_column)
		var seen := {}
		for ri in rows.size():
			var s := _norm(_cell(rows, ri, id_column))
			if s == "":
				continue
			if not seen.has(s):
				seen[s] = []
			seen[s].append(ri + 1)
		for idv in seen:
			var rs: Array = seen[idv]
			if rs.size() > 1:
				var rows_s := _join_rows(rs)
				errors.append({
					"type": "dup_id",
					"row": rs[0],
					"rows": rs.duplicate(),
					"col": id_column + 1,
					"col_name": cname,
					"message": "列 %s 存在重复 ID「%s」，出现于数据行 %s" % [cname, idv, rows_s],
				})

	return {"ok": errors.is_empty(), "error_count": errors.size(), "errors": errors}


# ---------------- 内部工具 ----------------

static func _matches(t: String, s: String, allow: Array) -> bool:
	match t:
		TypeInferScript.T_BOOL:
			var lower := s.to_lower()
			return lower == "true" or lower == "false"
		TypeInferScript.T_INT:
			return s.is_valid_int()
		TypeInferScript.T_FLOAT:
			return s.is_valid_float()
		TypeInferScript.T_VECTOR2:
			return _num_parts(s) == 2
		TypeInferScript.T_VECTOR3:
			return _num_parts(s) == 3
		TypeInferScript.T_ARRAY:
			return true  # 数组元素级匹配在此放宽，避免对自由文本列误报
		TypeInferScript.T_RESOURCE:
			return s.begins_with("res://")
		TypeInferScript.T_ENUM:
			return allow.is_empty() or allow.has(s)
	return true


static func _num_parts(s: String) -> int:
	var parts := s.split(",", false)
	if parts.is_empty():
		return 0
	for part in parts:
		if not part.strip_edges().is_valid_float():
			return -1
	return parts.size()


static func _expected_desc(t: String) -> String:
	match t:
		TypeInferScript.T_INT:
			return "整数(int)"
		TypeInferScript.T_FLOAT:
			return "浮点数(float)"
		TypeInferScript.T_BOOL:
			return "布尔(true/false)"
		TypeInferScript.T_VECTOR2:
			return "Vector2(x,y)"
		TypeInferScript.T_VECTOR3:
			return "Vector3(x,y,z)"
		TypeInferScript.T_ARRAY:
			return "数组(逗号分隔)"
		TypeInferScript.T_RESOURCE:
			return "资源路径(res://...)"
		TypeInferScript.T_ENUM:
			return "枚举值(合法标识符)"
	return t


static func _col_name(headers: Array, ci: int) -> String:
	if ci >= 0 and ci < headers.size():
		return _norm(headers[ci])
	return "列%d" % (ci + 1)


static func _cell(rows: Array, ri: int, ci: int) -> Variant:
	if ri < 0 or ri >= rows.size():
		return ""
	var row: Array = rows[ri]
	if ci < 0 or ci >= row.size():
		return ""
	return row[ci]


static func _blank(cell: Variant) -> bool:
	return _norm(cell) == ""


static func _norm(v: Variant) -> String:
	if v is String:
		return (v as String).strip_edges()
	return str(v).strip_edges()


static func _join_rows(rows_l: Array) -> String:
	var parts := PackedStringArray()
	for r in rows_l:
		parts.append(str(r))
	return ", ".join(parts)

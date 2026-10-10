class_name CsvParser
extends RefCounted
## Excel 导表工具 M1 —— CSV 解析器。
##
## 特性：
##  - 引号包裹字段（"..."）、字段内逗号、转义引号（"" 表示单个 "）。
##  - 换行兼容 \r\n / \n / 孤立 \r（自动跳过空行）。
##  - UTF-8 文本；自动剥离文件开头 BOM（U+FEFF）。
##  - 统一返回：{ok, format("csv"), source, headers, rows, row_count, col_count, error}
##    第一行为字段名。


static func parse_file(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return _err("无法打开文件: %s (错误码 %d)" % [path, FileAccess.get_open_error()])
	var text := f.get_as_text()
	return parse_text(text, path)


static func parse_text(text: String, source := "") -> Dictionary:
	if text.length() > 0 and text[0] == "\uFEFF":
		text = text.substr(1)
	var grid := _tokenize(text)
	var headers: Array = []
	var rows: Array = []
	if grid.size() > 0:
		headers = grid[0]
	for r in range(1, grid.size()):
		rows.append(grid[r])
	return {
		"ok": true,
		"format": "csv",
		"source": source,
		"headers": headers,
		"rows": rows,
		"row_count": rows.size(),
		"col_count": headers.size(),
	}


# ---------------- 内部实现 ----------------

static func _tokenize(text: String) -> Array:
	var rows: Array = []
	var row: Array = []
	var field := ""
	var in_quotes := false
	var field_started := false
	var i := 0
	var n := text.length()
	while i < n:
		var ch := text[i]
		if in_quotes:
			if ch == '"':
				if i + 1 < n and text[i + 1] == '"':
					field += '"'
					i += 2
					continue
				in_quotes = false
				i += 1
				continue
			field += ch
			i += 1
			continue
		# ---- 引号外 ----
		if ch == '"':
			in_quotes = true
			field_started = true
			i += 1
		elif ch == ',':
			row.append(field)
			field = ""
			field_started = false
			i += 1
		elif ch == '\n':
			_push_row(rows, row, field)
			row = []
			field = ""
			field_started = false
			i += 1
		elif ch == '\r':
			_push_row(rows, row, field)
			row = []
			field = ""
			field_started = false
			i += 1
			if i < n and text[i] == '\n':
				i += 1
		else:
			field += ch
			field_started = true
			i += 1
	# 收尾（文本末尾无换行）
	if field != "" or field_started or row.size() > 0:
		row.append(field)
		if not _all_empty(row):
			rows.append(row)
	return rows


static func _push_row(rows: Array, row: Array, field: String) -> void:
	var r := row.duplicate()
	r.append(field)
	if not _all_empty(r):
		rows.append(r)


static func _all_empty(row: Array) -> bool:
	for f in row:
		if f != "":
			return false
	return true


static func _err(msg: String) -> Dictionary:
	return {
		"ok": false, "format": "csv", "source": "", "error": msg,
		"headers": [], "rows": [], "row_count": 0, "col_count": 0,
	}

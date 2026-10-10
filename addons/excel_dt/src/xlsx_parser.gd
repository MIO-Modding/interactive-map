class_name XlsxParser
extends RefCounted
## Excel 导表工具 M1 —— .xlsx 解析器（零第三方依赖）。
##
## 实现要点：
##  - 基于 Godot 内置 ZIPReader（注意类名为全大写 ZIPReader）解压 xlsx（本质是 zip 容器）。
##  - 基于内置 XMLParser 解析 sharedStrings.xml / workbook.xml / sheetN.xml，
##    不依赖任何第三方库，离线可运行。
##  - 统一返回结构化结果（见 parse_data 说明），第一行为字段名。
##
## 返回结构（xlsx 多 sheet 版）：
##  {
##    ok, format("xlsx"), source,
##    sheets: { "Sheet名": {headers: [...], rows: [[...]], row_count, col_count} },
##    active_sheet: String,          # 首个 sheet 名
##    headers: [...], rows: [[...]], # 与 active sheet 相同的快捷字段
##    error: String                  # 仅失败时
##  }

## sharedStrings 缓存（同一文件内跨函数共享）
static var _sst: Array = []


static func parse_file(path: String) -> Dictionary:
	# 注意：Godot 4.7 的 ZIPReader.open() 只接受路径字符串，不接受字节。
	var zip := ZIPReader.new()
	if zip.open(path) == OK:
		return _parse_zip(zip, path)
	# 路径直开失败（如非 remap 路径）时退回按字节解析
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return _err("无法打开文件: %s (错误码 %d)" % [path, FileAccess.get_open_error()])
	return parse_data(f.get_buffer(f.get_length()), path)


static func parse_data(bytes: PackedByteArray, source := "") -> Dictionary:
	var tmp_path := "%s/excel_dt_tmp_%d.xlsx" % [OS.get_cache_dir(), Time.get_ticks_usec()]
	var tmp := FileAccess.open(tmp_path, FileAccess.WRITE)
	if tmp == null:
		return _err("无法创建临时文件进行解析: %s" % source)
	tmp.store_buffer(bytes)
	tmp.close()
	var zip := ZIPReader.new()
	var err := zip.open(tmp_path)
	var res: Dictionary = _err("Zip 结构打开失败（不是有效的 .xlsx）: %s (err=%d)" % [source, err])
	if err == OK:
		res = _parse_zip(zip, source)
	DirAccess.remove_absolute(tmp_path)
	return res


static func _parse_zip(zip: ZIPReader, source := "") -> Dictionary:
	_sst = []

	# ---- 1) sharedStrings.xml：可不存在（纯数字表）----
	if zip.file_exists("xl/sharedStrings.xml"):
		var p := XMLParser.new()
		if p.open_buffer(zip.read_file("xl/sharedStrings.xml")) == OK:
			_sst = _collect_shared_strings(p)

	# ---- 2) workbook.xml + rels：sheet 名 -> xml 路径 ----
	var sheets: Dictionary = {}
	var order: Array[String] = []
	if zip.file_exists("xl/workbook.xml"):
		var rels: Dictionary = {}
		if zip.file_exists("xl/_rels/workbook.xml.rels"):
			var rp := XMLParser.new()
			if rp.open_buffer(zip.read_file("xl/_rels/workbook.xml.rels")) == OK:
				rels = _collect_rels(rp)
		var wp := XMLParser.new()
		if wp.open_buffer(zip.read_file("xl/workbook.xml")) == OK:
			_collect_sheets(wp, rels, sheets, order)

	# ---- 3) 逐个解析 sheet ----
	var sheet_datas: Dictionary = {}
	for name in order:
		var xml_path: String = sheets[name]
		if not zip.file_exists(xml_path):
			continue
		var grid := _parse_sheet_grid(zip.read_file(xml_path))
		var headers: Array = []
		var rows: Array = []
		if grid.size() > 0:
			headers = grid[0]
		for r in range(1, grid.size()):
			rows.append(grid[r])
		sheet_datas[name] = {
			"headers": headers,
			"rows": rows,
			"row_count": rows.size(),
			"col_count": headers.size(),
		}

	if sheet_datas.size() == 0:
		return _err("未在文件中找到可解析的 sheet: %s" % source)

	var keys := order if order.size() > 0 else sheet_datas.keys()
	var active: String = keys[0]
	var main: Dictionary = sheet_datas[active]
	return {
		"ok": true,
		"format": "xlsx",
		"source": source,
		"sheets": sheet_datas,
		"active_sheet": active,
		"headers": main["headers"],
		"rows": main["rows"],
		"row_count": main["row_count"],
		"col_count": main["col_count"],
	}


# ---------------- 内部实现 ----------------

static func _collect_shared_strings(p: XMLParser) -> Array:
	var out: Array = []
	var in_si := false
	var in_t := false
	var buf := ""
	while p.read() == OK:
		var nt := p.get_node_type()
		var nm := p.get_node_name()
		if nt == XMLParser.NODE_ELEMENT:
			if nm == "si":
				if in_si and buf.is_empty():
					out.append(buf)  # 兜底：自闭合 <si/> 无 ELEMENT_END
				in_si = true
				buf = ""
			elif nm == "t" and in_si:
				in_t = true
		elif nt == XMLParser.NODE_TEXT or nt == XMLParser.NODE_CDATA:
			if in_t:
				buf += p.get_node_data()
		elif nt == XMLParser.NODE_ELEMENT_END:
			if nm == "t" and in_t:
				in_t = false
			elif nm == "si" and in_si:
				out.append(buf)
				in_si = false
	if in_si:
		out.append(buf)  # 尾部自闭合 <si/> 兜底
	return out


static func _collect_rels(p: XMLParser) -> Dictionary:
	var rels := {}
	while p.read() == OK:
		if p.get_node_type() == XMLParser.NODE_ELEMENT and p.get_node_name() == "Relationship":
			var rid := _attr(p, "Id")
			var target := _attr(p, "Target")
			if rid != "" and target != "":
				rels[rid] = target
	return rels


static func _collect_sheets(p: XMLParser, rels: Dictionary, out: Dictionary, order: Array[String]) -> void:
	# 注意：OOXML 的 <sheet .../> 是自闭合标签，Godot 的 XMLParser 对自闭合元素
	# 不会产生 NODE_ELEMENT_END 事件，因此必须直接在元素事件上提交。
	while p.read() == OK:
		var nt := p.get_node_type()
		var nm := ""
		if nt == XMLParser.NODE_ELEMENT or nt == XMLParser.NODE_ELEMENT_END:
			nm = p.get_node_name()
		if nt == XMLParser.NODE_ELEMENT and nm == "sheet":
			var cname := _attr(p, "name")
			var crid := _attr(p, "id")
			if cname != "" and crid != "" and rels.has(crid):
				if not out.has(cname):
					out[cname] = _sheet_path(rels[crid])
					order.append(cname)


static func _parse_sheet_grid(bytes: PackedByteArray) -> Array:
	var p := XMLParser.new()
	if p.open_buffer(bytes) != OK:
		return []
	var row_map := {}      # row_num(1-based) -> {col:int -> String}
	var row_values := {}
	var cur_row := 0
	var in_sheet_data := false
	var cell_col := -1
	var cell_type := ""
	var in_v := false
	var vbuf := ""
	var in_is := false
	var in_is_t := false
	var is_buf := ""
	while p.read() == OK:
		var nt := p.get_node_type()
		var nm := ""
		if nt == XMLParser.NODE_ELEMENT or nt == XMLParser.NODE_ELEMENT_END:
			nm = p.get_node_name()
		if nt == XMLParser.NODE_ELEMENT:
			if nm == "sheetData":
				in_sheet_data = true
			elif nm == "row" and in_sheet_data:
				cur_row = _attr(p, "r").to_int()
				if cur_row <= 0:
					cur_row = row_map.size() + 1
				row_values = {}
			elif nm == "c" and in_sheet_data:
				cell_col = _col_index(_attr(p, "r"))
				cell_type = _attr(p, "t")
				vbuf = ""
				is_buf = ""
			elif nm == "v" and in_sheet_data:
				in_v = true
				vbuf = ""
			elif nm == "is" and in_sheet_data:
				in_is = true
				is_buf = ""
			elif nm == "t" and in_is:
				in_is_t = true
		elif nt == XMLParser.NODE_TEXT or nt == XMLParser.NODE_CDATA:
			if in_v:
				vbuf += p.get_node_data()
			elif in_is_t:
				is_buf += p.get_node_data()
		elif nt == XMLParser.NODE_ELEMENT_END:
			if nm == "v" and in_v:
				in_v = false
			elif nm == "t" and in_is_t:
				in_is_t = false
			elif nm == "is" and in_is:
				in_is = false
			elif nm == "c" and in_sheet_data:
				if cell_col >= 0:
					row_values[cell_col] = _resolve_cell(cell_type, vbuf, is_buf)
				cell_col = -1
				cell_type = ""
			elif nm == "row" and in_sheet_data:
				if row_values.size() > 0 or cur_row > 0:
					row_map[cur_row] = row_values
				row_values = {}
				cur_row = 0
			elif nm == "sheetData":
				in_sheet_data = false

	var keys := row_map.keys()
	keys.sort()
	if keys.size() == 0:
		return []
	var min_row: int = keys[0]
	var max_row: int = keys[keys.size() - 1]
	var max_col := 0
	for rk in keys:
		var rd: Dictionary = row_map[rk]
		for c in rd:
			if c > max_col:
				max_col = c
	var grid: Array = []
	for rn in range(min_row, max_row + 1):
		var rd: Dictionary = row_map.get(rn, {})
		var line: Array = []
		for ci in range(max_col + 1):
			line.append(rd.get(ci, ""))
		grid.append(line)
	return grid


static func _resolve_cell(ctype: String, v: String, inline: String) -> String:
	if ctype == "s":
		var idx := v.to_int()
		if idx >= 0 and idx < _sst.size():
			return _sst[idx]
		return ""
	elif ctype == "inlineStr":
		return inline
	elif ctype == "b":
		return "true" if v == "1" else "false"
	return v


static func _attr(p: XMLParser, name: String) -> String:
	for i in p.get_attribute_count():
		var an := p.get_attribute_name(i)
		if an == name or an.ends_with(":" + name):
			return p.get_attribute_value(i)
	return ""


static func _col_index(ref: String) -> int:
	if ref.is_empty():
		return -1
	var letters := ""
	for i in ref.length():
		var ch := ref[i]
		if (ch >= "A" and ch <= "Z") or (ch >= "a" and ch <= "z"):
			letters += ch.to_upper()
		else:
			break
	if letters.is_empty():
		return -1
	var col := 0
	for i in letters.length():
		col = col * 26 + (letters[i].unicode_at(0) - 65 + 1)
	return col - 1


static func _sheet_path(target: String) -> String:
	if target.begins_with("/xl/"):
		return target.substr(1)
	if target.begins_with("xl/"):
		return target
	return "xl/" + target


static func _err(msg: String) -> Dictionary:
	return {
		"ok": false, "format": "xlsx", "source": "", "error": msg,
		"headers": [], "rows": [], "row_count": 0, "col_count": 0,
		"sheets": {}, "active_sheet": "",
	}

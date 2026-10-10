@tool
class_name TableCodeGen
extends RefCounted
## Excel 导表工具 M3 —— 代码/资源生成器。
##
## 基于 M2 的 columns 推断结果 + cleaned rows，为每张表生成 4 类产物到 out_dir（默认 res://tables/）：
##   <Pascal>.gd       数据类脚本（class_name 化，字段严格按推断类型声明）
##   <Pascal>Table.gd  读表入口（get(id)/get_all()/filter(predicate)/count()，基于 .tres 加载）
##   <Pascal>.tres     数据资源（ResourceSaver 序列化，根节点即读表入口，rows 内含全部行）
##   <Pascal>.json     明文 JSON 双输出（含 columns / validation，便于外部核对）
##
## 标识符处理：
##   - sheet/表名 -> PascalCase（去非法字符、首字母大写、数字开头补 'T'、规避 GDScript 关键词）
##   - 列名 -> lowerCamel 字段名（与 Object/Resource 内置成员冲突时补 '_'）
##   - 重名表 / 无法转为合法类名的表名 -> 收集为明确报错，本次导出整体失败、不写任何产物（事务式）
##
## 类型映射（对齐 M2）：
##   int/float/String/bool/Vector2/Vector3 -> 原生类型；Array -> Array[<elem>]；
##   enum -> 类内 enum 成员（UPPER_SNAKE），.tres 存索引 int；Resource(路径) -> String。

const XlsxScript := preload("res://addons/excel_dt/src/xlsx_parser.gd")
const CsvScript := preload("res://addons/excel_dt/src/csv_parser.gd")
const TypeInferScript := preload("res://addons/excel_dt/src/type_infer.gd")
const CleanerScript := preload("res://addons/excel_dt/src/cleaner.gd")
const ValidatorScript := preload("res://addons/excel_dt/src/validator.gd")

const TYPE_INT := TypeInferScript.T_INT
const TYPE_FLOAT := TypeInferScript.T_FLOAT
const TYPE_STRING := TypeInferScript.T_STRING
const TYPE_BOOL := TypeInferScript.T_BOOL
const TYPE_VECTOR2 := TypeInferScript.T_VECTOR2
const TYPE_VECTOR3 := TypeInferScript.T_VECTOR3
const TYPE_ARRAY := TypeInferScript.T_ARRAY
const TYPE_ENUM := TypeInferScript.T_ENUM
const TYPE_RESOURCE := TypeInferScript.T_RESOURCE

# 与 Object/Resource 内置成员或常见 GDScript 语义冲突的字段名清单（出现则追加 '_'）
const FIELD_BLOCKLIST := [
	"get", "set", "call", "script", "method", "base", "class", "signal",
	"meta", "path", "resource_path", "resource_name", "resource_local_to_scene",
	"editor_description", "property_list", "size", "keys", "values", "duplicate",
]

# Godot 保留关键词（表名/列名转出后与之冲突则加前缀/后缀规避）
const RESERVED_KEYWORDS := [
	"class", "extends", "func", "var", "const", "enum", "if", "elif", "else",
	"for", "while", "break", "continue", "return", "static", "match", "and",
	"or", "not", "in", "is", "as", "await", "yield", "signal", "void", "true",
	"false", "null", "self", "super", "tool",
]


# ============================================================
# 对外入口
# ============================================================

## 全量导出：扫描 source_dir 下所有 .xlsx/.csv（xlsx 的每个 sheet 为一张表，csv 以文件名命名为一张表）。
## 先整体校验标识符（非法/重名、事务式），全部合法后重建 out_dir 并生成 4 类产物。
## opts:
##   source_files : Array[String]  仅导出指定文件（含路径，需 res:// 前缀；用于定向导出/测试）
##   clear_out_dir: bool  默认 true，生成前清空 out_dir 中历史 .gd/.tres/.json（全量重建）
##   id_column    : int   默认 0（主键列索引）
##   formats      : Array[String]  取值 ".gd"/".table"/".tres"/".json" 之一或多个，
##                                仅生成指定类别的产物；默认空（四点全出，向后兼容）
##   name_override: Dictionary    raw_name -> 自定义类名；覆盖默认 sanitize 结果，
##                                覆盖名同样参与整体合法性/重名校验（事务式：任一失败不落盘）
##   tables_filter: Array[String] raw_name 白名单，仅导出指定表；默认空（全部）
static func export_all(source_dir: String, out_dir: String, opts := {}) -> Dictionary:
	var formats: Array = opts.get("formats", [])
	var name_override: Dictionary = opts.get("name_override", {})
	var tables_filter: Array = opts.get("tables_filter", [])
	var files: Array[String] = _collect_sources(source_dir, opts.get("source_files", []))
	var tables: Array = []
	var errors: Array = []
	for p in files:
		var parsed: Dictionary = (
			XlsxScript.parse_file(p) if p.to_lower().ends_with(".xlsx")
			else CsvScript.parse_file(p)
		)
		if not parsed.get("ok", false):
			errors.append({
				"type": "parse_error",
				"source": p,
				"message": "解析失败：%s" % parsed.get("error", "未知错误"),
			})
			continue
		if parsed.get("format", "") == "xlsx":
			var sheets: Dictionary = parsed.get("sheets", {})
			for sname in sheets:
				var sd: Dictionary = sheets[sname]
				_push_table(tables, str(sname), p,
					sd.get("headers", []), sd.get("rows", []), opts)
		else:
			var base := p.get_file().get_basename()
			_push_table(tables, base, p,
				parsed.get("headers", []), parsed.get("rows", []), opts)

	if tables_filter.size() > 0:
		var kept: Array = []
		for td in tables:
			if tables_filter.has(str(td["raw_name"])):
				kept.append(td)
		tables = kept

	if tables.is_empty():
		if errors.is_empty():
			errors.append({
				"type": "no_table",
				"message": "源目录 %s 下未发现任何可导出的表（或所选表与源文件不匹配）" % source_dir,
			})
		return {"ok": false, "errors": errors, "tables": [], "files": []}

	# ---- 标识符整体校验（非法/重名，任一失败即整体中止，不写任何产物） ----
	var class_name_of: Dictionary = _resolve_names(tables, errors, name_override)
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "tables": [], "files": []}

	if bool(opts.get("clear_out_dir", true)):
		_clear_artifacts(out_dir)

	var files_out: Array = []
	var generated: Array = []
	for i in tables.size():
		var r: Dictionary = _generate_one(tables[i], str(class_name_of[i]), out_dir, formats)
		if not r.get("ok", false):
			errors.append({
				"type": "gen_error",
				"table": tables[i]["raw_name"],
				"message": r.get("error", ""),
			})
			continue
		files_out.append_array(r["files"])
		generated.append(tables[i]["raw_name"])

	if not errors.is_empty():
		return {"ok": false, "errors": errors, "tables": generated, "files": files_out}
	return {"ok": true, "errors": [], "tables": generated, "files": files_out}


## 只读扫描：解析源目录，返回每张表的元信息（raw_name/源文件/列/默认类名），不写任何产物。
## 供「导出选项」对话框展示表清单使用，与 export_all 使用同一套解析/命名规则。
## opts: source_files（限定文件）同 export_all。
static func scan_tables(source_dir: String, opts := {}) -> Dictionary:
	var files: Array[String] = _collect_sources(source_dir, opts.get("source_files", []))
	var tables: Array = []
	var errors: Array = []
	for p in files:
		var parsed: Dictionary = (
			XlsxScript.parse_file(p) if p.to_lower().ends_with(".xlsx")
			else CsvScript.parse_file(p)
		)
		if not parsed.get("ok", false):
			errors.append({
				"type": "parse_error",
				"source": p,
				"message": "解析失败：%s" % parsed.get("error", "未知错误"),
			})
			continue
		if parsed.get("format", "") == "xlsx":
			var sheets: Dictionary = parsed.get("sheets", {})
			for sname in sheets:
				var sd: Dictionary = sheets[sname]
				_append_scan_table(tables, str(sname), p, sd.get("headers", []))
		else:
			var base := p.get_file().get_basename()
			_append_scan_table(tables, base, p, parsed.get("headers", []))
	return {"ok": true, "tables": tables, "errors": errors}


static func _append_scan_table(tables: Array, raw_name: String, source: String, headers: Array) -> void:
	var cn := sanitize_class_name(raw_name)
	if cn != "" and cn.to_lower() in RESERVED_KEYWORDS:
		cn = "T" + cn
	tables.append({
		"raw_name": raw_name,
		"source": source,
		"headers": headers,
		"col_count": headers.size(),
		"default_class": cn,
	})


# ============================================================
# 生成核心
# ============================================================

## 为单张表生成（部分）产物到 out_dir。formats 为空表示四点全出（默认，向后兼容）；
## 非空则仅生成指定类别：".gd"(数据类)/".table"(读表入口 Table.gd)/".tres"/".json"。
## 注意：.tres 依赖同名的 .gd 数据类与 Table.gd 读表类（仅选 .tres 时需先前已存在可加载）。
static func _generate_one(td: Dictionary, cls: String, out_dir: String, formats := []) -> Dictionary:
	var want_gd := _want(".gd", formats)
	var want_table := _want(".table", formats)
	var want_tres := _want(".tres", formats)
	var want_json := _want(".json", formats)
	var files_out: Array = []

	var prep := _prep_fields(td)
	if not prep.get("ok", false):
		return {"ok": false, "error": prep.get("error", "字段预处理失败")}
	var fields: Array = prep["fields"]
	var enums: Array = prep["enums"]
	var pk_field: String = prep["pk_field"]

	var data_path := "%s/%s.gd" % [out_dir, cls]
	var table_path := "%s/%sTable.gd" % [out_dir, cls]
	var tres_path := "%s/%s.tres" % [out_dir, cls]
	var json_path := "%s/%s.json" % [out_dir, cls]

	if want_gd:
		if not _write_text(data_path, _data_class_source(td, cls, fields, enums)):
			return {"ok": false, "error": "写入数据类失败：%s" % data_path}
		files_out.append(data_path)

	if want_table:
		if not _write_text(table_path, _table_class_source(td, cls, pk_field)):
			return {"ok": false, "error": "写入读表类失败：%s" % table_path}
		files_out.append(table_path)

	if want_tres:
		var row_script: GDScript = load(data_path)
		if row_script == null:
			return {"ok": false, "error": "生成的 %s 无法编译/加载（.tres 需要同时勾选 .gd 数据类）" % data_path}
		var rows_res: Array = []
		for r in td["rows"]:
			var inst: Resource = row_script.new()
			for ci in fields.size():
				var fd: Dictionary = fields[ci]
				inst.set(fd["field"], _coerce_value(fd, r, ci))
			rows_res.append(inst)

		var tbl_script: GDScript = load(table_path)
		if tbl_script == null:
			return {"ok": false, "error": "生成的 %s 无法编译/加载（.tres 需要同时勾选 Table.gd 读表类）" % table_path}
		var tbl: Resource = tbl_script.new()
		tbl.set("rows", rows_res)
		tbl.set("primary_key", pk_field)

		var err := ResourceSaver.save(tbl, tres_path)
		if err != OK:
			return {"ok": false, "error": "ResourceSaver 保存 %s 失败 err=%d" % [tres_path, err]}
		files_out.append(tres_path)

	if want_json:
		var jd := {
			"generator": "excel_table_importer/M3",
			"table": cls,
			"raw_name": td["raw_name"],
			"source": td["source"],
			"headers": td["headers"],
			"rows": td["rows"],
			"columns": td["columns"],
			"validation": td["validation"],
		}
		if not _write_text(json_path, JSON.stringify(jd, "\t")):
			return {"ok": false, "error": "写入 JSON 失败：%s" % json_path}
		files_out.append(json_path)

	return {"ok": true, "files": files_out}


## formats 是否包含 fmt（fmt ∈ ".gd"/".table"/".tres"/".json"）；formats 为空视为全选。
static func _want(fmt: String, formats: Array) -> bool:
	if formats.is_empty():
		return true
	return formats.has(fmt)


# ---------------- 构建表格描述 ----------------

static func _push_table(tables: Array, raw_name: String, source: String,
	headers: Array, rows: Array, opts: Dictionary) -> void:
	var clean: Dictionary = CleanerScript.clean_rows(rows)
	var columns: Array = []
	var validation := {}
	if headers.size() > 0 and not clean["rows"].is_empty():
		var inferred: Dictionary = TypeInferScript.infer(headers, clean["rows"])
		columns = inferred.get("columns", [])
		validation = ValidatorScript.validate(headers, clean["rows"], inferred,
			{"id_column": int(opts.get("id_column", 0))})
	tables.append({
		"raw_name": raw_name,
		"source": source,
		"headers": headers,
		"rows": clean["rows"],
		"columns": columns,
		"validation": validation,
		"id_column": int(opts.get("id_column", 0)),
	})


# ---------------- 标识符校验 ----------------

static func _resolve_names(tables: Array, errors: Array, name_override := {}) -> Dictionary:
	var mapping := {}
	var used   := {}   # class_name -> {raw_name, source}
	for i in tables.size():
		var td: Dictionary = tables[i]
		var raw := str(td["raw_name"])
		var cn := ""
		if name_override.has(raw):
			# 用户自定义类名：直接采用，但须是合法类名，且同样参与重名校验
			cn = str(name_override[raw]).strip_edges()
			var verr := _validate_override_class_name(cn)
			if verr != "":
				errors.append({
					"type": "illegal_name",
					"table": raw,
					"source": td["source"],
					"message": "表名「%s」的自定义类名「%s」不合法：%s" % [raw, cn, verr],
				})
				continue
		else:
			cn = sanitize_class_name(raw)
			if cn == "":
				errors.append({
					"type": "illegal_name",
					"table": raw,
					"source": td["source"],
					"message": "表名「%s」去除非法字符后为空，无法生成合法 Godot 类名（请使用字母/数字/下划线命名工作表，中文表名需改名）" % raw,
				})
				continue
			if cn.to_lower() in RESERVED_KEYWORDS:
				cn = "T" + cn
		if used.has(cn):
			var prev: Dictionary = used[cn]
			errors.append({
				"type": "dup_name",
				"table": raw,
				"source": td["source"],
				"class_name": cn,
				"message": "表名「%s」（%s）与「%s」（%s）重名，均映射为类名 %s，请重命名工作表/自定义类名，或用 source_files 指定唯一导出源" % [
					raw, td["source"], prev["raw_name"], prev["source"], cn,
				],
			})
		else:
			used[cn] = {"raw_name": raw, "source": td["source"]}
		mapping[i] = cn
	return mapping


## 自定义类名（name_override 提供的值）合法性校验；返回空串表示合法，否则返回失败原因。
static func _validate_override_class_name(name: String) -> String:
	if name == "":
		return "类名为空"
	for i in name.length():
		var ch: String = name[i]
		if not (_is_ascii_letter(ch) or _is_digit(ch) or ch == "_"):
			return "含非法字符（仅允许字母/数字/下划线）"
	var first := name[0]
	if not (_is_ascii_letter(first) or first == "_"):
		return "必须以字母或下划线开头"
	if name.to_lower() in RESERVED_KEYWORDS:
		return "为 Godot 保留关键词，请更换"
	return ""


## sheet/表名 -> 合法 Godot 类名（PascalCase，去非法字符、首字母大写）。
## 非法字符（中文/空格/标点等）视为分隔符；结果为空返回 ""（调用方报错）。
## 数字开头补 'T' 前缀。
static func sanitize_class_name(raw: String) -> String:
	var s := str(raw).strip_edges()
	if s.is_empty():
		return ""
	var out := ""
	var cap := true
	for i in s.length():
		var ch: String = s[i]
		if ch == "_":
			cap = true
			continue
		if _is_ascii_letter(ch):
			out += ch.to_upper() if cap else ch.to_lower()
			cap = false
		elif _is_digit(ch):
			out += ch
			cap = false
		else:
			cap = true
	if out.is_empty():
		return ""
	if _is_digit(out[0]):
		out = "T" + out
	return out


## 列名 -> lowerCamel 字段名（合法标识符、规避关键词 / Object/Resource 内置成员冲突）。
static func field_name(raw: String) -> String:
	var s := str(raw).strip_edges()
	var out := ""
	var cap := false
	for i in s.length():
		var ch: String = s[i]
		if ch == "_":
			cap = true
			continue
		if _is_ascii_letter(ch):
			out += ch.to_upper() if cap else ch.to_lower()
			cap = false
		elif _is_digit(ch):
			out += ch
			cap = false
		else:
			cap = true
	if out.is_empty():
		out = "col"
	if _is_digit(out[0]):
		out = "f" + out
	if out.to_lower() in RESERVED_KEYWORDS or out.to_lower() in FIELD_BLOCKLIST:
		out += "_"
	return out


# ---------------- 字段/枚举预处理 ----------------

static func _prep_fields(td: Dictionary) -> Dictionary:
	var fields: Array = []
	var enums: Array = []
	var seen_field := {}
	var headers: Array = td["headers"]
	var cols: Array = td["columns"]
	for ci in cols.size():
		var meta: Dictionary = cols[ci]
		var raw_name := str(meta.get("name", headers[ci] if ci < headers.size() else "col"))
		var fn := field_name(raw_name)
		if seen_field.has(fn):
			return {
				"ok": false,
				"error": "列「%s」与 %s 字段名冲突（均映射为 %s），请重命名列" % [
					raw_name, seen_field[fn], fn,
				],
			}
		seen_field[fn] = "「" + raw_name + "」"

		var t := str(meta.get("type", TYPE_STRING))
		var fd := {"name": raw_name, "field": fn, "type": t, "index": ci}
		var decl := "String"
		var dflt := "\"\""
		var doc := "「%s」" % raw_name
		match t:
			TYPE_INT:
				decl = "int"; dflt = "0"
			TYPE_FLOAT:
				decl = "float"; dflt = "0.0"
			TYPE_BOOL:
				decl = "bool"; dflt = "false"
			TYPE_VECTOR2:
				decl = "Vector2"; dflt = "Vector2.ZERO"
			TYPE_VECTOR3:
				decl = "Vector3"; dflt = "Vector3.ZERO"
			TYPE_ARRAY:
				var elem := str(meta.get("elem_type", TYPE_STRING))
				fd["elem"] = elem
				match elem:
					TYPE_INT:
						decl = "Array[int]"
					TYPE_FLOAT:
						decl = "Array[float]"
					TYPE_BOOL:
						decl = "Array[bool]"
					_:
						decl = "Array[String]"   # 含 Resource 路径数组，均以 String 承载
				dflt = "[]"
			TYPE_ENUM:
				var values: Array = meta.get("values", [])
				if values.is_empty():
					decl = "String"; dflt = "\"\""
				else:
					var ename := _unique_enum_name(fn, enums)
					var members := _enum_members(values)
					var emap := {}
					for m in members:
						emap[m[2]] = m[1]
					enums.append({"column": raw_name, "name": ename, "members": members})
					fd["enum_map"] = emap
					fd["enum_name"] = ename
					decl = ename; dflt = "0"
					doc = "「%s」（枚举 %s）" % [raw_name, ename]
			TYPE_RESOURCE:
				decl = "String"; dflt = "\"\""; doc = "「%s」（资源路径）" % raw_name
			_:
				decl = "String"; dflt = "\"\""
		fd["decl"] = decl
		fd["default"] = dflt
		fd["doc"] = doc
		fields.append(fd)

	var pk := "id"
	var idc: int = int(td.get("id_column", 0))
	if idc >= 0 and idc < fields.size():
		pk = str(fields[idc]["field"])
	return {"ok": true, "fields": fields, "enums": enums, "pk_field": pk}


static func _unique_enum_name(fn: String, enums: Array) -> String:
	var base := fn[0].to_upper() + fn.substr(1)
	var name := base
	var i := 2
	while _enum_name_taken(name, enums):
		name = "%s%d" % [base, i]
		i += 1
	return name


static func _enum_name_taken(name: String, enums: Array) -> bool:
	for e in enums:
		if e["name"] == name:
			return true
	return false


## 推断的 distinct 枚举值 -> [[UPPER_SNAKE 成员名, 索引, 原始值], ...]
static func _enum_members(values: Array) -> Array:
	var out: Array = []
	var used_names := {}
	var idx := 0
	for raw in values:
		var nm := _upper_identifier(str(raw))
		if nm == "" or nm == "NULL":
			nm = "V%d" % idx
		while used_names.has(nm):
			nm = "%s_%d" % [nm, idx]
		used_names[nm] = true
		out.append([nm, idx, str(raw)])
		idx += 1
	return out


static func _upper_identifier(raw: String) -> String:
	var out := ""
	for i in raw.length():
		var ch: String = raw[i]
		if _is_ascii_letter(ch):
			out += ch.to_upper()
		elif _is_digit(ch):
			if out != "":
				out += ch
		else:
			out += "_"
	return out


# ---------------- 值规范化（对齐 M2 coerce + 类型化数组） ----------------

static func _coerce_value(fd: Dictionary, row: Array, ci: int) -> Variant:
	var raw := ""
	if ci < row.size():
		raw = _norm(row[ci])
	var t := str(fd["type"])
	match t:
		TYPE_INT, TYPE_FLOAT, TYPE_BOOL, TYPE_VECTOR2, TYPE_VECTOR3:
			return TypeInferScript.coerce(t, raw)
		TYPE_ARRAY:
			var elem := str(fd.get("elem", TYPE_STRING))
			if raw.is_empty():
				return _typed_empty_array(elem)
			var arr: Array = TypeInferScript.coerce(t, raw, elem)
			return _typed_array(arr, elem)
		TYPE_ENUM:
			var emap: Dictionary = fd.get("enum_map", {})
			return emap.get(raw, 0)
		TYPE_RESOURCE:
			return raw   # 资源路径以字符串承载
		_:
			return raw


## .tres 序列化要求数组为类型化数组（未类型化会被丢弃），见 M3 探针结论。
static func _typed_array(arr: Array, elem: String) -> Variant:
	match elem:
		TYPE_INT:
			var out: Array[int] = []
			for v in arr:
				out.append(int(v))
			return out
		TYPE_FLOAT:
			var of: Array[float] = []
			for v in arr:
				of.append(float(v))
			return of
		TYPE_BOOL:
			var ob: Array[bool] = []
			for v in arr:
				ob.append(bool(v))
			return ob
		_:
			var os: Array[String] = []
			for v in arr:
				os.append(str(v))
			return os


static func _typed_empty_array(elem: String) -> Variant:
	match elem:
		TYPE_INT:
			var a: Array[int] = []
			return a
		TYPE_FLOAT:
			var b: Array[float] = []
			return b
		TYPE_BOOL:
			var c: Array[bool] = []
			return c
		_:
			var d: Array[String] = []
			return d


# ---------------- 生成源码 ----------------

static func _data_class_source(td: Dictionary, cls: String, fields: Array, enums: Array) -> String:
	var src := "# AUTO-GENERATED by ExcelTableImporter (M3). DO NOT EDIT MANUALLY.\n"
	src += "# source: %s\n" % td["source"]
	src += "# raw table: %s\n\n" % td["raw_name"]
	src += "class_name %s\n" % cls
	src += "extends Resource\n"
	src += "## 数据表 %s —— 字段类型由 M2 类型推断确定\n\n" % cls
	for e in enums:
		src += "## 列「%s」枚举\n" % e["column"]
		src += "enum %s { " % e["name"]
		var parts: Array = []
		for m in e["members"]:
			parts.append("%s = %d" % [m[0], m[1]])
		src += ", ".join(parts)
		src += " }\n\n"
	for fd in fields:
		src += "## %s\n" % fd["doc"]
		src += "@export var %s: %s = %s\n" % [fd["field"], fd["decl"], fd["default"]]
	return src


static func _table_class_source(td: Dictionary, cls: String, pk_field: String) -> String:
	var src := "# AUTO-GENERATED by ExcelTableImporter (M3). DO NOT EDIT MANUALLY.\n"
	src += "# source: %s\n" % td["source"]
	src += "# raw table: %s\n\n" % td["raw_name"]
	src += "class_name %sTable\n" % cls
	src += "extends Resource\n"
	src += "## 读表入口：%s —— 基于 .tres 加载的静态表数据\n" % cls
	src += "## 键列：%s\n\n" % pk_field
	src += "@export var rows: Array = []\n"
	src += "@export var primary_key := \"%s\"\n\n" % pk_field
	src += "var _index := {}\n\n"
	src += "func _rebuild_index() -> void:\n"
	src += "\t_index.clear()\n"
	src += "\tfor r in rows:\n"
	src += "\t\tvar k: Variant = r.get(primary_key)\n"
	src += "\t\tif not _index.has(k):\n"
	src += "\t\t\t_index[k] = r\n\n"
	src += "# 刻意命名为 get(id) 作为读表 API，覆盖 Object.get；需显式忽略该警告（否则项目视为错误）\n"
	src += "@warning_ignore(\"native_method_override\")\n"
	src += "func get(id: Variant) -> Variant:\n"
	src += "\t# 首次访问建索引；主键无重复（M2 校验），首个命中即返回\n"
	src += "\tif _index.is_empty():\n"
	src += "\t\t_rebuild_index()\n"
	src += "\treturn _index.get(id)\n\n"
	src += "func get_all() -> Array:\n"
	src += "\treturn rows\n\n"
	src += "func filter(predicate: Callable) -> Array:\n"
	src += "\tvar out: Array = []\n"
	src += "\tfor r in rows:\n"
	src += "\t\tif predicate.call(r):\n"
	src += "\t\t\tout.append(r)\n"
	src += "\treturn out\n\n"
	src += "func count() -> int:\n"
	src += "\treturn rows.size()\n"
	return src


# ============================================================
# IO 工具
# ============================================================

static func _collect_sources(source_dir: String, only: Array) -> Array[String]:
	var out: Array[String] = []
	if only.size() > 0:
		for p in only:
			var l := str(p).to_lower()
			if l.ends_with(".xlsx") or l.ends_with(".csv"):
				out.append(str(p))
		return out
	var d := DirAccess.open(source_dir)
	if d == null:
		return out
	var files := d.get_files()
	files.sort()
	for f in files:
		var l := f.to_lower()
		if l.ends_with(".xlsx") or l.ends_with(".csv"):
			out.append("%s/%s" % [source_dir, f])
	return out


static func _clear_artifacts(out_dir: String) -> void:
	var d := DirAccess.open(out_dir)
	if d == null:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
		return
	var abs := ProjectSettings.globalize_path(out_dir)
	for f in d.get_files():
		var l := f.to_lower()
		if l.ends_with(".gd") or l.ends_with(".tres") or l.ends_with(".json"):
			DirAccess.remove_absolute(abs.path_join(f))


static func _write_text(path: String, text: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true


static func _norm(v: Variant) -> String:
	if v is String:
		return (v as String).strip_edges()
	return str(v).strip_edges()


static func _is_ascii_letter(ch: String) -> bool:
	var c := ch.unicode_at(0)
	return (c >= 65 and c <= 90) or (c >= 97 and c <= 122)


static func _is_digit(ch: String) -> bool:
	var c := ch.unicode_at(0)
	return c >= 48 and c <= 57

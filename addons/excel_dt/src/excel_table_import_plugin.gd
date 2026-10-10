@tool
class_name ExcelTableImportPlugin
extends EditorImportPlugin
## Excel 导表工具 —— 导入器（M1 阶段带骨架）。
##
## 目的：让 .xlsx/.csv 在 Godot 文件系统面板可见、可被工程正式接管管理
##      （EditorImportPlugin 是唯一能让陌生扩展名稳定显示并纳入导入流程的正规机制）。
## 当前导入产物：把解析结果输出为一个 JSON（存于 .godot/imported），
##      编辑器里双击对应的 .xlsx/.csv 即可预览解析内容。
## M3 将把该导入器扩展为：同时生成类型安全的 .tres + 读表 .gd 到 res://tables/。

const IMPORTER_NAME := "excel_table_importer"
const IMPORTER_VERSION := 2
const EXTENSIONS := ["xlsx", "csv"]
const SAVE_EXT := "json"

const XlsxParserScript := preload("res://addons/excel_dt/src/xlsx_parser.gd")
const CsvParserScript := preload("res://addons/excel_dt/src/csv_parser.gd")
const CleanerScript := preload("res://addons/excel_dt/src/cleaner.gd")
const TypeInferScript := preload("res://addons/excel_dt/src/type_infer.gd")
const ValidatorScript := preload("res://addons/excel_dt/src/validator.gd")


func _get_importer_name() -> String:
	return IMPORTER_NAME


func _get_visible_name() -> String:
	return "Excel 导表工具"


## 扩展名竞争优先级。Godot 内置 csv_translation 的默认优先级为 1.0，
## 若不调高会导致 .csv 被引擎内置 importer 抢走（表现为只产出 .translation/.md5）。
## 设为 1.1 后，.csv 会稳定路由到本插件。
func _get_priority() -> float:
	return 1.1


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(EXTENSIONS)


func _get_save_extension() -> String:
	return SAVE_EXT


func _get_resource_type() -> String:
	return "JSON"


func _get_preset_count() -> int:
	return 1


func _get_preset_name(preset_index: int) -> String:
	return "默认"


func _get_import_options(path: String, preset_index: int) -> Array[Dictionary]:
	return []


func _get_option_visibility(path: String, option_name: StringName, options: Dictionary) -> bool:
	return true


func _import(
	source_file: String,
	save_path: String,
	options: Dictionary,
	platform_variants: Array,
	gen_files: Array
) -> Error:
	var parsed := _parse(source_file)
	if not parsed.get("ok", false):
		push_error("[excel_dt] 导入失败 %s: %s" % [source_file, parsed.get("error", "未知错误")])
		return ERR_CANT_OPEN

	var headers: Array = parsed.get("headers", [])
	var rows: Array = parsed.get("rows", [])

	# ---- M2 清洗：过滤全空行 + AI 注释/备注行 ----
	var clean := CleanerScript.clean_rows(rows)

	# ---- M2 类型推断 + 校验 ----
	var columns: Array = []
	var validation := {}
	if headers.size() > 0:
		var inferred := TypeInferScript.infer(headers, clean["rows"])
		columns = inferred.get("columns", [])
		validation = ValidatorScript.validate(headers, clean["rows"], inferred)
		if validation.get("error_count", 0) > 0:
			# 校验失败不阻断导入，错误随 JSON 产物落盘并由编辑器 toaster/日志提示
			var firsts: Array = validation.get("errors", [])
			var n: int = mini(3, firsts.size())
			for i in n:
				var e: Dictionary = firsts[i]
				push_warning("[excel_dt] 数据校验: %s" % e.get("message", ""))

	var data := {
		"source": source_file,
		"format": parsed.get("format", ""),
		"headers": headers,
		"rows": clean["rows"],
		"cleaned": {
			"input_rows": rows.size(),
			"rows": clean["rows"].size(),
			"dropped_empty": clean["dropped_empty"],
			"dropped_comment": clean["dropped_comment"],
			"dropped_total": clean["dropped_empty"] + clean["dropped_comment"],
		},
		"columns": columns,
		"validation": validation,
	}
	# xlsx 附带多 sheet 信息
	if parsed.has("sheets"):
		data["sheets"] = parsed.get("sheets")
		data["active_sheet"] = parsed.get("active_sheet", "")

	var text := JSON.stringify(data, "\t")
	var out_path := "%s.%s" % [save_path, SAVE_EXT]
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		push_error("[excel_dt] 无法写入导入结果: %s" % out_path)
		return ERR_CANT_CREATE
	f.store_string(text)
	f.close()
	return OK


static func _parse(p: String) -> Dictionary:
	if p.to_lower().ends_with(".xlsx"):
		return XlsxParserScript.parse_file(p)
	return CsvParserScript.parse_file(p)

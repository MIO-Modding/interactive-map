@tool
class_name ExportOptionsDialog
extends ConfirmationDialog
## Excel 导表工具 —— 交互式导出选项对话框（M4.5 / 交互导出）。
##
## 与 M3 codegen.gd 协同，提供导出前的可交互配置：
##   - 表清单：展示扫描到的每张表（源文件 / 当前类名 / 列数），可勾选是否导出、可编辑自定义类名
##   - 输出格式：.gd / Table.gd / .tres / .json 四项勾选（默认全选）
##   - 输出目录：默认 res://tables/，可改为其他 res:// 目录
##   - 导出 / 取消：确认后调用 codegen.export_all 并把 errors/success 汇总反馈
##
## 纯逻辑部分（build_opts / _collect 等）为 static 无 UI 依赖，便于 headless 验证；
## 弹窗展示与点击交互由用户在编辑器内验收。

const CodegenScript := preload("res://addons/excel_dt/src/codegen.gd")

const SOURCE_DIR := "res://examples"
const DEFAULT_OUT_DIR := "res://tables"

const FORMAT_ITEMS := [
	{"label": ".gd（数据类）", "value": ".gd"},
	{"label": "Table.gd（读表入口）", "value": ".table"},
	{"label": ".tres（数据资源）", "value": ".tres"},
	{"label": ".json（明文 JSON）", "value": ".json"},
]

# 最近一次导出结果（供外部/测试读取）：{ok, errors, tables, files, out_dir, formats}
var last_report: Dictionary = {}


## 暴露内置表格清单容器的引用（headless 无 UI 时可为 null），_refresh_tables 会重建。
var _list_box: VBoxContainer
var _row_ctrls: Array = []   # [{check: CheckBox, edit: LineEdit, raw: String, source: String}]
var _fmt_checks: Array = []
var _out_dir_edit: LineEdit
var _status: Label


func _ready() -> void:
	title = "导出选项…"
	ok_button_text = "导出"
	cancel_button_text = "取消"
	set_min_size(Vector2i(600, 520))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)

	var t1 := Label.new()
	t1.text = "表清单（勾选需要导出的表，可编辑自定义类名）"
	t1.add_theme_font_size_override("font_size", 15)
	box.add_child(t1)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 220)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 4)
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_box)
	box.add_child(scroll)

	var t2 := Label.new()
	t2.text = "输出格式"
	t2.add_theme_font_size_override("font_size", 15)
	box.add_child(t2)

	var fmts := HBoxContainer.new()
	fmts.add_theme_constant_override("separation", 12)
	for fi in FORMAT_ITEMS:
		var cb := CheckBox.new()
		cb.text = fi["label"]
		cb.button_pressed = true
		cb.set_meta("format_value", fi["value"])
		fmts.add_child(cb)
		_fmt_checks.append(cb)
	box.add_child(fmts)

	var t3 := Label.new()
	t3.text = "输出目录（res:// 相对路径，导出前会清空该目录下旧产物）"
	t3.add_theme_font_size_override("font_size", 15)
	box.add_child(t3)

	_out_dir_edit = LineEdit.new()
	_out_dir_edit.text = DEFAULT_OUT_DIR
	_out_dir_edit.placeholder_text = "res://tables"
	box.add_child(_out_dir_edit)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)

	add_child(box)
	confirmed.connect(_on_export)
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed() -> void:
	if visible:
		_refresh_tables()


## 重新扫描源目录并重建表清单行（勾选全开、类名回填默认值）。
func _refresh_tables() -> void:
	_row_ctrls = []
	for child in _list_box.get_children():
		child.queue_free()

	var scan := CodegenScript.scan_tables(SOURCE_DIR)
	if scan["tables"].is_empty():
		_set_status("未发现任何可导出的表（源目录 %s）" % SOURCE_DIR)
		return
	for td in scan["tables"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var check := CheckBox.new()
		check.button_pressed = true
		row.add_child(check)

		var edit := LineEdit.new()
		edit.custom_minimum_size = Vector2(180, 0)
		edit.text = str(td["default_class"])
		row.add_child(edit)

		var info := Label.new()
		info.text = "%s  |  %s  |  %d 列" % [
			str(td["raw_name"]), str(td["source"]), int(td["col_count"])
		]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		_list_box.add_child(row)
		_row_ctrls.append({
			"check": check,
			"edit": edit,
			"raw": str(td["raw_name"]),
			"source": str(td["source"]),
			"default": str(td["default_class"]),
		})
	_set_status("找到 %d 张表，可勾选/改名后点「导出」" % _row_ctrls.size())


## 纯逻辑：采集控件当前值 -> export_all 的 opts（static，无 UI 依赖，可 headless 单测）。
##   checks   : Array[bool]         每张勾选状态
##   names    : Array[String]       每张当前类名输入（空串回退默认类名）
##   raws     : Array[String]       每张 raw_name
##   defaults : Array[String]       每张默认类名
##   formats  : Array[String]       勾选的格式值（".gd"/".table"/".tres"/".json"）
##   out_dir  : String              输出目录（res:// 前缀）
## 返回 {ok, out_dir, formats, tables_filter, name_override, error}
static func build_opts(checks: Array, names: Array, raws: Array, defaults: Array,
		formats: Array, out_dir: String) -> Dictionary:
	var od := str(out_dir).strip_edges()
	if not od.begins_with("res://"):
		return {"ok": false, "error": "输出目录必须以 res:// 开头（当前：%s）" % od, "out_dir": od}
	if formats.is_empty():
		return {"ok": false, "error": "请至少勾选一种输出格式", "out_dir": od}

	var tables_filter: Array = []
	var name_override := {}
	for i in raws.size():
		if not bool(checks[i]):
			continue
		tables_filter.append(str(raws[i]))
		var nm := str(names[i]).strip_edges()
		if nm == "":
			nm = str(defaults[i])
		name_override[str(raws[i])] = nm

	return {
		"ok": true,
		"out_dir": od,
		"formats": formats,
		"tables_filter": tables_filter,
		"name_override": name_override,
	}


## 校验输出目录是否合法（可被 codegen 写入）。
static func validate_out_dir(out_dir: String) -> String:
	var od := str(out_dir).strip_edges()
	if od == "":
		return "输出目录为空"
	if not od.begins_with("res://"):
		return "输出目录必须以 res:// 开头（当前：%s）" % od
	return ""


## 导出按钮回调：采集配置 -> export_all -> 汇总反馈（toaster/print）。
func _on_export() -> void:
	var checks: Array = []
	var names: Array = []
	var raws: Array = []
	var defaults: Array = []
	for rc in _row_ctrls:
		checks.append(rc["check"].button_pressed)
		names.append(rc["edit"].text)
		raws.append(rc["raw"])
		defaults.append(rc["default"])

	var fmts: Array = []
	for cb in _fmt_checks:
		if cb.button_pressed:
			fmts.append(str(cb.get_meta("format_value")))

	var opts := build_opts(checks, names, raws, defaults, fmts, _out_dir_edit.text)
	if not opts.get("ok", false):
		_set_status(str(opts.get("error", "配置不合法")))
		return

	var report := CodegenScript.export_all(SOURCE_DIR, str(opts["out_dir"]), {
		"formats": opts["formats"],
		"name_override": opts["name_override"],
		"tables_filter": opts["tables_filter"],
		"clear_out_dir": true,
	})
	last_report = report
	last_report["out_dir"] = opts["out_dir"]
	last_report["formats"] = opts["formats"]

	var toaster = _safe_toaster()
	if report.get("ok", false):
		var msg := "导出成功：%d 张表 -> %s（%d 个文件，格式 %s）" % [
			int(report["tables"].size()), str(opts["out_dir"]),
			int(report["files"].size()), ",".join(opts["formats"]),
		]
		if toaster != null:
			toaster.popup_str(msg)
		_set_status(msg)
	else:
		var errs: Array = report.get("errors", [])
		var first: String = errs[0].get("message", "未知错误") if errs.size() > 0 else "未知错误"
		var msg := "导出失败（%d 个问题）：%s" % [errs.size(), first]
		if toaster != null:
			toaster.popup_str(msg)
		print("[excel_dt][export_dialog] " + msg)
		for e in errs:
			print("  - [%s] %s" % [e.get("type", "?"), e.get("message", "")])
		_set_status(msg)


func _safe_toaster():
	if ClassDB.class_exists("EditorInterface"):
		return EditorInterface.get_editor_toaster()
	return null


func _set_status(msg: String) -> void:
	_status.text = msg
	print("[excel_dt][export_dialog] " + msg)

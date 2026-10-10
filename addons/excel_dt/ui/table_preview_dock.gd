@tool
class_name TablePreviewDock
extends VBoxContainer
## Excel 导表工具 M4 —— 编辑器内表格预览面板（Dock）。
## 无需打开外部工具，在编辑器里即可展开查看 Excel/CSV 数据：
##   - 复用 M1 解析（XlsxParser / CsvParser）
##   - 复用 M2 清洗（Cleaner）/ 类型推断（TypeInfer）/ 校验（Validator）
##   - Tree 渲染行列：首行为表头（异色 + 列标推断类型），校验错误醒目列出（含行列定位）
##   - 「选择文件…」（FileDialog，限 xlsx/csv）/ examples 下拉 / 重新解析 / 导出 / 刷新
##
## 纯逻辑 build_preview() 为 static 无副作用函数，供 tools/verify_m4.gd headless 单测。

const XlsxScript := preload("res://addons/excel_dt/src/xlsx_parser.gd")
const CsvScript := preload("res://addons/excel_dt/src/csv_parser.gd")
const CleanerScript := preload("res://addons/excel_dt/src/cleaner.gd")
const TypeInferScript := preload("res://addons/excel_dt/src/type_infer.gd")
const ValidatorScript := preload("res://addons/excel_dt/src/validator.gd")
const CodegenScript := preload("res://addons/excel_dt/src/codegen.gd")
const ExportDialogScript := preload("res://addons/excel_dt/ui/export_dialog.gd")

const SOURCE_DIR := "res://examples"
const OUT_DIR := "res://tables"
const EMPTY_PLACEHOLDER := "<空>"

const COL_ERR_BG := Color(0.5, 0.12, 0.12, 0.4)
const COL_ERR_FG := Color(1.0, 0.35, 0.35)
const COL_EMPTY := Color(0.5, 0.5, 0.5)
const COL_INDEX := Color(0.62, 0.62, 0.62)

# ============================================================
# 纯逻辑：取数据 -> 整理成可渲染的表格行（headless 可单测，不依赖任何 UI）
# ============================================================
## headers: Array     parser 返回的字段名
## rows   : Array     Cleaner.clean_rows 之后的数据行（不含行号列）
## columns: Array     TypeInfer.infer 返回的列推断 [ {name,type,elem_type,...} ]
## errors : Array     Validator.validate 返回的错误 [{type,row,col,col_name,message}]
## 返回 {
##   column_titles: Array[String]  首列为 "#"，其余为 "字段名  [类型]"
##   data         : Array[Array[String]]  每行首列为 1 起的行号
##   error_rows   : Array[int]     命中校验错误的行号（clean 数据行，1 起）
##   error_lines  : Array[String]  "行2 列3(hp)：必填值为空"
##   column_count : int
##   row_count    : int
## }
static func build_preview(headers: Array, rows: Array, columns: Array, errors: Array) -> Dictionary:
	var titles: Array = ["#"]
	for ci in headers.size():
		titles.append(_column_title(headers[ci], _column_meta(columns, ci)))

	var data: Array = []
	for ri in rows.size():
		var line: Array = [str(ri + 1)]
		var cells: Array = rows[ri] if ri < rows.size() else []
		for ci in headers.size():
			var cell: Variant = cells[ci] if ci < cells.size() else ""
			line.append(_cell_text(cell))
		data.append(line)

	var error_lines: Array = []
	var error_rows: Array = []
	for e in errors:
		var row: int = int(e.get("row", 0))
		var col: int = int(e.get("col", 0))
		var cname: String = str(e.get("col_name", ""))
		var msg: String = str(e.get("message", ""))
		error_lines.append("行%d 列%d(%s)：%s" % [row, col, cname, msg])
		if row >= 1 and not error_rows.has(row):
			error_rows.append(row)

	return {
		"column_titles": titles,
		"data": data,
		"error_rows": error_rows,
		"error_lines": error_lines,
		"column_count": titles.size(),
		"row_count": data.size(),
	}


static func _column_meta(columns: Array, ci: int) -> Dictionary:
	return columns[ci] if ci < columns.size() else {}


static func _column_title(header: Variant, meta: Dictionary) -> String:
	var t := str(meta.get("type", "String"))
	match t:
		TypeInferScript.T_ARRAY:
			var elem := str(meta.get("elem_type", ""))
			if elem == "" or elem == "Array":
				t = "Array"
			else:
				t = "Array[%s]" % elem
		TypeInferScript.T_ENUM:
			t = "enum"
		TypeInferScript.T_RESOURCE:
			t = "Resource"
	return "%s  [%s]" % [str(header), t]


static func _cell_text(cell: Variant) -> String:
	if cell == null:
		return EMPTY_PLACEHOLDER
	var s := str(cell)
	return EMPTY_PLACEHOLDER if s.strip_edges() == "" else s


# ============================================================
# UI 构建（仅编辑器内使用）
# ============================================================
var _option: OptionButton
var _file_dialog: FileDialog
var _tree: Tree
var _err_root: VBoxContainer
var _status: Label
var _current_path := ""
var _current_sheets: Array = []


func _ready() -> void:
	set_custom_minimum_size(Vector2(460, 0))
	_build_ui()
	_refresh_sources()


func _build_ui() -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)

	_option = OptionButton.new()
	_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_option.item_selected.connect(_on_option_selected)
	bar.add_child(_option)

	var btn_pick := Button.new()
	btn_pick.text = "选择文件…"
	btn_pick.pressed.connect(_on_pick_file)
	bar.add_child(btn_pick)

	var btn_reparse := Button.new()
	btn_reparse.text = "重新解析"
	btn_reparse.pressed.connect(_on_reparse)
	bar.add_child(btn_reparse)

	var btn_export := Button.new()
	btn_export.text = "导出到 res://tables"
	btn_export.pressed.connect(_on_export)
	bar.add_child(btn_export)

	var btn_export_opts := Button.new()
	btn_export_opts.text = "导出选项…"
	btn_export_opts.pressed.connect(_open_export_options)
	bar.add_child(btn_export_opts)

	var btn_refresh := Button.new()
	btn_refresh.text = "刷新"
	btn_refresh.pressed.connect(_on_refresh)
	bar.add_child(btn_refresh)
	add_child(bar)

	_tree = Tree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# 注意：Tree.columns 最小为 1，禁止赋 0（否则触发 set_columns 断言崩溃）
	_tree.columns = 1
	_tree.column_titles_visible = true
	_tree.hide_root = true
	add_child(_tree)

	_err_root = VBoxContainer.new()
	_err_root.visible = false
	add_child(_err_root)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)

	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.filters = PackedStringArray(["*.xlsx ; Excel 工作簿", "*.csv ; CSV 文件"])
	_file_dialog.file_selected.connect(_on_file_selected)
	add_child(_file_dialog)


## 扫描 examples 下 .xlsx/.csv 填入下拉，并自动加载当前/首个文件。
func _refresh_sources() -> void:
	var prev := _current_path
	_option.clear()
	var dir := DirAccess.open(SOURCE_DIR)
	if dir == null:
		_set_status("无法访问 %s（错误码 %d）" % [SOURCE_DIR, DirAccess.get_open_error()])
		return
	dir.list_dir_begin()
	var names: Array = []
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() \
				and (fname.to_lower().ends_with(".xlsx") or fname.to_lower().ends_with(".csv")):
			names.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	names.sort()
	for n in names:
		_option.add_item(n, 0)
		_option.set_item_metadata(_option.item_count - 1, SOURCE_DIR + "/" + n)
	if _option.item_count == 0:
		_set_status("examples 下未发现 .xlsx/.csv，请放置示例或点「选择文件…」")
		return
	var target := 0
	for i in _option.item_count:
		if str(_option.get_item_metadata(i)) == prev:
			target = i
			break
	_option.select(target)
	_on_option_selected(target)


func _on_option_selected(idx: int) -> void:
	var path := str(_option.get_item_metadata(idx))
	_load_preview(path)


func _on_pick_file() -> void:
	_file_dialog.popup_centered_ratio(0.6)


func _on_file_selected(path: String) -> void:
	_load_preview(path)


func _on_reparse() -> void:
	if _current_path != "":
		_load_preview(_current_path)


func _on_refresh() -> void:
	_refresh_sources()


## 导出：扫描 examples 全量导出到 res://tables（与 Tools 菜单动作一致，避免误删其他表）。
func _on_export() -> void:
	var rep := CodegenScript.export_all(SOURCE_DIR, OUT_DIR)
	if rep.get("ok", false):
		_set_status("已导出 %d 张表 -> %s（%d 个文件）"
				% [rep["tables"].size(), OUT_DIR, rep["files"].size()])
	else:
		var errs: Array = rep.get("errors", [])
		var first: String = errs[0].get("message", "未知错误") if errs.size() > 0 else "未知错误"
		_set_status("导出失败（%d 个问题）：%s" % [errs.size(), first])


## 交互式导出：打开「导出选项…」对话框（表清单勾选/类名编辑 + 格式勾选 + 目录选择）。
func _open_export_options() -> void:
	var dlg: ConfirmationDialog = ExportDialogScript.new()
	EditorInterface.get_base_control().add_child(dlg)
	# 对话框关闭后自动释放，避免重复打开累积节点
	dlg.visibility_changed.connect(func() -> void:
		if not dlg.visible:
			dlg.queue_free()
	)
	dlg.popup_centered_ratio(0.7)


# ============================================================
# 解析 -> 清洗 -> 推断 -> 校验 -> 渲染
# ============================================================
func _load_preview(path: String) -> void:
	_current_path = path
	_current_sheets = []
	var parsed: Dictionary
	if path.to_lower().ends_with(".xlsx"):
		parsed = XlsxScript.parse_file(path)
	else:
		parsed = CsvScript.parse_file(path)
	if not parsed.get("ok", false):
		_set_status("解析失败：%s" % parsed.get("error", "未知错误"))
		_tree.clear()
		_err_root.visible = false
		return

	var headers: Array = parsed.get("headers", [])
	var rows: Array = parsed.get("rows", [])
	if parsed.get("format", "") == "xlsx":
		_current_sheets = (parsed.get("sheets", {}) as Dictionary).keys()
	# 只预览 active sheet（xlsx 首个 sheet）；状态栏注明 sheet 列表

	var clean := CleanerScript.clean_rows(rows)
	var infer := TypeInferScript.infer(headers, clean.get("rows", []))
	var vd := ValidatorScript.validate(headers, clean.get("rows", []), infer)

	var preview := build_preview(
		headers, clean.get("rows", []), infer.get("columns", []), vd.get("errors", [])
	)
	_render(preview, vd.get("errors", []))

	var meta := "表：%s | %d 列 x %d 行" % [path.get_file(), headers.size(), preview["row_count"]]
	if _current_sheets.size() > 0:
		meta += " | sheet[首个：%s / 共 %d]" % [str(_current_sheets[0]), _current_sheets.size()]
	meta += " | 清洗:-空行 %d,-注释 %d" % [clean.get("dropped_empty", 0), clean.get("dropped_comment", 0)]
	meta += " | 校验错误 %d" % vd.get("error_count", 0)
	_set_status(meta)


func _render(preview: Dictionary, errors: Array) -> void:
	_tree.clear()
	_tree.columns = preview["column_count"]
	for c in preview["column_titles"].size():
		_tree.set_column_title(c, str(preview["column_titles"][c]))

	var root := _tree.create_item()
	var err_rows: Array = preview["error_rows"]
	for line in preview["data"]:
		var item := _tree.create_item(root)
		var is_err: bool = err_rows.has(int(String(line[0])))
		for ci in line.size():
			item.set_cell_mode(ci, TreeItem.CELL_MODE_STRING)
			item.set_text(ci, String(line[ci]))
			if ci == 0:
				item.set_custom_color(0, COL_INDEX)
			elif is_err:
				item.set_custom_color(ci, COL_ERR_FG)
				item.set_custom_bg_color(ci, COL_ERR_BG)
			elif String(line[ci]) == EMPTY_PLACEHOLDER:
				item.set_custom_color(ci, COL_EMPTY)

	# 错误区：醒目列出（含行列定位）
	for child in _err_root.get_children():
		child.queue_free()
	var error_lines: Array = preview["error_lines"]
	if error_lines.size() > 0:
		var t := Label.new()
		t.text = "校验错误（%d 条）" % error_lines.size()
		t.add_theme_color_override("font_color", COL_ERR_FG)
		t.add_theme_font_size_override("font_size", 15)
		_err_root.add_child(t)
		for e in error_lines:
			var lb := Label.new()
			lb.text = "  " + String(e)
			lb.add_theme_color_override("font_color", COL_ERR_FG)
			_err_root.add_child(lb)
		_err_root.visible = true
	else:
		_err_root.visible = false


func _set_status(msg: String) -> void:
	_status.text = msg
	print("[excel_dt][dock] " + msg)

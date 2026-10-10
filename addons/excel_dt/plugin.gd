@tool
extends EditorPlugin
## Excel 导表工具 —— 编辑器插件入口。
## M1：解析层 + 注册导入器（.xlsx/.csv 可见可导入）。
## M2：类型推断 / 清洗 / 校验（在导入器中接入）。
## M3：代码/资源生成器（一键全量导出到 res://tables/）—— Tools 菜单动作。

const MENU_NAME := "Excel 导表工具"
const EXPORT_MENU_NAME := "Excel 导表工具：一键全量导出到 res://tables"
const EXPORT_OPTS_MENU_NAME := "Excel 导表工具：导出选项…"

const CodegenScript := preload("res://addons/excel_dt/src/codegen.gd")
const ImportPluginScript := preload("res://addons/excel_dt/src/excel_table_import_plugin.gd")
const DockScript := preload("res://addons/excel_dt/ui/table_preview_dock.gd")
const ExportDialogScript := preload("res://addons/excel_dt/ui/export_dialog.gd")

const SOURCE_DIR := "res://examples"
const OUT_DIR := "res://tables"

var _importer: EditorImportPlugin
var _dock: Control
var _export_dialog: ConfirmationDialog


## 声明本插件识别的扩展名（辅助；主力显示逻辑由下方导入器接管）。
func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["xlsx", "csv"])


func _enter_tree() -> void:
	_importer = ImportPluginScript.new()
	add_import_plugin(_importer)
	add_tool_menu_item(MENU_NAME, Callable(self, "_on_tools_menu_clicked"))
	add_tool_menu_item(EXPORT_MENU_NAME, Callable(self, "_on_export_all"))
	add_tool_menu_item(EXPORT_OPTS_MENU_NAME, Callable(self, "_open_export_options"))
	# M4：注册表格预览面板到右侧 Dock（常驻，可插拔）
	_dock = DockScript.new()
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, _dock)
	print("[excel_dt] Excel 导表工具已启用（M1 解析 + M2 推断 + M3 生成 + M4 预览 + 导出选项就绪）")


func _exit_tree() -> void:
	if _importer != null:
		remove_import_plugin(_importer)
		_importer = null
	remove_tool_menu_item(MENU_NAME)
	remove_tool_menu_item(EXPORT_MENU_NAME)
	remove_tool_menu_item(EXPORT_OPTS_MENU_NAME)
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
	if _export_dialog != null:
		_export_dialog.queue_free()
		_export_dialog = null


func _on_tools_menu_clicked() -> void:
	var toaster := EditorInterface.get_editor_toaster()
	if toaster != null:
		toaster.popup_str("Excel 导表工具：解析/M2 推断/校验已就绪；请使用菜单项「一键全量导出到 res://tables」生成读表代码与资源。")
	else:
		print("[excel_dt] 解析/推断/校验已就绪；可使用「一键全量导出到 res://tables」生成读表代码与资源。")


## M3 入口：全量重导模式 —— 扫描 SOURCE_DIR 下所有 .xlsx/.csv，
## 先整体校验标识符（非法/重名），合法后重建 res://tables/ 并生成 .gd/.tres/.json。
func _on_export_all() -> void:
	var report := CodegenScript.export_all(SOURCE_DIR, OUT_DIR)
	var toaster := EditorInterface.get_editor_toaster()
	if report.get("ok", false):
		var n: int = report["tables"].size()
		var fc: int = report["files"].size()
		var msg := "导出成功：%d 张表 -> res://tables/（共 %d 个文件）" % [n, fc]
		if toaster != null:
			toaster.popup_str(msg)
		print("[excel_dt] " + msg)
	else:
		var errs: Array = report.get("errors", [])
		var detail: String = errs[0].get("message", "未知错误") if errs.size() > 0 else "未知错误"
		var msg := "导出失败：%d 个问题（首个：%s）" % [errs.size(), detail]
		if toaster != null:
			toaster.popup_str(msg)
		print("[excel_dt] " + msg)
		for e in errs:
			print("  - [%s] %s" % [e.get("type", "?"), e.get("message", "")])


## 交互式导出入口：打开「导出选项…」对话框（表清单勾选/类名编辑 + 格式勾选 + 目录选择）。
func _open_export_options() -> void:
	if _export_dialog == null:
		_export_dialog = ExportDialogScript.new()
		EditorInterface.get_base_control().add_child(_export_dialog)
	_export_dialog.popup_centered_ratio(0.78)

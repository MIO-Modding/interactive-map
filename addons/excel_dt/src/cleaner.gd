class_name TableCleaner
extends RefCounted
## Excel 导表工具 M2 —— 脏数据清洗。
##
## 过滤规则（按行）：
##   1) 全空行（所有单元格为空/纯空白）；
##   2) 注释/备注行：
##      - 首个非空单元格以 "#" 或 "//" 开头；
##      - 任意单元格包含 AI 生成备注标记（如 "（内容由AI生成，仅供参考）"）。
##
## 只做过滤，不做删除/覆盖单元格内容。

const AI_MARKERS := [
	"（内容由AI生成，仅供参考）",
	"(内容由AI生成，仅供参考)",
	"内容由AI生成",
	"AI生成",
]

## 返回 { rows: Array(清洗后), dropped_empty: int, dropped_comment: int }
static func clean_rows(rows: Array) -> Dictionary:
	var out: Array = []
	var dropped_empty := 0
	var dropped_comment := 0
	for row in rows:
		if _is_empty_row(row):
			dropped_empty += 1
			continue
		if _is_comment_row(row):
			dropped_comment += 1
			continue
		out.append(row)
	return {
		"rows": out,
		"dropped_empty": dropped_empty,
		"dropped_comment": dropped_comment,
	}


static func _is_empty_row(row: Array) -> bool:
	for cell in row:
		if _has_content(cell):
			return false
	return true


static func _has_content(cell: Variant) -> bool:
	if cell is String:
		return (cell as String).strip_edges() != ""
	return cell != null and str(cell) != ""


static func _is_comment_row(row: Array) -> bool:
	var first_content := ""
	for cell in row:
		if not (cell is String):
			continue
		var s := (cell as String).strip_edges()
		if s == "":
			continue
		first_content = s
		break
	if first_content == "":
		return false
	if first_content.begins_with("#") or first_content.begins_with("//"):
		return true
	for cell in row:
		if not (cell is String):
			continue
		var s := cell as String
		for m in AI_MARKERS:
			if s.contains(m):
				return true
	return false

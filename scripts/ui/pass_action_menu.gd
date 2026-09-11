class_name PassActionMenu
extends CanvasLayer
## 패스 액션 선택 목록.
##
## **잠긴 항목은 회색으로 두지 않고 아예 빼서 받는다**(설계 §3-2). 목록을 거르는 일은
## `PassActionJudge.available_actions()`가 하고, 이 노드는 받은 것을 그리기만 한다 —
## 판정 규칙이 UI에 새어 들어가면 헤드리스로 검증할 수 없게 된다.
##
## 커서 이동은 `ui_up`/`ui_down`, 확정은 커스텀 `interact`다(설계 §1-1의 분리 규칙).
## 목록이 떠 있는 동안은 이동이 잠기므로 방향키 이중 바인딩이 문제되지 않는다.

const ITEM_FONT_SIZE: int = 13
## 고르지 않은 항목. 0.72는 선택 항목과 차이가 작아 어느 쪽이 커서인지 한눈에 안 들어왔다.
const ITEM_COLOR: Color = Color(0.66, 0.66, 0.61)
const SELECTED_COLOR: Color = Color(1.0, 0.93, 0.66)
const CURSOR: String = "▶ "
## 커서 자리를 비워 두는 공백. 반각 공백 3개로는 "▶ "보다 6px 짧아 선택이 바뀔 때 항목 글자가
## 좌우로 흔들렸다(_screenshots/ui_menu_zoom.png). 전각 공백(U+3000)이 커서 폭과 맞는다.
const INDENT: String = "　 "

## 선택 강조 막대. 색만 바꾸면 저해상도에서 명도 차가 잘 안 보인다 —
## 원작도 고른 항목 뒤에 판을 깐다.
const HIGHLIGHT_BG: Color = Color(0.85, 0.72, 0.34, 0.2)
const HIGHLIGHT_EDGE: Color = Color(0.96, 0.85, 0.5, 0.9)

## 목록 판 크기. 아랫변을 고정하고 항목 수만큼 위로 자란다(씬 주석 참고).
const PANEL_BOTTOM: float = 236.0
## 위 여백 + 제목 + 구분선까지의 높이. 씬의 Items.offset_top과 같아야 한다.
const PANEL_HEAD: float = 32.0
const PANEL_FOOT: float = 8.0
## 항목 한 줄의 높이를 고정한다. 폰트 최소 높이에 맡기면 판 높이 계산과 어긋나 아래 여백이 흔들린다.
const ROW_HEIGHT: float = 19.0
## 씬의 Items separation과 같아야 한다.
const ROW_SEPARATION: float = 1.0

## 목록이 떠오르는 시간. 대화창(0.12)보다 짧다 — 대사를 다 읽고 이어지는 화면이라
## 같은 속도면 흐름이 한 번 더 끊긴 것처럼 느껴진다.
const OPEN_TIME: float = 0.08

## 항목 라벨에 쓸 폰트. 씬에서 SystemFont를 주입한다 —
## 지정하지 않으면 기본 폰트에 한글 글리프가 없어 항목이 전부 □로 나온다.
@export var item_font: Font = null

@onready var _root: Control = $Root
@onready var _panel: Panel = $Root/Panel
@onready var _items: VBoxContainer = $Root/Panel/Items

var _entries: Array[NpcPassAction] = []
var _selected: int = 0

var _selected_style: StyleBoxFlat = null
var _normal_style: StyleBoxEmpty = null
var _open_tween: Tween = null


func _ready() -> void:
	_build_styles()
	_root.visible = false


## 항목 라벨의 배경 스타일. 씬에 두지 않고 여기서 만드는 이유: 항목 라벨 자체가
## 런타임 생성이라 스타일도 같은 곳에 있어야 둘의 여백이 어긋나지 않는다.
func _build_styles() -> void:
	_selected_style = StyleBoxFlat.new()
	_selected_style.bg_color = HIGHLIGHT_BG
	_selected_style.border_color = HIGHLIGHT_EDGE
	_selected_style.border_width_left = 2
	_selected_style.anti_aliasing = false
	_selected_style.content_margin_left = 5.0
	_selected_style.content_margin_right = 4.0
	_selected_style.content_margin_top = 1.0
	_selected_style.content_margin_bottom = 1.0

	# 선택 여부에 따라 글자가 좌우로 흔들리지 않도록 여백을 맞춘다(강조 막대 2px + 5px).
	_normal_style = StyleBoxEmpty.new()
	_normal_style.content_margin_left = 7.0
	_normal_style.content_margin_right = 4.0
	_normal_style.content_margin_top = 1.0
	_normal_style.content_margin_bottom = 1.0


func is_open() -> bool:
	return _root.visible


func open(entries: Array[NpcPassAction]) -> void:
	_entries = entries
	_selected = 0
	_rebuild()
	_resize_panel()
	_root.visible = not _entries.is_empty()
	if _root.visible:
		_play_open()


func close() -> void:
	_root.visible = false
	_stop_open()
	_entries = []
	_selected = 0
	_clear_items()


func item_count() -> int:
	return _entries.size()


func selected_index() -> int:
	return _selected


func selected_entry() -> NpcPassAction:
	if _selected < 0 or _selected >= _entries.size():
		return null
	return _entries[_selected]


## 커서 이동. 목록 양 끝에서 반대편으로 감싼다 — 항목이 2개뿐이라
## 끝에서 막히면 "고장 났나" 싶은 순간이 생긴다.
func move_selection(step: int) -> void:
	if _entries.is_empty():
		return
	_selected = posmod(_selected + step, _entries.size())
	_refresh_labels()


func _rebuild() -> void:
	_clear_items()
	for entry in _entries:
		var label := Label.new()
		if item_font != null:
			label.add_theme_font_override(&"font", item_font)
		label.add_theme_font_size_override(&"font_size", ITEM_FONT_SIZE)
		# 줄 높이를 고정해 판 높이 계산(_resize_panel)과 어긋나지 않게 한다.
		label.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_items.add_child(label)
	_refresh_labels()


func _refresh_labels() -> void:
	for i in _items.get_child_count():
		var label := _items.get_child(i) as Label
		if label == null:
			continue
		var entry := _entries[i]
		var title := entry.action.display_name if entry != null and entry.action != null else "?"
		var chosen := i == _selected
		label.text = (CURSOR if chosen else INDENT) + title
		label.add_theme_color_override(&"font_color", SELECTED_COLOR if chosen else ITEM_COLOR)
		label.add_theme_stylebox_override(&"normal", _selected_style if chosen else _normal_style)


## 항목 수에 맞춰 판 높이를 정한다. 아랫변은 고정이므로 위로 자란다.
func _resize_panel() -> void:
	var rows := float(_entries.size())
	var height := PANEL_HEAD + PANEL_FOOT + rows * ROW_HEIGHT + maxf(rows - 1.0, 0.0) * ROW_SEPARATION
	_panel.offset_bottom = PANEL_BOTTOM
	_panel.offset_top = PANEL_BOTTOM - height


# ── 연출 ──────────────────────────────────────────────────────────────────
#
# `modulate`만 만진다. 판 위치·크기는 _resize_panel이 매번 확정값으로 다시 쓰므로
# 연출이 중간에 끊겨도 다음에 열 때 어긋난 상태가 남지 않는다.

func _play_open() -> void:
	if not is_inside_tree():
		return
	_stop_open()
	_root.modulate.a = 0.0
	_open_tween = create_tween()
	_open_tween.tween_property(_root, ^"modulate:a", 1.0, OPEN_TIME)


func _stop_open() -> void:
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	_open_tween = null
	_root.modulate.a = 1.0


func _clear_items() -> void:
	for child in _items.get_children():
		_items.remove_child(child)
		child.queue_free()

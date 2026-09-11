class_name DialogueBox
extends CanvasLayer
## 대화창. **페이지 진행 상태를 소유하는 유일한 곳이다**(설계 §2-4).
##
## 진행 인덱스를 `NpcData`(.tres)에 두면 리소스 인스턴스가 프로젝트 전체에서 공유되므로
## 같은 리소스를 참조하는 다른 NPC에게 "몇 번째 대사까지 읽었는가"가 새어 나간다.
## 그래서 대사 배열은 열 때 복사해 받고, 진행은 여기서만 센다.
##
## 상태 전이는 이 노드가 결정하지 않는다 — `advance()`가 "더 보여줄 것이 있었는가"만 돌려주고,
## 다음 상태(패스 액션 목록으로 갈지 대화를 끝낼지)는 InteractionController가 정한다.

## 타이핑 속도(초당 글자). 설계 §2-2의 값.
const CHARS_PER_SECOND: float = 30.0

## 등장 연출: 아래에서 이만큼(px, 640×360 좌표계) 밀려 올라오며 나타난다.
## 6px 이상 주면 저해상도에서 판이 "튀어 오르는" 것처럼 보여 대사보다 연출이 눈에 띈다.
const OPEN_RISE: float = 5.0
## 0.12초. 더 길면 말을 건 반응이 굼떠 보이고, 더 짧으면 그냥 튀어나온 것과 구분되지 않는다.
const OPEN_TIME: float = 0.12

## 진행 표시(▼) 깜빡임. 한 주기 0.9초, 알파 1.0 ↔ 0.25.
## 완전히 끄면(0) 깜빡임이 아니라 점멸로 보여 시선을 너무 끈다.
const PROMPT_BLINK_TIME: float = 0.45
const PROMPT_BLINK_MIN: float = 0.25

@onready var _root: Control = $Root
@onready var _panel: Panel = $Root/Panel
@onready var _name_label: Label = $Root/Panel/NamePlate/NameLabel
@onready var _text_label: Label = $Root/Panel/TextLabel
@onready var _prompt: Label = $Root/Panel/Prompt

var _pages: PackedStringArray = PackedStringArray()
var _page_index: int = 0

## 지금까지 드러낸 글자 수. 정수로 세면 프레임률에 따라 타이핑 속도가 달라진다.
var _typed: float = 0.0

## 등장 연출용. 씬 파일에 적힌 기준 오프셋을 들고 있다가 연출이 끝나면 **정확히** 되돌린다 —
## 연출이 중간에 끊겨 판이 몇 px 어긋난 채 남으면 그 뒤의 구도 판단이 전부 어긋난다.
var _panel_offset_top: float = 0.0
var _panel_offset_bottom: float = 0.0
var _open_tween: Tween = null
var _blink_tween: Tween = null


func _ready() -> void:
	# 오프셋은 씬에 직렬화된 값이라 레이아웃 계산 전에도 읽을 수 있다.
	# position/size로 잡으면 첫 프레임 전에는 아직 0이라 연출이 화면 밖에서 시작한다.
	_panel_offset_top = _panel.offset_top
	_panel_offset_bottom = _panel.offset_bottom
	_root.visible = false
	set_process(false)


func _process(delta: float) -> void:
	_typed += delta * CHARS_PER_SECOND
	_text_label.visible_characters = int(_typed)
	if not is_typing():
		_finish_typing()


func is_open() -> bool:
	return _root.visible


## 현재 페이지가 아직 다 찍히지 않았는가.
func is_typing() -> bool:
	return _typed < float(_text_label.text.length())


## 여러 페이지짜리 대사를 연다.
func open(speaker: String, pages: PackedStringArray) -> void:
	_pages = pages.duplicate()
	# 대사가 하나도 없는 NPC라도 빈 대화창이 뜨는 편이 낫다 —
	# 아무 반응이 없으면 "말을 걸 수 없는 NPC"로 오해한다.
	if _pages.is_empty():
		_pages = PackedStringArray([""])
	_page_index = 0
	_name_label.text = speaker
	# 이미 떠 있는 창에 다음 대사를 넣는 경우(패스 액션 결과)에는 등장 연출을 다시 재생하지 않는다.
	# 재생하면 결과 대사가 나올 때 창이 한 번 깜빡여 "닫혔다 다시 열렸다"로 읽힌다.
	var was_open := _root.visible
	_root.visible = true
	if not was_open:
		_play_open()
	_show_page()


## 결과 대사처럼 한 줄만 띄운다.
func show_line(speaker: String, line: String) -> void:
	open(speaker, PackedStringArray([line]))


## 진행 요청. 아직 보여줄 것이 남아 있으면 true.
##
## 타이핑 중이면 다음 페이지로 넘기지 않고 현재 페이지를 즉시 완성한다(설계 §2-2).
## 이걸 빼면 빠르게 누르는 플레이어가 대사를 통째로 놓친다.
func advance() -> bool:
	if not _root.visible:
		return false
	if is_typing():
		_complete_typing()
		return true
	if _page_index + 1 < _pages.size():
		_page_index += 1
		_show_page()
		return true
	return false


func close() -> void:
	_root.visible = false
	set_process(false)
	# 연출은 닫을 때 반드시 원상복구한다. 퇴장 연출을 넣지 않은 것도 같은 이유다 —
	# `is_open()`이 `_root.visible`이라 페이드아웃 동안 "열려 있음"이 되고,
	# 그사이에 다음 대화가 시작되면 사라지는 중인 창에 새 대사가 들어간다.
	_stop_open()
	_stop_blink()
	_pages = PackedStringArray()
	_page_index = 0


## 현재 페이지의 전체 문구(타이핑 진행과 무관). 검증에서 쓴다.
func current_text() -> String:
	return _text_label.text


func page_index() -> int:
	return _page_index


func page_count() -> int:
	return _pages.size()


func _show_page() -> void:
	_text_label.text = _pages[_page_index]
	_typed = 0.0
	_text_label.visible_characters = 0
	_prompt.visible = false
	_stop_blink()
	# 빈 문자열이면 타이핑할 것이 없다. set_process(true)로 두면 첫 프레임까지 프롬프트가 안 뜬다.
	if _text_label.text.is_empty():
		_finish_typing()
	else:
		set_process(true)


func _complete_typing() -> void:
	_typed = float(_text_label.text.length())
	_finish_typing()


func _finish_typing() -> void:
	set_process(false)
	_typed = float(_text_label.text.length())
	_text_label.visible_characters = -1
	_prompt.visible = true
	_start_blink()


# ── 연출 ──────────────────────────────────────────────────────────────────
#
# 연출은 전부 `modulate`와 오프셋만 만진다. 상태(`visible`·페이지 인덱스)는 건드리지 않는다 —
# 상태 머신이 보는 값을 연출이 바꾸면 "화면이 끝나야 다음 입력을 받는" 구조가 되어
# 헤드리스 검증이 프레임 타이밍에 의존하게 된다.

func _play_open() -> void:
	if not is_inside_tree():
		return
	_stop_open()
	_root.modulate.a = 0.0
	_panel.offset_top = _panel_offset_top + OPEN_RISE
	_panel.offset_bottom = _panel_offset_bottom + OPEN_RISE
	_open_tween = create_tween().set_parallel()
	_open_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(_root, ^"modulate:a", 1.0, OPEN_TIME)
	_open_tween.tween_property(_panel, ^"offset_top", _panel_offset_top, OPEN_TIME)
	_open_tween.tween_property(_panel, ^"offset_bottom", _panel_offset_bottom, OPEN_TIME)


## 연출을 멈추고 기준값으로 되돌린다. 중간에 끊겨도 판이 어긋난 채 남지 않는다.
func _stop_open() -> void:
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	_open_tween = null
	_root.modulate.a = 1.0
	_panel.offset_top = _panel_offset_top
	_panel.offset_bottom = _panel_offset_bottom


func _start_blink() -> void:
	if not is_inside_tree():
		return
	if _blink_tween != null and _blink_tween.is_valid():
		return
	_prompt.modulate.a = 1.0
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_property(_prompt, ^"modulate:a", PROMPT_BLINK_MIN, PROMPT_BLINK_TIME)
	_blink_tween.tween_property(_prompt, ^"modulate:a", 1.0, PROMPT_BLINK_TIME)


func _stop_blink() -> void:
	if _blink_tween != null and _blink_tween.is_valid():
		_blink_tween.kill()
	_blink_tween = null
	_prompt.modulate.a = 1.0

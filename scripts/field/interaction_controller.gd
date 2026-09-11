class_name InteractionController
extends Node
## 필드 상태 머신의 **유일한 소유자**(설계 §4-1). 대화·패스 액션·시스템 메뉴가 한 상태를 공유한다.
##
## `FieldPlayer`는 자기 상태를 갖지 않고 `is_movement_locked()`만 질의한다.
## 이동을 잠글 이유는 앞으로 계속 늘어나는데(대화·메뉴·컷신·전투 진입 연출),
## 플레이어가 사유를 각각 알아야 하면 사유가 늘 때마다 플레이어 코드를 고쳐야 하고
## 해제를 한 군데 빠뜨리면 영원히 못 움직이는 버그가 난다.
##
## 판정 규칙은 여기 없다 — 전부 `PassActionJudge`(static)에 있다. 규칙이 노드 안에 묻히면
## 씬을 띄우고 입력을 흉내내야만 검증할 수 있게 된다.

enum State {
	FREE,        ## 걸어 다닐 수 있는 평상시
	TALKING,     ## 대화창이 떠 있다
	PASS_MENU,   ## 패스 액션 목록이 떠 있다
	RESULT,      ## 패스 액션 결과 대사가 떠 있다
	SYSTEM_MENU, ## 시스템 메뉴 (M1에는 상태와 전이만 있고 UI는 없다)
}

signal state_changed(previous: int, current: int)
signal dialogue_started(npc: NpcData)
signal dialogue_finished(npc: NpcData)
## M3 전투 진입 훅(설계 §3-4). 구독하는 쪽에서 `action_id == "challenge" and success`를 보고
## 씬을 전환한다. **결과 처리 함수 안에서 직접 전환하지 말 것** — 그렇게 하면 M1의 스텁 대사와
## M3의 전투 진입이 같은 함수에 뒤섞여 M1 검증 경로가 사라진다.
signal pass_action_resolved(npc_id: String, action_id: String, success: bool)

## UI는 컨트롤러가 직접 만들어 자식으로 붙인다.
## 씬에 따로 배치하지 않는 이유: 상태 머신과 대화창의 페이지 진행은 한 몸이라
## 한쪽만 있는 상태가 성립하지 않는다. 컨트롤러만 띄우면 UI가 함께 살아 있어야
## 헤드리스 테스트에서 실제 화면 경로를 그대로 검증할 수 있다.
const DIALOGUE_BOX_SCENE: PackedScene = preload("res://scenes/ui/DialogueBox.tscn")
const PASS_ACTION_MENU_SCENE: PackedScene = preload("res://scenes/ui/PassActionMenu.tscn")

## 상호작용 후보를 탐지할 플레이어. 비워 두면 상호작용만 동작하지 않고 나머지는 그대로다
## (헤드리스 테스트는 플레이어 없이 상태 머신만 돌린다).
@export var player_path: NodePath

## 플레이어 아래의 감지용 Area3D 이름. 반경 1.2m는 그 노드 쪽에 있다(설계 §2-1).
@export var interact_area_name: StringName = &"InteractArea"

var state: State = State.FREE

## 플래그·골드를 읽고 쓸 대상. 기본값은 autoload GameState이고,
## 테스트는 격리된 인스턴스를 주입해 전역 플래그를 오염시키지 않는다.
##
## `GameState`/`DayNight`를 전역 식별자로 직접 쓰지 않고 `/root/`에서 찾아 넣는 이유:
## `--check-only`는 autoload를 모르기 때문에 "Identifier not found: GameState"를 낸다.
## 그 자체는 하네스가 걸러 주는 오탐이지만, **이 스크립트를 타입으로 참조하는 다른 스크립트가
## "Failed to compile depended scripts"로 함께 실패한다**(field_player.gd가 실제로 그랬다).
## 그건 걸러낼 수 없다 — 진짜 컴파일 실패와 구분이 안 되기 때문이다. 그래서 주입으로 바꿨다.
var game_state: Node = null

## 낮/밤 상태(autoload DayNight). 위와 같은 이유로 주입한다.
var day_night: Node = null

var _player: Node3D = null
var _interact_area: Area3D = null

var _dialogue: DialogueBox = null
var _menu: PassActionMenu = null

## 대화 상대. 노드가 아니라 데이터를 들고 있는다 —
## 판정·대사에 필요한 것은 전부 NpcData이고, 그래야 노드 없이도 검증할 수 있다.
var _partner: NpcData = null

## 지금 말을 걸 수 있는 상대(마커가 켜진 NPC). 후보가 바뀔 때만 갱신한다.
var _candidate: FieldNpc = null


func _ready() -> void:
	if game_state == null:
		game_state = get_node_or_null(^"/root/GameState")
	if day_night == null:
		day_night = get_node_or_null(^"/root/DayNight")

	_dialogue = DIALOGUE_BOX_SCENE.instantiate() as DialogueBox
	_dialogue.name = "DialogueBox"
	add_child(_dialogue)

	_menu = PASS_ACTION_MENU_SCENE.instantiate() as PassActionMenu
	_menu.name = "PassActionMenu"
	add_child(_menu)

	_player = get_node_or_null(player_path) as Node3D
	if _player != null:
		_interact_area = _player.get_node_or_null(NodePath(interact_area_name)) as Area3D
		if _interact_area == null:
			push_warning("InteractionController: 플레이어에 %s(Area3D)가 없어 말을 걸 수 없다." % interact_area_name)


## 겹침은 물리 프레임에 갱신되므로 _process가 아니라 여기서 본다.
func _physics_process(_delta: float) -> void:
	_update_candidate()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact"):
		handle_interact()
	elif event.is_action_pressed(&"cancel"):
		handle_cancel()
	elif event.is_action_pressed(&"menu"):
		handle_menu()
	elif event.is_action_pressed(&"toggle_phase"):
		handle_toggle_phase()
	elif state == State.PASS_MENU and event.is_action_pressed(&"ui_up"):
		_menu.move_selection(-1)
	elif state == State.PASS_MENU and event.is_action_pressed(&"ui_down"):
		_menu.move_selection(1)
	else:
		return

	# 여기까지 왔으면 이 입력은 우리가 처리했다. 특히 toggle_phase는 field.gd도 듣고 있는데,
	# 컨트롤러가 Field의 자식이라 입력이 먼저 오므로(입력은 트리 아래에서 위로 올라간다)
	# 여기서 소비하면 대화 중 시간대가 바뀌는 사고를 field.gd를 고치지 않고 막을 수 있다.
	get_viewport().set_input_as_handled()


## 이동을 잠가야 하는가. 지금은 `state != FREE`와 동치지만 함수로 감싸 둔다 —
## "메뉴는 열려 있어도 걸을 수 있다" 같은 변경이 오면 여기 한 곳만 고치면 된다(설계 §4-1).
func is_movement_locked() -> bool:
	return state != State.FREE


## 지금 말을 걸 수 있는 상대. 없으면 null.
func candidate() -> FieldNpc:
	return _candidate


func dialogue_box() -> DialogueBox:
	return _dialogue


func pass_action_menu() -> PassActionMenu:
	return _menu


# ── 입력 처리 (테스트가 직접 부를 수 있도록 공개) ──────────────────────────────

func handle_interact() -> void:
	match state:
		State.FREE:
			if _candidate != null and _candidate.npc_data != null:
				start_dialogue(_candidate.npc_data)
		State.TALKING:
			# advance()가 false면 마지막 페이지까지 다 봤다는 뜻이다.
			if not _dialogue.advance():
				_after_last_page()
		State.PASS_MENU:
			_confirm_pass_action()
		State.RESULT:
			_end_dialogue()
		State.SYSTEM_MENU:
			# M1에는 메뉴 항목이 없다. 상태와 전이만 만들어 두고 확정은 M2에서 붙인다.
			pass


func handle_cancel() -> void:
	match state:
		State.TALKING, State.PASS_MENU, State.RESULT:
			# 어느 페이지에서든 즉시 종료한다(설계 §2-2). 검증·데모에서 대사를 빨리 넘기기 위해서다.
			_end_dialogue()
		State.SYSTEM_MENU:
			_set_state(State.FREE)
		State.FREE:
			pass


func handle_menu() -> void:
	match state:
		State.FREE:
			_set_state(State.SYSTEM_MENU)
		State.SYSTEM_MENU:
			_set_state(State.FREE)
		_:
			pass


## 개발 편의용 낮/밤 토글. **FREE에서만 받는다**(설계 §2-3) —
## 대화 도중에 시간대가 바뀌면 대사 배열이 통째로 교체되어 페이지 인덱스가 배열 밖으로 나간다.
func handle_toggle_phase() -> void:
	if state == State.FREE and day_night != null:
		day_night.toggle()


# ── 대화 ──────────────────────────────────────────────────────────────────

## 대화를 시작한다. 노드가 아니라 데이터를 받는다 — 이벤트로 말을 거는 경우
## (표지판·연출)에도 그대로 쓸 수 있고, 테스트가 씬 없이 호출할 수 있다.
func start_dialogue(npc: NpcData) -> void:
	if npc == null:
		return
	_partner = npc
	_set_candidate(null)
	_set_state(State.TALKING)
	_dialogue.open(npc.display_name, npc.lines_for(_is_night()))
	dialogue_started.emit(npc)


## 마지막 페이지를 넘겼을 때. 쓸 수 있는 패스 액션이 있으면 목록으로, 없으면 종료(설계 §2-2).
func _after_last_page() -> void:
	var entries := PassActionJudge.available_actions(_partner, _is_night(), game_state)
	if entries.is_empty():
		_end_dialogue()
		return
	# 항목이 1개여도 목록을 띄운다 — 입력 흐름이 일정해야 조작이 학습된다(설계 §3-2).
	_menu.open(entries)
	_set_state(State.PASS_MENU)


func _end_dialogue() -> void:
	var finished := _partner
	_partner = null
	_menu.close()
	_dialogue.close()
	_set_state(State.FREE)
	if finished != null:
		dialogue_finished.emit(finished)


# ── 패스 액션 ─────────────────────────────────────────────────────────────

func _confirm_pass_action() -> void:
	var entry := _menu.selected_entry()
	if entry == null or entry.action == null:
		_end_dialogue()
		return
	_resolve_pass_action(entry)


## 판정 → 결과 적용 → 결과 대사 → 시그널. 규칙 자체는 PassActionJudge에 있다.
func _resolve_pass_action(entry: NpcPassAction) -> void:
	var npc := _partner
	var success := PassActionJudge.resolve(npc, entry, game_state)
	# result_line 안에서 npc.format_line()을 거친다. 빠뜨리면 화면에 {level}이 그대로 찍힌다.
	var line := PassActionJudge.result_line(npc, entry, success)

	_menu.close()
	_dialogue.show_line(npc.display_name, line)
	_set_state(State.RESULT)

	# M3 전투 진입 훅은 **여기**다(설계 §3-4). 이 함수 안에서 씬을 전환하지 않는다.
	pass_action_resolved.emit(npc.npc_id, entry.action.action_id, success)


# ── 내부 ──────────────────────────────────────────────────────────────────

func _is_night() -> bool:
	# DayNight를 못 찾으면 낮으로 본다. 밤으로 가정하면 밤 대사·밤 액션이 낮에 뜨는데,
	# 그건 "왜 이게 지금 나오지"로 이어져 원인을 찾기 어렵다.
	if day_night == null:
		return false
	return day_night.is_night


func _set_state(next: State) -> void:
	if next == state:
		return
	var previous := state
	state = next
	state_changed.emit(previous, next)


## 반경 안에서 가장 가까운 NPC 한 명만 후보로 둔다(설계 §2-1).
## 전방 판정은 넣지 않는다 — Y축 빌보드 스프라이트는 "어디를 보는지"가 시각적으로 모호해서
## 방향으로 실패시키면 플레이어가 원인을 이해하지 못한다.
func _update_candidate() -> void:
	if state != State.FREE or _interact_area == null or _player == null:
		_set_candidate(null)
		return

	var nearest: FieldNpc = null
	var nearest_distance := INF
	var origin := _player.global_position
	for area in _interact_area.get_overlapping_areas():
		var npc := area.get_parent() as FieldNpc
		if npc == null or npc.npc_data == null:
			continue
		var distance := origin.distance_squared_to(npc.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = npc
	_set_candidate(nearest)


func _set_candidate(npc: FieldNpc) -> void:
	if npc == _candidate:
		return
	if _candidate != null and is_instance_valid(_candidate):
		_candidate.set_highlighted(false)
	_candidate = npc
	if _candidate != null:
		_candidate.set_highlighted(true)

extends SceneTree
## M1 필드 상호작용(상태 머신 · 대화 진행 · 패스 액션) 검증 — 설계 §7의 V1~V9.
##
## **두 층으로 나뉜다.**
##
## 1. 규칙 검증 — 컨트롤러의 `handle_*()`를 직접 호출한다. 한 프레임 안에서 동기로 끝나므로
##    fps에 흔들리지 않는다. V2~V9의 판정 규칙이 여기 있다.
## 2. 통합 검증 — `FieldPlayer`·`FieldNpc`를 실제로 세우고 **입력 이벤트**를 쏜다.
##    1층만으로는 `_unhandled_input` → Area3D 대상 탐지 → 상태 전이로 이어지는 실제 경로가
##    통째로 비어 있게 된다. 검증 리포트(§2-1, §2-3)가 지적한 구멍이 이것이다:
##    `controller_path`를 비우거나 `InteractZone`을 지워도 1층은 전부 초록이었다.
##    물리(겹침·이동)는 프레임이 지나야 하므로 2층은 프레임 구동 단계 기계로 돈다.
##
## `GameState`와 `DayNight`는 격리 인스턴스를 주입한다. 실제 autoload를 쓰면 테스트가 켠 플래그가
## 다음 테스트로 새어 나가 순서에 따라 결과가 달라진다. 게다가 `--script`로 커스텀 MainLoop을
## 돌리면 autoload 전역 이름 자체가 없다(`headless_day_night.gd`의 주석과 같은 이유).
##
## `_init`이 아니라 `_process`에서 도는 이유: `_init` 시점에는 root가 아직 트리에 들어가지
## 않아 add_child를 해도 `_ready`가 실행되지 않는다(실측).
##
## **조건부 assert를 쓰지 않는다.** `if _resolved.size() == 1:`로 감싸면 시그널이 0회 발화했을 때
## 아무것도 단언하지 않고 초록이 된다(실제로 V7 후반부가 그랬다). 대신 `_resolved_at()`이
## 없는 기록을 더미로 채워 돌려주므로, 발화하지 않으면 반드시 FAIL이 난다.

const RINE_PATH: String = "res://data/npc/npc_rine.tres"
const YURI_PATH: String = "res://data/npc/npc_yuri.tres"
const GAME_STATE_SCRIPT: String = "res://scripts/core/game_state.gd"
const DAY_NIGHT_SCRIPT: String = "res://scripts/core/day_night.gd"
const PLAYER_SCENE: String = "res://scenes/field/FieldPlayer.tscn"
const NPC_SCENE: String = "res://scenes/field/FieldNpc.tscn"
const FIELD_SCENE: String = "res://scenes/field/Field.tscn"

## 무한 루프 방지. 대사 페이지 하나당 최대 2회(타이핑 완성 + 넘김)면 충분하다.
const INTERACT_GUARD: int = 40

## 물리 대기 프레임. 이동은 60Hz 기준이므로 20프레임이면 4.0 m/s × 0.33s ≈ 1.33m 움직인다.
const SETTLE_FRAMES: int = 10
const MOVE_FRAMES: int = 20
## 입력 이벤트는 파싱된 다음 프레임에 트리로 전파된다. 3프레임이면 충분하다(실측).
const INPUT_FRAMES: int = 3

## 잠금 상태에서 허용할 위치 오차(m). 물리가 완전히 멎으면 0이어야 한다.
const ZERO_MOVE_EPSILON: float = 0.001

## 대조군이 "실제로 움직였다"고 인정할 최소 거리(m). 20프레임이면 1.33m가 나온다.
const MOVED_EPSILON: float = 0.5

## 통합 단계에서 NPC를 둘 거리. 플레이어 감지 반경 1.2 + NPC 존 0.4 = 실효 1.6m.
const NPC_NEAR_X: float = 0.8
const NPC_FAR_X: float = 6.0

enum Step {
	UNIT,              ## 1층 규칙 검증 + 이동 통합 씬 구성
	MOVE_BASELINE,     ## FREE에서 이동 입력을 준다 (대조군)
	MOVE_LOCK_SETUP,   ## 대조군을 확인하고 상태를 TALKING으로 강제 설정
	MOVE_LOCK_PRESS,   ## 잠긴 상태에서 같은 이동 입력을 준다
	MOVE_LOCK_CHECK,   ## 위치 불변 확인 → 상호작용 씬으로 교체
	INPUT_NEAR,        ## 반경 안: interact 이벤트를 쏜다
	INPUT_NEAR_CHECK,  ## 대화가 시작됐는지
	INPUT_FAR,         ## 반경 밖: interact 이벤트를 쏜다
	INPUT_FAR_CHECK,   ## 대화가 시작되지 않았는지
}

var _failed: int = 0
var _resolved: Array = []

var _step: Step = Step.UNIT
var _resume_at: int = 0

## 통합 검증용 씬. [월드, 컨트롤러, 플레이어, GameState, DayNight]
var _world: Node3D = null
var _controller: InteractionController = null
var _player: CharacterBody3D = null
var _integration_nodes: Array[Node] = []

var _origin: Vector3 = Vector3.ZERO


func _process(_delta: float) -> bool:
	# 물리 프레임 기준으로 기다린다. 헤드리스는 vsync가 없어 렌더 프레임이 물리보다 훨씬
	# 빨리 돌기 때문에, 렌더 프레임을 세면 아직 한 번도 물리가 돌지 않은 채 단언하게 된다.
	if Engine.get_physics_frames() < _resume_at:
		return false

	match _step:
		Step.UNIT:
			_run_rule_tests()
			_build_integration_world(false)
			_goto(Step.MOVE_BASELINE, SETTLE_FRAMES)
		Step.MOVE_BASELINE:
			_origin = _player.global_position
			Input.action_press(&"move_left")
			_goto(Step.MOVE_LOCK_SETUP, MOVE_FRAMES)
		Step.MOVE_LOCK_SETUP:
			# 대조군. 이 단언이 깨지면 잠금이 아니라 테스트가 입력을 못 주고 있는 것이다 —
			# 그 구분이 없으면 "아무 일도 안 일어나는 테스트"가 영원히 초록으로 남는다.
			_assert_true(
				_origin.distance_to(_player.global_position) > MOVED_EPSILON,
				"V1 대조군 — FREE에서는 이동 입력으로 실제로 움직인다"
			)
			Input.action_release(&"move_left")
			# 설계 §7 V1의 문구 그대로 상태를 강제 설정한다.
			_controller.state = InteractionController.State.TALKING
			_goto(Step.MOVE_LOCK_PRESS, SETTLE_FRAMES)
		Step.MOVE_LOCK_PRESS:
			# 입력을 떼고 완전히 멎은 뒤의 위치를 기준으로 잡는다.
			# 감속이 남은 지점을 기준으로 삼으면 잠금과 관성을 구분할 수 없다.
			_origin = _player.global_position
			Input.action_press(&"move_left")
			_goto(Step.MOVE_LOCK_CHECK, MOVE_FRAMES)
		Step.MOVE_LOCK_CHECK:
			_check_locked_movement()
		Step.INPUT_NEAR:
			_assert_true(_controller.candidate() != null, "통합 — 반경 안의 NPC가 대상으로 잡힌다(Area3D 탐지)")
			_send_action(&"interact")
			_goto(Step.INPUT_NEAR_CHECK, INPUT_FRAMES)
		Step.INPUT_NEAR_CHECK:
			_check_dialogue_started_by_event()
		Step.INPUT_FAR:
			_assert_true(_controller.candidate() == null, "통합 — 반경 밖의 NPC는 대상이 아니다")
			_send_action(&"interact")
			_goto(Step.INPUT_FAR_CHECK, INPUT_FRAMES)
		Step.INPUT_FAR_CHECK:
			_assert_eq(
				_controller.state, InteractionController.State.FREE,
				"통합 — 대상이 없으면 interact 이벤트로 대화가 시작되지 않는다"
			)
			_teardown_integration_world()
			quit(_failed)
			return true
	return false


func _goto(next: Step, wait_physics_frames: int) -> void:
	_step = next
	_resume_at = Engine.get_physics_frames() + wait_physics_frames


# ── 1층: 규칙 검증 ─────────────────────────────────────────────────────────

func _run_rule_tests() -> void:
	_test_field_scene_wiring()
	_test_movement_lock_contract()
	_test_transition_table()
	_test_dialogue_pages()
	_test_night_lines_and_toggle_guard()
	_test_pass_menu_listing()
	_test_challenge_hook()
	_test_allure_requires_inquire()
	_test_scrutinize_tokens()


## `Field.tscn`에 적힌 NodePath가 실제 노드를 가리키는지 확인한다.
##
## 2층의 통합 씬은 테스트가 직접 조립하므로 **배선 값 자체의 오타는 잡지 못한다.**
## `controller_path`를 한 글자만 틀려도 `get_node_or_null`이 null을 주고 잠금이 조용히 풀린다
## (`field_player.gd`의 의도된 폴백). 씬을 인스턴스화하지 않고 `SceneState`로 읽는 이유는,
## `--script` 모드에서는 autoload 전역이 없어 `Field.tscn`을 실제로 띄우면 field.gd가 죽기 때문이다.
func _test_field_scene_wiring() -> void:
	var packed := load(FIELD_SCENE) as PackedScene
	if packed == null:
		_assert_true(false, "배선 — Field.tscn 로드")
		return
	var state := packed.get_state()

	var known: Dictionary = {}
	for i in state.get_node_count():
		known[_normalize_scene_path(String(state.get_node_path(i)))] = true

	for wiring in [
		["InteractionController", "player_path", "상태 머신 → 플레이어"],
		["Actors/Player", "controller_path", "플레이어 → 상태 머신"],
		["Actors/Player", "camera_path", "플레이어 → 카메라"],
	]:
		var owner_path: String = wiring[0]
		var property: String = wiring[1]
		var label: String = wiring[2]
		var raw: Variant = _scene_property(state, owner_path, property)
		var target := _resolve_scene_path(owner_path, String(raw if raw != null else ""))
		_assert_true(
			not target.is_empty() and known.has(target),
			"배선 — %s (%s.%s = %s)" % [label, owner_path, property, raw]
		)


## 잠금 계약. 실제 플레이어가 멈추는지는 2층(Step.MOVE_*)이 본다.
func _test_movement_lock_contract() -> void:
	var ctx := _make_controller()
	var controller: InteractionController = ctx[0]

	_assert_true(not controller.is_movement_locked(), "V1 FREE에서는 이동 가능")
	for locked_state in [
		InteractionController.State.TALKING,
		InteractionController.State.PASS_MENU,
		InteractionController.State.RESULT,
		InteractionController.State.SYSTEM_MENU,
	]:
		controller.state = locked_state
		_assert_true(controller.is_movement_locked(), "V1 상태 %d 에서는 이동 잠김" % locked_state)
	controller.state = InteractionController.State.FREE

	_free_controller(ctx)


## 설계 §4-2 전이표에서 다른 테스트가 건드리지 않는 칸들.
## 구현은 맞지만 테스트가 없어 회귀를 못 잡던 자리다(검증 리포트 §2-4).
func _test_transition_table() -> void:
	var ctx := _make_controller(false)
	var controller: InteractionController = ctx[0]
	var day_night: Node = ctx[2]
	var rine := load(RINE_PATH) as NpcData
	var yuri := load(YURI_PATH) as NpcData

	# FREE: cancel 무시 / menu로 SYSTEM_MENU 왕복
	controller.handle_cancel()
	_assert_eq(controller.state, InteractionController.State.FREE, "§4-2 FREE에서 cancel은 무시된다")
	controller.handle_menu()
	_assert_eq(controller.state, InteractionController.State.SYSTEM_MENU, "§4-2 FREE에서 menu → SYSTEM_MENU")
	controller.handle_menu()
	_assert_eq(controller.state, InteractionController.State.FREE, "§4-2 SYSTEM_MENU에서 menu → FREE")
	controller.handle_menu()
	controller.handle_cancel()
	_assert_eq(controller.state, InteractionController.State.FREE, "§4-2 SYSTEM_MENU에서 cancel → FREE")

	# TALKING: 첫 페이지에서 cancel로 즉시 종료 / menu 무시
	controller.start_dialogue(rine)
	controller.handle_menu()
	_assert_eq(controller.state, InteractionController.State.TALKING, "§4-2 TALKING에서 menu는 무시된다")
	controller.handle_cancel()
	_assert_eq(controller.state, InteractionController.State.FREE, "§2-2 TALKING 중 어느 페이지에서든 cancel로 종료")

	# PASS_MENU: menu·toggle_phase 무시
	_open_menu(controller, yuri)
	_assert_eq(controller.state, InteractionController.State.PASS_MENU, "§4-2 목록 진입")
	controller.handle_menu()
	_assert_eq(controller.state, InteractionController.State.PASS_MENU, "§4-2 PASS_MENU에서 menu는 무시된다")
	controller.handle_toggle_phase()
	_assert_true(not day_night.is_night, "§4-2 PASS_MENU에서 toggle_phase는 무시된다")

	# RESULT: toggle_phase 무시 / cancel로 닫기
	controller.handle_interact()
	_assert_eq(controller.state, InteractionController.State.RESULT, "§4-2 선택 확정 → RESULT")
	controller.handle_toggle_phase()
	_assert_true(not day_night.is_night, "§4-2 RESULT에서 toggle_phase는 무시된다")
	controller.handle_menu()
	_assert_eq(controller.state, InteractionController.State.RESULT, "§4-2 RESULT에서 menu는 무시된다")
	controller.handle_cancel()
	_assert_eq(controller.state, InteractionController.State.FREE, "§4-2 RESULT에서 cancel → FREE")

	_free_controller(ctx)


# ── V2 ────────────────────────────────────────────────────────────────────

## 페이지가 배열 길이만큼 진행하고, 타이핑 중 interact는 페이지를 넘기지 않는다(설계 §2-2).
func _test_dialogue_pages() -> void:
	var ctx := _make_controller(false)
	var controller: InteractionController = ctx[0]
	var rine := load(RINE_PATH) as NpcData

	var started: Array = []
	var finished: Array = []
	controller.dialogue_started.connect(func(npc: NpcData) -> void: started.append(npc.npc_id))
	controller.dialogue_finished.connect(func(npc: NpcData) -> void: finished.append(npc.npc_id))

	controller.start_dialogue(rine)
	var box := controller.dialogue_box()
	_assert_eq(controller.state, InteractionController.State.TALKING, "V2 대화 시작 → TALKING")
	_assert_eq(started.size(), 1, "V2 dialogue_started 1회")
	_assert_eq(box.current_text(), rine.day_lines[0], "V2 첫 페이지는 낮 대사 0번")
	_assert_true(box.is_typing(), "V2 열자마자 타이핑 중")

	# 타이핑 중 interact = 페이지 넘김이 아니라 현재 페이지 즉시 완성.
	controller.handle_interact()
	_assert_true(not box.is_typing(), "V2 타이핑 중 interact → 즉시 완성")
	_assert_eq(box.page_index(), 0, "V2 타이핑 완성은 페이지를 넘기지 않는다")

	var count := 1
	while controller.state == InteractionController.State.TALKING and count < INTERACT_GUARD:
		controller.handle_interact()
		count += 1
	_assert_eq(count, 2 * rine.day_lines.size(), "V2 페이지당 interact 2회(완성+넘김)로 대화가 끝난다")
	# 리네는 낮에 정보수집 1종을 갖고 있으므로 목록으로 이어진다.
	_assert_eq(controller.state, InteractionController.State.PASS_MENU, "V2 마지막 페이지 + 액션 있음 → PASS_MENU")

	controller.handle_cancel()
	_assert_eq(controller.state, InteractionController.State.FREE, "V2 목록에서 cancel → FREE")
	_assert_eq(finished.size(), 1, "V2 dialogue_finished 1회")

	_free_controller(ctx)


# ── V3 · V8 ───────────────────────────────────────────────────────────────

func _test_night_lines_and_toggle_guard() -> void:
	var ctx := _make_controller(true)
	var controller: InteractionController = ctx[0]
	var day_night: Node = ctx[2]
	var rine := load(RINE_PATH) as NpcData

	controller.start_dialogue(rine)
	_assert_eq(controller.dialogue_box().current_text(), rine.night_lines[0], "V3 밤에는 밤 대사가 나온다")

	# 대화 중 시간대가 바뀌면 대사 배열이 통째로 교체돼 페이지 인덱스가 배열 밖으로 나간다.
	controller.handle_toggle_phase()
	_assert_true(day_night.is_night, "V8 TALKING 중 toggle_phase는 무시된다")

	controller.handle_cancel()
	controller.handle_toggle_phase()
	_assert_true(not day_night.is_night, "V8 FREE에서는 toggle_phase가 먹는다")

	_free_controller(ctx)


# ── V4 ────────────────────────────────────────────────────────────────────

## 목록에는 현재 시간대의 액션만 뜬다. 리네: 낮 1(정보수집) / 밤 2(조사·유혹).
func _test_pass_menu_listing() -> void:
	var ctx := _make_controller(false)
	var controller: InteractionController = ctx[0]
	var day_night: Node = ctx[2]
	var rine := load(RINE_PATH) as NpcData

	_open_menu(controller, rine)
	_assert_eq(controller.pass_action_menu().item_count(), 1, "V4 리네 낮 목록 1개")
	controller.handle_cancel()

	day_night.set_night(true)
	_open_menu(controller, rine)
	_assert_eq(controller.pass_action_menu().item_count(), 2, "V4 리네 밤 목록 2개")
	controller.handle_cancel()

	_free_controller(ctx)


# ── V5 · V6 ───────────────────────────────────────────────────────────────

## 도전 성공 시 pass_action_resolved가 정확히 1회 발화하고(M3 전투 훅의 진입점),
## 1회성이므로 다음 낮 목록에서 사라진다.
func _test_challenge_hook() -> void:
	var ctx := _make_controller(false)
	var controller: InteractionController = ctx[0]
	var state: Node = ctx[1]
	var yuri := load(YURI_PATH) as NpcData

	_resolved.clear()
	controller.pass_action_resolved.connect(_on_pass_action_resolved)

	_open_menu(controller, yuri)
	_assert_eq(controller.pass_action_menu().item_count(), 2, "V6 유리 낮 목록 2개(정보수집·도전)")
	_assert_true(_select_action(controller, "challenge"), "V5 목록에서 도전을 고를 수 있다")

	controller.handle_interact()
	_assert_eq(controller.state, InteractionController.State.RESULT, "V5 선택 확정 → RESULT")
	_assert_eq(_resolved.size(), 1, "V5 pass_action_resolved 1회")
	var signal_args := _resolved_at(0)
	_assert_eq(signal_args[0], "yuri", "V5 시그널 npc_id")
	_assert_eq(signal_args[1], "challenge", "V5 시그널 action_id")
	_assert_eq(signal_args[2], true, "V5 유리 Lv7 ≤ 8 이므로 도전 성공")
	_assert_true(state.has_flag("pa_challenge_yuri"), "V5 성공 플래그가 켜진다")
	_assert_true(not controller.dialogue_box().current_text().contains("{"), "V5 결과 대사에 미해결 토큰이 없다")

	controller.handle_interact()
	_assert_eq(controller.state, InteractionController.State.FREE, "V5 RESULT에서 interact → FREE")

	_open_menu(controller, yuri)
	_assert_eq(controller.pass_action_menu().item_count(), 1, "V6 도전 성공 후 낮 목록에서 사라진다")
	controller.handle_cancel()

	_free_controller(ctx)


# ── V7 ────────────────────────────────────────────────────────────────────

## 유혹은 낮의 정보수집 성공(pa_inquire_{npc})이 없으면 실패한다. 낮↔밤을 잇는 유일한 장치다.
func _test_allure_requires_inquire() -> void:
	var ctx := _make_controller(true)
	var controller: InteractionController = ctx[0]
	var state: Node = ctx[1]
	var yuri := load(YURI_PATH) as NpcData

	_resolved.clear()
	controller.pass_action_resolved.connect(_on_pass_action_resolved)

	_open_menu(controller, yuri)
	_assert_true(_select_action(controller, "allure"), "V7 밤 목록에 유혹이 있다")
	controller.handle_interact()
	_assert_eq(_resolved.size(), 1, "V7 첫 시도 결과 시그널 1회")
	_assert_eq(_resolved_at(0)[2], false, "V7 정보수집 성공 없이는 유혹 실패")
	_assert_true(not state.has_flag("pa_allure_yuri"), "V7 실패했으므로 성공 플래그가 꺼져 있다")
	controller.handle_cancel()

	# 낮의 정보수집을 성공시켜 두면 같은 유혹이 성공한다.
	state.set_flag("pa_inquire_yuri")
	_resolved.clear()
	_open_menu(controller, yuri)
	_assert_true(_select_action(controller, "allure"), "V7 유혹은 실패해도 목록에 남는다(failure_flag 없음)")
	controller.handle_interact()
	_assert_eq(_resolved.size(), 1, "V7 두 번째 시도도 결과 시그널 1회")
	_assert_eq(_resolved_at(0)[2], true, "V7 정보수집 성공 후에는 유혹 성공")
	_assert_true(state.has_flag("pa_allure_yuri"), "V7 성공했으므로 성공 플래그가 켜진다")
	controller.handle_cancel()

	_free_controller(ctx)


# ── V9 ────────────────────────────────────────────────────────────────────

## 조사 성공 대사에는 실제 수치가 찍힌다. 대사에 값을 손으로 적지 않으므로
## 밸런스를 바꿔도 표시가 어긋나지 않는다(설계 §3-5).
func _test_scrutinize_tokens() -> void:
	var ctx := _make_controller(true)
	var controller: InteractionController = ctx[0]
	var yuri := load(YURI_PATH) as NpcData

	_open_menu(controller, yuri)
	_assert_true(_select_action(controller, "scrutinize"), "V9 밤 목록에 조사가 있다")
	controller.handle_interact()

	var line := controller.dialogue_box().current_text()
	_assert_true(line.contains("Lv.7"), "V9 조사 결과에 실제 레벨이 찍힌다 — %s" % line)
	_assert_true(line.contains("경계도 3"), "V9 조사 결과에 실제 경계도가 찍힌다 — %s" % line)
	_assert_true(not line.contains("{"), "V9 미해결 토큰이 남지 않는다")

	controller.handle_cancel()
	_free_controller(ctx)


# ── 2층: 통합 검증 ─────────────────────────────────────────────────────────

## V1의 본문. 설계 §7은 "상태를 강제 설정하고 **플레이어 위치 변화가 0인지**"를 요구한다.
## 대조군(MOVE_LOCK_SETUP)과 같은 입력·같은 프레임 수를 주고 결과만 비교한다.
func _check_locked_movement() -> void:
	var drift := _origin.distance_to(_player.global_position)
	_assert_true(
		drift < ZERO_MOVE_EPSILON,
		"V1 잠긴 상태에서 이동 입력을 줘도 플레이어 위치가 변하지 않는다 — 이동량 %.4f m" % drift
	)
	_teardown_integration_world()
	_build_integration_world(true, NPC_NEAR_X)
	_goto(Step.INPUT_NEAR, SETTLE_FRAMES)


func _check_dialogue_started_by_event() -> void:
	var rine := load(RINE_PATH) as NpcData
	_assert_eq(
		_controller.state, InteractionController.State.TALKING,
		"통합 — interact 입력 이벤트로 대화가 시작된다(_unhandled_input 경로)"
	)
	_assert_eq(
		_controller.dialogue_box().current_text(), rine.day_lines[0],
		"통합 — 이벤트로 연 대화도 데이터의 낮 대사를 띄운다"
	)
	_teardown_integration_world()
	_build_integration_world(true, NPC_FAR_X)
	_goto(Step.INPUT_FAR, SETTLE_FRAMES)


## 통합 검증용 최소 씬을 만든다.
##
## 씬 전체를 트리 밖에서 조립한 뒤 한 번에 붙인다 — `add_child`가 트리 밖에서는 `_ready`를
## 부르지 않으므로, 이렇게 해야 `player_path`/`controller_path`가 서로를 찾을 수 있다.
func _build_integration_world(with_npc: bool, npc_x: float = NPC_NEAR_X) -> void:
	var state: Node = (load(GAME_STATE_SCRIPT) as GDScript).new()
	var day_night: Node = (load(DAY_NIGHT_SCRIPT) as GDScript).new()

	_world = Node3D.new()
	_world.name = "World"

	# 바닥이 없으면 플레이어가 계속 떨어져서 "위치 변화 0"을 단언할 수 없다.
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 40.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	ground.add_child(shape)
	_world.add_child(ground)

	_controller = InteractionController.new()
	_controller.name = "InteractionController"
	_controller.player_path = NodePath("../Player")
	_controller.game_state = state
	_controller.day_night = day_night
	_world.add_child(_controller)

	_player = (load(PLAYER_SCENE) as PackedScene).instantiate() as CharacterBody3D
	_player.name = "Player"
	_player.controller_path = NodePath("../InteractionController")
	_world.add_child(_player)

	if with_npc:
		var npc := (load(NPC_SCENE) as PackedScene).instantiate() as FieldNpc
		npc.name = "Npc"
		npc.npc_data = load(RINE_PATH) as NpcData
		npc.position = Vector3(npc_x, 0.0, 0.0)
		_world.add_child(npc)

	root.add_child(_world)
	_integration_nodes = [state, day_night]


func _teardown_integration_world() -> void:
	Input.action_release(&"move_left")
	if _world != null:
		_world.free()
	_world = null
	_controller = null
	_player = null
	for node in _integration_nodes:
		node.free()
	_integration_nodes = []


## 입력 이벤트를 실제로 쏜다. `Input.action_press()`는 폴링 상태만 바꾸고 이벤트를 트리에
## 흘리지 않아 `_unhandled_input`이 반응하지 않는다(`tools/capture_screenshot.gd`와 같은 이유).
func _send_action(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)


# ── 헬퍼 ──────────────────────────────────────────────────────────────────

## [컨트롤러, 격리된 GameState, 격리된 DayNight]를 만든다.
func _make_controller(night: bool = false) -> Array:
	var state: Node = (load(GAME_STATE_SCRIPT) as GDScript).new()
	var day_night: Node = (load(DAY_NIGHT_SCRIPT) as GDScript).new()
	day_night.set_night(night)
	var controller := InteractionController.new()
	controller.game_state = state
	controller.day_night = day_night
	root.add_child(controller)
	return [controller, state, day_night]


func _free_controller(ctx: Array) -> void:
	(ctx[0] as Node).free()
	(ctx[1] as Node).free()
	(ctx[2] as Node).free()


## 대사를 끝까지 넘겨 패스 액션 목록을 띄운다.
func _open_menu(controller: InteractionController, npc: NpcData) -> void:
	controller.start_dialogue(npc)
	var guard := 0
	while controller.state == InteractionController.State.TALKING and guard < INTERACT_GUARD:
		controller.handle_interact()
		guard += 1


## 목록에서 해당 action_id가 선택될 때까지 커서를 내린다.
func _select_action(controller: InteractionController, action_id: String) -> bool:
	var menu := controller.pass_action_menu()
	for _i in menu.item_count():
		var entry := menu.selected_entry()
		if entry != null and entry.action != null and entry.action.action_id == action_id:
			return true
		menu.move_selection(1)
	return false


## 저장된 씬에서 노드 하나의 프로퍼티 값을 꺼낸다. 없으면 null.
func _scene_property(state: SceneState, node_path: String, property: String) -> Variant:
	for i in state.get_node_count():
		if _normalize_scene_path(String(state.get_node_path(i))) != node_path:
			continue
		for j in state.get_node_property_count(i):
			if String(state.get_node_property_name(i, j)) == property:
				return state.get_node_property_value(i, j)
	return null


## `SceneState.get_node_path()`는 `./Actors/Player` 꼴로 준다. 앞의 `./`를 떼어
## `.tscn`에 적힌 상대 경로 표기와 같은 형태로 맞춘다.
func _normalize_scene_path(path: String) -> String:
	if path == "." or path.is_empty():
		return "."
	return path.trim_prefix("./")


## 씬 안의 상대 경로를 루트 기준 경로로 편다. 씬 밖으로 나가면 빈 문자열.
func _resolve_scene_path(owner_path: String, relative: String) -> String:
	if relative.is_empty():
		return ""
	var segments: PackedStringArray = PackedStringArray()
	if owner_path != ".":
		segments = owner_path.split("/")
	for part in relative.split("/"):
		if part == "..":
			if segments.is_empty():
				return ""
			segments.remove_at(segments.size() - 1)
		elif part != "." and not part.is_empty():
			segments.append(part)
	return "." if segments.is_empty() else "/".join(segments)


## 시그널 기록 한 건. **없으면 더미를 돌려준다** — 호출부가 `if`로 감싸지 않게 하기 위해서다.
## 조건부 assert는 시그널이 0회 발화해도 아무 단언 없이 초록이 된다.
func _resolved_at(index: int) -> Array:
	if index < 0 or index >= _resolved.size():
		return ["(발화 없음)", "(발화 없음)", "(발화 없음)"]
	return _resolved[index]


func _on_pass_action_resolved(npc_id: String, action_id: String, success: bool) -> void:
	_resolved.append([npc_id, action_id, success])


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		print("TEST PASS: ", label)
	else:
		_failed += 1
		printerr("TEST FAIL: ", label, " — 기대 ", expected, ", 실제 ", actual)


func _assert_true(condition: bool, label: String) -> void:
	_assert_eq(condition, true, label)

extends SceneTree
## M1 필드 데이터(.tres) 로딩 검증.
##
## 이 테스트의 존재 이유는 하나다: **.tres의 필드명이 스키마의 @export 변수명과 다르면
## Godot은 에러 없이 조용히 기본값으로 로드한다.** 그러면 대사가 빈 채로, 판정 상한이 0인 채로
## 게임이 "정상 실행"된다. 그래서 (1) 값이 실제로 들어왔는지, (2) 파일에 스키마에 없는 키가
## 섞여 있지 않은지를 둘 다 확인한다.
##
## 패스 액션 4종: 정보수집·도전(낮) / 유혹·조사(밤)

const PASS_ACTION_DIR: String = "res://data/pass_action"
const NPC_DIR: String = "res://data/npc"

const PASS_ACTION_IDS: PackedStringArray = ["inquire", "challenge", "allure", "scrutinize"]
const NPC_FILES: PackedStringArray = ["npc_rine.tres", "npc_borden.tres", "npc_yuri.tres"]

var _failed: int = 0


func _init() -> void:
	_test_pass_actions()
	_test_npcs()
	_test_phase_rules()
	_test_line_fallback()
	_test_line_tokens()
	_test_reward_override()
	_test_flag_format()
	_test_stale_files()
	_test_unknown_keys()
	quit(_failed)


## 패스 액션 4종이 낮 2 / 밤 2로 존재하고, 판정에 쓰이는 수치가 기본값이 아닌지 확인한다.
func _test_pass_actions() -> void:
	var day_count: int = 0
	var night_count: int = 0

	for id in PASS_ACTION_IDS:
		var path := "%s/%s.tres" % [PASS_ACTION_DIR, id]
		var action := load(path) as PassActionData
		if action == null:
			_fail("패스 액션 로드: %s" % path, "PassActionData", "null")
			continue
		_assert_eq(action.action_id, id, "패스 액션 action_id — %s" % id)
		_assert_true(not action.display_name.is_empty(), "패스 액션 display_name 비어있지 않음 — %s" % id)
		_assert_true(not action.success_line.is_empty(), "패스 액션 success_line 비어있지 않음 — %s" % id)
		_assert_true(not action.failure_line.is_empty(), "패스 액션 failure_line 비어있지 않음 — %s" % id)
		_assert_true(not action.success_flag.is_empty(), "패스 액션 success_flag 비어있지 않음 — %s" % id)
		if action.is_night:
			night_count += 1
		else:
			day_count += 1

	_assert_eq(day_count, 2, "낮 패스 액션 2종(정보수집·도전)")
	_assert_eq(night_count, 2, "밤 패스 액션 2종(유혹·조사)")

	# 판정 파라미터가 기본값(0)으로 떨어지지 않았는지 — 여기가 조용한 기본값 로드의 최전선이다.
	var inquire := load("%s/inquire.tres" % PASS_ACTION_DIR) as PassActionData
	_assert_eq(inquire.display_name, "정보수집", "정보수집 표시명")
	_assert_eq(inquire.judge_kind, PassActionData.JudgeKind.DIFFICULTY, "정보수집 판정 방식 = DIFFICULTY")
	_assert_eq(inquire.difficulty_limit, 3, "정보수집 난이도 상한 3")
	_assert_true(inquire.repeatable, "정보수집은 재시도 가능")

	var challenge := load("%s/challenge.tres" % PASS_ACTION_DIR) as PassActionData
	_assert_eq(challenge.display_name, "도전", "도전 표시명")
	_assert_eq(challenge.judge_kind, PassActionData.JudgeKind.LEVEL, "도전 판정 방식 = LEVEL")
	_assert_eq(challenge.level_limit, 8, "도전 레벨 상한 8")
	_assert_true(not challenge.repeatable, "도전은 1회성")
	_assert_eq(challenge.success_flag, "pa_challenge_{npc}", "도전 성공 플래그(M3 전투 진입 훅의 조건)")

	var allure := load("%s/allure.tres" % PASS_ACTION_DIR) as PassActionData
	_assert_eq(allure.display_name, "유혹", "유혹 표시명")
	_assert_eq(allure.judge_kind, PassActionData.JudgeKind.FLAG, "유혹 판정 방식 = FLAG")
	_assert_eq(allure.required_flag, "pa_inquire_{npc}", "유혹 선행 조건 = 낮의 정보수집 성공")
	_assert_true(not allure.repeatable, "유혹은 1회성")

	var scrutinize := load("%s/scrutinize.tres" % PASS_ACTION_DIR) as PassActionData
	_assert_eq(scrutinize.display_name, "조사", "조사 표시명")
	_assert_eq(scrutinize.judge_kind, PassActionData.JudgeKind.DIFFICULTY, "조사 판정 방식 = DIFFICULTY")
	_assert_eq(scrutinize.difficulty_limit, 3, "조사 난이도 상한 3")
	_assert_true(scrutinize.repeatable, "조사는 재시도 가능")
	# 조사 결과는 감춰진 수치를 드러내는 것이다. 토큰이 빠지면 아무것도 드러나지 않는다.
	_assert_true(scrutinize.success_line.contains("{level}"), "조사 성공 대사에 {level} 토큰")
	_assert_true(scrutinize.success_line.contains("{difficulty}"), "조사 성공 대사에 {difficulty} 토큰")


## NPC 3명의 모든 표시 데이터가 실제 값으로 들어왔는지 확인한다.
func _test_npcs() -> void:
	for file_name in NPC_FILES:
		var path := "%s/%s" % [NPC_DIR, file_name]
		var npc := load(path) as NpcData
		if npc == null:
			_fail("NPC 로드: %s" % path, "NpcData", "null")
			continue

		_assert_true(not npc.npc_id.is_empty(), "npc_id 비어있지 않음 — %s" % file_name)
		_assert_true(not npc.display_name.is_empty(), "display_name 비어있지 않음 — %s" % file_name)
		_assert_true(npc.sprite != null, "sprite 텍스처 참조 유효 — %s" % file_name)
		_assert_true(npc.difficulty >= 1 and npc.difficulty <= 5, "difficulty 범위 1~5 — %s" % file_name)
		_assert_true(npc.level > 1, "level이 기본값(1)이 아님 — %s" % file_name)
		_assert_true(npc.day_lines.size() >= 2, "낮 대사 2줄 이상 — %s" % file_name)
		_assert_true(npc.night_lines.size() >= 2, "밤 대사 2줄 이상 — %s" % file_name)
		_assert_true(npc.pass_actions.size() >= 3, "패스 액션 3개 이상 — %s" % file_name)

		for entry in npc.pass_actions:
			_assert_true(entry != null, "패스 액션 엔트리 non-null — %s" % file_name)
			if entry == null:
				continue
			# 엔트리에 action이 안 물리면 목록에 아무것도 안 뜨는데 에러는 나지 않는다. 반드시 잡는다.
			_assert_true(entry.action != null, "엔트리의 action 참조 유효 — %s" % file_name)
			if entry.action == null:
				continue
			_assert_true(PASS_ACTION_IDS.has(entry.action.action_id),
				"엔트리가 현행 4종 중 하나를 가리킴 — %s/%s" % [file_name, entry.action.action_id])
			_assert_true(not entry.resolve_success_line().is_empty(),
				"성공 대사 해석 — %s/%s" % [file_name, entry.action.action_id])
			_assert_true(not entry.resolve_failure_line().is_empty(),
				"실패 대사 해석 — %s/%s" % [file_name, entry.action.action_id])


## 데이터끼리의 관계가 의도한 플레이 경험을 만드는지 — 밸런스 회귀 감지용.
func _test_phase_rules() -> void:
	var rine := load("%s/npc_rine.tres" % NPC_DIR) as NpcData
	var borden := load("%s/npc_borden.tres" % NPC_DIR) as NpcData
	var yuri := load("%s/npc_yuri.tres" % NPC_DIR) as NpcData
	var inquire := load("%s/inquire.tres" % PASS_ACTION_DIR) as PassActionData
	var challenge := load("%s/challenge.tres" % PASS_ACTION_DIR) as PassActionData
	var scrutinize := load("%s/scrutinize.tres" % PASS_ACTION_DIR) as PassActionData

	# 정보수집: 리네(2)·유리(3) 성공, 보든(4) 실패 — 쉬운 상대와 벽이 데이터로 구분돼야 한다.
	_assert_true(rine.difficulty <= inquire.difficulty_limit, "리네에게 정보수집 성공 가능")
	_assert_true(yuri.difficulty <= inquire.difficulty_limit, "유리에게 정보수집 성공 가능(경계값)")
	_assert_true(borden.difficulty > inquire.difficulty_limit, "보든에게 정보수집 실패")

	# 도전: 실력(레벨)으로 판정한다. 유리(7) 성공 / 보든(12) 실패.
	_assert_true(yuri.level <= challenge.level_limit, "유리에게 도전 성공 가능(경계값)")
	_assert_true(borden.level > challenge.level_limit, "보든에게 도전 실패")

	# 조사: 경계심으로 판정. 보든만 실패해 "밤에도 뚫리지 않는 상대"가 존재한다.
	_assert_true(rine.difficulty <= scrutinize.difficulty_limit, "리네 조사 성공 가능")
	_assert_true(borden.difficulty > scrutinize.difficulty_limit, "보든 조사 실패")

	# 유혹: 낮의 정보수집이 선행이므로, 정보수집이 실패하는 보든은 유혹도 영영 실패한다.
	_assert_true(borden.difficulty > inquire.difficulty_limit, "보든은 낮 실패 → 밤 유혹도 연쇄 실패")

	# 시간대 필터가 실제로 갈라지는지.
	_assert_eq(rine.actions_for(false).size(), 1, "리네 낮 액션 1개(정보수집)")
	_assert_eq(rine.actions_for(true).size(), 2, "리네 밤 액션 2개(조사·유혹)")
	_assert_eq(borden.actions_for(false).size(), 2, "보든 낮 액션 2개(정보수집·도전)")
	_assert_eq(borden.actions_for(true).size(), 2, "보든 밤 액션 2개(조사·유혹)")
	_assert_eq(yuri.actions_for(false).size(), 2, "유리 낮 액션 2개(정보수집·도전)")
	_assert_eq(yuri.actions_for(true).size(), 2, "유리 밤 액션 2개(조사·유혹)")

	# 밤 액션이 낮 액션보다 관대하면 밤에 갈 이유가 없다. 조사는 정보수집과 같은 문턱을 쓰되,
	# 유혹은 낮의 성과를 요구하므로 전체적으로 밤이 더 빡빡하다는 점을 관계로 못 박아 둔다.
	var allure := load("%s/allure.tres" % PASS_ACTION_DIR) as PassActionData
	_assert_eq(allure.required_flag, inquire.success_flag, "유혹 선행 플래그 == 정보수집 성공 플래그")


## 밤 대사가 비어 있으면 낮 대사로 폴백해야 한다 (빈 대화창 방지 규칙).
func _test_line_fallback() -> void:
	var npc := NpcData.new()
	npc.day_lines = PackedStringArray(["낮 대사"])
	_assert_eq(npc.lines_for(true)[0], "낮 대사", "밤 대사 없으면 낮 대사로 폴백")
	npc.night_lines = PackedStringArray(["밤 대사"])
	_assert_eq(npc.lines_for(true)[0], "밤 대사", "밤 대사 있으면 밤 대사 사용")
	_assert_eq(npc.lines_for(false)[0], "낮 대사", "낮에는 항상 낮 대사")


## 결과 대사의 토큰 치환. 조사 액션의 결과 자체가 이 치환에 달려 있다.
func _test_line_tokens() -> void:
	var yuri := load("%s/npc_yuri.tres" % NPC_DIR) as NpcData
	var entry := _find_entry(yuri, "scrutinize")
	_assert_true(entry != null, "유리에게 조사 엔트리 존재")
	if entry == null:
		return

	var resolved := yuri.format_line(entry.resolve_success_line())
	_assert_true(resolved.contains("Lv.7"), "조사 결과에 실제 레벨(7)이 표시됨")
	_assert_true(resolved.contains("경계도 3"), "조사 결과에 실제 난이도(3)가 표시됨")
	_assert_true(not resolved.contains("{"), "치환 후 미해결 토큰이 남지 않음")
	_assert_eq(yuri.format_line("{name}"), "떠돌이 악사 유리", "{name} 토큰 치환")


## 보상 오버라이드 규칙. 현재 데이터에는 골드를 주는 액션이 없지만,
## 규칙 자체가 살아 있어야 M2에서 보상형 액션을 붙일 때 바로 쓸 수 있다.
func _test_reward_override() -> void:
	var action := PassActionData.new()
	action.reward_gold = 45

	var entry := NpcPassAction.new()
	entry.action = action
	_assert_eq(entry.resolve_reward_gold(), 45, "오버라이드 없으면 액션 기본 보상")

	entry.override_reward_gold = 60
	_assert_eq(entry.resolve_reward_gold(), 60, "오버라이드가 최종 보상에 반영")

	# 현행 데이터의 모든 액션은 보상 0이다. 실수로 골드가 흘러나오지 않는지 확인한다.
	for id in PASS_ACTION_IDS:
		var loaded := load("%s/%s.tres" % [PASS_ACTION_DIR, id]) as PassActionData
		_assert_eq(loaded.reward_gold, 0, "M1 액션은 골드를 주지 않음 — %s" % id)
		_assert_eq(loaded.gold_cost, 0, "M1 액션은 골드를 요구하지 않음 — %s" % id)


## 플래그 템플릿 치환. 낮→밤 연계(정보수집 성공 → 유혹 가능)가 이 문자열 하나에 달려 있다.
func _test_flag_format() -> void:
	_assert_eq(PassActionData.format_flag("pa_inquire_{npc}", "rine"), "pa_inquire_rine", "플래그 치환")
	_assert_eq(PassActionData.format_flag("", "rine"), "", "빈 템플릿은 빈 문자열")

	var inquire := load("%s/inquire.tres" % PASS_ACTION_DIR) as PassActionData
	var allure := load("%s/allure.tres" % PASS_ACTION_DIR) as PassActionData
	_assert_eq(
		PassActionData.format_flag(allure.required_flag, "yuri"),
		PassActionData.format_flag(inquire.success_flag, "yuri"),
		"유혹 선행 플래그 == 정보수집 성공 플래그 (치환 후에도 일치)"
	)


## 교체 전 액션 세트의 .tres가 남아 있으면 다음 작업자가 어느 쪽이 진실인지 알 수 없다.
func _test_stale_files() -> void:
	for stale in ["purchase.tres", "steal.tres", "entice.tres"]:
		var path := "%s/%s" % [PASS_ACTION_DIR, stale]
		_assert_true(not ResourceLoader.exists(path), "구 액션 파일 제거됨 — %s" % stale)

	# 디렉터리에 정확히 4개만 있어야 한다.
	var dir := DirAccess.open(PASS_ACTION_DIR)
	var count: int = 0
	if dir != null:
		for file_name in dir.get_files():
			if file_name.ends_with(".tres"):
				count += 1
	_assert_eq(count, 4, "패스 액션 .tres 파일 정확히 4개")


## .tres에 스키마에 없는 키가 들어 있으면 그 값은 조용히 무시된다. 텍스트를 직접 훑어서 잡는다.
func _test_unknown_keys() -> void:
	var files: PackedStringArray = []
	for id in PASS_ACTION_IDS:
		files.append("%s/%s.tres" % [PASS_ACTION_DIR, id])
	for file_name in NPC_FILES:
		files.append("%s/%s" % [NPC_DIR, file_name])

	for path in files:
		var text := FileAccess.get_file_as_string(path)
		if text.is_empty():
			_fail("파일 읽기: %s" % path, "내용 있음", "빈 문자열")
			continue

		var target: Resource = null
		for line in text.split("\n"):
			var trimmed := line.strip_edges()
			if trimmed.begins_with("[sub_resource"):
				# NPC 파일의 sub_resource는 전부 NpcPassAction이다.
				target = NpcPassAction.new()
				continue
			if trimmed.begins_with("[resource]"):
				target = load(path)
				continue
			if trimmed.begins_with("["):
				target = null
				continue
			if target == null or not trimmed.contains(" = "):
				continue

			var key := trimmed.split(" = ")[0]
			if key == "script":
				continue
			_assert_true(_has_property(target, key), "%s의 키 '%s'가 스키마에 존재" % [path.get_file(), key])


func _has_property(target: Object, key: String) -> bool:
	for prop in target.get_property_list():
		if String(prop["name"]) == key:
			return true
	return false


func _find_entry(npc: NpcData, action_id: String) -> NpcPassAction:
	for entry in npc.pass_actions:
		if entry != null and entry.action != null and entry.action.action_id == action_id:
			return entry
	return null


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		print("TEST PASS: ", label)
	else:
		_fail(label, expected, actual)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("TEST PASS: ", label)
	else:
		_fail(label, true, false)


func _fail(label: String, expected: Variant, actual: Variant) -> void:
	_failed += 1
	printerr("TEST FAIL: ", label, " — 기대 ", expected, ", 실제 ", actual)

class_name PassActionJudge
extends RefCounted
## 패스 액션의 목록 구성·판정·결과 적용 (설계 §3-2의 공통 처리 순서).
##
## **노드에 의존하지 않는 static 함수로 뽑은 이유:** 판정 규칙은 헤드리스로 검증해야 하는데,
## 규칙이 상태 머신 노드 안에 묻혀 있으면 씬을 띄우고 입력을 흉내내야만 확인할 수 있다.
## 설계 §5가 "판정식은 리소스가 아니라 필드 로직"이라고 한 그 필드 로직을 여기 모아 둔다.
## InteractionController는 이 함수들을 호출하고 화면에 띄우는 일만 한다.
##
## `state` 인자는 GameState(autoload)를 받는다. 타입을 Node로 둔 이유:
## autoload 스크립트에는 class_name이 없고, `--script` 헤드리스 실행에서는 autoload 초기화
## 시점을 보장할 수 없다(tests/headless_day_night.gd의 주석 참고). 그래서 전역을 직접 참조하지 않고
## 호출부가 주입하게 만든다 — 테스트는 새 GameState 인스턴스를 넣어 격리된 플래그로 검증할 수 있다.


## 현재 시간대에 실제로 목록에 뜨는 액션. (§3-2의 1·2단계)
##
## 잠긴 액션은 회색 처리 없이 아예 제외한다. M1 단순화 결정이다 —
## 회색 항목을 두면 "왜 못 고르는가"를 설명할 UI가 필요해진다.
static func available_actions(npc: NpcData, night_now: bool, state: Node) -> Array[NpcPassAction]:
	var result: Array[NpcPassAction] = []
	if npc == null:
		return result
	for entry in npc.actions_for(night_now):
		if not is_locked(npc, entry, state):
			result.append(entry)
	return result


## 이미 실패해 영구 차단됐거나(failure_flag), 1회성인데 이미 성공했는가.
static func is_locked(npc: NpcData, entry: NpcPassAction, state: Node) -> bool:
	# npc가 null이면 아래에서 npc.npc_id를 읽다 터진다. "판정할 수 없으면 잠김"으로 닫는다 —
	# 열어 두면 데이터가 빠진 NPC에게 액션이 뜨고, 고르는 순간 결과 처리에서 죽는다.
	if npc == null or entry == null or entry.action == null:
		return true
	var action := entry.action

	# M1 데이터에는 failure_flag를 쓰는 액션이 없다. 규칙만 살려 둬야
	# M2에서 "들켰다" 류 액션을 붙일 때 이 함수를 고치지 않는다(설계 §3-2).
	var fail_flag := PassActionData.format_flag(action.failure_flag, npc.npc_id)
	if not fail_flag.is_empty() and state.has_flag(fail_flag):
		return true

	var done_flag := PassActionData.format_flag(action.success_flag, npc.npc_id)
	if not action.repeatable and not done_flag.is_empty() and state.has_flag(done_flag):
		return true

	return false


## 판정. **난수를 쓰지 않는다**(설계 §3-2의 4단계) — 확률이 끼면 헤드리스 테스트가
## 불안정해지고, 실패했을 때 규칙 때문인지 운 때문인지 구분할 수 없다.
static func evaluate(npc: NpcData, entry: NpcPassAction, state: Node) -> bool:
	if npc == null or entry == null or entry.action == null:
		return false
	var action := entry.action

	# 정수 리터럴(0~4)을 쓰지 않는다. enum에 값이 추가되면 리터럴 쪽이 조용히 어긋난다.
	match action.judge_kind:
		PassActionData.JudgeKind.ALWAYS:
			return true
		PassActionData.JudgeKind.DIFFICULTY:
			return npc.difficulty <= action.difficulty_limit
		PassActionData.JudgeKind.GOLD:
			return state.gold >= action.gold_cost
		PassActionData.JudgeKind.FLAG:
			return state.has_flag(PassActionData.format_flag(action.required_flag, npc.npc_id))
		PassActionData.JudgeKind.LEVEL:
			return npc.level <= action.level_limit
	return false


## 판정하고 결과까지 적용한다. 성공 여부를 돌려준다. (§3-2의 4·5단계)
##
## 골드는 **먼저 지불하고 그 다음 보상**이다. 순서를 뒤집으면 보상으로 받은 돈으로
## 비용을 낼 수 있게 돼서, 잔액 판정이 사실상 무력화된다.
## M1의 네 액션은 골드가 전부 0이라 실제로는 플래그만 켜지지만, 순서 규칙은 지금 못 박아 둔다.
static func resolve(npc: NpcData, entry: NpcPassAction, state: Node) -> bool:
	var success := evaluate(npc, entry, state)
	# npc 검사를 함께 한다. evaluate는 npc가 null이면 false를 주므로 아래 실패 분기로 흘러가는데,
	# 거기서 npc.npc_id를 읽어 죽는다(원래 코드의 구멍).
	if npc == null or entry == null or entry.action == null:
		return success
	var action := entry.action

	if success:
		if action.judge_kind == PassActionData.JudgeKind.GOLD and action.gold_cost > 0:
			state.add_gold(-action.gold_cost)
		var reward := entry.resolve_reward_gold()
		if reward > 0:
			state.add_gold(reward)
		var done_flag := PassActionData.format_flag(action.success_flag, npc.npc_id)
		if not done_flag.is_empty():
			state.set_flag(done_flag)
	else:
		var fail_flag := PassActionData.format_flag(action.failure_flag, npc.npc_id)
		if not fail_flag.is_empty():
			state.set_flag(fail_flag)

	return success


## 결과 대사. **반드시 npc.format_line()을 통과시킨다**(§3-2의 6단계) —
## 빠뜨리면 화면에 `{level}`이 그대로 찍힌다. 조사(scrutinize)의 수치 공개가 이 경로다.
static func result_line(npc: NpcData, entry: NpcPassAction, success: bool) -> String:
	if npc == null or entry == null:
		return ""
	var raw := entry.resolve_success_line() if success else entry.resolve_failure_line()
	return npc.format_line(raw)

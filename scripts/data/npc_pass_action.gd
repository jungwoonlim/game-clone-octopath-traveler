class_name NpcPassAction
extends Resource
## NPC 한 명이 가진 패스 액션 1개의 엔트리.
##
## PassActionData(공용 규칙)와 NPC별 대사·보상 차이를 분리하기 위한 얇은 껍데기다.
## 이걸 두지 않으면 "묻다" 대사를 NPC 수만큼 PassActionData에 복사하게 되고,
## 판정 규칙을 고칠 때 여러 파일을 동시에 고쳐야 한다.

## 어떤 패스 액션인가. data/pass_action/*.tres를 ext_resource로 참조한다.
@export var action: PassActionData = null

## 이 NPC 전용 성공/실패 대사. 비우면 action 쪽 기본 문구를 쓴다.
@export_multiline var success_line: String = ""
@export_multiline var failure_line: String = ""

## -1이면 action.reward_gold를 그대로 쓴다. 부자 NPC에게서 더 많이 훔치는 식의 조정용.
@export_range(-1, 9999) var override_reward_gold: int = -1

## 비우면 `action.required_flag`를 쓴다. `{npc}` 치환 규칙은 같다. (M2 설계 §3-2)
##
## **무엇을 위한 것인가:** 유혹(allure)의 기본 선행 조건은 낮의 정보수집 성공
## (`pa_inquire_{npc}`)이다. 그런데 밤 고정 구역(집정관 광장)의 NPC에게는 낮에 말을 걸 기회가
## 아예 없어서, 기본값을 그대로 쓰면 그 구역의 유혹은 **영원히 실패하는 죽은 선택지**가 된다.
## 액션 자체의 규칙(4종 세트)은 건드리지 않고 이 엔트리에서만 선행 조건을 바꾼다 —
## 광장에서는 `pa_scrutinize_{npc}`(밤의 조사 성공)가 선행이 되어 밤 안에서 2단 연계가 성립한다.
##
## 액션을 5종으로 늘려(`allure_night.tres`) 해결하지 않은 이유:
## 판정 규칙은 같고 선행 플래그만 다른데 액션을 복제하면 밸런스를 고칠 때 두 파일을 고쳐야 하고,
## "패스 액션은 낮 2 / 밤 2"라는 M1의 확정 사항이 데이터에서 깨진다.
@export var override_required_flag: String = ""


## 이 엔트리의 실제 선행 플래그 템플릿(치환 전). 비어 있으면 아무 조건도 없다는 뜻이므로,
## FLAG 판정에서 빈 문자열은 `GameState.has_flag("")` = false로 떨어져 실패한다.
func resolve_required_flag() -> String:
	if not override_required_flag.is_empty():
		return override_required_flag
	return action.required_flag if action != null else ""


func resolve_success_line() -> String:
	if not success_line.is_empty():
		return success_line
	return action.success_line if action != null else ""


func resolve_failure_line() -> String:
	if not failure_line.is_empty():
		return failure_line
	return action.failure_line if action != null else ""


func resolve_reward_gold() -> int:
	if override_reward_gold >= 0:
		return override_reward_gold
	return action.reward_gold if action != null else 0

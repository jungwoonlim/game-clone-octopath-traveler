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

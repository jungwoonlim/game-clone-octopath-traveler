class_name PassActionData
extends Resource
## 패스 액션 1종의 정의 (낮 2종 / 밤 2종).
##
## 옥토패스의 패스 액션은 "NPC에게 무엇을 할 수 있는가"를 정하는 규칙이다.
## M1에서는 전투도 동료 영입도 없으므로, 결과는 "대사 한 줄 + GameState 플래그/골드 변화"로 끝난다.
## 그래도 판정 방식만은 지금 확정해 둔다 — 나중에 결과만 갈아끼우면 M4까지 그대로 쓸 수 있도록.
##
## 판정식은 여기 두지 않는다. 이 리소스는 "무엇을 비교할지"와 "비교 대상 수치"만 담고,
## 실제 비교는 필드 로직(InteractionController)이 수행한다. 밸런스를 고치려고 코드를 열지 않기 위함.

## 판정 방식. .tres에는 정수로 저장되므로 순서를 바꾸면 기존 데이터가 어긋난다 — 뒤에만 추가할 것.
##
## GOLD는 현재 어떤 액션도 쓰지 않는다. 그래도 지우지 않는 이유:
## enum 중간 값을 지우면 뒤의 값이 앞당겨져 이미 저장된 .tres의 정수가 다른 의미로 해석된다
## (FLAG 3 → 2). 남기는 비용은 이 한 줄이고, 지우는 비용은 데이터 마이그레이션이다.
## M2 상점·M4 뇌물에서 골드 판정이 다시 필요할 것이 거의 확실하므로 자리를 지켜 둔다.
enum JudgeKind {
	ALWAYS,      ## 항상 성공. 정보 제공형 액션용.
	DIFFICULTY,  ## npc.difficulty <= difficulty_limit 이면 성공. 상대의 경계심으로 판정한다.
	GOLD,        ## GameState.gold >= gold_cost 이면 성공. 성공 시 gold_cost만큼 지불한다. (M1 미사용)
	FLAG,        ## required_flag(치환 후)가 켜져 있으면 성공. 낮→밤 연계 액션용.
	LEVEL,       ## npc.level <= level_limit 이면 성공. 상대의 실력으로 판정한다.
}

## 내부 id. 플래그 이름과 NPC 쪽 참조에 쓰이므로 영소문자 snake_case로 고정한다.
@export var action_id: String = ""

## UI에 표시할 이름 (한국어).
@export var display_name: String = ""

## 밤 전용 액션이면 true. DayNight.is_night와 직접 비교할 수 있도록 bool로 둔다
## (enum으로 두면 비교할 때마다 변환이 끼어들고, 그 변환이 틀리면 조용히 잘못된 목록이 뜬다).
@export var is_night: bool = false

@export var judge_kind: JudgeKind = JudgeKind.ALWAYS

## JudgeKind.DIFFICULTY 전용. NPC 난이도가 이 값 이하일 때 성공한다. 0이면 아무도 성공하지 못한다.
@export_range(0, 5) var difficulty_limit: int = 0

## JudgeKind.LEVEL 전용. NPC 레벨이 이 값 이하일 때 성공한다.
## 난이도(경계심)와 레벨(실력)을 따로 두는 이유: 두 축을 한 필드로 뭉치면
## "약하지만 입이 무거운 NPC" 같은 조합을 표현할 수 없다.
@export_range(0, 99) var level_limit: int = 0

## JudgeKind.GOLD 전용. 성공 시 실제로 차감되는 금액. (M1에서는 쓰는 액션이 없다)
@export_range(0, 9999) var gold_cost: int = 0

## 성공 시 획득 골드. 구매형 액션은 0.
@export_range(0, 9999) var reward_gold: int = 0

## JudgeKind.FLAG 전용. `{npc}`는 대상 NPC의 npc_id로 치환된다.
@export var required_flag: String = ""

## 성공 시 켤 플래그. 비우면 아무것도 켜지 않는다. `{npc}` 치환 규칙은 위와 같다.
@export var success_flag: String = ""

## 실패 시 켤 플래그(예: 도둑질을 들켰다). 켜지면 이 NPC에게 이 액션은 영구 차단된다.
@export var failure_flag: String = ""

## NPC가 고유 대사를 주지 않을 때 쓰는 기본 문구.
@export_multiline var success_line: String = ""
@export_multiline var failure_line: String = ""

## 성공한 뒤에도 다시 시도할 수 있는가. false면 success_flag가 켜진 순간 선택지에서 사라진다.
@export var repeatable: bool = false


## 플래그 템플릿의 `{npc}`를 실제 npc_id로 바꾼다.
## 템플릿이 비어 있으면 빈 문자열을 돌려준다 — 호출부가 "빈 키면 플래그를 건드리지 않는다"로 처리한다.
static func format_flag(template: String, npc_id: String) -> String:
	if template.is_empty():
		return ""
	return template.replace("{npc}", npc_id)


## 지금 시간대에 이 액션이 목록에 뜨는가.
func matches_phase(night_now: bool) -> bool:
	return is_night == night_now

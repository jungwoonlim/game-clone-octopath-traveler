class_name NpcData
extends Resource
## 필드 NPC 1명의 데이터.
##
## 씬(.tscn)에는 "어디에 서 있는가"만 두고, "누구이며 무슨 말을 하는가"는 전부 여기 둔다.
## 그래야 NPC를 늘릴 때 씬 파일이 아니라 .tres만 추가하면 된다.

## 내부 id. 패스 액션 플래그 키(`pa_inquire_{npc}`)에 그대로 박히므로 영소문자 snake_case 고정.
@export var npc_id: String = ""

## 대화창 이름표에 표시할 이름 (한국어).
@export var display_name: String = ""

## 필드 Sprite3D에 꽂을 텍스처. 경로 문자열이 아니라 Texture2D로 받는다 —
## 경로 오타는 런타임까지 살아남지만, ext_resource 참조는 로드 시점에 바로 깨지므로 먼저 잡힌다.
@export var sprite: Texture2D = null

## 패스 액션 난이도. 1=만만함, 5=난공불락. JudgeKind.DIFFICULTY가 이 값을 본다.
@export_range(1, 5) var difficulty: int = 1

## 표시용 레벨. M1에서는 판정에 쓰지 않고 대화창 정보 표시에만 쓴다(M4 전투에서 사용 예정).
@export_range(1, 99) var level: int = 1

## 낮 대사. 배열 한 칸이 대화창 한 페이지다.
@export var day_lines: PackedStringArray = PackedStringArray()

## 밤 대사. 비워 두면 낮 대사로 폴백한다(lines_for 참조).
@export var night_lines: PackedStringArray = PackedStringArray()

## 이 NPC에게 시도할 수 있는 패스 액션 목록.
@export var pass_actions: Array[NpcPassAction] = []


## 현재 시간대의 대사 묶음.
## 밤 대사가 비어 있으면 낮 대사를 쓴다 — 모든 NPC에 밤 대사를 강제하면
## 단역 NPC를 추가할 때마다 의미 없는 문구를 채우게 되고, 빈 대화창이 뜨는 사고가 난다.
func lines_for(night_now: bool) -> PackedStringArray:
	if night_now and night_lines.size() > 0:
		return night_lines
	return day_lines


## 결과 대사의 토큰을 이 NPC의 값으로 치환한다.
## 지원 토큰: `{name}` `{level}` `{difficulty}`
##
## "조사" 액션은 상대의 감춰진 수치를 드러내는 것이 결과다. 그 수치를 대사에 손으로 적으면
## 밸런스를 바꿀 때 대사와 실제 값이 어긋난다 — 그래서 대사 쪽에 토큰만 두고 여기서 채운다.
func format_line(template: String) -> String:
	return template \
		.replace("{name}", display_name) \
		.replace("{level}", str(level)) \
		.replace("{difficulty}", str(difficulty))


## 현재 시간대에 뜨는 패스 액션만 추린다. 잠금(플래그) 판정은 필드 로직이 따로 수행한다.
func actions_for(night_now: bool) -> Array[NpcPassAction]:
	var result: Array[NpcPassAction] = []
	for entry in pass_actions:
		if entry != null and entry.action != null and entry.action.matches_phase(night_now):
			result.append(entry)
	return result

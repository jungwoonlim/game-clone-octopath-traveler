class_name ZoneData
extends Resource
## 필드 씬 1개(= 구역)의 규칙 데이터. M2에서 씬이 둘 이상이 되면서 생긴 개념이다.
##
## "이 구역이 어떻게 보이는가"(조명·안개 수치)는 `field.gd`가 코드로 들고 있다 —
## 그건 연출이라 hd2d-visual-tuner가 캡처를 보며 고치는 값이다.
## 여기 두는 것은 **규칙**이다: 시간대를 강제하는가, 어디에 세울 것인가, 막혔을 때 뭐라고 할 것인가.
## 규칙을 씬 파일에 export로 흩어 두면 씬이 늘 때마다 같은 설정을 다시 찾아 채워야 하고,
## 두 씬의 정책을 비교하려면 .tscn 두 개를 열어 눈으로 대조해야 한다.

## 시간대 정책. **.tres에 정수로 저장되므로 순서를 바꾸지 말고 뒤에만 추가할 것**
## (M1 설계 §3-6과 같은 이유 — 중간 값을 지우면 저장된 정수가 다른 의미로 해석된다).
##
## bool 두 개(`locked` + `locked_is_night`)로 두지 않은 이유:
## "잠기지 않았는데 잠긴 시간대가 밤"이라는 성립하지 않는 조합이 표현 가능해진다.
enum PhasePolicy {
	FREE,        ## 낮/밤 모두 허용. 진입 시 현재 시간대를 그대로 유지한다.
	LOCK_DAY,    ## 낮 고정. (M2 1차 데이터에는 없다 — LOCK_NIGHT의 대칭항으로 자리만 둔다)
	LOCK_NIGHT,  ## 밤 고정. 진입 시 밤으로 강제하고 toggle_phase를 막는다.
}

## 내부 id. 로그·경고 메시지·테스트가 구역을 식별하는 키. 영소문자 snake_case 고정.
@export var zone_id: String = ""

## 화면에 보일 구역 이름. `phase_locked_notice`의 `{zone}` 토큰으로 치환된다.
@export var display_name: String = ""

@export var phase_policy: PhasePolicy = PhasePolicy.FREE

## 시간대가 잠긴 구역에서 `toggle_phase`를 눌렀을 때 띄울 한 줄.
##
## **비워 두면 입력을 조용히 무시한다.** 조용한 무시는 "키가 고장 났나"로 읽히므로
## 잠긴 구역에는 반드시 문구를 넣는다. 규칙(정책)과 문구를 같은 리소스에 두는 이유는
## 둘이 어긋나는 것 — 잠기지 않았는데 안내문만 있는 상태 — 을 한눈에 보기 위해서다.
@export_multiline var phase_locked_notice: String = ""

## 스폰 지점 id를 못 찾았을 때 쓸 기본 지점(설계 §1-3).
## 이 id의 SpawnPoint마저 없으면 씬에 배치된 플레이어 위치를 그대로 쓰고 경고를 남긴다.
@export var default_spawn_id: StringName = &"default"


func is_phase_locked() -> bool:
	return phase_policy != PhasePolicy.FREE


## 잠긴 시간대가 밤인가. `is_phase_locked()`가 false일 때 호출하면 의미가 없다.
func locked_is_night() -> bool:
	return phase_policy == PhasePolicy.LOCK_NIGHT


## 안내 문구의 `{zone}`를 구역 이름으로 치환한다. 비어 있으면 빈 문자열 —
## 호출부는 "빈 문자열이면 알림을 띄우지 않는다"로 처리한다.
func resolve_notice() -> String:
	if phase_locked_notice.is_empty():
		return ""
	return phase_locked_notice.replace("{zone}", display_name)

extends Node
## 낮/밤 상태를 관리하는 전역 싱글톤 (autoload: DayNight).
##
## 옥토패스에서 낮/밤은 단순한 조명 변화가 아니라 게임 규칙의 일부다.
## 조명(hd2d-visual), NPC 패스 액션 선택지, 대사가 모두 이 상태를 구독한다.
## 그래서 상태를 여기 한 곳에만 두고, 나머지는 시그널로 반응하게 한다.

signal phase_changed(is_night: bool)

## 조명 전환 시간. 즉시 바꾸면 화면이 튀어서 1.5초에 걸쳐 보간한다.
const TRANSITION_SEC: float = 1.5

var is_night: bool = false


func toggle() -> void:
	set_night(not is_night)


func set_night(value: bool) -> void:
	# 같은 값으로 다시 설정하면 시그널을 쏘지 않는다.
	# 구독자(조명 Tween 등)가 불필요하게 재시작되는 것을 막는다.
	if value == is_night:
		return
	is_night = value
	phase_changed.emit(is_night)


## UI 표시용 시간대 이름.
func phase_name() -> String:
	return "밤" if is_night else "낮"

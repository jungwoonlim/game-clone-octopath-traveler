extends SceneTree
## DayNight 규칙 검증.
##
## autoload에 의존하지 않고 스크립트를 직접 인스턴스화한다.
## `--script`로 커스텀 MainLoop을 돌리면 autoload 초기화 시점을 보장할 수 없기 때문이다.

var _failed: int = 0


func _init() -> void:
	var day_night: Node = load("res://scripts/core/day_night.gd").new()

	_assert_eq(day_night.is_night, false, "초기 상태는 낮")
	_assert_eq(day_night.phase_name(), "낮", "초기 시간대 이름")

	# 시그널이 실제로 발화하는지 확인한다. 조명과 패스 액션이 여기에 의존한다.
	var emitted: Array = []
	day_night.phase_changed.connect(func(is_night: bool) -> void: emitted.append(is_night))

	day_night.toggle()
	_assert_eq(day_night.is_night, true, "토글 후 밤")
	_assert_eq(emitted.size(), 1, "토글 시 시그널 1회 발화")

	# 같은 값으로 다시 설정하면 시그널이 중복 발화하지 않아야 한다.
	# 이걸 놓치면 조명 Tween이 매번 재시작돼 전환이 끊겨 보인다.
	day_night.set_night(true)
	_assert_eq(emitted.size(), 1, "같은 값 재설정 시 시그널 미발화")

	day_night.toggle()
	_assert_eq(day_night.phase_name(), "낮", "다시 토글하면 낮")

	day_night.free()
	quit(_failed)


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		print("TEST PASS: ", label)
	else:
		_failed += 1
		printerr("TEST FAIL: ", label, " — 기대 ", expected, ", 실제 ", actual)

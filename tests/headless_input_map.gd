extends SceneTree
## 입력 맵이 설계 문서(_workspace/M1_design_field.md §1-2)대로 등록됐는지 검사한다.
##
## 왜 테스트까지 두는가: `project.godot`의 `[input]` 섹션은 Object(...) 직렬화 문자열이라
## 손으로 쓰다 한 글자만 틀려도 **에러 없이 그 액션만 조용히 사라진다.**
## 그러면 게임은 정상 실행되는데 특정 키만 안 먹고, 원인을 코드에서 찾게 된다.
## 액션이 없으면 `Input.get_vector()`도 예외 없이 0을 돌려주므로 런타임에도 티가 안 난다.

## 액션명 → 그 액션에 반드시 걸려 있어야 할 물리 키(physical_keycode)와 keycode.
## 설계 문서의 표를 그대로 옮긴 것이며, 표를 바꾸면 여기도 함께 바꾼다.
const EXPECTED_KEYS: Dictionary = {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"interact": [KEY_SPACE, KEY_ENTER],
	"cancel": [KEY_ESCAPE, KEY_BACKSPACE],
	"menu": [KEY_TAB],
	"toggle_phase": [KEY_N],
}

## 게임패드 버튼도 함께 검사한다. 키보드만 맞고 패드가 빠지는 실수가 흔하다.
const EXPECTED_BUTTONS: Dictionary = {
	"move_up": JOY_BUTTON_DPAD_UP,
	"move_down": JOY_BUTTON_DPAD_DOWN,
	"move_left": JOY_BUTTON_DPAD_LEFT,
	"move_right": JOY_BUTTON_DPAD_RIGHT,
	"interact": JOY_BUTTON_A,
	"cancel": JOY_BUTTON_B,
	"menu": JOY_BUTTON_START,
	"toggle_phase": JOY_BUTTON_Y,
}

## 게임플레이 입력이 UI 내비게이션을 덮어쓰지 않았는지 확인한다.
## ui_accept를 잃으면 Godot 기본 UI가 조용히 망가진다 (설계 §1-1).
const UI_ACTIONS: PackedStringArray = [
	"ui_accept", "ui_cancel", "ui_up", "ui_down", "ui_left", "ui_right",
]


func _init() -> void:
	for action: String in EXPECTED_KEYS:
		_check_action_exists(action)
		_check_keys(action, EXPECTED_KEYS[action])
		_check_button(action, EXPECTED_BUTTONS[action])

	for action in UI_ACTIONS:
		_check_action_exists(action)

	_check_wasd_is_physical()
	quit()


func _check_action_exists(action: String) -> void:
	if InputMap.has_action(action):
		print("TEST PASS: 액션 등록 — ", action)
	else:
		printerr("TEST FAIL: 액션이 InputMap에 없다 — ", action)


func _check_keys(action: String, expected: Array) -> void:
	if not InputMap.has_action(action):
		return
	var found: Array[int] = []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var key := ev as InputEventKey
			# physical_keycode로 등록한 것과 keycode로 등록한 것이 섞여 있다.
			# 어느 쪽이든 0이 아닌 값을 실제 바인딩으로 본다.
			found.append(key.physical_keycode if key.physical_keycode != 0 else key.keycode)

	for want: int in expected:
		if found.has(want):
			print("TEST PASS: %s 키 바인딩 — %s" % [action, OS.get_keycode_string(want)])
		else:
			printerr("TEST FAIL: %s에 키 %s가 없다 — 실제 %s" % [
				action, OS.get_keycode_string(want), str(found)
			])


func _check_button(action: String, expected: int) -> void:
	if not InputMap.has_action(action):
		return
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton and (ev as InputEventJoypadButton).button_index == expected:
			print("TEST PASS: %s 패드 버튼 %d" % [action, expected])
			return
	printerr("TEST FAIL: %s에 패드 버튼 %d가 없다" % [action, expected])


## WASD는 physical_keycode여야 한다. keycode로 등록하면 AZERTY·드보락에서 엉뚱한 키가 걸린다.
func _check_wasd_is_physical() -> void:
	var wasd := {"move_up": KEY_W, "move_down": KEY_S, "move_left": KEY_A, "move_right": KEY_D}
	for action: String in wasd:
		if not InputMap.has_action(action):
			continue
		var ok := false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey and (ev as InputEventKey).physical_keycode == wasd[action]:
				ok = true
		if ok:
			print("TEST PASS: %s는 physical_keycode로 등록" % action)
		else:
			printerr("TEST FAIL: %s의 %s가 physical_keycode가 아니다" % [
				action, OS.get_keycode_string(wasd[action])
			])

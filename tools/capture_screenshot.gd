extends SceneTree
## 실행 화면을 PNG로 저장한다. 비주얼(DOF·블룸·조명)을 사람이나 에이전트가 확인하기 위한 도구.
##
## 헤드리스(`--headless`)로 돌리면 dummy 렌더러라 빈 이미지가 나온다.
## 반드시 창 모드로 실행해야 한다 — `godot.sh shot`이 이를 처리한다.
##
## 인자: --scene=<res 경로>  --out=<저장 경로>  --frames=<대기 프레임>
##       --night=true|false  --actions=<입력 타임라인>  --pose=<x>,<z>
##
## 입력 타임라인이 필요한 이유:
## 정지 화면만 찍을 수 있으면 "걷는 모습·대화창·메뉴"처럼 조작해야 나타나는 것을
## 에이전트가 영영 확인할 수 없다. 실제로 M1 이전까지는 캡처로 검증 가능한 범위가
## "가만히 서 있는 화면"뿐이었다.
##
## 타임라인 문법 — `;`로 단계를 잇는다:
##   wait:<프레임>              그냥 기다린다
##   hold:<액션>:<프레임>        액션을 누른 채 그만큼 기다렸다 뗀다 (이동용)
##   press:<액션>               한 번 눌렀다 뗀다 (상호작용·메뉴 확정용)
##   night                      밤으로 전환한다 (타임라인 중간에 바꿀 때)
##
## 예: --actions="wait:30;hold:move_right:40;press:interact;wait:40"
##
## `--pose=x,z`는 플레이어를 그 좌표에 즉시 세우고 카메라를 보간 없이 붙인다.
##
## 왜 필요한가: `hold:<액션>:<프레임>`으로는 "끝까지 걸어간 화면"을 재현할 수 없다.
## 창 모드 fps가 상황에 따라 크게 흔들려(macOS App Nap 등) 같은 프레임 수가 매번 다른
## 이동량이 된다. 실제로 `hold:move_left:90`으로 찍은 화면이 플레이어가 중앙에 있는 상태였고
## 그걸 "서쪽 끝"으로 오독할 뻔했다. 구도 검증은 프레임이 아니라 좌표로 지정해야 한다.
##
## `--pose`와 `--actions`는 함께 쓸 수 있다 — 먼저 세우고, 그 자리에서 조작한다.

## 추적 카메라 스크립트가 노출하는 프로퍼티 이름.
## 이 이름이 바뀌면 pose가 조용히 카메라를 안 옮기고 보간이 끝나기를 기다리게 되므로
## 없으면 실패로 끊는다.
const CAM_PROPS: PackedStringArray = ["follow_offset", "limit_x", "limit_z"]

const DEFAULT_SCENE := "res://scenes/main/Main.tscn"
const DEFAULT_OUT := "res://_screenshots/shot.png"

# 조명 Tween과 씬 초기화가 안정되기를 기다리는 기본 프레임 수.
const DEFAULT_FRAMES := 45

# press 한 번이 차지하는 프레임. 1프레임이면 `_unhandled_input`이 뗌을 못 볼 수 있어 여유를 둔다.
const PRESS_FRAMES := 3


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene_path := _arg("scene", DEFAULT_SCENE)
	var out_path := _arg("out", DEFAULT_OUT)
	var frames := int(_arg("frames", str(DEFAULT_FRAMES)))

	var err := change_scene_to_file(scene_path)
	if err != OK:
		printerr("CAPTURE FAIL: 씬을 로드할 수 없다 — ", scene_path)
		quit(1)
		return

	# 밤 화면을 찍으려면 씬이 붙은 뒤에 상태를 바꿔야 한다.
	if _arg("night", "false") == "true":
		await process_frame
		_switch_to_night()

	# 씬이 붙고 조명·카메라가 자리를 잡을 때까지 기다린다.
	# 너무 일찍 찍으면 첫 프레임의 미완성 화면이 저장된다.
	for i in frames:
		await process_frame

	# 구도 검증은 프레임 수가 아니라 좌표로 지정한다. 입력 재생보다 먼저 세운다.
	var pose := _arg("pose", "")
	if not pose.is_empty():
		if not _apply_pose(pose):
			quit(1)
			return
		await process_frame

	# 조작이 필요한 화면(이동·대화·메뉴)은 여기서 입력을 재생한 뒤 찍는다.
	var timeline := _arg("actions", "")
	if not timeline.is_empty():
		if not await _play_actions(timeline):
			quit(1)
			return

	# 여기서 FPS를 재지 않는다. 캡처 시점은 아직 셰이더 컴파일 중이라
	# 실제 성능보다 훨씬 낮게 나온다 (74fps인 씬이 13fps로 찍혔다).
	# 성능은 워밍업을 거치는 tools/measure_fps.gd로 잰다.

	# 렌더가 실제로 끝난 뒤에 뷰포트를 읽어야 한다.
	await RenderingServer.frame_post_draw

	var img := root.get_texture().get_image()
	if img == null or img.is_empty():
		printerr("CAPTURE FAIL: 빈 이미지. 헤드리스로 실행하지 않았는지 확인하라.")
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var save_err := img.save_png(out_path)
	if save_err != OK:
		printerr("CAPTURE FAIL: 저장 실패 — ", out_path)
		quit(1)
		return

	print("CAPTURE OK: ", ProjectSettings.globalize_path(out_path))
	quit(0)


## 플레이어를 지정 좌표에 세우고 카메라를 즉시 그 구도로 옮긴다. 실패하면 false.
##
## 카메라는 보간(`field_camera.gd`의 감쇠 추적)을 기다리지 않고 목표 위치를 직접 계산해 붙인다.
## 보간을 기다리면 "몇 프레임 뒤에 찍어야 도착하는가"가 다시 fps에 의존하게 된다.
func _apply_pose(pose: String) -> bool:
	var xz := pose.split(",")
	if xz.size() != 2:
		printerr("CAPTURE FAIL: pose 문법은 --pose=<x>,<z> — ", pose)
		return false

	# 노드 이름이 아니라 타입으로 찾는다. 씬에서 "Player"로 인스턴스돼 있어 이름은 바뀔 수 있지만,
	# 필드에 CharacterBody3D는 플레이어뿐이다. 이름을 박으면 씬을 고칠 때 조용히 깨진다.
	var bodies := root.find_children("*", "CharacterBody3D", true, false)
	if bodies.is_empty():
		printerr("CAPTURE FAIL: CharacterBody3D(플레이어)를 찾지 못했다")
		return false
	if bodies.size() > 1:
		printerr("CAPTURE FAIL: CharacterBody3D가 %d개다 — 어느 것이 플레이어인지 알 수 없다" % bodies.size())
		return false
	var player := bodies[0] as Node3D

	var cam := root.get_viewport().get_camera_3d()
	if cam == null:
		printerr("CAPTURE FAIL: 활성 Camera3D가 없다")
		return false

	# 플레이어의 y는 유지한다. 지면 높이를 여기서 추측하면 공중이나 바닥 아래에 박힌다.
	player.global_position = Vector3(float(xz[0]), player.global_position.y, float(xz[1]))

	for prop in CAM_PROPS:
		if not prop in cam:
			printerr("CAPTURE FAIL: 카메라에 '%s'가 없다 — 추적 카메라 스크립트가 붙어 있는지 확인하라" % prop)
			return false

	# 추적 카메라와 **같은 규칙**으로 계산한다. 규칙이 갈라지면 pose 화면과 실제 플레이 화면이 달라진다.
	var target: Vector3 = player.global_position + (cam.get("follow_offset") as Vector3)
	var lx: Vector2 = cam.get("limit_x")
	var lz: Vector2 = cam.get("limit_z")
	target.x = clampf(target.x, lx.x, lx.y)
	target.z = clampf(target.z, lz.x, lz.y)
	cam.global_position = target

	print("  pose: 플레이어 %v / 카메라 %v" % [player.global_position, cam.global_position])
	return true


## 입력 타임라인을 재생한다. 실패하면 false.
func _play_actions(timeline: String) -> bool:
	for step in timeline.split(";", false):
		var parts := step.strip_edges().split(":")
		match parts[0]:
			"wait":
				if not await _step_wait(parts):
					return false
			"hold":
				if not await _step_hold(parts):
					return false
			"press":
				if not await _step_press(parts):
					return false
			"night":
				_switch_to_night()
				await process_frame
			_:
				printerr("CAPTURE FAIL: 알 수 없는 타임라인 단계 — ", step)
				return false
		print("  입력: ", step.strip_edges())
	return true


func _step_wait(parts: PackedStringArray) -> bool:
	if parts.size() != 2:
		printerr("CAPTURE FAIL: wait 문법은 wait:<프레임> — ", ":".join(parts))
		return false
	for i in int(parts[1]):
		await process_frame
	return true


func _step_hold(parts: PackedStringArray) -> bool:
	if parts.size() != 3:
		printerr("CAPTURE FAIL: hold 문법은 hold:<액션>:<프레임> — ", ":".join(parts))
		return false
	if not _has_action(parts[1]):
		return false
	# action_press는 폴링(Input.is_action_pressed)용 상태만 바꾼다.
	# 이동은 폴링으로 읽으므로 이것으로 충분하다.
	Input.action_press(parts[1])
	for i in int(parts[2]):
		await process_frame
	Input.action_release(parts[1])
	await process_frame
	return true


func _step_press(parts: PackedStringArray) -> bool:
	if parts.size() != 2:
		printerr("CAPTURE FAIL: press 문법은 press:<액션> — ", ":".join(parts))
		return false
	if not _has_action(parts[1]):
		return false

	# 상호작용·메뉴는 이벤트(`_unhandled_input`)로 읽는 경우가 많은데,
	# action_press는 이벤트를 트리에 흘려보내지 않는다. 그래서 둘 다 한다 —
	# 폴링 상태(action_press)와 실제 이벤트(parse_input_event)를 함께 만든다.
	var ev := InputEventAction.new()
	ev.action = parts[1]
	ev.pressed = true
	ev.strength = 1.0
	Input.action_press(parts[1])
	Input.parse_input_event(ev)
	for i in PRESS_FRAMES:
		await process_frame

	var up := InputEventAction.new()
	up.action = parts[1]
	up.pressed = false
	Input.action_release(parts[1])
	Input.parse_input_event(up)
	await process_frame
	return true


## 액션이 InputMap에 없으면 입력이 조용히 무시된다.
## 아무 일도 안 일어난 화면을 "정상 캡처"로 넘기지 않도록 여기서 끊는다.
func _has_action(action: String) -> bool:
	if InputMap.has_action(action):
		return true
	printerr("CAPTURE FAIL: InputMap에 없는 액션 — ", action)
	return false


## 밤으로 전환한다.
##
## autoload는 커스텀 MainLoop(`--script`)에서 로드되지 않을 수 있으므로,
## 없으면 필드 씬을 직접 찾아 적용한다. 캡처 도구가 게임 실행 방식에 좌우되면 안 된다.
func _switch_to_night() -> void:
	var day_night := root.get_node_or_null("DayNight")
	if day_night != null:
		day_night.set_night(true)
		print("  밤 전환: DayNight autoload 사용")
		return

	var field := root.find_child("Field", true, false)
	if field != null and field.has_method("_apply_phase"):
		field.call("_apply_phase", true, false)
		print("  밤 전환: Field 직접 적용 (autoload 미로드)")
		return

	printerr("CAPTURE FAIL: 밤으로 전환할 대상을 찾지 못했다")


## `--key=value` 형태의 커맨드라인 인자를 읽는다.
func _arg(key: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.split("=", true, 1)[1]
	return fallback

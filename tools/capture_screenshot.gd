extends SceneTree
## 실행 화면을 PNG로 저장한다. 비주얼(DOF·블룸·조명)을 사람이나 에이전트가 확인하기 위한 도구.
##
## 헤드리스(`--headless`)로 돌리면 dummy 렌더러라 빈 이미지가 나온다.
## 반드시 창 모드로 실행해야 한다 — `godot.sh shot`이 이를 처리한다.
##
## 인자: --scene=<res 경로>  --out=<저장 경로>  --frames=<대기 프레임>

const DEFAULT_SCENE := "res://scenes/main/Main.tscn"
const DEFAULT_OUT := "res://_screenshots/shot.png"

# 조명 Tween과 씬 초기화가 안정되기를 기다리는 기본 프레임 수.
const DEFAULT_FRAMES := 45


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

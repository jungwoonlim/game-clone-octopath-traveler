extends SceneTree
## 프레임 성능을 측정한다.
##
## 캡처 도구에 곁들인 측정은 신뢰할 수 없다 — 씬 진입 직후에는 셰이더 컴파일과
## 리소스 업로드가 진행 중이라 실제 성능보다 훨씬 낮게 나온다.
## 실제로 스프라이트를 제거했는데 FPS가 더 낮게 찍히는 일이 있었다.
## 그래서 충분히 워밍업한 뒤 긴 구간을 재고, 평균과 함께 최저값도 보고한다.
##
## 인자: --scene=<res 경로>  --night=true|false  --warmup=<프레임>  --sample=<프레임>

const DEFAULT_SCENE := "res://scenes/main/Main.tscn"
const DEFAULT_WARMUP := 180
const DEFAULT_SAMPLE := 120


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene_path := _arg("scene", DEFAULT_SCENE)
	var warmup := int(_arg("warmup", str(DEFAULT_WARMUP)))
	var sample := int(_arg("sample", str(DEFAULT_SAMPLE)))

	if change_scene_to_file(scene_path) != OK:
		printerr("BENCH FAIL: 씬 로드 실패 — ", scene_path)
		quit(1)
		return

	if _arg("night", "false") == "true":
		await process_frame
		var day_night := root.get_node_or_null("DayNight")
		if day_night != null:
			day_night.set_night(true)
		else:
			var field := root.find_child("Field", true, false)
			if field != null and field.has_method("_apply_phase"):
				field.call("_apply_phase", true, false)

	# 셰이더 컴파일과 리소스 업로드가 끝날 때까지 충분히 돌린다.
	for i in warmup:
		await process_frame

	var total := 0.0
	var worst := 99999.0
	for i in sample:
		await process_frame
		var f := Engine.get_frames_per_second()
		total += f
		worst = minf(worst, f)

	var avg := total / float(sample)
	print("BENCH avg=%.1f min=%.1f (warmup=%d sample=%d)" % [avg, worst, warmup, sample])
	quit(0)


func _arg(key: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.split("=", true, 1)[1]
	return fallback

extends SceneTree
## 스크린샷의 일부를 잘라 **최근접 확대**한다. UI 폰트의 안티에일리어싱처럼
## 640×360 원본에서는 눈으로 구분할 수 없는 픽셀 단위 차이를 확인하기 위한 도구다.
##
## 부드러운 보간으로 확대하면 AA가 있는 글자와 없는 글자가 똑같이 뿌옇게 보여
## 비교 자체가 불가능하다. 반드시 INTERPOLATE_NEAREST를 쓴다.
##
## 인자: --in=<res 경로> --out=<res 경로> --rect=<x>,<y>,<w>,<h> --scale=<배수>

func _init() -> void:
	var in_path := _arg("in", "")
	var out_path := _arg("out", "")
	var rect_arg := _arg("rect", "0,0,640,360").split(",")
	var scale := int(_arg("scale", "3"))

	var img := Image.load_from_file(ProjectSettings.globalize_path(in_path))
	if img == null:
		printerr("CROP FAIL: 이미지를 열 수 없다 — ", in_path)
		quit(1)
		return

	var rect := Rect2i(int(rect_arg[0]), int(rect_arg[1]), int(rect_arg[2]), int(rect_arg[3]))
	var cropped := img.get_region(rect)
	cropped.resize(rect.size.x * scale, rect.size.y * scale, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	if cropped.save_png(out_path) != OK:
		printerr("CROP FAIL: 저장 실패 — ", out_path)
		quit(1)
		return
	print("CROP OK: ", out_path)
	quit(0)


func _arg(key: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.split("=", true, 1)[1]
	return fallback

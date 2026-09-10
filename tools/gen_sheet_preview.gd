extends SceneTree
## 걷기 스프라이트 시트를 확대해 한 장으로 이어 붙인 검수용 미리보기를 만든다.
##
## 시트는 어느 씬에도 붙기 전이라 게임 스크린샷으로는 확인할 수 없다.
## 64x96 원본을 그냥 열면 방향도 걸음도 눈으로 셀 수 없으므로,
## NEAREST로 확대하고 셀 경계에 격자를 그려 프레임 단위로 세어볼 수 있게 한다.
## (INTERPOLATE_NEAREST 외의 보간을 쓰면 도트가 뭉개져 검수 자체가 무의미해진다.)
##
## 실행: godot --headless --path . --script res://tools/gen_sheet_preview.gd

const SHEETS := [
	"res://assets/placeholder/char_player_sheet.png",
	"res://assets/placeholder/char_npc_a_sheet.png",
	"res://assets/placeholder/char_npc_b_sheet.png",
	"res://assets/placeholder/char_npc_c_sheet.png",
]
const OUT_PATH := "res://_screenshots/m1_sheet_preview.png"

const CELL_W := 16
const CELL_H := 24
const COLS := 4  # 걷기 프레임
const ROWS := 4  # 방향
const SCALE := 6  # 16x24 셀이 96x144가 된다 — 픽셀 하나를 눈으로 셀 수 있는 최소 배율
const MARGIN := 24  # 왼쪽 방향 색상 바 영역

# 방향 행 색상 바: 0=남(빨강) 1=서(초록) 2=동(파랑) 3=북(노랑)
const DIR_COLORS := [
	Color8(198, 74, 66),
	Color8(86, 166, 92),
	Color8(76, 118, 198),
	Color8(206, 182, 74),
]

const BG := Color8(24, 24, 30)  # 시트 밖 여백
const SPRITE_BG := Color8(58, 58, 68)  # 알파 영역. 검정이면 어두운 도트가 배경에 묻힌다
const GRID := Color8(96, 96, 116)
const SEP := Color8(232, 200, 92)


func _init() -> void:
	var sheet_w := CELL_W * COLS
	var sheet_h := CELL_H * ROWS

	# 1) 시트 4장을 세로로 이어 붙인다 (알파는 회색 배경 위에 합성)
	var combo := Image.create(sheet_w, sheet_h * SHEETS.size(), false, Image.FORMAT_RGBA8)
	combo.fill(SPRITE_BG)
	for i in SHEETS.size():
		var img := Image.load_from_file(SHEETS[i])
		if img == null:
			printerr("PREVIEW FAIL: 열 수 없음 ", SHEETS[i])
			quit(1)
			return
		if img.get_width() != sheet_w or img.get_height() != sheet_h:
			printerr("PREVIEW FAIL: 크기가 %dx%d 가 아님 — %s (%dx%d)"
				% [sheet_w, sheet_h, SHEETS[i], img.get_width(), img.get_height()])
			quit(1)
			return
		img.convert(Image.FORMAT_RGBA8)
		combo.blend_rect(img, Rect2i(0, 0, sheet_w, sheet_h), Vector2i(0, i * sheet_h))

	# 2) NEAREST 확대
	combo.resize(combo.get_width() * SCALE, combo.get_height() * SCALE,
		Image.INTERPOLATE_NEAREST)

	# 3) 여백을 두고 격자를 얹는다. 확대 뒤에 그려야 선이 1px로 얇게 남는다.
	var out := Image.create(MARGIN + combo.get_width(), combo.get_height(),
		false, Image.FORMAT_RGBA8)
	out.fill(BG)
	out.blit_rect(combo, Rect2i(0, 0, combo.get_width(), combo.get_height()),
		Vector2i(MARGIN, 0))

	var cw := CELL_W * SCALE
	var ch := CELL_H * SCALE
	var sh := ch * ROWS
	var h := out.get_height()

	# 프레임 열 경계 (세로선)
	for c in range(1, COLS):
		out.fill_rect(Rect2i(MARGIN + c * cw, 0, 1, h), GRID)
	# 방향 행 경계 (가로선)
	for i in SHEETS.size():
		for r in range(1, ROWS):
			out.fill_rect(Rect2i(MARGIN, i * sh + r * ch, out.get_width() - MARGIN, 1), GRID)
		# 시트 구분선은 굵고 다른 색으로
		if i > 0:
			out.fill_rect(Rect2i(0, i * sh - 1, out.get_width(), 2), SEP)
		# 방향 색상 바
		for r in ROWS:
			out.fill_rect(Rect2i(6, i * sh + r * ch + 4, 12, ch - 8), DIR_COLORS[r])

	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUT_PATH).get_base_dir())
	var err := out.save_png(OUT_PATH)
	if err != OK:
		printerr("PREVIEW FAIL: 저장 실패 ", OUT_PATH)
		quit(1)
		return
	print("PREVIEW OK: ", OUT_PATH, " (", out.get_width(), "x", out.get_height(), ")")
	quit(0)

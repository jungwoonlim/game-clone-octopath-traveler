extends SceneTree
## 플레이스홀더 픽셀아트 텍스처를 생성한다.
##
## 도트풍의 핵심은 애셋 퀄리티가 아니라 "픽셀 밀도가 낮다"는 사실 자체다.
## 매끈한 단색 머티리얼로는 아무리 조명을 잘 잡아도 3D처럼 보인다.
## 그래서 낮은 해상도(16~48px)로 텍스처를 만들고, NEAREST 필터로 확대해 쓴다.
##
## 실행: godot --headless --path . --script res://tools/gen_placeholder_textures.gd

const OUT_DIR := "res://assets/placeholder"

# 시드를 고정해 매번 같은 텍스처가 나오게 한다. 재생성해도 화면이 달라지지 않아야
# 비주얼 변경의 원인이 텍스처인지 세팅인지 구분할 수 있다.
const SEED := 20260910


func _init() -> void:
	seed(SEED)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	_save(_make_grass(), "grass.png")
	_save(_make_dirt_path(), "dirt.png")
	_save(_make_stone_wall(), "stone_wall.png")
	_save(_make_wood_wall(), "wood_wall.png")
	_save(_make_tree(), "tree.png")
	_save(_make_bush(), "bush.png")
	_save(_make_character(Color(0.85, 0.35, 0.3), Color(0.95, 0.8, 0.65)), "char_player.png")
	_save(_make_character(Color(0.35, 0.45, 0.75), Color(0.9, 0.75, 0.6)), "char_npc_a.png")
	_save(_make_character(Color(0.5, 0.65, 0.4), Color(0.85, 0.7, 0.55)), "char_npc_b.png")

	# M2 — 마을을 채우는 소품들
	_save(_make_roof(), "roof.png")
	_save(_make_cliff(), "cliff.png")
	_save(_make_water(), "water.png")
	_save(_make_fence(), "fence.png")
	_save(_make_rock(), "rock.png")
	_save(_make_grass_tuft(), "grass_tuft.png")
	_save(_make_flowers(), "flowers.png")
	_save(_make_lantern(), "lantern.png")
	_save(_make_crate(), "crate.png")
	_save(_make_signpost(), "signpost.png")

	# 샘플② 도시 밤 광장용
	_save(_make_cobblestone(), "cobblestone.png")
	_save(_make_stone_block(), "stone_block.png")
	_save(_make_plaza_medallion(), "medallion.png")
	_save(_make_window(true), "window_lit.png")
	_save(_make_window(false), "window_dark.png")
	_save(_make_roof_slate(), "roof_slate.png")
	_save(_make_iron_fence(), "iron_fence.png")
	_save(_make_street_lamp(), "street_lamp.png")
	_save(_make_cypress(), "cypress.png")
	_save(_make_statue(), "statue.png")

	# 건물 파사드 — 창문을 개별 노드로 두면 수십 개가 되므로 텍스처에 그려 넣는다.
	# 같은 좌표계로 발광 마스크를 함께 만들어 창문만 빛나게 한다.
	_save(_make_light_glow(), "light_glow.png")

	var facade := _make_facade()
	_save(facade[0], "facade.png")
	_save(facade[1], "facade_emission.png")

	print("TEXGEN OK")
	quit(0)


func _save(img: Image, filename: String) -> void:
	var path := "%s/%s" % [OUT_DIR, filename]
	var err := img.save_png(path)
	if err != OK:
		printerr("TEXGEN FAIL: ", path)
	else:
		print("  생성: ", path, " (", img.get_width(), "x", img.get_height(), ")")


## 팔레트에서 가중치 없이 하나 고른다. 도트 특유의 거친 질감을 만든다.
func _pick(palette: Array) -> Color:
	return palette[randi() % palette.size()]


# ── 지면 타일 ────────────────────────────────────────────────

func _make_grass() -> Image:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var base := [
		Color8(74, 106, 58), Color8(84, 118, 64),
		Color8(66, 96, 52), Color8(92, 128, 70),
	]
	for y in 32:
		for x in 32:
			img.set_pixel(x, y, _pick(base))
	# 풀잎 하이라이트 — 규칙적이면 인위적으로 보이므로 흩뿌린다
	for i in 26:
		var x := randi() % 32
		var y := randi() % 32
		img.set_pixel(x, y, Color8(118, 152, 84))
		if y > 0:
			img.set_pixel(x, y - 1, Color8(104, 138, 76))
	return img


func _make_dirt_path() -> Image:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var base := [
		Color8(124, 100, 72), Color8(136, 110, 80),
		Color8(112, 90, 66), Color8(146, 120, 88),
	]
	for y in 32:
		for x in 32:
			img.set_pixel(x, y, _pick(base))
	for i in 18:
		img.set_pixel(randi() % 32, randi() % 32, Color8(96, 76, 56))
	return img


# ── 벽 ──────────────────────────────────────────────────────

func _make_stone_wall() -> Image:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var stone := [Color8(146, 140, 128), Color8(158, 152, 140), Color8(134, 128, 118)]
	var mortar := Color8(96, 92, 86)

	for y in 32:
		for x in 32:
			img.set_pixel(x, y, _pick(stone))

	# 벽돌 이음새. 줄마다 반 칸씩 어긋나게 해서 벽돌처럼 보이게 한다.
	for y in 32:
		if y % 8 == 0:
			for x in 32:
				img.set_pixel(x, y, mortar)
	for row in 4:
		var y_start := row * 8
		var offset := 0 if row % 2 == 0 else 8
		var x := offset
		while x < 32:
			for y in range(y_start, mini(y_start + 8, 32)):
				img.set_pixel(x, y, mortar)
			x += 16
	return img


func _make_wood_wall() -> Image:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var wood := [Color8(140, 100, 62), Color8(126, 88, 54), Color8(152, 112, 70)]
	for y in 32:
		for x in 32:
			img.set_pixel(x, y, _pick(wood))
	# 세로 널빤지 이음새
	for x in [0, 8, 16, 24]:
		for y in 32:
			img.set_pixel(x, y, Color8(96, 66, 40))
	return img


# ── 스프라이트 (알파 포함) ────────────────────────────────────

func _make_tree() -> Image:
	var img := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var trunk := [Color8(96, 68, 44), Color8(82, 58, 38)]
	# 기둥 — 아래쪽 1/3
	for y in range(30, 48):
		for x in range(13, 19):
			img.set_pixel(x, y, _pick(trunk))

	# 잎 덩어리 — 원형 실루엣을 픽셀로 근사한다.
	# 매끈한 원이 아니라 들쭉날쭉해야 도트처럼 보인다.
	var leaf := [Color8(58, 96, 52), Color8(70, 112, 60), Color8(46, 80, 44)]
	var cx := 16.0
	var cy := 18.0
	for y in 38:
		for x in 32:
			var dx := (x - cx) / 14.0
			var dy := (y - cy) / 16.0
			var d := dx * dx + dy * dy
			# 경계에 랜덤을 섞어 윤곽을 거칠게 만든다
			if d < 1.0 - randf() * 0.18:
				img.set_pixel(x, y, _pick(leaf))

	# 상단 하이라이트 — 빛 방향감을 준다
	for i in 30:
		var x := 6 + randi() % 14
		var y := 4 + randi() % 10
		if img.get_pixel(x, y).a > 0.0:
			img.set_pixel(x, y, Color8(96, 140, 74))
	return img


func _make_bush() -> Image:
	var img := Image.create(24, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var leaf := [Color8(62, 100, 54), Color8(76, 118, 62), Color8(50, 84, 46)]
	for y in 20:
		for x in 24:
			var dx := (x - 12.0) / 11.0
			var dy := (y - 13.0) / 8.0
			if dx * dx + dy * dy < 1.0 - randf() * 0.2:
				img.set_pixel(x, y, _pick(leaf))
	return img


# ── M2: 마을 소품 ────────────────────────────────────────────

func _make_roof() -> Image:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var tile := [Color8(150, 74, 62), Color8(134, 64, 54), Color8(164, 86, 70)]
	for y in 32:
		for x in 32:
			img.set_pixel(x, y, _pick(tile))
	# 기와 단. 줄마다 반 칸 어긋나게 해서 겹친 기와처럼 보이게 한다.
	for row in 8:
		var y := row * 4
		for x in 32:
			img.set_pixel(x, y, Color8(102, 46, 40))
		var offset := 0 if row % 2 == 0 else 4
		var x2 := offset
		while x2 < 32:
			for yy in range(y, mini(y + 4, 32)):
				img.set_pixel(x2, yy, Color8(112, 52, 44))
			x2 += 8
	return img


func _make_cliff() -> Image:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var rock := [Color8(118, 106, 92), Color8(132, 120, 104), Color8(104, 94, 82)]
	for y in 32:
		for x in 32:
			img.set_pixel(x, y, _pick(rock))
	# 세로 균열 — 절벽면의 결을 만든다
	for i in 6:
		var x := randi() % 32
		var len := 8 + randi() % 16
		var y := randi() % 20
		for k in len:
			if y + k < 32:
				img.set_pixel(x, y + k, Color8(78, 70, 62))
				if randf() < 0.3 and x + 1 < 32:
					img.set_pixel(x + 1, y + k, Color8(88, 80, 70))
	return img


func _make_water() -> Image:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var water := [Color8(58, 108, 148), Color8(68, 122, 162), Color8(48, 96, 136)]
	for y in 32:
		for x in 32:
			img.set_pixel(x, y, _pick(water))
	# 잔물결 하이라이트 — 가로로 짧게 끊어 그려야 수면처럼 보인다
	for i in 14:
		var x := randi() % 28
		var y := randi() % 32
		var len := 2 + randi() % 4
		for k in len:
			img.set_pixel(x + k, y, Color8(128, 180, 208))
	return img


func _make_fence() -> Image:
	var img := Image.create(24, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var wood := [Color8(132, 96, 60), Color8(146, 108, 68), Color8(118, 84, 52)]
	# 기둥 2개
	for x in [2, 3, 4, 19, 20, 21]:
		for y in range(4, 20):
			img.set_pixel(x, y, _pick(wood))
	# 가로대 2줄
	for y in [7, 8, 13, 14]:
		for x in range(0, 24):
			img.set_pixel(x, y, _pick(wood))
	return img


func _make_rock() -> Image:
	var img := Image.create(20, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rock := [Color8(126, 118, 108), Color8(140, 132, 120), Color8(108, 100, 92)]
	for y in 16:
		for x in 20:
			var dx := (x - 10.0) / 9.5
			var dy := (y - 11.0) / 6.5
			if dx * dx + dy * dy < 1.0 - randf() * 0.15:
				img.set_pixel(x, y, _pick(rock))
	# 윗면 하이라이트로 입체감
	for x in range(6, 14):
		if img.get_pixel(x, 5).a > 0.0:
			img.set_pixel(x, 5, Color8(158, 150, 138))
	return img


func _make_grass_tuft() -> Image:
	var img := Image.create(14, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var blade := [Color8(88, 130, 62), Color8(102, 146, 70), Color8(74, 112, 54)]
	# 아래에서 위로 뻗는 잎 몇 가닥
	for i in 7:
		var x := 1 + randi() % 12
		var h := 4 + randi() % 7
		for k in h:
			var y := 11 - k
			if y >= 0:
				img.set_pixel(x, y, _pick(blade))
		# 잎 끝을 한 칸 기울인다
		if x + 1 < 14 and 11 - h >= 0:
			img.set_pixel(x + 1, 11 - h, _pick(blade))
	return img


func _make_flowers() -> Image:
	var img := Image.create(14, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var stem := Color8(84, 122, 58)
	var petals := [Color8(226, 208, 108), Color8(232, 138, 158), Color8(226, 226, 236)]
	for i in 4:
		var x := 2 + randi() % 10
		var h := 4 + randi() % 4
		for k in h:
			img.set_pixel(x, 11 - k, stem)
		var p: Color = petals[randi() % petals.size()]
		var top := 11 - h
		if top >= 0:
			img.set_pixel(x, top, p)
			if x > 0:
				img.set_pixel(x - 1, top, p)
			if x + 1 < 14:
				img.set_pixel(x + 1, top, p)
			if top > 0:
				img.set_pixel(x, top - 1, p)
	return img


## 등불. 밤에 OmniLight3D와 함께 놓으면 블룸으로 번져 분위기를 만든다.
func _make_lantern() -> Image:
	var img := Image.create(12, 22, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var post := Color8(74, 60, 48)
	# 기둥
	for y in range(9, 22):
		img.set_pixel(5, y, post)
		img.set_pixel(6, y, post)
	# 등갓
	for y in range(1, 3):
		for x in range(3, 9):
			img.set_pixel(x, y, post)
	# 불빛 — 중심이 가장 밝아야 광원처럼 보인다
	for y in range(3, 9):
		for x in range(3, 9):
			var edge: bool = x == 3 or x == 8 or y == 8
			img.set_pixel(x, y, post if edge else Color8(252, 226, 148))
	for y in range(4, 7):
		for x in range(5, 7):
			img.set_pixel(x, y, Color8(255, 248, 214))
	return img


func _make_crate() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var wood := [Color8(146, 110, 66), Color8(158, 122, 74), Color8(132, 98, 58)]
	for y in 16:
		for x in 16:
			img.set_pixel(x, y, _pick(wood))
	# 테두리와 대각 보강재
	for i in 16:
		img.set_pixel(i, 0, Color8(100, 74, 44))
		img.set_pixel(i, 15, Color8(100, 74, 44))
		img.set_pixel(0, i, Color8(100, 74, 44))
		img.set_pixel(15, i, Color8(100, 74, 44))
		img.set_pixel(i, i, Color8(112, 84, 50))
	return img


func _make_signpost() -> Image:
	var img := Image.create(16, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var post := Color8(112, 82, 50)
	var board := Color8(158, 124, 78)
	for y in range(8, 20):
		img.set_pixel(7, y, post)
		img.set_pixel(8, y, post)
	for y in range(2, 9):
		for x in range(1, 15):
			img.set_pixel(x, y, board if y > 2 and y < 8 and x > 1 and x < 14 else post)
	# 글자 대신 흠집 두 줄 — 읽히지 않아도 표지판으로 보인다
	for x in range(4, 12):
		img.set_pixel(x, 4, Color8(108, 82, 52))
	for x in range(4, 10):
		img.set_pixel(x, 6, Color8(108, 82, 52))
	return img


# ── 도시 밤 광장 (샘플②) ─────────────────────────────────────

## 광장 돌바닥. 벽돌처럼 규칙적이면 인공적으로 보이므로 둥근 돌을 흔들어 배치한다.
func _make_cobblestone() -> Image:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color8(52, 50, 48))
	var stone := [
		Color8(124, 120, 114), Color8(138, 133, 125),
		Color8(110, 106, 100), Color8(130, 124, 116),
	]
	for cy in 4:
		for cx in 4:
			var ox := cx * 8 + 4 + (randi() % 3 - 1)
			var oy := cy * 8 + 4 + (randi() % 3 - 1)
			var rx := 3.2 + randf() * 0.7
			var ry := 3.2 + randf() * 0.7
			var c: Color = _pick(stone)
			for y in 32:
				for x in 32:
					var dx := (x - ox) / rx
					var dy := (y - oy) / ry
					if dx * dx + dy * dy < 1.0:
						img.set_pixel(x, y, c)
			# 돌 윗면에 하이라이트를 한 줄 넣어 젖은 듯한 느낌을 준다
			if oy - 2 >= 0 and oy - 2 < 32:
				for x in range(maxi(ox - 2, 0), mini(ox + 2, 32)):
					if img.get_pixel(x, oy - 2) == c:
						img.set_pixel(x, oy - 2, c.lightened(0.18))
	return img


## 석조 건물 벽. stone_wall보다 블록이 크고 밝아 도시 건축물에 어울린다.
func _make_stone_block() -> Image:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var stone := [Color8(168, 160, 146), Color8(180, 172, 156), Color8(154, 147, 134)]
	var seam := Color8(104, 98, 90)
	for y in 32:
		for x in 32:
			img.set_pixel(x, y, _pick(stone))
	# 가로 줄눈 (16px 간격의 큰 블록)
	for y in [0, 1, 16, 17]:
		for x in 32:
			img.set_pixel(x, y, seam)
	# 세로 줄눈을 단마다 엇갈리게
	for row in 2:
		var y_start := row * 16
		var offset := 0 if row % 2 == 0 else 16
		for y in range(y_start, y_start + 16):
			var x := offset
			while x < 32:
				img.set_pixel(x, y, seam)
				if x + 1 < 32:
					img.set_pixel(x + 1, y, seam)
				x += 32
	return img


## 광장 중앙의 원형 모자이크. 샘플②에서 바닥의 초점 역할을 한다.
func _make_plaza_medallion() -> Image:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var light := Color8(188, 178, 160)
	var dark := Color8(138, 130, 118)
	var mid := Color8(164, 155, 140)

	for y in 64:
		for x in 64:
			var dx := x - 31.5
			var dy := y - 31.5
			var d := sqrt(dx * dx + dy * dy)
			if d > 31.0:
				continue
			# 동심원 띠
			var band := int(d / 4.0)
			var c := light if band % 2 == 0 else mid
			# 방사형 살 — 각도를 8등분해 밝고 어두운 쐐기를 번갈아 넣는다
			var ang := atan2(dy, dx) + PI
			var spoke := int(ang / (PI / 8.0))
			if spoke % 2 == 0 and d > 10.0 and d < 26.0:
				c = dark
			if d > 28.0:
				c = dark
			img.set_pixel(x, y, c)
	return img


## 아치형 창문. lit이면 안쪽이 등불색으로 빛난다.
func _make_window(lit: bool) -> Image:
	var img := Image.create(16, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var frame := Color8(96, 88, 78)
	var glass_lit := [Color8(252, 214, 138), Color8(255, 232, 176), Color8(242, 196, 118)]
	var glass_dark := [Color8(38, 44, 66), Color8(46, 52, 76)]

	for y in 24:
		for x in 16:
			# 위쪽은 아치, 아래쪽은 사각
			var inside: bool
			if y < 8:
				var dx := (x - 7.5) / 6.0
				var dy := (y - 8.0) / 7.0
				inside = dx * dx + dy * dy < 1.0
			else:
				inside = x >= 2 and x <= 13 and y <= 22
			if not inside:
				continue
			var edge: bool = (x <= 2 or x >= 13 or y >= 21)
			if edge:
				img.set_pixel(x, y, frame)
			else:
				img.set_pixel(x, y, _pick(glass_lit) if lit else _pick(glass_dark))

	# 창살
	for y in range(4, 22):
		if img.get_pixel(7, y).a > 0.0:
			img.set_pixel(7, y, frame)
	for x in range(2, 14):
		if img.get_pixel(x, 13).a > 0.0:
			img.set_pixel(x, 13, frame)
	return img


## 슬레이트 지붕. roof(붉은 기와)보다 어둡고 차가워 석조 건물에 어울린다.
func _make_roof_slate() -> Image:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var slate := [Color8(72, 78, 92), Color8(84, 90, 106), Color8(62, 68, 80)]
	for y in 32:
		for x in 32:
			img.set_pixel(x, y, _pick(slate))
	for row in 8:
		var y := row * 4
		for x in 32:
			img.set_pixel(x, y, Color8(48, 52, 62))
		var offset := 0 if row % 2 == 0 else 4
		var x2 := offset
		while x2 < 32:
			for yy in range(y, mini(y + 4, 32)):
				img.set_pixel(x2, yy, Color8(56, 61, 72))
			x2 += 8
	return img


## 철제 난간. 광장 경계를 두르고 전경 프레이밍에도 쓴다.
func _make_iron_fence() -> Image:
	var img := Image.create(24, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var iron := Color8(42, 44, 52)
	var iron_hi := Color8(66, 70, 82)

	# 세로 창살 5개, 끝을 뾰족하게
	for i in 5:
		var x := 2 + i * 5
		for y in range(4, 32):
			img.set_pixel(x, y, iron)
			if x + 1 < 24:
				img.set_pixel(x + 1, y, iron_hi if y % 7 == 0 else iron)
		# 창끝 장식
		img.set_pixel(x, 2, iron)
		if x + 1 < 24:
			img.set_pixel(x + 1, 3, iron)
		if x - 1 >= 0:
			img.set_pixel(x - 1, 3, iron)

	# 가로 띠 2줄
	for y in [8, 9, 22, 23]:
		for x in 24:
			img.set_pixel(x, y, iron if y % 2 == 0 else iron_hi)
	return img


## 장식 가로등. 기존 lantern(12x22)은 확대하면 도트 밀도가 어긋나 도시용으로 새로 만든다.
func _make_street_lamp() -> Image:
	var img := Image.create(20, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var iron := Color8(48, 46, 52)
	var iron_hi := Color8(74, 72, 80)
	var flame := Color8(255, 236, 176)
	var glow := Color8(252, 206, 120)

	# 기둥
	for y in range(14, 40):
		img.set_pixel(9, y, iron)
		img.set_pixel(10, y, iron_hi)
	# 받침
	for y in range(37, 40):
		for x in range(6, 14):
			img.set_pixel(x, y, iron)
	# 기둥 중간 장식 링
	for x in range(7, 13):
		img.set_pixel(x, 22, iron_hi)

	# 등갓 (위쪽 사각뿔)
	for y in range(2, 6):
		var w := y - 1
		for x in range(10 - w, 10 + w):
			img.set_pixel(x, y, iron)
	# 유리함 — 안쪽이 가장 밝아야 광원처럼 읽힌다
	for y in range(6, 14):
		for x in range(5, 15):
			var edge: bool = x == 5 or x == 14 or y == 13
			img.set_pixel(x, y, iron if edge else glow)
	for y in range(8, 12):
		for x in range(7, 13):
			img.set_pixel(x, y, flame)
	return img


## 침엽수. 샘플②에서 어두운 실루엣으로 광장 가장자리에 서 있다.
func _make_cypress() -> Image:
	var img := Image.create(24, 56, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var needle := [Color8(34, 56, 42), Color8(44, 70, 50), Color8(26, 44, 34)]
	var trunk := Color8(58, 44, 34)

	for y in range(50, 56):
		for x in range(10, 14):
			img.set_pixel(x, y, trunk)

	# 아래로 갈수록 넓어지는 원뿔. 윤곽을 흔들어 잎처럼 보이게 한다.
	for y in range(0, 52):
		var t := float(y) / 52.0
		var half := 1.5 + t * 9.0
		var jitter := randf() * 1.6
		for x in 24:
			if absf(x - 11.5) < half - jitter:
				img.set_pixel(x, y, _pick(needle))
	return img


## 석상. 건물 위나 기둥 위에 올려 도시의 격을 만든다.
func _make_statue() -> Image:
	var img := Image.create(20, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var stone := [Color8(172, 166, 154), Color8(186, 180, 168), Color8(156, 150, 140)]
	var shade := Color8(128, 122, 114)

	# 받침
	for y in range(32, 40):
		for x in range(3, 17):
			img.set_pixel(x, y, _pick(stone) if y < 38 else shade)
	# 몸통 — 아래로 살짝만 퍼지게 한다. 많이 퍼뜨리면 원뿔로 보인다.
	for y in range(15, 32):
		var t := float(y - 15) / 17.0
		var half := 3.0 + t * 2.2
		for x in 20:
			if absf(x - 9.5) < half:
				img.set_pixel(x, y, _pick(stone))
	# 어깨 — 사람 실루엣의 핵심 단서
	for y in range(13, 16):
		for x in range(5, 15):
			img.set_pixel(x, y, _pick(stone))
	# 머리
	for y in range(5, 13):
		for x in range(7, 13):
			img.set_pixel(x, y, _pick(stone))
	# 목
	for y in range(12, 14):
		for x in range(8, 12):
			img.set_pixel(x, y, shade)
	# 한쪽 팔을 들어 올린 자세
	for y in range(8, 16):
		img.set_pixel(14, y, _pick(stone))
		img.set_pixel(15, y, shade)
	for x in range(13, 16):
		img.set_pixel(x, 7, _pick(stone))
	return img


## 광원 주위의 빛무리.
##
## 볼류메트릭 안개로도 같은 효과를 낼 수 있지만 프레임이 주기적으로 크게 튄다
## (평균 85fps에 최저 16fps). 발광 스프라이트를 겹치는 쪽이 훨씬 싸고 안정적이다.
## 중심에서 가장자리로 부드럽게 사라져야 원판처럼 보이지 않는다.
func _make_light_glow() -> Image:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	for y in size:
		for x in size:
			var d := sqrt(pow(x - c, 2) + pow(y - c, 2)) / c
			if d >= 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			# 제곱으로 떨어뜨려 중심만 진하게 남긴다
			var a := pow(1.0 - d, 2.4)
			img.set_pixel(x, y, Color(1.0, 0.86, 0.62, a))
	return img


## 창문이 박힌 석조 파사드와 그 발광 마스크를 함께 만든다.
##
## 두 장을 한 함수에서 만드는 이유: 창문 좌표가 조금이라도 어긋나면 벽이 빛나거나
## 창문이 어두운 채로 남는다. 같은 루프에서 그려야 어긋날 수가 없다.
## 반환: [albedo, emission]
func _make_facade() -> Array:
	var size := 64
	var alb := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var emi := Image.create(size, size, false, Image.FORMAT_RGBA8)
	emi.fill(Color(0, 0, 0, 1))

	var stone := [Color8(166, 158, 144), Color8(178, 170, 154), Color8(152, 145, 132)]
	var seam := Color8(102, 96, 88)
	var frame := Color8(88, 80, 72)
	var glass := [Color8(252, 214, 138), Color8(255, 234, 178), Color8(240, 194, 116)]

	for y in size:
		for x in size:
			alb.set_pixel(x, y, _pick(stone))

	# 석재 줄눈
	for y in range(0, size, 8):
		for x in size:
			alb.set_pixel(x, y, seam)

	# 창문 2×2. 각 창은 아치형이며, 같은 픽셀을 발광 마스크에도 찍는다.
	var win_w := 14
	var win_h := 20
	for row in 2:
		for col in 2:
			var ox := 8 + col * 32
			var oy := 6 + row * 32
			for wy in win_h:
				for wx in win_w:
					var px := ox + wx
					var py := oy + wy
					if px >= size or py >= size:
						continue
					# 위쪽 절반은 아치
					var inside: bool
					if wy < 7:
						var dx := (wx - (win_w - 1) * 0.5) / (win_w * 0.5)
						var dy := (wy - 7.0) / 7.0
						inside = dx * dx + dy * dy < 1.0
					else:
						inside = true
					if not inside:
						continue

					var edge: bool = wx <= 1 or wx >= win_w - 2 or wy >= win_h - 2
					if edge:
						alb.set_pixel(px, py, frame)
					else:
						var g: Color = _pick(glass)
						alb.set_pixel(px, py, g)
						# 발광 마스크에는 유리만 찍는다
						emi.set_pixel(px, py, g)

			# 창살
			for wy in range(3, win_h - 2):
				var px := ox + win_w / 2
				var py := oy + wy
				if px < size and py < size and alb.get_pixel(px, py) != Color8(0, 0, 0, 0):
					alb.set_pixel(px, py, frame)
					emi.set_pixel(px, py, Color(0, 0, 0, 1))

	return [alb, emi]


## 간단한 인물 실루엣. 16x24는 SNES급 JRPG 캐릭터의 전형적인 크기다.
func _make_character(cloth: Color, skin: Color) -> Image:
	var img := Image.create(16, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var hair := Color8(58, 42, 34)
	var boot := Color8(62, 48, 38)
	var cloth_dark := cloth.darkened(0.25)

	# 머리 (y 2~9)
	for y in range(2, 10):
		for x in range(5, 11):
			img.set_pixel(x, y, skin)
	# 머리카락 — 이마와 옆면을 덮는다
	for x in range(5, 11):
		img.set_pixel(x, 2, hair)
		img.set_pixel(x, 3, hair)
	img.set_pixel(4, 3, hair)
	img.set_pixel(4, 4, hair)
	img.set_pixel(11, 3, hair)
	img.set_pixel(11, 4, hair)
	# 눈 — 2픽셀이면 충분히 얼굴로 읽힌다
	img.set_pixel(6, 6, Color8(40, 34, 30))
	img.set_pixel(9, 6, Color8(40, 34, 30))

	# 몸통 (y 10~17)
	for y in range(10, 18):
		for x in range(4, 12):
			img.set_pixel(x, y, cloth if x > 4 and x < 11 else cloth_dark)
	# 팔
	for y in range(11, 16):
		img.set_pixel(3, y, skin)
		img.set_pixel(12, y, skin)

	# 다리 (y 18~22)
	for y in range(18, 22):
		for x in range(5, 8):
			img.set_pixel(x, y, cloth_dark)
		for x in range(8, 11):
			img.set_pixel(x, y, cloth_dark)
	# 신발
	for x in range(5, 8):
		img.set_pixel(x, 22, boot)
	for x in range(8, 11):
		img.set_pixel(x, 22, boot)

	return img

extends Node3D
## 풀 다발과 꽃을 지면에 흩뿌린다.
##
## 수십 개의 장식을 .tscn에 직접 쓰면 파일이 읽기 어려워지고, 손으로 놓은 좌표는
## 규칙적으로 보여 오히려 부자연스럽다. 코드로 뿌리되 시드를 고정해
## 매 실행 같은 배치가 나오게 한다 — 그래야 비주얼 변화의 원인이 배치인지 세팅인지 구분된다.

@export var tuft_texture: Texture2D
@export var flower_texture: Texture2D

@export_range(0, 300) var tuft_count: int = 90
@export_range(0, 100) var flower_count: int = 26

@export_group("배경 숲")
## 화면 위쪽을 채우는 원경 숲. 카메라 각도가 낮을수록 배경이 화면을 많이 차지하므로,
## 나무를 띠 모양으로 촘촘히 뿌려 지평선을 가린다. 안 그러면 배경색 벽이 드러난다.
@export var tree_texture: Texture2D
@export_range(0, 200) var tree_count: int = 0
## 나무를 뿌릴 z 범위 (뒤쪽일수록 값이 작다)
@export var tree_band_z: Vector2 = Vector2(-16, -7)
## 나무를 뿌릴 x 폭 (중심 기준 ±절반)
@export var tree_band_width: float = 34.0
@export var tree_pixel_size_min: float = 0.062
@export var tree_pixel_size_max: float = 0.098

## 뿌릴 영역 (가로 × 세로). 카메라에 잡히는 범위보다 조금 넓게 잡는다.
@export var area_size: Vector2 = Vector2(24, 15)
@export var area_center: Vector2 = Vector2(0, -1)

@export var scatter_seed: int = 424242

## 스프라이트 크기를 조금씩 흔들어 도장 찍은 느낌을 없앤다.
const PIXEL_SIZE_MIN := 0.058
const PIXEL_SIZE_MAX := 0.076

## 길·물·건물 위에는 풀이 자라지 않는다. Rect2의 y는 월드 z 좌표로 쓴다.
const BLOCKED := [
	Rect2(-9.0, 0.2, 18.0, 2.8),      # 마을 대로
	Rect2(-1.8, -4.4, 2.4, 6.0),      # 갈림길
	Rect2(4.3, 2.0, 4.2, 2.8),        # 연못
	Rect2(-7.3, -6.4, 4.6, 3.6),      # 여관
	Rect2(3.8, -5.7, 3.6, 3.0),       # 상점
	Rect2(-19.0, -10.8, 38.0, 2.6),   # 절벽
]


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = scatter_seed

	_spawn_forest(rng)
	_spawn_batch(rng, tuft_texture, tuft_count)
	_spawn_batch(rng, flower_texture, flower_count)


## 배경 숲을 띠 모양으로 뿌린다.
## 뒤쪽(z가 작을수록) 나무를 작게 만들어 원근을 강조한다 — 크기가 균일하면 벽처럼 보인다.
func _spawn_forest(rng: RandomNumberGenerator) -> void:
	if tree_texture == null or tree_count <= 0:
		return

	var half := tree_band_width * 0.5
	for i in tree_count:
		var z := rng.randf_range(tree_band_z.x, tree_band_z.y)
		var x := rng.randf_range(-half, half)

		# 띠 안에서 뒤쪽일수록 작게. 0=가장 뒤, 1=가장 앞
		var depth_t := inverse_lerp(tree_band_z.x, tree_band_z.y, z)
		# lerp()는 Variant를 반환해 타입 추론이 깨진다. float 전용 lerpf를 쓴다.
		var px := lerpf(tree_pixel_size_min, tree_pixel_size_max, depth_t * rng.randf_range(0.7, 1.0))

		var sprite := Sprite3D.new()
		sprite.texture = tree_texture
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.shaded = true
		sprite.pixel_size = px
		sprite.position = Vector3(x, tree_texture.get_height() * px * 0.5, z)

		# 원경 나무의 그림자는 화면에 거의 안 보이면서 그림자맵만 잡아먹는다
		if depth_t < 0.5:
			sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		add_child(sprite)


func _spawn_batch(rng: RandomNumberGenerator, tex: Texture2D, count: int) -> void:
	if tex == null:
		return

	for i in count:
		var pos := _find_free_spot(rng)
		if pos == Vector2.INF:
			continue

		var sprite := Sprite3D.new()
		sprite.texture = tex
		# HD-2D 4속성 — 하나라도 빠지면 눕거나 뿌옇게 보인다
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.shaded = true

		var px := rng.randf_range(PIXEL_SIZE_MIN, PIXEL_SIZE_MAX)
		sprite.pixel_size = px
		# 텍스처 아래쪽이 지면에 닿도록 절반 높이만큼 띄운다
		sprite.position = Vector3(pos.x, tex.get_height() * px * 0.5, pos.y)

		# 작은 장식이 그림자를 드리우면 지면이 지저분해진다
		sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		add_child(sprite)


## 막힌 영역을 피해 자리를 찾는다. 몇 번 실패하면 포기하고 그 개체는 건너뛴다.
func _find_free_spot(rng: RandomNumberGenerator) -> Vector2:
	for attempt in 12:
		var p := Vector2(
			area_center.x + rng.randf_range(-area_size.x * 0.5, area_size.x * 0.5),
			area_center.y + rng.randf_range(-area_size.y * 0.5, area_size.y * 0.5)
		)
		var blocked := false
		for rect in BLOCKED:
			if (rect as Rect2).has_point(p):
				blocked = true
				break
		if not blocked:
			return p
	return Vector2.INF

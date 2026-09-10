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

	_spawn_batch(rng, tuft_texture, tuft_count)
	_spawn_batch(rng, flower_texture, flower_count)


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

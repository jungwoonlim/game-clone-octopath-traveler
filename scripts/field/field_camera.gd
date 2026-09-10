extends Camera3D
## 플레이어를 따라가는 필드 카메라.
##
## **각도는 −22° 부감으로 고정하고 위치만 보간한다.** 각도가 흔들리면 HD-2D 특유의
## 디오라마 인상이 즉시 깨진다(hd2d-visual §카메라). 그래서 이 스크립트는 rotation을 건드리지 않는다.

## 추적 대상. 보통 `Actors/Player`.
@export var target_path: NodePath

## 대상 기준 카메라 오프셋.
## 씬의 초기 구도(카메라 0,10,18 / 플레이어 0,0.8,0.6)의 차를 그대로 쓴 값이라
## 추적을 붙여도 화면 인상이 바뀌지 않는다.
@export var follow_offset: Vector3 = Vector3(0, 9.2, 17.4)

## 카메라 x 이동 한계 (min, max).
##
## 플레이어 깊이에서 화면 가로 반폭이 약 9.34m다(fov 30 / 16:9 → 가로 반각 25.5°, 깊이 ≈19.7).
## 따라서 카메라가 ±5에서 멈춰도 플레이 영역 끝(x=±10)에 선 플레이어는 화면 안에 남는다.
@export var limit_x: Vector2 = Vector2(-5.0, 5.0)

## 카메라 z 이동 한계 (min, max).
##
## **이것은 구도용이 아니라 DOF를 지키기 위한 값이다.**
## 카메라의 CameraAttributesPractical은 near 16 / far 28로 잡혀 있고,
## 이 범위를 벗어나면 주인공이 흐려진다.
## (near는 원래 17이었으나 남단에서 머리가 근블러에 들어가 M1 Stage 2b에서 16으로 내렸다.
##  실제 수치의 원천은 `Field.tscn`의 CameraAttributesPractical이다 — 그쪽을 바꾸면 여기도 고칠 것)
##   플레이어 z=+4.7(벽 안쪽 5.0 − 캡슐 반지름 0.3) / 카메라 z=19.5
##     → Δz 14.8, Δy 9.2 → 거리 가슴 16.87 / 머리 16.57 (near 16 위)
##   플레이어 z=−7.2 / 카메라 z=16.0 → Δz 23.2, Δy 9.2 → 거리 약 25 (far 28 아래)
## 카메라 오프셋이나 플레이 영역(z −7.5 ~ +5.0)을 바꾸면 이 계산을 다시 해야 한다.
@export var limit_z: Vector2 = Vector2(16.0, 19.5)

## 추적 감쇠 계수. 클수록 빨리 따라붙는다.
@export_range(1.0, 20.0, 0.5) var follow_damping: float = 8.0

@onready var _target: Node3D = get_node_or_null(target_path) as Node3D


func _ready() -> void:
	# 시작할 때는 보간 없이 붙인다. 안 그러면 게임 시작 직후 카메라가 밀려드는 것처럼 보인다.
	if _target != null:
		global_position = _desired_position()


func _physics_process(delta: float) -> void:
	if _target == null:
		return
	# 프레임률 독립 보간.
	# lerp(a, b, delta * k)는 프레임률이 달라지면 따라붙는 속도가 달라져,
	# 저사양 기기에서 카메라가 눈에 띄게 늘어진다.
	var weight := 1.0 - exp(-follow_damping * delta)
	global_position = global_position.lerp(_desired_position(), weight)


func _desired_position() -> Vector3:
	var p := _target.global_position + follow_offset
	p.x = clampf(p.x, limit_x.x, limit_x.y)
	p.z = clampf(p.z, limit_z.x, limit_z.y)
	return p

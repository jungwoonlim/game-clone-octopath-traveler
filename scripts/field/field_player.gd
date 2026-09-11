extends CharacterBody3D
## 필드 플레이어 — 8방향 이동과 걷기 스프라이트 애니메이션.
##
## 스프라이트 시트(`char_player_sheet.png`)는 64×96, 셀 16×24, 4열 × 4행이다.
##   행: 0=남(정면) 1=서 2=동 3=북
##   열: 0=대기, 1=왼발, 2=대기, 3=오른발
##   frame = 방향행 * COLUMNS + 프레임열
## 이 배치는 `FieldPlayer.tscn`의 `hframes=4 / vframes=4`와 짝이다. 한쪽만 바꾸면 엉뚱한 칸이 나온다.

## 시트의 방향행 인덱스.
const ROW_SOUTH: int = 0
const ROW_WEST: int = 1
const ROW_EAST: int = 2
const ROW_NORTH: int = 3

## 한 행의 프레임 열 개수 (= Sprite3D.hframes)
const COLUMNS: int = 4

## 걷기 순환 순서. 0→1→2→3이 대기·왼발·대기·오른발을 만든다.
const WALK_CYCLE: PackedInt32Array = [0, 1, 2, 3]

## 정지 시 쓰는 열.
const IDLE_COLUMN: int = 0

## 애니메이션 속도를 "1m 이동당 몇 프레임"으로 정의한다.
##
## 목표는 초당 8프레임이고 걷기 속도는 4.0 m/s이므로 8 ÷ 4.0 = 2.0.
## 프레임/초를 상수로 박으면 move_speed를 올렸을 때 발 놀림은 그대로인데 몸만 빨라져
## 지면에서 미끄러지는 것처럼 보인다. 이동 거리에 비례시키면 속도를 바꿔도 보폭이 유지된다.
const WALK_FRAMES_PER_METER: float = 2.0

## 가로 성분이 이 값을 넘으면 옆모습(서/동) 행을 쓴다.
##
## 대각선에서 가로를 우선하는 이유: 옆모습이 진행 방향을 가장 분명하게 보여주고,
## 정면/뒷모습 스프라이트는 좌우 기울기를 표현할 수단이 없다. 그래서 북동은 '동' 행이다.
## 0이 아닌 작은 값을 쓰는 것은 아날로그 스틱의 미세한 흔들림으로 정면이 옆모습으로
## 튀는 것을 막기 위해서다.
const SIDE_VIEW_THRESHOLD: float = 0.05

@export_range(1.0, 8.0, 0.1) var move_speed: float = 4.0

## 이동 방향의 기준이 되는 카메라. 비워 두면 뷰포트의 활성 카메라를 쓴다.
@export var camera_path: NodePath

## 이동 잠금을 물어볼 상태 머신(설계 §4-1). 비워 두면 잠기지 않는다 —
## 컨트롤러가 없는 씬(TownSquare 등)에서도 플레이어만 떼어 쓸 수 있어야 한다.
##
## **플레이어는 잠금 사유를 알지 않는다.** 대화·메뉴·컷신 등 사유가 늘어날 때
## 여기를 고치지 않기 위해서다. 해제를 한 곳이라도 빠뜨리면 영원히 못 움직이는 버그가 된다.
@export var controller_path: NodePath

@onready var sprite: Sprite3D = $Sprite3D

@onready var _controller: InteractionController = get_node_or_null(controller_path) as InteractionController

## 프로젝트 기본 중력. 지금 필드는 평지지만, 계단·단차가 생기면 그대로 동작해야 한다.
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))

var _camera: Camera3D = null

## 걷기 순환 위치. 정수 카운터로 두면 프레임률에 따라 애니메이션 속도가 달라진다.
var _walk_phase: float = 0.0
var _facing_row: int = ROW_SOUTH


func _ready() -> void:
	_resolve_camera()
	_apply_frame(IDLE_COLUMN)


func _physics_process(delta: float) -> void:
	var direction := Vector3.ZERO
	# 매 프레임 상태 머신에 물어본다. 잠금 상태를 여기 복사해 두면
	# 해제 시그널을 한 번 놓쳤을 때 영영 못 움직인다.
	if not _is_movement_locked():
		direction = _input_direction()

	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta

	move_and_slide()
	_update_animation(direction, delta)


func _is_movement_locked() -> bool:
	if _controller == null:
		return false
	return _controller.is_movement_locked()


## 카메라 Y 회전을 반영한 월드 이동 방향(길이 0~1)을 낸다.
func _input_direction() -> Vector3:
	# get_vector는 결과 길이를 1로 제한한다. move_left/right를 따로 분기하면
	# 대각선에서 속도가 √2배가 되는 고전 버그가 생긴다.
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input == Vector2.ZERO:
		return Vector3.ZERO

	# 화면 위 = 월드 −Z. 카메라가 Y축으로 돌면 그만큼 입력도 돌려야
	# "위쪽 키를 눌렀는데 비스듬히 간다"가 생기지 않는다.
	var yaw := 0.0
	var cam := _resolve_camera()
	if cam != null:
		yaw = cam.global_rotation.y

	return Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, yaw)


func _update_animation(direction: Vector3, delta: float) -> void:
	if direction == Vector3.ZERO:
		_walk_phase = 0.0
		_apply_frame(IDLE_COLUMN)
		return

	_facing_row = _row_for(direction)

	# 입력이 아니라 실제로 움직인 거리로 순환시킨다.
	# 벽에 막혀 제자리일 때 발만 움직이면 미끄러지는 것처럼 보인다.
	var moved := Vector2(velocity.x, velocity.z).length() * delta
	_walk_phase = fposmod(
		_walk_phase + moved * WALK_FRAMES_PER_METER,
		float(WALK_CYCLE.size())
	)
	_apply_frame(WALK_CYCLE[int(_walk_phase)])


func _row_for(direction: Vector3) -> int:
	if absf(direction.x) > SIDE_VIEW_THRESHOLD:
		return ROW_EAST if direction.x > 0.0 else ROW_WEST
	return ROW_SOUTH if direction.z > 0.0 else ROW_NORTH


func _apply_frame(column: int) -> void:
	sprite.frame = _facing_row * COLUMNS + column


## 카메라를 한 번만 찾아 캐시한다.
## _ready 시점에 활성 카메라가 아직 없을 수 있어(씬 구성 순서) 실패하면 다음 프레임에 다시 시도한다.
func _resolve_camera() -> Camera3D:
	if _camera != null and is_instance_valid(_camera):
		return _camera

	if not camera_path.is_empty():
		_camera = get_node_or_null(camera_path) as Camera3D
	if _camera == null:
		_camera = get_viewport().get_camera_3d()
	return _camera

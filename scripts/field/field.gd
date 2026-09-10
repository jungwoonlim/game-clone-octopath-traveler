extends Node3D
## 필드 씬 루트. 낮/밤 전환에 따라 조명·환경·등불을 함께 보간한다.
##
## 조명만 바꾸고 나머지를 두면 그림자 속이 낮처럼 밝거나, 원경 안개 색이 하늘과 어긋나
## 즉시 어색해진다. 그래서 태양·앰비언트·안개·배경색·글로우·등불을 한 Tween에 묶는다.

## 낮/밤 각각의 환경 값 묶음. 값이 흩어져 있으면 한쪽만 고치는 실수가 나온다.
class PhaseLook:
	var light_color: Color
	var light_energy: float
	var sun_pitch: float
	var ambient_color: Color
	var ambient_energy: float
	var glow_intensity: float
	var bg_color: Color
	var fog_color: Color
	var fog_density: float
	var lantern_energy: float

	func _init(
		p_light_color: Color, p_light_energy: float, p_sun_pitch: float,
		p_ambient_color: Color, p_ambient_energy: float, p_glow: float,
		p_bg: Color, p_fog_color: Color, p_fog_density: float, p_lantern: float
	) -> void:
		light_color = p_light_color
		light_energy = p_light_energy
		sun_pitch = p_sun_pitch
		ambient_color = p_ambient_color
		ambient_energy = p_ambient_energy
		glow_intensity = p_glow
		bg_color = p_bg
		fog_color = p_fog_color
		fog_density = p_fog_density
		lantern_energy = p_lantern


@onready var sun: DirectionalLight3D = $Sun
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var lantern_lights: Array = [
	$Lanterns/LanternA/LightA,
	$Lanterns/LanternB/LightB,
]

var _day: PhaseLook
var _night: PhaseLook
var _tween: Tween = null


func _ready() -> void:
	_day = PhaseLook.new(
		Color(1.0, 0.95, 0.85), 1.25, -40.0,
		Color(0.5, 0.55, 0.6), 0.6, 0.85,
		Color(0.62, 0.73, 0.85), Color(0.68, 0.76, 0.86), 0.006, 0.0
	)
	# 밤에는 글로우를 올린다 — 등불이 번져야 분위기가 산다.
	# 안개도 짙게 해서 원경을 어둠에 묻는다.
	_night = PhaseLook.new(
		Color(0.55, 0.62, 0.95), 0.35, -20.0,
		Color(0.15, 0.18, 0.35), 0.3, 1.15,
		Color(0.07, 0.09, 0.18), Color(0.14, 0.18, 0.32), 0.013, 3.0
	)

	DayNight.phase_changed.connect(_on_phase_changed)
	# 씬 진입 시점의 상태를 보간 없이 즉시 반영한다.
	_apply_phase(DayNight.is_night, false)


func _unhandled_input(event: InputEvent) -> void:
	# 개발 편의용 낮/밤 토글. M1에서 정식 입력 맵으로 옮긴다.
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_N:
			DayNight.toggle()


func _on_phase_changed(is_night: bool) -> void:
	_apply_phase(is_night, true)


func _apply_phase(is_night: bool, animated: bool) -> void:
	var look: PhaseLook = _night if is_night else _day
	var env: Environment = world_environment.environment

	if not animated:
		sun.light_color = look.light_color
		sun.light_energy = look.light_energy
		sun.rotation_degrees.x = look.sun_pitch
		env.ambient_light_color = look.ambient_color
		env.ambient_light_energy = look.ambient_energy
		env.glow_intensity = look.glow_intensity
		env.background_color = look.bg_color
		env.fog_light_color = look.fog_color
		env.fog_density = look.fog_density
		for light in lantern_lights:
			(light as OmniLight3D).light_energy = look.lantern_energy
		return

	# 이전 전환이 진행 중이면 중단한다. 겹치면 값이 튄다.
	if _tween != null and _tween.is_valid():
		_tween.kill()

	var sec := DayNight.TRANSITION_SEC
	_tween = create_tween().set_parallel()
	_tween.tween_property(sun, "light_color", look.light_color, sec)
	_tween.tween_property(sun, "light_energy", look.light_energy, sec)
	_tween.tween_property(sun, "rotation_degrees:x", look.sun_pitch, sec)
	_tween.tween_property(env, "ambient_light_color", look.ambient_color, sec)
	_tween.tween_property(env, "ambient_light_energy", look.ambient_energy, sec)
	_tween.tween_property(env, "glow_intensity", look.glow_intensity, sec)
	_tween.tween_property(env, "background_color", look.bg_color, sec)
	_tween.tween_property(env, "fog_light_color", look.fog_color, sec)
	_tween.tween_property(env, "fog_density", look.fog_density, sec)
	for light in lantern_lights:
		_tween.tween_property(light, "light_energy", look.lantern_energy, sec)

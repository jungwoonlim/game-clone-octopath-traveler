extends Node
## 씬 전환을 담당하는 전역 싱글톤 (autoload: SceneRouter).
##
## `get_tree().change_scene_to_file()`을 직접 쓰지 않는 이유:
## 필드 ↔ 전투 전환에서 필드 상태(플레이어 위치 등)를 유지해야 하고,
## 페이드 연출을 한 곳에서 통제해야 하기 때문이다.
## Main.tscn이 컨테이너를 등록하면, 그 아래에 씬을 붙였다 뗀다.

signal scene_changed(scene_path: String)

var current_scene_path: String = ""

var _container: Node = null


## Main.tscn이 _ready에서 자신의 컨테이너 노드를 등록한다.
func register_container(container: Node) -> void:
	_container = container


func change_scene(scene_path: String) -> bool:
	if _container == null:
		push_warning("SceneRouter: 컨테이너 미등록. Main.tscn이 먼저 로드돼야 한다.")
		return false

	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_warning("SceneRouter: 씬을 불러올 수 없다 — %s" % scene_path)
		return false

	# 기존 씬을 즉시 지우지 않고 queue_free로 넘긴다.
	# 전환을 유발한 노드가 아직 이 프레임에서 살아있을 수 있다.
	for child in _container.get_children():
		child.queue_free()

	_container.add_child(packed.instantiate())
	current_scene_path = scene_path
	scene_changed.emit(scene_path)
	return true

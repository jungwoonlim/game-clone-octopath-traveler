extends Node
## 게임 진입점. 씬 컨테이너를 SceneRouter에 등록하고 첫 씬을 띄운다.

const FIRST_SCENE: String = "res://scenes/field/Field.tscn"

@onready var scene_container: Node = $SceneContainer


func _ready() -> void:
	SceneRouter.register_container(scene_container)
	SceneRouter.change_scene(FIRST_SCENE)

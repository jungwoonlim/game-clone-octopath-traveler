class_name FieldNpc
extends StaticBody3D
## 필드에 서 있는 NPC 한 명. **누구인가는 전부 `npc_data`(.tres)에서 온다.**
##
## 씬은 "어디에 서 있는가"만 담고 이름·텍스처·대사·패스 액션은 리소스가 갖는다.
## 그래서 NPC를 늘릴 때 `.tres` 하나를 만들고 이 씬을 인스턴스해 `npc_data`만 꽂으면 끝난다.
## 스프라이트를 씬에 직접 박으면 텍스처와 데이터가 따로 놀다가 조용히 어긋난다
## (실제로 M1 이전 배치에서 NpcB 노드가 리네 데이터와 짝지어질 뻔했다).

## 걷기 시트의 정면(남쪽) 대기 프레임. `char_*_sheet.png`는 4열 × 4행이고 0행이 남쪽이다
## (`field_player.gd`의 배치와 같은 규칙). M1의 NPC는 서 있기만 하므로 이 한 칸만 쓴다.
const IDLE_FRAME: int = 0

@export var npc_data: NpcData = null

@onready var sprite: Sprite3D = $Sprite3D
@onready var marker: Sprite3D = $Marker


func _ready() -> void:
	# 상호작용 후보를 찾는 쪽이 씬 경로가 아니라 그룹으로 NPC를 모을 수 있게 한다.
	add_to_group(&"field_npc")

	if npc_data != null and npc_data.sprite != null:
		sprite.texture = npc_data.sprite
	sprite.frame = IDLE_FRAME
	marker.visible = false


## 대화창 이름표에 쓸 이름. 데이터가 없으면 노드 이름으로 대신해 화면이 비지 않게 한다.
func display_name() -> String:
	if npc_data != null and not npc_data.display_name.is_empty():
		return npc_data.display_name
	return String(name)


## 지금 말을 걸 수 있는 상대인지 표시한다. 여러 명이 반경 안에 있어도 한 명만 켜진다
## (누구에게 말이 걸릴지 모르는 상태가 가장 답답하다).
func set_highlighted(on: bool) -> void:
	marker.visible = on

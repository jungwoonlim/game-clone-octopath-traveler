---
name: tscn-authoring
description: "Godot 에디터 없이 .tscn 씬 파일과 .tres 리소스 파일을 텍스트로 직접 작성하는 규칙. 노드 트리 표기, ext_resource/sub_resource id, load_steps, parent 경로, 시그널 연결, enum 정수값, 씬 인스턴싱을 다룬다. 씬을 새로 만들거나 노드를 추가/수정할 때, .tres 데이터 파일을 작성할 때 반드시 이 스킬을 읽을 것. '씬 만들어줘', '노드 추가해줘', 'tscn 수정', '씬 구조 바꿔줘' 요청 시 사용."
---

# .tscn / .tres 직접 작성

Godot의 씬과 리소스는 텍스트 포맷이므로 에디터 없이 작성할 수 있다.
다만 **문법이 하나만 틀려도 씬 전체가 로드에 실패하고**, 에디터가 없으면 어디가 틀렸는지 알기 어렵다.
아래 규칙은 그 실패를 막기 위한 것이다.

## 기본 구조

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/field/field_player.gd" id="1_player"]
[ext_resource type="PackedScene" path="res://scenes/field/FieldNpc.tscn" id="2_npc"]

[sub_resource type="BoxShape3D" id="BoxShape3D_body"]
size = Vector3(0.6, 1.6, 0.6)

[node name="FieldPlayer" type="CharacterBody3D"]
script = ExtResource("1_player")

[node name="Sprite3D" type="Sprite3D" parent="."]
billboard = 2
texture_filter = 0
alpha_cut = 1

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
shape = SubResource("BoxShape3D_body")

[node name="Interact" type="Area3D" parent="Sprite3D"]

[node name="Npc1" parent="." instance=ExtResource("2_npc")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 3, 0, 0)

[connection signal="body_entered" from="Sprite3D/Interact" to="." method="_on_interact_entered"]
```

## 규칙

### load_steps

`ext_resource` 개수 + `sub_resource` 개수 + 1. 위 예시는 2 + 1 + 1 = 4가 정확하다(예시는 3으로 적혀 있으니
실제 작성 시 세어서 맞춘다). Godot은 이 값을 로딩 진행률 힌트로 쓰므로 조금 틀려도 대개 로드는 되지만,
정확히 맞추는 습관을 들이면 리소스를 추가하고 빠뜨리는 실수를 스스로 잡게 된다.

### id는 유일해야 한다

`ext_resource`의 `id`가 중복되면 `Busy ext_resource id` 에러로 씬이 통째로 실패한다.
읽기 쉽게 `{번호}_{용도}` 형태로 짓는다: `1_player`, `2_npc`.
`sub_resource`의 id는 `{타입}_{용도}` 형태: `BoxShape3D_body`.

### parent 경로

- 루트 노드에는 `parent`를 **쓰지 않는다** (씬당 루트는 하나).
- 루트의 직계 자식: `parent="."`
- 더 깊은 곳: `parent="Sprite3D"`, `parent="Sprite3D/Interact"` — **노드 이름을 슬래시로 잇는다** (타입이 아니라 이름).
- 부모는 반드시 **자기보다 위 줄에 이미 선언**돼 있어야 한다. 순서가 뒤집히면 로드에 실패한다.

### 씬 인스턴싱

다른 씬을 넣을 때는 `type` 대신 `instance`를 쓴다.

```
[node name="Npc1" parent="." instance=ExtResource("2_npc")]
```

`type=`과 `instance=`를 함께 쓰지 않는다.

### uid

`uid="uid://..."`는 선택이다. 생략하면 Godot이 임포트할 때 만들어준다.
**임의로 지어내지 말 것** — 충돌하면 엉뚱한 리소스를 참조하게 된다. 모르면 그냥 빼고 `path=`만 쓴다.

## enum은 정수로 쓴다

`.tscn`에는 상수 이름을 쓸 수 없다. 아래는 이 프로젝트에서 실제로 확인한 값이다.

| 프로퍼티 | 값 |
|---------|-----|
| `Sprite3D.billboard` | 0=끔, 1=완전빌보드, **2=Y축고정** |
| `Sprite3D.alpha_cut` | 0=끔, **1=DISCARD**, 2=OPAQUE_PREPASS, 3=HASH |
| `Sprite3D.texture_filter` | **0=NEAREST**, 1=LINEAR, 2=NEAREST+밉맵 (기본 3=LINEAR+밉맵) |
| `Environment.background_mode` | 0=CLEAR_COLOR, 1=COLOR, 2=SKY |
| `Camera3D.projection` | 0=원근, 1=직교 |

확실하지 않은 enum은 지어내지 말고 헤드리스로 직접 확인한다:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script /tmp/check.gd
# extends SceneTree
# func _init(): print(BaseMaterial3D.BILLBOARD_FIXED_Y); quit()
```

## 자주 쓰는 값 표기

```
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, x, y, z)   # 기저 3x3 + 위치
position = Vector3(0, 1, 0)
rotation_degrees = Vector3(-45, 0, 0)
color = Color(1, 0.9, 0.7, 1)
size = Vector2(320, 96)
script = ExtResource("1_player")
shape = SubResource("BoxShape3D_body")
```

`Transform3D`는 회전이 섞이면 손으로 쓰기 어렵다. **회전이 필요하면 `transform` 대신
`position` + `rotation_degrees`로 나눠 쓰는 편이 안전하고 읽기도 쉽다.**

## 시그널 연결

```
[connection signal="body_entered" from="Sprite3D/Interact" to="." method="_on_interact_entered"]
```

`from`/`to`는 노드 경로, `method`는 대상 스크립트에 **실제로 존재해야** 한다.
없는 메서드를 적으면 런타임에 조용히 실패하거나 에러가 난다.

이 프로젝트는 가능하면 `.tscn`의 `[connection]`보다 **코드에서 `.connect()`** 를 쓴다 —
텍스트로 씬을 다루는 환경에서는 연결이 코드에 있어야 추적하기 쉽다.

## .tres 리소스 파일

```
[gd_resource type="Resource" script_class="SkillData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/data/skill_data.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
display_name = "화염참"
element = "불"
bp_cost = 1
power = 120
```

**가장 위험한 함정:** 필드 이름이 스크립트의 `@export` 변수명과 다르면
**에러 없이 조용히 기본값으로 로드된다.** 밸런스가 안 맞는데 원인을 못 찾는 상황이 여기서 나온다.
스키마(`.gd`)를 바꿨으면 그 스키마를 쓰는 모든 `.tres`를 Grep으로 찾아 함께 고친다.

## 작성 후 반드시 검증

```bash
bash .claude/skills/godot-run/scripts/godot.sh smoke
```

씬 하나를 쓰면 바로 확인한다. 여러 개를 몰아서 쓰면 어느 파일이 원인인지 좁히기 어렵다.

## 실패 진단

| 에러 | 원인 |
|------|------|
| `Busy ext_resource id` | id 중복 |
| `Parse Error ... expected` | 대괄호/따옴표 누락, 값 표기 오류 |
| `Can't create sub resource` | `sub_resource` type 오타 |
| 노드가 트리에 없음 | `parent=` 경로 오타, 또는 부모가 아래 줄에 선언됨 |
| `Cannot open file res://...` | `path=` 오타, 또는 `import` 미실행 |

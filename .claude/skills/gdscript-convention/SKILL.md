---
name: gdscript-convention
description: "이 프로젝트의 GDScript 코딩 컨벤션. 정적 타이핑, 네이밍(파일 kebab-case 예외 규칙 포함), 한글 주석, class_name 사용 기준, 시그널·export·autoload 작성 규칙을 정의한다. GDScript 파일(.gd)을 새로 작성하거나 수정하기 전에 반드시 읽을 것. '코드 스타일', '컨벤션', '네이밍 규칙', 'GDScript 작성' 관련 요청과 코드 리뷰 시에도 사용."
---

# GDScript 컨벤션

이 프로젝트는 **GDScript 전용**이다. 설치된 Godot이 official(non-mono) 빌드라 C#은 사용할 수 없다.

## 정적 타이핑을 항상 쓴다

```gdscript
# 좋음
var hp: int = 100
var target: CharacterBody3D = null
func take_damage(amount: int, element: String) -> int:

# 나쁨
var hp = 100
func take_damage(amount, element):
```

**왜:** 이 프로젝트는 에디터 없이 CLI로 개발한다. 에디터의 실시간 오류 표시가 없으므로,
`--check-only`가 잡아주는 정적 타입 검사가 사실상 유일한 안전망이다. 타입을 생략하면 그 안전망이 사라진다.

추론이 확실한 경우 `:=`를 쓴다: `var pos := Vector3.ZERO`.
반환값이 없으면 `-> void`를 명시한다 — 생략하면 검사기가 아무것도 확인하지 못한다.

## 네이밍

| 대상 | 규칙 | 예 |
|------|------|-----|
| 파일 (`.gd`) | snake_case | `field_player.gd`, `day_night.gd` |
| 파일 (`.tscn`) | PascalCase | `FieldPlayer.tscn`, `DialogueBox.tscn` |
| 클래스 (`class_name`) | PascalCase | `class_name SkillData` |
| 함수·변수 | snake_case | `func take_damage()`, `var shield_point: int` |
| 상수 | SCREAMING_SNAKE | `const MAX_BP: int = 5` |
| 시그널 | 과거형 snake_case | `signal shield_broken(target)` |
| private | 밑줄 접두 | `func _apply_boost()`, `var _cached_path: NodePath` |
| 노드 (`.tscn` 내) | PascalCase | `FieldCamera`, `DialogueLabel` |

**파일명이 사용자 전역 규칙(kebab-case)과 다른 이유:** GDScript는 `class_name`을 파일 경로에서
유추하고, Godot 생태계 전체가 snake_case `.gd` / PascalCase `.tscn`을 쓴다. 여기서만 kebab-case를
쓰면 엔진 관례와 충돌해 오히려 혼란을 만든다. 이 예외는 의도된 것이다.

## 주석은 한글로

무엇을 하는지가 아니라 **왜 그렇게 했는지**를 적는다.

```gdscript
# 나쁨 — 코드를 읽으면 아는 내용
# hp를 감소시킨다
hp -= amount

# 좋음 — 왜 이 값인지
# 브레이크 중에는 피해를 1.5배로 받는다. 브레이크의 통쾌함이 이 게임의 핵심이라
# 수치를 크게 잡았다 (원작보다 높음).
var multiplier := 1.5 if is_broken else 1.0
```

## `class_name`은 재사용될 때만 선언한다

```gdscript
# 좋음 — 다른 곳에서 타입으로 참조된다
class_name SkillData
extends Resource
```

노드에 붙는 일회성 스크립트에는 붙이지 않는다. `class_name`은 전역 이름공간을 차지하므로,
남발하면 이름 충돌이 나고 import 캐시가 낡았을 때 `Identifier not found`의 원인이 된다.

## `@export`에는 범위를 준다

```gdscript
@export_range(1, 5) var max_bp: int = 5
@export_range(0.0, 2.0, 0.1) var move_speed: float = 4.0
@export var skill_data: SkillData          # Resource 타입 명시
@export_enum("불", "얼음", "번개") var element: String
```

**왜:** 밸런싱은 에디터에서 값을 만지며 하게 된다. 범위가 없으면 실수로 음수를 넣어도 막히지 않는다.

## 노드 참조

```gdscript
@onready var sprite: Sprite3D = $Sprite3D
@onready var anim: AnimationPlayer = $AnimationPlayer
```

`.tscn`의 노드 이름과 **정확히** 일치해야 한다. 노드 이름을 바꾸면 참조하는 모든 스크립트를 함께 고친다.
이 불일치가 이 프로젝트에서 가장 흔한 런타임 에러다 (`null instance` 에러의 대부분).

`_ready()` 이전에는 `@onready` 변수가 아직 null이다 — `_init()`에서 쓰지 않는다.

## 시그널

```gdscript
signal shield_broken(target: BattleUnit)   # 인자에도 타입을 준다

# 연결은 코드로. .tscn의 [connection]보다 추적하기 쉽다.
func _ready() -> void:
	shield_broken.connect(_on_shield_broken)

func _on_shield_broken(target: BattleUnit) -> void:
	pass
```

핸들러는 `_on_{시그널명}` 형태로 이름을 맞춘다.

## autoload 싱글톤

`project.godot`의 `[autoload]`에 등록하고, 코드에서는 등록명으로 바로 부른다.

```gdscript
DayNight.toggle()
GameState.add_gold(100)
```

등록명은 **PascalCase**로 하고 파일명(snake_case)과 헷갈리지 않게 한다.
대소문자가 하나만 달라도 `Identifier not found`가 난다.

autoload는 꼭 필요한 전역 상태에만 쓴다. 지금 이 프로젝트는 세 개(`GameState`, `SceneRouter`, `DayNight`)로
충분하며, 늘리기 전에 정말 전역이어야 하는지 먼저 따진다.

## 피할 것

- **매직 넘버** — 상수나 `.tres` 데이터로 뺀다. 밸런스 수치가 코드에 박히면 조정할 때마다 코드를 열게 된다.
- **`get_node()` 문자열 반복** — `@onready`로 한 번만 캐시한다.
- **`_process`에서 무거운 작업** — 매 프레임 도는 함수다. 필요할 때만 계산한다.
- **`Object.free()` 직접 호출** — 노드는 `queue_free()`를 쓴다.
- **데이터를 코드에 하드코딩** — 스탯·대사·밸런스는 `.tres`에 둔다.

## 작성 후

`bash .claude/skills/godot-run/scripts/godot.sh check` 로 파싱·타입 검사를 돌린다.
에디터가 없으므로 이 단계를 건너뛰면 오류가 런타임까지 살아남는다.

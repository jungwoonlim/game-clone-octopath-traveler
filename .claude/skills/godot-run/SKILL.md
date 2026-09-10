---
name: godot-run
description: "Godot 프로젝트를 에디터 없이 CLI로 실행·검증한다. GDScript 파싱/타입 검사, 씬 로드 확인, 런타임 스모크, 헤드리스 동작 테스트, 창 모드 실행과 스크린샷을 수행. '검증해줘', '테스트 돌려줘', '에러 없는지 확인', '빌드 확인', '실행해봐', '제대로 도는지 봐줘', '게임 띄워줘', '스크린샷 찍어줘' 요청 시 반드시 이 스킬을 사용할 것. 씬이나 스크립트를 수정한 직후에도 사용. 재검증, 다시 확인, 검증 결과 갱신 요청에도 사용."
---

# Godot Run — CLI 실행·검증

이 프로젝트는 **Godot 에디터를 열지 않고 개발한다.** 씬은 텍스트(`.tscn`)로 작성하고, 검증은 CLI로 한다.
그래서 "실행해서 확인한다"는 절차가 다른 프로젝트보다 훨씬 중요하다 — 눈으로 볼 수 없으니 실행이 유일한 근거다.

## 사용법

번들 스크립트를 쓴다. 매번 Godot 명령을 새로 짜지 말 것 — 아래의 로그 노이즈 문제 때문이다.

```bash
bash .claude/skills/godot-run/scripts/godot.sh all      # 임포트 → 파싱 → 스모크 → 테스트
bash .claude/skills/godot-run/scripts/godot.sh check    # GDScript 파싱·타입 검사만
bash .claude/skills/godot-run/scripts/godot.sh smoke    # 씬 로드 + _ready 실행
bash .claude/skills/godot-run/scripts/godot.sh test     # tests/headless_*.gd
bash .claude/skills/godot-run/scripts/godot.sh shot out.png true  # 밤 화면 캡처
bash .claude/skills/godot-run/scripts/godot.sh bench [true]       # 성능 측정 (밤이면 true)
bash .claude/skills/godot-run/scripts/godot.sh run 15   # 창 모드 15초 (비주얼 확인)

# 조작한 뒤의 화면을 찍는다 (인자 순서: 출력, 밤, 입력 타임라인, 씬)
bash .claude/skills/godot-run/scripts/godot.sh shot out.png false "hold:move_right:40;press:interact"
```

`bash`를 붙여 호출한다 — 실행 권한(`chmod +x`)에 의존하지 않으므로 저장소를 새로 클론해도 그대로 동작한다.

종료 코드 0이 통과다. 특정 파일만 검사하려면 `check <파일경로...>`.

## 반드시 알아야 할 것

### 1. 정상 실행에도 ERROR가 찍힌다

Godot은 헤드리스로 정상 종료할 때 엔진 정리 과정에서 이런 걸 출력한다:

```
ERROR: Pages in use exist at exit in PagedAllocator
WARNING: 1 ObjectDB instance was leaked at exit
ERROR: 1 RID allocations of type '...' were leaked at exit
```

**이건 실패가 아니다.** 우리 코드와 무관한 알려진 노이즈다.
raw 로그에서 `ERROR` 문자열만 grep하면 모든 정상 실행이 실패로 잡힌다.
`godot.sh`가 이 패턴을 걸러내므로 스크립트를 거쳐서 판정하라.

### 2. 헤드리스로는 비주얼을 검증할 수 없다

`--headless`는 dummy 렌더러를 쓴다. 화면 픽셀이 비어 나오므로 DOF·블룸·조명 같은 룩은
**전혀 확인되지 않는다.** 헤드리스 통과 = 로직이 돈다는 뜻일 뿐이다.

비주얼 확인은 `godot.sh run`으로 창을 띄우거나, 게임 안에서 직접 저장한다:

```gdscript
# 인게임 스크린샷 — 렌더 완료 후여야 하므로 프레임 종료를 기다린다
await RenderingServer.frame_post_draw
var img := get_viewport().get_texture().get_image()
img.save_png("user://shot.png")
```

검증 리포트에 비주얼을 "통과"로 적지 말 것. "미검증 — 사용자 눈 확인 필요"로 적는다.

### 3. 조작해야 보이는 화면은 입력 타임라인으로 찍는다

가만히 서 있는 화면만 찍을 수 있으면 **이동·대화창·메뉴는 영영 검증되지 않는다.**
`shot`의 세 번째 인자에 타임라인을 준다.

| 단계 | 뜻 |
|------|-----|
| `wait:<프레임>` | 그냥 기다린다 |
| `hold:<액션>:<프레임>` | 누른 채 기다렸다 뗀다 (이동) |
| `press:<액션>` | 한 번 눌렀다 뗀다 (상호작용·메뉴 확정) |
| `night` | 타임라인 중간에 밤으로 전환 |

```bash
godot.sh shot _screenshots/talk.png false "hold:move_left:35;press:interact;wait:30"
```

**구도를 확인할 때는 프레임 수가 아니라 좌표로 지정한다** — 네 번째 인자 `pose`:

```bash
godot.sh shot _screenshots/west.png false "" "-9.7,0.6"    # 플레이어를 그 좌표에 세우고 찍는다
```

`hold:<액션>:<프레임>`으로는 "끝까지 걸어간 화면"을 **재현할 수 없다.** 창 모드 fps가
상황에 따라 크게 흔들려(macOS App Nap 등) 같은 프레임 수가 매번 다른 이동량이 된다.
실제로 `hold:move_left:90`으로 찍은 화면이 플레이어가 화면 중앙에 있는 상태였는데
그걸 "서쪽 끝"으로 오독할 뻔했다. 게다가 한 실행이 20분 넘게 걸린 적도 있다.

`pose`는 카메라를 `field_camera.gd`와 **같은 규칙**(오프셋 + 클램프)으로 즉시 계산해 붙인다.
보간이 끝나기를 기다리면 "몇 프레임 뒤에 도착하는가"가 다시 fps에 의존하게 된다.
`pose`와 `actions`는 함께 쓸 수 있다 — 먼저 세우고 그 자리에서 조작한다.

**`press`는 폴링과 이벤트를 둘 다 만든다.** `Input.action_press()`는 폴링 상태만 바꾸고
이벤트를 트리에 흘리지 않아서, `_unhandled_input`으로 받는 상호작용·메뉴가 반응하지 않는다.
그래서 `Input.parse_input_event(InputEventAction)`을 함께 쏜다.

**InputMap에 없는 액션 이름을 주면 실패로 끊는다.** 조용히 무시하면 아무 일도 안 일어난 화면이
"정상 캡처"로 넘어가고, 그걸 보고 "기능이 안 된다"고 오판하게 된다.

### 4. FPS는 씬 진입 직후에 재면 안 된다

Godot은 씬 진입 직후 셰이더를 컴파일하고 리소스를 업로드하느라 매우 느리다.
이때 잰 값은 실제 성능과 무관하다 — **74fps로 도는 씬이 13fps로 찍힌 적이 있고,
스프라이트를 300개 제거했더니 오히려 더 낮게 나오기도 했다.**

성능은 `godot.sh bench`로만 판단한다. 워밍업 180프레임 뒤 120프레임을 재고 평균과 최저를 함께 낸다.
최저값이 평균보다 크게 낮으면 특정 프레임에 튀는 것이므로 원인을 따로 찾는다.

참고로 이 프로젝트의 마을 씬(스프라이트 300여 개, 광원 11개, DOF·블룸·안개)은
M3 Mac에서 밤 74fps / 낮 59fps다. 광원을 10개 늘려도 3fps 정도만 줄었다 —
**광원 개수는 보통 병목이 아니다.**

### 5. 텍스처를 고쳤으면 반드시 import 한다

`.godot/` 캐시가 없으면 리소스가 로드되지 않는다. 저장소를 새로 클론했거나 애셋을 추가했으면
`godot.sh import`를 먼저 돌린다. `all`에는 포함돼 있다.

**파일을 추가할 때뿐 아니라 기존 텍스처의 내용을 바꿨을 때도 마찬가지다.**
`gen_placeholder_textures.gd`로 텍스처를 재생성한 뒤 곧바로 `shot`을 찍으면
**바뀌기 전 이미지가 그대로 나온다** — 실제로 이 때문에 "수정이 반영되지 않았다"고 오판한 적이 있다.
텍스처 생성 → `import` → `shot` 순서를 지킨다.

### 6. `--check-only`는 autoload를 모른다 (오탐)

`--check-only --script`는 개별 스크립트만 컴파일하므로 `project.godot`의 autoload를 알지 못한다.
그래서 정상 코드인 `DayNight.toggle()`이 이렇게 잡힌다:

```
SCRIPT ERROR: Compile Error: Identifier not found: DayNight
```

**이건 오탐이다.** 런타임에는 존재하며 스모크는 통과한다.
`godot.sh`가 `project.godot`의 `[autoload]` 섹션을 읽어 등록된 이름에 대한 미발견 에러만 걸러낸다.

검사 구멍이 생기지 않는 이유: 오타 난 식별자는 메시지 형태가 다르다
(`Identifier "DayNite" not declared in the current scope`) — 실제로 확인했다.
타입 에러도 그대로 잡힌다.

**autoload를 추가하면 `project.godot`에 등록만 하면 된다.** 스크립트는 자동으로 따라간다.

### 7. `--check-only`는 종료 코드를 믿을 수 없다

파싱 에러가 있어도 종료 코드가 0으로 나오는 경우가 있다. 그래서 `godot.sh`는 **stderr 문자열**로
판정한다. 직접 명령을 쓸 일이 있어도 `$?`로 판단하지 말 것.

## 동작 테스트 작성 규칙

`tests/headless_*.gd`에 둔다. `SceneTree`를 상속하고, 결과를 약속된 문자열로 출력한다 —
`godot.sh test`가 이 문자열로 판정한다.

```gdscript
extends SceneTree

func _init() -> void:
	_assert_eq(DayNight.is_night, false, "초기 상태는 낮")
	DayNight.toggle()
	_assert_eq(DayNight.is_night, true, "토글 후 밤")
	quit()

# 통과는 TEST PASS, 실패는 TEST FAIL로 출력한다 (godot.sh가 이 문자열을 본다)
func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		print("TEST PASS: ", label)
	else:
		printerr("TEST FAIL: ", label, " — 기대 ", expected, ", 실제 ", actual)
```

**왜 이 형식인가:** Godot에는 표준 테스트 러너가 없다. 종료 코드도 신뢰할 수 없으므로,
출력 문자열을 계약으로 삼는 것이 가장 견고하다.

autoload를 테스트하려면 `--script`가 아니라 씬을 띄워야 하는 경우가 있다.
autoload는 `SceneTree` 스크립트 실행 시에도 초기화되지만, 노드 트리에 의존하는 로직은
전용 테스트 씬을 만들어 `smoke`로 확인하는 편이 확실하다.

## 검증 순서

의존 순서대로 해야 원인을 좁힐 수 있다. 앞 단계가 실패하면 뒤 단계는 결과가 무의미하다.

```
import → check(파싱) → smoke(로드·_ready) → test(규칙) → run(비주얼, 사람 확인)
   └ 캐시      └ 문법·타입      └ 씬 구조·노드 경로    └ 게임 로직    └ 룩
```

## 실패했을 때 보는 순서

| 증상 | 먼저 확인할 것 |
|------|--------------|
| `Parse Error` in `.tscn` | `load_steps` 개수, `ext_resource` id 중복, `parent=` 경로 |
| `Cannot open file res://...` | 파일 경로 오타, import 미실행 |
| `Attempt to call ... on a null instance` | `@onready` 노드 경로가 `.tscn`의 실제 이름과 다름 |
| `Identifier not found` | `class_name` 미선언, 또는 import 캐시가 낡음 |
| autoload 관련 에러 | `project.godot`의 `[autoload]` 등록명 대소문자 |

같은 에러를 2회 고쳐도 재발하면 추측을 멈추고 로그 전문과 함께 보고하라.

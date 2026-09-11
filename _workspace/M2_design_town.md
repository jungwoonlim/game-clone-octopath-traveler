# M2 1차 — 집정관 광장 플레이화 · 씬 전환 규약 설계

작성: 2026-09-11 / 담당: game-system-designer
범위: 씬 전환 규약, 구역별 시간대 정책, 광장 NPC·패스 액션, 플레이 영역과 카메라 재계산 절차

이 문서는 **M2 1차의 단일 진실 원천**이다. `_workspace/M1_design_field.md`에서 확정된 규칙은
여기서 뒤집지 않는다. M1을 건드리는 곳은 §6에 영향 범위와 함께 전부 모아 두었다.

> **목표:** `scenes/field/TownSquare.tscn`(도시 밤 광장)을 걸어 다니고 말을 걸 수 있는 씬으로 만들고,
> `Field.tscn`(마을)과 양방향으로 잇는다. 광장은 지금 CSG 89노드짜리 **정지 화면**이고,
> M1의 이동·대화·패스 액션은 전부 `Field.tscn`에만 붙어 있다.

---

## 0. 이번에 추가되는 개념 한 장 요약

| 개념 | 무엇 | 어디 |
|---|---|---|
| **구역(Zone)** | 필드 씬 1개의 규칙 묶음 — 시간대 정책, 기본 스폰, 표시명 | `ZoneData` / `data/zone/*.tres` |
| **게이트(WarpGate)** | 걸어 들어가면 다른 구역으로 넘어가는 경계 트리거 | `scripts/field/warp_gate.gd` (구현자) |
| **스폰 지점(SpawnPoint)** | 어느 입구로 들어왔는지에 따라 플레이어가 서는 자리 | `scripts/field/spawn_point.gd` (구현자) |
| **보류 스폰 id** | 전환 1회 동안만 사는 휘발 상태. 세이브 대상이 아니다 | `SceneRouter._pending_spawn_id` |
| **NOTICE 상태** | 시스템이 한 줄 알리는 상태(시간대 잠금 안내) | `InteractionController.State` 끝에 추가 |

---

## 1. 씬 전환 규약

### 1-1. 결정: 전환 트리거는 **맵 경계의 게이트(Area3D) 통과**다

**왜 문 상호작용이 아닌가.** `interact`는 이미 "가장 가까운 NPC에게 말을 건다"에 묶여 있다
(M1 §2-1). 문을 `interact`로 열면 `handle_interact()`의 `FREE` 분기에 **"NPC 후보 vs 문 후보"
우선순위 규칙**이 새로 필요해진다. 하필 광장은 배경 인파가 16명 서 있고 대화 NPC도 3명이라,
문 앞에 누가 서 있는 상황이 기본값에 가깝다. 플레이어가 문을 누르려다 계속 딴 사람과 대화하는
경험이 나오고, 그 원인을 화면만 봐서는 알 수 없다.

**왜 표지판이 아닌가.** 표지판은 결국 상호작용이므로 위와 같은 문제를 그대로 갖고,
"읽는다"와 "이동한다"가 같은 버튼이 되어 의미가 흐려진다.

**경계 게이트를 고른 세 번째 이유는 검증이다.** 게이트는 플레이어 좌표를 존 안에 놓고
물리 프레임 한 번만 돌리면 발화한다 — **입력 재생 없이 헤드리스로 검증할 수 있다.**
M1 검증에서 "입력 경로(`_unhandled_input`)를 타는 테스트가 하나도 없다"가 이미 지적됐다
(`M1_validation_field.md` §2-3). 새 기능을 또 입력 재생에만 의존하게 만들지 않는다.

**오작동 방지:** 게이트는 벽에 낸 **폭 2.6 m의 틈** 안에만 둔다. 벽을 따라 걷다 실수로
빠져나가는 일이 없도록, 틈 외의 경계는 전부 `Bounds` 충돌체가 막는다.

### 1-2. 노드 규약

**`WarpGate`** (Area3D, `scripts/field/warp_gate.gd`)

| export | 타입 | 의미 |
|---|---|---|
| `target_scene` | `String`(res 경로) | 이동할 씬. `PackedScene`이 아니라 경로로 둔다 — `PackedScene`으로 잡으면 마을과 광장이 서로를 preload해 **순환 참조**가 되고 로드 시간이 두 배가 된다 |
| `target_spawn_id` | `StringName` | 도착 씬에서 설 자리. 관례는 `from_<출발 구역 zone_id>` (§1-3) |

**`SpawnPoint`** (Marker3D, `scripts/field/spawn_point.gd`)

| export | 타입 | 의미 |
|---|---|---|
| `spawn_id` | `StringName` | 이 자리의 id. 구역 안에서 유일해야 한다 |

씬의 `Spawns` 노드 아래에 모아 둔다. 씬 루트(`field.gd`)가 `find_children`으로 찾는다 —
경로를 하드코딩하면 스폰을 하나 옮길 때마다 스크립트를 고치게 된다.

### 1-3. 스폰 id 규약

- **이름:** `from_<출발 구역의 zone_id>` (예: 광장의 `from_village`, 마을의 `from_town_square`).
  게이트가 출발지를 알고 있으므로 이름만 보고 짝을 찾을 수 있고, 오타가 나면 이름이 짝이 안 맞는 것이
  눈에 띈다.
- **기본값:** `default`. 씬을 직접 띄웠을 때(디버그 실행·검증 캡처·`Main.FIRST_SCENE`) 서는 자리.
  **모든 구역은 `default` 스폰을 반드시 하나 갖는다.**
- **데이터 위치:** 기본 스폰의 **id**는 `ZoneData.default_spawn_id`(`data/zone/*.tres`)에,
  **좌표**는 씬의 `SpawnPoint` 노드에 둔다. 좌표를 리소스에 넣지 않는 이유: 좌표는 씬 지형과 한 몸이라
  씬을 고칠 때 같이 고쳐야 하는데, 다른 파일에 있으면 반드시 어긋난다.

**해결 순서 (씬 루트가 `_ready`에서 수행):**

1. `SceneRouter.consume_pending_spawn_id()`로 보류 id를 가져온다 (1회성, §1-4).
2. 그 id의 `SpawnPoint`가 있으면 거기 세운다.
3. 없으면 `zone.default_spawn_id`의 `SpawnPoint`에 세우고 **`push_warning`으로 요청 id를 찍는다.**
   조용히 기본값으로 가면 "왜 반대쪽에서 나오지"가 되고, 원인을 찾는 데 시간이 걸린다.
4. 그것도 없으면 씬에 배치된 플레이어 위치를 그대로 쓰고 다시 경고한다.

**세우는 방법:** `player.global_position.x/z`만 스폰 좌표로 바꾸고 **y는 플레이어의 값을 유지한다.**
지면 높이를 여기서 추측하면 공중이나 바닥 아래에 박힌다(`tools/capture_screenshot.gd`의 `--pose`가
같은 이유로 같은 규칙을 쓴다 — 두 경로의 규칙이 갈라지면 캡처 화면과 실제 플레이 화면이 달라진다).

### 1-4. 결정: 스폰 id는 **`SceneRouter`가 1회용으로 들고, 도착 씬이 가져간다(consume)**

```gdscript
func change_scene(scene_path: String, spawn_id: StringName = &"") -> bool
func consume_pending_spawn_id() -> StringName   # 읽는 즉시 비운다
```

**왜 `GameState`가 아닌가.** `GameState`는 주석에 적힌 대로 **세이브 대상만** 담는다.
"어느 입구로 들어왔는가"는 전환이 끝나는 순간 의미를 잃는 휘발 상태다. 세이브에 들어가면
불러오기 때문에 이상해진다 — 저장은 "광장 한복판에 서 있었다"인데 복원은 "서쪽 문에서 들어온다"가 된다.
세이브가 필요한 것은 **현재 씬 경로 + 실제 좌표**(M4)이지 입구가 아니다.

**왜 함수 인자만으로는 안 되는가.** `_container.add_child(instance)` 시점에 도착 씬의 `_ready`가
즉시 실행되므로, 인자를 새 씬에 전달할 통로가 없다. `instantiate()` 직후 루트에
`set("spawn_id", ...)`로 꽂는 방법도 있지만, 그러면 **`SceneRouter`가 "모든 씬 루트에 spawn_id가 있다"를
가정**하게 된다. 전투 씬(M3)에는 없다. 라우터는 값을 들고만 있고 **필요한 씬이 스스로 가져가는** 쪽이
라우터를 필드 전용으로 만들지 않는다.

**왜 consume(읽으면 비움)인가.** 남겨 두면 다음 전환이 id 없이 일어났을 때 **낡은 값이 재사용된다.**
예: 광장 → 마을(`from_town_square`) 이후 메뉴에서 마을을 다시 로드하면, 비우지 않은 경우
또 동쪽 문에서 나온다. 빈 값이 곧 "기본 스폰"이라는 규칙(§1-3)과 맞물려 안전한 기본 동작이 된다.

### 1-5. 이중 전환·입력 씹힘 방지

동시에 네 겹으로 막는다. 하나만으로는 부족하다 — 각각 막는 사고가 다르다.

| # | 장치 | 막는 사고 |
|---|---|---|
| G1 | `SceneRouter.is_transitioning` 가드. 전환 중 `change_scene()`은 **즉시 false** + `push_warning` | 같은 프레임에 게이트 두 개가 발화 / 게이트와 다른 전환(전투 진입)이 겹침 |
| G2 | `WarpGate._fired` 1회 발화 플래그 + `monitoring = false` | `queue_free` 대기 중인 옛 씬의 게이트가 이 프레임에 신호를 또 보냄 |
| G3 | **무장(arm) 규칙** — 게이트는 `_ready` 시점에 플레이어가 존 안에 있으면 **무장하지 않는다.** `body_exited`로 나가야 무장된다 | 도착 스폰이 반대편 게이트 존 안일 때의 **무한 왕복** |
| G4 | 게이트는 `InteractionController.is_movement_locked()`가 true면 발화하지 않는다(무장은 유지) | 대화·결과 대사 중에 씬이 갈려 대화창과 상태가 새 씬으로 새는 것 |

**G1의 해제 시점이 중요하다.** `call_deferred`는 같은 프레임 안에서 flush될 수 있어 가드 구실을
못 한다. `get_tree().process_frame`에 `CONNECT_ONE_SHOT`으로 붙여 **다음 프레임에** 푼다.
페이드 연출이 들어가도 이 자리만 늘리면 되도록 지금부터 이 구조로 둔다.

**G3를 시간(타이머)이 아니라 겹침 상태로 정한 이유:** 시간 기반이면 fps에 따라 결과가 달라져
헤드리스 검증이 불안정해진다(M1 검증 결함 2와 같은 종류의 함정). 겹침 기반은 결정론적이다.
그래도 스폰 좌표는 **게이트 존 바깥 1.2 m 이상 안쪽**에 두는 것을 규약으로 한다 — G3는 안전망이지
배치 규칙의 대체재가 아니다.

**입력 연속성:** 전환 순간 눌려 있던 `move_*`는 새 씬의 플레이어에게 그대로 이어져 계속 걷는다.
이것은 **의도된 동작**이다(문을 지나 걸어 들어가는 감각). `interact`는 전환 트리거가 아니므로
같은 프레임에 눌려 있을 이유가 없다.

### 1-6. 함정: 카메라가 옛 위치에서 끌려온다

Godot은 **자식의 `_ready`가 부모보다 먼저** 실행된다. 씬 루트(`field.gd`)가 `_ready`에서 플레이어를
스폰으로 옮길 때, `FieldCamera._ready()`는 **이미 씬에 박힌 초기 위치로 스냅을 끝낸 뒤**다.
그대로 두면 전환 직후 카메라가 씬 중앙에서 스폰 쪽으로 미끄러져 들어온다(감쇠 8 → 약 0.5초).

→ `field_camera.gd`에 `snap_to_target()`(= `global_position = _desired_position()`)을 공개하고,
씬 루트가 **스폰을 적용한 직후 반드시 호출한다.** `_ready()`의 기존 스냅도 이 함수를 쓰게 바꿔
계산이 두 벌이 되지 않게 한다.

### 1-7. 페이드는 M2 1차에 넣지 않는다

지금은 한 프레임에 갈리는 하드 컷이다. 넣지 않는 이유는 우선순위이고, **자리는 비워 두었다** —
G1 가드가 이미 "전환은 1프레임 이상 걸리는 일"로 모델링돼 있어서, 페이드를 넣을 때
호출부(게이트)를 고칠 필요가 없다. 호출부는 지금부터 `change_scene()`의 반환값을
"요청이 접수됐는가"로만 쓰고, **전환 완료는 `scene_changed` 시그널로 알아야 한다.**

---

## 2. 집정관 광장의 시간대 정책

### 2-1. 결정: 광장은 **밤 고정**이다. 낮 연출을 만들지 않는다

`TownSquare.tscn`은 밤을 전제로 지어졌다 — 창문 발광 마스크(`facade_emission.png`),
빛무리 스프라이트 10개, 등불 `OmniLight3D` 10개, 푸른 달빛 태양(에너지 0.35), 안개 0.013, 글로우 1.4.
낮을 허용하려면 이 전부에 낮 대응물이 필요하다: 발광 마스크 끄기, 빛무리 숨기기, 군중 조명 재조정,
그림자 켜기, 파사드 반사 재조정. 그것은 M2 1차의 목표(**플레이 가능하게 만들기**)와 무관한 비주얼
작업이고, 어중간하게 만든 낮은 사용자가 "목표 장면"으로 고른 화면의 인상을 깎는다.

**대안 "낮도 허용하되 연출은 밤 그대로"를 버린 이유:** 낮 대사와 낮 패스 액션이 뜨는데 화면은 밤인
상태가 된다. 시간대가 규칙의 일부인 게임에서 화면과 규칙이 어긋나면, 플레이어는 규칙 쪽을 불신한다.

### 2-2. 결정: 씬을 옮겨도 시간대는 **복원하지 않는다**

| 상황 | 결과 |
|---|---|
| 마을(낮) → 광장 | **밤으로 강제된다** |
| 마을(밤) → 광장 | 밤 그대로 (전환 없음 → `DayNight`가 시그널을 쏘지 않는다) |
| 광장(밤) → 마을 | **밤 그대로.** 낮으로 돌아가려면 마을에서 `N`을 누른다 |

**대안 A "광장을 나가면 들어오기 전 시간대로 되돌린다"를 버린 이유:** 휘발 상태가 하나 더 늘고
(입구 id + 진입 전 시간대), 왕복할 때 그 값을 언제 갱신하는지 규칙이 애매해진다
(광장→마을→광장에서 두 번째 진입의 "진입 전 값"은 무엇인가). 그리고 **시간이 거꾸로 흐르는 화면**이
나온다 — 밤 광장에서 나왔는데 마을이 대낮이다. 채택안은 "시간은 한 방향으로만 흐른다"는 한 문장으로
설명되고 상태를 늘리지 않는다.

이 결정의 부작용: 광장에 한 번 다녀오면 마을도 밤이 된다. **마을의 밤 패스 액션(조사·유혹)이
자연스럽게 열리므로** 오히려 M1 데이터와 궁합이 맞는다.

### 2-3. `toggle_phase`를 막는 방법과 피드백

**막는 곳은 `field.gd`가 아니라 `InteractionController`다.** 컨트롤러가 트리에서 아래에 있어
`toggle_phase`를 **먼저 소비하고** `set_input_as_handled()`를 부른다 — 컨트롤러가 있는 씬에서
`field.gd._unhandled_input`은 애초에 도달하지 않는다(M1 검증 §3에서 실측 확인됨).
`field.gd` 쪽만 막으면 **아무 효과가 없는데 코드는 그럴듯해 보이는** 최악의 수정이 된다.

```gdscript
# InteractionController
func handle_toggle_phase() -> void:
    if state != State.FREE:
        return                                  # M1 §2-3 규칙 그대로
    if _zone != null and _zone.is_phase_locked():
        var notice := _zone.resolve_notice()
        if not notice.is_empty():
            show_notice(_zone.display_name, notice)
        return
    day_night.toggle()
```

**피드백:** 대화창에 한 줄을 띄운다. 조용히 씹으면 "키가 고장 났나"로 읽힌다.
- **화자는 구역 이름**(`집정관 광장`)으로 둔다. 이름표를 비우면 빈 패널이 뜨므로 UI를 고쳐야 하는데,
  구역 이름을 쓰면 UI를 손대지 않고도 "장소가 말한다"는 그림이 된다.
- 문구는 코드가 아니라 `ZoneData.phase_locked_notice`에 있다. 현재 값:
  `"{zone}의 등은 밤에만 켠다. 여기서 시간을 돌릴 수는 없다."`
- 상태는 **`State.NOTICE`** (enum **끝에 추가** — M1 §3-6의 이유). 이동 잠금, `interact`/`cancel`로 `FREE`.
  기존 `RESULT`를 재사용하지 않는 이유: `RESULT`에는 "패스 액션 결과"라는 의미가 박혀 있어
  `pass_action_resolved`를 구독하는 연출이 엉뚱한 타이밍에 반응할 여지가 생긴다.

### 2-4. 진입 시 강제 전환의 순서

`field.gd._ready()`에서 **`_apply_phase()`보다 먼저** `DayNight.set_night()`을 부른다.
순서가 뒤바뀌면 잘못된 시간대로 한 프레임이 그려지고, 그 프레임이 하필 캡처에 잡히면
"낮 광장이 찍혔다"는 유령 버그를 쫓게 된다. 기존 `start_at_night` 처리와 같은 자리다(§6-3).

---

## 3. 광장의 NPC와 패스 액션

### 3-1. 대화 가능 NPC를 배경 인파와 구분하는 방법

광장에는 `ScatterProps`가 뿌리는 배경 인파 16명(`char_crowd_00~11.png`)이 있다.
말을 걸 수 있는 사람과 못 거는 사람이 똑같이 생기면 **플레이어는 전부 눌러 보고, 그다음부터
아무에게도 안 건다.** 세 겹으로 구분한다.

| # | 장치 | 사거리 | 담당 |
|---|---|---|---|
| D1 | **발밑 등불 후광** — 대화 NPC에게만 약한 `OmniLight3D`(따뜻한 색, 반경 2~2.5 m). 밤 광장이라 "이 사람 주위만 밝다"가 즉시 읽힌다. 배경 인파는 `shaded = true`라 어둠 속 실루엣으로 남는다 | 화면 전체 | hd2d-visual-tuner |
| D2 | **전용 팔레트 + 걷기 시트** — 대화 NPC는 4열×4행 `char_npc_{d,e,f}_sheet.png`(신규 생성 완료). 인파는 단일 프레임 `char_crowd_*` | 중거리 | 완료(본 작업) |
| D3 | **상호작용 마커** — M1의 `interact_marker.png`. 반경 안에 들어오면 머리 위에 뜬다 | 1.6 m | 완료(M1) |

D1을 1순위로 두는 이유: 유일하게 **멀리서도** 보이고, 밤 광장의 연출과 충돌하지 않고 오히려 보탠다.
`FieldNpc.tscn`에 `AuraLight`(기본 꺼짐)를 두고 인스턴스별 `@export var aura_enabled: bool`로 켠다 —
마을 NPC는 인파가 없어 구분이 필요 없으므로 끈 채로 둔다.

**배치 규칙 D4:** 대화 NPC 반경 1.6 m 안에 배경 인파가 서면 마커가 누구 것인지 모호해진다.
`ScatterProps`에 `npc_blocked_rects: Array[Rect2]`(월드 x,z)를 추가해 대화 NPC 주변을 비운다.
`BLOCKED` 상수처럼 코드에 박지 말 것 — 광장과 마을이 같은 스크립트를 쓴다.

### 3-2. 규칙 충돌과 그 해결 — **밤 고정 구역의 유혹**

광장이 밤 고정이면 낮 액션(`inquire`·`challenge`)은 **영원히 시도할 수 없다.**
그런데 `allure`(유혹)의 선행 조건은 `pa_inquire_{npc}`(낮의 정보수집 성공)다.
→ **광장의 유혹은 어떤 플레이를 해도 실패하는 죽은 선택지가 된다.**
M1이 낮과 밤을 묶으려고 넣은 유일한 장치(M1 §3-3)가 이 구역에서만 무력화되는 것이다.

검토한 안:

| 안 | 내용 | 판정 |
|---|---|---|
| (i) | 광장 NPC에게 유혹을 주지 않는다 | 밤 목록이 조사 1개뿐이라 "목록"이 성립하지 않는다. 광장에서 할 수 있는 일이 한 가지가 된다 |
| (ii) | 액션을 5종으로 늘린다(`allure_night.tres`) | 판정 규칙은 같고 선행 플래그만 다른데 파일이 복제된다. 밸런스를 고칠 때 두 곳을 고쳐야 하고, **"패스 액션은 낮 2 / 밤 2"라는 M1 확정 사항이 데이터에서 깨진다**(`headless_m1_data.gd`의 "정확히 4개" 단언도 깨진다) |
| (iii) | 광장을 밤 고정에서 뺀다 | §2-1에서 기각 |
| **(iv)** | **엔트리에서 선행 플래그를 오버라이드한다** | **채택** |

**채택안 (iv):** `NpcPassAction`에 `override_required_flag`를 추가한다(비우면 `action.required_flag`로
폴백하므로 **M1 데이터의 동작은 한 글자도 바뀌지 않는다**). 광장 NPC의 유혹 엔트리만
`pa_scrutinize_{npc}`를 요구하게 한다 — 밤 안에서 **조사 → 유혹** 2단 연계가 성립한다.

`NpcPassAction`은 원래 "NPC별 오버라이드 그릇"이고 `override_reward_gold`라는 선례가 있다.
덤으로 구역의 톤 차이가 규칙으로 표현된다: **마을에서는 낮의 안면이 밤의 호의를 만들고,
도시에서는 밤의 관찰이 먼저다.**

판정 코드도 함께 고쳤다(`pass_action_judge.gd`의 `FLAG` 분기 → `entry.resolve_required_flag()`).
데이터만 넣고 이 한 줄을 빼면 **에러 없이 유혹이 영구 실패**한다.

### 3-3. 광장 NPC 3명

수치 축은 M1 §3-3을 그대로 존중한다: 조사 난이도 상한 3, 도전 레벨 상한 8, 유혹은 플래그 선행.
광장에서 관찰 가능한 판정은 `DIFFICULTY`(조사)와 `FLAG`(유혹) 두 가지뿐이므로,
**여유 성공 · 경계값 성공 · 실패**를 조사 난이도 2 / 3 / 5로 배치했다.

| `npc_id` | 표시명 | 난이도 | 레벨 | 밤 액션 | 낮 액션 | 기대 결과 |
|---|---|---|---|---|---|---|
| `hadel` | 등불지기 하델 | 2 | 5 | 조사, 유혹(선행 `pa_scrutinize_hadel`) | **없음** | 조사 여유 성공 → 유혹 성공 |
| `vanne` | 전표상 반느 | 3 | 6 | 조사, 유혹(선행 `pa_scrutinize_vanne`) | **없음** | 조사 **경계값** 성공 → 유혹 성공 |
| `orlek` | 집정관 호위 오를렉 | 5 | 15 | 조사, 유혹(선행 `pa_scrutinize_orlek`) | **없음** | 조사 실패 → 유혹 **연쇄 실패** |

- **낮 액션을 하나도 주지 않았다.** 광장은 밤 고정이라 낮 액션은 **영원히 화면에 못 나오는 데이터**다.
  넣어 두면 다음 사람이 "이건 언제 뜨지"를 쫓게 된다. 검증 가능한 사실이므로 단언으로 못 박는다
  (`actions_for(false).size() == 0`).
- **난이도 5는 이 프로젝트에서 처음 쓰는 값이다**(상한). 마을의 보든(4)과 역할은 같지만 축이 다르다 —
  보든은 낮의 말길이 막히고, 오를렉은 밤의 관찰 자체가 막힌다.
- **순서 의존이 이 구역의 플레이 장치다.** 조사 전에 유혹을 고르면 실패한다. 유혹은 1회성이지만
  `failure_flag`가 비어 있어 **실패는 잠그지 않는다**(`PassActionJudge.is_locked`는 성공 플래그만 본다).
  그래서 조사에 성공한 뒤 다시 말을 걸면 유혹이 성공한다. 이 왕복이 밤 안에서 완결된다.
- **낮 대사도 채웠다.** 광장은 밤 고정이라 낮 대사는 화면에 안 나오지만, `lines_for(false)`는
  낮 대사를 반환하고 비어 있으면 빈 대화창이 뜬다. 시간대 잠금이 어떤 이유로 풀렸을 때
  빈 창 대신 말이 되는 화면이 나오도록 2페이지씩 넣었다. **규칙: `day_lines`는 어떤 구역에서도 비우지 않는다.**

### 3-4. 도시 톤 — 마을 3명과 무엇이 다른가

| | 마을(리네·보든·유리) | 광장(하델·반느·오를렉) |
|---|---|---|
| 화제 | 생계, 북쪽 길 소문, 떠도는 이야기 | 등 기름과 소등 지시, 전표와 서명, 관할과 근무 |
| 관계 | 얼굴을 아는 사이 | 이름 대신 직함·서명. 익명성 |
| 권력 | 없음 | 시청·집정관이 화제의 배후에 계속 있다 |
| 밤의 의미 | 가게를 닫고 등을 켠다 | **밤이 영업시간이다** (반느: "밤값이 더 쌉니다") |

세 명의 밤 대사가 하나의 사건을 서로 다른 각도로 가리킨다: 하델은 "북쪽 열 개를 켜지 말라는 지시"를,
반느는 "이름 없는 전표"를, 오를렉은 "듣는 사람은 따로 있다"를 말한다. 셋 다 들어야 무슨 일인지
윤곽이 잡히는 배치다 — 세 명에게 전부 말을 걸 이유가 대사만으로 생긴다.

### 3-5. 배치 권장 (구현자용, 확정 아님)

플레이 영역(§4-1) 안에서, 배경 인파 띠(z −7 ~ 0 권장)와 겹치지 않는 남쪽 대역을 권한다.

| NPC | 권장 좌표 (x, 0, z) | 이유 |
|---|---|---|
| `hadel` | `(-4.2, 0, 1.0)` | 서쪽 등불(LampA/B) 근처 — 등불지기가 등 옆에 선다 |
| `vanne` | `(3.6, 0, 1.6)` | 동쪽, 플레이어 진입 동선(서→동)의 끝 |
| `orlek` | `(0.0, 0, -4.6)` | 계단·아치 바로 앞. **접근 자체가 "여기까지다"를 말한다** |

셋의 상호작용 반경(실효 1.6 m)이 서로 물리지 않는 간격이다. 오를렉만 북쪽 깊숙이 두어
"벽까지 걸어가 봐야 만난다"는 동선을 만든다.

---

## 4. 플레이 영역과 카메라

### 4-1. 플레이 영역 (권장)

광장 지형과 소품의 실제 좌표에서 역산한 값이다.

| 경계 | 목표 **도달** 범위 | 근거 |
|---|---|---|
| 동서 | `x ∈ [-9.7, +9.7]` | 좌우 건물 안쪽면 `x ∓11`, 철책 `x ±11~12.5` 안쪽. 마을과 같은 폭이라 카메라 계산을 유추하기 쉽다 |
| 북 | `z ≥ -5.7` | 조각상 `z -6.5`, 사이프러스 `z -7.5`, 계단 `z -8.2` 앞에서 멈춘다. 아치 통과는 M3 실내용으로 남긴다 |
| 남 | `z ≤ +3.7` | 전경 스프라이트(`z 7.0~8.8`)보다 훨씬 앞. 전경은 카메라 근처를 스쳐야 하므로 절대 도달하면 안 된다 |

**충돌체:** `Bounds`(StaticBody3D) 아래 네 벽. 마을과 같은 방식으로 두께 1.0 / 높이 4를 쓰면
벽 중심은 `x ±10.5`, `z -6.5 / +4.5`가 된다(안쪽면 ∓0.5, 캡슐 반지름 0.3을 빼면 위 도달 범위).
서쪽 벽은 게이트 틈(`z -1.3 ~ +1.3`, 폭 2.6) 때문에 **두 조각으로 나눈다.**

**게이트·스폰 권장 좌표**

| 구역 | 노드 | 좌표 / 크기 |
|---|---|---|
| 마을 | `WarpGate` → `TownSquare` / `from_village` | 중심 `(10.1, 1.0, 0.0)`, 박스 `1.4 × 2.4 × 2.6`. 동쪽 벽을 `z -8.25~-1.3` / `z 1.3~5.75` 두 조각으로 나눠 틈을 만든다 |
| 마을 | `SpawnPoint from_town_square` | `(8.2, 0, 0.0)` — 게이트 존(`x ≥ 9.4`) 바깥 1.2 m |
| 마을 | `SpawnPoint default` | `(0, 0, 0.6)` — 현재 플레이어 위치 그대로 |
| 광장 | `WarpGate` → `Field` / `from_town_square` | 중심 `(-10.1, 1.0, 0.0)`, 박스 `1.4 × 2.4 × 2.6` |
| 광장 | `SpawnPoint from_village` | `(-8.2, 0, 0.0)` |
| 광장 | `SpawnPoint default` | `(0, 0, 2.6)` — 광장을 정면으로 보는 첫 구도 |

마을 동쪽 → 광장 서쪽으로 이었다. "동쪽으로 가면 도시"라는 지리가 생기고, 두 씬의 게이트가
서로 반대편 벽에 있어 왕복 동선이 직관적이다.

### 4-2. 카메라·DOF는 **여기서 확정하지 않는다.** 계산 절차와 제약만 정한다

현재 값은 정지 구도용이다: `FieldCamera` 위치 `(0, 10, 18)` / 피치 −22° / fov 30,
DOF near 17(전이 4) / far 34(전이 8) / amount 0.09. 마을은 near 16(전이 4) / far 28(전이 10) /
amount 0.11이고, `field_camera.gd`의 `limit_x ±5`, `limit_z 16.0~19.5`는 **마을 구도에서 실측한 값**이다.
광장은 플레이 영역도 DOF도 다르므로 그대로 쓰면 안 된다.

**최상위 제약: 플레이어는 어느 도달 위치에서도 DOF 선명 구간 안에 있어야 한다.**
주인공이 흐려지는 화면은 다른 어떤 장점으로도 상쇄되지 않는다.

**계산 순서 (이 순서를 지킬 것 — 뒤집으면 두 번 계산하게 된다)**

1. **플레이 영역을 먼저 확정한다**(§4-1). 카메라는 영역의 함수다. 반대로 하면 DOF를 맞춘 뒤
   영역을 넓히게 되고 전부 다시 계산해야 한다.
2. **`follow_offset` = 씬의 카메라 초기 위치 − 플레이어 기준점**. 마을은 `(0,10,18) − (0,0.8,0.6)
   = (0, 9.2, 17.4)`로 잡아 추적을 붙여도 화면 인상이 바뀌지 않게 했다. 광장도 같은 규칙을 쓴다.
   **카메라 초기 위치 자체를 바꾸고 싶다면 먼저 구도 캡처로 합의하고, 그다음 offset을 재계산한다.**
3. **`limit_z`를 DOF로 결정한다.** 플레이어 몸 전체(발 `y 0` ~ 머리 `y 1.61`, 스프라이트 상단은
   `0.804 + 0.804`)와 카메라 사이 거리를 남단·북단 두 극단에서 계산한다.
   - 마을의 판정 기준은 **`near_distance` 자체**를 하한, `far_distance`를 상한으로 삼았다
     (`Field.tscn` 주석에 머리 16.57 / 가슴 16.87 / 발 17.16 같은 실측이 남아 있다).
     **광장도 같은 기준을 쓰되, 근전이가 4로 같고 원전이가 8(마을 10)로 좁다는 점을 주의할 것.**
   - near를 내리는 대가는 근경이 선명해지는 것이다. 마을에서는 프레임 블러를 `CameraFrame`(깊이 5~7.6 m)이
     만들어 주어 near 16이 안전했다. **광장에는 카메라 자식 프레임이 없다** — 전경이 월드 고정
     (`z 7.0~8.8`)이므로 near를 내리면 그 전경이 선명해져 깊이감이 사라진다. near/far를 고치기 전에
     반드시 전경 깊이를 함께 계산할 것.
4. **`limit_x`를 프레이밍으로 결정한다.** 플레이어 깊이에서 화면 가로 반폭 ≈ `깊이 × tan(25.5°)`
   ≈ `깊이 × 0.4763` (fov 30 세로 / 16:9). 조건:
   `|플레이어x − 카메라x| + 0.5(캐릭터 반폭) ≤ 화면 반폭 − 1.5(마진)`.
   마진 1.5 m는 비네팅과 전경이 화면 가장자리를 먹기 때문이다.
   > **주의 — 마을 주석의 수치 오류를 그대로 베끼지 말 것.** `Field.tscn`은 도달 범위를
   > `x ±10.2`로 적어 두었지만, 실제 벽(중심 `±10.5`, 두께 1.0)과 캡슐 반지름 0.3에서
   > 나오는 값은 **`±9.7`**이다. 결과적으로 마을은 실제보다 넓은 최악의 경우로 계산해
   > 안전한 쪽으로 틀렸다. 광장에서는 벽 좌표에서 직접 역산할 것.
5. **캡처로 확인한다.** 도달 범위의 **네 모서리 + 중앙 5점**을 `--pose`로 찍어
   (a) 주인공이 선명한가 (b) 화면 안에 있는가 (c) 가려지지 않는가를 본다.
6. **마지막에** DOF 수치를 미세 조정한다. 먼저 고치면 3·4의 계산이 전부 무의미해진다.

**추가 제약 C1 — 월드 고정 전경이 주인공을 가린다.** 마을에서 실측한 교훈이다
(기존 `FgTreeL`이 468개 구도 중 358개에서 플레이어를 가렸다). 광장의 `Foreground/FgFigureL·R`은
`pixel_size 0.21~0.229`의 **큰 인물**이라 위험이 더 크다. `limit_x`를 정한 뒤 카메라 x가 양 끝일 때
플레이어 화면 열을 침범하는지 마을과 같은 방법으로 래스터 검사할 것. 침범하면
(a) 카메라 자식으로 옮기거나 (b) 좌우로 더 밀거나 (c) `limit_x`를 좁힌다 — 판단은 hd2d-visual-tuner.

**추가 제약 C2 — 배경 인파가 플레이어를 가린다.** 인파 띠가 현재 `z -7 ~ +2`로 플레이 영역과
겹친다. 인파 사이를 지나가며 앞사람에게 가려지는 것 자체는 정상이지만(3D 깊이라 정렬은 자동),
**플레이어가 주로 걷는 남쪽 대역까지 인파가 서면 계속 가린다.** `npc_area_center/size`를
`z -7 ~ 0` 정도로 물리는 것을 권한다(예: center `(0, -3.5)`, size `(23, 7)`).

**추가 제약 C3 — `--pose` 캡처가 깨지지 않게 할 것.** `tools/capture_screenshot.gd`는
`CharacterBody3D`를 **정확히 1개** 찾고, 활성 카메라에 `follow_offset`/`limit_x`/`limit_z`가
있어야 동작한다. 광장 카메라에 `field_camera.gd`를 붙이고 플레이어를 1명만 둘 것.
기존 정적 `Actors/Player`·`NpcA`·`NpcB` Sprite3D 3개는 **삭제**한다(장식이고, 새 NPC와 겹친다).

---

## 5. 데이터·스키마 변경 (본 작업에서 완료)

### 5-1. 신규 스키마

| 클래스 | 파일 | 역할 |
|---|---|---|
| `ZoneData` | `scripts/data/zone_data.gd` | 구역 1개의 규칙 |

| 필드 | 타입 | 기본 | 의미 |
|---|---|---|---|
| `zone_id` | `String` | `""` | 내부 id (snake_case) |
| `display_name` | `String` | `""` | 표시명. 알림 화자 + `{zone}` 토큰 |
| `phase_policy` | `PhasePolicy` | `FREE` | `0=FREE, 1=LOCK_DAY(미사용), 2=LOCK_NIGHT` |
| `phase_locked_notice` | `String`(multiline) | `""` | 잠금 안내 문구. 비면 조용히 무시 |
| `default_spawn_id` | `StringName` | `&"default"` | 기본 스폰 id |

메서드: `is_phase_locked()`, `locked_is_night()`, `resolve_notice()`

> `LOCK_DAY`는 M2 1차 데이터에 없다. bool 두 개(`locked` + `locked_is_night`)로 두면
> "잠기지 않았는데 잠긴 시간대가 밤"이라는 성립 불가 조합이 표현된다. enum 값 추가는 **끝에만**.

### 5-2. 기존 스키마 변경

`NpcPassAction`에 **`override_required_flag: String = ""`** 추가 + `resolve_required_flag()`.
비우면 `action.required_flag`로 폴백 → **M1 데이터 동작 불변**(회귀 검증 완료, §7 V4).

`pass_action_judge.gd`의 `FLAG` 분기가 `entry.resolve_required_flag()`를 쓰도록 수정.

### 5-3. 신규 데이터

| 경로 | 내용 |
|---|---|
| `data/zone/zone_village.tres` | `village` / 여울마을 / `FREE` |
| `data/zone/zone_town_square.tres` | `town_square` / 집정관 광장 / `LOCK_NIGHT` + 안내 문구 |
| `data/npc/npc_hadel.tres` | 등불지기 하델 — 난이도 2 / Lv5 / 밤 2종 |
| `data/npc/npc_vanne.tres` | 전표상 반느 — 난이도 3 / Lv6 / 밤 2종 |
| `data/npc/npc_orlek.tres` | 집정관 호위 오를렉 — 난이도 5 / Lv15 / 밤 2종(전부 실패) |

**전부 `ResourceSaver`로 생성했다** (`tools/gen_m2_data.gd`, 멱등). 손으로 쓰면
`Array[ExtResource(...)]` 직렬화를 추측하게 되고 **에러 없이 빈 배열로 로드된다.**
값을 바꿀 때도 `.tres`를 직접 고치지 말고 생성기를 고쳐 다시 돌릴 것.

> `default_spawn_id`는 기본값과 같아 `.tres`에 기록되지 않았다(Godot은 기본값을 생략한다).
> 정상이다 — 로드하면 `&"default"`가 된다. 다른 값을 쓰면 그때 파일에 나타난다.

### 5-4. 신규 텍스처

`char_npc_d_sheet.png`(하델) / `char_npc_e_sheet.png`(반느) / `char_npc_f_sheet.png`(오를렉).
`tools/gen_placeholder_textures.gd`의 **마커 생성 직전**에 추가했다(난수를 쓰지 않는 생성기이므로
기존 텍스처의 난수 스트림에 영향이 없다 — 재생성 후 `char_crowd_05`/`facade`/`interact_marker`의
md5가 동일함을 확인했다).

---

## 6. M1 자산에 미치는 영향

### 6-1. 깨지지 않는 것 (실행 확인 완료)

`godot.sh check` 21/21, `godot.sh test` 4/4 통과. 신규 NPC는 `headless_m1_data.gd`의
`NPC_FILES`에 없어 **아직 어떤 테스트도 광장 데이터를 보지 않는다.**

### 6-2. 테스트를 이렇게 고쳐라 (무력화 금지)

1. **`headless_m1_data.gd`의 `NPC_FILES`에 광장 3명을 그냥 추가하면 깨진다.**
   `_test_npcs()`가 `pass_actions.size() >= 3`을 단언하는데 광장 NPC는 2개다(낮 액션이 없으므로 의도된 값).
   → **추가하지 말 것.** `headless_m1_data.gd`는 "M1 데이터가 회귀하지 않았는가"라는 단일 목적을
   유지한다. 하한을 2로 낮추면 마을 데이터의 회귀 감지력이 같이 떨어진다.
2. **단, `_test_unknown_keys()`의 범위는 반드시 넓힌다.** 스키마에 없는 키는 조용히 무시되므로
   이 검사가 신규 파일을 안 보면 오타를 영영 못 잡는다. 하드코딩된 파일 목록 대신
   `data/npc/*.tres` + `data/zone/*.tres`를 **디렉터리 스캔**으로 훑게 바꿀 것
   (그러면 앞으로 NPC를 추가할 때 테스트를 고칠 필요가 없다).
   zone 파일에는 `sub_resource`가 없으므로 기존 파서 분기가 그대로 안전하다.
3. **멀티라인 파서 취약점**(M1 검증 §2-5)을 이 기회에 고칠 것. 신규 대사에는 `" = "`를 넣지 않았지만,
   데이터가 늘수록 터질 확률이 커진다.
4. **신규 `tests/headless_m2_data.gd`** — §7 V1~V5, V16.
5. **신규 `tests/headless_m2_town.gd`** — §7 V6~V15. `SceneRouter`는 autoload지만
   헤드리스 `--script`에서는 초기화가 보장되지 않는다. `headless_day_night.gd`처럼
   `load("res://scripts/core/scene_router.gd").new()`로 직접 인스턴스화하고 컨테이너를 주입할 것.

### 6-3. M1 구현물에 들어가는 수정 (전부 하위 호환)

| 파일 | 수정 | 위험 |
|---|---|---|
| `scripts/core/scene_router.gd` | `change_scene(path, spawn_id := &"")`, `consume_pending_spawn_id()`, `is_transitioning` 가드 | 기본 인자라 `main.gd` 무수정 |
| `scripts/field/field.gd` | `@export var zone: ZoneData` 추가, **`start_at_night` 제거**(→ `zone.phase_policy`), 스폰 적용, 카메라 스냅, 컨트롤러에 구역 주입 | `TownSquare.tscn`의 `start_at_night = true` 줄을 **반드시 함께 지울 것.** 안 지우면 로드 경고가 뜨고 밤 강제가 zone 쪽으로만 남는다. 어떤 테스트도 `start_at_night`를 보지 않음(확인함) |
| `scripts/field/field_camera.gd` | `snap_to_target()` 공개, `_ready`도 이를 사용 | 없음. `--pose` 캡처가 읽는 프로퍼티 3종(`follow_offset`/`limit_x`/`limit_z`)의 **이름을 바꾸지 말 것** |
| `scripts/field/interaction_controller.gd` | `State.NOTICE`(끝에 추가), `show_notice()`, `configure_zone()`, `handle_toggle_phase()`에 잠금 분기 | `State` 중간에 끼워 넣으면 `headless_m1_interaction.gd`의 상태 비교가 조용히 어긋난다 |
| `scripts/field/scatter_props.gd` | `npc_blocked_rects: Array[Rect2]` 추가 | 기본값 빈 배열 → 마을 무영향 |
| `scenes/field/FieldNpc.tscn` | `AuraLight`(OmniLight3D, 기본 꺼짐) + `aura_enabled` export | 마을 NPC는 끈 채 두면 화면 불변 |
| `scenes/field/Field.tscn` | `zone` 지정, `Spawns` 노드, 동쪽 벽 2분할 + `WarpGate` | 벽을 나눌 때 **틈이 생긴 만큼 카메라 `limit_x`는 그대로여도 되는지 확인**(플레이어가 x 10.8까지 나갈 수 있게 된다) |

---

## 7. 검증 기준 (godot-validator용)

### 헤드리스로 검증 가능

| # | 판정 기준 | 방법 |
|---|---|---|
| V1 | 광장 NPC 3명이 로드되고 모든 표시값이 기본값이 아니다 | `npc_id`/`display_name`/`sprite`/`difficulty`/`level`/대사/`pass_actions` 확인 |
| V2 | 광장 NPC는 **낮 액션이 0개**, 밤 액션이 2개다 | `actions_for(false).size() == 0`, `actions_for(true).size() == 2` |
| V3 | 조사 판정이 2 / 3 / 5로 갈린다 | `hadel`·`vanne` 성공(경계값 3 포함), `orlek` 실패 |
| V4 | 유혹 선행 조건 — 광장은 `pa_scrutinize_{npc}`, **마을은 여전히 `pa_inquire_{npc}`** | `entry.resolve_required_flag()` 비교. 마을 쪽이 M1 회귀 감지선이다 |
| V5 | 조사 성공 전에는 유혹 실패, 성공 후에는 유혹 성공, 그 뒤 밤 목록이 2→1로 준다 | 격리 `GameState`에 `PassActionJudge.resolve()` 2회. `orlek`은 두 번 다 실패하고 목록이 2로 유지된다 |
| V6 | `ZoneData` 정책이 데이터에 들어 있다 | `town_square`=`LOCK_NIGHT`, `village`=`FREE`, `resolve_notice()`에 `집정관 광장`이 박히고 `{`가 남지 않음 |
| V7 | `change_scene(path, spawn_id)` 후 보류 id를 **한 번만** 가져올 수 있다 | 1회차 == 넘긴 값, 2회차 == `&""` |
| V8 | 이중 전환이 막힌다 | 같은 프레임에 `change_scene` 2회 → 두 번째 `false`, 컨테이너 자식 1개 |
| V9 | 스폰 id대로 선다 | 광장 진입 후 플레이어 x·z가 `from_village` 스폰과 ±0.05 이내 |
| V10 | 없는 스폰 id는 기본 스폰으로 떨어지고 **경고를 남긴다** | 존재하지 않는 id로 진입 → `default` 좌표 + `push_warning` 발생 |
| V11 | 게이트가 스폰 직후 발화하지 않는다 | 플레이어를 게이트 존 **안**에 두고 씬 시작 → 물리 프레임 5회 후 전환 0회 |
| V12 | 게이트가 정상 통과 시 1회만 발화한다 | 존 밖 → 안으로 이동, 물리 프레임 5회 → `change_scene` 호출 1회 |
| V13 | 광장 진입 시 낮이었어도 밤이 된다 / 광장을 나가도 밤이 유지된다(§2-2) | `DayNight.set_night(false)` → 광장 `_ready` 후 `is_night == true` → 마을 복귀 후에도 `true` |
| V14 | 광장에서 `toggle_phase`가 막히고 안내가 뜬다 | `handle_toggle_phase()` → `is_night` 불변, `state == NOTICE`, 대화창 본문 == 치환된 안내문 |
| V15 | 마을에서는 `toggle_phase`가 여전히 동작한다 (M1 회귀) | `is_night` 반전, `state == FREE` 유지 |
| V16 | `NOTICE`에서 이동이 잠기고 `interact`/`cancel`로 `FREE`로 돌아온다 | `is_movement_locked()` true → 입력 후 `FREE` |
| V17 | 신규 `.tres`에 스키마에 없는 키가 없다 | `data/npc/*` + `data/zone/*` 디렉터리 스캔 (§6-2) |
| V18 | 씬이 로드된다 | `godot.sh smoke res://scenes/field/TownSquare.tscn` |

### 사람 눈이 필요한 것

| # | 확인할 것 | 방법 |
|---|---|---|
| V19 | **주인공이 어디서도 흐려지지 않는다** (최상위 제약, §4-2) | 도달 범위 네 모서리 + 중앙 5점 `--pose` 캡처 |
| V20 | 주인공이 화면 밖으로 나가지 않고, 전경·인파에 계속 가려지지 않는다 | 같은 5점 캡처 + 카메라 x 양 끝 |
| V21 | **말을 걸 수 있는 3명이 인파 16명과 구분된다** (§3-1) | 광장 전경 캡처 1장. "누구에게 말을 걸지 5초 안에 고를 수 있는가"가 판정 기준 |
| V22 | 게이트 위치를 눈으로 찾을 수 있다 | 마을 동쪽·광장 서쪽 캡처. 못 찾으면 표지판·등불 추가(hd2d-visual-tuner) |
| V23 | 전환 순간 카메라가 밀려들지 않고, 낮 화면이 한 프레임도 안 보인다 | `godot.sh run 20`으로 왕복 |

**캡처 관용구** (M1 검증 결함 2 — `wait:N`은 프레임 단위라 벽시계 연출과 동기화되지 않는다):

```bash
S=.claude/skills/godot-run/scripts/godot.sh
# 광장 단독 구도 (default 스폰). Main을 거치지 않으므로 씬 전환은 확인할 수 없다
bash $S shot _screenshots/sq_center.png true "" "0,2.6" res://scenes/field/TownSquare.tscn
# 마을에서 동쪽 게이트를 걸어서 통과 → 광장 도착 화면 (전환 검증)
bash $S shot _screenshots/sq_arrive.png false "hold:move_right:40;wait:30" "9.0,0.0"
# 광장 NPC 대화·패스 액션: 페이지당 press 2회 (완성 → 넘김)
bash $S shot _screenshots/sq_talk.png true "press:interact;press:interact;press:interact;press:interact;wait:40" "-4.2,2.0" res://scenes/field/TownSquare.tscn
```

> `--scene`으로 광장을 직접 띄우면 `Main.tscn`을 거치지 않아 **`SceneRouter`에 컨테이너가 등록되지
> 않는다.** 그 상태에서 게이트에 들어가면 `push_warning`만 남고 아무 일도 일어나지 않는다 —
> **정상이다.** 전환을 확인하려면 반드시 기본 씬(`Main.tscn`)으로 실행할 것.

---

## 8. 인계

### godot-scene-builder에게

**새로 만들 것**
- `scripts/field/warp_gate.gd` (§1-2, §1-5의 G2·G3·G4), `scripts/field/spawn_point.gd`
- `tests/headless_m2_data.gd`, `tests/headless_m2_town.gd` (§6-2, §7)

**고칠 것** — §6-3 표가 전부다. 특히:
- `TownSquare.tscn`에서 `start_at_night = true`를 **지우고** `zone = zone_town_square.tres`를 물릴 것
- 정적 `Actors/Player`·`NpcA`·`NpcB`(Sprite3D) **삭제** → `FieldPlayer.tscn` 1개 + `FieldNpc.tscn` 3개
  (`npc_hadel` / `npc_vanne` / `npc_orlek`, `aura_enabled = true`) + `InteractionController`
  (`player_path`) + `Bounds` + `Spawns` + `WarpGate`
- `FieldCamera`에 `field_camera.gd`를 붙이고 `target_path`를 지정 (§4-2 C3)
- `InteractionController`는 **`Actors`보다 뒤에** 선언할 것 — `player_path`가 가리키는 노드가
  먼저 존재해야 한다(마을과 같은 규칙)
- 새 `.gd`를 추가하면 `godot.sh import`를 먼저 돌려야 `class_name`이 전역 캐시에 등록된다

**절대 하지 말 것**
- `State` enum 중간에 값 끼워 넣기, `PhasePolicy`/`JudgeKind` 순서 변경 (M1 §3-6)
- `field.gd._unhandled_input`에서 시간대 잠금을 막기 (§2-3 — 그 코드는 실행되지 않는다)
- `.tres` 손편집 (§5-3 — `tools/gen_m2_data.gd`를 고쳐 다시 돌릴 것)
- `field_camera.gd`의 `follow_offset`/`limit_x`/`limit_z` **이름** 변경 (§4-2 C3)

### hd2d-visual-tuner에게

- **카메라·DOF 재계산** — §4-2의 절차 1~6과 제약 C1~C3. **수치는 이 문서에 없다.**
  최상위 제약은 "주인공이 어느 도달 위치에서도 선명할 것"이다.
- **대화 가능 NPC의 발밑 후광(D1)** — 밤 광장에서 3명만 빛 아래 서 있게. 세기는 배경 등불보다
  약하게(등불을 이기면 광장의 조명 계획이 무너진다). 판정 기준은 V21.
- **게이트의 시각 신호(V22)** — 마을 동쪽 틈과 광장 서쪽 틈. 표지판·등불 한 쌍 정도면 충분하다.
- **배경 인파 띠 축소(C2)** — `npc_area_center/size` 조정 후 인파 인상이 얇아지지 않았는지 확인.
- **전환 페이드는 이번 범위가 아니다**(§1-7). 넣고 싶다면 `SceneRouter`의 G1 가드 안쪽에 넣을 것 —
  게이트 코드는 고칠 필요가 없다.

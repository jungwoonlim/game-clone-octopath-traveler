# M1 필드 탐험 — 규칙·데이터 스키마 설계

작성: 2026-09-10 / 담당: game-system-designer
범위: 입력 맵, 대화 진행, 패스 액션(낮 2 / 밤 2), 필드 상태 머신, 데이터 스키마와 `.tres`

이 문서는 **결정된 규칙의 단일 진실 원천**이다. 구현(`scenes/**`, `scripts/field/**`)과
검증(`tests/**`)은 여기 적힌 판정 기준을 그대로 옮기면 된다.

---

## 1. 입력 액션

### 1-1. 결정: `ui_*`를 쓰지 않고 커스텀 액션명을 쓴다

**왜:** `ui_up/down/left/right`와 `ui_accept/ui_cancel`은 포커스를 가진 `Control`이
**먼저 소비하거나 동시에 반응한다.** 대화창에 버튼 하나만 놓아도 `ui_accept` 한 번에
"대사 다음 줄"과 "버튼 눌림"이 같이 일어나고, 패스 액션 목록을 방향키로 고를 때
캐릭터가 함께 걸어간다. 이 충돌은 나중에 원인을 찾기가 매우 어렵다.

따라서 **게임플레이 입력은 커스텀 액션, UI 내비게이션은 Godot 기본 `ui_*`** 로 완전히 분리한다.
`ui_*`의 기본 바인딩은 손대지 않는다 — 손대면 Godot 기본 UI가 조용히 망가진다.

방향키(↑↓←→)가 `move_*`와 `ui_*`에 이중으로 걸리는 것은 의도된 것이다.
상태 머신이 `FREE`일 때만 `move_*`를 읽으므로(§4) 실제 충돌은 발생하지 않는다.

### 1-2. 액션 표 (`project.godot`의 `[input]`과 스크립트의 단일 진실 원천)

| 액션 이름 | 키보드 | 게임패드 | 용도 | 비고 |
|---|---|---|---|---|
| `move_up` | `W`, `↑` | D-pad Up (버튼 11), 좌스틱 Y− (축 1, −1.0) | 필드 이동 | 축 데드존 0.5 |
| `move_down` | `S`, `↓` | D-pad Down (버튼 12), 좌스틱 Y+ (축 1, +1.0) | 필드 이동 | |
| `move_left` | `A`, `←` | D-pad Left (버튼 13), 좌스틱 X− (축 0, −1.0) | 필드 이동 | |
| `move_right` | `D`, `→` | D-pad Right (버튼 14), 좌스틱 X+ (축 0, +1.0) | 필드 이동 | |
| `interact` | `Space`, `Enter` | A (버튼 0) | 말 걸기 / 대사 넘기기 / 선택 확정 | |
| `cancel` | `Escape`, `Backspace` | B (버튼 1) | 대화 중단 / 목록 닫기 / 메뉴 닫기 | |
| `menu` | `Tab` | START (버튼 6) | 시스템 메뉴 열기 | |
| `toggle_phase` | `N` | Y (버튼 3) | 낮/밤 전환 | **개발 편의용.** M3 이후 여관 숙박으로 옮긴다 |

게임패드 버튼 인덱스는 추측이 아니라 Godot 4.7.2에서 실측한 값이다
(`JOY_BUTTON_A=0, B=1, X=2, Y=3, BACK=4, GUIDE=5, START=6, LS=9, RS=10, DPAD U/D/L/R=11/12/13/14`,
`JOY_AXIS_LEFT_X=0, JOY_AXIS_LEFT_Y=1`).

**WASD는 `physical_keycode`로 등록한다.** `keycode`로 등록하면 AZERTY·드보락 배열에서
엉뚱한 키가 걸린다. 방향키·Space·Enter 등 위치가 고정된 키는 어느 쪽이든 무방하다.

### 1-3. 이동 입력 처리 규칙

- 이동은 `Input.get_vector("move_left", "move_right", "move_up", "move_down")`로 읽는다.
  4방향 개별 분기를 쓰면 대각선 속도가 √2배가 되는 고전적 버그가 생긴다.
- 카메라가 −22° 부감으로 기울어져 있으므로 입력 벡터는 **카메라 Y 회전 기준**으로 변환한다
  (화면 위 = 월드 −Z 방향). 이 변환을 빠뜨리면 위쪽 키가 비스듬히 움직인다.
- 이동 속도 `4.0 m/s` (걷기). `@export_range(1.0, 8.0, 0.1)`로 노출해 조정 가능하게 둔다.

---

## 2. 대화 진행 규칙

### 2-1. 시작

1. 플레이어의 상호작용 탐지: 플레이어 자식 `Area3D`(반경 **1.2 m**)에 겹친 NPC 중 **가장 가까운 1명**을 후보로 둔다.
   - 전방 판정(바라보는 방향)은 M1에서 넣지 않는다. 스프라이트가 Y축 빌보드라 "어디를 보는지"가
     시각적으로 모호해서, 방향 판정을 넣으면 플레이어가 실패 원인을 이해하지 못한다.
2. 후보가 있고 상태가 `FREE`일 때 `interact` → `TALKING`으로 전이.

### 2-2. 진행

- 대사 묶음은 `NpcData.lines_for(DayNight.is_night)`로 얻는다. **배열 한 칸 = 대화창 한 페이지.**
- `interact` 1회 = 다음 페이지. 마지막 페이지에서 `interact`를 누르면:
  - 현재 시간대에 쓸 수 있는 패스 액션이 1개 이상 → `PASS_MENU`
  - 없으면 → `FREE` (대화 종료)
- `cancel`은 어느 페이지에서든 즉시 `FREE`로 종료한다. 검증·데모 시 대사를 빨리 넘기기 위해 허용한다.
- 타이핑 연출은 **30자/초**. 타이핑 중 `interact`를 누르면 다음 페이지로 넘기지 않고
  **현재 페이지를 즉시 전부 표시**한다 (JRPG 관례. 이걸 빼면 빠르게 누르는 플레이어가 대사를 놓친다).

### 2-3. 낮/밤 대사

- `day_lines` / `night_lines`를 **NPC 리소스가 각각 갖는다.**
- `night_lines`가 비어 있으면 `day_lines`로 폴백한다 (`NpcData.lines_for`).
  **왜:** 단역 NPC까지 밤 대사를 강제하면 의미 없는 문구로 채우게 되고, 실수로 비워두면
  빈 대화창이 뜬다. 폴백이 있으면 "밤에 할 말이 다른 NPC만" 밤 대사를 쓰면 된다.
- **대화 도중에 시간대가 바뀌면 안 된다.** `toggle_phase`는 `FREE` 상태에서만 받는다(§4).
  이걸 막지 않으면 대사 배열이 중간에 교체되어 인덱스가 배열 밖으로 나간다.

### 2-4. 진행 상태의 소유자

현재 페이지 인덱스는 **대화 UI(`DialogueBox`)가 소유**하고, `NpcData`는 읽기 전용이다.
`.tres` 리소스는 인스턴스가 프로젝트 전체에서 공유되므로, 여기에 진행 상태를 쓰면
같은 리소스를 참조하는 다른 NPC에게 상태가 새어 나간다.

---

## 3. 패스 액션 규칙

M1은 스텁이다. 전투도 동료 영입도 없고, 결과는 **결과 대사 1줄 + `GameState` 플래그/골드 변화**로 끝난다.
다만 **판정 방식만은 지금 확정**해 두고, 나중에 결과 처리만 갈아끼울 수 있게 만든다.

### 3-1. 4종 정의

| id | 표시명 | 시간대 | 판정(`judge_kind`) | 판정 기준 | 성공 결과 | 실패 결과 | 재시도 |
|---|---|---|---|---|---|---|---|
| `inquire` | 정보수집 | 낮 | `DIFFICULTY` | `npc.difficulty <= 3` | 플래그 `pa_inquire_{npc}` ON, 고유 정보 대사 | 거절 대사만 | 가능 |
| `challenge` | 도전 | 낮 | `LEVEL` | `npc.level <= 8` | 플래그 `pa_challenge_{npc}` ON, **결투 스텁 대사**(§3-4) | 거절 대사만 | 불가 |
| `allure` | 유혹 | 밤 | `FLAG` | `pa_inquire_{npc}`가 ON | 플래그 `pa_allure_{npc}` ON, 동행 대사 | 거절 대사만 | 불가 |
| `scrutinize` | 조사 | 밤 | `DIFFICULTY` | `npc.difficulty <= 3` | 플래그 `pa_scrutinize_{npc}` ON, **감춰진 수치 공개**(§3-5) | 거절 대사만 | 가능 |

`{npc}`는 대상의 `npc_id`로 치환된다(`PassActionData.format_flag`).
M1의 네 액션은 모두 **골드를 주지도 받지도 않는다**. 결과는 대사 한 줄과 플래그뿐이다.

### 3-2. 공통 처리 순서

1. **목록 구성** — `NpcData.actions_for(DayNight.is_night)`로 현재 시간대 액션만 추린다.
2. **잠금 제외** — 아래에 해당하면 목록에서 **제외**한다(회색 표시 없이 아예 뺀다. M1 단순화):
   - `failure_flag`(치환 후)가 ON → 이미 실패해 영구 차단됨 (M1 데이터에는 `failure_flag`를 쓰는 액션이 없다.
     규칙만 살려 두어 M2에서 "들켰다" 류 액션을 붙일 때 로직을 고치지 않게 한다)
   - `success_flag`가 ON **이면서** `repeatable == false` → 이미 완료됨 (`challenge`, `allure`)
3. **선택** — 목록이 1개여도 목록을 띄운다(입력 흐름이 일정해야 학습된다). `cancel`로 닫으면 `FREE`.
4. **판정** — `judge_kind`에 따라 위 표의 기준을 평가한다. **난수를 쓰지 않는다.**
5. **결과 적용** (성공 시): `GOLD` 종류면 `GameState.add_gold(-gold_cost)`로 **먼저 지불**하고,
   그 다음 `GameState.add_gold(entry.resolve_reward_gold())`. 마지막으로 `success_flag` ON.
   (실패 시): `failure_flag`가 비어 있지 않으면 ON.
   *M1의 네 액션은 골드가 0이라 실제로는 플래그만 켜진다. 순서 규칙은 M2를 위해 미리 못 박아 둔다.*
6. **결과 대사** — `entry.resolve_success_line()` / `resolve_failure_line()`으로 문구를 고른 뒤
   **반드시 `npc.format_line(...)`을 통과시켜** 토큰을 치환하고(§3-5) 대화창에 띄운다.
   `interact` 또는 `cancel`로 닫으면 `FREE`.

**난수를 쓰지 않는 이유:** M1의 목표는 규칙을 눈으로 확인하는 것이다. 확률이 끼면 헤드리스 테스트가
불안정해지고, 실패했을 때 "규칙 때문인지 운 때문인지" 구분할 수 없다. 확률은 M4에서 도입한다.

### 3-3. 수치 근거

- **`inquire` / `scrutinize` 난이도 상한 3** — 난이도(경계심)는 "말이 통하는가"를 뜻한다.
  NPC를 2/3/4로 배치해 **여유 성공 · 경계값 성공 · 실패** 세 결과를 전부 관찰할 수 있게 했다.
  경계값(유리 3)이 있어야 상한을 잘못 건드렸을 때 테스트가 바로 깨진다.
- **`challenge` 레벨 상한 8** — 도전은 경계심이 아니라 **실력**으로 갈려야 한다.
  유리(Lv7)는 경계값으로 응하고 보든(Lv12)은 거절한다. 난이도와 레벨을 다른 축으로 둔 덕에
  보든은 "말은 안 통하지만 도전은 받아줄 수도 있는" 식의 조합을 나중에 표현할 수 있다.
- **`allure`가 `inquire` 성공을 선행 조건으로 요구** — 낮과 밤을 왕복시키지 않으면 낮/밤 시스템은
  조명 스위치에 불과하다. 두 시간대를 묶는 최소 장치로 플래그 연계를 골랐다.
  부작용으로 보든은 낮 실패 → 밤 유혹도 연쇄 실패라, "벽인 NPC"가 자연스럽게 만들어진다.
- **골드 없음** — 이번 4종에는 거래가 없다. 억지로 보상을 붙이면 밸런스 기준이 없는 숫자가 생긴다.
  골드 경제는 상점이 들어오는 M2에서 한꺼번에 정한다.

### 3-4. `challenge`의 M3 전투 진입 훅

M1에서 `challenge`는 성공해도 "결투는 아직 이르다" 류의 대사로 끝난다. **전투로 잇는 자리는 한 곳이다:**

> `scripts/field/interaction_controller.gd`의 `_resolve_pass_action()` 마지막,
> `pass_action_resolved(npc_id, action_id, success)`를 emit하는 직후.
> M3에서는 이 시그널을 구독하는 쪽에서 `action_id == "challenge" and success`인 분기 하나를 추가해
> `GameState`에 대전 상대 `npc_id`를 기록하고 `SceneRouter.change_scene("res://scenes/battle/Battle.tscn")`을 호출한다.

**결과 처리 함수 안에서 직접 씬을 전환하지 말 것.** 시그널 바깥에서 전환하면 M1의 스텁 대사와
M3의 전투 진입이 같은 함수에 뒤섞여, 전투를 붙이는 순간 M1 검증 경로가 사라진다.

### 3-5. `scrutinize`의 결과 표시와 대사 토큰

조사는 **상대의 감춰진 수치를 드러내는 것 자체가 결과**다. 이미 스키마에 있는 `level`과 `difficulty`를
그대로 노출하고, 대사에는 값을 손으로 적지 않는다 — 밸런스를 바꾸면 대사와 실제 값이 어긋나기 때문이다.

결과 대사(성공·실패 모두)는 `NpcData.format_line()`을 통과하며 아래 토큰이 치환된다.

| 토큰 | 치환 값 |
|---|---|
| `{name}` | `display_name` |
| `{level}` | `level` |
| `{difficulty}` | `difficulty` (UI 표기는 "경계도") |

예: `"{name} — Lv.{level} / 경계도 {difficulty}"` → `"떠돌이 악사 유리 — Lv.7 / 경계도 3"`

### 3-6. `JudgeKind.GOLD`를 남기는 이유

새 4종에는 골드 판정이 없어 `GOLD`(=2)와 `gold_cost` 필드가 미사용이 된다. 그래도 **지우지 않는다.**

enum 중간 값을 지우면 뒤 값이 앞당겨져(`FLAG` 3 → 2, `LEVEL` 4 → 3) **이미 저장된 `.tres`의 정수가
다른 의미로 해석된다.** 지금은 파일이 4개뿐이라 함께 고칠 수 있지만, 이 위험은 데이터가 늘수록 커지고
어긋나도 에러가 나지 않는다(조용히 다른 판정이 걸린다). 남기는 비용은 enum 한 줄과 export 한 줄이고,
지우는 비용은 데이터 마이그레이션이다. M2 상점·M4 뇌물에서 골드 판정이 다시 필요할 것이 거의 확실하므로
자리를 지키고 주석에 "M1 미사용"을 명시했다.

같은 원칙으로 **새 판정 방식은 항상 enum 끝에 추가한다.** `LEVEL`(=4)도 그렇게 붙였다.

---

## 4. 필드 상태 머신

### 4-1. 소유자

상태는 **`InteractionController` 단 하나가 소유한다** (신규: `scenes/field/Field.tscn`의 자식 노드,
스크립트 `scripts/field/interaction_controller.gd`).

`FieldPlayer`는 자기 상태를 갖지 않고, 매 프레임 `controller.is_movement_locked()`만 질의한다.
**왜:** 이동을 잠글 이유는 앞으로 계속 늘어난다(대화·메뉴·컷신·전투 진입 연출). 플레이어가
잠금 사유를 각각 알아야 하면 사유가 늘 때마다 플레이어 코드를 고쳐야 하고, 해제를 한 군데 빠뜨리면
영원히 못 움직이는 버그가 난다.

### 4-2. 상태와 전이

```
        interact(대상 있음)        마지막 페이지 + 액션 있음
FREE ─────────────────────> TALKING ───────────────────────> PASS_MENU
 ^                             │                                │
 │        cancel / 마지막 페이지 + 액션 없음                       │ interact(선택)
 ├─────────────────────────────┘                                v
 │                     interact / cancel                     RESULT
 ├────────────────────────────────────────────────────────────┘
 │                                        cancel
 ├──> SYSTEM_MENU ────────────────────────────────┘
      (menu)
```

| 상태 | 이동 | `interact` | `cancel` | `menu` | `toggle_phase` |
|---|---|---|---|---|---|
| `FREE` | 허용 | 대화 시작(대상 있을 때) | 무시 | `SYSTEM_MENU` | **허용** |
| `TALKING` | 잠금 | 다음 페이지 / 타이핑 완성 | 대화 종료 → `FREE` | 무시 | 무시 |
| `PASS_MENU` | 잠금 | 선택 확정 → 판정 → `RESULT` | 목록 닫기 → `FREE` | 무시 | 무시 |
| `RESULT` | 잠금 | 닫기 → `FREE` | 닫기 → `FREE` | 무시 | 무시 |
| `SYSTEM_MENU` | 잠금 | 메뉴 항목 확정 | 닫기 → `FREE` | 닫기 → `FREE` | 무시 |

`is_movement_locked()`는 `state != FREE`와 동치다. 지금은 같지만 함수로 감싸 둔다 —
나중에 "메뉴는 열려 있어도 걸을 수 있다" 같은 변경이 오면 한 곳만 고치면 된다.

`toggle_phase`를 `FREE`에서만 받는 이유는 §2-3에 적었다(대사 배열 교체로 인한 인덱스 이탈 방지).

### 4-3. 시그널 (구현자가 노출할 것)

```gdscript
signal state_changed(previous: int, current: int)
signal dialogue_started(npc: NpcData)
signal dialogue_finished(npc: NpcData)
signal pass_action_resolved(npc_id: String, action_id: String, success: bool)
```

`pass_action_resolved`는 검증과 연출(브레이크 연출처럼 결과에 반응하는 이펙트)의 진입점이다.
결과 처리 로직 안에서 직접 이펙트를 재생하지 말고 이 시그널을 구독하게 한다.

---

## 5. 데이터 스키마

| 클래스 | 파일 | 역할 |
|---|---|---|
| `PassActionData` | `scripts/data/pass_action_data.gd` | 패스 액션 1종의 공용 규칙 |
| `NpcPassAction` | `scripts/data/npc_pass_action.gd` | NPC별 대사·보상 오버라이드 엔트리 |
| `NpcData` | `scripts/data/npc_data.gd` | NPC 1명의 데이터 |

### `PassActionData`

| 필드 | 타입 | 범위/기본 | 의미 |
|---|---|---|---|
| `action_id` | `String` | `""` | 내부 id (영소문자 snake_case) |
| `display_name` | `String` | `""` | UI 표시명 |
| `is_night` | `bool` | `false` | 밤 전용 여부. `DayNight.is_night`와 직접 비교 |
| `judge_kind` | `JudgeKind` | `ALWAYS` | `0=ALWAYS, 1=DIFFICULTY, 2=GOLD(M1 미사용), 3=FLAG, 4=LEVEL` |
| `difficulty_limit` | `int` | 0~5 | `DIFFICULTY` 판정 상한 (경계심) |
| `level_limit` | `int` | 0~99 | `LEVEL` 판정 상한 (실력) |
| `gold_cost` | `int` | 0~9999 | `GOLD` 판정 기준액이자 지불액 (M1 미사용) |
| `reward_gold` | `int` | 0~9999 | 성공 시 획득 골드(기본값). M1 데이터는 전부 0 |
| `required_flag` | `String` | `""` | `FLAG` 판정 대상. `{npc}` 치환 |
| `success_flag` | `String` | `""` | 성공 시 켤 플래그. `{npc}` 치환 |
| `failure_flag` | `String` | `""` | 실패 시 켤 플래그(영구 차단용) |
| `success_line` / `failure_line` | `String` | `""` | NPC가 고유 대사를 안 줄 때의 기본 문구 |
| `repeatable` | `bool` | `false` | 성공 후 재시도 허용 |

메서드: `static format_flag(template, npc_id) -> String`, `matches_phase(night_now) -> bool`

> `JudgeKind`의 순서를 바꾸면 `.tres`에 저장된 정수가 어긋난다. **뒤에만 추가**할 것.

### `NpcPassAction`

| 필드 | 타입 | 범위/기본 | 의미 |
|---|---|---|---|
| `action` | `PassActionData` | `null` | 참조할 공용 규칙 |
| `success_line` / `failure_line` | `String` | `""` | 비우면 `action` 쪽 문구로 폴백 |
| `override_reward_gold` | `int` | −1~9999 | −1이면 `action.reward_gold` 사용. M1 데이터는 전부 −1(규칙만 유지) |

메서드: `resolve_success_line()`, `resolve_failure_line()`, `resolve_reward_gold()`

### `NpcData`

| 필드 | 타입 | 범위/기본 | 의미 |
|---|---|---|---|
| `npc_id` | `String` | `""` | 플래그 키에 박히는 내부 id |
| `display_name` | `String` | `""` | 이름표 |
| `sprite` | `Texture2D` | `null` | 필드 `Sprite3D` 텍스처. 경로 문자열이 아니라 참조 |
| `difficulty` | `int` | 1~5 | 경계심. `DIFFICULTY` 판정과 `scrutinize` 결과 표시에 쓰인다 |
| `level` | `int` | 1~99 | 실력. `LEVEL` 판정(`challenge`)과 `scrutinize` 결과 표시에 쓰인다 |
| `day_lines` | `PackedStringArray` | `[]` | 낮 대사(1칸=1페이지) |
| `night_lines` | `PackedStringArray` | `[]` | 밤 대사. 비면 낮으로 폴백 |
| `pass_actions` | `Array[NpcPassAction]` | `[]` | 가능한 패스 액션 |

메서드: `lines_for(night_now) -> PackedStringArray`, `actions_for(night_now) -> Array[NpcPassAction]`,
`format_line(template) -> String` (§3-5의 토큰 치환)

---

## 6. 데이터 파일

| 경로 | 내용 |
|---|---|
| `data/pass_action/inquire.tres` | 정보수집 (낮, DIFFICULTY≤3, 재시도 가능) |
| `data/pass_action/challenge.tres` | 도전 (낮, LEVEL≤8, 1회성, M3 전투 훅) |
| `data/pass_action/allure.tres` | 유혹 (밤, FLAG `pa_inquire_{npc}`, 1회성) |
| `data/pass_action/scrutinize.tres` | 조사 (밤, DIFFICULTY≤3, 재시도 가능, 수치 공개) |
| `data/npc/npc_rine.tres` | 청과상 리네 — 난이도 2 / Lv3 / 낮: 정보수집 · 밤: 조사·유혹 (전부 성공) |
| `data/npc/npc_borden.tres` | 경비병 보든 — 난이도 4 / Lv12 / 낮: 정보수집·도전 · 밤: 조사·유혹 (전부 실패하는 벽) |
| `data/npc/npc_yuri.tres` | 떠돌이 악사 유리 — 난이도 3 / Lv7 / 낮: 정보수집·도전 · 밤: 조사·유혹 (경계값으로 전부 성공) |

리네에게 `challenge`를 주지 않은 이유: 청과상에게 결투를 신청하는 그림이 톤에 맞지 않는다.
"모든 NPC가 4종을 다 갖는다"는 규칙은 없다 — 목록은 NPC마다 다르고, 그래서 누구에게 뭘 걸지 고르는 재미가 생긴다.

**`.tres`는 손으로 쓰지 않고 엔진(`ResourceSaver`)으로 생성했다.** 직렬화 표기
(`Array[ExtResource("...")]([SubResource("...")])` 같은 타입 배열 형식)를 추측하면 조용히
빈 배열로 로드되기 때문이다. 앞으로 NPC를 추가할 때도 기존 `.tres`를 복사해 값만 바꾸는 방식을 권한다.

### 씬 배치 (구현자 참고, 이 문서에서는 변경하지 않음)

`Field.tscn`의 `Actors`에는 현재 `Player(0, 0.8, 0.6)`, `NpcA(-2.6, 0.8, -0.6)`, `NpcB(3, 0.8, 0.2)`가 있다.
- `NpcA` → `npc_rine.tres` (텍스처 `char_npc_a.png` 일치)
- `NpcB` → `npc_borden.tres` (텍스처 `char_npc_b.png` 일치)
- 세 번째 NPC(`npc_yuri.tres`, `char_crowd_03.png`)는 신규 노드. 플레이어 오른쪽 뒤 `(1.4, 0.8, -1.8)` 근처를 권한다
  (기존 두 NPC와 겹치지 않고, 상호작용 반경 1.2 m가 서로 물리지 않는 간격).

NPC 노드는 `Sprite3D`를 직접 두지 말고 `NpcData`를 `@export`로 받는 공용 씬(`FieldNpc.tscn`)으로
만들어 `sprite`·`display_name`을 데이터에서 주입하는 편이 좋다 — NPC 추가가 `.tres` 하나로 끝난다.

---

## 7. 검증 기준 (godot-validator용)

`tests/headless_m1_data.gd`가 이미 확인하는 것 (243 assert 통과):

- 패스 액션 4종(`inquire`/`challenge`/`allure`/`scrutinize`)이 로드되고 낮 2 / 밤 2로 갈린다
- 각 판정 파라미터가 기본값이 아니다 (`inquire.difficulty_limit == 3`, `challenge.level_limit == 8`,
  `allure.required_flag == "pa_inquire_{npc}"`, `scrutinize.difficulty_limit == 3`)
- 재시도 규칙이 데이터에 반영돼 있다 (`inquire`·`scrutinize` 가능 / `challenge`·`allure` 1회성)
- NPC 3명의 `npc_id`·`display_name`·`sprite`·`level`·대사 배열·`pass_actions`가 모두 실제 값이다
- 모든 패스 액션 엔트리가 현행 4종 중 하나를 물고 있고 성공/실패 대사를 해석할 수 있다
- 난이도 관계가 의도대로다 (리네·유리 정보수집 성공 / 보든 실패, 보든만 조사 실패)
- 레벨 관계가 의도대로다 (유리 Lv7 도전 성공 / 보든 Lv12 실패)
- 시간대 필터가 갈린다 (리네 낮1·밤2, 보든 낮2·밤2, 유리 낮2·밤2)
- 밤 대사 폴백이 동작한다
- `{name}`/`{level}`/`{difficulty}` 토큰이 실제 값으로 치환되고 미해결 토큰이 남지 않는다
- 보상 오버라이드 규칙이 살아 있고, 현행 데이터의 모든 액션은 `reward_gold == 0` / `gold_cost == 0`이다
- 플래그 템플릿 치환이 동작하고, `allure.required_flag == inquire.success_flag`다
- **구 액션 세트 `.tres`가 남아 있지 않다** (`purchase`/`steal`/`entice`, 디렉터리에 정확히 4개)
- **`.tres`에 스키마에 없는 키가 없다** (텍스트를 훑어 `[resource]`/`[sub_resource]` 섹션의 모든 키가
  실제 프로퍼티인지 확인. 오타 키를 넣으면 FAIL이 나는 것까지 변이 테스트로 확인함)

구현 후 추가로 검증해야 할 것 (다음 단계 담당):

| # | 판정 기준 | 방법 |
|---|---|---|
| V1 | `FREE`가 아닌 상태에서 이동 입력이 무시된다 | `InteractionController.state`를 강제 설정하고 플레이어 위치 변화가 0인지 |
| V2 | 대사 페이지가 배열 길이만큼 진행하고 마지막에서 종료된다 | `interact` N+1회 후 상태가 `FREE` 또는 `PASS_MENU` |
| V3 | 밤에는 밤 대사가 나온다 | `DayNight.set_night(true)` 후 첫 페이지 텍스트 == `night_lines[0]` |
| V4 | 목록에 현재 시간대 액션만 뜬다 | 리네 낮 1개 / 밤 2개 |
| V5 | `challenge` 성공 시 `pass_action_resolved("yuri", "challenge", true)`가 1회 발화한다 | 시그널 수집 후 개수·인자 확인 (M3 전투 훅의 진입점) |
| V6 | `challenge` 성공 후 그 NPC의 낮 목록에서 도전이 사라진다 (1회성) | 유리에게 실행 → 재진입 시 낮 목록 크기 1 |
| V7 | `allure`는 낮의 `inquire` 성공 없이는 실패한다 | `GameState.flags` 초기화 후 실행 → `success == false` |
| V8 | `toggle_phase`가 `TALKING` 중에는 무시된다 | 대화 중 입력 → `DayNight.is_night` 불변 |
| V9 | `scrutinize` 성공 대사에 실제 레벨이 찍힌다 | 유리에게 실행 → 결과 문자열에 `Lv.7` 포함, `{` 미포함 |

---

## 8. 다음 단계 인계

**godot-scene-builder에게**
- 새로 만들 것: `scripts/field/interaction_controller.gd`(상태 머신 소유), `scripts/field/field_player.gd`(이동),
  `scenes/field/FieldNpc.tscn`(+ `npc_data: NpcData` export), `scenes/ui/DialogueBox.tscn`, `scenes/ui/PassActionMenu.tscn`
- `project.godot`의 `[input]`은 §1-2 표 그대로. `ui_*` 기본 바인딩은 건드리지 말 것
- 타입 참조: `NpcData`, `NpcPassAction`, `PassActionData`. 판정 상수는 `PassActionData.JudgeKind`를 쓰고
  정수 리터럴(0~4)을 코드에 박지 말 것
- 결과 대사는 반드시 `npc.format_line()`을 거칠 것. 빠뜨리면 화면에 `{level}`이 그대로 찍힌다
- `challenge` 성공은 M3에서 전투로 이어진다. §3-4의 훅 위치를 지킬 것
- 새 `.gd`를 추가하면 `godot.sh import`를 먼저 돌려야 `class_name`이 전역 캐시에 등록된다

**hd2d-visual-tuner에게**
- 대화창이 열릴 때 DOF/비네팅을 건드릴지 여부는 미정. §4-3의 `dialogue_started` / `dialogue_finished`를
  구독해 조정할 수 있게 시그널을 열어 두었다
- 패스 액션 성공/실패 연출(성공 시 정보 공개 연출, 실패 시 화면 흔들림)은 `pass_action_resolved`를 구독한다.
  특히 `scrutinize` 성공은 "간파했다"는 감각이 필요한 순간이라 연출 여지를 남겨 둔다

**확정된 사항**
- `toggle_phase`(`N` 키 / 게임패드 Y)는 **개발 편의용으로 M1에 남긴다.** 낮/밤 분기를 확인하려고
  매번 여관까지 걸어가면 검증 루프가 느려진다. **M3 이후 여관 숙박으로 옮긴다.**
- **평판 시스템은 넣지 않는다.** 새 세트에는 절도가 없어 페널티를 걸 대상이 없다. `GameState`는 그대로 둔다.

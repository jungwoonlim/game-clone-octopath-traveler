# 검증 결과 — M1 필드 탐험 9단계 최종 (2026-09-11)

검증자: godot-validator / 대상: 설계 `_workspace/M1_design_field.md` §7 의 V1~V9 + 기본 4종 + 경계면 + 데이터
Godot: `/Applications/Godot.app/Contents/MacOS/Godot` (4.7, official)

---

## 1. 요약표

| 단계 | 결과 | 근거 |
|------|------|------|
| 임포트 | PASS | `godot.sh all` |
| 정적 파싱·타입 | PASS (20/20) | `godot.sh check` |
| 런타임 스모크 | PASS (7/7 씬) | main_scene + Field/FieldNpc/FieldPlayer/DialogueBox/PassActionMenu/TownSquare 개별 확인 |
| 동작 테스트 | PASS (4/4 파일, 총 312 assert) | day_night 6 / input_map 20 / m1_data 243 / m1_interaction **43** |
| 경계면 교차 | PASS | 씬↔스크립트 노드 경로 전수 대조 (§3) |
| 데이터 무결성 | PASS | `.tres` 스키마·참조 대조 (§4) |
| 실제 화면 | PASS (사실 판정 범위) | 스크린샷 9장 + 상태 추적 로그 (§5) |

**V1~V9 전 항목 실동작 확인 완료.** 다만 자동화 테스트의 **커버리지에 구멍이 4개** 있고
(§2), 하네스(`godot.sh shot`)에 **재현되는 결함 2건**이 있다(§6). 제품 코드의 결함은 발견하지 못했다.

### V1~V9 판정

| # | 헤드리스 테스트 | 실행 화면 | 종합 |
|---|---|---|---|
| V1 이동 잠금 | **PARTIAL** — `is_movement_locked()`만 확인, 플레이어 위치 미확인 | PASS (§5-C) | PASS |
| V2 페이지 진행·종료 | PASS (10 assert) | PASS | PASS |
| V3 밤 대사 | PASS (1 assert) | PASS (§5-B) | PASS |
| V4 시간대별 목록 | PASS (2 assert) | PASS (낮 정보수집·도전 / 밤 조사·유혹) | PASS |
| V5 `pass_action_resolved` 1회 | PASS (8 assert) | PASS (RESULT 진입 확인) | PASS |
| V6 1회성 액션 소멸 | PASS (2 assert) | 미촬영 | PASS |
| V7 `allure` 선행조건 | **WEAK** — 후반부 assert가 조건부라 조용히 통과 가능 | 미촬영 | PASS(단, §2-2) |
| V8 `toggle_phase` 가드 | PASS (2 assert) | 미촬영 | PASS |
| V9 `scrutinize` 토큰 | PASS (4 assert) | PASS (§5-D, `Lv.7 / 경계도 3`) | PASS |

---

## 2. 테스트가 V1~V9를 실제로 덮는가 — 코드 대조 결과

`tests/headless_m1_interaction.gd`를 줄 단위로 읽고 설계 §7의 판정 방법과 대조했다.
**보고된 46 assert는 실측 43개다** (`godot.sh test` 출력 기준). 차이는 조건부 assert 때문이다.

### 2-1. V1 — 설계가 요구한 것을 절반만 검증한다 (지적)

설계 §7 V1: *"`InteractionController.state`를 강제 설정하고 **플레이어 위치 변화가 0인지**"*

실제 테스트(`tests/headless_m1_interaction.gd:48-69`)는 `controller.state`를 강제 설정한 뒤
`controller.is_movement_locked()`의 반환값만 본다. **`FieldPlayer`를 한 번도 인스턴스화하지 않는다.**

따라서 아래 경로가 헤드리스에서 전혀 검증되지 않는다.

- `scenes/field/Field.tscn:886` `controller_path = NodePath("../../InteractionController")`
- `scripts/field/field_player.gd:54` `@onready var _controller ... get_node_or_null(controller_path)`
- `scripts/field/field_player.gd:75` `if not _is_movement_locked(): direction = _input_direction()`

`controller_path`를 비우거나 오타를 내면 `_controller`가 null이 되고 `_is_movement_locked()`가
**항상 false를 반환한다**(`field_player.gd:90-91`, 의도된 폴백). 즉 대화 중에도 걸어 다니게 되는데
**테스트는 전부 초록으로 통과한다.**

→ 이번에는 §5-C의 스크린샷 대조로 실제 잠금을 확인했으므로 최종 판정은 PASS다.
→ 권고: `_test_movement_lock()`에 `FieldPlayer.tscn`을 인스턴스화하고 `controller_path`를 물린 뒤
  `Input.action_press("move_left")` → `_physics_process` 몇 번 → `global_position` 불변을 단언하는
  케이스를 추가할 것. 담당: godot-scene-builder.

### 2-2. V7 — 조건부 assert라 시그널이 안 와도 통과한다 (지적)

`tests/headless_m1_interaction.gd:219-220`

```gdscript
	controller.handle_interact()
	if _resolved.size() == 1:
		_assert_eq(_resolved[0][2], true, "V7 정보수집 성공 후에는 유혹 성공")
```

앞의 전반부(206-209행)에는 `_assert_eq(_resolved.size(), 1, ...)`가 있는데 후반부에는 없다.
`pass_action_resolved`가 **0회 발화하면 블록 전체를 건너뛰고 실패 없이 끝난다.**
V7의 핵심("플래그를 켜면 성공으로 뒤집힌다")이 조용히 사라질 수 있는 구멍이다.
→ 219행 앞에 `_assert_eq(_resolved.size(), 1, "V7 두 번째 시도도 결과 시그널 1회")`를 추가할 것.

### 2-3. 입력 경로(`_unhandled_input`)를 타는 테스트가 하나도 없다 (지적)

모든 테스트가 `controller.handle_interact()` / `handle_cancel()` / `handle_menu()`를 **직접 호출**한다.
`scripts/field/interaction_controller.gd:98-117`의 `_unhandled_input`은 헤드리스에서 0회 실행된다.
같은 이유로 `_update_candidate()`(268-284행, Area3D 겹침 기반 대상 탐지)도 미검증이다.

즉 **"말을 걸 수 있다"는 것 자체가 자동 테스트에 없다.** InputMap 액션명을 하나 바꿔도,
`FieldNpc.tscn`의 `InteractZone`을 지워도 43 assert는 전부 통과한다.
→ 이번에는 §5의 실행 캡처로 커버했다. 회귀 방지를 원하면 `Field.tscn`을 띄우고
  `Input.parse_input_event(InputEventAction)`를 쏘는 통합 테스트 1개면 충분하다
  (검증 중 실제로 작성해 동작을 확인했다 — §5-A의 추적 로그가 그 결과다).

### 2-4. 설계 §4-2 전이표 중 미검증 칸 (지적, 경미)

| 전이 | 설계 위치 | 테스트 |
|---|---|---|
| `TALKING`에서 `cancel` → `FREE` | §2-2 "어느 페이지에서든 즉시 종료" | 없음 (`PASS_MENU`에서만 확인) |
| `RESULT`에서 `cancel` → `FREE` | §4-2 | 없음 (`interact`만 확인) |
| `TALKING`/`PASS_MENU`/`RESULT`에서 `menu` 무시 | §4-2 | 없음 |
| `FREE`에서 `cancel` 무시 | §4-2 | 없음 |
| `PASS_MENU`/`RESULT`에서 `toggle_phase` 무시 | §4-2 | 없음 (V8은 `TALKING`만) |

구현(`interaction_controller.gd:159-185`)은 다섯 칸 모두 설계대로다. 코드를 읽어 확인했고 결함은 없다.
테스트가 없다는 사실만 기록한다.

### 2-5. `headless_m1_data.gd`의 `.tres` 키 파서가 취약하다 (지적, 경미)

`tests/headless_m1_data.gd:250-268`은 `.tres`를 줄 단위로 훑어 `" = "`가 있으면 키로 본다.
그런데 `data/npc/npc_rine.tres:18`, `npc_yuri.tres:24`의 `success_line`은 **여러 줄에 걸친 문자열**이다.
지금은 이어지는 줄에 `" = "`가 없어 우연히 통과하지만, 대사에 `" = "`가 들어가는 순간
**존재하지 않는 키를 신고하는 오탐**이 난다. 데이터가 늘기 전에 파서를 고치는 편이 싸다.

---

## 3. 경계면 교차 검증 (PASS)

이번 작업에서 노드 경로가 여러 번 옮겨졌으므로 `.tscn`의 실제 트리와 `.gd`의 참조를 전수 대조했다.

| 스크립트 참조 | 씬의 실제 노드 | 결과 |
|---|---|---|
| `dialogue_box.gd:26` `$Root` | `DialogueBox.tscn:89` `Root` | OK |
| `dialogue_box.gd:27` `$Root/Panel` | `:97` `Root/Panel` | OK |
| `dialogue_box.gd:28` `$Root/Panel/NamePlate/NameLabel` | `:120` `NamePlate` + `:128` `NameLabel` | **OK (경로 이동분 반영됨)** |
| `dialogue_box.gd:29` `$Root/Panel/TextLabel` | `:137` | OK |
| `dialogue_box.gd:30` `$Root/Panel/Prompt` | `:151` | OK |
| `pass_action_menu.gd:44-46` `$Root`, `$Root/Panel`, `$Root/Panel/Items` | `PassActionMenu.tscn:50/59/101` | OK |
| `field_npc.gd:16-17` `$Sprite3D`, `$Marker` | `FieldNpc.tscn:20/44` | OK |
| `field_player.gd:52` `$Sprite3D` | `FieldPlayer.tscn:19` | OK |
| `interaction_controller.gd:41` `interact_area_name = "InteractArea"` | `FieldPlayer.tscn:36` `InteractArea` | OK |
| `field.gd:41-47` `$Sun`,`$WorldEnvironment`,`$Lanterns` | `Field.tscn:264/143/622` | OK |
| `main.gd:6` `$SceneContainer` | `Main.tscn:8` | OK |
| `Field.tscn:885` `camera_path="../../FieldCamera"` | `Field.tscn:145` `FieldCamera` | OK |
| `Field.tscn:886` `controller_path="../../InteractionController"` | `Field.tscn:906` | OK |
| `Field.tscn:908` `player_path="../Actors/Player"` | `Field.tscn:883` | OK |
| `Field.tscn:152` `target_path="../Actors/Player"` | 동상 | OK |
| autoload `GameState`/`DayNight` (`interaction_controller.gd:74,76`) | `project.godot:15,17` | OK (대소문자 일치) |
| `PassActionMenu.tscn:48` `item_font` export | `pass_action_menu.gd:42` `@export var item_font` | OK |
| `FieldNpc.tscn` `npc_data` export | `field_npc.gd:14` | OK |

부수 확인:
- `ext_resource` id 중복 없음, `load_steps` 값 정확 (DialogueBox 7, PassActionMenu 6, FieldNpc 5, FieldPlayer 5)
- 입력 전파 순서: `InteractionController`가 `Field`(root, `field.gd`)보다 트리 아래라 `toggle_phase`를
  먼저 소비한다 → 설계 §2-3의 "대화 중 시간대 고정"이 `field.gd` 수정 없이 성립. 실동작으로도 확인.
- 감지 반경: 플레이어 `SphereShape3D` 1.2m + NPC `InteractZone` 0.4m = 실효 1.6m.
  설계 §2-1(1.2m, 플레이어 쪽)과 인계 문서(1.6m, 실효)가 모두 만족된다. 씬 주석에 근거가 남아 있다.
- `assets/placeholder/interact_marker.png`는 인계 시점 "어느 씬에도 안 붙어 있음"이었으나
  지금은 `FieldNpc.tscn:44 Marker`에 연결되어 화면에 표시된다(§5-C 확대 캡처로 확인).

---

## 4. 데이터 무결성 (PASS)

- `.tres`에 스키마에 없는 키가 있는지는 `tests/headless_m1_data.gd:236` `_test_unknown_keys()`가
  `data/pass_action/*.tres` 4개와 `data/npc/*.tres` 3개 전부에 대해 확인한다(243 assert 중 포함).
  **범위가 겹치므로 별도 검증은 하지 않았다.** 다만 파서 취약점은 §2-5 참조.
- `sprite` 참조를 직접 대조했다 — 셋 다 인계 문서가 지시한 `_sheet` 파일을 가리키고 실제로 존재한다.

  | `.tres` | `sprite` | 파일 |
  |---|---|---|
  | `npc_rine.tres:8` | `char_npc_a_sheet.png` | 존재 |
  | `npc_borden.tres:9` | `char_npc_b_sheet.png` | 존재 |
  | `npc_yuri.tres:9` | `char_npc_c_sheet.png` | 존재 |

- 패스 액션 4종의 판정 파라미터가 설계 §3-1 표와 완전히 일치한다
  (`inquire` judge 1/limit 3/repeatable, `challenge` judge 4/limit 8, `allure` judge 3/`pa_inquire_{npc}`,
  `scrutinize` judge 1/limit 3/repeatable). `gold_cost`/`reward_gold`는 전부 미기재 = 0.
- NPC 수치도 일치 (rine 2/3, borden 4/12, yuri 3/7).

---

## 5. 실제 화면 검증 (직접 촬영)

`godot.sh shot`으로 **새로 촬영**했다. 구현자가 남긴 `_screenshots/ui_*.png`는 사용하지 않았다.
좌표 `pose=1.4,-0.8`(떠돌이 악사 유리 옆)을 기준으로 잡았다.

### A. 낮 대화 시작 → 페이지 진행 → 패스 액션 목록 → 결과 대사

| 화면 | 파일 | 확인한 사실 |
|---|---|---|
| 대화 1페이지 | `_screenshots/v_day_p1.png` | 이름표 `떠돌이 악사 유리`, 본문 `동전은 됐어요…` 정상 |
| 대화 2페이지 | `_screenshots/v_day_p2.png` | `세 마을 건너에서…`로 넘어감 |
| 패스 액션 목록(낮) | `_screenshots/v_day_menu5.png`, `v_day_result.png` | `패스 액션 / ▶정보수집 / 도전` 2항목, 우상단, 화면 안 |
| 결과 대사(낮·정보수집 성공) | `_screenshots/v_day_result2.png` | 목록이 닫히고 결과 대사가 같은 창에 표시됨 |

상태 추적(임시 프로브 노드로 실행 중 수집, 검증 후 삭제):

```
state=1 page=0/2 → state=1 page=1/2 → state=2(PASS_MENU) items=2 → state=3(RESULT) page=0/1
```

### B. 밤 대사 · 밤 패스 액션 목록

| 화면 | 파일 | 확인한 사실 |
|---|---|---|
| 밤 대화 + 목록 | `_screenshots/v_night_menu.png` | 본문이 `등불 아래에서만 들리는 이야기가 있죠…`(= `night_lines[1]`) → **밤 대사 사용 확인** |
| 밤 목록 | 동상 | `▶조사 / 유혹` — 낮(`정보수집/도전`)과 **항목이 다름** |

### C. 대화 중 이동 입력 무시 (V1 실동작)

동일 `pose`에서 `hold:move_left:80`을 준 두 화면을 대조했다.

| 조건 | 파일 | 결과 |
|---|---|---|
| 대화 없음(FREE) | `_screenshots/v_move_free.png` | 플레이어가 서쪽으로 **약 3.6m 이동**, 카메라도 따라감. 근처 NPC 머리 위에 상호작용 마커(`!`) 점등 — 확대본 `v_zoom_move.png` |
| 대화 중(TALKING) | `_screenshots/v_move_locked.png` | 구도가 `v_day_p1.png`과 **완전히 동일**. 1px도 움직이지 않음 |

### D. 한글 렌더링 · 레이아웃 사실 판정

- 한글이 `□`로 깨진 곳 없음. 대화 본문(13px)·이름표(12px)·목록 제목/항목 전부 판독 가능.
  `SystemFont`(Apple SD Gothic Neo)가 실제로 잡혔다.
- 대화창이 비네팅에 눌리지 않음 — 대화창/목록은 `layer=20`, `PostFX` 비네팅은 `layer=10`.
  캡처에서 패널 네 모서리가 균일하다.
- 요소 겹침/화면 이탈 없음. 640×360 좌표계 기준 목록 패널 `y 157~236`, 이름표 윗변 `y 246`으로
  10px 여유가 실제로 유지된다. 대화창 `y 266~348`(하단 여백 12px), 잘림 없음.
- 토큰 치환이 화면에서도 동작 — `_screenshots/v_night_result.png`에
  `떠돌이 악사 유리 — Lv.7 / 경계도 3` (V9). `{` 잔존 없음. 2줄 대사가 패널 안에 들어간다.

---

## 6. FAIL / 결함 상세

제품 코드 결함은 **0건**이다. 아래 2건은 **하네스(`godot.sh shot` / `tools/capture_screenshot.gd`)** 결함이다.
검증 시간을 크게 잡아먹었고, 다음 사람이 같은 함정에 빠지면 **제품 결함으로 오판할 수 있다.**

### 결함 1 (중대) — `shot`이 30~40% 확률로 매달린다. 게임은 멀쩡히 돌고 있다

**증상:** 타임라인이 전부 재생되고(`입력: …` 로그가 끝까지 찍힘) 나서 저장이 되지 않고
`SHOT_TIMEOUT`까지 매달린다. 이번 검증에서 **총 16회 실행 중 6회** 발생했다(180/240/300초 모두).

**게임이 멈춘 것이 아니다.** 프로브로 하트비트를 찍어 확인했다 — 매달리는 동안에도
게임 루프는 f21600까지 약 **120fps로 정상 진행**했다.

```
PROBE heartbeat f21480 t=183092
PROBE heartbeat f21540 t=183608     ← 60프레임 / 0.5초. 살아 있다
✗ FAIL — shot (180초를 넘겨 중단했다)
```

**원인 추정 위치:** `tools/capture_screenshot.gd:102` `await RenderingServer.frame_post_draw`.
타임라인 재생은 끝났는데 이 await가 깨어나지 못한다. 렌더는 돌고 있으므로
커스텀 MainLoop 코루틴에서 `frame_post_draw`를 기다리는 방식 자체를 의심해야 한다.

**재현:**
```bash
SHOT_TIMEOUT=180 bash .claude/skills/godot-run/scripts/godot.sh shot \
  _screenshots/x.png true "press:interact;press:interact;wait:30;press:interact;press:interact;wait:30;press:interact;press:interact;wait:90" "1.4,-0.8"
# 여러 번 돌리면 일부가 CAPTURE OK 없이 타임아웃된다
```

**권고:** `frame_post_draw`를 무한정 기다리지 말고 N프레임 워치독을 두고,
깨어나지 못하면 `await process_frame` 뒤 강제로 읽어 저장한 다음 경고를 남길 것. 담당: 하네스 소유자.

### 결함 2 (중대) — `wait:<프레임>`으로는 타이핑 연출과 동기화할 수 없다. "기능이 고장난 화면"이 찍힌다

**증상:** 아래 명령은 패스 액션 목록이 떠 있어야 정상인데, **대화 2페이지에서 멈춘 화면**이
`✓ PASS — shot`으로 저장된다. 2회 재현했다(`_screenshots/v_day_menu.png`, `v_day_menu2.png`).

```bash
bash .claude/skills/godot-run/scripts/godot.sh shot _screenshots/x.png false \
  "press:interact;wait:150;press:interact;wait:150;press:interact;wait:40" "1.4,-0.8"
```

**원인:** 대화창 타이핑은 **벽시계 기준 30자/초**(`scripts/ui/dialogue_box.gd:13,56`)인데
`wait:N`은 **프레임 수**다. 창 모드 fps가 실측 **72~120fps로 40% 이상 흔들려**
`wait:150`이 어떤 실행에서는 2.1초, 어떤 실행에서는 1.25초가 된다. 타이핑이 덜 끝난 상태에서
`interact`가 들어가면 페이지가 넘어가는 대신 **현재 페이지를 즉시 완성**할 뿐이다(설계 §2-2, 정상 동작).
그래서 같은 명령이 실행마다 페이지 1~2개씩 어긋난다.

실측 추적 로그 (프로브):
```
PROBE @f47  state=1 page=0/2 typing=true      ← press #1: 대화 시작
PROBE @f51  state=1 page=0/2 typing=false     ← press #2: 타이핑 완성(페이지 안 넘어감)
PROBE @f85  state=1 page=1/2 typing=true      ← press #3: 2페이지
PROBE @f89  state=1 page=1/2 typing=false     ← press #4: 타이핑 완성
PROBE @f123 state=2(PASS_MENU) items=2        ← press #5: 목록
PROBE @f127 state=3(RESULT)                   ← press #6: 결과
```

**이것은 인계 문서 §3이 `hold:`에 대해 경고한 것과 같은 종류의 함정이 `wait:`에도 있다는 뜻이다.**
인계 문서는 "구도는 `pose`로"라고만 적었고 "연출 대기는 프레임으로 하지 말라"는 없다.

**권고 (둘 중 하나):**
1. `tools/capture_screenshot.gd`에 `waitms:<밀리초>` 단계를 추가한다(`await create_timer(...).timeout`).
2. 타임라인에서 페이지를 넘길 때는 `wait` 대신 **`press`를 페이지당 2회 연속**으로 준다.
   3프레임 간격의 연속 `press`가 "완성 → 넘김"으로 확실히 동작하는 것을 확인했다(위 로그 f47~f51).
   이 방식으로 찍은 것이 §5의 최종 캡처들이다.

→ 담당: 하네스 소유자. 최소한 `godot-run` 스킬 문서에 2번을 관용구로 박아 둘 것.

### 경미 — 문서/주석 불일치 1건

`scripts/data/npc_data.gd:21` 주석: *"표시용 레벨. **M1에서는 판정에 쓰지 않고** 대화창 정보 표시에만 쓴다"*
→ 설계 §3-1과 실제 구현(`pass_action_judge.gd:69` `JudgeKind.LEVEL` → `npc.level <= action.level_limit`)에서
`challenge` 판정에 **쓰고 있다.** 주석만 낡았다. 동작에는 영향 없음.

### 경미 — `_screenshots/`에 `.gdignore`가 없다

`.gitignore`에는 빠져 있지만 Godot은 `_screenshots/*.png`를 전부 임포트한다(`.png.import` 생성 확인).
검증 캡처가 쌓일수록 `godot.sh import`가 느려지고 `.godot/imported`가 커진다.
`_screenshots/.gdignore` 빈 파일 하나면 끝난다.

---

## 7. 검증하지 못한 것

- **비주얼의 미적 판단** — "룩이 좋은가", 대화창 색·투명도·테두리·등장 연출의 적절성,
  전경 프레이밍 강도(인계 §5-1의 미결 사항). **사용자 눈 확인 필요.**
- **타이핑 연출·프롬프트 깜빡임·창 등장 연출의 움직임** — 정지 캡처로는 확인할 수 없다.
  코드상 존재는 확인했다(`dialogue_box.gd:168-200`). **`godot.sh run`으로 사용자 눈 확인 필요.**
- **게임패드 입력** — `project.godot`의 버튼 인덱스 등록만 확인했다(테스트 20 assert).
  실제 패드로 눌러본 것은 아니다. 실기 확인 필요.
- **성능(fps)** — 이번 검증 범위가 아니라 `bench`를 돌리지 않았다.
  다만 캡처 중 하트비트로 **낮 필드 약 120fps**를 관측했다(참고값, 정식 측정 아님).
  인계 §7의 경고대로 `bench` 수치 자체가 40% 흔들리므로 신뢰하지 말 것.
- **V6·V7·V8의 실행 화면** — 헤드리스 assert로만 확인했다(전부 통과). 화면은 찍지 않았다.
- **`SYSTEM_MENU`** — M1에 UI가 없다는 것이 확정 사항이므로 상태 전이만 확인했다.
- **밤 결과 대사의 실패 케이스**(보든) — 리네/유리만 촬영했다.

---

## 8. 이번 검증에서 촬영한 스크린샷

모두 `/Users/jungwoon/programming/nimbus/game/game-clone-octopath-traveler/_screenshots/` 아래.
(`_screenshots/`는 gitignore 대상이다.)

| 파일 | 내용 |
|---|---|
| `v_day_p1.png` | 낮 대화 1페이지 |
| `v_day_p2.png` | 낮 대화 2페이지 |
| `v_day_menu5.png` | 낮 패스 액션 목록 (정보수집·도전) |
| `v_day_result.png` | 낮 목록 (4프레스 변형) |
| `v_day_result2.png` | 낮 정보수집 성공 결과 대사 |
| `v_night_menu.png` | 밤 대화 + 밤 목록 (조사·유혹) |
| `v_night_result.png` | 밤 조사 성공 — `Lv.7 / 경계도 3` (V9) |
| `v_move_free.png` | FREE 상태에서 서쪽 이동 (약 3.6m) |
| `v_move_locked.png` | TALKING 상태에서 같은 입력 — 이동 없음 (V1) |
| `v_zoom_move.png` | 상호작용 마커 확대 |
| `v_day_menu.png`, `v_day_menu2.png` | **결함 2의 증거** — 목록이 떠야 하는데 안 뜬 화면이 PASS로 저장됨 |
| `v_zoom_menu.png`, `v_zoom_p2.png` | 위 두 장의 우상단 확대 (목록 부재 확인) |

---

## 9. 담당별 조치 요청

**godot-scene-builder (테스트 커버리지)**
1. V1에 `FieldPlayer` 실물을 물린 위치 불변 케이스 추가 (§2-1)
2. `headless_m1_interaction.gd:219` 앞에 `_resolved.size()` 단언 추가 (§2-2)
3. (선택) `_unhandled_input` + `_update_candidate`를 타는 통합 테스트 1개 (§2-3)
4. (선택) 설계 §4-2 미검증 5칸 보강 (§2-4)
5. `npc_data.gd:21` 주석 수정 (§6 경미)

**하네스 소유자**
1. `capture_screenshot.gd:102` `frame_post_draw` 워치독 (§6 결함 1) — **가장 시급**
2. `waitms:` 단계 추가 또는 스킬 문서에 "페이지당 press 2회" 관용구 명시 (§6 결함 2)
3. `_screenshots/.gdignore` 추가 (§6 경미)
4. `headless_m1_data.gd`의 `.tres` 키 파서에 멀티라인 문자열 처리 (§2-5)

**사용자**
- §7의 눈 확인 항목 (`godot.sh run 15`)

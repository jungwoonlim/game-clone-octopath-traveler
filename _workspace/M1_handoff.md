# M1 인계 — 2026-09-10 중단 시점

> **[2026-09-11 종료] 이 문서는 기록용이다. 아래 "남은 것"은 전부 완료됐다.**
> 6~9단계가 구현·검증까지 끝났고 결과는 `M1_validation_field.md`에 있다.
> 이 문서를 보고 작업을 시작하지 말 것 — §3의 제약(UI 좌표계 640×360, 대화창의
> 조용한 실패 3종, `.tres` 손편집 금지, 카메라 클램프)만 여전히 유효하다.

M1(필드 탐험) 9단계 중 **5단계 완료, 6~9단계 남음.** 저장소는 `godot.sh all` 전체 통과 상태다.
**모든 작업이 커밋되지 않았다** (마지막 커밋은 `7494fde`, M2 작업).

---

## 1. 완료된 것

| # | 단계 | 산출물 |
|---|------|--------|
| 1 | 데이터 스키마·패스 액션 설계 | `_workspace/M1_design_field.md`, `scripts/data/*.gd`, `data/**` |
| 2 | 입력 맵 | `project.godot` `[input]`, `tests/headless_input_map.gd` |
| 3 | 4방향 걷기 시트 | `assets/placeholder/char_*_sheet.png`, `tools/gen_sheet_preview.gd` |
| 4 | 플레이어 이동·충돌·추적 카메라 | `scenes/field/FieldPlayer.tscn`, `scripts/field/field_player.gd`, `field_camera.gd` |
| 5 | 전경 프레이밍 재배치 + DOF | `scenes/field/Field.tscn` (`FieldCamera/CameraFrame` 신규) |

하네스도 함께 손봤다 (`CLAUDE.md` 변경 이력에 기록됨):
- `godot.sh shot`에 **입력 타임라인** 추가 — 조작 후 화면을 찍을 수 있다
- `godot.sh shot`에 **`pose` 모드** 추가 — 좌표로 구도를 지정한다

---

## 2. 남은 것 — 6~9단계

### 6·7·8은 하나의 상태 머신을 공유하므로 **나누지 말고 한 번에** 구현한다

설계 문서 `_workspace/M1_design_field.md` §4의 전이표가 세 기능(상호작용·대화·메뉴)에
걸쳐 있다. 따로 만들면 반드시 갈아엎게 된다.

| # | 단계 | 핵심 |
|---|------|------|
| 6 | NPC 상호작용 | `FieldNpc.tscn` (StaticBody3D + Area3D 1.6m), 가장 가까운 하나만 표시 |
| 7 | 대화창 UI | `CanvasLayer layer=20`, `SystemFont`, 타이핑 효과 |
| 8 | 패스 액션 메뉴 | 낮/밤 분기, `PassActionJudge` 사용 |
| 9 | 최종 검증 | `godot-validator` 호출, 설계 §7의 V1~V9 |

### 이미 만들어져 있으나 **검증되지 않은** 것 (중단 직전 착수분)

⚠️ **아래 두 개는 아무도 리뷰하지 않았고, 어디서도 호출되지 않으며, 테스트가 없다.**
그대로 믿지 말고 설계 문서와 대조한 뒤 쓸지 결정하라.

- `scripts/field/pass_action_judge.gd` (`class_name PassActionJudge`, 105줄)
  - 설계 §3-2의 판정 순서를 `RefCounted` static 함수로 뽑은 것. `GameState`를 인자로 주입받아
    헤드리스 테스트가 가능한 구조다 — 의도는 맞다
  - `godot.sh check`는 통과한다(문법·타입만 본다). **동작은 미검증**
- `assets/placeholder/interact_marker.png` + `tools/gen_placeholder_textures.gd`의
  `_make_interact_marker()` (842행, 호출은 102행)
  - 상호작용 표시용 텍스처. 임포트까지 됐지만 **어느 씬에도 붙어 있지 않다**

---

## 3. 다음 세션이 반드시 알아야 할 제약

### UI 좌표계는 640×360이다 (가장 위험)

`project.godot`이 `viewport_width=640 / height=360`, `stretch/mode="viewport"`다.
1280×720 창에 2배 확대되지만 **UI를 짤 때 쓰는 좌표는 640×360**이다.
1280 기준으로 만들면 화면 밖으로 나가거나 글자가 거대해진다.

### 대화창은 세 가지가 **조용히** 실패한다

| 실패 | 증상 | 대책 |
|---|---|---|
| 폰트 미지정 | 한글이 □로 나온다 | `SystemFont` + `font_names = PackedStringArray("Apple SD Gothic Neo")`. 폰트 파일 불필요 |
| 레이어 | 대화창 모서리가 어둡다 | `Field.tscn`의 `PostFX` 비네팅이 `layer=10`. 대화창은 `layer=20` |
| 좌표계 | 화면 밖으로 나간다 | 위 640×360 |

### `data/npc/*.tres`는 `ResourceSaver`로 생성됐다

`pass_actions = Array[ExtResource(...)]([SubResource(...)])` 같은 타입 배열 직렬화가 들어 있다.
그 줄을 손으로 고치면 **에러 없이 조용히 빈 배열로 로드된다.**
`tests/headless_m1_data.gd`가 이 함정의 안전망이므로, `.tres`를 만졌으면 반드시 `godot.sh test`.

**NPC 텍스처를 시트로 바꿔야 한다** — `sprite`의 `path=` **한 줄만** 고칠 것:

| NPC | 현재 | 바꿀 것 |
|---|---|---|
| `npc_rine` | `char_npc_a.png` | `char_npc_a_sheet.png` |
| `npc_borden` | `char_npc_b.png` | `char_npc_b_sheet.png` |
| `npc_yuri` | `char_crowd_03.png` | `char_npc_c_sheet.png` |

### 카메라 클램프는 DOF에 묶여 있다

`field_camera.gd`의 `limit_x ±5`, `limit_z 16.0~19.5`는 구도용이 아니라
**플레이어가 DOF 선명 구간(near 16 / far 28)을 벗어나지 않게** 계산된 값이다.
카메라 오프셋이나 플레이 영역을 바꾸면 이 계산을 다시 해야 한다. 근거는 스크립트 주석에 있다.

### 전경 프레이밍은 카메라의 자식이다

`FieldCamera/CameraFrame`. 추적 카메라가 x로 ±5 움직이면 월드 고정 전경은
"중앙에서 가장자리 / 끝에서 화면 밖"을 **기하학적으로 동시에 만족할 수 없다**
(깊이 14m에서 화면 반폭 6.94m뿐이라 카메라 이동량이 화면 폭의 72%를 훑는다).
프레임 조각은 플레이어가 절대 침범하지 않는 화면 영역(`|x|>0.75`, `y<-0.72`, `y>+0.28`)에만 있다.

### 스프라이트 시트 파일명

`char_player.png` / `char_npc_a.png` / `char_npc_b.png`는 `TownSquare.tscn`이
`hframes=1`로 쓰고 있다. **덮어쓰면 TownSquare에 16명 격자가 그려진다.**
시트는 `_sheet` 접미사가 붙은 별도 파일이다.

### 스크린샷은 프레임 수가 아니라 좌표로 찍는다

창 모드 fps가 크게 흔들려(macOS App Nap 추정) `hold:move_left:90`의 이동량이 매번 다르다.
한 실행이 20분 넘게 걸린 적도 있다. 구도 검증은 `pose`를 쓸 것:

```bash
S=.claude/skills/godot-run/scripts/godot.sh
bash $S shot _screenshots/x.png false "" "-9.7,0.6"                    # 좌표로 세우기
bash $S shot _screenshots/y.png false "press:interact;wait:60" "0,0.6" # 세운 뒤 조작
bash $S shot _screenshots/z.png true  "press:interact;wait:60" "0,0.6" # 밤
```

`pose`는 `field_camera.gd`의 `follow_offset`/`limit_x`/`limit_z`를 읽어 카메라를 같은 규칙으로
즉시 붙인다. 그 프로퍼티 이름을 바꾸면 `capture_screenshot.gd`의 `CAM_PROPS`도 함께 고칠 것.

---

## 4. 확정된 설계 결정 (다시 논의하지 말 것)

- **패스 액션 4종**: `inquire` 정보수집(낮) / `challenge` 도전(낮) / `allure` 유혹(밤) /
  `scrutinize` 조사(밤). 난수 없는 결정론적 판정 — 헤드리스에서 규칙과 운이 구분돼야 한다
- **NPC 3명**: `rine`(난이도2/Lv3, 전부 성공) / `borden`(4/Lv12, 전부 실패하는 벽) /
  `yuri`(3/Lv7, 경계값 성공). 세 결과를 모두 관찰할 수 있는 배치다
- **`allure`는 `pa_inquire_{npc}` 플래그를 요구한다** — 낮↔밤을 잇는 유일한 장치
- **`JudgeKind.GOLD`는 M1 미사용이지만 남긴다.** enum 중간 값을 지우면 뒤 값이 앞당겨져
  기존 `.tres`의 정수가 다른 판정으로 조용히 해석된다. `LEVEL`을 끝에 붙인 것도 같은 이유
- **입력은 커스텀 액션, UI는 `ui_*`로 분리.** 섞으면 "대사 넘김 + 버튼 눌림" 이중 반응이 난다
- **`toggle_phase`(N키)는 개발 편의용으로 유지.** M3 이후 여관 숙박으로 옮긴다
- **평판 시스템 미도입**, `GameState` 무수정
- **`SYSTEM_MENU`는 상태와 전이만.** M1에 메뉴 UI는 만들지 않는다
- **M3 전투 훅**: `pass_action_resolved` 시그널 구독 쪽에 `action_id == "challenge" and success`
  분기를 추가한다. 결과 처리 함수 안에서 직접 씬 전환하지 말 것 (설계 §3-4)

---

## 5. 사용자 판단이 필요한 미결 사항

1. **전경 프레이밍 강도** — 카메라 자식으로 옮기면서 가림은 0이 됐지만 프레이밍이 이전보다
   **약해졌다.** `_screenshots/m1_before.png`(이전)와 `_screenshots/m2b_center.png`(현재)를
   비교하면 좌우 나무와 하단 덤불 덩어리가 얇아졌다. 조각을 키우면 되돌릴 수 있다
   (안전 영역 `|x|>0.75`, `y<-0.72`, `y>+0.28` 안에서)
2. **연못 통행** — 지금은 걸어서 지나갈 수 있다. 두께 0.1m 판이라 막으면 물 위를 걷는 그림이
   되고, 연못이 플레이 영역 남동쪽의 상당 부분을 차지해 동쪽 통행이 답답해진다.
   막으려면 `Bounds`에 박스 하나 추가
3. **낮은 소품의 하반신 가림** — `Props`의 부시·울타리(1.34m) 뒤에 서면 하반신이 최대 60%
   가려진다. 원작에도 있는 정상 동작이라 손대지 않았다
4. **커밋 분할** — 아래 5절 참고
5. **브랜치** — 지금 `master`에 체크아웃돼 있다. 세션 시작 시 말한 `feat/hd2d-harness-and-town`은
   오히려 8커밋 **뒤처진** 상태이고, M2 작업 전부가 master에 있다. `origin/master`는
   initial commit 하나뿐. M1용 브랜치를 팔지 결정이 필요하다

---

## 6. 커밋 제안 (아직 하나도 커밋되지 않았다)

논리 단위로 나누고 본문에 **왜 그렇게 했는지**를 남길 것.

1. **하네스: 스크린샷에 입력 타임라인과 `pose` 모드 추가**
   `tools/capture_screenshot.gd`, `.claude/skills/godot-run/**`, `CLAUDE.md`
   → 왜: 정지 화면만 찍을 수 있어 이동·대화창·메뉴를 검증할 수단이 없었고,
   프레임 수 기반 이동은 창 모드 fps가 흔들려 재현되지 않았다
2. **M1 데이터 스키마와 패스 액션 4종**
   `scripts/data/**`, `data/**`, `tests/headless_m1_data.gd`, `_workspace/M1_design_field.md`
   → 왜: 스키마 없이 구현하면 나중에 전부 갈아엎게 된다. `.tres` 필드명 오타가 조용히
   기본값으로 로드되는 함정이 있어 로딩 검증 테스트를 함께 둔다
3. **입력 맵 정의**
   `project.godot`, `tests/headless_input_map.gd`, `scripts/field/field.gd`(N키 → 액션)
   → 왜: `[input]` 섹션은 직렬화 문자열이라 한 글자만 틀려도 그 액션만 조용히 사라진다
4. **4방향 걷기 스프라이트 시트**
   `tools/gen_placeholder_textures.gd`, `tools/gen_sheet_preview.gd`, `assets/placeholder/char_*_sheet.png`
   → 왜: 기존 파일명을 덮어쓰면 TownSquare가 깨지므로 별도 파일로 만들었다
5. **플레이어 8방향 이동·충돌·추적 카메라**
   `scenes/field/FieldPlayer.tscn`, `scripts/field/field_player.gd`, `field_camera.gd`, `Field.tscn`
   → 왜: 카메라 클램프는 구도가 아니라 DOF 선명 구간을 지키기 위한 값이다
6. **전경 프레이밍을 카메라 자식으로 이동**
   `Field.tscn`
   → 왜: 추적 카메라와 월드 고정 전경은 기하학적으로 양립할 수 없다

`scripts/field/pass_action_judge.gd`와 `interact_marker.png`는 **미검증 Stage 3 착수분**이므로
6·7·8 구현과 함께 커밋하는 편이 낫다.

---

## 7. 검증 명령

```bash
bash .claude/skills/godot-run/scripts/godot.sh all     # 임포트 → 파싱 → 스모크 → 테스트
bash .claude/skills/godot-run/scripts/godot.sh run 15  # 창 모드 (사람 눈 확인)
```

**`godot.sh bench`의 성능 수치는 신뢰하지 말 것.** 동일 씬 3회 측정에 52.6/68.4/75.0으로
40% 넘게 흔들린다. 성능이 실제 문제로 보이면 측정 도구부터 고쳐야 한다
(vsync 끄기, 프레임 델타 직접 측정, 중앙값).

현재 테스트 3종: `headless_day_night.gd`, `headless_input_map.gd`, `headless_m1_data.gd`.
6~8 구현 시 `headless_m1_interaction.gd`를 추가해 **판정 규칙**을 화면 없이 검증할 것
(낮/밤 목록 분기, 난이도·레벨 판정, `allure`의 낮↔밤 연계, 1회성 액션 소멸).
`PassActionJudge`가 `GameState`를 주입받는 구조라 격리된 플래그로 테스트할 수 있다.

---
name: octopath-build
description: "옥토패스 트래블러 클론(Godot 4.7 HD-2D)의 개발 워크플로우를 조율하는 오케스트레이터. 설계 → 구현 → 검증 순으로 전문 에이전트를 호출해 마일스톤 단위로 기능을 완성한다. '필드 탐험 만들어줘', '전투 시스템 구현해줘', 'NPC 대화 붙여줘', '낮밤 전환 만들어줘', 'M1 진행해줘', '다음 마일스톤' 등 이 게임의 기능 개발 요청 시 반드시 이 스킬을 사용할 것. 후속 작업 — '다시 실행', '재실행', '수정해줘', '보완해줘', '업데이트', '이전 결과 개선', '전투만 다시', '검증 다시 돌려줘' 에도 반드시 사용. 단순 질문이나 파일 한 개 수정은 직접 처리해도 된다."
---

# Octopath Build — 개발 워크플로우 오케스트레이터

Godot 4.7로 옥토패스 트래블러 2 스타일 게임을 만드는 작업을 조율한다.
목표는 1:1 복제가 아니라 **HD-2D 룩과 옥토패스 특유의 시스템을 갖춘 플레이 가능한 프로토타입**이다.

## 실행 모드: 서브 에이전트

`Agent` 도구로 직접 호출하고, 산출물은 파일로 주고받는다.

> **왜 에이전트 팀이 아닌가:** 이 환경에는 `TeamCreate`/`TaskCreate`가 없다.
> 팀 모드로 작성하면 트리거되지 않는 죽은 코드가 된다. 나중에 팀 도구가 생기면
> Phase 3을 팀 모드로 전환할 수 있다 — 그때는 scene-builder ↔ visual-tuner 간
> `.tscn` 편집 충돌 조율이 실시간으로 가능해져 이득이 크다.

모든 `Agent` 호출에 `model: "opus"`를 명시한다.

## 에이전트 구성

| 에이전트 | subagent_type | 역할 | 읽어야 할 스킬 | 산출물 |
|---------|--------------|------|--------------|--------|
| game-system-designer | `game-system-designer` | 규칙·스키마·데이터 | — | `scripts/data/*.gd`, `data/*.tres`, `_workspace/*_design_*.md` |
| godot-scene-builder | `godot-scene-builder` | 씬·로직 구현 | `tscn-authoring`, `gdscript-convention` | `scenes/**/*.tscn`, `scripts/**/*.gd` |
| hd2d-visual-tuner | `hd2d-visual-tuner` | 카메라·조명·포스트프로세싱 | `hd2d-visual` | 비주얼 프로퍼티, `shaders/*.gdshader` |
| godot-validator | `godot-validator` | 실행 기반 검증 | `godot-run` | `_workspace/*_validation_*.md` |

## 워크플로우

### Phase 0: 컨텍스트 확인

1. `_workspace/` 존재 여부를 확인한다.
2. 실행 모드를 결정한다:
   - **`_workspace/` 없음** → 초기 실행. Phase 1로.
   - **있음 + 부분 수정 요청** ("전투만 다시", "카메라 좀 더 넓게") → **부분 재실행.**
     해당 에이전트만 호출하고, 이전 산출물 경로를 프롬프트에 넣어 읽고 고치게 한다.
   - **있음 + 새 마일스톤 요청** → 새 실행. 기존 `_workspace/`는 **그대로 두고** 새 파일을 추가한다
     (마일스톤별로 파일명이 다르므로 덮어쓰기 충돌이 없다).
3. `git status`로 미커밋 변경을 확인한다. 큰 변경 전이면 사용자에게 커밋을 제안한다.

### Phase 1: 범위 확정

1. 요청이 어느 마일스톤에 속하는지 판단한다 (아래 마일스톤 표 참조).
2. **범위가 애매하면 여기서 사용자에게 묻는다.** 구현을 시작한 뒤에 방향을 되돌리는 것이
   훨씬 비싸다.
3. `_workspace/`를 만든다 (없으면).

### Phase 2: 설계

**호출:** `game-system-designer` 1명 (`run_in_background: false` — 뒤 단계가 이 결과에 의존한다)

규칙과 데이터 스키마를 먼저 확정한다. 구현자가 스키마 없이 시작하면 나중에 전부 갈아엎게 된다.

비주얼만 다루는 요청(예: "블룸 조정")은 이 Phase를 건너뛴다.

### Phase 3: 구현

**호출:** `godot-scene-builder` + `hd2d-visual-tuner`

두 에이전트가 같은 `.tscn`을 만질 수 있으므로 **동시에 돌리지 않는다.**
순차로 호출하고, 담당 경계를 프롬프트에 명시한다:

- `godot-scene-builder` — 노드 트리 구조, 스크립트, 시그널 배선, 로직
- `hd2d-visual-tuner` — 카메라·조명·Environment·Sprite3D 렌더 프로퍼티

순서는 **scene-builder 먼저, visual-tuner 나중.** 노드가 존재해야 프로퍼티를 붙일 수 있다.

각 에이전트 프롬프트에 반드시 포함할 것:
- Phase 2의 설계 문서 경로
- 담당 범위와 **건드리지 말아야 할 파일**
- 완료 후 `godot.sh smoke`로 자체 확인하라는 지시

### Phase 4: 검증

**호출:** `godot-validator` 1명

`_workspace/{M}_validation_{scope}.md`를 생성한다.

**모듈 단위로 점진 검증한다.** 큰 마일스톤이면 Phase 3 중간에도 호출한다 —
전부 만든 뒤 한 번에 검증하면 에러가 얽혀 원인을 못 찾는다.

**실패 시:** 담당 에이전트를 재호출하되, 검증 리포트 경로와 실패 상세를 프롬프트에 넣는다.
**최대 2회까지만 재시도한다.** 3회째에도 같은 실패면 멈추고 사용자에게 보고한다 —
추측을 쌓으면 원래 문제까지 가려진다.

### Phase 5: 사용자 확인 및 정리

1. **비주얼은 반드시 사용자 눈 확인을 요청한다.** 헤드리스로는 검증되지 않는다:
   ```bash
   bash .claude/skills/godot-run/scripts/godot.sh run 15
   ```
2. 결과를 요약 보고한다 — 만든 것, 검증 통과 범위, **검증하지 못한 것**.
3. `_workspace/`는 보존한다 (사후 추적용).
4. 개선할 점이 있는지 사용자에게 묻는다.

## 마일스톤

| | 범위 | 완료 기준 |
|---|------|----------|
| **M0** | 프로젝트 골격, autoload 3종(`GameState`/`SceneRouter`/`DayNight`), 빈 HD-2D 씬 | 헤드리스 스모크 통과 |
| **M1** | **필드 탐험** — 8방향 이동, 추적 카메라, 마을 블록아웃, NPC 대화, 낮/밤, 패스 액션 스텁 | 마을을 돌며 NPC와 대화, 낮/밤 전환 시 조명과 선택지가 바뀜 |
| **M2** | HD-2D 룩 심화 — GridMap 지형, 파티클, 셰이더, 전환 연출 | 스크린샷이 "옥토패스 같다"고 느껴짐 |
| **M3** | **전투** — BP 부스트(1~4연타), 약점/실드 브레이크, 턴 순서 큐, 4인 파티 | 필드에서 전투 진입 → 브레이크로 승리 → 필드 복귀 |

현재 진행 상황은 `_workspace/`의 파일과 `git log`로 판단한다.

## 데이터 흐름

```
[사용자 요청]
     ↓
Phase 1: 범위 확정
     ↓
Phase 2: game-system-designer ──→ _workspace/{M}_design_*.md + scripts/data/*.gd + data/*.tres
     ↓                                        │
Phase 3: godot-scene-builder ←────────────────┘  (설계를 Read)
              ↓ scenes/*.tscn + scripts/*.gd
         hd2d-visual-tuner  (같은 .tscn의 렌더 프로퍼티만)
     ↓
Phase 4: godot-validator ──→ _workspace/{M}_validation_*.md
     ↓ (실패 시 담당자 재호출, 최대 2회)
Phase 5: 사용자 눈 확인 + 보고
```

## 에러 핸들링

| 상황 | 대응 |
|------|------|
| 에이전트 1개 실패 | 1회 재시도. 재실패 시 누락을 명시하고 나머지 진행 |
| 같은 검증 실패 3회 | 중단하고 사용자에게 로그 전문과 함께 보고 |
| scene-builder와 visual-tuner가 같은 파일 충돌 | 순차 실행이 원칙. 충돌 발생 시 visual-tuner 변경을 우선(룩이 이 프로젝트의 정체성) |
| Godot 실행 자체가 안 됨 | `godot.sh` 없이 바이너리 경로·`project.godot` 존재부터 확인 |
| 설계와 구현이 어긋남 | 구현을 고치지 말고 먼저 설계 문서를 확인 — 스키마가 진실의 원천 |
| 비주얼이 "느낌이 안 산다" | 주관적 피드백이므로 hd2d-visual-tuner에게 넘기되, 스크린샷을 함께 전달 |

## 테스트 시나리오

### 정상 흐름
1. 사용자: "NPC 대화 기능 만들어줘"
2. Phase 1 — M1 범위로 판정
3. Phase 2 — designer가 `NpcData` 스키마와 대사 `.tres` 생성
4. Phase 3 — scene-builder가 `DialogueBox.tscn` + 상호작용 로직, 이어서 visual-tuner가 UI 폰트·연출
5. Phase 4 — validator가 파싱·스모크·경계면 교차 검증 → PASS
6. Phase 5 — 창 모드 실행 요청, 요약 보고

### 에러 흐름
1. Phase 4에서 `Field.tscn` 로드 실패 (`ext_resource` id 중복)
2. validator가 파일·줄 번호·원인을 리포트에 기록
3. 오케스트레이터가 scene-builder를 리포트 경로와 함께 재호출
4. 재검증 → 통과하면 Phase 5로, 2회 더 실패하면 사용자에게 보고

## 원칙

- **설계 → 구현 → 검증 순서를 건너뛰지 않는다.** 급해 보여도 스키마 없이 구현하면 더 느려진다.
- **검증하지 않은 것을 완료로 보고하지 않는다.** 특히 비주얼은 항상 "사용자 확인 필요"로 남긴다.
- **작은 단위로 자주 검증한다.** 이 프로젝트는 에디터가 없어 피드백 루프가 유일한 안전망이다.

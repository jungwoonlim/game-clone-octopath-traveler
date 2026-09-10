# game-clone-octopath-traveler

Godot 4.7로 만드는 옥토패스 트래블러 2 스타일 HD-2D JRPG 프로토타입.

## 기술 전제

- **GDScript 전용.** 설치된 Godot이 official(non-mono) 빌드라 C#은 사용할 수 없다.
  사용자 전역 규칙의 "TypeScript only"는 웹 프로젝트 기준이며 여기엔 적용되지 않는다. 주석은 한글.
- **에디터를 열지 않고 CLI로 개발한다.** `.tscn`은 텍스트로 직접 작성하고, 검증은 `godot-run` 스킬로 한다.
- Godot 경로: `/Applications/Godot.app/Contents/MacOS/Godot`

## 하네스: 옥토패스 클론 개발

**목표:** 설계 → 구현 → 실행 검증 루프를 자동화해, 에디터 없이도 HD-2D 게임을 안전하게 만든다.

**트리거:** 게임 기능 개발·수정·검증 요청 시 `octopath-build` 스킬을 사용하라.
단순 질문이나 파일 한 개 수정은 직접 응답해도 된다.

**변경 이력:**

| 날짜 | 변경 내용 | 대상 | 사유 |
|------|----------|------|------|
| 2026-09-10 | 초기 구성 (에이전트 4 + 스킬 5) | 전체 | - |
| 2026-09-10 | 오케스트레이터를 서브 에이전트 모드로 작성 | skills/octopath-build | 이 환경에 `TeamCreate`/`TaskCreate`가 없어 팀 모드는 죽은 코드가 됨 |
| 2026-09-10 | autoload 오탐 필터 추가 | skills/godot-run/scripts/godot.sh | `--check-only`가 autoload를 인식 못해 정상 코드를 실패로 판정 |
| 2026-09-10 | `shot` 명령 추가 (스크린샷 캡처) | skills/godot-run | 헤드리스로 비주얼 검증이 불가능해 에이전트가 화면을 볼 수단이 없었음 |
| 2026-09-10 | DOF 거리값을 실측값으로 수정 | skills/hd2d-visual | 문서의 기존 값(far 14)은 카메라 거리 12.7보다 멀어 DOF가 걸리지 않았음 |
| 2026-09-10 | HD-2D 정의를 전면 수정 (저해상도 렌더·픽셀 텍스처·스프라이트 우선을 최상위로) | skills/hd2d-visual | "이건 3D잖아" 피드백. 기존 스킬이 HD-2D를 3D 씬 구성으로만 정의해 도트풍의 핵심을 누락 |
| 2026-09-10 | 픽셀아트 플레이스홀더 생성기 추가 | tools/gen_placeholder_textures.gd | 단색 머티리얼로는 도트풍이 불가능. 텍스처가 있어야 룩 판단이 가능 |
| 2026-09-10 | M2 선행 진행 (M1보다 먼저) | scenes/field | 사용자 요청 — 게임 화면을 먼저 보고 싶음 |
| 2026-09-10 | Sprite3D 4속성 → 5속성 (`shaded` 추가) | skills/hd2d-visual | 기본값 false라 스프라이트가 조명을 안 받아 밤에 캐릭터만 밝게 뜸 |
| 2026-09-10 | 안개 + 등불 연출 섹션 추가 | skills/hd2d-visual | 안개와 DOF를 동시에 강하게 걸어 화면이 뿌예지는 실수를 겪음 |
| 2026-09-10 | 스크린샷 `--night` 옵션 추가 | tools/capture_screenshot.gd, skills/godot-run | 밤 연출을 에이전트가 확인할 수단이 없었음 |

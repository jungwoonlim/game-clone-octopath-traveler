#!/usr/bin/env bash
# Godot CLI 검증 래퍼 — 에디터를 열지 않고 파싱/로드/스모크/테스트를 자동 검증한다.
#
# 사용법:
#   ./godot.sh import          .godot/ 캐시 생성 (최초 1회, 애셋 추가 후)
#   ./godot.sh check [파일...]  GDScript 파싱·타입 검사 (기본: scripts/ tests/ 전체)
#   ./godot.sh smoke [씬]       씬 로드 + _ready 실행 (기본: main_scene)
#   ./godot.sh test            tests/headless_*.gd 실행
#   ./godot.sh all             import → check → smoke → test 순차 실행
#   ./godot.sh run [초]        창 모드 실행 (비주얼 확인용, 기본 10초)
#   ./godot.sh shot <출력> [밤] [입력타임라인] [위치x,z] [씬]
#                              스크린샷. 조작 후 화면이나 특정 좌표의 구도를 찍을 수 있다:
#                              shot _screenshots/walk.png false "hold:move_right:40;press:interact"
#                              shot _screenshots/west.png false "" "-9.7,0.6"
#
# 종료 코드: 0 = 통과, 1 = 실패

set -uo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../../../.." && pwd)}"

# ─────────────────────────────────────────────────────────────
# 로그 필터
#
# Godot은 정상 종료할 때도 엔진 정리 과정에서 leaked 관련 ERROR/WARNING을 출력한다.
# 이건 우리 코드의 문제가 아니라 헤드리스 종료 시의 알려진 노이즈이므로 걸러낸다.
# 이 필터 없이 "ERROR" 문자열만 보고 판정하면 정상 실행도 전부 실패로 잡힌다.
# ─────────────────────────────────────────────────────────────
strip_noise() {
	grep -vE \
		'leaked at exit|Leaked instance dependency|Pages in use exist at exit|ObjectDB instance was leaked|ObjectDB instances were leaked|^[[:space:]]*at: (~PagedAllocator|cleanup|~Dependency)|^Godot Engine v|^$'
}

# 노이즈를 걷어낸 뒤 남은 진짜 에러를 찾는다.
ERROR_PATTERN='SCRIPT ERROR|Parse Error|Compile Error|ERROR:|Failed to load|Cannot open|Condition .* is true'

# check 단계 전용. 아래 autoload 오탐 처리 때문에 판정 패턴을 좁게 쓴다.
CHECK_ERROR_PATTERN='SCRIPT ERROR|Parse Error|Compile Error'

# ─────────────────────────────────────────────────────────────
# autoload 오탐 처리
#
# `--check-only --script`는 개별 스크립트만 컴파일하므로 project.godot의 autoload를
# 알지 못한다. 그래서 DayNight.toggle() 같은 정상 코드가
# "Identifier not found: DayNight"로 잡힌다 — 실제로는 런타임에 존재하며 스모크는 통과한다.
#
# project.godot에서 등록된 싱글톤 이름을 읽어와, 그 이름에 대한 미발견 에러만 걸러낸다.
# 오타 난 다른 식별자는 그대로 잡히므로 검사 구멍이 생기지 않는다.
# ─────────────────────────────────────────────────────────────
autoload_names() {
	awk '/^\[autoload\]/{f=1; next} /^\[/{f=0} f && /=/ {
		split($0, a, "="); gsub(/[ \t]/, "", a[1]); if (a[1] != "") print a[1]
	}' "$PROJECT_ROOT/project.godot" 2>/dev/null
}

check_binary() {
	if [[ ! -x "$GODOT" ]]; then
		echo "✗ Godot 실행 파일을 찾을 수 없습니다: $GODOT"
		echo "  GODOT 환경변수로 경로를 지정하세요."
		exit 1
	fi
	if [[ ! -f "$PROJECT_ROOT/project.godot" ]]; then
		echo "✗ project.godot이 없습니다: $PROJECT_ROOT"
		exit 1
	fi
}

# 실행 결과를 판정한다. $1 = 단계 이름, stdin = 로그
judge() {
	local label="$1" log
	log="$(cat)"
	local cleaned
	cleaned="$(printf '%s\n' "$log" | strip_noise)"

	if printf '%s\n' "$cleaned" | grep -qE "$ERROR_PATTERN"; then
		echo "✗ FAIL — $label"
		printf '%s\n' "$cleaned" | grep -E "$ERROR_PATTERN" -A2 | head -40 | sed 's/^/    /'
		return 1
	fi
	echo "✓ PASS — $label"
	return 0
}

# ─────────────────────────────────────────────────────────────
cmd_import() {
	echo "▶ 프로젝트 임포트 (.godot/ 캐시 생성)"
	"$GODOT" --headless --import --path "$PROJECT_ROOT" 2>&1 | judge "import"
}

cmd_check() {
	local files=("$@")
	if [[ ${#files[@]} -eq 0 ]]; then
		# scripts/ 와 tests/ 아래 모든 .gd를 대상으로 한다.
		while IFS= read -r f; do files+=("$f"); done < <(
			find "$PROJECT_ROOT/scripts" "$PROJECT_ROOT/tests" -name '*.gd' -type f 2>/dev/null | sort
		)
	fi

	if [[ ${#files[@]} -eq 0 ]]; then
		echo "⊘ SKIP — check (검사할 .gd 파일 없음)"
		return 0
	fi

	echo "▶ GDScript 파싱·타입 검사 (${#files[@]}개)"

	# autoload 이름을 정규식 대안으로 묶는다 (예: "GameState|SceneRouter|DayNight")
	local autoload_re
	autoload_re="$(autoload_names | paste -sd'|' -)"

	local failed=0 pass=0
	for f in "${files[@]}"; do
		local rel="${f#"$PROJECT_ROOT"/}"
		local out
		out="$("$GODOT" --headless --path "$PROJECT_ROOT" --check-only --script "res://$rel" 2>&1 | strip_noise)"

		# autoload 미발견 오탐을 제거한다.
		if [[ -n "$autoload_re" ]]; then
			out="$(printf '%s\n' "$out" | grep -vE "Identifier not found: ($autoload_re)\b")"
		fi

		# 오탐을 걷어낸 뒤에도 컴파일/파싱 에러가 남아있는지로 판정한다.
		# "Failed to load script"는 위 오탐에 뒤따르는 후속 메시지일 뿐이라 판정에 쓰지 않는다.
		if printf '%s\n' "$out" | grep -qE "$CHECK_ERROR_PATTERN"; then
			echo "  ✗ $rel"
			printf '%s\n' "$out" | grep -E "$CHECK_ERROR_PATTERN" | head -5 | sed 's/^/      /'
			((failed++))
		else
			((pass++))
		fi
	done

	if [[ $failed -gt 0 ]]; then
		echo "✗ FAIL — check ($pass 통과 / $failed 실패)"
		return 1
	fi
	echo "✓ PASS — check ($pass/$pass)"
	return 0
}

cmd_smoke() {
	local scene="${1:-}"
	echo "▶ 런타임 스모크 (씬 로드 + _ready 실행)"
	if [[ -n "$scene" ]]; then
		"$GODOT" --headless --path "$PROJECT_ROOT" --quit-after 3 "$scene" 2>&1 | judge "smoke ($scene)"
	else
		"$GODOT" --headless --path "$PROJECT_ROOT" --quit-after 3 2>&1 | judge "smoke (main_scene)"
	fi
}

cmd_test() {
	local tests=()
	while IFS= read -r f; do tests+=("$f"); done < <(
		find "$PROJECT_ROOT/tests" -name 'headless_*.gd' -type f 2>/dev/null | sort
	)

	if [[ ${#tests[@]} -eq 0 ]]; then
		echo "⊘ SKIP — test (tests/headless_*.gd 없음)"
		return 0
	fi

	echo "▶ 동작 테스트 (${#tests[@]}개)"
	local failed=0
	for t in "${tests[@]}"; do
		local rel="${t#"$PROJECT_ROOT"/}"
		local out
		out="$("$GODOT" --headless --path "$PROJECT_ROOT" --script "res://$rel" 2>&1 | strip_noise)"
		# 테스트 스크립트는 실패 시 "TEST FAIL"을 출력하기로 약속한다 (tests/ 컨벤션).
		if printf '%s\n' "$out" | grep -qE "TEST FAIL|$ERROR_PATTERN"; then
			echo "  ✗ $rel"
			printf '%s\n' "$out" | grep -E "TEST FAIL|$ERROR_PATTERN" | head -10 | sed 's/^/      /'
			((failed++))
		else
			echo "  ✓ $rel"
			printf '%s\n' "$out" | grep -E "TEST PASS" | head -20 | sed 's/^/      /'
		fi
	done

	if [[ $failed -gt 0 ]]; then
		echo "✗ FAIL — test ($failed개 실패)"
		return 1
	fi
	echo "✓ PASS — test (${#tests[@]}/${#tests[@]})"
	return 0
}

cmd_run() {
	local seconds="${1:-10}"
	local frames=$((seconds * 60))
	echo "▶ 창 모드 실행 (${seconds}초) — 비주얼 확인용"
	echo "  헤드리스는 dummy 렌더러라 화면이 비어 나옵니다. 실제 룩은 이 모드로만 확인 가능합니다."
	"$GODOT" --path "$PROJECT_ROOT" --resolution 1280x720 --quit-after "$frames" 2>&1 | strip_noise | tail -20
}

cmd_shot() {
	local out="${1:-_screenshots/shot.png}"
	local night="${2:-false}"
	local actions="${3:-}"
	local pose="${4:-}"
	local scene="${5:-res://scenes/main/Main.tscn}"
	echo "▶ 스크린샷 캡처 → $out (밤: $night${pose:+, 위치: $pose}${actions:+, 입력: $actions})"
	# 헤드리스는 dummy 렌더러라 빈 이미지가 나온다. 창 모드로 실행하되 사용자 개입 없이 끝난다.
	local log
	log="$("$GODOT" --path "$PROJECT_ROOT" --resolution 1280x720 \
		--script res://tools/capture_screenshot.gd \
		-- "--scene=$scene" "--out=res://$out" "--night=$night" \
		"--actions=$actions" "--pose=$pose" 2>&1 | strip_noise)"

	if printf '%s\n' "$log" | grep -q "CAPTURE OK"; then
		# 캡처가 성공해도 스크립트가 죽어 있으면 화면 일부가 통째로 비어 있다.
		# 실제로 scatter 스크립트가 파싱 에러로 로드되지 않아 배경 숲이 없는 채
		# 여러 번 "정상 캡처"로 넘어간 적이 있다. 반드시 함께 검사한다.
		if printf '%s\n' "$log" | grep -qE "SCRIPT ERROR|Parse Error|Failed to load"; then
			echo "✗ FAIL — shot (캡처는 됐으나 스크립트 에러 — 화면이 불완전하다)"
			printf '%s\n' "$log" | grep -E "SCRIPT ERROR|Parse Error|Failed to load" | head -6 | sed 's/^/    /'
			return 1
		fi
		echo "✓ PASS — shot"
		printf '%s\n' "$log" | grep "CAPTURE OK" | sed 's/^/    /'
		return 0
	fi
	echo "✗ FAIL — shot"
	printf '%s\n' "$log" | grep -E "CAPTURE FAIL|$ERROR_PATTERN" | head -10 | sed 's/^/    /'
	return 1
}

cmd_bench() {
	local night="${1:-false}"
	local scene="${2:-res://scenes/main/Main.tscn}"
	echo "▶ 성능 측정 (밤: $night, 씬: $scene) — 워밍업 후 120프레임 평균"
	local log
	log="$("$GODOT" --path "$PROJECT_ROOT" --resolution 1280x720 \
		--script res://tools/measure_fps.gd \
		-- "--night=$night" "--scene=$scene" 2>&1 | strip_noise)"

	if printf '%s\n' "$log" | grep -q "BENCH avg"; then
		printf '%s\n' "$log" | grep "BENCH avg" | sed 's/^/    /'
		return 0
	fi
	echo "✗ FAIL — bench"
	printf '%s\n' "$log" | grep -E "BENCH FAIL|$ERROR_PATTERN" | head -8 | sed 's/^/    /'
	return 1
}

cmd_all() {
	check_binary
	local rc=0
	cmd_import || rc=1
	cmd_check || rc=1
	cmd_smoke || rc=1
	cmd_test || rc=1
	echo ""
	if [[ $rc -eq 0 ]]; then
		echo "═══ 전체 통과 ═══"
		echo "단, 비주얼(DOF/블룸/실제 화면)은 헤드리스로 검증할 수 없습니다. './godot.sh run'으로 눈 확인이 필요합니다."
	else
		echo "═══ 실패 있음 ═══"
	fi
	return $rc
}

# ─────────────────────────────────────────────────────────────
case "${1:-all}" in
	import) check_binary; shift; cmd_import ;;
	check)  check_binary; shift; cmd_check "$@" ;;
	smoke)  check_binary; shift; cmd_smoke "$@" ;;
	test)   check_binary; shift; cmd_test ;;
	shot)   check_binary; shift; cmd_shot "$@" ;;
	bench)  check_binary; shift; cmd_bench "$@" ;;
	run)    check_binary; shift; cmd_run "$@" ;;
	all)    cmd_all ;;
	*)      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac

extends SceneTree
## M2 데이터(.tres) 생성기 — 구역 2개 + 집정관 광장 NPC 3명.
##
## **손으로 .tres를 쓰지 않는 이유:** 타입 배열 직렬화
## (`pass_actions = Array[ExtResource("...")]([SubResource("...")])`)를 추측해서 쓰면
## Godot은 에러 없이 **빈 배열로 로드한다.** 패스 액션이 하나도 안 뜨는데 실행은 정상이다.
## 그래서 M1과 같은 방식으로 엔진에게 직렬화를 맡긴다.
##
## 실행: godot --headless --path . --script res://tools/gen_m2_data.gd
## 같은 파일을 다시 만들어도 결과가 같다(멱등). 값을 바꾸려면 이 파일을 고치고 다시 돌린다.

const ZONE_DIR := "res://data/zone"
const NPC_DIR := "res://data/npc"
const TEX_DIR := "res://assets/placeholder"

const SCRUTINIZE := "res://data/pass_action/scrutinize.tres"
const ALLURE := "res://data/pass_action/allure.tres"

## 밤 고정 구역의 유혹 선행 조건(설계 §3-2). 낮의 정보수집 대신 밤의 조사 성공을 요구한다.
const NIGHT_ALLURE_REQUIRES := "pa_scrutinize_{npc}"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ZONE_DIR))

	_make_zones()
	_make_hadel()
	_make_vanne()
	_make_orlek()

	print("M2DATA OK")
	quit(0)


# ── 구역 ──────────────────────────────────────────────────────────────────

func _make_zones() -> void:
	var village := ZoneData.new()
	village.zone_id = "village"
	village.display_name = "여울마을"
	village.phase_policy = ZoneData.PhasePolicy.FREE
	# 낮/밤이 자유로운 구역이라 안내문이 필요 없다. 비어 있는 것이 정상이다.
	village.phase_locked_notice = ""
	village.default_spawn_id = &"default"
	_save(village, "%s/zone_village.tres" % ZONE_DIR)

	var square := ZoneData.new()
	square.zone_id = "town_square"
	square.display_name = "집정관 광장"
	square.phase_policy = ZoneData.PhasePolicy.LOCK_NIGHT
	# 키가 씹힌 것이 아니라 규칙이라는 것을 한 줄로 알린다(설계 §2-3).
	square.phase_locked_notice = "{zone}의 등은 밤에만 켠다. 여기서 시간을 돌릴 수는 없다."
	square.default_spawn_id = &"default"
	_save(square, "%s/zone_town_square.tres" % ZONE_DIR)


# ── 광장 NPC 3명 ──────────────────────────────────────────────────────────
#
# 배치 의도(설계 §3-3): 조사 난이도 상한 3에 대해 2 / 3 / 5를 배치해
# **여유 성공 · 경계값 성공 · 실패**를 한 구역에서 전부 관찰할 수 있게 한다.
# 세 명 모두 낮 액션이 없다 — 광장은 밤 고정이라 낮 액션은 영원히 볼 수 없는 데이터가 된다.

func _make_hadel() -> void:
	var npc := NpcData.new()
	npc.npc_id = "hadel"
	npc.display_name = "등불지기 하델"
	npc.sprite = load("%s/char_npc_d_sheet.png" % TEX_DIR)
	npc.difficulty = 2   # 여유 성공 — 조사 상한 3
	npc.level = 5
	npc.day_lines = PackedStringArray([
		"낮의 광장은 그냥 돌바닥입니다. 볼 게 없어요.",
		"해가 지고 오세요. 등이 켜져야 이 도시가 시작되거든요.",
	])
	npc.night_lines = PackedStringArray([
		"이 광장에만 등이 스물셋입니다. 순서대로 켜야 기름이 남아요.",
		"북쪽 열 개는 오늘 켜지 말라더군요. 시청에서 그러라니 그러는 거죠.",
		"누가 어둠을 사 갔는지는 등지기가 제일 먼저 압니다.",
	])
	npc.pass_actions = [
		_scrutinize_entry(
			"등불지기 하델 — Lv.{level} / 경계도 {difficulty}\n허리춤 열쇠꾸러미에 시청 문장이 섞여 있다.",
			""
		),
		_night_allure_entry(
			"하델이 등대를 어깨에 건다. \"어차피 북쪽 열 개는 꺼져 있으니까요.\"",
			"\"당신이 어느 쪽 사람인지부터 봅시다.\""
		),
	]
	_save(npc, "%s/npc_hadel.tres" % NPC_DIR)


func _make_vanne() -> void:
	var npc := NpcData.new()
	npc.npc_id = "vanne"
	npc.display_name = "전표상 반느"
	npc.sprite = load("%s/char_npc_e_sheet.png" % TEX_DIR)
	npc.difficulty = 3   # 경계값 성공 — 상한을 잘못 건드리면 여기서 먼저 깨진다
	npc.level = 6
	npc.day_lines = PackedStringArray([
		"낮에는 시청 창구에 앉아 있습니다. 여기선 아무것도 안 팔아요.",
		"표가 필요하면 밤에 오세요. 밤값이 더 쌉니다.",
	])
	npc.night_lines = PackedStringArray([
		"통행 전표, 숙박 전표, 이름 없는 전표. 무엇을 찾으십니까.",
		"이 도시에서는 이름보다 서명이 먼저입니다.",
		"값은 아직 동전으로 받지 않습니다. 아직은요.",
	])
	npc.pass_actions = [
		_scrutinize_entry(
			"전표상 반느 — Lv.{level} / 경계도 {difficulty}\n소맷단에 지워 낸 서명이 세 개 남아 있다.",
			""
		),
		_night_allure_entry(
			"반느가 장부를 접는다. \"동행도 일종의 계약이지요.\"",
			"\"거래는 서로를 확인한 다음입니다.\""
		),
	]
	_save(npc, "%s/npc_vanne.tres" % NPC_DIR)


func _make_orlek() -> void:
	var npc := NpcData.new()
	npc.npc_id = "orlek"
	npc.display_name = "집정관 호위 오를렉"
	npc.sprite = load("%s/char_npc_f_sheet.png" % TEX_DIR)
	# 난이도 5 — 광장의 벽. 조사에 실패하고, 유혹의 선행 조건이 조사 성공이므로 연쇄 실패한다.
	# 마을의 보든(난이도 4)과 같은 역할이지만 축이 다르다: 보든은 낮의 정보수집이 막히고,
	# 오를렉은 밤의 관찰 자체가 막힌다.
	npc.difficulty = 5
	npc.level = 15
	npc.day_lines = PackedStringArray([
		"계단 위는 시청 관할이다. 볼일이 없으면 내려가라.",
		"낮에는 줄을 서라. 밤에는 오지 마라.",
	])
	npc.night_lines = PackedStringArray([
		"아치 안쪽은 집정관의 구역이다. 여기까지다.",
		"광장에 무슨 이야기가 도는지 나는 듣지 않는다. 듣는 사람은 따로 있다.",
	])
	npc.pass_actions = [
		# 성공 대사는 화면에 나오지 않는다(난이도 5 > 상한 3). 그래도 채워 둔다 —
		# 밸런스를 조정해 상한을 올리는 순간 공용 기본 문구가 튀어나오지 않게 하기 위해서다.
		_scrutinize_entry(
			"집정관 호위 오를렉 — Lv.{level} / 경계도 {difficulty}\n갑주 안쪽에 봉인된 명령서가 접혀 있다.",
			"오를렉이 이쪽을 먼저 본다. 시선이 닿기도 전에 막힌다."
		),
		_night_allure_entry(
			"오를렉이 투구를 벗는다. \"교대까지 두 시간이다.\"",
			"\"근무 중이다.\""
		),
	]
	_save(npc, "%s/npc_orlek.tres" % NPC_DIR)


# ── 엔트리 조립 ───────────────────────────────────────────────────────────

func _scrutinize_entry(success_line: String, failure_line: String) -> NpcPassAction:
	var entry := NpcPassAction.new()
	entry.action = load(SCRUTINIZE)
	entry.success_line = success_line
	entry.failure_line = failure_line
	return entry


## 밤 고정 구역용 유혹 엔트리. 선행 조건을 조사 성공으로 갈아 끼운다(설계 §3-2).
func _night_allure_entry(success_line: String, failure_line: String) -> NpcPassAction:
	var entry := NpcPassAction.new()
	entry.action = load(ALLURE)
	entry.override_required_flag = NIGHT_ALLURE_REQUIRES
	entry.success_line = success_line
	entry.failure_line = failure_line
	return entry


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		printerr("M2DATA FAIL: ", path, " (err ", err, ")")
	else:
		print("  생성: ", path)

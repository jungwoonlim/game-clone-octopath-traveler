extends Node
## 게임 진행 상태를 담는 전역 싱글톤 (autoload: GameState).
##
## 세이브 대상이 되는 값만 여기에 둔다. 화면 표시용 임시 상태는 각 씬이 직접 관리한다.

signal gold_changed(amount: int)

var gold: int = 0

## 파티원 id 목록. M3 전투에서 4인 파티를 구성할 때 사용한다.
var party: Array[String] = []

## 진행 플래그. NPC 대화 분기와 퀘스트 상태를 여기에 기록한다.
var flags: Dictionary = {}


func add_gold(amount: int) -> void:
	# 소지금이 음수가 되지 않게 막는다. 구매 로직에서 잔액 검사를 빠뜨려도 안전하다.
	gold = maxi(0, gold + amount)
	gold_changed.emit(gold)


func set_flag(key: String, value: bool = true) -> void:
	flags[key] = value


func has_flag(key: String) -> bool:
	return flags.get(key, false)

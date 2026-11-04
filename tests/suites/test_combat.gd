extends RefCounted
## CombatManager core coverage: fists attack, cooldown, energy gate, arrows.

const COMBAT_SCRIPT := preload("res://scripts/autoloads/combat_manager.gd")
const PLAYER_SCRIPT := preload("res://scripts/autoloads/player_state.gd")
const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")


func suite_name() -> String:
	return "combat"


func run(t: Object) -> void:
	_test_fists_attack(t)
	_test_cooldown_blocks(t)
	_test_energy_gate(t)
	_test_bow_arrow(t)
	t.completed(4)


func _make() -> Array:
	var ps = PLAYER_SCRIPT.new()
	ps.energy = 100.0
	ps.arrow_count = 5
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var cm = COMBAT_SCRIPT.new()
	cm.configure_for_test(ps, gd, func() -> bool: return true)
	return [cm, ps]


func _test_fists_attack(t: Object) -> void:
	var parts := _make()
	var cm = parts[0]
	var ps = parts[1]
	cm._try_attack()
	t.eq(ps.energy, 99.0, "fists attack costs 1 energy")
	t.ok(float(cm.get("_cooldown_remaining")) > 0.0, "fists attack sets cooldown")
	t.section_done("fists")


func _test_cooldown_blocks(t: Object) -> void:
	var parts := _make()
	var cm = parts[0]
	var ps = parts[1]
	cm._try_attack()
	var energy_after_first: float = ps.energy
	cm._try_attack()
	t.eq(ps.energy, energy_after_first, "cooldown blocks second attack")
	t.section_done("cooldown")


func _test_energy_gate(t: Object) -> void:
	var parts := _make()
	var cm = parts[0]
	var ps = parts[1]
	ps.energy = 0.0
	cm.set("_cooldown_remaining", 0.0)
	cm._try_attack()
	t.eq(ps.energy, 20.0, "exhaustion recovers to data-driven 20 energy")
	t.eq(ps.pass_out_count, 1, "failed attack triggers the pass-out ladder")
	t.section_done("energy")


func _test_bow_arrow(t: Object) -> void:
	var parts := _make()
	var cm = parts[0]
	var ps = parts[1]
	ps.set_equipped_weapon("bow")
	cm.set("_cooldown_remaining", 0.0)
	cm._try_attack()
	t.eq(ps.arrow_count, 4, "bow attack consumes one arrow")
	t.section_done("arrows")

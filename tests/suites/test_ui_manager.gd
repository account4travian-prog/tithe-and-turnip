extends RefCounted
## UIManager v2 stack coverage: open/close ordering, current_menu(),
## is_open(), close_top(), close_all(), and the all_menus_closed signal.

const UI_MANAGER_SCRIPT := preload("res://scripts/autoloads/ui_manager.gd")


func suite_name() -> String:
	return "ui_manager"


func run(t: Object) -> void:
	_test_open_and_current(t)
	_test_stack_order(t)
	_test_close_top(t)
	_test_close_unopened_is_noop(t)
	_test_close_all(t)
	t.completed(5)


func _make() -> Object:
	return UI_MANAGER_SCRIPT.new()


func _test_open_and_current(t: Object) -> void:
	var ui = _make()
	t.not_ok(ui.menu_open, "menu_open starts false")
	ui.open_menu("a")
	t.ok(ui.is_open("a"), "is_open true after open_menu")
	t.ok(ui.menu_open, "menu_open true after open_menu")
	t.eq(ui.current_menu(), "a", "current_menu reports the opened id")
	t.section_done("open and current")


func _test_stack_order(t: Object) -> void:
	var ui = _make()
	ui.open_menu("a")
	ui.open_menu("b")
	t.eq(ui.current_menu(), "b", "current_menu reports the most recently opened id")
	t.ok(ui.is_open("a"), "earlier menu stays open when a second stacks on top")
	t.section_done("stack order")


func _test_close_top(t: Object) -> void:
	var ui = _make()
	var closed_events: Array = []
	ui.all_menus_closed.connect(func() -> void:
		closed_events.append(true))
	ui.open_menu("a")
	ui.open_menu("b")
	ui.close_top()
	t.eq(ui.current_menu(), "a", "close_top closes only the most recently opened id")
	t.ok(ui.menu_open, "menu_open stays true with one menu still open")
	t.eq(closed_events.size(), 0, "all_menus_closed has not fired yet")
	ui.close_top()
	t.not_ok(ui.menu_open, "menu_open false once the stack is empty")
	t.eq(closed_events.size(), 1, "all_menus_closed fires exactly once when the stack empties")
	t.section_done("close top")


func _test_close_unopened_is_noop(t: Object) -> void:
	var ui = _make()
	ui.open_menu("a")
	ui.close_menu("x")
	t.ok(ui.is_open("a"), "closing an id that was never opened leaves the real stack untouched")
	t.ok(ui.menu_open, "menu_open unchanged by closing an unopened id")
	t.section_done("close unopened")


func _test_close_all(t: Object) -> void:
	var ui = _make()
	var closed_events: Array = []
	ui.all_menus_closed.connect(func() -> void:
		closed_events.append(true))
	ui.open_menu("a")
	ui.open_menu("b")
	ui.open_menu("c")
	ui.close_all()
	t.not_ok(ui.menu_open, "menu_open false after close_all")
	t.eq(ui.current_menu(), "", "current_menu empty after close_all")
	t.eq(closed_events.size(), 1, "all_menus_closed fires exactly once for a 3-deep close_all")
	t.section_done("close all")

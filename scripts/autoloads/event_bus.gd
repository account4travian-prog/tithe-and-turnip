extends Node

## Global signals for events that cross responsibility boundaries and are not
## owned by a single system.

signal game_loaded
signal crop_harvested(crop_id: String, count: int)
signal inventory_changed
signal energy_changed
signal dialogue_started(line_ids: Array)
signal dialogue_ended
## E12 (Foraging 2.0): fired whenever a dig or gather turns up an is_rare
## forage entry (morel, truffle). Carries the item id gathered; PlayerState's
## matching event_flags entry is the persistent half E4's dialogue conditions
## will read from later.
signal rare_item_gathered(item_id: String)

class_name WorldVisuals
extends Node2D

## The single y_sort_enabled container for every isometric visual proxy
## (ADR-032, plan section 3). Structure and actor proxies must be added as
## DIRECT children of this node - y_sort_enabled sorts only direct children
## (CLAUDE.md trap 10), so a proxy parented anywhere else (its owning actor,
## a wrapper node) silently drops out of sort order. Terrain draws beneath
## this layer and is never a child of it.
##
## Frozen by Phase 0: main.gd owns the one instance; workstreams add children
## to it, they do not construct their own WorldVisuals.


func _init() -> void:
	# Set here rather than _ready() so the flag is already true before
	# main.gd's _ready() starts parenting proxies under this node.
	y_sort_enabled = true


func _ready() -> void:
	# Perf pass (2026-08-10): enemy.gd's _find_world_visuals() was written to
	# expect this group and falls back to a full recursive tree walk from
	# root when it's missing - that fallback fired on every single enemy
	# spawn because this registration was never actually added (a
	# documented API gap in enemy.gd's own docstring). Registering it here
	# makes the group lookup succeed at O(1) instead.
	add_to_group("world_visuals")

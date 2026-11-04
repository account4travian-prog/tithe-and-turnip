extends RefCounted

## Static helper that derives DEEPSEEK.md content from CLAUDE.md source text.
## Mirrors the CLAUDE -> AGENTS derivation (docs/make_agents.gd), but appends
## the DeepSeek harness section.

const BANNER := "<!-- GENERATED FROM CLAUDE.md - DeepSeek variant, do not edit. Run docs/make_deepseek.gd. -->\n"

const DEEPSEEK_HARNESS := """## DeepSeek harness

DEEPSEEK.md is the DeepSeek equivalent of CLAUDE.md and is generated from it
the same way AGENTS.md is generated for Codex. DeepSeek shares this project's
harness with Claude, ChatGPT, and Codex - the rules under `.deepseek/` mirror
the shared content, so the project safety and workflow rules are identical
across agents.

Before acting, load the matching rule file completely:

- For any GDScript work under `scripts/` or `addons/`, read `.deepseek/rules/gdscript.md`.
- Before inspecting or operating on Godot-managed files (`.tscn`, `.tres`, `.uid`,
  `.import`, `.godot`, `project.godot`), read `.deepseek/rules/godot-files.md`.

## DeepSeek model workflow (binding)

- **Every user query or task on this project routes through the
  `deepseek-v4-workflow` skill first.** The skill dispatches planning and
  reasoning to `deepseek-v4-pro`, routes implementation per Pro's decision,
  and requires the orchestrator to relay the interaction facts.
- **Planning and reasoning** run through `deepseek-v4-pro` (thinking mode on,
  effort `high` or `max`).
- **Creation and implementation** run through `deepseek-v4-flash` when v4 Pro
  deems Flash capable of the work item; otherwise v4 Pro creates the assets and
  Flash applies them to the project.
- The orchestrator (Codex) relays the interaction facts after every Pro call
  (connection, latency, tokens, truncation, outputs, errors) - see the
  `deepseek-v4-workflow` skill.
- Rationale: v4 Pro cannot yet drive the project directly inside Codex; until
  the native integration lands, Pro plans and authors, Flash executes.

## Division of labour

DeepSeek writes GDScript. **Editor work is the human's by default - but DeepSeek
does it on request.**

**Offer before instructing.** When a change needs Editor work, end the response
with the offer - *"want me to wire this up?"* - not with a list of steps. An
unprompted numbered walkthrough is the fallback for when the offer is declined
or desktop control is unavailable; it is not the default.

Never assume a script is attached to a node, a serialized reference is assigned,
or a scene contains anything - that holds regardless of who ends up doing the
wiring. Where DeepSeek is not doing it, the fallback is an explicit numbered
**"Wire this up"** list naming the node, component, and field.

When DeepSeek *is* driving the Editor:

- **Report what changed.** The other developer did not watch it happen.
- **Stop and ask before anything destructive** - deleting nodes or scripts,
  overwriting existing resources, or touching Project Settings.
- Reading the Output panel counts as verification; assuming counts as nothing.

## Files you must never write or edit

Godot's resource files are editor-managed. Never write: `.tscn`, `.tres`, `.uid`,
`.import`, `.godot`, or `project.godot`. **The Godot Editor GUI is the
sanctioned way to change these files**, whether the human drives it or DeepSeek
does. The one documented exception is the one-time headless bootstrap
(`docs/bootstrap_project.gd`), which uses the engine's own serialization APIs.
Where neither is happening, describe the Editor steps for the human.

`worksheet/` is the developer's private folder - write there only when asked.

## Verify before claiming it works

Run `$GODOT --headless --path . --import` after any script change, then run
`$GODOT --headless --path . --script res://tests/run_tests.gd`. The test suite
must pass before claiming completion.

If you cannot run it, say so plainly - never imply a change is verified when it
isn't."""


static func derive_deepseek(source_text: String) -> String:
	# 1. Apply the same filename substitution as the AGENTS generator.
	var body := source_text.replace("CLAUDE.md", "DEEPSEEK.md")
	# 2. Prefix banner, then append the DeepSeek harness section.
	var out := BANNER + body + "\n" + DEEPSEEK_HARNESS
	return out

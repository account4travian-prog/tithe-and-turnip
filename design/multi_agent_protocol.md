# Multi-agent working protocol

Working rules for running DeepSeek, ChatGPT/Terra, and Claude concurrently
on this repo, written down because they were previously tacit judgment
applied live by whichever agent was orchestrating. This document exists
so that judgment survives when the orchestrating agent isn't available -
originally written 2026-08-08 ahead of a ~4-day gap in Claude availability.

Every rule below is traced to a real incident from this project's own
history, not theory. Read the incident before the rule if you want the
"why."

---

## 1. Roles are defined by function, not by which agent is on shift

Any capable agent can fill a role as long as it follows that role's
rules. This is what makes rotation safe - the boundary is the file/domain,
not "DeepSeek always does X."

| Role | Owns | Never touches |
|---|---|---|
| **Orchestrator/reviewer** | Contract-frozen files (`scripts/player/player.gd` unless explicitly reviewing a proposed change to it), `CLAUDE.md`/ADR amendments, merge decisions, all engine verification, cross-file consistency checks | Nothing off-limits - this role is the backstop |
| **Bulk implementer** (DeepSeek's usual role) | GDScript implementation inside its own git worktree, following a written task brief | The Godot engine (see section 3) - ever, for any reason |
| **Art director** (Terra/GPT's usual role) | `asset_studio/style_bible.md`, prompt/seed design, image generation, accept/reject QA on generated assets | Gameplay code files, especially anything under `scripts/player/` or `scripts/autoloads/`. **Incident:** on 2026-08-08 a target-assist change from the art-director-agent's session touched `scripts/player/player.gd` (contract-frozen) at the same moment the orchestrator was independently reviewing it - no corruption resulted only because the orchestrator checked process state before editing, but it was a near-miss. If a task genuinely requires touching gameplay code, it needs the orchestrator role for that piece, not a scope-creep by whichever agent happens to be handy. |

**If you're unsure who owns a file, treat it as orchestrator-owned** -
the conservative default. Ask before editing rather than guess.

## 2. Git worktree discipline for parallel work

- Each parallel workstream gets its own git worktree and branch
  (`git worktree add ../<name> -b feature/<name>`), not shared edits on
  one working tree. This project has done this successfully many times
  (Sprint 16 WS-A/B/C/D, the terrain renderer).
- An implementing agent commits inside its own worktree. It does **not**
  merge its own branch into the integration branch
  (`feature/sprint16-art-foundation` as of this writing). Only the
  orchestrator role merges, and only after independently running
  verification (section 4) - not after reading the implementer's
  self-report of having run it.
- Before merging, check for uncommitted loose files in the main
  checkout that collide with paths the incoming branch will bring in
  (`git status`); remove your own loose duplicates rather than fight a
  merge conflict against your own working copy.

## 3. Engine verification: one instance, one owner, no exceptions

**Incident:** on 2026-08-08 an implementing agent, tasked with writing
GDScript, also tried to run the engine to verify its own work. It
couldn't find the binary, searched the filesystem, found a *different*
non-project Godot build, ran it `--headless` from a non-interactive
shell, and crashed it with a segfault - three times, producing visible
crash dialogs on the human operator's desktop. A later attempt, even
after being given the correct binary path, crashed a fourth time because
its own retry logic launched a second engine instance before the first
had fully exited, corrupting the shared `.godot/` import cache.

Rules, non-negotiable:

- **Implementing agents never invoke the Godot binary.** Not `--import`,
  not `--script res://tests/run_tests.gd`, not a syntax check, nothing.
  They write code, reason about correctness by reading it carefully
  (typos, signature mismatches, cross-file convention mismatches), and
  report what they believe they built. This is a deliberate hand-off,
  not a missing capability.
- **The orchestrator owns all engine verification**, and runs it as:
  1. Check no Godot process is currently running
     (`Get-Process | Where-Object { $_.ProcessName -match 'Godot' }`
     on Windows). Kill any strays first.
  2. Run `--headless --path . --import` alone, wait for it to fully
     exit, read the actual output for parse errors.
  3. Only then run `--headless --path . --script res://tests/run_tests.gd`,
     alone, and read the actual `ALL SUITES PASSED (N checks)` /
     `FAILURES` line - don't trust a summary from anyone else.
  4. The exact binary is
     `%USERPROFILE%\Desktop\GoDot\Godot_v4.7.1-stable_win64_console.exe`
     - the `_console` build specifically. A different build on this
     machine (no `_console` suffix) is not the project's engine and has
     crashed under `--headless`. Do not search for the binary; use this
     path.
- If a second engine-touching task is genuinely urgent while one is
  running, wait for it to exit rather than run a second instance
  "in a different directory" - this has not been proven safe on this
  machine and the one proven failure mode says don't risk it.

## 4. Independent re-verification - don't trust a self-report

Every real bug caught in this project's recent history was caught by
someone re-checking a claim instead of accepting it. Specific patterns
worth repeating:

- **"All tests passed" needs the actual summary line read, not the
  claim.** A compile failure in one file can silently skip an entire
  suite's checks while the harness still prints a passing summary for
  what *did* run - the total check count drops below the expected
  baseline, which is the tell. (Seen 2026-08-08: an expected 2188 checks
  read as 2159 with the suite still claiming a pass - the missing ~30
  were a cascaded compile failure, not intentionally skipped tests.)
- **A visual/QA "accept" needs independent inspection if the reviewing
  agent's own tooling failed partway through.** Terra's image viewer
  broke mid-session twice on 2026-08-08 (a Windows sandbox error); both
  times it disclosed the failure honestly rather than claiming a pass it
  couldn't back up - which is exactly why independent re-inspection
  was possible. The lesson isn't "don't trust Terra," it's "verify
  regardless of who reports it, especially when they've told you their
  own check was compromised."
- **Two independently-built components claiming to interoperate need
  their actual conventions compared by example, not by name.** On
  2026-08-08, a texture-generation tool and the GDScript renderer
  consuming it both used "a 4-bit mask, 16 configs" - but one meant
  dual-grid corner configuration and the other meant edge-adjacency
  bitmask. Same range, different geometry, silently wrong art until
  checked side by side.
- **A newly-added file failing to parse is not automatically a bug** -
  run `--import` once (section 3) before concluding a `class_name` isn't
  registering. But if the *same* error survives a clean import, it's
  real.
- **When stuck between "this might be someone else's live edit" and
  "this is just broken, fix it"**: check the file's last-write timestamp
  and whether a codex/agent process started very recently. If another
  agent is plausibly still writing to a file, don't edit it - report
  the exact finding and wait, rather than risk a collision.

## 5. When genuinely uncertain, stop and ask

This protocol cannot anticipate everything. If an action would touch a
contract-frozen file outside a reviewed change, modify save format,
touch anything under `.godot/`/`.tscn`/`.uid` by hand, or run a
destructive git operation - and there's no clear rule above covering
it - stop and surface the question rather than guess. The cost of
asking is low; the cost of an unwanted merge or a corrupted import cache
is not.

## 6. Reference

- `.deepseek/rules/godot-files.md` - the Godot binary path and
  editor-managed-file rules, referenced from DeepSeek's own task prompts.
- `design/IsometricConversion_Worktrees.md` - the original worktree
  runbook this section's pattern comes from.
- `.claude/skills/deepseek-consult/SKILL.md` - the CODEX_HOME-separation
  requirement for running DeepSeek without logging the operator out of
  ChatGPT. Do not "simplify" this into a `-p profile` inside the main
  Codex home; that has already broken auth once.

# IsometricConversion - parallel-agent runbook

Operational companion to `design/IsometricConversion.md`. That document says
*what* the four workstreams build; this one says *how* to run them
concurrently without them damaging each other's work.

Read `design/IsometricConversion.md` sections 4 and 5 first. This file assumes
the phase structure and the ownership table.

---

## 0. Prerequisite: the repository has no commits

**This blocks everything and must be handled before any agent is spawned.**

As of 2026-08-06 the repository is in this state:

```
branch:   master (no commits)
remote:   none
tracked:  nothing
untracked: 14 top-level entries - all fourteen sprints of work
```

`git worktree add` requires a commit to branch from. More importantly, running
four agents against an uncommitted tree means there is no state to return to
if the conversion goes wrong.

```bash
git -C "%USERPROFILE%/Documents/2DFarmingSim" add -A
```

```bash
git -C "%USERPROFILE%/Documents/2DFarmingSim" commit -m "Baseline: vertical slice through Sprint 14, contract v0.12 (ADR-032)"
```

Verify before continuing - this must print exactly one commit and a clean
tree:

```bash
git -C "%USERPROFILE%/Documents/2DFarmingSim" log --oneline && git -C "%USERPROFILE%/Documents/2DFarmingSim" status --short
```

`.gitignore` already excludes `.godot/*` (keeping `uid_cache.bin`), `.import/`,
OS junk, and `worksheet/`. Nothing further is needed before committing.

A remote is not required for worktrees, but worktrees protect against bad
merges, not against a failed disk. Pushing this baseline somewhere is worth
the five minutes.

---

## 1. Why worktrees rather than branches in one directory

A plain branch checkout gives all four agents **one** working directory, so
they would overwrite each other's files in real time - the ownership table in
the plan would be a convention with nothing enforcing it.

`git worktree` gives each agent its own directory with its own checked-out
branch, sharing one `.git` database. Agents cannot see or clobber each other's
files. Conflicts are deferred to merge time, where they are visible and
resolvable, instead of happening silently mid-edit.

There is one Godot-specific bonus: each worktree gets its own `.godot/` import
cache, so four agents running `--import` and the headless test suite
concurrently do not fight over one cache directory. Sharing that cache across
concurrent runs would produce spurious, confusing failures.

---

## 2. Creating the worktrees

Run after Phase 0 is merged to `master`, from the main repository. The plan's
Phase 0 is sequential and happens in the main working directory - do not
create worktrees for it.

```bash
cd "%USERPROFILE%/Documents/2DFarmingSim" && git worktree add ../iso-ws-a -b iso/ws-a-terrain && git worktree add ../iso-ws-b -b iso/ws-b-structures && git worktree add ../iso-ws-c -b iso/ws-c-actors && git worktree add ../iso-ws-d -b iso/ws-d-camera
```

That produces, as siblings of the project directory:

```
Documents/
├── 2DFarmingSim/     <- master, the integration checkout
├── iso-ws-a/         <- iso/ws-a-terrain
├── iso-ws-b/         <- iso/ws-b-structures
├── iso-ws-c/         <- iso/ws-c-actors
└── iso-ws-d/         <- iso/ws-d-camera
```

Confirm all five are registered:

```bash
git -C "%USERPROFILE%/Documents/2DFarmingSim" worktree list
```

**Do not work in `master` while the parallel phase runs.** It is the
integration target; commits landing there mid-phase invalidate the merge order
and give four agents four different bases.

---

## 3. Spawning the agents

One agent per worktree. Each agent's prompt must carry four things, because a
fresh agent starts with no knowledge of this conversation:

1. **Its working directory** - the worktree path, not the project path. This
   is the single most common failure: an agent that defaults to
   `2DFarmingSim/` edits `master` and destroys the isolation.
2. **Read these first, in order:** `CLAUDE.md` (the contract),
   `design/decisions.md` ADR-032, `design/IsometricConversion.md`.
3. **Its workstream letter**, and the instruction that the ownership table in
   plan section 5.1 is binding - it may write only its own files, and plan
   section 5.3 governs anything else.
4. **Its exit criteria**, quoted from the workstream's "Done when" line.

A serviceable prompt skeleton:

```
Working directory: %USERPROFILE%/Documents/iso-ws-a  (NOT 2DFarmingSim)

Read in order: CLAUDE.md, design/decisions.md (ADR-032),
design/IsometricConversion.md.

You are WS-A (Terrain). Implement plan section 4 / WS-A only.

You own exactly these files:
  scripts/world/farm_renderer.gd
  tests/suites/test_iso_terrain.gd
  the WS-A subsection of DEVELOPMENT_STATE.md

Every other file is owned by a concurrent agent. If you need one, follow plan
section 5.3: stop, record it, escalate, continue with the rest. Do not edit it
and do not duplicate its logic.

Three other agents are working in parallel worktrees right now. Commit only to
this worktree's branch. Never open the Godot editor.

Verify with:
  <godot> --headless --path . --import
  <godot> --headless --path . --script res://tests/run_tests.gd
The FULL suite must pass before you report done.
```

Godot lives at
`%USERPROFILE%\Desktop\GoDot\Godot_v4.7.1-stable_win64_console.exe`. It is
not on `PATH`; give agents the absolute path or they will report it missing.

---

## 4. While the phase runs

- **Do not rebase a workstream branch onto another's work mid-phase.** They
  are independent by construction; rebasing invents a dependency and
  guarantees the conflict the plan is designed to avoid.
- **Do not merge early to "check it fits".** Merge order exists so that each
  merge is verified against a known-good world. An out-of-order merge
  forfeits the diagnostic value of the whole sequence.
- Check in via `git -C ../iso-ws-a log --oneline` rather than by opening the
  directories, which risks stray edits in the wrong tree.
- If a workstream finishes early, it does **not** pick up another's scope.
  Have it deepen its own tests instead - depth sorting and culling both have
  more edge cases than the plan's minimum.

---

## 5. Merging

From `master` in the main checkout, in the plan's section 6 order (D, A, C,
B). After **each** merge, before starting the next:

```bash
cd "%USERPROFILE%/Documents/2DFarmingSim" && git merge --no-ff iso/ws-d-camera
```

```bash
"%USERPROFILE%/Desktop/GoDot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . --import
```

```bash
"%USERPROFILE%/Desktop/GoDot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . --script res://tests/run_tests.gd
```

The suite must print `ALL SUITES PASSED` and exit 0 before the next merge. A
failing merge is resolved before proceeding, never carried forward - with four
branches in flight, a carried failure becomes unattributable within one more
merge.

`--no-ff` is deliberate: it keeps each workstream visible as a unit in the
history, so a fault found in Phase 2 can be traced to a workstream and reverted
as one.

Conflict resolution follows plan section 5.4. In particular: a conflict in
`main.gd`, `run_tests.gd`, or `iso_projection.gd` means someone edited a frozen
file. Stop and find out who, rather than resolving the text.

---

## 6. Cleanup

Only after Phase 2 is complete and the definition of done in plan section 8 is
met:

```bash
cd "%USERPROFILE%/Documents/2DFarmingSim" && git worktree remove ../iso-ws-a && git worktree remove ../iso-ws-b && git worktree remove ../iso-ws-c && git worktree remove ../iso-ws-d
```

```bash
git -C "%USERPROFILE%/Documents/2DFarmingSim" branch -d iso/ws-a-terrain iso/ws-b-structures iso/ws-c-actors iso/ws-d-camera
```

`git worktree remove` refuses to drop a directory with uncommitted changes,
which is the desired behaviour - if it refuses, something in that worktree was
never merged. Look before forcing.

If a worktree directory was deleted manually at any point, clear the stale
registration with:

```bash
git -C "%USERPROFILE%/Documents/2DFarmingSim" worktree prune
```

---

## 7. Fallback: sequential execution

If parallel execution proves more trouble than it saves - four agents is a lot
of concurrent supervision - the plan degrades cleanly. The workstreams are
independent, so running them one at a time in merge order (D, A, C, B) in the
main checkout requires **no change to the plan at all**: skip this document
from section 2 onward, and treat each workstream's "Done when" as the gate to
start the next.

Phase 0 is worth doing exactly as written either way. Its value is not only
conflict avoidance - freezing the projection API and wiring `main.gd` against
it up front is what keeps four separate pieces of work compatible, whether
they happen at the same time or not.

# ORCHESTRATED-tier harness template — manifest

**Kit documentation. Never copied into a target repo; full of unresolved placeholders by design.**

This tier implements HARNESS-REDESIGN.md §2: one orchestrator with **full tools** that reads the design contract itself (its core at session start, each brief's cited sections just in time), dispatches **epic-sized units** (not stories) as subagents on disjoint file trees (a lone unit synchronously, a parallel group in the background and in worktrees, collected before the turn ends), runs the full gate and one composite review at **join points**, and rules on escalations with citations. It replaces the retired per-story `standard`/`full` lifecycle (scoper → implementer → reviewer per story), whose context re-establishment cost was the defect: same product, the unit-shaped build finished in ~19 dispatches while the story-shaped one paid the toll 3–7 times per story and stalled.

**Sizing (KD-002): for ~15+ story builds.** Below that, use `small` — one inline builder, no subagents; orchestration overhead at that size costs more than it returns. There is no upper tier above this one.

---

## Files

| File | What it is |
|---|---|
| `CLAUDE.md.tmpl` | The operating manual, under 50 lines once forged, **only what every agent needs on every prompt; the process lives in `orchestrate-build` (KD-021).** Opens with `{{ORGANISING_PRINCIPLE}}` (one sentence agents reason from) · project and one-liner · tier line ("invoke `orchestrate-build`; it holds the process", no tiebreak) · one line pointing to `orchestrate-build` → Talking to the user · the three governing files, one line each · pinned stack and `{{PROJECT_STRUCTURE}}` as one line · commands (`{{CHECK_COMMAND}}` at joins by the orchestrator only; scoped commands for unit agents) · **the only copy of `{{INVARIANTS}}`** · commit format · the unit agents' stop-and-report triggers (one line; the ruling procedure is in the skill). No rationale sentences. "Talking to the user" and the project DoD live in `orchestrate-build`. |
| `STATE_FILE.md.tmpl` | `{{STATE_FILE}}` = **`PROGRESS.md` at the repo root**. Single writer: the orchestrator. Statuses `todo/wip/done/blocked/partial` with **`partial` first-class** ("a row marked done that is not done is a silently wrong number"). Sections: NEXT ACTION · standing facts (incl. the skeleton's run command) · dispatch-unit status table · session log · **escalations & rulings log** · decisions & deviations (never delete) · blockers. |
| `skills/orchestrate-build/SKILL.md.tmpl` | **The loop, and the only home of every process rule.** Session start (read the design's core: §1, §2.1, §5, §10, §11; each brief's cited sections just in time) · units from `PLAN.md` → `## Dispatch units` with the verbatim merge rule · U0 walking skeleton first · the fixed **7-part brief skeleton** (sections+line ranges / trees+live-neighbours / 2–4 ⚠️ traps / deliverables / tests+vacuousness / stop-and-report / report-back with could-not-verify) · dispatch mechanics (lone unit synchronous, a group in the background and worktrees and collected in the same turn, liveness rule, no model override, cap `{{MAX_PARALLEL}}`, tree disjointness) · the join (drain → record → invariant-proof interrogation → mutation-test → `{{CHECK_COMMAND}}` → skeleton re-run → `join-review` at `opus` → conditional gates → fix directly or one follow-up) · escalation ruling with `> AMENDED` blocks · reporting to the user and "Talking to the user" (literal copy of the kit's `COMMUNICATION.md` block) · the mandatory final **integration unit**, which carries the project DoD · handoff on the single stop signal. |
| `skills/join-review/SKILL.md.tmpl` | Composite-diff review at every join, dispatched at **`model: opus`**. Reads the invariants **from CLAUDE.md** (never restates them) and the overrides layer (AMENDED blocks + deviations ledger) before judging fidelity. Focus: cross-unit seams, tests that pin stubs, glossary drift. Numbered findings to `{{REVIEWS_DIR}}`, capped ~150-word return. |

**No `agents/` directory.** Units and gates are general-purpose subagents given a brief or told to invoke a skill; the roles live in the dispatch prompts, not in agent files.

**Conditional gates** (emitted from `templates/gates/` when their flag is set, wired as **join-point dispatches** in orchestrate-build, never per-story duties): `db-migration-review` · `api-contract-sync` · `design-token-lint` · `mcp-scan` · `perf-profiling` · `release-runbook` (user-ask only, never a join gate).

---

## Load-bearing invariants of this tier

1. **The orchestrator has full tools, on purpose.** The old "no Bash/Grep/Glob orchestrator" existed to keep a per-story orchestrator's context flat; it also made briefs expensive and adjudication impossible: the mechanism behind "misses the point of the app." Here the one actor with continuity holds the contract. Do not re-add the restriction when editing this tier.
2. **The orchestrator reads the contract itself: §1, §2.1, §5, §10, §11 at session start, and each brief's cited sections just before writing it.** A whole-design read does not survive compaction. Everything downstream (cited briefs, trap-writing, one-message rulings) depends on that reading.
3. **Units, not stories.** Merge rule, verbatim: *if unit N's agent must re-read unit N−1's output to understand its own job, they are one unit.* Stories remain the AC checklist inside a brief.
4. **U0 is the walking skeleton and stays runnable** — re-verified at every join. Time-to-first-run is a correctness strategy: real data finds the defect class no synthetic fixture can.
5. **Gates at joins, not steps.** Unit agents run narrow checks on their own tree; only the orchestrator runs `{{CHECK_COMMAND}}`, only at joins. Review happens exactly once per join (`join-review`), not per unit.
6. **Briefs carry the traps** — the 2–4 things most likely to go silently wrong, ~200 tokens each; the cheapest whole-unit-rework prevention that exists.
7. **Escalations get ruled, and rulings amend the design** as dated `> AMENDED` blocks. Agents never quietly resolve contradictions; only user-reserved decisions reach the user (via `{{NOTIFY}}`, called directly — the orchestrator has Bash).
8. **One state file, one writer, `partial` first-class.**
9. **The final unit is always integration**: every contract entry answers non-stub, a real-data run, fixtures that *cross* every design-stated numeric limit, and red-probed gates. This is what catches units that pass their own tests while the assembled app does not run.
10. **The invariants block appears once, in CLAUDE.md.** Skills point at it; a restated copy is a divergence waiting to happen.
11. **`{{INVARIANTS}}` must be lifted verbatim from the design as checkable assertions** — see `templates/PLACEHOLDERS.md`. A vague block here checks nothing at every join.

---

## The notification channel (every tier)

`harness-forge` copies `.claude/scripts/notify.sh` (`{{NOTIFY}}`) and `.claude/ASK_CONTRACT.md` into the repo verbatim from the plugin root. Tier difference: **this orchestrator calls the notifier itself** — the notify-only chore dispatch existed only because the old orchestrator had no Bash. No `Notification` hook is emitted into the repo (a per-project copy double-fires against the user's global hook).

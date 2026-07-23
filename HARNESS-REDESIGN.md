# Harness redesign — why the generated build harness is slow, and what replaces it

> Status: **IMPLEMENTED 2026-07-23** (kit v0.5.0). §2 and §3 below are now built: the `orchestrated`
> tier exists at `templates/orchestrated/`, `standard`/`full` are deleted, KD-019 records the
> decision, `harness-migrate` exists, `backlog-author`/`plan-lint` emit and lint dispatch units and
> the design self-verification pass. Per the user's direction, ClaudeLens is **not** being migrated
> — that project is closed; the first new project on this tier is the validation run (§5).
> Originally written 2026-07-23 as a proposal, after comparing three artifacts:
>
> - `/Volumes/ExtSSD/Projects/test/ORCHESTRATION.md` — the *fast* build (Claude Lens, built in
>   ~one session, 13 dispatch units, ~19 agent invocations)
> - `/Volumes/ExtSSD/Projects/ClaudeLens` — the *slow* build (same product, same start date,
>   8 of 62 stories done, far more tokens)
> - this kit's `templates/` — which generated the slow build's harness at tier `full`

---

## 1. Diagnosis: the numbers

Same product, same design docs (the kit's front half generated both — and it is excellent; see §4).

| | Fast build (test/) | Slow build (ClaudeLens) |
|---|---|---|
| Dispatch unit | layer-sized epic (13 units for a ~68-story backlog) | story (62 stories → 70 after splits) |
| Agent dispatches per unit | 1 (occasionally a follow-up) | **3 minimum, up to 7** (scoper → implementer → reviewer → type gates), no size exemption |
| Total dispatches | ~19 for the whole build | ≥186 floor for stories alone, before gates/fix-stories/retries |
| Full-suite gate | at join points only; agents run scoped checks | per story (implementer) + per story (reviewer re-runs diff tests) + twice per epic boundary |
| Epic close | orchestrator runs the gate once | 7-step serial chain that runs twice (`regression-run → e2e-smoke → code-review → fix-stories → regression-run again → docs-sync`) |
| Who reads the design | orchestrator reads all ~4,400 lines once, dispatches section-cited briefs | orchestrator **forbidden** to read design or code ("You have no Bash, Grep, or Glob… you do not read DESIGN.md or product code"); a sonnet scoper re-reads design+code fresh for every story |
| Rules surface per agent | one CLAUDE.md + a dense brief | 223-line CLAUDE.md + 379-line resume-build (duplicated authority), 23 invariants restated in two places and re-checked literally on every story |
| Result after the same elapsed time | whole product built, user refining the idea | 1 epic of 11 complete; that epic's 8 stories spawned 19 fix-stories, 51 review artifacts, 15 harness-doctor runs |

**Root cause, in one sentence:** the dominant cost in agentic builds is context re-establishment,
and the `full`-tier harness pays it 3–7 times *per story* while structurally preventing the one
actor with continuity (the orchestrator) from ever holding the context that would make briefs cheap
and adjudication possible.

The tool-starved dispatcher is the exact inverse of what made the fast build work. It also
explains "misses the point of the app": an orchestrator that has never read the design cannot rule
on escalations, so contradictions either bounce to the human (stall) or get silently resolved by
whichever subagent hit them (divergence).

### 1a. The second failure mode: all stories green, product wrong

Observed by the user across ClaudeLens-style builds: even when the harness *does* grind through
the backlog, the finished thing does not do what the product is supposed to do. This is not bad
luck — it is structural, and it has three interlocking mechanisms:

- **Nobody holds the product.** Each story agent sees only its brief and its acceptance criteria;
  the scoper sees one story at a time; the orchestrator is forbidden to read the design or the
  code. Per-story acceptance criteria are all *locally* satisfiable while the point of the product
  lives *between* stories — so there is no actor who can notice the assembled thing has drifted.
  The fast build hit a small version of this even with epic-sized units: 17 IPC channels
  implemented but never registered, every view broken, every unit test green. Story-sized units
  multiply the number of seams where that happens by ~5×.
- **No one looks at the running product until the end.** With no walking skeleton, the first time
  anyone (human or agent) sees the app do its job is after the last story. Every intent error made
  in story 3 is invisible until story 62, by which point dozens of stories are built on top of it.
  Worse, per-story tests written against the wrong intent then *pin the wrong behaviour in place* —
  a test that encodes a mistaken reading becomes the reason the reading survives review.
- **No organising principle to reason from.** Agents facing a situation their acceptance criteria
  did not anticipate have a 23-invariant checklist but no single sentence saying what the app is
  *for*. Checklists produce compliance; they do not produce the correct novel judgement, and a
  product is mostly built out of novel judgements.

The §2 model attacks this directly: the orchestrator holds the entire contract (someone finally
owns the whole), the walking skeleton puts the real product in front of the user in the first
session and keeps it runnable (intent errors surface in days-worth-one-fix, not week-worth-of-
rework), briefs restate the product purpose and traps rather than only the task, and the final
unit exists specifically to test the assembled whole against real data. Rule 9's single
organising sentence is the cheapest of the four and arguably the most load-bearing.

Honesty note: the ceremony was not *pure* waste — ClaudeLens's epic-gate composite review caught
2 real defects that 22 first-pass PASSes missed. The redesign keeps that (review at joins);
it removes the per-story fan-out, which caught essentially nothing the join review wouldn't.

## 2. What replaces it

One orchestration model, taken directly from ORCHESTRATION.md §1–§2 and §5. The generated harness
becomes **one CLAUDE.md + one orchestrator skill + one state file.** No scoper agent, no
per-story reviewer agent, no evidence-file protocol, no fix-story machinery.

1. **The orchestrator reads the full contract itself** (PRD/STACK/DESIGN/FRONTEND), once, before
   dispatching anything. It has full tools. This is the single biggest reversal.
2. **Dispatch units are epics sized to an agent's context, not stories.** Merge rule, verbatim:
   *if unit N's agent must re-read unit N−1's output to understand its own job, they are one unit.*
   A ~60-story backlog should come out around 10–15 units. PLAN.md keeps its stories — they become
   the checklist *inside* a brief, not dispatch boundaries.
3. **Walking skeleton first, enforced.** Unit 0 is always the thinnest vertical slice that opens a
   real window / serves a real request against real data. Layer-shaped epics follow, and the
   skeleton stays runnable throughout. (ORCHESTRATION.md §2.7 — the fast build's own biggest
   self-critique; 90 seconds of real data found an overflow bug 890 green tests missed.)
4. **Briefs carry the traps.** Fixed 7-part skeleton: exact sections to read (with line ranges) ·
   owned file tree / forbidden trees · the 2–4 things most likely to go silently wrong ·
   deliverables · tests incl. what would make each vacuous · "stop and report if…" ·
   report-back format with a mandatory "what I could not verify" section.
5. **Gates at joins, not steps.** Agents verify with narrow commands (`tsc --build`, one vitest
   project). The orchestrator runs the full check at join points, plus one composite-diff
   `code-review` per epic-sized join (the one piece of ClaudeLens ceremony that earned its keep).
6. **Parallelism keyed on file-tree disjointness only, cap ~3.** Tell each agent which other trees
   are live and that failures there are not theirs to fix.
7. **Escalation protocol with a ruling orchestrator.** Agents stop-and-report on contradictions;
   the orchestrator rules in one message with a citation and writes the ruling back into DESIGN.md
   as a dated AMENDED block. (~30 escalations in the fast build; ~12 were real design defects.)
8. **One state file, single-writer (orchestrator), with `partial` as a first-class status.**
9. **One organising principle at the top of the generated CLAUDE.md** — one load-bearing sentence
   per project (the fast build's was "a silently wrong number is the worst possible outcome"),
   which is what lets agents make correct novel judgements no brief anticipated.
10. **Integration + gate-audit unit at the end**: an exhaustive "every contract entry answers"
    test (the fast build shipped 17 implemented-but-unregistered IPC channels with every unit test
    green), run against real data, plus probing each gate to demonstrate a red.

## 3. Concrete changes to this kit

- **`templates/full/` and `templates/standard/`: replace the per-story 3-agent lifecycle** with the
  model in §2. Practically: a new tier template (working name `orchestrated`) containing
  `CLAUDE.md.tmpl`, `STATE_FILE.md.tmpl`, and a single `orchestrate-build` skill that encodes
  §2's ten rules plus the brief skeleton. `full` and `standard` as they exist today are retired or
  kept only as an explicit opt-in.
- **`templates/small/` stays** — it is already the right shape for <15-story builds (one session,
  inline, no subagents).
- **`harness-forge`**: emits the new tier; drops story-scoper/story-implementer/story-reviewer
  agents, the evidence-file protocol, fix-story minting, and the twice-running epic-gate chain.
  Keeps `harness-doctor` (run once after forging, not 15 times a day) and the conditional
  stack-specific gates — but wired into the join-point review, not into per-story reviewer duties.
- **`backlog-author` or a new forge step: add unit grouping.** After stories are written, group
  them into dispatch units by file-tree + the §2.2 merge rule, and mark the walking-skeleton slice
  as unit 0. PLAN.md gains a thin "dispatch units" table; stories are otherwise untouched.
- **New skill: `harness-migrate`** — converts an *existing* generated harness (any tier, possibly
  mid-build) to the new design in place. Forging fresh is not enough; ClaudeLens is 8 stories in
  and its state must survive. What it does, in order:
  1. **Inventory the old harness**: CLAUDE.md, `.claude/agents/*`, `.claude/skills/*`, state
     file(s), PLAN.md, per-story artifacts (`_briefs/`, `_reviews/`), and any author-added gates
     beyond the templates.
  2. **Carry the state across, honestly.** Done stories stay done; anything the old harness left
     mid-flight (ClaudeLens is paused mid-epic-gate) is recorded as `partial` with what remains
     owed, never silently promoted to done. The deviation ledger and any DESIGN.md amendments are
     kept — they are rulings, not ceremony.
  3. **Preserve the project-specific content, delete the machinery.** Kept: the organising
     principle, the invariant list (once, in CLAUDE.md only), stack-conditional gates that match
     STACK.md, ASK_CONTRACT, and author-added gates (e.g. ClaudeLens's `e2e-smoke`,
     `golden-fixture-review`, `guarded-action-review`) re-wired as join-point tools. Deleted:
     scoper/implementer/reviewer agents and skills, `resume-build`, the evidence-file protocol,
     fix-story minting, the twice-running epic-gate chain. Old per-story artifacts are archived,
     not deleted (they are the only record of why early code looks the way it does).
  4. **Regroup the remaining backlog into dispatch units** with the §2.2 merge rule — and if the
     product is not yet runnable end-to-end (ClaudeLens isn't), the *first* new unit is the
     walking skeleton over whatever already exists, before any further layer work.
  5. **Rebuild the gate manifest** (the KD-015 re-tier caveat: re-run `stack-decide` in RE-TIER
     mode, or the migrated harness is gateless while still reporting CLEAN).
  6. **Finish with `harness-doctor`** and a migration report: what was kept, dropped, archived,
     and what state was marked `partial`. Does not complete with an open BLOCKER.
- **`plan-lint` grows a design-self-verification pass** (ORCHESTRATION.md §7 "a finding the kit
  should absorb"): compile the design doc's TypeScript blocks, run its DDL, hand-check the
  arithmetic of every named golden fixture. ~15 defects in ClaudeLens/test's shared design were
  mechanically detectable this way, including a golden fixture whose published expected values were
  wrong — the most dangerous kind, since the natural "fix" breaks the metric to match the fixture.
- **Do not touch the front half.** `project-brief`, `stack-decide`, `design-author`, `scaffold`
  produced the dense glossary/ADR/invariant/fixture contract that made 13-agent parallelism
  possible. ORCHESTRATION.md §7 warns explicitly against "optimising" it thinner.

## 4. Open questions (for the user, not decided here)

1. **What to do with ClaudeLens itself** — run `harness-migrate` on it and resume from the 8 done
   stories (which also makes it the natural first test of the migration skill), or leave it as-is
   and validate on a fresh project first?
2. **Keep a 3-tier ladder or collapse to 2** (`small` inline · `orchestrated`)? Current lean: 2 —
   the standard/full distinction is what produced the ceremony.
3. **Which of ClaudeLens's author-added gates survive** (`e2e-smoke`, `golden-fixture-review`,
   `guarded-action-review`)? Lean: keep as join-point tools the orchestrator may invoke, never as
   per-story obligations.
4. The kit's templates say *"do not 'improve' these templates by shortening them"* — the rationale
   prose is claimed to be what makes agents comply. The redesign rejects that for volume (2,600
   lines of always-on skill prose) but keeps the principle for the *brief* (traps ≈ 200 tokens
   each, §2.4). Worth stating in KIT_DESIGN.md as an amended decision rather than silently.

## 5. What "done" looks like

A re-forged harness for a ~60-story project should produce: ~10–15 dispatch units, unit 0 runnable
in front of the user in the first session, full gate runs counted in the tens not the hundreds,
and an orchestrator that can answer any design question from its own context. The fast build is
one data point, not proof (its own §7 caveat) — so the first project built on the new tier should
be treated as the validation run, with token totals and wall-clock compared against ClaudeLens.

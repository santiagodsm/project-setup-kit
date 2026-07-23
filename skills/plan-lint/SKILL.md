---
name: plan-lint
version: 0.1.0
description: "Audit PLAN.md before the build starts: dependency cycles, untestable acceptance criteria, design sections with no story, stories with no design citation, layer-shaped stories, unsplit L's, tier mismatch, dispatch-unit structure (orchestrated tier), and a mechanical design self-verification pass. Step 7 of project setup. Run after backlog-author and after any hand-edit to the plan. Use when the user says 'check the plan', 'lint the backlog', 'is this plan any good'."
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Write
metadata:
  role: reviewer
  reads: [PLAN.md, DESIGN.md, PRD.md (the TIER marker), OPEN_QUESTIONS.md, STACK.md]
  writes: [PLAN_LINT.md — never PLAN.md, never DESIGN.md, never SETUP_PROGRESS.md]
---

# plan-lint — the plan is the last thing nobody checks

Once the build starts, `PLAN.md` is treated as truth by every agent: the orchestrator writes unit briefs from it and sequences on `deps`, unit agents read acceptance criteria from it, `join-review` gates on them. **Nothing downstream will ever question it.** You are the only check it gets.

The author wrote it and is the worst possible judge of whether their own acceptance criteria are checkable — every AC feels obviously testable to the person who just wrote it. That is why this is a separate skill with fresh eyes.

**Report only. Never edit `PLAN.md`.**

## The checks

### 1. Dependency cycles — BLOCKER
Build the graph. Traverse it. A cycle **deadlocks the orchestrator**: pending stories remain, none is eligible, and it will sit there. Report the exact cycle (`S-03.2 → S-04.1 → S-03.2`).

Also flag **false dependencies** — a `deps` that isn't a real ordering constraint. Each one needlessly serializes work that could have run in parallel, and nobody ever goes back and removes them. **This is no longer a theoretical cost:** the generated harness dispatches up to `MAX_PARALLEL` units concurrently and a dependency edge is the *first* of its gating conditions — a false dep between stories becomes a false edge between dispatch units, and every false edge is throughput deleted for the life of the build. Ask of each edge: would the second story actually fail, or produce a wrong result, if the first had not landed? "It's tidier in this order" is not a dependency.

### 2. Untestable acceptance criteria — BLOCKER
The big one. For every AC, ask: **could two competent reviewers disagree about whether this is met?** If yes, it is untestable, and it will pass review forever while nothing gets built.

The tells:
- Adjectives with no threshold: *fast, responsive, intuitive, robust, clean, seamless, performant.*
- Verbs with no object: *handles, supports, manages, processes, validates.*
- "Works," "correctly," "properly," "as expected," "appropriately."
- Structural rather than behavioral: "the table exists," "the service is implemented." An AC must assert **behavior**, not the presence of code.
- A number with no unit or no percentile: "loads quickly," "under a second" (p50? p99?).

Quote the offending AC and rewrite it as an assertion. Showing the fix is the fastest way to make the point land.

### 3. Design coverage — BLOCKER
Walk `DESIGN.md` section by section against the plan's coverage map.

- **A design section with no story and no explicit out-of-scope marker is a silent failure.** It was specified, everyone assumed it was covered, and nobody built it. Nothing else in the system will ever catch this.
- Every §11 DEFERRABLE entry must have a story. Otherwise the gap decays into permanent, unrecorded debt.
- Every numeric target in the design must have a story that **measures** it. An unmeasured target is decoration.

### 4. Orphan stories — MAJOR  *(BLOCKER if it reveals DESIGN.md is wrong)*
A story with no design citation is building something the design never specified. That is either scope creep, or a gap the design missed and the backlog author quietly patched. Both need to be said out loud — the second one means `DESIGN.md` is wrong and every unit brief will keep citing it.

### 5. Layer-shaped stories — BLOCKER
"Build the data layer." "Implement the API." "Set up the frontend."

These cannot be demonstrated, so their acceptance criteria are always structural ("the tables exist"), so they always pass, and they are always where the real work quietly fails to happen. Every story is a **vertical slice** that does something observable.

### 6. Sizing — MAJOR
- Any `L` not marked `L(split)` with its sub-stories named. An `L` that reaches the orchestrator unsplit will be split badly, in the moment, by an agent with no context.
- Any `S` whose acceptance criteria clearly imply a week's work. Mis-sizing compounds: the estimate was the basis for the tier, and the tier sized the harness.

### 7. Tier consistency — MAJOR
Compare the story count to the tier set in `PRD.md`. Tiers are exactly two — `small` and `orchestrated`; the old standard/full distinction no longer exists.

A `small` tier (< ~15 stories) with a 60-story plan means **the harness has already been generated too light**: single-session, inline, no orchestrator, on a build that badly needs one. Conversely, an orchestrated-tier harness on a 12-story plan is ceremony that will get bypassed. Either way, the tier is wrong and it is much cheaper to say so now than after the first session.

### 8. Dispatch units — orchestrated tier only
Skip this check entirely when `PRD.md` says `<!-- TIER: small -->`.

- **Missing `## Dispatch units` section — BLOCKER.** The orchestrated build harness dispatches units, not stories; a plan without them cannot be dispatched at all.
- **U0 missing, or not a vertical slice — BLOCKER.** U0 must be the walking skeleton. If all of U0's stories live in one layer, it is a layer in disguise and the first real run has been deferred to the end of the build again.
- **A story in no unit, or in two units — BLOCKER.** Unassigned work never gets dispatched; doubly-assigned work gets built twice, differently.
- **No integration unit at the end — MAJOR.** The last unit must exercise the assembled whole: every-contract-entry-answers coverage, a real-data run, fixtures crossing every numeric limit the design states, gate red-probing.
- **File trees overlapping another unit's, with no dependency edge — MAJOR.** Two units that own the same tree and could run in parallel will collide in it.
- **Merge-rule violation — MAJOR.** A unit whose stated inputs are another unit's outputs, with no shared-context reason given, should have been merged: "if unit N's agent must re-read unit N−1's output to understand its own job, they are one unit" (ORCHESTRATION.md).
- **Unit count wildly off — MAJOR.** A >40-story backlog in fewer than 5 units, or more than ~20 units, means the sizing rule was not applied.

## Also check

- **Blocking register entries.** If any §11 entry is still BLOCKING, the plan should not exist. That is a **BLOCKER**: `backlog-author` ran when it should have refused, which means some acceptance criteria are invented.
- **Gate alignment.** The plan should not contain stories for gates the stack manifest excluded (a migration story on a project with no migration tool).
- **Foundation ordering.** Nothing should depend on infrastructure no story builds.

## Design self-verification — all tiers

The design document carries mechanically-checkable claims, and by this point nobody has checked them: ~15 defects in one generated design were mechanically detectable before the build started (ORCHESTRATION.md §7, "A finding the kit should absorb"). Three passes, all mechanical:

- **Compile the typed code blocks.** Extract DESIGN.md's typed fences and run them through the stack's own tools — `tsc` for TypeScript interfaces, the DB engine (or at minimum a syntax check) for DDL.
- **Recompute every named golden fixture.** For each fixture with published expected values, recompute those values by hand from the inputs printed beside them, and flag any expected value that is unreachable from its own inputs. This exact failure occurred: a fixture written specifically to catch a wrong implementation was itself wrong, and the natural "fix" would have broken the metric to match the fixture.
- **Chase dangling references.** Fields promised in contracts with no source column; sections citing declarations that don't exist.

**Tool honesty.** Run only what the stack actually provides. If the compiler or DB engine is not available in this environment, report that pass as **SKIPPED, with the reason** — never silently green.

**Routing.** Findings here are design defects, not plan defects. They route back to `design-author` in AMEND mode — through the user gate, as always — **not** to `backlog-author`. Tag them `→ design-author AMEND` in `PLAN_LINT.md` so `setup-project` dispatches the right fixer.

**Scope discipline.** This pass checks only mechanically-decidable things: does it compile, does the arithmetic reach the printed number, does the reference resolve. Whether the design is *good* is a judgment call, and judgment calls stay with `design-author` — do not let this grow into a second design review.

## Output

Write the detail to **`PLAN_LINT.md`** at the repo root. **Number every finding.** The number matters: `setup-project` re-dispatches `backlog-author` to fix them, and it points at findings by number without ever reading your report.

**Return a capped summary (~150 words):** counts by severity, then one numbered line per BLOCKER and MAJOR.

| | |
|---|---|
| **BLOCKER** | Dep cycle · untestable AC · a plan written over a BLOCKING register entry · **an uncovered design section** · **a layer-shaped story** · missing `## Dispatch units` (orchestrated) · U0 missing or not vertical · a story in no unit or two units. |
| **MAJOR** | Orphan story · unsplit `L` · tier mismatch · no integration unit at the end · tree overlap without a dep edge · merge-rule violation · unit count wildly off. |
| **MINOR** | False dep · sizing drift · citation formatting. |

Design self-verification findings use the same severities (a fixture whose published values are unreachable is a BLOCKER — building against it breaks the metric), but carry the `→ design-author AMEND` routing tag instead of pointing at `backlog-author`.

**Setup does not complete with an open BLOCKER, and it does not complete with an open MAJOR either.** Both must be cleared.

Two of these were tempting to call MAJOR, and both are BLOCKERs on purpose:

- **An uncovered design section** is the one failure **nothing else in the system will ever catch.** It was specified, everyone assumed someone would build it, and nobody did. No test fails. No gate fires. You are the only check.
- **A layer-shaped story** always passes review — its acceptance criteria are structural ("the tables exist"), so they are trivially true — and it is always where the real work quietly fails to happen.

**Tier mismatch is a MAJOR that sends the chain backwards, not forwards.** It means the harness at step 5 was sized against a wrong estimate: a `small` harness on an orchestrated-sized build has no orchestrator and no join-point review, on exactly the project that most needs them. Report it loudly. `setup-project` re-forges.

## Guardrails

- **Never edit the plan.** You diagnose; the author fixes. A linter that rewrites its own findings cannot be trusted on the next pass.
- **Quote and rewrite.** For every untestable AC, show the testable version. Abstract criticism of acceptance criteria does not land; a side-by-side does.
- **Expect to find things.** A first-draft backlog of any size carries untestable AC and at least one uncovered design section. Returning "clean" on a plan that has never been linted means you skimmed.

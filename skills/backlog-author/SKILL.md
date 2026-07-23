---
name: backlog-author
version: 0.1.0
description: "Turn DESIGN.md into PLAN.md — epics, stories, sizes, dependencies, and testable acceptance criteria, each citing the design section it implements. On the orchestrated tier, also groups stories into dispatch units. Refuses to run while design-author's verdict is BACKLOG BLOCKED. Step 6 of project setup. Use when the user says 'write the backlog', 'break this into stories', 'plan the build'."
allowed-tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - AskUserQuestion
metadata:
  role: author
  reads: [DESIGN.md (incl. the line-1 GATE banner), OPEN_QUESTIONS.md, STACK.md, PRD.md (TIER marker), PLAN_LINT.md (in FIX mode)]
  writes: [PLAN.md — never SETUP_PROGRESS.md, which setup-project alone owns]
---

# backlog-author — the plan is a contract, not a wish list

## FIX mode (check this first)

If `PLAN.md` already exists and you were dispatched with `plan-lint` findings, you are in **FIX mode**. Read **`PLAN_LINT.md`** and fix the numbered findings **in place**.

**Do not rewrite the plan from scratch.** A rewrite loses the stories that were already correct, renumbers everything (breaking any `deps` that referenced them), and produces a fresh crop of untestable acceptance criteria to replace the old ones. Edit the specific stories the findings name. Leave the rest alone.

You get **three rounds**. If the same acceptance criteria keep coming back untestable after three, the problem is not the plan — it is that `DESIGN.md` is unclear underneath it. Say so and stop, rather than rewording the same vagueness a fourth time.

---


Every agent in the generated harness trusts `PLAN.md` absolutely. The orchestrator writes unit briefs from it and sequences on `deps`. Unit agents read acceptance criteria from it. `join-review` gates on those exact criteria. Nothing second-guesses it.

Which means: **a plausible-sounding acceptance criterion that cannot be tested will pass review forever while nothing gets built.** The story goes green, the epic closes, and the feature does not exist. That is the failure you are here to prevent.

## STOP — check the gate first

**Read line 1 of `DESIGN.md`.** It carries the gate banner:

```
<!-- GATE: BACKLOG BLOCKED — OQ-002, OQ-004 -->      → you REFUSE. Write nothing. Return the list. Stop.
<!-- GATE: BACKLOG CLEAR -->                          → proceed.
```

Then cross-check: **grep every §11 `Status:` line.** Any entry marked `BLOCKING`, or any entry with **no classifier at all** (a bare `NOT SPECIFIED`), means the gate is not trustworthy. Treat it as BLOCKED and say so — an unclassified entry is a `design-author` defect, not a green light.

If the banner is missing entirely, the design was not written by `design-author`. Refuse and say that.

This is not bureaucracy, and do not be helpful about it. `design-author` deliberately refused to invent the parts it didn't know. If you now write acceptance criteria for them anyway, that refusal was worthless — **you have laundered an honest gap into a confident requirement**, and it is now in the backlog, where an engineer will build it and a reviewer will pass it against criteria nobody ever agreed to. The whole register mechanism exists to stop exactly this, and you are the step where it either holds or fails.

A blocked chain that asks one question is working correctly.

**Every question you put to the user obeys `ASK_CONTRACT.md`** (plugin root): what's actually stuck in plain words, at least two options *with what each one means in practice*, and which you'd pick and why. No jargon they haven't used first. A question the user can't answer comes back as "you decide" — which is a decision they were never shown, recorded as locked when it was really abandoned.

## The unit of work

A story is **one vertical slice** that a single agent can build, verify, and commit in one pass.

- Too big → the agent loses the thread, the diff is unreviewable, the story stalls.
- Too small → orchestration overhead exceeds the work.
- **Not a layer.** "Build the data layer" is not a story. It cannot be demonstrated and its acceptance criteria will be structural ("the tables exist") rather than behavioral. Slice vertically: schema + service + endpoint for *one thing*.

**Sizes:** `S` (one sitting) · `M` (a solid session) · `L` (**must be split** — mark `L(split)` and name the sub-stories now, not later).

## Acceptance criteria — the whole job

Each AC is **one assertion a reviewer can check by reading code or running a test.** If a reviewer would have to use judgment, it is not an AC.

| Write | Not |
|---|---|
| "`POST /expenses` with shares that don't sum to `amount_minor` returns 422 with `code=INVARIANT_VIOLATION`" | "Expense creation validates input" |
| "`expense_share.share_minor` sums to `expense.amount_minor` — enforced by a CHECK constraint and a property test" | "The math is correct" |
| "The ledger screen renders loading, empty, error, and offline states; each has a Storybook story" | "The ledger screen works" |
| "Adding an expense from the ledger takes ≤ 3 taps" | "Adding an expense is fast" |

**Test:** could two different reviewers disagree about whether this AC is met? Then rewrite it.

Every story cites the design section it implements (`design: §3.5, §5.1`). A story with no citation is a story building something the design never specified — and that is either scope creep or a gap the design missed. Either way, stop and say so.

## Dependencies

- `deps` are **hard** — the story cannot start until they're done.
- **The graph must be acyclic.** A cycle deadlocks the orchestrator, which will sit there with pending stories and none eligible.
- Do not create false deps. Over-constraining serializes a build that could have run wide.
- Schema before the service that uses it. Service before the endpoint. Endpoint before the screen that calls it. Beyond that, be sparing.

## Coverage — the plan must cover the design

Walk `DESIGN.md` section by section. **Every section is implemented by at least one story, or is explicitly out of scope for v1.**

- Every §3 table → a schema story.
- Every §4 endpoint → a story.
- Every §5 state machine and invariant → a story, **and an AC that tests it**.
- Every §6 screen → a story, with all its states in the AC.
- Every §8 numeric target → a story that measures it. A performance target nobody ever measures is decoration.
- **Every §11 DEFERRABLE entry → a real story**, so the gap gets closed rather than quietly decaying into permanent debt.
- Every §12 gate → wired into CI or a gate skill, not left as an aspiration.

A design section with no story is the most common silent failure here: the design specified it, everyone assumed someone would build it, and nobody did.

## Epics and phases

Group stories into epics along **domain** lines, not layer lines. Order epics so that each one ends at a demonstrable state. Foundation first (repo, schema baseline, auth), then domains, then the cross-cutting work that needs them all.

## Dispatch units — orchestrated tier only

If `PRD.md` carries `<!-- TIER: orchestrated -->`, there is one final authoring step after the stories are written. (On `<!-- TIER: small -->` the plan is unchanged — stop at the coverage map.)

The orchestrated build harness dispatches **epic-sized units, not stories**. Stories stay exactly as written above — IDs, ACs, sizes, deps untouched; they become the checklist *inside* a unit's brief. Your job is to group them into a `## Dispatch units` section in `PLAN.md`.

Each unit carries: an **ID** (`U0`, `U1`, …), a **name**, its **member story IDs**, **the file trees it owns** (read them off the member stories' design citations), its **dependencies on other units**, and a one-line **"why this is one unit"**.

**Sizing.** A unit is as much work as fits one agent's context while staying coherent — usually one architectural layer or one cohesive feature set. A ~60-story backlog should come out around 8–15 units. The merge rule (ORCHESTRATION.md): **"if unit N's agent must re-read unit N−1's output to understand its own job, they are one unit."** Any two units where the second would re-read the first's output get merged, whatever that does to the count.

**U0 is always the walking skeleton** — the thinnest vertical slice through every layer that ends with a runnable artifact a user can see against real data. Name concretely what "runnable" means for this stack: a window opens, a server answers a request, a CLI runs end to end. U0's stories may be thin slices *of* later stories — that is expected, not a defect; note the overlap explicitly on the unit so later units know the skeleton code already exists. This is not optional polish: real data finds defect classes no synthetic fixture can, and a build that defers the first real run is accumulating unpriced risk (ORCHESTRATION.md §2.7).

**The LAST unit is always integration**: every-contract-entry-answers coverage, a run against real data, fixtures crossing every numeric limit the design states, and probing each gate to demonstrate it can go red.

**File trees must be pairwise disjoint wherever units are meant to run in parallel.** Where two units genuinely must touch one tree, add an explicit dependency edge between them instead of sharing it.

## Output — `PLAN.md`

```markdown
# PLAN — <project>

## Phases
PHASE 0 — Foundation
PHASE 1 — <domain>
...

## EPIC-00 — <name>   → design §<refs>
### S-00.1 — <title>   [S]   deps: none   design: §2.1, §3.2
AC:
1. <testable assertion>
2. <testable assertion>

### S-00.2 — <title>   [M]   deps: S-00.1   design: §3.3, §4.2
...

## Coverage map
| Design § | Stories | |
|---|---|---|
| §3.4 expense | S-02.1 | ✓ |
| §11.5 recurring | S-09.1 | ✓ (deferrable gap, scheduled) |
| §7.3 real-time | — | OUT OF SCOPE v1 |

## Dispatch units          ← orchestrated tier only
| ID | Name | Stories | Owns (file trees) | Deps | Why one unit |
|---|---|---|---|---|---|
| U0 | Walking skeleton | S-00.1, S-03.1(thin) | src/... | none | thinnest runnable slice; overlaps S-03.x — skeleton code exists when U3 starts |
| U1 | <layer or feature set> | S-01.1…S-01.4 | src/... | U0 | one migration, one schema |
| U<last> | Integration | S-<...> | test/integration/... | all | contract coverage, real data, limit fixtures, gate red-probes |

## Totals
N stories (N S · N M · N L(split)) across N epics. Tier: <tier>.
```

## Self-check

- [ ] No BLOCKING register entry. (If there is, you should not be here.)
- [ ] Every AC is a single checkable assertion. Two reviewers could not disagree.
- [ ] Every story cites a design section.
- [ ] Every design section has a story, or is explicitly out of scope.
- [ ] Every §11 DEFERRABLE entry has a story.
- [ ] The dep graph is **acyclic**. Trace it.
- [ ] Every `L` is marked `L(split)` with sub-stories named.
- [ ] No story is a layer.
- [ ] Story count is roughly consistent with the tier. If it isn't, the tier was wrong — say so now, because the harness has already been sized to it.
- [ ] Orchestrated tier only: every story sits in exactly one unit · U0 is a vertical slice with its "runnable" named concretely · the last unit is integration · parallel units' file trees are disjoint, with a dependency edge wherever they are not.

## Return (~130 words)

- Story count by size, epic count, phase count.
- **Coverage: N design sections, N with stories, N explicitly out of scope.** Any section with neither is a defect — name it.
- Dep graph: acyclic, confirmed.
- Deferrable register entries scheduled: N.
- Orchestrated tier: unit count, and what U0's runnable artifact concretely is.
- **The story you are least confident is testable as written.** Say which and why — that is the one that will pass review while building nothing.

`setup-project` will now dispatch `plan-lint`. It is not optional, and you cannot skip it — you wrote this plan, which makes you the worst possible judge of whether its acceptance criteria are actually checkable. Every one of them feels obviously testable to the person who just wrote it.

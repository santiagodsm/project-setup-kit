# Project Setup Kit — design contract

**What this is.** A Claude Code plugin you install into an empty repo. It walks you from "I have an idea" to "this repo has a design doc, a locked set of decisions, a backlog, operating rules, and its own build agents." Then it gets out of the way.

**What it is not.** A runtime harness. The harness it *generates* is project-specific and lives in the target repo. Once setup completes, the target project does not depend on this kit.

---

## Locked decisions (do not re-litigate)

**KD-001 — Generator, not framework.**
The kit emits a bespoke harness per project. It does not ship a parameterized universal harness with a config layer. Rationale: a generic scoper that doesn't know your ORM writes vague briefs; the value of a good scoper is precisely that it knows your stack. Baking the specifics in beats parameterizing them.

**KD-002 — Tiered harness output.** *(AMENDED 2026-07-23 — see KD-019 and `HARNESS-REDESIGN.md`.)*
`harness-forge` emits one of two tiers, chosen at setup by build size:

| Tier | Emits | For |
|---|---|---|
| **small** | `CLAUDE.md` + plan + a single build loop. No gates, no subagents. | < ~15 stories. Weekend/side projects. |
| **orchestrated** | `CLAUDE.md` + `orchestrate-build` + `join-review` + `harness-doctor` + manifest gates. Epic-sized dispatch units, full gates at joins only. | ~15+ stories. |

A tier can be upgraded in place later. Rationale: a heavyweight harness on a small project gets bypassed, and **a bypassed harness is worse than none — it lies about what is being checked.**

> **AMENDED 2026-07-23.** The original ladder had three tiers (`small`/`standard`/`full`); `standard`
> and `full` mandated a scoper→implementer→reviewer chain per story (3–7 subagent dispatches each,
> full suite per story, a twice-running multi-gate epic boundary). Measured head-to-head on the same
> product with the same design docs, that harness finished 8 of 62 stories while a hand-run
> epic-unit orchestration finished the whole build in the same elapsed time (~19 dispatches total).
> The per-story granularity pays the context-re-establishment toll per story and leaves no actor
> holding the whole product — the two failure modes recorded in `HARNESS-REDESIGN.md` §1/§1a. Both
> heavy tiers are replaced by `orchestrated` (KD-019).

**KD-003 — Distribution: Claude Code plugin.**
Skills + agents + commands, versioned and installable. Improvements propagate to new projects. Generated harnesses are forked into the target repo and are expected to diverge.

**KD-004 — Fixed section skeleton in the design doc.**
`DESIGN.md` uses a **canonical, fixed** section map (§1–§12), not organic numbering. Rationale: every downstream agent cites sections. A fixed map means the scoper always knows where to look, and citations stay stable across projects.

**KD-005 — `harness-doctor` is a mandatory gate, not an option.**
Every generated harness is doctored before first use. Setup does not complete with an open BLOCKER. Rationale: a harness is a distributed system made of prose and nothing type-checks it. Hand-written harnesses routinely carry load-bearing contradictions (missing tools, orphan artifacts, unreachable gates). Generated ones will be worse, and the failures are silent.

**KD-006 — The incomplete register is the honesty valve.**
`DESIGN.md` §11 lists what is deliberately unspecified. Without a legitimate home for "I don't know yet," a model fills gaps with plausible fiction and every downstream agent inherits it. An empty §11 on a non-trivial project is a **defect**, not a success.

**KD-007 — Setup has its own state file.**
`SETUP_PROGRESS.md`, written after every step. Setup is multi-session. Same lesson the build loop already learned.

**KD-008 — The chain has a mandatory human gate between design and backlog.**
`design-author` classifies every §11 register entry as **BLOCKING** or **DEFERRABLE**, and returns a `BACKLOG BLOCKED` / `BACKLOG CLEAR` verdict. **`backlog-author` refuses to run while blocked.**

Rationale, learned from the first real run: `design-author` correctly refused to invent a dispute mechanism the PRD never specified. That refusal is worthless if `backlog-author` then writes acceptance criteria for the dispute flow anyway — the honesty gets **laundered into fiction one step later**, and now it is in the backlog, where an engineer builds it and a reviewer passes it. The register only works if the gate is enforced, not merely mentioned.

**KD-009 — Design depth scales with build size; the section map does not.**
All twelve `DESIGN.md` sections appear on every project. The **artifacts** (DDL, contracts, state machines, numeric targets) never scale away — they are what make a section citable, and citability is the point. **Prose, rationale, and ADR count** scale with build size.

ADR test: an ADR is warranted only if a competent engineer could plausibly have chosen differently **and** reversal is expensive. Everything else gets written into the section. Manufacturing ADRs buries the three or four that genuinely constrain the build under fifteen that don't, and a later agent cannot tell which is which. **Ten load-bearing ADRs beat thirty comprehensive ones.**

---

**KD-010 — Every cross-step signal is a machine-readable marker in a file, never a return string.**
A verdict that lives only in an agent's return message **evaporates** — the next skill runs in a fresh context and never sees it. So:

| Signal | Marker | Written by | Read by |
|---|---|---|---|
| Build tier | `<!-- TIER: small\|orchestrated -->` in `PRD.md` | `project-brief` (and `setup-project`, **only** on a tier-mismatch re-forge) | `design-author`, `stack-decide` (RE-TIER), `harness-forge`, `plan-lint`, `setup-project` |
| Backlog gate | `<!-- GATE: BACKLOG BLOCKED\|CLEAR -->` on line 1 of `DESIGN.md` | `design-author` | `backlog-author` |
| Register status | `Status: NOT SPECIFIED — BLOCKING\|DEFERRABLE` | `design-author` | `backlog-author`, `plan-lint` |
| Gate manifest | table in `STACK.md` | `stack-decide` (and `harness-forge`, **only** to resolve the `DEFERRED` perf row) | `harness-forge`, `harness-doctor` |

Learned the hard way: the first version put the BLOCKING/DEFERRABLE rule in prose *below* the §11 template an agent actually copies. On the kit's own first test run, all seven register entries came back unclassified, and `backlog-author` would have sailed straight through and invented the very thing `design-author` had honourably refused to invent. **The template is the contract. Prose below it is decoration.**

**KD-011 — `SETUP_PROGRESS.md` has exactly one writer: `setup-project`.**
Every other skill *returns*; the orchestrator records. Multi-writer state is a clobber waiting to happen. The orchestrator creates the file at step 0, before the (long) step-1 interview, so a crash costs at most one step.

**KD-012 — One ADR namespace.**
`stack-decide` numbers from ADR-001 and records its last number. `design-author` continues from there. Two namespaces both starting at ADR-001 means "ADR-003" resolves to two different decisions depending on which file you opened, and both `harness-forge` and the generated `code-review` cite ADRs by number.

**KD-013 — Every *machine* fix loop is capped. Human-gated loops are not.**
`plan-lint` → `backlog-author`: 3 rounds, then ask the user. `harness-doctor` → `harness-forge`: 3 rounds, then report failure. An uncapped "repeat until clean" loop spins forever on a problem it does not understand — a defect class the kit's own skills forbid in the harnesses they generate.

The `BACKLOG BLOCKED` → user → `design-author` AMEND loop is **deliberately uncapped**, and this is not an inconsistency: each iteration requires a human answer, so it cannot spin. The thing being guarded against is an agent retrying against itself, not a person taking three passes to decide what they want.

**KD-014 — `setup-project` dispatches every step as a subagent. It never invokes a skill itself.**
Its tools are `Read/Write/Edit/Agent/Skill/AskUserQuestion/ToolSearch` — **no `Bash`, no `Grep`, no `Glob`** — and a skill's `allowed-tools` **intersects down** with whoever loads it.

So if the orchestrator invoked a step directly: `scaffold` could not run the check command. `stack-decide` could not search, and would lock a stack from stale training data. `harness-doctor` could not grep, glob, or run git — silently disabling four of its thirteen checks, and it would report **CLEAN on a harness it never inspected.**

Every one of those failures is silent. The skill runs, produces plausible output, reports success. Dispatching every step is what keeps the orchestrator's context flat *and* gives each skill its full toolset. The two goals point the same way.

**KD-015 — Tier changes must rebuild the gate manifest, not just the tier marker.**
Manifest rows are tier-conditioned *at write time*. A tier-mismatch re-forge that rewrites `<!-- TIER -->` but not `STACK.md` produces a **gateless "standard" harness** — `harness-forge` reads "only the gates in the manifest," finds none; `harness-doctor` compares that harness against the same stale manifest and pronounces it CLEAN. Three independent checks, all agreeing, all wrong. Hence `stack-decide`'s RE-TIER mode, and hence the four-step loop-back.

**KD-016 — Every gate that waits on a human pushes to the human. And the question has a fixed shape.**

The kit is built on gates that stop rather than guess (KD-003, the `BACKLOG BLOCKED` verdict, the blocker protocol). Each one produces a *stopped run waiting on a person* — and **a stopped run is externally indistinguishable from a finished one.** The observed failure is not that the gate didn't fire; it is that it fired at 2am, nobody knew, and hours later a human told the next agent to carry on past it. The gate worked and cost nothing.

So the channel is part of the harness, not an add-on: `scripts/notify.sh` (Pushover), copied into every generated repo, called by whoever *discovers* the blocker. `setup-project` has no `Bash` and delegates the push exactly as it delegates every step (KD-014). *(AMENDED 2026-07-23: the original rule also stripped `Bash` from the generated build orchestrator at every tier. KD-019 reverses that for the `orchestrated` tier — its orchestrator holds the full contract and runs join gates itself, so it has full tools and calls `notify.sh` directly. The no-Bash restriction now binds `setup-project` only.)*

Three consequences that are decisions, not details:

- **`ASK_CONTRACT.md` is enforced, not documented.** `notify.sh ask` exits 2 without *what's stuck*, *two options with their real consequences*, and *a recommendation*. A question that can't be answered from a lock screen doesn't get answered — it gets *"you decide"*, which is a decision the user was never shown, recorded downstream as **locked** when it was abandoned. That is the same laundering failure KD-003 exists to prevent, arriving through the question instead of the design. The no-jargon rule is the part nothing can check mechanically and the part that decides whether a reply comes.
- **Delivery never fails a caller.** `ask`/`info`/`hook` exit 0 on any delivery error. A notifier that can fail a build halts it for a reason unrelated to the code, and that failure reads as a product defect. `selftest` is the only loud mode, and `harness-doctor` check 12 audits the wiring — because a broken channel fails *silently in both directions*, which is precisely the defect class the doctor exists for.
- **Exactly one `Notification` hook, installed globally by the user.** Generated repos deliberately emit none. A per-project hook fires on top of the global one; a channel that buzzes twice for nothing gets muted, and then it is not there the one time it mattered.
- **The channel fires only when something is required of the user, and once per stop.** The hook filters to Claude-is-waiting payloads and drops everything else; `ask` bundles a multi-question stop into one `--count N` summary push rather than one push per question. Both guard the same asset: a channel that buzzes for nothing — or five times for one thing — gets muted, and then it is not there the one time it mattered. The per-question detail (options, implications, recommendation) lives at the terminal and in `OPEN_QUESTIONS.md`; the push is the doorbell, not the questionnaire.


**KD-017 — Parallelism is ON by default, and derived from the isolation `scaffold` built. It is never a constant.**

The templates were extracted from a build whose tests all shared one database, so they hardcoded `Parallelism — DISABLED`, with the stated unblock condition *"per-worker DB isolation, plus a scoper-reported touches-DB flag."*

**Both halves of that condition were satisfied elsewhere in this kit and nothing connected them.** `scaffold` (step 4) makes per-worker isolation a hard gate — it is called "the single constraint that determines whether the harness can ever run stories in parallel." The scoper's return already carried `touches DB`. So `harness-forge` (step 5) was emitting a permanent serialization whose reason had been removed one step earlier, on every project, forever.

This is the same defect class as an unrunnable gate (KD-004), inverted: **a constraint that outlived its cause.** And it is worse to detect, because an unrunnable gate at least reports something false, while a needlessly serial build reports nothing at all — it just takes three times as long, and every session assumes the last one had a reason.

So the policy is **resolved, like the gate manifest**: `harness-forge` reads what `scaffold` actually built and emits `{{MAX_PARALLEL}}` plus one of three literal `{{DB_PARALLEL_RULE}}` sentences — the third of which **names itself as a defect**, because a harness that quietly serializes is one nobody ever fixes.

Four conditions gate a pair of in-flight stories: **no dependency edge · disjoint file sets · at most one migration-authoring story · concurrent suites isolated.** Three notes on the shape:

- **Scopers are unconditionally parallel.** Read-only, one brief file each. This is free throughput nobody was taking, and it is also load-bearing: the `Files:` lines it returns are what make the other decision possible at all. The mechanism that enables concurrency is the same one that makes it safe.
- **A failing condition costs one story, not the batch.** Dropping everything to serial on one vague brief is how a default quietly reverts to the old behavior.
- **Migrations serialize even under perfect test isolation.** The conflict is two revisions chaining off one head in a shared *source* directory — not shared data. Isolation is the wrong fix and would look like it worked.

**Background dispatch is the execution path, and it is part of the decision.** `run_in_background: true` on every subagent the generated harness launches. Without it the policy above is nominal: a synchronous dispatch blocks until that agent returns, so "up to `{{MAX_PARALLEL}}` concurrent" runs strictly one-at-a-time while every file still reads as parallel. **Nothing detects that** — no gate fails, no report lies, the build is just N times slower than it claims, which is the same invisibility that let the original ban survive. A policy stated without its mechanism is not a weaker version of the policy; it is the *appearance* of one, which is worse, because it stops anyone from looking.

Two corollaries follow and are stated wherever the rule is: **a launch confirmation is not a result** (a story is `done` when its return is recorded, never when its dispatch succeeded), and **barriers drain first** (a gate or a handoff requires nothing left `in_progress` — a full-suite run against a tree three engineers are still writing to describes a state that never existed, and the dangerous direction is a false GREEN closing a boundary on unfinished work).

**`setup-project` is deliberately the exception and dispatches its own chain synchronously.** Its steps are strictly sequential — each one's output is the next one's input — so background dispatch buys no wall-clock and risks advancing before a step finished, which is the failure that skill exists to prevent. The rule is one rule in both places: *dispatch in the background exactly when there is other work to do meanwhile.* Only its notify-only dispatch is backgrounded, since nothing waits on a push.

**`Files: UNKNOWN` is a first-class answer.** A wrong file set is worse than an admitted one: `UNKNOWN` is handled correctly, a wrong one is trusted. Same principle as §11's register — an honest gap needs a legitimate home, or it gets laundered into a confident claim one step downstream.

> **AMENDED 2026-07-23.** The mechanics above predate KD-019 and name story roles that no longer
> exist. The decision itself stands unchanged — parallelism ON by default, derived from scaffold's
> isolation, background dispatch, launch-confirmation-is-not-a-result, barriers drain first — but
> the unit of scheduling is now the **dispatch unit**, and the file sets compared for disjointness
> are the units' owned trees declared in `PLAN.md` → `## Dispatch units` (written by
> `backlog-author`), not per-story scoper returns. Units whose trees are meant to run in parallel
> must be pairwise disjoint by construction; migrations still serialize.

**KD-018 — Agents hand off files and pointers, never payloads. Disclosure is scoped to the consumer.**

The kit's spine already has this shape: briefs, evidence, and reviews live on disk; returns are capped summaries; the orchestrator passes paths and has no tools to read what it shouldn't. KD-010 governs cross-step *signals* (markers in files) but says nothing about *payloads* — which is why the same handoff pattern got reinvented five times with five naming conventions and no shared rule. KD-018 names the rule the tiers were independently implementing, and closes the gaps it exposes.

**The threshold — when content may travel inline instead of as a file.** A payload rides in a message only when all three hold: it is **bounded** (roughly a paragraph, never open-ended), it crosses **exactly one hop**, and the sender **already holds it in context**. Everything else is a file plus a pointer. This is why the `standard` tier pastes a regression finding into the scoper's dispatch prompt (the gate's capped return is already in the orchestrator's context — a pointer would be indirection for nothing) while `full` builds `source: <report>, finding #N` pointers (fix-stories outlive the session that minted them). One rule, two correct applications; neither tier is the "pure" one, and flattening them into "always a file" would be a regression. The same threshold legitimizes `setup-project`'s fix loops carrying numbered findings inline: bounded, one hop, already held.

**Dispatch prompts are contracts, symmetric to returns.** Return caps govern the inbound half of every handoff; nothing governed the outbound half. So: every dispatch carries the **role**, the **story/task ID**, the **paths** the callee must read, and the **inline values the callee cannot get from disk** (a pasted gate finding, a `model:`, plain-language ask wording). Nothing else — never the contents of a file that is on disk, never the backlog, never prior-story history. A prompt that pastes what a path could carry defeats the same design the return caps protect, from the other direction — and nothing detects it, because the work still succeeds; the orchestrator's context just stops being flat.

**Disclosure is per-section, not per-file.** A handoff file declares which sections are whose contract, and the section headers are the mechanism. The brief already does this implicitly: the reviewer's contract is `AC`, `FILES`, and `VERIFY WITH`; `FACTS THE ENGINEER NEEDS` and `REUSE THESE SEAMS` exist for the engineer alone. Making that explicit costs one line per file. Reading beyond your contract is not an error the way writing beyond scope is — but a consumer that *needs* a section outside its contract is the signal the file is mis-factored, and that signal only exists if the contract is written down.

**A handoff artifact is a primitive: ID-keyed name, exactly one writer, a stated lifecycle.** And the corollary that is a live defect today: **anything load-bearing must live in a *tracked* file.** The `full` tier declares the `source:` pointer "the only place the fix-story's acceptance criteria exist" — and it points into a gitignored directory. A clean clone silently loses the AC of every open fix-story. So: the state-file line for a repair/fix story carries the finding's text (one line, tracked, already in the orchestrator's hands from the gate's return); the report pointer stays as audit trail, never as the sole copy. Ephemeral evidence may be untracked; acceptance criteria may not.

**The doctor audits excess, not only sufficiency.** Check 4 asks whether a producer's return carries everything its consumer needs. Its inverse — a return or dispatch prompt carrying what a file already holds — is this KD's rot mode, and it is invisible by construction: nothing fails, context just grows until sessions shorten. A framework whose violations are silent gets exactly one defense here, and it is the doctor.

> **AMENDED 2026-07-23 — the unit-brief carve-out (KD-019).** In the `orchestrated` tier, the
> dispatch brief for a unit travels **in the dispatch prompt**, not as a file. It is the
> orchestrator's own synthesis (traps, boundaries, escalation triggers) — already held in context,
> crossing exactly one hop — plus *pointers* into `PLAN.md`/`DESIGN.md` for everything on disk.
> The threshold above still governs: a brief that pastes design sections or story ACs a path could
> carry violates this KD exactly as before. The tier-specific examples above (`standard` pasting a
> regression finding, `full` building `source:` pointers) describe retired tiers; the rule they
> illustrated is unchanged.

**KD-019 — The `orchestrated` tier: epic-sized units, a contract-holding orchestrator, gates at joins.**
*(2026-07-23. Replaces the `standard` and `full` tiers. Evidence and full rationale:
`HARNESS-REDESIGN.md`; the source methodology is the build recorded in the Claude Lens repo's
`ORCHESTRATION.md`.)*

The dominant cost in agentic builds is **context re-establishment**, not work: every agent boundary
pays a large fixed cost to load context. A harness that dispatches per story pays it per story —
and per-story acceptance criteria are all locally satisfiable while the point of the product lives
between stories, so a story-granular build can go all-green and still miss what the app is for.
The generated harness therefore:

1. gives the orchestrator **full tools** and has it read the entire design contract once, up front
   — it writes section-cited briefs, rules on escalations in one round trip with a citation, and
   amends `DESIGN.md` with dated rulings (the inverse of the retired tool-starved dispatcher);
2. dispatches **epic-sized units** from `PLAN.md` → `## Dispatch units` (merge rule: *if unit N's
   agent must re-read unit N−1's output to understand its own job, they are one unit*) — roughly
   10–15 units for a ~60-story backlog, stories surviving as the checklist inside a unit;
3. builds a **walking skeleton first** (U0: the thinnest vertical slice that runs against real
   data) and keeps it runnable — real data finds defect classes no synthetic fixture can, and every
   week the user cannot look at the product is unpriced risk;
4. runs **full gates at join points only** (unit agents verify with scoped commands); one
   composite-diff `join-review` per join replaces per-story independent review — measured, the
   join-point composite caught real defects that 22 consecutive per-story first-pass PASSes missed,
   so review earns its cost exactly once per join;
5. ends with an **integration unit**: an exhaustive "every contract entry answers" test, a
   real-data run, fixtures that cross every numeric limit the design states, and gate red-probing.

What was deliberately kept from the retired tiers: independent review (moved to joins), the
notification channel, the state-file single-writer rule, capped fix loops, and the design-doc
citation discipline. What was deliberately dropped: per-story scoper/reviewer dispatches, evidence
files, fix-story minting, and the twice-running epic-gate chain — the measured cost centers.

---

## The chain

Order is the product. Each step is an input to the next; running them out of order gives you a backlog written against a design that was never decided.

| # | Skill | Produces | Gate | On failure |
|---|---|---|---|---|
| 0 | `setup-project` | `SETUP_PROGRESS.md` | — | — |
| 1 | `project-brief` | `PRD.md` + `<!-- TIER -->` | tier marker present | — |
| 2 | `stack-decide` | `STACK.md` (ADRs, check command, gate manifest) | manifest emitted | — |
| 3 | `design-author` | `DESIGN.md` (§1–§12) + `<!-- GATE -->` | `BACKLOG CLEAR` | → user → `design-author` **AMEND** → recheck |
| 4 | `scaffold` | The repo + the check command | green from cold **and** red when broken | re-dispatch (3 rounds), then ask the user |
| 5 | `harness-forge` | `CLAUDE.md` + `.claude/**` | `harness-doctor`: zero BLOCKERs | 3 rounds, then fail |
| 6 | `backlog-author` | `PLAN.md` (+ `## Dispatch units` on the orchestrated tier) | refuses unless step 3 is CLEAR | — |
| 7 | `plan-lint` | `PLAN_LINT.md` | zero BLOCKERs **and zero MAJORs** | → 6 **FIX mode** (3 rounds) · tier mismatch → **1 → 2 (RE-TIER) → 5 → 7** |
| 8 | seed + `harness-doctor` | first story in the state file | zero BLOCKERs | → **5** with the numbered findings (3 rounds), then fail |

**Step 8 is not a repeat of step 5.** At step 5 no `PLAN.md` existed, so the build state file was emitted as a stub pointing at nothing. Step 8 seeds it with the first real story and doctors the *assembled* repo — harness plus plan plus state. It is the only pass that sees the whole thing.

Setup is done when 7 and 8 are clean. Then: run the generated harness.

---

## Where this fails, if it fails

**`design-author` (§3 of the chain) is the load-bearing risk.** Every later agent cites `DESIGN.md`. An LLM will cheerfully produce a design doc that reads beautifully and has no citable structure, no locked decisions, and no honest register of gaps — and **nothing will tell you.** Every downstream agent just quietly gets worse. This is why we build it first and judge it hardest.

**`backlog-author` is second.** Plausible-sounding acceptance criteria that can't be tested means stories pass review forever while building nothing. `plan-lint` exists for this and is not optional.

---

## Build order

1. `design-author` — risk-first. Prove the output is genuinely citable before building seven skills around it.
2. `harness-doctor` — needed before anything is generated, so we can verify what we generate.
3. `harness-forge` + the tier templates.
4. `scaffold`.
5. `project-brief` + `stack-decide` (the interview; more effort here than in any generator).
6. `backlog-author` + `plan-lint`.
7. Prove it end to end on a real (if small) project.

**Test target:** a deliberately throwaway project — but one that is *small in scope and real in structure*. It must have a database, an API, at least one non-obvious architectural decision, and at least one genuinely undecided thing. A toy with none of those tests nothing.

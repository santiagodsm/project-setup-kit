# Project Setup Kit — design contract

**What this is.** A Claude Code plugin you install into an empty repo. It walks you from "I have an idea" to "this repo has a design doc, a locked set of decisions, a backlog, operating rules, and its own build agents." Then it gets out of the way.

**What it is not.** A runtime harness. The harness it *generates* is project-specific and lives in the target repo. Once setup completes, the target project does not depend on this kit.

---

## Locked decisions (do not re-litigate)

**KD-001 — Generator, not framework.**
The kit emits a bespoke harness per project. It does not ship a parameterized universal harness with a config layer. Rationale: a generic scoper that doesn't know your ORM writes vague briefs; the value of a good scoper is precisely that it knows your stack. Baking the specifics in beats parameterizing them.

**KD-002 — Tiered harness output.**
`harness-forge` emits one of two tiers, chosen at setup by build size:

| Tier | Emits | For |
|---|---|---|
| **small** | `CLAUDE.md` + plan + a single build loop. No gates, no subagents. | < ~15 stories. Weekend/side projects. |
| **orchestrated** | `CLAUDE.md` + `orchestrate-build` + `join-review` + `harness-doctor` + manifest gates. Epic-sized dispatch units, the whole check run at joins only. | ~15+ stories. |

A tier can be upgraded in place later. Rationale: a heavyweight harness on a small project gets bypassed, and **a bypassed harness is worse than none — it lies about what is being checked.** There is no tier that dispatches per story; KD-019 records why, and the History section at the end of this file records the ladder this replaced.

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

**KD-014: `setup-project` runs the interview in the main session and dispatches everything else, for context flatness.**
*(Rewritten 2026-10-25, kit v0.7.0. The v0.6 text is under History.)*

Steps 1 (`project-brief`), 2 (`stack-decide`) and the ask pass of step 3 (`design-author`) run in the main session: `setup-project` invokes the skill directly with `Skill`. Claude Code removes the tool that asks the user a question from every subagent, so a dispatched interview can never ask; it guesses, or marks the gap BLOCKING. The main session is the only one that can ask, so the steps whose job is asking run there. The ask pass writes nothing itself: `setup-project` records its answers under `SETUP_PROGRESS.md` "Decisions locked" and stays the file's only writer (KD-011). If `OWNER_BRIEF.md` exists at the project root, every asking step reads it instead and says so.

The design write pass, every AMEND, and steps 4 to 8 are dispatched, one synchronous `general-purpose` subagent each. The reason is context flatness: each step starts clean, reads its inputs from disk, and returns a capped summary, so none of its file reads enter the orchestrator's context across a chain that spans sessions.

Dispatch is not a tool restriction. A skill's `allowed-tools` pre-approves the tools it lists and restricts nothing (Claude Code docs, skills page: "It does not restrict which tools are available"). A missing entry costs a permission prompt, not a capability. Where a skill must not use a tool, its frontmatter says so with `disallowed-tools` (the report-only `harness-doctor` and `plan-lint` disallow `Edit`). `setup-project` has `Bash` and calls `notify.sh` itself.

**KD-015 — Tier changes must rebuild the gate manifest, not just the tier marker.**
Manifest rows are tier-conditioned *at write time*. A tier-mismatch re-forge that rewrites `<!-- TIER -->` but not `STACK.md` produces a **gateless harness** — `harness-forge` reads "only the gates in the manifest," finds none; `harness-doctor` compares that harness against the same stale manifest and pronounces it CLEAN. Three independent checks, all agreeing, all wrong. Hence `stack-decide`'s RE-TIER mode, and hence the four-step loop-back.

**KD-016 — Every gate that waits on a human pushes to the human. And the question has a fixed shape.**

The kit is built on gates that stop rather than guess (KD-003, the `BACKLOG BLOCKED` verdict, the blocker protocol). Each one produces a *stopped run waiting on a person* — and **a stopped run is externally indistinguishable from a finished one.** The observed failure is not that the gate didn't fire; it is that it fired at 2am, nobody knew, and hours later a human told the next agent to carry on past it. The gate worked and cost nothing.

So the channel is part of the harness, not an add-on: `scripts/notify.sh` (Pushover), copied into every generated repo, called by whoever *discovers* the blocker. `setup-project` calls it with `Bash` for a stop it discovers itself; a dispatched step pushes its own stop before returning (KD-014). The generated orchestrator has every tool (KD-019) and calls `notify.sh` directly, as does the small-tier builder.

Three consequences that are decisions, not details:

- **`ASK_CONTRACT.md` is enforced, not documented.** `notify.sh ask` exits 2 without *what's stuck*, *two options with their real consequences*, and *a recommendation*. A question that can't be answered from a lock screen doesn't get answered — it gets *"you decide"*, which is a decision the user was never shown, recorded downstream as **locked** when it was abandoned. That is the same laundering failure KD-003 exists to prevent, arriving through the question instead of the design. The no-jargon rule is the part nothing can check mechanically and the part that decides whether a reply comes.
- **Delivery never fails a caller.** `ask`/`info`/`hook` exit 0 on any delivery error. A notifier that can fail a build halts it for a reason unrelated to the code, and that failure reads as a product defect. `selftest` is the only loud mode, and `harness-doctor` check 12 audits the wiring — because a broken channel fails *silently in both directions*, which is precisely the defect class the doctor exists for.
- **Exactly one `Notification` hook, installed once, globally (the plugin ships it).** A generated repo has a `.claude/settings.json` (KD-020), and that file never contains a `Notification` hook. A per-project hook fires on top of the global one; a channel that buzzes twice for nothing gets muted, and then it is not there the one time it mattered.
- **The channel fires only when something is required of the user, and once per stop.** The hook filters to Claude-is-waiting payloads and drops everything else; `ask` bundles a multi-question stop into one `--count N` summary push rather than one push per question. Both guard the same asset: a channel that buzzes for nothing — or five times for one thing — gets muted, and then it is not there the one time it mattered. The per-question detail (options, implications, recommendation) lives at the terminal and in `OPEN_QUESTIONS.md`; the push is the doorbell, not the questionnaire.

**KD-017 — Parallelism is ON by default, and derived from the isolation `scaffold` built. It is never a constant.**

The templates were extracted from a build whose tests all shared one database, so they once hardcoded parallelism as disabled, long after `scaffold` had made per-worker test isolation a hard gate. `harness-forge` was emitting a permanent serialization whose reason had been removed one step earlier, on every project. That is a **constraint that outlived its cause**, and it is worse to detect than an unrunnable gate: a needlessly serial build reports nothing at all, it just takes three times as long, and every session assumes the last one had a reason.

So the policy is **resolved, like the gate manifest**: `harness-forge` reads what `scaffold` actually built and emits `{{MAX_PARALLEL}}` plus one of three literal `{{DB_PARALLEL_RULE}}` sentences — the third of which **names itself as a defect**, because a harness that quietly serializes is one nobody ever fixes.

The unit of scheduling is the **dispatch unit**. Four conditions gate a pair of in-flight units: **no dependency edge · disjoint owned file trees · at most one migration-authoring unit · concurrent suites isolated.** The owned trees are declared per unit in `PLAN.md` → `## Dispatch units` (written by `backlog-author`), so disjointness is decided at planning time, not discovered mid-build; units meant to run together are pairwise disjoint by construction. Two notes on the shape:

- **A failing condition costs one unit, not the batch.** Dropping everything to serial because of one unit is how a default quietly reverts to the old behavior.
- **Migrations serialize even under perfect test isolation.** The conflict is two revisions chaining off one head in a shared *source* directory — not shared data. Isolation is the wrong fix and would look like it worked.

**Background dispatch is the execution path, and it is part of the decision.** `run_in_background: true` on every subagent the generated harness launches. Without it the policy above is nominal: a synchronous dispatch blocks until that agent returns, so "up to `{{MAX_PARALLEL}}` concurrent" runs strictly one-at-a-time while every file still reads as parallel. **Nothing detects that** — no gate fails, no report lies, the build is just N times slower than it claims. A policy stated without its mechanism is not a weaker version of the policy; it is the *appearance* of one, which is worse, because it stops anyone from looking.

Two corollaries follow and are stated wherever the rule is: **a launch confirmation is not a result** (a unit is `done` when its return is recorded, never when its dispatch succeeded), and **barriers drain first** (a gate or a handoff requires nothing left `wip` — a check run against a tree agents are still writing to describes a state that never existed, and the dangerous direction is a false GREEN closing a join on unfinished work).

**`setup-project` is deliberately the exception and dispatches its own chain synchronously.** Its steps are strictly sequential (each one's output is the next one's input), so background dispatch buys no wall-clock and risks advancing before a step finished, which is the failure that skill exists to prevent. The rule is one rule in both places: *dispatch in the background exactly when there is other work to do meanwhile.* It has no notify-only dispatch: it runs `notify.sh` itself with `Bash` (KD-014).

**KD-018 — Agents hand off files and pointers, never payloads. Disclosure is scoped to the consumer.**

Briefs, plans, rulings and reviews live on disk; returns are capped summaries; dispatch prompts carry paths. KD-010 governs cross-step *signals* (markers in files) but says nothing about *payloads*. This KD is the rule for payloads.

**The threshold — when content may travel inline instead of as a file.** A payload rides in a message only when all three hold: it is **bounded** (roughly a paragraph, never open-ended), it crosses **exactly one hop**, and the sender **already holds it in context**. Everything else is a file plus a pointer. Two applications in the current harness:

- **The unit brief travels in the dispatch prompt.** It is the orchestrator's own synthesis (traps, boundaries, unit-specific escalation triggers), already held in context, crossing exactly one hop, plus *pointers* into `PLAN.md`/`DESIGN.md` for everything on disk. A brief that pastes design sections or story acceptance criteria a path could carry violates this KD.
- **Join-review findings ride inline into a follow-up dispatch.** The review's numbered, capped return is already in the orchestrator's context and goes one hop to the owning unit's agent; a pointer would be indirection for nothing. The same threshold legitimizes `setup-project`'s fix loops carrying numbered findings inline.

**Dispatch prompts are contracts, symmetric to returns.** Return caps govern the inbound half of every handoff; dispatch contracts govern the outbound half. Every dispatch carries the **role**, the **unit or task ID**, the **paths** the callee must read, and the **inline values the callee cannot get from disk** (a pasted finding, a `model:`, plain-language ask wording). Nothing else — never the contents of a file that is on disk, never the backlog, never prior-unit history. A prompt that pastes what a path could carry defeats the return caps from the other direction, and nothing detects it, because the work still succeeds; the orchestrator's context just stops being flat.

**Disclosure is per-section, not per-file.** A handoff file declares which sections are whose contract, and the section headers are the mechanism. `PLAN.md` is the example: `## Dispatch units` is the orchestrator's contract, each story's acceptance criteria are the unit agent's. Reading beyond your contract is not an error the way writing beyond scope is — but a consumer that *needs* a section outside its contract is the signal the file is mis-factored, and that signal only exists if the contract is written down.

**A handoff artifact is a primitive: ID-keyed name, exactly one writer, a stated lifecycle.** And the corollary: **anything load-bearing must live in a *tracked* file.** Join-review and doctor reports are gitignored, so a fresh clone loses them; the load-bearing finding text therefore reaches the tracked state file through the review's return (one line per finding, written by the orchestrator), and the report path stays as audit trail, never as the sole copy. Ephemeral evidence may be untracked; acceptance criteria and rulings may not.

**The doctor audits excess, not only sufficiency.** Check 4 asks whether a producer's return carries everything its consumer needs. Its inverse — a return or dispatch prompt carrying what a file already holds — is this KD's rot mode, and it is invisible by construction: nothing fails, context just grows until sessions shorten. A framework whose violations are silent gets exactly one defense here, and it is the doctor.

**KD-019 — The `orchestrated` tier: epic-sized units, a contract-holding orchestrator, gates at joins.**
*(2026-07-23. Replaces the `standard` and `full` tiers. Evidence and the whole rationale:
`HARNESS-REDESIGN.md`; the source methodology is the build recorded in the Claude Lens repo's
`ORCHESTRATION.md`.)*

The dominant cost in agentic builds is **context re-establishment**, not work: every agent boundary
pays a large fixed cost to load context. A harness that dispatches per story pays it per story —
and per-story acceptance criteria are all locally satisfiable while the point of the product lives
between stories, so a story-granular build can go all-green and still miss what the app is for.
The generated harness therefore:

1. gives the orchestrator **every tool** and has it read the entire design contract once, up front
   — it writes section-cited briefs, rules on escalations in one round trip with a citation, and
   amends `DESIGN.md` with dated rulings (the inverse of the retired tool-starved dispatcher);
2. dispatches **epic-sized units** from `PLAN.md` → `## Dispatch units` (merge rule: *if unit N's
   agent must re-read unit N−1's output to understand its own job, they are one unit*) — roughly
   10–15 units for a ~60-story backlog, stories surviving as the checklist inside a unit;
3. builds a **walking skeleton first** (U0: the thinnest vertical slice that runs against real
   data) and keeps it runnable — real data finds defect classes no synthetic fixture can, and every
   week the user cannot look at the product is unpriced risk;
4. runs **the whole check at join points only** (unit agents verify with scoped commands); one
   composite-diff `join-review` per join replaces per-story independent review — measured, the
   join-point composite caught real defects that 22 consecutive per-story first-pass PASSes missed,
   so review earns its cost exactly once per join;
5. ends with an **integration unit**: an exhaustive "every contract entry answers" test, a
   real-data run, fixtures that cross every numeric limit the design states, and gate red-probing.

What was deliberately kept from the retired tiers: independent review (moved to joins), the
notification channel, the state-file single-writer rule, capped fix loops, and the design-doc
citation discipline. What was deliberately dropped: per-story scoper/reviewer dispatches, evidence
files, fix-story minting, and the twice-running epic-gate chain — the measured cost centers.

**KD-020 — Generated harnesses enforce their own load-bearing rules mechanically. And enforcement never adds a test run.**
*(2026-10-24, kit v0.6.0.)*

Every rule in a generated harness used to be prose. `harness-doctor` can audit prose once, at setup, but nothing stopped a unit agent from violating it at runtime, and an agent fails silently and unpredictably where a tool fails the same way every time. So `harness-forge` emits an enforcement layer from `templates/enforcement/` (both tiers):

- **`.claude/settings.json`.** A PreToolUse guard on Edit/Write, a PostToolUse formatter (only when `STACK.md` names a format command), a SessionStart hook on the `compact` source that prints one line telling the agent to re-read `CLAUDE.md` and the state file (the backstop for KD-019's stop rule: Claude Code documents no warning before auto-compaction), and `permissions.deny` rules for force-push, `git reset --hard`, `git commit --no-verify`/`-n`, `git clean`, and reading `.env` files. The deny rules stop the commands an agent normally writes; Claude Code's own docs say they are not a security boundary (`git -C . push --force` gets past them).
- **`.claude/hooks/guard-writes.sh`.** Path checks only: blocks writes to `.env`/`*.env` (not `*.env.example`) and anything under `.git/`.
- **`.claude/hooks/guard-bash.sh`** *(v0.6.1)*. Deny rules are prefix patterns and not a security boundary, so each blocked git or secrets operation is also matched by `guard-bash.sh`, anywhere in a shell command (after `&&` or `;`, inside `sh -c`, behind `git -C`/`-c`). String matching only, under 50 ms, fails closed.
- **`.githooks/pre-commit`**, tracked, activated with `git config core.hooksPath .githooks` by `harness-forge` and re-checked at every session start by both loop skills (a fresh clone loses that setting). It lints the staged files only.
- **The state-file single-writer rule runs at two levels at the orchestrated tier.** Tool level: the hook input carries `agent_id` when the call comes from a subagent, so `guard-writes.sh` blocks any subagent write to the state file. Commit level: `pre-commit` rejects a commit that stages the state file with anything but the design (the orchestrator commits it alone at each join; a mixed commit means a unit agent wrote it). The small tier has neither: its builder commits the state file with every story.
- **The narrowed Notification rule.** A generated repo may have `.claude/settings.json`; it must not contain a `Notification` hook (KD-016).
- `harness-doctor` check 14 (resident check 9) audits that all of it exists, is executable, is wired, and stays inside the budget below.

**The speed budget is part of this decision, and it binds every future edit.** The first harness was unusable because it tested too much: the per-story harness finished 8 of 62 stories in the time an epic-unit build finished everything (`HARNESS-REDESIGN.md` §1). Enforcement must never bring that back:

1. **No new test runs anywhere.** The whole suite runs exactly where it already ran: once per story at small, once per join at orchestrated. Hooks never run tests, never run the check command, never run the affected-test command. A hook or git hook that invokes a test runner is a doctor **BLOCKER**.
2. **Format hook: under 2 seconds**, one file, `timeout: 2`.
3. **Pre-commit: under 15 seconds**, staged files only, measured by `harness-forge` on the scaffolded repo. Lint plus typecheck over 15 seconds → typecheck stays out. Typecheck is in the hook at the small tier only: at orchestrated it covers the whole project while parallel unit agents share one working tree, so one unit's half-written code would reject another's commit. Lint alone over → no lint, only the state-file rule. At runtime each check is also bounded (lint 10 s, typecheck 5 s) and is skipped, not failed, when it runs past its bound.
4. **Guard hook: path checks only, under 100 ms.**
5. **SessionStart hook: prints one line**, reads nothing.
6. **Every hook has a timeout.** A timeout or crash lets the action through, except in the two guards that exist to block: the write guard sets `"onFailure": "block"`, and the state-file rule in `pre-commit` rejects. A formatter or lint failure from a timeout never blocks.
7. **The doctor and red-probes run at setup only**, once, when the harness is forged. Never during the build.

**Why the check command is not in the pre-commit hook, at either tier.** At orchestrated, unit agents commit as they complete coherent steps, several times per unit; a whole-suite check per commit would multiply the suite runs per unit and would contend between parallel agents (the reason KD-019 moved the check to joins). At small, the builder already runs the whole check once per story before committing; running it again on commit would double the test time of every story.

**KD-021 — One owner per rule; reasons stated once.**
*(2026-10-24, kit v0.6.0. Resolves `HARNESS-REDESIGN.md` §4, open question 4.)*

The retired per-story harness carried a long `CLAUDE.md` and a longer orchestration skill that both stated the process ("duplicated authority", `HARNESS-REDESIGN.md` §1). The orchestrated tier still did the same at v0.5: `CLAUDE.md` restated read-the-contract-once, the walking skeleton, parallelism, the ruling procedure and the stop rule, and carried a tiebreak line ("where this file and `orchestrate-build` disagree, `orchestrate-build` wins"). A tiebreak line is the evidence of duplication: it exists because the copies were expected to drift.

So every rule has exactly one owner file:

- **`CLAUDE.md` holds what applies to every prompt**, for the orchestrator and every unit agent alike: the organising principle, project facts, the pinned stack, commands, the invariants (their only copy), the commit format, the unit agents' stop-and-report triggers, "Talking to the user" (KD-022), and the project's definition of done. At the small tier it also states what the tier gave up and the upgrade trigger, which are standing facts about the harness, not loop steps. About 45 lines.
- **The tier skill (`orchestrate-build`, `build-loop`) holds the process**: session start, the loop, joins, drain, parallelism, escalation rulings, the stop conditions. `CLAUDE.md` points to it with one line ("it holds the process") and no tiebreak.
- **`{{PROJECT_STRUCTURE}}` is one line of top-level code directories, never a tree.** Context files that hold what the agent can find for itself add steps and cost (Gloaguen et al., "Evaluating AGENTS.md", ETH Zurich, 2026); briefs already carry owned trees.

**Reasons stay, once.** The original templates said "do not improve or summarize them", on the theory that the reasoning prose is what makes agents comply. That holds for the reason, not for its volume or its repetition. Each rule keeps its reason in one or two sentences, in the file that owns the rule, and the same reason is not repeated across files. `harness-doctor` check 5 (resident check 3) flags a process rule stated in both `CLAUDE.md` and the tier skill as MAJOR even when the copies agree today.

**KD-022 — The harness talks to the user in plain, short language.**
*(2026-10-24, kit v0.6.0.)*

The user's two complaints about agent messages are that they are too long and that they explain with jargon. `ASK_CONTRACT.md` already fixed this for one channel (questions pushed to the phone); nothing governed the rest. So:

- **`COMMUNICATION.md` at the kit root is the one canonical text**: answer first; short by default (progress in three lines at most, no narration or recap); plain words, with a needed term explained in the same sentence; no internal labels without their meaning; the project's own words (the design glossary and the user's words); explanations start from one concrete example from the project; no filler; and exact where it matters (commands, errors, paths and code stay verbatim and complete). It governs messages to the user only. Briefs, subagent reports, commit messages and design amendments stay precise and technical, because their reader is an agent or a future engineer.
- **`harness-forge` copies it, resolved, into a "Talking to the user" section of both generated `CLAUDE.md` files.** The kit's setup chain (`setup-project`, `project-brief`, `stack-decide`, `design-author`) points at `COMMUNICATION.md` instead of copying it, and `ASK_CONTRACT.md` points at it as the general rule, so the two cannot drift (KD-021).
- **Report-back to the user has a fixed shape**, at joins and handoffs (orchestrated) and per story and handoffs (small): what works now in the user's terms, what is left, what needs the user (in the Ask Contract's shape), and one line on anything that went wrong and was fixed, only if it changes what the user should trust. Under about eight lines.
- `harness-doctor` flags a missing section, or a harness file that contradicts it ("explain in detail", "summarize everything you did"), as MINOR.

**Rejected: the "caveman" skill** (`JuliusBrussee/caveman`). It shortens output by dropping articles and writing in fragments, which is shorter but harder to read and makes the jargon problem worse. Independent testing found most of its savings come from having any brevity instruction at all: 23% fewer output tokens against no instruction, only 4% against a plain "be concise" instruction (implicator.ai). Its author advises against it for learning, architecture discussions and debugging unfamiliar errors, which is most of what the user reads from a build.

**Considered, not adopted: a project output style.** Claude Code supports project output styles (`.claude/output-styles/*.md`, selected by `outputStyle` in settings). They change the system prompt rather than adding a user-turn file, but the docs say an output style "doesn't guarantee that something always happens", and a custom style drops Claude Code's built-in coding instructions unless `keep-coding-instructions` is set. Recorded in the v0.6 report as a proposal.

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

**`design-author` (§3 of the chain) is the load-bearing risk.** Every later agent cites `DESIGN.md`. An LLM will happily produce a design doc that reads well and has no citable structure, no locked decisions, and no honest register of gaps — and **nothing will tell you.** Every downstream agent just quietly gets worse. This is why we build it first and judge it hardest.

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

---

## History of amended decisions

Notes and superseded text removed from the decisions above when they were rewritten to one current reading (kit v0.6.0, 2026-10-24). Kept verbatim: they are the record of why each decision reads the way it does.

### KD-002 as of v0.5.0, with its AMENDED 2026-07-23 note

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

### KD-016 as of v0.5.0, with its inline AMENDED 2026-07-23 note

**KD-016 — Every gate that waits on a human pushes to the human. And the question has a fixed shape.**

The kit is built on gates that stop rather than guess (KD-003, the `BACKLOG BLOCKED` verdict, the blocker protocol). Each one produces a *stopped run waiting on a person* — and **a stopped run is externally indistinguishable from a finished one.** The observed failure is not that the gate didn't fire; it is that it fired at 2am, nobody knew, and hours later a human told the next agent to carry on past it. The gate worked and cost nothing.

So the channel is part of the harness, not an add-on: `scripts/notify.sh` (Pushover), copied into every generated repo, called by whoever *discovers* the blocker. `setup-project` has no `Bash` and delegates the push exactly as it delegates every step (KD-014). *(AMENDED 2026-07-23: the original rule also stripped `Bash` from the generated build orchestrator at every tier. KD-019 reverses that for the `orchestrated` tier — its orchestrator holds the full contract and runs join gates itself, so it has full tools and calls `notify.sh` directly. The no-Bash restriction now binds `setup-project` only.)*

Three consequences that are decisions, not details:

- **`ASK_CONTRACT.md` is enforced, not documented.** `notify.sh ask` exits 2 without *what's stuck*, *two options with their real consequences*, and *a recommendation*. A question that can't be answered from a lock screen doesn't get answered — it gets *"you decide"*, which is a decision the user was never shown, recorded downstream as **locked** when it was abandoned. That is the same laundering failure KD-003 exists to prevent, arriving through the question instead of the design. The no-jargon rule is the part nothing can check mechanically and the part that decides whether a reply comes.
- **Delivery never fails a caller.** `ask`/`info`/`hook` exit 0 on any delivery error. A notifier that can fail a build halts it for a reason unrelated to the code, and that failure reads as a product defect. `selftest` is the only loud mode, and `harness-doctor` check 12 audits the wiring — because a broken channel fails *silently in both directions*, which is precisely the defect class the doctor exists for.
- **Exactly one `Notification` hook, installed globally by the user.** Generated repos deliberately emit none. A per-project hook fires on top of the global one; a channel that buzzes twice for nothing gets muted, and then it is not there the one time it mattered.
- **The channel fires only when something is required of the user, and once per stop.** The hook filters to Claude-is-waiting payloads and drops everything else; `ask` bundles a multi-question stop into one `--count N` summary push rather than one push per question. Both guard the same asset: a channel that buzzes for nothing — or five times for one thing — gets muted, and then it is not there the one time it mattered. The per-question detail (options, implications, recommendation) lives at the terminal and in `OPEN_QUESTIONS.md`; the push is the doorbell, not the questionnaire.

### KD-017 as of v0.5.0 (story-era mechanics), with its AMENDED 2026-07-23 note

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

### KD-018 as of v0.5.0 (examples from the retired `standard`/`full` tiers), with its AMENDED 2026-07-23 note

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

### KD-014 as of v0.6.1

Verbatim except one phrase, replaced in brackets so the false claim it named no longer reads as current.

**KD-014 — `setup-project` dispatches every step as a subagent. It never invokes a skill itself.**
Its tools are `Read/Write/Edit/Agent/Skill/AskUserQuestion/ToolSearch` — **no `Bash`, no `Grep`, no `Glob`** — and a skill's `allowed-tools` *[narrows, so the v0.6 text claimed,]* the tools of whoever loads it.

So if the orchestrator invoked a step directly: `scaffold` could not run the check command. `stack-decide` could not search, and would lock a stack from stale training data. `harness-doctor` could not grep, glob, or run git — silently disabling four of its thirteen checks, and it would report **CLEAN on a harness it never inspected.**

Every one of those failures is silent. The skill runs, produces plausible output, reports success. Dispatching every step is what keeps the orchestrator's context flat *and* gives each skill its whole toolset. The two goals point the same way.

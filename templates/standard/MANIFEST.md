# STANDARD-tier harness template — manifest

**Derived from `templates/full/` by subtraction.** The contracts in `full` were paid for by six audit rounds and four real production defects; they are not re-derived here, they are *carried down*. Where a file is unchanged from `full`, that is deliberate.

**For:** ~15–50 stories (KD-002). Multi-session, but not multi-month.

**Do not "improve" these templates by shortening them.** The "here is WHY this rule exists / here is the failure it prevents" prose is what makes an agent comply under pressure. Strip it and you get a harness that gets rationalized past on story 30.

---

## What this tier removed, relative to `full`

| Removed | Consequence | How it is handled here |
|---|---|---|
| **Epic gates** (`regression-run` → `code-review` → fix-stories → `regression-run` → `docs-sync`) | No composite-diff review; no gate ordering to get wrong | A single `regression-run` at each **PHASE** boundary. GREEN → next phase. RED → repair stories → re-run. |
| **`code-review`** | Cross-story seams, security, and a11y are never reviewed as a composite | Per-story review still checks `{{INVARIANTS}}` (step 7 of `story-reviewer`). `regression-run` explicitly owns cross-story interaction. **This is a real reduction in coverage** and is one of the upgrade triggers. |
| **`docs-sync`** | **`{{DESIGN}}` never absorbs a mid-build deviation. Ever.** | **The deviation ledger rule** — see below. This is the load-bearing compensation and the reason this tier is safe at all. |
| **Fix-stories + the `source:` pointer** | No pointer to resolve, no report for the scoper to open | **Repair stories.** The orchestrator pastes `regression-run`'s numbered finding straight into the scoper's dispatch prompt. The finding is already in the orchestrator's context (it came back in the gate's return), so the disk pointer would be indirection for nothing. The anti-invention contract survives: the scoper **refuses to scope rather than invent AC** if the dispatch prompt carries no concrete finding. |
| **`{{HISTORY_FILE}}` / the archive split** | Nothing to archive *to* | One state file. Session-log entries and resolved blockers may be trimmed as they age. **`Decisions & deviations` may not be — ever.** |
| **The stack-conditional gate *skills*** (`db-migration-review`, `api-contract-sync`, `design-token-lint`) | No separate gate files to emit or keep reachable | **Folded inline into `story-reviewer` step 5**, still guarded by the same `{{#IF}}` flags: migration up/down/up on a **scratch DB**; contract regen to a temp dir, **check-only**; token grep on changed components. Same checks, one fewer indirection. |

## The rule that pays for `docs-sync`'s absence

Removing `docs-sync` without compensation would be the sharpest defect in this tier. `story-scoper` reads `{{DESIGN}}` as ground truth for **every** brief; a deviation that never reaches the design means every later brief quotes a superseded spec **with total confidence**, and nothing downstream can notice — the engineer builds the brief and the reviewer checks against the same brief.

So, stated in **four** files (`CLAUDE.md`, `STATE_FILE.md`, `resume-build`, `story-scoper` — skill *and* agent):

1. `{{STATE_FILE}}` → `Decisions & deviations` is the **ONLY** record of mid-build deviation in the project.
2. `story-scoper` **MUST** read it before every brief, and an entry there **beats the design text**. It reports `Overrides applied from the state file: <count>` in its return — that line is the orchestrator's proof the read happened.
3. **NOTHING is ever archived, pruned, or summarized out of that section.** Not at a phase boundary. Not ever.
4. This is a **deliberate trade for a shorter build**, and it **degrades as the ledger grows**. Past ~25 entries the scoper starts skimming and the guarantee evaporates.

**Upgrade trigger (stated in `CLAUDE.md` and `resume-build`):** ledger past ~25 entries · wanting a composite-diff `code-review` · build running well past ~50 stories → **the tier was wrong; regenerate at `full`.** Never hand-bolt a missing gate on: a half-built gate reports green without looking.

`harness-doctor` **check 11** verifies all of the above mechanically.

---

## Files

### Core (always emitted)

| File | What it is |
|---|---|
| `CLAUDE.md.tmpl` | The operating manual. Declares the tier, the orchestrator role, the tool restriction (**no Bash/Grep/Glob**) *and why it is an enforcement mechanism*, the three governing files, **The deviation ledger** (the tier's load-bearing section), the pinned stack, the project invariants, the two-commit model, the per-story loop, the phase boundary, the DO-NOT list, the single stop signal, the skill-trigger table. |
| `STATE_FILE.md.tmpl` | The single source of truth. Sections: NEXT ACTION · Standing operational facts · Session log · **Decisions & deviations (never-archive banner)** · Dependency additions · Blockers · **Phase gates + Repair stories** (with the two-cycle termination bound) · Story status · Progress (incl. deviation-ledger size). |

### Agents (`agents/`) — thin dispatch shims; the skill holds the substance

| File | Tool grant (preserve exactly) |
|---|---|
| `agents/story-scoper.md.tmpl` | `Read, Bash, Grep, Glob, Write, Skill, ToolSearch` — `Bash` for the step-0 state-file commit; `Write` for the brief and nothing else. Carries the ledger rule in its own words. |
| `agents/story-implementer.md.tmpl` | `Read, Write, Edit, Bash, Grep, Glob, Skill, ToolSearch, WebFetch` — the only agent with `Edit`. |
| `agents/story-reviewer.md.tmpl` | `Read, Bash, Grep, Glob, Write, Skill, ToolSearch, WebFetch` — **no `Edit`, deliberately.** A reviewer that fixes the code it judges has destroyed the gate. `Skill` must be present in *both* the agent file and the skill's `allowed-tools`, or the reviewer loses `Skill` the moment it loads its own skill (a real shipped defect). |

The orchestrator has **no agent file** — it is the main session, and its restriction is enforced by `resume-build`'s `allowed-tools: Read, Write, Edit, Agent`.

### Skills (`skills/`) — always emitted; there are no conditional gate skills at this tier

| File | Role |
|---|---|
| `skills/resume-build/SKILL.md.tmpl` | **The authority.** The orchestrator loop. Holds: what this tier is and is not, **the deviation-ledger rule + the upgrade trigger**, the loop, the verification model, the return-contract table, the phase gate + its two-cycle bound, repair stories, the parallelism policy + its four conditions + the back-out condition, per-dispatch models (judgment `opus`, mechanical `sonnet`, chores `haiku`), the single stop signal, the 11 hard rules. |
| `skills/story-scoper/SKILL.md.tmpl` | Step 0 = flush the pending state-file commit (the orchestrator has no git). Then: read design + **the ledger** + code, write `{{BRIEFS_DIR}}<ID>-brief.md`, return ~10 lines incl. the override count. **Flags, never decides.** **Refuses to scope a repair story with no concrete finding rather than invent AC.** |
| `skills/story-implementer/SKILL.md.tmpl` | Commit-only mode (first!) + normal mode. Green-baseline law. Writes **verbatim** check output to `{{REVIEWS_DIR}}<ID>-impl.md` (**overwrite on retry, never append**). **One story = one commit; `--amend` on retry.** Returns hash + ISO date. |
| `skills/story-reviewer/SKILL.md.tmpl` | Audits the engineer's evidence file, re-runs **only diff-affected** tests, runs the **inline** type-specific checks (step 5), checks AC / design-fidelity against `{{INVARIANTS}}` / scope. Never runs the full suite. Never commits. Detects a fragment diff and FAILs it. |
| `skills/regression-run/SKILL.md.tmpl` | The **authoritative** full-suite green gate — and the **only** gate at this tier. Runs at each **PHASE** boundary, ≥2× when red → filenames are `-r<N>`. **Numbered, self-contained findings** (each one *is* a repair story's problem statement) + attribution + **recurrence flag**. |
| `skills/harness-doctor/SKILL.md.tmpl` | The type-checker for the harness itself. **Check 0 = unresolved `{{` / `{{#IF` (BLOCKER)**, then twelve checks — the ten from `full`, plus **check 11: tier integrity** (no archive instruction · scoper reads the ledger · no orphan gate dispatch · the upgrade trigger is present) and **check 12: the notification channel reaches somebody**. Report only; never edits what it diagnoses. |
| `skills/test-authoring/SKILL.md.tmpl` | Level selection. The project's `{{INVARIANTS}}` are the primary property-test candidates. Unchanged from `full`. |

### Gates (`../gates/`) — **none emitted at this tier**

`code-review` and `docs-sync` do not exist here. The stack-conditional gates (`db-migration-review`, `api-contract-sync`, `design-token-lint`, `dependency-security-audit`, `perf-profiling`, `release-runbook`) are **not emitted as skills**; the first three are folded inline into `story-reviewer` step 5 under the same `{{#IF}}` flags. **Emitting a gate skill here without a dispatcher is an unreachable-dispatch BLOCKER** (`harness-doctor` checks 3 and 11).

---

## Placeholders used, by file

One row per placeholder (grouped only where the file sets are identical), grep-verified. `(agent+skill)` marks a placeholder carried by both the agent shim and its skill file.

| Placeholder | Files that use it |
|---|---|
| `{{PROJECT}}` | all files except harness-doctor |
| `{{PROJECT_ONE_LINER}}` `{{PROJECT_STRUCTURE}}` | CLAUDE |
| `{{DESIGN}}` | CLAUDE, STATE_FILE, resume-build, story-scoper (agent+skill), story-implementer, story-reviewer |
| `{{PLAN}}` | CLAUDE, STATE_FILE, resume-build, story-scoper, test-authoring |
| `{{STATE_FILE}}` | CLAUDE, resume-build, story-scoper (agent+skill), story-implementer, story-reviewer, regression-run, harness-doctor |
| `{{BRIEFS_DIR}}` | CLAUDE, STATE_FILE, resume-build, story-scoper (agent+skill), story-implementer, story-reviewer, harness-doctor |
| `{{REVIEWS_DIR}}` | CLAUDE, STATE_FILE, resume-build, story-scoper, story-implementer, story-reviewer (agent+skill), regression-run, harness-doctor |
| `{{CHECK_COMMAND}}` | CLAUDE, STATE_FILE, story-scoper, story-implementer, story-reviewer (agent+skill), regression-run |
| `{{CHECK_PRECONDITIONS}}` | CLAUDE, STATE_FILE, story-implementer, regression-run |
| `{{AFFECTED_TEST_COMMAND}}` `{{LINT_COMMAND}}` `{{TYPECHECK_COMMAND}}` `{{BUILD_COMMAND}}` `{{DB_ISOLATION}}` | story-reviewer |
| `{{FRONTEND_CHECK_COMMAND}}` | story-implementer, regression-run |
| `{{E2E_COMMAND}}` | regression-run |
| `{{STACK_SUMMARY}}` `{{LANGUAGE}}` `{{FRAMEWORK}}` `{{COMMIT_FORMAT}}` `{{DOD_SECTION}}` | CLAUDE |
| `{{BRANCH}}` | CLAUDE, STATE_FILE |
| `{{DATABASE}}` | CLAUDE, test-authoring |
| `{{TEST_FRAMEWORK}}` | CLAUDE, story-implementer, test-authoring |
| `{{MIGRATION_TOOL}}` | CLAUDE, STATE_FILE, resume-build, story-scoper, story-implementer, story-reviewer, regression-run, test-authoring |
| `{{MIGRATION_DIR}}` | CLAUDE, story-implementer |
| `{{MIGRATION_UP}}` `{{MIGRATION_DOWN}}` | resume-build, story-scoper, story-implementer, story-reviewer, regression-run, test-authoring |
| `{{DB_CONTAINER}}` | CLAUDE, STATE_FILE, resume-build, story-reviewer |
| `{{CONTRACT_GEN_COMMAND}}` | story-scoper, story-implementer, story-reviewer, regression-run |
| `{{TOKENS_FILE}}` | CLAUDE, story-scoper, story-implementer, story-reviewer, test-authoring |
| `{{SCHEMA_SECTION}}` | CLAUDE, story-scoper, story-implementer |
| `{{BEHAVIOR_SECTION}}` | CLAUDE, test-authoring |
| **`{{INVARIANTS}}`** | **CLAUDE, story-reviewer (step 7), test-authoring.** The one placeholder that carries the project. Lifted verbatim as *checkable assertions*. With no `code-review` at this tier, `story-reviewer` step 7 is the **only** place the invariants are enforced — a vague `{{INVARIANTS}}` block here is worse than at `full`. If the design gives you nothing concrete, **emit without them and flag the design as the gap.** |
| `{{CODE_DIRS}}` | CLAUDE, resume-build |
| `{{STANDARDS_DOC}}` | CLAUDE, story-scoper, story-implementer, story-reviewer |

**Not used at this tier (do not emit):** `{{HISTORY_FILE}}`, `{{PERF_SECTION}}`, `{{PERF_FIRST_EPIC}}`, `{{LOCKFILES}}`, `{{AUDIT_COMMANDS}}`, and the `{{#IF DEPENDENCY_AUDIT}}` / `{{#IF MCP_SERVERS}}` / `{{#IF PERF_PROFILING}}` / `{{#IF RELEASE_RUNBOOK}}` flags (all their gates are full-tier only). A flag set without its gate file emitted is an unreachable-dispatch BLOCKER. **Used at this tier:** `{{NOTIFY}}` (CLAUDE, resume-build, scoper, implementer, harness-doctor), `{{GLOSSARY_SECTION}}` (CLAUDE, scoper, and reviewer cite the §2.1 glossary) and `{{MODEL_SCOPER}}` / `{{MODEL_IMPLEMENTER}}` / `{{MODEL_REVIEWER}}` (the three agent files).

### Conditional flags in use

`{{#IF MIGRATION_TOOL}}` · `{{#IF CONTRACT_GEN_COMMAND}}` · `{{#IF TOKENS_FILE}}` · `{{#IF STANDARDS_DOC}}` · `{{#IF FRONTEND_CHECK_COMMAND}}` · `{{#IF BUILD_COMMAND}}` · `{{#IF E2E_COMMAND}}` · `{{#IF DATABASE}}`

---

## The load-bearing invariants of this tier

Carried down from `full` unchanged (1–7, 9–12), plus one that is unique to this tier (8).

1. **Orchestrator has no Bash/Grep/Glob.** Not an oversight — the *enforcement mechanism* for "never reads the design, never reads raw test output, never re-runs a gate." Every file that mentions the restriction also says why. Keep both.
2. **Single-writer state file.** The orchestrator writes it; `regression-run` *returns* lines and never writes. Two writers = a clobber mid-story.
3. **Artifact ownership:** scoper writes the **brief**; engineer writes the **evidence**; reviewer writes the **review**; `regression-run` writes its own **numbered report**. Every read has exactly one writer.
4. **Return contracts.** Engineer returns **commit hash + ISO date** (the orchestrator has no clock). `regression-run` returns **numbered findings + report filename**, each finding self-contained enough to *be* a repair story's problem statement.
5. **Two-tier verification.** Engineer runs the full suite **once** → verbatim output to disk. Reviewer **audits that file** and re-runs only diff-affected tests. `regression-run` re-proves repo-wide green at the phase boundary.
6. **One story = one commit; AMEND on retry.** A fix commit fragments the diff, and both the AC check and the out-of-scope check then run against a fragment and pass on nothing.
7. **The scoper's step-0 state-file commit.** The orchestrator writes the state file after the engineer has already committed and has no git; the next scoper is the first Bash-capable agent in the loop.
8. **The deviation ledger is never archived, and the scoper always reads it.** This tier's entire compensation for having no `docs-sync`. See above. The moment either half stops holding, every later brief is built on a superseded design and nothing will tell you.
9. **Loop caps.** Review retry: ×1, then `blocked`. Repair ↔ `regression-run`: **same failure survives 2 cycles → `blocked`** (a repair can pass its own review and still not clear the red; unbounded, you mint a new one forever). Harness forge: 3 rounds.
10. **Single stop signal.** The context/summarization `<system-reminder>`. **There is no story quota and no session cap.** Every soft heuristic fires long before real context pressure and costs a full resume cycle for nothing. `harness-doctor` check 8 greps for reintroduced residue.
11. **Parallelism ON by default, up to `{{MAX_PARALLEL}}`.** Gated on four conditions checked pairwise: no dependency edge · disjoint `Files:` sets from the scoper · one migration-authoring story in flight · concurrent suites isolated (`{{DB_PARALLEL_RULE}}`). **Scopers are always parallel, unconditionally.** **Every subagent is dispatched `run_in_background: true`** — without that the policy has no execution path and runs serial while reading as parallel. Corollaries: a launch confirmation is not a result; gates and handoffs drain every in-flight story first. A story failing a condition waits alone; the batch does not drop to serial. The old "DISABLED until DB isolation" rule was inherited from a build with a shared database — `scaffold` now builds isolation as a hard gate one step earlier, so the ban was enforcing a cost after its danger was gone.
12. **Green-baseline law.** Zero failing tests. A "pre-existing" or "environmental" red is **never** an excuse to pass a story. An environment the standard workflow cannot make green is *itself* the defect.

---

## Could not carry down cleanly

- **`code-review`'s composite-diff pass has no substitute.** Story-level review sees one diff; `regression-run` sees test failures, not code smells. Cross-story security and a11y defects that break no test are **not caught at this tier**. That is the honest cost of `standard`, it is why the upgrade trigger exists, and `{{INVARIANTS}}` in `story-reviewer` step 7 is the only partial mitigation. Do not paper over this in the generated harness.
- **`code-review`'s "read `Decisions & deviations` as an overrides layer" rule** has nowhere to live, since the gate is gone. Its *reasoning* survives in the scoper (an entry beats the design text) — which is where it mattered most anyway.

---

## The notification channel (every tier)

`harness-forge` copies two files into the repo, verbatim from the plugin root, and they are not tier-scaled:

| File | Role |
|---|---|
| `.claude/scripts/notify.sh` | `{{NOTIFY}}`. Pushes an ask to the owner's phone via Pushover. **Refuses to send** an ask missing what's stuck / two options / a recommendation. Never fails its caller: a delivery problem exits 0 and prints to stderr, because a notification that can fail a build stops the build for a reason unrelated to the code. |
| `.claude/ASK_CONTRACT.md` | What a question must contain to be answerable from a lock screen, and the no-jargon rule. Cited by every file that asks the user anything. |

**Who calls it:** whoever *discovers* the blocker — they have `Bash` and they have the detail. **The orchestrator has no `Bash` and must not be given any**; it dispatches a notify-only task, exactly as it dispatches a commit-only task to flush the state file.

**No `Notification` hook is emitted into the repo.** The user installs one globally in `~/.claude/settings.json`; a per-project copy double-fires, and a channel that cries wolf gets muted before the one time it mattered.

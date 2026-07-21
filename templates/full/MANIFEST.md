# FULL-tier harness template — manifest

Extracted from the Hearth harness (56 stories, six audit rounds, four real production defects fixed: a missing tool grant, an orphaned state-file commit, an unreachable gate dispatch, an OOM from concurrent DB migrations). The **structure** is the asset. The Hearth strings are gone; the reasoning behind every rule is not.

**Do not "improve" these templates by shortening them.** The "here is WHY this rule exists / here is the failure it prevents" prose is what makes an agent comply under pressure. Strip it and you get a harness that gets rationalized past on story 30.

---

## Files

### Core (always emitted)

| File | What it is |
|---|---|
| `CLAUDE.md.tmpl` | The operating manual. Declares the orchestrator role, the tool restriction (**no Bash/Grep/Glob**) *and why it is an enforcement mechanism rather than an oversight*, the three governing files, the pinned stack, the project invariants, the two-commit model, the per-story loop, the epic-gate order, the DO-NOT list, the single stop signal, and the skill-trigger table. |
| `STATE_FILE.md.tmpl` | The single source of truth. Sections: NEXT ACTION · Standing operational facts · Session log · **Decisions & deviations** (fold-based archive rule) · Dependency additions · Blockers · Epic gates · **Fix-stories** (with the `source:` pointer contract and the two-cycle termination bound) · Story status · Progress. |

### Agents (`agents/`) — thin dispatch shims; the skill holds the substance

| File | Tool grant (preserve exactly) |
|---|---|
| `agents/story-scoper.md.tmpl` | `Read, Bash, Grep, Glob, Write, Skill, ToolSearch` — `Bash` for the step-0 state-file commit; `Write` for the brief and nothing else. |
| `agents/story-implementer.md.tmpl` | `Read, Write, Edit, Bash, Grep, Glob, Skill, ToolSearch, WebFetch` — the only agent with `Edit`. |
| `agents/story-reviewer.md.tmpl` | `Read, Bash, Grep, Glob, Write, Skill, ToolSearch, WebFetch` — **no `Edit`, deliberately.** A reviewer that fixes the code it judges has destroyed the gate. `Skill` must be present in *both* the agent file and the skill's `allowed-tools`, or the reviewer loses the ability to invoke the type gates the moment it loads its own skill (this was a real shipped defect). |

The orchestrator has **no agent file** — it is the main session, and its restriction is enforced by `resume-build`'s `allowed-tools: Read, Write, Edit, Agent`.

### Skills (`skills/`) — always emitted

| File | Role |
|---|---|
| `skills/resume-build/SKILL.md.tmpl` | **The authority.** The orchestrator loop. Where `CLAUDE.md` and this disagree, this wins. Holds: the loop, the verification model, the return-contract table, the epic-gate order + reasoning in both directions, the fix-story `source:` pointer contract, the parallelism policy + its four conditions + the back-out condition, per-dispatch models (judgment `opus`, mechanical `sonnet`, chores `haiku`), the single stop signal, the 11 hard rules. |
| `skills/story-scoper/SKILL.md.tmpl` | Step 0 = flush the pending state-file commit (the orchestrator has no git). Then: read design + code + `Decisions & deviations`, write `{{BRIEFS_DIR}}<ID>-brief.md`, return ~10 lines. **Flags, never decides.** Refuses to scope a fix-story whose `source:` pointer it cannot resolve rather than invent AC. |
| `skills/story-implementer/SKILL.md.tmpl` | Commit-only mode (first!) + normal mode. Green-baseline law. Writes **verbatim** check output to `{{REVIEWS_DIR}}<ID>-impl.md` (**overwrite on retry, never append**). **One story = one commit; `--amend` on retry.** Returns hash + ISO date. |
| `skills/story-reviewer/SKILL.md.tmpl` | Audits the engineer's evidence file, re-runs **only diff-affected** tests, runs the type gates, checks AC / design-fidelity / scope. Never runs the full suite. Never commits. Detects a fragment diff (engineer added a commit instead of amending) and FAILs it. |
| `skills/regression-run/SKILL.md.tmpl` | The **authoritative** full-suite green gate. Runs ≥2× per epic gate → filenames are `-r1`, `-r2` (a date-based name would clobber the report that live fix-story pointers reference). Numbered findings + attribution + **recurrence flag**. |
| `skills/code-review/SKILL.md.tmpl` | Epic-composite review. **Reads `Decisions & deviations` as an OVERRIDES layer** — without it, every approved deviation gets flagged as drift and an engineer is told to revert correct reviewed code. Numbered, severity-ranked, capped return. |
| `skills/docs-sync/SKILL.md.tmpl` | **LAST in the gate, mandatory.** Folds deviations into `{{DESIGN}}`. Returns folded / not-yet-folded so the orchestrator knows what is safe to archive. Under-reports rather than over-reports. |
| `skills/harness-doctor/SKILL.md.tmpl` | The type-checker for the harness itself. **Check 0 = unresolved `{{` / `{{#IF` (BLOCKER)**, then the ten checks (tool sufficiency · artifact ownership · dispatch reachability · return contracts · doc-vs-skill · path validity · loop termination · early-stop residue · ordering · cross-cutting invariants). Report only; never edits what it diagnoses. |
| `skills/test-authoring/SKILL.md.tmpl` | Level selection. The project's `{{INVARIANTS}}` are the primary property-test candidates. |

### Gates (`../gates/`) — stack-conditional; emit only if the placeholder resolves

Emitting one of these when its placeholder is absent produces a gate that references a command that does not exist, which the agent will improvise past.

| File | Emit only if | If absent |
|---|---|---|
| `gates/db-migration-review/SKILL.md.tmpl` | `{{MIGRATION_TOOL}}` | Drop it, **and strip the schema-story branch from `story-reviewer` step 5.** |
| `gates/api-contract-sync/SKILL.md.tmpl` | `{{CONTRACT_GEN_COMMAND}}` | Drop it, **and strip the contract branch from `story-reviewer` step 5.** |
| `gates/design-token-lint/SKILL.md.tmpl` | `{{TOKENS_FILE}}` | Drop it, **and strip the frontend branch from `story-reviewer` step 5.** |
| `gates/dependency-security-audit/SKILL.md.tmpl` | `{{DEPENDENCY_AUDIT}}` | Drop it, and strip its rows from `resume-build`'s conditional-gate list and return-contract table. |
| `gates/mcp-scan/SKILL.md.tmpl` | `{{MCP_SERVERS}}` | Drop it, and strip its rows from `resume-build`'s conditional-gate list and return-contract table. |
| `gates/perf-profiling/SKILL.md.tmpl` | `{{PERF_PROFILING}}` (needs `{{PERF_SECTION}}` with **numeric** targets) | Drop it. A perf gate with invented targets is worse than none. |
| `gates/release-runbook/SKILL.md.tmpl` | `{{RELEASE_RUNBOOK}}` | Drop it. It is **not** an epic gate either way. |

---

## Placeholders used, by file

### Already in `PLACEHOLDERS.md`

One row per placeholder (grouped only where the file sets are identical), grep-verified. `(agent+skill)` marks a placeholder carried by both the agent shim and its skill file.

| Placeholder | Files that use it |
|---|---|
| `{{PROJECT}}` | CLAUDE, STATE_FILE, all three story roles (agent+skill), resume-build, regression-run, code-review, test-authoring, dependency-security-audit, design-token-lint, perf-profiling, release-runbook |
| `{{DESIGN}}` | CLAUDE, STATE_FILE, resume-build, story-scoper (agent+skill), story-implementer, story-reviewer, code-review, docs-sync, db-migration-review, mcp-scan, perf-profiling |
| `{{PLAN}}` | CLAUDE, STATE_FILE, resume-build, story-scoper, docs-sync, test-authoring, dependency-security-audit, mcp-scan, perf-profiling |
| `{{STATE_FILE}}` | CLAUDE, resume-build, story-scoper (agent+skill), story-implementer, story-reviewer, regression-run, code-review, docs-sync, harness-doctor, dependency-security-audit, mcp-scan, perf-profiling, release-runbook |
| `{{HISTORY_FILE}}` | CLAUDE, STATE_FILE, resume-build, story-scoper, story-implementer, docs-sync |
| `{{BRIEFS_DIR}}` | CLAUDE, STATE_FILE, resume-build, story-scoper (agent+skill), story-implementer, story-reviewer, harness-doctor |
| `{{REVIEWS_DIR}}` | CLAUDE, STATE_FILE, resume-build, story-scoper, story-implementer, story-reviewer (agent+skill), regression-run, code-review, harness-doctor, dependency-security-audit, mcp-scan, perf-profiling |
| `{{CHECK_COMMAND}}` | CLAUDE, STATE_FILE, story-scoper, story-implementer, story-reviewer (agent+skill), regression-run |
| `{{CHECK_PRECONDITIONS}}` | CLAUDE, STATE_FILE, story-implementer, regression-run |
| `{{AFFECTED_TEST_COMMAND}}` `{{LINT_COMMAND}}` `{{BUILD_COMMAND}}` | story-reviewer |
| `{{TYPECHECK_COMMAND}}` | story-reviewer, api-contract-sync |
| `{{FRONTEND_CHECK_COMMAND}}` | story-implementer, regression-run |
| `{{STACK_SUMMARY}}` `{{LANGUAGE}}` `{{FRAMEWORK}}` `{{COMMIT_FORMAT}}` `{{DOD_SECTION}}` | CLAUDE |
| `{{BRANCH}}` | CLAUDE, STATE_FILE |
| `{{DATABASE}}` | CLAUDE, test-authoring, db-migration-review |
| `{{TEST_FRAMEWORK}}` | CLAUDE, story-implementer, test-authoring |
| `{{MIGRATION_TOOL}}` | CLAUDE, STATE_FILE, resume-build, story-scoper, story-implementer, story-reviewer, regression-run, code-review, test-authoring, db-migration-review, release-runbook |
| `{{MIGRATION_DIR}}` | CLAUDE, story-implementer |
| `{{MIGRATION_UP}}` `{{MIGRATION_DOWN}}` | resume-build, story-scoper, story-implementer, story-reviewer, regression-run, test-authoring, db-migration-review, release-runbook |
| `{{DB_CONTAINER}}` | CLAUDE, STATE_FILE, resume-build, story-reviewer, db-migration-review |
| `{{DB_ISOLATION}}` | story-reviewer, db-migration-review |
| `{{CONTRACT_GEN_COMMAND}}` | CLAUDE, resume-build, story-scoper, story-implementer, story-reviewer, regression-run, code-review, api-contract-sync |
| `{{TOKENS_FILE}}` | CLAUDE, resume-build, story-scoper, story-implementer, story-reviewer, code-review, test-authoring, design-token-lint |
| `{{SCHEMA_SECTION}}` | CLAUDE, story-scoper, story-implementer, code-review, db-migration-review |
| `{{BEHAVIOR_SECTION}}` | CLAUDE, test-authoring |
| **`{{INVARIANTS}}`** | **CLAUDE, story-reviewer (step 7), code-review (dimension 3), test-authoring.** The one placeholder that carries the project. Lifted verbatim as *checkable assertions*. If the design gives you nothing concrete, **emit without them and flag it** — a `code-review` full of platitudes reports green without looking. |
| `{{CODE_DIRS}}` | CLAUDE, resume-build |
| `{{STANDARDS_DOC}}` | CLAUDE, story-scoper, story-implementer, db-migration-review |

### Later additions — **defined in `PLACEHOLDERS.md`**

| Placeholder | Source | Example | Used by |
|---|---|---|---|
| `{{PROJECT_ONE_LINER}}` | `PRD.md` one-line pitch | `A private, iPhone-first family-coordination PWA.` | CLAUDE |
| `{{PROJECT_STRUCTURE}}` | `scaffold` — the annotated dir tree | `/backend … /frontend …` | CLAUDE |
| `{{E2E_COMMAND}}` | `STACK.md`, or omit | `npx playwright test` | regression-run, release-runbook |
| `{{LOCKFILES}}` | `STACK.md` | `uv.lock, package-lock.json` | dependency-security-audit |
| `{{AUDIT_COMMANDS}}` | `STACK.md` | `pip-audit, npm audit` | dependency-security-audit |
| `{{PERF_SECTION}}` | `DESIGN.md` — **must contain numeric targets** | `§29.10` | perf-profiling |
| `{{PERF_FIRST_EPIC}}` | `PLAN.md` — first epic with a hot surface | `EPIC-12` | CLAUDE, resume-build, perf-profiling |
| `{{GLOSSARY_SECTION}}` | `DESIGN.md` §2.1 | `§2.1` | CLAUDE, story-scoper, story-reviewer, code-review, mcp-scan |
| `{{MODEL_SCOPER}}` `{{MODEL_IMPLEMENTER}}` `{{MODEL_REVIEWER}}` | forge, by role | `sonnet` / `opus` / `opus` | the three agent files |
| `{{NOTIFY}}` | fixed | `.claude/scripts/notify.sh` | CLAUDE, resume-build, story-scoper, story-implementer, harness-doctor |

### Conditional **flags** (boolean; presence gates a whole gate)

`{{#IF DEPENDENCY_AUDIT}}` · `{{#IF MCP_SERVERS}}` · `{{#IF PERF_PROFILING}}` · `{{#IF RELEASE_RUNBOOK}}`

Set these when the corresponding gate file is emitted. They gate the gate's rows in `resume-build`'s conditional-gate list, its return-contract table, its single-writer list, and `CLAUDE.md`'s trigger table. **A flag set without its gate file emitted, or a gate file emitted without its flag set, is an unreachable-dispatch BLOCKER** — `harness-doctor` check 3 catches it.

### Conditional flags already implied by the contract

`{{#IF MIGRATION_TOOL}}` · `{{#IF CONTRACT_GEN_COMMAND}}` · `{{#IF TOKENS_FILE}}` · `{{#IF STANDARDS_DOC}}` · `{{#IF FRONTEND_CHECK_COMMAND}}` · `{{#IF BUILD_COMMAND}}` · `{{#IF E2E_COMMAND}}` · `{{#IF DATABASE}}`

---

## The load-bearing invariants of the harness itself

Every one of these was paid for by a real defect. If a forge-time edit would break one, it is the edit that is wrong.

1. **Orchestrator has no Bash/Grep/Glob.** Not an oversight — the *enforcement mechanism* for "never reads the design, never reads raw test output, never re-runs a gate." Every file that mentions the restriction also says why. Keep both.
2. **Single-writer state file.** The orchestrator writes it; every gate *returns* lines and never writes. Two writers = a clobber mid-story.
3. **Artifact ownership:** scoper writes the **brief**; engineer writes the **evidence**; reviewer writes the **review**; gates write their own **numbered reports**. Every read has exactly one writer.
4. **Return contracts.** Engineer returns **commit hash + ISO date** (the orchestrator has no clock). Gates return **numbered findings + report filename** (the orchestrator never opens a report and builds every `source:` pointer from the return alone).
5. **Two-tier verification.** Engineer runs the full suite **once** → verbatim output to disk. Reviewer **audits that file** and re-runs only diff-affected tests. `regression-run` re-proves repo-wide green at the epic gate. Halves per-story wall-clock — and makes the evidence-file audit the reviewer's single most important step.
6. **One story = one commit; AMEND on retry.** A fix commit fragments the diff, and both the AC check and the out-of-scope check then run against a fragment and pass on nothing.
7. **The scoper's step-0 state-file commit.** The orchestrator writes the state file after the engineer has already committed and has no git; the next scoper is the first Bash-capable agent in the loop. Without this, `docs(progress):` history silently stops.
8. **Epic gate order:** `regression-run` → `code-review` → fix-stories → `regression-run` again → **`docs-sync` LAST**. Both directions are load-bearing. `code-review` **before** `docs-sync`, or it judges the diff against a design just rewritten to agree with it (fidelity divergence becomes undetectable *by construction*). `docs-sync` **last**, or the fix-stories' own deviations never reach the design and vanish when the epic closes.
9. **`code-review` reads `Decisions & deviations` as an OVERRIDES layer.** It runs *before* `docs-sync`, so the design does not yet contain the epic's approved deviations. Skip that read and it flags every one as drift — and an engineer gets told to revert correct, reviewed code back to superseded DDL. Worse than not running it.
10. **Fold-based archive rule.** A decision leaves the state file **only when `docs-sync` reports it folded into the design.** Not on epic completion. The scoper reads the design + this section and *never* the history file — archive early and every later brief quotes superseded facts with full confidence.
11. **Loop caps.** Review retry: ×1, then `blocked`. Fix-story ↔ regression: **same failure survives 2 cycles → `blocked`** (a fix-story can pass its own review and still not clear the red; unbounded, you mint a new one forever). Harness forge: 3 rounds.
12. **Single stop signal.** The context/summarization `<system-reminder>`. **There is no story quota and no session cap** — the explicit "40+ stories is the expected case" language exists because every soft heuristic ("natural stopping point", "that was a big story") fires long before real context pressure and costs a full resume cycle for nothing. `harness-doctor` check 8 greps for reintroduced residue.
13. **Parallelism ON by default, up to `{{MAX_PARALLEL}}`.** Gated on four conditions checked pairwise: no dependency edge · disjoint `Files:` sets from the scoper · one migration-authoring story in flight · concurrent suites isolated (`{{DB_PARALLEL_RULE}}`). **Scopers are always parallel, unconditionally.** **Every subagent is dispatched `run_in_background: true`** — without that the policy has no execution path and runs serial while reading as parallel. Corollaries: a launch confirmation is not a result; gates and handoffs drain every in-flight story first. A story failing a condition waits alone; the batch does not drop to serial. The old "DISABLED until DB isolation" rule was inherited from a build with a shared database — `scaffold` now builds isolation as a hard gate one step earlier, so the ban was enforcing a cost after its danger was gone.
14. **Green-baseline law.** Zero failing tests. A "pre-existing" or "environmental" red is **never** an excuse to pass a story — the story that surfaces it either fixes it or is `blocked` with the red test named. An environment the standard workflow cannot make green is *itself* the defect.

---

## Could not cleanly parameterize

Two things were generalized rather than mechanically substituted, and the forge should be aware:

- **Hearth's domain invariants** (evidence ladder / SourceBadge, urgency ladder, household isolation, proposals-never-in-confirmed-slots, agent-never-approves-its-own-proposal, typed-service-with-audit-and-outbox-per-write) are collapsed into `{{INVARIANTS}}`. They were *specific and checkable*, which is exactly why they worked. A generated harness whose `{{INVARIANTS}}` block is vague has a `code-review` gate that reports green without looking. Per `PLACEHOLDERS.md`, **do not invent them** — if the design is thin, emit without and flag the design as the gap.
- **Hearth's schema standard** (`§46`: uuidv7 PKs, `household_id`, `version`, audit columns, `archived_at`, CHECK-constrained states, FK RESTRICT, the 4-tier sensitivity taxonomy, the schema-name map) is generalized in `db-migration-review` to "the project's required column set / value set / schema map." The *checklist structure* survives; the concrete column names must come from `{{SCHEMA_SECTION}}` + `{{STANDARDS_DOC}}`. A generated `db-migration-review` whose checklist item 1 still says "the project's required column set" without a `{{STANDARDS_DOC}}` to resolve it is a gate that passes everything.

---

## The notification channel (every tier)

`harness-forge` copies two files into the repo, verbatim from the plugin root, and they are not tier-scaled:

| File | Role |
|---|---|
| `.claude/scripts/notify.sh` | `{{NOTIFY}}`. Pushes an ask to the owner's phone via Pushover. **Refuses to send** an ask missing what's stuck / two options / a recommendation. Never fails its caller: a delivery problem exits 0 and prints to stderr, because a notification that can fail a build stops the build for a reason unrelated to the code. |
| `.claude/ASK_CONTRACT.md` | What a question must contain to be answerable from a lock screen, and the no-jargon rule. Cited by every file that asks the user anything. |

**Who calls it:** whoever *discovers* the blocker — they have `Bash` and they have the detail. **The orchestrator has no `Bash` and must not be given any**; it dispatches a notify-only task, exactly as it dispatches a commit-only task to flush the state file.

**No `Notification` hook is emitted into the repo.** The user installs one globally in `~/.claude/settings.json`; a per-project copy double-fires, and a channel that cries wolf gets muted before the one time it mattered.

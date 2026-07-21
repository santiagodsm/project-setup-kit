# The placeholder contract

Every `{{VAR}}` in `templates/**`. `harness-forge` resolves all of them before writing a file into the target repo.

**An unresolved `{{VAR}}` that reaches the generated harness is a BLOCKER.** Not a cosmetic one: an agent reading `Run {{CHECK_COMMAND}}` will not error. It will infer a plausible command, run it, and report green. The check you believe in has quietly stopped running, and nothing tells you.

`harness-doctor` greps the generated harness for `{{` and fails on any hit. That grep is the last line of defence and it is worth more than it looks.

---

## Resolution table

| Placeholder | Source | Example |
|---|---|---|
| `{{PROJECT}}` | `PRD.md` title | `Tally` |
| `{{TIER}}` | `PRD.md` → `<!-- TIER: x -->` | `standard` — used by forge for tier selection; not substituted into any template |
| **`{{CHECK_COMMAND}}`** | `STACK.md` → "The check command" | `cd backend && make check` |
| `{{CHECK_PRECONDITIONS}}` | `STACK.md` | `starts hearth-pg18 automatically` |
| `{{AFFECTED_TEST_COMMAND}}` | `STACK.md` | `pytest {paths}` |
| `{{LINT_COMMAND}}` | `STACK.md` | `ruff check {files}` |
| `{{TYPECHECK_COMMAND}}` | `STACK.md` | `pyright` |
| `{{FRONTEND_CHECK_COMMAND}}` | `STACK.md`, or omit the block | `npm run lint && vitest && npm run build` |
| `{{BUILD_COMMAND}}` | `STACK.md` | `npm run build` |
| `{{STACK_SUMMARY}}` | `STACK.md`, one line | `Python 3.12 · FastAPI · Postgres 16 · React Native` |
| `{{LANGUAGE}}` / `{{FRAMEWORK}}` / `{{DATABASE}}` | `STACK.md` ADRs | `Python 3.12` / `FastAPI` / `PostgreSQL 16` |
| `{{TEST_FRAMEWORK}}` | `STACK.md` | `pytest + Hypothesis` |
| **`{{MIGRATION_TOOL}}`** | `STACK.md`. **Absent → the migration gate is not emitted at all.** | `alembic` |
| `{{MIGRATION_DIR}}` | `STACK.md` / repo | `backend/alembic/versions/` |
| `{{MIGRATION_UP}}` / `{{MIGRATION_DOWN}}` | `STACK.md` | `alembic upgrade head` / `alembic downgrade base` |
| `{{DB_ISOLATION}}` | `STACK.md` → test isolation | `scratch DB per worker: createdb {{PROJECT}}_review_<ID>` |
| `{{DB_CONTAINER}}` | `scaffold` | `tally-pg16` on :5433 |
| `{{CONTRACT_GEN_COMMAND}}` | `STACK.md`. **Absent → no contract-drift gate.** | `make openapi && npm run generate:api` |
| `{{TOKENS_FILE}}` | `STACK.md`. **Absent → no token lint.** | `tokens.css` |
| **`{{COMMIT_FORMAT}}`** | `STACK.md` / `scaffold` | `build(phase2): <summary> — <STORY-ID>` — **resolve to a literal. No nested placeholder may survive**, or the resolved string carries `{{` into the harness and trips the grep. |
| `{{BRANCH}}` | `scaffold` | `build/main` |
| `{{DESIGN}}` | always | `DESIGN.md` |
| `{{PLAN}}` | always | `PLAN.md` |
| **`{{STATE_FILE}}`** | forge's own choice, by tier | `PROGRESS.md` (small) · `docs/IMPL_PROGRESS.md` (std/full) |
| `{{HISTORY_FILE}}` | full tier only | `docs/IMPL_HISTORY.md` |
| `{{BRIEFS_DIR}}` | forge's choice | `docs/_briefs/` |
| `{{REVIEWS_DIR}}` | forge's choice | `docs/_reviews/` |
| `{{GLOSSARY_SECTION}}` | `DESIGN.md` §2.1 | `§2.1` |
| `{{SCHEMA_SECTION}}` | `DESIGN.md` §3 | `§3` |
| `{{BEHAVIOR_SECTION}}` | `DESIGN.md` §5 | `§5` |
| `{{DOD_SECTION}}` | `DESIGN.md` §12 | `§12` |
| **`{{INVARIANTS}}`** | `DESIGN.md` §5 + §12, verbatim | see below |
| `{{CODE_DIRS}}` | repo | `/backend`, `/mobile` |
| `{{STANDARDS_DOC}}` | `scaffold`, or omit | `backend/docs/db-standards.md` |
| `{{PROJECT_ONE_LINER}}` | `PRD.md` → What | `Shared expense tracking for roommates.` |
| `{{PROJECT_STRUCTURE}}` | repo, confirmed with `ls` | `/backend · /mobile · /infra` |
| `{{E2E_COMMAND}}` | `STACK.md`, or omit | `npx playwright test` — used by `regression-run` / `release-runbook` when the stack has E2E |
| `{{LOCKFILES}}` | `scaffold` | `uv.lock`, `package-lock.json` |
| `{{AUDIT_COMMANDS}}` | `STACK.md` | `pip-audit`, `npm audit` |
| `{{PERF_SECTION}}` | `DESIGN.md` §8 | `§8.1` |
| `{{PERF_FIRST_EPIC}}` | `PLAN.md` | `EPIC-09` |
| **`{{MAX_PARALLEL}}`** | forge, from the isolation `scaffold` built — **`standard` and `full` only; the `small` tier has one agent and nothing to run alongside it, so neither parallelism placeholder appears there** | `3` — concurrent engineers. **3 is the default and the right answer for almost every project.** Raise to 4–5 only when the check command is genuinely fast (< ~60s) and isolation is per-worker; drop to `1` only when `{{DB_PARALLEL_RULE}}` says isolation does not exist *and* every story touches the DB. `1` is a defect being reported, not a configuration. |
| **`{{DB_PARALLEL_RULE}}`** | forge, from `scaffold`'s returned isolation strategy | **Resolve to one literal sentence** stating what is actually true. Three canonical values, below. Never leave it abstract — this sentence is the only place the harness records whether concurrent test runs are safe, and an agent reading a vague one will assume the permissive reading. |
| **`{{NOTIFY}}`** | fixed — the notifier `harness-forge` copies into every repo | `.claude/scripts/notify.sh` — **resolve to the bare path, no backticks and no `./` prefix.** Every template already wraps it (in backticks, or inside a bash block), so a decorated value nests and produces a command that does not run. It is not configurable and not stack-dependent; the file is copied verbatim from the plugin root and the path must match it exactly or every ask silently runs nothing. |
| `{{MODEL_SCOPER}}` | forge, by role (see below) | `sonnet` |
| `{{MODEL_IMPLEMENTER}}` | forge, by role | `opus` |
| `{{MODEL_REVIEWER}}` | forge, by role | `opus` |

## Conditional flags

Set by `harness-forge` from `STACK.md`'s gate manifest. **A flag set without its gate emitted (or the reverse) is an unreachable-dispatch BLOCKER** — `harness-doctor` check 3 catches it.

| Flag | True when |
|---|---|
| `{{#IF MIGRATION_TOOL}}` | a migration tool exists **and** the manifest says yes |
| `{{#IF CONTRACT_GEN_COMMAND}}` | the client is generated from a spec **and** manifest yes |
| `{{#IF TOKENS_FILE}}` | a token system exists **and** manifest yes |
| `{{#IF DEPENDENCY_AUDIT}}` | third-party deps **and** manifest yes |
| `{{#IF MCP_SERVERS}}` | the project ships or dispatches MCP servers/tools **and** manifest yes |
| `{{#IF PERF_PROFILING}}` | `DESIGN.md` §8 has numeric targets (forge resolves the DEFERRED row) |
| `{{#IF RELEASE_RUNBOOK}}` | a deploy target exists **and** manifest yes |
| `{{#IF STANDARDS_DOC}}` | a coding/DB standards doc exists |
| `{{#IF DATABASE}}` | the stack has a database |
| `{{#IF BUILD_COMMAND}}` | there is a separate build step |
| `{{#IF FRONTEND_CHECK_COMMAND}}` | the frontend has its own check command |
| `{{#IF E2E_COMMAND}}` | the stack has an E2E suite |

---

## `{{INVARIANTS}}` — the one that carries the project

Every other placeholder is a string swap. This one is the difference between a `code-review` gate that finds real defects and one that produces generic advice.

Lift the project's actual invariants from `DESIGN.md` §5 and §12, **verbatim, as checkable assertions**, into the generated `code-review` and `CLAUDE.md`. For Tally that's:

```
- expense_share.share_minor sums to expense.amount_minor. Exactly. Always.
- Balances are DERIVED, never stored (ADR-005). Any code writing a balance column is a defect.
- Money is integer minor units. A float touching money is a defect.
- A settlement suggestion is never persisted (ADR-006).
```

A gate told "check that the code is correct" checks nothing. A gate told "any code writing a balance column is a defect" catches the bug.

**If §5 and §12 give you nothing concrete enough to assert, do not invent invariants.** Emit the gate without them and flag it: the design is thin, and a `code-review` gate full of platitudes is one more thing that reports green without looking.

---

## `{{MODEL_*}}` — per-agent model tier (a cost lever, used conservatively)

Each generated agent declares a `model:` in its frontmatter. The point is to spend the strongest model where a wrong answer is expensive and a cheaper one where the work is bounded and mechanical — **not** to minimize cost. Defaults:

| Agent | Default | Why |
|---|---|---|
| `story-scoper` | `{{MODEL_SCOPER}}` → `sonnet` | Read-heavy, mechanical: distil cited sections into a brief. Bounded output, low reasoning depth. The safe place to save. |
| `story-implementer` | `{{MODEL_IMPLEMENTER}}` → `opus` | The hardest reasoning in the loop and the one you least want wrong. Do not cheap out here. |
| `story-reviewer` | `{{MODEL_REVIEWER}}` → `opus` | Independent judgement is the entire value of the role; a weaker reviewer is a weaker gate. |

Rules:

1. **These are defaults, not mandates.** `harness-forge` may raise the scoper on a design-heavy project, or note that a simpler stack tolerates a cheaper implementer. It records any deviation in its return.
2. **Resolve to a literal tier** (`opus` / `sonnet` / `haiku`) — never leave `{{MODEL_*}}` in a generated file; `harness-doctor`'s `{{` grep fails on it like any other placeholder.
3. **When unsure, keep the strong default.** A gate or an engineer running on too weak a model fails silently — it produces plausible output that is subtly worse, exactly the failure mode this kit exists to prevent. Saving tokens on the scoper is safe; saving them on the reviewer is not.

## Conditional blocks

Templates use `{{#IF X}} … {{/IF}}` for parts that only exist on some stacks:

```
{{#IF MIGRATION_TOOL}}
- Schema story → run `db-migration-review` against {{DB_ISOLATION}}.
{{/IF}}
```

Resolve the condition, then **delete the markers**. A `{{#IF}}` left in a generated file is the same class of failure as an unresolved `{{VAR}}`.

---

## Rules

1. **Resolve every placeholder before writing.** Grep the output for `{{`. Zero hits.
2. **A placeholder with no source is a gap, not a guess.** Go back to `STACK.md` or the repo and get the real value. If it genuinely doesn't exist, the feature it belongs to shouldn't be in the harness — drop the gate rather than invent the command.
3. **Confirm every path with `ls`.** A `{{MIGRATION_DIR}}` that doesn't exist means every brief quoting it is wrong.
4. **Never leave a placeholder "for later."** There is no later. The generated harness is forked into the target repo and nobody comes back to it.

---

## `{{DB_PARALLEL_RULE}}` — resolve to one of these, verbatim

`scaffold` returns its test-isolation strategy. Map it:

| `scaffold` built | Resolve to |
|---|---|
| Per-worker isolation (testcontainers, DB-per-worker, schema-per-worker) | `Satisfied structurally — {{DB_ISOLATION}} gives every worker its own database, so concurrent suites cannot see each other. Nothing to check per story.` |
| No database in tests | `No test touches a database, so there is nothing to isolate and this condition is always met.` |
| A database, but **no** per-worker isolation | `**Per-worker DB isolation does not exist.** Any story whose scoper returned \`touches DB: yes\` runs alone; DB-free stories still run concurrently. This is a scaffold defect, not a steady state — report it and get it fixed, because it costs concurrency on every story for the life of the build.` |

**Substitute `{{DB_ISOLATION}}` inside the first sentence for the literal strategy** (`testcontainers, one DB per pytest-xdist worker`). It is the same trap as `{{COMMIT_FORMAT}}`: a resolved value that still carries `{{` drags a placeholder into the harness and trips the check-0 grep.

The third value must **name itself as a defect.** A harness that quietly serializes is one nobody ever fixes: the cost is invisible and permanent, and each session assumes the previous one had a reason.

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

## Conditional flags

Set by `harness-forge` from `STACK.md`'s gate manifest. **A flag set without its gate emitted (or the reverse) is an unreachable-dispatch BLOCKER** — `harness-doctor` check 3 catches it.

| Flag | True when |
|---|---|
| `{{#IF MIGRATION_TOOL}}` | a migration tool exists **and** the manifest says yes |
| `{{#IF CONTRACT_GEN_COMMAND}}` | the client is generated from a spec **and** manifest yes |
| `{{#IF TOKENS_FILE}}` | a token system exists **and** manifest yes |
| `{{#IF DEPENDENCY_AUDIT}}` | third-party deps **and** manifest yes |
| `{{#IF PERF_PROFILING}}` | `DESIGN.md` §8 has numeric targets (forge resolves the DEFERRED row) |
| `{{#IF RELEASE_RUNBOOK}}` | a deploy target exists **and** manifest yes |
| `{{#IF FRONTEND}}` | the stack has a frontend — reserved; not yet used by any template |
| `{{#IF STANDARDS_DOC}}` | a coding/DB standards doc exists |
| `{{#IF DATABASE}}` | the stack has a database |
| `{{#IF BUILD_COMMAND}}` | there is a separate build step |
| `{{#IF FRONTEND_CHECK_COMMAND}}` | the frontend has its own check command |

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

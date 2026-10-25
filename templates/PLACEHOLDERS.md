# The placeholder contract

Every `{{VAR}}` in `templates/**`. `harness-forge` writes their values into `HARNESS_VALUES.json` and `scripts/forge.sh` fills them; see "`HARNESS_VALUES.json`" below for the file's shape.

**An unresolved `{{VAR}}` that reaches the generated harness is a BLOCKER.** Not a cosmetic one: an agent reading `Run {{CHECK_COMMAND}}` will not error. It will infer a plausible command, run it, and report green. The check you believe in has quietly stopped running, and nothing tells you.

`harness-doctor` greps the generated harness for `{{` and fails on any hit. That grep is the last line of defence and it is worth more than it looks.

---

## Resolution table

| Placeholder | Source | Example |
|---|---|---|
| `{{PROJECT}}` | `PRD.md` title | `Tally` |
| `{{TIER}}` | `PRD.md` → `<!-- TIER: x -->` | `orchestrated` (or `small`) — used by forge for tier selection; not substituted into any template |
| **`{{CHECK_COMMAND}}`** | `STACK.md` → "The check command" | `cd backend && make check` |
| `{{CHECK_PRECONDITIONS}}` | `STACK.md` | `starts hearth-pg18 automatically` |
| `{{AFFECTED_TEST_COMMAND}}` | `STACK.md` | `pytest {paths}` |
| `{{LINT_COMMAND}}` | `STACK.md` | `ruff check {files}` |
| `{{TYPECHECK_COMMAND}}` | `STACK.md` | `pyright` |
| `{{FORMAT_COMMAND}}` | `STACK.md` → "Format command". **May be empty**: then forge emits no `format.sh` and no PostToolUse entry. Both tiers. | `npx prettier --write`: formats the one file given as its last argument |
| `{{LINT_STAGED_COMMAND}}` | forge, from `{{LINT_COMMAND}}` with the `{files}` token removed (the hook appends the staged files). **Empty when the lint command cannot take a file list**: then the pre-commit hook does not lint. Both tiers. | `ruff check` |
| `{{SOURCE_EXTENSIONS}}` | forge, from the stack's languages. Space separated, no dots. Used by `format.sh` and the pre-commit lint filter. | `ts tsx js` |
| `{{FRONTEND_CHECK_COMMAND}}` | `STACK.md`, or omit the block | `npm run lint && vitest && npm run build` |
| `{{BUILD_COMMAND}}` | `STACK.md` | `npm run build` |
| `{{STACK_SUMMARY}}` | `STACK.md`, one line | `Python 3.12 · FastAPI · Postgres 16 · React Native` |
| `{{DATABASE}}` | `STACK.md` ADRs | `PostgreSQL 16` |
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
| **`{{STATE_FILE}}`** | forge — both tiers | `PROGRESS.md`, at the repo root |
| `{{REVIEWS_DIR}}` | forge's choice — orchestrated only (join-review + doctor reports; gitignored) | `docs/_reviews/` |
| `{{GLOSSARY_SECTION}}` | `DESIGN.md` §2.1 | `§2.1` |
| `{{SCHEMA_SECTION}}` | `DESIGN.md` §3 | `§3` |
| `{{BEHAVIOR_SECTION}}` | `DESIGN.md` §5 | `§5` |
| `{{DOD_SECTION}}` | `DESIGN.md` §12 | `§12` |
| **`{{INVARIANTS}}`** | `DESIGN.md` §5 + §12, verbatim | see below |
| `{{STANDARDS_DOC}}` | `scaffold`, or omit | `backend/docs/db-standards.md` |
| `{{PROJECT_ONE_LINER}}` | `PRD.md` → What | `Shared expense tracking for roommates.` |
| `{{PROJECT_STRUCTURE}}` | repo, confirmed with `ls` | **One line listing the top-level code directories, nothing else:** `/backend · /mobile · /infra`. **Never a tree listing.** Codebase overviews do not help agents find files faster and cost tokens on every prompt (Gloaguen et al., ETH Zurich, 2026); briefs already carry each unit's owned trees. |
| `{{E2E_COMMAND}}` | `STACK.md`, or omit | `npx playwright test` — run at join points / by `release-runbook` when the stack has E2E |
| `{{LOCKFILES}}` | `scaffold`. Space separated (it goes into `git diff --name-only <commit> -- {{LOCKFILES}}`) | `uv.lock package-lock.json` |
| `{{AUDIT_COMMAND}}` | `STACK.md` → "Audit command". **Empty when there are no third-party dependencies**: then no audit line is emitted. One command that exits non-zero on a high-severity advisory; the orchestrator (or the small-tier builder) runs it in one shell call only when a lockfile changed. Both tiers. | `npm audit --audit-level=high` |
| `{{PERF_SECTION}}` | `DESIGN.md` §8 | `§8.1` |
| `{{PERF_FIRST_EPIC}}` | `PLAN.md` | `EPIC-09` |
| **`{{MAX_PARALLEL}}`** | forge, from the isolation `scaffold` built — **`orchestrated` only; the `small` tier has one agent and nothing to run alongside it, so neither parallelism placeholder appears there** | `3` — concurrent unit agents. **3 is the default and the right answer for almost every project** (beyond it, shared build artefacts contend and produce failures that look like real defects). Raise to 4–5 only when the check command is genuinely fast (< ~60s) and isolation is per-worker; drop to `1` only when `{{DB_PARALLEL_RULE}}` says isolation does not exist *and* every unit touches the DB. `1` is a defect being reported, not a configuration. |
| **`{{DB_PARALLEL_RULE}}`** | forge, from `scaffold`'s returned isolation strategy | **Resolve to one literal sentence** stating what is actually true. Three canonical values, below. Never leave it abstract — this sentence is the only place the harness records whether concurrent test runs are safe, and an agent reading a vague one will assume the permissive reading. |
| **`{{NOTIFY}}`** | **set by `forge.sh`; not a values key.** The notifier `harness-forge` copies into every repo | `.claude/scripts/notify.sh`: **the bare path, no backticks and no `./` prefix.** Every template already wraps it (in backticks, or inside a bash block), so a decorated value nests and produces a command that does not run. It is not configurable and not stack-dependent; the file is copied verbatim from the kit root and the path must match it exactly or every ask silently runs nothing. |
| `{{TALKING_TO_THE_USER}}` | **no longer used (v0.7); no template contains it.** | The `## Talking to the user` section is literal text in `orchestrate-build` and `build-loop`, copied from the block between the markers in the kit's `COMMUNICATION.md`, which stays its only owner (KD-021, KD-022). `CLAUDE.md` carries one pointer line. |
| **`{{ORGANISING_PRINCIPLE}}`** | `PRD.md` (What/Why, stated quality bar) + `DESIGN.md` invariants — see below | `A silently wrong number is the worst possible outcome.` |

## `HARNESS_VALUES.json`

`harness-forge` writes this file at the repo root (gitignored) and runs `bash <kit root>/scripts/forge.sh <tier> HARNESS_VALUES.json .`. One flat JSON object:

```json
{
  "PROJECT": "Dues",
  "CHECK_COMMAND": "npm run check",
  "FORMAT_COMMAND": "",
  "INVARIANTS": "- **I-1** A balance is never stored ...\n- **I-2** ...",
  "PRECOMMIT_TYPECHECK": false,
  "gates": ["db-migration-review"]
}
```

- **Strings fill `{{KEY}}`.** Multi-line values use `\n`. A value may name another placeholder (`DB_PARALLEL_RULE` naming `{{DB_ISOLATION}}`); `forge.sh` fills it too.
- **`{{#IF KEY}}` is true** when the key is `true` or a non-empty string. So a command the stack lacks is `""`: every block that needs it drops out. Pure flags (`PRECOMMIT_TYPECHECK`) are booleans.
- **`gates`** lists the manifest's `yes` gates for this tier, by directory name under `templates/gates/`. Empty at `small`. At `orchestrated`, `db-migration-review`, `api-contract-sync` and `design-token-lint` must be listed exactly when `MIGRATION_TOOL`, `CONTRACT_GEN_COMMAND` and `TOKENS_FILE` are non-empty, so the join never dispatches a gate that was not emitted.
- **Set by `forge.sh`, never in the file:** `ORCHESTRATED`, `MCP_SERVERS`, `PERF_PROFILING`, `RELEASE_RUNBOOK` (from the tier and `gates`), `NOTIFY`, `TALKING_TO_THE_USER`.
- **`forge.sh` exits non-zero and writes nothing** when a placeholder is left unfilled, a key is used by no emitted template (a typo, or a key for the other tier), a gate is unknown, or `gates` and the flags disagree. It never overwrites an existing state file.
- Worked examples: `tests/fixtures/values.orchestrated.json` and `tests/fixtures/values.small.json` (the Dues test project).

## Conditional flags

Set by `harness-forge` from `STACK.md`'s gate manifest. **A flag set without its gate emitted (or the reverse) is an unreachable-dispatch BLOCKER** — `harness-doctor` check 3 catches it.

| Flag | True when |
|---|---|
| `{{#IF MIGRATION_TOOL}}` | a migration tool exists **and** the manifest says yes |
| `{{#IF CONTRACT_GEN_COMMAND}}` | the client is generated from a spec **and** manifest yes |
| `{{#IF TOKENS_FILE}}` | a token system exists **and** manifest yes |
| `{{#IF MCP_SERVERS}}` | **set by `forge.sh`**: `mcp-scan` is in `gates` |
| `{{#IF PERF_PROFILING}}` | **set by `forge.sh`**: `perf-profiling` is in `gates` (`stack-decide` decided it from the PRD) |
| `{{#IF RELEASE_RUNBOOK}}` | **set by `forge.sh`**: `release-runbook` is in `gates` |
| `{{#IF AUDIT_COMMAND}}` | `{{AUDIT_COMMAND}}` is non-empty |
| `{{#IF STANDARDS_DOC}}` | a coding/DB standards doc exists |
| `{{#IF DATABASE}}` | the stack has a database |
| `{{#IF BUILD_COMMAND}}` | there is a separate build step |
| `{{#IF FRONTEND_CHECK_COMMAND}}` | the frontend has its own check command |
| `{{#IF E2E_COMMAND}}` | the stack has an E2E suite |
| `{{#IF ORCHESTRATED}}` | **set by `forge.sh`**: the tier is `orchestrated`. Used only in `templates/enforcement/` (the state-file guards), which both tiers share |
| `{{#IF FORMAT_COMMAND}}` | `{{FORMAT_COMMAND}}` is non-empty |
| `{{#IF LINT_STAGED_COMMAND}}` | `{{LINT_STAGED_COMMAND}}` is non-empty |
| `{{#IF PRECOMMIT_TYPECHECK}}` | **small tier only**, and forge measured lint plus `{{TYPECHECK_COMMAND}}` on the scaffolded repo at under 15 seconds (KD-020). Never at orchestrated: typecheck covers the whole project, and parallel unit agents share one working tree, so one unit's half-written code would reject another unit's commit |

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

## `{{ORGANISING_PRINCIPLE}}` — the sentence agents reason *from*

The generated `CLAUDE.md` **opens** with this: one load-bearing sentence stating what must never be
wrong for this product (`A silently wrong number is the worst possible outcome.`). It is what lets
an agent make the correct call in a situation no brief anticipated — a checklist produces
compliance; a principle produces judgement, and a build is mostly novel judgements (KD-019).

Resolve it from `PRD.md` (the What/Why, any stated quality bar) and `DESIGN.md`'s invariants — the
principle is usually the sentence the invariants are all instances of. Rules:

1. **It is one sentence, and it is falsifiable in use.** "Build good software" organises nothing.
   A principle is right when briefs can be traced back to it and refusals can cite it.
2. **If the PRD and design give you nothing concrete enough, do not invent one.** Same rule as
   `{{INVARIANTS}}`: resolve to a plain statement of the product's job (`{{PROJECT_ONE_LINER}}`)
   and flag the gap in your return — the PRD is thin, and a fabricated principle steers every
   novel judgement wrong in the same direction.

### Dispatch models (not placeholders — literals in the templates)

Unit agents carry **no `model:` override** — they inherit the session model, which is the strongest
thing running and is where the hardest reasoning happens. Fixed literals elsewhere, by the nature
of the task: `join-review` dispatches as `opus` (composite judgment); chore dispatches (a
notify-only or commit-only task, where one exists) as `haiku`. Never leave a model decision
abstract in a generated file.

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
| Per-worker isolation (testcontainers, DB-per-worker, schema-per-worker) | `Satisfied structurally: {{DB_ISOLATION}} gives every worker its own database, so concurrent suites cannot see each other. Nothing to check per story.` |
| No database in tests | `No test touches a database, so there is nothing to isolate and this condition is always met.` |
| A database, but **no** per-worker isolation | `**Per-worker DB isolation does not exist.** Any unit whose owned trees touch the database runs alone; DB-free units still run concurrently. This is a scaffold defect, not a steady state — report it and get it fixed, because it costs concurrency on every unit for the life of the build.` |

In `HARNESS_VALUES.json` the first sentence may keep `{{DB_ISOLATION}}` as written: `forge.sh` fills placeholders inside values too. Anything that still carries `{{` after filling makes `forge.sh` fail.

The third value must **name itself as a defect.** A harness that quietly serializes is one nobody ever fixes: the cost is invisible and permanent, and each session assumes the previous one had a reason.

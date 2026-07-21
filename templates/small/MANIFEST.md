# SMALL-tier harness template — manifest

**Not a subtraction from `full`.** `standard` is `full` minus gates; `small` is a genuinely different shape — **one role, one loop, one skill** — and it is written to be honest about what that costs rather than to look like a shrunken version of something bigger.

**For:** < ~15 stories (KD-002). Weekend and side projects.

**The rationale (KD-002):** a heavyweight harness on a small project gets bypassed, and **a bypassed harness is worse than none — it lies about what is being checked.** So this tier does not pretend to have gates it cannot afford to run. It keeps the four things that cost nothing and whose absence is what actually kills small projects, and it says plainly what it gave up.

---

## Files

| File | What it is | Placeholders used |
|---|---|---|
| `CLAUDE.md.tmpl` | The operating manual. Tier declaration · **What this tier gave up** (self-review is a real weakening; nothing folds deviations into the design) · **the upgrade trigger** · project structure · pinned stack · **`{{CHECK_COMMAND}}`** · the project `{{INVARIANTS}}` · **the four rules that do not bend** · commit format · ambiguity protocol · the single stop signal. | `{{PROJECT}}` `{{PROJECT_ONE_LINER}}` `{{PROJECT_STRUCTURE}}` `{{DESIGN}}` `{{PLAN}}` `{{STATE_FILE}}` `{{CODE_DIRS}}` `{{STACK_SUMMARY}}` `{{LANGUAGE}}` `{{FRAMEWORK}}` `{{DATABASE}}` `{{TEST_FRAMEWORK}}` `{{CHECK_COMMAND}}` `{{CHECK_PRECONDITIONS}}` `{{INVARIANTS}}` `{{COMMIT_FORMAT}}` `{{BRANCH}}` `{{DOD_SECTION}}` `{{GLOSSARY_SECTION}}` `{{NOTIFY}}` · cond: `{{MIGRATION_TOOL}}` `{{MIGRATION_DIR}}` `{{MIGRATION_UP}}` `{{MIGRATION_DOWN}}` `{{FRONTEND_CHECK_COMMAND}}` `{{TOKENS_FILE}}` `{{SCHEMA_SECTION}}` |
| `STATE_FILE.md.tmpl` | `{{STATE_FILE}}` = **`PROGRESS.md` at the repo root** (not `docs/`). Sections: NEXT ACTION · Standing facts · Session log · **Decisions & deviations (never delete a line)** · Blockers · Story status · Progress (with the ~15-story upgrade trigger in the counts). Written after **every** story. | `{{PROJECT}}` `{{DESIGN}}` `{{PLAN}}` `{{STATE_FILE}}` `{{CHECK_COMMAND}}` `{{CHECK_PRECONDITIONS}}` `{{BRANCH}}` · cond: `{{FRONTEND_CHECK_COMMAND}}` `{{MIGRATION_TOOL}}` `{{MIGRATION_UP}}` `{{MIGRATION_DOWN}}` |
| `skills/build-loop/SKILL.md.tmpl` | **The one skill.** Read the plan → pick the next story with deps done → read the design slice **+ the deviation ledger** → build → run `{{CHECK_COMMAND}}` → **self-review against the AC, one bullet at a time, with citations** → commit (one story, one commit) → write state → repeat. Plus: the blocker protocol (**which pushes the ask via `{{NOTIFY}}` — the builder has `Bash`**), the single stop signal, the upgrade trigger, and eight non-bending rules. | `{{PROJECT}}` `{{DESIGN}}` `{{PLAN}}` `{{STATE_FILE}}` `{{CHECK_COMMAND}}` `{{CHECK_PRECONDITIONS}}` `{{TEST_FRAMEWORK}}` `{{COMMIT_FORMAT}}` `{{INVARIANTS}}` (via CLAUDE.md) `{{GLOSSARY_SECTION}}` `{{NOTIFY}}` · cond: `{{FRONTEND_CHECK_COMMAND}}` `{{MIGRATION_TOOL}}` `{{MIGRATION_UP}}` `{{MIGRATION_DOWN}}` `{{SCHEMA_SECTION}}` |

**No agents.** No `agents/` directory. The builder *is* the session.

**No parallelism, and this one is structural rather than a trade.** The heavier tiers run up to `{{MAX_PARALLEL}}` stories concurrently because they have separate scoper/engineer/reviewer agents to run concurrently. This tier has **one** agent that does all three jobs in sequence for a single story — there is nothing here to run alongside anything. Serial is not a caution being exercised; it is what one loop means. **Do not "enable parallelism" at this tier.** If the build is big enough that concurrency would pay, that is the ~15-story upgrade trigger firing: regenerate at `standard`, which has the roles to parallelize.

**No gates.** No `regression-run`, no `code-review`, no `docs-sync`, no migration/contract/token gates, no epic or phase boundaries, no fix-stories.

**No `harness-doctor` emitted.** The kit's own `harness-doctor` still doctors this harness at setup (KD-005) — nothing ships with an open BLOCKER. But a three-file harness does not need a resident type-checker, and shipping one would be the same over-engineering this tier exists to avoid.

---

## What was kept, and why (these cost nothing; their absence is what kills small projects)

| Kept | Why it survives the cut |
|---|---|
| **Green-baseline law. Zero failing tests. Never excuse a red as "environmental."** | The cheapest rule in the whole system and the one whose absence is terminal. Three stories on a red tree and nobody reads the suite output again — from then on the build is flying blind while still reporting "done" every story. |
| **One story = one commit.** | Costs nothing. Without it the diff stops being a story and becomes a fog, and the self-review in step 7 has nothing crisp to run against. |
| **State file written after EVERY story.** | Costs one write. Buys: a crash, a context reset, or a closed laptop loses at most one story. |
| **The single stop signal + "there is no story quota."** | Pure prose. Every soft heuristic ("natural stopping point", "that was a big story") fires long before real context pressure and costs a full resume cycle for nothing. |
| **Acceptance criteria checked — cited, with a test — before a story is `done`.** | The mechanical replacement for the reviewer this tier does not have. "I implemented the story" is not a check. `AC 3 → services/split.py:88, tests/test_split.py:41` is. |
| **The deviation ledger, never pruned.** | Nothing folds a deviation back into `{{DESIGN}}` at this tier either. The ledger is the only thing that will contradict a stale design next session — and *you* are the one who will read that design and believe it. |
| **`{{INVARIANTS}}`, checked literally in self-review.** | With no `code-review`, this is the only place the project's actual correctness rules are asserted. A vague `{{INVARIANTS}}` block here checks nothing at all. |

---

## What was given up — stated plainly in the skill, not buried

The `build-loop` skill says this in its own voice, in its second section, because a weakness a harness will not name is one it will not defend against:

- **The builder self-reviews.** The author is judging their own work. That is precisely the conflict of interest an independent reviewer removes, and it is not fixable with resolve — you read your own diff already believing it is correct, seeing what you meant rather than what you typed. Accepted, because at this size the orchestration overhead exceeds its value. Mitigated **mechanically**: per-AC citation, reading the diff cold as a diff, and letting the tests be the reviewer you don't have (which is why a red suite is non-negotiable and why a test that never went red proves nothing).
- **No cross-story regression gate.** The full suite runs on every story instead — which is the same coverage at this scale, and would not be at 50 stories.
- **Nothing folds deviations into the design.** Same hazard as `standard`, same compensation: a ledger that is never pruned.

### The upgrade trigger (in `CLAUDE.md`, in `STATE_FILE.md`, and in the skill's rules)

**If the build passes ~15 stories, or you catch yourself wanting a gate, or the ledger has grown enough that you no longer trust the design — the tier was wrong. Regenerate at `standard`. Do not hand-bolt a gate on.**

**A small harness silently carrying a large build is the characteristic failure mode of this tier.** It does not break loudly. It keeps saying "done", story after story, while nobody but the author has looked at anything.

---

## The notification channel (every tier)

`harness-forge` copies two files into the repo, verbatim from the plugin root, and they are not tier-scaled:

| File | Role |
|---|---|
| `.claude/scripts/notify.sh` | `{{NOTIFY}}`. Pushes an ask to the owner's phone via Pushover. **Refuses to send** an ask missing what's stuck / two options / a recommendation. Never fails its caller: a delivery problem exits 0 and prints to stderr, because a notification that can fail a build stops the build for a reason unrelated to the code. |
| `.claude/ASK_CONTRACT.md` | What a question must contain to be answerable from a lock screen, and the no-jargon rule. Cited by every file that asks the user anything. |

**Who calls it:** whoever *discovers* the blocker — they have `Bash` and they have the detail. **The orchestrator has no `Bash` and must not be given any**; it dispatches a notify-only task, exactly as it dispatches a commit-only task to flush the state file.

**No `Notification` hook is emitted into the repo.** The user installs one globally in `~/.claude/settings.json`; a per-project copy double-fires, and a channel that cries wolf gets muted before the one time it mattered.

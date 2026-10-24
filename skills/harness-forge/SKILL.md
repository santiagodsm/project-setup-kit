---
name: harness-forge
version: 0.3.0
description: "Generate the project's own build harness from the tier templates: CLAUDE.md, .claude/skills/*, the state file, sized to the build tier (small or orchestrated), containing only the gates the stack can run. Substitutes templates by default; authors new gates from the contracts when the stack needs one no template covers. Step 5 of project setup. Ends by running harness-doctor and does not complete with an open BLOCKER."
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - Skill
  - ToolSearch
metadata:
  role: generator
  reads: [templates/**, COMMUNICATION.md (the Talking-to-the-user block), STACK.md (gate manifest + check command), DESIGN.md, PRD.md (TIER marker + organising-principle sources), PLAN.md (if it exists — dispatch-unit count only), the scaffolded repo]
  writes: [target repo CLAUDE.md, .claude/skills/**, .claude/scripts/notify.sh + .claude/ASK_CONTRACT.md (copied verbatim from the plugin root), .claude/settings.json, .claude/hooks/** (guard-writes.sh, guard-bash.sh, format.sh), .githooks/**, the build state file (stub), .gitignore (reviews dir, .env), STACK.md (resolves DEFERRED manifest rows ONLY)]
---

# harness-forge — substitute what exists, author what doesn't

You are producing a **multi-agent system made of prose files**. Nothing type-checks it. A skill can demand a tool it was never granted, write a file nobody reads, or contradict `CLAUDE.md` outright, and **it will all look fine until the build silently stops verifying itself.**

That is why you start from templates rather than from a blank page.

## Templates are the floor, not the ceiling

**Default: substitute.** `templates/{small,orchestrated}/` and `templates/gates/` hold a harness extracted from builds that actually survived — real defects fixed, a whole per-story ceremony retired because it was measured and lost. Their **contracts are correct**: tool grants, artifact ownership, return contracts, loop caps, gates-at-joins.

Those contracts are expensive to derive and easy to get subtly wrong. **Do not rewrite them.** Each rule keeps its reason, stated once, in one or two sentences, in the file that owns the rule; the same reason is never repeated across files (KD-021). The reason is what makes an agent comply under pressure, so a rule stripped of it gets rationalized past on its first hard day. A reason copied into a second file is worse: the copies drift, and the agent obeys whichever it read last.

**But you are not limited to them.** If this project needs a gate no template covers — a store-submission check, a data-migration verifier, a model-drift gate — **author it.** A stack the templates never anticipated is a normal outcome, not an error.

**What you must not do is fake it.** If the stack needs a gate you cannot write properly, emit no gate and say so. A gate that cannot really run gets skipped, faked, or rationalized past — **and the harness reports that it ran.** That is strictly worse than a harness that admits the check is missing.

## Procedure

1. **Read `templates/PLACEHOLDERS.md`.** It is the resolution contract.
2. **Read the tier** from `PRD.md`'s `<!-- TIER -->` marker. Not the prose. The marker. It is `small` or `orchestrated` — nothing else. If you find `standard` or `full`, stop: the marker predates the two-tier model and `setup-project` must re-tier before you run.
3. **Read the gate manifest** in `STACK.md`.
4. **Resolve the `DEFERRED` rows.** `stack-decide` ran before `DESIGN.md` existed and could not decide `perf-profiling`. You can: **§8 has numeric targets → yes; none → no.** **Write your answer back into `STACK.md`'s manifest table.** A `DEFERRED` row must not survive — `harness-doctor` cannot classify one, and the fidelity check then silently passes on a gate nobody ever decided.
5. **Copy `templates/<tier>/**`** into the target repo — **except `MANIFEST.md`**, which is kit documentation, is full of unresolved placeholders by design, and would ship as an orphan file that trips the grep in step 12. **No `.claude/agents/` is created at either tier.** The orchestrated tier dispatches unit work as general-purpose subagents; emitting role-agent files would be dead machinery on day one.
6. **Emit gates per the manifest's tier column.** Two values:
   - **`yes`** → copy `templates/gates/<gate>/` into the target repo.
   - **`no`** → **do not emit it.** At that tier nothing dispatches it, so the file would be an orphan — a gate the harness appears to have and doesn't. `harness-doctor` check 3 blocks on it.

   There is no `inline` value anymore — there is no story-reviewer to fold a check into. Migration, token, and contract-drift checks live in unit briefs and in `join-review`, which the tier templates already carry. The **tier-core skills** — `orchestrate-build`, `join-review`, `harness-doctor` for orchestrated; `build-loop` for small — live in `templates/<tier>/skills/`, not `templates/gates/`, and step 5 already copied them. Do not look for them in `gates/` and do not author duplicates at step 7.
7. **Author any gate the stack needs that no template covers.** Same contracts. Note it in your return so the template library can absorb it later.
8. **Resolve every placeholder.** After resolving `{{#IF}}` blocks, renumber any numbered list a removed block left with a gap, and collapse runs of blank lines. Confirm every path with `ls` before writing it. `{{STATE_FILE}}` resolves to `PROGRESS.md` at the repo root for the orchestrated tier. `{{ORGANISING_PRINCIPLE}}` has its own section below — resolve it deliberately, not as a string swap. `{{TALKING_TO_THE_USER}}` is the block between the markers in the plugin root's `COMMUNICATION.md`, copied verbatim: it is the user's rule for how every agent talks to them, and it has one owner.
9. **Stub the state file.** `PLAN.md` and its `## Dispatch units` section don't exist yet (step 6). Emit every required section — including the five statuses `todo / wip / done / blocked / partial` — with `NEXT ACTION: awaiting PLAN.md`. **Do not invent a first unit** — an orchestrator booting at a fabricated unit is worse than one booting at nothing.
10. **Gitignore** `{{REVIEWS_DIR}}` (join-review and doctor reports), `HARNESS_DOCTOR.md`, `PLAN_LINT.md`, and `.env` / `*.env` (with `!*.env.example`). You chose the reviews path; `scaffold` was explicitly forbidden from guessing it. The `.env` rules are belt-and-braces — the real credentials live outside every repo — but a project that later adds a local override must not have to remember this. **Then emit the notification channel — see below. No tier skips it.**
11. **Emit enforcement.** See "Emit enforcement" below. No tier skips it.
12. **Grep the output for `{{`.** Zero hits. See below.
13. **Run `harness-doctor`**, read its report file, fix every BLOCKER. **Three rounds max**, then stop and report failure with the findings — a generator that can't converge in three rounds does not understand what it produced.

## `{{ORGANISING_PRINCIPLE}}` — one sentence that carries the judgement calls

The generated `CLAUDE.md` opens with **one load-bearing sentence** — the thing every rule below it serves (the canonical example: *"a silently wrong number is the worst possible outcome"*). It exists because agents facing a situation no brief anticipated need something to reason *from*; a checklist produces compliance, not the correct novel judgement.

Resolve it from **`PRD.md`** (the What/Why, and any stated quality bar) and **`DESIGN.md`'s invariants** — the principle is whatever single failure the design spends the most machinery preventing. It must be *this project's* sentence: falsifiable, consequence-shaped, something an agent could cite to refuse a plausible shortcut.

**If nothing concrete supports one, do not invent it.** Same rule as `{{INVARIANTS}}`: emit a placeholder-free generic line instead and **flag it in your return as a PRD gap.** A manufactured principle is worse than none — agents will faithfully optimize for a sentence nobody actually meant.

## Zero `{{` in the output. This one is not cosmetic.

An unresolved placeholder does not throw. An agent reading `Run {{CHECK_COMMAND}}` will **infer a plausible command, run it, and report green.** The verification you believe in has quietly stopped, and nothing tells you.

Same for a stray `{{#IF}}`: resolve the condition, then **delete the markers.**

*One exception, and read it precisely:* `harness-doctor`'s template must **name** the pattern in order to grep for it, so its check-0 grep quotes a bare `{{` on a line tagged `PLACEHOLDER-LITERAL`. **That one literal is exempt.**

**The exemption is on that line, not on the file.** That same file also carries real placeholders — `{{STATE_FILE}}`, `{{REVIEWS_DIR}}` — and **every one of them must still resolve.** Skip the file wholesale and you ship a doctor whose report path is literally `{{REVIEWS_DIR}}harness-doctor-<date>.md`. That is precisely the failure this check exists to catch, embedded in the thing that checks for it.

## Resolve the parallelism policy from what `scaffold` actually built

**This is a manifest-shaped decision, not a constant.** Emit only the *serialization* the stack actually requires. (`small` has one agent and neither placeholder; this section is orchestrated-only.)

Read `scaffold`'s returned **test-isolation strategy** — it is required to have decided one. Then resolve:

- **`{{MAX_PARALLEL}}`** — `3` unless you have a specific reason. See `PLACEHOLDERS.md`.
- **`{{DB_PARALLEL_RULE}}`** — one of the three literal sentences in `PLACEHOLDERS.md`. Do not paraphrase them.

**Do not emit a serialized harness because serial feels safer.** These templates once hardcoded "parallelism DISABLED," inherited from a build that genuinely had a shared database — after `scaffold` had started building per-worker isolation as a hard gate. Carrying the ban forward serialized every generated build forever, and nothing ever noticed, because a slow build looks exactly like a careful one. If isolation genuinely is missing, resolve the third sentence, which **names itself as a defect**, and say so in your return.

**And emit the dispatch mode with it.** The generated orchestrator must dispatch concurrent unit agents with **`run_in_background: true`**, or "up to `{{MAX_PARALLEL}}` at once" runs strictly one-at-a-time while every file still reads as parallel. The templates carry this; if you author a dispatcher yourself, carry it too, with its two corollaries: **a launch confirmation is not a result**, and **units drain before a join**. Synchronous dispatch is correct exactly when there is nothing to overlap — which is why `setup-project`'s own chain is synchronous; do not "fix" that asymmetry.

## Emit the notification channel

The harness you are generating will, on some Tuesday, hit a blocker at 2am with nobody watching. **A build that stops silently is a build that has stopped forever**, and the way that resolves is a human eventually telling an agent to "just carry on" — past the exact gate that fired correctly.

So every harness ships with a way to reach its owner. Two files, copied verbatim from the plugin root — **do not rewrite either one**:

| From (plugin root) | To (target repo) |
|---|---|
| `scripts/notify.sh` | `.claude/scripts/notify.sh` — **`chmod +x` it** |
| `ASK_CONTRACT.md` | `.claude/ASK_CONTRACT.md` |

Then resolve **`{{NOTIFY}}`** to the literal invocation: `` `.claude/scripts/notify.sh` ``.

**Everyone calls it directly** — the orchestrator included, since it has `Bash`. There is no notify-only relay task anymore; that workaround existed only for a tool-starved orchestrator that no longer exists.

**The target repo's `.claude/settings.json` may exist (step 11 writes it); it must not contain a `Notification` hook.** The user's one notification hook is installed once, globally (the plugin ships it). A per-project copy fires *in addition* to it and buzzes the user twice, which trains them to ignore the channel, which costs you the one time it mattered.

Verify with `.claude/scripts/notify.sh` (no arguments) — it prints usage and exits 2. Do **not** run `selftest`: it sends a real push, and the user did not ask for one.

## Emit enforcement

Every rule above is prose, and prose fails silently. A few rules are load-bearing enough to enforce in tooling, where a violation fails the same way every time (KD-020). Templates: `templates/enforcement/`, shared by both tiers. Resolve them like every other template; `{{#IF ORCHESTRATED}}` is true only at the orchestrated tier.

| From `templates/enforcement/` | To (target repo) | Emit when |
|---|---|---|
| `settings.json.tmpl` | `.claude/settings.json` | always. Deny rules (force-push, hard reset, `--no-verify`, `git clean`, reading `.env` files), the guard hook, the compaction hook, and the format hook when `{{FORMAT_COMMAND}}` is set |
| `hooks/guard-writes.sh.tmpl` | `.claude/hooks/guard-writes.sh`, `chmod +x` | always. Blocks writes to `.env`/`*.env` (not `*.env.example`) and `.git/`; at orchestrated, also blocks writes to `{{STATE_FILE}}` from any subagent |
| `hooks/guard-bash.sh.tmpl` | `.claude/hooks/guard-bash.sh`, `chmod +x` | always. Matches the operations the deny rules name (force push, hard reset, skipped hooks, destructive clean) and shell writes to `.env` files or `.git/` anywhere in a command, because deny rules are prefix patterns and not a security boundary |
| `hooks/format.sh.tmpl` | `.claude/hooks/format.sh`, `chmod +x` | only when `STACK.md` names a format command. No command means no file and no PostToolUse entry: a formatter hook with nothing to run is a gate that can't run |
| `githooks/pre-commit.tmpl` | `.githooks/pre-commit`, `chmod +x`, tracked | always. At orchestrated: rejects a commit that stages `{{STATE_FILE}}` with anything but `{{DESIGN}}`. Both tiers: lints staged files when `{{LINT_STAGED_COMMAND}}` is set |

**The speed budget is a hard limit, not a target (KD-020).** These hooks never run tests, never run `{{CHECK_COMMAND}}`, `{{AFFECTED_TEST_COMMAND}}` or any test runner. The full suite runs where it already runs: once per story at small, once per join at orchestrated. Then:

- **Measure the pre-commit cost on the scaffolded repo** before you set `{{#IF PRECOMMIT_TYPECHECK}}`: time lint on a few source files plus `{{TYPECHECK_COMMAND}}`. Under 15 seconds together → include typecheck, **at the small tier only**. Over → leave typecheck out. At orchestrated, typecheck never goes in the hook: it covers the whole project, parallel unit agents share one working tree, and one unit's half-written code would reject another unit's commit. Lint alone over 15 seconds → leave `{{LINT_STAGED_COMMAND}}` empty too, and the hook keeps only the state-file rule. Report the measured numbers.
- Every hook in `settings.json` carries a `timeout`. The hooks that exist to block (the write guard, the Bash guard, and the state-file rule) fail closed; the two guards do it with `"onFailure": "block"`. The Bash guard runs on every shell command, so it exits at once when the command mentions neither `git` nor `.env`, and stays string matching only (under 50 ms). The format hook and the pre-commit lint fail open: a timeout or crash lets the action through.
- The compaction hook prints one line and reads nothing.

**Activate the git hook.** `core.hooksPath` is not tracked, so run `git config core.hooksPath .githooks` once now; both loop skills re-check it at every session start, because a fresh clone loses it. The state-file rule applies from the first commit, so commit `{{STATE_FILE}}` on its own.

**Do not add a `Notification` hook here.** See "Emit the notification channel".

## The five contracts (they apply to templates AND to anything you author)

Generated harnesses break in exactly these five places.

**1. Tool grants.** Every skill's `allowed-tools` covers what its procedure demands — a skill's grant **intersects down** once loaded, so a gate that writes a report needs `Write`, and one that invokes another skill needs `Skill`.
→ **The generated orchestrator has FULL tools — including `Bash`, `Grep`, `Glob`, `Skill` — BY DESIGN.** This is a deliberate reversal of the old rule: the orchestrator reads the whole design contract itself, runs the check at joins, and rules on escalations, and it can do none of that starved. **Do not "harden" it back.** Its enforcement mechanism is the join protocol, not tool starvation. (The old no-Bash rule survives only in the kit's own `setup-project`.)

**2. Artifact ownership.** Every read has exactly one writer. Draw the table. **The state file has exactly one writer: the orchestrator.** Unit agents and gates report; they never write it. Orphan read → the agent invents the file. A report with no declared path → unconstructable pointers.

**3. Return contracts — and their dispatch mirror.** The orchestrator writes every state-file line from **returns**, so unit agents must return what it records: what is **done**, what is **partial** (with what remains owed), and **what they could not verify** — a deliverable, not an admission. Gates return findings numbered and self-contained, with the report filename (reports are gitignored; load-bearing text must reach the tracked state file). The mirror binds dispatches: a brief carries the unit, exact design sections with line ranges, owned/forbidden trees, the traps, and only values the callee cannot get from disk — never the contents of a file that is on disk.

**4. Dispatch reachability.** Unit work goes to **general-purpose subagents** — there are no agent files, nothing to be unreachable. Gates are **skills**, and the orchestrator has `Skill`, so it invokes them directly. The old workaround — dispatch a general-purpose subagent told to invoke the skill — now applies **only** to gate runs the orchestrator wants backgrounded in parallel; state that narrowly or the gate path grows a needless hop.

**5. Loop termination.** The join-review fix loop is capped: **two rounds, then the unit is `blocked`** and the owner is notified. **Exactly one stop signal** (the context system-reminder; a compacted conversation means re-read `CLAUDE.md` and the state file and continue, never stop) — no unit caps, no session caps, no "natural stopping point."

## Bake in the project, not a generic

The generated skills must read as if hand-written for this project:

- The **verbatim `{{CHECK_COMMAND}}`**, never "run the tests" — and it runs **at joins only**; unit agents verify with the scoped commands you name.
- **Real paths**, confirmed with `ls`. The real commit format, migration commands, container names.
- `DESIGN.md`'s section convention, so briefs cite correctly — including `{{GLOSSARY_SECTION}}` (§2.1), which keeps the code's vocabulary aligned with the design's.
- **`{{INVARIANTS}}`** — the project's actual assertions from §5/§12, verbatim.

That last one carries the whole `join-review` gate. *"Any code writing a balance column is a defect"* catches the bug. *"Check that the code is correct"* checks nothing. **If §5/§12 give you nothing concrete, do not invent invariants** — emit without them and flag it. The design is the gap, and a gate full of platitudes is one more thing reporting green without looking.

## Return (~150 words)

- Tier emitted; skills generated. Confirm **no `.claude/agents/` was created.**
- **Gates included; gates deliberately excluded** (name the exclusions — they are what make the harness honest).
- **The organising principle chosen, verbatim, and its source** (which PRD/DESIGN statements support it) — or the generic line plus the PRD-gap flag.
- **Any gate you authored from scratch**, and why no template covered it.
- `{{CHECK_COMMAND}}`, verbatim, as wired in — and that it fires at joins only.
- **The exact path of the build state file you created** (orchestrated: `PROGRESS.md` at the repo root). `setup-project` must seed it and has no Glob. Omit this and it guesses.
- **Dispatch-unit count read from `PLAN.md`'s `## Dispatch units`, if the file exists** — usually it doesn't yet; say so.
- **Parallelism policy:** `{{MAX_PARALLEL}}` = N, and which `{{DB_PARALLEL_RULE}}` sentence you resolved to, naming the isolation `scaffold` built. The defect sentence is a finding, not a footnote.
- **Notification channel emitted:** `.claude/scripts/notify.sh` (executable) + `.claude/ASK_CONTRACT.md`, `{{NOTIFY}}` resolved everywhere, **no** `Notification` hook emitted.
- **Enforcement emitted:** hooks emitted (always `guard-writes.sh` and `guard-bash.sh`), hooks omitted and why (no format command, lint or typecheck over the speed budget, with the measured seconds), the deny rules, `core.hooksPath` set, and that the state-file guard runs at both levels at orchestrated (tool level via the subagent check, commit level via pre-commit) and at neither at small.
- Placeholder grep: **zero `{{` remaining.**
- **`harness-doctor`: N blockers found, N fixed, final = CLEAN.** Report nothing else as success.
- The first command the user runs to start building.

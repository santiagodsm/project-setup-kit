---
name: harness-forge
version: 0.3.0
description: "Use after scaffold or when the user says 'generate the harness': writes HARNESS_VALUES.json and runs scripts/forge.sh to emit the tier's CLAUDE.md, skills and gates (setup step 5)."
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
  reads: [<kit root>/templates/PLACEHOLDERS.md, STACK.md (gate manifest + check command), DESIGN.md, PRD.md (TIER marker + organising-principle sources), PLAN.md (if it exists; dispatch-unit count only), the scaffolded repo]
  writes: [HARNESS_VALUES.json, and through forge.sh: CLAUDE.md, .claude/skills/**, .claude/scripts/notify.sh + .claude/ASK_CONTRACT.md, .claude/settings.json, .claude/hooks/**, .githooks/pre-commit, the build state file (stub); by hand: authored gates, .gitignore lines]
---

# harness-forge — substitute what exists, author what doesn't

Kit root: run `cat ~/.claude/project-setup-kit.root` once; every kit path in this skill is relative to it. If the file is missing, the root is the directory two levels above this SKILL.md. Never search the disk (`find`, `ls -R`, globbing `~` or `/`) for kit files or for this skill: the skill is already loaded, and the root file is the only lookup.

You are producing a **multi-agent system made of prose files**. Nothing type-checks it. A skill can demand a tool it was never granted, write a file nobody reads, or contradict `CLAUDE.md` outright, and **it will all look fine until the build silently stops verifying itself.**

That is why you start from templates rather than from a blank page.

## Templates are the floor, not the ceiling

**Default: substitute.** `templates/{small,orchestrated}/` and `templates/gates/` hold a harness extracted from builds that actually survived — real defects fixed, a whole per-story ceremony retired because it was measured and lost. Their **contracts are correct**: tool grants, artifact ownership, return contracts, loop caps, gates-at-joins.

Those contracts are expensive to derive and easy to get subtly wrong. **Do not rewrite them.** Each rule keeps its reason, stated once, in one or two sentences, in the file that owns the rule; the same reason is never repeated across files (KD-021). The reason is what makes an agent comply under pressure, so a rule stripped of it gets rationalized past on its first hard day. A reason copied into a second file is worse: the copies drift, and the agent obeys whichever it read last.

**But you are not limited to them.** If this project needs a gate no template covers — a store-submission check, a data-migration verifier, a model-drift gate — **author it.** A stack the templates never anticipated is a normal outcome, not an error.

**What you must not do is fake it.** If the stack needs a gate you cannot write properly, emit no gate and say so. A gate that cannot really run gets skipped, faked, or rationalized past — **and the harness reports that it ran.** That is strictly worse than a harness that admits the check is missing.

## Procedure

The copying, filling and checking is a script, `scripts/forge.sh` under the kit root. It does in a second what used to take an agent most of an hour, and it cannot alter template text. Your job is the judgement: the values, and the parts no template covers.

1. **Read `<kit root>/templates/PLACEHOLDERS.md`.** It is the resolution contract: every key, where its value comes from, and the `HARNESS_VALUES.json` schema.
2. **Read the tier** from `PRD.md`'s `<!-- TIER -->` marker. Not the prose. The marker. It is `small` or `orchestrated`, nothing else. If you find `standard` or `full`, stop: the marker predates the two-tier model and `setup-project` must re-tier before you run.
3. **Read the gate manifest** in `STACK.md`. Every row is `yes` or `no`. Any other value means a stale manifest: stop and say so in your return (`setup-project` re-runs `stack-decide` in RE-TIER mode). The `yes` rows for this tier are the `gates` list.
4. **Measure the pre-commit cost** (see "Emit enforcement") to set `PRECOMMIT_TYPECHECK`.
5. **Write `HARNESS_VALUES.json` at the repo root**: every key `PLACEHOLDERS.md` lists for this tier, from `PRD.md`, `STACK.md`, `DESIGN.md` and the scaffolded repo. Confirm every path with `ls` first. Three values are judgement, not lookup, and each has its own section below: `ORGANISING_PRINCIPLE`, `INVARIANTS` (verbatim from the design), and `DB_PARALLEL_RULE` (one of the three canonical sentences). An empty string is the honest value for a command the stack does not have (`FORMAT_COMMAND`, `FRONTEND_CHECK_COMMAND`, `AUDIT_COMMAND`); the template line that needs it is then dropped.
6. **Run the script once:**
   ```bash
   KIT="$(cat ~/.claude/project-setup-kit.root 2>/dev/null)"
   bash "$KIT/scripts/forge.sh" <tier> HARNESS_VALUES.json .
   ```
   It copies the tier's `MANIFEST.md` file list, the gates in `gates`, the enforcement files, `notify.sh` and `ASK_CONTRACT.md`; fills every placeholder; resolves every `{{#IF}}`; collapses blank lines; sets executable bits; and never overwrites an existing state file. Non-zero exit: it names each unfilled placeholder, unused key or gate mismatch, and writes nothing. Fix `HARNESS_VALUES.json` and run it again. It does not run tests.
7. **Author any gate the stack needs that no template covers**, as `.claude/skills/<gate>/SKILL.md`, by hand. Same contracts (below). Note it in your return so the template library can absorb it later. Do not hand-edit a file `forge.sh` wrote: change the value and re-run, or the next forge silently undoes your edit.
8. **Gitignore** `REVIEWS_DIR` (join-review and doctor reports), `HARNESS_DOCTOR.md`, `PLAN_LINT.md`, `HARNESS_VALUES.json`, and `.env` / `*.env` (with `!*.env.example`). You chose the reviews path; `scaffold` was explicitly forbidden from guessing it.
9. **Activate the git hook:** `git config core.hooksPath .githooks`. Commit the state file on its own (the orchestrated pre-commit rule applies from the first commit).
10. **Verify the hooks with direct shell calls**, never with the check command:
    ```bash
    printf '%s' '{"tool_input":{"command":"git -C . push --force origin main"}}' | .claude/hooks/guard-bash.sh; echo $?   # 2
    printf '%s' '{"tool_input":{"command":"git status"}}' | .claude/hooks/guard-bash.sh; echo $?                      # 0
    printf '%s' '{"tool_input":{"file_path":".env"}}' | .claude/hooks/guard-writes.sh; echo $?                         # 2
    # orchestrated only: a subagent writing the state file is blocked, the orchestrator is not
    printf '%s' '{"tool_input":{"file_path":"PROGRESS.md"},"agent_id":"a1"}' | .claude/hooks/guard-writes.sh; echo $?  # 2
    printf '%s' '{"tool_input":{"file_path":"PROGRESS.md"}}' | .claude/hooks/guard-writes.sh; echo $?                 # 0
    .claude/scripts/notify.sh >/dev/null 2>&1; echo $?                                                                 # 2 (usage)
    ```
    Use the real state-file name. Any other result is a defect in what you emitted: fix it and re-run the line.
11. **Run `{{CHECK_COMMAND}}` once, at the end,** to prove the forged hooks and files did not break the green build. This is the only check run in this step; `scaffold` already proved green and red.

`setup-project` dispatches `harness-doctor` after you return. Do not run it yourself.

## `{{ORGANISING_PRINCIPLE}}` — one sentence that carries the judgement calls

The generated `CLAUDE.md` opens with **one load-bearing sentence** — the thing every rule below it serves (the canonical example: *"a silently wrong number is the worst possible outcome"*). It exists because agents facing a situation no brief anticipated need something to reason *from*; a checklist produces compliance, not the correct novel judgement.

Resolve it from **`PRD.md`** (the What/Why, and any stated quality bar) and **`DESIGN.md`'s invariants** — the principle is whatever single failure the design spends the most machinery preventing. It must be *this project's* sentence: falsifiable, consequence-shaped, something an agent could cite to refuse a plausible shortcut.

**If nothing concrete supports one, do not invent it.** Same rule as `{{INVARIANTS}}`: emit a placeholder-free generic line instead and **flag it in your return as a PRD gap.** A manufactured principle is worse than none — agents will faithfully optimize for a sentence nobody actually meant.

## Zero `{{` in the output. This one is not cosmetic.

An unresolved placeholder does not throw. An agent reading `Run {{CHECK_COMMAND}}` will **infer a plausible command, run it, and report green.** The verification you believe in has quietly stopped, and nothing tells you. `forge.sh` refuses to write a harness with one left, so this holds for every file it emits. **A gate you author by hand has no such check:** grep it for `{{` yourself.

*No exception.* No file `forge.sh` emits may contain the pattern: the harness ships no doctor skill (the kit's own `harness-doctor` audits it at setup), and `notify.sh` no longer carries it.

## Resolve the parallelism policy from what `scaffold` actually built

**This is a manifest-shaped decision, not a constant.** Emit only the *serialization* the stack actually requires. (`small` has one agent and neither placeholder; this section is orchestrated-only.)

Read `scaffold`'s returned **test-isolation strategy** — it is required to have decided one. Then resolve:

- **`{{MAX_PARALLEL}}`** — `3` unless you have a specific reason. See `PLACEHOLDERS.md`.
- **`{{DB_PARALLEL_RULE}}`** — one of the three literal sentences in `PLACEHOLDERS.md`. Do not paraphrase them.

**Do not emit a serialized harness because serial feels safer.** These templates once hardcoded "parallelism DISABLED," inherited from a build that genuinely had a shared database — after `scaffold` had started building per-worker isolation as a hard gate. Carrying the ban forward serialized every generated build forever, and nothing ever noticed, because a slow build looks exactly like a careful one. If isolation genuinely is missing, resolve the third sentence, which **names itself as a defect**, and say so in your return.

**And emit the dispatch mode with it.** The generated orchestrator dispatches a lone unit (U0, the only eligible `todo`, any follow-up) **synchronously**, so the call returns the report and nothing waits. It dispatches two or more units together with **`run_in_background: true`**, each with `isolation: "worktree"`, and collects every one before its turn ends: an unattended run stops background agents 10 minutes after the turn ends, so a turn never ends with a unit in flight. The templates carry this, with the liveness rule (a `wip` unit whose tree has not changed in 10 minutes is dead and is re-dispatched to finish what is there) and the settings `env` entry `CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0`. If you author a dispatcher yourself, carry all of it, with its two corollaries: **a launch confirmation is not a result**, and **units drain before a join**. `setup-project`'s own chain follows the same rule: each step runs alone, so each is synchronous.

## Emit the notification channel

The harness you are generating will, on some Tuesday, hit a blocker at 2am with nobody watching. **A build that stops silently is a build that has stopped forever**, and the way that resolves is a human eventually telling an agent to "just carry on" — past the exact gate that fired correctly.

So every harness ships with a way to reach its owner. `forge.sh` copies two files verbatim from the kit root. **Do not rewrite either one**:

| From (kit root) | To (target repo) |
|---|---|
| `scripts/notify.sh` | `.claude/scripts/notify.sh`, executable |
| `ASK_CONTRACT.md` | `.claude/ASK_CONTRACT.md` |

`{{NOTIFY}}` resolves to `.claude/scripts/notify.sh`; `forge.sh` sets it, it is not a key in `HARNESS_VALUES.json`.

**Everyone calls it directly** — the orchestrator included, since it has `Bash`. There is no notify-only relay task anymore; that workaround existed only for a tool-starved orchestrator that no longer exists.

**The target repo's `.claude/settings.json` must not contain a `Notification` hook.** The user's one notification hook is installed once, globally (the plugin ships it). A per-project copy fires *in addition* to it and buzzes the user twice, which trains them to ignore the channel, which costs you the one time it mattered.

Step 10 runs it with no arguments (usage, exit 2). Do **not** run `selftest`: it sends a real push, and the user did not ask for one.

## Emit enforcement

Every rule above is prose, and prose fails silently. A few rules are load-bearing enough to enforce in tooling, where a violation fails the same way every time (KD-020). Templates: `templates/enforcement/`, shared by both tiers. `forge.sh` emits them as below; `{{#IF ORCHESTRATED}}` is true only at the orchestrated tier.

| From `templates/enforcement/` | To (target repo) | Emit when |
|---|---|---|
| `settings.json.tmpl` | `.claude/settings.json` | always. Deny rules (force-push, hard reset, `--no-verify`, `git clean`, reading `.env` files), the guard hook, the compaction hook, and the format hook when `{{FORMAT_COMMAND}}` is set |
| `hooks/guard-writes.sh.tmpl` | `.claude/hooks/guard-writes.sh`, executable | always. Blocks writes to `.env`/`*.env` (not `*.env.example`) and `.git/`; at orchestrated, also blocks writes to `{{STATE_FILE}}` from any subagent |
| `hooks/guard-bash.sh.tmpl` | `.claude/hooks/guard-bash.sh`, executable | always. Matches the operations the deny rules name (force push, hard reset, skipped hooks, destructive clean) and shell writes to `.env` files or `.git/` anywhere in a command, because deny rules are prefix patterns and not a security boundary |
| `hooks/format.sh.tmpl` | `.claude/hooks/format.sh`, executable | only when `STACK.md` names a format command. No command means no file and no PostToolUse entry: a formatter hook with nothing to run is a gate that can't run |
| `githooks/pre-commit.tmpl` | `.githooks/pre-commit`, executable, tracked | always. At orchestrated: rejects a commit that stages `{{STATE_FILE}}` with anything but `{{DESIGN}}`. Both tiers: lints staged files when `{{LINT_STAGED_COMMAND}}` is set |

**The speed budget is a hard limit, not a target (KD-020).** These hooks never run tests, never run `{{CHECK_COMMAND}}`, `{{AFFECTED_TEST_COMMAND}}` or any test runner. The full suite runs where it already runs: once per story at small, once per join at orchestrated. Then:

- **Measure the pre-commit cost on the scaffolded repo** before you set `{{#IF PRECOMMIT_TYPECHECK}}`: time lint on a few source files plus `{{TYPECHECK_COMMAND}}`. Under 15 seconds together → include typecheck, at both tiers. Over → leave typecheck out. At orchestrated this is safe because each parallel unit works in its own worktree (KD-023), so one unit's half-written code never reaches another unit's commit. Lint alone over 15 seconds → leave `{{LINT_STAGED_COMMAND}}` empty too, and the hook keeps only the state-file rule. Report the measured numbers.
- Every hook in `settings.json` carries a `timeout`. The hooks that exist to block (the write guard, the Bash guard, and the state-file rule) fail closed; the two guards do it with `"onFailure": "block"`. The Bash guard runs on every shell command, so it exits at once when the command mentions neither `git` nor `.env`, and stays string matching only (under 50 ms). The format hook and the pre-commit lint fail open: a timeout or crash lets the action through.
- The compaction hook prints one line and reads nothing.

**Activate the git hook** (step 9). `core.hooksPath` is not tracked; both loop skills re-check it at every session start, because a fresh clone loses it.

**Do not add a `Notification` hook here.** See "Emit the notification channel".

## The five contracts (they apply to templates AND to anything you author)

Generated harnesses break in exactly these five places.

**1. Tool grants.** A skill's `allowed-tools` pre-approves tools; it restricts nothing. So list every tool the procedure uses (a gate that writes a report lists `Write`, one that invokes another skill lists `Skill`): a missing entry means a permission prompt, which stalls an unattended run. Where a skill must not use a tool, say so with `disallowed-tools` in its frontmatter. And a skill that will be dispatched must not need a tool a subagent lacks: subagents cannot ask the user a question, and background subagents get a reduced tool set.
→ **The generated orchestrator has FULL tools, including `Bash`, `Grep`, `Glob`, `Skill`, BY DESIGN.** The orchestrator reads the design contract itself, runs the check at joins, and rules on escalations. **Do not "harden" it back** with `disallowed-tools`. Its enforcement mechanism is the join protocol, not tool starvation.

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
- **The exact path of the build state file you created** (orchestrated: `PROGRESS.md` at the repo root). `setup-project` must seed it without searching for it. Omit this and it guesses.
- **Dispatch-unit count read from `PLAN.md`'s `## Dispatch units`, if the file exists** — usually it doesn't yet; say so.
- **Parallelism policy:** `{{MAX_PARALLEL}}` = N, and which `{{DB_PARALLEL_RULE}}` sentence you resolved to, naming the isolation `scaffold` built. The defect sentence is a finding, not a footnote.
- **Notification channel emitted:** `.claude/scripts/notify.sh` (executable) + `.claude/ASK_CONTRACT.md`, `{{NOTIFY}}` resolved everywhere, **no** `Notification` hook emitted.
- **Enforcement emitted:** hooks emitted (always `guard-writes.sh` and `guard-bash.sh`), hooks omitted and why (no format command, lint or typecheck over the speed budget, with the measured seconds), the deny rules, `core.hooksPath` set, and that the state-file guard runs at both levels at orchestrated (tool level via the subagent check, commit level via pre-commit) and at neither at small.
- **`forge.sh` exit 0** (it refuses to write with a placeholder left) and the file list it printed; the `{{` grep result for any gate you authored by hand.
- **Hook checks:** each line of step 10 with its exit code.
- **The one check run:** `{{CHECK_COMMAND}}` result at the end (pass count).
- The first command the user runs to start building.

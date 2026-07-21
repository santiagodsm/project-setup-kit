---
name: harness-forge
version: 0.2.0
description: "Generate the project's own build harness from the tier templates: CLAUDE.md, .claude/skills/*, .claude/agents/*, sized to the build tier, containing only the gates the stack can run. Substitutes templates by default; authors new gates from the contracts when the stack needs one no template covers. Step 5 of project setup. Ends by running harness-doctor and does not complete with an open BLOCKER."
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
  reads: [templates/**, STACK.md (gate manifest + check command), DESIGN.md, PRD.md (TIER marker), the scaffolded repo]
  writes: [target repo CLAUDE.md, .claude/skills/**, .claude/agents/**, .claude/scripts/notify.sh + .claude/ASK_CONTRACT.md (copied verbatim from the plugin root), the build state file (stub), .gitignore (harness dirs, .env), STACK.md (resolves DEFERRED manifest rows ONLY)]
---

# harness-forge — substitute what exists, author what doesn't

You are producing a **multi-agent system made of prose files**. Nothing type-checks it. A skill can demand a tool its agent was never granted, write a file nobody reads, or contradict `CLAUDE.md` outright, and **it will all look fine until the build silently stops verifying itself.**

That is why you start from templates rather than from a blank page.

## Templates are the floor, not the ceiling

**Default: substitute.** `templates/{small,standard,full}/` and `templates/gates/` hold a harness extracted from a build that actually survived — dozens of stories, several rounds of auditing, real defects fixed (a reviewer with no `Write`, an orphaned state-file commit, an unreachable gate, an OOM from concurrent migrations). Its **contracts are correct**: tool grants, artifact ownership, return contracts, loop caps, the two-tier verification model.

Those contracts are expensive to derive and easy to get subtly wrong. **Do not rewrite them. Do not "improve" them. Do not summarize them** — the reasoning prose (*why* the orchestrator has no Bash, *why* red is never "environmental") is what makes an agent comply under pressure. Strip it and you get a harness that gets rationalized past on its first hard day.

**But you are not limited to them.** If this project needs a gate no template covers — a mobile store-submission check, a data-migration verifier, an ML-model-drift gate, a compliance scan — **author it.** A stack the templates never anticipated is a normal outcome, not an error.

When you author a new gate, it obeys the same five contracts (below). Write it to the target repo, and note it in your return so the template library can absorb it later.

**What you must not do is fake it.** If the stack needs a gate you cannot write properly, emit no gate and say so. A gate that cannot really run gets skipped, faked, or rationalized past — **and the harness reports that it ran.** That is strictly worse than a harness that admits the check is missing.

## Procedure

1. **Read `templates/PLACEHOLDERS.md`.** It is the resolution contract.
2. **Read the tier** from `PRD.md`'s `<!-- TIER -->` marker. Not the prose. The marker.
3. **Read the gate manifest** in `STACK.md`.
4. **Resolve the `DEFERRED` rows.** `stack-decide` ran before `DESIGN.md` existed and could not decide `perf-profiling`. You can: **§8 has numeric targets → yes; none → no.** **Write your answer back into `STACK.md`'s manifest table.** A `DEFERRED` row must not survive — `harness-doctor` cannot classify one, and the fidelity check then silently passes on a gate nobody ever decided.
5. **Copy `templates/<tier>/**`** into the target repo — **except `MANIFEST.md`**, which is kit documentation, is full of unresolved placeholders by design, and would ship as an orphan file that trips the grep in step 11.
6. **Emit gates per the manifest's tier column.** It has three values, not two:
   - **`yes`** → copy `templates/gates/<gate>/` into the target repo.
   - **`no`** → **do not emit it.** At that tier nothing dispatches it, so the file would be an orphan — a gate the harness appears to have and doesn't. `harness-doctor` check 3 blocks on it.
   - **`inline`** → **do not emit a skill file.** The check is already folded into `story-reviewer` step 5 in that tier's template (the migration cycle, the contract-drift check, the token lint). It runs; it just isn't a separate file. Emitting one as well gives you two copies of the same check, one of which nothing calls.

   `regression-run`, `code-review`, and `docs-sync` are **tier-core**: they live in `templates/<tier>/skills/`, not `templates/gates/`, and step 5 already copied them. Do not look for them in `gates/` and do not author duplicates at step 7.
7. **Author any gate the stack needs that no template covers.** Same contracts.
8. **Resolve every placeholder.** Confirm every path with `ls` before writing it. **Including `{{MODEL_*}}`:** each agent declares a `model:` tier (see `PLACEHOLDERS.md` → "per-agent model tier"). Take the defaults — scoper `sonnet`, implementer and reviewer `opus` — unless something about this project argues otherwise, and keep the strong default when unsure. Spend the cheap model where the work is bounded and mechanical (the scoper), never on the independent reviewer. Resolve to a literal tier; a surviving `{{MODEL_*}}` trips the grep in step 11 like any other placeholder.
9. **Stub the state file.** `PLAN.md` doesn't exist yet (step 6). Emit every required section with `NEXT ACTION: awaiting PLAN.md`. **Do not invent a first story** — an orchestrator booting at a fabricated story is worse than one booting at nothing.
10. **Gitignore** the harness's working dirs (`{{BRIEFS_DIR}}`, `{{REVIEWS_DIR}}`), plus `HARNESS_DOCTOR.md`, `PLAN_LINT.md`, and `.env` / `*.env` (with `!*.env.example`). You chose the first two paths; `scaffold` was explicitly forbidden from guessing them. The `.env` rules are belt-and-braces — the real credentials live in `~/.claude/pushover.env`, outside every repo — but a project that later adds a local override must not have to remember this. **Then emit the notification channel — see the section below. No tier skips it.**
11. **Grep the output for `{{`.** Zero hits. See below.
12. **Run `harness-doctor`**, read its report file, fix every BLOCKER. **Three rounds max**, then stop and report failure with the findings — a generator that can't converge in three rounds does not understand what it produced.

## Zero `{{` in the output. This one is not cosmetic.

An unresolved placeholder does not throw. An agent reading `Run {{CHECK_COMMAND}}` will **infer a plausible command, run it, and report green.** The verification you believe in has quietly stopped, and nothing tells you.

Same for a stray `{{#IF}}`: resolve the condition, then **delete the markers.**

*One exception, and read it precisely:* `harness-doctor`'s template must **name** the pattern in order to grep for it, so its check-0 grep quotes a bare `{{` on a line tagged `PLACEHOLDER-LITERAL`. **That one literal is exempt.**

**The exemption is on that line, not on the file.** That same file also carries real placeholders — `{{STATE_FILE}}`, `{{REVIEWS_DIR}}`, `{{BRIEFS_DIR}}` — and **every one of them must still resolve.** Skip the file wholesale and you ship a doctor whose report path is literally `{{REVIEWS_DIR}}harness-doctor-<date>.md`. That is precisely the failure this check exists to catch, embedded in the thing that checks for it.

## Resolve the parallelism policy from what `scaffold` actually built

**This is a manifest-shaped decision, not a constant.** The same reasoning as the gate manifest (emit only what the stack can honor) applies here, in the opposite direction: emit only the *serialization* the stack actually requires.

Read `scaffold`'s returned **test-isolation strategy** — it is required to have decided one, and `stack-decide` was required to specify it. Then resolve:

- **`{{MAX_PARALLEL}}`** — `3` unless you have a specific reason. See `PLACEHOLDERS.md`.
- **`{{DB_PARALLEL_RULE}}`** — one of the three literal sentences in `PLACEHOLDERS.md`. Do not paraphrase them.

**Do not emit a serialized harness because serial feels safer.** These templates used to hardcode "parallelism DISABLED — unblock condition: per-worker DB isolation," inherited from a build that genuinely had a shared database. `scaffold` now *builds* that isolation as a hard gate one step before you run, so the unblock condition is satisfied before the harness exists. Carrying the ban forward serialized every generated build forever, on a constraint that had already been removed — and nothing ever noticed, because a slow build looks exactly like a careful one.

If isolation genuinely is missing, resolve the third sentence, which **names itself as a defect**, and say so in your return. Do not silently paper it into a serial harness.

**And emit the dispatch mode with it.** A concurrency policy the orchestrator cannot execute is worse than no policy: the generated harness must tell the orchestrator to dispatch every subagent with **`run_in_background: true`**, or "up to `{{MAX_PARALLEL}}` at once" runs strictly one-at-a-time while every file still reads as parallel. Nothing detects it — the build is simply slower than it claims, forever. The templates carry this; if you author an orchestrator or a gate dispatcher yourself, carry it too, along with its two corollaries: **a launch confirmation is not a result**, and **gates and handoffs drain first**.

Note the asymmetry, and do not "fix" it: **`setup-project`'s own chain is dispatched synchronously**, because each step's output is the next step's input and there is nothing to overlap. The rule in both places is the same — dispatch in the background exactly when there is other work to do meanwhile.

## Emit the notification channel

The harness you are generating will, on some Tuesday, hit a blocker at 2am with nobody watching. **A build that stops silently is a build that has stopped forever**, and the way that resolves is a human eventually telling an agent to "just carry on" — past the exact gate that fired correctly.

So every harness ships with a way to reach its owner. Two files, copied verbatim from the plugin root — **do not rewrite either one**:

| From (plugin root) | To (target repo) |
|---|---|
| `scripts/notify.sh` | `.claude/scripts/notify.sh` — **`chmod +x` it** |
| `ASK_CONTRACT.md` | `.claude/ASK_CONTRACT.md` |

Then resolve **`{{NOTIFY}}`** to the literal invocation the generated agents will use: `` `.claude/scripts/notify.sh` ``.

**Do not emit a `Notification` hook into the target repo's `.claude/settings.json`.** The user installs one hook once, globally, in `~/.claude/settings.json`, and it covers every project. A per-project copy fires *in addition* to it and buzzes the user twice for the same event — which trains them to ignore the channel, which costs you the one time it mattered.

**Who can actually call it.** `Bash` is required, so:

- **The scoper, the engineer, the reviewer, and every gate** call it directly. They have `Bash`, and they are the ones who *discover* blockers.
- **The orchestrator has no `Bash` and must not be given any** — that restriction is contract 1 and it is load-bearing. For a blocker the orchestrator finds itself (a dependency deadlock, a twice-failed review, a repair loop hitting its bound), it **dispatches a notify-only task**, exactly as it already dispatches a commit-only task to flush the state file. Say this in the orchestrator skill in those words; the parallel to the commit-only task is what makes it stick.

Verify with `.claude/scripts/notify.sh` (no arguments) — it prints usage and exits 2. Do **not** run `selftest` from here: it sends a real push, and the user did not ask for one.

## The five contracts (they apply to templates AND to anything you author)

Generated harnesses break in exactly these five places.

**1. Tool grants.** Every agent's `tools:` covers what its skill demands. A skill's `allowed-tools` **intersects down** once loaded. A reviewer that writes a report needs `Write`. One that invokes gates needs `Skill`. An engineer that commits needs `Bash`. **An agent with no `tools:` frontmatter inherits its dispatcher's set** — so if the orchestrator is restricted, the agent silently is too.
→ **The orchestrator's missing `Bash`/`Grep`/`Glob` is deliberate.** It is the enforcement mechanism for "never reads code, never re-runs the suite." Do not repair it into an affordance.

**2. Artifact ownership.** Every read has exactly one writer. Draw the table. Orphan read → the agent invents the file. Two writers on the state file → clobbered mid-story. A report with no declared path, while something else builds a pointer into it → unconstructable.

**3. Return contracts — and their dispatch mirror.** The orchestrator does not read the files, so everything it needs is in the *returns*. It records a commit hash and a date and has no Bash and no clock → the engineer returns both. It writes each fix-story's state-file line — the finding's text **verbatim** plus `source: <report> #3` — from the return alone → every gate returns findings **numbered**, self-contained, with its report filename (the finding text must live in the tracked state file, because the reports are gitignored and vanish on a fresh clone). The symmetric rule binds dispatches: a prompt carries the role, the ID, the paths to read, and only the values the callee cannot get from disk — never the contents of a file that is on disk.

**4. Dispatch reachability.** Story roles are **agents** → `subagent_type`. Gates are **skills, not agents** → the orchestrator has no `Skill` tool, so it dispatches a general-purpose subagent told to invoke the skill. State this, or the gate is unreachable and gets quietly skipped.

**5. Loop termination.** Review retry: capped. Fix-story ↔ regression: bounded (same failure survives two cycles → blocked). **Exactly one stop signal** (the context system-reminder) — no story caps, no session caps, no "natural stopping point."

## Bake in the project, not a generic

The generated skills must read as if hand-written for this project:

- The **verbatim `{{CHECK_COMMAND}}`**, never "run the tests."
- **Real paths**, confirmed with `ls`.
- The real commit format, the real migration commands, the real container names.
- `DESIGN.md`'s section convention, so the scoper cites correctly — including `{{GLOSSARY_SECTION}}` (§2.1), the glossary the scoper and reviewer both read to keep the code's vocabulary aligned with the design's.
- **`{{INVARIANTS}}`** — the project's actual assertions from §5/§12, verbatim.

That last one carries the whole `code-review` gate. *"Any code writing a balance column is a defect"* catches the bug. *"Check that the code is correct"* checks nothing. **If §5/§12 give you nothing concrete, do not invent invariants** — emit without them and flag it. The design is the gap, and a gate full of platitudes is one more thing reporting green without looking.

## Return (~150 words)

- Tier emitted; agents and skills generated.
- **Gates included; gates deliberately excluded** (name the exclusions — they are what make the harness honest).
- **Per-agent model tiers set**, and any deviation from the scoper-`sonnet` / implementer-`opus` / reviewer-`opus` default, with why.
- **Any gate you authored from scratch**, and why no template covered it.
- `{{CHECK_COMMAND}}`, verbatim, as wired in.
- **The exact path of the build state file you created.** `setup-project` must seed it at step 8 and has no Glob. Omit this and it guesses.
- **Parallelism policy:** `{{MAX_PARALLEL}}` = N, and which of the three `{{DB_PARALLEL_RULE}}` sentences you resolved to — **naming the isolation `scaffold` built**. If you emitted the defect sentence, say so as a finding, not a footnote.
- **Notification channel emitted:** `.claude/scripts/notify.sh` (executable) + `.claude/ASK_CONTRACT.md`, and `{{NOTIFY}}` resolved everywhere. Say you did **not** emit a `Notification` hook — that one is the user's, installed once globally.
- Placeholder grep: **zero `{{` remaining.**
- **`harness-doctor`: N blockers found, N fixed, final = CLEAN.** Report nothing else as success.
- The first command the user runs to start building.

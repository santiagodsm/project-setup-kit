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
  writes: [target repo CLAUDE.md, .claude/skills/**, .claude/agents/**, the build state file (stub), .gitignore (harness dirs), STACK.md (resolves DEFERRED manifest rows ONLY)]
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
10. **Gitignore** the harness's working dirs (`{{BRIEFS_DIR}}`, `{{REVIEWS_DIR}}`), plus `HARNESS_DOCTOR.md` and `PLAN_LINT.md`. You chose those paths; `scaffold` was explicitly forbidden from guessing them.
11. **Grep the output for `{{`.** Zero hits. See below.
12. **Run `harness-doctor`**, read its report file, fix every BLOCKER. **Three rounds max**, then stop and report failure with the findings — a generator that can't converge in three rounds does not understand what it produced.

## Zero `{{` in the output. This one is not cosmetic.

An unresolved placeholder does not throw. An agent reading `Run {{CHECK_COMMAND}}` will **infer a plausible command, run it, and report green.** The verification you believe in has quietly stopped, and nothing tells you.

Same for a stray `{{#IF}}`: resolve the condition, then **delete the markers.**

*One exception, and read it precisely:* `harness-doctor`'s template must **name** the pattern in order to grep for it, so its check-0 grep quotes a bare `{{` on a line tagged `PLACEHOLDER-LITERAL`. **That one literal is exempt.**

**The exemption is on that line, not on the file.** That same file also carries real placeholders — `{{STATE_FILE}}`, `{{REVIEWS_DIR}}`, `{{BRIEFS_DIR}}` — and **every one of them must still resolve.** Skip the file wholesale and you ship a doctor whose report path is literally `{{REVIEWS_DIR}}harness-doctor-<date>.md`. That is precisely the failure this check exists to catch, embedded in the thing that checks for it.

## The five contracts (they apply to templates AND to anything you author)

Generated harnesses break in exactly these five places.

**1. Tool grants.** Every agent's `tools:` covers what its skill demands. A skill's `allowed-tools` **intersects down** once loaded. A reviewer that writes a report needs `Write`. One that invokes gates needs `Skill`. An engineer that commits needs `Bash`. **An agent with no `tools:` frontmatter inherits its dispatcher's set** — so if the orchestrator is restricted, the agent silently is too.
→ **The orchestrator's missing `Bash`/`Grep`/`Glob` is deliberate.** It is the enforcement mechanism for "never reads code, never re-runs the suite." Do not repair it into an affordance.

**2. Artifact ownership.** Every read has exactly one writer. Draw the table. Orphan read → the agent invents the file. Two writers on the state file → clobbered mid-story. A report with no declared path, while something else builds a pointer into it → unconstructable.

**3. Return contracts.** The orchestrator does not read the files, so everything it needs is in the *returns*. It records a commit hash and a date and has no Bash and no clock → the engineer returns both. It builds `source: <report>, finding #3` → every gate returns findings **numbered**, with its report filename.

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
- Placeholder grep: **zero `{{` remaining.**
- **`harness-doctor`: N blockers found, N fixed, final = CLEAN.** Report nothing else as success.
- The first command the user runs to start building.

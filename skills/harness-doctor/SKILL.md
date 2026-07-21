---
name: harness-doctor
version: 1.0.0
description: "Audit the agent harness itself (CLAUDE.md + .claude/skills/* + .claude/agents/* + the state file) for internal contradictions, missing tools, orphan artifacts, unreachable dispatch paths, and broken return contracts. Run after ANY edit to the harness, and before the first build session of a newly generated one. Use when the user says 'check the harness', 'audit the skills', 'did I break the orchestration', or after adding/editing a skill or agent."
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Write
  - Skill
  - ToolSearch
metadata:
  role: reviewer
  reads: [CLAUDE.md, .claude/skills/**/SKILL.md, .claude/agents/*.md, the build state file, STACK.md (gate manifest), PRD.md (tier), PLAN.md (if it exists), .gitignore]
  writes: [HARNESS_DOCTOR.md — never a skill, never an agent, never product code]
---

# harness-doctor — audit the harness, not the product

The harness is a distributed system whose components are prose files. Nothing type-checks it. A skill can demand a tool its agent was never granted, write to a file nobody reads, read a file nobody writes, or contradict `CLAUDE.md` outright, and **everything will look fine until it silently doesn't.** The failures are not loud: the agent improvises, rationalizes past the missing gate, and the build keeps moving while a check you believe in has quietly stopped running.

You are the type-checker. You **report only**. You never edit a skill, an agent, or `CLAUDE.md` — a doctor that rewrites the thing it is diagnosing has destroyed the audit.

## Scope

Read **all** of:
- `CLAUDE.md` (and any nested `CLAUDE.md`)
- every `.claude/skills/*/SKILL.md` and every `.claude/agents/*.md`
- **the build state file, whatever it is called.** Do not assume a name — `glob` for it. Small-tier harnesses use `PROGRESS.md` at the root; heavier ones use `docs/IMPL_PROGRESS.md`. A doctor that hardcodes one name will report the other as missing.
- `.gitignore`
- the build-tool manifest (`Makefile`, `package.json`, `pyproject.toml`, `justfile`, whatever this project has) — enough to verify the commands the skills invoke actually exist

**And the two files that define what this harness was *supposed* to be:**
- **`STACK.md` → the gate manifest.** The list of gates the stack can actually run.
- **`PRD.md` → the `<!-- TIER: x -->` marker.** What size harness was called for.

Then use `bash`/`git` to check claims against reality. **A path a skill references either exists or is a declared template placeholder. There is no third option.**

## Judge against the tier and the manifest, not against a template

Before you flag a single absent gate, read the tier and the manifest. Otherwise you will produce a report that is confidently, uselessly wrong.

- **A `small`-tier harness has no gates and no epic boundaries. That is correct.** Reporting "docs-sync is missing" on a small harness is noise, and noise in a mandatory gate teaches people to skim it.
- **A gate absent from the manifest must be absent from the harness.** No migration tool → no migration gate. Its absence is the design working.
- **The inverse is a BLOCKER, and it is the one check nobody else performs:** a gate present in the harness but **not** in the manifest, or present but unable to run against this stack. That gate will be skipped, faked, or rationalized past — **and the harness will report that it ran.** This is the single most important thing you check, because nothing else in the entire system checks it.

So, for every gate: in the manifest? in the harness? Both, or neither. Any mismatch is a finding.

## The thirteen checks

Each is grounded in a defect class that has actually shipped in a hand-written harness. Run all thirteen.

### 0. Unresolved placeholders (run this FIRST — it is the cheapest and the most dangerous to skip)

If the harness was produced by `harness-forge` from templates, grep it:

```bash
grep -rn -e '{{' --include='*.md' \
  --exclude-dir=.git --exclude='*/harness-doctor/SKILL.md' \
  CLAUDE.md .claude/ 2>/dev/null
```

**Zero hits. Every hit is a BLOCKER.**

An unresolved placeholder does not throw. An agent reading `Run {{CHECK_COMMAND}}` will **infer a plausible command, run it, and report green.** The check you believe in has silently stopped running. A stray `{{#IF` means the condition was never resolved and the markers never deleted.

The `--exclude` on `harness-doctor` is required: any doctor skill must name the pattern to search for it, so its own prose contains it. Do not extend that exclusion to any other file.

Skip if the harness was hand-written and uses no templates.

### 1. Tool sufficiency
For every agent: does its `tools:` list cover everything its skill's procedure demands? And does the skill's own `allowed-tools` (which **intersects down** once the skill loads) still cover it?

- A reviewer told to write `docs/_reviews/<ID>-review.md` but granted no `Write`.
- An engineer told to run `make check` and `git commit` but with no `tools:` frontmatter, so it inherits the *orchestrator's* restricted set and gets no `Bash`.
- A reviewer whose agent file grants `Skill` but whose skill's `allowed-tools` omits it, so the moment it loads the skill it can no longer invoke the gates that same skill orders it to invoke.

Also check the inverse: an orchestrator **deliberately** denied `Bash` is not a bug, it is the enforcement mechanism. Do not "fix" a restriction into an affordance. Distinguish *missing capability* from *intentional constraint* by reading why the file says the tool is absent.

### 2. Artifact ownership (every read has exactly one writer)
Build the full table: for every file any agent reads or writes, who writes it and who reads it.

- **Orphan read:** an agent reads `docs/_briefs/<ID>-brief.md` but no agent is told to write it.
- **Orphan write:** a gate writes a report nobody reads.
- **Two writers:** the orchestrator claims sole ownership of the state file while three gate skills also contain "update `IMPL_PROGRESS.md`" instructions. That is a clobber waiting to happen.
- **Unnamed artifact:** a skill says `writes: [an audit report]` with no path, while another skill is told to build a pointer *into* that report. The pointer is unconstructable.

### 3. Dispatch reachability
Every component someone is told to invoke must be invocable **by that caller, with that caller's tools.**

- An orchestrator told to dispatch a gate — but the gate is a *skill*, not an agent, and the orchestrator has no `Skill` tool and there is no agent file for it. Unreachable.
- A skill that exists but nothing ever triggers. Dead code in the harness is **a gate you think you have and don't**, which is strictly worse than not having it.
- Conversely: a rule saying "no general-purpose fallback" that forecloses the only mechanism a gate had.

*(Check the tier first. On a small-tier harness there are no gates by design — their absence is not a finding. See "Judge against the tier" above.)*

### 4. Return-contract sufficiency
For every producer→consumer pair, does the producer's **declared return** contain everything the consumer's procedure requires? The consumer cannot read the producer's mind, and often cannot read the producer's file either.

- The orchestrator must record a commit hash and a date, but has **no Bash and no clock**, and no subagent's return contract carries either.
- The orchestrator must build a pointer like `source: <report>, finding #3`, but never reads gate reports, and no gate's return contract carries the finding **number**.
- A gate writes `report-<EPIC>-<date>.md` but is dispatched twice per gate cycle → same filename, silent overwrite, and every pointer into the first report now resolves to different content.

This check finds the subtlest bugs. Trace at least one full happy path end to end, naming every input at every hop.

### 5. Doc-vs-skill contradiction
`CLAUDE.md`, the skills, and the state file's operating-facts must agree. When they disagree, the agent obeys whichever it read most recently or most literally — which is not the one you meant.

- `CLAUDE.md` says the orchestrator writes the brief; the skill says a scoper does.
- `CLAUDE.md` allows inline review for small stories; the skill says "every story, no exceptions."
- `CLAUDE.md` carries a session/story cap that the skill deleted.
- The state file's operating-facts say the orchestrator commits; the skill says the engineer does.
- `CLAUDE.md` tells the engineer to `export DB_URL` before the test command; four skills say never to.

**Report which file wins.** A harness must declare an authority (usually the orchestrator skill). If it doesn't, that itself is a finding.

### 6. Path and command validity
Every path, every command, every filename. Check them against the repo.

- Docs claimed to be in `/docs` that are actually at the repo root.
- A migrations directory named that doesn't exist.
- A `make` target or `npm` script a skill invokes that isn't defined.
- A working directory referenced but never created and not gitignored.
- Artifact directories (`_briefs/`, `_reviews/`) that agents are told to create but which aren't gitignored, so evidence and briefs get committed. Verify with `git check-ignore -v`.

### 7. Loop termination
Every loop in the harness must be bounded, and every stop condition must be reachable.

- A retry loop: "retry once, then block" — good. "Repeat until green" with no cap — a fix that passes its own review but doesn't clear the failure loops forever.
- A stop signal that can never fire (e.g. "hand off on the third dispatch round" when the retry cap already blocks at two).
- A stop condition list that says "one item, on purpose" and then refers to "one of the two signals above." Plural invites the agent to hunt for a signal that isn't there.

### 8. Early-stop residue
Anything that lets an agent stop before its work is done. **Grep for it explicitly**, because it hides.

Story caps, session caps, "~N stories", "natural stopping point", "this seems like a good place to pause", "a reasonable amount of work". Every one of these is a self-imposed limit the model will happily honor, and each costs a full resume cycle. If the harness declares a single stop signal, verify **no file anywhere** offers a second.

### 9. Ordering constraints
Where a harness declares an order, verify it is stated identically everywhere and that violating it is actually prevented.

- A doc-sync step that rewrites the design to match what was built **must** run after any review that judges the code *against* that design. Run it first and the fidelity check becomes tautological — it can never find anything.
- A gate whose result is recorded before fix-stories land is recording a stale result.
- The same order restated three times in three files must be the *same* order. Check the hard-rules list against the procedure section; a hard rule with the stale order is the copy an agent obeys under pressure.

### 10. Cross-cutting invariants
Whatever the harness claims about itself, verify mechanically:
- If it claims the orchestrator's context stays flat, check nothing forces it to read raw test output, a diff, or the design.
- If it claims single-writer on a file, check for a second writer.
- If it claims a gate is mandatory, check it has a dispatcher and a failure path.
- **Parallelism: check the policy against the isolation that actually exists — in both directions.** This is the gate-manifest check applied to concurrency, and it fails both ways:
  - Harness says **serial / one-at-a-time**, but `scaffold` built per-worker isolation → **MAJOR.** The build runs at a fraction of its speed forever, on a constraint that was removed before the harness existed. It is invisible: a slow build looks exactly like a careful one, and every session assumes the last one had a reason.
  - Harness permits **concurrent engineers**, but there is no per-worker DB isolation and stories touch the DB → **BLOCKER.** Concurrent suites corrupt each other and produce flaky verdicts, which is worse than slow: the two-tier verification model rests on a green meaning something.
  - `the DB-parallel rule` resolved to something vague, or paraphrased rather than one of the three canonical sentences → **MAJOR.** An agent reading a hedge takes the permissive reading.
  - The scoper's return contract omits **`Files:`** while the orchestrator gates concurrency on it → **BLOCKER.** The orchestrator is deciding co-dispatch on data nobody returns, so it will either serialize everything or guess.
  - The harness states a concurrency policy but **never tells the orchestrator to dispatch in the background** → **BLOCKER.** This is the policy-with-no-execution-path defect and it is invisible by construction: a synchronous dispatch blocks until that agent returns, so "up to N concurrent" runs strictly one-at-a-time while every file still reads as parallel. Nothing is wrong, nothing reports, the build is simply N times slower than it claims. Grep for the background-dispatch instruction; its absence is the finding.
  - A gate or a handoff is described **without a drain precondition** (no story left `in_progress`) → **MAJOR.** A full-suite gate run while engineers are still writing describes a state that never existed, and the dangerous direction is a false GREEN closing a boundary on unfinished work.
  - Anything treats a **dispatch as a completion** — marking a story `done`, or writing a commit hash, from a launch rather than a return → **BLOCKER.** Under background dispatch that records outcomes that never happened.

### 11. Gate manifest fidelity (the check nobody else performs)
Cross-check `STACK.md`'s gate manifest against the gates actually in `.claude/skills/`.

**The manifest is already tier-adjusted** — `stack-decide` writes `no` for every gate on a small tier. So you compare against the manifest, **not** against some ideal gate set. Do not second-guess a `no`.

| Manifest says | Harness has | Verdict |
|---|---|---|
| yes | yes | correct |
| no | no | correct — including a small-tier harness with **no gates at all** |
| yes | **no** | **BLOCKER** — a gate the project needs was never emitted |
| **no** | yes | **BLOCKER** — a gate that cannot run against this stack. It will be skipped, faked, or rationalized past, **and the harness will report that it ran.** |
| **inline** | no separate skill file, **and** the check appears in `story-reviewer` step 5 | correct — this is the `standard` tier working. The check runs; it just isn't a file. |
| **inline** | a separate skill file exists | **BLOCKER** — two copies of the same check, and nothing dispatches the standalone one. |
| **inline** | no skill file **and** nothing in `story-reviewer` | **BLOCKER** — the check vanished entirely. |
| **DEFERRED** | either | **BLOCKER** — `harness-forge` was supposed to resolve this row to yes/no and write it back. An unresolved row means a gate nobody ever decided, and I cannot tell whether its presence or absence is correct. |

Also verify each present gate's commands actually exist (the `make` target, the `npm` script). A gate invoking a command that isn't defined is a gate that fails on first use and then gets quietly disabled by whoever hits it.

### 12. The notification channel reaches somebody

The harness tells its agents to push a blocker to the user's phone. If that path is broken, the failure is **silent in both directions**: the agent runs a command that isn't there, the script it expected exits 0 by design, and the user is never told the build stopped. Everything reports fine. Nobody is coming.

| | |
|---|---|
| `.claude/scripts/notify.sh` exists and is **executable** | missing or non-executable → **BLOCKER** |
| Every path any harness file names for it resolves to that same file | mismatch → **BLOCKER** (the agent runs nothing) |
| `.claude/ASK_CONTRACT.md` exists | missing → **MAJOR** — the pushes will send, and they will be unanswerable |
| `.gitignore` covers `.env` / `*.env` | missing → **MAJOR** |
| Every agent instructed to call it has `Bash` in its grant | missing → **BLOCKER** (this is check 1, applied here) |
| The **orchestrator** is told to *dispatch a notify-only task*, not to run the script | told to run it directly → **BLOCKER** — it has no `Bash`; the instruction is unexecutable, and the agent will improvise or skip |
| No `Notification` hook in the target repo's `.claude/settings.json` | present → **MINOR** — it double-fires against the user's global hook, and a channel that cries wolf gets muted |

**Do not run `notify.sh selftest`.** It sends a real push. You are auditing, and nobody asked to be buzzed.

Skip this check entirely if the harness genuinely has no notification channel — but say so in the report as a MINOR, with the consequence stated: this build cannot tell anyone it stopped.

## Output

Write full detail to **`HARNESS_DOCTOR.md`** at the repo root. **Number every finding** — the caller (`harness-forge`, or a human) fixes by number, and never reads your report unless something is wrong.

Per finding: `#N`, severity, the **two or more files that disagree** (with `file:line` quotes for each), the concrete failure it produces at runtime, and the fix. Severity:

| | |
|---|---|
| **BLOCKER** | The harness will fail or silently skip a gate on the next run. **Unresolved placeholder**, missing tool, unreachable dispatch, orphan read, unbounded loop. |
| **MAJOR** | Contradiction that will cause an agent to do the wrong thing under pressure. Doc-vs-skill conflict, stale hard rule, early-stop residue. |
| **MINOR** | Stale reference, wrong path, cosmetic drift. Wrong today, load-bearing later. |

**Return a capped summary (~150 words):** counts by severity, the report filename, and one numbered line per BLOCKER and MAJOR. Nothing else. Do not paste the report.

## Guardrails

- **Report only. Never edit a skill, an agent, `CLAUDE.md`, or the state file.** Someone else fixes; you diagnose. A doctor that patches its own findings cannot be trusted about the next set.
- **Verify against the repo, not the prose.** A skill asserting a file exists is not evidence. `ls` is.
- **Do not fail a deliberate constraint.** An orchestrator with no `Bash` is the design working. Read *why* before you flag.
- **Trace, don't skim.** Most real defects live in check 4 (return contracts) and check 2 (artifact ownership), and neither is visible by reading files one at a time. Build the tables. Walk one full happy path, hop by hop, naming every input.
- **Expect to find things.** A hand-written harness of a dozen skills routinely carries a handful of blockers. Returning "clean" on a harness that has never been doctored means you skimmed.

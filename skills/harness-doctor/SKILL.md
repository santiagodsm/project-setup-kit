---
name: harness-doctor
version: 1.1.0
description: "Audit the agent harness itself (CLAUDE.md + .claude/skills/* + the state file, plus any leftover .claude/agents/*) for internal contradictions, missing tools, orphan artifacts, unreachable dispatch paths, and broken return contracts. Run after ANY edit to the harness, and before the first build session of a newly generated one. Use when the user says 'check the harness', 'audit the skills', 'did I break the orchestration', or after adding/editing a skill or agent."
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
  reads: [CLAUDE.md, .claude/skills/**/SKILL.md, .claude/agents/*.md (if any exist), the build state file, STACK.md (gate manifest), PRD.md (tier), PLAN.md (if it exists), .gitignore]
  writes: [HARNESS_DOCTOR.md — never a skill, never an agent, never product code]
---

# harness-doctor — audit the harness, not the product

The harness is a distributed system whose components are prose files. Nothing type-checks it. A skill can demand a tool it was never granted, write to a file nobody reads, read a file nobody writes, or contradict `CLAUDE.md` outright, and **everything will look fine until it silently doesn't.** The failures are not loud: the agent improvises, rationalizes past the missing gate, and the build keeps moving while a check you believe in has quietly stopped running.

You are the type-checker. You **report only**. You never edit a skill, an agent, or `CLAUDE.md` — a doctor that rewrites the thing it is diagnosing has destroyed the audit.

## Scope

Read **all** of:
- `CLAUDE.md` (and any nested `CLAUDE.md`)
- every `.claude/skills/*/SKILL.md` — and every `.claude/agents/*.md` **if the directory exists** (current tiers emit none; see below)
- **the build state file, whatever it is called.** Do not assume a name — `glob` for it. Both current tiers use `PROGRESS.md` at the root, but migrated or hand-written harnesses may not. A doctor that hardcodes one name will report the other as missing.
- `.gitignore`
- the build-tool manifest (`Makefile`, `package.json`, `pyproject.toml`, `justfile`, whatever this project has) — enough to verify the commands the skills invoke actually exist

**And the two files that define what this harness was *supposed* to be:**
- **`STACK.md` → the gate manifest.** The list of gates the stack can actually run.
- **`PRD.md` → the `<!-- TIER: x -->` marker.** What size harness was called for.

Then use `bash`/`git` to check claims against reality. **A path a skill references either exists or is a declared template placeholder. There is no third option.**

## Judge against the tier and the manifest, not against a template

Before you flag a single absent gate, read the tier and the manifest. Otherwise you will produce a report that is confidently, uselessly wrong. The tier marker is `small` or `orchestrated`; a marker still reading `standard` or `full` means the harness predates the two-tier model and needs migration, not this audit — **BLOCKER**, report it and finish.

- **`small`**: one skill, `build-loop`, and no gates unless the manifest says otherwise. No orchestrator, no subagents. That is correct — reporting "join-review is missing" on a small harness is noise, and noise in a mandatory gate teaches people to skim it.
- **`orchestrated`**: tier-core skills `orchestrate-build`, `join-review`, `harness-doctor`, plus exactly the manifest's gates. Unit work is dispatched as **general-purpose subagents** — so `.claude/agents/` should not exist. Role-agent files present (scoper/implementer/reviewer leftovers from a migration) are dead machinery: check 3.
  - `PLAN.md`, when it exists, must carry a `## Dispatch units` section — epic-sized units with owned file trees, **unit U0 = the walking skeleton** (the thinnest runnable vertical slice). Section absent → **BLOCKER** (the orchestrator has nothing to dispatch). U0 not a runnable end-to-end slice → **MAJOR**. `PLAN.md` absent entirely (forge runs before backlog-author) → not a finding, but the state file must say it is awaiting `PLAN.md`.
  - The state file declares five statuses — `todo / wip / done / blocked / partial` — with `partial` first-class. `partial` missing → **MAJOR**: agents with no honest middle status round up to `done`.
- **A gate absent from the manifest must be absent from the harness.** No migration tool → no migration gate. Its absence is the design working.
- **The inverse is a BLOCKER, and it is the one check nobody else performs:** a gate present in the harness but **not** in the manifest, or present but unable to run against this stack. That gate will be skipped, faked, or rationalized past — **and the harness will report that it ran.**

So, for every gate: in the manifest? in the harness? Both, or neither. Any mismatch is a finding.

## The fourteen checks

Each is grounded in a defect class that has actually shipped in a real harness. Run all fourteen.

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
For every skill: does its `allowed-tools` (which **intersects down** once the skill loads) cover everything its procedure demands? And for any agent file that exists, does its `tools:` grant cover its skill?

- A join-review told to write `<reviews-dir>/join-<unit>.md` but granted no `Write`.
- An orchestrator skill whose `allowed-tools` omits `Skill` while its procedure invokes gates by skill name.
- A gate told to run a command but with no `Bash` in its grant.

**The orchestrated orchestrator has FULL tools — `Bash`, `Grep`, `Glob`, `Skill` — BY DESIGN.** It reads the whole design contract, runs the full check at joins, and rules on escalations; it can do none of that starved. A harness that strips those tools back off it is a **MAJOR** finding, not a hardening — the enforcement mechanism is the join protocol, not tool starvation. Distinguish *missing capability* from *intentional constraint* by reading why the file says a tool is absent.

### 2. Artifact ownership (every read has exactly one writer)
Build the full table: for every file any actor reads or writes, who writes it and who reads it.

- **Orphan read:** a skill reads a file no actor is told to write.
- **Orphan write:** a gate writes a report nobody reads.
- **Two writers on the state file:** the orchestrator claims sole ownership while a gate or unit-agent instruction also says "update the state file." **The state file's single writer is the orchestrator** — unit agents and gates return, they never write it. A second writer is a clobber waiting to happen.
- **Unnamed artifact:** a skill says `writes: [an audit report]` with no path, while another skill is told to build a pointer *into* that report. The pointer is unconstructable.

### 3. Dispatch reachability
Every component someone is told to invoke must be invocable **by that caller, with that caller's tools.**

- Gates are **skills**, and the orchestrator has `Skill` — it invokes them directly. Verify `join-review` is actually invoked at every join the orchestrator skill describes. The dispatch-a-general-purpose-agent-to-invoke-the-skill pattern is legitimate **only** for gate runs the orchestrator backgrounds in parallel; anywhere else it is a needless hop worth a MINOR.
- A skill that exists but nothing ever triggers. Dead code in the harness is **a gate you think you have and don't**, which is strictly worse than not having it. Leftover role agents (`story-scoper`, `story-implementer`, `story-reviewer`), per-story skills, `resume-build`, evidence-file or fix-story machinery are the migration-era version of this: **MAJOR** — nothing dispatches them, and an agent that stumbles on one will obey it.

*(Check the tier first. On a small-tier harness there is no orchestrator and no join — build-loop's absence of gates is not a finding.)*

### 4. Return-contract sufficiency
For every producer→consumer pair, does the producer's **declared return** contain everything the consumer's procedure requires? The consumer cannot read the producer's mind, and often does not read the producer's file either.

- The orchestrator writes each unit's state line — `done`, `partial` with what remains owed, `blocked` — from the return alone → every unit agent's return contract must carry done / partial / **could-not-verify** as named sections. A brief without a report-back format produces returns the orchestrator cannot record.
- Join-review returns findings **numbered**, self-contained, with its report filename — the reports are gitignored and vanish on a fresh clone, so load-bearing finding text must reach the tracked state file via the return.
- A gate writes `report-<unit>.md` but is dispatched twice at one join → same filename, silent overwrite, every pointer into the first report resolves to different content.

This check finds the subtlest bugs. Trace at least one full happy path end to end, naming every input at every hop.

Then check the inverse — **excess**. A return contract or dispatch instruction that carries what a named file already holds: a brief told to paste design sections instead of citing them with line ranges, a return that includes a report's contents. **MAJOR.** Nothing fails when this rots in — the orchestrator's context just stops being flat, and sessions quietly shorten. Sufficiency breaks loudly at the next hop; excess never breaks at all, which is exactly why it must be audited. (Bounded inline values the consumer cannot get from disk — a pasted finding, an ask wording — are correct, not excess.)

### 5. Doc-vs-skill contradiction
`CLAUDE.md`, the skills, and the state file's operating-facts must agree. When they disagree, the agent obeys whichever it read most recently or most literally — which is not the one you meant.

- `CLAUDE.md` says the orchestrator runs the full check at joins; a skill tells unit agents to run it per unit.
- `CLAUDE.md` says units come from `PLAN.md`'s dispatch-units table; the orchestrator skill says to derive them itself.
- The state file's operating-facts name a commit format the orchestrator skill contradicts.
- `CLAUDE.md` opens with an organising principle a skill's rule quietly violates.

**Report which file wins.** A harness must declare an authority (usually the orchestrator skill). If it doesn't, that itself is a finding.

### 6. Path and command validity
Every path, every command, every filename. Check them against the repo.

- Docs claimed to be in `/docs` that are actually at the repo root.
- A migrations directory named that doesn't exist.
- A `make` target or `npm` script a skill invokes that isn't defined.
- The reviews directory agents are told to write into but which isn't gitignored, so reports get committed. Verify with `git check-ignore -v`.

### 7. Loop termination
Every loop in the harness must be bounded, and every stop condition must be reachable.

- **The join-review fix loop: two rounds, then the unit is `blocked`.** "Repeat until the review passes" with no cap — a fix that passes its own reasoning but not the review loops forever.
- A stop signal that can never fire (e.g. "hand off on the third round" when the cap already blocks at two).
- A stop condition list that says "one item, on purpose" and then refers to "one of the two signals above." Plural invites the agent to hunt for a signal that isn't there.

### 8. Early-stop residue
Anything that lets an agent stop before its work is done. **Grep for it explicitly**, because it hides.

Unit caps, session caps, "~N units", "natural stopping point", "this seems like a good place to pause", "a reasonable amount of work". Every one of these is a self-imposed limit the model will happily honor, and each costs a full resume cycle. The harness declares **a single stop signal — the context system-reminder**; verify no file anywhere offers a second.

### 9. Ordering constraints
Where a harness declares an order, verify it is stated identically everywhere and that violating it is actually prevented.

- Any step that rewrites the design to match what was built (a docs-sync, a design amendment pass) **must** run after any review that judges the code *against* that design. Run it first and the review becomes tautological.
- A join recorded green before its units drained is recording a state that never existed.
- The same order restated in `CLAUDE.md` and the orchestrator skill must be the *same* order. A hard rule with the stale order is the copy an agent obeys under pressure.

### 10. Cross-cutting invariants
Whatever the harness claims about itself, verify mechanically:
- If it claims single-writer on a file, check for a second writer.
- If it claims a gate is mandatory, check it has an invoker and a failure path.
- **Escalations have a ruler.** The harness must tell unit agents to stop-and-report on contradictions AND tell the orchestrator to rule with a citation and write the ruling into the design as a dated amendment. Agents told to escalate to an orchestrator never told to rule → **MAJOR** (every escalation becomes a stall or a silent improvisation).
- **Join-review dispatches carry an explicit model** — the templates name `opus` as a literal on the dispatch. A join-review dispatch with no model inherits the session's, and the one independent-judgment boundary left is unguaranteed. **MAJOR.**
- **Parallelism: check the policy against the isolation that actually exists — in both directions.**
  - Harness says **serial / one-at-a-time**, but `scaffold` built per-worker isolation → **MAJOR.** Invisible forever: a slow build looks exactly like a careful one.
  - Harness permits **concurrent unit agents**, but there is no per-worker DB isolation and units touch the DB → **BLOCKER.** Concurrent suites corrupt each other and produce flaky verdicts.
  - The DB-parallel rule resolved to something vague, or paraphrased rather than one of the canonical sentences → **MAJOR.** An agent reading a hedge takes the permissive reading.
  - Concurrency is keyed on **file-tree disjointness**, so the dispatch units must declare owned trees. Units in `PLAN.md`'s table without file trees, while the orchestrator gates co-dispatch on disjointness → **BLOCKER** — it will either serialize everything or guess.
  - A concurrency policy but **no instruction to dispatch unit agents in the background** → **BLOCKER.** Synchronous dispatch blocks until return, so "up to N concurrent" runs one-at-a-time while every file still reads as parallel. Grep for the background-dispatch instruction; its absence is the finding.
  - A join described **without a drain precondition** (no unit left `wip`) → **MAJOR.** The dangerous direction is a false GREEN closing a join on unfinished work.
  - Anything treats a **dispatch as a completion** — marking a unit `done` from a launch rather than a return → **BLOCKER.** Under background dispatch that records outcomes that never happened.

### 11. Gate manifest fidelity (the check nobody else performs)
Cross-check `STACK.md`'s gate manifest against the gates actually in `.claude/skills/`.

**The manifest is already tier-adjusted** — its tier columns are `small` and `orchestrated`, and each row is `yes` or `no`. So you compare against the manifest, **not** against some ideal gate set. Do not second-guess a `no`.

| Manifest says | Harness has | Verdict |
|---|---|---|
| yes | yes | correct |
| no | no | correct — including a small-tier harness with **no gates at all** |
| yes | **no** | **BLOCKER** — a gate the project needs was never emitted |
| **no** | yes | **BLOCKER** — a gate that cannot run against this stack. It will be skipped, faked, or rationalized past, **and the harness will report that it ran.** |
| **DEFERRED** | either | **BLOCKER** — `harness-forge` was supposed to resolve this row and write it back. An unresolved row means a gate nobody ever decided. |
| **`inline`**, or columns for `standard`/`full` | anything | **BLOCKER** — the manifest predates the two-tier model. A stale manifest makes this whole check pass vacuously: the harness is gateless (or wrongly gated) while the audit reports CLEAN. Re-run `stack-decide` in RE-TIER mode (KD-015). |

Also verify each present gate's commands actually exist (the `make` target, the `npm` script). A gate invoking a command that isn't defined is a gate that fails on first use and then gets quietly disabled by whoever hits it.

### 12. The notification channel reaches somebody

The harness tells its agents to push a blocker to the user's phone. If that path is broken, the failure is **silent in both directions**: the agent runs a command that isn't there, the script it expected exits 0 by design, and the user is never told the build stopped. Everything reports fine. Nobody is coming.

| | |
|---|---|
| `.claude/scripts/notify.sh` exists and is **executable** | missing or non-executable → **BLOCKER** |
| Every path any harness file names for it resolves to that same file | mismatch → **BLOCKER** (the agent runs nothing) |
| `.claude/ASK_CONTRACT.md` exists | missing → **MAJOR** — the pushes will send, and they will be unanswerable |
| `.gitignore` covers `.env` / `*.env` | missing → **MAJOR** |
| Every actor instructed to call it has `Bash` in its grant | missing → **BLOCKER** (this is check 1, applied here) |
| The **orchestrator** calls the script **directly** — it has `Bash` | told to dispatch a notify-only relay task instead → **MAJOR** — stale machinery from the retired tiers; it still works, but it spends a dispatch on a one-line command and teaches the wrong tool model |
| No `Notification` hook in the target repo's `.claude/settings.json` | present → **MINOR** — it double-fires against the user's global hook, and a channel that cries wolf gets muted |

**Do not run `notify.sh selftest`.** It sends a real push. You are auditing, and nobody asked to be buzzed.

Skip this check entirely if the harness genuinely has no notification channel — but say so in the report as a MINOR, with the consequence stated: this build cannot tell anyone it stopped.

### 13. Gate placement — full suites at joins only

The single largest time sink in the retired per-story harness was full-suite runs inside the story loop: each re-proved things that could not have changed, and the total ran to hours. The current design is two-level by contract: **unit agents verify with narrow, scoped commands; the orchestrator runs the full check command at join points.**

Grep every generated file for instructions that put the full check command (or a full regression run) inside per-story or per-unit work — "run the full suite before reporting", "each story ends with `<check command>`", a brief template baking the full command into the unit loop. Any such instruction → **MAJOR**, citing the file and line. The inverse — **nobody** runs the full check at joins, or joins are never defined → **BLOCKER**: scoped checks alone never see cross-unit breakage, which is exactly where assembled products fail while every unit reports green.

(`small` tier is exempt in one direction only: build-loop runs the full check per story by design — there are no joins. The BLOCKER direction still applies: something must run it.)

## Output

Write full detail to **`HARNESS_DOCTOR.md`** at the repo root. **Number every finding** — the caller (`harness-forge`, `harness-migrate`, or a human) fixes by number, and never reads your report unless something is wrong.

Per finding: `#N`, severity, the **two or more files that disagree** (with `file:line` quotes for each), the concrete failure it produces at runtime, and the fix. Severity:

| | |
|---|---|
| **BLOCKER** | The harness will fail or silently skip a gate on the next run. **Unresolved placeholder**, missing tool, unreachable dispatch, orphan read, unbounded loop, stale manifest. |
| **MAJOR** | Contradiction that will cause an agent to do the wrong thing under pressure. Doc-vs-skill conflict, dead machinery, early-stop residue, per-unit full-suite runs. |
| **MINOR** | Stale reference, wrong path, cosmetic drift. Wrong today, load-bearing later. |

**Return a capped summary (~150 words):** counts by severity, the report filename, and one numbered line per BLOCKER and MAJOR. Nothing else. Do not paste the report.

## Guardrails

- **Report only. Never edit a skill, an agent, `CLAUDE.md`, or the state file.** Someone else fixes; you diagnose. A doctor that patches its own findings cannot be trusted about the next set.
- **Verify against the repo, not the prose.** A skill asserting a file exists is not evidence. `ls` is.
- **Do not fail a deliberate design choice.** The orchestrator's full tool set is the design working, not a privilege escalation. Read *why* before you flag.
- **Trace, don't skim.** Most real defects live in check 4 (return contracts) and check 2 (artifact ownership), and neither is visible by reading files one at a time. Build the tables. Walk one full happy path, hop by hop, naming every input.
- **Expect to find things.** A hand-written harness of a dozen skills routinely carries a handful of blockers. Returning "clean" on a harness that has never been doctored means you skimmed.

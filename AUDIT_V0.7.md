# AUDIT_V0.7: project-setup-kit v0.6.1

Audit date: 2026-10-24. Auditor: Claude Fable 5.1, unattended, branch `audit-v0.7`. Test project: "Dues" (cycling-club treasurer app) at `/Users/santiago/Projects/psk-v07-testbed/dues`, logs in `/Users/santiago/Projects/psk-v07-testbed/logs/`.

## The one screen

**Verdict per goal**

| Goal | Verdict | One line |
|---|---|---|
| 1. Fast | **Fails** | Setup for a 25-story project took 133 minutes of wall-clock and about $71 of model time at list price, with the full test suite run about 31 times on a scaffold that had almost no tests. Most of the time went to the harness-generation and doctor loop, not to thinking about the product. |
| 2. Manages context well | **Partly** | Dispatch prompts are small (2 to 4k chars, pointers only) and the state file survived three interruptions. But the chain cannot find its own files (4 minutes of disk search), compaction silently drops the design, the orchestrator cannot tell a dead unit from a slow one (it waited an hour for a unit that had been killed), and the generated CLAUDE.md is twice the size it needs to be for the agents that read it most. |
| 3. Generates exactly the tools the project needs | **Mostly works** | The gate manifest was derived from the stack correctly (migration review yes, dependency audit yes, five gates no). Two gates are over-included by default, and a resident doctor nobody dispatches is emitted. |
| 4. Good functional and technical design | **Works, with one blocker** | PRD.md and DESIGN.md are strong (literal, citable, zero hedges, honest open register). The blocker: the interview skills cannot ask the user when dispatched the way the kit requires, so in a real run the interview never happens. |

**The five findings that matter most**

1. **F1 BLOCKER.** The interview steps (project-brief, stack-decide, design-author) are dispatched as subagents, and subagents cannot ask the user anything: Claude Code removes the question tool from every subagent. The kit's whole front half rests on asking. It worked in this test only because I pre-wrote the owner's answers in a file.
2. **F2 MAJOR.** The setup chain is slow and expensive for the wrong reasons. Steps 4 and 5 (scaffold, harness-forge) ran the full test suite 18 times and dispatched the doctor 4 times. One doctor round was spent on a bookkeeping blocker (a table row in STACK.md still said DEFERRED). Harness generation is mostly copying templates and filling blanks, which a script can do in a second.
3. **F3 MAJOR.** Skills tell the agent to read files "at the plugin root" but nothing tells it where that is. The orchestrator searched the whole disk for 4 minutes before writing its first line.
4. **F5 MAJOR.** The orchestrator template assumes the design stays in memory across compaction. Claude Code's compaction brings back files over 5,000 tokens as a path only. DESIGN.md is about 13,600 tokens. After the first compaction the orchestrator writes briefs from a summary, which the template itself forbids.
5. **F17 MAJOR.** The build loop dispatches every unit in the background and then ends its turn to wait. In an unattended run Claude Code stops background agents 10 minutes after the turn ends. The skeleton unit was killed with 56 tests passing and nothing committed; the orchestrator checked twice over the next hour, saw files on disk, and concluded "still running". A lone unit should be dispatched synchronously, and a unit should commit after every story that goes green.

**What to do first**

Run `V0.7_CHANGES_PROMPT.md`. It fixes the blocker (interview in the main session), cuts the chain (scripted forge, one doctor pass, capped check runs), makes the plugin root findable, and makes the orchestrator survive compaction and new sessions. Everything else is minor.

---

## Findings

Severity: BLOCKER = the kit does not do what it says; MAJOR = measurable cost or a real failure path; MINOR = cleanup.

| ID | Goal | Severity | What is wrong | Evidence | Recommended change | Expected effect |
|---|---|---|---|---|---|---|
| F1 | 4, 1 | BLOCKER | The interview skills are run as subagents, and a subagent cannot ask the user. project-brief's "grill" pass and design-author's "stop and ask before writing" never happen in a real run; the skill guesses or marks BLOCKING instead. | `skills/setup-project/SKILL.md:88` (every step dispatched, no exception); `skills/project-brief/SKILL.md:46` (AskUserQuestion), `:66-74` (grill); `skills/design-author/SKILL.md:51-63`; `skills/stack-decide/SKILL.md:87`; `skills/backlog-author/SKILL.md:52`. Docs: subagents page, "The first filter removes these tools, even when listed: ... AskUserQuestion" (https://code.claude.com/docs/en/sub-agents). In this test the subagent read `OWNER_BRIEF.md` instead, which masked the defect. | Run project-brief, stack-decide and the question pass of design-author in the main session. Dispatch only the generator and checker steps (scaffold, harness-forge, backlog-author, plan-lint, doctor). Rewrite KD-014 (see F4). | Interview restored. Three fewer fresh subagent contexts of about 35k tokens each. |
| F2 | 1 | MAJOR | The chain is slow for mechanical reasons. The whole chain took 133 min and $71.35. Scaffold ran the check 8 times, harness-forge 10 times, backlog-author and plan-lint (which write only Markdown) 5 times between them, and the doctor and orchestrator the rest: about 31 full-suite runs in total. The doctor ran 5 rounds, one of them for a bookkeeping blocker (STACK.md row still said DEFERRED after perf-profiling was emitted). harness-forge reached 229k tokens of context in one subagent; backlog-author and plan-lint reached 175k each. Step 8 dispatched a subagent to seed PROGRESS.md and the kit's own write guard blocked it, so the orchestrator did it again itself. | `logs/setup*.stream.jsonl` (table below); `dues/SETUP_PROGRESS.md:18-21`; `HARNESS_DOCTOR.md` round 3 finding #1; `skills/stack-decide` DEFERRED protocol; `skills/harness-forge/SKILL.md` (model copies templates by hand); `skills/harness-doctor/SKILL.md` check 11 rates the manifest mismatch BLOCKER. | (a) Make harness-forge a script: `scripts/forge.sh` copies the tier's MANIFEST files, fills `{{PLACEHOLDERS}}` from a small JSON the model writes, and collapses blank lines. The model's job shrinks to writing the JSON and the project-specific sections. (b) Doctor runs once after forge; its BLOCKER class is reserved for things that break a build (unresolved placeholder, missing hook, two writers); manifest bookkeeping is MINOR and fixed by the orchestrator in place without a re-dispatch. (c) Cap check runs in scaffold at two (green once, red once). (d) harness-forge resolves DEFERRED rows by editing STACK.md in the same step. | Steps 4-5 from about 50 min to under 10. No new test runs. |
| F3 | 2, 1 | MAJOR | Skills say "read COMMUNICATION.md at the plugin root" and "read templates/PLACEHOLDERS.md" but neither the skill text nor the environment says where the root is. The orchestrator ran a breadth-first search of `/`, hit the 120 s Bash timeout, probed `~/.claude` four more times, and spent about 4 minutes and 20k tokens before step 0. Each step then re-read COMMUNICATION.md and ASK_CONTRACT.md. | `skills/setup-project/SKILL.md:110`; `skills/project-brief/SKILL.md:48`; `skills/design-author/SKILL.md:256`; `skills/harness-forge/SKILL.md:38`; `README.md:99` (CLAUDE_PLUGIN_ROOT not set for skill Bash); `logs/setup.stream.jsonl` MAIN turns 1-6. | The plugin's SessionStart hook (`hooks/sync-notify.sh` already runs with `CLAUDE_PLUGIN_ROOT`) writes the path to `~/.claude/project-setup-kit.root`; every skill reads that file first. Stop telling skills to read COMMUNICATION.md: fold the eight rules into setup-project in one line each. | About 4 min and 20k tokens off every chain start; two file reads off every step. |
| F4 | 2 | MAJOR | KD-014's mechanism does not exist. A skill's `allowed-tools` pre-approves tools; it never restricts them. The stated reason for dispatching every step ("scaffold could not run the check command") is false, and doctor check 1 audits a failure that cannot happen. | `KIT_DESIGN.md:74-79`; `skills/setup-project/SKILL.md:92`; `skills/harness-forge/SKILL.md:132`; `skills/harness-doctor/SKILL.md:76`. Docs: "It does not restrict which tools are available: every tool remains callable" (https://code.claude.com/docs/en/skills). Observed: the orchestrator ran Bash on its first two turns. | Rewrite KD-014 and the three passages. Where a restriction is wanted, use `disallowed-tools`. Doctor check 1 becomes "does this skill need a tool the dispatched session lacks" (AskUserQuestion, the reduced background tool set). | Honest design record; enables F1. |
| F5 | 2 | MAJOR | The orchestrator template assumes the design read survives compaction. It does not: after compaction, files over 5,000 tokens come back as a path only, and at most five files are re-read. DESIGN.md is 10,220 words, about 13,600 tokens. The orchestrator then writes briefs from a summary, which rule 1 of the same skill forbids. | `templates/orchestrated/skills/orchestrate-build/SKILL.md.tmpl:34, :38, :145`; generated `dues/.claude/skills/orchestrate-build/SKILL.md:38`. Docs: context-window page, compaction section (https://code.claude.com/docs/en/context-window). | Read §1, §2.1, §5 invariants, §10, §11 once; read the unit's cited sections just before each brief. Add a "Compact Instructions" section to the generated CLAUDE.md naming what the summary must keep (NEXT ACTION, in-flight unit IDs and task IDs, rulings this session). | No new test runs. Orchestrator context per brief drops from the whole design to the cited sections. |
| F6 | 2 | MAJOR | A unit marked `wip` carries no dispatch identity. A new or compacted orchestrator cannot tell a running unit from a dead one, so it either re-dispatches onto a tree another agent is editing or waits forever. | `templates/orchestrated/STATE_FILE.md.tmpl` unit rows; `orchestrate-build.tmpl:33-38`. Docs: background subagents run across compaction; a new session cannot see them. | `wip` rows record dispatch time and agent task ID. Session-start rule: a `wip` row with no return is re-verified with `git log` on its tree and re-dispatched as "finish what is there", never assumed done. | Prevents double dispatch; one extra column. |
| F7 | 1, 2 | MAJOR | Parallel units share one working tree. One unit's half-written code breaks another's type check; `git add -A` stages a neighbour's files; the pre-commit type check was dropped in v0.6 for this reason. | `V0.6_REPORT.md:28`; `KIT_DESIGN.md` KD-020 rule 3. Docs: Agent tool `isolation: worktree`, `worktree.baseRef: "head"` (https://code.claude.com/docs/en/sub-agents). Measured on the v0.6 testbed (TypeScript, 123 packages): worktree add 0.02 s, `npm ci` 0.42 s, full check 1.44 s. | Dispatch units that have a parallel neighbour with `isolation: worktree`; set `worktree.baseRef` to `head`; the join merges unit branches (disjoint trees, trivial merges) before the one full check. Re-enable the pre-commit type check at orchestrated tier. | No new test runs. One merge and one install per parallel unit. The single-writer rule for the state file becomes mechanical. |
| F8 | 2 | MAJOR | The generated CLAUDE.md mixes audiences. Dues: 69 lines, about 2,290 tokens, loaded into every prompt of every agent. "Talking to the user" (about 370 tokens) binds only the orchestrator; the project definition of done binds only the integration unit; the invariants block (about 880 tokens) is right to be there. | `dues/CLAUDE.md:10-20, :68-69`; `templates/orchestrated/CLAUDE.md.tmpl`; haiku probe: empty dir 32,806 tokens, Dues repo 37,204 (harness adds about 4,400 per prompt). Docs: "Bloated CLAUDE.md files cause Claude to ignore your actual instructions" (https://code.claude.com/docs/en/best-practices). Gloaguen et al.: context files raise steps 2.45-3.92 and cost 20-23% (https://arxiv.org/abs/2602.11988). | Move "Talking to the user" into orchestrate-build and build-loop (they load that skill at session start anyway). Keep the DoD in the integration unit's brief. Drop rationale sentences. Amend KD-021/022 by one line. | About 500 tokens off every prompt for every unit agent and every join-review turn. |
| F9 | 3, 1 | MAJOR | Two gates are over-included. `dependency-security-audit` is copied by default for any project with a lockfile and runs unconditionally every 4th join as a subagent; `npm audit` is a one-line Bash command the orchestrator can run itself when the lockfile changed. The DEFERRED protocol for `perf-profiling` creates a doctor BLOCKER unless STACK.md is edited again. | `dues/STACK.md:139-142`; `dues/.claude/skills/orchestrate-build/SKILL.md:85-86`; `templates/gates/dependency-security-audit/SKILL.md.tmpl:30-36`; `HARNESS_DOCTOR.md` #1. | Replace the dependency gate with one Bash line in the join (run only when the lockfile changed). stack-decide decides perf-profiling yes/no itself from the PRD's loop; no DEFERRED state. | One fewer dispatch every 4th join; one fewer doctor round at setup. |
| F10 | 1 | MINOR | Mutation testing at every join adds 2-3 test-suite runs per join. | `orchestrate-build.tmpl:79`; `dues/.claude/skills/orchestrate-build/SKILL.md:79`. | Mutation-test only the invariants the join's diff touched, running only the affected test files, never the full check. | Removes 2-3 full runs per join. |
| F11 | 3 | MINOR | The resident harness-doctor is emitted at orchestrated tier and never dispatched by anything. | `dues/.claude/skills/harness-doctor/SKILL.md` (103 lines, 1,776 words, 430-char description); KD-020 rule 7; `templates/small/MANIFEST.md` already omits it. | Do not emit it. The kit's doctor remains available to re-audit. | About 110 tokens off every prompt; one fewer skill. |
| F12 | 2 | MINOR | Skill descriptions are long and at risk of being dropped by the listing budget. Kit: 10 skills, 4,196 chars (about 1,050 tokens). Generated: 6 skills, 2,156 chars. The listing is capped at 1% of the context window and drops least-used descriptions first. | Measured; docs skills page, "skill listing budget". | One sentence each, trigger first. | Small, always-loaded saving. |
| F13 | 2 | MINOR | Stale references: generated skills cite HARNESS-REDESIGN.md and ORCHESTRATION.md, which are not in generated repos (or the kit). small MANIFEST says the user installs the Notification hook; the plugin ships it. build-loop says "create from the template"; there is no template in the repo. | `dues/.claude/skills/orchestrate-build/SKILL.md:24`; `join-review.tmpl:19`; `STATE_FILE.tmpl:51`; `backlog-author:112,114`; `plan-lint:76,87`; `small/MANIFEST.md:70`; `build-loop.tmpl:56`. | Delete or inline the references. | Fewer dead reads. |
| F14 | 4 | MINOR | OPEN_QUESTIONS.md has no defined format; project-brief says only "OQ-NNN". The Dues run invented a good one (id, status, question, v1 meanwhile, would touch). | `skills/project-brief/SKILL.md:139`; `dues/OPEN_QUESTIONS.md:5`. | Adopt that five-field format in the skill. | Consistency across projects. |
| F15 | 1, 3 | MINOR | stack-decide has no proportionality rule. For a 16-story local single-user app it chose Playwright in the check command, a two-pass type check and a Vite build. The check is 3 s today and grows with every end-to-end test. | `dues/STACK.md` ADR list; `dues/package.json` check script. | Add one rule: the check command at small and orchestrated tier runs in under 60 s; end-to-end tests run at joins only unless the PRD's loop is a browser flow. | Faster unit cycles. |
| F16 | 2 | MINOR | `notify.sh` reads an env file the user does not have; the generated PROGRESS.md tells the user to create one. The user's own rule keeps the keys in the macOS Keychain. | `dues/PROGRESS.md:32`; `scripts/notify.sh`; doctor #5, #6. | `notify.sh` falls back to `security find-generic-password -s pushover-claude-token -w` and `-s pushover-user-key -w` on macOS. | The notifier works out of the box on this machine. |
| F17 | 1, 2 | MAJOR | The build loop's dispatch mechanics do not survive an unattended run, and the orchestrator cannot detect a dead unit. Every unit is dispatched in the background and the orchestrator ends its turn to wait (with a 30-minute fallback wakeup). In `claude -p` mode Claude Code stops background tasks 10 minutes after the turn ends: U0 was killed at minute 12 with "All 56 pass" and 26 files written, none committed. The orchestrator woke at minutes 33 and 64, ran `git status`, saw uncommitted files and concluded "still running" both times. One hour, $4.95, zero committed work. The brief said "commit as you go"; the unit had not committed once in 12 minutes. | `logs/build1.stream.jsonl` (task_updated status killed at 741 s; orchestrator texts at 1,990 s and 3,854 s); `logs/build1.stderr` ("Background tasks still running 10m after the last turn ... stopping them"); `templates/orchestrated/skills/orchestrate-build/SKILL.md.tmpl` Dispatch mechanics (background dispatch for every unit); `dues/PROGRESS.md` U0 row `wip` with no commits. | Dispatch a unit that has no parallel neighbour synchronously: the Agent call returns with the report and no waiting logic is needed. Use background dispatch only when two or more units run together, and then collect them in the same turn (never end the turn with a unit in flight). Liveness rule: a `wip` unit whose tree has not changed in 10 minutes is dead; re-dispatch with "finish what is there" (F6). Brief rule: commit after every story whose tests pass, so a killed agent leaves its work in git. For unattended runs set `CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0` in the generated settings `env`. | No new test runs. Removes the wait-and-wake loop for most units; a dead unit costs 10 minutes instead of an hour. |
| F18 | 2 | MINOR | The orchestrator read the entire design, the whole plan and every source file before the first dispatch (132 s, context from 35k to 172k tokens) and wrote a 12,317-char brief for U0. The brief is good (line ranges, traps, report format) but it is six times the size of a setup-chain dispatch prompt, and the whole-contract read is what F5 says to stop doing. | `logs/build1.stream.jsonl` MAIN turns 1-11; brief length 12,317 chars, 59 lines. | Covered by F5 (read cited sections just in time). Add a brief budget to orchestrate-build: under 6,000 chars, pointers with line ranges, no restated design text. | Smaller orchestrator context per unit. |

---

## Measurements

### B. Setup chain on Dues (Fable 5.1 as every agent, owner brief instead of interview)

Peak context = largest single request in that subagent (input + cache read + cache creation). Test-suite runs = Bash commands matching the check or test command.

| Step | Wall (s) | Turns | Peak context (tokens) | Test-suite runs | Note |
|---|---|---|---|---|---|
| MAIN orchestrator, run 1 | 1,547 total | 29 | 60,520 | 0 | 4 min locating the plugin root (F3) |
| 1 project-brief | 179 | 7 | 46,776 | 0 | Read OWNER_BRIEF.md; PRD 147 lines, 16 stories, 3 OQs |
| 2 stack-decide | 483 | 15 | 74,922 | 0 | 4 web searches; 15 ADRs |
| 3 design-author | 636+ (cut) | - | 105,019 | 0 | DESIGN.md 871 lines, cut by usage limit, then verified in 180 s / 14 turns |
| 4 scaffold | 659 | 50 | 151,273 | 8 | |
| 5 harness-forge | 2,402 + 137 + 268 | 43 + 12 + 14 | 229,559 | 11 | 4 doctor rounds (R1-R3 nested, R4 by the orchestrator), 1 fix round |
| 6 backlog-author | 924 + 111 + 41 | 18 + 11 + 7 | 174,996 | 4 | PLAN.md 560 lines, 25 stories, 6 units; 2 fix rounds |
| 7 plan-lint | 559 + 199 + 147 (+100 design AMEND) | 20 + 20 + 13 | 175,261 | 1 | R1 0/5/11, R2 0/1/7, R3 PASS 0/0/5 |
| 8 seed + doctor | 42 + 120 | 11 + 13 | 83,312 | 2 | seed subagent blocked by the write guard; final doctor 0/0/6 |
| MAIN orchestrator, all four legs | 2,000 to 3,500 per leg | 29 + 17 + 17 + 27 | 136,908 | about 7 | |
| **Total** | **7,977 s (133 min)** | | | **about 31** | **$71.35 at list price**: Fable $65.07 (legs 1-3, steps 1 to 7 part), Opus $6.22 (leg 4, steps 7 fix loop and 8), Haiku $0.05 |

Legs: the run was cut twice by usage limits and once by me to switch model, and resumed each time with `--resume`. Steps 7 (fix loop) and 8 ran on Opus at the user's request; everything before ran on Fable. Dispatch prompts were 1,486 to 3,701 chars each, pointers only (KD-018 respected).

### B. Generated harness run (U0 + one unit)

Run on Opus (user's request), unattended via `claude -p`, owner mode. Cap: U0, join, U1 and U4, join, stop.

**Run 1** (`logs/build1.stream.jsonl`, 90 min, killed by my cap, $4.95):

| Actor | Wall (s) | Turns | Peak context (tokens) | Test-suite runs | What happened |
|---|---|---|---|---|---|
| Orchestrator, before dispatch | 132 | 11 | 172,578 | 1 (baseline check) | Read PRD, STACK, DESIGN, PLAN, all source; one design ruling (§12.3 amended); marked U0 wip; 12,317-char brief |
| U0 unit agent (background) | 741 then killed | 96 | 159,110 | 4 (typecheck, vitest) | 26 files written, 56 tests passing, 0 commits; killed by the harness 10 min after the orchestrator's turn ended |
| Orchestrator, waiting | 2 wakeups at 1,990 s and 3,854 s | 33 | | 0 | `git status` each time, concluded "still running", scheduled another 30-min wakeup |

**Run 2** (`logs/build2.stream.jsonl`, resumed session, U0 re-dispatched synchronously with "finish what is there", then join J1, then stop):

| Actor | Wall (s) | Turns | Peak context (tokens) | Test runs | What happened |
|---|---|---|---|---|---|
| U0 unit agent (synchronous, 10,751-char brief) | 515 | 47 | 156,759 | 18 (vitest subsets, typecheck) | Finished the killed draft: 4 commits, 72 Vitest tests in 11 files, typecheck and lint clean; reported what it could not verify (smoke spec unrun, screens never rendered) |
| Orchestrator, join J1 | 954 total | 51 | 214,921 | 6 (4 mutation probes on vitest subsets, 1 full check, skeleton run twice) | Recorded U0 return; mutation probes all went red and were restored; full check green; skeleton run on a temp DB with curl checks |
| join-review (opus, 2,250-char brief) | 216 | 23 | 119,738 | 2 | 8 findings: 0 blocker, 2 major, 6 minor. Major #1 CONFIRMED: duplicate-name check missed Unicode look-alikes (a real defect). 3 fixed in place by the orchestrator, 5 carried into later briefs |
| db-migration-review | 58 | 11 | 52,858 | 2 | PASS, migration matches DESIGN.md §3 statement for statement |
| Re-check after fixes | | | | 1 full check | green: 73 tests, vite build, Playwright smoke 1/1 |

Run 2: 958 s (16 min), $6.03, 3 dispatches, 2 full check runs plus the skeleton run. Both runs: 106 min and $10.98 for one finished unit and one join, of which 90 min and $4.95 produced nothing (F17).

What this shows: the join is worth its cost. One 4-minute opus review on a 4-commit unit found a confirmed defect that the unit's 72 tests did not. The dependency and perf gates correctly did not run (lockfile unchanged, perf trigger is U2). The 4 mutation probes were targeted vitest runs, not full checks, so F10 stays MINOR.

### C. Always-loaded context

| Measurement | Tokens | Method |
|---|---|---|
| Empty directory, first turn (haiku) | 32,806 | `claude -p --model haiku --output-format json`, usage sum |
| Dues repo with generated harness | 37,204 | same; delta 4,398 |
| Dues CLAUDE.md | about 2,290 | 9,156 chars / 4 |
| of which "Talking to the user" | about 370 | lines 10-20 |
| of which invariants block | about 880 | lines 36-57 |
| Generated skill descriptions (6) | about 540 | 2,156 chars |
| Kit skill descriptions (10) | about 1,050 | 4,196 chars |
| orchestrate-build body (loaded at session start) | about 4,750 | 19k chars |
| Subagent first turn (kit chain) | 23,359 to 23,461 | stream usage |
| Main session first turn with plugin | 30,180 | stream usage (earlier baseline 27,644) |

### Worktree cost (v0.6 testbed, TypeScript, 123 packages)

| Operation | Seconds |
|---|---|
| `git worktree add` | 0.02 |
| `npm ci` | 0.42 |
| full check | 1.44 |

---

## What works and should not change

- **Pointer-only dispatch prompts (KD-018).** Every brief was 2 to 3k chars and named files and sections instead of pasting them. Keep.
- **The state file as the single source of truth, one writer.** SETUP_PROGRESS.md let a usage-limit cut be resumed twice without loss. PROGRESS.md follows the same shape. Keep, add the task-ID column (F6).
- **Gate manifest derived from the stack.** The seven yes/no decisions in STACK.md were right for this project and the forge obeyed them. Keep (minus F9).
- **PRD.md and DESIGN.md quality.** Literal, citable, with CREATE TABLE statements, CHECK constraints, 14 invariants each with an enforcement point, and an open register that did not resolve the owner's reserved questions. The "decided for the owner" list is honest. Keep.
- **Enforcement layer.** Deny list, write guard, Bash guard, formatter hook, pre-commit hook, all with 2 s timeouts. The write guard blocked a subagent from writing the state file during setup, which is exactly its job. Keep; re-enable the type check once units have their own trees (F7).
- **The backlog-author and plan-lint pair.** The first lint round found 5 real MAJORs in a plan written minutes earlier from the same inputs, including a design gap (error codes a trigger can raise that the error table did not list). Two rounds later the plan passed. Keep the pair; cut its check-command runs (F2).
- **Dispatch units with owned file trees and a strict chain for shared files.** The plan named the five files more than one unit touches and ordered the units so no two of them run together. This is the right shape for the worktree change (F7).
- **The invariants block in CLAUDE.md as the only copy, cited by content.** Right place, right size.
- **Compaction-is-not-a-stop rule** in orchestrate-build. Correct; needs the F5 additions to be safe.
- **The join: full check, skeleton run, opus join-review that cites invariants by content, conditional gates.** In 16 minutes it found a confirmed defect (Unicode look-alike duplicate names) that 72 unit tests missed, fixed three findings in place, and carried the rest into later briefs with their source cited. The conditional gates correctly stayed off. Keep all of it.
- **Unit return format** ("what you could NOT verify" as a deliverable). U0 reported honestly that the screens were never rendered and the smoke test never run; the join then ran them. Keep.

## What could not be verified

- **The interactive interview.** Owner mode replaced every question. The defect (F1) is established from the docs and the skill text, not from a failed interview.
- **The BLOCKED → ask → AMEND path.** DESIGN.md came out BACKLOG CLEAR; the reserved questions were classified DEFERRABLE with v1 behaviour defined, so the stop-and-ask loop never fired.
- **Auto-compaction during a real build.** The harness run was capped at U0 plus its join and no compaction occurred. F5 rests on the documented compaction behaviour; F6 and F17 were observed directly.
- **Two units in parallel (U1 with U4), the second join, and the every-4th-join gates.** Not reached within the cap. The shared-tree problem (F7) rests on v0.6's own report and the plan's ownership table, not on an observed collision in this run.
- **The fair second test (E5)** was designed, not run: three arms on the same Dues artifacts. See below.
- **Tokens per step** are from the final result record per run; per-message output counts in the stream are partial and were not used.

## Answers to the open questions (E)

- **E1 Worktrees for parallel units:** yes, cheap, and they fix the shared-tree problem (F7).
- **E2 Compaction vs state file:** the state file survives; the design read and in-flight dispatch identities do not (F5, F6).
- **E3 Whole-contract read:** DESIGN.md is about 13,600 tokens, over the 5,000-token re-read threshold; read sections just in time (F5).
- **E4 Is the CLAUDE.md all needed:** no; about 500 of 2,290 tokens bind only the orchestrator (F8).
- **E5 Fair second test:** same repo, same PRD/STACK/DESIGN/PLAN, three arms, same model, one run each unattended to completion or a 4-hour cap: (A) orchestrated as generated; (B) small-tier build-loop on the same plan; (C) no harness, facts-only CLAUDE.md and "implement PLAN.md, run the check before each commit". Record wall-clock, tokens from the result record, dispatches, check runs; then one independent opus review of each whole diff counting CONFIRMED defects, and the PRD's loop by hand. The harness earns its cost only if (A) has fewer confirmed defects than (C) per hour.
- **E6 Is the 8-step chain over-ceremonious:** the steps are right; the cost is in how they run (F1, F2, F3). With the interview in the main session, a scripted forge and one doctor pass, the same eight steps should fit in about 30 minutes.

## Decisions made during the audit

- Owner answers were pre-written in `OWNER_BRIEF.md` so the chain could run unattended; this masks F1 and is recorded as such.
- The chain was cut twice by usage limits and once by me (to switch to Opus at the user's request), and resumed each time with `--resume`; totals are summed across the four legs. The model switch means steps 7 and 8 are Opus numbers, the rest Fable.
- The harness run was done on Opus for the same reason.
- The harness run was capped (first at U0, join, U1 and U4, join; then, after the first run produced nothing, at U0 and its join) to fit the audit; the cap is a test decision, not a kit finding.
- Severity of F2 is MAJOR, not BLOCKER, because the chain finishes; it is just slow.

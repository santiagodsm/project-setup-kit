# AUDIT_V0.7 (PARTIAL: stopped by the usage limit on 2026-10-24; resume from "Status")

## Status
- Done: read every kit file; measured always-loaded context; measured worktree cost; web research (notes below, with URLs); end-to-end chain run on the Dues test project through step 3 (design-author) before the Claude usage limit stopped it.
- Not done: steps 4 to 8 of the chain, the harness run (U0 + one unit), the final findings table and verdicts, V0.7_CHANGES_PROMPT.md.
- Test project: /Users/santiago/Projects/psk-v07-testbed/dues (OWNER_BRIEF.md, PRD.md, OPEN_QUESTIONS.md, STACK.md, SETUP_PROGRESS.md; DESIGN.md may be partial). Logs: ../logs/setup.stream.jsonl; analyzer: scratchpad/analyze_stream.py (per-dispatch wall-clock, turns, peak context). Resume the chain with `claude -p --plugin-dir <kit> --dangerously-skip-permissions "Invoke project-setup-kit:setup-project; resume from SETUP_PROGRESS.md; OWNER_BRIEF.md replaces every question"`.

## Chain measurements (Dues, Fable 5.1, unattended)
| Step | Wall | Turns | Peak context (tokens) | Notes |
|---|---|---|---|---|
| Orchestrator (setup-project) | 1,542 s total | 29 | 60,520 | 4 min lost locating the plugin root (disk-wide search hit the 120 s Bash timeout) |
| 1 project-brief | 179 s | 7 | 46,776 | PRD 147 lines, good quality; re-read kit root files |
| 2 stack-decide | 483 s | 15 | 74,922 | 15 ADRs, 4 web searches; re-read PRD/OQ/brief and kit root again |
| 3 design-author | 636 s+ (cut off) | 12+ | 105,019 | reached 105k context before the limit |
Cost through step 3: $9.81, 92k output tokens, 1.63M cached-read tokens. Subagent baseline before any work: 23.4k tokens; main session 30.2k.

# Draft sections for AUDIT_V0.7.md (settled parts; numbers from the run to be filled)

## Findings settled so far

### F1 BLOCKER (goal 4, goal 1) — The interview steps cannot ask the user when dispatched as the kit requires
- Evidence: skills/setup-project/SKILL.md:88 ("Every step is dispatched as a general-purpose subagent... There is no exception"); skills/project-brief/SKILL.md:46 ("Use AskUserQuestion with real options"); design-author:63, stack-decide:87, backlog-author:52 all ask the user. Docs: code.claude.com/docs/en/sub-agents, "The first filter removes these tools, even when listed in the tools field: ... AskUserQuestion".
- Consequence: a dispatched project-brief cannot interview; it writes a PRD from whatever the user typed first, or returns a list of questions no instruction tells setup-project to relay. The "grill" pass (project-brief:66-74) never happens. design-author's "stop and ask" before writing (line 51-63) silently becomes "guess or mark BLOCKING". The one relay that is described (BLOCKED → setup-project asks → AMEND) works because it goes through the state file.
- In the Dues run the owner brief masked this (the subagent read the file). In an interactive run the defect is live.
- Fix: run the interview skills (project-brief, stack-decide, design-author's question pass) in the main session, and dispatch only the generator/checker steps (scaffold, harness-forge, backlog-author, plan-lint, harness-doctor). Rewrite KD-014 accordingly (see F2).
- Speed/context effect: fewer dispatches (3 fewer fresh contexts of ≈35k tokens each), interview quality restored.

### F2 MAJOR (goal 2) — KD-014's mechanism does not exist: a skill's `allowed-tools` grants permission, it does not restrict
- Evidence: KIT_DESIGN.md:74-79; setup-project:92 ("a skill's allowed-tools intersects down"); harness-forge:132; harness-doctor:76. Docs (code.claude.com/docs/en/skills): "`allowed-tools`: Tools Claude can use without asking permission during the turn that invokes this skill... It does not restrict which tools are available: every tool remains callable." Observed: the Dues orchestrator ran Bash on its first two turns (stream, main session).
- Consequence: the stated reason for dispatching every step ("scaffold could not run the check command") is false. The real reason, context flatness, stands on its own. The doctor's check 1 ("tool sufficiency... intersects down") audits a non-existent failure mode in SKILL files; it is real only for `.claude/agents/*.md` `tools:` fields, which the kit no longer emits.
- Fix: rewrite KD-014 and the three skill passages to the true mechanism; if a restriction is wanted, use `disallowed-tools` (skills) or an agent file. Doctor check 1 becomes "does the skill's procedure need a tool the session may lack" (e.g. background subagents lack AskUserQuestion and have the reduced built-in set).

### F3 MAJOR (goal 2, goal 1) — Skills cannot find "the plugin root"; the orchestrator searched the whole disk
- Evidence: setup-project:110 ("COMMUNICATION.md at the plugin root"), project-brief:48, design-author:256, harness-forge:38 ("Read templates/PLACEHOLDERS.md"), README:99 (CLAUDE_PLUGIN_ROOT "not set for a skill's or subagent's Bash"). Observed: main session ran `bfs ... / -type d -name project-setup-kit*`, hit the 120 s Bash timeout, then four more probes of ~/.claude before finding the path; ≈4 minutes and ≈20k tokens before step 0 was written. The step-1 subagent then `cat`ed ASK_CONTRACT.md and COMMUNICATION.md again and grepped the whole kit for OPEN_QUESTIONS.
- Fix: the plugin's SessionStart hook (hooks/sync-notify.sh already runs with CLAUDE_PLUGIN_ROOT) writes the root path to ~/.claude/project-setup-kit.root, and every skill reads that one file; or the Skill tool's base-directory line is cited explicitly in each skill. Also stop telling skills to read COMMUNICATION.md at all: it is a kit-author rule about generated CLAUDE.md, and setup-chain messages can carry the eight rules in one line each inside setup-project.

### F4 MAJOR (goal 2) — Compaction erases the orchestrator's design reading; the template assumes it survives
- Evidence: templates/orchestrated/skills/orchestrate-build/SKILL.md.tmpl:34 (read the entire design contract once) and :38 ("the design contract stays read unless the summary lost what you need"). Docs (context-window page): after compaction Claude Code re-reads up to five recently modified files and "a file over 5,000 tokens comes back as a path reference only"; "detailed instructions from early in the conversation may be lost". A real DESIGN.md is far over 5,000 tokens (Claude Lens ≈4,400 lines; Dues: N lines ≈ N tokens).
- Consequence: after the first auto-compaction the orchestrator writes briefs from a summary, exactly the "brief written from someone else's summary" that rule 1 (line 145) forbids, and nothing tells it so.
- Fix (no new test runs): (a) stop reading the whole contract up front; read §1, §2.1, §5 invariants, §10, §11 once (small) and the unit's cited sections just before writing each brief (just-in-time, per Anthropic's context-engineering post); (b) a "Compact Instructions" section in the generated CLAUDE.md naming what to keep (NEXT ACTION, in-flight unit IDs and their agent task IDs, rulings made this session); (c) the SessionStart compact hook already points at the state file; make the state file carry, per in-flight unit, the agent task ID so a compacted orchestrator can tell "still running" from "needs re-dispatch".

### F5 MAJOR (goal 2) — In-flight background units are invisible to a resumed or compacted orchestrator
- Evidence: STATE_FILE.md.tmpl rows carry status `wip` but no dispatch identity; orchestrate-build:33-38 session start says resume from NEXT ACTION; nothing says what to do with a `wip` row whose agent may or may not still be running. Docs: background subagents keep running across compaction; a new session cannot see them.
- Consequence: a new session re-dispatches a running unit (two agents on one tree) or waits forever for a return that will never be recorded.
- Fix: the `wip` row records the dispatch time and the task ID; session start rule: a `wip` row with no return after a new session starts is re-verified (`git log` on its tree) and re-dispatched with "finish what is there", never assumed done.

### F6 MAJOR (goal 1, goal 2) — Parallel units share one working tree; use worktree isolation for units that run alongside another
- Evidence: V0.6_REPORT.md:28 (typecheck removed from orchestrated pre-commit because of the shared tree); KD-020 rule 3. Docs: `isolation: worktree` on the Agent tool; worktree subagent cannot write the main checkout (enforces the state-file single-writer rule mechanically, better than guard-writes.sh); `worktree.baseRef: "head"` needed so the unit branches from the build branch, not the default branch; each worktree needs its own dependency install.
- Measured on the v0.6 testbed (TypeScript, 123 packages): `git worktree add` 0.02 s, `npm ci` 0.42 s, full check 1.44 s. On a larger project the install is the only real cost (tens of seconds to a few minutes once per unit), far below one unit's wall-clock.
- Consequence of the current design: one unit's half-written code breaks another's `tsc --noEmit`; `git add -A` by one unit can stage another unit's files; the pre-commit typecheck had to be dropped.
- Fix: dispatch units that have a parallel neighbour with `isolation: worktree`; U0 and single-dispatch units stay in the main tree; the join step merges each unit branch (trees are disjoint by construction, so merges are trivial) before the full check. Re-enable PRECOMMIT_TYPECHECK at orchestrated. Speed budget: no new test run; one merge and one install per parallel unit.

### F7 MINOR→MAJOR? (goal 2) — Generated CLAUDE.md mixes audiences; ≈30% of it is not needed by the agents that read it most
- Evidence: forged Tally CLAUDE.md lines 10-20 (Talking to the user, 11 lines ≈350 tokens) govern messages to the user, which only the orchestrator and build-loop ever write (orchestrate-build "Reporting to the user"; unit agents return to the orchestrator). Lines 54-55 (project DoD) are orchestrator/integration-unit only. Line 40 is three lines of rationale. Docs: "only include things that apply broadly... Bloated CLAUDE.md files cause Claude to ignore your actual instructions" (best-practices). Gloaguen et al.: context files cost 20-23% more steps and agents follow them.
- Fix: move "Talking to the user" into orchestrate-build/build-loop (the only actors it binds; they load that skill at session start so it is in context anyway), drop the rationale sentences, keep DoD in the integration unit's brief. Saves ≈450 of ≈1,100 tokens per prompt for every unit agent and every join-review turn. KD-021/022 need a one-line amendment.

### F8 MINOR (goal 3) — The resident harness-doctor skill is dead weight after setup
- Evidence: templates/orchestrated/skills/harness-doctor: 103 lines, 1,779 words; description 429 chars loaded on every turn of every agent in the repo. KD-020 rule 7: "the doctor and red-probes run at setup only". small MANIFEST already omits it ("a three-file harness does not need a resident type-checker"). Nothing in orchestrate-build invokes it.
- Fix: do not emit it; the kit's doctor remains available to re-audit. Saves ≈110 tokens per prompt and a skill nobody dispatches.

### F9 MINOR (goal 2) — Skill listing budget risk
- Docs: the skill listing is capped at 1% of the context window and drops descriptions of least-used skills first. Kit descriptions: 4,196 chars ≈1,050 tokens (10 skills); generated orchestrated: 1,441 chars ≈360 tokens. On a machine with many plugins (this one lists ~60 skills) the kit's descriptions may be dropped. Names stay, so Skill-by-name invocation still works; natural-language triggering ("new project") may not. Fix: shorten descriptions to one sentence each (project-brief already 329 chars); keep "Use when..." triggers first.

### F10 MINOR — stale references and leftovers
- orchestrate-build.tmpl:24, join-review.tmpl:19, STATE_FILE.tmpl:51, harness-doctor.tmpl:39 cite HARNESS-REDESIGN.md / ORCHESTRATION.md, which do not exist in generated repos. backlog-author:112,114 and plan-lint:76,87 cite ORCHESTRATION.md (not in the kit either).
- small/MANIFEST.md:70 says the user installs the Notification hook in ~/.claude/settings.json; the plugin ships it (hooks/hooks.json).
- build-loop.tmpl:56 "create it from the template" — no template is in the generated repo.
- .claude/ASK_CONTRACT.md (copied) names scripts/notify.sh and OPEN_QUESTIONS.md (kit paths).
- Forged CLAUDE.md keeps blank-line runs where {{#IF}} blocks were removed (lines 33-34, 42-44) despite harness-forge:49 "collapse runs of blank lines".

## E. Known open questions (draft answers)
E1 worktrees → F6. E2 compaction → F4, F5. E3 contract size → F4 (+ Dues numbers). E4 CLAUDE.md → F7. E5 fair second test → section below. E6 chain speed → numbers from run + F1/F3.

### E5. A fair second test for the orchestrated tier
The one comparison (HARNESS-REDESIGN §1) compared two different products of the same design built by different people on different days, with the fast build hand-run. A fair test: same repo, same PRD/STACK/DESIGN/PLAN (the Dues artifacts), three arms, same model, each run once unattended to completion or a 4-hour cap: (A) orchestrated harness as generated; (B) small-tier build-loop on the same plan; (C) no harness: CLAUDE.md with facts only and the prompt "implement PLAN.md, run `npm run check` before each commit". Record wall-clock, total tokens from `claude -p --output-format json`, dispatches, test-suite runs (count `npm run check` in the stream), and then run one independent review (join-review skill, opus, over the whole diff) on each result and count CONFIRMED defects; also run the PRD's loop by hand (seeded 40 members, 6 payments in 2 minutes). The harness earns its cost only if (A) has fewer confirmed defects than (C) per hour of wall-clock. Cost: three builds of a 16-story project.

# Working findings log
# Findings log (working notes; audit branch audit-v0.7)

## Measurements so far
- Baseline `claude -p` (haiku, "say ok") in empty dir: 27,644 tokens total input (cache create + read). Includes the user's global ~/.claude/CLAUDE.md and system prompt.
- v0.6 forged-orchestrated repo: 30,097 → generated harness adds ≈ 2,450 tokens per prompt (CLAUDE.md 55 lines / 776 words ≈ 1,000-1,200 tok; 4 skill descriptions 1,441 chars ≈ 360 tok; settings/hooks).
- v0.6 forged-small repo: 29,461 → ≈ 1,800 tokens.
- Kit plugin loaded (--plugin-dir): 33,903 (first probe) → kit adds ≈ 6,000 tokens?? second probe 28,828; unstable cache accounting. Text measure: 10 skill descriptions 4,196 chars ≈ 1,049 tokens; plus command.
- Kit skill bodies (tokens ≈ words×1.33): setup-project 3,271; project-brief 2,359; stack-decide 2,387; design-author 4,681; scaffold 1,311; harness-forge 4,269; backlog-author 2,715; plan-lint 2,521; harness-doctor 5,749; harness-migrate 2,202.
- Generated orchestrate-build body 2,612 words ≈ 3,473 tok; join-review 1,129; resident harness-doctor 2,366; dependency-security-audit 626.
- Talking-to-the-user block in generated CLAUDE.md: 13 lines, 260 words ≈ 350 tok.
- Worktree cost on toy TS project (123 packages, 58 MB node_modules): `git worktree add` 0.02 s; `npm ci` 0.42 s warm cache; `npm run check` 1.44 s.
- HARNESS-REDESIGN §1: Claude Lens design was ~4,400 lines ≈ 50-60k tokens if read whole (KD-019 step 2).

## Observations from the live run (Dues)
- setup-project orchestrator used Bash immediately (stream lines 2-3: "List project dir", "Locate the project-setup-kit plugin skill files") although skills/setup-project/SKILL.md allowed-tools has no Bash. Docs: skill allowed-tools is a permission grant, not a restriction. KD-014 premise ("allowed-tools intersects down") is false → the no-Bash design is prose-only.
- The orchestrator spent its first turns locating the plugin's skill files on disk rather than invoking skills (the Skill tool was invoked for setup-project; the skill text tells it to dispatch).

## Candidate findings (to be confirmed/evidenced)
F-A KD-014 tool-intersection premise is false (docs + observed). Severity MAJOR (design rationale wrong; KIT_DESIGN, setup-project, harness-forge contract 1, harness-doctor check 1 all assert it). Effect: none on speed; fix rationale, use agents (`tools:`) if restriction is really wanted, or drop the claim.
F-B Compaction loses the design contract: docs say files >5,000 tokens are not re-read; KD-019 "read whole contract once" vanishes at compaction; template says "design stays read unless summary lost it" — optimistic. Mitigation: Compact Instructions section in CLAUDE.md; state file carries per-unit "sections to cite"; orchestrator re-reads only cited sections per brief (just-in-time).
F-C KD-019 whole-contract read crowds orchestrator context (Claude Lens 4,400 lines ≈ 50k+ tokens of 200k; plus 30k baseline). Measure Dues DESIGN.md size.
F-D Parallel units share one working tree → worktrees recommended? Measured cost tiny on toy; docs: baseRef default branch (must set worktree.baseRef head), fresh install per worktree, main-checkout writes blocked (enforces single-writer for free), typecheck in pre-commit becomes possible at orchestrated.
F-E CLAUDE.md audiences mixed: Talking-to-the-user (13 lines) is for actors that talk to the user only (orchestrator / build-loop), DoD orchestrator-only; unit agents and join-review carry it every turn.
F-F Skill description budget: 1% of context (≈2,000 tokens at 200k) shared across ALL skills on the machine; kit's 10 descriptions ≈ 1,049 tokens; generated 4 ≈ 360. Risk of drop; names kept so Skill invocation works.
F-G Background subagents have "a smaller built-in tool set" (docs) → need to check which tools; orchestrated tier dispatches units in background.
F-H harness-forge step 5 says copy templates/<tier>/** except MANIFEST.md; small MANIFEST contradicts "No Notification hook ... installs one globally in ~/.claude/settings.json" (stale vs plugin hooks.json) MINOR.
F-I build-loop step 1 "create it from the template" — no template shipped (known MINOR from v0.6).
F-J ASK_CONTRACT.md copied into project names scripts/notify.sh and OPEN_QUESTIONS.md (known MINOR).
F-K Skills cite HARNESS-REDESIGN.md / ORCHESTRATION.md which don't exist in generated repos (orchestrate-build line 24, join-review line 19, STATE_FILE line 51, harness-doctor tmpl line 39, backlog-author/plan-lint cite ORCHESTRATION.md) MINOR.
F-L Pre-commit lint fails open on timeout but typecheck "bounded 5" - fine. Note `bounded` kills at 143 only; fine.
F-M dependency-security-audit "every 4th join" — orchestrator must count; Build metrics table has Joins count; ok.
F-N Generated harness-doctor (resident) at orchestrated: 103 lines/1,779 words loaded on demand only; description 429 chars always loaded. Is a resident doctor needed? Kit doctor exists. MINOR candidate for removal (small tier already omits it).
F-O setup-project chain: each of 8 steps is a fresh subagent that re-reads PRD/STACK/DESIGN → measure from run.

## Confirmed from docs (WebFetch 2026-10-24)
- skills page: "`allowed-tools`: Tools Claude can use without asking permission during the turn that invokes this skill. The grant clears when you send your next message." and "It does not restrict which tools are available: every tool remains callable". `disallowed-tools` DOES remove tools while the skill is active.
- sub-agents page: "The first filter removes these tools, even when listed in the `tools` field: ... `AskUserQuestion`" → NO subagent can ask the user. Background subagents keep only: Read, Grep, Glob, LSP, Bash, PowerShell, Edit, Write, NotebookEdit, WebFetch, WebSearch, TodoWrite, Skill, ToolSearch, EnterWorktree, ExitWorktree, Monitor, TaskStop, SendMessage, Artifact (+SubagentHandback); Agent/ExitPlanMode conditional.
- sub-agents: `tools`/`disallowedTools` in AGENT frontmatter do restrict. Subagents load CLAUDE.md hierarchy (except Explore/Plan or omitClaudeMd). `isolation: worktree` branches from DEFAULT branch by default; commands resolving to main checkout fail.
- "Main conversation compaction: when the main conversation compacts, subagent transcripts are unaffected."

## BLOCKER candidate F-P: the interview cannot happen inside a dispatched subagent
- setup-project mandates every step be a general-purpose subagent (KD-014). project-brief, stack-decide, design-author, backlog-author list AskUserQuestion and are written as interviews ("interview, in batches. Use AskUserQuestion"). Docs: AskUserQuestion is removed from every subagent. So dispatched as designed, step 1 cannot interview; it either returns questions for setup-project to relay (not described for step 1; only for the BLOCKED stop) or guesses.
- Observed: in the Dues run the orchestrator DID dispatch step 1 as a synchronous Agent (the stream-json interleaves subagent events; the Skill call was inside the subagent). With OWNER_BRIEF.md replacing the interview the AskUserQuestion defect was masked; it would bite in a real interactive run.
- Fix direction: the interview steps (1, 2, and design-author's gap-finding questions) run in the main session (the orchestrator loads the skill; `disallowed-tools` can scope tools if wanted), the generator/checker steps (scaffold, forge, backlog, lint, doctor) dispatch. Or: setup-project becomes a thin command and the chain runs inline with each skill using `context: fork` only where no user interaction is needed.

## MAJOR candidate F-Q: "the plugin root" is unresolvable from a skill
- Skills say "COMMUNICATION.md at the plugin root", "templates/PLACEHOLDERS.md", "scripts/notify.sh at the plugin root" without a path; README admits CLAUDE_PLUGIN_ROOT is not set for a skill's Bash. Observed: the orchestrator ran `bfs ... / -type d -name project-setup-kit*` over the whole filesystem; it hit the 120 s Bash timeout and was backgrounded; then four more Bash probes of ~/.claude/plugins and ~/.claude.json (stream lines 20-80) before finding the path. ≈3.5 minutes and several thousand tokens lost before step 1 began.
- Also: the orchestrator `cat`ed COMMUNICATION.md and ASK_CONTRACT.md into its own context (≈1,500 tok) because setup-project says 'follow COMMUNICATION.md at the plugin root'. The step-1 subagent then did the same (cat ASK_CONTRACT, COMMUNICATION, grep OPEN_QUESTIONS across the kit). Every step re-pays this.
- Fix: Claude Code prints the skill's base directory when it loads? (check) — otherwise skills must derive the root from the Skill tool's output or the plugin must write its root into a known place (SessionStart hook writes ~/.claude/project-setup-kit.root, like sync-notify.sh already does for notify.sh).

## More measurements (Dues run, stream-json)
- Main session first-turn context: 30,180 tokens (system prompt + user global CLAUDE.md + kit skill descriptions). Dispatched subagent first-turn context: 23,359 / 23,461 tokens (subagent system prompt is smaller) + the dispatch prompt (~2,000 chars ≈ 500 tok).
- MAIN reached 56.5k context after step 0 (plugin hunt + cat of COMMUNICATION/ASK_CONTRACT + skill body ≈3.3k).
- Step 1 (project-brief): 179 s wall, 7 turns, peak ctx 46.8k; tools: Read brief, Bash ls, Skill, 3× Bash reading kit root (COMMUNICATION, ASK_CONTRACT, grep OPEN_QUESTIONS format, sed skill files), Bash heredoc write PRD. PRD.md 147 lines / 2,654 words; OPEN_QUESTIONS.md 41 lines. Quality: concrete timed loop, 11 non-goals, 13-term vocabulary with rejected synonyms, 7 flagged owner decisions, least-sure item named (family membership). Tier: orchestrated at 16 stories (borderline; PRD says so itself).
- Step 2 (stack-decide): 175+ s, 9+ turns, peak ctx 61.8k; cat PRD/OQ/SETUP_PROGRESS/OWNER_BRIEF + kit root again; node/npm/sqlite checks; 4 WebSearch + 1 WebFetch (version research, good); npm view probes.
- Skill tool: the Skill call returns "Execute skill: <name>" / "Launching skill"; the skill body is injected WITHOUT its directory path (grep for the path in the first records: none). So "at the plugin root" is unresolvable → F3 confirmed.
- OPEN_QUESTIONS.md has no defined format anywhere in the kit (project-brief:139 says "Route every undecided item to OPEN_QUESTIONS.md as OQ-NNN"; design-author/stack-decide read it). The step-1 agent spent two Bash calls grepping the kit for a format. → finding: orphan-format artifact (MINOR, goal 4).

## Goal 3 / goal 1 candidates from the templates (text evidence)
- F-R dependency-security-audit (templates/gates/dependency-security-audit/SKILL.md.tmpl): manifest condition "there are third-party deps" is true for nearly every project, so it is emitted almost always; it carries a generic "application-security posture" checklist (backups encrypted, network boundary, sensitivity tiers: lines 30-36) that does not derive from the project (v0.6 report §7 already noted Tally had none of these); orchestrate-build:87 dispatches it "unconditionally every 4th join" = one extra subagent per 4 joins to run `npm audit`. Recommendation: drop the skill; the join step runs `{{AUDIT_COMMANDS}}` itself when lockfiles changed (bounded output, no dispatch); posture items go to join-review dimension 3 only when DESIGN §8 names them. Saves one skill description per prompt and a dispatch per 4 joins. MAJOR (goal 3: copied by default, not decided from the project).
- F-S Join step 4 mutation testing (orchestrate-build.tmpl:79): "flip the guard, confirm the tests go red, restore" for 2-3 assertions per join = 2-3 extra scoped test runs + 4-6 edits per join, every join, with no measurement that it finds defects the join-review misses. Not "new" (predates v0.6) but is ceremony per join. Recommendation: make it conditional: only for an invariant whose unit report says "argued in comments" (step 3 already identifies these), max one per join. MINOR (speed).
- F-T Join-review "Run the narrow checks you need" (join-review.tmpl:67) adds test runs per join inside the reviewer; bounded by the reviewer's judgement; acceptable, note only.
- F-U Resident harness-doctor at orchestrated: see F8 (dead weight, nothing dispatches it, KD-020 rule 7 says doctor runs at setup only).
- F-V Gate manifest is decided from STACK (good): for Dues expect only dependency-security-audit (and maybe db-migration-review if a migration tool is chosen). Verify after step 5.

# Research notes
# Research notes (read 2026-10-24) — facts with URLs, for AUDIT_V0.7.md

## Claude Code docs (code.claude.com/docs/en/...)

### skills (https://code.claude.com/docs/en/skills)
- Skill descriptions loaded every turn; full body only when invoked. "Every skill in the skill listing adds to your context on every turn, whether or not Claude ever uses it."
- Listing budget = 1% of model context window (chars); when it overflows, descriptions dropped starting with least-used skills; names always kept. Per-skill description+when_to_use capped at 1,536 chars. Settings: skillListingBudgetFraction, SLASH_COMMAND_TOOL_CHAR_BUDGET, skillOverrides "name-only". /doctor estimates listing cost; /context shows Skills row.
- `allowed-tools` in skill frontmatter: a permission GRANT while the skill is active ("The grant clears when you send your next message"). NOT a restriction. `disallowed-tools` also exists.
- `disable-model-invocation: true` keeps the description out of context entirely.
- `context: fork` runs the skill in a subagent that does not see the conversation; background by default.
- After compaction: most recent invocation of each skill re-attached, first 5,000 tokens per skill, 25,000 tokens combined, newest first. Skill file not re-read later.
- "Keep SKILL.md under 500 lines." Rules that must hold every time should be hooks, not skill text.

### sub-agents (https://code.claude.com/docs/en/sub-agents)
- Frontmatter: tools, disallowedTools (these DO restrict), model, permissionMode, maxTurns, skills (full content injected, up to 32), memory, background, isolation (worktree), omitClaudeMd, autoCompactWindow, hooks.
- Background is now the default for Agent-tool subagents; background subagents have "a smaller built-in tool set than foreground subagents".
- Non-fork subagents: fresh context, no conversation history, no invoked skills, no files read. They DO get the CLAUDE.md hierarchy (user + project + rules + AGENTS.md) and a git status snapshot; can discover/invoke skills via Skill tool. Explore/Plan skip CLAUDE.md. Combined subagent description budget 15,000 tokens.
- Subagents auto-compact independently.

### worktrees (https://code.claude.com/docs/en/worktrees)
- `isolation: worktree`: temporary worktree under .claude/worktrees/, branched by default from the DEFAULT branch, not the parent's HEAD (`worktree.baseRef: "head"` changes this). Auto-removed if no changes; otherwise kept until periodic sweep (cleanupPeriodDays, 30d default; keeps uncommitted/unpushed work). Enforcement blocks edits/commands/git redirects into the main checkout. Instruction files come from the main conversation. `.worktreeinclude` copies gitignored files (.env). Each worktree is a fresh checkout needing its own dependency install. Cost figures: not stated. Permission rule `Agent(isolation:worktree)` exists. `/batch` uses one worktree per subagent.

### hooks (https://code.claude.com/docs/en/hooks, /hooks-guide)
- Events incl. SessionStart (matchers startup/resume/clear/compact/fork), PreCompact (manual/auto; can block; cannot inject additionalContext), PostCompact (receives compact_summary; no decision control), SubagentStart/SubagentStop, Stop (can block turn ending), InstructionsLoaded (load_reason: compact), WorktreeCreate/Remove, TaskCreated/Completed.
- Exit 2 blocks; plain stdout added to context only for some events (SessionStart, UserPromptSubmit). onFailure continue|block (v2.1.295+). timeout default 600s. async hooks don't block. additionalContext capped 10,000 chars.

### memory / CLAUDE.md (https://code.claude.com/docs/en/memory, /costs, /best-practices)
- "target under 200 lines per CLAUDE.md file. Longer files consume more context and reduce adherence." Costs page: "Aim to keep CLAUDE.md under 200 lines."
- Best practices: "CLAUDE.md is loaded every session, so only include things that apply broadly. For domain knowledge or workflows that are only relevant sometimes, use skills instead." Per line: "Would removing this cause Claude to make mistakes? If not, cut it. Bloated CLAUDE.md files cause Claude to ignore your actual instructions!" Hooks are "for actions that must happen every time with zero exceptions" because CLAUDE.md is advisory.
- Imports (@path) load with the file and do not reduce cost. Project-root CLAUDE.md re-read from disk after compaction. HTML comments stripped before injection.
- "Compact Instructions" section in CLAUDE.md steers what the summary keeps.

### context window / compaction (https://code.claude.com/docs/en/context-window, /how-claude-code-works, /model-config)
- What survives compaction: system prompt; project-root CLAUDE.md re-injected; skill descriptions rebuilt; git status snapshot; files read/edited: re-reads up to FIVE, most recently modified first, and "a file over 5,000 tokens comes back as a path reference only"; invoked skill bodies capped 5,000/skill, 25,000 total; background commands and subagents keep running; SessionStart compact hooks run and output added; context hooks added earlier is summarized.
- "It clears older tool outputs first, then summarizes the conversation if needed. Your requests and key code snippets are preserved; detailed instructions from early in the conversation may be lost."
- No documented pre-compaction notice to the model. Thresholds: default compacts when conversation reaches the model's context limit (cloud sessions approach); configurable /autocompact, autoCompactWindow, CLAUDE_CODE_AUTO_COMPACT_WINDOW (100K to 1M).
- Costs: "Agent teams use approximately 7x more tokens". MCP tool definitions deferred by default.

### permissions (https://code.claude.com/docs/en/permissions)
- Order: deny, then ask, then allow; first match wins. Bare tool name in deny removes the tool from context. Write(path)/Glob(path) rules never match; use Edit/Read. Rules: Agent(model:opus), Agent(isolation:worktree), Skill(skill:name).

### output styles (https://code.claude.com/docs/en/output-styles)
- Not deprecated. Custom style drops built-in coding instructions unless keep-coding-instructions: true. Styles survive compaction, apply to forks; "Other subagents run their own system prompt, so styles don't change how they respond."

## Anthropic engineering
- Effective context engineering (https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents, 2025-09-29): context is finite with diminishing returns ("context rot"); subagents use tens of thousands of tokens and return 1-2k token summaries; just-in-time context (identifiers, load with tools); structured note-taking (NOTES.md) for milestones; system prompt at the "right altitude", start minimal, add rules from observed failures.
- Effective harnesses for long-running agents (https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents, 2025-11-26): session start = pwd, git log, read claude-progress.txt, read feature list, run init.sh and a basic end-to-end test "to catch bugs left by earlier sessions"; feature list as JSON with `passes` field agents may only flip; one feature at a time; session end = commit, progress summary, clean state. Compaction "not sufficient on its own". Browser-level testing beat unit tests + curl.
- Multi-agent research (https://www.anthropic.com/engineering/multi-agent-research-system, 2025-06-13): lead saves plan to memory because context >200k gets truncated; subagent brief = objective, output format, tool guidance, task boundaries; agents ~4x chat tokens, multi-agent ~15x; "most coding tasks involve fewer truly parallelizable tasks than research"; lead spins 3-5 subagents in parallel.
- Managed agents (https://www.anthropic.com/engineering/managed-agents, 2026-04-08): harness assumptions "can go stale as models improve" (context resets became dead weight on Opus 4.5); session is append-only log; irreversible selective retention can cause failures.
- Writing tools (https://www.anthropic.com/engineering/writing-tools-for-agents): Claude Code caps tool responses at 25,000 tokens; concise/detailed response formats cut tokens ~3x.
- Best practices (https://code.claude.com/docs/en/best-practices): subagents to keep research out of context; adversarial reviewer in fresh subagent "sees only the diff and the criteria"; warns a reviewer prompted to find gaps "will usually report some, even when the work is sound"; verification levels incl. Stop hook that blocks turn end until a check passes; "If you can't verify it, don't ship it."
- Agent Skills post (https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills): progressive disclosure is the core principle; split SKILL.md when unwieldy.

## Agent Skills spec (agentskills.io)
- https://agentskills.io/specification: three levels: metadata (~100 tokens, name+description at startup), instructions (SKILL.md body, recommended under 5,000 tokens, "under 500 lines"), resources (scripts/references/assets, loaded when needed). description 1-1024 chars. References one level deep.
- https://agentskills.io/skill-creation/best-practices: say WHEN to load each reference; cut what the model already knows ("Would the agent get this wrong without this instruction?"); overly comprehensive skills hurt; one default not a menu; gotchas in SKILL.md.
- https://agentskills.io/skill-creation/optimizing-descriptions: description carries the whole triggering burden; eval with ~20 queries.

## Academic
- Gloaguen et al. 2026, arXiv:2602.11988 (https://arxiv.org/abs/2602.11988): SWE-bench Lite + AGENTbench (138 tasks, 12 repos); Claude Code/Sonnet 4.5, Codex, Qwen. LLM-generated context files reduced success ~0.5% / ~2%; human-written +4% avg (not for Claude Code); context files added 2.45-3.92 steps and ~20-23% cost; agents DO follow files (uv 1.6/instance vs 0.01); codebase overviews did not shorten path to files; LLM files mostly duplicate docs. Recommendation: human-written, minimal, essential tooling only; evaluate changes rigorously.
- Lulla et al. 2026, arXiv:2601.20404: 10 repos, 124 PRs; AGENTS.md associated with 28.64% lower median runtime, 16.58% fewer output tokens, comparable completion.
- Progressive disclosure 2026: arXiv:2606.11543 (+4.1% passes with PD when resources actionable); arXiv:2607.17598 ("buys context, not intelligence"; second routing level never helps); arXiv:2608.23067 (injecting matching skill lowered Pass@2 1.3-4.2%, raised tokens 72-394%; length alone hurts; anti-pattern rules beat examples).

## HumanLayer
- Writing a good CLAUDE.md (https://www.humanlayer.dev/blog/writing-a-good-claude-md): "<300 lines is best, shorter is even better", their root under 60 lines; models follow ~150-200 instructions, Claude Code's system prompt already ~50; WHAT/WHY/HOW; progressive disclosure via agent_docs/ with one-line descriptions; "Never send an LLM to do a linter's job" (use hooks); Claude Code wraps CLAUDE.md as "may or may not be relevant"; as instruction count rises Claude ignores all uniformly.
- ACE-FCA (https://github.com/humanlayer/advanced-context-engineering-for-coding-agents/blob/main/ace-fca.md): keep context 40-60%; frequent intentional compaction via progress file + fresh session; Research → Plan (~200 lines) → Implement, compact status into plan after each verified phase; subagents for context control; review plans not code.
- Pragmatic Engineer interview 2026-07-15 (https://newsletter.pragmaticengineer.com/p/context-engineering-with-dex-horthy): "dumb zone" past ~100K on smaller models; hour of planning saves ~4h implementation.

## Community
- obra/superpowers (https://github.com/obra/superpowers): SessionStart-injected bootstrap skill, re-injected after compaction; mandatory 7-skill sequence; writing-skills word budgets (frequently loaded <200 words, others <500), "no skill without a failing test"; subagent-driven-development: fresh implementer per task, task brief file, ledger file because conversation memory does not survive compaction, per-task review with capped fix loop + one whole-branch review; brainstorming hard gate (nothing built before human approves design doc).
- Boris Cherny Jan 2026 thread (https://threadreaderapp.com/thread/2017742741636321619.html): 3-5 worktrees each with a session; plan mode; update CLAUDE.md after each correction "until the error rate measurably drops"; subagents to keep main context clean; "prove to me this works"; `/statusline` for context usage. March 2026 (via https://github.com/0xquinto/bcherny-claude): hooks per lifecycle stage, `claude -w` worktree, `/batch` fan-out, `--bare`.
- Worktree cost (vendor post https://aiterm.app/blog/run-multiple-ai-coding-agents/): ~600 MB RAM per session, ~400 MB disk per stale worktree with node_modules; 4 agents in 4 worktrees → 28 conflicting files, 40 min merging.

## Update 2026-10-24 (second usage-limit stop): resumed chain, steps 3-verify to 5

Resumed with `--resume`; the run stopped again by usage limit during step 5 (harness-forge) after 4 harness-doctor rounds. Log: `/Users/santiago/Projects/psk-v07-testbed/logs/setup2.stream.jsonl`.

| Dispatch | Wall (s) | Turns | Bash | Peak context (tokens) | Test-suite runs |
|---|---|---|---|---|---|
| MAIN orchestrator (this resume) | 3,517 | 17 | 5 | 82,447 | 3 |
| Step 3 verify (design-author self-check) | 180 | 14 | 13 | 91,592 | 0 |
| Step 4 scaffold | 659 | 50 | 47 | 151,273 | 8 |
| Step 5 harness-forge | 2,402 | 43 | 38 | 229,559 | 9 |
| Step 5 fix round 1 (harness-forge) | 137 | 12 | 10 | 65,635 | 1 |
| harness-doctor rounds 1-4 (nested inside step 5) | included above | | | | |

Resume totals: 3,524 s wall, $44.97, 331k output tokens, 10.5M cache-read tokens. Chain so far (steps 1-5, incomplete): 5,071 s (85 min) and $54.78, with steps 6-8 still to run. Steps 4 and 5 ran the full check command 18 times between them; the harness-doctor was dispatched 4 times inside step 5 (fix loop). This is a MAJOR speed finding (goal 1): the forge/doctor loop, not the interview, dominates chain cost. Also candidate finding: step 5 peak context 229k tokens in one subagent, far above the 5,000-token file-reference threshold, so any compaction inside harness-forge loses the templates it is copying.

Still not done: steps 6-8 (backlog-author, plan-lint, seed+doctor), the harness run for U0 + one unit, step C for the Dues harness, the final one-screen audit, and `V0.7_CHANGES_PROMPT.md` (skeleton in scratchpad `changes-prompt-draft.md`; BLOCKER/MAJOR items F1-F7, F-R plus the chain-cost finding above).

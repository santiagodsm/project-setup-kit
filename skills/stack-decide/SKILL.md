---
name: stack-decide
version: 0.1.0
description: "Lock the technology stack as ADRs and emit the gate manifest that harness-forge consumes. Produces STACK.md: language, framework, database, test tooling, deploy target, the check command, and which quality gates are actually coherent for this stack. Step 2 of project setup, after project-brief. Use when the user says 'pick the stack', 'what should I build this with', or after a PRD exists."
allowed-tools:
  - Read
  - Write
  - Edit
  - AskUserQuestion
  - WebSearch
  - WebFetch
  - Bash
metadata:
  role: decider
  reads: [PRD.md, OPEN_QUESTIONS.md]
  writes: [STACK.md, OPEN_QUESTIONS.md]
---

# stack-decide — commit, and say what you rejected

## RE-TIER mode (check this first)

If `STACK.md` already exists and `setup-project` dispatched you after a **tier mismatch**, you are in RE-TIER mode. Do exactly this and stop:

1. Read the new `<!-- TIER -->` marker in `PRD.md`.
2. **Rebuild the gate manifest table against the new tier.** Every row is conditioned on two things — does the stack support it, and does the tier want it. The tier just changed, so the second condition changed for every row.
3. Leave the ADRs, the check command, and the "not chosen" list **untouched**. The stack did not change; only its size did.

Why this mode has to exist: manifest rows are tier-conditioned *at write time*. On a `small` tier you wrote `no` against every gate. If nobody rebuilds the manifest, a re-forge reads "only the gates in the manifest," finds none, and emits a gateless harness — which `harness-doctor` then compares against that same stale manifest and pronounces **CLEAN**. Three checks, all agreeing, all wrong.

---


Two outputs, and the second is the one people forget:

1. **Locked stack decisions**, as ADRs. Not a menu. Not "you could use X or Y." A commitment, with the alternatives you rejected and why.
2. **A gate manifest** — which quality gates are *coherent* for this stack. `harness-forge` reads this and emits exactly those gates.

## Why the gate manifest is the real deliverable

A gate that cannot run is worse than no gate. An agent told to run `db-migration-review` on a project with no migrations will either invent a check, skip it and say it passed, or rationalize past it. All three produce a harness that **lies about what is being verified** — and you will believe it.

So: a gate exists only if the stack actually supports it. No ORM, no migration gate. No design tokens, no token lint. No generated API client, no contract-drift gate. **This is a subtraction exercise, and being generous here is the failure.**

## Search before you decide. Your training data is stale.

Versions, deprecations, pricing, platform rules, and "is this library still maintained" are **present-day facts you cannot know**. Search them. A stack locked against a library that was abandoned eighteen months ago is a bad day discovered in week three.

Verify at minimum: current stable versions of the language and framework; whether anything you're picking is deprecated or in maintenance-only; anything with a pricing or platform-policy constraint the PRD depends on.

## Decide these (each is an ADR, or an OQ)

| | Notes |
|---|---|
| **Language + runtime** | Version-pinned. |
| **Backend framework** | Or "none — this is a client-only app," which is a real answer. |
| **Database** | The single biggest constraint on the design. Relational vs document vs none. |
| **Migration tooling** | Follows from the DB. **Determines whether a migration gate exists.** |
| **Frontend** | Web, native, both, or none. |
| **Design system / tokens** | **Determines whether a token lint exists.** "No token system" is a legitimate answer for a small build. |
| **API contract** | Hand-written, OpenAPI-generated, tRPC, GraphQL. **Determines whether a contract-drift gate exists.** |
| **Test tooling** | Per layer. Must cover every layer the design will have. |
| **Auth** | Almost always more constraining on the schema than people expect. |
| **Deploy target** | Sets the release gate's shape. |
| **Async / jobs / real-time** | Only if the daily loop needs it. Say so if it doesn't. |
| **MCP tool surface** | Does the product ship or dispatch MCP servers/tools (its own, or third-party)? **Determines whether an `mcp-scan` gate exists.** "No MCP" is the common answer; say it explicitly. |
| **THE CHECK COMMAND** | See below. This is the most-referenced string in the entire harness. |

## The check command (get this right or everything downstream suffers)

Every gate, every engineer, every reviewer invokes one command to prove the build is green. Name it now.

**It must be self-contained-green.** If it only passes when a human remembers to export an environment variable, start a container, or run it from the right directory, **that is a defect in the command, not a quirk to document.** An agent will hit the failure, decide it is "environmental," and pass the story anyway. Every harness that tolerates this eventually ships red.

Specify:
- The exact command (`make check`, `npm run check`, `just check`).
- What it runs: lint, typecheck, tests, build.
- **Its preconditions, and how they are satisfied automatically.** A database it needs, it starts. A container it needs, it starts.
- **Test isolation.** If tests touch a database, each parallel worker needs its own. Decide this **now**, not after concurrent runs corrupt each other. Retrofitting isolation is painful and until you do, the harness cannot parallelize at all.

## Reserved decisions are not yours

`OPEN_QUESTIONS.md` holds what the user reserved. **Do not resolve them.** If a reserved question blocks a stack choice, say so, lock what you can, and record the blocked part as a new OQ. Locking a decision the user reserved is the one unforgivable move here — they will not notice until it is load-bearing.

## One ADR namespace, shared with the design

You number ADRs from **ADR-001**. `design-author` continues from wherever you stopped — if you end at ADR-006, its first is ADR-007. **Never restart the numbering.**

Two namespaces both starting at ADR-001 is a quiet disaster: `harness-forge` and the generated `code-review` both cite ADRs by number, and "ADR-003" would resolve to two different decisions depending on which file you happened to open. Record your last number explicitly so the next skill can pick it up.

## Output — `STACK.md`

```markdown
# Stack — <project>

## Locked (ADRs)   — this project's ADR numbering STARTS here; design-author continues it

ADR-001 — <Decision>                                   [LOCKED <date>]
- Decision:   the specific, version-pinned choice
- Because:    the reason, tied to a PRD constraint or the daily loop
- Rejected:   the real alternative, and its real cost
- Constrains: what downstream this forces
- Revisit if: the condition that would reopen it

## The check command
`<command>` — runs <lint, typecheck, tests, build>.
Preconditions: <what it needs> — satisfied automatically by <how>.
Test isolation: <per-worker DB strategy, or "no DB in tests">.

## Gate manifest  (harness-forge reads this; ONLY these gates are emitted)
Tier: <from PRD.md's TIER marker>

| Gate | small | standard | full | Stack condition |
|---|---|---|---|---|
| regression-run            | **no** | yes | yes | — |
| code-review               | **no** | **no** | yes | — |
| docs-sync                 | **no** | **no** | yes | — |
| db-migration-review       | **no** | **inline** | yes | a migration tool exists |
| api-contract-sync         | **no** | **inline** | yes | the client is generated from a spec |
| design-token-lint         | **no** | **inline** | yes | a token system exists |
| dependency-security-audit | **no** | **no** | yes | there are third-party deps |
| mcp-scan                  | **no** | **no** | yes | the project ships or dispatches MCP servers/tools |
| perf-profiling            | **no** | **no** | DEFERRED | see below |
| release-runbook           | **no** | **no** | yes | a deploy target exists |

**Three values, and `inline` is not the same as `yes`:**

- **`yes`** → `harness-forge` emits the gate as its own skill file.
- **`no`** → not emitted. **Emitting it anyway is a BLOCKER**, because at that tier nothing dispatches it: an orphan skill file is a gate you believe you have and don't.
- **`inline`** → the *check* exists but not as a separate skill. At `standard` there is no epic gate to dispatch one, so the migration cycle, the contract-drift check, and the token lint are folded **into `story-reviewer` step 5**. The check runs; it just isn't a file.

**Every row is `no` on `small`.** That is KD-002 working, not an oversight — including `release-runbook`, even when a deploy target exists. A small harness's only skill is `build-loop`, which has no dispatch path for a gate, so any gate you mark `yes` there becomes an unreachable orphan.

**`perf-profiling` is the one you cannot decide.** It depends on whether §8 ends up with numeric targets, and the design is written *after* you. Mark it **`DEFERRED`** on full tier (`no` on the others). `harness-forge` reads `DESIGN.md`, resolves it, and **writes the answer back into this table.** A `DEFERRED` row must not survive into the built harness — `harness-doctor` cannot classify one, and the fidelity check then silently passes on a gate nobody ever decided. Do not guess it yourself: a perf gate with no targets will invent something to measure.

## ADR numbering handoff
Last ADR issued here: **ADR-00N**. `design-author` continues at ADR-00N+1.

## Not chosen, deliberately
What this project does NOT use, and why. Stops later agents adding it back.
```

## Self-check

- [ ] Every choice is version-pinned and **searched**, not recalled.
- [ ] Every ADR names a **real** rejected alternative with a real cost. A strawman means the decision wasn't real.
- [ ] The check command is self-contained-green, with its preconditions automated.
- [ ] Test isolation decided **now**.
- [ ] Every gate in the manifest can actually run against this stack. Cut the ones that can't — generosity here is the failure.
- [ ] No reserved OQ was quietly resolved.
- [ ] "Not chosen, deliberately" is populated.

## Return (~120 words)

- The stack in one line.
- **The check command**, verbatim.
- ADR count. Gates **included** vs **excluded** (name the excluded ones — that list is what makes the harness honest).
- New OQs, if any.
- The decision you are least confident in, and what would confirm it.

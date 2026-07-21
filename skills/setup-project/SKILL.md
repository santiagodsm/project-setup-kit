---
name: setup-project
version: 0.1.0
description: "Run the full project setup chain: brief → stack → design → scaffold → harness → backlog → lint → doctor. Maintains SETUP_PROGRESS.md so setup can span sessions. This is the entry point of the Project Setup Kit. Use when the user says 'new project', 'set up a project', 'start a project', 'I want to build X', or 'resume setup'."
allowed-tools:
  - Read
  - Write
  - Edit
  - Agent
  - Skill
  - AskUserQuestion
  - ToolSearch
metadata:
  role: orchestrator
  reads: [SETUP_PROGRESS.md, PRD.md (TIER), DESIGN.md (line-1 GATE), PLAN.md (first eligible story)]
  writes: [SETUP_PROGRESS.md, PRD.md (the TIER marker ONLY, on a tier-mismatch re-forge), the build state file (seeding step 8)]
---

# setup-project — walk the chain, in order, once

You take a person from "I have an idea" to "this repo has a design, a plan, and its own build agents." Then you get out of the way. The harness you generate is the project's; the kit is not a runtime dependency.

**Read `SETUP_PROGRESS.md` first, always.** If it exists, you are resuming — go to the step it names. If it doesn't, you are starting at step 1.

## Step 0 — before anything

Create `SETUP_PROGRESS.md` **first**, before you invoke a single skill. Step 1 is a long interview; a crash halfway through it must not lose the whole conversation. Write the file after every step thereafter.

**You are its only writer.** No other skill in the chain touches it — they return, you record. Two writers on a state file is a clobber waiting to happen.

## The order is the product

Each step is an input to the next. Run them out of order and you get a backlog written against a design whose stack was never decided.

| # | Skill | Produces | Gate before moving on | On failure |
|---|---|---|---|---|
| 1 | `project-brief` | `PRD.md` | `<!-- TIER: x -->` marker present. ≥4 non-goals. Daily loop concrete. | — |
| 2 | `stack-decide` | `STACK.md` | Check command named. Gate manifest emitted. | — |
| 3 | `design-author` | `DESIGN.md` | Line 1 reads `<!-- GATE: BACKLOG CLEAR -->` | **BLOCKED** → ask the user → re-dispatch `design-author` in **AMEND mode** → recheck |
| 4 | `scaffold` | The repo | **Check command green from cold, AND red when broken.** Both verified by running them. | Re-dispatch with the specific failure. **3 rounds max**, then stop and ask the user — a toolchain that won't come up green in three tries needs a human, not a fourth agent. |
| 5 | `harness-forge` | `CLAUDE.md` + `.claude/**` | It runs `harness-doctor` internally; **zero BLOCKERs** | 3 rounds max, then report failure |
| 6 | `backlog-author` | `PLAN.md` | — | Refuses if step 3's gate is not CLEAR |
| 7 | `plan-lint` | `PLAN_LINT.md` | **Zero BLOCKERs and zero MAJORs** | → re-dispatch `backlog-author` in **FIX mode** with the numbered findings → re-lint. **3 rounds max**, then stop and ask the user. |
| 8 | **Seed + final doctor** | The harness's first story | Zero BLOCKERs | → re-dispatch `harness-forge` with the numbered findings → re-doctor. **3 rounds max**, then report failure. |

**Step 8 is not a repeat of step 5.** At step 5 there was no `PLAN.md`, so `harness-forge` emitted the build state file as a stub pointing at nothing. Now the plan exists and has been linted. Step 8:

1. **Seed the state file** with the first eligible story, so the generated orchestrator boots pointing at real work.
2. Run `harness-doctor` once more over the **finished** repo — harness plus plan plus seeded state. This is the only pass that sees the whole thing assembled.

## Loop-backs (the chain is not a straight line)

Three steps can send you backwards. Each is capped — an uncapped fix loop will spin forever on a problem it doesn't understand.

- **3 → user → 3 (AMEND).** Blocking questions get answered, `design-author` folds them in and recomputes the banner. No cap; it's gated on a human.
- **7 → 6 → 7.** Lint findings go back to the author. **Max 3 rounds**, then stop and ask the user — three failed attempts at testable acceptance criteria means the design underneath is unclear, not the plan.
- **7 → 5 (tier mismatch).** `plan-lint` compares the real story count to the tier. If they disagree, the harness at step 5 was sized against a wrong estimate — and a light harness on a heavy build has no independent reviewer and no epic gates, on exactly the project that most needs them.

  **This loop-back has FOUR steps. Skip either of the first two and it is a no-op that looks like a fix:**
  1. **Rewrite the `<!-- TIER: x -->` marker in `PRD.md`.** Confirm the new tier with the user first — it was their call. `harness-forge` reads the tier from that marker and nowhere else.
  2. **Re-dispatch `stack-decide` in RE-TIER mode** to rebuild the gate manifest. This is the one everybody misses. **The manifest rows are tier-conditioned at write time** — on a `small` tier `stack-decide` wrote `no` against every gate. If you re-forge without rebuilding it, `harness-forge` reads "only the gates in the manifest," finds none, and emits a gateless "standard" harness. Then `harness-doctor` compares that harness *against the same stale manifest*, finds them consistent, and reports **CLEAN**. You end up with three independent checks all confirming a harness that has no gates at all.
  3. Re-dispatch `harness-forge`.
  4. **Re-run step 7 (`plan-lint`), then step 8.** The tier-mismatch finding is still open in `PLAN_LINT.md` and nothing else will ever clear it — `backlog-author`'s FIX mode only edits `PLAN.md`, and the tier was never the plan's fault.

  Do not carry on with the wrong harness to save time. You pay it back as a gate that was never there.

## Step-8 findings: who fixes what

`harness-doctor` is **report-only** — it never patches what it diagnoses, and you have no `Bash` and cannot patch a harness yourself. So a step-8 BLOCKER goes back to **`harness-forge`**, with the numbered findings. It wrote the harness; it fixes the harness. Three rounds, then stop and report failure with the specific findings — a generator that can't converge in three rounds does not understand what it produced, and rounds four through ten will not change that.

## The three hard gates. Do not walk past them.

**After step 3 — `BACKLOG BLOCKED`.**
`design-author` refuses to invent what the brief didn't specify, and marks those gaps BLOCKING. **Stop and get the answers from the user.** Do not proceed to the backlog. If you do, `backlog-author` writes acceptance criteria for behavior nobody ever chose, the design's honesty is laundered into a confident requirement, and an engineer builds it while a reviewer passes it. Every safeguard downstream is now pointing at fiction.

This gate exists because the alternative is silent. Nothing later will catch it.

**After step 4 — the check command.**
It must be **green from a cold clean clone** and **red when the code is broken**. Both, verified by running them.

A check command that only passes when a human remembers to export a variable will be hit by an agent that cannot ask anyone. It will reason "this failure is environmental and unrelated to my change" and pass the story. That reasoning is locally sensible and globally fatal, and it happens *every* time. A check command that cannot fail is worse still: everything passes forever and you trust it.

**After steps 5 and 7 — zero BLOCKERs.**
A generated harness with a missing tool grant or an unreachable gate fails on its first real story, and the failure looks like a build problem rather than a harness problem. That is the expensive kind: you debug the wrong thing.

## How to run each step — DISPATCH. Never run a step yourself.

**Every step is dispatched as a `general-purpose` subagent, told to invoke the skill by name and follow it in full.** Not "long steps." Every step. There is no exception.

This is not a style preference, it is a hard constraint:

**Your tools are `Read`, `Write`, `Edit`, `Agent`, `Skill`, `AskUserQuestion`, `ToolSearch`. You have no `Bash`, no `Grep`, no `Glob`.** And a skill's `allowed-tools` **intersects down** with the tools of whoever loads it. So if *you* invoke `scaffold`, it cannot run the check command. If *you* invoke `harness-doctor`, it cannot grep, glob, or run git — which silently disables four of its thirteen checks, and it will report CLEAN on a harness it never actually inspected. If *you* invoke `stack-decide`, it cannot search the web and will lock a stack from stale training data.

Every one of those failures is **silent**. The skill runs, produces plausible output, and reports success.

### Dispatch these steps **synchronously**. This is the one place background is wrong.

The generated build harness dispatches every subagent with `run_in_background: true`, because it runs many stories at once. **Your chain is the opposite shape: each step's output *is* the next step's input.** There is nothing to overlap — `design-author` cannot start before `STACK.md` exists, and `backlog-author` reads the gate banner `design-author` writes. Dispatching in the background here buys zero wall-clock and adds the one failure this skill exists to prevent: moving to step N+1 before step N actually finished. "The order is the product."

So: **chain steps synchronous (`run_in_background: false`); the notify-only dispatch background.** A notification has no output anyone waits on, and blocking the chain on a push to somebody's phone would be absurd.

Do not generalize the harness's rule to here, and do not generalize this exception to the harness. The rule in both places is the same one: **dispatch in the background exactly when there is other work to do meanwhile.**

The restriction is deliberate: it is what keeps your context flat across a chain that spans sessions. Dispatch, take the capped return, record it, move on. Read a produced file only when you need one specific value from it (the `<!-- GATE -->` banner, the `<!-- TIER -->` marker, the first eligible story).

Write `SETUP_PROGRESS.md` **after every step**. Setup spans sessions. A crash should cost at most one step.

## Reaching the user when the chain stops

A halted chain is indistinguishable from a finished one if nobody is at the terminal — and long silences get resolved by guessing. So a stop that waits on a person gets **one push** to their phone (never one per question — `notify.sh ask --count N` bundles them; `ASK_CONTRACT.md` at the plugin root is the contract for both channels).

You have no `Bash`; delegate the push like everything else:

1. **The skill that discovers the stop sends it before returning** — `design-author` on BLOCKED; `scaffold`, `harness-forge`, `plan-lint` on their third failed round. Still say in every dispatch prompt: *"if you end in a state that waits on the user, push once per `ASK_CONTRACT.md` before returning."* A subagent reads the skill, not this file.
2. **For a stop only you can see** (tier mismatch to confirm, a bailout you are declaring), dispatch a one-shot `general-purpose` agent (`model: haiku` — the wording is already written) to run `~/.claude/scripts/notify.sh ask` — **with the plain-language wording written by you** in the dispatch prompt.

**Then still ask in the terminal.** The push is the doorbell; `AskUserQuestion` is where the answer gets captured. Delivery failure exits 0 and never halts the chain.

## Handing off between sessions

**Hand off when a context/summarization `<system-reminder>` fires. That is the only signal.** Not "this feels like a good stopping point," not "that was a big step." Write `SETUP_PROGRESS.md`, name the next step, and stop. A fresh session reads the file and continues.

Step 1 (the interview) and step 3 (the design) are long and will often span sessions on their own. That is expected and is not a reason to rush them.

## `SETUP_PROGRESS.md`

```markdown
# SETUP_PROGRESS — <project>

## NEXT
Step <N>: <skill>. <Why it's next / what's blocking.>

## Decisions locked
- Build tier: <tier> (~N stories)
- Stack: <one line>
- Check command: `<verbatim>`
- **Build state file:** `<path harness-forge returned>`   ← record it. You have no Glob, steps 5→8 often span sessions, and you must seed this file at step 8.
- Harness tier emitted: <tier> · gates: <list> · gates excluded: <list>

## Steps
- [done]    1. project-brief   → PRD.md
- [done]    2. stack-decide    → STACK.md (N ADRs, gates: a, b, c)
- [BLOCKED] 3. design-author   → DESIGN.md — BACKLOG BLOCKED on OQ-002, OQ-004
- [pending] 4. scaffold
...

## Open questions blocking setup
- OQ-002 — <question>. Blocks: <what>.

## Notes
Anything a fresh session would otherwise have to rediscover.
```

## When setup is done

Tell the user, concretely:
- What exists now: design, plan, harness, repo.
- **The story count and the first story.**
- **The one command that starts the build.**
- Any DEFERRABLE gap that is scheduled but not yet specified — so they know what the plan is quietly carrying.

Then stop. The build is not your job, and the project no longer needs this kit.

## Do not

- **Do not skip a step because it seems obvious.** The step you skip is the one whose absence is silent.
- **Do not answer a reserved question on the user's behalf.** Ever. They will not notice until it is load-bearing.
- **Do not proceed past a hard gate to be helpful.** A blocked chain that asks one question is working correctly. That is the whole design.
- **Do not let the tier drift.** If the plan comes in at four times the estimate, the harness was sized wrong. Say so and re-forge — do not quietly carry on with a light harness on a heavy build.

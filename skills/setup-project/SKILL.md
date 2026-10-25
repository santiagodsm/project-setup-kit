---
name: setup-project
version: 0.1.0
description: "Run the full project setup chain: brief → stack → design → scaffold → harness → backlog → lint → doctor. Maintains SETUP_PROGRESS.md so setup can span sessions. This is the entry point of the Project Setup Kit. Use when the user says 'new project', 'set up a project', 'start a project', 'I want to build X', or 'resume setup'."
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
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

Kit root: `cat ~/.claude/project-setup-kit.root`; if the file is missing, the root is the directory two levels above this SKILL.md.

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
| 3 | `design-author` (ask pass here, write pass dispatched) | `DESIGN.md` | Line 1 reads `<!-- GATE: BACKLOG CLEAR -->` | **BLOCKED** → ask the user → re-dispatch `design-author` in **AMEND mode** → recheck |
| 4 | `scaffold` | The repo | **Check command green from cold, AND red when broken.** Both verified by running them. | Re-dispatch with the specific failure. **3 rounds max**, then stop and ask the user — a toolchain that won't come up green in three tries needs a human, not a fourth agent. |
| 5 | `harness-forge`, then `harness-doctor` once | `CLAUDE.md` + `.claude/**`, `HARNESS_DOCTOR.md` | **Zero BLOCKERs** | See "Step 5: one doctor pass" |
| 6 | `backlog-author` | `PLAN.md` (+ `## Dispatch units` on the orchestrated tier) | — | Refuses if step 3's gate is not CLEAR |
| 7 | `plan-lint` | `PLAN_LINT.md` | **Zero BLOCKERs and zero MAJORs** | → re-dispatch `backlog-author` in **FIX mode** with the numbered findings → re-lint. **3 rounds max**, then stop and ask the user. |
| 8 | **Seed + final doctor** | The harness's first story | Zero BLOCKERs | → re-dispatch `harness-forge` with the numbered findings → re-doctor. **3 rounds max**, then report failure. |

**Step 8 is not a repeat of step 5.** At step 5 there was no `PLAN.md`, so `harness-forge` emitted the build state file as a stub pointing at nothing. Now the plan exists and has been linted. Step 8:

1. **Seed the state file** with the first real work — on `small`, the first eligible story; on `orchestrated`, dispatch unit **U0** (the walking skeleton) — so the generated harness boots pointing at it.
2. Run `harness-doctor` once more over the **finished** repo — harness plus plan plus seeded state. This is the only pass that sees the whole thing assembled.

## Loop-backs (the chain is not a straight line)

Three steps can send you backwards. Each is capped — an uncapped fix loop will spin forever on a problem it doesn't understand.

- **3 → user → 3 (AMEND).** Blocking questions get answered, `design-author` folds them in and recomputes the banner. No cap; it's gated on a human.
- **7 → 6 → 7.** Lint findings go back to the author. **Max 3 rounds**, then stop and ask the user — three failed attempts at testable acceptance criteria means the design underneath is unclear, not the plan.
- **7 → 5 (tier mismatch).** `plan-lint` compares the real story count to the tier. If they disagree, the harness at step 5 was sized against a wrong estimate — and a `small` harness on a heavy build has no orchestrator, no join review and no gates, on exactly the project that most needs them.

  **This loop-back has FOUR steps. Skip either of the first two and it is a no-op that looks like a fix:**
  1. **Rewrite the `<!-- TIER: x -->` marker in `PRD.md`.** Confirm the new tier with the user first — it was their call. `harness-forge` reads the tier from that marker and nowhere else.
  2. **Re-dispatch `stack-decide` in RE-TIER mode** to rebuild the gate manifest. This is the one everybody misses. **The manifest rows are tier-conditioned at write time** — on a `small` tier `stack-decide` wrote `no` against every gate. If you re-forge without rebuilding it, `harness-forge` reads "only the gates in the manifest," finds none, and emits a gateless "orchestrated" harness. Then `harness-doctor` compares that harness *against the same stale manifest*, finds them consistent, and reports **CLEAN**. You end up with three independent checks all confirming a harness that has no gates at all.
  3. Re-dispatch `harness-forge`.
  4. **Re-run step 7 (`plan-lint`), then step 8.** The tier-mismatch finding is still open in `PLAN_LINT.md` and nothing else will ever clear it — `backlog-author`'s FIX mode only edits `PLAN.md`, and the tier was never the plan's fault.

  Do not carry on with the wrong harness to save time. You pay it back as a gate that was never there.

## Step 5: one doctor pass

After `harness-forge` returns, dispatch `harness-doctor` **once**. Then, by severity:

- **BLOCKERs** (the doctor's narrow class: a build session would break): re-dispatch `harness-forge` **once** with the numbered BLOCKER lines, then dispatch `harness-doctor` once more to confirm. Still a BLOCKER: stop and ask the user. That is at most two doctor passes before step 6.
- **MAJORs and MINORs:** already recorded in `HARNESS_DOCTOR.md`. Each one the doctor marked `(one-line)` you fix yourself with `Edit`, now, and note it in `SETUP_PROGRESS.md` → Notes. The rest stay in `HARNESS_DOCTOR.md` for the user; list them in the final summary. **No further doctor dispatch** for them: step 8 audits the whole repo again anyway.

## Step-8 findings: who fixes what

`harness-doctor` is **report-only**: it never patches what it diagnoses. So a step-8 BLOCKER goes back to **`harness-forge`**, with the numbered findings. It wrote the harness; it fixes the harness. Three rounds, then stop and report failure with the specific findings: a generator that can't converge in three rounds does not understand what it produced, and rounds four through ten will not change that.

## The three hard gates. Do not walk past them.

**After step 3 — `BACKLOG BLOCKED`.**
`design-author` refuses to invent what the brief didn't specify, and marks those gaps BLOCKING. **Stop and get the answers from the user.** Do not proceed to the backlog. If you do, `backlog-author` writes acceptance criteria for behavior nobody ever chose, the design's honesty is laundered into a confident requirement, and an engineer builds it while a reviewer passes it. Every safeguard downstream is now pointing at fiction.

This gate exists because the alternative is silent. Nothing later will catch it.

**After step 4 — the check command.**
It must be **green from a cold clean clone** and **red when the code is broken**. Both, verified by running them.

A check command that only passes when a human remembers to export a variable will be hit by an agent that cannot ask anyone. It will reason "this failure is environmental and unrelated to my change" and pass the story. That reasoning is locally sensible and globally fatal, and it happens *every* time. A check command that cannot fail is worse still: everything passes forever and you trust it.

**After steps 5 and 7 — zero BLOCKERs.**
A generated harness with a missing tool grant or an unreachable gate fails on its first real story, and the failure looks like a build problem rather than a harness problem. That is the expensive kind: you debug the wrong thing.

## How each step runs: the interview here, everything else dispatched

| Step | Runs | How |
|---|---|---|
| 1 `project-brief` | **main session** | invoke the skill with `Skill` and follow it in full |
| 2 `stack-decide` | **main session** | invoke the skill with `Skill` and follow it in full |
| 3 `design-author`, **ask pass** | **main session** | invoke the skill with `Skill`, mode ASK |
| 3 `design-author`, **write pass** | dispatched | one `general-purpose` subagent, mode WRITE |
| 3 `design-author`, AMEND | dispatched | as before, with the user's answers inline |
| 4 to 8 | dispatched | one `general-purpose` subagent each, told to invoke the skill by name and follow it in full |

**Why the split.** Claude Code removes `AskUserQuestion` from every subagent, so a dispatched step can never ask the user anything; it guesses or marks a gap BLOCKING instead. The three steps whose job is asking therefore run here, in the only session that can ask. Every other step is dispatched for **context flatness**: it starts clean, reads its inputs from disk, returns a capped summary, and none of its file reads enter your context. Dispatch is not a tool restriction. A skill's `allowed-tools` pre-approves tools and restricts nothing; where a skill must not use a tool, its frontmatter says so with `disallowed-tools`.

**The design-author split.** The ask pass reads `PRD.md`, `STACK.md` and `OPEN_QUESTIONS.md` and asks the user every question the design would otherwise have to guess. You write each answer as one line under `SETUP_PROGRESS.md` → "Decisions locked" (the ask pass runs in your session, so you are still the file's only writer). Then dispatch the write pass once, pointing it at those lines. The write pass writes `DESIGN.md` from the locked decisions and may mark BLOCKING only what the ask pass did not cover. The BLOCKED, ask the user, AMEND loop is unchanged.

**After a main-session step, do not re-read what it wrote.** The next step reads the file itself. Keep the step's return (a few lines) and move on.

**Owner mode.** If `OWNER_BRIEF.md` exists at the project root, the owner wrote their answers in advance and is not at the terminal. Every skill that would ask the user reads that file instead, and says "Owner mode: answers taken from OWNER_BRIEF.md" in its output. You do the same for your own questions (a tier change to confirm, BLOCKED answers to collect). A question the brief does not answer: take the recommended option and record it in `SETUP_PROGRESS.md` → Notes as "decided for the owner", unless it is a decision the owner reserved, which stays open.

### Dispatch these steps **synchronously**. This is the one place background is wrong.

The generated build harness can run several units at once. **Your chain is the opposite shape: each step's output *is* the next step's input.** There is nothing to overlap. `design-author` cannot start before `STACK.md` exists, and `backlog-author` reads the gate banner `design-author` writes. Dispatching in the background here buys zero wall-clock and adds the one failure this skill exists to prevent: moving to step N+1 before step N actually finished. "The order is the product."

So every dispatch here is synchronous (`run_in_background: false`). The rule is the same one the generated harness follows: **dispatch in the background exactly when there is other work to do meanwhile.**

Dispatch, take the capped return, record it, move on. Read a produced file only when you need one specific value from it (the `<!-- GATE -->` banner, the `<!-- TIER -->` marker, the first eligible story).

**What a dispatch carries:** the skill name, the mode if any (WRITE / AMEND / FIX / RE-TIER), the inputs by *path*, and only the values the skill cannot read from disk: the numbered findings from a prior return, the user's answers to blocking questions. Never paste a produced file's contents into a prompt. The skill reads files itself, and everything you paste sits in your context for the rest of the chain.

Write `SETUP_PROGRESS.md` **after every step**. Setup spans sessions. A crash should cost at most one step.

## Talking to the user

Every message you, or a step running in this session, writes to the user follows these eight rules:

1. **Answer first.** The first sentence says what happened, what you found, or what you need.
2. **Short by default.** Progress is three lines at most: outcome, what is left, what is blocked. No narration, no recap.
3. **Plain words.** A needed technical term is explained in the same sentence the first time.
4. **No bare internal labels.** Never "U3", "KD-017", "§4.2" or a file name on its own; say what it is.
5. **The project's own words.** The user's words and the design glossary, never new names for the same thing.
6. **Explaining.** One concrete example from this project first, then the rule; about 150 words unless asked for more.
7. **No filler.** No apologies, no "great question", no hedging, no closing offers of more help.
8. **Exact where it matters.** Commands, error messages, paths and code stay verbatim and complete.

These bind messages to the user only. Dispatch prompts, returns and design text stay precise and technical. Questions also follow `ASK_CONTRACT.md` at the kit root (read it once, when you first need to ask).

## Reaching the user when the chain stops

A halted chain is indistinguishable from a finished one if nobody is at the terminal, and long silences get resolved by guessing. So a stop that waits on a person gets **one push** to their phone (never one per question: `notify.sh ask --count N` bundles them; `ASK_CONTRACT.md` at the kit root is the contract for both channels).

1. **A dispatched skill that discovers the stop sends it before returning**: `design-author` on BLOCKED; `scaffold`, `harness-forge`, `plan-lint` on their third failed round. Still say in every dispatch prompt: *"if you end in a state that waits on the user, push once with `~/.claude/scripts/notify.sh ask` before returning."* (`notify.sh` refuses a question without the contract's fields, so the subagent does not need to read the contract.) A subagent reads the skill, not this file.
2. **For a stop you discover yourself** (a tier change to confirm, BLOCKED answers to collect, a bailout you are declaring), run `~/.claude/scripts/notify.sh ask` yourself with Bash, with the plain-language wording you wrote.

**Then still ask in the terminal.** The push is the doorbell; `AskUserQuestion` is where the answer gets captured. Delivery failure exits 0 and never halts the chain.

## Handing off between sessions

**Hand off when a context/summarization system-reminder fires. That is the only signal. If you find the conversation has been compacted instead (earlier turns replaced by a summary), do not stop: re-read `SETUP_PROGRESS.md` and continue from NEXT.** Not "this feels like a good stopping point," not "that was a big step." Write `SETUP_PROGRESS.md`, name the next step, and stop. A fresh session reads the file and continues.

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
- **Build state file:** `<path harness-forge returned>`   ← record it. Steps 5→8 often span sessions, and you must seed this file at step 8 without searching for it.
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

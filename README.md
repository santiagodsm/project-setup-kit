# Project Setup Kit

Install it into an empty repo. It takes you from "I have an idea" to a repo with a design contract, a linted backlog, and its own build agents. Then it gets out of the way — the harness it generates belongs to the project, not to this kit.

```
/project-setup-kit:setup-project
```

That's it. It runs the chain and asks you things.

---

## What it does

| Step | Skill | Produces |
|---|---|---|
| 1 | `project-brief` | `PRD.md` — the daily loop, non-goals, constraints, **the build tier** |
| 2 | `stack-decide` | `STACK.md` — locked stack (ADRs), the check command, **the gate manifest** |
| 3 | `design-author` | `DESIGN.md` — fixed §1–§12, literal DDL and contracts, locked ADRs, **the register of what's not specified** |
| 4 | `scaffold` | The repo — dirs, CI, containers, and a check command that's green from cold and red when broken |
| 5 | `harness-forge` | `CLAUDE.md` + `.claude/skills/**` + `.claude/agents/**`, **generated for this stack** |
| 6 | `backlog-author` | `PLAN.md` — epics, stories, deps, **testable** acceptance criteria |
| 7 | `plan-lint` | Audits the plan: dep cycles, untestable AC, uncovered design sections |
| 8 | seed + `harness-doctor` | Seeds the harness's first story, then audits the assembled repo: tool grants, artifact ownership, dispatch paths, return contracts |

---

## The four ideas it's built on

**A design doc is a contract, not documentation.** Every later agent cites it. So it has a fixed section map (§1–§12), literal DDL and literal API contracts rather than prose, and locked ADRs that record what was *rejected* — because a decision that keeps getting re-argued isn't locked.

**"I don't know yet" needs a legitimate home.** Asked for a schema it lacks the information to specify, a model will produce a plausible one — and it will look exactly as confident as the parts it actually knows. Nobody can tell later. So `DESIGN.md` §11 is a register of what is deliberately unspecified, each entry marked **BLOCKING** or **DEFERRABLE**. `backlog-author` **refuses to run** while anything is BLOCKING. Otherwise the honest gap gets laundered into a confident requirement one step downstream, and an engineer builds it while a reviewer passes it.

**A gate that can't run is worse than no gate.** It lies about what's being checked, and you believe it. So `stack-decide` emits a manifest of the gates the stack actually supports, and `harness-forge` emits *only* those. No ORM, no migration gate. No design tokens, no token lint.

**Shared vocabulary, not just shared section numbers.** Three agents can cite the same section and still call the same concept three different names — the scoper writes "account," the engineer builds `User`, the reviewer reads "member," and grep stops finding things. So `DESIGN.md` §2.1 is a glossary: one canonical term per concept, the rejected synonyms listed under `Avoid`, and a `Code:` anchor tying each term to its table or type. The scoper writes briefs in it, and the reviewer flags code that names a concept by an avoided word.

---

## Parallelism is the default, not the reward

The generated harness dispatches **up to 3 stories concurrently**, and scopes further ahead than that. Serial is what a *specific* story falls back to, not the posture of the build.

Two stories run together when four things hold: **no dependency edge · disjoint file sets · at most one migration-authoring story in flight · concurrent test suites can't see each other.** Fail one and that story waits while the rest keep going — one vague brief costs one story's concurrency, never the build's.

The mechanism that makes it safe is the same one that makes it fast: **scopers always run in parallel, unconditionally**, and each returns a `Files:` line naming exactly what its story will touch. That is what the orchestrator compares. A scoper that can't pin the set writes `Files: UNKNOWN`, which is a legitimate answer costing one story's concurrency — a *wrong* file set is far worse, because `UNKNOWN` is handled correctly and a wrong one is trusted.

**The mechanism ships with the policy.** Every subagent is dispatched `run_in_background: true` — otherwise "up to 3 at once" blocks on each agent in turn and runs strictly serial while every file still reads as parallel, and *nothing detects that*: no gate fails, the build is just three times slower than it claims. Two rules come with it — **a launch confirmation is not a result** (a story is done when its return is recorded), and **gates and handoffs drain first** (a full-suite run against a tree engineers are still writing to describes a state that never existed). `setup-project`'s own chain is the deliberate exception and runs synchronously: its steps feed each other, so there is nothing to overlap.

**None of this is configured, it's derived.** `stack-decide` requires a test-isolation decision, `scaffold` builds it as a hard gate, and `harness-forge` emits the concurrency the result actually supports — the same way it emits only the gates the stack can run. If isolation is missing, the harness says so *in a sentence that calls itself a defect*, because a build that quietly serializes is one nobody ever fixes: the cost is invisible and permanent, and each session assumes the last one had a reason.

---

## Proportionality

The harness is sized to the build. Ceremony you don't need gets bypassed, and a bypassed harness is worse than none.

| Tier | | Harness |
|---|---|---|
| **small** | < ~15 stories | One build loop. No gates. |
| **standard** | ~15–50 | Scoper / implementer / independent reviewer. Regression gate. |
| **full** | 50+ | Epic gates, `docs-sync`, fix-stories, the full set. |

---

## Why `harness-doctor` is mandatory

The generated harness is a multi-agent system made of prose files. **Nothing type-checks it.** A skill can demand a tool its agent was never granted, write a file nobody reads, or contradict `CLAUDE.md` outright — and it all looks fine until the build quietly stops verifying itself.

Hand-written harnesses routinely carry several load-bearing contradictions. Generated ones start worse. So setup does not complete with an open BLOCKER.

---

## When an agent has a question, it can reach you

Both halves of the system — the setup chain and the harness it generates — stop at gates by design. `design-author` refuses to invent a schema nobody specified. A story goes `blocked` rather than guessing at a reserved decision. That is the whole point.

But a stopped build looks exactly like a finished one from outside, and the difference gets noticed late. **The way a silent stop actually ends is a human coming back hours later and telling an agent to carry on — past the gate that fired correctly.** So every gate that waits on a person pushes the question to your phone, via Pushover.

### Setup

```bash
cp scripts/pushover.env.example ~/.claude/pushover.env   # fill in the two keys
chmod 600 ~/.claude/pushover.env
cp scripts/notify.sh ~/.claude/scripts/notify.sh && chmod +x ~/.claude/scripts/notify.sh
scripts/notify.sh selftest                                # a push should arrive
```

The credentials live in `~/.claude/`, outside every repo — one copy serves the kit and every project it generates, and no `git add` can reach them.

Then one hook, once, in `~/.claude/settings.json`. It pushes **only when Claude has a question or is waiting for your input**, at silent priority — permission prompts and every other notification are dropped (they fire constantly in supervised sessions, across every project on the machine), and repeats within 5 minutes are deduped per project:

```json
"hooks": { "Notification": [ { "hooks": [
  { "type": "command", "command": "\"$HOME/.claude/scripts/notify.sh\" hook", "async": true, "timeout": 20 }
] } ] }
```

Generated projects get their own `.claude/scripts/notify.sh` for the loud channel, and **deliberately no hook** — a per-project hook fires on top of the global one, and a channel that buzzes twice for nothing gets muted before the one time it mattered.

### The Ask Contract

A push that says *"I have a question about §4.2"* is useless from a lock screen. You are not looking at §4.2. You may never have read it.

So `ASK_CONTRACT.md` fixes what a question must contain, and `notify.sh ask` **refuses to send** without it: **what's actually stuck** in the words a non-engineer would use · **at least two options, each with what picking it means in practice** · **what the agent would pick, why, and what would change its mind** · **what stays blocked** until you answer. No jargon you haven't used first.

**And one push per stop, never one per question.** A stop that carries several questions sends a single summary push (`--count N`) — the numbered one-liners on your phone, the full options and recommendations at the terminal and in `OPEN_QUESTIONS.md`. A phone that buzzes five times for one stop gets muted.

Not a style preference. A question that can't be answered in four seconds gets no answer, or gets *"you decide"* — which is a decision you were never actually shown, recorded downstream as **locked** when it was really just abandoned. Same contract governs terminal questions, so the two channels can't drift.

**Delivery never fails a build.** `notify.sh` exits 0 whether or not the message arrived; a notification that can halt a run stops it for a reason unrelated to the code. `selftest` is the one mode that fails loudly, and `harness-doctor` check 12 verifies the wiring is real rather than assuming it.

---

## Design notes

`KIT_DESIGN.md` holds the locked decisions (KD-001…015) and the rationale. Read it before changing anything here.

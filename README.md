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

## The three ideas it's built on

**A design doc is a contract, not documentation.** Every later agent cites it. So it has a fixed section map (§1–§12), literal DDL and literal API contracts rather than prose, and locked ADRs that record what was *rejected* — because a decision that keeps getting re-argued isn't locked.

**"I don't know yet" needs a legitimate home.** Asked for a schema it lacks the information to specify, a model will produce a plausible one — and it will look exactly as confident as the parts it actually knows. Nobody can tell later. So `DESIGN.md` §11 is a register of what is deliberately unspecified, each entry marked **BLOCKING** or **DEFERRABLE**. `backlog-author` **refuses to run** while anything is BLOCKING. Otherwise the honest gap gets laundered into a confident requirement one step downstream, and an engineer builds it while a reviewer passes it.

**A gate that can't run is worse than no gate.** It lies about what's being checked, and you believe it. So `stack-decide` emits a manifest of the gates the stack actually supports, and `harness-forge` emits *only* those. No ORM, no migration gate. No design tokens, no token lint.

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

## Design notes

`KIT_DESIGN.md` holds the locked decisions (KD-001…015) and the rationale. Read it before changing anything here.

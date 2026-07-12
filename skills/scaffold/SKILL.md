---
name: scaffold
version: 0.1.0
description: "Build the repo skeleton from the locked stack: directories, dependency manifests, CI, test harness, containers, and above all the check command — which must be self-contained-green with per-worker test isolation. Step 4 of project setup, after stack-decide. Use when the user says 'scaffold the repo', 'set up the project structure', or after STACK.md exists."
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - WebSearch
metadata:
  role: executor
  reads: [STACK.md, PRD.md, DESIGN.md (if it exists)]
  writes: [repo skeleton, CI config, container config, the check command, .gitignore]
---

# scaffold — build the floor the agents will stand on

Every agent in the generated harness assumes this exists and works: the engineer runs the check command, the reviewer re-runs a subset of it, the regression gate runs all of it. **If the floor is soft, every one of them improvises**, and improvisation in a verification step means a green that isn't.

## The one thing that must be right

**The check command must be self-contained-green.**

Run it on a clean clone with nothing warmed up. It must pass, or fail for a real reason. It must not fail because:

- an environment variable wasn't exported
- a database wasn't running
- a container wasn't started
- it was run from the wrong directory
- a fixture wasn't seeded

Every one of those is a **defect in the command**, not a quirk to document in a README.

Here is why this is worth more care than it looks. An agent hits an environmental failure. It cannot ask you. It has a story to finish. It will reason: *this failure is pre-existing and unrelated to my change, so I'll note it and pass.* That reasoning is locally sensible and globally fatal. It happens every time, and once it happens once, the green-baseline law is dead and nobody notices.

So: **the command starts what it needs.** If it needs Postgres, it starts Postgres. If it needs a container, it starts the container. Prove it:

```bash
git clean -xdff && git stash && <check command>   # must be green from cold
```

If that doesn't pass, you are not done, whatever else you built.

## The second thing: test isolation, now

If tests touch a database, **give each parallel worker its own.** Decide and build it now.

This is not premature. It is the single constraint that determines whether the harness can ever run stories in parallel. A shared test database means concurrent agents corrupt each other's migrations — transient reds, and eventually a hang or an OOM that costs an afternoon to diagnose. Once that happens the honest response is to serialize everything, and now every future story runs at half speed, permanently, because of a decision you didn't make in week one.

Pick one and implement it:
- **Testcontainers** — a real DB per test session, cleanest, slightly slower start.
- **Database-per-worker** — `test_db_{worker_id}`, created and dropped by the fixture.
- **Schema-per-worker** — cheaper, works when the DB supports it.
- **No DB in tests** — legitimate, if true. Say so explicitly so nobody adds one later.

## Build

Work from `STACK.md`. Emit only what the stack actually calls for.

| | |
|---|---|
| **Directories** | Match what `DESIGN.md` claims (and what `CLAUDE.md` will claim at step 5). **Tests live beside the code they cover.** If a doc says code is at `/backend` and it isn't, every brief that quotes the doc is wrong. |
| **Dependency manifests** | Version-pinned. Lockfiles **committed**. |
| **The check command** | Lint, typecheck, test, build. One entry point. Self-contained-green. |
| **Test harness** | Per layer, per the stack. Plus the isolation strategy above. |
| **Containers** | Whatever the check command needs, started by the check command. |
| **CI** | Runs the same check command. **Do not let CI and local diverge** — the moment they do, "works locally" becomes an argument instead of a fact. |
| **.gitignore** | Language defaults, build output, `.env`, local caches. **Not the harness's working dirs** — `harness-forge` (step 5) chooses those paths and adds them itself. You cannot know them yet, and guessing them means guessing wrong. |
| **Migrations** | Initialized, empty, at the path `STACK.md` names. |
| **Env** | `.env.example` committed, `.env` ignored. **No secrets in the repo, ever.** |

## Verify before returning (actually run these)

```bash
<check command>                                  # green from cold
<check command>                                  # green twice in a row (catches order-dependence)
git status --short                               # clean; no generated junk untracked
```

Then break it on purpose: introduce a deliberate failure — a failing assertion, a type error — and confirm the check command **actually goes red**. A check command that can't fail is the worst possible outcome, and it is a real one: everything passes, forever, and you trust it.

Undo the deliberate failure.

## Self-check

- [ ] Check command green from a cold clean clone. **Verified by running it.**
- [ ] Green twice in a row.
- [ ] Goes red when the code is broken. **Verified by breaking it.**
- [ ] Preconditions started by the command, not by a human.
- [ ] Test isolation implemented, or "no DB in tests" recorded explicitly.
- [ ] CI runs the same command as local.
- [ ] Directory layout matches what the docs will claim.
- [ ] Lockfiles committed; build output and `.env` gitignored; no secrets. (Harness working dirs are `harness-forge`'s job, not yours.)

## Return (~120 words)

- The check command, verbatim, and its cold-start result (pass count).
- Confirmation it goes red when broken. **Say that you actually tested this.**
- Test isolation strategy.
- Directory layout, one line.
- Anything the stack called for that you could not build, and why. Do not paper over it — `harness-forge` is about to emit gates that assume this floor exists.

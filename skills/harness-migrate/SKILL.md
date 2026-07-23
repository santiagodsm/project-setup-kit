---
name: harness-migrate
version: 0.1.0
description: "Convert an existing generated build harness — any retired tier, possibly mid-build — to the orchestrated design in place, carrying its state honestly. Inventories the old machinery, preserves project content and rulings, archives per-story artifacts, regroups the remaining backlog into dispatch units, rebuilds the gate manifest, and ends with harness-doctor. Use when the user says 'migrate the harness', 'convert this harness', 'upgrade the harness to the new tier', or 'move this build off the per-story model'."
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - Skill
  - ToolSearch
metadata:
  role: generator
  reads: [the old harness (CLAUDE.md, .claude/agents/**, .claude/skills/**, state file(s), per-story briefs and reviews), PRD.md, STACK.md, DESIGN.md, PLAN.md, templates/orchestrated/**, templates/gates/**, templates/PLACEHOLDERS.md]
  writes: [target repo CLAUDE.md, .claude/skills/**, PRD.md (TIER marker), PLAN.md (## Dispatch units section only), the state file (seeded from the old state), docs/_archive/**, .gitignore, the migration report]
---

# harness-migrate — convert a live harness without lying about its state

A project mid-build cannot be re-forged. `harness-forge` assumes a **virgin repo**: it stubs the state file empty and awaits a plan. A project with done stories, half-done stories, deviation ledgers, and design amendments has state that must **survive** the conversion — silently resetting it destroys the only record of what is true.

So you do what forge does — emit the orchestrated file set, resolved per `templates/PLACEHOLDERS.md` — **but you seed the state file from the old state instead of stubbing it.** That is the entire difference, and it is why this skill exists. Do not dispatch `harness-forge` and patch afterwards; a stub that briefly replaces real state is a window in which a resumed build starts from a lie.

Two boundaries, stated up front because everything else depends on them:

- **Migration is a harness-and-state operation only.** It does not touch source code, does not touch tests, and does not rewrite git history. If the old harness left the code mid-story, the code stays mid-story — the *state file* records that honestly, and the first new dispatch unit deals with it.
- **Honesty over tidiness.** A row promoted from mid-flight to `done` because "it was nearly there" is the migration equivalent of a silently wrong number. When in doubt, `partial`, with what remains owed written next to it.

One scope note: a `small`-tier harness needs no migration — the small tier survives the redesign unchanged. This skill converts harnesses built on the retired per-story tiers. If the marker already reads `small` or `orchestrated`, stop and say so; there is nothing to convert.

## The six steps

### 1. Inventory the old harness

Enumerate before you touch anything: `CLAUDE.md`, every `.claude/agents/*.md`, every `.claude/skills/*/SKILL.md`, the state file(s) — `glob`, do not assume names; older tiers used `docs/IMPL_PROGRESS.md` and a separate history file — plus `PLAN.md`, per-story working dirs (briefs, reviews, evidence), `.claude/settings.json` (a per-project `Notification` hook, if one was emitted, gets deleted in step 3 — it double-fires against the user's global hook), and **any author-added gates beyond the templates**. Diff the skill list against the template library to find those: a gate nobody generated is a gate somebody needed.

Record the inventory in the migration report as three columns you will fill in as you go: **keep · delete · archive**. A file you cannot classify is a file you have not read.

### 2. Carry the state across, honestly

Seed the new state file (`PROGRESS.md` at the repo root, in the orchestrated template's shape, with the five statuses `todo / wip / done / blocked / partial`) from the old one:

- **Done stays done.** Verified rows carry over with their commit hashes and dates intact.
- **Anything mid-flight becomes `partial`, with what remains owed spelled out** — a story half-implemented, a gate cycle interrupted midway, a fix in review. Never promoted, never dropped. The next agent to touch that area must be able to read the row and know exactly what is unpaid.
- **Deviation ledgers and design amendments are kept, verbatim.** They are rulings, not ceremony — deleting one re-opens a question somebody already paid to settle, and the next reader will re-derive it wrongly.

Then **archive the old state file(s) under `docs/_archive/`** — never leave them in place. Two files each claiming to be the state is a two-writer hazard in waiting, and the next session has even odds of reading the dead one.

### 3. Preserve the project, delete the machinery, archive the record

**Keep** (this is the project speaking, and it moves into the new harness):
- The **organising principle**, if the old `CLAUDE.md` has one load-bearing sentence at its head. If it does not, resolve one the way `harness-forge` does — from `PRD.md`'s What/Why and `DESIGN.md`'s invariants — and if nothing concrete supports one, emit a placeholder-free generic line and flag the gap in your report. Do not invent.
- The **invariant list — once, in `CLAUDE.md` only.** Old tiers restated it in multiple files; the restatements are deleted with the files that held them.
- **Stack-conditional gates that match `STACK.md`**, and `ASK_CONTRACT.md` + `notify.sh` (re-copy from the plugin root and `chmod +x` if the old ones were modified — they are copied verbatim, always).
- **Author-added gates**, re-wired as join-point tools the orchestrator invokes via `Skill` — never as per-story obligations. They were added because somebody found a real hole; the redesign changes *when* they run, not *whether*.

**Delete** (this is the retired machinery):
- Role agents (scoper / implementer / reviewer) and their skills, per-story orchestration skills (`resume-build` and kin), the evidence-file protocol, fix-story minting, any epic-gate chain, and the per-project `Notification` hook found in step 1.

**Archive, never delete** — old per-story artifacts (briefs, reviews, evidence files) move under `docs/_archive/`, gitignored if the originals were. They are the only record of *why early code looks the way it does*; a reviewer six units from now will need them to distinguish a deliberate ruling from an accident.

Then emit the orchestrated file set: copy `templates/orchestrated/**` minus `MANIFEST.md`, resolve every placeholder per `templates/PLACEHOLDERS.md`, confirm every path with `ls`, update `PRD.md`'s marker to `<!-- TIER: orchestrated -->`, and grep the output for `{{` — zero hits, same rule and same PLACEHOLDER-LITERAL exemption as forge. No `.claude/agents/` is created.

Rewire `.gitignore` to match: add the new reviews dir and the archive dir (if the artifacts it holds were gitignored before — committed history stays committed), and remove entries for working dirs that no longer exist. A gitignore full of dead paths is how the next author-added dir goes untracked-by-accident.

### 4. Regroup the remaining backlog into dispatch units

Write (or rewrite) `PLAN.md`'s `## Dispatch units` section covering every story not yet `done`. Stories themselves are untouched — they become the checklist inside a unit's brief, not dispatch boundaries. The merge rule, verbatim:

> If unit N's agent must re-read unit N−1's output to understand its own job, they are one unit.

Units are epic-sized, keyed on disjoint file trees, in dependency order. And the first new unit is fixed:

- **If the product is not yet runnable end-to-end, unit U0 is the walking skeleton** — the thinnest vertical slice over whatever already exists, before any further layer work. A mid-build migration usually inherits several finished layers and no running product; the skeleton is what surfaces the intent errors and integration gaps those layers are silently accumulating.
- If the product already runs end-to-end, say so in the report and number units from the dependency order directly.

`partial` rows from step 2 fold into whichever unit owns their file tree, with the owed remainder named in that unit's entry.

### 5. Rebuild the gate manifest

**Re-run `stack-decide` in RE-TIER mode.** The old manifest's tier columns and any `inline` rows predate the two-tier model, and the failure mode is exactly KD-015's: a migrated harness judged against a stale manifest is **gateless while reporting CLEAN** — three independent checks, all agreeing, all wrong. Then emit gates per the rebuilt manifest's `yes`/`no` column, exactly as forge does, including any author-added gates from step 3 that the manifest now covers.

### 6. Finish with harness-doctor, and report

Run `harness-doctor`, read its report, fix every BLOCKER. **Three rounds max**, then stop and report failure with the findings. **Never complete with an open BLOCKER** — a migration that hands over a broken harness has converted a slow build into a stopped one.

Write the migration report (in the reviews dir, gitignored): what was **kept**, what was **deleted**, what was **archived** (with paths), and every row **marked `partial`** with what remains owed.

## Return (~150 words)

- Old tier found → orchestrated. Inventory counts: files kept / deleted / archived.
- **State carried:** N rows done (unchanged), N marked `partial` — list each partial with one line of what remains owed. Confirm deviation ledgers and design amendments survived.
- The organising principle: carried from the old harness, newly resolved (with source), or generic + flagged as a PRD gap.
- **Dispatch units written:** count, and whether U0 is the walking skeleton or the product already ran end-to-end.
- Author-added gates re-wired as join-point tools, by name.
- Gate manifest: rebuilt via `stack-decide` RE-TIER; gates emitted / excluded.
- Archive location, and that no source code and no git history was touched.
- Placeholder grep: zero `{{` remaining.
- **`harness-doctor`: N blockers found, N fixed, final = CLEAN.** Report nothing else as success.
- The first command the user runs to resume building.

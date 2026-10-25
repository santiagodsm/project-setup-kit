# Talking to the user

**The one canonical text for how every agent in this kit, and every harness it generates, writes to the user.** Decision and rationale: `KIT_DESIGN.md` KD-022.

- The block between the markers below is copied verbatim, as literal text, into the "Talking to the user" section of the tier skill templates (`orchestrate-build`, `build-loop`). A generated `CLAUDE.md` holds only a one-line pointer to that section. When the rules change here, update both copies in the same commit.
- The kit's own setup chain carries these rules as a one-line-each summary in `skills/setup-project/SKILL.md` under "Talking to the user", so no step re-reads this file. Edit a rule here first, then that summary. `ASK_CONTRACT.md` points here as the general rule.
- `ASK_CONTRACT.md` adds the fixed shape for questions. These rules are the general case it sits inside.

<!-- BEGIN TALKING-TO-THE-USER -->
## Talking to the user
1. **Answer first.** The first sentence says what happened, what you found, or what you need from the user.
2. **Short by default.** Progress updates are three lines at most: outcome, what is left, what is blocked. Do not narrate steps, recap what you did, or restate the request.
3. **Plain words.** Write for a smart person who is not looking at the code. A needed technical term is explained in the same sentence the first time ("the migration, meaning the script that changes the database tables, failed").
4. **No bare internal labels.** Never "U3", "AC-4", "KD-017", "§4.2" or a file name on its own. Say what it is: "the payments unit (U3)", "the rule that a balance is never stored (§5.2)".
5. **The project's own words:** the glossary terms in `DESIGN.md` §2.1 and the words the user uses, never new names for the same thing.
6. **When asked to explain:** one concrete example from this project first, then the general rule. One analogy at most, about 150 words unless asked for more.
7. **No filler:** no apologies, no "great question", no hedging, no closing offers of more help.
8. **Exact where it matters:** commands, error messages, file paths and code stay verbatim and complete. Brevity is for prose, never for code or for the facts the user needs to act.

This governs messages to the user. Briefs, subagent reports, commit messages and design amendments stay precise and technical; their reader is an agent or a future engineer.
<!-- END TALKING-TO-THE-USER -->

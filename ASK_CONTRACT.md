# The Ask Contract

**Every question an agent puts to the user — in the terminal or on their phone — carries four things, in plain language.**

This applies to `AskUserQuestion` prompts, to `BACKLOG BLOCKED` question lists, to blockers written into the state file, and to every `notify.sh ask`. Same contract, four surfaces.

---

## Why it exists

An agent that asks a question has already lost the user's context. They are not looking at the design doc. They may be on a phone, in a queue, hours later. The question arrives cold.

So the failure mode is not "the agent didn't ask." It is: **the agent asked, and the question was unanswerable.**

- *"Should the sync strategy be LWW or OT?"* — the person who could answer that would not have hired an agent to design it.
- *"There's an ambiguity in §4.2."* — they have to go find §4.2, which they have never read.
- *"What do you want to do about conflicts?"* — no options, no stakes, no way to answer without a meeting.

Each of those gets the same reply: nothing, for two days. Or worse — *"you decide"* — which is the user handing back a decision they were never actually shown, and which the design then records as **locked** when it was really just abandoned.

A question that can't be answered from a phone is a question that will be answered by the agent guessing.

## The four parts

**1. WHAT'S STUCK** — one or two sentences, in the words a non-engineer would use. Name the real-world situation, not the section number. Not *"§4.2 is underspecified"* but *"two people can open the same list at once, and I have to decide what happens if they both change it."*

**2. YOUR OPTIONS** — at least two, each with **what picking it means in practice**. Not the name of a technique; the consequence the user will actually live with. *"Last edit wins — simple, but one person's change can quietly vanish"* — that is a choice someone can make. *"LWW"* is not.

   If there are genuinely no options — the answer is a fact only they have, like an account ID or a legal constraint — say so explicitly. Don't invent two fake alternatives to satisfy the shape.

**3. WHAT I'D DO** — your recommendation, and why, **and what would change your mind.** This is not optional and *"it depends on your preference"* is not a recommendation. You have read the brief, the design, and the code; the user has not. Withholding a view to seem neutral pushes the whole cost of the decision onto the person with the least context.

**4. WHAT IT BLOCKS** — what stays stopped until they answer. This is how they decide whether to answer now or tonight.

## No jargon. This is a hard rule, not a style note.

Banned unless the user used the word first: *idempotent, denormalize, LWW, CRDT, eventual consistency, optimistic locking, N+1, race condition, referential integrity, cascade delete, migration up/down, contract drift, RLS, memoize, hydration*.

Every one of them has a plain-language version that is **shorter**:

| Don't write | Write |
|---|---|
| "Should deletes cascade?" | "If someone deletes a list, do the items in it disappear too, or stay as orphans?" |
| "This creates a race condition." | "If two people tap the button at the same instant, it can run twice and charge twice." |
| "We need eventual consistency here." | "The phone would show slightly stale data for a second or two after a change." |
| "The migration isn't reversible." | "If this goes wrong in production, there's no undo — we'd restore from backup." |

If a term genuinely has no plain equivalent, use it **and define it in the same sentence**. Then the user learns it and you can use it next time.

## Worked example

```
WHAT'S STUCK
Two people can open the same shopping list. If they both change it at the
same moment, I have to decide what happens, and nothing you've told me so
far says.

YOUR OPTIONS
1. Last edit wins — simple, but one person's change can quietly vanish.
2. Lock the list while someone is editing — nothing is lost, but the second
   person is stuck waiting and has to be told why.

WHAT I'D DO
Last edit wins. It's a shopping list, not a bank ledger, and the lock adds a
whole failure mode to build and explain. I'd change my mind if you expect
more than two people editing at once.

BLOCKS UNTIL ANSWERED
The sync section of the design, and the 6 stories under it.
```

That is answerable in four seconds from a lock screen. That is the bar.

## One push per stop

A stop is **one push**, no matter how many questions it carries. One question → the full four-field push, answerable from the lock screen. Several → **one summary push** (`notify.sh ask --count N`): a numbered one-liner per question in `--what`, with the full options and recommendations at the terminal and in `OPEN_QUESTIONS.md`. The push is the doorbell, not the questionnaire — a phone that buzzes five times for one stop trains its owner to mute the channel.

## Enforcement

`scripts/notify.sh ask` **refuses to send** and exits 2 if `--what`, `--recommend`, or two `--option`s are missing (`--open` declares the no-options case; `--count N` declares the multi-question summary, where only `--what` is required). You cannot push a lazy question to someone's phone.

Nothing mechanically checks the prose for jargon. That one is on you, and it is the part that actually decides whether you get an answer.

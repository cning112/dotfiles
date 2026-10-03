---
name: harden
description: Drive the review–fix loop until a change has no blockers left — a fresh adversarial review each round, fixes that earn their own review, then polish and one last look.
disable-model-invocation: true
---

# Harden

Take a change to **no blockers** by looping: review cold → fix → review cold again. Two rules make or
break it. The reviewer is fresh every round, and the fixer is never the reviewer. And a fix is *new,
unreviewed code*: it does not inherit the verdict of the round that asked for it.

Adversarial review is a skill in its own right; this one drives it. Read
`~/.agents/skills/adversarial-review/SKILL.md` and hand its body to each reviewer **verbatim** as the
brief, rather than restating the method here and letting the two drift apart.

## 1. The loop

```
round 1: review the whole artifact  → blockers? → fix → gate green
round 2: review the fix diff        → blockers? → fix → gate green
   …                                → none     → polish → review the polish → done
```

Round 1 reviews the **uncommitted working tree**. If it already returns ACCEPT, there is nothing to
fix — go straight to step 6. Before each fix, record a fixed point to diff the next round against (a
commit, or a saved `git diff` if you would rather not commit mid-loop); it doubles as the revert point
for a fix that makes things worse.

## 2. Stop on no blockers, not on no risk

The exit condition is *no blockers*. **ACCEPT WITH RISK is a finished state** — the reviewer names a
risk, the author accepts it, the loop closes.

Chasing "no risk" never terminates: a cold reviewer can always name one more thing that could be
wrong, and every named risk would open another round. **Blockers gate a round. Nitpicks and risks do
not** — record them and finish.

## 3. A fresh reviewer every round

Dispatch a **new sub-agent** per round carrying only the artifact, the repo's standards, the gate
command, and the review method — never the conversation that produced the change, and **never the
previous round's findings**, which anchor a reviewer into confirming a list instead of reading cold.

If you cannot dispatch a sub-agent, say so before starting. Independence is the whole product here: a
loop where the author reviews their own fixes is theater, and should be labelled as such.

## 4. Fix the trigger, and prove it

A fix starts by **re-running the previous round's trigger** — the concrete input or state the blocker
named — and confirming it no longer fires. Reading the patch proves nothing.

- A blocker is withdrawn only on evidence its trigger does not fire, never on argument.
- **A fix is not done until the gate is green.** Quote the command and its result.
- Fix the cause the blocker names, not the line it points at. A fix that moves the failure is not one.
- Fix nothing the round did not name. Unrequested edits are unreviewed code, and they invalidate the
  diff the next round is about to read.

**Design blockers are not yours to fix.** When the category is Design — an unproven abstraction, a
missing alternative, a wrong seam — the remedy is a decision, not an edit. Stop and hand it back with
the choice laid out.

## 5. Narrow the scope, but re-open it on a seam

Round 1 reads the whole artifact. Later rounds read **the fix diff**: re-reading everything buys a
fresh crop of nitpicks and converges on nothing.

Except when a fix touches a **shared seam** — a helper, a signature, a contract, a config key, a
registration. Then re-open the whole artifact. A missing call site is invisible in a diff, and a
changed contract reaches consumers the diff never mentions.

## 6. Polish last, then look at it

Only once blockers are gone, run `/polish` — which must leave the gate green on both sides of its own
run and change no behaviour.

Then **review the polish**. It is not optional. Polish's hard rule is that which branch wins must not
change, and a reordered guard clause is a behaviour change in readability's clothing. The round is
cheap — narrow the hunt to structure and the two gate runs — but it is a round, because an edited
artifact invalidates the verdict that described it.

Polish lands in its **own commit**, apart from the behaviour fixes, so it can be read and reverted
alone.

## 7. When to stop

| Signal | Action |
| --- | --- |
| No blockers | Exit. Polish, review it, report. |
| Round cap reached (default **3**) | Stop and report what is still open. The cap is a runaway guard, not a target — most loops finish in two rounds. |
| The same blocker survives two fix attempts | Stop. That is a design problem wearing an implementation costume; another round will not move it. |
| A round returns only nitpicks and risks | Exit — that is convergence, not incompleteness. |

Rounds cost real tokens, so never start one you cannot say the purpose of.

## Output

- **Rounds**: one line each — revision reviewed, verdict, blockers, what closed them, gate command and
  result.
- **Final verdict**: the last round's verdict verbatim, with its risks.
- **Stopped because**: no blockers | round cap | repeated blocker | design decision needed.
- **For you**: the design decisions handed back, and the risks the loop recorded rather than fixed.

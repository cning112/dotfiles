---
name: polish
description: Make recently changed code more readable without changing what it does — flatten tangled logic and keep only the docstrings that earn their place.
disable-model-invocation: true
---

# Polish

Make recently changed code easier to read, without changing what it does. Two things are in scope:
the **structure** — tangled logic made straight — and the **prose** — docstrings cut to what earns
their place. Behaviour preservation is the contract: if output, errors, ordering, timing, or
the public surface changes, it is not polish.

**This skill edits and commits.** Most agents hide it from their own catalog, but OpenCode ignores
`disable-model-invocation` — so if you reached this skill without the user asking for it, stop and
confirm before the first edit, not merely before the commit. A pass another skill reaches (`harden`
§6 reads this file) counts as asked only if the user asked for that skill.

## 1. Establish the baseline first

Run the target repo's gate **before** editing — in these dotfiles `./test.sh`, bar 0 failed — and again
after.
Without a green baseline you cannot claim behaviour was preserved, only assume it. Quote both runs.

## 2. Bound the scope

Default to the working tree and the last few commits, not the whole repo: a repo-wide tidy is
unreviewable and unrevertable. If the whole repo is genuinely wanted, state the expected diff size
before starting. Performance is not polish: a "this would be faster" change needs a before/after
number, not a rewrite — leave it out.

## 3. Simplify the logic

The highest-yield work, and mostly about conditionals:

- **Guard clauses over nesting.** Invert the condition and return, continue, or throw early. A
  pyramid of nested `if`s becomes a linear list of rules read top to bottom.
- **Drop branches that carry no information.** The `else` after a `return`; the
  `if (x) return true else return false` shape; an accumulator assigned in every arm that just wants
  a return.
- **Name the condition.** A boolean the reader has to decode becomes a predicate in the domain's
  words — `order.isRefundable()` beats `o.status === 3 && !o.shipped && …`. The branch then states
  its intent instead of its arithmetic.
- **Decompose the arms.** When each branch is a paragraph, extract it: the conditional should show
  the *decision*, and the extracted names should show the *work*.
- **Map instead of cascade.** When every branch turns the same input into a different value, data
  beats four `else if`s.
- **Make the parallel arms parallel.** Inconsistent structure across symmetric branches forces the
  reader to diff them mentally.

Two hard rules, because this is where polish breaks code:

- **Which branch wins must not change.** Reordering overlapping tests silently changes behaviour —
  check the cases against each other, not only one at a time.
- **Conditions can have side effects.** A null guard, a lazy load, or an `await` inside a test means
  an "equivalent" rewrite is not equivalent. When in doubt, leave it.

## 4. Docstrings: brief, and only when they earn it

A docstring exists to carry what the name and signature cannot — a precondition, an invariant, a
unit, an error contract, a side effect, or the *why* behind a surprising choice. Anything else is
noise, and noise has a cost: it is read on every visit, and it drifts out of date.

- **Test it by deletion.** Remove the docstring and ask what a first-time reader loses. If nothing is
  lost, it should not exist. `/** Gets the user. */` above `getUser()` is a no-op, and so is a
  docstring that narrates the body line by line.
- **Be brief.** One line unless the content genuinely needs more. Length has to be earned by what the
  docstring carries, never by habit or by a template.
- **Keep the why.** The rationale for a rejected alternative, or for a choice that looks odd, is
  provenance — precisely what the deletion test protects.
- **Keep the contract.** Parameters, returns, errors and invariants stay, but only where a
  well-named signature does not already say them.

## 5. Leave alone what only looks redundant

- **Guards, copies, ordering, waits.** Defensive checks, explicit copies, deliberate sequencing and
  timeouts look removable until they are not. If you cannot say what breaks without it, keep it.
- **Clever is not simpler.** A denser one-liner that takes longer to read is a regression. A
  comprehension is for a simple transform, not a paragraph of logic.
- **Renames and reformatting.** They bury the real change and break blame for every consumer.
- **Tests.** Polishing a test must not reduce what it asserts. Confirm it still goes **red** without
  the fix — a shorter test that cannot fail is worse than a verbose one that can.

## 6. Land it separately

Polish goes in its own commit, apart from behaviour changes, so a reviewer can read it as pure
cleanup and revert it alone. A diff that mixes the two is neither. If the behaviour change is still
uncommitted, commit it first — asking the user if that change is theirs, and with an explicit message
(`git commit -m`: a bare `git commit` hands the message to the configured editor, so with no terminal
it can hang, and under `GIT_EDITOR=true`, as Claude Code sets it, it aborts on an empty message or
commits one git prefilled — a merge, cherry-pick or revert — unread). Splitting the hunks
afterwards means `git add -p`, which reads its answers from stdin, and at EOF stages nothing while
still exiting 0. Stage only the paths you polished, never `git add -A`. If the two genuinely cannot be
separated, say so instead of mixing them silently.

## Output

- **Gate**: the command, and its result before and after.
- **Changed**: one line per edit — what got simpler, and why behaviour is unchanged.
- **Left alone**: what looked redundant and stayed, with the reason.
- **Out of scope**: cleanup you found but did not do, because it would change behaviour.

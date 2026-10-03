---
name: polish
description: Tighten recently changed code for clarity without changing behaviour — simplify, de-duplicate, and condense docstrings, keeping the diff readable as pure cleanup.
disable-model-invocation: true
---

# Polish

Improve how the code reads without changing what it does. Behaviour preservation is the whole
contract: if output, errors, ordering, timing, or the public surface changes, it is not polish.

## 1. Establish the baseline first

Run the repo's gate **before** editing — in this repo `./test.sh`, bar 0 failed — and again after.
Without a green baseline you cannot claim behaviour was preserved, only assume it. Quote both runs.

## 2. Bound the scope

Default to the working tree and the last few commits, not the whole repo: a repo-wide tidy is
unreviewable and unrevertable. If the whole repo is genuinely wanted, state the expected diff size
before starting.

## 3. Condense what it says

A docstring carries what a first-time reader needs — what it does now, its parameters, returns,
errors, invariants. Cut restatement of the signature and of the code below it. Keep the *why*: the
rationale for a rejected alternative is provenance, not noise, and deleting it costs the next reader
most. Comments explaining non-obvious domain logic are in the same category — shortening those is
not polish.

## 4. Leave alone what only looks redundant

- **Guards, copies, ordering, waits.** Defensive checks, explicit copies, deliberate sequencing and
  timeouts look removable until they are not. If you cannot say what breaks without it, keep it.
- **Clever is not simpler.** A denser one-liner that takes longer to read is a regression. A
  comprehension is for a simple transform, not a paragraph of logic.
- **Renames and reformatting.** They bury the real change and break blame for every consumer.
- **Tests.** Polishing a test must not reduce what it asserts. Confirm it still goes **red** without
  the fix — a shorter test that cannot fail is worse than a verbose one that can.
- **Performance.** "This would be faster" needs a before/after number, not a rewrite, and several
  popular micro-optimizations are pessimizations: a list comprehension usually beats an append loop,
  and an enhanced `for` compiles to the same iterator it replaces. Out of scope here.

## 5. Land it separately

Polish goes in its own commit, apart from behaviour changes, so a reviewer can read it as pure
cleanup and revert it alone. A diff that mixes the two is neither.

## Output

- **Gate**: the command, and its result before and after.
- **Changed**: one line per edit — what got simpler, and why behaviour is unchanged.
- **Left alone**: what looked redundant and stayed, with the reason.
- **Out of scope**: cleanup you found but did not do, because it would change behaviour.

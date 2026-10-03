---
name: adversarial-review
description: Red-team a change before it ships — hunt the blockers the author is blind to, and never accept the author's own claims as evidence.
disable-model-invocation: true
---

# Adversarial review

Read the change **cold** as a hostile stranger who never saw the conversation that produced it: assume
the **design, the implementation, and the tests are wrong**, and make the artifact carry the burden of proof.

## 1. Work in a fresh context

Independence is structural, not an instruction to ignore what you already know. Dispatch to a **fresh
sub-agent** carrying only the raw artifact, this repo's standards, and the gate command — never the
conversation that produced the change, and never the author's summary of it, which is a claim (step 5).
If you *are* that sub-agent, work from the artifact alone.

## 2. Pin the artifact — the working tree, not `HEAD`

A pre-PR review happens *before* the commit: the default artifact is the **uncommitted working tree**.
`git diff BASE...HEAD` is commit-to-commit and reports "nothing to review" over exactly that state.

1. Take the fixed point from the user; otherwise resolve the remote default branch and take the
   merge-base. **Verify it resolves** (`git rev-parse --verify`) — never assume `origin/main`.
2. Collect all three, because no single command sees everything:
   - `git diff <merge-base>` — tracked edits, staged and unstaged.
   - `git status --porcelain` — **untracked files appear in no diff.** Read every one in full.
   - `git log <merge-base>..HEAD --oneline` — commit messages make claims too (step 5).
3. Empty artifact → say so and stop; that is a result, not a failure. Too large to read in full → name
   what you skipped, because a confident skim is worse than an honest partial.

## 3. Find this repo's standards and gate

A generic checklist is a no-op — you already look for null derefs and hardcoded secrets. The findings
only a repo-aware reviewer can make are the ones that block. Read what the repo documents (`CLAUDE.md`,
`CONTRIBUTING.md`, `docs/`), find its gate, and **run it** — in these dotfiles `./test.sh`, bar 0
failed; elsewhere, whatever that repo's own docs name, or if they name none, say so and name what you
ran instead — and confirm it can go red, or it is not a gate. The artifact may be config, not code:
the gate is whatever proves it still loads.

Report the verbatim command and result; an unverified "tests pass" is itself a finding.

## 4. Read the artifact cold

- **First-time reader**: every docstring states what the component does *now* — parameters, returns,
  errors, invariants.
- **Journey vs provenance**: flag "updated in round 2", "refactored because X failed", "temporary fix",
  scratchpads — but keep the rationale for a rejected alternative. Test: would a first-time reader be
  *slowed or misled*? Journey fails it; `we don't buffer here, unlike X, because Y` passes.
- **Dead weight**: commented-out code, debug prints, temp harnesses, unused deps, drive-by reformatting.
- **Scope, both ways**: everything the request did not ask for — and everything it *did* ask for that the
  diff omits. For every changed name, key, signature, or value, grep its other consumers: a missing
  registration or call site is invisible in a diff, and is the blocker this method otherwise cannot see.

## 5. Falsify before you accuse

State **the trigger** — the concrete input or state that fires each blocker — and why the code fails it.
No trigger → a nitpick, not a blocker. **"No blockers" is a legitimate verdict**; manufacturing one is the
failure this skill exists to prevent, and a false blocker costs more than a missed nitpick.

Then hunt the four a checklist never finds:

- **Unsubstantiated claims** — every "thread-safe", "handles timeouts", "backwards compatible" in a
  comment, docstring, or commit message that the diff does not establish.
- **Unsubstantiated design** — for every structural choice (a new abstraction, dependency, interface, or
  config surface) name the alternative it beat and the evidence. If neither the artifact nor the repo's
  docs supply that evidence, the design is unproven — say so.
- **Load-bearing tests** — for each test in the diff, mutate the line it claims to cover and confirm it
  goes **red**; a test that passes without the fix is not evidence. Then ask the question mutation
  cannot answer: does it assert what the code *should* do, or merely what it does now?
- **Test theater** — an assertion that cannot fail is not a test: `toBeDefined`, `is not None`, a bare type
  check, a mock asserted against its own configured value, a body with no assertion at all. Name the
  implementation change the test would catch; if there is none, it is theater. So is a test that never
  runs — a skipped marker, or a file the gate never collects.

Do mutation on a **throwaway copy**, never in the tree under review. The copy must carry the artifact:
a bare `git worktree add` checks out a commit, without the uncommitted edits or untracked files under
review. Copy the whole checkout instead (`rsync -a <repo>/ <tmp>/`, `.git` included). Then run the gate
on the **unmutated copy first**: a copy can fail where the original passes (in these dotfiles the
sync-drift check, because `$HOME` links point at the original checkout). A mutation is red only if it
adds a failure to that baseline or changes a baseline failure's output — diff the two runs, not their
counts. A check whose baseline failure hides the mutation cannot be tested in the copy: list it under
Unverified, never as theater. Report, don't touch; an edited artifact invalidates the verdict that
described it.

## 6. Hold the line on re-review

A blocker is withdrawn only when its **trigger is shown not to fire** — evidence, not argument. A fix is
verified by **re-running that trigger**, never by reading the patch; the fix then earns its own review.

## Output

### Verdict

- **Status** — ACCEPT | ACCEPT WITH RISK | REJECT, judged against the artifact's claims and this repo's
  standards, never against whether this was the *right* change (that is /code-review's Spec axis).
  **ACCEPT** = no blockers, nothing unverified hiding one. **ACCEPT WITH RISK** = no blocker, but a named
  risk remains — what could still be wrong, what would reveal it — and it is **unreachable while a blocker
  is open**: only the author can accept one, recorded rather than laundered. **REJECT** = a blocker.
- **Unverified**: what you could not check and why. Empty is fine; a silent gap is not.
- **Artifact**: merge-base → revision, files changed, gate command + observed result — or, when the
  repo names no gate, the substitute you ran, its result, and why it is not the repo's own.
- **Risk**: LOW | MEDIUM | HIGH | CRITICAL — from blast radius and reversibility, not finding count.

### Blockers

- **Location**: `path:line` at the reviewed revision, with the offending line quoted (deletions: cite the base).
- **Category**: Logic | Contract | Design | Security/Resource | Tests/Evidence | Unsubstantiated claim |
  Trajectory debris | Scope
- **Trigger**: the concrete input or state, and why the current code fails it.
- **Fix**: the exact change required.

### Nitpicks

Same shape, no trigger required. Never promoted into Blockers to look thorough.

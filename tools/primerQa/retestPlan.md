# Retest plan: skills against a repo that already has a primer

Purpose: measure whether the current repo-reader, pre-flight (v3) and primer-qa skills produce a better primer than the committed one, on a repo that was not used to design them. n=1 per side, so results are observations, not proof.

## Levels (reusable; update the numbers after each run)

| Level | What runs | Tokens (rough) |
|---|---|---|
| Lite | New pipeline through inventory, ledger and first deep reads; lint only; no judges | ~120k |
| Standard | Full recreation, then judges A and B on both primers, blind | ~450k |
| Full | Standard, plus a pro reviewer, a con reviewer and a third judge | ~550k |

Basis: generation ~200k (earlier estimate), judge A ~38k, judge B ~84k (`judgeBriefs.md`). Rule 10 applies: state the estimate, run the Lite part as a pilot, wait for approval before the rest.

## Steps (reusable)

1. Fixed inputs: the old primer's pinned SHA, its approved focus areas, and the user's background, answered fresh and logged verbatim in the scratchpad.
2. Isolation: a new session; a git worktree with the old primer file removed; the agent is told never to look for it.
3. Run the skills as written: repo-reader order of work, `preflight.md`, then write the primer in the worktree only.
4. Free checks: `primer-qa/scripts/lint.sh` with the ledger, word count, ledger reconciliation, API calls, tokens, number of corrections the user had to make.
5. Blind judges A and B on both primers: labels X and Y, random assignment, the judge is not told which is new. Judge B needs the user's approval for the named repo.
6. Scorecard: lint rule findings and leads; words; judge A scores 1 to 6; judge B accuracy and pointer accuracy; tokens; API calls; corrections.
7. Report differences by dimension. A gap inside the judges' own variation is not counted. List any trap that was hit.

Traps: a recreation that reads the old primer; skipped approval gates (so the focus list is fixed); judges that can tell which is new; calling a lower lint count better without checking the old primer's lint findings were real; fresh background answers differing from the old ones (note as noise).

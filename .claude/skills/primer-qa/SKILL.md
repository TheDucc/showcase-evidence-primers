---
name: primer-qa
description: Mechanical quality check for a primer in repoPrimers/ before it is shown to the user. Run it whenever a primer has just been written, revised or retrofitted, when the user asks to check, lint, QA or validate a primer, or before committing a primer change. It checks format, word cap, legend, files-line counts, pointers against the read ledger, and wording leads; it does not rewrite the primer or check claims against the code.
---

# primer-qa

Checks one primer for errors a script can find reliably, at no model cost and with no network. It reports; you decide and fix. It does not judge quality or fit to a posting, and it does not compare claims with the code (that needs repo reads and the user's approval; see `tools/primerQa/judgeBriefs.md`, brief B).

## Run it

```
<project-root>/.claude/skills/primer-qa/scripts/lint.sh <primer.md> [<ledger.tsv>]
```

Call it by absolute path and avoid `cd`. Pass the read ledger (`<scratchpad>/<repo>.<sha8>.reads.tsv`, see repo-reader) whenever it exists: without it the count and pointer checks are skipped, and the output says so. The ledger normally exists only in the session that wrote the primer, so run the lint before ending that session. Export `PRIMER_NAMES` (an extended regex of internal names that must not appear) from your shell profile to enable the `names` check; never type the names into a command.

A clean run checks format and ledger consistency only: it cannot see dead code, coverage-line counts, whether a cited range starts and ends on declaration boundaries, or terms a stranger would not know. Finish `preflight.md` pass 5 by hand.

Output lines are `<file>:<line>:<rule|lead>:<id>: <detail>`. A rule is an error; the exit code is 1 when any fires. A lead is a hint and never changes the exit code. Skipped checks are listed after the findings.

## Read the output

- Verify each finding against the primer before acting: the checks are deliberately simple and a finding can be a false alarm. A lead is a question, not a verdict.
- Fix real defects in the primer. Do not edit the primer to silence a check; if a check is wrong, change the check (below).
- If a lead is accepted as it stands, append `<!-- lint-ok: <id> -->` to that line.
- Report to the user what was found, what was fixed, and anything left as is, with the reason.

## Add or change a check

A real primer exposed a miss, or a check misfires. In `scripts/`:
1. A row in `rules.tsv`: `id`, `kind` (rule or lead), `version` (v2, or v3 if it needs the legend, files or terms lines), `needs` (primer, ledger or env), `what`, `why`.
2. A function `check_<id>` in `lint.sh` that calls `emit <line> <id> <detail>`.
3. At least one row in `cases.tsv` that applies a mutation and lists the ids that must fire (comma separated, `-` for none), plus a negative case for any legitimate variant it must not flag. Mutation operations are listed at the top of `selftest.sh`.
4. Run `scripts/selftest.sh`. It also fails if a rule has no case.

Prefer making a noisy lead narrower or removing it over tuning it. The template (`primerTemplate.md`) is the source of truth for header fields, legend, facet names and vocabularies; the lint reads it, so change the template rather than the lint when the format changes.

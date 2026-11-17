# Evidence-bound primers

A method for turning code I wrote into claims I can defend, with an AI assistant doing the reading and guardrails keeping it honest.

This repo is for reading, not running. It is the method extracted from a private working project.

## The problem

AI-written summaries of code overclaim. They say "designed" when the code was skimmed, treat a README as proof, and present remembered outcomes as fact. A resume built on that cannot survive an interview.

## The method

1. **Pre-pass.** Mechanical facts only: manifests, layout, commit dates. No judgment.
2. **Inventory.** List candidate focus areas and stop. A person approves before any deep read.
3. **Deep read.** Only the approved areas. Every file opened is logged in a read ledger.
4. **Primer.** One short document per repo. Each row names a facet, a depth tag, a pointer (repo path, lines and commit) and a source (code, declared, memory or inferred).
5. **Check.** A linter reconciles counts and pointers against the ledger. A fresh, independent reviewer then tries to fault the primer.
6. **Use.** The depth tag decides the verb a resume may use: deep allows "built", skimmed allows "worked with", declared allows only "documented", and memory counts only once confirmed.

The full rules are in [RULES.md](RULES.md) and the process is in [preflight.md](preflight.md).

## Worked examples

Three sanitized excerpts of real primers. Names are changed, commit pins are withheld and some rows are trimmed, so the pointers cannot be opened. Read them for the shape.

| Example | What it shows |
|---|---|
| [variant_forms.md](examples/variant_forms.md) | The basic shape on code I wrote: file counts, "none found" where nothing was found, unused code called unused, and "intent not recorded" instead of guessing. |
| [booking_portal.md](examples/booking_portal.md) | The same method on a different stack (WordPress, React, Vite), read in a management role: the role line limits the verbs to what the code shows, not personal authorship. |
| [feed_hub.md](examples/feed_hub.md) | A role line where the code's dates cannot be determined, so it says so, plus a facet-11 entry (context, options, decision, consequences). |

## What the guardrails caught

The linter's rule list ([rules.tsv](.claude/skills/primer-qa/scripts/rules.tsv)) records where each rule came from. Two examples:
- An early draft exceeded its own word cap, which became a rule.
- A retest found rows that cited commit messages as if they were code, which became a check that such rows say "declared".

## What is here

| Path | Contents |
|---|---|
| `.claude/skills/repo-reader/` | Read-only repository reader and the ledger scripts |
| `.claude/skills/primer-qa/` | The primer linter, with its own self-test |
| `tools/hooks/` | Pre-commit hook enforcing the dash rule |
| `tools/primerQa/` | Briefs for independent reviewers and a plan for retesting the method |
| `preflight.md`, `primerTemplate.md` | The process and the primer format |

## Limits

- The method was built and tested on a small number of repos, so the results are observations, not proof.
- The primers on my past work are not published. Full primers are available to interviewers on request.

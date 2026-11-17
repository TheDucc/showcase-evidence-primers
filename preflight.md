# Pre-flight checklist (v3)

Run once per repo before writing its primer. Version 3, revised after four real primers and three independent judge reviews of one primer. v1 was reviewed by an independent judge.

## Passes

1. **Mechanical pre-pass.** No judgment, no deep reading. Collect from the repo in place: dependency manifests, CI config, Dockerfiles, migration directories, top-level layout, commit date range. Exclude vendored and generated code (vendor, node_modules, build output) from every count.
2. **Claims to test (only when the user supplies background).** Turn each remembered statement into one line: the claim, the code evidence that would support it, and the pass that will look. Keep the list in the session scratchpad; it is not stored. While reading, mark each line supported (path @ SHA) or still memory. Supported lines become ordinary rows with a depth tag. Unsupported lines stay source: memory. Judgements ("better built") and outcomes ("improved rates") can never be supported by code; do not test them, and keep them out of claims.
3. **Inventory.** List candidate focus areas (specific directories or modules) with one line each on why they might matter. Stop and wait for approval.
4. **Deep read.** Only the approved focus areas. Nothing else is read in depth.
5. **Finish.** Before presenting: (a) the tree's file count, less any left-out vendored paths, equals deep + skimmed + declared + unread, from the read ledger (files left unread on purpose are the skipped ones); (b) each row's depth agrees with the coverage line and each pointer matches the ledger; (c) plain-words check: list the terms a stranger would not know, define them in the `terms` line, and describe internal names by capability (rule 8); (d) every count in the coverage line comes from `ledger.sh summary` or `ledger.sh count`, with the pattern quoted, not a hand count; (e) each deep row cites code that a live entry point reaches, or says it is dead (repo-reader, "Live or dead"); (f) each cited range starts and ends on declaration boundaries, confirmed with a command, or is marked "part".

## Facets

For each facet record evidence or "none found". "None found" is a valid answer; never pad. Use it only after looking; use the `unread` tag for areas that were not opened.

| # | Facet | Looks for | Usually filled by |
|---|---|---|---|
| 1 | Language and runtime | Languages, versions, era of the code | pre-pass |
| 2 | Framework and platform | Frameworks, CMS, major libraries, how extended, admin screens, hard dependencies named in manifests (info files, composer require) with the dependency's primer when one exists | pre-pass, then read |
| 3 | Data layer | Databases, schema, queries, caching, search | pre-pass, then read |
| 4 | Integrations and APIs | APIs consumed and exposed, data sync between systems | read |
| 5 | Architecture and system design | Structure, boundaries, migrations and modernization | read |
| 6 | Front end and UX | UI code, components, accessibility, client-side behavior | read |
| 7 | Hosting and delivery | Environments, deploys, CI/CD, configuration, version control and release practice (branches, tags, packaging) | pre-pass |
| 8 | Testing | Test types, coverage approach, test data. If none found, say where you looked (test folders, CI config, scripts) and note any manual QA seen in commit messages (declared) | pre-pass, then read |
| 9 | Observability, performance, operations | Logging, error handling, monitoring, tuning, production fixes | read |
| 10 | Security and data handling | Auth, access control, regulated data, secrets handling | read |
| 11 | Problem and solution | A hard problem and how it was solved | read, plus memory |
| 12 | Business context and scale | What the system was for, who relied on it, size and impact | memory |

Auth lives in facet 10 only. Facet 4 covers integration, not identity.

## Depth tags and what they allow

Each entry gets one tag. The tag limits the verb a submission document may use.

| Tag | Meaning | Claimable as |
|---|---|---|
| deep | Code read and understood | "built", "designed", "implemented" |
| skimmed | Present in the code, not studied | "used", "worked with" |
| inferred | Deduced, not seen | never claimable; may prompt interview prep |
| declared | Stated by the README, docs, or commit messages; the code was not read | only as "documented"; never "built" or "designed" |
| unread | Files exist but were not opened | not claimable |

Role defaults to "wrote". "Managed" applies only for periods the user confirms as Manager. Authorship is not verified from git.

## Source flag

Mark an entry `source: memory` when the code cannot show it: why a problem was hard, scale, users, business impact. Memory-sourced entries are claimable only after the user confirms them. Mark `source: inferred` where an entry is deduced; it is a Source value, never a Tag.

## Facet 11 shape

Context, options considered, decision, consequences. Keep each to a line or two.

## Conventions

- **Pointers** are remote URL, commit SHA, and full repo path; give a line range with a function or section name where one exists. Never a local path. A pointer must name a file that was actually read; evidence from the README alone is tagged `declared`.
- **Tag names** use the canonical public name of the technology, one spelling each (PostgreSQL, not Postgres). Check earlier primers before inventing a spelling.
- **Out of scope for primers:** mentoring, collaboration, and soft skills. Code cannot show them; they belong in a separate narrative layer.
- **Production fixes** are recorded in facet 9 or 11 as symptom, fix and pointer. Impact (users affected, time saved, cost) is memory only and must be confirmed before a document uses it.
- **Best-practice notes** (hardcoded secrets and similar) are mentioned in passing, not scrubbed, and are not a focus.

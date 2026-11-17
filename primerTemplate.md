# Primer template

Copy for each repo as `repoPrimers/<repoName>.md`. Rules for filling it are in `preflight.md`.

**Size cap: about 1,300 words**, counting the inline legend. Rows are pointers, not prose. When a facet needs more detail than fits, move it to `repoPrimers/<repoName>.<facet>.md` next to the primer and leave a one-line pointer in the table.

---

```
# <repoName>

repo:          <remote URL>
reviewed:      <commit SHA>, <date>
role:          wrote | managed, <period>; add "sole author" or "team" once the user confirms
involvement:   <first year>-<last year>
purpose:       <one line>
stack:         <languages, frameworks, datastores>
files:         <n> in the tree = <n> deep + <n> skimmed + <n> declared + <n> unread (<n> of them skipped on purpose, with reason)
coverage:      deep: <areas>; skimmed: <areas>; skipped: <areas, with reason>
focus:         <areas approved before the deep read>
skills:        <canonical tag> (deep|skimmed), <canonical tag> (deep|skimmed), ...
legend:        <copy the Legend section below, verbatim>
terms:         <words a stranger would not know, defined once; internal names described by capability>
```

## Legend (copy verbatim into each primer)

```
Depth: deep = code read and understood; skimmed = present, not studied; declared = stated in README, notes or commit messages, code unread; none found = looked, nothing there; unread = not opened. (In skills, depth is how deeply the code was read, not proficiency.)
Source: code = seen in code; declared = stated in project text; memory = from the engineer, not checkable ("confirmed" = the engineer confirmed it); inferred = deduced, not seen.
May say: deep = built, designed, implemented; skimmed = used, worked with; declared = documented; memory (confirmed) = describe plainly, no outcomes.
```

## Facets

| # | Facet | Tag | Depth | Pointer (path @ SHA) | Source |
|---|---|---|---|---|---|
| 1 | Language and runtime | | | | |
| 2 | Framework and platform | | | | |
| 3 | Data layer | | | | |
| 4 | Integrations and APIs | | | | |
| 5 | Architecture and system design | | | | |
| 6 | Front end and UX | | | | |
| 7 | Hosting and delivery | | | | |
| 8 | Testing | | | | |
| 9 | Observability, performance, operations | | | | |
| 10 | Security and data handling | | | | |
| 11 | Problem and solution | | | | |
| 12 | Business context and scale | | | | memory |

Write "none found" in the Tag cell for an empty facet. A facet may have several rows.

A Source cell may list several values when a row mixes evidence (`code, declared`); when it does, the pointer cell says which part rests on which. Memory-only content goes in its own sub-row (5b, 7b). "inferred" is a Source value, never a Tag. The Tag cell is the short name of the technology or capability. A pointer cell gives the full repo path, then lines and a function or section name: `src/Form/X.php lines 62-202 (__construct)`.

## Problem and solution entries (facet 11)

- **Context:**
- **Options considered:**
- **Decision:**
- **Consequences:**
- **Pointer:**
- **Source:** code | memory

## Best-practice notes

Optional. One line each, only if something turned up.

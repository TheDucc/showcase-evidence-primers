# Rules

The numbering is stable: `preflight.md` and `tools/primerQa/` refer to rules by number.

1. **No em dashes or en dashes anywhere.** Use hyphens, including in date ranges (2019-2024). A pre-commit hook in `tools/hooks/` enforces this.
2. **No claim in a submission document may outrun its evidence.** The depth tag on each row limits the verb a document may use (see `preflight.md`).
3. **Role defaults to "wrote".** "Managed" applies only for periods the engineer confirms. Ask, do not assume.
4. **Repos are read in place and never copied.** A primer points to code by repo, path and commit SHA.
5. **Deep reads only in approved areas.** Do an inventory pass first, list candidate focus areas, and wait for approval.
6. **Read only the repos the engineer names.** Listing or searching other repos, or looking for related code, needs explicit permission first.
7. **Hardcoded secrets or similar** are mentioned in passing as a best-practice note, never as a focus. Values are not copied into a primer.
8. **Language:** never adopt a target posting's terminology for a claim the evidence has not earned. Never use internal project or role names that a reader outside the original team cannot parse; describe the capability instead.
9. **Pull earlier work into a project** only when a primer needs it, and review it at pull time.
10. **Before any test that launches many sessions or agents,** state a usage estimate and run one pilot first; wait for approval.

# Unverified Bitbucket API notes

Claims from an independent review that have not yet been tested against a real repo. Verify before relying on one, then move it into SKILL.md.

- **Branch names containing "/"** may break `commits/<branch>`. Suggested workaround: take the branch's `.target.hash` from `refs/branches` and use that SHA in place of the name. Not tested; the first repo had no such branch.

Verified 2026-11-04: a full 40-character SHA works in `src/<sha>/` listings and file reads. A short SHA in `src/` paths is still untested.

Verified and promoted already (2026-11-02): `commits?include=<b>&exclude=<other>` returns only the commits unique to a branch; the `next` URL carries an opaque `ctx` and `page` cursor.
- **Commit hashes in single-commit requests.** In one test run a short hash (10 characters) failed on `commits/<hash>`, and a full 40-character hash returned a list of commits instead of one commit. Suggested workaround: read parent hashes from a commits list call and use full hashes. Seen once, not reproduced.

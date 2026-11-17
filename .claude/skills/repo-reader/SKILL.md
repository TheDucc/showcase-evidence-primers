---
name: repo-reader
description: Read a Bitbucket Cloud repository read-only through its REST API, without cloning, to build a primer about the user's past code. Use whenever the user names a Bitbucket repo or bitbucket.org URL to review, inventory, pin, skim, deep read, or write a primer for, or asks what is in a repo, its branches, tags, commit history, or files, even casually ("look at repo X", "run the pre-flight on X"). Reading anything beyond a repo the user has named, such as listing or searching other repos, needs the user's explicit permission first.
---

# repo-reader

Reads one named Bitbucket repo in place. Nothing is cloned or copied; the primer points at code by remote URL, commit SHA, and path. The process and facets live in `preflight.md` at the project root (`../../../preflight.md` from here); this skill covers only how to read safely and quickly.

## Use the helper

`bb.sh <path>` takes a path under `https://api.bitbucket.org/2.0/` and prints the response. It loads credentials itself, follows redirects over https only, and refuses any host other than api.bitbucket.org, so a stray URL cannot receive the token. Never read or print the credentials file; only `bb.sh` touches it. Never put credentials in a command.

Call the helper by its absolute path, `<project-root>/.claude/skills/repo-reader/bb.sh`, and avoid `cd`: in the main session a `cd` persists and moves the working directory away from the project root.

Define `H` (that path) and `R=repositories/<workspace>/<repo>` inside the same command that uses them; shell variables do not carry between calls. The workspace is usually the one on the `repo:` line of an earlier primer; if the repo may live elsewhere, ask, or run `"$H" user/workspaces` (it lists workspaces, not repos).

```
"$H" user/workspaces
"$H" "$R/refs/branches?pagelen=50"
"$H" "$R/refs/tags?pagelen=100"
"$H" "$R/commits/<branch>?pagelen=100"
"$H" "$R/commits?include=<branch>&exclude=<other>&pagelen=100"
"$H" "$R/src/<sha>/?pagelen=100&max_depth=10&fields=next,values.path,values.type,values.size"
"$H" "$R/src/<sha>/<path>"
```

One tree listing usually returns the whole tree; if the response has `next`, follow it (lesson 3).

Fetch each file once. Save it to the session scratchpad directory (the path given in the session's environment notes), then read, grep, and `jq` that local copy as often as needed. Do not re-request a file you already hold; every request counts against the rate limit (lesson 4). Save fetches under `<scratchpad>/<repo>/<short sha>/`, mirroring the repo path, so names cannot collide. Delete that subfolder when the pass ends (see Boundaries). Never save into the project or a repo directory.

## Helper scripts

Four scripts in `scripts/` do the repeated work. Run them by absolute path (`<project-root>/.claude/skills/repo-reader/scripts/<name>`). `refs.sh` and `tree.sh` call `bb.sh`; `scan.sh` and `ledger.sh` are local. None touches the credentials. Each header lists columns, limits and exit codes; `scripts/selftest.sh` checks `scan.sh`, `tree.sh` and `ledger.sh` offline.

- `refs.sh <workspace/repo> [pin]` prints the ref table: branches and tags with short SHA and date. With a pin (a branch or tag name without slashes, or a full SHA) it adds commits ahead of and behind the pin. Use a branch as the pin: on a tag row, `ahead_of_pin 0` means the pin contains that tag. It prints its request count on stderr.
- `tree.sh <workspace/repo> <full sha> <outdir>` lists the tree once, prints a per-directory size summary with token estimates, and seeds the read ledger. Make `<outdir>` the scratchpad root, not the fetch folder, which is deleted at the end of a pass; it refuses a folder inside the project. Its notes report directories past the depth limit and non-file entries; put those in the coverage line. A truncated run exits 3 and writes `*.reads.PARTIAL.tsv`; do not reconcile counts against it.
- `scan.sh <folder>` scans fetched files for secret-like and identifier-like strings and reports file, line and pattern name, never the value. For internal host or product names, the user exports `SCAN_HOST_RE` (a regex) from their shell profile; do not type the names into a command or store them in the repo. Hits are leads, and no hits is not proof that nothing is there.
- `ledger.sh summary <ledger>` prints the primer's `files:` line (`<n> in the tree = a deep + b skimmed + c declared + d unread`, the form `primer-qa` parses) and a directory by tag table. `ledger.sh count <ledger> '<ERE on path>'` counts a category by tag (for example `'^src/Controller/'`). Copy the numbers into the `files:` and coverage lines and quote the pattern when you cite a category count. Read-only. It warns on duplicate paths (the last row wins, as in `primer-qa`), unknown tags, short rows and PARTIAL ledgers.

## Lessons from the first read (why the rules exist)

1. **Pin every read to a SHA.** `src/HEAD` resolves to the repo's default branch, which may be abandoned. On the first repo it was a stale branch, so the tree, manifests, and README read were from the wrong version. A branch name in the path (`src/master/...`) is the same mistake: it can be stale too. Read branches and tags first, then read files at the pinned commit's SHA. Take the full 40-character SHA from the commit list (`.hash`) and use it in `src/` paths; shorten it only for display. A short SHA in a `src/` path is untested; `references/unverified.md` records a short hash failing on `commits/<hash>`.

   Pinning is the user's choice, informed by a ref table. Before proposing a pin, build the table: every branch tip and every tag, each with SHA and date, and for each tag the branches that contain it (use `commits?include=<branch>&exclude=<tag>` to find commits past a tag). Tags matter on their own: in Composer-managed projects they are how consumers pull a specific version, so keep all tags in the table, not only the newest. A branch deploy and a tag deploy can both be real for the same repo (for example, sites built on different versions, or code repurposed for a minor need), so a tag never rules out a branch as the pin.

   State the pin's relation to the tags in the primer: "pin = <sha>, <n> commits after tag <x>" or "pin is tag <x>". Say "after the last tag", never "unreleased". Whether a branch or tag was deployed is `source: memory` unless a consumer manifest was read, and reading one in another repo needs the user's permission. Per-tag diffs (`commits?include=<tag>&exclude=<previous tag>`) are the preferred way to date and size the work per version.
2. **Scope commit lists.** Unscoped `/commits` mixes all branches. `commits/<branch>` includes everything reachable from that branch, including merged-in history. For the commits unique to a branch, use `commits?include=<branch>&exclude=<other>`. Branch names containing a slash are not yet verified; see `references/unverified.md`.
3. **Pagination.** A response with a `next` field has more pages. Pass the whole `next` URL to `bb.sh`. It carries an opaque cursor; never build `page=` yourself.
4. **Stay inside the rate limit.** Atlassian caps repository API calls at roughly 1,000 per hour per user, and a 429 means stop and tell the user. One recursive listing (`max_depth` with `fields=`) beats a loop of per-file calls, and it shows the real layout, so do not probe guessed directory names.
5. **Parse with `jq`**, not inline `python3 -c`. Nested quotes broke once. Example: `"$H" "$R/refs/tags" | jq -r '.values[] | [.name, .target.date[:10]] | @tsv'`.
6. **Tags and manifests declare; they do not prove.** A tag or `info.yml` shows what the code says, not what ran in production. Mark deployment and reuse claims `source: memory`.
7. **Report what the code does and what it earns.** For each area read, state what the code does, its depth tag, and the verbs that tag allows. Skip defect and quality commentary: the project builds an evidence base and is not a code review. Facet answers, including "none found" with where you looked (facet 8) and production fixes (facet 9), are evidence, not commentary; record them. Mention disabled or unused code only where it limits a claim. The exception is project rule 7 in `RULES.md` (secrets, credentials, internal hostnames), noted in passing as best-practice notes.

## Order of work

1. Refs: branches and tags (`refs.sh`). Choose the pinned SHA (lesson 1).
2. Tree at that SHA: run `tree.sh`, which lists the tree once and seeds the read ledger. Name only files that appear in that listing; never guess a path. Leave identical copies out of any count too; the script already leaves out vendored and generated paths.
3. Manifests and README only (the mechanical pre-pass). Also record the delivery facts: whether `composer.json` at the pin declares a `type` (for example `drupal-module`), a `version` field, or repository references, and whether the tags follow semantic versioning.
4. Commit messages per branch. Note any long gap between commit dates; a silence of months is worth a line in the primer.
5. Stop. List candidate focus areas and wait for the user to approve before any deep read.

## Planning passes and reading

- Estimate each pass from the `tree.sh` summary: roughly bytes divided by 4 tokens per file, with binary files (judged by extension) counted as 0. It is a lower bound: it leaves out tool overhead and rereads, and minified or non-ASCII files differ. Skip binary and minified files. State the estimate before each pass; for the first deep read in a repo, start with the smallest file as a pilot. Passes stay inside approved focus areas (rule 5); rule 10's approval applies when a pass launches multiple sessions or agents.
- A skim (purpose, structure, key names) earns at most the `skimmed` tag; `preflight.md` sets which verbs each tag allows.
- Read economically: get a function outline with `grep -nE 'function|class'`, then read the ranges for the approved focus area. A comment-stripped listing can help you find your way (recipe: the ecosystem note), but it also hides live lines that start with a comment marker and any commented-out calls, so never take an outline from it and read every range you cite raw. Never strip comment lines from manifests, routing, services or other config; read those raw. Pointers cite lines of the raw file. Read raw where comments carry meaning, as in notes and README files.

## Ecosystem notes

`references/<ecosystem>.md` holds recipes for one stack (commands, file patterns, where entry points are declared). Read the one that matches the repo; today only `php-drupal.md` exists. For a stack with no note, find the entry points from its manifest or README and say in the primer that you did. Add a note the first time a stack needs one.

## Live or dead

Lesson 7 says to mention disabled code where it limits a claim; this is how to find it. Before the first deep read, write the repo's entry-point list into the pass report as `path:line, live|commented` (the places a stack declares what runs: routes, commands, scheduled jobs, plugins registered by config or annotation; the ecosystem note says where). A row may say a handler runs only if it is on that list as live, or if you cite a live caller. Also read install and update scripts for commented-out calls, and in each range you cite look for statements after an unconditional `return`, `throw`, `exit` or `die`. Record dead code by writing `<a>-<b> dead` in that file's `lines` entry, one per range, and explain it in the primer row. Dead code can back "wrote", never "runs" or "enforces".

## Read ledger

Keep the ledger at `<scratchpad>/<repo>.<short sha>.reads.tsv`, beside the fetch folder and not inside it. Columns: `path, bytes, tag, lines, name, pass, reason`. `tree.sh` seeds it with one row per file, tag `unread`, and leaves vendored and generated paths out. Leave identical copies out too, and record all left-out paths in the coverage line as one count per pattern.

Tags are the ones in `preflight.md`: deep, skimmed, declared, unread. A file left unread on purpose (empty, an unused copy, a stock template, a data file) keeps `unread` and gets a `reason`; the primer calls these skipped. `declared` is for project text read as a source of declared facts (README, notes, manifests). Commit-message evidence is not a file row, so cite the commit SHA in the primer. A file read in several ranges keeps one row: raise its tag to the highest used and list each range in `lines`, separated by `;`. (`tree.sh` seeds one row per file and `primer-qa` keys the ledger by path and keeps the last row, so a second row would replace the first.)

The ledger is why the primer's numbers agree: the coverage line, each row's depth, each pointer and the `files:` line come from it. Before deleting the fetch folder at the end of a pass, list in your pass report each file fetched but not planned and each planned file not fetched, with a reason for each, or write "fetched = planned". Build the `files:` line and every count in the coverage line from `ledger.sh summary` and `ledger.sh count`, not by hand. Before writing, check that the rows add up to the tree's file count (less the left-out paths) and that unread files are named in the coverage line (`preflight.md` pass 5).

Pointers use the full repo path from the tree listing, never a bare filename, and a file's line ranges must agree everywhere it is cited. If a read cannot finish in one session, stop and ask the user where the ledger should live before the session ends; the scratchpad does not survive it.

Cite a function or class from its signature line to its closing brace at the signature's indent (or, in a language without braces, its last indented line); a signature can take several lines, and a docblock above may be included if you do it everywhere. Confirm the end line with a command, for example `awk 'NR>S && /^<indent>}/ {print NR; exit}' file` with the start line S, instead of using the span you happened to read. If you read only part, cite the part and write "part" in the pointer cell.

To update a ledger row, use this guarded form (values pass through the environment, because `awk -v` interprets backslashes). It never lowers a tag (order unread < declared < skimmed < deep), rejects an unknown tag, and fails unless exactly one row matches; the ledger is replaced only on success:

```
P='src/Foo.php' T=deep R='39-173' awk -F'\t' -v OFS='\t' 'BEGIN{split("unread declared skimmed deep",o," ");for(i in o)r[o[i]]=i;if(!(ENVIRON["T"] in r)){print "bad tag" > "/dev/stderr";exit 2}} NR>1&&$1==ENVIRON["P"]{f++;if(r[ENVIRON["T"]]>r[$3])$3=ENVIRON["T"];if(ENVIRON["R"]!="")$4=($4==""?"":$4";")ENVIRON["R"]} {print} END{if(f!=1){print "matched " f+0 " rows" > "/dev/stderr";exit 1}}' ledger.tsv > ledger.new && mv ledger.new ledger.tsv
```

## Boundaries

- Read only repos the user names. Listing or searching other repos, or looking for related or reused code, needs the user's explicit permission first, even when the code looks like a starting point for something else.
- Do not open data files that may hold real identifiers (CSV exports, user lists) or stock config templates. Say that you skipped them.
- Run `scan.sh` on the fetch folder before deleting it, and report hits by file, line and pattern; do not print matched lines or values. If hardcoded secrets or internal identifiers appear, mention them as a best-practice note and do not copy them into a primer.
- Delete the `<scratchpad>/<repo>/` fetch folder when the pass ends and confirm it is gone. The ledger and the claims list (`preflight.md` pass 2) stay until the primer is presented; the end of the session removes the scratchpad anyway. To verify a later finding, fetch that file again at the pinned SHA (one request each), then run `scan.sh` on it and delete it again.

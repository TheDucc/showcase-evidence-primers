#!/usr/bin/env bash
# ledger.sh summary <ledger>   |   ledger.sh count <ledger> <ERE on path>
# Read-only helper for the read ledger (columns: path bytes tag lines name pass reason). Local, no network, never edits the ledger.
# Counting rule matches primer-qa's lint.sh: one entry per distinct path, the LAST row for a path wins (duplicate paths are
# warned about on stderr). CR characters are removed. A tag other than deep, skimmed, declared, unread is warned about and
# counted as 'other'. A ledger named *.PARTIAL.tsv (a truncated listing) is warned about: do not reconcile counts against it.
# summary: first line is the primer's files line, '<n> in the tree = a deep + b skimmed + c declared + d unread' (the format
#   lint.sh parses; add '(details...)' after it yourself), then a directory by tag table (directory = first two path components,
#   as in tree.sh).
# count: how many entries have a path matching the ERE, split by tag. For category counts in the coverage line (for example
#   '^src/Controller/'); quote the pattern when you cite the number. An empty or invalid pattern is rejected.
# Exit codes: 0 ok, 1 usage or empty ledger, 2 bad pattern.
set -euo pipefail
usage() { echo "usage: ledger.sh summary <ledger> | ledger.sh count <ledger> <ERE on path>" >&2; exit 1; }
[ $# -ge 2 ] && [ -f "$2" ] || usage
L="$2"
case "$L" in *PARTIAL*) echo "ledger.sh: warning: PARTIAL ledger (truncated listing); do not reconcile counts against it" >&2 ;; esac
rows="$(tail -n +2 "$L" | tr -d '\r' | grep -c . || true)"
[ "$rows" -gt 0 ] || { echo "ledger.sh: $L has no file rows" >&2; exit 1; }
# normalise: last row per path, CR removed; emits 'path<TAB>tag'
norm() {
  tail -n +2 "$L" | tr -d '\r' | awk -F'\t' '
    NF<3 || $1=="" { print "ledger.sh: warning: skipped a row with fewer than 3 columns: " $0 > "/dev/stderr"; next }
    { if ($1 in seen) { dup++; print "ledger.sh: warning: duplicate path " $1 " (last row wins)" > "/dev/stderr" } else { order[++n]=$1 }
                      seen[$1]=1; tag[$1]=$3 }
    END { for (i=1;i<=n;i++) print order[i] "\t" tag[order[i]] }'
}
case "$1" in
  summary)
    [ $# -eq 2 ] || usage
    norm | awk -F'\t' '
      { tg=$2; if (tg!="deep" && tg!="skimmed" && tg!="declared" && tg!="unread") { print "ledger.sh: warning: unknown tag \"" tg "\" for " $1 > "/dev/stderr"; tg="other" }
        n++; t[tg]++; k=split($1,a,"/"); d=(k>=3)?a[1] "/" a[2]:(k==2?a[1]:"(root)"); c[d,tg]++; ds[d]=1 }
      END { printf "%d in the tree = %d deep + %d skimmed + %d declared + %d unread", n, t["deep"], t["skimmed"], t["declared"], t["unread"]
            if (t["other"]>0) printf "   (# %d more with an unknown tag, not in the sum)", t["other"]
            printf "\n"; print "dir\tdeep\tskimmed\tdeclared\tunread\tother"
            for (d in ds) printf "%s\t%d\t%d\t%d\t%d\t%d\n", d, c[d,"deep"], c[d,"skimmed"], c[d,"declared"], c[d,"unread"], c[d,"other"] }' \
      | { IFS= read -r a; echo "$a"; IFS= read -r b; echo "$b"; sort; } ;;
  count)
    [ $# -eq 3 ] || usage
    [ -n "$3" ] || { echo "ledger.sh: empty pattern" >&2; exit 2; }
    PAT="$3" awk 'BEGIN { "" ~ ENVIRON["PAT"] }' 2>/dev/null || { echo "ledger.sh: invalid pattern: $3" >&2; exit 2; }
    norm | PAT="$3" awk -F'\t' '
      $1 ~ ENVIRON["PAT"] { n++; tg=$2; if (tg!="deep" && tg!="skimmed" && tg!="declared" && tg!="unread") tg="other"; t[tg]++ }
      END { printf "%d match: %d deep, %d skimmed, %d declared, %d unread", n, t["deep"], t["skimmed"], t["declared"], t["unread"]
            if (t["other"]>0) printf ", %d other", t["other"]
            printf "\n" }' ;;
  *) usage ;;
esac

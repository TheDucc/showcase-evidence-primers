#!/usr/bin/env bash
# tree.sh <workspace/repo> <full sha> <outdir>
# Read-only. Lists the repo tree at one commit with bb.sh, prints a size summary, and seeds the read ledger.
# Summary (stdout, TSV): dir files bytes est_tokens, grouped by the first two path components, then TOTAL,
# then '#' notes (excluded paths, binary files, coverage gaps, ledger path). Warnings also go to stderr.
# Ledger: <outdir>/<repo>.<sha8>.reads.tsv with columns path bytes tag lines name pass reason; every file starts as 'unread'.
# If the listing was cut off (page limit), the ledger is named <repo>.<sha8>.reads.PARTIAL.tsv and the exit code is 3;
# do not reconcile counts against a PARTIAL ledger.
# Coverage gaps, reported as notes: directories at the max_depth 10 limit whose contents were not listed, and
# entries that are neither files nor directories (submodules, links). Files inside them are not in the counts.
# est_tokens is bytes / 4 for text files and 0 for binary ones, judged by extension (a lower bound; see SKILL.md).
# Left out of the ledger and counted in the notes: vendor, node_modules, .git, dist, build and *.min.js/css paths.
# Control characters in paths are replaced with '?'.
# outdir must exist and must be outside the project (use the session scratchpad root).
# Selftest (offline, stubbed bb.sh): scripts/selftest.sh.
set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
H="${TREE_BB:-$here/../bb.sh}"   # TREE_BB exists only for selftest.sh
project="$(cd "$here/../../../.." && pwd -P)"
MAX_PAGES="${TREE_MAX_PAGES:-30}"

die() { echo "tree.sh: $*" >&2; exit 1; }

[ $# -eq 3 ] || die "usage: tree.sh <workspace/repo> <full sha> <outdir>"
[[ "$MAX_PAGES" =~ ^[1-9][0-9]{0,3}$ ]] || die "TREE_MAX_PAGES must be a positive integer"
repo="$1"; sha="$2"; outdir="$3"
[[ "$repo" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]*/[A-Za-z0-9_][A-Za-z0-9_.-]*$ ]] || die "repo must look like workspace/repo"
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || die "sha must be a full 40-character SHA"
[ -d "$outdir" ] || die "outdir does not exist: $outdir"
out_real="$(cd -- "$outdir" && pwd -P)"
case "$out_real/" in
  "$project"/*) die "outdir must be outside the project; use the session scratchpad" ;;
esac

name="${repo#*/}"
ledger="$out_real/$name.${sha:0:8}.reads.tsv"
partial="$out_real/$name.${sha:0:8}.reads.PARTIAL.tsv"
[ ! -e "$ledger" ] && [ ! -e "$partial" ] || die "a ledger for this commit already exists in $out_real; remove it or use another outdir"

R="repositories/$repo"
max_depth=10
path="$R/src/$sha/?pagelen=100&max_depth=$max_depth&fields=next,values.path,values.type,values.size"
listing=""; unexpanded=0; other=0; pages=0
while [ -n "$path" ] && [ "$pages" -lt "$MAX_PAGES" ]; do
  out="$("$H" "$path")" || die "request failed: tree listing"
  jq -e '.values | type == "array"' <<<"$out" >/dev/null || die "unexpected response (no values list)"
  chunk="$(jq -r '.values[] | select(.type=="commit_file") | [(.path|gsub("[\u0000-\u001f]";"?")), (.size // 0)] | @tsv' <<<"$out")"
  [ -z "$chunk" ] || listing+="$chunk"$'\n'
  unexpanded=$((unexpanded + $(jq --argjson d "$max_depth" '[.values[] | select(.type=="commit_directory" and ((.path|split("/")|length) >= $d))] | length' <<<"$out")))
  other=$((other + $(jq '[.values[] | select(.type!="commit_file" and .type!="commit_directory")] | length' <<<"$out")))
  path="$(jq -r '.next // empty' <<<"$out")"
  pages=$((pages + 1))
done
truncated=no
[ -z "$path" ] || truncated=yes

set -o noclobber
tmp="$(mktemp "$out_real/.rows.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
printf 'dir\tfiles\tbytes\test_tokens\n'
printf '%s' "$listing" | ROWS_FILE="$tmp" awk -F'\t' -v OFS='\t' '
  BEGIN { rows = ENVIRON["ROWS_FILE"] }
  NF < 2 { next }
  {
    p = $1; b = $2 + 0; ex = ""
    if (p ~ /(^|\/)vendor\//) ex = "vendor"
    else if (p ~ /(^|\/)node_modules\//) ex = "node_modules"
    else if (p ~ /(^|\/)\.git\//) ex = "git"
    else if (p ~ /(^|\/)dist\//) ex = "dist"
    else if (p ~ /(^|\/)build\//) ex = "build"
    else if (p ~ /\.min\.(js|css)$/) ex = "minified"
    if (ex != "") { excl[ex]++; exb[ex] += b; next }
    bin = (tolower(p) ~ /\.(png|jpe?g|gif|ico|webp|bmp|pdf|zip|gz|tgz|tar|woff2?|ttf|eot|otf|mp3|mp4|mov|class|jar|so|dll|exe)$/)
    n = split(p, parts, "/")
    if (n == 1) dir = "(root)"; else if (n == 2) dir = parts[1]; else dir = parts[1] "/" parts[2]
    files[dir]++; bytes[dir] += b
    if (!bin) { t = int(b / 4); tok[dir] += t } else nbin++
    print p, b, "unread", "", "", "", (bin ? "binary" : "") >> rows
    tf++; tb += b; if (!bin) tt += int(b / 4)
  }
  END {
    for (d in files) print d, files[d], bytes[d], tok[d] + 0 | "LC_ALL=C sort -t \"\t\" -k1,1"
    close("LC_ALL=C sort -t \"\t\" -k1,1")
    print "TOTAL", tf + 0, tb + 0, tt + 0
    for (e in excl) print "# excluded " e ": " excl[e] " files, " exb[e] " bytes (not in the ledger)"
    if (nbin > 0) print "# binary files: " nbin " (est_tokens 0, reason=binary in the ledger)"
  }'

target="$ledger"; [ "$truncated" = no ] || target="$partial"
{ printf 'path\tbytes\ttag\tlines\tname\tpass\treason\n'; LC_ALL=C sort -t$'\t' -k1,1 "$tmp"; } > "$target"

if [ "$unexpanded" -gt 0 ]; then
  echo "# NOTE: $unexpanded directories at the depth limit ($max_depth) were not expanded; files inside them are missing from the counts"
  echo "tree.sh: $unexpanded directories at the depth limit were not expanded" >&2
fi
if [ "$other" -gt 0 ]; then
  echo "# NOTE: $other entries that are neither files nor directories (submodules or links) are not in the counts"
  echo "tree.sh: $other non-file entries not counted" >&2
fi
echo "# ledger: $target ($(( $(wc -l < "$target") - 1 )) rows)"
if [ "$truncated" = yes ]; then
  echo "# WARNING: listing truncated after $MAX_PAGES pages; counts are incomplete (TREE_MAX_PAGES); ledger is PARTIAL"
  echo "tree.sh: listing truncated after $MAX_PAGES pages; wrote a PARTIAL ledger" >&2
  exit 3
fi

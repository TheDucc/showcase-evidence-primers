#!/usr/bin/env bash
# refs.sh <workspace/repo> [pin]
# Read-only ref table for one Bitbucket repo, built only from bb.sh calls.
# Prints TSV: kind name sha date ahead_of_pin pin_ahead shares_history
#   ahead_of_pin   commits in the ref that are not in the pin
#   pin_ahead      commits in the pin that are not in the ref (for a tag: commits after it)
#   shares_history yes; no = the ref has a root commit the pin lacks (unrelated or merged-in history); unknown = list
#                  truncated; pin = this is the pin
# pin: a branch or tag name without slashes, or a full 40-character SHA. Without a pin, only the ref list is printed.
# A count ending in + means the first pages did not cover the whole range.
# Cost: 1 request per page of branches and tags, then up to 10 per compared ref (2 comparisons, up to 5 pages each);
# the total is printed on stderr. At most REFS_MAX_COMPARE (default 20) distinct commits are compared.
# Live test only: it needs the API, so scripts/selftest.sh does not cover it.
set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
H0="$here/../bb.sh"
cnt="$(mktemp)"
trap 'rm -f "$cnt"' EXIT
bb() { printf x >> "$cnt"; "$H0" "$@"; }   # counts requests, also from subshells
MAX_PAGES=10
MAX_COMPARE="${REFS_MAX_COMPARE:-20}"

die() { echo "refs.sh: $*" >&2; exit 1; }
[[ "$MAX_COMPARE" =~ ^[0-9]{1,4}$ ]] || die "REFS_MAX_COMPARE must be a non-negative integer"

[ $# -ge 1 ] && [ $# -le 2 ] || die "usage: refs.sh <workspace/repo> [pin]"
repo="$1"; pin="${2:-}"
[[ "$repo" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]*/[A-Za-z0-9_][A-Za-z0-9_.-]*$ ]] || die "repo must look like workspace/repo"
if [ -n "$pin" ]; then
  [[ "$pin" =~ ^[A-Za-z0-9_.-]+$ ]] || die "pin must be a name without slashes, or a full SHA (slash names are untested)"
fi
R="repositories/$repo"

# Print every element of .values across pages, one compact JSON object per line.
fetch_values() {
  local path="$1" page=0 out
  while [ -n "$path" ] && [ "$page" -lt "$MAX_PAGES" ]; do
    out="$(bb "$path")" || die "request failed: ${path%%\?*}"
    jq -e '.values | type == "array"' <<<"$out" >/dev/null || die "unexpected response (no values list): ${path%%\?*}"
    jq -c '.values[]' <<<"$out"
    path="$(jq -r '.next // empty' <<<"$out")"
    page=$((page + 1))
  done
  [ -z "$path" ] || echo "refs.sh: more than $MAX_PAGES pages; list truncated" >&2
}

fields='next,values.name,values.target.hash,values.target.date'
to_rows() { # $1 = kind, stdin = JSON lines
  jq -r --arg kind "$1" '[$kind, (.name|gsub("[\u0000-\u001f]";"")), .target.hash, .target.date[:10]] | @tsv'
}
# Capture each listing in a variable first so a failed request stops the script (a process substitution would not).
branch_json="$(fetch_values "$R/refs/branches?pagelen=100&fields=$fields")"
tag_json="$(fetch_values "$R/refs/tags?pagelen=100&fields=$fields")"
rows=()
while IFS= read -r line; do rows+=("$line"); done < <(to_rows branch <<<"$branch_json")
while IFS= read -r line; do rows+=("$line"); done < <(to_rows tag <<<"$tag_json")

pin_sha=""
if [ -n "$pin" ]; then
  if [[ "$pin" =~ ^[0-9a-f]{40}$ ]]; then
    pin_sha="$pin"
  else
    pin_sha="$(printf '%s\n' "${rows[@]}" | awk -F'\t' -v p="$pin" '$2==p && !f {print $3; f=1}')"
    [ -n "$pin_sha" ] || die "pin '$pin' is not a branch or tag name in this repo"
    [ "$(printf '%s\n' "${rows[@]}" | awk -F'\t' -v p="$pin" '$2==p' | wc -l)" -eq 1 ] || die "'$pin' is both a branch and a tag; pass the full SHA instead"
  fi
  [[ "$pin_sha" =~ ^[0-9a-f]{40}$ ]] || die "pin did not resolve to a full SHA"
fi

# Commits in $1 that are not in $2. Sets EXTRA_N (with a trailing + if truncated) and EXTRA_ROOT (yes if a root commit is among them).
extra() {
  local a="$1" b="$2" path out n=0 pages=0
  EXTRA_ROOT=no
  path="$R/commits?include=$a&exclude=$b&pagelen=100&fields=next,values.hash,values.parents.hash"
  while [ -n "$path" ] && [ "$pages" -lt 5 ]; do
    out="$(bb "$path")" || die "request failed: commits"
    jq -e '.values | type == "array"' <<<"$out" >/dev/null || die "unexpected response (no values list): commits"
    n=$((n + $(jq '.values|length' <<<"$out")))
    if [ "$(jq '[.values[] | select((.parents|length)==0)] | length' <<<"$out")" -gt 0 ]; then EXTRA_ROOT=yes; fi
    path="$(jq -r '.next // empty' <<<"$out")"
    pages=$((pages + 1))
  done
  EXTRA_N="$n"
  if [ -n "$path" ]; then EXTRA_N="${n}+"; fi
}

declare -A c_ahead c_behind c_shares
compared=0; skipped=0
printf 'kind\tname\tsha\tdate\tahead_of_pin\tpin_ahead\tshares_history\n'
for row in "${rows[@]}"; do
  IFS=$'\t' read -r kind name sha date <<<"$row"
  [[ "$sha" =~ ^[0-9a-f]{40}$ ]] || die "unexpected SHA from the API for $name"
  ahead="-"; behind="-"; shares="-"
  if [ -n "$pin_sha" ]; then
    if [ "$sha" = "$pin_sha" ]; then
      ahead=0; behind=0; shares=pin
    elif [ -n "${c_ahead[$sha]:-}" ]; then
      ahead="${c_ahead[$sha]}"; behind="${c_behind[$sha]}"; shares="${c_shares[$sha]}"
    elif [ "$compared" -lt "$MAX_COMPARE" ]; then
      extra "$sha" "$pin_sha"; ahead="$EXTRA_N"
      if [ "$EXTRA_ROOT" = yes ]; then shares=no
      elif [[ "$EXTRA_N" == *+ ]]; then shares=unknown
      else shares=yes; fi
      extra "$pin_sha" "$sha"; behind="$EXTRA_N"
      c_ahead[$sha]="$ahead"; c_behind[$sha]="$behind"; c_shares[$sha]="$shares"
      compared=$((compared + 1))
    else
      skipped=$((skipped + 1))
    fi
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$kind" "$name" "${sha:0:8}" "$date" "$ahead" "$behind" "$shares"
done
if [ "$skipped" -gt 0 ]; then
  echo "refs.sh: $skipped refs not compared (limit $MAX_COMPARE distinct commits; REFS_MAX_COMPARE)" >&2
fi
echo "refs.sh: $(wc -c < "$cnt") API requests" >&2

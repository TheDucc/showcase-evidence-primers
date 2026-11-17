#!/usr/bin/env bash
# lint.sh <primer.md> [ledger.tsv]
# Mechanical checks on one primer. Local only: no network, no credentials, no model. Never modifies files.
# Output, one line each: <file>:<line>:<rule|lead>:<id>: <detail>   (line is - for whole-file findings)
#   then skipped:<id>: <reason> lines, then a '#' summary line.
# Exit: 0 no rule findings (leads never change it), 1 at least one rule finding, 2 usage or template error.
# Checks are listed in rules.tsv; each runs the function check_<id> below. Test cases: cases.tsv, run by selftest.sh.
# A finding is suppressed when its own line contains  <!-- lint-ok: <id> -->
# Reads from ../../../../primerTemplate.md: header fields, legend text, facet names, Depth and Source vocabularies.
# PRIMER_NAMES (env, extended regex, case-insensitive): internal names that must not appear. Keep it out of the repo.
# A primer is v3 when it has any of the legend, files or terms header lines; v3 checks are skipped otherwise.
# Written for mawk and GNU grep/sed; see the repo-reader scripts for the mawk limits.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rules="$here/rules.tsv"
template="${PRIMER_TEMPLATE:-$here/../../../../primerTemplate.md}"   # override exists for selftest only
die() { echo "lint.sh: $*" >&2; exit 2; }

[ $# -ge 1 ] && [ $# -le 2 ] || die "usage: lint.sh <primer.md> [ledger.tsv]"
P="$1"; L="${2:-}"
[ -r "$P" ] || die "cannot read primer: $P"
[ -z "$L" ] || [ -r "$L" ] || die "cannot read ledger: $L"
[ -r "$template" ] || die "template not found: $template"
[ -r "$rules" ] || die "rules not found: $rules"
T="$(mktemp -d)"; trap 'rm -rf -- "$T"' EXIT
base="$(basename -- "$P")"
: > "$T/out"; : > "$T/skip"

# ---- template ----
tmpl_fields="$(awk '/^```/{n++; next} n==1 && /^[a-z]+:/{sub(/:.*/,""); print}' "$template")"
tmpl_legend="$(awk '/^```/{n++; next} n==3{print}' "$template")"
[ -n "$tmpl_fields" ] && [ -n "$tmpl_legend" ] || die "template yields no header fields or legend"
collapse() { tr -s '[:space:]' ' ' | sed -E 's/^ //; s/ $//'; }
vocab_of() { grep "^$1:" <<<"$tmpl_legend" | sed -E "s/^$1: //" | tr ';' '\n' | sed -E 's/ =.*$//; s/^ +//'; }
dvocab="$(vocab_of Depth)"; svocab="$(vocab_of Source)"
[ -n "$dvocab" ] && [ -n "$svocab" ] || die "template legend yields no Depth or Source vocabulary"
declare -A tname
while IFS=$'\t' read -r n nm; do tname[$n]="$nm"; done < <(awk -F'|' '/^\| [0-9]+ \|/ {n=$2+0; nm=$3; gsub(/^ +| +$/,"",nm); print n "\t" nm}' "$template")
[ "${#tname[@]}" -eq 12 ] || die "template facet table does not give 12 facets"

# ---- primer: header and table ----
US=$'\037'
awk '/^## /{exit}
  /^[a-z]+:[ \t]/ { if (name != "") print name "\037" ln "\037" val; name=$0; sub(/:.*/,"",name); ln=NR; val=$0; sub(/^[a-z]+:[ \t]*/,"",val); next }
  /^[ \t]+[^ \t]/ && name != "" { v=$0; sub(/^[ \t]+/,"",v); val = val " " v; next }
  END { if (name != "") print name "\037" ln "\037" val }' "$P" > "$T/hdr"
awk 'function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
  /^\|/ { s=$0; gsub(/\\\|/, "\001", s); n=split(s, f, "|")
    num=trim(f[2]); if (num !~ /^[0-9]+[a-z]?$/) next
    for (i=3; i<=7; i++) { f[i]=trim(f[i]); gsub(/\001/, "|", f[i]) }
    print NR "\037" num "\037" f[3] "\037" f[4] "\037" f[5] "\037" f[6] "\037" f[7] }' "$P" > "$T/rows"

declare -A hv hl
while IFS="$US" read -r name ln val; do hv[$name]="$val"; hl[$name]="$ln"; done < "$T/hdr"
v3=no
for f in legend files terms; do [ -z "${hv[$f]+x}" ] || v3=yes; done

declare -A ltag
if [ -n "$L" ]; then
  # awk keeps empty columns and drops CR; a bash read with a tab IFS collapses empty fields and would shift the tag
  while IFS=$'\x1f' read -r path tag; do ltag[$path]="$tag"; done < <(tail -n +2 "$L" | tr -d '\r' | awk -F'\t' '{printf "%s\037%s\n", $1, $3}')
fi

declare -A rk
while IFS=$'\t' read -r id kind _; do [ "$id" = id ] || rk[$id]="$kind"; done < "$rules"

emit() { # line id detail
  if [ "$1" != "-" ] && sed -n "${1}p" "$P" | grep -qF "lint-ok: $2"; then return; fi
  printf '%s:%s:%s:%s: %s\n' "$base" "$1" "${rk[$2]}" "$2" "$3" >> "$T/out"
}
words_of() { sed -E 's/\([^)]*\)//g' <<<"$1" | tr ',;' '\n\n' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g' | grep -v '^$' || true; }
tokens_of() { { sed -E 's/[A-Za-z0-9_.\/-]*\*[A-Za-z0-9_.\/*-]*/ /g' <<<"$1" | grep -oE '[A-Za-z0-9_./-]+\.[A-Za-z][A-Za-z0-9]*' || true; } | { grep -vE '^v?[0-9][0-9.xX-]*$' || true; }; }   # version-like tag names (8.x-2.0, 7.x-1.x, v9.x) are not paths
inlist() { grep -qFx -- "$1" <<<"$2"; }
each_row() { while IFS="$US" read -r ln num facet tag depth ptr src; do "$@"; done < "$T/rows"; }

# ---- checks ----
check_dash() {
  local m; while IFS= read -r m; do emit "${m%%:*}" dash "em or en dash"; done < <(LC_ALL=C grep -nE $'\xe2\x80[\x93\x94]' "$P" || true)
}
check_words() {
  local n; n="$(sed -E 's/<!-- lint-ok:[^>]*-->//g' "$P" | wc -w)"
  [ "$n" -le 1300 ] || emit - words "$n words, limit 1300"
}
check_header() {
  local f; for f in $tmpl_fields; do
    case "$f" in files|legend|terms) continue ;; esac
    [ -n "${hv[$f]+x}" ] || emit - header "missing header line: $f"
  done
}
check_header3() {
  local f; for f in files legend terms; do [ -n "${hv[$f]+x}" ] || emit - header3 "missing header line: $f"; done
}
check_legend() {
  [ -n "${hv[legend]+x}" ] || return 0
  [ "$(collapse <<<"${hv[legend]}")" = "$(collapse <<<"$tmpl_legend")" ] || emit "${hl[legend]}" legend "legend differs from the template legend"
}
check_facets() {
  local n seen=""
  for n in 1 2 3 4 5 6 7 8 9 10 11 12; do
    local found="" l num facet _x
    while IFS="$US" read -r l num facet _x; do
      if [ "$num" = "$n" ]; then found=1; [ "$facet" = "${tname[$n]}" ] || emit "$l" facets "facet $n is named '$facet', template says '${tname[$n]}'"; break; fi
    done < "$T/rows"
    [ -n "$found" ] || emit - facets "facet $n is missing"
  done
}
vocab_row() {
  local w
  if [ -z "$(words_of "$depth")" ]; then emit "$ln" vocab "row $num: empty Depth"; fi
  while IFS= read -r w; do [ -n "$w" ] || continue
    if ! inlist "$w" "$dvocab" && [ "$w" != memory ]; then emit "$ln" vocab "row $num: '$w' is not a Depth word"; fi
  done < <(words_of "$depth")
  if [ -z "$(words_of "$src")" ]; then emit "$ln" vocab "row $num: empty Source"; fi
  while IFS= read -r w; do [ -n "$w" ] || continue
    inlist "$w" "$svocab" || emit "$ln" vocab "row $num: '$w' is not a Source word"
  done < <(words_of "$src")
}
check_vocab() { each_row vocab_row; }
many_row() { [ "$num" = 11 ] && return 0; [ "$(words_of "$src" | wc -l)" -lt 3 ] || emit "$ln" manysources "row $num lists $(words_of "$src" | wc -l) sources"; }
check_manysources() { each_row many_row; }
mem_row() {
  local w only=1 any=""
  while IFS= read -r w; do any=1; [ "$w" = memory ] || only=""; done < <(words_of "$src")
  [ -n "$any" ] && [ -n "$only" ] || return 0
  [[ "$num" =~ ^[0-9]+[a-z]$ ]] || [ "$num" = 12 ] || emit "$ln" memrow "row $num has only memory as its source but is not a sub-row"
}
check_memrow() { each_row mem_row; }
parse_files() { # sets FT FD FS FC FU, returns 1 if absent or unparsable
  local v="${hv[files]:-}"
  [[ "$v" =~ ^([0-9]+)\ in\ the\ tree\ =\ ([0-9]+)\ deep\ \+\ ([0-9]+)\ skimmed\ \+\ ([0-9]+)\ declared\ \+\ ([0-9]+)\ unread ]] || return 1
  FT="${BASH_REMATCH[1]}"; FD="${BASH_REMATCH[2]}"; FS="${BASH_REMATCH[3]}"; FC="${BASH_REMATCH[4]}"; FU="${BASH_REMATCH[5]}"
}
check_filesline() {
  [ -n "${hv[files]+x}" ] || return 0
  if ! parse_files; then emit "${hl[files]}" filesline "files line does not follow '<n> in the tree = a deep + b skimmed + c declared + d unread'"; return 0; fi
  [ $((FD + FS + FC + FU)) -eq "$FT" ] || emit "${hl[files]}" filesline "parts add to $((FD + FS + FC + FU)), total says $FT"
}
check_ledgersum() {
  if ! parse_files; then emit - ledgersum "files line missing or unparsable; cannot compare with the ledger"; return 0; fi
  local t c d=0 s=0 c2=0 u=0 total=0
  for t in "${ltag[@]}"; do
    total=$((total + 1))
    case "$t" in deep) d=$((d + 1)) ;; skimmed) s=$((s + 1)) ;; declared) c2=$((c2 + 1)) ;; unread) u=$((u + 1)) ;; esac
  done
  if [ "$d,$s,$c2,$u" != "$FD,$FS,$FC,$FU" ] || [ "$total" -ne "$FT" ]; then
    emit "${hl[files]}" ledgersum "files line says $FT = $FD+$FS+$FC+$FU; ledger has $total = $d+$s+$c2+$u (deep+skimmed+declared+unread)"
  fi
}
check_ledgersha() {
  local lb sha; lb="$(basename -- "$L")"
  [[ "$lb" =~ \.([0-9a-f]{8})\.reads(\.PARTIAL)?\.tsv$ ]] || { emit - ledgersha "ledger filename does not look like <repo>.<sha8>.reads.tsv"; return 0; }
  [ -z "${BASH_REMATCH[2]}" ] || emit - ledgersha "ledger is PARTIAL (a truncated listing)"
  sha="${BASH_REMATCH[1]}"
  [[ "${hv[reviewed]:-}" =~ ^([0-9a-f]{8}) ]] || { emit "${hl[reviewed]:-1}" ledgersha "reviewed line does not start with a SHA of at least 8 hex characters"; return 0; }
  [ "${BASH_REMATCH[1]}" = "$sha" ] || emit "${hl[reviewed]}" ledgersha "reviewed SHA starts ${BASH_REMATCH[1]}, ledger name says $sha"
}
ptr_exists_row() { local t; while IFS= read -r t; do [ -n "$t" ] || continue; [ -n "${ltag[$t]+x}" ] || emit "$ln" ptrexists "row $num: '$t' is not in the ledger"; done < <(tokens_of "$ptr"); }
check_ptrexists() { each_row ptr_exists_row; }
ptr_unread_row() { has_word "$depth" unread && return 0; local t; while IFS= read -r t; do [ "${ltag[$t]:-}" != unread ] || emit "$ln" ptrunread "row $num cites '$t', which the ledger marks unread"; done < <(tokens_of "$ptr"); }
check_ptrunread() { each_row ptr_unread_row; }
has_word() { words_of "$1" | grep -qFx -- "$2"; }
ptr_deep_row() {
  has_word "$depth" deep || return 0
  local t any="" deep=""
  while IFS= read -r t; do [ -n "$t" ] || continue; [ -n "${ltag[$t]+x}" ] || continue; any=1; [ "${ltag[$t]}" != deep ] || deep=1; done < <(tokens_of "$ptr")
  [ -z "$any" ] || [ -n "$deep" ] || emit "$ln" ptrdeep "row $num says deep but cites no ledger-deep path"
}
check_ptrdeep() { each_row ptr_deep_row; }
ptr_shallow_row() {
  has_word "$depth" deep && return 0
  has_word "$depth" "none found" && return 0
  local t; while IFS= read -r t; do [ -n "$t" ] || continue
    [ "${ltag[$t]:-}" != deep ] || { emit "$ln" ptrshallow "row $num cites ledger-deep '$t' but its Depth has no deep"; return 0; }
  done < <(tokens_of "$ptr")
}
check_ptrshallow() { each_row ptr_shallow_row; }
srccommit_row() {
  has_word "$src" declared && return 0
  local pin h; pin="$(grep -oiE '^[0-9a-f]{7,40}' <<<"${hv[reviewed]:-}" | head -1 | tr 'A-F' 'a-f')"
  while IFS= read -r h; do h="${h,,}"
    [ -n "$pin" ] && { [[ "$pin" == "$h"* ]] || [[ "$h" == "$pin"* ]]; } && continue
    emit "$ln" srccommit "row $num cites commit $h but Source has no declared"; return 0
  done < <(grep -oiE '(commits?|diffs?|sha)[ :]+[0-9a-f]{7,40}\b' <<<"$tag $ptr" | grep -oiE '[0-9a-f]{7,40}$' || true)
}
check_srccommit() { each_row srccommit_row; }
check_names() {
  local m; while IFS= read -r m; do emit "${m%%:*}" names "matches PRIMER_NAMES"; done < <(grep -inE -- "$PRIMER_NAMES" "$P" || true)
}
verb_row() { has_word "$depth" deep && return 0; [ "$(words_of "$depth")" = memory ] && return 0; grep -qiwE 'built|designed|implemented' <<<"$tag" && emit "$ln" verb "row $num: built/designed/implemented in a row without deep"; return 0; }
check_verb() { each_row verb_row; }
check_unreleased() {
  local m; while IFS= read -r m; do emit "${m%%:*}" unreleased "say 'after the last tag' instead"; done < <(grep -inw 'unreleased' "$P" || true)
}
check_acronym() {
  local allow=" PHP REST API YAML JSON HTTP HTTPS URL CSS JS SQL HTML XML CORS CMS UI UX CI CD TLS SSL SSH PDF CSV DB ID README POST PUT PATCH GET DELETE SHA QA TRUE FALSE NULL XXX "
  local defined="${hv[terms]:-} ${hv[legend]:-}" m ln w
  while IFS= read -r m; do ln="${m%%:*}"
    while IFS= read -r w; do w="${w//[^A-Z]/}"; [ -n "$w" ] || continue
      case "$allow" in *" $w "*) continue ;; esac
      grep -qw -- "$w" <<<"$defined" && continue
      grep -qE "(^|[^A-Za-z0-9_])$w[[:space:]]*\(|\($w\)" "$P" && continue   # defined inline at first use, e.g. SAML (a standard) or (SSO)
      emit "$ln" acronym "'$w' is not defined in terms, legend or inline"
    done < <(grep -oE '(^|[^A-Za-z0-9_])[A-Z]{2,6}([^A-Za-z0-9_]|$)' <<<"${m#*:}" || true)
  done < <(grep -nvE '^(repo|legend|terms):|^[[:space:]]{6,}' "$P" || true)
}

# ---- run ----
while IFS=$'\t' read -r id kind version needs _; do
  [ "$id" != id ] || continue
  if [ "$version" = v3 ] && [ "$v3" = no ]; then echo "skipped:$id: v3 only" >> "$T/skip"; continue; fi
  case "$needs" in
    ledger) if [ -z "$L" ]; then echo "skipped:$id: needs ledger" >> "$T/skip"; continue; fi ;;
    env) if [ -z "${PRIMER_NAMES:-}" ]; then echo "skipped:$id: needs env PRIMER_NAMES" >> "$T/skip"; continue; fi ;;
  esac
  "check_$id"
done < "$rules"

nrule="$(grep -c ':rule:' "$T/out" || true)"; nlead="$(grep -c ':lead:' "$T/out" || true)"
cat "$T/out" "$T/skip"
echo "# $nrule rule findings, $nlead leads, $(wc -l < "$T/skip") checks skipped"
[ "$nrule" -eq 0 ]

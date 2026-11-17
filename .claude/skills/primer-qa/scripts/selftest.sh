#!/usr/bin/env bash
# selftest.sh [workdir]
# Offline test of lint.sh. Builds a clean synthetic primer and ledger (using the template's real legend), then for each
# line of cases.tsv applies the mutation and requires the set of finding ids to equal `expected` ('-' = none).
# Mutation operations, joined by ' ;; ': none | sed:<ERE> | ledger-sed:<ERE> | delete-line:<ERE> | append:<text, \xHH ok>
#   | pad-to:<words> | ledger-name:<sha8> | old-style (drop legend, files, terms) | no-ledger
# Also fails when a rule id in rules.tsv has no case that expects it. Uses no real primer and no network.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
template="$here/../../../../primerTemplate.md"
if [ $# -ge 1 ]; then w="$1"; mkdir -p -- "$w"; [ -z "$(ls -A -- "$w")" ] || { echo "selftest.sh: workdir not empty" >&2; exit 1; }
else w="$(mktemp -d)"; fi
w="$(cd -- "$w" && pwd -P)"
trap 'rm -rf -- "$w"' EXIT
pass=0; fail=0
bad() { fail=$((fail + 1)); echo "FAIL: $1"; }

legend="$(awk '/^```/{n++; next} n==3{print}' "$template")"
{
  echo "# demo_repo"; echo
  echo "repo:          https://example.org/ws/demo_repo"
  echo "reviewed:      abcdef0123456789abcdef0123456789abcdef01 (branch main), 2020-01-01"
  echo "role:          wrote, 2020"
  echo "involvement:   2020-01 to 2020-02"
  echo "purpose:       Demo service"
  echo "stack:         PHP"
  echo "files:         4 in the tree = 1 deep + 1 skimmed + 1 declared + 1 unread (1 skipped on purpose, empty)"
  echo "coverage:      deep: src/A.php; skimmed: src/B.php; declared: README.md; unread: empty.txt"
  echo "focus:         src/A.php"
  echo "skills:        PHP (deep)"
  first=1; while IFS= read -r l; do if [ $first = 1 ]; then echo "legend:        $l"; first=0; else echo "               $l"; fi; done <<<"$legend"
  echo "terms:         pin = the commit read."
  echo; echo "## Facets"; echo
  echo "| # | Facet | Tag | Depth | Pointer (path @ abcdef01) | Source |"
  echo "|---|---|---|---|---|---|"
  names=("" "Language and runtime" "Framework and platform" "Data layer" "Integrations and APIs" "Architecture and system design" "Front end and UX" "Hosting and delivery" "Testing" "Observability, performance, operations" "Security and data handling" "Problem and solution" "Business context and scale")
  for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
    case $i in
      1) echo "| 1 | ${names[1]} | PHP | skimmed | src/B.php | code |" ;;
      7) echo "| 7 | ${names[7]} | documented install | declared | README.md | declared |" ;;
      11) echo "| 11 | ${names[11]} | see entry A | deep | src/A.php lines 1-20 (run) | code |" ;;
      12) echo "| 12 | ${names[12]} | testing only | memory | | memory (confirmed) |" ;;
      *) echo "| $i | ${names[$i]} | none found | none found | | code |" ;;
    esac
  done
} > "$w/base.md"
printf 'path\tbytes\ttag\tlines\tname\tpass\treason\nREADME.md\t100\tdeclared\t\t\t\t\nempty.txt\t0\tunread\t\t\t\tempty\nsrc/A.php\t900\tdeep\t1-20\trun\tdeep1\t\nsrc/B.php\t500\tskimmed\t\t\t\t\n' > "$w/base.tsv"

words() { sed -E 's/<!-- lint-ok:[^>]*-->//g' "$1" | wc -w; }

run_case() { # name mutation expected
  local name="$1" mut="$2" want="$3" d="$w/case" op ledger uselg=1 got rc kind
  rm -rf "$d"; mkdir -p "$d"; cp "$w/base.md" "$d/demo_repo.md"; ledger="$d/demo_repo.abcdef01.reads.tsv"; cp "$w/base.tsv" "$ledger"
  local ops; IFS=$'\n' read -r -d '' -a ops < <(sed 's/ ;; /\n/g' <<<"$mut"; printf '\0') || true
  for op in "${ops[@]}"; do
    case "$op" in
      none) ;;
      sed:*) sed -E -i "${op#sed:}" "$d/demo_repo.md" ;;
      ledger-sed:*) sed -E -i "${op#ledger-sed:}" "$ledger" ;;
      delete-line:*) sed -E -i "/${op#delete-line:}/d" "$d/demo_repo.md" ;;
      append:*) printf '%b\n' "${op#append:}" >> "$d/demo_repo.md" ;;
      pad-to:*) local have; have="$(words "$d/demo_repo.md")"; local k=$(( ${op#pad-to:} - have )); { for ((i = 0; i < k; i++)); do printf 'pad '; done; echo; } >> "$d/demo_repo.md" ;;
      ledger-name:*) mv "$ledger" "$d/demo_repo.${op#ledger-name:}.reads.tsv"; ledger="$d/demo_repo.${op#ledger-name:}.reads.tsv" ;;
      old-style) sed -E -i '/^(legend|files|terms):/d; /^ {10,}/d' "$d/demo_repo.md" ;;
      no-ledger) uselg=0 ;;
      *) bad "$name: unknown mutation '$op'"; return ;;
    esac
  done
  if [ $uselg = 1 ]; then out="$(PRIMER_NAMES='zork[0-9]' "$here/lint.sh" "$d/demo_repo.md" "$ledger" 2>&1)"; rc=$?
  else out="$(PRIMER_NAMES='zork[0-9]' "$here/lint.sh" "$d/demo_repo.md" 2>&1)"; rc=$?; fi
  got="$(grep -E '^[^:]+:[^:]+:(rule|lead):[a-z0-9]+:' <<<"$out" | awk -F: '{print $4}' | sort -u | paste -sd, -)"
  [ -n "$got" ] || got="-"
  local wantsorted; wantsorted="$(tr ',' '\n' <<<"$want" | sort -u | paste -sd, -)"
  if [ "$got" = "$wantsorted" ]; then pass=$((pass + 1)); else bad "$name: expected [$wantsorted], got [$got]"; fi
  local rules_hit; rules_hit="$(grep -c ':rule:' <<<"$out" || true)"
  if { [ "$rules_hit" -gt 0 ] && [ "$rc" -ne 1 ]; } || { [ "$rules_hit" -eq 0 ] && [ "$rc" -ne 0 ]; }; then bad "$name: exit code $rc with $rules_hit rule findings"; fi
}

while IFS=$'\t' read -r name mut want; do
  [ "$name" != name ] || continue
  run_case "$name" "$mut" "$want"
done < "$here/cases.tsv"

# every rule needs a case
while IFS=$'\t' read -r id _; do
  [ "$id" != id ] || continue
  cut -f3 "$here/cases.tsv" | tr ',' '\n' | grep -qFx -- "$id" || bad "rule '$id' has no case that expects it"
done < "$here/rules.tsv"

# usage errors
"$here/lint.sh" >/dev/null 2>&1; [ $? -eq 2 ] && pass=$((pass + 1)) || bad "no arguments should exit 2"
"$here/lint.sh" "$w/nope.md" >/dev/null 2>&1; [ $? -eq 2 ] && pass=$((pass + 1)) || bad "unreadable primer should exit 2"

echo "selftest: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

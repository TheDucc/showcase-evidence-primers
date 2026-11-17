#!/usr/bin/env bash
# scan.sh <folder>
# Local only: no network, no credentials. Scans the text files under <folder> for secret-like and identifier-like
# strings and prints WHERE they are, never WHAT they are: file, line, pattern name (TSV), then per-pattern counts.
# Patterns: private_key, password_hash, aws_access_key, token_prefix, credential_assignment, email_address,
#           ip_address (127.0.0.1 and 0.0.0.0 ignored), and internal_host when SCAN_HOST_RE is set.
# SCAN_HOST_RE is an extended regex for internal host or product names. Export it from your shell profile, not in a
# command and not in the repo, so the names never appear in the transcript or the skill. It is passed by environment.
# Hits are leads for review, not proof: a credential_assignment can be a harmless placeholder.
# Skipped, and not counted as scanned: binary files, files of 5 MiB or more, empty files, symlinks.
# Lines over 3000 characters are not scanned (matching them takes quadratic time) and are reported as long_line_not_scanned.
# Output is capped at 200 hits. Selftest: scripts/selftest.sh.
# Written for mawk, the default awk here: repeat counts are written out wherever more pattern follows them.
set -euo pipefail

die() { echo "scan.sh: $*" >&2; exit 1; }
[ $# -eq 1 ] || die "usage: scan.sh <folder>"
[ -d "$1" ] || die "not a directory: $1"
cd -- "$1"

if [ -n "${SCAN_HOST_RE:-}" ]; then
  rc=0; grep -E -- "$SCAN_HOST_RE" </dev/null >/dev/null 2>&1 || rc=$?
  [ "$rc" -ne 2 ] || die "SCAN_HOST_RE is not a valid extended regex"
fi

prog='
function add(name, re) { n++; pname[n] = name; pre[n] = re }
function skipip(s) { return (s == "127.0.0.1" || s == "0.0.0.0") }
function rep(c, k,   r, i) { r = ""; for (i = 0; i < k; i++) r = r c; return r }
function isip(s,   a, k) { if (split(s, a, ".") != 4) return 0; for (k = 1; k <= 4; k++) if (a[k] + 0 > 255) return 0; return 1 }
BEGIN {
  hostre = ENVIRON["SCAN_HOST_RE"]
  add("private_key", "-----BEGIN [A-Z ]*PRIVATE KEY-----")
  add("password_hash", "[$]S[$][A-Za-z0-9./]{20,}|[$]2[aby][$][0-9][0-9][$][A-Za-z0-9./]{20,}|[$]P[$][A-Za-z0-9./]{20,}|[$]6[$]" rep("[A-Za-z0-9./]", 8) "[A-Za-z0-9./]*[$]")
  add("aws_access_key", "AKIA[0-9A-Z]{16}")
  add("token_prefix", "gh[pousr]_[A-Za-z0-9]{30,}|xox[baprs]-[A-Za-z0-9-]{10,}|sk-[A-Za-z0-9]{20,}")
  add("email_address", "[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+[.][A-Za-z0-9.-]+")
  if (hostre != "") add("internal_host", hostre)
  cred1 = "(password|passwd|pwd|secret|api[_-]?key|token|(^|[^a-z])pw)[a-z0-9_\"\047]*[[:space:]]*(:|=[^>=])[[:space:]]*[\"\047][^\"\047$<{( ]" rep("[^\"\047]", 5) "[^\"\047]*[\"\047]"
  cred2 = "^[[:space:]]*[a-z_]*(password|secret|token|api_key)[a-z_]*:[[:space:]]+[^[:space:]\"\047$#]" rep("[^[:space:]]", 5) "[^[:space:]]*"
  ipre = "[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+"
}
{
  if (length($0) > 3000) { print FILENAME "\t" FNR "\tlong_line_not_scanned"; next }
  line = $0; low = tolower($0)
  for (i = 1; i <= n; i++) if (line ~ pre[i]) print FILENAME "\t" FNR "\t" pname[i]
  if (low ~ cred1 || low ~ cred2) print FILENAME "\t" FNR "\tcredential_assignment"
  rest = line
  while (match(rest, ipre)) {
    s = substr(rest, RSTART, RLENGTH)
    if (isip(s) && !skipip(s)) { print FILENAME "\t" FNR "\tip_address"; break }
    rest = substr(rest, RSTART + RLENGTH)
  }
}'

# -size -5242881c = at most 5 MiB (a plain -5M rounds up and would skip files over about 4 MiB).
files=()
while IFS= read -r -d '' f; do files+=("$f"); done < <(find . -type f -size -5242881c -print0 | xargs -0 -r grep -IlZ -- '' || true)

hits=""
if [ "${#files[@]}" -gt 0 ]; then
  hits="$(printf '%s\0' "${files[@]}" | SCAN_HOST_RE="${SCAN_HOST_RE:-}" xargs -0 awk "$prog" \
    | sed 's#^\./##' | LC_ALL=C sort -t$'\t' -k1,1 -k2,2n -k3,3 -u)"
fi

printf 'file\tline\tpattern\n'
if [ -n "$hits" ]; then
  # sed reads all of its input, so a long list cannot kill the script with SIGPIPE the way head would.
  sed -n '1,200p' <<<"$hits"
  total="$(wc -l <<<"$hits")"
  [ "$total" -le 200 ] || echo "# output capped: $total hits, first 200 shown"
fi
echo "# text files scanned: ${#files[@]}"
if [ -n "$hits" ]; then
  cut -f3 <<<"$hits" | sort | uniq -c | awk '{print "# " $2 ": " $1}'
else
  echo "# no hits"
fi

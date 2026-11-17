#!/usr/bin/env bash
# selftest.sh [workdir]
# Offline check of scan.sh, tree.sh and ledger.sh. No network, no credentials. refs.sh needs the live API and is not covered.
# Fake secrets are built here at run time and deleted afterwards, so no secret-like text is stored in the repo.
# workdir (optional, must be empty or absent, outside the project): defaults to a fresh mktemp folder.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ $# -ge 1 ]; then w="$1"; mkdir -p -- "$w"; [ -z "$(ls -A -- "$w")" ] || { echo "selftest.sh: workdir not empty" >&2; exit 1; }
else w="$(mktemp -d)"; fi
w="$(cd -- "$w" && pwd -P)"
trap 'rm -rf -- "$w"' EXIT
pass=0; fail=0
ok() { if [ "$2" = 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1"; fi; }
has() { grep -qF -- "$2" <<<"$1"; }

# ---------- scan.sh ----------
f="$w/fx"; mkdir -p "$f/sub dir"
k="PRIVATE KEY"
printf -- '-----BEGIN RSA %s-----\nabc\n' "$k" > "$f/pem.txt"
printf 'key = AKIA%s\n' "ABCDEFGHIJKLMNOP" > "$f/aws.txt"
printf 'tok = gh%s_%s\n' "p" "abcdefghijklmnopqrstuvwxyz0123456789" > "$f/gh.txt"
printf '<?php\n$password = "hunter2hunter2";\n' > "$f/cred.php"
printf 'db:\n  password: verysecretvalue1\n' > "$f/cred.yml"
printf 'h = $2y$10$%s\n' "abcdefghijklmnopqrstuvwxyz0123" > "$f/bcrypt.txt"
printf 'mail me at a.b@example.com from 10.20.30.40 and version 9.3.1.2\n' > "$f/misc.txt"
printf 'x\0y\0password = "binarybinary"\n' > "$f/blob.bin"
printf 'plain text with nothing, 127.0.0.1 and 1.2.3\n' > "$f/sub dir/we:ird name.txt"
: > "$f/empty.txt"
head -c 4700000 /dev/zero | tr '\0' 'a' > "$f/big.txt"; printf '\npassword = "bigfilebigfile"\n' >> "$f/big.txt"
out="$("$here/scan.sh" "$f" 2>&1)"; rc=$?
ok "scan exit 0" "$rc"
for want in $'pem.txt\t1\tprivate_key' $'aws.txt\t1\taws_access_key' $'gh.txt\t1\ttoken_prefix' $'cred.php\t2\tcredential_assignment' \
            $'cred.yml\t2\tcredential_assignment' $'bcrypt.txt\t1\tpassword_hash' $'misc.txt\t1\temail_address' $'misc.txt\t1\tip_address' \
            $'big.txt\t2\tcredential_assignment' $'big.txt\t1\tlong_line_not_scanned'; do
  has "$out" "$want"; ok "scan finds: ${want//$'\t'/ }" "$?"
done
! has "$out" "blob.bin"; ok "scan skips binary file" "$?"
! has "$out" "we:ird"; ok "scan: no hit in clean file with odd name" "$?"
has "$out" "# text files scanned: 9"; ok "scan counts 9 text files (empty and binary skipped)" "$?"
leak=0; for frag in hunter2 verysecretvalue abcdefghijklmnop example.com 10.20.30.40 ABCDEFGHIJKLMNOP; do has "$out" "$frag" && leak=1; done
ok "scan prints no matched text" "$leak"
printf 'see badhost.internal now\n' > "$f/host.txt"
out2="$(SCAN_HOST_RE='badhost[.]internal' "$here/scan.sh" "$f" 2>&1)"; has "$out2" $'host.txt\t1\tinternal_host'; ok "scan internal_host via SCAN_HOST_RE" "$?"
! has "$out2" "badhost"; ok "scan does not print host names" "$?"
out3="$(SCAN_HOST_RE='(' "$here/scan.sh" "$f" 2>&1)"; rc=$?; [ "$rc" -ne 0 ] && has "$out3" "not a valid"; ok "scan rejects invalid SCAN_HOST_RE" "$?"
! has "$out3" '('; ok "scan does not echo the bad regex" "$?"
big="$w/many"; mkdir -p "$big"; for i in $(seq 1 250); do printf 'ip 10.0.0.%s\n' "$((i % 250 + 1))" > "$big/f$i.txt"; done
out4="$("$here/scan.sh" "$big" 2>&1)"; rc=$?
ok "scan survives more than 200 hits" "$rc"; has "$out4" "# output capped: 250 hits"; ok "scan reports the cap" "$?"

# ---------- tree.sh with a stub bb.sh ----------
stub="$w/stub"; mkdir -p "$stub"
cat > "$stub/bb.sh" <<'STUB'
#!/usr/bin/env bash
case "$1" in *cursor=2*) cat "$STUB_DIR/page2.json" ;; *) cat "$STUB_DIR/page1.json" ;; esac
STUB
chmod +x "$stub/bb.sh"
deep="a/b/c/d/e/f/g/h/i/j"
cat > "$stub/page1.json" <<JSON
{"next":"https://api.bitbucket.org/2.0/x?cursor=2","values":[
 {"type":"commit_file","path":"README.md","size":400},
 {"type":"commit_file","path":"src/a.php","size":4000},
 {"type":"commit_file","path":"img/logo.png","size":9000},
 {"type":"commit_file","path":"vendor/lib/x.php","size":100}]}
JSON
cat > "$stub/page2.json" <<JSON
{"values":[
 {"type":"commit_file","path":"web/app.min.js","size":50},
 {"type":"commit_file","path":"web/tab\\tname.js","size":80},
 {"type":"commit_directory","path":"$deep"},
 {"type":"commit_link","path":"sub/module"}]}
JSON
export STUB_DIR="$stub" TREE_BB="$stub/bb.sh"
sha="$(printf 'ab%.0s' $(seq 1 20))"
od="$w/out"; mkdir -p "$od"
t="$("$here/tree.sh" ws/repo "$sha" "$od" 2>"$w/err")"; rc=$?
ok "tree exit 0" "$rc"
has "$t" $'TOTAL\t4\t'; ok "tree TOTAL counts 4 files (vendor and minified left out)" "$?"
has "$t" "# excluded vendor: 1 files"; ok "tree notes vendor" "$?"
has "$t" "# excluded minified: 1 files"; ok "tree notes minified" "$?"
has "$t" "# binary files: 1"; ok "tree notes binary" "$?"
has "$t" "1 directories at the depth limit"; ok "tree notes unexpanded directory" "$?"
has "$t" "1 entries that are neither files nor directories"; ok "tree notes submodule" "$?"
L="$od/repo.abababab.reads.tsv"
[ -f "$L" ] && [ "$(wc -l < "$L")" -eq 5 ]; ok "tree ledger has header plus 4 rows" "$?"
awk -F'\t' 'NR>1 && $3!="unread" {bad=1} END {exit bad}' "$L"; ok "tree ledger rows all unread" "$?"
grep -q $'img/logo.png\t9000\tunread\t\t\t\tbinary' "$L"; ok "tree marks binary reason" "$?"
grep -q 'tab?name.js' "$L"; ok "tree replaces control characters" "$?"
[ -z "$(ls -A "$od" | grep '^\.rows' || true)" ]; ok "tree leaves no temp file" "$?"
"$here/tree.sh" ws/repo "$sha" "$od" >/dev/null 2>&1; [ $? -ne 0 ]; ok "tree refuses an existing ledger" "$?"
od2="$w/out2"; mkdir -p "$od2"
TREE_MAX_PAGES=1 "$here/tree.sh" ws/repo "$sha" "$od2" >"$w/t2" 2>/dev/null; rc=$?
[ "$rc" -eq 3 ]; ok "tree truncated run exits 3" "$?"
[ -f "$od2/repo.abababab.reads.PARTIAL.tsv" ] && [ ! -f "$od2/repo.abababab.reads.tsv" ]; ok "tree truncated run writes a PARTIAL ledger only" "$?"
"$here/tree.sh" ws/.. "$sha" "$od2" >/dev/null 2>&1; [ $? -ne 0 ]; ok "tree rejects repo ws/.." "$?"
"$here/tree.sh" ../x "$sha" "$od2" >/dev/null 2>&1; [ $? -ne 0 ]; ok "tree rejects repo ../x" "$?"
TREE_MAX_PAGES=abc "$here/tree.sh" ws/repo "$sha" "$od2" >/dev/null 2>&1; [ $? -ne 0 ]; ok "tree rejects a bad TREE_MAX_PAGES" "$?"
"$here/tree.sh" ws/repo "$sha" "$here" >/dev/null 2>&1; [ $? -ne 0 ]; ok "tree refuses an outdir inside the project" "$?"


# ---------- ledger.sh ----------
lf="$w/ledger"; mkdir -p "$lf"; hd='path\tbytes\ttag\tlines\tname\tpass\treason\n'
printf "$hd"'a b/x y.php\t1\tdeep\t\t\t\t\nsrc/Foo.php\t1\tskimmed\t\t\t\t\nsrc/Bar.php\t1\tunread\t\t\t\t\nREADME.md\t1\tdeclared\t\t\t\t\n' > "$lf/ok.tsv"
cp "$lf/ok.tsv" "$lf/ok.bak"
out="$("$here/ledger.sh" summary "$lf/ok.tsv" 2>&1)"; rc=$?
ok "ledger summary exit 0" "$rc"
has "$out" "4 in the tree = 1 deep + 1 skimmed + 1 declared + 1 unread"; ok "ledger summary files line equals hand counts" "$?"
line="$(head -1 <<<"$out") (details in coverage)"
[[ "$line" =~ ^([0-9]+)\ in\ the\ tree\ =\ ([0-9]+)\ deep\ \+\ ([0-9]+)\ skimmed\ \+\ ([0-9]+)\ declared\ \+\ ([0-9]+)\ unread ]]; ok "ledger files line matches the pattern primer-qa parses" "$?"
cmp -s "$lf/ok.tsv" "$lf/ok.bak"; ok "ledger.sh leaves the ledger unchanged" "$?"
out="$("$here/ledger.sh" count "$lf/ok.tsv" '^src/' 2>&1)"; has "$out" "2 match: 0 deep, 1 skimmed, 0 declared, 1 unread"; ok "ledger count with matches" "$?"
out="$("$here/ledger.sh" count "$lf/ok.tsv" 'zzz' 2>&1)"; has "$out" "0 match"; ok "ledger count without matches" "$?"
"$here/ledger.sh" count "$lf/ok.tsv" '' >/dev/null 2>&1; [ $? -eq 2 ]; ok "ledger count: empty pattern exits 2" "$?"
"$here/ledger.sh" count "$lf/ok.tsv" '[' >/dev/null 2>&1; [ $? -eq 2 ]; ok "ledger count: invalid pattern exits 2" "$?"
printf "$hd"'a.php\t1\tdeep\t\t\t\t\na.php\t1\tskimmed\t\t\t\t\n' > "$lf/dup.tsv"
out="$("$here/ledger.sh" summary "$lf/dup.tsv" 2>&1)"; has "$out" "duplicate path a.php"; ok "ledger warns on a duplicate path" "$?"; has "$out" "1 in the tree = 0 deep + 1 skimmed"; ok "ledger duplicate: last row wins" "$?"
printf "$hd"'a.php\t1\tweird\t\t\t\t\n' > "$lf/odd.tsv"
out="$("$here/ledger.sh" summary "$lf/odd.tsv" 2>&1)"; has "$out" 'unknown tag "weird"'; ok "ledger warns on an unknown tag" "$?"
printf "$hd"'a.php\t1\n' > "$lf/short.tsv"
out="$("$here/ledger.sh" summary "$lf/short.tsv" 2>&1)"; has "$out" "fewer than 3 columns"; ok "ledger warns on a short row" "$?"
cp "$lf/ok.tsv" "$lf/x.reads.PARTIAL.tsv"
out="$("$here/ledger.sh" summary "$lf/x.reads.PARTIAL.tsv" 2>&1)"; has "$out" "PARTIAL"; ok "ledger warns on a PARTIAL ledger" "$?"
printf "$hd" > "$lf/hdr.tsv"; "$here/ledger.sh" summary "$lf/hdr.tsv" >/dev/null 2>&1; [ $? -eq 1 ]; ok "ledger: header-only exits 1" "$?"
printf "$hd"'a.php\t1\tdeep\r\t\t\t\r\n' > "$lf/crlf.tsv"
out="$("$here/ledger.sh" summary "$lf/crlf.tsv" 2>&1)"; has "$out" "1 in the tree = 1 deep"; ok "ledger: CRLF tag is clean" "$?"

echo "selftest: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

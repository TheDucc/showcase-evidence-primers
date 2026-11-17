#!/usr/bin/env bash
# Read-only Bitbucket REST helper. Usage: bb.sh <path-under-/2.0/ | full api.bitbucket.org URL>
# Loads BB_EMAIL and BB_TOKEN from ~/.config/talentForge/bb_credentials by parsing, never sourcing.
# Follows up to 5 redirects, https only. Refuses any host other than api.bitbucket.org.
# Never prints credentials.
set -euo pipefail

f="$HOME/.config/talentForge/bb_credentials"
[ -r "$f" ] || { echo "bb.sh: credentials file not found: $f" >&2; exit 2; }
[ $# -eq 1 ] || { echo "usage: bb.sh <path-under-/2.0/ | https://api.bitbucket.org/... URL>" >&2; exit 2; }

# Strip carriage returns and stray quotes so editor quirks do not corrupt the values.
E=$(grep -m1 '^BB_EMAIL=' "$f" | cut -d= -f2- | tr -d '\r"')
T=$(grep -m1 '^BB_TOKEN=' "$f" | cut -d= -f2- | tr -d '\r"')
[ -n "$E" ] && [ -n "$T" ] || { echo "bb.sh: BB_EMAIL or BB_TOKEN is empty" >&2; exit 2; }
# A backslash would break the quoted curl config line below.
case "$E$T" in
  *\\*) echo "bb.sh: backslash in credentials is not supported" >&2; exit 2 ;;
esac

case "$1" in
  https://api.bitbucket.org/*) url="$1" ;;
  http*://*) echo "bb.sh: refusing non-Bitbucket-API host" >&2; exit 2 ;;
  *) url="https://api.bitbucket.org/2.0/${1#/}" ;;
esac

# --fail-with-body: HTTP errors print the body and return a nonzero exit. -L: /src redirects.
# Credentials go through a config on stdin so they never appear in the process list.
printf 'user = "%s:%s"\n' "$E" "$T" |
  curl -sSL --proto '=https' --proto-redir '=https' --max-redirs 5 --fail-with-body -K - "$url"

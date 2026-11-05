#!/usr/bin/env bash
# Checks that nothing private is about to go into this public repo: home paths, LAN addresses, machine names,
# e-mail addresses in files, and em or en dashes. Run it before every push: bash tests/scrub.sh
cd "$(dirname "$0")/.."
bad=0
check() { # check <label> <grep arguments including the pattern>
  local label=$1; shift
  local hits
  hits=$(git ls-files -z | xargs -0 grep -n "$@" -- 2>/dev/null | grep -v -E "^(LICENSE|tests/scrub.sh):" | head -5)
  if [ -n "$hits" ]; then echo "FOUND $label:"; echo "$hits"; bad=1; fi
}
check "a home path"            -I -E "/home/[a-z]"
check "a LAN address"          -I -E "192\.168\.[0-9]"
check "a private machine name" -I -E "\b(Z13P|X1C|pi5paiva|MbpM5Max|iFelipeM2Max)\b"
check "an e-mail address"      -I -E "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[a-z]{2,}"
check "a client name"          -I -i -E "tribalscale"
# em and en dashes (the project writes plain hyphens and commas)
if git ls-files -z | xargs -0 grep -l -I -P "[\x{2013}\x{2014}]" -- 2>/dev/null | grep -v -E "^(LICENSE|tests/scrub.sh)$" | head -3 | grep -q .; then
  echo "FOUND an em or en dash in:"; git ls-files -z | xargs -0 grep -l -I -P "[\x{2013}\x{2014}]" -- | head -5; bad=1
fi
[ $bad = 0 ] && echo "scrub ok" || { echo "scrub FAILED"; exit 1; }

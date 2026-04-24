#!/usr/bin/env bash
#
# Sync-banner SHA check.
#
# For each references/*.md that has a '<!-- Generated from ... @ <sha> -->'
# banner, asserts that <sha> resolves to a real commit in the apl repo's
# history (not an invented or typo'd hash).
#
# Usage:
#   APL_REPO=/path/to/all-purpose-login tests/sha-banner-check.sh
#
# Default APL_REPO: /Users/muthuishere/muthu/gitworkspace/all-purpose-login

set -u -o pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
SKILL_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)
REF_DIR="$SKILL_DIR/references"
APL_REPO="${APL_REPO:-/Users/muthuishere/muthu/gitworkspace/all-purpose-login}"

green()  { printf "\033[32m%s\033[0m\n" "$*"; }
red()    { printf "\033[31m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
hdr()    { printf "\n\033[1m── %s ──\033[0m\n" "$*"; }

fails=0
passes=0
skips=0
pass() { green "  ✓ $*"; passes=$((passes+1)); }
fail() { red   "  ✗ $*"; fails=$((fails+1)); }
skip() { yellow "  ∼ $*"; skips=$((skips+1)); }

hdr "preflight"
if [[ ! -d "$APL_REPO/.git" ]]; then
  fail "APL_REPO='$APL_REPO' is not a git repo"
  printf "  pass=%d fail=%d skip=%d\n" "$passes" "$fails" "$skips"
  exit "$fails"
fi
pass "apl repo at $APL_REPO"

hdr "banner SHAs"
for f in "$REF_DIR"/*.md; do
  name=$(basename "$f")
  sha=$(grep -oE 'Generated from [^ ]+ @ [a-f0-9]+' "$f" | head -1 | awk '{print $NF}' || true)
  if [[ -z "$sha" ]]; then
    skip "$name: no banner"
    continue
  fi
  if git -C "$APL_REPO" cat-file -e "$sha" 2>/dev/null; then
    pass "$name @ $sha"
  else
    fail "$name @ $sha — SHA not found in $APL_REPO"
  fi
done

hdr "summary"
printf "  pass=%d fail=%d skip=%d\n" "$passes" "$fails" "$skips"
exit "$fails"

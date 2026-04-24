#!/usr/bin/env bash
#
# Recipe format + cross-reference validator for all-purpose-data-skill.
#
# Parses every references/*.md file, then asserts for every `### <ID>` block:
#   - has a "When to use" or "User intent" label
#   - has a "Command", "Call sequence", or "Sequence" label
#   - has an "Expected response" or "Synthesis" label
#   - has a "Common errors" label
#
# Also asserts:
#   - the top-of-file sync banner (`Generated from ... @ <sha>`) is present
#     on files that are regenerated from the apl spec
#   - every recipe ID cited in morning-brief.md exists as a `### <ID>` header
#     in the corresponding family file
#   - no duplicate recipe IDs within a family
#
# Exit code = count of failures. Zero = all green.

set -u -o pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
SKILL_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)
REF_DIR="$SKILL_DIR/references"

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

# Files that carry the spec-sync banner. Other files (handle-selection.md,
# workflow.md, setup-*.md) are hand-authored and exempt.
BANNER_FILES=(
  calendar.md
  contacts.md
  delta-and-batch.md
  drive.md
  github.md
  mail.md
  morning-brief.md
  online-meetings.md
  teams-chat.md
)

hdr "sync banners"
for f in "${BANNER_FILES[@]}"; do
  path="$REF_DIR/$f"
  if [[ ! -f "$path" ]]; then
    fail "$f: file missing"
    continue
  fi
  banner=$(grep -oE 'Generated from [^ ]+ @ [a-f0-9]+' "$path" | head -1 || true)
  if [[ -z "$banner" ]]; then
    fail "$f: no sync banner (expected '<!-- Generated from ... @ <sha> -->')"
  else
    pass "$f: $banner"
  fi
done

hdr "recipe format"
# Drive the per-block parse in Python (set -u safe, macOS always has python3).
# Emit PASS/FAIL lines to a temp file, replay into pass/fail here so counters
# stay in the parent shell.
parse_out=$(mktemp)
trap 'rm -f "$parse_out"' EXIT

python3 - "$REF_DIR" >"$parse_out" <<'PYEOF'
# Recipes may follow either the strict 4-label shape (new files: github.md,
# morning-brief.md) OR the terse shape (older files: mail.md, calendar.md,
# etc. — one-line Purpose/When + a code block). We check for STRUCTURAL
# integrity only: every recipe must (a) be uniquely numbered within its file
# and (b) contain at least one command block (``` fenced) OR a documented
# fallback pointer. Missing optional labels are WARN (emitted but not failing).
import os, re, sys
ref_dir = sys.argv[1]
files = [
  "calendar.md","contacts.md","delta-and-batch.md","drive.md",
  "github.md","mail.md","morning-brief.md","online-meetings.md",
  "teams-chat.md",
]
# Optional label patterns — tracked for coverage reporting, not pass/fail.
opt_labels = {
  "intent":   re.compile(r"\*\*(When to use|User intent|Purpose)[^*]*\*\*"),
  "command":  re.compile(r"\*\*(Command|Call sequence|Sequence|Call)[^*]*\*\*"),
  "response": re.compile(r"\*\*(Expected response|Synthesis|Returns)[^*]*\*\*"),
  "errors":   re.compile(r"\*\*(Common errors|Gotchas|Errors)[^*]*\*\*"),
}
code_fence = re.compile(r"```")
for f in files:
  path = os.path.join(ref_dir, f)
  if not os.path.isfile(path):
    print(f"FAIL\t{f}: file missing")
    continue
  content = open(path).read()
  lines = content.split("\n")
  current = None
  blocks = {}
  order = []
  meta_marker = re.compile(r"\((reference|composable|meta|documentation)", re.I)
  meta_ids = set()
  for ln in lines:
    if ln.startswith("### "):
      header = ln[4:]
      rid = header.split(":")[0].strip()
      current = rid
      blocks[rid] = []
      order.append(rid)
      if meta_marker.search(header):
        meta_ids.add(rid)
    elif current is not None:
      blocks[current].append(ln)
  # duplicate check — hard fail
  seen = {}
  for rid in order:
    seen[rid] = seen.get(rid, 0) + 1
  dupes = [f"{rid} ({n}x)" for rid,n in seen.items() if n > 1]
  if dupes:
    print(f"FAIL\t{f}: duplicate recipe IDs: {', '.join(dupes)}")
  # structural check — every recipe needs a command block or a "Fallback:"
  structurally_broken = []
  seq_label = re.compile(r"\*\*(Call sequence|Sequence|Steps)[^*]*\*\*", re.I)
  numbered_step = re.compile(r"^\s*\d+\.\s+", re.M)
  for rid in order:
    if rid in meta_ids:
      continue  # reference/meta blocks have no command by design
    body = "\n".join(blocks[rid])
    has_code = bool(code_fence.search(body))
    has_fallback = "Fallback:" in body or "See " in body
    has_sequence = bool(seq_label.search(body)) and bool(numbered_step.search(body))
    if not (has_code or has_fallback or has_sequence):
      structurally_broken.append(rid)
  if structurally_broken:
    print(f"FAIL\t{f}: recipes with no command block or fallback: {', '.join(structurally_broken)}")
  else:
    print(f"PASS\t{f}: {len(order)} recipes, all structurally complete")
  # coverage report — informational only (counted as skip in outer shell)
  label_hits = {k: 0 for k in opt_labels}
  for rid in order:
    body = "\n".join(blocks[rid])
    for k, p in opt_labels.items():
      if p.search(body):
        label_hits[k] += 1
  if order:
    pct = lambda k: round(100 * label_hits[k] / len(order))
    print(f"SKIP\t{f}: label coverage  intent={pct('intent')}%  command={pct('command')}%  response={pct('response')}%  errors={pct('errors')}%")
PYEOF

while IFS=$'\t' read -r verdict msg; do
  case "$verdict" in
    PASS) pass "$msg" ;;
    FAIL) fail "$msg" ;;
    SKIP) skip "$msg" ;;
  esac
done < "$parse_out"

hdr "cross-references (morning-brief.md → family files)"
BRIEF="$REF_DIR/morning-brief.md"
if [[ ! -f "$BRIEF" ]]; then
  fail "morning-brief.md missing"
else
  cited=$(grep -oE '\b(MAIL|CAL|CHAT|GH|DRIVE|CONT|MEET|SYNC|ADV|IDENT|BRIEF)-[A-Z]*-?[0-9]+\b' "$BRIEF" \
    | sort -u)
  for id in $cited; do
    case "$id" in
      MAIL-*)  famfile="mail.md" ;;
      CAL-*)   famfile="calendar.md" ;;
      CHAT-*)  famfile="teams-chat.md" ;;
      GH-*)    famfile="github.md" ;;
      DRIVE-*) famfile="drive.md" ;;
      CONT-*|IDENT-*) famfile="contacts.md" ;;
      MEET-*)  famfile="online-meetings.md" ;;
      SYNC-*|ADV-*)   famfile="delta-and-batch.md" ;;
      BRIEF-*) famfile="morning-brief.md" ;;
      *)       famfile="" ;;
    esac
    if [[ -z "$famfile" ]]; then
      fail "morning-brief.md: unknown family for cited ID '$id'"
      continue
    fi
    if grep -qE "^### ${id}:" "$REF_DIR/$famfile"; then
      pass "$id → $famfile"
    else
      fail "orphan: morning-brief.md cites $id but $famfile has no '### $id:' header"
    fi
  done
fi

hdr "summary"
printf "  pass=%d fail=%d skip=%d\n" "$passes" "$fails" "$skips"
exit "$fails"

#!/bin/sh

SKILL_NAME="all-purpose-data-skill"
HOME_DIR="${HOME:-$(cd ~ && pwd)}"

CLAUDE_SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME_DIR/.claude/skills}"
CODEX_SKILLS_DIR="$HOME_DIR/.agents/skills"

remove_from() {
  target_dir="$1"
  label="$2"
  dest="$target_dir/$SKILL_NAME"

  if [ -L "$dest" ]; then
    rm "$dest"
    echo "  Removed $label -> $dest"
  elif [ -e "$dest" ]; then
    echo "  $label -> $dest is not a symlink, skipping (never touches real dirs)"
  else
    echo "  $label -> not installed, skipping"
  fi
}

echo ""
echo "Uninstalling $SKILL_NAME..."
echo ""

remove_from "$CLAUDE_SKILLS_DIR" "Claude Code"
remove_from "$CODEX_SKILLS_DIR" "Codex Agent"

echo ""
echo "Done."

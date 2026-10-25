#!/usr/bin/env bash
#
# Keep ~/.claude/scripts/notify.sh in step with the installed plugin.
#
# Why this exists: ${CLAUDE_PLUGIN_ROOT} is set for hooks and commands, but NOT
# for a skill's or a subagent's Bash. So the kit's skills call a stable path,
# ~/.claude/scripts/notify.sh, and that copy would otherwise drift behind every
# plugin update — silently, since notify.sh exits 0 when it cannot deliver.
#
# It also records the plugin root in ~/.claude/project-setup-kit.root, so a
# skill can find the kit's files with one `cat` instead of searching the disk.
#
# This runs on SessionStart, copies only when the files actually differ, and
# always exits 0. A sync failure must never block a session from starting.

set -u

ROOT="${CLAUDE_PLUGIN_ROOT:-}"
[ -n "$ROOT" ] && [ -d "$ROOT" ] || exit 0

# Root file: write a temp file, then mv, so a reader never sees half a path.
ROOT_FILE="$HOME/.claude/project-setup-kit.root"
if mkdir -p "$HOME/.claude" 2>/dev/null; then
  TMP="$(mktemp "$HOME/.claude/.project-setup-kit.root.XXXXXX" 2>/dev/null)" \
    && printf '%s\n' "$ROOT" > "$TMP" 2>/dev/null \
    && mv -f "$TMP" "$ROOT_FILE" 2>/dev/null \
    || rm -f "${TMP:-}" 2>/dev/null
fi

SRC="$ROOT/scripts/notify.sh"
DEST="$HOME/.claude/scripts/notify.sh"

[ -r "$SRC" ] || exit 0
cmp -s "$SRC" "$DEST" 2>/dev/null && exit 0

mkdir -p "$(dirname "$DEST")" 2>/dev/null || exit 0
cp "$SRC" "$DEST" 2>/dev/null && chmod +x "$DEST" 2>/dev/null
exit 0

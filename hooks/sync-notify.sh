#!/usr/bin/env bash
#
# Keep ~/.claude/scripts/notify.sh in step with the installed plugin.
#
# Why this exists: ${CLAUDE_PLUGIN_ROOT} is set for hooks and commands, but NOT
# for a skill's or a subagent's Bash. So the kit's skills call a stable path,
# ~/.claude/scripts/notify.sh, and that copy would otherwise drift behind every
# plugin update — silently, since notify.sh exits 0 when it cannot deliver.
#
# This runs on SessionStart, copies only when the files actually differ, and
# always exits 0. A sync failure must never block a session from starting.

set -u

SRC="${CLAUDE_PLUGIN_ROOT:-}/scripts/notify.sh"
DEST="$HOME/.claude/scripts/notify.sh"

[ -r "$SRC" ] || exit 0
cmp -s "$SRC" "$DEST" 2>/dev/null && exit 0

mkdir -p "$(dirname "$DEST")" 2>/dev/null || exit 0
cp "$SRC" "$DEST" 2>/dev/null && chmod +x "$DEST" 2>/dev/null
exit 0

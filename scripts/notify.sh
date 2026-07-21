#!/usr/bin/env bash
#
# notify.sh — reach the human through Pushover, ONLY when something is needed from them.
#
# Three modes:
#   ask       work is stopped on the user. Priority 1 (bypasses quiet hours).
#             ONE push per stop, however many questions the stop carries:
#               - one question  → the four-field form (what/options/recommend/blocks)
#               - N questions   → --count N + a one-line-per-question --what summary;
#                                 the full detail lives at the terminal, not in the push.
#             Enforces the Ask Contract — see ASK_CONTRACT.md. Missing a piece = exit 2.
#   hook      reads a Claude Code Notification-hook JSON payload on stdin. Sends
#             (silently, priority -1) ONLY when Claude is actually waiting on the
#             user — a permission prompt or a question. Every other notification
#             is dropped. Deduped per project for 5 minutes.
#   selftest  prove the wiring works. The ONLY mode that fails loudly.
#
# ask/hook ALWAYS exit 0 on a delivery failure. A notification that can fail a
# build is worse than no notification. Delivery problems go to stderr only.
#
# Credentials, first hit wins:
#   1. $PUSHOVER_TOKEN + $PUSHOVER_USER already in the environment
#   2. ./.env                 (project-local override)
#   3. ~/.claude/pushover.env (the normal home for them)
#
# Set PUSHOVER_DISABLED=1 to make every mode a silent no-op except selftest.

set -uo pipefail

API="https://api.pushover.net/1/messages.json"
HOOK_DEDUPE=300   # seconds; asks are never suppressed

load_creds() {
  [ -n "${PUSHOVER_TOKEN:-}" ] && [ -n "${PUSHOVER_USER:-}" ] && return 0
  local f
  for f in "./.env" "${HOME}/.claude/pushover.env"; do
    [ -r "$f" ] || continue
    # shellcheck disable=SC1090
    set -a; . "$f"; set +a
    [ -n "${PUSHOVER_TOKEN:-}" ] && [ -n "${PUSHOVER_USER:-}" ] && return 0
  done
  return 1
}

project_name() {
  local root
  root=$(git rev-parse --show-toplevel 2>/dev/null) && { basename "$root"; return; }
  basename "$PWD"
}

send() {
  local title="$1" message="$2" priority="$3"

  if [ "${PUSHOVER_DISABLED:-}" = "1" ]; then
    printf 'notify: PUSHOVER_DISABLED=1 — not sending: %s\n' "$title" >&2
    return 0
  fi
  if ! load_creds; then
    printf 'notify: no Pushover credentials ($PUSHOVER_TOKEN/$PUSHOVER_USER, ./.env, ~/.claude/pushover.env).\nnotify: undelivered:\n%s\n%s\n' "$title" "$message" >&2
    return 0
  fi
  if [ "${#message}" -gt 1000 ]; then
    message="${message:0:980}"$'\n[truncated]'
  fi

  local body http
  body=$(mktemp)
  http=$(curl -sS --max-time 15 -o "$body" -w '%{http_code}' \
    --form-string "token=${PUSHOVER_TOKEN}" \
    --form-string "user=${PUSHOVER_USER}" \
    --form-string "title=${title}" \
    --form-string "message=${message}" \
    --form-string "priority=${priority}" \
    "$API" 2>&1)
  local rc=$? out; out=$(cat "$body" 2>/dev/null); rm -f "$body"

  if [ "$rc" -ne 0 ] || [ "$http" != "200" ] || ! printf '%s' "$out" | grep -q '"status":1'; then
    printf 'notify: Pushover delivery failed (curl rc=%s http=%s): %s\n' "$rc" "$http" "$out" >&2
    return 1
  fi
  return 0
}

dedupe_ok() {
  local key
  key=$(printf '%s' "$1" | cksum | tr -d ' \t/')
  local stamp="${TMPDIR:-/tmp}/notify-pushover-${key}"
  if [ -f "$stamp" ]; then
    local age=$(( $(date +%s) - $(stat -f %m "$stamp" 2>/dev/null || stat -c %Y "$stamp" 2>/dev/null || echo 0) ))
    [ "$age" -lt "$HOOK_DEDUPE" ] && return 1
  fi
  : > "$stamp"
  return 0
}

contract_error() {
  cat >&2 <<'EOF'
notify: this ask does not meet the Ask Contract, so it was NOT sent.

ONE push per stop. Two valid shapes (see ASK_CONTRACT.md):

Single question — all four fields, answerable from a lock screen:
  notify.sh ask \
    --what "Two people can edit the same list at once and I must decide what happens." \
    --option "Last edit wins — simple, but one person's change can vanish silently." \
    --option "Lock while editing — nothing lost, but the second person waits." \
    --recommend "Last edit wins; it's a shopping list. I'd rethink if >2 concurrent editors." \
    --blocks "The sync design and the 6 stories under it."
  (--open replaces the options when the answer is a fact only the user has.)

Several questions — ONE summary push, never one push each:
  notify.sh ask --count 3 \
    --what "1) What happens when two people edit at once. 2) Can a member leave with unpaid balances. 3) Who can delete a list." \
    --blocks "The design gate; backlog cannot start."
  Full options + recommendations for each go to the terminal / OPEN_QUESTIONS.md.
EOF
  exit 2
}

mode="${1:-}"; shift || true

case "$mode" in

  ask)
    what="" recommend="" blocks="" title="" open=0 count=0
    options=()
    while [ $# -gt 0 ]; do
      case "$1" in
        --what)      what="${2:-}"; shift 2 ;;
        --option)    options+=("${2:-}"); shift 2 ;;
        --recommend) recommend="${2:-}"; shift 2 ;;
        --blocks)    blocks="${2:-}"; shift 2 ;;
        --title)     title="${2:-}"; shift 2 ;;
        --count)     count="${2:-0}"; shift 2 ;;
        --open)      open=1; shift ;;
        *) printf 'notify: unknown flag for ask: %s\n' "$1" >&2; exit 2 ;;
      esac
    done

    [ -n "$what" ] && [ "${#what}" -ge 30 ] || contract_error
    if [ "$count" -lt 2 ]; then
      [ -n "$recommend" ] || contract_error
      if [ "$open" -eq 0 ] && [ "${#options[@]}" -lt 2 ]; then contract_error; fi
    fi
    case "$what$recommend${options[*]-}" in *'{{'*) printf 'notify: unresolved {{placeholder}} in the ask.\n' >&2; exit 2 ;; esac

    proj=$(project_name)

    if [ "$count" -ge 2 ]; then
      [ -n "$title" ] || title="${count} questions need answers"
      msg="WHAT'S STUCK
${what}

${count} decisions are waiting. Each has options and a recommendation at the terminal (and in OPEN_QUESTIONS.md)."
    else
      [ -n "$title" ] || title="needs your call"
      msg="WHAT'S STUCK
${what}
"
      if [ "$open" -eq 1 ]; then
        msg="${msg}
NO CLEAN OPTIONS — this needs information only you have.
"
      else
        msg="${msg}
YOUR OPTIONS"
        i=1
        for o in "${options[@]}"; do
          msg="${msg}
${i}. ${o}"
          i=$((i+1))
        done
        msg="${msg}
"
      fi
      msg="${msg}
WHAT I'D DO
${recommend}"
    fi
    [ -n "$blocks" ] && msg="${msg}

BLOCKS UNTIL ANSWERED
${blocks}"
    msg="${msg}

— ${proj} · $(hostname -s 2>/dev/null || echo local)"

    send "[${proj}] ${title}" "$msg" 1 || true
    exit 0
    ;;

  hook)
    # Claude Code Notification hook: JSON on stdin. Push ONLY when Claude is
    # actually waiting on the user; drop every other notification unheard.
    payload=$(cat 2>/dev/null || echo '{}')
    text=$(printf '%s' "$payload" | jq -r '.message // empty' 2>/dev/null)
    dir=$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)
    printf '%s' "$text" | grep -qiE 'permission|waiting|input|question|approv|needs you' || exit 0
    [ -n "$dir" ] && proj=$(basename "$dir") || proj=$(project_name)
    dedupe_ok "${proj}-hook" || exit 0
    send "[${proj}] waiting for you" "$text" -1 || true
    exit 0
    ;;

  selftest)
    if ! load_creds; then
      printf 'FAIL: no Pushover credentials.\nCreate ~/.claude/pushover.env (see scripts/pushover.env.example).\n' >&2
      exit 1
    fi
    proj=$(project_name)
    if send "[${proj}] notify selftest" "If you can read this, the harness can reach you. Nothing is wrong." -1; then
      printf 'OK: Pushover delivered. Check your phone.\n'
      exit 0
    fi
    printf 'FAIL: credentials loaded but Pushover rejected the message (see above).\n' >&2
    exit 1
    ;;

  *)
    cat >&2 <<'EOF'
notify.sh — reach the human ONLY when something is needed from them.

  notify.sh ask [--count N] --what "..." [--option "..." --option "..." --recommend "..."] [--blocks "..."] [--open] [--title "..."]
      Work is stopped on the user. ONE push per stop: four-field form for a
      single question, --count N + numbered summary for several. Priority 1.

  notify.sh hook
      Claude Code Notification hook (JSON on stdin). Pushes silently, only
      when Claude is waiting on the user; drops everything else. 5-min dedupe.

  notify.sh selftest
      Send a test push. Exits non-zero if it did not arrive.

ask/hook never fail the caller. selftest does.
EOF
    exit 2
    ;;
esac

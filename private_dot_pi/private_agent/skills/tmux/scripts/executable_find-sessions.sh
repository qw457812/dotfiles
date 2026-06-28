#!/usr/bin/env bash
set -eu
set -o pipefail

usage() {
  cat <<'USAGE'
Usage: find-sessions.sh [-L socket-name|-S socket-path|-A] [-q pattern]

List tmux sessions on a socket (default tmux socket if none provided).

Options:
  -L, --socket       tmux socket name (passed to tmux -L)
  -S, --socket-path  tmux socket path (passed to tmux -S)
  -A, --all          scan all sockets under CLAUDE_TMUX_SOCKET_DIR
  -q, --query        case-insensitive substring to filter session names
  -h, --help         show this help
USAGE
}

socket_name=""
socket_path=""
query=""
scan_all=false
socket_dir="${CLAUDE_TMUX_SOCKET_DIR:-${TMPDIR:-/tmp}/claude-tmux-sockets}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -L|--socket)      socket_name="${2-}"; shift 2 ;;
    -S|--socket-path) socket_path="${2-}"; shift 2 ;;
    -A|--all)         scan_all=true; shift ;;
    -q|--query)       query="${2-}"; shift 2 ;;
    -h|--help)        usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ "$scan_all" == true && ( -n "$socket_name" || -n "$socket_path" ) ]]; then
  echo "Cannot combine --all with -L or -S" >&2
  exit 1
fi

if [[ -n "$socket_name" && -n "$socket_path" ]]; then
  echo "Use either -L or -S, not both" >&2
  exit 1
fi

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux not found in PATH" >&2
  exit 1
fi

list_sessions() {
  local label="$1"; shift
  local sep=$'\037'

  if ! sessions="$(tmux "$@" list-sessions -F "#{session_name}${sep}#{session_attached}${sep}#{t:session_created}" 2>&1)"; then
    echo "Failed to list tmux sessions on $label" >&2
    printf '%s\n' "$sessions" >&2
    return 1
  fi

  if [[ -n "$query" ]]; then
    sessions="$(printf '%s\n' "$sessions" | grep -i -e "$query" || true)"
  fi

  if [[ -z "$sessions" ]]; then
    echo "No sessions found on $label"
    return 0
  fi

  echo "Sessions on $label:"
  printf '%s\n' "$sessions" | while IFS="$sep" read -r name attached created; do
    attached_label=$([[ "$attached" == "1" ]] && echo "attached" || echo "detached")
    printf '  - %s (%s, started %s)\n' "$name" "$attached_label" "$created"
  done
}

if [[ "$scan_all" == true ]]; then
  if [[ ! -d "$socket_dir" ]]; then
    echo "Socket directory not found: $socket_dir" >&2
    exit 1
  fi

  found=false
  exit_code=0
  for sock in "$socket_dir"/*; do
    if [[ ! -e "$sock" ]]; then
      continue
    fi
    if [[ ! -S "$sock" && "$sock" != *.sock ]]; then
      continue
    fi
    if ! sessions_probe="$(tmux -S "$sock" list-sessions 2>&1)"; then
      case "$sessions_probe" in
        "no server running on "*)
          continue
          ;;
        *)
          echo "Failed to list tmux sessions on socket path '$sock'" >&2
          printf '%s\n' "$sessions_probe" >&2
          exit_code=1
          continue
          ;;
      esac
    fi
    found=true
    list_sessions "socket path '$sock'" -S "$sock" || exit_code=$?
  done

  if [[ "$found" != true && "$exit_code" -eq 0 ]]; then
    echo "No live tmux sessions found under $socket_dir" >&2
    exit 1
  fi

  exit "$exit_code"
fi

socket_label="default socket"

if [[ -n "$socket_name" ]]; then
  socket_label="socket name '$socket_name'"
  list_sessions "$socket_label" -L "$socket_name"
elif [[ -n "$socket_path" ]]; then
  socket_label="socket path '$socket_path'"
  list_sessions "$socket_label" -S "$socket_path"
else
  list_sessions "$socket_label"
fi

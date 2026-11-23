---
name: interactive-testing
description: Test and debug interactive terminal applications in a controlled tmux terminal. Use for TUI behavior checks and interactive smoke tests.
---

# Interactive Testing with tmux

Test interactive terminal applications in a fresh, fixed-size tmux session with
a unique socket. Wait after startup and interactions, send literal text separately
from special keys, inspect captured output, and clean up. The example below runs
Pi; replace it with the app under test:

```bash
TEMP_DIR="${TMPDIR:-/tmp}"
SOCKET_DIR="${CLAUDE_TMUX_SOCKET_DIR:-$TEMP_DIR/claude-tmux-sockets}"
SESSION="tui-test-$(date +%s)-$$"
SOCKET="$SOCKET_DIR/$SESSION.sock"
TARGET="$SESSION:0.0"

mkdir -p "$SOCKET_DIR"
tmux -S "$SOCKET" -f /dev/null new-session -d -s "$SESSION" -c "$TEMP_DIR" -x 80 -y 24 'pi --no-session'
sleep 3
tmux -S "$SOCKET" capture-pane -p -J -t "$TARGET" -S -200
tmux -S "$SOCKET" send-keys -t "$TARGET" -l -- '/hotkeys'
tmux -S "$SOCKET" send-keys -t "$TARGET" Enter
sleep 1
tmux -S "$SOCKET" capture-pane -p -J -t "$TARGET" -S -200
tmux -S "$SOCKET" kill-session -t "$SESSION"
```

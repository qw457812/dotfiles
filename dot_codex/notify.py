#!/usr/bin/env python3
import json
import os
import platform
import subprocess
import sys


def main() -> int:
    notification = json.loads(sys.argv[1])
    if notification.get("type") != "agent-turn-complete":
        return 0

    title = f"Codex: {notification.get('last-assistant-message', 'Turn Complete!')}"
    message = " ".join(notification.get("input-messages", []))
    group = "codex-" + notification.get("thread-id", "")

    if platform.system() == "Darwin":
        script = """on run argv
    display notification (item 2 of argv) with title (item 1 of argv)
end run"""
        subprocess.check_output(["osascript", "-e", script, title, message])
    elif os.environ.get("TERMUX_VERSION"):
        subprocess.check_output(
            [
                "termux-notification",
                "--title",
                title,
                "--content",
                message,
                "--group",
                group,
            ]
        )
    else:
        return 0

    return 0


if __name__ == "__main__":
    sys.exit(main())

import re

from kittens.tui.handler import result_handler
from kitty.boss import Boss
from kitty.key_encoding import KeyEvent, parse_shortcut


# copied from: https://github.com/knubie/vim-kitty-navigator/blob/081c6f8f9eb17cddb4ff4cd1ad44db48aa76fe03/pass_keys.py#L12-L25
def encode_key_mapping(window, key_mapping):
    mods, key = parse_shortcut(key_mapping)
    event = KeyEvent(
        mods=mods,
        key=key,
        shift=bool(mods & 1),
        alt=bool(mods & 2),
        ctrl=bool(mods & 4),
        super=bool(mods & 8),
        hyper=bool(mods & 16),
        meta=bool(mods & 32),
    ).as_window_system_event()

    return window.encoded_key(event)


def is_nvim(cmd):
    return re.search("n?vim", cmd, re.I) is not None


def is_tmux(cmd):
    return cmd == "tmux"


def is_yazi(cmd):
    return cmd == "yazi"


def is_fzf(window):
    fp = window.child.foreground_processes
    return any(
        p.get("cmdline") and len(p["cmdline"]) > 0 and p["cmdline"][0] == "fzf"
        for p in fp
    )


def main():
    pass


# https://github.com/kovidgoyal/kitty/blob/41a3519ebb9949955cc97c95253a830788ddaf49/docs/kittens/custom.rst
@result_handler(no_ui=True)
def handle_result(
    args: list[str], result: str, target_window_id: int, boss: Boss
) -> None:
    w = boss.window_id_map.get(target_window_id)
    if w is None:
        return

    direction = args[1]
    key = args[2]

    # # debugging: run `kitty` from another kitty instance
    # print(f"""neighboring_window_or_pass_key.py:
    # {{
    #   is_main_linebuf: {w.screen.is_main_linebuf()}
    #   cmd: {w.child.foreground_cmdline}
    #   fp: {w.child.foreground_processes}
    # }}""")

    cmd = w.child.foreground_cmdline[0]
    # https://github.com/yurikhan/kitty-smart-scroll/blob/8aaa91b9f52527c3dbe395a79a90aea4a879857a/smart_scroll.py#L18
    # yazi: for cmp like `cd --interactive`
    if w.screen.is_main_linebuf() or not (
        is_nvim(cmd)
        or is_tmux(cmd)
        or ((key == "ctrl+j" or key == "ctrl+k") and (is_fzf(w) or is_yazi(cmd)))
    ):
        # # kitten @ focus-window --match=neighbor:bottom
        # boss.call_remote_control(w, ("focus-window", f"--match=neighbor:{direction}"))
        boss.active_tab.neighboring_window(direction)
    else:
        # pass the keys through to nvim/tmux/fzf
        w.write_to_child(encode_key_mapping(w, key))

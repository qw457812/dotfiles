from kittens.tui.handler import result_handler
from kitty.boss import Boss
from kitty.key_encoding import KeyEvent, parse_shortcut


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


def main():
    pass


@result_handler(no_ui=True)
def handle_result(
    args: list[str], result: str, target_window_id: int, boss: Boss
) -> None:
    w = boss.window_id_map.get(target_window_id)
    if w is None:
        return

    if w.child.foreground_cmdline[0] == "lazygit":
        # make <bs> close the lazygit
        # mapped <c-h> to quit in lazygit/config.yml via `quitWithoutChangingDirectory: <backspace>`
        # when typing a commit message in lazygit, <c-h> and <bs> do the same thing
        # tcell doesn't handle kitty keyboard protocol's CSI-u backspace correctly
        # with <backspace> keybinding, so send raw \x08 (ASCII BS) instead
        w.write_to_child(b"\x08")
    else:
        w.write_to_child(encode_key_mapping(w, "backspace"))

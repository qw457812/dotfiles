import { View, div } from "gpui-kit";
import { checking, closeOverlay, focused, notify, props, run } from "herdr";

const script = `
source_tab=$2
cleanup() {
  [ -z "$scrollback" ] || rm -f "$scrollback"
  if [ -n "$HC_TERMINAL_ID" ]; then
    nohup sh -c 'hc kill "$1"; sleep 0.5; herdr-app do tab.select --id "$2"' _ "$HC_TERMINAL_ID" "$source_tab" </dev/null >/dev/null 2>&1 &
  fi
}
trap cleanup EXIT
scrollback=$(mktemp) || exit 1
hc read --lines 50000 "$1" > "$scrollback" &&
  nvim --cmd 'lua vim.g.terminal_scrollback_pager = true' -c 'normal! G' -- "$scrollback"
`;

export default class CopyMode extends View {
  init() {
    if (checking()) return;
    const { terminal, tab } = focused() ?? {};
    closeOverlay(props().overlay);
    if (!terminal || !tab) {
      notify({ title: "Copy mode", body: "Focus a terminal first.", level: "warning" });
      return;
    }
    run("terminal.open", {
      name: "Scrollback",
      place: "tab",
      argv: ["sh", "-c", script, "herdr-copy-mode", terminal, tab],
    });
  }

  render() {
    return div();
  }
}

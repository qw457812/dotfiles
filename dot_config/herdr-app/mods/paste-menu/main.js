// Right-click in a terminal pastes instead of opening Herdr's menu.
import { View, div } from "gpui-kit";
import { checking, closeOverlay, panes, props, run } from "herdr";

export default class PasteMenu extends View {
  init(_props, _cx) {
    if (checking()) return;
    const { target, overlay } = props();
    // terminal.paste reads the focused terminal, so focus the one clicked.
    // Terminals outside a tab (a window, a float) cannot take pane.focus;
    // pasting then would land in whatever is focused, so leave them alone.
    if (target?.terminal && panes().some((pane) => pane.terminal === target.terminal)) {
      run("pane.focus", { terminal: target.terminal });
      run("terminal.paste", {});
    }
    closeOverlay(overlay);
  }

  render() {
    return div();
  }
}

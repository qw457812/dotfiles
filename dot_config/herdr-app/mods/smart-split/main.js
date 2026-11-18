import { View, div } from "gpui-kit";
import { checking, closeOverlay, focused, hc, notify, props, run } from "herdr";

export default class SmartSplit extends View {
  init(_props, cx) {
    if (checking()) return;
    const focus = focused();
    const terminal = focus?.shown ?? focus?.terminal;
    const overlay = props().overlay;
    cx.spawn(async () => {
      try {
        if (!focus?.pane || !terminal) throw new Error("Focus a terminal pane first.");
        const result = await hc(["get", terminal, "--json"]);
        if (result.code !== 0)
          throw new Error(result.stderr || "Could not read terminal dimensions.");
        const { cols, rows } = JSON.parse(result.stdout);
        if (!(cols > 0 && rows > 0)) throw new Error("Terminal dimensions are unavailable.");
        if (focused()?.pane !== focus.pane) return;
        // Terminal cells are roughly twice as tall as wide: split the longer axis.
        run("pane.split", { pane: focus.pane, direction: cols > rows * 2 ? "right" : "down" });
      } catch (error) {
        notify({ title: "Smart split", body: String(error), level: "error" });
      } finally {
        closeOverlay(overlay);
      }
    });
  }

  render() {
    return div();
  }
}

// Loaded only for Sidekick's Pi process. Don't preload it in Pi's child processes.
const originalNodeOptions = process.env.PI_OSC7501_ORIGINAL_NODE_OPTIONS;
if (originalNodeOptions !== undefined) {
  delete process.env.PI_OSC7501_ORIGINAL_NODE_OPTIONS;
  if (originalNodeOptions) {
    process.env.NODE_OPTIONS = originalNodeOptions;
  } else {
    delete process.env.NODE_OPTIONS;
  }

  if (process.env.TMUX && process.stdout.isTTY) {
    const write = process.stdout.write;
    process.stdout.write = function (chunk, ...args) {
      // Wrap only complete OSC 7501 reports, not queries or ordinary TUI output.
      if (
        typeof chunk === "string" &&
        /^\x1b\]7501;state=[^\x1b\x07]*(?:\x07|\x1b\\)$/.test(chunk)
      ) {
        chunk = "\x1bPtmux;" + chunk.replaceAll("\x1b", "\x1b\x1b") + "\x1b\\";
      }
      return write.call(this, chunk, ...args);
    };
  }
}

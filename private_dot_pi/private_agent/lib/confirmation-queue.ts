import type { ExtensionContext } from "@earendil-works/pi-coding-agent";

// Pi contexts share one UI object. Tool guards must not replace each other's dialogs.
const queues = new WeakMap<ExtensionContext["ui"], Promise<void>>();

export async function withConfirmationQueue<T>(
  ui: ExtensionContext["ui"],
  run: () => Promise<T>,
): Promise<T> {
  const previous = queues.get(ui) ?? Promise.resolve();
  let release!: () => void;
  const next = new Promise<void>((resolve) => {
    release = resolve;
  });
  queues.set(ui, next);
  await previous;
  try {
    return await run();
  } finally {
    release();
    if (queues.get(ui) === next) queues.delete(ui);
  }
}

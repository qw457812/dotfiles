// Config docs:
//
//   https://glide-browser.app/config
//
// API reference:
//
//   https://glide-browser.app/api
//
// Default config files can be found here:
//
//   https://github.com/glide-browser/glide/tree/main/src/glide/browser/base/content/plugins
//
// Most default keymappings are defined here:
//
//   https://github.com/glide-browser/glide/blob/main/src/glide/browser/base/content/plugins/keymaps.mts
//
// Try typing `glide.` and see what you can do!

// https://support.mozilla.org/en-US/kb/keyboard-shortcuts-perform-firefox-tasks-quickly

// https://github.com/RobertCraigie/dotfiles/blob/ecfd6f66e8a775c80849f7889f297ef99cea7997/glide/glide.ts

// https://github.com/mozilla-firefox/firefox/blob/e2e91539047e030b956e01fd5e8c28c074ae3f88/services/settings/dumps/main/search-config-v2.json
const search_engines = {
  g: "https://www.google.com/search?q={}",
  b: "https://www.bing.com/search?q={}",
  d: "https://duckduckgo.com/?q={}",
  p: "https://www.perplexity.ai/search?q={}",
  bd: "https://www.baidu.com/baidu?wd={}",
  gh: "https://github.com/search?q={}&type=repositories",
  wiki: "https://en.wikipedia.org/wiki/Special:Search?search={}",
} as const;
const default_search_engine = search_engines.g;

if (glide.ctx.os === "macosx") {
  glide.env.set("PATH", `/opt/homebrew/bin:${glide.env.get("PATH")}`);
}

// Options
glide.o.hint_size = "12px";

// Keymaps
glide.keymaps.del("normal", "<leader>f");
glide.keymaps.del("normal", "<leader>d");
glide.keymaps.del("normal", "<leader>r");
glide.keymaps.del("normal", "<leader>R");
glide.keymaps.set(
  "normal",
  "<Esc>",
  when_editing(
    async () => {
      // for case: `<D-f>` -> `<Esc>` -> `<Esc>` (close find bar)
      await glide.keys.send("<Esc>", { skip_mappings: true });

      // defocus the editable element
      await focus_page();
    },
    async () => {
      await glide.keys.send("<Esc>", { skip_mappings: true });

      // // for case: `<D-f>` -> `<C-w>` -> `<Esc>` at https://github.com/glide-browser/glide/blob/e6a590d53c7d6101792fedfd9894491cda46dbde/src/glide/browser/actors/GlideHandlerChild.sys.mts
      // if (await glide.ctx.is_editing()) {
      //   await focus_page();
      // }

      // additional actions we want to perform on esc
      await glide.excmds.execute("clear");
    },
  ),
);
// vimium-like keymaps
// https://github.com/glide-browser/glide/blob/107e240a8fd274cafef403d089dc2b646319e8f8/src/glide/browser/base/content/plugins/keymaps.mts
// TODO: b
glide.keymaps.set("normal", "/", "keys <D-f>");
glide.keymaps.set("normal", "r", when_editing("r", "reload"));
glide.keymaps.set("normal", "R", when_editing(null, "reload_hard"));
glide.keymaps.set("normal", "t", when_editing(null, "tab_new"));
glide.keymaps.set("normal", "T", when_editing(null, "commandline_show tab "));
glide.keymaps.set(
  "normal",
  "yt",
  when_editing(
    null,
    async ({ tab_id }) => await browser.tabs.duplicate(tab_id),
  ),
);
glide.keymaps.set("normal", "yf", () => {
  glide.hints.show({
    action: async (target) => {
      if ("href" in target && typeof target.href === "string") {
        navigator.clipboard.writeText(target.href);
      }
    },
  });
});
glide.keymaps.set(
  "normal",
  "ym",
  when_editing(null, async ({ tab_id }) => {
    const tab = await browser.tabs.get(tab_id);
    await navigator.clipboard.writeText(`[${tab.title}](${tab.url})`);
  }),
);
glide.keymaps.set(
  "normal",
  "p",
  when_editing(null, async () => {
    const url = text_to_url(await navigator.clipboard.readText());
    await browser.tabs.update({ url });
  }),
);
glide.keymaps.set(
  "normal",
  "P",
  when_editing(null, async () => {
    const url = text_to_url(await navigator.clipboard.readText());
    await browser.tabs.create({ url });
  }),
);
glide.keymaps.set(
  "normal",
  "e",
  when_editing("motion e", async () => {
    await glide.keys.send("<D-l>", { skip_mappings: true });
    await sleep(50);
    await glide.excmds.execute("mode_change normal");
    await glide.excmds.execute("caret_move right");
  }),
);
glide.keymaps.set("normal", "gi", async () => {
  await glide.excmds.execute("focusinput last");
  if (!(await glide.ctx.is_editing())) {
    await glide.keys.send("gI");
  }
});
glide.keymaps.set("normal", "gu", async () => {
  const url = new URL(glide.ctx.url);
  const parts = url.pathname.split("/").filter(Boolean);
  assert(parts.length > 0, "Cannot go up: already at root of URL hierarchy");
  parts.pop();
  await browser.tabs.update({
    url: [url.origin, ...parts].filter(Boolean).join("/"),
  });
});
glide.keymaps.set("normal", "gU", async () => {
  const url = new URL(glide.ctx.url);
  await browser.tabs.update({ url: url.origin });
});
glide.keymaps.set("normal", "gs", "keys <D-u>");
glide.keymaps.set(
  "normal",
  "d",
  when_editing("mode_change op-pending --operator=d", async () => {
    // await glide.excmds.execute("scroll_page_down"); // buggy

    // for (let i = 0; i < 4; i++) {
    //   await glide.excmds.execute("caret_move down");
    //   await sleep(20);
    // }

    await glide.keys.send("<PageDown>", { skip_mappings: true });
  }),
  // { retain_key_display: true }, // no way to display key sequence only for editing
);
glide.keymaps.set(
  "normal",
  "u",
  when_editing("undo", async () => {
    // await glide.excmds.execute("scroll_page_up"); // buggy

    // for (let i = 0; i < 4; i++) {
    //   await glide.excmds.execute("caret_move up");
    //   await sleep(20);
    // }

    await glide.keys.send("<PageUp>", { skip_mappings: true });
  }),
);
glide.keymaps.set("normal", "x", when_editing("motion x", "tab_close"));
glide.keymaps.set(
  "normal",
  "X",
  when_editing("motion X", async () => await browser.sessions.restore()),
);
glide.keymaps.set("normal", "h", when_editing("caret_move left", "back"));
glide.keymaps.set("normal", "l", when_editing("caret_move right", "forward"));
glide.keymaps.set("normal", "H", when_editing("motion 0", "caret_move left")); // scroll left?
glide.keymaps.set("normal", "L", when_editing("motion $", "caret_move right")); // scroll right?
glide.keymaps.set("normal", "J", "tab_next");
glide.keymaps.set("normal", "K", "tab_prev");
// track previously active tab
let previousTabId: number | undefined;
browser.tabs.onActivated.addListener((activeInfo) => {
  previousTabId = activeInfo.previousTabId;
});
glide.keymaps.set("normal", "`", async () => {
  if (previousTabId) {
    await browser.tabs.update(previousTabId, { active: true });
  }
});
glide.keymaps.set("normal", "q", async ({ tab_id }) => {
  const tab = await browser.tabs.get(tab_id);
  if (tab.index > 0) {
    await browser.tabs.move(tab_id, { index: tab.index - 1 });
  }
});
glide.keymaps.set(
  "normal",
  "w",
  when_editing("motion w", async ({ tab_id }) => {
    const tab = await browser.tabs.get(tab_id);
    await browser.tabs.move(tab_id, { index: tab.index + 1 });
  }),
);
glide.keymaps.set("normal", "U", "redo");
glide.keymaps.set("normal", "<BS>", "tab_close");
glide.keymaps.set("normal", "<S-BS>", async () => {
  await browser.sessions.restore();
});
glide.keymaps.set("normal", "<C-r>", "config_reload");
glide.keymaps.set("normal", "<C-f>", "hint --location=browser-ui");
// store tab indices before pinning to restore position when unpinning
const tab_indices_before_pin = new Map<number, number>();
browser.tabs.onRemoved.addListener((tabId) => {
  tab_indices_before_pin.delete(tabId);
});
browser.tabs.onDetached.addListener((tabId) => {
  tab_indices_before_pin.delete(tabId);
});
glide.keymaps.set("normal", "<C-p>", async ({ tab_id }) => {
  const tab = await browser.tabs.get(tab_id);
  if (tab.pinned) {
    const orig_idx = tab_indices_before_pin.get(tab_id);
    await browser.tabs.update(tab_id, { pinned: false });
    if (orig_idx !== undefined) {
      await browser.tabs.move(tab_id, { index: orig_idx });
    }
    tab_indices_before_pin.delete(tab_id);
  } else {
    tab_indices_before_pin.set(tab_id, tab.index);
    await browser.tabs.update(tab_id, { pinned: true });
  }
});
glide.keymaps.set("normal", "<leader><BS>", "quit");
glide.keymaps.set("normal", "<leader>,", "commandline_show tab ");
for (let i = 1; i <= 9; i++) {
  glide.keymaps.set("normal", `<leader>${i}`, `keys <D-${i}>`);
}
glide.keymaps.set("normal", "gh", "keys <D-1>");
glide.keymaps.set("normal", "gl", "keys <D-9>");
glide.keymaps.set("normal", "<leader>bH", "keys <D-1>");
glide.keymaps.set("normal", "<leader>bL", "keys <D-9>");
glide.keymaps.set("normal", "<leader>bh", async ({ tab_id }) => {
  const tab = await browser.tabs.get(tab_id);
  const tabs = await browser.tabs.query({ windowId: tab.windowId });
  const tabs_to_close = tabs
    .filter((t) => t.index < tab.index && t.id !== undefined)
    .map((t) => t.id!);
  if (tabs_to_close.length > 0) {
    await browser.tabs.remove(tabs_to_close);
  }
});
glide.keymaps.set("normal", "<leader>bl", async ({ tab_id }) => {
  const tab = await browser.tabs.get(tab_id);
  const tabs = await browser.tabs.query({ windowId: tab.windowId });
  const tabs_to_close = tabs
    .filter((t) => t.index > tab.index && t.id !== undefined)
    .map((t) => t.id!);
  if (tabs_to_close.length > 0) {
    await browser.tabs.remove(tabs_to_close);
  }
});
glide.keymaps.set("normal", "<leader>bo", async ({ tab_id }) => {
  const tab = await browser.tabs.get(tab_id);
  const tabs = await browser.tabs.query({ windowId: tab.windowId });
  const tabs_to_close = tabs
    .filter((t) => t.id !== tab_id && t.id !== undefined)
    .map((t) => t.id!);
  if (tabs_to_close.length > 0) {
    await browser.tabs.remove(tabs_to_close);
  }
});
glide.keymaps.set("normal", "<leader>ba", async ({ tab_id }) => {
  const tab = await browser.tabs.get(tab_id);
  const tabs = await browser.tabs.query({ windowId: tab.windowId });
  const tabs_to_close = tabs
    .filter((t) => !t.pinned && t.id !== undefined)
    .map((t) => t.id!);
  if (tabs_to_close.length > 0) {
    await browser.tabs.remove(tabs_to_close);
  }
});
glide.keymaps.set("normal", "<leader>bb", "keys `");
glide.keymaps.set("normal", "<leader>bp", "keys <C-p>");
glide.keymaps.set("normal", "<leader>fc", async () => {
  const config = `${glide.path.home_dir}/.config/glide/glide.ts`;
  // await glide.process.spawn("kitty", ["-e", "nvim", config]);
  if (glide.ctx.os === "macosx") {
    await glide.process.spawn("open", ["-b", "com.neovide.neovide", config]);
  } else {
    await glide.process.spawn("neovide", [config]);
  }
});
glide.keymaps.set("normal", "<leader>fk", "map");
glide.keymaps.set("normal", "<leader>un", "clear");
glide.keymaps.set("normal", "<leader>g,", "tab_new about:settings");
glide.keymaps.set("normal", "<leader>gg", go_to_tab("https://github.com/"));
glide.keymaps.set(
  "normal",
  "<leader>gs",
  go_to_tab("https://github.com/search"),
);
glide.keymaps.set(
  "normal",
  "<leader>g/",
  go_to_tab("https://github.com/search?type=code"),
);
glide.keymaps.set(
  "normal",
  "<leader>gt",
  go_to_tab("https://github.com/trending"),
);
glide.keymaps.set("normal", "<leader>gi", go_to_tab("https://ossinsight.io/"));
glide.keymaps.set(
  "normal",
  "<leader>g.",
  go_to_tab("https://github.com/qw457812/dotfiles"),
);
glide.keymaps.set(
  "normal",
  "<leader>gG",
  go_to_tab("https://github.com/glide-browser/glide"),
);
glide.keymaps.set(
  "normal",
  "<leader>gK",
  go_to_tab(
    "https://github.com/glide-browser/glide/blob/main/src/glide/browser/base/content/plugins/keymaps.mts",
  ),
);

glide.keymaps.set(["normal", "insert"], "<C-j>", "keys <Down>");
glide.keymaps.set(["normal", "insert"], "<C-k>", "keys <Up>");
// glide.keymaps.set(["normal", "insert"], "<C-n>", "keys <Down>");
// glide.keymaps.set(["normal", "insert"], "<C-p>", "keys <Up>");
glide.keymaps.set(["normal", "insert"], "<C-q>", focus_page);

glide.keymaps.set("insert", "jj", "mode_change normal");
// glide.keymaps.set("insert", "kk", "mode_change normal");

glide.keymaps.set("command", "<c-j>", "commandline_focus_next");
glide.keymaps.set("command", "<c-k>", "commandline_focus_back");

// Autocmds
glide.autocmds.create("ModeChanged", "command:*", focus_page);

glide.autocmds.create("UrlEnter", { hostname: "github.com" }, async () => {
  const url = new URL(glide.ctx.url);
  const [org, repo, ...rest_segments] = url.pathname.split("/").filter(Boolean);

  // it's annoying to be in insert mode when switching tabs
  // maybe do this for all URLs?
  await glide.excmds.execute("mode_change normal");

  glide.buf.keymaps.set(
    "normal",
    "ym",
    when_editing(null, async ({ tab_id }) => {
      const tab = await browser.tabs.get(tab_id);
      if (org && repo && rest_segments.length === 0) {
        await navigator.clipboard.writeText(`[${org}/${repo}](${tab.url})`);
      } else {
        await navigator.clipboard.writeText(`[${tab.title}](${tab.url})`);
      }
    }),
  );
  glide.buf.keymaps.set(
    "normal",
    "yr",
    when_editing(null, async () => {
      assert(org && repo, `Path does not look like github.com/$org/$repo`);
      await navigator.clipboard.writeText(`${org}/${repo}`);
    }),
  );

  function go_to(what: string) {
    return async () => {
      assert(org && repo, `Path does not look like github.com/$org/$repo`);
      await browser.tabs.update({
        url: [url.origin, org, repo, what].filter(Boolean).join("/"),
      });
    };
  }
  glide.buf.keymaps.set("normal", ",,", go_to(""));
  glide.buf.keymaps.set("normal", ",c", go_to("commits"));
  glide.buf.keymaps.set("normal", ",i", go_to("issues"));
  glide.buf.keymaps.set("normal", ",p", go_to("pulls"));
  glide.buf.keymaps.set("normal", ",r", go_to("releases"));
  glide.buf.keymaps.set("normal", ",d", go_to("discussions"));
  glide.buf.keymaps.set("normal", ",w", go_to("wiki"));
});

// glide.autocmds.create(
//   "KeyStateChanged",
//   async ({ mode, sequence, partial }) => {
//     if (
//       mode === "normal" &&
//       sequence.length === 1 &&
//       sequence[0]?.toLowerCase() === "<esc>" &&
//       partial === false
//     ) {
//       await glide.excmds.execute("clear");
//     }
//   },
// );

// Excmds
const open = glide.excmds.create(
  { name: "open", description: "Open URL" },
  opener(),
);
declare global {
  interface ExcmdRegistry {
    open: typeof open;
  }
}
const open_in_new_tab = glide.excmds.create(
  { name: "open_in_new_tab", description: "Open URL in new tab" },
  opener(true),
);
declare global {
  interface ExcmdRegistry {
    open_in_new_tab: typeof open_in_new_tab;
  }
}
glide.keymaps.set(
  "normal",
  "o",
  when_editing("motion o", "commandline_show open "),
);
glide.keymaps.set(
  "normal",
  "O",
  when_editing(null, "commandline_show open_in_new_tab "),
);

// Utils
function when_editing(
  editing_action: glide.ExcmdString | glide.KeymapCallback | null,
  non_editing_action: glide.ExcmdString | glide.KeymapCallback | null,
): glide.KeymapCallback {
  return async (props) => {
    const action = (await glide.ctx.is_editing())
      ? editing_action
      : non_editing_action;

    if (!action) return;

    if (typeof action === "string") {
      await glide.excmds.execute(action);
    } else {
      await action(props);
    }
  };
}

async function focus_page() {
  // HACK: defocus the editable element by focusing the address bar and then refocusing the page
  await glide.keys.send("<F6>", { skip_mappings: true });
  await sleep(100);
  // check insert mode for address bar
  if (glide.ctx.mode === "insert") {
    await glide.keys.send("<F6>", { skip_mappings: true });
  }
}

function go_to_tab(url: string) {
  return async () => {
    const tab = await glide.tabs.get_first({ url });
    if (tab && tab.id) {
      await browser.tabs.update(tab.id, { active: true });
    } else {
      await browser.tabs.create({ url });
    }
  };
}

function text_to_url(text: string): string {
  try {
    new URL(text);
    return text;
  } catch {
    return default_search_engine.replace("{}", encodeURIComponent(text));
  }
}

function opener(
  newtab: boolean = false,
): (props: glide.ExcmdCallbackProps) => void | Promise<void> {
  // ref: https://github.com/glide-browser/glide/discussions/61#discussioncomment-14672404
  function args_to_url(args: string[]): string | undefined {
    if (!args.length) return;

    // A single argument with dots is a host or URL on its own.
    // But take care to complete it with a scheme if it doesn't have one.
    if (args.length == 1 && args[0]!.indexOf(".") >= 0) {
      return /^[a-z]+:/.test(args[0]!) ? args[0]! : "https://" + args[0]!;
    }

    // Otherwise, consider the first argument as a search shorthand.
    for (const [shorthand, url] of Object.entries(search_engines)) {
      if (args[0]! == shorthand) {
        args.shift(); // drop shorthand
        const query = args.map(encodeURIComponent).join("+");
        return url.replace("{}", query);
      }
    }

    // No shorthand match. Feed all args to the default search engine.
    const query = args.map(encodeURIComponent).join("+");
    return default_search_engine.replace("{}", query);
  }

  return (props) => {
    const url = args_to_url(props.args_arr);
    if (url) {
      if (newtab) {
        browser.tabs.create({ url });
      } else {
        browser.tabs.update({ url });
      }
    }
  };
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

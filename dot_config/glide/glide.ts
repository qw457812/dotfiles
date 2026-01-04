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
// https://github.com/y3owk1n/nix-system-config-v2/blob/6d6e20540ae533cea4828abdf655238e8d4f2498/config/glide/glide.ts

// TODO: https://github.com/yuuqilin/FlexFox

// Search engines
// https://github.com/mozilla-firefox/firefox/blob/e2e91539047e030b956e01fd5e8c28c074ae3f88/services/settings/dumps/main/search-config-v2.json
const search_engines = {
  g: "https://www.google.com/search?q={}",
  b: "https://www.bing.com/search?q={}",
  d: "https://duckduckgo.com/?q={}",
  p: "https://www.perplexity.ai/search?q={}",
  bd: "https://www.baidu.com/baidu?wd={}",
  gh: "https://github.com/search?q={}&type=repositories",
  w: "https://en.wikipedia.org/wiki/Special:Search?search={}",
  k: "https://kagi.com/search?q={}",
} as const;
const default_search_engine = search_engines.k;

// Env
if (glide.ctx.os === "macosx") {
  glide.env.set("PATH", `/opt/homebrew/bin:${glide.env.get("PATH")}`);
}

// // Styles
// glide.styles.add(css`
//   #TabsToolbar {
//     visibility: collapse !important;
//   }
// `);

// Preferences
// about:config
// https://support.mozilla.org/en-US/kb/about-config-editor-firefox
// https://kb.mozillazine.org/About:config_entries
// https://searchfox.org/firefox-release/source/browser/app/profile/firefox.js
glide.prefs.set("browser.startup.page", 3); // Open previous windows and tabs
glide.prefs.set("browser.uidensity", 1); // compact mode
// vertical tabs
glide.prefs.set("sidebar.revamp", true);
glide.prefs.set("sidebar.verticalTabs", true);
glide.prefs.set("sidebar.visibility", "expand-on-hover");
glide.prefs.set("sidebar.animation.expand-on-hover.duration-ms", "0");
// make <PageDown>/<PageUp> scroll half page
glide.prefs.set("toolkit.scrollbox.pagescroll.maxOverlapLines", 10000);
glide.prefs.set("toolkit.scrollbox.pagescroll.maxOverlapPercent", 50);
// disable the password manager since I use Bitwarden
glide.prefs.set("signon.rememberSignons", false);
// disable the credit card and address autofill
glide.prefs.set("extensions.formautofill.creditCards.enabled", false);
glide.prefs.set("extensions.formautofill.addresses.enabled", false);

// Options
glide.o.hint_size = "12px";

// Keymaps
glide.keymaps.del("normal", "<leader>f");
glide.keymaps.del("normal", "<leader>d");
glide.keymaps.del("normal", "<leader>r");
glide.keymaps.del("normal", "<leader>R");
glide.keymaps.set("normal", "<Esc>", async (props) => {
  // Test cases:
  // - `<D-f>` -> `<Esc>` (enter normal mode) -> `<Esc>` (close find bar) -> `j` (scroll page down)
  // - On https://github.com/glide-browser/glide/blob/e6a590d53c7d6101792fedfd9894491cda46dbde/src/glide/browser/actors/GlideHandlerChild.sys.mts, `<D-f>` -> `<C-w>` (enter normal mode) -> `<Esc>` (close find bar)
  // - `<D-l>` -> `<Esc>` (enter normal mode) -> `<Esc>` (defocus address bar)
  // - On https://github.com/glide-browser/glide/issues, `f` -> `hq` (type hints of "Newest") -> `<Esc>` (defocus button) -> `j` (scroll page down)
  // - On resource://glide-docs/dynamic/mappings.html, `<Esc>` without the "An error occurred executing () - Error: Missing host permission for the tab `:clear`" error
  const is_editing = await glide.ctx.is_editing();
  await glide.keys.send("<Esc>", { skip_mappings: true });
  await focus_page(props);
  if (!is_editing) {
    await glide.excmds.execute("clear");
    // TODO: close find bar if open
  }
});

// vimium-like keymaps
// https://github.com/glide-browser/glide/blob/107e240a8fd274cafef403d089dc2b646319e8f8/src/glide/browser/base/content/plugins/keymaps.mts
// glide.keymaps.set("normal", "f", () =>
//   glide.hints.show({ include_click_listeners: true }),
// );
// glide.keymaps.set("normal", "F", () =>
//   glide.hints.show({ include_click_listeners: true, action: "newtab-click" }),
// );
glide.keymaps.set("normal", "/", async () => {
  await glide.keys.send(glide.ctx.os === "macosx" ? "<D-f>" : "<C-f>", {
    skip_mappings: true,
  });
});
glide.keymaps.set("normal", "r", when_editing("r", "reload"));
glide.keymaps.set("normal", "R", when_editing(null, "reload_hard"));
glide.keymaps.set("normal", "t", when_editing(null, "tab_new"));
glide.keymaps.set("normal", "T", when_editing(null, "commandline_show tab "));
glide.keymaps.set("normal", "b", when_editing("motion b", bookmark_picker()), {
  description: "Open bookmark",
});
glide.keymaps.set(
  "normal",
  "B",
  when_editing("motion B", bookmark_picker(true)),
  { description: "Open bookmark in a new tab" },
);
glide.keymaps.set("normal", "s", history_picker(), {
  description: "Open history",
});
glide.keymaps.set("normal", "S", history_picker(true), {
  description: "Open history in a new tab",
});
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
    action: async ({ content }) => {
      const href = await content.execute((el) =>
        "href" in el && typeof el.href === "string" ? el.href : null,
      );
      if (href) {
        navigator.clipboard.writeText(href);
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
  when_editing(
    `keys ${glide.ctx.os === "macosx" ? "<D-v>" : "<C-v>"}`,
    async () => {
      const url = text_to_url(await navigator.clipboard.readText());
      await browser.tabs.update({ url });
    },
  ),
);
glide.keymaps.set(
  "normal",
  "P",
  when_editing(
    async () => {
      await glide.keys.send("<Left>", { skip_mappings: true });
      await glide.keys.send(glide.ctx.os === "macosx" ? "<D-v>" : "<C-v>", {
        skip_mappings: true,
      });
      await glide.keys.send("<Right>", { skip_mappings: true });
    },
    async () => {
      const url = text_to_url(await navigator.clipboard.readText());
      await browser.tabs.create({ url });
    },
  ),
);
glide.keymaps.set(
  "normal",
  "e",
  when_editing("motion e", async () => {
    await glide.keys.send(glide.ctx.os === "macosx" ? "<D-l>" : "<C-l>", {
      skip_mappings: true,
    });
    await sleep(50);
    await glide.excmds.execute("mode_change normal");
    await glide.excmds.execute("caret_move right");
  }),
);
glide.keymaps.set("normal", "gi", focusinput);
glide.keymaps.set("normal", "gs", async () => {
  await glide.keys.send(glide.ctx.os === "macosx" ? "<D-u>" : "<C-u>", {
    skip_mappings: true,
  });
});
glide.keymaps.set(
  "normal",
  "d",
  when_editing("mode_change op-pending --operator=d", "scroll_page_down"),
  // { retain_key_display: true }, // no way to display key sequence only for editing
);
glide.keymaps.set("normal", "u", when_editing("undo", "scroll_page_up"));
glide.keymaps.set("normal", "x", when_editing("motion x", "tab_close"));
glide.keymaps.set(
  "normal",
  "X",
  when_editing("motion X", async () => await browser.sessions.restore()),
);
glide.keymaps.set("normal", "h", when_editing("caret_move left", "back"));
glide.keymaps.set("normal", "l", when_editing("caret_move right", "forward"));
glide.keymaps.set("normal", "H", when_editing("motion 0", "caret_move left"));
glide.keymaps.set("normal", "L", when_editing("motion $", "caret_move right"));
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
glide.keymaps.set("normal", "<<", async ({ tab_id }) => {
  const tab = await browser.tabs.get(tab_id);
  if (tab.index > 0) {
    await browser.tabs.move(tab_id, { index: tab.index - 1 });
  }
});
glide.keymaps.set("normal", ">>", async ({ tab_id }) => {
  const tab = await browser.tabs.get(tab_id);
  await browser.tabs.move(tab_id, { index: tab.index + 1 });
});
glide.keymaps.set("normal", "q", "keys <<");
glide.keymaps.set("normal", "w", when_editing("motion w", "keys >>"));
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
glide.keymaps.set("normal", "<leader>bd", "tab_close");
glide.keymaps.set("normal", "<leader>bb", "keys `");
glide.keymaps.set("normal", "<leader>bp", "keys <C-p>");
glide.keymaps.set("normal", "<leader>fc", async () => {
  const config = `${glide.path.home_dir}/.config/glide/glide.ts`;
  await open_in_editor(config);
});
glide.keymaps.set(
  "normal",
  "<C-w>v",
  async ({ tab_id }) => {
    const alt_tab = previousTabId
      ? await browser.tabs.get(previousTabId)
      : await browser.tabs.duplicate(tab_id);
    glide.unstable.split_views.create([tab_id, alt_tab.id!]);
  },
  {
    description: "Create split view with previous tab",
  },
);
glide.keymaps.set(
  "normal",
  "<C-w>d",
  async ({ tab_id }) => glide.unstable.split_views.separate(tab_id),
  { description: "Close split view" },
);
glide.keymaps.set(
  "normal",
  "<C-w>f",
  async ({ tab_id }) => {
    glide.hints.show({
      action: async ({ content }) => {
        const href = await content.execute((el) =>
          "href" in el && typeof el.href === "string" ? el.href : null,
        );
        if (href) {
          const new_tab = await browser.tabs.create({ url: href });
          if (new_tab.id) {
            glide.unstable.split_views.create([tab_id, new_tab.id]);
          }
        }
      },
    });
  },
  { description: "Open link in split view" },
);
glide.keymaps.set("normal", "<leader>wv", "keys <C-w>v");
glide.keymaps.set("normal", "<leader>wd", "keys <C-w>d");
glide.keymaps.set("normal", "<leader>wf", "keys <C-w>f");
glide.keymaps.set("normal", "<leader>sk", "map");
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
glide.keymaps.set(
  "normal",
  "<leader>gP",
  go_to_tab(
    "https://searchfox.org/firefox-release/source/browser/app/profile/firefox.js",
  ),
);
glide.keymaps.set(
  "normal",
  "<leader>gi",
  go_to_tab_by_hostname("ossinsight.io", "https://ossinsight.io/"),
);
glide.keymaps.set(
  "normal",
  "<leader>gr",
  go_to_tab_by_hostname("openrouter.ai", "https://openrouter.ai/settings/keys"),
);

glide.keymaps.set(["normal", "insert"], "<C-j>", "keys <Down>");
glide.keymaps.set(["normal", "insert"], "<C-k>", "keys <Up>");
// glide.keymaps.set(["normal", "insert"], "<C-n>", "keys <Down>");
// glide.keymaps.set(["normal", "insert"], "<C-p>", "keys <Up>");
glide.keymaps.set(["normal", "insert"], "<C-q>", focus_page);

// glide.keymaps.set("insert", "jj", "mode_change normal");
// glide.keymaps.set("insert", "kk", "mode_change normal");

glide.keymaps.set("command", "<c-j>", "commandline_focus_next");
glide.keymaps.set("command", "<c-k>", "commandline_focus_back");
glide.keymaps.set("command", "<c-w>", "keys <A-BS>");
glide.keymaps.set("command", "<c-u>", "keys <D-BS>");
glide.keymaps.set("command", "<c-d>", "keys <Del>");

// Autocmds
// glide.autocmds.create("ModeChanged", "*", ({ new_mode }) => {
//   let color = null;
//   switch (new_mode) {
//     case "normal":
//       color = "#000000";
//       break;
//     case "insert":
//       color = "#C3E88D";
//       break;
//     case "visual":
//       color = "#C099FF";
//       break;
//     case "ignore":
//       color = "#FF757F";
//       break;
//     case "command":
//       // color = "#FFC777";
//       color = "#000000";
//       break;
//     case "op-pending":
//       color = "#82AAFF";
//       break;
//     case "hint":
//       color = "#000000";
//       break;
//   }
//   if (color) {
//     browser.theme.update({ colors: { frame: color } });
//   }
// });

function on_tab_enter(
  pattern: glide.AutocmdPatterns["UrlEnter"],
  callback: (args: glide.AutocmdArgs["UrlEnter"]) => void | Promise<void>,
): void {
  let last_tab_id: number | undefined;
  glide.autocmds.create("UrlEnter", pattern, async (props) => {
    const is_tab_enter = last_tab_id !== props.tab_id;
    last_tab_id = props.tab_id;
    // only trigger on tab enter, not URL change within same tab
    if (is_tab_enter) {
      await callback(props);
    }
  });
}

// It's annoying to be in insert mode when switching tabs.
//
// Use `on_tab_enter` instead of UrlEnter to prevent changing to normal mode when editing search box on the following pages:
// - https://openrouter.ai/models?q=gemini
// - https://grafana.com/grafana/dashboards/?search=node
on_tab_enter({}, async ({ url }) => {
  if (url !== "about:newtab") {
    // HACK: sleep is needed when switching tabs quickly, otherwise `mode_change normal` may not take effect
    // e.g. editing search box on https://openrouter.ai/models?q=gemini (insert mode) -> `<esc>` -> `J` -> `K`, without sleep, ends up in insert mode
    await sleep(50);
    await glide.excmds.execute("mode_change normal");
  }
});

glide.autocmds.create("UrlEnter", { hostname: "github.com" }, async () => {
  const url = new URL(glide.ctx.url);
  const path_segments = url.pathname.split("/").filter(Boolean);
  const is_searching =
    path_segments.length === 1 &&
    path_segments[0] === "search" &&
    url.searchParams.has("q");

  let org: string | undefined;
  let repo: string | undefined;
  if (is_searching) {
    const query = url.searchParams.get("q")!;
    const repo_match = query.match(/repo:(?<org>[^/\s]+)\/(?<repo>[^\s]+)/);
    if (repo_match?.groups) {
      ({ org, repo } = repo_match.groups);
    }
  } else if (path_segments.length >= 2) {
    [org, repo] = path_segments;
  }

  glide.buf.keymaps.set("normal", "gi", async () => {
    await focusinput();
    await sleep(50);
    if (!(await glide.ctx.is_editing())) {
      await glide.excmds.execute("clear"); // clear "No hints found"
      await glide.keys.send("/", { skip_mappings: true }); // GitHub keyboard shortcut: Open search bar
    }
  });

  glide.buf.keymaps.set(
    "normal",
    "ym",
    when_editing(null, async ({ tab_id }) => {
      const tab = await browser.tabs.get(tab_id);
      let md_link: string;
      if (org && repo && (path_segments.length === 2 || is_searching)) {
        md_link = is_searching
          ? `[${tab.title} - ${org}/${repo}](${tab.url})`
          : `[${org}/${repo}](${tab.url})`;
      } else {
        md_link = `[${tab.title}](${tab.url})`;
      }
      await navigator.clipboard.writeText(md_link);
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
  // ref: https://github.com/refined-github/refined-github/pull/8430
  glide.buf.keymaps.set(
    "normal",
    ",b",
    go_to(
      `issues?q=${encodeURIComponent("sort:updated-desc is:issue is:open (label:bug OR type:Bug)")}`,
    ),
  );
});

glide.autocmds.create("UrlEnter", { hostname: "openrouter.ai" }, async () => {
  function go_to(url: string) {
    return async () => {
      await browser.tabs.update({ url });
    };
  }
  glide.buf.keymaps.set(
    "normal",
    ",,",
    go_to("https://openrouter.ai/settings/keys"),
  );
  glide.buf.keymaps.set(
    "normal",
    ",c",
    go_to("https://openrouter.ai/settings/credits"),
  );
  glide.buf.keymaps.set(
    "normal",
    ",a",
    go_to("https://openrouter.ai/activity"),
  );
  glide.buf.keymaps.set("normal", ",m", go_to("https://openrouter.ai/models"));
  glide.buf.keymaps.set(
    "normal",
    ",r",
    go_to("https://openrouter.ai/rankings"),
  );
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

// ref: https://github.com/seruman/rc.d/blob/2b56450a8316680dfcecbdae0729f592e7ac42f4/private_dot_config/glide/glide.ts#L394-L458
const bulk_tab_close = glide.excmds.create(
  { name: "bulk_tab_close", description: "Close tabs with editor" },
  async () => {
    const tabs = await browser.tabs.query({});
    const lines = tabs.map(
      (t) =>
        `${t.id}${t.pinned ? "  " : ""} [${t.title?.replace(/\n/g, " ") || "No Title"}](${t.url || "about:blank"})`,
    );

    const mktemp = await glide.process.execute("mktemp", [
      "-t",
      "glide-editor-tabs.XXXXXX",
    ]);
    let tmp = "";
    for await (const chunk of mktemp.stdout) tmp += chunk;
    tmp = tmp.trim();
    await glide.fs.write(tmp, lines.join("\n"));

    try {
      const { exit_code } = await (
        await glide.process.execute("open", [
          "-W",
          "-n",
          "-b",
          "com.mitchellh.ghostty",
          "--args",
          `--command=${glide.env.get("SHELL")!} -c 'nvim --cmd "lua vim.g.shell_command_editor = true" -c "setl ft=markdown" -c "setl cole=0" -c "lua vim.diagnostic.enable(false, { bufnr = 0 })" "${tmp}"'`,
          "--quit-after-last-window-closed=true",
        ])
      ).wait();
      if (exit_code !== 0)
        throw new Error(`Editor failed with exit code ${exit_code}`);

      const edited = await glide.fs.read(tmp, "utf8");
      const keep = new Set(
        edited
          .split("\n")
          .filter(Boolean)
          .map((l) => Number(l.split(" ")[0])),
      );
      const to_close = tabs
        .map((t) => t.id)
        .filter((id): id is number => id !== undefined && !keep.has(id));
      await browser.tabs.remove(to_close);
    } finally {
      glide.process.spawn("rm", [tmp]);
    }
  },
);
declare global {
  interface ExcmdRegistry {
    bulk_tab_close: typeof bulk_tab_close;
  }
}
glide.keymaps.set("normal", "<leader>bD", "bulk_tab_close");

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

/**
 * defocus the editable element
 */
async function focus_page(props: glide.KeymapCallbackProps) {
  try {
    // ref: https://github.com/glide-browser/glide/discussions/93#discussioncomment-14805495
    await glide.content.execute(
      async () => {
        if (document.activeElement instanceof HTMLElement) {
          document.activeElement.blur();
        }
      },
      { tab_id: props.tab_id },
    );
  } catch {
    // fall back to blur excmd if content.execute fails (e.g., missing host permissions on resource://glide-docs/dynamic/mappings.html)
    await glide.excmds.execute("blur");
  }

  // HACK: fall back to focus the address bar and then refocusing the page
  if (await glide.ctx.is_editing()) {
    await glide.keys.send("<F6>", { skip_mappings: true });
    await sleep(100);
    // check insert mode for address bar
    if (glide.ctx.mode === "insert") {
      await glide.keys.send("<F6>", { skip_mappings: true });
    }
  }
}

async function focusinput() {
  await glide.excmds.execute("focusinput last");
  if (!(await glide.ctx.is_editing())) {
    await glide.keys.send("gI");
  }
}

async function open_in_editor(file: string) {
  // await glide.process.spawn("kitty", ["-e", "nvim", file]);
  if (glide.ctx.os === "macosx") {
    await glide.process.spawn("open", ["-b", "com.neovide.neovide", file]); // single neovide instance
  } else {
    await glide.process.spawn("neovide", [file]);
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

function go_to_tab_by_hostname(hostname: string, default_url: string) {
  return async () => {
    const tabs = await browser.tabs.query({});
    const matching_tab = tabs.find(
      (tab) =>
        tab.url &&
        URL.canParse(tab.url) &&
        new URL(tab.url).hostname === hostname,
    );
    if (matching_tab && matching_tab.id) {
      await browser.tabs.update(matching_tab.id, { active: true });
    } else {
      await browser.tabs.create({ url: default_url });
    }
  };
}

function text_to_url(text: string): string {
  return URL.canParse(text)
    ? text
    : default_search_engine.replace("{}", encodeURIComponent(text));
}

const bookmark_cache = {
  data: null as Awaited<ReturnType<typeof browser.bookmarks.getRecent>> | null,
  timestamp: 0,
  ttl: 60_000, // 1 minute cache
};

async function cached_bookmarks() {
  const now = Date.now();
  if (
    bookmark_cache.data &&
    now - bookmark_cache.timestamp < bookmark_cache.ttl
  ) {
    return bookmark_cache.data;
  }
  bookmark_cache.data = await browser.bookmarks.getRecent(10000);
  bookmark_cache.timestamp = now;
  return bookmark_cache.data;
}

function bookmark_picker(newtab: boolean = false) {
  return async () => {
    const bookmarks = await cached_bookmarks();

    glide.commandline.show({
      title: `Bookmarks (${bookmarks.length})`,
      options: bookmarks.map((bookmark): glide.CommandLineCustomOption => {
        const url = bookmark.url ?? "";
        let display_url = url;
        try {
          const u = new URL(url);
          display_url = u.hostname + decodeURIComponent(u.pathname);
        } catch {}

        return {
          label: bookmark.title,
          // description: bookmark.url,
          render() {
            return DOM.create_element("div", {
              style: {
                display: "flex",
                alignItems: "center",
                gap: "8px",
                padding: "4px 12px",
                borderBottom: "1px solid #2a2a2a",
              },
              children: [
                DOM.create_element("div", [" "], {
                  style: {
                    fontSize: "1.2em",
                    opacity: "0.6",
                    flexShrink: "0",
                    marginRight: "8px",
                  },
                }),
                DOM.create_element("div", {
                  style: {
                    display: "flex",
                    flexDirection: "column",
                    gap: "2px",
                    overflow: "hidden",
                    flex: "1",
                  },
                  children: [
                    DOM.create_element("div", [bookmark.title], {
                      style: {
                        fontWeight: "500",
                        overflow: "hidden",
                        textOverflow: "ellipsis",
                        whiteSpace: "nowrap",
                      },
                    }),
                    DOM.create_element("div", [display_url], {
                      style: {
                        color: "#888888",
                        fontSize: "0.8em",
                        overflow: "hidden",
                        textOverflow: "ellipsis",
                        whiteSpace: "nowrap",
                      },
                    }),
                  ],
                }),
              ],
            });
          },
          async execute() {
            const tab = await glide.tabs.get_first({ url: bookmark.url });
            if (tab) {
              await browser.tabs.update(tab.id, { active: true });
            } else if (newtab) {
              await browser.tabs.create({ url: bookmark.url });
            } else {
              await browser.tabs.update({ url: bookmark.url });
            }
          },
        };
      }),
    });
  };
}

// ref: https://github.com/glide-browser/glide/discussions/147#discussioncomment-15270940
function history_picker(newtab: boolean = false) {
  return async () => {
    const all_history = await browser.history.search({
      text: "",
      startTime: 0,
      maxResults: 1000,
    });

    const seen = new Set<string>();
    const unique_history = all_history.filter(
      (item) => item.url && !seen.has(item.url) && seen.add(item.url),
    );

    glide.commandline.show({
      title: "history",
      options: unique_history.map((item) => ({
        label: item.title || item.url!,
        render() {
          const url = item.url ?? "";
          let display_url = url;
          try {
            const u = new URL(url);
            display_url = u.hostname + decodeURIComponent(u.pathname);
          } catch {}

          return DOM.create_element("div", {
            style: {
              display: "flex",
              alignItems: "center",
              gap: "8px",
              marginLeft: "1em",
            },
            children: [
              DOM.create_element("img", {
                src: `page-icon:${item.url}`,
                style: { width: "16px", height: "16px" },
              }),
              DOM.create_element("div", {
                children: [
                  ...(item.title
                    ? [DOM.create_element("div", { children: item.title })]
                    : []),
                  DOM.create_element("div", { children: display_url }),
                ],
              }),
            ],
          });
        },
        async execute() {
          const tab = await glide.tabs.get_first({ url: item.url });
          if (tab) {
            await browser.tabs.update(tab.id, { active: true });
          } else if (newtab) {
            await browser.tabs.create({ active: true, url: item.url });
          } else {
            await browser.tabs.update({ url: item.url });
          }
        },
      })),
    });
  };
}

function opener(
  newtab: boolean = false,
): (props: glide.ExcmdCallbackProps) => void | Promise<void> {
  // ref: https://github.com/glide-browser/glide/discussions/61#discussioncomment-14672404
  function args_to_url(args: string[]): string | undefined {
    if (!args.length) return;

    // A single argument with dots is a host or URL on its own.
    // But take care to complete it with a scheme if it doesn't have one.
    if (args.length === 1 && args[0]!.indexOf(".") >= 0) {
      return /^[a-z]+:/.test(args[0]!) ? args[0]! : "https://" + args[0]!;
    }

    // Otherwise, consider the first argument as a search shorthand.
    for (const [shorthand, url] of Object.entries(search_engines)) {
      if (args[0]! === shorthand) {
        args.shift(); // drop shorthand
        const query = args.map(encodeURIComponent).join("+");
        return url.replace("{}", query);
      }
    }

    // No shorthand match. Feed all args to the default search engine.
    const query = args.map(encodeURIComponent).join("+");
    return default_search_engine.replace("{}", query);
  }

  return async (props) => {
    const url = args_to_url(props.args_arr);
    if (url) {
      if (newtab) {
        await browser.tabs.create({ url });
      } else {
        await browser.tabs.update({ url });
      }
    }
  };
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

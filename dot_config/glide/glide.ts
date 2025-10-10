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

// https://github.com/RobertCraigie/dotfiles/blob/ecfd6f66e8a775c80849f7889f297ef99cea7997/glide/glide.ts

if (glide.ctx.os === "macosx") {
  glide.env.set("PATH", `/opt/homebrew/bin:${glide.env.get("PATH")}`);
}

// Options
glide.o.hint_size = "12px";

// Keymaps
glide.keymaps.del("normal", "<leader>f");
glide.keymaps.del("normal", "<leader>d");
// vimium-like keymaps
// https://github.com/glide-browser/glide/blob/107e240a8fd274cafef403d089dc2b646319e8f8/src/glide/browser/base/content/plugins/keymaps.mts
// TODO: o b
glide.keymaps.set("normal", "/", "keys <D-f>");
glide.keymaps.set("normal", "r", async () => {
  if (await glide.ctx.is_editing()) {
    await glide.excmds.execute("r");
  } else {
    await glide.excmds.execute("reload");
  }
});
glide.keymaps.set("normal", "t", async () => {
  if (!(await glide.ctx.is_editing())) {
    await glide.excmds.execute("tab_new");
  }
});
glide.keymaps.set("normal", "T", async () => {
  if (!(await glide.ctx.is_editing())) {
    await glide.excmds.execute("commandline_show tab ");
  }
});
glide.keymaps.set("normal", "yt", async ({ tab_id }) => {
  if (!(await glide.ctx.is_editing())) {
    await browser.tabs.duplicate(tab_id);
  }
});
glide.keymaps.set("normal", "p", async ({ tab_id }) => {
  if (!(await glide.ctx.is_editing())) {
    const url = await navigator.clipboard.readText();
    await browser.tabs.update(tab_id, { url });
  }
});
glide.keymaps.set("normal", "P", async () => {
  if (!(await glide.ctx.is_editing())) {
    const url = await navigator.clipboard.readText();
    await browser.tabs.create({ url });
  }
});
glide.keymaps.set("normal", "e", async () => {
  if (await glide.ctx.is_editing()) {
    await glide.excmds.execute("motion e");
  } else {
    await glide.keys.send("<D-l>");
  }
});
glide.keymaps.set(
  "normal",
  "d",
  async () => {
    if (await glide.ctx.is_editing()) {
      await glide.excmds.execute("mode_change op-pending --operator=d");
    } else {
      await glide.excmds.execute("scroll_page_down");
    }
  },
  {
    retain_key_display: true,
  },
);
glide.keymaps.set("normal", "u", async () => {
  if (await glide.ctx.is_editing()) {
    await glide.excmds.execute("undo");
  } else {
    await glide.excmds.execute("scroll_page_up");
  }
});
glide.keymaps.set("normal", "x", async () => {
  if (await glide.ctx.is_editing()) {
    await glide.excmds.execute("motion x");
  } else {
    await glide.excmds.execute("tab_close");
  }
});
glide.keymaps.set("normal", "X", async () => {
  if (await glide.ctx.is_editing()) {
    await glide.excmds.execute("motion X");
  } else {
    await browser.sessions.restore();
  }
});
glide.keymaps.set("normal", "h", async () => {
  if (await glide.ctx.is_editing()) {
    await glide.excmds.execute("caret_move left");
  } else {
    await glide.excmds.execute("back");
  }
});
glide.keymaps.set("normal", "l", async () => {
  if (await glide.ctx.is_editing()) {
    await glide.excmds.execute("caret_move right");
  } else {
    await glide.excmds.execute("forward");
  }
});
glide.keymaps.set("normal", "H", async () => {
  if (await glide.ctx.is_editing()) {
    await glide.excmds.execute("motion 0");
  } else {
    await glide.excmds.execute("caret_move left"); // scroll left?
  }
});
glide.keymaps.set("normal", "L", async () => {
  if (await glide.ctx.is_editing()) {
    await glide.excmds.execute("motion $");
  } else {
    await glide.excmds.execute("caret_move right"); // scroll right?
  }
});
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
glide.keymaps.set("normal", "U", "redo");
glide.keymaps.set("normal", "<BS>", "tab_close");
glide.keymaps.set("normal", "<S-BS>", async () => {
  await browser.sessions.restore();
});
glide.keymaps.set("normal", "<C-r>", "config_reload");
glide.keymaps.set("normal", "<C-f>", "hint --location=browser-ui");
glide.keymaps.set("normal", "<C-p>", async ({ tab_id }) => {
  const tab = await browser.tabs.get(tab_id);
  await browser.tabs.update(tab_id, { pinned: !tab.pinned });
});
glide.keymaps.set("normal", "<leader><BS>", "quit");
glide.keymaps.set("normal", "<leader>fc", async () => {
  const config = `${glide.path.home_dir}/.config/glide/glide.ts`;
  if (glide.ctx.os === "macosx") {
    await glide.process.spawn("open", ["-b", "com.neovide.neovide", config]);
  } else {
    await glide.process.spawn("neovide", [config]);
  }
});
glide.keymaps.set("normal", "<leader>fk", "map");
glide.keymaps.set("normal", "<leader>un", "clear");
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
glide.keymaps.set("normal", "<leader>gg", go_to_tab("https://github.com/"));
glide.keymaps.set(
  "normal",
  "<leader>gs",
  go_to_tab("https://github.com/search"),
);
glide.keymaps.set(
  "normal",
  "<leader>gc",
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
  "<leader>g`",
  go_to_tab("https://github.com/qw457812/dotfiles"),
);

glide.keymaps.set("insert", "jj", "mode_change normal");
glide.keymaps.set("insert", "kk", "mode_change normal");

glide.keymaps.set("command", "<c-j>", "commandline_focus_next");
glide.keymaps.set("command", "<c-k>", "commandline_focus_back");

// Autocmds
glide.autocmds.create("UrlEnter", { hostname: "github.com" }, async () => {
  await glide.excmds.execute("mode_change normal");

  function go_to(page: string) {
    return async () => {
      const url = new URL(glide.ctx.url);
      const [org, repo] = url.pathname.split("/").filter(Boolean);
      assert(org && repo, `Path does not look like github.com/$org/$repo`);
      await browser.tabs.update({
        url: [url.origin, org, repo, page].filter(Boolean).join("/"),
      });
    };
  }
  glide.buf.keymaps.set("normal", ",<space>", go_to(""));
  glide.buf.keymaps.set("normal", ",c", go_to("commits"));
  glide.buf.keymaps.set("normal", ",i", go_to("issues"));
  glide.buf.keymaps.set("normal", ",p", go_to("pulls"));
  glide.buf.keymaps.set("normal", ",r", go_to("releases"));
  glide.buf.keymaps.set("normal", ",d", go_to("discussions"));
  glide.buf.keymaps.set("normal", ",w", go_to("wiki"));
});

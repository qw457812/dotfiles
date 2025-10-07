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
glide.keymaps.set("normal", "J", "tab_next");
glide.keymaps.set("normal", "K", "tab_prev");
glide.keymaps.set("normal", "H", "back");
glide.keymaps.set("normal", "L", "forward");
glide.keymaps.set("normal", "U", "redo");
glide.keymaps.set("normal", "<BS>", "tab_close");
glide.keymaps.set("normal", "<S-BS>", async () => {
  await browser.sessions.restore();
});
glide.keymaps.set("normal", "<C-r>", "reload");
glide.keymaps.set("normal", "<C-f>", "hint --location=browser-ui");
glide.keymaps.set("normal", "<leader><BS>", "quit");
glide.keymaps.set("normal", "<leader>r", "config_reload");
glide.keymaps.set("normal", "<leader>fc", async () => {
  await glide.process.spawn("neovide", [
    `${glide.path.home_dir}/.config/glide/glide.ts`,
  ]);
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
  function go_to(page: string) {
    return async () => {
      const url = new URL(glide.ctx.url);
      const parts = url.pathname.split("/").filter(Boolean);
      assert(
        parts.length >= 2,
        `Path does not look like github.com/$org/$repo`,
      );
      url.pathname = "/" + [parts[0], parts[1], page].filter(Boolean).join("/");
      await browser.tabs.update({ url: url.toString() });
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

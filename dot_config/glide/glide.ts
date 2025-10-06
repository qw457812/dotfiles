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

// Options
glide.o.hint_size = "12px";

// Keymaps
glide.keymaps.set("normal", "J", "tab_next");
glide.keymaps.set("normal", "K", "tab_prev");
glide.keymaps.set("normal", "H", "back");
glide.keymaps.set("normal", "L", "forward");
glide.keymaps.set("normal", "<BS>", "tab_close");
glide.keymaps.set("normal", "<leader><BS>", "quit");
glide.keymaps.set("normal", "<C-r>", "reload");
glide.keymaps.set("normal", "<D-r>", "config_reload");
glide.keymaps.set("normal", "<C-f>", "hint --location=browser-ui");
glide.keymaps.set("normal", "<leader>fc", "config_edit");
glide.keymaps.set("normal", "<leader>fk", "map");
glide.keymaps.set("normal", "<leader>un", "clear");

glide.keymaps.set("command", "<c-j>", "commandline_focus_next");
glide.keymaps.set("command", "<c-k>", "commandline_focus_back");

// Autocmds
async function github_go_to_issues() {
  const url = new URL(glide.ctx.url);

  const parts = url.pathname.split("/").filter(Boolean);
  assert(parts.length > 2, `Path does not look like github.com/$org/$repo`);

  url.pathname = `/${parts[0]}/${parts[1]}/issues`;
  await browser.tabs.update({ url: url.toString() });
}

glide.autocmds.create("UrlEnter", { hostname: "github.com" }, async () =>
  glide.buf.keymaps.set("normal", "<leader>gi", github_go_to_issues),
);

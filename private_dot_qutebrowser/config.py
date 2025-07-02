import catppuccin

c = c  # noqa: F821
config = config  # noqa: F821

config.load_autoconfig(False)

# https://github.com/catppuccin/qutebrowser#manual-config
catppuccin.setup(c, "frappe")  # mocha, macchiato, frappe

# https://github.com/qutebrowser/qutebrowser/blob/main/doc/help/settings.asciidoc
c.fonts.default_family = "Maple Mono NF CN"
c.fonts.default_size = "12pt"

c.tabs.show = "multiple"
c.tabs.title.format = "{audio}{current_title}"
c.tabs.position = "left"
c.tabs.width = 200
c.tabs.padding = {"bottom": 7, "left": 5, "right": 0, "top": 7}
c.tabs.indicator.width = 0
c.tabs.last_close = "close"

c.downloads.position = "bottom"
c.downloads.location.directory = "~/Downloads"
c.downloads.location.prompt = False

c.window.hide_decoration = True
c.colors.webpage.darkmode.enabled = True

c.auto_save.session = True
c.keyhint.delay = 300  # which key
# c.scrolling.smooth = True
c.url.searchengines = {"DEFAULT": "https://google.com/search?q={}"}
c.editor.command = [
    "/opt/homebrew/bin/kitty",
    "-e",
    "nvim",
    "-f",
    "{file}",
    "-c",
    "normal {line}G{column0}l",
    "--cmd",
    "lua vim.g.shell_command_editor = true",
]

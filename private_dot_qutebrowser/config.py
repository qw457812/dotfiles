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

c.content.javascript.clipboard = "access"
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

config.bind("d", "scroll-page 0 0.5")
config.bind("u", "scroll-page 0 -0.5")
config.bind("x", "tab-close")
config.bind("X", "undo")
config.bind("h", "back")
config.bind("l", "forward")
config.bind("H", "cmd-run-with-count 2 scroll left")
config.bind("L", "cmd-run-with-count 2 scroll right")
config.bind("j", "cmd-run-with-count 2 scroll down")
config.bind("k", "cmd-run-with-count 2 scroll up")
config.bind("gn", "navigate next")
config.bind("gp", "navigate prev")

config.bind("gt", "tab-focus")
config.bind("gT", "tab-prev")

config.bind("<Backspace>", "tab-close")
config.bind("<Space><Backspace>", "quit")

config.bind("<Space>,", "set-cmd-text -s :tab-select")
config.bind("<Space>`", "tab-focus last")
config.bind("<Space>bb", "tab-focus last")
config.bind("<Space>bd", "tab-close")
config.bind("<Space>bp", "tab-pin")
config.bind("<Space>bo", "tab-only")
config.bind("<Space>bH", "tab-focus 1")
config.bind("<Space>bL", "tab-focus -1")

config.bind("<Space>qq", "quit")
config.bind("<Space>qr", "restart")

config.bind("<Space>1", "tab-focus 1")
config.bind("<Space>2", "tab-focus 2")
config.bind("<Space>3", "tab-focus 3")
config.bind("<Space>4", "tab-focus 4")
config.bind("<Space>5", "tab-focus 5")
config.bind("<Space>6", "tab-focus 6")
config.bind("<Space>7", "tab-focus 7")
config.bind("<Space>8", "tab-focus 8")
config.bind("<Space>9", "tab-focus 9")

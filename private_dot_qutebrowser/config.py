c = c  # noqa: F821
config = config  # noqa: F821

config.load_autoconfig(False)

# https://github.com/qutebrowser/qutebrowser/blob/main/doc/help/settings.asciidoc
c.fonts.default_family = "Maple Mono NF CN"
c.fonts.default_size = "12pt"

c.tabs.position = "left"
c.tabs.show = "multiple"
c.tabs.width = "10%"

c.auto_save.session = True
c.colors.webpage.darkmode.enabled = True
c.window.hide_decoration = True
c.downloads.position = "bottom"
# c.scrolling.smooth = True

c.editor.command = [
    "/opt/homebrew/bin/kitty",
    "-e",
    "nvim",
    "-f",
    "{file}",
    "-c",
    "normal {line}G{column0}l",
]

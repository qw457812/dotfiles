rex.bind("ctrl+b>ctrl+b", "pane.send_key", { key = "ctrl+b" }) -- prefix passthrough
rex.bind("ctrl+b>s", "session.switch") -- session picker
rex.bind("ctrl+b>shift+0", "session.next")
rex.bind("ctrl+b>shift+9", "session.previous")
rex.bind("ctrl+b>ctrl+c", "session.new")
rex.bind("ctrl+b>r", "client.config.reload")
rex.bind("ctrl+b>c", "client.tab.new")
rex.bind("ctrl+b>n", "client.tab.next")
rex.bind("ctrl+b>p", "client.tab.previous")
rex.bind("ctrl+b>,", "client.tab.rename")
rex.bind("ctrl+b>-", "pane.split", { direction = "down" })
rex.bind("ctrl+b>shift+-", "pane.split", { direction = "right" })
rex.bind("ctrl+b>h", "pane.focus", { direction = "left" })
rex.bind("ctrl+b>j", "pane.focus", { direction = "down" })
rex.bind("ctrl+b>k", "pane.focus", { direction = "up" })
rex.bind("ctrl+b>l", "pane.focus", { direction = "right" })
rex.bind("ctrl+b>shift+h", "pane.resize", { amount = 2, direction = "left" })
rex.bind("ctrl+b>shift+j", "pane.resize", { amount = 2, direction = "down" })
rex.bind("ctrl+b>shift+k", "pane.resize", { amount = 2, direction = "up" })
rex.bind("ctrl+b>shift+l", "pane.resize", { amount = 2, direction = "right" })

rex.bind("cmd+m", "pane.zoom")
rex.bind("cmd+j", "client.tab.next")
rex.bind("cmd+k", "client.tab.previous")
rex.bind("cmd+,", "client.tab.move", { direction = "backward" })
rex.bind("cmd+.", "client.tab.move", { direction = "forward" })

rex.bind("shift+cmd+;", "client.palette.toggle")

-- Work around intermittent Ctrl-Q input with Squirrel on macOS.
-- Related IME issue: https://discord.com/channels/1546797889009881158/1565307429262991440
rex.bind("ctrl+[KeyQ]", "pane.send_key", { key = "ctrl+q" })

-- https://www.hammerspoon.org/go/
-- Adds a pathwatcher to automatically reload hammerspoon configuration on changes | http://www.hammerspoon.org/Spoons/ReloadConfiguration.html
hs.loadSpoon("ReloadConfiguration")
spoon.ReloadConfiguration:start()
hs.alert.show("Hammerspoon Config loaded")

-- Just another clock, floating above all | https://www.hammerspoon.org/Spoons/AClock.html
hs.loadSpoon("AClock")
spoon.AClock:init()
hs.urlevent.bind("toggleAClock", function(eventName, params)
    spoon.AClock:toggleShow()
end)

-- Move Mouse to center and click | https://gist.github.com/imjma/51710df48cf6110e758f
function mouseCenterClick()
    local screen = hs.mouse.getCurrentScreen()
    local rect = screen:fullFrame()
    local center = hs.geometry.rectMidPoint(rect)
    -- https://www.hammerspoon.org/docs/hs.mouse.html#absolutePosition
    -- hs.mouse.absolutePosition(center)
    -- https://www.hammerspoon.org/docs/hs.eventtap.html#leftClick
    hs.eventtap.leftClick(center)
end
hs.urlevent.bind("mouseCenterClick", function(eventName, params)
    mouseCenterClick()
end)

function maximizeWindow()
    -- local win = hs.window.focusedWindow()
    -- local f = win:frame()
    -- local screen = win:screen()
    -- local max = screen:frame()
    -- f.x = max.x
    -- f.y = max.y
    -- f.w = max.w
    -- f.h = max.h
    -- win:setFrame(f, 0)

    -- Maximize Window use Rectangle.app, note that not work with yabai
    -- https://www.hammerspoon.org/docs/hs.eventtap.html#keyStroke
    -- https://www.hammerspoon.org/docs/hs.keycodes.html#map
    hs.eventtap.keyStroke({"ctrl", "alt", "shift"}, "space")
end
hs.urlevent.bind("mouseCenterClickThenMaximizeWindow", function(eventName, params)
    mouseCenterClick()
    maximizeWindow()
end)

function cmdTab(repeatTimes)
    -- problem: act like cmd+tab, but not release cmd
    -- hs.eventtap.keyStroke({"cmd"}, "tab")

    -- problem: wired behavior with delay
    -- https://www.hammerspoon.org/docs/hs.window.switcher.html
    -- hs.window.switcher.nextWindow()
    -- hs.window.switcher.new():next()

    -- https://www.hammerspoon.org/docs/hs.eventtap.event.html#newKeyEvent
    hs.eventtap.event.newKeyEvent(hs.keycodes.map.cmd, true):post()

    for _ = 1, repeatTimes do
        hs.eventtap.event.newKeyEvent(hs.keycodes.map.tab, true):post()
        hs.eventtap.event.newKeyEvent(hs.keycodes.map.tab, false):post()
    end

    hs.eventtap.event.newKeyEvent(hs.keycodes.map.cmd, false):post()
end
hs.urlevent.bind("cmdTab", function(eventName, params)
    cmdTab(1)
end)

function prevApp()
    cmdTab(1)

    -- Note:
    -- After `defaults write com.apple.finder QuitMenuItem -bool true`, Finder can be quit by cmd+q.
    -- As long as Finder stays quit, the following code won't be needed that much.

    -- Wait for the cmd+tab event to complete, maybe including the animation when
    -- switching between a full-screen app and a non-full-screen app.
    -- Ensure the `app` below is obtained after the cmd+tab event.
    -- https://www.hammerspoon.org/docs/hs.timer.html#doAfter
    hs.timer.doAfter(0.3, function()
        -- alternative: hs.window.focusedWindow():application()
        local app = hs.application.frontmostApplication()

        -- Do not focus Finder when no open window on cmd+tab
        if (app:name() == "Finder") then
            -- https://www.hammerspoon.org/docs/hs.application.html#allWindows
            local windows = app:allWindows()
            -- For Finder, when no open window, both allWindows and visibleWindows are 1
            if #windows == 1 then
                -- Use another cmd+tab+tab to skip Finder
                cmdTab(2)
            end
        end
    end)
end


hs.urlevent.bind("prevApp", function(eventName, params)
    local _, status = hs.execute("/opt/homebrew/bin/yabai -m window --focus recent")

    -- fallback to cmd+tab on yabai failed
    if not status then
        prevApp()
    end
end)

-- function applicationWatcher(appName, eventType, appObject)
--     if (eventType == hs.application.watcher.activated) then
--         if (appName == "Finder") then
--             -- Bring all Finder windows forward when one gets activated
--             -- appObject:selectMenuItem({"Window", "Bring All to Front"})
--
--             -- Do not focus Finder when no open window on cmd+tab
--             local windows = appObject:allWindows()
--             -- For Finder, when no open window, both allWindows and visibleWindows are 1
--             if #windows == 1 then
--                 -- Wait for cmd+tab which cause the activated event to finished,
--                 -- make sure `cmdTab(2)` below is separate from the current event.
--                 hs.timer.doAfter(0.25, function()
--                     -- Use another cmd+tab+tab to skip Finder
--                     cmdTab(2)
--                 end)
--             end
--         end
--     end
-- end
-- -- https://www.hammerspoon.org/docs/hs.application.watcher.html#new
-- appWatcher = hs.application.watcher.new(applicationWatcher)
-- appWatcher:start()

-- Sometimes you just cannot find your mouse pointer
mouseCircle = nil
mouseCircleTimer = nil
function mouseHighlight()
    -- Delete an existing highlight if it exists
    if mouseCircle then
        mouseCircle:delete()
        if mouseCircleTimer then
            mouseCircleTimer:stop()
        end
    end
    -- Get the current co-ordinates of the mouse pointer
    mousepoint = hs.mouse.absolutePosition()
    -- Prepare a big red circle around the mouse pointer
    mouseCircle = hs.drawing.circle(hs.geometry.rect(mousepoint.x-40, mousepoint.y-40, 80, 80))
    mouseCircle:setStrokeColor({["red"]=1,["blue"]=0,["green"]=0,["alpha"]=1})
    mouseCircle:setFill(false)
    mouseCircle:setStrokeWidth(5)
    mouseCircle:show()

    -- Set a timer to delete the circle after 3 seconds
    mouseCircleTimer = hs.timer.doAfter(3, function()
      mouseCircle:delete()
      mouseCircle = nil
    end)
end
-- hs.hotkey.bind({"cmd", "alt", "ctrl", "shift"}, "D", mouseHighlight)
hs.urlevent.bind("mouseHighlight", function(eventName, params)
    mouseHighlight()
end)

--[[
-- https://github.com/dbalatero/VimMode.spoon
--------------------------------
-- START VIM CONFIG
--------------------------------
local VimMode = hs.loadSpoon("VimMode")
local vim = VimMode:new()

-- Configure apps you do *not* want Vim mode enabled in
-- For example, you don't want this plugin overriding your control of Terminal
-- vim
-- [:j :i] :!!f18 | ~/.config/karabiner.edn
vim
  :disableForApp('Code')
  :disableForApp('zoom.us')
  :disableForApp('iTerm')
  :disableForApp('iTerm2')
  :disableForApp('Terminal')

-- If you want the screen to dim (a la Flux) when you enter normal mode
-- flip this to true.
vim:shouldDimScreenInNormalMode(false)

-- If you want to show an on-screen alert when you enter normal mode, set
-- this to true
vim:shouldShowAlertInNormalMode(true)

-- You can configure your on-screen alert font
vim:setAlertFont("Courier New")

-- Enter normal mode by typing a key sequence
-- vim:enterWithSequence('jk')

-- if you want to bind a single key to entering vim, remove the
-- :enterWithSequence('jk') line above and uncomment the bindHotKeys line
-- below:
--
-- To customize the hot key you want, see the mods and key parameters at:
--   https://www.hammerspoon.org/docs/hs.hotkey.html#bind
--
-- vim:bindHotKeys({ enter = { {'ctrl'}, ';' } })
vim:bindHotKeys({ enter = { {"ctrl", "alt", "cmd", "shift"}, 'f19' } })

-- https://github.com/dbalatero/VimMode.spoon#block-cursor-mode
-- vim:enableBetaFeature('block_cursor_overlay')

--------------------------------
-- END VIM CONFIG
--------------------------------
--]]

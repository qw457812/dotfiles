-- https://www.hammerspoon.org/go/
-- Adds a pathwatcher to automatically reload hammerspoon configuration on changes | http://www.hammerspoon.org/Spoons/ReloadConfiguration.html
hs.loadSpoon("ReloadConfiguration")
spoon.ReloadConfiguration:start()

-- Just another clock, floating above all | https://www.hammerspoon.org/Spoons/AClock.html
hs.loadSpoon("AClock")
spoon.AClock:init()
-- https://github.com/akermen/.hammerspoon/blob/f333eec7b0b71d3d35389112a09ee25d2d72aecc/init.lua#L387
spoon.AClock.format = "%H:%M:%S"
spoon.AClock.width = 512
spoon.AClock.showDuration = 1
hs.urlevent.bind("toggle_aclock", function(eventName, params)
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
hs.urlevent.bind("mouse_center_click", function(eventName, params)
  mouseCenterClick()
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
hs.urlevent.bind("cmd_tab", function(eventName, params)
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
    if app:name() == "Finder" then
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

hs.urlevent.bind("prev_app", function(eventName, params)
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
  mouseCircle = hs.drawing.circle(hs.geometry.rect(mousepoint.x - 40, mousepoint.y - 40, 80, 80))
  mouseCircle:setStrokeColor({ ["red"] = 1, ["blue"] = 0, ["green"] = 0, ["alpha"] = 1 })
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
hs.urlevent.bind("mouse_highlight", function(eventName, params)
  mouseHighlight()
end)

hs.alert.show("Hammerspoon Config loaded")

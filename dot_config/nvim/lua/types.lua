---@meta

-- Explicit global aliases for EmmyLua when using lazydev.
-- lazydev loads the plugin sources, but EmmyLua does not resolve these globals automatically.
-- Not needed with lua_ls + lazydev.
_G.Layers = require("layers")
_G.MiniFiles = require("mini.files")
_G.MiniPairs = require("mini.pairs")
_G.MiniSnippets = require("mini.snippets")
_G.MiniSurround = require("mini.surround")
_G.MiniTest = require("mini.test")
_G.MiniTrailspace = require("mini.trailspace")

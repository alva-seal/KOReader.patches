--[[
KOReader user patch: dark-magenta text and monochrome icons in KOReader menus.

Place this file in koreader/patches/ and restart KOReader.
On color screens, menu text and eligible monochrome icons are tinted RGB (112, 0, 70).
On grayscale screens, menu text uses dark gray and icons remain unchanged.
Remove this file to undo the patch.
]]

local BlitBuffer = require("ffi/blitbuffer")
local Screen = require("device").screen
local Menu = require("ui/widget/menu")
local TouchMenu = require("ui/widget/touchmenu")
local TextWidget = require("ui/widget/textwidget")
local IconWidget = require("ui/widget/iconwidget")
local RenderText = is_color and require("ui/rendertext") or nil

local is_color = Screen:isColorScreen()

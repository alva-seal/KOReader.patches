--[[
KOReader user patch: dark-magenta menu text, icons, and rules.

Place this file in koreader/patches/ and restart KOReader.
On color displays, the tint is RGB (112, 0, 70). On monochrome e-ink,
magenta cannot be displayed, so menu marks use dark gray instead.
Remove the file to undo the patch.
]]

local BlitBuffer = require("ffi/blitbuffer")
local Screen = require("device").screen
local Menu = require("ui/widget/menu")
local TextWidget = require("ui/widget/textwidget")
local IconWidget = require("ui/widget/iconwidget")
local LineWidget = require("ui/widget/linewidget")
local UnderlineContainer = require("ui/widget/container/underlinecontainer")

local is_color = Screen:isColorScreen()
local magenta = is_color and BlitBuffer.ColorRGB32(112, 0, 70, 0xFF) or BlitBuffer.COLOR_DARK_GRAY
local original_text_paint = TextWidget.paintTo
local original_icon_paint = IconWidget.paintTo

-- TextWidget's normal painter uses a grayscale mask. On color screens, render
-- shaped glyph masks through RGB32 so the magenta tint is preserved.
if is_color then
    local RenderText = require("ui/rendertext")
    TextWidget.paintTo = function(self, bb, x, y)
        if not self._menu_dark_magenta or not self.fgcolor
            or BlitBuffer.isColor8(self.fgcolor) or not Screen:isColorScreen()
            or not self.use_xtext then
            return original_text_paint(self, bb, x, y)
        end
        self:updateSize()
        if self._is_empty then return end
        if not self._xshaping then
            self._xshaping = self._xtext:shapeLine(self._shape_start, self._shape_end,
                self._shape_idx_to_substitute_with_ellipsis)
        end
        local text_width = math.min(bb:getWidth() - x, self.max_width or (bb:getWidth() - x))
        local pen_x = 0
        local baseline = self.forced_baseline or self._baseline_h
        for _, xglyph in ipairs(self._xshaping) do
            if pen_x >= text_width then break end
            local face = self.face.getFallbackFont(xglyph.font_num)
            local glyph = RenderText:getGlyphByIndex(face, xglyph.glyph, self.bold)
            bb:colorblitFromRGB32(glyph.bb,
                x + pen_x + glyph.l + xglyph.x_offset,
                y + baseline - glyph.t - xglyph.y_offset,
                0, 0, glyph.bb:getWidth(), glyph.bb:getHeight(), magenta)
            pen_x = pen_x + xglyph.x_advance
        end
    end
end

-- Tint only icon widgets discovered inside a menu. Other KOReader icons are untouched.
IconWidget.paintTo = function(self, bb, x, y)
    if not self._menu_dark_magenta or not is_color or self.hide then
        return original_icon_paint(self, bb, x, y)
    end
    local size = self:getSize()
    local Geom = require("ui/geometry")
    self.dimen = self.dimen or Geom:new{ x = x, y = y, w = size.w, h = size.h }
    self.dimen.x, self.dimen.y = x, y
    self._bb:invert()
    bb:colorblitFromRGB32(self._bb, x, y, self._offset_x, self._offset_y,
        size.w, size.h, magenta)
    self._bb:invert()
end

local function tint_menu_tree(root)
    local visited = {}
    local function walk(widget)
        if type(widget) ~= "table" or visited[widget] then return end
        visited[widget] = true
        local mt = getmetatable(widget)
        if mt == TextWidget then
            widget._menu_dark_magenta = true
            widget.fgcolor = magenta
        elseif mt == IconWidget then
            widget._menu_dark_magenta = true
        elseif mt == LineWidget then
            widget.background = magenta
        elseif mt == UnderlineContainer then
            widget.color = magenta
        end

        -- Keep focus underlines magenta; stock focus handlers reset them to black.
        if widget._underline_container and not widget._menu_magenta_focus_patched then
            widget._menu_magenta_focus_patched = true
            local old_focus = widget.onFocus
            local old_unfocus = widget.onUnfocus
            if old_focus then
                widget.onFocus = function(self, ...)
                    local result = old_focus(self, ...)
                    if self._underline_container then self._underline_container.color = magenta end
                    return result
                end
            end
            if old_unfocus then
                widget.onUnfocus = function(self, ...)
                    local result = old_unfocus(self, ...)
                    if self._underline_container then self._underline_container.color = magenta end
                    return result
                end
            end
        end

        if widget.line_color ~= nil then widget.line_color = magenta end
        if widget.bottom_line_color ~= nil then widget.bottom_line_color = magenta end
        for i = 1, #widget do walk(widget[i]) end
    end
    walk(root)
end

-- Menu:updateItems rebuilds its rows; tint after each rebuild and initialisation.
local original_update_items = Menu.updateItems
if original_update_items then
    Menu.updateItems = function(self, ...)
        local result = original_update_items(self, ...)
        tint_menu_tree(self)
        return result
    end
end
local original_init = Menu.init
if original_init then
    Menu.init = function(self, ...)
        local result = original_init(self, ...)
        tint_menu_tree(self)
        return result
    end
end

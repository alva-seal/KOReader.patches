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
local is_color = Screen:isColorScreen()
local magenta = is_color and BlitBuffer.ColorRGB32(112, 0, 70, 0xFF) or nil
local gray_text = BlitBuffer.COLOR_DARK_GRAY
local original_text_paint = TextWidget.paintTo
local original_icon_paint = IconWidget.paintTo

-- Stock TextWidget passes its fgcolor through grayscale-oriented rendering
-- paths. On color screens, use RGB32 only for explicitly marked XText glyphs.
-- Unmarked text and grayscale displays retain KOReader's original painter.
if is_color then
    local RenderText = require("ui/rendertext")
    TextWidget.paintTo = function(self, bb, x, y)
        if not self._dark_magenta_menu or not self.use_xtext or not magenta
            or not self.fgcolor or BlitBuffer.isColor8(self.fgcolor)
            or not Screen:isColorScreen() then
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

-- Tint only flagged, flattened 8-bit monochrome menu icons on color screens.
-- Never mutate an IconWidget's cached _bb (SimpleUI and other plugins may share it).
IconWidget.paintTo = function(self, bb, x, y)
    if not self._dark_magenta_menu or not is_color or not magenta or self.hide then
        return original_icon_paint(self, bb, x, y)
    end
    local size = self:getSize()
    if not self._bb or self._bb:getType() ~= BlitBuffer.TYPE_BB8 then
        return original_icon_paint(self, bb, x, y)
    end
    local Geom = require("ui/geometry")
    self.dimen = self.dimen or Geom:new{ x = x, y = y, w = size.w, h = size.h }
    self.dimen.x, self.dimen.y = x, y
    local mask = BlitBuffer.new(size.w, size.h, BlitBuffer.TYPE_BB8)
    mask:blitFrom(self._bb, 0, 0, self._offset_x, self._offset_y, size.w, size.h)
    -- KOReader's flattened monochrome icons are black artwork on white.
    -- Invert a temporary copy so artwork becomes the color-blit coverage mask.
    mask:invert()
    bb:colorblitFromRGB32(mask, x, y, 0, 0, size.w, size.h, magenta)
    mask:free()
    if self.invert then bb:invertRect(x, y, size.w, size.h) end
end

local function markMenuTree(root)
    local visited = {}
    local function walk(widget)
        if type(widget) ~= "table" or visited[widget] then return end
        visited[widget] = true
        local mt = getmetatable(widget)
        if mt == TextWidget then
            widget._dark_magenta_menu = true
            -- The RGB painter handles XText; all other painters, including
            -- grayscale mode and non-XText, get a grayscale-safe fallback.
            widget.fgcolor = (is_color and widget.use_xtext and magenta) or gray_text
        elseif mt == IconWidget then
            widget._dark_magenta_menu = true
        end
        for i = 1, #widget do walk(widget[i]) end
    end
    walk(root)
end

local function wrapMenuClass(class)
    local original_update = class.updateItems
    if original_update and not class._dark_magenta_update_wrapped then
        class._dark_magenta_update_wrapped = true
        class.updateItems = function(self, ...)
            local result = original_update(self, ...)
            markMenuTree(self)
            return result
        end
    end
    local original_init = class.init
    if original_init and not class._dark_magenta_init_wrapped then
        class._dark_magenta_init_wrapped = true
        class.init = function(self, ...)
            local result = original_init(self, ...)
            markMenuTree(self)
            return result
        end
    end
end

-- Traditional menus plus the hierarchical top TouchMenu (a different class).
wrapMenuClass(Menu)
wrapMenuClass(TouchMenu)

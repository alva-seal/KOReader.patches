-- 2-simpleui-tweaks.lua
-- KOReader user patch for the Simple UI plugin (simpleui.koplugin)
--
-- Reproduces the changes from https://github.com/alva-seal/simpleui.koplugin :
--   * Pages badge shows only the number, no " p." suffix
--     (home-screen book grid + library folder covers)
--   * Pages badge on folder covers is shifted by (-6, +12) px (scaled)
--   * Simple UI no longer auto-disables "Reader Menu Redesign"
--
-- Works by rewriting a few lines of the plugin's source when its modules are
-- loaded, so the stock plugin stays untouched.

local logger = require("logger")

-- Extra shift of the pages badge on folder covers: positive = right / down.
local PAGES_SHIFT_X = -6
local PAGES_SHIFT_Y = 12

-- Source rewrites, keyed by module file basename (without .lua).
-- Each returns (new_source, number_of_substitutions).
local rewrites = {
    sui_book_grid = function(src)
        return src:gsub('bd%.pages %.%. _%(" p%."%)', 'tostring(bd.pages)')
    end,

    sui_foldercovers = function(src)
        local total, n = 0, 0
        src, n = src:gsub('self%._fc_pages %.%. _%(" p%."%)', 'tostring(self._fc_pages)')
        total = total + n
        src, n = src:gsub(
            '(badge_y = fy %+ fh %- wg%.dimen%.h %- _native_bar_left_margin%s+end%s+)wg:paintTo%(bb, badge_x, badge_y%)',
            '%1wg:paintTo(bb, badge_x + Screen:scaleBySize(' .. PAGES_SHIFT_X ..
            '), badge_y + Screen:scaleBySize(' .. PAGES_SHIFT_Y .. '))')
        total = total + n
        return src, total
    end,

    sui_compat_check = function(src)
        return src:gsub('%s*{%s*sentinel = "readermenuredesign_installer",.-},', '')
    end,
}

-- ---------------------------------------------------------------------------

local function key(s)
    s = s:gsub("%.lua$", "")
    return s:match("([^/%.]+)$")
end

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

local function findModuleFile(modname)
    local fname = modname:gsub("%.", "/")
    for template in package.path:gmatch("[^;]+") do
        local path = template:gsub("%?", (fname:gsub("%%", "%%%%")))
        local f = io.open(path, "r")
        if f then
            f:close()
            return path
        end
    end
end

local function compilePatched(k, path)
    local src = readFile(path)
    if not src then return nil end
    local new_src, n = rewrites[k](src)
    if n == 0 then
        logger.warn("simpleui-tweaks: no matching lines found in", path, "- plugin source may have changed")
        return nil
    end
    logger.info("simpleui-tweaks: patched", path, "(" .. n .. " substitutions)")
    return (loadstring or load)(new_src, "@" .. path)
end

-- 1) Hook require(): insert a searcher ahead of the normal Lua file searcher.
local loaders = package.loaders or package.searchers
table.insert(loaders, 2, function(modname)
    local k = key(modname)
    if not rewrites[k] then return nil end
    local path = findModuleFile(modname)
    if not path then return nil end
    local chunk, err = compilePatched(k, path)
    if chunk then return chunk end
    if err then return "\n\tsimpleui-tweaks: " .. tostring(err) end
    return nil
end)

-- 2) Hook loadfile()/dofile() in case the plugin loads its modules by path.
local orig_loadfile, orig_dofile = loadfile, dofile

loadfile = function(path, ...)
    if type(path) == "string" and rewrites[key(path)] then
        local chunk = compilePatched(key(path), path)
        if chunk then return chunk end
    end
    return orig_loadfile(path, ...)
end

dofile = function(path)
    if type(path) == "string" and rewrites[key(path)] then
        local chunk = compilePatched(key(path), path)
        if chunk then return chunk() end
    end
    return orig_dofile(path)
end

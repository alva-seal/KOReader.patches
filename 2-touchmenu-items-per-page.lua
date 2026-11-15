-- 2-touchmenu-items-per-page.lua
-- Make both the maximum number of entries per page and the row height
-- in KOReader's top touch menu configurable in the Settings tab.

local TouchMenu   = require("ui/widget/touchmenu")
local MenuSorter  = require("ui/menusorter")
local UIManager   = require("ui/uimanager")
local Size        = require("ui/size")
local _           = require("gettext")
local T           = require("ffi/util").template

local SETTING_KEY_MAX    = "touch_menu_max_per_page"
local SETTING_KEY_HEIGHT = "touch_menu_item_height_pct"
local STOCK_MAX          = 10   -- KOReader's default ceiling
local STOCK_HEIGHT_PCT   = 100  -- 100% of TouchMenu's true stock height (height_big)
local BASE_ITEM_HEIGHT   = Size.item.height_big

local function getMax()
    return G_reader_settings:readSetting(SETTING_KEY_MAX) or STOCK_MAX
end

local function getHeightPct()
    return G_reader_settings:readSetting(SETTING_KEY_HEIGHT) or STOCK_HEIGHT_PCT
end

local function applyMenuDimensions(menu)
    menu.max_per_page_default = getMax()
    menu.max_per_page = getMax()
    menu.item_height = math.floor(BASE_ITEM_HEIGHT * (getHeightPct() / 100))
end

-- 1) Apply defaults at class level and refresh dynamically whenever a tab builds
applyMenuDimensions(TouchMenu)

local orig_switchMenuTab = TouchMenu.switchMenuTab
function TouchMenu:switchMenuTab(tab_num)
    applyMenuDimensions(self)
    return orig_switchMenuTab(self, tab_num)
end

-- 2) Add menu entries to change both values live
local function buildMaxItemsEntry()
    return {
        text_func = function()
            return T(_("Top menu items per page: %1"), getMax())
        end,
        keep_menu_open = true,
        callback = function(touchmenu_instance)
            local SpinWidget = require("ui/widget/spinwidget")
            UIManager:show(SpinWidget:new{
                title_text      = _("Top menu items per page"),
                info_text       = _("Upper limit only: the actual number is still bounded by row height and screen size."),
                value           = getMax(),
                value_min       = 4,
                value_max       = 40,
                value_step      = 1,
                value_hold_step = 5,
                default_value   = STOCK_MAX,
                callback = function(spin)
                    G_reader_settings:saveSetting(SETTING_KEY_MAX, spin.value)
                    applyMenuDimensions(TouchMenu)
                    if touchmenu_instance then
                        touchmenu_instance:switchMenuTab(touchmenu_instance.cur_tab)
                    end
                end,
            })
        end,
    }
end

local function buildRowHeightEntry()
    return {
        text_func = function()
            return T(_("Top menu row height: %1%"), getHeightPct())
        end,
        keep_menu_open = true,
        callback = function(touchmenu_instance)
            local SpinWidget = require("ui/widget/spinwidget")
            UIManager:show(SpinWidget:new{
                title_text      = _("Top menu row height (%)"),
                info_text       = _("Adjusts vertical spacing between menu entries (100% = stock height)."),
                value           = getHeightPct(),
                value_min       = 40,
                value_max       = 150,
                value_step      = 5,
                value_hold_step = 10,
                default_value   = STOCK_HEIGHT_PCT,
                callback = function(spin)
                    G_reader_settings:saveSetting(SETTING_KEY_HEIGHT, spin.value)
                    applyMenuDimensions(TouchMenu)
                    if touchmenu_instance then
                        touchmenu_instance:switchMenuTab(touchmenu_instance.cur_tab)
                    end
                end,
            })
        end,
    }
end

-- Inject both items into the menu table right before it is sorted
local orig_mergeAndSort = MenuSorter.mergeAndSort
function MenuSorter:mergeAndSort(config_prefix, item_table, order)
    if item_table then
        if not item_table[SETTING_KEY_MAX] then
            item_table[SETTING_KEY_MAX] = buildMaxItemsEntry()
        end
        if not item_table[SETTING_KEY_HEIGHT] then
            item_table[SETTING_KEY_HEIGHT] = buildRowHeightEntry()
        end
    end
    return orig_mergeAndSort(self, config_prefix, item_table, order)
end

-- Place both entries in the Settings tab right after "screen"
local function addToOrder(order)
    local tab = order and order.setting
    if not tab then return end

    local keys = { SETTING_KEY_MAX, SETTING_KEY_HEIGHT }
    for _, key in ipairs(keys) do
        for i = #tab, 1, -1 do
            if tab[i] == key then
                table.remove(tab, i)
            end
        end
    end

    for i, v in ipairs(tab) do
        if v == "screen" then
            table.insert(tab, i + 1, SETTING_KEY_MAX)
            table.insert(tab, i + 2, SETTING_KEY_HEIGHT)
            return
        end
    end
    table.insert(tab, SETTING_KEY_MAX)
    table.insert(tab, SETTING_KEY_HEIGHT)
end

addToOrder(require("ui/elements/reader_menu_order"))
addToOrder(require("ui/elements/filemanager_menu_order"))

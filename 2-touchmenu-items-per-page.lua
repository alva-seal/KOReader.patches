-- 2-touchmenu-items-per-page.lua
-- Make the number of entries per page in KOReader's top touch menu
-- configurable. Stock KOReader caps it at 10 regardless of screen size.
--
-- Adds "Top menu items per page" under the Settings tab of the top menu
-- (both in the reader and in the file browser). The value is stored in
-- settings.reader.lua as "touch_menu_max_per_page".

local TouchMenu   = require("ui/widget/touchmenu")
local MenuSorter  = require("ui/menusorter")
local UIManager   = require("ui/uimanager")
local _           = require("gettext")
local T           = require("ffi/util").template

local SETTING_KEY = "touch_menu_max_per_page"
local STOCK_MAX   = 10   -- KOReader's default ceiling

local function getMax()
    return G_reader_settings:readSetting(SETTING_KEY) or STOCK_MAX
end

-- 1) Apply the ceiling. switchMenuTab() reads self.max_per_page_default
--    every time a tab is (re)built, so refreshing it there keeps it live.
TouchMenu.max_per_page_default = getMax()

local orig_switchMenuTab = TouchMenu.switchMenuTab
function TouchMenu:switchMenuTab(tab_num)
    self.max_per_page_default = getMax()
    return orig_switchMenuTab(self, tab_num)
end

-- 2) Add a menu entry to change it.
local function buildMenuItem()
    return {
        text_func = function()
            return T(_("Top menu items per page: %1"), getMax())
        end,
        keep_menu_open = true,
        callback = function(touchmenu_instance)
            local SpinWidget = require("ui/widget/spinwidget")
            UIManager:show(SpinWidget:new{
                title_text    = _("Top menu items per page"),
                info_text     = _("Upper limit only: the actual number is still bounded by what fits on the screen."),
                value         = getMax(),
                value_min     = 4,
                value_max     = 40,
                value_step    = 1,
                value_hold_step = 5,
                default_value = STOCK_MAX,
                callback = function(spin)
                    G_reader_settings:saveSetting(SETTING_KEY, spin.value)
                    TouchMenu.max_per_page_default = spin.value
                    if touchmenu_instance then
                        -- Rebuild the current tab so the new layout shows immediately
                        touchmenu_instance:switchMenuTab(touchmenu_instance.cur_tab)
                    end
                end,
            })
        end,
    }
end

-- Inject the item into the menu table right before it is sorted, for both
-- the reader menu and the file manager menu.
local orig_mergeAndSort = MenuSorter.mergeAndSort
function MenuSorter:mergeAndSort(config_prefix, item_table, order)
    if item_table and not item_table[SETTING_KEY] then
        item_table[SETTING_KEY] = buildMenuItem()
    end
    return orig_mergeAndSort(self, config_prefix, item_table, order)
end

-- Place it in the Settings tab (after "screen", or at the end if not found).
local function addToOrder(order)
    local tab = order and order.setting
    if not tab then return end
    for _, v in ipairs(tab) do
        if v == SETTING_KEY then return end
    end
    for i, v in ipairs(tab) do
        if v == "screen" then
            table.insert(tab, i + 1, SETTING_KEY)
            return
        end
    end
    table.insert(tab, SETTING_KEY)
end

addToOrder(require("ui/elements/reader_menu_order"))
addToOrder(require("ui/elements/filemanager_menu_order"))

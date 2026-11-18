-- Fix the Markdown exporter crash when an annotation has no chapter.
--
-- Install this file in KOReader's patches/ directory and restart KOReader.
-- Missing chapter names are exported under "Unknown Chapter".

local _ = require("gettext")
local md = require("template/md")

local original_prepareBookContent = md.prepareBookContent

md.prepareBookContent = function(book, formatting_options, highlight_formatting, export_backlinks)
    -- Copy the book and its note entries so the patch does not modify the
    -- annotations held by the exporter or the book's metadata.
    local safe_book = {}
    for key, value in pairs(book) do
        safe_book[key] = value
    end

    for index, note in ipairs(book) do
        if note and note[1] then
            local safe_note = {}
            for key, value in pairs(note) do
                safe_note[key] = value
            end

            local safe_entry = {}
            for key, value in pairs(note[1]) do
                safe_entry[key] = value
            end
            if safe_entry.chapter == nil then
                safe_entry.chapter = _("Unknown Chapter")
            end

            safe_note[1] = safe_entry
            safe_book[index] = safe_note
        end
    end

    return original_prepareBookContent(
        safe_book,
        formatting_options,
        highlight_formatting,
        export_backlinks
    )
end

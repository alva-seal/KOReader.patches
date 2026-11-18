-- Fix the Markdown exporter crash when an annotation has no chapter.
--
-- Install this file in KOReader's patches/ directory and restart KOReader.
-- Missing chapter names are exported under "Unknown Chapter".

local _ = require("gettext")
local logger = require("logger")
local userpatch = require("userpatch")

-- The exporter plugin (and its `template/md` dependency) may not be loaded
-- when late user patches run. Register a hook so we patch the actual cached
-- Markdown template module once the exporter plugin has been instantiated.
userpatch.registerPatchPluginFunc("exporter", function(exporter_plugin)
    local targets = userpatch.getUpValue(exporter_plugin.genExportersTable, "targets")
    local markdown_exporter = targets and targets.markdown
    local export_func = markdown_exporter and markdown_exporter.export
    local md = export_func and userpatch.getUpValue(export_func, "md")

    if not md or type(md.prepareBookContent) ~= "function" then
        logger.warn("Markdown missing-chapter patch: couldn't find template module")
        return
    end

    -- Avoid stacking wrappers if the plugin is instantiated again.
    if md._missing_chapter_patch_applied then
        return
    end
    md._missing_chapter_patch_applied = true

    local original_prepareBookContent = md.prepareBookContent
    md.prepareBookContent = function(book, formatting_options, highlight_formatting, export_backlinks)
        -- Copy the book, notes, and entries so the fallback does not mutate
        -- the annotations held by the exporter or the book's metadata.
        local safe_book = {}
        for key, value in pairs(book) do
            safe_book[key] = value
        end

        for index, note in ipairs(book) do
            if type(note) == "table" and type(note[1]) == "table" then
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

    logger.info("Markdown missing-chapter patch applied")
end)

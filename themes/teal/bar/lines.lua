#!/usr/bin/lua5.1

--  https://github.com/brndnmtthws/conky/wiki/Using-Lua-scripts-in-conky:-Drawing-lines

--this is a lua script for use in conky
require 'cairo'

function conky_main()
    if conky_window == nil then
        return
    end
    -- create surface onto which things are drawn
    local cs = cairo_xlib_surface_create(conky_window.display,
                                         conky_window.drawable,
                                         conky_window.visual,
                                         conky_window.width,
                                         conky_window.height)
    cr = cairo_create(cs)
    --cairo_set_line_width (cr,1)
--    cairo_set_source_rgba (cr,.8,.8,.8,1)

--    starty = 35
--    cairo_move_to (cr,254,starty)
--    cairo_rel_line_to (cr,155,0)

    cairo_rectangle (cr, 254,35, 155,2)
    cairo_rectangle (cr, 483,35, 155,2)
    cairo_rectangle (cr, 712,35, 155,2)
    cairo_rectangle (cr, 941,35, 145,2)
    cairo_set_source_rgba (cr,.68,.66,.467,1)

--    cairo_move_to (cr,483,starty)
--    cairo_rel_line_to (cr,155,0)
--    cairo_move_to (cr,712,starty)
--    cairo_rel_line_to (cr,155,0)
--    cairo_move_to (cr,941,starty)
--    cairo_rel_line_to (cr,145,0)

--    cairo_stroke (cr)
    cairo_fill (cr)
    cairo_destroy(cr)
    cairo_surface_destroy(cs)
    cr=nil
end


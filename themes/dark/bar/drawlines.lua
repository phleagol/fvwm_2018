#!/usr/bin/lua5.1

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
    cairo_set_line_width (cr,1)
    cairo_set_source_rgba (cr,.8,.8,.8,1)

    starty = 35
    cairo_move_to (cr,256,starty)
    cairo_rel_line_to (cr,164,0)
    cairo_move_to (cr,484,starty)
    cairo_rel_line_to (cr,164,0)
    cairo_move_to (cr,707,starty)
    cairo_rel_line_to (cr,164,0)
    cairo_move_to (cr,930,starty)
    cairo_rel_line_to (cr,165,0)

    cairo_stroke (cr)
    cairo_destroy(cr)
    cairo_surface_destroy(cs)
    cr=nil
end


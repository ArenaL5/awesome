---------------------------------------------------------------------------
--- Mouse module for awful
--
-- @author Julien Danjou &lt;julien@danjou.info&gt;
-- @copyright 2008 Julien Danjou
-- @release @AWESOME_VERSION@
-- @module mouse
---------------------------------------------------------------------------

-- Grab environment we need
local layout = require("awful.layout")
local aplace = require("awful.placement")
local awibox = require("awful.wibox")
local util = require("awful.util")
local type = type
local ipairs = ipairs
local capi =
{
    root = root,
    mouse = mouse,
    screen = screen,
    client = client,
    mousegrabber = mousegrabber,
}

local mouse = {
    resize = require("awful.mouse.resize"),
    snap   = require("awful.mouse.snap"),
    drag_to_tag = require("awful.mouse.drag_to_tag")
}

mouse.object = {}
mouse.client = {}
mouse.wibox = {}

--- The default snap distance.
-- @tfield integer awful.mouse.snap.default_distance
-- @tparam[opt=8] integer default_distance
-- @see awful.mouse.snap

--- Enable screen edges snapping.
-- @tfield[opt=true] boolean awful.mouse.snap.edge_enabled

--- Enable client to client snapping.
-- @tfield[opt=true] boolean awful.mouse.snap.client_enabled

--- Enable changing tag when a client is dragged to the edge of the screen.
-- @tfield[opt=false] integer awful.mouse.drag_to_tag.enabled

--- The snap outline background color.
-- @beautiful beautiful.snap_bg
-- @tparam color|string|gradient|pattern color

--- The snap outline width.
-- @beautiful beautiful.snap_border_width
-- @param integer

--- The snap outline shape.
-- @beautiful beautiful.snap_shape
-- @tparam function shape A `gears.shape` compatible function

--- Get the client object under the pointer.
-- @deprecated awful.mouse.client_under_pointer
-- @return The client object under the pointer, if one can be found.
-- @see current_client
function mouse.client_under_pointer()
    util.deprecated("Use mouse.current_client instead of awful.mouse.client_under_pointer()")

    return mouse.object.get_current_client()
end

--- Move a client.
-- @function awful.mouse.client.move
-- @param c The client to move, or the focused one if nil.
-- @param snap The pixel to snap clients.
-- @param finished_cb Deprecated, do not use
function mouse.client.move(c, snap, finished_cb) --luacheck: no unused args
    if finished_cb then
        util.deprecated("The mouse.client.move `finished_cb` argument is no longer"..
            " used, please use awful.mouse.resize.add_leave_callback(f, 'mouse.move')")
    end

    c = c or capi.client.focus

    if not c
        or c.fullscreen
        or c.type == "desktop"
        or c.type == "splash"
        or c.type == "dock" then
        return
    end

    -- Compute the offset
    local coords = capi.mouse.coords()
    local geo    = aplace.centered(capi.mouse,{parent=c, pretend=true})

    local offset = {
        x = geo.x - coords.x,
        y = geo.y - coords.y,
    }

    mouse.resize(c, "mouse.move", {
        placement = aplace.under_mouse,
        offset    = offset,
        snap      = snap
    })
end

mouse.client.dragtotag = { }

--- Move a client to a tag by dragging it onto the left / right side of the screen.
-- @deprecated awful.mouse.client.dragtotag.border
-- @param c The client to move
function mouse.client.dragtotag.border(c)
    util.deprecated("Use awful.mouse.snap.drag_to_tag_enabled = true instead "..
        "of awful.mouse.client.dragtotag.border(c). It will now be enabled.")

    -- Enable drag to border
    mouse.snap.drag_to_tag_enabled = true

    return mouse.client.move(c)
end

--- Move the wibox under the cursor.
-- @function awful.mouse.wibox.move
--@param w The wibox to move, or none to use that under the pointer
function mouse.wibox.move(w)
    w = w or mouse.wibox_under_pointer()
    if not w then return end

    local offset = {
        x = w.x - capi.mouse.coords().x,
        y = w.y - capi.mouse.coords().y
    }

    capi.mousegrabber.run(function (_mouse)
        local button_down = false
        if awibox.get_position(w) == "floating" then
            w.x = capi.mouse.coords().x + offset.x
            w.y = capi.mouse.coords().y + offset.y
        else
            local wa = capi.screen[capi.mouse.screen].workarea

            if capi.mouse.coords()["y"] > wa.y + wa.height - 10 then
                awibox.set_position(w, "bottom", w.screen)
            elseif capi.mouse.coords()["y"] < wa.y + 10 then
                awibox.set_position(w, "top", w.screen)
            elseif capi.mouse.coords()["x"] > wa.x + wa.width - 10 then
                awibox.set_position(w, "right", w.screen)
            elseif capi.mouse.coords()["x"] < wa.x + 10 then
                awibox.set_position(w, "left", w.screen)
            end
            w.screen = capi.mouse.screen
        end
        for _, v in ipairs(_mouse.buttons) do
            if v then button_down = true end
        end
        if not button_down then
            return false
        end
        return true
    end, "fleur")
end

--- Get a client corner coordinates.
-- @deprecated awful.mouse.client.corner
-- @tparam[opt=client.focus] client c The client to get corner from, focused one by default.
-- @tparam string corner The corner to use: auto, top_left, top_right, bottom_left,
-- bottom_right, left, right, top bottom. Default is auto, and auto find the
-- nearest corner.
-- @treturn string The corner name
-- @treturn number x The horizontal position
-- @treturn number y The vertical position
function mouse.client.corner(c, corner)
    util.deprecated(
        "Use awful.placement.closest_corner(mouse) or awful.placement[corner](mouse)"..
        " instead of awful.mouse.client.corner"
    )

    c = c or capi.client.focus
    if not c then return end

    local ngeo = nil

    if (not corner) or corner == "auto" then
        ngeo, corner = aplace.closest_corner(mouse, {parent = c})
    elseif corner and aplace[corner] then
        ngeo = aplace[corner](mouse, {parent = c})
    end

    return corner, ngeo and ngeo.x or nil, ngeo and ngeo.y or nil
end

--- Resize a client.
-- @function awful.mouse.client.resize
-- @param c The client to resize, or the focused one by default.
-- @tparam string corner The corner to grab on resize. Auto detected by default.
-- @tparam[opt={}] table args A set of `awful.placement` arguments
-- @treturn string The corner (or side) name
function mouse.client.resize(c, corner, args)
    c = c or capi.client.focus

    if not c then return end

    if c.fullscreen
        or c.type == "desktop"
        or c.type == "splash"
        or c.type == "dock" then
        return
    end

    -- Move the mouse to the corner
    if corner and aplace[corner] then
        aplace[corner](capi.mouse, {parent=c})
    else
        local _
        _, corner = aplace.closest_corner(capi.mouse, {parent=c})
    end

    mouse.resize(c, "mouse.resize", args or {include_sides=true})

    return corner
end

--- Default handler for `request::geometry` signals with "mouse.resize" context.
-- @signalhandler awful.mouse.resize_handler
-- @tparam client c The client
-- @tparam string context The context
-- @tparam[opt={}] table hints The hints to pass to the handler
function mouse.resize_handler(c, context, hints)
    if hints and context and context:find("mouse.*") then
        -- This handler only handle the floating clients. If the client is tiled,
        -- then it let the layouts handle it.
        local lay = c.screen.selected_tag.layout

        if lay == layout.suit.floating or c.floating then
            local offset = hints and hints.offset or {}

            if type(offset) == "number" then
                offset = {
                    x      = offset,
                    y      = offset,
                    width  = offset,
                    height = offset,
                }
            end

            c:geometry {
                x      = hints.x      + (offset.x      or 0 ),
                y      = hints.y      + (offset.y      or 0 ),
                width  = hints.width  + (offset.width  or 0 ),
                height = hints.height + (offset.height or 0 ),
            }
        elseif lay.resize_handler then
            lay.resize_handler(c, context, hints)
        end
    end
end

-- Older layouts implement their own mousegrabber.
-- @tparam client c The client
-- @tparam table args Additional arguments
-- @treturn boolean This return false when the resize need to be aborted
mouse.resize.add_enter_callback(function(c, args) --luacheck: no unused args
    if c.floating then return end

    local l = c.screen.selected_tag and c.screen.selected_tag.layout or nil
    if l == layout.suit.floating then return end

    if l ~= layout.suit.floating and l.mouse_resize_handler then
        capi.mousegrabber.stop()

        local geo, corner = aplace.closest_corner(capi.mouse, {parent=c})

        l.mouse_resize_handler(c, corner, geo.x, geo.y)

        return false
    end
end, "mouse.resize")

--- Get the client currently under the mouse cursor.
-- @property current_client
-- @tparam client|nil The client

function mouse.object.get_current_client()
    local obj = capi.mouse.object_under_pointer()
    if type(obj) == "client" then
        return obj
    end
end

function mouse.object.set_current_client() end

--- Get the wibox currently under the mouse cursor.
-- @property current_wibox
-- @tparam wibox|nil The wibox

function mouse.object.get_current_wibox()
    local obj = capi.mouse.object_under_pointer()
    if type(obj) == "drawin" and obj.get_wibox then
        return obj:get_wibox()
    end
end

function mouse.object.set_current_wibox() end

--- Get the widgets currently under the mouse cursor.
--
-- @property current_widgets
-- @tparam nil|table list The widget list
-- @treturn table The list of widgets.The first element is the biggest
-- container while the last is the topmost widget. The table contains *x*, *y*,
-- *width*, *height* and *widget*.
-- @treturn table The list of geometries.
-- @see wibox.find_widgets

function mouse.object.get_current_widgets()
    local w = mouse.object.get_current_wibox()
    if w then
        local geo, coords = w:geometry(), capi.mouse:coords()

        local list = w:find_widgets(coords.x - geo.x, coords.y - geo.y)

        local ret = {}

        for k, v in ipairs(list) do
            ret[k] = v.widget
        end

        return ret, list
    end
end

function mouse.object.set_current_widgets() end

--- Get the topmost widget currently under the mouse cursor.
-- @property current_widget
-- @tparam widget|nil widget The widget
-- @treturn ?widget The widget
-- @treturn ?table The geometry.
-- @see wibox.find_widgets

function mouse.object.get_current_widget()
    local wdgs, geos = mouse.object.get_current_widgets()

    if wdgs then
        return wdgs[#wdgs], geos[#geos]
    end
end

function mouse.object.set_current_widget() end

--- True if the left mouse button is pressed.
-- @property is_left_mouse_button_pressed
-- @param boolean

--- True if the right mouse button is pressed.
-- @property is_right_mouse_button_pressed
-- @param boolean

--- True if the middle mouse button is pressed.
-- @property is_middle_mouse_button_pressed
-- @param boolean

for _, b in ipairs {"left", "right", "middle"} do
    mouse.object["is_".. b .."_mouse_button_pressed"] = function()
        return capi.mouse.coords().buttons[1]
    end

    mouse.object["set_is_".. b .."_mouse_button_pressed"] = function() end
end

capi.client.connect_signal("request::geometry", mouse.resize_handler)

-- Set the cursor at startup
capi.root.cursor("left_ptr")

-- Implement the custom property handler
local props = {}

capi.mouse.set_newindex_miss_handler(function(_,key,value)
    if mouse.object["set_"..key] then
        mouse.object["set_"..key](value)
    else
        props[key] = value
    end
end)

capi.mouse.set_index_miss_handler(function(_,key)
    if mouse.object["get_"..key] then
        return mouse.object["get_"..key]()
    else
        return props[key]
    end
end)

--- Get or set the mouse coords.
--
--@DOC_awful_mouse_coords_EXAMPLE@
--
-- @tparam[opt=nil] table coords_table None or a table with x and y keys as mouse
--  coordinates.
-- @tparam[opt=nil] integer coords_table.x The mouse horizontal position
-- @tparam[opt=nil] integer coords_table.y The mouse vertical position
-- @tparam[opt=false] boolean silent Disable mouse::enter or mouse::leave events that
--  could be triggered by the pointer when moving.
-- @treturn integer table.x The horizontal position
-- @treturn integer table.y The vertical position
-- @treturn table table.buttons Table containing the status of buttons, e.g. field [1] is true
--  when button 1 is pressed.
-- @function mouse.coords


return mouse

-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80

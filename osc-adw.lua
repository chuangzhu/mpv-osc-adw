-- GNOME Showtime inspired OSC for mpv
-- Install as ~/.config/mpv/scripts/osc-adw.lua and disable mpv's stock OSC.
local mp = require "mp"
local assdraw = require "mp.assdraw"
local utils = require "mp.utils"

mp.set_property_native("osc", false)

local overlay = mp.create_osd_overlay("ass-events")
local visible, menu, settings, volume_popup = true, false, false, false
local hide_timer, tap_timer, volume_timer
local last_tap = nil
local hitboxes = {}

local C = {
    white = "&HFFFFFF&", panel = "&H303035&", track = "&H99FFFFFF&",
    shadow = "&H000000&", selected = "&H55555C&",
}

-- ASS drawings transcribed from the 16x16 Adwaita symbolic SVG path data.
-- Keeping them in script makes the OSC independent of the installed icon theme.
local icon = {
    play = "m 2 3 b 2 1 3 1 4 2 l 14 7 b 15 8 15 9 14 9 l 4 15 b 3 15 2 15 2 13",
    pause = "m 3 1 b 2 1 2 2 2 3 l 2 14 b 2 15 3 15 4 15 l 6 15 b 7 15 7 14 7 13 l 7 2 b 7 1 6 1 5 1 m 10 1 b 9 1 9 2 9 3 l 9 14 b 9 15 10 15 11 15 l 13 15 b 14 15 14 14 14 13 l 14 2 b 14 1 13 1 12 1",
    menu = "m 1 2 l 15 2 15 4 1 4 m 1 7 l 15 7 15 9 1 9 m 1 12 l 15 12 15 14 1 14",
    close = "m 4 4 l 5 4 8 7 11 4 12 4 12 5 9 8 12 11 12 12 11 12 8 9 5 12 4 12 4 11 7 8 4 5",
    fullscreen = "m 1 9 b 0.449 9 0 9.449 0 10 l 0 16 6 16 b 6.551 16 7 15.551 7 15 b 7 14.449 6.551 14 6 14 l 3.414 14 6.707 10.707 b 7.098 10.316 7.098 9.684 6.707 9.293 b 6.52 9.105 6.266 9 6 9 b 5.734 9 5.48 9.105 5.293 9.293 l 2 12.586 2 10 b 2 9.449 1.551 9 1 9 m 15 7 b 15.551 7 16 6.551 16 6 l 16 0 10 0 b 9.449 0 9 0.449 9 1 b 9 1.551 9.449 2 10 2 l 12.586 2 9.293 5.293 b 8.902 5.684 8.902 6.316 9.293 6.707 b 9.48 6.895 9.734 7 10 7 b 10.266 7 10.52 6.895 10.707 6.707 l 14 3.414 14 6 b 14 6.551 14.449 7 15 7",
    restore = "m 2 8 b 1.449 8 1 8.449 1 9 b 1 9.551 1.449 10 2 10 l 4.586 10 1.293 13.293 b 0.902 13.684 0.902 14.316 1.293 14.707 b 1.684 15.098 2.316 15.098 2.707 14.707 l 6 11.414 6 14 b 6 14.551 6.449 15 7 15 b 7.551 15 8 14.551 8 14 l 8 8 2 8 m 14 8 b 14.551 8 15 7.551 15 7 b 15 6.449 14.551 6 14 6 l 11.414 6 14.707 2.707 b 15.098 2.316 15.098 1.684 14.707 1.293 b 14.316 0.902 13.684 0.902 13.293 1.293 l 10 4.586 10 2 b 10 1.449 9.551 1 9 1 b 8.449 1 8 1.449 8 2 l 8 8 14 8",
    volume = "m 0 6 b 0 5 1 5 2 5 l 3 5 7 1 7 15 3 11 2 11 b 1 11 0 10 0 9 m 9 5 b 10 4 11 5 12 6 b 13 8 13 10 11 12 l 9 11 b 11 9 11 7 9 5 m 13 2 b 17 5 17 11 13 14 l 12 12 b 15 10 15 6 12 4",
    muted = "m 0 6 b 0 5 1 5 2 5 l 3 5 7 1 7 15 3 11 2 11 b 1 11 0 10 0 9 m 10 5 l 12 7 14 5 15 6 13 8 15 10 14 11 12 9 10 11 9 10 11 8 9 6",
    gear = "m 7.5 1.02 b 6.949 1.02 6.504 1.465 6.504 2.016 l 6.504 2.469 b 6.031 2.598 5.574 2.789 5.148 3.035 l 4.824 2.711 b 4.434 2.32 3.805 2.32 3.414 2.711 l 2.711 3.418 b 2.32 3.809 2.32 4.438 2.711 4.828 l 3.031 5.148 b 2.785 5.574 2.598 6.031 2.469 6.504 l 2.016 6.504 b 1.465 6.504 1.02 6.949 1.02 7.5 l 1.02 8.5 b 1.02 9.051 1.465 9.496 2.016 9.496 l 2.465 9.496 b 2.598 9.969 2.785 10.426 3.031 10.852 l 2.711 11.172 b 2.32 11.563 2.32 12.191 2.711 12.582 l 3.414 13.289 b 3.805 13.68 4.434 13.68 4.824 13.289 l 5.145 12.969 b 5.574 13.211 6.027 13.402 6.504 13.527 l 6.504 13.984 b 6.504 14.535 6.949 14.98 7.5 14.98 l 8.496 14.98 b 9.051 14.98 9.496 14.535 9.496 13.984 l 9.496 13.531 b 9.969 13.402 10.426 13.211 10.852 12.965 l 11.172 13.289 b 11.563 13.68 12.191 13.68 12.582 13.289 l 13.289 12.582 b 13.68 12.191 13.68 11.563 13.289 11.172 l 12.969 10.852 b 13.211 10.426 13.402 9.969 13.527 9.496 l 13.981 9.496 b 14.535 9.496 14.981 9.051 14.981 8.5 l 14.981 7.5 b 14.981 6.949 14.535 6.504 13.981 6.504 l 13.531 6.504 b 13.402 6.031 13.211 5.574 12.965 5.148 l 13.289 4.828 b 13.68 4.438 13.68 3.809 13.289 3.418 l 12.582 2.711 b 12.191 2.32 11.563 2.32 11.172 2.711 l 10.852 3.031 b 10.426 2.789 9.969 2.602 9.496 2.473 l 9.496 2.016 b 9.496 1.465 9.051 1.02 8.496 1.02 l 7.5 1.02 m 8.016 4.996 b 9.676 4.996 11.016 6.34 11.016 7.996 b 11.016 9.652 9.676 10.996 8.016 10.996 b 6.359 10.996 5.016 9.652 5.016 7.996 b 5.016 6.34 6.359 4.996 8.016 4.996",
    rewind = "m 8.254 1 b 8.121 1.008 7.988 1.047 7.879 1.117 l 4.129 3.367 b 3.918 3.508 3.793 3.75 3.801 4 b 3.801 4.25 3.914 4.5 4.129 4.637 l 7.879 6.887 b 7.988 6.957 8.121 6.996 8.254 7 l 9.004 7 9.004 5 b 10.75 4.996 12.297 6.133 12.82 7.801 b 13.344 9.465 12.731 11.281 11.297 12.281 b 11 12.484 10.836 12.828 10.867 13.188 b 10.898 13.547 11.117 13.859 11.441 14.012 b 11.77 14.164 12.152 14.125 12.445 13.918 b 14.586 12.414 15.512 9.695 14.727 7.199 b 13.938 4.699 11.621 3.004 9.004 3 l 9.004 1 8.254 1 m 7.16 8.898 b 5.625 8.898 4.594 10.148 4.594 12.02 b 4.594 13.859 5.609 15.086 7.117 15.086 b 8.641 15.086 9.672 13.84 9.672 11.957 b 9.672 10.121 8.656 8.898 7.16 8.898 m 2.285 8.988 l 0.215 10.184 0.777 11.258 1.68 10.789 1.68 13.719 0.52 13.719 0.52 15.004 4.246 15.004 4.246 13.719 3.18 13.719 3.18 8.988 2.285 8.988 m 7.125 10.184 b 7.723 10.184 8.129 10.918 8.129 12.027 b 8.129 13.094 7.73 13.805 7.152 13.805 b 6.535 13.801 6.137 13.066 6.137 11.969 b 6.137 10.895 6.535 10.184 7.125 10.184",
    forward = "m 7.004 1 l 7.004 3 b 4.383 3.004 2.07 4.699 1.281 7.199 b 0.496 9.695 1.418 12.414 3.563 13.918 b 3.855 14.125 4.234 14.164 4.563 14.012 b 4.887 13.859 5.109 13.547 5.137 13.188 b 5.168 12.828 5.004 12.484 4.707 12.281 b 3.277 11.281 2.66 9.465 3.188 7.801 b 3.707 6.133 5.254 4.996 7.004 5 l 7.004 7 7.754 7 b 7.887 6.996 8.016 6.953 8.129 6.883 l 11.879 4.633 b 12.086 4.492 12.211 4.254 12.207 4 b 12.211 3.746 12.086 3.508 11.879 3.367 l 8.129 1.117 b 8.016 1.047 7.887 1.004 7.754 1 l 7.004 1 m 13.16 8.898 b 11.625 8.898 10.594 10.148 10.594 12.02 b 10.594 13.856 11.606 15.086 13.113 15.086 b 14.641 15.086 15.672 13.84 15.672 11.957 b 15.672 10.121 14.656 8.898 13.16 8.898 m 8.285 8.984 l 6.215 10.18 6.777 11.254 7.68 10.785 7.68 13.719 6.52 13.719 6.52 15 10.246 15 10.246 13.719 9.18 13.719 9.18 8.984 8.285 8.984 m 13.125 10.18 b 13.723 10.18 14.129 10.918 14.129 12.027 b 14.129 13.094 13.731 13.805 13.148 13.805 b 12.535 13.805 12.137 13.066 12.137 11.965 b 12.137 10.891 12.535 10.18 13.125 10.18",
    go_next = "m 4 2 b 4 1.734 4.105 1.48 4.293 1.293 b 4.684 0.902 5.316 0.902 5.707 1.293 l 11.707 7.293 b 11.895 7.48 12 7.734 12 8 b 12 8.266 11.895 8.52 11.707 8.707 l 5.707 14.707 b 5.316 15.098 4.684 15.098 4.293 14.707 b 4.105 14.52 4 14.266 4 14 b 4 13.734 4.105 13.48 4.293 13.293 l 9.586 8 4.293 2.707 b 4.105 2.52 4 2.266 4 2",
    rotate_left = "m 8.914 2 b 8.34 2.008 7.762 2.086 7.188 2.238 b 4.133 3.059 2 5.836 2 9 l 0 9 0 10 0.008 10 b 0.004 10.266 0.109 10.52 0.293 10.707 l 2.293 12.707 b 2.684 13.098 3.316 13.098 3.707 12.707 l 5.707 10.707 b 5.891 10.52 5.996 10.266 5.996 10 l 6 10 6 9 4 9 b 4 6.73 5.516 4.758 7.707 4.168 b 9.895 3.582 12.195 4.535 13.332 6.5 b 14.465 8.465 14.141 10.93 12.535 12.535 b 12.145 12.926 12.145 13.559 12.535 13.949 b 12.926 14.34 13.559 14.34 13.949 13.949 b 16.188 11.711 16.645 8.238 15.063 5.5 b 13.875 3.445 11.758 2.176 9.484 2.02 b 9.293 2.004 9.105 1.996 8.914 2",
    rotate_right = "m 7.086 2 b 7.66 2.008 8.238 2.086 8.813 2.238 b 11.867 3.059 14 5.836 14 9 l 16 9 16 10 15.992 10 b 15.996 10.266 15.891 10.52 15.707 10.707 l 13.707 12.707 b 13.316 13.098 12.684 13.098 12.293 12.707 l 10.293 10.707 b 10.105 10.52 10.004 10.266 10.004 10 l 10 10 10 9 12 9 b 12 6.73 10.484 4.758 8.293 4.168 b 6.105 3.582 3.805 4.535 2.668 6.5 b 1.535 8.465 1.859 10.93 3.465 12.535 b 3.855 12.926 3.855 13.559 3.465 13.949 b 3.074 14.34 2.441 14.34 2.051 13.949 b -0.188 11.711 -0.645 8.238 0.938 5.5 b 2.125 3.445 4.242 2.176 6.516 2.02 b 6.703 2.004 6.895 1.996 7.086 2",
}

local function esc(s)
    return (s or ""):gsub("\\", "\\e"):gsub("{", "\\{"):gsub("}", "\\}"):gsub("\n", " ")
end

local function fmt_time(t)
    if not t or t < 0 then return "0:00" end
    t = math.floor(t + 0.5)
    local h, m, s = math.floor(t / 3600), math.floor(t / 60) % 60, t % 60
    return h > 0 and string.format("%d:%02d:%02d", h, m, s) or string.format("%d:%02d", m, s)
end

local function add_box(name, x1, y1, x2, y2, action)
    hitboxes[#hitboxes + 1] = {name=name, x1=x1, y1=y1, x2=x2, y2=y2, action=action}
end

local function shape(a, path, x, y, size, color, alpha, with_shadow)
    local scale = size / 16
    if with_shadow ~= false then
        -- Equivalent to Showtime's stacked CSS drop-shadows: one crisp edge
        -- and one broad halo for bright or low-contrast video frames.
        a:new_event()
        a:append(string.format("{\\an7\\pos(%.1f,%.1f)\\p1\\fscx%.2f\\fscy%.2f\\bord0\\shad0\\blur1\\1c%s\\1a&H%02X&}", x, y, scale*100, scale*100, C.shadow, 70))
        a:append(path)
        a:new_event()
        a:append(string.format("{\\an7\\pos(%.1f,%.1f)\\p1\\fscx%.2f\\fscy%.2f\\bord0\\shad0\\blur5\\1c%s\\1a&H%02X&}", x, y, scale*100, scale*100, C.shadow, 145))
        a:append(path)
    end
    a:new_event()
    a:append(string.format("{\\an7\\pos(%.1f,%.1f)\\p1\\fscx%.2f\\fscy%.2f\\bord0\\shad0\\1c%s\\1a&H%02X&}", x, y, scale*100, scale*100, color or C.white, alpha or 0))
    a:append(path)
end

local function text(a, value, x, y, size, align, bold, alpha)
    a:new_event()
    a:append(string.format("{\\an%d\\pos(%.1f,%.1f)\\fnSans\\fs%d\\b%d\\bord0\\shad0\\1c%s\\1a&H%02X&}%s", align or 7, x, y, size, bold and 1 or 0, C.white, alpha or 0, esc(value)))
end

local function shadow_text(a, value, x, y, size, align, bold)
    for _,layer in ipairs({{1,65},{5,145}}) do
        a:new_event()
        a:append(string.format("{\\an%d\\pos(%.1f,%.1f)\\fnSans\\fs%d\\b%d\\bord0\\shad0\\blur%d\\1c%s\\1a&H%02X&}%s", align or 7,x,y,size,bold and 1 or 0,layer[1],C.shadow,layer[2],esc(value)))
    end
    text(a,value,x,y,size,align,bold)
end

local function rect(a, x1, y1, x2, y2, color, alpha)
    a:new_event()
    a:append(string.format("{\\an7\\pos(0,0)\\p1\\bord0\\shad0\\1c%s\\1a&H%02X&}m %.1f %.1f l %.1f %.1f %.1f %.1f %.1f %.1f", color, alpha or 0, x1,y1,x2,y1,x2,y2,x1,y2))
end

local function round_rect(a, x1, y1, x2, y2, r, color, alpha)
    r = math.min(r, (x2-x1)/2, (y2-y1)/2)
    local k = r * 0.55228475
    a:new_event()
    a:append(string.format("{\\an7\\pos(0,0)\\p1\\bord0\\shad0\\1c%s\\1a&H%02X&}", color, alpha or 0))
    a:append(string.format("m %.1f %.1f l %.1f %.1f b %.1f %.1f %.1f %.1f %.1f %.1f l %.1f %.1f b %.1f %.1f %.1f %.1f %.1f %.1f l %.1f %.1f b %.1f %.1f %.1f %.1f %.1f %.1f l %.1f %.1f b %.1f %.1f %.1f %.1f %.1f %.1f",
        x1+r,y1,x2-r,y1,x2-r+k,y1,x2,y1+r-k,x2,y1+r,x2,y2-r,x2,y2-r+k,x2-r+k,y2,x2-r,y2,x1+r,y2,x1+r-k,y2,x1,y2-r+k,x1,y2-r,x1,y1+r,x1,y1+r-k,x1+r-k,y1,x1+r,y1))
end

local function circle(a,cx,cy,r,color,alpha,blur)
    local k=r*0.55228475
    a:new_event()
    a:append(string.format("{\\an7\\pos(0,0)\\p1\\bord0\\shad0\\blur%d\\1c%s\\1a&H%02X&}",blur or 0,color,alpha or 0))
    a:append(string.format("m %.2f %.2f b %.2f %.2f %.2f %.2f %.2f %.2f b %.2f %.2f %.2f %.2f %.2f %.2f b %.2f %.2f %.2f %.2f %.2f %.2f b %.2f %.2f %.2f %.2f %.2f %.2f",
        cx,cy-r,cx+k,cy-r,cx+r,cy-k,cx+r,cy,cx+r,cy+k,cx+k,cy+r,cx,cy+r,cx-k,cy+r,cx-r,cy+k,cx-r,cy,cx-r,cy-k,cx-k,cy-r,cx,cy-r))
end

local function shadow_circle(a,cx,cy,r)
    circle(a,cx,cy,r,C.shadow,70,1)
    circle(a,cx,cy,r,C.shadow,145,5)
    circle(a,cx,cy,r,C.white,0,0)
end

local function is_hovered(x1,y1,x2,y2)
    local x,y=mp.get_mouse_pos()
    x,y=x or -1,y or -1
    return x>=x1 and x<=x2 and y>=y1 and y<=y2
end


local function triangle(a,x1,y1,x2,y2,x3,y3,color,alpha)
    a:new_event(); a:append(string.format("{\\an7\\pos(0,0)\\p1\\bord0\\shad0\\1c%s\\1a&H%02X&}m %.1f %.1f l %.1f %.1f %.1f %.1f",color,alpha or 0,x1,y1,x2,y2,x3,y3))
end

local function blurred_rect(a,x1,y1,x2,y2,alpha,blur)
    a:new_event()
    a:append(string.format("{\\an7\\pos(0,0)\\p1\\bord0\\shad0\\blur%.1f\\1c%s\\1a&H%02X&}m %.1f %.1f l %.1f %.1f %.1f %.1f %.1f %.1f",
        blur,C.shadow,alpha,x1,y1,x2,y1,x2,y2,x1,y2))
end

local function shade(a,w,h)
    -- ASS has no gradient fill.  A light full-frame veil plus oversized,
    -- blurred edge shapes produces a continuous falloff without striping.
    rect(a,0,0,w,h,C.shadow,230)
    blurred_rect(a,-70,-90,w+70,h*.055,174,52)
    blurred_rect(a,-80,h*.82,w+80,h+90,185,62)
    blurred_rect(a,-80,h*.94,w+80,h+100,155,38)
end

local function hover_circle(a, x, y, radius, x1,y1,x2,y2)
    if is_hovered(x1,y1,x2,y2) then round_rect(a,x-radius,y-radius,x+radius,y+radius,radius,C.white,217) end
end

local function mouse()
    local x, y = mp.get_mouse_pos()
    return x or -1, y or -1
end

local function schedule_hide()
    visible = true
    if hide_timer then hide_timer:kill() end
    hide_timer = mp.add_timeout(3, function()
        if not menu and not settings and not volume_popup then
            visible = false
            hitboxes = {}
            overlay:remove()
        end
    end)
end

local function open_file()
    menu = false
    mp.command_native_async({name="subprocess", playback_only=false,
        args={"zenity", "--file-selection", "--title=Open File", "--file-filter=Videos | *.mp4 *.mkv *.webm *.avi *.mov *.m4v", "--file-filter=All files | *"}},
        function(success, result)
            if success and result and result.status == 0 then
                local path = (result.stdout or ""):gsub("[\r\n]+$", "")
                if path ~= "" then mp.commandv("loadfile", path, "replace") end
            end
            schedule_hide()
        end)
end

local function render()
    local w, h = mp.get_osd_size()
    hitboxes = {}
    if w < 1 or h < 1 or not visible then overlay:remove(); return end
    local a, bottom, cy = assdraw.ass_new(), h - 78, h/2 - 36

    -- Showtime's .shade: a quiet edge gradient that keeps white controls
    -- legible over bright video without dimming the middle of the picture.
    shade(a,w,h)

    -- Header controls, anchored to corners and therefore invariant in pixels.
    hover_circle(a,39,35,23,16,14,62,60)
    shape(a, mp.get_property_native("fullscreen") and icon.restore or icon.fullscreen, 28, 24, 22)
    add_box("fullscreen", 16, 14, 62, 60, function() mp.command("cycle fullscreen") end)
    hover_circle(a,w-78,36,23,w-103,12,w-57,60)
    shape(a, icon.menu, w - 88, 26, 20)
    add_box("menu", w-103, 12, w-57, 60, function() menu=not menu; settings=false; render() end)
    hover_circle(a,w-33,36,23,w-57,12,w-12,60)
    shape(a, icon.close, w - 43, 25, 20)
    add_box("close", w-57, 12, w-12, 60, function() mp.command("quit") end)

    -- Central transport controls.
    hover_circle(a,w/2-72,cy,31,w/2-105,cy-37,w/2-45,cy+35)
    hover_circle(a,w/2,cy,42,w/2-40,cy-42,w/2+40,cy+42)
    hover_circle(a,w/2+72,cy,31,w/2+45,cy-37,w/2+105,cy+35)
    shape(a, icon.rewind, w/2-84, cy-12, 24)
    shape(a, mp.get_property_native("pause") and icon.play or icon.pause, w/2-18, cy-20, 38)
    shape(a, icon.forward, w/2+60, cy-12, 24)
    add_box("rewind",w/2-105,cy-37,w/2-45,cy+35,function() mp.commandv("seek",-10,"relative+exact") end)
    add_box("pause",w/2-40,cy-42,w/2+40,cy+42,function() mp.command("cycle pause") end)
    add_box("forward",w/2+45,cy-37,w/2+105,cy+35,function() mp.commandv("seek",10,"relative+exact") end)

    local margin, duration = 45, mp.get_property_number("duration", 0)
    local pos = mp.get_property_number("time-pos", 0)
    local title = mp.get_property("media-title", "Video"):gsub("%.[^%.]+$", "")
    -- Title and trailing buttons share one middle-aligned toolbar row.
    shadow_text(a, title, margin, bottom-59, 30, 4, true)
    local x1, x2, sy = margin, w-margin, bottom-18
    rect(a,x1,sy-2,x2,sy+2,C.track,217)
    local p = duration > 0 and math.max(0,math.min(1,pos/duration)) or 0
    rect(a,x1,sy-2,x1+(x2-x1)*p,sy+2,C.white,0)
    shadow_circle(a,x1+(x2-x1)*p,sy,12)
    add_box("seek",x1,sy-15,x2,sy+15,function(mx) if duration>0 then mp.commandv("seek",duration*(mx-x1)/(x2-x1),"absolute+exact") end end)
    shadow_text(a,fmt_time(pos),margin,bottom+4,21,7,true)
    shadow_text(a,fmt_time(duration),w-margin,bottom+4,21,9,true)
    hover_circle(a,w-100,bottom-59,23,w-120,bottom-85,w-77,bottom-45)
    shape(a,mp.get_property_native("mute") and icon.muted or icon.volume,w-111,bottom-70,21)
    add_box("volume",w-120,bottom-85,w-77,bottom-45,function() volume_popup=not volume_popup; settings=false; menu=false; render() end)
    hover_circle(a,w-54,bottom-59,23,w-80,bottom-85,w-37,bottom-45)
    shape(a,icon.gear,w-65,bottom-70,21)
    add_box("settings",w-80,bottom-85,w-37,bottom-45,function() settings=not settings; menu=false; volume_popup=false; render() end)

    if menu then
        local pw, ph, px, py = 290, 296, w-315, 72
        triangle(a,w-88,py,w-78,py-11,w-68,py,C.panel,5)
        round_rect(a,px,py,px+pw,py+ph,14,C.panel,5)
        local items={
            {"New Window","Ctrl+N",function() mp.commandv("run","mpv") end},
            {"Open…","Ctrl+O",open_file,"sep"},
            {"Show in Files","",function() local path=mp.get_property("path"); if path then local dir=select(1,utils.split_path(path)); mp.commandv("run","xdg-open",dir) end end,"sep"},
            {"Take Screenshot","Ctrl+Alt+S",function() mp.command("screenshot") end,"sep"},
            {"Keyboard Shortcuts","Ctrl+?",function() mp.osd_message("Space  Play/Pause   ←/→  Seek   F  Fullscreen",4) end},
            {"About Video Player","",function() mp.osd_message("Showtime OSC for mpv",3) end},
        }
        local yy=py+8
        for i,it in ipairs(items) do
            local y1,y2=yy,yy+40
            if is_hovered(px+8,y1,px+pw-8,y2) then round_rect(a,px+8,y1,px+pw-8,y2,9,C.selected,0) end
            text(a,it[1],px+22,y1+10,18,7,false)
            if it[2]~="" then text(a,it[2],px+pw-18,y1+10,16,9,false,90) end
            add_box("menu"..i,px+8,y1,px+pw-8,y2,it[3]); yy=y2
            if it[4] then rect(a,px+10,yy+5,px+pw-10,yy+6,C.white,210); yy=yy+12 end
        end
    elseif settings then
        -- Match Showtime's wider options popover.  Its body reaches farther
        -- right; the stock pointer geometry then joins the bottom edge.
        local pw,ph,px,py=528,304,w-547,bottom-397
        triangle(a,w-64,py+ph-2,w-54,py+ph+9,w-44,py+ph-2,C.panel,5)
        round_rect(a,px,py,px+pw,py+ph,14,C.panel,5)
        local function settings_row(name,y1,y2,action)
            if is_hovered(px+10,py+y1,px+pw-10,py+y2) then round_rect(a,px+10,py+y1,px+pw-10,py+y2,9,C.selected,0) end
            add_box(name,px+10,py+y1,px+pw-10,py+y2,action)
        end
        settings_row("language",6,43,function() mp.command("cycle audio") end)
        settings_row("subtitles",44,82,function() mp.command("cycle sub") end)
        settings_row("repeat",94,135,function() mp.command("cycle loop-file") end)
        text(a,"Language",px+50,py+14,18,7,false)
        shape(a,icon.go_next,px+pw-38,py+19,12,C.white,70,false)
        text(a,"Subtitles",px+50,py+52,18,7,false)
        shape(a,icon.go_next,px+pw-38,py+57,12,C.white,70,false)
        rect(a,px+10,py+88,px+pw-10,py+89,C.white,210)
        text(a,"Repeat",px+50,py+102,18,7,false)
        rect(a,px+10,py+140,px+pw-10,py+141,C.white,210)
        text(a,"Rotate",px+50,py+154,18,7,false)
        local rotate_left_x,rotate_right_x=px+pw-82,px+pw-38
        hover_circle(a,rotate_left_x,py+165,20,rotate_left_x-21,py+145,rotate_left_x+21,py+187)
        hover_circle(a,rotate_right_x,py+165,20,rotate_right_x-21,py+145,rotate_right_x+21,py+187)
        shape(a,icon.rotate_left,rotate_left_x-8,py+157,16,C.white,0,false)
        shape(a,icon.rotate_right,rotate_right_x-8,py+157,16,C.white,0,false)
        add_box("rotate-left",rotate_left_x-21,py+145,rotate_left_x+21,py+187,function() mp.commandv("add","video-rotate",-90) end)
        add_box("rotate-right",rotate_right_x-21,py+145,rotate_right_x+21,py+187,function() mp.commandv("add","video-rotate",90) end)
        rect(a,px+10,py+193,px+pw-10,py+194,C.white,210)
        text(a,"Playback Speed",px+28,py+207,18,7,true)
        local speeds={0.5,1,1.25,1.5,2}; local current_speed=mp.get_property_number("speed",1)
        for i,s in ipairs(speeds) do
            local xx=px+63+(i-1)*100
            if s==current_speed or is_hovered(xx-38,py+244,xx+38,py+286) then round_rect(a,xx-38,py+244,xx+38,py+286,21,C.selected,0) end
            text(a,string.format("%g×",s),xx,py+265,17,5,s==current_speed)
            add_box("speed"..i,xx-38,py+244,xx+38,py+286,function() mp.set_property_number("speed",s); render() end)
        end
    elseif volume_popup then
        local px,py,pw,ph=w-280,bottom-172,250,78
        triangle(a,w-110,py+ph,w-100,py+ph+11,w-90,py+ph,C.panel,5)
        round_rect(a,px,py,px+pw,py+ph,14,C.panel,5)
        shape(a,mp.get_property_native("mute") and icon.muted or icon.volume,px+20,py+28,21,C.white,0,false)
        add_box("mute",px+9,py+16,px+50,py+61,function() mp.command("cycle mute"); render() end)
        local vx1,vx2,vy=px+75,px+225,py+39; rect(a,vx1,vy-2,vx2,vy+2,C.track,80)
        local vol=math.min(100,mp.get_property_number("volume",100)); rect(a,vx1,vy-2,vx1+(vx2-vx1)*vol/100,vy+2,C.white,0); rect(a,vx1+(vx2-vx1)*vol/100-7,vy-7,vx1+(vx2-vx1)*vol/100+7,vy+7,C.white,0)
        add_box("volslider",vx1,vy-18,vx2,vy+18,function(mx) mp.set_property_number("volume",100*(mx-vx1)/(vx2-vx1)); render() end)
    end
    overlay.res_x, overlay.res_y, overlay.data = w,h,a.text
    overlay:update()
end

local function activate(x,y)
    for i=#hitboxes,1,-1 do local b=hitboxes[i]; if x>=b.x1 and x<=b.x2 and y>=b.y1 and y<=b.y2 then b.action(x,y); schedule_hide(); render(); return true end end
    if menu or settings or volume_popup then
        menu,settings,volume_popup=false,false,false
        schedule_hide()
        render()
        return true
    end
    return false
end

local function video_tap(x,y)
    local w = mp.get_osd_size()
    local zone = x < w/3 and "left" or (x > w*2/3 and "right" or "center")
    local now = mp.get_time()
    if last_tap and last_tap.zone == zone and now-last_tap.time <= 0.32 then
        if zone=="left" then mp.commandv("seek",-10,"relative+exact") elseif zone=="right" then mp.commandv("seek",10,"relative+exact") else mp.command("cycle fullscreen") end
        last_tap=nil; schedule_hide(); render(); return
    end
    last_tap={zone=zone,time=now}
end

mp.add_forced_key_binding("MBTN_LEFT","adw-click",function() local x,y=mouse(); if not activate(x,y) then video_tap(x,y) end end)
mp.add_forced_key_binding("MOUSE_MOVE","adw-move",function() schedule_hide(); render() end)
mp.add_forced_key_binding("MBTN_LEFT_DBL","adw-native-double",function() end) -- suppress mpv's default fullscreen binding
mp.add_forced_key_binding("WHEEL_UP","adw-vol-up",function() mp.commandv("add","volume",5); volume_popup=true; schedule_hide(); render() end)
mp.add_forced_key_binding("WHEEL_DOWN","adw-vol-down",function() mp.commandv("add","volume",-5); volume_popup=true; schedule_hide(); render() end)

for _,p in ipairs({"pause","time-pos","duration","media-title","osd-dimensions","fullscreen","volume","mute","speed",u}) do mp.observe_property(p,"native",function() if visible then render() end end) end
mp.register_event("file-loaded",function() schedule_hide(); render() end)
mp.register_event("end-file",function() visible=true; render() end)
mp.register_event("shutdown",function() overlay:remove() end)
schedule_hide(); render()

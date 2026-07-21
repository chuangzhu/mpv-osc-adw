-- GNOME Showtime inspired OSC for mpv
-- Install as ~/.config/mpv/scripts/adw-osc.lua and disable mpv's stock OSC.
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
    fullscreen = "m 0 10 b 0 9 1 9 2 9 l 6 9 6 11 4 11 4 12 2 14 6 14 6 16 0 16 m 10 0 l 16 0 16 6 b 16 7 15 7 14 7 l 14 4 12 4 10 6 9 6 9 5 12 2 10 2",
    restore = "m 1 9 b 1 8 2 8 3 8 l 8 8 8 13 b 8 14 7 15 6 14 l 6 11 3 14 2 14 2 13 5 10 2 10 b 1 10 1 9 1 9 m 8 3 b 8 2 9 1 10 2 l 10 5 13 2 14 2 14 3 11 6 14 6 b 15 6 15 7 15 8 l 8 8",
    volume = "m 0 6 b 0 5 1 5 2 5 l 3 5 7 1 7 15 3 11 2 11 b 1 11 0 10 0 9 m 9 5 b 10 4 11 5 12 6 b 13 8 13 10 11 12 l 9 11 b 11 9 11 7 9 5 m 13 2 b 17 5 17 11 13 14 l 12 12 b 15 10 15 6 12 4",
    muted = "m 0 6 b 0 5 1 5 2 5 l 3 5 7 1 7 15 3 11 2 11 b 1 11 0 10 0 9 m 10 5 l 12 7 14 5 15 6 13 8 15 10 14 11 12 9 10 11 9 10 11 8 9 6",
    gear = "m 6 1 l 10 1 11 3 13 3 15 6 14 8 15 10 13 13 11 13 10 15 6 15 5 13 3 13 1 10 2 8 1 6 3 3 5 3 m 8 5 b 12 5 12 11 8 11 b 4 11 4 5 8 5",
    rewind = "m 7 3 b 2 4 2 12 7 13 l 7 10 b 5 9 5 7 7 6 l 7 8 12 8 12 10 15 7 12 4 12 6 9 6 9 3",
    forward = "m 9 3 b 14 4 14 12 9 13 l 9 10 b 11 9 11 7 9 6 l 9 8 4 8 4 10 1 7 4 4 4 6 7 6 7 3",
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

local function shape(a, path, x, y, size, color, alpha)
    local scale = size / 16
    a:new_event()
    a:append(string.format("{\\an7\\pos(%.1f,%.1f)\\p1\\fscx%.2f\\fscy%.2f\\bord0\\shad0\\1c%s\\1a&H%02X&}", x, y, scale*100, scale*100, color or C.white, alpha or 0))
    a:append(path)
end

local function text(a, value, x, y, size, align, bold, alpha)
    a:new_event()
    a:append(string.format("{\\an%d\\pos(%.1f,%.1f)\\fnSans\\fs%d\\b%d\\bord0\\shad0\\1c%s\\1a&H%02X&}%s", align or 7, x, y, size, bold and 1 or 0, C.white, alpha or 0, esc(value)))
end

local function rect(a, x1, y1, x2, y2, color, alpha)
    a:new_event()
    a:append(string.format("{\\an7\\pos(0,0)\\p1\\bord0\\shad0\\1c%s\\1a&H%02X&}m %.1f %.1f l %.1f %.1f %.1f %.1f %.1f %.1f", color, alpha or 0, x1,y1,x2,y1,x2,y2,x1,y2))
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
    local a, bottom = assdraw.ass_new(), h - 48

    -- Header controls, anchored to corners and therefore invariant in pixels.
    shape(a, mp.get_property_native("fullscreen") and icon.restore or icon.fullscreen, 28, 24, 22)
    add_box("fullscreen", 16, 14, 62, 60, function() mp.command("cycle fullscreen") end)
    shape(a, icon.menu, w - 88, 26, 20)
    add_box("menu", w-103, 12, w-57, 60, function() menu=not menu; settings=false; render() end)
    shape(a, icon.close, w - 43, 25, 20)
    add_box("close", w-57, 12, w-12, 60, function() mp.command("quit") end)

    -- Central transport controls.
    shape(a, icon.rewind, w/2-86, h/2-14, 28); text(a, "10", w/2-71, h/2+6, 9, 5, true)
    shape(a, mp.get_property_native("pause") and icon.play or icon.pause, w/2-18, h/2-20, 38)
    shape(a, icon.forward, w/2+58, h/2-14, 28); text(a, "10", w/2+73, h/2+6, 9, 5, true)
    add_box("rewind",w/2-105,h/2-37,w/2-45,h/2+35,function() mp.commandv("seek",-10,"relative+exact") end)
    add_box("pause",w/2-40,h/2-42,w/2+40,h/2+42,function() mp.command("cycle pause") end)
    add_box("forward",w/2+45,h/2-37,w/2+105,h/2+35,function() mp.commandv("seek",10,"relative+exact") end)

    local margin, duration = 45, mp.get_property_number("duration", 0)
    local pos = mp.get_property_number("time-pos", 0)
    local title = mp.get_property("media-title", "Video")
    text(a, title, margin, bottom-58, 22, 7, true)
    local x1, x2, sy = margin, w-margin, bottom-18
    rect(a,x1,sy-2,x2,sy+2,C.track,80)
    local p = duration > 0 and math.max(0,math.min(1,pos/duration)) or 0
    rect(a,x1,sy-2,x1+(x2-x1)*p,sy+2,C.white,0)
    rect(a,x1+(x2-x1)*p-7,sy-7,x1+(x2-x1)*p+7,sy+7,C.white,0)
    add_box("seek",x1,sy-15,x2,sy+15,function(mx) if duration>0 then mp.commandv("seek",duration*(mx-x1)/(x2-x1),"absolute+exact") end end)
    text(a,fmt_time(pos),margin,bottom+4,15,7,true)
    text(a,fmt_time(duration),w-margin,bottom+4,15,9,true)
    shape(a,mp.get_property_native("mute") and icon.muted or icon.volume,w-105,bottom-70,21)
    add_box("volume",w-120,bottom-85,w-77,bottom-45,function() volume_popup=not volume_popup; settings=false; menu=false; render() end)
    shape(a,icon.gear,w-65,bottom-70,21)
    add_box("settings",w-80,bottom-85,w-37,bottom-45,function() settings=not settings; menu=false; volume_popup=false; render() end)

    if menu then
        local pw, ph, px, py = 285, 294, w-310, 70
        rect(a,px,py,px+pw,py+ph,C.panel,5)
        local items={{"New Window",function() mp.commandv("run","mpv") end},{"Open…",open_file},{"Show in Files",function() local path=mp.get_property("path"); if path then local dir=select(1,utils.split_path(path)); mp.commandv("run","xdg-open",dir) end end},{"Take Screenshot",function() mp.command("screenshot") end},{"Keyboard Shortcuts",function() mp.osd_message("Space  Play/Pause   ←/→  Seek   F  Fullscreen",4) end},{"About mpv",function() mp.osd_message("Showtime OSC for mpv",3) end}}
        for i,it in ipairs(items) do local yy=py+18+(i-1)*44; text(a,it[1],px+18,yy,18,7,false); add_box("menu"..i,px,yy-8,px+pw,yy+33,it[2]) end
    elseif settings then
        local pw,ph,px,py=510,292,w-555,bottom-372
        rect(a,px,py,px+pw,py+ph,C.panel,5)
        text(a,"Language                                      ›",px+28,py+22,18,7,false)
        text(a,"Subtitles                                     ›",px+28,py+66,18,7,false)
        text(a,"Repeat",px+28,py+122,18,7,false)
        add_box("repeat",px,py+108,px+pw,py+151,function() mp.command("cycle loop-file") end)
        text(a,"Rotate                         ↶      ↷",px+28,py+178,18,7,false)
        text(a,"Playback Speed",px+28,py+230,18,7,true)
        local speeds={0.5,1,1.25,1.5,2}; for i,s in ipairs(speeds) do local xx=px+54+(i-1)*100; text(a,string.format("%g×",s),xx,py+270,17,5,s==mp.get_property_number("speed",1)); add_box("speed"..i,xx-38,py+248,xx+38,py+290,function() mp.set_property_number("speed",s); render() end) end
    elseif volume_popup then
        local px,py,pw=w-280,bottom-195,250
        rect(a,px,py,px+pw,py+78,C.panel,5)
        shape(a,mp.get_property_native("mute") and icon.muted or icon.volume,px+20,py+28,21)
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
    return false
end

local function video_tap(x,y)
    local w = mp.get_osd_size()
    local zone = x < w/3 and "left" or (x > w*2/3 and "right" or "center")
    local now = mp.get_time()
    if last_tap and last_tap.zone == zone and now-last_tap.time <= 0.32 then
        if tap_timer then tap_timer:kill(); tap_timer=nil end
        if zone=="left" then mp.commandv("seek",-10,"relative+exact") elseif zone=="right" then mp.commandv("seek",10,"relative+exact") else mp.command("cycle fullscreen") end
        last_tap=nil; schedule_hide(); render(); return
    end
    last_tap={zone=zone,time=now}
    if tap_timer then tap_timer:kill() end
    tap_timer=mp.add_timeout(0.33,function() last_tap=nil; mp.command("cycle pause"); schedule_hide(); render() end)
end

mp.add_forced_key_binding("MBTN_LEFT","adw-click",function() local x,y=mouse(); if not activate(x,y) then video_tap(x,y) end end)
mp.add_forced_key_binding("MOUSE_MOVE","adw-move",function() schedule_hide(); render() end)
mp.add_forced_key_binding("MBTN_LEFT_DBL","adw-native-double",function() end) -- suppress mpv's default fullscreen binding
mp.add_forced_key_binding("WHEEL_UP","adw-vol-up",function() mp.commandv("add","volume",5); volume_popup=true; schedule_hide(); render() end)
mp.add_forced_key_binding("WHEEL_DOWN","adw-vol-down",function() mp.commandv("add","volume",-5); volume_popup=true; schedule_hide(); render() end)

for _,p in ipairs({"pause","time-pos","duration","media-title","fullscreen","volume","mute","speed"}) do mp.observe_property(p,"native",function() if visible then render() end end) end
mp.register_event("file-loaded",function() schedule_hide(); render() end)
mp.register_event("end-file",function() visible=true; render() end)
mp.register_event("shutdown",function() overlay:remove() end)
schedule_hide(); render()

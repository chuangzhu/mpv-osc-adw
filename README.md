# mpv-osc-adw

A mpv OSC heavily inspired by GNOME Showtime.

## Install

```sh
mkdir -p ~/.config/mpv/scripts
cp osc-adw.lua ~/.config/mpv/scripts/
```

Dependencies: [adwaita-fonts](https://gitlab.gnome.org/GNOME/adwaita-fonts),
and [`zenity`](https://gitlab.gnome.org/GNOME/zenity) for `Open…` file chooser.

Recommended mpv settings:

```
keepaspect-window=no
```

Recommended GNOME Shell extension: [Rounded Window Corners Reborn](https://extensions.gnome.org/extension/7048/rounded-window-corners-reborn/)

Recommended niri settings:

```kdl
window-rule {
    match app-id="mpv"
    geometry-corner-radius 12
    clip-to-geometry true
}
window-rule {
    match app-id="mpv" is-focused=true
    shadow {
        on
        softness 12
        spread 2
        offset x=0 y=4
        color "#0000003a"
    }
}
```

## Gestures

- Double-tap the left third to rewind 10 seconds.
- Double-tap the right third to fast-forward 10 seconds.
- Double-tap the middle third to toggle fullscreen.

## Acknowledgement

The embedded icons are copied from [adwaita-icon-theme](https://gitlab.gnome.org/GNOME/adwaita-icon-theme) and [Showtime](https://gitlab.gnome.org/GNOME/showtime).

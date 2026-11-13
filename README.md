# omarchy-tasklist

A taskbar for the [Omarchy](https://omarchy.org) bar: every open window as an
icon, grouped into one pill per Hyprland workspace, so you can see at a glance
what's open and where. Click to jump to a window, or drag it onto another
workspace.

![Tasklist pills in the Omarchy bar](screenshots/bar.png)

## Install

```bash
omarchy plugin add https://github.com/antar37/omarchy-tasklist --enable
omarchy plugin enable antar37.tasklist left --after omarchy.workspaces
```

The second line places it right after the workspace numbers; leave it out to
use the default spot in the left section, or drag it anywhere on the bar.
Update later with `omarchy plugin update`.

## Use

| Action | What it does |
|---|---|
| Left click an icon | Focus that window |
| Middle click an icon | Close that window |
| Hover an icon | Show the window title |
| **Right**-drag an icon onto another pill | Move the window to that workspace (you stay where you are) |
| Right-drag onto the `+N` pill | Move the window to the first empty workspace |

The focused window is highlighted. Pills follow workspace order; special
workspaces (like the scratchpad) show as ★ at the end.

**Why right-drag?** The Omarchy bar uses left-drag to rearrange its widgets
and takes that gesture before any widget sees it, so dragging windows uses the
right mouse button instead.

## How it works

Everything is in `Tasklist.qml`. Windows come live from Quickshell's Hyprland
integration (`Hyprland.toplevels`), which knows each window's workspace and
address, so there's no polling and nothing breaks when titles change. Moving a
window runs `hyprctl dispatch 'hl.dsp.window.move({ workspace = "N", follow = false, window = "address:…" })'`.
Icons come from the window's app id through your icon theme, falling back to
the matching desktop entry.

If an app shows a generic icon, its window's app id doesn't match any icon
name. Linking its real icon under that name fixes it, e.g.
`ln -s /usr/share/icons/hicolor/256x256/apps/<real-icon>.png ~/.local/share/icons/hicolor/256x256/apps/<app-id>.png`.

## Requirements

Omarchy with the Quickshell bar (`omarchy-shell`) on Hyprland with the Lua
config.

## License

MIT

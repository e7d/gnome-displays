# gnome-displays

Save your GNOME monitor layouts and switch between them from the terminal.

```sh
curl -fsSL https://github.com/e7d/gnome-displays/releases/latest/download/install.sh | bash
```

## Why this exists

GNOME keeps one remembered arrangement per set of monitors, and re-detection isn't always kind about restoring it. Dock the laptop and the windows scatter; unplug and the primary display ends up on the wrong screen; plug in a projector and you're back in the Settings panel dragging rectangles around.

So I save each arrangement as a named profile and reapply the right one when I need it, or let a small service do it for me every time the monitors change.

## Usage

Save the current arrangement:

```sh
gnome-displays save office
```

List what you've saved (append `--available` to show only the ones whose monitors are all plugged in):

```sh
gnome-displays list
```

Apply one by name, or let it pick the best match for whatever is connected:

```sh
gnome-displays apply office
gnome-displays apply          # auto-select
```

Applying persists across reboots and asks GNOME to confirm the change, same as the Settings panel. Pass `--temporary` to apply for the current session only, without the confirmation prompt.

The rest:

```sh
gnome-displays show office     # print a profile's monitors and settings
gnome-displays verify office   # check a profile applies cleanly
gnome-displays delete office
```

## Apply automatically

Install a systemd user service that applies the best matching profile at login and again whenever you plug or unplug a monitor:

```sh
gnome-displays setup             # copy the command into ~/.local/bin
gnome-displays service --install
```

It applies in temporary mode, so no confirmation dialog interrupts you, and it waits for the display to settle before acting (docks can take a while to sort themselves out). Check on it or remove it:

```sh
gnome-displays service --status
gnome-displays service --remove
```

Follow along in the journal:

```sh
journalctl --user -u gnome-displays.service -f
```

## Requirements

- GNOME 48 or newer (it drives `gdctl`)
- `jq`, `gawk`, `column`
- `gdbus` and a systemd user session for the auto-apply service

It talks to Mutter, so it's for GNOME sessions. It won't do anything useful under other desktops.

## Shell completion

```sh
gnome-displays completion fish > ~/.config/fish/completions/gnome-displays.fish
gnome-displays completion bash > ~/.local/share/bash-completion/completions/gnome-displays
gnome-displays completion zsh  > ~/.zfunc/_gnome-displays
```

## Installing by hand

If piping a script into your shell makes you uneasy, that's fair. `install.sh` is short, so download it and read it first:

```sh
curl -fsSLO https://github.com/e7d/gnome-displays/releases/latest/download/install.sh
less install.sh
bash install.sh
```

Or grab `gnome-displays.sh` from the [latest release](https://github.com/e7d/gnome-displays/releases/latest), drop it somewhere on your `PATH`, and make it executable. To pin a version, set `GNOME_DISPLAYS_VERSION=0.1.0` before running the installer.

To remove everything: `gnome-displays service --remove` then `gnome-displays setup --remove`.

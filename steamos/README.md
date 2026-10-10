# SteamOS support for g13d

Builds and runs the Logitech G13 userspace driver on SteamOS (Steam Deck and
other SteamOS devices). The read-only system stays untouched, and everything
survives SteamOS updates.

## Requirements

* [Homebrew](https://brew.sh) installed (the scripts install the formulae they need).
* A sudo password for `deck`. SteamOS doesn't set one by default, so run `passwd` in
  Konsole first. sudo is needed only once, to install the udev rule.

## Install

From Desktop Mode, in Konsole:

```bash
git clone <this repo> ~/g13 && cd ~/g13
./steamos/install.sh
```

If you received only this `steamos/` directory, run `./install.sh` from inside it.
The script clones the upstream sources into `~/.local/src/g13`.

| Installed file | Purpose |
|---|---|
| `~/.local/bin/g13d`, `pbm2lpbm`, `g13-profile` | Driver, LCD image converter, profile switcher |
| `~/.config/g13/*.bind` | Key maps (you can edit these; reinstalling keeps your changes) |
| `~/.config/g13/games/*.bind` | Per-game profiles |
| `~/.config/systemd/user/g13d.service` | Starts g13d automatically in Game Mode and Desktop Mode |
| `/etc/udev/rules.d/91-g13.rules` | Lets your user access the G13 and uinput |

Options: `--reset-config` (restore the default key maps) and `--clean` (full rebuild).
To remove everything: `./steamos/uninstall.sh [--purge]`.

## Default layout

Based on the [MirrorBoard](https://github.com/nicoseddio/G13_Keyboard_Profiles)
profile. The LCD shows the active mode and a key legend, and each mode has its own
backlight colour and M-key LED.

| Key | M1 WASD (blue) | M2 Mirror (green) | M3 Num/Sym (orange) |
|---|---|---|---|
| G1–G7 | Tab Q W E R T Bksp | Esc P O I U Y Del | `` ` `` `\` 9 8 7 - = |
| G8–G14 | Shift A S D F G Enter | Shift ; L K J H Enter | Shift ' 6 5 4 [ ] |
| G15–G19 | Z X C V B | / . , M N | . 3 2 1 0 |
| G20–G22 | Ctrl Alt Space | Ctrl Alt Space | Ctrl Alt Space |
| Thumb LEFT | → M3 | → M3 | → M1 |
| Thumb DOWN | → M2 | → M1 | → M2 |
| Stick | Arrow keys | Arrow keys | Arrow keys |
| Stick click | Esc | Esc | Esc |

M1/M2/M3 switch modes, and MR returns to M1.

> g13d runs commands only when a key is pressed, not when it's released. So modes
> are switched, not held. MirrorBoard's "hold G22 to mirror" isn't supported yet.

## Steam integration

The G13 isn't a game controller, so Steam Input can't configure it. Instead, switch
G13 profiles per game in **Properties → Launch Options**:

```
~/.local/bin/g13-profile starcraft2 %command%
```

This loads `~/.config/g13/games/starcraft2.bind`, shows `GAME PROFILE / starcraft2`
on the LCD, lights MR, and returns to M1 when the game exits. M1–M3 still work while
a game profile is active. To switch manually: `g13-profile <name>` or `g13-profile default`.

A game profile is a list of `bind` lines (see the top-level README for the command
reference), for example:

```
bind G1 KEY_1
bind G2 KEY_2
bind STICK_UP KEY_W
```

## Troubleshooting

```bash
systemctl --user status g13d          # is it running?
journalctl --user -u g13d -f          # live log (key binds, errors)
echo "rgb 255 0 0" > $XDG_RUNTIME_DIR/g13-0   # send a command to the running driver
```

* **"doesn't grant write permissions" for uinput**: log out and back in (or reboot)
  after the first install, so the udev ACLs are applied to your session.
* **Nothing happens after an update**: run `./steamos/install.sh` again. Your config
  is kept.

## How the build works

SteamOS has no `/usr/include`, so libc headers come from Homebrew's keg-only `glibc`.
Adding them with `-I`, `-isystem` or `C_INCLUDE_PATH` breaks GCC's `#include_next`
chain (`<cstdlib>` → `<stdlib.h>`), so `build.sh` uses `-idirafter`, which keeps the
search order. Binaries link against Homebrew glibc and use its loader
(`-Wl,--dynamic-linker=$(brew --prefix)/lib/ld.so`), which avoids `GLIBC_PRIVATE`
symbol errors.

## Credits

* [MirrorBoard](https://github.com/nicoseddio/G13_Keyboard_Profiles) by nicoseddio for the default profiles.
* [g13](https://github.com/ecraven/g13) by ecraven for the original G13 daemon project.
* [g13 fork](https://github.com/khampf/g13) by khampf for the active fork used in this driver.

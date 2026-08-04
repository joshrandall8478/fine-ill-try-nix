# Manual

The long version: what every module does, which options exist, and why the
awkward parts are the shape they are. [README.md](README.md) is the map — the
hosts, the layout and the rebuild commands. This is everything else.

Written to be read out of order. Nothing below is required reading to rebuild
the machine.

## Contents

- [What's here](#whats-here)
- [niri (alternative to Plasma)](#niri-alternative-to-plasma)
  - [Layout](#layout)
  - [The bar](#the-bar)
  - [The on-screen display](#the-on-screen-display)
  - [Theme switching](#theme-switching)
  - [Keys](#keys)
  - [Clipboard history](#clipboard-history)
  - [Emoji picker](#emoji-picker)
  - [Staying awake](#staying-awake)
  - [No automatic sleep on mains power](#no-automatic-sleep-on-mains-power)
  - [The lid](#the-lid)
  - [Coming back from suspend](#coming-back-from-suspend)
  - [Displays](#displays)
  - [Brightness](#brightness)
  - [The login screen](#the-login-screen)
  - [Screenshots](#screenshots)
  - [Lock screen](#lock-screen)
  - [RGB lighting](#rgb-lighting)
- [Wallpapers](#wallpapers)
  - [Which twenty, and who decides](#which-twenty-and-who-decides)
  - [Why the images aren't in the store](#why-the-images-arent-in-the-store)
  - [The one-off directory change](#the-one-off-directory-change)
  - [What the first rebuild will do](#what-the-first-rebuild-will-do)
- [Dates and times](#dates-and-times)
- [The browser](#the-browser)
  - [File associations, and why they're in /etc](#file-associations-and-why-theyre-in-etc)
  - [Why Firefox is still here](#why-firefox-is-still-here)
  - [How it follows the theme](#how-it-follows-the-theme)
  - [What Nix owns and what Sync owns](#what-nix-owns-and-what-sync-owns)
- [Bootloader](#bootloader)
  - [Dual boot: finding the other operating systems](#dual-boot-finding-the-other-operating-systems)
  - [How the boot menu ends up wearing the desktop's colours](#how-the-boot-menu-ends-up-wearing-the-desktops-colours)
- [Shells](#shells)
  - [`nix-clean`](#nix-clean)
- [Development environments](#development-environments)
  - [One import, and it's off by default](#one-import-and-its-off-by-default)
  - [The one-command path](#the-one-command-path)
  - [The manual path](#the-manual-path)
  - [Day to day](#day-to-day)
  - [Why a project shell is instant](#why-a-project-shell-is-instant)
  - [Secrets](#secrets)
  - [A project that isn't yours](#a-project-that-isnt-yours)
  - [VS Code](#vs-code)
- [Single GPU passthrough](#single-gpu-passthrough)
  - [What it costs](#what-it-costs)
  - [Turning it on](#turning-it-on)
  - [The guest itself](#the-guest-itself)
  - [What happens when the guest starts](#what-happens-when-the-guest-starts)
  - [And when it stops](#and-when-it-stops)
  - [When it goes wrong](#when-it-goes-wrong)
- [Local AI](#local-ai)
  - [Turning it on](#turning-it-on-1)
  - [The first rebuild is a long one](#the-first-rebuild-is-a-long-one)
  - [Models](#models)
  - [Open WebUI](#open-webui)
  - [OpenClaw, and what it costs](#openclaw-and-what-it-costs)
  - [Sharing the card with a VM](#sharing-the-card-with-a-vm)
  - [When it goes wrong](#when-it-goes-wrong-1)
- [Scheduled jobs](#scheduled-jobs)
  - [When not to use it](#when-not-to-use-it)
- [The accounts](#the-accounts)
  - [What "primary user" actually decides](#what-primary-user-actually-decides)
  - [One profile, two accounts](#one-profile-two-accounts)
  - [Adding a third](#adding-a-third)
- [The root account](#the-root-account)
- [Where things came from](#where-things-came-from)
- [Before you build this](#before-you-build-this)
- [Regenerating hardware-configuration.nix](#regenerating-hardware-configurationnix)
- [Fresh install from the NixOS ISO](#fresh-install-from-the-nixos-iso)
- [The XDG_DATA_DIRS workaround (nixpkgs#126590)](#the-xdg_data_dirs-workaround-nixpkgs126590)
- [Rebuilding after changes](#rebuilding-after-changes)
- [Hosts](#hosts)
  - [What actually differs](#what-actually-differs)
  - [The server](#the-server)
  - [The NVIDIA server](#the-nvidia-server)
  - [Adding another host](#adding-another-host)
- [Updating the dotfiles-derived assets](#updating-the-dotfiles-derived-assets)

## What's here

```
flake.nix                        # inputs: nixpkgs, home-manager, plasma-manager,
                                 #   spicetify-nix, nvidia-patch, dotfiles,
                                 #   wallhaven-toplist
hosts/gamestation/                # the desk: NVIDIA, multi-monitor
  configuration.nix               # top-level system config, imports the modules below
  hardware-configuration.nix      # PLACEHOLDER — replace with your real hardware scan
  kernel-params.nix               # boot.kernelParams, shared with gamestation-niri
hosts/laptop/                     # portable: no NVIDIA, single display
  configuration.nix
  hardware-configuration.nix      # PLACEHOLDER — regenerate on the machine
hosts/server/                     # headless: no desktop, cron jobs
  configuration.nix
  hardware-configuration.nix      # PLACEHOLDER — regenerate on the machine
hosts/server-nvidia/              # headless with a card: NVENC/NvFBC unlocked
  configuration.nix
  hardware-configuration.nix      # PLACEHOLDER — regenerate on the machine
modules/nixos/
  base.nix                        # nix settings, locale/timezone, fish, base fonts
  plasmalogin.nix                     # SDDM (Wayland) + Plasma 6, portals, audio, Flatpak
  development.nix                 # direnv, Docker, nix settings — commented out
                                  #   per host, see below
  virtualization.nix              # libvirtd/QEMU/virt-manager — imported per host
  gpu-passthrough.nix             # single GPU passthrough: the libvirt hook that
                                  #   lends the only card to a guest and takes it back
  ai.nix                          # local models: ollama on the GPU, Open WebUI,
                                  #   and the OpenClaw agent — imported per host
  default-apps.nix                # /etc/xdg/mimeapps.list — file associations,
                                  #   overridable from a settings panel
  cron.nix                        # local.cron.jobs -> the system crontab
  emoji.nix                       # Microsoft Fluent Emoji as the system emoji font
  plasma-xdg-data-dirs.nix        # workaround for nixpkgs#126590 (see below)
  nvidia.nix                      # NVIDIA driver, 32-bit graphics for Steam/Proton,
                                  #   and the suspend/resume video-memory handling
  nvidia-server.nix               # the same card with no monitor on it: persistence,
                                  #   the container toolkit, the nvidia-patch overlay
  gaming.nix                      # Steam, MangoHud
  openrgb.nix                     # OpenRGB daemon + re-applying the profile on resume
  laptop.nix                       # power-profiles-daemon, upower, thermald, fstrim
  power.nix                        # no idle suspend while on mains power
  boot.nix                         # bootloader: limine theming + other-OS detection
  options.nix                      # local.boot.*, local.power.*, local.sddm.*,
                                   #   local.openrgb.*, local.virtualisation.*,
                                   #   local.ai.*, local.nvidia.*
  users.nix                        # the `joshr`, `raiden` and `root` accounts
home/common/
  options.nix                      # local.* options the entrypoints toggle
  shell.nix                        # fish + starship, shared by every account
  files/                           # starship.toml, smallfetch.jsonc
home/joshr/
  gamestation.nix                  # host entrypoint: enables the 2nd-monitor panel
  laptop.nix                       # host entrypoint: single-display panels
  server.nix                       # host entrypoint: shell only, no desktop base
  home.nix                         # packages (Spotify, Discord, ProtonUp-Qt, ...)
  browser.nix                      # the default browser: Vivaldi, $BROWSER
                                   #   (handlers: modules/nixos/default-apps.nix)
  firefox.nix                      # Firefox: profile, prefs, sync (installed, not default)
  wallhaven.nix                    # wallhaven's top 20 -> ~/.local/share/wallpapers/
                                   #   WallhavenFlake, from the locked listing
  kitty.nix                        # kitty terminal + zenwritten_dark theme
  vscode.nix                       # VS Code settings + extension list
  niri/                            # the niri desktop; see the section below
    default.nix                    #   imports, GTK/Qt theming, Dolphin
    themes.nix theming.nix         #   the palettes, and every generated config
    niri.nix waybar.nix            #   compositor config and the bar
    scripts.nix notifications.nix  #   theme/wallpaper/lock/screenshot helpers
    clipboard.nix                  #   clipboard history
    emoji.nix                      #   the Mod+. emoji picker
    vscode.nix lock.nix            #   editor theming, idle handling
  plasma.nix                       # KDE Plasma settings/panels/shortcuts (plasma-manager)
  files/                           # DarkObsidianII.colors
home/raiden/
  home.nix                         # names the account, and nothing else
  gamestation.nix laptop.nix       # host entrypoints, each importing joshr's
  gamestation-niri.nix             #   counterpart verbatim
  laptop-niri.nix server.nix
home/root/
  home.nix                         # fish + starship only, no desktop
templates/                         # `nix flake init -t` dev environments
  generic/ python/ node/ rust/ go/
```

## niri (alternative to Plasma)

There are niri variants of both machines. They're separate hosts rather than
a switch inside the existing ones, because Plasma here uses
plasma-login-manager and niri uses SDDM.

```bash
sudo nixos-rebuild switch --flake .#gamestation-niri   # use niri
sudo nixos-rebuild switch --flake .#gamestation        # back to Plasma
```

Nothing is destroyed either way, and the previous generation stays in the
boot menu. `laptop-niri` is the same deal for the laptop.

The niri hosts deliberately **don't** import `plasma-xdg-data-dirs.nix`.
That workaround exists because plasma-workspace's Qt wrapper builds an ~18 KB
`XDG_DATA_DIRS`; there's no plasma-workspace in a niri session, so the bug
can't occur — and neither can the from-source rebuild the workaround costs.

### Layout

```
modules/nixos/niri.nix        # session, SDDM + theme, polkit, PAM, portals
modules/nixos/ddcci.nix       # DDC/CI brightness for external monitors
home/joshr/displays/
  gamestation.nix             # DP-3 + DP-2 layout — edit here for monitors
  laptop.nix                  # empty: niri auto-detects
home/joshr/niri/
  default.nix                 # entrypoint: packages, GTK/Qt/cursor
  themes.nix                  # the palettes — edit colours here
  theming.nix                 # renders each palette into per-tool configs
  niri.nix                    # config.kdl: binds, layout, window rules
  waybar.nix                  # bar layout + style
  notifications.nix           # dunst + wofi
  osd.nix                     # swayosd: the volume/brightness pop-up
  lock.nix                    # swayidle timers
  scripts.nix                 # theme/wallpaper/screenshot/session helpers
```

### The bar

Left is the username, workspaces and the focused window title, centre is the
clock and date, right is the tray, media controls, brightness, volume,
network, battery, caps lock and gamemode while each is on, the idle inhibitor,
then **lock** and **power** as a matched pair at the far end. Each group is
its own rounded floating pill rather than one long bar.

The right-hand group is deliberately tight — the modules carry no horizontal
margin of their own, so the bar's 4px `spacing` is the entire gap between two
pills. There is a wrinkle worth knowing before changing it: **`spacing` is one
number for the whole bar**, with no per-group setting, so cutting it to bring
the right-hand cluster together also cut the left. The left group's three
modules carry 1px either side in the stylesheet to put that back.

**The username** is the first slot, in the accent colour — the same treatment
the clock gets, because both are labels rather than controls. It's static
text with no `exec`: the name comes from `config.home.username` at build
time, so there's no subprocess polling for a string that can't change while
the bar is running, and a second user's generation renders their own name
without editing anything.

Lock and power are styled identically and differ only on hover — the power
button goes red, because it's the one that can end the session. The lock
button runs the same `lock-now` as `Mod+L` and the session menu's "Lock"
entry, so all three take the active theme's colours.

**Brightness** sits immediately left of the volume, the two controls on the
bar that are a level rather than a state. Scroll it to adjust; there is no
click action, because brightness has no equivalent of mute and a click that
jumped to a fixed level is a worse thing to hit by accident than nothing.

The scroll runs the same `brightness` helper as the keys rather than waybar's
own stepping, for the reason that helper exists: the built-in stepping is
`brightnessctl` with no `--device`, which moves the first backlight device and
leaves the rest — invisible with one internal panel, wrong on the desk with
one device per monitor. Setting `on-scroll-up`/`on-scroll-down` replaces the
module's stepping rather than adding to it, so `scroll-step` would do nothing
and isn't there; the step is the 5 inside the script. Unlike the volume
module, nothing overrides it down to 1 — DDC/CI writes are slow and the script
drops overlapping runs, so a finer step would mostly land on a held lock.

It is waybar's built-in `backlight` module even so, because the number has to
be right whatever moved the level — the scroll, a media key, the pre-lock dim
in `lock.nix`. Those all write the device through sysfs, which is what the
module watches, so it repaints on the change instead of on a timer. What it
shows is the *first* device's level, the same convention the OSD uses and for
the same reason. See "Brightness" below.

On a host with no backlight device at all it draws no text but still holds its
padding — it isn't one of the custom modules waybar hides outright. That's the
desk before the reboot `ddcci` needs, and it sorts itself out.

**Caps lock** is one glyph between the battery and the idle inhibitor, in the
theme's warn colour, and it is on the bar *only* while caps lock is on. The
rest of the time it isn't dimmed or blank, it's gone — no glyph, no gap, the
bar exactly as it was before.

That last part is why it's a custom module and not waybar's built-in
`keyboard-state`, which reads the same LED and would need no script at all.
`keyboard-state` always draws its label; even with the text emptied out, the
label stays in the layout and still costs the gap the bar puts between
modules, and a GTK stylesheet has no `display: none` to take it out. A custom
module that prints an empty line is hidden by waybar itself and costs nothing
— the same trick the visualiser below uses to disappear when the music stops.

The script watches the caps LED rather than polling: the compositor mirrors
the lock state onto every keyboard's LED, and the kernel passes each change to
everything holding the device open, so one blocking `select` is the whole loop
and the glyph turns over with the keypress. It's Python because it needs to
ask each device whether it has a caps LED and read the starting state with an
ioctl, neither of which shell can do. Reading `/dev/input` needs the `input`
group, which `joshr` has from `modules/nixos/users.nix`; without it the script
finds no keyboards and exits, and the bar is just short one module. See
`capsLockWatch` in `home/joshr/niri/scripts.nix`.

None of this is the caps lock OSD that swayosd deliberately doesn't run (see
"The on-screen display"): that one is a system service reading every input
device to draw a pop-up, where this is the session's own bar reading the
keyboard the session is already using.

**GameMode** sits immediately to its right and disappears the same way — a
controller glyph in the accent colour while a game holds gamemode, and no slot
at all the rest of the time. The accent rather than caps lock's warn colour
because the two are neighbours that can be lit at once, and because gamemode
being on is something you asked for rather than something to warn you about.

It's polled, not watched: gamemode has somewhere to *ask* — a D-Bus daemon
with a status call — but nothing a shell can subscribe to. So the module works
the way the idle inhibitor does, a 30-second `interval` as the backstop and a
`signal` for the answer that matters. The gamemode start and end hooks in
`modules/nixos/gaming.nix` already fire a notification; they now also send
waybar `SIGRTMIN+9`, so the glyph appears as the game takes gamemode instead
of up to half a minute later. **The signal number is written in two places**
— that hook and the module in `waybar.nix` — and nothing checks that they
still agree.

The script (`gamemodeStatus` in `scripts.nix`) checks that `gamemoded` is
running before asking it anything. gamemoded is D-Bus activated, so a bare
`gamemoded --status` on a timer would keep starting the very daemon it's
reporting on. It matches `is active` and not `active`, for the reason you'd
expect from "inactive".

**The visualiser** is eight bars of cava just left of the track name, in the
theme's dimmed accent. It is only there while something is actually making
noise: the script prints an empty line on a silent frame and waybar hides a
custom module with no text, so the bar looks exactly as it did before
whenever nothing is playing — no reserved slot, no flat row of glyphs.

It follows the *audio*, not the mpris player, so a notification chime blips
it for a moment too. That's the trade for needing no polling and no second
process: cava already knows whether there's sound. Tying it to the player
would mean gating the loop on `playerctl --follow status`.

After two seconds of silence cava stops doing FFT and only checks for input
once a second, so the idle cost is close to nothing. `cava` is also on PATH
on its own — running it in a terminal is the quickest way to tell whether
it's cava or the widget at fault if the bar stays empty. See `cavaBar` in
`home/joshr/niri/scripts.nix`.

### The on-screen display

Volume and brightness raise a pop-up — icon, bar and the number, low and
centred on every output, in the active theme's colours. niri has none of its
own, being a compositor and nothing else, so before this the keys were silent:
the level moved and the only way to see where it had landed was waybar — a
number in a corner of one display, which you have to already be looking at.

**swayosd** draws it. `swayosd-server` is a user service (`osd.nix`); a
one-shot `swayosd-client` asks it to draw over the session bus. The mute keys
get a worded message instead of a bar — "Muted", "Microphone muted" — because a
toggle has no level to show, and because a client request can't grey out the
bar the way swayosd's own volume OSD does.

**swayosd never changes anything, only draws.** `swayosd-client --output-volume
raise` would do both in one call, and that is the usage its README documents,
but with the server down it does neither — a crashed OSD daemon would take the
media keys with it. So `volume` and `brightness` (`scripts.nix`) make the
change themselves, read the result back, and then ask for a pop-up, with every
one of those calls best-effort. The worst case is a change you don't see.

Brightness has a second reason: swayosd drives `brightnessctl` with at most one
`--device`, which is the exact thing `brightness` exists to work around (see
"Brightness" below), and asking it for a wildcard makes `brightnessctl get`
print one line per display into a parser that wants a single number.

Reading the level back rather than predicting it is also what keeps the number
honest — clamping at 0% and 100% is `brightnessctl`'s and `wpctl`'s, and a
level computed here would be wrong at both ends of the range. `volume show`
draws the current level without changing it, which is the quickest way to tell
whether the daemon is up.

Every route to the volume goes through that one script: the media keys, and
waybar's click-to-mute and scroll. The bar's scroll passes an explicit step of
1, since a scroll notch moves a single point where a key moves five —
`scroll-step` no longer does anything once `on-scroll-up`/`on-scroll-down` are
set, so it's gone from the module rather than left there looking load-bearing.

It appears on **every** output rather than only the focused one, which is
swayosd's default and is left alone. `swayosd-client --monitor <name>` would
narrow it, but only if something works out which output is focused first —
`niri msg focused-output` on every keypress, with a fallback for when that
fails — and two small pop-ups is a cheaper thing to live with than a key that
sometimes shows nothing.

Two things it deliberately doesn't do. **The idle dim doesn't raise one**: the
dim happens when you've stopped touching the machine and the restore happens
the instant you touch it again, so a pop-up on the way back would fire on every
return to the desk to report a level that hasn't changed. And **nothing shows
on the lock screen** — a session lock draws above every layer-shell surface,
which is the point of it. The keys still work there; `allow-when-locked` is
about the volume moving, not about the pop-up.

The libinput backend — caps lock, num lock, scroll lock — is not set up. That
half is a system service wanting udev rules and polkit, it reads every input
device to do its job, and none of the three keys is one this session has
anything to say about.

### Theme switching

29 palettes ship, and `nord` is the default.

`joshrandall-net` is the house palette — dark neutral grey with a pastel
green. Greens: `matrix` (bright phosphor), `forest`, `mint`. Monochrome:
`mono` (white on black), `mono-light` (black on white). Reds: `blackred`,
`crimson`. Then `catppuccin-mocha`, `catppuccin-macchiato`,
`catppuccin-frappe`, `rose-pine`, `rose-pine-moon`, `nord`, `dracula`,
`tokyo-night`, `everforest`, `kanagawa`, `solarized`, and the four Gruvbox
contrasts — `gruvbox` (medium), `gruvbox-hard`, `gruvbox-soft` and
`gruvbox-light`, all transcribed from morhetz/gruvbox's own palette.

Four are originals rather than transcriptions: `synthwave` (neon magenta on
midnight violet), `ember` (amber on a cold neutral charcoal, where Gruvbox's
orange sits on a warm one), `abyss` (cyan on deep-water navy) and `sakura`
(pastel rose on ink plum).

Three light options besides `mono-light`: `rose-pine-dawn` is the cool one,
`gruvbox-light` the yellow one, and `sandstone` — warm paper and sienna —
sits between them.

`Mod+Shift+T` jumps to a random one, `Mod+Ctrl+T` opens a picker (more useful
at this count). That matches the wallpaper keys — `Mod+Shift` is the random
half of both pairs, `Mod+Ctrl` the deliberate half. The theme currently active
is excluded from the draw, so the key always visibly does something; at 29
palettes a plain random pick would land on the current one about one press in
twenty-nine, and a keybind that occasionally appears to do nothing reads as
broken rather than as chance. `theme-cycle` is still on PATH if you want the
ordered walk.

The mechanism is worth knowing, because it's what keeps this declarative.
home-manager owns `~/.config/...` as read-only symlinks into the store, so a
script can't rewrite them. Instead every theme is **built ahead of time** as a
complete set of config files, and the only mutable state is one symlink:

```
~/.local/state/niri-theme/active -> /nix/store/...-niri-theme-matrix
```

Each tool is pointed at a file under that symlink: niri via its `include` node
(live-reloaded), waybar started with `-s <active>/waybar.css`, wofi via its
`style` config key, dunst via `services.dunst.configFile`, swayosd via
`--style <active>/swayosd.css`, kitty via an `include` at the end of
`kitty.conf`. `theme-apply` moves the symlink, restarts waybar, dunst and
swayosd, and sends kitty SIGUSR1 so open terminals repaint in place; wofi
re-reads on each launch.

**Dolphin and other KDE apps** read `~/.config/kdeglobals`, which is a symlink
into the active theme. Two things have to be true for that to work, and the
second is easy to get wrong: `qt.platformTheme.name` must be `"kde"`, not
`"gtk"`. The GTK platform plugin reads colours out of the *GTK* theme and
never opens `kdeglobals` at all, so with it loaded Dolphin comes out in
Adwaita grey whatever palette is selected. With the KDE plugin in place,
`theme-apply` also emits KDE's palette-changed signal on the session bus —
the same one Plasma sends when you apply a colour scheme — so an open Dolphin
repaints without being restarted. That part is best effort; anything that
doesn't listen picks the change up next time it starts.

That `"kde"` costs one thing worth knowing about. home-manager maps the name
to a fixed package list, and it includes **KDE System Settings** — which is
why that app used to appear in the launcher on a session with no Plasma to
configure. `qt.platformTheme.package` is therefore spelled out in
`home/joshr/niri/default.nix`: the module takes the first non-empty of
[your list, the name's list], so naming `kio` and `plasma-integration`
explicitly means the third one is never installed. Both of those are
load-bearing — the KDE file dialog and the plugin that reads `kdeglobals` —
and `QT_QPA_PLATFORMTHEME` is still `kde`. The Plasma hosts are unaffected;
they get System Settings from Plasma itself.

**VS Code** has no "read colours from this path" setting — a colour theme can
only arrive as an extension. So each palette renders a complete one-theme
extension, and `home/joshr/niri/vscode.nix` symlinks the whole directory into
`~/.vscode/extensions`. `workbench.colorTheme` is therefore pinned to `"Niri"`
forever: a switch re-points the symlink at a different build of the same
extension, and the name in `settings.json` — which lives in the store and
can't change at runtime — never has to. Restart the editor to see it.

**Firefox** is the same shape as Dolphin: its profile's `chrome/userChrome.css`
and `userContent.css` are symlinks into the active theme, read once at
startup. See "The browser" below.

Adding a theme is one attrset in `themes.nix` — the niri fragment, both
stylesheets, the dunstrc, the OSD's stylesheet, the swaylock palette, the SDDM
config, Dolphin's kdeglobals, VS Code's extension and Firefox's two chrome
stylesheets are all generated from its ten colour roles.

The OSD's sheet is the one that overrides rather than replaces: swayosd loads
its own at GTK's APPLICATION priority and ours at USER priority, which is
higher, so only the colours and the corner radius are restated and the layout
stays upstream's. It is written against GTK4 node names — `window#osd`,
`#container`, `progressbar > trough > progress` — because swayosd 0.3 is a
GTK4 application, and it spells its `rgba()` channels out rather than using
GTK's `alpha(@theme_bg_color, …)`, which resolves only if the loaded GTK theme
defines that name.

kitty is the exception, because a terminal needs sixteen ANSI colours and ten
semantic roles don't contain them — there's no blue, magenta or cyan in a
palette built for a bar and a focus ring. So each theme also carries an `ansi`
block. Themes with a published terminal palette (Catppuccin, Nord, Gruvbox,
Dracula, Tokyo Night, Rosé Pine, Everforest, Kanagawa, Solarized) use it
verbatim, quirks included — Rosé Pine maps "green" to a teal, Solarized's
bright slots are greys rather than brighter hues. The rest are hand-picked.
Omitting `ansi` is allowed and falls back to a derivation from the ten roles,
but it's flat: blue, magenta and cyan all collapse onto the accent.

One trap worth knowing if you ever edit the greeter's clock: SDDM reads a
theme's config through `QSettings(path, QSettings::IniFormat)`, and QSettings'
INI format treats an **unquoted comma as a list separator**. So a `DateFormat`
of `dddd, MMMM d` comes back as the two-element list `["dddd", "MMMM d"]`,
which `Clock.qml` then hands to `Date.toLocaleDateString(locale, format)` —
a function that takes a string or a format enum and nothing else. The month
silently disappears. The format here uses a middle dot instead of a comma for
that reason; quoting the value also works, but only because the reader happens
to be QSettings.

The login screen does **not** follow, by default. It uses SDDM's built-in
greeter, because the themed one left the primary display black — see "The
login screen" below. `local.sddm.theme = "astronaut"` turns the themed
version back on, which builds one `sddm-astronaut` instance per palette and
has a system path unit rewrite an SDDM drop-in when the selection changes.
SDDM only reads its config when the greeter starts, so that lands at the next
logout or reboot rather than immediately.

Wallpapers use `awww` (the renamed `swww`) over `~/.local/share/wallpapers`:
`Mod+Shift+W` is random, `Mod+Ctrl+W` picks one. The choice is remembered and
restored at login.

**Whose theme the machine follows** is `local.desktop.primaryUser`, which
defaults to `joshr`. Three things live outside any session and have to be
dressed from *someone's* choices: the SDDM greeter and the limine boot menu
both read the theme and wallpaper out of that user's
`~/.local/state/niri-theme`, and plasmalogin copies Plasma's settings out of
their `~/.config`.

Each of those is a singleton — one login screen, one boot menu — so this
can't be generalised to "whoever is logged in" without the last person to
pick a theme deciding what the machine looks like at boot. Naming one owner
is the honest version. Pointing it at an account that never opens a niri
session isn't an error either: the sync services find no state file and leave
the greeter and boot menu on the default palette.

### Keys

| Key | Action |
|---|---|
| `Mod+Return` / `Mod+D` / `Mod+E` / `Mod+B` | terminal, launcher, Dolphin, browser |
| `Mod+Ctrl+E` | ranger, in a terminal |
| `Mod+Ctrl+V` | clipboard history |
| `Mod+.` | emoji picker |
| `Mod+Q` / `Mod+O` | close window, overview |
| `Mod+H/J/K` | focus (arrows also work; `Mod+L` is lock, so use `Mod+Right`) |
| `Mod+1..5` | named workspaces |
| `Mod+R` / `Mod+F` / `Mod+V` | preset widths, maximize, float |
| `Mod+W` | tab the focused column — its windows stack, one shown at a time |
| `Print` / `Mod+Shift+S` | region screenshot, annotated in satty |
| `Shift+Print` / `Mod+Ctrl+S` | same region as last time, no selection step |
| `Ctrl+Print` / `Alt+Print` | screen / window (niri's built-ins) |
| `Mod+L` / `Mod+Shift+Escape` | lock, session menu |
| `Mod+Shift+L` | lock **and** blank the monitors, in one key |
| `Mod+Escape` | blank the monitors — works on the lock screen too |
| `Mod+Shift+I` | stay awake — toggle the idle inhibitor |
| `Mod+Shift+T` / `Mod+Ctrl+T` | random theme, pick theme |
| `Mod+Shift+W` / `Mod+Ctrl+W` | random wallpaper, pick wallpaper |
| volume / brightness keys | change it and show an OSD — see "The on-screen display" |
| `Mod`+scroll / `Mod+Shift`+scroll | walk windows / workspaces (wheel and touchpad) |

`Mod+W` is the one that isn't guessable from the key. A column normally
divides its height between the windows stacked in it, so a column of four is
four short windows. Tabbed, they share one full-height slot and only the
focused one is drawn, with an indicator marking the rest — the column still
takes one slot on the strip, and `Mod+K`/`Mod+J` walk the tabs. `Mod+W` again
puts the stack back. Nothing moves in or out of the column either way; it's
purely how the column is drawn.

`Mod+Shift+Slash` shows niri's own **Important Hotkeys** overlay. That's a
shorter list than the table above: niri hardcodes the entries it considers
important, and anything else appears only if its bind carries a
`hotkey-overlay-title`. `Mod+W` is given one for exactly that reason — the
titled binds land after the hardcoded ones. Scroll binds can't appear there
at all, so `Mod`+scroll stays a table-only entry.

### Clipboard history

`Mod+Ctrl+V` opens the history in wofi; picking an entry puts it back on the
clipboard. `clipboard-wipe` empties it, and isn't bound to a key on purpose.

**Removing single entries**, two ways, because wofi has no way to put a button
on a row:

- **`Delete`** in the picker removes the entry under the cursor and reopens
  it, so several can go in a row.
- **`✕  Delete entries…`**, the first row of the list, switches the picker
  into a mode where Enter — or a mouse click — removes instead of copies.
  `←  Back to copying` returns. This is the discoverable version, and the
  only one reachable with a mouse.

`Backspace` is deliberately not bound. wofi's dmenu mode puts the cursor in a
search box and Backspace is how you correct what you typed there, so binding
it would make the history impossible to search. `Delete` is free, which is
why it's the one. Adding another (`Shift-BackSpace`, say) is one more
`--define=key_custom_1=…` in `clipboard.nix` plus its exit code in the case
at the bottom of the loop.

The bind is passed with wofi's `--define`, not set in `programs.wofi.settings`
— that config is shared with the launcher and the theme, wallpaper and session
menus, and binding `Delete` globally would arm a delete exit code in all of
them. One caveat from wofi(5): a custom key *"will not cause wofi to exit, it
will only set its exit code for when it does"*, so on wofi 1.5.3 `Delete` takes
effect when the picker is next dismissed. Either way it's the entry under the
cursor that goes, and the script handles both behaviours.

Wayland has no clipboard manager in the compositor — a copied selection lives
in the process that copied it and vanishes when that process exits, which is
why closing a browser tab loses what you just copied out of it. `cliphist`
plugs that hole: home-manager runs it as two `wl-paste --watch` user services,
one for text and one for images, and it keeps the last 300 entries.

Images are stored too. They show in the picker as `[[ binary data … ]]`;
choosing one puts the real image back on the clipboard, so pasting into an
image-aware app still works.

`Mod+V` and `Mod+Shift+V` were already float and float/tile focus, hence the
third spelling.

See `home/joshr/niri/clipboard.nix`.

### Emoji picker

`Mod+.`, because that's the key Windows uses and that reflex is the whole
reason it exists. Type to search by name, `Enter` to pick, `Escape` to
cancel — and what you use most floats to the top of the list next time.

The emoji is **typed into the focused window and put on the clipboard**, both.
Typing alone would be the closer copy of Windows, but it depends on the window
accepting synthetic keystrokes, and when one doesn't there'd be nothing to
show for the keypress. The clipboard is the fallback that's already in place
by the time typing is attempted. `cliphist` keeps whatever selection it
displaced, so nothing is lost either way.

It's [`bemoji`](https://github.com/marty-oehme/bemoji) driving wofi, with two
things changed:

- **The list is built at build time**, not downloaded. bemoji normally curls
  `unicode.org/Public/emoji/latest/emoji-test.txt` into `~/.local/share/bemoji`
  on first run. That puts a keybind behind the network, behind a `latest` URL
  that moves, and behind mutable state no rebuild reproduces — so the same
  transformation runs in a derivation instead, against the pinned copy in
  `pkgs.unicode-emoji`, and `BEMOJI_DB_LOCATION` points at the store path.
  Pointing it there also settles the download question permanently: bemoji only
  fetches when that directory comes back empty, and a store path never is. The
  derivation fails the build if the parse yields fewer than a thousand entries,
  so a format change upstream stops the rebuild rather than shipping an empty
  picker.
- **Typing goes through a wrapper** that sleeps 150 ms first. `wtype` starts
  the moment wofi exits, and niri needs a beat to hand focus back to the
  window underneath; without the pause the keystrokes can land while nothing
  is focused yet.

Only the picker's own history at `~/.local/state/bemoji` is mutable. Adding
another list — symbols, kaomoji — means adding a file to the derivation in
`emoji.nix`, not dropping one in a directory.

`Mod+.` used to be `expel-window-from-column`, which moved to
`Mod+Shift+Period`. `Mod+BracketLeft` / `Mod+BracketRight` already consume and
expel, and they're the pair that reads as a direction, so nothing is really
lost.

The picker gets its own stylesheet, `wofi-emoji.css`, generated from the same
palette as `wofi.css` with rows at 20px — big enough to tell 😀 from 😃 at a
glance, with the search box left at the normal size. It follows theme
switches like everything else.

**The font is Microsoft's Fluent Emoji**, which is what makes this look like
the thing `Win+.` opens rather than like Android. nixpkgs has no Fluent Emoji
font — Microsoft publishes `fluentui-emoji` as loose SVG and PNG assets and
the packaging request ([nixpkgs#347889](https://github.com/NixOS/nixpkgs/issues/347889))
was closed as not planned — so `modules/nixos/emoji.nix` packages
[tetunori/fluent-emoji-webfont](https://github.com/tetunori/fluent-emoji-webfont),
a build of those assets into a real font, pinned to its v0.8.5 commit. It's
set as `fonts.fontconfig.defaultFonts.emoji`, so it's what Firefox, kitty,
Discord and everything else draw too, with `noto-fonts-color-emoji` left
behind it to cover anything Unicode has added since the Fluent set was last
built.

It is an 87 MB font, which is most of what this costs. The build carries three
colour formats for the same 33k glyphs — CBDT bitmaps, COLRv1 vectors and
OT-SVG — because it's meant for browsers, where which one gets used depends on
the engine. FreeType needs one of them. It ships whole anyway: stripping tables
means a fonttools pass whose output would have to be trusted sight-unseen, and
a silently broken emoji font is worse than a large one.

See `home/joshr/niri/emoji.nix` and `modules/nixos/emoji.nix`.

On the Plasma hosts the font applies just the same, and `Meta+.` is already
KDE's own emoji picker (`plasma-emojier`). That default is restated explicitly
in `home/joshr/plasma.nix` — the one place that file states a stock KDE
default on purpose — so the same key can't quietly mean different things
depending on which session booted.

### Staying awake

`Mod+Shift+I`, or the coffee-cup icon in the bar, holds the machine awake.
The icon is dim when idling is normal and lit when the inhibitor is on — it's
a mode that's easy to leave running by accident, so it's meant to be obvious.
Clicking and keying run the same script, and the state lives in
`idle-inhibit.service`, so the two can't disagree.

It holds off two unrelated mechanisms, which is why it isn't a one-liner:

- **swayidle** dims, locks and blanks. It takes its cue from the compositor's
  idle-notify protocol, not from logind, so a logind inhibitor does nothing to
  it — the timer is stopped outright and restarted on the way back.
- **logind** handles the idle action, sleep, and the lid switch.
  `systemd-inhibit` holds a block lock on all three for as long as the unit
  runs.

This isn't waybar's built-in `idle_inhibitor` module. That one takes a Wayland
idle-inhibit lock on waybar's own surface — a perfectly good mechanism, but it
can only be toggled by clicking, with no IPC for a keybind to use, and it
wouldn't stop logind suspending the machine.

The inhibitor is per session, and half of what it holds is not. Your own dim,
lock and blank stop, and *the machine* stops sleeping — that half is logind's
and applies to everyone — but another logged-in user's timers keep running in
their own session, where they can lock that session and nothing more. See
[Idle actions stop at the session
boundary](#idle-actions-stop-at-the-session-boundary).

### No automatic sleep on mains power

Separate from the toggle above, and always on: while the machine is plugged
in, it never suspends on an idle timer. `modules/nixos/power.nix`, option
`local.power.noAutoSleepOnAC`, imported by `base.nix` so every host has it.

There is no single "auto-sleep" switch to flip, because automatic suspend can
come from more than one place and they don't know about each other. So this
holds a logind **idle** inhibitor for as long as a mains supply reports
`online`, and anything that asks logind — Plasma's powerdevil included — then
treats the session as busy. `ExecCondition` re-checks the power source each
time the unit starts, and a udev rule restarts it on any `power_supply` event,
so plugging and unplugging just re-evaluate the one condition. That check
follows systemd's own `on_ac_power()` rule — any supply that isn't a battery
and reports `online` non-zero — which is what makes a USB-C-charged laptop
(supply type `USB`, `online` 2) count as plugged in. A machine with no battery
at all counts as permanently on mains, so on the desk and the server the
inhibitor just stays up.

`--what=idle`, not `idle:sleep`, and that distinction is the whole point: a
*sleep* inhibitor blocks every suspend including a deliberate one, so
`systemctl suspend`, the session menu's "Suspend" and the lid switch would
all stop working. An *idle* inhibitor blocks only the timer-driven path.

Locking, dimming and blanking are untouched — those are swayidle under niri
and powerdevil under Plasma, and "don't fall asleep" is not "don't lock the
screen". On battery, nothing changes at all. The Plasma hosts also set
`powerdevil.AC.autoSuspend.action = "nothing"` directly, so the behaviour
doesn't rest on one daemon asking another the right question.

### The lid

Three cases:

| Lid closed… | What happens |
| --- | --- |
| on battery | suspend |
| on mains, nothing else attached | lock the session |
| docked | nothing |

**"Docked" is logind's own definition, and it's broader than a dock**: an ACPI
dock station reporting docked, *or* at least one external display connected.
Shutting a laptop that's driving a monitor is the case that wants nothing to
happen — the session stays up on the external screen rather than locking
behind a lid nobody was looking at.

The order those are tested in is what makes that hold, and it's logind's
rather than ours: docked first, then external power, then the plain case. A
dock supplies power, so the other order would never reach the docked rule and
a docked laptop would lock.

`modules/nixos/laptop.nix` owns the logind half — the three
`services.logind.settings.Login` keys. `HandleLidSwitchExternalPower` is
ignored entirely unless it's set, for backwards compatibility, so leaving it
out doesn't mean "do nothing on mains", it means mains falls through to
`HandleLidSwitch` and suspends. `lock` doesn't suspend: it asks every session
to lock, which under niri is swayidle's `lock` event running `lock-now`,
the same path `loginctl lock-session` takes. On battery the lock still happens
one step later, from swayidle's `before-sleep`, so the machine never resumes
unlocked either way.

`lock` and `suspend` differ in one place, and that's logind's doing rather than
a setting: while the lid stays shut logind keeps re-evaluating which of the
three cases applies, but the lock is only ever sent on the closing edge — a
no-op on those rechecks, or it would re-lock on every wakeup. So pulling the
monitor out of an already-closed laptop suspends it if that leaves it on
battery, and leaves the session as it was if it's still plugged in. Opening
and shutting the lid locks it.

The mains inhibitor from the section above doesn't get in the way, even
though "on mains" is exactly when it's held: `LidSwitchIgnoreInhibited`
defaults to yes, so lid handling ignores the high-level idle and sleep locks.
The low-level `handle-lid-switch` lock is always honoured, which is why
`Mod+Shift+I` still stops the lid doing anything at all.

What happens to the *panel* is niri's business rather than logind's, and it
lines up with the table: with an external monitor connected niri turns the
built-in one off when the lid shuts, so the docked case leaves a working
desktop on the monitor. With no external monitor it leaves the panel on —
disabling the only output would leave the session with nowhere to draw — so
the lock screen sits behind a closed lid until swayidle blanks it on its own
timer.

**Under Plasma, none of those keys fire.** powerdevil takes a block inhibitor
on `handle-lid-switch` at session start ("KDE handles power events") and
handles the lid itself, so the same three cases are restated for it in
`home/joshr/laptop.nix`: `lockScreen` on AC, `sleep` on battery, and
`inhibitLidActionWhenExternalMonitorConnected` for the docked case — powerdevil
has no docked profile, it has a per-profile "don't act when an external
monitor is connected", which is the same rule written from the other side.
The logind half still covers the greeter and a bare TTY there, which is why
both are set. Sleeping locks on the way back either way: that's
`kscreenlocker.lockOnResume` in `home/joshr/plasma.nix`.

It didn't always live in one place per session. `modules/nixos/niri.nix` set
the same three logind keys and disagreed with `laptop.nix`, and two modules
setting one option to different values is a conflict NixOS refuses to merge —
`laptop-niri` imports both, so that host could not evaluate at all. A lid is
hardware rather than a desktop session, which is why `laptop.nix` is where it
lives; `niri.nix` also runs on `gamestation-niri`, which has no lid.

### Coming back from suspend

Two things on the desk don't survive a sleep on their own, and neither is the
session's fault — both are fixed at the system level.

**The NVIDIA card.** By default the driver throws video memory away when the
machine suspends. Nothing warns you: the suspend works, the machine wakes, the
fans spin, and the session never comes back — niri's framebuffers, textures
and every GL/Vulkan context lived in memory the driver no longer has, so it
can't take the GPU back and you get a black screen on a machine that is
otherwise running. SSH answering while the monitors stay dark is the quickest
way to prove that's what happened.

`hardware.nvidia.powerManagement.enable` (`modules/nixos/nvidia.nix`) is the
fix, and it's three things at once: `NVreg_PreserveVideoMemoryAllocations=1`
on the nvidia module, `nvidia-suspend.service` and `nvidia-hibernate.service`
ordered *before* the systemd unit that does the sleeping so the save happens
while there's still a machine to save from, and `nvidia-resume.service`
ordered *after* both to put the memory back. All three are `nvidia-sleep.sh`;
nixpkgs generates the units. After a rebuild:

```bash
systemctl list-unit-files 'nvidia-*'
grep PreserveVideoMemoryAllocations /proc/driver/nvidia/params
```

`powerManagement.kernelSuspendNotifier` is pinned off there, and that line
looks redundant but isn't. The driver has a second mechanism — it hooks the
kernel's own PM notifier chain and does the save and restore itself, no
systemd units involved — and nixpkgs turns that on **by default** for the open
kernel modules on a driver this new. When it's on, none of the three services
are generated, so a rebuild leaves `systemctl list-unit-files 'nvidia-*'` just
as empty as it was and it looks like nothing changed. False keeps the systemd
path, which is the older and far more travelled of the two; deleting the line
is how to try the newer one, and it's worth trying if resume is still
unreliable with the services in place.

The saved video memory goes to a file under `/tmp`
(`NVreg_TemporaryFilePath`), which on this machine is a directory on the root
btrfs subvolume — real disk, which is what it needs to be. If `boot.tmp.useTmpfs`
is ever switched on here, point that parameter somewhere on disk in the same
breath, or the "save" becomes a copy from RAM to RAM: double the memory for a
suspend, and hibernation stops working entirely.

```nix
hardware.nvidia.moduleParams.nvidia.NVreg_TemporaryFilePath = "/var/tmp";
```

**The RGB lighting.** Suspend cuts power to the controllers, and they only
hold what was last written to them — USB ones are re-enumerated on the way
back up and the ones on the board return to their firmware default, which is
usually the rainbow. Nothing re-applies the profile, so the lighting is right
until the first suspend and wrong from then until the next login.
`modules/nixos/openrgb.nix` adds `openrgb-resume.service`, which re-applies
`local.openrgb.profile` after every sleep (`local.openrgb.applyOnResume` to
turn it off).

It runs as `local.desktop.primaryUser` rather than root, because profiles are
runtime state living in that account's `~/.config/OpenRGB` — root would find
nothing there and say so. It waits five seconds first, because systemd calls
the resume finished as soon as the kernel is back, which is well before USB
has re-enumerated; a run started at that instant simply doesn't see the
keyboard yet.

The unit is shaped the way `systemd.special(7)` recommends for "run something
on resume", and the way nixpkgs' own `powerManagement.resumeCommands` is: it's
`WantedBy` and `Before` `sleep.target` — one target that covers suspend,
hibernate, hybrid-sleep and suspend-then-hibernate — with the work in
`ExecStop`, since systemd stops units in the reverse of the order it started
them and "after `sleep.target` stops" is another way of saying "after the
machine wakes up". So `systemctl status openrgb-resume` reads `active
(exited)` whenever the machine is awake: that's the unit armed, not the unit
run. What it did last time is in the journal.

```bash
journalctl -u openrgb-resume -b
```

### Displays

One file per host under `home/joshr/displays/`, kept separate so a monitor
change doesn't mean editing the session config. Empty means niri
auto-detects, which is what the laptop does.

```nix
# home/joshr/displays/gamestation.nix
local.niri.outputs = [
  { name = "DP-3"; mode = "2560x1440@180.000";
    position = { x = 0;    y = 0; }; focusAtStartup = true; }
  { name = "DP-2"; mode = "1920x1080@100.000";
    position = { x = 2560; y = 0; }; }
];
```

Get connector names and the modes each display actually reports with:

```bash
niri msg outputs
```

Three things worth knowing:

- **State the refresh rate.** A display's *preferred* mode is often not its
  fastest, so omitting it can silently leave a 180Hz panel at 60. The string
  has to match a mode the display reports or niri falls back and warns.
- **Positions are logical pixels**, so a scaled display occupies
  `width / scale`. Lay the next one out from there, not from its physical
  width. Above, DP-2 starts at x=2560 because DP-3 is unscaled.
- **niri has no "primary" display.** `focusAtStartup` decides where the
  session begins. To pin workspaces to a display, give them an
  `open-on-output` in the `workspace` declarations in `niri.nix`.

Also available per output: `scale`, `transform` (rotation),
`variableRefreshRate`, and `off`.

**The greeter does not follow the display config, deliberately.** Several
attempts to make it do so are gone; see "The login screen" below for why. The
greeter auto-detects, which lights up every connected display at kwin's choice
of mode and arrangement.


**Workspaces follow a display** via `local.niri.workspaceOutput` in the same
file. niri creates a workspace on whichever output is focused at the time, so
without it the numbered workspaces scatter across displays depending on where
you were when you first used each one. The desk pins them to `DP-3`.

### Brightness

The brightness keys worked on the laptop and did nothing on the desk for a
while, with the same package installed and the same binding on both. The
difference is hardware, not config.

`/sys/class/backlight` only ever contains **internal** panels — a display
whose backlight PWM the GPU driver owns. A monitor on DisplayPort or HDMI
never appears there, because its backlight is inside the monitor. So on a
desktop that directory is empty, and everything pointed at it silently does
nothing: the keys, and the pre-lock dim in `lock.nix` as well.

An external monitor is reached over **DDC/CI** instead, a small command set it
answers on the i2c bus alongside the video link. `modules/nixos/ddcci.nix`
loads `ddcci-backlight`, which speaks that in the kernel and registers each
monitor as an ordinary backlight device — so the existing keys and timers work
unchanged rather than needing a second code path.

```nix
# hosts/gamestation-niri/configuration.nix
local.backlight.ddcci.enable = true;
```

It needs a **reboot**, not just a switch — it's a kernel module. Then:

```bash
ls /sys/class/backlight/    # expect a ddcci* per monitor
ddcutil detect              # what DDC/CI itself can see
```

If a monitor is missing, check DDC/CI is enabled in its OSD — some vendors
ship it off, and call it "MCCS". If it's still missing, compare the adapter
names against `local.backlight.ddcci.busNameMatch`:

```bash
cat /sys/bus/i2c/devices/i2c-*/name
```

Buses are matched by name rather than probed blindly on purpose: most i2c
buses on a desktop are SMBus segments carrying RAM and RGB hardware, not
displays, and this machine already runs `acpi_enforce_resources=lax` so
OpenRGB can reach some of them.

Two things worth knowing:

- **DDC/CI is slow** — a write is a round trip on the order of 100ms per
  display, where a laptop panel is instant. The `brightness` helper
  (`scripts.nix`) drops overlapping presses rather than queueing them, so a
  held key doesn't keep climbing after you let go.
- **The keys drive every display**, which is why they call that helper and
  not `brightnessctl` directly. `brightnessctl` with no `--device` adjusts
  the *first* device it finds — invisible with one internal panel, wrong
  with one device per monitor. The bar's brightness module scrolls through
  the same helper for the same reason, so the keys and the scroll can't
  drift apart. See "The bar".

The OSD that comes up with the keys reports the *first* device's level, read
back after the write. On the laptop that is the only device there is, and on
the desk every display has just taken the same step — but they can still drift
apart, if a monitor refuses a write or gets adjusted from its own buttons, and
what you get then is one display's real level rather than an average of two
that belongs to neither. See "The on-screen display".

Not enabled on the Plasma variant of the desk. It would work, but it would
also hand powerdevil's idle timer real dimming on displays it currently can't
touch.

### The login screen

**SDDM uses its own built-in greeter**, not a theme of ours. That is
`local.sddm.theme = "stock"`, and it is the default after the themed one left
the primary display black.

The evidence for blaming the theme is that the failure did not move. It was
identical under kwin_wayland, under weston and under X11, and SDDM logged no
error at any point in the process:

```
sddm[1734]: Greeter starting...
sddm-helper[1766]: [PAM] Starting... / Authenticating... / returning.
sddm[1734]: Greeter session started successfully
sddm[1734]: Message received from greeter: Connect
```

The greeter started, authenticated and connected. Three different display
servers failing the same way, with the stack reporting success, points away
from all three and at the one component they share.

Things ruled out along the way, so they are not tried again:

- **A generated `kwinoutputconfig.json`** from `local.niri.outputs`. Removed.
  Writing a mode can black-screen a display outright, because kwin hands it
  straight to a modeset and a rate that doesn't match exactly — DRM reporting
  179998 mHz where the config says 180000 — simply fails. Dropping the mode
  didn't help either: with no config, kwin still picks the preferred mode,
  which for a 1440p180 panel is 180Hz.
- **Copying KWin's own file** from the Plasma session. That dragged a whole
  arrangement across including its enabled/disabled state.
- **The greeter's compositor.** weston made no difference, and neither did
  X11.

The stock greeter confirmed the diagnosis: it comes up fine on both displays,
so the theme was indeed the thing at fault.

**`local.sddm.theme = "astronaut"`** brings the themed greeter back — one
`sddm-astronaut` build per palette, following the desktop's theme and
wallpaper — with the leading suspect now fixed.

That suspect is the background. The theme config points `Background` at a
fixed runtime path, `/var/lib/sddm-theme/wallpaper.png`, and that file only
appears once the wallpaper switcher has run. Before a wallpaper has ever been
picked, it isn't there. sddm-astronaut then feeds a missing image into a blur
shader — `PartialBlur` is on — and a QML scene graph that fails while building
an effect chain renders *nothing*, rather than falling back to
`BackgroundColor`. That matches every symptom: no error from SDDM, which had
already logged the greeter as started and connected, and identical behaviour
on every display server, because none of them were involved.

The fix is that the sync service now guarantees the file exists, seeding a
solid image in the palette's background colour when there's no wallpaper to
convert. A few KB per palette.

This is unproven — the greeter's own QML warnings were never captured — but it
was the only path in the theme referencing a file that might not exist. If the
themed greeter is still black, go back to `"stock"` and the next thing to
strip is the per-palette directory rename.

One thing that has to happen on the way to stock: the sync service deletes
`/etc/sddm.conf.d/99-niri-active-theme.conf`. That drop-in names a
`niri-<palette>` theme package, it lives in `/etc` where NixOS only removes
what it declares, and left behind it would point SDDM at a theme directory
that is no longer in the store. The service is ordered before
`display-manager.service` so this lands before the greeter reads it, rather
than one boot late.

**The greeter's cursor** comes from `settings.Theme.CursorTheme`. SDDM ships
no cursor of its own — it exports `XCURSOR_THEME`/`XCURSOR_SIZE` into the
greeter, which looks the name up on the *system* icon path. Without them the
greeter inherits whatever the compositor defaults to, which on a bare login
screen is often nothing, and the pointer is invisible.

It's set to `Bibata-Modern-Ice` at size 24, matching `home.pointerCursor` in
`home/joshr/home.nix` so the pointer doesn't change shape at login. The two
have to be stated separately: the greeter runs as the `sddm` user before
anyone has logged in and cannot see home-manager's config. `bibata-cursors` is
in `environment.systemPackages` (`modules/nixos/base.nix`), which is what puts
it on the system icon path — a cursor theme only in the user profile would not
be found.

If the login screen is ever black again, a TTY still works (`Ctrl+Alt+F2`), as
does booting the previous generation.


### Screenshots

Region capture goes `slurp` → `grim` → `satty`, so you land in an annotation
editor (arrows, boxes, blur, text) and it copies to the clipboard on save.
Plain screen and window capture use niri's built-in `screenshot-screen` and
`screenshot-window` actions instead — the compositor already knows the exact
geometry, so there's nothing for a script to compute wrong.

**`Shift+Print` (or `Mod+Ctrl+S`) re-shoots the last region** with no selection
step. Every region capture writes its geometry to
`~/.local/state/niri-screenshot/region`, and that mode reads it straight back.
It's for shooting the same frame repeatedly — a panel, a window, a chart being
tweaked — where redrawing the box by hand is both the tedious part and the
reason successive shots don't line up.

It falls back to a normal selection if there's no remembered region yet, or if
the region no longer captures — a monitor unplugged or the layout rearranged
under it. The geometry is only remembered once `grim` has accepted it, so a
region that can't be captured never becomes the one it comes back to.

Note that this is a separate keybind rather than "reopen slurp with last time's
box ready to adjust", because slurp can't pre-fill a selection. Its `-r` reads
boxes on stdin and *restricts* selection to them, so handing it the saved region
would let you click that box to accept it but never drag its edges — a worse
version of the same thing, with an extra click.

### Lock screen

Hyprlock, with a clock, a greeting, one wide password field and — when
something is playing — the album cover, blurred across the whole screen and
again as a small card above the track name. Nothing playing puts the current
wallpaper back. Colours come from the active theme, so it follows a theme
switch. `swaylock-effects` is still installed and is the fallback the lock
script drops to if Hyprlock fails to start — a locker regression must not
leave the session sitting unlocked.

`swayidle` dims at 4 minutes, locks at 5, blanks at 10, and locks before
suspend.

#### The background is the album cover

One cover becomes two pictures. `lock-album-art-fetch` renders a 2560x1440
backdrop — the sleeve blown up to fill the screen and blurred to a wash of its
own colours, which is what the lock screen uses in place of the wallpaper —
and a 200px card with soft corners, a hairline edge and a shadow, which sits
above the track name. Both are keyed by the cover's URL and cached under
`~/.cache/niri/album-art`, thirty of each, so locking twice during the same
song does no work at all.

Hyprlock asks for both every three seconds through `reload_cmd`, which is what
makes the lock screen follow the music while it sits there locked: skip a
track and the card changes and the background crossfades behind it; stop the
music and it fades back to the wallpaper.

**`lock-album-art` — the command Hyprlock actually runs — never fetches and
never renders.** That is the constraint the whole design is built around.
Hyprlock runs a `reload_cmd` through `spawnSync` from a timer callback on its
main thread, so a cover downloaded inline would freeze the clock and the
password field for as long as curl felt like taking. `lock-album-art` answers
out of the cache, and when a track has no render yet it hands the URL to
`lock-album-art-fetch` in a detached process and answers with what is true
right now instead. The cost is that the first lock during a never-seen track
comes up on the wallpaper and crossfades into the cover a beat later, which is
the right way round for that trade.

Two of the details are downstream of one Hyprlock behaviour: an empty answer
from a `reload_cmd` means *keep what you have*, not *show nothing*. That is
what you want while a cover is still rendering — the previous one stays up
rather than blinking through a gap — and it means "the music stopped" has to
be said with a picture. So there is a transparent PNG in the store for the
card to point at, and the corners, edge and shadow are baked into the rendered
image rather than left to Hyprlock's `rounding` and `border_size`, because a
Hyprlock border would draw a neat empty box around the transparent one.

The backdrop is also exposed rather than simply copied. Hyprlock's own
`brightness` is a fixed multiplier set for the wallpapers, which are chosen
and mostly dark; album covers are neither, and a sleeve that is mostly white
leaves every label on the screen sitting on a pale wash. So each cover is
dimmed *to* a target lightness instead of by a constant — never brightened,
and never dimmed by more than two thirds, which is the point past which a
cover stops being visible at all rather than merely dim.

The cover is fetched with the same care as anything else that comes off the
network. Only `http`, `https` and `file` URLs are followed, `--proto-redir`
keeps a redirect from walking into `file://` and handing a local file of its
choosing to ImageMagick, the download is bounded on size and time, and what
arrives has to *be* an image by its magic bytes — the MPRIS metadata was a
claim, not a check. A per-track `flock` keeps two renders of the same cover
from racing, and both files are renamed into place only once they are whole,
so a reload can never catch a half-written JPEG.

Which player all of this is about is decided once, in a shell fragment shared
with the now-playing label: a player that is actually playing, or else the
first paused one. Sharing it is not tidiness — the cover and the title are
resolved separately, and two copies of that loop would eventually put one
track's sleeve under another track's name. Every `playerctl` call in it is
wrapped in `timeout 1`, because these are D-Bus calls into other applications
and a wedged one (a hung browser tab, usually) blocks its caller for D-Bus's
own 25-second default. Two of the three callers cannot afford that: one runs
on Hyprlock's main thread, and one runs on the path that has to have the
screen locked before the machine suspends.

#### And the colours come off the cover too

The password field's outline, the clock, the greeting, the track name and the
session controls all take their colour from the sleeve, so the whole screen
belongs to the record rather than to the picture alone.

The cover decides exactly one thing: a hue. Everything else is fixed in
`home/joshr/niri/album-palette.awk`, which reads the same twelve-colour
histogram the exposure comes from, takes the hue of the colour the sleeve is
*mostly* made of — skipping greys, and skipping anything so dark or so light
that the eye reads it as black or white regardless of what its saturation
claims — and rebuilds the theme's five lock-screen colours at that hue with
fixed lightnesses and a bounded amount of the cover's own saturation. A neon
sleeve and a washed-out one land in the same place, which is the point: this
is a screen that has to stay readable over a picture nobody chose.

`LOCK_ERR` and `LOCK_WARN` keep the theme's values. An error is red and a
caps-lock warning is yellow whatever is playing.

A cover with no colour confident enough to build on — a black-and-white
photograph, a plain white sleeve — produces no palette at all, and the lock
screen keeps the theme's own colours. Only the exposure comes out of that
pass, which every cover needs.

**The colours are fixed for the life of the lock screen**, even though the
pictures behind them are not. Hyprlock can be told to re-read a *path* while
it is up — `reload_cmd` is exactly that, and it is how the background and the
card follow the music — but there is no equivalent for a colour anywhere in
its config. A label's colour could be smuggled in through markup; the password
field's cannot, and that was half the point. Recolouring only the half that
could be recoloured would leave the screen in two albums' colours at once,
which is worse than a screen that wears the track it was locked on.

The palette file is read rather than sourced, one known key at a time and only
when the value is six hex digits. It is our own file and holds nothing else,
but it lives in a cache directory rather than in the store, and `lock-session`
is the script standing between a locked session and the desktop.

#### Everything locks through `lock-now`

`lock-session` is the script that actually draws the lock screen, and it
blocks until you unlock. Nothing calls it directly. The keybinds, the bar's
lock button, the session menu, switch-user and swayidle all go through
`lock-now`, which starts it, waits until it is up, and returns — a few hundred
milliseconds rather than however long you are away.

That indirection is not tidiness — it is the fix for the idle timer stopping
dead at the moment it locked. home-manager runs swayidle with `-w`
(`services.swayidle.extraArgs` defaults to it), and with `-w` swayidle's
`cmd_exec` forks the command **once** and then `waitpid()`s it from inside its
own Wayland event loop, instead of double-forking and returning. A timeout
pointed straight at `lock-session` therefore froze every later timer for as
long as the screen was locked: the 10-minute blank never fired, so the display
stayed lit behind the lock screen indefinitely. `before-sleep` and the `lock`
event — the lid closing on mains, `loginctl lock-session` — wedged the timer
the same way.

Dropping `-w` would have been the wrong fix. It is what makes swayidle hold
logind's sleep delay lock until `before-sleep` has returned, which is the
guarantee that the machine never suspends before the locker is on screen. So
the command has to return quickly *and* not until the lock is really up, which
is what `lock-now` does.

`lock-now` is also idempotent, which is why every route can share it.
`lock-session` holds an `flock` on a file under `$XDG_RUNTIME_DIR` for as long
as it lives — an open descriptor rather than a PID file, so the kernel drops
it however the process dies and there is no stale state to clean up — and a
second lock request sees the lock held and returns success instead of starting
a second locker on top of the first. That matters beyond tidiness, because
`lock-session` falls back to swaylock when Hyprlock exits non-zero: without the
guard, a duplicate lock request started a second Hyprlock, which cannot take an
already-held session lock and exits non-zero, and the fallback then layered a
swaylock over the perfectly good lock screen already on screen.

The one thing `lock-now` cannot do is wait for a *rendered* lock screen. The
file lock proves `lock-session` is running, which is a fraction of a second
ahead of Hyprlock claiming the session lock and drawing, and there is no
readiness signal to wait on instead — Hyprlock has no IPC, and a Wayland
session lock is not visible to logind. So it ends on a 300 ms settle, which is
an honest guess, generous for what it covers, and only matters to the two
callers that touch the screen immediately afterwards: `lock-blank` powering the
monitors off and `switch-user` handing the seat to the greeter.

#### Only the idle lock has a grace period

A grace period is a window, counted from the moment the lock screen appears,
during which any input dismisses it with no password. Hyprlock and swaylock
both take one as `--grace`, and `lock-session` passes its own `--grace` through
to whichever it ends up running.

`lock-session` defaults to `--grace 0`, so every route to the lock demands a
password immediately: `Mod+L`, `Mod+Shift+L`, the bar's lock button, the
session menu, `switch-user`, `before-sleep`, and the `lock` event that
`loginctl lock-session` triggers. All of those are locks somebody asked for,
and on those a grace window is a hole rather than a convenience — waking the
screen to confirm that it actually locked is itself input, so the check that
you locked would unlock it.

The 5-minute idle timeout in `lock.nix` is the single exception, and it passes
`--grace 2`. Nobody asked for that lock; it fired on its own while you were
away, and the case worth covering is the timer going off just as you sit back
down. Two seconds covers that and nothing longer. It is also the one lock
where the grace window costs nothing you had: the machine was already sitting
unlocked and unattended for the five minutes leading up to it.

Note that `before-sleep` deliberately sits on the strict side of that line even
though a suspend can itself be idle-triggered. Resuming from suspend is exactly
the moment a free keypress would get spent, and the lid closing is usually a
deliberate act.

The lock script passes `--color` as well as `--screenshots`, and that is
load-bearing rather than decorative. `--color` is the flat colour swaylock
paints underneath the screenshot, so it is what you see when there is no
screenshot to draw over it — and its default is **white**. Locking with a
monitor already blanked is exactly that case: `--screenshots` grabs each
output through wlr-screencopy, and a capture of a powered-off output fails.
The packaged fork then clears the screenshot flag on its shared state instead
of on the surface that failed, so one blanked monitor drops the screenshot
background on *every* display and the whole lock screen comes up white.
Pointing `--color` at the theme background makes that fallback a themed solid
colour. It is easy to hit because blanking and locking are independent —
`Mod+Escape` blanks on demand, `Mod+Shift+L` does both at once, and swayidle
blanks at 600s and locks before sleep.

niri's `layout { background-color }` does not help here: that is the backdrop
behind windows, and swaylock's own surface covers it.

**swaylock is patched** (`home/joshr/niri/swaylock-date-fit.patch`) so the date
stacks onto two lines — weekday over month and day — and can't overhang the
ring.

Upstream draws the date as one row sized at a hardcoded `arc_radius / 6`, so it
grows in exact proportion to the circle: a long date like "Wednesday, September
24" hangs over by the same fraction at *every* radius, and widening
`--indicator-radius` buys nothing. No flag reaches it either — `--font-size`
sets the clock above it, and the date's divisor isn't exposed. Without the patch
the only fixes available in configuration are to shorten the date or narrow the
font, and the installed fonts are FiraCode and Poppins with nothing condensed.

The patch splits `--datestr` on a newline (strftime `%n`, hence
`--datestr "%A%n%B %d"`) and stacks the halves. Two short lines fit at full size
where one long one didn't: at radius 130 "Wednesday" and "September 24" measure
117px and 156px against chords of 246px and 231px, where the single row was
299px against 240px. It also scales a line down if it still wouldn't fit,
bounded by the ring's inner chord at that line's own baseline rather than the
diameter — with stacking that never triggers here, it's the backstop that makes
an overhang impossible for any format or locale.

It costs a source build of swaylock-effects, which is a small C project and
quick. If a nixpkgs bump moves those lines the patch will fail to apply — the
fallback is a one-line `--datestr` short enough to fit.

**`Mod+Escape` blanks the monitors on demand**, from the lock screen as well
as from the desktop — for when you're walking away now and don't want to wait
out the idle timer. Any input wakes them; on the lock screen that leaves
swaylock exactly where it was, so it's a screen-off, not an unlock.

It works through the lock without an `allow-when-locked` on it because niri
keeps a whitelist of actions that survive the lock screen —
`power-off-monitors` is on it, which is the same reason the 10-minute blank
above fires while locked. That check lives in `do_action`, so it covers
`niri msg action power-off-monitors` over IPC as well as the keybind, which is
how swayidle's blank reaches it. Setting that property here would actually be
a config *error*: niri only accepts it on `spawn` binds.

**`Mod+Shift+L` locks and blanks together**, which is the "I'm walking away"
version of pressing `Mod+L` and then `Mod+Escape`. Like `Mod+L`, it locks with
no grace period at all — see [Only the idle lock has a grace
period](#only-the-idle-lock-has-a-grace-period).

It's `Mod+Escape` and not bare `Escape` because niri intercepts a bound key
unconditionally — it matches binds before it looks at the lock state, and
only then drops the action if the session is locked. A bare `Escape` bind
would therefore swallow Escape in every application all the time, and there
is no "only while locked" flag to scope it with.

The system module adds `security.pam.services.swaylock` — without that PAM
entry swaylock accepts your password and then rejects it, which locks you out
of your own session.

#### Idle actions stop at the session boundary

More than one person can be logged in at once. `switch-user` hands the seat to
the greeter and deliberately leaves the session it came from running, so every
account that has logged in since boot still has a niri, a swayidle and a full
set of idle timers of its own, ticking.

niri does not stop that clock for a session that has been switched away from.
Pausing a session suspends its libinput and DRM devices and nothing else, so
the compositor simply stops seeing input, concludes after four minutes that you
are idle, and runs the timers in `lock.nix` in a session nobody is looking at.
Locking there is correct — nobody is sitting in front of it. Dimming and
blanking are not, because neither one stays inside the session that asked for
it: the dim is a DDC/CI write to the monitor itself
([`modules/nixos/ddcci.nix`](modules/nixos/ddcci.nix)), which is one piece of
hardware shared by the whole seat. The symptom is the screen going dark on
whoever is actually using the machine, four minutes after they sat down, driven
by the timers of somebody who walked away an hour ago.

So the timers that touch the screen run through `when-active`, and the one that
touches only its own session does not:

| timeout | action | gated |
| --- | --- | --- |
| 240s | dim to 20%, restore on activity | yes |
| 300s | lock | **no** — it locks its own session and reaches nothing else |
| 600s | blank the outputs | yes |

`when-active` asks logind whether this session is the one on the screen —
`loginctl show-session auto --property=Active` — and runs the command only if
it is. `auto` is how swayidle itself finds the session it listens to for Lock
and Unlock: logind resolves it as the caller's own session and falls back to
the user's display session, and that fallback is what makes the question
answerable from a `systemd --user` service, where there is no
`XDG_SESSION_ID` and the unit's cgroup sits outside every login session.

A question that can't be answered runs the command anyway. A session on no seat
at all — a VM, a headless box — reports itself active, and a machine with no
logind to ask is one with nobody else to interrupt.

The blank is gated for a second reason on top of that one: a paused niri has
handed its DRM devices back and cannot power an output off while it is in the
background, so all an ungated blank could do is queue the monitors up to come
back dark on the way in.

One consequence worth knowing: while the greeter is on screen with no session
behind it, nothing dims or blanks the monitors, because there is no active
session to do it. That screen belongs to SDDM at that point, not to us.

#### Coming back through the greeter only asks once

`switch-user` locks the session and hands the seat to SDDM. Logging back in as
yourself used to cost two passwords: one at the greeter, and one at the lock
screen still standing in the session you left.

It now costs one. SDDM looks for a session of its own for that user in state
`online` — exactly what `switch-user` leaves behind — and answers a successful
authentication with logind's `UnlockSession` followed by `ActivateSession`,
instead of starting a second session beside the first. That is
`Users.ReuseSession`, set explicitly in
[`modules/nixos/niri.nix`](modules/nixos/niri.nix): it is SDDM's own default,
but this configuration now depends on the behaviour rather than inheriting it.
swayidle turns the `Unlock` half into `unlock-session`, which sends hyprlock
`SIGUSR1`.

Three things make that a shortcut rather than a hole in the lock:

- logind accepts `Unlock` only from the session's own user or from root — the
  polkit check names the session owner as the user who may skip it. So the
  senders are code already running as you, and SDDM's daemon, which sends it
  having just put you through PAM.
- `SIGUSR1` is hyprlock's own unlock path (`enqueueUnlock`), the same one a
  correct password takes, so the Wayland session lock is released properly.
  Killing the locker would not unlock anything: under `ext-session-lock`, a
  locker that dies without releasing the lock leaves the compositor locked with
  nothing left to type into. That is the protocol working as designed.
- Nothing else here sends `Unlock`. `loginctl unlock-session` by hand does the
  same thing, which is rather the point of hanging this off logind's signal
  instead of inventing a private one.

The swaylock fallback has no unlock signal, so a session that came up on it —
which only happens when hyprlock failed to start — still asks for the password
at the lock screen. That is the right direction for a fallback to fail in.

The listener is swayidle, so it is also gone while the idle inhibitor is on:
that stops swayidle outright (see [Staying awake](#staying-awake)), and
switching away and back with `Mod+Shift+I` held on asks for the password again.
Old behaviour rather than a new failure, and not worth a second long-running
D-Bus listener to close.

Without `ReuseSession` the second login would start a *new* session instead:
two niris, two swayidles and two of everything the session launches, for one
person, with the first one still locked behind them.

### RGB lighting

`modules/nixos/openrgb.nix`, imported by `gaming.nix`, so it lands on the two
`gamestation` hosts and not the laptop. It runs the OpenRGB daemon, the niri
session starts the tray applet at login, and both apply one profile:

```nix
local.openrgb.profile = "Main";   # ~/.config/OpenRGB/Main.orp
```

That name is a filename and is case-sensitive — `Main` and `main` are two
different profiles. Profiles are made from OpenRGB's own UI ("Save Profile")
and are runtime state, not something this repo writes, so naming one that
doesn't exist yet is harmless: the applet says "Profile failed to load" and
carries on, and the resume service checks for the file and does nothing.

The applet is launched with `--startminimized`, which is load-bearing twice
over: OpenRGB drops to CLI mode and *exits* as soon as it's given any option,
so `--profile` on its own would set the lighting and quit with no tray icon.
`--startminimized` implies `--gui` and keeps the window out of the way. (The
resume service is the case that *wants* that CLI behaviour, and gets it by
leaving the flag out.)

Each argument is its own string in the config —
`spawn-at-startup "…/openrgb" "--startminimized" "--profile" "Main"`. This is
the one thing to get right here: `spawn-at-startup` is not a shell, niri execs
the first string and hands it the rest, so the whole command line packed into
one string is a program name with spaces in it. It fails with `ENOENT`,
quietly, into niri's log — which is exactly what it did for a while, and why
the lighting was only ever whatever the last thing to touch it had left.

`local.openrgb.autostart` decides whether the applet starts at all, and
defaults to whether the daemon is enabled: on at the desk, off on the laptop,
where it would cost a tray icon, a Qt process and a failed profile load every
session for nothing to talk to. The laptop has no `openrgb` on PATH either —
the package comes with the daemon's module — so on that host it's
`nix run nixpkgs#openrgb` for a one-off, or importing `gaming.nix` to have it
properly.

#### Two applets at login

Counting two `openrgb` processes is normal. One is the daemon —
`openrgb --server`, running as root since boot — and the other is the tray
applet in your session. The applet does not fight the daemon for the
hardware: given a server already listening on localhost it connects to it as
a client rather than detecting anything itself, which is what
`--noautoconnect` exists to switch off.

Two *tray icons* is the bug, and it is almost always OpenRGB's own "Start At
Login" checkbox (Settings → General). That writes
`~/.config/autostart/OpenRGB.desktop`, and niri's session runs XDG autostart
entries — `niri.service` pulls in `xdg-desktop-autostart.target` — so the
applet starts once from `niri/config.kdl` and once from that entry. OpenRGB
has no singleton lock and will happily run both; the first to finish
detection takes the hardware and the second comes up with an empty device
list, so the giveaway is one tray icon that controls nothing rather than
lighting that flickers.

That box is easy to have ticked, because it is the only way to autostart the
applet in the Plasma session on the same machine and the same `$HOME`, and it
was the only thing that worked in the niri session too for as long as
`spawn-at-startup` was packed into a single string and failing with `ENOENT`.
Repairing the spawn is what turned one applet into two.

`home/joshr/niri/niri.nix` now masks the entry with a `Hidden=true` stub — the
same treatment `niri/default.nix` gives blueman — gated on
`local.openrgb.autostart`, so it only claims the file where the repo is what
starts the applet. Plasma and the laptop are left alone. The side effect is
that OpenRGB's checkbox reads "on" forever, since it only asks whether the
file exists; unticking it deletes the stub and the next home-manager
activation writes it back.

To confirm which of the two you have before changing anything:

```bash
ls -l ~/.config/autostart/OpenRGB.desktop   # the duplicate, if it exists
pgrep -af openrgb                           # daemon + applet is expected
```

The lighting does not survive a suspend on its own; see "Coming back from
suspend" above for the service that puts it back.

## Wallpapers

`~/.local/share/wallpapers` has two halves. The collection out of the
dotfiles repo is the permanent one. Beside it, `WallhavenFlake/` holds
[wallhaven.cc](https://wallhaven.cc)'s current top 20 — and only those
twenty, so as the toplist moves on, the folder moves with it.

Both desktops pick the new files up for free: niri's `Mod+Ctrl+W` picker globs
the whole tree, and Plasma's slideshow is pointed at the same directory.

### Which twenty, and who decides

A flake input:

```nix
wallhaven-toplist = {
  url = "file+https://wallhaven.cc/api/v1/search?categories=111&purity=100&sorting=toplist&topRange=1M&order=desc&atleast=1920x1080&ratios=16x9%2C16x10";
  flake = false;
};
```

That's the API's JSON search response — the **list**, not the images. Nix
fetches and hashes it like any other input, which is the whole point of doing
it this way: the twenty are pinned in `flake.lock`, the desk and the laptop
show the same twenty, and they change when you run `nix flake update` rather
than whenever wallhaven's front page does.

```bash
nix flake update --refresh wallhaven-toplist
```

`--refresh` because Nix caches fetched files for an hour and will otherwise
hand back the copy it already has. That's for re-locking the *same* URL —
editing the query is a different input entirely, and the next evaluation
re-locks it on its own. Commit the resulting `flake.lock` alongside the edit.
`file+https` rather than plain `https` because the plain form is the *tarball*
fetcher, which would try to unpack a JSON document.

The query is the website's Toplist view: all three categories (`111`), SFW
only (`100`), ranked over the last month, nothing below 1080p, and — via
`ratios` — widescreen only. Edit it and re-lock to change what "top 20"
means: drop `atleast` for the unfiltered list, `topRange=1d` for today's.
How many to keep is separate, and is `local.wallhaven.count` (1–24, the size
of one API page).

**`ratios=16x9,16x10`** is the widescreen filter. Both displays on the desk
are 16:9 — 2560x1440 and 1920x1080 — so 16:10 is the widest miss worth
taking, losing a sliver off the top and bottom when it scales. Anything
squarer arrives pillarboxed or cropped hard by whichever of awww or Plasma is
drawing it. The laptop panel isn't pinned in this repo at all
(`home/joshr/displays/laptop.nix` is deliberately empty), so it isn't what
the filter is measured against — `16x10` covers it if it happens to be one.

Two things about that parameter are easy to get wrong. It takes a
comma-separated list, but wallhaven's `landscape` supergroup is *not* the
same request — that's every non-portrait ratio it knows, `4x3` and `5x4`
included, which means "not portrait" rather than "wide". And the ultrawide
ratios (`21x9`, `32x9`) are left out deliberately: there's no display here to
put them on, and on a 16:9 panel they letterbox to a strip.

The comma is written `%2C` in `flake.nix`. Nix parses the query into
parameters rather than passing the URL through verbatim — you can see it
re-emit them alphabetically in `flake.lock` — so encoding the separator keeps
it unambiguously part of the value. wallhaven decodes it back on receipt.

A narrower query is drawn from a smaller pool, so a month with an unusually
vertical toplist can return fewer than `local.wallhaven.count` images.
Nothing breaks — the sync script takes what's there — the folder is just
occasionally short.

### Why the images aren't in the store

A flake input is one URL locked by one hash. The twenty image URLs aren't
known until that JSON has been fetched and read, by which point evaluation is
already under way — and wallhaven publishes no checksum for the files
anywhere in its API, so there is nothing for `pkgs.fetchurl` to verify even
if the URLs were known in time.

So the list is declarative and the files are not. `home/joshr/wallhaven.nix`
builds a `wallhaven-sync` script around the locked JSON; home-manager runs it
at activation and again at login (`wallhaven-wallpapers.service`), and you can
run it by hand. It downloads what the list names, deletes everything it
doesn't, and is careful in the two ways that matter:

- **It won't prune after a failed download.** Deleting yesterday's twenty
  because the network dropped halfway through would leave the picker emptier
  than it started. A run with any failure keeps everything and exits non-zero;
  the next one finishes the job.
- **It checks the JSON is a search response before believing it.** `nix flake
  update` will pin an error page as happily as a result set, and an error page
  parses as "zero wallpapers".

Files are named for wallhaven's id, so a wallpaper that merely slides from 3rd
to 5th place isn't downloaded again. A run with nothing to fetch touches the
network zero times — the list is a local store path by then.

The practical consequence of all this: a machine that hasn't had network since
the last `nix flake update` still shows the previous twenty. It isn't broken,
it just hasn't caught up. `wallhaven-sync` when it's back online.

### The one-off directory change

`~/.local/share/wallpapers` used to be a single symlink to the dotfiles'
wallpaper directory in the store. It's now a real directory of per-file links
(`recursive = true` in `home/joshr/home.nix`), because a read-only store path
has nowhere to put `WallhavenFlake/`.

Switching between those two shapes is not something home-manager handles on
its own — with the old symlink still there, every wallpaper's target resolves
*through* it into the store, and the linker spends the switch trying to back
up files it cannot move. So `wallhaven.nix` removes the stale link first, once,
before the linking phase. It only does this for a symlink pointing into the
store; one you made yourself, to another disk say, is left alone with a
warning.

### What the first rebuild will do

`flake.lock` has no `wallhaven-toplist` entry yet — wallhaven.cc was not
reachable from where this was written, so there was nothing to hash. Nix adds
the entry itself on the first evaluation that has network; commit the result
like any other lock change.

That also means the response shape was matched against wallhaven's documented
API (`data[].path`, one page of 24) rather than a live call. The sync was
exercised end to end against a stand-in server — fresh sync, toplist rotation,
mid-run download failure, an error page in place of a listing — but not
against wallhaven itself. If a field has moved since, the failure is the loud
kind: `wallhaven-sync` says "not a wallhaven search response", exits non-zero
and changes nothing.

## Dates and times

12-hour clock, month before day, everywhere. There is no single setting for
this — every clock either carries its own format string or asks the locale —
so it is set in each of them, and they're listed here because that's the only
way to find them all again:

| where | file | format |
|---|---|---|
| locale (`date`, `ls -l`, anything that asks) | `modules/nixos/base.nix` | `LC_TIME = en_US.UTF-8` |
| waybar clock | `home/joshr/niri/waybar.nix` | `%I:%M %p   %a, %b %d` |
| swaylock | `home/joshr/niri/scripts.nix` | `%I:%M %p`, `%A, %B %d` |
| SDDM greeter | `modules/nixos/niri.nix` | `h:mm AP`, `dddd, MMMM d` |
| Plasma panel clocks | `home/joshr/plasma.nix` | `time.format = "12h"` |
| screenshot filenames | `niri.nix`, `scripts.nix` | `%m-%d-%Y %I-%M-%S %p` |

Two things worth knowing before editing any of them:

- **waybar is not strftime.** It formats through libfmt/date.h, so glibc's
  `%-I` "no padding" extension doesn't exist there — it comes out as a
  literal `-I` or throws the whole format away. Hence `07:30 PM` rather than
  `7:30 PM` in the bar. SDDM is Qt format, which is different again: `h`
  means 12-hour as soon as an `AP` field is present.
- **Screenshot filenames no longer sort chronologically.** `%m-%d-%Y` puts
  every January together. That's the cost of matching the rest of the system;
  if you'd rather have sortable names back, `%Y-%m-%d %H-%M-%S` is the string
  to restore, in both `niri.nix` and `scripts.nix`.

## The browser

**Vivaldi**, on every host. `home/joshr/browser.nix` installs it, sets
`$BROWSER`, and is the one place that decides which browser is *the* browser.

Firefox is still installed and still themed (`home/joshr/firefox.nix`) — it
held the default for a while, and the notes below are what it is still good
for. It simply isn't what links open in any more.

One detail that bites: nixpkgs copies Vivaldi's upstream `.deb` desktop entry
across **without renaming it**, so the entry ID is `vivaldi-stable.desktop`,
not `vivaldi.desktop`. Naming the wrong one fails silently — `mimeapps.list`
keeps whatever string you give it and `xdg-open` just finds nothing. Both
spellings are listed wherever the format takes a fallback list.

Both sessions get it the same way now: **`modules/nixos/default-apps.nix`**,
which writes `/etc/xdg/mimeapps.list`. `kdeglobals.General.BrowserApplication`
in `home/joshr/plasma.nix` is still set and still agrees.

### File associations, and why they're in /etc

This used to be home-manager's `xdg.mimeApps`, which owns
`~/.config/mimeapps.list` and writes it as a read-only symlink into the store.
That is the same file every interactive "make this the default" writes to —
Dolphin's "Open With… → Remember application association for this type of
file", KDE's File Associations panel, Plasma's Default Applications page, "set
as default" inside a browser. With home-manager holding it, **all of them
appear to work and none of them persist.** Images kept reverting; the checkbox
looked like it worked and the association was gone by the next launch.

It was also why the Plasma hosts were deliberately kept away from
`xdg.mimeApps` — under a running Plasma it breaks the settings page outright.

So the declarations moved down a level. The XDG mime-apps spec reads, in order
of decreasing precedence:

```
$XDG_CONFIG_HOME/$desktop-mimeapps.list
$XDG_CONFIG_HOME/mimeapps.list      <- the user's; nothing manages it now
$XDG_CONFIG_DIRS/$desktop-mimeapps.list
$XDG_CONFIG_DIRS/mimeapps.list      <- modules/nixos/default-apps.nix
```

`$XDG_CONFIG_DIRS` is `/etc/xdg`, so the declared defaults apply on a fresh
install and on every rebuild, while anything picked in a GUI lands in the
user's own file and outranks them. Declarative defaults *and* a settings panel
that works, rather than one at the cost of the other. It also removed the
reason the two sessions were configured differently.

`[Default Applications]` is honoured there specifically because `/etc/xdg` is a
*config* directory — the spec only reads that group from `$XDG_CONFIG_HOME` and
`$XDG_CONFIG_DIRS`, which is why this isn't in a data dir.

Note that **System Settings alone would not have fixed any of this.** It ships
no KCMs; it's the shell they load into. The File Associations panel
(`kcm_filetypes`, plus the standalone `keditfiletype` that Dolphin's properties
dialog opens) is in `kde-cli-tools`, which the niri profile now installs.
Default Applications (`kcm_componentchooser`) is in `plasma-desktop`, which is
deliberately not pulled in — it's a large chunk of Plasma, and that panel only
covers the browser/email/terminal/file-manager four rather than file types.

### Why Firefox is still here

The requirement when it took over was cloud sync, a Chromium or Firefox base,
and colours that follow the desktop theme. Firefox is the only candidate that
does all three without a workaround:

- **Sync** is Firefox Sync over a Mozilla account — first-party, end-to-end
  encrypted, carrying bookmarks, history, open tabs, logins, add-ons and
  preferences between the desk and the laptop with no server of your own.
  Sign in from the toolbar's account button; nothing about it is configured
  here beyond leaving `identity.fxaccounts.enabled` alone.
- **Theming** is the part that ruled the others out. A Chromium UI takes its
  colours from a signed theme extension or from GTK, and neither reads a file
  you generate. Vivaldi *can* take arbitrary colours, but only through its own
  settings UI, into a preferences blob that isn't declarative and can't be
  repointed at a symlink. Firefox reads `chrome/userChrome.css` out of the
  profile directory at startup, so it plugs straight into the mechanism
  already in place for everything else.

### How it follows the theme

`themes.nix` grows two more generated files per palette,
`firefox-userChrome.css` and `firefox-userContent.css`, and
`home/joshr/niri/firefox.nix` symlinks the profile's `chrome/userChrome.css`
and `chrome/userContent.css` at the active theme — the same out-of-store
symlink trick as `kdeglobals`. Tab strip, toolbars, address bar, menus,
sidebar, findbar and the `about:` pages all end up on the palette's ten
colour roles, with the accent on the selected tab and the focused address
bar, exactly like niri's focus ring and waybar's active workspace.

Two honest caveats:

- Firefox reads those stylesheets **once, while it starts**. There's no
  supported way to make a running Firefox re-read them, so a theme switch
  lands at the next launch — same as Dolphin, unlike kitty and waybar which
  the switcher can nudge.
- `userChrome.css` works against Firefox's internal CSS variables, not a
  documented config format. The names have been stable since the Proton
  redesign, but they aren't API. If an update renames one, that surface falls
  back to the built-in dark theme rather than breaking; the fix is to diff
  against `browser.css` in the new version.

All of that is niri-only, for the same reason the kitty `include` is: the
Plasma hosts have no theme state for the symlinks to point at, so there
Firefox wears its own dark theme and takes its accent from Plasma like any
other GTK app.

Note `home/joshr/niri/firefox.nix` is currently not imported by
`home/joshr/niri/default.nix`, so the stylesheet symlinks aren't in place.
Uncomment it there to turn Firefox's theming back on; the `xdg.mimeApps`
block that used to live in it has moved to `./browser.nix`, so the two won't
collide.

### What Nix owns and what Sync owns

Nix owns the *shape* of the browser — which prefs are set, that custom
stylesheets are on, that it handles `http(s)`. Sync owns the *contents* —
bookmarks, history, tabs, logins, add-ons.

That split is deliberate. Declaring add-ons here would need the NUR or the
firefox-addons flake, and would then fight Sync every time the two disagreed:
Nix would reinstall on the desk what you removed on the laptop. The prefs in
`firefox.nix` are written to `user.js`, which Firefox re-applies on **every**
start, so where the two overlap the declared value always wins. The practical
rule: anything you want to change from inside the browser and have stick must
not be listed in `firefox.nix`.

## Bootloader

`local.boot.loader` picks one of three, in `modules/nixos/boot.nix`:

| | themed | finds other OSes by |
|---|---|---|
| `limine` (default) | wallpaper + full palette, follows runtime switches | scanning every ESP on the machine for other loaders |
| `grub` | palette + fixed splash, build time only | `os-prober` |
| `systemd-boot` | not at all | itself, no setting needed |

limine is the default because it's the only one that can put the desktop's
wallpaper and colours on the boot menu. grub is the fallback for anything it
can't handle — BIOS/MBR, odd partition layouts, firmware that dislikes
limine's EFI binary — and it still detects *more*, since os-prober looks
inside other partitions rather than only at EFI System Partitions.
systemd-boot is the escape hatch and what this repo used before the module
existed:

```nix
local.boot.loader = "systemd-boot";
```

**Changing this rewrites how the machine boots.** Do it on a rebuild you can
watch, with install media to hand. The previous generation stays in the *old*
loader's menu — but only while that loader is still installed and still the
one your firmware runs.

### Dual boot: finding the other operating systems

**On by default.** `local.boot.detectOtherSystems = true` is the setting, and
under limine the scan runs in two passes:

1. **This machine's own ESP.** That is the whole story for a dual boot where
   both systems share one EFI System Partition, which is what you get when
   they're installed onto the same disk.
2. **Every other ESP attached to the machine**, behind
   `local.boot.scanAllEsps` (also on by default). NixOS mounts exactly one
   ESP, so an OS installed onto a disk of its own is otherwise invisible.
   Each is located by GPT partition type, mounted read-only, read, and
   unmounted. Nothing is written, and the service runs with `PrivateMounts`
   so a mount can't outlive the scan even if it's killed mid-way.

Whatever it finds appears under an **"Other operating systems"** branch in the
boot menu — one chainload entry per vendor directory that carries a
recognised loader (`bootmgfw.efi` for Windows, `shimx64.efi` or `grubx64.efi`
for a distro, rEFInd, elilo). Entries on this machine's ESP are addressed as
`boot():/…`; entries on any other are addressed by filesystem UUID, since
`boot()` only ever means the volume limine itself was loaded from.

To see what it found without rebooting:

```bash
sudo systemctl start limine-theme-sync
grep -A100 'detected systems' /boot/limine/limine.conf
```

Nothing found? The scan only reads EFI System Partitions. An OS whose loader
isn't on one — an old BIOS/MBR install, or a distro on an LVM or LUKS volume
with no ESP of its own — needs grub, whose `os-prober` inspects partitions
rather than boot partitions:

```nix
local.boot.loader = "grub";   # detects more, but no runtime theming
```

To turn detection off entirely, or to leave other disks alone:

```nix
local.boot.detectOtherSystems = false;   # no other-OS entries at all
local.boot.scanAllEsps = false;          # this machine's ESP only
```

### How the boot menu ends up wearing the desktop's colours

The menu is drawn before any of the desktop exists, from a text file on the
EFI System Partition. So the palette and wallpaper are *pushed* there ahead of
time, the same way the SDDM greeter is fed, and for the same reason: the thing
being themed can't read your home directory.

The NixOS limine module regenerates `<esp>/limine/limine.conf` on every
rebuild, so a runtime edit can't just go anywhere in it. What makes it work is
that the module emits two verbatim blocks at known ends of the file —
`extraConfig` first, `extraEntries` last. Each gets a sentinel-delimited
region, filled at build time with the default palette and no detected systems.
`limine-theme-sync` then rewrites the *inside* of each region, running at
boot, whenever you pick a theme or wallpaper, and at the end of every
bootloader install. If it never runs, the menu is still valid and still
themed, just with the default palette.

The regions sit where they do because limine's config has no separator between
global options and menu entries: an entry is opened by a line starting with
`/` and swallows every option after it. Theming keys are global and must go
above the first entry; detected-OS entries must go below the NixOS ones.

Three things keep this from being a way to brick the machine, and all three
are enforced in the module:

- **`enrollConfig` stays off.** Enrolling hashes the config into the limine
  binary; a rewritten file then fails its own integrity check and you stop at
  the bootloader. This is the one setting that turns a cosmetic feature into
  an unbootable system.
- **The wallpaper lives outside `<esp>/limine/`.** The installer walks that
  directory and deletes every file it didn't itself write, so an image parked
  there survives exactly until the next rebuild.
- **The config never names a wallpaper that isn't there.** Both the build-time
  block and the sync emit the `wallpaper:` line only alongside a file that
  exists.

`style.wallpapers` and the `style.graphicalTerminal.*` options are deliberately
left alone — they'd write the same keys from build-time values, duplicating
every line, and `style.wallpapers` additionally appends a BLAKE2b hash of the
image to the path, which is exactly what stops a file being swapped underneath
it at runtime.

Detection is ESP-only under limine: an OS on a disk that isn't mounted here
won't be seen, and a distro shipping both shim and grub is listed once (shim
wins — it's what boots under Secure Boot and hands over to grub itself).

```nix
local.boot.detectOtherSystems = false;   # skip the scan entirely
local.boot.wallpaper = ./some.png;       # menu image before niri picks one
local.boot.branding = "gamestation";     # text above the menu
local.boot.menuTransparency = "50";      # TT of limine's TTRRGGBB
```

## Shells

Fish is the login shell for both `joshr` and `root`, but zsh, bash and
nushell are all installed and configured too, and **all four get the same
starship prompt** from `home/common/files/starship.toml`.

Two things are needed for that, both in `home/common/shell.nix`. starship's
`enable*Integration` options already default to `true`, but all they do is
set the corresponding `programs.<shell>` options — and home-manager only
writes a shell's rc file when that shell's own module is enabled. So the
shells are enabled explicitly alongside the integrations; with only one half,
the prompt silently doesn't appear.

Note that only fish carries the eza aliases (`ls`, `ll`, `la`, `lt`, `lg`) —
those came from the dotfiles' `config.fish.tmpl` and haven't been mirrored
into the other shells.

### `nix-clean`

Also fish-only, and also in `home/common/shell.nix`, so `joshr` and `root`
both get it. It's the on-demand version of the weekly garbage collection in
`modules/nixos/base.nix`, for when you want the space back now:

```fish
nix-clean          # generations older than 7d, matching the weekly timer
nix-clean 30d      # any age nix-collect-garbage accepts
nix-clean all      # every generation but the current one
```

It runs `nix-collect-garbage` **twice**, and that's the point of it. The tool
only walks the profiles it can see, and which profiles those are follows
`$HOME`. The `sudo` run gets the system profile — old kernels, initrds and
system closures, which is where the space actually is — but root's `$HOME` is
`/root`, so it never reaches `~/.local/state/nix/profiles`, where
home-manager keeps joshr's generations. Sweep only the system half and those
stay pinned as live GC roots, holding their whole closures down with them.
The second run is skipped when you're already root, where it would just
repeat the first.

The current generation always survives, both here and under `all`. What you
spend is rollback: picking a previous generation from the boot menu is the
recovery path for a bad switch, which is why `all` has to be asked for by
name. Deleted generations also stay *listed* in the menu until the bootloader
config is regenerated, so the function ends by reminding you to
`sudo nixos-rebuild boot --flake /etc/nixos#<host>` — and `<host>` there is
the flake attribute, not the hostname. On this machine those differ:
`gamestation` and `gamestation-niri` both run on a box called `dialga`.

## Development environments

Both machines are set up so that **no language toolchain is installed
globally**. Python, node, a Rust compiler, JDKs, `gcc`, database clients —
none of it lives in the user profile. Each project declares what it needs in
its own `flake.nix`, and direnv puts those tools on `PATH` when you `cd` in
and takes them away again when you leave.

That's not asceticism. Two projects wanting different Python minor versions
is the normal case, and the moment toolchains are global, the second one is a
problem to be worked around. Per-project shells make it a non-event, and the
declaration travels with the repo, so the laptop and the desk agree without
either being configured for that project at all.

### One import, and it's off by default

All of it lives in **`modules/nixos/development.nix`**, and the import line is
**commented out in every desktop host**. Uncomment it on the machines you
actually develop on:

```nix
# hosts/gamestation/configuration.nix
    # ../../modules/nixos/development.nix     <- delete the #
```

`server` is the exception — it imports the module for real, since a headless
box is where containers and a remote `nix develop` are the point.

Note what that costs when it's off: **Docker goes with it.** The old
`modules/nixos/virtualisation.nix` had nothing in it but Docker and
docker-compose, so it was folded in here rather than left as a second thing to
remember. There's no finer granularity on purpose — one switch, one mental
model. `joshr`'s membership of the `docker` and `libvirtd` groups follows the
daemons automatically (`modules/nixos/users.nix`), so a host with the module
off doesn't fail activation naming groups that don't exist.

**VMs are a separate import.** QEMU/KVM and virt-manager used to be in here
too, and are now `modules/nixos/virtualization.nix`, added per host the same
way:

```nix
# hosts/gamestation-niri/configuration.nix
    ../../modules/nixos/virtualization.nix
```

Both are "virtualisation" in the NixOS option tree, which is how they ended up
in one file, but they aren't one decision: libvirtd is a daemon, a bridge
interface, swtpm and a GUI app, and wanting containers on a box is a poor
reason to be handed all of that. The group membership works the same way —
`users.nix` keys off `config.virtualisation.libvirtd.enable`, so importing one
module and not the other is fine.

What that one turns on: **libvirtd** with `qemu_kvm` and `runAsRoot = false`
(the failure mode of the other setting is a guest escape being a root escape);
**swtpm**, the software TPM a Windows 11 guest insists on; **virt-manager** as
the GUI, via `programs.virt-manager` rather than the bare package because the
module also enables the dconf settings it keeps its connection list in; **SPICE
USB redirection**, so a passed-through YubiKey or flash drive reaches the
guest; and `virtiofsd` + `spice-gtk` for host directory sharing and the console
client.

What the module turns on:

- **direnv** with **nix-direnv**, hooked into bash, zsh and fish. Plain direnv
  re-evaluates `use flake` from scratch on every `cd`, which for a flake means
  seconds each time; nix-direnv caches the built profile and only
  re-evaluates when `flake.nix` or `flake.lock` change. It also plants a GC
  root in `.direnv/`, so the weekly `nix-collect-garbage` in `base.nix` can't
  delete a shell you're still using.
  - This is the NixOS module, not home-manager's, so the whole story is one
    import. The one gap is **nushell** — the NixOS module doesn't hook it.
  - Per-user tuning (`hide_env_diff`, `warn_timeout`) is a
    `~/.config/direnv/direnv.toml` thing that no system module can set.
- **Docker** + docker-compose.
- **`dev-init`**, the one-command path below.
- The nix settings the rest depends on, all of which need root: `keep-outputs`
  and `keep-derivations`, without which garbage collection deletes the *build*
  inputs of a dev shell (a shell isn't a package, so nothing points at its
  output); `trusted-users = [ "root" "@wheel" ]`, without which `cachix use`
  can't write a substituter; and `log-lines = 25`, because ten lines of a
  failed builder's output usually isn't the part that says what went wrong.
- **A pinned `nixpkgs` in the flake registry**, set to the rev this system is
  built from. Every template says `inputs.nixpkgs.url = "nixpkgs"` rather than
  naming a URL, so a new project's shell resolves to store paths the machine
  already has. It's what `nix run nixpkgs#...` means here too. See [Why a
  project shell is instant](#why-a-project-shell-is-instant).
- Language-agnostic tools: `nil`, `nixfmt`, `nix-output-monitor`,
  `nix-tree`, `cachix`, `just`, `jq`, `yq-go`, `ripgrep`, `fd`, `lazygit`,
  `gnumake`. Nothing language-specific — a compiler or an interpreter goes in
  the project's own devShell.

### The one-command path

In the project directory:

```bash
dev-init            # generic skeleton
dev-init python     # or: node, rust, go
```

That copies a template's `flake.nix`, `.envrc` and `.gitignore` in and marks
the `.envrc` trusted, so the shell is built and entered at the prompt you get
back. Commit all three files — the whole point is that the next machine gets
the same environment by cloning.

`dev-init` refuses to run where a `flake.nix` already exists rather than
overwrite one.

### The manual path

Two files. `flake.nix`:

```nix
{
  # Resolved through the flake registry — see below.
  inputs.nixpkgs.url = "nixpkgs";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [ python313 postgresql ];

        # Exported on entry, gone on exit.
        env.DATABASE_URL = "postgres://localhost/dev";

        shellHook = ''
          echo "ready"
        '';
      };
    };
}
```

and `.envrc`:

```
use flake
```

Then `direnv allow`. direnv refuses to run an `.envrc` it hasn't been told to
trust — that message on first entry, and after every edit, is the safety
check working, not a failure.

### Day to day

| | |
|---|---|
| add a tool | put it in `packages`, save; direnv rebuilds on the next prompt |
| find the attribute name | `nix search nixpkgs ripgrep`, or search.nixos.org |
| pin the exact versions | commit `flake.lock` — it's what makes the shell reproducible |
| update them | `nix flake update`, or `nix flake update nixpkgs` for one input |
| force a rebuild | `direnv reload` |
| run one command without entering | `nix develop -c pytest` |
| a second shell (e.g. CI) | `devShells.${system}.ci = ...`, entered with `use flake .#ci` |

Anything the project writes at runtime — a venv, `node_modules`, `GOPATH` —
stays inside the project directory. The templates set that up and ignore the
paths in `.gitignore`, because the Nix store is read-only and the alternative
is a tool failing halfway through an install with a confusing error.

### Why a project shell is instant

Two things keep `direnv allow` down to a couple of seconds, and both are easy
to undo by accident.

**The shell resolves to a nixpkgs the machine already has.** The templates say
`inputs.nixpkgs.url = "nixpkgs"` — an indirect ref, which `development.nix`
pins in the flake registry to the rev this system is built from. Name a URL
there instead and the project locks against whatever `nixos-unstable` was that
afternoon: nothing is *wrong* with the result, but every path the shell needs
becomes a fresh download of a bit-for-bit alternative to something already in
`/nix/store`. Pinned, `nix flake update` in a project re-resolves against the
system's current lock, so the shells move when the machines do — which is the
reason the templates live in this repo at all.

**Python libraries come from a package set nixpkgs actually builds.** This is
the one that bites. nixpkgs exposes a package set per interpreter but only
marks some of them `recurseIntoAttrs` in `all-packages.nix`:

```nix
python311Packages = python311.pkgs;                   # evaluated, never built
python312Packages = python312.pkgs;                   # evaluated, never built
python313Packages = recurseIntoAttrs python313.pkgs;  # built by Hydra
python314Packages = recurseIntoAttrs python314.pkgs;  # built by Hydra
python3Packages   = dontRecurseIntoAttrs python314Packages;
```

Hydra enumerates the recursed sets and builds them, and cache.nixos.org holds
what Hydra builds. The others evaluate perfectly well and are simply never
built, so every derivation in them is compiled locally — test suites included
— each time the lock moves. The list changes: 3.11 fell off in December 2024,
3.12 in November 2025.

The **interpreters** are all built regardless. `pkgs.python312` is a
substituted binary like anything else, so choosing a minor version is free.
It's asking an unbuilt *set* for a library that isn't.

Which is exactly what the python template used to do. It read
`python312.pkgs.python-lsp-server` from the moment 3.12 stopped being built,
and python-lsp-server's check inputs are numpy, pandas and matplotlib plus its
whole optional-linter set — so a first `cd` into a project compiled all of
that before returning a prompt, and did it again after every `nix flake
update`. It now takes pylsp from `python3Packages`, which is always the
default and always built, and leaves the project's interpreter a free choice:
jedi resolves completions from `$VIRTUAL_ENV`, so a language server running on
3.14 reads a 3.12 venv correctly.

When a shell is unexpectedly slow, this says what it's about to do:

```bash
nix build --dry-run .#devShells.x86_64-linux.default
```

Paths under "will be fetched" are a download. Anything under "will be built"
that isn't your own package is a set that nobody cached.

### Secrets

Don't put them in `flake.nix` — it goes in the store, world-readable. Use a
gitignored `.env` and read it from `.envrc`, which direnv evaluates on your
machine and never copies anywhere:

```bash
# .envrc
use flake
dotenv_if_exists .env
```

### A project that isn't yours

Most repos don't ship a flake. Add one anyway — `dev-init` in a clone works
fine, and `flake.nix`, `.envrc` and `.direnv/` can stay out of the repo's
history via `.git/info/exclude` if you'd rather not commit them upstream.

If a project has a `shell.nix` or `default.nix` already, skip the flake
entirely and let direnv use it:

```
# .envrc
use nix
```

And when the dependency really is a whole service rather than a binary —
Postgres, Redis, a message queue — reach for Docker Compose instead; both
hosts have it via `modules/nixos/virtualisation.nix`. A dev shell is for
tools, not daemons.

### VS Code

The editor has to be told about direnv, or it sees the bare system `PATH` and
reports every import in the project as unresolved. `mkhl.direnv` is in the
extension list in `home/joshr/vscode.nix` for that reason — it hands the
shell's environment to language servers, terminals and the debugger. If
something still looks wrong, launching `code .` from inside a directory
direnv has already loaded is the quick way to tell the two apart.

`jnoortheen.nix-ide` is in the list too, pointed at the `nil` and `nixfmt`
from `development.nix` rather than downloading its own — so on a host with
that module still commented out, neither name resolves and both settings are
inert.

## Single GPU passthrough

Give the desk's graphics card to a virtual machine for as long as that machine
is running, and take it back when it shuts down. `gamestation-niri` has it on;
`modules/nixos/gpu-passthrough.nix` is the whole of it.

The usual sort of VFIO passthrough is a two-card arrangement: the host uses
one, the guest gets the other, and the guest's card is bound to `vfio-pci` in
the initrd before anything else can claim it. There is one card in this box.
The host is *using* it — greeter, compositor, framebuffer console — so before a
guest can have it, every one of those has to let go, and afterwards every one
of them has to come back. libvirt has no idea how to do that, which is why
there is a hook.

### What it costs

**Starting one of these guests logs you out.** The display manager is stopped,
the session goes with it, the screen is dark for a few seconds and then the
guest is driving the monitor. Shutting the guest down brings the greeter back
and you log in again.

That is not a rough edge to be filed off later. One card cannot be in two
operating systems at once, and every implementation of this — scripts, hooks,
someone typing `systemctl stop display-manager` by hand — ends at the same
place. What the module buys is that it happens in the right order, that it is
undone in the right order, and that a failure half way through puts the desktop
back rather than leaving a black screen.

Anything you want to keep running belongs on the *host's* other tty or on
another machine. An SSH session survives the whole thing; `base.nix` has sshd
on with password auth off, so put a key in place first if there isn't one.

### Turning it on

```nix
# hosts/gamestation-niri/configuration.nix
    ../../modules/nixos/virtualization.nix        # libvirtd, which the hook needs

  local.virtualisation.singleGpuPassthrough = {
    enable = true;
    vms = [ "win11" ];    # `virsh list --all` prints these names
  };
```

The module rides along with `virtualization.nix` rather than being a third
import to remember — it is a libvirt hook and nothing else, so it has no
meaning without libvirtd and costs nothing until `enable` is set.

`vms` is the list of libvirt domains allowed to take the card. Everything not
named there starts and stops as an ordinary VM, and the hook returns
immediately. It is a list rather than "any domain with a `<hostdev>`" because
being wrong is asymmetric: a guest treated as a passthrough guest when it isn't
takes the desktop down every time it boots, while a passthrough guest that
isn't listed merely comes up without a display, with the session still there to
fix it in. A name that matches no domain is inert, so renaming a VM makes
passthrough *stop* rather than start happening to something else.

An empty list is a warning at rebuild time, not an error. So is a kernel
command line with neither `amd_iommu=on` nor `intel_iommu=on` — VFIO needs an
IOMMU, and on this box `hosts/gamestation/kernel-params.nix` has had
`amd_iommu=on iommu=pt` for exactly this reason since before there was anything
to use it. It stays a warning because a recent kernel may have the IOMMU on
already, because the firmware does.

The other three options are for when the defaults don't fit:

| | |
|---|---|
| `pciDevices` | The card's PCI functions, `0000:0b:00.0` style. Empty — the default — reads them out of the guest's own `<hostdev>` entries on stdin, so the card is written down once, in the VM, rather than twice. Set it when the guest's device list mixes the GPU with something the hook should leave alone. |
| `hostDriverModules` | What to unload before the guest starts, most dependent module first; they go back in the reverse order. Defaults to the NVIDIA stack when `services.xserver.videoDrivers` says `nvidia`, otherwise `amdgpu`. |
| `stopServices` | Extra units holding the card — a local model runner, a transcoder, a container started with the GPU passed in. `display-manager.service` is always handled and doesn't belong here. Only units that were running get stopped, and only those get started again. |

### The guest itself

Nothing here creates a VM. Make it in virt-manager as usual, then **Add
Hardware → PCI Host Device** for every function of the card — the video one and
its HDMI/DP audio at least, and everything else in the same IOMMU group,
because a group travels together:

```bash
lspci -nnk                                   # addresses, and who has them now
find /sys/kernel/iommu_groups -type l        # what shares a group with what
```

virt-manager writes those as `<hostdev managed='yes'>`, which means libvirt
does the vfio-pci binding itself. That works: by the time libvirt gets there
the hook has already taken the host driver off the card. The hook binds them
too when it can name them, which is belt and braces rather than a requirement.

`virtualization.nix` already turns on the two things a Windows guest asks for
beyond this — OVMF for UEFI and swtpm for the TPM 2.0 device.

### What happens when the guest starts

libvirt runs every executable in `/var/lib/libvirt/hooks/qemu.d/` around a
domain's lifecycle, with the domain name, the operation and the domain XML on
stdin. The hook acts on two of them and ignores the rest. `prepare/begin` is
before libvirt has allocated anything for the guest — the last moment the host
can be told to drop the card cleanly — and in order it:

1. Stops `display-manager.service`, and anything in `stopServices`.
2. Unbinds the framebuffer console (`/sys/class/vtconsole/vtcon*`), which holds
   the card without being a service at all.
3. Unbinds whatever drew the boot splash — `efi-framebuffer` on the old path,
   `simple-framebuffer` on anything recent enough to be using simpledrm.
4. Unloads the GPU driver, retrying while it is busy. `systemctl stop` returns
   when the *unit* is gone, but a compositor's last processes can hold a
   `/dev/nvidia*` open for a moment after that, and the module won't come out
   while they do.
5. Loads `vfio-pci` and binds the card's functions to it through
   `driver_override`, so the re-probe can only land on vfio-pci and the host
   driver can't race for the card it has just let go of.

If any of that fails, the hook puts the host back and *then* reports the
failure. libvirt turns a non-zero hook into a refused domain start, which is
the right outcome once the desktop is back: a VM that won't start is a problem
you can look at, and a machine with no display manager and no GPU driver is
not.

### And when it stops

`release/end` fires after the domain is fully torn down and libvirt has already
reattached whatever it detached itself, so the card is genuinely free. The hook
unbinds it from vfio-pci, clears the driver override, unloads the vfio modules,
loads the GPU driver back in the reverse of the order it came out, rebinds the
console, and starts the display manager last — the greeter wants a card that is
already back.

It restores exactly what the other half stopped and unbound, which it wrote
down in `/run/single-gpu-passthrough.state`. That is deliberate: a unit that
was already off before the guest started stays off. `/run` is tmpfs, so a
reboot with a guest running leaves no stale file to act on, and if the file is
missing the hook falls back to restoring the console and the display manager —
the things whose absence leaves no way back in.

### When it goes wrong

```bash
journalctl -t single-gpu-passthrough -f    # what the hook did, step by step
journalctl -u libvirtd -f                  # what libvirt made of it
```

The hook is also on `PATH` as `single-gpu-passthrough`, taking the same
arguments libvirt gives it. That is the way out when a guest has died in a way
that never produced a `release/end` and the machine is sitting there with no
desktop — from a TTY, or over SSH from another machine:

```bash
sudo single-gpu-passthrough <domain> release end < /dev/null
```

Ctrl+Alt+F2 gets a TTY right up until step 2 above; after that, SSH is the way
in.

Two failures worth naming:

- **"could not unload the host GPU driver"**, and the desktop comes straight
  back. Something still has the card open. `sudo fuser -v /dev/nvidia*` or
  `lsof /dev/dri/*` names it; if it's a service, put it in `stopServices`.
- **The guest starts but has no display**, and the host is dark. The card went
  to vfio-pci but the guest didn't get it, or didn't drive it. Check that every
  function of the card — and everything else in its IOMMU group — is attached
  to the domain, then look at the guest's own console over SPICE.

A rebuild alone doesn't install a changed hook. The libvirtd module symlinks
the hooks into `/var/lib/libvirt/hooks/qemu.d/` from its `preStart`, so it
takes a `sudo systemctl restart libvirtd` (or a reboot) before the new one is
the one that runs.

## Local AI

Models that run on this machine's own card. `modules/nixos/ai.nix`, imported
by `gamestation-niri` and nowhere else — the laptop has no discrete GPU and
the server has neither a GPU nor anyone sitting at it.

Three programs, three jobs:

| | What it is | Where |
|---|---|---|
| **ollama** | the model server: holds the weights, answers HTTP | `127.0.0.1:11434` |
| **Open WebUI** | a browser chat window, pointed at ollama | `127.0.0.1:8080` |
| **OpenClaw** | an agent — sessions, tools, chat channels — with a control UI | `127.0.0.1:18789` |

All three are on loopback and **nothing here opens a firewall port**. Reaching
any of them from a phone is a `tailscale serve` decision to make on purpose;
`services.tailscale` is already up from `base.nix`, so the tailnet is there
when you want it, and none of these is on it until you say so.

### Turning it on

```nix
# hosts/gamestation-niri/configuration.nix
local.ai = {
  enable = true;

  ollama.models = [
    "qwen3"
    "nomic-embed-text"
  ];

  openclaw = {
    enable = true;
    model = "ollama/qwen3";
    linger = false;
  };
};
```

`local.ai.enable` brings up the model server and the chat window. It does
*not* bring up the agent — `local.ai.openclaw.enable` is separate, and the
reason is [further down](#openclaw-and-what-it-costs). Every option is in
`modules/nixos/options.nix` with its reasoning attached.

### The first rebuild is a long one

`local.ai.ollama.acceleration` defaults to `"auto"`, which reads
`services.xserver.videoDrivers`: nvidia here, so `ollama-cuda`.

**cache.nixos.org does not have that build.** Hydra doesn't build against
unfree CUDA, so the first rebuild after enabling this compiles ollama on the
machine. Tens of minutes, once, and again after a nixpkgs bump moves it.

That is the cost of the right default rather than a fault in it — on this
card, "cuda" versus "cpu" is roughly the difference between a conversation and
a progress bar. Two ways round it if the wait isn't acceptable today:

```nix
local.ai.ollama.acceleration = "cpu";   # builds from cache, small models are usable
```

or point the daemon at the cuda-maintainers cachix and let someone else have
done the build.

### Models

`local.ai.ollama.models` is a **download** list, not a build input. Names come
from [ollama.com/library](https://ollama.com/library); a bare name means that
model's default tag, `name:tag` picks a size.

```
ollama list                  # what's actually on disk
ollama pull deepseek-r1      # try one without editing the config
ollama run qwen3             # a terminal chat, straight against the server
```

`ollama-model-loader.service` fetches them in the background once the server
is up, so a rebuild never waits on gigabytes, and a machine that was offline
at the time retries with a backoff instead of failing activation. The weights
live under `/var/lib/ollama` and never enter the store — which also means the
weekly `nix-collect-garbage` has no opinion about them, and neither does a
rollback.

Pulling by hand and writing down the keepers afterwards is the intended
rhythm. `local.ai.ollama.pruneUndeclaredModels = true` reverses that and makes
the list authoritative, deleting anything not named in it.

**If the agent is going to use a model, it needs tool calling and at least a
16K context window.** OpenClaw checks for both and quietly won't offer a model
that lacks them, which reads as "the agent is broken" rather than "that model
can only chat". `qwen3` is in the list above for exactly this reason; several
otherwise excellent small models advertise no tools at all.
`nomic-embed-text` is a different kind of thing — it's what Open WebUI uses to
index documents you upload, not something you talk to.

### Open WebUI

`http://127.0.0.1:8080`. The first visit asks you to create an account; it is
local to this machine, lives in a SQLite file under `/var/lib/open-webui`, and
is what stops a stray browser tab talking to the models. If that ceremony
isn't wanted on a single-user desktop:

```nix
local.ai.webui.extraEnvironment.WEBUI_AUTH = "False";
```

The module turns telemetry off, points the UI at the local ollama, and sets
`ENABLE_OPENAI_API = "False"` — with no key on this box, leaving that on costs
a connection attempt to `api.openai.com` at every start and a spinner on the
model list. `extraEnvironment` merges over all of that and wins, so adding a
key later is two lines. Secrets don't go there —
`services.open-webui.environmentFile` takes a path for those.

### OpenClaw, and what it costs

OpenClaw is not a chat window. It's a gateway: sessions, tools, chat channels
(WhatsApp, Telegram, Discord and a dozen more), with a control UI on
`http://127.0.0.1:18789`.

That is also the problem, and it is worth stating plainly rather than in a
footnote. **nixpkgs ships this package with a `knownVulnerabilities` entry**,
so a plain rebuild refuses to install it:

```
error: Refusing to evaluate package 'openclaw-2026.6.33' … because it is marked as insecure
  - Project uses LLMs to parse untrusted content, making it vulnerable to
    prompt injection, while having full access to system by default.
```

That is accurate. An agent acts on text that arrived from somewhere else — a
message, a fetched web page, a document — and there is no reliable way to stop
instructions inside that text from being followed. `ai.nix` disarms the check
for this one package by name:

```nix
nixpkgs.config.allowInsecurePredicate = pkg: lib.getName pkg == "openclaw";
```

By name rather than by nixpkgs' suggested `permittedInsecurePackages = [
"openclaw-2026.6.33" ]`, so a `nix flake update` doesn't break the next
rebuild with an error about a version number nobody chose. It does replace
nixpkgs' default predicate, which is the one that reads
`permittedInsecurePackages` — nothing else here uses that list, but if
something ever does, that line is where it has to be taught about it.

So `local.ai.openclaw.enable` is deliberately not wired to `local.ai.enable`.
Turning it on is where the decision gets made, and what limits the blast
radius afterwards is the account boundary and nothing else:

- It runs as a **systemd user service** for one account —
  `local.ai.openclaw.user`, defaulting to `local.desktop.primaryUser`.
- It is **not sandboxed**, on purpose. `DynamicUser`, `ProtectHome` and the
  rest would each remove a capability the program exists to have. Assume
  anything that user can do, this can be talked into doing. On this machine
  that user isn't root.
- NixOS has one `systemd --user` generation for the whole box, so the unit is
  defined for every account and `ConditionUser=` selects the right one.
  Everyone else's user manager skips it with a journal line and no failure.
- `local.ai.openclaw.linger = false` means it's up while that account has a
  session and gone otherwise, which is the honest shape for something on a
  desk. Turn it on for a machine you message while nobody's sitting at it —
  and notice that this means an agent with a shell running unattended.

#### First start

Two things have to exist before the gateway will run, and neither can come out
of the Nix store, so the unit's `ExecStart` is a small wrapper that makes them:

1. **A token.** The gateway requires authentication. One is generated on first
   start into `~/.openclaw/gateway.env`, mode 600, and read back on every
   start after that. Nothing secret ends up in a world-readable store path.
2. **A config file.** Seeded at `~/.openclaw/openclaw.json` if it's missing —
   the token reference and, if `local.ai.openclaw.model` is set, the primary
   model. That's all: OpenClaw validates its config strictly, and an unknown
   key doesn't warn, it stops the gateway booting.

**The seed is written once and never again**, because OpenClaw owns that file
afterwards — its control UI writes to it, `openclaw config set` writes to it,
and the gateway hot-reloads it while running. Upstream explicitly says not to
make it a symlink, which rules out the usual Nix approach. The practical
consequence:

> Changing `local.ai.openclaw.model` after the machine has started once does
> **nothing**. Use `openclaw models set ollama/<model>`.

The port is the exception — it's passed on the command line, so
`local.ai.openclaw.port` stays authoritative and can't drift.

`~/.openclaw/gateway.env` is also the place to put provider credentials by
hand — `OPENAI_API_KEY`, `ANTHROPIC_API_KEY` — for anything that isn't the
local server. It's sourced, so comments and bare `NAME=value` both work.
`local.ai.openclaw.environmentFile` is the other half of that: a path to a
file something *else* manages, outside the home directory. A missing file
there isn't an error, so it can be named before it exists.

#### Talking to the local models

The unit sets `OLLAMA_API_KEY=ollama-local`, which is upstream's marker for
"this host needs no real credential" and what opts the bundled Ollama provider
in. There is no account behind that string and it is not a secret.

```
openclaw models list          # what it can see
openclaw models set ollama/qwen3
openclaw onboard              # the interactive setup, if you'd rather
openclaw doctor               # what it thinks is wrong
```

Discovery only looks at the default `11434`. Moving `local.ai.ollama.port`
with the agent enabled makes a rebuild warn and hands you the two `openclaw
config set` lines that teach it the new address.

### Sharing the card with a VM

`gamestation-niri` also runs [single GPU passthrough](#single-gpu-passthrough),
and a loaded model pins the NVIDIA driver in memory. The hook can't unload a
driver something else is holding, so its five attempts fail and the guest
refuses to start.

`ai.nix` adds `ollama.service` and `open-webui.service` to that hook's
`stopServices` list itself, which is the case that option's `example` was
written for. Nothing to configure — start the VM, the model server stops with
the display manager, and both come back when the guest does. The two modules
are otherwise independent; either works without the other.

### When it goes wrong

```bash
systemctl status ollama open-webui        # the two system services
journalctl -u ollama -f

systemctl --user status openclaw          # the agent, as its own user
journalctl --user -u openclaw -f
openclaw doctor

curl http://127.0.0.1:11434/api/tags      # is the model server answering?
nvidia-smi                                # is anything on the card?
```

A few failures that look like something else:

- **The gateway won't start and only `openclaw doctor` works.** Config
  validation failed. OpenClaw refuses to boot on an unknown key or a bad
  value, and says which one.
- **`systemctl --user status openclaw` says the condition failed.** That's a
  different account than `local.ai.openclaw.user`. Working as intended — the
  unit exists for every user manager on the machine.
- **The agent sees no models.** Either ollama has none yet (`ollama list`), or
  the ones it has don't do tool calling, or the port was moved. The rebuild
  warns about the last of those.
- **A rebuild refuses to evaluate `openclaw`.** The predicate above is in the
  `local.ai.openclaw.enable` branch, so it only applies when the agent is on.
  Installing the package some other way needs its own answer.

## Scheduled jobs

`server` runs its recurring work as **actual cronjobs**. The section is in
`hosts/server/configuration.nix`, and the option behind it is
`modules/nixos/cron.nix`:

```nix
local.cron = {
  enable = true;

  jobs = [
    {
      name = "nix-gc";
      description = "Trim the store beyond what base.nix's weekly GC keeps";
      schedule = "30 3 * * 0";
      command = "nix-collect-garbage --delete-older-than 30d";
    }
  ];
};
```

Each entry becomes one line of the system crontab plus a comment, so
`/etc/crontab` stays readable. `user` defaults to `root`. `schedule` is
standard five-field crontab syntax, and the `@daily` / `@weekly` / `@reboot`
shorthands work too. Schedules are in the system timezone (`time.timeZone`),
not UTC.

Three things worth knowing:

- **Bare command names work here**, which is the opposite of the usual cron
  advice. nixpkgs' cron module writes `SHELL=…/bash` and
  `PATH=<system.path>/bin:<system.path>/sbin` above our jobs, so anything in
  `environment.systemPackages` resolves by name. `local.cron.path` exists for
  tools that *aren't* installed system-wide, and it extends that PATH rather
  than replacing it — replacing it is the easy mistake, since a second `PATH=`
  line in a crontab wins over the first.
- **`%` is a crontab metacharacter**, meaning "newline" — everything after the
  first one is fed to the job on stdin. `date +%F` has to be written
  `date +\%F`.
- **A job missed while the machine was off never runs.** Cron has no catch-up.

### When not to use it

Cron was chosen because crontab syntax is familiar and these jobs are the
boring kind. It is genuinely the weaker tool: output goes to a mail spool that
no MTA is reading, so a job that's been failing for a month is invisible;
`systemctl list-timers` has no equivalent; and there's the missed-job problem
above.

So if a job *matters* — skipping it silently is a problem, or you'll want to
know why it failed three days ago — write it as a systemd service plus a timer
with `Persistent = true` directly in the host config. Nothing stops the two
coexisting. For output you actually want to read from a cron job, redirect it
yourself: `... 2>&1 | systemd-cat -t backup`.

## The accounts

Three, on every host, all declared in `modules/nixos/users.nix` and all given
a home-manager profile in `flake.nix`:

| Account | Description | Profile | `wheel` |
|---|---|---|---|
| `joshr` | Josh Randall | `home/joshr/<host>.nix` | yes |
| `raiden` | Samuel Hunt | `home/raiden/<host>.nix` → joshr's | no |
| `root` | — | `home/root/home.nix` | — |

Both interactive accounts get fish, `networkmanager`, `video` and `input`, plus
`docker` and `libvirtd` on the hosts whose imports enable those daemons. Only
`joshr` is in `wheel`, so `sudo nixos-rebuild` is joshr's; add `"wheel"` to
`extraGroups` in `users.nix` to change that. Both are created with
`initialPassword = "changeme"` — which applies at first creation only, so
`passwd` after the first login is the whole of the fix.

`mkHost` in `flake.nix` takes its users as an attrset:

```nix
gamestation = mkHost {
  hostModule = ./hosts/gamestation/configuration.nix;
  homeModules = {
    joshr = ./home/joshr/gamestation.nix;
    raiden = ./home/raiden/gamestation.nix;
  };
};
```

`root` is added to every host by `mkHost` itself rather than repeated in each
call — it gets the same shell everywhere and nothing graphical follows it in,
so there is nothing per-host to say about it.

### What "primary user" actually decides

`joshr` being the primary user is one option, `local.desktop.primaryUser`, and
it is about the surfaces that exist outside any session: the SDDM/plasmalogin
greeter and the limine boot menu take their theme and wallpaper from that
account's `~/.local/state/niri-theme` and `~/.config`, and the OpenRGB
after-resume service runs as it.

Each of those is a singleton — one login screen, one boot menu, one set of
lights — so they follow one named account rather than whoever logged in last.
Everything else is per-account and per-session: `raiden` switching themes
restyles `raiden`'s niri, kitty, waybar, Firefox and Dolphin, and leaves the
greeter and the boot menu alone.

### One profile, two accounts

`home/raiden/` contains no configuration. Each entrypoint imports joshr's for
the same host and `./home.nix`, which sets one thing:

```nix
# home/raiden/gamestation.nix
{
  imports = [
    ./home.nix
    ../joshr/gamestation.nix
  ];
}
```

So anything added to joshr's profile arrives in raiden's on the next rebuild,
which is the point of importing rather than copying.

That works because nothing under `home/joshr/` writes the name `joshr` into a
path. `home.username` in `home/joshr/home.nix` (and `home/joshr/server.nix`)
is a `lib.mkDefault`, raiden's `home.username` outranks it at ordinary
priority, and everything downstream is derived from it:

| Derived from the account name | Where |
|---|---|
| `~` and everything under it | `home.homeDirectory` |
| `~/.mozilla/firefox/<name>` | `home/joshr/firefox.nix`, read back by `niri/firefox.nix` |
| `<name>-gwenview.desktop` and friends | `home/joshr/desktop-apps.nix` |
| `com.<name>.NiriSystem` | `home/joshr/obs.nix` |

All four resolve to exactly what they were for `joshr`, so nothing of joshr's
moved when raiden was added — no Firefox profile to migrate, no desktop
entries to re-associate.

One thing raiden does *not* get its own of: the git identity — joshr's name
and address, from `home/common/git.nix` on the desktop hosts and from
`home/joshr/server.nix` on the server. Commits from `raiden` carry it until
it's overridden, and `home/raiden/home.nix` has the `lib.mkForce` to do that
sitting commented out.

### Adding a third

1. An account in `modules/nixos/users.nix`. Copy the `raiden` block; the
   `sessionGroups` list above it is the shared membership.
2. A `home/<name>/` directory shaped like `home/raiden/` — a `home.nix` with
   the username, and one entrypoint per host importing joshr's.
3. The name and its entrypoint in each host's `homeModules` in `flake.nix`.

Nothing else. In particular, don't change `local.desktop.primaryUser` unless
you mean to hand the login screen and boot menu to the new account.

## The root account

`root` uses fish as its login shell and gets the same starship prompt and eza
aliases as `joshr`, via `home/common/shell.nix`. It gets nothing else — no
Plasma, no Kitty config, no GUI packages.

That split isn't invented here; it's what the dotfiles already do. Their
`.chezmoiignore` has a `root` / `jrh` / `jrp` branch that strips the Plasma
configs, Code, spicetify, mpv, vlc, wallpapers, icons and colour schemes, and
`config.fish.tmpl` branches on username to give root an **empty**
`fish_greeting` instead of the fastfetch one. Both behaviours are reproduced
here — the greeting via `local.shell.fastfetchGreeting`, which also decides
whether fastfetch and `~/.smallfetch.jsonc` get installed at all.

Root is managed by home-manager rather than chezmoi, same as joshr. Pointing
chezmoi at the dotfiles repo for root would mean two mechanisms writing to
the same home directories, with chezmoi's state living outside the Nix store
and drifting on its own.

## Where things came from

Your `dotfiles` repo is a chezmoi repo, so it isn't "home-manager-native" —
there's no 1:1 mechanical conversion. What I did instead:

- **Settings** (kdeglobals, plasmarc, kwinrc, kglobalshortcutsrc, the
  appletsrc panel layout, fish config, VS Code settings, kitty config,
  starship.toml) were read from the repo and translated into
  `programs.plasma`/`programs.fish`/`programs.kitty`/`programs.vscode` options
  in `home/joshr/`. Anything that was pure session noise (window-tiling
  geometry caches, per-instance applet UUIDs, dialog-size memory, activity
  UUIDs) was dropped rather than transcribed.
- **Large assets** (fonts, the `Fluent-round-Pursuit` Plasma theme and other
  vendored desktop themes, the two `look-and-feel` packages, the
  `Bibata-Modern-Ice` cursor theme, your custom `j-accent`/`j-contrast` SVGs,
  and your wallpapers) are pulled straight from the `dotfiles` repo via the
  `dotfiles` flake input (see `flake.nix`) instead of being hand-copied. This
  means `nix flake update dotfiles` will pick up changes you push to that repo.
- **VS Code extensions** aren't declaratively pinned (most aren't packaged in
  nixpkgs), so `vscode.nix` reinstalls them from the marketplace on every
  `home-manager switch`, mirroring what `scripts/install-vscode-extensions.sh`
  did in the original repo.
- Things I could find no evidence you'd actually customized (e.g. almost all
  of `kglobalshortcutsrc`, which was stock KDE defaults) were left alone
  rather than guessed at.
- **Per-machine profiles have no direct equivalent here.** The dotfiles repo
  uses chezmoi templates (`.chezmoiignore`, `config.fish.tmpl`) to branch on
  OS, username, and hostname — notably a shell-and-starship-only profile for
  root and for `jrh`/`jrp` hostnames. In Nix that job belongs to separate
  `nixosConfigurations.<host>` entries in `flake.nix` rather than to
  in-file conditionals, so nothing was ported for it. If you want a minimal
  laptop host that skips Plasma/gaming, that's a new host entry importing a
  subset of `modules/nixos/`.

## Before you build this

1. **Hardware config.** `hosts/gamestation/hardware-configuration.nix` is a
   placeholder — it has invented disk labels and a guessed CPU vendor, and
   will not boot your machine. See
   [Regenerating hardware-configuration.nix](#regenerating-hardware-configurationnix)
   below.
2. **NVIDIA generation.** `modules/nixos/nvidia.nix` sets `open = true`, the
   open kernel module, which needs a Turing (RTX 20xx) card or newer. On
   anything older, flip it to `false` for the proprietary module.
3. **Multi-monitor panel layout.** `home/joshr/plasma.nix` assumes the same
   monitor arrangement as the original machine: a dock and a status bar on
   `screen = 0`, and one bar on `screen = 1`. (Screen 2 has a desktop but no
   panel, matching the upstream dotfiles.) If this is a different machine,
   adjust or drop the `screen` numbers.
4. **Git identity.** `home/joshr/home.nix` sets
   `programs.git.userEmail = "joshrandall8478@gmail.com"` — change it if
   that's not the identity you want for commits.

## Regenerating hardware-configuration.nix

`nixos-generate-config` scans the running machine — disks, filesystem UUIDs,
kernel modules needed at boot, CPU vendor — and writes a Nix module
describing it. It is machine-specific and must be regenerated per host.

**On a machine that already runs NixOS:**

```bash
sudo nixos-generate-config --show-hardware-config \
  > hosts/gamestation/hardware-configuration.nix
```

`--show-hardware-config` prints to stdout instead of writing into
`/etc/nixos`, which is what you want when the file lives in a repo.

**During a fresh install**, it's generated as part of the install flow below
(step 4), after the target disk is mounted at `/mnt`.

Either way, open the result and sanity-check it — in particular
`boot.initrd.availableKernelModules` (needs your storage controller) and that
`fileSystems` entries point at the right devices.

## Fresh install from the NixOS ISO

Boot the NixOS installer ISO (the minimal or graphical image, either works)
and get a network connection.

**1. Partition and format.** This config uses `systemd-boot`, so the disk
must be GPT with an EFI system partition. Replace `/dev/nvme0n1` with your
actual disk (`lsblk` to find it) — **this erases it**:

```bash
sudo parted /dev/nvme0n1 -- mklabel gpt
sudo parted /dev/nvme0n1 -- mkpart ESP fat32 1MB 1GB
sudo parted /dev/nvme0n1 -- set 1 esp on
sudo parted /dev/nvme0n1 -- mkpart root ext4 1GB 100%

sudo mkfs.fat -F 32 -n boot /dev/nvme0n1p1
sudo mkfs.ext4 -L nixos /dev/nvme0n1p2
```

**2. Mount.**

```bash
sudo mount /dev/disk/by-label/nixos /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/disk/by-label/boot /mnt/boot
```

**3. Clone this repo to where it will live permanently.** Putting it at
`/mnt/etc/nixos` means it survives the reboot and is where you'll edit it
later:

```bash
sudo nix-shell -p git --run \
  'git clone https://github.com/joshrandall8478/nixos /mnt/etc/nixos'
```

**4. Generate the hardware config into the repo.**

```bash
sudo nixos-generate-config --root /mnt --show-hardware-config \
  > /mnt/etc/nixos/hosts/gamestation/hardware-configuration.nix
```

**5. Commit it — this step is not optional.** Flakes only see files that git
tracks. A newly written, untracked `hardware-configuration.nix` is invisible
to the evaluator and the install will fail with a confusing "path does not
exist" error:

```bash
cd /mnt/etc/nixos
sudo nix-shell -p git --run 'git add hosts/gamestation/hardware-configuration.nix'
```

(You don't have to `git commit` — staging is enough for the flake to see it —
but committing keeps things tidy.)

**6. Install.** This builds the whole system, so expect it to take a while
and pull down a lot (NVIDIA driver, Plasma, Steam, VS Code):

```bash
sudo nixos-install --flake /mnt/etc/nixos#gamestation
```

If the installer's Nix complains about experimental features, prefix it:

```bash
sudo NIX_CONFIG="experimental-features = nix-command flakes" \
  nixos-install --flake /mnt/etc/nixos#gamestation
```

`nixos-install` prompts for a **root** password at the end.

**7. Reboot and log in.** `joshr`'s initial password is `changeme` (set in
`modules/nixos/users.nix`). Change it immediately:

```bash
passwd
```

That new password persists — `initialPassword` only applies at account
creation, and editing it later does nothing.

`raiden` is created with the same initial password and wants the same
treatment. It isn't in `wheel`, so do it from that account's own session or
`sudo passwd raiden` from joshr's — see [The accounts](#the-accounts).

**8. Commit `flake.lock`.** The first build generates one, pinning every
input to an exact revision. Commit it:

```bash
cd /etc/nixos
sudo git add flake.lock && sudo git commit -m "Pin flake inputs"
```

This matters more than it looks. `flake.nix` tracks `nixos-unstable`, so
**without a committed lock file every build resolves to whatever nixpkgs
HEAD happens to be that day** — meaning a rebuild that worked yesterday can
fail today because a package got renamed upstream. With the lock committed,
inputs only move when you explicitly run `nix flake update`.

## The XDG_DATA_DIRS workaround (nixpkgs#126590)

`modules/nixos/plasma-xdg-data-dirs.nix` works around a long-standing NixOS
bug where Plasma's Qt wrapper builds an `XDG_DATA_DIRS` of roughly 18 KB with
heavy duplication. Every process in the session inherits it, and since
applications stat every entry on startup looking for `.desktop` files, icons
and mime data, the whole session feels slow to launch things. It's especially
bad on storage with high per-operation latency — a VM disk, for instance.

The module merges all those `share/` directories into one derivation and
points the wrapper at that instead, taking `XDG_DATA_DIRS` down to two
entries. Taken from
[this comment](https://github.com/NixOS/nixpkgs/issues/126590#issuecomment-3194531220).

**It rebuilds `plasma-workspace` from source.** A modified derivation gets no
binary cache hit, so this recompiles on every `nix flake update` that touches
the package — think tens of minutes, more in a VM. If that trade stops being
worth it, drop the import from `hosts/gamestation/configuration.nix`; nothing
else depends on it.

## Rebuilding after changes

Once installed, from the repo (`/etc/nixos` if you followed the above):

```bash
sudo nixos-rebuild switch --flake .#gamestation
```

Useful variants:

```bash
# Build and check it evaluates, without activating:
sudo nixos-rebuild build --flake .#gamestation

# Activate now but don't add a boot entry (reverts on reboot — good for
# testing risky NVIDIA/kernel changes):
sudo nixos-rebuild test --flake .#gamestation

# Update all flake inputs (nixpkgs, home-manager, plasma-manager, dotfiles):
nix flake update

# Update just one input (e.g. after pushing to the dotfiles repo):
nix flake update dotfiles

# Pull a fresh wallhaven toplist. --refresh because Nix caches fetched files
# for an hour; without it you get the copy you already have. See "Wallpapers":
nix flake update --refresh wallhaven-toplist
```

`nix flake update` rewrites `flake.lock` — commit it alongside whatever
prompted the update, so a build that works is a build you can get back to.
If an update breaks something, `git checkout flake.lock` and rebuild.

If a rebuild leaves you with a broken desktop, pick the previous generation
from the boot menu at startup — nothing is destroyed by a bad switch.

## Hosts

Six are defined. Pick one with the flake attribute:

| Host | For | Differences |
|---|---|---|
| `gamestation` | the desk, Plasma | NVIDIA; second-monitor panel; kernel params |
| `laptop` | portable, Plasma | no NVIDIA; power management; single-display panels |
| `gamestation-niri` | the desk, niri | as above, niri + SDDM instead of Plasma |
| `laptop-niri` | portable, niri | as above; no OpenRGB applet at login |
| `server` | headless | no desktop at all; systemd-boot; cron jobs |
| `server-nvidia` | headless, with a card | as `server`, plus the driver and the NVENC/NvFBC patch |

```bash
sudo nixos-rebuild switch --flake .#gamestation
sudo nixos-rebuild switch --flake .#laptop
sudo nixos-rebuild switch --flake .#server
```

The two desk hosts and the two laptop hosts share everything else — the same
modules, the same `home/joshr` profile, the same package set. The two headless
hosts are the outliers and are described below.

### What actually differs

**Panels.** `home/joshr/plasma.nix` is shared. The second-monitor status bar
is gated behind `local.plasma.secondaryMonitorPanel`, which
`home/joshr/gamestation.nix` turns on and `home/joshr/laptop.nix` leaves off.
The dock and the primary status bar are on `screen = 0` and appear on both.
If the laptop gets docked to external displays and you want that bar back,
set the option to `true` in `home/joshr/laptop.nix`.

**Graphics.** `laptop` deliberately does *not* import `modules/nixos/nvidia.nix`
— that module hard-sets `services.xserver.videoDrivers = [ "nvidia" ]` for a
single always-on discrete GPU, which is wrong for integrated-only machines and
wrong for Optimus hybrids. If the laptop does have an NVIDIA chip, read the
comment at the bottom of `hosts/laptop/configuration.nix`: hybrids want PRIME
offload, not that module as written.

**Power.** `modules/nixos/laptop.nix` adds power-profiles-daemon (which backs
Plasma's power-profile switcher and the `Meta+B` shortcut from the dotfiles),
upower, thermald and fstrim.

**Kernel command line.** `hosts/gamestation/kernel-params.nix` is imported by
both desk hosts — it's the same physical box, so the flags belong to the
hardware rather than to either session. It's a separate file because
`hardware-configuration.nix` is regenerated by `nixos-generate-config` and
says so at the top.

| | |
|---|---|
| `acpi_enforce_resources=lax` | lets i2c drivers touch ACPI-claimed regions, which is what OpenRGB needs to see SMBus RGB controllers — RAM and most motherboard headers. Without it OpenRGB finds the GPU and nothing else. It is a guard being switched off, not a feature switched on. |
| `nvidia_drm.fbdev=1` | gives the NVIDIA DRM driver a framebuffer console. `nvidia.nix` already sets the `modeset=1` half; this is the other, and it's what removes the flicker/black VT between bootloader and greeter. |
| `amd_iommu=on` + `iommu=pt` | AMD IOMMU on, in passthrough mode — identity-map the host's own devices so remapping is only paid for devices handed to a guest. Prerequisite for VFIO passthrough; does nothing on its own. |

**RGB.** The OpenRGB tray applet autostarts on the desk and **not** on the
laptop. Nothing sets that per host: `local.openrgb.autostart` defaults to
whether the daemon is enabled, and the daemon comes with
`modules/nixos/gaming.nix`, which the laptop hosts don't import. The laptop has
nothing for it to drive, so all it would buy is a tray icon, a Qt process and a
failed profile load every session — and with no daemon there's no `openrgb` on
PATH there either, since the package arrives with that module.

### The server

`server` doesn't build on `home/joshr/home.nix`. That file is the *desktop*
base — kitty, VS Code, ranger, spicetify, Firefox, Discord, OBS, a cursor
theme, fonts pulled from the dotfiles repo — none of which a headless machine
uses and all of which it would still build. So `home/joshr/server.nix` is
shaped like `home/root/home.nix` instead: `home/common/shell.nix`, git, and
nothing else. Add to it directly rather than reaching for the desktop base.

It takes `base.nix`, `boot.nix`, `cron.nix` and `users.nix`, imports
`development.nix` for real rather than commented out, and pins
`local.boot.loader = "systemd-boot"` — there's no wallpaper to draw, and this
is the machine most likely to reboot unattended.

Get in over SSH. `base.nix` already enables sshd with password auth **off**,
so put a key in place before the first boot or the only way in is a physical
console. Tailscale is enabled there too and still needs `tailscale up` once.

Each host still needs its own hardware scan —
`hosts/laptop/hardware-configuration.nix` is the same placeholder as
gamestation's and must be regenerated on the machine.

### The NVIDIA server

`server-nvidia` is that machine with a card in it, and the difference is one
import: `modules/nixos/nvidia-server.nix`. Same base, same `systemd-boot`,
same three cron jobs, same shell-only home profile — `home/joshr/server.nix`,
reused rather than copied, because a GPU isn't something a home profile has
an opinion about.

```bash
sudo nixos-rebuild switch --flake .#server-nvidia
```

It's a separate host rather than an option on `server` because they're
separate machines: different hardware scan, and a driver that rebuilds
locally on every kernel bump is not something to hand to a box with no card
in it.

The module is the *headless* driver, and deliberately not
`modules/nixos/nvidia.nix` — importing both would leave two definitions of
`hardware.nvidia.package` and stop the rebuild. What it does differently:

| | |
|---|---|
| `nvidiaPersistenced` | on. A desktop always has a client holding the driver open — the display server. A headless card has none, so without this every job pays for a full initialisation and the clocks fall back to idle in between. |
| `powerManagement` | off. The suspend/resume video-memory dance is for a machine that sleeps, and it copies the whole of VRAM to `/tmp` on the way down. |
| `nvidiaSettings` | off. It's a GUI control panel. |
| `enable32Bit` | off. It's there for 32-bit games under Proton. |
| `hardware.nvidia-container-toolkit` | follows `virtualisation.docker.enable`, so importing `development.nix` is also what gives containers the card — `docker run --rm --device=nvidia.com/gpu=all <image> nvidia-smi`. That name is a CDI spec, regenerated by a udev rule; the older `--gpus all` wants a runtime wrapper that only comes with the deprecated `virtualisation.docker.enableNvidia`, so the module turns Docker's own CDI support on instead. |
| the patch | below. |

One thing worth knowing before it confuses you: the module sets
`services.xserver.videoDrivers = [ "nvidia" ]` on a machine with no X.
nixpkgs gates its *entire* NVIDIA module on that list — kernel modules, udev
rules, the libraries under `/run/opengl-driver`, `nvidia-smi`, persistenced.
Leave it out and every `hardware.nvidia.*` setting is silently inert. It does
not enable X; `services.xserver.enable` does that, and it stays false.

#### The patch

GeForce cards carry two limits that are policy rather than silicon:

- **NVENC** refuses more than a handful of simultaneous encode sessions —
  three on older drivers, five on newer ones. The fourth `ffmpeg -c:v
  h264_nvenc` fails with `OpenEncodeSessionEx failed: out of memory (10)`
  while the card sits at 20% utilisation. This is the limit that decides how
  many streams a transcoding server can serve.
- **NvFBC**, whole-framebuffer capture, is refused on anything that isn't a
  Quadro. Sunshine, OBS and the remote desktops fall back to slower paths.

Both are a branch on the card's model inside a userspace library.
[keylase/nvidia-patch](https://github.com/keylase/nvidia-patch) publishes,
per driver version, the bytes to overwrite so the branch isn't taken, and
[icewind1991/nvidia-patch-nixos](https://github.com/icewind1991/nvidia-patch-nixos)
wraps those offsets as a nixpkgs overlay. That's the `nvidia-patch` flake
input; the overlay is applied inside `nvidia-server.nix` rather than in
`flake.nix`, so it reaches the hosts that import the module and no others.

Three consequences of the mechanism:

- **It edits a binary NVIDIA ships**, which is a licence question you're
  answering for yourself. Nothing is redistributed — the `sed` runs on the
  machine, on the driver that machine downloaded.
- **It's keyed on the exact driver version.** nixpkgs gets a new driver
  before the offsets for it are published, so a channel that moves can land
  on a version the table has never seen. That's why `local.nvidia.driver`
  defaults to `"production"` rather than the desktop's `"latest"`, and why a
  version the table doesn't cover **warns and installs unpatched** instead of
  failing. `local.nvidia.patch.required = true` turns that warning into a
  failed rebuild on a host where a capped encoder is an outage.
- **It changes the driver derivation**, so the driver builds on the machine
  instead of coming from `cache.nixos.org` — kernel module included, several
  minutes on a server CPU, repeated on every kernel or driver bump.

It reaches containers too. The CDI spec is generated against
`hardware.nvidia.package`, so the libraries bind-mounted into a container are
the patched ones — a stock Jellyfin or ffmpeg image gets the unlocked encoder
without knowing anything about it.

When a rebuild warns that the offsets are missing, in order of cheapness:

```bash
nix flake update nvidia-patch     # the table is usually days behind a release
                                  # then: local.nvidia.driver = "production";
                                  # or:   local.nvidia.patch.nvenc = false;

# what the table currently knows
nix eval .#nixosConfigurations.server-nvidia.pkgs.nvidia-patch-list.nvenc \
  --apply builtins.attrNames
```

#### Checking it worked

There's no flag to read — the check is to exceed the old limit:

```bash
nix shell nixpkgs#ffmpeg
for i in $(seq 1 8); do
  ffmpeg -f lavfi -i testsrc=size=1920x1080:rate=30 -t 60 \
         -c:v h264_nvenc -f null - &
done
nvidia-smi                        # eight encoders, or a pile of session errors
nvidia-smi -q -d ENCODER_STATS    # what the card thinks it's running
```

`nvtop` is installed for the same question asked continuously — per-process
GPU, VRAM and encoder use.

#### On other hardware

`local.nvidia.open = true` needs Turing (RTX 20xx, GTX 16xx) or newer. Most
of what ends up in a box like this is older — P4, P40, GTX 10xx — and Pascal
has no open kernel module at all, so leaving it on there produces a driver
that won't load. Set it to `false` in
`hosts/server-nvidia/configuration.nix`.

A datacenter or legacy driver that `local.nvidia.driver` can't name goes in
`local.nvidia.package` (e.g. `config.boot.kernelPackages.nvidiaPackages.dc_580`)
rather than in `hardware.nvidia.package` — the module writes that one, and a
second definition either conflicts or, forced, quietly discards the patch.

Nothing that *uses* the card is configured here. Jellyfin, Frigate, a stack
of ffmpeg jobs, ollama — this is the machine they'd run on, and they go in
that host's `configuration.nix` or a module of their own. `ai.nix` is
deliberately not imported; the host file says why.

### Adding another host

1. `mkdir -p hosts/<newhost>`, write a `configuration.nix` importing the
   modules that apply, and generate its `hardware-configuration.nix`.
2. Add a `<newhost> = mkHost { ... }` entry to `nixosConfigurations` in
   `flake.nix`, pointing at that host module and a `homeModules` attrset —
   one entrypoint per account, `root` excepted. See
   [The accounts](#the-accounts).
3. Install with `--flake /mnt/etc/nixos#<newhost>`.


## Updating the dotfiles-derived assets

```bash
nix flake update dotfiles   # pull in changes from joshrandall8478/dotfiles
```

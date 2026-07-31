# fine-ill-try-nix

A NixOS flake for `joshr`'s gaming + development workstation: KDE Plasma 6 on
Wayland, NVIDIA, Steam/ProtonUp-Qt/MangoHud, Docker + Docker Compose,
Flatpak, and a home-manager profile (with
[plasma-manager](https://github.com/nix-community/plasma-manager)) ported
from the [joshrandall8478/dotfiles](https://github.com/joshrandall8478/dotfiles)
chezmoi repo.

## What's here

```
flake.nix                        # inputs: nixpkgs, home-manager, plasma-manager, dotfiles
hosts/gamestation/                # the desk: NVIDIA, multi-monitor
  configuration.nix               # top-level system config, imports the modules below
  hardware-configuration.nix      # PLACEHOLDER — replace with your real hardware scan
hosts/laptop/                     # portable: no NVIDIA, single display
  configuration.nix
  hardware-configuration.nix      # PLACEHOLDER — regenerate on the machine
hosts/server/                     # headless: docker + shell, nothing else
  configuration.nix
  hardware-configuration.nix      # PLACEHOLDER — throws until regenerated
modules/nixos/
  options.nix                     # system-level local.* options
  base.nix                        # nix settings, locale/timezone, fish, base fonts
  desktop.nix                     # SDDM (Wayland) + Plasma 6, portals, audio, Flatpak
  plasma-xdg-data-dirs.nix        # workaround for nixpkgs#126590 (see below)
  nvidia.nix                      # NVIDIA driver + 32-bit graphics for Steam/Proton
  gaming.nix                      # Steam, MangoHud
  virtualisation.nix               # Docker + Docker Compose
  laptop.nix                       # power-profiles-daemon, upower, thermald, fstrim
  users.nix                        # the `joshr` and `root` accounts
home/common/
  options.nix                      # local.* options the entrypoints toggle
  shell.nix                        # fish + starship, shared by joshr and root
  files/                           # starship.toml, smallfetch.jsonc
home/joshr/
  gamestation.nix                  # host entrypoint: enables the 2nd-monitor panel
  laptop.nix                       # host entrypoint: single-display panels
  server.nix                       # host entrypoint: shell only, no desktop
  home.nix                         # packages (Vivaldi, Spotify, Discord, ProtonUp-Qt, ...)
  kitty.nix                        # kitty terminal + zenwritten_dark theme
  vscode.nix                       # VS Code settings + extension list
  plasma.nix                       # KDE Plasma settings/panels/shortcuts (plasma-manager)
  files/                           # DarkObsidianII.colors
home/root/
  home.nix                         # fish + starship only, no desktop
```

## niri (experimental alternative to Plasma)

There are niri variants of both machines. They're separate hosts rather than
a switch inside the existing ones, because Plasma here uses
plasma-login-manager and niri uses SDDM — NixOS won't enable two display
managers at once.

```bash
sudo nixos-rebuild switch --flake .#gamestation-niri   # try niri
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
  lock.nix                    # swayidle timers
  scripts.nix                 # theme/wallpaper/screenshot/session helpers
```

### The bar

Left is workspaces and the focused window title, centre is the clock and
date, right is the tray, volume, network, battery and a session button. Each
group is its own rounded floating pill rather than one long bar.

### Theme switching

20 palettes ship. Greens: `matrix` (bright phosphor, the default), `forest`,
`mint`. Monochrome: `mono` (white on black), `mono-light` (black on white).
Reds: `blackred`, `crimson`. Then `catppuccin-mocha`,
`catppuccin-macchiato`, `catppuccin-frappe`, `rose-pine`, `rose-pine-moon`,
`nord`, `gruvbox`, `dracula`, `tokyo-night`, `everforest`, `kanagawa`,
`solarized`, and `rose-pine-dawn` as the one light option.

`Mod+Shift+T` cycles, `Mod+Ctrl+T` opens a picker (more useful at this count).

The mechanism is worth knowing, because it's what keeps this declarative.
home-manager owns `~/.config/...` as read-only symlinks into the store, so a
script can't rewrite them. Instead every theme is **built ahead of time** as a
complete set of config files, and the only mutable state is one symlink:

```
~/.local/state/niri-theme/active -> /nix/store/...-niri-theme-matrix
```

Each tool is pointed at a file under that symlink: niri via its `include` node
(live-reloaded), waybar started with `-s <active>/waybar.css`, wofi via its
`style` config key, dunst via `services.dunst.configFile`, kitty via an
`include` at the end of `kitty.conf`. `theme-apply` moves the symlink, restarts
waybar and dunst, and sends kitty SIGUSR1 so open terminals repaint in place;
wofi re-reads on each launch. KDE apps read `~/.config/kdeglobals`, which is a
symlink into the active theme — Dolphin picks up a switch when it next starts.

Adding a theme is one attrset in `themes.nix` — the niri fragment, both
stylesheets, the dunstrc, the swaylock palette, the SDDM config and
Dolphin's kdeglobals are all generated from its ten colour roles.

kitty is the exception, because a terminal needs sixteen ANSI colours and ten
semantic roles don't contain them — there's no blue, magenta or cyan in a
palette built for a bar and a focus ring. So each theme also carries an `ansi`
block. Themes with a published terminal palette (Catppuccin, Nord, Gruvbox,
Dracula, Tokyo Night, Rosé Pine, Everforest, Kanagawa, Solarized) use it
verbatim, quirks included — Rosé Pine maps "green" to a teal, Solarized's
bright slots are greys rather than brighter hues. The rest are hand-picked.
Omitting `ansi` is allowed and falls back to a derivation from the ten roles,
but it's flat: blue, magenta and cyan all collapse onto the accent.

The login screen does **not** follow, by default. It uses SDDM's built-in
greeter, because the themed one left the primary display black — see "The
login screen" below. `local.sddm.theme = "astronaut"` turns the themed
version back on, which builds one `sddm-astronaut` instance per palette and
has a system path unit rewrite an SDDM drop-in when the selection changes.
SDDM only reads its config when the greeter starts, so that lands at the next
logout or reboot rather than immediately.

Wallpapers use `awww` (the renamed `swww`) over `~/.local/share/wallpapers`:
`Mod+Shift+W` picks one, `Mod+Ctrl+W` is random. The choice is remembered and
restored at login.

### Keys

| Key | Action |
|---|---|
| `Mod+Return` / `Mod+D` / `Mod+E` / `Mod+B` | terminal, launcher, Dolphin, browser |
| `Mod+Ctrl+E` | ranger, in a terminal |
| `Mod+Q` / `Mod+O` | close window, overview |
| `Mod+H/J/K/L` | focus (arrows also work) |
| `Mod+1..5` | named workspaces |
| `Mod+R` / `Mod+F` / `Mod+V` | preset widths, maximize, float |
| `Print` / `Mod+Shift+S` | region screenshot, annotated in satty |
| `Ctrl+Print` / `Alt+Print` | screen / window (niri's built-ins) |
| `Mod+Escape` / `Mod+Shift+Escape` | lock, session menu |
| `Mod+Shift+I` | stay awake (toggle the sleep inhibitor) |
| `Mod+Shift+T` / `Mod+Ctrl+T` | cycle theme, pick theme |
| `Mod+Shift+W` / `Mod+Ctrl+W` | pick wallpaper, random wallpaper |
| `Mod`+scroll / `Mod+Shift`+scroll | walk windows / workspaces (wheel and touchpad) |

`Mod+Shift+Slash` shows niri's own hotkey overlay.

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

### Lock screen

`swaylock-effects` with a blurred screenshot background, ring colours from
the active theme. `swayidle` dims at 4 minutes, locks at 5, blanks at 10, and
locks before suspend.

The system module adds `security.pam.services.swaylock` — without that PAM
entry swaylock accepts your password and then rejects it, which locks you out
of your own session.

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

**Fish's colours are Base16 Eighties**, on every host and for both `joshr` and
`root`, since they all come through `home/common/shell.nix`.

The palette isn't transcribed into the Nix — it's read at build time out of
the `.theme` file fish itself ships, under
`share/fish/tools/web_config/themes/`, and converted into `set -g` lines. So
it's exactly what `fish_config` would apply, without the state.

That matters because `fish_config theme choose` writes the palette into fish's
*universal* variables, which land in `~/.config/fish/fish_variables`: outside
the store, surviving rebuilds, and drifting per machine and per user — the
opposite of what this repo is for. Setting them globally instead also wins on
fish's scoping rules (local → function → global → universal), so an old
`fish_config` choice still sitting in `fish_variables` is overridden rather
than fought with.

To change it, edit `fishThemeName` in `home/common/shell.nix`. A name fish
doesn't ship fails the build and lists the ones it does, rather than leaving
you with an uncoloured prompt and nothing to go on.

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
2. **NVIDIA generation.** `modules/nixos/nvidia.nix` defaults to the
   proprietary kernel module (`open = false`). If your card is a Turing
   (RTX 20xx) or newer, you can flip that to `true` to use the open kernel
   module instead.
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
  'git clone https://github.com/joshrandall8478/fine-ill-try-nix /mnt/etc/nixos'
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
```

`nix flake update` rewrites `flake.lock` — commit it alongside whatever
prompted the update, so a build that works is a build you can get back to.
If an update breaks something, `git checkout flake.lock` and rebuild.

If a rebuild leaves you with a broken desktop, pick the previous generation
from the systemd-boot menu at startup — nothing is destroyed by a bad switch.

## Hosts

Pick one with the flake attribute:

| Host | For | Differences |
|---|---|---|
| `gamestation` | the desk | NVIDIA module; second-monitor panel |
| `laptop` | portable | no NVIDIA; power management; single-display panels |
| `gamestation-niri` | the desk, niri | niri + SDDM instead of Plasma |
| `laptop-niri` | portable, niri | same, on the laptop |
| `server` | headless | Docker + shell only; no session, no GPU, no fonts |

```bash
sudo nixos-rebuild switch --flake .#gamestation
sudo nixos-rebuild switch --flake .#laptop
sudo nixos-rebuild switch --flake .#server
```

The two workstations share everything else — the same modules, the same
`home/joshr` profile, the same Plasma theming, the same package set.

### The server

`hosts/server/configuration.nix` imports only `base.nix`, `virtualisation.nix`
(Docker + Compose) and `users.nix`. No desktop module, no display manager, no
`nvidia.nix`, no `gaming.nix`.

It sets `local.base.graphical = false`, which drops the parts of `base.nix`
that need a screen — the terminal emulator, cursor theme, icon theme and the
font set. Everything else in there still applies: nix settings, locale, ssh,
tailscale, and the command-line tools (`git`, `vim`, `btop`, `ranger`, `gh`,
`glab`).

The shell is deliberately *identical* to the workstations'. `joshr` and `root`
both get fish as their login shell, the same starship prompt, the same eza
aliases and the same Base16 Eighties palette, because
`home/joshr/server.nix` imports the same `home/common/shell.nix` everything
else does. What it does not import is `home/joshr/home.nix` — that is the
workstation profile (Vivaldi, VS Code, OBS, Lutris, kitty), all of which would
otherwise be built and dragged into a headless closure.

**Its hardware placeholder throws rather than building.** The other hosts ship
placeholders naming devices like `/dev/disk/by-label/nixos`, which evaluate
fine and then leave the machine hanging at `A start job is running for
/dev/disk/by-label/...` — a broken generation you can only escape from the
boot menu. `hosts/server/hardware-configuration.nix` fails at eval with the
command to run instead. The trade is that `nix flake check` will fail on
`server` until you replace it, which is the honest state of affairs: that host
genuinely cannot be built yet.

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

Each host still needs its own hardware scan —
`hosts/laptop/hardware-configuration.nix` is the same placeholder as
gamestation's and must be regenerated on the machine.

### Adding a third host

1. `mkdir -p hosts/<newhost>`, write a `configuration.nix` importing the
   modules that apply, and generate its `hardware-configuration.nix`.
2. Add a `<newhost> = mkHost { ... }` entry to `nixosConfigurations` in
   `flake.nix`, pointing at that host module and a home entrypoint.
3. Install with `--flake /mnt/etc/nixos#<newhost>`.

## I couldn't fully validate this here

This was written in a sandboxed environment without network access to
nixos.org/the Nix binary cache, so **`nix flake check` has not been run**.
Everything was hand-reviewed against the actual plasma-manager and
home-manager module sources (fetched via `raw.githubusercontent.com`) rather
than from memory, but please run `nix flake check` before your first
`nixos-rebuild switch`, and expect to iterate on:

- `hardware-configuration.nix` (definitely needs regenerating, see above)
- exact widget/option names in `plasma.nix` if plasma-manager's schema has
  moved since this was written
- the NVIDIA `open` kernel module flag for your specific GPU

## Updating the dotfiles-derived assets

```bash
nix flake update dotfiles   # pull in changes from joshrandall8478/dotfiles
```

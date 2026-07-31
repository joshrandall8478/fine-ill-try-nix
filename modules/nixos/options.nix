{ lib, ... }:

# System-level `local.*` options.
#
# The home-manager equivalents live in home/common/options.nix; these are the
# ones a NixOS module needs to read, which can't come from there.
{
  options.local.base.graphical = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether this host has a screen attached.

      `base.nix` is shared by every host, and carries a few things that only
      make sense with a display: a terminal emulator, a cursor theme, an icon
      theme, and the font set. False drops them, leaving the parts a headless
      machine actually uses — nix settings, locale, fish, ssh, tailscale, and
      the command-line tools.

      Only the server sets this. It is not a "minimal" switch: the shell
      environment is deliberately identical everywhere, so a server feels the
      same to log into as the desk.
    '';
  };

  options.local.sddm.theme = lib.mkOption {
    type = lib.types.enum [
      "stock"
      "astronaut"
    ];
    default = "stock";
    description = ''
      Which greeter SDDM draws.

      "stock" sets no theme at all, so SDDM uses its own built-in greeter:
      no external theme package, no QML of ours, no runtime state pointing
      at it. Almost nothing in that path is our code, which is exactly why
      it is the default.

      "astronaut" is the themed one — an sddm-astronaut build per palette,
      following the desktop's theme and wallpaper through a system service.

      The themed greeter left the primary display black on this machine.
      That happened under kwin_wayland, under weston and under X11 alike,
      with the display-server layer producing no errors at all: SDDM logged
      "Greeter session started successfully" and the greeter connected. Three
      different display servers failing identically points away from all of
      them and at the one component they share, which is the theme.

      So "stock" is both the fallback and the experiment. If the login screen
      works here, the theme was at fault and can be rebuilt more carefully.
      If it is still black, the cause is somewhere neither the compositor nor
      the theme, and the next thing to suspect is SDDM's multi-monitor
      handling itself.
    '';
  };

  options.local.sddm.wayland = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Run SDDM's Wayland greeter. False uses the X11 greeter instead, which
      starts an X server for the sole purpose of drawing the login screen.

      The niri session is Wayland either way — this is only about the greeter.

      True by default because X11 was tried against the black primary display
      and behaved exactly like the two Wayland compositors, which is what
      ruled the display server out as the cause. It stays an option because
      it is one line to flip and worth a try if the greeter breaks again.
    '';
  };

  options.local.sddm.compositor = lib.mkOption {
    type = lib.types.enum [
      "kwin"
      "weston"
    ];
    default = "kwin";
    description = ''
      Which compositor SDDM's Wayland greeter runs under.

      Back to NixOS's default of kwin. weston was tried against the black
      primary display and made no difference, which — together with X11
      behaving the same way — is what ruled the compositor out.

      Kept as an option because it is a cheap thing to vary if the greeter
      misbehaves again. To leave Wayland entirely, set
      `services.displayManager.sddm.wayland.enable = false` for the X11
      greeter; the niri session stays Wayland regardless.
    '';
  };
}

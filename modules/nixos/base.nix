{ config, lib, pkgs, ... }:

{
  # local.base.graphical gates the display-only parts below.
  imports = [ ./options.nix ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # NVIDIA, Steam, VS Code, Vivaldi, Spotify and Discord are all unfree.
  # This has to be set as a module option so it applies to the system pkgs
  # (and, via home-manager.useGlobalPkgs, to joshr's profile too).
  nixpkgs.config.allowUnfree = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Building the NixOS manual is one of the slower steps of a rebuild and it
  # runs nearly every time. Web docs cover the same ground. Set this back to
  # true if you want `nixos-help` and the offline manual.
  documentation.nixos.enable = false;

  # Defaults to 25; the store is thousands of small fetches, so a higher
  # ceiling helps most on links with latency (which includes a VM going
  # through a host NAT).
  nix.settings.http-connections = 64;

  # The weather widget ported from the dotfiles was configured for Detroit;
  # adjust if this machine lives somewhere else.
  time.timeZone = "America/Detroit";
  i18n.defaultLocale = "en_US.UTF-8";

  networking.networkmanager.enable = true;

  # Fish is the primary interactive shell for this workstation.
  programs.fish.enable = true;

  # Command-line tools, on every host including the server.
  environment.systemPackages =
    (with pkgs; [
      git
      curl
      wget
      vim
      btop
      ranger
      gh
      glab
    ])
    # A terminal emulator, a cursor and an icon theme need a screen to be of
    # any use.
    ++ lib.optionals config.local.base.graphical (with pkgs; [
      kitty
      bibata-cursors
      papirus-icon-theme
    ]);

  programs.vim = {
   enable = true;
   defaultEditor = true;
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
     };
  };

  services.tailscale.enable = true;

  fonts.packages = lib.optionals config.local.base.graphical (
    with pkgs;
    [
      noto-fonts
      noto-fonts-color-emoji
      nerd-fonts.fira-code
      (google-fonts.override { fonts = [ "Poppins" ]; })
    ]
  );
  fonts.fontconfig.defaultFonts.monospace = lib.mkIf config.local.base.graphical [
    "FiraCode Nerd Font Mono"
  ];
}

{ config, lib, pkgs, ... }:

# Headless server: Docker, the shell environment, and nothing else.
#
#   sudo nixos-rebuild switch --flake .#server
#
# What it deliberately does not import:
#
#   desktop.nix / niri.nix   no session, no display manager
#   nvidia.nix               no GPU driver
#   gaming.nix               no Steam
#   laptop.nix               no battery or lid handling
#
# The shell is the same as everywhere else — fish as the login shell for both
# joshr and root, starship, the eza aliases, the Base16 Eighties palette. A
# server you log into constantly is not the place to have a different prompt.
{
  imports = [
    ./hardware-configuration.nix

    ../../modules/nixos/base.nix
    ../../modules/nixos/virtualisation.nix
    ../../modules/nixos/users.nix
  ];

  # Drops the terminal emulator, cursor theme, icon theme and fonts that
  # base.nix carries for the machines with screens. Everything else in there
  # — nix settings, locale, fish, ssh, tailscale, the command-line tools —
  # applies here unchanged.
  local.base.graphical = false;

  networking.hostName = "server";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Do not bump this after the initial install; see the NixOS manual.
  system.stateVersion = "24.11";
}

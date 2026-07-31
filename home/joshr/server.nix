{ ... }:

# joshr's home profile on the server: the shell, and nothing else.
#
# Deliberately does *not* import ./home.nix. That file is the workstation
# profile — Vivaldi, VS Code, OBS, Lutris, kitty, cursor themes — none of
# which a headless machine has any use for, and all of which would be built
# and copied into the closure regardless.
#
# What it shares with every other host is the part that matters over SSH:
# fish as the login shell, starship, the eza aliases and the Base16 Eighties
# palette, all from ../common/shell.nix. Logging into the server should feel
# exactly like logging into the desk.
{
  imports = [
    ../common/options.nix
    ../common/shell.nix
  ];

  home.username = "joshr";
  home.homeDirectory = "/home/joshr";
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;

  # Kept: committing from the server is a normal thing to do.
  programs.git = {
    enable = true;
    settings.user = {
      name = "Joshua Randall";
      email = "josh@joshrandall.net";
    };
  };
}

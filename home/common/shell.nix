{ config, lib, pkgs, ... }:

# Shell environment shared by joshr and root, ported from the dotfiles'
# dot_config/fish/config.fish.tmpl and dot_config/starship.toml.
#
# That template branches on username: root gets an empty fish_greeting while
# everyone else gets the fastfetch one. Reproduced here via
# `local.shell.fastfetchGreeting`.
let
  # The colour scheme, taken from the theme file fish itself ships rather than
  # transcribed here.
  #
  # `fish_config theme choose` writes the palette into fish's *universal*
  # variables, which is exactly the kind of state this repo exists to avoid:
  # it lives in ~/.config/fish/fish_variables, survives a rebuild, and differs
  # per machine and per user. Reading the same .theme file at build time and
  # setting the variables globally gets the identical result declaratively.
  # Globals also win over universals in fish's scoping, so an old
  # `fish_config` choice still sitting in fish_variables is overridden rather
  # than fought with.
  #
  # A .theme file is `name value...` lines with `#` comments. Each becomes a
  # `set -g`, with `--` before the values so entries like `-r` and
  # `--background=…` are read as values and not as options to `set`.
  fishThemeName = "Base16 Eighties";

  fishTheme = pkgs.runCommand "fish-theme-${lib.replaceStrings [ " " ] [ "-" ] (lib.toLower fishThemeName)}.fish" { } ''
    themes="${pkgs.fish}/share/fish/tools/web_config/themes"
    src="$themes/${fishThemeName}.theme"

    # Loud rather than silent: an empty colour file would just look like the
    # theme quietly not applying, which is a miserable thing to debug.
    if [ ! -f "$src" ]; then
      echo "fish theme '${fishThemeName}' not found at $src" >&2
      echo "themes this fish ships:" >&2
      ls "$themes" >&2
      exit 1
    fi

    awk 'NF && $1 !~ /^#/ {
      name = $1
      $1 = ""
      sub(/^[ \t]+/, "")
      printf "set -g %s -- %s\n", name, $0
    }' "$src" > "$out"

    if [ ! -s "$out" ]; then
      echo "parsed no colours out of $src" >&2
      exit 1
    fi
  '';

  # The two branches of the {{ if eq .chezmoi.username "root" }} block in
  # config.fish.tmpl, kept as whole functions so they read the same way.
  fishGreeting =
    if config.local.shell.fastfetchGreeting then
      ''
        function fish_greeting
            fastfetch -c ~/.smallfetch.jsonc
        end
      ''
    else
      ''
        function fish_greeting
        end
      '';
in
{
  home.packages =
    [ pkgs.eza ]
    ++ lib.optional config.local.shell.fastfetchGreeting pkgs.fastfetch;

  programs.fish = {
    enable = true;

    # Upstream config.fish.tmpl sources /usr/share/cachyos-fish-config behind an
    # existence check; that path never exists on NixOS, so it's omitted here.
    interactiveShellInit = ''
      # ${fishThemeName}, generated from fish's own theme file — see above.
      source ${fishTheme}

      # overwrite greeting
      # potentially disabling fastfetch
      ${fishGreeting}
    '';

    functions = {
      ls = {
        description = "eza as ls";
        body = "eza --group-directories-first --icons=auto $argv";
      };
      ll = {
        description = "long list";
        body = "eza -l --group-directories-first --icons=auto --git $argv";
      };
      la = {
        description = "long list, all files";
        body = "eza -la --group-directories-first --icons=auto --git $argv";
      };
      lt = {
        description = "tree view";
        body = "eza --tree --level=2 --icons=auto --group-directories-first $argv";
      };
      lg = {
        description = "long list with git status";
        body = "eza -l --git --git-repos --icons=auto --group-directories-first $argv";
      };
    };
  };

  # Fish is the login shell, but zsh/bash/nushell all get the same prompt.
  #
  # Both halves below are needed. starship's enable*Integration options
  # already default to true (via home.shell.enableShellIntegration), but all
  # they do is set `programs.<shell>.initExtra`-style options — and
  # home-manager only writes a shell's rc file when that shell's own module is
  # enabled. Without these, the zsh/bash/nushell integrations are computed and
  # then dropped on the floor.
  programs.bash.enable = true;
  programs.zsh.enable = true;
  programs.nushell.enable = true;

  programs.starship = {
    enable = true;
    # Stated explicitly rather than leaning on the defaults, so the intent
    # survives a change to home.shell.enableShellIntegration.
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    enableNushellIntegration = true;
  };

  # One config for every shell. starship looks here by default, and
  # home-manager also exports STARSHIP_CONFIG pointing at it.
  xdg.configFile."starship.toml".source = ./files/starship.toml;

  # Only useful when the greeting actually calls fastfetch.
  home.file.".smallfetch.jsonc" = lib.mkIf config.local.shell.fastfetchGreeting {
    source = ./files/smallfetch.jsonc;
  };
}

{
  config,
  lib,
  osConfig,
  pkgs,
  niriTheming,
  ...
}:

# Runtime helpers, all built as store scripts and bound to keys in config.kdl.
#
# The theme switcher only ever moves one symlink (see theming.nix) and then
# nudges each tool to re-read its config. Nothing writes generated content at
# runtime.
let
  inherit (niriTheming)
    themes
    themeDirs
    stateDir
    activeDir
    ;

  # Resolve the greeting from the declarative NixOS user description while
  # the configuration is built. Runtime lock invocations no longer depend on
  # NSS/getent being available or returning a complete GECOS field.
  userDescription =
    lib.attrByPath
      [ config.home.username "description" ]
      config.home.username
      osConfig.users.users;

  userDescriptionWords =
    lib.filter (word: word != "") (lib.splitString " " userDescription);

  firstName =
    if userDescriptionWords == [ ] then
      config.home.username
    else
      builtins.head userDescriptionWords;

  wallpaperDir = "${config.home.homeDirectory}/.local/share/wallpapers";

  # swaylock, patched so the date stacks onto two lines and can't overhang the
  # ring.
  #
  # Upstream draws the date as one row sized at a hardcoded `arc_radius / 6`
  # (render.c), so it grows in exact proportion to the circle and a long date
  # overhangs by the same fraction at every radius. No flag reaches it —
  # `--font-size` sets the clock above it and nothing else is exposed — so a
  # wider `--indicator-radius` cannot buy the room. Without the patch the only
  # options are to shorten the date or narrow the font, and both give something
  # up: the installed fonts are FiraCode and Poppins, with nothing condensed.
  #
  # So the patch teaches it to split `--datestr` on a newline (strftime `%n`)
  # and stack the halves — weekday over month and day. Two short lines fit at
  # full size where one long one didn't: at radius 130 "Wednesday" and
  # "September 24" come out 117px and 156px against chords of 246px and 231px,
  # where the single row was 299px against 240px.
  #
  # It also scales a line down if it still wouldn't fit, bounded by the ring's
  # inner chord at that line's own baseline rather than the diameter, since the
  # date sits below the centre where the circle has already narrowed. With
  # stacking that never triggers for this format — it's the backstop that makes
  # an overhang impossible for any format or locale.
  #
  # Costs a source build of swaylock-effects, which is a small C project and
  # quick. If a nixpkgs bump ever moves those lines the patch will fail to
  # apply, and the fallback is a one-line `--datestr` short enough to fit
  # (`%a, %b %d`).
  swaylock = pkgs.swaylock-effects.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./swaylock-date-fit.patch ];
  });

  # name -> store path, as a shell case statement.
  themeCases = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (n: d: ''${n}) target="${d}" ;;'') themeDirs
  );

  themeNames = lib.concatStringsSep "\n" (lib.attrNames themes);

  # Apply a theme by name: repoint the symlink, then reload consumers.
  #
  #   niri    watches its config and the include target changed, so it
  #           reloads on its own.
  #   waybar  restarted. It's started with `-s <active>/waybar.css`, and a
  #           restart is the only way to be sure the stylesheet is re-read —
  #           SIGUSR2 alone did not reliably repaint.
  #   dunst   restarted; it's launched with `-config <active>/dunstrc`.
  #   swayosd restarted. Same reason as the other two — it's started with
  #           `--style <active>/swayosd.css` and reads that once, at startup.
  #   wofi    nothing — it reads its stylesheet fresh on each launch.
  #   kitty   SIGUSR1, which is kitty's documented "re-read kitty.conf"
  #           signal. It follows the include and repaints open windows, so
  #           running terminals change colour in place.
  #   KDE     a palette-changed signal on the session bus. This is the
  #           mechanism Plasma itself uses when you pick a colour scheme, and
  #           plasma-integration — loaded because qt.platformTheme.name is
  #           "kde", see ./default.nix — listens for it and re-reads
  #           kdeglobals, so an open Dolphin repaints in place. Best effort:
  #           nothing guarantees a given Qt app subscribes, and anything that
  #           doesn't keeps its old palette until relaunched.
  #   VS Code nothing to send. Extensions, and therefore colour themes, are
  #           scanned once at startup; the editor picks the new palette up
  #           the next time it starts.
  #   SDDM    picked up by a system path unit watching the file written
  #           below; applies at the next greeter start. See
  #           modules/nixos/niri.nix.
  themeApply = pkgs.writeShellApplication {
    name = "theme-apply";
    runtimeInputs = with pkgs; [
      libnotify
      systemd
      procps
      dbus
    ];
    text = ''
      name="''${1:-}"
      if [ -z "$name" ]; then
        echo "usage: theme-apply <name>" >&2
        exit 2
      fi

      target=""
      case "$name" in
      ${themeCases}
        *) echo "unknown theme: $name" >&2; exit 1 ;;
      esac

      mkdir -p "${stateDir}"
      ln -sfn "$target" "${activeDir}"
      printf %s "$name" > "${stateDir}/current"

      systemctl --user restart waybar.service || true
      systemctl --user restart dunst.service || true
      systemctl --user restart swayosd.service || true

      # -x so this matches the kitty process and not, say, an editor that
      # happens to have "kitty" in its command line. Non-zero simply means no
      # terminal is open.
      pkill -USR1 -x kitty || true

      # Tell running KDE apps their palette changed, so an open Dolphin
      # repaints instead of waiting to be relaunched.
      #
      # This is KGlobalSettings::notifyChange, the signal Plasma emits when a
      # colour scheme is applied; the two int32 arguments are the change type
      # (0 = PaletteChanged) and an unused argument the signature still
      # requires. It is a plain broadcast — with no subscriber it goes
      # nowhere and costs nothing, which is why it is safe to send blind.
      dbus-send --session --type=signal \
        /KGlobalSettings org.kde.KGlobalSettings.notifyChange \
        int32:0 int32:0 >/dev/null 2>&1 || true

      notify-send -a theme -i preferences-desktop-theme \
        "Theme" "Switched to $name — Some apps may need to be restarted for $name to apply." || true
    '';
  };

  # Cycle to the next theme in the list, wrapping around. Bound to a key.
  themeCycle = pkgs.writeShellApplication {
    name = "theme-cycle";
    runtimeInputs = [ themeApply ];
    text = ''
      themes="${themeNames}"
      current="$(cat "${stateDir}/current" 2>/dev/null || echo "")"

      next="$(echo "$themes" | awk -v cur="$current" '
        { list[NR] = $0 }
        END {
          for (i = 1; i <= NR; i++) if (list[i] == cur) { print list[i % NR + 1]; exit }
          print list[1]
        }')"

      theme-apply "$next"
    '';
  };

  # Jump to a random theme. This is what Mod+Shift+T runs.
  #
  # The current theme is excluded from the draw, so the key always visibly
  # does something. With 29 palettes a plain random pick would land on the
  # one already active about one press in twenty-nine, and a keybind that
  # occasionally appears to do nothing reads as broken rather than as chance.
  #
  # themeCycle above is still built and still on PATH as `theme-cycle`; it
  # just isn't bound to anything any more. This mirrors the wallpaper keys —
  # Mod+Shift+W is random, Mod+Ctrl+W picks — so the two pairs now behave the
  # same way.
  themeRandom = pkgs.writeShellApplication {
    name = "theme-random";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      themeApply
    ];
    text = ''
      current="$(cat "${stateDir}/current" 2>/dev/null || echo "")"

      # -x so a name can't match as a substring of another, -F so nothing in
      # a theme name is read as a pattern. `|| true` because grep exits 1 when
      # it selects nothing, which under pipefail would abort the script.
      pick="$(printf '%s\n' "${themeNames}" \
                | grep -vxF -- "$current" \
                | shuf -n1 || true)"

      # Only reachable if themes.nix defines exactly one theme, in which case
      # there is nothing to switch to.
      [ -n "$pick" ] || exit 0

      theme-apply "$pick"
    '';
  };

  # Pick a theme from a wofi menu.
  themeMenu = pkgs.writeShellApplication {
    name = "theme-menu";
    runtimeInputs = with pkgs; [
      wofi
      themeApply
    ];
    text = ''
      choice="$(printf '%s\n' ${lib.escapeShellArgs (lib.attrNames themes)} | wofi --dmenu --prompt "Theme" --insensitive)"
      [ -n "$choice" ] && theme-apply "$choice"
    '';
  };

  # Wallpaper: awww daemon plus a picker over ~/.local/share/wallpapers.
  # The chosen path is remembered so it can be restored at login.
  wallpaperSet = pkgs.writeShellApplication {
    name = "wallpaper-set";
    runtimeInputs = with pkgs; [
      awww
      libnotify
    ];
    text = ''
      img="''${1:-}"
      [ -z "$img" ] && { echo "usage: wallpaper-set <image>" >&2; exit 2; }
      [ -f "$img" ] || { echo "no such file: $img" >&2; exit 1; }

      # Start the daemon if it isn't already up.
      awww query >/dev/null 2>&1 || { awww-daemon & sleep 0.5; }

      awww img "$img" \
        --transition-type grow \
        --transition-pos center \
        --transition-duration 1 \
        --transition-fps 60

      mkdir -p "${stateDir}"
      printf %s "$img" > "${stateDir}/wallpaper"
    '';
  };
wallpaperMenu = pkgs.writeShellApplication {
  name = "wallpaper-menu";

  runtimeInputs = with pkgs; [
    wofi
    findutils
    coreutils
    imagemagick
    libnotify
    util-linux
    wallpaperSet
  ];

  text = ''
    dir="${wallpaperDir}"
    [ -d "$dir" ] || {
      echo "no wallpaper dir: $dir" >&2
      exit 1
    }

    cache="''${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-menu"
    entries="$(mktemp)"
    images="$(mktemp)"

    mkdir -p "$cache"
    trap 'rm -f "$entries" "$images"' EXIT

    find -L "$dir" -type f \
      \( -iname '*.png' \
      -o -iname '*.jpg' \
      -o -iname '*.jpeg' \
      -o -iname '*.webp' \) \
      -print 2>/dev/null |
      sort > "$images"

    [ -s "$images" ] || {
      echo "no wallpapers found in: $dir" >&2
      exit 1
    }

    # Generate every missing preview. The function scans the wallpaper
    # directory itself so it remains safe when run in the background after
    # this menu invocation exits.
    build_missing_previews() {
      while IFS= read -r img; do
        stamp="$(stat -c '%Y:%s' "$img")"
        key="$(
          printf '%s\0%s' "$img" "$stamp" |
            sha256sum |
            cut -d ' ' -f1
        )"

        thumb="$cache/$key.jpg"
        [ -f "$thumb" ] && continue

        tmp="$cache/.$key.$$.tmp.jpg"

        if magick "$img" -auto-orient \
            -thumbnail '320x180^' \
            -gravity center \
            -extent 320x180 \
            -strip \
            -quality 85 \
            "$tmp" 2>/dev/null; then
          mv -f "$tmp" "$thumb"
        else
          rm -f "$tmp"
        fi
      done < <(
        find -L "$dir" -type f \
          \( -iname '*.png' \
          -o -iname '*.jpg' \
          -o -iname '*.jpeg' \
          -o -iname '*.webp' \) \
          -print 2>/dev/null |
          sort
      )
    }

    # Determine how much work is waiting before deciding which picker layout
    # to show.
    missing_count=0

    while IFS= read -r img; do
      stamp="$(stat -c '%Y:%s' "$img")"
      key="$(
        printf '%s\0%s' "$img" "$stamp" |
          sha256sum |
          cut -d ' ' -f1
      )"

      [ -f "$cache/$key.jpg" ] ||
        missing_count=$((missing_count + 1))
    done < "$images"

    if [ "$missing_count" -ge 10 ]; then
      # Only one invocation may build at a time. The notification happens
      # after acquiring the lock, so opening the picker twice does not produce
      # duplicate builders or duplicate notifications.
      (
        flock -n 9 || exit 0

        notify-send \
          -a wallpaper-menu \
          -i preferences-desktop-wallpaper \
          -t 6000 \
          "Wallpaper picker" \
          "The wallpaper widget is building its cache. This may take a moment." \
          || true

        build_missing_previews
      ) 9> "$cache/.build.lock" &

      # While the cache is cold, open immediately as a plain searchable list.
      # Selection still resolves to the same wallpaper path.
      while IFS= read -r img; do
        rel="''${img#"$dir"/}"
        printf '%s\n' "$rel" >> "$entries"
      done < "$images"

      choice="$(
        wofi --dmenu \
          --prompt "Wallpaper · previews building" \
          --insensitive \
          --no-custom-entry \
          --cache-file /dev/null \
          --width 55% \
          --lines 12 \
          --columns 1 \
          < "$entries" ||
          true
      )"
    else
      # A small amount of missing work is quick enough to finish before
      # opening the normal thumbnail grid.
      build_missing_previews

      while IFS= read -r img; do
        rel="''${img#"$dir"/}"
        stamp="$(stat -c '%Y:%s' "$img")"
        key="$(
          printf '%s\0%s' "$img" "$stamp" |
            sha256sum |
            cut -d ' ' -f1
        )"

        thumb="$cache/$key.jpg"
        preview="$img"
        [ -f "$thumb" ] && preview="$thumb"

        printf 'img:%s:text:%s\n' \
          "$preview" \
          "$rel" >> "$entries"
      done < "$images"

      choice="$(
        wofi --dmenu \
          --prompt "Wallpaper" \
          --insensitive \
          --allow-images \
          --parse-search \
          --no-custom-entry \
          --cache-file /dev/null \
          --width 80% \
          --lines 3 \
          --columns 4 \
          --define=image_size=180 \
          < "$entries" ||
          true
      )"

      # Image-grid mode may return the complete Wofi image escape.
      choice="''${choice#*:text:}"
    fi

    [ -n "$choice" ] && wallpaper-set "$dir/$choice"
  '';
};
 
  wallpaperRandom = pkgs.writeShellApplication {
    name = "wallpaper-random";
    runtimeInputs = with pkgs; [
      findutils
      coreutils
      wallpaperSet
    ];
    text = ''
      dir="${wallpaperDir}"
      [ -d "$dir" ] || exit 0
      pick="$(find -L "$dir" -type f \
                \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) \
              2>/dev/null | shuf -n1)"
      [ -n "$pick" ] && wallpaper-set "$pick"
    '';
  };

  # Restore the remembered wallpaper at login, falling back to a random one.
  wallpaperRestore = pkgs.writeShellApplication {
    name = "wallpaper-restore";
    runtimeInputs = [
      pkgs.awww
      wallpaperSet
      wallpaperRandom
    ];
    text = ''
      awww query >/dev/null 2>&1 || { awww-daemon & sleep 0.5; }
      saved="$(cat "${stateDir}/wallpaper" 2>/dev/null || echo "")"
      if [ -n "$saved" ] && [ -f "$saved" ]; then
        wallpaper-set "$saved"
      else
        wallpaper-random
      fi
    '';
  };

  screenshotDir = "${config.home.homeDirectory}/Pictures/Screenshots";

  # Where the last selected region is remembered. Its own directory rather
  # than niri-theme/ next to the wallpaper: that one is named for the theme
  # state it holds, and a screenshot region isn't part of a theme.
  screenshotStateDir = "${config.home.homeDirectory}/.local/state/niri-screenshot";

  # Annotated region capture: slurp selects, grim captures, satty annotates
  # and writes the result.
  #
  # Plain screen and window captures are bound straight to niri's built-in
  # `screenshot-screen` / `screenshot-window` actions instead — the compositor
  # already knows the exact geometry, so there's nothing for a script to
  # compute and get wrong.
  #
  # Two modes:
  #
  #   screenshot          select a region, remember it, capture it
  #   screenshot last     capture the remembered region again, no selection
  #
  # `last` is for the repeat case — the same panel or window region, shot over
  # and over, where redrawing the selection by hand each time is the tedious
  # part and is also what makes the frames not line up.
  #
  # slurp has no way to *pre-fill* a selection, which is why this is a separate
  # mode rather than "reopen slurp with last time's box ready to nudge". Its
  # `-r` reads boxes on stdin and restricts the selection to them, so feeding
  # it the saved region would let you click that box to accept it but never
  # drag its edges — a worse version of `last`, with an extra click.
  #
  # The saved geometry is grim's own `X,Y WxH`, straight from slurp and passed
  # back to grim unparsed. Nothing here needs to understand it, so nothing here
  # can misparse it.
  screenshot = pkgs.writeShellApplication {
    name = "screenshot";
    runtimeInputs = with pkgs; [
      grim
      slurp
      satty
      wl-clipboard
      libnotify
      coreutils
    ];
    text = ''
      mkdir -p "${screenshotDir}" "${screenshotStateDir}"
      region="${screenshotStateDir}/region"
      mode="''${1:-select}"

      # Month-day-year on a 12-hour clock, matching niri's own
      # `screenshot-path` and every other clock in the session. The cost is
      # that filenames no longer sort chronologically; "%Y-%m-%d_%H-%M-%S"
      # is the string to put back in both places if that matters more.
      stamp="$(date '+%m-%d-%Y_%I-%M-%S-%p')"
      out="${screenshotDir}/screenshot_$stamp.png"

      # grim writes to a file rather than down a pipe into satty, so that a
      # geometry it rejects is catchable here. Piping would only surface as a
      # pipefail exit after satty had already been handed nothing.
      shot="$(mktemp -t screenshot-XXXXXXXX.png)"
      trap 'rm -f "$shot"' EXIT

      geom=""
      if [ "$mode" = "last" ]; then
        geom="$(cat "$region" 2>/dev/null || true)"
      fi

      # A remembered region can stop being valid — a monitor unplugged, or the
      # layout rearranged under it. Fall through to a fresh selection rather
      # than failing, since the point of the key is to be quick.
      if [ -n "$geom" ] && ! grim -g "$geom" "$shot" 2>/dev/null; then
        notify-send -a screenshot \
          "Screenshot" "Last region isn't on screen any more — select a new one."
        geom=""
      fi

      if [ -z "$geom" ]; then
        # Cancelled selection exits non-zero; that's not an error.
        geom="$(slurp -d -b '#0a0e0acc' -c '#39ff14' -s '#39ff1420' -w 2)" || exit 0
        grim -g "$geom" "$shot"

        # Only after grim accepts it, so a region that can't be captured is
        # never the one `last` comes back to.
        printf %s "$geom" > "$region"
      fi

      satty --filename "$shot" \
        --output-filename "$out" \
        --early-exit \
        --copy-command wl-copy

      if [ -f "$out" ]; then
        notify-send -a screenshot -i "$out" "Screenshot" "Saved $(basename "$out")"
      fi
    '';
  };

  # Lock the session. Colours come from the active theme's swaylock.env, so
  # the lock screen follows whatever theme is current.
  #
  # `--color` is the flat colour swaylock paints *underneath* the screenshot
  # background, and it is what you actually see whenever there is no
  # screenshot to draw over it. Its default is white, so leaving it off is
  # what made the lock screen come up blank white with a monitor powered off.
  #
  # `--screenshots` captures each output through wlr-screencopy at lock time,
  # and a capture of an output that is currently blanked fails. In the
  # packaged fork (jirutka's swaylock-effects 1.7.0.0) that failure handler
  # clears `args.screenshots` on the shared state rather than on the one
  # surface that failed, so a single blanked monitor takes the screenshot
  # background away from *every* display — hence full white everywhere, not
  # just on the display that was off. Pointing --color at the theme
  # background turns that fallback into a themed solid colour.
  #
  # It's reachable in normal use because the blank and the lock are
  # independent: Mod+Escape blanks on demand, Mod+Shift+L does both at once,
  # and swayidle blanks at 600s and locks before sleep, so "outputs off" and
  # "now lock" overlap easily.
  #
  # niri's `layout { background-color }` has no bearing on this. That is the
  # backdrop behind windows; swaylock's own surface covers it.
  #
  # The `%n` in `--datestr` is the line break that stacks the weekday over the
  # month and day. Stock swaylock would draw it as a literal newline character
  # in one row; reading it as a break is the patch on `swaylock` above, which
  # is also what keeps the date from overhanging. See the comment there.
  #
  # Thickness moves 8 → 9 with the radius (110 → 130) only to hold the ring's
  # weight steady; at 8 a 130 ring reads visibly thinner than the 110 one did.
  # Which MPRIS player the lock screen is about, as a shell fragment rather
  # than a script of its own.
  #
  # Three separate things on the lock screen ask that question — the label,
  # the cover card and the background behind both — and they have to give the
  # same answer. A cover from one player under a title from another is worse
  # than either alone, and it is exactly what two copies of this loop would
  # drift into the moment one of them was edited.
  #
  # Prefer a playing player. When nothing is actively playing, retain the
  # first paused track so the lock screen still reflects the current media
  # session. Leaves `player` empty when there is nothing to show, which makes
  # every caller here fall back to what it shows without music.
  #
  # Every playerctl call is under a `timeout`, which is not defensive
  # programming for its own sake. These are D-Bus method calls into other
  # desktop applications, and a player that has stopped answering — a hung
  # browser tab is the usual one — blocks its caller for D-Bus's own 25s
  # default. Two of the three callers cannot afford that: one runs on the path
  # that has to lock the screen before the machine suspends, and one runs on
  # Hyprlock's main thread. A second is already far longer than an answer
  # takes.
  pickMprisPlayer = ''
    player=""
    paused_player=""

    while IFS= read -r candidate; do
      [ -n "$candidate" ] || continue

      status="$(
        timeout 1 playerctl --player="$candidate" status 2>/dev/null || true
      )"

      case "$status" in
        Playing)
          player="$candidate"
          break
          ;;
        Paused)
          [ -n "$paused_player" ] || paused_player="$candidate"
          ;;
      esac
    done < <(timeout 1 playerctl --list-all 2>/dev/null || true)

    [ -n "$player" ] || player="$paused_player"
  '';

  # A short-lived MPRIS query for the lock screen.
  #
  # No player means no output, which makes Hyprlock hide the label.
lockNowPlaying = pkgs.writeShellApplication {
  name = "lock-now-playing";

  runtimeInputs = with pkgs; [
    playerctl
    coreutils
    gnused
  ];

  text = ''
    ${pickMprisPlayer}

    [ -n "$player" ] || exit 0

    status="$(
      playerctl --player="$player" status 2>/dev/null || true
    )"

    metadata="$(
      playerctl \
        --player="$player" \
        metadata \
        --format '{{artist}}|||{{title}}' \
        2>/dev/null || true
    )"

    artist="''${metadata%%|||*}"
    title="''${metadata#*|||}"

    # No delimiter means the metadata query failed.
    [ "$metadata" != "$title" ] || exit 0
    [ -n "$title" ] || exit 0

    # playerName is cleaner than the D-Bus instance name, but fall back to the
    # candidate selected above for players that do not expose it properly.
    player_name="$(
      playerctl \
        --player="$player" \
        metadata \
        --format '{{playerName}}' \
        2>/dev/null || true
    )"

    [ -n "$player_name" ] || player_name="$player"

    # Remove instance suffixes such as firefox.instance123 and normalize case.
    source="$(
      printf '%s' "$player_name" |
        tr '[:upper:]' '[:lower:]'
    )"
    source="''${source%%.*}"

    # Browser players normally identify as the browser, but the media URL can
    # reveal recognizable web services.
    media_url="$(
      playerctl \
        --player="$player" \
        metadata xesam:url \
        2>/dev/null || true
    )"

    case "$media_url" in
      *open.spotify.com/* | spotify:*)
        source="spotify"
        ;;
      *music.youtube.com/*)
        source="youtube-music"
        ;;
      *youtube.com/* | *youtu.be/*)
        source="youtube"
        ;;
    esac

    case "$source" in
      spotify | spotifyd)
        player_icon=""
        ;;

      firefox)
        player_icon="󰈹"
        ;;

      chromium | chrome | google-chrome)
        player_icon=""
        ;;

      brave | brave-browser)
        player_icon="󰖟"
        ;;

      vivaldi | vivaldi-stable)
        player_icon="󰖟"
        ;;

      mpv)
        player_icon=""
        ;;

      vlc)
        player_icon="󰕼"
        ;;

      cider | cider-2)
        player_icon=""
        ;;

      youtube | youtube-music)
        player_icon=""
        ;;

      cmus | mpd | rhythmbox | strawberry | amberol)
        player_icon="󰎆"
        ;;

      *)
        player_icon="󰎆"
        ;;
    esac

    case "$status" in
      Playing)
        status_text=""
        ;;
      Paused)
        status_text="  "
        ;;
      *)
        exit 0
        ;;
    esac

    if [ -n "$artist" ]; then
      display="$artist · $title"
    else
      display="$title"
    fi

    # Hyprlock labels support markup, so sanitize media metadata before it
    # reaches the generated label.
    display="$(
      printf '%s' "$display" |
        tr '\r\n' '  ' |
        sed \
          -e 's/[[:space:]][[:space:]]*/ /g' \
          -e 's/&/\&amp;/g' \
          -e 's/</\&lt;/g' \
          -e 's/>/\&gt;/g' |
        cut -c 1-100
    )"

    printf '%s%s  %s\n' \
      "$player_icon" \
      "$status_text" \
      "$display"
  '';
};

  # Where rendered album art lives, and how a track maps onto a file name.
  # Shared by the two scripts below so that neither has to ask the other.
  #
  # Keyed by the cover URL rather than by artist and title, because the URL is
  # what the rendering actually depends on: hashing it gives a name that is
  # safe in a Hyprlang path, stable across locks — the second lock during the
  # same song does no work at all — and different for two albums that happen
  # to share a title.
  albumArtPaths = ''
    art_cache="''${XDG_CACHE_HOME:-$HOME/.cache}/niri/album-art"

    # <cover url> -> the name everything about that cover is filed under.
    art_key() {
      printf '%s' "$1" | sha256sum | cut -c1-32
    }

    # <key> <backdrop|cover|palette|lock|source> -> the file that belongs to
    # it. Takes the key rather than the URL so that a caller which wants
    # several of these pays for the hash once.
    art_path() {
      case "$2" in
        backdrop) printf '%s\n' "$art_cache/$1.backdrop.jpg" ;;
        cover)    printf '%s\n' "$art_cache/$1.cover.png" ;;
        palette)  printf '%s\n' "$art_cache/$1.palette" ;;
        lock)     printf '%s\n' "$art_cache/.$1.lock" ;;
        source)   printf '%s\n' "$art_cache/.$1.source" ;;
      esac
    }
  '';

  # The current track's cover URL, or the empty string when there isn't one.
  currentArtUrl = ''
    ${pickMprisPlayer}

    art_url=""

    if [ -n "$player" ]; then
      art_url="$(
        timeout 1 playerctl --player="$player" metadata mpris:artUrl \
          2>/dev/null || true
      )"
    fi

    # Only the two schemes the fetcher can resolve. `data:` URLs are left out
    # on purpose: a handful of players inline an entire JPEG there, and it
    # would travel through an argv and a cache key to save one local read.
    case "$art_url" in
      http://* | https://* | file://*) ;;
      *) art_url="" ;;
    esac
  '';

  # The wallpaper, behind a fixed, punctuation-free path.
  #
  # Hyprlang reads `path =` to the end of the line and does no quoting or
  # escaping of its own, so a wallpaper named `Sunset #2 (final).png` cannot
  # be pointed at directly — the `#` starts a comment. The symlink is what the
  # config names instead. Prints nothing when there is no usable wallpaper,
  # which leaves Hyprlock on the flat themed `color` underneath.
  hyprlockWallpaper = ''
    hyprlock_wallpaper() {
      local wallpaper extension link

      wallpaper="$(cat "${stateDir}/wallpaper" 2>/dev/null || true)"
      [ -n "$wallpaper" ] || return 0
      [ -f "$wallpaper" ] || return 0

      extension="$(
        printf %s "''${wallpaper##*.}" |
          tr '[:upper:]' '[:lower:]'
      )"

      case "$extension" in
        png | jpg | jpeg | webp) ;;
        *) return 0 ;;
      esac

      link="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hyprlock-wallpaper.$extension"
      ln -sfn -- "$wallpaper" "$link" || return 0

      printf '%s\n' "$link"
    }
  '';

  # Something valid for the cover card to point at when nothing is playing.
  #
  # It has to be an image rather than an empty answer. Hyprlock reads an empty
  # `reload_cmd` result as "keep what you have" — both Background.cpp and
  # Image.cpp return early on it — which is the behaviour worth having while a
  # cover is still rendering, and exactly the wrong one when the music has
  # stopped. So the way to take the card off the screen is to hand Hyprlock a
  # picture of nothing. Sized to match the card so nothing is scaled.
  emptyCover =
    pkgs.runCommand "hyprlock-empty-cover.png"
      {
        nativeBuildInputs = [ pkgs.imagemagick ];
      }
      ''
        magick -size 256x256 xc:none png32:$out
      '';

  # Renders the current track's cover into the two shapes the lock screen
  # wants — a blurred full-screen backdrop that stands in for the wallpaper,
  # and a small framed card to sit above the track name — and reads the
  # colours off it that the rest of the lock screen then wears.
  #
  # Run detached, by `lock-album-art` whenever a track turns up that has never
  # been rendered. It downloads and it runs ImageMagick, so it is the half of
  # this that is allowed to take a second; see the comment on `lock-album-art`
  # for why nothing on Hyprlock's clock may. Takes the cover URL, and works it
  # out from MPRIS when run by hand without one.
  lockAlbumArtFetch = pkgs.writeShellApplication {
    name = "lock-album-art-fetch";

    runtimeInputs = with pkgs; [
      coreutils
      curl
      file
      findutils
      gawk
      imagemagick
      playerctl
      util-linux
    ];

    text = ''
      ${albumArtPaths}

      # The caller usually knows the URL already, having just looked it up to
      # discover the render was missing. Without one, work it out.
      art_url="''${1:-}"

      if [ -z "$art_url" ]; then
        ${currentArtUrl}
      fi

      [ -n "$art_url" ] || exit 0

      # Wherever it came from — MPRIS above, or an argument, which is not
      # necessarily one of ours once this is a command on PATH.
      case "$art_url" in
        http://* | https://* | file://*) ;;
        *)
          echo "lock-album-art-fetch: unsupported cover URL: $art_url" >&2
          exit 2
          ;;
      esac

      key="$(art_key "$art_url")"
      art_backdrop="$(art_path "$key" backdrop)"
      art_cover="$(art_path "$key" cover)"
      art_palette="$(art_path "$key" palette)"

      if [ -f "$art_backdrop" ] && [ -f "$art_cover" ] && [ -f "$art_palette" ]
      then
        exit 0
      fi

      mkdir -p "$art_cache"

      # One worker per track. A second request while the first is still
      # fetching returns rather than queues, because whoever asked is a reload
      # timer that will ask again in a couple of seconds anyway — and two
      # curls racing to write the same cache entry is the one way this could
      # hand Hyprlock a half-written JPEG.
      exec 9>"$(art_path "$key" lock)"
      if ! flock -n 9; then
        exit 0
      fi

      # The holder we just queued behind may have finished the job.
      if [ -f "$art_backdrop" ] && [ -f "$art_cover" ] && [ -f "$art_palette" ]
      then
        exit 0
      fi

      source_file="$(art_path "$key" source)"
      tmp_backdrop="$art_backdrop.tmp"
      tmp_cover="$art_cover.tmp"
      tmp_palette="$art_palette.tmp"
      trap '
        rm -f "$source_file" "$tmp_backdrop" "$tmp_cover" "$tmp_palette"
      ' EXIT

      case "$art_url" in
        file://*)
          # Percent-decoded, because this arrives as a URL: local players hand
          # back file:///tmp/mpv/Some%20Album.jpg for a file whose name has a
          # space in it.
          local_cover="''${art_url#file://}"
          local_cover="$(printf '%b' "''${local_cover//%/\\x}")"

          if [ ! -f "$local_cover" ]; then
            echo "lock-album-art-fetch: no such cover: $local_cover" >&2
            exit 0
          fi

          # Copied rather than read in place: the player owns that file and is
          # free to delete it on the next track, halfway through the render.
          cp -- "$local_cover" "$source_file"
          ;;

        *)
          # Bounded on every axis, because this runs behind a lock screen on
          # whatever network happens to be there, and a cover is never worth
          # waiting on. `--proto-redir` is the one doing real work: without it
          # a redirect could walk this into file:// and feed a local file of
          # its choosing to the renderer below.
          if ! curl --fail --location --silent --show-error \
              --proto '=http,https' --proto-redir '=http,https' \
              --connect-timeout 5 --max-time 20 \
              --max-filesize 16000000 \
              --output "$source_file" "$art_url"; then
            echo "lock-album-art-fetch: could not fetch $art_url" >&2
            exit 0
          fi
          ;;
      esac

      # The metadata was a claim; this is the check. It also keeps ImageMagick
      # away from the formats that have delegates behind them — an
      # image/svg+xml can name external references, and a cover never is one.
      mime="$(file --brief --mime-type -- "$source_file" 2>/dev/null || true)"

      case "$mime" in
        image/png | image/jpeg | image/webp | image/gif | image/bmp | image/avif) ;;
        *)
          echo "lock-album-art-fetch: $art_url is $mime, not a cover" >&2
          exit 0
          ;;
      esac

      # `[0]` throughout: an animated cover is one image to the lock screen,
      # and without it ImageMagick writes one output file per frame and the
      # moves at the bottom find nothing where they expect a render.

      # What colour the cover is, in one pass, before anything is drawn with
      # it. A twelve-colour histogram of a 100px copy is a cheap and honest
      # summary of a sleeve; `album-palette.awk` turns it into the exposure
      # the backdrop is rendered at and the palette the lock screen wears.
      # Alpha is flattened onto black first, so a transparent PNG cover does
      # not report the colour of nothing.
      if ! magick "''${source_file}[0]" \
          -background black -alpha remove -alpha off \
          -resize 100x100^ -gravity center -extent 100x100 \
          -depth 8 -colors 12 \
          -format %c histogram:info:- |
          gawk -f ${./album-palette.awk} > "$tmp_palette"; then
        echo "lock-album-art-fetch: could not read the colours of $art_url" >&2
        exit 0
      fi

      # How far to stop the backdrop down, as a percentage for `-modulate`.
      # Written by the awk above, and re-checked here because it is about to
      # be interpolated into a command line.
      art_brightness="$(
        gawk -F= '$1 == "ART_BRIGHTNESS" { print $2; exit }' "$tmp_palette"
      )"

      case "$art_brightness" in
        "" | *[!0-9]*) art_brightness=100 ;;
      esac

      # The backdrop. Blurring at 512px and scaling the result up costs a
      # fraction of blurring at 2560px and lands in the same place once it is
      # this soft — the detail was on its way out either way. The square crop
      # first is for the players that report a 16:9 thumbnail instead of a
      # cover.
      #
      # The exposure is the one thing here that is about the lock screen
      # rather than about the picture. Hyprlock's own `brightness` in the
      # background block is a fixed multiplier set for the wallpapers, which
      # are chosen and are mostly dark; album covers are neither, and a sleeve
      # that is mostly white leaves every label on this screen sitting on a
      # pale wash, unreadable. So the cover is exposed *to* a target instead
      # of by a constant — see the reasoning in album-palette.awk — with a
      # little saturation put back to stop the dimming going muddy.
      if ! magick "''${source_file}[0]" \
          -auto-orient -strip -colorspace sRGB \
          -resize 512x512^ -gravity center -extent 512x512 \
          -blur 0x8 \
          -modulate "$art_brightness,110" \
          -filter Lanczos -resize 2560x1440^ \
          -gravity center -extent 2560x1440 \
          -quality 92 "jpg:$tmp_backdrop"; then
        echo "lock-album-art-fetch: could not render a backdrop from $art_url" >&2
        exit 0
      fi

      # The card: the cover at 200px with soft corners, a hairline edge to
      # lift it off whatever it is sitting on, and a shadow under it, on a
      # 256px transparent canvas that leaves the shadow room to fall.
      #
      # All of it baked into the PNG rather than left to Hyprlock's own
      # `rounding` and `border_size`, for one reason: when the music stops the
      # widget is pointed at a transparent image, and a Hyprlock border would
      # draw a neat empty box around the nothing.
      if ! magick "''${source_file}[0]" \
          -auto-orient -strip -colorspace sRGB \
          -resize 200x200^ -gravity center -extent 200x200 -alpha set \
          \( -size 200x200 xc:none -fill white \
             -draw 'roundrectangle 0,0 199,199 18,18' \) \
          -compose DstIn -composite \
          \( -size 200x200 xc:none -fill none \
             -stroke 'rgba(255,255,255,0.28)' -strokewidth 2 \
             -draw 'roundrectangle 1,1 198,198 17,17' \) \
          -compose Over -composite \
          \( +clone -background black -shadow 50x8+0+4 \) \
          +swap -background none -layers merge +repage \
          -gravity center -background none -extent 256x256 \
          "png32:$tmp_cover"; then
        echo "lock-album-art-fetch: could not render a cover from $art_url" >&2
        exit 0
      fi

      # Into place only now, and one rename each, so the reload timer either
      # finds the old answer or a finished new one and never a partial file.
      # The palette goes last on purpose. `lock-session` takes its colours
      # from it and its pictures from the other two, so a palette on disk has
      # to mean the pictures are already there — otherwise a lock landing in
      # this gap would wear a cover it is not showing.
      mv -f "$tmp_backdrop" "$art_backdrop"
      mv -f "$tmp_cover" "$art_cover"
      mv -f "$tmp_palette" "$art_palette"

      # Keep the cache bounded. Thirty tracks each way is a few megabytes and
      # covers an evening of skipping; past that it is a song you are not
      # about to lock the screen on.
      prune_art() {
        find "$art_cache" -maxdepth 1 -type f -name "$1" -printf '%T@ %p\n' |
          sort -rn |
          tail -n +31 |
          cut -d ' ' -f2- |
          xargs -r rm -f
      }

      prune_art '*.backdrop.jpg' || true
      prune_art '*.cover.png' || true
      prune_art '*.palette' || true

      # And the lock files, which are empty and never numerous, but are
      # otherwise the one thing here that only accumulates. A week is far
      # longer than any of them is held, so nothing in use is removed.
      find "$art_cache" -maxdepth 1 -type f -name '.*.lock' -mtime +7 -delete ||
        true
    '';
  };

  # What Hyprlock asks, every few seconds, for the path it should be showing.
  # Prints one path and returns: it never downloads and never renders.
  #
  # That restraint is the whole design. Hyprlock runs `reload_cmd` through
  # `spawnSync` from a timer callback on its main thread (Background.cpp,
  # Image.cpp), so every millisecond spent in here is a millisecond the lock
  # screen is not drawing, and a cover fetched inline over a hotel wifi would
  # freeze the clock and the password field for as long as curl felt like
  # taking. A track that has no render yet is handed to
  # `lock-album-art-fetch` in a detached process and collected on a later
  # tick instead.
  lockAlbumArt = pkgs.writeShellApplication {
    name = "lock-album-art";

    runtimeInputs = with pkgs; [
      coreutils
      playerctl
      util-linux
    ];

    text = ''
      ${albumArtPaths}
      ${hyprlockWallpaper}

      mode="''${1:-}"

      case "$mode" in
        backdrop | cover | palette | all) ;;
        *)
          echo "usage: lock-album-art backdrop|cover|palette|all" >&2
          exit 2
          ;;
      esac

      ${currentArtUrl}

      key=""
      [ -z "$art_url" ] || key="$(art_key "$art_url")"

      # One answer, for one of the three things a lock screen takes from a
      # cover. Prints nothing when there is nothing to say.
      answer() {
        local want="$1" rendered

        if [ -n "$key" ]; then
          rendered="$(art_path "$key" "$want")"

          if [ -f "$rendered" ]; then
            printf '%s\n' "$rendered"
            return 0
          fi
        fi

        case "$want" in
          backdrop)
            # The wallpaper is the answer whenever the cover isn't: no music,
            # a cover that could not be fetched, or one still rendering.
            # Hyprlock crossfades between whatever two paths it is handed, so
            # the swap reads as a transition in both directions.
            hyprlock_wallpaper
            ;;

          cover)
            if [ -z "$art_url" ]; then
              printf '%s\n' "${emptyCover}"
            fi

            # With a cover on the way, print nothing at all. Hyprlock keeps
            # what it has, which holds the last cover on screen for the second
            # the new one takes rather than blinking through the empty one.
            ;;

          palette)
            # And nothing to fall back to here: no palette means the lock
            # screen keeps the theme's own colours, which is what the caller
            # does with an empty answer anyway.
            ;;
        esac
      }

      # Anything missing starts the render, once, however many answers are
      # being asked for. Every descriptor is redirected before the fork
      # because Hyprlock is reading this command's stdout, and a pipe left
      # open in the worker would keep it waiting on the download after all the
      # trouble taken not to.
      if [ -n "$key" ]; then
        for want in backdrop cover palette; do
          if [ ! -f "$(art_path "$key" "$want")" ]; then
            setsid -f ${lib.getExe lockAlbumArtFetch} "$art_url" \
              </dev/null >/dev/null 2>&1 || true
            break
          fi
        done
      fi

      case "$mode" in
        # Everything `lock-session` needs, in one run. It asks on the path
        # that has to have the screen locked before the machine suspends, and
        # three separate runs would be three separate rounds of MPRIS calls
        # for one question about one track.
        all)
          for want in backdrop cover palette; do
            value="$(answer "$want")"
            [ -z "$value" ] || printf '%s=%s\n' "$want" "$value"
          done
          ;;

        *)
          answer "$mode"
          ;;
      esac
    '';
  };

  # Switch the current seat to SDDM without unlocking or ending this session.
  #
  # Kept below `switch-user` as a low-level primitive: the normal desktop
  # action locks first, while Hyprlock can call this directly because the
  # session is already locked.
  switchToGreeter = pkgs.writeShellApplication {
    name = "switch-to-greeter";
    runtimeInputs = [ pkgs.dbus ];
    text = ''
      seat="''${XDG_SEAT_PATH:-/org/freedesktop/DisplayManager/Seat0}"

      exec dbus-send --system --print-reply \
        --dest=org.freedesktop.DisplayManager \
        "$seat" \
        org.freedesktop.DisplayManager.Seat.SwitchToGreeter
    '';
  };

  # Exposed deliberately on the lock screen. Suspending leaves Hyprlock in
  # place, so waking the machine returns to the same locked session.
  suspendSystem = pkgs.writeShellApplication {
    name = "suspend-system";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      exec systemctl suspend
    '';
  };

  lockSession = pkgs.writeShellApplication {
  name = "lock-session";

  runtimeInputs = [
    pkgs.hyprlock
    pkgs.coreutils
    pkgs.gawk
    pkgs.glibc.bin
    pkgs.util-linux
    swaylock
  ];

  text = ''
    # This blocks until the session is unlocked. Nothing on a timer should
    # call it directly — see `lock-now` below, which is what swayidle, the
    # keybinds and the bar all go through.

    grace=0

    while [ "$#" -gt 0 ]; do
      case "$1" in
        # Seconds during which any input dismisses the lock without a
        # password. Zero by default, because every deliberate route to the
        # lock — the keybinds, the bar, the session menu, switch-user,
        # before-sleep, `loginctl lock-session` — means "lock it", and on
        # those a grace window is one in which the very act of waking the
        # screen to check that it locked would unlock it again.
        #
        # The one caller that wants a nonzero value is the idle timer in
        # lock.nix, which passes `--grace 2`: there the lock fired on its own
        # while you were away from the desk, and the two seconds cover walking
        # back into it as it fires.
        --grace)
          grace="''${2:-}"
          case "$grace" in
            "" | *[!0-9]*) echo "lock-session: --grace wants a number" >&2; exit 2 ;;
          esac
          shift 2
          ;;
        *)
          echo "usage: lock-session [--grace <seconds>]" >&2
          exit 2
          ;;
      esac
    done

    # One locker at a time, held for as long as this process lives.
    #
    # Without it a second lock request — the lid closing onto an already
    # locked session, a stray Mod+L, before-sleep arriving after the idle
    # timer — starts a second hyprlock, which cannot take the session lock
    # and exits non-zero, and the fallback below then reads that as "hyprlock
    # is broken" and layers a swaylock on top of the working lock screen.
    #
    # An open file descriptor rather than a PID file or a process-name match:
    # the kernel drops the lock when the process dies however it dies, so
    # there is no stale state to clean up, and it survives the `exec swaylock`
    # at the bottom (fd 9 is not close-on-exec) so the fallback holds it too.
    #
    # `lock-now` tests the same file, which is how it knows the locker is up.
    lockfile="''${XDG_RUNTIME_DIR:-/tmp}/lock-session.lock"
    exec 9>"$lockfile"
    if ! flock -n 9; then
      exit 0
    fi

    # shellcheck disable=SC1091
    if [ -r "${activeDir}/swaylock.env" ]; then
      . "${activeDir}/swaylock.env"
    fi

    : "''${LOCK_BG:=0a0e0a}"
    : "''${LOCK_ACCENT:=39ff14}"
    : "''${LOCK_ACCENT_DIM:=1f8b0d}"
    : "''${LOCK_FG:=c8f5c8}"
    : "''${LOCK_FG_DIM:=5c7a5c}"
    : "''${LOCK_ERR:=ff5555}"
    : "''${LOCK_WARN:=f5d76e}"

    runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    config="$runtime_dir/hyprlock-niri.conf"

    mkdir -p "$runtime_dir"
    umask 077

    # The first name is baked into this script from
    # users.users.<name>.description during Nix evaluation. Every route to the
    # lock screen therefore generates the same greeting.
    first_name=${lib.escapeShellArg firstName}

    # Remove characters that could break the generated Hyprlang line.
    first_name="$(printf %s "$first_name" | tr -d '\r\n{}"#')"
    [ -n "$first_name" ] || first_name="${lib.escapeShellArg config.home.username}"

    ${hyprlockWallpaper}

    # Stale links from an earlier lock, before hyprlock_wallpaper re-creates
    # the one that matches the wallpaper as it is now.
    rm -f "$runtime_dir"/hyprlock-wallpaper.*

    # The background is the album cover of whatever is playing, and the
    # wallpaper when nothing is. This is only its first frame: the reload
    # command in the config below asks the same question every few seconds,
    # which is what makes the lock screen follow the music while it sits
    # there locked. Asking now also starts the render for a track that has
    # never been locked on, so the answer is usually ready by that first tick.
    #
    # Under a `timeout` because this is the path that has to have the screen
    # locked before the machine suspends. lock-album-art bounds its own MPRIS
    # queries and should never come near this, and if it does, everything
    # below falls back to what it would show without music.
    backdrop=""
    cover=""
    palette=""

    while IFS='=' read -r kind value; do
      case "$kind" in
        backdrop) backdrop="$value" ;;
        cover)    cover="$value" ;;
        palette)  palette="$value" ;;
      esac
    done < <(timeout 2 ${lib.getExe lockAlbumArt} all || true)

    if [ -z "$backdrop" ]; then
      backdrop="$(hyprlock_wallpaper)"
    fi

    path_line=""

    if [ -n "$backdrop" ]; then
      path_line="    path = $backdrop"
    fi

    # The cover card above the track name. Always a real image, so the widget
    # has something valid to point at from the first frame: a transparent one
    # when nothing is playing, or when the cover is still rendering and the
    # reload timer is about to bring it in.
    if [ -z "$cover" ]; then
      cover="${emptyCover}"
    fi

    # And the album's own colours over the theme's, when the cover had a
    # colour confident enough to take. `album-palette.awk` decides that and
    # writes the file. `LOCK_ERR` and `LOCK_WARN` are not in the list below
    # and keep the theme's values: an error is red and a caps-lock warning is
    # yellow whatever happens to be playing.
    #
    # These colours are fixed for the life of the lock screen even though the
    # pictures behind them are not. Hyprlock can be told to re-read a path
    # while it is up, through `reload_cmd`, but there is no equivalent for a
    # colour anywhere in its config — and of the things asked for here, the
    # password field's is the one that could not be faked with markup in a
    # label. Recolouring only what could be recoloured would leave a lock
    # screen half in one album's colours and half in another's, which is worse
    # than a lock screen that simply wears the track it was locked on.
    #
    # Read rather than sourced. The file is ours and holds nothing but
    # assignments, but it is a cache file rather than a store path, and this
    # is the script that stands between a locked session and the desktop.
    if [ -n "$palette" ] && [ -r "$palette" ]; then
      while IFS='=' read -r key value; do
        case "$value" in
          [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
          *) continue ;;
        esac

        case "$key" in
          LOCK_BG)         LOCK_BG="$value" ;;
          LOCK_ACCENT)     LOCK_ACCENT="$value" ;;
          LOCK_ACCENT_DIM) LOCK_ACCENT_DIM="$value" ;;
          LOCK_FG)         LOCK_FG="$value" ;;
          LOCK_FG_DIM)     LOCK_FG_DIM="$value" ;;
        esac
      done < "$palette"
    fi

    # Read straight for the swaylock fallback at the bottom, which stays on
    # the wallpaper: that is the locker of last resort, and routing the album
    # art through it too would put one more thing that can fail on the path
    # that only runs because something already has.
    wallpaper="$(cat "${stateDir}/wallpaper" 2>/dev/null || true)"

    cat > "$config" <<EOF
    general {
        # The session controls below are clickable, so keep the pointer
        # visible instead of making users hunt for it by echolocation.
        hide_cursor = false
        ignore_empty_input = true
        immediate_render = true
        text_trim = true
        fail_timeout = 1800
    }

    auth {
        pam:enabled = true
        pam:module = hyprlock
    }

    animations {
        enabled = true

        bezier = graceful, 0.22, 1, 0.36, 1

        animation = fadeIn, 1, 2.4, graceful
        animation = fadeOut, 1, 2.0, graceful
        animation = inputFieldDots, 1, 2.8, graceful
        animation = inputFieldColors, 1, 2.2, graceful
        animation = inputFieldFade, 1, 2.2, graceful
    }

    background {
        monitor =
    $path_line
        color = rgb($LOCK_BG)

        blur_passes = 1
        blur_size = 3

        noise = 0.05
        contrast = 1.0
        brightness = 0.64
        vibrancy = 0.16
        vibrancy_darkness = 0.12

        # Follows the music. lock-album-art answers with the blurred cover of
        # whatever is playing and with the wallpaper when nothing is, so the
        # background changes with the track and comes back to the wallpaper
        # when the music stops. The crossfade is what keeps that from
        # registering as a flicker.
        #
        # Three seconds rather than one, because a widget with no monitor is
        # built once per output and each copy runs its own reload command on
        # Hyprlock's main thread — on the desk that is three backgrounds and
        # three covers all asking. All it costs is a track change landing a
        # beat later than it could.
        reload_time = 3
        reload_cmd = ${lib.getExe lockAlbumArt} backdrop
        crossfade_time = 0.9
    }

    # Quiet clock above the greeting.
    label {
        monitor =
        text = \$TIME12
        color = rgba(''${LOCK_FG}dd)
        font_size = 72
        font_family = Poppins

        position = 0, 125
        halign = center
        valign = center
    }

    # The account's configured full name supplies this first name.
    label {
        monitor =
        text = Welcome, $first_name
        color = rgb($LOCK_FG)
        font_size = 40
        font_family = Poppins

        position = 0, 35
        halign = center
        valign = center
    }

    # The cover of whatever is playing, sitting just above the track name.
    # The rounded corners, the hairline edge and the shadow are all in the
    # image rather than in the options below, which is what lets nothing
    # playing be a transparent image and leave no empty frame behind.
    image {
        monitor =
        path = $cover

        size = 256
        rounding = 0
        border_size = 0

        reload_time = 3
        reload_cmd = ${lib.getExe lockAlbumArt} cover

        position = 0, 184
        halign = center
        valign = bottom
    }

    # The active MPRIS track. This remains blank when there is no recognized
    # media session, so the lock screen does not grow an empty placeholder.
    label {
        monitor =
        text = cmd[update:1500] ${lib.getExe lockNowPlaying}

        color = rgba(''${LOCK_FG}cc)
        font_size = 18
        font_family = FiraCode Nerd Font
        text_align = center

        position = 0, 158
        halign = center
        valign = bottom
    }
    # One low, horizontal password field. Dots begin at the left and animate
    # individually so typing travels across the line rather than accumulating
    # as a static cluster in its center.
    input-field {
        monitor =

        size = 620, 58
        outline_thickness = 2
        rounding = 18

        dots_size = 0.15
        dots_spacing = 0.42
        dots_center = true
        dots_rounding = -1
        dots_text_format = •

        outer_color = rgba(''${LOCK_ACCENT_DIM}dd)
        inner_color = rgba(''${LOCK_BG}d6)
        font_color = rgb($LOCK_FG)
        font_family = FiraCode Nerd Font

        fade_on_empty = false
        hide_input = false
        placeholder_text = Password

        check_color = rgb($LOCK_ACCENT)
        check_text = Unlocking…

        fail_color = rgb($LOCK_ERR)
        fail_text = <i>\$FAIL</i>

        capslock_color = rgb($LOCK_WARN)

        position = 0, 72
        halign = center
        valign = bottom
    }

    # Lightweight session actions, styled like the clock rather than as
    # boxed controls. Hyprlock still shows the normal pointer over each label,
    # but there is no custom color, scaling, or opacity hover effect.
    label {
        monitor =
        text = 󰍃 Switch user
        color = rgba(''${LOCK_FG}cc)
        font_size = 15
        font_family = FiraCode Nerd Font

        position = -78, 18
        halign = center
        valign = bottom

        onclick = ${lib.getExe switchToGreeter}
    }

    label {
        monitor =
        text = 󰒲 Sleep
        color = rgba(''${LOCK_FG}cc)
        font_size = 15
        font_family = FiraCode Nerd Font

        position = 78, 18
        halign = center
        valign = bottom

        onclick = ${lib.getExe suspendSystem}
    }
    EOF

    # Hyprlock blocks until the session is unlocked. A nonzero exit here
    # means it failed to initialize, not merely that a password was wrong.
    if hyprlock --config "$config" --grace "$grace"; then
      exit 0
    fi

    # Last-resort locker. Even a Hyprlock regression must not leave the
    # session exposed.
    image_args=()
    if [ -n "$wallpaper" ] && [ -f "$wallpaper" ]; then
      image_args=(
        --image ":$wallpaper"
        --scaling fill
      )
    fi

    exec swaylock \
      "''${image_args[@]}" \
      --color "$LOCK_BG" \
      --clock \
      --indicator \
      --indicator-radius 130 \
      --indicator-thickness 9 \
      --effect-blur 8x5 \
      --effect-vignette 0.4:0.4 \
      --datestr "%A%n%B %d" \
      --timestr "%I:%M %p" \
      --font "FiraCode Nerd Font" \
      --ring-color "$LOCK_ACCENT_DIM" \
      --ring-clear-color "$LOCK_WARN" \
      --ring-ver-color "$LOCK_ACCENT" \
      --ring-wrong-color "$LOCK_ERR" \
      --key-hl-color "$LOCK_ACCENT" \
      --bs-hl-color "$LOCK_ERR" \
      --inside-color "$LOCK_BG"cc \
      --inside-clear-color "$LOCK_BG"cc \
      --inside-ver-color "$LOCK_BG"cc \
      --inside-wrong-color "$LOCK_BG"cc \
      --line-color 00000000 \
      --separator-color 00000000 \
      --text-color "$LOCK_FG" \
      --text-clear-color "$LOCK_FG" \
      --text-ver-color "$LOCK_FG" \
      --text-wrong-color "$LOCK_ERR" \
      --fade-in 0.2 \
      --grace "$grace"
  '';
};

  # Lock, and come back as soon as the lock is up rather than when it ends.
  #
  # This exists because of one line in swayidle: home-manager passes it `-w`
  # by default (`services.swayidle.extraArgs`), and with `-w` swayidle's
  # `cmd_exec` does a single fork and then `waitpid()`s the command from
  # inside its Wayland event loop instead of double-forking and returning
  # (main.c). Pointing a timeout straight at `lock-session`, which blocks
  # until you type your password, therefore froze the whole idle timer at the
  # moment it locked: the 600s `power-off-monitors` never fired, so the
  # screen locked and then stayed lit indefinitely. The `lock` and
  # `before-sleep` events had the same problem — a lid close on mains, or a
  # suspend, wedged the timer until the session was unlocked again.
  #
  # `-w` is worth keeping, though, and that's why this is a wrapper rather
  # than an `extraArgs = [ ]`: it is what makes swayidle hold logind's sleep
  # delay lock until `before-sleep` has returned, which is the guarantee that
  # the machine never suspends before the locker is on screen. So the command
  # has to return quickly *and* not before the lock has taken — both of which
  # this does.
  #
  # Idempotent, so every route to the lock can call it: already locked is a
  # silent success rather than a second locker.
  lockNow = pkgs.writeShellApplication {
    name = "lock-now";
    runtimeInputs = with pkgs; [
      coreutils
      util-linux
      lockSession
    ];
    text = ''
      lockfile="''${XDG_RUNTIME_DIR:-/tmp}/lock-session.lock"

      # True once lock-session holds the lock. Testing it in a subshell takes
      # the lock only for the life of that subshell, so this never races the
      # real holder — and `flock -n` failing is the *positive* answer here,
      # hence the negation.
      locked() { ! ( flock -n 9 ) 9>"$lockfile"; }

      if locked; then
        exit 0
      fi

      # setsid so the locker outlives this script and its caller. swayidle
      # reaps the `sh -c` that ran us and nothing else; niri's `spawn` and
      # waybar's `on-click` behave the same way.
      setsid lock-session "$@" &

      # Bounded wait for the locker to come up. Six seconds is far longer than
      # hyprlock needs and still short enough that a locker which never starts
      # can't hold a suspend past logind's own five-second inhibit delay.
      up=0
      for _ in $(seq 1 60); do
        if locked; then
          up=1
          break
        fi
        sleep 0.1
      done

      if [ "$up" = "0" ]; then
        echo "lock-now: no locker came up within 6s" >&2
        exit 1
      fi

      # The lock file says lock-session is *running*, which is a fraction of a
      # second before hyprlock has claimed the session lock and drawn. There
      # is no readiness signal to wait on instead — hyprlock has no IPC, and a
      # Wayland session lock isn't visible to logind — so this is a settle,
      # honestly a guess, and deliberately a generous one relative to what it
      # is covering. It matters for the two callers that do something to the
      # screen straight afterwards: `lock-blank` powers the monitors off, and
      # `switch-user` hands the seat to the greeter.
      sleep 0.3
    '';
  };

  # Lock and turn the displays off, in one key.
  #
  # The two halves are independent mechanisms — the lock is a Wayland session
  # lock, the blank is niri's own DPMS over IPC — so this is the only thing
  # that does both, and it is what Mod+Shift+L runs. Any input powers the
  # monitors back on and lands on the lock screen, exactly as the 600s idle
  # blank does.
  #
  # `--grace 0` is the default `lock-session` already uses, and is passed here
  # explicitly because this key is the clearest case for it: it means "I am
  # leaving", and it blanks the screen, so the very act of waking the display
  # to check that it locked would fall inside any grace window. Only the idle
  # timer in lock.nix asks for a nonzero grace.
  lockBlank = pkgs.writeShellApplication {
    name = "lock-blank";
    runtimeInputs = with pkgs; [
      niri
      lockNow
    ];
    text = ''
      # lock-now returns once the locker is up and settled, so there is
      # nothing to sleep on here — see the comment on its settle.
      lock-now --grace 0

      niri msg action power-off-monitors
    '';
  };

  # Dismiss the lock screen without asking for the password.
  #
  # Wired to swayidle's `unlock` event (lock.nix), which is logind's Unlock
  # signal on this session. The only thing that sends it here is SDDM: with
  # Users.ReuseSession (modules/nixos/niri.nix) a login for someone who is
  # already logged in calls UnlockSession and then ActivateSession on the
  # session they left behind, rather than starting a second one. Without this
  # you land back on your own lock screen having just typed your password into
  # the greeter, and type it again.
  #
  # It is not a hole in the lock. logind takes Unlock only from the session's
  # own user or from root — the polkit check names the session owner as the
  # user who may skip it — so the two ways to reach this are code already
  # running as you, and SDDM's daemon, which sends it having just put you
  # through PAM.
  #
  # SIGUSR1 is hyprlock's own unlock path (`enqueueUnlock`), the same one a
  # correct password takes, so the Wayland session lock is released properly.
  # Killing the locker would not unlock anything: under ext-session-lock a
  # locker that dies without releasing the lock leaves the compositor locked
  # with nothing left to type into, which is the protocol working as designed
  # rather than a bug to work around.
  #
  # Nothing here for swaylock, which `lock-session` only runs when hyprlock
  # failed to start. It has no unlock signal, so a session sitting on the
  # fallback locker still wants the password — the right direction for a
  # fallback to fail in.
  unlockSession = pkgs.writeShellApplication {
    name = "unlock-session";
    runtimeInputs = with pkgs; [
      procps
      coreutils
    ];
    text = ''
      if ! pkill -USR1 -x -u "$(id -u)" hyprlock; then
        echo "unlock-session: no hyprlock running; nothing to unlock" >&2
      fi
    '';
  };

  # Run a command only while this session is the one on the screen.
  #
  #     when-active brightness dim 20
  #
  # More than one person can be logged in at once — `switch-user` hands the
  # seat to the greeter and deliberately leaves the old session running — and
  # every one of those sessions has its own swayidle counting. niri does not
  # stop the idle clock for a session that has been switched away from:
  # pausing a session suspends libinput and DRM and nothing else, so the
  # compositor simply sees no input, decides you are idle, and the timers in
  # lock.nix fire in a session nobody is looking at.
  #
  # Locking such a session is right. Dimming and blanking it are not, because
  # neither one is confined to the session that asked for it: brightness goes
  # out over DDC/CI to the monitor itself (modules/nixos/ddcci.nix), which is
  # one piece of hardware shared by everyone on the seat. Left ungated, a
  # background session's four-minute dim lands on the screen of whoever is
  # actually using the machine, four minutes after they sat down.
  #
  # `show-session auto` is how swayidle itself finds the session it listens to
  # for logind's Lock and Unlock signals. logind resolves "auto" as the
  # caller's own session, falling back to the user's display session, and that
  # fallback is what makes it work from a `systemd --user` service — there is
  # no XDG_SESSION_ID in that environment and the unit's cgroup sits outside
  # any login session, so asking about "this process's session" gets nowhere.
  #
  # A question that can't be answered runs the command. Sessions on no seat at
  # all — a VM, a headless box, an ssh login — report themselves active, and
  # anything that leaves this empty (no logind, no session) is a machine where
  # there is nobody else to interrupt in the first place.
  whenActive = pkgs.writeShellApplication {
    name = "when-active";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      if [ "$#" -eq 0 ]; then
        echo "usage: when-active <command> [args...]" >&2
        exit 2
      fi

      active="$(loginctl show-session auto --property=Active --value 2>/dev/null || true)"

      if [ "$active" = "no" ]; then
        exit 0
      fi

      exec "$@"
    '';
  };

  # Sleep inhibitor. One entry point for the keybind and the waybar module,
  # so the two can't disagree about the state.
  #
  # All the actual work is in idle-inhibit.service (lock.nix); this only
  # starts and stops it. systemd holding the state means `status` is a real
  # query rather than a flag file that can go stale — if the inhibitor dies
  # for any reason, the bar shows it.
  #
  # Not waybar's built-in `idle_inhibitor` module: that one holds a Wayland
  # idle-inhibit lock on waybar's own surface, which is a fine mechanism but
  # can only be toggled by clicking the module. There's no IPC to it, so a
  # keybind would have no way in. It also wouldn't hold off logind sleep.
  idleInhibit = pkgs.writeShellApplication {
    name = "idle-inhibit";
    runtimeInputs = with pkgs; [
      systemd
      libnotify
      procps
    ];
    text = ''
      unit=idle-inhibit.service

      is_on() { systemctl --user is-active --quiet "$unit"; }

      case "''${1:-toggle}" in
        on)  systemctl --user start "$unit" ;;
        off) systemctl --user stop  "$unit" ;;
        toggle)
          if is_on; then systemctl --user stop "$unit"
          else systemctl --user start "$unit"
          fi
          ;;
        status)
          # waybar custom module, return-type json.
          if is_on; then
            printf '%s\n' '{"text":"󰅶","class":"activated","tooltip":"Awake — no dim, lock, blank or sleep"}'
          else
            printf '%s\n' '{"text":"󰒲","class":"deactivated","tooltip":"Idle actions normal — click to stay awake"}'
          fi
          exit 0
          ;;
        *)
          echo "usage: idle-inhibit [toggle|on|off|status]" >&2
          exit 2
          ;;
      esac

      # Refresh the bar now rather than waiting for its next poll. waybar
      # re-runs a custom module on SIGRTMIN+<signal>; 8 is the number set on
      # the module in waybar.nix.
      pkill -RTMIN+8 waybar || true

      if is_on; then
        notify-send -a idle-inhibit -i preferences-desktop-screensaver \
          "Staying awake" "Idle actions and sleep are inhibited" || true
      else
        notify-send -a idle-inhibit -i preferences-desktop-screensaver \
          "Idle actions restored" "Screen will dim, lock and blank as usual" || true
      fi
    '';
  };

  # Session menu: shown by the waybar power button and a hotkey.
  # Switch to the login greeter, leaving this session running on its own VT.
  #
  # SDDM implements the org.freedesktop.DisplayManager D-Bus interface, whose
  # Seat object has SwitchToGreeter — that's the supported way to do this;
  # there's no CLI equivalent. SDDM exports the seat path as XDG_SEAT_PATH in
  # the session, with Seat0 as the fallback for a single-seat machine.
  #
  # The session is locked first. SwitchToGreeter doesn't lock anything, so
  # without this, switching back would land straight in an unlocked desktop.
  switchUser = pkgs.writeShellApplication {
    name = "switch-user";
    runtimeInputs = [ lockNow ];
    text = ''
      # lock-now returns once the locker is up rather than when it ends, and
      # carries the settle that the hand-rolled `lock-session & sleep 0.3`
      # here used to do by hand.
      lock-now

      exec ${lib.getExe switchToGreeter}
    '';
  };

  sessionMenu = pkgs.writeShellApplication {
    name = "session-menu";
    runtimeInputs = with pkgs; [
      wofi
      systemd
      niri
      lockNow
      switchUser
    ];
    text = ''
      choice="$(printf '%s\n' \
        "  Lock" \
        "  Switch user" \
        "  Log out" \
        "  Suspend" \
        "  Reboot" \
        "  Shut down" \
        | wofi --dmenu --prompt "Session" --insensitive --width 260 --height 300)"

      case "$choice" in
        *Lock*)        lock-now ;;
        *"Switch user"*) switch-user ;;
        *"Log out"*)   niri msg action quit --skip-confirmation ;;
        *Suspend*)     systemctl suspend ;;
        *Reboot*)      systemctl reboot ;;
        *"Shut down"*) systemctl poweroff ;;
      esac
    '';
  };

  # The on-screen display, as one entry point.
  #
  # swayosd draws it (see ./osd.nix); this is the only thing that knows how to
  # ask. Two shapes, matching the two a client request can actually produce:
  #
  #   osd progress <icon> <percent>   icon, bar and a percentage
  #   osd message  <icon> <text>      icon and a line of text
  #
  # `<icon>` is a Freedesktop icon name. swayosd bundles its own set inside the
  # binary — `sink-volume-{muted,low,medium,high}-symbolic`, the matching
  # `source-volume-*` for microphones, and `display-brightness-symbolic` — and
  # those are the ones to reach for: they are the glyphs its native OSD draws,
  # and being compiled in they cannot go missing when the icon theme changes.
  #
  # Every call is best effort. `swayosd-client` exits non-zero when the server
  # isn't up, and a missing pop-up must never turn into a volume or brightness
  # key that appears to have failed.
  #
  # That is also why swayosd is never asked to *change* anything, only to draw.
  # `swayosd-client --output-volume raise` and `--brightness raise` do the
  # change and the drawing together, and that is the usage its README
  # documents — but with the server down they do neither, so a crashed OSD
  # daemon would take the media keys with it. Its brightness backend is a
  # second reason: it is `brightnessctl` with at most one `--device`, which is
  # the exact behaviour `brightness` below exists to work around, and asking it
  # for a wildcard makes `brightnessctl get` print one line per display into a
  # parser that wants a single number. So both callers make the change
  # themselves and read the result back.
  osd = pkgs.writeShellApplication {
    name = "osd";
    runtimeInputs = with pkgs; [
      swayosd
      gawk
      coreutils
    ];
    text = ''
      icon="''${2:-}"

      case "''${1:-}" in
        progress)
          pct="''${3:-}"

          # A malformed reading draws nothing rather than a wrong bar.
          case "$pct" in
            "" | *[!0-9]*) exit 0 ;;
          esac

          # The bar takes a 0.0–1.0 fraction; the label is padded to the width
          # of "100%" so the bar beside it doesn't shift sideways as the number
          # gains a digit. swayosd's own volume OSD pins that label at four
          # characters for the same reason, but a client-drawn one has no width
          # to set — only the text.
          swayosd-client \
            --custom-icon "$icon" \
            --custom-progress "$(awk -v p="$pct" 'BEGIN { printf "%.2f", p / 100 }')" \
            --custom-progress-text "$(printf '%3d%%' "$pct")" \
            >/dev/null 2>&1 || true
          ;;
        message)
          swayosd-client \
            --custom-icon "$icon" \
            --custom-message "''${3:-}" \
            >/dev/null 2>&1 || true
          ;;
        *)
          echo "usage: osd [progress <icon> <percent>|message <icon> <text>]" >&2
          exit 2
          ;;
      esac
    '';
  };

  # Volume, and the display that goes with it.
  #
  # wpctl is still what moves the volume, with the same arguments the keybinds
  # used to carry inline — this exists so that changing it and showing it are
  # one action, and so that every route to the volume goes through one place.
  # There are three: the media keys, waybar's click to mute, and waybar's
  # scroll. That last one is why `up`/`down` take an optional step — the bar
  # scrolls in single points where a key moves five.
  #
  # The level is read back from wpctl after the change rather than tracked
  # here. That costs one extra call and buys a display that is telling the
  # truth: `volume show` on its own draws whatever the system is actually at,
  # including a level set from pavucontrol or by an application.
  #
  # Mute is a message rather than a greyed-out bar. swayosd's native volume OSD
  # dims the bar by marking the widget insensitive, which a client request
  # can't do — and "Muted" in words is clearer than a bar you have to notice is
  # a different shade anyway.
  #
  # Raising while muted stays muted, which is wpctl's behaviour and was this
  # config's before. The OSD makes that state visible instead of leaving you to
  # work out why the sound didn't come back.
  volume = pkgs.writeShellApplication {
    name = "volume";
    runtimeInputs = with pkgs; [
      wireplumber
      gawk
      coreutils
      osd
    ];
    text = ''
      # Percentage points per press. wpctl reads "5%+" and "0.05+" as the same
      # thing (its argument regex is `(\d*\.?\d*)(%?)([-+]?)`, and a `%` just
      # divides by 100); percent is the form here because the step can also
      # arrive as an argument, and waybar's scroll passes 1.
      default_step=5
      sink="@DEFAULT_AUDIO_SINK@"
      mic="@DEFAULT_AUDIO_SOURCE@"

      # Optional second argument on up/down. A non-number falls back rather
      # than failing: a mistyped step should still change the volume.
      step="''${2:-$default_step}"
      case "$step" in
        "" | *[!0-9]*) step="$default_step" ;;
      esac

      # `wpctl get-volume` prints "Volume: 0.65", or "Volume: 0.65 [MUTED]".
      show_sink() {
        state="$(wpctl get-volume "$sink" 2>/dev/null || true)"
        [ -n "$state" ] || return 0

        case "$state" in
          *MUTED*)
            osd message sink-volume-muted-symbolic "Muted"
            return 0
            ;;
        esac

        pct="$(printf '%s\n' "$state" | awk 'NR == 1 { printf "%d", $2 * 100 + 0.5 }')"

        # The same thresholds swayosd's native OSD uses, so the glyph means the
        # same thing however the volume was changed.
        if [ "$pct" -le 0 ]; then
          icon=muted
        elif [ "$pct" -le 33 ]; then
          icon=low
        elif [ "$pct" -le 66 ]; then
          icon=medium
        else
          icon=high
        fi

        osd progress "sink-volume-$icon-symbolic" "$pct"
      }

      # The microphone has no level bound to a key, only a mute toggle, so it
      # gets the state in words rather than a bar.
      show_mic() {
        state="$(wpctl get-volume "$mic" 2>/dev/null || true)"
        [ -n "$state" ] || return 0

        case "$state" in
          *MUTED*) osd message source-volume-muted-symbolic "Microphone muted" ;;
          *)       osd message source-volume-high-symbolic  "Microphone on" ;;
        esac
      }

      case "''${1:-}" in
        # -l 1.0 caps the sink at 100%. Software gain above that is available
        # in pavucontrol for the once-a-year quiet recording; on a key held
        # down it is a way to damage speakers.
        up)       wpctl set-volume "$sink" "''${step}%+" -l 1.0 ; show_sink ;;
        down)     wpctl set-volume "$sink" "''${step}%-"        ; show_sink ;;
        mute)     wpctl set-mute   "$sink" toggle               ; show_sink ;;
        mic-mute) wpctl set-mute   "$mic"  toggle               ; show_mic ;;
        set)
          [ -n "''${2:-}" ] || { echo "usage: volume set <percent>" >&2; exit 2; }
          wpctl set-volume "$sink" "$2%" -l 1.0
          show_sink
          ;;
        # Draw the current level without changing it.
        show) show_sink ;;
        *)
          echo "usage: volume [up|down [pct]|mute|mic-mute|set <pct>|show]" >&2
          exit 2
          ;;
      esac
    '';
  };

  # Brightness, across every backlight device rather than only the first.
  #
  # `brightnessctl set` with no --device picks the first device it finds and
  # adjusts that one alone. On the laptop there is exactly one — the internal
  # panel — so that was invisible. The desk reaches its monitors through
  # ddcci-backlight (modules/nixos/ddcci.nix), which registers one device per
  # display, and "the first one" there means a single monitor changes and the
  # other doesn't. Hence the loop.
  #
  # Also the reason the keybinds call this rather than brightnessctl directly:
  # a host with one display and a host with two want the same key to mean the
  # same thing.
  brightness = pkgs.writeShellApplication {
    name = "brightness";
    runtimeInputs = with pkgs; [
      brightnessctl
      util-linux
      coreutils
      gawk
      osd
    ];
    text = ''
      step=5

      # Serialise, and drop overlapping runs rather than queue them.
      #
      # A DDC/CI write is a round trip over the monitor's own i2c bus, on the
      # order of 100ms per display — the kernel backlight of a laptop panel is
      # effectively instant by comparison. Holding the key down generates
      # presses far faster than the monitors can answer, and without this the
      # backlog keeps applying for seconds after the key is released. -n makes
      # a run that arrives mid-write exit instead of waiting its turn.
      exec 9>"''${XDG_RUNTIME_DIR:-/tmp}/brightness.lock"
      flock -n 9 || exit 0

      # Machine-readable list is `name,class,current,percent%,max` per device.
      #
      # The process substitution keeps a non-zero brightnessctl — which is
      # what an empty backlight class produces, the ordinary state of a
      # desktop without ddcci loaded — from tripping `set -e` here, so the
      # empty case gets a clear message instead of a bare failure.
      mapfile -t devices < <(
        brightnessctl --class=backlight --machine-readable --list 2>/dev/null | cut -d, -f1
      )

      if [ ''${#devices[@]} -eq 0 ]; then
        echo "brightness: no backlight devices — see modules/nixos/ddcci.nix" >&2
        exit 1
      fi

      # One monitor refusing a DDC/CI write shouldn't stop the others moving.
      apply() {
        local dev="$1"
        shift
        brightnessctl --class=backlight --device="$dev" --quiet "$@" || true
      }

      each() {
        local dev
        for dev in "''${devices[@]}"; do
          apply "$dev" "$@"
        done
      }

      # The on-screen display, drawn from a fresh reading of the device rather
      # than from a level computed here. Nothing in this script has to know
      # what a step did — including the clamping at 0% and 100%, which is
      # brightnessctl's, and which a predicted number would get wrong at both
      # ends of the range.
      #
      # The first device speaks for all of them. That is brightnessctl's own
      # no-`--device` semantics, it is the only device there is on the laptop,
      # and on the desk every display has just taken the same step. They can
      # still drift apart — a monitor that refused a write, or one adjusted
      # from its own buttons — in which case this shows the first display's
      # level rather than an average, which is at least a number that belongs
      # to something real.
      #
      # awk rather than `head -1`: this runs under `set -o pipefail`, and a
      # reader that closes the pipe early would make brightnessctl die of
      # SIGPIPE and take the whole script with it.
      show_osd() {
        local pct
        pct="$(
          brightnessctl --class=backlight --machine-readable --list 2>/dev/null \
            | awk -F, 'NR == 1 { sub(/%$/, "", $4); print $4 }' || true
        )"

        osd progress display-brightness-symbolic "$pct"
      }

      case "''${1:-}" in
        up)   each set "+''${step}%" ; show_osd ;;
        down) each set "''${step}%-" ; show_osd ;;
        set)
          [ -n "''${2:-}" ] || { echo "usage: brightness set <percent>" >&2; exit 2; }
          each set "$2%"
          show_osd
          ;;
        # Save the current level and drop to <percent>. This is the swayidle
        # dim warning; `restore` is its resumeCommand.
        #
        # No OSD on either: the dim is what happens when you have stopped
        # touching the machine, and the restore is what happens the instant you
        # touch it again. A pop-up on the second one would fire on every return
        # to the desk, reporting a level that hasn't changed from what it was
        # before the timer ran.
        dim)
          [ -n "''${2:-}" ] || { echo "usage: brightness dim <percent>" >&2; exit 2; }
          each --save set "$2%"
          ;;
        restore) each --restore ;;
        *)
          echo "usage: brightness [up|down|set <pct>|dim <pct>|restore]" >&2
          exit 2
          ;;
      esac
    '';
  };

  # Audio visualiser for the bar. See the custom/cava module in waybar.nix.
  cavaConfig = pkgs.writeText "cava-waybar.conf" ''
    [general]
    # Eight glyphs in a status bar, not a full-screen visualiser — and every
    # frame is a waybar label redraw, so 30 rather than cava's default 60.
    framerate = 30
    bars = 8
    autosens = 1

    # After two seconds of silence cava stops doing FFT and just checks for
    # input once a second, until sound comes back. Nothing is playing most of
    # the time, and this is meant to be a detail rather than a background job.
    sleep_timer = 2

    [input]
    # pipewire-pulse is on (modules/nixos/niri.nix), and `pulse` with
    # `source = auto` follows the *default sink's* monitor — so it tracks
    # whichever output you switched to instead of a device named here.
    method = pulse
    source = auto

    [output]
    method = raw
    raw_target = /dev/stdout
    data_format = ascii
    # 0-7, one value per block glyph in the mapping below.
    ascii_max_range = 7
  '';

  # Eight bars of the playing audio, or nothing at all when it's quiet.
  #
  # Emitting an empty line is what hides it: waybar hides a custom module
  # whose text is empty. So the bar looks exactly as it did before whenever
  # the music stops, which is the point — the widget doesn't reserve a slot
  # or leave a flat row of glyphs sitting there.
  #
  # It follows *audio*, not the mpris player, so a notification chime blips it
  # for a moment too. That's deliberate: it needs no polling and no second
  # process, and it reacts within a frame. To tie it to the player instead,
  # the gate would have to be `playerctl --follow status` feeding this loop.
  #
  # No stdbuf anywhere in here, and it isn't an oversight — cava's raw output
  # is plain write(2) with no stdio buffer (output/raw.c), and bash flushes
  # its printf per iteration, so frames arrive one at a time on their own.
  cavaBar = pkgs.writeShellApplication {
    name = "cava-bar";
    runtimeInputs = [ pkgs.cava ];
    text = ''
      cava -p ${cavaConfig} | while IFS= read -r frame; do
        # `0;3;5;7;` -> `0357`
        bars="''${frame//;/}"

        # An all-zero frame is silence. Anything at all in 1-7 is sound.
        case "$bars" in
          *[1-7]*) ;;
          *) echo; continue ;;
        esac

        # Parameter substitution rather than sed or tr: this runs thirty times
        # a second, and a process per frame is not the way to draw a
        # decoration. The replacements can't collide — every result is a
        # non-digit.
        bars="''${bars//0/▁}"
        bars="''${bars//1/▂}"
        bars="''${bars//2/▃}"
        bars="''${bars//3/▄}"
        bars="''${bars//4/▅}"
        bars="''${bars//5/▆}"
        bars="''${bars//6/▇}"
        bars="''${bars//7/█}"

        printf '%s\n' "$bars"
      done
    '';
  };
  # Caps lock for the bar — the glyph while the lock is on, nothing at all
  # while it is off. See the custom/caps-lock module in waybar.nix.
  #
  # The empty line is the entire design. waybar hides a custom module whose
  # text is empty (Custom::update), and hiding is the only way for a module to
  # cost *no* room: a glyph styled invisible still holds its slot, and even a
  # zero-width label still costs the 6px `spacing` the bar puts between
  # modules, because GTK only skips that gap for children that are hidden
  # outright. So an indicator that is meant to exist only while the lock is on
  # has to be a custom module that prints nothing the rest of the time —
  # exactly the trick cava-bar above uses to vanish when the music stops.
  #
  # That is also why this isn't waybar's own `keyboard-state` module, which is
  # otherwise precisely this widget: it always draws its label, locked or not,
  # and no stylesheet can take that label out of the layout.
  #
  # It watches the LED rather than the key. The compositor owns the lock state
  # and mirrors it onto the caps LED of every keyboard, and the kernel hands
  # each EV_LED change to everything holding the device open (INPUT_PASS_TO_ALL
  # in drivers/input/input.c) — so a blocking select over the keyboards is the
  # whole loop. No polling, and the glyph turns over with the keypress rather
  # than at the next tick.
  #
  # Python rather than shell: the shell version is `evtest` piped into `read`,
  # which means picking the right event device out of a hex LED bitmask in
  # /proc/bus/input/devices, and stdbuf to defeat evtest's block buffering once
  # its stdout is a pipe. python-evdev asks each device what it supports and
  # reads the starting state with an ioctl, which is the part shell can't do
  # at all.
  #
  # Reading /dev/input needs the `input` group; joshr has it from
  # modules/nixos/users.nix. Without it every device fails to open, the script
  # finds no keyboards and exits, and the bar is simply short one module.
  capsLockWatch = pkgs.writeText "caps-lock-watch.py" ''
    """Print the caps lock glyph while caps lock is on, an empty line while it
    is off. One line per change, forever."""

    import select
    import sys

    from evdev import InputDevice, ecodes, list_devices

    GLYPH = "󰪛"


    def keyboards():
        """Every input device that reports a caps lock LED."""
        found = []
        for path in sorted(list_devices()):
            try:
                device = InputDevice(path)
            except OSError:
                continue
            if ecodes.LED_CAPSL in device.capabilities().get(ecodes.EV_LED, []):
                found.append(device)
            else:
                device.close()
        return found


    def emit(on):
        print(GLYPH if on else "", flush=True)


    def main():
        devices = keyboards()
        if not devices:
            emit(False)
            return 1

        state = any(ecodes.LED_CAPSL in device.leds() for device in devices)
        emit(state)

        while True:
            readable, _, _ = select.select(devices, [], [])
            for device in readable:
                try:
                    events = list(device.read())
                except BlockingIOError:
                    # Woken with nothing to read. Not an error, and not worth
                    # tearing the module down over.
                    continue
                except OSError:
                    # The keyboard was unplugged. Leave the slot empty and quit;
                    # waybar's restart-interval starts a fresh scan, which is
                    # also how a keyboard plugged in later gets picked up.
                    emit(False)
                    return 1

                for event in events:
                    if event.type != ecodes.EV_LED or event.code != ecodes.LED_CAPSL:
                        continue
                    if bool(event.value) != state:
                        state = bool(event.value)
                        emit(state)


    if __name__ == "__main__":
        sys.exit(main())
  '';

  capsLock = pkgs.writeShellApplication {
    name = "caps-lock";
    runtimeInputs = [ (pkgs.python3.withPackages (ps: [ ps.evdev ])) ];
    text = ''
      exec python3 ${capsLockWatch}
    '';
  };

  # GameMode for the bar: the pad while a game is holding gamemode, nothing at
  # all the rest of the time. See the custom/gamemode module in waybar.nix.
  #
  # Empty output rather than a dimmed glyph, the same as caps-lock above and
  # for the same reason — gamemode is off nearly always, and an indicator for
  # something that is almost never happening should cost nothing while it
  # isn't.
  #
  # This one is asked rather than watched: the module polls it every 30s, and
  # the gamemode start/end hooks in modules/nixos/gaming.nix send waybar
  # SIGRTMIN+9 so the real answer lands the moment a game takes gamemode.
  # Same arrangement as idle-inhibit above, and the poll is the backstop for
  # the same reason — it catches a state that changed without the hook, which
  # here means gamemoded having been killed outright.
  gamemodeStatus = pkgs.writeShellApplication {
    name = "gamemode-status";
    runtimeInputs = with pkgs; [
      gamemode
      procps
    ];
    text = ''
      # There is nothing to ask when the daemon is down, and asking would
      # *start* it: gamemoded is D-Bus activated, so `gamemoded --status`
      # would launch the very thing it is supposed to be reporting on, every
      # time the module ticks.
      #
      # pgrep rather than `systemctl --user is-active gamemoded.service`
      # because that hard-codes a unit name this config never sets. If the
      # name were ever wrong the check would fail exactly like "gamemode is
      # off" — silence that looks correct — where a wrong process name at
      # least fails the same way for everyone and shows up the first time a
      # game runs.
      if ! pgrep -x -u "$UID" gamemoded >/dev/null; then
        echo
        exit 0
      fi

      # "gamemode is inactive", "gamemode is active", or "gamemode is active
      # and [pid] registered". Matching `is active` rather than `active` is
      # the whole trick — "inactive" contains "active".
      case "$(gamemoded --status 2>/dev/null || true)" in
        *"is active"*) printf '%s\n' '󰊗' ;;
        *)             echo ;;
      esac
    '';
  };
in
{
  home.packages = [
    themeApply
    themeCycle
    themeRandom
    themeMenu
    wallpaperSet
    wallpaperMenu
    wallpaperRandom
    wallpaperRestore
    screenshot
    lockSession
    lockNow
    lockBlank
    unlockSession
    switchUser
    sessionMenu
    whenActive
    idleInhibit
    osd
    volume
    brightness
    cavaBar
    capsLock
    gamemodeStatus
  ];

  _module.args.niriScripts = {
    inherit
      themeApply
      themeCycle
      themeRandom
      themeMenu
      wallpaperMenu
      wallpaperRandom
      wallpaperRestore
      screenshot
      lockSession
      lockNow
      lockBlank
      unlockSession
      switchUser
      sessionMenu
      whenActive
      idleInhibit
      osd
      volume
      brightness
      cavaBar
      capsLock
      gamemodeStatus
      ;

    # Not a script: the patched swaylock that lock-session wraps. Exported so
    # lock.nix installs the same build rather than the stock one, which would
    # otherwise put an unpatched `swaylock` on PATH beside it.
    inherit swaylock;
  };
}

# An ImageMagick histogram of an album cover on stdin, and on stdout the two
# things the lock screen wants to know about it: how far to stop the backdrop
# down, and what colour to wear.
#
# The cover decides a hue. Everything else about what is done with that hue is
# decided here, and that split is the whole point: a lock screen has to stay
# readable over a picture nobody chose, so the lightness of every colour below
# is fixed and only the hue — plus a bounded amount of saturation — comes off
# the sleeve. A neon cover and a washed-out one land in the same place.
#
# Two kinds of line come out, and they are independent:
#
#   ART_BRIGHTNESS   always, because every cover needs an exposure.
#   LOCK_*           only when some colour in the cover is confident enough to
#                    build on, which leaves a black-and-white sleeve wearing
#                    the theme's own colours rather than a hue invented for it.

function hue2rgb(p, q, t) {
    if (t < 0) t += 1
    if (t > 1) t -= 1
    if (t < 1 / 6) return p + (q - p) * 6 * t
    if (t < 1 / 2) return q
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6
    return p
}

# Hue in degrees, saturation and lightness in 0..1; six hex digits out.
function hsl(h, s, l,   q, p, r, g, b) {
    if (s <= 0) {
        r = l; g = l; b = l
    } else {
        q = (l < 0.5) ? l * (1 + s) : l + s - l * s
        p = 2 * l - q
        r = hue2rgb(p, q, h / 360 + 1 / 3)
        g = hue2rgb(p, q, h / 360)
        b = hue2rgb(p, q, h / 360 - 1 / 3)
    }

    return sprintf("%02x%02x%02x",
        int(r * 255 + 0.5), int(g * 255 + 0.5), int(b * 255 + 0.5))
}

function smaller(a, b) { return (a < b) ? a : b }

# The lightness the blurred backdrop is aimed at, before Hyprlock applies its
# own `brightness` on top of it. Low, because everything on this screen is
# text laid over it.
BEGIN { target = 0.28 }

# "   3473: ( 19, 28, 41) #141C2A srgb(...)"
match($0, /#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]/) {
    count = $1 + 0
    hex = substr($0, RSTART + 1, 6)

    r = strtonum("0x" substr(hex, 1, 2)) / 255
    g = strtonum("0x" substr(hex, 3, 2)) / 255
    b = strtonum("0x" substr(hex, 5, 2)) / 255

    # Exposure first, over every colour in the cover including the greys — a
    # sleeve that is mostly white is exactly the one this has to catch.
    pixels += count
    light += count * (0.2126 * r + 0.7152 * g + 0.0722 * b)

    hi = (r > g) ? ((r > b) ? r : b) : ((g > b) ? g : b)
    lo = (r < g) ? ((r < b) ? r : b) : ((g < b) ? g : b)

    l = (hi + lo) / 2
    d = hi - lo

    # Grey has no hue to take.
    if (d == 0) next

    s = (l > 0.5) ? d / (2 - hi - lo) : d / (hi + lo)

    if      (hi == r) h = 60 * ((g - b) / d % 6)
    else if (hi == g) h = 60 * ((b - r) / d + 2)
    else              h = 60 * ((r - g) / d + 4)

    if (h < 0) h += 360

    # Nearly grey is grey, and a colour at either end of the range is one the
    # eye reads as black or white however saturated it claims to be.
    if (s < 0.18 || l < 0.15 || l > 0.85) next

    # The most of the cover, not the loudest part of it: the colour a sleeve
    # is *mostly* made of is the one it reads as from across the room.
    if (count > best) {
        best = count
        best_h = h
        best_s = s
    }
}

END {
    # Never brighten — a dark cover is allowed to make a dark lock screen, the
    # same way a dark wallpaper does — and never take off more than two
    # thirds, which is the point past which a cover stops being visible at all
    # rather than merely dim.
    brightness = 1
    if (pixels > 0 && light > 0) {
        brightness = target / (light / pixels)
        if (brightness > 1) brightness = 1
        if (brightness < 0.30) brightness = 0.30
    }

    printf "ART_BRIGHTNESS=%d\n", int(brightness * 100 + 0.5)

    if (!best) exit 0

    # Follow the sleeve's own saturation, but not past the point where an
    # accent stops reading as one, nor to where it vibrates against the
    # backdrop it is sitting on.
    sat = best_s
    if (sat < 0.45) sat = 0.45
    if (sat > 0.90) sat = 0.90

    printf "LOCK_BG=%s\n",         hsl(best_h, 0.35, 0.055)
    printf "LOCK_ACCENT=%s\n",     hsl(best_h, sat, 0.62)
    printf "LOCK_ACCENT_DIM=%s\n", hsl(best_h, sat * 0.85, 0.38)
    printf "LOCK_FG=%s\n",         hsl(best_h, smaller(0.50, sat * 0.55), 0.88)
    printf "LOCK_FG_DIM=%s\n",     hsl(best_h, smaller(0.30, sat * 0.35), 0.56)
}

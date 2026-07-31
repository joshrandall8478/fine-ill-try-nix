{ ... }:

# PLACEHOLDER — this host cannot be built until it is replaced.
#
# On the target machine:
#
#   sudo nixos-generate-config --show-hardware-config \
#     > hosts/server/hardware-configuration.nix
#   git add hosts/server/hardware-configuration.nix
#
# and replace this whole file with the output. The `git add` matters: a flake
# build only sees files git knows about, so an untracked hardware config is
# silently invisible and the build fails in a confusing way.
#
# Why this throws instead of shipping plausible defaults
# ------------------------------------------------------
# The other hosts' placeholders name devices like /dev/disk/by-label/nixos.
# Those evaluate and build perfectly well, then leave the machine sitting at
# "A start job is running for /dev/disk/by-label/..." until it times out —
# a broken generation you can only escape from the boot menu. Failing here
# costs one clear error message at eval time instead.
throw ''
  hosts/server/hardware-configuration.nix is still the placeholder.

  Generate the real one on the server:

    sudo nixos-generate-config --show-hardware-config \
      > hosts/server/hardware-configuration.nix
    git add hosts/server/hardware-configuration.nix

  It carries the disk UUIDs, filesystem layout and kernel modules for that
  specific machine, so there is nothing sensible to default to.
''

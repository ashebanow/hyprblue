#!/bin/bash

set -ouex pipefail

RELEASE="$(rpm -E %fedora)"

# if true, the binaries needed for nwg-shell will be installed.
# Includes all of sway, though only swaync is used.
# NOTE: NOT FULLY IMPLEMENTED AND UNTESTED, DO NOT USE YET
USE_NWG_SHELL=FALSE

# if true, sddm will be installed as the display manager.
# NOTE: NOT FULLY IMPLEMENTED AND UNTESTED, DO NOT USE YET
USE_SDDM=FALSE

#######################################################################
# Setup Repositories
#######################################################################

# NOTE: RPMFusion repos are available by default
# NOTE: chrome .repo file is installed in the Containerfile prior
# to running this script.

dnf5 -y copr enable solopasha/hyprland
dnf5 -y copr enable erikreider/SwayNotificationCenter
dnf5 -y copr enable errornointernet/packages
dnf5 -y copr enable tofik/sway
dnf5 -y copr enable pgdev/ghostty

if [[ $USE_NWG_SHELL == TRUE ]]; then
    dnf5 -y copr enable tofik/nwg-shell
fi

#######################################################################
## Install Packages
#######################################################################

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images

# this installs a package from fedora repos
# dnf install -y tmux

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

# Note that these fedora font packages are preinstalled in the
# bluefin-dx image, along with the SymbolsNerdFont which doesn't
# have an associated fedora package:
#
#   adobe-source-code-pro-fonts
#   google-droid-sans-fonts
#   google-noto-sans-cjk-fonts
#   google-noto-color-emoji-fonts
#   jetbrains-mono-fonts
#
# Because the nerd font symbols are mapped correctly, we can get
# nerd font characters anywhere.
FONTS=(
  fira-code-fonts
  fontawesome-fonts-all
  google-noto-emoji-fonts
)

# Hyprland dependencies to be installed, based on
# https://github.com/JaKooLit/Fedora-Hyprland/ with additions
# from ml4w and other sources.
HYPR_DEPS=(
  aquamarine
  blueman
  bluez-tools
  brightnessctl
  btop
  cava
  cliphist
  # egl-wayland
  eog
  grim
  inxi
  kvantum
  # lib32-nvidia-utils
  mpv
#   mpv-mpris
  # nvidia-dkms
  # nvidia-utils
  nwg-look
  pamixer
  pavucontrol
  playerctl
  python3-pyquery
  qalculate-gtk
  qt5ct
  qt6ct
  slurp
  swww
  tumbler
  wallust
  wget2
  wl-clipboard
  wlr-randr
  xarchiver
  yad
)

# Hyprland ecosystem packages
HYPR_PKGS=(
  hyprcursor
  hyprland
  hypridle
  hyprlock
  network-manager-applet
  rofi-wayland
  swappy
  swaync
  waybar
  wlogout
  xdg-desktop-portal-hyprland
  xdg-desktop-portal-gtk
)

# See https://github.com/nwg-piotr/nwg-shell/blob/main/install/fedora-ostree.sh
NWG_SHELL_PKGS=()
if [[ $USE_NWG_SHELL == TRUE ]]; then
  NWG_SHELL_PKGS=(
    nwg-shell
    gtklock
  )
fi

# SDDM not set up properly yet, so this is just a placeholder.
# For now you'll have to invoke Hyprland from the command line.
SDDM_PACKAGES=()
if [[ $USE_SDDM == TRUE ]]; then
  SDDM_PACKAGES=(
    sddm
    sddm-breeze
    sddm-kcm
    qt6-qt5compat
  )
fi

# 1password* and chrome are installed separately above.
LAYERED_APPS=(
  # We really should just pick one terminal emulator!
  ghostty
  kitty
  kitty-terminfo

  thunar
  thunar-volman
  thunar-archive-plugin
)

# we do all package installs in one rpm-ostree command
# so that we create minimal layers in the final image
dnf5 install -y \
  ${FONTS[@]} \
  ${HYPR_DEPS[@]} \
  ${HYPR_PKGS[@]} \
  ${SDDM_PACKAGES[@]} \
  ${NWG_SHELL_PKGS[@]} \
  ${LAYERED_APPS[@]}

#######################################################################
### Disable repositeories so they aren't cluttering up the final image

dnf5 -y copr disable solopasha/hyprland
dnf5 -y copr disable erikreider/SwayNotificationCenter
dnf5 -y copr disable errornointernet/packages
dnf5 -y copr disable tofik/sway
dnf5 -y copr disable pgdev/ghostty

if [[ $USE_NWG_SHELL == TRUE ]]; then
    dnf5 -y copr disable tofik/nwg-shell
fi

#######################################################################
### Enable Services

# Setting Thunar as the default file manager
# TODO: these need to be run at first boot, not during build
# xdg-mime default thunar.desktop inode/directory
# xdg-mime default thunar.desktop application/x-wayland-gnome-saved-search

if [[ $USE_SDDM == TRUE ]]; then
    for login_manager in lightdm gdm lxdm lxdm-gtk3; do
    if sudo dnf list installed "$login_manager" &>> /dev/null; then
      sudo systemctl disable "$login_manager" 2>&1 | tee -a "$LOG"
    fi
    done
  systemctl set-default graphical.target
  systemctl enable sddm.service
fi
